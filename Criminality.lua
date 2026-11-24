-- ============================================================
-- COMPLETE UI + ESP + AIMBOT + LIGHTING
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ============================================================
-- CONFIGURATION
-- ============================================================
local CONFIG = {
    ShowOutline       = true,
    ShowName          = true,
    OutlineColor      = Color3.fromRGB(0, 200, 255),
    NameColor         = Color3.fromRGB(255, 255, 255),
    NameOffset        = 2.5,
    BaseTextSize      = 12,
    ThroughWalls      = true,
    RequireLineOfSight = false, 
    
    RegisterColor      = Color3.fromRGB(0, 255, 0), -- Green
    
    AimTargetPart     = "HumanoidRootPart",
    AimSmoothness     = 1.0,
    AimFOV            = 150,
}

-- ============================================================
-- STATE
-- ============================================================
local espData = {}
local registerEspData = {}

local espEnabled = true
local registerEspEnabled = true
local aimbotEnabled = false
local fullbrightEnabled = false
local removeShadowsEnabled = false
local currentTarget = nil

local cachedMap = nil
local cachedMoneyContainer = nil

-- Store original lighting
local originalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    GlobalShadows = Lighting.GlobalShadows,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart
}

local Keybinds = { ESP = Enum.KeyCode.E, Aimbot = Enum.KeyCode.Q }
local isBindingESP = false
local isBindingAimbot = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function hasLineOfSight(fromPart, toPart, ignoreList)
    rayParams.FilterDescendantsInstances = ignoreList
    local origin    = fromPart.Position
    local direction = toPart.Position - origin
    local result    = workspace:Raycast(origin, direction, rayParams)
    return result == nil or result.Instance == toPart or result.Instance:IsDescendantOf(toPart.Parent)
end

-- ============================================================
-- UI CREATION
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameMenu"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- FOV CIRCLE
local fovCircle = Instance.new("Frame")
fovCircle.BackgroundTransparency = 1
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircle.Size = UDim2.new(0, CONFIG.AimFOV * 2, 0, CONFIG.AimFOV * 2)
fovCircle.Visible = false
fovCircle.Parent = screenGui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255, 255, 255)
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.3
fovStroke.Parent = fovCircle

-- MAIN MENU FRAME
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 500, 0, 450)
mainFrame.Position = UDim2.new(0.5, -250, 0.5, -225)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 8)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 120, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
sidebar.BorderSizePixel = 0
sidebar.Parent = mainFrame
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 8)

local dragBar = Instance.new("TextLabel")
dragBar.Size = UDim2.new(1, -20, 0, 40)
dragBar.Position = UDim2.new(0, 10, 0, 10)
dragBar.BackgroundTransparency = 1
dragBar.Text = "Criminality v1"
dragBar.TextColor3 = Color3.fromRGB(255, 255, 255)
dragBar.Font = Enum.Font.GothamBold
dragBar.TextSize = 16
dragBar.TextXAlignment = Enum.TextXAlignment.Left
dragBar.Parent = sidebar

local tabsContainer = Instance.new("Frame")
tabsContainer.Size = UDim2.new(1, 0, 1, -60)
tabsContainer.Position = UDim2.new(0, 0, 0, 60)
tabsContainer.BackgroundTransparency = 1
tabsContainer.Parent = sidebar

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -120, 1, 0)
contentFrame.Position = UDim2.new(0, 120, 0, 0)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = mainFrame

