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
local E = {}
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
saved.questTrackerChoice = ""
saved.questTracker = true

-- Applying ----------------------------------------------------------------------------------

saved.darkMode, saved.classColourBorders = true, true
local _, count = P:Changes("qol")
Equal(count, #P.LOOK + 3, "Quality of Life only switches every Classic skin and optional look off")
P:Apply("qol")
Equal(saved.unitFrames, false, "Classic unit frames off")
Equal(saved.darkMode, false, "Dark Mode art off")
Equal(saved.damageMeterSkin, false, "damage meter skin off")
Equal(saved.vendorPrice, true, "QoL options untouched")
Equal(saved.cursorRing, true, "cursor effects untouched")
_, count = P:Changes("classic")
Equal(count, #P.LOOK, "the Classic look switches every Classic skin back on")
P:Apply("classic")
Equal(P:Current(), "classic", "Classic look restored")
Equal(saved.damageMeterSkin, false, "optional looks stay as chosen")
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
