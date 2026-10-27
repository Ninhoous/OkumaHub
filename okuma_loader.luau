-- Okuma loader (jnkie key system)
-- Use:  loadstring(game:HttpGet("https://raw.githubusercontent.com/Ninhoous/OkumaHub/main/okuma_loader.luau"))()
-- Asks for the key, checks it with the jnkie public SDK, then loads the protected script from jnkie.
-- A saved key is checked silently, so the teleports of the auto loops come back without the window.
-- On the service's keyless days (jnkie schedule) it skips the window and loads right away.
-- Any other game just gets a "not supported" notice.
-- SDK reference: https://docs.jnkie.com/roblox-sdk/public-sdk

-- ============================================================================
-- CONFIG  (jnkie dashboard values; none of them is a secret)
-- ============================================================================
local CONFIG = {
    service = "Okuma",  -- Services: the service name (or its numeric id)
    identifier = "1226841", -- your Junkie user id (dashboard), not a Roblox or Discord id
    provider = "",      -- Providers: the one behind "Get key" (Linkvertise, Work.ink, ...)
    discord = "",       -- invite copied by the Discord button ("" hides it)
    oneTimeKeys = false, -- true when the service gives one-time keys: check_key would burn them, so it is skipped
    keyFile = "Okuma/key.txt",
}
-- GameId (every place of the game: menu, lobby, match servers) -> id = the jnkie script's public token
-- (the part of its loadstring after /public/)
local UNIVERSES = {
    [4658598196] = { name = "Attack on Titan Revolution", id = "797b542977672b9df976f2cd4a33e3695ee87229fcecbb8c0dfe90b376ad42c0" },
}

-- ============================================================================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local LocalPlayer = Players.LocalPlayer
local genv = (type(getgenv) == "function" and getgenv()) or _G

local function notify(text)
    pcall(function() StarterGui:SetCore("SendNotification", { Title = "Okuma", Text = text, Duration = 7 }) end)
end

local entry = UNIVERSES[game.GameId]
if not entry then notify("This game is not supported yet."); return end

-- PREVIEW: with the jnkie values still empty the window opens against a fake SDK, so the look can be tested.
-- Key "okuma" passes, "expired" / "hwid" show those errors, anything else is invalid. Nothing is saved or loaded.
local PREVIEW = CONFIG.service == "" or CONFIG.identifier == ""
local Junkie
if PREVIEW then
    notify("Preview: jnkie not set up yet. Try the key \"okuma\".")
    Junkie = {
        check_key = function(k)
            task.wait(0.9)
            if k == "okuma" then return { valid = true, is_keyless = false, is_premium = false, message = "KEY_VALID" } end
            return { valid = false, error = (k == "expired" and "KEY_EXPIRED") or (k == "hwid" and "HWID_MISMATCH") or "KEY_INVALID" }
        end,
        get_key_link = function() task.wait(0.6); return "https://jnkie.com/preview-key-link", nil end,
        load_script = function() notify("Preview: " .. entry.name .. " would load now.") end,
    }
else
    local okSdk, lib = pcall(function() return loadstring(game:HttpGet("https://jnkie.com/sdk/library.lua"))() end)
    if not okSdk or type(lib) ~= "table" then notify("Could not reach the key service. Try again later."); return end
    Junkie = lib
end
Junkie.service, Junkie.identifier, Junkie.script_id = CONFIG.service, CONFIG.identifier, entry.id
if CONFIG.provider ~= "" then Junkie.provider = CONFIG.provider end

-- saved key
local function readKey()
    if not (isfile and readfile) then return nil end
    local ok, has = pcall(isfile, CONFIG.keyFile)
    if not (ok and has) then return nil end
    local ok2, k = pcall(readfile, CONFIG.keyFile)
    k = ok2 and type(k) == "string" and k:match("^%s*(.-)%s*$") or nil
    return (k and k ~= "") and k or nil
end
local function saveKey(k)
    if PREVIEW or not writefile then return end
    pcall(function()
        if makefolder and isfolder and not isfolder("Okuma") then makefolder("Okuma") end
        writefile(CONFIG.keyFile, k or "")
    end)
end

