-- "Fade map while moving" (registry entry "mapFade") on the real
-- Look/MapFadeSwitch.lua with Look/Base.lua, against a small mock of the
-- game's settings (C_CVar, which announces each change with CVAR_UPDATE as
-- the game does) and of the Classic engine's guarded setting writer
-- (13-old-base 4.9: refuses in a fight, skips a value the game already
-- holds, notes the game's value the first time EraUI changes it).
-- Checked: registered with an apply and a restore (no init); apply writes
-- "1", restore "0", each through the guarded writer only; no write while
-- the game already holds the value, none in a fight; the earlier value
-- noted once; the game's own change followed (the saved choice, the option
-- list refreshed), a lower-case name too; EraUI's own write never echoed
-- back; other settings ignored; nothing written without C_CVar.SetCVar; the
-- default added only where the engine has none.
-- Run: fengari Tools/TestMapFade.lua
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local combat, cvars, written, listeners, timers, errors
local ns, E, entries, refreshed

geterrorhandler = function() return function(problem) errors[#errors + 1] = tostring(problem) end end
InCombatLockdown = function() return combat end
hooksecurefunc = function() end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

-- A frame of EraUI's: events and scripts only.
CreateFrame = function()
    local frame = { events = {}, scripts = {} }
    function frame:RegisterEvent(event) self.events[event] = true; listeners[#listeners + 1] = self end
    function frame:SetScript(name, fn) self.scripts[name] = fn end
    function frame:HookScript() end
    return frame
end
local function Announce(name, value)
    for _, frame in ipairs(listeners) do
        if frame.events.CVAR_UPDATE and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, "CVAR_UPDATE", name, value) end
    end
end

local function Fresh(opts)
    opts = opts or {}
    combat, written, listeners, timers, errors, refreshed = false, {}, {}, {}, {}, 0
    cvars = { mapFade = opts.game or "1" }
    C_CVar = {
        GetCVar = function(name) return cvars[name] end,
        SetCVar = not opts.noSetter and function(name, value)
            cvars[name] = tostring(value)
            written[#written + 1] = name .. "=" .. tostring(value)
            Announce(name, tostring(value))
            return true
        end or nil,
    }
    entries = {}
    ns = { db = { mapFade = opts.saved == true }, DB_DEFAULTS = opts.defaults or {} }
    ns.RegisterModule = function(key, entry) entries[#entries + 1] = { key = key, entry = entry } end
    ns.RefreshOptionsWindow = function() refreshed = refreshed + 1 end
    -- The engine's guarded writer, as 13-old-base 4.9 describes it.
    ns.SetCVar = function(name, value)
        if not name or value == nil or InCombatLockdown() then return false end
        if not (C_CVar.SetCVar and C_CVar.GetCVar) then return false end
        local fine, now = pcall(C_CVar.GetCVar, name)
        if fine and now ~= nil and tostring(now) == tostring(value) then return true end
        ns.db.cvarWas = ns.db.cvarWas or {}
        if ns.db.cvarWas[name] == nil and fine and now ~= nil then ns.db.cvarWas[name] = tostring(now) end
        return (pcall(C_CVar.SetCVar, name, value))
    end
    E = { Classic = ns, modules = {} }
    function E:GetSetting() return nil end
    assert(loadfile("Look/Base.lua"))("EraUI", E)
    assert(loadfile("Look/MapFadeSwitch.lua"))("EraUI", E)
end
local function Entry()
    return entries[1] and entries[1].entry
end
local function Writes() return table.concat(written, ",") end

-- Registered ---------------------------------------------------------------------------------------
Fresh()
equal(#entries .. " " .. entries[1].key, "1 mapFade", "one registry entry, mapFade")
equal(type(Entry().apply) .. " " .. type(Entry().restore) .. " " .. type(Entry().init), "function function nil",
    "an apply and a restore, no init")
equal(tostring(ns.DB_DEFAULTS.mapFade), "false", "its default (off) added where the engine has none")
Fresh({ defaults = { mapFade = "theirs" } })
equal(ns.DB_DEFAULTS.mapFade, "theirs", "the engine's own default left alone")

-- Writing ----------------------------------------------------------------------------------------------
Fresh({ game = "1" })
Entry().restore()
equal(Writes() .. " " .. cvars.mapFade, "mapFade=0 0", "off (the default): the game's setting written 0")
equal(ns.db.cvarWas and ns.db.cvarWas.mapFade, "1", "the game's earlier value noted for the hand-back")
equal(tostring(ns.db.mapFade) .. " " .. refreshed, "false 0", "EraUI's own write didn't echo back into its choice")
RunTimers()
Entry().restore()
equal(Writes(), "mapFade=0", "off again: the game already holds 0, nothing written")
Entry().apply()
equal(Writes() .. " " .. cvars.mapFade, "mapFade=0,mapFade=1 1", "on: written 1")
equal(ns.db.cvarWas.mapFade, "1", "the earlier value noted only the first time")
RunTimers()
combat = true
Entry().restore()
equal(Writes(), "mapFade=0,mapFade=1", "in a fight: nothing written (the guarded writer refuses)")
combat = false
Fresh({ noSetter = true })
Entry().apply()
equal(Writes(), "", "without C_CVar.SetCVar: nothing")
equal(#errors, 0, "and no error")

-- Following the game's own setting ---------------------------------------------------------------------------
Fresh({ game = "0" })
Entry().restore()
RunTimers()
Announce("mapFade", "1")
equal(tostring(ns.db.mapFade) .. " " .. refreshed, "true 1", "the game's settings turned it on: EraUI's choice follows, the option list refreshed")
Announce("mapFade", "1")
equal(refreshed, 1, "the same value again: nothing more")
Announce("mapfade", "0")
equal(tostring(ns.db.mapFade) .. " " .. refreshed, "false 2", "a lower-case name followed too")
Announce("mapFade", 1)
equal(tostring(ns.db.mapFade), "true", "a number value: on")
Announce("mapFade", false)
equal(tostring(ns.db.mapFade), "false", "false: off")
Announce("rotateMinimap", "1")
equal(tostring(ns.db.mapFade) .. " " .. refreshed, "false 4", "another setting: ignored")
-- The next pass applies the followed choice; the game already holds it.
local before = Writes()
cvars.mapFade = "1"
Announce("mapFade", "1")
Entry().apply()
equal(Writes(), before, "the pass after a game change writes nothing (the game already holds it)")
-- A change while EraUI's own write is in progress is EraUI's echo: ignored
-- until the next frame.
Fresh({ game = "1" })
Entry().restore()
Announce("mapFade", "1")
equal(tostring(ns.db.mapFade) .. " " .. refreshed, "false 0", "during EraUI's own write: ignored")
RunTimers()
Announce("mapFade", "1")
equal(tostring(ns.db.mapFade) .. " " .. refreshed, "true 1", "a frame later: followed")
-- One listener, however many passes.
Fresh()
for _ = 1, 4 do Entry().restore(); Entry().apply() end
equal(#listeners, 1, "one listener of EraUI's, made once")
equal(table.concat(errors, " | "), "", "no Lua errors")

print("Map fade checks passed: " .. checks .. " assertions.")
