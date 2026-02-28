-- [ SERVICES ]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Camera = Workspace.CurrentCamera

-- [ LOCAL PLAYER ]
local lp = Players.LocalPlayer
local mouse = lp:GetMouse()

-- [ ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ]
sg = nil
mf = nil
settingsFrame = nil
cam = Camera

-- [ НАСТРОЙКИ ] (ДОБАВЛЕН camera_fov)
local vars = {
    -- Aim Settings
    aimlock = false,
    aim_part = "Head",
    available_parts = {"Head", "UpperTorso", "HumanoidRootPart", "LowerTorso"},
    teamcheck = false,
    smooth = 0.08,
    prediction = 0.13,
    fov = 120,        -- FOV КРУГ АИМБОТА
    camera_fov = 70,  -- FOV КАМЕРЫ
    wallcheck = true,
    autofire = false,
    lastfire = 0,
    aim_bind = Enum.UserInputType.MouseButton2,

    -- Visual Settings
    esp = true,
    fov_circle = true,
    nightvision = false,
    color = Color3.fromRGB(255, 182, 193),
    tracers = false,
    tracer_duration = 0.8,

    -- Movement & Fun
    bunnyhop = false,
    bhspeed = 45,
    spinbot = false,
    spinspeed = 15,
    walkspeed = 16,
    full_overhaul = false,
    skybox_id = "rbxassetid://159414210",

    -- Internal
    target = nil,
    whitelist = {players = {}}
}

-- [ ФУНКЦИЯ ЗАЩИТЫ ]
local function gethui()
    local success, target = pcall(function() return CoreGui end)
    if success and target then return target end
    return lp:WaitForChild("PlayerGui")
end

-- [ FOV CIRCLE CONSTRUCTION ]
local fov_circle_draw = Drawing.new("Circle")
fov_circle_draw.Visible = true
fov_circle_draw.Thickness = 1
fov_circle_draw.NumSides = 60
fov_circle_draw.Filled = false
fov_circle_draw.Transparency = 1
fov_circle_draw.Color = vars.color

-- [ UI OBJECT REFERENCES ]
local wl_frame, wl_scroll, distlbl

-- [ UTILITY FUNCTIONS ]
local function isVisible(targetPart, targetPlayer)
    if not vars.wallcheck then return true end
    
    local rayOrigin = cam.CFrame.Position
    local rayDirection = (targetPart.Position - rayOrigin)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {lp.Character, cam}
    
    local result = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    
    if result then
        local hit = result.Instance
        return hit:IsDescendantOf(targetPlayer.Character)
    end
    return true
end

local function getClosestPlayer()
    local closest = nil
    local maxDist = vars.fov

    for _, v in pairs(Players:GetPlayers()) do
        if v ~= lp and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            if vars.teamcheck and v.Team == lp.Team then continue end
            
            local part = v.Character:FindFirstChild(vars.aim_part) or v.Character.HumanoidRootPart
            if vars.wallcheck and not isVisible(part, v) then continue end

            local pos, onScreen = cam:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
            if onScreen then
                local dist = (Vector2.new(mouse.X, mouse.Y) - Vector2.new(pos.X, pos.Y)).Magnitude
                if dist < maxDist then
                    maxDist = dist
                    closest = v
                end
            end
        end
    end
    return closest
end

