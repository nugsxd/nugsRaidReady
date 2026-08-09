--------------------------------------------------------------------------------
-- RaidReady
-- Copyright (c) 2026 nugs. All Rights Reserved.
-- Unauthorized copying, distribution, or modification is prohibited. See LICENSE.
--------------------------------------------------------------------------------
-- RaidReady  -  UI.lua
-- Flat, ElvUI-style dark skin. One movable window: required-addon editor on top
-- (with a "Browse installed" picker) and the compliance roster below.
local ADDON_NAME, RAA = ...

--------------------------------------------------------------------------------
-- Theme
--------------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8X8"
local C = {
    bg     = { 0.07, 0.07, 0.07, 0.96 },
    header = { 0.10, 0.10, 0.10, 1.00 },
    panel  = { 0.10, 0.10, 0.10, 0.90 },
    input  = { 0.14, 0.14, 0.14, 1.00 },
    border = { 0.00, 0.00, 0.00, 1.00 },
    btn    = { 0.16, 0.16, 0.16, 1.00 },
    btnHi  = { 0.24, 0.24, 0.24, 1.00 },
    accent = { 0.35, 0.72, 1.00, 1.00 },   -- storm / lightning blue
    rowA   = { 1, 1, 1, 0.025 },
    rowB   = { 1, 1, 1, 0.055 },
    text   = { 0.82, 0.82, 0.82 },
    faint  = { 0.50, 0.50, 0.50 },
    gold   = { 1.00, 0.84, 0.42 },         -- Valarjar gold
    guild  = { 0.55, 0.82, 1.00 },         -- accent for byline text
}

-- Matches the nugs family header: gold addon name, storm-blue version tail.
local TITLE_TEXT = "nugsRaidReady |cff8cd2ffv" .. (RAA.version or "?") .. "|r"

local STATUS = {
    ok         = { text = "OK",              color = {0.35, 0.90, 0.45} },
    outdated   = { text = "Outdated",        color = {1.00, 0.70, 0.20} },
    missing    = { text = "Missing",         color = {1.00, 0.35, 0.35} },
    noversion  = { text = "No version info", color = {0.55, 0.75, 1.00} },
    noaddon    = { text = "No addon",        color = {0.95, 0.45, 0.95} },
    offline    = { text = "Offline",         color = {0.45, 0.45, 0.45} },
    pending    = { text = "Waiting...",      color = {0.80, 0.80, 0.80} },
}

--------------------------------------------------------------------------------
-- Flat-styling helpers
--------------------------------------------------------------------------------
-- SetPropagateKeyboardInput is protected during combat, and a blocked call is not a
-- Lua error: pcall does not contain it, it raises ADDON_ACTION_BLOCKED and taints the
-- addon for the rest of the session. So it is never called inside a lockdown, and the
-- next key pressed after combat ends restores propagation on its own.
local function SafePropagate(frame, value)
    if InCombatLockdown() then return end
    frame:SetPropagateKeyboardInput(value)
end

local function Skin(frame, bg, border)
    frame:SetBackdrop({
        bgFile = WHITE, edgeFile = WHITE, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(unpack(bg or C.panel))
    frame:SetBackdropBorderColor(unpack(border or C.border))
end

local function CreateFlatFrame(parent, bg)
    local fr = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin(fr, bg or C.panel)
    return fr
end

local function CreateFlatButton(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, h)
    Skin(b, C.btn)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.text:SetPoint("CENTER")
    b.text:SetText(text)
    b.text:SetTextColor(unpack(C.text))
    b:SetScript("OnEnter", function(s)
        s:SetBackdropColor(unpack(C.btnHi))
        s:SetBackdropBorderColor(unpack(C.accent))
        s.text:SetTextColor(1, 1, 1)
    end)
    b:SetScript("OnLeave", function(s)
        s:SetBackdropColor(unpack(C.btn))
        s:SetBackdropBorderColor(unpack(C.border))
        s.text:SetTextColor(unpack(C.text))
    end)
    -- Enable/disable with a greyed look. Disabling mouse also suppresses the
    -- hover recolor, so a disabled button stays visibly inert.
    function b:SetFlatEnabled(enabled)
        if enabled then
            self:EnableMouse(true)
            self:SetBackdropColor(unpack(C.btn))
            self:SetBackdropBorderColor(unpack(C.border))
            self.text:SetTextColor(unpack(C.text))
        else
            self:EnableMouse(false)
            self:SetBackdropColor(0.10, 0.10, 0.10, 1)
            self:SetBackdropBorderColor(unpack(C.border))
            self.text:SetTextColor(0.40, 0.40, 0.40)
        end
    end
    return b
end

-- Flat checkbox with a label.
local function CreateFlatCheck(parent, label)
    local cb = CreateFrame("Button", nil, parent, "BackdropTemplate")
    cb:SetSize(16, 16)
    Skin(cb, C.input)
    cb.check = cb:CreateTexture(nil, "OVERLAY")
    cb.check:SetPoint("CENTER")
    cb.check:SetSize(9, 9)
    cb.check:SetTexture(WHITE)
    cb.check:SetVertexColor(unpack(C.accent))
    cb.check:Hide()
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    cb.label:SetText(label)
    cb.label:SetTextColor(unpack(C.text))
    function cb:SetChecked(v)
        self.checked = v and true or false
        if self.checked then self.check:Show() else self.check:Hide() end
    end
    cb:SetScript("OnClick", function(s)
        s:SetChecked(not s.checked)
        if s.onToggle then s.onToggle(s.checked) end
    end)
    cb:SetScript("OnEnter", function(s) s:SetBackdropBorderColor(unpack(C.accent)) end)
    cb:SetScript("OnLeave", function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
    return cb
end

local function CreateFlatEditBox(parent, w, h)
    local eb = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    eb:SetSize(w, h)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextInsets(6, 6, 0, 0)
    Skin(eb, C.input)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    eb:SetScript("OnEditFocusGained", function(s) s:SetBackdropBorderColor(unpack(C.accent)) end)
    eb:SetScript("OnEditFocusLost",   function(s) s:SetBackdropBorderColor(unpack(C.border)) end)
    return eb
end

-- Static accent bar under a window header. (Was an animated lightning effect;
-- made static to keep the addon lightweight - no per-frame OnUpdate.)
local function addAccentBar(header)
    local bar = header:CreateTexture(nil, "OVERLAY")
    bar:SetTexture(WHITE)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetHeight(3)
    bar:SetVertexColor(unpack(C.accent))
    return bar
end

-- Scroll list with a thin custom bar rather than Blizzard's.
--
-- It used to draw no bar at all, on the grounds that it looked cleaner. It did, and
-- it also left the wheel as the only way through a raid-sized list. The bar is a
-- frame, not a texture: a texture cannot take mouse input, so a drawn-on indicator
-- would have been decoration.
--
-- BAR_W is the grab area and is wider than the 3px line you can see, because a 3px
-- target is not something anybody can reliably hit. The whole bar hides when
-- everything fits, so it never eats a click on a row underneath it.
local function CreateScrollList(parent, w, h)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    scroll:SetSize(w, h)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(w, h)
    scroll:SetScrollChild(content)
    scroll.content = content

    local BAR_W = 9

    local bar = CreateFrame("Frame", nil, scroll)
    bar:SetPoint("TOPRIGHT", 0, 0)
    bar:SetPoint("BOTTOMRIGHT", 0, 0)
    bar:SetWidth(BAR_W)
    bar:EnableMouse(true)

    local track = bar:CreateTexture(nil, "ARTWORK")
    track:SetPoint("TOPRIGHT", 0, 0)
    track:SetPoint("BOTTOMRIGHT", 0, 0)
    track:SetWidth(3)
    track:SetColorTexture(1, 1, 1, 0.05)

    local thumb = CreateFrame("Frame", nil, bar)
    thumb:SetWidth(BAR_W)
    thumb:EnableMouse(true)
    local thumbTex = thumb:CreateTexture(nil, "OVERLAY")
    thumbTex:SetPoint("TOPRIGHT", 0, 0)
    thumbTex:SetPoint("BOTTOMRIGHT", 0, 0)
    thumbTex:SetWidth(3)
    thumbTex:SetColorTexture(unpack(C.accent))

    local function MaxScroll()
        return math.max(0, (content:GetHeight() or 1) - (scroll:GetHeight() or 1))
    end

    local function ScrollTo(value)
        scroll:SetVerticalScroll(math.max(0, math.min(MaxScroll(), value)))
        scroll:UpdateBar()
    end

    function scroll:UpdateBar()
        local viewH    = self:GetHeight() or 1
        local totalH   = content:GetHeight() or 1
        local maxScrol = math.max(0, totalH - viewH)
        if self:GetVerticalScroll() > maxScrol then self:SetVerticalScroll(maxScrol) end
        if maxScrol <= 0 then
            bar:Hide()
            return
        end
        bar:Show()
        local thumbH = math.max(20, viewH * math.min(1, viewH / totalH))
        local travel = viewH - thumbH
        thumb:SetHeight(thumbH)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0,
                       -((self:GetVerticalScroll() / maxScrol) * travel))
        self.thumbTravel = travel
    end

    -- Cursor position comes back at the root scale and has to be divided by the
    -- frame's effective scale before it can be compared with anything measured off
    -- the frame. Skipping that makes the drag track the cursor at the wrong speed on
    -- any UI scale other than 1.
    local function CursorY()
        local _, y = GetCursorPosition()
        return y / (thumb:GetEffectiveScale() or 1)
    end

    local function OnDrag(self)
        local travel = scroll.thumbTravel or 0
        if travel <= 0 then return end
        ScrollTo(self.grabScroll + (self.grabY - CursorY()) * (MaxScroll() / travel))
    end

    thumb:SetScript("OnMouseDown", function(self)
        self.grabY      = CursorY()
        self.grabScroll = scroll:GetVerticalScroll()
        thumbTex:SetColorTexture(1, 1, 1, 0.9)
        self:SetScript("OnUpdate", OnDrag)
    end)
    -- OnHide as well as OnMouseUp: releasing outside the frame does not always
    -- deliver OnMouseUp, and a leftover OnUpdate would drag the list around forever.
    local function EndDrag(self)
        self:SetScript("OnUpdate", nil)
        thumbTex:SetColorTexture(unpack(C.accent))
    end
    thumb:SetScript("OnMouseUp", EndDrag)
    thumb:SetScript("OnHide", EndDrag)

    bar:SetScript("OnMouseDown", function()
        local top, bot, y = thumb:GetTop(), thumb:GetBottom(), CursorY()
        if top and bot and y <= top and y >= bot then return end
        ScrollTo(scroll:GetVerticalScroll()
                 + ((top and y > top) and -(scroll:GetHeight() or 1) or (scroll:GetHeight() or 1)))
    end)

    -- Nothing in this addon called an UpdateBar before, because there was no bar.
    -- Rather than add a call to every loop that fills a list, the bar watches the
    -- content frame it is describing and updates itself when that resizes.
    content:SetScript("OnSizeChanged", function() scroll:UpdateBar() end)
    scroll:SetScript("OnShow", function(self) self:UpdateBar() end)

-- If the content frame is still sitting at zero when the scroll frame gets its
    -- real size, give it that size. A frame positioned by anchors measures 0 until a
    -- layout pass has run, so a caller that sized its content from scroll:GetWidth()
    -- on the very first call built every row zero-wide - which is the "the list is
    -- empty until I click a second time" bug, and it has now been found three times.
    --
    -- Only when it is zero: several callers set a deliberate width, and clobbering
    -- those would trade this bug for a layout one. Rows are anchored to the content's
    -- edges, so they take the corrected width with them.
    scroll:SetScript("OnSizeChanged", function(self)
        if (self.content:GetWidth() or 0) <= 1 then
            self.content:SetWidth(self:GetWidth() or 0)
        end
        if self.UpdateBar then self:UpdateBar() end
    end)

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local maxScroll = math.max(0, content:GetHeight() - self:GetHeight())
        local newScroll = math.min(maxScroll, math.max(0, self:GetVerticalScroll() - delta * 24))
        self:SetVerticalScroll(newScroll)
        self:UpdateBar()
    end)
    return scroll
end

-- Shared behaviour for every floating list and panel: closes when you click away
-- from it, closes on Escape, and never outlives the window it belongs to.
--
-- `closeOnOutside` is false for panels that hold typed input. Dismissing a form on a
-- stray click loses whatever was in it, which is worse than an extra click on Close.
--
-- There is no "clicked anywhere" event, so the outside click is caught by a full
-- screen button underneath the popup, shown and hidden with it. It swallows the click
-- that dismisses - first click closes, second one acts - which is how every dropdown
-- in the game behaves, Blizzard's included.
local function AttachPopupBehaviour(popup, closeOnOutside)
    local catcher
    if closeOnOutside then
        catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:RegisterForClicks("AnyUp")
        catcher:Hide()
        catcher:SetScript("OnClick", function() popup:Hide() end)
    end

    -- Escape closes the list rather than the window behind it. Propagation is left on
    -- for every other key, so this never swallows movement or typing; it is turned off
    -- only for the Escape that is actually being handled, which is what stops the same
    -- press also reaching CloseSpecialWindows and shutting the window.
    popup:EnableKeyboard(true)
    SafePropagate(popup, true)
    popup:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" and not InCombatLockdown() then
            SafePropagate(self, false)
            self:Hide()
        else
            SafePropagate(self, true)
        end
    end)

    -- The anchor is read back from the popup's own SetPoint rather than passed in, so
    -- this works for every caller without any of them having to remember to say who
    -- owns them. IsVisible is false when any ancestor is hidden, which is exactly the
    -- case being watched for.
    local function WatchOwner(self)
        if self.owner and not self.owner:IsVisible() then self:Hide() end
    end

    popup:HookScript("OnShow", function(self)
        local _, relativeTo = self:GetPoint(1)
        self.owner = relativeTo
        self:SetScript("OnUpdate", WatchOwner)
        if catcher then
            catcher:SetFrameStrata(self:GetFrameStrata())
            catcher:SetFrameLevel(110)
            self:SetFrameLevel(120)
            catcher:Show()
        end
    end)
    popup:HookScript("OnHide", function(self)
        self:SetScript("OnUpdate", nil)
        SafePropagate(self, true)
        if catcher then catcher:Hide() end
    end)
    return popup
