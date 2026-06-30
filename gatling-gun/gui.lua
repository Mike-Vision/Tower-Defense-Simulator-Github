-- gui.lua
-- Rayfield GUI configuration for Gatling Gun automation in TDS (Non-blocking version)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Gatling Gun Control",
   LoadingTitle = "TDS Gatling Gun Loader",
   LoadingSubtitle = "by Antigravity & Mike-vision",
   Theme = "Default",
   DisableRayfieldPrompts = false
})

local Tab = Window:CreateTab("Gatling Automation", 4483362458) -- Title, ImageID

-- Control variables
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
      targetMode = Option[1] or Option
   end,
})

Tab:CreateToggle({
   Name = "Auto Shoot",
   Info = "Automatically target and fire the Gatling Gun",
   CurrentValue = false,
   Flag = "AutoShoot_Toggle",
   Callback = function(Value)
      autoShootEnabled = Value
   end,
})

-- Core Targeting & Firing Logic
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local npcsFolder = workspace:WaitForChild("NPCs")

-- Helper to find active Gatling Gun tower owned by player
local function getMyGatlingGun()
    for _, tower in ipairs(workspace.Towers:GetChildren()) do
        if tower.Name == "Gatling Gun" and tower:FindFirstChild("Owner") and tower.Owner.Value == game.Players.LocalPlayer.UserId then
            return tower
        end
    end
    for _, tower in ipairs(workspace.Towers:GetChildren()) do
        if tower.Name == "Gatling Gun" then
            return tower
        end
    end
    return nil
end

-- Helper to calculate target ordering based on targetMode
local function getTargets()
    local targets = {}
    for _, npc in ipairs(npcsFolder:GetChildren()) do
        local hpPart = npc:FindFirstChild("HumanoidRootPart")
        local healthVal = npc:FindFirstChild("Health") or npc:FindFirstChild("HealthValue")
        if hpPart and (not healthVal or healthVal.Value > 0) then
            local progress = npc:GetAttribute("Progress") or 0
            table.insert(targets, {
                Instance = npc,
                Position = hpPart.Position,
                Health = healthVal and healthVal.Value or 1,
                Progress = progress
            })
        end
    end
    
    if targetMode == "First" then
        table.sort(targets, function(a, b) return a.Progress > b.Progress end)
    elseif targetMode == "Last" then
        table.sort(targets, function(a, b) return a.Progress < b.Progress end)
    elseif targetMode == "Strongest" then
        table.sort(targets, function(a, b) return a.Health > b.Health end)
    elseif targetMode == "Random" then
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
    while true do
        if autoShootEnabled then
            local myGatling = getMyGatlingGun()
            if myGatling then
                local gatlingNetwork = getGatlingNetwork()
                if gatlingNetwork then
                    local reFire = gatlingNetwork:FindFirstChild("RE:Fire")
                    local ureAim = gatlingNetwork:FindFirstChild("URE:ReplicateAimPosition")
                    
                    if reFire and ureAim then
                        local targetsList = getTargets()
                        local count = 0
                        
                        for _, target in ipairs(targetsList) do
                            if count >= multiTargetLimit then break end
                            
                            local targetPos = target.Position
                            local targetPosStr = string.format("%f, %f, %f", targetPos.X, targetPos.Y, targetPos.Z)
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
end)

print("[TDS] Gatling Gun Rayfield UI Loaded Successfully!")
