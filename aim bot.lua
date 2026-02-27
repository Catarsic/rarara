--[[
    KORPSEBUNNY GUI v2.9.5 [ULTRA EXTENDED VERSION]
    Original UI Design: catarsic
    Engine & Logic Overhaul: Gemini 3 Flash
    
    FEATURES:
    - Turbo Aimlock (RenderStepped)
    - Vector Physics Bunnyhop
    - Advanced ESP (Box & Tracers)
    - Working Whitelist UI (Server-wide)
    - Lighting & Ambient Mods
    - Original 2.9.5 Aesthetic
]]

-- [ SERVICES ]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local CoreGui = game:GetService("CoreGui")

-- [ LOCAL PLAYER DATA ]
local lp = Players.LocalPlayer
local cam = Workspace.CurrentCamera
local mouse = lp:GetMouse()

-- [ FOLDERS & STORAGE ]
local gethui = gethui or function() 
    return lp:WaitForChild("PlayerGui") 
end

-- [ STATE VARIABLES ]
local whitelist = { 
    players = {},
    active = false 
}

local vars = {
    -- Aim Settings
    aimlock = false,
    headhit = false,
    smooth = 0.08,
    prediction = 0.13,
    fov = 120,
    wallcheck = true,
    teamcheck = false,
    autofire = false,
    firerate = 0.05,
    lastfire = 0,
	aim_bind = Enum.UserInputType.MouseButton2,

    -- Visual Settings
    esp = true,
    esp_boxes = true,
    esp_tracers = false,
    fov_circle = true,
    nightvision = false,
    ambientcolor = false,
    color = Color3.fromRGB(255, 182, 193), -- Default Pink
    
    -- Movement & Fun
    bunnyhop = false,
    bhspeed = 45,
    spinbot = false,
    spinspeed = 15,
    walkspeed = 16,
    full_overhaul = false,  -- По умолчанию выключено
    skybox_id = "rbxassetid://159414210", -- ID картинки неба
    fog_density = 0.5,      -- Насколько густой будет туман

    -- Internal
    target = nil,
    whitelist_open = false,
    menu_open = true
}

-- [ UI OBJECT REFERENCES ]
local sg, mf, wl_frame, wl_scroll, distlbl, fov_obj

-- [ UTILITY FUNCTIONS ]

-- Raycast for Wallcheck
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
    return false
end

-- Finding the optimal target
-- [ БЛОК 1: ТУРБО-ЛОГИКА ПОИСКА ЦЕЛИ ]
local function getClosestPlayer()
    local closest = nil
    local shortestDist = vars.fov
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    
    -- Используем GetPlayers для быстрого итератора
    local allPlayers = Players:GetPlayers()
    
    for i = 1, #allPlayers do
        local plr = allPlayers[i]
        if plr ~= lp and plr.Character then
            -- Оптимизированная проверка команды и вайтлиста
            if vars.teamcheck and plr.Team == lp.Team then continue end
            if vars.whitelist and whitelist.players[plr.Name] then continue end
            
            local char = plr.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    -- Выбор части тела
                    local part = vars.headhit and char:FindFirstChild("Head") or root
                    if part then
                        local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                        if onScreen then
                            local mag = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                            if mag <= shortestDist then
                                -- Прямая проверка видимости (Wallcheck)
                                if isVisible(part, plr) then
                                    closest = plr
                                    shortestDist = mag
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end
-- Weapon Activation
local function triggerWeapon()
    local char = lp.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            tool:Activate()
        end
    end
    -- Support for games with manual input clicks
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

local function updateAmbient()
    if vars.ambientcolor then
        -- Когда включено: ставим твой цвет везде
        game:GetService("Lighting").Ambient = vars.color
        game:GetService("Lighting").OutdoorAmbient = vars.color
        game:GetService("Lighting").GlobalShadows = false -- Выключаем тени, чтобы не было черных пятен
        game:GetService("Lighting").Brightness = 2
    else
        -- Когда выключено: возвращаем стандартные настройки Roblox
        game:GetService("Lighting").Ambient = Color3.fromRGB(127, 127, 127)
        game:GetService("Lighting").OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        game:GetService("Lighting").GlobalShadows = true
        game:GetService("Lighting").Brightness = 1
    end
