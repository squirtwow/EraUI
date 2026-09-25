local ADDON_NAME, EraUI = ...
_G.EraUI = EraUI

EraUI.name = ADDON_NAME
EraUI.version = "1.0.2"
EraUI.modules = {}
EraUI.callbacks = {}
EraUI.moduleResults = {}

local defaults = {
    profile = "EraPlus",
    classicChatDragging = false,
    cursorRing = false,
    cursorRingClassColour = false,
    cursorRingSize = 48,
    cursorRingThickness = 2,
    darkMode = false,
    floatingComboPoints = false,
    comboPointRed = false,
    energyBar = false,
    classReminders = false,
    hunterFeed = false,
    mageSupplies = false,
    mageAutoTrade = false,
    roguePoisons = false,
    poisonReminders = false,
    advancedCastBar = false,
    advancedCastClassFill = false,
    advancedCastLatency = true,
    advancedCastTicks = true,
    castBarClassBorder = false,
    rageBar = false,
    manaBar = false,
    druidResourceBar = false,
    rangedSwingTimer = false,
    swingTimer = false,
    classColourBorders = false,
    enabled = true,
    actionBars = true,
    hideEmptyActionSlots = false,
    hideSecondaryNames = false,
    gryphons = true,
    minimap = true,
    unitFrames = true,
    friendlyNameplates = true,
    enemyNameplates = true,
    disableAggroHighlight = false,
    lootWindow = true,
    castBars = true,
    characterPanel = true,
    professions = true,
    spellbook = true,
    spellbookCombatDrag = true,
    questDialogs = true,
    classicDialogs = true,
    socialWindows = true,
    talentWindow = true,
    questTracker = true,
    trainer = true,
    gameMenu = true,
    popups = true,
    coordinates = false,
    fastAutoLoot = false,
    autoQuests = false,
    mapQuestObjectives = true,
    movableMap = true,
    revealMap = false,
    rewardUpgradeHighlight = false,
    autoSummon = false,
    autoResurrect = false,
    releasePvP = false,
    blockDuels = false,
    blockPartyInvites = false,
    partyFromFriends = false,
    inviteFromWhispers = false,
    hideKeybindText = false,
    hideMacroText = false,
    hideZoneText = false,
    maxCameraZoom = false,

    autoGossip = false,
    durabilityWarning = false,
    tooltipIDs = false,
    junkValueSummary = false,
    showWelcomeOnLogin = false,
    matchFocusSize = true,
    questLog = true,
    bagsBank = true,
    merchantSkin = true,
    mailSkin = true,
    auctionHouse = true,
    groupFinderPvp = true,
    blizzardSettings = true,
    tooltipSkin = false,
    contextMenus = false,
    cleanMinimap = false,
    autoSellJunk = false,
    autoRepair = false,
    vendorPrice = true,
    questLevels = true,
    bagSpace = true,
    classColors = true,
    hideStatusMessages = true,
}

-- Visual choices are staged for the next UI load. Live modules keep a coherent
-- presentation until then; disabling never tries to undo protected hooks.
EraUI.reloadSettings = {}
for _, key in ipairs({"classicChatDragging", "floatingComboPoints", "classColourBorders", "darkMode", "actionBars", "minimap", "unitFrames", "castBars", "characterPanel",
    "friendlyNameplates", "enemyNameplates", "disableAggroHighlight", "lootWindow", "matchFocusSize",
    "professions", "trainer", "spellbook", "spellbookCombatDrag", "questDialogs", "questTracker",
    "classicDialogs", "gameMenu", "popups", "socialWindows", "talentWindow",
    "questLog", "bagsBank", "merchantSkin", "mailSkin", "auctionHouse",
    "groupFinderPvp", "blizzardSettings", "tooltipSkin", "contextMenus"}) do
    EraUI.reloadSettings[key] = true
end
EraUI.settingDefaults = defaults

function EraUI:GetSavedSetting(key)
    if key == "showAllSpellRanks" and GetCVarBool then return GetCVarBool("ShowAllSpellRanks") end
    return EraUIDB and EraUIDB[key]
end

local function ApplyDefaults(target, source)
    for key, value in pairs(source) do
        if target[key] == nil then
            target[key] = value
        elseif type(value) == "table" and type(target[key]) == "table" then
            ApplyDefaults(target[key], value)
        end
    end
end

function EraUI:RegisterModule(name, module)
    module.name = name
    self.modules[name] = module
end

function EraUI:Print(message)
    local prefix = "|cffd8b25cEraUI:|r "
    DEFAULT_CHAT_FRAME:AddMessage(prefix .. tostring(message))
end

function EraUI:Status(message)
    if self:GetSetting("hideStatusMessages") then return end
    self:Print(message)
end

