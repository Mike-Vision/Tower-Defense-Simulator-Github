-- gui.lua
-- Synced Cooldown Gatling Gun automation UI for TDS (Stable Damage Version)

local HttpService = game:GetService("HttpService")

-- 1. Clean up previous GUI if exists
if getgenv().GatlingWindow then
    pcall(function()
        getgenv().GatlingWindow:Destroy()
    end)
    getgenv().GatlingWindow = nil
end

-- 2. Generate a unique ID for this execution thread to kill old loops
local currentScriptID = HttpService:GenerateGUID(false)
getgenv().GatlingScriptID = currentScriptID

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Gatling Gun Control",
   LoadingTitle = "TDS Gatling Gun Loader",
   LoadingSubtitle = "by Antigravity & Mike-vision",
   Theme = "Default",
   DisableRayfieldPrompts = false
})

getgenv().GatlingWindow = Window

local Tab = Window:CreateTab("Gatling Automation", 4483362458) -- Title, ImageID

-- Control variables (Direct callback-driven state)
local bpsValue = 10
local multiTargetLimit = 1
local targetMode = "First"
local autoShootEnabled = false

-- UI Elements
Tab:CreateSlider({
   Name = "Bullet Per Second (BPS)",
   Info = "Fallback firing speed if cooldown is not loaded (1 - 26)",
   Range = {1, 26},
   Increment = 1,
   Suffix = "bullets/s",
   CurrentValue = 10,
   Flag = "BPS_Slider",
   Callback = function(Value)
      bpsValue = Value
   end,
})

Tab:CreateSlider({
   Name = "Multi Target Limit",
   Info = "Max targets to shoot concurrently (1 - 5)",
   Range = {1, 5},
   Increment = 1,
   Suffix = "targets",
   CurrentValue = 1,
   Flag = "MultiTarget_Slider",
   Callback = function(Value)
      multiTargetLimit = Value
   end,
})

Tab:CreateDropdown({
   Name = "Targeting Mode",
   Options = {"First", "Strongest", "Last", "Random"},
   CurrentValue = "First",
   MultipleOptions = false,
   Flag = "Targeting_Dropdown",
   Callback = function(Option)
      local selected = type(Option) == "table" and Option[1] or Option
      targetMode = selected or "First"
   end,
})

-- Core Targeting & Firing Logic
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local npcsFolder = workspace:WaitForChild("NPCs")
local rf = ReplicatedStorage:WaitForChild("RemoteFunction")
local stateReplicators = ReplicatedStorage:WaitForChild("StateReplicators")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Helper to find active Gatling Gun tower owned by player
local function getMyGatlingGun()
    for _, tower in ipairs(workspace.Towers:GetChildren()) do
        local isOwner = tower:FindFirstChild("Owner") and tower.Owner.Value == localPlayer.UserId
        if isOwner and (tower.Name == "Gatling Gun" or tower.Name == "Default") then
            return tower
        end
    end
    for _, tower in ipairs(workspace.Towers:GetChildren()) do
        if tower.Name == "Gatling Gun" or tower.Name == "Default" then
            return tower
        end
    end
    return nil
end

-- Get Gatling Network Events
local function getGatlingNetwork()
    local network = ReplicatedStorage:FindFirstChild("Network")
    return network and network:FindFirstChild("GatlingGun")
end

Tab:CreateToggle({
   Name = "Auto Shoot",
   Info = "Automatically target and fire the Gatling Gun",
   CurrentValue = false,
   Flag = "AutoShoot_Toggle",
   Callback = function(Value)
      autoShootEnabled = Value
      print("[TDS] Gatling Auto Shoot toggled to: " .. tostring(Value))
      
      -- Toggle FPS Mode on server when Auto Shoot status changes
      task.spawn(function()
          local myGatling = getMyGatlingGun()
          if myGatling then
              pcall(function()
                  rf:InvokeServer("Troops", "Abilities", "Activate", { 
                      Troop = myGatling, 
                      Name = "FPS", 
                      Data = { enabled = Value } 
                  })
              end)
              
              local gatlingNetwork = getGatlingNetwork()
              local reFps = gatlingNetwork and gatlingNetwork:FindFirstChild("RE:FpsEnabled")
              if reFps then
                  pcall(function()
                      reFps:FireServer(Value)
                  end)
              end
              print("[TDS] AutoShoot: Toggled FPS Mode to " .. tostring(Value))
          end
      end)
   end,
})

