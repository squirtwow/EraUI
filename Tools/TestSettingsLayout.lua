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
   {"style", "Style", {{"STYLE", {"appearanceChoice", "presets"}}, {"FRAME STYLE", {"flatBars", "thickFrames", "thickFrameRings", "thickFrameParty",
    "thickFrameEdge", "thickAuraBorders", "roundedCastBars", "partyOutline"}}}},
   {"dark", "Dark Mode", {{"DARKNESS", {"darkModeDarkness", "darkenClassColours"}},
    {"BORDERS", {"darkAuraBorders", "darkAuraShadows", "darkDebuffLines"}},
    {"BARS AND WINDOWS", {"darkMenuBar", "darkBagButtons", "darkWindows", "blackPages"}}}},
   {"classcol", "Class Colours", {{"CLASS COLOURS", {"classColors", "tooltipClassColours", "classColourBorders", "castBarClassBorder"}}}}}},
  {"actionBars", "Action Bars", "The stone dock and the Classic action buttons.", {
   {"main", nil, {{"ACTION BARS", {"actionBars", "gryphons", "hideEmptyActionSlots", "hideKeybindText", "hideMacroText",
    "upgradeSpellRanks"}}}}}},
  {"frames", "Frames & Nameplates", "Unit frames, portraits and nameplates.", {
   {"unit", "Unit Frames", {{"UNIT FRAMES", {"unitFrames", "matchFocusSize", "disableAggroHighlight", "portraitDebuffs",
    "classIconPortraitMine", "classIconPortraitOthers"}}}},
   {"plates", "Nameplates", {{"NAMEPLATES", {"friendlyNameplates", "enemyNameplates"}}}}}},
  {"map", "Map & Minimap", "The minimap and the world map.", {
   {"main", nil, {{"MINIMAP", {"minimap", "squareMinimap", "squareMinimapScale", "cleanMinimap", "cleanMinimapStyle", "minimapDrawerColumns",
    "coordinates"}},
    {"WORLD MAP", {"mapQuestObjectives", "movableMap", "revealMap"}}}}}},
  {"windows", "Windows & Tooltips", "Classic frames for the game's windows, and tooltips.", {
   {"main", nil, {{"WINDOWS", {"gameMenu", "popups", "blizzardSettings", "mailSkin", "auctionHouse", "damageMeterSkin",
    "otherWindows", "contextMenus"}}, {"TOOLTIPS", {"tooltipSkin", "tooltipIDs"}}}}}},
 }},
 {group = "GAMEPLAY", tabs = {
  {"class", nil, "Tools for your class. Each class sees its own.", nil},
  {"casting", "Casting", "Cast bars for you and everyone else.", {
   {"main", nil, {{"CAST BARS", {"castBars", "advancedCastBar", "advancedCastClassFill", "advancedCastTicks", "advancedCastLatency"}},
    {"COLOUR", {"castBarColour", "castBarCustomColour"}}}}}},
  {"quests", "Quests", "The quest log, dialogue and tracker.", {
   {"main", nil, {{"QUESTS", {"questLog", "questDialogs", "questTracker", "questLevels"}},
    {"AUTOMATION", {"autoQuests", "autoGossip", "rewardUpgradeHighlight", "rewardProfile"}}}}}},
  {"character", "Character & Spells", "Character, talents, spellbook, trainer, professions and the stat tracker.", {
   {"main", nil, {{"WINDOWS", {"characterPanel", "characterItemLevels", "talentWindow", "trainer", "professions"}},
    {"SPELLBOOK", {"spellbook", "spellbookCombatDrag", "trainingGuide", "showAllSpellRanks"}},
    {"STAT TRACKER", {"statTracker", "statTrackerLayout", "statTrackerShow", "statTrackerScale", "statTrackerPerLine", "statTrackerGains",
     "statTrackerTitle", "statTrackerNameColour", "statTrackerNameCustomColour"}},
    {"ATTRIBUTES", {"statTrackerStrength", "statTrackerAgility", "statTrackerStamina", "statTrackerIntellect", "statTrackerSpirit"}},
    {"OFFENCE", {"statTrackerAttackPower", "statTrackerCrit", "statTrackerHit", "statTrackerSpellPower", "statTrackerSpellCrit"}},
    {"DEFENCE", {"statTrackerArmor", "statTrackerDodge", "statTrackerParry", "statTrackerBlock"}},
    {"OTHER", {"statTrackerSpeed", "statTrackerDurability"}}}}}},
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
 -- Clean Minimap's style and the drawer's icons per row, folded under it
 -- (checked in their own block below).
 cleanMinimapStyle = "cleanMinimap", minimapDrawerColumns = "cleanMinimap",
 -- Custom Cast Bar Colour, folded under the Cast Bar Colour choice (a whole
 -- line, greyed by Cast Bars but never indented under it: its own block below).
 castBarCustomColour = "castBarColour",
 -- Custom Stat Name Colour, folded under the Stat Name Colour choice (a whole
 -- line, shown only with the Stat Tracker on: its own block below).
 statTrackerNameCustomColour = "statTrackerNameColour",
 -- Thick Frames' two ticks and its Frame Edge choice (Thick Frames itself is
 -- greyed by Unit Frames, on another page, and never indented).
 thickFrameRings = "thickFrames", thickFrameParty = "thickFrames", thickFrameEdge = "thickFrames",
 -- Square Minimap reshapes Minimap's own look: under it, greyed while it's off.
 -- Its Square Size slider shows only with it, laid out under Minimap at its
 -- indent (GROUPS; checked in its own block below).
 squareMinimap = "minimap", squareMinimapScale = "minimap",
}
local FOLDED = {
 cursorRing = {"cursorRingClassColour", "cursorRingSize", "cursorRingThickness"},
 cursorCastRing = {"cursorCastClassColour", "cursorCastSize", "cursorCastOpacity", "cursorCastColour"},
 cursorTrail = {"cursorTrailClassColour", "cursorTrailSize", "cursorTrailOpacity", "cursorTrailLength", "cursorTrailColour"},
}
for parent, kids in pairs(FOLDED) do for _, kid in ipairs(kids) do PARENT[kid] = parent end end
-- The options each release added, written out here by hand (from the
-- releases' notes), one per option: its own row. "just added" goes after
-- them for an account that updated from before that release, while it runs
-- the version it updated into; the rows under or shown with them (Black
-- Pages under Dark Windows, Thick Frames' ticks and Edge, the Stat
-- Tracker's options, Custom Cast Bar Colour, Icons per Row) go with them and
-- never say it. A row with no room for "just added" and its other words
-- before its buttons would say only those (TIGHT, measured below): none now.
-- Clean Minimap's Style and Cast Bar Colour were, while they said
-- "experimental"; seen working in game (2026-10-15), they have room.
-- Then those not seen working in game yet ("experimental", always): since
-- the user's check in game on 2026-10-15, only the Raid-style Party Outline.
-- Nothing says it moved any more.
local LEADS = {["1.6.0"] = {"flatBars", "darkDebuffLines", "darkWindows"},
 ["1.7.0"] = {"thickFrames", "thickAuraBorders", "roundedCastBars", "partyOutline", "darkBagButtons", "upgradeSpellRanks",
  "cleanMinimapStyle", "castBarColour", "statTracker"},
 ["1.7.1"] = {"squareMinimap"}}
local TIGHT = {}
-- The options saying "just added" for an account that updated from this version.
local function NewSince(from)
 local out = {}
 for version, keys in pairs(LEADS) do
  local a, b = {}, {}
  for n in version:gmatch("%d+") do a[#a + 1] = tonumber(n) end
  for n in from:gmatch("%d+") do b[#b + 1] = tonumber(n) end
  local later = false
  for i = 1, 3 do if (a[i] or 0) ~= (b[i] or 0) then later = (a[i] or 0) > (b[i] or 0); break end end
  if later then for _, key in ipairs(keys) do if not TIGHT[key] then out[key] = true end end end
 end
 return out
end
local TESTING = {partyOutline = true}
-- The eighteen the user saw working in game on 2026-10-15: no "experimental".
local SEEN_WORKING = {"darkAuraShadows", "darkDebuffLines", "darkWindows", "blackPages", "darkBagButtons", "characterItemLevels",
 "flatBars", "thickAuraBorders", "roundedCastBars", "thickFrames", "thickFrameRings", "thickFrameParty", "thickFrameEdge",
 "castBarColour", "cleanMinimapStyle", "squareMinimap", "upgradeSpellRanks", "statTracker"}

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
 -- and Thin Debuff Colours under it, then Dark Menu Bar beside Dark Bag
 -- Buttons, and Dark Windows with Black Pages under it.
 do
  local aura, shade, lines = f.checks.darkAuraBorders, f.checks.darkAuraShadows, f.checks.darkDebuffLines
  local bar, bags, windows, black = f.checks.darkMenuBar, f.checks.darkBagButtons, f.checks.darkWindows, f.checks.blackPages
  for _, row in ipairs({aura, shade, lines, bar, bags, windows, black}) do
   equal(row.category == Tab(f, "appearance") and row.subId, "dark", c .. " " .. row.settingKey .. " on Appearance > Dark Mode")
  end
  equal(aura.text:GetText() .. "/" .. shade.text:GetText() .. "/" .. lines.text:GetText() .. "/" .. bags.text:GetText() .. "/"
   .. windows.text:GetText() .. "/" .. black.text:GetText(),
   "Dark Aura Borders/Aura Shadows/Thin Debuff Colours/Dark Bag Buttons/Dark Windows/Black Pages", c .. " plain labels (any words are small ones after the name)")
  Open(f, "appearance", "dark")
  M.NoOverlaps(f, c .. " Appearance > Dark Mode")
  M.Fits(f, c .. " Appearance > Dark Mode")
  equal(Keys(f), "darkModeDarkness,darkenClassColours,darkAuraBorders,darkAuraShadows,darkDebuffLines,darkMenuBar,darkBagButtons,darkWindows,blackPages",
   c .. " Dark Mode in the approved order")
  for _, row in ipairs({shade, lines}) do
   equal(row.depth == 1 and math.abs(row:GetLeft() - aura:GetLeft() - 22) < .01 and row:GetTop() < aura:GetBottom(), true,
    c .. " " .. row.settingKey .. " indented under Dark Aura Borders")
  end
  equal(black.depth == 1 and math.abs(black:GetLeft() - windows:GetLeft() - 22) < .01 and black:GetTop() < windows:GetBottom(), true,
   c .. " Black Pages indented under Dark Windows")
  equal((bags.depth or 0) == 0 and bags:GetTop() == bar:GetTop() and bags:GetLeft() > bar:GetRight(), true,
   c .. " Dark Bag Buttons beside Dark Menu Bar, not indented")
  equal(windows:GetLeft() == bar:GetLeft() and windows:GetTop() < bar:GetBottom(), true, c .. " Dark Windows on the next line, under Dark Menu Bar")
  -- Dark Mode off greys all six; Dark Aura Borders off greys its two;
  -- Dark Windows off greys Black Pages.
  E.settings.darkMode = nil; E.settings.darkAuraBorders = true; E.settings.darkWindows = true; f:RefreshDependencies()
  for _, row in ipairs({aura, shade, lines, bar, bags, windows, black}) do
   equal(row.dependencyDisabled == true and row.alpha, .45, c .. " " .. row.settingKey .. " greyed while Dark Mode is off")
  end
  bags:SetChecked(true); bags:Fire("OnClick")
  equal(E.settings.darkBagButtons == nil and bags:GetChecked() == false, true, c .. " Dark Bag Buttons can't be switched on without Dark Mode; its tick goes back")
  aura:SetChecked(false); aura:Click()
  equal(E.settings.darkAuraBorders == true and aura:GetChecked() == true, true, c .. " a click on a greyed row changes nothing and keeps its tick")
  shade:SetChecked(true); shade:Fire("OnClick")
  equal(E.settings.darkAuraShadows == nil and shade:GetChecked() == false, true, c .. " Aura Shadows can't be switched on without Dark Mode; its tick goes back")
  E.settings.darkMode = true; E.settings.darkAuraBorders = false; E.settings.darkWindows = false; f:RefreshDependencies()
  equal(aura.dependencyDisabled == false and aura.alpha == 1 and bar.dependencyDisabled == false and bags.dependencyDisabled == false
   and bags.alpha == 1 and windows.dependencyDisabled == false, true,
   c .. " Dark Mode on: Dark Aura Borders, Dark Menu Bar, Dark Bag Buttons and Dark Windows available")
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
  equal(table.concat(card.tagIds, ","), "", c .. " no words after its name (seen working in game, not in a release's list)")
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
  "Aura Shadows help: what it does, no experimental or Needs testing words")
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
 -- Dark Bag Buttons: its words, off by default, live through EraUI.Classic
 -- with its own chat line, waiting for Dark Mode like the rows round it.
 local bagRow = f.checks.darkBagButtons
 _, help, extras = M.Hover(f, bagRow)
 equal(help, "Dark Bag Buttons  Your bag buttons' icons in a darker grey, all alike, instead of each bag's colours. An open bag shows a dark line, not a bright one.",
  "Dark Bag Buttons: what it does, in two lines")
 equal(extras, "Default: Off.", "Dark Bag Buttons: off by default, no reload line")
 equal(bagRow.summary, "Grey, darker bag icons and a dark line on open bags. Dark Mode only.", "Dark Bag Buttons: its summary")
 local bagPasses = 0
 E.Classic.RefreshDarkBagButtons = function() bagPasses = bagPasses + 1 end
 bagRow:SetChecked(false); bagRow:Click()
 equal(tostring(E.settings.darkBagButtons) .. " " .. bagPasses .. " " .. menus .. " " .. wins .. " " .. status,
  "true 1 2 3 Dark Bag Buttons enabled.", "Dark Bag Buttons on, live through EraUI.Classic, the menu bar and windows left alone")
 bagRow:Click()
 equal(tostring(E.settings.darkBagButtons) .. " " .. bagPasses .. " " .. status, "false 2 Dark Bag Buttons disabled.", "and off, live")
 E.GetSetting = function(self, key) if key == "darkMode" then return false end; return get(self, key) end
 bagRow:Click()
 equal(status, "Dark Bag Buttons enabled. They show once Dark Mode is applied.", "Dark Bag Buttons waits for Dark Mode")
 E.GetSetting = get
 bagRow:Click()
 E.Classic.RefreshDarkBagButtons = nil
 bagRow:Click()
 equal(E.settings.darkBagButtons, true, "without Classic loaded, the Dark Bag Buttons tick still saves")
 bagRow:Click()
 for _, word in ipairs({"bag", "backpack", "icon", "grey", "gray", "colour", "color", "open", "dark"}) do
  local hit = false
  for _, key in ipairs(M.Results(f, word)) do if key == "darkBagButtons" then hit = true end end
  equal(hit, true, "searching " .. word .. " finds Dark Bag Buttons")
 end
 f.searchBox:SetText(""); Flush()
 Open(f, "appearance", "dark")
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
 equal(f.checks.upgradeSpellRanks:IsShown(), true, "and Upgrade Spell Ranks, which applies without a reload")
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
 equal(Keys(f), "appearanceChoice,presets,flatBars,thickFrames,thickFrameRings,thickFrameParty,thickFrameEdge,thickAuraBorders,roundedCastBars,partyOutline",
  "Style holds the Look choice and Presets, then Frame Style's Flat Bars, Thick Frames with its two ticks and Frame Edge, Thick Aura Borders, Rounded Cast Bars and the Raid-style Party Outline")
 -- Flat Bars: a tick under the choice, in its own Frame Style section,
 -- applying at once (Classic/Skin.lua and the Advanced Cast Bar) with the
 -- usual chat line.
 local flat = f.checks.flatBars
 equal(flat.text:GetText() .. " / " .. tostring(flat:IsVisible()) .. " / " .. tostring(flat:GetChecked()) .. " / " .. tostring(flat.wide),
  "Flat Bars / true / false / nil", "Flat Bars: a tick row in the left column, off")
 local headings = {}
 for _, item in ipairs(f.settingsItems or {}) do if item.heading then headings[#headings + 1] = item.heading end end
 equal(table.concat(headings, "|"):upper(), "STYLE|FRAME STYLE", "under its own heading, after the style's")
 local _, flatHelp, flatExtras = M.Hover(f, flat)
 equal(flatHelp, "Flat Bars  A plain, even fill instead of Classic's shaded one on unit-frame and cast bars. Their colours stay. Works with Classic or Dark Mode.",
  "Flat Bars: its words")
 equal(flatExtras, "Default: Off.", "Flat Bars: no reload line, off by default")
 local refreshes, advanced, flatStatus, waits = 0, 0, nil, false
 E.Classic.RefreshFlatBars = function() refreshes = refreshes + 1; return not waits end
 E.modules.AdvancedCastBar = {Refresh = function() advanced = advanced + 1 end}
 local status = E.Status
 E.Status = function(_, m) flatStatus = m end
 flat:Click()
 equal(tostring(E.settings.flatBars) .. " " .. refreshes .. " " .. advanced .. " " .. flatStatus, "true 1 1 Flat Bars enabled.",
  "a click switches it on, live: the bars, then the Advanced Cast Bar")
 flat:Click()
 equal(tostring(E.settings.flatBars) .. " " .. refreshes .. " " .. advanced .. " " .. flatStatus, "false 2 2 Flat Bars disabled.", "and off, live")
 waits = true
 flat:Click()
 equal(flatStatus, "Flat Bars enabled. Some bars change when combat ends.", "a bar held in a fight: it says the rest follow")
 E.Classic.RefreshFlatBars, E.modules.AdvancedCastBar = nil, nil
 flat:Click()
 equal(tostring(E.settings.flatBars) .. " " .. flatStatus, "false Flat Bars disabled.", "without Classic loaded the tick still saves")
 E.Status = status
 -- Search finds it by its words.
 for _, word in ipairs({"flat", "texture", "solid", "frame style"}) do
  local found = M.Results(f, word)
  local hit = false
  for _, key in ipairs(found) do if key == "flatBars" then hit = true end end
  equal(hit, true, "searching " .. word .. " finds Flat Bars")
 end
 f.searchBox:SetText(""); Flush()
 -- Thick Aura Borders: the next tick in Frame Style, its own switch (never
 -- greyed, in Classic or Dark Mode), applying at once through the aura
 -- module with its own chat line, and saying in its help that it wins over
 -- the other aura borders.
 Open(f, "appearance", "style")
 M.NoOverlaps(f, "DRUID Appearance > Style")
 local thick = f.checks.thickAuraBorders
 equal(thick.text:GetText() .. " / " .. tostring(thick:IsVisible()) .. " / " .. tostring(thick:GetChecked()) .. " / " .. tostring(thick.wide)
  .. " / " .. tostring(thick.dependencyDisabled), "Thick Aura Borders / true / false / nil / nil", "Thick Aura Borders: a tick row, off, never greyed")
 equal(f.rowHome.thickAuraBorders.tab == f.rowHome.flatBars.tab and f.rowHome.thickAuraBorders.sub == f.rowHome.flatBars.sub, true,
  "Thick Aura Borders on Flat Bars' page")
 local _, thickHelp, thickExtras = M.Hover(f, thick)
 equal(thickHelp, "Thick Aura Borders  Thick dark borders round your own buffs and debuffs, debuffs lined in their colour. Works with Classic or Dark Mode. Wins over the other aura borders.",
  "Thick Aura Borders: its words, the rule for several ticked in one short line")
 equal(thickExtras, "Default: Off.", "Thick Aura Borders: no reload line, no switch needed first, off by default")
 equal(thick.summary, "Thick dark borders round your own buffs and debuffs. Works with Classic or Dark Mode.", "Thick Aura Borders: its summary")
 local auraRefreshes, thickStatus = 0, nil
 local realAuras = E.modules.AuraStyle
 E.modules.AuraStyle = {RefreshBorders = function() auraRefreshes = auraRefreshes + 1 end}
 local status2 = E.Status
 E.Status = function(_, m) thickStatus = m end
 local get = E.GetSetting
 for _, dark in ipairs({false, true}) do
  E.GetSetting = function(self, key) if key == "darkMode" then return dark end; return get(self, key) end
  f:RefreshDependencies()
  equal(thick.dependencyDisabled, nil, "Thick Aura Borders never greyed (Dark Mode " .. tostring(dark) .. ")")
  thick:Click()
  equal(tostring(E.settings.thickAuraBorders) .. " " .. thickStatus, "true Thick Aura Borders enabled.", "a click switches it on, live, no Dark Mode note (Dark Mode " .. tostring(dark) .. ")")
  thick:Click()
  equal(tostring(E.settings.thickAuraBorders) .. " " .. thickStatus, "false Thick Aura Borders disabled.", "and off, live (Dark Mode " .. tostring(dark) .. ")")
 end
 E.GetSetting = get
 equal(auraRefreshes, 4, "each click refreshes the aura borders at once")
 E.modules.AuraStyle = nil
 thick:Click()
 equal(tostring(E.settings.thickAuraBorders) .. " " .. thickStatus, "true Thick Aura Borders enabled.", "without the aura module the tick still saves")
 thick:Click()
 E.modules.AuraStyle, E.Status = realAuras, status2
 for _, word in ipairs({"thick", "border", "buff", "debuff", "aura", "frame style"}) do
  local found = M.Results(f, word)
  local hit = false
  for _, key in ipairs(found) do if key == "thickAuraBorders" then hit = true end end
  equal(hit, true, "searching " .. word .. " finds Thick Aura Borders")
 end
 f.searchBox:SetText(""); Flush()
 -- Rounded Cast Bars: the third tick in Frame Style, on Flat Bars' page and
 -- never indented (its switch, Cast Bars, is on Casting), greyed with a note
 -- while Cast Bars is off, applying at once through the cast bars, the
 -- Advanced Cast Bar and the class accents, with its own chat line.
 Open(f, "appearance", "style")
 M.NoOverlaps(f, "DRUID Appearance > Style with Rounded Cast Bars")
 local rounded = f.checks.roundedCastBars
 equal(rounded.text:GetText() .. " / " .. tostring(rounded:IsVisible()) .. " / " .. tostring(rounded:GetChecked()) .. " / " .. tostring(rounded.wide)
  .. " / " .. tostring(rounded.dependencyDisabled == true) .. " / " .. tostring(rounded.depth or 0),
  "Rounded Cast Bars / true / false / nil / false / 0", "Rounded Cast Bars: a tick row, off, not greyed with Cast Bars on, not indented")
 equal(f.rowHome.roundedCastBars.tab == f.rowHome.flatBars.tab and f.rowHome.roundedCastBars.sub == f.rowHome.flatBars.sub, true,
  "Rounded Cast Bars on Flat Bars' page")
 local keysThere = Keys(f)
 equal(keysThere:find("thickAuraBorders,roundedCastBars", 1, true) ~= nil, true, "Rounded Cast Bars right after Thick Aura Borders")
 local _, roundedHelp, roundedExtras = M.Hover(f, rounded)
 equal(roundedHelp, "Rounded Cast Bars  Thick, soft-cornered cast bars for you, your pet, target and focus: the spell icon in its own tile, its name left, the time right. Needs Cast Bars.",
  "Rounded Cast Bars: its words")
 equal(roundedExtras, "Default: Off.", "Rounded Cast Bars: no reload line, nothing to switch on first with Cast Bars on, off by default")
 equal(rounded.summary, "Thick soft-cornered cast bars with the spell icon in its own tile. Needs Cast Bars.", "Rounded Cast Bars: its summary")
 local castRefreshes, advancedRefreshes, accentRefreshes, roundedStatus, roundedWaits = 0, 0, 0, nil, false
 local order = {}
 local realClassic, realAdvanced, realAccents = E.Classic, E.modules.AdvancedCastBar, E.modules.ClassAccents
 E.Classic = setmetatable({RefreshRoundedCasts = function()
  castRefreshes = castRefreshes + 1; order[#order + 1] = "casts"; return not roundedWaits end}, {__index = realClassic})
 E.modules.AdvancedCastBar = {Refresh = function() advancedRefreshes = advancedRefreshes + 1; order[#order + 1] = "advanced" end}
 E.modules.ClassAccents = {Refresh = function() accentRefreshes = accentRefreshes + 1; order[#order + 1] = "accents" end}
 local status3 = E.Status
 E.Status = function(_, m) roundedStatus = m end
 rounded:Click()
 equal(tostring(E.settings.roundedCastBars) .. " " .. castRefreshes .. " " .. advancedRefreshes .. " " .. accentRefreshes .. " " .. roundedStatus,
  "true 1 1 1 Rounded Cast Bars enabled.", "a click switches it on, live")
 equal(table.concat(order, ","), "casts,advanced,accents", "the cast bars first, then the Advanced Cast Bar, then the class colour on the new line")
 rounded:Click()
 equal(tostring(E.settings.roundedCastBars) .. " " .. castRefreshes .. " " .. advancedRefreshes .. " " .. accentRefreshes .. " " .. roundedStatus,
  "false 2 2 2 Rounded Cast Bars disabled.", "and off, live")
 roundedWaits = true
 rounded:Click()
 equal(roundedStatus, "Rounded Cast Bars enabled. Some bars change when combat ends.", "a bar held in a fight: it says the rest follow")
 roundedWaits = false
 rounded:Click()
 E.Classic, E.modules.AdvancedCastBar, E.modules.ClassAccents = {}, nil, nil
 rounded:Click()
 equal(tostring(E.settings.roundedCastBars) .. " " .. roundedStatus, "true Rounded Cast Bars enabled.", "without the cast bars loaded the tick still saves")
 rounded:Click()
 E.Classic, E.modules.AdvancedCastBar, E.modules.ClassAccents = realClassic, realAdvanced, realAccents
 -- Cast Bars off (Casting): greyed, a note says where to switch it on, and a
 -- click changes nothing.
 E.settings.castBars = false
 f:RefreshDependencies()
 local _, _, greyExtras = M.Hover(f, rounded)
 equal(tostring(rounded.dependencyDisabled) .. " / " .. greyExtras, "true / Switch on Cast Bars first (Casting).  Default: Off.",
  "Cast Bars off: greyed, its note names the switch and its tab")
 local clicksBefore = castRefreshes
 rounded:Click()
 equal(tostring(E.settings.roundedCastBars) .. " " .. tostring(rounded:GetChecked()) .. " " .. (castRefreshes - clicksBefore), "false false 0",
  "greyed: a click changes nothing")
 E.settings.castBars = true
 f:RefreshDependencies()
 equal(rounded.dependencyDisabled, false, "Cast Bars back on: not greyed")
 E.Status = status3
 for _, word in ipairs({"rounded", "corner", "cast bar", "icon", "tile", "frame style"}) do
  local found = M.Results(f, word)
  local hit = false
  for _, key in ipairs(found) do if key == "roundedCastBars" then hit = true end end
  equal(hit, true, "searching " .. word .. " finds Rounded Cast Bars")
 end
 f.searchBox:SetText(""); Flush()
 -- Thick Frames: the tick right after Flat Bars, on Flat Bars' page and
 -- never indented (its switch, Unit Frames, is on Frames & Nameplates),
 -- greyed with a note while Unit Frames is off. Its two ticks, Portrait
 -- Rings and Classic Party Frames, sit indented under it and are greyed
 -- while it's off. Each applies at once through the unit frames with its own
 -- chat line, and says so when a fight holds the frames.
 E.settings.unitFrames = true
 Open(f, "appearance", "style")
 M.NoOverlaps(f, "DRUID Appearance > Style with Thick Frames")
 M.Fits(f, "DRUID Appearance > Style with Thick Frames")
 local thickRow, ringsRow, partyRow = f.checks.thickFrames, f.checks.thickFrameRings, f.checks.thickFrameParty
 equal(thickRow.text:GetText() .. " / " .. tostring(thickRow:IsVisible()) .. " / " .. tostring(thickRow:GetChecked()) .. " / " .. tostring(thickRow.wide)
  .. " / " .. tostring(thickRow.dependencyDisabled == true) .. " / " .. tostring(thickRow.depth or 0),
  "Thick Frames / true / false / nil / false / 0", "Thick Frames: a tick row, off, not greyed with Unit Frames on, not indented")
 equal(f.rowHome.thickFrames.tab == f.rowHome.flatBars.tab and f.rowHome.thickFrames.sub == f.rowHome.flatBars.sub, true,
  "Thick Frames on Flat Bars' page")
 equal(Keys(f):find("flatBars,thickFrames,thickFrameRings,thickFrameParty,thickFrameEdge,thickAuraBorders", 1, true) ~= nil, true,
  "Thick Frames right after Flat Bars, its two ticks and Frame Edge right after it")
 equal(ringsRow.text:GetText() .. " / " .. partyRow.text:GetText(), "Portrait Rings / Classic Party Frames", "the two ticks' names")
 for _, row in ipairs({ringsRow, partyRow}) do
  equal(tostring(row:IsVisible()) .. " / " .. tostring(row:GetChecked()) .. " / " .. tostring(row.depth) .. " / " .. tostring(row.dependencyDisabled),
   "true / false / 1 / true", row.text:GetText() .. ": shown, off, indented under Thick Frames, greyed while it's off")
 end
 -- Edge (Frame Edge): a choice row (Dark, Class colour) indented under Thick
 -- Frames after its ticks, Dark chosen, greyed while it's off; its name (one
 -- short word) clears its buttons with no words after it ("just added" goes
 -- with Thick Frames above it), each button holds its word, in the row.
 local edgeRow = f.checks.thickFrameEdge
 local edgeNames = {}
 for i, button in ipairs(edgeRow.buttons) do edgeNames[i] = button.label:GetText() end
 equal(edgeRow.rowKind .. " " .. edgeRow.labelText .. " " .. table.concat(edgeNames, "/") .. " / " .. tostring(edgeRow:IsVisible()) .. " / " .. tostring(edgeRow.wide)
  .. " / " .. tostring(edgeRow.depth) .. " / " .. tostring(edgeRow.dependencyDisabled) .. " / " .. edgeRow.selected .. " / " .. edgeRow.alpha,
  "choice Edge Dark/Class colour / true / nil / 1 / true / 1 / 0.45",
  "Frame Edge: a choice row, Dark or Class colour, indented under Thick Frames, greyed while it's off, Dark chosen")
 local edgeWords = M.Glyphs(edgeRow.text:GetText(), 13)
 for i in ipairs(edgeRow.tagIds) do edgeWords = edgeWords + (i == 1 and 6 or 5) + M.Glyphs(edgeRow.tags[i]:GetText(), 10) end
 equal(#edgeRow.tagIds .. " " .. tostring(edgeRow.text:GetLeft() + edgeWords <= edgeRow.buttons[1]:GetLeft() - 4), "0 true",
  "Frame Edge: no words after its name (seen working in game), its name clears Dark")
 for i, button in ipairs(edgeRow.buttons) do
  equal(M.Glyphs(button.label:GetText(), 13) <= button:GetWidth() - 8 and button:GetRight() <= edgeRow:GetRight() + .01, true, edgeNames[i] .. " fits its button, in the row")
  if i > 1 then equal(edgeRow.buttons[i - 1]:GetRight() <= button:GetLeft() - 5.99, true, edgeNames[i - 1] .. " clear of " .. edgeNames[i]) end
 end
 local _, edgeHelp, edgeExtras = M.Hover(f, edgeRow)
 equal(edgeHelp, "Edge  The thick frames' edges. Dark keeps them near black. Class colour adds a fine line round the frames and rings: yours, a player's in theirs, gold for elites.",
  "Frame Edge: its words")
 equal(M.LinesIn(edgeHelp, 570, 12) <= 3, true, "Frame Edge: its words fit the footer's three lines")
 equal(edgeExtras, "Switch on Thick Frames first.  Default: Dark.", "Frame Edge: greyed, its note names Thick Frames; Dark by default")
 equal(edgeRow.summary, "Dark edges, or a fine line in class colours.", "Frame Edge: its summary")
 M.SubOptionsFollow(f, "DRUID Appearance > Style with Thick Frames", ParentOf(E))
 local _, thickFramesHelp, thickFramesExtras = M.Hover(f, thickRow)
 equal(thickFramesHelp, "Thick Frames  Thick dark frames with round corners and taller bars for you, your pet, target, focus and target of target. Elites get a gold mark. Needs Unit Frames.",
  "Thick Frames: its words")
 equal(thickFramesExtras, "Default: Off.", "Thick Frames: no reload line, nothing to switch on first with Unit Frames on, off by default")
 equal(thickRow.summary, "Thick dark frames with round corners on player, pet, target, focus and target of target.", "Thick Frames: its summary")
 local _, ringsHelp, ringsExtras = M.Hover(f, ringsRow)
 equal(ringsHelp, "Portrait Rings  A thick dark ring round each portrait on the thick frames; Edge below can line it in class colours. Off, the portraits sit on the frames without one.",
  "Portrait Rings: its words")
 equal(ringsExtras, "Switch on Thick Frames first.  Default: Off.", "Portrait Rings: greyed, its note names Thick Frames (same page, no crumb)")
 equal(ringsRow.summary, "Dark ring round each portrait.", "Portrait Rings: its summary")
 local _, partyHelp, partyExtras = M.Hover(f, partyRow)
 equal(partyHelp, "Classic Party Frames  Thick frames on EraUI's Classic-style party frames too, like your pet's. Raid-style party frames aren't changed.",
  "Classic Party Frames: its words")
 equal(partyExtras, "Switch on Thick Frames first.  Default: Off.", "Classic Party Frames: greyed, its note names Thick Frames")
 equal(partyRow.summary, "The same frames on EraUI's Classic-style party frames.", "Classic Party Frames: its summary")
 -- Greyed: a click changes nothing.
 ringsRow:Click()
 equal(tostring(E.settings.thickFrameRings) .. " " .. tostring(ringsRow:GetChecked()), "nil false", "Portrait Rings greyed: a click changes nothing")
 local frameRefreshes, framesStatus, framesWait = 0, nil, false
 local realClassic2 = E.Classic
 E.Classic = setmetatable({RefreshThickFrames = function() frameRefreshes = frameRefreshes + 1; return not framesWait end}, {__index = realClassic2})
 local status4 = E.Status
 E.Status = function(_, m) framesStatus = m end
 thickRow:Click()
 equal(tostring(E.settings.thickFrames) .. " " .. frameRefreshes .. " " .. framesStatus, "true 1 Thick Frames enabled.", "a click switches it on, live")
 for _, row in ipairs({ringsRow, partyRow}) do
  equal(row.dependencyDisabled, false, row.text:GetText() .. ": not greyed with Thick Frames on")
 end
 ringsRow:Click()
 equal(tostring(E.settings.thickFrameRings) .. " " .. frameRefreshes .. " " .. framesStatus, "true 2 Thick Frames: Portrait Rings enabled.",
  "Portrait Rings on, live, its own line")
 partyRow:Click()
 equal(tostring(E.settings.thickFrameParty) .. " " .. frameRefreshes .. " " .. framesStatus, "true 3 Thick Frames: Classic Party Frames enabled.",
  "Classic Party Frames on, live, its own line")
 -- Frame Edge with Thick Frames on: free; each choice saved and applied at
 -- once through the thick frames' lines (no unit-frame pass, so a fight
 -- never holds it: only EraUI's own textures change), with its own chat
 -- line; Space on the row flips it too.
 local lineRefreshes = 0
 E.Classic.RefreshThickFrameLines = function() lineRefreshes = lineRefreshes + 1 end
 equal(tostring(edgeRow.dependencyDisabled) .. " " .. edgeRow.alpha, "false 1", "Frame Edge: free with Thick Frames on")
 edgeRow.buttons[2]:Click(); Flush()
 equal(E.settings.thickFrameEdge .. " " .. edgeRow.selected .. " " .. lineRefreshes .. " " .. frameRefreshes .. " " .. framesStatus,
  "class 2 1 3 Thick Frames: a fine line in class colours round the frames and portrait rings.",
  "Class colour: saved, the lines toned at once (no unit-frame pass), said")
 edgeRow.buttons[1]:Click(); Flush()
 equal(E.settings.thickFrameEdge .. " " .. edgeRow.selected .. " " .. lineRefreshes .. " " .. framesStatus,
  "dark 1 2 Thick Frames: dark frame edges and portrait rings.", "Dark: saved, at once, said")
 f:FocusRow(edgeRow); f.keys:Fire("OnSpacePressed")
 equal(E.settings.thickFrameEdge .. " " .. edgeRow.selected .. " " .. lineRefreshes, "class 2 3", "Space on the row flips it")
 f:ClearRowFocus()
 edgeRow.buttons[1]:Click(); Flush()
 framesWait = true
 ringsRow:Click()
 equal(tostring(E.settings.thickFrameRings) .. " " .. framesStatus, "false Thick Frames: Portrait Rings disabled. Some frames change when combat ends.",
  "in a fight: it says the frames follow when it ends")
 thickRow:Click()
 equal(tostring(E.settings.thickFrames) .. " " .. framesStatus, "false Thick Frames disabled. Some frames change when combat ends.",
  "Thick Frames off in a fight: the same note")
 framesWait = false
 equal(tostring(ringsRow.dependencyDisabled) .. " " .. tostring(partyRow.dependencyDisabled), "true true", "Thick Frames off greys its ticks again")
 equal(tostring(edgeRow.dependencyDisabled) .. " " .. edgeRow.alpha, "true 0.45", "and Frame Edge")
 local linesBefore = lineRefreshes
 edgeRow.buttons[2]:Click(); Flush()
 equal(E.settings.thickFrameEdge .. " " .. edgeRow.selected .. " " .. (lineRefreshes - linesBefore), "dark 1 0", "Frame Edge greyed: a click changes nothing")
 partyRow:Click()
 equal(tostring(E.settings.thickFrameParty) .. " " .. frameRefreshes, "true 5", "greyed, a ticked one stays ticked and a click changes nothing")
 E.Classic = {}
 thickRow:Click()
 equal(tostring(E.settings.thickFrames) .. " " .. framesStatus, "true Thick Frames enabled.", "without the unit frames loaded the tick still saves")
 partyRow:Click()
 thickRow:Click()
 E.Classic = realClassic2
 equal(tostring(E.settings.thickFrames) .. " " .. tostring(E.settings.thickFrameParty), "false false", "all off again")
 -- Unit Frames off (Frames & Nameplates): greyed, a note says where.
 E.settings.unitFrames = false
 f:RefreshDependencies()
 local _, _, framesGrey = M.Hover(f, thickRow)
 equal(tostring(thickRow.dependencyDisabled) .. " / " .. framesGrey, "true / Switch on Unit Frames first (Frames & Nameplates > Unit Frames).  Default: Off.",
  "Unit Frames off: greyed, its note names the switch and its page")
 local _, _, ringsGrey = M.Hover(f, ringsRow)
 equal(ringsGrey, "Switch on Unit Frames first (Frames & Nameplates > Unit Frames).  Default: Off.", "its ticks name Unit Frames first, up the chain")
 local _, _, edgeGrey = M.Hover(f, edgeRow)
 equal(edgeGrey, "Switch on Unit Frames first (Frames & Nameplates > Unit Frames).  Default: Dark.", "Frame Edge too")
 local before = frameRefreshes
 thickRow:Click()
 equal(tostring(E.settings.thickFrames) .. " " .. tostring(thickRow:GetChecked()) .. " " .. (frameRefreshes - before), "false false 0",
  "greyed: a click changes nothing")
 E.settings.unitFrames = true
 f:RefreshDependencies()
 equal(thickRow.dependencyDisabled, false, "Unit Frames back on: not greyed")
 E.Status = status4
 E.settings.thickFrameEdge = nil
 for _, case in ipairs({{"thick frames", "thickFrames"}, {"plate", "thickFrames"}, {"soft corners", "thickFrames"}, {"round corners", "thickFrames"},
  {"frame style", "thickFrames"}, {"portrait ring", "thickFrameRings"}, {"ring", "thickFrameRings"}, {"party", "thickFrameParty"},
  {"classic party", "thickFrameParty"}, {"frame edge", "thickFrameEdge"}, {"edge", "thickFrameEdge"}, {"class colour", "thickFrameEdge"},
  {"outline", "thickFrameEdge"}}) do
  local found = M.Results(f, case[1])
  local hit = false
  for _, key in ipairs(found) do if key == case[2] then hit = true end end
  equal(hit, true, "searching " .. case[1] .. " finds " .. case[2])
 end
 f.searchBox:SetText(""); Flush()
 -- Raid-style Party Outline: the last tick in Frame Style, its own switch
 -- (the game's party frames, not EraUI's: never greyed, never indented),
 -- applying at once through Classic/PartyOutline.lua with its own chat
 -- line: where it shows, or that Forever Enhanced Raid Frames has the
 -- party; in a fight it says the frames follow when it ends.
 Open(f, "appearance", "style")
 M.NoOverlaps(f, "DRUID Appearance > Style with the Raid-style Party Outline")
 M.Fits(f, "DRUID Appearance > Style with the Raid-style Party Outline")
 local outlineRow = f.checks.partyOutline
 equal(outlineRow.text:GetText() .. " / " .. tostring(outlineRow:IsVisible()) .. " / " .. tostring(outlineRow:GetChecked()) .. " / " .. tostring(outlineRow.wide)
  .. " / " .. tostring(outlineRow.dependencyDisabled) .. " / " .. tostring(outlineRow.depth or 0),
  "Raid-style Party Outline / true / false / nil / nil / 0", "Raid-style Party Outline: a tick row, off, never greyed, not indented")
 equal(f.rowHome.partyOutline.tab == f.rowHome.flatBars.tab and f.rowHome.partyOutline.sub == f.rowHome.flatBars.sub, true,
  "Raid-style Party Outline on Flat Bars' page")
 equal(Keys(f):find("roundedCastBars,partyOutline$") ~= nil, true, "the Raid-style Party Outline last, right after Rounded Cast Bars")
 equal(table.concat(outlineRow.tagIds or {}, ","), "TEST", "it says experimental (just added too for returning players: checked with the rest below)")
 local _, outlineHelp, outlineExtras = M.Hover(f, outlineRow)
 equal(outlineHelp, "Raid-style Party Outline  Flat bars and one thick dark outline round the game's raid-style party frames. The outline shows while Edit Mode's Display Border is on.",
  "Raid-style Party Outline: its words")
 equal(outlineExtras, "Default: Off.", "Raid-style Party Outline: no reload line, nothing to switch on first, off by default")
 equal(outlineRow.summary, "Flat bars and one thick outline round raid-style party frames.", "Raid-style Party Outline: its summary (the mockup's)")
 local outlineRefreshes, outlineStatus, outlineWaits, outlineAside = 0, nil, false, false
 local realClassic3 = E.Classic
 E.Classic = setmetatable({RefreshPartyOutline = function() outlineRefreshes = outlineRefreshes + 1; return not outlineWaits end,
  PartyOutlineStepsAside = function() return outlineAside end}, {__index = realClassic3})
 local status5 = E.Status
 E.Status = function(_, m) outlineStatus = m end
 outlineRow:Click()
 equal(tostring(E.settings.partyOutline) .. " " .. outlineRefreshes .. " " .. outlineStatus,
  "true 1 Raid-style Party Outline enabled. It shows on raid-style party frames with Edit Mode's Display Border on.", "a click switches it on, live, saying where it shows")
 outlineRow:Click()
 equal(tostring(E.settings.partyOutline) .. " " .. outlineRefreshes .. " " .. outlineStatus, "false 2 Raid-style Party Outline disabled.", "and off, live")
 outlineAside = true
 outlineRow:Click()
 equal(outlineStatus, "Raid-style Party Outline enabled. Forever Enhanced Raid Frames draws your party, so it steps aside.",
  "while Forever Enhanced Raid Frames draws the party: it says it steps aside")
 outlineRow:Click()
 outlineAside, outlineWaits = false, true
 outlineRow:Click()
 equal(outlineStatus, "Raid-style Party Outline enabled. It shows on raid-style party frames with Edit Mode's Display Border on. Some frames change when combat ends.",
  "in a fight: it says the frames follow when it ends")
 outlineRow:Click()
 equal(outlineStatus, "Raid-style Party Outline disabled. Some frames change when combat ends.", "off in a fight: the same note")
 outlineWaits = false
 -- Never greyed: Unit Frames, Cast Bars and the look don't matter.
 local get5 = E.GetSetting
 E.settings.unitFrames, E.settings.castBars = false, false
 for _, dark in ipairs({false, true}) do
  E.GetSetting = function(self, key) if key == "darkMode" then return dark end; return get5(self, key) end
  f:RefreshDependencies()
  equal(outlineRow.dependencyDisabled, nil, "never greyed, Unit Frames and Cast Bars off (Dark Mode " .. tostring(dark) .. ")")
 end
 E.GetSetting = get5
 E.settings.unitFrames, E.settings.castBars = true, true
 f:RefreshDependencies()
 E.Classic = {}
 outlineRow:Click()
 equal(tostring(E.settings.partyOutline) .. " " .. outlineStatus,
  "true Raid-style Party Outline enabled. It shows on raid-style party frames with Edit Mode's Display Border on.", "without Classic loaded the tick still saves")
 outlineRow:Click()
 equal(tostring(E.settings.partyOutline) .. " " .. outlineRefreshes, "false 6", "off again; each click with Classic loaded refreshed it once")
 E.Classic, E.Status = realClassic3, status5
 for _, word in ipairs({"raid", "outline", "raid style", "party outline", "display border", "edit mode", "flat", "frame style"}) do
  local found = M.Results(f, word)
  local hit = false
  for _, key in ipairs(found) do if key == "partyOutline" then hit = true end end
  equal(hit, true, "searching " .. word .. " finds the Raid-style Party Outline")
 end
 f.searchBox:SetText(""); Flush()
 Open(f, "appearance", "style")
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
 -- The cursor effects' folded options open, Clean Minimap's (with the
 -- Drawer style), Cast Bar Colour's (with Custom), the Stat Tracker's
 -- (with Stat Name Colour's Custom) and Square Minimap's Square Size, so
 -- every row shows.
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = true, true, true
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle = true, "drawer"
 E.settings.castBarColour = "custom"
 E.settings.statTracker, E.settings.statTrackerNameColour = true, "custom"
 E.settings.squareMinimap = true
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
     -- None of the topic pages scrolls at the default size, these folds
     -- open, but Character & Spells with the Stat Tracker's twenty-three
     -- rows open (switched off it fits: the Stat Tracker's own block below).
     local long = id == "character"
     equal(f.settingsContent:GetHeight() <= f.settingsScroll:GetHeight() + .01 and not f.settingsScrollHint:IsShown(), not long,
      id .. " > " .. sub[1] .. (long and " scrolls, the Stat Tracker open" or " fits without scrolling"))
    end
   end
  end
 end
 equal(index, #f.tabs, "every tab checked")
 equal(#f.tabs, 14, "fourteen tabs")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = nil, nil, nil
 E.settings.statTracker, E.settings.statTrackerNameColour = nil, nil
 E.settings.squareMinimap = nil
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
 -- every sub-page, with every fold open (the Stat Tracker's rows have no
 -- layout parent: each its own block, never indented, but Custom Stat Name
 -- Colour, under its choice; and Square Size, under Minimap at Square
 -- Minimap's indent).
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail, E.settings.afkScreen = true, true, true, true
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = true, true, true
 E.settings.statTracker, E.settings.statTrackerNameColour = true, "custom"
 E.settings.squareMinimap = true
 for i, cat in ipairs(f.categories) do
  for _, sub in ipairs(cat.subs) do
   f:SelectCategory(i, sub.id); Flush()
   M.SubOptionsFollow(f, cat.id .. " > " .. sub.id, ParentOf(E))
   M.NoOverlaps(f, cat.id .. " > " .. sub.id .. " with folds open")
   M.Fits(f, cat.id .. " > " .. sub.id .. " with folds open")
  end
 end
 -- Not indented: options whose mockup parent is no real dependency.
 for _, key in ipairs({"cleanMinimap", "characterItemLevels", "classColourBorders", "darkAuraBorders", "darkMenuBar", "darkBagButtons", "darkWindows", "castBarColour",
  "statTrackerLayout", "statTrackerShow", "statTrackerScale", "statTrackerPerLine", "statTrackerGains", "statTrackerNameColour", "statTrackerStrength",
  "statTrackerDurability"}) do
  equal(f.checks[key].depth or 0, 0, key .. " not indented")
 end
 Open(f, "character")
 equal(f.checks.statTrackerNameCustomColour.depth == 1 and f.checks.statTrackerNameCustomColour.connV:IsShown(), true,
  "Custom Stat Name Colour sits under Stat Name Colour")
 Open(f, "map")
 equal(f.checks.squareMinimapScale.depth == 1 and f.checks.squareMinimapScale.connV:IsShown()
  and math.abs(f.checks.squareMinimapScale:GetLeft() - f.checks.squareMinimap:GetLeft()) < .01, true,
  "Square Size sits under Minimap, at Square Minimap's indent")
 Open(f, "class")
 equal(f.checks.comboPointRed.depth == 1 and f.checks.comboPointRed.connV:IsShown(), true, "Red Combo Points sits under Floating Combo Points")
 E.settings.floatingComboPoints = false; f:RefreshDependencies()
 equal(f.checks.comboPointRed.dependencyDisabled, nil, "but is never greyed by it")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail, E.settings.afkScreen = nil, nil, nil, nil
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = nil, nil, nil
 E.settings.statTracker, E.settings.statTrackerNameColour = nil, nil
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle, E.settings.castBarColour = nil, nil, nil
 E.settings.squareMinimap = nil
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
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle, E.settings.castBarColour = true, "drawer", "custom"
 E.settings.statTracker, E.settings.statTrackerNameColour = true, "custom"
 E.settings.squareMinimap = true
 local scrolls = {}
 for i, cat in ipairs(f.categories) do
  for _, sub in ipairs(cat.subs) do
   f:SelectCategory(i, sub.id); Flush()
   if f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + .01 then scrolls[#scrolls + 1] = cat.id .. ">" .. sub.id end
   equal(f.settingsScrollHint:IsShown(), f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + 1, cat.id .. " > " .. sub.id .. " scroll hint only when it scrolls")
  end
 end
 equal(table.concat(scrolls, ","), "character>main",
  "only Character & Spells scrolls at the default size, every fold open: the Stat Tracker's rows (the class tab's boxes are checked per class)")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail, E.settings.afkScreen = nil, nil, nil, nil
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle, E.settings.castBarColour = nil, nil, nil
 E.settings.statTracker, E.settings.statTrackerNameColour = nil, nil
 E.settings.squareMinimap = nil
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
   -- Waiting on a choice (Stats per Line on Layout's One line): that row
   -- by its label, and one of its own choices by its button's name.
   local choice
   if not name then name, choice = text:match("^Set (.-) to (.-) first%.") end
   local owner = name and f.checks[names[name]]
   equal(owner ~= nil, true, key .. " names a row: " .. text)
   if choice then
    local found = false
    for _, button in ipairs(owner.buttons or {}) do if button.label:GetText() == choice then found = true end end
    equal(found, true, key .. " names one of " .. name .. "'s own choices: " .. choice)
   end
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
 local colours = "thickFrameEdge,darkenClassColours,classColors,tooltipClassColours,classColourBorders,castBarClassBorder,advancedCastClassFill,castBarColour,"
  .. "statTrackerNameColour,cursorRingClassColour,cursorCastClassColour,cursorTrailClassColour"
 Open(f, "map")
 equal(Results("class colour"), colours, "class colour finds every class-colour option, in tab then page order (Stat Name Colour folded)")
 equal(Results("class color"), colours, "and so does class color")
 equal(Results("Class Colored"), colours, "and class colored")
 equal(f.sectionTitle:GetText() .. " / " .. f.sectionAbout:GetText(), "Search / 12 options found. Click one to go to it.", "search says how many and what a click does")
 equal(f.subTabStrip:IsShown(), false, "no sub-tabs in search")
 for _, tab in ipairs(f.tabs) do equal(tab.underline:IsShown(), false, tab.id .. " not highlighted in search") end
 local _, crumbs = Results("class colour")
 equal(crumbs[1] .. "|" .. crumbs[2] .. "|" .. crumbs[3] .. "|" .. crumbs[7] .. "|" .. crumbs[10],
  "Appearance > Style|Appearance > Dark Mode|Appearance > Class Colours|Casting|Screen & Cursor > Cursor", "each result says where it lives")
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
 equal(Results("casting"), "castBars,advancedCastBar,advancedCastClassFill,advancedCastTicks,advancedCastLatency,castBarColour,castBarCustomColour",
  "casting finds the Casting tab, its folded Custom Cast Bar Colour too")
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
 local squared = f.checks.squareMinimap
 equal(N(squared:GetLeft() - content) .. " " .. N(minimap:GetBottom() - squared:GetTop()), "22 4", c .. " the next line 4 under (Square Minimap, 22 in under Minimap)")
 equal(N(coords:GetLeft() - content) .. " " .. N(squared:GetBottom() - coords:GetTop()), "0 4", c .. " and the one after it 4 under that")
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
 equal(f.focusedRow == squared and not minimap.focused, true, c .. " Tab moves to the next row (Square Minimap, under Minimap)")
 S.shift = true; f.keys:Fire("OnTabPressed"); S.shift = false
 equal(f.focusedRow, minimap, c .. " Shift-Tab moves back")
 f.keys:Fire("OnTabPressed"); f.keys:Fire("OnTabPressed")
 equal(f.focusedRow, clean, c .. " then Clean Minimap")
 f.keys:Fire("OnTabPressed")
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

-- The words after a row's name: "just added" (the game's gold) for an
-- account that updated, on the options added since the version it updated
-- from, while it runs the version it updated into (none for a fresh
-- install); "experimental" (muted warm grey) always; never "moved"; never
-- in setup.
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
 -- And stop short of the row's buttons (a choice's), never under them.
 if row.buttons and row.buttons[1] and #row.tagIds > 0 then
  equal(row.text:GetLeft() + width <= row.buttons[1]:GetLeft() - 4, true, label .. " name and words clear its first button")
 end
end
-- Whether a choice row's name has room for "just added" and its other words
-- before its first button, all measured with the glyph widths (never under
-- the game's), the buttons too: each at least 80, else its label and 28.
local function BothWordsFit(row)
 local width = M.Glyphs(row.text:GetText(), 13) + 6 + M.Glyphs("just added", 10)
 for _, id in ipairs(row.tagIds) do if id ~= "NEW" then width = width + 5 + M.Glyphs(WORDS[id][1], 10) end end
 local buttons = 0
 for i, button in ipairs(row.buttons) do buttons = buttons + math.max(80, M.Glyphs(button.label:GetText(), 13) + 28) + (i > 1 and 6 or 0) end
 return row.text:GetLeft() + width <= row:GetRight() - 10 - buttons - 4
end
do
 local E, f = Session("ROGUE")
 local Nav = E.SettingsNav
 local function Tags(key) return table.concat(f.checks[key].tagIds, ",") end
 -- from: the version the account updated from (nil: no words at all).
 local function Expect(from, label)
  local new = from and NewSince(from) or {}
  for key in pairs(f.checks) do
   local want = {}
   if new[key] then want[#want + 1] = "NEW" end
   if TESTING[key] then want[#want + 1] = "TEST" end
   if f.checks[key].unavailable then want[#want + 1] = "SOON" end
   equal(Tags(key), table.concat(want, ","), label .. " " .. key)
  end
 end
 local function Updated(from, into)
  E.settings.justAddedFrom, E.settings.justAddedVersion = from, into
  f:Hide(); f:Show(); Flush()
 end
 -- The data: every option Nav says a release added is a row here, from a
 -- release with notes, and its own rows are exactly the ones written out above.
 local releases = {}
 for _, version in ipairs({"1.6.0", "1.7.0", "1.7.1"}) do releases[version] = true end
 local leads = {}
 for key, version in pairs(Nav.ADDED) do
  equal(f.checks[key] ~= nil, true, key .. ": a release added a row that exists")
  equal(releases[version], true, key .. ": added in a release with notes (" .. version .. ")")
  if Nav.Lead(key) then leads[version] = leads[version] or {}; table.insert(leads[version], key) end
 end
 for version, keys in pairs(LEADS) do
  local want = {}
  for _, key in ipairs(keys) do want[#want + 1] = key end
  table.sort(want); table.sort(leads[version] or {})
  equal(table.concat(leads[version] or {}, ","), table.concat(want, ","), version .. "'s options, one row each")
 end
 equal(Nav.ADDED.statTrackerStrength .. " " .. Nav.ADDED.thickFrameEdge .. " " .. Nav.ADDED.castBarCustomColour .. " " .. Nav.ADDED.minimapDrawerColumns
  .. " " .. Nav.ADDED.squareMinimapScale, "1.7.0 1.7.0 1.7.0 1.7.0 1.7.1", "the rows under a new option carry its release too")
 equal(tostring(Nav.Lead("squareMinimap")) .. " " .. tostring(Nav.Lead("squareMinimapScale")), "true false",
  "Square Size goes with Square Minimap (shown only with it): one lead for 1.7.1")
 Expect(nil, "no version saved:")
 -- Only the Raid-style Party Outline says experimental; the eighteen the
 -- user saw working in game (2026-10-15) don't, here or in a release.
 local seen = {}
 for _, key in ipairs(SEEN_WORKING) do
  equal(f.checks[key] ~= nil and E.SettingsRules.NeedsTesting(key) == false and TESTING[key] == nil, true, key .. ": seen working, not experimental")
  if Tags(key) == "" then seen[#seen + 1] = key end
 end
 equal(#seen .. " " .. Tags("partyOutline") .. " " .. tostring(E.SettingsRules.NeedsTesting("partyOutline")), "18 TEST true",
  "the eighteen say nothing, the Raid-style Party Outline still says experimental")
 Updated("1.5.5", "9.9.9")
 Expect("1.5.5", "updated from 1.5.5:")
 equal(Tags("darkWindows") .. " " .. Tags("blackPages") .. " " .. Tags("thickFrames") .. " " .. Tags("thickFrameRings") .. " " .. Tags("partyOutline"),
  "NEW  NEW  NEW,TEST", "for example: Dark Windows and Thick Frames say it, the ticks under them don't; the Party Outline says experimental too")
 Updated("1.6.0", "9.9.9")
 Expect("1.6.0", "updated from 1.6.0:")
 equal(Tags("flatBars") .. " " .. Tags("statTracker") .. " " .. Tags("castBarColour"), " NEW NEW", "from 1.6.0 only 1.7.0's options say it")
 Updated("1.7.0", "9.9.9")
 Expect("1.7.0", "updated from 1.7.0:")
 equal(Tags("statTracker") .. " " .. Tags("squareMinimap") .. " " .. Tags("squareMinimapScale"), " NEW ", "from 1.7.0 only 1.7.1's Square Minimap says it, not its Square Size")
 Updated("1.7.1", "9.9.9")
 Expect("1.7.1", "updated from 1.7.1 (nothing newer here):")
 -- Never an option from a release after the one running (a copy of 1.6.0
 -- with 1.7.0's rows in it): only up to the version it runs.
 E.version = "1.6.0"
 Updated("1.5.5", "1.6.0")
 equal(Tags("darkWindows") .. " " .. Tags("thickFrames") .. " " .. Tags("statTracker") .. " " .. Tags("partyOutline"), "NEW   TEST",
  "running 1.6.0: its own options, not 1.7.0's")
 E.version = "9.9.9"
 Updated("1.5.5", "9.9.9")
 equal(Tags("darkWindows") .. " " .. Tags("darkAuraShadows") .. " " .. Tags("autoRepair") .. " " .. Tags("cursorRing"), "NEW   ", "for example: nothing says it moved")
 -- An option a release added with buttons after its name is TIGHT exactly
 -- when "just added" and its other words wouldn't clear its first button.
 -- None is now: Clean Minimap's Style and Cast Bar Colour were, while they
 -- said experimental too.
 E.settings.cleanMinimap = true
 local measured = {}
 for key in pairs(Nav.ADDED) do
  local row = f.checks[key]
  if Nav.Lead(key) and row.buttons then
   local home = f.rowHome[key]
   f:SelectCategory(home.tab, home.sub); Flush()
   local fits = BothWordsFit(row)
   measured[key] = fits
   equal(Nav.TIGHT[key] == true, not fits, key .. (fits and ": room for just added and its other words" or ": no room for just added and its other words, so only those"))
  end
 end
 for key in pairs(Nav.TIGHT) do equal(Nav.ADDED[key] ~= nil, true, key .. ": TIGHT only lists new options") end
 equal(tostring(measured.cleanMinimapStyle) .. " " .. tostring(measured.castBarColour) .. " " .. tostring(next(Nav.TIGHT)), "true true nil",
  "Clean Minimap's Style and Cast Bar Colour measured: room for just added now, so nothing is TIGHT")
 E.settings.cleanMinimap = nil
 equal(E.SettingsNav.MOVED, nil, "no moved list any more")
 -- Every row with words, on its page, as it shows.
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = true, true, true
 E.settings.cleanMinimap = true
 local looked, worded, newCount = 0, 0, 0
 local saying = NewSince("1.5.5")
 for _ in pairs(saying) do newCount = newCount + 1 end
 for key, row in pairs(f.checks) do
  if TESTING[key] or row.unavailable or saying[key] then worded = worded + 1 end
  if #row.tagIds > 0 then
   local home = f.rowHome[key]
   f:SelectCategory(home.tab, home.sub); Flush()
   TagLook(row, key)
   looked = looked + 1
  end
 end
 equal(newCount, 13, "updated from 1.5.5: the thirteen options of 1.6.0, 1.7.0 and 1.7.1 say just added")
 equal(looked == worded and looked > newCount, true, "every row with words checked (" .. looked .. ": the thirteen just added, the Party Outline also experimental, and the coming soon ones)")
 -- Clean Minimap's Style row: its name and "just added" stop short of its
 -- Hover and Drawer buttons (the glyph widths, never under the game's), as
 -- they show to an account that updated.
 Updated("1.5.5", "9.9.9")
 Open(f, "map")
 local style = f.checks.cleanMinimapStyle
 local words = M.Glyphs(style.text:GetText(), 13)
 for i, id in ipairs(style.tagIds) do words = words + (i == 1 and 6 or 5) + M.Glyphs(style.tags[i]:GetText(), 10) end
 equal(table.concat(style.tagIds, ",") .. " " .. tostring(style.text:GetLeft() + words <= style.buttons[1]:GetLeft() - 4), "NEW true",
  "Clean Minimap's Style: its name and just added clear its Hover button")
 Updated(nil, nil)
 E.settings.darkMode, E.settings.darkAuraBorders, E.settings.darkWindows = nil, nil, nil
 E.settings.cleanMinimap = nil
 equal(table.concat(f.checks.contextMenus.tagIds, ","), "SOON", "Context Menus says coming soon")
 -- A fresh install ("" from), or a version other than the one running
 -- (the account's next update decides again), says nothing.
 for _, case in ipairs({{"", "9.9.9"}, {"1.5.5", "1.7.0"}, {"1.5.5", ""}, {"1.5.5", nil}, {"dev", "9.9.9"}, {"9.9.9", "9.9.9"}}) do
  Updated(case[1], case[2])
  Expect(nil, "from " .. tostring(case[1]) .. " into " .. tostring(case[2]) .. ":")
 end
 Updated("1.5.5", "9.9.9")
 f:SetSetupMode(true); Flush()
 Expect(nil, "in setup:")
 f:SetSetupMode(false); Flush()
 Expect("1.5.5", "after setup:")
 -- Search results carry the same words, after the option's name.
 M.Results(f, "dark windows")
 local result = f.visibleRows[1]
 equal(result.target.settingKey .. " " .. table.concat(result.tagIds, ","), "darkWindows NEW", "a result shows its option's words")
 TagLook(result, "the Dark Windows result")
 M.Results(f, "raid-style party outline")
 result = nil
 for _, shown in ipairs(f.visibleRows) do if shown.target and shown.target.settingKey == "partyOutline" then result = shown end end
 equal(result and (result.target.settingKey .. " " .. table.concat(result.tagIds, ",")), "partyOutline NEW,TEST", "the Party Outline's result: just added and experimental")
 TagLook(result, "the Raid-style Party Outline result")
 -- "experimental" finds the experimental option, only it.
 local found = M.Results(f, "experimental")
 table.sort(found)
 equal(table.concat(found, ","), "partyOutline", "searching experimental finds the Raid-style Party Outline alone")
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
 -- (a jump to Dark Mode's page: Tab, Tab and Space there flip a tick)
 M.Results(f, "darken class colours"); f.visibleRows[1]:Click(); Flush()
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
 local MINOR = {a = true, an = true, ["and"] = true, the = true, of = true, on = true, to = true, ["in"] = true, from = true, ["for"] = true, with = true,
  per = true}
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
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle = true, "drawer"
 E.settings.statTracker = true
 E.settings.squareMinimap = true
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
 equal(sliders, 13, "every slider row measured (Darkness, damage text size, seven cursor sliders, the drawer's icons per row, the Stat Tracker's Panel Size"
  .. " and Stats per Line, Square Minimap's Square Size)")
 E.settings.cursorRing, E.settings.cursorCastRing, E.settings.cursorTrail = nil, nil, nil
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle = nil, nil
 E.settings.statTracker = nil
 E.settings.squareMinimap = nil
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

-- Clean Minimap's style (Hover or Drawer) and the drawer's
-- Icons per Row: folded under Clean Minimap, Icons per Row only with Drawer
-- chosen, opening and folding at once keeping the scroll; each choice saved
-- and applied through Modules/MinimapTools.lua at once; the footer's
-- default; search words; the walkthrough's Map & Minimap page.
do
 local E, f = Session("PRIEST")
 -- The real defaults (Core/Init.lua): off, Hover, five a row.
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 local defaults = real.settingDefaults
 equal(tostring(defaults.cleanMinimap) .. " " .. defaults.cleanMinimapStyle .. " " .. defaults.minimapDrawerColumns, "false hover 5",
  "Clean Minimap off by default; when on, Hover (as before) and five icons a row")
 equal(real.reloadSettings.cleanMinimapStyle or real.reloadSettings.minimapDrawerColumns, nil, "both apply without a reload")
 for key, value in pairs(defaults) do E.settingDefaults[key] = value end
 local calls = {}
 E.modules.MinimapTools = {Discover = function() calls[#calls + 1] = "discover" end, Refresh = function() calls[#calls + 1] = "refresh" end,
  LayoutDrawer = function() calls[#calls + 1] = "layout" end}
 local clean, style, columns = f.checks.cleanMinimap, f.checks.cleanMinimapStyle, f.checks.minimapDrawerColumns
 Open(f, "map")
 equal(Keys(f), "minimap,squareMinimap,cleanMinimap,coordinates,mapQuestObjectives,movableMap,revealMap", "Clean Minimap off: its style and icons per row folded away")
 equal(style.rowKind .. " " .. style.labelText .. " " .. style.buttons[1].label:GetText() .. "/" .. style.buttons[2].label:GetText(), "choice Style Hover/Drawer",
  "the style is a choice row: Hover or Drawer")
 equal(columns.rowKind .. " " .. columns.labelText .. " " .. columns.info.low .. "-" .. columns.info.high, "slider Icons per Row 3-8", "icons per row: a slider from 3 to 8")
 -- A short window, so the page scrolls.
 M.Resize(f, 340)
 Open(f, "map")
 f:SetSettingsScroll(10)
 equal(f.settingsScroll:GetVerticalScroll(), 10, "the page scrolled a little")
 clean:Click(); Flush()
 equal(E.settings.cleanMinimap, true, "Clean Minimap on")
 equal(Keys(f), "minimap,squareMinimap,cleanMinimap,cleanMinimapStyle,coordinates,mapQuestObjectives,movableMap,revealMap", "its style opens right under it at once; icons per row waits for Drawer")
 equal(style.selected, 1, "Hover chosen until Drawer is (as before)")
 equal(f.settingsScroll:GetVerticalScroll(), 10, "opening keeps the scroll")
 equal(style.depth == 1 and style.connV:IsShown() and style.dependencyDisabled == nil, true, "the style sits under Clean Minimap, never greyed")
 calls = {}
 style.buttons[2]:Click(); Flush()
 equal(E.settings.cleanMinimapStyle .. " " .. style.selected, "drawer 2", "Drawer chosen and saved")
 equal(Keys(f), "minimap,squareMinimap,cleanMinimap,cleanMinimapStyle,minimapDrawerColumns,coordinates,mapQuestObjectives,movableMap,revealMap",
  "Icons per Row opens under the style at once")
 equal(columns.depth, 1, "Icons per Row sits under Clean Minimap too")
 equal(table.concat(calls, ","), "discover,refresh", "the drawer applies at once (MinimapTools)")
 equal(f.settingsScroll:GetVerticalScroll(), 10, "choosing keeps the scroll")
 M.NoOverlaps(f, "Clean Minimap's drawer rows"); M.Fits(f, "Clean Minimap's drawer rows")
 M.SubOptionsFollow(f, "Clean Minimap's drawer rows", ParentOf(E))
 equal(columns.text:GetText(), "Icons per Row: 5", "five icons a row by default")
 calls = {}
 columns.slider:SetValue(7)
 equal(E.settings.minimapDrawerColumns .. " " .. columns.text:GetText() .. " " .. table.concat(calls, ","), "7 Icons per Row: 7 layout",
  "the slider saves and lays the drawer out again at once")
 columns.slider:SetValue(99)
 equal(E.settings.minimapDrawerColumns, 8, "never more than eight")
 E.settings.minimapDrawerColumns = nil
 -- The keyboard flips the choice too.
 f:FocusRow(style); f.keys:Fire("OnSpacePressed")
 equal(E.settings.cleanMinimapStyle, "hover", "Space on the row: back to Hover")
 equal(columns:IsShown(), false, "Hover: Icons per Row folds away")
 f:ClearRowFocus()
 -- The footer: what each does, Hover by default.
 local _, help, extras = M.Hover(f, style)
 equal(Has(help, "Hover hides addon buttons") and Has(help, "Drawer tucks them") and Has(extras, "Default: Hover."), true, "the style's description and default: " .. help .. " | " .. extras)
 equal(M.LinesIn(help, 570, 12) <= 2, true, "two footer lines at most")
 _, help, extras = M.Hover(f, columns)
 equal(Has(help, "each row of the drawer") and Has(extras, "Default: 5."), true, "icons per row's description and default: " .. help .. " | " .. extras)
 -- Search finds them by drawer, minimap buttons and tidy, folded or not.
 clean:Click(); Flush()
 equal(E.settings.cleanMinimap, false, "Clean Minimap off again")
 equal(style:IsShown() or columns:IsShown(), false, "both fold away with it")
 for _, query in ipairs({"drawer", "minimap buttons", "tidy"}) do
  local found = M.Results(f, query)
  table.sort(found)
  equal(table.concat(found, ","), "cleanMinimap,cleanMinimapStyle,minimapDrawerColumns", "search " .. query .. " finds Clean Minimap and its drawer rows")
 end
 f.searchBox:SetText(""); Flush()
 -- A jump to a folded option lands on Clean Minimap.
 equal(f:JumpTo("minimapDrawerColumns"), clean, "a jump to Icons per Row lands on Clean Minimap while folded")
 M.Resize(f, 650)
 -- The walkthrough's Map & Minimap page offers the style with Clean Minimap on.
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle = true, "drawer"
 f:SetSetupMode(true); Flush(); f.setupPreset = "qol"
 local shown = false
 for page = 1, 40 do
  f.setupPage = page; f:RenderSetup(); Flush()
  if f.sectionTitle:GetText() == "Map & Minimap" then shown = true; break end
 end
 equal(shown and Keys(f):find("cleanMinimap,cleanMinimapStyle,minimapDrawerColumns", 1, true) ~= nil, true, "the walkthrough's Map & Minimap page: " .. Keys(f))
 M.NoOverlaps(f, "walkthrough Map & Minimap with the drawer"); M.Fits(f, "walkthrough Map & Minimap with the drawer")
 f:SetSetupMode(false); Flush()
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle = nil, nil
end

-- Square Minimap (Map & Minimap): a tick under Minimap,
-- indented, greyed while Minimap is off (the footer says so); off by
-- default, live, never a reload; applied at once through Classic/Minimap.lua
-- with its own chat line (in a fight: the minimap changes when it ends;
-- Minimap waiting for a reload: it shows once that's applied); its words,
-- summary and search words; no words after its name (seen working in game,
-- 2026-10-15), and "just added" (once a release lists it) fits its row;
-- offered on the walkthrough's Map & Minimap page with Minimap on, left out
-- with it off, like Show Gryphons.
do
 local E, f = Session("WARRIOR")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 equal(real.settingDefaults.squareMinimap, false, "Square Minimap off by default (Core/Init.lua)")
 equal(real.reloadSettings.squareMinimap, nil, "it applies without a reload")
 for key in pairs(real.reloadSettings) do E.reloadSettings[key] = true end
 E.settingDefaults.squareMinimap = false
 E.settings.minimap = true
 f:RefreshDependencies()
 Open(f, "map")
 M.NoOverlaps(f, "Map & Minimap with Square Minimap"); M.Fits(f, "Map & Minimap with Square Minimap")
 M.SubOptionsFollow(f, "Map & Minimap with Square Minimap", ParentOf(E))
 local row = f.checks.squareMinimap
 equal(row.text:GetText() .. " / " .. row.rowKind .. " / " .. tostring(row:IsVisible()) .. " / " .. tostring(row:GetChecked()) .. " / "
  .. tostring(row.depth) .. " / " .. tostring(row.dependencyDisabled), "Square Minimap / tick / true / false / 1 / false",
  "a tick row under Minimap, off, not greyed")
 equal(Keys(f):find("^minimap,squareMinimap,cleanMinimap,") ~= nil, true, "right under Minimap, before Clean Minimap")
 equal(table.concat(row.tagIds, ","), "", "no words after its name: seen working in game, not in a release's list yet")
 TagLook(row, "Square Minimap")
 local _, help, extras = M.Hover(f, row)
 equal(help, "Square Minimap  A square map in a thin dark frame, the zone's name on top and the buttons on its edges. In Dark Mode its fine line follows the Darkness slider.",
  "its words")
 equal(M.LinesIn(help, 570, 12) <= 2, true, "two footer lines at most")
 equal(extras, "Default: Off.", "no reload line, nothing to switch on first, off by default")
 equal(row.summary, "A square map in a thin dark frame instead of the round border.", "its summary")
 -- Live, with its own chat line.
 local refreshes, waits, status = 0, false, nil
 local realClassic, realStatus = E.Classic, E.Status
 E.Classic = setmetatable({RefreshSquareMinimap = function() refreshes = refreshes + 1; return not waits end}, {__index = realClassic})
 E.Status = function(_, m) status = m end
 row:Click()
 equal(tostring(E.settings.squareMinimap) .. " " .. refreshes .. " " .. status, "true 1 Square Minimap enabled.", "a click switches it on, live")
 row:Click()
 equal(tostring(E.settings.squareMinimap) .. " " .. refreshes .. " " .. status, "false 2 Square Minimap disabled.", "and off, live")
 waits = true
 row:Click()
 equal(status, "Square Minimap enabled. The minimap changes when combat ends.", "in a fight: the minimap follows when it ends")
 row:Click()
 equal(status, "Square Minimap disabled. The minimap changes when combat ends.", "off in a fight: the same note")
 waits = false
 -- Minimap ticked but not applied yet (it waits for a reload).
 local get = E.GetSetting
 E.GetSetting = function(self, key) if key == "minimap" then return false end; return get(self, key) end
 row:Click()
 equal(status, "Square Minimap enabled. It shows once Minimap is applied.", "Minimap waiting for a reload: it shows once that's applied")
 row:Click()
 equal(status, "Square Minimap disabled.", "off: no note")
 E.GetSetting = get
 E.Classic = {}
 row:Click()
 equal(tostring(E.settings.squareMinimap) .. " " .. status, "true Square Minimap enabled.", "without Classic loaded the tick still saves")
 row:Click()
 E.Classic, E.Status = realClassic, realStatus
 equal(tostring(E.settings.squareMinimap) .. " " .. refreshes, "false 6", "off again; each click with Classic loaded refreshed it once")
 -- Minimap off: greyed, the footer names it.
 E.settings.minimap = false
 f:RefreshDependencies()
 local _, _, grey = M.Hover(f, row)
 equal(tostring(row.dependencyDisabled) .. " / " .. grey, "true / Switch on Minimap first.  Default: Off.", "Minimap off: greyed, its note names Minimap")
 row:Click()
 equal(tostring(E.settings.squareMinimap) .. " " .. tostring(row:GetChecked()) .. " " .. refreshes, "false false 6", "greyed: a click changes nothing")
 E.settings.minimap = true
 f:RefreshDependencies()
 equal(row.dependencyDisabled, false, "Minimap back on: not greyed")
 for _, query in ipairs({"square", "shape", "corners", "minimap frame", "darkness", "square minimap", "experimental"}) do
  local found = M.Results(f, query)
  local hit = false
  for _, key in ipairs(found) do if key == "squareMinimap" then hit = true end end
  equal(hit, query ~= "experimental", "searching " .. query .. (query ~= "experimental" and " finds Square Minimap" or " no longer finds Square Minimap"))
 end
 f.searchBox:SetText(""); Flush()
 -- 1.7.1 lists it (Core/SettingsNav.lua ADDED): an account that updated
 -- from 1.7.0 sees "just added", and it fits.
 local Nav = E.SettingsNav
 equal(Nav.ADDED.squareMinimap, "1.7.1", "added in 1.7.1")
 E.settings.justAddedFrom, E.settings.justAddedVersion = "1.7.0", "9.9.9"
 f:Hide(); f:Show(); Flush(); Open(f, "map")
 equal(table.concat(row.tagIds, ","), "NEW", "listed in a release: just added")
 TagLook(row, "Square Minimap, just added")
 E.settings.justAddedFrom, E.settings.justAddedVersion = nil, nil
 f:Hide(); f:Show(); Flush()
 -- The walkthrough.
 for _, on in ipairs({true, false}) do
  E.settings.minimap = on
  f:SetSetupMode(false); Flush(); f:SetSetupMode(true); Flush(); f.setupPreset = "qol"
  local shown = false
  for page = 1, 40 do
   f.setupPage = page; f:RenderSetup(); Flush()
   if f.sectionTitle:GetText() == "Map & Minimap" then shown = true; break end
  end
  equal(shown, true, "the walkthrough has its Map & Minimap page")
  equal(f.checks.squareMinimap:IsShown(), on, "the walkthrough's Map & Minimap page " .. (on and "offers it with Minimap on" or "leaves it out with Minimap off"))
  M.NoOverlaps(f, "walkthrough Map & Minimap"); M.Fits(f, "walkthrough Map & Minimap")
  M.SubOptionsFollow(f, "walkthrough Map & Minimap", ParentOf(E))
 end
 f:SetSetupMode(false); Flush()
 E.settings.minimap = true
end

-- Square Size (Map & Minimap): a slider, 75% to 150% in fives, 100% by
-- default (Core/Init.lua), never a reload. Hidden (not greyed) while Square
-- Minimap is off; ticking it opens the slider right under it at its indent
-- at once, keeping the scroll, and the page reflows with no gap or overlap
-- either way. Each move saves and refreshes the minimap (Classic/Minimap.lua)
-- at once; in a fight the minimap waits, said once a fight. Greyed with
-- Square Minimap while Minimap is off: not dragged, a move puts it back. A
-- saved value it can't read shows 100%; one beyond its ends, the nearest.
-- The footer's words and default, search, a jump while it's hidden, no
-- words after its name, the walkthrough.
do
 local E, f = Session("MAGE")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 equal(real.settingDefaults.squareMinimapScale, 100, "Square Size 100% by default (Core/Init.lua): nothing changes for anyone who never moves it")
 equal(real.reloadSettings.squareMinimapScale, nil, "it applies without a reload")
 for key in pairs(real.reloadSettings) do E.reloadSettings[key] = true end
 E.settings.minimap = true
 f:RefreshDependencies()
 local square, size = f.checks.squareMinimap, f.checks.squareMinimapScale
 local coords = f.checks.coordinates
 Open(f, "map")
 -- Off: hidden, not greyed, and nothing left where it would be.
 equal(Keys(f), "minimap,squareMinimap,cleanMinimap,coordinates,mapQuestObjectives,movableMap,revealMap", "Square Minimap off: Square Size hidden")
 equal(size:IsShown(), false, "the slider not on show")
 equal(N(square:GetBottom() - coords:GetTop()), "4", "Coordinates' line right under Square Minimap, no gap")
 equal(size.rowKind .. " " .. size.labelText .. " " .. size.info.low .. "-" .. size.info.high .. " " .. size.info.step .. " " .. tostring(size.wide),
  "slider Square Size 75-150 5 nil", "a half-line slider row, 75 to 150 in fives")
 equal(table.concat(size.tagIds, ","), "", "no words after its name (it goes with Square Minimap above it)")
 -- A short window, so the page scrolls; ticking opens it at once.
 M.Resize(f, 340)
 Open(f, "map")
 f:SetSettingsScroll(10)
 local calls, waits, status = 0, false, {}
 local realClassic, realStatus = E.Classic, E.Status
 E.Classic = setmetatable({RefreshSquareMinimap = function() calls = calls + 1; return not waits end}, {__index = realClassic})
 E.Status = function(_, m) status[#status + 1] = m end
 square:Click(); Flush()
 equal(tostring(E.settings.squareMinimap) .. " " .. table.concat(status, "|"), "true Square Minimap enabled.", "Square Minimap on")
 status = {}
 equal(Keys(f), "minimap,squareMinimap,squareMinimapScale,cleanMinimap,coordinates,mapQuestObjectives,movableMap,revealMap",
  "Square Size opens right under Square Minimap at once")
 equal(f.settingsScroll:GetVerticalScroll(), 10, "opening keeps the scroll")
 equal(size:IsVisible() and size.text:GetText(), "Square Size: 100%", "shown at 100%")
 equal(size.depth == 1 and size.connV:IsShown() and math.abs(size:GetLeft() - square:GetLeft()) < .01 and math.abs(size:GetWidth() - square:GetWidth()) < .01, true,
  "at Square Minimap's indent and width, joined by its line")
 equal(N(square:GetBottom() - size:GetTop()) .. " " .. N(size:GetBottom() - coords:GetTop()), "4 4", "right under it, and Coordinates' line under it: no gap")
 equal(size.dependencyDisabled == false and size.alpha == 1 and size.slider:IsMouseEnabled(), true, "with Minimap on: not greyed, dragged")
 M.NoOverlaps(f, "Square Size open"); M.Fits(f, "Square Size open")
 M.SubOptionsFollow(f, "Square Size open", ParentOf(E))
 -- Each move saves and refreshes the minimap at once.
 calls = 0
 size.slider:SetValue(120)
 equal(E.settings.squareMinimapScale .. " " .. size.text:GetText() .. " " .. calls, "120 Square Size: 120% 1", "a move saves and refreshes the minimap at once")
 size.slider:SetValue(400)
 equal(E.settings.squareMinimapScale .. " " .. size.text:GetText(), "150 Square Size: 150%", "never more than 150%")
 size.slider:SetValue(10)
 equal(E.settings.squareMinimapScale .. " " .. size.text:GetText(), "75 Square Size: 75%", "never less than 75%")
 equal(#status, 0, "out of a fight: no chat line")
 -- In a fight the minimap waits: said once a drag.
 waits, calls = true, 0
 size.slider:SetValue(90); size.slider:SetValue(95)
 equal(E.settings.squareMinimapScale .. " " .. calls .. " " .. table.concat(status, "|"), "95 2 Square Size: the minimap changes when combat ends.",
  "in a fight: saved, the minimap asked each time (it books the pass), said once a drag")
 size.slider:Fire("OnMouseUp")
 size.slider:SetValue(85)
 equal(#status .. " " .. tostring(status[2]), "2 Square Size: the minimap changes when combat ends.", "the next drag in the fight: said again")
 waits = false
 size.slider:SetValue(100)
 equal(#status, 2, "after the fight: done at once, nothing said")
 waits = true
 size.slider:SetValue(105)
 equal(#status .. " " .. tostring(status[3]), "3 Square Size: the minimap changes when combat ends.", "the next fight: said again")
 waits = false
 size.slider:SetValue(100)
 -- Without Classic loaded the slider still saves.
 E.Classic = {}
 size.slider:SetValue(110)
 equal(E.settings.squareMinimapScale, 110, "without Classic loaded it still saves")
 E.Classic = setmetatable({RefreshSquareMinimap = function() calls = calls + 1; return not waits end}, {__index = realClassic})
 -- The footer: its words and its default.
 local _, help, extras = M.Hover(f, size)
 equal(help, "Square Size  How big the square minimap is, its frame and buttons too, from 75% to 150%. It works on top of Edit Mode's Minimap Size.",
  "its words")
 equal(M.LinesIn(help, 570, 12) <= 2 and not Has(help, EM), true, "two footer lines at most, no em dash")
 equal(extras, "Default: 100%.", "100% by default, no reload line")
 -- Minimap off: greyed with Square Minimap; not dragged, a move puts it back.
 E.settings.minimap = false
 f:RefreshDependencies()
 equal(tostring(size.dependencyDisabled) .. " " .. size.alpha .. " " .. tostring(size.slider:IsMouseEnabled()), "true 0.45 false",
  "Minimap off: greyed, its slider not dragged")
 _, _, extras = M.Hover(f, size)
 equal(extras, "Switch on Minimap first.  Default: 100%.", "its note names Minimap, up the chain")
 calls = 0
 size.slider:SetValue(140)
 equal(E.settings.squareMinimapScale .. " " .. size.text:GetText() .. " " .. size.slider:GetValue() .. " " .. calls, "110 Square Size: 110% 110 0",
  "a move while greyed: nothing saved, the slider back, the minimap untouched")
 E.settings.minimap = true
 f:RefreshDependencies()
 equal(tostring(size.dependencyDisabled) .. " " .. size.alpha .. " " .. tostring(size.slider:IsMouseEnabled()), "false 1 true", "Minimap on again: free")
 -- A saved value it can't read: 100%; one beyond its ends: the nearest.
 for _, case in ipairs({{"big", "100%"}, {0 / 0, "100%"}, {math.huge, "100%"}, {400, "150%"}, {-5, "75%"}, {nil, "100%"}}) do
  E.settings.squareMinimapScale = case[1]
  size:SetChecked()
  equal(size.text:GetText(), "Square Size: " .. case[2], "saved " .. tostring(case[1]) .. ": shows " .. case[2])
 end
 equal(E.settings.squareMinimapScale, nil, "showing it saves nothing over it")
 -- Unticked: it folds away at once, keeping the scroll, the page closing up.
 f:SetSettingsScroll(10)
 square:Click(); Flush()
 equal(E.settings.squareMinimap, false, "Square Minimap off")
 equal(size:IsShown(), false, "Square Size folds away at once")
 equal(Keys(f), "minimap,squareMinimap,cleanMinimap,coordinates,mapQuestObjectives,movableMap,revealMap", "the page without it")
 equal(N(square:GetBottom() - coords:GetTop()), "4", "Coordinates' line back right under Square Minimap: no gap")
 equal(f.settingsScroll:GetVerticalScroll(), 10, "closing keeps the scroll")
 M.NoOverlaps(f, "Square Size folded"); M.Fits(f, "Square Size folded")
 E.Classic, E.Status = realClassic, realStatus
 -- With Clean Minimap's drawer open beside it: no overlap either.
 E.settings.squareMinimap, E.settings.cleanMinimap, E.settings.cleanMinimapStyle = true, true, "drawer"
 Open(f, "map")
 M.NoOverlaps(f, "Square Size with the drawer rows"); M.Fits(f, "Square Size with the drawer rows")
 M.SubOptionsFollow(f, "Square Size with the drawer rows", ParentOf(E))
 E.settings.cleanMinimap, E.settings.cleanMinimapStyle = nil, nil
 M.Resize(f, 650)
 -- Search finds it, hidden or not; a jump while hidden lands on Square Minimap.
 E.settings.squareMinimap = false
 for _, query in ipairs({"size", "scale", "bigger", "smaller", "square size", "minimap size"}) do
  local found = M.Results(f, query)
  local hit = false
  for _, key in ipairs(found) do if key == "squareMinimapScale" then hit = true end end
  equal(hit, true, "searching " .. query .. " finds Square Size")
 end
 -- Its result, hovered while Square Minimap is off, names that switch.
 M.Results(f, "square size")
 local result
 for _, row in ipairs(f.visibleRows or {}) do if row.target == size then result = row end end
 f:RefreshDependencies()
 local _, _, waitsFor = M.Hover(f, result)
 equal(waitsFor, "Switch on Square Minimap first.  Default: 100%.", "its search result, Square Minimap off: switch that on first")
 f.searchBox:SetText(""); Flush()
 equal(f:JumpTo("squareMinimapScale"), square, "a jump to Square Size lands on Square Minimap while it's off")
 E.settings.squareMinimap = true
 equal(f:JumpTo("squareMinimapScale"), size, "and on the slider itself while it's on")
 -- The walkthrough's Map & Minimap page: right under Square Minimap with
 -- Minimap on, left out with it off.
 for _, on in ipairs({true, false}) do
  E.settings.minimap = on
  f:SetSetupMode(false); Flush(); f:SetSetupMode(true); Flush(); f.setupPreset = "qol"
  local shown = false
  for page = 1, 40 do
   f.setupPage = page; f:RenderSetup(); Flush()
   if f.sectionTitle:GetText() == "Map & Minimap" then shown = true; break end
  end
  equal(shown, true, "the walkthrough has its Map & Minimap page")
  equal(size:IsShown(), on, "the walkthrough's Map & Minimap page " .. (on and "offers Square Size" or "leaves Square Size out with Minimap off"))
  if on then
   equal(Keys(f):find("squareMinimap,squareMinimapScale,", 1, true) ~= nil, true, "after Square Minimap: " .. Keys(f))
   -- Minimap itself (reload-only) is left off the walkthrough, so the
   -- slider goes under Square Minimap, one level in, still in its column.
   equal(f.checks.minimap:IsShown(), false, "the walkthrough leaves Minimap out")
   equal((square.depth or 0) .. " " .. size.depth .. " " .. N(size:GetLeft() - square:GetLeft()) .. " " .. N(square:GetBottom() - size:GetTop())
    .. " " .. tostring(size.connV:IsShown()), "0 1 22 4 true", "right under Square Minimap, one level in, joined by its line")
  end
  M.NoOverlaps(f, "walkthrough Map & Minimap with Square Size"); M.Fits(f, "walkthrough Map & Minimap with Square Size")
  M.SubOptionsFollow(f, "walkthrough Map & Minimap with Square Size", ParentOf(E))
 end
 f:SetSetupMode(false); Flush()
 E.settings.minimap, E.settings.squareMinimap, E.settings.squareMinimapScale = true, nil, nil
end

-- Cast Bar Colour (Casting): a whole line under its own Colour
-- heading with Match look, Yellow, Grey, Class and Custom, its name (and
-- "just added", for an account that updated) clear of the first button;
-- greyed while Cast Bars is off
-- (a click changes nothing), never indented under it; each choice saved and
-- applied at once (Classic/CastBars.lua ns.RefreshCastColours); Custom opens
-- the colour picker and Custom Cast Bar Colour under it (folded until then),
-- whose click opens the picker again; the picked colour saved as hex, a
-- cancel puts back the colour and the choice from before; the footer's
-- descriptions and defaults; search; a jump to the folded row; the keyboard.
-- (The bars themselves: Tools/TestCastBarColour.lua.)
do
 local E, f = Session("PALADIN")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 local defaults = real.settingDefaults
 equal(defaults.castBarColour .. " " .. defaults.castBarCustomColour, "auto C7CCD6", "Match look by default; Custom starts at the light grey")
 equal(real.reloadSettings.castBarColour or real.reloadSettings.castBarCustomColour, nil, "both apply without a reload")
 for key, value in pairs(defaults) do E.settingDefaults[key] = value end
 local refreshes, status = 0, nil
 E.Classic.RefreshCastColours = function() refreshes = refreshes + 1 end
 local say = E.Status
 E.Status = function(_, m) status = m end
 E.settings.castBars = true; f:RefreshDependencies()
 local row, swatch = f.checks.castBarColour, f.checks.castBarCustomColour
 Open(f, "casting")
 equal(PageText(f), "CAST BARS:castBars,advancedCastBar,advancedCastClassFill,advancedCastTicks,advancedCastLatency|COLOUR:castBarColour",
  "under its own Colour heading; Custom Cast Bar Colour folded away until Custom")
 local names = {}
 for i, button in ipairs(row.buttons) do names[i] = button.label:GetText() end
 equal(row.rowKind .. " " .. row.labelText .. " " .. table.concat(names, "/"), "choice Cast Bar Colour Match look/Yellow/Grey/Class/Custom",
  "a choice row with the five")
 equal(tostring(row.wide) .. " " .. N(row:GetWidth()) .. " " .. (row.depth or 0) .. " " .. tostring(row.connV:IsShown()), "true 718 0 false",
  "a whole line, never indented under Cast Bars")
 equal(row.selected .. " " .. tostring(row.dependencyDisabled) .. " " .. row.alpha, "1 false 1", "Match look chosen, available with Cast Bars on")
 -- Its name, and "just added" for an account that updated from before
 -- 1.7.0, stop short of the first button (the glyph widths, never under the
 -- game's); each button holds its name, in the row, clear of the next.
 local function Clears()
  local words = M.Glyphs(row.text:GetText(), 13)
  for i in ipairs(row.tagIds) do words = words + (i == 1 and 6 or 5) + M.Glyphs(row.tags[i]:GetText(), 10) end
  return table.concat(row.tagIds, ",") .. " " .. tostring(row.text:GetLeft() + words <= row.buttons[1]:GetLeft() - 4)
 end
 equal(Clears(), " true", "no words after its name (seen working in game), its name clears Match look")
 E.settings.justAddedFrom, E.settings.justAddedVersion = "1.6.0", "9.9.9"
 f:Hide(); f:Show(); Flush(); Open(f, "casting")
 equal(Clears(), "NEW true", "updated from 1.6.0: its name and just added clear Match look")
 TagLook(row, "Cast Bar Colour, just added")
 E.settings.justAddedFrom, E.settings.justAddedVersion = nil, nil
 f:Hide(); f:Show(); Flush(); Open(f, "casting")
 equal(Clears(), " true", "and with no version saved, no words again")
 for i, button in ipairs(row.buttons) do
  equal(M.Glyphs(button.label:GetText(), 13) <= button:GetWidth() - 8 and button:GetRight() <= row:GetRight() + .01, true, names[i] .. " fits its button, in the row")
  if i > 1 then equal(row.buttons[i - 1]:GetRight() <= button:GetLeft() - 5.99, true, names[i - 1] .. " clear of " .. names[i]) end
 end
 M.NoOverlaps(f, "Cast Bar Colour"); M.Fits(f, "Cast Bar Colour")
 -- Greyed while Cast Bars is off: named in the footer, a click changes nothing.
 E.settings.castBars = false; f:RefreshDependencies()
 equal(tostring(row.dependencyDisabled) .. " " .. row.alpha, "true 0.45", "greyed while Cast Bars is off")
 local _, help, extras = M.Hover(f, row)
 equal(extras, "Switch on Cast Bars first.  Default: Match look.", "it names Cast Bars, on the same page")
 row.buttons[3]:Click(); Flush()
 equal(tostring(E.settings.castBarColour) .. " " .. row.selected .. " " .. refreshes, "nil 1 0", "a click while greyed changes nothing")
 E.settings.castBars = true; f:RefreshDependencies()
 equal(tostring(row.dependencyDisabled) .. " " .. row.alpha, "false 1", "Cast Bars on frees it at once")
 -- Each choice saved and applied at once, with a word in chat.
 for i, want in ipairs({{"classic", "Classic yellow"}, {"grey", "light grey"}, {"class", "your class colour"}, {"auto", "matches the look"}}) do
  local index = ({classic = 2, grey = 3, class = 4, auto = 1})[want[1]]
  row.buttons[index]:Click(); Flush()
  equal(E.settings.castBarColour .. " " .. row.selected .. " " .. refreshes .. " " .. tostring(status), want[1] .. " " .. index .. " " .. i .. " Cast bar colour: " .. want[2] .. ".",
   names[index] .. " saved, applied at once, said")
  equal(swatch:IsShown(), false, names[index] .. ": no custom colour row")
 end
 -- Custom: the picker opens at the custom colour, and its row opens under the choice.
 local picker
 ColorPickerFrame = {SetupColorPickerAndShow = function(_, info) picker = info end, GetColorRGB = function() return 1, .5, 0 end}
 row.buttons[3]:Click(); Flush()
 refreshes = 0
 row.buttons[5]:Click(); Flush()
 equal(E.settings.castBarColour .. " " .. row.selected .. " " .. refreshes, "custom 5 1", "Custom chosen and applied")
 equal(picker ~= nil and string.format("%.3f,%.3f,%.3f %s", picker.r, picker.g, picker.b, tostring(picker.hasOpacity)), "0.780,0.800,0.839 false",
  "the colour picker opens at once, at the custom colour (the light grey), no opacity")
 equal(Keys(f), "castBars,advancedCastBar,advancedCastClassFill,advancedCastTicks,advancedCastLatency,castBarColour,castBarCustomColour",
  "Custom Cast Bar Colour opens under the choice at once")
 equal(swatch.rowKind .. " " .. swatch.labelText .. " " .. swatch.depth .. " " .. tostring(swatch.connV:IsShown()) .. " " .. Colour(swatch.swatch.fill),
  "colour Custom Cast Bar Colour 1 true 0.780,0.800,0.839", "a colour row under the choice, its swatch the light grey")
 M.NoOverlaps(f, "Custom Cast Bar Colour"); M.Fits(f, "Custom Cast Bar Colour")
 M.SubOptionsFollow(f, "Custom Cast Bar Colour", ParentOf(E))
 picker.swatchFunc(); Flush()
 equal(E.settings.castBarCustomColour .. " " .. E.settings.castBarColour .. " " .. refreshes .. " " .. Colour(swatch.swatch.fill), "FF8000 custom 2 1.000,0.502,0.000",
  "the picked colour saved as hex, applied at once, the swatch shows it")
 picker.cancelFunc(); Flush()
 equal(E.settings.castBarCustomColour .. " " .. E.settings.castBarColour .. " " .. row.selected .. " " .. refreshes .. " " .. tostring(swatch:IsShown()),
  "C7CCD6 grey 3 3 false", "cancel puts back the colour and the choice from before, and folds the row away")
 -- The row's own click opens the picker again; a cancel keeps Custom.
 row.buttons[5]:Click(); Flush()
 picker.swatchFunc(); Flush()
 picker = nil
 swatch:Click(); Flush()
 equal(picker ~= nil and string.format("%.3f,%.3f,%.3f", picker.r, picker.g, picker.b), "1.000,0.502,0.000", "the row's click opens the picker at the colour picked")
 ColorPickerFrame.GetColorRGB = function() return .2, .4, .6 end
 picker.swatchFunc(); Flush()
 equal(E.settings.castBarCustomColour, "336699", "a new colour picked")
 picker.cancelFunc(); Flush()
 equal(E.settings.castBarCustomColour .. " " .. E.settings.castBarColour .. " " .. tostring(swatch:IsShown()), "FF8000 custom true", "cancel: the colour before, still Custom")
 -- Greyed: the colour row's click opens nothing.
 E.settings.castBars = false; f:RefreshDependencies()
 picker = nil
 swatch:Click(); Flush()
 equal(tostring(swatch.dependencyDisabled) .. " " .. tostring(picker), "true nil", "with Cast Bars off its click opens nothing")
 E.settings.castBars = true; f:RefreshDependencies()
 ColorPickerFrame = nil
 -- Without the game's picker Custom is still chosen.
 row.buttons[2]:Click(); Flush()
 row.buttons[5]:Click(); Flush()
 equal(E.settings.castBarColour, "custom", "no picker: Custom chosen all the same")
 -- The footer: what each does, two lines at most, and the defaults.
 _, help, extras = M.Hover(f, row)
 equal(help, "Cast Bar Colour  Your own and your pet's cast bar fill. Match look: yellow in Classic, light grey in Dark Mode. Interrupted casts stay red, uninterruptible ones grey.",
  "its description")
 equal(M.LinesIn(help, 570, 12) .. " " .. extras, "2 Default: Match look.", "two footer lines, Match look by default")
 _, help, extras = M.Hover(f, swatch)
 equal(help .. " | " .. extras, "Custom Cast Bar Colour  Click to pick the colour of your own and your pet's cast bar. | Default: light grey.", "the colour row's description and default")
 -- Search finds them by cast colour, cast bar colour and fill, folded or not.
 row.buttons[1]:Click(); Flush()
 for _, query in ipairs({"cast colour", "cast bar color", "fill", "castbar", "class colour", "match look", "pet"}) do
  equal(Has(table.concat(M.Results(f, query), ","), "castBarColour"), true, "search " .. query .. " finds Cast Bar Colour")
 end
 equal(table.concat(M.Results(f, "custom cast bar"), ","), "castBarColour,castBarCustomColour", "custom cast bar finds the choice and its colour row while folded")
 f.searchBox:SetText(""); Flush()
 equal(f:JumpTo("castBarCustomColour"), row, "a jump to the folded colour row lands on Cast Bar Colour")
 -- The keyboard moves the choice on, one at a time.
 Open(f, "casting")
 f:FocusRow(row); f.keys:Fire("OnSpacePressed"); Flush()
 equal(E.settings.castBarColour .. " " .. row.selected, "classic 2", "Space on the row: Match look to Yellow")
 f:ClearRowFocus()
 E.Status = say
 E.settings.castBarColour, E.settings.castBarCustomColour, E.settings.castBars = nil, nil, nil
end

-- Upgrade Spell Ranks (Action Bars): a tick after Hide Macro
-- Names, off by default, applying at once through Modules/SpellRanks.lua
-- with its own chat line. It works with any bars, so the Classic Action Bars
-- look being off never greys it. Its footer words, and search finds it.
do
 local E, f = Session("PRIEST")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 equal(tostring(real.settingDefaults.upgradeSpellRanks) .. " " .. tostring(real.reloadSettings.upgradeSpellRanks), "false nil",
  "Upgrade Spell Ranks: off by default, no reload")
 E.settingDefaults.upgradeSpellRanks = false
 Open(f, "actionBars")
 equal(Keys(f), "actionBars,gryphons,hideEmptyActionSlots,hideKeybindText,hideMacroText,upgradeSpellRanks", "last on Action Bars, after Hide Macro Names")
 local row = f.checks.upgradeSpellRanks
 equal(row.text:GetText() .. " / " .. tostring(row:IsVisible()) .. " / " .. tostring(row:GetChecked()) .. " / " .. tostring(row.wide)
  .. " / " .. table.concat(row.tagIds, ","), "Upgrade Spell Ranks / true / false / nil / ", "a tick row, off, no words after its name (seen working in game)")
 local _, help, extras = M.Hover(f, row)
 equal(help, "Upgrade Spell Ranks  A new rank you learn replaces the rank it outgrew on your action bars, after any fight. Lower ranks you placed, macros and items stay.",
  "its words")
 equal(M.LinesIn(help, 570, 12) <= 2, true, "two footer lines at most")
 equal(extras, "Default: Off.", "no reload line, off by default")
 equal(row.summary, "A new rank takes the old one's place on your bars. Waits out fights.", "its summary")
 -- The Classic Action Bars look off: it is still free to switch.
 E.settings.actionBars = false; f:RefreshDependencies()
 equal(row.dependencyDisabled == true or row.greyed == true, false, "never greyed by the Action Bars look")
 E.settings.actionBars = true; f:RefreshDependencies()
 local refreshes, said = 0, nil
 local say = E.Status
 E.Status = function(_, m) said = m end
 E.modules.SpellRanks = {Refresh = function() refreshes = refreshes + 1 end}
 row:Click()
 equal(tostring(E.settings.upgradeSpellRanks) .. " " .. refreshes .. " " .. said,
  "true 1 Upgrade Spell Ranks enabled. The next rank you learn takes the old one's place on your bars.", "a click switches it on, live")
 row:Click()
 equal(tostring(E.settings.upgradeSpellRanks) .. " " .. refreshes .. " " .. said, "false 2 Upgrade Spell Ranks disabled.", "and off, live")
 E.modules.SpellRanks = nil
 row:Click()
 equal(tostring(E.settings.upgradeSpellRanks) .. " " .. said, "true Upgrade Spell Ranks enabled. The next rank you learn takes the old one's place on your bars.",
  "without the module loaded the tick still saves")
 row:Click()
 E.Status = say
 for _, word in ipairs({"rank", "spell rank", "upgrade", "highest", "trainer", "downrank", "action bar"}) do
  equal(Has(table.concat(M.Results(f, word), ","), "upgradeSpellRanks"), true, "searching " .. word .. " finds Upgrade Spell Ranks")
 end
 f.searchBox:SetText(""); Flush()
 E.settings.upgradeSpellRanks = nil
end

-- Stat Tracker (Character & Spells): its own Stat tracker
-- section under Spellbook. Off, only its switch shows and the page fits.
-- Switched on (live, through Modules/StatTracker.lua, with a chat line),
-- its rows open at once, keeping the scroll, none indented and none greyed:
-- Layout beside the switch, Show It on a line of its own (its three choices),
-- Panel Size a whole-line slider (50% to 150%), Stats per Line one under it
-- (1 to 16, All at the top; greyed for a list, the footer saying why, free
-- at once with One line), Gains in Green beside Show
-- Title, Stat Name Colour a whole line (five choices, Custom's colour row
-- folded under it until Custom is chosen), then the sixteen stat ticks two
-- to a line under Attributes, Offence, Defence and Other, in the panel's own
-- order, the approved eight ticked. Each choice, slider move, colour and
-- tick saved and shown at once; the footer's defaults; search finds them
-- folded; a jump lands on the switch (or on Stat Name Colour).
do
 local E, f = Session("ROGUE")
 local era = _G.EraUI; local real = {}; assert(loadfile("Core/Init.lua"))("EraUI", real); _G.EraUI = era
 local defaults = real.settingDefaults
 local ticked = {}
 for _, key in ipairs(f.pages.character.main) do
  if key:find("^statTracker%u") and defaults[key] == true and key ~= "statTrackerGains" and key ~= "statTrackerTitle" then ticked[#ticked + 1] = key end
 end
 equal(tostring(defaults.statTracker) .. " " .. defaults.statTrackerLayout .. " " .. defaults.statTrackerShow .. " " .. tostring(defaults.statTrackerGains)
  .. " " .. tostring(defaults.statTrackerTitle) .. " " .. defaults.statTrackerScale .. " " .. defaults.statTrackerNameColour .. " " .. defaults.statTrackerNameCustomColour,
  "false list always true true 100 auto FFD100", "off by default; when on: a list, always, gains in green, the title, 100%, names matching the look, Custom at gold")
 equal(defaults.statTrackerPerLine, 16, "Stats per Line: All (every one of the sixteen on one line) by default")
 equal(table.concat(ticked, ","), "statTrackerAgility,statTrackerStamina,statTrackerAttackPower,statTrackerCrit,statTrackerHit,statTrackerArmor,statTrackerDodge,statTrackerSpeed",
  "the approved eight ticked by default")
 for key in pairs(defaults) do
  if key:find("^statTracker") then equal(real.reloadSettings[key], nil, key .. " applies without a reload") end
 end
 for key, value in pairs(defaults) do E.settingDefaults[key] = value; if key:find("^statTracker") then E.settings[key] = value end end
 f:Hide(); f:Show(); Flush()
 -- The ticks in the panel's own order (Modules/StatTracker.lua STATS).
 local loaded = {}
 assert(loadfile("Modules/StatTracker.lua"))("EraUI", {RegisterModule = function(_, _, m) loaded.module = m end})
 local order = {}
 for _, stat in ipairs(loaded.module.STATS) do order[#order + 1] = "statTracker" .. stat.id end
 local listed = {}
 for _, key in ipairs(f.pages.character.main) do if key:find("^statTracker%u") and f.checks[key].rowKind == "tick" and key ~= "statTrackerGains" and key ~= "statTrackerTitle" then listed[#listed + 1] = key end end
 equal(table.concat(listed, ","), table.concat(order, ","), "the sixteen ticks in the panel's order")
 local refreshes, said = 0, nil
 E.modules.StatTracker = {Refresh = function() refreshes = refreshes + 1 end}
 local say = E.Status
 E.Status = function(_, m) said = m end
 local tracker, layout, show = f.checks.statTracker, f.checks.statTrackerLayout, f.checks.statTrackerShow
 local gains, titled = f.checks.statTrackerGains, f.checks.statTrackerTitle
 local size, names, swatch = f.checks.statTrackerScale, f.checks.statTrackerNameColour, f.checks.statTrackerNameCustomColour
 local perLine = f.checks.statTrackerPerLine
 -- Off: the switch alone under its heading, and the page fits.
 E.settings.statTracker = false
 Open(f, "character")
 equal(PageText(f), "WINDOWS:characterPanel,characterItemLevels,talentWindow,trainer,professions|SPELLBOOK:spellbook,spellbookCombatDrag,trainingGuide,showAllSpellRanks|STAT TRACKER:statTracker",
  "off: its switch alone, the groups folded away with their headings")
 equal(f.settingsContent:GetHeight() <= f.settingsScroll:GetHeight() + .01 and not f.settingsScrollHint:IsShown(), true, "off: Character & Spells fits without scrolling")
 M.NoOverlaps(f, "Stat Tracker off"); M.Fits(f, "Stat Tracker off")
 equal(tracker.rowKind .. " " .. tracker.text:GetText() .. " " .. tostring(tracker:GetChecked()) .. " " .. table.concat(tracker.tagIds, ","), "tick Stat Tracker false ",
  "a tick row, off, no words after its name (seen working in game)")
 local _, help, extras = M.Hover(f, tracker)
 equal(help, "Stat Tracker  A small panel of the stats you tick, updating as buffs, gear and levels change them. Drag it anywhere; it stays on screen.", "its words")
 equal(M.LinesIn(help, 570, 12) <= 2 and extras == "Default: Off.", true, "two footer lines, off by default: " .. extras)
 -- On: its rows open at once, keeping the scroll.
 M.Resize(f, 420)
 Open(f, "character")
 f:SetSettingsScroll(30)
 tracker:Click(); Flush()
 equal(tostring(E.settings.statTracker) .. " " .. refreshes .. " " .. tostring(said), "true 1 Stat Tracker enabled. Drag it to move it; tick the stats you want below.",
  "a click switches it on, live, with its chat line")
 equal(f.settingsScroll:GetVerticalScroll(), 30, "opening keeps the scroll")
 equal(Keys(f):find("statTracker,statTrackerLayout,statTrackerShow,statTrackerScale,statTrackerPerLine,statTrackerGains,statTrackerTitle,statTrackerNameColour,statTrackerStrength", 1, true) ~= nil, true,
  "its rows open under it at once, Custom's colour row folded: " .. Keys(f))
 M.Resize(f, 650)
 Open(f, "character")
 equal(PageText(f), "WINDOWS:characterPanel,characterItemLevels,talentWindow,trainer,professions|SPELLBOOK:spellbook,spellbookCombatDrag,trainingGuide,showAllSpellRanks"
  .. "|STAT TRACKER:statTracker,statTrackerLayout,statTrackerShow,statTrackerScale,statTrackerPerLine,statTrackerGains,statTrackerTitle,statTrackerNameColour"
  .. "|ATTRIBUTES:statTrackerStrength,statTrackerAgility,statTrackerStamina,statTrackerIntellect,statTrackerSpirit"
  .. "|OFFENCE:statTrackerAttackPower,statTrackerCrit,statTrackerHit,statTrackerSpellPower,statTrackerSpellCrit"
  .. "|DEFENCE:statTrackerArmor,statTrackerDodge,statTrackerParry,statTrackerBlock|OTHER:statTrackerSpeed,statTrackerDurability",
  "on: its options, then the sixteen ticks under their four groups")
 M.NoOverlaps(f, "Stat Tracker on"); M.Fits(f, "Stat Tracker on")
 M.SubOptionsFollow(f, "Stat Tracker on", ParentOf(E))
 equal(layout:GetTop() == tracker:GetTop() and layout:GetLeft() > tracker:GetRight(), true, "Layout beside the switch")
 equal(tostring(show.wide) .. " " .. N(show:GetWidth()) .. " " .. tostring(show:GetTop() < tracker:GetBottom()), "true 718 true", "Show It a whole line under them")
 equal(tostring(size.wide) .. " " .. N(size:GetWidth()) .. " " .. tostring(size:GetTop() < show:GetBottom()), "true 718 true", "Panel Size a whole line under Show It")
 equal(tostring(perLine.wide) .. " " .. N(perLine:GetWidth()) .. " " .. tostring(perLine:GetTop() < size:GetBottom()) .. " " .. (perLine.depth or 0)
  .. " " .. tostring(perLine.connV:IsShown()) .. " " .. #perLine.tagIds, "true 718 true 0 false 0",
  "Stats per Line a whole line right under Panel Size, never indented, no words after its name")
 equal(gains:GetTop() == titled:GetTop() and gains:GetTop() < perLine:GetBottom() and titled:GetLeft() > gains:GetRight(), true, "Gains in Green beside Show Title, under Stats per Line")
 equal(tostring(names.wide) .. " " .. N(names:GetWidth()) .. " " .. tostring(names:GetTop() < gains:GetBottom()), "true 718 true", "Stat Name Colour a whole line under them")
 local rows = {}
 for _, key in ipairs(listed) do rows[#rows + 1] = f.checks[key] end
 for i, row in ipairs(rows) do
  equal((row.depth or 0) .. " " .. tostring(row.dependencyDisabled) .. " " .. tostring(row.connV:IsShown()), "0 nil false", row.settingKey .. " never indented, never greyed")
  equal(row:GetChecked(), defaults[row.settingKey], row.settingKey .. " ticked as saved")
 end
 local function Pair(a, b) return a:GetTop() == b:GetTop() and b:GetLeft() > a:GetRight() end
 equal(Pair(rows[1], rows[2]) and Pair(rows[3], rows[4]) and rows[5]:GetTop() < rows[3]:GetBottom() and Pair(rows[6], rows[7]) and Pair(rows[11], rows[12])
  and Pair(rows[15], rows[16]), true, "two ticks to a line")
 for _, row in ipairs({layout, show, size, gains, titled, names}) do
  equal(tostring(row.dependencyDisabled) .. " " .. (row.depth or 0) .. " " .. #row.tagIds, "nil 0 0", row.settingKey .. " not greyed, not indented, no words after its name")
 end
 -- Layout: List or One line, a click each, at once.
 equal(layout.rowKind .. " " .. layout.labelText .. " " .. layout.buttons[1].label:GetText() .. "/" .. layout.buttons[2].label:GetText() .. " " .. layout.selected,
  "choice Layout List/One line 1", "Layout: List or One line, List chosen")
 refreshes = 0
 layout.buttons[2]:Click(); Flush()
 equal(E.settings.statTrackerLayout .. " " .. layout.selected .. " " .. refreshes .. " " .. said, "line 2 1 Stat Tracker: on one line.", "One line saved, shown at once, said")
 layout.buttons[1]:Click(); Flush()
 equal(E.settings.statTrackerLayout .. " " .. layout.selected .. " " .. said, "list 1 Stat Tracker: as a list.", "and back to a list")
 -- Show It: Always, In a fight or Out of a fight.
 local shows = {}
 for i, button in ipairs(show.buttons) do shows[i] = button.label:GetText() end
 equal(show.rowKind .. " " .. show.labelText .. " " .. table.concat(shows, "/") .. " " .. show.selected, "choice Show It Always/In a fight/Out of a fight 1", "Show It: its three choices, Always chosen")
 for i, button in ipairs(show.buttons) do
  equal(M.Glyphs(button.label:GetText(), 13) <= button:GetWidth() - 8 and button:GetRight() <= show:GetRight() + .01, true, shows[i] .. " fits its button, in the row")
  if i > 1 then equal(show.buttons[i - 1]:GetRight() <= button:GetLeft() - 5.99, true, shows[i - 1] .. " clear of " .. shows[i]) end
 end
 equal(show.text:GetLeft() + M.Glyphs(show.text:GetText(), 13) <= show.buttons[1]:GetLeft() - 4, true, "Show It clears its first choice")
 equal(layout.text:GetLeft() + M.Glyphs(layout.text:GetText(), 13) <= layout.buttons[1]:GetLeft() - 4, true, "Layout clears its first choice")
 for index, want in ipairs({{"always", "shows all the time."}, {"combat", "shows only in a fight."}, {"calm", "shows only out of a fight."}}) do
  refreshes = 0
  show.buttons[index]:Click(); Flush()
  equal(E.settings.statTrackerShow .. " " .. show.selected .. " " .. refreshes .. " " .. said, want[1] .. " " .. index .. " 1 Stat Tracker: " .. want[2], shows[index] .. " saved, shown at once, said")
 end
 -- The keyboard moves a choice on.
 f:FocusRow(show); f.keys:Fire("OnSpacePressed"); Flush()
 equal(E.settings.statTrackerShow, "always", "Space on Show It: Out of a fight to Always")
 f:ClearRowFocus()
 -- Ticks: saved and shown at once, quietly.
 said, refreshes = nil, 0
 f.checks.statTrackerStrength:Click()
 gains:Click()
 equal(tostring(E.settings.statTrackerStrength) .. " " .. tostring(E.settings.statTrackerGains) .. " " .. refreshes .. " " .. tostring(said), "true false 2 nil",
  "a stat's tick and Gains in Green: saved, the panel at once, no chat line")
 f.checks.statTrackerStrength:Click(); gains:Click()
 -- Panel Size: 50% to 150% in fives, saved and shown at once, quietly.
 equal(size.rowKind .. " " .. size.text:GetText() .. " " .. size.info.low .. "-" .. size.info.high .. " " .. size.info.step, "slider Panel Size: 100% 50-150 5",
  "Panel Size: a slider at 100%, 50% to 150% in fives")
 said, refreshes = nil, 0
 size.slider:SetValue(75)
 equal(E.settings.statTrackerScale .. " " .. size.text:GetText() .. " " .. refreshes .. " " .. tostring(said), "75 Panel Size: 75% 1 nil",
  "a move: saved, the panel at once, no chat line")
 size.slider:SetValue(400)
 equal(E.settings.statTrackerScale, 150, "never more than 150%")
 size.slider:SetValue(10)
 equal(E.settings.statTrackerScale, 50, "never less than 50%")
 size.slider:SetValue(100)
 -- Stats per Line: 1 to 16, All at the top (the default), for One line only.
 equal(perLine.rowKind .. " " .. perLine.text:GetText() .. " " .. perLine.info.low .. "-" .. perLine.info.high .. " " .. perLine.info.step,
  "slider Stats per Line: All 1-16 1", "Stats per Line: a slider at All, 1 to 16")
 -- A list: greyed, the footer says why, the slider can't be dragged and a move changes nothing.
 equal(E.settings.statTrackerLayout .. " " .. tostring(perLine.dependencyDisabled) .. " " .. perLine.alpha .. " " .. tostring(perLine.slider:IsMouseEnabled()),
  "list true 0.45 false", "a list: Stats per Line greyed, its slider not dragged")
 _, help, extras = M.Hover(f, perLine)
 equal(help .. " | " .. extras, "Stats per Line  For One line: how many stats go on each line, the rest in neat rows under it. All keeps them on one line."
  .. " | Set Layout to One line first.  Default: All.", "its words, why it's greyed and its default")
 equal(M.LinesIn(help, 570, 12) <= 2, true, "two footer lines at most")
 said, refreshes = nil, 0
 perLine.slider:SetValue(4)
 equal(E.settings.statTrackerPerLine .. " " .. perLine.text:GetText() .. " " .. perLine.slider:GetValue() .. " " .. refreshes, "16 Stats per Line: All 16 0",
  "a move while greyed: nothing saved, the slider back at All, the panel untouched")
 -- One line frees it at once (the Layout click), and each move shows live, quietly.
 layout.buttons[2]:Click(); Flush()
 equal(tostring(perLine.dependencyDisabled) .. " " .. perLine.alpha .. " " .. tostring(perLine.slider:IsMouseEnabled()), "false 1 true",
  "One line: Stats per Line free at once")
 _, help, extras = M.Hover(f, perLine)
 equal(extras, "Default: All.", "free: only its default in the footer")
 said, refreshes = nil, 0
 perLine.slider:SetValue(4)
 equal(E.settings.statTrackerPerLine .. " " .. perLine.text:GetText() .. " " .. refreshes .. " " .. tostring(said), "4 Stats per Line: 4 1 nil",
  "a move: saved, the panel at once, no chat line")
 perLine.slider:SetValue(1)
 equal(E.settings.statTrackerPerLine .. " " .. perLine.text:GetText() .. " " .. refreshes, "1 Stats per Line: 1 2", "1: one stat a line")
 perLine.slider:SetValue(0)
 equal(E.settings.statTrackerPerLine, 1, "never fewer than 1")
 perLine.slider:SetValue(99)
 equal(E.settings.statTrackerPerLine .. " " .. perLine.text:GetText(), "16 Stats per Line: All", "never more than 16, which reads All")
 perLine.slider:SetValue(4)
 -- Back to a list: greyed again at once, its number kept for One line.
 layout.buttons[1]:Click(); Flush()
 equal(tostring(perLine.dependencyDisabled) .. " " .. perLine.alpha .. " " .. tostring(perLine.slider:IsMouseEnabled()) .. " " .. E.settings.statTrackerPerLine
  .. " " .. perLine.text:GetText(), "true 0.45 false 4 Stats per Line: 4", "a list again: greyed at once, 4 kept")
 -- Changed elsewhere (a /run): greyed or free when /era is next shown.
 E.settings.statTrackerLayout = "line"
 f:Hide(); f:Show(); Flush(); Open(f, "character")
 equal(tostring(perLine.dependencyDisabled) .. " " .. perLine.text:GetText(), "false Stats per Line: 4", "One line set elsewhere: free when /era opens")
 E.settings.statTrackerLayout = "list"
 f:Hide(); f:Show(); Flush(); Open(f, "character")
 equal(tostring(perLine.dependencyDisabled), "true", "and greyed again for a list")
 -- A number it can't read (lost or broken): All, nothing saved over it.
 E.settings.statTrackerPerLine = "big"
 perLine:SetChecked()
 equal(perLine.text:GetText() .. " " .. E.settings.statTrackerPerLine, "Stats per Line: All big", "Stats per Line unreadable: All, left as it was")
 E.settings.statTrackerPerLine = 16
 perLine:SetChecked()
 -- Stat Name Colour: Match look, Gold, Class, White or Custom, a click each, at once.
 local colours = {}
 for i, button in ipairs(names.buttons) do colours[i] = button.label:GetText() end
 equal(names.rowKind .. " " .. names.labelText .. " " .. table.concat(colours, "/") .. " " .. names.selected .. " " .. tostring(swatch:IsShown()),
  "choice Stat Name Colour Match look/Gold/Class/White/Custom 1 false", "Stat Name Colour: five choices, Match look chosen, no colour row")
 for i, button in ipairs(names.buttons) do
  equal(M.Glyphs(button.label:GetText(), 13) <= button:GetWidth() - 8 and button:GetRight() <= names:GetRight() + .01, true, colours[i] .. " fits its button, in the row")
  if i > 1 then equal(names.buttons[i - 1]:GetRight() <= button:GetLeft() - 5.99, true, colours[i - 1] .. " clear of " .. colours[i]) end
 end
 equal(names.text:GetLeft() + M.Glyphs(names.text:GetText(), 13) <= names.buttons[1]:GetLeft() - 4, true, "Stat Name Colour clears its first choice")
 for _, want in ipairs({{2, "gold", "names in gold."}, {3, "class", "names in your class colour."}, {4, "white", "names in white."}, {1, "auto", "names match the look."}}) do
  refreshes = 0
  names.buttons[want[1]]:Click(); Flush()
  equal(E.settings.statTrackerNameColour .. " " .. names.selected .. " " .. refreshes .. " " .. said .. " " .. tostring(swatch:IsShown()),
   want[2] .. " " .. want[1] .. " 1 Stat Tracker: " .. want[3] .. " false", colours[want[1]] .. " saved, shown at once, said, no colour row")
 end
 -- Custom: the picker opens at the custom colour, and its row opens under the choice.
 local picker
 ColorPickerFrame = {SetupColorPickerAndShow = function(_, info) picker = info end, GetColorRGB = function() return .2, .4, 1 end}
 names.buttons[3]:Click(); Flush()
 refreshes = 0
 names.buttons[5]:Click(); Flush()
 equal(E.settings.statTrackerNameColour .. " " .. names.selected .. " " .. refreshes .. " " .. said, "custom 5 1 Stat Tracker: names in your own colour.",
  "Custom chosen, shown at once, said")
 equal(picker ~= nil and string.format("%.3f,%.3f,%.3f %s", picker.r, picker.g, picker.b, tostring(picker.hasOpacity)), "1.000,0.820,0.000 false",
  "the colour picker opens at once, at the custom colour (gold), no opacity")
 equal(Keys(f):find("statTrackerNameColour,statTrackerNameCustomColour,statTrackerStrength", 1, true) ~= nil, true, "Custom Stat Name Colour opens under the choice at once")
 equal(swatch.rowKind .. " " .. swatch.labelText .. " " .. swatch.depth .. " " .. tostring(swatch.connV:IsShown()) .. " " .. Colour(swatch.swatch.fill),
  "colour Custom Stat Name Colour 1 true 1.000,0.820,0.000", "a colour row under the choice, its swatch the gold")
 M.NoOverlaps(f, "Custom Stat Name Colour"); M.Fits(f, "Custom Stat Name Colour")
 M.SubOptionsFollow(f, "Custom Stat Name Colour", ParentOf(E))
 picker.swatchFunc(); Flush()
 equal(E.settings.statTrackerNameCustomColour .. " " .. E.settings.statTrackerNameColour .. " " .. refreshes .. " " .. Colour(swatch.swatch.fill),
  "3366FF custom 2 0.200,0.400,1.000", "the picked colour saved as hex, shown at once, the swatch shows it")
 _, help, extras = M.Hover(f, swatch)
 equal(help .. " | " .. extras, "Custom Stat Name Colour  Click to pick the colour of the stat names. | Default: gold.", "the colour row's words and default")
 picker.cancelFunc(); Flush()
 equal(E.settings.statTrackerNameCustomColour .. " " .. E.settings.statTrackerNameColour .. " " .. names.selected .. " " .. tostring(swatch:IsShown()),
  "FFD100 class 3 false", "cancel puts back the colour and the choice from before, and folds the row away")
 -- The row's own click opens the picker again; a cancel keeps Custom.
 names.buttons[5]:Click(); Flush()
 picker.swatchFunc(); Flush()
 picker = nil
 swatch:Click(); Flush()
 equal(picker ~= nil and string.format("%.3f,%.3f,%.3f", picker.r, picker.g, picker.b), "0.200,0.400,1.000", "the row's click opens the picker at the colour picked")
 ColorPickerFrame.GetColorRGB = function() return 1, .5, 0 end
 picker.swatchFunc(); Flush()
 equal(E.settings.statTrackerNameCustomColour, "FF8000", "a new colour picked")
 picker.cancelFunc(); Flush()
 equal(E.settings.statTrackerNameCustomColour .. " " .. E.settings.statTrackerNameColour .. " " .. tostring(swatch:IsShown()), "3366FF custom true",
  "cancel: the colour before, still Custom")
 -- A jump to the colour row, folded under Gold, lands on Stat Name Colour.
 names.buttons[2]:Click(); Flush()
 equal(f:JumpTo("statTrackerNameCustomColour"), names, "a jump to Custom Stat Name Colour, folded: Stat Name Colour")
 Open(f, "character")
 -- Without the game's picker Custom is still chosen.
 ColorPickerFrame = nil
 names.buttons[5]:Click(); Flush()
 equal(E.settings.statTrackerNameColour, "custom", "no picker: Custom chosen all the same")
 names.buttons[1]:Click(); Flush()
 E.settings.statTrackerNameCustomColour = "FFD100"
 -- Changed elsewhere (a profile, a /run): each choice row shows the saved
 -- choice again when it's next shown.
 E.settings.statTrackerLayout, E.settings.statTrackerShow, E.settings.statTrackerNameColour = "line", "calm", "white"
 for _, row in ipairs({layout, show, names}) do row:Hide(); row:Show() end
 equal(layout.selected .. " " .. show.selected .. " " .. names.selected, "2 3 4", "Layout, Show It and Stat Name Colour show the saved choice again when shown")
 E.settings.statTrackerLayout, E.settings.statTrackerShow, E.settings.statTrackerNameColour = "list", "always", "auto"
 for _, row in ipairs({layout, show, names}) do row:Hide(); row:Show() end
 -- A size it can't read (lost or broken): the slider shows 100%, nothing saved over it.
 E.settings.statTrackerScale = "big"
 size:SetChecked()
 equal(size.text:GetText() .. " " .. E.settings.statTrackerScale, "Panel Size: 100% big", "Panel Size unreadable: 100%, left as it was")
 E.settings.statTrackerScale = 100
 size:SetChecked()
 -- The footer: what each does and its default.
 _, help, extras = M.Hover(f, layout)
 equal(Has(help, "List puts each stat") and extras == "Default: List.", true, "Layout's words and default: " .. extras)
 _, help, extras = M.Hover(f, show)
 equal(Has(help, "only in a fight") and extras == "Default: Always.", true, "Show It's words and default: " .. extras)
 _, help, extras = M.Hover(f, gains)
 equal(Has(help, "five seconds") and extras == "Default: On.", true, "Gains in Green: how long, on by default")
 _, help, extras = M.Hover(f, size)
 equal(help .. " | " .. extras, "Panel Size  How big the panel is, from 50% to 150%, as a list or on one line. It stays where you put it. | Default: 100%.",
  "Panel Size's words and default")
 _, help, extras = M.Hover(f, names)
 equal(help .. " | " .. extras, "Stat Name Colour  The colour of the stat names. Match look: gold in Classic, grey in Dark Mode. The numbers keep theirs, green when they go up."
  .. " | Default: Match look.", "Stat Name Colour's words and default")
 equal(M.LinesIn(help, 570, 12) <= 2, true, "two footer lines at most")
 _, help, extras = M.Hover(f, f.checks.statTrackerSpeed)
 equal(Has(help, "Standing still or swimming doesn't change it.") and extras == "Default: On.", true, "Speed: run speed, not movement or swimming; ticked by default")
 _, help, extras = M.Hover(f, f.checks.statTrackerStrength)
 equal(extras, "Default: Off.", "Strength unticked by default")
 -- EraUI's own words spell it armour (the stat's name is the game's Armor).
 _, help = M.Hover(f, f.checks.statTrackerArmor)
 equal(Has(help, "Your armour, gear and buffs included.") and not Has(help:lower(), "your armor"), true, "Armor's words in British spelling: " .. help)
 -- Off again: everything after the switch folds away.
 tracker:Click(); Flush()
 equal(tostring(E.settings.statTracker) .. " " .. tostring(said), "false Stat Tracker disabled.", "off again, said")
 equal(Keys(f):find("statTrackerLayout", 1, true) == nil and Keys(f):find("statTrackerSpeed", 1, true) == nil and tracker:IsShown(), true, "its rows fold away; the switch stays")
 -- Search finds them folded; a jump to one lands on the switch.
 local found = M.Results(f, "stat tracker")
 equal(#found, 25, "searching stat tracker finds its switch, its eight options and its sixteen ticks")
 equal(table.concat(M.Results(f, "panel size"), ","), "statTrackerScale", "panel size finds Panel Size")
 for _, query in ipairs({"stats per line", "per line", "rows", "wrap", "columns", "stat grid"}) do
  equal(Has(table.concat(M.Results(f, query), ","), "statTrackerPerLine"), true, query .. " finds Stats per Line, folded")
 end
 for _, query in ipairs({"stat name colour", "stat name color", "stat words", "stat labels"}) do
  equal(table.concat(M.Results(f, query), ","), "statTrackerNameColour,statTrackerNameCustomColour", query .. " finds Stat Name Colour and its colour row, folded")
 end
 for _, query in ipairs({"name colour gold", "stats class colour", "stats white"}) do
  equal(Has(table.concat(M.Results(f, query), ","), "statTrackerNameColour"), true, query .. " finds Stat Name Colour")
 end
 equal(Has(table.concat(M.Results(f, "durability"), ","), "statTrackerDurability") and Has(table.concat(M.Results(f, "durability"), ","), "durabilityWarning"), true,
  "durability finds the tracker's tick and the low durability warning")
 equal(table.concat(M.Results(f, "agility"), ","), "statTrackerAgility", "agility finds its tick")
 local armour = {}
 for _, key in ipairs(M.Results(f, "armour")) do armour[key] = true end
 equal(tostring(armour.statTrackerArmor) .. " " .. tostring(armour.statTracker), "true true", "armour finds the Armor tick and the Stat Tracker")
 equal(Has(table.concat(M.Results(f, "stats"), ","), "statTracker"), true, "stats finds the Stat Tracker")
 f.searchBox:SetText(""); Flush()
 equal(f:JumpTo("statTrackerSpeed"), tracker, "a jump to a folded tick lands on Stat Tracker")
 equal(f:JumpTo("statTrackerShow"), tracker, "and to a folded choice")
 equal(f:JumpTo("statTrackerScale"), tracker, "and to Panel Size")
 equal(f:JumpTo("statTrackerPerLine"), tracker, "and to Stats per Line")
 E.settings.statTrackerNameColour = "custom"
 equal(f:JumpTo("statTrackerNameCustomColour"), tracker, "and to Custom Stat Name Colour, with Custom chosen but the tracker off")
 equal(tostring(swatch:IsShown()) .. " " .. tostring(names:IsShown()), "false false", "Custom chosen, the tracker off: its colour row folded away with the rest")
 E.settings.statTrackerNameColour = "auto"
 E.Status = say
 for key in pairs(defaults) do if key:find("^statTracker") then E.settings[key] = nil end end
 E.modules.StatTracker = nil
end
print("Settings layout/combat checks passed: " .. M.checks .. " assertions.")
