local ADDON_NAME, EraUI = ...
_G.EraUI = EraUI

-- The game's Key Bindings menu, AddOns section (Bindings.xml): the names of
-- EraUI's entries. The first three each click a window's named button, made in
-- Look/SpellLayer.lua, Look/QuestLogOpen.lua and Look/TalentModule.lua. The
-- player sets the key there himself; EraUI sets one only when he clicks Use N
-- in the classic talents key offer (Look/TalentKey.lua).
BINDING_HEADER_ERAUI = "EraUI"
_G["BINDING_NAME_CLICK EraUIClassicSpellBookBind:LeftButton"] = "Classic Spellbook"
_G["BINDING_NAME_CLICK EraUIClassicQuestLogBind:LeftButton"] = "Classic Quest Log"
_G["BINDING_NAME_CLICK EraUIClassicTalentsBind:LeftButton"] = "Classic Talents"
-- Action Rings (Modules/ActionRings.lua): ten more entries, each clicking a
-- ring's named button (Modules/RingSecure.lua). EraUI never sets their keys.
for i = 1, 10 do _G["BINDING_NAME_CLICK EraUIRingButton" .. i .. ":LeftButton"] = "Action Ring " .. i end
-- A ring's name in Key Bindings: "Action Ring 3: Mage Ring"; nil puts the
-- plain name back. The game reads it each time the list shows a row.
function EraUI:SetRingBindingName(slot, ringName)
    if type(slot) ~= "number" or slot < 1 or slot > 10 or slot % 1 ~= 0 then return end
    local plain = "Action Ring " .. slot
    local named = type(ringName) == "string" and ringName ~= ""
    _G["BINDING_NAME_CLICK EraUIRingButton" .. slot .. ":LeftButton"] = named and (plain .. ": " .. ringName) or plain