end

--------------------------------------------------------------------------------
-- Row pooling (with alternating shading)
--------------------------------------------------------------------------------
local function AcquireRow(pool, parent, index, withRemove)
    local row = pool[index]
    if not row then
        row = CreateFrame("Frame", nil, parent)
        row:SetHeight(18)
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetTexture(WHITE)
        row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.left:SetPoint("LEFT", 4, 0)
        row.left:SetJustifyH("LEFT")
        row.right = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.right:SetPoint("RIGHT", -6, 0)
        row.right:SetJustifyH("RIGHT")
        row.btn = CreateFlatButton(row, "x", 16, 14)
        row.btn:SetPoint("RIGHT", -2, 0)
        row.btn:Hide()
        pool[index] = row
    end
    local col = (index % 2 == 0) and C.rowA or C.rowB
    row.bg:SetVertexColor(unpack(col))
    row:Show()
    return row
end

local function HideExtraRows(pool, fromIndex)
    for i = fromIndex, #pool do pool[i]:Hide() end
end

--------------------------------------------------------------------------------
-- Tabs (Raid Addons / Raid Consumables) shared by leader + raider windows
--------------------------------------------------------------------------------
-- Copy the first anchor point of a shown window to another, so a tab switch
-- opens the sibling window in the same on-screen spot.
local function copyPoint(from, to)
    if not (from and to) then return end
    if not from:IsShown() then return end
    local p, rel, rp, x, y = from:GetPoint(1)
    if p then
        to:ClearAllPoints()
        to:SetPoint(p, rel, rp, x, y)
    end
end

-- The RaidReady window currently on screen that a secondary window should dock
-- next to (optionally ignoring one, and optionally only the leader-side windows).
local function anchorWindow(exclude, leaderOnly)
    local list = leaderOnly
        and { RAA.frame, RAA.consumeFrame, RAA.infoFrame }
        or  { RAA.frame, RAA.consumeFrame, RAA.infoFrame, RAA.raiderFrame, RAA.raiderConsumeFrame }
    for i = 1, #list do
        local fr = list[i]
        if fr and fr ~= exclude and fr:IsShown() then return fr end
    end
    return nil
end

-- Attach `win` to `ref`: anchored to its right when that fits on screen, else its
-- left, so the popup MOVES WITH the window it docked to. Clamping is turned off
-- while docked - a frame-relative anchor plus SetClampedToScreen fight each other
-- (visible shaking); an unclamped anchored frame just follows cleanly. Dragging
-- the popup re-enables its clamp (see the header OnDragStop). With no `ref`, the
-- window keeps its existing position.
local function placeBeside(win, ref)
    if not (ref and ref:IsShown() and ref:GetLeft() and ref:GetRight()) then return end

    local gap = 6
    local ws = win:GetEffectiveScale()
    local rs = ref:GetEffectiveScale()
    local screenW  = GetScreenWidth() * UIParent:GetEffectiveScale()
    local refRight = ref:GetRight() * rs
    local refLeft  = ref:GetLeft()  * rs
    local winW     = win:GetWidth() * ws
    local gapPx    = gap * ws

    local rightFits = (refRight + gapPx + winW) <= screenW
    local leftFits  = (refLeft - gapPx - winW) >= 0
    local goRight = rightFits or (not leftFits and (screenW - refRight) >= refLeft)

    win:ClearAllPoints()
    win:SetClampedToScreen(false)
    if goRight then
        win:SetPoint("TOPLEFT", ref, "TOPRIGHT", gap, 0)
    else
        win:SetPoint("TOPRIGHT", ref, "TOPLEFT", -gap, 0)
    end
end

-- Dock `win` next to an open RaidReady window, unless the user has dragged it.
-- Call AFTER win:Show() so both frames report final size/position.
local function dockBeside(win, leaderOnly)
    if not win or win.userMoved then return end
    local ref = anchorWindow(win, leaderOnly)
    if ref then placeBeside(win, ref) end
end

local function CreateTabBar(win, activeKey, onSwitch)
    local defs = {
        { key = "addons",      text = "Addons" },
        { key = "consumables", text = "Consumables" },
        { key = "info",        text = "Character" },
    }
    local margin, gap = 10, 4
    local tabW = math.floor((win:GetWidth() - margin * 2 - gap * (#defs - 1)) / #defs)
    local x = margin
    for _, d in ipairs(defs) do
        local b = CreateFlatButton(win, d.text, tabW, 20)
        b:SetPoint("TOPLEFT", x, -40)   -- gap below the header so the accent bar stands out
        if d.key == activeKey then
            b:SetScript("OnEnter", nil)
            b:SetScript("OnLeave", nil)
            b:SetBackdropColor(unpack(C.btnHi))
            b:SetBackdropBorderColor(unpack(C.accent))
            b.text:SetTextColor(1, 1, 1)
        else
            b:SetScript("OnClick", function() onSwitch(d.key) end)
        end
        x = x + tabW + gap
    end
end

--------------------------------------------------------------------------------
-- Window auto-sizing + class colors
--------------------------------------------------------------------------------
local ROW_H = 18

local function groupRows()
    local n = GetNumGroupMembers()   -- 0 solo, up to 40
    if n == 0 then return 4 end
    if n <= 5 then return math.max(n, 4) end
    return math.min(n, 40)           -- fit up to a 40-person raid
end

-- Resize a window so `scroll` shows `rows` rows. The top gap (window top ->
-- scroll top) and bottom gap (scroll bottom -> window bottom) are invariant to
-- height, so one measurement suffices; retry once if not yet laid out. A little
-- slack (+10) guarantees the last intended row isn't clipped into a scroll.
local function fitRows(f, scroll, rows)
    if not (f and scroll and f:IsShown()) then return end
    local ft, st, sb, fb = f:GetTop(), scroll:GetTop(), scroll:GetBottom(), f:GetBottom()
    if not (ft and st and sb and fb) then
        C_Timer.After(0, function() fitRows(f, scroll, rows) end)
        return
    end
    f:SetHeight((ft - st) + rows * ROW_H + (sb - fb) + 10)
end

-- Fit a window to the actual pixel height of its scroll content (accounts for
-- inter-category gaps, so it never comes up a few px short and scrolls).
local function fitContentPx(f, scroll, px)
    if not (f and scroll and f:IsShown()) then return end
    px = math.max(3 * ROW_H, math.min(px, 45 * ROW_H))
    local ft, st, sb, fb = f:GetTop(), scroll:GetTop(), scroll:GetBottom(), f:GetBottom()
    if not (ft and st and sb and fb) then
        C_Timer.After(0, function() fitContentPx(f, scroll, px) end)
        return
    end
    f:SetHeight((ft - st) + px + (sb - fb) + 12)
end

-- Settings gear button placed just left of the close button.
local function addSettingsButton(header, closeBtn)
    local gear = CreateFrame("Button", nil, header)
    gear:SetSize(18, 18)
    gear:SetPoint("RIGHT", closeBtn, "LEFT", -4, 0)
    gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
    gear:SetScript("OnClick", function() RAA:ToggleSettings() end)
    return gear
end

-- "AARRGGBB" class color for a class token ("MAGE"), honoring class-color addons.
local function classColorHex(classToken)
    local t = classToken and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classToken])
                              or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken]))
    if t then return string.format("ff%02x%02x%02x", t.r * 255, t.g * 255, t.b * 255) end
    return "ffe6e6e6"
end

--------------------------------------------------------------------------------
-- Installed-addon picker (flyout)
--------------------------------------------------------------------------------
local function BuildBrowser(f)
    local fly = CreateFlatFrame(f, C.bg)
    fly:SetSize(250, 320)
    fly:SetClampedToScreen(true)
    fly:SetFrameStrata("DIALOG")
    fly:Hide()
    fly.rows = {}

    local search = CreateFlatEditBox(fly, 226, 20)
    search:SetPoint("TOPLEFT", 12, -12)
    fly.search = search
    local sLbl = fly:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sLbl:SetPoint("BOTTOMLEFT", search, "TOPLEFT", 0, 2)
    sLbl:SetText("Search installed addons")

    local list = CreateScrollList(fly, 226, 250)
    list:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -8)
    fly.list = list

    search:SetScript("OnTextChanged", function(s) RAA:RefreshBrowser(s:GetText()) end)
    f.browser = fly
    AttachPopupBehaviour(fly, true)
    return fly
end

