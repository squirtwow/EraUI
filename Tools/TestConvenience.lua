-- Convenience (Modules/Convenience.lua: Hide Keybind Text, Hide Macro Names,
-- Hide Zone Text, Max Camera Zoom and more) on a small mock. Audit A15: a
-- burst of slot changes (a rank swap, a page change) or the other events it
-- listens to make one pass on the next frame, never one per event; a pass
-- still waits for the fight's end.
-- Run from the addon folder: fengari Tools/TestConvenience.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local settings = { hideKeybindText = true, hideMacroText = false }
local E = { modules = {} }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return settings[key] end
EraUIDB = {}
local combat = false
InCombatLockdown = function() return combat end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function NextFrame()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end
hooksecurefunc = function() end
local frames = {}
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end
-- The bars' hotkey labels.
local function Label()
    local alpha = 1
    return {
        SetAlpha = function(_, value) alpha = value end,
        GetAlpha = function() return alpha end,
    }
end
for _, prefix in ipairs({ "ActionButton", "MultiBarBottomLeftButton" }) do
    for i = 1, 12 do _G[prefix .. i .. "HotKey"] = Label() end
end

assert(loadfile("Modules/Convenience.lua"))("EraUI", E)
local Module = E.modules.Convenience
Module:Initialize()
local events = frames[1]
local function Fire(event) events.onEvent(events, event) end
Equal(ActionButton1HotKey:GetAlpha(), 0, "Hide Keybind Text on: the label hidden at once")

-- A burst: one pass on the next frame.
local passes = 0
local refresh = Module.Refresh
function Module:Refresh(...) passes = passes + 1; return refresh(self, ...) end
for _ = 1, 180 do Fire("ACTIONBAR_SLOT_CHANGED") end
Fire("UPDATE_BINDINGS"); Fire("PLAYER_ENTERING_WORLD")
Equal(passes, 0, "A15: 180 slot changes and more: no pass yet")
NextFrame()
Equal(passes, 1, "A15: one pass on the next frame")
NextFrame()
Equal(passes, 1, "A15: and only one")
Fire("ACTIONBAR_SLOT_CHANGED")
NextFrame()
Equal(passes, 2, "A15: a later change: its own pass")
-- In a fight the pass waits for its end, as before.
combat = true
Fire("ACTIONBAR_SLOT_CHANGED")
NextFrame()
Equal(Module.pending, true, "A15: in a fight the pass is kept for its end")
combat = false
Fire("PLAYER_REGEN_ENABLED")
NextFrame()
Equal(Module.pending, false, "A15: and runs once it ends")
-- A switch in /era still applies at once.
settings.hideKeybindText = false
passes = 0
Module:Refresh()
Equal(passes .. " " .. ActionButton1HotKey:GetAlpha(), "1 1", "a switch applies at once, the label back")

print("Convenience checks passed: " .. checks .. " assertions.")
