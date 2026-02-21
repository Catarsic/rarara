-- korpebunny GUI by catarsic - ✅ ПОЛНЫЙ КОД С ПРОСТОЙ КНОПКОЙ БИНДА
-- Xeno executor ready - ✅ FOV КАМЕРЫ ВСЕГДА ИЗМЕНЁННЫЙ!

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local lp = Players.LocalPlayer
local cam = Workspace.CurrentCamera

local gethui = gethui or function() return lp:WaitForChild("PlayerGui") end

-- ✅ WHITELIST СИСТЕМА
local whitelist = {
    players = {},
    showlist = true
}

-- ✅ ПРОСТОЙ AIM BIND КНОПКА
local aimBindKey = nil  -- nil = выключен

local vars = {
    teamcheck = false,
    fov = 120,
    fov_camera = 50,
    aimlock = false,
    esp = true,
    headhit = false,
    autofire = false,
    spinbot = false,
    bunnyhop = false,
    nightvision = false,
    ambientcolor = false,
    whitelist = false,
    target = nil,
    distance = "N/A",
    color = Color3.fromRGB(255, 182, 193),
    smooth = 0.12,
    spinspeed = 6,
    bhspeed = 35,
    walkspeed = 16,
    wallcheck = true,
    firerate = 0.1,
    lastfire = 0,
    prediction = 0.13
}

local espobjs = {}
local conns = {}
local fovcircle = nil
local distlbl = nil
local sg, mf, sf
local bloom_effect = nil
local sunrays_effect = nil
local whitelistFrame = nil
local bindFrame = nil
local bindingMode = false

-- ✅ ПРОСТАЯ ПРОВЕРКА БИНДА
local function isAimBindPressed()
    if not aimBindKey then return false end
    
    if aimBindKey:find("MouseButton") then
        return UserInputService:IsMouseButtonPressed(Enum.UserInputType[aimBindKey])
    else
        return UserInputService:IsKeyDown(Enum.KeyCode[aimBindKey])
    end
end

local function updateCameraFOV()
    cam.FieldOfView = vars.fov_camera
end

local function isWhitelisted(plr)
    if not vars.whitelist then return false end
    return whitelist.players[plr.Name] or false
end

local function toggleNightVision()
    local cc = Lighting:FindFirstChild("NightVisionCC")
    if not cc then
        cc = Instance.new("ColorCorrectionEffect")
        cc.Name = "NightVisionCC"
        cc.Parent = Lighting
    end
    
    if vars.nightvision then
        Lighting.Brightness = 4
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.AmbientOcclusion = 0
        Lighting.ClockTime = 12
        Lighting.GeographicLatitude = 0
        Lighting.TimeOfDay = "12:00:00"
        cc.Enabled = true
        cc.Brightness = 0.8
        cc.Contrast = 0.2
        cc.Saturation = 0.3
        cc.TintColor = Color3.fromRGB(255, 255, 255)
    else
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 100000
        Lighting.AmbientOcclusion = 1
        Lighting.ClockTime = 14
        cc.Enabled = false
    end
end