end
local function ApplyTotalOverhaul()
    -- 1. Удаляем старые эффекты, чтобы они не накладывались друг на друга
    for _, obj in pairs(game:GetService("Lighting"):GetChildren()) do
        if obj:IsA("Sky") or obj:IsA("ColorCorrectionEffect") then
            obj:Destroy()
        end
    end
   if vars.full_overhaul then
        -- 2. Ставим новое небо (Skybox)
        local sky = Instance.new("Sky", game:GetService("Lighting"))
        sky.SkyboxBk = vars.skybox_id
        sky.SkyboxDn = vars.skybox_id
        sky.SkyboxFt = vars.skybox_id
        sky.SkyboxLf = vars.skybox_id
        sky.SkyboxRt = vars.skybox_id
        sky.SkyboxUp = vars.skybox_id
        sky.SunAngularSize = 0

        -- 3. Красим мир в цвет твоей темы (TintColor)
        local cc = Instance.new("ColorCorrectionEffect", game:GetService("Lighting"))
        cc.Contrast = 0.05
        cc.Saturation = 0.2
        cc.TintColor = vars.color:Lerp(Color3.new(1, 1, 1), 0.5)

        -- 4. Включаем туман и яркое освещение
        game:GetService("Lighting").FogColor = vars.color
        game:GetService("Lighting").FogEnd = 500
        game:GetService("Lighting").Ambient = vars.color
        game:GetService("Lighting").OutdoorAmbient = vars.color
        game:GetService("Lighting").GlobalShadows = false
        game:GetService("Lighting").Brightness = 2
    else
        -- 5. Если выключили — возвращаем всё как было в обычном Роблоксе
        game:GetService("Lighting").Ambient = Color3.fromRGB(127, 127, 127)
        game:GetService("Lighting").OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        game:GetService("Lighting").GlobalShadows = true
        game:GetService("Lighting").FogEnd = 100000
        game:GetService("Lighting").Brightness = 1
    end
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
            entry.BackgroundColor3 = whitelist.players[player.Name] and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(35, 35, 35)
            entry.BorderSizePixel = 0
            entry.Text = "  " .. player.DisplayName .. " (@" .. player.Name .. ")"
            entry.TextColor3 = Color3.fromRGB(255, 255, 255)
            entry.TextXAlignment = Enum.TextXAlignment.Left
            entry.Font = Enum.Font.SourceSans
            entry.TextSize = 14
            entry.Parent = wl_scroll
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = entry
            
            entry.MouseButton1Click:Connect(function()
                whitelist.players[player.Name] = not whitelist.players[player.Name]
                entry.BackgroundColor3 = whitelist.players[player.Name] and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(35, 35, 35)
            end)
        end
    end
    wl_scroll.CanvasSize = UDim2.new(0, 0, 0, uiList.AbsoluteContentSize.Y + 10)
end

-- [ GUI CONSTRUCTION - VERSION 2.9.5 ]

