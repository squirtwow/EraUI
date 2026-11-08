-- Hide Zzz in Cities (/era > Frames & Nameplates > Unit Frames;
-- Modules/RestInCities.lua) on a small mock of the game: off by default; on,
-- in a capital (its map, a map inside it, or the zone's name against the
-- capitals' own map names) the game's own Zzz fades (alpha only) and EraUI's
-- 1.x frame is told at once; leaving, or switching it off, puts back only what
-- it faded. Secrets change nothing. Run from the addon folder.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Secrets: one stand-in value the game would keep hidden.
local SECRET = setmetatable({}, {__tostring = function() return "SECRET" end})
_G.issecretvalue = function(value) return value == SECRET end

-- Frames: events and scripts only.
local frames = {}
_G.CreateFrame = function()
    local f = {events = {}, scripts = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
local function Listening()
    local n = 0
    for _, f in ipairs(frames) do for _ in pairs(f.events) do n = n + 1 end end
    return n
end

-- Post-hooks as the game makes them: the original first, then the hook.
local hooks = 0
_G.hooksecurefunc = function(name, after)
    local original = _G[name]
    hooks = hooks + 1
    _G[name] = function(...) original(...); after(...) end
end

-- The game's player frame and its rest picture (alpha writes counted).
local writes = 0
local texture = {alpha = 1}
function texture:SetAlpha(a) self.alpha = a; writes = writes + 1 end
local loopShown = false
_G.PlayerFrame = {PlayerFrameContent = {PlayerFrameContentContextual = {PlayerRestLoop = {RestTexture = texture}}}}
_G.PlayerFrame_UpdatePlayerRestLoop = function(state) loopShown = state end

-- The world: maps by ID with parents and names, the map you're on, the zone.
local MAPS = {
    [947] = {name = "Azeroth"}, [1415] = {name = "Eastern Kingdoms", parentMapID = 947}, [1414] = {name = "Kalimdor", parentMapID = 947},
    [1429] = {name = "Elwynn Forest", parentMapID = 1415}, [1453] = {name = "Stormwind City", parentMapID = 1415},
    [1454] = {name = "Orgrimmar", parentMapID = 1414}, [1455] = {name = "Ironforge", parentMapID = 1415},
    [1456] = {name = "Thunder Bluff", parentMapID = 1414}, [1457] = {name = "Darnassus", parentMapID = 1414},
    [1458] = {name = "Undercity", parentMapID = 1415},
    [5001] = {name = "Cleft of Shadow", parentMapID = 1454}, -- a map inside a capital
    [84] = {name = "Stormwind City", parentMapID = 13},       -- a capital numbered another way
    [13] = {name = "Eastern Kingdoms"},
}
local here, zone = 1429, "Elwynn Forest"
_G.C_Map = {
    GetBestMapForUnit = function(unit) assert(unit == "player"); return here end,
    GetMapInfo = function(id) local m = MAPS[id]; return m and {mapID = id, name = m.name, parentMapID = m.parentMapID or 0} end,
}
_G.GetRealZoneText = function() return zone end

-- A mock EraUI: its settings and EraUI's 1.x player frame keeper.
local settings, kept
local function Load()
    frames, hooks, writes, kept = {}, 0, 0, 0
    texture.alpha = 1
    settings = {enabled = true, hideRestInCities = false}
    local E = {modules = {}, Look = {UF = {KeepPlayerState = function() kept = kept + 1 end}}}
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    function E:GetSetting(key) return settings[key] end
    assert(loadfile("Modules/RestInCities.lua"))("EraUI", E)
    local rest = E.modules.RestInCities
    rest:Initialize()
    return rest
end
local function Move(map, name, event)
    here, zone = map, name
    Fire(event or "ZONE_CHANGED_NEW_AREA")
end

-- Off (the default): nothing listened to or faded, even in a capital.
here, zone = 1453, "Stormwind City"
local rest = Load()
equal(tostring(rest:Hides()) .. " " .. Listening() .. " " .. writes .. " " .. hooks, "false 0 0 0", "off by default: no events, no hook, nothing faded")
PlayerFrame_UpdatePlayerRestLoop(true)
equal(texture.alpha .. " " .. writes, "1 0", "off: the game's Zzz left alone")

-- On in Stormwind: faded at once, EraUI's frame told.
settings.hideRestInCities = true
rest:Refresh()
equal(tostring(rest:Hides()) .. " " .. texture.alpha .. " " .. tostring(kept > 0) .. " " .. hooks, "true 0 true 1",
    "switched on in Stormwind City: the Zzz fades, EraUI's frame is told, one hook")
equal(Listening(), 5, "it listens for zone changes and resting")
rest:Refresh()
equal(hooks, 1, "hooked once, however often it refreshes")

-- Out to Elwynn: back to 1. Every zone event re-checks.
Move(1429, "Elwynn Forest")
equal(tostring(rest:Hides()) .. " " .. texture.alpha, "false 1", "leaving the city: the Zzz comes back")
for _, event in ipairs({"ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING", "PLAYER_ENTERING_WORLD"}) do
    Move(1458, "Undercity", event)
    equal(tostring(rest:Hides()) .. " " .. texture.alpha, "true 0", event .. " into Undercity: faded")
    Move(1429, "Elwynn Forest", event)
    equal(tostring(rest:Hides()) .. " " .. texture.alpha, "false 1", event .. " out again: back")
end

-- Every capital, and a map inside one.
for _, id in ipairs({1453, 1454, 1455, 1456, 1457, 1458, 5001}) do
    Move(id, MAPS[id].name)
    equal(rest:Hides(), true, MAPS[id].name .. " counts as a capital")
end
Move(1429, "Elwynn Forest")

-- The game shows its Zzz again (its own function): still faded in a city.
Move(1455, "Ironforge")
texture.alpha = 1 -- as if the game had put it back
PlayerFrame_UpdatePlayerRestLoop(true)
equal(tostring(loopShown) .. " " .. texture.alpha, "true 0", "the game's own rest update runs, then the Zzz fades again")

-- The name fallback: no map from the game, or a capital numbered another way.
Move(nil, "Orgrimmar")
equal(rest:Hides(), true, "no map from the game: the zone's name finds Orgrimmar")
Move(84, "Stormwind City")
equal(rest:Hides(), true, "a capital numbered another way: its name still counts")
Move(nil, "Elwynn Forest")
equal(rest:Hides(), false, "no map, a zone that isn't a capital: no")

-- Secrets: never compared, nothing changes.
Move(SECRET, "Elwynn Forest")
equal(rest:Hides(), false, "a secret map ID: not a capital (the name says Elwynn)")
Move(SECRET, SECRET)
equal(tostring(rest:Hides()) .. " " .. texture.alpha, "false 1", "a secret map and zone: not a capital, the Zzz shows")
local realInfo = C_Map.GetMapInfo
C_Map.GetMapInfo = function(id) local info = realInfo(id); if info then info.parentMapID = SECRET; info.name = SECRET end; return info end
Move(5001, "Cleft of Shadow")
equal(rest:Hides(), false, "a secret parent and names: no capital found, no error")
C_Map.GetMapInfo = realInfo

-- Switched off in a capital: the Zzz back, events dropped.
Move(1456, "Thunder Bluff")
equal(texture.alpha, 0, "in Thunder Bluff: faded")
settings.hideRestInCities = false
rest:Refresh()
equal(tostring(rest:Hides()) .. " " .. texture.alpha .. " " .. Listening(), "false 1 0", "switched off: the Zzz back, nothing listened to")
writes = 0
PlayerFrame_UpdatePlayerRestLoop(true)
equal(writes, 0, "off: the hook leaves the Zzz alone")

-- Only what it faded is put back: another fade it didn't make stays.
Move(1429, "Elwynn Forest")
texture.alpha = .5
settings.hideRestInCities = true
rest:Refresh()
Move(1429, "Elwynn Forest", "ZONE_CHANGED")
equal(texture.alpha, .5, "outside a city it never touches the Zzz")

-- EraUI switched off as a whole: nothing.
settings.enabled = false
rest:Refresh()
Move(1453, "Stormwind City")
equal(tostring(rest:Hides()) .. " " .. texture.alpha, "false 0.5", "EraUI off: nothing faded")
settings.enabled = true

-- A client without the game's frame or its rest function: no error.
_G.PlayerFrame = nil
_G.PlayerFrame_UpdatePlayerRestLoop = nil
rest = Load()
settings.hideRestInCities = true
rest:Refresh()
equal(tostring(rest:Hides()) .. " " .. hooks, "true 0", "no game frame: it still knows the city (for EraUI's frame), hooks nothing")

io.write("Hide Zzz in Cities checks passed: " .. checks .. " assertions.\n")
