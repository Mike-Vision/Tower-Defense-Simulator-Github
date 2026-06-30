-- gui.lua
-- Rayfield GUI configuration for Gatling Gun automation in TDS (Callback-driven version)

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
   Info = "Sets the firing speed (1 - 26)",
   Range = {1, 26},
   Increment = 1,
   Suffix = "bullets/s",
   CurrentValue = 10,
   Flag = "BPS_Slider",
   Callback = function(Value)
      bpsValue = Value
      print("[TDS] Gatling BPS updated to: " .. tostring(Value))
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
      print("[TDS] Gatling Multi Target updated to: " .. tostring(Value))
   end,
})

Tab:CreateDropdown({
   Name = "Targeting Mode",
   Options = {"First", "Strongest", "Last", "Random"},
   CurrentValue = "First",
   MultipleOptions = false,
   Flag = "Targeting_Dropdown",
   Callback = function(Option)
      targetMode = type(Option) == "table" and Option[1] or Option or "First"
      print("[TDS] Gatling Target Mode updated to: " .. tostring(targetMode))
   end,
})

-- Core Targeting & Firing Logic
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local npcsFolder = workspace:WaitForChild("NPCs")
local rf = ReplicatedStorage:WaitForChild("RemoteFunction")
local stateReplicators = ReplicatedStorage:WaitForChild("StateReplicators")

-- Helper to find active Gatling Gun tower owned by player
local function getMyGatlingGun()
    for _, tower in ipairs(workspace.Towers:GetChildren()) do
        local isOwner = tower:FindFirstChild("Owner") and tower.Owner.Value == game.Players.LocalPlayer.UserId
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
        if hpPart then
            local hp, progress = getNPCState(npc)
            -- If health/progress state couldn't be loaded, default to allowing it
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

-- Dynamic connection getter to prevent infinite yield
local function getGatlingNetwork()
    local network = ReplicatedStorage:FindFirstChild("Network")
    if network then
        return network:FindFirstChild("GatlingGun")
    end
    return nil
end

-- Thread loop for firing mechanism
task.spawn(function()
    local seqNum = 1
    local lastWarn = 0
    while getgenv().GatlingScriptID == currentScriptID do
        if autoShootEnabled then
            local myGatling = getMyGatlingGun()
            if myGatling then
                local gatlingNetwork = getGatlingNetwork()
                if gatlingNetwork then
                    local reFire = gatlingNetwork:FindFirstChild("RE:Fire")
                    local ureAim = gatlingNetwork:FindFirstChild("URE:ReplicateAimPosition")
                    
                    if reFire and ureAim then
                        local targetsList = getTargets(targetMode)
                        local count = 0
                        
                        for _, target in ipairs(targetsList) do
                            if count >= multiTargetLimit then break end
                            
                            local targetPos = target.Position
                            -- Roblox standard vector string representation (e.g. "X, Y, Z")
                            local targetPosStr = tostring(targetPos)
                            local timestamp = workspace:GetServerTimeNow()
                            
                            -- 1. Replicate aim direction for nòng súng
                            pcall(function()
                                ureAim:FireServer(targetPosStr)
                            end)
                            
                            -- 2. Fire bullet event
                            pcall(function()
                                reFire:FireServer(targetPosStr, seqNum, timestamp)
                            end)
                            
                            seqNum = seqNum + 1
                            count = count + 1
                        end
                    end
                else
                    if tick() - lastWarn > 5 then
                        warn("[TDS] AutoShoot: GatlingGun network folder not found. Make sure to place at least one Gatling Gun!")
                        lastWarn = tick()
                    end
                end
            else
                if tick() - lastWarn > 5 then
                    warn("[TDS] AutoShoot: No active Gatling Gun found on map. Place a Gatling Gun to start.")
                    lastWarn = tick()
                end
            end
        end
        task.wait(1 / bpsValue)
    end
    print("[TDS] Gatling Gun Old Thread (ID: " .. currentScriptID .. ") Stopped.")
end)

print("[TDS] Gatling Gun Rayfield UI Loaded Successfully! Thread ID: " .. currentScriptID)
