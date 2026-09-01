--[[
    OKUMA HUB
    EB Jobs AutoFarm — Caixas | Cortar Grama | Recolher Lixo
    UI: preto / cinza profissional
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

--[[
    ===================== CONFIG EDITAVEL =====================
    Muda os valores aqui e re-executa o script.
]]
local CFG = {
    -- CAIXAS
    CaixaCooldown   = 15,

    -- CORTAR GRAMA
    GramaCooldown   = 2,
    GramaRange      = 500,

    -- RECOLHER LIXO
    LixoCooldown    = 1.5,
    LixoRange       = 500,

    -- GERAL
    PickupWait      = 0.75,
    DeliverWait     = 0.35,
    HeightOffset    = 2.5,
    UseTween        = false,
    TweenSpeed      = 100,
}

local State = {
    Caixa = false,
    Grama = false,
    Lixo  = false,
}

-- ===================== THEME =====================
local Theme = {
    Bg          = Color3.fromRGB(12, 12, 14),
    Panel       = Color3.fromRGB(18, 18, 22),
    Card        = Color3.fromRGB(24, 24, 28),
    Stroke      = Color3.fromRGB(40, 40, 48),
    Text        = Color3.fromRGB(230, 230, 235),
    TextDim     = Color3.fromRGB(140, 140, 150),
    Accent      = Color3.fromRGB(90, 90, 100),
    On          = Color3.fromRGB(70, 200, 120),
    Off         = Color3.fromRGB(55, 55, 62),
    ToggleOff   = Color3.fromRGB(45, 45, 52),
    Danger      = Color3.fromRGB(200, 70, 70),
}

-- ===================== PATHS =====================
local function jobsRoot()
    return workspace:WaitForChild("Map"):WaitForChild("Sistemas"):WaitForChild("Jobs")
end

local function caixasFolder()
    return jobsRoot():WaitForChild("Caixas")
end

local function cortarGramaFolder()
    return jobsRoot():WaitForChild("Cortar Grama")
end

local function recolherLixoFolder()
    return jobsRoot():WaitForChild("Recolher Lixo")
end

local function getCaixaPrompt()
    local part = caixasFolder():FindFirstChild("PromptPart")
    if not part then return nil end
    local pp = part:FindFirstChildWhichIsA("ProximityPrompt")
    if pp then return pp, part end
    for _, v in ipairs(part:GetDescendants()) do
        if v:IsA("ProximityPrompt") then return v, part end
    end
    return nil, part
end

local function getAreaEntrega()
    return caixasFolder():WaitForChild("LocalEntrega"):WaitForChild("AreaEntrega")
end

-- ===================== HELPERS =====================
local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function tp(cf)
    local root = hrp()
    if not root then return end
    if CFG.UseTween then
        local dist = (root.Position - cf.Position).Magnitude
        local t = math.clamp(dist / CFG.TweenSpeed, 0.08, 1.8)
        local tw = TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
        tw:Play()
        tw.Completed:Wait()
    else
        root.CFrame = cf
    end
end

local function firePrompt(prompt)
    if not prompt then return end
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait((prompt.HoldDuration or 0) + 0.05)
            prompt:InputHoldEnd()
        end
    end)
end

local function forceTouch(part)
    local root = hrp()
    if not root or not part then return end
    pcall(function()
        firetouchinterest(root, part, 0)
        task.wait(0.1)
        firetouchinterest(root, part, 1)
    end)
end

local function equipTool(name)
    if LP.Character and LP.Character:FindFirstChild(name) then return true end
    local t = LP.Backpack:FindFirstChild(name)
    if t and hum() then
        hum():EquipTool(t)
        task.wait(0.3)
        return LP.Character and LP.Character:FindFirstChild(name) ~= nil
    end
    return false
end

local function getPart(inst)
    if not inst then return nil end
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        return inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart", true)
    end
    return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function getPrompt(inst)
    if not inst then return nil end
    if inst:IsA("ProximityPrompt") then return inst end
    return inst:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function isPromptEnabled(inst)
    local pp = getPrompt(inst)
    return pp and pp.Enabled ~= false
end

-- ===================== CAIXA =====================
local function caixaPickup()
    if LP.Character and LP.Character:FindFirstChild("Caixa") then return true end
    if LP.Backpack:FindFirstChild("Caixa") then return equipTool("Caixa") end
    local prompt, part = getCaixaPrompt()
    if not prompt and not part then return false end
    local target
    if part and part:IsA("BasePart") then
        target = part.CFrame + Vector3.new(0, CFG.HeightOffset, 0)
    elseif prompt and prompt.Parent:IsA("BasePart") then
        target = prompt.Parent.CFrame + Vector3.new(0, CFG.HeightOffset, 0)
    end
    if target then tp(target) task.wait(0.2) end
    if prompt then firePrompt(prompt) end
    task.wait(CFG.PickupWait)
    return equipTool("Caixa") or (LP.Character and LP.Character:FindFirstChild("Caixa") ~= nil)
end

local function caixaDeliver()
    local area = getAreaEntrega()
    if not area then return false end
    if not (LP.Character and LP.Character:FindFirstChild("Caixa")) then
        if not equipTool("Caixa") then return false end
    end
    local cf = area:IsA("BasePart") and (area.CFrame + Vector3.new(0, CFG.HeightOffset, 0))
        or (area:GetPivot() + Vector3.new(0, CFG.HeightOffset, 0))
    tp(cf)
    task.wait(0.15)
    forceTouch(area)
    task.wait(CFG.DeliverWait)
    return true
end

local function caixaLoop()
    while State.Caixa do
        if caixaPickup() then caixaDeliver() end
        task.wait(CFG.CaixaCooldown)
    end
end

-- ===================== GRAMA =====================
local function ensureFoice()
    if equipTool("Foice") then return true end
    local foice = cortarGramaFolder():FindFirstChild("Foice")
        or LP.Backpack:FindFirstChild("Foice")
        or (LP.Character and LP.Character:FindFirstChild("Foice"))
    if not foice then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "Foice" and (v:IsA("Tool") or v:FindFirstChildWhichIsA("ProximityPrompt", true)) then
                foice = v
                break
            end
        end
    end
    if not foice then return false end
    if foice:IsA("Tool") then
        if foice.Parent == LP.Backpack or foice.Parent == LP.Character then return equipTool("Foice") end
        local handle = foice:FindFirstChild("Handle")
        if handle then
            tp(handle.CFrame + Vector3.new(0, 3, 0))
            task.wait(0.25)
            forceTouch(handle)
            task.wait(0.4)
            return equipTool("Foice")
        end
    end
    local pp = foice:FindFirstChildWhichIsA("ProximityPrompt", true)
    if pp then
        local parent = pp.Parent
        if parent:IsA("BasePart") then
            tp(parent.CFrame + Vector3.new(0, CFG.HeightOffset, 0))
        elseif parent:IsA("Model") then
            tp(parent:GetPivot() + Vector3.new(0, CFG.HeightOffset, 0))
        end
        task.wait(0.2)
        firePrompt(pp)
        task.wait(0.6)
        return equipTool("Foice")
    end
    return false
end

local function collectGramas()
    local list = {}
    local folder = cortarGramaFolder():FindFirstChild("Gramas")
    if folder then
        for _, v in ipairs(folder:GetChildren()) do table.insert(list, v) end
    end
    if #list == 0 then
        for _, v in ipairs(workspace:GetDescendants()) do
            if v.Name == "Grama" and v:FindFirstChildWhichIsA("ProximityPrompt", true) then
                table.insert(list, v)
            end
        end
    end
    return list
end

local function nearestGrama()
    local root = hrp()
    if not root then return nil end
    local best, bestDist = nil, CFG.GramaRange
    for _, g in ipairs(collectGramas()) do
        if isPromptEnabled(g) then
            local part = getPart(g)
            if part then
                local d = (part.Position - root.Position).Magnitude
                if d < bestDist then best, bestDist = g, d end
            end
        end
    end
    return best
end

local function anyGrama()
    for _, g in ipairs(collectGramas()) do
        if isPromptEnabled(g) then return g end
    end
    return nil
end

local function cutGrama(grama)
    if not grama or not ensureFoice() then return false end
    local prompt = getPrompt(grama)
    local part = getPart(grama)
    if part then
        tp(part.CFrame + Vector3.new(0, CFG.HeightOffset, 0))
        task.wait(0.2)
    elseif prompt and prompt.Parent:IsA("BasePart") then
        tp(prompt.Parent.CFrame + Vector3.new(0, CFG.HeightOffset, 0))
        task.wait(0.2)
    end
    if prompt then firePrompt(prompt) elseif part then forceTouch(part) end
    task.wait(0.35)
    return true
end

local function gramaLoop()
    while State.Grama do
        if not ensureFoice() then
            task.wait(2)
        else
            local g = nearestGrama() or anyGrama()
            if g then pcall(cutGrama, g) else task.wait(1.5) end
        end
        task.wait(CFG.GramaCooldown)
    end
end

-- ===================== LIXO =====================
local function collectLixos()
    local list = {}
    local folder = recolherLixoFolder():FindFirstChild("Lixos")
    if folder then
        for _, v in ipairs(folder:GetChildren()) do
            if v.Name == "Lixo" or getPrompt(v) then table.insert(list, v) end
        end
    end
    return list
end

local function collectLixeiras()
    local list = {}
    local folder = recolherLixoFolder():FindFirstChild("Lixeiras")
    if folder then
        for _, v in ipairs(folder:GetChildren()) do
            if v.Name == "Lixeira" or getPrompt(v) then table.insert(list, v) end
        end
    end
    return list
end

local function nearestFromList(list, range)
    local root = hrp()
    if not root then return nil end
    local best, bestDist = nil, range or 500
    for _, inst in ipairs(list) do
        if isPromptEnabled(inst) then
            local part = getPart(inst)
            if part then
                local d = (part.Position - root.Position).Magnitude
                if d < bestDist then best, bestDist = inst, d end
            end
        end
    end
    return best
end

local function anyFromList(list)
    for _, inst in ipairs(list) do
        if isPromptEnabled(inst) then return inst end
    end
    return nil
end

local function interactPromptTarget(target)
    if not target then return false end
    local prompt = getPrompt(target)
    local part = getPart(target)
    if part then
        tp(part.CFrame + Vector3.new(0, CFG.HeightOffset, 0))
        task.wait(0.2)
    elseif prompt and prompt.Parent:IsA("BasePart") then
        tp(prompt.Parent.CFrame + Vector3.new(0, CFG.HeightOffset, 0))
        task.wait(0.2)
    end
    if prompt then firePrompt(prompt) elseif part then forceTouch(part) end
    task.wait(0.4)
    return true
end

local function hasLixoTool()
    local names = {"Lixo", "Saco", "SacoDeLixo", "Trash", "Bag"}
    for _, n in ipairs(names) do
        if (LP.Character and LP.Character:FindFirstChild(n)) or LP.Backpack:FindFirstChild(n) then
            return n
        end
    end
    if LP.Character then
        for _, t in ipairs(LP.Character:GetChildren()) do
            if t:IsA("Tool") and t.Name ~= "Foice" and t.Name ~= "Caixa" then return t.Name end
        end
    end
    return nil
end

local function lixoLoop()
    while State.Lixo do
        if hasLixoTool() then
            local lixeira = nearestFromList(collectLixeiras(), CFG.LixoRange) or anyFromList(collectLixeiras())
            if lixeira then interactPromptTarget(lixeira) else task.wait(1) end
        else
            local lixo = nearestFromList(collectLixos(), CFG.LixoRange) or anyFromList(collectLixos())
            if lixo then interactPromptTarget(lixo) task.wait(0.3) else task.wait(1.2) end
        end
        task.wait(CFG.LixoCooldown)
    end
end

-- ===================== UI — OKUMA HUB =====================
local function protectGui(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui)
        elseif protect_gui then protect_gui(gui) end
    end)
    pcall(function()
        if gethui then gui.Parent = gethui()
        else gui.Parent = CoreGui end
    end)
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
    return c
