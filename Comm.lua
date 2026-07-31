--------------------------------------------------------------------------------
-- RaidReady
-- Copyright (c) 2026 nugs. All Rights Reserved.
-- Unauthorized copying, distribution, or modification is prohibited. See LICENSE.
--------------------------------------------------------------------------------
-- RaidReady  -  Comm.lua
-- Addon-to-addon messaging. No filesystem, no server: the leader broadcasts the
-- REQUIRED addon names over the RAID channel, and every client that runs this
-- addon replies (via whisper to the leader) with its version for only those
-- addons. Keeping the payload to just the required list keeps every message
-- comfortably under Blizzard's ~255-byte addon-message limit.
local ADDON_NAME, RAA = ...

-- Retail moved this into C_ChatInfo; the bare global still answers but is flagged
-- as deprecated and is what disappears in a later patch. Same shape as the C_AddOns
-- aliases at the top of Core.lua.
local SendChatMessage = (C_ChatInfo and C_ChatInfo.SendChatMessage) or _G.SendChatMessage

local PREFIX      = "RR1"        -- registered comm prefix (max 16 chars)
local MSG_REQUEST = "CHK"         -- leader -> raid: "CHK|Name1;Name2;..."
local MSG_REPORT  = "RPT"         -- member -> leader: "RPT|Name1=ver;Name2=;..."
local MSG_SCORE   = "SCR"         -- member -> group: readiness score on a ready check
local MSG_RREQ    = "RRQ"         -- leader -> group: readiness-check request
local MSG_RSCORE  = "RSC"         -- member -> leader: readiness score reply
local FIELD_SEP   = "\029"        -- ASCII GS, unlikely to appear in a version string
local LIST_SEP    = ";"
local KV_SEP      = "="
local RESPONSE_WINDOW = 6         -- seconds the leader waits for replies

--------------------------------------------------------------------------------
-- Serialization helpers
--------------------------------------------------------------------------------

-- Encode { "DBM-Core", "WeakAuras" } -> "DBM-Core;WeakAuras"
local function encodeNames(names)
    return table.concat(names, LIST_SEP)
end

