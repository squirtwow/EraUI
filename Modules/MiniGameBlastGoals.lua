local _, EraUI = ...

-- Azeroth Blast's level rules (experimental, with the mini-games): holes,
-- blockers and how every hit treats them, goals, the boss, the power-ups,
-- Blast.GoalHint and a level kept mid-way (Blast.SaveLevel / LoadLevel).
-- Plain functions on MiniGames.Blast, no frames (Tools/TestBlastLevels.lua
-- and Tools/TestBlastBalance.lua play them). The levels themselves (zones,
-- the first 40, the made ones and Blast.NewLevel) are in
-- Modules/MiniGameBlastLevels.lua; the shared rules (matches, specials,
-- combos, falls) in Modules/MiniGameBlast.lua, which hands a level's parts here.
--
-- BLAST RULES CONTRACT (for the view; nothing here draws or plays a sound):
-- A level state (Blast.NewLevel(n, random, faction, boosters), or
-- Blast.LoadLevel(snapshot, random, faction)) has, besides Free play's board,
-- score, meter and lust:
--   mode = "level", level = n, spec (Blast.LevelSpec(n)), kinds (the races that drop),
--   cells[i] = {hole = true} | {oil = 0..2, bossOil = 0..2} | nil, exits = {[i] = true},
--   movesLeft, moves (used), extra (+5 moves bought on the lose card this attempt),
--   lust (moves of Bloodlust / Heroism left, 0..3), epics,
--   goals = {{id, token, race, foe, name, need, have}} in the spec's order,
--   boss = {key, name, hp, max, every, timer, actions, next} or nil,
--   relics = {need, max, onBoard, spawned, out, cols, byExit} or nil,
--   outcome = nil | "won" | "lost", finished (Blast.Finish's table, once won).
-- A piece: {id, kind (race; nil for a Hearthstone or blocker), special, dir,
--   ice = 1|2, web = true, block = "crate"|"skull"|"relic", hits = 1..3 (a
--   crate's), relic = 1..5 (its look), boss = true (the boss put it there)}.
--   A piece is never changed: a change makes a new one (a new id), so the
--   boards kept in the steps stay pictures.
-- Moves (each returns a result):
--   Blast.Swap(state, a, b, {free = true}) (Free swap: no match needed, no move used)
--   Blast.Smash(state, i) (the Mallet: a blast on one cell, no move; a relic is refused)
--   Blast.Shuffle(state) -> {ok, shuffled, before, after, goals, movesLeft} (no move)
--   Blast.AddMoves(state, n) -> movesLeft (on a lost level it carries on: extra + 1)
--   Refused: {ok = false, why = "far"|"nomatch"|"locked"|"over"|"empty"|"relic",
--     what = "ice"|"web"|"crate"|"skull" (locked)}.
-- A special swapped with a race's piece fires at once, no match needed (a
--   move used, or none on a Free swap); with a relic it needs a match.
-- A result: {ok, a, b, free, used (a move went), smash, swapped (the board after
--   the swap), combo, hearthKind, lone (the cell a special on its own fired
--   from), steps, lustStep, lustOver (it ended with this
--   move), settled, reshuffled (laid again: no move was left), bossActed (the
--   boss's step), points, scoreBefore, meterBefore, movesLeft, outcome, goals = {have...}}.
-- Its steps, in order, each with kind:
--   "clear": before, after, cleared {{i, piece, loot, epic}}, fired, made, flashes,
--     hits {{i, what = "ice"|"web"|"crate"|"skull"|"oil", left}} (cell order),
--     broken {{i, piece}} (crates and skulls gone), fall {[i] = rows, holes
--     counted}, relicsIn {{i, piece}} (a relic dropped in) or nil, points,
--     mult, score, meter, enemies, epics, lust (lit here), index (its place in
--     the chain), damage, shielded, bossHp, goals = {have...}
--   "exit": relicsOut {{i, piece}}, before, after, fall, relicsIn, points, score, goals
--   "boss": action ("oil"|"freeze"|"crates"|"skulls"|"web"), cells {i...},
--     oil {[i] = layers now}, before, after, text ("Hogger spills oil."), goals
-- The boss: his timer counts used moves down (with Blast.WAIT_SHIELDED, not
--   while his own mess is on the board); at 0 he acts (result.bossActed, the last
--   step) unless the move won, then it starts again at every. His mess never
--   passes Blast.MESS_CAP cells (no room: he waits, no step). Shielded (any of
--   his mess up): half damage.
-- The end: Blast.Outcome(state) -> "won"|"lost"|nil. Blast.Result(state) ->
--   {won, stars, score, movesLeft, epics, boss}, what MiniGames.Progress:Finish
--   ("blast", n, result) takes; on a win it runs Blast.Finish(state) first,
--   once (each move left adds Blast.MOVE_BONUS) -> {score, bonus, stars, movesLeft}.
--   Blast.Stars(state) -> 0..3: 1 a win, 2 and 3 with spec.stars moves to
--   spare (a win after +5 moves: 1). An oil goal counts spots made clean.
-- Reading: Blast.Locked(piece), Blast.Shielded(state) -> on, count,
--   Blast.GoalText(goal, faction), Blast.GoalShort(goal) "14/20", Blast.GoalCounts(state),
--   Blast.GoalsDone(state), Blast.GoalHint(state) -> a, b, Blast.RaceOf(token, faction),
--   Blast.Hole(state, i), Blast.Plain(piece).
-- Keeping: Blast.SaveLevel(state) -> snapshot; Blast.LoadLevel(t, random, faction) -> state or nil.
local MG = EraUI.MiniGames
if not MG or not MG.Blast then return end

local Blast = MG.Blast
local N = Blast.SIZE
local CELLS = N * N
local Index, Cell, Copy = Blast.Index, Blast.Cell, Blast.Copy
local Roll, Piece, Locked = Blast.Roll, Blast.Piece, Blast.Locked
local EMPTY = {}

Blast.LUST_MOVES = 3       -- Bloodlust / Heroism in a level: this many moves
Blast.HIT_POINTS = 20      -- each blocker hit: an ice layer, a web, a crate's hit, a skull, an oil layer
Blast.RELIC_POINTS = 100   -- a relic out
Blast.RELIC_LOOKS = 5      -- relic.1 .. relic.5
Blast.MAX_MOVES = 99
Blast.LOW_BONUS = .2       -- the goal hint's worth a row down, for each piece a move clears
Blast.HINT_DAMAGE, Blast.HINT_MESS = 20, 8   -- the goal hint: this much boss damage is worth 1; a piece of his mess 8
-- Boss damage: a piece (the other side's hit harder), each special that
-- fires, two specials swapped, each later step of a chain, and the shield.
Blast.DAMAGE = {piece = 10, foe = 15, charge = 40, sheep = 60, flyer = 30, hearth = 100, combo = 150,
    chain = .1, shield = .5}
Blast.MESS_CAP = 8         -- the most of the boss's mess (cells) on the board at once
-- true: his countdown waits while his mess is on the board. Off: he strikes
-- every few moves as his intro says (waiting, he struck under once a fight).
Blast.WAIT_SHIELDED = false
Blast.BOSS_TEXT = {oil = "%s spills oil.", freeze = "%s freezes your pieces.", crates = "%s drops crates.",
    skulls = "%s drops skulls.", web = "%s spins webs."}

local function Hole(state, i)
    local cell = state.cells and state.cells[i]
    return cell ~= nil and cell.hole == true
end
Blast.Hole = Hole
local function Inside(r, c) return r >= 1 and r <= N and c >= 1 and c <= N end
local function Near(i, d)
    local r, c = Cell(i)
    if Inside(r + d[1], c + d[2]) then return Index(r + d[1], c + d[2]) end
    return nil
end
-- A plain piece: a race's, no special, nothing on it.
local function Plain(piece)
    return piece ~= nil and piece.kind ~= nil and not piece.special and not piece.ice and not piece.web and not piece.block
end
Blast.Plain = Plain

-- A new piece: from's fields (none), then over's (false takes one away).
function Blast.Make(state, from, over)
    state.nextId = (state.nextId or 0) + 1
    local piece = {}
    for key, value in pairs(from or EMPTY) do piece[key] = value end
    for key, value in pairs(over or EMPTY) do
        if value == false then piece[key] = nil else piece[key] = value end
    end
    piece.id = state.nextId
    if not (piece.ice or piece.web or piece.block) then piece.boss = nil end
    return piece
end
local Make = Blast.Make

-- Races by token: foe1..3 the other side's, pal1..3 your own.
Blast.TOKENS = {foe1 = 1, foe2 = 2, foe3 = 3, pal1 = 4, pal2 = 5, pal3 = 6}
local SIDES = {Alliance = {"orc", "tauren", "undead", "human", "dwarf", "nightelf"},
    Horde = {"human", "dwarf", "nightelf", "orc", "tauren", "undead"}}
Blast.PLURAL = {orc = "orcs", tauren = "tauren", undead = "undead", human = "humans", dwarf = "dwarves",
    nightelf = "night elves"}
function Blast.RaceOf(token, faction)
    local at = Blast.TOKENS[token]
    if at then return SIDES[faction == "Alliance" and "Alliance" or "Horde"][at] end
    if Blast.RACE[token] then return token end
    return nil
end
-- The races that drop: all six, or five without your own third (pal3).
function Blast.KindsFor(count, faction)
    local leave = count == 5 and Blast.RaceOf("pal3", faction) or nil
    local kinds = {}
    for _, kind in ipairs(Blast.KINDS) do if kind ~= leave then kinds[#kinds + 1] = kind end end
    return kinds
end

-- Goals ------------------------------------------------------------------------------------------

local function Tick(state, id, count, race)
    if not count or count <= 0 then return end
    for _, goal in ipairs(state.goals or EMPTY) do
        if goal.id == id and (race == nil or goal.race == race) then goal.have = math.min(goal.need, goal.have + count) end
    end
end
local function TickScore(state)
    for _, goal in ipairs(state.goals or EMPTY) do
        if goal.id == "score" then goal.have = math.min(goal.need, state.score) end
    end
end
Blast.TickScore = TickScore
function Blast.GoalCounts(state)
    local out = {}
    for k, goal in ipairs(state.goals or EMPTY) do out[k] = goal.have end
    return out
end
function Blast.GoalsDone(state)
    local goals = state.goals or EMPTY
    if #goals == 0 then return false end
    for _, goal in ipairs(goals) do if goal.have < goal.need then return false end end
    return true
end
-- "won" once every goal is met (even on the last move), "lost" with no move
-- left, else nil (Free play: nil).
function Blast.Outcome(state)
    if state.mode ~= "level" then return nil end
    if state.outcome then return state.outcome end
    if Blast.GoalsDone(state) then return "won" end
    if (state.movesLeft or 0) <= 0 then return "lost" end
    return nil
end
-- Stars for a win: 1, then 2 and 3 with the level's marks of moves to spare
-- (spec.stars), so a quick win always earns them; a win after +5 moves, 1.
-- 0 not won. (score: unused, kept for old callers.)
function Blast.Stars(state, score)
    if state.mode ~= "level" or Blast.Outcome(state) ~= "won" then return 0 end
    if (state.extra or 0) > 0 then return 1 end
    local left, marks = state.movesLeft or 0, state.spec.stars
    if left >= marks[2] then return 3 end
    if left >= marks[1] then return 2 end
    return 1
end
-- A won level's end, once: each move left adds Blast.MOVE_BONUS.
function Blast.Finish(state)
    if state.finished then return state.finished end
    if Blast.Outcome(state) ~= "won" then return nil end
    local bonus = (Blast.MOVE_BONUS or 100) * (state.movesLeft or 0)
    state.score = state.score + bonus
    state.finished = {score = state.score, bonus = bonus, stars = Blast.Stars(state, state.score), movesLeft = state.movesLeft}
    return state.finished
end
-- What MiniGames.Progress:Finish("blast", n, result) takes for this attempt.
function Blast.Result(state)
    local won = Blast.Outcome(state) == "won"
    local done = won and Blast.Finish(state) or nil
    return {won = won, stars = done and done.stars or 0, score = state.score, movesLeft = won and state.movesLeft or 0,
        epics = state.epics or 0, boss = state.spec ~= nil and state.spec.boss ~= nil}
end

local function Count(n, one, many) return ("%d %s"):format(n, n == 1 and one or many) end
-- A goal in words: "Clear 10 orcs", "Clean 16 oil spots", "Defeat Hogger".
function Blast.GoalText(goal, faction)
    local id, need = goal.id, goal.need or 0
    if id == "collect" then
        local race = goal.race or Blast.RaceOf(goal.token, faction)
        local info = Blast.RACE[race]
        return "Clear " .. Count(need, info and info.name or "piece", Blast.PLURAL[race] or "pieces")
    elseif id == "enemy" then
        local foe = goal.foe or ((faction == "Alliance") and "Horde" or "Alliance")
        return "Clear " .. Count(need, foe .. " piece", foe .. " pieces")
    elseif id == "score" then return ("Score %d points"):format(need)
    elseif id == "oil" then return "Clean " .. Count(need, "oil spot", "oil spots")
    elseif id == "ice" then return "Free " .. Count(need, "frozen piece", "frozen pieces")
    elseif id == "crate" then return "Break " .. Count(need, "crate", "crates")
    elseif id == "web" then return "Break " .. Count(need, "web", "webs")
    elseif id == "relic" then return "Bring down " .. Count(need, "relic", "relics")
    elseif id == "boss" then return "Defeat " .. tostring(goal.name or "the boss") end
    return tostring(id)
end
function Blast.GoalShort(goal) return ("%d/%d"):format(goal.have or 0, goal.need or 0) end

-- Laying a level out ---------------------------------------------------------------------------

-- A kind for (r, c) that makes no line or square with any piece round it.
local function LevelPick(state, board, r, c)
    local kinds = state.kinds or Blast.KINDS
    local start = Roll(state, 1, #kinds, "kind")
    for k = 0, #kinds - 1 do
        local kind = kinds[(start - 1 + k) % #kinds + 1]
        if not Blast.Makes(board, r, c, kind) then return kind end
    end
    return kinds[start]
end
-- Holes stay empty; blockers, relics, specials and frozen or webbed pieces
-- (with their race) stay; every other cell gets a new plain piece.
local function LayLevel(state, old)
    local board = {}
    for i = 1, CELLS do
        local piece = old[i]
        if piece and not Hole(state, i) and (piece.block or piece.special or ((piece.ice or piece.web) and piece.kind)) then
            board[i] = piece
        end
    end
    for r = 1, N do
        for c = 1, N do
            local i = Index(r, c)
            if not Hole(state, i) and not board[i] then
                local was, kind = old[i], LevelPick(state, board, r, c)
                if was and (was.ice or was.web) then board[i] = Make(state, was, {kind = kind})
                else board[i] = Piece(state, kind) end
            end
        end
    end
    return board
end
-- Plain pieces next to a piece that could swap with them: where a Hearthstone helps.
local function HearthSpots(board)
    local spots = {}
    for i = 1, CELLS do
        if Plain(board[i]) then
            for _, d in ipairs(Blast.AROUND) do
                local j = Near(i, d)
                local other = j and board[j]
                if other and not Locked(other) and (other.kind or other.special) then spots[#spots + 1] = i; break end
            end
        end
    end
    return spots
end
-- Laid with no line or square standing and a move (Blast.TRIES layouts);
-- else the last one, any match standing broken by a Hearthstone, and when
-- still stuck, one random plain piece made a Hearthstone (always a move).
function Blast.ArrangeLevel(state)
    local old, board = state.board or {}, nil
    for _ = 1, math.max(1, Blast.TRIES) do
        board = LayLevel(state, old)
        if #Blast.FindGroups(board) == 0 and Blast.FindMove(board) then
            state.board = board
            return board
        end
    end
    for _ = 1, CELLS do
        local group = Blast.FindGroups(board)[1]
        if not group then break end
        local at = group.cells[1]
        for _, i in ipairs(group.cells) do if Plain(board[i]) then at = i; break end end
        board[at] = Piece(state, nil, "hearth")
    end
    if not Blast.FindMove(board) then
        local spots = HearthSpots(board)
        if #spots > 0 then board[spots[Roll(state, 1, #spots, "stuck")]] = Piece(state, nil, "hearth") end
    end
    state.board = board
    return board
end

-- Falls and relics --------------------------------------------------------------------------------

-- The column the next relic drops in, or nil (none due).
local function RelicColumn(state)
    local relics = state.relics
    if not relics or relics.onBoard >= relics.max or relics.spawned >= relics.need then return nil end
    local cols = relics.cols or EMPTY
    if #cols == 0 then return nil end
    if relics.byExit then return cols[relics.spawned % #cols + 1] end
    return cols[relics.spawned + 1] or cols[#cols]
end
function Blast.NewRelic(state)
    local relics = state.relics
    relics.spawned, relics.onBoard = relics.spawned + 1, relics.onBoard + 1
    return Make(state, nil, {block = "relic", relic = (relics.spawned - 1) % Blast.RELIC_LOOKS + 1})
end
-- A level's fall: in each column the cells that aren't holes, top to bottom,
-- are its list; the pieces settle down it (past the holes) and new ones
-- drop in above its top cell. Returns fall ({[i] = rows fallen, holes
-- counted}) and relicsIn ({{i, piece}}: a relic due dropped in) or nil.
function Blast.LevelFall(state, calm)
    local board, kinds = state.board, state.kinds or Blast.KINDS
    local fall, lists, gaps = {}, {}, {}
    for c = 1, N do
        local list = {}
        for r = 1, N do if not Hole(state, Index(r, c)) then list[#list + 1] = r end end
        local write = #list
        for k = #list, 1, -1 do
            local r = list[k]
            local i = Index(r, c)
            local piece = board[i]
            if piece then
                local to = list[write]
                if to ~= r then
                    board[Index(to, c)] = piece
                    board[i] = nil
                end
                fall[Index(to, c)] = to - r
                write = write - 1
            end
        end
        lists[c], gaps[c] = list, write
    end
    local spawn, relicsIn = RelicColumn(state), nil
    for c = 1, N do
        local list, gap = lists[c], gaps[c]
        for k = gap, 1, -1 do
            local r = list[k]
            local i = Index(r, c)
            if k == 1 and c == spawn then
                board[i] = Blast.NewRelic(state)
                relicsIn = relicsIn or {}
                relicsIn[#relicsIn + 1] = {i = i, piece = board[i]}
                spawn = nil
            else
                local kind = kinds[Roll(state, 1, #kinds, "kind")]
                if calm and Blast.Makes(board, r, c, kind) then
                    local start = Roll(state, 1, #kinds, "kind")
                    for j = 0, #kinds - 1 do
                        local other = kinds[(start - 1 + j) % #kinds + 1]
                        if not Blast.Makes(board, r, c, other) then kind = other; break end
                    end
                end
                board[i] = Piece(state, kind)
            end
            fall[i] = r - (list[1] - gap + k - 1)
        end
    end
    return fall, relicsIn
end
-- Relics on an exit cell leave, each time the board settles: an exit step
-- with its own fall (and any relic due), until none stands on an exit.
function Blast.Exits(state, result)
    local relics = state.relics
    if not relics then return end
    local board = state.board
    for _ = 1, CELLS do
        local out = {}
        for i = 1, CELLS do
            if state.exits[i] and board[i] and board[i].block == "relic" then out[#out + 1] = i end
        end
        if #out == 0 then return end
        local mult = state.lust > 0 and Blast.LUST_MULT or 1
        local step = {kind = "exit", before = Copy(board), relicsOut = {}, cleared = {}, fired = {}, made = {}, flashes = {},
            hits = {}, broken = {}, mult = mult}
        for _, i in ipairs(out) do
            step.relicsOut[#step.relicsOut + 1] = {i = i, piece = board[i]}
            board[i] = nil
            relics.out, relics.onBoard = relics.out + 1, relics.onBoard - 1
        end
        Tick(state, "relic", #out)
        step.points = Blast.RELIC_POINTS * #out * mult
        state.score = state.score + step.points
        step.fall, step.relicsIn = Blast.LevelFall(state, false)
        step.after = Copy(board)
        step.score, step.meter = state.score, state.meter
        TickScore(state)
        step.goals = Blast.GoalCounts(state)
        result.steps[#result.steps + 1] = step
    end
end

-- Hits -------------------------------------------------------------------------------------------

-- A Gryphon's or Wind Rider's target in a level: a crate, else a skull, a
-- frozen piece, a webbed one, a piece on oil, a piece under a relic, any
-- piece (never a relic).
local FLYER_ORDER = {"crate", "skull", "ice", "web", "oil", "under", "any"}
local function UnderRelic(board, j)
    local r, c = Cell(j)
    for above = r - 1, 1, -1 do
        local piece = board[Index(above, c)]
        if piece and piece.block == "relic" then return true end
    end
    return false
end
function Blast.FlyerTarget(state, clear)
    local board, cells, groups = state.board, state.cells or EMPTY, {any = {}}
    for j = 1, CELLS do
        local piece = board[j]
        if piece and not clear[j] and piece.block ~= "relic" then
            local what
            if piece.block then what = piece.block
            elseif piece.ice then what = "ice"
            elseif piece.web then what = "web"
            elseif cells[j] and (cells[j].oil or 0) > 0 then what = "oil"
            elseif UnderRelic(board, j) then what = "under" end
            if what then
                groups[what] = groups[what] or {}
                groups[what][#groups[what] + 1] = j
            end
            groups.any[#groups.any + 1] = j
        end
    end
    for _, what in ipairs(FLYER_ORDER) do
        if groups[what] and #groups[what] > 0 then return groups[what] end
    end
    return groups.any
end
-- Whether the boss's own mess is on the board (it halves his damage), and how much.
function Blast.Shielded(state)
    local count = 0
    for i = 1, CELLS do
        local piece = state.board[i]
        if piece and piece.boss then count = count + 1 end
        local cell = state.cells and state.cells[i]
        if cell and (cell.bossOil or 0) > 0 then count = count + 1 end
    end
    return count > 0, count
end

local function Record(step, i, what, left)
    step.hits[#step.hits + 1] = {i = i, what = what, left = left}
end
-- One hit on cell i (how: "match", "near" or "blast"); returns the points.
-- A cleared piece goes into step.cleared (its loot rolled as in Free play).
local function HitCell(state, step, i, how, tally)
    local board, piece = state.board, state.board[i]
    local gone, points = false, 0
    if piece.block == "crate" then
        local left = (piece.hits or 1) - 1
        Record(step, i, "crate", math.max(0, left))
        points = Blast.HIT_POINTS
        if left <= 0 then gone = true; Tick(state, "crate", 1)
        else board[i] = Make(state, piece, {hits = left}) end
    elseif piece.block == "skull" then
        Record(step, i, "skull", 0)
        points, gone = Blast.HIT_POINTS, true
    elseif piece.ice then
        local left = piece.ice - 1
        Record(step, i, "ice", math.max(0, left))
        points = Blast.HIT_POINTS
        board[i] = Make(state, piece, {ice = left > 0 and left or false})
        if left <= 0 then Tick(state, "ice", 1) end
    elseif how ~= "near" and piece.block == nil then
        if piece.web then
            Record(step, i, "web", 0)
            points = Blast.HIT_POINTS
            Tick(state, "web", 1)
        end
        local epic = Roll(state, 1, Blast.EPIC_ODDS, "epic") == 1
        local list = epic and Blast.EPIC_LOOT or Blast.LOOT
        step.cleared[#step.cleared + 1] = {i = i, piece = piece, loot = list[Roll(state, 1, #list, "loot")], epic = epic}
        points = points + Blast.POINTS + (epic and Blast.EPIC_BONUS or 0)
        if epic then tally.epics = tally.epics + 1 end
        if Blast.Enemy(state, piece) then tally.enemies = tally.enemies + 1 end
        if piece.kind then Tick(state, "collect", 1, piece.kind) end
        gone = true
    end
    if gone then
        if piece.block then step.broken[#step.broken + 1] = {i = i, piece = piece} end
        board[i] = nil
        local cell = state.cells[i]
        if cell and (cell.oil or 0) > 0 then
            cell.oil = cell.oil - 1
            if (cell.bossOil or 0) > 0 then cell.bossOil = cell.bossOil - 1 end
            Record(step, i, "oil", cell.oil)
            points = points + Blast.HIT_POINTS
            -- The oil goal counts spots: one is clean once its last layer goes.
            if cell.oil == 0 then Tick(state, "oil", 1) end
        end
    end
    return points
end
local function Damage(state, step, plan, mult, shielded)
    local D, dmg = Blast.DAMAGE, 0
    for _, gone in ipairs(step.cleared) do dmg = dmg + (Blast.Enemy(state, gone.piece) and D.foe or D.piece) end
    for _, shot in ipairs(step.fired) do dmg = dmg + (D[shot.special] or 0) end
    if plan.combo == "hearth" then dmg = dmg + D.hearth elseif plan.combo then dmg = dmg + D.combo end
    dmg = dmg * mult * (1 + D.chain * ((plan.index or 1) - 1))
    if shielded then dmg = dmg * D.shield end
    return math.floor(dmg)
end
-- One clear in a level (Free play's Step, with blockers): the matched groups
-- ("match" hits), the plan's seeds and every special's area ("blast" hits)
-- and the cells next to a matched one ("near" hits); a cell takes one hit a
-- step at most. Then the new specials go in (never where a piece stayed),
-- the meter fills, the boss is hit and the pieces fall.
function Blast.LevelStep(state, plan)
    local board, boss = state.board, state.boss
    local step = {kind = "clear", before = Copy(board), cleared = {}, fired = {}, made = {}, flashes = {}, hits = {},
        broken = {}, index = plan.index or 1}
    local shielded = boss ~= nil and boss.hp > 0 and Blast.Shielded(state)
    local how, order, done, matched, made = {}, {}, {}, {}, {}
    local function Add(i)
        local piece = board[i]
        if piece and not how[i] and piece.block ~= "relic" then
            how[i] = "blast"
            order[#order + 1] = i
        end
    end
    for id in pairs(plan.spent or EMPTY) do done[id] = true end
    for _, rect in ipairs(plan.flashes or EMPTY) do step.flashes[#step.flashes + 1] = rect end
    for _, group in ipairs(plan.groups or EMPTY) do
        for _, i in ipairs(group.cells) do
            matched[#matched + 1] = i
            if not how[i] then how[i] = "match"; order[#order + 1] = i end
        end
        local special, dir = Blast.Shape(group)
        if special then made[#made + 1] = {group = group, special = special, dir = dir, kind = special ~= "hearth" and group.kind or nil} end
    end
    for _, i in ipairs(plan.seeds or EMPTY) do Add(i) end
    local k = 1
    while k <= #order do
        local i = order[k]
        local piece = board[i]
        if piece.special and not done[piece.id] then
            done[piece.id] = true
            Blast.Fire(state, step, i, piece, how, Add)
        end
        k = k + 1
    end
    local touched, near = {}, {}
    for i in pairs(how) do touched[#touched + 1] = i end
    for _, i in ipairs(matched) do
        for _, d in ipairs(Blast.AROUND) do
            local j = Near(i, d)
            if j and board[j] and not how[j] and not near[j] then
                near[j] = true
                touched[#touched + 1] = j
            end
        end
    end
    table.sort(touched)
    local mult = state.lust > 0 and Blast.LUST_MULT or 1
    local tally, points = {enemies = 0, epics = 0}, 0
    for _, i in ipairs(touched) do points = points + HitCell(state, step, i, how[i] or "near", tally) end
    for _, make in ipairs(made) do
        local at = Blast.Anchor(make.group, make.special, plan.prefer)
        if board[at] ~= nil then
            at = nil
            for _, i in ipairs(make.group.cells) do if board[i] == nil then at = i; break end end
        end
        if at then
            local piece = Piece(state, make.kind, make.special, make.dir)
            board[at] = piece
            step.made[#step.made + 1] = {i = at, piece = piece}
        end
    end
    points = points * mult
    state.score = state.score + points
    state.epics = (state.epics or 0) + tally.epics
    Tick(state, "enemy", tally.enemies)
    if state.lust <= 0 then
        state.meter = state.meter + tally.enemies
        if state.meter >= Blast.METER_FULL then
            state.meter, state.lust, step.lust, state.lustLit = 0, Blast.LUST_MOVES, true, true
        end
    end
    if boss and boss.hp > 0 then
        step.damage, step.shielded = Damage(state, step, plan, mult, shielded), shielded
        boss.hp = math.max(0, boss.hp - step.damage)
        if boss.hp == 0 then Tick(state, "boss", 1) end
    end
    step.bossHp = boss and boss.hp or nil
    step.fall, step.relicsIn = Blast.LevelFall(state, plan.calm)
    step.after = Copy(board)
    step.points, step.mult, step.score, step.meter = points, mult, state.score, state.meter
    step.enemies, step.epics = tally.enemies, tally.epics
    TickScore(state)
    step.goals = Blast.GoalCounts(state)
    return step
end

-- The boss -------------------------------------------------------------------------------------------

-- The top two cells (not holes) of each column: where his crates land.
local function TopTwo(state)
    local top = {}
    for c = 1, N do
        local found = 0
        for r = 1, N do
            local i = Index(r, c)
            if not Hole(state, i) and found < 2 then top[i], found = true, found + 1 end
        end
    end
    return top
end
-- The boss strikes back with his next action, on plain pieces picked by
-- the roll ("boss"): never holes, relics, specials or blockers. His mess
-- on the board never goes past Blast.MESS_CAP: with no room left he waits
-- (nil: no step, the same action next time).
function Blast.BossAct(state)
    local boss, board, cells = state.boss, state.board, state.cells
    local room = Blast.MESS_CAP - select(2, Blast.Shielded(state))
    if room <= 0 then return nil end
    local action = boss.actions[boss.next] or boss.actions[1]
    boss.next = boss.next % #boss.actions + 1
    local kind = action.kind
    local step = {kind = "boss", action = kind, cells = {}, oil = {}, before = Copy(board), cleared = {}, fired = {}, made = {},
        flashes = {}, hits = {}, broken = {}}
    local top = kind == "crates" and TopTwo(state) or nil
    local spots = {}
    for i = 1, CELLS do
        if Plain(board[i]) and (top == nil or top[i]) and (kind ~= "oil" or ((cells[i] and cells[i].oil) or 0) < 2) then
            spots[#spots + 1] = i
        end
    end
    for _ = 1, math.min(action.count or 1, #spots, room) do
        local i = table.remove(spots, Roll(state, 1, #spots, "boss"))
        local piece = board[i]
        if kind == "oil" then
            local cell = cells[i] or {}
            cells[i] = cell
            local add = math.min(2 - (cell.oil or 0), action.layers or 1)
            cell.oil, cell.bossOil = (cell.oil or 0) + add, math.min(2, (cell.bossOil or 0) + add)
            step.oil[i] = cell.oil
        elseif kind == "freeze" then board[i] = Make(state, piece, {ice = 1, boss = true})
        elseif kind == "crates" then board[i] = Make(state, nil, {block = "crate", hits = action.hits or 2, boss = true})
        elseif kind == "skulls" then board[i] = Make(state, nil, {block = "skull", boss = true})
        elseif kind == "web" then board[i] = Make(state, piece, {web = true, boss = true}) end
        step.cells[#step.cells + 1] = i
    end
    table.sort(step.cells)
    step.after = Copy(board)
    step.text = (Blast.BOSS_TEXT[kind] or "%s strikes back."):format(boss.name or "The boss")
    step.goals = Blast.GoalCounts(state)
    return step
end

-- Moves -------------------------------------------------------------------------------------------

-- After a level's swap or power-up: a used move counts down the moves,
-- Bloodlust / Heroism (not on the move that lit it) and the boss's
-- countdown; the boss acts at 0 unless this move won; a board with no move
-- is laid again; then the outcome.
function Blast.EndMove(state, result, used)
    if used then
        state.movesLeft = math.max(0, state.movesLeft - 1)
        state.moves = (state.moves or 0) + 1
        if state.lust > 0 and not state.lustLit then
            state.lust = state.lust - 1
            if state.lust == 0 then result.lustOver = true end
        end
    end
    state.lustLit = nil
    TickScore(state)
    local won = Blast.GoalsDone(state)
    local boss = state.boss
    if not won and used and boss and boss.hp > 0 and not (Blast.WAIT_SHIELDED and Blast.Shielded(state)) then
        boss.timer = boss.timer - 1
        if boss.timer <= 0 then
            local step = Blast.BossAct(state)
            if step then
                result.steps[#result.steps + 1] = step
                result.bossActed = step
            end
            boss.timer = boss.every
        end
    end
    if not won then result.reshuffled = Blast.Unstick(state) end
    if won then state.outcome = "won" elseif state.movesLeft <= 0 then state.outcome = "lost" end
    result.outcome, result.movesLeft, result.used = state.outcome, state.movesLeft, used and true or nil
    result.points = state.score - (result.scoreBefore or state.score)
    result.goals = Blast.GoalCounts(state)
    return result
end
local function Refused(why, a, b, what) return {ok = false, why = why, a = a, b = b, what = what} end
-- A level's swap (Blast.Swap hands it here). opts.free: a Free swap, made
-- with or without a match, using no move.
function Blast.LevelSwap(state, a, b, opts)
    local board, free = state.board, type(opts) == "table" and opts.free == true
    if state.outcome then return Refused("over", a, b) end
    if not (Blast.Adjacent(a, b) and board[a] and board[b]) then return Refused("far", a, b) end
    local pa, pb = board[a], board[b]
    local what = Locked(pa) or Locked(pb)
    if what then return Refused("locked", a, b, what) end
    board[a], board[b] = pb, pa
    local plan = Blast.Combo(state, a, b)
    if not plan then
        local groups = Blast.FindGroups(board)
        if #groups > 0 then plan = {groups = groups, prefer = {b, a}}
        elseif not free then
            board[a], board[b] = pa, pb
            return Refused("nomatch", a, b)
        end
    end
    local result = {ok = true, a = a, b = b, free = free or nil, steps = {}, swapped = Copy(board),
        combo = plan and plan.combo, hearthKind = plan and plan.hearthKind, lone = plan and plan.lone,
        scoreBefore = state.score, meterBefore = state.meter}
    state.lustLit = nil
    if plan then
        Blast.Run(state, plan, result)
    else
        -- A Free swap that matched nothing: a relic it put on an exit still leaves.
        Blast.Exits(state, result)
        local groups = Blast.FindGroups(board)
        if #groups > 0 then Blast.Run(state, {groups = groups}, result) end
    end
    return Blast.EndMove(state, result, not free)
end
-- The Mallet: a "blast" hit on cell i (a special there fires; a crate
-- loses a hit, a skull breaks, ice cracks). A relic can't be smashed. No move.
function Blast.Smash(state, i)
    if state.mode ~= "level" or state.outcome then return Refused("over") end
    if not Blast.Valid(i) or Hole(state, i) or not state.board[i] then return Refused("empty", i) end
    if state.board[i].block == "relic" then return Refused("relic", i) end
    local result = {ok = true, smash = i, a = i, steps = {}, swapped = Copy(state.board), scoreBefore = state.score,
        meterBefore = state.meter}
    state.lustLit = nil
    Blast.Run(state, {seeds = {i}}, result)
    return Blast.EndMove(state, result, false)
end
-- Shuffle: the plain pieces laid again (a move, no match standing). No move.
function Blast.Shuffle(state)
    if state.mode ~= "level" or state.outcome then return Refused("over") end
    local before = Copy(state.board)
    Blast.ArrangeLevel(state)
    return {ok = true, shuffled = true, before = before, after = Copy(state.board), goals = Blast.GoalCounts(state),
        movesLeft = state.movesLeft}
end
-- n more moves (+5 moves). On a lost level it carries on (extra + 1: the
-- lose card's price ladder). Returns the moves left.
function Blast.AddMoves(state, n)
    n = tonumber(n) or 5
    if n ~= n or n < 1 then n = 5 end
    state.movesLeft = math.min(Blast.MAX_MOVES, (state.movesLeft or 0) + math.floor(n))
    if state.outcome == "lost" then
        state.outcome = nil
        state.extra = math.min(Blast.MAX_MOVES, (state.extra or 0) + 1)
    end
    return state.movesLeft
end

-- The goal hint ---------------------------------------------------------------------------------

-- What's still wanted: unfinished goals by id (collect by race), whether a
-- boss is up, each column's top relic row.
local function Wants(state)
    local want = {race = {}, top = {}}
    for _, goal in ipairs(state.goals or EMPTY) do
        if goal.have < goal.need then
            if goal.id == "collect" then want.race[goal.race] = true else want[goal.id] = true end
        end
    end
    want.boss = state.boss ~= nil and state.boss.hp > 0
    for i = 1, CELLS do
        local piece = state.board[i]
        if piece and piece.block == "relic" then
            local r, c = Cell(i)
            want.top[c] = math.min(want.top[c] or N, r)
        end
    end
    return want
end
-- One cell's worth to the goals, hit as how.
local function CellValue(state, want, i, how)
    local piece = state.board[i]
    if not piece or piece.block == "relic" then return 0 end
    if piece.block == "crate" then return want.crate and 8 or piece.boss and Blast.HINT_MESS or 3 end
    if piece.block == "skull" then return 6 end
    if piece.ice then return want.ice and 8 or piece.boss and Blast.HINT_MESS or 2 end
    if how == "near" then return 0 end
    local r, c = Cell(i)
    -- A clear low down shakes up more of the board (and the bottom rows
    -- that pieces otherwise never leave).
    local value, cell = 1 + (r - 1) * Blast.LOW_BONUS, state.cells[i]
    if piece.kind and want.race[piece.kind] then value = value + 6 end
    if want.enemy and Blast.Enemy(state, piece) then value = value + 4 end
    if piece.web then value = value + ((want.web or piece.boss) and 7 or 2) end
    if cell and (cell.oil or 0) > 0 and (want.oil or (cell.bossOil or 0) > 0) then value = value + 8 end
    if want.relic then
        -- Under a relic it drops; beside its column, new pieces fall in next to its way down.
        if want.top[c] and want.top[c] < r then value = value + 10
        elseif (want.top[c - 1] and want.top[c - 1] < r) or (want.top[c + 1] and want.top[c + 1] < r) then value = value + 4 end
    end
    if want.boss then value = value + (Blast.Enemy(state, piece) and 15 or 10) / Blast.HINT_DAMAGE end
    return value
end
-- A special caught in the first clear, or fired on its own: its area as
-- blast hits (no chain past it), each cell once (seen: cells already
-- counted). blasted: a cell counted only as beside the match (seen "near")
-- counts as blasted instead.
local function SpecialValue(state, want, i, piece, seen, blasted)
    local rect = Blast.Reach(piece, i)
    if not rect then return piece.special == "flyer" and 6 or 10 end
    local value = want.boss and (Blast.DAMAGE[piece.special] or 0) / Blast.HINT_DAMAGE or 0
    Blast.EachIn(rect, function(j)
        local was = seen[j]
        if not was then
            seen[j] = true
            value = value + CellValue(state, want, j, "blast")
        elseif blasted and was == "near" then
            seen[j] = true
            value = value + CellValue(state, want, j, "blast") - CellValue(state, want, j, "near")
        end
    end)
    return value
end
-- How far column col is from the nearest exit.
local function ExitGap(state, col)
    local best = N
    for i in pairs(state.exits or EMPTY) do
        local _, c = Cell(i)
        best = math.min(best, math.abs(c - col))
    end
    return best
end
local function KindAt(board, r, c)
    local piece = Inside(r, c) and board[Index(r, c)]
    return piece and piece.kind
end
-- The match a swapped-in piece at i makes (the board had none before, so
-- every match of the swap runs through a or b): its cells go in cells;
-- returns whether it makes a special (four in a line, an L or T, a square).
local function MatchAt(board, i, cells)
    local kind = board[i] and board[i].kind
    if not kind then return false end
    local r, c = Cell(i)
    local left, right, up, down = c, c, r, r
    while KindAt(board, r, left - 1) == kind do left = left - 1 end
    while KindAt(board, r, right + 1) == kind do right = right + 1 end
    while KindAt(board, up - 1, c) == kind do up = up - 1 end
    while KindAt(board, down + 1, c) == kind do down = down + 1 end
    local across, along, square = right - left + 1, down - up + 1, false
    if across >= 3 then for cc = left, right do cells[Index(r, cc)] = true end end
    if along >= 3 then for rr = up, down do cells[Index(rr, c)] = true end end
    for top = r - 1, r do
        for side = c - 1, c do
            if KindAt(board, top, side) == kind and KindAt(board, top, side + 1) == kind and KindAt(board, top + 1, side) == kind
                and KindAt(board, top + 1, side + 1) == kind then
                square = true
                cells[Index(top, side)], cells[Index(top, side + 1)] = true, true
                cells[Index(top + 1, side)], cells[Index(top + 1, side + 1)] = true, true
            end
        end
    end
    return across >= 4 or along >= 4 or (across >= 3 and along >= 3) or square
end
-- What a plain swap is worth (nil: it matches nothing): the cells it
-- matches, the specials it makes and catches, the cells next to them, and a
-- relic moved down or toward an exit. Also the cells it counted (true, or
-- "near" for one only beside the match).
local scratch = {}
local function MatchValue(state, want, a, b, pa, pb)
    local board, value = state.board, 0
    if MatchAt(board, a, scratch) then value = value + 4 end
    if MatchAt(board, b, scratch) then value = value + 4 end
    if next(scratch) == nil then return nil end
    local matched, seen = {}, {}
    for i in pairs(scratch) do matched[#matched + 1] = i end
    for _, i in ipairs(matched) do scratch[i] = nil end
    table.sort(matched)
    for _, i in ipairs(matched) do
        seen[i] = true
        value = value + CellValue(state, want, i, "match")
    end
    for _, i in ipairs(matched) do
        local piece = board[i]
        if piece.special then value = value + SpecialValue(state, want, i, piece, seen) end
        for _, d in ipairs(Blast.AROUND) do
            local j = Near(i, d)
            if j and not seen[j] then
                seen[j] = "near"
                value = value + CellValue(state, want, j, "near")
            end
        end
    end
    local from, to
    if pa.block == "relic" then from, to = a, b elseif pb.block == "relic" then from, to = b, a end
    if from and want.relic then
        local rf, cf = Cell(from)
        local rt, ct = Cell(to)
        if rt > rf or ExitGap(state, ct) < ExitGap(state, cf) then value = value + 12
        else value = value - 12 end
    end
    return value, seen
end
-- Whether a piece of kind moved to i (from from) has one of its kind beside
-- it: no line or square can form without one (a quick no for most swaps).
local function Beside(board, i, from, kind)
    if not kind then return false end
    local r, c = Cell(i)
    for _, d in ipairs(Blast.AROUND) do
        local rr, cc = r + d[1], c + d[2]
        if Inside(rr, cc) then
            local j = Index(rr, cc)
            local piece = j ~= from and board[j]
            if piece and piece.kind == kind then return true end
        end
    end
    return false
end
-- Whether cell i is one of the groups' (matched).
local function Matched(groups, i)
    for _, group in ipairs(groups or EMPTY) do
        for _, j in ipairs(group.cells) do if j == i then return true end end
    end
    return false
end
-- How good swapping a and b is for the goals, looking at its first clear
-- only, or nil when it's no move. A special on its own: the match the swap
-- lines up (one that takes the special in counts its blast) and its blast
-- from where it lands, a cell they share counted once.
function Blast.GoalValue(state, a, b, want)
    local board = state.board
    local pa, pb = board[a], board[b]
    if not (pa and pb) or Locked(pa) or Locked(pb) or not Blast.Adjacent(a, b) then return nil end
    if pa.kind == pb.kind and not (pa.special or pb.special) then return nil end   -- the same picture
    if not (pa.special or pb.special) and not Beside(board, a, b, pb.kind) and not Beside(board, b, a, pa.kind) then return nil end
    want = want or Wants(state)
    board[a], board[b] = pb, pa
    local value
    local plan = (pa.special or pb.special) and Blast.Combo(state, a, b)
    if plan and plan.lone then
        local seen
        value, seen = MatchValue(state, want, a, b, pa, pb)
        value = value or 0
        if not Matched(plan.groups, plan.lone) then
            value = value + SpecialValue(state, want, plan.lone, board[plan.lone], seen or {}, true)
        end
    elseif plan then
        local seen = {}
        value = Blast.MoveValue(board, b, a) or 90
        for _, i in ipairs(plan.seeds) do
            if not seen[i] then
                seen[i] = true
                value = value + CellValue(state, want, i, "blast")
            end
        end
    else
        value = MatchValue(state, want, a, b, pa, pb)
    end
    board[a], board[b] = pa, pb
    return value
end
-- The best move for the level's goals as two cells, or nil (the first of
-- equals from the top left). Free play: Blast.Hint.
function Blast.GoalHint(state)
    if state.mode ~= "level" then return Blast.Hint(state.board) end
    local want = Wants(state)
    local bestA, bestB, best
    for r = 1, N do
        for c = 1, N do
            for _, step in ipairs(Blast.AHEAD) do
                local r2, c2 = r + step[1], c + step[2]
                if Inside(r2, c2) then
                    local a, b = Index(r, c), Index(r2, c2)
                    local value = Blast.GoalValue(state, a, b, want)
                    if value and (best == nil or value > best) then bestA, bestB, best = a, b, value end
                end
            end
        end
    end
    return bestA, bestB
end

-- Keeping a level ---------------------------------------------------------------------------------
-- Blast.SaveLevel(state) -> {v = 1, mode = "level", level, board (64 tokens
-- joined by ","), oil (64 digits), bossOil (64 digits, only once the boss
-- spilt some), movesLeft, moves, score, meter, lust, extra, epics,
-- goals = {have...}, boss = {hp, timer, next}, relics = {onBoard, spawned, out},
-- outcome ("lost" only: the lose card waits)}. Tokens: "#" a hole; "orc",
-- "orc/charge/row", "/hearth"; then "*i1" "*i2" (ice) or "*w" (web);
-- blockers "@crate1".."@crate3", "@skull", "@relic1".."@relic9"; "*b" last
-- when the boss put it there.

local function Token(piece)
    if not piece then return "" end
    local text
    if piece.block == "crate" then text = "@crate" .. (piece.hits or 1)
    elseif piece.block == "skull" then text = "@skull"
    elseif piece.block == "relic" then text = "@relic" .. (piece.relic or 1)
    else
        text = piece.kind or ""
        if piece.special then text = text .. "/" .. piece.special .. (piece.dir and ("/" .. piece.dir) or "") end
        if piece.ice then text = text .. "*i" .. piece.ice end
        if piece.web then text = text .. "*w" end
    end
    if piece.boss then text = text .. "*b" end
    return text
end
function Blast.SaveLevel(state)
    if type(state) ~= "table" or state.mode ~= "level" or type(state.board) ~= "table" then return nil end
    local tokens, oil, bossOil, spilt = {}, {}, {}, false
    for i = 1, CELLS do
        local cell = state.cells[i] or EMPTY
        tokens[i] = cell.hole and "#" or Token(state.board[i])
        oil[i] = tostring(cell.oil or 0)
        bossOil[i] = tostring(cell.bossOil or 0)
        if (cell.bossOil or 0) > 0 then spilt = true end
    end
    local boss, relics = state.boss, state.relics
    return {v = 1, mode = "level", level = state.level, board = table.concat(tokens, ","), oil = table.concat(oil),
        bossOil = spilt and table.concat(bossOil) or nil, movesLeft = state.movesLeft, moves = state.moves or 0,
        score = state.score, meter = state.meter, lust = state.lust, extra = state.extra or 0, epics = state.epics or 0,
        goals = Blast.GoalCounts(state), boss = boss and {hp = boss.hp, timer = boss.timer, next = boss.next} or nil,
        relics = relics and {onBoard = relics.onBoard, spawned = relics.spawned, out = relics.out} or nil,
        outcome = state.outcome == "lost" and "lost" or nil}
end

local SPECIALS = {charge = true, sheep = true, flyer = true, hearth = true}
-- A token back into a piece, or nil when it isn't one.
local function Untoken(state, text)
    local body, mods = text:match("^([^*]*)(.*)$")
    if not body or mods:gsub("%*[ibw][12]?", "") ~= "" then return nil end
    local over = {}
    for mod in mods:gmatch("%*([^*]+)") do
        if (mod == "i1" or mod == "i2") and not over.ice then over.ice = tonumber(mod:sub(2))
        elseif mod == "w" and not over.web then over.web = true
        elseif mod == "b" and not over.boss then over.boss = true
        else return nil end
    end
    if body:sub(1, 1) == "@" then
        if over.ice or over.web then return nil end
        local hits, relic = tonumber(body:match("^@crate(%d)$")), tonumber(body:match("^@relic(%d)$"))
        if hits and hits >= 1 and hits <= 3 then over.block, over.hits = "crate", hits
        elseif body == "@skull" then over.block = "skull"
        elseif relic and relic >= 1 and not over.boss then over.block, over.relic = "relic", relic
        else return nil end
        return Make(state, nil, over)
    end
    local kind, special, dir = body:match("^(%a*)/?(%a*)/?(%a*)$")
    if not kind then return nil end
    if special == "" then special = nil end
    if dir == "" then dir = nil end
    if special and not SPECIALS[special] then return nil end
    if special == "hearth" then
        if kind ~= "" or dir then return nil end
        kind = nil
    elseif not Blast.RACE[kind] then
        return nil
    end
    if (special == "charge") ~= (dir == "row" or dir == "col") then return nil end
    if (over.ice and over.web) or ((over.ice or over.web) and special) or (over.boss and not (over.ice or over.web)) then return nil end
    over.kind, over.special, over.dir = kind, special, dir
    return Make(state, nil, over)
end
local function Whole(value, low, high)
    if type(value) ~= "number" or value ~= value or value ~= math.floor(value) or value < low or (high and value > high) then return nil end
    return value
end
local function Digits(text)
    if type(text) ~= "string" or #text ~= CELLS or text:find("[^012]") then return nil end
    return text
end
-- The races on the board made to fit this faction's: a level of five races
-- leaves out each side's own third, so the one race the other side's board
-- had and this one leaves out becomes the one this one has and the board
-- lacks (the same picture, so no match appears).
local function FitRaces(state)
    local allowed, present, extra = {}, {}, {}
    for _, kind in ipairs(state.kinds) do allowed[kind] = true end
    for i = 1, CELLS do
        local piece = state.board[i]
        if piece and piece.kind then present[piece.kind] = true end
    end
    for _, kind in ipairs(Blast.KINDS) do if present[kind] and not allowed[kind] then extra[#extra + 1] = kind end end
    if #extra == 0 then return true end
    if #extra > 1 then return false end
    local spare
    for _, kind in ipairs(state.kinds) do if not present[kind] then spare = kind; break end end
    if not spare then return false end
    for i = 1, CELLS do
        local piece = state.board[i]
        if piece and piece.kind == extra[1] then state.board[i] = Make(state, piece, {kind = spare}) end
    end
    return true
end
local function LoadNumbers(state, t)
    local movesLeft, score = Whole(t.movesLeft, 0, Blast.MAX_MOVES), Whole(t.score, 0)
    local meter, lust = Whole(t.meter, 0, Blast.METER_FULL - 1), Whole(t.lust, 0, Blast.LUST_MOVES)
    local extra, epics, moves = Whole(t.extra or 0, 0, Blast.MAX_MOVES), Whole(t.epics or 0, 0), Whole(t.moves or 0, 0)
    if not (movesLeft and score and meter and lust and extra and epics and moves) then return false end
    state.movesLeft, state.score, state.meter, state.lust = movesLeft, score, meter, lust
    state.extra, state.epics, state.moves = extra, epics, moves
    if type(t.goals) ~= "table" or #t.goals ~= #state.goals then return false end
    for k, goal in ipairs(state.goals) do
        local have = Whole(t.goals[k], 0, goal.need)
        if not have then return false end
        goal.have = have
    end
    local boss = state.boss
    if (boss == nil) ~= (t.boss == nil) then return false end
    if boss then
        if type(t.boss) ~= "table" then return false end
        local hp, timer = Whole(t.boss.hp, 0, boss.max), Whole(t.boss.timer, 1, boss.every)
        local nextAt = Whole(t.boss.next, 1, #boss.actions)
        if not (hp and timer and nextAt) then return false end
        boss.hp, boss.timer, boss.next = hp, timer, nextAt
    end
    return true
end
local function LoadRelics(state, t, onBoard)
    local relics = state.relics
    if not relics then return t.relics == nil and onBoard == 0 end
    if type(t.relics) ~= "table" then return false end
    local out, spawned = Whole(t.relics.out, 0, relics.need), Whole(t.relics.spawned, 0, relics.need)
    if not (out and spawned) or t.relics.onBoard ~= onBoard or spawned ~= onBoard + out then return false end
    relics.onBoard, relics.spawned, relics.out = onBoard, spawned, out
    return true
end
-- A kept level back as a state for the current faction, or nil when it's
-- damaged, from another version, or doesn't fit its level any more.
function Blast.LoadLevel(t, random, faction)
    if type(t) ~= "table" or t.v ~= 1 or t.mode ~= "level" or not Whole(t.level, 1) then return nil end
    if type(t.board) ~= "string" or not Digits(t.oil) or (t.bossOil ~= nil and not Digits(t.bossOil)) then return nil end
    local ok, spec = pcall(Blast.LevelSpec, t.level)
    if not ok or type(spec) ~= "table" then return nil end
    local state = Blast.LevelState(spec, random, faction)
    local tokens = {}
    for text in (t.board .. ","):gmatch("([^,]*),") do tokens[#tokens + 1] = text end
    if #tokens ~= CELLS then return nil end
    local onBoard = 0
    for i = 1, CELLS do
        local hole = Hole(state, i)
        local layers, spilt = tonumber(t.oil:sub(i, i)), t.bossOil and tonumber(t.bossOil:sub(i, i)) or 0
        if (tokens[i] == "#") ~= hole or spilt > layers or (hole and layers > 0) then return nil end
        if not hole then
            local piece = Untoken(state, tokens[i])
            if not piece then return nil end
            state.board[i] = piece
            if piece.block == "relic" then onBoard = onBoard + 1 end
            state.cells[i] = layers > 0 and {oil = layers, bossOil = spilt > 0 and spilt or nil} or nil
        end
    end
    if not FitRaces(state) or #Blast.FindGroups(state.board) > 0 then return nil end
    if not LoadNumbers(state, t) or not LoadRelics(state, t, onBoard) then return nil end
    TickScore(state)
    if t.outcome == "lost" then
        if state.movesLeft > 0 or Blast.GoalsDone(state) then return nil end
        state.outcome = "lost"
    elseif t.outcome ~= nil or state.movesLeft == 0 or Blast.GoalsDone(state) then
        return nil
    else
        Blast.Unstick(state)
    end
    return state
end
