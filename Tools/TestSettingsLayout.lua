-- The real /era window (Core/Settings.lua, SettingsNav.lua, SettingsRows.lua,
-- SettingsTour.lua, SettingsLayout.lua), class panels and mage action
-- overlays under the geometric frame mock in Tools/SettingsMock.lua.
-- Protected parents/anchors throw on combat mutations. The welcome card and
-- the walkthrough are Tools/TestSettingsTour.lua.
local M = dofile("Tools/SettingsMock.lua")
local equal, Session, Flush, Open, Tab = M.equal, M.Session, M.Flush, M.Open, M.Tab
local S = M.S
local EM, EN = "\226\128\148", "\226\128\147"
local function Keys(f) return table.concat(M.Keys(f), ",") end
local function Has(text, part) return text:find(part, 1, true) ~= nil end
local function Colour(t) return t and string.format("%.3f,%.3f,%.3f", t[1], t[2], t[3]) or "nil" end
-- A size or place as text, to two places ("32", "366", "10.5").
local function N(x) return string.format("%g", math.floor(x * 100 + .5) / 100) end
local CLASSES = {"HUNTER", "MAGE", "ROGUE", "WARRIOR", "PALADIN", "SHAMAN", "PRIEST", "WARLOCK", "DRUID"}
-- The rules' layout parent (fold, group or first DEPENDS option).
local function ParentOf(E) return function(key) return E.SettingsRules.GroupParent(key) end end