end

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
    darkBagButtons = false, -- Dark Bag Buttons: grey, darker bag bar icons and a dark open-bag line, with or without Dark Mode; off by default, applies live
    darkBagAddonSlots = false, -- Bag Addon Windows (experimental, under Dark Bag Buttons): a bag addon's bag icons (its bag slots and special bags' buttons) grey the same way, every kind of bag; needs Dark Bag Buttons; off by default, applies live (Look/BarArt.lua)
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
    advancedCastBatch = false, -- crafting a batch: which one of how many, and the time left for them all
    castBarClassBorder = false,
    plainNameStrip = false, -- Plain Target Name Strip: the target/focus name strip keeps the game's colour (Modules/ClassAccents.lua)
    castBarColour = "auto", -- Cast Bar Colour: the player's and pet's cast fill; "auto" (Match look: Classic yellow, the light grey in Dark Mode), "classic", "grey", "class" or "custom"; applies live
    castBarCustomColour = "C7CCD6", -- Cast Bar Colour's Custom: a hex colour, the light grey until one is picked
    -- Ability Trail (Modules/AbilityTrail.lua, /era > Casting > Ability
    -- Trail): your last abilities as a trail of icons, and your party's;
    -- off by default, applies live. Its places (abilityTrailPosition, and
    -- abilityTrailPartyPositions per party slot) and ignore list
    -- (abilityTrailIgnore) are kept once you move a trail or ignore something.
    abilityTrail = false, -- You: your own trail
    abilityTrailDirection = "right", -- "right", "left", "up" or "down"
    abilityTrailSize = 36, -- your icons' size in pixels, 20 to 64
    abilityTrailCount = 5, -- how many of your icons, 1 to 10
    abilityTrailParty = false, -- Party (experimental): a trail beside each party member's frame
    abilityTrailPartyDirection = "right",
    abilityTrailPartySize = 29, -- party icons, 20 to 64 (80% of yours before they had their own)
    abilityTrailPartyCount = 5,
    abilityTrailScroll = true, -- Scrolling Icons: icons glide away; off, a still row
    abilityTrailSpeed = 12, -- how fast they glide, 4 to 60 pixels a second
    abilityTrailDistance = 200, -- how far they glide, 50 to 600 pixels
    abilityTrailSeconds = 10, -- Show For (still row): how long each stays, 2 to 30 seconds
    abilityTrailCombatOnly = false, -- new icons only in a fight
    abilityTrailBorder = "auto", -- the icons' edge: "auto" (Match look: black in Dark Mode, silver in Classic), "black", "class" (each trail's class colour) or "custom"
    abilityTrailBorderColour = "C7CCD6", -- Border's Custom: a hex colour, light grey until one is picked
    abilityTrailInWorld = true, -- Show In: the world, dungeons, raids and battlegrounds (arenas too)
    abilityTrailInDungeons = true,
    abilityTrailInRaids = true,
    abilityTrailInBattlegrounds = true,
    abilityTrailTooltip = true, -- your icons' tooltip
    abilityTrailPauseOnHover = true, -- your trail holds still while the mouse is on one of your icons
    abilityTrailSpellID = false, -- the spell ID in your icons' tooltip
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
    hideSecondaryNamesTooltips = true, -- On Tooltips Too (experimental, under Hide Surnames): players' names on unit tooltips without the surname; on within Hide Surnames, which stays off by default; applies live
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
    spellbookCombatDrag = false, -- experimental, off unless chosen (Squirt's call, after 1.7.3)
    questDialogs = true,
    classicDialogs = true,
    socialWindows = true,
    talentWindow = true,
    legacyWindow = true, -- Legacy Window: Forever's Legacy window (Y) in the 1.x look; on by default (Squirt's call, 2026-10-22), a reload setting
    questTracker = true,
    questTrackerChoice = "", -- "classic" or "questie" once answered; see QuestTrackerChoice.
    trainer = true,
    gameMenu = true,
    popups = true,
    coordinates = false,
    rememberMinimapZoom = false, -- Remember Minimap Zoom: keeps this character's minimap zoom, indoors and outdoors apart, and puts it back after logging in (Modules/MinimapZoom.lua); off by default, applies live
    questSparkles = true, -- Quest Item Sparkles: the game's own sparkle on lootable quest items, which needs its outlines off (Modules/QuestSparkles.lua); on by default (Squirt's call, 2026-11-04), applies live
    gatherSparkles = false, -- Herb and Ore Sparkles (experimental): the same, plus the game's soft targeting picking out the nearest herb or ore as you get close; off by default, applies live
    fastAutoLoot = false,
    discardCheapestJunk = false,
    openClams = false, -- Open Clams: clams in your bags open one at a time by themselves out of a fight, never at a vendor, bank, mailbox, trade or auction house, and a clam button shows while you carry some (Modules/OpenClams.lua); steps aside while Clam Opener is loaded; off by default, applies live
    plainAddonList = false, -- Plain AddOn List: the game's AddOn list as one plain list in addon order, no category headings, nothing tucked under another addon (Modules/PlainAddonList.lua); off by default, applies live; seen in game 2026-11-07
    hideRestInCities = false, -- Hide Zzz in Cities: in a capital city your level shows instead of the resting Zzz, on EraUI's 1.x player frame or the game's own (Modules/RestInCities.lua, Look/UnitPlayer.lua); off by default, applies live; seen in game 2026-11-07
    classColourFriends = true, -- Class-coloured Friends: online friends' names in their class colour in the friends list, a Battle.net friend's character name only (Modules/ClassFriends.lua); ON by default (Squirt, 2026-11-07: "class colored will be enabled by default"), applies live; seen in game the same day
    classColourFriendsLevel = false, -- Show Their Level, under Class-coloured Friends: a Battle.net friend's level in the brackets after their character's name, "(Vex, 60)", in the same colour (Modules/ClassFriends.lua); off by default, applies live; seen in game 2026-11-07
    -- Thank for Buffs (experimental, Modules/ThankBuffs.lua): another player
    -- who buffs you gets one whisper of thanks (their buffs within two
    -- seconds in one line), then 30 minutes of quiet; off by default, applies
    -- live. The whisper's words (%name% their first name, %spell% the buffs)
    -- and who or when to skip.
    thankBuffs = false,
    thankBuffsMessage = "Thanks for the %spell%!",
    thankBuffsSkipGroup = true, thankBuffsSkipGuild = true, thankBuffsSkipFriends = false,
    thankBuffsSkipCombat = true, thankBuffsSkipInstances = true,
    -- Name in Chat (experimental, Modules/NameInChat.lua): the name you set
    -- goes in brackets before what you send, "(Squirt) Hello"; off by
    -- default, applies live. The name (empty: nothing added), then which
    -- chats: party (and instance), raid (and raid warnings), guild (and
    -- officer) on, say off. Whispers, channels, yell and emotes never.
    nameInChat = false,
    nameInChatName = "",
    nameInChatParty = true, nameInChatRaid = true, nameInChatGuild = true, nameInChatSay = false,
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
    -- Action Rings (experimental, Modules/ActionRings.lua, /era > Action Bars
    -- > Action Rings): hold a ring's key (Key Bindings > AddOns > EraUI) for a
    -- ring of spells, items, mounts and more round your cursor, and let go on
    -- one to use it. Off by default, applies live (a change in a fight waits
    -- for its end). The rings are this character's (EraUIClassicCharDB.actionRings).
    actionRings = false,
    actionRingScale = 100, -- Ring Size: 75 to 150 (percent)
    actionRingNames = true, -- Slice Names: the name of the slice you point at, under the ring
    actionRingCooldowns = true, -- Cooldowns & Counts: cooldown sweeps and item counts on the icons
    actionRingMotion = true, -- Ring Motion: the icons swirl in as a ring opens and out as it closes
    hideZoneText = false,
    maxCameraZoom = false,

    autoGossip = false,
    durabilityWarning = false,
    tooltipIDs = false,
    linkToggle = true, -- click a chat link again to close its tooltip
    chatArrowKeys = false, -- Arrow Keys in Chat: plain arrows move along the line and bring back sent lines (Modules/ExtraQoL.lua)
    updateCheck = true, -- Update Notice: say in chat when a newer EraUI is out (Core/SquirtVersions.lua)
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
    bagArrowArmourColour = false, -- Arrow Colour by Armour, under Bag Item Levels: upgrade arrows on body armour in the colour of its type (Modules/BagItemLevels.lua); off by default, applies live
    bagBigCounts = false, -- Big Stack Numbers, under Bag Item Levels: stack counts in the item level's font (Modules/BagItemLevels.lua); off by default, applies live
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
    miniGameFlight = "off",  -- Mini-games, On a Flight Path (experimental): "off", "whack" or "blast", the game that opens as you take off (Modules/MiniGames.lua); off by default, applies live
    miniGameSounds = true,   -- Mini-game Sounds: the games' sounds and voices; applies live
}

