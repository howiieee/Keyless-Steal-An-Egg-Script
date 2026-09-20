-- ===== Set global so RedstoneGuard's core can find it =====
scriptkey = "keyless"

local Players      = game:GetService("Players")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

-- =========================================================
-- Re-entry guard — blocks double-execute during auth
-- =========================================================
local gv = (getgenv and getgenv()) or _G
if gv.__HUBLOADER_BUSY then
    warn("[HubLoader] Already authenticating — please wait.")
    return
end
gv.__HUBLOADER_BUSY = true

local function clearBusyFlag()
    gv.__HUBLOADER_BUSY = false
end

-- Safety: auto-clear the flag after 30s no matter what happens
task.delay(30, clearBusyFlag)
-- =========================================================

-- =========================================================
-- Small floating auth UI (top-center pill)
-- =========================================================
local function showAuthUI()
    local screen = Instance.new("ScreenGui")
    screen.Name = "HubLoaderAuth"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 999999
    screen.Parent = PlayerGui

    -- Invisible full-screen input blocker
    local blocker = Instance.new("TextButton")
    blocker.Name = "Blocker"
    blocker.Size = UDim2.fromScale(1, 1)
    blocker.BackgroundTransparency = 1
    blocker.Text = ""
    blocker.AutoButtonColor = false
    blocker.Modal = true
    blocker.Active = true
    blocker.Parent = screen

    -- The pill
    local pill = Instance.new("Frame")
    pill.Name = "Pill"
    pill.AnchorPoint = Vector2.new(0.5, 0)
    pill.Position = UDim2.new(0.5, 0, 0, 18)
    pill.Size = UDim2.fromOffset(170, 32)
    pill.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
    pill.BackgroundTransparency = 1
    pill.BorderSizePixel = 0
    pill.Active = false
    pill.Parent = screen

    local pillCorner = Instance.new("UICorner")
    pillCorner.CornerRadius = UDim.new(0, 16)
    pillCorner.Parent = pill

    local pillStroke = Instance.new("UIStroke")
    pillStroke.Color = Color3.fromRGB(128, 255, 160)
    pillStroke.Thickness = 1
    pillStroke.Transparency = 1
    pillStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    pillStroke.Parent = pill

    -- Spinner (a small rotating arc made from a UIStroke circle)
    local spinnerFrame = Instance.new("Frame")
    spinnerFrame.Name = "Spinner"
    spinnerFrame.Size = UDim2.fromOffset(14, 14)
    spinnerFrame.Position = UDim2.new(0, 11, 0.5, -7)
    spinnerFrame.BackgroundTransparency = 1
    spinnerFrame.Parent = pill

    local spinnerRing = Instance.new("Frame")
    spinnerRing.Size = UDim2.fromScale(1, 1)
    spinnerRing.BackgroundTransparency = 1
    spinnerRing.Parent = spinnerFrame

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = spinnerRing

    local ringStroke = Instance.new("UIStroke")
    ringStroke.Color = Color3.fromRGB(128, 255, 160)
    ringStroke.Thickness = 1.8
    ringStroke.Transparency = 0.65
    ringStroke.Parent = spinnerRing

    -- The active arc (a partial ring that rotates)
    local arc = Instance.new("Frame")
    arc.Size = UDim2.fromScale(1, 1)
    arc.BackgroundTransparency = 1
    arc.Parent = spinnerFrame

    local arcCorner = Instance.new("UICorner")
    arcCorner.CornerRadius = UDim.new(1, 0)
    arcCorner.Parent = arc

    local arcStroke = Instance.new("UIStroke")
    arcStroke.Color = Color3.fromRGB(128, 255, 160)
    arcStroke.Thickness = 1.8
    arcStroke.Transparency = 0.05
    arcStroke.Parent = arc

    -- Rotation loop
    local spinning = true
    task.spawn(function()
        while spinning and spinnerFrame.Parent do
            local t0 = tick()
            while spinning and spinnerFrame.Parent and (tick() - t0) < 1 do
                local angle = ((tick() - t0) / 1) * 360
                spinnerFrame.Rotation = angle
                RunService.RenderStepped:Wait()
            end
        end
    end)

    -- Label
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 30, 0, 0)
    label.Size = UDim2.new(1, -36, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = "Authenticating..."
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(200, 240, 210)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextTransparency = 1
    label.Parent = pill

    -- Fade in
    TweenService:Create(pill,       TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
    TweenService:Create(pillStroke, TweenInfo.new(0.2), { Transparency = 0.35 }):Play()
    TweenService:Create(label,      TweenInfo.new(0.2), { TextTransparency = 0 }):Play()

    return {
        destroy = function()
            spinning = false
            TweenService:Create(pill,       TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
            TweenService:Create(pillStroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
            TweenService:Create(label,      TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
            task.wait(0.25)
            if screen.Parent then screen:Destroy() end
        end,
    }
end

-- =========================================================
-- ROUTES — add new games here as you set them up
-- =========================================================
local ROUTES = {
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/f57732b2-b144-4aa4-8beb-80789d4ad6aa/init",
}

-- =========================================================
-- Main flow
-- =========================================================
local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[HubLoader] No script for this game (PlaceId " .. tostring(game.PlaceId) .. ")")
        clearBusyFlag()
        return
    end

    scriptkey = "keyless"

    -- Show small pill + input blocker
    local authUI = showAuthUI()

    -- Safety net: kill the UI if auth hangs
    task.delay(20, function()
        pcall(function() authUI.destroy() end)
        clearBusyFlag()
    end)

    -- Run RedstoneGuard auth
    local ok, err = pcall(function()
        local body = game:HttpGet(url)
        if type(body) ~= "string" or #body == 0 then
            error("Empty response from RedstoneGuard")
        end
        local fn = loadstring(body)
        if not fn then
            error("Compile failed")
        end
        fn()
    end)

    -- Cleanup — the LoaderUI takes over from here
    pcall(function() authUI.destroy() end)
    clearBusyFlag()

    if not ok then
        warn("[HubLoader] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
