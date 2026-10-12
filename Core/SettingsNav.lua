local _, E = ...

-- Where every /era option lives, and how the window gets you there: the
-- grouped tab list (Look, Gameplay, Social, Extras), each tab's title and
-- one-line description, the sub-tabs on busy tabs, the sections and rows of
-- each page, the footer that describes the row under the mouse (or the
-- keyboard), search and its jump to an option. Core/Settings.lua keeps what
-- each option does; it builds the rows and calls Nav.Build and Nav.Index.
-- Setting keys never change with a row's place, so no saved choice moves.
-- Functions here take the window as their first argument and keep their
-- state on it, so none of them holds more than a few values from outside
-- (the game refuses a function with more than 60).
local Nav = {}
E.SettingsNav = Nav

local NAV_WIDTH = 212                       -- the tab list's dark backing
local TAB_WIDTH = NAV_WIDTH - 24            -- 12 in from the window edge, 13 short of the divider
local PAGE_LEFT = NAV_WIDTH + 20            -- page titles and descriptions
local VIEW_LEFT = NAV_WIDTH + 14            -- the rows' viewport and the sub-tabs
local WINDOW_WIDTH = 772 + NAV_WIDTH        -- 984
local FOOTER_H = 92                         -- room for three lines of description and two of extras
local VIEW_TOP, VIEW_TOP_SUBS = -88, -122   -- under the description, or under the sub-tabs
Nav.NAV_WIDTH, Nav.TAB_WIDTH, Nav.PAGE_LEFT, Nav.VIEW_LEFT = NAV_WIDTH, TAB_WIDTH, PAGE_LEFT, VIEW_LEFT
Nav.WINDOW_WIDTH, Nav.FOOTER_H, Nav.VIEW_TOP, Nav.VIEW_TOP_SUBS = WINDOW_WIDTH, FOOTER_H, VIEW_TOP, VIEW_TOP_SUBS
Nav.VIEW_BOTTOM = FOOTER_H + 22             -- the scroll hint sits between the rows and the footer
Nav.TAB_HEIGHT, Nav.TAB_TOP = 28, -96

