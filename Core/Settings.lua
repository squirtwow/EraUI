local _, EraUI = ...

local SettingsModule = {}
EraUI:RegisterModule("Settings", SettingsModule)

-- /era: what every option does, and the setup walkthrough. Where each option
-- sits (the grouped tabs, sub-tabs and sections) is Core/SettingsNav.lua;
-- the rows themselves are Core/SettingsRows.lua; the welcome card and the
-- walkthrough of the new layout are Core/SettingsTour.lua.
local reloadSettings = EraUI.reloadSettings
local Rows, Nav, Tour = EraUI.SettingsRows, EraUI.SettingsNav, EraUI.SettingsTour
local TAB = Nav.TAB

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
    darkAuraBorders="darkMode", darkAuraShadows="darkAuraBorders", darkMenuBar="darkMode", darkWindows="darkMode",
    blackPages="darkWindows", darkDebuffLines="darkAuraBorders",
}
-- The names on the rows, so a description points at a switch the player can find.
local DEPEND_NAMES = {
    advancedCastBar = "Advanced Cast Bar", spellbook = "Spellbook",
    unitFrames = "Unit Frames", actionBars = "Action Bars",
    afkScreen = "AFK Screen", darkMode = "Dark Mode", darkAuraBorders = "Dark Aura Borders",
    darkWindows = "Dark Windows",
}
-- The row each of those switches is on (Dark Mode is the Classic / Dark Mode choice).
local DEPEND_ROWS = {darkMode = "appearanceChoice"}
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
-- Options another addon takes over while it is loaded: greyed, can't be
-- switched, and the row says what handles them now. The saved choice is
-- kept for when that addon is gone (Core/Utils.lua). Squirt's nameplate addon
-- has the nameplates; another map addon showing unexplored areas has the map.
local HANDED_OVER = {
    friendlyNameplates = "Forever Enhanced Nameplates handles friendly plates.",
    enemyNameplates = "Forever Enhanced Nameplates handles enemy plates.",
    revealMap = "Another map addon is showing the unexplored areas.",
}
local HANDED_OVER_HELP = "Forever Enhanced Nameplates is on and handles nameplates, so EraUI leaves them alone. Your choice here is kept for when it's off."
local MAP_HANDED_OVER_HELP = "Another map addon already shows the unexplored areas, so EraUI leaves the map alone. Your choice is kept for when it stops."
local function HandedOver(key)
    if key == "revealMap" then return EraUI.MapRevealHandedOver ~= nil and EraUI:MapRevealHandedOver() == true end
    return HANDED_OVER[key] ~= nil and EraUI.NamePlatesHandedOver ~= nil and EraUI:NamePlatesHandedOver() == true
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
-- The row each sub-option sits under: its fold, its group or its first
-- DEPENDS option. GROUPS are for layout only, never greyed: the reward
-- profile goes with Highlight Reward Upgrades, Red Combo Points with the
-- floating orbs it colours.
local GROUPS = {rewardProfile = "rewardUpgradeHighlight", comboPointRed = "floatingComboPoints"}
local function GroupParent(key)
    return FOLDS[key] or GROUPS[key] or Parents(key)[1]
end
-- Earlier names of renamed options (one or a list), so searching an old name
-- still finds them.
local OLD_NAMES = {
    characterPanel = "Character / Reputation / Skills", bagsBank = "Bags / Bank",
    socialWindows = "Friends / Guild", groupFinderPvp = "Group Finder / PvP",
    blizzardSettings = "Blizzard Settings Skin", hideSecondaryNames = "Hide Secondary Names",
    classColors = "Class Colours in Chat", fastAutoLoot = "Faster Auto Loot", autoGossip = "Auto Gossip",
    discardCheapestJunk = "Discard Cheapest Junk When Bags Are Full",
    afkCameraNormal = {"AFK Camera: Normal Speed", "AFK Screen: Faster Camera"},
    afkTurnRight = {"AFK Camera: Circle Right", "AFK Screen: Circle Right"},
    afkZoom = {"AFK Camera: Zoom In", "AFK Screen: Zoom In"},
    afk24Hour = "AFK Screen: 24-Hour Clock", afkShowGuild = "AFK Screen: Show Guild",
    afkShowZone = "AFK Screen: Show Zone", afkShowDate = "AFK Screen: Show Date",
    afkShowQuote = "AFK Screen: Class Quote", darkAuraShadows = "Aura Shadows (Needs testing)",
    advancedCastClassFill = "Class-coloured Fill",
    cursorCastColour = "Custom cast-ring colour",
}
-- New-player hints pulse on the class and Casting tabs. They are saved by tab
-- number, so a new tab order is a new version: version 1 had your class at 12
-- and Casting at 13, version 2 at 2 and 5; version 3 is the grouped list.
local HINTS_VERSION = 3
local OLD_HINT_TABS = {[1] = {class = 12, casting = 13}, [2] = {class = 2, casting = 5}}
-- Search spells colour/color and grey/gray the same way.
local function Normalise(text)
    return (text:gsub("colour", "color"):gsub("grey", "gray"))
end
-- AFK Screen options apply live through its module.
local AFK_KEYS = {afkScreen=true, afkCameraNormal=true, afkTurnRight=true, afkZoom=true,
    afk24Hour=true, afkShowGuild=true, afkShowZone=true, afkShowDate=true, afkShowQuote=true}
-- The game's own switches mirrored on rows (EraUI.cvarSettings): what the
-- game holds now, or nil when it can't be read (a game without that switch
-- gives nothing back).
local function GameSwitch(cvar)
    if not GetCVarBool then return nil end
    local ok, value = pcall(GetCVarBool, cvar)
    if not ok or (issecretvalue and issecretvalue(value)) or value == nil then return nil end
    return value and true or false
end
-- A switch the game keeps for its own Options window (secure or read-only)
-- quietly ignores addon writes, so its row doesn't try.
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
-- Coming soon: while its module says so, a feature's row says "coming soon", its tick
-- stays empty, and it can't be switched on. Each module owns its comingSoon flag.
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