local function toggleAmbientColor()
    if vars.ambientcolor then
        Lighting.Ambient = vars.color
        Lighting.OutdoorAmbient = vars.color
        Lighting.ColorShift_Bottom = vars.color
        Lighting.ColorShift_Top = vars.color
        Lighting.Brightness = 4
        Lighting.GlobalShadows = false
        Lighting.AmbientOcclusion = 0
        
        bloom_effect = Lighting:FindFirstChild("AmbientBloom") or Instance.new("BloomEffect")
        if bloom_effect.Name ~= "AmbientBloom" then
            bloom_effect.Name = "AmbientBloom"
            bloom_effect.Parent = Lighting
        end
        bloom_effect.Enabled = true
        bloom_effect.Intensity = 1.2
        bloom_effect.Size = 32
        bloom_effect.Threshold = 0.8
        
        sunrays_effect = Lighting:FindFirstChild("AmbientSunRays") or Instance.new("SunRaysEffect")
        if sunrays_effect.Name ~= "AmbientSunRays" then
            sunrays_effect.Name = "AmbientSunRays"
            sunrays_effect.Parent = Lighting
        end
        sunrays_effect.Enabled = true
        sunrays_effect.Intensity = 0.4
        sunrays_effect.Spread = 1
        
        local cc = Lighting:FindFirstChild("AmbientCC")
        if not cc then
            cc = Instance.new("ColorCorrectionEffect")
            cc.Name = "AmbientCC"
            cc.Parent = Lighting
        end
        cc.Enabled = true
        cc.TintColor = vars.color
        cc.Brightness = 0.3
        cc.Contrast = 0.4
        cc.Saturation = 0.6
    else
        Lighting.Ambient = Color3.fromRGB(64, 64, 77)
        Lighting.OutdoorAmbient = Color3.fromRGB(107, 116, 127)
        Lighting.ColorShift_Bottom = Color3.fromRGB(168, 184, 255)
        Lighting.ColorShift_Top = Color3.fromRGB(95, 121, 199)
        Lighting.Brightness = 1
        Lighting.GlobalShadows = true
        Lighting.AmbientOcclusion = 1
        
        if bloom_effect then bloom_effect.Enabled = false end
        if sunrays_effect then sunrays_effect.Enabled = false end
        
        local cc = Lighting:FindFirstChild("AmbientCC")
        if cc then cc.Enabled = false end
    end
end

local function raycast(part, char)
    if not vars.wallcheck then return true end
    local origin = cam.CFrame.Position
    local dir = (part.Position - origin).Unit * 1000
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {lp.Character or {}}
    local res = Workspace:Raycast(origin, dir, params)
    return not res or res.Instance:IsDescendantOf(char)
end

local function closest()
    local closest, dist = nil, math.huge
    local center = cam.ViewportSize/2
    local pos = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character.HumanoidRootPart.Position or Vector3.new()
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local char = plr.Character
            local hum = char:FindFirstChild("Humanoid")
            local root = char.HumanoidRootPart
            
            if isWhitelisted(plr) then continue end
            
            if hum and hum.Health > 0 and (not vars.teamcheck or plr.Team ~= lp.Team) then
                if not vars.wallcheck or raycast(root, char) then
                    local hitpart = vars.headhit and (char:FindFirstChild("Head") or root) or root
                    
                    local screen, visible = cam:WorldToViewportPoint(hitpart.Position)
                    local d2d = (Vector2.new(screen.X, screen.Y) - center).Magnitude
                    
                    if visible and d2d < dist and d2d <= vars.fov then
                        closest = plr
                        dist = d2d
                        vars.distance = math.floor((pos - hitpart.Position).Magnitude)
                    end
                end
            end
        end
    end
    return closest
end

local function aimat()
    if vars.target and vars.target.Character then
        local char = vars.target.Character
        local hitpart = vars.headhit and char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        
        if hitpart and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local vel = hitpart.AssemblyLinearVelocity or Vector3.new()
            local distance3d = (cam.CFrame.Position - hitpart.Position).Magnitude
            local predict_time = vars.prediction * (distance3d / 100)
            local predictpos = hitpart.Position + vel * predict_time
            
            local targetCFrame = CFrame.lookAt(cam.CFrame.Position, predictpos)
            local alpha = vars.smooth * 2
            cam.CFrame = cam.CFrame:Lerp(targetCFrame, alpha)
        else
            vars.target = nil
        end
    end
end

local function shoot()
    pcall(function()
        local char = lp.Character
        if char then
            for _, tool in pairs(char:GetChildren()) do
                if tool:IsA("Tool") then tool:Activate() end
            end
        end
    end)
    
    pcall(function()
        local vu = game:GetService("VirtualUser")
        if vu then
            vu:Button1Down(Vector2.new())
            task.wait(0.03)
            vu:Button1Up(Vector2.new())
        end
    end)
    
    if mouse1click then mouse1click() end
end