-- The tab list, in four groups. Each tab has a fixed word id; its number is
-- only its place in the list (the new-player hints are saved by number, so
-- a new order is a new hint version in Core/Settings.lua).
local GROUPS = {
    {title = "Look", tabs = {"appearance", "actionBars", "frames", "map", "windows"}},
    {title = "Gameplay", tabs = {"class", "casting", "quests", "character", "bags"}},
    {title = "Social", tabs = {"chat", "group"}},
    {title = "Extras", tabs = {"screen", "more"}},
}
Nav.GROUPS = GROUPS
local TAB_IDS, TAB, TAB_GROUP = {}, {}, {}
for g, group in ipairs(GROUPS) do
    for _, id in ipairs(group.tabs) do
        TAB_IDS[#TAB_IDS + 1] = id
        TAB[id] = #TAB_IDS
        TAB_GROUP[id] = g
    end
end
Nav.TAB_IDS, Nav.TAB = TAB_IDS, TAB

local function S(title, rows) return {title = title, rows = rows} end
-- Every option's page and section, in reading order. A sub-option comes
-- right after the option it sits under. Section titles are drawn in small
-- capitals. The class tab's resource section is named per class.
local TABS = {
    appearance = {name = "Appearance", icon = "Interface\\Icons\\INV_Misc_Desecrated_ClothShoulder",
        about = "How EraUI looks: the style, Dark Mode and class colours.", subs = {
            {id = "style", name = "Style", sections = {S("Style", {"appearanceChoice", "presets"}),
                S("Frame style", {"flatBars", "thickAuraBorders", "roundedCastBars"})}},
            {id = "dark", name = "Dark Mode", sections = {
                S("Darkness", {"darkModeDarkness", "darkenClassColours"}),
                S("Borders", {"darkAuraBorders", "darkAuraShadows", "darkDebuffLines"}),
                S("Bars and windows", {"darkMenuBar", "darkWindows", "blackPages"})}},
            {id = "classcol", name = "Class Colours", sections = {
                S("Class colours", {"classColors", "tooltipClassColours", "classColourBorders", "castBarClassBorder"})}},
        }},
    actionBars = {name = "Action Bars", icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
        about = "The stone dock and the Classic action buttons.", sections = {
            S("Action bars", {"actionBars", "gryphons", "hideEmptyActionSlots", "hideKeybindText", "hideMacroText"})}},
    frames = {name = "Frames & Nameplates", icon = "Interface\\Icons\\INV_Helmet_03",
        about = "Unit frames, portraits and nameplates.", subs = {
            {id = "unit", name = "Unit Frames", sections = {S("Unit frames", {"unitFrames", "matchFocusSize",
                "disableAggroHighlight", "portraitDebuffs", "classIconPortraitMine", "classIconPortraitOthers"})}},
            {id = "plates", name = "Nameplates", sections = {S("Nameplates", {"friendlyNameplates", "enemyNameplates"})}},
        }},
    map = {name = "Map & Minimap", icon = "Interface\\Icons\\INV_Misc_Map_01",
        about = "The minimap and the world map.", sections = {
            S("Minimap", {"minimap", "cleanMinimap", "cleanMinimapStyle", "minimapDrawerColumns", "coordinates"}),
            S("World map", {"mapQuestObjectives", "movableMap", "revealMap"})}},
    windows = {name = "Windows & Tooltips", icon = "Interface\\Icons\\INV_Misc_Gear_01",
        about = "Classic frames for the game's windows, and tooltips.", sections = {
            S("Windows", {"gameMenu", "popups", "blizzardSettings", "mailSkin", "auctionHouse", "damageMeterSkin",
                "otherWindows", "contextMenus"}),
            S("Tooltips", {"tooltipSkin", "tooltipIDs"})}},
    class = {about = "Tools for your class. Each class sees its own.", sections = {
            S("Reminders", {"classReminders"}),
            S("Class tools", {"hunterFeed", "mageSupplies", "mageAutoTrade", "roguePoisons", "classTools"}),
            S("%RESOURCES%", {"floatingComboPoints", "comboPointRed", "energyBar", "rageBar", "manaBar", "druidResourceBar"}),
            S("Timers", {"swingTimer", "rangedSwingTimer"})}},
    casting = {name = "Casting", icon = "Interface\\Icons\\Spell_Arcane_Blast",
        about = "Cast bars for you and everyone else.", sections = {
            S("Cast bars", {"castBars", "advancedCastBar", "advancedCastClassFill", "advancedCastTicks", "advancedCastLatency"}),
            S("Colour", {"castBarColour", "castBarCustomColour"})}},
    quests = {name = "Quests", icon = "Interface\\GossipFrame\\AvailableQuestIcon",
        about = "The quest log, dialogue and tracker.", sections = {
            S("Quests", {"questLog", "questDialogs", "questTracker", "questLevels"}),
            S("Automation", {"autoQuests", "autoGossip", "rewardUpgradeHighlight", "rewardProfile"})}},
    character = {name = "Character & Spells", icon = "Interface\\Icons\\INV_Chest_Plate04",
        about = "Character, talents, spellbook, trainer and professions.", sections = {
            S("Windows", {"characterPanel", "characterItemLevels", "talentWindow", "trainer", "professions"}),
            S("Spellbook", {"spellbook", "spellbookCombatDrag", "trainingGuide", "showAllSpellRanks"})}},
    bags = {name = "Bags & Vendors", icon = "Interface\\Icons\\INV_Misc_Bag_08",
        about = "Bags, loot and merchants.", subs = {
            {id = "bagsloot", name = "Bags & Loot", sections = {S("Bags", {"bagsBank", "bagSpace", "bagItemLevels",
                "lootWindow", "fastAutoLoot", "discardCheapestJunk"})}},
            {id = "vendors", name = "Vendors", sections = {S("Vendors", {"merchantSkin", "autoSellJunk", "autoRepair",
                "vendorPrice", "junkValueSummary", "durabilityWarning"})}},
        }},
    chat = {name = "Chat & Names", icon = "Interface\\Icons\\INV_Letter_15",
        about = "Chat, names and EraUI's own messages.", sections = {
            S("Chat", {"hideSecondaryNames", "classicChatDragging", "linkToggle", "hideStatusMessages",
                "showWelcomeOnLogin", "updateCheck"})}},
    group = {name = "Group & Invites", icon = "Interface\\Icons\\INV_Misc_GroupLooking",
        about = "Friends, guild, group finder and invites.", sections = {
            S("Windows", {"socialWindows", "groupFinderPvp"}),
            S("Invites and requests", {"blockDuels", "blockPartyInvites", "partyFromFriends", "inviteFromWhispers",
                "autoSummon", "autoResurrect", "releasePvP"})}},
    screen = {name = "Screen & Cursor", icon = "Interface\\Icons\\Spell_Nature_FarSight",
        about = "The screen, your cursor and the AFK screen.", subs = {
            {id = "screenmain", name = "Screen", sections = {S("Screen", {"hideZoneText", "maxCameraZoom", "damageFont", "damageTextScale"})}},
            {id = "cursor", name = "Cursor", sections = {
                S("Cursor ring", {"cursorRing", "cursorRingClassColour", "cursorRingSize", "cursorRingThickness"}),
                S("Cast ring and trail", {"cursorCastRing", "cursorCastClassColour", "cursorCastSize", "cursorCastOpacity",
                    "cursorCastColour", "cursorTrail", "cursorTrailClassColour", "cursorTrailSize", "cursorTrailOpacity",
                    "cursorTrailLength", "cursorTrailColour"})}},
            {id = "afk", name = "AFK Screen", sections = {S("AFK screen", {"afkScreen", "afkShowZone", "afkShowGuild",
                "afkShowDate", "afkShowQuote", "afk24Hour", "afkZoom", "afkCameraNormal", "afkTurnRight"})}},
        }},
    more = {name = "More from Squirt", icon = "Interface\\Icons\\INV_Misc_Gift_02",
        about = "Other addons by the same author.", sections = {S("Addons", {"moreFECM", "moreFEC", "moreFECP"})}},
}
Nav.TABS = TABS
Nav.RESOURCES = {ROGUE = "Combo points and energy", DRUID = "Combo points and resources"}

-- Rows that take the whole width. (A hunter's or mage's class tools heading
-- does too, with its options box under it: Core/Settings.lua sets wideRow.)
-- Cast Bar Colour's five choices don't fit half a line.
Nav.WIDE = {appearanceChoice = true, presets = true, darkModeDarkness = true, classReminders = true,
    damageFont = true, damageTextScale = true, afkScreen = true, moreFECM = true, moreFEC = true, moreFECP = true,
    castBarColour = true}
-- "just added" after the name, for players who had the old layout, while
-- they run the version the new layout came in (EraUIDB.layoutPillsVersion):
-- the options not released before.
Nav.NEW = {darkDebuffLines = true, blackPages = true, darkWindows = true, flatBars = true, thickAuraBorders = true,
    roundedCastBars = true}

local function Rows() return E.SettingsRows end
local function Rules() return E.SettingsRules end

-- Where a row lives, as "Tab > Sub-tab" ("Tab" on a tab without sub-tabs).
function Nav.Crumb(frame, home)
    local cat = home and frame.categories[home.tab]
    if not cat then return "" end
    if not cat.hasSubs then return cat.name end
    for _, sub in ipairs(cat.subs) do
        if sub.id == home.sub then return cat.name .. " > " .. sub.name end
    end
    return cat.name
end

-- Sidebar -----------------------------------------------------------------

local function PaintTabs(frame, index)
    local r, g, b = Rows().ClassColour()
    for i, tab in ipairs(frame.tabs) do
        local active = i == index
        tab.underline:SetColorTexture(r, g, b, 1)
        tab.underline:SetShown(active)
        tab.selected:SetColorTexture(r, g, b, active and .12 or 0)
        tab.text:SetTextColor(active and r or .58, active and g or .62, active and b or .68)
    end
end

local function TabClick(tab)
    local frame = tab.owner
    local state = EraUIClassicCharDB and EraUIClassicCharDB.onboarding
    if state and state.discoverTabs then state.discoverTabs[tab.index] = nil end
    if E.SaveCharOnboarding then E.SaveCharOnboarding() end
    frame:SelectCategory(tab.index)
end

-- New-player hints pulse on the class and Casting tabs, read by tab number.
local function HintPulse(tab, elapsed)
    tab.pulse = (tab.pulse or 0) + elapsed
    local frame = tab.owner
    local state = EraUIClassicCharDB and EraUIClassicCharDB.onboarding
    local pending = state and state.discoverTabs and state.discoverTabs[tab.index]
    tab.hint:SetShown(not frame.setupMode and pending == true and frame.selectedCategory ~= tab.index)
    if pending then tab.hint:SetAlpha(.055 + .03 * (.5 + .5 * math.sin(tab.pulse * 2))) end
end

local function TabButton(frame, index, classToken, classCoords)
    local category = frame.categories[index]
    local Text = Rows().Text
    local tab = CreateFrame("Button", nil, frame)
    tab.owner, tab.index, tab.id = frame, index, category.id
    tab:SetSize(TAB_WIDTH, Nav.TAB_HEIGHT)
    tab.text = Text(tab, category.name, 13)
    tab.text:SetPoint("LEFT", tab, "LEFT", 36, 0)
    tab.text:SetPoint("RIGHT", tab, "RIGHT", -2, 0)
    tab.text:SetWordWrap(false)
    tab.underline = tab:CreateTexture(nil, "ARTWORK")
    tab.underline:SetPoint("TOPLEFT", tab, "TOPLEFT", 0, -5)
    tab.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 5)
    tab.underline:SetWidth(3)
    tab.selected = tab:CreateTexture(nil, "BACKGROUND")
    tab.selected:SetAllPoints()
    local icon = tab:CreateTexture(nil, "ARTWORK")
    icon:SetSize(18, 18)
    icon:SetPoint("LEFT", tab, "LEFT", 10, 0)
    if category.id == "class" then
        icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        icon:SetTexCoord(unpack(classCoords[classToken] or classCoords.ROGUE))
    else
        icon:SetTexture(category.icon)
    end
    tab.icon = icon
    local hover = tab:CreateTexture(nil, "HIGHLIGHT")
    hover:SetAllPoints()
    hover:SetColorTexture(1, 1, 1, .04)
    if category.id == "class" or category.id == "casting" then
        tab.hint = tab:CreateTexture(nil, "BACKGROUND", nil, 1)
        tab.hint:SetAllPoints()
        tab.hint:SetColorTexture(Rows().ClassColour())
        tab.hint:Hide()
        tab:SetScript("OnUpdate", HintPulse)
    end
    tab:SetScript("OnClick", TabClick)
    return tab