-- Helper to retrieve State Attributes (Health, PathDistance) of an NPC model
local function getNPCState(npcModel)
    local rootPointer = npcModel:FindFirstChild("RootPointer")
    if rootPointer and rootPointer.Value then
        local rep = rootPointer.Value
        local hp = rep:GetAttribute("Health") or 0
        local dist = rep:GetAttribute("PathDistance") or 0
        return hp, dist
    end
    
    for _, rep in ipairs(stateReplicators:GetChildren()) do
        if rep.Name == "NPCReplicator" then
            local targetVal = rep:FindFirstChild("Target")
            if targetVal and targetVal.Value == npcModel then
                local hp = rep:GetAttribute("Health") or 0
                local dist = rep:GetAttribute("PathDistance") or 0
                return hp, dist
            end
        end
    end
    
    return 0, 0
end

-- Helper to calculate target ordering based on targetMode
local function getTargets(mode)
    local targets = {}
    for _, npc in ipairs(npcsFolder:GetChildren()) do
        local hpPart = npc:FindFirstChild("HumanoidRootPart") or npc:FindFirstChild("Hitbox")
        if hpPart and npc.Name ~= "Red" and npc.Name ~= "Blue" then
            local hp, progress = getNPCState(npc)
            if hp > 0 or (hp == 0 and progress == 0) then
                table.insert(targets, {
                    Instance = npc,
                    Position = hpPart.Position,
                    Health = hp,
                    Progress = progress
                })
            end
        end
    end
    
    if mode == "First" then
        table.sort(targets, function(a, b) return a.Progress > b.Progress end)
    elseif mode == "Last" then
        table.sort(targets, function(a, b) return a.Progress < b.Progress end)
    elseif mode == "Strongest" then
        table.sort(targets, function(a, b) return a.Health > b.Health end)
    elseif mode == "Random" then
        local rng = Random.new()
        for i = #targets, 2, -1 do
            local j = rng:NextInteger(1, i)
            targets[i], targets[j] = targets[j], targets[i]
        end
    end
    
    return targets
end

-- Target tracking variables
local activeTarget = nil

-- Local Rotate Component Hook (Runs every Heartbeat to face the target properly)
local rotateConnection
rotateConnection = RunService.Heartbeat:Connect(function()
    if getgenv().GatlingScriptID ~= currentScriptID then
        if rotateConnection then rotateConnection:Disconnect() end
        return
    end
    
    if autoShootEnabled and activeTarget and activeTarget.Parent then
        local myGatling = getMyGatlingGun()
        if myGatling and myGatling:FindFirstChild("Rotate") then
            local targetHRP = activeTarget:FindFirstChild("HumanoidRootPart") or activeTarget:FindFirstChild("Hitbox")
            if targetHRP then
                local rotatePart = myGatling.Rotate
                local targetPos = targetHRP.Position
                local lookCF = CFrame.lookAt(
                    rotatePart.Position, 
                    Vector3.new(targetPos.X, rotatePart.Position.Y, targetPos.Z)
                )
                pcall(function()
                    rotatePart.CFrame = lookCF
                end)
            end
        end
    end
end)