-- Helper Functions
local function createTabButton(text, yPos)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 36)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Text = "  " .. text
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = tabsContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local function createToggle(parent, yPos, text, defaultState, callback, keybindType)
    local featureFrame = Instance.new("Frame")
    featureFrame.Size = UDim2.new(1, -40, 0, 50)
    featureFrame.Position = UDim2.new(0, 20, 0, yPos)
    featureFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    featureFrame.Parent = parent
    Instance.new("UICorner", featureFrame).CornerRadius = UDim.new(0, 6)

    local featureLabel = Instance.new("TextLabel")
    featureLabel.Size = UDim2.new(0.5, 0, 1, 0)
    featureLabel.Position = UDim2.new(0, 15, 0, 0)
    featureLabel.BackgroundTransparency = 1
    featureLabel.Text = text
    featureLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    featureLabel.Font = Enum.Font.Gotham
    featureLabel.TextSize = 14
    featureLabel.TextXAlignment = Enum.TextXAlignment.Left
    featureLabel.Parent = featureFrame

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(0, 50, 0, 24)
    keybindBtn.Position = UDim2.new(1, -115, 0.5, -12)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    
    if keybindType then
        keybindBtn.Text = "[" .. Keybinds[keybindType].Name .. "]"
        keybindBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        keybindBtn.Font = Enum.Font.GothamBold
        keybindBtn.TextSize = 12
        keybindBtn.Parent = featureFrame
        Instance.new("UICorner", keybindBtn).CornerRadius = UDim.new(0, 4)

        keybindBtn.MouseButton1Click:Connect(function()
            if keybindType == "ESP" then isBindingESP = true else isBindingAimbot = true end
            keybindBtn.Text = "[...]"
            keybindBtn.TextColor3 = Color3.fromRGB(0, 200, 255)
        end)
    else
        keybindBtn.Visible = false
    end

    local toggleBack = Instance.new("Frame")
    toggleBack.Size = UDim2.new(0, 40, 0, 20)
    toggleBack.Position = UDim2.new(1, -55, 0.5, -10)
    toggleBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toggleBack.Parent = featureFrame
    Instance.new("UICorner", toggleBack).CornerRadius = UDim.new(0, 10)

    local toggleKnob = Instance.new("Frame")
    toggleKnob.Size = UDim2.new(0, 16, 0, 16)
    toggleKnob.Position = UDim2.new(0, 2, 0.5, -8)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
    toggleKnob.Parent = toggleBack
    Instance.new("UICorner", toggleKnob).CornerRadius = UDim.new(0, 8)

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(1, 0, 1, 0)
    toggleBtn.BackgroundTransparency = 1
    toggleBtn.Text = ""
    toggleBtn.Parent = toggleBack

    local state = defaultState
    local function updateUI()
        local targetPos = state and UDim2.new(0, 22, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local targetColor = state and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(150, 150, 150)
        TweenService:Create(toggleKnob, TweenInfo.new(0.2), {Position = targetPos, BackgroundColor3 = targetColor}):Play()
        TweenService:Create(toggleBack, TweenInfo.new(0.2), {BackgroundColor3 = state and Color3.fromRGB(0, 100, 130) or Color3.fromRGB(50, 50, 50)}):Play()
    end
    updateUI()

    toggleBtn.MouseButton1Click:Connect(function()
        state = not state
        updateUI()
        callback(state)
    end)

    return { SetState = function(newState) state = newState; updateUI() end, KeybindButton = keybindBtn }
end

local function createSlider(parent, yPos, labelText, minVal, maxVal, defaultVal, isDecimal, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -40, 0, 50)
    frame.Position = UDim2.new(0, 20, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    frame.Parent = parent
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0, 15, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local valueText = Instance.new("TextLabel")
    valueText.Size = UDim2.new(0, 40, 1, 0)
    valueText.Position = UDim2.new(1, -50, 0, 0)
    valueText.BackgroundTransparency = 1
    valueText.Text = isDecimal and string.format("%.1f", defaultVal) or tostring(defaultVal)
    valueText.TextColor3 = Color3.fromRGB(0, 200, 255)
    valueText.Font = Enum.Font.GothamBold
    valueText.TextSize = 14
    valueText.TextXAlignment = Enum.TextXAlignment.Right
    valueText.Parent = frame

    local sliderBack = Instance.new("Frame")
    sliderBack.Size = UDim2.new(0, 120, 0, 6)
    sliderBack.Position = UDim2.new(1, -180, 0.5, -3)
    sliderBack.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sliderBack.Parent = frame
    Instance.new("UICorner", sliderBack).CornerRadius = UDim.new(0, 3)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
    sliderFill.Parent = sliderBack
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 3)

    local sliderBtn = Instance.new("Frame")
    sliderBtn.Size = UDim2.new(0, 14, 0, 14)
    sliderBtn.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), -7, 0.5, -7)
    sliderBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderBtn.Parent = sliderBack
    Instance.new("UICorner", sliderBtn).CornerRadius = UDim.new(0, 7)

    local sliderInput = Instance.new("TextButton")
    sliderInput.Size = UDim2.new(1, 0, 1, 0)
    sliderInput.BackgroundTransparency = 1
    sliderInput.Text = ""
    sliderInput.Parent = sliderBack

    local isDraggingSlider = false
    local function update(inputX)
        local relativeX = math.clamp((inputX - sliderBack.AbsolutePosition.X) / sliderBack.AbsoluteSize.X, 0, 1)
        local val = minVal + (relativeX * (maxVal - minVal))
        if not isDecimal then val = math.floor(val) end
        
        local displayVal = isDecimal and string.format("%.1f", val) or tostring(val)
        valueText.Text = displayVal
        
        sliderFill.Size = UDim2.new(relativeX, 0, 1, 0)
        sliderBtn.Position = UDim2.new(relativeX, -7, 0.5, -7)
        callback(val)
    end

    sliderInput.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingSlider = true
            update(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isDraggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isDraggingSlider = false
        end
    end)
