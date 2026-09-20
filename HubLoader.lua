local HttpGet = game:HttpGet

local ROUTES = {
    -- Steal An Egg
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/f57732b2-b144-4aa4-8beb-80789d4ad6aa/init",
}

local function loadScriptForPlace()
    local url = ROUTES[game.PlaceId]
    if not url then
        warn("[PlundererHub] No script for this game")
        return
    end

    local ok, err = pcall(function()
        loadstring(HttpGet(url))()
    end)

    if not ok then
        warn("[PlundererHub] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
