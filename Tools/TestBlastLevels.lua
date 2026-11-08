-- Azeroth Blast's levels (Modules/MiniGameBlastGoals.lua and
-- Modules/MiniGameBlastLevels.lua, on Modules/MiniGameBlast.lua's rules), as
-- plain Lua: holes; every hit on every blocker (match, near and blast, one
-- hit a cell a step, oil only when the piece on it goes); locked pieces;
-- frozen pieces never made specials; the Hearthstone and the flyer with
-- blockers; a special swapped with any piece firing at once (blockers on its
-- line, goals, the boss, Bloodlust, a Free swap, locked pieces, holes and
-- relics, the goal hint); relics falling, leaving at the exits and dropping in; each
-- goal; winning and losing; Bloodlust / Heroism by moves; the boss's
-- damage, shield, countdown, actions and defeat; the power-ups and starting
-- boosters; a level kept and read back (and every damage refused); levels
-- 1 to 40 as written; the made levels (the same every time, valid to 400);
-- and a quick check that a greedy bot wins every written level often enough.
-- Tools/TestBlastBalance.lua is the slow balance run.
-- Run: fengari Tools/TestBlastLevels.lua
local M = dofile("Tools/MiniGameMock.lua")
local equal = M.equal
local RULES = {"MiniGames", "MiniGameFX", "MiniGameAssets", "MiniGameProgress", "MiniGameBlast", "MiniGameBlastGoals",
    "MiniGameBlastLevels"}
local MG = M.Session({only = RULES})
local B = MG.Blast
local I = B.Index

-- Helpers ---------------------------------------------------------------------------------------

