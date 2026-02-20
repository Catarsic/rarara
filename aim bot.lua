local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local lp = Players.LocalPlayer
local cam = Workspace.CurrentCamera

local gethui = gethui or function() return lp:WaitForChild("PlayerGui") end

local vars = {
    teamcheck = false,
    fov = 120,
    aimlock = false,
    esp = true,
    headhit = false,
    autofire = false,
    target = nil,
    distance = "N/A",
    color = Color3.fromRGB(255, 182, 193),
    smooth = 0.2,
    spin = 6,
    bhspeed = 35,
    walkspeed = 16,
    wallcheck = true,
    firerate = 0.1,
    lastfire = 0
}

local espobjs = {}
local conns = {}
local sliderconns = {}

local sg, mf, sf

local function raycast(part, char)
    if not vars.wallcheck then return true end
    local origin = cam.CFrame.Position
    local dir = part.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {lp.Character}
    local res = Workspace:Raycast(origin, dir, params)
    return not res or res.Instance:IsDescendantOf(char)
end

local function closest()
    local closest, dist = nil, math.huge
    local center = cam.ViewportSize/2
    local pos = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") and lp.Character.HumanoidRootPart.Position or Vector3.new()
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            local hitpart = vars.headhit and plr.Character:FindFirstChild("Head") or plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChild("Humanoid")
            if hitpart and hum and hum.Health > 0 and (not vars.teamcheck or plr.Team ~= lp.Team) then
                if raycast(hitpart, plr.Character) then
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
        local hitpart = vars.headhit and vars.target.Character:FindFirstChild("Head") or vars.target.Character:FindFirstChild("HumanoidRootPart")
        if hitpart and raycast(hitpart, vars.target.Character) then
            local vel = hitpart.Velocity or Vector3.new()
            local pred = math.clamp(0.05 + (vars.distance/2000), 0.02, 0.1)
            local predictpos = hitpart.Position + vel * pred
            cam.CFrame = cam.CFrame:Lerp(CFrame.new(cam.CFrame.Position, predictpos), vars.smooth)
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
            vu:Button1Up(Vector3.new())
        end
    end)
    
    if mouse1click then mouse1click() end
end

-- bunnyhop setup
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
    local sliderconns = {}

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

    local moveconn = UserInputService.InputChanged:Connect(function(i)
        if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
            moved(i)
        end
    end)

    local endconn = UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)

    table.insert(sliderconns, {moveconn, endconn})
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
    mf.Size = UDim2.new(0, 320, 0, 500)
    mf.Position = UDim2.new(1, -340, 0, 50)
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
    title.Text = "by catarsic"
    title.ZIndex = 6
    title.Parent = mf

    -- кнопки 2x3
    local btns = {
        {pos=UDim2.new(0,10,0,42), txt="Aimlock: OFF", var="aimlock"},
        {pos=UDim2.new(0,10,0,78), txt="Head Aim: OFF", var="headhit"},
        {pos=UDim2.new(0,10,0,114), txt="ESP: ON", var="esp"},
        {pos=UDim2.new(0,165,0,42), txt="AutoFire: OFF", var="autofire"},
        {pos=UDim2.new(0,165,0,78), txt="Spinbot: OFF", var="spin"},
        {pos=UDim2.new(0,165,0,114), txt="Bunnyhop: OFF", var="bunnyhop"}
    }

    for i, b in ipairs(btns) do
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(0, 140, 0, 28)
        button.Position = b.pos
        button.BackgroundColor3 = Color3.fromRGB(45,45,45)
        button.BorderColor3 = vars.color
        button.Text = b.txt
        button.TextColor3 = Color3.new(1,1,1)
        button.TextScaled = true
        button.Font = Enum.Font.SourceSans
        button.ZIndex = 6
        button.Parent = mf
        
        button.MouseButton1Click:Connect(function()
            vars[b.var] = not vars[b.var]
            button.Text = b.txt:gsub(":%s*...$", ": "..(vars[b.var] and "ON" or "OFF"))
        end)
    end

    sf = Instance.new("Frame")
    sf.Size = UDim2.new(0, 280, 0, 500)
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
    makeslider(scroll, 94, "Spin Speed", 1, 60, vars.spin, 260, function(v) vars.spin = v end)
    makeslider(scroll, 154, "Bunny Speed", 10, 120, vars.bhspeed, 260, function(v) vars.bhspeed = v end)
    makeslider(scroll, 214, "Fire Rate", 0.03, 1, vars.firerate, 260, function(v) vars.firerate = v end)
    makeslider(scroll, 274, "FOV", 30, 200, vars.fov, 260, function(v) vars.fov = vars.fov end)

    setbtn.MouseButton1Click:Connect(function()
        sf.Visible = not sf.Visible
        scroll.ScrollBarImageColor3 = vars.color
    end)

    local themelbl = Instance.new("TextLabel")
    themelbl.Size = UDim2.new(0, 300, 0, 18)
    themelbl.Position = UDim2.new(0,10,0,320)
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
    end

    for i, t in ipairs(themes) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(0, 70, 0, 24)
        tb.Position = UDim2.new(0, 10+(i-1)*75, 0, 342)
        tb.BackgroundColor3 = t[1]
        tb.Text = t[2]
        tb.TextColor3 = Color3.new(1,1,1)
        tb.ZIndex = 6
        tb.Parent = mf
        tb.MouseButton1Click:Connect(function() sett(t[1]) end)
    end

    local distlbl = Instance.new("TextLabel")
    distlbl.Size = UDim2.new(0, 300, 0, 18)
    distlbl.Position = UDim2.new(0,10,0,380)
    distlbl.BackgroundTransparency = 1
    distlbl.TextColor3 = Color3.new(1,1,1)
    distlbl.TextScaled = true
    distlbl.Text = "Distance: N/A"
    distlbl.ZIndex = 6
    distlbl.Parent = mf
end

-- основные лупы
table.insert(conns, RunService.RenderStepped:Connect(function()
    distlbl.Text = "Distance: "..vars.distance
end))

table.insert(conns, RunService.RenderStepped:Connect(function()
    if vars.esp then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= lp and plr.Character and not espobjs[plr] then
                local h = Instance.new("Highlight")
                h.Adornee = plr.Character
                h.FillColor = vars.color
                h.FillTransparency = 0.5
                h.OutlineColor = Color3.new(1,1,1)
                h.OutlineTransparency = 0.3
                h.Parent = plr.Character
                espobjs[plr] = h
            end
        end
    else
        for plr, h in pairs(espobjs) do
            if h then h:Destroy() end
            espobjs[plr] = nil
        end
    end
end))

table.insert(conns, RunService.RenderStepped:Connect(function()
    if vars.aimlock and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        if not vars.target then vars.target = closest() end
        if vars.target then
            aimat()
            if vars.autofire then
                local now = tick()
                if now-vars.lastfire >= vars.firerate then
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
    if vars.spin then
        local char = lp.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
            if root then
                root.CFrame = root.CFrame * CFrame.Angles(0, math.rad(vars.spin), 0)
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
print("by catarsic")