local function bh(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    vars.walkspeed = vars.walkspeed or hum.WalkSpeed or 16
    
    hum.StateChanged:Connect(function(_, state)
        if not vars.bunnyhop then
            if hum.WalkSpeed ~= vars.walkspeed then
                hum.WalkSpeed = vars.walkspeed
            end
            return
        end
        if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
            hum.WalkSpeed = vars.bhspeed
        else
            hum.WalkSpeed = vars.walkspeed
        end
    end)
end

if lp.Character then bh(lp.Character) end
lp.CharacterAdded:Connect(function(c) task.wait(0.5); bh(c) end)

local function createWhitelistFrame()
    if whitelistFrame then whitelistFrame:Destroy() end
    
    whitelistFrame = Instance.new("Frame")
    whitelistFrame.Size = UDim2.new(0, 250, 0, 400)
    whitelistFrame.Position = UDim2.new(0, 10, 0, 10)
    whitelistFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    whitelistFrame.BorderSizePixel = 2
    whitelistFrame.BorderColor3 = vars.color
    whitelistFrame.Active = true
    whitelistFrame.Draggable = true
    whitelistFrame.Parent = sg
    
    local wtitle = Instance.new("TextLabel")
    wtitle.Size = UDim2.new(1, 0, 0, 30)
    wtitle.Position = UDim2.new(0, 0, 0, 0)
    wtitle.BackgroundColor3 = vars.color
    wtitle.Text = "👥 Whitelist Players"
    wtitle.TextColor3 = Color3.new(1,1,1)
    wtitle.TextScaled = true
    wtitle.Font = Enum.Font.SourceSansBold
    wtitle.ZIndex = 15
    wtitle.Parent = whitelistFrame
    
    local wlist = Instance.new("ScrollingFrame")
    wlist.Size = UDim2.new(1, -10, 1, -40)
    wlist.Position = UDim2.new(0, 5, 0, 35)
    wlist.BackgroundTransparency = 1
    wlist.BorderSizePixel = 0
    wlist.ScrollBarThickness = 6
    wlist.ScrollBarImageColor3 = vars.color
    wlist.CanvasSize = UDim2.new(0, 0, 0, 0)
    wlist.Parent = whitelistFrame
    
    local function updateList()
        for _, child in pairs(wlist:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local playersList = {}
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= lp then
                table.insert(playersList, plr)
            end
        end
        
        local yPos = 0
        for i, plr in ipairs(playersList) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30)
            btn.Position = UDim2.new(0, 0, 0, yPos)
            btn.BackgroundColor3 = whitelist.players[plr.Name] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(45, 45, 45)
            btn.Text = plr.Name .. (plr.Team and " [" .. plr.Team.Name .. "]" or "")
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextScaled = true
            btn.Font = Enum.Font.SourceSans
            btn.ZIndex = 16
            btn.Parent = wlist
            
            btn.MouseButton1Click:Connect(function()
                whitelist.players[plr.Name] = not whitelist.players[plr.Name]
                btn.BackgroundColor3 = whitelist.players[plr.Name] and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(45, 45, 45)
            end)
            
            yPos = yPos + 35
        end
        
        wlist.CanvasSize = UDim2.new(0, 0, 0, yPos)
    end
    
    updateList()
    Players.PlayerAdded:Connect(updateList)
    Players.PlayerRemoving:Connect(updateList)
end

-- ✅ ПРОСТАЯ КНОПКА БИНДА
local bindConnection = nil
local function createBindFrame()
    if bindFrame then 
        bindFrame:Destroy()
        bindFrame = nil
        return 
    end
    
    bindFrame = Instance.new("Frame")
    bindFrame.Size = UDim2.new(0, 220, 0, 120)
    bindFrame.Position = UDim2.new(0.5, -110, 0.5, -60)
    bindFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    bindFrame.BorderSizePixel = 2
    bindFrame.BorderColor3 = vars.color
    bindFrame.Active = true
    bindFrame.Draggable = true
    bindFrame.Parent = sg
    bindFrame.ZIndex = 20
    
    local bindTitle = Instance.new("TextLabel")
    bindTitle.Size = UDim2.new(1, 0, 0, 25)
    bindTitle.Position = UDim2.new(0, 0, 0, 0)
    bindTitle.BackgroundColor3 = vars.color
    bindTitle.Text = "🎯 Aim Bind"
    bindTitle.TextColor3 = Color3.new(1,1,1)
    bindTitle.TextScaled = true
    bindTitle.Font = Enum.Font.SourceSansBold
    bindTitle.ZIndex = 21
    bindTitle.Parent = bindFrame
    
    local bindDesc = Instance.new("TextLabel")
    bindDesc.Size = UDim2.new(1, -10, 0, 20)
    bindDesc.Position = UDim2.new(0, 5, 0, 28)
    bindDesc.BackgroundTransparency = 1
    bindDesc.TextColor3 = Color3.fromRGB(200, 200, 200)
    bindDesc.Text = "Кликни → нажми клавишу/кнопку"
    bindDesc.TextSize = 13
    bindDesc.TextXAlignment = Enum.TextXAlignment.Left
    bindDesc.ZIndex = 21
    bindDesc.Parent = bindFrame
    
    local bindSquare = Instance.new("TextButton")
    bindSquare.Size = UDim2.new(0, 120, 0, 45)
    bindSquare.Position = UDim2.new(0.5, -60, 0, 55)
    bindSquare.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    bindSquare.Text = aimBindKey or "Забиндить"
    bindSquare.TextColor3 = Color3.new(1,1,1)
    bindSquare.TextScaled = true
    bindSquare.Font = Enum.Font.SourceSansBold
    bindSquare.ZIndex = 22
    bindSquare.Parent = bindFrame
    
    local bindCorner = Instance.new("UICorner")
    bindCorner.CornerRadius = UDim.new(0, 12)
    bindCorner.Parent = bindSquare
    
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 70, 0, 25)
    clearBtn.Position = UDim2.new(0, 10, 1, -35)
    clearBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    clearBtn.Text = "Сбросить"
    clearBtn.TextColor3 = Color3.new(1,1,1)
    clearBtn.TextScaled = true
    clearBtn.Font = Enum.Font.SourceSans
    clearBtn.ZIndex = 22
    clearBtn.Parent = bindFrame
    
    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 8)
    clearCorner.Parent = clearBtn
    
    clearBtn.MouseButton1Click:Connect(function()
        aimBindKey = nil
        bindSquare.Text = "Забиндить"
        bindSquare.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
    
    bindSquare.MouseButton1Click:Connect(function()
        if bindingMode then return end
        bindingMode = true
        bindSquare.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
        bindSquare.Text = "ЖДЁМ КНОПКУ..."
    end)
    
    if bindConnection then bindConnection:Disconnect() end
    bindConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not bindingMode or gameProcessed then return end
        
        local bindName
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            bindName = "MouseButton1"
        elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
            bindName = "MouseButton2"
        elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
            bindName = "MouseButton3"
        elseif input.UserInputType == Enum.UserInputType.MouseButton4 then
            bindName = "MouseButton4"
        elseif input.UserInputType == Enum.UserInputType.MouseButton5 then
            bindName = "MouseButton5"
        elseif input.UserInputType == Enum.UserInputType.Keyboard then
            bindName = input.KeyCode.Name
        else
            return
        end
        
        aimBindKey = bindName
        bindingMode = false
        
        bindSquare.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
        if bindName == "MouseButton1" then
            bindSquare.Text = "ЛКМ"
        elseif bindName == "MouseButton2" then
            bindSquare.Text = "ПКМ"
        elseif bindName == "MouseButton3" then
            bindSquare.Text = "Колёсико"
        elseif bindName == "MouseButton4" then
            bindSquare.Text = "Mouse4"
        elseif bindName == "MouseButton5" then
            bindSquare.Text = "Mouse5"
        else
            bindSquare.Text = bindName
        end
        
        task.wait(1)
        bindSquare.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end)
