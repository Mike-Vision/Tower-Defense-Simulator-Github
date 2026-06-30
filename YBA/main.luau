-- main.luau
-- Main script for YBA Automation utilizing Orion Library (ESP, Safe Tween Auto Farm & Jesus TP)

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- Generate a unique ID to clean up old loops on load
local scriptID = game:GetService("HttpService"):GenerateGUID(false)
getgenv().YBAScriptID = scriptID

-- 1. Orion Library Initialization (Using stable community backup link)
local OrionLib = loadstring(game:HttpGet(('https://raw.githubusercontent.com/jensonhirst/Orion/main/source')))()
local Window = OrionLib:MakeWindow({Name = "YBA Automation Hub", HidePremium = true, SaveConfig = false})

local MainTab = Window:MakeTab({
	Name = "Main",
	Icon = "rbxassetid://4483345906",
	PremiumOnly = false
})

-- Feature States
local espEnabled = false
local autoFarmEnabled = false
local tweenSpeed = 70 -- Safe speed studs/second to bypass YBA teleport anti-cheat

-- Status Label for Jesus Spawn
local jesusStatusLabel = MainTab:AddLabel("Jesus Spawned: No")

-- Loop to monitor Jesus Spawn state in real-time
task.spawn(function()
    while getgenv().YBAScriptID == scriptID do
        local dialogues = workspace:FindFirstChild("Dialogues")
        local jesus = dialogues and dialogues:FindFirstChild("Jesus")
        if jesus then
            jesusStatusLabel:Set("Jesus Spawned: Yes")
        else
            jesusStatusLabel:Set("Jesus Spawned: No")
        end
        task.wait(1)
    end
end)

-- Tween & NoClip Helper for safe movement
local isTweening = false
local noclipConnection = nil