-- Each option's description in the footer, after its name: short enough for
-- two of the footer's lines (Tools/TestSettingsLayout checks every one),
-- with the one thing worth knowing first. What it needs first, a reload and
-- its default are added by the footer itself (Describe, below).
local settingHelp = {
    discardCheapestJunk = "With full bags, looting deletes your cheapest grey stack to make room and says which in chat. Never in combat; hold Shift to skip.",
    cursorCastRing = "A ring round your cursor that fills as you cast and drains as you channel. With Cursor Ring on, it sits just outside it.",
    portraitDebuffs = "Stuns, fears and other crowd control on player, target, focus and party portraits, with a countdown. Covers the level badge.",
    classColourBorders = "Player, target and focus frame borders in each player's class colour. Needs Dark Mode and Unit Frames.",
    darkMode = "Dark decorative artwork instead of Classic's stone and gold. Your character, party and raid frames keep their look.",
    trainer = "Classic trainer window and training controls, separate from the profession windows.",
    gameMenu = "Classic game menu borders and red buttons.",
    popups = "Classic borders and buttons for the game's confirmation prompts.",
    coordinates = "Your map position under the minimap. Off by default so it doesn't double up with another addon's coordinates.",
    showAllSpellRanks = "Every rank of each spell in the spellbook. It's the game's own setting. Can't change in combat.",
    classIconPortraitMine = "Your class icon instead of your face on your unit frame. It's the game's own setting, so the two always match.",
    classIconPortraitOthers = "Other players' class icons instead of faces on target, party and focus. It's the game's own setting, so both match.",
    hideEmptyActionSlots = "Hides empty action slots in normal play. They show again while you arrange your spells.",
    autoSellJunk = "Sells your grey items when you open a merchant.",
    autoRepair = "Repairs your gear with your own gold when you open a repair merchant.",
    hideSecondaryNames = "Hides Forever surnames, using the game's own display settings. New chat messages follow it; older ones stay as they were.",
    socialWindows = "Classic frames for the Friends, Who and Guild windows. Everything in them works as before.",
    talentWindow = "A Classic frame round your talent trees. Your talents and their buttons work as before.",
    friendlyNameplates = "Classic art and lettering on friendly nameplates. Your nameplate settings are kept.",
    enemyNameplates = "Classic art and lettering on enemy and neutral nameplates. Threat colours, casts and auras stay the game's.",
    lootWindow = "Classic loot window and item art. Looting, tooltips and scrolling work as before.",
    otherWindows = "Classic frames for windows without a switch of their own: trade, taxi, macros, calendar, inspect, the add-on list and more.",
    damageMeterSkin = "A Classic look for Blizzard's Damage Meter: dark frame, grey border, Classic bars and fonts. Its own options keep working.",
    disableAggroHighlight = "Hides the combat and threat glows on Classic player, target and focus frames.",
    questTracker = "Classic text and collapse buttons on the quest tracker. With another quest addon's tracker on, EraUI asks which one to show.",
    cleanMinimap = "Hides addon buttons round the minimap until you hover over it. Clock, mail, tracking and zoom stay put.",
    questDialogs = "Classic window for accepting and handing in quests. Quest text, rewards and buttons work as before.",
    professions = "Classic profession windows, progress bars and spell buttons. Recipes and controls work as before.",
    spellbook = "Classic parchment, frame and spell buttons. Spell tabs, casting and dragging to your bars work as before.",
    characterPanel = "Swaps the character window's side icons for labelled tabs along the bottom. Every pane works as before.",
    actionBars = "Your action buttons, menu, bags and XP bar on a Classic stone bar along the bottom. Your spells and keybinds are kept.",
    gryphons = "The gryphons at each end of the Classic action bar.",
    minimap = "The round Classic minimap border and zoom buttons, fitted to your map's size.",
    unitFrames = "Classic art and bar sizes on player, target and focus frames, with Classic debuff borders. Their controls are kept.",
    castBars = "Classic cast bars for you, target, focus, bosses and nameplates. Boss bars follow Forever Enhanced Cooldown Manager's Raid Timers when it's on.",
    vendorPrice = "Adds a sell price to item tooltips that don't show one.",
    questLevels = "Each quest's level in brackets before its title in the quest tracker.",
    bagSpace = "How many bag slots are free, on the backpack button. It's the game's own Show Free Bag Space setting where it has one.",
    classColors = "Player names in new chat messages in their class colour. Off uses the channel's colour. Older messages keep theirs.",
    hideStatusMessages = "Hides EraUI's startup and setting-change messages. Errors and replies to commands still show.",
    afkScreen = "When you go AFK the interface fades and your character stands beside a card with your name, zone and time away. Move to come back.",
    afkCameraNormal = "Circles the camera once a minute. Off circles once every two minutes.",
    afkTurnRight = "Circles the camera to the right. Off circles to the left.",
    afkZoom = "Slowly zooms in on your character, and your zoom comes back when you return. Skipped when the camera is already close.",
    afk24Hour = "The time as a 24-hour clock, like 15:07. Off shows 3:07 PM.",
    afkShowGuild = "Your guild's name on the AFK screen.",
    afkShowZone = "Your zone and subzone on the AFK screen.",
    afkShowDate = "Today's date on the AFK screen.",
    afkShowQuote = "A famous Classic line for your class, like a loading screen tip. A new one each time you're away.",
    tooltipClassColours = "A player's tooltip border, name and class in their class colour, on EraUI's tooltips or the game's own. NPCs keep theirs.",
    bagItemLevels = "Item levels on the gear in your bags, in quality colours, with a green arrow on an upgrade over what you wear. Not the bank yet.",
    characterItemLevels = "Item levels on the gear you wear, in quality colours, in EraUI's character window or Blizzard's. They match Bag Item Levels.",
    darkAuraBorders = "Thin dark borders round your own buff and debuff icons. Debuffs keep their coloured border, or a thin line with Thin Debuff Colours.",
    darkAuraShadows = "A soft shadow round your own buff and debuff icons, just outside the dark border. It never covers the next icon.",
    darkDebuffLines = "Your debuffs get the dark border, with a thin line inside in the debuff's colour, like blue for magic. Target and focus keep theirs.",
    darkMenuBar = "Darkens the bronze frames behind the menu bar buttons with the Darkness slider. The icons keep their colours.",
    darkWindows = "Darkens the red buttons, pop-ups, window edges and book pages Dark Mode left light, with the Darkness slider. Gold text stays gold.",
    blackPages = "Near black spellbook and Professions pages instead of Dark Windows' brown-grey. Names keep their gold and text stays readable.",
    flatBars = "A plain, even fill instead of Classic's shaded one on unit-frame and cast bars. Their colours stay. Works with Classic or Dark Mode.",
    advancedCastBar = "Your own cast bar with the spell icon, cast time and latency. A preview shows while /era is open; hover + on it to move or resize.",
    advancedCastClassFill = "A muted class colour instead of gold. Priests get dark silver so the text stays readable.",
    advancedCastTicks = "Marks each tick on channelled spells whose description gives the ticks. Not every channel does.",
    castBarClassBorder = "Class-coloured outlines on player, target, focus and your nameplate cast bars. NPCs keep theirs.",
    mapQuestObjectives = "Blizzard's quest objectives on the world map, using the game's own map filter.",
    movableMap = "Drag the world map's header to move it, and its edges or corners to resize it. Normal and full size each keep their own place.",
    revealMap = "Unexplored parts of the world map shaded grey until you explore them. No exploration credit.",
    autoQuests = "Accepts quests and hands in finished ones with one reward or none. Hold Shift to skip; reward choices stay yours.",
    autoGossip = "Picks the only free dialogue option for you. Leaves quests alone. Hold Shift to skip.",
    rewardUpgradeHighlight = "Marks the quest reward that's the best upgrade for your stat profile. You still choose.",
    trainingGuide = "A tab in the Classic spellbook listing the spells still to learn, with their levels, costs and a search. Unchecked prices show a ?.",
    classicChatDragging = "Right-click General or a docked chat tab to unlock, drag and lock the chat window. Its place is remembered.",
    tooltipSkin = "Classic dark tooltips with grey borders for items, spells, units and map buttons. In Dark Mode the border follows the Darkness slider.",
    hideZoneText = "Hides the big zone and subzone names that pop up. The minimap still shows them.",
    maxCameraZoom = "Lets the camera pull back further, to 2.6. Off puts your earlier limit back.",
    cursorRing = "A ring follows your mouse pointer. Its colour, size and thickness show under it while it's on.",
    cursorTrail = "A short, soft trail follows your cursor and fades when you stop. Its options show under it while it's on.",
    hunterFeed = "A button to feed your pet when it's unhappy. Right-click the button to unlock and move it; Pet Feeding Options are below.",
    mageSupplies = "Suggests the food and water to conjure for your target's level. Conjure them from Conjuring & Trade Options below.",
    mageAutoTrade = "Puts full stacks of suitable conjured food and water in trade. Set how many in Conjuring & Trade Options below.",
    roguePoisons = "Set how many poisons you want: at a poison vendor it buys their materials and Flash Powder, then crafts them. Opens from the row beside it.",
    questLog = "Classic quest log and its quest map pane.",
    bagsBank = "Classic bag and bank windows.",
    merchantSkin = "Classic merchant and buyback windows.",
    mailSkin = "Classic mailbox and letter windows.",
    auctionHouse = "Classic auction house window.",
    groupFinderPvp = "Classic group finder and PvP windows.",
    blizzardSettings = "Classic frame for the game's own Settings window.",
    updateCheck = "Tells you in chat when someone in your guild or group has a newer EraUI.",
    hideKeybindText = "Hides the key labels on your action buttons. Your keybinds still work. A change made in combat waits until it ends.",
    hideMacroText = "Hides macro names on your action buttons. A change made in combat waits until it ends.",
    matchFocusSize = "Your focus frame takes the target frame's size. Off, it keeps the game's own layout.",
    advancedCastLatency = "A red zone at the end of the bar, as long as your world latency. It shows whenever the cast's length can be read.",
    fastAutoLoot = "Takes all the loot at once, without the loot window. Not in combat; hold Shift to skip.",
    junkValueSummary = "When you open a merchant, says in chat how many grey items you carry and what they sell for.",
    durabilityWarning = "Warns you once when any gear you wear drops to 20% durability or less. Repairing resets it.",
    linkToggle = "Clicking an item or spell link in chat a second time closes its tooltip.",
    showWelcomeOnLogin = "Shows the EraUI welcome each time you log in. A /reload doesn't show it.",
    blockDuels = "Declines duel requests for you. Hold Shift to skip.",
    blockPartyInvites = "Declines group invites for you. With Party from Friends on, your friends' invites are still accepted. Hold Shift to skip.",
    partyFromFriends = "Accepts group invites from your character friends, even with Block Party Invites on. Hold Shift to skip.",
    inviteFromWhispers = "A character friend who whispers you \"invite\" gets a group invite, as long as you're able to invite.",
    autoSummon = "Accepts a summon after one second, outside combat. Hold Shift to skip.",
    autoResurrect = "Accepts a resurrection outside combat. Hold Shift to skip.",
    releasePvP = "Releases your spirit one second after you die, in battlegrounds only. Hold Shift to skip.",
    contextMenus = "Classic borders and buttons for right-click menus.",
    tooltipIDs = "Item, spell and NPC ID numbers on tooltips, where the game gives them. They show from your next hover.",
    spellbookCombatDrag = "Lets you drag spells from the spellbook to your bars in a fight, with the game's own spell buttons.",
    floatingComboPoints = "Your combo points as orbs below your character. Hover them and right-click the + to move or resize; left-click it to lock.",
    comboPointRed = "Draws the floating combo point orbs in red instead of gold.",
    energyBar = "A floating energy bar with its value. Hover the bar for a + to move or resize it.",
    rageBar = "A floating rage bar with its value. Hover the bar for a + to move or resize it.",
    manaBar = "A floating mana bar with its value. Hover the bar for a + to move or resize it.",
    druidResourceBar = "One floating bar for mana, cat energy or bear rage, switching with your form. Hover it for a + to move or resize it.",
    swingTimer = "Bars for your main-hand and off-hand swings. Hover a bar for a + to move or resize it.",
    rangedSwingTimer = "A bar for your ranged attacks and wand shots, with a ranged weapon equipped. Hover it for a + to move or resize it.",
    cursorRingClassColour = "The ring in your class colour. Off, it's white.",
    cursorCastClassColour = "The cast ring in your class colour. Off, it uses the custom colour below.",
    cursorTrailClassColour = "The trail in your class colour. Off, it uses the custom colour below.",
    classReminders = "Big alerts on your screen when a class buff, your pet, a poison or a supply is missing. Its options are in the box below.",
}

-- Descriptions for rows that never had a card of their own text.
settingHelp.presets = "A ready-made set of options: Quality of Life only, or the full Classic look. You can change anything afterwards."
settingHelp.darkModeDarkness = "From light grey (40) to near black (90). Everything Dark Mode touches follows it at once."
settingHelp.darkenClassColours = "Class-coloured unit borders darken with the slider too. Off, they keep their full class colour. Dark Mode only."
settingHelp.cursorRingSize = "How wide the cursor ring is."
settingHelp.cursorRingThickness = "How thick the ring's line is."
settingHelp.cursorCastSize = "How wide the cast ring is."
settingHelp.cursorCastOpacity = "How solid the cast ring looks."
settingHelp.cursorTrailSize = "How wide the trail is."
settingHelp.cursorTrailOpacity = "How solid the trail looks."
settingHelp.cursorTrailLength = "How long the trail takes to fade."
settingHelp.cursorCastColour = "Click to choose a custom colour. Used while Class-coloured Cast Ring is off."
settingHelp.cursorTrailColour = "Click to choose a custom colour. Used while Class-coloured Cursor Trail is off."
settingHelp.damageFont = "The font of the damage and healing numbers over your targets."
settingHelp.damageTextScale = "How big the damage and healing numbers over your targets are."
-- Rows whose description is another setting's (the Classic / Dark Mode choice).
local HELP_KEY = {appearanceChoice = "darkMode"}

-- Not seen working in game yet: the row says "experimental" after its name
-- (Core/SettingsRows.lua), so its description doesn't have to.
local EXPERIMENTAL = {darkAuraShadows = true, darkDebuffLines = true, darkWindows = true, blackPages = true,
    characterItemLevels = true, flatBars = true}
local function NeedsTesting(key)
    return EXPERIMENTAL[key] == true
end

local function DefaultText(key)
    if key == "presets" or key == "rewardProfile" or key == "classTools" or key:find("^more") then return nil end
    if key == "appearanceChoice" then return "Default: Classic." end
    if key == "showAllSpellRanks" or (EraUI.cvarSettings and EraUI.cvarSettings[key]) then
        return "Default: keep your existing game preference."
    end
    if key == "damageTextScale" then return "Default: 1.00x." end
    if key == "cursorCastColour" or key == "cursorTrailColour" then return "Default: white." end
    local default = EraUI.settingDefaults[key]
    if key == "damageFont" then
        for _, font in ipairs(EraUI.CombatFonts or {}) do
            if font.key == default then return "Default: " .. font.name .. "." end
        end
        return nil
    end
    if key == "cursorTrailLength" and type(default) == "number" then return string.format("Default: %.2fs.", default / 100) end
    if type(default) == "number" then return "Default: " .. default .. "." end
    return "Default: " .. (default and "On" or "Off") .. "."
end

