local HttpGet = game:HttpGet
local ROUTES = {
    -- Steal An Egg
    [107778070777162] = "https://api.redstoneguard.xyz/api/loader/95b209b3-00cc-41df-abcc-d04353022a7f/init",

}

local function loadScriptForPlace()
    local placeId = game.PlaceId
    local url = ROUTES[placeId]

    if not url then
        warn("[PlundererHub] No script found for this game (PlaceId: " .. placeId .. ")")
        return
    end

    local success, err = pcall(function()
        loadstring(HttpGet(url))()
    end)

    if not success then
        warn("[PlundererHub] Failed to load script: " .. tostring(err))
    end
end

loadScriptForPlace()