function RAA:RefreshBrowser(filter)
    local fly = self.frame and self.frame.browser
    if not fly then return end
    self:BuildInstalledMap()
    filter = (filter or ""):lower()

    -- collect + sort installed folder names
    local names = {}
    for _, entry in pairs(self.installed) do
        if filter == "" or entry.name:lower():find(filter, 1, true) then
            names[#names + 1] = entry
        end
    end
    table.sort(names, function(a, b) return a.name:lower() < b.name:lower() end)

    local content = fly.list.content
    local y = 0
    for i, entry in ipairs(names) do
        local row = fly.rows[i]
        if not row then
            row = CreateFrame("Button", nil, content, "BackdropTemplate")
            row:SetHeight(18)
            row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints(); row.bg:SetTexture(WHITE)
            row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.name:SetPoint("LEFT", 4, 0); row.name:SetJustifyH("LEFT")
            row.ver = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            row.ver:SetPoint("RIGHT", -6, 0); row.ver:SetJustifyH("RIGHT")
            row:SetScript("OnEnter", function(s) s.bg:SetVertexColor(unpack(C.accent)); s.bg:SetAlpha(0.35) end)
            row:SetScript("OnLeave", function(s) s.bg:SetAlpha(1); s.bg:SetVertexColor(unpack((s.idx % 2 == 0) and C.rowA or C.rowB)) end)
            fly.rows[i] = row
        end
        row.idx = i
        row:SetPoint("TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", 0, y)
        row.bg:SetAlpha(1); row.bg:SetVertexColor(unpack((i % 2 == 0) and C.rowA or C.rowB))
        row.name:SetText(entry.name)
        row.name:SetTextColor(unpack(C.text))
        row.ver:SetText(entry.version ~= "" and entry.version or "-")
        row:SetScript("OnClick", function()
            self.frame.nameBox:SetText(entry.name)
            -- Prefill the min-version box with the version you currently run, so
            -- "at least what I have" is one click. Editable before you hit Add.
            self.frame.verBox:SetText(entry.version ~= "" and entry.version or "")
            fly:Hide()
            self.frame.verBox:SetFocus()
            self.frame.verBox:HighlightText()
        end)
        row:Show()
        y = y - 18
    end
    for i = #names + 1, #fly.rows do fly.rows[i]:Hide() end
    content:SetHeight(math.max(1, #names * 18))
    fly.list:SetVerticalScroll(0)
end

--------------------------------------------------------------------------------
-- Build the main window
--------------------------------------------------------------------------------
local function BuildUI()
    if RAA.frame then return RAA.frame end

    local f = CreateFrame("Frame", "RaidReadyFrame", UIParent, "BackdropTemplate")
    f:SetSize(440, 604)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadyFrame")  -- ESC closes
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)

    -- Header bar (drag handle)
    local header = CreateFlatFrame(f, C.header)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(30)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f.userMoved = true; f:SetClampedToScreen(true) end)

    -- accent underline
    addAccentBar(header)

    local icon = header:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\AddOns\\nugsRaidReady\\icon")
    icon:SetTexCoord(0, 1, 0, 1)  -- custom icon: show the full image

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText(TITLE_TEXT)
    title:SetTextColor(unpack(C.gold))

    local close = CreateFlatButton(header, "x", 22, 18)
    close:SetPoint("RIGHT", -6, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    -- keep hover behavior from CreateFlatButton but re-add the click text
    close.text:SetText("x")

    addSettingsButton(header, close)
    CreateTabBar(f, "addons", function(k) RAA:SwitchLeaderTab(k) end)

    ----------------------------------------------------------------------------
    -- Requirements editor
    ----------------------------------------------------------------------------
    local reqHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    reqHeader:SetPoint("TOPLEFT", 16, -72)
    reqHeader:SetText("Required addons")
    reqHeader:SetTextColor(unpack(C.text))

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", reqHeader, "BOTTOMLEFT", 0, -3)
    hint:SetText("Pick from your installed addons, then set a minimum version (blank = any).")

    -- name box + browse
    local nameBox = CreateFlatEditBox(f, 210, 22)
    nameBox:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 2, -18)
    f.nameBox = nameBox
    local nameLbl = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    nameLbl:SetPoint("BOTTOMLEFT", nameBox, "TOPLEFT", 0, 3)
    nameLbl:SetText("Addon folder")

    local browseBtn = CreateFlatButton(f, "Browse...", 80, 22)
    browseBtn:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)

    -- version box + add
    local verBox = CreateFlatEditBox(f, 100, 22)
    verBox:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -22)
    f.verBox = verBox
    local verLbl = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    verLbl:SetPoint("BOTTOMLEFT", verBox, "TOPLEFT", 0, 3)
    verLbl:SetText("Min version")

    local addBtn = CreateFlatButton(f, "Add", 60, 22)
    addBtn:SetPoint("LEFT", verBox, "RIGHT", 8, 0)

    -- Fill the version box with whatever version YOU currently have installed
    -- for the folder named in the name box.
    local useMineBtn = CreateFlatButton(f, "Use mine", 76, 22)
    useMineBtn:SetPoint("LEFT", addBtn, "RIGHT", 8, 0)
    useMineBtn:SetScript("OnClick", function()
        local name = (nameBox:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local ver = RAA:InstalledVersionOf(name)
        if ver == nil then
            print("|cff33ff99RaidReady|r: you don't have an addon named '" .. name .. "' installed.")
        elseif ver == "" then
            print("|cff33ff99RaidReady|r: '" .. name .. "' has no version in its .toc, so it can't be version-gated.")
        else
            verBox:SetText(ver)
            verBox:SetFocus()
            verBox:HighlightText()
        end
    end)

    local reqPanel = CreateFlatFrame(f, C.panel)
    reqPanel:SetPoint("TOPLEFT", verBox, "BOTTOMLEFT", 0, -14)
    reqPanel:SetSize(408, 120)
    local reqScroll = CreateScrollList(reqPanel, 402, 114)
    reqScroll:SetPoint("TOPLEFT", 3, -3)
    f.reqScroll = reqScroll
    f.reqRows = {}

    local function commitAdd()
        if RAA:AddRequirement(nameBox:GetText(), verBox:GetText()) then
            nameBox:SetText(""); verBox:SetText("")
            nameBox:ClearFocus(); verBox:ClearFocus()
            RAA:RefreshRequirements()
        end
    end
    addBtn:SetScript("OnClick", commitAdd)
    verBox:SetScript("OnEnterPressed", commitAdd)
    nameBox:SetScript("OnEnterPressed", function() verBox:SetFocus() end)

    -- browser flyout
    BuildBrowser(f)
    f.browser:SetPoint("TOPLEFT", browseBtn, "BOTTOMLEFT", -180, -2)
    browseBtn:SetScript("OnClick", function()
        if f.browser:IsShown() then
            f.browser:Hide()
        else
            f.browser.search:SetText("")
            RAA:RefreshBrowser("")
            f.browser:Show()
            f.browser.search:SetFocus()
        end
    end)

    ----------------------------------------------------------------------------
    -- Check + results
    ----------------------------------------------------------------------------
    local checkBtn = CreateFlatButton(f, "Check Raid", 120, 26)
    checkBtn:SetPoint("TOPLEFT", reqPanel, "BOTTOMLEFT", 0, -14)
    checkBtn:SetScript("OnClick", function() RAA:StartCheck() end)
    f.checkBtn = checkBtn

    local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("LEFT", checkBtn, "RIGHT", 12, 0)
    summary:SetText("")
    f.summary = summary

    -- Auto-whisper toggle
    local whisperCheck = CreateFlatCheck(f, "Whisper players to update or install")
    whisperCheck:SetPoint("TOPLEFT", checkBtn, "BOTTOMLEFT", 2, -10)
    whisperCheck:SetChecked(RaidReadyDB and RaidReadyDB.autoWhisper)
    whisperCheck.onToggle = function(checked)
        if RaidReadyDB then RaidReadyDB.autoWhisper = checked end
    end
    f.whisperCheck = whisperCheck

    -- Preview the player-facing screen (uses your own required list; handy solo)
    local previewBtn = CreateFlatButton(f, "Preview Player View", 150, 22)
    previewBtn:SetPoint("TOPLEFT", whisperCheck, "BOTTOMLEFT", -2, -12)
    previewBtn:SetScript("OnClick", function() RAA:PreviewRaiderView() end)

    local resPanel = CreateFlatFrame(f, C.panel)
    resPanel:SetPoint("TOPLEFT", previewBtn, "BOTTOMLEFT", 2, -12)
    resPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    local resScroll = CreateScrollList(resPanel, 404, 180)
    resScroll:SetPoint("TOPLEFT", 3, -3)
    resScroll:SetPoint("BOTTOMRIGHT", -3, 3)
    f.resScroll = resScroll
    f.resRows = {}

    f:Hide()  -- new frames show by default; start hidden so the first toggle opens it
    RAA.frame = f
    return f
end

--------------------------------------------------------------------------------
-- Refresh: requirements list
--------------------------------------------------------------------------------
function RAA:RefreshRequirements()
    local f = self.frame
    if not f then return end
    local names = self:RequiredNames()
    local req = self:GetRequirements()
    local content = f.reqScroll.content
    local width = f.reqScroll:GetWidth()

    if #names == 0 then
        HideExtraRows(f.reqRows, 1)
        local row = AcquireRow(f.reqRows, content, 1, false)
        row:SetPoint("TOPLEFT", 0, 0); row:SetWidth(width)
        row.bg:SetVertexColor(0, 0, 0, 0)
        row.left:SetText("|cff777777No required addons yet - add some above.|r")
        row.right:Hide(); row.btn:Hide()
        content:SetHeight(18)
        return
    end

    local y = 0
    for i, name in ipairs(names) do
        local row = AcquireRow(f.reqRows, content, i, true)
        row:SetPoint("TOPLEFT", 0, y); row:SetWidth(width)
        local minv = req[name]
        local verText = (minv == nil or minv == "") and "(any)" or (">= " .. minv)
        row.left:SetText("|cffe6e6e6" .. name .. "|r   |cff888888" .. verText .. "|r")
        row.right:Hide()
        row.btn:Show()
        row.btn:SetScript("OnClick", function()
            RAA:RemoveRequirement(name)
            RAA:RefreshRequirements()
        end)
        y = y - 18
    end
    HideExtraRows(f.reqRows, #names + 1)
    content:SetHeight(math.max(1, #names * 18))
end

--------------------------------------------------------------------------------
-- Refresh: results list
--------------------------------------------------------------------------------
local function detailString(details)
    local bad = {}
    for name, d in pairs(details) do
        if d.status == "missing" then
            bad[#bad + 1] = name .. " missing"
        elseif d.status == "outdated" then
            bad[#bad + 1] = name .. " " .. (d.have or "?") .. "<" .. (d.need or "?")
        elseif d.status == "noversion" then
            bad[#bad + 1] = name .. " (ver?)"
        end
    end
    return table.concat(bad, ", ")
end

function RAA:RefreshResults()
    local f = self.frame
    if not f then return end
    local session = self.session
    local content = f.resScroll.content
    local width = f.resScroll:GetWidth()

    if not session then
        HideExtraRows(f.resRows, 1)
        return
    end

    local order = { pending = 0, ok = 1, offline = 2, noversion = 3, outdated = 4, noaddon = 5, missing = 6 }
    local list = {}
    for _, r in pairs(session.results) do list[#list + 1] = r end
    table.sort(list, function(a, b)
        local oa, ob = order[a.worst] or 9, order[b.worst] or 9
        if oa ~= ob then return oa > ob end
        return (a.display or "") < (b.display or "")
    end)

    local counts = { ok = 0, bad = 0, waiting = 0 }
    local y = 0
    for i, r in ipairs(list) do
        local row = AcquireRow(f.resRows, content, i, false)
        row:SetPoint("TOPLEFT", 0, y); row:SetWidth(width)
        row.btn:Hide()

        local s = STATUS[r.worst] or STATUS.pending
        local detail = (r.worst ~= "ok" and r.worst ~= "pending" and r.responded)
                       and ("   |cff888888" .. detailString(r.details) .. "|r") or ""
        row.left:SetText("|c" .. classColorHex(r.class) .. (r.display or "?") .. "|r" .. detail)
        row.right:Show()
        row.right:SetText(s.text)
        row.right:SetTextColor(s.color[1], s.color[2], s.color[3])

        if r.worst == "ok" then counts.ok = counts.ok + 1
        elseif r.worst == "pending" then counts.waiting = counts.waiting + 1
        elseif r.worst == "offline" then -- neutral: not counted as an issue
        else counts.bad = counts.bad + 1 end
        y = y - 18
    end
    HideExtraRows(f.resRows, #list + 1)
    content:SetHeight(math.max(1, #list * 18))

    f.summary:SetText(string.format("|cff59e673%d ok|r   |cffff5959%d issue(s)|r   |cff888888%d waiting|r",
        counts.ok, counts.bad, counts.waiting))
    self:AutoSizeLeader()
end

--------------------------------------------------------------------------------
-- Raider view
-- Shown on a raider's own screen when a leader runs a check: a compact box
-- listing the required addons and whether THEY are ok / outdated / missing.
--------------------------------------------------------------------------------
local function BuildRaiderView()
    if RAA.raiderFrame then return RAA.raiderFrame end

    local f = CreateFrame("Frame", "RaidReadyRaiderFrame", UIParent, "BackdropTemplate")
    f:SetSize(340, 274)
    f:SetPoint("CENTER", 0, 140)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetFrameStrata("HIGH")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadyRaiderFrame")  -- ESC closes
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)
    -- Closing forgets a manual drag, so reopening re-docks beside the main window.
    f:SetScript("OnHide", function(s) s.userMoved = nil end)

    local header = CreateFlatFrame(f, C.header)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(28)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f.userMoved = true; f:SetClampedToScreen(true) end)

    addAccentBar(header)

    local icon = header:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\AddOns\\nugsRaidReady\\icon")
    icon:SetTexCoord(0, 1, 0, 1)

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    title:SetText(TITLE_TEXT)
    title:SetTextColor(unpack(C.gold))

    local close = CreateFlatButton(header, "x", 22, 18)
    close:SetPoint("RIGHT", -6, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    addSettingsButton(header, close)

    CreateTabBar(f, "addons", function(k) RAA:SwitchRaiderTab(k) end)

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", 14, -66)
    sub:SetPoint("TOPRIGHT", -14, -66)
    sub:SetJustifyH("LEFT")
    f.sub = sub

    local panel = CreateFlatFrame(f, C.panel)
    panel:SetPoint("TOPLEFT", 12, -86)
    panel:SetPoint("BOTTOMRIGHT", -12, 44)
    local scroll = CreateScrollList(panel, 274, 130)
    scroll:SetPoint("TOPLEFT", 3, -3)
    scroll:SetPoint("BOTTOMRIGHT", -3, 3)
    f.scroll = scroll
    f.rows = {}

    local okBtn = CreateFlatButton(f, "Got it", 90, 24)
    okBtn:SetPoint("BOTTOM", 0, 12)
    okBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()  -- start hidden so the first toggle/show opens it cleanly
    RAA.raiderFrame = f
    return f
end

function RAA:ShowRaiderView(reqMap, requester)
    local f = BuildRaiderView()
    if self.raiderConsumeFrame then self.raiderConsumeFrame:Hide() end  -- addon tab is active
    if self.infoFrame then self.infoFrame:Hide() end

    -- Build our own installed versions for the required addons and evaluate.
    local reported = {}
    for name in pairs(reqMap) do
        local v = self:InstalledVersionOf(name)
        if v ~= nil then reported[name] = v end
    end
    local worst, details = self:EvaluateAgainst(reqMap, reported)

    local who = requester and Ambiguate(requester, "none") or "Raid leader"
    if worst == "ok" then
        f.sub:SetText("|cff59e673You're all set|r - required by " .. who .. ":")
    else
        f.sub:SetText("|cffff7d0aAction needed|r - required by " .. who .. ":")
    end

    local names = {}
    for name in pairs(reqMap) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)

    local content = f.scroll.content
    local width = f.scroll:GetWidth()
    local y = 0
    for i, name in ipairs(names) do
        local row = AcquireRow(f.rows, content, i, false)
        row:SetPoint("TOPLEFT", 0, y); row:SetWidth(width)
        row.btn:Hide()
        local d = details[name]
        local s = STATUS[d.status] or STATUS.ok
        local haveStr = (d.have and d.have ~= "") and ("  |cff888888(" .. d.have .. ")|r") or ""
        row.left:SetText("|cffe6e6e6" .. name .. "|r" .. haveStr)
        row.right:Show()
        row.right:SetText(s.text)
        row.right:SetTextColor(s.color[1], s.color[2], s.color[3])
        y = y - 18
    end
    HideExtraRows(f.rows, #names + 1)
    content:SetHeight(math.max(1, #names * 18))
    f.scroll:SetVerticalScroll(0)
    f:Show()
    fitContentPx(f, f.scroll, #names * ROW_H)
    dockBeside(f, true)
end

-- Toggle the raider box on demand (e.g. a member typing /nrr). Uses the most
-- recent check we received; shows an empty state if none has happened yet.
function RAA:ToggleRaiderView()
    local f = BuildRaiderView()
    if f:IsShown() or (self.raiderConsumeFrame and self.raiderConsumeFrame:IsShown())
       or (self.infoFrame and self.infoFrame:IsShown()) then
        f:Hide()
        if self.raiderConsumeFrame then self.raiderConsumeFrame:Hide() end
        if self.infoFrame then self.infoFrame:Hide() end
        return
    end
    if self.lastReqMap and next(self.lastReqMap) then
        self:ShowRaiderView(self.lastReqMap, self.lastRequester)
    else
        f.sub:SetText("|cff888888No addon check has been run yet. Your raid leader will run one.|r")
        HideExtraRows(f.rows, 1)
        f.scroll.content:SetHeight(1)
        f:Show()
    end
end

-- Leader-side: preview the player-facing screen using your own required list,
-- evaluated against your own installed addons. Useful for checking it solo.
function RAA:PreviewRaiderView()
    local req = self:GetRequirements()
    if not next(req) then
        print("|cff33ff99RaidReady|r: add some required addons first, then preview.")
        return
    end
    self:ShowRaiderView(req, GetUnitName("player", true) or UnitName("player"))
end

--------------------------------------------------------------------------------
-- Consumables: leader window (config + results)
--------------------------------------------------------------------------------
local function addSkinnedHeader(f, titleText, tabActiveKey, onSwitch)
    local header = CreateFlatFrame(f, C.header)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(30)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f.userMoved = true; f:SetClampedToScreen(true) end)
    addAccentBar(header)
    local icon = header:CreateTexture(nil, "OVERLAY")
    icon:SetSize(18, 18); icon:SetPoint("LEFT", 10, 0)
    icon:SetTexture("Interface\\AddOns\\nugsRaidReady\\icon"); icon:SetTexCoord(0, 1, 0, 1)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", icon, "RIGHT", 8, 0); title:SetText(TITLE_TEXT); title:SetTextColor(unpack(C.gold))
    local close = CreateFlatButton(header, "x", 22, 18)
    close:SetPoint("RIGHT", -6, 0); close:SetScript("OnClick", function() f:Hide() end)
    addSettingsButton(header, close)
    CreateTabBar(f, tabActiveKey, onSwitch)
end

local function BuildConsumeUI()
    if RAA.consumeFrame then return RAA.consumeFrame end

    local f = CreateFrame("Frame", "RaidReadyConsumeFrame", UIParent, "BackdropTemplate")
    f:SetSize(440, 604)
    f:SetPoint("CENTER")
    f:SetMovable(true); f:SetClampedToScreen(true); f:SetFrameStrata("HIGH")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadyConsumeFrame")
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)
    addSkinnedHeader(f, "RaidReady", "consumables", function(k) RAA:SwitchLeaderTab(k) end)

    local cfgHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cfgHeader:SetPoint("TOPLEFT", 16, -72)
    cfgHeader:SetText("Required categories")
    cfgHeader:SetTextColor(unpack(C.text))

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", cfgHeader, "BOTTOMLEFT", 0, -3)
    hint:SetText("A raider passes a category if they carry any item in it.")

    local cfgPanel = CreateFlatFrame(f, C.panel)
    cfgPanel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", -2, -8)
    cfgPanel:SetSize(408, 146)   -- fits the category checkboxes with no dead space
    local cfgScroll = CreateScrollList(cfgPanel, 402, 140)
    cfgScroll:SetPoint("TOPLEFT", 3, -3)
    f.cfgScroll = cfgScroll

    -- One checkbox per category (require the whole category).
    local content = cfgScroll.content
    f.categoryChecks = {}
    local y = -2
    for _, cat in ipairs(RAA.CONSUMABLES) do
        local catName = cat.category
        local cb = CreateFlatCheck(content, catName)
        cb:SetPoint("TOPLEFT", 4, y)
        cb.onToggle = function(checked) RAA:SetCategoryRequired(catName, checked) end
        f.categoryChecks[catName] = cb
        y = y - 22
    end
    content:SetHeight(-y + 4)

    local checkBtn = CreateFlatButton(f, "Check Raid", 120, 26)
    checkBtn:SetPoint("TOPLEFT", cfgPanel, "BOTTOMLEFT", 0, -12)
    checkBtn:SetScript("OnClick", function() RAA:StartConsumableCheck() end)
    f.consumeCheckBtn = checkBtn

    local summary = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summary:SetPoint("LEFT", checkBtn, "RIGHT", 12, 0)
    f.consumeSummary = summary

    local previewBtn = CreateFlatButton(f, "Preview Player View", 150, 22)
    previewBtn:SetPoint("TOPLEFT", checkBtn, "BOTTOMLEFT", 2, -10)
    previewBtn:SetScript("OnClick", function() RAA:PreviewConsumePreview() end)

    -- See all categories with what you personally have (pre-raid prep view).
    local myBtn = CreateFlatButton(f, "My Consumables", 130, 22)
    myBtn:SetPoint("LEFT", previewBtn, "RIGHT", 8, 0)
    myBtn:SetScript("OnClick", function() RAA:ShowConsumeInventory() end)

    local resPanel = CreateFlatFrame(f, C.panel)
    resPanel:SetPoint("TOPLEFT", previewBtn, "BOTTOMLEFT", -2, -12)
    resPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 14)
    local resScroll = CreateScrollList(resPanel, 404, 140)
    resScroll:SetPoint("TOPLEFT", 3, -3)
    resScroll:SetPoint("BOTTOMRIGHT", -3, 3)
    f.consumeResScroll = resScroll
    f.consumeResRows = {}

    f:Hide()
    RAA.consumeFrame = f
    return f
end

function RAA:RefreshConsumeConfig()
    local f = self.consumeFrame
    if not f then return end
    for catName, cb in pairs(f.categoryChecks) do
        cb:SetChecked(self:IsCategoryRequired(catName))
    end
end

function RAA:RefreshConsumeResults()
    local f = self.consumeFrame
    if not f then return end
    local session = self.consumeSession
    local content = f.consumeResScroll.content
    local width = f.consumeResScroll:GetWidth()
    if not session then HideExtraRows(f.consumeResRows, 1); return end

    local order = { pending = 0, ok = 1, offline = 2, missing = 5, noaddon = 5 }
    local list = {}
    for _, r in pairs(session.results) do list[#list + 1] = r end
    table.sort(list, function(a, b)
        local oa, ob = order[a.worst] or 9, order[b.worst] or 9
        if oa ~= ob then return oa > ob end
        return (a.display or "") < (b.display or "")
    end)

    local counts = { ok = 0, bad = 0, waiting = 0 }
    local y = 0
    for i, r in ipairs(list) do
        local row = AcquireRow(f.consumeResRows, content, i, false)
        row:SetPoint("TOPLEFT", 0, y); row:SetWidth(width); row.btn:Hide()
        local s = STATUS[r.worst] or STATUS.pending
        local detail = ""
        if r.responded and r.worst == "missing" then
            local miss = {}
            for idx, st in pairs(r.details) do
                if st == "missing" then
                    local cat = RAA.CONSUMABLES[idx]
                    miss[#miss + 1] = cat and cat.category or tostring(idx)
                end
            end
            detail = "   |cff888888" .. table.concat(miss, ", ") .. "|r"
        end
        row.left:SetText("|c" .. classColorHex(r.class) .. (r.display or "?") .. "|r" .. detail)
        row.right:Show(); row.right:SetText(s.text)
        row.right:SetTextColor(s.color[1], s.color[2], s.color[3])
        if r.worst == "ok" then counts.ok = counts.ok + 1
        elseif r.worst == "pending" then counts.waiting = counts.waiting + 1
        elseif r.worst == "offline" then
        else counts.bad = counts.bad + 1 end
        y = y - 18
    end
    HideExtraRows(f.consumeResRows, #list + 1)
    content:SetHeight(math.max(1, #list * 18))
    f.consumeSummary:SetText(string.format("|cff59e673%d ok|r   |cffff5959%d issue(s)|r   |cff888888%d waiting|r",
        counts.ok, counts.bad, counts.waiting))
    self:AutoSizeLeader()
end

function RAA:ShowConsumeUI()
    BuildConsumeUI()
    copyPoint(self.frame, self.consumeFrame)
    if self.frame then self.frame:Hide() end
    if self.infoFrame then self.infoFrame:Hide() end
    self.consumeFrame:Show()
    self:RefreshConsumeConfig()
    self:RefreshConsumeResults()
    self:UpdateLeaderState()
    self:AutoSizeLeader()
end

--------------------------------------------------------------------------------
-- Consumables: raider preview window
--------------------------------------------------------------------------------
local function BuildRaiderConsume()
    if RAA.raiderConsumeFrame then return RAA.raiderConsumeFrame end

    local f = CreateFrame("Frame", "RaidReadyRaiderConsumeFrame", UIParent, "BackdropTemplate")
    f:SetSize(340, 300)
    f:SetPoint("CENTER", 0, 140)
    f:SetMovable(true); f:SetClampedToScreen(true); f:SetFrameStrata("HIGH")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadyRaiderConsumeFrame")
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)
    -- Closing forgets a manual drag, so reopening re-docks beside the main window.
    f:SetScript("OnHide", function(s) s.userMoved = nil end)
    addSkinnedHeader(f, "Consumables", "consumables", function(k) RAA:SwitchRaiderTab(k) end)

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOPLEFT", 14, -66)
    sub:SetPoint("TOPRIGHT", -14, -66)
    sub:SetJustifyH("LEFT")
    f.sub = sub

    local panel = CreateFlatFrame(f, C.panel)
    panel:SetPoint("TOPLEFT", 12, -86)
    panel:SetPoint("BOTTOMRIGHT", -12, 44)
    local scroll = CreateScrollList(panel, 274, 150)
    scroll:SetPoint("TOPLEFT", 3, -3)
    scroll:SetPoint("BOTTOMRIGHT", -3, 3)
    f.scroll = scroll
    f.consumeRows = {}

    local okBtn = CreateFlatButton(f, "Got it", 90, 24)
    okBtn:SetPoint("BOTTOM", 0, 12)
    okBtn:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    RAA.raiderConsumeFrame = f
    return f
end

-- Render one category into the raider consume window: a header row (category +
-- have/none) followed by an indented row per item with the player's count. This
-- shows raiders exactly what items qualify for each category.
-- onlyOwned = true: list only the items the player has (>0). optionsWhenEmpty:
-- if a category has none, list all its items as options so the raider knows what
-- would qualify. onlyOwned = false lists every item always.
local function renderConsumeCategory(f, catEntry, ri, y, onlyOwned, optionsWhenEmpty)
    local content = f.scroll.content
    local width = f.scroll:GetWidth()
    local hasAny, items = RAA:CategoryStatus(catEntry)

    local h = AcquireRow(f.consumeRows, content, ri, false)
    h:SetPoint("TOPLEFT", 0, y); h:SetWidth(width); h.btn:Hide()
    h.left:SetText("|cff9fd7ff" .. catEntry.category .. "|r")
    h.right:Show()
    if hasAny then
        h.right:SetText("have"); h.right:SetTextColor(0.35, 0.9, 0.45)
    else
        h.right:SetText("none"); h.right:SetTextColor(1.0, 0.35, 0.35)
    end
    ri = ri + 1; y = y - 18

    for _, ic in ipairs(items) do
        local ct = RAA:ConsumableCountText(ic.hc, ic.lc)
        if ct or (not onlyOwned) or (optionsWhenEmpty and not hasAny) then
            local row = AcquireRow(f.consumeRows, content, ri, false)
            row:SetPoint("TOPLEFT", 0, y); row:SetWidth(width); row.btn:Hide()
            row.left:SetText("   |cffb0b0b0" .. ic.item.name .. "|r")
            row.right:Show()
            if ct then
                row.right:SetText(ct); row.right:SetTextColor(0.85, 0.85, 0.85)
            else
                row.right:SetText("-"); row.right:SetTextColor(0.45, 0.45, 0.45)
            end
            ri = ri + 1; y = y - 18
        end
    end
    return ri, y - 6
end

function RAA:ShowConsumePreview(indices, requester)
    local f = BuildRaiderConsume()
    if self.raiderFrame then self.raiderFrame:Hide() end
    if self.infoFrame then self.infoFrame:Hide() end

    local anyMissing = false
    for _, idx in ipairs(indices) do
        local cat = self.CONSUMABLES[idx]
        if cat and not self:CategoryStatus(cat) then anyMissing = true end
    end
    local who = requester and Ambiguate(requester, "none") or "Raid leader"
    f.sub:SetText(anyMissing
        and ("|cffff7d0aMissing consumables|r - required by " .. who .. ":")
        or  ("|cff59e673You're stocked|r - required by " .. who .. ":"))

    local ri, y = 1, 0
    for _, idx in ipairs(indices) do
        local cat = self.CONSUMABLES[idx]
        -- owned items only, but list options for a category they have none of
        if cat then ri, y = renderConsumeCategory(f, cat, ri, y, true, true) end
    end
    HideExtraRows(f.consumeRows, ri)
    f.scroll.content:SetHeight(math.max(1, -y))
    f.scroll:SetVerticalScroll(0)
    f:Show()
    fitContentPx(f, f.scroll, -y)
    dockBeside(f, true)
end

-- Default player view (no active check): every category, but only the items you
-- actually have; empty categories just show "none".
function RAA:ShowConsumeInventory()
    local f = BuildRaiderConsume()
    if self.raiderFrame then self.raiderFrame:Hide() end
    if self.infoFrame then self.infoFrame:Hide() end
    f.sub:SetText("Your consumables (by category):")
    local ri, y = 1, 0
    for _, cat in ipairs(self.CONSUMABLES) do
        ri, y = renderConsumeCategory(f, cat, ri, y, true, false)
    end
    HideExtraRows(f.consumeRows, ri)
    f.scroll.content:SetHeight(math.max(1, -y))
    f.scroll:SetVerticalScroll(0)
    f:Show()
    fitContentPx(f, f.scroll, -y)
    dockBeside(f, true)
end

-- Leader-side: preview the consumables screen using your own required categories.
function RAA:PreviewConsumePreview()
    local indices = self:RequiredCategoryIndices()
    if #indices == 0 then
        print("|cff33ff99RaidReady|r: select some required consumable categories first.")
        return
    end
    self:ShowConsumePreview(indices, GetUnitName("player", true) or UnitName("player"))
end

--------------------------------------------------------------------------------
-- Character tab (same content for leader and raider: your own character info)
--------------------------------------------------------------------------------
-- Grouped rather than one long list, so the tab is scannable at a glance.
local INFO_SECTIONS = {
    { title = "Gear", rows = {
        { key = "ilvlEquipped", label = "Item Level (equipped)" },
        { key = "ilvlOverall",  label = "Item Level (overall)" },
        { key = "tier",         label = "Tier Set" },
        { key = "enchants",     label = "Enchants" },
        { key = "gems",         label = "Gems" },
        { key = "durability",   label = "Durability" },
    }},
    { title = "Setup", rows = {
        { key = "spec",         label = "Specialization" },
        { key = "loadout",      label = "Talent Loadout" },
        { key = "loadoutAddon", label = "Loadout Addon" },
        { key = "set",          label = "Equipment Set" },
    }},
    { title = "Resources", rows = {
        { key = "gold",         label = "Gold" },
    }},
}

local INFO_ROW_H, INFO_SEC_H, INFO_SEC_GAP = 20, 18, 8

local function infoPanelHeight()
    local h = 10
    for i, sec in ipairs(INFO_SECTIONS) do
        h = h + INFO_SEC_H + #sec.rows * INFO_ROW_H
        if i < #INFO_SECTIONS then h = h + INFO_SEC_GAP end
    end
    return h + 8
end

-- Reusable single-select flyout for the preferred-setup pickers.
local choiceFlyout
local function ShowChoiceFlyout(anchor, choices, current, onPick)
    if not choiceFlyout then
        choiceFlyout = CreateFlatFrame(UIParent, C.bg)
        choiceFlyout:SetFrameStrata("FULLSCREEN_DIALOG")
        choiceFlyout:SetClampedToScreen(true)
        choiceFlyout.rows = {}
        choiceFlyout:Hide()
        AttachPopupBehaviour(choiceFlyout, true)
    end
    local fly = choiceFlyout
    fly:ClearAllPoints()
    fly:SetWidth(math.max(anchor:GetWidth(), 150))

    local list = { "(none)" }
    for _, c in ipairs(choices) do list[#list + 1] = c end

    for i, name in ipairs(list) do
        local row = fly.rows[i]
        if not row then
            row = CreateFrame("Button", nil, fly)
            row:SetHeight(18)
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints(); row.bg:SetTexture(WHITE)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            row.text:SetPoint("LEFT", 6, 0); row.text:SetJustifyH("LEFT")
            row:SetScript("OnEnter", function(s) s.bg:SetVertexColor(unpack(C.accent)); s.bg:SetAlpha(0.35) end)
            row:SetScript("OnLeave", function(s) s.bg:SetAlpha(1); s.bg:SetVertexColor(0, 0, 0, 0) end)
            fly.rows[i] = row
        end
        local y = -4 - (i - 1) * 18
        row:SetPoint("TOPLEFT", 4, y); row:SetPoint("TOPRIGHT", -4, y)
        row.bg:SetAlpha(1); row.bg:SetVertexColor(0, 0, 0, 0)
        local isCur = (name == current) or (name == "(none)" and (current == nil or current == ""))
        row.text:SetText((isCur and "|cff59e673" or "|cffe6e6e6") .. name .. "|r")
        row:SetScript("OnClick", function()
            fly:Hide()
            onPick(name ~= "(none)" and name or nil)
        end)
        row:Show()
    end
    for i = #list + 1, #fly.rows do fly.rows[i]:Hide() end
    fly:SetHeight(#list * 18 + 8)

    -- Anchored only now: the height comes from the row count, and there is
    -- nothing to measure against the screen edge before it is known. Drop down
    -- if there is room, otherwise open upwards - clamping alone would slide the
    -- list over the button that opened it.
    local below = (anchor:GetBottom() or 0) - fly:GetHeight()
    if below < 20 then
        fly:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 2)
    else
        fly:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    end
    fly:Show()
end

local function BuildInfoUI()
    if RAA.infoFrame then return RAA.infoFrame end

    local f = CreateFrame("Frame", "RaidReadyInfoFrame", UIParent, "BackdropTemplate")
    f:SetSize(440, 600)
    f:SetPoint("CENTER")
    f:SetMovable(true); f:SetClampedToScreen(true); f:SetFrameStrata("HIGH")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadyInfoFrame")
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)
    -- routes back to whichever side opened it
    addSkinnedHeader(f, "RaidReady", "info", function(k)
        if RAA.infoSide == "raider" then RAA:SwitchRaiderTab(k) else RAA:SwitchLeaderTab(k) end
    end)

    ----------------------------------------------------------------------------
    -- Readiness summary
    ----------------------------------------------------------------------------
    local rdyLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rdyLbl:SetPoint("TOPLEFT", 16, -64)
    rdyLbl:SetText("Raid Readiness")
    rdyLbl:SetTextColor(unpack(C.gold))

    local rdyMax = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rdyMax:SetPoint("TOPRIGHT", -16, -68)
    rdyMax:SetText("/ 1000")

    local rdyPct = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rdyPct:SetPoint("RIGHT", rdyMax, "LEFT", -4, 0)
    f.rdyPct = rdyPct

    local barBg = CreateFlatFrame(f, C.input)
    barBg:SetPoint("TOPLEFT", 16, -86)
    barBg:SetPoint("TOPRIGHT", -16, -86)
    barBg:SetHeight(14)
    barBg:EnableMouse(true)
    local fill = barBg:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(WHITE)
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMLEFT", 2, 2)
    fill:SetWidth(1)
    f.rdyBar, f.rdyFill = barBg, fill

    barBg:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Raid Readiness")
        GameTooltip:AddLine("Only applicable checks are scored.", 0.6, 0.6, 0.6, true)
        for _, p in ipairs(f.rdyParts or {}) do
            if p.score == nil then
                GameTooltip:AddDoubleLine(p.label, p.note or "not scored",
                    0.75, 0.75, 0.75, 0.55, 0.80, 1.00)
            else
                local g = p.score
                local txt = string.format("%d%%", math.floor(g * 100 + 0.5))
                if p.note then txt = txt .. "  (" .. p.note .. ")" end
                GameTooltip:AddDoubleLine(p.label, txt,
                    0.85, 0.85, 0.85, 1 - g * 0.65, 0.35 + g * 0.55, 0.35)
            end
        end
        GameTooltip:Show()
    end)
    barBg:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local panel = CreateFlatFrame(f, C.panel)
    panel:SetPoint("TOPLEFT", 16, -110)
    panel:SetPoint("TOPRIGHT", -16, -110)
    panel:SetHeight(infoPanelHeight())

    f.infoValues, f.infoLabels, f.secHeaders = {}, {}, {}
    local y = -10
    for i, sec in ipairs(INFO_SECTIONS) do
        local sh = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sh:SetPoint("TOPLEFT", 10, y)
        sh:SetText("|cff9fd7ff" .. sec.title .. "|r")
        f.secHeaders[sec.title] = sh
        y = y - INFO_SEC_H
        for _, r in ipairs(sec.rows) do
            local lbl = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT", 22, y)
            lbl:SetText("|cffb0b0b0" .. r.label .. "|r")
            local val = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            val:SetPoint("TOPRIGHT", -12, y)
            val:SetJustifyH("RIGHT")
            f.infoValues[r.key] = val
            f.infoLabels[r.key] = lbl
            y = y - INFO_ROW_H
        end
        if i < #INFO_SECTIONS then y = y - INFO_SEC_GAP end
    end

    ----------------------------------------------------------------------------
    -- Preferred setup per context
    ----------------------------------------------------------------------------
    -- Mismatch banner, sits directly above the preferred-setup controls.
    local warnText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    warnText:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 2, -10)
    warnText:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", -2, -10)
    warnText:SetJustifyH("LEFT")
    warnText:SetWordWrap(true)
    warnText:SetHeight(30)
    f.warnText = warnText

    local prefLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    prefLbl:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, -46)
    f.prefLbl = prefLbl

    local colSet = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    colSet:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 80, -64)
    colSet:SetText("Equipment set")
    local colLoad = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    colLoad:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 220, -64)
    colLoad:SetText("Talent loadout")

    f.prefButtons = {}
    local function addPrefRow(ctx, label, yOff)
        local l = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 4, yOff - 4)
        l:SetText("|cffb0b0b0" .. label .. "|r")

        local setBtn = CreateFlatButton(f, "(none)", 134, 20)
        setBtn:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 78, yOff)
        setBtn:SetScript("OnClick", function()
            ShowChoiceFlyout(setBtn, RAA:GetEquipmentSetNames(), (RAA:GetPreferred(ctx) or {}).set,
                function(v) RAA:SetPreferred(ctx, "set", v); RAA:RefreshInfo() end)
        end)

        local loadBtn = CreateFlatButton(f, "(none)", 134, 20)
        loadBtn:SetPoint("LEFT", setBtn, "RIGHT", 6, 0)
        loadBtn:SetScript("OnClick", function()
            ShowChoiceFlyout(loadBtn, RAA:GetLoadoutNames(), (RAA:GetPreferred(ctx) or {}).loadout,
                function(v) RAA:SetPreferred(ctx, "loadout", v); RAA:RefreshInfo() end)
        end)

        f.prefButtons[ctx] = { set = setBtn, loadout = loadBtn }
    end
    addPrefRow("dungeon", "Dungeon", -80)
    addPrefRow("raid",    "Raid",    -106)

    local refresh = CreateFlatButton(f, "Refresh", 90, 22)
    refresh:SetPoint("BOTTOMRIGHT", -14, 14)
    refresh:SetScript("OnClick", function() RAA:RefreshInfo() end)

    -- Leader-only: query the raid's readiness scores.
    local checkBtn = CreateFlatButton(f, "Check Raid Readiness", 170, 22)
    checkBtn:SetPoint("BOTTOMLEFT", 14, 14)
    checkBtn:SetScript("OnClick", function() RAA:StartReadinessCheck() end)
    f.readinessCheckBtn = checkBtn

    f:Hide()
    RAA.infoFrame = f
    return f
end

function RAA:RefreshInfo(info)
    local f = self.infoFrame
    if not f then return end
    info = info or self:GetCharacterInfo()

    if f.readinessCheckBtn then f.readinessCheckBtn:SetShown(self:CanLeadCheck()) end

    for _, sec in ipairs(INFO_SECTIONS) do
        for _, r in ipairs(sec.rows) do
            local v = f.infoValues[r.key]
            if v then
                v:SetText(info[r.key] or "?")
                v:SetTextColor(1, 1, 1)
            end
        end
    end

    -- Gold row + its section hidden entirely when gold tracking is off.
    local showGold = RaidReadyDB and RaidReadyDB.scoreGold
    if f.infoLabels.gold then f.infoLabels.gold:SetShown(showGold) end
    if f.infoValues.gold then f.infoValues.gold:SetShown(showGold) end
    if f.secHeaders.Resources then f.secHeaders.Resources:SetShown(showGold) end

    -- readiness summary
    f.rdyParts = info.readinessParts
    local score = info.readiness
    if score then
        local frac = score / 1000
        local r, g, b
        if frac >= 0.90 then r, g, b = 0.35, 0.90, 0.45
        elseif frac >= 0.70 then r, g, b = 0.85, 0.85, 0.35
        elseif frac >= 0.50 then r, g, b = 1.00, 0.60, 0.25
        else r, g, b = 1.00, 0.35, 0.35 end
        f.rdyPct:SetText(tostring(score))
        f.rdyPct:SetTextColor(r, g, b)
        f.rdyFill:SetVertexColor(r, g, b, 0.9)
        local w = f.rdyBar:GetWidth()
        if not w or w <= 0 then w = f:GetWidth() - 32 end
        f.rdyFill:SetWidth(math.max(1, (w - 4) * frac))
    else
        f.rdyPct:SetText("n/a")
        f.rdyPct:SetTextColor(0.6, 0.6, 0.6)
        f.rdyFill:SetWidth(1)
    end

    -- gear-check rows are pass/fail regardless of group context
    -- nil = data not available yet (neutral), true = pass, false = fail
    local function tone(key, ok)
        local v = f.infoValues[key]
        if not v then return end
        if ok == nil then
            v:SetTextColor(0.55, 0.80, 1.00)
        elseif ok then
            v:SetTextColor(0.35, 0.90, 0.45)
        else
            v:SetTextColor(1.00, 0.45, 0.25)
        end
    end
    tone("enchants", info.enchantsOk)
    tone("gems", info.gemsOk)

    -- Tier: 4pc green, 2pc yellow (partial bonus), under 2 orange
    local tv = f.infoValues.tier
    if tv then
        if not info.tierComplete then
            tv:SetTextColor(0.55, 0.80, 1.00)
        elseif (info.tierPieces or 0) >= 4 then
            tv:SetTextColor(0.35, 0.90, 0.45)
        elseif (info.tierPieces or 0) >= 2 then
            tv:SetTextColor(0.85, 0.85, 0.35)
        else
            tv:SetTextColor(1.00, 0.45, 0.25)
        end
    end

    -- preferred picker button labels
    for _, ctx in ipairs({ "dungeon", "raid" }) do
        local p = self:GetPreferred(ctx) or {}
        local b = f.prefButtons and f.prefButtons[ctx]
        if b then
            b.set.text:SetText(p.set or "(none)")
            b.loadout.text:SetText(p.loadout or "(none)")
        end
    end

    -- highlight current vs preferred for whichever group we're actually in
    local ctx = self:GroupContext()
    local ctxName = (ctx == "raid" and "Raid") or (ctx == "dungeon" and "Dungeon (party)") or "Solo"
    f.prefLbl:SetText("|cff9fd7ffPreferred setup|r   |cff888888currently: " .. ctxName .. "|r")

    f.warnText:SetText("")
    if ctx then
        local pref = self:GetPreferred(ctx) or {}
        local function mark(key, want, have)
            local v = f.infoValues[key]
            if not (v and want and want ~= "") then return end
            if have == want then
                v:SetTextColor(0.35, 0.9, 0.45)
            else
                v:SetTextColor(1.0, 0.45, 0.25)
                v:SetText((have or "?") .. "  |cffff7d0a(want: " .. want .. ")|r")
            end
        end
        mark("set", pref.set, info.set)
        mark("loadout", pref.loadout, info.loadout)

        -- Banner above the preferred controls, so a mismatch is unmissable.
        local word = (ctx == "raid") and "raid" or "dungeon"
        local wantSet  = pref.set     and pref.set     ~= "" and pref.set     or nil
        local wantLoad = pref.loadout and pref.loadout ~= "" and pref.loadout or nil
        if wantSet or wantLoad then
            local bad = {}
            if wantSet  and info.set     ~= wantSet  then bad[#bad + 1] = "equipment set" end
            if wantLoad and info.loadout ~= wantLoad then bad[#bad + 1] = "talent loadout" end
            if #bad > 0 then
                f.warnText:SetText("|cffff5959!|r |cffff7d0aYou're in a " .. word .. " but your "
                    .. table.concat(bad, " and ") .. (#bad > 1 and " don't" or " doesn't")
                    .. " match your " .. word .. " setup.|r")
            else
                f.warnText:SetText("|cff59e673Your setup matches your " .. word .. " preference.|r")
            end
        end
    end
end

-- side = "leader" | "raider" (controls where the other tabs switch back to)
function RAA:ShowInfo(side)
    BuildInfoUI()
    self.infoSide = side or "leader"
    local others = { self.frame, self.consumeFrame, self.raiderFrame, self.raiderConsumeFrame }
    for i = 1, 4 do
        if others[i] then others[i]:Hide() end
    end
    self.infoFrame:Show()
    self:RefreshInfo()
end

--------------------------------------------------------------------------------
-- Tab switching
--------------------------------------------------------------------------------
function RAA:SwitchLeaderTab(which)
    BuildUI(); BuildConsumeUI(); BuildInfoUI()
    -- whichever leader window is currently up, so the new tab opens in its place
    local from = (self.frame:IsShown() and self.frame)
              or (self.consumeFrame:IsShown() and self.consumeFrame)
              or (self.infoFrame:IsShown() and self.infoFrame) or nil

    if which == "consumables" then
        copyPoint(from, self.consumeFrame)
        self.frame:Hide(); self.infoFrame:Hide()
        self.consumeFrame:Show()
        self:RefreshConsumeConfig(); self:RefreshConsumeResults(); self:UpdateLeaderState()
    elseif which == "info" then
        copyPoint(from, self.infoFrame)
        self:ShowInfo("leader")
        return
    else
        copyPoint(from, self.frame)
        self.consumeFrame:Hide(); self.infoFrame:Hide()
        self.frame:Show()
        self:RefreshRequirements(); self:RefreshResults(); self:UpdateLeaderState()
    end
    self:AutoSizeLeader()
end

function RAA:SwitchRaiderTab(which)
    BuildRaiderView(); BuildRaiderConsume(); BuildInfoUI()
    local from = (self.raiderFrame:IsShown() and self.raiderFrame)
              or (self.raiderConsumeFrame:IsShown() and self.raiderConsumeFrame)
              or (self.infoFrame:IsShown() and self.infoFrame) or nil

    if which == "info" then
        copyPoint(from, self.infoFrame)
        self:ShowInfo("raider")
        return
    end

    if which == "consumables" then
        copyPoint(from, self.raiderConsumeFrame)
        self.infoFrame:Hide()
        if self.lastConsumeKeys and #self.lastConsumeKeys > 0 then
            self:ShowConsumePreview(self.lastConsumeKeys, self.lastConsumeRequester)
        else
            self:ShowConsumeInventory()  -- default: show what's in their bags
        end
    else
        copyPoint(from, self.raiderFrame)
        self.infoFrame:Hide()
        self.raiderConsumeFrame:Hide()
        if self.lastReqMap and next(self.lastReqMap) then
            self:ShowRaiderView(self.lastReqMap, self.lastRequester)
        else
            self.raiderFrame.sub:SetText("|cff888888No addon check has been run yet.|r")
            HideExtraRows(self.raiderFrame.rows, 1)
            self.raiderFrame.scroll.content:SetHeight(1)
            self.raiderFrame:Show()
        end
    end
end

--------------------------------------------------------------------------------
-- Standalone readiness bar + ready-check warning
--------------------------------------------------------------------------------
local function scoreColor(frac)
    if frac >= 0.90 then return 0.35, 0.90, 0.45 end
    if frac >= 0.70 then return 0.85, 0.85, 0.35 end
    if frac >= 0.50 then return 1.00, 0.60, 0.25 end
    return 1.00, 0.35, 0.35
end

local function BuildScoreBar()
    if RAA.scoreBar then return RAA.scoreBar end

    local f = CreateFrame("Button", "RaidReadyScoreBar", UIParent, "BackdropTemplate")
    f:SetSize(180, 26)
    local p = (RaidReadyDB and RaidReadyDB.barPos) or {}
    f:SetPoint(p.point or "CENTER", UIParent, p.point or "CENTER", p.x or 0, p.y or -220)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:SetFrameStrata("MEDIUM")
    Skin(f, C.bg)
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)

    local fill = f:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(WHITE)
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMLEFT", 2, 2)
    fill:SetWidth(1)
    fill:SetAlpha(0.30)
    f.fill = fill

    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16); icon:SetPoint("LEFT", 5, 0)
    icon:SetTexture("Interface\\AddOns\\nugsRaidReady\\icon"); icon:SetTexCoord(0, 1, 0, 1)

    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    label:SetText("Ready")
    label:SetTextColor(unpack(C.text))

    local score = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    score:SetPoint("RIGHT", -8, 0)
    f.scoreText = score

    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(s)
        if RaidReadyDB and RaidReadyDB.barLocked then return end
        s:StartMoving()
    end)
    f:SetScript("OnDragStop", function(s)
        s:StopMovingOrSizing()
        local point, _, _, x, y = s:GetPoint(1)
        if RaidReadyDB then RaidReadyDB.barPos = { point = point, x = x, y = y } end
    end)
    f:SetScript("OnClick", function()
        RAA:ShowInfo(RAA:CanLeadCheck() and "leader" or "raider")
    end)
    f:SetScript("OnEnter", function(s)
        GameTooltip:SetOwner(s, "ANCHOR_TOP")
        GameTooltip:AddLine("Raid Readiness")
        for _, part in ipairs(s.parts or {}) do
            if part.score == nil then
                GameTooltip:AddDoubleLine(part.label, part.note or "not scored",
                    0.75, 0.75, 0.75, 0.55, 0.80, 1.00)
            else
                local g = part.score
                local txt = string.format("%d%%", math.floor(g * 100 + 0.5))
                if part.note then txt = txt .. "  (" .. part.note .. ")" end
                GameTooltip:AddDoubleLine(part.label, txt, 0.85, 0.85, 0.85,
                    1 - g * 0.65, 0.35 + g * 0.55, 0.35)
            end
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click to open. Drag to move (unlock in settings).", 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Updates are event-driven; this slow poll is only a safety net for things
    -- that fire no event (e.g. socket data becoming readable after you hover gear).
    f:SetScript("OnUpdate", function(s, e)
        s.elapsed = (s.elapsed or 0) + e
        if s.elapsed >= 30 then
            s.elapsed = 0
            RAA:UpdateScoreBar()
        end
    end)

    RAA.scoreBar = f
    return f
end

function RAA:UpdateScoreBar(info)
    local f = self.scoreBar
    if not (f and f:IsShown()) then return end
    info = info or self:GetCharacterInfo()
    f.parts = info.readinessParts
    local s = info.readiness
    if s then
        local frac = s / 1000
        local r, g, b = scoreColor(frac)
        f.scoreText:SetText(tostring(s))
        f.scoreText:SetTextColor(r, g, b)
        f.fill:SetVertexColor(r, g, b)
        f.fill:SetWidth(math.max(1, (f:GetWidth() - 4) * frac))
    else
        f.scoreText:SetText("--")
        f.scoreText:SetTextColor(0.6, 0.6, 0.6)
        f.fill:SetWidth(1)
    end
end

function RAA:SetScoreBarShown(shown)
    local f = BuildScoreBar()
    if shown then
        f:Show()
        self:UpdateScoreBar()
    else
        f:Hide()
    end
end

-- Recompute readiness once and push it to whatever's visible (panel + bar share
-- the one snapshot so the tooltip scan only runs once).
function RAA:RefreshReadiness()
    local panel = self.infoFrame and self.infoFrame:IsShown()
    local bar   = self.scoreBar and self.scoreBar:IsShown()
    if not (panel or bar) then return end
    local info = self:GetCharacterInfo()
    if panel then self:RefreshInfo(info) end
    if bar   then self:UpdateScoreBar(info) end
end

-- Debounced: gear/bag events fire in bursts, so coalesce into one recompute.
local readinessPending
function RAA:ScheduleReadiness()
    if readinessPending then return end
    readinessPending = true
    C_Timer.After(0.6, function()
        readinessPending = false
        RAA:RefreshReadiness()
    end)
end

function RAA:InitReadinessEvents()
    if self._readinessEvents then return end
    local fr = CreateFrame("Frame")
    self._readinessEvents = fr
    -- Anything that can move the score. pcall each in case an event name isn't
    -- valid on this client (RegisterEvent errors on unknown names).
    for _, e in ipairs({
        "BAG_UPDATE_DELAYED",           -- consumables
        "PLAYER_EQUIPMENT_CHANGED",     -- ilvl, enchants, tier, empowerment, set
        "UPDATE_INVENTORY_DURABILITY",  -- durability
        "PLAYER_MONEY",                 -- gold
        "PLAYER_SPECIALIZATION_CHANGED",
        "TRAIT_CONFIG_UPDATED",         -- talent loadout
        "ACTIVE_PLAYER_SPECIALIZATION_CHANGED",
        "EQUIPMENT_SETS_CHANGED",       -- equipment manager
        "GROUP_ROSTER_UPDATE",          -- context (solo/party/raid)
        "PLAYER_ENTERING_WORLD",
    }) do
        pcall(function() fr:RegisterEvent(e) end)
    end
    fr:SetScript("OnEvent", function() RAA:ScheduleReadiness() end)
end

-- Popup shown to the player on a ready check when their score is too low.
local function BuildRCWarning()
    if RAA.rcFrame then return RAA.rcFrame end

    local f = CreateFrame("Frame", "RaidReadyWarningFrame", UIParent, "BackdropTemplate")
    f:SetSize(320, 190)
    f:SetPoint("CENTER", 0, 160)
    f:SetMovable(true); f:SetClampedToScreen(true); f:SetFrameStrata("DIALOG")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadyWarningFrame")
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)

    local header = CreateFlatFrame(f, C.header)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(28)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    addAccentBar(header)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0)
    title:SetText("Not raid ready")
    title:SetTextColor(1.0, 0.45, 0.25)
    local close = CreateFlatButton(header, "x", 22, 18)
    close:SetPoint("RIGHT", -6, 0); close:SetScript("OnClick", function() f:Hide() end)

    local big = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    big:SetPoint("TOP", 0, -40)
    f.big = big

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sub:SetPoint("TOP", big, "BOTTOM", 0, -4)
    f.sub = sub

    f.lines = {}
    for i = 1, 12 do
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 20, -88 - (i - 1) * 18)
        fs:SetPoint("TOPRIGHT", -20, -88 - (i - 1) * 18)
        fs:SetJustifyH("LEFT")
        f.lines[i] = fs
    end

    local ok = CreateFlatButton(f, "Got it", 90, 22)
    ok:SetPoint("BOTTOM", 0, 12)
    ok:SetScript("OnClick", function() f:Hide() end)

    f:Hide()
    RAA.rcFrame = f
    return f
end

function RAA:ShowReadyCheckWarning(score, threshold, parts)
    local f = BuildRCWarning()
    local r, g, b = scoreColor(score / 1000)
    f.big:SetText(score .. " / 1000")
    f.big:SetTextColor(r, g, b)
    f.sub:SetText("below your " .. threshold .. " threshold")

    -- Only the checks actually dragging the score down; anything at 100% is hidden.
    local bad = {}
    for _, p in ipairs(parts or {}) do
        if p.score and p.score < 1 then bad[#bad + 1] = p end
    end
    table.sort(bad, function(a, b) return a.score < b.score end)

    local shown = math.min(#bad, #f.lines)
    for i = 1, #f.lines do
        local p = bad[i]
        if p and i <= shown then
            f.lines[i]:SetText(string.format("|cffff7d0a%s|r  |cff888888%s|r",
                p.label, p.note or (math.floor(p.score * 100 + 0.5) .. "%")))
            f.lines[i]:Show()
        else
            f.lines[i]:SetText("")
            f.lines[i]:Hide()
        end
    end

    -- Size the box to the number of issues (min 1 row so it never collapses).
    f:SetHeight(88 + math.max(1, shown) * 18 + 44)
    f:Show()
end

--------------------------------------------------------------------------------
-- Leader readiness roster: each raider's score number, class-coloured, low first.
--------------------------------------------------------------------------------
local function BuildReadinessRoster()
    if RAA.readinessFrame then return RAA.readinessFrame end

    local f = CreateFrame("Frame", "RaidReadyReadinessFrame", UIParent, "BackdropTemplate")
    f:SetSize(280, 340)
    f:SetPoint("CENTER")
    f:SetMovable(true); f:SetClampedToScreen(true); f:SetFrameStrata("HIGH")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadyReadinessFrame")
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)
    f:SetScript("OnHide", function(s) s.userMoved = nil end)

    local header = CreateFlatFrame(f, C.header)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(28)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f.userMoved = true; f:SetClampedToScreen(true) end)
    addAccentBar(header)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", 12, 0); title:SetText("Raid Readiness"); title:SetTextColor(unpack(C.gold))
    local close = CreateFlatButton(header, "x", 22, 18)
    close:SetPoint("RIGHT", -6, 0); close:SetScript("OnClick", function() f:Hide() end)

    local summary = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    summary:SetPoint("TOPLEFT", 14, -36)
    f.rdySummary = summary

    local panel = CreateFlatFrame(f, C.panel)
    panel:SetPoint("TOPLEFT", 12, -56); panel:SetPoint("BOTTOMRIGHT", -12, 14)
    local scroll = CreateScrollList(panel, 252, 260)
    scroll:SetPoint("TOPLEFT", 3, -3); scroll:SetPoint("BOTTOMRIGHT", -3, 3)
    f.rdyScroll = scroll
    f.rdyRows = {}

    f:Hide()
    RAA.readinessFrame = f
    return f
end

function RAA:ShowReadinessRoster()
    local f = BuildReadinessRoster()
    f:Show()
    dockBeside(f, false)
    self:RefreshReadinessRoster()
end

function RAA:RefreshReadinessRoster()
    local f = self.readinessFrame
    if not (f and f:IsShown()) then return end
    local session = self.readinessSession
    local content = f.rdyScroll.content
    local width = f.rdyScroll:GetWidth()
    if not session then HideExtraRows(f.rdyRows, 1); return end

    local list = {}
    for _, r in pairs(session.results) do list[#list + 1] = r end
    -- Lowest score first so problems are at the top; pending/offline sink below.
    table.sort(list, function(a, b)
        local sa = a.score or (a.status == "offline" and 1e9 or 1e8)
        local sb = b.score or (b.status == "offline" and 1e9 or 1e8)
        if sa ~= sb then return sa < sb end
        return (a.display or "") < (b.display or "")
    end)

    local y, reporting, sum = 0, 0, 0
    for i, r in ipairs(list) do
        local row = AcquireRow(f.rdyRows, content, i, false)
        row:SetPoint("TOPLEFT", 0, y); row:SetWidth(width); row.btn:Hide()
        row.left:SetText("|c" .. classColorHex(r.class) .. (r.display or "?") .. "|r")
        row.right:Show()
        if r.score then
            local rr, gg, bb = scoreColor(r.score / 1000)
            row.right:SetText(tostring(r.score)); row.right:SetTextColor(rr, gg, bb)
            reporting = reporting + 1; sum = sum + r.score
        elseif r.status == "offline" then
            row.right:SetText("offline"); row.right:SetTextColor(0.5, 0.5, 0.5)
        elseif r.status == "noaddon" then
            row.right:SetText("no addon"); row.right:SetTextColor(0.95, 0.45, 0.95)
        else
            row.right:SetText("..."); row.right:SetTextColor(0.8, 0.8, 0.8)
        end
        y = y - 18
    end
    HideExtraRows(f.rdyRows, #list + 1)
    content:SetHeight(math.max(1, #list * 18))
    f.rdySummary:SetText(reporting > 0
        and ("avg " .. math.floor(sum / reporting + 0.5) .. " / 1000   (" .. reporting .. " reporting)")
        or "waiting for replies...")
end

--------------------------------------------------------------------------------
-- Gold-tracking consent dialogs
--------------------------------------------------------------------------------
local GOLD_BLURB = "RaidReady reads your gold |cffffffffonly|r to factor a repair "
    .. "buffer into your readiness score. It is never stored elsewhere or shared "
    .. "with anyone."

local function applyGoldSetting(on)
    if RaidReadyDB then RaidReadyDB.scoreGold = on end
    if RAA.settingsFrame and RAA.settingsFrame.goldCheck then
        RAA.settingsFrame.goldCheck:SetChecked(on)
    end
    RAA:RefreshReadiness()
    if RAA.infoFrame then RAA:RefreshInfo() end
end

StaticPopupDialogs["RAIDREADY_GOLD_OPTIN"] = {
    text = "Track gold toward your RaidReady readiness score?\n\n" .. GOLD_BLURB,
    button1 = YES, button2 = NO,
    OnAccept = function() applyGoldSetting(true);  if RaidReadyDB then RaidReadyDB.introDone = true end end,
    OnCancel = function() applyGoldSetting(false); if RaidReadyDB then RaidReadyDB.introDone = true end end,
    timeout = 0, whileDead = true, hideOnEscape = false, preferredIndex = 3,
}

StaticPopupDialogs["RAIDREADY_GOLD_CONFIRM"] = {
    text = "Enable gold tracking?\n\n" .. GOLD_BLURB,
    button1 = OKAY, button2 = CANCEL,
    OnAccept = function() applyGoldSetting(true) end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
}

-- Shown once, on first ever login.
function RAA:ShowGoldOptIn()
    StaticPopup_Show("RAIDREADY_GOLD_OPTIN")
end

--------------------------------------------------------------------------------
-- Settings (minimap toggle + UI scale)
--------------------------------------------------------------------------------
local function BuildSettings()
    if RAA.settingsFrame then return RAA.settingsFrame end

    local f = CreateFrame("Frame", "RaidReadySettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(360, 448)
    f:SetPoint("CENTER")
    f:SetMovable(true); f:EnableMouse(true); f:SetClampedToScreen(true)
    f:SetFrameStrata("DIALOG")
    Skin(f, C.bg)
    table.insert(UISpecialFrames, "RaidReadySettingsFrame")
    f:SetScale((RaidReadyDB and RaidReadyDB.uiScale) or 1)
    -- Closing forgets a manual drag, so reopening re-docks beside the main window.
    f:SetScript("OnHide", function(s) s.userMoved = nil end)

    -- header
    local header = CreateFlatFrame(f, C.header)
    header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(30)
    header:EnableMouse(true); header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing(); f.userMoved = true; f:SetClampedToScreen(true) end)
    addAccentBar(header)
    local hicon = header:CreateTexture(nil, "OVERLAY")
    hicon:SetSize(18, 18); hicon:SetPoint("LEFT", 10, 0)
    hicon:SetTexture("Interface\\AddOns\\nugsRaidReady\\icon"); hicon:SetTexCoord(0, 1, 0, 1)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("LEFT", hicon, "RIGHT", 8, 0); title:SetText(TITLE_TEXT); title:SetTextColor(unpack(C.gold))
    local close = CreateFlatButton(header, "x", 22, 18)
    close:SetPoint("RIGHT", -6, 0); close:SetScript("OnClick", function() f:Hide() end)

    -- Display section
    local sec = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sec:SetPoint("TOPLEFT", 16, -44); sec:SetText("|cff9fd7ffDisplay|r")

    local mm = CreateFlatCheck(f, "Show minimap button")
    mm:SetPoint("TOPLEFT", 20, -66)
    mm.onToggle = function(checked)
        if RaidReadyDB then RaidReadyDB.minimapHidden = not checked end
        if RAA.SetMinimapShown then RAA:SetMinimapShown(checked) end
    end
    f.minimapCheck = mm

    local scaleLbl = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    scaleLbl:SetPoint("TOPLEFT", 20, -96); scaleLbl:SetText("UI Scale (all windows)")

    local sl = CreateFrame("Slider", "RaidReadyScaleSlider", f, "OptionsSliderTemplate")
    sl:SetPoint("TOPLEFT", 24, -118)
    sl:SetWidth(266)
    sl:SetMinMaxValues(0.75, 2.0)
    sl:SetValueStep(0.05)
    sl:SetObeyStepOnDrag(true)
    _G["RaidReadyScaleSliderLow"]:SetText("75%")
    _G["RaidReadyScaleSliderHigh"]:SetText("200%")
    sl:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v * 20 + 0.5) / 20
        if RaidReadyDB then RaidReadyDB.uiScale = v end
        _G["RaidReadyScaleSliderText"]:SetText(string.format("%d%%", math.floor(v * 100 + 0.5)))
        RAA:ApplyScale()
    end)
    f.scaleSlider = sl

    -- Readiness bar section
    local secBar = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secBar:SetPoint("TOPLEFT", 16, -150)
    secBar:SetText("|cff9fd7ffReadiness bar|r")

    local barShow = CreateFlatCheck(f, "Show readiness bar")
    barShow:SetPoint("TOPLEFT", 20, -172)
    barShow.onToggle = function(checked)
        if RaidReadyDB then RaidReadyDB.barShown = checked end
        if RAA.SetScoreBarShown then RAA:SetScoreBarShown(checked) end
    end
    f.barShow = barShow

    local barLock = CreateFlatCheck(f, "Lock bar position")
    barLock:SetPoint("TOPLEFT", 20, -194)
    barLock.onToggle = function(checked)
        if RaidReadyDB then RaidReadyDB.barLocked = checked end
    end
    f.barLock = barLock

    -- Ready check section
    local secRC = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secRC:SetPoint("TOPLEFT", 16, -222)
    secRC:SetText("|cff9fd7ffReady check|r")

    local rcLbl = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    rcLbl:SetPoint("TOPLEFT", 20, -246)
    rcLbl:SetText("Minimum score (of 1000)")

    local rcBox = CreateFlatEditBox(f, 60, 20)
    rcBox:SetPoint("TOPLEFT", 230, -242)
    rcBox:SetNumeric(true)
    rcBox:SetScript("OnTextChanged", function(s)
        local v = tonumber(s:GetText())
        if v and v >= 0 and RaidReadyDB then RaidReadyDB.rcThreshold = v end
    end)
    f.rcBox = rcBox

    local rcPopup = CreateFlatCheck(f, "Warn me if I'm below it")
    rcPopup:SetPoint("TOPLEFT", 20, -270)
    rcPopup.onToggle = function(checked)
        if RaidReadyDB then RaidReadyDB.rcPopup = checked end
    end
    f.rcPopup = rcPopup

    local rcWhisper = CreateFlatCheck(f, "Whisper raiders below it (leader)")
    rcWhisper:SetPoint("TOPLEFT", 20, -292)
    rcWhisper.onToggle = function(checked)
        if RaidReadyDB then RaidReadyDB.rcWhisper = checked end
    end
    f.rcWhisper = rcWhisper

    -- Scoring section
    local secScore = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    secScore:SetPoint("TOPLEFT", 16, -318)
    secScore:SetText("|cff9fd7ffScoring|r")

    local goldCheck = CreateFlatCheck(f, "Count gold toward readiness")
    goldCheck:SetPoint("TOPLEFT", 20, -340)
    goldCheck.onToggle = function(checked)
        if checked then
            -- confirm before enabling; revert the tick until they accept
            goldCheck:SetChecked(false)
            StaticPopup_Show("RAIDREADY_GOLD_CONFIRM")
        else
            applyGoldSetting(false)
        end
    end
    f.goldCheck = goldCheck

    -- divider
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetTexture(WHITE); div:SetVertexColor(1, 1, 1, 0.08)
    div:SetPoint("TOPLEFT", 14, -368); div:SetPoint("TOPRIGHT", -14, -368); div:SetHeight(1)

    -- footer / branding
    local ver = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ver:SetPoint("TOPLEFT", 16, -384)
    ver:SetText("nugsRaidReady  |cff9fd7ffv" .. (RAA.version or "?") .. "|r")

    local dev = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dev:SetPoint("TOPLEFT", 16, -404); dev:SetText("Developed by nugs")

    local cr = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    cr:SetPoint("TOPLEFT", 16, -420)
    cr:SetText("|cff777777(c) 2026 nugs. All Rights Reserved.|r")

    -- Shown only when nugsSuite is absent. _G.nugsSuite is the suite's own handle,
    -- so this also reads correctly when it is installed but switched off - a
    -- disabled suite is no more use than a missing one.
    --
    -- A note, never a warning, and never a dependency: this addon works perfectly
    -- well on its own and the suite is only worth having once you run more than one.
    if not _G.nugsSuite then
        local suite = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        suite:SetPoint("TOPLEFT", 16, -440)
        suite:SetText("Part of the |cff8cd2ffnugs suite|r")
        -- The panel is laid out in absolute offsets from the top with no bottom
        -- bar, so it has to grow to make room rather than tuck this in underneath.
        f:SetHeight(468)
    end

    f:Hide()
    RAA.settingsFrame = f
    return f
end

function RAA:ToggleSettings()
    local f = BuildSettings()
    if f:IsShown() then f:Hide(); return end
    f.minimapCheck:SetChecked(not (RaidReadyDB and RaidReadyDB.minimapHidden))
    f.barShow:SetChecked(RaidReadyDB and RaidReadyDB.barShown)
    f.barLock:SetChecked(RaidReadyDB and RaidReadyDB.barLocked)
    f.rcBox:SetText(tostring((RaidReadyDB and RaidReadyDB.rcThreshold) or 700))
    f.rcPopup:SetChecked(RaidReadyDB and RaidReadyDB.rcPopup)
    f.rcWhisper:SetChecked(RaidReadyDB and RaidReadyDB.rcWhisper)
    f.goldCheck:SetChecked(RaidReadyDB and RaidReadyDB.scoreGold)
    local scale = (RaidReadyDB and RaidReadyDB.uiScale) or 1
    f.scaleSlider:SetValue(scale)
    _G["RaidReadyScaleSliderText"]:SetText(string.format("%d%%", math.floor(scale * 100 + 0.5)))
    -- Match the other windows. Applied on open rather than live, so dragging the
    -- slider inside this window doesn't rescale it out from under the cursor.
    f:SetScale(scale)
    f:Show()
    dockBeside(f, false)
end

-- Apply the saved UI scale to all RaidReady windows (not the settings panel).
function RAA:ApplyScale()
    local s = (RaidReadyDB and RaidReadyDB.uiScale) or 1
    -- numeric loop: some frames may be nil, which would stop ipairs early
    local frames = { self.frame, self.consumeFrame, self.raiderFrame, self.raiderConsumeFrame,
                     self.infoFrame, self.scoreBar, self.rcFrame, self.readinessFrame }
    for i = 1, #frames do
        if frames[i] then frames[i]:SetScale(s) end
    end
end

--------------------------------------------------------------------------------
-- Auto-size the leader window's results area to the current group size, so a
-- full 20-person raid shows without scrolling (and small groups stay compact).
--------------------------------------------------------------------------------
function RAA:AutoSizeLeader()
    local rows = groupRows()
    if self.frame and self.frame:IsShown() then
        fitRows(self.frame, self.frame.resScroll, rows)
    end
    if self.consumeFrame and self.consumeFrame:IsShown() then
        fitRows(self.consumeFrame, self.consumeFrame.consumeResScroll, rows)
    end
end

--------------------------------------------------------------------------------
-- Public show/hide
--------------------------------------------------------------------------------
function RAA:ShowUI()
    BuildUI()
    -- addon tab is the active view
    if self.consumeFrame then self.consumeFrame:Hide() end
    if self.infoFrame then self.infoFrame:Hide() end
    self.frame:Show()
    self:RefreshRequirements()
    self:RefreshResults()
    self:UpdateLeaderState()
    self:AutoSizeLeader()
end

function RAA:ToggleUI()
    BuildUI()
    if self.frame:IsShown() or (self.consumeFrame and self.consumeFrame:IsShown())
       or (self.infoFrame and self.infoFrame:IsShown()) then
        self.frame:Hide()
        if self.consumeFrame then self.consumeFrame:Hide() end
        if self.infoFrame then self.infoFrame:Hide() end
    else
        self:ShowUI()
    end
end