end

-- ============================================================
-- TAB 1: ESP
-- ============================================================
local visualTabBtn = createTabButton("ESP", 0)
local visualsFrame = Instance.new("Frame")
visualsFrame.Size = UDim2.new(1, 0, 1, 0)
visualsFrame.BackgroundTransparency = 1
visualsFrame.Visible = true
visualsFrame.Parent = contentFrame

local visualsTitle = Instance.new("TextLabel")
visualsTitle.Size = UDim2.new(1, -40, 0, 40)
visualsTitle.Position = UDim2.new(0, 20, 0, 20)
visualsTitle.BackgroundTransparency = 1
visualsTitle.Text = "ESP Settings"
visualsTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
visualsTitle.Font = Enum.Font.GothamBold
visualsTitle.TextSize = 18
visualsTitle.TextXAlignment = Enum.TextXAlignment.Left
visualsTitle.Parent = visualsFrame

local espToggleAPI = createToggle(visualsFrame, 70, "Enable Player ESP", true, function(state)
    espEnabled = state
    if not espEnabled then
        for _, data in pairs(espData) do data.highlight.Enabled = false; data.billboard.Enabled = false end
    end
end, "ESP")

createToggle(visualsFrame, 130, "Enable Register ESP", true, function(state)
    registerEspEnabled = state
    if not registerEspEnabled then for _, data in pairs(registerEspData) do data.billboard.Enabled = false end end
end, nil)

-- ============================================================
-- TAB 2: AIMBOT
-- ============================================================
local aimTabBtn = createTabButton("Aimbot", 45)
local aimFrame = Instance.new("Frame")
aimFrame.Size = UDim2.new(1, 0, 1, 0)
aimFrame.BackgroundTransparency = 1
aimFrame.Visible = false
aimFrame.Parent = contentFrame

local aimTitle = Instance.new("TextLabel")
aimTitle.Size = UDim2.new(1, -40, 0, 40)
aimTitle.Position = UDim2.new(0, 20, 0, 20)
aimTitle.BackgroundTransparency = 1
aimTitle.Text = "Aimbot Settings"
aimTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
aimTitle.Font = Enum.Font.GothamBold
aimTitle.TextSize = 18
aimTitle.TextXAlignment = Enum.TextXAlignment.Left
aimTitle.Parent = aimFrame

local aimToggleAPI = createToggle(aimFrame, 70, "Enable Target Lock", false, function(state)
    aimbotEnabled = state
    fovCircle.Visible = state
    if not aimbotEnabled then currentTarget = nil end
end, "Aimbot")

createSlider(aimFrame, 130, "FOV Size", 10, 300, CONFIG.AimFOV, false, function(val)
    CONFIG.AimFOV = val
    fovCircle.Size = UDim2.new(0, val * 2, 0, val * 2)
end)