-- A scripted random: a rule per kind of roll (a number or a function of low
-- and high); epic loot never; everything else goes round.
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
-- Park-Miller from a seed (the bots' roll).
local function PM(seed)
    local s = seed % 2147483647
    if s <= 0 then s = 1 end
    return function(low, high)
        s = (s * 16807) % 2147483647
        return low + math.floor(s / 2147483647 * (high - low + 1))
    end
end
-- Kinds that never match: new pieces in a hand-laid board drop as these.
local FILLER = {}
for k = 1, 600 do FILLER[k] = "f" .. k end
local LETTER = {O = "orc", T = "tauren", U = "undead", H = "human", D = "dwarf", N = "nightelf"}
local BLANK = "........"
local function Rows(over)
    local rows = {}
    for r = 1, 8 do rows[r] = over and over[r] or BLANK end
    return rows
end
-- A level laid by hand. rows: 8 rows of O T U H D N (races) or "." (a kind
-- of its own). marks: 8 rows of "." nothing, "#" a hole, "o"/"O" oil under
-- the piece, "i"/"I" ice, "w" a web, "1".."3" a crate, "s" a skull, "r" a
-- relic, "b" a skull the boss put there. opts: goals, moves, exits, relics,
-- boss, faction, rules, oil {[i] = layers}, specials {[i] = {special, dir}},
-- bossMade {[i] = true}.
local function Hand(rows, marks, opts)
    opts = opts or {}
    marks = Rows(marks)
    local grid = {}
    for r = 1, 8 do grid[r] = marks[r]:gsub("[^#oO]", ".") end
    local spec = {n = opts.n or 1, moves = opts.moves or 20, kinds = 6, grid = table.concat(grid, "/"),
        goals = opts.goals or {{id = "score", need = 999999}}, exits = opts.exits, relics = opts.relics, boss = opts.boss,
        stars = opts.stars or {1000, 2000}}
    local state = B.LevelState(spec, Script(opts.rules), opts.faction or "Horde")
    state.kinds = FILLER
    for r = 1, 8 do
        for c = 1, 8 do
            local i = I(r, c)
            if not B.Hole(state, i) then
                local ch, m = rows[r]:sub(c, c), marks[r]:sub(c, c)
                local over = {kind = LETTER[ch] or ("x" .. i)}
                if m == "i" or m == "I" then over.ice = m == "I" and 2 or 1
                elseif m == "w" then over.web = true
                elseif tonumber(m) then over = {block = "crate", hits = tonumber(m)}
                elseif m == "s" then over = {block = "skull"}
                elseif m == "b" then over = {block = "skull", boss = true}
                elseif m == "r" then over = {block = "relic", relic = 1} end
                if opts.bossMade and opts.bossMade[i] then over.boss = true end
                state.board[i] = B.Make(state, nil, over)
            end
        end
    end
    for i, layers in pairs(opts.oil or {}) do state.cells[i] = {oil = layers} end
    for i, special in pairs(opts.specials or {}) do
        local was = state.board[i]
        state.board[i] = B.Piece(state, special[1] ~= "hearth" and was.kind or nil, special[1], special[2])
    end
    return state
end
local function Hits(step)
    local out = {}
    for _, hit in ipairs(step.hits) do out[#out + 1] = ("%d:%s:%d"):format(hit.i, hit.what, hit.left) end
    return table.concat(out, " ")
end
local function Cleared(step)
    local out = {}
    for _, gone in ipairs(step.cleared) do out[#out + 1] = gone.i end
    table.sort(out)
    return table.concat(out, " ")
end
local function Goals(state) return table.concat(B.GoalCounts(state), " ") end
-- A plain table as text, keys sorted (for comparing specs and snapshots).
local function Dump(value)
    if type(value) ~= "table" then return tostring(value) end
    local keys = {}
    for key in pairs(value) do keys[#keys + 1] = key end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local parts = {}
    for _, key in ipairs(keys) do parts[#parts + 1] = tostring(key) .. "=" .. Dump(value[key]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
-- No new move needed after a hand-laid move: the board is left as the move left it.
local realUnstick = B.Unstick
local function Still() B.Unstick = function() return false end end
local function Moving() B.Unstick = realUnstick end
local function Kinds(board)
    local out = {}
    for i = 1, 64 do
        local p = board[i]
        out[i] = p and (p.kind or (p.block and ("@" .. p.block)) or p.special or "?") or "-"
    end
    return out
end

-- 1. Holes -------------------------------------------------------------------------------------

do
    for n = 1, 40 do
        local state = B.NewLevel(n, PM(n), n % 2 == 0 and "Alliance" or "Horde")
        local wrong = 0
        for i = 1, 64 do
            if B.Hole(state, i) ~= (state.board[i] == nil) then wrong = wrong + 1 end
        end
        equal(wrong, 0, "level " .. n .. ": nothing on a hole, a piece on every other cell")
        equal(#B.FindGroups(state.board) == 0 and B.FindMove(state.board) ~= nil, true, "level " .. n .. ": no match standing, a move")
    end
    -- Column 1 has a hole on row 5: three orcs below it go, the four above fall past it.
    Still()
    local s = Hand(Rows({[6] = "O.......", [7] = "O.......", [8] = "O......."}), {[5] = "#......."})
    local above = s.board[I(4, 1)].id
    local result = B.Settle(s)
    local step = result.steps[1]
    equal(Cleared(step), I(6, 1) .. " " .. I(7, 1) .. " " .. I(8, 1), "the three orcs under the hole go")
    equal(s.board[I(5, 1)], nil, "the hole stays empty")
    equal(s.board[I(8, 1)].id .. " " .. step.fall[I(8, 1)], above .. " 4", "row 4's piece falls past the hole to row 8 (4 rows, the hole counted)")
    equal(step.fall[I(4, 1)] .. " " .. step.fall[I(1, 1)], "3 3", "row 1's piece falls to row 4, new ones drop 3")
    equal(s.board[I(1, 1)] ~= nil and s.board[I(3, 1)] ~= nil, true, "new pieces fill the top")
    -- A line broken by a hole is no line.
    s = Hand(Rows({[1] = "OO.O...."}), {[1] = "..#....."})
    equal(#B.FindGroups(s.board), 0, "orc, orc, a hole, orc: no match")
    -- A Charge's row skips the hole.
    s = Hand(Rows({[4] = "TTT....."}), {[4] = "....#..."}, {specials = {[I(4, 2)] = {"charge", "row"}}})
    step = B.Settle(s).steps[1]
    equal(Cleared(step), table.concat({I(4, 1), I(4, 2), I(4, 3), I(4, 4), I(4, 6), I(4, 7), I(4, 8)}, " "),
        "a Charge across row 4 clears all but the hole")
    equal(s.board[I(4, 5)], nil, "and the hole stays empty")
    Moving()
end

-- 2. Hits ----------------------------------------------------------------------------------------

do
    Still()
    -- Three orcs on row 4; round them: frozen (row 3 col 2), a 2-hit crate,
    -- a skull, thick ice (row 4 col 1), a 1-hit crate (row 4 col 5), a web,
    -- a relic and a plain piece below. Oil under (4, 2).
    local s = Hand(Rows({[4] = ".OOO...."}), {[3] = ".i2s....", [4] = "Io..1...", [5] = ".wr....."},
        {goals = {{id = "ice", need = 2}, {id = "crate", need = 2}, {id = "oil", need = 1}, {id = "web", need = 1}}})
    local step = B.Settle(s).steps[1]
    equal(Cleared(step), I(4, 2) .. " " .. I(4, 3) .. " " .. I(4, 4), "the three orcs go")
    equal(Hits(step), table.concat({I(3, 2) .. ":ice:0", I(3, 3) .. ":crate:1", I(3, 4) .. ":skull:0", I(4, 1) .. ":ice:1",
        I(4, 2) .. ":oil:0", I(4, 5) .. ":crate:0"}, " "),
        "near hits: ice cracks, a crate loses a hit, a skull and a 1-hit crate break; the oil under a cleared orc goes; web, relic and plain untouched")
    equal(Goals(s), "1 1 1 0", "goals: one piece freed, one crate broken, one oil spot, no web")
    equal(#step.broken, 2, "two blockers broken (the skull and the crate)")
    -- One near hit a step: thick ice touching two matched cells of an L.
    s = Hand(Rows({[4] = "OOO.....", [5] = "..O.....", [6] = "..O....."}), {[5] = ".I......"})
    step = B.Settle(s).steps[1]
    equal(s.board[I(5, 2)] and s.board[I(5, 2)].ice or s.board[I(6, 2)].ice, 1, "thick ice touching two matched cells loses one layer")
    -- A frozen piece in a match cracks and stays; one hit, though matched cells touch it too.
    s = Hand(Rows({[6] = "TTTT...."}), {[6] = ".I......"}, {oil = {[I(6, 2)] = 1}})
    local frozen = s.board[I(6, 2)].id
    step = B.Settle(s).steps[1]
    local stayed = s.board[I(6, 2)] and s.board[I(6, 2)] or s.board[I(7, 2)]
    equal(stayed and stayed.kind .. " " .. stayed.ice, "tauren 1", "a frozen tauren in the line cracks (2 to 1) and stays")
    equal(stayed.id ~= frozen, true, "as a new piece (the old one is never changed)")
    equal(s.cells[I(6, 2)].oil, 1, "the oil under it stays: the piece didn't go")
    -- A webbed piece in a match: the web and the piece go.
    s = Hand(Rows({[7] = "UUU....."}), {[7] = "w......."}, {goals = {{id = "web", need = 1}}})
    step = B.Settle(s).steps[1]
    equal(Cleared(step) .. " | " .. Hits(step), I(7, 1) .. " " .. I(7, 2) .. " " .. I(7, 3) .. " | " .. I(7, 1) .. ":web:0",
        "a webbed undead in a match: cleared with its web")
    equal(Goals(s), "1", "a web broken")
    -- Blast hits: a Charge across row 2 over every blocker.
    s = Hand(Rows({[1] = "........", [2] = "........"}), {[2] = "iw3sr#.."}, {oil = {[I(2, 7)] = 2}, specials = {[I(2, 8)] = {"charge", "row"}},
        goals = {{id = "ice", need = 1}, {id = "web", need = 1}, {id = "crate", need = 1}, {id = "oil", need = 2}}})
    -- (2, 8)'s Charge goes when the three humans below it match.
    s.board[I(3, 8)] = B.Make(s, nil, {kind = s.board[I(2, 8)].kind})
    s.board[I(4, 8)] = B.Make(s, nil, {kind = s.board[I(2, 8)].kind})
    step = B.Settle(s).steps[1]
    equal(Hits(step), table.concat({I(2, 1) .. ":ice:0", I(2, 2) .. ":web:0", I(2, 3) .. ":crate:2", I(2, 4) .. ":skull:0",
        I(2, 7) .. ":oil:1"}, " "), "a Charge's blast: ice cracks, the web goes, the crate loses one, the skull breaks, oil loses a layer")
    equal(s.board[I(2, 5)] and s.board[I(2, 5)].block, "relic", "the relic is never hit (it stays, nothing under it went)")
    equal(s.board[I(2, 6)], nil, "the hole stays empty")
    equal(Goals(s), "1 1 0 0", "goals: the ice and the web; not the crate (2 hits left) nor the dark oil spot (a layer left)")
    Moving()
end

-- 3. Locked pieces --------------------------------------------------------------------------------

do
    local s = Hand(Rows({[4] = "OO.H....", [5] = "..O....."}), {[5] = "..i.....", [6] = "w2s....."})
    for _, case in ipairs({{I(5, 3), I(4, 3), "ice"}, {I(6, 1), I(6, 2), "web"}, {I(6, 2), I(6, 3), "crate"}, {I(6, 3), I(5, 3), "skull"}}) do
        local result = B.Swap(s, case[1], case[2])
        equal(tostring(result.ok) .. " " .. tostring(result.why) .. " " .. tostring(result.what), "false locked " .. case[3],
            "a " .. case[3] .. " can't be swapped")
    end
    equal(B.FindMove(s.board), nil, "the one swap that would match moves a frozen piece: no move")
    equal(B.Hint(s.board) == nil and B.GoalHint(s) == nil, true, "and no hint")
    s.board[I(5, 3)] = B.Make(s, s.board[I(5, 3)], {ice = false})
    equal(B.FindMove(s.board) ~= nil, true, "thawed, it's a move")
    -- A relic swaps like a piece, when the other one matches.
    Still()
    s = Hand(Rows({[7] = "TT.T...."}), {[7] = "..r....."}, {goals = {{id = "relic", need = 1}}, exits = {3}, relics = {need = 1, max = 1, cols = {3}, byExit = true}})
    s.relics.onBoard, s.relics.spawned = 1, 1
    local result = B.Swap(s, I(7, 3), I(7, 4))
    equal(result.ok, true, "a relic swapped with a tauren that lines up three: a move")
    equal(B.Swap(s, I(1, 1), I(1, 2)).why, "nomatch", "a swap that matches nothing still doesn't")
    Moving()
    -- A Hearthstone needs a match with a relic.
    s = Hand(Rows(), {[1] = ".r......"}, {specials = {[I(1, 1)] = {"hearth"}}})
    equal(B.MoveValue(s.board, I(1, 1), I(1, 2)), nil, "a Hearthstone and a relic: no move")
end

-- 4. Specials with blockers ----------------------------------------------------------------------------

do
    Still()
    -- Four in a line, the middle one frozen: the Charge goes on a cleared one.
    local s = Hand(Rows({[5] = "HHHH...."}), {[5] = ".i......"})
    local step = B.Settle(s).steps[1]
    equal(#step.made, 1, "four in a line makes a Charge")
    equal(step.made[1].i ~= I(5, 2) and step.made[1].piece.special, "charge", "never on the frozen piece")
    -- All four frozen: no special.
    s = Hand(Rows({[5] = "HHHH...."}), {[5] = "iiii...."})
    step = B.Settle(s).steps[1]
    equal(#step.made .. " " .. #step.cleared, "0 0", "four frozen in a line: they crack, nothing cleared, no special")
    -- A Hearthstone swapped with an orc: plain orcs go, frozen ones crack, webbed ones go.
    s = Hand(Rows({[1] = ".O......", [3] = "O.O.O...", [8] = ".......O"}), {[3] = "..i.w..."}, {specials = {[I(1, 1)] = {"hearth"}}})
    local result = B.Swap(s, I(1, 1), I(1, 2))
    step = result.steps[1]
    equal(Cleared(step), table.concat({I(1, 1), I(1, 2), I(3, 1), I(3, 5), I(8, 8)}, " "), "the Hearthstone, the plain and webbed orcs go")
    equal(Hits(step), I(3, 3) .. ":ice:0 " .. I(3, 5) .. ":web:0", "the frozen orc cracks, the web breaks")
    Moving()
    -- The flyer's target: a crate first, then a skull, ice, a web, oil, under a relic, anything.
    s = Hand(Rows(), {[2] = "2s.iw..r"}, {oil = {[I(5, 5)] = 1}})
    local function Target() return B.Cell(B.FlyerTarget(s, {})[1]) end
    local order = {}
    for _ = 1, 6 do
        local list = B.FlyerTarget(s, {})
        local i = list[1]
        local p = s.board[i]
        local r, c = B.Cell(i)
        order[#order + 1] = p.block or (p.ice and "ice") or (p.web and "web") or ((s.cells[i] or {}).oil and "oil")
            or ((c == 8 and r > 2 and #list == 6) and "under") or "any"
        for _, j in ipairs(list) do s.board[j] = B.Make(s, nil, {kind = "x" .. j}) end
        if order[#order] == "oil" then s.cells[i] = nil end
    end
    equal(table.concat(order, " "), "crate skull ice web oil under", "a flyer goes for a crate, a skull, ice, a web, oil, then under a relic")
    local clear = {}
    for r = 3, 8 do clear[I(r, 8)] = true end
    local any = B.FlyerTarget(s, clear)
    local relic = false
    for _, i in ipairs(any) do if i == I(2, 8) or clear[i] then relic = true end end
    equal(#any .. " " .. tostring(relic), "57 false", "then any piece not already hit (never the relic)")
    local _ = Target
end

-- 4b. A special swapped with any piece fires at once -------------------------------------------------------

do
    Still()
    -- A Charge for the row moved up a row: it fires row 3, every blocker on it hit, and uses a move.
    local s = Hand(Rows(), {[3] = "2.i.s..."}, {moves = 10, specials = {[I(4, 4)] = {"charge", "row"}}})
    local result = B.Swap(s, I(4, 4), I(3, 4))
    local step = result.steps[1]
    equal(tostring(result.ok) .. " " .. tostring(result.lone) .. " " .. tostring(result.combo) .. " " .. s.movesLeft .. " " .. tostring(result.used),
        "true " .. I(3, 4) .. " nil 9 true", "a Charge and a plain piece: it fires, no match needed, one move used")
    equal(Hits(step), I(3, 1) .. ":crate:1 " .. I(3, 3) .. ":ice:0 " .. I(3, 5) .. ":skull:0",
        "along its row: the crate loses a hit, the ice cracks, the skull breaks")
    equal(Cleared(step), table.concat({I(3, 2), I(3, 4), I(3, 6), I(3, 7), I(3, 8)}, " "), "the plain pieces go, and the Charge")
    -- A flyer still goes for a crate first.
    s = Hand(Rows(), {[1] = "....2..."}, {specials = {[I(4, 4)] = {"flyer"}}})
    step = B.Swap(s, I(4, 4), I(4, 5)).steps[1]
    equal(step.fired[1].special .. " " .. step.fired[1].i .. " " .. step.fired[1].target .. " | " .. Hits(step),
        "flyer " .. I(4, 5) .. " " .. I(1, 5) .. " | " .. I(1, 5) .. ":crate:1", "a flyer swapped with a piece: off to the crate")
    -- Goals count what it clears.
    s = Hand(Rows({[4] = "H.H.H..."}), nil, {goals = {{id = "collect", token = "foe1", need = 5}, {id = "enemy", need = 9}},
        specials = {[I(5, 4)] = {"charge", "row"}}})
    result = B.Swap(s, I(5, 4), I(4, 4))
    equal(Goals(s) .. " " .. tostring(result.outcome), "3 3 nil", "a Charge moved up through three humans: 3 humans, 3 Alliance pieces")
    -- The boss: its pieces and the Charge's 40, no combo's 150.
    s = Hand(Rows(), nil, {goals = {{id = "boss", need = 1, name = "Hogger"}}, specials = {[I(4, 4)] = {"charge", "row"}},
        boss = {key = "elwynn", name = "Hogger", hp = 1000, every = 3, actions = {{kind = "oil", count = 3}}}})
    step = B.Swap(s, I(4, 4), I(4, 5)).steps[1]
    equal(step.damage .. " " .. s.boss.hp, "120 880", "a Charge fired on its own hits the boss as any Charge: 8 x 10 + 40")
    -- Bloodlust / Heroism: its clear fills the meter like any.
    s = Hand(Rows({[4] = "HHDNHDNH"}), nil, {specials = {[I(5, 4)] = {"sheep"}}})
    s.meter = B.METER_FULL - 2
    result = B.Swap(s, I(5, 4), I(5, 5))
    equal(tostring(result.lustStep) .. " " .. s.lust .. " " .. s.meter, "1 3 0", "a Sheep's blast through three Alliance pieces lights Bloodlust: 3 moves of it")
    -- A Free swap sets it off too, with no move used.
    s = Hand(Rows(), nil, {moves = 5, specials = {[I(4, 4)] = {"sheep"}}})
    result = B.Swap(s, I(4, 4), I(4, 5), {free = true})
    equal(#result.steps[1].cleared .. " " .. s.movesLeft .. " " .. tostring(result.free) .. " " .. tostring(result.lone), "9 5 true " .. I(4, 5),
        "a Free swap with a Sheep: it fires, no move used")

    -- Locked pieces, holes and relics still can't set it off (with a relic it needs a match).
    s = Hand(Rows(), {[1] = ".2......", [2] = "#.r.....", [3] = ".i......"}, {specials = {[I(2, 2)] = {"sheep"}}})
    equal(tostring(B.Swap(s, I(2, 2), I(1, 2)).what) .. " " .. tostring(B.Swap(s, I(2, 2), I(3, 2)).what), "crate ice",
        "a Sheep beside a crate or a frozen piece: they can't move")
    equal(B.Swap(s, I(2, 2), I(2, 1)).why .. " " .. B.Swap(s, I(2, 2), I(2, 3)).why, "far nomatch", "nor into a hole; with a relic it needs a match")
    equal(tostring(B.MoveValue(s.board, I(2, 2), I(2, 3))) .. " " .. tostring(B.GoalValue(s, I(2, 2), I(2, 3))), "nil nil",
        "so the Sheep and the relic are no move")
    equal(B.FindMove(s.board) == nil and B.Hint(s.board) == nil and B.GoalHint(s) == nil, true, "boxed in like that: no move, no hint")
    Moving()
    equal(B.Unstick(s) and s.board[I(2, 2)].special .. " " .. tostring(B.FindMove(s.board) ~= nil), "sheep true",
        "so it's shuffled (the Sheep kept where it is) into a board with a move")
    Still()
    s = Hand(Rows(), {[1] = ".2......", [2] = "#.r.....", [3] = ".i......"}, {specials = {[I(2, 2)] = {"sheep"}}})
    s.board[I(3, 2)] = B.Make(s, s.board[I(3, 2)], {ice = false})
    local a, b = B.FindMove(s.board)
    equal(a .. " " .. b, I(2, 2) .. " " .. I(3, 2), "thawed, the piece below it and the Sheep are a move")
    equal(B.GoalHint(s) ~= nil and B.Swap(s, I(2, 2), I(3, 2)).ok, true, "a hint, and it plays")

    -- The goal hint fires a Charge where it serves the goal.
    s = Hand(Rows({[6] = "H.H.H.H."}), nil, {goals = {{id = "collect", token = "foe1", need = 9}}, specials = {[I(5, 1)] = {"charge", "row"}}})
    a, b = B.GoalHint(s)
    equal(a .. " " .. b, I(5, 1) .. " " .. I(6, 1), "the goal hint: move the Charge down onto the humans' row")
    B.Swap(s, a, b)
    equal(Goals(s), "3", "three humans cleared (the fourth swapped up out of the row)")
    -- A swap lining up three humans along the Charge's own line: worth what
    -- the line alone is worth, each cell once (the cells beside the match too).
    local goal = {{id = "collect", token = "foe1", need = 9}}
    s = Hand(Rows({[4] = ".HH.H..."}), nil, {goals = goal, specials = {[I(4, 4)] = {"charge", "row"}}})
    local shared = B.GoalValue(s, I(4, 4), I(4, 5))
    s = Hand(Rows({[4] = "H.H.H..."}), nil, {goals = goal, specials = {[I(4, 4)] = {"charge", "row"}}})
    local alone = B.GoalValue(s, I(4, 4), I(4, 5))
    equal(type(shared) == "number" and math.abs(shared - alone) < 1e-9, true,
        ("a row Charge over the three it lines up: %s, as the row alone (%s)"):format(tostring(shared), tostring(alone)))
    s = Hand(Rows({[2] = "...H....", [3] = "...H....", [5] = "...H...."}), nil, {goals = goal, specials = {[I(4, 4)] = {"charge", "col"}}})
    shared = B.GoalValue(s, I(4, 4), I(5, 4))
    s = Hand(Rows({[1] = "...H....", [3] = "...H....", [5] = "...H...."}), nil, {goals = goal, specials = {[I(4, 4)] = {"charge", "col"}}})
    alone = B.GoalValue(s, I(4, 4), I(5, 4))
    equal(type(shared) == "number" and math.abs(shared - alone) < 1e-9, true,
        ("a column Charge down the three it lines up: %s, as the column alone (%s)"):format(tostring(shared), tostring(alone)))
    Moving()
end

-- 5. Relics -------------------------------------------------------------------------------------------

do
    Still()
    -- A relic on row 5 over column 3's exit; three humans under it go: it falls to row 8 and leaves.
    local s = Hand(Rows({[6] = "..H.....", [7] = "..H.....", [8] = "..H....."}), {[5] = "..r....."},
        {goals = {{id = "relic", need = 2}}, exits = {3, 6}, relics = {need = 2, max = 1, cols = {3, 6}, byExit = true}})
    s.relics.onBoard, s.relics.spawned = 1, 1
    local result = B.Settle(s)
    local kinds = {}
    for _, step in ipairs(result.steps) do kinds[#kinds + 1] = step.kind end
    equal(table.concat(kinds, ","), "clear,exit", "a clear, then the relic's exit")
    local exit = result.steps[2]
    equal(#exit.relicsOut .. " " .. exit.relicsOut[1].i, "1 " .. I(8, 3), "it leaves from the exit cell")
    equal(Goals(s) .. " " .. s.relics.out .. " " .. s.relics.onBoard, "1 1 0", "the goal ticks; out 1, none on the board")
    equal(exit.fall[I(8, 3)] ~= nil and exit.relicsIn == nil, true, "the exit's own fall (column 3 only: no relic due there)")
    for r = 6, 8 do s.board[I(r, 6)] = B.Make(s, nil, {kind = "dwarf"}) end
    result = B.Settle(s)
    equal(result.steps[1].relicsIn and result.steps[1].relicsIn[1].i, I(1, 6), "the next relic drops in the next exit's column once it has a gap")
    equal(s.relics.spawned .. " " .. s.relics.onBoard .. " " .. s.board[I(1, 6)].relic, "2 1 2", "spawned 2, on the board 1, its look the 2nd")
    -- On row 8 away from an exit: it stays.
    s = Hand(Rows({[7] = "TTT....."}), {[8] = "r......."}, {goals = {{id = "relic", need = 1}}, exits = {3}, relics = {need = 1, max = 1, cols = {3}, byExit = true}})
    s.relics.onBoard, s.relics.spawned = 1, 1
    result = B.Settle(s)
    equal(#result.steps .. " " .. s.board[I(8, 1)].block, "1 relic", "on row 8 of column 1 (no exit) it stays")
    -- Spawning: none due once the board holds max, or all are made.
    s.relics.onBoard = 1
    local fall = B.LevelFall(s, false)
    equal(fall ~= nil and s.relics.spawned, 1, "max on the board: no new relic")
    -- The Mallet refuses a relic; a Charge passes it by.
    equal(B.Smash(s, I(8, 1)).why, "relic", "a relic can't be smashed")
    Moving()
end

-- 6. Goals and the end -------------------------------------------------------------------------------

do
    Still()
    -- Collect and enemy (the Horde's foes are the Alliance's races).
    local s = Hand(Rows({[4] = "HH.H....", [5] = "..O....."}), nil,
        {goals = {{id = "collect", token = "foe1", need = 3}, {id = "enemy", need = 3}}, moves = 1})
    equal(s.goals[1].race .. " " .. s.goals[2].foe, "human Alliance", "a Horde player's foe1 is human, foes the Alliance")
    local result = B.Swap(s, I(5, 3), I(4, 3))
    equal(result.ok, false, "orc into the gap: no match")
    result = B.Swap(s, I(4, 3), I(5, 3))
    equal(result.ok, false, "and the other way")
    s = Hand(Rows({[4] = "HH.H....", [5] = "..H....."}), nil,
        {goals = {{id = "collect", token = "foe1", need = 3}, {id = "enemy", need = 3}}, moves = 1})
    result = B.Swap(s, I(5, 3), I(4, 3))
    equal(Goals(s) .. " " .. tostring(result.outcome) .. " " .. s.movesLeft, "3 3 won 0", "three humans on the last move: won")
    equal(B.Outcome(s), "won", "Outcome says so")
    local before = s.score
    local done = B.Finish(s)
    equal(done.bonus .. " " .. s.score, "0 " .. before, "no moves left: no bonus")
    -- Lost: the last move doesn't finish it.
    s = Hand(Rows({[4] = "HH.H....", [5] = "..H....."}), nil, {goals = {{id = "collect", token = "foe1", need = 9}}, moves = 1})
    result = B.Swap(s, I(5, 3), I(4, 3))
    equal(result.outcome .. " " .. B.Outcome(s), "lost lost", "out of moves: lost")
    equal(B.Swap(s, I(1, 1), I(1, 2)).why, "over", "no move after the end")
    equal(B.Result(s).won, false, "the result: not won")
    -- The moves-left bonus, once.
    s = Hand(Rows({[4] = "HH.H....", [5] = "..H....."}), nil, {goals = {{id = "score", need = 30}}, moves = 9, stars = {3, 6}})
    B.Swap(s, I(5, 3), I(4, 3))
    equal(s.outcome .. " " .. s.movesLeft, "won 8", "a score goal met with 8 moves left")
    before = s.score
    done = B.Finish(s)
    equal(done.bonus .. " " .. s.score, (8 * B.MOVE_BONUS) .. " " .. (before + 8 * B.MOVE_BONUS), "8 moves add their bonus")
    B.Finish(s)
    equal(s.score, before + 8 * B.MOVE_BONUS, "only once")
    equal(B.Stars(s), 3, "stars by moves to spare: 8 left, 6 for 3 stars")
    s.movesLeft = 4
    equal(B.Stars(s), 2, "4 left: 2 stars (3 for 2)")
    s.movesLeft = 2
    equal(B.Stars(s), 1, "2 left: 1 star, however high the score")
    s.movesLeft, s.extra = 8, 1
    equal(B.Stars(s), 1, "a win after +5 moves: 1 star")
    s.movesLeft, s.extra = 8, 0
    equal(Dump(B.StarMarks(20)) .. " " .. Dump(B.StarMarks(16)) .. " " .. Dump(B.StarMarks(2)),
        Dump({5, 10}) .. " " .. Dump({4, 8}) .. " " .. Dump({1, 2}), "the marks: a quarter and half the moves to spare, 2 above 1 at least")
    local r = B.Result(s)
    equal(Dump({r.won, r.stars, r.score, r.movesLeft, r.epics, r.boss}), Dump({true, done.stars, s.score, 8, 0, false}),
        "the result for MiniGames.Progress:Finish")
    -- Its text.
    equal(B.GoalText({id = "collect", token = "foe1", need = 10}, "Alliance") .. "; " .. B.GoalText({id = "collect", token = "pal3", need = 1}, "Horde")
        .. "; " .. B.GoalText({id = "enemy", need = 30}, "Horde") .. "; " .. B.GoalText({id = "relic", need = 1}) .. "; "
        .. B.GoalText({id = "boss", name = "Hogger"}) .. "; " .. B.GoalShort({have = 14, need = 20}),
        "Clear 10 orcs; Clear 1 undead; Clear 30 Alliance pieces; Bring down 1 relic; Defeat Hogger; 14/20", "goals in words")
    Moving()
end

-- 7. Bloodlust / Heroism by moves ---------------------------------------------------------------------

do
    Still()
    local s = Hand(Rows({[4] = "HH.H....", [5] = "..H....."}))
    s.meter = B.METER_FULL - 2
    local result = B.Swap(s, I(5, 3), I(4, 3))
    equal(result.lustStep .. " " .. s.lust .. " " .. s.meter, "1 3 0", "the meter fills on the move: 3 moves of it, the move that lit it not counted")
    equal(B.Tick(s, 60), false, "time does nothing in a level")
    equal(s.lust, 3, "still 3")
    for move = 1, 3 do
        s.board[I(6, 1)], s.board[I(6, 2)], s.board[I(7, 3)] = B.Make(s, nil, {kind = "orc"}), B.Make(s, nil, {kind = "orc"}), B.Make(s, nil, {kind = "orc"})
        s.board[I(6, 3)] = B.Make(s, nil, {kind = "x9" .. move})
        result = B.Swap(s, I(7, 3), I(6, 3))
        equal(result.steps[1].mult, 2, "move " .. move .. ": double points")
        equal(tostring(result.lustOver) .. " " .. s.lust, move == 3 and "true 0" or ("nil " .. (3 - move)), "move " .. move .. ": its count")
    end
    local free = B.New(Script(), "Horde")
    free.lust = B.LUST_TIME
    equal(tostring(B.Tick(free, B.LUST_TIME)), "true", "Free play still runs on seconds")
    Moving()
end

-- 8. The boss ----------------------------------------------------------------------------------------------

do
    Still()
    local function Boss(rows, marks, opts)
        opts = opts or {}
        opts.goals = {{id = "boss", need = 1, name = "Hogger"}}
        opts.boss = opts.boss or {key = "elwynn", name = "Hogger", hp = 1000, every = opts.every or 3,
            actions = opts.actions or {{kind = "oil", count = 3}}}
        return Hand(rows, marks, opts)
    end
    -- Three humans (foes to the Horde): 3 x 15.
    local s = Boss(Rows({[4] = "HH......", [5] = "..H....."}))
    local step = B.Swap(s, I(5, 3), I(4, 3)).steps[1]
    equal(step.damage .. " " .. s.boss.hp, "45 955", "three foes: 15 each")
    -- Three orcs (your own): 10 each; doubled in Bloodlust; halved with his mess up.
    s = Boss(Rows({[4] = "OO......", [5] = "..O....."}))
    s.lust = 2
    step = B.Swap(s, I(5, 3), I(4, 3)).steps[1]
    equal(step.damage, 60, "three of yours in Bloodlust: 30 x 2")
    s = Boss(Rows({[4] = "OO......", [5] = "..O....."}), {[8] = ".......b"})
    step = B.Swap(s, I(5, 3), I(4, 3)).steps[1]
    equal(step.damage .. " " .. tostring(step.shielded) .. " " .. tostring(B.Shielded(s)), "15 true true", "his skull on the board: half damage")
    s = Boss(Rows({[4] = "OO......", [5] = "..O....."}), {[8] = ".......s"})
    step = B.Swap(s, I(5, 3), I(4, 3)).steps[1]
    equal(step.damage .. " " .. tostring(step.shielded), "30 false", "a skull of the level's own: no shield")
    -- A Charge firing: +40; a chain's second step x 1.1.
    s = Boss(Rows({[4] = "OO......", [5] = "..O....."}), nil, {specials = {[I(4, 1)] = {"charge", "col"}}})
    step = B.Swap(s, I(5, 3), I(4, 3)).steps[1]
    equal(step.damage, (#step.cleared - 0) * 10 + 40 - (function() local f = 0; for _, g in ipairs(step.cleared) do if B.Enemy(s, g.piece) then f = f + 5 end end; return -f end)(),
        "a Charge firing adds 40 to its pieces' damage")
    local chain = {plan = {index = 2}}
    local sc = Boss(Rows({[4] = "OOO....."}))
    local stepped = B.LevelStep(sc, {groups = B.FindGroups(sc.board), index = 2})
    equal(stepped.damage, 33, "the second step of a chain: 30 x 1.1")
    local _ = chain
    -- A combo: two Charges swapped, +150.
    s = Boss(Rows(), nil, {specials = {[I(4, 4)] = {"charge", "row"}, [I(4, 5)] = {"charge", "col"}}})
    local result = B.Swap(s, I(4, 4), I(4, 5))
    equal(result.combo, "charges", "two Charges swapped")
    equal(result.steps[1].damage, #result.steps[1].cleared * 10 + 150, "their pieces plus 150 (the spent Charges don't fire again)")
    -- His countdown: every 2; he acts after the second move (oil 3 on plain pieces).
    s = Boss(Rows({[4] = "OO....T.", [5] = "..O..TT.", [6] = ".....T.."}), nil, {every = 2})
    result = B.Swap(s, I(5, 3), I(4, 3))
    equal(s.boss.timer .. " " .. tostring(result.bossActed), "1 nil", "move 1: his countdown 2 to 1")
    result = B.Swap(s, I(6, 6), I(6, 7))
    if not result.ok then result = B.Swap(s, I(5, 6), I(5, 7)) end
    equal(result.bossActed ~= nil and result.bossActed.kind, "boss", "move 2: he acts")
    local acted = result.bossActed
    equal(#acted.cells .. " " .. acted.action .. " " .. acted.text .. " " .. s.boss.timer, "3 oil Hogger spills oil. 2", "three cells of oil, his words, the countdown back to 2")
    local okCells = 0
    for _, i in ipairs(acted.cells) do
        if (s.cells[i].oil or 0) >= 1 and (s.cells[i].bossOil or 0) >= 1 and acted.oil[i] == s.cells[i].oil then okCells = okCells + 1 end
    end
    equal(okCells, 3, "each with his oil (shield) marked")
    equal(B.Shielded(s), true, "his mess: shielded")
    -- While shielded his countdown keeps going: he strikes on time, as his intro says.
    local timer = s.boss.timer
    s.board[I(1, 1)], s.board[I(1, 2)], s.board[I(2, 3)] = B.Make(s, nil, {kind = "dwarf"}), B.Make(s, nil, {kind = "dwarf"}), B.Make(s, nil, {kind = "dwarf"})
    s.board[I(1, 3)] = B.Make(s, nil, {kind = "x700"})
    B.Swap(s, I(2, 3), I(1, 3))
    equal(B.Shielded(s) and s.boss.timer, timer - 1, "his countdown keeps going while his mess is up")
    -- Each action on plain pieces only, never holes, relics, specials or blockers.
    for _, action in ipairs({{kind = "freeze", count = 3}, {kind = "crates", count = 2, hits = 2}, {kind = "skulls", count = 2},
        {kind = "web", count = 3}, {kind = "oil", count = 3, layers = 2}}) do
        s = Boss(Rows(), {[1] = "#r1s.iw.", [2] = "#......."}, {actions = {action}, specials = {[I(2, 2)] = {"sheep"}}})
        local before = B.Copy(s.board)
        acted = B.BossAct(s)
        local wrong = 0
        for _, i in ipairs(acted.cells) do
            local was = before[i]
            if not B.Plain(was) then wrong = wrong + 1 end
            if action.kind == "crates" and select(1, B.Cell(i)) > 2 then wrong = wrong + 1 end
        end
        equal(#acted.cells .. " " .. wrong, action.count .. " 0", action.kind .. ": " .. action.count .. " plain pieces, none else"
            .. (action.kind == "crates" and ", in the top two rows" or ""))
        local p = s.board[acted.cells[1]]
        local made = action.kind == "freeze" and p.ice == 1 and p.boss or action.kind == "crates" and p.block == "crate" and p.hits == 2
            or action.kind == "skulls" and p.block == "skull" or action.kind == "web" and p.web or action.kind == "oil" and s.cells[acted.cells[1]].oil == 2
        equal(made and true, true, action.kind .. ": made as it says")
    end
    -- His mess never goes past Blast.MESS_CAP: with no room he waits.
    s = Boss(Rows(), {[1] = "bbbbbbbb"})
    equal(B.BossAct(s), nil, "8 of his skulls up: he waits")
    -- No action on the winning move; defeat at 0.
    s = Boss(Rows({[4] = "HH......", [5] = "..H....."}), nil, {every = 1})
    s.boss.hp = 40
    result = B.Swap(s, I(5, 3), I(4, 3))
    equal(s.boss.hp .. " " .. result.outcome .. " " .. tostring(result.bossActed) .. " " .. Goals(s), "0 won nil 1", "the move that beats him: won, he doesn't act")
    equal(B.Result(s).boss, true, "a boss level's result")
    Moving()
end

-- 9. Power-ups and boosters --------------------------------------------------------------------------------

do
    Still()
    local s = Hand(Rows(), {[8] = ".2sIw..."}, {moves = 7, specials = {[I(6, 6)] = {"charge", "row"}}})
    local result = B.Smash(s, I(1, 1))
    equal(result.ok and Cleared(result.steps[1]) .. " " .. s.movesLeft, I(1, 1) .. " 7", "the Mallet clears a piece, no move used")
    result = B.Smash(s, I(6, 6))
    equal(#result.steps[1].cleared, 8, "on a Charge: it fires along its row")
    equal(Hits(B.Smash(s, I(8, 2)).steps[1]), I(8, 2) .. ":crate:1", "a crate loses a hit")
    equal(Hits(B.Smash(s, I(8, 3)).steps[1]), I(8, 3) .. ":skull:0", "a skull breaks")
    equal(Hits(B.Smash(s, I(8, 4)).steps[1]), I(8, 4) .. ":ice:1", "thick ice cracks")
    equal(Hits(B.Smash(s, I(8, 5)).steps[1]), I(8, 5) .. ":web:0", "a web goes with its piece")
    equal(B.Smash(s, 65).why .. " " .. B.Smash(s, "x").why, "empty empty", "nothing there: refused")
    -- Shuffle: blockers, specials and frozen pieces stay; a move, no match.
    s = Hand(Rows(), {[2] = ".2sIw.r."}, {specials = {[I(5, 5)] = {"sheep"}}})
    for i = 1, 64 do if B.Plain(s.board[i]) then s.board[i] = B.Make(s, s.board[i], {kind = "orc"}) end end
    local before = B.Copy(s.board)
    s.kinds = B.KindsFor(6, "Horde")
    Moving()
    result = B.Shuffle(s)
    local kept = true
    for i = 1, 64 do
        local was, now = before[i], s.board[i]
        if not B.Plain(was) and was ~= now then kept = false end
    end
    equal(result.shuffled and kept, true, "Shuffle keeps every blocker, relic, special and frozen piece where it was")
    equal(#B.FindGroups(s.board) == 0 and B.FindMove(s.board) ~= nil and s.movesLeft == 20, true, "no match, a move, no move used")
    -- Free swap: no match needed, no move used; a locked piece still refused.
    Still()
    s = Hand(Rows(), {[2] = "i......."}, {moves = 5})
    local a, b = s.board[I(4, 4)], s.board[I(4, 5)]
    result = B.Swap(s, I(4, 4), I(4, 5), {free = true})
    equal(tostring(result.ok) .. " " .. tostring(result.free) .. " " .. s.movesLeft .. " " .. tostring(s.board[I(4, 4)] == b and s.board[I(4, 5)] == a),
        "true true 5 true", "a Free swap with no match: swapped, no move used")
    equal(B.Swap(s, I(2, 1), I(2, 2), {free = true}).why, "locked", "a frozen piece still can't be swapped")
    local relic = Hand(Rows(), {[7] = "r......."}, {goals = {{id = "relic", need = 1}}, exits = {1}, relics = {need = 1, max = 1, cols = {1}, byExit = true}})
    relic.relics.onBoard, relic.relics.spawned = 1, 1
    result = B.Swap(relic, I(7, 1), I(8, 1), {free = true})
    equal(result.steps[1] and result.steps[1].kind .. " " .. relic.outcome, "exit won", "a Free swap that puts a relic on its exit: it leaves")
    -- +5 moves: on a lost level it carries on.
    s.movesLeft, s.outcome = 0, "lost"
    equal(B.AddMoves(s, 5) .. " " .. tostring(s.outcome) .. " " .. s.extra, "5 nil 1", "+5 moves on the lose card: 5 moves, carried on, extra 1")
    equal(B.AddMoves(s, 5) .. " " .. s.extra, "10 1", "+5 moves mid-level: no extra")
    Moving()
    -- Boosters: a Charge, a Sheep and Bloodlust to start.
    local state = B.NewLevel(12, PM(5), "Horde", {charge = true, sheep = true, lust = true})
    local charge, sheep = state.board[state.boosted.charge], state.board[state.boosted.sheep]
    equal(charge.special .. " " .. tostring(charge.dir == "row" or charge.dir == "col") .. " " .. sheep.special .. " " .. state.lust,
        "charge true sheep 3", "a Charge, a Sheep and 3 moves of Bloodlust")
    equal(charge.ice == nil and charge.web == nil and sheep.ice == nil and state.boosted.charge ~= state.boosted.sheep, true,
        "on plain pieces, two different ones")
    equal(#B.FindGroups(state.board), 0, "no match made by them")
end

-- 10. Keeping a level ------------------------------------------------------------------------------------------

do
    local function Round(state, label)
        local saved = B.SaveLevel(state)
        local back = B.LoadLevel(saved, PM(1), state.faction)
        equal(back ~= nil, true, label .. ": read back")
        equal(Dump(B.SaveLevel(back)), Dump(saved), label .. ": exactly as kept")
        return saved, back
    end
    -- Mid-level with every blocker: level 19 after a few moves.
    local s = B.NewLevel(19, PM(19), "Horde")
    for _ = 1, 4 do local a, b = B.GoalHint(s); B.Swap(s, a, b) end
    local saved = Round(s, "level 19 mid-way (ice, thick ice, crates)")
    equal(saved.board:find("*i2", 1, true) ~= nil and saved.board:find("@crate", 1, true) ~= nil, true, "its tokens hold thick ice and crates")
    -- A boss with his mess up.
    local function Spilt(state)
        for i = 1, 64 do if state.cells[i] and (state.cells[i].bossOil or 0) > 0 then return true end end
        return false
    end
    for seed = 1, 20 do
        s = B.NewLevel(10, PM(seed), "Alliance")
        while not s.outcome and not Spilt(s) do local a, b = B.GoalHint(s); B.Swap(s, a, b) end
        if Spilt(s) and not s.outcome then break end
    end
    equal(Spilt(s) and not s.outcome, true, "Hogger spilt oil in one of 20 tries")
    saved = Round(s, "Hogger with his oil up")
    equal(saved.bossOil ~= nil and saved.boss.hp == s.boss.hp, true, "his oil and health kept")
    -- Relics mid-way.
    s = B.NewLevel(24, PM(24), "Horde")
    for _ = 1, 6 do if not s.outcome then local a, b = B.GoalHint(s); B.Swap(s, a, b) end end
    saved = Round(s, "level 24 with relics")
    equal(saved.relics.spawned, saved.relics.onBoard + saved.relics.out, "relics counted")
    -- Webs, skulls and boss-made blockers.
    s = Hand(Rows(), {[1] = "wbs3r..."}, {goals = {{id = "web", need = 1}}, bossMade = {[I(1, 1)] = true}})
    s.spec.grid = B.LEVELS[1].grid
    saved = B.SaveLevel(s)
    equal(saved.board:sub(1, 30):find("*w*b", 1, true) ~= nil and saved.board:find("@skull*b", 1, true) ~= nil, true,
        "a webbed piece and a skull the boss made are marked *b")
    -- Lost, waiting on the lose card.
    s = B.NewLevel(2, PM(2), "Horde")
    s.movesLeft, s.outcome = 0, "lost"
    saved = B.SaveLevel(s)
    local back = B.LoadLevel(saved, PM(1), "Horde")
    equal(back and back.outcome, "lost", "a lost level waits on its lose card")
    -- The other faction: level 3 (five races) kept by an Alliance player, read by a Horde one.
    s = B.NewLevel(3, PM(3), "Alliance")
    saved = B.SaveLevel(s)
    back = B.LoadLevel(saved, PM(1), "Horde")
    equal(back ~= nil and #B.FindGroups(back.board), 0, "kept on the Alliance, read on the Horde")
    local allowed = {}
    for _, kind in ipairs(back.kinds) do allowed[kind] = true end
    local stray = 0
    for i = 1, 64 do if back.board[i] and back.board[i].kind and not allowed[back.board[i].kind] then stray = stray + 1 end end
    equal(stray .. " " .. back.goals[1].race, "0 human", "its races fit the Horde's five; foe1 is now human")
    -- Each damage refused.
    s = B.NewLevel(19, PM(7), "Horde")
    local good = B.SaveLevel(s)
    local function Bad(change, label)
        local copy = {}
        for key, value in pairs(good) do copy[key] = type(value) == "table" and {} or value end
        for key, value in pairs(good) do if type(value) == "table" then for k, v in pairs(value) do copy[key][k] = v end end end
        change(copy)
        equal(B.LoadLevel(copy, PM(1), "Horde"), nil, label .. ": refused")
    end
    Bad(function(t) t.v = 2 end, "another version")
    Bad(function(t) t.mode = "free" end, "not a level")
    Bad(function(t) t.board = t.board:gsub(",[^,]*$", "") end, "63 tokens")
    Bad(function(t) t.board = "#," .. t.board:gsub("^[^,]*,", "") end, "a hole where the level has none")
    Bad(function(t) t.board = "gnoll," .. t.board:gsub("^[^,]*,", "") end, "a race that isn't one")
    Bad(function(t) t.board = "orc*i3," .. t.board:gsub("^[^,]*,", "") end, "ice 3")
    Bad(function(t) t.board = "@crate4," .. t.board:gsub("^[^,]*,", "") end, "a 4-hit crate")
    Bad(function(t) t.oil = t.oil:sub(1, 63) .. "3" end, "3 layers of oil")
    Bad(function(t) t.bossOil = ("1"):rep(64) end, "his oil where there's none")
    Bad(function(t) t.movesLeft = 100 end, "100 moves")
    Bad(function(t) t.movesLeft = 2.5 end, "half a move")
    Bad(function(t) t.goals = {99, 0} end, "a goal past its need")
    Bad(function(t) t.goals = {1} end, "a goal missing")
    Bad(function(t) t.meter = B.METER_FULL end, "a full meter")
    Bad(function(t) t.outcome = "lost" end, "lost with moves left")
    Bad(function(t) t.boss = {hp = 5, timer = 1, next = 1} end, "a boss on a level with none")
    Bad(function(t) t.relics = {onBoard = 1, spawned = 1, out = 0} end, "relics on a level with none")
    local row = {}
    for text in (good.board .. ","):gmatch("([^,]*),") do row[#row + 1] = text end
    local kinds = Kinds(s.board)
    local a = I(8, 1)
    local first, second = kinds[I(8, 2)], kinds[I(8, 3)]
    if B.RACE[first] and first == second then
        row[a] = row[I(8, 2)]
        Bad(function(t) t.board = table.concat(row, ",") end, "a match standing")
    else
        row[I(8, 2)], row[I(8, 3)], row[I(8, 1)] = "orc", "orc", "orc"
        Bad(function(t) t.board = table.concat(row, ",") end, "a match standing")
    end
    equal(B.LoadLevel(nil) == nil and B.LoadLevel("x") == nil and B.LoadLevel({v = 1, mode = "level", level = 0}) == nil, true, "nothing kept")
    -- Boss numbers.
    s = B.NewLevel(10, PM(1), "Horde")
    good = B.SaveLevel(s)
    Bad(function(t) t.boss = {hp = s.boss.max + 50, timer = 1, next = 1} end, "health past his most")
    Bad(function(t) t.boss = {hp = 100, timer = 9, next = 1} end, "a countdown past his every")
    Bad(function(t) t.boss = nil end, "a boss level with no boss")
    -- Free play's kept board (version 1) still reads as before.
    local free = B.New(Script(), "Horde")
    local kept = {}
    B.Save(free, kept)
    local again = B.New(Script(), "Horde")
    equal(B.Load(again, kept) and again.board[1].kind == free.board[1].kind and again.mode == nil, true, "Free play's board keeps as it did")
end

-- 11. Levels 1 to 40 as written --------------------------------------------------------------------------------

do
    -- n = {moves, kinds, goals ("id need" or "id token need"), exits, boss hp, every, card}
    local WANT = {
        {16, 5, "collect foe1 14", nil, nil, nil, "goals"}, {16, 5, "collect foe2 20"}, {18, 5, "collect foe1 14, collect foe3 14"},
        {18, 5, "oil 16", nil, nil, nil, "oil"}, {16, 5, "score 1200", nil, nil, nil, "holes"}, {20, 5, "oil 12"},
        {20, 5, "collect foe2 24, oil 8"}, {18, 5, "enemy 50"}, {26, 5, "oil 16"}, {20, 5, "boss 1", nil, 1250, 4, "boss"},
        {16, 5, "ice 14", nil, nil, nil, "ice"}, {20, 5, "ice 8, collect foe1 22"}, {18, 6, "ice 8, collect foe3 14"}, {26, 6, "oil 12, ice 6"},
        {20, 6, "enemy 50"}, {18, 6, "crate 8", nil, nil, nil, "crate"}, {26, 6, "crate 6, collect foe2 12"}, {28, 6, "oil 16, crate 6"},
        {24, 6, "ice 10, crate 4"}, {26, 6, "boss 1", nil, 1350, 4}, {30, 6, "collect foe1 16, collect foe2 16"}, {24, 6, "crate 10"},
        {24, 6, "relic 1", "4,5", nil, nil, "relic"}, {30, 6, "relic 2, oil 10", "2,5"}, {24, 6, "score 2000, crate 6"},
        {24, 6, "relic 2, ice 8", "4,5"}, {26, 6, "oil 12"}, {30, 6, "relic 2, crate 8", "2,7"}, {28, 6, "ice 12, oil 12, collect foe3 14"},
        {28, 6, "boss 1", nil, 1550, 4}, {26, 6, "enemy 60, oil 12"}, {20, 6, "web 8", nil, nil, nil, "web"}, {24, 6, "web 10, collect pal1 16"},
        {28, 6, "relic 2, web 6", "3,6"}, {26, 6, "crate 12"}, {28, 6, "ice 14, web 6"}, {34, 6, "oil 16, relic 1", "4,5"},
        {28, 6, "score 2400, crate 8, ice 8"}, {36, 6, "relic 2, oil 16, web 6", "3,6"}, {30, 6, "boss 1", nil, 1500, 3, "skull"},
    }
    local ZONES = {"elwynn", "durotar", "westfall", "barrens"}
    for n, want in ipairs(WANT) do
        local spec = B.LevelSpec(n)
        local goals = {}
        for _, goal in ipairs(spec.goals) do goals[#goals + 1] = goal.id .. (goal.token and (" " .. goal.token) or "") .. " " .. goal.need end
        equal(spec.moves .. " " .. spec.kinds .. " " .. table.concat(goals, ", "), want[1] .. " " .. want[2] .. " " .. want[3], "level " .. n)
        equal(spec.exits and table.concat(spec.exits, ",") or nil, want[4], "level " .. n .. ": exits")
        equal(spec.boss and spec.boss.hp, want[5], "level " .. n .. ": boss health")
        equal(spec.boss and spec.boss.every, want[6], "level " .. n .. ": how often he acts")
        equal(spec.card, want[7], "level " .. n .. ": its card")
        equal(spec.zone .. " " .. spec.name, ZONES[math.floor((n - 1) / 10) + 1] .. " " .. B.ZONES[math.floor((n - 1) / 10) + 1].name, "level " .. n .. ": zone")
        equal(spec.stars[1] .. " " .. spec.stars[2], B.StarMarks(spec.moves)[1] .. " " .. B.StarMarks(spec.moves)[2], "level " .. n .. ": star marks (moves to spare)")
        for _, c in ipairs(spec.exits or {}) do
            equal(spec.grid:sub(7 * 9 + c, 7 * 9 + c) ~= "#", true, "level " .. n .. ": exit " .. c .. " on a playable row 8 cell")
        end
    end
    local function Counts(n) return B.GridCounts(B.ParseGrid(B.LevelSpec(n).grid)) end
    equal(Counts(4).oil .. " " .. Counts(4).oilCells .. " " .. Counts(6).oil .. " " .. Counts(6).oilCells .. " " .. Counts(37).oil .. " " .. Counts(37).oilCells,
        "20 16 24 12 18 16", "oil: level 4 20 layers on 16 spots, level 6 24 on 12, level 37 18 on 16 (the goal counts spots)")
    local spots = 0
    for _, goal in ipairs(B.LevelSpec(6).goals) do if goal.id == "oil" then spots = goal.need end end
    equal(spots .. " " .. B.GoalText({id = "oil", need = spots}, "Horde"), "12 Clean 12 oil spots", "level 6 asks for its 12 spots, as the board shows")
    equal(Counts(19).ice .. " " .. Counts(19).iceLayers .. " " .. Counts(22).crate .. " " .. Counts(36).ice .. " " .. Counts(36).web,
        "10 14 10 14 6", "level 19 ice 10 (4 thick), level 22 crates 10, level 36 ice 14 and webs 6")
    equal(B.Zone(10).boss.name .. ", " .. B.Zone(20).boss.name .. ", " .. B.Zone(30).boss.name .. ", " .. B.Zone(40).boss.name,
        "Hogger, Zalazane, Edwin VanCleef, Mutanus the Devourer", "the first four bosses")
end

-- 12. Made levels ----------------------------------------------------------------------------------------------

do
    local real = math.random
    math.random = function() error("a made level used math.random") end
    local first = {}
    for n = 41, 400 do first[n] = Dump(B.LevelSpec(n)) end
    local again = 0
    for n = 41, 400 do if Dump(B.LevelSpec(n)) == first[n] then again = again + 1 end end
    math.random = real
    equal(again, 360, "levels 41 to 400: the same spec every time, with no random")
    -- Read the file again: still the same.
    assert(loadfile("Modules/MiniGameBlastLevels.lua"))("EraUI", M.E)
    local same = 0
    for n = 41, 400 do if Dump(B.LevelSpec(n)) == first[n] then same = same + 1 end end
    equal(same, 360, "and after the file is read again")
    local bad = {}
    local function Bad(n, why) bad[#bad + 1] = n .. " " .. why end
    for n = 41, 400 do
        local spec = B.LevelSpec(n)
        local chars = B.ParseGrid(spec.grid)
        local counts = B.GridCounts(chars)
        local zone, tier, k = B.Zone(n)
        if spec.zone ~= zone.key or spec.name ~= zone.name .. (tier > 0 and (" " .. (tier + 1)) or "") then Bad(n, "zone or name") end
        if (k == 10) ~= (spec.boss ~= nil) then Bad(n, "a boss on the 10th only") end
        if spec.moves < 16 or spec.moves > 40 then Bad(n, "moves " .. spec.moves) end
        if spec.kinds ~= 6 then Bad(n, "six races") end
        local blockers = counts.oilCells + counts.ice + counts.crate + counts.web + counts.relic + counts.skull
        if blockers > counts.playable / 2 then Bad(n, "blockers past half") end
        for r = 1, 8 do
            for c = 1, 4 do
                local a, b = chars[I(r, c)], chars[I(r, 9 - c)]
                if a ~= b and a ~= "r" and b ~= "r" then Bad(n, "not mirrored at " .. r .. "," .. c) end
            end
        end
        for _, goal in ipairs(spec.goals) do
            if not goal.need or goal.need < 1 then Bad(n, goal.id .. " needs nothing") end
        end
        if spec.boss then
            if spec.shape == "PILLARS" then Bad(n, "a boss on Pillars") end
            if spec.boss.hp < 500 or spec.boss.every < 3 then Bad(n, "boss numbers") end
        end
        if spec.exits then
            if spec.exits[1] == 1 or spec.exits[2] == 8 or spec.exits[1] + spec.exits[2] ~= 9 then Bad(n, "exits " .. table.concat(spec.exits, ",")) end
            for _, c in ipairs(spec.relics.cols) do if c ~= spec.exits[1] and c ~= spec.exits[2] then Bad(n, "a relic column off the exits") end end
            if counts.relic ~= 1 then Bad(n, "one relic laid") end
            for r = 1, 8 do
                local ch = chars[I(r, spec.exits[1])]
                if ch == "i" or ch == "I" or ch == "w" or tonumber(ch) then Bad(n, "a blocker in a relic's way") end
            end
        end
    end
    equal(table.concat(bad, "; "), "", "levels 41 to 400: valid (zones, bosses every 10th, moves 16 to 40, mirrored, at most half blockers)")
    equal(B.LevelSpec(101).name .. ", " .. B.LevelSpec(110).boss.name .. ", " .. B.LevelSpec(161).name, "Elwynn Forest 2, Hogger, Tanaris 2",
        "the zones come round again a tier on")
    equal(B.LevelSpec(0) == nil and B.LevelSpec(1.5) == nil and B.LevelSpec("x") == nil, true, "no level 0, 1.5 or x")
    local state = B.NewLevel(57, PM(57), "Horde")
    equal(state ~= nil and #B.FindGroups(state.board) == 0 and B.FindMove(state.board) ~= nil, true, "a made level lays out like any")
end

-- 13. What the view reads ----------------------------------------------------------------------------------------

do
    Still()
    -- Frozen and webbed pieces fall like any piece.
    local s = Hand(Rows({[6] = "O.......", [7] = "O.......", [8] = "O......."}), {[4] = "i.......", [5] = "w......."})
    local frozen, webbed = s.board[I(4, 1)].id, s.board[I(5, 1)].id
    local step = B.Settle(s).steps[1]
    equal(s.board[I(7, 1)].id .. " " .. s.board[I(8, 1)].id .. " " .. step.fall[I(8, 1)], frozen .. " " .. webbed .. " 3",
        "a frozen and a webbed piece fall 3 rows like the rest")
    -- Every field the contract names, on a move of a boss level with relics and blockers.
    s = Hand(Rows({[4] = "HH......", [5] = "..H....."}), {[1] = "r.......", [8] = ".i......"},
        {goals = {{id = "boss", need = 1, name = "Hogger"}}, boss = {key = "elwynn", name = "Hogger", hp = 900, every = 1,
        actions = {{kind = "freeze", count = 2}}}, exits = {1}, relics = {need = 1, max = 1, cols = {1}, byExit = true}})
    s.relics.onBoard, s.relics.spawned = 1, 1
    local result = B.Swap(s, I(5, 3), I(4, 3))
    local missing = {}
    for _, key in ipairs({"ok", "a", "b", "steps", "swapped", "points", "scoreBefore", "meterBefore", "movesLeft", "goals", "used"}) do
        if result[key] == nil then missing[#missing + 1] = "result." .. key end
    end
    step = result.steps[1]
    for _, key in ipairs({"kind", "before", "after", "cleared", "fired", "made", "flashes", "hits", "broken", "fall", "points", "mult",
        "score", "meter", "enemies", "epics", "index", "damage", "shielded", "bossHp", "goals"}) do
        if step[key] == nil then missing[#missing + 1] = "clear step." .. key end
    end
    local acted = result.bossActed
    for _, key in ipairs({"kind", "action", "cells", "oil", "before", "after", "text", "goals"}) do
        if not acted or acted[key] == nil then missing[#missing + 1] = "boss step." .. key end
    end
    equal(table.concat(missing, " "), "", "a level's result and steps carry every field the view reads")
    equal(result.steps[#result.steps] == acted and acted.kind .. " " .. step.kind, "boss clear", "the boss step comes last")
    equal(B.Shielded(s) and step.goals[1] .. " " .. acted.goals[1], "0 0", "goal counts on each step")
    Moving()
end

-- 14. A greedy bot wins each written level often enough ------------------------------------------------------------

do
    local function Play(n, seed)
        local state = B.NewLevel(n, PM(seed * 7777 + n * 13), seed % 2 == 0 and "Alliance" or "Horde")
        local guard = 0
        while not state.outcome and guard < 200 do
            local a, b = B.GoalHint(state)
            assert(a, "level " .. n .. ": the hint found a move")
            local result = B.Swap(state, a, b)
            assert(result.ok, "level " .. n .. ": the hint's move was taken")
            guard = guard + 1
        end
        return state.outcome == "won"
    end
    local short = {}
    for n = 1, 40 do
        local wins = 0
        for seed = 1, 6 do if Play(n, seed) then wins = wins + 1 end end
        if wins < (n <= 10 and 3 or 2) then short[#short + 1] = n .. ":" .. wins .. "/6" end
    end
    equal(table.concat(short, " "), "", "the bot wins levels 1 to 10 at least 3 of 6 times, 11 to 40 at least 2 of 6")
end

print("Blast level checks passed: " .. M.checks .. " assertions.")
