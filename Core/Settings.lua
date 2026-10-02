local _, EraUI = ...

local SettingsModule = {}
EraUI:RegisterModule("Settings", SettingsModule)

local reloadSettings = EraUI.reloadSettings

-- Options that only work on top of another one. They are greyed out, and
-- cannot be switched on, while it is off. A list means every one is needed;
-- the first is the option it sits under in /era.
local DEPENDS = {
    advancedCastClassFill = "advancedCastBar", advancedCastTicks = "advancedCastBar", advancedCastLatency = "advancedCastBar",
    trainingGuide = "spellbook", spellbookCombatDrag = "spellbook",
    portraitDebuffs = "unitFrames", matchFocusSize = "unitFrames", disableAggroHighlight = "unitFrames",
    classColourBorders = {"darkMode", "unitFrames"}, gryphons = "actionBars",
    afkCameraNormal="afkScreen", afkTurnRight="afkScreen", afkZoom="afkScreen", afk24Hour="afkScreen",
    afkShowGuild="afkScreen", afkShowZone="afkScreen", afkShowDate="afkScreen", afkShowQuote="afkScreen",
    darkAuraBorders="darkMode", darkAuraShadows="darkAuraBorders",
}
-- The names on the cards, so a hover points at a switch the player can find.
local DEPEND_NAMES = {
    advancedCastBar = "Advanced Cast Bar", spellbook = "Spellbook",
    unitFrames = "Unit Frames", actionBars = "Action Bars",
    afkScreen = "AFK Screen", darkMode = "Dark Mode", darkAuraBorders = "Dark Aura Borders",
}
local function Parents(key)
    local parents = DEPENDS[key]
    if type(parents) == "table" then return parents end
    return parents and {parents} or {}
end
-- The option to switch on first, walking up each chain: Aura Shadows needs
-- Dark Aura Borders, which needs Dark Mode, so Dark Mode is named first.
local function MissingParent(key, depth)
    depth = depth or 0
    if depth > 8 then return end
    for _, parentKey in ipairs(Parents(key)) do
        local higher = MissingParent(parentKey, depth + 1)
        if higher then return higher end
        if EraUI:GetSavedSetting(parentKey) ~= true then return parentKey end
    end
end
-- Folded options: hidden, not greyed, until their switch is on, then shown
-- right after it. The AFK Screen's options stay unfolded: it is on by default.
local FOLDS = {
    cursorRingClassColour="cursorRing", cursorRingSize="cursorRing", cursorRingThickness="cursorRing",
    cursorCastClassColour="cursorCastRing", cursorCastSize="cursorCastRing", cursorCastOpacity="cursorCastRing",
    cursorCastColour="cursorCastRing",
    cursorTrailClassColour="cursorTrail", cursorTrailSize="cursorTrail", cursorTrailOpacity="cursorTrail",
    cursorTrailLength="cursorTrail", cursorTrailColour="cursorTrail",
}
local FOLD_PARENTS = {}
for _, parentKey in pairs(FOLDS) do FOLD_PARENTS[parentKey] = true end
local function Folded(key)
    return FOLDS[key] ~= nil and EraUI:GetSavedSetting(FOLDS[key]) ~= true
end
-- The card each sub-option belongs under: its fold, its first DEPENDS option,
-- or (for cards that are not switches) the one it goes with.
local GROUPS = {rewardProfile = "rewardUpgradeHighlight"}
local function GroupParent(key)
    return FOLDS[key] or GROUPS[key] or Parents(key)[1]
end
-- Earlier names of renamed cards, so searching an old name still finds them.
local OLD_NAMES = {
    characterPanel = "Character / Reputation / Skills", bagsBank = "Bags / Bank",
    socialWindows = "Friends / Guild", groupFinderPvp = "Group Finder / PvP",
    blizzardSettings = "Blizzard Settings Skin", hideSecondaryNames = "Hide Secondary Names",
    classColors = "Class Colours in Chat", fastAutoLoot = "Faster Auto Loot", autoGossip = "Auto Gossip",
    discardCheapestJunk = "Discard Cheapest Junk When Bags Are Full",
    afkCameraNormal = "AFK Camera: Normal Speed", afkTurnRight = "AFK Camera: Circle Right",
    afkZoom = "AFK Camera: Zoom In", advancedCastClassFill = "Class-coloured Fill",
    cursorCastColour = "Custom cast-ring colour",
}
-- The /era tabs, one home per topic, in the order of the left list. Ids stay
-- the same; the numbers are only their place in the list.
local TAB_IDS = {"appearance", "class", "actionBars", "frames", "casting", "map", "quests",
    "character", "bags", "chat", "group", "windows", "screen", "more"}
local TAB = {}
for index, id in ipairs(TAB_IDS) do TAB[id] = index end
-- The left tab list. Every tab name fits inside its tab at the tab font
-- (size 13): the widest, Frames & Nameplates, is about 146 wide in game, and
-- a tab's text starts 36 in and ends 2 short of the tab's edge (150 of room),
-- so text that renders wider at another UI scale is cut short inside the
-- highlight. The pages start just right of the list, so the window grows
-- with it and the pages keep their width.
local NAV_WIDTH = 212                       -- the list's dark backing
local TAB_WIDTH = NAV_WIDTH - 24            -- 12 in from the window edge, 13 short of the divider
local PAGE_LEFT = NAV_WIDTH + 20            -- page titles, descriptions and search
local VIEW_LEFT = NAV_WIDTH + 14            -- the card viewport and the new layout note
local WINDOW_WIDTH = 772 + NAV_WIDTH        -- 984
-- New-player hints pulse on the class and Casting tabs. They are saved by tab
-- number, so a new tab order is a new version (version 1: the old numbers).
local HINTS_VERSION = 2
-- Search spells colour/color and grey/gray the same way.
local function Normalise(text)
    return (text:gsub("colour", "color"):gsub("grey", "gray"))
end
-- AFK Screen options apply live through its module.
local AFK_KEYS = {afkScreen=true, afkCameraNormal=true, afkTurnRight=true, afkZoom=true,
    afk24Hour=true, afkShowGuild=true, afkShowZone=true, afkShowDate=true, afkShowQuote=true}
-- The game's own switches mirrored on cards (EraUI.cvarSettings): what the
-- game holds now, or nil when it can't be read (a game without that switch
-- gives nothing back).
local function GameSwitch(cvar)
    if not GetCVarBool then return nil end
    local ok, value = pcall(GetCVarBool, cvar)
    if not ok or (issecretvalue and issecretvalue(value)) or value == nil then return nil end
    return value and true or false
end
-- A switch the game keeps for its own Options window (secure or read-only)
-- quietly ignores addon writes, so its card doesn't try.
local function GameOnlySwitch(cvar)
    if not (C_CVar and C_CVar.GetCVarInfo) then return false end
    local ok, value, _, _, _, _, isSecure, isReadOnly = pcall(C_CVar.GetCVarInfo, cvar)
    if not ok or value == nil then return false end
    if issecretvalue and (issecretvalue(isSecure) or issecretvalue(isReadOnly)) then return false end
    return isSecure == true or isReadOnly == true