createSlider(aimFrame, 190, "Smoothness", 0.1, 10.0, CONFIG.AimSmoothness, true, function(val)
    CONFIG.AimSmoothness = val
end)

local partFrame = Instance.new("Frame")
partFrame.Size = UDim2.new(1, -40, 0, 50)
partFrame.Position = UDim2.new(0, 20, 0, 250)
partFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
partFrame.Parent = aimFrame
Instance.new("UICorner", partFrame).CornerRadius = UDim.new(0, 6)

local partLabel = Instance.new("TextLabel")
partLabel.Size = UDim2.new(0.7, 0, 1, 0)
partLabel.Position = UDim2.new(0, 15, 0, 0)
partLabel.BackgroundTransparency = 1
partLabel.Text = "Target Body Part"
partLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
partLabel.Font = Enum.Font.Gotham
partLabel.TextSize = 14
partLabel.TextXAlignment = Enum.TextXAlignment.Left
partLabel.Parent = partFrame

local partBtn = Instance.new("TextButton")
partBtn.Size = UDim2.new(0, 80, 0, 30)
partBtn.Position = UDim2.new(1, -95, 0.5, -15)
partBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
partBtn.Text = "Root"
partBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
partBtn.Font = Enum.Font.Gotham
partBtn.TextSize = 13
partBtn.Parent = partFrame
Instance.new("UICorner", partBtn).CornerRadius = UDim.new(0, 4)

partBtn.MouseButton1Click:Connect(function()
    if CONFIG.AimTargetPart == "HumanoidRootPart" then
        CONFIG.AimTargetPart = "Head"; partBtn.Text = "Head"
    else
        CONFIG.AimTargetPart = "HumanoidRootPart"; partBtn.Text = "Root"
    end
end)

-- ============================================================
-- TAB 3: LIGHTING
-- ============================================================
local lightingTabBtn = createTabButton("Lighting", 90)
local lightingFrame = Instance.new("Frame")
lightingFrame.Size = UDim2.new(1, 0, 1, 0)
lightingFrame.BackgroundTransparency = 1
lightingFrame.Visible = false
lightingFrame.Parent = contentFrame

local lightingTitle = Instance.new("TextLabel")
lightingTitle.Size = UDim2.new(1, -40, 0, 40)
lightingTitle.Position = UDim2.new(0, 20, 0, 20)
lightingTitle.BackgroundTransparency = 1
lightingTitle.Text = "Lighting Settings"
lightingTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
lightingTitle.Font = Enum.Font.GothamBold
lightingTitle.TextSize = 18
lightingTitle.TextXAlignment = Enum.TextXAlignment.Left
lightingTitle.Parent = lightingFrame

local function applyLighting()
    if fullbrightEnabled then
        Lighting.Brightness = 3
        Lighting.ClockTime = 12
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.FogEnd = 100000
        Lighting.FogStart = 0
    else
        Lighting.Brightness = originalLighting.Brightness
        Lighting.ClockTime = originalLighting.ClockTime
        Lighting.Ambient = originalLighting.Ambient
        Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
        Lighting.FogEnd = originalLighting.FogEnd
        Lighting.FogStart = originalLighting.FogStart
    end

    if fullbrightEnabled or removeShadowsEnabled then
        Lighting.GlobalShadows = false
    else
        Lighting.GlobalShadows = originalLighting.GlobalShadows
    end
end

createToggle(lightingFrame, 70, "Fullbrightness", false, function(state)
    fullbrightEnabled = state
    applyLighting()
end, nil)

createToggle(lightingFrame, 130, "Remove Shadows", false, function(state)
    removeShadowsEnabled = state
    applyLighting()
end, nil)

-- Tab Switching Logic
local function switchTab(activeBtn, activeFrame)
    visualTabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    aimTabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    lightingTabBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    
    visualsFrame.Visible = false
    aimFrame.Visible = false
    lightingFrame.Visible = false
    
    activeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    activeFrame.Visible = true
end