-- A row's description for the footer: its help (or its summary), then, each
-- only when it applies, Coming soon, the switch it needs first (with that
-- switch's tab when it is elsewhere), a hand-over note, a reload line (not
-- for a Coming soon switch, which can't be turned on) and its default. The
-- extras come back as one line, gold then grey.
local function Describe(frame, row)
    local key = row.settingKey or ""
    local help = row.helpText and row.helpText()
    help = help or settingHelp[HELP_KEY[key] or key] or row.summary or ""
    local extras = {}
    if row.unavailable then extras[#extras + 1] = "Coming soon: not finished yet." end
    if row.dependencyDisabled then
        local missing = MissingParent(key) or Parents(key)[1]
        local where = ""
        local home = frame.rowHome and frame.rowHome[DEPEND_ROWS[missing] or missing]
        local mine = frame.rowHome and frame.rowHome[key]
        if home and mine and (home.tab ~= mine.tab or home.sub ~= mine.sub) then
            where = " (" .. Nav.Crumb(frame, home) .. ")"
        end
        extras[#extras + 1] = "Switch on " .. (DEPEND_NAMES[missing] or "its parent option") .. " first" .. where .. "."
    end
    local default
    if row.handedOver then
        extras[#extras + 1] = key == "revealMap" and MAP_HANDED_OVER_HELP or HANDED_OVER_HELP
    else
        if key == "damageFont" then extras[#extras + 1] = "Needs a log out to apply. A /reload won't do it."
        elseif reloadSettings[HELP_KEY[key] or key] and not row.unavailable then extras[#extras + 1] = "Needs /reload to apply." end
        default = DefaultText(key)
    end
    local text = #extras > 0 and ("|cffe6c36a" .. table.concat(extras, " ") .. "|r") or ""
    if default then text = text .. (text ~= "" and "  " or "") .. "|cff9aa0a8" .. default .. "|r" end
    return help, text
end

-- The footer's hint: whether a reload is waiting (or a note left for you).
local function HintText(frame)
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
    if frame.reloadButton then frame.reloadButton:SetShown(pending) end
    if frame.footerMessage then frame.reloadHint:SetText(frame.footerMessage); return end
    frame.reloadHint:SetText(pending
        and "Changes saved. Click Reload UI to apply them."
        or "No reload needed for your current settings.")
end

local function UpdateReloadHint(frame)
    -- Called after every settings change: keep dependent options and the
    -- preset label current too.
    if frame.RefreshDependencies then frame:RefreshDependencies() end
    if frame.UpdatePresetLabel then frame:UpdatePresetLabel() end
    HintText(frame)
end

-- A row's saved value (swing timers are kept per character).
local function Saved(key)
    if EraUI.charSettingKeys and EraUI.charSettingKeys[key] then return EraUI:GetCharSetting(key) and true or false end
    return EraUI:GetSavedSetting(key) and true or false
end

-- A switch row. Its tab and place come from Core/SettingsNav.lua. (icon is
-- from the old cards and goes unused.)
local function MakeCheck(parent, label, key, icon, summary, unavailable)
    local check = Rows.Tick(parent, key, label, summary, unavailable)
    check:SetChecked(not check.unavailable and Saved(key))
    check:SetScript("OnClick", function(self)
        -- Greyed, handed over or Coming soon: nothing changes, the tick goes back.
        if unavailable or self.dependencyDisabled or self.handedOver then
            self:SetChecked(not self.unavailable and Saved(key))
            return
        end
        local charKey = EraUI.charSettingKeys and EraUI.charSettingKeys[key]
        local previous
        if charKey then previous = EraUI:GetCharSetting(key) else previous = EraUI:GetSavedSetting(key) end
        local value = self:GetChecked() and true or false
        if charKey then EraUI:SetCharSetting(key, value) else EraUI:SetSetting(key, value) end
        UpdateReloadHint(parent)
        if parent.setupMode and reloadSettings[key] then return end
        -- Darken class colours too re-tints at once with the Darkness slider's
        -- own refresh (Core/Appearance.lua), quietly as its old tick did.
        if key=="darkenClassColours" then
            local classic=EraUI.Classic or {}
            if classic.RefreshDarkness then classic.RefreshDarkness() end
            return
        end
        if AFK_KEYS[key] then
            if EraUI.modules.AFKScreen then EraUI.modules.AFKScreen:Refresh() end
            if key=="afkScreen" then EraUI:Status(value and "AFK Screen enabled. Type /era afk to preview it." or "AFK Screen disabled.")
            else EraUI:Status("AFK Screen: "..label..(value and " enabled." or " disabled.")) end
            return
        end
        -- Dark Menu Bar, Dark Windows and Black Pages repaint at once
        -- (Classic/BarSkins.lua, Core/Appearance.lua), through EraUI.Classic:
        -- this file has no ns.
        if key=="darkMenuBar" or key=="darkWindows" or key=="blackPages" then
            local classic=EraUI.Classic or {}
            local refresh=classic[key=="darkMenuBar" and "RefreshDarkMenuBar" or "RefreshDarkWindows"]
            if refresh then refresh() end
            local name=key=="darkMenuBar" and "Dark Menu Bar " or key=="darkWindows" and "Dark Windows " or "Black Pages "
            local later=key=="darkMenuBar" and " It shows once Dark Mode is applied." or " They show once Dark Mode is applied."
            EraUI:Status(name..(value and "enabled." or "disabled.")..(value and not EraUI:GetSetting("darkMode") and later or ""))
            return
        end
        -- Flat Bars changes the unit-frame and cast bars' fill at once
        -- (Classic/Skin.lua, Modules/AdvancedCastBar.lua); a protected bar in
        -- a fight follows when it ends.
        if key=="flatBars" then
            local classic=EraUI.Classic or {}
            local done=true
            if classic.RefreshFlatBars then done=classic.RefreshFlatBars()~=false end
            if EraUI.modules.AdvancedCastBar then EraUI.modules.AdvancedCastBar:Refresh() end
            EraUI:Status("Flat Bars "..(value and "enabled." or "disabled.")..(done and "" or " Some bars change when combat ends."))
            return
        end
        if key=="darkAuraBorders" or key=="darkAuraShadows" or key=="darkDebuffLines" then
            if EraUI.modules.AuraStyle then EraUI.modules.AuraStyle:RefreshBorders() end
            local name=key=="darkAuraShadows" and "Aura Shadows " or key=="darkDebuffLines" and "Thin Debuff Colours "
                or "Dark Aura Borders "
            EraUI:Status(name..(value and "enabled." or "disabled.")
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
        if key=="characterItemLevels" then
            if EraUI.modules.CharacterItemLevels then EraUI.modules.CharacterItemLevels:Refresh() end
            EraUI:Status("Character Item Levels "..(value and "enabled. Open your character window to see it." or "disabled."))
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
        -- Update Notice, on Chat & Names.
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
        if key=="hunterFeed" or key=="mageSupplies" or key=="mageAutoTrade" or key=="roguePoisons" or key=="classReminders" then
            local tools=EraUI.modules.ClassTools
            if tools then tools:Refresh() end
            -- Every class has class reminders, whichever class tool it runs
            -- (a rogue's is Poison Supplies), so they and their clicks follow at once.
            local reminders=EraUI.modules.ClassReminders
            if key=="classReminders" and reminders and not(tools and tools:ActiveModule()==reminders) then reminders:Refresh() end
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
            -- its Options window, or kept its old value, the row follows the
            -- game and says where to change it (two lines, so a test in game
            -- tells which happened).
            local cvar = EraUI.cvarSettings[key]
            if InCombatLockdown() then
                EraUI:SetSetting(key,previous);self:SetChecked(previous)
                EraUI:Print("Finish combat before changing portraits.");return
            end
            if GameOnlySwitch(cvar) then
                EraUI:SetSetting(key,previous);self:SetChecked(previous)
                EraUI:Print("Only Options > Interface can change this portrait setting.");return
            end
            local wrote = pcall(SetCVar,cvar,value and "1" or "0")
            local now = GameSwitch(cvar)
            if not wrote or now == nil then
                EraUI:SetSetting(key,previous);self:SetChecked(previous)
                EraUI:Print("This game version doesn't have that portrait setting.");return
            end
            if now ~= value then
                EraUI:SetSetting(key,now);self:SetChecked(now)
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

-- The rules the navigation, footer and tests read (Core/SettingsNav.lua).
EraUI.SettingsRules = {
    DEPENDS = DEPENDS, DEPEND_NAMES = DEPEND_NAMES, DEPEND_ROWS = DEPEND_ROWS, Parents = Parents,
    MissingParent = MissingParent, HANDED_OVER = HANDED_OVER, HANDED_OVER_HELP = HANDED_OVER_HELP,
    MAP_HANDED_OVER_HELP = MAP_HANDED_OVER_HELP, HandedOver = HandedOver, FOLDS = FOLDS, Folded = Folded,
    GROUPS = GROUPS, GroupParent = GroupParent, OLD_NAMES = OLD_NAMES, Normalise = Normalise,
    ComingSoon = ComingSoon, settingHelp = settingHelp, HELP_KEY = HELP_KEY, NeedsTesting = NeedsTesting,
    EXPERIMENTAL = EXPERIMENTAL,
    Describe = Describe, DefaultText = DefaultText, HINTS_VERSION = HINTS_VERSION,
}

-- Rows ----------------------------------------------------------------------

local function UpdatePresetLabel(frame)
    local P = EraUI.Presets
    local row = frame.checks.presets
    if row and P then row.text:SetText("Preset: " .. P.NAMES[P:Current()]) end
end

-- Appearance: the Classic / Dark Mode choice, Presets, the Darkness slider
-- and the Dark Mode and class colour options.
local function BuildLookRows(frame)
    local choice
    choice = Rows.Choice(frame, "appearanceChoice", "Look", {"Classic", "Dark Mode"}, function(index)
        -- Appearance only changes the theme; it never overwrites feature or QoL choices.
        EraUI:SetSetting("darkMode", index == 2)
        choice:SetChecked()
        UpdateReloadHint(frame)
    end)
    choice.searchText = "appearance style look theme classic dark mode artwork"
    choice.summary = "Classic or Dark Mode."
    choice.SetChecked = function() Rows.SelectChoice(choice, EraUI:GetSavedSetting("darkMode") and 2 or 1) end
    choice:HookScript("OnShow", function() choice:SetChecked() end)
    frame.appearanceChoices = choice.buttons
    local presets = Rows.ButtonRow(frame, "presets", "Preset", "Choose a preset", function()
        if EraUI.Presets then EraUI.Presets:Show() end
    end)
    presets.searchText = "presets preset quality of life classic look choose"
    presets.summary = "Choose a ready-made set of options."
    presets.SetChecked = function() UpdatePresetLabel(frame) end
    frame.presetButton, frame.presetLabel = presets.button, presets.text
    -- Frame Style, under the choice: Flat Bars for now.
    local flat = MakeCheck(frame, "Flat Bars", "flatBars", nil, "Plain, even fill on unit-frame and cast bars. Works with Classic or Dark Mode.", false)
    flat.searchText = flat.searchText .. " flat bar texture solid plain fill frame style"
    -- Darkness: dragging re-tints the Dark Mode artwork at once
    -- (Core/Appearance.lua). Its value shows once, in "Darkness: 58"; the
    -- grey swatch that sat after the slider read as an empty box, so it went.
    local ns = EraUI.Classic or {}
    local low, high, default = ns.DARKNESS_MIN or 40, ns.DARKNESS_MAX or 90, ns.DARKNESS_DEFAULT or 58
    local darkness = Rows.Slider(frame, "darkModeDarkness", "Darkness", {low = low, high = high, step = 1, wide = true,
        read = function() return tonumber(EraUI:GetSavedSetting("darkModeDarkness")) or default end,
        save = function(value)
            EraUI:SetSetting("darkModeDarkness", value)
            if ns.RefreshDarkness then ns.RefreshDarkness() end
        end})
    darkness.searchText = "appearance dark mode darkness darker black grey gray brightness slider"
    darkness.summary = "How dark Dark Mode is."
    MakeCheck(frame, "Darken class colours too", "darkenClassColours", nil, "Class-coloured unit borders darken with the Darkness slider too.", false)
    MakeCheck(frame, "Dark Aura Borders", "darkAuraBorders", nil, "Thin dark borders around your buff and debuff icons. Dark Mode only.", false)
    MakeCheck(frame, "Aura Shadows", "darkAuraShadows", nil, "A soft shadow behind your buff and debuff icons. Needs Dark Aura Borders.", false)
    MakeCheck(frame, "Thin Debuff Colours", "darkDebuffLines", nil, "Debuffs: dark border with a thin line in their colour.", false)
    MakeCheck(frame, "Dark Menu Bar", "darkMenuBar", nil, "Dark frames behind the menu bar buttons. Dark Mode only.", false)
    MakeCheck(frame, "Dark Windows", "darkWindows", nil, "Darker buttons, pop-ups, frames and book pages. Dark Mode only.", false)
    MakeCheck(frame, "Black Pages", "blackPages", nil, "Black spellbook and professions pages instead of brown-grey.", false)
    MakeCheck(frame, "Class-coloured Chat Names", "classColors", nil, "Colour new player names by class.", false)
    MakeCheck(frame, "Class-coloured Tooltips", "tooltipClassColours", nil, "Player tooltips: border, name and class in the player's class colour.", false)
    MakeCheck(frame, "Class-coloured Unit Borders", "classColourBorders", nil, "Class-coloured unit frame borders. Needs Dark Mode and Unit Frames.", false)
    MakeCheck(frame, "Class-coloured Cast Border", "castBarClassBorder", nil, "Class-coloured outlines on players' cast bars. NPCs keep theirs.", false)
end

-- The plain switches of the other tabs.
local function BuildToggleRows(frame)
    -- Action Bars.
    MakeCheck(frame, "Action Bars", "actionBars", nil, "Stone dock and Classic action buttons.", false)
    MakeCheck(frame, "Show Gryphons", "gryphons", nil, "Show action-bar end decorations.", false)
    MakeCheck(frame, "Hide Empty Action Slots", "hideEmptyActionSlots", nil, "Reveal empty slots when arranging spells.", false)
    MakeCheck(frame, "Hide Keybind Text", "hideKeybindText", nil, "Hide action-button key labels; bindings still work. Combat changes wait.", false)
    MakeCheck(frame, "Hide Macro Names", "hideMacroText", nil, "Hide action-button macro names. Combat changes wait.", false)
    -- Frames & Nameplates.
    MakeCheck(frame, "Unit Frames", "unitFrames", nil, "Player, target and focus styling.", false)
    MakeCheck(frame, "Match Focus Size", "matchFocusSize", nil, "Use target size for focus. Reload to apply; off uses your native layout.", false)
    MakeCheck(frame, "Hide Aggro Highlight", "disableAggroHighlight", nil, "Hide unit-frame threat decoration.", false)
    MakeCheck(frame, "Important Debuffs on Portraits", "portraitDebuffs", nil, "CC icons and countdowns, even in combat. The icon covers the level badge.", false)
    MakeCheck(frame, "Class Icon Portraits: Mine", "classIconPortraitMine", nil, "Your class icon instead of your face.", false)
    MakeCheck(frame, "Class Icon Portraits: Others", "classIconPortraitOthers", nil, "Other players' class icons instead of faces.", false)
    MakeCheck(frame, "Friendly Nameplates", "friendlyNameplates", nil, "Classic look on friendly nameplates.", false)
    MakeCheck(frame, "Enemy Nameplates", "enemyNameplates", nil, "Classic look on enemy and neutral nameplates.", false)
    -- Casting.
    MakeCheck(frame, "Cast Bars", "castBars", nil, "Player, target, focus, boss and nameplate casts.", false)
    MakeCheck(frame, "Advanced Cast Bar", "advancedCastBar", nil, "Icon, time and latency. Hover + on its preview to move or resize.", false)
    MakeCheck(frame, "Class-coloured Cast Fill", "advancedCastClassFill", nil, "A muted class colour instead of gold. Priests get dark silver.", false)
    MakeCheck(frame, "Channel Tick Marks", "advancedCastTicks", nil, "Tick marks on channels, when the spell's text gives them.", false)
    MakeCheck(frame, "Latency Zone", "advancedCastLatency", nil, "Red end zone based on world latency. Shown when cast duration is readable.", false)
    -- Map & Minimap.
    MakeCheck(frame, "Minimap", "minimap", nil, "Classic round map and controls.", false)
    MakeCheck(frame, "Clean Minimap", "cleanMinimap", nil, "Addon buttons appear on hover.", false)
    MakeCheck(frame, "Coordinates", "coordinates", nil, "Your map position beneath the minimap.", false)
    MakeCheck(frame, "Map Quest Objectives", "mapQuestObjectives", nil, "Blizzard's quest objectives on the world map.", false)
    MakeCheck(frame, "Movable World Map", "movableMap", nil, "Drag the header to move; resize from the corners and edges.", false)
    MakeCheck(frame, "Reveal World Map", "revealMap", nil, "Show unexplored areas in grey. No exploration credit.", false)
    -- Quests.
    MakeCheck(frame, "Quest Log", "questLog", nil, "Classic quest log and quest map pane.", false)
    MakeCheck(frame, "Quest Dialogue", "questDialogs", nil, "Quest offers, rewards and turn-ins.", false)
    MakeCheck(frame, "Quest Tracker", "questTracker", nil, "Classic quest watch presentation.", false)
    MakeCheck(frame, "Quest Levels", "questLevels", nil, "Show levels on tracked quests.", false)
    MakeCheck(frame, "Automate Quests", "autoQuests", nil, "Accept and turn in quests with one reward or none. Shift pauses.", false)
    MakeCheck(frame, "Auto-gossip", "autoGossip", nil, "Picks the only free dialogue option. Hold Shift to bypass.", false)
    MakeCheck(frame, "Highlight Reward Upgrades", "rewardUpgradeHighlight", nil, "Suggests a reward using your stat profile. You still choose.", false)
    -- Character & Spells.
    MakeCheck(frame, "Character Window", "characterPanel", nil, "Classic panels, rows and bottom tabs.", false)
    MakeCheck(frame, "Character Item Levels", "characterItemLevels", nil, "Item levels on the gear you wear, in quality colours.", false)
    MakeCheck(frame, "Talents", "talentWindow", nil, "Classic talent trees and native talent actions.", false)
    MakeCheck(frame, "Trainer", "trainer", nil, "Classic trainer window and training controls.", false)
    MakeCheck(frame, "Professions", "professions", nil, "Classic profession windows.", false)
    MakeCheck(frame, "Spellbook", "spellbook", nil, "Classic book and native spell actions.", false)
    MakeCheck(frame, "Combat Spell Dragging", "spellbookCombatDrag", nil, "Use native spell buttons to drag spells during combat. Reload to apply.", false)
    MakeCheck(frame, "Training Guide", "trainingGuide", nil, "A training tab in the spellbook: spells to learn, levels and costs.", false)
    MakeCheck(frame, "Show All Spell Ranks", "showAllSpellRanks", nil, "Keep every rank visible in the spellbook.", false)
    -- Bags & Vendors.
    MakeCheck(frame, "Bags & Bank", "bagsBank", nil, "Classic bag and bank windows.", false)
    MakeCheck(frame, "Bag Space", "bagSpace", nil, "Show free slots on the backpack.", false)
    MakeCheck(frame, "Bag Item Levels", "bagItemLevels", nil, "Item levels in quality colours, with upgrade arrows.", ComingSoon("bagItemLevels"))
    MakeCheck(frame, "Loot Window", "lootWindow", nil, "Classic loot window and item rows.", false)
    MakeCheck(frame, "Faster Auto-loot", "fastAutoLoot", nil, "Loot immediately. Hold Shift for manual looting; inactive in combat.", false)
    MakeCheck(frame, "Discard Junk When Full", "discardCheapestJunk", nil, "Frees the cheapest grey stack when looting with full bags. Shift bypasses.", false)
    MakeCheck(frame, "Merchant", "merchantSkin", nil, "Classic merchant and buyback windows.", false)
    MakeCheck(frame, "Auto-sell Junk", "autoSellJunk", nil, "Sell grey items at merchants.", false)
    MakeCheck(frame, "Auto-repair", "autoRepair", nil, "Repair using your own gold.", false)
    MakeCheck(frame, "Vendor Prices", "vendorPrice", nil, "Add missing item selling prices.", false)
    MakeCheck(frame, "Junk Value Summary", "junkValueSummary", nil, "Report grey-item vendor value when opening a merchant, before sales.", false)
    MakeCheck(frame, "Low Durability Warning", "durabilityWarning", nil, "Warn once when equipped gear falls to 20% or less; resets after repair.", false)
    -- Chat & Names.
    MakeCheck(frame, "Hide Surnames", "hideSecondaryNames", nil, "Hide Forever surnames.", false)
    MakeCheck(frame, "Classic Chat Dragging", "classicChatDragging", nil, "Right-click a chat tab to unlock, drag and lock chat. Reload to apply.", false)
    MakeCheck(frame, "Click Links Again to Close", "linkToggle", nil, "Click an item or spell link in chat again to close its tooltip.", false)
    MakeCheck(frame, "Quiet Mode", "hideStatusMessages", nil, "Hide EraUI startup and change notices.", false)
    MakeCheck(frame, "Welcome on Login", "showWelcomeOnLogin", nil, "Show the EraUI welcome on login, not ordinary UI reloads.", false)
    local update = MakeCheck(frame, "Update Notice", "updateCheck", nil, "In chat, when a guild or group member has a newer EraUI.", false)
    update.searchText = update.searchText .. " version newer"
    -- Group & Invites.
    MakeCheck(frame, "Friends & Guild", "socialWindows", nil, "Classic Friends, Who and Guild windows.", false)
    MakeCheck(frame, "Group Finder & PvP", "groupFinderPvp", nil, "Classic group finder and PvP windows.", false)
    MakeCheck(frame, "Block Duels", "blockDuels", nil, "Decline duel requests. Hold Shift to handle a request manually.", false)
    MakeCheck(frame, "Block Party Invites", "blockPartyInvites", nil, "Decline invitations, except enabled friend acceptance. Shift bypasses.", false)
    MakeCheck(frame, "Party from Friends", "partyFromFriends", nil, "Accept invites from character friends. Takes priority over invite blocking.", false)
    MakeCheck(frame, "Invite from Whispers", "inviteFromWhispers", nil, "Character friends can whisper invite to join. Requires permission to invite.", false)
    MakeCheck(frame, "Accept Summons", "autoSummon", nil, "Accept after one second outside combat. Hold Shift to bypass.", false)
    MakeCheck(frame, "Accept Resurrection", "autoResurrect", nil, "Accept resurrection requests outside combat. Hold Shift to bypass.", false)
    MakeCheck(frame, "Release in Battlegrounds", "releasePvP", nil, "Release after one second, in battlegrounds only. Shift bypasses.", false)
    -- Windows & Tooltips.
    MakeCheck(frame, "Game Menu", "gameMenu", nil, "Classic menu border and buttons.", false)
    MakeCheck(frame, "Popups", "popups", nil, "Classic confirmation prompts.", false)
    MakeCheck(frame, "Settings Window", "blizzardSettings", nil, "Classic frame for the game's Settings window.", false)
    MakeCheck(frame, "Mail", "mailSkin", nil, "Classic mailbox and letter windows.", false)
    MakeCheck(frame, "Auction House", "auctionHouse", nil, "Classic auction house window.", false)
    MakeCheck(frame, "Damage Meter", "damageMeterSkin", nil, "Classic frame, bars and text for Blizzard's damage meter.", false)
    MakeCheck(frame, "Other Windows", "otherWindows", nil, "Trade, taxi, macros, calendar and other windows.", false)
    MakeCheck(frame, "Context Menus", "contextMenus", nil, "Not implemented yet.", true)
    MakeCheck(frame, "Tooltips", "tooltipSkin", nil, "Dark tooltips with grey borders, item comparisons included.", false)
    MakeCheck(frame, "Tooltip IDs", "tooltipIDs", nil, "Item, spell and NPC IDs when exposed by this client. Re-hover to update.", false)
    -- Screen & Cursor.
    MakeCheck(frame, "Hide Zone Announcements", "hideZoneText", nil, "Hide large zone announcements; minimap names remain.", false)
    MakeCheck(frame, "Maximum Camera Distance", "maxCameraZoom", nil, "Raise the camera limit to 2.6. Off restores your earlier limit.", false)
end

local function RefreshCursor()
    if EraUI.modules.CursorRing then EraUI.modules.CursorRing:Refresh() end
    if EraUI.modules.CursorEffects then EraUI.modules.CursorEffects:Refresh() end
end

local function RingSlider(frame, key, label, low, high, default, format)
    local row = Rows.Slider(frame, key, label, {low = low, high = high, step = 1, format = format,
        read = function() return tonumber(EraUI:GetSavedSetting(key)) or default end,
        save = function(value) EraUI:SetSetting(key, value); RefreshCursor() end})
    row.searchText = string.lower("cursor mouse " .. label)
    return row
end

local function CursorColour(frame, key, classKey, label)
    local function RGB()
        local hex = EraUI:GetSavedSetting(key)
        if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then hex = "FFFFFF" end
        return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
    end
    local row = Rows.Colour(frame, key, label, RGB)
    local function Save(hex, classColour)
        EraUI:SetSetting(key, hex); EraUI:SetSetting(classKey, classColour)
        frame.checks[classKey]:SetChecked(classColour)
        row:SetChecked(); RefreshCursor()
    end
    row:SetScript("OnClick", function()
        local picker = ColorPickerFrame
        if not picker then return end
        local old = EraUI:GetSavedSetting(key) or "FFFFFF"
        local oldClass = EraUI:GetSavedSetting(classKey)
        local r, g, b = RGB()
        local function Changed()
            local red, green, blue = picker:GetColorRGB()
            Save(string.format("%02X%02X%02X", math.floor(red * 255 + .5), math.floor(green * 255 + .5), math.floor(blue * 255 + .5)), false)
        end
        local function Cancel() Save(old, oldClass) end
        if picker.SetupColorPickerAndShow then
            picker:SetupColorPickerAndShow({r = r, g = g, b = b, hasOpacity = false, swatchFunc = Changed, cancelFunc = Cancel})
        else
            picker:Hide(); picker.func = nil; picker.hasOpacity = false; picker:SetColorRGB(r, g, b)
            picker.func = Changed; picker.cancelFunc = Cancel; picker:Show()
        end
    end)
    return row
end

-- Screen & Cursor's cursor effects: each switch with its folded options.
local function BuildCursorRows(frame)
    MakeCheck(frame, "Cursor Ring", "cursorRing", nil, "A ring follows your mouse pointer. Its options show when it's on.", false)
    MakeCheck(frame, "Class-coloured Cursor Ring", "cursorRingClassColour", nil, "Use your class colour for the ring. Off uses white.", false)
    RingSlider(frame, "cursorRingSize", "Ring Diameter", 24, 160, 48)
    RingSlider(frame, "cursorRingThickness", "Ring Thickness", 1, 10, 2)
    MakeCheck(frame, "Cast Progress Ring", "cursorCastRing", nil, "A cursor ring that fills as you cast. Its options show when it's on.", false)
    MakeCheck(frame, "Class-coloured Cast Ring", "cursorCastClassColour", nil, "Use your class colour. Off uses the custom cast ring colour below.", false)
    RingSlider(frame, "cursorCastSize", "Cast Ring Diameter", 24, 200, 60)
    RingSlider(frame, "cursorCastOpacity", "Cast Ring Opacity (%)", 10, 100, 90)
    CursorColour(frame, "cursorCastColour", "cursorCastClassColour", "Custom Cast Ring Colour")
    MakeCheck(frame, "Cursor Trail", "cursorTrail", nil, "A soft trail follows your cursor. Its options show when it's on.", false)
    MakeCheck(frame, "Class-coloured Cursor Trail", "cursorTrailClassColour", nil, "Use your class colour. Off uses the custom trail colour below.", false)
    RingSlider(frame, "cursorTrailSize", "Trail Size", 4, 32, 10)
    RingSlider(frame, "cursorTrailOpacity", "Trail Opacity (%)", 10, 100, 55)
    RingSlider(frame, "cursorTrailLength", "Trail Fade", 10, 60, 25, function(value) return string.format("%.2fs", value / 100) end)
    CursorColour(frame, "cursorTrailColour", "cursorTrailClassColour", "Custom Trail Colour")
end

-- Damage and healing text (the font, which the game reads as you log in, and
-- the size, the game's own world text scale, which applies at once), and the
-- AFK Screen with its options.
local function BuildScreenRows(frame)
    local font = Rows.Font(frame, "damageFont", "Damage Text Font", {fonts = EraUI.CombatFonts or {},
        current = function() return EraUI:CombatFont() end,
        choose = function(choice)
            EraUI:SetSetting("damageFont", choice.key); EraUI:ApplyCombatFont()
            frame.checks.damageFont:SetChecked()
            if frame.checks.damageTextScale then frame.checks.damageTextScale:SetChecked() end
            if frame.RefreshTags then frame:RefreshTags() end
            EraUI:Status("Damage text font: " .. choice.name .. ". Log out and back in to apply.")
        end})
    font.searchText = "damage healing combat text numbers font pepsi"
    font.summary = "The font of the damage numbers."
    local showFont = font.SetChecked
    -- A new font waits for a log out: the row says so.
    font.SetChecked = function()
        showFont()
        font.logoutPending = EraUI.CombatFontWaiting ~= nil and EraUI:CombatFontWaiting() == true
    end
    local limits = EraUI.COMBAT_TEXT_SCALE or {min = 50, max = 250}
    local scale = Rows.Slider(frame, "damageTextScale", "Damage Text Size", {low = limits.min, high = limits.max, step = 5, wide = true,
        read = function() return EraUI.CombatTextScale and EraUI:CombatTextScale() end,
        save = function(value) EraUI:SetCombatTextScale(value) end,
        format = function(value) return string.format("%.2fx", value / 100) end,
        -- A number in your damage font, bigger or smaller with the size.
        after = function(row, value)
            if not row.preview then return end
            row.preview:SetShown(value ~= nil)
            if value then
                Rows.UseFont(row.preview, EraUI:CombatFont(), math.floor(10 + (value / 100 - .5) * 11 + .5))
                row.preview:SetText("1234")
            end
        end})
    local preview = scale:CreateFontString(nil, "OVERLAY")
    preview:SetPoint("LEFT", scale.slider, "RIGHT", 16, 0)
    preview:SetJustifyH("LEFT")
    preview:SetTextColor(1, 1, 1)
    scale.preview = preview
    scale.searchText = "damage healing combat text numbers size scale"
    scale.summary = "The size of the damage numbers."
    -- AFK Screen and its options. Coming soon, it is one "coming soon" row with its
    -- options kept out of the window.
    local afkSoon = ComingSoon("afkScreen")
    MakeCheck(frame, "AFK Screen", "afkScreen", nil, "Fades the interface while you are AFK and shows your character." .. (afkSoon and "" or " Try /era afk."), afkSoon)
    if not afkSoon then
        MakeCheck(frame, "Show Zone", "afkShowZone", nil, "Show your zone and subzone.", false)
        MakeCheck(frame, "Show Guild", "afkShowGuild", nil, "Show your guild name under your level.", false)
        MakeCheck(frame, "Show Date", "afkShowDate", nil, "Show today's date.", false)
        MakeCheck(frame, "Class Quote", "afkShowQuote", nil, "A famous Classic line for your class.", false)
        MakeCheck(frame, "24-Hour Clock", "afk24Hour", nil, "Show local time as 15:07. Off shows 3:07 PM.", false)
        MakeCheck(frame, "Zoom In", "afkZoom", nil, "Gently zoom in on your character. Your zoom returns afterwards.", false)
        MakeCheck(frame, "Faster Camera", "afkCameraNormal", nil, "Circle once a minute. Off circles every two minutes.", false)
        MakeCheck(frame, "Circle Right", "afkTurnRight", nil, "Circle the camera to the right. Off circles to the left.", false)
    end
end

-- More from Squirt: the author's other addons, whether you have them, and
-- a way to open each one or copy its link (an addon can't open a web page).
local MORE = {
    {key = "moreFECM", name = "Forever Enhanced Cooldown Manager", addon = "ForeverEnhancedCooldownManager",
        slash = "FECM", command = "/ccm", icon = "Interface\\AddOns\\EraUI\\Media\\FECMIcon.tga",
        search = "fecm ccm cooldown manager bars cast bar layout",
        about = "Cooldown, buff and cast bars round your Personal Resource Display, and a fresh look for Blizzard's Cooldown Manager.",
        curseforge = "https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-manager",
        github = "https://github.com/squirtwow/ForeverEnhancedCooldownManager"},
    {key = "moreFEC", name = "Forever Enhanced Cursor", addon = "ForeverEnhancedCursor",
        slash = "FECURSOR", command = "/fec", icon = "Interface\\AddOns\\EraUI\\Media\\FECIcon.tga",
        search = "fec cursor trail rings ring marker mouse pointer",
        about = "Trail, rings and a marker for your cursor.",
        curseforge = "https://www.curseforge.com/wow/addons/forever-enhanced-cursor",
        github = "https://github.com/squirtwow/ForeverEnhancedCursor"},
    {key = "moreFECP", name = "Forever Enhanced Cooldown Pulse", addon = "ForeverEnhancedCooldownPulse",
        slash = "FECP", command = "/fecp", icon = "Interface\\AddOns\\EraUI\\Media\\FECPIcon.tga",
        search = "fecp cooldown pulse ready flash",
        about = "The cooldown pulse on its own.",
        curseforge = "https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-pulse",
        github = "https://github.com/squirtwow/ForeverEnhancedCooldownPulse"},
}
local function MoreRow(frame, info)
    local row = Rows.More(frame, info.key, info)
    row.searchText = string.lower("more addons squirt " .. info.name .. " " .. info.search)
    row.summary = info.about
    local function Copy(url)
        if EraUI.Classic and EraUI.Classic.CopyLink then
            EraUI.Classic.CopyLink(info.name .. "\n\nPaste it into your browser. On CurseForge, Install opens the CurseForge app.", url)
        end
    end
    row.open:SetScript("OnClick", function()
        local run = SlashCmdList and SlashCmdList[info.slash]
        if run then frame:Hide(); run("") end
    end)
    row.getIt:SetScript("OnClick", function() Copy(info.curseforge) end)
    row.github:SetScript("OnClick", function() Copy(info.github) end)
    row.SetChecked = function()
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(info.addon)
        local links = info.curseforge ~= nil and not loaded
        row.open:SetShown(loaded and true or false)
        row.getIt:SetShown(links)
        row.github:SetShown(links)
        -- The name and state line stop 12 short of the leftmost button
        -- (or of the row's end, with none).
        local edge = loaded and row.open or links and row.getIt
        if edge then
            row.text:SetPoint("RIGHT", edge, "LEFT", -12, 0)
            row.state:SetPoint("RIGHT", edge, "LEFT", -12, 0)
        else
            row.text:SetPoint("RIGHT", row, "RIGHT", -12, 0)
            row.state:SetPoint("RIGHT", row, "RIGHT", -12, 0)
        end
        row.state:SetText(loaded and ("Installed. Type " .. info.command .. ", or click Open.")
            or links and "Get it on CurseForge or GitHub: click one for its link."
            or "Coming soon to CurseForge and GitHub.")
    end
    row:SetChecked()
end

-- The reward profile's description: how to switch, then the three stats its
-- weights count most ("Arms weighs damage per second, strength and hit
-- rating most."). QuestTools' whole list would run past the footer.
local function ProfileHelp()
    local how = "Click: next profile. Right-click: previous."
    local quest = EraUI.modules.QuestTools
    local text = quest and quest.ProfileDescription and quest:ProfileDescription()
    if type(text) ~= "string" then return how end
    local name = text:match("^(.-)%s*\226\128\148")
    local stats = {}
    for stat, value in text:gmatch("\n([%a ]+): ([%d%.]+)") do stats[#stats + 1] = {stat, tonumber(value) or 0} end
    if not name or name == "" or #stats == 0 then return how end
    table.sort(stats, function(a, b)
        if a[2] ~= b[2] then return a[2] > b[2] end
        return a[1] < b[1]
    end)
    local top = {}
    for i = 1, math.min(3, #stats) do top[i] = stats[i][1] end
    local list = #top == 1 and top[1] or (table.concat(top, ", ", 1, #top - 1) .. " and " .. top[#top])
    return how .. " " .. name .. " weighs " .. list .. " most."
end

-- Your class's tab: reminders, class tools, resource bars and timers. Each
-- row shows only for the classes it is for (classAllowed).
local function BuildClassRows(frame, className, classToken)
    local melee = {ROGUE=true, DRUID=true, WARRIOR=true, PALADIN=true, SHAMAN=true, HUNTER=true}
    local mana = {HUNTER=true, MAGE=true, PRIEST=true, WARLOCK=true, PALADIN=true, SHAMAN=true}
    local ranged = {HUNTER=true, ROGUE=true, WARRIOR=true, MAGE=true, PRIEST=true, WARLOCK=true}
    local checks = frame.checks
    MakeCheck(frame, "Floating Combo Points", "floatingComboPoints", nil, "Hover orbs for controls. Right-click + to unlock; left-click to lock. Reload to enable.", false)
    MakeCheck(frame, "Red Combo Points", "comboPointRed", nil, "Draw the combo point orbs red instead of gold. Applies immediately.", false)
    MakeCheck(frame, "Energy Bar", "energyBar", nil, "Floating energy and current value. Hover + to move or resize. Applies immediately.", false)
    checks.energyBar.classAllowed = classToken == "ROGUE"
    checks.floatingComboPoints.classAllowed = classToken == "ROGUE" or classToken == "DRUID"
    checks.comboPointRed.classAllowed = classToken == "ROGUE" or classToken == "DRUID"
    MakeCheck(frame, "Swing Timer", "swingTimer", nil, "Main-hand and off-hand swings. Hover + to move or resize. Applies immediately.", false)
    checks.swingTimer.classAllowed = melee[classToken] or false
    MakeCheck(frame, "Rage Bar", "rageBar", nil, "Floating rage and current value. Hover + to move or resize.", false)
    checks.rageBar.classAllowed = classToken == "WARRIOR"
    MakeCheck(frame, "Mana Bar", "manaBar", nil, "Floating mana and current value. Hover + to move or resize.", false)
    checks.manaBar.classAllowed = mana[classToken] or false
    MakeCheck(frame, "Resource Bar", "druidResourceBar", nil, "Mana, cat energy or bear rage. Switches automatically with your form.", false)
    checks.druidResourceBar.classAllowed = classToken == "DRUID"
    MakeCheck(frame, "Ranged Swing Timer", "rangedSwingTimer", nil, "Ranged attacks and wands. Equip a ranged weapon. Hover + to move or resize.", false)
    checks.rangedSwingTimer.classAllowed = ranged[classToken] or false
    for _, entry in ipairs({
        {"hunterFeed", "Pet Feeding", "HUNTER", "A feeding button when your pet is unhappy, and how long Feed Pet lasts."},
        {"mageSupplies", "Conjuring Suggestions", "MAGE", "The food and water to conjure for your target's level."},
        {"mageAutoTrade", "Auto-fill Trade", "MAGE", "Full stacks of conjured food and water put in trade for you."},
        {"roguePoisons", "Poison Supplies", "ROGUE", "Poison vendor quantities, material purchases, crafting and Flash Powder."},
    }) do
        MakeCheck(frame, entry[2], entry[1], nil, entry[4], false)
        checks[entry[1]].classAllowed = classToken == entry[3]
    end
    -- Rogue poisons are one of these alerts (POISON!), so "poison" finds it.
    MakeCheck(frame, "Class Reminders & Buffs", "classReminders", nil, "Big on-screen alerts when a class buff, pet, poison or supply is missing.", false)
    checks.classReminders.classAllowed = true
    local reminders = checks.classReminders
    local module = EraUI.modules.ClassReminders
    if module then
        module.settingsFrame = frame
        module.settingsAnchor = reminders
        -- Its options box opens under it on the class tab (Core/SettingsNav.lua ShowItems).
        reminders.attachPanel = function() module:AttachOptions(frame, reminders) end
        reminders:HookScript("OnShow", function() if not frame.searching then reminders.attachPanel() end end)
        reminders:HookScript("OnHide", function() module:HideOptions() end)
        reminders:HookScript("OnClick", function() module:UpdateOptionsState() end)
    end
    -- Class tools: hunters' and mages' options open under a heading; a
    -- rogue's open in their own window; reminder-only classes have their full
    -- controls under Class Reminders & Buffs already.
    local toolsModule = EraUI.modules.ClassTools and EraUI.modules.ClassTools:ActiveModule()
    local inline = not not (toolsModule and toolsModule.Attach and toolsModule ~= EraUI.modules.ClassReminders)
    local tools
    if inline then
        tools = Rows.Heading(frame, "classTools", classToken == "HUNTER" and "Pet Feeding Options" or "Conjuring & Trade Options")
        tools.summary = classToken == "HUNTER" and "Which foods your pet may eat, and moving its feeding button. They're in the box below."
            or "Conjure food and water, and choose how many stacks to offer in trade. They're in the box below."
        -- A whole line, so its options box spans the page under it in two
        -- columns (Modules/ClassTools.lua) instead of leaving half of it empty.
        tools.wideRow = true
        tools.attachPanel = function()
            local active = EraUI.modules.ClassTools and EraUI.modules.ClassTools:ActiveModule()
            if active and active.Attach and active ~= EraUI.modules.ClassReminders then
                active.settingsFrame = frame
                active.settingsAnchor = tools
                active:Attach(frame, tools)
            end
        end
        tools:HookScript("OnShow", function() if not frame.searching then tools.attachPanel() end end)
    else
        tools = Rows.Link(frame, "classTools", "Configure " .. (className or "Class") .. " Tools", function()
            if EraUI.modules.ClassTools then EraUI.modules.ClassTools:Open() end
        end)
        tools.summary = classToken == "ROGUE" and "Opens the Poison Supplies window: set how many poisons you want, then Buy and Craft at a poison vendor."
            or "Opens your class tools in their own window."
    end
    tools:HookScript("OnHide", function()
        local active = EraUI.modules.ClassTools and EraUI.modules.ClassTools:ActiveModule()
        if active and active.HidePanel then active:HidePanel() end
    end)
    local hasControls = melee[classToken] or mana[classToken]
    tools.classAllowed = not not (hasControls and toolsModule and toolsModule ~= EraUI.modules.ClassReminders)
    -- Each class's own tool words, so a hunter's "poison" finds nothing here.
    tools.searchText = "class tools options " .. (({HUNTER = "pet feeding food",
        MAGE = "conjure conjuring food water trade", ROGUE = "poison supplies flash powder"})[classToken] or "")
    -- The reward profile, right after Highlight Reward Upgrades: click for
    -- the next profile, right-click for the one before.
    local profile
    profile = Rows.Link(frame, "rewardProfile", "Reward Profile", function(_, button)
        local quest = EraUI.modules.QuestTools
        if quest then quest:CycleProfile(button == "RightButton" and -1 or 1); profile:SetChecked() end
    end)
    profile:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    profile.searchText = "reward profile specialization stats upgrades"
    profile.summary = "Click: next profile. Right-click: previous."
    profile.helpText = ProfileHelp
    profile.SetChecked = function()
        local quest = EraUI.modules.QuestTools
        profile.text:SetText("Reward Profile: " .. (quest and quest:Profile()[1] or "Loading"))
    end
    profile:HookScript("OnShow", profile.SetChecked)
end

local function RefreshDependencies(self)
    -- Every option up the chain counts: Aura Shadows is greyed while Dark
    -- Mode is off even with Dark Aura Borders still ticked.
    for key in pairs(DEPENDS) do
        local row = self.checks[key]
        if row then
            local enabled = MissingParent(key) == nil
            row.dependencyDisabled = not enabled
            Rows.SetGreyed(row, not enabled or row.handedOver == true)
        end
    end
    -- Handed over: only a change of state touches the row, so without the
    -- other addon nothing here runs.
    for key, note in pairs(HANDED_OVER) do
        local row = self.checks[key]
        local over = HandedOver(key)
        if row and over ~= (row.handedOver == true) then
            row.handedOver = over
            Rows.SetGreyed(row, over or row.dependencyDisabled == true)
            Rows.SetNote(row, over and note or nil)
        end
    end
end

local function RefreshCastDependencies(self)
    self:RefreshDependencies()
    if EraUI.modules.ClassAccents then EraUI.modules.ClassAccents:Refresh() end
end

local function Pending(frame)
    local labels = {}
    for key in pairs(reloadSettings) do
        if (EraUI:GetSavedSetting(key) and true or false) ~= frame.loadedSettings[key] then
            labels[#labels + 1] = key == "darkMode" and "Appearance" or (frame.checks[key] and frame.checks[key].labelText or key)
        end
    end
    local tracker = EraUI.modules.QuestTrackerChoice
    if tracker and tracker:NeedsReload() then labels[#labels + 1] = "Questie tracker" end
    table.sort(labels)
    return labels
end

-- Setup walkthrough -----------------------------------------------------------

-- The setup uses the same rows and callbacks as the regular window. Only
-- navigation and placement change; there is one settings implementation.
local function SetupButton(frame, label, x, width)
    local button = CreateFrame("Button", nil, frame, "BackdropTemplate")
    button:SetSize(width, 32)
    button:SetPoint("BOTTOMRIGHT", x, 20)
    button:SetBackdrop(Rows.BACKDROP)
    local r, g, b = Rows.ClassColour()
    button:SetBackdropColor(r * .22, g * .22, b * .22, 1)
    button:SetBackdropBorderColor(r, g, b, 1)
    button.label = Rows.Text(button, label, 14)
    button.label:SetPoint("CENTER")
    button:Hide()
    return button
end

-- The big choice boxes of the setup pages (presets and quest tracker).
local function Choice(frame, label, description, column, callback)
    local button = SetupButton(frame, label, -24, 330)
    button:ClearAllPoints()
    button:SetSize(330, 112)
    button.label:ClearAllPoints()
    button.label:SetPoint("TOPLEFT", 18, -18)
    local detail = Rows.Text(button, description, 13, true)
    detail:SetPoint("TOPLEFT", 18, -46); detail:SetWidth(292)
    button.detail = detail
    button:SetScript("OnClick", callback)
    button.column = column
    return button
end
local function PlaceChoice(frame, button)
    button:ClearAllPoints()
    button:SetPoint("TOPLEFT", frame, "TOPLEFT", (frame.setupMode and 30 or Nav.PAGE_LEFT) + button.column * 366, -156)
end
local function PaintChoice(button, selected, name)
    local r, g, b = Rows.ClassColour()
    if selected then
        button:SetBackdropColor(r * .26, g * .26, b * .26, 1)
        button:SetBackdropBorderColor(r, g, b, 1)
        button.label:SetTextColor(r, g, b, 1)
    else
        button:SetBackdropColor(.075, .078, .085, 1)
        button:SetBackdropBorderColor(.25, .27, .3, 1)
        button.label:SetTextColor(.7, .72, .76, 1)
    end
    button.label:SetText((selected and "Selected: " or "") .. name)
end

-- The walkthrough's quality-of-life pages, one per tab. Reload-only looks
-- stay out (Classic Chat Dragging is the exception: its tab handlers need a
-- reload), and the damage text rows have their own page. Options whose tab
-- has no page here join a related one (Show All Spell Ranks joins Action
-- Bars, Tooltip IDs the chat link tooltips); Class-coloured Chat Names is on
-- the style page, so it joins Chat & Names only when that page is skipped.
local WALKTHROUGH = {
    {tab = "actionBars", add = {{after = "hideMacroText", key = "showAllSpellRanks"}}},
    {tab = "map"},
    {tab = "quests"},
    {tab = "bags"},
    {tab = "chat", add = {{after = "hideSecondaryNames", key = "classColors", qolOnly = true}, {after = "linkToggle", key = "tooltipIDs"}}},
    {tab = "group"},
    {tab = "screen"},
}
-- First page: how EraUI is used. The Classic look gets the style page (and,
-- with Questie installed, the tracker page); quality-of-life choices get the
-- walkthrough pages above. A preset only switches the Classic look.
local PRESETS = {
    {id = "classicqol", name = "Classic + Quality of Life", look = "classic", detail = "The 2004 look, plus your choice of Quality of Life options. Recommended."},
    {id = "classic", name = "Classic look only", look = "classic", detail = "The 2004 look. Your Quality of Life options stay as they are."},
    {id = "qol", name = "Quality of Life only", look = "qol", detail = "Keep Blizzard's modern interface and pick Quality of Life options."},
}
-- Left out of the walkthrough's option pages (Update Notice never was on one).
local function LeftOut(key)
    return (reloadSettings[key] and key ~= "classicChatDragging") or key == "damageFont" or key == "damageTextScale"
        or key == "updateCheck"
end
local function WalkthroughItems(frame, walk)
    local extra = {}
    for _, add in ipairs(walk.add or {}) do
        if not add.qolOnly or frame.setupPreset == "qol" then extra[add.after] = add.key end
    end
    -- An option waiting on a look left out here can't be switched on here
    -- either (Show Gryphons with the Action Bars look off), so it waits too.
    return frame:PageItems(TAB[walk.tab], "all", function(key)
        local missing = MissingParent(key)
        return LeftOut(key) or (missing ~= nil and LeftOut(missing))
    end, extra)
end
local function SetupPages(frame)
    local pages = {"preset"}
    if frame.setupPreset ~= "qol" then
        pages[#pages + 1] = "style"
        -- Only the Classic tracker competes with Questie's own.
        if frame.trackerStep then pages[#pages + 1] = "tracker" end
    end
    -- The damage and healing text font, for every preset.
    if frame.checks.damageFont then pages[#pages + 1] = "font" end
    if frame.setupPreset ~= "classic" then
        for index = 1, #WALKTHROUGH do pages[#pages + 1] = index end
    end
    pages[#pages + 1] = "final"
    return pages
end
local function RenderPresets(frame, shown)
    for i, button in ipairs(frame.presetChoices) do
        button:ClearAllPoints(); button:SetPoint("TOPLEFT", frame, "TOPLEFT", 30 + (i - 1) * 250, -156); button:SetShown(shown)
        local selected = frame.setupPreset == PRESETS[i].id
        PaintChoice(button, selected, PRESETS[i].name)
        -- These boxes are too narrow for a "Selected:" prefix; a tag shows it.
        button.label:SetText(PRESETS[i].name)
        button.tag:SetTextColor(Rows.ClassColour()); button.tag:SetShown(selected)
    end
end
local function RenderTracker(frame, shown)
    local tracker = EraUI.modules.QuestTrackerChoice
    local current = tracker and tracker:CurrentChoice() or ""
    for i, button in ipairs(frame.trackerChoices) do
        PlaceChoice(frame, button); button:SetShown(shown)
        PaintChoice(button, current == (i == 1 and "classic" or "questie"), i == 1 and "Classic Tracker" or "Questie Tracker")
    end
end
-- A preset changes many saved settings at once; the reused rows must show
-- the saved state again before any page displays them.
local function SyncChecks(frame)
    for key, check in pairs(frame.checks) do check:SetChecked(not check.unavailable and Saved(key)) end
end
local function Summary(frame, text, y)
    frame.setupSummary:SetText(text)
    frame.setupSummary:ClearAllPoints()
    frame.setupSummary:SetPoint("TOPLEFT", frame, "TOPLEFT", 30, y)
    frame.setupSummary:Show()
end

local function RenderSetup(self)
    local pages = SetupPages(self)
    self.setupPage = math.max(1, math.min(self.setupPage or 1, #pages))
    local page = pages[self.setupPage]
    local final = page == "final"
    self.walkEntries = nil
    RenderPresets(self, false); RenderTracker(self, false); self.setupSummary:Hide(); self.fontQuestion:Hide()
    self.sectionAbout:SetText("")
    self:SetNavShown(false)
    if page == "preset" then
        self:ShowItems({}, true)
        self.sectionTitle:SetText("How do you want EraUI?")
        Summary(self, "Choose a starting point. You can change any option later, or switch preset from /era.", -128)
        RenderPresets(self, true)
    elseif page == "style" then
        -- All of Appearance: the style, Dark Mode and class colours.
        self.sectionTitle:SetText("Choose your style"); self.sectionAbout:SetText(self.categories[TAB.appearance].about)
        self.walkEntries = function() return self:PageItems(TAB.appearance, "all", function(key) return key == "presets" end) end
        self:ShowItems(self.walkEntries(), true)
    elseif page == "tracker" then
        self:ShowItems({}, true)
        self.sectionTitle:SetText("Quest tracker")
        Summary(self, "Questie is installed. Only one quest tracker can show at a time. Which would you like?", -128)
        RenderTracker(self, true)
    elseif page == "font" then
        self.sectionTitle:SetText("Damage & healing text")
        Summary(self, "Pick the font and size of the damage and healing numbers over your targets.", -128)
        local font, scale = self.checks.damageFont, self.checks.damageTextScale
        font:SetChecked(); scale:SetChecked()
        self:ShowItems({{rows = {font}, depth = {}, wide = true}, {rows = {scale}, depth = {}, wide = true}}, true)
    elseif not final then
        local walk = WALKTHROUGH[page]
        local cat = self.categories[TAB[walk.tab]]
        self.sectionTitle:SetText(cat.name); self.sectionAbout:SetText(cat.about)
        self.walkEntries = function() return WalkthroughItems(self, walk) end
        self:ShowItems(self.walkEntries(), true)
    else
        self:ShowItems({}, true)
        self.sectionTitle:SetText("You're ready")
        local pending = Pending(self)
        self.setupNeedsReload = #pending > 0
        local message = "All saved. The rest of the settings are here when you want them.\n\nCasting: the advanced cast bar, its ticks and latency.\n"
            .. (self.className or "Your class") .. ": resource bars and class tools.\nEvery other option has its own tab, and Search finds any of them.\n\n/era opens this window any time."
        if #pending > 0 then
            message = message .. "\n\nReload to apply these changes, then settings will open:\n\n" .. table.concat(pending, ", ")
        else message = message .. "\n\nNo reload needed. Continue to explore the settings." end
        -- A new damage font only shows after logging out and back in: asked
        -- about below, or noted once put off.
        local waiting = EraUI.CombatFontWaiting and EraUI:CombatFontWaiting()
        if waiting and self.fontLater then
            message = message .. "\n\nYour new damage font shows next time you log in."
        end
        Summary(self, message, -156)
        if waiting and not self.fontLater then self.fontQuestion:Show(); self.PlaceLogout(true) end
    end
    self.setupNext.label:SetText(final and (self.setupNeedsReload and "Reload & explore" or "Explore settings") or "Next >")
    self.setupNext:Show()
    self.setupBack:Show()
    self.setupProgress:SetText(final and "FINISH" or page == "preset" and "START" or page == "style" and "APPEARANCE"
        or page == "tracker" and "QUEST TRACKER" or page == "font" and "DAMAGE TEXT" or ("OPTIONS  " .. page .. " / " .. #WALKTHROUGH))
    self.setupProgress:Show(); UpdateReloadHint(self)
end

local function SetSetupMode(self, enabled)
    self:ResetSearch()
    Tour.End(self)
    if enabled then Tour.HideWelcome(self) end
    self:ClearRowFocus()
    self.setupMode = enabled
    self:SetNavShown(not enabled)
    self:SetWidth(enabled and 800 or Nav.WINDOW_WIDTH)
    self:SetScale(math.min(1, math.max(.1, (UIParent:GetWidth() - 32) / self:GetWidth()), math.max(.1, (UIParent:GetHeight() - 32) / 650)))
    self.sectionTitle:ClearAllPoints()
    self.sectionTitle:SetPoint("TOPLEFT", self, "TOPLEFT", enabled and 30 or Nav.PAGE_LEFT, enabled and -84 or -26)
    self.sectionAbout:ClearAllPoints()
    self.sectionAbout:SetPoint("TOPLEFT", self, "TOPLEFT", enabled and 30 or Nav.PAGE_LEFT, enabled and -114 or -58)
    if enabled then
        self.settingsScroll:ClearAllPoints()
        self.settingsScroll:SetPoint("TOPLEFT", self, "TOPLEFT", 30, -148)
        self.settingsScroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -40, Nav.VIEW_BOTTOM)
    end
    self:ShowRowHelp(nil)
    self:RefreshTags()
    if enabled then
        local tracker = EraUI.modules.QuestTrackerChoice
        self.trackerStep = tracker and tracker:QuestieInstalled() or false
        -- Start on the preset that matches the current look. A Custom look
        -- selects nothing: only a click applies a preset.
        local current = EraUI.Presets and EraUI.Presets:Current()
        self.setupPreset = current == "qol" and "qol" or current == "classic" and "classicqol" or nil
        self.setupPage = 1; self.fontLater = nil
        self:RenderSetup()
    else
        self.walkEntries = nil
        RenderPresets(self, false); RenderTracker(self, false)
        -- The log out question belongs to setup; its OnHide takes the button too.
        self.setupSummary:Hide(); self.setupProgress:Hide(); self.setupNext:Hide(); self.setupBack:Hide(); self.fontQuestion:Hide()
        self:SelectCategory(self.selectedCategory or 1)
        UpdateReloadHint(self)
    end
end

-- Marks setup done, with settings to open once the UI next loads.
local function SaveSetupDone()
    if EraUI.Classic and EraUI.Classic.db then
        if EraUI.Classic.CompleteCharacterSetup then EraUI.Classic.CompleteCharacterSetup() end
        EraUI.Classic.db.erauiSetupComplete = true
        EraUI.Classic.MirrorSave()
    end
    EraUIClassicCharDB = EraUIClassicCharDB or {}
    EraUIClassicCharDB.onboarding = EraUIClassicCharDB.onboarding or {}
    EraUIClassicCharDB.onboarding.exploreSettings = true
    EraUIClassicCharDB.onboarding.discoverTabs = {[TAB.class] = true, [TAB.casting] = true}
    EraUIClassicCharDB.onboarding.discoveryHintsVersion = HINTS_VERSION
    if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
end
local function FinishSetup(frame, reloadNow)
    if reloadNow and InCombatLockdown() then frame.reloadHint:SetText("Finish combat before reloading."); return end
    SaveSetupDone()
    -- Keep the click path direct: do not rebuild/hide the settings window
    -- before the client receives the reload request.
    if reloadNow then ReloadUI(); return end
    frame:SetSetupMode(false)
    frame.selectedCategory = 1
    frame:SelectCategory(1)
    frame:Show()
    EraUIClassicCharDB.onboarding.exploreSettings = nil
    if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
    EraUI:Print("Casting and your class tab have more. /era opens settings any time.")
end

-- The finish page asks whether to log out now when a new damage font is
-- waiting, since only a new login shows it. Logging out is for the game's
-- own secure code, so "Yes, log out" is a secure macro button of its own,
-- laid over its spot on the screen rather than joined to this window, which
-- stays free to move and close in combat. It's hidden as combat starts and
-- while the window moves.
local function BuildFontQuestion(frame)
    local fontQuestion = CreateFrame("Frame", nil, frame)
    -- Above the footer's line (FOOTER_H up), so neither button sits on it.
    fontQuestion:SetSize(560, 70); fontQuestion:SetPoint("BOTTOMLEFT", 30, Nav.FOOTER_H + 12); fontQuestion:Hide()
    frame.fontQuestion = fontQuestion
    local fontAsk = Rows.Text(fontQuestion, "Apply your new damage font now? It needs a log out.", 15)
    fontAsk:SetPoint("TOPLEFT", 0, 0)
    local logoutSpot = CreateFrame("Frame", nil, fontQuestion)
    logoutSpot:SetSize(150, 32); logoutSpot:SetPoint("TOPLEFT", 0, -30)
    frame.fontLogoutSpot = logoutSpot
    local later = CreateFrame("Button", nil, fontQuestion, "BackdropTemplate")
    later:SetSize(110, 32); later:SetPoint("TOPLEFT", logoutSpot, "TOPRIGHT", 10, 0)
    later:SetBackdrop(Rows.BACKDROP)
    later:SetBackdropColor(.045, .05, .065, 1); later:SetBackdropBorderColor(.22, .23, .27, 1)
    later.label = Rows.Text(later, "No, later", 14); later.label:SetPoint("CENTER")
    later:SetScript("OnClick", function() if not frame.setupMode then return end; frame.fontLater = true; frame:RenderSetup() end)
    frame.fontLaterButton = later
    local logout
    -- IsShown is the question's own flag, still set after the window closes;
    -- the button only goes where the question can be seen.
    local function PlaceLogout(show)
        if InCombatLockdown() then return end
        if not (show and fontQuestion:IsVisible()) then if logout then logout:Hide() end; return end
        if not logout then
            logout = CreateFrame("Button", "EraUISetupLogout", UIParent, "SecureActionButtonTemplate,BackdropTemplate")
            logout:SetSize(150, 32); logout:SetFrameStrata("DIALOG"); logout:Hide()
            logout:RegisterForClicks("LeftButtonUp", "LeftButtonDown")
            logout:SetAttribute("type1", "macro"); logout:SetAttribute("macrotext1", "/logout")
            logout:SetBackdrop(Rows.BACKDROP)
            local r, g, b = Rows.ClassColour()
            logout:SetBackdropColor(r * .22, g * .22, b * .22, 1); logout:SetBackdropBorderColor(r, g, b, 1)
            logout.label = Rows.Text(logout, "Yes, log out", 14); logout.label:SetPoint("CENTER")
            -- Setup is done either way; settings open after the next login.
            logout:SetScript("PreClick", function() SaveSetupDone() end)
        end
        local left, right, top, bottom = logoutSpot:GetLeft(), logoutSpot:GetRight(), logoutSpot:GetTop(), logoutSpot:GetBottom()
        if not (left and right and top and bottom) then logout:Hide(); return end
        logout:SetScale(logoutSpot:GetEffectiveScale() / UIParent:GetEffectiveScale())
        logout:ClearAllPoints(); logout:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (left + right) / 2, (top + bottom) / 2)
        logout:SetFrameLevel(frame:GetFrameLevel() + 50); logout:Show()
    end
    frame.PlaceLogout = PlaceLogout
    fontQuestion:SetScript("OnShow", function()
        PlaceLogout(true)
        C_Timer.After(0, function() if fontQuestion:IsVisible() then PlaceLogout(true) end end)
    end)
    fontQuestion:SetScript("OnHide", function() PlaceLogout(false) end)
    frame:HookScript("OnDragStart", function() PlaceLogout(false) end)
    frame:HookScript("OnDragStop", function() if fontQuestion:IsVisible() then PlaceLogout(true) end end)
    local logoutWatch = CreateFrame("Frame", nil, frame)
    logoutWatch:RegisterEvent("PLAYER_REGEN_DISABLED"); logoutWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
    logoutWatch:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_DISABLED" then
            if logout then logout:Hide() end -- still allowed as combat begins
        elseif fontQuestion:IsVisible() then PlaceLogout(true) end
    end)
    frame.logoutWatch = logoutWatch
end

local function BuildSetup(frame)
    local setupSummary = Rows.Text(frame, "", 15, true)
    setupSummary:SetPoint("TOPLEFT", 30, -156)
    setupSummary:SetWidth(730)
    setupSummary:SetJustifyV("TOP")
    setupSummary:Hide()
    frame.setupSummary = setupSummary
    local setupProgress = Rows.Text(frame, "", 12, true)
    setupProgress:SetPoint("TOPRIGHT", -64, -30)
    setupProgress:Hide()
    frame.setupProgress = setupProgress
    local nextPage = SetupButton(frame, "Next >", -24, 160)
    local previousPage = SetupButton(frame, "< Back", -196, 92)
    frame.setupNext, frame.setupBack = nextPage, previousPage
    BuildFontQuestion(frame)
    -- Quest tracker step, shown only when Questie is installed: only one
    -- tracker can show, so the walkthrough asks rather than the login prompt.
    -- Questie's own tracker does not list quests on WoW Forever yet.
    local function ChooseTracker(choice)
        local tracker = EraUI.modules.QuestTrackerChoice
        if tracker then tracker:SetChoice(choice) end
        RenderTracker(frame, true); UpdateReloadHint(frame)
    end
    frame.trackerChoices = {
        Choice(frame, "Classic Tracker", "|cff66dd66Recommended.|r Blizzard's tracker in EraUI's Classic look. Turns Questie's tracker off; applies with the reload at the end.", 0, function() ChooseTracker("classic") end),
        Choice(frame, "Questie Tracker", "Questie's own tracker, unfolded. |cffffd24aDoes not list quests on WoW Forever yet.|r", 1, function() ChooseTracker("questie") end),
    }
    frame.presetChoices = {}
    for i, preset in ipairs(PRESETS) do
        local button = Choice(frame, preset.name, preset.detail, 0, function()
            frame.setupPreset = preset.id
            if EraUI.Presets then EraUI.Presets:Apply(preset.look) end
            SyncChecks(frame)
            frame:RenderSetup()
        end)
        button:SetSize(236, 112); button.detail:SetWidth(200)
        button.label:SetWidth(200); button.label:SetWordWrap(false)
        button.tag = Rows.Text(button, "SELECTED", 11)
        button.tag:SetPoint("BOTTOMLEFT", 18, 12); button.tag:Hide()
        frame.presetChoices[i] = button
    end
    frame.walkthrough = WALKTHROUGH
    frame.RenderSetup, frame.SetSetupMode = RenderSetup, SetSetupMode
    nextPage:SetScript("OnClick", function()
        if SetupPages(frame)[frame.setupPage] == "final" then FinishSetup(frame, #Pending(frame) > 0)
        else frame.setupPage = frame.setupPage + 1; frame:RenderSetup() end
    end)
    previousPage:SetScript("OnClick", function()
        if frame.setupPage == 1 then
            frame:Hide(); frame:SetSetupMode(false)
            EraUI.Classic.setupRequested = true; EraUI.Classic.ShowWelcome(); return
        end
        frame.setupPage = frame.setupPage - 1
        frame:RenderSetup()
    end)
end

-- The window -------------------------------------------------------------------

local function Refresh(frame)
    frame:RefreshCastDependencies()
    for key, check in pairs(frame.checks) do check:SetChecked(not check.unavailable and Saved(key)) end
    frame:RefreshTags()
    if frame.setupMode then
        frame:RenderSetup()
    elseif (frame.searchBox:GetText() or ""):match("%S") then
        frame:ApplySearch()
    else
        local index = frame.selectedCategory or 1
        frame:SelectCategory(index, frame.selectedSub[index], true)
    end
    UpdateReloadHint(frame)
    frame:ShowRowHelp(frame.focusedRow)
end

-- Inherit the chosen UI scale; shrink only if the window would exceed the screen.
local function FitToScreen(frame)
    frame:SetScale(math.min(1, math.max(.1, (UIParent:GetWidth() - 32) / frame:GetWidth()),
        math.max(.1, (UIParent:GetHeight() - 32) / 650)))
    frame:RefreshInlineActions()
end

local function OnShow(frame)
    FitToScreen(frame)
    Refresh(frame)
    Tour.MaybeWelcome(frame)
end

local function OnHide(frame)
    frame:StopMovingOrSizing(); frame.settingsMoving = false
    frame:RefreshInlineActions()
    -- The welcome card shows once: closing /era while it shows uses it up.
    if frame.welcoming then Tour.UseWelcome(frame) end
    Tour.End(frame)
    -- A Presets window opened from here goes with it.
    if EraUI.Presets and EraUI.Presets.Hide then EraUI.Presets:Hide() end
    frame.footerMessage = nil
    frame:ClearRowFocus()
    frame.keys:ClearFocus()
    frame:ShowRowHelp(nil)
end

local function CreateWindow()
    local frame = CreateFrame("Frame", "EraUISettingsFrame", UIParent, "BackdropTemplate")
    frame.checks = {}
    frame.loadedSettings = {}
    for key in pairs(reloadSettings) do
        frame.loadedSettings[key] = EraUI:GetSetting(key) and true or false
    end
    frame:SetSize(Nav.WINDOW_WIDTH, 650)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self.settingsMoving = true; self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing(); self.settingsMoving = false
        if self.RefreshInlineActions then self:RefreshInlineActions() end
    end)
    frame:SetScript("OnUpdate", function(self)
        if self.settingsMoving and self.RefreshInlineActions then self:RefreshInlineActions() end
    end)
    frame:Hide()
    if UISpecialFrames then table.insert(UISpecialFrames, "EraUISettingsFrame") end
    frame:SetBackdrop(Rows.BACKDROP)
    frame:SetBackdropColor(.026, .029, .037, 1)
    frame:SetBackdropBorderColor(.19, .20, .24, 1)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(36, 36)
    close:SetPoint("TOPRIGHT", -12, -12)
    local closeLabel = Rows.Text(close, "X", 20, true)
    closeLabel:SetPoint("CENTER")
    close:SetScript("OnClick", function() frame:Hide() end)
    close:SetScript("OnEnter", function() closeLabel:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() closeLabel:SetTextColor(.58, .62, .68) end)
    frame.closeButton = close
    frame.viewLeft, frame.viewTop, frame.viewBottom = Nav.VIEW_LEFT, Nav.VIEW_TOP, Nav.VIEW_BOTTOM
    return frame
end

-- The game's Options window flips the same portrait switches; their rows
-- follow at once, even with /era open beside it. Only EraUI's own rows
-- change here.
local function WatchPortraitSwitches(frame)
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
            EraUI:SetSetting(key, now); check:SetChecked(now)
        end
    end)
    frame.cvarWatch = cvarWatch
end

-- The class and Casting tab hints, saved by tab number. Runs after both the
-- onboarding CVar and the recovery backup have loaded. Setup finished before
-- the hints existed gets them (the onboarding CVar stores no version as 0);
-- an older order (version 1 or 2) moves to the tabs' places now, once.
local function MigrateHints()
    local onboarding = EraUIClassicCharDB and EraUIClassicCharDB.onboarding
    if not onboarding then return end
    local version = onboarding.discoveryHintsVersion
    local migrated = false
    if onboarding.setupComplete and (version or 0) == 0 then
        onboarding.discoverTabs = {[TAB.class] = true, [TAB.casting] = true}
        migrated = true
    elseif OLD_HINT_TABS[version] then
        local was = OLD_HINT_TABS[version]
        local old = type(onboarding.discoverTabs) == "table" and onboarding.discoverTabs or {}
        local tabs = {}
        if old[was.class] then tabs[TAB.class] = true end
        if old[was.casting] then tabs[TAB.casting] = true end
        onboarding.discoverTabs = tabs
        migrated = true
    end
    if migrated then
        onboarding.discoveryHintsVersion = HINTS_VERSION
        if EraUI.SaveCharOnboarding then EraUI.SaveCharOnboarding() end
    end
end

function SettingsModule:Initialize()
    MigrateHints()
    if self.frame then return end
    local frame = CreateWindow()
    local className, classToken = UnitClass("player")
    frame.className, frame.classToken = className, classToken
    -- The rows scroll inside the viewport (Core/SettingsLayout.lua).
    EraUI:CreateSettingsViewport(frame)
    Nav.Build(frame, className, classToken, classIconCoords)
    Tour.Attach(frame)
    BuildLookRows(frame)
    BuildToggleRows(frame)
    BuildCursorRows(frame)
    BuildScreenRows(frame)
    for _, info in ipairs(MORE) do MoreRow(frame, info) end
    BuildClassRows(frame, className, classToken)
    Nav.Index(frame)
    frame.RefreshDependencies, frame.RefreshCastDependencies = RefreshDependencies, RefreshCastDependencies
    frame.UpdatePresetLabel, frame.RefreshHintText, frame.RefreshHint = UpdatePresetLabel, HintText, UpdateReloadHint
    BuildSetup(frame)
    frame:SetScript("OnShow", OnShow)
    frame:SetScript("OnHide", OnHide)
    frame:RegisterEvent("UI_SCALE_CHANGED")
    frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
    frame:SetScript("OnEvent", function() if frame:IsShown() then FitToScreen(frame) end end)
    WatchPortraitSwitches(frame)
    Refresh(frame)
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
    local wasSetup = self.frame.setupMode
    self.frame:SetSetupMode(false)
    if wasSetup then self.frame:Show()
    else self.frame:SetShown(not self.frame:IsShown()) end
end

-- Explicit show avoids the normal /era toggle closing an already open window.
function SettingsModule:ShowSettings()
    if not self.frame then self:Initialize() end
    self.frame.selectedCategory = 1
    self.frame:SetSetupMode(false)
    self.frame:Show()
end

-- Tool navigation is an explicit show/focus action, never the /era toggle.
-- Clear search/setup first so the requested class controls have visible
-- anchors. The welcome card waits for the next plain /era.
function SettingsModule:ShowClassControls(key)
    if InCombatLockdown() then return end
    if not self.frame then self:Initialize() end
    local frame = self.frame
    frame.selectedCategory = TAB.class
    frame.navigatingToClass = true
    frame:SetSetupMode(false)
    frame:Show()
    frame.navigatingToClass = false
    local anchor = frame.checks[key]
    if not anchor or not anchor:IsShown() then return end
    local module
    if key == "classReminders" then
        module = EraUI.modules.ClassReminders
    else
        local tools = EraUI.modules.ClassTools
        module = tools and tools:ActiveModule()
    end
    if module then
        module.settingsFrame, module.settingsAnchor = frame, anchor
        if key == "classReminders" and module.AttachOptions then
            module:AttachOptions(frame, anchor)
        elseif module.Attach then
            module:Attach(frame, anchor)
        end
    end
    frame:LayoutSettings()
    local top, contentTop = anchor:GetTop(), frame.settingsContent:GetTop()
    if top and contentTop then frame:SetSettingsScroll(contentTop - top) end
end
