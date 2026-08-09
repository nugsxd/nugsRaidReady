--------------------------------------------------------------------------------
-- RaidReady
-- Copyright (c) 2026 nugs. All Rights Reserved.
-- Unauthorized copying, distribution, or modification is prohibited. See LICENSE.
--------------------------------------------------------------------------------
-- RaidReady  -  Core.lua
-- Shared namespace: the second vararg is the same table across every Lua file
-- in this addon, so we hang all of our state and functions off of it.
local ADDON_NAME, RAA = ...

RAA.version = C_AddOns and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or "0.1.0"

--------------------------------------------------------------------------------
-- Secret values
--
-- 12.1 widens which unit APIs can hand back a "secret": UnitClass, UnitRace,
-- UnitSex, UnitGroupRolesAssigned and GetInspectSpecialization all return one
-- whenever the unit's identity is itself secret, which inside an instance it is.
--
-- A secret may be drawn on screen but never measured, compared, concatenated or
-- used as a table key - and a class token's whole job here is to be a table key,
-- in RAID_CLASS_COLORS. So anything that could be secret goes through Plain(),
-- which hands back nil instead. nil means "cannot know right now", and a nil class
-- draws in the default colour rather than throwing.
--
-- Your own identity is never secret, so UnitClass("player") needs no guard. The
-- raid path is also safe: GetRaidRosterInfo returns the class as plain data and is
-- not on the list.
--------------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue

function RAA.Plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

--------------------------------------------------------------------------------
-- API shims
-- Retail (The War Within, 11.x) moved the AddOn functions into the C_AddOns
-- namespace. We fall back to the old globals so the file at least loads on
-- older clients, but this addon targets retail.
--------------------------------------------------------------------------------
local GetNumAddOns     = (C_AddOns and C_AddOns.GetNumAddOns)     or _G.GetNumAddOns
local GetAddOnInfo     = (C_AddOns and C_AddOns.GetAddOnInfo)     or _G.GetAddOnInfo
local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata

--------------------------------------------------------------------------------
-- Small helpers
--------------------------------------------------------------------------------

-- Reduce a full "Name-Realm" (or plain "Name") to a stable lowercase key.
-- We drop the realm to keep same-realm/cross-realm names comparable. Duplicate
-- base names across realms in one raid is rare; documented as a v1 limitation.
function RAA.NameKey(name)
    if not name or name == "" then return nil end
    local base = name:match("^[^-]+") or name
    return base:lower()
end