function EraUI:GetSetting(key)
    if self.loadedVisualSettings and self.reloadSettings[key] then
        return self.loadedVisualSettings[key]
    end
    return self:GetSavedSetting(key)
end

function EraUI:SetSetting(key, value)
    EraUIDB = EraUIDB or {}
    EraUIDB[key] = value
    if key == "advancedCastBar" and not value then
        EraUIDB.advancedCastTicks = false
        EraUIDB.advancedCastLatency = false
    end
end

-- Per-character swing timer settings. The Forever client does not reliably
-- restore per-character SavedVariables, so these toggles live in a CVar
-- keyed by character name + realm, the same way the onboarding state does.
EraUI.charSettingKeys = { swingTimer = true, rangedSwingTimer = true }
local CHAR_SETTING_CVAR = "EraUICharSwing"
if C_CVar and C_CVar.RegisterCVar then
    pcall(C_CVar.RegisterCVar, CHAR_SETTING_CVAR, "")
end

local function CharSettingKey()
    if UnitFullName then
        local ok, name = pcall(UnitFullName, "player")
        if ok and name and not (issecretvalue and issecretvalue(name)) then return name end
    end
    local ok, name = pcall(UnitName, "player")
    return ok and name or "?"
end

function EraUI:LoadCharSettings()
    self.charSettings = {}
    if not (C_CVar and C_CVar.GetCVar) then return end
    local key = CharSettingKey()
    local ok, text = pcall(C_CVar.GetCVar, CHAR_SETTING_CVAR)
    if not ok or not text then return end
    for entry in text:gmatch("[^;]+") do
        local k, payload = entry:match("^(.-):(.*)$")
        if k == key and payload then
            local flags = payload:match("^([01][01])$")
            if flags then
                self.charSettings.swingTimer = flags:sub(1, 1) == "1"
                self.charSettings.rangedSwingTimer = flags:sub(2, 2) == "1"
            end
            return
        end
    end
end

function EraUI:SaveCharSettings()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local key = CharSettingKey()
    local existing = {}
    for entry in (C_CVar.GetCVar(CHAR_SETTING_CVAR) or ""):gmatch("[^;]+") do
        local k, payload = entry:match("^(.-):(.*)$")
        if k and payload then existing[k] = payload end
    end
    existing[key] = (self.charSettings.swingTimer and "1" or "0")
        .. (self.charSettings.rangedSwingTimer and "1" or "0")
    local parts = {}
    for k, payload in pairs(existing) do parts[#parts + 1] = k .. ":" .. payload end
    table.sort(parts)
    pcall(C_CVar.SetCVar, CHAR_SETTING_CVAR, table.concat(parts, ";"))
end

function EraUI:GetCharSetting(key)
    if not EraUI.charSettingKeys[key] then return EraUI:GetSetting(key) end
    return EraUI.charSettings and EraUI.charSettings[key] == true
end

function EraUI:SetCharSetting(key, value)
    if not EraUI.charSettingKeys[key] then return EraUI:SetSetting(key, value) end
    EraUI.charSettings = EraUI.charSettings or {}
    EraUI.charSettings[key] = value and true or false
    EraUI:SaveCharSettings()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        EraUIDB = EraUIDB or {}
        -- Split old combined settings without turning a previously disabled skin on.
        for key, legacy in pairs({trainer="professions", gameMenu="classicDialogs", popups="classicDialogs"}) do
            if EraUIDB[key] == nil then
                local value = EraUIDB[legacy]
                if value == nil then value = defaults[legacy] end
                EraUIDB[key] = value
            end
        end
        ApplyDefaults(EraUIDB, defaults)
        if not EraUIDB.advancedCastBar then
            EraUIDB.advancedCastTicks = false
            EraUIDB.advancedCastLatency = false
        end
        if EraUIDB.showAllSpellRanks == nil then
            EraUIDB.showAllSpellRanks = GetCVarBool and GetCVarBool("ShowAllSpellRanks") or false
        end
        EraUI.loadedVisualSettings = {}
        for key in pairs(EraUI.reloadSettings) do EraUI.loadedVisualSettings[key] = EraUIDB[key] end
        EraUI.db = EraUIDB
        EraUI:Status("v" .. EraUI.version .. " loaded for WoW Forever beta.")
    elseif event == "PLAYER_LOGIN" then
        if not EraUIDB or EraUIDB.enabled == false then return end
        EraUI:LoadCharSettings()
        for name, module in pairs(EraUI.modules) do
            if type(module.Initialize) == "function" then
                local ok, err = pcall(module.Initialize, module)
                EraUI.moduleResults[name] = { ok = ok, error = not ok and tostring(err) or nil }
                if not ok then
                    EraUI:Print(name .. " could not initialise: " .. tostring(err))
                end
            end
        end
    end
end)
