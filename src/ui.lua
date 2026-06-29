-- ui.lua
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")

local UI = {}

-- Helper to apply smooth hover tweens on buttons
local function makeInteractive(button, defaultBg, hoverBg, defaultStroke, hoverStroke)
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local sizeTweenIn = TweenService:Create(button, tweenInfo, {Size = UDim2.new(button.Size.X.Scale, button.Size.X.Offset + 4, button.Size.Y.Scale, button.Size.Y.Offset + 2)})
    local sizeTweenOut = TweenService:Create(button, tweenInfo, {Size = button.Size})
    
    local bgTweenIn = TweenService:Create(button, tweenInfo, {BackgroundColor3 = hoverBg})
    local bgTweenOut = TweenService:Create(button, tweenInfo, {BackgroundColor3 = defaultBg})
    
    local stroke = button:FindFirstChildOfClass("UIStroke")
    local strokeTweenIn, strokeTweenOut
    if stroke and hoverStroke then
        strokeTweenIn = TweenService:Create(stroke, tweenInfo, {Color = hoverStroke})
        strokeTweenOut = TweenService:Create(stroke, tweenInfo, {Color = defaultStroke})
    end
    
    button.MouseEnter:Connect(function()
        sizeTweenIn:Play()
        bgTweenIn:Play()
        if strokeTweenIn then strokeTweenIn:Play() end
    end)
    
    button.MouseLeave:Connect(function()
        sizeTweenOut:Play()
        bgTweenOut:Play()
        if strokeTweenOut then strokeTweenOut:Play() end
    end)
end