end

local function makeslider(p, y, text, min, max, def, w, cb)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, w, 0, 18)
    label.Position = UDim2.new(0, 10, 0, y)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.SourceSans
    label.Text = text.." ("..def..")"
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextSize = 14
    label.ZIndex = 20
    label.Parent = p

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, w, 0, 8)
    track.Position = UDim2.new(0, 10, 0, y+22)
    track.BackgroundColor3 = Color3.fromRGB(60,60,60)
    track.ZIndex = 20
    track.Parent = p

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((def-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = vars.color
    fill.ZIndex = 21
    fill.Parent = track

    local tcor = Instance.new("UICorner"); tcor.CornerRadius = UDim.new(0,4); tcor.Parent = track
    local fcor = Instance.new("UICorner"); fcor.CornerRadius = UDim.new(0,4); fcor.Parent = fill

    local val = def
    local drag = false

    local function moved(input)
        if not drag or not track.AbsoluteSize then return end
        local relx = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, track.AbsoluteSize.X)
        local percent = relx/track.AbsoluteSize.X
        val = math.floor((min+(max-min)*percent)*100+0.5)/100
        fill.Size = UDim2.new(percent, 0, 1, 0)
        label.Text = text.." ("..val..")"
        cb(val)
    end

    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            moved(i)
        end
    end)

    UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            moved(i)
        end
    end)

    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)