local function triggerWeapon()
    local char = lp.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
    end
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.delay(0.01, function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

-- [ LIGHTING CONTROLS ]
local function updateNightVision()
    local nv = Lighting:FindFirstChild("KorpseNightVision")
    if not nv then
        nv = Instance.new("ColorCorrectionEffect")
        nv.Name = "KorpseNightVision"
        nv.Parent = Lighting
    end
    
    if vars.nightvision then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        nv.Enabled = true
        nv.Brightness = 0.5
        nv.Contrast = 0.5
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        nv.Enabled = false
    end
end

local function ApplyTotalOverhaul()
    for _, obj in pairs(Lighting:GetChildren()) do
        if obj:IsA("Sky") or obj:IsA("ColorCorrectionEffect") then obj:Destroy() end
    end
    
    if vars.full_overhaul then
        local sky = Instance.new("Sky", Lighting)
        sky.SkyboxBk = vars.skybox_id
        sky.SkyboxDn = vars.skybox_id
        sky.SkyboxFt = vars.skybox_id
        sky.SkyboxLf = vars.skybox_id
        sky.SkyboxRt = vars.skybox_id
        sky.SkyboxUp = vars.skybox_id
        sky.SunAngularSize = 0

        local cc = Instance.new("ColorCorrectionEffect", Lighting)
        cc.Contrast = 0.05
        cc.Saturation = 0.2
        cc.TintColor = vars.color:Lerp(Color3.new(1, 1, 1), 0.5)

        Lighting.FogColor = vars.color
        Lighting.FogEnd = 500
        Lighting.Ambient = vars.color
        Lighting.OutdoorAmbient = vars.color
        Lighting.GlobalShadows = false
        Lighting.Brightness = 2
    else
        Lighting.Ambient = Color3.fromRGB(127, 127, 127)
        Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 100000
        Lighting.Brightness = 1
    end
end

local function CreatePowerTracer(from, to)
    if not vars.tracers then return end

    local tracerModel = Instance.new("Part")
    tracerModel.Name = "StaticTracer"
    tracerModel.Anchored = true
    tracerModel.CanCollide = false
    tracerModel.Transparency = 1
    tracerModel.Position = from
    tracerModel.Parent = Workspace.Terrain

    local a0 = Instance.new("Attachment", tracerModel)
    local a1 = Instance.new("Attachment", tracerModel)
    a1.WorldPosition = to 

    local beam = Instance.new("Beam", tracerModel)
    beam.Attachment0 = a0
    beam.Attachment1 = a1
    beam.Color = ColorSequence.new(vars.color)
    beam.Width0 = 0.3
    beam.Width1 = 0.3
    beam.LightEmission = 1
    beam.Brightness = 5
    beam.Texture = "rbxassetid://446111271"
    beam.TextureSpeed = 0
    
    game:GetService("Debris"):AddItem(tracerModel, vars.tracer_duration)
end

-- [ WHITELIST UI UPDATE ]
local function refreshWhitelist()
    if not wl_scroll then return end
    wl_scroll:ClearAllChildren()
    
    local uiList = Instance.new("UIListLayout")
    uiList.Parent = wl_scroll
    uiList.Padding = UDim.new(0, 6)
    uiList.SortOrder = Enum.SortOrder.LayoutOrder
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= lp then
            local entry = Instance.new("TextButton")
            entry.Name = player.Name
            entry.Size = UDim2.new(1, -10, 0, 35)
            entry.BackgroundColor3 = vars.whitelist.players[player.Name] and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(35, 35, 35)
            entry.BorderSizePixel = 0
            entry.Text = "  " .. player.DisplayName .. " (@ " .. player.Name .. ")"
            entry.TextColor3 = Color3.fromRGB(255, 255, 255)
            entry.TextXAlignment = Enum.TextXAlignment.Left
            entry.Font = Enum.Font.SourceSans
            entry.TextSize = 14
            entry.Parent = wl_scroll
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = entry
            
            entry.MouseButton1Click:Connect(function()
                vars.whitelist.players[player.Name] = not vars.whitelist.players[player.Name]
                entry.BackgroundColor3 = vars.whitelist.players[player.Name] and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(35, 35, 35)
            end)
        end
    end
    wl_scroll.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 10)
end