-- Visual choices are staged for the next UI load. Live modules keep a coherent
-- presentation until then; disabling never tries to undo protected hooks.
EraUI.reloadSettings = {}
for _, key in ipairs({"classicChatDragging", "floatingComboPoints", "classColourBorders", "darkMode", "actionBars", "minimap", "unitFrames", "castBars", "characterPanel",
    "friendlyNameplates", "enemyNameplates", "disableAggroHighlight", "lootWindow", "matchFocusSize",
    "professions", "trainer", "spellbook", "spellbookCombatDrag", "questDialogs", "questTracker",
    "classicDialogs", "gameMenu", "popups", "socialWindows", "talentWindow", "legacyWindow",
    "questLog", "bagsBank", "merchantSkin", "mailSkin", "auctionHouse",
    "groupFinderPvp", "blizzardSettings", "tooltipSkin", "damageMeterSkin", "otherWindows", "trainingGuide", "contextMenus"}) do
    EraUI.reloadSettings[key] = true
end
EraUI.settingDefaults = defaults
-- Settings nothing reads any more (the old profile name, and the one-panel
-- reminders' place and size, unread since 1.0.4): taken out of every saved
-- copy as EraUI loads, so they are neither kept nor backed up.
EraUI.retiredSettings = { "profile", "reminderX", "reminderY", "reminderScale" }

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

-- Per-character swing timer settings, kept in this character's
-- SavedVariables (EraUIClassicCharDB.swing). The game keeps addon CVars only
-- until it closes (they never reach Config.wtf), so the CVar below, keyed by
-- character name + realm, and the settings recovery (Core/Persistence.lua)
-- only bring them back within one session. Versions before this kept them in
-- the CVar alone, so a full restart switched both timers off; that CVar is
-- still read once to move a choice over.
EraUI.charSettingKeys = { swingTimer = true, rangedSwingTimer = true }
local CHAR_SETTING_CVAR = "EraUICharSwing"
if C_CVar and C_CVar.RegisterCVar then
    local ok, value = pcall(C_CVar.GetCVar, CHAR_SETTING_CVAR)
    if not ok or value == nil then pcall(C_CVar.RegisterCVar, CHAR_SETTING_CVAR, "") end
end

local function CharSettingKey()
    return EraUI:CharacterIdentity()
end

-- This character's swing toggles as its SavedVariables hold them, or nil.
local function SavedSwing()
    local char = EraUIClassicCharDB
    local swing = type(char) == "table" and char.swing
    return type(swing) == "table" and swing or nil
end

-- The toggles in use written to this character's SavedVariables.
local function KeepSwing()
    if type(EraUIClassicCharDB) ~= "table" then EraUIClassicCharDB = {} end
    local now = EraUI.charSettings or {}
    EraUIClassicCharDB.swing = { swingTimer = now.swingTimer == true, rangedSwingTimer = now.rangedSwingTimer == true }
end

function EraUI:LoadCharSettings()
    self.charSettings = {}
    -- This session's recovery record first (it wins over SavedVariables the
    -- game may have lost), then SavedVariables, then the old CVar.
    local saved = (self.Persistence and self.Persistence.characterSwing) or SavedSwing()
    if saved then
        for key in pairs(self.charSettingKeys) do self.charSettings[key] = saved[key] == true end
        KeepSwing()
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
        -- Moved into SavedVariables (and an old name-only entry claimed).
        self:SaveCharSettings()
    end
end

function EraUI:SaveCharSettings()
    if self.Persistence and self.Persistence.resetting then return end
    KeepSwing()
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
        for _, key in ipairs(EraUI.retiredSettings) do EraUIDB[key] = nil end
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
