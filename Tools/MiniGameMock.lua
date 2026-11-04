-- A mock client for the mini-games' tests (not a test on its own): frames
-- that show and hide down their own branch (OnShow and OnHide fire only when
-- that changes what's visible), textures and atlases the client can refuse,
-- mask textures, 3D model frames, events, timers, sounds (any can be
-- refused), the flight flag, fights and the faction. Session loads every
-- mini-game file in EraUI.toc's order (M.FILES) with SavedVariables as given.
-- Use: local M = dofile("Tools/MiniGameMock.lua"); local MG = M.Session(opts)
--   opts: db (EraUIDB), char (EraUIClassicCharDB), faction ("Horde"), taxi,
--   models (PlayerModel frames work), badModels {[id] = true}, missing
--   {[path, file ID or atlas] = true}, refused {[sound kit] = true}, closeX,
--   gradients, cursor, noInit, random (MiniGames.Random), only (a list of
--   file names, else M.FILES), commands (load Core/Commands.lua too).
-- Then: M.Tick(seconds, step), M.Fire(event, ...), M.Shell(), M.Showing(),
-- M.TakeOff(node), M.Land(), M.equal(got, want, label), M.near(...),
-- M.world, M.frames, M.sounds, M.printed, M.statuses, M.saves(), M.E, M.checks.
local M = {checks = 0}
unpack = table.unpack or unpack

function M.equal(got, want, label)
    M.checks = M.checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
function M.near(got, want, label, within)
    M.checks = M.checks + 1
    assert(type(got) == "number" and math.abs(got - want) <= (within or 1e-6), label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Every mini-game file, in EraUI.toc's order (Tools/TestRules.mjs checks this
-- list and both older suites' loaders against the toc; fengari can't read it).
M.FILES = {"MiniGames", "MiniGameFX", "MiniGameAssets", "MiniGameProgress", "MiniGameMap", "MiniGameCards", "MiniGameShop",
    "MiniGameWhackStages", "MiniGameWhack", "MiniGameWhackHud", "MiniGameBlast", "MiniGameBlastGoals", "MiniGameBlastLevels",
    "MiniGameBlastView", "MiniGameBlastHud", "MiniGameBlastGame"}

local world, frames, timers, sounds, printed, statuses, saves
local missing, refused = {}, {}
local methods = {}
local modelMethods = setmetatable({}, {__index = methods})
local MODEL_META = {__index = modelMethods}
M.methods = methods

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
M.Visible = Visible
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
function methods:SetTexture(path, wrapH, wrapV)
    self.texture, self.wrapH, self.wrapV, self.atlas, self.colour = path, wrapH, wrapV, nil, nil
    if missing[path] then return false end
    return true
end
function methods:SetRotation(radians) self.rotation = radians end
function methods:SetGradient(orientation, low, high) self.gradient = {orientation, low, high} end
function methods:SetAtlas(atlas)
    if missing[atlas] then error("no such atlas " .. tostring(atlas)) end
    self.atlas, self.texture, self.colour = atlas, nil, nil
end
function methods:SetColorTexture(...) self.colour, self.texture, self.atlas = {...}, nil, nil end
function methods:SetVertexColor(...) self.vertex = {...} end
function methods:SetTexCoord(...) self.coords = {...} end
function methods:SetBlendMode(mode) self.blend = mode end
function methods:SetDesaturated(on) self.desaturated = on end
function methods:AddMaskTexture(mask) self.mask = mask end
function methods:SetFont(...) self.font = {...} end
function methods:GetFont() local f = self.font or {}; return f[1], f[2], f[3] end
function methods:SetTextColor(...) self.textColour = {...} end
function methods:SetJustifyH(j) self.justify = j end
function methods:SetWordWrap(on) self.wrap = on end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end
function methods:GetStringWidth() return #tostring(self.text or "") * 6 end
function methods:SetSnapToPixelGrid(on) self.snap = on end
function methods:SetTexelSnappingBias(bias) self.snapBias = bias end
function methods:GetEffectiveScale() return world.scale or 1 end
function methods:IsMouseOver() return self.mouseOver == true end
function modelMethods:SetDisplayInfo(id)
    if world.badModels[id] then error("no such model " .. id) end
    self.display = id
end
function modelMethods:GetDisplayInfo() return self.display or 0 end
function modelMethods:SetAnimation(anim) self.anims[#self.anims + 1] = anim; self.anim = anim end
function modelMethods:SetKeepModelOnHide(on) self.keep = on end
function modelMethods:SetPortraitZoom(zoom) self.zoom = zoom end
function modelMethods:SetCamDistanceScale(scale) self.camera = scale end
function modelMethods:SetPosition(x, y, z) self.position = {x, y, z} end
function modelMethods:SetViewInsets(l, r, t, b) self.insets = {l, r, t, b} end
function modelMethods:SetRotation(radians, animate) self.rotation, self.animateTurn = radians, animate end

function M.Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
-- Time passes: timers that come due run, and the shown frames' OnUpdate runs every step.
function M.Tick(seconds, step)
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
    world = {time = 100, taxi = opts.taxi == true, combat = false, faction = opts.faction or "Horde",
        models = opts.models == true, badModels = opts.badModels or {}, stopped = {}}
    frames, timers, sounds, printed, statuses, saves = {}, {}, {}, {}, {}, 0
    missing, refused = opts.missing or {}, opts.refused or {}
    M.world, M.frames, M.sounds, M.printed, M.statuses = world, frames, sounds, printed, statuses
    GetCursorPosition = opts.cursor and function() return world.cursorX or 0, world.cursorY or 0 end or nil
    UIParent = Frame("Frame", "UIParent")
    UIParent.w, UIParent.h = 1600, 1000
    _G.EraUIMiniGames = nil
    GameFontHighlight = {GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end}
    CreateFrame = Frame
    UISpecialFrames = {}
    issecretvalue = function() return false end
    UnitOnTaxi = function(unit) assert(unit == "player"); return world.taxi end
    UnitFactionGroup = function() return world.faction end
    UnitClass = function() return "Warrior", "WARRIOR" end
    RAID_CLASS_COLORS = {WARRIOR = {r = .78, g = .61, b = .43}}
    InCombatLockdown = function() return world.combat end
    GetTime = function() return world.time end
    C_Timer = {After = function(delay, fn) timers[#timers + 1] = {at = world.time + delay, fn = fn} end}
    PlaySound = function(id, channel)
        sounds[#sounds + 1] = id .. ":" .. tostring(channel)
        if refused[id] then return false end
        return true, #sounds
    end
    PlaySoundFile = function(file, channel)
        sounds[#sounds + 1] = "file " .. file .. ":" .. tostring(channel)
        if refused[file] then return false end
        return true, #sounds
    end
    StopSound = function(handle) world.stopped[#world.stopped + 1] = handle end
    CreateColor = opts.gradients and function(r, g, b, a) return {r = r, g = g, b = b, a = a} end or nil
    IsMouseButtonDown = function() return false end
    C_Texture = {GetAtlasInfo = function(name) if missing[name] then return nil end; return {width = 128, height = 128} end}
    world.nodes = {[3] = "Orgrimmar, Durotar"}
    TakeTaxiNode = function(index) world.took = index end
    TaxiNodeName = function(index) return world.nodes[index] end
    hooksecurefunc = function(name, fn)
        local old = _G[name]
        _G[name] = function(...) local result = old(...); fn(...); return result end
    end
end

-- EraUI with SavedVariables as given, and the mini-game files.
function M.Session(opts)
    opts = opts or {}
    NewWorld(opts)
    EraUIDB = opts.db or {}
    if EraUIDB.miniGameFlight == nil then EraUIDB.miniGameFlight = "off" end
    if EraUIDB.miniGameSounds == nil then EraUIDB.miniGameSounds = true end
    EraUIClassicCharDB = opts.char or {}
    local E = {modules = {}}
    function E:RegisterModule(name, module) self.modules[name] = module end
    function E:GetSetting(key) return EraUIDB[key] end
    function E:SetSetting(key, value) EraUIDB[key] = value end
    function E:SaveSettings() saves = saves + 1 end
    function E:Print(message) printed[#printed + 1] = message end
    function E:Status(message) statuses[#statuses + 1] = message end
    if opts.closeX then
        function E:CreateCloseX(parent, onClick)
            local close = CreateFrame("Button", nil, parent)
            close:SetSize(36, 36)
            close:SetPoint("TOPRIGHT", -8, -8)
            close:SetScript("OnClick", onClick)
            return close
        end
    end
    M.E = E
    for _, name in ipairs(opts.only or M.FILES) do
        assert(loadfile("Modules/" .. name .. ".lua"))("EraUI", E)
    end
    if opts.commands then
        SlashCmdList = {}
        assert(loadfile("Core/Commands.lua"))("EraUI", E)
    end
    local MG = E.MiniGames
    if opts.random then MG.Random = opts.random end
    if not opts.noInit then
        MG:Initialize()
        M.Fire("PLAYER_ENTERING_WORLD", true, false)
    end
    M.MG = MG
    return MG
end
function M.saves() return saves end
function M.Shell() return _G.EraUIMiniGames end
function M.Showing() return _G.EraUIMiniGames ~= nil and _G.EraUIMiniGames:IsVisible() end
function M.TakeOff(node)
    if node then TakeTaxiNode(node) end
    world.taxi = true
    M.Fire("PLAYER_CONTROL_LOST")
end
function M.Land()
    world.taxi = false
    M.Fire("PLAYER_CONTROL_GAINED")
end
-- A plain test game registered as id (it records what the core asks of it).
function M.TestGame(MG, id)
    local game = {calls = {}}
    local function Log(name, ...) game.calls[#game.calls + 1] = table.concat({name, ...}, " ") end
    function game:Build(shell, holder, bar) self.made = true; Log("Build") end
    function game:Shown(shell, why) Log("Shown", tostring(why)) end
    function game:Pause(shell, why) Log("Pause", tostring(why)) end
    function game:Land() Log("Land") end
    function game:Keep() Log("Keep") end
    function game:Score() return 0 end
    function game:ProgressReset() Log("ProgressReset") end
    function game:Command(words) Log("Command", words); return words ~= "nonsense" end
    MG:Register(id, game)
    return game
end
return M
