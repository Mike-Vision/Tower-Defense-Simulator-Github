-- gui.lua
-- Rayfield GUI configuration for Gatling Gun automation in TDS (Virtual Mouse Input Version)

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
local mouse = localPlayer:GetMouse()

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
      
      -- Release mouse button when toggled off
      if not Value then
          pcall(mouse1release)
      end
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

-- Active tracking target variable for the Mouse Hook
local currentTarget = nil

-- Hook Mouse.Hit safely (Only once to prevent C stack overflow)
pcall(function()
    local mouseMT = getrawmetatable(mouse)
    if mouseMT and mouseMT.__index and not getgenv().GatlingMouseHooked then
        getgenv().GatlingMouseHooked = true
        local rawIndex = mouseMT.__index
        
        setreadonly(mouseMT, false)
        mouseMT.__index = newcclosure(function(self, key)
            if autoShootEnabled and currentTarget and currentTarget.Parent and self == mouse and key == "Hit" then
                local hitBox = currentTarget:FindFirstChild("Hitbox") or currentTarget:FindFirstChild("HumanoidRootPart")
                if hitBox then
                    -- Target center body offset
                    return CFrame.new(hitBox.Position + Vector3.new(0, 1.4, 0))
                end
            end
            return rawIndex(self, key)
        end)
        setreadonly(mouseMT, true)
        print("[TDS] Mouse Hook active for Auto Aim.")
    end
end)

-- Thread loop for firing mechanism using Virtual Mouse Inputs
task.spawn(function()
    local mousePressed = false
    
    while getgenv().GatlingScriptID == currentScriptID do
        if autoShootEnabled then
            local targetsList = getTargets(targetMode)
            
            if #targetsList > 0 then
                -- Set target for the safe Mouse Hook to rotate the gun visual
                currentTarget = targetsList[1].Instance
                
                -- Simulate holding MouseButton1 (left click)
                if not mousePressed then
                    pcall(mouse1press)
                    mousePressed = true
                end
                
                -- If BPS is customized (e.g. less than max speed), spam click to rate limit firing
                if bpsValue < 26 then
                    pcall(mouse1release)
                    task.wait(0.01)
                    pcall(mouse1press)
                end
            else
                currentTarget = nil
                if mousePressed then
                    pcall(mouse1release)
                    mousePressed = false
                end
            end
        else
            currentTarget = nil
            if mousePressed then
                pcall(mouse1release)
                mousePressed = false
            end
        end
        
        -- Loop frequency
        task.wait(1 / bpsValue)
    end
    
    -- Safety release when thread stops
    pcall(mouse1release)
    print("[TDS] Gatling Gun Old Thread (ID: " .. currentScriptID .. ") Stopped.")
end)

print("[TDS] Gatling Gun Rayfield UI Loaded Successfully! Thread ID: " .. currentScriptID)
