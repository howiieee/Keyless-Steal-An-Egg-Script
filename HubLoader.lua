scriptkey = "keyless"

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local function showPreAuthUI()
    local screen = Instance.new("ScreenGui")
    screen.Name = "HubLoaderPreAuth"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.DisplayOrder = 999999
    screen.Parent = PlayerGui

    local bg = Instance.new("Frame")
    bg.Size = UDim2.fromScale(1, 1)
    bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
    bg.BorderSizePixel = 0
    bg.Parent = screen

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.Position = UDim2.fromScale(0.5, 0.5)
    label.Size = UDim2.fromOffset(400, 40)
    label.Font = Enum.Font.GothamMedium
    label.Text = "Authenticating..."
    label.TextSize = 18
    label.TextColor3 = Color3.fromRGB(128, 255, 160)
    label.Parent = bg

    return screen
end

local function hidePreAuthUI(screen)
    if screen then screen:Destroy() end
end

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
    local preUI = showPreAuthUI()

    task.spawn(function()
        task.wait(15)  -- safety: kill pre-UI if auth hangs
        hidePreAuthUI(preUI)
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

    hidePreAuthUI(preUI)

    if not ok then
        warn("[PlundererHub] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
