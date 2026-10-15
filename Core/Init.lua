local ADDON_NAME, EraUI = ...
_G.EraUI = EraUI

EraUI.name = ADDON_NAME
-- The version is the .toc's own "## Version", read as the addon loads, so it
-- can never be left behind at a release. A copy without a real number there
-- (empty, or the packager's "@project-version@" placeholder) runs as "dev":
-- What's New then shows the newest notes and the update notice neither
-- shares nor compares it.
local function TocVersion(read)
    if type(read) ~= "function" then return nil end
    local ok, value = pcall(read, ADDON_NAME, "Version")
    if not ok or type(value) ~= "string" then return nil end
    value = value:match("^%s*(.-)%s*$")
    if value == "" or value:find("@", 1, true) then return nil end
    return value
end
EraUI.version = TocVersion(C_AddOns and C_AddOns.GetAddOnMetadata) or TocVersion(GetAddOnMetadata) or "dev"
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
    cursorCastRing = false,
    cursorCastClassColour = true,
    cursorCastColour = "FFFFFF",
    cursorCastSize = 60,
    cursorCastOpacity = 90,
    cursorTrail = false,
    cursorTrailClassColour = true,
    cursorTrailColour = "FFFFFF",
    cursorTrailSize = 10,
    cursorTrailOpacity = 55,
    cursorTrailLength = 25,
    darkMode = false,
    darkModeDarkness = 58, -- Darkness: 40 light grey to 90 near black; 58 is the original grey
    darkenClassColours = false, -- Darkness row tick: class-coloured unit borders darken with the slider too
    darkAuraBorders = true, -- Dark Aura Borders: shows only in Dark Mode, so choosing Dark Mode gives them
    darkAuraShadows = true, -- Aura Shadows: shows only with Dark Mode and Dark Aura Borders
    darkDebuffLines = false, -- Thin Debuff Colours: debuffs get the dark border with a thin line in their type's colour; off by default
    darkMenuBar = true, -- Dark Menu Bar: shows only in Dark Mode, so choosing Dark Mode gives it
    darkBagButtons = false, -- Dark Bag Buttons: grey, darker bag bar icons and a dark open-bag line; Dark Mode only; off by default, applies live
    darkWindows = true, -- Dark Windows: shows only in Dark Mode, so choosing Dark Mode gives it
    blackPages = false, -- Black Pages: near-black spellbook and professions pages under Dark Windows; off by default
    flatBars = false, -- Flat Bars: a plain, solid fill on unit-frame and cast bars, Classic or Dark Mode; off by default, applies live
    thickFrames = false, -- Thick Frames: thick dark soft-cornered plates with taller bars on player, pet, target, focus and target of target; needs Unit Frames; off by default, applies live (a change in a fight waits for its end)
    thickFrameRings = false, -- Portrait Rings (under Thick Frames): a thick dark ring round each portrait; off by default, applies live
    thickFrameEdge = "dark", -- Edge (under Thick Frames): "dark" (every edge near black, the default) or "class" (a fine line in class colours inside the plates, rings and level pill; elites gold, rares silver, other NPCs none); applies live
    thickFrameParty = false, -- Classic Party Frames (under Thick Frames): the same plates on EraUI's Classic-style party frames; off by default, applies live
    thickAuraBorders = false, -- Thick Aura Borders: thick dark borders round your own buff and debuff icons, Classic or Dark Mode; wins over Dark Aura Borders; off by default, applies live
    roundedCastBars = false, -- Rounded Cast Bars: thick soft-cornered player, pet, target and focus cast bars with the spell icon in its own tile; needs Cast Bars; off by default, applies live
    partyOutline = false, -- Raid-style Party Outline (experimental): a flat fill and one thick dark outline round the game's raid-style party frames (the outline while Edit Mode's Display Border is on); steps aside while Forever Enhanced Raid Frames draws the party; off by default, applies live (a change in a fight waits for its end)
    floatingComboPoints = false,
    comboPointRed = false,
    energyBar = false,
    classReminders = false,
    reminderX = 0,
    reminderY = 120,
    reminderScale = 1,
    reminderShards = 5,
    hunterFeed = false,
    mageSupplies = false,
    mageAutoTrade = false,
    roguePoisons = false,
    poisonReminders = false, -- the old Poison Reminders panel; kept so its users move to POISON! (ReminderPoisons.Migrate)
    advancedCastBar = false,
    advancedCastClassFill = false,
    advancedCastLatency = true,
    advancedCastTicks = true,
    castBarClassBorder = false,
    castBarColour = "auto", -- Cast Bar Colour: the player's and pet's cast fill; "auto" (Match look: Classic yellow, the light grey in Dark Mode), "classic", "grey", "class" or "custom"; applies live
    castBarCustomColour = "C7CCD6", -- Cast Bar Colour's Custom: a hex colour, the light grey until one is picked
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
    portraitDebuffs = false,
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
    questTrackerChoice = "", -- "classic" or "questie" once answered; see QuestTrackerChoice.
    trainer = true,
    gameMenu = true,
    popups = true,
    coordinates = false,
    fastAutoLoot = false,
    discardCheapestJunk = false,
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
    upgradeSpellRanks = false, -- Upgrade Spell Ranks: a new rank you learn takes the outgrown rank's place on your action bars, out of combat; lower ranks, macros and items stay; off by default, applies live
    hideZoneText = false,
    maxCameraZoom = false,

    autoGossip = false,
    durabilityWarning = false,
    tooltipIDs = false,
    linkToggle = true, -- click a chat link again to close its tooltip
    updateCheck = true, -- say in chat when a guild or group member has a newer EraUI
    damageFont = "pepsi", -- the font of the damage and healing numbers
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
    tooltipSkin = true,
    tooltipClassColours = false, -- Class-coloured Tooltips; off by default
    damageMeterSkin = false,
    otherWindows = true,
    trainingGuide = true,
    contextMenus = false,
    cleanMinimap = false,
    cleanMinimapStyle = "hover", -- Clean Minimap's style: "hover" (hide until hover, as before) or "drawer"
    minimapDrawerColumns = 5, -- the drawer's icons per row, 3 to 8
    squareMinimap = false, -- Square Minimap (needs Minimap): a square map in a thin dark frame, its fine line bronze in Classic and the Darkness grey in Dark Mode, buttons on its edges, other addons told it's square; off by default, applies live (a change in a fight waits for its end)
    squareMinimapScale = 100, -- Square Size (shown only while Square Minimap is ticked): the whole square, map, frame and buttons, 75 to 150 (percent), on top of Edit Mode's Minimap Size; only while the square is worn; unreadable: 100; applies live (a change in a fight waits for its end)
    autoSellJunk = false,
    autoRepair = false,
    vendorPrice = true,
    questLevels = true,
    bagSpace = true,
    bagItemLevels = false, -- Bag Item Levels; off by default, a saved choice is kept
    characterItemLevels = false, -- Character Item Levels; off by default, a saved choice is kept
    statTracker = false, -- Stat Tracker: a small panel of the stats ticked below, updating live; drag to move; off by default, applies live
    statTrackerLayout = "list", -- "list" (a stat a line) or "line" (all on one line)
    statTrackerShow = "always", -- "always", "combat" (only in a fight) or "calm" (only out of one); always while /era is open
    statTrackerGains = true, -- a stat that goes up turns green with how much, for five seconds
    statTrackerTitle = true, -- the "Stats" title over the list
    statTrackerScale = 100, -- Panel Size, 50 to 150 (percent), in either layout
    statTrackerPerLine = 16, -- Stats per Line (One line only), 1 to 16; 16 (All) keeps them all on one line
    statTrackerNameColour = "auto", -- the stat names: "auto" (Match look: Classic gold, Dark Mode grey), "gold", "class", "white" or "custom"
    statTrackerNameCustomColour = "FFD100", -- Stat Name Colour's Custom: a hex colour, the Classic gold until one is picked
    -- The stats on the panel (Modules/StatTracker.lua STATS), the approved eight ticked.
    statTrackerStrength = false, statTrackerAgility = true, statTrackerStamina = true, statTrackerIntellect = false,
    statTrackerSpirit = false, statTrackerAttackPower = true, statTrackerCrit = true, statTrackerHit = true,
    statTrackerSpellPower = false, statTrackerSpellCrit = false, statTrackerArmor = true, statTrackerDodge = true,
    statTrackerParry = false, statTrackerBlock = false, statTrackerSpeed = true, statTrackerDurability = false,
    classColors = true,
    hideStatusMessages = true,
    afkScreen = true,        -- AFK Screen; on by default (the user's call), a saved choice is kept
    afkCameraNormal = false, -- off = slow circle (3 deg/s), on = normal (6 deg/s)
    afkTurnRight = false,    -- off = circle left, on = circle right
    afkZoom = true,          -- gently zoom in while away
    afk24Hour = false,       -- local time as 15:07 instead of 3:07 PM
    afkShowGuild = true,
    afkShowZone = true,
    afkShowDate = true,
    afkShowQuote = true,     -- a famous Classic line for your class above the hint
}