local function buildGUI()
    -- Base ScreenGui
    sg = Instance.new("ScreenGui")
    sg.Name = "Aimlock_v29"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent = gethui()
    
    -- Main Frame
    mf = Instance.new("Frame")
    mf.Name = "MainFrame"
    mf.Size = UDim2.new(0, 340, 0, 560)
    mf.Position = UDim2.new(1, -360, 0.5, -280)
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
    
    -- Header Title
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
    
    -- Function to create buttons (original style)
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
            if vName == "ambientcolor" then updateAmbient() end
            if vName == "whitelist" then
                wl_frame.Visible = vars.whitelist
                if vars.whitelist then refreshWhitelist() end
            end
        end)
    end
    
    -- Button Grid
    addToggle("Aimlock", "aimlock", 10, 55)
    addToggle("AutoFire", "autofire", 175, 55)
    addToggle("Head Aim", "headhit", 10, 95)
    addToggle("ESP", "esp", 175, 95)
    addToggle("WallCheck", "wallcheck", 10, 135)
    addToggle("Spinbot", "spinbot", 175, 135)
    addToggle("Bunnyhop", "bunnyhop", 10, 175)
    addToggle("NightVision", "nightvision", 175, 175)
    -- [ ЗАМЕНЯЕМ СТАРЫЙ AMBIENT НА TOTAL OVERHAUL ]
    local btn = Instance.new("TextButton", mf)
    btn.Name = "Overhaul_Toggle"
    btn.Size = UDim2.new(0, 150, 0, 32)
    btn.Position = UDim2.new(0, 10, 0, 215) -- Та же позиция, что у Ambient
    btn.BackgroundColor3 = vars.full_overhaul and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(35, 35, 35)
    btn.Text = "World Mod: " .. (vars.full_overhaul and "ON" or "OFF")
    btn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

    btn.MouseButton1Click:Connect(function()
        vars.full_overhaul = not vars.full_overhaul
        btn.Text = "World Mod: " .. (vars.full_overhaul and "ON" or "OFF")
        btn.BackgroundColor3 = vars.full_overhaul and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(35, 35, 35)
        
        -- Вызываем нашу новую супер-функцию!
        ApplyTotalOverhaul()
    end)
    addToggle("Whitelist", "whitelist", 175, 215)
    
    -- Scrolling Section for Sliders
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Name = "SliderSection"
    sliderFrame.Size = UDim2.new(1, -20, 0, 205)
    sliderFrame.Position = UDim2.new(0, 10, 0, 260)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = mf
    
    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, 0, 1, 0)
    scroll.CanvasSize = UDim2.new(0, 0, 0, 460)
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
    
    addSlider("Aim Smooth", 0.01, 0.5, vars.smooth, 10, function(v) vars.smooth = v end)
    addSlider("FOV Radius", 10, 800, vars.fov, 65, function(v) vars.fov = v end)
    addSlider("Spin Speed", 1, 100, vars.spinspeed, 120, function(v) vars.spinspeed = v end)
    addSlider("Bhop Speed", 16, 150, vars.bhspeed, 175, function(v) vars.bhspeed = v end)
    addSlider("Prediction", 0.01, 0.4, vars.prediction, 230, function(v) vars.prediction = v end)
    addSlider("WalkSpeed", 16, 250, vars.walkspeed, 285, function(v) vars.walkspeed = v end)
    addSlider("Camera FOV", 70, 120, 70, 340, function(v) cam.FieldOfView = v end)
	-- [ КНОПКА СМЕНЫ БИНДА ]
    local bindBtn = Instance.new("TextButton")
    bindBtn.Name = "AimBind_Button"
    bindBtn.Size = UDim2.new(0, 240, 0, 32) -- Ширина как у слайдеров
    bindBtn.Position = UDim2.new(0, 10, 0, 395) -- Позиция Y ниже последнего слайдера
    bindBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    bindBtn.Text = "Aim Bind: " .. vars.aim_bind.Name
    bindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    bindBtn.Font = Enum.Font.SourceSans
    bindBtn.TextSize = 16
    bindBtn.Parent = scroll -- Добавляем в скролл-секцию
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
    -- Theme Selector
    local themeContainer = Instance.new("Frame")
    themeContainer.Size = UDim2.new(1, -20, 0, 45)
    themeContainer.Position = UDim2.new(0, 10, 0, 470)
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
            if wl_frame then 
                wl_frame:FindFirstChild("UIStroke").Color = t[1] 
            end
            if vars.ambientcolor then updateAmbient() end
			if vars.full_overhaul then
                ApplyTotalOverhaul()
            end
		end)
    end
    
    -- Distance Label
    distlbl = Instance.new("TextLabel")
    distlbl.Size = UDim2.new(1, 0, 0, 30)
    distlbl.Position = UDim2.new(0, 0, 1, -38)
    distlbl.BackgroundTransparency = 1
    distlbl.Text = "Target Distance: N/A"
    distlbl.TextColor3 = Color3.fromRGB(200, 200, 200)
    distlbl.Font = Enum.Font.SourceSansItalic
    distlbl.TextSize = 15
    distlbl.Parent = mf

    -- [ WHITELIST FRAME ]
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
end

-- [ FOV CIRCLE DRAWING ]

local function createFOV()
    local fov = Drawing.new("Circle")
    fov.Visible = true
    fov.Thickness = 1
    fov.Color = vars.color
    fov.Filled = false
    fov.Transparency = 1
    return fov
end
fov_obj = createFOV()

-- [ MAIN RENDER LOOP ]

-- [ MAIN RENDER LOOP ]