end

local function stroke(parent, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color or Theme.Stroke
    s.Thickness = thick or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function pad(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop = UDim.new(0, t or 8)
    p.PaddingBottom = UDim.new(0, b or 8)
    p.PaddingLeft = UDim.new(0, l or 10)
    p.PaddingRight = UDim.new(0, r or 10)
    p.Parent = parent
    return p
end

local Gui = {}
local currentTab = "Farm"

local function createToggle(parent, text, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 42)
    row.BackgroundColor3 = Theme.Card
    row.BorderSizePixel = 0
    row.Parent = parent
    corner(row, 8)
    stroke(row, Theme.Stroke, 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -70, 1, 0)
    label.Position = UDim2.new(0, 14, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.TextColor3 = Theme.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(0, 44, 0, 24)
    track.Position = UDim2.new(1, -56, 0.5, -12)
    track.BackgroundColor3 = default and Theme.On or Theme.ToggleOff
    track.BorderSizePixel = 0
    track.Parent = row
    corner(track, 12)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(245, 245, 250)
    knob.BorderSizePixel = 0
    knob.Parent = track
    corner(knob, 9)

    local on = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    btn.MouseButton1Click:Connect(function()
        on = not on
        local goalTrack = on and Theme.On or Theme.ToggleOff
        local goalKnob = on and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        TweenService:Create(track, TweenInfo.new(0.18), {BackgroundColor3 = goalTrack}):Play()
        TweenService:Create(knob, TweenInfo.new(0.18), {Position = goalKnob}):Play()
        callback(on)
    end)

    return row
end

local function createSlider(parent, text, min, max, default, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 58)
    row.BackgroundColor3 = Theme.Card
    row.BorderSizePixel = 0
    row.Parent = parent
    corner(row, 8)
    stroke(row, Theme.Stroke, 1)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.7, 0, 0, 22)
    label.Position = UDim2.new(0, 14, 0, 6)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = Theme.Text
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local valueLbl = Instance.new("TextLabel")
    valueLbl.Size = UDim2.new(0.3, -14, 0, 22)
    valueLbl.Position = UDim2.new(0.7, 0, 0, 6)
    valueLbl.BackgroundTransparency = 1
    valueLbl.Text = tostring(default)
    valueLbl.Font = Enum.Font.GothamBold
    valueLbl.TextSize = 13
    valueLbl.TextColor3 = Theme.TextDim
    valueLbl.TextXAlignment = Enum.TextXAlignment.Right
    valueLbl.Parent = row

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -28, 0, 6)
    barBg.Position = UDim2.new(0, 14, 1, -18)
    barBg.BackgroundColor3 = Theme.ToggleOff
    barBg.BorderSizePixel = 0
    barBg.Parent = row
    corner(barBg, 3)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    corner(fill, 3)

    local dragging = false
    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 1, 12)
    hit.Position = UDim2.new(0, 0, 0.5, -6)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.Parent = barBg

    local function update(inputX)
        local rel = math.clamp((inputX - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * rel + 0.5)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        valueLbl.Text = tostring(val)
        callback(val)
    end

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input.Position.X)
        end
    end)

    return row
