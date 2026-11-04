-- Turning EraUI off cleanly for this character: the earlier Edit Mode
-- layout made active again and every game setting EraUI changed put back
-- (the hand-back), then the addon disabled for this character and the
-- interface reloaded. The engine also runs the hand-back at logout when
-- EraUI was disabled in the AddOns list.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Lay = Look.Layout

local OFF_POPUP = "ERAUI_CLASSIC_TURN_OFF"

-- This character as the game's AddOns list names it: its GUID, else the
-- whole name (first name and surname; never the first name alone).
local function Character()
    local asked, guid = pcall(UnitGUID, "player")
    if asked and not Look.Secret(guid) and type(guid) == "string" and guid ~= "" then return guid end
    if type(EraUI.PlayerFullName) ~= "function" then return nil end
    local fine, whole = pcall(EraUI.PlayerFullName, EraUI)
    if fine and type(whole) == "string" and not Look.Secret(whole) then return whole end
    return nil
end

local function Folder()
    return ns.ADDON or "EraUI"
end

-- Disabled for this character in the AddOns list (the next load is off).
local function OffNextLoad()
    local addons = C_AddOns
    if type(addons) ~= "table" or type(addons.GetAddOnEnableState) ~= "function" then return false end
    local fine, state = pcall(addons.GetAddOnEnableState, Folder(), Character())
    return fine and not Look.Secret(state) and state == 0
end

-- Every game setting back as it was before EraUI first wrote it, through
-- the engine's guarded writer (which records nothing new while handing
-- back), else the game's own.
local function SettingsBack(saved)
    local before = saved and saved.cvarWas
    if type(before) ~= "table" then return end
    local cvars = C_CVar
    local write = (type(ns.SetCVar) == "function" and ns.SetCVar) or (type(cvars) == "table" and cvars.SetCVar) or nil
    for name, value in pairs(before) do
        if write then Look.Try(write, name, value) end
    end
    saved.cvarWas = nil
end

local function GiveBack()
    ns.handingBack = true
    local saved, api = ns.db, C_EditMode
    if Lay.Ours() and Lay.Manager() and type(api) == "table" and type(api.SetActiveLayout) == "function" then
        local earlier = saved and saved.previousLayout
        local index = (type(earlier) == "string" and earlier ~= "" and Lay.Find(earlier)) or 1
        if Look.Try(api.SetActiveLayout, index) and saved then saved.layoutSelectPending = true end
    end
    SettingsBack(saved)
end

local function OffNow()
    if Look.InFight() then return Lay.Say("Turning EraUI off has to wait until you're out of a fight.") end
    local addons = C_AddOns
    if type(addons) ~= "table" or type(addons.DisableAddOn) ~= "function" then return end
    Look.Try(addons.DisableAddOn, Folder(), Character())
    Look.Try(GiveBack)
    local ui = C_UI
    if type(ui) == "table" and type(ui.Reload) == "function" then ui.Reload() elseif ReloadUI then ReloadUI() end
end

if type(StaticPopupDialogs) == "table" then
    StaticPopupDialogs[OFF_POPUP] = {
        text = "EraUI: turn the addon off for this character? Your earlier Edit Mode layout comes back and the game settings EraUI changed go back to yours. The interface reloads, and you can turn EraUI on again from the AddOns list.",
        button1 = "Turn off", button2 = CANCEL or "Cancel",
        OnAccept = function() OffNow() end,
        timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end

function Lay.AskTurnOff()
    if StaticPopup_Show then StaticPopup_Show(OFF_POPUP) end
end

ns.BeingTurnedOff, ns.HandBack, ns.TurnOffCleanly = OffNextLoad, GiveBack, OffNow