local MESSAGES = {
    KEY_INVALID = "Invalid key.",
    KEY_EXPIRED = "This key expired. Get a new one.",
    KEY_INVALIDATED = "This key was disabled.",
    ALREADY_USED = "This key was already used.",
    HWID_MISMATCH = "This key is bound to another device. Ask for an HWID reset on the Discord.",
    HWID_BANNED = "This device is banned.",
    SERVICE_MISMATCH = "This key is for another script.",
    SERVICE_NOT_FOUND = "The key service is unavailable.",
    PREMIUM_REQUIRED = "This script needs a premium key.",
    ["http 429"] = "Too many tries. Wait a minute.",
}
-- true, nil | false, message
local function check(key)
    if CONFIG.oneTimeKeys then return true end
    local ok, res = pcall(Junkie.check_key, key)
    if not ok or type(res) ~= "table" then warn("[Okuma key] check failed: " .. tostring(res)); return false, "Could not reach the key service. Try again." end
    warn(("[Okuma key] valid=%s message=%s keyless=%s premium=%s error=%s"):format(tostring(res.valid), tostring(res.message),
        tostring(res.is_keyless), tostring(res.is_premium), tostring(res.error)))
    -- a keyless service lets any text through; that is a dashboard setting, not a key, so it is refused here
    if res.valid and (res.is_keyless or res.message == "KEYLESS") then
        return false, "The service is in keyless mode on jnkie (any key passes). Turn keyless off in Services."
    end
    if res.valid then return true end
    return false, MESSAGES[tostring(res.error)] or ("Key not accepted (" .. tostring(res.error) .. ").")
end

local function launch(key)
    genv.SCRIPT_KEY = key
    local ok, err = pcall(Junkie.load_script)
    if not ok then notify("Could not load " .. entry.name .. "."); warn("[Okuma key] " .. tostring(err)) end
end

-- keyless days (set on the jnkie dashboard): "KEYLESS" passes, straight in, no window; the saved key is kept
if not PREVIEW then
    local ok, res = pcall(Junkie.check_key, "KEYLESS")
    if ok and type(res) == "table" and res.valid and (res.is_keyless or res.message == "KEYLESS") then
        notify("Keyless day: no key needed.")
        launch("KEYLESS")
        return
    end
end

-- a saved key that still passes: straight in, no window
local saved = not PREVIEW and readKey() or nil
local savedErr
if saved then
    local ok, why = check(saved)
    if ok then launch(saved); return end
    savedErr = why
    saveKey("")
end


-- ============================================================================
-- WINDOW  (the Okuma shell's look: Mono palette, Gotham SSm, logo, accent glint on the border, Back pop)
-- ============================================================================
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local C = {
    deep = Color3.fromRGB(16, 16, 17), card = Color3.fromRGB(25, 25, 26), alt = Color3.fromRGB(41, 41, 42),
    hover = Color3.fromRGB(52, 52, 53), border = Color3.fromRGB(63, 63, 65), low = Color3.fromRGB(47, 47, 49),
    text = Color3.fromRGB(236, 236, 240), dim = Color3.fromRGB(140, 140, 150), mute = Color3.fromRGB(84, 84, 90),
    ok = Color3.fromRGB(110, 220, 130), warn = Color3.fromRGB(240, 190, 110), err = Color3.fromRGB(240, 110, 130),
}
local F = {
    bold = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
    medium = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
    regular = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular),
}
-- same asset ids as shell.luau ICONS (the logo keeps its own colours)
local ICON = {
    logo = 89786629350927, shield = 13780781482, play = 8517323802, copy = 85360060654230, globe = 121176334529781,
    target = 107058246184363, check = 13289068631,
}
local function New(class, props)
    local o = Instance.new(class)
    for k, v in pairs(props) do if k ~= "Parent" then o[k] = v end end
    if props.Parent then o.Parent = props.Parent end
    return o
end
local function round(p, r) return New("UICorner", { CornerRadius = UDim.new(0, r), Parent = p }) end
local function stroke(p, c) return New("UIStroke", { Color = c, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p }) end
local function tween(o, props, t, style)
    local tw = TweenService:Create(o, TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function icon(parent, name, size, color)
    local img = New("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.new(0, size, 0, size), ScaleType = Enum.ScaleType.Fit,
        Image = "rbxthumb://type=Asset&id=" .. ICON[name] .. "&w=150&h=150", Parent = parent })
    if color then img.ImageColor3 = color end
    return img
