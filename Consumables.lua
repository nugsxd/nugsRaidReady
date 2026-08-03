--------------------------------------------------------------------------------
-- RaidReady
-- Copyright (c) 2026 nugs. All Rights Reserved.
-- Unauthorized copying, distribution, or modification is prohibited. See LICENSE.
--------------------------------------------------------------------------------
-- RaidReady  -  Consumables.lua
-- Curated consumable categories + counting logic + comm. The leader requires
-- whole CATEGORIES (e.g. "Flasks"). A raider passes a category if they carry at
-- least one item (any rank) from it. The player view lists the items in each
-- category with counts, so raiders can see what qualifies. Display shows the
-- count of the highest rank held (5* else 4*).
local ADDON_NAME, RAA = ...

--------------------------------------------------------------------------------
-- Preset data. `high` = 5-star / preferred rank item ID, `low` = 4-star id
-- (optional). IDs are patch 12.0; verify with /nrr ids.
--------------------------------------------------------------------------------
RAA.CONSUMABLES = {
    { category = "Flasks", items = {
        { name = "Flask of Thalassian Resistance", high = 241320, low = 241321 },
        { name = "Flask of the Blood Knights",     high = 241324, low = 241325 },
        { name = "Flask of the Magisters",         high = 241322, low = 241323 },
        { name = "Flask of the Shattered Sun",      high = 241326, low = 241327 },
    }},
    { category = "Combat Potions", items = {
        { name = "Light's Potential",         high = 241308, low = 241309 },
        { name = "Potion of Recklessness",    high = 241288, low = 241289 },
        { name = "Potion of Zealotry",        high = 241296, low = 241297 },
        { name = "Draught of Rampant Abandon", high = 241292, low = 241293 },
    }},
    { category = "Healing Potions", items = {
        { name = "Silvermoon Health Potion", high = 241304, low = 241305 },
        { name = "Amani Extract",            high = 241298, low = 241299 },
        { name = "Light's Preservation",     high = 241286, low = 241287 },
    }},
    { category = "Weapon Enhancement", items = {
        { name = "Thalassian Phoenix Oil",     high = 243734, low = 243733 },
        { name = "Smuggler's Enchanted Edge",  high = 243738, low = 243737 },
        { name = "Oil of Dawn",                high = 243736, low = 243735 },
        { name = "Refulgent Weightstone",      high = 237369, low = 237367 },
        { name = "Refulgent Whetstone",        high = 237371, low = 237370 },
    }},
    { category = "Augment Runes", items = {
        { name = "Void-Touched Augment Rune", high = 259085 },
    }},
    { category = "Healthstones", items = {
        { name = "Healthstone", high = 5512 },  -- verify with /nrr ids
    }},
}

--------------------------------------------------------------------------------
-- Requirements (SavedVariables) — a set of required category names.
--------------------------------------------------------------------------------
function RAA:GetRequiredCategories()
    return RaidReadyDB and RaidReadyDB.requiredCategories or {}
end

function RAA:IsCategoryRequired(name)
    return self:GetRequiredCategories()[name] and true or false
end

function RAA:SetCategoryRequired(name, required)
    if not RaidReadyDB then return end
    RaidReadyDB.requiredCategories[name] = required and true or nil
end

-- Ordered list of required category indices (stable for comms/UI).
function RAA:RequiredCategoryIndices()
    local out = {}
    for i, cat in ipairs(self.CONSUMABLES) do
        if self:IsCategoryRequired(cat.category) then out[#out + 1] = i end
    end
    return out
end

--------------------------------------------------------------------------------
-- Counting / display
--------------------------------------------------------------------------------
local function itemCount(id)
    if not id then return 0 end
    if C_Item and C_Item.GetItemCount then return C_Item.GetItemCount(id) or 0 end
    return (GetItemCount and GetItemCount(id)) or 0
end

function RAA:CountConsumable(entry)
    return itemCount(entry.high), (entry.low and itemCount(entry.low) or 0)
end

-- Rank markup: WoW's crafting-quality star atlas, with a "5*"/"4*" text fallback
-- if the atlas isn't available, so it never renders as a box.
local starCache = {}
local function star(tier)
    if starCache[tier] ~= nil then return starCache[tier] end
    local atlas = "Professions-ChatIcon-Quality-Tier" .. tier
    local v
    if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) and CreateAtlasMarkup then
        v = CreateAtlasMarkup(atlas, 16, 16)
    else
        v = tier .. "*"
    end
    starCache[tier] = v
    return v
end

-- Display string for an item's counts: "<5*> xN" / "<4*> xN".
function RAA:ConsumableCountText(hc, lc)
    if hc and hc > 0 then return star(5) .. " x" .. hc end
    if lc and lc > 0 then return star(4) .. " x" .. lc end
    return nil
end