end

local function maingui()
    if gethui():FindFirstChild("Aimlock_GUI") then gethui().Aimlock_GUI:Destroy() end
    
    sg = Instance.new("ScreenGui")
    sg.Name = "Aimlock_GUI"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 1
    sg.Parent = gethui()

    if syn and syn.protect_gui then syn.protect_gui(sg) end

    mf = Instance.new("Frame")
    mf.Size = UDim2.new(0, 340, 0, 550)
    mf.Position = UDim2.new(1, -360, 0, 50)
    mf.BackgroundColor3 = Color3.fromRGB(20,20,20)
    mf.BorderSizePixel = 2
    mf.BorderColor3 = vars.color
    mf.Active = true
    mf.Draggable = true
    mf.ZIndex = 5
    mf.Parent = sg

    local setbtn = Instance.new("TextButton")
    setbtn.Size = UDim2.new(0, 30, 0, 30)
    setbtn.Position = UDim2.new(1, -40, 0, 8)
    setbtn.BackgroundColor3 = vars.color
    setbtn.Text = "⚙"
    setbtn.TextColor3 = Color3.new(1,1,1)
    setbtn.TextScaled = true
    setbtn.Font = Enum.Font.SourceSansBold
    setbtn.ZIndex = 10
    setbtn.Parent = mf

    local setcor = Instance.new("UICorner")
    setcor.CornerRadius = UDim.new(0,15)
    setcor.Parent = setbtn

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0, 300, 0, 28)
    title.Position = UDim2.new(0,10,0,6)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.new(1,1,1)
    title.TextScaled = true
    title.Font = Enum.Font.SourceSansBold
    title.Text = "korpsebunny GUI - ПРОСТОЙ AIM BIND"
    title.ZIndex = 6
    title.Parent = mf

    local btns = {
        {pos=UDim2.new(0,10,0,42), txt="Aimlock", var="aimlock"},
        {pos=UDim2.new(0,10,0,78), txt="Head Aim", var="headhit"},
        {pos=UDim2.new(0,10,0,114), txt="ESP", var="esp"},
        {pos=UDim2.new(0,10,0,150), txt="Ambient Color", var="ambientcolor"},
        {pos=UDim2.new(0,175,0,42), txt="AutoFire", var="autofire"},
        {pos=UDim2.new(0,175,0,78), txt="Spinbot", var="spinbot"},
        {pos=UDim2.new(0,175,0,114), txt="Bunnyhop", var="bunnyhop"},
        {pos=UDim2.new(0,175,0,150), txt="NightVision", var="nightvision"},
        {pos=UDim2.new(0,10,0,186), txt="Whitelist", var="whitelist"},
        {pos=UDim2.new(0,10,0,222), txt="🎯 Bind Key", var="bindkey"}  -- ✅ ПРОСТАЯ КНОПКА БИНДА
    }

    for i, b in ipairs(btns) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 150, 0, 28)
        button.Position = b.pos
        button.BackgroundColor3 = Color3.fromRGB(45,45,45)
        button.BorderColor3 = vars.color
        button.Text = b.txt..": "..(vars[b.var] and "ON" or "OFF")
        button.TextColor3 = Color3.new(1,1,1)
        button.TextScaled = true
        button.Font = Enum.Font.SourceSans
        button.ZIndex = 6
        button.Parent = mf
        
        button.MouseButton1Click:Connect(function()
            if b.var == "bindkey" then
                createBindFrame()
                return
            end
            
            vars[b.var] = not vars[b.var]
            button.Text = b.txt..": "..(vars[b.var] and "ON" or "OFF")
            
            if b.var == "whitelist" then
                if vars.whitelist then
                    createWhitelistFrame()
                else
                    if whitelistFrame then whitelistFrame:Destroy() end
                end
            elseif b.var == "nightvision" then
                toggleNightVision()
            elseif b.var == "ambientcolor" then
                toggleAmbientColor()
            end
        end)
    end

    -- FOV CIRCLE
    fovcircle = Instance.new("Frame")
    fovcircle.Size = UDim2.new(0, vars.fov*2, 0, vars.fov*2)
    fovcircle.Position = UDim2.new(0.5, -vars.fov, 0.5, -vars.fov)
    fovcircle.BackgroundTransparency = 1
    fovcircle.ZIndex = 1
    fovcircle.Parent = sg
    
    local fovstroke = Instance.new("UIStroke")
    fovstroke.Color = vars.color
    fovstroke.Thickness = 3
    fovstroke.Transparency = 0.7
    fovstroke.Parent = fovcircle
    
    local fovcor = Instance.new("UICorner")
    fovcor.CornerRadius = UDim.new(1, 0)
    fovcor.Parent = fovcircle

    -- Settings frame
    sf = Instance.new("Frame")
    sf.Size = UDim2.new(0, 280, 0, 520)
    sf.Position = UDim2.new(1, -300, 0, 50)
    sf.BackgroundColor3 = Color3.fromRGB(25,25,25)
    sf.BorderSizePixel = 2
    sf.BorderColor3 = vars.color
    sf.Visible = false
    sf.Active = true
    sf.Draggable = true
    sf.ZIndex = 10
    sf.Parent = sg

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -40)
    scroll.Position = UDim2.new(0, 10, 0, 35)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 8
    scroll.ScrollBarImageColor3 = vars.color
    scroll.CanvasSize = UDim2.new(0, 0, 0, 700)
    scroll.Parent = sf

    local stitle = Instance.new("TextLabel")
    stitle.Size = UDim2.new(1, -20, 0, 24)
    stitle.Position = UDim2.new(0, 10, 0, 6)
    stitle.BackgroundTransparency = 1
    stitle.TextColor3 = Color3.new(1,1,1)
    stitle.TextScaled = true
    stitle.Text = "⚙ Settings"
    stitle.ZIndex = 11
    stitle.Parent = sf

    makeslider(scroll, 34, "Aim Speed", 0.02, 1, vars.smooth, 260, function(v) vars.smooth = v end)
    makeslider(scroll, 94, "Spin Speed", 1, 60, vars.spinspeed, 260, function(v) vars.spinspeed = v end)
    makeslider(scroll, 154, "Bunny Speed", 10, 120, vars.bhspeed, 260, function(v) vars.bhspeed = v end)
    makeslider(scroll, 214, "Fire Rate", 0.03, 1, vars.firerate, 260, function(v) vars.firerate = v end)
    makeslider(scroll, 274, "FOV Circle", 30, 200, vars.fov, 260, function(v) 
        vars.fov = v
        fovcircle.Size = UDim2.new(0, v*2, 0, v*2)
        fovcircle.Position = UDim2.new(0.5, -v, 0.5, -v)
    end)
    makeslider(scroll, 334, "FOV Camera", 20, 120, vars.fov_camera, 260, function(v) 
        vars.fov_camera = v
    end)
    makeslider(scroll, 394, "Prediction", 0.05, 0.3, vars.prediction, 260, function(v) 
        vars.prediction = v 
    end)

    setbtn.MouseButton1Click:Connect(function()
        sf.Visible = not sf.Visible
        scroll.ScrollBarImageColor3 = vars.color
    end)

    local themelbl = Instance.new("TextLabel")
    themelbl.Size = UDim2.new(0, 300, 0, 18)
    themelbl.Position = UDim2.new(0,10,0,450)
    themelbl.BackgroundTransparency = 1
    themelbl.TextColor3 = Color3.new(1,1,1)
    themelbl.Text = "Themes:"
    themelbl.ZIndex = 6
    themelbl.Parent = mf

    local themes = {
        {Color3.fromRGB(220,20,60), "Red"},
        {Color3.fromRGB(128,0,128), "Purple"},
        {Color3.fromRGB(60,179,113), "Green"},
        {Color3.fromRGB(255,182,193), "Pink"}
    }

    local function sett(color)
        vars.color = color
        mf.BorderColor3 = color
        sf.BorderColor3 = color
        setbtn.BackgroundColor3 = color
        if fovcircle:FindFirstChildOfClass("UIStroke") then
            fovcircle:FindFirstChildOfClass("UIStroke").Color = color
        end
        if vars.ambientcolor then toggleAmbientColor() end
        if whitelistFrame then
            whitelistFrame.BorderColor3 = color
            whitelistFrame:FindFirstChild("TextLabel").BackgroundColor3 = color
        end
        if bindFrame then
            bindFrame.BorderColor3 = color
            bindFrame:FindFirstChild("TextLabel").BackgroundColor3 = color
        end
    end

    for i, t in ipairs(themes) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0, 70, 0, 24)
        tb.Position = UDim2.new(0, 10+(i-1)*75, 0, 472)
        tb.BackgroundColor3 = t[1]
        tb.Text = t[2]
        tb.TextColor3 = Color3.new(1,1,1)
        tb.ZIndex = 6
        tb.Parent = mf
        tb.MouseButton1Click:Connect(function() sett(t[1]) end)
    end

    distlbl = Instance.bindFrame.new("TextLabel")
    distlbl.Size = UDim2.new(0, 300, 0, 18)
    distlbl.Position = UDim2.new(0,10,0,500)
    distlbl.BackgroundTransparency = 1
    distlbl.TextColor3 = Color3.new(1,1,1)
    distlbl.TextScaled = true
    distlbl.Text = "Distance: N/A | Bind: "..(aimBindKey or "НЕТ")
    distlbl.ZIndex = 6
    distlbl.Parent = mf