-- The approved map (the mockup's NAV): groups, tabs, sub-tabs, sections and
-- rows, in order. The class tab is checked per class below.
local EXPECTED = {
 {group = "LOOK", tabs = {
  {"appearance", "Appearance", "How EraUI looks: the style, Dark Mode and class colours.", {
   {"style", "Style", {{"STYLE", {"appearanceChoice", "presets"}}}},
   {"dark", "Dark Mode", {{"DARKNESS", {"darkModeDarkness", "darkenClassColours"}},
    {"BORDERS", {"darkAuraBorders", "darkAuraShadows", "darkDebuffLines"}},
    {"BARS AND WINDOWS", {"darkMenuBar", "darkWindows", "blackPages"}}}},
   {"classcol", "Class Colours", {{"CLASS COLOURS", {"classColors", "tooltipClassColours", "classColourBorders", "castBarClassBorder"}}}}}},
  {"actionBars", "Action Bars", "The stone dock and the Classic action buttons.", {
   {"main", nil, {{"ACTION BARS", {"actionBars", "gryphons", "hideEmptyActionSlots", "hideKeybindText", "hideMacroText"}}}}}},
  {"frames", "Frames & Nameplates", "Unit frames, portraits and nameplates.", {
   {"unit", "Unit Frames", {{"UNIT FRAMES", {"unitFrames", "matchFocusSize", "disableAggroHighlight", "portraitDebuffs",
    "classIconPortraitMine", "classIconPortraitOthers"}}}},
   {"plates", "Nameplates", {{"NAMEPLATES", {"friendlyNameplates", "enemyNameplates"}}}}}},
  {"map", "Map & Minimap", "The minimap and the world map.", {
   {"main", nil, {{"MINIMAP", {"minimap", "cleanMinimap", "coordinates"}}, {"WORLD MAP", {"mapQuestObjectives", "movableMap", "revealMap"}}}}}},
  {"windows", "Windows & Tooltips", "Classic frames for the game's windows, and tooltips.", {
   {"main", nil, {{"WINDOWS", {"gameMenu", "popups", "blizzardSettings", "mailSkin", "auctionHouse", "damageMeterSkin",
    "otherWindows", "contextMenus"}}, {"TOOLTIPS", {"tooltipSkin", "tooltipIDs"}}}}}},
 }},
 {group = "GAMEPLAY", tabs = {
  {"class", nil, "Tools for your class. Each class sees its own.", nil},
  {"casting", "Casting", "Cast bars for you and everyone else.", {
   {"main", nil, {{"CAST BARS", {"castBars", "advancedCastBar", "advancedCastClassFill", "advancedCastTicks", "advancedCastLatency"}}}}}},
  {"quests", "Quests", "The quest log, dialogue and tracker.", {
   {"main", nil, {{"QUESTS", {"questLog", "questDialogs", "questTracker", "questLevels"}},
    {"AUTOMATION", {"autoQuests", "autoGossip", "rewardUpgradeHighlight", "rewardProfile"}}}}}},
  {"character", "Character & Spells", "Character, talents, spellbook, trainer and professions.", {
   {"main", nil, {{"WINDOWS", {"characterPanel", "characterItemLevels", "talentWindow", "trainer", "professions"}},
    {"SPELLBOOK", {"spellbook", "spellbookCombatDrag", "trainingGuide", "showAllSpellRanks"}}}}}},
  {"bags", "Bags & Vendors", "Bags, loot and merchants.", {
   {"bagsloot", "Bags & Loot", {{"BAGS", {"bagsBank", "bagSpace", "bagItemLevels", "lootWindow", "fastAutoLoot", "discardCheapestJunk"}}}},
   {"vendors", "Vendors", {{"VENDORS", {"merchantSkin", "autoSellJunk", "autoRepair", "vendorPrice", "junkValueSummary", "durabilityWarning"}}}}}},
 }},
 {group = "SOCIAL", tabs = {
  {"chat", "Chat & Names", "Chat, names and EraUI's own messages.", {
   {"main", nil, {{"CHAT", {"hideSecondaryNames", "classicChatDragging", "linkToggle", "hideStatusMessages", "showWelcomeOnLogin", "updateCheck"}}}}}},
  {"group", "Group & Invites", "Friends, guild, group finder and invites.", {
   {"main", nil, {{"WINDOWS", {"socialWindows", "groupFinderPvp"}}, {"INVITES AND REQUESTS", {"blockDuels", "blockPartyInvites",
    "partyFromFriends", "inviteFromWhispers", "autoSummon", "autoResurrect", "releasePvP"}}}}}},
 }},
 {group = "EXTRAS", tabs = {
  {"screen", "Screen & Cursor", "The screen, your cursor and the AFK screen.", {
   {"screenmain", "Screen", {{"SCREEN", {"hideZoneText", "maxCameraZoom", "damageFont", "damageTextScale"}}}},
   {"cursor", "Cursor", {{"CURSOR RING", {"cursorRing", "cursorRingClassColour", "cursorRingSize", "cursorRingThickness"}},
    {"CAST RING AND TRAIL", {"cursorCastRing", "cursorCastClassColour", "cursorCastSize", "cursorCastOpacity", "cursorCastColour",
     "cursorTrail", "cursorTrailClassColour", "cursorTrailSize", "cursorTrailOpacity", "cursorTrailLength", "cursorTrailColour"}}}},
   {"afk", "AFK Screen", {{"AFK SCREEN", {"afkScreen", "afkShowZone", "afkShowGuild", "afkShowDate", "afkShowQuote", "afk24Hour",
    "afkZoom", "afkCameraNormal", "afkTurnRight"}}}}}},
  {"more", "More from Squirt", "Other addons by the same author.", {{"main", nil, {{"ADDONS", {"moreFECM", "moreFEC", "moreFECP"}}}}}},
 }},
}
-- Your class's tab, per class: its sections and rows in order.
local CLASS_PAGE = {
 HUNTER = "REMINDERS:classReminders|CLASS TOOLS:hunterFeed,classTools|RESOURCE BARS:manaBar|TIMERS:swingTimer,rangedSwingTimer",
 MAGE = "REMINDERS:classReminders|CLASS TOOLS:mageSupplies,mageAutoTrade,classTools|RESOURCE BARS:manaBar|TIMERS:rangedSwingTimer",
 ROGUE = "REMINDERS:classReminders|CLASS TOOLS:roguePoisons,classTools|COMBO POINTS AND ENERGY:floatingComboPoints,comboPointRed,energyBar|TIMERS:swingTimer,rangedSwingTimer",
 WARRIOR = "REMINDERS:classReminders|RESOURCE BARS:rageBar|TIMERS:swingTimer,rangedSwingTimer",
 PALADIN = "REMINDERS:classReminders|RESOURCE BARS:manaBar|TIMERS:swingTimer",
 SHAMAN = "REMINDERS:classReminders|RESOURCE BARS:manaBar|TIMERS:swingTimer",
 PRIEST = "REMINDERS:classReminders|RESOURCE BARS:manaBar|TIMERS:rangedSwingTimer",
 WARLOCK = "REMINDERS:classReminders|RESOURCE BARS:manaBar|TIMERS:rangedSwingTimer",
 DRUID = "REMINDERS:classReminders|COMBO POINTS AND RESOURCES:floatingComboPoints,comboPointRed,druidResourceBar|TIMERS:swingTimer",
}
-- A page as it shows: "HEADING:key,key|HEADING:key".
local function PageText(f)
 local items, out = f.settingsItems or {}, {}
 local current
 for _, item in ipairs(items) do
  if item.heading then current = {item.heading:upper()}; out[#out + 1] = current
  else for _, row in ipairs(item.rows) do current[#current + 1] = (#current == 1 and ":" or ",") .. row.settingKey end end
 end
 local parts = {}
 for i, section in ipairs(out) do parts[i] = table.concat(section) end
 return table.concat(parts, "|")
end
-- A class option's box (Class Reminders & Buffs, Pet Feeding Options,
-- Conjuring & Trade Options): the page's whole width under its whole-line
-- row, its options in both of the page's columns (ticks at 10 and 376), the
-- rows' square tick boxes in the class colour (no ON/OFF tracks), nothing
-- overlapping and everything inside the box. Returns how many switches.
local function BoxChecks(f, p, row, label)
 local content = f.settingsContent
 equal(N(p:GetLeft() - content:GetLeft()) .. " " .. N(p:GetWidth()) .. " " .. N(row:GetWidth()), "0 718 718", label .. " box spans the page under its whole-line row")
 equal(p:GetTop() <= row:GetBottom() - 5.99 and p:GetTop() >= row:GetBottom() - 6.01, true, label .. " box 6 under its row")
 local shown, columns, switches = {}, {}, 0
 local colour = RAID_CLASS_COLORS[S.token]
 for _, item in ipairs(p.items) do
  if item:IsVisible() and item.points[1] then
   shown[#shown + 1] = item
   local x = N(item:GetLeft() - p:GetLeft())
   columns[x] = true
   equal(item:GetLeft() >= p:GetLeft() + 9.99 and item:GetRight() <= p:GetRight() - 9.99 and item:GetTop() <= p:GetTop() - 7.99, true,
    label .. " " .. tostring(item.label and item.label:GetText()) .. " inside the box")
   equal(item.track == nil and item.thumb == nil, true, label .. " no ON/OFF track left")
   if item.tickBox then
    switches = switches + 1
    local box, mark = item.tickBox, item.tickMark
    equal(N(box:GetWidth()) .. "x" .. N(box:GetHeight()) .. " " .. N(box:GetLeft() - item:GetLeft()) .. " " .. Colour(box.fill) .. " " .. Colour(item.tickFill.fill),
     "14x14 0 0.300,0.320,0.360 0.059,0.063,0.075", label .. " " .. item.label:GetText() .. " a square tick box like the rows'")
    equal(N(mark:GetWidth()) .. "x" .. N(mark:GetHeight()) .. " " .. (colour and Colour(mark.fill) or ""), "8x8 " .. (colour and Colour({colour.r, colour.g, colour.b}) or ""),
     label .. " " .. item.label:GetText() .. " its inner square in the class colour")
    equal(N(item.label:GetLeft() - item:GetLeft()), "24", label .. " " .. item.label:GetText() .. " name after the tick box")
   end
   -- Measured with the game font's widths (M.Glyphs) at the label's own
   -- size, not the mock's six a letter: a switch's name in its label's
   -- width, a button's or slider's text in the frame less 8, and a switch's
   -- small tag word after its name.
   if item.label then
    local text = item.label:GetText()
    local size = item.label.font and item.label.font[2] or 12
    local room = item.label:GetWidth() > 0 and item.label:GetWidth() or item:GetWidth() - 8
    equal(M.Glyphs(text, size) <= room + .01, true, label .. " " .. tostring(text) .. " fits (" .. N(M.Glyphs(text, size)) .. " in " .. N(room) .. ")")
    if item.tag then
     equal(M.Glyphs(text, size) + 6 + M.Glyphs(item.tag:GetText(), 10) <= item:GetWidth() + .01, true, label .. " " .. text .. " and its " .. item.tag:GetText() .. " fit")
    end
   end
  end
 end
 equal(columns["10"] and columns["376"], true, label .. " options in both columns (10 and 376)")
 for i = 1, #shown do
  for j = i + 1, #shown do
   local a, b = shown[i], shown[j]
   -- A wide switch's own button sits inside its line, clear of its name.
   local inside = a.parent == b or b.parent == a
   local hit = a:GetLeft() < b:GetRight() - .01 and b:GetLeft() < a:GetRight() - .01 and a:GetBottom() < b:GetTop() - .01 and b:GetBottom() < a:GetTop() - .01
   equal(hit and not inside, false, label .. " " .. tostring(a.label and a.label:GetText()) .. " / " .. tostring(b.label and b.label:GetText()) .. " do not overlap")
   if inside then
    local switch, button = a.parent == b and b or a, a.parent == b and a or b
    equal(switch.label:GetRight() <= button:GetLeft() - 4 and N(button:GetRight()) == N(switch:GetRight()), true, label .. " " .. switch.label:GetText() .. " its button at the line's end, clear of its name")
   end
  end
 end
 if p.hint or p.offHint then
  local hint = p.offHint or p.hint
  for _, item in ipairs(shown) do equal(item:GetBottom() >= hint:GetTop() - .01 or not hint:IsShown(), true, label .. " the hint line under the options") end
 end
 return switches
end
-- Each sub-option and the row it sits under (DEPENDS first parent, FOLDS,
-- GROUPS). Those under darkMode (the Style sub-tab's choice) and unitFrames
-- (Frames & Nameplates) live elsewhere on purpose and are not indented.
local PARENT = {
 darkAuraShadows = "darkAuraBorders", darkDebuffLines = "darkAuraBorders", blackPages = "darkWindows",
 gryphons = "actionBars", matchFocusSize = "unitFrames", disableAggroHighlight = "unitFrames", portraitDebuffs = "unitFrames",
 advancedCastClassFill = "advancedCastBar", advancedCastTicks = "advancedCastBar", advancedCastLatency = "advancedCastBar",
 spellbookCombatDrag = "spellbook", trainingGuide = "spellbook", rewardProfile = "rewardUpgradeHighlight",
 comboPointRed = "floatingComboPoints",
 afkCameraNormal = "afkScreen", afkTurnRight = "afkScreen", afkZoom = "afkScreen", afk24Hour = "afkScreen",
 afkShowGuild = "afkScreen", afkShowZone = "afkScreen", afkShowDate = "afkScreen", afkShowQuote = "afkScreen",
}
local FOLDED = {
 cursorRing = {"cursorRingClassColour", "cursorRingSize", "cursorRingThickness"},
 cursorCastRing = {"cursorCastClassColour", "cursorCastSize", "cursorCastOpacity", "cursorCastColour"},
 cursorTrail = {"cursorTrailClassColour", "cursorTrailSize", "cursorTrailOpacity", "cursorTrailLength", "cursorTrailColour"},
}
for parent, kids in pairs(FOLDED) do for _, kid in ipairs(kids) do PARENT[kid] = parent end end
-- Options new since 1.5.5 ("just added" for returning players this version)
-- and those not seen working in game yet ("experimental", always). Nothing
-- says it moved any more.
local NEW = {darkDebuffLines = true, blackPages = true, darkWindows = true}
local TESTING = {darkAuraShadows = true, darkDebuffLines = true, darkWindows = true, blackPages = true, characterItemLevels = true}

-- Every class: the pages its rows sit on, the Dark Mode options and their
-- greying chains, live applying, class colours, item levels, AFK Screen,
-- cursor colour, the class tab's boxes, scrolling and setup.
EXPANDED_SCROLLS = {}
-- Measured, with Advanced open: in two columns the reminders box is short
-- enough for the page to fit, except where a class tools row and its box
-- (hunter, mage) or the poison picks (rogue) come too. A shorter window
-- scrolls for every class (checked below).
local EXPANDED_SCROLLS_EXPECTED = "HUNTER,MAGE,ROGUE"
for _, c in ipairs(CLASSES) do
 local E, f = Session(c)
 Open(f, "frames", "unit")
 M.NoOverlaps(f, c .. " Frames & Nameplates > Unit Frames")
 equal(f.checks.portraitDebuffs:IsShown(), true, c .. " portrait setting on Frames & Nameplates > Unit Frames")
 equal(f.checks.matchFocusSize:IsShown(), true, c .. " focus sizing on Frames & Nameplates > Unit Frames")
 -- Appearance > Dark Mode: Darkness, then Dark Aura Borders with Aura Shadows
 -- and Thin Debuff Colours under it, then Dark Menu Bar and Dark Windows with
 -- Black Pages under it.
 do
  local aura, shade, lines = f.checks.darkAuraBorders, f.checks.darkAuraShadows, f.checks.darkDebuffLines
  local bar, windows, black = f.checks.darkMenuBar, f.checks.darkWindows, f.checks.blackPages
  for _, row in ipairs({aura, shade, lines, bar, windows, black}) do
   equal(row.category == Tab(f, "appearance") and row.subId, "dark", c .. " " .. row.settingKey .. " on Appearance > Dark Mode")
  end
  equal(aura.text:GetText() .. "/" .. shade.text:GetText() .. "/" .. lines.text:GetText() .. "/" .. windows.text:GetText() .. "/" .. black.text:GetText(),
   "Dark Aura Borders/Aura Shadows/Thin Debuff Colours/Dark Windows/Black Pages", c .. " plain labels (experimental is a small word after the name)")
  Open(f, "appearance", "dark")
  M.NoOverlaps(f, c .. " Appearance > Dark Mode")
  M.Fits(f, c .. " Appearance > Dark Mode")
  equal(Keys(f), "darkModeDarkness,darkenClassColours,darkAuraBorders,darkAuraShadows,darkDebuffLines,darkMenuBar,darkWindows,blackPages",
   c .. " Dark Mode in the approved order")
  for _, row in ipairs({shade, lines}) do
   equal(row.depth == 1 and math.abs(row:GetLeft() - aura:GetLeft() - 22) < .01 and row:GetTop() < aura:GetBottom(), true,
    c .. " " .. row.settingKey .. " indented under Dark Aura Borders")
  end
  equal(black.depth == 1 and math.abs(black:GetLeft() - windows:GetLeft() - 22) < .01 and black:GetTop() < windows:GetBottom(), true,
   c .. " Black Pages indented under Dark Windows")
  equal(windows:GetTop() == bar:GetTop() and windows:GetLeft() > bar:GetRight(), true, c .. " Dark Windows beside Dark Menu Bar")
  -- Dark Mode off greys all five; Dark Aura Borders off greys its two;
  -- Dark Windows off greys Black Pages.
  E.settings.darkMode = nil; E.settings.darkAuraBorders = true; E.settings.darkWindows = true; f:RefreshDependencies()
  for _, row in ipairs({aura, shade, lines, bar, windows, black}) do
   equal(row.dependencyDisabled == true and row.alpha, .45, c .. " " .. row.settingKey .. " greyed while Dark Mode is off")
  end
  aura:SetChecked(false); aura:Click()
  equal(E.settings.darkAuraBorders == true and aura:GetChecked() == true, true, c .. " a click on a greyed row changes nothing and keeps its tick")
  shade:SetChecked(true); shade:Fire("OnClick")
  equal(E.settings.darkAuraShadows == nil and shade:GetChecked() == false, true, c .. " Aura Shadows can't be switched on without Dark Mode; its tick goes back")
  E.settings.darkMode = true; E.settings.darkAuraBorders = false; E.settings.darkWindows = false; f:RefreshDependencies()
  equal(aura.dependencyDisabled == false and aura.alpha == 1 and bar.dependencyDisabled == false and windows.dependencyDisabled == false, true,
   c .. " Dark Mode on: Dark Aura Borders, Dark Menu Bar and Dark Windows available")
  equal(shade.dependencyDisabled and lines.dependencyDisabled and black.dependencyDisabled, true, c .. " their sub-options still greyed")
  lines:SetChecked(true); lines:Fire("OnClick"); black:SetChecked(true); black:Fire("OnClick")
  equal(E.settings.darkDebuffLines == nil and E.settings.blackPages == nil, true, c .. " Thin Debuff Colours and Black Pages can't be switched on yet")
  E.settings.darkAuraBorders = true; E.settings.darkWindows = true; f:RefreshDependencies()
  equal(shade.dependencyDisabled == false and lines.dependencyDisabled == false and black.dependencyDisabled == false and black.alpha == 1, true,
   c .. " all available with their switches on")
  E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = nil, nil, nil; f:RefreshDependencies()
 end
 -- Class-coloured Tooltips on Appearance > Class Colours, under Chat Names.
 do
  local card, chat = f.checks.tooltipClassColours, f.checks.classColors
  equal(card.category == Tab(f, "appearance") and card.subId, "classcol", c .. " Class-coloured Tooltips on Appearance > Class Colours")
  Open(f, "appearance", "classcol")
  M.NoOverlaps(f, c .. " Appearance > Class Colours")
  equal(card:IsShown() and chat:IsShown() and card:GetLeft() > chat:GetRight() and card:GetTop() == chat:GetTop(), true,
   c .. " Class-coloured Tooltips beside Class-coloured Chat Names")
  equal(card.dependencyDisabled, nil, c .. " Class-coloured Tooltips needs no other option")
 end
 -- Bag Item Levels on Bags & Vendors > Bags & Loot, under Bags & Bank.
 do
  local card, bags = f.checks.bagItemLevels, f.checks.bagsBank
  equal(card.category == Tab(f, "bags") and card.subId, "bagsloot", c .. " Bag Item Levels on Bags & Vendors > Bags & Loot")
  Open(f, "bags", "bagsloot")
  M.NoOverlaps(f, c .. " Bags & Loot")
  equal(card:GetLeft() == bags:GetLeft() and card:GetTop() < bags:GetBottom() and card:GetTop() > bags:GetBottom() - 10, true,
   c .. " Bag Item Levels directly under Bags & Bank")
  equal(card.unavailable == false and card:GetChecked() == false and card.tickMark:IsShown() == false, true, c .. " can be switched, off by default")
  equal(Has(card.searchText, "quality colours"), true, c .. " its summary mentions the quality colours")
 end
 -- Character Item Levels right after Character Window, beside it, not indented.
 do
  local card, window = f.checks.characterItemLevels, f.checks.characterPanel
  equal(card.category, Tab(f, "character"), c .. " Character Item Levels on Character & Spells")
  equal(card.summary, "Item levels on the gear you wear, in quality colours.", c .. " its summary")
  Open(f, "character")
  M.NoOverlaps(f, c .. " Character & Spells")
  equal(card:GetTop() == window:GetTop() and card:GetLeft() > window:GetLeft() and (card.depth or 0) == 0, true,
   c .. " Character Item Levels right after Character Window, beside it, not indented")
  equal(card.dependencyDisabled, nil, c .. " needs no other option")
  equal(table.concat(card.tagIds, ","), "TEST", c .. " says experimental after its name")
 end
 -- AFK Screen on Screen & Cursor > AFK Screen, its eight options under it.
 do
  local afk = f.checks.afkScreen
  equal(afk.category == Tab(f, "screen") and afk.subId, "afk", c .. " AFK Screen on Screen & Cursor > AFK Screen")
  equal(afk.text:GetText() == "AFK Screen" and afk.unavailable == false and afk.wide == true, true, c .. " AFK Screen: its label, available, a whole line")
  equal(Has(afk.searchText, "try /era afk"), true, c .. " its summary offers the /era afk preview")
  Open(f, "screen", "afk")
  M.NoOverlaps(f, c .. " AFK Screen")
  M.Fits(f, c .. " AFK Screen")
  local labels = {}
  for _, key in ipairs({"afkShowZone", "afkShowGuild", "afkShowDate", "afkShowQuote", "afk24Hour", "afkZoom", "afkCameraNormal", "afkTurnRight"}) do
   local row = f.checks[key]
   labels[#labels + 1] = row.text:GetText()
   equal(row:IsShown() and row.depth == 1 and math.abs(row:GetLeft() - afk:GetLeft() - 22) < .01, true, c .. " " .. key .. " indented under AFK Screen")
  end
  equal(table.concat(labels, ","), "Show Zone,Show Guild,Show Date,Class Quote,24-Hour Clock,Zoom In,Faster Camera,Circle Right", c .. " the AFK options' short labels")
  E.settings.afkScreen = nil; f:RefreshDependencies()
  equal(afk.dependencyDisabled, nil, c .. " AFK Screen itself is never greyed out")
  equal(f.checks.afkZoom.dependencyDisabled and f.checks.afkShowQuote.dependencyDisabled and f.checks.afkZoom.alpha == .45, true, c .. " its options greyed while it is off")
 end
 equal(f.checks.cursorCastRing.category == Tab(f, "screen") and f.checks.cursorTrail.subId == "cursor", true, c .. " the cursor effects on Screen & Cursor > Cursor")
 -- The class tab: its sections, its boxes, and how it scrolls.
 Open(f, "class")
 equal(PageText(f), CLASS_PAGE[c], c .. " class tab sections and rows")
 equal(f.sectionTitle:GetText(), f.tabs[Tab(f, "class")].text:GetText(), c .. " class tab named after the class")
 M.Fits(f, c .. " collapsed")
 M.NoOverlaps(f, c .. " class tab")
 local p = E.modules.ClassReminders:OptionsPanel()
 equal(f.checks.classTools:IsShown(), c == "HUNTER" or c == "MAGE" or c == "ROGUE", c .. " only useful tool rows shown")
 equal(p.group:IsShown(), c ~= "ROGUE" and c ~= "SHAMAN", c .. " group checking matches supported reminders")
 equal(p.clickable:IsShown(), true, c .. " reminder clicking matches supported actions")
 equal(p.mana:IsShown(), c ~= "ROGUE", c .. " the out-of-mana note only where a click casts a spell")
 equal(p.poisonClick ~= nil and p.poisonClick:IsShown(), c == "ROGUE", c .. " Click to apply poisons only for rogues")
 equal(p.mainPoison ~= nil and p.offPoison ~= nil, c == "ROGUE", c .. " poison picks only for rogues")
 if c == "ROGUE" then
  local pc, main, off = p.poisonClick, p.mainPoison, p.offPoison
  equal(pc.label:GetText(), "Click to apply poisons", "Click to apply poisons: a plain name")
  equal(pc.tag:GetText() .. " " .. Colour(pc.tag.colour), "experimental 0.660,0.610,0.530", "with a small warm grey experimental after it")
  equal(pc.tag.font[2] == 10 and pc.tag:GetText() == pc.tag:GetText():lower(), true, "small, lower case")
  equal(pc.tag:GetLeft() >= pc.label:GetLeft() + pc.label:GetStringWidth() + 4 and pc.tag:GetLeft() + pc.tag:GetStringWidth() <= pc:GetRight(), true,
   "right after the name, inside its switch")
  equal(pc.label:GetStringWidth() <= pc.label:GetWidth(), true, "its label fits its width")
  equal(pc.dependencyDisabled, true, "greyed out until Clickable reminders is on")
  -- The rogue's box: Show during combat | Clickable reminders, Click to apply
  -- poisons | Show all reminders, then Main hand | Off hand, Alert size |
  -- Reset alert positions, and Advanced.
  local function Line(a, b) return a:GetTop() == b:GetTop() and N(a:GetLeft() - p:GetLeft()) == "10" and N(b:GetLeft() - p:GetLeft()) == "376" end
  equal(Line(p.combat, p.clickable) and Line(pc, p.prev) and Line(main, off) and Line(p.size, p.reset), true, "the rogue's box in two columns")
  equal(pc:GetTop() < p.combat:GetBottom() and main:GetTop() < pc:GetBottom() and p.size:GetTop() < main:GetBottom()
   and p.adv:GetTop() < p.size:GetBottom() and N(p.adv:GetLeft() - p:GetLeft()) == "10", true, "switches first, then the poison picks, the alert buttons and Advanced")
  equal(N(main:GetWidth()) .. " " .. N(p.size:GetWidth()) .. " " .. N(p.adv:GetWidth()), "332 332 332", "each button fills its column")
  equal(main.label:GetText() .. " / " .. off.label:GetText(), "Main hand: Spell8681  > / Off hand: Spell8681  >", "level 20: both hands pick Instant Poison")
  for _, hand in ipairs({"Main hand: ", "Off hand: "}) do
   for _, family in ipairs(E.PoisonData.families) do
    main.label:SetText(hand .. family.name .. "  >")
    equal(main.label:GetStringWidth() <= main:GetWidth() - 8, true, hand .. family.name .. " fits its button")
   end
  end
  main.draw()
  local lines = {}
  GameTooltip = {SetOwner = function() end, SetText = function(_, t) lines = {t} end, AddLine = function(_, t) lines[#lines + 1] = t end,
   Show = function() end, Hide = function() end, IsOwned = function() return true end}
  -- Each hover, word for word, and none with an em or en dash.
  local function Hover(b, label)
   b:Fire("OnEnter")
   for _, l in ipairs(lines) do equal(not Has(l, EM) and not Has(l, EN), true, "no em or en dash in the " .. label .. " help") end
   return table.concat(lines, "\n")
  end
  equal(Hover(pc, "Click to apply poisons"), "Click to apply poisons\nTurn on Clickable reminders to use this.\n"
   .. "With Clickable reminders on, a left-click on POISON!'s icon puts your main hand's poison on your main hand, and a right-click puts your off hand's poison on your off hand. "
   .. "It uses the game's own item use, outside combat only, with the highest rank you carry that your level allows. "
   .. "Pick each hand's poison with the buttons below. Experimental: not seen working in game yet.\nDefault: Off.",
   "Click to apply poisons: its title, what to turn on while greyed, what each click does, experimental, off by default")
  equal(Hover(off, "off hand pick"), "Off hand poison\nPicks the poison a right-click on POISON! puts on your off hand: the highest rank you carry that your level allows. "
   .. "Only poisons your level allows are offered, from level 20. With none in your bags, POISON! says so. Each rogue keeps its own picks.\n"
   .. "Default: Spell2835, or Spell8681 before level 30.", "the off hand's pick, in its own words, with its default from Forever's data")
  equal(Hover(main, "main hand pick"), "Main hand poison\nPicks the poison a left-click on POISON! puts on your main hand: the highest rank you carry that your level allows. "
   .. "Only poisons your level allows are offered, from level 20. With none in your bags, POISON! says so. Each rogue keeps its own picks.\n"
   .. "Default: Spell8681.", "the main hand's too")
  GameTooltip = nil
 end
 equal(p.combatClick:IsShown(), c == "HUNTER" or c == "WARLOCK", c .. " pet clicks in combat only for pet classes")
 equal(p.combatClick.label:GetStringWidth() <= p.combatClick.label:GetWidth(), true, c .. " its label fits its width")
 equal(p.combatClick.dependencyDisabled, true, c .. " greyed out until Clickable reminders is on")
 if p.combatClick:IsShown() then
  equal(p.combatClick:GetTop() == p.clickable:GetTop() and p.combatClick:GetLeft() > p.clickable:GetRight(), true, c .. " it sits beside Clickable reminders")
  equal(p.mana:GetTop() < p.combatClick:GetBottom(), true, c .. " the mana note on the line under them")
 end
 -- The box spans the page, in two columns, with square ticks.
 local switches = BoxChecks(f, p, f.checks.classReminders, c .. " reminders box")
 equal(switches >= 4, true, c .. " the reminders box's switches are tick boxes (" .. switches .. ")")
 for _, other in ipairs({p.group, p.combat, p.clickable, p.combatClick, p.poisonClick, p.mana}) do
  if other and other:IsShown() then
   equal(other:GetTop() > p.prev:GetTop() or (other:GetTop() == p.prev:GetTop() and other:GetLeft() < p.prev:GetLeft()), true,
    c .. " Show all reminders is the last switch")
  end
 end
 equal(p.size:GetTop() < p.prev:GetBottom(), true, c .. " the buttons start a line of their own under the switches")
 if c == "HUNTER" or c == "MAGE" then
  local tools = f.checks.classTools
  equal(tools.kind, "Frame", c .. " inline heading is not a button")
  equal(tools.scripts.OnClick, nil, c .. " inline heading has no click action")
  equal(tools.inlinePanel:IsShown(), true, c .. " its box opens under it")
  equal(tools.wide, true, c .. " the heading takes a whole line, so its box can span the page")
  BoxChecks(f, tools.inlinePanel, tools, c .. " class tools box")
 end
 p.adv:Fire("OnClick"); Flush(); M.Fits(f, c .. " expanded"); M.NoOverlaps(f, c .. " expanded")
 BoxChecks(f, p, f.checks.classReminders, c .. " reminders box with Advanced open")
 local low
 for _, row in ipairs(p.advRows) do if row.label:GetText() == "PET LOW HEALTH!" then low = row end end
 equal(low ~= nil, c == "HUNTER" or c == "WARLOCK", c .. " pet low health switch only for pet classes")
 if low then
  equal(low:IsShown() and N(low:GetWidth()), "332", c .. " pet low health fills a column")
  equal(M.Glyphs(low.label:GetText(), 12) <= low.label:GetWidth(), true, c .. " its label fits its width")
  equal(low.label:GetRight() <= low.limit:GetLeft() - 4, true, c .. " its label clears the Below button")
  equal(N(low.limit:GetRight()), N(low:GetRight()), c .. " the Below button at the column's end")
  equal(M.Glyphs(low.limit.label:GetText(), 11) <= low.limit:GetWidth() - 8, true, c .. " the Below button's text fits")
 end
 -- Every choice a choice button can show fits it, in the game font's widths
 -- at 11 point: just the choice, its switch's name before it says what for.
 local function ChoicesFit(name, cb)
  for _, def in ipairs(E.ReminderSpells[c] or {}) do
   if def.choices and def.text == name then
    for _, choice in ipairs(def.choices) do
     cb.label:SetText(choice.name .. "  >")
     equal(M.Glyphs(cb.label:GetText(), 11) <= cb:GetWidth() - 8, true, c .. " " .. name .. " " .. choice.name .. " fits its button")
    end
   end
  end
  cb.draw()
  equal(Has(cb.label:GetText(), ": "), false, c .. " " .. name .. " its button shows just the choice: " .. cb.label:GetText())
 end
 local choiceLines = 0
 for _, row in ipairs(p.advRows) do
  local cb = row.choice
  if cb then
   choiceLines = choiceLines + 1
   local name = c .. " " .. row.label:GetText()
   equal(row.label:GetText() == "SEAL!" or row.label:GetText() == "AURA!", true, name .. " has a plain label")
   equal(row:IsShown() and N(row:GetWidth()), "332", name .. " fills a column")
   equal(M.Glyphs(row.label:GetText(), 12) <= row.label:GetWidth(), true, name .. " label fits its width")
   equal(row.label:GetRight() <= cb:GetLeft() - 4, true, name .. " label clears the choice button")
   equal(cb:IsShown() and N(cb:GetRight()), N(row:GetRight()), name .. " choice button at the column's end")
   ChoicesFit(row.label:GetText(), cb)
  end
  -- A switch and its choice button share a column.
  if row.pairNext then
   equal(row.pairNext:GetTop() == row:GetTop() and row.pairNext:GetLeft() > row:GetRight(), true, c .. " " .. row.label:GetText() .. " its choice button beside it")
   local mid = p:GetLeft() + 366
   equal((row:GetLeft() < mid) == (row.pairNext:GetLeft() < mid), true, c .. " " .. row.label:GetText() .. " and its button in one column")
   ChoicesFit(row.label:GetText(), row.pairNext)
  end
  -- A plain switch with a name too long for half a column fills one.
  if row.tickBox and not row.choice and not row.pairNext and not row.limit then
   local long = M.Glyphs(row.label:GetText(), 12) > 160 - 28
   equal(N(row:GetWidth()), long and "332" or "160", c .. " " .. row.label:GetText() .. (long and " too long for half a column, fills one" or " half a column"))
  end
 end
 local longNames = {PRIEST = "SHADOW PROTECTION!", WARLOCK = "CREATE HEALTHSTONE!"}
 if longNames[c] then
  local found
  for _, row in ipairs(p.advRows) do if row.label:GetText() == longNames[c] then found = row end end
  equal(found and found:IsShown() and N(found:GetWidth()) .. " " .. N(found.label:GetWidth()), "332 304", c .. " " .. longNames[c] .. " fills a column, its whole name shown")
 end
 equal(choiceLines, c == "PALADIN" and 2 or 0, c .. " whole-column choice switches only for SEAL! and AURA!")
 -- With its box expanded the class tab may scroll (measured); in a shorter
 -- window it always does, with the hint until the end.
 if f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + .01 then EXPANDED_SCROLLS[#EXPANDED_SCROLLS + 1] = c end
 local fullHeight = f:GetHeight()
 M.Resize(f, 500)
 local endHeight = f.settingsContent:GetHeight()
 equal(endHeight > f.settingsScroll:GetHeight() + .01, true, c .. " expanded class tab scrolls in a shorter window")
 equal(f.settingsScrollHint:IsShown(), true, c .. " long page indicates options below")
 equal(f.settingsScrollHint:GetTop() <= f.settingsScroll:GetBottom() + .01 and f.settingsScrollHint:GetBottom() >= f.footer:GetTop() - .01, true,
  c .. " hint between the rows and the footer")
 f:SetSettingsScroll(99999)
 equal(f.settingsScroll:GetVerticalScroll(), endHeight - f.settingsScroll:GetHeight(), c .. " scroll reaches the last panel")
 equal(f.settingsScrollHint:IsShown(), false, c .. " hint disappears at page bottom")
 f:SetSettingsScroll(0)
 equal(f.settingsScrollHint:IsShown(), true, c .. " hint returns after scrolling up")
 f:SetSettingsScroll(99999)
 p.adv:Fire("OnClick"); Flush()
 equal(f.settingsScroll:GetVerticalScroll() <= math.max(0, f.settingsContent:GetHeight() - f.settingsScroll:GetHeight()), true, c .. " collapse clamps offset")
 M.Resize(f, fullHeight)
 -- Search lists results, never the rows, so no box shows; clearing it opens them again.
 f.searchBox:SetText("class"); Flush(); M.Fits(f, c .. " search results")
 for key, card in pairs(f.checks) do
  if card.inlinePanel then equal(card.inlinePanel:IsShown(), false, c .. " search shows no options box under " .. key) end
 end
 f.searchBox:SetText("no matching cursor option"); Flush()
 equal(f.settingsScrollHint:IsShown(), false, c .. " no scroll hint for an empty search")
 f.searchBox:SetText(""); Flush(); M.Fits(f, c .. " restored class page")
 equal(p:IsShown(), true, c .. " the class tab opens Class Reminders & Buffs' box again")
 if c == "HUNTER" or c == "MAGE" then equal(f.checks.classTools.inlinePanel:IsShown(), true, c .. " and the class tools box") end
 f:SetSetupMode(true); Flush()
 equal(f.settingsScroll:GetLeft() - f:GetLeft(), 30, c .. " setup viewport position")
 f:SetSetupMode(false); Flush(); M.Fits(f, c .. " return from setup")
end
equal(table.concat(EXPANDED_SCROLLS, ","), EXPANDED_SCROLLS_EXPECTED, "which classes' tab scrolls with its box expanded (measured)")
print("Class tabs that scroll with the reminders box expanded: " .. table.concat(EXPANDED_SCROLLS, ","))

-- The details, word for word, on one class: descriptions, live applying and chat lines.
do
 local E, f = Session("DRUID")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 for key in pairs(real.reloadSettings) do E.reloadSettings[key] = true end
 for key, value in pairs(real.settingDefaults) do E.settingDefaults[key] = value end
 local aura, shade, lines = f.checks.darkAuraBorders, f.checks.darkAuraShadows, f.checks.darkDebuffLines
 local windows, black, bar = f.checks.darkWindows, f.checks.blackPages, f.checks.darkMenuBar
 Open(f, "appearance", "dark")
 E.settings.darkMode = nil; f:RefreshDependencies()
 -- Dark Aura Borders.
 local text, help, extras = M.Hover(f, aura)
 equal(extras, "Switch on Dark Mode first (Appearance > Style).  Default: On.", "Dark Aura Borders names Dark Mode and where it is, then its default")
 equal(help, "Dark Aura Borders  Thin dark borders round your own buff and debuff icons. Debuffs keep their coloured border, or a thin line with Thin Debuff Colours.",
  "Dark Aura Borders: short, and it names Thin Debuff Colours (on the same sub-tab)")
 equal(Has(text, "reload") or Has(text, EM), false, "no reload line and no em dash")
 -- Choosing Dark Mode makes it available at once.
 f.appearanceChoices[2]:Click()
 equal(E.settings.darkMode == true and aura.dependencyDisabled == false and aura.alpha == 1, true, "Dark Mode chosen: Dark Aura Borders available at once")
 equal(f.appearanceChoices[2].selected and not f.appearanceChoices[1].selected, true, "and Dark Mode shows as chosen")
 local refreshed, status = 0
 E.modules.AuraStyle = {RefreshBorders = function() refreshed = refreshed + 1 end, RefreshClassTooltips = function() refreshed = refreshed + 10 end}
 local say = E.Status; E.Status = function(_, m) status = m end
 E.settings.darkAuraBorders = false; aura:SetChecked(false); aura:Click()
 equal(E.settings.darkAuraBorders == true and aura:GetChecked() == true and refreshed == 1, true, "a click on Dark Aura Borders switches it on, live through AuraStyle")
 equal(status, "Dark Aura Borders enabled.", "says so in chat")
 aura:Click()
 equal(E.settings.darkAuraBorders == false and refreshed == 2 and status == "Dark Aura Borders disabled.", true, "and off, live")
 -- Aura Shadows.
 equal(shade.dependencyDisabled, true, "Aura Shadows greyed while Dark Aura Borders is off")
 _, help, extras = M.Hover(f, shade)
 equal(extras, "Switch on Dark Aura Borders first.  Default: On.", "Aura Shadows names Dark Aura Borders (same sub-tab, no place)")
 equal(help, "Aura Shadows  A soft shadow round your own buff and debuff icons, just outside the dark border. It never covers the next icon.",
  "Aura Shadows help: what it does (experimental is the word after its name, not in its help)")
 E.settings.darkMode = nil; f:RefreshDependencies()
 _, _, extras = M.Hover(f, shade)
 equal(extras, "Switch on Dark Mode first (Appearance > Style).  Default: On.", "with Dark Mode off too, Dark Mode first")
 E.settings.darkMode = true; E.settings.darkAuraBorders = true; f:RefreshDependencies()
 shade:SetChecked(true); shade:Click()
 equal(E.settings.darkAuraShadows == false and refreshed == 3 and status == "Aura Shadows disabled.", true, "Aura Shadows off, live")
 shade:Click()
 equal(E.settings.darkAuraShadows == true and status == "Aura Shadows enabled.", true, "and on")
 local get = E.GetSetting
 E.GetSetting = function(self, key) if key == "darkMode" then return false end; return get(self, key) end
 shade:Click(); shade:Click()
 equal(status, "Aura Shadows enabled. They show once Dark Mode is applied.", "Aura Shadows waits for Dark Mode to be applied")
 E.GetSetting = get
 -- Thin Debuff Colours.
 _, help, extras = M.Hover(f, lines)
 equal(help, "Thin Debuff Colours  Your debuffs get the dark border, with a thin line inside in the debuff's colour, like blue for magic. Target and focus keep theirs.",
  "Thin Debuff Colours: the line, and that target and focus keep their look")
 equal(extras, "Default: Off.", "Thin Debuff Colours off by default")
 lines:SetChecked(false); lines:Click()
 equal(E.settings.darkDebuffLines == true and status == "Thin Debuff Colours enabled.", true, "Thin Debuff Colours on, live")
 lines:Click()
 equal(E.settings.darkDebuffLines == false and status == "Thin Debuff Colours disabled.", true, "and off")
 E.GetSetting = function(self, key) if key == "darkMode" then return false end; return get(self, key) end
 lines:Click()
 equal(status, "Thin Debuff Colours enabled. They show once Dark Mode is applied.", "waits for Dark Mode to be applied")
 E.GetSetting = get
 -- Dark Windows, Black Pages and Dark Menu Bar, live through EraUI.Classic.
 _, help, extras = M.Hover(f, windows)
 equal(help, "Dark Windows  Darkens the red buttons, pop-ups, window edges and book pages Dark Mode left light, with the Darkness slider. Gold text stays gold.",
  "Dark Windows: what it darkens, in two lines")
 equal(extras, "Default: On.", "Dark Windows on by default")
 _, _, extras = M.Hover(f, black)
 equal(extras, "Switch on Dark Windows first.  Default: Off.", "Black Pages names Dark Windows while it is off")
 E.settings.darkWindows = true; f:RefreshDependencies()
 _, help, extras = M.Hover(f, black)
 equal(help, "Black Pages  Near black spellbook and Professions pages instead of Dark Windows' brown-grey. Names keep their gold and text stays readable.",
  "Black Pages: its words")
 equal(extras, "Default: Off.", "Black Pages: off by default")
 local wins, menus = 0, 0
 E.Classic.RefreshDarkWindows = function() wins = wins + 1 end
 E.Classic.RefreshDarkMenuBar = function() menus = menus + 1 end
 E.settings.darkWindows = true; windows:SetChecked(true); windows:Click()
 equal(E.settings.darkWindows == false and wins == 1 and status == "Dark Windows disabled.", true, "Dark Windows off, live through EraUI.Classic")
 equal(black.dependencyDisabled, true, "Black Pages greyed at once")
 windows:Click()
 equal(E.settings.darkWindows == true and wins == 2 and status == "Dark Windows enabled." and black.dependencyDisabled == false, true, "Dark Windows on frees Black Pages at once")
 black:SetChecked(false); black:Click()
 equal(E.settings.blackPages == true and wins == 3 and status == "Black Pages enabled.", true, "Black Pages on, live")
 bar:SetChecked(true); bar:Click()
 equal(E.settings.darkMenuBar == false and menus == 1 and wins == 3 and status == "Dark Menu Bar disabled.", true, "Dark Menu Bar off, live, leaving the windows alone")
 E.GetSetting = function(self, key) if key == "darkMode" then return false end; return get(self, key) end
 bar:Click()
 equal(status, "Dark Menu Bar enabled. It shows once Dark Mode is applied.", "Dark Menu Bar waits for Dark Mode")
 E.GetSetting = get
 E.Classic.RefreshDarkWindows, E.Classic.RefreshDarkMenuBar = nil, nil
 windows:Click()
 equal(E.settings.darkWindows, false, "without Classic loaded, the tick still saves")
 -- Darken class colours too: its own row now, re-tinting through the slider's refresh.
 local tints = 0
 E.Classic.RefreshDarkness = function() tints = tints + 1 end
 local darken = f.checks.darkenClassColours
 equal(darken.text:GetText() .. " / " .. tostring(darken:IsShown()), "Darken class colours too / true", "Darken class colours too is a row under Darkness")
 darken:Click()
 equal(E.settings.darkenClassColours == true and tints == 1, true, "it switches on and re-tints at once")
 E.Classic.RefreshDarkness = nil
 -- The Darkness slider.
 local darkness = f.checks.darkModeDarkness
 equal(darkness.wide and darkness.text:GetText(), "Darkness: 58", "Darkness: a whole line, with its value")
 darkness.slider:SetValue(80)
 equal(E.settings.darkModeDarkness == 80 and darkness.text:GetText() == "Darkness: 80", true, "dragging it saves the value")
 -- The value shows once, in its name; nothing sits between the slider and
 -- the row's end (the grey swatch there looked like an empty box).
 darkness.slider:SetValue(90)
 equal(darkness.text:GetText() .. " " .. tostring(darkness.swatch), "Darkness: 90 nil", "Darkness: 90, and no swatch")
 local after = {}
 for _, region in ipairs(darkness.children) do
  if region ~= darkness.slider and region ~= darkness.tagBox and region:IsShown() and region.points[1] and region:GetLeft() >= darkness.slider:GetRight() - .01 then
   after[#after + 1] = region.kind
  end
 end
 equal(table.concat(after, ","), "", "nothing drawn after the slider")
 _, _, extras = M.Hover(f, darkness)
 equal(extras, "Default: 58.", "its default")
 -- Class-coloured Tooltips.
 _, help, extras = M.Hover(f, f.checks.tooltipClassColours)
 equal(help, "Class-coloured Tooltips  A player's tooltip border, name and class in their class colour, on EraUI's tooltips or the game's own. NPCs keep theirs.",
  "Class-coloured Tooltips help")
 equal(extras, "Default: Off.", "off by default")
 local tip = f.checks.tooltipClassColours
 tip:Click()
 equal(E.settings.tooltipClassColours == true and status == "Class-coloured Tooltips enabled. Hover a player to see it.", true, "applies live, says so")
 E.modules.AuraStyle = nil
 -- Bag Item Levels and Character Item Levels.
 _, help, extras = M.Hover(f, f.checks.bagItemLevels)
 equal(help, "Bag Item Levels  Item levels on the gear in your bags, in quality colours, with a green arrow on an upgrade over what you wear. Not the bank yet.",
  "Bag Item Levels help: the levels, the arrow, not the bank")
 equal(extras, "Default: Off.", "Bag Item Levels off by default, no Coming soon")
 local count = 0
 local realBags = E.modules.BagItemLevels
 E.modules.BagItemLevels = {Refresh = function() count = count + 1 end}
 f.checks.bagItemLevels:Click()
 equal(E.settings.bagItemLevels == true and count == 1 and status == "Bag Item Levels enabled. Open your bags to see it.", true, "Bag Item Levels on, live")
 E.modules.BagItemLevels = realBags
 _, help, extras = M.Hover(f, f.checks.characterItemLevels)
 equal(help, "Character Item Levels  Item levels on the gear you wear, in quality colours, in EraUI's character window or Blizzard's. They match Bag Item Levels.",
  "Character Item Levels help")
 E.modules.CharacterItemLevels = {Refresh = function() count = count + 1 end}
 f.checks.characterItemLevels:Click()
 equal(E.settings.characterItemLevels == true and count == 2 and status == "Character Item Levels enabled. Open your character window to see it.", true, "Character Item Levels on, live")
 E.modules.CharacterItemLevels = nil
 -- AFK Screen, live through its module, and /era afk.
 Open(f, "screen", "afk")
 local afk, quote = f.checks.afkScreen, f.checks.afkShowQuote
 _, help, extras = M.Hover(f, afk)
 equal(help, "AFK Screen  When you go AFK the interface fades and your character stands beside a card with your name, zone and time away. Move to come back.",
  "AFK Screen help")
 equal(extras, "Default: On.", "on by default")
 E.settings.afkScreen = false; f:RefreshDependencies()
 _, help, extras = M.Hover(f, quote)
 equal(help, "Class Quote  A famous Classic line for your class, like a loading screen tip. A new one each time you're away.", "Class Quote help")
 equal(extras, "Switch on AFK Screen first.  Default: On.", "Class Quote names the AFK Screen while it is off")
 local realAfk = E.modules.AFKScreen
 local afkCount = 0
 E.modules.AFKScreen = {Refresh = function() afkCount = afkCount + 1 end}
 afk:SetChecked(false); afk:Click()
 equal(E.settings.afkScreen == true and afkCount == 1 and status == "AFK Screen enabled. Type /era afk to preview it.", true, "AFK Screen on, live")
 equal(quote.dependencyDisabled, false, "its options available at once")
 quote:SetChecked(true); quote:Click()
 equal(E.settings.afkShowQuote == false and afkCount == 2 and status == "AFK Screen: Class Quote disabled.", true, "Class Quote off, live, with the AFK Screen's name in chat")
 afk:Click()
 equal(E.settings.afkScreen == false and afkCount == 3 and status == "AFK Screen disabled.", true, "AFK Screen off")
 E.modules.AFKScreen = realAfk; E.settings.afkScreen = nil; f:RefreshDependencies()
 local printed = {}
 local print = E.Print; E.Print = function(_, m) printed[#printed + 1] = m end
 SlashCmdList.ERAUI("afk"); Flush()
 equal(printed[1], "Turn on AFK Screen in /era > Screen & Cursor > AFK Screen first.", "/era afk reaches the real preview")
 equal(E.SettingsNav.Crumb(f, f.rowHome.afkScreen), "Screen & Cursor > AFK Screen", "and names the sub-tab AFK Screen is on")
 printed = {}; SlashCmdList.ERAUI("help")
 equal(Has(printed[1] or "", "/era afk previews the AFK screen."), true, "/era help lists /era afk")
 E.Print = print
 -- Cast Bars says the boss bars follow the Raid Timers while they are on.
 _, help, extras = M.Hover(f, f.checks.castBars)
 equal(help, "Cast Bars  Classic cast bars for you, target, focus, bosses and nameplates. Boss bars follow Forever Enhanced Cooldown Manager's Raid Timers when it's on.",
  "Cast Bars help (the reload is the footer's own line)")
 equal(extras, "Needs /reload to apply.  Default: On.", "Cast Bars needs a reload")
 equal(f.checks.castBars.summary, "Player, target, focus, boss and nameplate casts.", "Cast Bars summary names the boss bars")
 -- The cursor colour picker.
 local cursor = 0; E.modules.CursorEffects = {Refresh = function() cursor = cursor + 1 end}
 E.settings.cursorTrailClassColour = true; E.settings.cursorTrailColour = "123456"
 local picker
 ColorPickerFrame = {SetupColorPickerAndShow = function(_, info) picker = info end, GetColorRGB = function() return 1, .5, 0 end}
 f.checks.cursorTrailColour:Click()
 picker.swatchFunc()
 equal(E.settings.cursorTrailColour, "FF8000", "custom trail colour saved")
 equal(E.settings.cursorTrailClassColour == false and f.checks.cursorTrailClassColour:GetChecked() == false, true, "custom selection switches off class colour, its tick too")
 equal(Colour(f.checks.cursorTrailColour.swatch.fill), "1.000,0.502,0.000", "the swatch shows it")
 picker.cancelFunc()
 equal(E.settings.cursorTrailColour == "123456" and E.settings.cursorTrailClassColour == true, true, "cancel restores the colour and class mode")
 equal(cursor, 2, "colour preview and cancellation apply immediately")
 ColorPickerFrame = nil; E.modules.CursorEffects = nil
 E.Status = say
end

-- Configure navigation for every class: the class tools and reminders open
-- /era at their controls, on the class tab, never as a toggle.
for _, c in ipairs({"DRUID", "WARRIOR", "PALADIN", "SHAMAN", "PRIEST", "WARLOCK", "HUNTER", "MAGE", "ROGUE"}) do
 local E, f = Session(c)
 E.settings.classReminders = true
 local expected = c == "HUNTER" and "HunterFeed" or c == "MAGE" and "MageSupplies" or c == "ROGUE" and "RoguePoisons" or "ClassReminders"
 equal(E.ClassTools:ActiveModule(), E.modules[expected], c .. " real class route")
 -- Class Reminders & Buffs refreshes the alerts at once, once.
 do
  local reminders = E.modules.ClassReminders
  local refresh, count = reminders.Refresh, 0
  reminders.Refresh = function(self, ...) count = count + 1; return refresh(self, ...) end
  local card = f.checks.classReminders
  card:SetChecked(true); card:Click()
  equal(E.settings.classReminders == false and count == 1, true, c .. " the row switches Class Reminders & Buffs off and refreshes the alerts once")
  count = 0; card:Click()
  equal(E.settings.classReminders == true and count == 1, true, c .. " the same switching it on")
  reminders.Refresh = refresh
 end
 local button = f.checks.classTools
 local function OpenTools()
  if button:IsShown() and button.scripts.OnClick then button:Click() else E.ClassTools:Open() end
  Flush()
 end
 OpenTools()
 equal(f:IsShown(), true, c .. " Configure keeps settings open")
 local key = (c == "HUNTER" or c == "MAGE") and "classTools" or "classReminders"
 local function Focused(label)
  equal(f:IsShown(), true, label .. " settings shown")
  equal(f.selectedCategory, Tab(f, "class"), label .. " class tab selected")
  equal(f.searchBox:GetText(), "", label .. " search cleared")
  local anchor = f.checks[key]
  equal(anchor:IsShown(), true, label .. " destination anchor shown")
  equal(anchor.inlinePanel:IsShown(), true, label .. " actual controls shown")
  equal(anchor:GetTop() <= f.settingsScroll:GetTop() + .01, true, label .. " anchor below viewport top")
  equal(anchor:GetBottom() >= f.settingsScroll:GetBottom() - .01, true, label .. " anchor above viewport bottom")
 end
 if c == "ROGUE" then
  equal(EraUIRogueTools:IsShown(), true, "rogue Configure opens real poison window")
  equal(M.Depends(EraUIRogueTools, f), false, "rogue tool window independent of settings")
  OpenTools(); equal(EraUIRogueTools:IsShown(), true, "repeat rogue click leaves poison window open")
  EraUIRogueTools:Hide()
 else
  Focused(c .. " first click")
  OpenTools(); Focused(c .. " repeat click")
  f:Hide(); f.selectedCategory = 1
  E.ClassTools:Open(); Flush(); Focused(c .. " initially closed")
  f.searchBox:SetText("no matching control"); Flush()
  E.ClassTools:Open(); Flush(); Focused(c .. " from search")
  f:SetSetupMode(true)
  E.ClassTools:Open(); Flush(); Focused(c .. " from setup")
  equal(f.setupMode, false, c .. " tool navigation exits setup")
 end
 E.settings.classReminders = false
 f:Hide(); f.selectedCategory = 1
 SlashCmdList.ERAUI("reminders"); Flush()
 key = "classReminders"; Focused(c .. " disabled reminder command")
 equal(E.settings.classReminders, false, c .. " navigation does not enable reminders")
 equal(E.modules.ClassReminders:OptionsPanel().offHint:IsShown(), true, c .. " disabled explanation remains visible")
 SlashCmdList.ERAUI("reminders"); Flush(); Focused(c .. " repeated reminder command")
 -- Ordinary /era remains a toggle, using the actual Integration bridge.
 SlashCmdList.ERAUI(""); Flush(); equal(f:IsShown(), false, c .. " normal slash still closes")
 SlashCmdList.ERAUI(""); Flush(); equal(f:IsShown(), true, c .. " normal slash still opens")
 E.ClassTools:Open(); f:Hide(); Flush()
 equal(f:IsShown(), false, c .. " closing immediately after navigation stays closed")
 if c == "ROGUE" then EraUIRogueTools:Hide() end
 S.combat = true
 E.ClassTools:Open(); E.modules.ClassReminders:Open(); Flush()
 equal(f:IsShown(), false, c .. " combat attempt does not open settings")
 if c == "ROGUE" then equal(EraUIRogueTools:IsShown(), false, "combat attempt does not open poison window") end
 S.combat = false
end

-- Coming soon features as they will be once finished: the same rows switch
-- on and apply live through their modules.
do
 local E, f = Session("DRUID", true)
 local card = f.checks.bagItemLevels
 Open(f, "bags", "bagsloot")
 equal(card.unavailable == false and card.tickMark:IsShown() == false and table.concat(card.tagIds, ",") == "", true, "finished: Bag Item Levels has no coming soon and is off")
 local _, help, extras = M.Hover(f, card)
 equal(Has(help .. extras, "Coming soon"), false, "finished: no Coming soon line")
 equal(Has(help, "green arrow on an upgrade over what you wear"), true, "finished: its help")
 local count, status = 0
 E.modules.BagItemLevels = {Refresh = function() count = count + 1 end}
 local say = E.Status; E.Status = function(_, m) status = m end
 card:Click()
 equal(E.settings.bagItemLevels == true and count == 1 and status == "Bag Item Levels enabled. Open your bags to see it.", true, "finished: switches on live")
 card:Click()
 equal(E.settings.bagItemLevels == false and count == 2 and status == "Bag Item Levels disabled.", true, "and off")
 E.modules.BagItemLevels = nil; E.Status = say; E.settings.bagItemLevels = nil
 f:SetSetupMode(true); Flush()
 f.setupPreset = "classicqol"; f.setupPage = 7; f:RenderSetup(); Flush()
 equal(f.setupProgress:GetText() .. " " .. f.sectionTitle:GetText(), "OPTIONS  4 / 7 Bags & Vendors", "walkthrough on its Bags & Vendors page")
 equal(card:IsShown(), true, "the walkthrough's Bags & Vendors page offers Bag Item Levels")
 f:SetSetupMode(false); Flush()
 for _, key in ipairs({"afkScreen", "afkCameraNormal", "afkTurnRight", "afkZoom", "afk24Hour", "afkShowGuild", "afkShowZone", "afkShowDate", "afkShowQuote"}) do
  equal(f.checks[key] and f.checks[key].subId, "afk", "finished: " .. key .. " on Screen & Cursor > AFK Screen")
 end
 f:RefreshDependencies()
 equal(f.checks.afkZoom.dependencyDisabled, true, "AFK options greyed out while AFK Screen is off")
 local afk = 0; E.modules.AFKScreen = {Refresh = function() afk = afk + 1 end}
 f.checks.afkScreen:Click()
 equal(E.settings.afkScreen == true and afk == 1 and f.checks.afkZoom.dependencyDisabled == false, true, "AFK Screen on, live, its options available")
 f.checks.afkShowDate:SetChecked(true); f.checks.afkShowDate:Click()
 equal(E.settings.afkShowDate == false and afk == 2, true, "AFK display options apply live too")
 E.modules.AFKScreen = nil
end

-- Coming soon, as a feature would ship before it is finished: SOON, its tick
-- empty, can't be switched on, a saved on still shows off, a preset click
-- keeps SOON, and the footer says so.
do
 local E, f = Session("DRUID", nil, true)
 local card = f.checks.bagItemLevels
 Open(f, "bags", "bagsloot")
 equal(card.text:GetText(), "Bag Item Levels", "coming soon: a plain label")
 equal(card.unavailable == true and table.concat(card.tagIds, ",") == "SOON", true, "coming soon: SOON at the row's end")
 equal(card:GetChecked() == false and card.tickMark:IsShown() == false, true, "coming soon: its tick empty")
 local _, _, extras = M.Hover(f, card)
 equal(extras, "Coming soon: not finished yet.  Default: Off.", "coming soon: the footer says so")
 local real, refreshed = E.modules.BagItemLevels, 0
 E.modules.BagItemLevels = {Refresh = function() refreshed = refreshed + 1 end}
 E.settings.bagItemLevels = true; f:Hide(); f:Show(); Flush()
 equal(card:GetChecked() or card.tickMark:IsShown(), false, "coming soon: a saved on still shows off")
 E.settings.bagItemLevels = nil
 card:Click()
 equal(E.settings.bagItemLevels == nil and refreshed == 0 and card:GetChecked() == false, true, "coming soon: a click changes nothing and runs nothing")
 E.modules.BagItemLevels = real
 f:SetSetupMode(true); Flush()
 f.presetChoices[1]:Click(); Flush()
 equal(card.unavailable == true and card.tickMark:IsShown() == false and table.concat(card.tagIds, ","), "SOON", "a preset click keeps a Coming soon row on SOON")
 f:SetSetupMode(false); Flush()
 -- Context Menus is Coming soon too, last on Windows & Tooltips.
 Open(f, "windows")
 equal(f.checks.contextMenus.unavailable == true and M.Keys(f)[8], "contextMenus", "Context Menus SOON, last of the windows")
end

-- The mage's secure conjure buttons over the class tab.
do
 local E, f = Session("MAGE")
 local Mage = E.modules.MageSupplies
 local function Actions()
  local out = {}; for _, b in ipairs(S.frames) do if b.secure then out[#out + 1] = b end end; return out
 end
 local actions = Actions()
 equal(#actions, 2, "both mage actions created")
 for _, b in ipairs(actions) do
  equal(b.parent, UIParent, "secure button independent parent")
  equal(M.Depends(b, f), false, "secure button has no settings dependency")
  equal(b:IsShown(), true, "fully visible inline action enabled")
  equal(b.attributes.type, "spell", "conjure action retains secure spell route")
 end
 local panel = f.checks.classTools.inlinePanel
 -- Food and water side by side: the conjure buttons, then the stack sliders under them.
 local food, water, foodStacks, waterStacks = panel.items[1], panel.items[2], panel.items[3], panel.items[4]
 equal(food:GetTop() == water:GetTop() and water:GetLeft() > food:GetRight(), true, "the water conjure button beside the food one")
 equal(foodStacks:GetTop() == waterStacks:GetTop() and N(foodStacks:GetLeft()) == N(food:GetLeft()) and N(waterStacks:GetLeft()) == N(water:GetLeft()), true,
  "each stack slider under its conjure button")
 equal(foodStacks.label:GetTop() <= food:GetBottom() - 4 and waterStacks.label:GetTop() <= water:GetBottom() - 4, true, "the slider labels clear the conjure buttons")
 local slot = panel.items[1]
 local function Aligned(label)
  Mage:SyncButtons()
  for _, b in ipairs(actions) do
   if b:IsShown() and b.attributes.spell == 587 then
    equal(math.abs(b:GetLeft() * b:GetEffectiveScale() - slot:GetLeft() * slot:GetEffectiveScale()) < .01, true, label .. " x")
    equal(math.abs(b:GetTop() * b:GetEffectiveScale() - slot:GetTop() * slot:GetEffectiveScale()) < .01, true, label .. " y")
   end
  end
 end
 Aligned("initial")
 f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 150, -40); f:Fire("OnDragStop"); Aligned("moved")
 f:SetScale(.7); Aligned("scaled")
 f.searchBox:SetText("conjure"); Flush(); M.Fits(f, "mage search")
 -- Search lists results: the heading, its box and the conjure buttons over it stay on the class tab.
 equal(f.checks.classTools:IsShown() or panel:IsShown(), false, "mage search shows no heading or box")
 for _, b in ipairs(actions) do equal(b:IsShown(), false, "conjure actions hidden in search") end
 f.searchBox:SetText(""); Flush()
 equal(panel:IsShown(), true, "clearing search opens the box again")
 for _, b in ipairs(actions) do equal(b:IsShown(), true, "with its conjure actions") end
 Aligned("after search")
 Open(f, "frames", "unit")
 for _, b in ipairs(actions) do equal(b:IsShown(), false, "conjure actions hidden on another tab") end
 Open(f, "class"); Aligned("back on the class tab")
 for _, b in ipairs(actions) do equal(b:IsShown(), true, "conjure actions back on the class tab") end
 f:Hide(); for _, b in ipairs(actions) do equal(b:IsShown(), false, "close hides independent action") end
 f:Show(); Flush()
 S.combat = true
 for _, b in ipairs(actions) do b.shown = false end -- Secure visibility driver, not insecure Lua.
 Mage:Refresh()
 f.searchBox:SetText("class"); Flush(); f:SetSettingsScroll(99999)
 f:SetSetupMode(true); Flush(); f:SetSetupMode(false); Flush()
 f:Hide(); f:Show(); Flush(); f:Fire("OnEvent", "UI_SCALE_CHANGED")
 for _, b in ipairs(actions) do equal(b:IsShown(), false, "combat navigation never shows conjure action") end
 equal(true, true, "combat close, search, setup, scrolling and scaling have no protected mutations")
 S.combat = false
 for _, b in ipairs(actions) do b.shown = b.rule ~= "hide" end -- Native driver exits combat.
 Mage:Refresh(); Flush()
 for _, b in ipairs(actions) do equal(b:IsShown(), true, "combat exit restores visible actions") end
 -- A small viewport must never leave a clipped or offscreen secure click target.
 f.settingsScroll:ClearAllPoints(); f.settingsScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 226, -148); f.settingsScroll:SetSize(718, 100)
 f:LayoutSettings(true); Mage:SyncButtons()
 for _, b in ipairs(actions) do equal(b:IsShown(), false, "clipped action hidden") end
 f:SetSettingsScroll(99999); Mage:SyncButtons()
 M.Fits(f, "short viewport")
end

-- Setup walkthrough: presets come first, the pages that follow depend on the
-- preset, and a quest tracker step appears only with Questie installed.
do
 local E, f = Session("DRUID")
 local P = E.Presets
 for _, key in ipairs(P.LOOK) do E.settings[key] = true; E.reloadSettings[key] = true; f.loadedSettings[key] = true end
 local reloads = 0
 ReloadUI = function() reloads = reloads + 1 end
 local function Next() f.setupNext:Click(); Flush() end
 local function Final() return f.setupNext.label:GetText() ~= "Next >" end
 local function Steps()
  local steps = 0
  while not Final() and steps < 20 do Next(); steps = steps + 1 end
  return steps
 end
 local function Restart() f:SetSetupMode(false); Flush(); f:SetSetupMode(true); Flush() end
 f:SetSetupMode(true); Flush()
 local choices = f.presetChoices
 equal(#choices, 3, "three presets on the first page")
 equal(choices[1]:IsShown() and choices[2]:IsShown() and choices[3]:IsShown(), true, "presets are the first page")
 equal(choices[1].label:GetText(), "Classic + Quality of Life", "preset names fit without a Selected: prefix")
 equal(choices[1].tag:IsShown() and not choices[2].tag:IsShown(), true, "the Classic look starts on Classic + Quality of Life, only one tagged")
 equal(choices[3]:GetRight() <= f:GetRight(), true, "third preset fits inside the walkthrough")
 equal(f.presetButton:IsVisible() or f.tourButton:IsShown() or f.tabs[1]:IsShown() or f.searchBox:IsShown(), false,
  "no Presets button, tab list, search or Take the tour during the walkthrough")
 Next()
 equal(f.checks.classColourBorders:IsShown() and f.checks.appearanceChoice:IsShown() and f.checks.presets:IsShown() == false, true,
  "Classic + QoL: the style page next (all of Appearance but Presets)")
 equal(f.sectionTitle:GetText(), "Choose your style", "its title")
 M.NoOverlaps(f, "setup style page")
 f.setupBack:Click(); Flush()
 equal(Steps(), 10, "Classic + QoL without Questie: style, damage text, seven option pages, finish")
 E.settings.damageFont = "pepsi"; E.combatFontAtLoad = nil; E:ApplyCombatFont()
 f:RenderSetup()
 equal(f.fontQuestion:IsShown(), false, "no question with the font the game loaded")
 E:SetSetting("damageFont", "bangers"); E:ApplyCombatFont()
 f:RenderSetup()
 equal(f.fontQuestion:IsShown(), true, "a new font: asked whether to log out now")
 local logout = EraUISetupLogout
 equal(logout:IsShown() and logout.attributes.type1 == "macro" and logout.attributes.macrotext1, "/logout", "Yes logs out through the game's own secure macro")
 local line = f.footer:GetTop()
 equal(f.fontLogoutSpot:GetBottom() > line and f.fontLaterButton:GetBottom() > line and logout:GetBottom() > line, true,
  "Yes, log out (its spot and the button over it) and No, later sit above the footer's line")
 equal(f.fontQuestion:GetBottom() - line, 11, "the question 11 above the footer's line")
 local loose = logout.parent == UIParent
 for _, p in ipairs(logout.points) do if p[2] ~= UIParent then loose = false end end
 equal(loose, true, "laid over its spot on the screen, not joined to the window")
 f.logoutWatch:Fire("OnEvent", "PLAYER_REGEN_DISABLED")
 equal(logout:IsShown(), false, "hidden as combat starts")
 S.combat = true; f:Hide(); f:Show(); S.combat = false
 f.logoutWatch:Fire("OnEvent", "PLAYER_REGEN_ENABLED")
 equal(logout:IsShown(), true, "the window closed and opened in combat, and the button came back after")
 EraUIClassicCharDB.onboarding = nil
 logout:Fire("PreClick")
 equal(EraUIClassicCharDB.onboarding.exploreSettings, true, "logging out finishes setup first")
 local hints = EraUIClassicCharDB.onboarding
 equal(hints.discoveryHintsVersion == 3 and hints.discoverTabs[Tab(f, "class")] == true and hints.discoverTabs[Tab(f, "casting")] == true
  and hints.discoverTabs[2] == nil and hints.discoverTabs[5] == nil, true, "finishing setup saves the class and Casting hints in the grouped order")
 f.fontLaterButton:Click()
 equal(f.fontQuestion:IsShown() or logout:IsShown(), false, "No, later puts it off")
 equal(Has(f.setupSummary:GetText(), "Your new damage font shows next time you log in."), true, "and says when it'll show")
 E:SetSetting("damageFont", "pepsi"); E:ApplyCombatFont(); f.fontLater = nil
 f:RenderSetup()
 equal(f.fontQuestion:IsShown() or Has(f.setupSummary:GetText(), "log in"), false, "picking the loaded font again clears it")
 E:SetSetting("damageFont", "bangers"); E:ApplyCombatFont(); f:RenderSetup()
 equal(f.fontQuestion:IsVisible() and logout:IsShown(), true, "asked again with a new font")
 f.setupNext:Click(); Flush()
 equal(f.setupMode or reloads > 0, false, "Explore settings leaves setup without a reload")
 equal(f:IsShown() and f.selectedCategory == 1 and f.presetButton:IsVisible(), true, "the normal /era window opens on Appearance > Style, with Presets")
 equal(f.fontQuestion:IsShown() or logout:IsShown(), false, "no question or log out button left in /era")
 f.fontLaterButton:Click(); Flush()
 equal(f.setupNext:IsShown() or f.setupBack:IsShown(), false, "No, later does nothing outside setup")
 Restart(); Steps()
 equal(f.fontQuestion:IsVisible() and logout:IsShown(), true, "asked again after rerunning setup")
 f:Hide()
 equal(logout:IsShown(), false, "closing the window hides the log out button")
 f.logoutWatch:Fire("OnEvent", "PLAYER_REGEN_DISABLED"); f.logoutWatch:Fire("OnEvent", "PLAYER_REGEN_ENABLED")
 f:Fire("OnDragStop"); Flush()
 equal(logout:IsShown(), false, "and it stays hidden after the next fight")
 SlashCmdList.ERAUI(""); Flush()
 equal(f:IsShown() and not f.setupMode, true, "/era then opens the normal settings")
 equal(f.fontQuestion:IsShown() or logout:IsShown(), false, "without the question or its button")
 Restart(); Steps()
 equal(logout:IsShown(), true, "asked on the finish page once more")
 f.logoutWatch:Fire("OnEvent", "PLAYER_REGEN_DISABLED"); S.combat = true
 SlashCmdList.ERAUI(""); Flush()
 S.combat = false; f.logoutWatch:Fire("OnEvent", "PLAYER_REGEN_ENABLED"); Flush()
 equal(f.fontQuestion:IsShown() or logout:IsShown(), false, "leaving setup in combat keeps it hidden after")
 E:SetSetting("damageFont", "pepsi"); E:ApplyCombatFont()
 Restart()
 Next(); Next()
 equal(f.checks.damageFont:IsShown() and f.checks.damageTextScale:IsShown(), true, "damage text page after the style page")
 equal(Keys(f) .. " " .. tostring(f.checks.damageFont.wide and f.checks.damageTextScale.wide), "damageFont,damageTextScale true", "font, then size, each a whole line")
 equal(f.setupProgress:GetText(), "DAMAGE TEXT", "its step is named")
 local oldCVar = C_CVar; C_CVar = {GetCVar = function(name) return name == "WorldTextScale_v2" and "1" or nil end, SetCVar = function() end}
 local scale = f.checks.damageTextScale
 scale:SetChecked()
 equal(scale.slider:IsShown() and scale.text:GetText(), "Damage Text Size: 1.00x", "the size found under the game's newer name")
 scale.slider:SetValue(250)
 local big = scale.preview.font[2]
 scale.slider:SetValue(50)
 equal(big > scale.preview.font[2] and scale.preview:GetText(), "1234", "a sample number grows and shrinks with the size")
 C_CVar = oldCVar
 scale:SetChecked()
 equal(scale.slider:IsShown() == false and scale.text:GetText(), "Damage Text Size: not available", "a game without the size says so")
 -- The font list: names in their own fonts; picking one saves it and says "log out to apply".
 local font = f.checks.damageFont
 font.fontButton:Click()
 equal(font.list:IsShown() and #font.list.rows, #E.CombatFonts, "the font list opens with every font")
 local say, status = E.Status; E.Status = function(_, m) status = m end
 E.combatFontAtLoad = "pepsi"
 font.list.rows[3]:Click()
 equal(E.settings.damageFont == "bangers" and font.list:IsShown() == false and font.sample:GetText() == "Bangers", true, "picking Bangers saves it and shows it")
 equal(status, "Damage text font: Bangers. Log out and back in to apply.", "and says so")
 equal(table.concat(font.tagIds, ","), "LOGOUT", "the row says log out to apply")
 local word = font.tags[1]
 equal(word:GetText() .. " " .. Colour(word.colour) .. " " .. word.font[2], "log out to apply 0.580,0.620,0.680 10", "small, muted, lower case")
 equal(word:IsVisible() and word:GetLeft() >= font.fontButton:GetRight() + 9.99 and word:GetLeft() + M.Glyphs(word:GetText(), 10) <= font:GetRight() - 10, true,
  "after the font button, inside the row")
 local _, _, extras = M.Hover(f, font)
 equal(extras, "Needs a log out to apply. A /reload won't do it.  Default: Pepsi.", "its footer says a log out applies it")
 E:SetSetting("damageFont", "pepsi"); font:SetChecked(); f:RefreshTags()
 equal(table.concat(font.tagIds, ","), "", "back to the loaded font: no label")
 E.Status = say
 Next()
 equal(f.sectionTitle:GetText(), "Action Bars", "the first options page is Action Bars")
 equal(f.checks.hideKeybindText:IsShown() and f.checks.showAllSpellRanks:IsShown(), true, "Action Bars offers keybind text and, joining it, Show All Spell Ranks")
 equal(f.checks.actionBars:IsShown(), false, "but not the reload-only Action Bars look")
 Next(); Next(); Next(); Next(); Next(); Next()
 equal(f.sectionTitle:GetText(), "Screen & Cursor", "the last options page is Screen & Cursor")
 equal(f.checks.cursorRing:IsShown() and f.checks.afkScreen:IsShown(), true, "with the cursor effects and the AFK Screen")
 equal(f.checks.damageFont:IsShown() or f.checks.damageTextScale:IsShown(), false, "the damage text rows aren't repeated there")
 Restart()
 choices[2]:Click(); Flush()
 equal(choices[2].tag:IsShown() and not choices[1].tag:IsShown(), true, "Classic look only selected")
 equal(Steps(), 3, "Classic look only: style page, damage text, then finish; QoL pages skipped")
 Restart()
 E.settings.vendorPrice = true; E.settings.darkMode = true
 choices[3]:Click(); Flush()
 equal(E.settings.unitFrames == false and E.settings.darkMode == false and E.settings.vendorPrice == true, true, "QoL only switches the Classic look and its optional looks off, QoL options stay")
 Next()
 equal(f.checks.classColourBorders:IsShown(), false, "QoL only: no style page")
 f.setupBack:Click(); Flush()
 equal(Steps(), 9, "QoL only: damage text, seven option pages, then finish")
 equal(f.setupNext.label:GetText(), "Reload & explore", "switching the look asks for the final reload")
 local choice, reloadNeeded = "", false
 E.modules.QuestTrackerChoice = {
  QuestieInstalled = function() return true end, CurrentChoice = function() return choice end,
  SetChoice = function(_, c) choice = c; reloadNeeded = c == "classic" end, NeedsReload = function() return reloadNeeded end,
 }
 Restart()
 equal(choices[3].tag:IsShown(), true, "the modern look starts on Quality of Life only")
 Next()
 equal(f.trackerChoices[1]:IsShown(), false, "QoL only has no tracker step")
 f.setupBack:Click(); Flush()
 choices[1]:Click(); Flush()
 equal(E.settings.unitFrames, true, "Classic + QoL switches the Classic look back on")
 Next(); Next()
 equal(f.trackerChoices[1]:IsShown(), true, "tracker step after the style page")
 equal(f.trackerChoices[1]:GetLeft() - f:GetLeft(), 30, "the tracker choices start at the walkthrough's edge")
 f.trackerChoices[1]:Click(); Flush()
 equal(choice, "classic", "tracker choice applied")
 f.setupBack:Click(); Flush(); f.setupBack:Click(); Flush()
 equal(Steps(), 11, "Classic + QoL with Questie: style, tracker, damage text, seven option pages, finish")
 f.setupNext:Click()
 equal(reloads, 1, "finish reloads straight from the click")
 f:SetSetupMode(false); Flush()
 equal(f.trackerChoices[1]:IsShown() or choices[1]:IsShown(), false, "walkthrough choices hidden outside setup")
 for i, button in ipairs(f.trackerChoices) do
  equal(button:GetLeft() - f:GetLeft(), f.sectionTitle:GetLeft() - f:GetLeft() + (i - 1) * 366, "tracker choice " .. i .. " lines up with the pages outside setup")
  equal(button:GetLeft() > f.navDivider:GetLeft(), true, "tracker choice " .. i .. " clear of the tab list")
 end
 -- The Presets row heads Appearance > Style: the active preset, never a warning.
 Open(f, "appearance", "style")
 equal(Keys(f), "appearanceChoice,presets", "Style holds the Look choice and Presets")
 equal(f.presetButton:IsVisible() and f.presetButton.label:GetText(), "Choose a preset", "Presets button on its row")
 local shown = 0
 local realPresets = E.Presets
 E.Presets = setmetatable({Show = function() shown = shown + 1 end, Hide = function() end}, {__index = realPresets})
 f.presetButton:Click()
 equal(shown, 1, "it opens the Presets window")
 E.Presets = realPresets
 f:Show(); Flush()
 equal(f.presetLabel:GetText(), "Preset: Classic look", "Classic look recognised")
 E.settings.minimap = false; f:UpdatePresetLabel()
 equal(f.presetLabel:GetText(), "Preset: Custom", "any change to the look shows Custom")
 for _, key in ipairs(P.LOOK) do E.settings[key] = false end; f:UpdatePresetLabel()
 equal(f.presetLabel:GetText(), "Preset: Quality of Life only", "modern look recognised")
 -- Update Notice: an ordinary row on Chat & Names now.
 equal(f.updateNotice, nil, "no Update Notice tick in the corner any more")
 Open(f, "chat")
 local update = f.checks.updateCheck
 equal(update:IsShown() and Keys(f), "hideSecondaryNames,classicChatDragging,linkToggle,hideStatusMessages,showWelcomeOnLogin,updateCheck", "Update Notice last on Chat & Names")
 local tickSay, tickStatus = E.Status
 E.Status = function(_, m) tickStatus = m end
 E.settings.updateCheck = true; update:SetChecked(true); update:Click()
 equal(E.settings.updateCheck == false and tickStatus == "Update Notice off.", true, "switching it off says so")
 update:Click()
 equal(E.settings.updateCheck == true and tickStatus == "Update Notice on.", true, "and on")
 local _, help = M.Hover(f, update)
 equal(help, "Update Notice  Tells you in chat when someone in your guild or group has a newer EraUI.", "its help no longer points at a tick")
 E.Status = tickSay
 -- The footer: Changelog and Discord beside Reload UI.
 local discord, changelog = f.discordButton, f.changelogButton
 local dpoint, dto, drel, dx = discord:GetPoint()
 equal(dpoint == "RIGHT" and dto == f.footer and drel == "RIGHT" and dx, -174, "Discord left of Reload UI")
 local cpoint, cto, crel, cx = changelog:GetPoint()
 equal(cpoint == "RIGHT" and cto == discord and crel == "LEFT" and cx, -8, "Changelog beside Discord")
 equal(discord:IsShown() and discord.label:GetText(), "Discord", "Discord shown in the footer")
 discord:Fire("OnEnter")
 equal(f.reloadHint:GetText(), "Found a bug or have an idea? Join the Discord.", "hovering Discord says what it's for, in the footer")
 discord:Fire("OnLeave")
 equal(f.reloadHint:GetText() ~= "Found a bug or have an idea? Join the Discord.", true, "and the hint comes back")
 local invited = 0; E.ShowDiscord = function() invited = invited + 1 end
 discord:Click(); SlashCmdList.ERAUI("discord")
 equal(invited, 2, "the button and /era discord give the invite")
 local notes = 0; E.ShowUpdateNotes = function() notes = notes + 1 end
 changelog:Click()
 equal(notes, 1, "Changelog opens the update notes")
 f:SetSetupMode(true); equal(discord:IsShown() or changelog:IsShown(), false, "hidden during guided setup")
 f:SetSetupMode(false); Flush(); equal(discord:IsShown() and changelog:IsShown(), true, "and back after it")
 -- More from Squirt: the cooldown manager, the cursor and the cooldown
 -- pulse, each a whole line, built the same way: Get it copies its
 -- CurseForge link, GitHub its repo, Open (once installed) runs its command.
 Open(f, "more")
 equal(Keys(f), "moreFECM,moreFEC,moreFECP", "More from Squirt lists the three addons, in order")
 M.NoOverlaps(f, "More from Squirt"); M.Fits(f, "More from Squirt")
 local ADDONS = {
  moreFECM = {"Forever Enhanced Cooldown Manager", "ForeverEnhancedCooldownManager", "FECM", "/ccm", "FECMIcon.tga",
   "https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-manager", "https://github.com/squirtwow/ForeverEnhancedCooldownManager",
   "Forever Enhanced Cooldown Manager  Cooldown, buff and cast bars round your Personal Resource Display, and a fresh look for Blizzard's Cooldown Manager."},
  moreFEC = {"Forever Enhanced Cursor", "ForeverEnhancedCursor", "FECURSOR", "/fec", "FECIcon.tga",
   "https://www.curseforge.com/wow/addons/forever-enhanced-cursor", "https://github.com/squirtwow/ForeverEnhancedCursor",
   "Forever Enhanced Cursor  Trail, rings and a marker for your cursor."},
  moreFECP = {"Forever Enhanced Cooldown Pulse", "ForeverEnhancedCooldownPulse", "FECP", "/fecp", "FECPIcon.tga",
   "https://www.curseforge.com/wow/addons/forever-enhanced-cooldown-pulse", "https://github.com/squirtwow/ForeverEnhancedCooldownPulse",
   "Forever Enhanced Cooldown Pulse  The cooldown pulse on its own."},
 }
 for key, want in pairs(ADDONS) do
  local more = f.checks[key]
  local name, folder, slash, command, icon, curseforge, github, help = want[1], want[2], want[3], want[4], want[5], want[6], want[7], want[8]
  equal(more.category == Tab(f, "more") and more.wide == true and more.text:GetText(), name, key .. " on More from Squirt, a whole line, named")
  equal(more.icon.texture, "Interface\\AddOns\\EraUI\\Media\\" .. icon, key .. " its own icon")
  local function Clear(label)
   for _, button in ipairs({more.open, more.getIt, more.github}) do
    if button:IsShown() then
     equal(more.text:GetRight() <= button:GetLeft() - 12 + .01 and more.state:GetRight() <= button:GetLeft() - 12 + .01, true,
      key .. " " .. label .. ": name and state end left of " .. button.label:GetText())
     equal(button:GetRight() <= more:GetRight() - 10 + .01, true, key .. " " .. label .. ": " .. button.label:GetText() .. " inside the row")
    end
   end
   equal(M.Glyphs(more.text:GetText(), 14) <= more.text:GetRight() - more.text:GetLeft(), true, key .. " " .. label .. ": the name fits")
   equal(M.Glyphs(more.state:GetText(), 11) <= more.state:GetRight() - more.state:GetLeft(), true, key .. " " .. label .. ": the state line fits")
  end
  more:SetChecked()
  Clear("not installed")
  equal(more.open:IsShown() == false and more.getIt:IsShown() and more.github:IsShown(), true, key .. " not installed: Get it and GitHub")
  equal(more.state:GetText(), "Get it on CurseForge or GitHub: click one for its link.", key .. " out now: where to get it")
  local copied
  local copy = E.Classic.CopyLink
  E.Classic.CopyLink = function(_, url) copied = url end
  more.getIt:Click()
  equal(copied, curseforge, key .. " Get it gives its CurseForge page to copy")
  more.github:Click()
  equal(copied, github, key .. " and GitHub its repo")
  E.Classic.CopyLink = copy
  local opened
  C_AddOns = {IsAddOnLoaded = function(addon) return addon == folder end}
  SlashCmdList[slash] = function(msg) opened = msg end
  more:SetChecked()
  Clear("installed")
  equal(more.open:IsShown() and not more.getIt:IsShown() and more.state:GetText(), "Installed. Type " .. command .. ", or click Open.", key .. " installed: an Open button")
  more.open:Click()
  equal(opened == "" and f:IsShown(), false, key .. " which runs its command, /era stepping aside")
  equal(opened, "", key .. " its command opened")
  C_AddOns = nil; SlashCmdList[slash] = nil
  f:Show(); Flush(); Open(f, "more")
  local _, help2, moreExtras = M.Hover(f, more)
  equal(help2 .. "|" .. moreExtras, help .. "|", key .. " its description in the footer, no default")
 end
 -- Options that need a Classic piece are greyed out and cannot be switched on.
 E.settings.portraitDebuffs = false
 f:RefreshDependencies()
 local portrait = f.checks.portraitDebuffs
 equal(portrait.dependencyDisabled, true, "portrait debuffs greyed out without Classic Unit Frames")
 portrait:Click(); Flush()
 equal(E.settings.portraitDebuffs, false, "a greyed-out option cannot be switched on")
 equal(f.checks.trainingGuide.dependencyDisabled and f.checks.spellbookCombatDrag.dependencyDisabled, true, "Training Guide and Combat Spell Dragging need the Classic Spellbook")
 equal(f.checks.vendorPrice.dependencyDisabled, nil, "ordinary QoL options are never greyed out")
 E.settings.unitFrames = true; f:RefreshDependencies()
 equal(portrait.dependencyDisabled, false, "available again with Classic Unit Frames")
 -- Class icon portraits: the game's own switches, mirrored on Frames & Nameplates > Unit Frames.
 do
  local cvars, refuse = {}, false
  local oldSet, oldBool, oldGet, oldPrint = SetCVar, GetCVarBool, E.GetSavedSetting, E.Print
  SetCVar = function(name, v) if refuse then return false end; cvars[name] = v; return true end
  GetCVarBool = function(name) return cvars[name] == "1" end
  E.GetSavedSetting = function(self, key)
   local cvar = self.cvarSettings[key]
   if cvar then return GetCVarBool ~= nil and GetCVarBool(cvar) and true or false end
   return self.settings[key]
  end
  local function Game(fields) return setmetatable(fields, {__newindex = function(_, k) error("wrote " .. tostring(k) .. " on a game frame") end}) end
  PlayerFrame = Game({portrait = {}, unit = "player"})
  TargetFrame = Game({portrait = {}, unit = "target", totFrame = Game({portrait = {}, unit = "targettarget"})})
  FocusFrame = Game({portrait = {}, unit = "focus", totFrame = Game({portrait = {}, unit = "focustarget"})})
  local party1, party2, bare = Game({portrait = {}, unit = "party1"}), Game({portrait = {}, unit = "party2"}), Game({unit = "party3"})
  local active = {[party1] = true, [party2] = true, [bare] = true}
  PartyFrame = Game({PartyMemberFramePool = Game({EnumerateActive = function() return pairs(active) end})})
  local all = {PlayerFrame, TargetFrame, FocusFrame, TargetFrame.totFrame, FocusFrame.totFrame, party1, party2}
  local redrawn, times, printed = {}, {}, {}
  UnitFramePortrait_Update = function(frame) redrawn[#redrawn + 1] = frame; times[frame] = (times[frame] or 0) + 1 end
  E.Print = function(_, m) printed[#printed + 1] = m end
  local function Reset() redrawn, times, printed = {}, {}, {} end
  for key, cvar in pairs({classIconPortraitMine = "ReplaceMyPlayerPortrait", classIconPortraitOthers = "ReplaceOtherPlayerPortraits"}) do
   local card = f.checks[key]
   equal(card.category == Tab(f, "frames") and card.subId == "unit" and card.dependencyDisabled ~= true, true, key .. " on Frames & Nameplates > Unit Frames, never greyed")
   cvars[cvar] = "0"; Reset(); card:SetChecked(false); card:Click(); Flush()
   equal(cvars[cvar] .. " " .. tostring(card:GetChecked()) .. " " .. #redrawn .. " " .. #printed, "1 true 7 0", key .. " on: the game's switch, the tick, every portrait redrawn")
   for _, frame in ipairs(all) do equal(times[frame], 1, key .. " on: the " .. frame.unit .. " portrait redrawn once") end
   equal(times[bare], nil, key .. " a frame without a portrait is left alone")
   Reset(); card:Click(); Flush()
   equal(cvars[cvar] .. " " .. tostring(card:GetChecked()) .. " " .. #redrawn, "0 false 7", key .. " and off again")
   refuse = true; Reset(); card:SetChecked(false); card:Click(); Flush(); refuse = false
   equal(cvars[cvar] .. " " .. tostring(card:GetChecked()) .. " " .. #redrawn, "0 false 0", key .. " refused: the tick goes back to the game's value")
   equal(printed[1], "The game kept its own portrait setting. Change it in Options > Interface.", key .. " refused: says where to change it")
   S.combat = true; Reset(); card:Click(); Flush(); S.combat = false
   equal(cvars[cvar] .. " " .. tostring(card:GetChecked()) .. " " .. #redrawn, "0 false 0", key .. " in combat: nothing changes")
   equal(printed[1], "Finish combat before changing portraits.", key .. " in combat: says why")
   Reset(); cvars[cvar] = "1"; f.cvarWatch:Fire("OnEvent", "CVAR_UPDATE", cvar, "1")
   equal(card:GetChecked(), true, key .. " follows the game's Options window on")
   cvars[cvar] = "0"; f.cvarWatch:Fire("OnEvent", "CVAR_UPDATE", string.lower(cvar), "0")
   equal(card:GetChecked() == false and #redrawn == 0, true, key .. " and off (any letter case), the game redrawing its own change")
   S.combat = true; cvars[cvar] = "1"; f.cvarWatch:Fire("OnEvent", "CVAR_UPDATE", cvar, "1"); S.combat = false
   equal(card:GetChecked() == true and #redrawn == 0, true, key .. " follows in combat too (only the tick changes)")
   f:Hide(); cvars[cvar] = "0"; f:Show(); Flush()
   equal(card:GetChecked(), false, key .. " reopening /era shows the game's value")
  end
  local mine, others = f.checks.classIconPortraitMine, f.checks.classIconPortraitOthers
  cvars.ReplaceMyPlayerPortrait = "1"; f.cvarWatch:Fire("OnEvent", "CVAR_UPDATE", "ReplaceOtherPlayerPortraits", "0")
  equal(tostring(mine:GetChecked()) .. " " .. tostring(others:GetChecked()), "false false", "one switch's change leaves the other row alone")
  f.cvarWatch:Fire("OnEvent", "CVAR_UPDATE", "chatBubbles", "1"); f.cvarWatch:Fire("OnEvent", "CVAR_UPDATE", nil, nil)
  equal(mine:GetChecked(), false, "another setting's change, or none, leaves the rows alone")
  cvars.ReplaceMyPlayerPortrait = "0"
  UnitFramePortrait_Update = function(frame) if frame == TargetFrame then error("no unit") end; redrawn[#redrawn + 1] = frame end
  Reset(); mine:Click(); Flush()
  equal(#redrawn .. " " .. tostring(mine:GetChecked()) .. " " .. cvars.ReplaceMyPlayerPortrait, "6 true 1", "one portrait failing: the rest are redrawn, the switch flips")
  UnitFramePortrait_Update = nil
  Reset(); mine:Click(); Flush()
  equal(cvars.ReplaceMyPlayerPortrait .. " " .. tostring(mine:GetChecked()) .. " " .. #printed, "0 false 0", "no portrait function: the switch still flips")
  SetCVar = function() error("no such cvar") end
  Reset(); mine:Click(); Flush()
  equal(tostring(mine:GetChecked()) .. " " .. tostring(printed[1]), "false This game version doesn't have that portrait setting.", "a game without the setting: the tick goes back and says so")
  SetCVar = function(name, v) cvars[name] = v; return true end; GetCVarBool = nil
  Reset(); mine:Click(); Flush()
  equal(tostring(mine:GetChecked()) .. " " .. tostring(printed[1]), "false This game version doesn't have that portrait setting.", "a game that can't read it back")
  local writes = 0
  SetCVar = function() writes = writes + 1 end
  GetCVarBool = function() return nil end
  Reset(); mine:Click(); Flush()
  equal(tostring(mine:GetChecked()) .. " " .. tostring(printed[1]), "false This game version doesn't have that portrait setting.", "a game without the switch (nothing back)")
  local oldCVar2 = C_CVar
  SetCVar = function(name, v) writes = writes + 1; cvars[name] = v; return true end
  GetCVarBool = function(name) return cvars[name] == "1" end
  UnitFramePortrait_Update = function(frame) redrawn[#redrawn + 1] = frame end
  local info = {}
  C_CVar = {GetCVarInfo = function(name)
   local i = info[name]
   if i == "error" then error("no info") end
   if i then return cvars[name], "0", false, false, i.locked or false, i.secure or false, i.readOnly or false end
  end}
  local switches = {classIconPortraitMine = "ReplaceMyPlayerPortrait", classIconPortraitOthers = "ReplaceOtherPlayerPortraits"}
  for _, kind in ipairs({"secure", "readOnly"}) do
   for key, cvar in pairs(switches) do
    local card = f.checks[key]
    cvars[cvar] = "0"; info[cvar] = {[kind] = true}; writes = 0; Reset(); card:SetChecked(false); card:Click(); Flush()
    equal(writes .. " " .. cvars[cvar] .. " " .. tostring(card:GetChecked()) .. " " .. #redrawn, "0 0 false 0", key .. " " .. kind .. ": nothing written or redrawn, the tick goes back")
    equal(printed[1], "Only Options > Interface can change this portrait setting.", key .. " " .. kind .. ": says where to change it")
   end
  end
  for _, state in ipairs({{}, "error"}) do
   for key, cvar in pairs(switches) do
    local card = f.checks[key]
    cvars[cvar] = "0"; info[cvar] = state; writes = 0; Reset(); card:SetChecked(false); card:Click(); Flush()
    equal(writes .. " " .. cvars[cvar] .. " " .. tostring(card:GetChecked()) .. " " .. #redrawn .. " " .. #printed, "1 1 true 7 0",
     key .. " " .. (state == "error" and "details unreadable" or "open switch") .. ": flips and redraws")
   end
  end
  C_CVar = oldCVar2
  SetCVar, GetCVarBool, E.GetSavedSetting, E.Print = oldSet, oldBool, oldGet, oldPrint
  PlayerFrame, TargetFrame, FocusFrame, PartyFrame, UnitFramePortrait_Update = nil, nil, nil, nil, nil
 end
 -- Other Windows: the windows without a switch of their own follow it.
 local function Window(name) return {GetName = function() return name end} end
 local allowed = E.Classic.WindowAllowed
 E.settings.otherWindows = false; E.settings.merchantSkin = true
 equal(allowed(Window("TradeFrame")) or allowed(Window(nil)), false, "Other Windows off: trade and unnamed extra windows stay modern")
 equal(allowed(Window("MerchantFrame")), true, "windows with their own switch ignore Other Windows")
 E.settings.otherWindows = true
 equal(allowed(Window("TaxiFrame")), true, "Other Windows on: taxi window skinned")
 E.settings.merchantSkin = false
 equal(allowed(Window("MerchantFrame")), false, "merchant still follows its own switch")
 equal(f.checks.otherWindows ~= nil, true, "Other Windows has an /era row")
 -- A Custom look selects no preset; a preset click re-syncs every tick.
 for _, key in ipairs(P.LOOK) do E.settings[key] = true end
 E.settings.minimap = false
 f:SetSetupMode(true); Flush()
 equal(choices[1].tag:IsShown() or choices[2].tag:IsShown() or choices[3].tag:IsShown(), false, "Custom look: no preset pre-selected")
 E.settings.classColourBorders = true; f.checks.classColourBorders:SetChecked(true)
 choices[3]:Click(); Flush()
 choices[1]:Click(); Flush()
 equal(E.settings.classColourBorders == false and f.checks.classColourBorders:GetChecked() == false, true, "Quality of Life only switched the optional look off, and its tick shows it")
 equal(f.checks.bagItemLevels:GetChecked(), false, "a preset click leaves Bag Item Levels off: neither preset touches it")
 f:SetSetupMode(false); Flush()
end

-- The map: groups, tabs, sub-tabs, sections and rows exactly as approved;
-- every option on exactly one sub-page; sub-options after their parent,
-- indented with their line; folds; which pages scroll.
do
 local E, f = Session("DRUID")
 -- The cursor effects' folded options open, so every row shows.
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = true, true, true
 equal(#f.groupHeadings, 4, "four groups")
 local icons, abouts, index = {}, {}, 0
 for g, group in ipairs(EXPECTED) do
  local heading = f.groupHeadings[g]
  equal(heading:GetText(), group.group, "group " .. g .. " heading")
  equal(heading.colour and Colour(heading.colour), "0.370,0.410,0.450", group.group .. " heading muted")
  for _, want in ipairs(group.tabs) do
   index = index + 1
   local id, tab = want[1], f.tabs[index]
   equal(tab.id, id, "tab " .. index .. " is " .. id)
   equal(Tab(f, id), index, id .. " found by its id")
   equal(tab.text:GetText(), want[2] or "DRUID", id .. " tab name")
   equal(f.categories[index].group, g, id .. " in " .. group.group)
   equal(tab:GetTop() <= heading:GetBottom() + .01, true, id .. " under its group's heading")
   if f.groupHeadings[g + 1] then equal(tab:GetBottom() >= f.groupHeadings[g + 1]:GetTop() - .01, true, id .. " above the next group's heading") end
   equal(type(tab.icon.texture) == "string" and icons[tab.icon.texture] == nil, true, id .. " has its own icon")
   icons[tab.icon.texture] = true
   Open(f, id)
   equal(f.sectionTitle:GetText(), tab.text:GetText(), id .. " title")
   local about = f.sectionAbout:GetText()
   equal(about, want[3], id .. " description")
   equal(#about * 6 <= 560 and about:sub(-1) == "." and not Has(about, EM), true, id .. " description on one line, ending with a full stop")
   equal(abouts[about], nil, id .. " description is its own"); abouts[about] = true
   equal(f.sectionAbout:GetTop() <= f.sectionTitle:GetBottom() + .01, true, id .. " description under the title")
   if want[4] then
    local subs = f.categories[index].subs
    local hasSubs = #want[4] > 1
    equal(f.categories[index].hasSubs, hasSubs, id .. (hasSubs and " has sub-tabs" or " has no sub-tabs"))
    equal(f.subTabStrip:IsShown(), hasSubs, id .. " sub-tab strip shown only with sub-tabs")
    equal(f.settingsScroll:GetTop() <= (hasSubs and f.subTabStrip:GetBottom() or f.sectionAbout:GetBottom()) + .01, true, id .. " rows start under the header")
    for s, sub in ipairs(want[4]) do
     equal(subs[s].id, sub[1], id .. " sub-page " .. s)
     if hasSubs then
      equal(f.subTabs[s]:IsShown() and f.subTabs[s].label:GetText(), sub[2], id .. " sub-tab " .. s .. " name")
      f.subTabs[s]:Click(); Flush()
      equal(f.selectedSub[index] == sub[1] and f.subTabs[s].selected and f.subTabs[s].top:IsShown(), true, id .. " " .. sub[1] .. " selected, its class-colour line on")
     end
     local parts = {}
     for i, section in ipairs(sub[3]) do parts[i] = section[1] .. ":" .. table.concat(section[2], ",") end
     equal(PageText(f), table.concat(parts, "|"), id .. " > " .. sub[1] .. " sections and rows, in order")
     equal(table.concat(f.pages[id][sub[1]], ","), table.concat((function() local all = {}; for _, section in ipairs(sub[3]) do for _, k in ipairs(section[2]) do all[#all + 1] = k end end; return all end)(), ","),
      id .. " > " .. sub[1] .. " page list")
     for _, fs in ipairs(f.headingPool) do
      if fs:IsShown() then equal(fs:GetText() == fs:GetText():upper() and Colour(fs.colour), "0.930,0.750,0.320", id .. " heading " .. fs:GetText() .. " in gold capitals") end
     end
     M.NoOverlaps(f, id .. " > " .. sub[1])
     M.Fits(f, id .. " > " .. sub[1])
     -- None of the topic pages scrolls at the default size with folds closed.
     equal(f.settingsContent:GetHeight() <= f.settingsScroll:GetHeight() + .01 and not f.settingsScrollHint:IsShown(), true, id .. " > " .. sub[1] .. " fits without scrolling")
    end
   end
  end
 end
 equal(index, #f.tabs, "every tab checked")
 equal(#f.tabs, 14, "fourteen tabs")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = nil, nil, nil
 -- The class tab, per class (its page above); here its place and name.
 equal(Tab(f, "class") .. "," .. Tab(f, "casting"), "6,7", "your class is the sixth tab and Casting the seventh")
 -- Every option is on exactly one sub-page.
 local seen = {}
 for id, subs in pairs(f.pages) do
  for sub, list in pairs(subs) do
   for _, key in ipairs(list) do
    equal(seen[key], nil, key .. " listed once")
    seen[key] = id .. " > " .. sub
    equal(f.checks[key] ~= nil and f.rowHome[key].sub, sub, key .. " knows its sub-page")
   end
  end
 end
 for key in pairs(f.checks) do equal(seen[key] ~= nil, true, key .. " is on a sub-page") end
 equal(f.checks.searchOnly, nil, "no search-only option")
 -- Each sub-option on its parent's sub-page.
 for key, parent in pairs(PARENT) do
  if f.checks[key] and f.checks[parent] then
   equal(seen[key], seen[parent], key .. " on its parent's sub-page")
  end
 end
 equal(seen.classColourBorders .. " / " .. seen.appearanceChoice, "appearance > classcol / appearance > style", "Class-coloured Unit Borders' switches live elsewhere on purpose")
 -- Sub-options right after their parent, indented with their line, on
 -- every sub-page, with every fold open.
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail, E.settings.afkScreen = true, true, true, true
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = true, true, true
 for i, cat in ipairs(f.categories) do
  for _, sub in ipairs(cat.subs) do
   f:SelectCategory(i, sub.id); Flush()
   M.SubOptionsFollow(f, cat.id .. " > " .. sub.id, ParentOf(E))
   M.NoOverlaps(f, cat.id .. " > " .. sub.id .. " with folds open")
   M.Fits(f, cat.id .. " > " .. sub.id .. " with folds open")
  end
 end
 -- Not indented: options whose mockup parent is no real dependency.
 for _, key in ipairs({"cleanMinimap", "characterItemLevels", "classColourBorders", "darkAuraBorders", "darkMenuBar", "darkWindows"}) do
  equal(f.checks[key].depth or 0, 0, key .. " not indented")
 end
 Open(f, "class")
 equal(f.checks.comboPointRed.depth == 1 and f.checks.comboPointRed.connV:IsShown(), true, "Red Combo Points sits under Floating Combo Points")
 E.settings.floatingComboPoints = false; f:RefreshDependencies()
 equal(f.checks.comboPointRed.dependencyDisabled, nil, "but is never greyed by it")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail, E.settings.afkScreen = nil, nil, nil, nil
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = nil, nil, nil
 -- Folds: hidden (not greyed) until their switch is on, open right after it
 -- at once keeping the scroll, and fold away again.
 local height = f:GetHeight()
 -- A shorter window, with the other effects open, so the page can scroll.
 M.Resize(f, 420)
 for parent, kids in pairs(FOLDED) do
  for other in pairs(FOLDED) do E.settings[other] = other ~= parent end
  Open(f, "screen", "cursor")
  for _, kid in ipairs(kids) do equal(f.checks[kid]:IsShown(), false, kid .. " folded away while " .. parent .. " is off") end
  equal(f.checks[parent]:IsShown(), true, parent .. " itself shows")
  f:SetSettingsScroll(20)
  equal(f.settingsScroll:GetVerticalScroll(), 20, parent .. " page scrolled a little")
  local card = f.checks[parent]
  card:Click(); Flush()
  equal(E.settings[parent], true, parent .. " switched on")
  local order, at = M.Keys(f)
  for i, key in ipairs(order) do if key == parent then at = i end end
  for n, kid in ipairs(kids) do
   equal(order[at + n], kid, kid .. " opens right after " .. parent .. " at once")
   equal(f.checks[kid].dependencyDisabled, nil, kid .. " is folded, never greyed")
  end
  equal(f.settingsScroll:GetVerticalScroll(), 20, parent .. " opening keeps the scroll")
  M.NoOverlaps(f, parent .. " open")
  M.SubOptionsFollow(f, parent .. " open alone", ParentOf(E))
  card:Click(); Flush()
  equal(E.settings[parent], false, parent .. " switched off")
  for _, kid in ipairs(kids) do equal(f.checks[kid]:IsShown(), false, kid .. " folds away again") end
 end
 for other in pairs(FOLDED) do E.settings[other] = nil end
 M.Resize(f, height)
 -- The AFK Screen's options are not folded: shown, greyed, while it is off.
 E.settings.afkScreen = false; Open(f, "screen", "afk")
 equal(f.checks.afkZoom:IsShown() and f.checks.afkZoom.dependencyDisabled, true, "the AFK Screen's options stay open, greyed while it is off")
 E.settings.afkScreen = nil
 -- Every sub-page with every fold open: which ones scroll (measured).
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail, E.settings.afkScreen = true, true, true, true
 local scrolls = {}
 for i, cat in ipairs(f.categories) do
  for _, sub in ipairs(cat.subs) do
   f:SelectCategory(i, sub.id); Flush()
   if f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + .01 then scrolls[#scrolls + 1] = cat.id .. ">" .. sub.id end
   equal(f.settingsScrollHint:IsShown(), f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + 1, cat.id .. " > " .. sub.id .. " scroll hint only when it scrolls")
  end
 end
 equal(table.concat(scrolls, ","), "", "no page scrolls at the default size, every fold open (the class tab's boxes are checked per class)")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail, E.settings.afkScreen = nil, nil, nil, nil
 -- The viewport is pinned by two corners and sized; its content too.
 equal(#f.settingsScroll.points, 2, "the viewport is pinned by two corners")
 equal(f.settingsScroll:GetWidth() > 0 and f.settingsScroll:GetHeight() > 0 and f.settingsContent:GetWidth() > 0, true, "it and its content have a size")
end

-- The class tab, per class: sections and rows, indents, no overlaps.
for _, c in ipairs(CLASSES) do
 local E, f = Session(c)
 Open(f, "class")
 equal(PageText(f), CLASS_PAGE[c], c .. " class tab")
 if c == "ROGUE" or c == "DRUID" then
  equal(f.checks.comboPointRed.depth == 1 and math.abs(f.checks.comboPointRed:GetLeft() - f.checks.floatingComboPoints:GetLeft() - 22) < .01, true, c .. " Red Combo Points indented under Floating Combo Points")
 end
 equal(f.checks.classReminders.wide and math.abs(f.checks.classReminders:GetWidth() - 718) < .01, true, c .. " Class Reminders & Buffs takes the whole line")
 local tools = f.checks.classTools
 if c == "ROGUE" then
  equal(tools.rowKind == "link" and tools.text:GetText(), "Configure ROGUE Tools", "the rogue's tools open in their own window, a link row")
 elseif c == "HUNTER" or c == "MAGE" then
  equal(tools.rowKind == "heading" and tools.text:GetText(), c == "HUNTER" and "Pet Feeding Options" or "Conjuring & Trade Options", c .. " tools heading")
 else
  equal(tools.classAllowed, false, c .. " no tools row (its controls are under Class Reminders & Buffs)")
 end
end

-- Greying chains: Class-coloured Unit Borders needs Dark Mode and Unit
-- Frames, and every greyed row's footer names its switch by its row's
-- label, with where it is when that's another sub-page.
do
 local E, f = Session("HUNTER")
 local card = f.checks.classColourBorders
 Open(f, "appearance", "classcol")
 E.settings.darkMode = nil; E.settings.unitFrames = true; f:RefreshDependencies()
 equal(card.dependencyDisabled == true and card.alpha == .45, true, "Class-coloured Unit Borders greyed without Dark Mode, even with Unit Frames")
 local _, _, extras = M.Hover(f, card)
 equal(extras, "Switch on Dark Mode first (Appearance > Style).  Default: Off.", "it names Dark Mode and where it is")
 card:SetChecked(true); card:Fire("OnClick")
 equal(E.settings.classColourBorders, nil, "and it can't be switched on")
 E.settings.darkMode = true; E.settings.unitFrames = false; f:RefreshDependencies()
 _, _, extras = M.Hover(f, card)
 equal(extras, "Switch on Unit Frames first (Frames & Nameplates > Unit Frames).  Default: Off.", "then Unit Frames, and where it is")
 equal(card.summary, "Class-coloured unit frame borders. Needs Dark Mode and Unit Frames.", "its summary names both")
 local names = {}
 for key, row in pairs(f.checks) do if row.labelText then names[row.labelText] = key end end
 names["Dark Mode"] = "appearanceChoice"
 E.settings.unitFrames, E.settings.spellbook, E.settings.actionBars, E.settings.advancedCastBar = false, false, false, false
 E.settings.afkScreen, E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = false, true, false, false
 f:RefreshDependencies()
 local named = 0
 for key, row in pairs(f.checks) do
  if row.dependencyDisabled then
   local _, _, text = M.Hover(f, row)
   local name, where = text:match("^Switch on (.-) first %((.-)%)%.")
   name = name or text:match("^Switch on (.-) first%.")
   local owner = name and f.checks[names[name]]
   equal(owner ~= nil, true, key .. " names a row: " .. text)
   local home, mine = f.rowHome[owner.settingKey], f.rowHome[key]
   local elsewhere = home.tab ~= mine.tab or home.sub ~= mine.sub
   equal(where, elsewhere and E.SettingsNav.Crumb(f, home) or nil, key .. " gives the place only when it is elsewhere")
   named = named + 1
  end
 end
 equal(named >= 20, true, "every greyed row checked (" .. named .. ")")
 E.settings.unitFrames, E.settings.spellbook, E.settings.actionBars, E.settings.advancedCastBar = nil, nil, nil, nil
 E.settings.afkScreen, E.settings.darkAuraBorders, E.settings.darkWindows = nil, nil, nil
 E.settings.darkMode = nil; f:RefreshDependencies()
 _, _, extras = M.Hover(f, card)
 equal(Has(extras, "Switch on Dark Mode first"), true, "with both off, Dark Mode first")
 local _, help = M.Hover(f, card)
 equal(Has(help, "Needs Dark Mode and Unit Frames."), true, "its help names both")
 E.settings.darkMode = true; E.settings.unitFrames = true; f:RefreshDependencies()
 equal(card.dependencyDisabled == false and card.alpha == 1, true, "available with Dark Mode and Unit Frames")
 card:SetChecked(false); card:Click()
 equal(E.settings.classColourBorders, true, "and it switches on")
 E.settings.darkMode = nil; E.settings.classColourBorders = nil; f:RefreshDependencies()
 equal(card.dependencyDisabled, true, "greyed again without Dark Mode")
 Open(f, "appearance", "style")
 f.appearanceChoices[2]:Click()
 equal(card.dependencyDisabled, false, "choosing Dark Mode frees it at once")
end

-- Hand-overs: Forever Enhanced Nameplates takes the nameplate rows, another
-- map addon revealing the map takes Reveal World Map: greyed, a note on the
-- row, the help word for word in the footer, a click changes nothing, the
-- saved choice is kept; without them, the rows exactly as before.
do
 local E, f = Session("ROGUE", nil, nil, nil, function(E) assert(loadfile("Core/Utils.lua"))("EraUI", E) end)
 local friendly, enemy = f.checks.friendlyNameplates, f.checks.enemyNameplates
 local function Reopen() f:Hide(); f:Show(); Flush() end
 local function State(card)
  return tostring(card.handedOver) .. " " .. tostring(card.alpha) .. " " .. tostring(card.note:IsShown()) .. " " .. string.format("%d", card:GetHeight())
 end
 E.settings.friendlyNameplates = true; E.settings.enemyNameplates = false
 Reopen()
 equal(State(friendly) .. " / " .. State(enemy), "nil 1 false 32 / nil 1 false 32", "no Forever Enhanced Nameplates: the nameplate rows as before, never touched")
 for state, api in pairs({none = false, other = {IsAddOnLoaded = function(name) return name == "ForeverEnhancedCooldownManager" end},
  installedOff = {IsAddOnLoaded = function() return false end}}) do
  C_AddOns = api or nil; Reopen()
  equal(State(friendly) .. " / " .. State(enemy), "nil 1 false 32 / nil 1 false 32", state .. ": the nameplate rows as before")
 end
 C_AddOns = {IsAddOnLoaded = function(name) return name == "ForeverEnhancedNameplates" end}
 Reopen(); Open(f, "frames", "plates")
 M.NoOverlaps(f, "handed over nameplates")
 local saved = {friendlyNameplates = true, enemyNameplates = false}
 for key, card in pairs({friendlyNameplates = friendly, enemyNameplates = enemy}) do
  equal(card.handedOver == true and card.alpha == .45 and card:IsShown(), true, key .. " greyed, shown, while Forever Enhanced Nameplates is loaded")
  equal(card.note:IsShown() and N(card:GetHeight()), "46", key .. " with its note on a second line")
  card:SetChecked(not saved[key]); card:Fire("OnClick"); Flush()
  equal(E.settings[key] == saved[key] and card:GetChecked() == saved[key], true, key .. " a click changes nothing and keeps its tick")
  local text, _, extras = M.Hover(f, card)
  equal(extras, "Forever Enhanced Nameplates is on and handles nameplates, so EraUI leaves them alone. Your choice here is kept for when it's off.",
   key .. " footer says who handles nameplates now, word for word, nothing else")
  equal(Has(text, "Switch on") or Has(text, EM), false, key .. " no parent option named, no em dash")
  equal(M.Glyphs(card.note:GetText(), 11) <= card.note:GetRight() - card.note:GetLeft(), true, key .. " note fits its line (11 point, the glyph widths)")
  equal(N(card.note:GetLeft() - card:GetLeft()) .. " " .. N(card:GetRight() - card.note:GetRight()), "10 10", key .. " note runs from under the tick box to 10 from the end")
  equal(card.tagBox:GetBottom() >= card.note:GetTop() - .01, true, key .. " its labels stay above the note")
  local _, boxY = card.tickBox:GetCenter()
  local _, textY = card.text:GetCenter()
  equal(N(boxY - textY), "0", key .. " its tick box shares the name's line")
  equal(card.tickBox:GetBottom() >= card.note:GetTop() - .01, true, key .. " its tick box stays above the note")
 end
 equal(friendly.note:GetText() .. " / " .. enemy.note:GetText(), "Forever Enhanced Nameplates handles friendly plates. / Forever Enhanced Nameplates handles enemy plates.", "the notes say who handles them")
 equal(f.checks.unitFrames.handedOver == nil and f.checks.portraitDebuffs.handedOver == nil and f.checks.revealMap.handedOver == nil, true, "the other rows are left alone")
 C_AddOns = nil; Reopen()
 equal(State(friendly) .. " / " .. State(enemy), "false 1 false 32 / false 1 false 32", "handed back: the rows as before")
 friendly:Click(); Flush()
 equal(E.settings.friendlyNameplates, false, "handed back: the row switches again")
 -- Reveal World Map.
 local card = f.checks.revealMap
 E.settings.revealMap = true; MAUTTAB = nil
 Reopen()
 equal(State(card), "nil 1 false 32", "no other map addon: Reveal World Map as before")
 C_AddOns = {IsAddOnLoaded = function(name) return name == "MapUtils" end}; MAUTTAB = {REVEALMAP = false}
 Reopen()
 equal(State(card), "nil 1 false 32", "another map addon with its reveal off: as before")
 MAUTTAB = nil; Reopen(); Open(f, "map")
 M.NoOverlaps(f, "handed over Map & Minimap")
 equal(card.handedOver == true and card.alpha == .45 and card.note:GetText(), "Another map addon is showing the unexplored areas.", "greyed, with its note, without naming the addon")
 equal(M.Glyphs(card.note:GetText(), 11) <= card.note:GetRight() - card.note:GetLeft(), true, "its note fits its line (11 point, the glyph widths)")
 local _, boxY = card.tickBox:GetCenter()
 local _, textY = card.text:GetCenter()
 equal(N(boxY - textY) .. " " .. tostring(card.tickBox:GetBottom() >= card.note:GetTop() - .01), "0 true", "its tick box on the name's line, above the note")
 card:SetChecked(false); card:Fire("OnClick"); Flush()
 equal(E.settings.revealMap == true and card:GetChecked() == true, true, "a click changes nothing")
 local text, _, extras = M.Hover(f, card)
 equal(extras, "Another map addon already shows the unexplored areas, so EraUI leaves the map alone. Your choice is kept for when it stops.", "footer says why")
 equal(M.LinesIn(extras, 466, 12) .. " " .. M.LinesIn(extras, 570, 12), "2 2", "two lines in setup's footer (466) and the page's (570)")
 equal(Has(text, "Switch on") or Has(text, EM), false, "no parent option named, no em dash")
 equal(f.checks.movableMap.handedOver == nil and f.checks.friendlyNameplates.handedOver == false, true, "the other rows are left alone")
 C_AddOns = nil; Reopen()
 equal(State(card), "false 1 false 32", "handed back: as before")
 local _, rowY = card:GetCenter()
 boxY = select(2, card.tickBox:GetCenter())
 equal(N(boxY - rowY), "0", "handed back: its tick box centred on the row again")
 card:Click(); Flush()
 equal(E.settings.revealMap, false, "handed back: it switches again")
end

-- Search: every option, folded ones too, on its name, summary, old names,
-- tab and sub-tab names, colour/color and grey/gray either way; results are
-- rows with where they live, in tab then page order; a click goes there.
do
 local E, f = Session("DRUID")
 local function Results(q) local keys, crumbs = M.Results(f, q); return table.concat(keys, ","), crumbs end
 local colours = "darkenClassColours,classColors,tooltipClassColours,classColourBorders,castBarClassBorder,advancedCastClassFill,cursorRingClassColour,cursorCastClassColour,cursorTrailClassColour"
 Open(f, "map")
 equal(Results("class colour"), colours, "class colour finds every class-colour option, in tab then page order")
 equal(Results("class color"), colours, "and so does class color")
 equal(Results("Class Colored"), colours, "and class colored")
 equal(f.sectionTitle:GetText() .. " / " .. f.sectionAbout:GetText(), "Search / 9 options found. Click one to go to it.", "search says how many and what a click does")
 equal(f.subTabStrip:IsShown(), false, "no sub-tabs in search")
 for _, tab in ipairs(f.tabs) do equal(tab.underline:IsShown(), false, tab.id .. " not highlighted in search") end
 local _, crumbs = Results("class colour")
 equal(crumbs[1] .. "|" .. crumbs[2] .. "|" .. crumbs[6] .. "|" .. crumbs[9], "Appearance > Dark Mode|Appearance > Class Colours|Casting|Screen & Cursor > Cursor", "each result says where it lives")
 for i, result in ipairs(f.visibleRows) do
  equal(result.isResult and result:GetHeight() == 40 and result.text:GetText() == result.target.labelText, true, "result " .. i .. " a row with the option's name")
  equal(not Has(result.crumb:GetText(), EM) and Colour(result.crumb.colour), "0.440,0.480,0.530", "result " .. i .. " breadcrumb small and grey, no em dash")
 end
 M.NoOverlaps(f, "class colour results"); M.Fits(f, "class colour results")
 equal(f.visibleRows[1]:GetLeft() < f.visibleRows[2]:GetLeft() and f.visibleRows[1]:GetTop() == f.visibleRows[2]:GetTop(), true, "two results to a line")
 local grey, gray = Results("grey"), Results("gray")
 equal(#grey > 0 and grey == gray and Has(grey, "autoSellJunk") and Has(grey, "revealMap"), true, "grey and gray find the same, such as Auto-sell Junk and Reveal World Map")
 equal(Results("1 options found"), "", "no option matches nonsense")
 equal(f.sectionAbout:GetText(), "No options found.", "and it says so")
 equal(Results("tooltip ids"), "tooltipIDs", "one result")
 equal(f.sectionAbout:GetText(), "1 option found. Click it to go to it.", "one result reads right")
 f.searchBox:SetText(""); Flush()
 equal(f.sectionTitle:GetText() .. " " .. tostring(f.searching), "Map & Minimap false", "clearing search goes back to the page")
 for _, result in ipairs(f.results) do equal(result:IsShown(), false, "pages show no results") end
 equal(Results("dark mode"):match("^[^,]+"), "appearanceChoice", "dark mode finds the Classic / Dark Mode choice first")
 equal(Results("update notice"), "updateCheck", "search finds Update Notice")
 _, crumbs = Results("update notice")
 equal(crumbs[1], "Chat & Names", "on Chat & Names")
 equal(Has(Results("cast bar"), "moreFECM"), true, "cast bar finds More from Squirt")
 equal(Results("casting"), "castBars,advancedCastBar,advancedCastClassFill,advancedCastTicks,advancedCastLatency", "casting finds the Casting tab")
 -- A broad search lists every result in one scrolling list.
 local broad = Results("e")
 local count = select(2, broad:gsub(",", ",")) + 1
 equal(count > 60 and #f.visibleRows == count, true, "a broad search lists every result (" .. count .. ")")
 equal(f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() and f.settingsScrollHint:IsShown(), true, "and scrolls, with the hint")
 M.NoOverlaps(f, "broad search"); M.Fits(f, "broad search")
 for key, card in pairs(f.checks) do
  equal(card:IsShown(), false, "no row shows in search: " .. key)
  if card.inlinePanel then equal(card.inlinePanel:IsShown(), false, "no options box in search: " .. key) end
 end
 f:SetSettingsScroll(99999)
 local last = f.visibleRows[#f.visibleRows]
 equal(last:GetBottom() >= f.settingsScroll:GetBottom() - .01, true, "the last result scrolls into view")
 f.searchBox:SetText(""); Flush()
 -- Tab and sub-tab names find their options.
 local function PageKeys(id)
  local out = {}
  for _, list in pairs(f.pages[id]) do for _, key in ipairs(list) do if f.checks[key].classAllowed ~= false then out[#out + 1] = key end end end
  table.sort(out); return table.concat(out, ",")
 end
 local function Sorted(q) local keys = M.Results(f, q); table.sort(keys); return table.concat(keys, ",") end
 for query, id in pairs({vendors = "bags", ["group invites"] = "group", druid = "class", nameplates = "frames"}) do
  equal(Sorted(query), PageKeys(id), "searching \"" .. query .. "\" finds the whole " .. id .. " tab")
 end
 local dark = Sorted("dark mode")
 for _, key in ipairs(f.pages.appearance.dark) do equal(Has(dark, key), true, "the sub-tab name dark mode finds " .. key) end
 local unit = Sorted("unit frames")
 for _, key in ipairs(f.pages.frames.unit) do equal(Has(unit, key), true, "the sub-tab name unit frames finds " .. key) end
 equal(Has(unit, "friendlyNameplates") or Has(unit, "enemyNameplates"), false, "but not the Nameplates sub-tab's options")
 -- Old names still find the renamed options.
 for old, key in pairs({["Character / Reputation / Skills"] = "characterPanel", ["reputation"] = "characterPanel", ["Bags / Bank"] = "bagsBank",
  ["Friends / Guild"] = "socialWindows", ["Group Finder / PvP"] = "groupFinderPvp", ["Blizzard Settings Skin"] = "blizzardSettings",
  ["Hide Secondary Names"] = "hideSecondaryNames", ["Class Colours in Chat"] = "classColors", ["Faster Auto Loot"] = "fastAutoLoot",
  ["Auto Gossip"] = "autoGossip", ["Discard Cheapest Junk When Bags Are Full"] = "discardCheapestJunk",
  ["AFK Camera: Normal Speed"] = "afkCameraNormal", ["normal speed"] = "afkCameraNormal", ["AFK Camera: Circle Right"] = "afkTurnRight",
  ["AFK Camera: Zoom In"] = "afkZoom", ["Class-coloured Fill"] = "advancedCastClassFill", ["Custom cast-ring colour"] = "cursorCastColour",
  ["Loot"] = "lootWindow", ["AFK Screen: Faster Camera"] = "afkCameraNormal", ["AFK Screen: Class Quote"] = "afkShowQuote",
  ["AFK Screen: 24-Hour Clock"] = "afk24Hour", ["AFK Screen: Show Guild"] = "afkShowGuild", ["AFK Screen: Show Zone"] = "afkShowZone",
  ["AFK Screen: Show Date"] = "afkShowDate", ["AFK Screen: Circle Right"] = "afkTurnRight", ["AFK Screen: Zoom In"] = "afkZoom",
  ["Aura Shadows (Needs testing)"] = "darkAuraShadows"}) do
  equal(Has(Results(old), key), true, "the old name \"" .. old .. "\" finds " .. key)
 end
 -- A folded option is found, and a click goes to its switch, which flashes.
 E.settings.cursorTrail = nil
 local found, folded = Results("trail opacity")
 equal(found .. " " .. folded[1], "cursorTrailOpacity Screen & Cursor > Cursor", "search finds a folded option, and where")
 local before = {}
 for k, v in pairs(E.settings) do before[k] = v end
 f.visibleRows[1]:Click()
 equal(f.selectedCategory .. " " .. f.selectedSub[f.selectedCategory] .. " " .. f.searchBox:GetText() .. f.sectionTitle:GetText(), Tab(f, "screen") .. " cursor Screen & Cursor",
  "a folded option's result opens Screen & Cursor > Cursor and leaves search")
 equal(f.checks.cursorTrailOpacity:IsShown() == false and f.checks.cursorTrail.flashing == true, true, "it stays folded; its switch flashes")
 equal(Colour(f.checks.cursorTrail.borderColour), Colour({1, .49, .04}), "in the class colour")
 Flush()
 equal(f.checks.cursorTrail.flashing, false, "the flash fades")
 for k, v in pairs(before) do equal(E.settings[k], v, "a jump changes no setting: " .. k) end
 for k in pairs(E.settings) do equal(before[k] ~= nil, true, "a jump adds no setting: " .. k) end
 -- A jump centres its row (or scrolls as far as it goes).
 local height = f:GetHeight()
 M.Resize(f, 330)
 Results("release in battlegrounds")
 f.visibleRows[1]:Click(); Flush()
 local row = f.checks.releasePvP
 local centre = (f.settingsScroll:GetTop() + f.settingsScroll:GetBottom()) / 2
 local range = f.settingsContent:GetHeight() - f.settingsScroll:GetHeight()
 equal(row:IsShown() and (math.abs((row:GetTop() + row:GetBottom()) / 2 - centre) < .01 or math.abs(f.settingsScroll:GetVerticalScroll() - range) < .01), true,
  "the jump centres the row, or scrolls as far as it goes")
 equal(row:GetTop() <= f.settingsScroll:GetTop() + .01 and row:GetBottom() >= f.settingsScroll:GetBottom() - .01, true, "in view")
 M.Resize(f, height)
 -- Escape in the search box goes back to the page.
 Open(f, "quests")
 Results("tooltip")
 f.searchBox:Fire("OnEscapePressed")
 equal(f.searchBox:GetText() .. f.sectionTitle:GetText() .. tostring(f.searching), "Questsfalse", "Escape goes back to the page")
 -- Switching a fold's switch never runs in search: results are not rows.
 equal(f.checks.cursorRing:IsShown(), false, "search never shows the switches themselves")
end

-- Poisons live in Class Reminders & Buffs; each class's tools words are its own.
for _, c in ipairs({"ROGUE", "HUNTER", "MAGE", "PRIEST"}) do
 local E, f = Session(c)
 local function Results(q) return table.concat((M.Results(f, q)), ",") end
 equal(f.checks.classReminders.summary, "Big on-screen alerts when a class buff, pet, poison or supply is missing.", c .. " Class Reminders & Buffs mentions poisons")
 equal(Results("poison"), c == "ROGUE" and "classReminders,roguePoisons,classTools" or "classReminders", c .. " poison finds Class Reminders & Buffs")
 equal(Results("poison reminders"), "classReminders", c .. " and so does the old Poison Reminders name")
 equal(Has(Results("flash powder"), "classTools"), c == "ROGUE", c .. " flash powder finds the class tools only for a rogue")
 equal(Has(Results("pet feeding"), "classTools"), c == "HUNTER", c .. " pet feeding finds them only for a hunter")
 equal(Has(Results("conjure"), "classTools"), c == "MAGE", c .. " conjure finds them only for a mage")
 -- A class option's result opens the class tab with its boxes.
 local inline = c == "HUNTER" or c == "MAGE"
 Open(f, "frames", "unit")
 M.Results(f, string.lower(c))
 local boxes = 0
 for _, card in pairs(f.checks) do if card.inlinePanel and card.inlinePanel:IsShown() then boxes = boxes + 1 end end
 equal(boxes, 0, c .. " search from another tab opens no box")
 M.Results(f, "class reminders")
 f.visibleRows[1]:Click(); Flush()
 equal(f.selectedCategory == Tab(f, "class") and not f.searching, true, c .. " a result opens the class tab")
 equal(E.modules.ClassReminders:OptionsPanel():IsShown(), true, c .. " with the reminders box open")
 if inline then equal(f.checks.classTools.inlinePanel:IsShown(), true, c .. " and the tools box") end
 M.Fits(f, c .. " class tab after a jump"); M.NoOverlaps(f, c .. " class tab after a jump")
 equal(f.checks.classReminders:GetTop() <= f.settingsScroll:GetTop() + .01, true, c .. " Class Reminders & Buffs in view")
end

-- Rows and tick boxes: sizes, columns, indents, the square tick in the
-- player's class colour, a click anywhere toggling, and the keyboard.
for _, c in ipairs({"MAGE", "HUNTER"}) do
 local E, f = Session(c)
 local colour = RAID_CLASS_COLORS[c]
 Open(f, "map")
 local minimap, clean, coords = f.checks.minimap, f.checks.cleanMinimap, f.checks.coordinates
 local content = f.settingsContent:GetLeft()
 equal(N(minimap:GetHeight()) .. " " .. N(minimap:GetWidth()), "32 352", c .. " a row is 32 tall, 352 wide")
 equal(N(minimap:GetLeft() - content) .. " " .. N(clean:GetLeft() - content), "0 366", c .. " columns at 0 and 366")
 equal(N(coords:GetLeft() - content) .. " " .. N(minimap:GetBottom() - coords:GetTop()), "0 4", c .. " the next line 4 under")
 local box, fill, mark = minimap.tickBox, minimap.tickFill, minimap.tickMark
 equal(N(box:GetWidth()) .. "x" .. N(box:GetHeight()) .. " " .. N(box:GetLeft() - minimap:GetLeft()), "14x14 10", c .. " a 14 x 14 tick box, 10 in")
 equal(Colour(box.fill) .. " / " .. Colour(fill.fill), "0.300,0.320,0.360 / 0.059,0.063,0.075", c .. " grey edge, dark fill")
 equal(minimap.text:GetLeft() - minimap:GetLeft(), 34, c .. " the label after the tick box")
 E.settings.minimap = true; f:Hide(); f:Show(); Flush()
 equal(mark:IsShown() and mark:GetWidth() .. "x" .. mark:GetHeight(), "8x8", c .. " on: an 8 x 8 inner square")
 equal(Colour(mark.fill), Colour({colour.r, colour.g, colour.b}), c .. " in the player's class colour")
 E.settings.coordinates = false; coords:SetChecked(false)
 equal(coords.tickMark:IsShown(), false, c .. " off: no inner square")
 coords:Click()
 equal(E.settings.coordinates == true and coords:GetChecked() == true and coords.tickMark:IsShown(), true, c .. " a click anywhere on the row switches it on")
 coords:Click()
 equal(E.settings.coordinates == false and coords.tickMark:IsShown() == false, true, c .. " and off")
 equal(Colour(minimap.backdropColour) .. " " .. Colour(minimap.borderColour), "0.071,0.082,0.102 0.106,0.122,0.149", c .. " the row's fill and edge")
 minimap:Fire("OnEnter")
 equal(Colour(minimap.backdropColour), "0.098,0.114,0.141", c .. " lighter while hovered")
 minimap:Fire("OnLeave")
 -- Wide rows and indents.
 Open(f, "screen", "afk")
 equal(N(f.checks.afkScreen:GetWidth()) .. " " .. N(f.checks.afkShowZone:GetWidth()) .. " " .. N(f.checks.afkShowZone:GetLeft() - f.settingsContent:GetLeft()), "718 330 22",
  c .. " a wide row 718; a sub-option 22 in, 22 narrower")
 local sub = f.checks.afkShowZone
 equal(sub.connV:IsShown() and sub.connH:IsShown() and Colour(sub.connV.fill), "0.230,0.250,0.290", c .. " joined by a thin line")
 equal(f.checks.afkScreen.connV:IsShown(), false, c .. " no line on a top-level row")
 -- Keyboard: Tab from search reaches the first row; Tab and Shift-Tab move;
 -- Space and Enter act; a greyed row refuses; Escape lets go.
 Open(f, "map")
 f.searchBox:SetFocus()
 f.searchBox:Fire("OnTabPressed")
 equal(f.focusedRow == minimap and f.keys:HasFocus() and minimap.focused, true, c .. " Tab from search focuses the first row")
 equal(f.keys.font ~= nil and f.keys.font[2] == 12 and f.keys.alpha == 0 and f.keys.mouse == false, true,
  c .. " the hidden edit box has a font before it takes a key, unseen and without the mouse")
 f.keys:SetText("q")
 equal(f.keys:GetText(), "", c .. " a letter typed while a row has the keyboard is cleared at once")
 equal(Colour(minimap.borderColour), Colour({colour.r, colour.g, colour.b}), c .. " its edge in the class colour")
 equal(f.footerHelp:IsShown() and Has(M.Text(f.footerHelp:GetText()), "Minimap  The round Classic minimap"), true, c .. " its description in the footer")
 f.keys:Fire("OnTabPressed")
 equal(f.focusedRow == clean and not minimap.focused, true, c .. " Tab moves to the next row")
 S.shift = true; f.keys:Fire("OnTabPressed"); S.shift = false
 equal(f.focusedRow, minimap, c .. " Shift-Tab moves back")
 f.keys:Fire("OnTabPressed"); f.keys:Fire("OnTabPressed")
 equal(f.focusedRow, coords, c .. " and on")
 f.keys:Fire("OnSpacePressed")
 equal(E.settings.coordinates, true, c .. " Space switches it")
 f.keys:Fire("OnEnterPressed")
 equal(E.settings.coordinates, false, c .. " and so does Enter")
 f.keys:Fire("OnArrowPressed", "DOWN")
 equal(f.focusedRow, f.checks.mapQuestObjectives, c .. " down arrow moves on too")
 E.settings.revealMap = false
 E.MapRevealHandedOver = function() return true end; f:RefreshDependencies()
 f:FocusRow(f.checks.revealMap); f.keys:Fire("OnSpacePressed")
 equal(E.settings.revealMap == false and f.checks.revealMap:GetChecked() == false, true, c .. " a handed-over row refuses the keyboard too")
 E.MapRevealHandedOver = nil; f:RefreshDependencies()
 E.settings.actionBars = false; Open(f, "actionBars")
 f:FocusRow(f.checks.gryphons); f.keys:Fire("OnSpacePressed")
 equal(E.settings.gryphons == nil and f.checks.gryphons.dependencyDisabled, true, c .. " so does a greyed row")
 E.settings.actionBars = nil; Open(f, "map"); f:FocusRow(f.checks.mapQuestObjectives)
 -- Another page takes the focus off a row that is no longer shown.
 f.tabs[Tab(f, "quests")]:Click(); Flush()
 equal(f.focusedRow == nil and not f.checks.mapQuestObjectives.focused, true, c .. " a row that leaves the page lets go of the keyboard's edge")
 f.checks.questLog:Fire("OnEnter"); f.checks.questLog:Fire("OnLeave")
 equal(f.footerHelp:IsShown(), false, c .. " so the footer goes back after a hover, not to a hidden row")
 Open(f, "map"); f:FocusRow(f.checks.mapQuestObjectives)
 f.keys:Fire("OnEscapePressed")
 equal(f.focusedRow == nil and f.keys:HasFocus() == false and f.footerHelp:IsShown() == false and f.reloadHint:IsShown(), true, c .. " Escape lets go and the footer goes back")
 -- The keyboard reaches results too, and a jump keeps it.
 M.Results(f, "auto repair")
 f.searchBox:SetFocus(); f.searchBox:Fire("OnTabPressed")
 equal(f.focusedRow == f.visibleRows[1] and f.focusedRow.isResult, true, c .. " Tab from search reaches the first result")
 f.keys:Fire("OnEnterPressed"); Flush()
 equal(f.focusedRow == f.checks.autoRepair and f.keys:HasFocus() and f.checks.autoRepair.focused, true, c .. " Enter on a result jumps and keeps the keyboard on its row")
 f:Hide()
 equal(f.keys:HasFocus() or f.focusedRow ~= nil, false, c .. " closing /era lets go of the keyboard")
end

-- The footer: by default the reload hint, the signature and Changelog,
-- Discord and Reload UI; a row under the mouse shows its description
-- instead, in up to three lines, then its extras in up to two.
do
 local E, f = Session("PRIEST")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 for key in pairs(real.reloadSettings) do E.reloadSettings[key] = true end
 for key, value in pairs(real.settingDefaults) do E.settingDefaults[key] = value end
 for key in pairs(E.reloadSettings) do f.loadedSettings[key] = E.settings[key] and true or false end
 Open(f, "map"); f:RefreshHint()
 equal(N(f.footer:GetLeft() - f:GetLeft()) .. " " .. N(f.footer:GetHeight()), "213 92", "the footer runs under the page, 92 tall")
 equal(f.signature:IsShown() and Has(f.signature:GetText(), "Squirt"), true, "the signature shows")
 equal(f.reloadHint:IsShown() and f.reloadHint:GetText(), "No reload needed for your current settings.", "the reload hint shows")
 equal(f.changelogButton:IsShown() and f.discordButton:IsShown() and not f.reloadButton:IsShown(), true, "Changelog and Discord; Reload UI only when a reload waits")
 E.settings.minimap = not E.settings.minimap; f:RefreshHint()
 equal(f.reloadButton:IsShown() and f.reloadHint:GetText(), "Changes saved. Click Reload UI to apply them.", "a reload waiting: Reload UI and the hint")
 local reloads = 0; ReloadUI = function() reloads = reloads + 1 end
 S.combat = true; f.reloadButton:Click(); S.combat = false
 equal(reloads .. " " .. f.reloadHint:GetText(), "0 Finish combat before reloading the UI.", "no reload in combat")
 f.reloadButton:Click()
 equal(reloads, 1, "Reload UI reloads")
 local row = f.checks.minimap
 row:Fire("OnEnter")
 equal(f.footerHelp:IsShown() and f.footerHelp:GetMaxLines() == 3 and f.footerExtras:GetMaxLines() == 2, true, "a hovered row: its description, three lines and two")
 equal(f.reloadHint:IsShown() or f.signature:IsShown() or f.changelogButton:IsShown() or f.discordButton:IsShown(), false, "the hint, signature, Changelog and Discord give way")
 equal(f.reloadButton:IsShown(), true, "Reload UI stays")
 equal(f.footerHelp:GetRight() <= f.reloadButton:GetLeft() - 8, true, "the description ends before Reload UI")
 equal(f.footerExtras:GetTop() <= f.footerHelp:GetBottom() and f.footerExtras:GetLeft() == f.footerHelp:GetLeft(), true, "its extras under it")
 equal(M.Text(f.footerExtras:GetText()), "Needs /reload to apply.  Default: On.", "a reload row: the reload line, then its default")
 equal(Has(f.footerHelp:GetText(), "|cffffffffMinimap|r  "), true, "the row's name in white first")
 row:Fire("OnLeave")
 equal(f.footerHelp:IsShown() or not f.signature:IsShown(), false, "leaving the row: the footer as before")
 -- Each kind of row's extras.
 local expect = {
  showAllSpellRanks = "Default: keep your existing game preference.", classIconPortraitMine = "Default: keep your existing game preference.",
  cursorRingSize = "Default: 48.", cursorTrailLength = "Default: 0.25s.", cursorCastColour = "Default: white.",
  damageFont = "Needs a log out to apply. A /reload won't do it.  Default: Pepsi.", damageTextScale = "Default: 1.00x.",
  appearanceChoice = "Needs /reload to apply.  Default: Classic.", presets = "", rewardProfile = "", moreFECM = "", moreFEC = "", moreFECP = "",
  hideKeybindText = "Default: Off.", darkModeDarkness = "Default: 58.", contextMenus = "Coming soon: not finished yet.  Default: Off.",
 }
 for key, want in pairs(expect) do
  local _, _, extras = M.Hover(f, f.checks[key])
  equal(extras, want, key .. " extras")
 end
 local _, help = M.Hover(f, f.checks.rewardProfile)
 equal(Has(help, "Reward Profile  Click: next profile. Right-click: previous."), true, "the reward profile says how to switch")
 -- Then the stats its weights count most (three at most, highest first),
 -- without the em dash QuestTools' own text has.
 local profiles, at = {"Balanced", "Caster"}, 1
 E.modules.QuestTools = {Profile = function() return {profiles[at], "x"} end,
  CycleProfile = function(_, step) at = (at - 1 + step) % 2 + 1 end,
  ProfileDescription = function() return profiles[at] .. " \226\128\148 starter weights\nagility: 2\nstamina: 1\nNo proc modelling." end}
 Open(f, "quests")
 local profile = f.checks.rewardProfile
 equal(profile.text:GetText() .. " " .. tostring(profile.depth) .. " " .. tostring(profile.dependencyDisabled), "Reward Profile: Balanced 1 nil", "the reward profile under Highlight Reward Upgrades, never greyed")
 _, help = M.Hover(f, profile)
 equal(help, "Reward Profile  Click: next profile. Right-click: previous. Balanced weighs agility and stamina most.", "the stats it weighs most, no em dash")
 profile:Click("LeftButton")
 equal(profile.text:GetText(), "Reward Profile: Caster", "a click picks the next profile")
 profile:Click("RightButton")
 equal(profile.text:GetText(), "Reward Profile: Balanced", "a right-click the one before")
 equal(profile.clicks and table.concat(profile.clicks, ","), "LeftButtonUp,RightButtonUp", "it takes both buttons")
 E.modules.QuestTools = nil
 equal(Has(M.Hover(f, f.checks.appearanceChoice), "Look  Dark decorative artwork instead of Classic's stone and gold."), true, "the Look choice describes Dark Mode")
 -- The footer in setup spans the window.
 f:SetSetupMode(true); Flush()
 equal(N(f.footer:GetLeft() - f:GetLeft()) .. " " .. tostring(f.signature:IsShown()) .. " " .. tostring(f.changelogButton:IsShown()), "1 false false", "in setup the footer spans the window, without the signature or Changelog")
 equal(f.reloadHint:GetText(), "Your choices are saved as you go.", "and says choices are saved")
 f:SetSetupMode(false); Flush()
 -- No row uses the game's tooltip.
 local owned = 0
 GameTooltip = {SetOwner = function() owned = owned + 1 end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end, IsOwned = function() return false end}
 for _, row2 in pairs(f.checks) do row2:Fire("OnEnter"); row2:Fire("OnLeave") end
 equal(owned, 0, "no row uses the game's tooltip")
 GameTooltip = nil
end

-- Descriptions: every option's footer description (its name, then its help)
-- fits two of the footer's lines at the default window size, for every
-- class, every row kind and every reward profile; no em dash, no "Needs
-- testing" (the row says experimental), no other addon's name, British
-- spelling. The extras always fit two lines too.
local DESCRIBED = {}
for _, run in ipairs({{"DRUID", true}, {"HUNTER"}, {"MAGE"}, {"ROGUE"}, {"WARRIOR"}, {"PALADIN"}, {"SHAMAN"}, {"PRIEST"}, {"WARLOCK"}, {"DRUID", nil, true}}) do
 local c = run[1]
 local E, f = Session(c, run[2], run[3])
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 for key in pairs(real.reloadSettings) do E.reloadSettings[key] = true end
 for key, value in pairs(real.settingDefaults) do E.settingDefaults[key] = value end
 -- The real reward profiles and their weights.
 assert(loadfile("Modules/QuestTools.lua"))("EraUI", E)
 -- The footer's 570 at 12 point, with the row's name first, wrapped word by
 -- word with the glyph widths (never under the game's).
 local WIDTH, SIZE = f.footerHelp:GetWidth(), 12
 equal(WIDTH .. " " .. f.footerExtras:GetWidth(), "570 570", c .. " the footer's description and extras are 570 wide")
 local function Check(label)
  for key, row in pairs(f.checks) do
   if row.classAllowed ~= false then
    local _, help, extras = M.Hover(f, row)
    local body = help:gsub("^.-  ", "", 1)
    local where = c .. " " .. label .. " " .. key
    equal(#body > 0 and not Has(help, EM) and not Has(help, EN), true, where .. " has a description, no em or en dash")
    equal(M.LinesIn(help, WIDTH, SIZE) <= 2, true, where .. " fits two footer lines: " .. help)
    equal(Has(help:lower(), "needs testing") or Has(help, "Questie") or Has(help:lower(), "color"), false, where .. " no Needs testing, no other addon, British spelling")
    equal(M.LinesIn(extras, WIDTH, SIZE) <= 2 and not Has(extras, EM), true, where .. " extras fit two lines: " .. extras)
    -- The footer adds the reload line and the default itself, so the help
    -- never says them; Shift always "skips".
    local lower = body:lower()
    equal(E.reloadSettings[key] and Has(lower, "reload") or false, false, where .. " a reload row's help leaves the reload to the footer: " .. body)
    equal(Has(lower, "reload to") or Has(lower, "applies immediately") or Has(lower, "applies at once") or Has(lower, "bypass") or Has(lower, "default:"),
     false, where .. " no reload, applies-now or default words, no bypass: " .. body)
    DESCRIBED[key] = true
   end
  end
 end
 -- In setup the footer is 466 wide (no list beside it): every row the
 -- walkthrough offers keeps its description to the footer's three lines and
 -- its extras to two there too, handed over as well (Reveal World Map is on
 -- the Map & Minimap page).
 local function SetupCheck(label)
  f:SetSetupMode(false); Flush(); f:SetSetupMode(true); Flush()
  f.setupPreset = "classicqol"
  local narrow, rows = f.footerHelp:GetWidth(), 0
  equal(narrow .. " " .. f.footerExtras:GetWidth() .. " " .. f.footerHelp:GetMaxLines() .. " " .. f.footerExtras:GetMaxLines(), "466 466 3 2",
   c .. " setup's footer: 466 wide, three lines and two")
  for page = 1, 40 do
   f.setupPage = page; f:RenderSetup(); Flush()
   if f.setupPage < page then break end
   for key, row in pairs(f.checks) do
    if row:IsShown() then
     rows = rows + 1
     local _, help, extras = M.Hover(f, row)
     local where = c .. " setup " .. label .. " page " .. page .. " " .. key
     equal(M.LinesIn(help, narrow, SIZE) <= 3, true, where .. " fits setup's three lines: " .. help)
     equal(M.LinesIn(extras, narrow, SIZE) <= 2, true, where .. " extras fit setup's two lines: " .. extras)
    end
   end
  end
  equal(rows > 40, true, c .. " setup " .. label .. ": the walkthrough's rows measured (" .. rows .. ")")
  f:SetSetupMode(false); Flush()
 end
 Check("all on")
 SetupCheck("all on")
 -- Every reward profile of the class, with the real weights.
 local profile = f.checks.rewardProfile
 local _, list = E.modules.QuestTools:Profile()
 for i, entry in ipairs(list) do
  EraUIDB.rewardProfiles[c] = i
  local _, help = M.Hover(f, profile)
  equal(M.LinesIn(help, WIDTH, SIZE) <= 2 and Has(help, entry[1] .. " weighs ") and not Has(help, EM), true, c .. " reward profile " .. entry[1] .. " fits two lines: " .. help)
 end
 E.settings.darkMode, E.settings.unitFrames, E.settings.afkScreen, E.settings.spellbook = false, false, false, false
 E.settings.actionBars, E.settings.advancedCastBar = false, false
 E.NamePlatesHandedOver = function() return true end
 E.MapRevealHandedOver = function() return true end
 f:RefreshDependencies()
 equal(f.checks.revealMap.handedOver and f.checks.friendlyNameplates.handedOver and f.checks.gryphons.dependencyDisabled, true, c .. " rows greyed and handed over")
 Check("greyed and handed over")
 SetupCheck("greyed and handed over")
 equal(f.checks.revealMap.handedOver, true, c .. " Reveal World Map still handed over after setup")
 E.NamePlatesHandedOver, E.MapRevealHandedOver = nil, nil
end
do
 local _, f = Session("DRUID", true)
 for key in pairs(f.checks) do if f.checks[key].classAllowed ~= false or key == "classTools" then equal(DESCRIBED[key] or key == "classTools", true, key .. " described and measured") end end
 for _, key in ipairs({"hunterFeed", "mageSupplies", "mageAutoTrade", "roguePoisons", "manaBar", "rageBar", "energyBar", "afkShowQuote", "moreFEC", "moreFECP"}) do
  equal(DESCRIBED[key], true, key .. " measured on its class")
 end
end

-- The words after a row's name: "just added" (the game's gold) for players
-- who had the old layout, while they run the version it arrived in;
-- "experimental" (muted warm grey) always; never "moved"; never in setup.
-- Plain small lower-case words right after the name: no box, no border, no
-- capitals, no spaced-out letters, on the name's line, inside the row.
local WORDS = {NEW = {"just added", "1.000,0.820,0.000"}, TEST = {"experimental", "0.660,0.610,0.530"},
 SOON = {"coming soon", "0.580,0.620,0.680"}, LOGOUT = {"log out to apply", "0.580,0.620,0.680"}}
local function TagLook(row, label)
 local x = row.text:GetLeft() + row.text:GetStringWidth()
 local width = M.Glyphs(row.text:GetText(), 13)
 for i, id in ipairs(row.tagIds) do
  local tag = row.tags[i]
  local text = tag:GetText()
  equal(text .. " " .. Colour(tag.colour), WORDS[id][1] .. " " .. WORDS[id][2], label .. " says " .. WORDS[id][1] .. " in its colour")
  equal(tag.kind, "FontString", label .. " " .. text .. " is plain text, no box")
  equal(text == text:lower() and not text:find("%a %a %a") and tag.font[2] == 10, true, label .. " " .. text .. " small, lower case, no spaced letters")
  equal(row.tagBox.borderColour == nil and row.tagBox.backdropColour == nil and tag.borderColour == nil, true, label .. " " .. text .. " has no border")
  local _, ty = tag:GetCenter()
  local _, ly = row.text:GetCenter()
  equal(math.abs(ty - ly) <= 1.01, true, label .. " " .. text .. " on the name's line")
  if i == 1 then
   local gap = tag:GetLeft() - x
   equal(gap >= 4 and gap <= 8, true, label .. " " .. text .. " right after the name (" .. N(gap) .. ")")
  end
  width = width + (i == 1 and 6 or 5) + M.Glyphs(text, 10)
 end
 -- The name and its words fit the row (the glyph widths, never under the game's).
 equal(row.text:GetLeft() + width <= row:GetRight() - 4, true, label .. " name and words fit its row (" .. N(width) .. ")")
end
do
 local E, f = Session("ROGUE")
 local function Tags(key) return table.concat(f.checks[key].tagIds, ",") end
 local function Expect(show, label)
  for key in pairs(f.checks) do
   local want = {}
   if show and NEW[key] then want[#want + 1] = "NEW" end
   if TESTING[key] then want[#want + 1] = "TEST" end
   if f.checks[key].unavailable then want[#want + 1] = "SOON" end
   equal(Tags(key), table.concat(want, ","), label .. " " .. key)
  end
 end
 Expect(false, "no version saved:")
 for _, version in ipairs({"9.9.9"}) do
  E.settings.layoutPillsVersion = version; f:Hide(); f:Show(); Flush()
  Expect(true, "the version the layout arrived in:")
 end
 equal(Tags("darkWindows") .. " " .. Tags("darkAuraShadows") .. " " .. Tags("autoRepair") .. " " .. Tags("cursorRing"), "NEW,TEST TEST  ", "for example: nothing says it moved")
 equal(E.SettingsNav.MOVED, nil, "no moved list any more")
 -- Every row with words, on its page, as it shows.
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = true, true, true
 local looked, worded = 0, 0
 for key, row in pairs(f.checks) do
  if TESTING[key] or row.unavailable then worded = worded + 1 end
  if #row.tagIds > 0 then
   local home = f.rowHome[key]
   f:SelectCategory(home.tab, home.sub); Flush()
   TagLook(row, key)
   looked = looked + 1
  end
 end
 equal(looked == worded and looked >= 6, true, "every row with words checked (" .. looked .. ": the five experimental ones and the coming soon ones)")
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = nil, nil, nil
 equal(table.concat(f.checks.contextMenus.tagIds, ","), "SOON", "Context Menus says coming soon")
 for _, version in ipairs({"1.0.0", "", false}) do
  E.settings.layoutPillsVersion = version or nil; f:Hide(); f:Show(); Flush()
  Expect(false, "another version (" .. tostring(version) .. "):")
 end
 E.settings.layoutPillsVersion = "9.9.9"; f:Hide(); f:Show(); Flush()
 f:SetSetupMode(true); Flush()
 Expect(false, "in setup:")
 f:SetSetupMode(false); Flush()
 Expect(true, "after setup:")
 -- Search results carry the same words, after the option's name.
 M.Results(f, "black pages")
 local result = f.visibleRows[1]
 equal(table.concat(result.tagIds, ","), "NEW,TEST", "a result shows its option's words")
 TagLook(result, "the Black Pages result")
 -- "experimental" finds the experimental options.
 local found = M.Results(f, "experimental")
 table.sort(found)
 equal(table.concat(found, ","), "blackPages,characterItemLevels,darkAuraShadows,darkDebuffLines,darkWindows", "searching experimental finds them")
 f.searchBox:SetText(""); Flush()
end

-- New-player hints pulse on the class and Casting tabs, saved by tab
-- number: older orders (version 1: 12 and 13; version 2: 2 and 5) move once.
do
 local saved
 local function Hints(onboarding)
  saved = nil
  local E, f = Session("MAGE", nil, nil, {onboarding = onboarding}, function(E)
   E.SaveCharOnboarding = function()
    local o = EraUIClassicCharDB.onboarding; local tabs = {}
    for k in pairs(o.discoverTabs or {}) do tabs[#tabs + 1] = k end; table.sort(tabs)
    saved = tostring(o.discoveryHintsVersion) .. ":" .. table.concat(tabs, ".")
   end
  end)
  return E, f, EraUIClassicCharDB.onboarding
 end
 local E, f, o = Hints({setupComplete = true, discoveryHintsVersion = 2, discoverTabs = {[2] = true, [5] = true}})
 local class, casting = Tab(f, "class"), Tab(f, "casting")
 equal(class .. "," .. casting, "6,7", "the class and Casting tabs are sixth and seventh")
 equal(o.discoveryHintsVersion .. " " .. tostring(saved), "3 3:6.7", "version 2 hints move to the grouped order once, saved at once")
 local n = 0; for _ in pairs(o.discoverTabs) do n = n + 1 end
 equal(o.discoverTabs[class] == true and o.discoverTabs[casting] == true and n, 2, "the class and Casting hints follow their tabs, nothing else")
 Open(f, "appearance")
 for _, tab in ipairs(f.tabs) do if tab.scripts.OnUpdate then tab:Fire("OnUpdate", .1) end end
 local pulsing = {}
 for _, tab in ipairs(f.tabs) do if tab.hint and tab.hint:IsShown() then pulsing[#pulsing + 1] = tab.id end end
 equal(table.concat(pulsing, ","), "class,casting", "the class and Casting tabs pulse")
 f.tabs[class]:Click(); f.tabs[class]:Fire("OnUpdate", .1)
 equal(o.discoverTabs[class] == nil and f.selectedCategory == class and not f.tabs[class].hint:IsShown(), true, "clicking the class tab opens it and ends its hint")
 equal(o.discoverTabs[casting], true, "Casting still pulses")
 E, f, o = Hints({setupComplete = true, discoveryHintsVersion = 2, discoverTabs = {[5] = true}})
 equal(o.discoverTabs[casting] == true and o.discoverTabs[class] == nil and o.discoverTabs[5] == nil and saved == "3:7", true, "a hint already seen stays seen")
 E, f, o = Hints({setupComplete = true, discoveryHintsVersion = 1, discoverTabs = {[12] = true, [13] = true}})
 equal(o.discoveryHintsVersion == 3 and saved == "3:6.7", true, "version 1 hints move straight to the grouped order")
 E, f, o = Hints({setupComplete = true, discoveryHintsVersion = 1, discoverTabs = {[13] = true}})
 equal(saved, "3:7", "a version 1 hint already seen stays seen")
 E, f, o = Hints({setupComplete = true})
 equal(saved, "3:6.7", "setup done before the hints: both pulse, saved")
 E, f, o = Hints({setupComplete = true, discoveryHintsVersion = 0, discoverTabs = {}})
 equal(saved, "3:6.7", "setup done before the hints, read from the CVar (version 0): both pulse")
 E, f, o = Hints({setupComplete = true, discoveryHintsVersion = 3, discoverTabs = {[7] = true}})
 equal(o.discoverTabs[7] == true and o.discoveryHintsVersion == 3 and saved == nil, true, "version 3 hints are not moved again, nothing saved")
 E, f, o = Hints({})
 equal(o.discoverTabs, nil, "no hints before setup")
 E, f, o = Hints({discoveryHintsVersion = 0})
 equal(o.discoverTabs == nil and saved == nil, true, "no hints before setup, even from the CVar")
end

-- The walkthrough: seven option pages, and every option it offered before is
-- still offered once (Class-coloured Chat Names: the style page, or Chat &
-- Names when the style page is skipped).
do
 local E, f = Session("DRUID")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 for key in pairs(real.reloadSettings) do E.reloadSettings[key] = true end
 for _, key in ipairs(E.Presets.LOOK) do E.settings[key] = true; f.loadedSettings[key] = true end
 local TODAY = {"mapQuestObjectives", "movableMap", "revealMap", "rewardUpgradeHighlight", "rewardProfile",
  "vendorPrice", "bagSpace", "questLevels", "cleanMinimap", "coordinates", "showAllSpellRanks", "gryphons", "hideEmptyActionSlots",
  "autoSellJunk", "autoRepair", "linkToggle", "bagItemLevels", "hideSecondaryNames", "classColors", "classicChatDragging", "hideStatusMessages",
  "fastAutoLoot", "autoGossip", "durabilityWarning", "tooltipIDs", "junkValueSummary", "showWelcomeOnLogin", "autoQuests",
  "autoSummon", "autoResurrect", "releasePvP", "discardCheapestJunk", "hideKeybindText", "hideMacroText", "hideZoneText", "maxCameraZoom",
  "cursorRing", "cursorRingClassColour", "cursorRingSize", "cursorRingThickness", "cursorCastRing", "cursorCastClassColour",
  "cursorCastSize", "cursorCastOpacity", "cursorCastColour", "cursorTrail", "cursorTrailClassColour", "cursorTrailSize",
  "cursorTrailOpacity", "cursorTrailLength", "cursorTrailColour", "afkScreen", "afkCameraNormal", "afkTurnRight", "afkZoom",
  "afk24Hour", "afkShowGuild", "afkShowZone", "afkShowDate", "afkShowQuote", "blockDuels", "blockPartyInvites", "partyFromFriends",
  "inviteFromWhispers", "damageFont", "damageTextScale"}
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = true, true, true
 local function Walk(preset)
  f:SetSetupMode(false); Flush(); f:SetSetupMode(true); Flush()
  f.setupPreset = preset
  local offered, titles, count, scrolls = {}, {}, {}, {}
  for page = 1, 40 do
   f.setupPage = page; f:RenderSetup(); Flush()
   if f.setupPage < page then break end
   local progress = f.setupProgress:GetText()
   local option = progress:match("^OPTIONS  (%d+) / 7$")
   if option then
    titles[#titles + 1] = f.sectionTitle:GetText()
    equal(#f.sectionAbout:GetText() > 0, true, preset .. " " .. progress .. " explains its page")
   end
   for key, card in pairs(f.checks) do
    if card:IsShown() then
     offered[key] = true; count[key] = (count[key] or 0) + 1
     if option then equal(not E.reloadSettings[key] or key == "classicChatDragging", true, preset .. " " .. progress .. ": " .. key .. " is no reload-only look") end
     equal(key ~= "updateCheck", true, preset .. " " .. progress .. ": Update Notice is not offered")
    end
   end
   if #(f.visibleRows or {}) > 0 then
    M.NoOverlaps(f, preset .. " " .. progress); M.Fits(f, preset .. " " .. progress)
    M.SubOptionsFollow(f, preset .. " " .. progress, ParentOf(E))
    if f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + .01 then scrolls[#scrolls + 1] = f.sectionTitle:GetText() end
   end
  end
  return offered, titles, count, scrolls
 end
 local offered, titles, count, scrolls = Walk("classicqol")
 equal(table.concat(titles, ","), "Action Bars,Map & Minimap,Quests,Bags & Vendors,Chat & Names,Group & Invites,Screen & Cursor", "the seven option pages")
 for _, key in ipairs(TODAY) do equal(offered[key], true, "Classic + QoL: " .. key .. " still in the walkthrough") end
 equal(count.classColors .. " " .. count.tooltipIDs, "1 1", "Class-coloured Chat Names and Tooltip IDs once")
 equal(table.concat(scrolls, ","), "Choose your style,Screen & Cursor", "the style page and Screen & Cursor scroll (measured)")
 offered, titles, count = Walk("qol")
 equal(#titles, 7, "QoL only: the same seven option pages")
 for _, key in ipairs(TODAY) do equal(offered[key], true, "QoL only: " .. key .. " still in the walkthrough") end
 equal(count.classColors, 1, "QoL only: Class-coloured Chat Names on the Chat & Names page")
 local function Page(title)
  for page = 1, 40 do
   f.setupPage = page; f:RenderSetup(); Flush()
   if f.sectionTitle:GetText() == title then return true end
  end
 end
 f:SetSetupMode(false); Flush(); f:SetSetupMode(true); Flush(); f.setupPreset = "classicqol"
 Page("Chat & Names")
 equal(Keys(f), "hideSecondaryNames,classicChatDragging,linkToggle,tooltipIDs,hideStatusMessages,showWelcomeOnLogin", "Tooltip IDs on Chat & Names, after Click Links Again to Close")
 Page("Bags & Vendors")
 equal(f.checks.tooltipIDs:IsShown(), false, "and not on Bags & Vendors")
 E.settings.actionBars = false
 Page("Action Bars")
 equal(f.checks.gryphons:IsShown(), false, "Action Bars look off: no greyed Show Gryphons")
 equal(f.checks.hideEmptyActionSlots:IsShown() and f.checks.showAllSpellRanks:IsShown(), true, "the other Action Bars options stay")
 E.settings.actionBars = true; f:RenderSetup(); Flush()
 equal(f.checks.gryphons:IsShown() and not f.checks.gryphons.dependencyDisabled, true, "Action Bars look on: Show Gryphons offered, and it can be switched")
 E.settings.cursorRing = nil
 f:SetSetupMode(false); Flush(); f:SetSetupMode(true); Flush(); f.setupPreset = "classicqol"
 Page("Screen & Cursor")
 equal(f.checks.cursorRing:IsShown() and not f.checks.cursorRingSize:IsShown(), true, "walkthrough: the cursor ring's options folded while it is off")
 f.checks.cursorRing:Click(); Flush()
 equal(f.setupMode and f.checks.cursorRingSize:IsShown(), true, "and open when it is switched on")
 -- The setup pages hide every other page's rows and the old layout's note.
 equal(f.layoutNotice, nil, "the old layout note is gone (the welcome card replaced it)")
 f:SetSetupMode(false); Flush()
end

-- Combat: a full pass with combat on, every page, search, a jump, the
-- keyboard, the welcome card and every walkthrough step, raises no
-- protected mutation and never shows a conjure button.
do
 local E, f = Session("MAGE")
 local actions = {}
 for _, b in ipairs(S.frames) do if b.secure then actions[#actions + 1] = b end end
 S.combat = true
 for _, b in ipairs(actions) do b.shown = false end
 for i, cat in ipairs(f.categories) do for _, sub in ipairs(cat.subs) do f:SelectCategory(i, sub.id); Flush() end end
 M.Results(f, "class colour"); f.visibleRows[1]:Click(); Flush()
 f.searchBox:SetFocus(); f.searchBox:Fire("OnTabPressed"); f.keys:Fire("OnTabPressed"); f.keys:Fire("OnSpacePressed"); f.keys:Fire("OnEscapePressed")
 E.settings.layoutWelcome = 1; f:Hide(); f:Show(); Flush()
 equal(f.welcoming, true, "the welcome card shows in combat (nothing secure)")
 f.welcome.go:Click(); Flush()
 for _ = 1, 6 do f.tour.nextButton:Click(); Flush() end
 equal(f.touring, false, "the walkthrough runs through in combat")
 f:StartTour(); f.keys:Fire("OnEscapePressed")
 f:Hide(); f:Show(); Flush()
 for _, b in ipairs(actions) do equal(b:IsShown(), false, "combat never shows a conjure button") end
 equal(true, true, "combat: pages, search, jump, keyboard, welcome and walkthrough have no protected mutations")
 S.combat = false
end

-- Tidy labels: Title Case, "&" not "/", "Class-coloured", British spelling,
-- names on one line; headings in small capitals; no "/" in tab names.
do
 local E, f = Session("WARLOCK")
 local MINOR = {a = true, an = true, ["and"] = true, the = true, of = true, on = true, to = true, ["in"] = true, from = true, ["for"] = true, with = true}
 local function TitleCase(label)
  local first = true
  for word in label:gmatch("%S+") do
   if word:find("%w") then
    local lead = word:match("%w")
    if not (lead:match("[%u%d]") or (not first and MINOR[word])) then return false end
    first = false
   end
  end
  return true
 end
 local summaries = {}
 for key, row in pairs(f.checks) do
  local label = row.labelText
  if row.rowKind ~= "more" and row.rowKind ~= "heading" and row.rowKind ~= "link" then
   if key ~= "darkenClassColours" then equal(TitleCase(label), true, key .. " label in Title Case: " .. label) end
   equal(label:find("/", 1, true), nil, key .. " label uses & not /")
   equal(#label * 7 <= (row.rowKind == "slider" and 194 or 300), true, key .. " label fits one line: " .. label)
   local lower = label:lower()
   if lower:find("class", 1, true) and lower:find("colo", 1, true) and key ~= "darkenClassColours" then
    equal(label:find("^Class%-coloured ") ~= nil or label:find("^Custom ") ~= nil, true, key .. " says Class-coloured: " .. label)
   end
   equal(lower:find("colored", 1, true) == nil and lower:find("colors", 1, true) == nil, true, key .. " British spelling")
  end
  if row.summary and row.rowKind == "tick" then
   equal(not Has(row.summary, EM) and row.summary ~= "Classic presentation.", true, key .. " summary says what it does")
   equal(summaries[row.summary], nil, key .. " summary is its own"); summaries[row.summary] = true
  end
 end
 for _, cat in ipairs(f.categories) do
  for _, sub in ipairs(cat.subs) do for _, section in ipairs(sub.sections) do equal(section.title:find("/", 1, true), nil, section.title .. " uses & not /") end end
 end
 for _, tab in ipairs(f.tabs) do equal(tab.text:GetText():find("/", 1, true), nil, tab.id .. " tab uses & not /") end
 -- A slider row shows "Name: value": the whole of it fits beside the
 -- slider at its lowest and highest value (the glyph widths at 13 point),
 -- and the slider keeps room to drag.
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = true, true, true
 local sliders = 0
 for key, row in pairs(f.checks) do
  if row.rowKind == "slider" then
   local home = f.rowHome[key]
   f:SelectCategory(home.tab, home.sub); Flush()
   equal(row:IsVisible(), true, key .. " on show on its page")
   local info, room = row.info, row.text:GetRight() - row.text:GetLeft()
   for _, value in ipairs({info.low, info.high}) do
    local shown = row.labelText .. ": " .. (info.format and info.format(value) or tostring(value))
    equal(M.Glyphs(shown, 13) <= room, true, key .. " shows its name and value whole: " .. shown)
   end
   equal(row.slider:GetWidth() >= 90, true, key .. " its slider keeps 90 or more to drag")
   sliders = sliders + 1
  end
 end
 equal(sliders, 9, "every slider row measured (Darkness, damage text size, seven cursor sliders)")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = nil, nil, nil
 Open(f, "quests")
 equal(f.checks.rewardProfile.text:GetText():find("^Reward Profile: ") ~= nil, true, "the reward profile row in Title Case")
end

-- Every tab name fits inside its tab and ends before the sidebar divider,
-- for all nine classes, with honest widths for the tab font (Friz Quadrata
-- at 13, measured in game on 2026-10-01 at 1.2 scale; any other name a
-- glyph estimate never under those measurements). The tabs sit between the
-- search box and Take the tour.
do
 local MEASURED = {["Appearance"] = 80.1, ["Hunter"] = 45.0, ["Action Bars"] = 75.9, ["Frames & Nameplates"] = 145.9,
  ["Casting"] = 49.2, ["Map & Minimap"] = 110.1, ["Quests"] = 45.9, ["Character & Spells"] = 123.4, ["Bags & Vendors"] = 105.1,
  ["Chat & Names"] = 95.1, ["Group & Invites"] = 106.8, ["Windows & Tooltips"] = 135.9, ["Screen & Cursor"] = 108.4,
  ["More from Squirt"] = 115.9}
 -- The glyph estimate (Tools/SettingsMock.lua) the other width checks use.
 local function Glyphs(text) return M.Glyphs(text, 13) end
 for name, width in pairs(MEASURED) do equal(Glyphs(name) >= width, true, "the glyph estimate is never under the game's width: " .. name) end
 local function Width(text, size) return (MEASURED[text] or Glyphs(text)) * (size or 13) / 13 end
 local NAMES = {WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid"}
 local oldClass = UnitClass
 UnitClass = function() return NAMES[S.token] or S.token, S.token end
 for _, c in ipairs(CLASSES) do
  local E, f = Session(c)
  local divider = f.navDivider:GetLeft()
  equal(#f.tabs, 14, c .. " 14 tabs")
  for _, tab in ipairs(f.tabs) do
   local name = tab.text:GetText()
   local size = tab.text.font and tab.text.font[2]
   local right = tab.text:GetLeft() + Width(name, size)
   equal(N(tab:GetWidth()) .. "x" .. N(tab:GetHeight()), "188x28", c .. " " .. name .. " tab 188 x 28")
   equal(right + 2 <= tab:GetRight(), true, c .. " " .. name .. " fits inside its tab")
   equal(tab:GetRight() < divider, true, c .. " " .. name .. " tab ends before the sidebar divider")
   local label = tab.text
   equal(label.wordWrap == false and label.justifyH == "LEFT", true, c .. " " .. name .. " label on one line from the left")
   equal(#label.points == 2 and label:GetRight() <= tab:GetRight() - 2, true, c .. " " .. name .. " label held 2 inside its tab")
   equal(right <= label:GetRight(), true, c .. " " .. name .. " fits its label whole")
   equal(tab:GetTop() <= f.searchBox:GetBottom() - 8 and tab:GetBottom() >= f.tourButton:GetTop() + 8, true, c .. " " .. name .. " between search and Take the tour")
  end
  equal(f.tabs[Tab(f, "class")].text:GetText(), NAMES[c], c .. " the class tab shows the class name")
  equal(f.settingsScroll:GetLeft() - divider, 13, c .. " the rows start 13 right of the divider")
  equal(f.settingsScroll:GetWidth(), 718, c .. " the rows keep their width")
  equal(f.sectionTitle:GetLeft() - divider, 19, c .. " the page title 19 right of the divider")
  equal(f.navigation:GetRight() .. " " .. f.navigation:GetTop() .. " " .. f.navigation:GetBottom(), divider .. " " .. (f:GetTop() - 1) .. " " .. (f:GetBottom() + 1),
   c .. " the dark list backing runs the window's height and ends at the divider")
  equal(N(f.searchBox:GetWidth()) .. " " .. N(f.searchBox:GetLeft() - f:GetLeft()), "188 12", c .. " search at the top of the list")
  equal(f.searchPlaceholder:GetText(), "Search options", c .. " search placeholder")
  equal(N(f.tourButton:GetWidth()) .. " " .. f.tourButton.label:GetText(), "188 Take the tour", c .. " Take the tour at the bottom of the list")
  equal(f.navTitle:GetText() .. " " .. Colour(f.navTitle.colour), "EraUI " .. Colour({RAID_CLASS_COLORS[c] and RAID_CLASS_COLORS[c].r or .7,
   RAID_CLASS_COLORS[c] and RAID_CLASS_COLORS[c].g or .7, RAID_CLASS_COLORS[c] and RAID_CLASS_COLORS[c].b or .7}), c .. " EraUI title in the class colour")
 end
 UnitClass = oldClass
end
print("Settings layout/combat checks passed: " .. M.checks .. " assertions.")