local function buildAimSettings()
    settingsFrame = Instance.new("Frame")
    settingsFrame.Name = "AimExtraSettings"
    settingsFrame.Size = UDim2.new(0, 220, 0, 220)
    settingsFrame.Position = UDim2.new(1, 10, 0, 0) 
    settingsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    settingsFrame.Visible = false
    settingsFrame.Parent = mf 
    
    Instance.new("UICorner", settingsFrame).CornerRadius = UDim.new(0, 10)
    local stroke = Instance.new("UIStroke", settingsFrame)
    stroke.Name = "AimStroke"
    stroke.Color = vars.color
    stroke.Thickness = 2

    local stitle = Instance.new("TextLabel", settingsFrame)
    stitle.Name = "AimTitle"
    stitle.Size = UDim2.new(1, 0, 0, 35)
    stitle.Text = "AIMBOT SETTINGS"
    stitle.TextColor3 = vars.color
    stitle.BackgroundTransparency = 1
    stitle.Font = Enum.Font.SourceSansBold
    stitle.TextSize = 16

    local partBtn = Instance.new("TextButton", settingsFrame)
    partBtn.Size = UDim2.new(1, -20, 0, 30)
    partBtn.Position = UDim2.new(0, 10, 0, 40)
    partBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    partBtn.Text = "Target: " .. (vars.aim_part or "Head")
    partBtn.TextColor3 = Color3.new(1, 1, 1)
    partBtn.Font = Enum.Font.SourceSans
    Instance.new("UICorner", partBtn).CornerRadius = UDim.new(0, 6)

    local pIdx = 1
    partBtn.MouseButton1Click:Connect(function()
        pIdx = pIdx + 1
        if pIdx > #vars.available_parts then pIdx = 1 end
        vars.aim_part = vars.available_parts[pIdx]
        partBtn.Text = "Target: " .. vars.aim_part
    end)

    local function addMiniSlider(name, min, max, def, y, callback)
        local sLabel = Instance.new("TextLabel", settingsFrame)
        sLabel.Size = UDim2.new(1, -20, 0, 20)
        sLabel.Position = UDim2.new(0, 10, 0, y)
        sLabel.Text = name .. " (" .. def .. ")"
        sLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
        sLabel.BackgroundTransparency = 1
        sLabel.Font = Enum.Font.SourceSans
        sLabel.TextXAlignment = Enum.TextXAlignment.Left

        local sTray = Instance.new("Frame", settingsFrame)
        sTray.Size = UDim2.new(1, -20, 0, 4)
        sTray.Position = UDim2.new(0, 10, 0, y + 22)
        sTray.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        sTray.BorderSizePixel = 0
        
        local sFill = Instance.new("Frame", sTray)
        sFill.Size = UDim2.new(math.clamp((def - min) / (max - min), 0, 1), 0, 1, 0)
        sFill.BackgroundColor3 = vars.color
        sFill.BorderSizePixel = 0

        local dragging = false
        local function update()
            local mousePos = UserInputService:GetMouseLocation().X
            local relX = math.clamp((mousePos - sTray.AbsolutePosition.X) / sTray.AbsoluteSize.X, 0, 1)
            local val = math.floor((min + (max - min) * relX) * 100) / 100
            sFill.Size = UDim2.new(relX, 0, 1, 0)
            sLabel.Text = name .. " (" .. val .. ")"
            callback(val)
        end

        sTray.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true update() end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then update() end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
    end

    addMiniSlider("Smoothness", 0.01, 1, vars.smooth, 80, function(v) vars.smooth = v end)
    addMiniSlider("FOV Radius", 10, 600, vars.fov, 120, function(v) vars.fov = v end)
    addMiniSlider("Prediction", 0.01, 0.5, vars.prediction, 160, function(v) vars.prediction = v end)
end