-- Parse a version string into a list of numeric components, e.g.
-- "11.2.3-release" -> {11, 2, 3}. Non-numeric junk is ignored.
local function parseVersion(v)
    local parts = {}
    for num in tostring(v or ""):gmatch("%d+") do
        parts[#parts + 1] = tonumber(num)
    end
    return parts
end

-- Compare two version strings. Returns -1 if a<b, 0 if equal, 1 if a>b.
-- Best-effort: compares numeric components left to right, missing = 0.
function RAA.CompareVersion(a, b)
    local ta, tb = parseVersion(a), parseVersion(b)
    local n = math.max(#ta, #tb)
    for i = 1, n do
        local x, y = ta[i] or 0, tb[i] or 0
        if x < y then return -1 elseif x > y then return 1 end
    end
    return 0
end

--------------------------------------------------------------------------------
-- Installed-addon enumeration
-- The game client already indexes every addon in the AddOns folder and exposes
-- it here, so we never touch the filesystem. This sees enabled AND disabled
-- addons, loaded or not.
--------------------------------------------------------------------------------

-- Build { [lowercaseFolderName] = { name = "FolderName", version = "x.y.z" } }
function RAA:BuildInstalledMap()
    local map = {}
    local total = GetNumAddOns() or 0
    for i = 1, total do
        local folder = GetAddOnInfo(i)          -- folder name on disk
        if folder then
            local ver = GetAddOnMetadata(i, "Version")
                     or GetAddOnMetadata(folder, "Version")
            map[folder:lower()] = { name = folder, version = ver or "" }
        end
    end
    self.installed = map
    return map
end

-- Look up the installed version of a required addon by folder name.
-- Returns the version string, or nil if not installed. "" = installed but the
-- author left no ## Version in the .toc.
function RAA:InstalledVersionOf(folderName)
    if not self.installed then self:BuildInstalledMap() end
    local entry = self.installed[tostring(folderName):lower()]
    if not entry then return nil end
    return entry.version or ""
end

--------------------------------------------------------------------------------
-- Requirements (SavedVariables)
-- RaidReadyDB.required = { ["DBM-Core"] = "0", ["WeakAuras"] = "5.19" }
-- A min version of "" or "0" means "any installed version is fine".
--------------------------------------------------------------------------------

function RAA:GetRequirements()
    return RaidReadyDB and RaidReadyDB.required or {}
end

function RAA:AddRequirement(folderName, minVersion)
    folderName = folderName and folderName:gsub("^%s+", ""):gsub("%s+$", "")
    if not folderName or folderName == "" then return false end
    RaidReadyDB.required[folderName] = (minVersion and minVersion:gsub("%s+", "")) or ""
    return true
end

function RAA:RemoveRequirement(folderName)
    RaidReadyDB.required[folderName] = nil
end

-- Ordered list of required folder names (for stable UI + comms).
function RAA:RequiredNames()
    local names = {}
    for name in pairs(self:GetRequirements()) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

--------------------------------------------------------------------------------
-- Compliance evaluation
-- Given a reporter's {folderName = version} table, decide per-requirement status.
-- status: "ok" | "outdated" | "missing" | "noversion"
--------------------------------------------------------------------------------
-- Compare a `reported` {folder=version} table against a `required`
-- {folder=minVersion} table. Returns an overall worst status plus a per-addon
-- details table. Used by BOTH the leader (evaluating members' reports) and each
-- raider (evaluating themselves against the broadcast requirements).
function RAA:EvaluateAgainst(required, reported)
    local details = {}
    local worst = "ok"   -- ok < noversion < outdated < missing (for overall)
    local rank = { ok = 0, noversion = 1, outdated = 2, missing = 3 }

    for folder, minVer in pairs(required) do
        local have = reported[folder] or reported[folder:lower()]
        local status
        if have == nil then
            status = "missing"
        elseif minVer == "" or minVer == "0" then
            status = (have == "") and "noversion" or "ok"
        elseif have == "" then
            status = "noversion"   -- installed but can't verify version
        elseif RAA.CompareVersion(have, minVer) < 0 then
            status = "outdated"
        else
            status = "ok"
        end
        details[folder] = { have = have, need = minVer, status = status }
        if rank[status] > rank[worst] then worst = status end
    end

    return worst, details
end

-- Leader-side convenience: evaluate a member's report against our own required list.
function RAA:EvaluateReport(reported)
    return self:EvaluateAgainst(self:GetRequirements(), reported)
end

--------------------------------------------------------------------------------
-- Raid roster
--------------------------------------------------------------------------------

-- Returns an ordered list of { display = "Name", key = "namekey" } for the
-- current group. Falls back to just the player when solo (useful for testing).
function RAA:GetRosterMembers()
    local members = {}
    local seen = {}
    local function add(display, online, class)
        local key = RAA.NameKey(display)
        if key and not seen[key] then
            seen[key] = true
            members[#members + 1] = {
                display = Ambiguate(display, "none"),
                key = key,
                online = online and true or false,  -- normalize nil -> false
                class = class,                       -- class token, e.g. "MAGE"
            }
        end
    end

    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, _, _, _, fileName, _, online = GetRaidRosterInfo(i)
            if name then add(name, online, fileName) end
        end
    elseif IsInGroup() then
        add(UnitName("player"), true, select(2, UnitClass("player")))
        for i = 1, GetNumGroupMembers() - 1 do
            local unit = "party" .. i
            local name = GetUnitName(unit, true)
            -- Plain: a party member's class is secret from 12.1 whenever their
            -- identity is, and this value ends up indexing RAID_CLASS_COLORS.
            if name then add(name, UnitIsConnected(unit), RAA.Plain(select(2, UnitClass(unit)))) end
        end
    else
        add(GetUnitName("player", true) or UnitName("player"), true, select(2, UnitClass("player")))
    end
    return members
end

--------------------------------------------------------------------------------
-- Gear check: missing enchants and empty gem sockets
--------------------------------------------------------------------------------
local SLOT_NAMES = {
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [5] = "Chest", [6] = "Waist",
    [7] = "Legs", [8] = "Feet", [9] = "Wrist", [10] = "Hands", [11] = "Ring 1",
    [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2", [15] = "Cloak",
    [16] = "Main Hand", [17] = "Off Hand",
}

-- Slots expected to carry an enchant. Midnight (12.0) has no wrist or cloak
-- enchants, so those are intentionally absent.
local ENCHANTABLE = {
    [5] = true,   -- Chest
    [7] = true,   -- Legs
    [8] = true,   -- Feet
    [11] = true, [12] = true,  -- Rings
    [16] = true, [17] = true,  -- Weapons
}

-- Localized "…Socket" strings, harvested from the EMPTY_SOCKET_* globals so this
-- works in any locale and picks up new socket types automatically.
local emptySocketText
local function socketTexts()
    if emptySocketText then return emptySocketText end
    emptySocketText = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and k:sub(1, 12) == "EMPTY_SOCKET" then
            emptySocketText[v] = true
        end
    end
    return emptySocketText
end

-- Enchant id is the second field of the item string; 0/absent means unenchanted.
local function slotEnchantID(slot)
    local link = GetInventoryItemLink("player", slot)
    if not link then return nil end
    local itemString = link:match("|Hitem:([%-%d:]+)")
    if not itemString then return nil end
    local fields = {}
    for v in (itemString .. ":"):gmatch("([^:]*):") do fields[#fields + 1] = v end
    return tonumber(fields[2]) or 0
end

-- Empty sockets are only unambiguous in tooltip data, so read it per slot.
-- Returns count plus whether the tooltip was actually readable: item tooltips
-- aren't populated until the client has cached them (i.e. until you've hovered
-- the gear), and we must not report "no empty sockets" from missing data.
local function emptySocketsInSlot(slot)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return 0, false end
    local data = C_TooltipInfo.GetInventoryItem("player", slot)
    if not (data and data.lines and #data.lines > 0) then return 0, false end
    if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(data) end
    local set, n = socketTexts(), 0
    for _, line in ipairs(data.lines) do
        if TooltipUtil and TooltipUtil.SurfaceArgs then TooltipUtil.SurfaceArgs(line) end
        if line.leftText and set[line.leftText] then n = n + 1 end
    end
    return n, true
end

local function itemEquipLoc(link)
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not (get and link) then return nil end
    return select(9, get(link))
end

-- Tier ("class set") pieces come from these five slots. Set membership is the
-- item's setID (16th return of GetItemInfo); we count the largest matching set so
-- stray legacy-set items don't inflate the total.
local TIER_SLOTS = { 1, 3, 5, 7, 10 }   -- head, shoulder, chest, legs, hands

function RAA:GetTierCount()
    local get = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    if not get then return 0, false end
    local counts, best, complete = {}, 0, true
    for _, slot in ipairs(TIER_SLOTS) do
        local link = GetInventoryItemLink("player", slot)
        if link then
            if not get(link) then complete = false end   -- not cached yet
            local setID = select(16, get(link))
            if setID then
                counts[setID] = (counts[setID] or 0) + 1
                if counts[setID] > best then best = counts[setID] end
            end
        end
    end
    return best, complete
end

-- Returns: list of slots missing an enchant, list of slots with empty sockets,
-- and the total number of empty sockets.
function RAA:GetGearIssues()
    local missingEnchants, socketSlots, totalEmpty = {}, {}, 0
    local socketDataOk, enchantable = true, 0
    for slot = 1, 17 do
        if slot ~= 4 then                       -- skip shirt
            local link = GetInventoryItemLink("player", slot)
            if link then
                if ENCHANTABLE[slot] then
                    -- Off-hand held items (tomes, orbs) can't take an enchant.
                    local skip = (slot == 17) and (itemEquipLoc(link) == "INVTYPE_HOLDABLE")
                    if not skip then enchantable = enchantable + 1 end
                    if not skip and (slotEnchantID(slot) or 0) == 0 then
                        missingEnchants[#missingEnchants + 1] = SLOT_NAMES[slot] or ("Slot " .. slot)
                    end
                end
                local empty, readable = emptySocketsInSlot(slot)
                if not readable then
                    socketDataOk = false
                elseif empty > 0 then
                    totalEmpty = totalEmpty + empty
                    socketSlots[#socketSlots + 1] = SLOT_NAMES[slot] or ("Slot " .. slot)
                end
            end
        end
    end
    return missingEnchants, socketSlots, totalEmpty, socketDataOk, enchantable
end

--------------------------------------------------------------------------------
-- Character info (for the Character tab). Every lookup is guarded so a changed
-- API degrades to "?" rather than throwing.
--------------------------------------------------------------------------------
function RAA:GetCharacterInfo()
    local info = {}

    -- Item level: GetAverageItemLevel() -> overall(equippable), equipped
    if GetAverageItemLevel then
        local overall, equipped = GetAverageItemLevel()
        info.ilvlEquippedNum = equipped
        info.ilvlOverallNum  = overall
        info.ilvlEquipped = equipped and string.format("%.1f", equipped) or "?"
        info.ilvlOverall  = overall  and string.format("%.1f", overall)  or "?"
    else
        info.ilvlEquipped, info.ilvlOverall = "?", "?"
    end

    -- Specialization
    local specIndex = GetSpecialization and GetSpecialization()
    local specID, specName
    if specIndex and GetSpecializationInfo then
        specID, specName = GetSpecializationInfo(specIndex)
    end
    info.spec = specName or "None"

    -- Talent loadout (the saved config currently selected for this spec)
    local loadout
    if specID and C_ClassTalents and C_Traits and C_Traits.GetConfigInfo then
        local cfgID
        if C_ClassTalents.GetLastSelectedSavedConfigID then
            cfgID = C_ClassTalents.GetLastSelectedSavedConfigID(specID)
        end
        if not cfgID and C_ClassTalents.GetActiveConfigID then
            cfgID = C_ClassTalents.GetActiveConfigID()
        end
        if cfgID then
            local cfg = C_Traits.GetConfigInfo(cfgID)
            loadout = cfg and cfg.name
        end
    end
    -- A loadout manager (Talent Loadout Ex) applies builds without changing the
    -- Blizzard loadout, so prefer its name when we can identify the active one.
    local tleName = self:GetActiveTLELoadout()
    if tleName then
        info.loadout = tleName
        info.loadoutSource = "addon"
    else
        info.loadout = loadout or "Default"
        info.loadoutSource = "blizzard"
    end

    -- Equipment manager set currently equipped
    local setName
    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
        for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
            local name, _, _, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(id)
            if isEquipped then setName = name; break end
        end
    end
    info.set = setName or "None"

    -- Durability across equipped gear
    local cur, max = 0, 0
    if GetInventoryItemDurability then
        for slot = 1, 19 do
            local c, m = GetInventoryItemDurability(slot)
            if c and m and m > 0 then cur = cur + c; max = max + m end
        end
    end
    info.durFraction = (max > 0) and (cur / max) or nil
    info.durability = info.durFraction
                      and string.format("%d%%", math.floor(info.durFraction * 100 + 0.5)) or "n/a"

    -- Enchants / gems
    local missEnch, socketSlots, emptyCount, socketDataOk, enchTotal = self:GetGearIssues()
    -- raw values kept for the readiness score
    info.enchMissing, info.enchTotal = #missEnch, enchTotal
    info.emptySockets, info.socketDataOk = emptyCount, socketDataOk
    local function joinCapped(list, cap)
        if #list <= cap then return table.concat(list, ", ") end
        local head = {}
        for i = 1, cap do head[i] = list[i] end
        return table.concat(head, ", ") .. " +" .. (#list - cap) .. " more"
    end
    info.enchantsOk = (#missEnch == 0)
    info.enchants = info.enchantsOk and "All enchanted"
                    or (#missEnch .. " missing: " .. joinCapped(missEnch, 3))
    if not socketDataOk then
        -- Tooltips aren't cached yet; say so rather than falsely reporting "clean".
        info.gemsOk = nil
        info.gems = "Hover your gear to load, then Refresh"
    else
        info.gemsOk = (emptyCount == 0)
        info.gems = info.gemsOk and "No empty sockets"
                    or (emptyCount .. " empty: " .. joinCapped(socketSlots, 3))
    end

    -- Tier set pieces (only 2pc and 4pc actually grant bonuses)
    local tierPieces, tierComplete = self:GetTierCount()
    info.tierPieces, info.tierComplete = tierPieces, tierComplete
    if not tierComplete then
        info.tier = "Loading, then Refresh"
    else
        local bonus = (tierPieces >= 4 and "  (4pc active)")
                   or (tierPieces >= 2 and "  (2pc active)")
                   or "  (no bonus)"
        info.tier = tierPieces .. " / 5 pieces" .. bonus
    end

    -- A loadout-manager addon (e.g. Talent Loadout Ex) overrides the Blizzard
    -- loadout without changing it, so detect one if present.
    info.loadoutAddon = nil
    for lname, entry in pairs(self.installed or {}) do
        if lname:find("talentloadout", 1, true) or lname:find("loadoutmanager", 1, true) then
            info.loadoutAddon = entry.name
            break
        end
    end
    info.loadoutAddon = info.loadoutAddon or "none"
    -- If the manager is present but we couldn't identify which of its loadouts is
    -- running, say so rather than silently showing the (stale) Blizzard name.
    if info.loadoutAddon ~= "none" and info.loadoutSource ~= "addon" then
        info.loadoutAddon = info.loadoutAddon .. "  |cff888888(no match)|r"
    end

    -- Gold on this character
    if GetMoney then
        local money = GetMoney() or 0
        info.goldCopper = money
        -- C_CurrencyInfo first: the bare global is deprecated. The plain "%dg" tail
        -- stays as the last resort so a client with neither still shows a number.
        local coinText = (C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString)
                         or _G.GetCoinTextureString
        info.gold = coinText and coinText(money)
                    or string.format("%dg", math.floor(money / 10000))
    else
        info.gold = "?"
    end

    info.readiness, info.readinessParts = self:GetReadiness(info)
    return info
end

--------------------------------------------------------------------------------
-- Raid readiness score (out of 1000)
-- Weighted, and normalized over only the checks that actually apply: if you
-- haven't set a preferred loadout or required any consumables, those are skipped
-- rather than counted as failures.
--------------------------------------------------------------------------------
-- Item level is scored self-referentially (equipped vs your best available), so
-- there is no per-tier ceiling to maintain.
local GOLD_FLOOR  = 5000  * 10000  -- below 5000g scores nothing
local GOLD_FULL   = 25000 * 10000  -- 25000g is full credit
local MAX_SCORE   = 1000

-- True current item level of an equipped slot (accounts for upgrades/empowerment).
local function slotItemLevel(slot)
    if not (C_Item and C_Item.GetCurrentItemLevel and ItemLocation
            and ItemLocation.CreateFromEquipmentSlot) then return nil end
    local ok, loc = pcall(ItemLocation.CreateFromEquipmentSlot, ItemLocation, slot)
    if not (ok and loc) then return nil end
    if C_Item.DoesItemExist and not C_Item.DoesItemExist(loc) then return nil end
    local ok2, ilvl = pcall(C_Item.GetCurrentItemLevel, loc)
    return ok2 and ilvl or nil
end

function RAA:GetReadiness(info)
    local parts, earned, total = {}, 0, 0
    local function add(label, weight, score, note)
        if score == nil then                       -- unavailable: don't penalize
            parts[#parts + 1] = { label = label, note = note }
            return
        end
        score = math.max(0, math.min(1, score))
        earned, total = earned + weight * score, total + weight
        parts[#parts + 1] = { label = label, score = score, note = note }
    end

    -- Item level: gap between equipped and your best available (overall). Full
    -- credit within 2 ilvls (so wearing your best always reads 100%), scaling to
    -- zero by 15 below. Self-normalizing, no per-tier maximum.
    if info.ilvlEquippedNum and info.ilvlOverallNum and info.ilvlOverallNum > 0 then
        local gap = info.ilvlOverallNum - info.ilvlEquippedNum
        add("Item level", 175, 1 - (gap - 2) / 13,
            string.format("%.0f / %.0f best", info.ilvlEquippedNum, info.ilvlOverallNum))
    end

    -- Tier set: bonuses only exist at 2pc and 4pc, so score the actual benefit
    -- rather than a straight piece count.
    if info.tierComplete then
        local t = info.tierPieces or 0
        local s = (t >= 4) and 1 or ((t >= 2) and 0.5 or 0)
        add("Tier set", 125, s, t .. "/5"
            .. ((t >= 4) and " (4pc)" or (t >= 2) and " (2pc)" or " (no bonus)"))
    else
        add("Tier set", 125, nil, "loading")
    end

    -- Consumables score excludes Augment Runes and Healthstones: they're gold- or
    -- warlock-dependent, so the leader can still require them but they don't count
    -- against a personal readiness score.
    local SCORE_EXCLUDE = { ["Augment Runes"] = true, ["Healthstones"] = true }
    local have, scored = 0, 0
    for _, i in ipairs(self:RequiredCategoryIndices()) do
        local cat = self.CONSUMABLES and self.CONSUMABLES[i]
        if cat and not SCORE_EXCLUDE[cat.category] then
            scored = scored + 1
            if self:CategoryStatus(cat) then have = have + 1 end
        end
    end
    if scored > 0 then
        add("Consumables", 175, have / scored, have .. "/" .. scored .. " categories")
    end

    if (info.enchTotal or 0) > 0 then
        local miss = info.enchMissing or 0
        add("Enchants", 125, (info.enchTotal - miss) / info.enchTotal,
            (miss == 0) and "all enchanted" or (miss .. " missing"))
    end

    if info.socketDataOk then
        local e = info.emptySockets or 0
        add("Gems", 100, (e == 0) and 1 or (1 - e * 0.34),
            (e == 0) and "none empty" or (e .. " empty"))
    else
        add("Gems", 100, nil, "hover gear to load")
    end

    -- Empowerment: weapons and trinkets are the slots pushed to the ceiling via
    -- Voidcores. Scored against your OWN highest equipped item level, so it flags
    -- those slots lagging the rest of your gear without a per-tier constant.
    local maxEq = 0
    for slot = 1, 17 do
        if slot ~= 4 then
            local il = slotItemLevel(slot)
            if il and il > maxEq then maxEq = il end
        end
    end
    if maxEq > 0 then
        local TOL, atCap, counted = 4, 0, 0   -- within 4 ilvls of your best counts
        for _, slot in ipairs({ 16, 17, 13, 14 }) do
            if GetInventoryItemLink("player", slot) then
                local il = slotItemLevel(slot)
                if il then
                    counted = counted + 1
                    if il >= maxEq - TOL then atCap = atCap + 1 end
                end
            end
        end
        if counted > 0 then
            add("Empowerment", 100, atCap / counted,
                atCap .. "/" .. counted .. " at your ceiling")
        end
    end

    if info.durFraction then
        -- full credit at 90%+, nothing below 30%
        add("Durability", 75, (info.durFraction - 0.30) / 0.60,
            string.format("%d%%", math.floor(info.durFraction * 100 + 0.5)))
    end

    -- Scored against whatever group you're actually in. Solo has no expected
    -- setup (you may legitimately be on a questing build), so it isn't scored.
    local ctx = self:GroupContext()
    local pref = ctx and (self:GetPreferred(ctx) or {}) or nil
    if pref then
        if pref.set and pref.set ~= "" then
            local ok = (info.set == pref.set)
            add("Equipment set", 50, ok and 1 or 0, ok and "matches" or ("want " .. pref.set))
        end
        if pref.loadout and pref.loadout ~= "" then
            local ok = (info.loadout == pref.loadout)
            add("Talent loadout", 50, ok and 1 or 0, ok and "matches" or ("want " .. pref.loadout))
        end
    else
        add("Equipment set", 50, nil, "solo - not scored")
        add("Talent loadout", 50, nil, "solo - not scored")
    end

    -- Gold: nothing below 5000g, ramping to full at 25000g. Optional - it's more
    -- about repair convenience than raid readiness, so it can be toggled off.
    if info.goldCopper and RaidReadyDB and RaidReadyDB.scoreGold then
        local g = info.goldCopper
        local score = (g < GOLD_FLOOR) and 0 or ((g - GOLD_FLOOR) / (GOLD_FULL - GOLD_FLOOR))
        add("Gold", 25, score, math.floor(g / 10000) .. "g")
    end

    local score = (total > 0) and math.floor(earned / total * MAX_SCORE + 0.5) or nil
    return score, parts, MAX_SCORE
end

--------------------------------------------------------------------------------
-- Preferred setup per group context
--------------------------------------------------------------------------------
-- "raid" in a raid, "dungeon" in a party, nil solo.
function RAA:GroupContext()
    if IsInRaid() then return "raid" end
    if IsInGroup() then return "dungeon" end
    return nil
end

function RAA:GetPreferred(context)
    local p = RaidReadyDB and RaidReadyDB.preferred
    if not (p and context) then return nil end
    return p[context]
end

function RAA:SetPreferred(context, key, value)
    if not (RaidReadyDB and RaidReadyDB.preferred and context) then return end
    RaidReadyDB.preferred[context] = RaidReadyDB.preferred[context] or {}
    RaidReadyDB.preferred[context][key] = value   -- nil clears
end

-- Names of the character's equipment-manager sets.
function RAA:GetEquipmentSetNames()
    local out = {}
    if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
        for _, id in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
            local name = C_EquipmentSet.GetEquipmentSetInfo(id)
            if name then out[#out + 1] = name end
        end
    end
    table.sort(out)
    return out
end

--------------------------------------------------------------------------------
-- Talent Loadout(s) Ex support
-- Its SavedVariables global is TalentLoadoutEx (singular), shaped:
--   TalentLoadoutEx[CLASS_TOKEN][specIndex] = { {name=, text=, icon=}, ... }
-- Entries without `text` are group/folder headers. The addon stores no "active"
-- flag, so we identify the running loadout by matching the current build's
-- export string against each saved entry's `text`.
--------------------------------------------------------------------------------
function RAA:GetTLEList()
    local tle = _G.TalentLoadoutEx
    if type(tle) ~= "table" then return nil end
    local _, classToken = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    if not (classToken and specIndex) then return nil end
    local byClass = tle[classToken]
    local list = byClass and byClass[specIndex]
    if type(list) ~= "table" then return nil end
    return list
end

-- The export string for the build currently active on the character.
local function currentBuildString()
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID
            and C_Traits and C_Traits.GenerateImportString) then return nil end
    local cfg = C_ClassTalents.GetActiveConfigID()
    if not cfg then return nil end
    local ok, str = pcall(C_Traits.GenerateImportString, cfg)
    return ok and str or nil
end

-- Name of the TLE loadout matching the current build, or nil.
function RAA:GetActiveTLELoadout()
    local list = self:GetTLEList()
    if not list then return nil end
    local current = currentBuildString()
    if not current then return nil end
    for _, e in pairs(list) do
        if type(e) == "table" and e.text and e.text == current then return e.name end
    end
    return nil
end

-- Names of selectable talent loadouts: TLE's when installed, else Blizzard's.
function RAA:GetLoadoutNames()
    local out = {}
    local tleList = self:GetTLEList()
    if tleList then
        for _, e in pairs(tleList) do
            -- skip group/folder headers (no export text)
            if type(e) == "table" and e.name and e.text then out[#out + 1] = e.name end
        end
    else
        local specIndex = GetSpecialization and GetSpecialization()
        local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
        if specID and C_ClassTalents and C_ClassTalents.GetConfigIDsBySpecID
           and C_Traits and C_Traits.GetConfigInfo then
            for _, cfgID in ipairs(C_ClassTalents.GetConfigIDsBySpecID(specID) or {}) do
                local cfg = C_Traits.GetConfigInfo(cfgID)
                if cfg and cfg.name then out[#out + 1] = cfg.name end
            end
        end
    end
    table.sort(out)
    return out
end

--------------------------------------------------------------------------------
-- Leader gate
-- Only the raid leader or an assistant may run a check. When solo (not grouped)
-- we allow it so the tool is still testable by yourself.
--------------------------------------------------------------------------------
function RAA:CanLeadCheck()
    if not IsInGroup() then return true end
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- Keep the Check button's enabled state in sync with our current role.
function RAA:UpdateLeaderState()
    local can = self:CanLeadCheck()
    local f = self.frame
    if f and f.checkBtn and f.checkBtn.SetFlatEnabled then
        f.checkBtn:SetFlatEnabled(can)
    end
    local cf = self.consumeFrame
    if cf and cf.consumeCheckBtn and cf.consumeCheckBtn.SetFlatEnabled then
        cf.consumeCheckBtn:SetFlatEnabled(can)
    end
end

--------------------------------------------------------------------------------
-- nugsSuite
--------------------------------------------------------------------------------
-- One entry in a plain global table, which the nugsSuite launcher reads to list
-- this addon, open it and carry its settings between characters.
--
-- Written unconditionally and without checking whether nugsSuite exists: the table
-- is inert on its own, so this costs nothing when the suite is not installed, and
-- being a global rather than a call into it means neither addon has to load first.
--
-- This addon seeds its saved variables inline rather than from a defaults table,
-- so one is spelled out here purely for the suite to diff against. It has to stay
-- in step with the ADDON_LOADED block below; the only cost of drifting is that a
-- stale key exports when it did not need to.
local SUITE_DEFAULTS = {
    required           = {},
    requiredCategories = {},
    autoWhisper        = false,
    minimapHidden      = false,
    minimapAngle       = 200,
    uiScale            = 1,
    barShown           = true,
    barLocked          = false,
    barPos             = { point = "CENTER", x = 0, y = -220 },
    rcThreshold        = 700,
    rcPopup            = true,
    rcWhisper          = false,
    preferred          = { dungeon = {}, raid = {} },
}

local function RegisterWithSuite()
    _G.nugsSuiteRegistry = _G.nugsSuiteRegistry or {}
    _G.nugsSuiteRegistry[ADDON_NAME] = {
        title      = "nugsRaidReady",
        version    = RAA.version,
        icon       = "Interface\\AddOns\\nugsRaidReady\\icon",
        slash      = "/nrr",
        -- Matches what typing /nrr does, rather than always opening the leader view
        -- to a raider who cannot use it.
        Open       = function()
            if RAA:CanLeadCheck() then RAA:ToggleUI() else RAA:ToggleRaiderView() end
        end,
        SetMinimap = function(shown)
            RaidReadyDB.minimapHidden = not shown
            RAA:SetMinimapShown(shown)
        end,
        GetDB      = function() return RaidReadyDB, SUITE_DEFAULTS end,
        -- Gold tracking is a first-launch prompt, not a preference. Importing
        -- somebody else's answer would silently skip the question.
        exclude    = { introDone = true, scoreGold = true, minimapAngle = true },
    }
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------
local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("GROUP_ROSTER_UPDATE")
boot:RegisterEvent("PARTY_LEADER_CHANGED")
boot:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        RaidReadyDB = RaidReadyDB or {}
        RaidReadyDB.required = RaidReadyDB.required or {}
        RaidReadyDB.requiredCategories = RaidReadyDB.requiredCategories or {}
        if RaidReadyDB.autoWhisper == nil then RaidReadyDB.autoWhisper = false end
        if RaidReadyDB.minimapHidden == nil then RaidReadyDB.minimapHidden = false end
        RaidReadyDB.minimapAngle = RaidReadyDB.minimapAngle or 200
        RaidReadyDB.uiScale = RaidReadyDB.uiScale or 1
        -- standalone readiness bar
        if RaidReadyDB.barShown == nil then RaidReadyDB.barShown = true end
        if RaidReadyDB.barLocked == nil then RaidReadyDB.barLocked = false end
        RaidReadyDB.barPos = RaidReadyDB.barPos or { point = "CENTER", x = 0, y = -220 }
        -- ready-check warnings
        RaidReadyDB.rcThreshold = RaidReadyDB.rcThreshold or 700
        if RaidReadyDB.rcPopup == nil then RaidReadyDB.rcPopup = true end
        if RaidReadyDB.rcWhisper == nil then RaidReadyDB.rcWhisper = false end
        -- Gold tracking is opt-in via a first-launch prompt; leaving it nil means
        -- "not yet asked" (and, until answered, not counted). Anyone who already
        -- has a value chose before, so don't re-prompt them.
        if RaidReadyDB.scoreGold ~= nil then RaidReadyDB.introDone = true end
        RaidReadyDB.preferred = RaidReadyDB.preferred or {}
        RaidReadyDB.preferred.dungeon = RaidReadyDB.preferred.dungeon or {}
        RaidReadyDB.preferred.raid    = RaidReadyDB.preferred.raid    or {}
        RegisterWithSuite()
    elseif event == "PLAYER_LOGIN" then
        RAA:BuildInstalledMap()
        if RAA.InitComm then RAA:InitComm() end
        if RAA.InitConsumableComm then RAA:InitConsumableComm() end
        if RAA.InitMinimap then RAA:InitMinimap() end
        if RAA.SetScoreBarShown then RAA:SetScoreBarShown(RaidReadyDB.barShown) end
        if RAA.InitReadinessEvents then RAA:InitReadinessEvents() end
        if not RaidReadyDB.introDone and RAA.ShowGoldOptIn then
            C_Timer.After(1, function() RAA:ShowGoldOptIn() end)
        end
        RAA:UpdateLeaderState()
        print("|cff33ff99RaidReady|r v" .. RAA.version ..
              " loaded. Type |cffffff00/nrr|r to open.")
    else
        -- roster/leadership changed
        RAA:UpdateLeaderState()
    end
end)

-- Slash command
SLASH_RAIDREADY1 = "/nrr"
SLASH_RAIDREADY2 = "/raidready"
SlashCmdList["RAIDREADY"] = function(msg)
    msg = (msg or ""):lower():gsub("%s+", "")
    if msg == "check" then
        if RAA.StartCheck then RAA:StartCheck() end
    elseif msg == "ids" then
        if RAA.ToggleItemIDs then RAA:ToggleItemIDs() end
    elseif msg == "loadoutscan" or msg == "tle" then
        if RAA.ScanLoadoutAddon then RAA:ScanLoadoutAddon() end
    elseif msg == "settings" or msg == "config" or msg == "options" then
        if RAA.ToggleSettings then RAA:ToggleSettings() end
    elseif RAA:CanLeadCheck() then
        -- Raid leader / assistant (or solo): full management window.
        if RAA.ToggleUI then RAA:ToggleUI() end
    else
        -- Regular raider: only their own status box.
        if RAA.ToggleRaiderView then RAA:ToggleRaiderView() end
    end
end
