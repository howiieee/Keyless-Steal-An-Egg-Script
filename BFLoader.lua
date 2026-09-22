scriptkey = "keyless"

local Players      = game:GetService("Players")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")

local gv = (getgenv and getgenv()) or _G

local function cleanupOldScreens()
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        if gui.Name == "HubLoaderAuth" or gui.Name == "HubLoaderPreAuth" then
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
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/f57732b2-b144-4aa4-8beb-80789d4ad6aa/init",
}

-- =========================================================
-- Safe execution: sandboxed, threaded, and timeout-guarded
-- =========================================================
local EXEC_TIMEOUT = 30 -- seconds before we assume the script hung

local function safeExecute(source)
    local env = setmetatable({}, { __index = getfenv(0) })
    env.script = nil
    env.getgenv = function() return gv end
    env._G = gv
    -- Note: we intentionally DO NOT set env.game / env.workspace / etc.
    -- They resolve through __index from the real global env, which is what
    -- the script needs (game:GetService, workspace, task, etc.).

    local fn, compileErr = loadstring(source)
    if not fn then
        return false, "Compile error: " .. tostring(compileErr)
    end

    if setfenv then
        setfenv(fn, env)
    end

    local thread = coroutine.create(fn)
    local t0 = os.clock()
    local success, result

    while coroutine.status(thread) == "suspended" or coroutine.status(thread) == "running" do
        success, result = coroutine.resume(thread)
        if not success then
            return false, "Runtime error: " .. tostring(result)
        end
        if coroutine.status(thread) == "dead" then
            return true, result
        end
        if os.clock() - t0 > EXEC_TIMEOUT then
            return false, ("Execution timeout (%ds) — script aborted."):format(EXEC_TIMEOUT)
        end
        task.wait() -- yield a frame so the client stays responsive
    end

    return true, result
end

local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[HubLoader] No script for this game (PlaceId " .. tostring(game.PlaceId) .. ")")
        clearBusyFlag()
        return
    end

    scriptkey = "keyless"

    local authUI = showAuthUI()

    -- Hard safety: if for any reason the script never finishes, we still
    -- clear the busy flag after 2 * EXEC_TIMEOUT.
    task.delay(EXEC_TIMEOUT * 2, function()
        if gv.__HUBLOADER_BUSY then
            warn("[HubLoader] Force-clearing busy flag after extended wait.")
            clearBusyFlag()
        end
    end)

    local body = nil
    local fetchOk, fetchErr = pcall(function()
        body = game:HttpGet(url)
    end)

    if not fetchOk or type(body) ~= "string" or #body == 0 then
        warn("[HubLoader] Failed to fetch script: " .. tostring(fetchErr))
        pcall(function() authUI.destroy() end)
        clearBusyFlag()
        return
    end

    local ok, err = safeExecute(body)

    pcall(function() authUI.destroy() end)
    clearBusyFlag()

    if not ok then
        warn("[HubLoader] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