end

local function BuildSidebar(frame, classToken, classCoords)
    local R = Rows()
    local navigation = frame:CreateTexture(nil, "BACKGROUND")
    navigation:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    navigation:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    navigation:SetWidth(NAV_WIDTH)
    navigation:SetColorTexture(.014, .016, .022, 1)
    local divider = frame:CreateTexture(nil, "BORDER")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", NAV_WIDTH + 1, -1)
    divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", NAV_WIDTH + 1, 1)
    divider:SetWidth(1)
    divider:SetColorTexture(.14, .15, .18, 1)
    frame.navigation, frame.navDivider = navigation, divider
    local title = R.Text(frame, "EraUI", 26)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", 24, -20)
    title:SetTextColor(R.ClassColour())
    frame.navTitle = title
    frame.tabs, frame.groupHeadings = {}, {}
    local y = Nav.TAB_TOP
    for g, group in ipairs(GROUPS) do
        local heading = R.Text(frame, group.title:upper(), 11)
        heading:SetTextColor(.37, .41, .45)
        heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, y - 5)
        frame.groupHeadings[g] = heading
        y = y - 20
        for _, id in ipairs(group.tabs) do
            local tab = TabButton(frame, TAB[id], classToken, classCoords)
            tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, y)
            frame.tabs[TAB[id]] = tab
            y = y - Nav.TAB_HEIGHT
        end
        y = y - 6
    end
    local tour = R.Button(frame, "Take the tour", TAB_WIDTH, 28, true)
    tour:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 16)
    tour:SetScript("OnClick", function() if frame.StartTour then frame:StartTour() end end)
    frame.tourButton = tour
end

-- Header and sub-tabs -------------------------------------------------------