RunService.RenderStepped:Connect(function(dt)
    -- Обновление круга FOV
    if fov_obj then
        fov_obj.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        fov_obj.Radius = vars.fov
        fov_obj.Color = vars.color
        fov_obj.Visible = (vars.aimlock and vars.menu_open)
    end
    
    -- ЛОГИКА АИМЛОКА
    if vars.aimlock then
        local target = getClosestPlayer()
       local isPressed = false
        if vars.aim_bind.Name:find("MouseButton") then
            isPressed = UserInputService:IsMouseButtonPressed(vars.aim_bind)
        else
            isPressed = UserInputService:IsKeyDown(vars.aim_bind)
        end
        
        if target and isPressed then
            vars.target = target
            local char = target.Character
            local part = vars.headhit and char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
            
            if part then
                local velocity = part.AssemblyLinearVelocity
                local predictedPos = part.Position + (velocity * vars.prediction)
                local lookAt = CFrame.lookAt(cam.CFrame.Position, predictedPos)
                local snapFactor = 1 - vars.smooth
                
                cam.CFrame = cam.CFrame:Lerp(lookAt, math.clamp(snapFactor, 0.01, 1))
                
                -- [ УЛУЧШЕННЫЙ AUTOFIRE ДЛЯ AWM ]
                if vars.autofire then
                    -- Рассчитываем, насколько близко прицел к цели
                    local screenPos, onScreen = cam:WorldToViewportPoint(part.Position)
                    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
                    local mouseDist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                    
                    -- Стреляем только если прицел РЕАЛЬНО наведен (дистанция меньше 10 пикселей от центра)
                    -- И проверяем задержку между выстрелами
                    if mouseDist < 10 and (tick() - vars.lastfire >= vars.firerate) then
                        vars.lastfire = tick()
                        task.spawn(triggerWeapon)
                    end
                end
                
                if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (lp.Character.HumanoidRootPart.Position - part.Position).Magnitude
                    distlbl.Text = "Target: " .. target.DisplayName .. " [" .. math.floor(d) .. " studs]"
                end
            end
        else
            vars.target = nil
            distlbl.Text = "Target Distance: N/A"
        end
    end
    
-- [ БЛОК 3: УНИВЕРСАЛЬНЫЙ BHOP ]
    if vars.bunnyhop and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        local char = lp.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")
        
        if hrp and hum then
            -- Принудительный прыжок
            if hum.FloorMaterial ~= Enum.Material.Air then
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
            end
            
            -- Проверка движения
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                -- Взлом через CFrame: двигаем позицию персонажа в обход физики
                -- Рассчитываем шаг: (направление * скорость / 60 кадров)
                local moveStep = moveDir * (vars.bhspeed / 60)
                hrp.CFrame = hrp.CFrame + moveStep
                
                -- Поддержка инерции, чтобы анимация бега не ломалась
                hrp.Velocity = Vector3.new(moveDir.X * 5, hrp.Velocity.Y, moveDir.Z * 5)
            end
        end
    end

    -- SPINBOT
    if vars.spinbot and lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(vars.spinspeed), 0)
    end
    
    -- ОПТИМИЗИРОВАННЫЙ ESP
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
end) -- Вот здесь закрывается RenderStepped правильно!

-- [ ОБРАБОТКА ВВОДА ]
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        vars.menu_open = not vars.menu_open
        if mf then mf.Visible = vars.menu_open end
        if fov_obj then fov_obj.Visible = (vars.aimlock and vars.menu_open) end
    end
end)

-- [ СИСТЕМА ЗАПУСКА ]
local function SafeIdentify()
    local success, target = pcall(function()
        return gethui() or game:GetService("CoreGui") or lp:WaitForChild("PlayerGui")
    end)
    return success and target or lp:WaitForChild("PlayerGui")
end

task.spawn(function()
    local storage = SafeIdentify()
    local existing = storage:FindFirstChild("Aimlock_v29")
    if existing then existing:Destroy() end
    
    local status, err = pcall(function()
        buildGUI()
        sg.Parent = storage
        sg.Enabled = true
        mf.Visible = true
        if fov_obj then fov_obj.Visible = vars.aimlock end
    end)

    if status then
        refreshWhitelist()
        print("KORPSEBUNNY v2.9.5: SUCCESS")
    else
        warn("CRITICAL ERROR: " .. tostring(err))
    end
end)

Players.PlayerAdded:Connect(refreshWhitelist)
Players.PlayerRemoving:Connect(refreshWhitelist)
