-- ===== Set global so RedstoneGuard's core can find it =====
scriptkey = "keyless"

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")

-- ===== Small floating auth indicator =====
local function showAuthPill()
    local screen = Instance.new("ScreenGui")
    screen.Name = "HubLoaderAuthPill"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 999999
    screen.Parent = PlayerGui

    local pill = Instance.new("Frame")
    pill.Name = "Pill"
    pill.AnchorPoint = Vector2.new(0.5, 0)
    pill.Position = UDim2.new(0.5, 0, 0, 16)
    pill.Size = UDim2.fromOffset(200, 34)
    pill.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    pill.BackgroundTransparency = 1
    pill.BorderSizePixel = 0
    pill.Parent = screen

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 17)
    corner.Parent = pill

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(128, 255, 160)
    stroke.Thickness = 1
    stroke.Transparency = 1
    stroke.Parent = pill

    -- Animated dot on the left
    local dot = Instance.new("Frame")
    dot.Size = UDim2.fromOffset(8, 8)
    dot.Position = UDim2.new(0, 14, 0.5, -4)
    dot.BackgroundColor3 = Color3.fromRGB(128, 255, 160)
    dot.BorderSizePixel = 0
    dot.BackgroundTransparency = 1
    dot.Parent = pill
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 30, 0, 0)
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = "Authenticating..."
    label.TextSize = 12
    label.TextColor3 = Color3.fromRGB(128, 255, 160)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTransparency = 1
    label.Parent = pill

    -- Pulse animation on dot
    local pulseAlive = true
    task.spawn(function()
        while pulseAlive and pill.Parent do
            TweenService:Create(dot, TweenInfo.new(0.6), {
                BackgroundTransparency = 0.2,
                Size = UDim2.fromOffset(10, 10),
                Position = UDim2.new(0, 13, 0.5, -5),
            }):Play()
            task.wait(0.6)
            TweenService:Create(dot, TweenInfo.new(0.6), {
                BackgroundTransparency = 0.7,
                Size = UDim2.fromOffset(8, 8),
                Position = UDim2.new(0, 14, 0.5, -4),
            }):Play()
            task.wait(0.6)
        end
    end)

    -- Fade in
    TweenService:Create(pill, TweenInfo.new(0.25), { BackgroundTransparency = 0.15 }):Play()
    TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 0.4 }):Play()
    TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()

    return {
        destroy = function()
            pulseAlive = false
            TweenService:Create(pill, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(stroke, TweenInfo.new(0.25), { Transparency = 1 }):Play()
            TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 1 }):Play()
            TweenService:Create(dot, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
            task.wait(0.3)
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
        return
    end

    scriptkey = "keyless"

    -- Show the small pill
    local pill = showAuthPill()

    -- Safety timeout: kill the pill if auth hangs beyond 20s
    task.delay(20, function()
        pcall(function() pill.destroy() end)
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

    -- Hide pill — the real LoaderUI takes over from here
    pcall(function() pill.destroy() end)

    if not ok then
        warn("[PlundererHub] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
