-- The mini-games (Modules/MiniGames.lua, the shared core, and
-- Modules/MiniGameWhack.lua, Whack-a-Gnome / Whack-a-Peon) on a small mock
-- of the client: frames that show and hide down their own branch (OnShow and
-- OnHide fire only when that changes what's visible), events, timers, the
-- flight flag (UnitOnTaxi) set a moment after control goes, the flight map's
-- TakeTaxiNode and TaxiNodeName, fights, sounds and the faction.
-- Checks: the options default off and nothing opens or listens with them
-- off; the flight choice opens its game as you take off and closes it when
-- you land (a missed landing too); never in a fight, back after one; closed
-- by hand stays closed for that flight; scores kept per character and for the
-- account; the window's place kept; Whack's timing, 3, 2, 1, scoring,
-- streaks, misses, pausing and round end as plain rules; its field's layout
-- (every hole and its sunk target inside the field, rows never reaching into
-- each other); the faction picks the gnome or the peon, their ground and 3D
-- models (portraits when the client has none); the field's layers (mound,
-- target, the cover of the same ground in front, row by row from the back);
-- the mallet resting with its striking face on the pointer's tip and
-- swinging from there; /era whack opening the stage map, a Quick round from
-- it, landing keeping the round for the next flight; a round's
-- banners, bursts, words, voices, timer and fanfare (Whack's stages, cards,
-- decoys, bosses and tune: Tools/TestWhackStages.lua); /era
-- whack and /era blast; the window's look (its stone, the framed play area
-- in your faction's metal, the note line, EraUI's buttons); the Switch button
-- both ways, on the ground and on a flight; the effects kit (sparks, floating
-- words, the banner, a shake, a pulse, a pop, a tween), pooled, capped,
-- moved only while one runs and cleared as the window hides; the sounds by
-- name; the header's score counting up. Run: fengari Tools/TestMiniGames.lua
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
local function near(got, want, label)
    checks = checks + 1
    assert(type(got) == "number" and math.abs(got - want) < 1e-6, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = table.unpack or unpack

-- The mock client -------------------------------------------------------------------

local world, frames, timers, sounds, printed, saves, hooks
local SECRET = setmetatable({}, {__tostring = function() return "secret" end})
local missing = {}   -- file paths and atlases the client refuses
local methods = {}
-- A PlayerModel's own calls, only when the world has models (else a model
-- frame is a plain frame, as on a client that can't show one).
local modelMethods = setmetatable({}, {__index = methods})
local MODEL_META = {__index = modelMethods}

local function Visible(f) return f.shown and (f.parent == nil or Visible(f.parent)) end
local function Visit(f, script)
    f:Fire(script)
    for _, child in ipairs(f.children) do if child.shown then Visit(child, script) end end
end
local function Frame(kind, name, parent, template)
    local meta = (kind == "PlayerModel" and world.models) and MODEL_META or {__index = methods}
    local f = setmetatable({kind = kind, name = name, parent = parent, template = template, shown = true, points = {},
        scripts = {}, events = {}, children = {}, calls = {}, level = parent and (parent.level or 1) + 1 or 1}, meta)
    if meta == MODEL_META then f.anims = {} end
    if parent then parent.children[#parent.children + 1] = f end
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function methods:Fire(script, ...)
    local fn = self.scripts[script]
    if fn then return fn(self, ...) end
end
function methods:Note(call) self.calls[call] = (self.calls[call] or 0) + 1 end
function methods:SetScript(script, fn) self.scripts[script] = fn end
function methods:GetScript(script) return self.scripts[script] end
function methods:HookScript(script, fn)
    local old = self.scripts[script]
    self.scripts[script] = function(...) if old then old(...) end; fn(...) end
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return Visible(self) end
function methods:SetShown(on)
    on = not not on
    if self.shown == on then return end
    local parentVisible = self.parent == nil or Visible(self.parent)
    self.shown = on
    if parentVisible then Visit(self, on and "OnShow" or "OnHide") end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetSize(w, h) self.w, self.h = w, h; if #self.points == 0 then self.sizedFirst = true end end
function methods:SetWidth(w) self.w = w end
function methods:SetHeight(h) self.h = h end
function methods:GetWidth() return self.w end
function methods:GetHeight() return self.h end
function methods:SetPoint(point, ...) self.points[#self.points + 1] = {point, ...}; self.lastPoint = {point, ...} end
function methods:ClearAllPoints() self.points = {} end
function methods:SetAllPoints(other) self.points = {{"ALL", other}} end
function methods:GetLeft() return self.left end
function methods:GetTop() return self.top end
function methods:SetFrameStrata(strata) self.strata = strata end
function methods:SetToplevel(on) self.toplevel = on end
function methods:SetClampedToScreen(on) self.clamped = on end
function methods:SetMovable(on) self.movable = on end
function methods:SetDontSavePosition(on) self.dontSave = on end
function methods:SetUserPlaced(on) self.userPlaced = on end
function methods:EnableMouse(on) self.mouse = on end
function methods:EnableKeyboard() self:Note("EnableKeyboard") end
function methods:SetPropagateKeyboardInput() self:Note("SetPropagateKeyboardInput") end
function methods:RegisterForDrag(button) self.drag = button end
function methods:RegisterForClicks(...) self.clicks = {...} end
function methods:StartMoving() self.moving = true end
function methods:StopMovingOrSizing() self.moving = false end
function methods:Raise() self:Note("Raise") end
function methods:SetFrameLevel(level) self.level = level end
function methods:GetFrameLevel() return self.level end
function methods:SetClipsChildren(on) self.clips = on end
function methods:SetBackdrop(backdrop) self.backdrop = backdrop end
function methods:SetBackdropColor(...) self.backdropColour = {...} end
function methods:SetBackdropBorderColor(...) self.borderColour = {...} end
function methods:SetAlpha(a) self.alpha = a end
function methods:GetAlpha() return self.alpha or 1 end
function methods:SetScale(s) assert(type(s) == "number" and s > 0, "a scale over 0"); self.scale = s end
function methods:GetScale() return self.scale or 1 end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:Click(button) self:Fire("PreClick", button); self:Fire("OnClick", button) end
function methods:CreateTexture(_, layer, _, sublevel) local t = Frame("Texture", nil, self); t.layer, t.sublevel = layer, sublevel; return t end
function methods:CreateMaskTexture() return Frame("MaskTexture", nil, self) end
function methods:CreateFontString() return Frame("FontString", nil, self) end
-- Textures and text.
function methods:SetTexture(path, wrapH, wrapV)
    self.texture, self.wrapH, self.wrapV = path, wrapH, wrapV
    if missing[path] then return false end
    return true
end
function methods:SetRotation(radians) self.rotation = radians end
function methods:SetGradient(orientation, low, high) self.gradient = {orientation, low, high} end
function methods:SetAtlas(atlas) self.atlas = atlas end
function methods:SetColorTexture(...) self.colour = {...} end
function methods:SetVertexColor(...) self.vertex = {...} end
function methods:SetTexCoord(...) self.coords = {...} end
function methods:SetBlendMode(mode) self.blend = mode end
function methods:AddMaskTexture(mask) self.mask = mask end
function methods:SetFont(...) self.font = {...} end
function methods:SetTextColor(...) self.textColour = {...} end
function methods:SetJustifyH(j) self.justify = j end
function methods:SetWordWrap(on) self.wrap = on end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
-- A plain line's width: 6 px a character.
function methods:GetStringWidth() return #tostring(self.text or "") * 6 end
function methods:SetSnapToPixelGrid(on) self.snap = on end
function methods:SetTexelSnappingBias(bias) self.snapBias = bias end
function methods:GetEffectiveScale() return world.scale or 1 end
function methods:IsMouseOver() return self.mouseOver == true end
-- The model calls Whack makes (FrameAPICharacterModelBase).
function modelMethods:SetDisplayInfo(id)
    if world.badModels[id] then error("no such model " .. id) end
    self.display = id
end
function modelMethods:GetDisplayInfo() return self.display or 0 end
function modelMethods:SetAnimation(anim) self.anims[#self.anims + 1] = anim; self.anim = anim end
function modelMethods:SetKeepModelOnHide(on) self.keep = on end
function modelMethods:SetPortraitZoom(zoom) self.zoom = zoom end
function modelMethods:SetCamDistanceScale(scale) self.camera = scale end
function modelMethods:SetRotation(radians, animate) self.rotation, self.animateTurn = radians, animate end

local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
-- Time passes: timers that come due run, and the shown frames' OnUpdate
-- runs every step (as the client does only for visible frames).
local function Tick(seconds, step)
    step = step or .05
    local passed = 0
    while passed < seconds - 1e-9 do
        local dt = math.min(step, seconds - passed)
        passed = passed + dt
        world.time = world.time + dt
        local due = {}
        for i = #timers, 1, -1 do
            if timers[i].at <= world.time + 1e-9 then table.insert(due, 1, timers[i].fn); table.remove(timers, i) end
        end
        for _, fn in ipairs(due) do fn() end
        for _, f in ipairs(frames) do
            if f.scripts.OnUpdate and Visible(f) then f.scripts.OnUpdate(f, dt) end
        end
    end
end

local function NewWorld(opts)
    opts = opts or {}
    world = {time = 100, taxi = opts.taxi == true, combat = false, faction = opts.faction or "Horde",
        models = opts.models == true, badModels = opts.badModels or {}}
    frames, timers, sounds, printed, saves, hooks = {}, {}, {}, {}, 0, {}
    missing = opts.missing or {}
    -- The pointer (screen pixels), only when asked for.
    GetCursorPosition = opts.cursor and function() return world.cursorX or 0, world.cursorY or 0 end or nil
    UIParent = Frame("Frame", "UIParent")
    UIParent.w, UIParent.h = 1600, 1000
    _G.EraUIMiniGames = nil
    GameFontHighlight = {GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end}
    CreateFrame = Frame
    UISpecialFrames = {}
    issecretvalue = function(v) return v == SECRET end
    UnitOnTaxi = function(unit) assert(unit == "player"); return world.taxi end
    UnitFactionGroup = function() return world.faction end
    UnitClass = function() return "Warrior", "WARRIOR" end
    RAID_CLASS_COLORS = {WARRIOR = {r = .78, g = .61, b = .43}}
    InCombatLockdown = function() return world.combat end
    GetTime = function() return world.time end
    C_Timer = {After = function(delay, fn) timers[#timers + 1] = {at = world.time + delay, fn = fn} end}
    -- Each sound played gets a handle: its place in sounds.
    PlaySound = function(id, channel) sounds[#sounds + 1] = id .. ":" .. tostring(channel); return true, #sounds end
    PlaySoundFile = function(file, channel) sounds[#sounds + 1] = "file " .. file .. ":" .. tostring(channel); return true, #sounds end
    StopSound = function(handle) world.stopped[#world.stopped + 1] = handle end
    world.stopped = {}
    -- The colour objects SetGradient takes, only when asked for (else the flat fallback).
    CreateColor = opts.gradients and function(r, g, b, a) return {r = r, g = g, b = b, a = a} end or nil
    IsMouseButtonDown = function() return false end
    C_Texture = {GetAtlasInfo = function(name) if missing[name] then return nil end; return {width = 128, height = 128} end}
    world.nodes = {[3] = "Orgrimmar, Durotar", [5] = "Crossroads, The Barrens"}
    TakeTaxiNode = function(index) world.took = index end
    TaxiNodeName = function(index) return world.nodes[index] end
    hooksecurefunc = function(name, fn)
        hooks[#hooks + 1] = name
        local old = _G[name]
        _G[name] = function(...) local result = old(...); fn(...); return result end
    end
end

-- EraUI: the two files alone, with SavedVariables as given (EraUIDB: the
-- account's settings; EraUIClassicCharDB: this character's).
local E, MG, W
local function Session(opts)
    opts = opts or {}
    NewWorld(opts)
    EraUIDB = opts.db or {}
    if EraUIDB.miniGameFlight == nil then EraUIDB.miniGameFlight = "off" end
    if EraUIDB.miniGameSounds == nil then EraUIDB.miniGameSounds = true end
    EraUIClassicCharDB = opts.char or {}
    E = {modules = {}}
    function E:RegisterModule(name, module) self.modules[name] = module end
    function E:GetSetting(key) return EraUIDB[key] end
    function E:SetSetting(key, value) EraUIDB[key] = value end
    function E:SaveSettings() saves = saves + 1 end
    function E:Print(message) printed[#printed + 1] = message end
    function E:Status() end
    if opts.closeX then
        function E:CreateCloseX(parent, onClick)
            local close = CreateFrame("Button", nil, parent)
            close:SetSize(36, 36)
            close:SetPoint("TOPRIGHT", -8, -8)
            close:SetScript("OnClick", onClick)
            close.fromPresets = true
            return close
        end
    end
    -- The core and its helpers, Whack, then (when asked) Azeroth Blast, in EraUI.toc's order.
    for _, name in ipairs({"MiniGames", "MiniGameFX", "MiniGameAssets", "MiniGameProgress", "MiniGameMap", "MiniGameCards",
        "MiniGameShop", "MiniGameWhackStages", "MiniGameWhack", "MiniGameWhackHud"}) do
        assert(loadfile("Modules/" .. name .. ".lua"))("EraUI", E)
    end
    if opts.blast then
        for _, name in ipairs({"MiniGameBlast", "MiniGameBlastGoals", "MiniGameBlastLevels", "MiniGameBlastView",
            "MiniGameBlastHud", "MiniGameBlastGame"}) do
            assert(loadfile("Modules/" .. name .. ".lua"))("EraUI", E)
        end
    end
    MG = E.MiniGames
    W = MG.Whack
    if opts.random then MG.Random = opts.random end
    if not opts.noInit then
        MG:Initialize()
        Fire("PLAYER_ENTERING_WORLD", true, false)
    end
    return MG
end
local function Shell() return _G.EraUIMiniGames end
local function Showing() return Shell() ~= nil and Shell():IsVisible() end
local function Whack() return MG.games.whack end
local function Listening(event) return MG.events ~= nil and MG.events.events[event] == true end
local function Last() return printed[#printed] end
local function Words(...) local out = {}; for i = 1, select("#", ...) do out[i] = tostring((select(i, ...))) end; return table.concat(out, " ") end
-- A random that goes round 1, 2, 3...
local function Cycle()
    local n = 0
    return function(low, high)
        n = n + 1
        return low + (n - 1) % (high - low + 1)
    end
end
local function TakeOff(node)
    if node then TakeTaxiNode(node) end
    world.taxi = true
    Fire("PLAYER_CONTROL_LOST")
end
local function Land()
    world.taxi = false
    Fire("PLAYER_CONTROL_GAINED")
end
-- Plays until a head is up (or gives up after ten seconds). Returns its hole.
local function UntilUp()
    for _ = 1, 200 do
        if Whack().state.hole then return Whack().state.hole end
        Tick(.05)
    end
end
local function Bonk()
    local hole = UntilUp()
    Whack().holes[hole]:Click("LeftButton")
    return hole
end
-- The field, ready for a Quick round, instead of the stage map /era whack opens on.
local function OnField() Whack():Screen("quick") end

-- The options' defaults: the real Core/Init.lua ---------------------------------------

do
    NewWorld()
    local init = {}
    assert(loadfile("Core/Init.lua"))("EraUI", init)
    equal(init.settingDefaults.miniGameFlight, "off", "On a Flight Path is Off by default")
    equal(init.settingDefaults.miniGameSounds, true, "Mini-game Sounds on by default")
    equal(init.reloadSettings.miniGameFlight == nil and init.reloadSettings.miniGameSounds == nil, true, "both apply live, no reload")
end

-- Whack's rules (no frames) -------------------------------------------------------------

Session()
do
    local up, gap = W.Timing(0)
    near(up, 1, "a head stays up 1 s as a round starts"); near(gap, .45, "and .45 s go by before the next")
    up, gap = W.Timing(15)
    near(up, .75, "halfway: .75 s up"); near(gap, .3, "halfway: .3 s apart")
    up, gap = W.Timing(30)
    near(up, .5, "at the end: half a second up"); near(gap, .15, "at the end: .15 s apart")
    near((W.Timing(-4)), 1, "before the start counts as the start"); near((W.Timing(99)), .5, "after the end counts as the end")
    local last = math.huge
    for t = 0, 30, 2.5 do
        local now = W.Timing(t)
        equal(now <= last, true, "never slower as the round goes on (" .. t .. " s)")
        last = now
    end

    local s = W.New(function() return 5 end)
    equal(s.phase .. " " .. s.score .. " " .. s.left, "ready 0 30", "a new round waits for Start, 30 seconds")
    equal(W.Advance(s, 1), nil, "no time passes before Start")
    equal(W.Hit(s, 5), false, "and no point")
    W.Start(s)
    equal(s.phase, "playing", "Start plays")
    local happened = W.Advance(s, .55)
    equal(s.hole == nil and happened.popped == nil, true, "no head for the first .6 s")
    happened = W.Advance(s, .05)
    equal(happened.popped .. " " .. s.hole .. " " .. s.pops, "5 5 1", "then a head comes up")
    near(s.upFor, (W.Timing(.6)), "for as long as the timing says")
    equal(W.Hit(s, 4), false, "a click on another hole: no point")
    equal(s.score, 0, "still 0")
    equal(W.Hit(s, 5), "normal", "a click on the head: a point")
    equal(s.score .. " " .. tostring(s.hole) .. " " .. s.last, "1 nil 5", "and it ducks at once")
    equal(W.Hit(s, 5), false, "the same head can't be hit twice")
    near(s.wait, select(2, W.Timing(s.elapsed)), "the next waits the gap")

    -- A head left alone ducks after its time, no point.
    s = W.New(function() return 2 end)
    W.Start(s)
    W.Advance(s, .6)
    equal(s.hole, 2, "a head is up")
    happened = W.Advance(s, s.upFor - .05)
    equal(s.hole, 2, "still up just before its time")
    happened = W.Advance(s, .05)
    equal(happened.ducked .. " " .. tostring(s.hole) .. " " .. s.score, "2 nil 0", "then it ducks unhit")

    -- Never the same hole twice in a row: with the last at 5, rolls 1 to 8
    -- give every other hole once.
    s = W.New(Cycle())
    s.last = 5
    local seen = {}
    for _ = 1, 8 do seen[#seen + 1] = W.PickHole(s) end
    equal(table.concat(seen, ","), "1,2,3,4,6,7,8,9", "any hole but the last one")
    s.last = nil
    equal(W.PickHole(W.New(function() return 9 end)), 9, "with no last, all nine can come up")
    equal(W.PickHole(W.New(function() return 42 end)), 9, "an odd roll is kept on the board")

    -- A whole round, hitting nothing: quicker heads at the end, then over.
    s = W.New(Cycle())
    W.Start(s)
    local early, late, done = 0, 0, nil
    for _ = 1, 1000 do
        if s.phase ~= "playing" then break end
        happened = W.Advance(s, .05)
        if happened.popped then
            if s.elapsed <= 10 then early = early + 1 elseif s.elapsed > 20 then late = late + 1 end
        end
        if happened.over then done = s.elapsed end
    end
    equal(late > early, true, "more heads in the last 10 s than the first 10 (" .. early .. ", " .. late .. ")")
    near(done, 30, "the round ends at 30 s")
    equal(s.phase .. " " .. s.left .. " " .. tostring(s.hole), "over 0 nil", "over: no time left, no head up")
    equal(W.Advance(s, 1), nil, "no more time once it's over")
    equal(W.Hit(s, s.last or 1), false, "no more points")

    -- Pausing stops the clock; resuming carries on.
    s = W.New(Cycle())
    W.Start(s)
    W.Advance(s, 2)
    local at = s.elapsed
    equal(W.Pause(s), true, "a round being played pauses")
    equal(W.Advance(s, 5), nil, "a paused round doesn't move")
    near(s.elapsed, at, "its clock stopped")
    equal(W.Hit(s, s.hole or 1), false, "no points while paused")
    equal(W.Pause(s), false, "pausing twice does nothing")
    equal(W.Resume(s), true, "it resumes")
    W.Advance(s, 1)
    near(s.elapsed, at + 1, "and its clock runs again")
    equal(W.Resume(W.New()), false, "a round never started doesn't resume")
    W.Pause(s)
    equal(W.Finish(s), true, "a paused round can be finished (landing)")
    equal(s.phase, "over", "over")
    equal(W.Finish(W.New()), false, "a round never started can't be")

    -- A long frame moves the round as many short ones would.
    local a, b = W.New(Cycle()), W.New(Cycle())
    W.Start(a); W.Start(b)
    W.Advance(a, 3)
    for _ = 1, 30 do W.Advance(b, .1) end
    near(a.elapsed, b.elapsed, "one long frame keeps time")
    equal(a.pops .. " " .. tostring(a.hole), b.pops .. " " .. tostring(b.hole), "and pops as many heads")

    -- The faction picks the head.
    equal(W.Target("Horde").accent, "Gnome", "the Horde whacks gnomes")
    equal(W.Target("Alliance").accent, "Peon", "the Alliance whacks peons")
    equal(W.Target(nil).accent .. W.Target("Neutral").accent, "GnomeGnome", "anyone else gets the gnome")
    equal(W.Target("Horde").file, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Gnome", "the gnome's own portrait")
    equal(W.Target("Alliance").file, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc", "the peon's: the orc portrait")
    equal(W.Target("Horde").displays[1] .. " " .. W.Target("Alliance").displays[1], "6973 10038", "the gnome's and the peon's 3D models")

    -- The 3, 2, 1 before a round: no heads and no points, then play.
    s = W.New(function() return 4 end)
    W.Begin(s)
    equal(s.phase .. " " .. s.count .. " " .. s.left .. " " .. s.score, "countdown 3 30 0", "Begin counts 3, 2, 1 first")
    equal(W.Hit(s, 4) or W.Miss(s), false, "no point or miss while it counts")
    happened = W.Advance(s, .5)
    equal(tostring(happened.count) .. " " .. tostring(happened.go), "nil nil", "half a second in: still 3")
    happened = W.Advance(s, .6)
    equal(happened.count, 2, "then 2")
    local again = W.Advance(s, 1)
    equal(again == happened and again.count, 1, "then 1 (the same report, cleared each time)")
    happened = W.Advance(s, .9)
    equal(happened.go and s.phase, "playing", "then play")
    near(s.elapsed, 0, "the round's clock starts there")
    equal(happened.popped, nil, "no head at once")
    happened = W.Advance(s, .6)
    equal(happened.popped, 4, "the first head .6 s later")
    -- A long frame through the count carries on into the round.
    s = W.New(function() return 2 end)
    W.Begin(s)
    happened = W.Advance(s, 3.7)
    equal(happened.go and happened.popped, 2, "a long frame: the count ends and play goes on in it")
    near(s.elapsed, .7, "the time left over is played")
    -- The count pauses, resumes and can be finished.
    s = W.New(Cycle())
    W.Begin(s)
    W.Advance(s, 1.5)
    equal(W.Pause(s) and s.phase .. " " .. s.was, "paused countdown", "the count pauses")
    equal(W.Advance(s, 5), nil, "and doesn't move")
    near(s.count, 1.5, "its seconds kept")
    equal(W.Resume(s) and s.phase, "countdown", "it resumes counting")
    equal(W.Finish(s) and s.phase .. " " .. s.left, "over 0", "a count can be finished (landing)")

    -- Streaks: hits in a row; a miss or a head ducking unhit ends one.
    local function Up(state)
        for _ = 1, 400 do
            if state.hole then return state.hole end
            W.Advance(state, .05)
        end
    end
    s = W.New(Cycle())
    W.Start(s)
    for _ = 1, 3 do W.Hit(s, Up(s)) end
    equal(s.streak .. " " .. s.bestStreak .. " " .. s.score, "3 3 3", "three hits in a row: a streak of 3")
    equal(W.Miss(s) and s.streak .. " " .. s.misses .. " " .. s.bestStreak .. " " .. s.score, "0 1 3 3",
        "a miss ends it (its best kept, no point lost)")
    W.Hit(s, Up(s))
    Up(s)
    happened = W.Advance(s, s.upFor + .01)
    equal(happened.ducked ~= nil and s.streak, 0, "a head ducking unhit ends it too")
    equal(W.Miss(W.New()), false, "no miss before a round")
    equal(W.StreakWord(5) .. "|" .. W.StreakWord(10) .. "|" .. W.StreakWord(15) .. "|" .. W.StreakWord(20) .. "|" .. W.StreakWord(45),
        "On a roll!|Unstoppable!|Whack master!|Legendary!|Legendary!", "a word on every fifth in a row")
    equal(W.StreakWord(4) == nil and W.StreakWord(7) == nil and W.StreakWord(0) == nil and W.StreakWord(nil) == nil, true, "and only then")
    W.Begin(s)
    equal(s.streak .. s.bestStreak .. s.misses .. s.score .. s.pops, "00000", "a new round starts it all again")
end

-- The field's layout (no frames) ------------------------------------------------------------

do
    local inside, apart, rows, pairsApart, hud, sunk = true, true, true, true, true, true
    local V = W.VIEW
    equal(V.W .. "x" .. V.H, MG.CONTENT_W .. "x" .. MG.CONTENT_H, "the field fills the bigger play area")
    for index = 1, W.HOLES do
        local g = W.Spot(index)
        -- Every mound inside the field (the edge's 3 px in), clear of the timer under the front row.
        if g.cx - g.mw / 2 < 3 or g.cx + g.mw / 2 > V.W - 3 or g.my + g.mh / 2 > V.BAR_Y - V.BAR_H then inside = false end
        -- All the way up, a head (a boss's too) stays under the HUD band.
        if g.top < V.HUD_H or g.bossTop < V.HUD_H then hud = false end
        -- A sunk target's picture (its frame less the empty share under it) stays in the field.
        for _, framing in pairs(W.FRAMING) do
            if g.bottom + g.bh * framing.body * (1 - framing.lift) > V.H + 1 then sunk = false end
        end
        -- A target's width stays inside its hole, so the hole's near edge hides it;
        -- the cover is as wide as a boss.
        if g.bw / 2 + 1 >= g.hw / 2 or g.c < g.bw * V.BOSS / 2 then apart = false end
        local right = index % 3 ~= 0 and W.Spot(index + 1)
        if right and g.cx + g.mw / 2 > right.cx - right.mw / 2 then pairsApart = false end
        local below = index <= 6 and W.Spot(index + 3)
        -- A row's click area (a boss's head all the way up to the mound's foot) never reaches the next.
        if below and g.my + g.mh / 2 >= below.bossTop - 6 * below.k then rows = false end
        if below and below.k <= g.k then rows = false end
    end
    equal(inside, true, "every hole inside the field, the timer clear")
    equal(hud, true, "the HUD band clear of every head, a boss's too")
    equal(sunk, true, "every sunk target's picture inside the field")
    equal(apart, true, "every target narrower than its hole, the cover as wide as a boss")
    equal(pairsApart, true, "mounds side by side never overlap")
    equal(rows, true, "rows bigger towards the front, never reaching into each other")
end

-- Off (the default): nothing listens, opens or hooks ------------------------------

Session()
equal(Listening("PLAYER_CONTROL_LOST") or Listening("PLAYER_CONTROL_GAINED") or Listening("PLAYER_ENTERING_WORLD"), false,
    "with On a Flight Path off no flight event is heard")
equal(Listening("PLAYER_REGEN_DISABLED"), false, "nor fights, before a game was ever opened")
equal(#hooks, 0, "and nothing is hooked")
TakeOff(3); Tick(4)
equal(Shell(), nil, "taking off opens nothing")
Land(); Tick(2)
equal(Shell() == nil and #printed == 0, true, "landing neither; nothing said")
MG:Refresh()
equal(Listening("PLAYER_CONTROL_LOST") or #hooks > 0, false, "Refresh with it off still listens to nothing")

Session({noInit = true})
equal(MG:Toggle("whack"), false, "before it starts up, /era whack does nothing")
equal(Last(), "Mini-games are not available.", "and says so")

-- The window -------------------------------------------------------------------------------

Session({closeX = true})
equal(MG:Toggle("whack"), true, "/era whack opens Whack")
local shell = Shell()
equal(shell ~= nil and Showing(), true, "the mini-games window shows")
equal(shell.strata .. " " .. shell.w .. "x" .. shell.h, "DIALOG 440x650", "DIALOG, 440 x 650 (bigger pieces and room for the levels)")
equal(shell.sizedFirst, true, "sized before anything placed it")
equal(shell.toplevel and shell.clamped and shell.movable and shell.mouse and shell.drag == "LeftButton" and shell.dontSave, true,
    "comes to the front, stays on screen, moves by dragging, its place EraUI's own")
equal(shell.calls.EnableKeyboard == nil and shell.calls.SetPropagateKeyboardInput == nil, true, "never takes the keyboard")
for _, f in ipairs(frames) do
    if f.calls.EnableKeyboard or f.calls.SetPropagateKeyboardInput then error("a frame took the keyboard") end
end
equal(UISpecialFrames[1], "EraUIMiniGames", "Escape closes it through the game's own list of windows")
equal(shell.content.w .. "x" .. shell.content.h .. " " .. shell.footer.w .. "x" .. shell.footer.h, "412x500 412x32", "content and footer sized")
equal(Whack().holder.sizedFirst and Whack().bar.sizedFirst, true, "the game's holder and footer strip sized first too")
equal(Whack().bar.w .. "x" .. Whack().bar.h .. " " .. Whack().bar.lastPoint[1] .. " " .. tostring(Whack().bar.lastPoint[2] == shell.footer),
    "256x32 TOPRIGHT true", "its footer strip: the footer's right, the Switch button's room on its left")
equal(shell.fx.sizedFirst and shell.edge.sizedFirst and shell.fx.w .. "x" .. shell.fx.h, "412x500", "the effects layer and the play area's edge sized first")
equal(shell.content.lastPoint[4] .. " " .. shell.content.lastPoint[5], "14 -70", "the play area under the header")
equal(shell.close.fromPresets, true, "the close X is EraUI's own (as on the Presets window)")
equal(shell:GetScript("OnUpdate") ~= nil, true, "it runs its every-frame update only while shown")
equal(Listening("PLAYER_REGEN_DISABLED") and Listening("PLAYER_REGEN_ENABLED"), true, "fights heard once a game was opened")
equal(Listening("PLAYER_CONTROL_LOST"), false, "flights still not, with the choice off")
equal(shell.title.text, "Whack-a-|cffc79c6eGnome|r", "the header: Whack-a-Gnome, Gnome in your class colour")
equal(shell.where.text, "Whack the gnome before it ducks.", "on the ground: how to play")
equal(shell.score.text .. " | " .. shell.best.text, "Score 0 | Best 0", "score and best score (the account's the same: said once)")
equal(shell.where.w, MG.WIDTH - 62 - 46 - 10 - 6 * #shell.best.text - (6 * #shell.coins.text + 3 + 14 + 10), "the where line takes the room the Best line and the coin purse leave")
equal(shell.where.wrap, false, "cut short, never wrapping under it")
equal(shell.note.text, "Next: The shop at stage 2.", "/era whack opens the stage map; the footer says what comes next")
equal(Whack().map:IsShown() and not Whack().root.shown and Whack().button.label.text .. " | " .. Whack().shopButton.label.text
    .. " " .. tostring(Whack().shopButton.shown) .. " " .. tostring(Whack().mapButton.shown), "Quick round | Shop true false",
    "the map over the field, its buttons Quick round and Shop")
local face = Whack().holes[1].face
equal(face.texture .. " " .. tostring(face.mask ~= nil) .. " " .. face.mask.texture, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Gnome true "
    .. "Interface\\CharacterFrame\\TempPortraitAlphaMask", "no 3D models in this client: the gnome's portrait, cut round")
equal(Whack().holes[1].model == nil and face.shown, true, "and no model")
equal(Whack().holes[1].body.shown, false, "no head up before Start")
equal(#Whack().holes, 9, "nine holes")
shell.close:Click()
equal(Showing(), false, "its X closes it")
equal(shell:GetScript("OnUpdate"), nil, "no every-frame update while closed")
MG:Toggle("whack")
equal(Showing(), true, "/era whack opens it again")
MG:Toggle("whack")
equal(Showing(), false, "and closes it when it shows")

Session({faction = "Alliance"})
MG:Open("whack", "command")
equal(Shell().title.text, "Whack-a-|cffc79c6ePeon|r", "an Alliance player gets Whack-a-Peon")
equal(Whack().holes[5].face.texture, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc", "with the orc's portrait")
equal(Shell().where.text, "Whack the peon before it ducks.", "and peon in the words")
equal(MG:Title("whack"), "Whack-a-Peon", "its name for /era")

-- The art falls back when the client refuses a file.
Session({missing = {["Interface\\CharacterFrame\\TemporaryPortrait-Male-Gnome"] = true}})
MG:Open("whack", "command")
face = Whack().holes[1].face
equal(tostring(face.atlas) .. " " .. Whack().holes[1].art, "raceicon128-gnome-male atlas", "no portrait: the gnome race icon")
Session({missing = {["Interface\\CharacterFrame\\TemporaryPortrait-Male-Gnome"] = true, ["raceicon128-gnome-male"] = true}})
MG:Open("whack", "command")
face = Whack().holes[1].face
equal(face.texture .. " " .. Whack().holes[1].art .. " " .. table.concat(face.coords, ","), "Interface\\Icons\\INV_Misc_Head_Gnome_01 icon 0.08,0.92,0.08,0.92",
    "no race icon either: the gnome head's icon, its border cropped")

-- The window's look ----------------------------------------------------------------------

Session()
MG:Open("whack", "command")
do
    local s = Shell()
    equal(s.stone.texture .. " " .. s.stone.wrapH .. " " .. tostring(s.stone.shown), "Interface\\Garrison\\ClassHallBackground REPEAT true",
        "a dark stone tiled under the whole window")
    equal(s.stone.alpha < 1 and s.backdropColour[1] < .05, true, "faint, over EraUI's dark fill")
    equal(s.rock.texture .. " " .. s.floor.layer, "Interface\\FrameGeneral\\UI-Background-Rock BACKGROUND", "dark rock on the play area's floor")
    equal(s.icon.texture .. " " .. tostring(s.icon.shown), "Interface\\Icons\\INV_Hammer_15 true", "Whack's icon in the header: a wooden mallet")
    equal(s.glow.texture .. " " .. s.glow.blend .. " " .. table.concat(s.glow.vertex, ",", 1, 3), "Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64 ADD 0.78,0.61,0.43",
        "a soft glow of your class colour behind it")
    local coords = s.glow.coords
    equal(coords[1] > 0 and coords[2] == 1 and coords[3] > 0 and coords[4] == 1 and s.glow.w + 1 <= MG.WIDTH, true, "cut at the window's edges, never past them")
    equal(table.concat(s.stripe.colour, ",", 1, 3) .. " " .. table.concat(s.score.textColour, ",", 1, 3), "0.78,0.61,0.43 1,0.86,0.5",
        "the class-colour stripe kept; the score in gold")
    local pieces = s.edge.pieces
    equal(#pieces .. " " .. pieces[1].texture .. " " .. pieces[3].texture .. " " .. tostring(s.edge.lines), "8 Interface\\Garrison\\HordeBfAMissionFrame "
        .. "Interface\\Garrison\\HordeBfAMissionFrame2 nil", "the play area framed in the Horde's bronze")
    local tl, tr, bl, br = pieces[5].coords, pieces[6].coords, pieces[7].coords, pieces[8].coords
    equal(tl[1] < tl[2] and tr[1] > tr[2] and bl[3] > bl[4] and br[1] > br[2] and br[3] > br[4], true, "one corner, mirrored to the other three")
    equal(pieces[5].w .. "x" .. pieces[5].h .. " " .. pieces[1].h .. " " .. pieces[1].w, "50x50 9 324", "at 0.3 of its size, edges between the corners")
    equal(s.edge.level > Whack().holes[1].over.level and s.fx.level > s.edge.level and s.edge.mouse == nil and s.fx.mouse == nil, true,
        "the edge over the game's frames, the effects over both, neither taking clicks")
    equal(s.note.lastPoint[1] .. " " .. s.note.lastPoint[5] .. " " .. s.note.justify .. " " .. tostring(s.note.wrap), "CENTER -591 CENTER true",
        "the note on its own line between the play area and the footer")
    equal(s.switch.shown, false, "no Switch button with one game")
    -- EraUI's buttons: lighter on hover, pressed in on a click.
    local button = Whack().button
    local plain = button.backdropColour[1]
    button:Fire("OnEnter")
    equal(button.backdropColour[1] > plain and button.borderColour[4], 1, "hover: lighter, its edge full")
    button:Fire("OnMouseDown")
    equal(button.label.lastPoint[4] .. " " .. button.label.lastPoint[5] .. " " .. tostring(button.backdropColour[1] < plain), "1 -1 true",
        "pressed: darker, its word in a pixel")
    button:Fire("OnMouseUp")
    equal(button.label.lastPoint[4] .. " " .. button.label.lastPoint[5], "0 0", "let go: back")
    button:Fire("OnLeave")
    equal(button.backdropColour[1], plain, "and plain again")
    equal(("%g,%g,%g,%g"):format(unpack(button.sheen.colour)), "1,1,1,0.6", "no gradients in this client: a flat sheen")
end
Session({faction = "Alliance"})
MG:Open("whack", "command")
equal(Shell().edge.pieces[5].texture .. " " .. table.concat(Shell().metal, ","), "Interface\\Garrison\\AllianceBfAMissionFrame 0.86,0.68,0.27",
    "an Alliance player's play area: the gold frame")
Session({missing = {["Interface\\Garrison\\HordeBfAMissionFrame"] = true, ["Interface\\Garrison\\ClassHallBackground"] = true}})
MG:Open("whack", "command")
do
    local s = Shell()
    local hidden = true
    for _, piece in ipairs(s.edge.pieces) do if piece.shown then hidden = false end end
    equal(hidden and #s.edge.lines .. " " .. table.concat(s.edge.lines[1].colour, ",", 1, 3), "4 0.66,0.48,0.28", "the frame's art refused: plain bronze lines")
    equal(s.stone.shown, false, "the stone refused: EraUI's dark fill alone")
end
Session({gradients = true})
MG:Open("whack", "command")
do
    local sheen = Whack().button.sheen
    equal(sheen.gradient[1] .. " " .. sheen.gradient[2].a .. " " .. sheen.gradient[3].a, "VERTICAL 0.2 1", "with gradients: the sheen fades down the button")
end

-- Whack's field -----------------------------------------------------------------------------

Session()
MG:Open("whack", "command")
OnField()
do
    local game, V = Whack(), W.VIEW
    local holder, ground = game.holder, game.ground
    equal(ground.texture .. " " .. ground.wrapH .. " " .. ground.wrapV .. " " .. ground.w .. "x" .. ground.h, "187126 REPEAT REPEAT 412x500",
        "the Horde whacks gnomes on a grassy field (Elwynn's grass), tiled over the whole field")
    near(ground.coords[2], 412 / V.TILE, "tiled at its own size, not stretched")
    equal(game.root.shown and not game.map:IsShown() and game.root.parent == holder, true, "the field in its own frame, the map hidden")
    equal(ground.vertex[1] + ground.vertex[2] + ground.vertex[3] < 2.8, true, "shaded a little, so light added over it still shows")
    equal(tostring(holder.clips) .. " " .. tostring(game.mallet.clips), "nil true", "the mallet cut at the field's edges; no model ever in a clipping frame")
    -- Every frame that clips is pinned by two opposite corners (Forever may draw nothing of one placed by one).
    local pinned, clipping = true, 0
    for _, f in ipairs(frames) do
        if f.clips then
            clipping = clipping + 1
            local at = {}
            for _, p in ipairs(f.points) do at[p[1]] = true end
            if not (at.ALL or (at.TOPLEFT and at.BOTTOMRIGHT) or (at.TOPRIGHT and at.BOTTOMLEFT)) then pinned = false end
        end
    end
    equal(clipping > 0 and pinned, true, "every clipping frame pinned by two corners")
    local corner = game.mallet.points[2]
    equal(corner[1] .. " " .. tostring(corner[2] == holder) .. " " .. corner[3] .. " " .. corner[4] .. " " .. corner[5], "BOTTOMRIGHT true TOPLEFT 412 -500",
        "the mallet's: the field's whole size, as it's sized")
    equal(game.field.level == holder.level + 1 and game.field.clicks[1], "LeftButtonDown", "a button under the holes hears a click that lands on none")
    -- Rows layered from the back: all of a front row over the row behind it.
    local layered = true
    for index = 1, 9 do
        local hole = game.holes[index]
        if not (hole.body.level == hole.level + 1 and hole.cover.level == hole.level + 3 and hole.over.level == hole.level + 4) then layered = false end
        if index <= 6 and game.holes[index + 3].level <= hole.over.level then layered = false end
        if hole.body.mouse or hole.cover.mouse or hole.over.mouse then layered = false end
    end
    equal(layered, true, "each hole: its mound, the target, the cover, its stars, none taking clicks; rows in front over rows behind")
    local hole = game.holes[5]
    local g = hole.g
    equal(hole.mound.texture .. " " .. hole.lip.texture .. " " .. hole.wall.texture .. " "
        .. tostring(hole.mound.mask ~= nil and hole.lip.mask ~= nil and hole.wall.mask ~= nil and hole.depth.mask ~= nil),
        "188581 188581 332326 true", "an earth mound and lip round a dark hole, each cut oval")
    equal(hole.mound.wrapH .. " " .. hole.lip.vertex[1], "REPEAT 1", "the lip lighter than the mound")
    -- The cover matches what's behind it: the same tile laid at the same spot.
    local cover = hole.cover
    local piece = cover.pieces[#cover.pieces]
    local x, y = piece.lastPoint[4], -piece.lastPoint[5]
    equal(piece.texture, 187126, "the cover is the field's own grass")
    equal(tostring(piece.snap) .. " " .. piece.snapBias .. " " .. tostring(ground.snap) .. " " .. tostring(cover.moundMask.snap) .. " " .. tostring(hole.mound.snap),
        "false 0 false false false", "the ground and its masks never snapped to the screen's pixels, so the cover meets the field exactly")
    near(piece.coords[1], x / V.TILE, "laid where it is, so it lines up with the field")
    near(piece.coords[3], y / V.TILE, "both ways")
    near(y, g.bottom, "from the hole's near edge")
    near(piece.h, math.min(g.bh * V.BOSS + 2, V.H - g.bottom), "down as far as a boss sinks, never past the field")
    near(piece.w, 2 * g.c, "as wide as a boss")
    local front = game.holes[8].cover.pieces[#game.holes[8].cover.pieces]
    near(-front.lastPoint[5] + front.h, V.H, "the front row's cover stops at the field's bottom")
    local masked = 0
    for _, child in ipairs(cover.children) do
        if child.kind == "Texture" and child.sublevel == 2 and child.mask == cover.moundMask then masked = masked + 1 end
    end
    equal(masked, #cover.pieces, "the mound over each piece, cut by the mound's own oval")
    -- The steps along the near edge follow it to within a pixel both ways:
    -- never more than that over the hole, nor more than that of the ground
    -- below it left open (every hole).
    local worst = 0
    for _, each in ipairs(game.holes) do
        local eg, pieces = each.g, each.cover.pieces
        local a, b = eg.hw / 2, eg.hh / 2
        for index = 1, #pieces - 1 do
            local p = pieces[index]
            local left, top = p.lastPoint[4], -p.lastPoint[5]
            local right, bottom = left + p.w, top + p.h
            -- The step's inner side, from the hole's middle, and the near edge there (down from the middle).
            local d = right <= eg.cx + 1e-6 and eg.cx - right or left >= eg.cx - 1e-6 and left - eg.cx or 0
            local edge = d < a and b * math.sqrt(1 - (d / a) ^ 2) or 0
            worst = math.max(worst, edge - (top - eg.cy), (bottom - eg.cy) - edge)
            if top < eg.cy - 1e-6 then worst = math.huge end
        end
    end
    equal(worst < 1 and #cover.pieces, 2 * V.BANDS + 1, "steps along the near edge, within a pixel of it both ways ("
        .. ("%.2f"):format(worst) .. " px at worst)")
    equal(hole.shade.mask == cover.moundMask and hole.shade.layer, "ARTWORK", "the mound's front shaded, over the target's foot in the hole")
    -- The edges in shadow over every row; the timer and the mallet over them.
    equal(#game.edges.sides .. " " .. tostring(game.edges.level > game.holes[9].over.level), "4 true", "the field's edges in shadow over the rows")
    local timer = game.timer
    equal(timer.fill.w .. " " .. timer.label.text .. " " .. tostring(timer.frame.level > game.edges.level), "300 30 true", "a full timer, 30 seconds")
    equal(timer.spark.blend .. " " .. tostring(timer.spark.shown), "ADD false", "its spark hidden while it's full")
    local mallet = game.mallet
    equal(#mallet.parts .. " " .. mallet.parts[1].texture .. " " .. tostring(mallet.shown), "8 Interface\\CharacterFrame\\TempPortraitAlphaMask false",
        "a mallet of eight ovals, hidden until wanted")
    equal(mallet.level > timer.frame.level and mallet.level < Shell().edge.level and mallet.mouse == nil, true, "over the field, under the frame, no clicks")
    -- Between rounds one peeks out of the middle hole.
    local peek = game.holes[5]
    local pg = peek.g
    local highest = pg.bottom
    for _ = 1, 30 do
        Tick(.01)
        highest = math.min(highest, -peek.body.lastPoint[5])
    end
    equal(game.holes[5].body.shown and game.holes[5].up .. " " .. tostring(game.holes[1].body.shown), "0.6 false", "between rounds one peeks out of the middle hole")
    near(-peek.body.lastPoint[5], pg.bottom - pg.bh * V.SHOWN * V.PEEK, "its face out, not all the way")
    local over = (pg.bottom - highest) / (pg.bh * V.SHOWN)
    equal(over > V.PEEK and over < V.PEEK * 1.1, true, "rising a touch past it, then settling (" .. ("%.3f"):format(over) .. ")")
    -- Start: it ducks smoothly, never lifting first.
    local lowest, steady = -peek.body.lastPoint[5], true
    game.button:Click()
    for _ = 1, 10 do
        Tick(.02)
        local y = -peek.body.lastPoint[5]
        if y < lowest - 1e-9 then steady = false end
        lowest = y
    end
    equal(steady and lowest, pg.bottom, "Start: the peek goes back down without lifting first")
end
Session({faction = "Alliance"})
MG:Open("whack", "command")
equal(Whack().ground.texture .. " " .. Whack().holes[1].mound.texture .. " " .. Whack().holes[1].cover.pieces[1].texture, "332329 187017 332329",
    "the Alliance whacks peons on Durotar's dry grass, red dirt mounds")
Session({missing = {[187126] = true, [188581] = true}})
MG:Open("whack", "command")
equal(table.concat(Whack().ground.colour, ",") .. " " .. Whack().holes[1].mound.texture, "0.26,0.34,0.1,1 188579",
    "the grass and its stand-in refused: a flat green; the mound's stand-in earth")
Session({missing = {[187126] = true}})
MG:Open("whack", "command")
equal(Whack().ground.texture .. " " .. Whack().holes[1].cover.pieces[1].texture, "188581 188581", "the stand-in tile, the cover the same")

-- Whack's 3D targets --------------------------------------------------------------------------

Session({models = true, random = Cycle()})
MG:Open("whack", "command")
OnField()
do
    local game = Whack()
    local hole = game.holes[1]
    local model = hole.model
    equal(model ~= nil and model.kind .. " " .. model.display .. " " .. tostring(model.keep) .. " " .. model.zoom .. " " .. model.camera,
        "PlayerModel 6973 true 0.55 1", "with 3D models: the Gnomeregan Evacuee, kept loaded while hidden, framed head and shoulders")
    model.zoom, model.camera = 0, 3
    model:Fire("OnModelLoaded")
    equal(model.zoom .. " " .. model.camera, "0.55 1", "framed again when its model loads (a load resets the camera)")
    equal(("%gx%g"):format(model.w, model.h) .. " " .. tostring(model.parent == hole.body) .. " " .. tostring(hole.face.shown) .. " " .. tostring(model.mouse),
        ("%gx%g"):format(hole.g.bw, hole.g.bh) .. " true false false", "in the target's frame, no portrait, no clicks")
    equal(model.level == hole.body.level + 1 and model.level < hole.cover.level, true, "over its frame, under the cover in front of it")
    equal(model.rotation .. " " .. game.holes[2].model.rotation .. " " .. game.holes[3].model.rotation .. " " .. tostring(model.animateTurn),
        "0.38 0 -0.38 false", "the outer columns turned a little to the middle, at once")
    Tick(.3)
    equal(game.holes[5].model.anim, W.MODEL.idle, "the one peeking between rounds stands")
    game.button:Click()
    Tick(3)
    local index = UntilUp()
    local up = game.holes[index]
    equal(up.body.shown and up.model.anim, W.MODEL.pop[1], "a head comes up in its pose")
    up:Click("LeftButton")
    equal(up.model.anim, W.MODEL.hit, "bonked: it flinches")
    local before = #up.model.anims
    up.model:Fire("OnModelLoaded")
    equal(#up.model.anims == before + 1 and up.model.anim, W.MODEL.hit, "a model that loads late still takes its pose")
    for _ = 1, 4 do Bonk() end
    local last = game.holes[game.state.last]
    equal(game.state.streak .. " " .. last.model.anim, "5 " .. W.MODEL.crit, "the fifth in a row: the big flinch")
    W.Models(false)
    equal(tostring(last.model.shown) .. " " .. tostring(last.face.shown), "false true", "models off: the portraits instead")
    W.Models(true)
    equal(tostring(last.model.shown) .. " " .. tostring(last.face.shown), "true false", "and back")
    Tick(31)
    equal(game.state.phase .. " " .. game.holes[5].model.anim, "over " .. W.MODEL.laugh, "the round over, the one peeking laughs")
end
Session({models = true, faction = "Alliance"})
MG:Open("whack", "command")
equal(Whack().holes[9].model.display, 10038, "the Alliance's peon: the Lazy Peon")
Session({models = true, badModels = {[6973] = true}})
MG:Open("whack", "command")
equal(Whack().holes[1].model.display, 7028, "the first model refused: the second gnome")
Session({models = true, badModels = {[6973] = true, [7028] = true}})
MG:Open("whack", "command")
do
    local none = true
    for _, hole in ipairs(Whack().holes) do if hole.model or not hole.face.shown then none = false end end
    equal(none, true, "both refused: every hole shows the portrait")
end

-- The mallet follows the pointer -----------------------------------------------------------------

Session({cursor = true, random = Cycle()})
MG:Open("whack", "command")
OnField()
do
    local game = Whack()
    local holder, mallet = game.holder, game.mallet
    local cursorCalls = 0
    SetCursor = function() cursorCalls = cursorCalls + 1 end
    ResetCursor = SetCursor
    -- The striking face's middle (part 8) from where the pointer is, in px.
    local function FaceOff(px, py)
        local face = mallet.parts[8]
        local dx, dy = face.lastPoint[4] - px, -face.lastPoint[5] - py
        return math.sqrt(dx * dx + dy * dy)
    end
    holder.left, holder.top = 400, 700
    world.cursorX, world.cursorY = 500, 600
    Tick(.05)
    equal(mallet.shown, false, "the pointer off the field: no mallet")
    holder.mouseOver = true
    Tick(.05)
    local handle = mallet.parts[1]
    equal(mallet.shown, true, "over the field the mallet follows the pointer")
    near(handle.rotation, W.SWING.rest, "resting")
    equal(FaceOff(100, 100) < 2, true, "its striking face right on the pointer's tip (" .. ("%.2f"):format(FaceOff(100, 100)) .. " px), not above and right of it")
    local grip = mallet.parts[3]
    equal(grip.lastPoint[4] > 100 and -grip.lastPoint[5] > 100, true, "the handle running down and to the right of the pointer")
    local x = handle.lastPoint[4]
    world.cursorX = 520
    Tick(.05)
    near(handle.lastPoint[4] - x, 20, "and moves with it the same frame")
    equal(FaceOff(120, 100) < 2, true, "the face still on the tip")
    local moves = 0
    local set = handle.SetPoint
    handle.SetPoint = function(...) moves = moves + 1; return set(...) end
    Tick(.2)
    equal(moves, 0, "a still pointer moves nothing")
    handle.SetPoint = nil
    -- The swing: lifted, slammed back down past rest, settled; the face on the
    -- tip at rest and at the strike, never more than 30 px off it on the way.
    local S = W.SWING
    local furthest = 0
    for t = 0, S.up + S.slam + S.settle, .002 do
        local angle = W.SwingAngle(t)
        if angle then
            local fx, fy = W.PartAt(0, 0, angle, W.FACE[1], W.FACE[2])
            furthest = math.max(furthest, math.sqrt(fx * fx + fy * fy))
        end
    end
    equal(furthest > 15 and furthest <= 30, true, "mid-swing the face leaves the tip, up to 30 px (" .. ("%.1f"):format(furthest) .. ")")
    local strike = S.up + S.slam * (S.rest - S.raise) / (S.over - S.raise)
    near(W.SwingAngle(strike), S.rest, "the strike lands at the resting angle")
    local sx, sy = W.PartAt(0, 0, W.SwingAngle(strike), W.FACE[1], W.FACE[2])
    equal(math.sqrt(sx * sx + sy * sy) < 2, true, "so the face strikes right on the pointer")
    equal(W.SwingAngle(S.up + S.slam + S.settle + .01), nil, "and the swing is over in a fifth of a second")
    game.holes[5]:Click("LeftButton")
    Tick(.04)
    equal(handle.rotation < S.rest, true, "a click lifts it first")
    world.cursorX = 530
    Tick(.02)
    equal(math.floor(game.aimX + .5) .. " " .. math.floor(game.aimY + .5), "130 100", "the swing follows the pointer, no lag")
    Tick(.3)
    near(handle.rotation, S.rest, "then it rests again")
    equal(FaceOff(130, 100) < 2, true, "its face back on the tip")
    holder.mouseOver = false
    Tick(.05)
    equal(mallet.shown, false, "off the field it goes")
    world.scale = 2
    holder.mouseOver = true
    world.cursorX, world.cursorY = 1000, 1200
    Tick(.05)
    equal(math.floor(game.aimX + .5) .. " " .. math.floor(game.aimY + .5), "100 100", "the interface's scale counted")
    -- Skins colour every part; the frost and felfire ones glow.
    local wood = W.Skin("wood")
    equal(table.concat(mallet.parts[4].vertex, ",", 1, 3) .. " " .. tostring(mallet.glow.shown), table.concat(wood.head, ",") .. " false",
        "the wooden mallet by default, no glow")
    game:PaintMallet("frost")
    local frost, painted = W.Skin("frost"), true
    for index, part in ipairs(mallet.parts) do
        local want = frost[W.SKIN_PARTS[index]]
        if not (part.vertex[1] == want[1] and part.vertex[2] == want[2] and part.vertex[3] == want[3]) then painted = false end
    end
    equal(painted and mallet.glow.shown and mallet.glow.blend, "ADD", "the frost mallet: every part its colour, a soft glow on its head")
    game:PaintMallet("nothing")
    equal(game.skin, "wood", "an unknown skin: the wooden mallet")
    equal(cursorCalls, 0, "the game's own pointer is left alone (no SetCursor or ResetCursor)")
    SetCursor, ResetCursor = nil, nil
end

-- A round in the window ------------------------------------------------------------------

-- The sounds played since n were, in order.
local function Since(n) return table.concat(sounds, " ", n + 1) end
local function Floats()
    local out = {}
    for _, float in ipairs(MG.FX.floats) do out[#out + 1] = float.text.text end
    return table.concat(out, "|")
end
Session({random = Cycle()})
MG:Open("whack", "command")
Whack().button:Click()
equal(Whack().screen .. " " .. tostring(Whack().root.shown) .. " " .. tostring(Whack().map:IsShown()) .. " " .. Whack().mapButton.label.text
    .. " " .. tostring(Whack().mapButton.shown), "quick true false Map true", "Quick round on the map: the field, a Map button beside it")
equal(Whack().state.phase .. " " .. Whack().button.label.text, "countdown Pause", "Start counts down first; the button says Pause")
equal(MG.FX.banner.text.text .. " " .. sounds[#sounds], "3 856:SFX", "a big 3, with a soft click (no mining tink)")
Tick(1)
equal(MG.FX.banner.text.text .. " " .. sounds[#sounds], "2 856:SFX", "then 2")
Tick(1)
equal(MG.FX.banner.text.text, "1", "then 1")
local before = #sounds
Tick(1)
equal(Whack().state.phase .. " " .. MG.FX.banner.text.text, "playing Whack!", "then Whack! and the round plays")
do
    local c, t = Whack().colour, MG.FX.banner.text.textColour
    near(t[1], c[1] + (1 - c[1]) * .4, "Whack! in a lighter shade of your class colour")
    equal(t[2] > c[2] and t[3] > c[3], true, "so a dark one still reads")
end
equal(Since(before), "219930:SFX 5922:SFX", "a soft whoosh (no weapon swing) and the gnome's hello")
local hole = UntilUp()
Tick(.2)
local body, spot = Whack().holes[hole].body, Whack().holes[hole].g
equal(body.shown and -body.lastPoint[5] < spot.bottom - 20, true, "the head rises out of its hole")
near(-body.lastPoint[5], spot.top, "all the way up as far as the layout says")
local other = hole % 9 + 1
before = #sounds
Whack().holes[other]:Click("LeftButton")
equal(Whack().state.score .. " " .. Since(before) .. " " .. Whack().state.misses, "0 219930:SFX 1", "a click on an empty hole: no point, a whiff")
equal(MG.FX.sparks[1].texture .. " " .. MG.FX.sparks[1].blend, MG.ART.smokeToon .. " BLEND", "and a puff of dust")
equal(Whack().mallet.shown and Whack().mallet.parts[1].rotation, W.SWING.rest, "the mallet swings where you clicked")
before = #sounds
Whack().holes[hole]:Click("LeftButton")
equal(Whack().state.score, 1, "a click on the head: a point")
equal(Shell().score.text, "Score 1", "the header counts it")
equal(Floats(), "Bonk!", "Bonk!")
equal(Since(before):sub(1, 7), "722:SFX", "a squish (no mace on flesh)")
equal(MG.FX.pulses[1].texture .. " " .. MG.FX.sparks[#MG.FX.sparks].texture, MG.ART.starburst .. " " .. MG.ART.bursts, "a starburst and gold sparks")
do
    -- Knocked down: held a moment, then down, never lifting on the way.
    local y, steady = -body.lastPoint[5], true
    for _ = 1, 20 do
        Tick(.01)
        local now = -body.lastPoint[5]
        if now < y - 1e-9 or now < spot.top - 1e-9 then steady = false end
        y = now
    end
    equal(steady and y > spot.top + 5, true, "knocked down without lifting first")
end
equal(Whack().holes[hole].stars[1].shown, true, "it sees stars")
Tick(1)
equal(Floats() .. "|" .. tostring(Whack().holes[hole].stars[1].shown) .. " " .. tostring(Whack().holes[hole].body.shown), "|false false",
    "then the words and stars go, the head down")
equal(Whack().holes[hole].clicks[1], "LeftButtonDown", "a hole takes the press itself, so a quick click lands")
Bonk(); Bonk()
equal(Floats():find("3 in a row", 1, true) ~= nil, true, "three in a row says so")
before = #sounds
Bonk(); Bonk()
equal(Whack().state.score .. " " .. Whack().state.streak, "5 5", "five heads, five points, five in a row")
equal(Floats():find("On a roll!", 1, true) ~= nil, true, "the fifth in a row: On a roll!")
do
    local roll
    for _, float in ipairs(MG.FX.floats) do if float.text.text == "On a roll!" then roll = float end end
    near(roll.text.textColour[1], Whack().textColour[1], "in the lighter shade of your class colour too")
end
equal(Since(before):find("91242:SFX 206515:SFX", 1, true) ~= nil, true, "a boing and a rising chime")
Whack().field:Click("LeftButton")
equal(Whack().state.streak .. " " .. Whack().state.misses .. " " .. sounds[#sounds], "0 2 219930:SFX", "a click on the open field: a whiff, the streak gone")
local timer = Whack().timer
equal(timer.fill.w < 300 and timer.label.text, tostring(math.ceil(Whack().state.left)), "the timer runs down, its seconds on it")
equal(timer.spark.shown, true, "a spark at its end")
Tick(Whack().state.left - 4.5)
equal(timer.fill.colour[1] > .6 and timer.fill.colour[2] < .3, true, "red for the last five seconds")
before = #sounds
Tick(4.4)
local _, ticks = Since(before):gsub("856:SFX", "")
equal(ticks, 3, "a tick on each of the last three")
before = #sounds
Tick(.2)
equal(Whack().state.phase, "over", "after 30 seconds the round is over")
equal(Shell().note.text, "Time's up: 5 points, +1 coin. New account best!", "the footer gives the score, its coins (1 per 5 points) and the best")
equal(Shell().coins.text .. " " .. MG.Progress:Coins() .. " " .. tostring(EraUIDB.miniGameResume == nil or EraUIDB.miniGameResume.whack == nil),
    "1 1 true", "the coin in the header's purse; nothing left waiting for the next flight")
equal(MG.FX.banner.text.text .. " | " .. MG.FX.banner.sub.text, "New best! | 5 points, best streak 5", "a banner says so")
equal(Since(before):find("74438:SFX", 1, true) ~= nil, true, "a new record's fanfare")
before = #sounds
Tick(1)
equal(Since(before):find("2835:SFX", 1, true) ~= nil, true, "then the gnomes cheer")
equal(Whack().button.label.text, "Play Again", "the button says Play Again")
equal(EraUIClassicCharDB.miniGames.best.whack .. " " .. EraUIDB.miniGameBest.whack, "5 5", "kept as this character's best and the account's")
equal(Shell().best.text, "Best 5", "the header shows it (once: this character's and the account's)")
equal(saves > 0, true, "and they're saved")
equal(Whack().holes[5].body.shown, true, "one peeks out again")
Whack().button:Click()
equal(Whack().state.phase .. " " .. Shell().score.text .. " " .. Whack().timer.label.text, "countdown Score 0 30", "Play Again starts a new round at 0")
Bonk(); Bonk()
before = #sounds
Tick(35)
equal(Shell().note.text .. " | " .. MG.FX.banner.text.text, "Time's up: 2 points. | Time's up!", "a lower score is no best")
equal(Since(before):find("218231:SFX", 1, true) ~= nil and Since(before):find("74438", 1, true) == nil, true, "the plain fanfare")
equal(Since(before):find("888:SFX", 1, true), nil, "never the level-up sound (no one thinks they levelled)")
equal(EraUIClassicCharDB.miniGames.best.whack, 5, "the best stays")
-- The window closed just as a round ends: no word from the target after.
Whack().button:Click()
Tick(33.05)
before = #sounds
Shell().close:Click()
Tick(2)
equal(#sounds, before, "closed: no voice line follows")

-- Another character on the account.
local account = EraUIDB
Session({db = account, char = {}, random = Cycle()})
equal(Words(MG:Best("whack")), "0 5", "another character: its own best 0, the account's 5")
MG:Open("whack", "command")
equal(Shell().best.text .. " | " .. Shell().where.w, "Best 0, account 5 | " .. (MG.WIDTH - 62 - 46 - 10 - 6 * 17 - (6 * #Shell().coins.text + 3 + 14 + 10)),
    "the header shows both, the where line narrower to make room")
MG:Close("hand")
equal(Words(MG:Record("whack", 3)), "true false", "3 is its best but not the account's")
equal(Words(MG:Record("whack", 9)), "true true", "9 beats both")
equal(EraUIDB.miniGameBest.whack .. " " .. EraUIClassicCharDB.miniGames.best.whack, "9 9", "both kept")
equal(Words(MG:Record("whack", SECRET)) .. " " .. Words(MG:Record("whack", -4)), "false false false false",
    "a hidden or odd score is no score")
EraUIDB.miniGameBest = {whack = 2}
equal(select(2, MG:Best("whack")), 9, "the account's best is never under this character's")

-- Sounds off.
Session({db = {miniGameSounds = false}, random = Cycle()})
MG:Open("whack", "command")
Whack().button:Click()
Bonk()
equal(Whack().state.score .. " " .. #sounds, "1 0", "with Mini-game Sounds off, no sound at all")

-- Closed by hand mid-round: paused, and its clock stopped.
Session({random = Cycle()})
MG:Open("whack", "command")
Whack().button:Click()
Tick(5)
local at = Whack().state.elapsed
Shell().close:Click()
equal(Whack().state.phase, "paused", "closing the window pauses the round")
Tick(10)
near(Whack().state.elapsed, at, "no time passes while it's closed")
equal(EraUIDB.miniGameResume.whack.mode .. " " .. EraUIDB.miniGameResume.whack.elapsed, "quick " .. at, "and it's saved for the next flight")
MG:Open("whack", "command")
equal(Whack().screen .. " " .. Whack().button.label.text, "map Quick round", "/era whack again: the map")
Whack().button:Click()
equal(Whack().button.label.text .. " | " .. Shell().note.text, "Resume | Paused. Click Resume to carry on.", "Quick round: the round left, paused, Resume")
Whack().button:Click()
Tick(1)
near(Whack().state.elapsed, at + 1, "Resume carries on")
Whack().button:Click()
equal(Whack().state.phase .. " " .. Whack().button.label.text, "paused Resume", "the button pauses too")

-- The whole interface hidden (Alt+Z): paused, not closed by you.
Whack().button:Click()
UIParent:Hide()
equal(Whack().state.phase .. " " .. tostring(Shell():IsShown()), "paused true", "hiding the interface pauses it, the window still open")
UIParent:Show()
equal(Showing() and Shell():GetScript("OnUpdate") ~= nil, true, "and it's back with the interface")

-- Its place ---------------------------------------------------------------------------------

Session()
MG:Open("whack", "command")
equal(Shell().lastPoint[1] .. " " .. tostring(Shell().lastPoint[2] == UIParent), "CENTER true", "first time: near the middle")
Shell():Fire("OnDragStart")
equal(Shell().moving, true, "drag it")
Shell().left, Shell().top = 210.4, 700.2
Shell():Fire("OnDragStop")
equal(EraUIDB.miniGamePosition.x .. " " .. EraUIDB.miniGamePosition.y, "210 -300", "its top left corner kept, from the screen's")
equal(Shell().lastPoint[1] .. " " .. Shell().lastPoint[3] .. " " .. Shell().lastPoint[4] .. " " .. Shell().lastPoint[5], "TOPLEFT TOPLEFT 210 -300",
    "and pinned there")
equal(Shell().userPlaced, false, "the game's own layout cache never keeps it")
local place = EraUIDB
Session({db = place})
MG:Open("whack", "command")
equal(Shell().lastPoint[1] .. " " .. Shell().lastPoint[4] .. " " .. Shell().lastPoint[5], "TOPLEFT 210 -300", "the next session it opens there")
world.combat = true
Shell():Fire("OnDragStart")
equal(Shell().moving, nil, "never dragged in a fight")
world.combat = false

-- Flights ------------------------------------------------------------------------------------

Session({db = {miniGameFlight = "whack"}})
equal(Listening("PLAYER_CONTROL_LOST") and Listening("PLAYER_CONTROL_GAINED") and Listening("PLAYER_ENTERING_WORLD"), true,
    "On a Flight Path set: taking off and landing are heard")
equal(Listening("PLAYER_REGEN_DISABLED"), true, "and fights")
equal(#hooks .. " " .. hooks[1], "1 TakeTaxiNode", "one post-hook, on the flight map's TakeTaxiNode")
equal(Shell(), nil, "nothing opens on the ground")
TakeOff(3)
equal(Showing() and MG.current, "whack", "taking off opens Whack")
equal(world.took, 3, "the flight map's own pick still goes through")
equal(Shell().where.text, "Flying to Orgrimmar, Durotar", "the header says where you're flying")
equal(MG.Card.Shown("whack") and MG.Card.Frame("whack").title.text .. " | " .. Whack().screen .. " " .. Whack().button.label.text,
    "Stage 1 | stage Start", "a first flight: stage 1's intro card over the field, Start")
Whack().button:Click()
equal(tostring(MG.Card.Shown("whack")) .. " " .. Whack().state.phase .. " " .. Whack().state.mode, "false countdown stage", "Start plays stage 1")
Bonk(); Bonk(); Bonk()
Land()
equal(Showing(), false, "landing closes it")
do
    local kept = EraUIDB.miniGameResume and EraUIDB.miniGameResume.whack
    equal(Whack().state.phase .. " " .. Whack().state.score .. " | " .. kept.mode .. " " .. kept.stage .. " " .. kept.score, "paused 3 | stage 1 3",
        "landing no longer ends the round: it waits, paused and saved, for the next flight")
end
equal(MG.flight.on or MG.flight.opened, false, "the flight is over")
MG:Open("whack", "command")
equal(Shell().note.text .. " | " .. Shell().where.text, "You landed. Your round waits for your next flight. | Whack the gnome before it ducks.",
    "opened again on the ground: the map, and your round waiting")
equal(Whack().map.nodes[1].carry.shown, true, "Carry on under its stage")
MG:Close("hand")

-- No pick (or an old one): just "On a flight".
TakeTaxiNode(5); Tick(20)
TakeOff()
equal(Showing() and Shell().where.text, "On a flight", "a pick from 20 s ago isn't where you're flying")
Land()
TakeOff()
equal(Shell().where.text, "On a flight", "no pick at all: On a flight")
Land()

-- The flight flag comes a moment after control goes.
Fire("PLAYER_CONTROL_LOST")
equal(Showing(), false, "control gone, not on a flight yet: nothing")
world.taxi = true
Tick(.5)
equal(Showing(), true, "on a flight half a second later: it opens")
Land()
-- A stun, never a flight.
Fire("PLAYER_CONTROL_LOST"); Tick(4)
equal(Showing(), false, "control lost to a stun: nothing")
Fire("PLAYER_CONTROL_GAINED")

-- A landing the events missed: the open window notices within a second.
TakeOff()
world.taxi = false
Tick(1.1)
equal(Showing() or MG.flight.on, false, "landed without the event: closed within a second")

-- Closed by hand: closed for the rest of that flight.
TakeOff()
Shell().close:Click()
equal(MG.flight.closedByHand, true, "closed by hand during the flight")
world.combat = true; Fire("PLAYER_REGEN_DISABLED")
world.combat = false; Fire("PLAYER_REGEN_ENABLED")
equal(Showing(), false, "a fight's end doesn't bring it back")
Fire("PLAYER_CONTROL_LOST"); Tick(4)
equal(Showing(), false, "nor losing control again on the same flight")
Land()
TakeOff()
equal(Showing(), true, "the next flight opens it again")
Land()
-- Escape (the game's list of windows hides it) counts as by hand.
TakeOff()
Shell():Hide()
equal(MG.flight.closedByHand, true, "Escape closes it by hand too")
Land()
-- Closed by hand, then control back a moment before the flight flag goes:
-- the shut window can't look, so the landing is looked for again.
TakeOff()
Shell().close:Click()
Fire("PLAYER_CONTROL_GAINED")
equal(MG.flight.on, true, "control back, the flight flag not gone yet: still flying")
world.taxi = false
Tick(2)
equal(MG.flight.on or MG.flight.closedByHand, false, "closed by hand, the flag going a moment after control: landed all the same")
TakeOff()
equal(Showing() and MG.flight.on and Shell().where.text, "On a flight", "so the next flight opens it")
Land()
-- The same with a fight hiding it.
TakeOff()
world.combat = true; Fire("PLAYER_REGEN_DISABLED")
Fire("PLAYER_CONTROL_GAINED")
world.taxi = false
Tick(2)
equal(MG.flight.on, false, "hidden by a fight, the flag going a moment after control: landed")
world.combat = false; Fire("PLAYER_REGEN_ENABLED")
equal(Showing(), false, "the fight over on the ground: nothing comes back")
TakeOff()
equal(Showing(), true, "and the next flight opens it")
Land()

-- Fights ------------------------------------------------------------------------------------

TakeOff()
Whack().button:Click()
Tick(4.5)
at = Whack().state.elapsed
world.combat = true; Fire("PLAYER_REGEN_DISABLED")
equal(Showing() or Whack().state.phase, "paused", "a fight hides it and pauses the round")
Tick(3)
near(Whack().state.elapsed, at, "the round waits")
equal(MG:Open("whack", "command"), false, "it can't be opened in a fight")
equal(Last(), "Mini-games open once the fight is over.", "and says so")
equal(MG.flight.closedByHand, false, "a fight isn't closing it by hand")
world.combat = false; Fire("PLAYER_REGEN_ENABLED")
equal(Showing() and Whack().button.label.text, "Resume", "the fight over, still flying: back, paused")
world.combat = true; Fire("PLAYER_REGEN_DISABLED")
Land()
world.combat = false; Fire("PLAYER_REGEN_ENABLED")
equal(Showing(), false, "a fight that ends after landing brings nothing back")

-- Taking off in a fight: it opens once the fight is over, if still flying.
world.combat = true; Fire("PLAYER_REGEN_DISABLED")
TakeOff()
equal(Showing(), false, "never opens in a fight")
world.combat = false; Fire("PLAYER_REGEN_ENABLED")
equal(Showing(), true, "the fight over, still flying: it opens")
Land()
world.combat = true; Fire("PLAYER_REGEN_DISABLED")
TakeOff()
Land()
world.combat = false; Fire("PLAYER_REGEN_ENABLED")
equal(Showing(), false, "landed before the fight ended: nothing")

-- Opened on the ground, then a flight: the flight's game from then on.
MG:Open("whack", "command")
TakeOff()
equal(Showing() and MG.flight.opened, true, "still open as you take off, now the flight's")
Land()
equal(Showing(), false, "so landing closes it")

-- Choosing Off: the flight events go.
TakeOff()
EraUIDB.miniGameFlight = "off"; MG:Refresh()
equal(Showing() and tostring(MG.flight.on) .. " " .. Shell().where.text, "false Stage 1",
    "set to Off mid-flight: the game stays open (on the stage carried on), the flight no longer followed")
Land(); Tick(2)
equal(Showing(), true, "so landing leaves it open")
MG:Close("hand")
equal(Listening("PLAYER_CONTROL_LOST") or Listening("PLAYER_CONTROL_GAINED") or Listening("PLAYER_ENTERING_WORLD"), false,
    "set back to Off: no flight event heard")
TakeOff(); Tick(4)
equal(Showing(), false, "and taking off opens nothing")
Land()
MG:Open("whack", "command")
TakeOff(); Tick(2); Land(); Tick(2)
equal(Showing(), true, "with Off, a game you opened on the ground stays open through a flight")
MG:Close("hand")

-- Chosen in /era during a flight: nothing opens until the next one.
world.taxi = true
EraUIDB.miniGameFlight = "whack"; MG:Refresh()
equal(#hooks .. " " .. tostring(Showing()), "1 false", "chosen mid-flight: nothing opens now, still one hook")
Land()
TakeOff()
equal(Showing(), true, "the next flight opens it")
Land()

-- A /reload (or logging in) on a flight: open once the loading screen is over.
local reload = EraUIDB
Session({db = reload, taxi = true})
equal(Showing() and Shell().where.text, "On a flight", "a /reload on a flight opens it again")
Land()
equal(Showing(), false, "and landing closes it")

-- A choice whose game isn't there opens nothing and says nothing on a flight.
Session({db = {miniGameFlight = "blast"}})
local blast = MG.games.blast
MG.games.blast = nil
TakeOff(); Tick(4)
equal(Showing() == false and #printed, 0, "a game not plugged in yet: nothing opens on a flight, nothing said")
Land()
equal(MG:Open("blast", "command"), false, "asked for by hand")
equal(Last(), "Azeroth Blast is not ready yet.", "it says so")
MG.games.blast = blast

-- A hidden flight flag counts as not flying.
Session({db = {miniGameFlight = "whack"}})
world.taxi = SECRET
Fire("PLAYER_CONTROL_LOST"); Tick(4)
equal(Showing(), false, "a hidden answer: not on a flight")

-- A game that breaks closes the window with one line in chat.
Session()
local broken = MG:Register("broken", {Title = function() return "Broken ", "Game" end, Build = function() end,
    Update = function() error("boom") end})
equal(MG:Open("broken", "command"), true, "a game that will break opens")
Tick(.1)
equal(Showing(), false, "its error closes the window")
equal(#printed == 1 and printed[1]:find("A mini-game hit an error and was closed", 1, true) ~= nil, true, "said once in chat")
MG:Open("broken", "command"); Tick(.1)
equal(#printed, 1, "never twice")
equal(broken.id, "broken", "registering names the game")

-- A game whose Build fails never takes the window: the one showing closes
-- (its game paused, still the current one), and it's never built again.
Session({blast = true, random = Cycle()})
MG.games.blast.Build = function() error("no board") end
MG:Open("whack", "command")
Whack().button:Click()
Tick(4.5)
printed = {}
equal(Shell().switch.label.text, "Azeroth Blast", "a Switch to the game that will fail")
Shell().switch:Click()
equal(tostring(Showing()) .. " " .. MG.current .. " " .. Whack().state.phase, "false whack paused", "it fails: the window closes, Whack paused and still current")
equal(#printed == 1 and printed[1]:find("A mini-game hit an error and was closed", 1, true) ~= nil, true, "said once in chat")
do
    local made = #frames
    equal(MG:Open("blast", "command"), false, "asked for again: no")
    equal(#frames .. " | " .. tostring(Last()), made .. " | Azeroth Blast hit an error. Type /reload to try again.", "nothing built again, and it says to /reload")
end
MG:Open("whack", "command")
equal(tostring(Showing()) .. " " .. tostring(Shell().switch.shown) .. " " .. tostring(MG.games.blast.holder.shown), "true false false",
    "Whack opens as before, with no Switch to the broken game and none of its frames")

-- The Switch button (with Azeroth Blast loaded too) ------------------------------------------

Session({blast = true, random = Cycle()})
MG:Open("whack", "command")
do
    local s = Shell()
    local switch = s.switch
    equal(switch.shown and switch.label.text .. " | " .. switch.icon.texture, "Azeroth Blast | Interface\\Icons\\Spell_Nature_Polymorph",
        "the Switch button names Azeroth Blast, with its icon")
    equal(switch.parent == s.footer and switch.lastPoint[1] .. " " .. switch.w, "LEFT 148", "on the footer's left")
    Whack().button:Click()
    Tick(4.5)
    local at, spot, placed = Whack().state.elapsed, s.lastPoint, #s.points
    switch:Click()
    equal(MG.current .. " " .. Whack().state.phase, "blast paused", "Switch: Azeroth Blast shows, Whack's round paused")
    equal(Showing() and MG.games.blast.holder.shown and not Whack().holder.shown and not Whack().bar.shown and MG.games.blast.bar.shown, true,
        "in the same window, Whack's holes and button hidden")
    equal(#s.points .. " " .. tostring(s.lastPoint == spot), placed .. " true", "the window stays where it was")
    equal(s.title.text .. " | " .. s.icon.texture, "Azeroth |cffc79c6eBlast|r | Interface\\Icons\\Spell_Nature_Polymorph", "the header: Azeroth Blast and its icon")
    equal(switch.label.text .. " | " .. switch.icon.texture, "Whack-a-Gnome | Interface\\Icons\\INV_Hammer_15", "the button now names Whack-a-Gnome")
    equal(s.note.text, "Click a piece, then one next to it to swap.", "Azeroth Blast's own words")
    Tick(3)
    near(Whack().state.elapsed, at, "Whack's clock stopped meanwhile")
    switch:Click()
    equal(MG.current .. " " .. Whack().button.label.text .. " | " .. s.note.text, "whack Resume | Paused. Click Resume to carry on.",
        "and back: Whack, paused, Resume")
    equal(switch.label.text, "Azeroth Blast", "the button names Azeroth Blast again")
    equal(MG:OtherGame(), "blast", "the other game")
    MG:Close("hand")
    equal(MG:Switch(), false, "no switching a closed window")
end
Session({blast = true, faction = "Alliance", random = Cycle()})
MG:Open("blast", "command")
equal(Shell().switch.label.text, "Whack-a-Peon", "an Alliance player's button names Whack-a-Peon")
-- On a flight: switching keeps the flight's window; landing ends both games.
Session({blast = true, db = {miniGameFlight = "whack"}, random = Cycle()})
TakeOff(3)
Whack().button:Click()
Bonk(); Bonk()
Shell().switch:Click()
equal(MG.current .. " " .. tostring(Showing()) .. " | " .. Shell().where.text, "blast true | Flying to Orgrimmar, Durotar", "switched on a flight: still the flight's")
world.combat = true; Fire("PLAYER_REGEN_DISABLED")
equal(Showing(), false, "a fight hides it")
world.combat = false; Fire("PLAYER_REGEN_ENABLED")
equal(Showing() and MG.current, "blast", "and brings back the game you switched to")
Land()
equal(Showing(), false, "landing closes it")
equal(Whack().state.phase .. " " .. Whack().state.score .. " " .. EraUIDB.miniGameResume.whack.stage, "paused 2 1",
    "the round you switched away from waits too, saved for the next flight")
MG:Open("whack", "command")
equal(Shell().note.text, "You landed. Your round waits for your next flight.", "and says so the next time")

-- The effects kit ----------------------------------------------------------------------------

Session()
MG:Open("whack", "command")
OnField() -- off the map, whose glow pulses on the kit
do
    local fx, layer, hole = MG.FX, Shell().fx, Whack().holes[5]
    local animated, animate = 0, MG.Animate
    MG.Animate = function(...) animated = animated + 1; return animate(...) end
    Tick(.5)
    equal(animated, 0, "nothing running: the effects aren't moved at all")
    equal(MG:Burst(hole, {count = 12, colour = {1, .5, .2}, texture = MG.ART.bursts, coords = MG.QUARTER.red}), 12, "a burst: twelve sparks")
    local spark = fx.sparks[1]
    equal(spark.parent == layer and spark.layer == "OVERLAY" and spark.shown, true, "on the effects layer, over the game")
    equal(spark.texture .. " " .. table.concat(spark.coords, ",") .. " " .. spark.blend .. " " .. table.concat(spark.vertex, ",", 1, 3),
        "166970 0,0.5,0.5,1 ADD 1,0.5,0.2", "the texture, quarter and colour asked for, as light")
    equal(spark.lastPoint[2] == hole and spark.lastPoint[1], "CENTER", "from the hole's middle")
    equal(MG.fxBusy, true, "running")
    Tick(.2)
    local far = 0
    for _, each in ipairs(fx.sparks) do far = math.max(far, math.abs(each.lastPoint[4]) + math.abs(each.lastPoint[5])) end
    equal(far > 10 and animated > 0, true, "the sparks fly out")
    Tick(1)
    equal(#fx.sparks .. " " .. tostring(spark.shown) .. " " .. tostring(MG.fxBusy), "0 false false", "a moment later all gone, nothing left running")
    animated = 0
    Tick(.3)
    equal(animated, 0, "and the effects stop being moved")
    local made = #frames
    MG:Burst(nil, {count = 12, atlas = "OBJFX_StarBurst"})
    equal(#frames .. " " .. tostring(fx.sparks[1].lastPoint[2] == layer) .. " " .. tostring(fx.sparks[1].atlas), made .. " true OBJFX_StarBurst",
        "the next burst reuses them (nothing new made); no region: the play area's middle; an atlas")
    Tick(1)
    MG:Burst(hole, {count = 1, blend = "BLEND", texture = MG.ART.star})
    MG:Burst(hole, {count = 1, blend = "MOD"})
    equal(fx.sparks[1].blend .. " " .. fx.sparks[1].texture .. " " .. fx.sparks[2].blend, "BLEND 166955 ADD",
        "a plain texture when asked; any other mode is light added")
    Tick(1)
    equal(MG:Burst(hole, {count = 99}), 40, "at most 40 in one burst")
    for _ = 1, 5 do MG:Burst(hole, {count = 40}) end
    equal(#fx.sparks .. " " .. fx.made.spark, "160 160", "never more than 160 at once, nor made")
    equal(MG:Burst(hole), 0, "past that, none")
    Tick(1.5)
    equal(#fx.sparks .. " " .. #fx.free.spark, "0 160", "all back in the pool")
    -- A floating word.
    equal(MG:FloatText(hole, "+30", {colour = {.4, 1, .4}}), true, "a floating word")
    local float = fx.floats[1]
    equal(float.text.text .. " " .. float.text.font[3] .. " " .. float.scale .. " " .. table.concat(float.text.textColour, ",", 1, 3),
        "+30 OUTLINE 1.5 0.4,1,0.4", "outlined, in its colour, starting big")
    Tick(.2)
    equal(float.scale == 1 and float.lastPoint[5] > 0, true, "settled to its size and rising")
    Tick(1)
    equal(float.shown or #fx.floats, 0, "then gone")
    -- The banner.
    equal(MG:Banner("Unstoppable!", {sub = "A chain of 6"}), true, "a banner")
    local banner = fx.banner
    equal(banner.text.text .. " | " .. banner.sub.text .. " " .. banner.scale .. " " .. tostring(banner.level > layer.level),
        "Unstoppable! | A chain of 6 1.8 true", "its word and the line under it, starting big, over the rest")
    Tick(.25)
    equal(banner.scale .. " " .. banner.alpha, "1 1", "scaled in, fully there")
    Tick(1.3)
    equal(banner.shown, false, "then faded away")
    -- A shake.
    local content = Shell().content
    MG:Shake(6, .3)
    Tick(.1)
    equal(content.lastPoint[4] ~= 14 or content.lastPoint[5] ~= -70, true, "the play area shakes")
    Tick(.3)
    equal(content.lastPoint[4] .. " " .. content.lastPoint[5] .. " " .. tostring(fx.shake.on), "14 -70 false", "then rests where it was")
    -- A pulse.
    MG:Pulse(hole, {colour = {1, .8, .2}})
    local pulse = fx.pulses[1]
    local wide, tall = hole.w * 1.3, hole.h * 1.3
    equal(math.floor(pulse.w + .5) .. "x" .. math.floor(pulse.h + .5) .. " " .. pulse.texture .. " " .. pulse.layer,
        math.floor(wide + .5) .. "x" .. math.floor(tall + .5) .. " Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64 ARTWORK",
        "a soft glow 1.3 times the hole, under the sparks")
    Tick(.1)
    equal(pulse.alpha > 0 and pulse.w > wide + .5, true, "flashing and growing")
    Tick(.4)
    equal(pulse.shown, false, "then gone")
    -- A pop.
    local frame, popped = Whack().holes[2].over, nil
    MG:Pop(frame, {peak = 1.5, done = function(f, cleared) popped = {f, cleared} end})
    Tick(.05)
    equal(frame.scale > 1, true, "a pop: the frame grows")
    Tick(.4)
    equal(frame.scale .. " " .. tostring(popped[1] == frame) .. " " .. tostring(popped[2]), "1 true false", "then back to its size, and done")
    MG:Pop(frame, {to = 0, done = function(f, cleared) popped = {f, cleared, f.alpha} end})
    Tick(.2)
    equal(frame.alpha < 1 and frame.scale < 1, true, "a pop away: shrinking and fading")
    Tick(.2)
    equal(popped[3] .. " " .. frame.scale, "1 1", "it ends at its own size and alpha, for done to hide it")
    local first
    MG:Pop(frame, {done = function(_, cleared) first = cleared end})
    MG:Pop(frame, {})
    equal(tostring(first) .. " " .. #fx.pops, "true 1", "a second pop on a frame starts it again (the first one cleared)")
    Tick(.5)
    -- A tween.
    local shares, ended = {}, nil
    MG:Tween(.2, function(share, data) shares[#shares + 1] = share .. data end, function(data, cleared) ended = data .. " " .. tostring(cleared) end, "x")
    Tick(.3)
    equal(shares[1] ~= "1x" and shares[#shares] .. " | " .. ended, "1x | x false", "a tween steps up to 1, then ends")
    -- An effect started from a callback, once nothing else runs, still plays.
    MG:Tween(.1, nil, function() MG:Burst(hole, {count = 3}) end)
    Tick(.15)
    equal(#fx.tweens .. " " .. #fx.sparks .. " " .. tostring(MG.fxBusy), "0 3 true", "a burst from a tween's end still runs")
    Tick(1)
    equal(#fx.sparks .. " " .. tostring(MG.fxBusy), "0 false", "and ends")
    -- The header's score counts up.
    MG:SetScore(500)
    equal(Shell().score.text .. " " .. Shell().scoreGoal, "Score 0 500", "a rise counts up")
    Tick(.05)
    local mid = Shell().scoreShown
    equal(mid > 0 and mid < 500, true, "part way after a frame (" .. mid .. ")")
    Tick(1.5)
    equal(Shell().score.text .. " " .. tostring(MG.fxBusy), "Score 500 false", "there within a moment")
    MG:SetScore(501)
    equal(Shell().score.text, "Score 501", "one point: at once")
    MG:SetScore(3)
    equal(Shell().score.text, "Score 3", "a fall: at once")
    MG:SetScore(90, true)
    equal(Shell().score.text, "Score 90", "now: at once")
    -- Hiding clears everything.
    local poppedNow, tweened
    MG:SetScore(400)
    MG:Burst(hole, {count = 5}); MG:FloatText(hole, "Bonk!"); MG:Banner("Double!"); MG:Shake(); MG:Pulse(hole)
    MG:Pop(frame, {done = function(_, cleared) poppedNow = cleared end})
    MG:Tween(5, nil, function(_, cleared) tweened = cleared end)
    Tick(.1)
    Shell().close:Click()
    equal(#fx.sparks + #fx.floats + #fx.pulses + #fx.pops + #fx.tweens, 0, "closing the window clears every effect")
    equal(fx.banner.shown or fx.shake.on or MG.fxBusy, false, "the banner and the shake too")
    equal(content.lastPoint[4] .. " " .. content.lastPoint[5] .. " " .. frame.scale, "14 -70 1", "the play area still, the popped frame its own size")
    equal(tostring(poppedNow) .. " " .. tostring(tweened) .. " " .. Shell().score.text, "true true Score 400", "the pop and tween cleared, the score at its goal")
    equal(MG:Burst(hole) .. " " .. tostring(MG:Banner("x")) .. " " .. tostring(MG:FloatText(hole, "x")) .. " " .. tostring(MG:Shake()),
        "0 false false false", "nothing while it's hidden")
    local ran
    MG:Tween(1, nil, function(_, cleared) ran = cleared end)
    equal(ran, true, "a tween while hidden ends at once")
    MG:Open("whack", "command")
    UIParent:Hide()
    equal(MG:Burst(hole), 0, "nor while the whole interface is hidden")
    UIParent:Show()
    -- An effect's callback that breaks: said once, the window closed.
    printed = {}
    MG:Tween(.1, nil, function() error("fx boom") end)
    Tick(.2)
    equal(Showing(), false, "a broken callback closes the window")
    equal(#printed == 1 and printed[1]:find("A mini-game hit an error", 1, true) ~= nil, true, "said once in chat")
    MG.Animate = animate
end
-- Switching games clears the effects too.
Session({blast = true, random = Cycle()})
MG:Open("whack", "command")
OnField() -- off the map, whose glow pulses on the kit
MG:Burst(nil, {count = 6})
local _, drums = MG:Sound("drums")
Shell().switch:Click()
equal(#MG.FX.sparks .. " " .. tostring(world.stopped[1] == drums and MG.held.drums), "0 nil", "switching games clears the effects and stops the drums")
-- Switched away mid-move: what the move's end starts as it pauses is cleared too.
do
    local blast = MG.games.blast
    local a, b = MG.Blast.FindMove(blast.state.board)
    blast.cells[a]:Click("LeftButton")
    blast.cells[b]:Click("LeftButton")
    Tick(.05)
    equal(blast.busy and blast.state.score > 0 and Shell().scoreGoal < blast.state.score, true, "a move playing, its score not yet all shown")
    Shell().switch:Click()
    equal(tostring(blast.busy) .. " " .. #MG.FX.pulses .. " " .. tostring(MG.fxBusy) .. " " .. Shell().score.text, "false 0 false Score 0",
        "switched mid-move: the move ends, no score glow left on Whack's header, its score shown")
    local kept = blast.state.score
    Shell().switch:Click()
    equal(Shell().score.text, "Score " .. kept, "back on Azeroth Blast: its whole score")
end

-- Sounds ----------------------------------------------------------------------------------------

Session()
do
    local function Played() return sounds[#sounds] end
    equal(MG:Sound("chain", 1) and Played(), "206515:SFX", "a chain's first step")
    MG:Sound("chain", 4)
    equal(Played(), "208732:SFX", "its fourth")
    MG:Sound("chain", 9)
    equal(Played(), "31578:SFX", "past the end: the last")
    local seen = {}
    for _ = 1, 40 do MG:Sound("chain"); seen[Played()] = true end
    local kinds = 0
    for key in pairs(seen) do kinds = kinds + 1; assert(key:match("^%d+:SFX$")) end
    equal(kinds > 1, true, "no step: one of the list at random")
    MG:Sound("peonUp")
    equal(Played(), "7121:SFX", "a named kit (the peon's lines)")
    MG:Sound("heroism")
    equal(Played(), "file 569013:SFX", "Heroism: its sound file")
    PlaySoundFile = nil
    MG:Sound("heroism")
    equal(Played(), "3113:SFX", "no sound files: Battle Shout instead")
    local before = #sounds
    equal(MG:Sound("nothing") or #sounds, before, "an unknown name: nothing")
    -- Every sound is a whole SoundKit ID, a list of them, a file with a kit or
    -- a kit with a stand-in, and none of them a blacksmith or metal sound.
    local bad = {}
    local function Whole(id) return type(id) == "number" and id > 0 and id == math.floor(id) end
    local function Good(entry, depth)
        if depth > 4 then return false end
        if type(entry) == "number" then return Whole(entry) and not MG.FORBIDDEN_SOUNDS[entry] end
        if type(entry) ~= "table" then return false end
        if #entry > 0 then
            for _, each in ipairs(entry) do if not Good(each, depth + 1) then return false end end
            return true
        end
        if entry.file ~= nil and not Whole(entry.file) then return false end
        if entry.kit == nil and entry.file == nil then return false end
        if entry.kit ~= nil and not Good(entry.kit, depth + 1) then return false end
        return entry.alt == nil or Good(entry.alt, depth + 1)
    end
    for name, entry in pairs(MG.SOUNDS) do
        if not Good(entry, 0) then bad[#bad + 1] = name end
    end
    table.sort(bad)
    equal(table.concat(bad, ","), "", "every sound a whole ID, never a forbidden one")
    for _, id in ipairs({941, 942, 1143, 865, 1221, 1204, 233, 235, 237, 238}) do
        equal(MG.FORBIDDEN_SOUNDS[id], true, "forbidden: " .. id)
    end
    -- The first games' names now play the soft sounds.
    equal(MG.SOUNDS.bonk == MG.SOUNDS.squish and MG.SOUNDS.hit == MG.SOUNDS.squish and MG.SOUNDS.hitBig == MG.SOUNDS.boing
        and MG.SOUNDS.tink == MG.SOUNDS.uiClick and MG.SOUNDS.gems == MG.SOUNDS.uiClick and MG.SOUNDS.clink == MG.SOUNDS.chime
        and MG.SOUNDS.swing == MG.SOUNDS.whoosh and MG.SOUNDS.swap == MG.SOUNDS.whoosh and MG.SOUNDS.start == MG.SOUNDS.chime
        and MG.SOUNDS.coinBig == MG.SOUNDS.coins, true, "old names re-pointed")
    -- A forbidden ID set by hand still never plays.
    MG.SOUNDS.test = 941
    before = #sounds
    equal(MG:Sound("test") or #sounds, before, "a forbidden ID never plays")
    MG.SOUNDS.test = nil
    -- The drums run on: kept, stopped as the window hides.
    MG:Open("whack", "command")
    local _, handle = MG:Sound("drums")
    equal(Played() .. " " .. tostring(MG.held.drums == handle), "344561:SFX true", "the drums: kept to be stopped")
    MG:Sound("drums")
    equal(world.stopped[1], handle, "a second drum roll stops the first")
    Shell().close:Click()
    equal(world.stopped[2] ~= nil and MG.held.drums, nil, "closing the window stops them")
end
Session({db = {miniGameSounds = false}})
equal(MG:Sound("chain", 1) or MG:Sound("heroism") or #sounds, 0, "Mini-game Sounds off: none at all")

-- /era whack, /era blast and /era help ------------------------------------------------------

Session()
SlashCmdList = {}
assert(loadfile("Core/Commands.lua"))("EraUI", E)
local asked = {}
local toggle = MG.Toggle
MG.Toggle = function(self, id) asked[#asked + 1] = id; return toggle(self, id) end
SlashCmdList.ERAUI("whack")
equal(Showing() and MG.current, "whack", "/era whack opens Whack")
SlashCmdList.ERAUI("  WHACK ")
equal(Showing(), false, "and closes it (any case, spaces round it)")
SlashCmdList.ERAUI("blast")
equal(table.concat(asked, ","), "whack,whack,blast", "/era blast asks for Azeroth Blast")
printed = {}
SlashCmdList.ERAUI("help")
local helped = false
for _, line in ipairs(printed) do if line == "/era whack and /era blast open the mini-games." then helped = true end end
equal(helped, true, "/era help lists them")
E.MiniGames = nil
printed = {}
SlashCmdList.ERAUI("whack")
equal(printed[1], "Mini-games are not available.", "without the mini-games, /era whack says so")

print("Mini-games checks passed: " .. checks .. " assertions.")