visualTabBtn.MouseButton1Click:Connect(function() switchTab(visualTabBtn, visualsFrame) end)
aimTabBtn.MouseButton1Click:Connect(function() switchTab(aimTabBtn, aimFrame) end)
lightingTabBtn.MouseButton1Click:Connect(function() switchTab(lightingTabBtn, lightingFrame) end)

-- Initialize first tab
switchTab(visualTabBtn, visualsFrame)

-- ============================================================
-- KEYBIND LISTENER
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if isBindingESP or isBindingAimbot then
            if key.Value >= Enum.KeyCode.A.Value and key.Value <= Enum.KeyCode.Z.Value then
                if isBindingESP then
                    Keybinds.ESP = key; isBindingESP = false
                    espToggleAPI.KeybindButton.Text = "[" .. key.Name .. "]"; espToggleAPI.KeybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
                elseif isBindingAimbot then
                    Keybinds.Aimbot = key; isBindingAimbot = false
                    aimToggleAPI.KeybindButton.Text = "[" .. key.Name .. "]"; aimToggleAPI.KeybindButton.TextColor3 = Color3.fromRGB(200, 200, 200)
                end
            end
            return
        end

        if key == Keybinds.ESP then
            espEnabled = not espEnabled; espToggleAPI.SetState(espEnabled)
            if not espEnabled then for _, data in pairs(espData) do data.highlight.Enabled = false; data.billboard.Enabled = false end end
        elseif key == Keybinds.Aimbot then
            aimbotEnabled = not aimbotEnabled; aimToggleAPI.SetState(aimbotEnabled); fovCircle.Visible = aimbotEnabled
            if not aimbotEnabled then currentTarget = nil end
        end
    end
end)

-- ============================================================
-- ESP LOGIC
-- ============================================================
local function createESP(player)
    if espData[player] then return espData[player] end
    local data = { highlight = Instance.new("Highlight"), billboard = Instance.new("BillboardGui"), label = Instance.new("TextLabel") }
    data.highlight.FillColor = CONFIG.OutlineColor; data.highlight.FillTransparency = 0.75
    data.highlight.OutlineColor = CONFIG.OutlineColor; data.highlight.OutlineTransparency = 0
    data.highlight.DepthMode = CONFIG.ThroughWalls and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    data.billboard.Size = UDim2.new(0, 200, 0, 32); data.billboard.StudsOffset = Vector3.new(0, CONFIG.NameOffset, 0)
    data.billboard.AlwaysOnTop = CONFIG.ThroughWalls; data.billboard.LightInfluence = 0
    data.label.Size = UDim2.new(1, 0, 1, 0); data.label.BackgroundTransparency = 1
    data.label.Font = Enum.Font.GothamBold; data.label.TextSize = CONFIG.BaseTextSize
    data.label.TextColor3 = CONFIG.NameColor; data.label.TextStrokeTransparency = 0.3
    data.label.Text = player.Name; data.label.Parent = data.billboard
    data.highlight.Parent = screenGui; data.billboard.Parent = screenGui
    espData[player] = data
    return data
end

