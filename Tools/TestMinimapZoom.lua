-- Remember Minimap Zoom (/era > Map & Minimap; Modules/MinimapZoom.lua)
-- against a mock of Forever's minimap (Blizzard_Minimap, camelot: the
-- Mainline Minimap.lua and .xml): one zoom for indoors and one for outdoors,
-- swapped by the game as you go in and out; Minimap:GetZoom/SetZoom/
-- GetZoomLevels; MINIMAP_UPDATE_ZOOM sent later, never inside SetZoom (it is
-- not a synchronous event); the + and - buttons (Minimap.ZoomIn/ZoomOut)
-- whose own click zooms one level, the mouse wheel and the zoom keys
-- pressing them. The game forgets both zooms at every login.
-- Off (the default): nothing listened to, hooked, kept or set. On: the zoom
-- you leave the minimap at is kept per place and put back after logging in
-- or a /reload, and the first time you go indoors or outdoors; values are
-- clamped to the levels the minimap has; your own zooming always wins; the
-- kept zooms survive a logout with both SavedVariables lost (the real
-- Core/Init.lua and Core/Persistence.lua). No key is written on the game's
-- frames and no global is made.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- The mock game ---------------------------------------------------------------
-- The game's frames are proxies: a key written on one shows up in writes.
local writes = {}
local function GameFrame(name, fields)
    return setmetatable({}, {
        __index = fields,
        __newindex = function(_, key, value) writes[#writes + 1] = name .. "." .. tostring(key); rawset(fields, key, value) end,
    })
end

local game, queue, frames, timers
local function Place() return game.indoors and "indoor" or "outdoor" end
-- The game's events: MINIMAP_UPDATE_ZOOM is a unique event (one a frame),
-- sent after the call that caused it.
local function Queue(event)
    for _, queued in ipairs(queue) do if queued == event then return end end
    queue[#queue + 1] = event
end
local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.events[event] and frame.script then frame.script(frame, event, ...) end
    end
end
local function Pump()
    for _ = 1, 20 do
        if #queue == 0 then return end
        local pending = queue; queue = {}
        for _, event in ipairs(pending) do Fire(event) end
    end
    error("events did not settle")
end

local function NewGame()
    game = {levels = 6, zooms = {outdoor = 0, indoor = 0}, indoors = false, time = 100, hooks = 0,
        asked = {}, clicking = false, secretPlace = false, secretZoom = false}
    queue, frames, timers = {}, {}, {}
    local hooks = {ZoomIn = {}, ZoomOut = {}}
    local function Button(key, step)
        local button
        button = GameFrame("Minimap." .. key, {
            HookScript = function(_, script, fn)
                game.hooks = game.hooks + 1
                game.hookedScript = script
                table.insert(hooks[key], fn)
            end,
            -- Blizzard's own OnClick (MinimapZoomIn/OutButtonMixin), then the post-hooks.
            Click = function()
                local level = game.zooms[Place()]
                local top = game.levels - 1
                game.clicking = true
                if step > 0 then Minimap:SetZoom(math.min(level, top - 1) + 1) else Minimap:SetZoom(math.max(1, level) - 1) end
                game.clicking = false
                for _, fn in ipairs(hooks[key]) do fn(button, "LeftButton") end
            end,
        })
        return button
    end
    Minimap = GameFrame("Minimap", {
        GetZoom = function()
            if game.secretZoom then return game.secret end
            return game.zooms[Place()]
        end,
        GetZoomLevels = function() return game.levels end,
        SetZoom = function(_, level)
            if not game.clicking then game.asked[#game.asked + 1] = level end
            -- The game keeps what it's given in range.
            level = math.max(0, math.min(game.levels - 1, math.floor(level)))
            if game.zooms[Place()] ~= level then game.zooms[Place()] = level; Queue("MINIMAP_UPDATE_ZOOM") end
        end,
    })
    rawset(getmetatable(Minimap).__index, "ZoomIn", Button("ZoomIn", 1))
    rawset(getmetatable(Minimap).__index, "ZoomOut", Button("ZoomOut", -1))
    IsIndoors = function()
        if game.secretPlace then return game.secret end
        return game.indoors
    end
    GetTime = function() return game.time end
    game.secret = setmetatable({}, {__tostring = function() return "secret" end})
    issecretvalue = function(value) return value == game.secret end
    C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
    CreateFrame = function()
        local frame = {events = {}}
        function frame:RegisterEvent(event) self.events[event] = true end
        function frame:UnregisterEvent(event) self.events[event] = nil end
        function frame:SetScript(script, fn) if script == "OnEvent" then self.script = fn end end
        frames[#frames + 1] = frame
        return frame
    end
end

-- What you do in the game.
local function Press(key, times) for _ = 1, times or 1 do Minimap[key]:Click(); Pump() end end
local function ZoomIn(times) Press("ZoomIn", times) end
local function ZoomOut(times) Press("ZoomOut", times) end
local function GoIndoors(inside)
    if game.indoors == inside then return end
    game.indoors = inside
    Queue("MINIMAP_UPDATE_ZOOM")
    Pump()
end
local function Wait(seconds) game.time = game.time + seconds end
local function Shown() return game.zooms[Place()] end
local function Asked() return table.concat(game.asked, ",") end
local function Listening(frame) local n = 0; for _ in pairs(frame and frame.events or {}) do n = n + 1 end; return n end

-- EraUI: the module alone, with the option as given (settings are the
-- account's, EraUIClassicCharDB is this character's SavedVariables).
local E, M, saves
local function LoadModule(on)
    saves = 0
    E = {modules = {}, settings = {enabled = true, rememberMinimapZoom = on}}
    function E:RegisterModule(name, module) self.modules[name] = module end
    function E:GetSetting(key) return self.settings[key] end
    function E:SaveSettings() saves = saves + 1 end
    assert(loadfile("Modules/MinimapZoom.lua"))("EraUI", E)
    M = E.modules.MinimapZoom
end
-- Logging in: the game has forgotten both zooms (default: where it starts),
-- EraUI loads, PLAYER_LOGIN runs Initialize, the loading screen ends.
local function Login(on, opts)
    opts = opts or {}
    game.zooms.outdoor, game.zooms.indoor = opts.default or 0, opts.default or 0
    game.indoors = opts.indoors == true
    game.asked, queue = {}, {}
    LoadModule(on)
    M:Initialize()
    Fire("PLAYER_ENTERING_WORLD", true, false)
    Pump()
end
-- A /reload: the game keeps its zooms unless told to forget them.
local function Reload(on, forget)
    if forget then game.zooms.outdoor, game.zooms.indoor = 0, 0 end
    game.asked, queue = {}, {}
    LoadModule(on)
    M:Initialize()
    Fire("PLAYER_ENTERING_WORLD", false, true)
    Pump()
end
local function Kept(place) local kept = EraUIClassicCharDB.minimapZoom; return kept and kept[place] end

local globalsBefore = {}
for key in pairs(_G) do globalsBefore[key] = true end

-- Off (the default) ------------------------------------------------------------
NewGame()
EraUIClassicCharDB = {minimapZoom = {outdoor = 4, indoor = 2}}
Login(nil)
equal(#frames, 0, "off at login: no event frame made")
equal(game.hooks, 0, "off at login: the zoom buttons aren't hooked")
equal(Shown() .. " " .. Asked(), "0 ", "off at login: a zoom kept earlier isn't put back")
ZoomIn(3); GoIndoors(true); ZoomIn(1); GoIndoors(false)
equal(Asked(), "", "off: EraUI never sets the zoom")
equal(Kept("outdoor") .. " " .. Kept("indoor") .. " " .. saves, "4 2 0", "off: nothing kept, nothing saved")
Login(false)
equal(#frames .. " " .. game.hooks .. " " .. Asked(), "0 0 ", "switched off: the same")
Reload(false, true)
equal(#frames .. " " .. game.hooks .. " " .. Asked() .. " " .. Shown(), "0 0  0", "off after a /reload: nothing")
equal(#writes, 0, "off: no key written on the game's frames")

-- On: outdoors, kept and put back after logging in ----------------------------
NewGame()
EraUIClassicCharDB = {}
Login(true)
equal(#frames, 1, "on at login: one event frame")
equal(frames[1].events.PLAYER_LEAVING_WORLD and frames[1].events.PLAYER_ENTERING_WORLD and frames[1].events.MINIMAP_UPDATE_ZOOM
    and Listening(frames[1]), 3, "it listens to the loading screen's start and end and the minimap's zoom only")
equal(game.hooks .. " " .. tostring(game.hookedScript), "2 OnClick", "both zoom buttons post-hooked, on their clicks")
equal(Asked() .. " " .. tostring(EraUIClassicCharDB.minimapZoom), " nil", "nothing kept yet: nothing put back, nothing made")
ZoomIn(3)
equal(Shown() .. " " .. Kept("outdoor") .. " " .. tostring(Kept("indoor")), "3 3 nil", "zoomed in three outdoors: kept for outdoors")
equal(saves, 3, "each new zoom saved (the save itself waits a moment and runs once)")
ZoomOut(1)
equal(Kept("outdoor"), 2, "zoomed back out one: kept as 2")
ZoomIn(9)
equal(Shown() .. " " .. Kept("outdoor"), "5 5", "all the way in: the last level, kept")
local savesBefore = saves
ZoomIn(1)
equal(saves, savesBefore, "pressing + at the last level changes nothing and saves nothing")
ZoomOut(3)
equal(Kept("outdoor"), 2, "left at 2")
Login(true)
equal(Shown() .. " " .. Asked(), "2 2", "logged in again: the game started at 0, EraUI put 2 back")
equal(Kept("outdoor"), 2, "still kept as 2")
Pump()
equal(Shown() .. " " .. Asked() .. " " .. Kept("outdoor"), "2 2 2", "the game's zoom event for EraUI's own change changes nothing")
-- The game that remembers a zoom across a /reload: nothing to do.
Reload(true, false)
equal(Shown() .. " " .. Asked(), "2 ", "a /reload the game kept the zoom through: EraUI sets nothing")
-- One that forgets it then: put back.
Reload(true, true)
equal(Shown() .. " " .. Asked(), "2 2", "a /reload the game forgot the zoom in: put back")

-- Indoors, kept apart and put back the first time you go in ------------------
GoIndoors(true)
equal(Shown() .. " " .. Asked() .. " " .. tostring(Kept("indoor")), "0 2 nil", "first time indoors: nothing kept for it, so nothing set")
ZoomIn(4)
equal(Shown() .. " " .. Kept("indoor") .. " " .. Kept("outdoor"), "4 4 2", "zoomed indoors: kept apart from outdoors")
GoIndoors(false)
equal(Shown() .. " " .. Kept("outdoor") .. " " .. Kept("indoor"), "2 2 4", "back outside: the game shows the outdoor zoom, nothing changes")
Login(true)
equal(Shown() .. " " .. Asked(), "2 2", "logged in outdoors: the outdoor zoom")
GoIndoors(true)
equal(Shown() .. " " .. Asked(), "4 2,4", "then the first time indoors: the indoor zoom put back")
GoIndoors(false); GoIndoors(true)
equal(Shown() .. " " .. Asked(), "4 2,4", "in and out again: only the first time each")
Login(true, {indoors = true})
equal(Shown() .. " " .. Asked(), "4 4", "logged in indoors: the indoor zoom")
GoIndoors(false)
equal(Shown() .. " " .. Asked(), "2 4,2", "then the first time outdoors: the outdoor zoom")
equal(Kept("outdoor") .. " " .. Kept("indoor"), "2 4", "putting them back keeps them as they were")

-- Clamped to the levels the minimap has ----------------------------------------
NewGame()
EraUIClassicCharDB = {minimapZoom = {outdoor = 9, indoor = -2}}
Login(true, {default = 2})
equal(Shown() .. " " .. Asked(), "5 5", "a kept 9 with six levels: the last one, 5")
GoIndoors(true)
equal(Shown() .. " " .. Asked(), "0 5,0", "a kept -2: the first level, 0")
EraUIClassicCharDB.minimapZoom = {outdoor = 2.6, indoor = "far"}
game.indoors = false
Login(true, {default = 0})
equal(Shown() .. " " .. Asked(), "3 3", "a kept 2.6: a whole level, 3")
GoIndoors(true)
equal(Shown() .. " " .. Asked(), "0 3", "a kept zoom that isn't a number: left alone")
game.levels = 4
EraUIClassicCharDB.minimapZoom = {outdoor = 5}
game.indoors = false
Login(true)
equal(Shown() .. " " .. Asked(), "3 3", "a minimap with fewer levels now: its last one")
for _, level in ipairs(game.asked) do
    equal(level >= 0 and level <= game.levels - 1 and level == math.floor(level), true, "every level EraUI sets is one the minimap has")
end
game.levels = 6
equal(Kept("outdoor"), 5, "clamping doesn't change what's kept")

-- Your own zooming always wins ---------------------------------------------------
NewGame()
EraUIClassicCharDB = {minimapZoom = {outdoor = 3, indoor = 4}}
Login(true)
equal(Shown(), 3, "logged in: 3 put back")
-- You go in and press + before the game's swap reaches EraUI.
game.indoors = true
Queue("MINIMAP_UPDATE_ZOOM")
Minimap.ZoomIn:Click()
Pump()
equal(Shown() .. " " .. Kept("indoor") .. " " .. Asked(), "1 1 3", "zoomed indoors before EraUI saw the swap: your 1 stays, kept, the 4 never set")
GoIndoors(false)
equal(Shown() .. " " .. Asked(), "3 3", "outside again: the game's outdoor zoom, nothing set")
-- In the first seconds after a loading screen, the game setting its own
-- zoom is put right; a click of yours in them is kept and wins.
Login(true)
ZoomIn(1)
equal(Shown() .. " " .. Kept("outdoor"), "4 4", "zoomed just after logging in: kept")
Minimap:SetZoom(0); game.asked = {}
Pump()
equal(Shown() .. " " .. Asked() .. " " .. Kept("outdoor"), "4 4 4", "the game then setting 0 by itself: your 4 put back, not the older 3")
-- After them, a change nobody clicked (another addon) is kept as yours, and
-- the next loading screen leaves it alone.
Wait(5)
Minimap:SetZoom(1); game.asked = {}
Pump()
equal(Shown() .. " " .. Kept("outdoor") .. " " .. Asked(), "1 1 ", "another addon's zoom later on: kept, not undone")
Fire("PLAYER_ENTERING_WORLD", false, false); Pump()
equal(Shown() .. " " .. Asked(), "1 ", "a loading screen with the zoom unchanged: nothing set")
-- After you've zoomed in a place, going in and out never puts an older one back.
ZoomIn(1)
GoIndoors(true)
equal(Shown() .. " " .. Asked(), "1 1", "indoors for the first time since logging in: your indoor 1 from before, not the older 4")
ZoomIn(2)
GoIndoors(false); GoIndoors(true)
equal(Shown() .. " " .. Kept("indoor") .. " " .. Asked(), "3 3 1", "zoomed indoors, out and back: your 3 stays")
GoIndoors(false)
equal(Shown() .. " " .. Kept("outdoor"), "2 2", "outdoors: your 2 from before")
-- The game swaps late at login: it said outdoors at first, then indoors.
NewGame()
EraUIClassicCharDB = {minimapZoom = {outdoor = 3, indoor = 1}}
Login(true)
GoIndoors(true)
equal(Shown() .. " " .. Asked(), "1 3,1", "the swap just after logging in: each place's own zoom")

-- A loading screen in play (a portal, an instance, a boat): the game may set
-- its own zoom while the world loads, before the loading screen is over.
-- That change isn't yours, so it is put right, never kept.
local function LoadingScreen(reset, inside)
    Fire("PLAYER_LEAVING_WORLD")
    if inside ~= nil then game.indoors = inside end
    if reset and game.zooms[Place()] ~= reset then game.zooms[Place()] = reset; Queue("MINIMAP_UPDATE_ZOOM") end
    Pump()
    game.asked = {}
    Fire("PLAYER_ENTERING_WORLD", false, false)
    Pump()
end
NewGame()
EraUIClassicCharDB = {}
Login(true)
ZoomIn(4)
Wait(10)
LoadingScreen(0)
equal(Shown() .. " " .. Kept("outdoor") .. " " .. Asked(), "4 4 4",
    "a loading screen in play, the game resetting the zoom as the world loads: your 4 kept and put back")
GoIndoors(true); ZoomIn(2); GoIndoors(false)
Wait(10)
LoadingScreen(0, true)
equal(Shown() .. " " .. Kept("indoor") .. " " .. Kept("outdoor") .. " " .. Asked(), "2 2 4 2",
    "one into an indoor place, reset as it loads: your indoor 2 put back, the outdoor 4 kept")
LoadingScreen(nil, false)
equal(Shown() .. " " .. Asked(), "4 ", "one that leaves the zoom alone: nothing set")

-- Switched on and off in play ------------------------------------------------------
NewGame()
EraUIClassicCharDB = {minimapZoom = {outdoor = 5, indoor = 5}}
Login(false)
ZoomIn(2)
E.settings.rememberMinimapZoom = true
M:Refresh()
equal(#frames .. " " .. game.hooks .. " " .. Listening(frames[1]), "1 2 3", "switched on: listening and hooked")
equal(Shown() .. " " .. Asked() .. " " .. Kept("outdoor") .. " " .. tostring(Kept("indoor")), "2  2 nil",
    "switched on: it starts from the zoom you have (2), older kept zooms forgotten, nothing set")
GoIndoors(true)
equal(Shown() .. " " .. Asked(), "0 ", "indoors: nothing kept for it, so nothing set")
ZoomIn(1)
equal(Kept("indoor"), 1, "and zooming there is kept")
E.settings.rememberMinimapZoom = false
M:Refresh()
equal(Listening(frames[1]), 0, "switched off: nothing listened to")
ZoomIn(2); GoIndoors(false); ZoomIn(1)
equal(Kept("indoor") .. " " .. Kept("outdoor") .. " " .. Asked(), "1 2 ", "switched off: nothing kept or set")
E.settings.rememberMinimapZoom = true
M:Refresh()
equal(game.hooks .. " " .. Listening(frames[1]) .. " " .. #frames, "2 3 1", "on again: the same frame, no second hook")
equal(Kept("outdoor") .. " " .. tostring(Kept("indoor")), "3 nil", "on again: from the zoom you have now")
E.settings.enabled = false
M:Refresh()
equal(Listening(frames[1]), 0, "EraUI switched off as a whole: nothing either")

-- What the game won't say -------------------------------------------------------------
NewGame()
EraUIClassicCharDB = {minimapZoom = {outdoor = 3}}
game.secretPlace = true
Login(true)
equal(Shown() .. " " .. Asked(), "0 ", "indoors or out hidden: nothing set")
ZoomIn(1)
equal(Kept("outdoor"), 3, "nor kept")
game.secretPlace, game.secretZoom = false, true
Fire("PLAYER_ENTERING_WORLD", false, false); Pump()
ZoomIn(1)
equal(Asked() .. " " .. Kept("outdoor"), " 3", "a hidden zoom: nothing set or kept")
game.secretZoom = false
local noReader = getmetatable(Minimap).__index
local getZoom = noReader.GetZoom
noReader.GetZoom = function() error("no minimap yet") end
Fire("PLAYER_ENTERING_WORLD", false, false); Pump()
equal(Asked(), "", "a minimap reader that errors: nothing set")
noReader.GetZoom = getZoom
-- A minimap that can't say yet how many levels it has: the next look tries again.
NewGame()
EraUIClassicCharDB = {minimapZoom = {outdoor = 3}}
game.levels = 0
Login(true)
equal(Shown() .. " " .. Asked(), "0 ", "the minimap's levels not known yet at login: nothing set")
game.levels = 6
Queue("MINIMAP_UPDATE_ZOOM"); Pump()
equal(Shown() .. " " .. Asked(), "3 3", "its next zoom event: the kept 3 goes back")
Wait(5)
Minimap:SetZoom(1); game.asked = {}; Pump()
equal(Shown() .. " " .. Asked() .. " " .. Kept("outdoor"), "1  1", "then done with: a later change is kept, not undone")

-- No key on the game's frames, no global ---------------------------------------------
equal(table.concat(writes, ","), "", "no key written on the game's frames")
local made = {}
for key in pairs(_G) do
    if not globalsBefore[key] and not ({Minimap = 1, IsIndoors = 1, GetTime = 1, issecretvalue = 1, C_Timer = 1, CreateFrame = 1,
        EraUIClassicCharDB = 1})[key] then made[#made + 1] = key end
end
table.sort(made)
equal(table.concat(made, ","), "", "no global made")
-- A character without saved data yet gets a table of its own.
NewGame()
EraUIClassicCharDB = nil
Login(true)
ZoomIn(2)
equal(type(EraUIClassicCharDB) .. " " .. Kept("outdoor"), "table 2", "no character data yet: made, and the zoom kept in it")

-- (The source rules, no GameTooltip, binding or secure hook, only the zoom
-- buttons' clicks post-hooked: Tools/TestRules.mjs.)

-- The real defaults and recovery: Core/Init.lua and Core/Persistence.lua -------------
-- Forever may lose SavedVariables; Persistence backs everything up in CVars.
-- The kept zooms are the character's, so they come back with it, and only
-- for it.
local cvars = {}
local character = "Hunter"
local function Session(account, char)
    NewGame()
    frames = {}
    EraUIDB, EraUIClassicCharDB, EraUIClassicDB = account, char, nil
    C_CVar = {
        GetCVar = function(name) return cvars[name] end,
        RegisterCVar = function(name, default) if cvars[name] == nil then cvars[name] = default end end,
        SetCVar = function(name, value) cvars[name] = value end,
    }
    GetCVarBool = function() return false end
    UnitFullName = function() return character, "RealmOne" end
    UnitName = function() return character end
    GetNormalizedRealmName = function() return "RealmOne" end
    DEFAULT_CHAT_FRAME = {AddMessage = function() end}
    local real = {}
    assert(loadfile("Core/Init.lua"))("EraUI", real)
    assert(loadfile("Core/Persistence.lua"))("EraUI", real)
    real.Classic = {db = {}, OnForever = function() return true end}
    assert(loadfile("Modules/MinimapZoom.lua"))("EraUI", real)
    Fire("ADDON_LOADED", "EraUI")
    real.Persistence:LoadAccount() -- as Core/Integration.lua does, once everything is loaded
    Fire("PLAYER_LOGIN")
    Fire("PLAYER_ENTERING_WORLD", true, false)
    Pump()
    return real
end
local function Flush()
    for _ = 1, 10 do
        if #timers == 0 then return end
        local pending = timers; timers = {}
        for _, fn in ipairs(pending) do fn() end
    end
end
local real = Session(nil, nil)
equal(real.settingDefaults.rememberMinimapZoom, false, "Remember Minimap Zoom off by default (Core/Init.lua)")
equal(real.reloadSettings.rememberMinimapZoom, nil, "it applies live, no reload")
equal(EraUIDB.rememberMinimapZoom, false, "a new account starts with it off")
equal(#frames, 2, "off: only Init's and Persistence's own event frames")
real:SetSetting("rememberMinimapZoom", true)
real.modules.MinimapZoom:Refresh()
ZoomIn(3)
GoIndoors(true); ZoomIn(1); GoIndoors(false)
Flush()
equal(EraUIClassicCharDB.minimapZoom.outdoor .. " " .. EraUIClassicCharDB.minimapZoom.indoor, "3 1", "switched on and zoomed: both kept")
Fire("PLAYER_LOGOUT")
-- The next login with both SavedVariables files lost: the game forgot the zoom too.
real = Session(nil, nil)
equal(EraUIDB.rememberMinimapZoom, true, "the option came back from the backup")
equal(Shown() .. " " .. Asked(), "3 3", "logged in again with SavedVariables lost: the outdoor zoom put back")
GoIndoors(true)
equal(Shown() .. " " .. Asked(), "1 3,1", "and the indoor one, the first time in")
ZoomOut(1)
Flush()
Fire("PLAYER_LOGOUT")
real = Session(nil, nil)
GoIndoors(true)
equal(Shown(), 0, "a zoom changed in the last session is the one that comes back")
-- Another character on the account has the option, not this one's zooms.
character = "Mage"
real = Session(nil, nil)
equal(tostring(EraUIDB.rememberMinimapZoom) .. " " .. Shown() .. " " .. Asked() .. " " .. tostring(EraUIClassicCharDB.minimapZoom), "true 0  nil",
    "another character: the option is the account's, the zooms aren't")
ZoomIn(2)
Flush()
Fire("PLAYER_LOGOUT")
character = "Hunter"
real = Session(nil, nil)
equal(Shown() .. " " .. EraUIClassicCharDB.minimapZoom.outdoor, "3 3", "the first character's zooms are its own")
-- With SavedVariables there as usual: the same.
local account, char = EraUIDB, EraUIClassicCharDB
Fire("PLAYER_LOGOUT")
real = Session(account, char)
equal(Shown() .. " " .. Asked(), "3 3", "SavedVariables kept: put back the same")

print("Minimap zoom checks passed: " .. checks .. " assertions.")
