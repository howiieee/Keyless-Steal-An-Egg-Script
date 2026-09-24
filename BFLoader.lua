scriptkey = "keyless"

local Players      = game:GetService("Players")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")

local gv = (getgenv and getgenv()) or _G

local function cleanupOldScreens()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui.Name == "HubLoaderAuth" or gui.Name == "HubLoaderPreAuth" or gui.Name == "HubLoaderError" then
            pcall(function() gui:Destroy() end)
        end
    end
end
cleanupOldScreens()

if gv.__HUBLOADER_BUSY then
    warn("[HubLoader] Already authenticating — please wait.")
    return
end
gv.__HUBLOADER_BUSY = true

local function clearBusyFlag()
    gv.__HUBLOADER_BUSY = false
end

task.delay(30, clearBusyFlag)

-- =========================================================
-- Error UI (Displays Maintenance Messages)
-- =========================================================
local function showErrorUI(messageText)
    cleanupOldScreens()

    local screen = Instance.new("ScreenGui")
    screen.Name = "HubLoaderError"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 999999
    screen.Parent = PlayerGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
    bg.BackgroundTransparency = 0.3
    bg.BorderSizePixel = 0
    bg.Parent = screen

    local box = Instance.new("Frame")
    box.Size = UDim2.fromOffset(360, 140)
    box.Position = UDim2.fromScale(0.5, 0.5)
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    box.Parent = bg

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = box

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 85, 85)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = box

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextColor3 = Color3.fromRGB(255, 85, 85)
    title.Text = "Connection Rejected"
    title.Parent = box

    local desc = Instance.new("TextLabel")
    desc.Size = UDim2.new(1, -40, 1, -50)
    desc.Position = UDim2.fromOffset(20, 35)
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.GothamMedium
    desc.TextSize = 14
    desc.TextColor3 = Color3.fromRGB(220, 220, 230)
    desc.TextWrapped = true
    desc.Text = messageText or "An unknown error occurred."
    desc.Parent = box

    -- Animate In
    box.Size = UDim2.fromOffset(340, 120)
    TweenService:Create(box, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.fromOffset(360, 140)
    }):Play()

    -- Auto-destroy after 5 seconds
    task.delay(5, function()
        TweenService:Create(box, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        TweenService:Create(desc, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
        TweenService:Create(title, TweenInfo.new(0.2), { TextTransparency = 1 }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.2), { Transparency = 1 }):Play()
        TweenService:Create(bg, TweenInfo.new(0.2), { BackgroundTransparency = 1 }):Play()
        task.wait(0.25)
        pcall(function() screen:Destroy() end)
    end)
end

-- =========================================================
-- Authentication UI
-- =========================================================
local function showAuthUI()
    cleanupOldScreens()

    local screen = Instance.new("ScreenGui")
    screen.Name = "HubLoaderAuth"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 999999
    screen.Enabled = true
    screen.Parent = PlayerGui

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

    local spinnerFrame = Instance.new("Frame")
    spinnerFrame.Name = "Spinner"
    spinnerFrame.Size = UDim2.fromOffset(14, 14)
    spinnerFrame.Position = UDim2.new(0, 11, 0.5, -7)
    spinnerFrame.BackgroundTransparency = 1
    spinnerFrame.Active = false
    spinnerFrame.Parent = pill

    local spinnerRing = Instance.new("Frame")
    spinnerRing.Size = UDim2.fromScale(1, 1)
    spinnerRing.BackgroundTransparency = 1
    spinnerRing.Active = false
    spinnerRing.Parent = spinnerFrame

    local ringCorner = Instance.new("UICorner")
    ringCorner.CornerRadius = UDim.new(1, 0)
    ringCorner.Parent = spinnerRing

    local ringStroke = Instance.new("UIStroke")
    ringStroke.Color = Color3.fromRGB(128, 255, 160)
    ringStroke.Thickness = 1.8
    ringStroke.Transparency = 0.65
    ringStroke.Parent = spinnerRing

    local arc = Instance.new("Frame")
    arc.Size = UDim2.fromScale(1, 1)
    arc.BackgroundTransparency = 1
    arc.Active = false
    arc.Parent = spinnerFrame

    local arcCorner = Instance.new("UICorner")
    arcCorner.CornerRadius = UDim.new(1, 0)
    arcCorner.Parent = arc

    local arcStroke = Instance.new("UIStroke")
    arcStroke.Color = Color3.fromRGB(128, 255, 160)
    arcStroke.Thickness = 1.8
    arcStroke.Transparency = 0.05
    arcStroke.Parent = arc

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
    label.Active = false
    label.Parent = pill

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

local ROUTES = {
    [107778070777162] = "https://raw.githubusercontent.com/howiieee/Keyless-Steal-An-Egg-Script/refs/heads/main/ObfSaeLoader2.lua",
}

local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[HubLoader] No script for this game.")
        showErrorUI("No script configured for this game.")
        clearBusyFlag()
        return
    end

    scriptkey = "keyless"
    local authUI = showAuthUI()

    task.delay(20, function()
        pcall(function() authUI.destroy() end)
        clearBusyFlag()
    end)

    local ok, err = pcall(function()
        local body = game:HttpGet(url)
        if type(body) ~= "string" or #body == 0 then
            error("Empty response from RedstoneGuard")
        end
        
        -- Intercept JSON error responses (like Maintenance Mode)
        local jsonOk, decoded = pcall(function() return HttpService:JSONDecode(body) end)
        if jsonOk and type(decoded) == "table" and (decoded.success == false or decoded.message) then
            error(decoded.message or "Service unavailable.")
        end

        local fn = loadstring(body)
        if not fn then
            error("Compile failed.")
        end
        fn()
    end)

    pcall(function() authUI.destroy() end)
    clearBusyFlag()

    if not ok then
        -- Clean up lua tracebacks (e.g., "[string \"...\"]:15: ")
        local cleanErr = tostring(err)
        if cleanErr:match(":%d+: (.*)") then
            cleanErr = cleanErr:match(":%d+: (.*)")
        end
        
        warn("[HubLoader] Failed: " .. cleanErr)
        showErrorUI(cleanErr)
    end
end

loadScriptForPlace()