end
-- The game's Options window redraws every portrait when it flips a portrait
-- switch. A flip from /era gets the same redraw at once, both ways, from the
-- game's own portrait function on each unit frame that has one. Out of
-- combat only; nothing is written on the frames.
local function RedrawPortraits()
    local update = UnitFramePortrait_Update
    if type(update) ~= "function" or InCombatLockdown() then return 0 end
    local list = {}
    local function Add(unitFrame) if unitFrame then list[#list + 1] = unitFrame end end
    Add(PlayerFrame); Add(TargetFrame); Add(FocusFrame)
    if TargetFrame then Add(TargetFrame.totFrame) end
    if FocusFrame then Add(FocusFrame.totFrame) end
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if pool and pool.EnumerateActive then
        local ok, iterate, state, start = pcall(pool.EnumerateActive, pool)
        if ok and iterate then for member in iterate, state, start do Add(member) end end
    end
    local redrawn = 0
    for _, unitFrame in ipairs(list) do
        if unitFrame.portrait and type(unitFrame.unit) == "string" and pcall(update, unitFrame) then redrawn = redrawn + 1 end
    end
    return redrawn
end
-- Coming soon: while its module says so, a feature's card shows SOON, greyed
-- out, and can't be switched on. Each module owns its comingSoon flag.
local SOON_MODULES = {afkScreen="AFKScreen", bagItemLevels="BagItemLevels"}
local function ComingSoon(key)
    local module = SOON_MODULES[key] and EraUI.modules[SOON_MODULES[key]]
    return module ~= nil and module.comingSoon == true
end

local classIconCoords = CLASS_ICON_TCOORDS or {
    WARRIOR={0,.25,0,.25}, MAGE={.25,.49609375,0,.25},
    ROGUE={.49609375,.7421875,0,.25}, DRUID={.7421875,.98828125,0,.25},
    HUNTER={0,.25,.25,.5}, SHAMAN={.25,.49609375,.25,.5},
    PRIEST={.49609375,.7421875,.25,.5}, WARLOCK={.7421875,.98828125,.25,.5},
    PALADIN={0,.25,.5,.75},
}

local settingHelp = {
    discardCheapestJunk = "With full bags, right-clicking a corpse the client identifies as lootable frees the lowest-value grey stack during that click. If loot rights are unavailable, cleanup waits for a bags-full loot error and the next normal world/loot click. At most one stack per loot window. No separate confirmation; the deleted item is reported in chat. Compares total stack vendor value and skips locked/quest items or unknown prices. Never runs in combat or with an occupied cursor. Hold Shift to bypass.",
    cursorCastRing = "A thin progress ring follows your cursor, filling during casts and draining during channels. Works independently of Cursor Ring and the normal cast bar. When Cursor Ring is enabled, the cast ring grows as needed to stay outside it with a small gap. Stops quietly on interruption.",
    poisonReminders = "Shows missing poison, low remaining time and low charges. While enabled, this panel handles missing-poison warnings instead of duplicating the generic Rogue class alerts. Poison Supplies is separate and manages buying/crafting. Preview while settings are open; right-click the header to move or resize.",
    portraitDebuffs = "Shows crowd control on player, target, focus and party portraits with the game's own icon, sweep and countdown, in and out of combat. Enemy targets show the most important effect: stuns, then fears/incapacitates, silences and roots. Friendly units show any crowd control. While shown, the icon extends slightly past the portrait's edge on purpose, to cover the level badge; your level returns when the effect ends. Requires Unit Frames. Applies immediately; off by default.",
    classColourBorders = "Use each player's class colour on normal player, target and focus borders in Dark Mode. Keeps dark interiors, health/power colours and special rare/elite artwork. Requires Dark Mode and Unit Frames. Reload to apply. Off by default.",
    darkMode = "Dark decorative artwork. Character, party and raid frames keep their appearance. Reload to apply either style; Quality of Life choices are unchanged.",
    trainer = "Classic trainer presentation and training controls, independent of profession window styling.",
    gameMenu = "Classic game-menu borders and red buttons.",
    popups = "Classic borders and buttons for native confirmation prompts.",
    coordinates = "Show EraUI coordinates beneath the minimap. Off by default to avoid duplicating another addon's coordinates. No coordinate text is shown when a map position is unavailable.",
    showAllSpellRanks = "Show every spell rank, using the game's spell-rank preference. This also updates EraUI's spellbook. Unavailable during combat.",
    classIconPortraitMine = "Your unit frame shows your class icon instead of your face. This is the game's own setting (Options > Interface: Replace My Frame Portrait), so both always match. Applies at once; unavailable during combat.",
    classIconPortraitOthers = "Other players' unit frames (target, party, focus) show their class icon instead of their face. This is the game's own setting (Options > Interface: Replace Player Frame Portraits), so both always match. Applies at once; unavailable during combat.",
    hideEmptyActionSlots = "Hide unused slots during normal play; reveal them when arranging abilities.",
    autoSellJunk = "Sell grey-quality items on your next merchant visit.",
    autoRepair = "Repair using your own money on your next repair-vendor visit.",
    hideSecondaryNames = "Hide Forever surnames (secondary names) using the supported game display settings. Turning this off shows surnames again. New chat messages follow this setting; existing chat history is unchanged.",
    classicDialogs = "Classic grey borders and red buttons for confirmation prompts and the game menu. Includes resurrection prompts. Reload UI to apply or restore.",
    socialWindows = "Classic frame borders for Friends and Who, with existing social actions. Reload UI to apply or restore.",
    talentWindow = "Classic outer frame around supported talent trees. Keeps existing talent choices and controls. Reload UI to apply or restore.",
    friendlyNameplates = "Classic artwork and lettering on friendly nameplates. Keeps your existing nameplate visibility settings. Reload UI to apply.",
    enemyNameplates = "Classic artwork and lettering on enemy and neutral nameplates. Keeps native threat colours, casts, targeting and auras. Reload UI to apply.",
    lootWindow = "Classic loot frame and item artwork. Keeps native looting, tooltips and scrolling. Reload UI to apply or restore.",
    otherWindows = "Classic frames for the windows without a switch of their own: trade, taxi, macros, calendar, achievements, collections, dressing room, inspect, item socketing, guild charter, tabard, pet stable, add-on list, the world map border and group listings. Reload UI to apply or restore.",
    damageMeterSkin = "Classic look for Blizzard's Damage Meter: dark tooltip-style frame with a grey border, Classic bar texture and fonts, and silver header buttons. Covers extra windows and the spell breakdown window. Blizzard's buttons, menus and Edit Mode options (size, bar height, text size, transparency, background, class colours) keep working, and names and numbers are unchanged. Reload UI to apply or restore. Off by default.",
    disableAggroHighlight = "Hide combat and threat glows on Classic player, target and focus frames, including the player status glow. Requires Unit Frames. Reload UI to apply.",
    questTracker = "Classic text and collapse buttons without modern header plates. Keeps tracking, quest items and completion colours. With Questie's own tracker on, EraUI asks which tracker to use, since only one can show. Reload UI to apply or restore.",
    cleanMinimap = "Hide supported addon minimap buttons until you hover over the minimap. Clock, mail, tracking and zoom stay visible. Changes wait until combat ends.",
    questDialogs = "Classic quest acceptance and turn-in window. Keeps quest text, reward selection and the existing buttons. Reload UI to apply or restore.",
    professions = "Classic window artwork, profession progress bars and spell buttons. Keeps the client's recipes and profession controls. Reload UI to apply or restore.",
    spellbook = "Classic parchment, frame artwork and spell buttons. Keeps the client's spell categories, casting and drag-to-bar controls. Reload UI to apply or restore.",
    characterPanel = "Replaces the character window's side icons with labelled bottom tabs. The existing character panes retain their data and controls. Reload UI to apply or restore the original tabs.",
    actionBars = "Places the main buttons, menu, bags and XP bar on a Classic stone bar at the bottom of the screen. Keeps your spells and keybinds. Also skins extra action buttons. Reload UI to apply or restore the client layout.",
    gryphons = "Show the gryphons at the ends of the action bar. Applies immediately.",
    minimap = "Uses the original round Classic minimap border and zoom-button artwork, fitted to your map size. Reload UI to apply.",
    unitFrames = "Uses Classic artwork and bar proportions on player, target and focus frames, with Classic player debuff borders and buff/debuff hover boxes. Keeps native unit data and controls. Reload UI to apply.",
    castBars = "Classic borders and fill on player, target, focus, boss and styled nameplate cast bars. Keeps native timing, colours and interrupt indicators. Reload UI to apply. Boss bars follow Forever Enhanced Cooldown Manager's Raid Timers when that's on, with no reload.",
    vendorPrice = "Adds a vendor price to item tooltips only when one is missing. Applies the next time you hover an item.",
    questLevels = "Shows a level in brackets before quest titles in the right-hand quest tracker. Applies immediately.",
    bagSpace = "Shows empty bag slots on the backpack button at the end of the action bar. Filling an empty slot lowers the count; adding to an existing stack does not. Where the game has its own switch (Options > Interface: Show Free Bag Space), this is that setting, so both always match. Applies immediately.",
    classColors = "Colours player names in new chat messages by class. Untick to use the chat channel's colour. Earlier messages keep their original colours.",
    hideStatusMessages = "Hides EraUI's startup and setting-change notices immediately. Errors and replies to commands still appear. Messages already in chat stay visible.",
    afkScreen = "When you go AFK, the interface and the minimap fade away and EraUI shows its own AFK screen: the EraUI logo in your class colour, your character standing on the left, a card with your name, level, guild, zone, time away, local time and date, and a famous line for your class. Your character stays still while the camera slowly circles. Move, press a key or click to come back. It also closes when combat starts, a prompt appears or you are no longer AFK, and your camera and minimap come back as they were. On by default.",
    afkCameraNormal = "Circle the camera once a minute. Off circles once every two minutes.",
    afkTurnRight = "Circle the camera to the right. Off circles to the left.",
    afkZoom = "Gently zoom the camera in on your character over about 20 seconds. Your zoom returns when you come back. Skipped when the camera is already close.",
    afk24Hour = "Show the local time as a 24-hour clock, for example 15:07. Off shows 3:07 PM.",
    afkShowGuild = "Show your guild name on the AFK screen.",
    afkShowZone = "Show your zone and subzone on the AFK screen.",
    afkShowDate = "Show today's date on the AFK screen.",
    afkShowQuote = "A famous line from World of Warcraft Classic for your class, like a loading-screen tip. A new one each time you're away.",
    tooltipClassColours = "A player's tooltip shows their class colour on its border, their name and their class, for example a rogue's name and \"Rogue\" in rogue yellow. Works with EraUI's Classic tooltips or the game's own. NPCs and pets keep their usual colours, and if the game hides a player's class the tooltip stays as it is. Only colours change: the tooltip's lines are the game's. Applies the next time you hover a player. Off by default.",
    bagItemLevels = "Shows the item level of every piece of gear in your bags as a big number at the bottom right, in the item's quality colour: grey, white, green, blue or purple. Armour, rings, necks, cloaks, trinkets, relics and weapons get one (not bags, quivers, ammo, shirts or tabards). A small green arrow at the top right means it has a higher item level than what you wear in that slot, a red arrow a lower one. Rings, trinkets and, when you dual wield, one-hand weapons are compared with the weaker of the two you wear. Upgrade means item level only for now: stats, armour type and set bonuses are not compared. Gear you can't equip right now has its icon tinted red, using the game's own check, so it follows your level and the armour and weapon skills you learn, such as plate or mail at level 40. Works with Blizzard's bags, EraUI's Classic bags and One bag, not the bank yet. Applies immediately. Off by default.",
    darkAuraBorders = "A thin dark border around your own buff and debuff icons at the top right, including weapon enchants, to match Dark Mode. Debuffs keep their coloured border on top. Target and focus auras are drawn by the game's protected aura frames and keep their own look. Only EraUI's border is added: timers, tooltips and right-click cancelling are unchanged, in and out of combat. Requires Dark Mode. On by default, so choosing Dark Mode adds them; switch this off to keep plain icons. Applies immediately once Dark Mode is active.",
    darkAuraShadows = "A soft shadow round your own buff and debuff icons, just outside the dark border. It fades out in the gap between icons, so it never covers the next icon, and it sits under every timer and debuff border. Requires Dark Mode and Dark Aura Borders. Needs testing. On by default. Applies immediately once Dark Mode is active.",
    -- Fuller help for cards whose one-line summary is short.
    advancedCastBar = "Your own cast bar with the spell icon, cast time and latency. A preview appears while settings are open; hover + to move or resize it.",
    advancedCastClassFill = "Use a muted class colour instead of gold. Priests use dark silver so the text stays readable.",
    advancedCastTicks = "Marks the tick intervals given in the spell's description, when it gives them. Not every channelled spell does.",
    castBarClassBorder = "Class-coloured outlines for player, target, focus and player nameplate casts. NPCs stay unchanged.",
    mapQuestObjectives = "Show Blizzard's quest objectives on the world map. Updates the game's own map filter.",
    movableMap = "Drag the header to move the world map. Resize smoothly from the corners or edges. Normal and expanded map positions and sizes are remembered separately.",
    revealMap = "Show unexplored terrain with grey shading. Each section returns to normal colours when you explore it. Does not grant exploration credit. Turn off to restore the normal map.",
    autoQuests = "Accept quests and turn in completed quests with zero or one reward choice. Hold Shift to pause; multiple choices stay manual.",
    autoGossip = "Choose a single free dialogue option. Hold Shift to bypass. Leaves quests alone.",
    rewardUpgradeHighlight = "Suggest a usable reward using your chosen stat profile. You choose the reward.",
    trainingGuide = "Adds a training tab inside the Classic spellbook, filled at once with unlearned spells, required levels, availability groups and search. Reference cost totals mark unverified prices with ?. Requires Spellbook.",
    classicChatDragging = "Right-click General or a docked chat tab to unlock, drag and lock the chat window. Remembers your position and lock state.",
    tooltipSkin = "Classic dark backgrounds and grey borders for item, spell, unit and map-control tooltips, including item comparisons.",
    hideZoneText = "Hide the large zone and subzone announcements. Minimap names remain.",
    maxCameraZoom = "Raise the camera distance limit to 2.6. Scroll out as normal; switching it off restores your earlier limit.",
    cursorRing = "A ring follows your mouse pointer. Its colour, diameter and thickness options appear under it while it is on. Applies immediately.",
    cursorTrail = "A short, soft trail follows cursor movement and fades when you stop. Independent of both cursor rings. Its options appear under it while it is on.",
    questLog = "Classic quest log and its quest map pane.",
    bagsBank = "Classic bag and bank windows.",
    merchantSkin = "Classic merchant and buyback windows.",
    mailSkin = "Classic mailbox and letter windows.",
    auctionHouse = "Classic auction house window.",
    groupFinderPvp = "Classic group finder and PvP windows.",
    blizzardSettings = "Classic frame for the game's own Settings window.",
    updateCheck = "Tells you in chat when someone in your guild or group has a newer EraUI. The same switch as the Update Notice tick at the top right of /era, under Presets.",
}

local function HideSettingTooltip(owner)
    if GameTooltip and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end
end

local function UpdateReloadHint(frame)
    -- Called after every settings change: keep dependent options and the
    -- preset label current too.
    if frame.RefreshDependencies then frame:RefreshDependencies() end
    if frame.UpdatePresetLabel then frame:UpdatePresetLabel() end
    if frame.setupMode then
        frame.reloadHint:SetText("Your choices are saved as you go.")
        if frame.reloadButton then frame.reloadButton:Hide() end
        return
    end
    local pending = false
    for key in pairs(reloadSettings) do
        local enabled = EraUI:GetSavedSetting(key) and true or false
        if enabled ~= frame.loadedSettings[key] then pending = true; break end
    end
    frame.reloadHint:SetText(pending
        and "Changes saved. Click Reload UI to apply them."
        or "No reload needed for your current settings.")
    if frame.reloadButton then frame.reloadButton:SetShown(pending) end
end

local function ClassColour()
    local _, class = UnitClass("player")
    local colour = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if colour then return colour.r, colour.g, colour.b end
    return 0.7, 0.7, 0.7
end

local function Text(parent, value, size, muted)
    local text = parent:CreateFontString(nil, "OVERLAY")
    local font, _, flags = GameFontHighlight:GetFont()
    text:SetFont(font, size, flags or "")
    text:SetTextColor(muted and 0.58 or 0.94, muted and 0.62 or 0.95, muted and 0.68 or 0.98)
    text:SetJustifyH("LEFT")
    text:SetText(value)
    return text
end

local function PaintToggle(check)
    local enabled = check:GetChecked()
    local r, g, b = ClassColour()
    check.track:SetBackdropColor(enabled and r * 0.65 or 0.06,
        enabled and g * 0.65 or 0.07, enabled and b * 0.65 or 0.09, 1)
    check.track:SetBackdropBorderColor(enabled and r or 0.24,
        enabled and g or 0.26, enabled and b or 0.3, 1)
    check.thumb:ClearAllPoints()
    check.thumb:SetPoint(enabled and "RIGHT" or "LEFT", check.track,
        enabled and "RIGHT" or "LEFT", enabled and -3 or 3, 0)
    check.thumb:SetColorTexture(enabled and 0.98 or 0.48, enabled and 0.98 or 0.5,
        enabled and 1 or 0.55, 1)
    check.state:SetText(check.unavailable and "SOON" or enabled and "ON" or "OFF")
    check.state:SetTextColor(enabled and r or 0.58, enabled and g or 0.62, enabled and b or 0.68)
end

local featureIcons = {
    spellbookCombatDrag = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    autoQuests = "Interface\\Icons\\INV_Misc_ScrollInfo",
    autoSummon = "Interface\\Icons\\Spell_Shadow_Twilight",
    autoResurrect = "Interface\\Icons\\Spell_Holy_Resurrection",
    releasePvP = "Interface\\Icons\\Ability_DualWield",
    blockDuels = "Interface\\Icons\\Ability_DualWield",
    blockPartyInvites = "Interface\\Icons\\INV_Misc_GroupLooking",
    partyFromFriends = "Interface\\Icons\\INV_Misc_GroupLooking",
    inviteFromWhispers = "Interface\\Icons\\INV_Letter_15",
    hideKeybindText = "Interface\\Icons\\INV_Misc_StoneTablet_01",
    hideMacroText = "Interface\\Icons\\INV_Misc_Note_01",
    hideZoneText = "Interface\\Icons\\INV_Misc_Map_01",
    maxCameraZoom = "Interface\\Icons\\Spell_Nature_FarSight",

    fastAutoLoot = "Interface\\Icons\\INV_Misc_TreasureChest01",
    autoGossip = "Interface\\Icons\\INV_Misc_Note_01",
    durabilityWarning = "Interface\\Icons\\Trade_BlackSmithing",
    tooltipIDs = "Interface\\Icons\\INV_Misc_QuestionMark",
    junkValueSummary = "Interface\\Icons\\INV_Misc_Coin_01",
    showWelcomeOnLogin = "Interface\\Icons\\INV_Letter_15",
    matchFocusSize = "Interface\\Icons\\Ability_Hunter_SniperShot",
    actionBars = "Interface\\Icons\\Ability_Warrior_BattleShout",
    castBars = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    unitFrames = "Interface\\Icons\\INV_Helmet_03",
    minimap = "Interface\\Icons\\INV_Misc_Map_01",
    friendlyNameplates = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
    enemyNameplates = "Interface\\Icons\\Ability_Creature_Cursed_02",
    disableAggroHighlight = "Interface\\Icons\\Ability_Warrior_Challange",
    characterPanel = "Interface\\Icons\\INV_Chest_Plate04",
    talentWindow = "Interface\\Icons\\Ability_Marksmanship",
    spellbook = "Interface\\Icons\\INV_Misc_Book_09",
    questDialogs = "Interface\\Icons\\INV_Misc_Note_01",
    questTracker = "Interface\\Icons\\INV_Misc_ScrollInfo",
    questLog = "Interface\\Icons\\INV_Misc_Book_11",
    professions = "Interface\\Icons\\Trade_BlackSmithing",
    trainer = "Interface\\Icons\\Trade_Engineering",
    bagsBank = "Interface\\Icons\\INV_Misc_Bag_08",
    merchantSkin = "Interface\\Icons\\INV_Misc_Coin_01",
    mailSkin = "Interface\\Icons\\INV_Letter_15",
    auctionHouse = "Interface\\Icons\\INV_Misc_Coin_02",
    socialWindows = "Interface\\Icons\\INV_Misc_GroupLooking",
    groupFinderPvp = "Interface\\Icons\\Ability_Warrior_BattleShout",
    gameMenu = "Interface\\Icons\\INV_Misc_Gear_01",
    blizzardSettings = "Interface\\Icons\\Trade_Engineering",
    tooltipSkin = "Interface\\Icons\\INV_Misc_Note_05",
    contextMenus = "Interface\\Icons\\INV_Misc_Note_02",
    popups = "Interface\\Icons\\INV_Misc_QuestionMark",
    lootWindow = "Interface\\Icons\\INV_Misc_TreasureChest01",
    vendorPrice = "Interface\\Icons\\INV_Misc_Coin_01",
    bagSpace = "Interface\\Icons\\INV_Misc_Bag_10",
    questLevels = "Interface\\GossipFrame\\AvailableQuestIcon",
    cleanMinimap = "Interface\\Icons\\Spell_Nature_FarSight",
    coordinates = "Interface\\Icons\\INV_Misc_Map_01",
    showAllSpellRanks = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    gryphons = "Interface\\Icons\\Ability_Mount_Gryphon_01",
    hideEmptyActionSlots = "Interface\\Icons\\INV_Misc_StoneTablet_01",
    autoSellJunk = "Interface\\Icons\\INV_Misc_Coin_05",
    autoRepair = "Interface\\Icons\\Trade_BlackSmithing",
    hideSecondaryNames = "Interface\\Icons\\INV_Misc_Idol_03",
    classColors = "Interface\\Icons\\INV_Misc_Desecrated_ClothShoulder",
    hideStatusMessages = "Interface\\Icons\\Spell_Shadow_Silence",
}

-- A switch card. Its tab and place come from the page lists in Initialize.
local function MakeCheck(parent, label, key, icon, summary, unavailable)
    local check = CreateFrame("CheckButton", nil, parent)
    check.searchText = string.lower(label .. " " .. (summary or "") .. " " .. key)
    check:SetSize(350, 74)
    local separator = check:CreateTexture(nil, "BACKGROUND")
    separator:SetPoint("TOPLEFT")
    separator:SetPoint("TOPRIGHT")
    separator:SetHeight(1)
    separator:SetColorTexture(0.14, 0.15, 0.18, 1)
    local highlight = check:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.035)
    local picture = check:CreateTexture(nil, "ARTWORK")
    picture:SetSize(28, 28)
    picture:SetPoint("TOPLEFT", 8, -18)
    picture:SetTexture(featureIcons[key] or ("Interface\\Icons\\" .. icon))
    if key ~= "questLevels" then picture:SetTexCoord(0.07, 0.93, 0.07, 0.93) end
    if key=="energyBar" or key=="floatingComboPoints" or key=="swingTimer" or key=="rageBar" or key=="manaBar" or key=="druidResourceBar" or key=="rangedSwingTimer" then
        local _,class=UnitClass("player")
        picture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        local coords=classIconCoords[class] or classIconCoords.ROGUE
        picture:SetTexCoord(unpack(coords))
    end
    check.text = Text(check, label, 14)
    check.text:SetPoint("TOPLEFT", 46, -10)
    check.text:SetWidth(244)
    check.text:SetWordWrap(true)
    check.text:SetHeight(30)
    check.text:SetJustifyV("TOP")
    local description = Text(check, summary, 12, true)
    check.description = description
    description:SetPoint("TOPLEFT", 46, -40)
    description:SetWidth(244)
    description:SetHeight(26)
    description:SetJustifyV("TOP")
    check.track = CreateFrame("Frame", nil, check, "BackdropTemplate")
    check.track:SetSize(42, 22)
    check.track:SetPoint("TOPRIGHT", -8, -18)
    check.track:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    check.thumb = check.track:CreateTexture(nil, "ARTWORK")
    check.thumb:SetSize(16, 16)
    check.state = Text(check, "", 10, true)
    check.state:SetPoint("TOP", check.track, "BOTTOM", 0, -5)
    local checked = EraUI:GetSavedSetting(key) and true or false
    if EraUI.charSettingKeys and EraUI.charSettingKeys[key] then
        checked = EraUI:GetCharSetting(key) and true or false
    end
            
            check:SetChecked(not check.unavailable and checked)
            if check.unavailable then check.state:SetText("SOON") end
    hooksecurefunc(check, "SetChecked", PaintToggle)
    PaintToggle(check)
    local function ShowSettingTooltip(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(label, ClassColour())
        if check.dependencyDisabled then
            -- Names the switch, and its tab when that is another one.
            local missing = MissingParent(key) or Parents(key)[1]
            local name = DEPEND_NAMES[missing] or "its parent option"
            local owner = parent.checks[missing]
            local tab = owner and owner.category ~= check.category and parent.categories and parent.categories[owner.category]
            if tab then name = name .. " on the " .. tab.name .. " tab" end
            GameTooltip:AddLine("Enable " .. name .. " to use this feature.",1,.82,.3,true)
        end
        GameTooltip:AddLine(settingHelp[key] or summary, 1, 1, 1, true)
        if unavailable then
            GameTooltip:AddLine("Coming soon - not finished yet.",1,.82,0,true)
        elseif reloadSettings[key] then
            GameTooltip:AddLine("Requires /reload to apply or restore native appearance. Until then, your current appearance stays active.",1,.82,0,true)
        end
        local default = EraUI.settingDefaults[key]
        GameTooltip:AddLine((key=="showAllSpellRanks" or (EraUI.cvarSettings and EraUI.cvarSettings[key])) and "Default: keep your existing game preference."
            or ("Default: " .. (default and "On" or "Off")),.7,.7,.7,true)
        GameTooltip:Show()
    end
    check:HookScript("OnEnter", ShowSettingTooltip)
    check:HookScript("OnLeave", HideSettingTooltip)
    check:HookScript("OnHide", HideSettingTooltip)
    if DEPENDS[key] then
        -- Disabled buttons do not reliably receive mouse motion on every client.
        -- A motion-only cover retains the explanation without enabling clicks.
        local cover=CreateFrame("Frame",nil,check)
        cover:SetAllPoints();cover:EnableMouse(true)
        cover:SetFrameLevel((check:GetFrameLevel()or 0)+1)
        cover:SetScript("OnEnter",ShowSettingTooltip)
        cover:SetScript("OnLeave",HideSettingTooltip)
        cover:SetScript("OnHide",HideSettingTooltip)
        cover:Hide();check.dependencyHelp=cover
    end
    parent.checks[key] = check
    check.unavailable = unavailable
    if unavailable then
        check:SetEnabled(false)
        check:SetChecked(false)
        check.state:SetText("SOON")
        check.text:SetTextColor(.58,.62,.68)
    end
    check:SetScript("OnClick", function(self)
        if unavailable or self.dependencyDisabled then return end
        PaintToggle(self)
        local charKey = EraUI.charSettingKeys and EraUI.charSettingKeys[key]
        local previous
        if charKey then previous = EraUI:GetCharSetting(key) else previous = EraUI:GetSavedSetting(key) end
        local value = self:GetChecked() and true or false
        if charKey then EraUI:SetCharSetting(key, value) else EraUI:SetSetting(key, value) end
        UpdateReloadHint(parent)
        if parent.setupMode and reloadSettings[key] then return end
        if AFK_KEYS[key] then
            if EraUI.modules.AFKScreen then EraUI.modules.AFKScreen:Refresh() end
            if key=="afkScreen" then EraUI:Status(value and "AFK Screen enabled. Type /era afk to preview it." or "AFK Screen disabled.")
            else EraUI:Status(label:gsub(" %(Needs testing%)$","")..(value and " enabled." or " disabled.")) end
            return
        end
        if key=="darkAuraBorders" or key=="darkAuraShadows" then
            if EraUI.modules.AuraStyle then EraUI.modules.AuraStyle:RefreshBorders() end
            EraUI:Status((key=="darkAuraShadows" and "Aura Shadows " or "Dark Aura Borders ")..(value and "enabled." or "disabled.")
                ..(value and not EraUI:GetSetting("darkMode") and " They show once Dark Mode is applied." or ""))
            return
        end
        if key=="tooltipClassColours" then
            if EraUI.modules.AuraStyle then EraUI.modules.AuraStyle:RefreshClassTooltips() end
            EraUI:Status("Class-coloured Tooltips "..(value and "enabled. Hover a player to see it." or "disabled."))
            return
        end
        if key=="bagItemLevels" then
            if EraUI.modules.BagItemLevels then EraUI.modules.BagItemLevels:Refresh() end
            EraUI:Status("Bag Item Levels "..(value and "enabled. Open your bags to see it." or "disabled."))
            return
        end
        -- Its folded options open or close under it at once.
        if FOLD_PARENTS[key] and parent.RefreshFolds then parent:RefreshFolds() end
        if key=="cursorRing" or key=="cursorRingClassColour" then
            if EraUI.modules.CursorRing then EraUI.modules.CursorRing:Refresh()end
            if EraUI.modules.CursorEffects then EraUI.modules.CursorEffects:Refresh()end
            return
        end
        if key=="cursorCastRing" or key=="cursorCastClassColour" or key=="cursorTrail" or key=="cursorTrailClassColour" then
            if EraUI.modules.CursorEffects then EraUI.modules.CursorEffects:Refresh()end
            return
        end
        -- Search's copy of the Update notice tick under Presets; the reload
        -- hint refresh above (UpdatePresetLabel) keeps the tick in step.
        if key=="updateCheck" then
            EraUI:Status("Update Notice "..(value and "on." or "off."))
            return
        end
        if key=="portraitDebuffs" then
            if EraUI.modules.PortraitDebuffs then EraUI.modules.PortraitDebuffs:Refresh() end
            return
        end
        if key=="advancedCastBar" or key=="advancedCastClassFill" or key=="advancedCastLatency" or key=="advancedCastTicks" then
            if key=="advancedCastBar" and not value then
                for _,dependent in ipairs({"advancedCastTicks","advancedCastLatency"}) do
                    EraUI:SetSetting(dependent,false);parent.checks[dependent]:SetChecked(false)
                end
            end
            if parent.RefreshCastDependencies then parent:RefreshCastDependencies()end
            if EraUI.modules.AdvancedCastBar then EraUI.modules.AdvancedCastBar:Refresh()end
            return
        end
        if key=="castBarClassBorder" then
            if EraUI.modules.AdvancedCastBar then EraUI.modules.AdvancedCastBar:Refresh()end
            if EraUI.modules.ClassAccents then EraUI.modules.ClassAccents:Refresh() end
            return
        end
        if key=="poisonReminders" then
            if EraUI.modules.PoisonReminders then EraUI.modules.PoisonReminders:Refresh()end
            local reminders=EraUI.modules.ClassReminders
            if reminders then reminders:Refresh();reminders:UpdateOptionsState()end
            return
        end
        if key=="hunterFeed" or key=="mageSupplies" or key=="mageAutoTrade" or key=="roguePoisons" or key=="classReminders" then
            local tools=EraUI.modules.ClassTools
            if tools then tools:Refresh() end
            return
        end
        if key=="mapQuestObjectives" or key=="rewardUpgradeHighlight" then
            local tools=EraUI.modules.QuestTools
            if tools then if key=="mapQuestObjectives" then tools:ApplyMap() else tools:RefreshRewards() end end
            return
        end
        if key=="rageBar" or key=="manaBar" or key=="druidResourceBar" then
            if EraUI.modules.ResourceBar then EraUI.modules.ResourceBar:Refresh() end
            return
        end
        if key=="rangedSwingTimer" then
            if EraUI.modules.RangedSwingTimer then EraUI.modules.RangedSwingTimer:Refresh() end
            return
        end
        if key=="swingTimer" then
            if EraUI.modules.SwingTimer then EraUI.modules.SwingTimer:Refresh() end
            return
        end
        if key=="energyBar" then
            if EraUI.modules.EnergyBar then EraUI.modules.EnergyBar:Refresh() end
            return
        end
        local applied = false
        if EraUI.convenienceSettings and EraUI.convenienceSettings[key] then
            if EraUI.modules.Convenience then EraUI.modules.Convenience:Refresh() end
            EraUI:Status(label .. (value and " enabled." or " disabled.") .. (InCombatLockdown() and " Applies after combat." or ""))
            return
        end
        if key == "durabilityWarning" and EraUI.modules.ExtraQoL then EraUI.modules.ExtraQoL:CheckDurability() end
        if key == "fastAutoLoot" or key == "discardCheapestJunk" or key == "autoGossip" or key == "durabilityWarning" or key == "tooltipIDs" or key == "junkValueSummary" or key == "showWelcomeOnLogin" or key == "linkToggle" then
            EraUI:Status(label .. (value and " enabled." or " disabled.")); return
        end
        if key == "coordinates" and EraUI.modules.MinimapTools then
            EraUI.modules.MinimapTools:UpdateCoordinates()
            applied = true
        elseif key == "showAllSpellRanks" then
            if InCombatLockdown() then
                EraUI:SetSetting(key,previous);self:SetChecked(previous)
                EraUI:Print("Finish combat before changing spell ranks.");return
            end
            SetCVar("ShowAllSpellRanks",value and "1" or "0")
            if EraUI.SyncClassicQoL then EraUI:SyncClassicQoL() end
            applied = true
        elseif EraUI.cvarSettings and EraUI.cvarSettings[key] then
            -- The game's own portrait switch: set it, read it back, then
            -- redraw the portraits at once. If the game keeps the switch for
            -- its Options window, or kept its old value, the card follows the
            -- game and says where to change it (two lines, so a test in game
            -- tells which happened).
            local cvar = EraUI.cvarSettings[key]
            if InCombatLockdown() then
                EraUI:SetSetting(key,previous);self:SetChecked(previous);PaintToggle(self)
                EraUI:Print("Finish combat before changing portraits.");return
            end
            if GameOnlySwitch(cvar) then
                EraUI:SetSetting(key,previous);self:SetChecked(previous);PaintToggle(self)
                EraUI:Print("Only Options > Interface can change this portrait setting.");return
            end
            local wrote = pcall(SetCVar,cvar,value and "1" or "0")
            local now = GameSwitch(cvar)
            if not wrote or now == nil then
                EraUI:SetSetting(key,previous);self:SetChecked(previous);PaintToggle(self)
                EraUI:Print("This game version doesn't have that portrait setting.");return
            end
            if now ~= value then
                EraUI:SetSetting(key,now);self:SetChecked(now);PaintToggle(self)
                EraUI:Print("The game kept its own portrait setting. Change it in Options > Interface.");return
            end
            RedrawPortraits()
            applied = true
        elseif key == "cleanMinimap" and EraUI.modules.MinimapTools then
            EraUI.modules.MinimapTools:Discover()
            EraUI.modules.MinimapTools:Refresh()
            applied = true
        elseif key == "hideStatusMessages" then
            applied = true
        elseif key == "classColors" then
            local qol = EraUI.modules.QoL
            if not qol or not qol:ApplyChatClassColors() then
                EraUI:SetSetting(key, previous)
                self:SetChecked(previous and true or false)
                EraUI:Print("Could not change class colours in chat on this client.")
                return
            end
            EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled") .. ". Applies to new chat messages.")
            return
        elseif key == "bagSpace" and EraUI.modules.QoL then
            EraUI.modules.QoL:UpdateBagSpace()
            applied = true
        elseif key == "questLevels" and EraUI.modules.QoL then
            EraUI.modules.QoL:RefreshQuestLevels()
            applied = true
        elseif key == "hideSecondaryNames" and EraUI.modules.SecondaryNames then
            EraUI.modules.SecondaryNames:Apply()
            applied = true
        elseif key == "hideEmptyActionSlots" and EraUI.modules.ActionBars then
            EraUI.modules.ActionBars:RefreshEmptySlots()
            applied = true
        elseif key == "gryphons" and EraUI.modules.ActionBars then
            EraUI.modules.ActionBars:ApplyGryphons(_G.MainActionBar or _G.MainMenuBar)
            EraUI:Status(self:GetChecked() and "Gryphons shown." or "Gryphons hidden.")
            return
        elseif key == "comboPointRed" then
            applied = true
            if EraUI.Classic and EraUI.Classic.RefreshComboPointColor then EraUI.Classic.RefreshComboPointColor() end
        elseif key == "movableMap" then
            applied = true
            if EraUI.modules.MovableMap then EraUI.modules.MovableMap:Apply() end
        elseif key == "revealMap" then
            applied = true -- MapReveal responds to SetSetting immediately.
        elseif key == "autoSellJunk" or key == "autoRepair" then
            EraUI:Status(label .. " applies on your next merchant visit."); return
        elseif key == "vendorPrice" then
            EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled") .. ". Applies on your next item hover.")
            return
        end
        if applied then
            EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled") .. ".")
            return
        end
        local changed = (self:GetChecked() and true or false) ~= parent.loadedSettings[key]
        EraUI:Status(label .. " " .. (self:GetChecked() and "enabled" or "disabled")
            .. (changed and ". Click Reload UI to apply." or ". Restored the loaded setting."))
    end)
    return check
end

function SettingsModule:Initialize()
    -- The class and Casting tab hints, saved by tab number. Runs after both the
    -- onboarding CVar and the recovery backup have loaded. Setup finished before
    -- the hints existed gets them (the onboarding CVar stores no version as 0);
    -- version 1 (the old order, where your class was 12 and Casting 13) moves
    -- to the tabs' places now.
    local onboarding=EraUIClassicCharDB and EraUIClassicCharDB.onboarding
    if onboarding then
        local migrated=false
        if onboarding.setupComplete and (onboarding.discoveryHintsVersion or 0)==0 then
            onboarding.discoverTabs={[TAB.class]=true,[TAB.casting]=true}
            migrated=true
        elseif onboarding.discoveryHintsVersion==1 then
            local old=type(onboarding.discoverTabs)=="table" and onboarding.discoverTabs or {}
            local tabs={}
            if old[12] then tabs[TAB.class]=true end
            if old[13] then tabs[TAB.casting]=true end
            onboarding.discoverTabs=tabs
            migrated=true
        end
        if migrated then
            onboarding.discoveryHintsVersion=HINTS_VERSION
            if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
        end
    end
    if self.frame then return end

    local frame = CreateFrame("Frame", "EraUISettingsFrame", UIParent, "BackdropTemplate")
    frame.checks = {}
    frame.loadedSettings = {}
    for key in pairs(reloadSettings) do
        frame.loadedSettings[key] = EraUI:GetSetting(key) and true or false
    end
    frame:SetSize(WINDOW_WIDTH, 650)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self)self.settingsMoving=true;self:StartMoving()end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();self.settingsMoving=false
        if self.RefreshInlineActions then self:RefreshInlineActions()end
    end)
    frame:SetScript("OnUpdate",function(self)
        if self.settingsMoving and self.RefreshInlineActions then self:RefreshInlineActions()end
    end)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "EraUISettingsFrame") end
    frame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    frame:SetBackdropColor(0.026, 0.029, 0.037, 1)
    frame:SetBackdropBorderColor(0.19, 0.20, 0.24, 1)

    local navigation = frame:CreateTexture(nil, "BACKGROUND")
    navigation:SetPoint("TOPLEFT", 1, -1)
    navigation:SetPoint("BOTTOMLEFT", 1, 1)
    navigation:SetWidth(NAV_WIDTH)
    navigation:SetColorTexture(0.014, 0.016, 0.022, 1)
    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", NAV_WIDTH + 1, -1)
    divider:SetPoint("BOTTOMLEFT", NAV_WIDTH + 1, 64)
    divider:SetWidth(1)
    divider:SetColorTexture(0.14, 0.15, 0.18, 1)
    frame.navigation,frame.navDivider=navigation,divider

    local title = Text(frame, "EraUI", 26)
    title:SetPoint("TOPLEFT", 24, -20)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(36, 36)
    close:SetPoint("TOPRIGHT", -12, -12)
    local closeLabel = Text(close, "X", 20, true)
    closeLabel:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)
    close:SetScript("OnEnter", function() closeLabel:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() closeLabel:SetTextColor(0.58, 0.62, 0.68) end)

    local className,classToken=UnitClass("player")
    local meleeClasses={ROGUE=true,DRUID=true,WARRIOR=true,PALADIN=true,SHAMAN=true,HUNTER=true}
    local manaClasses={HUNTER=true,MAGE=true,PRIEST=true,WARLOCK=true,PALADIN=true,SHAMAN=true}
    local rangedClasses={HUNTER=true,ROGUE=true,WARRIOR=true,MAGE=true,PRIEST=true,WARLOCK=true}
    local hasClassControls=meleeClasses[classToken] or manaClasses[classToken]
    -- One home per topic: each tab is one thing a player thinks of ("my
    -- bags", "the map"), with a one-line description under its title.
    local TABS={
        appearance={name="Appearance",icon="Interface\\Icons\\INV_Misc_Desecrated_ClothShoulder",
            about="Your look: Classic or Dark Mode, and class colours."},
        class={name=className,about="Your class tools and reminders."},
        actionBars={name="Action Bars",icon="Interface\\Icons\\Ability_Warrior_BattleShout",
            about="The stone bar and everything on it."},
        frames={name="Frames & Nameplates",icon="Interface\\Icons\\INV_Helmet_03",
            about="Unit frames, portraits and nameplates."},
        casting={name="Casting",icon="Interface\\Icons\\Spell_Arcane_Blast",
            about="Cast bars and cast details."},
        map={name="Map & Minimap",icon="Interface\\Icons\\INV_Misc_Map_01",
            about="The minimap and world map."},
        quests={name="Quests",icon="Interface\\GossipFrame\\AvailableQuestIcon",
            about="Quest windows and helpers."},
        character={name="Character & Spells",icon="Interface\\Icons\\INV_Chest_Plate04",
            about="Your character, talents and spellbook."},
        bags={name="Bags & Vendors",icon="Interface\\Icons\\INV_Misc_Bag_08",
            about="Bags, loot and selling."},
        chat={name="Chat & Names",icon="Interface\\Icons\\INV_Letter_15",
            about="Chat and how names show."},
        group={name="Group & Invites",icon="Interface\\Icons\\INV_Misc_GroupLooking",
            about="Friends, groups, invites and summons."},
        windows={name="Windows & Tooltips",icon="Interface\\Icons\\INV_Misc_Gear_01",
            about="Menus, popups, tooltips and more."},
        screen={name="Screen & Cursor",icon="Interface\\Icons\\Spell_Nature_FarSight",
            about="Camera, damage text, cursor and AFK."},
        more={name="More from Squirt",icon="Interface\\Icons\\INV_Misc_Gift_02",
            about="My other addons."},
    }
    local categories={}
    for index,id in ipairs(TAB_IDS)do TABS[id].id=id;categories[index]=TABS[id] end
    frame.tabIds,frame.tabIndex,frame.categories=TAB_IDS,TAB,categories
    local ResetSearch, ApplySearch
    local classOrder
    local RenderAppearance
    -- Each tab's cards in reading order (two per row); filled in once the
    -- cards exist. "#" entries are section labels.
    local PAGES
    local section = Text(frame, "", 24)
    section:SetPoint("TOPLEFT", PAGE_LEFT, -38)
    local about = Text(frame, "", 12, true)
    about:SetPoint("TOPLEFT", PAGE_LEFT, -68);about:SetWidth(560);about:SetWordWrap(false)
    frame.sectionTitle,frame.sectionAbout=section,about
    frame.sectionLabels={}
    local searchTags={}
    -- A tab's cards as they show: folded options only once their switch is
    -- on, class cards only for your class. skip leaves cards out (setup);
    -- extra adds a card after another (setup).
    local function PageEntries(index,skip,extra)
        local out={}
        local function Add(key)
            local entry=frame.checks[key] or frame.sectionLabels[key]
            if not entry or entry.classAllowed==false or Folded(key) or (skip and skip(key)) then return end
            out[#out+1]=entry
        end
        for _,key in ipairs(PAGES[categories[index].id])do
            Add(key)
            if extra and extra[key] then Add(extra[key]) end
        end
        return out
    end
    -- Shows exactly these entries and lays them out; pad leaves room above
    -- each card for its tab name (search).
    local function ShowEntries(entries,reset,pad)
        local wanted={}
        for _,entry in ipairs(entries)do wanted[entry]=true end
        for _,check in pairs(frame.checks)do check:SetShown(wanted[check]==true)end
        for _,label in pairs(frame.sectionLabels)do label:SetShown(wanted[label]==true)end
        for _,tag in pairs(searchTags)do tag:Hide()end
        -- A card with its options on show starts a row, so they follow it
        -- from the left column. Search lists its results as they come.
        local breaks={}
        if not pad then
            local shown={}
            for _,entry in ipairs(entries)do if entry.settingKey then shown[entry.settingKey]=entry end end
            for key in pairs(shown)do
                local owner=shown[GroupParent(key) or ""]
                if owner then breaks[owner]=true end
            end
        end
        frame.settingsBreaks=breaks
        frame.settingsPad=pad
        frame.settingsEntries=entries
        if frame.LayoutSettings then frame:LayoutSettings(reset)end
    end
    local tabs = {}
    local function SelectCategory(index, keepSearch, entries)
        if ResetSearch and not keepSearch then ResetSearch() end
        frame.selectedCategory = index
        section:SetText(categories[index].name)
        about:SetText(categories[index].about)
        local r, g, b = ClassColour()
        for i, tab in ipairs(tabs) do
            local active = i == index
            tab.underline:SetColorTexture(r, g, b, 1)
            tab.underline:SetShown(active)
            tab.selected:SetColorTexture(r, g, b, active and 0.12 or 0)
            tab.text:SetTextColor(active and r or 0.58, active and g or 0.62, active and b or 0.68)
        end
        ShowEntries(entries or PageEntries(index),true)
    end
    -- Folded options open or close under their switch, keeping the scroll.
    function frame:RefreshFolds()
        if self.searching then return end -- search always lists them
        if self.setupMode then
            if self.walkEntries then ShowEntries(self.walkEntries(),false) end
            return
        end
        ShowEntries(PageEntries(self.selectedCategory or 1),false)
    end
    for i, category in ipairs(categories) do
        local index = i
        local tab = CreateFrame("Button", nil, frame)
        tab.id=category.id
        -- Fourteen tabs fit above the footer at 34 high.
        tab:SetSize(TAB_WIDTH, 34)
        tab:SetPoint("TOPLEFT", 12, -104 - (i - 1) * 34)
        tab.text = Text(tab, category.name, 14)
        tab.text:SetPoint("LEFT", 36, 0)
        tab.text:SetPoint("RIGHT", -2, 0)
        tab.text:SetWordWrap(false)
        tab.text:SetFont(select(1, GameFontHighlight:GetFont()), 13, "")
        tab.underline = tab:CreateTexture(nil, "ARTWORK")
        tab.underline:SetPoint("TOPLEFT", 0, -6)
        tab.underline:SetPoint("BOTTOMLEFT", 0, 6)
        tab.underline:SetWidth(3)
        tab.selected = tab:CreateTexture(nil, "BACKGROUND")
        tab.selected:SetAllPoints()
        local navIcon = tab:CreateTexture(nil, "ARTWORK")
        navIcon:SetSize(20,20)
        navIcon:SetPoint("LEFT",10,0)
        if category.id=="class" then
            navIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
            navIcon:SetTexCoord(unpack(classIconCoords[classToken] or classIconCoords.ROGUE))
        else navIcon:SetTexture(category.icon) end
        tab.icon=navIcon
        local hover = tab:CreateTexture(nil, "HIGHLIGHT")
        hover:SetAllPoints()
        hover:SetColorTexture(1,1,1,0.04)
        if category.id=="class" or category.id=="casting" then
            local hint=tab:CreateTexture(nil,"BACKGROUND",nil,1)
            hint:SetAllPoints()
            local r,g,b=ClassColour()
            hint:SetColorTexture(r,g,b,1)
            hint:Hide()
            tab.hint=hint
            local elapsed=0
            tab:SetScript("OnUpdate",function(_,dt)
                elapsed=elapsed+dt
                local state=EraUIClassicCharDB and EraUIClassicCharDB.onboarding
                local pending=state and state.discoverTabs and state.discoverTabs[index]
                hint:SetShown(not frame.setupMode and pending==true and frame.selectedCategory~=index)
                if pending then hint:SetAlpha(.055+.03*(.5+.5*math.sin(elapsed*2)))end
            end)
        end
        tab:SetScript("OnClick", function()
            local state=EraUIClassicCharDB and EraUIClassicCharDB.onboarding
             if state and state.discoverTabs then state.discoverTabs[index]=nil end
             if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
            SelectCategory(index)
        end)
        tabs[i] = tab
    end
    frame.tabs=tabs
    -- Section labels, in EraUI's small class-coloured capitals. Full width
    -- starts a new row; half width sits over one column.
    local function SectionLabel(id,text,wide)
        local label=CreateFrame("Frame",nil,frame)
        label:SetSize(wide and 716 or 350,22)
        label.isSection,label.fullWidth=true,wide or nil
        label.text=Text(label,text,11);label.text:SetPoint("BOTTOMLEFT",8,4)
        label.text:SetTextColor(ClassColour())
        frame.sectionLabels[id]=label
    end
    SectionLabel("#darkExtras","DARK MODE EXTRAS")
    SectionLabel("#classColours","CLASS COLOURS")
    SectionLabel("#bagsLoot","BAGS & LOOT",true)
    SectionLabel("#vendors","VENDORS",true)
    -- The Classic / Dark Mode choice heads Appearance as a full-width row that
    -- scrolls with the cards. Its two buttons are added with the setup choices.
    local choiceRow=CreateFrame("Frame",nil,frame)
    choiceRow:SetSize(716,92);choiceRow.fullWidth=true
    choiceRow.searchText="appearance style look theme classic dark mode artwork"
    frame.checks.appearanceChoice=choiceRow

    -- Cards, grouped by the tab they live on. Where each one shows comes from
    -- the page lists after the cards (PAGES), not from here.
    -- Appearance: Dark Mode extras and class colours.
    MakeCheck(frame, "Dark Aura Borders", "darkAuraBorders", "Spell_Holy_WordFortitude", "Thin dark borders around your buff and debuff icons. Dark Mode only.", false)
    MakeCheck(frame, "Aura Shadows (Needs testing)", "darkAuraShadows", "Ability_Stealth", "A soft shadow behind your buff and debuff icons. Needs Dark Aura Borders.", false)
    MakeCheck(frame, "Class-coloured Unit Borders", "classColourBorders", "INV_Misc_ArmorKit_17", "Class-coloured unit frame borders. Needs Dark Mode and Unit Frames.", false)
    MakeCheck(frame, "Class-coloured Chat Names", "classColors", "INV_Misc_Book_09", "Colour new player names by class.", false)
    MakeCheck(frame, "Class-coloured Tooltips", "tooltipClassColours", "INV_Misc_ArmorKit_17", "Player tooltips: border, name and class in the player's class colour.", false)
    MakeCheck(frame, "Class-coloured Cast Border", "castBarClassBorder", "Spell_Arcane_Blast", "Class-coloured outlines on players' cast bars. NPCs keep theirs.", false)
    -- Action Bars.
    MakeCheck(frame, "Action Bars", "actionBars", "INV_Misc_Book_09", "Stone dock and Classic action buttons.", false)
    MakeCheck(frame, "Show Gryphons", "gryphons", "INV_Misc_Book_09", "Show action-bar end decorations.", false)
    MakeCheck(frame, "Hide Empty Action Slots", "hideEmptyActionSlots", "INV_Misc_Book_09", "Reveal empty slots when arranging spells.", false)
    MakeCheck(frame, "Hide Keybind Text", "hideKeybindText", "INV_Misc_StoneTablet_01", "Hide action-button key labels; bindings still work. Combat changes wait.", false)
    MakeCheck(frame, "Hide Macro Names", "hideMacroText", "INV_Misc_Note_01", "Hide action-button macro names. Combat changes wait.", false)
    -- Frames & Nameplates.
    MakeCheck(frame, "Unit Frames", "unitFrames", "INV_Misc_Book_09", "Player, target and focus styling.", false)
    MakeCheck(frame, "Match Focus Size", "matchFocusSize", "INV_Misc_Book_09", "Use target size for focus. Reload to apply; off uses your native layout.", false)
    MakeCheck(frame, "Hide Aggro Highlight", "disableAggroHighlight", "INV_Misc_Book_09", "Hide unit-frame threat decoration.", false)
    MakeCheck(frame, "Important Debuffs on Portraits", "portraitDebuffs", "Spell_Nature_Polymorph", "CC icons and countdowns, even in combat. The icon covers the level badge.", false)
    MakeCheck(frame, "Class Icon Portraits: Mine", "classIconPortraitMine", "Spell_Nature_Polymorph", "Your class icon instead of your face.", false)
    MakeCheck(frame, "Class Icon Portraits: Others", "classIconPortraitOthers", "Spell_Nature_Polymorph", "Other players' class icons instead of faces.", false)
    MakeCheck(frame, "Friendly Nameplates", "friendlyNameplates", "INV_Misc_Book_09", "Classic look on friendly nameplates.", false)
    MakeCheck(frame, "Enemy Nameplates", "enemyNameplates", "INV_Misc_Book_09", "Classic look on enemy and neutral nameplates.", false)
    -- Casting.
    MakeCheck(frame, "Cast Bars", "castBars", "INV_Misc_Book_09", "Player, target, focus, boss and nameplate casts.", false)
    MakeCheck(frame, "Advanced Cast Bar", "advancedCastBar", "Spell_Arcane_Blast", "Icon, time and latency. Hover + on its preview to move or resize.", false)
    MakeCheck(frame, "Class-coloured Cast Fill", "advancedCastClassFill", "INV_Misc_ArmorKit_17", "A muted class colour instead of gold. Priests get dark silver.", false)
    MakeCheck(frame, "Channel Tick Marks", "advancedCastTicks", "Spell_Shadow_DrainSoul", "Tick marks on channels, when the spell's text gives them.", false)
    MakeCheck(frame, "Latency Zone", "advancedCastLatency", "INV_Misc_PocketWatch_01", "Red end zone based on world latency. Shown when cast duration is readable.", false)
    -- Map & Minimap.
    MakeCheck(frame, "Minimap", "minimap", "INV_Misc_Book_09", "Classic round map and controls.", false)
    MakeCheck(frame, "Clean Minimap", "cleanMinimap", "INV_Misc_Book_09", "Addon buttons appear on hover.", false)
    MakeCheck(frame, "Coordinates", "coordinates", "INV_Misc_Book_09", "Your map position beneath the minimap.", false)
    MakeCheck(frame, "Map Quest Objectives", "mapQuestObjectives", "INV_Misc_Map_01", "Blizzard's quest objectives on the world map.", false)
    MakeCheck(frame, "Movable World Map", "movableMap", "INV_Misc_Map_03", "Drag the header to move; resize from the corners and edges.", false)
    MakeCheck(frame, "Reveal World Map", "revealMap", "INV_Misc_Map_02", "Show unexplored areas in grey. No exploration credit.", false)
    -- Quests.
    MakeCheck(frame, "Quest Log", "questLog", "INV_Misc_Book_09", "Classic quest log and quest map pane.", false)
    MakeCheck(frame, "Quest Dialogue", "questDialogs", "INV_Misc_Book_09", "Quest offers, rewards and turn-ins.", false)
    MakeCheck(frame, "Quest Tracker", "questTracker", "INV_Misc_Book_09", "Classic quest watch presentation.", false)
    MakeCheck(frame, "Quest Levels", "questLevels", "INV_Misc_Book_09", "Show levels on tracked quests.", false)
    MakeCheck(frame, "Automate Quests", "autoQuests", "INV_Misc_ScrollInfo", "Accept and turn in quests with one reward or none. Shift pauses.", false)
    MakeCheck(frame, "Auto-gossip", "autoGossip", "INV_Misc_Book_09", "Picks the only free dialogue option. Hold Shift to bypass.", false)
    MakeCheck(frame, "Highlight Reward Upgrades", "rewardUpgradeHighlight", "INV_Misc_ArmorKit_17", "Suggests a reward using your stat profile. You still choose.", false)
    -- Character & Spells.
    MakeCheck(frame, "Character Window", "characterPanel", "INV_Misc_Book_09", "Classic panels, rows and bottom tabs.", false)
    MakeCheck(frame, "Talents", "talentWindow", "INV_Misc_Book_09", "Classic talent trees and native talent actions.", false)
    MakeCheck(frame, "Spellbook", "spellbook", "INV_Misc_Book_09", "Classic book and native spell actions.", false)
    MakeCheck(frame, "Combat Spell Dragging", "spellbookCombatDrag", "Spell_Holy_MagicalSentry", "Use native spell buttons to drag spells during combat. Reload to apply.", false)
    MakeCheck(frame, "Training Guide", "trainingGuide", "INV_Misc_Book_09", "A training tab in the spellbook: spells to learn, levels and costs.", false)
    MakeCheck(frame, "Show All Spell Ranks", "showAllSpellRanks", "INV_Misc_Book_09", "Keep every rank visible in the spellbook.", false)
    MakeCheck(frame, "Trainer", "trainer", "INV_Misc_Book_09", "Classic trainer window and training controls.", false)
    MakeCheck(frame, "Professions", "professions", "INV_Misc_Book_09", "Classic profession windows.", false)
    -- Bags & Vendors.
    MakeCheck(frame, "Bags & Bank", "bagsBank", "INV_Misc_Book_09", "Classic bag and bank windows.", false)
    MakeCheck(frame, "Bag Space", "bagSpace", "INV_Misc_Book_09", "Show free slots on the backpack.", false)
    MakeCheck(frame, "Bag Item Levels", "bagItemLevels", "INV_Misc_Bag_07", "Item levels in quality colours, with upgrade arrows.", ComingSoon("bagItemLevels"))
    MakeCheck(frame, "Loot Window", "lootWindow", "INV_Misc_Book_09", "Classic loot window and item rows.", false)
    MakeCheck(frame, "Faster Auto-loot", "fastAutoLoot", "INV_Misc_Book_09", "Loot immediately. Hold Shift for manual looting; inactive in combat.", false)
    MakeCheck(frame, "Discard Junk When Full", "discardCheapestJunk", "INV_Misc_Bag_10", "Frees the cheapest grey stack when looting with full bags. Shift bypasses.", false)
    MakeCheck(frame, "Merchant", "merchantSkin", "INV_Misc_Book_09", "Classic merchant and buyback windows.", false)
    MakeCheck(frame, "Auto-sell Junk", "autoSellJunk", "INV_Misc_Book_09", "Sell grey items at merchants.", false)
    MakeCheck(frame, "Auto-repair", "autoRepair", "INV_Misc_Book_09", "Repair using your own gold.", false)
    MakeCheck(frame, "Vendor Prices", "vendorPrice", "INV_Misc_Book_09", "Add missing item selling prices.", false)
    MakeCheck(frame, "Junk Value Summary", "junkValueSummary", "INV_Misc_Book_09", "Report grey-item vendor value when opening a merchant, before sales.", false)
    MakeCheck(frame, "Low Durability Warning", "durabilityWarning", "INV_Misc_Book_09", "Warn once when equipped gear falls to 20% or less; resets after repair.", false)
    -- Chat & Names.
    MakeCheck(frame, "Hide Surnames", "hideSecondaryNames", "INV_Misc_Book_09", "Hide Forever surnames.", false)
    MakeCheck(frame, "Classic Chat Dragging", "classicChatDragging", "INV_Misc_Note_01", "Right-click a chat tab to unlock, drag and lock chat. Reload to apply.", false)
    MakeCheck(frame, "Click Links Again to Close", "linkToggle", "INV_Misc_Note_01", "Click an item or spell link in chat again to close its tooltip.", false)
    MakeCheck(frame, "Quiet Mode", "hideStatusMessages", "INV_Misc_Book_09", "Hide EraUI startup and change notices.", false)
    MakeCheck(frame, "Welcome on Login", "showWelcomeOnLogin", "INV_Misc_Book_09", "Show the EraUI welcome on login, not ordinary UI reloads.", false)
    -- The Update notice tick under Presets, as a card only search shows.
    do
        local update=MakeCheck(frame, "Update Notice", "updateCheck", "INV_Letter_15", "In chat, when a guild or group member has a newer EraUI.", false)
        update.searchOnly,update.sortTab,update.searchTag=true,TAB.chat,"TOP RIGHT, UNDER PRESETS"
        update.searchText=update.searchText.." version newer tick presets"
    end
    -- Group & Invites.
    MakeCheck(frame, "Friends & Guild", "socialWindows", "INV_Misc_Book_09", "Classic Friends, Who and Guild windows.", false)
    MakeCheck(frame, "Group Finder & PvP", "groupFinderPvp", "INV_Misc_Book_09", "Classic group finder and PvP windows.", false)
    MakeCheck(frame, "Block Duels", "blockDuels", "Ability_DualWield", "Decline duel requests. Hold Shift to handle a request manually.", false)
    MakeCheck(frame, "Block Party Invites", "blockPartyInvites", "INV_Misc_GroupLooking", "Decline invitations, except enabled friend acceptance. Shift bypasses.", false)
    MakeCheck(frame, "Party from Friends", "partyFromFriends", "INV_Misc_GroupLooking", "Accept invites from character friends. Takes priority over invite blocking.", false)
    MakeCheck(frame, "Invite from Whispers", "inviteFromWhispers", "INV_Letter_15", "Character friends can whisper invite to join. Requires permission to invite.", false)
    MakeCheck(frame, "Accept Summons", "autoSummon", "Spell_Shadow_Twilight", "Accept after one second outside combat. Hold Shift to bypass.", false)
    MakeCheck(frame, "Accept Resurrection", "autoResurrect", "Spell_Holy_Resurrection", "Accept resurrection requests outside combat. Hold Shift to bypass.", false)
    MakeCheck(frame, "Release in Battlegrounds", "releasePvP", "Ability_DualWield", "Release after one second, in battlegrounds only. Shift bypasses.", false)
    -- Windows & Tooltips.
    MakeCheck(frame, "Game Menu", "gameMenu", "INV_Misc_Book_09", "Classic menu border and buttons.", false)
    MakeCheck(frame, "Popups", "popups", "INV_Misc_Book_09", "Classic confirmation prompts.", false)
    MakeCheck(frame, "Settings Window", "blizzardSettings", "INV_Misc_Book_09", "Classic frame for the game's Settings window.", false)
    MakeCheck(frame, "Tooltips", "tooltipSkin", "INV_Misc_Book_09", "Dark tooltips with grey borders, item comparisons included.", false)
    MakeCheck(frame, "Tooltip IDs", "tooltipIDs", "INV_Misc_Book_09", "Item, spell and NPC IDs when exposed by this client. Re-hover to update.", false)
    MakeCheck(frame, "Damage Meter", "damageMeterSkin", "INV_Misc_Book_09", "Classic frame, bars and text for Blizzard's damage meter.", false)
    MakeCheck(frame, "Mail", "mailSkin", "INV_Misc_Book_09", "Classic mailbox and letter windows.", false)
    MakeCheck(frame, "Auction House", "auctionHouse", "INV_Misc_Book_09", "Classic auction house window.", false)
    MakeCheck(frame, "Other Windows", "otherWindows", "INV_Misc_Book_09", "Trade, taxi, macros, calendar and other windows.", false)
    MakeCheck(frame, "Context Menus", "contextMenus", "INV_Misc_Book_09", "Not implemented yet.", true)
    -- Screen & Cursor.
    MakeCheck(frame, "Hide Zone Announcements", "hideZoneText", "INV_Misc_Map_01", "Hide large zone announcements; minimap names remain.", false)
    MakeCheck(frame, "Maximum Camera Distance", "maxCameraZoom", "Spell_Nature_FarSight", "Raise the camera limit to 2.6. Off restores your earlier limit.", false)
    MakeCheck(frame, "Cursor Ring", "cursorRing", "INV_Misc_EngGizmos_18", "A ring follows your mouse pointer. Its options show when it's on.", false)
    MakeCheck(frame, "Class-coloured Cursor Ring", "cursorRingClassColour", "INV_Misc_ArmorKit_17", "Use your class colour for the ring. Off uses white.", false)
    local function RefreshCursor()
        if EraUI.modules.CursorRing then EraUI.modules.CursorRing:Refresh()end
        if EraUI.modules.CursorEffects then EraUI.modules.CursorEffects:Refresh()end
    end
    local function RingSlider(key,label,low,high,default,formatValue)
        local card=CreateFrame("Frame",nil,frame)
        card.searchText=string.lower("cursor mouse "..label)
        card:SetSize(350,74)
        card.text=Text(card,label,14);card.text:SetPoint("TOPLEFT",12,-10)
        local slider=CreateFrame("Slider",nil,card,"BackdropTemplate")
        slider:SetSize(310,12);slider:SetPoint("TOPLEFT",12,-45)
        slider:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        slider:SetBackdropColor(.06,.065,.075,1);slider:SetBackdropBorderColor(.3,.32,.36,1)
        slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(low,high);slider:SetValueStep(1);slider:SetObeyStepOnDrag(true)
        slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8");slider:GetThumbTexture():SetSize(10,20);slider:GetThumbTexture():SetVertexColor(ClassColour())
        slider:SetScript("OnValueChanged",function(_,value)
            value=math.max(low,math.min(high,math.floor(value+.5)))
            card.text:SetText(label..": "..(formatValue and formatValue(value)or value))
            if not card.syncing then EraUI:SetSetting(key,value);RefreshCursor()end
        end)
        card.SetChecked=function()
            card.syncing=true;slider:SetValue(math.max(low,math.min(high,tonumber(EraUI:GetSavedSetting(key))or default)));card.syncing=false
        end
        card.slider=slider;card:SetChecked();frame.checks[key]=card
    end
    RingSlider("cursorRingSize","Ring Diameter",24,160,48)
    RingSlider("cursorRingThickness","Ring Thickness",1,10,2)
    local function CursorColour(key,classKey,label)
        local card=CreateFrame("Button",nil,frame,"BackdropTemplate")
        card.searchText=string.lower("cursor mouse colour color "..label)
        card:SetSize(350,74)
        card:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        card:SetBackdropColor(.026,.029,.037,1);card:SetBackdropBorderColor(.19,.20,.24,1)
        card.text=Text(card,label,14);card.text:SetPoint("TOPLEFT",12,-12)
        local hint=Text(card,"Click to choose a custom colour.",12,true);hint:SetPoint("TOPLEFT",12,-38)
        local swatch=card:CreateTexture(nil,"ARTWORK");swatch:SetSize(24,24);swatch:SetPoint("RIGHT",-12,0)
        local function RGB()
            local hex=EraUI:GetSavedSetting(key)
            if type(hex)~="string"or not hex:match("^%x%x%x%x%x%x$")then hex="FFFFFF"end
            return tonumber(hex:sub(1,2),16)/255,tonumber(hex:sub(3,4),16)/255,tonumber(hex:sub(5,6),16)/255
        end
        card.SetChecked=function()swatch:SetColorTexture(RGB())end
        local function Save(hex,classColour)
            EraUI:SetSetting(key,hex);EraUI:SetSetting(classKey,classColour)
            frame.checks[classKey]:SetChecked(classColour);PaintToggle(frame.checks[classKey])
            card:SetChecked();RefreshCursor()
        end
        card:SetScript("OnClick",function()
            local picker=ColorPickerFrame
            if not picker then return end
            local old=EraUI:GetSavedSetting(key)or "FFFFFF"
            local oldClass=EraUI:GetSavedSetting(classKey)
            local r,g,b=RGB()
            local function Changed()
                local red,green,blue=picker:GetColorRGB()
                Save(string.format("%02X%02X%02X",math.floor(red*255+.5),math.floor(green*255+.5),math.floor(blue*255+.5)),false)
            end
            local function Cancel()Save(old,oldClass)end
            if picker.SetupColorPickerAndShow then
                picker:SetupColorPickerAndShow({r=r,g=g,b=b,hasOpacity=false,swatchFunc=Changed,cancelFunc=Cancel})
            else
                picker:Hide();picker.func=nil;picker.hasOpacity=false;picker:SetColorRGB(r,g,b)
                picker.func=Changed;picker.cancelFunc=Cancel;picker:Show()
            end
        end)
        card:SetChecked();frame.checks[key]=card
    end
    MakeCheck(frame,"Cast Progress Ring","cursorCastRing","Spell_Arcane_Arcane01","A cursor ring that fills as you cast. Its options show when it's on.",false)
    MakeCheck(frame,"Class-coloured Cast Ring","cursorCastClassColour","INV_Misc_ArmorKit_17","Use your class colour. Off uses the custom cast ring colour below.",false)
    RingSlider("cursorCastSize","Cast Ring Diameter",24,200,60)
    RingSlider("cursorCastOpacity","Cast Ring Opacity (%)",10,100,90)
    CursorColour("cursorCastColour","cursorCastClassColour","Custom Cast Ring Colour")
    MakeCheck(frame,"Cursor Trail","cursorTrail","Spell_Arcane_Blink","A soft trail follows your cursor. Its options show when it's on.",false)
    MakeCheck(frame,"Class-coloured Cursor Trail","cursorTrailClassColour","INV_Misc_ArmorKit_17","Use your class colour. Off uses the custom trail colour below.",false)
    RingSlider("cursorTrailSize","Trail Size",4,32,10)
    RingSlider("cursorTrailOpacity","Trail Opacity (%)",10,100,55)
    RingSlider("cursorTrailLength","Trail Fade",10,60,25,function(value)return string.format("%.2fs",value/100)end)
    CursorColour("cursorTrailColour","cursorTrailClassColour","Custom Trail Colour")
    -- Damage and healing text: the font, which the game reads as you log in,
    -- and the size, the game's own world text scale, which applies at once.
    local function CardLook(card)
        card:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        card:SetBackdropColor(.026,.029,.037,1);card:SetBackdropBorderColor(.19,.20,.24,1)
    end
    -- Draws text in a font, falling back to the normal one if it can't load.
    local function UseFont(text,font,size)
        local ok=font and font.file and text:SetFont(font.file,size,"OUTLINE")
        if ok==false or not(font and font.file)then text:SetFont(select(1,GameFontHighlight:GetFont()),size,"OUTLINE")end
    end
    local function CombatFontCard()
        local card=CreateFrame("Button",nil,frame,"BackdropTemplate")
        card.searchText="damage healing combat text numbers font pepsi"
        card:SetSize(350,74)
        CardLook(card)
        card.text=Text(card,"Damage Text Font",14);card.text:SetPoint("TOPLEFT",12,-10)
        local sample=card:CreateFontString(nil,"OVERLAY")
        sample:SetPoint("TOPLEFT",12,-30);sample:SetWidth(280);sample:SetJustifyH("LEFT");sample:SetWordWrap(false)
        sample:SetTextColor(1,1,1)
        local arrow=Text(card,"v",16,true);arrow:SetPoint("RIGHT",-16,4)
        local note=Text(card,"Log out and back in to apply. A /reload won't do it.",11,true);note:SetPoint("BOTTOMLEFT",12,7)
        card.sample,card.note=sample,note
        -- The list of fonts, each name written in its own font.
        local list=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        list:SetSize(350,#EraUI.CombatFonts*26+12)
        list:SetPoint("TOPLEFT",card,"BOTTOMLEFT",0,-4)
        list:SetFrameLevel(frame:GetFrameLevel()+60)
        CardLook(list);list:SetBackdropColor(.018,.02,.026,.98);list:EnableMouse(true);list:Hide()
        card.list,list.rows=list,{}
        for i,font in ipairs(EraUI.CombatFonts)do
            local row=CreateFrame("Button",nil,list)
            row:SetSize(330,24);row:SetPoint("TOPLEFT",10,-6-(i-1)*26)
            row.mark=row:CreateTexture(nil,"ARTWORK");row.mark:SetSize(4,16);row.mark:SetPoint("LEFT",0,0)
            row.label=row:CreateFontString(nil,"OVERLAY");row.label:SetPoint("LEFT",12,0)
            row.label:SetJustifyH("LEFT");row.label:SetTextColor(.9,.91,.93)
            UseFont(row.label,font,16);row.label:SetText(font.name)
            local hover=row:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(1,1,1,.06)
            row.font=font
            row:SetScript("OnClick",function()
                EraUI:SetSetting("damageFont",font.key);EraUI:ApplyCombatFont()
                list:Hide();card.changed=true;card:SetChecked()
                if frame.checks.damageTextScale then frame.checks.damageTextScale:SetChecked()end
                EraUI:Status("Damage text font: "..font.name..". Log out and back in to apply.")
            end)
            list.rows[i]=row
        end
        -- Opens under the card, or above it when the card is low in the window.
        card:SetScript("OnClick",function()
            if list:IsShown()then list:Hide();return end
            local _,cardY=card:GetCenter();local _,frameY=frame:GetCenter()
            list:ClearAllPoints()
            if cardY and frameY and cardY<frameY then list:SetPoint("BOTTOMLEFT",card,"TOPLEFT",0,4)
            else list:SetPoint("TOPLEFT",card,"BOTTOMLEFT",0,-4)end
            card:SetChecked();list:Show()
        end)
        card:HookScript("OnHide",function()list:Hide()end)
        card.SetChecked=function()
            local current=EraUI:CombatFont()
            UseFont(sample,current,20);sample:SetText(current and current.name or "")
            local r,g,b=ClassColour()
            for _,row in ipairs(list.rows)do
                local chosen=current and row.font.key==current.key
                row.mark:SetColorTexture(r,g,b,1);row.mark:SetShown(chosen)
            end
            note:SetTextColor(card.changed and r or .58,card.changed and g or .62,card.changed and b or .68)
        end
        card:SetChecked();frame.checks.damageFont=card
    end
    local function CombatScaleCard()
        local limits=EraUI.COMBAT_TEXT_SCALE
        local card=CreateFrame("Frame",nil,frame)
        card.searchText="damage healing combat text numbers size scale"
        card:SetSize(350,74)
        card.text=Text(card,"Damage Text Size",14);card.text:SetPoint("TOPLEFT",12,-10)
        local slider=CreateFrame("Slider",nil,card,"BackdropTemplate")
        slider:SetSize(310,12);slider:SetPoint("TOPLEFT",12,-45)
        slider:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        slider:SetBackdropColor(.06,.065,.075,1);slider:SetBackdropBorderColor(.3,.32,.36,1)
        slider:SetOrientation("HORIZONTAL");slider:SetMinMaxValues(limits.min,limits.max);slider:SetValueStep(5);slider:SetObeyStepOnDrag(true)
        slider:SetThumbTexture("Interface\\Buttons\\WHITE8X8");slider:GetThumbTexture():SetSize(10,20);slider:GetThumbTexture():SetVertexColor(ClassColour())
        -- A number in your damage font, bigger or smaller with the size.
        local preview=card:CreateFontString(nil,"OVERLAY")
        preview:SetPoint("RIGHT",card,"TOPRIGHT",-16,-24);preview:SetJustifyH("RIGHT");preview:SetTextColor(1,1,1)
        card.preview=preview
        local function Label(value)
            card.text:SetText(string.format("Damage Text Size: %.2fx",value/100))
            UseFont(preview,EraUI:CombatFont(),math.floor(10+(value/100-.5)*11+.5));preview:SetText("1234")
        end
        slider:SetScript("OnValueChanged",function(_,value)
            value=math.max(limits.min,math.min(limits.max,math.floor(value+.5)))
            Label(value)
            if not card.syncing then EraUI:SetCombatTextScale(value)end
        end)
        card.SetChecked=function()
            local current=EraUI:CombatTextScale()
            slider:SetShown(current~=nil);preview:SetShown(current~=nil)
            if not current then card.text:SetText("Damage Text Size: not available");return end
            card.syncing=true;slider:SetValue(current);card.syncing=false;Label(current)
        end
        card.slider=slider;card:SetChecked();frame.checks.damageTextScale=card
    end
    CombatFontCard()
    CombatScaleCard()
    -- AFK Screen and its options. Coming soon, it would be one SOON card with
    -- its options kept out of the window.
    local afkSoon=ComingSoon("afkScreen")
    MakeCheck(frame,"AFK Screen","afkScreen","Spell_Nature_Sleep","Fades the interface while you are AFK and shows your character."..(afkSoon and "" or " Try /era afk."),afkSoon)
    if not afkSoon then
        MakeCheck(frame,"AFK Screen: Faster Camera","afkCameraNormal","Spell_Nature_Swiftness","Circle once a minute. Off circles every two minutes.",false)
        MakeCheck(frame,"AFK Screen: Circle Right","afkTurnRight","Spell_Nature_Cyclone","Circle the camera to the right. Off circles to the left.",false)
        MakeCheck(frame,"AFK Screen: Zoom In","afkZoom","INV_Misc_Spyglass_02","Gently zoom in on your character. Your zoom returns afterwards.",false)
        MakeCheck(frame,"AFK Screen: 24-Hour Clock","afk24Hour","INV_Misc_PocketWatch_01","Show local time as 15:07. Off shows 3:07 PM.",false)
        MakeCheck(frame,"AFK Screen: Show Guild","afkShowGuild","INV_Shirt_GuildTabard_01","Show your guild name under your level.",false)
        MakeCheck(frame,"AFK Screen: Show Zone","afkShowZone","INV_Misc_Map_01","Show your zone and subzone.",false)
        MakeCheck(frame,"AFK Screen: Show Date","afkShowDate","INV_Misc_Note_02","Show today's date.",false)
        MakeCheck(frame,"AFK Screen: Class Quote","afkShowQuote","INV_Scroll_03","A famous Classic line for your class.",false)
    end
    -- More from Squirt: the author's other addons, whether you have them, and
    -- a way to open each one.
    local function MoreCard(key,info)
        local card=CreateFrame("Frame",nil,frame,"BackdropTemplate")
        card.searchText=string.lower("more addons squirt "..info.name.." "..info.search)
        -- Full width, in search results too, so its buttons are never cut off.
        card:SetSize(716,92);card.fullWidth=true
        CardLook(card)
        local icon=card:CreateTexture(nil,"ARTWORK")
        icon:SetSize(40,40);icon:SetPoint("TOPLEFT",14,-14);icon:SetTexture(info.icon)
        card.text=Text(card,info.name,15);card.text:SetPoint("TOPLEFT",66,-12)
        local about=Text(card,info.about,12,true)
        about:SetPoint("TOPLEFT",66,-34);about:SetWidth(500);about:SetJustifyH("LEFT")
        card.about=about
        local state=Text(card,"",12,true);state:SetPoint("BOTTOMLEFT",66,12)
        local function Button(label,x)
            local button=CreateFrame("Button",nil,card,"BackdropTemplate")
            button:SetSize(96,28);button:SetPoint("RIGHT",x,0);button.x=x
            button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            button.label=Text(button,label,14);button.label:SetPoint("CENTER")
            return button
        end
        local open=Button("Open",-16)
        open:SetScript("OnClick",function()
            local run=SlashCmdList and SlashCmdList[info.slash]
            if run then frame:Hide();run("")end
        end)
        -- Links to copy: an addon can't open a web page or the CurseForge app.
        local curse,github=Button("CurseForge",-120),Button("GitHub",-16)
        local function Copy(url)
            if EraUI.Classic and EraUI.Classic.CopyLink then
                EraUI.Classic.CopyLink(info.name.."\n\nPaste it into your browser. On CurseForge, Install opens the CurseForge app.",url)
            end
        end
        curse:SetScript("OnClick",function()Copy(info.curseforge)end)
        github:SetScript("OnClick",function()Copy(info.github)end)
        card.open,card.state,card.curse,card.github=open,state,curse,github
        card.SetChecked=function()
            local loaded=C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(info.addon)
            local links=info.curseforge~=nil and not loaded
            local r,g,b=ClassColour()
            for _,button in ipairs({open,curse,github})do
                button:SetBackdropColor(r*.22,g*.22,b*.22,1);button:SetBackdropBorderColor(r,g,b,1)
            end
            open:SetShown(loaded and true or false)
            curse:SetShown(links);github:SetShown(links)
            -- The text stops 12 short of the leftmost button on show.
            local edge=card:GetWidth()-16
            for _,button in ipairs({open,curse,github})do
                if button:IsShown()then edge=math.min(edge,card:GetWidth()+button.x-button:GetWidth())end
            end
            about:SetWidth(edge-12-66)
            state:SetText(loaded and ("Installed. Type "..info.command..", or click Open.")
                or links and "Get it on CurseForge or GitHub: click one for its link."
                or "Coming soon to CurseForge and GitHub.")
        end
        card:SetChecked();frame.checks[key]=card
    end
    MoreCard("moreFECM",{name="Forever Enhanced Cooldown Manager",addon="ForeverEnhancedCooldownManager",
        slash="FECM",command="/ccm",icon="Interface\\AddOns\\EraUI\\Media\\FECMIcon.tga",search="fecm ccm cooldown manager bars cast bar layout",
        about="Cooldown, buff and cast bars of your own, stacked round your Personal Resource Display, and a fresh look for Blizzard's Cooldown Manager.",
        curseforge="https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-manager",
        github="https://github.com/squirtwow/ForeverEnhancedCooldownManager"})
    MakeCheck(frame, "Floating Combo Points", "floatingComboPoints", "Ability_Rogue_Eviscerate", "Hover orbs for controls. Right-click + to unlock; left-click to lock. Reload to enable.", false)
    MakeCheck(frame, "Red Combo Points", "comboPointRed", "Ability_Rogue_Rupture", "Draw the combo point orbs red instead of gold. Applies immediately.", false)
    MakeCheck(frame, "Energy Bar", "energyBar", "ClassIcon_Rogue", "Floating energy and current value. Hover + to move or resize. Applies immediately.", false)
    frame.checks.energyBar.classAllowed=classToken=="ROGUE"
    frame.checks.floatingComboPoints.classAllowed=classToken=="ROGUE" or classToken=="DRUID"
    frame.checks.comboPointRed.classAllowed=classToken=="ROGUE" or classToken=="DRUID"
    MakeCheck(frame, "Swing Timer", "swingTimer", "INV_Sword_04", "Main-hand and off-hand swings. Hover + to move or resize. Applies immediately.", false)
    frame.checks.swingTimer.classAllowed=meleeClasses[classToken] or false
    MakeCheck(frame, "Rage Bar", "rageBar", "ClassIcon_Warrior", "Floating rage and current value. Hover + to move or resize.", false)
    frame.checks.rageBar.classAllowed=classToken=="WARRIOR"
    MakeCheck(frame, "Mana Bar", "manaBar", "INV_Potion_76", "Floating mana and current value. Hover + to move or resize.", false)
    frame.checks.manaBar.classAllowed=manaClasses[classToken] or false
    MakeCheck(frame, "Resource Bar", "druidResourceBar", "ClassIcon_Druid", "Mana, cat energy or bear rage. Switches automatically with your form.", false)
    frame.checks.druidResourceBar.classAllowed=classToken=="DRUID"
    MakeCheck(frame, "Ranged Swing Timer", "rangedSwingTimer", "INV_Weapon_Bow_07", "Ranged attacks and wands. Equip a ranged weapon. Hover + to move or resize.", false)
    frame.checks.rangedSwingTimer.classAllowed=rangedClasses[classToken] or false
    for _,entry in ipairs({
        {"hunterFeed","Pet Feeding","HUNTER","Feeding button when pet happiness is low, plus Feed Pet duration. Right-click the icon to unlock, drag or scroll to arrange it, then left-click to lock. Use Move / resize below to preview it before learning Feed Pet."},
        {"mageSupplies","Conjuring Suggestions","MAGE","Suggest learned food and water for your target's level. Open Class Tools to conjure."},
        {"mageAutoTrade","Auto-fill Trade","MAGE","Place full stacks of suitable conjured food and water in trade. Stack counts are in Class Tools."},
        {"poisonReminders","Poison Reminders","ROGUE","Missing weapon coatings, low time and charges. Preview while settings are open; right-click header to move/resize."},
        {"roguePoisons","Poison Supplies","ROGUE","Poison vendor quantities, material purchases, crafting and Flash Powder. Open Class Tools for controls."},
    }) do
        MakeCheck(frame,entry[2],entry[1],"INV_Misc_Bag_10",entry[4],false)
        frame.checks[entry[1]].classAllowed=classToken==entry[3]
    end
    MakeCheck(frame,"Class Reminders & Buffs","classReminders","Spell_Holy_MagicalSentry","Big on-screen alerts when a class buff, pet or supply is missing.",false)
    frame.checks.classReminders.classAllowed=true
    do
        local reminders=frame.checks.classReminders
        local module=EraUI.modules.ClassReminders
        if reminders and module then
            module.settingsFrame=frame
            module.settingsAnchor=reminders
            reminders:HookScript("OnShow",function()module:AttachOptions(frame,reminders)end)
            reminders:HookScript("OnHide",function()module:HideOptions()end)
            reminders:HookScript("OnClick",function()module:UpdateOptionsState()end)
        end
    end
    local toolsModule=EraUI.modules.ClassTools and EraUI.modules.ClassTools:ActiveModule()
    local toolsInline=not not(toolsModule and toolsModule.Attach and toolsModule~=EraUI.modules.ClassReminders)
    local toolsButton=CreateFrame(toolsInline and "Frame" or "Button",nil,frame,"BackdropTemplate")
    -- Reminder-only classes already have their full controls on this page.
    toolsButton.classAllowed=not not(hasClassControls and toolsModule and toolsModule~=EraUI.modules.ClassReminders)
    toolsButton.searchText="class tools pet feeding food water conjure trade poison supplies flash powder options"
    toolsButton:SetSize(350,74)
    toolsButton:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    local tr,tg,tb=ClassColour()
    toolsButton:SetBackdropColor(tr*.16,tg*.16,tb*.16,1);toolsButton:SetBackdropBorderColor(tr,tg,tb,1)
    local toolsIcon=toolsButton:CreateTexture(nil,"ARTWORK");toolsIcon:SetSize(30,30);toolsIcon:SetPoint("LEFT",12,0)
    toolsIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    toolsIcon:SetTexCoord(unpack(classIconCoords[classToken] or classIconCoords.ROGUE))
    local toolsArrow=Text(toolsButton,">",24);toolsArrow:SetPoint("RIGHT",-14,0);toolsArrow:SetTextColor(tr,tg,tb)
    toolsButton.text=Text(toolsButton,"Configure "..className.." Tools",14);toolsButton.text:SetPoint("TOPLEFT",54,-14);toolsButton.text:SetTextColor(tr,tg,tb)
    local toolsDetail=Text(toolsButton,"Click to open options and controls.",12,true)
    toolsDetail:SetPoint("TOPLEFT",54,-40);toolsDetail:SetWidth(266)
    toolsButton.SetChecked=function()end
    if toolsInline then
        toolsArrow:Hide()
        toolsButton:EnableMouse(false)
        toolsButton:SetBackdropColor(.026,.029,.037,1)
        toolsButton:SetBackdropBorderColor(.19,.20,.24,1)
        toolsButton.text:SetText(classToken=="HUNTER" and "Pet Feeding Options" or "Conjuring & Trade Options")
        toolsDetail:SetText(classToken=="HUNTER" and "Food choices and feeding-button placement." or "Conjure food/water and set trade quantities.")
    else
        toolsButton:SetScript("OnEnter",function(self)self:SetBackdropColor(tr*.28,tg*.28,tb*.28,1)end)
        toolsButton:SetScript("OnLeave",function(self)self:SetBackdropColor(tr*.16,tg*.16,tb*.16,1)end)
        toolsButton:SetScript("OnClick",function()
            if EraUI.modules.ClassTools then EraUI.modules.ClassTools:Open() end
        end)
    end
    toolsButton:HookScript("OnShow",function()
        local tools=EraUI.modules.ClassTools
        local m=tools and tools:ActiveModule()
        if m and m.Attach and m~=EraUI.modules.ClassReminders then
            m.settingsFrame=frame
            m.settingsAnchor=toolsButton
            m:Attach(frame,toolsButton)
        end
    end)
    toolsButton:HookScript("OnHide",function()
        local tools=EraUI.modules.ClassTools
        local m=tools and tools:ActiveModule()
        if m and m.HidePanel then m:HidePanel()end
    end)
    frame.checks.classTools=toolsButton
    -- Compact class controls so unavailable features never leave empty cells.
    classOrder={"floatingComboPoints","comboPointRed","energyBar","rageBar","manaBar","druidResourceBar","swingTimer","rangedSwingTimer","hunterFeed","mageSupplies","mageAutoTrade","roguePoisons","poisonReminders","classReminders","classTools"}
    -- The reward profile, right after Highlight Reward Upgrades.
    local profile=CreateFrame("Button",nil,frame,"BackdropTemplate")
    profile:SetSize(350,74)
    profile.searchText="reward profile specialization stats upgrades"
    profile:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    profile:SetBackdropColor(.075,.078,.085,1);profile:SetBackdropBorderColor(.25,.27,.3,1)
    profile.label=Text(profile,"",14);profile.label:SetPoint("TOPLEFT",12,-12)
    local detail=Text(profile,"Click: next profile. Right-click: previous.\nHover to inspect the scoring weights.",12,true)
    detail:SetPoint("TOPLEFT",12,-36)
    local function ProfileLabel()
        local tools=EraUI.modules.QuestTools
        profile.label:SetText("Reward Profile: "..(tools and tools:Profile()[1] or "Loading"))
    end
    profile.SetChecked=ProfileLabel -- Participate in the settings refresh/layout only.
    profile:RegisterForClicks("LeftButtonUp","RightButtonUp")
    profile:SetScript("OnClick",function(_,button)
        local tools=EraUI.modules.QuestTools
        if tools then tools:CycleProfile(button=="RightButton" and -1 or 1);ProfileLabel() end
    end)
    profile:SetScript("OnEnter",function(self)
        local tools=EraUI.modules.QuestTools
        if tools and GameTooltip then GameTooltip:SetOwner(self,"ANCHOR_RIGHT");GameTooltip:SetText("Reward scoring");GameTooltip:AddLine(tools:ProfileDescription(),1,1,1,true);GameTooltip:Show()end
    end)
    profile:SetScript("OnLeave",function()if GameTooltip then GameTooltip:Hide()end end)
    profile:SetScript("OnShow",ProfileLabel)
    frame.checks.rewardProfile=profile
    -- Every tab's cards in reading order, two per row: each sub-option right
    -- after its parent. Appearance reads as two columns under their labels
    -- (Dark Mode extras on the left, class colours on the right). A card on no
    -- page (the Update notice) only shows in search.
    PAGES={
        appearance={"appearanceChoice","#darkExtras","#classColours",
            "darkAuraBorders","classColors",
            "darkAuraShadows","tooltipClassColours",
            "classColourBorders","castBarClassBorder"},
        class=classOrder,
        actionBars={"actionBars","gryphons","hideEmptyActionSlots","hideKeybindText","hideMacroText"},
        frames={"unitFrames","matchFocusSize","disableAggroHighlight","portraitDebuffs",
            "classIconPortraitMine","classIconPortraitOthers","friendlyNameplates","enemyNameplates"},
        casting={"castBars","advancedCastBar","advancedCastClassFill","advancedCastTicks","advancedCastLatency"},
        map={"minimap","cleanMinimap","coordinates","mapQuestObjectives","movableMap","revealMap"},
        quests={"questLog","questDialogs","questTracker","questLevels","autoQuests","autoGossip",
            "rewardUpgradeHighlight","rewardProfile"},
        character={"characterPanel","talentWindow","spellbook","spellbookCombatDrag","trainingGuide",
            "showAllSpellRanks","trainer","professions"},
        bags={"#bagsLoot","bagsBank","bagSpace","bagItemLevels","lootWindow","fastAutoLoot","discardCheapestJunk",
            "#vendors","merchantSkin","autoSellJunk","autoRepair","vendorPrice","junkValueSummary","durabilityWarning"},
        chat={"hideSecondaryNames","classicChatDragging","linkToggle","hideStatusMessages","showWelcomeOnLogin"},
        group={"socialWindows","groupFinderPvp","blockDuels","blockPartyInvites","partyFromFriends",
            "inviteFromWhispers","autoSummon","autoResurrect","releasePvP"},
        windows={"gameMenu","popups","blizzardSettings","tooltipSkin","tooltipIDs","damageMeterSkin",
            "mailSkin","auctionHouse","otherWindows","contextMenus"},
        screen={"hideZoneText","maxCameraZoom","damageFont","damageTextScale",
            "cursorRing","cursorRingClassColour","cursorRingSize","cursorRingThickness",
            "cursorCastRing","cursorCastClassColour","cursorCastSize","cursorCastOpacity","cursorCastColour",
            "cursorTrail","cursorTrailClassColour","cursorTrailSize","cursorTrailOpacity","cursorTrailLength","cursorTrailColour",
            "afkScreen","afkCameraNormal","afkTurnRight","afkZoom","afk24Hour","afkShowGuild","afkShowZone","afkShowDate","afkShowQuote"},
        more={"moreFECM"},
    }
    frame.pages=PAGES
    -- Each card's tab, and its place there (search lists results in page order).
    local pageOrder={}
    for key,check in pairs(frame.checks)do
        check.settingKey=key
        if OLD_NAMES[key] and check.searchText then check.searchText=check.searchText.." "..string.lower(OLD_NAMES[key]) end
    end
    for index,id in ipairs(TAB_IDS)do
        for place,key in ipairs(PAGES[id])do
            local check=frame.checks[key]
            if check then check.category=index;pageOrder[key]=place end
        end
    end
    function frame:RefreshDependencies()
        -- Every option up the chain counts: Aura Shadows is greyed while Dark
        -- Mode is off even with Dark Aura Borders still ticked.
        for key in pairs(DEPENDS)do
            local check=self.checks[key]
            if check then
                local enabled=MissingParent(key)==nil
                check.dependencyDisabled=not enabled;check:SetEnabled(enabled);check:SetAlpha(enabled and 1 or .4)
                check.dependencyHelp:SetShown(not enabled)
            end
        end
    end
    function frame:RefreshCastDependencies()
        self:RefreshDependencies()
        if EraUI.modules.ClassAccents then EraUI.modules.ClassAccents:Refresh()end
    end
    local footerLine = frame:CreateTexture(nil, "ARTWORK")
    footerLine:SetPoint("BOTTOMLEFT", 24, 64)
    footerLine:SetPoint("BOTTOMRIGHT", -24, 64)
    footerLine:SetHeight(1)
    footerLine:SetColorTexture(0.14, 0.15, 0.18, 1)
    local hint = Text(frame, "", 13, true)
    hint:SetPoint("BOTTOMLEFT", 26, 29)
    hint:SetWidth(560)
    frame.reloadHint = hint

    local signature = Text(frame, "Made with |TInterface\\AddOns\\EraUI\\Media\\Heart:10:10:0:0|t by Squirt", 10, true)
    signature:SetPoint("BOTTOMRIGHT", -24, 5)
    signature:SetJustifyH("RIGHT")
    signature:SetTextColor(0.48, 0.49, 0.52, 1)

    local reload = CreateFrame("Button", nil, frame, "BackdropTemplate")
    reload:SetSize(142, 32)
    reload:SetPoint("BOTTOMRIGHT", -24, 20)
    reload:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
    local reloadText = Text(reload, "Reload UI", 15)
    reloadText:SetPoint("CENTER")
    frame.reloadButton = reload
    reload:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            hint:SetText("Finish combat before reloading the UI.")
            return
        end
        ReloadUI()
    end)
    -- The setup uses the same controls and callbacks as the regular menu.
    -- Only navigation and placement change; there is one settings implementation.
    local setupSummary = Text(frame, "", 15, true)
    setupSummary:SetPoint("TOPLEFT", 30, -156)
    setupSummary:SetWidth(730)
    setupSummary:SetJustifyV("TOP")
    frame.setupSummary=setupSummary
    setupSummary:Hide()
    local setupProgress = Text(frame, "", 12, true)
    setupProgress:SetPoint("TOPRIGHT", -64, -30)
    setupProgress:Hide()
    frame.setupProgress=setupProgress
    local function SetupButton(label, x, width)
        local button=CreateFrame("Button",nil,frame,"BackdropTemplate")
        button:SetSize(width,32)
        button:SetPoint("BOTTOMRIGHT",x,20)
        button:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
        local r,g,b=ClassColour()
        button:SetBackdropColor(r*.22,g*.22,b*.22,1)
        button:SetBackdropBorderColor(r,g,b,1)
        button.label=Text(button,label,14)
        button.label:SetPoint("CENTER")
        button:Hide()
        return button
    end
    local nextPage=SetupButton("Next >",-24,160)
    local previousPage=SetupButton("< Back",-196,92)
    -- The finish page asks whether to log out now when a new damage font is
    -- waiting, since only a new login shows it. Logging out is for the game's
    -- own secure code, so "Yes, log out" is a secure macro button of its own,
    -- laid over its spot on the screen rather than joined to this window,
    -- which stays free to move and close in combat. It's hidden as combat
    -- starts and while the window moves.
    local SaveSetupDone,PlaceLogout
    local fontQuestion=CreateFrame("Frame",nil,frame)
    fontQuestion:SetSize(560,70);fontQuestion:SetPoint("BOTTOMLEFT",30,78);fontQuestion:Hide()
    frame.fontQuestion=fontQuestion
    do
    local fontAsk=Text(fontQuestion,"Apply your new damage font now? It needs a log out.",15)
    fontAsk:SetPoint("TOPLEFT",0,0)
    local logoutSpot=CreateFrame("Frame",nil,fontQuestion)
    logoutSpot:SetSize(150,32);logoutSpot:SetPoint("TOPLEFT",0,-30)
    local later=CreateFrame("Button",nil,fontQuestion,"BackdropTemplate")
    later:SetSize(110,32);later:SetPoint("TOPLEFT",logoutSpot,"TOPRIGHT",10,0)
    later:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    later:SetBackdropColor(.045,.05,.065,1);later:SetBackdropBorderColor(.22,.23,.27,1)
    later.label=Text(later,"No, later",14);later.label:SetPoint("CENTER")
    later:SetScript("OnClick",function()if not frame.setupMode then return end;frame.fontLater=true;frame:RenderSetup()end)
    frame.fontLaterButton=later
    local logout
    -- IsShown is the question's own flag, still set after the window closes;
    -- the button only goes where the question can be seen.
    PlaceLogout=function(show)
        if InCombatLockdown()then return end
        if not(show and fontQuestion:IsVisible())then if logout then logout:Hide()end;return end
        if not logout then
            logout=CreateFrame("Button","EraUISetupLogout",UIParent,"SecureActionButtonTemplate,BackdropTemplate")
            logout:SetSize(150,32);logout:SetFrameStrata("DIALOG");logout:Hide()
            logout:RegisterForClicks("LeftButtonUp","LeftButtonDown")
            logout:SetAttribute("type1","macro");logout:SetAttribute("macrotext1","/logout")
            logout:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            local r,g,b=ClassColour()
            logout:SetBackdropColor(r*.22,g*.22,b*.22,1);logout:SetBackdropBorderColor(r,g,b,1)
            logout.label=Text(logout,"Yes, log out",14);logout.label:SetPoint("CENTER")
            -- Setup is done either way; settings open after the next login.
            logout:SetScript("PreClick",function()if SaveSetupDone then SaveSetupDone()end end)
        end
        local left,right,top,bottom=logoutSpot:GetLeft(),logoutSpot:GetRight(),logoutSpot:GetTop(),logoutSpot:GetBottom()
        if not(left and right and top and bottom)then logout:Hide();return end
        logout:SetScale(logoutSpot:GetEffectiveScale()/UIParent:GetEffectiveScale())
        logout:ClearAllPoints();logout:SetPoint("CENTER",UIParent,"BOTTOMLEFT",(left+right)/2,(top+bottom)/2)
        logout:SetFrameLevel(frame:GetFrameLevel()+50);logout:Show()
    end
    fontQuestion:SetScript("OnShow",function()
        PlaceLogout(true)
        C_Timer.After(0,function()if fontQuestion:IsVisible()then PlaceLogout(true)end end)
    end)
    fontQuestion:SetScript("OnHide",function()PlaceLogout(false)end)
    frame:HookScript("OnDragStart",function()PlaceLogout(false)end)
    frame:HookScript("OnDragStop",function()if fontQuestion:IsVisible()then PlaceLogout(true)end end)
    local logoutWatch=CreateFrame("Frame",nil,frame)
    logoutWatch:RegisterEvent("PLAYER_REGEN_DISABLED");logoutWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
    logoutWatch:SetScript("OnEvent",function(_,event)
        if event=="PLAYER_REGEN_DISABLED"then
            if logout then logout:Hide()end -- still allowed as combat begins
        elseif fontQuestion:IsVisible()then PlaceLogout(true)end
    end)
    frame.logoutWatch=logoutWatch
    end
    local changelog=SetupButton("Changelog",-178,112)
    changelog:ClearAllPoints();changelog:SetPoint("BOTTOM",0,20)
    frame.changelogButton=changelog
    changelog:SetScript("OnClick",function()
        if EraUI.ShowUpdateNotes then EraUI.ShowUpdateNotes() end
    end)
    -- Discord beside it, for bugs and ideas; Changelog stays in the middle.
    local discord=SetupButton("Discord",-24,112)
    discord:ClearAllPoints();discord:SetPoint("LEFT",changelog,"RIGHT",8,0)
    frame.discordButton=discord
    discord:SetScript("OnClick",function()
        if EraUI.ShowDiscord then EraUI.ShowDiscord() end
    end)
    discord:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_TOP")
        GameTooltip:SetText("Found a bug or have an idea? Join the Discord.",1,1,1,1,true)
        GameTooltip:Show()
    end)
    discord:SetScript("OnLeave",function()GameTooltip:Hide()end)
    -- Active preset and a way to switch; a label only, never a warning.
    local presets=SetupButton("Presets",-24,96)
    presets:ClearAllPoints();presets:SetSize(96,26);presets:SetPoint("TOPRIGHT",-48,-36)
    presets:SetScript("OnClick",function()if EraUI.Presets then EraUI.Presets:Show()end end)
    frame.presetButton=presets
    local presetLabel=Text(frame,"",12,true)
    presetLabel:SetPoint("RIGHT",presets,"LEFT",-10,0)
    presetLabel:SetJustifyH("RIGHT")
    frame.presetLabel=presetLabel
    -- Under Presets: a small tick for the update notice.
    local notice=CreateFrame("Button",nil,frame)
    notice:SetSize(14,14);notice:SetPoint("TOPRIGHT",presets,"BOTTOMRIGHT",0,-9)
    notice.box=notice:CreateTexture(nil,"BACKGROUND");notice.box:SetAllPoints();notice.box:SetColorTexture(.15,.16,.19,1)
    notice.mark=notice:CreateTexture(nil,"ARTWORK");notice.mark:SetPoint("TOPLEFT",3,-3);notice.mark:SetPoint("BOTTOMRIGHT",-3,3)
    notice.text=Text(notice,"Update Notice",12,true);notice.text:SetPoint("RIGHT",notice,"LEFT",-6,0)
    function notice:Set(on)
        self.on=on and true or false
        local r,g,b=ClassColour()
        self.mark:SetColorTexture(r,g,b,1);self.mark:SetShown(self.on)
    end
    notice:SetScript("OnClick",function(self)
        self:Set(not self.on)
        EraUI:SetSetting("updateCheck",self.on)
        -- Search's Update Notice card is the same switch.
        if frame.checks.updateCheck then frame.checks.updateCheck:SetChecked(self.on) end
        EraUI:Status("Update Notice "..(self.on and "on." or "off."))
    end)
    notice:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("Update Notice")
        GameTooltip:AddLine("Tells you in chat when someone in your guild or group has a newer EraUI.",1,1,1,true)
        GameTooltip:Show()
    end)
    notice:SetScript("OnLeave",function()GameTooltip:Hide()end)
    frame.updateNotice=notice
    function frame:UpdatePresetLabel()
        local P=EraUI.Presets
        local shown=P~=nil and not self.setupMode
        presets:SetShown(shown);presetLabel:SetShown(shown);notice:SetShown(not self.setupMode)
        notice:Set(EraUI:GetSetting("updateCheck")~=false)
        if shown then presetLabel:SetText("Preset: "..P.NAMES[P:Current()]) end
    end
    -- New layout note: once per account, at the top of the window, for players
    -- who knew the old tabs. Core/Integration.lua decides who (layoutNotice 1);
    -- fresh installs never get it and the setup walkthrough never shows it.
    -- The X, or closing the window after seeing it, puts it away for good.
    -- It ends before the Presets column, so its X is well clear of the
    -- window's own.
    local banner=CreateFrame("Frame",nil,frame,"BackdropTemplate")
    banner:SetPoint("TOPLEFT",VIEW_LEFT,-8);banner:SetPoint("TOPRIGHT",-170,-8);banner:SetHeight(24)
    banner:SetSize(588,24)
    banner:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    do
        local r,g,b=ClassColour()
        banner:SetBackdropColor(r*.16,g*.16,b*.16,1);banner:SetBackdropBorderColor(r,g,b,1)
    end
    do
        local r,g,b=ClassColour()
        banner.text=Text(banner,string.format("|cff%02x%02x%02xNew layout:|r every option now lives with its topic. Can't find something? Use Search.",
            math.floor(r*255+.5),math.floor(g*255+.5),math.floor(b*255+.5)),12)
    end
    banner.text:SetPoint("LEFT",10,0)
    local bannerClose=CreateFrame("Button",nil,banner)
    bannerClose:SetSize(22,22);bannerClose:SetPoint("RIGHT",-2,0)
    local bannerX=Text(bannerClose,"X",14,true);bannerX:SetPoint("CENTER")
    bannerClose:SetScript("OnEnter",function()bannerX:SetTextColor(1,1,1)end)
    bannerClose:SetScript("OnLeave",function()bannerX:SetTextColor(.58,.62,.68)end)
    banner.close=bannerClose
    banner:Hide()
    function frame:DismissLayoutNotice()
        banner:Hide()
        if EraUI:GetSavedSetting("layoutNotice")==1 then
            EraUI:SetSetting("layoutNotice",0);EraUI:SaveSettings()
        end
    end
    bannerClose:SetScript("OnClick",function()frame:DismissLayoutNotice()end)
    frame.layoutNotice=banner
    function frame:UpdateLayoutNotice()
        banner:SetShown(not self.setupMode and self:IsShown() and EraUI:GetSavedSetting("layoutNotice")==1)
    end
    -- For changes made outside the window (e.g. the quest tracker prompt).
    function frame:RefreshHint()UpdateReloadHint(self)end
    -- Every card, label and the Appearance choice scroll inside the viewport;
    -- each page lays them out from its list.
    frame.viewLeft=VIEW_LEFT
    local content=EraUI:CreateSettingsViewport(frame)
    -- Each starts at the top corner; its page puts it in place when shown.
    for _,check in pairs(frame.checks) do check:SetParent(content);check:ClearAllPoints();check:SetPoint("TOPLEFT",content,"TOPLEFT",0,0) end
    for _,label in pairs(frame.sectionLabels) do label:SetParent(content);label:ClearAllPoints();label:SetPoint("TOPLEFT",content,"TOPLEFT",0,0) end
    local function Pending()
        local labels={}
        for key in pairs(reloadSettings) do
            if (EraUI:GetSavedSetting(key) and true or false)~=frame.loadedSettings[key] then
                labels[#labels+1]=key=="darkMode" and "Appearance" or (frame.checks[key] and frame.checks[key].text:GetText() or key)
            end
        end
        local tracker=EraUI.modules.QuestTrackerChoice
        if tracker and tracker:NeedsReload() then labels[#labels+1]="Questie tracker" end
        table.sort(labels)
        return labels
    end
    -- Appearance only changes the theme; it never overwrites feature/QoL choices.
    local appearanceButtons={}
    local function Choice(label, description, column, callback)
        local button=SetupButton(label,-24,330)
        button:ClearAllPoints()
        button:SetSize(330,112)
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT",18,-18)
        local detail=Text(button,description,13,true)
        detail:SetPoint("TOPLEFT",18,-46);detail:SetWidth(292)
        button.detail=detail
        button:SetScript("OnClick",callback)
        button.column=column
        return button
    end
    local function PlaceChoice(button)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT",frame,"TOPLEFT",(frame.setupMode and 30 or PAGE_LEFT)+button.column*366,-156)
    end
    local function PaintChoice(button,selected,name)
        local r,g,b=ClassColour()
        if selected then
            button:SetBackdropColor(r*.26,g*.26,b*.26,1)
            button:SetBackdropBorderColor(r,g,b,1)
            button.label:SetTextColor(r,g,b,1)
        else
            button:SetBackdropColor(.075,.078,.085,1)
            button:SetBackdropBorderColor(.25,.27,.3,1)
            button.label:SetTextColor(.7,.72,.76,1)
        end
        button.label:SetText((selected and "Selected: " or "")..name)
    end
    RenderAppearance=function()
        local dark=EraUI:GetSavedSetting("darkMode")
        for i,button in ipairs(appearanceButtons) do
            PaintChoice(button,(i==2)==not not dark,i==1 and "Classic" or "Dark Mode")
        end
    end
    local function ChooseAppearance(dark)
        EraUI:SetSetting("darkMode",dark)
        RenderAppearance();UpdateReloadHint(frame)
    end
    -- The two style buttons live in the Appearance choice row, so they scroll
    -- with the cards, on the Appearance tab, in search and in the walkthrough.
    for i,info in ipairs({
        {"Classic","Original Classic artwork. Requires a reload when switching styles.",false},
        {"Dark Mode","Darker decorative artwork. Character, party and raid frames stay unchanged. Reload to apply.",true},
    })do
        local button=Choice(info[1],info[2],i-1,function()ChooseAppearance(info[3])end)
        button:SetParent(choiceRow);button:SetSize(350,92)
        button:ClearAllPoints();button:SetPoint("TOPLEFT",choiceRow,"TOPLEFT",(i-1)*366,0)
        button.label:ClearAllPoints();button.label:SetPoint("TOPLEFT",18,-14)
        button.detail:ClearAllPoints();button.detail:SetPoint("TOPLEFT",18,-40);button.detail:SetWidth(314)
        button:Show()
        appearanceButtons[i]=button
    end
    frame.appearanceChoices=appearanceButtons
    choiceRow.SetChecked=function()RenderAppearance()end
    choiceRow:SetScript("OnShow",function()RenderAppearance()end)

    -- Quest tracker step, shown only when Questie is installed: only one
    -- tracker can show, so the walkthrough asks rather than the login prompt.
    local trackerButtons={}
    local function RenderTracker(shown)
        local tracker=EraUI.modules.QuestTrackerChoice
        local current=tracker and tracker:CurrentChoice() or ""
        for i,button in ipairs(trackerButtons) do
            PlaceChoice(button);button:SetShown(shown)
            local choice=i==1 and "classic" or "questie"
            PaintChoice(button,current==choice,i==1 and "Classic Tracker" or "Questie Tracker")
        end
    end
    local function ChooseTracker(choice)
        local tracker=EraUI.modules.QuestTrackerChoice
        if tracker then tracker:SetChoice(choice) end
        RenderTracker(true);UpdateReloadHint(frame)
    end
    -- Questie's own tracker does not list quests on WoW Forever yet.
    trackerButtons[1]=Choice("Classic Tracker","|cff66dd66Recommended.|r Blizzard's tracker in EraUI's Classic look. Turns Questie's tracker off; applies with the reload at the end.",0,function()ChooseTracker("classic")end)
    trackerButtons[2]=Choice("Questie Tracker","Questie's own tracker, unfolded. |cffffd24aDoes not list quests on WoW Forever yet.|r",1,function()ChooseTracker("questie")end)
    frame.trackerChoices=trackerButtons

    -- Reuse the actual controls so search preserves their normal actions and dependencies.
    local search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    frame.searchBox=search
    search:SetSize(440,28);search:SetPoint("TOPLEFT",PAGE_LEFT,-96)
    search:SetAutoFocus(false);search:SetMaxLetters(80)
    search:SetFont(select(1,GameFontHighlight:GetFont()),13,"")
    search:SetTextInsets(9,9,0,0)
    search:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    search:SetBackdropColor(.06,.065,.075,1);search:SetBackdropBorderColor(.25,.27,.3,1)
    local placeholder=Text(search,"Search settings...",13,true)
    placeholder:SetPoint("LEFT",9,0)
    local results=Text(frame,"",12,true);results:SetPoint("LEFT",search,"RIGHT",12,0)
    local page=1
    local prev=SetupButton("<",-24,28);prev:ClearAllPoints();prev:SetSize(28,28);prev:SetPoint("TOPLEFT",WINDOW_WIDTH-104,-96)
    local next=SetupButton(">",-24,28);next:ClearAllPoints();next:SetSize(28,28);next:SetPoint("TOPLEFT",WINDOW_WIDTH-68,-96)
    local clearing=false
    ResetSearch=function()
        clearing=true;search:SetText("");search:ClearFocus();clearing=false
        placeholder:Show();results:SetText("");prev:Hide();next:Hide();page=1
        frame.searching=false
    end
    -- Each result shows the tab it lives on, in small capitals above it.
    local function SearchTag(check)
        local tag=searchTags[check]
        if not tag then
            tag=Text(check,"",10);tag:SetPoint("BOTTOMLEFT",check,"TOPLEFT",8,3)
            searchTags[check]=tag
        end
        local tab=categories[check.category]
        tag:SetText(check.searchTag or string.upper(tab and tab.name or ""))
        tag:SetTextColor(ClassColour())
        return tag
    end
    frame.searchTags,frame.searchResultsText,frame.searchPrev,frame.searchNext=searchTags,results,prev,next
    ApplySearch=function()
        if frame.setupMode then return end
        local query=Normalise(string.lower(search:GetText() or ""):match("^%s*(.-)%s*$"))
        placeholder:SetShown(query=="")
        if query=="" then
            frame.searching=false
            results:SetText("");prev:Hide();next:Hide()
            SelectCategory(frame.selectedCategory or 1,true);return
        end
        frame.searching=true
        -- Every card, folded ones too, with its tab's name; colour and grey
        -- match either spelling.
        local matches={}
        for key,check in pairs(frame.checks) do
            local tab=categories[check.category]
            local text=Normalise((check.searchText or string.lower(key)).." "..string.lower(tab and tab.name or ""))
            local matched=check.classAllowed~=false and (tab~=nil or check.searchOnly==true)
            for word in query:gmatch("%S+") do
                if not text:find(word,1,true) then matched=false;break end
            end
            if matched then matches[#matches+1]={key=key,check=check,tab=check.category or check.sortTab or #categories+1,place=pageOrder[key] or 999} end
        end
        -- In tab order, then in page order.
        table.sort(matches,function(a,b)
            if a.tab~=b.tab then return a.tab<b.tab end
            if a.place~=b.place then return a.place<b.place end
            return a.key<b.key
        end)
        -- Pages of eight cells (four rows); a full-width card takes a whole row.
        local resultPages,current,cells={},{},0
        for _,match in ipairs(matches) do
            local wide=match.check.fullWidth
            local size=wide and 2+cells%2 or 1
            if cells+size>8 then resultPages[#resultPages+1]=current;current,cells={},0;size=wide and 2 or 1 end
            current[#current+1]=match.check;cells=cells+size
        end
        if #current>0 then resultPages[#resultPages+1]=current end
        local pages=math.max(1,#resultPages);page=math.max(1,math.min(page,pages))
        section:SetText("Search results");about:SetText("Each result shows the tab it lives on.")
        for _,tab in ipairs(tabs) do
            tab.underline:Hide();tab.selected:SetColorTexture(0,0,0,0);tab.text:SetTextColor(.58,.62,.68)
        end
        results:SetText(#matches==0 and "No matching settings" or (#matches.." found  |  "..page.." / "..pages))
        prev:SetShown(pages>1);next:SetShown(pages>1);prev:SetEnabled(page>1);next:SetEnabled(page<pages)
        local shown=resultPages[page] or {}
        ShowEntries(shown,true,16)
        for _,check in ipairs(shown) do SearchTag(check):Show() end
    end
    search:SetScript("OnTextChanged",function()if not clearing then page=1;ApplySearch() end end)
    search:SetScript("OnEscapePressed",function()ResetSearch();SelectCategory(frame.selectedCategory or 1,true)end)
    search:SetScript("OnEnterPressed",function(self)self:ClearFocus()end)
    prev:SetScript("OnClick",function()page=page-1;ApplySearch()end)
    next:SetScript("OnClick",function()page=page+1;ApplySearch()end)

    -- The walkthrough's quality-of-life pages, one per tab. Reload-only looks
    -- stay out (Classic Chat Dragging is the exception: its tab handlers need
    -- a reload), and the damage text cards have their own page. Options whose
    -- tab has no page here join a related one with room (Tooltip IDs goes with
    -- the chat link tooltips); Class-coloured Chat Names is on the style page,
    -- so it joins Chat & Names only when that page is skipped.
    local WALKTHROUGH={
        {tab="actionBars",add={{after="hideMacroText",key="showAllSpellRanks"}}},
        {tab="map"},
        {tab="quests"},
        {tab="bags"},
        {tab="chat",add={{after="hideSecondaryNames",key="classColors",qolOnly=true},{after="linkToggle",key="tooltipIDs"}}},
        {tab="group"},
        {tab="screen"},
    }
    frame.walkthrough=WALKTHROUGH
    local function LeftOut(key)
        return (reloadSettings[key] and key~="classicChatDragging") or key=="damageFont" or key=="damageTextScale"
    end
    local function WalkthroughEntries(walk)
        local extra={}
        for _,add in ipairs(walk.add or {})do
            if not add.qolOnly or frame.setupPreset=="qol" then extra[add.after]=add.key end
        end
        -- An option waiting on a look left out here can't be switched on here
        -- either (Show Gryphons with the Action Bars look off), so it waits too.
        -- Section labels stay on the tab: without its looks, Bags & Vendors
        -- then fits the page.
        return PageEntries(TAB[walk.tab],function(key)
            if key:sub(1,1)=="#" then return true end
            local missing=MissingParent(key)
            return LeftOut(key) or (missing~=nil and LeftOut(missing))
        end,extra)
    end
    -- First page: how EraUI is used. The Classic look gets the style page
    -- (and, with Questie installed, the tracker page); quality-of-life choices
    -- get the walkthrough pages above. A preset only switches the Classic look.
    local PRESETS={
        {id="classicqol",name="Classic + Quality of Life",look="classic",detail="The 2004 look, plus your choice of Quality of Life options. Recommended."},
        {id="classic",name="Classic look only",look="classic",detail="The 2004 look. Your Quality of Life options stay as they are."},
        {id="qol",name="Quality of Life only",look="qol",detail="Keep Blizzard's modern interface and pick Quality of Life options."},
    }
    local presetChoices={}
    local function RenderPresets(shown)
        for i,button in ipairs(presetChoices) do
            button:ClearAllPoints();button:SetPoint("TOPLEFT",frame,"TOPLEFT",30+(i-1)*250,-156);button:SetShown(shown)
            local selected=frame.setupPreset==PRESETS[i].id
            PaintChoice(button,selected,PRESETS[i].name)
            -- These boxes are too narrow for a "Selected:" prefix; a tag shows it.
            button.label:SetText(PRESETS[i].name)
            button.tag:SetTextColor(ClassColour());button.tag:SetShown(selected)
        end
    end
    -- A preset changes many saved settings at once; the reused toggles must
    -- show the saved state again before any page displays them.
    local function SyncChecks()
        for key,check in pairs(frame.checks) do
            local checked=EraUI:GetSavedSetting(key) and true or false
            if EraUI.charSettingKeys and EraUI.charSettingKeys[key] then checked=EraUI:GetCharSetting(key) and true or false end
            check:SetChecked(not check.unavailable and checked)
        end
    end
    for i,preset in ipairs(PRESETS) do
        local button=Choice(preset.name,preset.detail,0,function()
            frame.setupPreset=preset.id
            if EraUI.Presets then EraUI.Presets:Apply(preset.look) end
            SyncChecks()
            frame:RenderSetup()
        end)
        button:SetSize(236,112);button.detail:SetWidth(200)
        button.label:SetWidth(200);button.label:SetWordWrap(false)
        button.tag=Text(button,"SELECTED",11)
        button.tag:SetPoint("BOTTOMLEFT",18,12);button.tag:Hide()
        presetChoices[i]=button
    end
    frame.presetChoices=presetChoices
    local function SetupPages()
        local pages={"preset"}
        if frame.setupPreset~="qol" then
            pages[#pages+1]="style"
            -- Only the Classic tracker competes with Questie's own.
            if frame.trackerStep then pages[#pages+1]="tracker" end
        end
        -- The damage and healing text font, for every preset.
        if frame.checks.damageFont then pages[#pages+1]="font" end
        if frame.setupPreset~="classic" then
            for index=1,#WALKTHROUGH do pages[#pages+1]=index end
        end
        pages[#pages+1]="final"
        return pages
    end
    function frame:RenderSetup()
        local pages=SetupPages()
        self.setupPage=math.max(1,math.min(self.setupPage or 1,#pages))
        local page=pages[self.setupPage]
        local final=page=="final"
        self.walkEntries=nil
        RenderPresets(false);RenderTracker(false);setupSummary:Hide();fontQuestion:Hide()
        about:SetText("")
        navigation:Hide();divider:Hide()
        if page=="preset" then
            ShowEntries({},true)
            section:SetText("How do you want EraUI?")
            setupSummary:SetText("Choose a starting point. You can change any option later, or switch preset from /era.")
            setupSummary:ClearAllPoints();setupSummary:SetPoint("TOPLEFT",30,-128);setupSummary:Show()
            RenderPresets(true)
        elseif page=="style" then
            -- The whole Appearance tab: the style buttons, Dark Mode extras and
            -- class colours.
            section:SetText("Choose your style");about:SetText(categories[TAB.appearance].about)
            self.walkEntries=function()return PageEntries(TAB.appearance)end
            ShowEntries(self.walkEntries(),true)
        elseif page=="tracker" then
            ShowEntries({},true)
            section:SetText("Quest tracker")
            setupSummary:SetText("Questie is installed. Only one quest tracker can show at a time. Which would you like?")
            setupSummary:ClearAllPoints();setupSummary:SetPoint("TOPLEFT",30,-128);setupSummary:Show()
            RenderTracker(true)
        elseif page=="font" then
            section:SetText("Damage & healing text")
            setupSummary:SetText("Pick the font and size of the damage and healing numbers over your targets.")
            setupSummary:ClearAllPoints();setupSummary:SetPoint("TOPLEFT",30,-128);setupSummary:Show()
            for _,check in ipairs({self.checks.damageFont,self.checks.damageTextScale}) do check:SetChecked() end
            ShowEntries({self.checks.damageFont,self.checks.damageTextScale},true)
        elseif not final then
            local walk=WALKTHROUGH[page]
            self.walkEntries=function()return WalkthroughEntries(walk)end
            SelectCategory(TAB[walk.tab],false,self.walkEntries())
        else
            ShowEntries({},true)
            section:SetText("You're ready")
            local pending=Pending()
            self.setupNeedsReload=#pending>0
            local message="All saved. The rest of the settings are here when you want them.\n\nCasting: the advanced cast bar, its ticks and latency.\n"..className..": resource bars and class tools.\nEvery other option has its own tab, and Search finds any of them.\n\n/era opens this window any time."
            if #pending>0 then
                message=message.."\n\nReload to apply these changes, then settings will open:\n\n"..table.concat(pending,", ")
            else message=message.."\n\nNo reload needed. Continue to explore the settings." end
            -- A new damage font only shows after logging out and back in:
            -- asked about below, or noted once put off.
            local waiting=EraUI.CombatFontWaiting and EraUI:CombatFontWaiting()
            if waiting and self.fontLater then
                message=message.."\n\nYour new damage font shows next time you log in."
            end
            setupSummary:ClearAllPoints();setupSummary:SetPoint("TOPLEFT",30,-156)
            setupSummary:SetText(message);setupSummary:Show()
            if waiting and not self.fontLater then fontQuestion:Show();PlaceLogout(true)end
        end
        for _,tab in ipairs(tabs) do tab:Hide() end
        nextPage.label:SetText(final and (self.setupNeedsReload and "Reload & explore" or "Explore settings") or "Next >")
        nextPage:Show()
        previousPage:Show()
        setupProgress:SetText(final and "FINISH" or page=="preset" and "START" or page=="style" and "APPEARANCE"
            or page=="tracker" and "QUEST TRACKER" or page=="font" and "DAMAGE TEXT" or ("OPTIONS  "..page.." / "..#WALKTHROUGH))
        setupProgress:Show();UpdateReloadHint(self)
    end
    function frame:SetSetupMode(enabled)
        ResetSearch()
        search:SetShown(not enabled)
        self.setupMode=enabled
        changelog:SetShown(not enabled)
        discord:SetShown(not enabled)
        self:SetWidth(enabled and 800 or WINDOW_WIDTH)
        self:SetScale(math.min(1,math.max(.1,(UIParent:GetWidth()-32)/self:GetWidth()),math.max(.1,(UIParent:GetHeight()-32)/650)))
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT",enabled and 30 or PAGE_LEFT,enabled and -84 or -38)
        about:ClearAllPoints()
        about:SetPoint("TOPLEFT",enabled and 30 or PAGE_LEFT,enabled and -114 or -68)
        self.settingsScroll:ClearAllPoints()
        self.settingsScroll:SetPoint("TOPLEFT",enabled and 30 or VIEW_LEFT,-148)
        self.settingsScroll:SetPoint("BOTTOMRIGHT",-40,94)
        hint:SetWidth(enabled and 330 or 380)
        self:UpdateLayoutNotice()
        if enabled then
            local tracker=EraUI.modules.QuestTrackerChoice
            self.trackerStep=tracker and tracker:QuestieInstalled() or false
            -- Start on the preset that matches the current look. A Custom
            -- look selects nothing: only a click applies a preset.
            local current=EraUI.Presets and EraUI.Presets:Current()
            self.setupPreset=current=="qol" and "qol" or current=="classic" and "classicqol" or nil
            self.setupPage=1;self.fontLater=nil
            self:RenderSetup()
        else
            self.walkEntries=nil
            navigation:Show();divider:Show()
            for _,tab in ipairs(tabs) do tab:Show() end
            RenderPresets(false);RenderTracker(false)
            -- The log out question belongs to setup; its OnHide takes the button too.
            setupSummary:Hide();setupProgress:Hide();nextPage:Hide();previousPage:Hide();fontQuestion:Hide()
            SelectCategory(self.selectedCategory or 1)
            UpdateReloadHint(self)
        end
    end
    -- Marks setup done, with settings to open once the UI next loads.
    SaveSetupDone=function()
        if EraUI.Classic and EraUI.Classic.db then
            if EraUI.Classic.CompleteCharacterSetup then EraUI.Classic.CompleteCharacterSetup() end
            EraUI.Classic.db.erauiSetupComplete=true
            EraUI.Classic.MirrorSave()
        end
        EraUIClassicCharDB=EraUIClassicCharDB or {}
        EraUIClassicCharDB.onboarding=EraUIClassicCharDB.onboarding or {}
        EraUIClassicCharDB.onboarding.exploreSettings=true
        EraUIClassicCharDB.onboarding.discoverTabs={[TAB.class]=true,[TAB.casting]=true}
        EraUIClassicCharDB.onboarding.discoveryHintsVersion=HINTS_VERSION
        if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
    end
    local function FinishSetup(reloadNow)
        if reloadNow and InCombatLockdown() then hint:SetText("Finish combat before reloading.");return end
        SaveSetupDone()
        -- Keep the click path direct: do not rebuild/hide the settings window
        -- before the client receives the reload request.
        if reloadNow then ReloadUI();return end
        frame:SetSetupMode(false)
        frame.selectedCategory=1
        SelectCategory(1)
        frame:Show()
        EraUIClassicCharDB.onboarding.exploreSettings=nil
        if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
        EraUI:Print("Casting and your class tab have more. /era opens settings any time.")
    end
    nextPage:SetScript("OnClick",function()
        if SetupPages()[frame.setupPage]=="final" then FinishSetup(#Pending()>0)
        else frame.setupPage=frame.setupPage+1;frame:RenderSetup() end
    end)
    previousPage:SetScript("OnClick",function()
        if frame.setupPage==1 then
            frame:Hide();frame:SetSetupMode(false)
            EraUI.Classic.setupRequested=true;EraUI.Classic.ShowWelcome();return
        end
        frame.setupPage=frame.setupPage-1
        frame:RenderSetup()
    end)
    frame.setupNext,frame.setupBack=nextPage,previousPage

    local function Refresh()
        changelog:SetShown(not frame.setupMode)
        discord:SetShown(not frame.setupMode)
        frame:RefreshCastDependencies()
        for key, check in pairs(frame.checks) do
            local checked = EraUI:GetSavedSetting(key) and true or false
            if EraUI.charSettingKeys and EraUI.charSettingKeys[key] then
                checked = EraUI:GetCharSetting(key) and true or false
            end
            
            check:SetChecked(not check.unavailable and checked)
            if check.unavailable then check.state:SetText("SOON") end
        end
        local r, g, b = ClassColour()
        reload:SetBackdropColor(r * 0.22, g * 0.22, b * 0.22, 1)
        reload:SetBackdropBorderColor(r, g, b, 1)
        SelectCategory(frame.selectedCategory or 1,true)
        ApplySearch()
        UpdateReloadHint(frame)
        frame:UpdateLayoutNotice()
        if frame.setupMode then frame:RenderSetup() end
    end
    -- Inherit the chosen UI scale; shrink only if the window would exceed the screen.
    local function FitToScreen()
        frame:SetScale(math.min(1, math.max(0.1, (UIParent:GetWidth() - 32) / frame:GetWidth()),
            math.max(0.1, (UIParent:GetHeight() - 32) / 650)))
        frame:RefreshInlineActions()
    end
    frame:SetScript("OnShow", function() FitToScreen(); Refresh() end)
    frame:SetScript("OnHide",function(self)
        self:StopMovingOrSizing();self.settingsMoving=false
        self:RefreshInlineActions()
        -- The new layout note shows once: seen now, it stays away.
        if self.layoutNotice:IsShown() then self:DismissLayoutNotice() end
    end)
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:SetScript("OnEvent", function() if frame:IsShown() then FitToScreen() end end)
    -- The game's Options window flips the same portrait switches; their cards
    -- follow at once, even with /era open beside it. Only EraUI's own cards
    -- change here.
    local cvarKeys = {}
    for key, cvar in pairs(EraUI.cvarSettings or {}) do cvarKeys[string.lower(cvar)] = key end
    local cvarWatch = CreateFrame("Frame")
    cvarWatch:RegisterEvent("CVAR_UPDATE")
    cvarWatch:SetScript("OnEvent", function(_, _, name)
        if type(name) ~= "string" or (issecretvalue and issecretvalue(name)) then return end
        local key = cvarKeys[string.lower(name)]
        local check = key and frame.checks[key]
        if not check then return end
        local now = GameSwitch(EraUI.cvarSettings[key])
        if now ~= nil and (check:GetChecked() and true or false) ~= now then
            EraUI:SetSetting(key, now);check:SetChecked(now)
        end
    end)
    frame.cvarWatch = cvarWatch
    Refresh()

    self.frame = frame
    EraUI.settingsFrame = frame
end



function SettingsModule:OpenSetup()
    if not self.frame then self:Initialize() end
    self.frame:SetSetupMode(true)
    self.frame:Show()
end

function SettingsModule:OpenSettings()
    if not self.frame then self:Initialize() end
    local wasSetup=self.frame.setupMode
    self.frame:SetSetupMode(false)
    if wasSetup then self.frame:Show()
    else self.frame:SetShown(not self.frame:IsShown()) end
end


-- Explicit show avoids the normal /era toggle closing an already open window.
function SettingsModule:ShowSettings()
    if not self.frame then self:Initialize() end
    self.frame.selectedCategory=1
    self.frame:SetSetupMode(false)
    self.frame:Show()
end

-- Tool navigation is an explicit show/focus action, never the /era toggle.
-- Clear search/setup first so the requested class controls have visible anchors.
function SettingsModule:ShowClassControls(key)
    if InCombatLockdown() then return end
    if not self.frame then self:Initialize() end
    local frame=self.frame
    frame.selectedCategory=TAB.class
    frame:SetSetupMode(false)
    frame:Show()
    local anchor=frame.checks[key]
    if not anchor or not anchor:IsShown() then return end
    local module
    if key=="classReminders" then
        module=EraUI.modules.ClassReminders
    else
        local tools=EraUI.modules.ClassTools
        module=tools and tools:ActiveModule()
    end
    if module then
        module.settingsFrame,module.settingsAnchor=frame,anchor
        if key=="classReminders" and module.AttachOptions then
            module:AttachOptions(frame,anchor)
        elseif module.Attach then
            module:Attach(frame,anchor)
        end
    end
    frame:LayoutSettings()
    local top,contentTop=anchor:GetTop(),frame.settingsContent:GetTop()
    if top and contentTop then frame:SetSettingsScroll(contentTop-top) end
end