local function SubClick(button)
    local frame = button.owner
    frame:SelectCategory(frame.selectedCategory, button.subId, true)
end

local function RenderSubTabs(frame, index)
    local cat = frame.categories[index]
    local strip = frame.subTabStrip
    strip:SetShown(cat.hasSubs and not frame.searching and not frame.setupMode)
    local R = Rows()
    local r, g, b = R.ClassColour()
    local x = 0
    for i, sub in ipairs(cat.hasSubs and cat.subs or {}) do
        local button = frame.subTabs[i]
        if not button then
            button = CreateFrame("Button", nil, strip, "BackdropTemplate")
            button:SetBackdrop(R.BACKDROP)
            button.owner = frame
            button.label = R.Text(button, "", 13)
            button.label:SetPoint("CENTER", button, "CENTER", 0, -1)
            button.top = button:CreateTexture(nil, "ARTWORK")
            button.top:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
            button.top:SetPoint("TOPRIGHT", button, "TOPRIGHT", -1, -1)
            button.top:SetHeight(2)
            button:SetScript("OnClick", SubClick)
            frame.subTabs[i] = button
        end
        local on = sub.id == frame.selectedSub[index]
        button.subId, button.selected = sub.id, on
        button.label:SetText(sub.name)
        button:SetSize(math.floor(button.label:GetStringWidth() + 28.5), 28)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", strip, "TOPLEFT", x, 0)
        x = x + button:GetWidth() + 2
        button:SetBackdropColor(.08, .09, .125, on and 1 or 0)
        button:SetBackdropBorderColor(.14, .15, .18, on and 1 or 0)
        button.top:SetColorTexture(r, g, b, 1)
        button.top:SetShown(on)
        button.label:SetTextColor(on and .94 or .58, on and .95 or .62, on and .98 or .68)
        button:Show()
    end
    for i = (cat.hasSubs and #cat.subs or 0) + 1, #frame.subTabs do frame.subTabs[i]:Hide() end
end

local function BuildHeader(frame)
    local R = Rows()
    local title = R.Text(frame, "", 24)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAGE_LEFT, -26)
    local about = R.Text(frame, "", 12, true)
    about:SetPoint("TOPLEFT", frame, "TOPLEFT", PAGE_LEFT, -58)
    about:SetWidth(560)
    about:SetWordWrap(false)
    frame.sectionTitle, frame.sectionAbout = title, about
    local strip = CreateFrame("Frame", nil, frame)
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", VIEW_LEFT, -84)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, -84)
    strip:SetHeight(28)
    local line = strip:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT", strip, "BOTTOMLEFT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(.14, .15, .18, 1)
    strip.line = line
    strip:Hide()
    frame.subTabStrip, frame.subTabs = strip, {}
end

-- Footer ------------------------------------------------------------------

local function PinFooter(frame, setup)
    local footer = frame.footer
    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", setup and 1 or NAV_WIDTH + 1, 1)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    footer:SetHeight(FOOTER_H)
    local width = setup and 466 or 570
    frame.footerHelp:SetWidth(width)
    frame.footerExtras:SetWidth(width)
    frame.reloadHint:SetWidth(setup and 330 or 360)
end
Nav.PinFooter = PinFooter

local function FooterButton(frame, label, width, height)
    local button = Rows().Button(frame.footer, label, width, height, true)
    return button
end

local function BuildFooter(frame)
    local R = Rows()
    local footer = CreateFrame("Frame", nil, frame)
    frame.footer = footer
    local line = footer:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    line:SetHeight(1)
    line:SetColorTexture(.14, .15, .18, 1)
    footer.line = line
    local hint = R.Text(footer, "", 13, true)
    hint:SetPoint("TOPLEFT", footer, "TOPLEFT", 20, -22)
    hint:SetWordWrap(true)
    hint:SetJustifyV("TOP")
    frame.reloadHint = hint
    local signature = R.Text(footer, E.Signature and E:Signature()
        or "Made with |TInterface\\AddOns\\EraUI\\Media\\Heart:10:10:0:0|t by Squirt", 10, true)
    signature:SetPoint("TOPLEFT", footer, "TOPLEFT", 20, -64)
    signature:SetTextColor(.48, .49, .52, 1)
    frame.signature = signature
    local help = R.Text(footer, "", 12)
    help:SetPoint("TOPLEFT", footer, "TOPLEFT", 20, -12)
    help:SetTextColor(.78, .80, .84)
    help:SetWordWrap(true)
    help:SetJustifyV("TOP")
    help:SetMaxLines(3)
    help:Hide()
    local extras = R.Text(footer, "", 12, true)
    extras:SetPoint("TOPLEFT", help, "BOTTOMLEFT", 0, -5)
    extras:SetWordWrap(true)
    extras:SetJustifyV("TOP")
    extras:SetMaxLines(2)
    extras:Hide()
    frame.footerHelp, frame.footerExtras = help, extras
    local reload = FooterButton(frame, "Reload UI", 142, 32)
    reload.label:SetFont(select(1, GameFontHighlight:GetFont()), 15, "")
    reload:SetPoint("RIGHT", footer, "RIGHT", -24, 0)
    reload:SetScript("OnClick", function()
        if InCombatLockdown and InCombatLockdown() then
            frame.reloadHint:SetText("Finish combat before reloading the UI.")
            return
        end
        ReloadUI()
    end)
    frame.reloadButton = reload
    local discord = FooterButton(frame, "Discord", 100, 28)
    discord:SetPoint("RIGHT", footer, "RIGHT", -174, 0)
    discord:SetScript("OnClick", function() if E.ShowDiscord then E.ShowDiscord() end end)
    -- What it's for, in the hint beside it.
    discord:SetScript("OnEnter", function() frame.reloadHint:SetText("Found a bug or have an idea? Join the Discord.") end)
    discord:SetScript("OnLeave", function() if frame.RefreshHintText then frame:RefreshHintText() end end)
    frame.discordButton = discord
    local changelog = FooterButton(frame, "Changelog", 100, 28)
    changelog:SetPoint("RIGHT", discord, "LEFT", -8, 0)
    changelog:SetScript("OnClick", function() if E.ShowUpdateNotes then E.ShowUpdateNotes() end end)
    frame.changelogButton = changelog
    PinFooter(frame, false)