end

table.insert(conns, RunService.RenderStepped:Connect(updateCameraFOV))

table.insert(conns, RunService.RenderStepped:Connect(function()
    distlbl.Text = "Distance: "..vars.distance.." | Bind: "..(aimBindKey or "НЕТ")
end))

table.insert(conns, RunService.RenderStepped:Connect(function()
    for plr, h in pairs(espobjs) do
        if h then h:Destroy() end
        espobjs[plr] = nil
    end
    
    if vars.esp then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if vars.whitelist and isWhitelisted(plr) then continue end
                
                local h = Instance.new("Highlight")
                h.Adornee = plr.Character
                h.FillColor = vars.color
                h.FillTransparency = 0.4
                h.OutlineColor = Color3.new(1,1,1)
                h.OutlineTransparency = 0
                h.Parent = plr.Character
                espobjs[plr] = h
            end
        end
    end
end))

-- ✅ АИМ ЛУП С ПРОСТЫМ БИНДОМ - ✅ ИСПРАВЛЕНО!
table.insert(conns, RunService.RenderStepped:Connect(function()
    if vars.aimlock and isAimBindPressed() then
        if not vars.target or not vars.target.Character or not vars.target.Character.Parent then
            vars.target = closest()
        end
        
        if vars.target then
            aimat()
            if vars.autofire then
                local now = tick()
                if now - vars.lastfire >= vars.firerate then
                    vars.lastfire = now
                    shoot()
                end
            end
        end
    else
        vars.target = nil
    end
end))

table.insert(conns, RunService.RenderStepped:Connect(function()
    if vars.spinbot then
        local char = lp.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            if root then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(vars.spinspeed), 0)
            end
        end
    end
end))

table.insert(conns, UserInputService.InputBegan:Connect(function(key)
    if key.KeyCode == Enum.KeyCode.RightShift then
        sg.Enabled = not sg.Enabled
    end
end))

maingui()
print("korpsebunny ПРОСТОЙ AIM BIND by catarsic - ✅ РАБОТАЕТ ЛЮБАЯ КЛАВИША/МЫШЬ!")