-- Visual choices are staged for the next UI load. Live modules keep a coherent
-- presentation until then; disabling never tries to undo protected hooks.
EraUI.reloadSettings = {}
for _, key in ipairs({"classicChatDragging", "floatingComboPoints", "classColourBorders", "darkMode", "actionBars", "minimap", "unitFrames", "castBars", "characterPanel",
    "friendlyNameplates", "enemyNameplates", "disableAggroHighlight", "lootWindow", "matchFocusSize",
    "professions", "trainer", "spellbook", "spellbookCombatDrag", "questDialogs", "questTracker",
    "classicDialogs", "gameMenu", "popups", "socialWindows", "talentWindow",
    "questLog", "bagsBank", "merchantSkin", "mailSkin", "auctionHouse",
    "groupFinderPvp", "blizzardSettings", "tooltipSkin", "damageMeterSkin", "otherWindows", "trainingGuide", "contextMenus"}) do
    EraUI.reloadSettings[key] = true
end
EraUI.settingDefaults = defaults

-- Blizzard's own switches (Options > Interface), mirrored in /era: the card
-- reads and writes the game's setting, so the two always match.
EraUI.cvarSettings = {
    classIconPortraitMine = "ReplaceMyPlayerPortrait",
    classIconPortraitOthers = "ReplaceOtherPlayerPortraits",
}
function EraUI:GetSavedSetting(key)
    if key == "showAllSpellRanks" and GetCVarBool then return GetCVarBool("ShowAllSpellRanks") end
    local cvar = self.cvarSettings[key]
    if cvar then return GetCVarBool ~= nil and GetCVarBool(cvar) and true or false end
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
    local ok, value = pcall(C_CVar.GetCVar, CHAR_SETTING_CVAR)
    if not ok or value == nil then pcall(C_CVar.RegisterCVar, CHAR_SETTING_CVAR, "") end