end

-- The footer: by default the reload hint and the signature, with Changelog,
-- Discord and Reload UI. A row under the mouse or the keyboard shows its
-- description instead (up to three lines), then what it needs first, a
-- hand-over note, a reload line and its default (Core/Settings.lua says).
local function ShowRowHelp(frame, row)
    row = row and (row.target or row)
    if row and not frame.touring and not frame.welcoming then
        local help, extras = Rules().Describe(frame, row)
        frame.footerHelp:SetText("|cffffffff" .. (row.labelText or "") .. "|r  " .. (help or ""))
        frame.footerExtras:SetText(extras or "")
        frame.footerHelp:Show()
        frame.footerExtras:SetShown(extras ~= nil and extras ~= "")
        frame.reloadHint:Hide()
        frame.signature:Hide()
        frame.changelogButton:Hide()
        frame.discordButton:Hide()
        frame.footerMessage = nil
        frame.helpRow = row
        return
    end
    frame.helpRow = nil
    frame.footerHelp:Hide()
    frame.footerExtras:Hide()
    frame.reloadHint:Show()
    frame.signature:SetShown(not frame.setupMode)
    frame.changelogButton:SetShown(not frame.setupMode)
    frame.discordButton:SetShown(not frame.setupMode)
    if frame.RefreshHintText then frame:RefreshHintText() end
end

-- Pages ---------------------------------------------------------------------