-- [ GUI CONSTRUCTION ] (УДАЛЕНА Head Aim кнопка, ДОБАВЛЕН Camera FOV ползунок)
local function buildGUI()
    sg = Instance.new("ScreenGui")
    sg.Name = "Aimlock_v29"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = gethui()
    
    mf = Instance.new("Frame")
    mf.Name = "MainFrame"
    mf.Size = UDim2.new(0, 340, 0, 600)
    mf.Position = UDim2.new(1, -360, 0.5, -250)
    mf.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mf.BorderSizePixel = 0
    mf.Active = true
    mf.Draggable = true
    mf.Parent = sg
    
    local mfCorner = Instance.new("UICorner")
    mfCorner.CornerRadius = UDim.new(0, 12)
    mfCorner.Parent = mf
    
    local mfStroke = Instance.new("UIStroke")
    mfStroke.Name = "GlowStroke"
    mfStroke.Color = vars.color
    mfStroke.Thickness = 2
    mfStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mfStroke.Parent = mf
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 45)
    title.Position = UDim2.new(0, 0, 0, 5)
    title.BackgroundTransparency = 1
    title.Text = "korpsebunny GUI v2.9.5"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 22
    title.Parent = mf
    
    local function addToggle(name, vName, x, y)
        local btn = Instance.new("TextButton")
        btn.Name = name .. "_Toggle"
        btn.Size = UDim2.new(0, 150, 0, 32)
        btn.Position = UDim2.new(0, x, 0, y)
        btn.BackgroundColor3 = vars[vName] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(35, 35, 35)
        btn.BorderSizePixel = 0
        btn.Text = name .. ": " .. (vars[vName] and "ON" or "OFF")
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 16
        btn.Parent = mf
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            vars[vName] = not vars[vName]
            btn.Text = name .. ": " .. (vars[vName] and "ON" or "OFF")
            
            local targetColor = vars[vName] and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(35, 35, 35)
            TweenService:Create(btn, TweenInfo.new(0.25), {BackgroundColor3 = targetColor}):Play()
            
            if vName == "nightvision" then updateNightVision() end
            if vName == "full_overhaul" then ApplyTotalOverhaul() end
            if vName == "whitelist" then
                if wl_frame then wl_frame.Visible = vars.whitelist end
                if vars.whitelist then refreshWhitelist() end
            end
        end)
        return btn
    end
    
    -- КНОПКИ (УДАЛЕНА Head Aim)
    local aimBtn = addToggle("Aimlock", "aimlock", 10, 55)
    aimBtn.MouseButton2Click:Connect(function()
        if settingsFrame then
            settingsFrame.Visible = not settingsFrame.Visible
        end
    end)
    
    addToggle("AutoFire", "autofire", 175, 55)
    addToggle("ESP", "esp", 10, 95)
    addToggle("WallCheck", "wallcheck", 175, 95)
    addToggle("Spinbot", "spinbot", 10, 135)
    addToggle("Bunnyhop", "bunnyhop", 175, 135)
    addToggle("NightVision", "nightvision", 10, 175)
    addToggle("Bullet Tracers", "tracers", 175, 175)
    addToggle("World Mod", "full_overhaul", 10, 215)
    addToggle("Whitelist", "whitelist", 175, 215)
    addToggle("Team Check", "teamcheck", 10, 255)
    
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = "SliderSection"
    sliderFrame.Size = UDim2.new(1, -20, 0, 240)
    sliderFrame.Position = UDim2.new(0, 10, 0, 305)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = mf
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 500)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = vars.color
    scroll.Parent = sliderFrame
    
    local function addSlider(name, min, max, def, y, callback)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 240, 0, 20)
        label.Position = UDim2.new(0, 10, 0, y)
        label.BackgroundTransparency = 1
        label.Text = name .. " (" .. def .. ")"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Font = Enum.Font.SourceSans
        label.Parent = scroll
        
        local tray = Instance.new("Frame")
        tray.Size = UDim2.new(0, 240, 0, 8)
        tray.Position = UDim2.new(0, 10, 0, y + 24)
        tray.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        tray.Parent = scroll
        Instance.new("UICorner", tray).CornerRadius = UDim.new(0, 4)
        
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((def - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = vars.color
        fill.Parent = tray
        Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)
        
        local dragging = false
        
        local function update()
            local mouseX = UserInputService:GetMouseLocation().X
            local relX = math.clamp((mouseX - tray.AbsolutePosition.X) / tray.AbsoluteSize.X, 0, 1)
            local val = math.floor((min + (max - min) * relX) * 100) / 100
            
            fill.Size = UDim2.new(relX, 0, 1, 0)
            label.Text = name .. " (" .. val .. ")"
            callback(val)
        end
        
        tray.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                update()
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                update()
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end
    
    -- ПОЛЗУНКИ (FOV Radius = FOV КРУГА, Camera FOV = FOV КАМЕРЫ)
    addSlider("Camera FOV", 10, 120, vars.camera_fov, 65, function(v) 
        vars.camera_fov = v
        cam.FieldOfView = v
    end)
    addSlider("Spin Speed", 1, 100, vars.spinspeed, 120, function(v) vars.spinspeed = v end)
    addSlider("Bhop Speed", 16, 150, vars.bhspeed, 175, function(v) vars.bhspeed = v end)
    addSlider("WalkSpeed", 16, 250, vars.walkspeed, 230, function(v) vars.walkspeed = v end)
    
    local bindBtn = Instance.new("TextButton")
    bindBtn.Name = "AimBind_Button"
    bindBtn.Size = UDim2.new(0, 240, 0, 32)
    bindBtn.Position = UDim2.new(0, 10, 0, 290)
    bindBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    bindBtn.Text = "Aim Bind: " .. vars.aim_bind.Name
    bindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    bindBtn.Font = Enum.Font.SourceSans
    bindBtn.TextSize = 16
    bindBtn.Parent = scroll
    Instance.new("UICorner", bindBtn).CornerRadius = UDim.new(0, 8)

    local listening = false
    bindBtn.MouseButton1Click:Connect(function()
        listening = true
        bindBtn.Text = "... Press Key ..."
        bindBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end)

    UserInputService.InputBegan:Connect(function(input)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                vars.aim_bind = input.KeyCode
            elseif input.UserInputType.Name:find("MouseButton") then
                vars.aim_bind = input.UserInputType
            end
            bindBtn.Text = "Aim Bind: " .. vars.aim_bind.Name
            bindBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            listening = false
        end
    end)
    
    local themeContainer = Instance.new("Frame")
    themeContainer.Size = UDim2.new(1, -20, 0, 45)
    themeContainer.Position = UDim2.new(0, 10, 0, 520)
    themeContainer.BackgroundTransparency = 1
    themeContainer.Parent = mf
    
    local themes = {
        {Color3.fromRGB(220, 20, 60), "Red"},
        {Color3.fromRGB(128, 0, 128), "Purple"},
        {Color3.fromRGB(60, 179, 113), "Green"},
        {Color3.fromRGB(255, 182, 193), "Pink"}
    }
    
    for i, t in ipairs(themes) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0, 72, 0, 32)
        tb.Position = UDim2.new(0, (i - 1) * 82, 0, 5)
        tb.BackgroundColor3 = t[1]
        tb.Text = t[2]
        tb.TextColor3 = Color3.fromRGB(255, 255, 255)
        tb.Font = Enum.Font.SourceSansBold
        tb.Parent = themeContainer
        Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 8)
        
        tb.MouseButton1Click:Connect(function()
            vars.color = t[1]
            mfStroke.Color = t[1]
            scroll.ScrollBarImageColor3 = t[1]
            
            if settingsFrame then
                local s = settingsFrame:FindFirstChild("AimStroke")
                if s then s.Color = t[1] end
                local tit = settingsFrame:FindFirstChild("AimTitle")
                if tit then tit.TextColor3 = t[1] end
            end
            
            if wl_frame then 
                local stroke = wl_frame:FindFirstChild("UIStroke")
                if stroke then stroke.Color = t[1] end
            end
            
            if vars.full_overhaul then ApplyTotalOverhaul() end
        end)
    end
    
    distlbl = Instance.new("TextLabel")
    distlbl.Size = UDim2.new(1, 0, 0, 30)
    distlbl.Position = UDim2.new(0, 0, 1, -38)
    distlbl.BackgroundTransparency = 1
    distlbl.Text = "Target Distance: N/A"
    distlbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distlbl.Font = Enum.Font.SourceSansItalic
    distlbl.TextSize = 15
    distlbl.Parent = mf

    wl_frame = Instance.new("Frame")
    wl_frame.Name = "WhitelistFrame"
    wl_frame.Size = UDim2.new(0, 240, 0, 420)
    wl_frame.Position = UDim2.new(1, -610, 0.5, -210)
    wl_frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    wl_frame.BorderSizePixel = 0
    wl_frame.Visible = false
    wl_frame.Parent = sg
    
    Instance.new("UICorner", wl_frame).CornerRadius = UDim.new(0, 10)
    local wlStroke = Instance.new("UIStroke", wl_frame)
    wlStroke.Color = vars.color
    wlStroke.Thickness = 2
    
    local wlTitle = Instance.new("TextLabel")
    wlTitle.Size = UDim2.new(1, 0, 0, 40)
    wlTitle.BackgroundTransparency = 1
    wlTitle.Text = "WHITELIST MANAGER"
    wlTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    wlTitle.Font = Enum.Font.SourceSansBold
    wlTitle.TextSize = 18
    wlTitle.Parent = wl_frame
    
    wl_scroll = Instance.new("ScrollingFrame")
    wl_scroll.Size = UDim2.new(1, -15, 1, -55)
    wl_scroll.Position = UDim2.new(0, 7, 0, 45)
    wl_scroll.BackgroundTransparency = 1
    wl_scroll.ScrollBarThickness = 2
    wl_scroll.Parent = wl_frame
    
    buildAimSettings()