end

local function CharSettingKey()
    return EraUI:CharacterIdentity()
end

function EraUI:LoadCharSettings()
    self.charSettings = {}
    local saved = self.Persistence and self.Persistence.characterSwing
    if saved then
        for key in pairs(self.charSettingKeys) do self.charSettings[key] = saved[key] == true end
        return
    end
    if not (C_CVar and C_CVar.GetCVar) then return end
    local key, legacy = CharSettingKey()
    if not key then return end
    local ok, text = pcall(C_CVar.GetCVar, CHAR_SETTING_CVAR)
    if not ok or not text then return end
    local records = {}
    for entry in text:gmatch("[^;]+") do
        local k, payload = entry:match("^(.-):(.*)$")
        if k and payload then records[k] = payload end
    end
    local flags = (records[key] or records[legacy] or ""):match("^([01][01])$")
    if flags then
        self.charSettings.swingTimer = flags:sub(1, 1) == "1"
        self.charSettings.rangedSwingTimer = flags:sub(2, 2) == "1"
        if not records[key] then self:SaveCharSettings() end
    end
end

function EraUI:SaveCharSettings()
    if self.Persistence and self.Persistence.resetting then return end
    self:SaveSettings()
    if not (C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then return end
    local key, legacy = CharSettingKey()
    if not key then return end
    local existing = {}
    for entry in (C_CVar.GetCVar(CHAR_SETTING_CVAR) or ""):gmatch("[^;]+") do
        local k, payload = entry:match("^(.-):(.*)$")
        if k and payload then existing[k] = payload end
    end
    existing[legacy] = nil -- Claim the old name-only entry once, on migration.
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
        -- A reset is consumed before any saved choices or aliases are loaded.
        EraUI.Persistence:PrepareReset()
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
        -- The damage text font is read by the game as you log in.
        if EraUIDB.enabled ~= false and EraUI.ApplyCombatFont then EraUI:ApplyCombatFont() end
        EraUI:Status((EraUI.version == "dev" and "Development copy" or ("v" .. EraUI.version)) .. " loaded for WoW Forever beta.")
    elseif event == "PLAYER_LOGIN" then
        if not EraUI.Persistence.character and EraUI.LoadCharOnboarding then EraUI.LoadCharOnboarding() end
        EraUI.Persistence:LoadCharacter()
        EraUI:LoadCharSettings()
        if not EraUIDB or EraUIDB.enabled == false then return end
        for name, module in pairs(EraUI.modules) do
            if type(module.Initialize) == "function" then
                local ok, err = pcall(module.Initialize, module)
                EraUI.moduleResults[name] = { ok = ok, error = not ok and tostring(err) or nil }
                if not ok then
                    EraUI:Print(name .. " could not initialise: " .. tostring(err))
                end
            end
        end
        EraUI:SaveSettings()
    end
end)