local function createObjectESP(object, targetPart, color, baseText, dataStore)
    if dataStore[object] then 
        dataStore[object].adornee = targetPart
        return dataStore[object] 
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = baseText .. "ESP"
    billboard.Size = UDim2.new(0, 100, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.TextColor3 = color
    label.TextStrokeTransparency = 0.3
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.Text = baseText .. "\n0m"
    label.Parent = billboard
    
    billboard.Parent = screenGui
    dataStore[object] = { billboard = billboard, label = label, adornee = targetPart, lastDist = -1 }
    return dataStore[object]
end

-- ============================================================
-- MAIN ESP UPDATE LOOP (5 FPS)
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.2)
        local myChar = LocalPlayer.Character
        local originPart = myChar and (myChar:FindFirstChild("Head") or myChar:FindFirstChild("HumanoidRootPart"))
        
        if originPart then
            -- 1. Player ESP
            if espEnabled then
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        local data = espData[player] or createESP(player)
                        local char = player.Character
                        local root = char and char:FindFirstChild("HumanoidRootPart")
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if root and hum and hum.Health > 0 then
                            if data.highlight.Adornee ~= char then data.highlight.Adornee = char; data.billboard.Adornee = root end
                            local visible = true
                            if CONFIG.RequireLineOfSight then visible = hasLineOfSight(originPart, root, {myChar, char}) end
                            data.highlight.Enabled = visible; data.billboard.Enabled = visible
                        else
                            data.highlight.Adornee = nil; data.billboard.Adornee = nil
                            data.highlight.Enabled = false; data.billboard.Enabled = false
                        end
                    end
                end
            end

            -- 2. Register ESP
            if registerEspEnabled then
                if not cachedMap or not cachedMap.Parent then cachedMap = workspace:FindFirstChild("Map") end
                if cachedMap and (not cachedMoneyContainer or not cachedMoneyContainer.Parent) then cachedMoneyContainer = cachedMap:FindFirstChild("BredMakurz") end
                
                if cachedMoneyContainer then
                    for _, obj in ipairs(cachedMoneyContainer:GetChildren()) do
                        local values = obj:FindFirstChild("Values")
                        local broken = values and values:FindFirstChild("Broken")
                        local isRobbed = broken and broken.Value
                        local regPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")

                        if regPart and not isRobbed then
                            local data = createObjectESP(obj, regPart, CONFIG.RegisterColor, "Cash", registerEspData)
                            data.billboard.Adornee = regPart; data.billboard.Enabled = true
                            local dist = math.floor((originPart.Position - regPart.Position).Magnitude)
                            if dist ~= data.lastDist then data.lastDist = dist; data.label.Text = "Cash\n" .. dist .. "m" end
                        elseif registerEspData[obj] then
                            registerEspData[obj].billboard.Enabled = false
                        end
                    end
                end
            end
        end
    end
end)

-- ============================================================
-- OPTIMIZED AIMBOT LOOP
-- ============================================================
local aimTimer = 0
RunService.RenderStepped:Connect(function(dt)
    if not aimbotEnabled then return end
    
    aimTimer = aimTimer + dt
    if aimTimer < 0.05 then return end
    aimTimer = 0

    local myChar = LocalPlayer.Character
    local originPart = myChar and (myChar:FindFirstChild("Head") or myChar:FindFirstChild("HumanoidRootPart"))
    if not originPart then return end

    local closestDist = math.huge
    local bestTarget = nil
    local bestPart = nil
    local centerScreen = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local targetPart = char:FindFirstChild(CONFIG.AimTargetPart)

            if hum and hum.Health > 0 and targetPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distToCenter = (Vector2.new(screenPos.X, screenPos.Y) - centerScreen).Magnitude
                    if distToCenter <= CONFIG.AimFOV then
                        local dist3D = (Camera.CFrame.Position - targetPart.Position).Magnitude
                        if dist3D < closestDist then
                            closestDist = dist3D; bestTarget = player; bestPart = targetPart
                        end
                    end
                end
            end
        end
    end

    if bestTarget and bestPart then
        if hasLineOfSight(originPart, bestPart, {myChar, bestTarget.Character}) then
            currentTarget = bestTarget
            local targetPos = bestPart.Position
            local alpha = math.clamp(1 / CONFIG.AimSmoothness, 0.01, 1)
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, targetPos), alpha)
        else
            currentTarget = nil
        end
    else
        currentTarget = nil
    end
end)

-- ============================================================
-- INITIALIZATION & CLEANUP
-- ============================================================
Players.PlayerAdded:Connect(function(player) if player ~= LocalPlayer then createESP(player) end end)
Players.PlayerRemoving:Connect(function(player)
    if espData[player] then espData[player].highlight:Destroy(); espData[player].billboard:Destroy(); espData[player] = nil end
end)
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createESP(p) end end

-- ============================================================
-- UI DRAGGING LOGIC
-- ============================================================
local dragging = false
local dragInput, mousePos, framePos
dragBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; mousePos = input.Position; framePos = mainFrame.Position end
end)
dragBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
        local delta = input.Position - mousePos
        mainFrame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)