end

local function buildUI()
    if Gui.Screen then Gui.Screen:Destroy() end

    local screen = Instance.new("ScreenGui")
    screen.Name = "OkumaHub"
    screen.ResetOnSpawn = false
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    protectGui(screen)
    Gui.Screen = screen

    -- Main window
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 420, 0, 340)
    main.Position = UDim2.new(0.5, -210, 0.5, -170)
    main.BackgroundColor3 = Theme.Bg
    main.BorderSizePixel = 0
    main.Active = true
    main.Parent = screen
    corner(main, 12)
    stroke(main, Theme.Stroke, 1.5)
    Gui.Main = main

    -- Header
    local header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Theme.Panel
    header.BorderSizePixel = 0
    header.Parent = main
    corner(header, 12)

    -- fix bottom corners of header
    local headerFix = Instance.new("Frame")
    headerFix.Size = UDim2.new(1, 0, 0, 14)
    headerFix.Position = UDim2.new(0, 0, 1, -14)
    headerFix.BackgroundColor3 = Theme.Panel
    headerFix.BorderSizePixel = 0
    headerFix.Parent = header

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -90, 1, 0)
    title.Position = UDim2.new(0, 16, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "OKUMA HUB"
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Theme.Text
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = header

    local sub = Instance.new("TextLabel")
    sub.Size = UDim2.new(0, 80, 0, 16)
    sub.Position = UDim2.new(0, 16, 1, -18)
    sub.BackgroundTransparency = 1
    sub.Text = "EB Jobs"
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 11
    sub.TextColor3 = Theme.TextDim
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Parent = header

    -- Floating reopen button (hidden until minimized)
    local floatBtn = Instance.new("TextButton")
    floatBtn.Name = "OkumaFloat"
    floatBtn.Size = UDim2.new(0, 48, 0, 48)
    floatBtn.Position = UDim2.new(0, 20, 0.5, -24)
    floatBtn.BackgroundColor3 = Theme.Panel
    floatBtn.Text = "OK"
    floatBtn.Font = Enum.Font.GothamBold
    floatBtn.TextSize = 14
    floatBtn.TextColor3 = Theme.Text
    floatBtn.Visible = false
    floatBtn.ZIndex = 50
    floatBtn.Parent = screen
    corner(floatBtn, 12)
    stroke(floatBtn, Theme.Stroke, 1.5)

    local floatDragging, floatStart, floatPos
    floatBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            floatDragging = true
            floatStart = input.Position
            floatPos = floatBtn.Position
        end
    end)
    floatBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            -- if barely moved, treat as click to reopen
            local moved = floatStart and (input.Position - floatStart).Magnitude or 0
            floatDragging = false
            if moved < 6 then
                main.Visible = true
                floatBtn.Visible = false
            end
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if floatDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - floatStart
            floatBtn.Position = UDim2.new(floatPos.X.Scale, floatPos.X.Offset + delta.X, floatPos.Y.Scale, floatPos.Y.Offset + delta.Y)
        end
    end)

    local function minimizeHub()
        main.Visible = false
        floatBtn.Visible = true
    end

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 32, 0, 32)
    minBtn.Position = UDim2.new(1, -78, 0.5, -16)
    minBtn.BackgroundColor3 = Theme.Card
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 18
    minBtn.TextColor3 = Theme.TextDim
    minBtn.Parent = header
    corner(minBtn, 8)
    minBtn.MouseButton1Click:Connect(minimizeHub)

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0.5, -16)
    closeBtn.BackgroundColor3 = Theme.Card
    closeBtn.Text = "×"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 20
    closeBtn.TextColor3 = Theme.TextDim
    closeBtn.Parent = header
    corner(closeBtn, 8)
    closeBtn.MouseButton1Click:Connect(function()
        State.Caixa = false
        State.Grama = false
        State.Lixo = false
        screen:Destroy()
    end)

    -- Sidebar
    local side = Instance.new("Frame")
    side.Size = UDim2.new(0, 110, 1, -56)
    side.Position = UDim2.new(0, 8, 0, 52)
    side.BackgroundColor3 = Theme.Panel
    side.BorderSizePixel = 0
    side.Parent = main
    corner(side, 10)
    stroke(side, Theme.Stroke, 1)

    local sideList = Instance.new("UIListLayout")
    sideList.Padding = UDim.new(0, 6)
    sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sideList.Parent = side
    pad(side, 10, 10, 8, 8)

    -- Content
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -134, 1, -56)
    content.Position = UDim2.new(0, 126, 0, 52)
    content.BackgroundColor3 = Theme.Panel
    content.BorderSizePixel = 0
    content.Parent = main
    corner(content, 10)
    stroke(content, Theme.Stroke, 1)

    local contentScroll = Instance.new("ScrollingFrame")
    contentScroll.Size = UDim2.new(1, -16, 1, -16)
    contentScroll.Position = UDim2.new(0, 8, 0, 8)
    contentScroll.BackgroundTransparency = 1
    contentScroll.BorderSizePixel = 0
    contentScroll.ScrollBarThickness = 3
    contentScroll.ScrollBarImageColor3 = Theme.Accent
    contentScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    contentScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    contentScroll.Parent = content

    local contentList = Instance.new("UIListLayout")
    contentList.Padding = UDim.new(0, 8)
    contentList.SortOrder = Enum.SortOrder.LayoutOrder
    contentList.Parent = contentScroll
    pad(contentScroll, 4, 8, 4, 4)

    -- pages
    local pages = {}

    local function clearContent()
        for _, c in ipairs(contentScroll:GetChildren()) do
            if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
                c:Destroy()
            end
        end
    end

    local function showFarm()
        clearContent()
        currentTab = "Farm"

        local section = Instance.new("TextLabel")
        section.Size = UDim2.new(1, 0, 0, 20)
        section.BackgroundTransparency = 1
        section.Text = "JOBS"
        section.Font = Enum.Font.GothamBold
        section.TextSize = 12
        section.TextColor3 = Theme.TextDim
        section.TextXAlignment = Enum.TextXAlignment.Left
        section.Parent = contentScroll

        createToggle(contentScroll, "Caixas", State.Caixa, function(on)
            State.Caixa = on
            if on then task.spawn(caixaLoop) end
        end)

        createToggle(contentScroll, "Cortar Grama", State.Grama, function(on)
            State.Grama = on
            if on then task.spawn(gramaLoop) end
        end)

        createToggle(contentScroll, "Recolher Lixo", State.Lixo, function(on)
            State.Lixo = on
            if on then task.spawn(lixoLoop) end
        end)

        local section2 = Instance.new("TextLabel")
        section2.Size = UDim2.new(1, 0, 0, 20)
        section2.BackgroundTransparency = 1
        section2.Text = "TIMINGS"
        section2.Font = Enum.Font.GothamBold
        section2.TextSize = 12
        section2.TextColor3 = Theme.TextDim
        section2.TextXAlignment = Enum.TextXAlignment.Left
        section2.Parent = contentScroll

        createSlider(contentScroll, "Caixa Cooldown", 5, 30, CFG.CaixaCooldown, function(v)
            CFG.CaixaCooldown = v
        end)

        createSlider(contentScroll, "Grama Cooldown", 0.5, 10, CFG.GramaCooldown, function(v)
            CFG.GramaCooldown = v
        end)

        createSlider(contentScroll, "Lixo Cooldown", 0.5, 10, CFG.LixoCooldown, function(v)
            CFG.LixoCooldown = v
        end)
    end

    local function showSettings()
        clearContent()
        currentTab = "Settings"

        local section = Instance.new("TextLabel")
        section.Size = UDim2.new(1, 0, 0, 20)
        section.BackgroundTransparency = 1
        section.Text = "MOVIMENTO"
        section.Font = Enum.Font.GothamBold
        section.TextSize = 12
        section.TextColor3 = Theme.TextDim
        section.TextXAlignment = Enum.TextXAlignment.Left
        section.Parent = contentScroll

        createToggle(contentScroll, "Usar Tween", CFG.UseTween, function(on)
            CFG.UseTween = on
        end)

        createSlider(contentScroll, "Tween Speed", 40, 200, CFG.TweenSpeed, function(v)
            CFG.TweenSpeed = v
        end)

        createSlider(contentScroll, "Height Offset", 0, 8, CFG.HeightOffset, function(v)
            CFG.HeightOffset = v
        end)

        local section2 = Instance.new("TextLabel")
        section2.Size = UDim2.new(1, 0, 0, 20)
        section2.BackgroundTransparency = 1
        section2.Text = "RANGE"
        section2.Font = Enum.Font.GothamBold
        section2.TextSize = 12
        section2.TextColor3 = Theme.TextDim
        section2.TextXAlignment = Enum.TextXAlignment.Left
        section2.Parent = contentScroll

        createSlider(contentScroll, "Grama Range", 50, 800, CFG.GramaRange, function(v)
            CFG.GramaRange = v
        end)

        createSlider(contentScroll, "Lixo Range", 50, 800, CFG.LixoRange, function(v)
            CFG.LixoRange = v
        end)
    end

    -- sidebar buttons
    local function makeTabBtn(name, emoji, order, onClick)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 56)
        btn.BackgroundColor3 = Theme.Card
        btn.Text = ""
        btn.LayoutOrder = order
        btn.Parent = side
        corner(btn, 8)

        local icon = Instance.new("TextLabel")
        icon.Name = "Emoji"
        icon.Size = UDim2.new(1, 0, 0, 26)
        icon.Position = UDim2.new(0, 0, 0, 6)
        icon.BackgroundTransparency = 1
        icon.Text = emoji
        icon.TextSize = 20
        icon.Font = Enum.Font.GothamBold
        icon.TextColor3 = Theme.TextDim
        icon.Parent = btn

        local lbl = Instance.new("TextLabel")
        lbl.Name = "Label"
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.Position = UDim2.new(0, 0, 1, -20)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextColor3 = Theme.TextDim
        lbl.Parent = btn

        btn.MouseButton1Click:Connect(function()
            for _, child in ipairs(side:GetChildren()) do
                if child:IsA("TextButton") then
                    child.BackgroundColor3 = Theme.Card
                    local em = child:FindFirstChild("Emoji")
                    local tx = child:FindFirstChild("Label")
                    if em then em.TextColor3 = Theme.TextDim end
                    if tx then tx.TextColor3 = Theme.TextDim end
                end
            end
            btn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
            icon.TextColor3 = Theme.Text
            lbl.TextColor3 = Theme.Text
            onClick()
        end)

        return btn
    end

    local farmBtn = makeTabBtn("Farm", "🌾", 1, showFarm)
    makeTabBtn("Settings", "⚙️", 2, showSettings)

    -- default select farm
    farmBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    local fem = farmBtn:FindFirstChild("Emoji")
    local ftx = farmBtn:FindFirstChild("Label")
    if fem then fem.TextColor3 = Theme.Text end
    if ftx then ftx.TextColor3 = Theme.Text end
    showFarm()

    -- drag
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    header.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- toggle key
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.RightShift then
            if main.Visible then
                minimizeHub()
            else
                main.Visible = true
                floatBtn.Visible = false
            end
        end
    end)
end

buildUI()
print("[Okuma Hub] carregado | RightShift = mostrar/esconder")