-- Category status: hasAny (bool) + per-item {item, hc, lc}.
function RAA:CategoryStatus(catEntry)
    local hasAny = false
    local items = {}
    for _, item in ipairs(catEntry.items) do
        local hc, lc = self:CountConsumable(item)
        if (hc + lc) > 0 then hasAny = true end
        items[#items + 1] = { item = item, hc = hc, lc = lc }
    end
    return hasAny, items
end

--------------------------------------------------------------------------------
-- Comm  (shares RR1 prefix; kinds CCK / CRP carry category indices)
--------------------------------------------------------------------------------
local PREFIX     = "RR1"
local FIELD_SEP  = "\029"
local MSG_CREQ   = "CCK"   -- leader -> group: required category indices
local MSG_CREP   = "CRP"   -- member -> leader: per-category presence (0/1)
local RESPONSE_WINDOW = 6

local function channel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- This client's per-category presence for the given category indices.
function RAA:BuildOwnCategoryReport(indices)
    local report = {}
    for _, idx in ipairs(indices) do
        local cat = self.CONSUMABLES[idx]
        if cat then
            local hasAny = self:CategoryStatus(cat)
            report[idx] = hasAny and 1 or 0
        end
    end
    return report
end

local function encodeCReport(report)
    local parts = {}
    for idx, v in pairs(report) do parts[#parts + 1] = idx .. "=" .. v end
    return table.concat(parts, ";")
end

local function decodeCReport(str)
    local map = {}
    for pair in tostring(str):gmatch("[^;]+") do
        local i, v = pair:match("^(%d+)=(%d+)$")
        if i then map[tonumber(i)] = tonumber(v) end
    end
    return map
end

-- Evaluate a presence report against required indices -> worst, details.
-- details[idx] = "ok" | "missing"
function RAA:EvaluateCategoryReport(indices, report)
    local worst = "ok"
    local details = {}
    for _, idx in ipairs(indices) do
        local present = (report[idx] == 1)
        details[idx] = present and "ok" or "missing"
        if not present then worst = "missing" end
    end
    return worst, details
end

-- LEADER: broadcast required categories and open a check session.
function RAA:StartConsumableCheck()
    if not self:CanLeadCheck() then
        print("|cff33ff99RaidReady|r: only the raid leader or an assistant can run a check.")
        return
    end
    local indices = self:RequiredCategoryIndices()
    if #indices == 0 then
        print("|cff33ff99RaidReady|r: no required consumable categories selected yet.")
        if self.ShowConsumeUI then self:ShowConsumeUI() end
        return
    end

    local roster = self:GetRosterMembers()
    local session = { keys = indices, results = {} }
    for _, m in ipairs(roster) do
        session.results[m.key] = { display = m.display, online = m.online, class = m.class,
                                   responded = false, worst = "pending", details = {} }
    end
    self.consumeSession = session

    if self.ShowConsumeUI then self:ShowConsumeUI() end
    if self.RefreshConsumeResults then self:RefreshConsumeResults() end

    local payload = MSG_CREQ .. FIELD_SEP .. table.concat(indices, ";")
    local chan = channel()
    if chan then C_ChatInfo.SendAddonMessage(PREFIX, payload, chan) end
    self:OnConsumableReport(GetUnitName("player", true) or UnitName("player"),
                            self:BuildOwnCategoryReport(indices))

    self._consumeToken = (self._consumeToken or 0) + 1
    local token = self._consumeToken
    C_Timer.After(RESPONSE_WINDOW, function()
        if self._consumeToken ~= token then return end
        for _, r in pairs(session.results) do
            if not r.responded then r.worst = r.online and "noaddon" or "offline" end
        end
        if self.RefreshConsumeResults then self:RefreshConsumeResults() end
    end)
end

function RAA:OnConsumableReport(sender, report)
    local session = self.consumeSession
    if not session then return end
    local key = RAA.NameKey(sender)
    if not key then return end
    local entry = session.results[key]
    if not entry then
        entry = { display = Ambiguate(sender, "none"), details = {} }
        session.results[key] = entry
    end
    local worst, details = self:EvaluateCategoryReport(session.keys, report)
    entry.responded = true
    entry.worst = worst
    entry.details = details
    if self.RefreshConsumeResults then self:RefreshConsumeResults() end
end

function RAA:RespondConsumables(leaderFullName, indices)
    local payload = MSG_CREP .. FIELD_SEP .. encodeCReport(self:BuildOwnCategoryReport(indices))
    C_Timer.After(math.random() * 2.0, function()
        C_ChatInfo.SendAddonMessage(PREFIX, payload, "WHISPER", leaderFullName)
    end)
end

function RAA:InitConsumableComm()
    if self._consumeCommReady then return end
    self._consumeCommReady = true
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
        if prefix ~= PREFIX then return end
        local kind, body = text:match("^(%u+)" .. FIELD_SEP .. "(.*)$")
        if kind == MSG_CREQ then
            local indices = {}
            for id in tostring(body):gmatch("%d+") do indices[#indices + 1] = tonumber(id) end
            RAA:RespondConsumables(sender, indices)
            local me = RAA.NameKey(GetUnitName("player", true) or UnitName("player"))
            if RAA.NameKey(sender) ~= me then
                RAA.lastConsumeKeys = indices
                RAA.lastConsumeRequester = sender
                if RAA.ShowConsumePreview then RAA:ShowConsumePreview(indices, sender) end
            end
        elseif kind == MSG_CREP then
            RAA:OnConsumableReport(sender, decodeCReport(body))
        end
    end)
end