end
-- click ripple (the shell's): a soft circle grows from the pointer inside a rounded CanvasGroup
local function ripple(btn, color)
    local abs, size = btn.AbsolutePosition, btn.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then return end
    local m = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
    local host = New("CanvasGroup", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = btn })
    round(host, 10)
    local dot = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color, BackgroundTransparency = 0.75,
        Position = UDim2.fromScale(math.clamp((m.X - abs.X) / size.X, 0, 1), math.clamp((m.Y - abs.Y) / size.Y, 0, 1)),
        Size = UDim2.fromScale(0, 0), BorderSizePixel = 0, Parent = host })
    New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = dot })
    New("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width, Parent = dot })
    tween(dot, { Size = UDim2.fromScale(2.4, 2.4), BackgroundTransparency = 1 }, 0.55, Enum.EasingStyle.Quad)
    task.delay(0.6, function() host:Destroy() end)
end

local gui = New("ScreenGui", { Name = "OkumaKey", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 1000,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling })
pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
if not pcall(function() gui.Parent = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui") end) then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end
local conns = {}
local function track(c) conns[#conns + 1] = c; return c end

-- the screen dims behind the window; on touch-only devices a plain frame (a CanvasGroup blurs when scaled down)
local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local dim = New("Frame", { Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
    BorderSizePixel = 0, Parent = gui })
local W, H = 380, 278
local win = New(touchOnly and "Frame" or "CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.new(0, W, 0, H), BackgroundColor3 = C.deep, BorderSizePixel = 0, Parent = gui })
if not touchOnly then win.GroupTransparency = 1 end
round(win, 16)
local scale = New("UIScale", { Scale = 0.9, Parent = win })
local cam = workspace.CurrentCamera
local fit = (cam and cam.ViewportSize.X < W + 32) and (cam.ViewportSize.X - 32) / W or 1
-- accent glint running round the border (white stroke, the gradient carries Border with an accent band)
local border = stroke(win, Color3.new(1, 1, 1))
local glint = New("UIGradient", { Parent = border, Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, C.border), ColorSequenceKeypoint.new(0.38, C.border), ColorSequenceKeypoint.new(0.5, C.text),
    ColorSequenceKeypoint.new(0.62, C.border), ColorSequenceKeypoint.new(1, C.border) }) })
track(RunService.RenderStepped:Connect(function() glint.Rotation = (os.clock() * 40) % 360 end))

-- header: logo tile, title, game, close
local tile = New("Frame", { Position = UDim2.new(0, 20, 0, 20), Size = UDim2.new(0, 36, 0, 36), BackgroundTransparency = 1, Parent = win })
local logo = icon(tile, "logo", 36)
logo.AnchorPoint, logo.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0)
round(logo, 10)
track(tile.MouseEnter:Connect(function()
    tween(logo, { Rotation = -12, Size = UDim2.new(0, 39, 0, 39) }, 0.12, Enum.EasingStyle.Quad)
    task.delay(0.12, function() tween(logo, { Rotation = 0, Size = UDim2.new(0, 36, 0, 36) }, 0.6, Enum.EasingStyle.Elastic) end)
end))
New("TextLabel", { Position = UDim2.new(0, 66, 0, 20), Size = UDim2.new(1, -120, 0, 18), BackgroundTransparency = 1, Text = "Okuma",
    TextColor3 = C.text, FontFace = F.bold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, Parent = win })
New("TextLabel", { Position = UDim2.new(0, 66, 0, 40), Size = UDim2.new(1, -120, 0, 14), BackgroundTransparency = 1,
    Text = PREVIEW and "Key system  ·  preview" or "Key system  ·  v3",
    TextColor3 = C.dim, FontFace = F.regular, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = win })
local closeBtn = New("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.new(0, 28, 0, 28),
    BackgroundColor3 = C.card, BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = win })
round(closeBtn, 8)
local closeX = New("TextLabel", { Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "×", TextColor3 = C.dim,
    FontFace = F.medium, TextSize = 20, Parent = closeBtn })

-- game chip
local chip = New("Frame", { Position = UDim2.new(0, 20, 0, 70), Size = UDim2.new(0, 0, 0, 24), AutomaticSize = Enum.AutomaticSize.X,
    BackgroundColor3 = C.card, BorderSizePixel = 0, Parent = win })
round(chip, 12)
stroke(chip, C.low)
New("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 11), Parent = chip })
New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chip })
icon(chip, "target", 12, C.dim)
New("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = entry.name,
    TextColor3 = C.text, FontFace = F.medium, TextSize = 11, LayoutOrder = 2, Parent = chip })

-- key box: shield icon, input, spinner while checking
local box = New("Frame", { Position = UDim2.new(0, 20, 0, 106), Size = UDim2.new(1, -40, 0, 42), BackgroundColor3 = C.card,
    BorderSizePixel = 0, Parent = win })