-- Thread loop for firing mechanism and target tracking
task.spawn(function()
    local TowerReplicator = require(ReplicatedStorage.Client.Modules.Replicators.TowerReplicator)
    local seqNum = 1
    local lastWarn = 0
    
    while getgenv().GatlingScriptID == currentScriptID do
        local waitTime = 1 / bpsValue
        
        if autoShootEnabled then
            local myGatlingModel = getMyGatlingGun()
            if myGatlingModel then
                local rep = TowerReplicator.getTowerByModel(myGatlingModel)
                if rep then
                    -- 1. Đọc Cooldown thực tế từ Replicator để đồng bộ tốc độ bắn (BPS) chính xác nhất
                    if rep.GetCooldown then
                        local cd = rep:GetCooldown()
                        if cd and cd > 0 then
                            waitTime = cd
                        end
                    elseif rep.Cooldown then
                        if rep.Cooldown > 0 then
                            waitTime = rep.Cooldown
                        end
                    end
                    
                    -- 2. Tự động Reload nếu hết đạn
                    if rep.Ammo and rep.Ammo <= 0 and not rep.Reloading then
                        print("[TDS] AutoShoot: Ammo empty. Triggering Reload...")
                        pcall(function()
                            rep:FireServer("Reload")
                        end)
                        task.wait(2.2) -- Chờ nạp đạn
                    end
                    
                    local targetsList = getTargets(targetMode)
                    if #targetsList > 0 then
                        activeTarget = targetsList[1].Instance
                        
                        -- Đồng bộ các trạng thái bắn cục bộ
                        rep._firing = true
                        rep._allowedToFire = true
                        rep._FPSEnabled = true
                        rep.CanFire = true
                        
                        local count = 0
                        for _, target in ipairs(targetsList) do
                            if count >= multiTargetLimit then break end
                            
                            -- Nhắm thẳng vào giữa thân quái vật trên máy chủ
                            local targetPos = target.Position + Vector3.new(0, 1.4, 0)
                            local targetPosStr = tostring(targetPos)
                            local timestamp = workspace:GetServerTimeNow()
                            
                            -- Lấy điểm đầu nòng súng để vẽ tia đạn bay (VFX)
                            local barrel = myGatlingModel:FindFirstChild("Weapon") 
                                and myGatlingModel.Weapon:FindFirstChild("Main") 
                                and myGatlingModel.Weapon.Main:FindFirstChild("Barrel")
                            local startPos = barrel and barrel.Position or (myGatlingModel.PrimaryPart and myGatlingModel.PrimaryPart.Position + Vector3.new(0, 5, 0)) or targetPos
                            
                            -- A. Đồng bộ hướng ngắm lên Server
                            pcall(function()
                                rep:FireServer("ReplicateAimPosition", targetPosStr)
                            end)
                            
                            -- B. Tạo hiệu ứng đạn bay cục bộ (Visual Bullet)
                            pcall(function()
                                if rep.Bullet then
                                    rep:Bullet({
                                        Start = startPos,
                                        End = targetPos,
                                        Spread = 0.3
                                    })
                                end
                            end)
                            
                            -- C. Gửi yêu cầu bắn đạn thực tế lên Server để gây sát thương
                            pcall(function()
                                rep:FireServer("Fire", targetPosStr, seqNum, timestamp)
                            end)
                            
                            seqNum = seqNum + 1
                            count = count + 1
                        end
                    else
                        activeTarget = nil
                        if rep._firing then
                            rep._firing = false
                            pcall(function()
                                rep:FireServer("StopFiring")
                            end)
                        end
                    end
                else
                    activeTarget = nil
                    if tick() - lastWarn > 10 then
                        warn("[TDS] AutoShoot: TowerReplicator not found for Gatling Gun.")
                        lastWarn = tick()
                    end
                end
            else
                activeTarget = nil
                if tick() - lastWarn > 10 then
                    warn("[TDS] AutoShoot: No Gatling Gun found on map.")
                    lastWarn = tick()
                end
            end
        else
            activeTarget = nil
        end
        
        task.wait(waitTime)
    end
    
    -- Dọn dẹp liên kết khi luồng bị tắt
    if rotateConnection then rotateConnection:Disconnect() end
    print("[TDS] Gatling Gun Old Thread (ID: " .. currentScriptID .. ") Stopped.")
end)

print("[TDS] Gatling Gun Rayfield UI Loaded Successfully! Thread ID: " .. currentScriptID)
