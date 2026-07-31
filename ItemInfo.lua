--------------------------------------------------------------------------------
-- RaidReady
-- Copyright (c) 2026 nugs. All Rights Reserved.
-- Unauthorized copying, distribution, or modification is prohibited. See LICENSE.
--------------------------------------------------------------------------------
-- RaidReady  -  ItemInfo.lua
-- A verification helper: toggle with "/rr ids" to add the item ID to every item
-- tooltip. Used to capture exact consumable item IDs (including each rank) when
-- building the Raid Consumables preset lists.
local ADDON_NAME, RAA = ...

local enabled = false
local hooked = false

local function ensureHook()
    if hooked then return end
    hooked = true
    -- Modern retail tooltip hook (Enum.TooltipDataType.Item), 10.0.2+.
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
       and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if not enabled then return end
            if tooltip == GameTooltip and data and data.id then
                tooltip:AddLine("|cff33ff99RaidReady|r  itemID: |cffffffff" .. data.id .. "|r")
            end
        end)
    end
end

-- Discovery helper for loadout-manager addons (Talent Loadout Ex etc.).
-- Reads the addon's own .toc SavedVariables declaration, then dumps those
-- globals' top-level keys so we can find where the active loadout is stored.
function RAA:ScanLoadoutAddon()
    local GetNumAddOns     = (C_AddOns and C_AddOns.GetNumAddOns)     or _G.GetNumAddOns
    local GetAddOnInfo     = (C_AddOns and C_AddOns.GetAddOnInfo)     or _G.GetAddOnInfo
    local GetAddOnMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata

    local matches = {}
    for i = 1, (GetNumAddOns() or 0) do
        local folder = GetAddOnInfo(i)
        if folder and (folder:lower():find("talent", 1, true) or folder:lower():find("loadout", 1, true)) then
            matches[#matches + 1] = folder
        end
    end
    if #matches == 0 then
        print("|cff33ff99RaidReady|r: no installed addon with 'talent' or 'loadout' in its folder name.")
        return
    end

    for _, folder in ipairs(matches) do
        print("|cff33ff99RaidReady|r addon: |cffffffff" .. folder .. "|r")
        for _, metaKey in ipairs({ "SavedVariables", "SavedVariablesPerCharacter" }) do
            local sv = GetAddOnMetadata(folder, metaKey)
            if sv and sv ~= "" then
                print("   " .. metaKey .. ": " .. sv)
                for globalName in sv:gmatch("[^,%s]+") do
                    local v = _G[globalName]
                    print("     " .. globalName .. " = " .. type(v))
                    if type(v) == "table" then
                        local n = 0
                        for k, vv in pairs(v) do
                            n = n + 1
                            if n <= 15 then
                                local extra = ""
                                if type(vv) == "string" or type(vv) == "number" then
                                    extra = " = " .. tostring(vv)
                                end
                                print("        ." .. tostring(k) .. " (" .. type(vv) .. ")" .. extra)
                            end
                        end
                        if n > 15 then print("        ... " .. n .. " keys total") end
                    end
                end
            end
        end
    end
    print("|cff33ff99RaidReady|r: paste this output back so the active loadout can be wired up.")
end

function RAA:ToggleItemIDs()
    ensureHook()
    enabled = not enabled
    print("|cff33ff99RaidReady|r: item IDs on tooltips are now "
        .. (enabled and "|cff59e673ON|r - hover any item to see its ID." or "|cffff5959OFF|r."))
end