round(box, 10)
local boxStroke = stroke(box, C.low)
local boxIcon = icon(box, "shield", 16, C.dim)
boxIcon.AnchorPoint, boxIcon.Position = Vector2.new(0, 0.5), UDim2.new(0, 13, 0.5, 0)
local input = New("TextBox", { Position = UDim2.new(0, 38, 0, 0), Size = UDim2.new(1, -76, 1, 0), BackgroundTransparency = 1,
    Text = "", PlaceholderText = "Paste your key", PlaceholderColor3 = C.mute, TextColor3 = C.text, FontFace = F.medium,
    TextSize = 13, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
local spinner = New("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -13, 0.5, 0), Size = UDim2.new(0, 16, 0, 16),
    BackgroundTransparency = 1, Visible = false, Parent = box })
New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = spinner })
local spinStroke = New("UIStroke", { Color = C.text, Thickness = 2, Parent = spinner })
local spinGrad = New("UIGradient", { Parent = spinStroke, Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.55, 0.15), NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1) }) })
track(RunService.RenderStepped:Connect(function() if spinner.Visible then spinGrad.Rotation = (os.clock() * 420) % 360 end end))
track(input.Focused:Connect(function() tween(boxStroke, { Color = C.dim }); tween(boxIcon, { ImageColor3 = C.text }) end))
track(input.FocusLost:Connect(function() tween(boxStroke, { Color = C.low }); tween(boxIcon, { ImageColor3 = C.dim }) end))

-- status: dot + text
local statusRow = New("Frame", { Position = UDim2.new(0, 22, 0, 158), Size = UDim2.new(1, -44, 0, 30), BackgroundTransparency = 1, Parent = win })
local statusDot = New("Frame", { Position = UDim2.new(0, 0, 0, 4), Size = UDim2.new(0, 6, 0, 6), BackgroundColor3 = C.mute,
    BorderSizePixel = 0, Parent = statusRow })
New("UICorner", { CornerRadius = UDim.new(1, 0), Parent = statusDot })
local status = New("TextLabel", { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -14, 1, 0), BackgroundTransparency = 1,
    Text = "Get a key, paste it above and press Verify.", TextColor3 = C.dim, FontFace = F.regular, TextSize = 11, TextWrapped = true,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Parent = statusRow })
local function setStatus(text, color)
    status.Text = text
    tween(status, { TextColor3 = color or C.dim })
    tween(statusDot, { BackgroundColor3 = color or C.mute })
    statusDot.Size = UDim2.new(0, 2, 0, 2)
    statusDot.Position = UDim2.new(0, 2, 0, 6)
    tween(statusDot, { Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0, 0, 0, 4) }, 0.4, Enum.EasingStyle.Back)
end
if savedErr then setStatus("Saved key: " .. savedErr, C.warn) end

-- buttons: icon + label, hover, ripple
local row = New("Frame", { Position = UDim2.new(0, 20, 1, -80), Size = UDim2.new(1, -40, 0, 38), BackgroundTransparency = 1, Parent = win })
New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
local function button(text, iconName, primary, order, width)
    local b = New("TextButton", { Size = UDim2.new(width, primary and 0 or -6, 1, 0), LayoutOrder = order, AutoButtonColor = false,
        BackgroundColor3 = primary and C.text or C.card, Text = "", ClipsDescendants = true, Parent = row })
    round(b, 10)
    if not primary then stroke(b, C.low) end
    local inner = New("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 0, 0, 16),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = b })
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder, Parent = inner })
    local ic = icon(inner, iconName, 14, primary and C.deep or C.text)
    local lbl = New("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
        Text = text, TextColor3 = primary and C.deep or C.text, FontFace = F.medium, TextSize = 13, LayoutOrder = 2, Parent = inner })
    local base = b.BackgroundColor3
    track(b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = primary and C.dim:Lerp(C.text, 0.78) or C.alt }) end))
    track(b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = base }) end))
    track(b.Activated:Connect(function()
        ripple(b, primary and C.deep or C.text)
        ic.Size = UDim2.new(0, 11, 0, 11)
        tween(ic, { Size = UDim2.new(0, 14, 0, 14) }, 0.4, Enum.EasingStyle.Back)
    end))
    return b, lbl, ic
end
if PREVIEW and CONFIG.discord == "" then CONFIG.discord = "https://discord.gg/preview" end
local hasDiscord = CONFIG.discord ~= ""
local verifyBtn, verifyLbl, verifyIcon = button("Verify", "play", true, 1, hasDiscord and 0.38 or 0.5)
local getBtn, getLbl = button("Get key", "copy", false, 2, hasDiscord and 0.34 or 0.5)
local discordBtn = hasDiscord and button("Discord", "globe", false, 3, 0.28) or nil
New("TextLabel", { Position = UDim2.new(0, 20, 1, -30), Size = UDim2.new(1, -40, 0, 14), BackgroundTransparency = 1,
    Text = "The key is saved on this device. Next time you go straight in.", TextColor3 = C.mute, FontFace = F.regular, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Parent = win })