-- Rows grouped into column blocks: an option and the sub-options under it
-- (its fold, its group or its first DEPENDS option, Core/Settings.lua) stay
-- together in one column, indented 22 a level. A wide row has its own line;
-- its sub-options start the next block in the left column.
local function Blocks(frame, keys, skip, extra, out)
    local list = {}
    local Folded = Rules().Folded
    local function Add(key)
        local row = frame.checks[key]
        if not row or row.classAllowed == false or Folded(key) or (skip and skip(key)) then return end
        list[#list + 1] = row
    end
    for _, key in ipairs(keys) do
        Add(key)
        if extra and extra[key] then Add(extra[key]) end
    end
    local GroupParent = Rules().GroupParent
    local current, before = nil, #out
    for _, row in ipairs(list) do
        local key = row.settingKey
        local parent = GroupParent(key)
        if row.wide then
            out[#out + 1] = {rows = {row}, depth = {[row] = 0}, wide = true}
            -- Its sub-options (if any) follow in the next block, which
            -- starts the next line in the left column.
            current = {rows = {}, depth = {}, has = {[key] = 0}, pending = true}
        elseif parent and current and current.has[parent] ~= nil then
            local depth = math.min(current.has[parent] + 1, 2)
            current.rows[#current.rows + 1] = row
            current.depth[row] = depth
            current.has[key] = depth
            if current.pending then current.pending = nil; out[#out + 1] = current end
        else
            current = {rows = {row}, depth = {[row] = 0}, has = {[key] = 0}}
            out[#out + 1] = current
        end
    end
    return #out > before
end

-- A page's items in order: section headings and row blocks. subId "all"
-- runs every sub-page (the setup walkthrough's pages). skip leaves rows out;
-- extra[key] adds a row after another (both for setup).
local function PageItems(frame, index, subId, skip, extra)
    local items = {}
    local cat = frame.categories[index]
    for _, sub in ipairs(cat and cat.subs or {}) do
        if subId == "all" or sub.id == subId then
            for _, section in ipairs(sub.sections) do
                local heading = {heading = section.title}
                items[#items + 1] = heading
                if not Blocks(frame, section.rows, skip, extra, items) then items[#items] = nil end
            end
        end
    end
    return items
end

local function Heading(frame, index)
    local pool = frame.headingPool
    local fs = pool[index]
    if not fs then
        fs = Rows().Text(frame.settingsContent, "", 11)
        local gold = Rows().GOLD
        fs:SetTextColor(gold[1], gold[2], gold[3])
        pool[index] = fs
    end
    return fs
end

local function ClearRowFocus(frame)
    if frame.focusedRow then Rows().SetFocus(frame.focusedRow, false) end
    frame.focusedRow = nil
end

-- Shows exactly these items (and hides every other row), then lays them out.
local function ShowItems(frame, items, reset)
    local wanted = {}
    local headings = 0
    for _, item in ipairs(items) do
        if item.heading then
            headings = headings + 1
            local fs = Heading(frame, headings)
            fs:SetText(item.heading:upper())
            fs:Show()
            item.fs = fs
        else
            for _, row in ipairs(item.rows) do wanted[row] = true end
        end
    end
    for i = headings + 1, #frame.headingPool do frame.headingPool[i]:Hide() end
    for _, result in ipairs(frame.results) do result:SetShown(wanted[result] == true) end
    if frame.focusedRow and not wanted[frame.focusedRow] then ClearRowFocus(frame) end
    local R = Rows()
    for _, row in pairs(frame.checks) do
        row:SetShown(wanted[row] == true)
    end
    for _, item in ipairs(items) do
        for _, row in ipairs(item.rows or {}) do
            R.SetIndent(row, item.depth and item.depth[row] or 0)
            -- A class option's box opens under it on its tab only (never in
            -- search, which lists results instead of the rows).
            local box = row.inlinePanel
            if row.attachPanel and not frame.searching and not (box and box:IsShown()) and row:IsVisible() then
                row.attachPanel()
            end
        end
    end
    frame.settingsItems = items
    if frame.LayoutSettings then frame:LayoutSettings(reset) end
end

local function SetViewportTop(frame, y)
    frame.viewTop = y
    local scroll = frame.settingsScroll
    if not scroll then return end
    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", VIEW_LEFT, y)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -40, Nav.VIEW_BOTTOM)
end

local function SelectCategory(frame, index, subId, keepSearch)
    if not keepSearch and frame.ResetSearch then frame:ResetSearch() end
    -- A Presets window left open goes with a change of tab.
    if E.Presets and E.Presets.Hide then E.Presets:Hide() end
    index = frame.categories[index] and index or 1
    frame.selectedCategory = index
    local cat = frame.categories[index]
    local sub = subId
    local valid = false
    for _, s in ipairs(cat.subs) do if s.id == sub then valid = true end end
    if not valid then
        sub = frame.selectedSub[index]
        valid = false
        for _, s in ipairs(cat.subs) do if s.id == sub then valid = true end end
        if not valid then sub = cat.subs[1].id end
    end
    frame.selectedSub[index] = sub
    if frame.setupMode then return end
    frame.sectionTitle:SetText(cat.name)
    frame.sectionAbout:SetText(cat.about)
    PaintTabs(frame, index)
    RenderSubTabs(frame, index)
    SetViewportTop(frame, cat.hasSubs and VIEW_TOP_SUBS or VIEW_TOP)
    ShowItems(frame, PageItems(frame, index, sub), true)
end

-- Folded options open or close under their switch at once, keeping the scroll.
local function RefreshFolds(frame)
    if frame.searching then return end -- search always lists them
    if frame.setupMode then
        if frame.walkEntries then ShowItems(frame, frame.walkEntries(), false) end
        return
    end
    local index = frame.selectedCategory or 1
    ShowItems(frame, PageItems(frame, index, frame.selectedSub[index]), false)
end

-- The words after a row's name ----------------------------------------------

-- "just added" only for players who had the old layout, while they run the
-- version it arrived in, and never in the setup walkthrough; "experimental",
-- "coming soon" and "log out to apply" always.
local function TagsFor(frame, key, row, show)
    local list = {}
    if show and Nav.NEW[key] then list[#list + 1] = "NEW" end
    if Rules().NeedsTesting(key) then list[#list + 1] = "TEST" end
    if row.unavailable then list[#list + 1] = "SOON" end
    if row.logoutPending then list[#list + 1] = "LOGOUT" end
    return list
end
local function RefreshTags(frame)
    local show = not frame.setupMode and E:GetSavedSetting("layoutPillsVersion") == E.version
    frame.showNewTags = show
    local R = Rows()
    for key, row in pairs(frame.checks) do R.SetTags(row, TagsFor(frame, key, row, show)) end
end

-- Search --------------------------------------------------------------------

local function ResetSearch(frame)
    frame.searchClearing = true
    frame.searchBox:SetText("")
    frame.searchBox:ClearFocus()
    frame.searchClearing = false
    frame.searchPlaceholder:Show()
    frame.searching = false
end

local function Result(frame, index)
    local result = frame.results[index]
    if not result then
        result = Rows().Result(frame)
        frame.results[index] = result
    end
    return result
end

-- Every option, folded ones too, matched on its name, summary, key, earlier
-- names, its tab and sub-tab names; colour and grey spelled either way.
-- Results come in tab order, then page order, as a list of rows: each says
-- where it lives, and a click goes there.
local function ApplySearch(frame)
    if frame.setupMode then return end
    local Normalise = Rules().Normalise
    local query = Normalise(string.lower(frame.searchBox:GetText() or ""):match("^%s*(.-)%s*$"))
    frame.searchPlaceholder:SetShown(query == "")
    if query == "" then
        frame.searching = false
        SelectCategory(frame, frame.selectedCategory or 1, nil, true)
        return
    end
    frame.searching = true
    local matches = {}
    for key, row in pairs(frame.checks) do
        local home = frame.rowHome[key]
        if home and row.classAllowed ~= false then
            local cat = frame.categories[home.tab]
            local subName = ""
            if cat.hasSubs then for _, sub in ipairs(cat.subs) do if sub.id == home.sub then subName = sub.name end end end
            local text = Normalise((row.searchText or string.lower(key)) .. " " .. string.lower(cat.name) .. " " .. string.lower(subName))
            local matched = true
            for word in query:gmatch("%S+") do
                if not text:find(word, 1, true) then matched = false; break end
            end
            if matched then matches[#matches + 1] = {row = row, home = home} end
        end
    end
    table.sort(matches, function(a, b)
        if a.home.tab ~= b.home.tab then return a.home.tab < b.home.tab end
        return a.home.place < b.home.place
    end)
    frame.sectionTitle:SetText("Search")
    frame.sectionAbout:SetText(#matches == 0 and "No options found."
        or (#matches == 1 and "1 option found. Click it to go to it.")
        or (#matches .. " options found. Click one to go to it."))
    PaintTabs(frame, 0)
    frame.subTabStrip:Hide()
    SetViewportTop(frame, VIEW_TOP)
    local items, R = {}, Rows()
    for i, match in ipairs(matches) do
        local result = Result(frame, i)
        result.target = match.row
        result.settingKey = match.row.settingKey
        result.text:SetText(match.row.labelText or match.row.settingKey)
        result.crumb:SetText(Nav.Crumb(frame, match.home))
        R.SetTags(result, TagsFor(frame, match.row.settingKey, match.row, frame.showNewTags))
        items[i] = {rows = {result}, depth = {[result] = 0}}
    end
    frame.searchResults = matches
    ShowItems(frame, items, true)
end

-- Scrolls a row into view, or centres it (after a jump).
local function ScrollTo(frame, row, centre)
    local content, scroll = frame.settingsContent, frame.settingsScroll
    local top, bottom = content:GetTop() - row:GetTop(), content:GetTop() - row:GetBottom()
    local current, view = scroll:GetVerticalScroll(), scroll:GetHeight()
    if centre then
        frame:SetSettingsScroll(top - (view - row:GetHeight()) / 2)
    elseif top < current then
        frame:SetSettingsScroll(top - 4)
    elseif bottom > current + view then
        frame:SetSettingsScroll(bottom - view + 4)
    end
end

-- Opens an option's tab and sub-tab, scrolls it into the middle and flashes
-- it. A folded option opens at its switch. Changes nothing.
local function JumpTo(frame, key)
    local home = frame.rowHome[key]
    if not home then return end
    local keyboard = frame.keys:HasFocus()
    ResetSearch(frame)
    SelectCategory(frame, home.tab, home.sub, true)
    local target = frame.checks[key]
    if target and not target:IsShown() then target = frame.checks[Rules().FOLDS[key] or ""] end
    if not (target and target:IsShown()) then return end
    ScrollTo(frame, target, true)
    Rows().Flash(target)
    if keyboard then frame:FocusRow(target) end
    return target
end

-- Keyboard ------------------------------------------------------------------

-- One hidden edit box (no mouse) takes the keys while a row has the
-- keyboard: Tab and Shift-Tab move, Space and Enter act, Escape lets go.
-- Nothing is bound: keys go to it only while it has focus.
local function FocusRow(frame, row)
    if frame.focusedRow and frame.focusedRow ~= row then Rows().SetFocus(frame.focusedRow, false) end
    frame.focusedRow = row
    if not row then ShowRowHelp(frame, nil); return end
    Rows().SetFocus(row, true)
    ScrollTo(frame, row, false)
    ShowRowHelp(frame, row)
    if not frame.keys:HasFocus() then frame.keys:SetFocus() end
end

local function VisibleRows(frame)
    return frame.visibleRows or {}
end

local function MoveFocus(frame, step)
    local list = VisibleRows(frame)
    if #list == 0 then return end
    local at = 0
    for i, row in ipairs(list) do if row == frame.focusedRow then at = i end end
    local n = at + step
    if at == 0 and step < 0 then n = #list end
    if n < 1 then n = #list elseif n > #list then n = 1 end
    FocusRow(frame, list[n])
end

local function Activate(frame, row)
    if not row then return end
    local kind = row.rowKind
    if kind == "tick" or kind == "link" or kind == "colour" or kind == "result" then row:Click()
    elseif kind == "button" then row.button:Click()
    elseif kind == "font" then row.fontButton:Click()
    elseif kind == "choice" then row.buttons[(row.selected or 1) % #row.buttons + 1]:Click()
    elseif kind == "more" then
        local button = row.open:IsShown() and row.open or row.getIt
        if button:IsShown() then button:Click() end
    end
end

local function Tour() return E.SettingsTour end
local function KeyTab(keys)
    local frame = keys.owner
    if frame.welcoming or frame.tourStep then return end
    MoveFocus(frame, (IsShiftKeyDown and IsShiftKeyDown()) and -1 or 1)
end
local function KeySpace(keys)
    local frame = keys.owner
    if frame.welcoming or frame.tourStep then return end
    Activate(frame, frame.focusedRow)
end
local function KeyEnter(keys)
    local frame = keys.owner
    if frame.welcoming then Tour().Go(frame)
    elseif frame.tourStep then Tour().Next(frame)
    else Activate(frame, frame.focusedRow) end
end
local function KeyEscape(keys)
    local frame = keys.owner
    if frame.welcoming then Tour().Later(frame); return end
    if frame.tourStep then Tour().End(frame); return end
    ClearRowFocus(frame)
    keys:ClearFocus()
    ShowRowHelp(frame, nil)
end
local function KeyArrow(keys, key)
    local frame = keys.owner
    if frame.welcoming then return end
    if frame.tourStep then
        if key == "LEFT" and frame.tourStep > 1 then Tour().Back(frame)
        elseif key == "RIGHT" then Tour().Next(frame) end
        return
    end
    if key == "UP" then MoveFocus(frame, -1) elseif key == "DOWN" then MoveFocus(frame, 1) end
end
local function KeyLost(keys)
    local frame = keys.owner
    if frame.welcoming or frame.tourStep then return end
    if frame.focusedRow then
        ClearRowFocus(frame)
        ShowRowHelp(frame, nil)
    end
end
local function KeyText(keys)
    if keys:GetText() ~= "" then keys:SetText("") end
end

local function BuildKeys(frame)
    local keys = CreateFrame("EditBox", nil, frame)
    keys.owner = frame
    keys:SetSize(1, 1)
    keys:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    -- An edit box needs a font before it takes text; this one is never seen
    -- and holds at most the one letter it clears at once.
    keys:SetFont(select(1, GameFontHighlight:GetFont()), 12, "")
    keys:SetMaxLetters(1)
    keys:SetAlpha(0)
    keys:EnableMouse(false)
    keys:SetAutoFocus(false)
    keys:SetScript("OnTabPressed", KeyTab)
    keys:SetScript("OnSpacePressed", KeySpace)
    keys:SetScript("OnEnterPressed", KeyEnter)
    keys:SetScript("OnEscapePressed", KeyEscape)
    keys:SetScript("OnArrowPressed", KeyArrow)
    keys:SetScript("OnEditFocusLost", KeyLost)
    keys:SetScript("OnTextChanged", KeyText)
    frame.keys = keys
end

local function BuildSearch(frame)
    local R = Rows()
    local search = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    search:SetSize(TAB_WIDTH, 28)
    search:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -58)
    search:SetAutoFocus(false)
    search:SetMaxLetters(80)
    search:SetFont(select(1, GameFontHighlight:GetFont()), 13, "")
    search:SetTextInsets(9, 9, 0, 0)
    search:SetBackdrop(R.BACKDROP)
    search:SetBackdropColor(.047, .055, .07, 1)
    search:SetBackdropBorderColor(.165, .18, .21, 1)
    local placeholder = R.Text(search, "Search options", 13, true)
    placeholder:SetPoint("LEFT", search, "LEFT", 9, 0)
    frame.searchBox, frame.searchPlaceholder = search, placeholder
    search:SetScript("OnTextChanged", function() if not frame.searchClearing then ApplySearch(frame) end end)
    search:SetScript("OnEscapePressed", function()
        ResetSearch(frame)
        SelectCategory(frame, frame.selectedCategory or 1, nil, true)
    end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTabPressed", function()
        local first = VisibleRows(frame)[1]
        if first then FocusRow(frame, first) end
    end)
end

-- Setup mode hides the tab list, title, search and tour button; the footer
-- then spans the window.
local function SetNavShown(frame, shown)
    for _, region in ipairs({frame.navigation, frame.navDivider, frame.navTitle, frame.searchBox, frame.tourButton}) do
        region:SetShown(shown)
    end
    for _, heading in ipairs(frame.groupHeadings) do heading:SetShown(shown) end
    for _, tab in ipairs(frame.tabs) do tab:SetShown(shown) end
    if not shown then frame.subTabStrip:Hide() end
    PinFooter(frame, not shown)
end

function Nav.Build(frame, className, classToken, classCoords)
    frame.selectedSub, frame.categories, frame.headingPool, frame.results = {}, {}, {}, {}
    for index, id in ipairs(TAB_IDS) do
        local tab = TABS[id]
        local subs = tab.subs or {{id = "main", sections = tab.sections}}
        if id == "class" then
            local sections = {}
            for i, section in ipairs(tab.sections) do
                sections[i] = section.title == "%RESOURCES%"
                    and S(Nav.RESOURCES[classToken] or "Resource bars", section.rows) or section
            end
            subs = {{id = "main", sections = sections}}
        end
        frame.categories[index] = {id = id, name = id == "class" and (className or "Class") or tab.name,
            icon = tab.icon, about = tab.about, group = TAB_GROUP[id], subs = subs, hasSubs = tab.subs ~= nil}
    end
    frame.tabIds, frame.tabIndex = TAB_IDS, TAB
    BuildSidebar(frame, classToken, classCoords)
    BuildHeader(frame)
    BuildFooter(frame)
    BuildSearch(frame)
    BuildKeys(frame)
    frame.SelectCategory, frame.PageItems, frame.ShowItems = SelectCategory, PageItems, ShowItems
    frame.RefreshFolds, frame.ShowRowHelp, frame.RefreshTags = RefreshFolds, ShowRowHelp, RefreshTags
    frame.ApplySearch, frame.ResetSearch, frame.JumpTo = ApplySearch, ResetSearch, JumpTo
    frame.FocusRow, frame.MoveFocus, frame.ClearRowFocus = FocusRow, MoveFocus, ClearRowFocus
    frame.SetViewportTop, frame.SetNavShown, frame.ActivateRow = SetViewportTop, SetNavShown, Activate
end

-- Once every row exists: where each lives (rowHome), each row's tab and
-- sub-tab, wide rows, and earlier names (and "experimental") for search.
function Nav.Index(frame)
    local OLD_NAMES = Rules().OLD_NAMES
    frame.rowHome, frame.pages = {}, {}
    local place = 0
    for index, cat in ipairs(frame.categories) do
        local pages = {}
        frame.pages[cat.id] = pages
        for _, sub in ipairs(cat.subs) do
            local list = {}
            pages[sub.id] = list
            for s, section in ipairs(sub.sections) do
                for _, key in ipairs(section.rows) do
                    local row = frame.checks[key]
                    if row then
                        place = place + 1
                        frame.rowHome[key] = {tab = index, sub = sub.id, section = s, place = place}
                        row.category, row.subId = index, sub.id
                        list[#list + 1] = key
                    end
                end
            end
        end
    end
    for key, row in pairs(frame.checks) do
        row.settingKey = key
        if Nav.WIDE[key] or row.wideRow then row.wide = true; row:SetWidth(Rows().WIDE) end
        -- "experimental" after its name finds it too.
        if row.searchText and Rules().NeedsTesting(key) then row.searchText = row.searchText .. " experimental" end
        local old = OLD_NAMES[key]
        if old and row.searchText then
            for _, name in ipairs(type(old) == "table" and old or {old}) do
                row.searchText = row.searchText .. " " .. string.lower(name)
            end
        end
    end
end
