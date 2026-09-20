scriptkey = "keyless"

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

    local ok, err = pcall(function()
        local body = game:HttpGet(url)
        if type(body) ~= "string" or #body == 0 then
            error("Empty response from RedstoneGuard")
        end
        local fn, compileErr = loadstring(body)
        if not fn then
            error("Compile failed: " .. tostring(compileErr))
        end
        fn()
    end)

    if not ok then
        warn("[PlundererHub] Failed: " .. tostring(err))
    end
end

loadScriptForPlace()