-- drag by the window
do
    local dragging, start, origin
    track(win.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, start, origin = true, i.Position, win.Position
            i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            win.Position = UDim2.new(origin.X.Scale, origin.X.Offset + d.X, origin.Y.Scale, origin.Y.Offset + d.Y)
        end
    end))
end

-- open: dim in, window pops (Back) and fades in
tween(dim, { BackgroundTransparency = 0.45 }, 0.3)
tween(scale, { Scale = fit }, 0.45, Enum.EasingStyle.Back)
if not touchOnly then tween(win, { GroupTransparency = 0 }, 0.25) end

local finished = false
local function close()
    if finished then return end
    finished = true
    tween(dim, { BackgroundTransparency = 1 }, 0.25)
    tween(scale, { Scale = fit * 0.92 }, 0.22, Enum.EasingStyle.Quad)
    if touchOnly then win.Visible = false else tween(win, { GroupTransparency = 1 }, 0.22) end
    task.delay(0.3, function()
        for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
        gui:Destroy()
    end)
end
-- wrong key: the window shakes and the border flashes red
local function shake()
    local p = win.Position
    tween(boxStroke, { Color = C.err }, 0.1)
    for _, dx in ipairs({ -10, 9, -7, 5, -3, 0 }) do
        tween(win, { Position = UDim2.new(p.X.Scale, p.X.Offset + dx, p.Y.Scale, p.Y.Offset) }, 0.05, Enum.EasingStyle.Sine)
        task.wait(0.05)
    end
    task.delay(0.6, function() tween(boxStroke, { Color = input:IsFocused() and C.dim or C.low }, 0.4) end)
end

-- actions
local busy = false
local function setBusy(on)
    busy = on
    spinner.Visible = on
    verifyLbl.Text = on and "Checking" or "Verify"
    tween(verifyBtn, { BackgroundTransparency = on and 0.35 or 0 })
end
local function verify()
    if busy or finished then return end
    local key = input.Text:match("^%s*(.-)%s*$")
    if key == "" then setStatus("Paste a key first.", C.warn); task.spawn(shake); return end
    setBusy(true)
    setStatus("Checking the key...")
    local ok, why = check(key)
    setBusy(false)
    if not ok then setStatus(why, C.err); shake(); return end
    -- accepted: green border, check icon, then out
    setStatus("Key accepted. Loading " .. entry.name .. "...", C.ok)
    tween(boxStroke, { Color = C.ok }, 0.2)
    boxIcon.Image = "rbxthumb://type=Asset&id=" .. ICON.check .. "&w=150&h=150"
    tween(boxIcon, { ImageColor3 = C.ok }, 0.2)
    verifyLbl.Text = "Verified"
    verifyIcon.Image = boxIcon.Image
    saveKey(key)
    task.wait(0.8)
    close()
    launch(key)
end
track(verifyBtn.Activated:Connect(function() task.spawn(verify) end))
track(input.FocusLost:Connect(function(enter) if enter then task.spawn(verify) end end))

local linkBusy = false
track(getBtn.Activated:Connect(function()
    if linkBusy then return end
    if CONFIG.provider == "" and not PREVIEW then setStatus("Keys are given on the Discord.", C.warn); return end
    linkBusy = true
    getLbl.Text = "Getting..."
    task.spawn(function()
        local ok, link, err = pcall(Junkie.get_key_link)
        linkBusy = false
        getLbl.Text = "Get key"
        if not ok or not link then
            setStatus(err == "RATE_LIMITTED" and "Too many requests. Wait a minute." or "Could not get a key link. Try again.", C.err)
            return
        end
        if setclipboard then
            pcall(setclipboard, link)
            setStatus("Key link copied. Open it in your browser.", C.ok)
            getLbl.Text = "Copied"
            task.delay(1.6, function() if not finished then getLbl.Text = "Get key" end end)
        else
            input.Text = link
            setStatus("Your executor can't copy: the link is in the box above.", C.warn)
        end
    end)
end))
if discordBtn then
    track(discordBtn.Activated:Connect(function()
        if setclipboard then pcall(setclipboard, CONFIG.discord); setStatus("Discord invite copied.", C.ok)
        else input.Text = CONFIG.discord end
    end))
end
track(closeBtn.MouseEnter:Connect(function() tween(closeBtn, { BackgroundTransparency = 0 }); tween(closeX, { TextColor3 = C.text, Rotation = 90 }, 0.3) end))
track(closeBtn.MouseLeave:Connect(function() tween(closeBtn, { BackgroundTransparency = 1 }); tween(closeX, { TextColor3 = C.dim, Rotation = 0 }, 0.3) end))
track(closeBtn.Activated:Connect(close))
