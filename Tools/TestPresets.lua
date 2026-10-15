-- Run the actual presets module: which settings each preset changes, how the
-- active preset is recognised, and the Presets window's confirmation, which
-- reloads straight from its click and never in combat.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat, reloads = false, 0
local window
InCombatLockdown = function() return combat end
ReloadUI = function()
    assert(not combat, "blocked Reload() in combat")
    assert(window and window.shown, "blocked Reload(): window hidden before the reload request")
    reloads = reloads + 1
end
UnitClass = function() return "Druid", "DRUID" end
RAID_CLASS_COLORS = { DRUID = { r = 1, g = .49, b = .04 } }
UISpecialFrames = {}
GameFontHighlight = { GetFont = function() return "font", 12, "" end }

local function Region(parent)
    local r = { parent = parent, shown = true }
    for _, name in ipairs({ "SetPoint", "SetWidth", "SetJustifyH", "SetTextColor", "SetColorTexture", "SetHeight", "SetAllPoints", "SetFont" }) do
        r[name] = function() end
    end
    function r:SetText(text) self.text = text end
    function r:GetText() return self.text end
    return r
end
local function Frame(parent, name)
    local f = Region(parent)
    f.name, f.scripts = name, {}
    for _, method in ipairs({ "SetSize", "SetClampedToScreen", "EnableMouse", "SetMovable", "RegisterForDrag",
        "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "StartMoving", "StopMovingOrSizing", "SetToplevel" }) do
        f[method] = function() end
    end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown and (not self.parent or self.parent.shown ~= false) end
    function f:Raise() end
    function f:CreateTexture() return Region(self) end
    function f:CreateFontString() return Region(self) end
    function f:Click() self.scripts.OnClick(self) end
    return f
end
CreateFrame = function(_, name, parent)
    local f = Frame(parent, name)
    if name == "EraUIPresets" then window = f end
    return f
end

local saved = {}
local questieTrackerOn = true
local E = { modules = { QuestTrackerChoice = { QuestieTrackerOn = function() return questieTrackerOn end } } }
function E:GetSavedSetting(key) return saved[key] end
function E:SetSetting(key, value) saved[key] = value end
assert(loadfile("Core/Presets.lua"))("EraUI", E)
local P = E.Presets

local function ClassicLook() for _, key in ipairs(P.LOOK) do saved[key] = true end end

-- Recognising the active preset ---------------------------------------------------------

ClassicLook()
Equal(P:Current(), "classic", "every Classic skin on is the Classic look")
saved.damageMeterSkin, saved.vendorPrice, saved.cursorRing = true, true, true
Equal(P:Current(), "classic", "optional looks and QoL options never affect the preset")
saved.minimap = false
Equal(P:Current(), "custom", "one Classic skin off is Custom")
for _, key in ipairs(P.LOOK) do saved[key] = false end
Equal(P:Current(), "qol", "every Classic skin off is Quality of Life only")
Equal(P.NAMES.qol, "Quality of Life only", "spelled out in full")
ClassicLook()
saved.questTrackerChoice, saved.questTracker = "questie", false
Equal(P:Current(), "classic", "Questie's tracker chosen still counts as the Classic look")
questieTrackerOn = false
Equal(P:Current(), "custom", "an old Questie choice no longer counts once its tracker is off")
local changes = P:Changes("classic")
Equal(changes.questTracker, true, "the Classic look turns the Classic tracker back on then")
questieTrackerOn = true
saved.questTrackerChoice = ""
saved.questTracker = true
local inLook = {}
for _, key in ipairs(P.LOOK) do inLook[key] = true end
Equal(inLook.otherWindows, true, "Other Windows belongs to the Classic look")

-- Applying ----------------------------------------------------------------------------------

saved.darkMode, saved.classColourBorders, saved.darkAuraBorders, saved.darkAuraShadows = true, true, true, true
-- Class-coloured Tooltips works on the game's own tooltips too, so neither
-- preset touches it.
saved.tooltipClassColours = true
Equal(P:Changes("qol").tooltipClassColours, nil, "Quality of Life only leaves Class-coloured Tooltips alone")
Equal(P:Changes("classic").tooltipClassColours, nil, "the Classic look leaves Class-coloured Tooltips alone")
-- Bag Item Levels is a Quality of Life option: neither preset touches it.
saved.bagItemLevels = true
Equal(P:Changes("qol").bagItemLevels, nil, "Quality of Life only leaves Bag Item Levels alone")
Equal(P:Changes("classic").bagItemLevels, nil, "the Classic look leaves Bag Item Levels alone")
-- Character Item Levels too: it works on Blizzard's character window as well.
saved.characterItemLevels = true
Equal(P:Changes("qol").characterItemLevels, nil, "Quality of Life only leaves Character Item Levels alone")
Equal(P:Changes("classic").characterItemLevels, nil, "the Classic look leaves Character Item Levels alone")
-- Dark Aura Borders only shows in Dark Mode, so presets leave it alone:
-- choosing Dark Mode later brings the borders back.
Equal(P:Changes("qol").darkAuraBorders, nil, "Quality of Life only leaves Dark Aura Borders alone")
Equal(P:Changes("classic").darkAuraBorders, nil, "the Classic look leaves Dark Aura Borders alone")
local inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "darkAuraBorders" then inExtras = true end end
Equal(inExtras, false, "Dark Aura Borders is not an optional look")
-- Aura Shadows goes with Dark Aura Borders: presets leave it alone too.
Equal(P:Changes("qol").darkAuraShadows, nil, "Quality of Life only leaves Aura Shadows alone")
Equal(P:Changes("classic").darkAuraShadows, nil, "the Classic look leaves Aura Shadows alone")
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "darkAuraShadows" then inExtras = true end end
Equal(inExtras, false, "Aura Shadows is not an optional look")
-- Flat Bars is one: it shows in Classic or Dark Mode. The Classic look
-- leaves it as chosen, Quality of Life only switches it off, and it never
-- changes which preset you're on.
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "flatBars" then inExtras = true end end
Equal(inExtras, true, "Flat Bars is an optional look")
saved.flatBars = true
Equal(P:Changes("classic").flatBars, nil, "the Classic look leaves Flat Bars alone")
Equal(P:Changes("qol").flatBars, false, "Quality of Life only switches Flat Bars off")
local _, count = P:Changes("qol")
Equal(count, #P.LOOK + 4, "Quality of Life only switches every Classic skin and optional look off")
P:Apply("qol")
Equal(saved.flatBars, false, "Flat Bars off after Quality of Life only")
Equal(saved.unitFrames, false, "Classic unit frames off")
Equal(saved.darkMode, false, "Dark Mode art off")
Equal(saved.darkAuraBorders, true, "Dark Aura Borders kept, so Dark Mode brings it back")
Equal(saved.damageMeterSkin, false, "damage meter skin off")
Equal(saved.vendorPrice, true, "QoL options untouched")
Equal(saved.cursorRing, true, "cursor effects untouched")
Equal(saved.tooltipClassColours, true, "Class-coloured Tooltips kept after Quality of Life only")
Equal(saved.bagItemLevels, true, "Bag Item Levels kept after Quality of Life only")
Equal(saved.characterItemLevels, true, "Character Item Levels kept after Quality of Life only")
_, count = P:Changes("classic")
Equal(count, #P.LOOK, "the Classic look switches every Classic skin back on")
P:Apply("classic")
Equal(P:Current(), "classic", "Classic look restored")
Equal(saved.damageMeterSkin, false, "optional looks stay as chosen")
Equal(saved.flatBars, false, "Flat Bars stays as chosen after the Classic look")
saved.flatBars = true
Equal(P:Current(), "classic", "Flat Bars on is still the Classic look")
P:Apply("classic")
Equal(saved.flatBars, true, "the Classic look keeps a switched-on Flat Bars")
saved.flatBars = nil
-- Thick Aura Borders is one too: Classic or Dark Mode, the same as Flat Bars.
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "thickAuraBorders" then inExtras = true end end
Equal(inExtras, true, "Thick Aura Borders is an optional look")
saved.thickAuraBorders = true
Equal(P:Changes("classic").thickAuraBorders, nil, "the Classic look leaves Thick Aura Borders alone")
Equal(P:Changes("qol").thickAuraBorders, false, "Quality of Life only switches Thick Aura Borders off")
P:Apply("qol")
Equal(saved.thickAuraBorders, false, "Thick Aura Borders off after Quality of Life only")
P:Apply("classic")
Equal(saved.thickAuraBorders, false, "Thick Aura Borders stays as chosen after the Classic look")
saved.thickAuraBorders = true
Equal(P:Current(), "classic", "Thick Aura Borders on is still the Classic look")
P:Apply("classic")
Equal(saved.thickAuraBorders, true, "the Classic look keeps a switched-on Thick Aura Borders")
saved.thickAuraBorders = nil
Equal(P:Current(), "classic", "and off, still the Classic look")
-- Rounded Cast Bars is one too: Classic or Dark Mode, the same as Flat Bars.
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "roundedCastBars" then inExtras = true end end
Equal(inExtras, true, "Rounded Cast Bars is an optional look")
saved.roundedCastBars = true
Equal(P:Changes("classic").roundedCastBars, nil, "the Classic look leaves Rounded Cast Bars alone")
Equal(P:Changes("qol").roundedCastBars, false, "Quality of Life only switches Rounded Cast Bars off")
P:Apply("qol")
Equal(saved.roundedCastBars, false, "Rounded Cast Bars off after Quality of Life only")
P:Apply("classic")
Equal(saved.roundedCastBars, false, "Rounded Cast Bars stays as chosen after the Classic look")
saved.roundedCastBars = true
Equal(P:Current(), "classic", "Rounded Cast Bars on is still the Classic look")
P:Apply("classic")
Equal(saved.roundedCastBars, true, "the Classic look keeps a switched-on Rounded Cast Bars")
saved.roundedCastBars = nil
Equal(P:Current(), "classic", "and off, still the Classic look")
-- Thick Frames is one too. Its two ticks and its Edge choice are not: they
-- do nothing while it's off, so both presets leave them as chosen.
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do
    if key == "thickFrames" then inExtras = true end
    Equal(key ~= "thickFrameRings" and key ~= "thickFrameParty" and key ~= "thickFrameEdge", true,
        "Thick Frames' ticks and Edge are no optional look of their own (" .. key .. ")")
end
Equal(inExtras, true, "Thick Frames is an optional look")
saved.thickFrames, saved.thickFrameRings, saved.thickFrameParty, saved.thickFrameEdge = true, true, true, "class"
Equal(P:Changes("classic").thickFrames, nil, "the Classic look leaves Thick Frames alone")
Equal(P:Changes("qol").thickFrames, false, "Quality of Life only switches Thick Frames off")
Equal(tostring(P:Changes("qol").thickFrameEdge) .. " " .. tostring(P:Changes("classic").thickFrameEdge), "nil nil", "neither touches Edge")
P:Apply("qol")
Equal(tostring(saved.thickFrames) .. " " .. tostring(saved.thickFrameRings) .. " " .. tostring(saved.thickFrameParty) .. " " .. tostring(saved.thickFrameEdge),
    "false true true class", "Thick Frames off after Quality of Life only, its ticks and Edge kept for next time")
P:Apply("classic")
Equal(saved.thickFrames, false, "Thick Frames stays as chosen after the Classic look")
saved.thickFrames = true
Equal(P:Current(), "classic", "Thick Frames on is still the Classic look")
P:Apply("classic")
Equal(tostring(saved.thickFrames) .. " " .. tostring(saved.thickFrameRings) .. " " .. tostring(saved.thickFrameParty) .. " " .. tostring(saved.thickFrameEdge),
    "true true true class", "the Classic look keeps a switched-on Thick Frames, its ticks and Edge")
saved.thickFrames, saved.thickFrameRings, saved.thickFrameParty, saved.thickFrameEdge = nil, nil, nil, nil
Equal(P:Current(), "classic", "and off, still the Classic look")
-- The Raid-style Party Outline is one too: it shows in Classic or Dark Mode.
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "partyOutline" then inExtras = true end end
Equal(inExtras, true, "the Raid-style Party Outline is an optional look")
saved.partyOutline = true
Equal(P:Changes("classic").partyOutline, nil, "the Classic look leaves the Raid-style Party Outline alone")
Equal(P:Changes("qol").partyOutline, false, "Quality of Life only switches the Raid-style Party Outline off")
P:Apply("qol")
Equal(saved.partyOutline, false, "the Raid-style Party Outline off after Quality of Life only")
P:Apply("classic")
Equal(saved.partyOutline, false, "the Raid-style Party Outline stays as chosen after the Classic look")
saved.partyOutline = true
Equal(P:Current(), "classic", "the Raid-style Party Outline on is still the Classic look")
P:Apply("classic")
Equal(saved.partyOutline, true, "the Classic look keeps a switched-on Raid-style Party Outline")
saved.partyOutline = nil
Equal(P:Current(), "classic", "and off, still the Classic look")
-- Square Minimap is one too: it reshapes the Classic minimap, in Classic or
-- Dark Mode, and Quality of Life only switches that minimap off.
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "squareMinimap" then inExtras = true end end
Equal(inExtras, true, "Square Minimap is an optional look")
saved.squareMinimap = true
Equal(P:Changes("classic").squareMinimap, nil, "the Classic look leaves Square Minimap alone")
Equal(P:Changes("qol").squareMinimap, false, "Quality of Life only switches Square Minimap off")
P:Apply("qol")
Equal(tostring(saved.squareMinimap) .. " " .. tostring(saved.minimap), "false false", "Square Minimap off after Quality of Life only, with the Classic minimap")
P:Apply("classic")
Equal(tostring(saved.squareMinimap) .. " " .. tostring(saved.minimap), "false true", "the Classic look brings the minimap back, Square Minimap as chosen")
saved.squareMinimap = true
Equal(P:Current(), "classic", "Square Minimap on is still the Classic look")
P:Apply("classic")
Equal(saved.squareMinimap, true, "the Classic look keeps a switched-on Square Minimap")
saved.squareMinimap = nil
Equal(P:Current(), "classic", "and off, still the Classic look")
-- Its Square Size is left as chosen by both, like Thick Frames' own ticks:
-- it does nothing while the square is off, and never changes the preset.
for _, list in ipairs({ P.LOOK, P.LOOK_EXTRAS }) do
    for _, key in ipairs(list) do Equal(key ~= "squareMinimapScale", true, "Square Size is not a look (" .. key .. ")") end
end
for _, case in ipairs({ { true, 140 }, { false, 80 }, { true, 100 } }) do
    saved.squareMinimap, saved.squareMinimapScale = case[1], case[2]
    Equal(P:Changes("qol").squareMinimapScale, nil, "Quality of Life only leaves Square Size alone (" .. case[2] .. ")")
    Equal(P:Changes("classic").squareMinimapScale, nil, "the Classic look leaves Square Size alone (" .. case[2] .. ")")
    P:Apply("qol")
    Equal(saved.squareMinimapScale, case[2], "Square Size kept after Quality of Life only (" .. case[2] .. ")")
    P:Apply("classic")
    Equal(saved.squareMinimapScale, case[2], "and after the Classic look (" .. case[2] .. ")")
    Equal(P:Current(), "classic", "Square Size never changes the preset (" .. case[2] .. ")")
end
saved.squareMinimap, saved.squareMinimapScale = nil, nil
Equal(saved.bagItemLevels, true, "Bag Item Levels kept after the Classic look")
Equal(saved.characterItemLevels, true, "Character Item Levels kept after the Classic look")
Equal(saved.darkAuraBorders, true, "Dark Aura Borders kept after the Classic look")
Equal(saved.darkAuraShadows, true, "Aura Shadows kept through both presets")
-- Switched off by the player: no preset turns it back on.
saved.darkAuraBorders = false
saved.darkAuraShadows = false
P:Apply("qol"); P:Apply("classic")
Equal(saved.darkAuraBorders, false, "a switched-off Dark Aura Borders stays off through presets")
Equal(saved.darkAuraShadows, false, "a switched-off Aura Shadows stays off through presets")
saved.darkAuraBorders = true
saved.darkAuraShadows = true
-- Dark Bag Buttons only shows in Dark Mode too: presets leave it alone, on
-- or off, and it never changes which preset you're on.
inExtras = false
for _, key in ipairs(P.LOOK_EXTRAS) do if key == "darkBagButtons" then inExtras = true end end
Equal(inExtras, false, "Dark Bag Buttons is not an optional look")
for _, value in ipairs({ true, false }) do
    saved.darkBagButtons = value
    Equal(P:Changes("qol").darkBagButtons, nil, "Quality of Life only leaves Dark Bag Buttons alone (" .. tostring(value) .. ")")
    Equal(P:Changes("classic").darkBagButtons, nil, "the Classic look leaves Dark Bag Buttons alone (" .. tostring(value) .. ")")
    P:Apply("qol")
    Equal(saved.darkBagButtons, value, "Dark Bag Buttons kept after Quality of Life only (" .. tostring(value) .. ")")
    P:Apply("classic")
    Equal(saved.darkBagButtons, value, "and after the Classic look (" .. tostring(value) .. ")")
    Equal(P:Current(), "classic", "Dark Bag Buttons never changes the preset (" .. tostring(value) .. ")")
end
saved.darkBagButtons = nil
-- Upgrade Spell Ranks is a quality-of-life choice, not a look: presets leave
-- it alone, on or off, and it never changes which preset you're on.
for _, list in ipairs({ P.LOOK, P.LOOK_EXTRAS }) do
    for _, key in ipairs(list) do Equal(key ~= "upgradeSpellRanks", true, "Upgrade Spell Ranks is not a look") end
end
for _, value in ipairs({ true, false }) do
    saved.upgradeSpellRanks = value
    Equal(P:Changes("qol").upgradeSpellRanks, nil, "Quality of Life only leaves Upgrade Spell Ranks alone (" .. tostring(value) .. ")")
    Equal(P:Changes("classic").upgradeSpellRanks, nil, "the Classic look leaves Upgrade Spell Ranks alone (" .. tostring(value) .. ")")
    P:Apply("qol")
    Equal(saved.upgradeSpellRanks, value, "Upgrade Spell Ranks kept after Quality of Life only (" .. tostring(value) .. ")")
    P:Apply("classic")
    Equal(saved.upgradeSpellRanks, value, "and after the Classic look (" .. tostring(value) .. ")")
    Equal(P:Current(), "classic", "Upgrade Spell Ranks never changes the preset (" .. tostring(value) .. ")")
end
saved.upgradeSpellRanks = nil
-- The Stat Tracker is a quality-of-life choice too, with its own look in
-- Classic or Dark Mode: presets leave it, its choices and its ticks alone,
-- on or off, and it never changes which preset you're on.
local STAT_KEYS = { "statTracker", "statTrackerLayout", "statTrackerShow", "statTrackerGains", "statTrackerTitle", "statTrackerAgility",
    "statTrackerStrength", "statTrackerScale", "statTrackerNameColour", "statTrackerNameCustomColour", "statTrackerPerLine" }
for _, list in ipairs({ P.LOOK, P.LOOK_EXTRAS }) do
    for _, key in ipairs(list) do Equal(key:find("^statTracker"), nil, "no Stat Tracker setting is a look (" .. key .. ")") end
end
for _, value in ipairs({ true, false }) do
    saved.statTracker, saved.statTrackerGains, saved.statTrackerTitle = value, value, value
    saved.statTrackerAgility, saved.statTrackerStrength = value, not value
    saved.statTrackerLayout, saved.statTrackerShow = value and "line" or "list", value and "combat" or "calm"
    saved.statTrackerScale, saved.statTrackerNameColour = value and 60 or 140, value and "custom" or "class"
    saved.statTrackerNameCustomColour = value and "3366FF" or "FF8000"
    saved.statTrackerPerLine = value and 4 or 1
    local before = {}
    for _, key in ipairs(STAT_KEYS) do before[key] = saved[key] end
    for _, key in ipairs(STAT_KEYS) do
        Equal(P:Changes("qol")[key], nil, "Quality of Life only leaves " .. key .. " alone (" .. tostring(value) .. ")")
        Equal(P:Changes("classic")[key], nil, "the Classic look leaves " .. key .. " alone (" .. tostring(value) .. ")")
    end
    P:Apply("qol")
    P:Apply("classic")
    for _, key in ipairs(STAT_KEYS) do Equal(saved[key], before[key], key .. " kept through both presets (" .. tostring(value) .. ")") end
    Equal(P:Current(), "classic", "the Stat Tracker never changes the preset (" .. tostring(value) .. ")")
end
for _, key in ipairs(STAT_KEYS) do saved[key] = nil end
saved.questTrackerChoice = "questie"; saved.questTracker = false
_, count = P:Changes("classic")
Equal(count, 0, "the Classic look keeps Questie's tracker when it was chosen")
saved.questTrackerChoice = ""; saved.questTracker = true

local applyingSeen
E.SetSetting = function(_, key, value) saved[key] = value; applyingSeen = P.applying end
P:Apply("qol")
Equal(applyingSeen, true, "applying is flagged, so the tracker prompt stays quiet")
Equal(P.applying, false, "flag cleared afterwards")
P:Apply("classic")
-- POISON! (the rogue's class reminder), Click to apply poisons and each
-- hand's poison are Quality of Life: no preset touches them. The picks are
-- the character's own (its class tools settings).
local poisonKeys = { classReminders = true, reminder_ROGUE_poison = false, reminderClickable = true,
    reminderPoisonClick = true }
for key, value in pairs(poisonKeys) do saved[key] = value end
local charBefore = EraUIClassicCharDB
EraUIClassicCharDB = { classTools = { poisonPickMain = 2892, poisonPickOff = 3775 } }
for _, name in ipairs({ "qol", "classic" }) do
    local changed = P:Changes(name)
    for key in pairs(poisonKeys) do Equal(changed[key], nil, P.NAMES[name] .. " leaves " .. key .. " alone") end
    P:Apply(name)
    for key, value in pairs(poisonKeys) do Equal(saved[key], value, key .. " kept after " .. P.NAMES[name]) end
    Equal(EraUIClassicCharDB.classTools.poisonPickMain == 2892 and EraUIClassicCharDB.classTools.poisonPickOff == 3775, true,
        "each hand's poison kept after " .. P.NAMES[name])
end
EraUIClassicCharDB = charBefore

-- Presets window ------------------------------------------------------------------------------

P:Show()
Equal(window.shown, true, "Presets window shown")
Equal(window.strata, "FULLSCREEN_DIALOG", "above the /era window")
Equal(window.current.text, "Current: Classic look", "shows the current preset")
Equal(window.close.label.text, "X", "the /era-style plain X, not Blizzard's red button")
window.qol:Click()
Equal(window.confirm.shown, true, "choosing asks for confirmation")
Equal(window.message.text:find(#P.LOOK + 0 .. " settings", 1, true) ~= nil, true, "says how many settings change")
Equal(window.message.text:find("reloads your UI", 1, true) ~= nil, true, "says it reloads")
Equal(saved.unitFrames, true, "nothing changes before confirming")
window.back:Click()
Equal(window.choices.shown, true, "Back returns to the choices")
Equal(saved.unitFrames, true, "Back changes nothing")

window.qol:Click()
combat = true
window.apply:Click()
Equal(reloads, 0, "no reload attempted in combat")
Equal(saved.unitFrames, true, "combat click changes nothing")
Equal(window.message.text:find("Finish combat", 1, true) ~= nil, true, "explains to finish combat first")
combat = false
window.apply:Click()
Equal(saved.unitFrames, false, "confirmed: the preset is applied")
Equal(reloads, 1, "and reloads straight from the click")

P:Show()
window.qol:Click()
Equal(window.apply.shown, false, "already using it: nothing to apply")
Equal(window.message.text:find("already using", 1, true) ~= nil, true, "says so")
window.back:Click()
Equal(window.shown, false, "OK closes the window")
P:Show()
window.close:Click()
Equal(window.shown, false, "the X closes the window")

print("Preset checks passed: " .. checks .. " assertions.")