local function startNoClip()
    if noclipConnection then return end
    noclipConnection = RunService.Stepped:Connect(function()
        if localPlayer.Character then
            for _, part in ipairs(localPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local function stopNoClip()
    if noclipConnection then
        noclipConnection:Disconnect()
        noclipConnection = nil
    end
end

local function safeTween(targetCFrame)
    local character = localPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local duration = distance / tweenSpeed
    
    isTweening = true
    startNoClip()
    
    -- Anchor Character temporarily to prevent physics jittering during tweening
    hrp.Anchored = true
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    local completed = false
    local connection
    connection = tween.Completed:Connect(function()
        completed = true
        connection:Disconnect()
    end)
    
    tween:Play()
    
    -- Keep checking thread validity while tweening
    while not completed and getgenv().YBAScriptID == scriptID and autoFarmEnabled do
        task.wait()
    end
    
    if not completed then
        tween:Cancel()
    end
    
    hrp.Anchored = false
    stopNoClip()
    isTweening = false
    
    return completed
end

-- Button to Teleport to Jesus NPC safely
MainTab:AddButton({
	Name = "Teleport to Jesus",
	Callback = function()
		local dialogues = workspace:FindFirstChild("Dialogues")
		local jesus = dialogues and dialogues:FindFirstChild("Jesus")
		local jesusHRP = jesus and jesus:FindFirstChild("HumanoidRootPart")
		
		local character = localPlayer.Character
		local myHRP = character and character:FindFirstChild("HumanoidRootPart")
		local myHumanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		
		if myHRP and myHumanoid and myHumanoid.Health > 0 then
			if jesusHRP then
				print("[YBA] Safe Tweening to Jesus...")
                local targetCF = jesusHRP.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.pi, 0)
                task.spawn(function()
                    safeTween(targetCF)
                end)
			else
				OrionLib:MakeNotification({
					Name = "Teleport Failed",
					Content = "Jesus NPC is not spawned in this server!",
					Image = "rbxassetid://4483345906",
					Time = 4
				})
			end
		else
			OrionLib:MakeNotification({
				Name = "Teleport Failed",
				Content = "Your character is dead or not loaded!",
				Image = "rbxassetid://4483345906",
				Time = 3
			})
		end
	end    
})

-- 2. ESP Players Feature (Highlight Method)
local function applyESP(player)
    if player == localPlayer then return end
    
    local function setupHighlight(character)
        if not character then return end
        
        -- Wait for character parts to load
        character:WaitForChild("HumanoidRootPart")
        
        -- Check if highlight already exists
        if character:FindFirstChild("ESPHighlight") then return end
        
        local highlight = Instance.new("Highlight")
        highlight.Name = "ESPHighlight"
        highlight.FillColor = Color3.fromRGB(255, 0, 100)
        highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.Adornee = character
        highlight.Parent = character
        
        -- Create a text tag on head for name and distance
        local head = character:WaitForChild("Head", 5)
        if head and not head:FindFirstChild("ESPNameTag") then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "ESPNameTag"
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.AlwaysOnTop = true
            billboard.ExtentsOffset = Vector3.new(0, 2, 0)
            billboard.Adornee = head
            
            local label = Instance.new("TextLabel")
            label.BackgroundTransparency = 1
            label.Size = UDim2.new(1, 0, 1, 0)
            label.Text = player.Name
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextStrokeTransparency = 0
            label.TextSize = 12
            label.Font = Enum.Font.SourceSansBold
            
            label.Parent = billboard
            billboard.Parent = head
            
            -- Dynamic distance update loop
            task.spawn(function()
                while billboard and billboard.Parent and getgenv().YBAScriptID == scriptID do
                    if espEnabled and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local charHRP = character:FindFirstChild("HumanoidRootPart")
                        local localHRP = localPlayer.Character.HumanoidRootPart
                        if charHRP then
                            local distance = math.round((localHRP.Position - charHRP.Position).Magnitude)
                            label.Text = player.Name .. " [" .. tostring(distance) .. "m]"
                        end
                    end
                    task.wait(0.5)
                end
            end)
        end
    end
    
    if player.Character then
        setupHighlight(player.Character)
    end
    player.CharacterAdded:Connect(setupHighlight)
end

-- Active Player ESP Loop
task.spawn(function()
    while getgenv().YBAScriptID == scriptID do
        if espEnabled then
            for _, player in ipairs(Players:GetPlayers()) do
                pcall(applyESP, player)
            end
        else
            -- Clean up Highlights and Tags if ESP is disabled
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Character then
                    local hl = player.Character:FindFirstChild("ESPHighlight")
                    if hl then hl:Destroy() end
                    local head = player.Character:FindFirstChild("Head")
                    local tag = head and head:FindFirstChild("ESPNameTag")
                    if tag then tag:Destroy() end
                end
            end
        end
        task.wait(1.5)
    end
end)

MainTab:AddToggle({
	Name = "ESP Players",
	Default = false,
	Callback = function(Value)
		espEnabled = Value
		print("[YBA] ESP Players toggled: " .. tostring(Value))
	end    
})

-- 3. Auto Farm Items Feature (Safe Tween & Interact)
local function getItems()
    local items = {}
    local itemSpawns = workspace:FindFirstChild("Item_Spawns")
    local itemsFolder = itemSpawns and itemSpawns:FindFirstChild("Items")
    
    if itemsFolder then
        for _, item in ipairs(itemsFolder:GetChildren()) do
            if item:IsA("Model") then
                table.insert(items, item)
            end
        end
    end
    return items
end

-- Auto Farm Loop
task.spawn(function()
    while getgenv().YBAScriptID == scriptID do
        if autoFarmEnabled then
            local character = localPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
            
            if hrp and humanoid and humanoid.Health > 0 then
                local itemsList = getItems()
                
                for _, item in ipairs(itemsList) do
                    if not autoFarmEnabled then break end
                    if getgenv().YBAScriptID ~= scriptID then break end
                    
                    local itemPart = item:FindFirstChildWhichIsA("MeshPart", true) or item:FindFirstChildWhichIsA("BasePart", true)
                    local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                    
                    if itemPart and prompt and item.Parent then
                        -- Position offset slightly above the item
                        local targetCF = itemPart.CFrame * CFrame.new(0, 1.5, 0)
                        
                        -- Execute safe anti-cheat bypass tween movement
                        local success = safeTween(targetCF)
                        
                        if success then
                            -- Post-movement replication delay (vital for server position sync)
                            task.wait(0.3)
                            
                            -- Activate pickup prompt
                            if prompt and item.Parent then
                                pcall(function()
                                    fireproximityprompt(prompt, 1)
                                end)
                            end
                            task.wait(0.2)
                        end
                    end
                end
            end
        end
        task.wait(1.5)
    end
end)

MainTab:AddToggle({
	Name = "Auto Farm Items",
	Default = false,
	Callback = function(Value)
		autoFarmEnabled = Value
		print("[YBA] Auto Farm Items toggled: " .. tostring(Value))
        if not Value then
            stopNoClip()
            local character = localPlayer.Character
            local hrp = character and character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.Anchored = false end
        end
	end    
})

OrionLib:Init()
print("[YBA] Orion UI and scripts initialized successfully. Thread ID: " .. scriptID)