local function decodeNames(str)
    local names = {}
    for name in tostring(str):gmatch("[^" .. LIST_SEP .. "]+") do
        names[#names + 1] = name
    end
    return names
end

-- Encode { ["DBM-Core"] = "11.2.3", ["WeakAuras"] = "" } into
-- "DBM-Core=11.2.3;WeakAuras="
local function encodeReport(map)
    local parts = {}
    for name, ver in pairs(map) do
        parts[#parts + 1] = name .. KV_SEP .. (ver or "")
    end
    return table.concat(parts, LIST_SEP)
end

local function decodeReport(str)
    local map = {}
    for pair in tostring(str):gmatch("[^" .. LIST_SEP .. "]+") do
        local name, ver = pair:match("^(.-)" .. KV_SEP .. "(.*)$")
        if name then map[name] = ver end
    end
    return map
end

--------------------------------------------------------------------------------
-- Sending
--------------------------------------------------------------------------------

local function channel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- Build this client's own report for the given required names.
function RAA:BuildOwnReport(requiredNames)
    self:BuildInstalledMap()
    local report = {}
    for _, folder in ipairs(requiredNames) do
        local ver = self:InstalledVersionOf(folder)
        -- nil  -> not installed: we simply omit it, so the leader marks "missing"
        -- ""   -> installed, no version metadata: send name= (empty)
        if ver ~= nil then
            report[folder] = ver
        end
    end
    return report
end

-- LEADER: broadcast a check request to the group. We send the required addon
-- names AND their minimum versions, so each raider can evaluate and show itself.
function RAA:SendRequest(requiredNames)
    local chan = channel()
    local req = self:GetRequirements()
    local reqMap = {}
    for _, name in ipairs(requiredNames) do reqMap[name] = req[name] or "" end
    local payload = MSG_REQUEST .. FIELD_SEP .. encodeReport(reqMap)
    if chan then
        C_ChatInfo.SendAddonMessage(PREFIX, payload, chan)
    end
    -- Always evaluate ourselves locally (we may be the only one, or solo testing).
    local ownReport = self:BuildOwnReport(requiredNames)
    self:OnReport(GetUnitName("player", true) or UnitName("player"), ownReport)
end

-- MEMBER: reply to the leader with our report, staggered by a small random
-- delay so 20-30 simultaneous replies don't trip the throttle.
function RAA:SendReport(leaderFullName, requiredNames)
    local report = self:BuildOwnReport(requiredNames)
    local payload = MSG_REPORT .. FIELD_SEP .. encodeReport(report)
    local delay = math.random() * 2.0
    C_Timer.After(delay, function()
        -- Whisper directly to the requester to avoid spamming the whole raid.
        C_ChatInfo.SendAddonMessage(PREFIX, payload, "WHISPER", leaderFullName)
    end)
end

--------------------------------------------------------------------------------
-- Receiving
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Ready check integration
-- On a ready check each client scores itself: it warns the player if they're
-- below their threshold, and reports the score so the leader can whisper anyone
-- who isn't ready.
--------------------------------------------------------------------------------
function RAA:OnReadyCheck()
    self._rcWhispered = {}                     -- fresh per ready check

    local info = self:GetCharacterInfo()
    local score = info.readiness
    if not score then return end
    local threshold = (RaidReadyDB and RaidReadyDB.rcThreshold) or 700

    if RaidReadyDB and RaidReadyDB.rcPopup and score < threshold and self.ShowReadyCheckWarning then
        self:ShowReadyCheckWarning(score, threshold, info.readinessParts)
    end

    local chan = channel()
    if chan then
        C_ChatInfo.SendAddonMessage(PREFIX, MSG_SCORE .. FIELD_SEP .. score, chan)
    end
end

-- Leader side: whisper anyone who reported below the threshold.
function RAA:OnScoreReport(sender, score)
    if not score then return end
    if not (RaidReadyDB and RaidReadyDB.rcWhisper) then return end
    if not self:CanLeadCheck() then return end
    local threshold = RaidReadyDB.rcThreshold or 700
    if score >= threshold then return end

    local key = RAA.NameKey(sender)
    local me = RAA.NameKey(GetUnitName("player", true) or UnitName("player"))
    if not key or key == me then return end

    self._rcWhispered = self._rcWhispered or {}
    if self._rcWhispered[key] then return end   -- once per ready check
    self._rcWhispered[key] = true

    local target = Ambiguate(sender, "none")
    local msg = "RaidReady: your score is " .. score .. " (below " .. threshold
                .. "). Type /rr to see what's missing."
    C_Timer.After(math.random() * 1.5, function()
        SendChatMessage(msg, "WHISPER", nil, target)
    end)
end

--------------------------------------------------------------------------------
-- Leader-initiated readiness check: broadcast a request, collect each member's
-- readiness score (just the number), and show a roster.
--------------------------------------------------------------------------------
function RAA:StartReadinessCheck()
    if not self:CanLeadCheck() then
        print("|cff33ff99RaidReady|r: only the raid leader or an assistant can run a check.")
        return
    end
    local session = { results = {} }
    for _, m in ipairs(self:GetRosterMembers()) do
        session.results[m.key] = { display = m.display, class = m.class, online = m.online }
    end
    self.readinessSession = session
    if self.ShowReadinessRoster then self:ShowReadinessRoster() end

    local chan = channel()
    if chan then C_ChatInfo.SendAddonMessage(PREFIX, MSG_RREQ .. FIELD_SEP .. "1", chan) end
    local info = self:GetCharacterInfo()
    self:OnReadinessReply(GetUnitName("player", true) or UnitName("player"), info.readiness)

    self._rdyToken = (self._rdyToken or 0) + 1
    local token = self._rdyToken
    C_Timer.After(RESPONSE_WINDOW, function()
        if self._rdyToken ~= token then return end
        for _, r in pairs(session.results) do
            if r.score == nil then r.status = r.online and "noaddon" or "offline" end
        end
        if self.RefreshReadinessRoster then self:RefreshReadinessRoster() end
    end)
end

function RAA:OnReadinessReply(sender, score)
    local session = self.readinessSession
    if not session then return end
    local key = RAA.NameKey(sender)
    if not key then return end
    local entry = session.results[key]
    if not entry then
        entry = { display = Ambiguate(sender, "none") }
        session.results[key] = entry
    end
    entry.score = score
    if self.RefreshReadinessRoster then self:RefreshReadinessRoster() end
end

function RAA:InitComm()
    if self._commReady then return end
    self._commReady = true
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

    local rc = CreateFrame("Frame")
    rc:RegisterEvent("READY_CHECK")
    rc:SetScript("OnEvent", function() RAA:OnReadyCheck() end)

    local f = CreateFrame("Frame")
    f:RegisterEvent("CHAT_MSG_ADDON")
    f:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
        if prefix ~= PREFIX then return end
        local kind, body = text:match("^(%u+)" .. FIELD_SEP .. "(.*)$")
        if not kind then return end

        if kind == MSG_REQUEST then
            -- A raid leader asked for our addon versions. Body is name=minVer pairs.
            local reqMap = decodeReport(body)
            local names = {}
            for name in pairs(reqMap) do names[#names + 1] = name end
            RAA:SendReport(sender, names)

            -- Show the raider their own status locally (skip our own echo).
            local me = RAA.NameKey(GetUnitName("player", true) or UnitName("player"))
            if RAA.NameKey(sender) ~= me then
                -- Remember it so the raider can reopen their box with /rr.
                RAA.lastReqMap = reqMap
                RAA.lastRequester = sender
                if RAA.ShowRaiderView then RAA:ShowRaiderView(reqMap, sender) end
            end

        elseif kind == MSG_REPORT then
            -- A member answered our check.
            RAA:OnReport(sender, decodeReport(body))

        elseif kind == MSG_SCORE then
            RAA:OnScoreReport(sender, tonumber(body))

        elseif kind == MSG_RREQ then
            -- Leader asked for our readiness score; reply privately.
            local info = RAA:GetCharacterInfo()
            if info.readiness then
                C_Timer.After(math.random() * 1.5, function()
                    C_ChatInfo.SendAddonMessage(PREFIX, MSG_RSCORE .. FIELD_SEP .. info.readiness,
                        "WHISPER", sender)
                end)
            end

        elseif kind == MSG_RSCORE then
            RAA:OnReadinessReply(sender, tonumber(body))
        end
    end)
end

--------------------------------------------------------------------------------
-- Leader-side check session
--------------------------------------------------------------------------------

-- Kick off a raid-wide check. Populates RAA.session and refreshes the UI as
-- replies arrive, then finalizes non-responders after RESPONSE_WINDOW seconds.
function RAA:StartCheck()
    if not self:CanLeadCheck() then
        print("|cff33ff99RaidReady|r: only the raid leader or an assistant can run a check.")
        return
    end

    local required = self:RequiredNames()
    if #required == 0 then
        print("|cff33ff99RaidReady|r: no required addons set. Open |cffffff00/rr|r and add some first.")
        if self.ShowUI then self:ShowUI() end
        return
    end

    local roster = self:GetRosterMembers()
    local session = {
        required   = required,
        results    = {},   -- [namekey] = { display, responded, worst, details }
        startedAt  = GetTime(),
    }
    for _, m in ipairs(roster) do
        session.results[m.key] = {
            display   = m.display,
            online    = m.online,
            class     = m.class,
            responded = false,
            worst     = "pending",
            details   = {},
        }
    end
    self.session = session

    if self.ShowUI then self:ShowUI() end
    if self.RefreshResults then self:RefreshResults() end

    self:SendRequest(required)

    -- Close the window: anyone who hasn't answered is a non-responder.
    self._checkToken = (self._checkToken or 0) + 1
    local token = self._checkToken
    C_Timer.After(RESPONSE_WINDOW, function()
        if self._checkToken ~= token then return end   -- superseded by a newer check
        for _, r in pairs(session.results) do
            if not r.responded then
                -- Online but silent => they almost certainly don't have the addon.
                r.worst = r.online and "noaddon" or "offline"
            end
        end
        if self.RefreshResults then self:RefreshResults() end
        if RaidReadyDB and RaidReadyDB.autoWhisper then
            self:WhisperOffenders(session)
        end
    end)
end

-- Whisper each responded, non-compliant player a specific fix list. Staggered so
-- a raid full of offenders doesn't trip the whisper spam filter. Non-responders
-- are skipped (we don't know what they're missing), and we never whisper ourself.
function RAA:WhisperOffenders(session)
    local myKey = RAA.NameKey(GetUnitName("player", true) or UnitName("player"))
    local outdatedMsg = "You have out of date addons, type /rr to view"
    local installMsg  = "Please install the RaidReady addon so the raid leader can check your required addons."
    local i = 0
    for key, entry in pairs(session.results) do
        if key ~= myKey then
            local msg
            if entry.worst == "outdated" or entry.worst == "missing" then
                msg = outdatedMsg
            elseif entry.worst == "noaddon" then
                msg = installMsg   -- online, never replied => missing the addon itself
            end
            -- "offline" players are intentionally skipped (avoids whisper errors).
            if msg then
                local target, m = entry.display, msg
                i = i + 1
                C_Timer.After(i * 0.6, function()
                    SendChatMessage(m, "WHISPER", nil, target)
                end)
            end
        end
    end
    if i > 0 then
        print("|cff33ff99RaidReady|r: whispered " .. i .. " player(s).")
    end
end

-- Record a report from `sender` and re-evaluate their compliance.
function RAA:OnReport(sender, reportMap)
    local session = self.session
    if not session then return end
    local key = RAA.NameKey(sender)
    if not key then return end

    local entry = session.results[key]
    if not entry then
        -- Someone reported who isn't in our roster snapshot (e.g. just joined).
        entry = { display = Ambiguate(sender, "none"), details = {} }
        session.results[key] = entry
    end

    local worst, details = self:EvaluateReport(reportMap)
    entry.responded = true
    entry.worst     = worst
    entry.details   = details

    if self.RefreshResults then self:RefreshResults() end
end