end

-- [ MAIN RENDER LOOP ]
local tracerDebounce = false

RunService.RenderStepped:Connect(function()
    -- FOV КРУГ АИМБОТА всегда работает
    fov_circle_draw.Radius = vars.fov
    fov_circle_draw.Position = Vector2.new(mouse.X, mouse.Y + 36)
    fov_circle_draw.Color = vars.color
    
    -- Camera FOV всегда применяется
    cam.FieldOfView = vars.camera_fov

    -- Aim logic
    if vars.aimlock then
        local target = getClosestPlayer()
        if target and target.Character then
            vars.target = target
            local targetPart = target.Character:FindFirstChild(vars.aim_part) or target.Character.HumanoidRootPart
            
            if targetPart then
                local lookAt = targetPart.Position
                if vars.prediction > 0 then
                    lookAt = lookAt + (targetPart.AssemblyLinearVelocity * vars.prediction)
                end
                
                local lookCFrame = CFrame.lookAt(cam.CFrame.Position, lookAt)
                cam.CFrame = cam.CFrame:Lerp(lookCFrame, vars.smooth)
                
                if vars.autofire then
                    local screenPos, onScreen = cam:WorldToViewportPoint(targetPart.Position)
                    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
                    local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    
                    if mouseDist < 10 and (tick() - vars.lastfire >= 0.05) then
                        vars.lastfire = tick()
                        task.spawn(triggerWeapon)
                    end
                end
                
                if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (lp.Character.HumanoidRootPart.Position - targetPart.Position).Magnitude
                    distlbl.Text = "Target: " .. target.DisplayName .. " [" .. math.floor(d) .. " studs]"
                end
            end
        else
            vars.target = nil
            distlbl.Text = "Target Distance: N/A"
        end
    end
    
    -- Bunnyhop
    if vars.bunnyhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        if hrp and hum then
            if hum.FloorMaterial ~= Enum.Material.Air then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                local moveStep = moveDir * (vars.bhspeed / 60)
                hrp.CFrame = hrp.CFrame + moveStep
                hrp.Velocity = Vector3.new(moveDir.X * 5, hrp.Velocity.Y, moveDir.Z * 5)
            end
        end
    end

    -- Spinbot
    if vars.spinbot and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(vars.spinspeed), 0)
    end
    
    -- ESP
    if vars.esp then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character then
                local h = plr.Character:FindFirstChild("KorpseHighlight")
                if not h then
                    h = Instance.new("Highlight")
                    h.Name = "KorpseHighlight"
                    h.Parent = plr.Character
                end
                h.Enabled = not (vars.teamcheck and plr.Team == lp.Team)
                h.FillColor = vars.color
                h.FillTransparency = 0.5
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            local h = plr.Character and plr.Character:FindFirstChild("KorpseHighlight")
            if h then h.Enabled = false end
        end
    end
    
    -- Tracers
    if vars.tracers and lp.Character and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        if not tracerDebounce then
            tracerDebounce = true
            
            local char = lp.Character
            local tool = char:FindFirstChildOfClass("Tool")
            local originPart = (tool and (tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle"))) 
                             or char:FindFirstChild("Head")
            
            if originPart then
                local startPos = originPart:IsA("Attachment") and originPart.WorldPosition or originPart.Position
                CreatePowerTracer(startPos, mouse.Hit.Position)
            end
            
            task.wait(0.1)
            tracerDebounce = false
        end
    end
end)

-- [ INPUT LOGIC ]
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    
    if input.KeyCode == Enum.KeyCode.Insert then
        if mf then
            mf.Visible = not mf.Visible
            if settingsFrame and not mf.Visible then
                settingsFrame.Visible = false
            end
        end
    end
    
    if input.UserInputType == vars.aim_bind or input.KeyCode == vars.aim_bind then
        vars.aimlock = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == vars.aim_bind or input.KeyCode == vars.aim_bind then
        vars.aimlock = false
        vars.target = nil
    end
end)

-- [ STARTUP ]
task.spawn(function()
    local storage = gethui()
    local existing = storage:FindFirstChild("Aimlock_v29")
    if existing then existing:Destroy() end
    
    local status, err = pcall(function()
        buildGUI()
        sg.Parent = storage
        mf.Visible = true
        refreshWhitelist()
        print("KORPSEBUNNY v2.9.5: FOV FIXED")
    end)
    
    if not status then
        warn("CRITICAL ERROR: " .. tostring(err))
    end
end)

Players.PlayerAdded:Connect(refreshWhitelist)
Players.PlayerRemoving:Connect(refreshWhitelist)
