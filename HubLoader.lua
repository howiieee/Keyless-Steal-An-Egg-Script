-- ===== Set global so RedstoneGuard's core can find it =====
scriptkey = "keyless"

local Players      = game:GetService("Players")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")

-- ===== Re-entry guard (prevents double-execute during auth) =====
local gv = (getgenv and getgenv()) or _G
if gv.__HUBLOADER_BUSY then
    warn("[HubLoader] Already authenticating — please wait.")
    return
end
gv.__HUBLOADER_BUSY = true

-- ===== Small floating auth UI + input blocker =====
local function showAuthUI()
    local screen = Instance.new("ScreenGui")
    screen.Name = "HubLoaderAuth"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 999999
    screen.Parent = PlayerGui

    -- Invisible full-screen click-catcher (blocks input without covering the view visually)
    local blocker = Instance.new("TextButton")
    blocker.Name = "Blocker"
    blocker.Size = UDim2.fromScale(1, 1)
    blocker.BackgroundTransparency = 1
    blocker.Text = ""
    blocker.AutoButtonColor = false
    blocker.Modal = true
    blocker.Active = true
    blocker.Parent = screen

    -- The small pill
    local pill = Instance.new("Frame")
    pill.Name = "Pill"
    pill.AnchorPoint = Vector2.new(0.5, 0)
    pill.Position = UDim2.new(0.5, 0, 0, 16)
    pill.Size = UDim2.fromOffset(180, 32)
    pill.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    pill.BackgroundTransparency = 1
    pill.BorderSizePixel = 0
    pill.Active = false
    pill.Parent = screen

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = pill

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(128, 255, 160)
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.Parent = pill

    -- Pulsing green dot
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.new(0, 12, 0.5, -4)
    dot.BackgroundColor3 = Color3.fromRGB(128, 255, 160)
    dot.BorderSizePixel = 0
    dot.BackgroundTransparency = 1
    dot.Parent = pill
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 28, 0, 0)
    label.Size = UDim2.new(1, -36, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = "Authenticating..."
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(128, 255, 160)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTransparency = 1
    label.Parent = pill

    -- Pulse the dot
    local alive = true
    task.spawn(function()
        while alive and pill.Parent do
            TweenService:Create(dot, TweenInfo.new(0.55), {
                BackgroundTransparency = 0.15,
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.new(0, 11, 0.5, -5),
            }):Play()
            task.wait(0.55)
            TweenService:Create(dot, TweenInfo.new(0.55), {
                BackgroundTransparency = 0.75,
                Size = UDim2.fromOffset(8, 8),
                Position = UDim2.new(0, 12, 0.5, -4),
            }):Play()
            task.wait(0.55)
        end
    end)

    -- Fade in
    TweenService:Create(pill,   TweenInfo.new(0.2), { BackgroundTransparency = 0.15 }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 0.4 }):Play()
    TweenService:Create(label,  TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

    return {
        destroy = function()
            alive = false
            TweenService:Create(pill,   TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
            TweenService:Create(label,  TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
            TweenService:Create(dot,    TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            task.wait(0.25)
            if screen.Parent then screen:Destroy() end
        end,
    }
end

-- ===== ROUTES =====
local ROUTES = {
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/f57732b2-b144-4aa4-8beb-80789d4ad6aa/init",
}

local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[PlundererHub] No script for this game")
        gv.__HUBLOADER_BUSY = false
        return
    end

    scriptkey = "keyless"

    -- Show small pill + input blocker
    local authUI = showAuthUI()

    -- Safety: kill UI after 20s no matter what
    task.delay(20, function()
        pcall(function() authUI.destroy() end)
        gv.__HUBLOADER_BUSY = false
    end)

    local ok, err = pcall(function()
        local body = game:HttpGet(url)
        if type(body) ~= "string" or #body == 0 then
            error("Empty response from RedstoneGuard")
        end
        local fn = loadstring(body)
        if not fn then error("Compile failed") end
        fn()
    end)

    -- Auth finished — remove the small pill and clear the busy flag
    pcall(function() authUI.destroy() end)
    gv.__HUBLOADER_BUSY = false

    if not ok then
        warn("[PlundererHub] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
