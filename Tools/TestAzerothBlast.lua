-- Azeroth Blast (Modules/MiniGameBlast.lua) on the mini-games core
-- (Modules/MiniGames.lua). First its rules as plain Lua (MiniGames.Blast, no
-- frames) on boards laid out by hand: a new board never starts with a line
-- or a square and always has a move; swaps that match nothing or aren't
-- side by side; each special made by its shape (Charge, Explosive Sheep,
-- Gryphon / Wind Rider, Hearthstone) and where it goes; what each one clears;
-- chains; every combo; one special swapped with any piece firing at once
-- (from where it lands, with any match the swap lines up), and counted as a
-- move by the move finder, the hint and the shuffle; the Hearthstone clearing one race; the Bloodlust /
-- Heroism meter filling only from the other faction's races and doubling
-- points for 10 seconds; epic loot; chains of clears always ending;
-- shuffling a board with no move; keeping a board; the hint finder. Then
-- Free play in the window on a small mock client (as Tools/TestMiniGames.lua;
-- the levels are Tools/TestBlastCampaign.lua's): the board drawn (stone
-- tiles, each race's face on its own coloured plate, the sides' pips, the
-- specials' marks: a bigger badge in its own light, a stronger pulsing glow
-- and a glint, never over the face; the art's fallbacks), clicks and drags, a move played out
-- (pieces popping, sparks, loot flying to the score, points rising, the
-- fall's bounce), each special's and combo's effects and sounds, chain
-- words, Bloodlust / Heroism round the board's edge (never over it), epic
-- loot, hints (by themselves after 15 seconds and by the button, a 30 second
-- cooldown between them), New board,
-- flights (the board kept for the next one), fights, sounds off and the
-- faction's names and icons.
-- Run: fengari Tools/TestAzerothBlast.lua
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = table.unpack or unpack

-- The mock client -------------------------------------------------------------------

local world, frames, timers, sounds, printed, saves, hooks
local missing = {}
local methods = {}

local function Visible(f) return f.shown and (f.parent == nil or Visible(f.parent)) end
local function Visit(f, script)
    f:Fire(script)
    for _, child in ipairs(f.children) do if child.shown then Visit(child, script) end end
end
local function Frame(kind, name, parent, template)
    local f = setmetatable({kind = kind, name = name, parent = parent, template = template, shown = true, points = {},
        scripts = {}, events = {}, children = {}, calls = {}, level = parent and (parent.level or 1) + 1 or 1}, {__index = methods})
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
function methods:SetRotation(radians) self.rotation = radians end
function methods:RegisterEvent(event) self.events[event] = true end
function methods:UnregisterEvent(event) self.events[event] = nil end
function methods:Click(button) self:Fire("PreClick", button); self:Fire("OnClick", button) end
function methods:CreateTexture(_, layer, _, sublevel) local t = Frame("Texture", nil, self); t.layer, t.sublevel = layer, sublevel; return t end
function methods:CreateMaskTexture() return Frame("MaskTexture", nil, self) end
function methods:CreateFontString() return Frame("FontString", nil, self) end
function methods:SetTexture(path, wrapH, wrapV)
    self.texture, self.wrapH, self.wrapV, self.atlas = path, wrapH, wrapV, nil
    if missing[path] then return false end
    return true
end
function methods:SetAtlas(atlas) self.atlas = atlas end
function methods:SetColorTexture(...) self.colour = {...} end
function methods:SetVertexColor(...) self.vertex = {...} end
function methods:SetTexCoord(...) self.coords = {...} end
function methods:SetBlendMode(mode) self.blend = mode end
function methods:SetDesaturated(on) self.desaturated = on end
function methods:AddMaskTexture(mask) self.mask = mask end
function methods:SetFont(...) self.font = {...} end
function methods:SetTextColor(...) self.textColour = {...} end
function methods:SetJustifyH(j) self.justify = j end
function methods:SetWordWrap(on) self.wrap = on end
function methods:SetText(text) self.text = text end
function methods:GetText() return self.text end

local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
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
    world = {time = 100, taxi = opts.taxi == true, combat = false, faction = opts.faction or "Horde", mouse = false}
    frames, timers, sounds, printed, saves, hooks = {}, {}, {}, {}, 0, {}
    missing = opts.missing or {}
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
    IsMouseButtonDown = function(button) return button == "LeftButton" and world.mouse end
    C_Timer = {After = function(delay, fn) timers[#timers + 1] = {at = world.time + delay, fn = fn} end}
    -- Each sound played gets a handle: its place in sounds.
    PlaySound = function(id, channel) sounds[#sounds + 1] = id .. ":" .. tostring(channel); return true, #sounds end
    PlaySoundFile = function(file, channel) sounds[#sounds + 1] = "file " .. file .. ":" .. tostring(channel); return true, #sounds end
    StopSound = function(handle) world.stopped[#world.stopped + 1] = handle end
    world.stopped = {}
    C_Texture = {GetAtlasInfo = function(name) if missing[name] then return nil end; return {width = 128, height = 128} end}
    world.nodes = {[3] = "Orgrimmar, Durotar"}
    TakeTaxiNode = function(index) world.took = index end
    TaxiNodeName = function(index) return world.nodes[index] end
    hooksecurefunc = function(name, fn)
        hooks[#hooks + 1] = name
        local old = _G[name]
        _G[name] = function(...) local result = old(...); fn(...); return result end
    end
end

-- A random that goes round 1, 2, 3...
local function Cycle()
    local n = 0
    return function(low, high)
        n = n + 1
        return low + (n - 1) % (high - low + 1)
    end
end
-- A seeded random, the same every run.
local function Lcg(seed)
    local x = seed
    return function(low, high)
        x = (x * 1103515245 + 12345) % 2147483648
        return low + math.floor(x / 65536) % (high - low + 1)
    end
end

-- EraUI: the core, Whack and Azeroth Blast alone, with SavedVariables as given.
local E, MG, B

-- The effects kit's calls, kept as they're made (each runs as it would):
-- {name, at, text, opts (a copy, as it was then), strength, data}.
local spied = {}
local KIT = {"Burst", "FloatText", "Banner", "Shake", "Pulse", "Tween"}
local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end
local function Spy()
    spied = {}
    for _, name in ipairs(KIT) do
        local real = MG[name]
        MG[name] = function(self, a, b, c, d)
            local call = {name = name}
            if name == "Burst" or name == "Pulse" then call.at, call.opts = a, Copy(b)
            elseif name == "FloatText" then call.at, call.text, call.opts = a, b, Copy(c)
            elseif name == "Banner" then call.text, call.opts = a, Copy(b)
            elseif name == "Shake" then call.strength = a
            else call.data = d end
            spied[#spied + 1] = call
            return real(self, a, b, c, d)
        end
    end
end
-- The calls of one kind (since the last Forget), those test likes.
local function Spied(name, test)
    local out = {}
    for _, call in ipairs(spied) do
        if call.name == name and (test == nil or test(call)) then out[#out + 1] = call end
    end
    return out
end
local function Forget() spied = {} end
local function Heard(id)
    for _, sound in ipairs(sounds) do if sound == id then return true end end
    return false
end
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
    -- Every mini-game file, in EraUI.toc's order.
    for _, name in ipairs({"MiniGames", "MiniGameFX", "MiniGameAssets", "MiniGameProgress", "MiniGameMap", "MiniGameCards",
        "MiniGameShop", "MiniGameWhackStages", "MiniGameWhack", "MiniGameWhackHud", "MiniGameBlast", "MiniGameBlastGoals",
        "MiniGameBlastLevels", "MiniGameBlastView", "MiniGameBlastHud", "MiniGameBlastGame"}) do
        assert(loadfile("Modules/" .. name .. ".lua"))("EraUI", E)
    end
    MG = E.MiniGames
    B = MG.Blast
    MG.Random = opts.random or Lcg(7)
    Spy()
    MG:Initialize()
    Fire("PLAYER_ENTERING_WORLD", true, false)
    return MG
end
local function Shell() return _G.EraUIMiniGames end
local function Showing() return Shell() ~= nil and Shell():IsVisible() end
local function Game() return MG.games.blast end
local function TakeOff(node)
    if node then TakeTaxiNode(node) end
    world.taxi = true
    Fire("PLAYER_CONTROL_LOST")
end
local function Land()
    world.taxi = false
    Fire("PLAYER_CONTROL_GAINED")
end

-- Boards by hand --------------------------------------------------------------------

Session()
local I = B.Index
local LETTER = {O = "orc", T = "tauren", U = "undead", H = "human", D = "dwarf", N = "nightelf"}
-- A scripted random: a rule per kind of roll (a number, or a function of
-- low and high); epic loot never unless asked; everything else goes round.
local function Script(rules)
    rules = rules or {}
    local n = 0
    return function(low, high, why)
        local rule = rules[why]
        if type(rule) == "function" then return rule(low, high) end
        if type(rule) == "number" then return rule end
        if why == "epic" then return high end
        n = n + 1
        return low + (n - 1) % (high - low + 1)
    end
end
local function State(faction, rules) return B.New(Script(rules), faction or "Horde") end
-- 8 rows of 8: O, T, U the Horde's orc, tauren, undead; H, D, N the
-- Alliance's human, dwarf, night elf; "." a piece of a kind of its own (it
-- never matches). specials: {[cell] = {special, dir}}. standing: the board
-- may have a match laid on it already.
local function Lay(state, rows, specials, standing)
    local board = {}
    for r = 1, 8 do
        for c = 1, 8 do
            local i = I(r, c)
            state.nextId = state.nextId + 1
            board[i] = {id = state.nextId, kind = LETTER[rows[r]:sub(c, c)] or ("x" .. i)}
        end
    end
    for i, spec in pairs(specials or {}) do
        if spec[1] == "hearth" then board[i].kind = nil end
        board[i].special, board[i].dir = spec[1], spec[2]
    end
    state.board = board
    if not standing then equal(#B.FindGroups(board), 0, "a board laid by hand starts with no match") end
    return board
end
local EMPTY = "........"
local function Rows(over)
    local rows = {}
    for r = 1, 8 do rows[r] = over[r] or EMPTY end
    return rows
end
local function Sorted(list)
    local copy = {}
    for k, v in ipairs(list) do copy[k] = v end
    table.sort(copy)
    return table.concat(copy, " ")
end
local function Cleared(step)
    local out = {}
    for _, gone in ipairs(step.cleared) do out[#out + 1] = gone.i end
    return Sorted(out)
end
-- Cells as a sorted list: rectangles {r1, c1, r2, c2} and single cells {r, c}, joined.
local function Area(...)
    local seen, out = {}, {}
    for _, part in ipairs({...}) do
        local r1, c1, r2, c2 = part[1], part[2], part[3] or part[1], part[4] or part[2]
        for r = r1, r2 do
            for c = c1, c2 do
                local i = I(r, c)
                if not seen[i] then seen[i] = true; out[#out + 1] = i end
            end
        end
    end
    return Sorted(out)
end
local function Fired(step)
    local out = {}
    for _, shot in ipairs(step.fired) do out[#out + 1] = shot.special end
    return table.concat(out, ",")
end

-- An independent look at a board: its lines of three and squares, and whether any swap matches.
local function Matches(board)
    local function K(r, c)
        local p = r >= 1 and r <= 8 and c >= 1 and c <= 8 and board[(r - 1) * 8 + c]
        return p and p.kind
    end
    local found = 0
    for r = 1, 8 do
        for c = 1, 8 do
            local k = K(r, c)
            if k then
                if K(r, c + 1) == k and K(r, c + 2) == k then found = found + 1 end
                if K(r + 1, c) == k and K(r + 2, c) == k then found = found + 1 end
                if K(r, c + 1) == k and K(r + 1, c) == k and K(r + 1, c + 1) == k then found = found + 1 end
            end
        end
    end
    return found
end
local function AnyMove(board)
    for i = 1, 64 do
        -- Any special: swapped with the piece beside it, it fires (Free play has no relics or locked pieces).
        if board[i].special then return true end
        local r, c = B.Cell(i)
        for _, j in ipairs({c < 8 and i + 1 or nil, r < 8 and i + 8 or nil}) do
            board[i], board[j] = board[j], board[i]
            local works = Matches(board) > 0
            board[i], board[j] = board[j], board[i]
            if works then return true end
        end
    end
    return false
end

-- New boards ---------------------------------------------------------------------------

do
    local bad, stuck, odd = 0, 0, 0
    for seed = 1, 300 do
        local s = B.New(Lcg(seed), seed % 2 == 0 and "Alliance" or "Horde")
        if Matches(s.board) > 0 or #B.FindGroups(s.board) > 0 then bad = bad + 1 end
        if not AnyMove(s.board) or not B.FindMove(s.board) then stuck = stuck + 1 end
        for i = 1, 64 do
            local p = s.board[i]
            if not (p and B.RACE[p.kind] and p.special == nil) then odd = odd + 1 end
        end
    end
    equal(bad, 0, "300 new boards: no line of three and no 2x2 square on any")
    equal(stuck, 0, "and every one has a move")
    equal(odd, 0, "64 plain pieces of the six races on each")
    for _, fixed in ipairs({1, 6, 99}) do
        local s = B.New(function(low, high) return fixed end, "Horde")
        equal(Matches(s.board) == 0 and AnyMove(s.board), true, "a random stuck on " .. fixed .. ": still no match and a move")
    end
    local s = B.New(Script(), "Horde")
    local tries = B.TRIES
    B.TRIES = 0
    B.Arrange(s, false)
    B.TRIES = tries
    equal(Matches(s.board) .. " " .. tostring(AnyMove(s.board)), "0 true", "the fixed layout (no random one had a move): no match, a move")
    local a, b = B.FindMove(s.board)
    equal(a .. " " .. b, I(2, 1) .. " " .. I(2, 2), "its move: row 2's first two")
    local seen = {}
    for _, race in ipairs(B.RACES) do seen[race.faction] = (seen[race.faction] or 0) + 1 end
    equal(seen.Horde .. " " .. seen.Alliance .. " " .. #B.KINDS, "3 3 6", "three Horde races and three Alliance ones")
    equal(State("Neutral").faction .. " " .. State(nil).faction .. " " .. State("Alliance").faction, "Horde Horde Alliance",
        "anyone not Alliance sees it as the Horde")
end

-- Swaps -------------------------------------------------------------------------------------

do
    local s = State()
    Lay(s, Rows({[4] = "OO......", [5] = "..O....."}))
    local before = B.Copy(s.board)
    for _, pair in ipairs({{I(1, 1), I(1, 3)}, {I(1, 1), I(2, 2)}, {I(1, 8), I(2, 1)}, {0, 1}, {64, 65}, {5, 5}, {"1", 2}, {1.5, 2}}) do
        local result = B.Swap(s, pair[1], pair[2])
        equal(result.ok == false and result.why, "far", "only side by side swaps: " .. tostring(pair[1]) .. " and " .. tostring(pair[2]))
    end
    local result = B.Swap(s, I(5, 5), I(5, 6))
    equal(result.ok == false and result.why, "nomatch", "a swap that matches nothing")
    local same = true
    for i = 1, 64 do if s.board[i] ~= before[i] then same = false end end
    equal(same and s.score == 0 and s.moves == 0, true, "swaps back: the board as it was, no score")

    -- Three in a line.
    result = B.Swap(s, I(5, 3), I(4, 3))
    equal(result.ok, true, "three of a race lined up")
    local step = result.steps[1]
    equal(Cleared(step), Area({4, 1, 4, 3}), "they clear")
    equal(#step.made .. " " .. step.points .. " " .. s.score, "0 30 30", "three make nothing: 10 points a piece")
    equal(step.fall[I(4, 1)] .. " " .. step.fall[I(1, 1)] .. " " .. step.fall[I(5, 1)], "1 1 0", "the pieces above fall one row, a new one drops in")
    equal(step.after[I(4, 1)] == step.before[I(3, 1)], true, "the piece above is now in the gap")
    equal(s.moves, 1, "a move counted")
end

-- A Hearthstone (no race) after a pair in a row ends the line: the match
-- finder once read the cell under the pair's start as the row's next one.
do
    local s = State()
    Lay(s, Rows({[2] = "OO......", [3] = ".O......"}), {[I(2, 3)] = {"hearth"}})
    equal(#B.FindGroups(s.board), 0, "two orcs, a Hearthstone, an orc under the second: no match")
    -- The same with every piece a real race, kept and read back.
    local kept = State()
    local board, place = {}, {[I(2, 1)] = "orc", [I(2, 2)] = "orc", [I(3, 2)] = "orc"}
    for i = 1, 64 do
        kept.nextId = kept.nextId + 1
        if i == I(2, 3) then board[i] = {id = kept.nextId, special = "hearth"}
        elseif place[i] then board[i] = {id = kept.nextId, kind = place[i]} end
    end
    for i = 1, 64 do
        if not board[i] then
            kept.nextId = kept.nextId + 1
            for _, kind in ipairs(B.KINDS) do
                board[i] = {id = kept.nextId, kind = kind}
                if Matches(board) == 0 then break end
            end
        end
    end
    kept.board = board
    equal(Matches(board) .. " " .. #B.FindGroups(board), "0 0", "a full board with that pattern: no match either way")
    local saved = {}
    B.Save(kept, saved)
    local back = State()
    equal(B.Load(back, saved), true, "kept with it: read back, not refused")
    equal(back.board[I(2, 3)].special .. " " .. tostring(back.board[I(2, 3)].kind), "hearth nil", "the Hearthstone where it was")
    -- A swap that only lines up two orcs and that Hearthstone.
    s = State()
    Lay(s, Rows({[2] = "OO......", [3] = "..O....."}), {[I(2, 3)] = {"hearth"}})
    local hearth = s.board[I(2, 3)]
    local result = B.Swap(s, I(3, 3), I(3, 2))
    equal(result.ok == false and result.why, "nomatch", "an orc moved under the pair: no match, so it swaps back")
    equal(s.board[I(2, 3)] == hearth and s.board[I(3, 3)].kind .. " " .. s.score, "orc 0", "the Hearthstone kept, nothing scored")
end

-- Specials, made by their shapes ----------------------------------------------------------

local function Made(rows, a, b, label)
    local s = State()
    Lay(s, Rows(rows))
    local result = B.Swap(s, a, b)
    equal(result.ok, true, label .. ": the swap matches")
    return result.steps[1], s, result
end
do
    local step = Made({[4] = "OO.O....", [5] = "..O....."}, I(5, 3), I(4, 3), "four across")
    local made = step.made[1] and step.made[1].piece
    equal(made.special .. " " .. made.dir .. " " .. made.kind .. " " .. step.made[1].i, "charge row orc " .. I(4, 3),
        "four across make a Charge for the row, an orc still, where the moved piece went")
    equal(Cleared(step), Area({4, 1, 4, 4}), "the four go")
    equal(step.after[I(4, 3)], made, "and it stays there (nothing under it went)")

    step = Made({[1] = "...O....", [2] = "...O....", [3] = "....O...", [4] = "...O...."}, I(3, 5), I(3, 4), "four down")
    made = step.made[1].piece
    equal(made.special .. " " .. made.dir .. " " .. step.made[1].i, "charge col " .. I(3, 4), "four down make a Charge for the column")
    equal(step.after[I(4, 4)] == made and step.fall[I(4, 4)], 1, "it falls into the gap under it")

    step = Made({[3] = "O.......", [4] = "O.......", [5] = ".OO.....", [6] = "O......."}, I(6, 1), I(5, 1), "an L")
    made = step.made[1].piece
    equal(made.special .. " " .. made.kind .. " " .. step.made[1].i, "sheep orc " .. I(5, 1), "an L makes an Explosive Sheep at its corner")
    equal(Cleared(step), Area({3, 1, 5, 1}, {5, 2, 5, 3}), "the five of the L go")

    step = Made({[4] = "..O.....", [5] = ".O.O....", [6] = "..O.....", [7] = "..O....."}, I(4, 3), I(5, 3), "a T")
    equal(step.made[1].piece.special .. " " .. step.made[1].i, "sheep " .. I(5, 3), "a T makes one too")

    step = Made({[4] = "OO......", [5] = "O.O....."}, I(5, 3), I(5, 2), "a square")
    made = step.made[1].piece
    equal(made.special .. " " .. made.kind .. " " .. step.made[1].i, "flyer orc " .. I(5, 2), "a 2x2 square makes a flyer")
    equal(Cleared(step), Area({4, 1, 5, 2}), "the square goes")

    step = Made({[4] = "OO.OO...", [5] = "..O....."}, I(5, 3), I(4, 3), "five across")
    made = step.made[1].piece
    equal(made.special .. " " .. tostring(made.kind) .. " " .. step.made[1].i, "hearth nil " .. I(4, 3), "five in a line make a Hearthstone, no race")
    step = Made({[2] = "..O.....", [3] = "..O.....", [4] = "OO.OO...", [5] = "..O....."}, I(5, 3), I(4, 3), "five across with three down")
    equal(step.made[1].piece.special .. " " .. #step.made, "hearth 1", "five in a line beat a T: one Hearthstone")
    step = Made({[3] = "..OO....", [4] = "OO.O....", [5] = "..O....."}, I(5, 3), I(4, 3), "four across with a square")
    equal(step.made[1].piece.special .. " " .. step.made[1].piece.dir .. " " .. #step.made, "charge row 1", "four in a line beat a square: one Charge")
    equal(Cleared(step), Area({4, 1, 4, 4}, {3, 3, 3, 4}), "all six go")

    local s = State()
    Lay(s, Rows({[3] = "..O.....", [4] = "..O.....", [5] = "OO......"}), nil, true)
    s.board[I(5, 3)].kind = "orc"
    local result = B.Settle(s)
    equal(result.steps[1].made[1].piece.special .. " " .. result.steps[1].made[1].i, "sheep " .. I(5, 3),
        "an L no one moved (a chain's): the Sheep at its corner")
    s = State()
    Lay(s, Rows({[2] = "OOOO...."}), nil, true)
    result = B.Settle(s)
    equal(result.steps[1].made[1].i, I(2, 2), "four no one moved: the Charge in the middle")
    equal(B.Shape({runs = {{dir = "row", cells = {1, 2, 3}}}, squares = {}}), nil, "three in a line: no special")
end

-- What the specials clear --------------------------------------------------------------------

local function Settled(rows, specials, rules)
    local s = State(nil, rules)
    Lay(s, Rows(rows), specials, true)
    local result = B.Settle(s)
    return result.steps[1], s, result
end
do
    local step = Settled({[4] = "OOO....."}, {[I(4, 2)] = {"charge", "row"}})
    equal(Fired(step) .. " | " .. Cleared(step), "charge | " .. Area({4, 1, 4, 8}), "a Charge for the row caught in a match clears the row")
    equal(table.concat(step.flashes[1], ","), "4,1,4,8", "and lights it")
    equal(step.points, 80, "8 pieces, 80 points")
    step = Settled({[2] = ".....O..", [3] = ".....O..", [4] = ".....O.."}, {[I(3, 6)] = {"charge", "col"}})
    equal(Cleared(step), Area({1, 6, 8, 6}), "a Charge for the column clears the column")
    step = Settled({[4] = "..OOO..."}, {[I(4, 4)] = {"sheep"}})
    equal(Cleared(step), Area({3, 3, 5, 5}), "an Explosive Sheep clears the 3x3 round it")
    step = Settled({[1] = "OOO....."}, {[I(1, 1)] = {"sheep"}})
    equal(Cleared(step), Area({1, 1, 2, 2}, {1, 3}), "in a corner, what of the 3x3 is on the board")
    step = Settled({[4] = "OOO....."}, {[I(4, 2)] = {"flyer"}}, {flyer = 1})
    equal(Fired(step) .. " " .. step.fired[1].target .. " | " .. Cleared(step), "flyer " .. I(1, 1) .. " | " .. Area({4, 1, 4, 3}, {1, 1}),
        "a flyer clears one piece elsewhere")
    step = Settled({[4] = "OOO....."}, {[I(4, 2)] = {"flyer"}}, {flyer = 61})
    equal(step.fired[1].target .. " " .. #step.cleared, I(8, 8) .. " 4", "any of the 61 pieces left, one only")

    -- The Hearthstone: swapped with a piece, every piece of that race goes.
    local s = State()
    Lay(s, Rows({[1] = "H.......", [2] = "......H.", [4] = "....H...", [6] = ".D....D.", [8] = ".......H"}), {[I(4, 4)] = {"hearth"}})
    local result = B.Swap(s, I(4, 4), I(4, 5))
    step = result.steps[1]
    equal(result.combo .. " " .. result.hearthKind, "hearth human", "the Hearthstone swapped with a human")
    equal(Cleared(step), Area({1, 1}, {2, 7}, {4, 4}, {4, 5}, {8, 8}), "every human goes, and the Hearthstone")
    equal(Fired(step), "", "it's spent, not fired again")
    equal(step.points, 50, "five pieces")
    s = State()
    Lay(s, Rows({[1] = "H.......", [4] = "...D....", [6] = ".D....D."}), {[I(4, 5)] = {"hearth"}})
    result = B.Swap(s, I(4, 4), I(4, 5))
    equal(result.hearthKind .. " | " .. Cleared(result.steps[1]), "dwarf | " .. Area({4, 4}, {4, 5}, {6, 2}, {6, 7}),
        "the piece swapped onto it decides too: every dwarf")
    -- Caught in another's blast, it takes a race still on the board.
    step = Settled({[1] = "H....H..", [3] = "...H....", [6] = "OOO....."}, {[I(6, 2)] = {"charge", "row"}, [I(6, 8)] = {"hearth"}}, {hearth = 1})
    equal(Fired(step) .. " " .. step.fired[2].kind, "charge,hearth human", "a Hearthstone caught in a Charge fires on a race")
    equal(Cleared(step), Area({6, 1, 6, 8}, {1, 1}, {1, 6}, {3, 4}), "every human goes with the row")
end

-- Chains ------------------------------------------------------------------------------------

do
    local step = Settled({[4] = "..OOO..."}, {[I(4, 4)] = {"sheep"}, [I(3, 3)] = {"charge", "col"}, [I(8, 3)] = {"flyer"}}, {flyer = 1})
    equal(Fired(step), "sheep,charge,flyer", "a Sheep's blast sets off a Charge, whose line sets off a flyer")
    equal(Cleared(step), Area({3, 3, 5, 5}, {1, 3, 8, 3}, {1, 1}), "all they caught goes")
    equal(step.points, 10 * (9 + 5 + 1), "10 a piece")
end

-- Combos: two specials swapped together --------------------------------------------------------

local function Combo(specials, a, b, rules)
    local s = State(nil, rules)
    Lay(s, Rows({}), specials)
    local result = B.Swap(s, a, b)
    equal(result.ok, true, "two specials always swap")
    return result, result.steps[1], s
end
do
    local result, step = Combo({[I(4, 4)] = {"charge", "row"}, [I(4, 5)] = {"sheep"}}, I(4, 4), I(4, 5))
    equal(result.combo .. " | " .. Cleared(step), "chargesheep | " .. Area({3, 1, 5, 8}, {1, 4, 8, 6}), "Charge + Sheep: a cross three wide")
    equal(Fired(step), "", "both spent in the combo")
    result, step = Combo({[I(4, 4)] = {"sheep"}, [I(4, 5)] = {"charge", "col"}}, I(4, 4), I(4, 5))
    equal(result.combo .. " | " .. Cleared(step), "chargesheep | " .. Area({3, 1, 5, 8}, {1, 4, 8, 6}), "either way round")
    result, step = Combo({[I(4, 4)] = {"charge", "row"}, [I(5, 4)] = {"charge", "col"}}, I(4, 4), I(5, 4))
    equal(result.combo .. " | " .. Cleared(step), "charges | " .. Area({5, 1, 5, 8}, {1, 4, 8, 4}), "Charge + Charge: a row and a column")
    result, step = Combo({[I(4, 4)] = {"sheep"}, [I(4, 5)] = {"sheep"}}, I(4, 4), I(4, 5))
    equal(result.combo .. " | " .. Cleared(step), "sheeps | " .. Area({2, 3, 6, 7}), "Sheep + Sheep: the 5x5")
    result, step = Combo({[I(1, 1)] = {"sheep"}, [I(1, 2)] = {"sheep"}}, I(1, 1), I(1, 2))
    equal(Cleared(step), Area({1, 1, 3, 4}), "in a corner, what of it is on the board")
    result, step = Combo({[I(4, 4)] = {"hearth"}, [I(4, 5)] = {"hearth"}}, I(4, 4), I(4, 5))
    equal(result.combo .. " " .. #step.cleared .. " " .. step.points, "hearths 64 640", "Hearthstone + Hearthstone: the whole board")
    result, step = Combo({[I(4, 4)] = {"flyer"}, [I(4, 5)] = {"charge", "row"}}, I(4, 4), I(4, 5), {flyer = 1})
    equal(result.combo .. " " .. Fired(step) .. " | " .. Cleared(step), "flyer flyer,charge | " .. Area({4, 1, 4, 8}, {1, 1}),
        "a flyer + a Charge: both fire")
    result, step = Combo({[I(4, 4)] = {"flyer"}, [I(4, 5)] = {"flyer"}}, I(4, 4), I(4, 5), {flyer = 1})
    equal(Fired(step) .. " | " .. Cleared(step), "flyer,flyer | " .. Area({4, 4, 4, 5}, {1, 1, 1, 2}), "two flyers: each clears a piece")
    result, step = Combo({[I(6, 6)] = {"sheep"}, [I(6, 7)] = {"flyer"}}, I(6, 6), I(6, 7), {flyer = 1})
    equal(Fired(step) .. " | " .. Cleared(step), "sheep,flyer | " .. Area({5, 6, 7, 8}, {1, 1}),
        "a flyer + a Sheep: both fire (the Sheep from where it was moved to)")
    result, step = Combo({[I(4, 4)] = {"hearth"}, [I(4, 5)] = {"flyer"}}, I(4, 4), I(4, 5), {flyer = 1})
    equal(Fired(step) .. " " .. #step.cleared, "flyer 3", "a Hearthstone + a flyer: its race goes and the flyer fires")

    local s = State()
    Lay(s, Rows({[4] = ".OO.....", [5] = "O......."}), {[I(5, 1)] = {"charge", "col"}})
    local result2 = B.Swap(s, I(5, 1), I(4, 1))
    equal(result2.ok and Fired(result2.steps[1]) .. " | " .. Cleared(result2.steps[1]), "charge | " .. Area({1, 1, 8, 1}, {4, 2, 4, 3}),
        "a Charge moved into a match fires down its column, once")
    equal(result2.lone, I(4, 1), "from the cell it landed on")
end

-- One special swapped with any piece: it fires at once, no match needed ------------------------------

-- A board with no match and the specials given ({[cell] = {special, dir}}), swapped from a to b.
local function Lone(specials, a, b, rows, rules)
    local s = State(nil, rules)
    Lay(s, Rows(rows or {}), specials)
    local before = B.Copy(s.board)
    local result = B.Swap(s, a, b)
    return result, result.steps and result.steps[1], s, before
end
do
    -- A Charge for the row moved along its row: that row, from where it lands.
    local result, step, s, before = Lone({[I(4, 4)] = {"charge", "row"}}, I(4, 4), I(4, 5))
    equal(tostring(result.ok) .. " " .. tostring(result.lone) .. " " .. tostring(result.combo), "true " .. I(4, 5) .. " nil",
        "a Charge and a plain piece swap: no match needed, no combo")
    equal(Fired(step) .. " " .. step.fired[1].i .. " | " .. Cleared(step), "charge " .. I(4, 5) .. " | " .. Area({4, 1, 4, 8}),
        "it fires its row from the cell it landed on")
    equal(table.concat(step.flashes[1], ",") .. " " .. step.points .. " " .. s.score .. " " .. s.moves, "4,1,4,8 80 80 1",
        "the row lit, 80 points, one move")
    equal(result.swapped[I(4, 5)] == before[I(4, 4)] and result.swapped[I(4, 4)] == before[I(4, 5)], true, "the swap shows first")
    -- Moved down a row: the row it lands on (the line its badge shows).
    result, step = Lone({[I(4, 4)] = {"charge", "row"}}, I(4, 4), I(5, 4))
    equal(Cleared(step), Area({5, 1, 5, 8}), "a Charge for the row moved down: row 5")
    equal(step.before[I(4, 4)].special == nil and step.after[I(5, 4)] == step.before[I(4, 4)], true,
        "the piece it swapped with, off its line, stays and falls into the gap")
    result, step = Lone({[I(4, 4)] = {"charge", "col"}}, I(4, 4), I(5, 4))
    equal(Cleared(step), Area({1, 4, 8, 4}), "a Charge for the column moved down: its column")
    -- A plain piece moved onto the Charge: the Charge still fires from where it lands.
    result, step = Lone({[I(4, 4)] = {"charge", "col"}}, I(4, 5), I(4, 4))
    equal(result.lone .. " | " .. Cleared(step), I(4, 5) .. " | " .. Area({1, 5, 8, 5}), "a piece moved onto a Charge: it fires down column 5")
    -- At the board's edges and corners.
    result, step = Lone({[I(8, 8)] = {"charge", "col"}}, I(8, 8), I(7, 8))
    equal(Cleared(step), Area({1, 8, 8, 8}), "a Charge in the bottom corner: column 8")
    result, step = Lone({[I(1, 1)] = {"charge", "row"}}, I(1, 1), I(2, 1))
    equal(Cleared(step), Area({2, 1, 2, 8}), "from the top corner down: row 2")

    -- An Explosive Sheep: the 3 x 3 round where it lands, cut at the edges.
    result, step = Lone({[I(4, 4)] = {"sheep"}}, I(4, 4), I(4, 5))
    equal(Fired(step) .. " | " .. Cleared(step), "sheep | " .. Area({3, 4, 5, 6}), "a Sheep and a plain piece: the 3x3 round it")
    result, step = Lone({[I(1, 4)] = {"sheep"}}, I(1, 4), I(1, 5))
    equal(Cleared(step), Area({1, 4, 2, 6}), "on the top edge: what of it is on the board")
    result, step = Lone({[I(1, 2)] = {"sheep"}}, I(1, 2), I(1, 1))
    equal(Cleared(step), Area({1, 1, 2, 2}), "in the corner: four pieces")

    -- A Gryphon / Wind Rider: off it goes, as when it's caught in a clear.
    result, step = Lone({[I(4, 4)] = {"flyer"}}, I(4, 4), I(4, 5), nil, {flyer = 1})
    equal(Fired(step) .. " " .. step.fired[1].i .. " " .. step.fired[1].target .. " | " .. Cleared(step),
        "flyer " .. I(4, 5) .. " " .. I(1, 1) .. " | " .. Area({1, 1}, {4, 5}), "a flyer and a plain piece: it takes off and clears one piece")
    equal(step.points .. " " .. #step.made, "20 0", "two pieces, nothing made")

    -- The same swap lining up a match: both go in the one clear.
    result, step = Lone({[I(4, 3)] = {"charge", "col"}}, I(5, 3), I(4, 3), {[4] = "OO......", [5] = "..O....."})
    equal(tostring(result.lone) .. " " .. Fired(step) .. " | " .. Cleared(step), I(5, 3) .. " charge | " .. Area({1, 3, 8, 3}, {4, 1, 4, 2}),
        "an orc swapped with a Charge, lining up three: the Charge's column and the three go together")
    equal(#step.made, 0, "three make nothing")
    result, step = Lone({[I(4, 3)] = {"sheep"}}, I(5, 3), I(4, 3), {[4] = "OO.O....", [5] = "..O....."})
    equal(Cleared(step), Area({4, 1, 4, 4}, {4, 2, 6, 4}), "four lined up beside a Sheep: the four and the Sheep's 3x3")
    equal(step.made[1] and step.made[1].piece.special .. " " .. step.made[1].i .. " " .. tostring(step.after[I(6, 3)] == step.made[1].piece),
        "charge " .. I(4, 3) .. " true", "the four still make their Charge where the moved piece went (it falls into the Sheep's gap)")

    -- A Hearthstone and two specials keep their combos.
    result = Lone({[I(4, 4)] = {"hearth"}}, I(4, 4), I(4, 5), {[4] = "....O..."})
    equal(tostring(result.combo) .. " " .. tostring(result.lone), "hearth nil", "a Hearthstone with a piece: still that piece's race")
    result = Lone({[I(4, 4)] = {"charge", "row"}, [I(4, 5)] = {"sheep"}}, I(4, 4), I(4, 5))
    equal(tostring(result.combo) .. " " .. tostring(result.lone), "chargesheep nil", "two specials: still their combo")
    -- Two plain pieces still need a match.
    result = Lone({[I(1, 1)] = {"charge", "row"}}, I(5, 5), I(5, 6))
    equal(result.ok == false and result.why, "nomatch", "two plain pieces that match nothing still swap back")

    -- The meter fills from the other side's pieces it clears; Bloodlust doubles it; epic loot as ever.
    result, step, s = Lone({[I(4, 4)] = {"charge", "row"}}, I(4, 4), I(4, 5), {[4] = "HH.DN..."})
    equal(step.enemies .. " " .. s.meter, "4 4", "a Horde player's Charge (a dwarf) through three Alliance pieces and itself: Bloodlust fills by 4")
    s = State()
    s.lust = 5
    Lay(s, Rows({}), {[I(4, 4)] = {"charge", "row"}})
    equal(B.Swap(s, I(4, 4), I(4, 5)).steps[1].points, 160, "doubled under Bloodlust")
    result, step = Lone({[I(4, 4)] = {"sheep"}}, I(4, 4), I(4, 5), nil, {epic = 1})
    equal(step.epics .. " " .. step.points, "9 540", "epic loot from what it clears (every roll epic here: 9 x 60)")
end

-- Bloodlust / Heroism ------------------------------------------------------------------------

do
    local three = {[4] = "HH......", [5] = "..H....."}
    local orcs = {[4] = "OO......", [5] = "..O....."}
    local function Play(s, rows)
        Lay(s, Rows(rows))
        local result = B.Swap(s, I(5, 3), I(4, 3))
        equal(result.ok, true, "the match plays")
        return result
    end
    local s = State("Horde")
    local step = Play(s, three).steps[1]
    equal(step.enemies .. " " .. step.meter .. " " .. s.meter, "3 3 3", "a Horde player: three humans fill Bloodlust by 3")
    step = Play(s, orcs).steps[1]
    equal(step.enemies .. " " .. step.meter, "0 3", "three orcs don't")
    s = State("Alliance")
    step = Play(s, orcs).steps[1]
    equal(step.enemies .. " " .. step.meter, "3 3", "an Alliance player: orcs fill Heroism")
    step = Play(s, three).steps[1]
    equal(step.enemies .. " " .. step.meter, "0 3", "humans don't")
    local hearth = State("Horde")
    Lay(hearth, Rows({[1] = "H......."}), {[I(4, 4)] = {"hearth"}, [I(4, 5)] = {"hearth"}})
    step = B.Swap(hearth, I(4, 4), I(4, 5)).steps[1]
    equal(step.enemies, 1, "a Hearthstone is no race: of the whole board, only the human counts")

    -- Full: double points for 10 seconds, then it fills again.
    s = State("Horde")
    s.meter = 28
    local result = Play(s, three)
    step = result.steps[1]
    equal(tostring(step.lust) .. " " .. result.lustStep .. " " .. s.lust .. " " .. s.meter .. " " .. step.points .. " " .. step.mult,
        "true 1 10 0 30 1", "the 30th: Bloodlust for 10 s, the meter empty; that clear still counts single")
    step = Play(s, orcs).steps[1]
    equal(step.mult .. " " .. step.points, "2 60", "the next clear counts double")
    step = Play(s, three).steps[1]
    equal(step.points .. " " .. s.meter, "60 0", "the meter doesn't fill while it runs")
    equal(tostring(B.Tick(s, 9.9)) .. " " .. tostring(s.lust > 0), "false true", "9.9 s on: still running")
    equal(tostring(B.Tick(s, .2)) .. " " .. s.lust, "true 0", "10 s: over")
    equal(B.Tick(s, 1), false, "and stays over")
    step = Play(s, three).steps[1]
    equal(step.points .. " " .. s.meter, "30 3", "single points again, and the meter fills")
    equal(B.Tick(State(), 5), false, "no time runs without it")

    -- Started by a clear, the chain after it counts double. (Every new piece
    -- an orc: the top row matches again and again until new pieces calm down.)
    s = State("Horde", {kind = 1})
    s.meter = 27
    Lay(s, Rows({[4] = "HH......", [5] = "..H....."}))
    result = B.Swap(s, I(5, 3), I(4, 3))
    equal(result.steps[1].lust and result.steps[1].mult .. " " .. result.steps[2].mult .. " " .. result.steps[2].points, "1 2 60",
        "the chain after Bloodlust starts counts double")
end

-- Epic loot -------------------------------------------------------------------------------------

do
    local rolled = 0
    local s = State("Horde", {epic = function(low, high) rolled = rolled + 1; return rolled == 2 and 1 or high end})
    Lay(s, Rows({[4] = "OO......", [5] = "..O....."}))
    local step = B.Swap(s, I(5, 3), I(4, 3)).steps[1]
    local epic = step.cleared[2]
    equal(step.epics .. " " .. tostring(epic.epic) .. " " .. step.points, "1 true 80", "an epic piece: 50 more")
    local listed = false
    for _, icon in ipairs(B.EPIC_LOOT) do if icon == epic.loot then listed = true end end
    equal(listed, true, "it bursts into epic loot")
    listed = false
    for _, icon in ipairs(B.LOOT) do if icon == step.cleared[1].loot then listed = true end end
    equal(listed and not step.cleared[1].epic, true, "the others into loot")
    rolled = 0
    s.lust = 5
    Lay(s, Rows({[4] = "OO......", [5] = "..O....."}))
    step = B.Swap(s, I(5, 3), I(4, 3)).steps[1]
    equal(step.points, 160, "doubled under Bloodlust")
end

-- Chains always end ------------------------------------------------------------------------

do
    local s = State("Horde", {kind = 1})
    Lay(s, Rows({[4] = "OO......", [5] = "..O....."}))
    local result = B.Swap(s, I(5, 3), I(4, 3))
    equal(#result.steps > 1 and #result.steps <= B.CALM_AFTER, true, "every new piece an orc: a chain, ended by calm new pieces (" .. #result.steps .. ")")
    equal(Matches(s.board) .. " " .. tostring(AnyMove(s.board)), "0 true", "no match left standing, a move to make")
    local calm = B.CALM_AFTER
    B.CALM_AFTER = 1000
    s = State("Horde", {kind = 1})
    Lay(s, Rows({[4] = "OO......", [5] = "..O....."}))
    result = B.Swap(s, I(5, 3), I(4, 3))
    B.CALM_AFTER = calm
    equal(#result.steps .. " " .. tostring(result.settled), B.STEP_LIMIT .. " true", "never calm: it stops at the limit and lays the board out again")
    equal(Matches(s.board) .. " " .. tostring(AnyMove(s.board)), "0 true", "with no match and a move")
    equal(s.board[I(4, 3)] ~= nil and #s.board, 64, "a full board")
end

-- No move left: shuffled -------------------------------------------------------------------

do
    local s = State()
    local rows = {}
    local letters = {"O", "T", "U", "H", "D", "N"}
    for r = 1, 8 do
        local row = {}
        for c = 1, 8 do row[c] = letters[((c - 1) + 3 * ((r - 1) % 2)) % 6 + 1] end
        rows[r] = table.concat(row)
    end
    Lay(s, rows)
    equal(tostring(B.FindMove(s.board)) .. " " .. tostring(AnyMove(s.board)), "nil false", "a board with no move")
    equal(B.Unstick(s), true, "is shuffled")
    equal(Matches(s.board) .. " " .. tostring(AnyMove(s.board)), "0 true", "into one with no match and a move")
    equal(B.Unstick(s), false, "a board with a move isn't")
    -- A special on it is a move (swapped with the piece beside it, it fires): never shuffled for having none.
    Lay(s, rows, {[I(3, 3)] = {"charge", "col"}, [I(6, 6)] = {"sheep"}})
    local fa, fb = B.FindMove(s.board)
    equal(tostring(fa == I(3, 3) and B.Adjacent(fa, fb)) .. " " .. tostring(B.Unstick(s)), "true false",
        "the same board with a Charge and a Sheep: a move (the Charge and a piece beside it), not shuffled")
    B.Arrange(s, true)
    equal(s.board[I(3, 3)].special .. " " .. s.board[I(3, 3)].dir .. " " .. s.board[I(6, 6)].special, "charge col sheep",
        "laid out again (as after a chain too long): its specials kept in place")
    local hearth = s.board[I(1, 1)]
    s.board[I(1, 1)] = {id = 9999, special = "hearth"}
    hearth = s.board[I(1, 1)]
    B.Arrange(s, true)
    equal(s.board[I(1, 1)], hearth, "a Hearthstone stays as it is")

    -- After a move.
    s = State()
    Lay(s, Rows({[4] = "OO......", [5] = "..O....."}))
    local real, calls = B.FindMove, 0
    B.FindMove = function(board) calls = calls + 1; if calls == 1 then return nil end; return real(board) end
    local result = B.Swap(s, I(5, 3), I(4, 3))
    B.FindMove = real
    equal(tostring(result.reshuffled) .. " " .. Matches(s.board) .. " " .. tostring(AnyMove(s.board)), "true 0 true",
        "a move that leaves none: the board is shuffled")
end

-- Keeping a board ---------------------------------------------------------------------------------

do
    local s = State("Alliance")
    Lay(s, Rows({[1] = "H.......", [3] = "..O....."}), {[I(2, 2)] = {"charge", "row"}, [I(5, 5)] = {"hearth"}, [I(7, 1)] = {"flyer"}})
    for i = 1, 64 do if not B.RACE[s.board[i].kind] and s.board[i].special ~= "hearth" then s.board[i].kind = B.KINDS[(i % 6) + 1] end end
    -- (the "." pieces made real: a pattern that has no match)
    local pattern = {}
    for i = 1, 64 do
        local r, c = B.Cell(i)
        local p = s.board[i]
        if p.special ~= "hearth" then p.kind = B.Pattern(r, c) end
        pattern[i] = p
    end
    equal(#B.FindGroups(s.board), 0, "a board to keep")
    s.score, s.meter = 1234, 17
    local kept = {}
    B.Save(s, kept)
    equal(type(kept.board) == "string" and kept.version .. " " .. kept.score .. " " .. kept.meter, "1 1234 17", "kept as one string, with the score and meter")
    equal(kept.board:find("/hearth", 1, true) ~= nil and kept.board:find("/charge/row", 1, true) ~= nil, true, "specials in it")
    local back = State("Alliance")
    equal(B.Load(back, kept), true, "and read back")
    local same = true
    for i = 1, 64 do
        local a, b = s.board[i], back.board[i]
        if a.kind ~= b.kind or a.special ~= b.special or a.dir ~= b.dir then same = false end
    end
    equal(same and back.score .. " " .. back.meter .. " " .. back.lust, "1234 17 0", "every piece, the score and the meter as they were")
    local function Refused(change, label)
        local copy = {}
        for k, v in pairs(kept) do copy[k] = v end
        change(copy)
        local fresh = State()
        local board = fresh.board
        equal(B.Load(fresh, copy) == false and fresh.board == board, true, label .. ": refused, the board left alone")
    end
    Refused(function(t) t.version = 2 end, "another version")
    Refused(function(t) t.board = t.board:gsub("^%a+", "gnomeX") end, "a race that isn't one")
    Refused(function(t) t.board = t.board:gsub(",[^,]*$", "") end, "63 pieces")
    Refused(function(t) t.board = t.board .. ",orc" end, "65")
    Refused(function(t) t.board = t.board:gsub("/charge/row", "/charge") end, "a Charge with no line")
    Refused(function(t) t.board = t.board:gsub("/hearth", "orc/hearth") end, "a Hearthstone with a race")
    Refused(function(t) t.board = t.board:gsub("/charge/row", "/frog") end, "an odd special")
    Refused(function(t) t.board = 5 end, "not a string")
    local first = kept.board:match("^(%a+)")
    Refused(function(t) t.board = t.board:gsub("^(%a+),(%a+),(%a+)", first .. "," .. first .. "," .. first) end, "a match standing")
    equal(B.Load(State(), nil) or B.Load(State(), "x"), false, "nothing kept")
    kept.score, kept.meter = -5, 99
    back = State()
    B.Load(back, kept)
    equal(back.score .. " " .. back.meter, "0 29", "an odd score is none, a meter past full just under it")
end

-- Many moves --------------------------------------------------------------------------------------

do
    local s = B.New(Lcg(42), "Horde")
    local pieces, epics, total, broken = 0, 0, 0, 0
    for _ = 1, 400 do
        local a, b = B.FindMove(s.board)
        local result = B.Swap(s, a, b)
        if not result.ok then broken = broken + 1 end
        for _, step in ipairs(result.steps or {}) do
            pieces = pieces + #step.cleared
            epics = epics + step.epics
            total = total + step.points
        end
        if Matches(s.board) > 0 or not AnyMove(s.board) or #s.board ~= 64 then broken = broken + 1 end
        B.Tick(s, 1)
    end
    equal(broken, 0, "400 moves: each plays, and leaves no match standing, a move, a full board")
    equal(total, s.score, "the score is what the clears scored")
    equal(epics / pieces > .02 and epics / pieces < .065, true, "about one piece in 25 is epic (" .. epics .. " of " .. pieces .. ")")
end

-- Hints ---------------------------------------------------------------------------------------------

do
    -- A four (a Charge) beats a three.
    local s = State()
    Lay(s, Rows({[2] = "OO.O....", [3] = "..O.....", [6] = "HH......", [7] = "..H....."}))
    local before = B.Copy(s.board)
    equal(B.MoveValue(s.board, I(7, 3), I(6, 3)) .. " " .. B.MoveValue(s.board, I(2, 3), I(3, 3)), "3 8",
        "a three is worth its 3 pieces; a four its 4 and the Charge it makes")
    equal(B.MoveValue(s.board, I(5, 5), I(5, 6)) == nil and B.MoveValue(s.board, I(1, 1), I(1, 3)) == nil, true, "no match or not side by side: no move")
    local a, b = B.Hint(s.board)
    equal(a .. " " .. b, I(2, 3) .. " " .. I(3, 3), "the hint: the four")
    local same = true
    for i = 1, 64 do if s.board[i] ~= before[i] then same = false end end
    equal(same, true, "looking leaves the board as it was")
    equal(B.Swap(s, a, b).steps[1].made[1].piece.special, "charge", "and it plays")

    -- A Hearthstone beside a human beats any match; two specials beat a match.
    s = State()
    Lay(s, Rows({[1] = "H.......", [3] = "...H....", [5] = "OO......", [6] = "..O.....", [8] = "......H."}), {[I(8, 8)] = {"hearth"}})
    a, b = B.Hint(s.board)
    equal(a .. " " .. b .. " " .. B.MoveValue(s.board, a, b), I(8, 7) .. " " .. I(8, 8) .. " 103", "a Hearthstone beside one of three humans: the hint")
    s = State()
    Lay(s, Rows({[5] = "OO......", [6] = "..O....."}), {[I(2, 2)] = {"sheep"}, [I(2, 3)] = {"flyer"}})
    a, b = B.Hint(s.board)
    equal(a .. " " .. b, I(2, 2) .. " " .. I(2, 3), "two specials side by side: the hint")

    -- No move: no hint.
    s = State()
    local rows, letters = {}, {"O", "T", "U", "H", "D", "N"}
    for r = 1, 8 do
        local row = {}
        for c = 1, 8 do row[c] = letters[((c - 1) + 3 * ((r - 1) % 2)) % 6 + 1] end
        rows[r] = table.concat(row)
    end
    Lay(s, rows)
    equal(B.FindMove(s.board) == nil and B.Hint(s.board) == nil, true, "a board with no move has no hint")

    -- A special beside any piece is a move, and the hint weighs what it clears.
    Lay(s, rows, {[I(6, 6)] = {"sheep"}})
    local ha, hb = B.Hint(s.board)
    equal((ha == I(6, 6) or hb == I(6, 6)) and B.Adjacent(ha, hb) and B.MoveValue(s.board, ha, hb), 9,
        "one Sheep on a board with no match to make: the hint is the Sheep, worth its 3x3")
    equal(B.Swap(s, ha, hb).ok and s.moves, 1, "and it plays as a move")
    Lay(s, rows, {[I(8, 8)] = {"flyer"}})
    equal(B.FindMove(s.board) ~= nil and B.MoveValue(s.board, I(8, 8), I(8, 7)), 2, "a flyer in the corner: a move, worth itself and the piece it hits")
    s = State()
    Lay(s, Rows({[2] = "OO......", [3] = "..O....."}), {[I(6, 4)] = {"charge", "row"}})
    equal(B.MoveValue(s.board, I(6, 4), I(6, 5)) .. " " .. B.MoveValue(s.board, I(6, 4), I(7, 4)) .. " " .. B.MoveValue(s.board, I(3, 3), I(2, 3)),
        "8 8 3", "a Charge's line is worth its 8 pieces, a three 3")
    ha, hb = B.Hint(s.board)
    equal(ha == I(6, 4) or hb == I(6, 4), true, "the hint: fire the Charge")
    s = State()
    Lay(s, Rows({[4] = "OO......", [5] = "..O....."}), {[I(4, 3)] = {"charge", "col"}})
    equal(B.MoveValue(s.board, I(5, 3), I(4, 3)) .. " " .. B.MoveValue(s.board, I(4, 3), I(5, 3)), "10 10",
        "a Charge's column with the three it lines up: 10 pieces, the one they share counted once (either way round)")
    local was = B.Copy(s.board)
    B.Hint(s.board)
    local same = true
    for i = 1, 64 do if s.board[i] ~= was[i] then same = false end end
    equal(same, true, "looking at specials leaves the board as it was")

    -- Many boards: a hint whenever there's a move, always one that plays, never worse than the first move found.
    s = B.New(Lcg(99), "Alliance")
    local refused, missed, worse = 0, 0, 0
    for _ = 1, 300 do
        local ha, hb = B.Hint(s.board)
        local fa, fb = B.FindMove(s.board)
        if (ha == nil) ~= (fa == nil) then missed = missed + 1 end
        if ha and B.MoveValue(s.board, ha, hb) < B.MoveValue(s.board, fa, fb) then worse = worse + 1 end
        if not (ha and B.Swap(s, ha, hb).ok) then refused = refused + 1 end
        B.Tick(s, 1)
    end
    equal(missed .. " " .. refused .. " " .. worse, "0 0 0", "300 moves played by hints: each found, each played, each the best")
    equal(B.HINT_AFTER .. " " .. B.HINT_COOLDOWN, "15 30", "a hint shows by itself after 15 seconds with no move, 30 seconds between hints")
end

-- The game in the window -------------------------------------------------------------------------
-- (Free play here: the old endless board, kept per character. The levels,
-- the map, the cards and the power-ups: Tools/TestBlastCampaign.lua.)

-- A kept board: the fixed layout, whose one move swaps (2, 2) onto (2, 1),
-- lining up three orcs down column 1.
local function Kept(faction)
    local s = B.New(Script(), faction or "Horde")
    local tries = B.TRIES
    B.TRIES = 0
    B.Arrange(s, false)
    B.TRIES = tries
    local kept = {}
    B.Save(s, kept)
    return {miniGames = {games = {blast = kept}}}, kept.board
end
local function Cells() return Game().cells end
local function Busy() return Game().busy end
local function Settle() for _ = 1, 400 do if not Busy() then return end; Tick(.05) end end
-- The map (what /era blast opens), then its footer's Free play.
local function OpenFree()
    MG:Open("blast", "command")
    Game().buttons.free:Click()
    return Game()
end
local function Colour(c) return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3]) end

do
    local char, board = Kept()
    Session({char = char})
    equal(MG:Toggle("blast"), true, "/era blast opens Azeroth Blast")
    local shell = Shell()
    equal(Showing() and MG.current, "blast", "it shows")
    equal(shell.title.text, "Azeroth |cffc79c6eBlast|r", "Azeroth Blast, Blast in your class colour")
    equal(MG:Title("blast"), "Azeroth Blast", "its name for /era")
    local game = Game()
    equal(game.screen .. " | " .. shell.where.text, "map | Pick a level on the map.", "/era blast: the level map")
    equal(game.buttons.free.shown and game.buttons.free.label.text, "Free play", "its footer: Free play")
    game.buttons.free:Click()
    equal(game.screen .. " | " .. shell.where.text, "free | Match three or more of a race.", "Free play: the old endless board")
    equal(shell.note.text, "Click a piece, then one next to it to swap.", "the footer says how")
    equal(shell.score.text .. " | " .. shell.best.text, "Score 0 | Best 0", "score and best")
    equal(#game.cells, 64, "64 cells")
    local V = B.VIEW
    local size = 8 * V.CELL
    equal(game.board.w .. "x" .. game.board.h .. " " .. tostring(game.board.sizedFirst) .. " " .. tostring(game.board.clips), size .. "x" .. size .. " true true",
        "an 8x8 board, sized first, new pieces shown only on it")
    local tl, br = game.board.points[1], game.board.points[2]
    equal(#game.board.points .. " " .. tl[1] .. " " .. br[1] .. " " .. tostring(tl[2] == game.play and br[2] == game.play) .. " "
        .. ("%gx%g"):format(br[4] - tl[4], tl[5] - br[5]), "2 TOPLEFT BOTTOMRIGHT true " .. size .. "x" .. size,
        "clipping, so pinned by two corners (Forever may draw nothing of one placed by one), its own size apart")
    equal(("%g %g %g %g"):format(V.CELL, V.LEFT, V.TOP, V.BOTTOM), "45 26 78 438", "45 px cells, the board centred under the HUD")
    local sized = true
    for _, cell in ipairs(game.cells) do if not (cell.sizedFirst and cell.w == V.CELL and cell.art.sizedFirst) then sized = false end end
    equal(sized, true, "every cell sized before it's placed")
    equal(game.holder.w .. "x" .. game.holder.h, MG.CONTENT_W .. "x" .. MG.CONTENT_H, "in the core's holder")
    local orc = game.cells[I(1, 1)].art
    equal(orc.face.texture .. " " .. tostring(orc.face.mask ~= nil) .. " " .. orc.face.w, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc true 33",
        "an orc: the game's orc portrait, cut round, 33 px")
    local green = MG.BlastView.PAINT.race.orc
    equal(Colour(orc.plate.vertex) .. " " .. orc.plate.w .. " " .. tostring(orc.plate.shown), Colour(green) .. " 41 true", "on a 41 px plate in the orcs' green")
    equal(Colour(orc.pip.vertex) .. " " .. tostring(orc.pip.shown) .. " " .. orc.pip.w, "0.860,0.160,0.100 true 12", "a Horde red pip")
    local human = game.cells[I(1, 4)].art
    equal(human.face.texture .. " " .. Colour(human.pip.vertex), "Interface\\CharacterFrame\\TemporaryPortrait-Male-Human 0.180,0.440,1.000",
        "a human: an Alliance blue pip")
    equal(Colour(human.plate.vertex) == Colour(orc.plate.vertex), false, "each race on its own colour")
    local hover = game.cells[1].hover
    equal(hover.colour[4] .. " " .. hover.blend .. " " .. hover.w .. " " .. hover.layer, "0.18 ADD " .. V.TILE .. " HIGHLIGHT", "the pointer lights a cell")
    equal(orc.glow.shown or orc.badge.shown or orc.streak.shown, false, "a plain piece: no glow, no badge")
    local tile, next = game.cells[1].tile, game.cells[2].tile
    equal(tile.texture .. " " .. tile.wrapH .. " " .. tostring(tile.vertex[1] ~= next.vertex[1]) .. " " .. tostring(tile.w == V.TILE),
        "Interface\\Garrison\\ClassHallBackground REPEAT true true", "stone tiles, a shade apart on alternate cells, a fine gap round each")
    equal(game.rim.w .. " " .. Colour(game.rim.colour), (size + 6) .. " " .. Colour({.66, .48, .28}), "the board in a rim of the Horde's bronze, flat")
    equal(game.meter.icon.texture .. " " .. game.meter.label.text .. " " .. tostring(game.meter.fill.shown), "Interface\\Icons\\Spell_Nature_BloodLust 0/30 false",
        "a Horde player's meter: Bloodlust, empty")
    equal(game.meter.label.font[3] .. " " .. tostring(game.meter.icon.desaturated), "OUTLINE true", "its count outlined, the icon grey until it's full")
    equal(game.button.label.text .. " | " .. game.hintButton.label.text .. " | " .. game.hintButton.lastPoint[2].label.text, "New board | Hint | New board",
        "a Hint button beside New board")
    local wide = 0
    for _, id in ipairs({"new", "hint", "map"}) do wide = wide + game.buttons[id].w + 6 end
    equal(game.button.parent == game.bar and game.mapButton.shown and wide - 6 <= MG.BAR_W, true, "New board, Hint and Map in the game's part of the footer")
    local unsized = 0
    local function Under(f, root) while f do if f == root then return true end; f = f.parent end; return false end
    for _, f in ipairs(frames) do
        if (f.kind == "Frame" or f.kind == "Button") and (Under(f, game.holder) or Under(f, game.bar)) and not f.sizedFirst then unsized = unsized + 1 end
    end
    equal(unsized, 0, "every frame of the game sized before it's placed")
    equal(game.sky.level > Shell().edge.level and game.sky.level < Shell().fx.level and game.sky.mouse == nil, true,
        "flying icons over the play area's edge, under the effects, taking no clicks")
    equal(game.cells[1].clicks[1] .. " " .. game.cells[1].clicks[2], "LeftButtonDown RightButtonDown", "pieces take the press itself")
    for _, f in ipairs(frames) do
        if f.calls.EnableKeyboard or f.calls.SetPropagateKeyboardInput then error("a frame took the keyboard") end
    end
    equal(EraUIClassicCharDB.miniGames.games.blast.board, board, "the kept board is the one shown")

    -- Picking.
    local ring = game.picker.ring
    sounds = {}
    game.cells[I(5, 5)]:Click("LeftButton")
    equal(game.selected .. " " .. tostring(ring.shown and game.picker.glow.shown) .. " " .. tostring(ring.lastPoint[2] == game.cells[I(5, 5)].art),
        I(5, 5) .. " true true", "a click picks a piece: a pale ring round it")
    equal(ring.texture .. " " .. ring.blend .. " " .. tostring(sounds[1]) .. " " .. game.cells[I(5, 5)].scale, "Interface\\Cooldown\\ping4 ADD 856:SFX 1.1",
        "a ring of light, the piece a little bigger, a soft click (no gem clink)")
    equal(table.concat(ring.vertex, ",", 1, 3) .. " " .. table.concat(game.picker.glow.vertex, ",", 1, 3), "1,0.97,0.85 1,0.84,0.35",
        "pale, in a gold glow")
    Tick(.1)
    local was = ring.alpha
    Tick(.1)
    equal(ring.alpha ~= was and ring.alpha >= .55 and ring.alpha <= 1, true, "it pulses")
    equal(ring.w >= B.VIEW.PICK and ring.w <= B.VIEW.PICK + 5 and B.VIEW.PICK > B.VIEW.PLATE + 10 and game.picker.glow.alpha >= .3, true,
        "well outside the piece's plate, its glow plain to see")
    game.cells[I(5, 5)]:Click("LeftButton")
    equal(tostring(game.selected) .. " " .. tostring(ring.shown) .. " " .. game.cells[I(5, 5)].scale, "nil false 1", "again: let go")
    game.cells[I(5, 5)]:Click("LeftButton")
    game.cells[I(7, 7)]:Click("LeftButton")
    equal(game.selected .. " " .. tostring(ring.lastPoint[2] == game.cells[I(7, 7)].art), I(7, 7) .. " true", "a piece not next to it: that one picked instead")
    game.cells[I(1, 1)]:Click("RightButton")
    equal(game.selected, nil, "a right click lets go")

    -- A swap that matches nothing slides back, with a boing.
    sounds = {}
    game.cells[I(8, 7)]:Click("LeftButton")
    game.cells[I(8, 8)]:Click("LeftButton")
    equal(Busy(), true, "a swap plays out")
    Tick(.1)
    equal(game.cells[I(8, 7)].dx > 0 and game.cells[I(8, 8)].dx < 0, true, "the two slide towards each other")
    equal(table.concat(sounds, " "), "856:SFX 219930:SFX", "with a soft whoosh")
    game.cells[I(2, 2)]:Click("LeftButton")
    equal(game.selected, nil, "no clicks while it plays")
    Tick(.1)
    equal(sounds[3] .. " " .. #MG.FX.pulses, "91242:SFX 2", "where they meet: a boing and a red flash on both")
    Settle()
    equal(shell.note.text .. " " .. game.cells[I(8, 7)].dx .. " " .. game.state.score, "No match there, so they swap back. 0 0", "no match: back where they were")
    equal(EraUIClassicCharDB.miniGames.games.blast.board, board, "nothing changed")

    -- The move.
    local orcs = game.state.board[I(2, 2)]
    sounds = {}
    game.cells[I(2, 2)]:Click("LeftButton")
    game.cells[I(2, 1)]:Click("LeftButton")
    equal(Busy() and game.state.score > 0, true, "the move is made at once, then played out")
    equal(shell.score.text, "Score 0", "the score counts up as each clear shows")
    Tick(.1)
    equal(game.cells[I(2, 2)].piece == orcs and game.cells[I(2, 2)].dx < 0 and game.cells[I(2, 1)].dx > 0, true,
        "the orc slides onto its new place, the other the other way")
    Tick(.1)
    local first = game.cells[I(1, 1)]
    equal(first.art.shown and first.scale > 1.1 and first.art.flash.shown and first.art.flash.alpha > .3, true, "the orcs flash and swell")
    local flying, loot = 0, 0
    for _, fly in ipairs(Spied("Tween")) do
        if fly.data and fly.data.icon and fly.data.shown then
            flying = flying + 1
            for _, icon in ipairs(B.LOOT) do if icon == fly.data.icon.texture then loot = loot + 1 end end
        end
    end
    equal(flying > 0 and loot == flying and flying <= B.VIEW.LOOT_FLY, true, "their loot pops out and flies to the score (" .. flying .. ")")
    local inGreen = 0
    for _, spark in ipairs(MG.FX.sparks) do if spark.vertex and spark.vertex[1] == green[1] and spark.vertex[2] == green[2] then inGreen = inGreen + 1 end end
    equal(inGreen >= 6 and MG.FX.sparks[1].texture, 166970, "sparks in the orcs' green")
    local float = MG.FX.floats[1]
    equal(float and float.shown and float.text.text:match("^%+%d+$") ~= nil, true, "the points rise from the clear")
    equal(shell.scoreGoal == game.shownScore and game.shownScore >= 30 and game.shownScore <= game.state.score, true,
        "the header counts up to the score as of this clear")
    equal(Heard("140556:SFX") and Heard("219930:SFX") and not Heard("206515:SFX"), true, "a swap whoosh, then a balloon pop (a chain's sound from its second clear)")
    Tick(.15)
    equal(first.scale < 1 and first.alpha < .6, true, "then shrink away")
    Settle()
    Tick(1)
    equal(shell.score.text, "Score " .. game.state.score, "played out: the header has the score")
    local calm = true
    for _, cell in ipairs(game.cells) do
        if cell.dx ~= 0 or cell.dy ~= 0 or cell.scale ~= 1 or cell.art.flash.shown or cell.alpha ~= 1
            or cell.piece ~= game.state.board[cell.index] then calm = false end
    end
    equal(calm, true, "every cell back in place, whole, showing the board")
    equal(#game.freeFlyers .. " " .. #game.freeStreaks .. " " .. #game.freeSwirls, B.VIEW.FLYERS .. " " .. B.VIEW.STREAKS .. " " .. B.VIEW.SWIRLS,
        "every flying icon back in its pool")
    equal(Heard("120:SFX") and not Heard("865:SFX"), true, "the first loot to arrive: a coin (no money window's clink)")
    local saved = EraUIClassicCharDB.miniGames.games.blast
    equal(saved.board ~= board and saved.score, game.state.score, "the board and its score kept")
    equal(EraUIClassicCharDB.miniGames.best == nil, true, "a best is kept once the window closes")

    -- Closed mid-move: it ends there, the score a best.
    local a, b = B.FindMove(game.state.board)
    game.cells[a]:Click("LeftButton")
    game.cells[b]:Click("LeftButton")
    Tick(.1)
    shell.close:Click()
    equal(Showing() or Busy(), false, "closed mid-move: the move ends")
    calm = true
    for _, cell in ipairs(game.cells) do if cell.dx ~= 0 or cell.dy ~= 0 or cell.scale ~= 1 or cell.art.flash.shown then calm = false end end
    equal(calm, true, "nothing left half drawn")
    equal(#game.freeFlyers .. " " .. #MG.FX.sparks .. " " .. #MG.FX.floats, B.VIEW.FLYERS .. " 0 0", "every effect gone with it")
    equal(EraUIClassicCharDB.miniGames.best.blast .. " " .. EraUIDB.miniGameBest.blast, game.state.score .. " " .. game.state.score,
        "its score kept as this character's best and the account's")
    MG:Open("blast", "switch")
    equal(game.screen .. " " .. shell.best.text, "free Best " .. game.state.score, "opened again: Free play, the header shows the best")

    -- New board.
    local old, oldBoard = game.state.score, saved.board
    sounds = {}
    game.button:Click()
    equal(game.state.score .. " " .. shell.score.text, "0 Score 0", "New board: a fresh start")
    equal(EraUIClassicCharDB.miniGames.games.blast.board ~= oldBoard and EraUIClassicCharDB.miniGames.games.blast.score, 0, "kept at once")
    equal(sounds[1], "206515:SFX", "with a chime")
    Settle()
    equal(shell.note.text, "A new board.", "the footer says so")
    equal(Matches(game.state.board) .. " " .. tostring(AnyMove(game.state.board)), "0 true", "no match on it, a move to make")
    equal(EraUIClassicCharDB.miniGames.best.blast, old, "the old score still the best")

    -- Dragging one piece onto the next.
    a, b = B.FindMove(game.state.board)
    game.cells[a]:Click("LeftButton")
    world.mouse = true
    game.cells[b]:Fire("OnEnter")
    world.mouse = false
    equal(Busy() and game.state.moves, 1, "pressed on a piece and dragged onto the next: swapped")
    Settle()
    game.cells[I(4, 4)]:Click("LeftButton")
    game.cells[I(4, 5)]:Fire("OnEnter")
    equal(Busy() or game.selected, I(4, 4), "moving over the next with the button up: no swap")
    -- Map: back to the levels.
    game.mapButton:Click()
    equal(game.screen .. " " .. tostring(game.play.shown) .. " " .. tostring(game.map:IsShown()), "map false true", "Map: the level map, the board hidden")
end

-- The Alliance's names and icons; a missing portrait; Heroism round the board's edge.
do
    local char = Kept("Alliance")
    Session({char = char, faction = "Alliance", missing = {["Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc"] = true}})
    local game = OpenFree()
    equal(game.meter.icon.texture .. " " .. game.meter.label.text, "Interface\\Icons\\Ability_Shaman_Heroism 0/30", "an Alliance player's meter: Heroism")
    local orc = game.cells[I(1, 1)].art.face
    equal(tostring(orc.atlas) .. " " .. orc.how, "raceicon128-orc-male atlas", "no orc portrait: the orc race icon")
    equal(game:Badge("flyer") .. " " .. game:FlyerName(), "Interface\\Icons\\Ability_Mount_Gryphon_01 Gryphon", "the Alliance's flyer: a Gryphon")
    local metal = Colour(game.rim.colour)
    equal(metal, Colour({.86, .68, .27}), "the Alliance's gold rim")

    -- Orcs fill Heroism; full, it shows.
    game.state.meter = 29
    game.cells[I(2, 2)]:Click("LeftButton")
    game.cells[I(2, 1)]:Click("LeftButton")
    equal(game.state.lust > 0 and game.meter.label.text, "29/30", "Heroism waits for its clear to show")
    equal(game.glows[1].shown or game.runners[1].shown, false, "the edge not lit yet")
    Tick(.1)
    equal(game.lustPending and game.state.lust, B.LUST_TIME, "its 10 s don't run down while it waits")
    Tick(.1)
    equal(Shell().note.text .. " | " .. game.meter.label.text, "Heroism! Double points for 10 seconds. | 10s", "then it's on")
    equal(game.meter.fill.shown and game.meter.icon.desaturated, false, "the meter lit")
    local banner = MG.FX.banner
    equal(banner.shown and banner.text.text .. " | " .. banner.sub.text, "Heroism! | Double points for 10 seconds", "a big Heroism banner")
    equal(table.concat(banner.glow.vertex, ",", 1, 3), "0,0,0", "with no blue glow laid over the board behind it")
    equal(Heard("file 569013:SFX") and Heard("344561:SFX"), true, "Heroism's cast and the drums")
    local lit, blue, inside = 0, 0, 0
    local V = B.VIEW
    for _, glow in ipairs(game.glows) do
        if glow.shown and glow.blend == "ADD" then lit = lit + 1 end
        if glow.colour[3] > glow.colour[1] then blue = blue + 1 end
        local p = glow.points[#glow.points]
        local x1, y1 = p[4], -p[5]
        local x2, y2 = x1 + glow.w, y1 + glow.h
        if x1 < V.LEFT + V.BOARD and x2 > V.LEFT and y1 < V.BOTTOM and y2 > V.TOP then inside = inside + 1 end
    end
    equal(lit .. " " .. blue .. " " .. inside, "8 8 0", "eight blue bands of light round the board, none of them over it")
    local runners = 0
    for _, spark in ipairs(game.runners) do if spark.shown and spark.blend == "ADD" then runners = runners + 1 end end
    equal(runners, 4, "four sparks running round it")
    equal(Colour(game.rim.colour), metal, "the rim keeps its gold")
    equal(#Spied("Burst", function(call) return call.at == game.meter.icon end), 1, "sparks from the meter's icon")
    Settle()
    equal(Shell().note.text, "Heroism! Double points for 10 seconds.", "still said once the move is played")
    MG:Close("hand")
    equal(MG.held.drums, nil, "closed while it runs: the drums stop")
    local heard = #sounds
    MG:Open("blast", "switch")
    equal(#sounds .. " " .. sounds[#sounds] .. " " .. tostring(MG.held.drums ~= nil), (heard + 1) .. " 344561:SFX true",
        "opened again while it still runs: the drums come back")
    MG:Open("blast", "switch")
    equal(#sounds, heard + 1, "never twice at once")
    local drums
    for index, sound in ipairs(sounds) do if sound == "344561:SFX" then drums = index end end
    Tick(10.5)
    equal(Shell().note.text .. " | " .. game.meter.label.text, "Heroism is over. Fill the meter again. | 0/30", "10 s on, over")
    equal(game.meter.icon.desaturated, true, "the icon greyed again")
    local stopped = false
    for _, handle in ipairs(world.stopped) do if handle == drums then stopped = true end end
    equal(stopped and not game.glows[1].shown and not game.runners[1].shown and Colour(game.rim.colour) == metal, true,
        "the drums stop, the glow goes, the rim as it was")
    local quiet = #sounds
    game:LustOn()
    local drummed = false
    for index = quiet + 1, #sounds do if sounds[index] == "344561:SFX" then drummed = true end end
    equal(drummed, false, "a start shown after its time ran out: no drums left playing")
    game:LustOver()

    Session({faction = "Horde"})
    OpenFree()
    equal(Game():Badge("flyer") .. " " .. Game():FlyerName() .. " " .. Game():Badge("charge") .. " " .. Game():Badge("sheep"),
        "Interface\\Icons\\Ability_Mount_Wyvern_01 Wind Rider Interface\\Icons\\Ability_Warrior_Charge Interface\\Icons\\Spell_Nature_Polymorph",
        "the Horde's: a Wind Rider; Charge and Explosive Sheep icons")
    equal(Game():Badge("hearth"), nil, "a Hearthstone shows its own icon whole")
    -- What the footer says after a move.
    local function Said(result)
        result.steps = result.steps or {}
        return Game():MoveNote(result)
    end
    local function Making(special) return {steps = {{made = {{piece = {special = special}}}, epics = 0}}} end
    equal(Said({reshuffled = true}), "No moves left, so the board was shuffled.", "shuffled")
    equal(Said({reshuffled = true, lustStep = 1}), "Bloodlust! Double points for 10 seconds.", "Bloodlust before the shuffle")
    equal(Said({combo = "hearth", hearthKind = "nightelf"}), "Hearthstone: every night elf cleared!", "a Hearthstone used")
    equal(Said({combo = "charges"}) .. " | " .. Said({combo = "sheeps"}) .. " | " .. Said({combo = "chargesheep"}) .. " | " .. Said({combo = "hearths"}),
        "Two Charges: a row and a column! | Two Sheep: a huge blast! | Charge and Sheep: a cross three wide! | Two Hearthstones: the whole board!",
        "each combo")
    equal(Said({combo = "flyer"}), "Wind Rider combo: both fire!", "a flyer combo")
    equal(Said(Making("charge")) .. " | " .. Said(Making("sheep")) .. " | " .. Said(Making("flyer")) .. " | " .. Said(Making("hearth")),
        "Charge made: swap it with any piece to clear its line. | Explosive Sheep made: swap with any piece to blast round it. | "
        .. "Wind Rider made: swap with any piece to clear one elsewhere. | Hearthstone made: swap it with any piece to clear that race.",
        "each special made says how to use it: swapped with any piece")
    local plain = {made = {}, epics = 0}
    equal(Said({steps = {plain, plain, plain}}) .. " | " .. Said({steps = {{made = {}, epics = 1}}}) .. " | " .. Said({steps = {plain}}),
        "A chain of 3! | Epic loot! 50 more for each. | ", "a chain, epic loot, else nothing")
    equal(Said({lone = I(4, 5), steps = {plain}}), "", "a special fired on its own: no words (its effects say it)")
    local long = 0
    local lines = {Said({combo = "chargesheep"}), "Heroism is over. Fill the meter again.", MG.BlastView.NOTES.flyer:format("Gryphon")}
    for _, special in ipairs({"charge", "sheep", "flyer", "hearth"}) do lines[#lines + 1] = Said(Making(special)) end
    for _, words in ipairs(lines) do
        if #words > 60 or words:find("%-%-") or words:find("\226\128\148", 1, true) then long = long + 1 end
    end
    equal(long, 0, "short enough for two footer lines, no dashes")
    local cell = Game().cells[1]
    local art = cell.art
    Game():Dress(cell, {id = -1, special = "hearth"})
    equal(art.full.shown and art.full.texture == "Interface\\Icons\\INV_Misc_Rune_01" and not art.face.shown and art.full.mask == art.face.mask, true,
        "the Hearthstone's icon, cut round as a face is, no face")
    equal(tostring(art.pip.shown) .. " " .. tostring(art.badge.shown) .. " " .. tostring(art.glow.shown) .. " " .. table.concat(art.glow.vertex, ",", 1, 3)
        .. " " .. tostring(art.plate.shown), "false false true 0.3,0.6,1 true", "no side's pip, no badge, a blue glow, on a blue plate")
    Game():Dress(cell, {id = -2, kind = "dwarf", special = "charge", dir = "col"})
    equal(art.streak.shown and art.streak.w .. "x" .. art.streak.h .. " " .. table.concat(art.streak.coords, ",") .. " " .. art.full.texture,
        "10x" .. (B.VIEW.FACE + 8) .. " 0,1,0,1 Interface\\Icons\\Ability_Warrior_Charge", "a Charge for the column: a line of light down it and the Charge's icon")
    equal(tostring(art.full.shown) .. " " .. tostring(art.face.shown) .. " " .. art.full.w .. " " .. tostring(art.full.mask == art.face.mask)
        .. " " .. table.concat(art.full.coords, ","), "true false " .. B.VIEW.FACE .. " true 0.08,0.92,0.08,0.92",
        "the special's icon drawn whole where the face was, cut round as a face is")
    equal(art.badge.texture, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Dwarf", "the dwarf's face small in the corner ring, so its race still shows")
    equal(art.badge.shown and art.badgeRing.shown and art.badge.mask ~= nil and art.badgeRing.atlas, "GarrMission_PortraitRing",
        "its badge round, in a small gold ring")
    equal(art.glow.shown and art.glow.blend .. " " .. table.concat(art.glow.vertex, ",", 1, 3), "ADD 1,0.62,0.18", "and a warm glow behind it")
    local V = B.VIEW
    equal(art.badge.w .. " " .. art.badgeRing.w .. " " .. tostring(art.badgeRing.w / 2 + V.BADGE_X <= V.CELL / 2
        and art.badgeRing.w / 2 + V.BADGE_Y <= V.CELL / 2), "17 19 true",
        "a bigger badge (17 px in a 19 px ring, was 16 in 21), its ring inside the cell (the board clips what's past it)")
    local spot = art.badge.lastPoint
    equal(spot[1] .. " " .. spot[4] .. "," .. spot[5] .. " " .. art.badgeRing.lastPoint[4] .. "," .. art.badgeRing.lastPoint[5], "CENTER 13,13 13,13",
        "at the top right, ring and badge on one centre")
    -- The ring and badge are one solid disc over the face: its nearest edge
    -- must stay at least as far from the face's centre as the old badge's
    -- (a 21 px ring at 13, 13: 7.9 px), so it never creeps onto the portrait.
    local ringAt, faceAt = art.badgeRing.lastPoint, art.face.lastPoint
    local fx, fy = faceAt and faceAt[4] or 0, faceAt and faceAt[5] or 0
    local gap = math.sqrt((ringAt[4] - fx) ^ 2 + (ringAt[5] - fy) ^ 2) - art.badgeRing.w / 2
    local oldGap = math.sqrt(2) * 13 - 21 / 2
    equal(gap >= oldGap - .001, true, ("the badge keeps off the face: its edge %.2f px from the face's centre (old badge %.2f)"):format(gap, oldGap))
    local lit = art.badgeGlow
    equal(lit.shown and lit.blend .. " " .. table.concat(lit.vertex, ",", 1, 3) .. " " .. lit.texture .. " " .. lit.layer .. " " .. lit.sublevel
        .. " " .. art.face.layer .. " " .. tostring(art.face.sublevel or 0) .. " " .. art.plate.layer,
        "ADD 1,0.62,0.18 Interface\\Glues\\Models\\UI_Draenei\\GenericGlow64 ARTWORK -1 ARTWORK 0 BORDER",
        "the badge in a soft light of the Charge's colour, over the plate but under the face (the portrait never dimmed)")
    equal(art.glint.shown and art.glint.texture .. " " .. art.glint.blend .. " " .. art.glint.layer .. " " .. art.glint.alpha,
        "Interface\\Cooldown\\star4 ADD OVERLAY 0", "a star waiting to glint on the badge")
    equal(tostring(art.full.shown) .. " " .. art.full.w .. " " .. tostring(art.full.mask ~= nil), "true " .. V.FACE .. " true", "the icon shown whole, at the face's size")
    equal(Game().cells[1].art.plate.shown and Game().cells[1].art.face.texture, "Interface\\CharacterFrame\\TemporaryPortrait-Male-Dwarf", "on a dwarf's plate")
    Game():Dress(cell, {id = -3, kind = "dwarf", special = "charge", dir = "row"})
    equal(art.streak.w .. "x" .. art.streak.h .. " " .. table.concat(art.streak.coords, ","), (B.VIEW.FACE + 8) .. "x10 0,0,1,0,0,1,1,1", "a Charge for the row: the line turned across")
    -- Specials shimmer: the glow, the badge and its light pulse; a glint flares now and then.
    local shiny = Game().cells[2]
    Game():Dress(shiny, {id = -4, kind = "orc", special = "sheep"})
    Tick(.1)
    local was = shiny.art.glow.alpha
    local wasBadge, wasLight = shiny.art.badge.w, shiny.art.badgeGlow.alpha
    Tick(.2)
    equal(type(was) == "number" and shiny.art.glow.alpha ~= was, true, "a special's glow shimmers")
    equal(shiny.art.badge.w ~= wasBadge and shiny.art.badgeGlow.alpha ~= wasLight, true, "its badge and the badge's light pulse with it")
    local low, high, wide, narrow, ring, most, glinted = 1, 0, 0, math.huge, 0, 0, false
    for _ = 1, 80 do
        Tick(.05)
        local a = shiny.art
        low, high = math.min(low, a.glow.alpha), math.max(high, a.glow.alpha)
        wide, narrow = math.max(wide, a.badge.w), math.min(narrow, a.badge.w)
        ring = math.max(ring, a.badgeRing.w)
        most = math.max(most, a.glint.alpha or 0)
        if (a.glint.alpha or 0) > .3 and a.glint.w > 8 then glinted = true end
    end
    equal(low >= .55 and high > .9 and high <= 1, true, ("a stronger glow: %.2f to %.2f (was .4 to .9)"):format(low, high))
    equal(narrow >= V.BADGE and wide <= V.BADGE * 1.08, true, "the badge swells gently, never past 8%")
    equal(ring == V.BADGE_RING and ring / 2 + V.BADGE_X <= V.CELL / 2 and wide < ring, true,
        "inside its ring, which stays put inside the cell (no flat edge on the board's top row or right column)")
    equal(glinted and most <= .9 and shiny.art.glint.w <= V.GLINT, true, "and now and then a glint flares on the badge")
    equal(table.concat(shiny.art.glow.vertex, ",", 1, 3) .. " " .. shiny.art.full.texture .. " " .. table.concat(shiny.art.badgeGlow.vertex, ",", 1, 3),
        "1,0.45,0.85 Interface\\Icons\\Spell_Nature_Polymorph 1,0.45,0.85", "a Sheep's pink glow, its icon whole, its race's face in pink light")
    Game():Dress(shiny, {id = -5, kind = "orc"})
    equal(shiny.shiny or shiny.art.glow.shown or shiny.art.badge.shown or shiny.art.badgeGlow.shown or shiny.art.glint.shown or shiny.art.full.shown, false,
        "a plain piece again: no glow, no badge, no light, no glint, no icon")
    equal(shiny.art.face.shown, true, "and its face back")
    Game():Dress(shiny, {id = -6, special = "hearth"})
    equal(tostring(shiny.art.badgeGlow.shown) .. " " .. tostring(shiny.art.glint.shown) .. " " .. tostring(shiny.art.glow.shown) .. " " .. shiny.art.full.texture,
        "false true true Interface\\Icons\\INV_Misc_Rune_01", "a Hearthstone: its own icon again (not the Sheep's), a glint on it, its blue glow")
end

-- When the client has no gold ring, no green glow or no swirl: the next art, then plain shapes.
do
    Session({char = Kept(), missing = {GarrMission_PortraitRing = true, ["talents-node-circle-greenglow"] = true,
        ["powerswirlanimation-whirls"] = true}})
    local game = OpenFree()
    local art = game.cells[1].art
    equal(tostring(art.badgeRing.atlas) .. " " .. art.badgeRing.texture, "nil Interface\\CharacterFrame\\TempPortraitAlphaMask", "the badge on a small gold disc")
    equal(game.hintGlows[1].texture .. " " .. table.concat(game.hintGlows[1].vertex, ",", 1, 3), "Interface\\Cooldown\\ping4 0.4,1,0.5", "the hint: a green ring")
    local swirl = game.freeSwirls[1]
    equal(tostring(swirl.atlas) .. " " .. swirl.texture, "nil 986749", "the swirl: a glowing ring")
    Session({char = Kept(), missing = {["Interface\\Garrison\\ClassHallBackground"] = true}})
    game = OpenFree()
    equal(game.cells[1].tile.colour ~= nil and game.cells[1].tile.colour[1] ~= game.cells[2].tile.colour[1], true, "no stone: flat tiles, still a shade apart")
end

-- Flights: Free play's board kept for the next one ---------------------------------------------

do
    local char = Kept()
    Session({char = char, db = {miniGameFlight = "blast"}})
    equal(Shell(), nil, "nothing opens on the ground")
    OpenFree()
    MG:Close("hand")
    TakeOff(3)
    equal(Showing() and MG.current .. " " .. Game().screen, "blast free", "taking off opens Azeroth Blast where you left it: Free play")
    equal(Shell().where.text, "Flying to Orgrimmar, Durotar", "the header says where you're flying")
    local game = Game()
    game.cells[I(2, 2)]:Click("LeftButton")
    game.cells[I(2, 1)]:Click("LeftButton")
    Settle()
    local board, score = game.state.board, game.state.score
    local kept = EraUIClassicCharDB.miniGames.games.blast.board
    Land()
    equal(Showing(), false, "landing closes it")
    equal(EraUIClassicCharDB.miniGames.best.blast, score, "its score kept as a best")
    TakeOff()
    equal(Showing() and game.state.board == board and game.state.score, score, "the next flight: the same board and score")
    equal(EraUIClassicCharDB.miniGames.games.blast.board, kept, "and the same kept board")
    equal(Shell().note.text, "Your board from your last flight is kept.", "flying again: it says the board is kept, never that you landed")
    Land()

    -- A /reload: the kept board comes back.
    local db, keptChar = EraUIDB, EraUIClassicCharDB
    Session({char = keptChar, db = db})
    OpenFree()
    local same = true
    for i = 1, 64 do
        local p, q = Game().state.board[i], board[i]
        if p.kind ~= q.kind or p.special ~= q.special then same = false end
    end
    equal(same and Game().state.score, score, "after a /reload: the same board and score")

    -- Mid-move as a fight starts: hidden, the move ended.
    local a, b = B.FindMove(Game().state.board)
    Game().cells[a]:Click("LeftButton")
    Game().cells[b]:Click("LeftButton")
    Tick(.05)
    world.combat = true; Fire("PLAYER_REGEN_DISABLED")
    equal(Showing() or Busy(), false, "a fight hides it, the move ended")
    world.combat = false; Fire("PLAYER_REGEN_ENABLED")

    -- Whack and Azeroth Blast share the window.
    MG:Open("whack", "command")
    equal(MG.games.whack.holder.shown and not Game().holder.shown and not Game().bar.shown, true, "Whack opened: Azeroth Blast's board and buttons hidden")
    MG:Open("blast", "switch")
    equal(Game().holder.shown and not MG.games.whack.holder.shown and Game().screen, "free", "and back, to the same screen")
end

-- Hints in the window -----------------------------------------------------------------------------

do
    Session({char = Kept()})
    local game = OpenFree()
    local a, b = B.Hint(game.state.board)
    equal(a .. " " .. b, I(2, 1) .. " " .. I(2, 2), "the fixed layout's one move is its hint")
    equal(game.hintButton.label.text .. " " .. game.hintButton:GetAlpha(), "Hint 1", "the Hint button ready at first")
    Tick(14.9)
    equal(game.hintA == nil and not game.hintGlows[1].shown, true, "no hint before 15 seconds")
    Tick(.2)
    equal(game.hintA .. " " .. game.hintB .. " " .. tostring(game.hintGlows[1].shown and game.hintGlows[2].shown), a .. " " .. b .. " true",
        "15 seconds with no move: the move's two pieces glow")
    equal(game.hintGlows[1].lastPoint[2] == game.cells[a].art and game.hintGlows[2].lastPoint[2] == game.cells[b].art and game.hintGlows[1].atlas,
        "talents-node-circle-greenglow", "a green glow round each")
    equal(Shell().note.text, "Swap the two glowing pieces.", "the footer says so")
    Tick(.15)
    equal(game.cells[a].dx > 0 and game.cells[b].dx < 0 and game.cells[a].dy == 0 and game.cells[a].dx <= 3.5, true, "they lean towards each other")
    local quiet = #sounds
    Tick(1)
    equal(#sounds, quiet, "a hint by itself makes no sound")
    game.cells[I(6, 6)]:Click("LeftButton")
    equal(tostring(game.hintA) .. " " .. tostring(game.hintGlows[1].shown) .. " " .. game.cells[a].dx .. " " .. game.cells[b].dx, "nil false 0 0",
        "the next click ends it, the pieces back in place")
    game.cells[I(6, 6)]:Click("LeftButton")
    -- The cooldown: a hint by itself rests the button too.
    sounds = {}
    game.hintButton:Click()
    equal(game.hintA == nil and #sounds, 0, "the Hint button gives nothing during the cooldown, silently")
    equal(game.hintButton.label.text:match("^%d+s$") ~= nil and game.hintButton:GetAlpha(), .55, "it greys and counts down")
    local counted = game.hintButton.label.text
    Tick(1.1)
    equal(game.hintButton.label.text ~= counted, true, "the count moves on")
    Tick(14)
    game.cells[I(6, 6)]:Click("LeftButton")
    game.cells[I(6, 6)]:Click("LeftButton")
    Tick(13)
    game.cells[I(6, 6)]:Click("LeftButton")
    game.cells[I(6, 6)]:Click("LeftButton")
    equal(game.hintA, nil, "no hint by itself during the cooldown either")
    Tick(2)
    equal(game.hintA == nil and game.hintButton.label.text .. " " .. game.hintButton:GetAlpha(), "Hint 1", "the cooldown over: the button ready again")
    sounds = {}
    game.hintButton:Click()
    equal(game.hintA .. " " .. game.hintB .. " " .. tostring(sounds[1]), a .. " " .. b .. " 856:SFX", "the Hint button: the hint at once, with a soft click")
    equal(game:HintWait() > 29.9 and game:HintWait() < 30.1, true, "and the cooldown starts")
    Tick(.05)
    equal(game.hintButton.label.text .. " " .. game.hintButton:GetAlpha(), "30s 0.55", "shown on the button")
    game.hintButton:Click()
    equal(game.hintA .. " " .. tostring(game.hintGlows[1].shown), a .. " true", "asked again: still shown")
    game.cells[a]:Click("LeftButton")
    game.cells[b]:Click("LeftButton")
    equal(Busy() and game.state.moves, 1, "the hinted move plays")
    game.hintButton:Click()
    Tick(.3)
    equal(game.hintA, nil, "no hint while a move plays out")
    Settle()
    Tick(14.5)
    equal(game.hintA, nil, "the wait starts again once the move is played")
    for _ = 1, 700 do
        if game.hintA then break end
        Tick(.05)
    end
    equal(game:HintWait() > 29 and game.hintA ~= nil and B.MoveValue(game.state.board, game.hintA, game.hintB) ~= nil, true,
        "after 15 seconds still in the cooldown: a hint on the new board as soon as it's over")
    local left = game:HintWait()
    MG:Close("hand")
    equal(game.hintA == nil and not game.hintGlows[1].shown, true, "closing the window ends it")
    MG:Open("blast", "switch")
    equal(game:HintWait(), left, "closing the window doesn't run the cooldown down")
    Tick(14.9)
    equal(game.hintA, nil, "opened again: the 15 seconds start again")
end

-- Each special's effects and sounds in the window ------------------------------------------------

-- A board laid by hand on Free play, a move made on it by clicks, and its
-- first clear begun. Returns the game.
local function Played(rows, specials, a, b, opts)
    opts = opts or {}
    Session({char = Kept(opts.faction), faction = opts.faction, db = opts.db})
    local game = OpenFree()
    game.state.random = opts.random or Script()
    if opts.meter then game.state.meter = opts.meter end
    Lay(game.state, Rows(rows), specials)
    game:Paint(game.state.board)
    sounds = {}
    Forget()
    game.cells[a]:Click("LeftButton")
    game.cells[b]:Click("LeftButton")
    Tick(.2)
    return game
end
do
    -- A Charge caught in a match.
    local game = Played({[4] = "OO......", [5] = "..O....."}, {[I(4, 2)] = {"charge", "row"}}, I(5, 3), I(4, 3))
    local ends = {}
    for _, call in ipairs(Spied("Tween")) do
        local streak = call.data
        if streak and streak.x1 and not streak.icon then ends[#ends + 1] = streak.x1 .. ":" .. streak.w .. "x" .. streak.h end
    end
    table.sort(ends)
    local V = B.VIEW
    equal(B.VIEW.STREAKS - #game.freeStreaks .. " " .. table.concat(ends, " "), "2 -70:120x26 " .. (8 * V.CELL + 70) .. ":120x26",
        "a Charge fires: streaks sweep out both ways along its row")
    equal(game.flashes[1].shown and game.flashes[1].w .. "x" .. game.flashes[1].h, (8 * V.CELL) .. "x" .. V.CELL, "the row lit")
    equal(Heard("3330:SFX") and Heard("3113:SFX"), true, "with the Charge's own sound and a battle shout")
    equal(#Spied("Shake", function(call) return call.strength == 4 end), 1, "the board shakes")
    equal(Spied("FloatText")[1].text, "+80", "eight pieces: +80 rising")
    Settle()
    Tick(.5)
    equal(#game.freeStreaks, B.VIEW.STREAKS, "the streaks back in their pool")

    -- An Explosive Sheep.
    game = Played({[4] = "OO......", [5] = "..O....."}, {[I(4, 2)] = {"sheep"}}, I(5, 3), I(4, 3))
    equal(Heard("3580:SFX") and Heard("4100:SFX"), true, "an Explosive Sheep: a bleat and a blast")
    local puffs = Spied("Burst", function(call) return call.opts.texture == 937000 end)
    equal(#puffs == 1 and puffs[1].opts.blend == "BLEND" and puffs[1].at == game.cells[I(4, 2)], true, "smoke puffs out where it was")
    equal(#Spied("Pulse", function(call) return call.opts.texture == "Interface\\Cooldown\\ping4" end), 1, "a shockwave ring")
    equal(#Spied("Shake", function(call) return call.strength == 6 end), 1, "a harder shake")

    -- A Wind Rider.
    game = Played({[4] = "OO......", [5] = "..O....."}, {[I(4, 2)] = {"flyer"}}, I(5, 3), I(4, 3))
    local swoop
    for _, call in ipairs(Spied("Tween")) do if call.data and call.data.land then swoop = call.data end end
    local land = swoop and swoop.land
    local r, c = B.Cell(land or 1)
    equal(swoop and swoop.shown and swoop.icon.texture, "Interface\\Icons\\Ability_Mount_Wyvern_01", "a Wind Rider swoops out")
    local function Spot(row, col) return V.LEFT + (col - .5) * V.CELL, -(V.TOP + (row - .5) * V.CELL) end
    local fx, fy = Spot(4, 2)
    local tx, ty = Spot(r, c)
    equal(swoop.x0 == fx and swoop.y0 == fy and swoop.x1 == tx and swoop.y1 == ty, true,
        "from its cell to its target's")
    equal(Heard("219930:SFX"), true, "with a soft whoosh")
    Tick(.3)
    equal(#Spied("Pulse", function(call) return call.at == game.cells[land] and call.opts.colour and call.opts.colour[1] == .45 end), 1,
        "a flash where it lands")

    -- A Hearthstone swapped with a human.
    game = Played({[1] = "H.......", [4] = "....H...", [6] = ".D....D."}, {[I(4, 4)] = {"hearth"}}, I(4, 4), I(4, 5))
    local swirl
    for _, call in ipairs(Spied("Tween")) do if call.data and call.data.size and not call.data.icon then swirl = call.data end end
    equal(B.VIEW.SWIRLS - #game.freeSwirls .. " " .. tostring(swirl and swirl.atlas), "1 powerswirlanimation-whirls", "a Hearthstone: a swirl spins out")
    local sx, sy = Spot(4, 5)
    equal(swirl.lastPoint[4] == sx and swirl.lastPoint[5] == sy and swirl.rotation ~= 0, true, "spinning, from where it was swapped to")
    equal(Heard("2561:SFX") and Heard("3315:SFX"), true, "with the Hearthstone's cast and its arrival")
    equal(#Spied("Pulse", function(call) return call.opts.colour and call.opts.colour[1] == .3 and call.opts.colour[2] == .6 end), 3,
        "each piece it clears flashes blue (two humans and itself)")
    Settle()
    Tick(1)
    equal(#game.freeSwirls .. " " .. tostring(swirl.rotation) .. " " .. tostring(swirl.shown), B.VIEW.SWIRLS .. " 0 false", "the swirl back in its pool, hidden, unturned")
end

do
    -- Combos.
    local game = Played({}, {[I(4, 4)] = {"charge", "row"}, [I(5, 4)] = {"charge", "col"}}, I(4, 4), I(5, 4))
    equal(B.VIEW.STREAKS - #game.freeStreaks .. " " .. #Spied("Shake", function(call) return call.strength == 7 end), "4 1",
        "two Charges: streaks along a row and a column, a big shake")
    game = Played({}, {[I(4, 4)] = {"sheep"}, [I(4, 5)] = {"sheep"}}, I(4, 4), I(4, 5))
    local puffs = Spied("Burst", function(call) return call.opts.texture == 937000 end)
    equal(#puffs .. " " .. puffs[1].opts.count .. " " .. #Spied("Shake", function(call) return call.strength == 9 end), "1 11 1",
        "two Sheep: a bigger cloud, a bigger shake")
    game = Played({}, {[I(4, 4)] = {"charge", "row"}, [I(4, 5)] = {"sheep"}}, I(4, 4), I(4, 5))
    equal(B.VIEW.STREAKS - #game.freeStreaks .. " " .. #Spied("Burst", function(call) return call.opts.texture == 937000 end), "4 1",
        "a Charge and a Sheep: streaks and smoke")
    game = Played({}, {[I(4, 4)] = {"hearth"}, [I(4, 5)] = {"hearth"}}, I(4, 4), I(4, 5))
    -- (Script: no piece is epic, so only every 13th piece's loot flies.)
    equal(B.VIEW.SWIRLS - #game.freeSwirls .. " " .. #Spied("Shake", function(call) return call.strength == 11 end), "2 1",
        "two Hearthstones: two big swirls, the biggest shake")
    local flying = 0
    for _, call in ipairs(Spied("Tween")) do if call.data and call.data.icon and call.data.shown then flying = flying + 1 end end
    equal(flying <= B.VIEW.LOOT_FLY and #game.freeFlyers >= B.VIEW.FLYERS - B.VIEW.LOOT_FLY, true, "the whole board cleared: still only a few loot icons fly")

    -- A chain: a word for each step from the second, a sound a step higher each time.
    game = Played({[4] = "OO......", [5] = "..O....."}, nil, I(5, 3), I(4, 3), {random = Script({kind = 1})})
    Settle()
    local words = {}
    for _, call in ipairs(Spied("Banner")) do words[#words + 1] = call.text .. (call.opts.sub and (" (" .. call.opts.sub .. ")") or "") end
    equal(table.concat(words, " ", 1, 4), "Double! Triple! Unstoppable! (A chain of 4!) Legendary! (A chain of 5!)", "the chain's words")
    local double = Spied("Banner")[1].opts.colour
    equal(table.concat(double, ","), "0.12,1,0", "Double! in green")
    equal(Heard("206515:SFX") and Heard("206517:SFX") and Heard("208731:SFX") and Heard("208732:SFX"), true, "each step's sound higher")
    equal(#Spied("Shake", function(call) return call.strength == 5 end) >= 1, true, "the third step shakes the board")

    -- Epic loot: a purple flash, its 50 rising, the epic loot sound.
    game = Played({[4] = "OO......", [5] = "..O....."}, nil, I(5, 3), I(4, 3), {random = Script({epic = 1})})
    local purple = Spied("Pulse", function(call) return call.opts.colour and call.opts.colour[1] == .7 and call.opts.colour[3] == 1 end)
    local epicWords = Spied("FloatText", function(call) return call.text == "Epic! +50" end)
    equal(#purple .. " " .. #epicWords .. " " .. epicWords[1].opts.size, "3 3 20", "three epic pieces: three purple flashes, each with its 50, bigger")
    equal(Spied("FloatText")[1].text, "+180", "the clear's own points")
    local epicSounds = 0
    for _, sound in ipairs(sounds) do if sound == "31578:SFX" then epicSounds = epicSounds + 1 end end
    equal(epicSounds, 1, "the epic loot sound, once")
    local purpleFlying = 0
    for _, fly in ipairs(game.sky.children) do
        if fly.icon and fly.shown and fly.glow.vertex[1] == .7 then purpleFlying = purpleFlying + 1 end
    end
    equal(purpleFlying, 3, "every epic piece's loot flies, in a purple glow")

    -- Bloodlust (a Horde player).
    game = Played({[4] = "HH......", [5] = "..H....."}, nil, I(5, 3), I(4, 3), {meter = 29})
    equal(MG.FX.banner.text.text .. " " .. tostring(Heard("347047:SFX") and Heard("344561:SFX")), "Bloodlust! true", "Bloodlust: a banner, a roar and the drums")
    equal(game.glows[1].shown and game.glows[1].colour[1] > game.glows[1].colour[3], true, "the board's edge glows red")
    equal(Spied("FloatText")[1].opts.colour[1], 1, "the clear's points (counted before it starts)")
end

do
    -- Falling in: faster and faster, a hop, then still.
    local F = Game().FallAt
    local falling, faster = true, true
    for k = 1, 73 do
        if not (F(k / 100, 120, 5) < F((k - 1) / 100, 120, 5)) then falling = false end
        if k > 1 and not (F((k - 1) / 100, 120, 5) - F(k / 100, 120, 5) > F((k - 2) / 100, 120, 5) - F((k - 1) / 100, 120, 5)) then faster = false end
    end
    equal(F(0, 120, 5) == 120 and falling and faster and F(B.VIEW.LAND, 120, 5) == 0, true, "a piece falls from above, faster and faster, to its place")
    equal(F(.87, 120, 5) > 4.9 and F(.87, 120, 5) <= 5 and F(.95, 120, 5) < F(.87, 120, 5), true, "then hops up a little")
    equal(F(1, 120, 5), 0, "and settles")
    local game = Played({[4] = "OO.O....", [5] = "..O....."}, nil, I(5, 3), I(4, 3))
    Tick(.3)
    equal(game.cells[I(1, 1)].dy > 0 and game.cells[I(1, 1)].dy < 40, true, "after the clear, the pieces above fall in")
    local made = game.cells[I(4, 3)]
    equal(made.made and made.scale > 1 and made.piece.special, "charge", "the Charge made swells as it lands")
    equal(Heard("206515:SFX") and #Spied("Pulse", function(call) return call.at == made end) >= 1, true, "with a flash and a chime")
    Settle()
    equal(made.scale .. " " .. made.dy, "1 0", "then all still")
end

-- Sounds off: none, though everything else plays.
do
    local char = Kept()
    Session({char = char, db = {miniGameSounds = false}})
    OpenFree()
    sounds = {}
    Game().cells[I(2, 2)]:Click("LeftButton")
    Game().cells[I(2, 1)]:Click("LeftButton")
    Tick(.2)
    equal(#MG.FX.sparks > 0 and #MG.FX.floats > 0 and #sounds, 0, "with Mini-game Sounds off: sparks and points, no sound")
    Settle()
    Game().hintButton:Click()
    Tick(6)
    equal(Game().state.score > 0 and #sounds, 0, "no sound at all")
end

-- A board kept damaged: a new one, kept at once.
do
    Session({char = {miniGames = {games = {blast = {board = "frog", version = 1}}}}})
    OpenFree()
    local kept = EraUIClassicCharDB.miniGames.games.blast.board
    equal(type(kept) == "string" and select(2, kept:gsub(",", ",")) + 1, 64, "a damaged board: a new one, kept")
end

print("Azeroth Blast checks passed: " .. checks .. " assertions.")