function UI.create(utils, manualReloadCallback, autoSyncToggleCallback, closeCallback)
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "TDSLoadoutGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 99999
    ScreenGui.Parent = PlayerGui
    
    -- Cleanup existing GUI
    pcall(function()
        for _, child in ipairs(PlayerGui:GetChildren()) do
            if child.Name == "TDSLoadoutGui" and child ~= ScreenGui then
                child:Destroy()
            end
        end
    end)
    
    -- ----------------------------------------------------
    -- Floating Toggle Button (Sleek Circular Design)
    -- ----------------------------------------------------
    local ToggleFloatingBtn = Instance.new("TextButton")
    ToggleFloatingBtn.Name = "ToggleFloatingBtn"
    ToggleFloatingBtn.Size = UDim2.new(0, 52, 0, 52)
    ToggleFloatingBtn.Position = UDim2.new(0.05, 0, 0.3, 0)
    ToggleFloatingBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    ToggleFloatingBtn.BorderSizePixel = 0
    ToggleFloatingBtn.Text = "⚔️"
    ToggleFloatingBtn.TextSize = 26
    ToggleFloatingBtn.ZIndex = 10
    ToggleFloatingBtn.Parent = ScreenGui
    
    local FloatCorner = Instance.new("UICorner")
    FloatCorner.CornerRadius = UDim.new(0, 26)
    FloatCorner.Parent = ToggleFloatingBtn
    
    local FloatStroke = Instance.new("UIStroke")
    FloatStroke.Color = Color3.fromRGB(255, 120, 30)
    FloatStroke.Thickness = 2
    FloatStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    FloatStroke.Parent = ToggleFloatingBtn
    
    local FloatGradient = Instance.new("UIGradient")
    FloatGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 10))
    })
    FloatGradient.Parent = FloatStroke
    
    utils.makeDraggable(ToggleFloatingBtn)
    
    -- Hover effect for floating button
    ToggleFloatingBtn.MouseEnter:Connect(function()
        TweenService:Create(ToggleFloatingBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(45, 45, 55)}):Play()
    end)
    ToggleFloatingBtn.MouseLeave:Connect(function()
        TweenService:Create(ToggleFloatingBtn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(30, 30, 38)}):Play()
    end)
    
    -- ----------------------------------------------------
    -- Main Frame (Clean, Large layout with Modern Styling)
    -- ----------------------------------------------------
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 450, 0, 300)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    MainFrame.Visible = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 14)
    MainCorner.Parent = MainFrame
    
    -- Sleek border with orange-gold gradient
    local MainStroke = Instance.new("UIStroke")
    MainStroke.Color = Color3.fromRGB(255, 255, 255)
    MainStroke.Thickness = 1.2
    MainStroke.Parent = MainFrame
    
    local StrokeGradient = Instance.new("UIGradient")
    StrokeGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 50)),
        ColorSequenceKeypoint.new(0.25, Color3.fromRGB(60, 50, 40)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 22, 20))
    })
    StrokeGradient.Rotation = 90
    StrokeGradient.Parent = MainStroke
    
    -- Left Sidebar Container
    local Sidebar = Instance.new("Frame")
    Sidebar.Name = "Sidebar"
    Sidebar.Size = UDim2.new(0, 140, 1, 0)
    Sidebar.BackgroundColor3 = Color3.fromRGB(11, 11, 14)
    Sidebar.BorderSizePixel = 0
    Sidebar.Parent = MainFrame
    
    local SidebarCorner = Instance.new("UICorner")
    SidebarCorner.CornerRadius = UDim.new(0, 14)
    SidebarCorner.Parent = Sidebar
    
    -- Cover to keep sidebar flush on the right edge
    local SidebarCover = Instance.new("Frame")
    SidebarCover.Size = UDim2.new(0, 15, 1, 0)
    SidebarCover.Position = UDim2.new(1, -15, 0, 0)
    SidebarCover.BackgroundColor3 = Color3.fromRGB(11, 11, 14)
    SidebarCover.BorderSizePixel = 0
    SidebarCover.Parent = Sidebar
    
    -- Logo
    local LogoText = Instance.new("TextLabel")
    LogoText.Size = UDim2.new(1, 0, 0, 50)
    LogoText.BackgroundTransparency = 1
    LogoText.Text = "TDS LOADOUT ⚔️"
    LogoText.TextColor3 = Color3.fromRGB(255, 140, 50)
    LogoText.TextSize = 13
    LogoText.Font = Enum.Font.GothamBold
    LogoText.Parent = Sidebar
    
    -- Left Panel Target Towers List Frame
    local ConfigListFrame = Instance.new("Frame")
    ConfigListFrame.Size = UDim2.new(1, -16, 1, -70)
    ConfigListFrame.Position = UDim2.new(0, 8, 0, 60)
    ConfigListFrame.BackgroundTransparency = 1
    ConfigListFrame.Parent = Sidebar
    
    local ConfigTitle = Instance.new("TextLabel")
    ConfigTitle.Size = UDim2.new(1, 0, 0, 18)
    ConfigTitle.BackgroundTransparency = 1
    ConfigTitle.Text = "🎯 TARGET TOWER (.env)"
    ConfigTitle.TextColor3 = Color3.fromRGB(180, 180, 180)
    ConfigTitle.TextSize = 8
    ConfigTitle.Font = Enum.Font.GothamBold
    ConfigTitle.TextXAlignment = Enum.TextXAlignment.Left
    ConfigTitle.Parent = ConfigListFrame
    
    local ConfigListLayout = Instance.new("UIListLayout")
    ConfigListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ConfigListLayout.Padding = UDim.new(0, 5)
    ConfigListLayout.Parent = ConfigListFrame
    
    -- Keep list labels
    local configLabels = {}
    for i = 1, 5 do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 24)
        lbl.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
        lbl.BorderSizePixel = 0
        lbl.Text = i .. ". Empty"
        lbl.TextColor3 = Color3.fromRGB(130, 130, 130)
        lbl.TextSize = 9
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = ConfigListFrame
        
        local lblCorner = Instance.new("UICorner")
        lblCorner.CornerRadius = UDim.new(0, 6)
        lblCorner.Parent = lbl
        
        local lblPadding = Instance.new("UIPadding")
        lblPadding.PaddingLeft = UDim.new(0, 8)
        lblPadding.Parent = lbl
        
        table.insert(configLabels, lbl)
    end
    
    -- Right Content Panels Area
    local ContentArea = Instance.new("Frame")
    ContentArea.Name = "ContentArea"
    ContentArea.Size = UDim2.new(1, -140, 1, 0)
    ContentArea.Position = UDim2.new(0, 140, 0, 0)
    ContentArea.BackgroundTransparency = 1
    ContentArea.Parent = MainFrame
    
    -- Modern close button
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Name = "CloseBtn"
    CloseBtn.Size = UDim2.new(0, 32, 0, 32)
    CloseBtn.Position = UDim2.new(1, -38, 0, 10)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
    CloseBtn.TextSize = 14
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.ZIndex = 10
    CloseBtn.Parent = ContentArea
    
    local CloseCorner = Instance.new("UICorner")
    CloseCorner.CornerRadius = UDim.new(0, 16)
    CloseCorner.Parent = CloseBtn
    
    local CloseStroke = Instance.new("UIStroke")
    CloseStroke.Color = Color3.fromRGB(45, 45, 52)
    CloseStroke.Thickness = 1
    CloseStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    CloseStroke.Parent = CloseBtn
    
    CloseBtn.MouseEnter:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 50, 50), TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
        TweenService:Create(CloseStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(255, 100, 100)}):Play()
    end)
    CloseBtn.MouseLeave:Connect(function()
        TweenService:Create(CloseBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(25, 25, 30), TextColor3 = Color3.fromRGB(180, 180, 180)}):Play()
        TweenService:Create(CloseStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(45, 45, 52)}):Play()
    end)
    
    -- TitleBar for Dragging Main GUI
    local DragBar = Instance.new("Frame")
    DragBar.Name = "DragBar"
    DragBar.Size = UDim2.new(1, -45, 0, 45)
    DragBar.BackgroundTransparency = 1
    DragBar.Parent = ContentArea
    utils.makeDraggable(DragBar, MainFrame)
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size = UDim2.new(1, -20, 0, 22)
    TitleLabel.Position = UDim2.new(0, 12, 0, 15)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "⚙️ TDS LOADOUT SYNCER"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.TextSize = 13
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
    TitleLabel.Parent = ContentArea
    
    -- Content Card (Main Panel)
    local MainCard = Instance.new("Frame")
    MainCard.Size = UDim2.new(1, -24, 1, -65)
    MainCard.Position = UDim2.new(0, 12, 0, 45)
    MainCard.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    MainCard.Parent = ContentArea
    
    local mcCorner = Instance.new("UICorner")
    mcCorner.CornerRadius = UDim.new(0, 10)
    mcCorner.Parent = MainCard
    
    local mcStroke = Instance.new("UIStroke")
    mcStroke.Color = Color3.fromRGB(35, 35, 42)
    mcStroke.Thickness = 1
    mcStroke.Parent = MainCard
    
    -- ----------------------------------------------------
    -- Toggles & Control Buttons inside MainCard
    -- ----------------------------------------------------
    local AutoSyncContainer = Instance.new("Frame")
    AutoSyncContainer.Size = UDim2.new(1, -20, 0, 36)
    AutoSyncContainer.Position = UDim2.new(0, 10, 0, 10)
    AutoSyncContainer.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
    AutoSyncContainer.Parent = MainCard
    
    local ascCorner = Instance.new("UICorner")
    ascCorner.CornerRadius = UDim.new(0, 8)
    ascCorner.Parent = AutoSyncContainer
    
    local ascStroke = Instance.new("UIStroke")
    ascStroke.Color = Color3.fromRGB(40, 40, 48)
    ascStroke.Thickness = 1
    ascStroke.Parent = AutoSyncContainer
    
    local autoSyncLabel = Instance.new("TextLabel")
    autoSyncLabel.Size = UDim2.new(1, -60, 1, 0)
    autoSyncLabel.Position = UDim2.new(0, 12, 0, 0)
    autoSyncLabel.BackgroundTransparency = 1
    autoSyncLabel.Text = "Auto Sync (Swaps loadout on .env change)"
    autoSyncLabel.TextColor3 = Color3.fromRGB(220, 220, 225)
    autoSyncLabel.TextSize = 10
    autoSyncLabel.Font = Enum.Font.GothamBold
    autoSyncLabel.TextXAlignment = Enum.TextXAlignment.Left
    autoSyncLabel.Parent = AutoSyncContainer
    
    local AutoSyncBtn = Instance.new("TextButton")
    AutoSyncBtn.Size = UDim2.new(0, 38, 0, 20)
    AutoSyncBtn.Position = UDim2.new(1, -50, 0.5, -10)
    AutoSyncBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    AutoSyncBtn.Text = ""
    AutoSyncBtn.BorderSizePixel = 0
    AutoSyncBtn.Parent = AutoSyncContainer
    
    local asbCorner = Instance.new("UICorner")
    asbCorner.CornerRadius = UDim.new(0, 10)
    asbCorner.Parent = AutoSyncBtn
    
    local indicatorDot = Instance.new("Frame")
    indicatorDot.Size = UDim2.new(0, 14, 0, 14)
    indicatorDot.Position = UDim2.new(0, 3, 0.5, -7)
    indicatorDot.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
    indicatorDot.BorderSizePixel = 0
    indicatorDot.Parent = AutoSyncBtn
    
    local idCorner = Instance.new("UICorner")
    idCorner.CornerRadius = UDim.new(0, 7)
    idCorner.Parent = indicatorDot
    
    local autoSyncState = false
    local function updateAutoSyncToggle(state)
        autoSyncState = state
        if autoSyncState then
            TweenService:Create(AutoSyncBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 140, 50)}):Play()
            TweenService:Create(indicatorDot, TweenInfo.new(0.2), {
                Position = UDim2.new(0, 21, 0.5, -7),
                BackgroundColor3 = Color3.fromRGB(40, 200, 40)
            }):Play()
        else
            TweenService:Create(AutoSyncBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 48)}):Play()
            TweenService:Create(indicatorDot, TweenInfo.new(0.2), {
                Position = UDim2.new(0, 3, 0.5, -7),
                BackgroundColor3 = Color3.fromRGB(200, 70, 70)
            }):Play()
        end
    end
    
    AutoSyncBtn.MouseButton1Click:Connect(function()
        autoSyncState = not autoSyncState
        updateAutoSyncToggle(autoSyncState)
        autoSyncToggleCallback(autoSyncState)
    end)
    
    -- Manual Sync Button
    local SyncNowBtn = Instance.new("TextButton")
    SyncNowBtn.Size = UDim2.new(0.45, -5, 0, 32)
    SyncNowBtn.Position = UDim2.new(0, 10, 0, 55)
    SyncNowBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 38)
    SyncNowBtn.Text = "🔄 FORCE SYNC"
    SyncNowBtn.TextColor3 = Color3.fromRGB(255, 140, 50)
    SyncNowBtn.TextSize = 10
    SyncNowBtn.Font = Enum.Font.GothamBold
    SyncNowBtn.Parent = MainCard
    
    local snCorner = Instance.new("UICorner")
    snCorner.CornerRadius = UDim.new(0, 8)
    snCorner.Parent = SyncNowBtn
    
    local snStroke = Instance.new("UIStroke")
    snStroke.Color = Color3.fromRGB(50, 45, 40)
    snStroke.Thickness = 1
    snStroke.Parent = SyncNowBtn
    
    makeInteractive(SyncNowBtn, Color3.fromRGB(30, 30, 38), Color3.fromRGB(40, 40, 52), Color3.fromRGB(50, 45, 40), Color3.fromRGB(255, 140, 50))
    
    SyncNowBtn.MouseButton1Click:Connect(function()
        manualReloadCallback()
    end)
    
    -- Status Card / Output Box
    local StatusCard = Instance.new("Frame")
    StatusCard.Size = UDim2.new(1, -20, 1, -100)
    StatusCard.Position = UDim2.new(0, 10, 0, 95)
    StatusCard.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    StatusCard.Parent = MainCard
    
    local scCorner = Instance.new("UICorner")
    scCorner.CornerRadius = UDim.new(0, 8)
    scCorner.Parent = StatusCard
    
    local scStroke = Instance.new("UIStroke")
    scStroke.Color = Color3.fromRGB(30, 30, 36)
    scStroke.Thickness = 1
    scStroke.Parent = StatusCard
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -20, 1, -20)
    StatusLabel.Position = UDim2.new(0, 10, 0, 10)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Status: Idle\nEquipped PVP: -\nEquipped Normal: -\n\nHint: Edit .env-tower inside your Executor's workspace folder. Put your tower names in double quotes, e.g. {\"Scout\", \"Sniper\"}"
    StatusLabel.TextColor3 = Color3.fromRGB(160, 160, 165)
    StatusLabel.TextSize = 9
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextWrapped = true
    StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusCard
    
    -- Open/Close Animations (Clean Bounce)
    local isMainVisible = true
    local originalSize = UDim2.new(0, 450, 0, 300)
    
    local function openGui()
        isMainVisible = true
        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, 0, 0, 0)
        TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = originalSize
        }):Play()
    end
    
    local function closeGui()
        isMainVisible = false
        local tween = TweenService:Create(MainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0)
        })
        tween:Play()
        tween.Completed:Connect(function()
            if not isMainVisible then
                MainFrame.Visible = false
            end
        end)
    end
    
    -- Drag/Tap detector on Floating button
    local dragStartPos = nil
    ToggleFloatingBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStartPos = input.Position
        end
    end)
    
    ToggleFloatingBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragStartPos then
                local delta = (input.Position - dragStartPos).Magnitude
                if delta < 5 then
                    if isMainVisible then closeGui() else openGui() end
                end
            end
        end
    end)
    
    CloseBtn.MouseButton1Click:Connect(function()
        closeGui()
    end)
    
    -- UI API Object
    local uiApi = {}
    uiApi.ScreenGui = ScreenGui
    
    function uiApi.updateStatus(statusText)
        StatusLabel.Text = statusText
    end
    
    function uiApi.updateConfigList(towerList)
        for i = 1, 5 do
            local lbl = configLabels[i]
            local val = towerList[i]
            if val then
                lbl.Text = i .. ". " .. tostring(val)
                lbl.TextColor3 = Color3.fromRGB(240, 240, 240)
            else
                lbl.Text = i .. ". -"
                lbl.TextColor3 = Color3.fromRGB(100, 100, 100)
            end
        end
    end
    
    return uiApi
end

return UI
