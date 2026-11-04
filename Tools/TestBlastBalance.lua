-- Azeroth Blast's balance (slow: about 7 minutes; run it with the 10-minute timeout). Two bots, a seeded roll
-- per game: greedy (Blast.GoalHint every move) and casual (the best move
-- half the time, any move that matches the other half: closer to a person
-- playing on a flight). Greedy plays 16 games of each written level (1 to
-- 40) and 8 of each made one (41 to 140); casual 12 of each written level.
-- A line a level. Then the bands:
--   greedy wins at least 80% on levels 1 to 10, 60% on 11 to 40 and on every
--   boss; made levels 65% on average, none under 25%, a zone's first two
--   (k 1 and 2) 80% on average;
--   casual wins at least 85% on average on levels 1 to 10 (none under 65%),
--   55% on average on 11 to 40 (none under 30%);
--   not too easy: the pooled greedy median of moves left (levels 5 to 40) at
--   most 45% of the limit, and each level from 5 with no new card at most
--   60% unless its moves are at their floor;
--   stars (casual, levels 1 to 20): 3 stars on 20 to 65% of wins, 2 or 3 on
--   50 to 95%;
--   the bosses of levels 100, 300 and 500 still beatable; levels 400 to 500
--   (every 4th) none a wall for greedy;
--   the calibration inside its knobs (moves within 4 of the design, boss
--   health within 25%); and the coins of playing 1 to 40 through
--   MiniGames.Progress (never below 0, 1,000 earned by level 40, five
--   power-ups affordable by level 20).
-- Knobs: a written level's goals, moves and boss health, Blast.STAR2, STAR3,
-- MOVE_BONUS and BOSS_HP_K, and Blast.WORK, MADE_SQUEEZE, OPENER_MOVES and
-- TIGHT_MOVES (the made levels' moves).
-- Run: fengari Tools/TestBlastBalance.lua
local M = dofile("Tools/MiniGameMock.lua")
local equal = M.equal
local MG = M.Session({only = {"MiniGames", "MiniGameFX", "MiniGameAssets", "MiniGameProgress", "MiniGameBlast",
    "MiniGameBlastGoals", "MiniGameBlastLevels"}})
local B, P = MG.Blast, MG.Progress
local N = B.SIZE

local function PM(seed)
    local s = seed % 2147483647
    if s <= 0 then s = 1 end
    return function(low, high)
        s = (s * 16807) % 2147483647
        return low + math.floor(s / 2147483647 * (high - low + 1))
    end
end
-- Every pair of cells side by side, once.
local PAIRS = {}
for r = 1, N do
    for c = 1, N do
        if c < N then PAIRS[#PAIRS + 1] = {B.Index(r, c), B.Index(r, c + 1)} end
        if r < N then PAIRS[#PAIRS + 1] = {B.Index(r, c), B.Index(r + 1, c)} end
    end
end
-- Any swap that would match, from a rolled place on (the casual bot's other half).
local function AnyMove(state, pick)
    local start = pick(1, #PAIRS)
    for k = 0, #PAIRS - 1 do
        local pair = PAIRS[(start + k - 1) % #PAIRS + 1]
        if B.MoveValue(state.board, pair[1], pair[2]) then return pair[1], pair[2] end
    end
    return nil
end
-- One game: {won, movesLeft, stars, result (for Progress:Finish)}. casual: half its moves any match.
local function Play(n, seed, casual)
    local state = B.NewLevel(n, PM(seed * 7777 + n * 13), seed % 2 == 0 and "Alliance" or "Horde")
    local pick = PM(seed * 31 + 7)
    local guard = 0
    while not state.outcome and guard < 200 do
        local a, b
        if casual and pick(1, 2) == 1 then a, b = AnyMove(state, pick) end
        if not a then a, b = B.GoalHint(state) end
        local result = B.Swap(state, a, b)
        if not result.ok then
            a, b = B.GoalHint(state)
            result = B.Swap(state, a, b)
        end
        assert(a and result.ok, "level " .. n .. ": the bot always has a move")
        guard = guard + 1
    end
    local won = state.outcome == "won"
    local movesLeft = state.movesLeft
    local result = B.Result(state)
    return {won = won, movesLeft = movesLeft, stars = result.stars, result = result, moves = state.spec.moves}
end
local function Median(list)
    if #list == 0 then return nil end
    table.sort(list)
    return list[math.floor((#list + 1) / 2)]
end

-- The design's moves and boss health (Campaign-Design 3.5), before calibration.
local DESIGN = {20, 20, 22, 22, 20, 24, 24, 22, 26, 24, 20, 24, 22, 26, 24, 22, 26, 28, 28, 26, 26, 26, 24, 30, 28, 28, 30, 32,
    32, 28, 30, 24, 28, 30, 30, 32, 34, 32, 36, 30}
local DESIGN_HP = {[10] = 1000, [20] = 1100, [30] = 1250, [40] = 1350}

local games, levels, casuals = {}, {}, {}
local pooled = {}
local function Run(n, seeds, casual)
    local spec = B.LevelSpec(n)
    local wins, lefts, stars, list = 0, {}, {0, 0, 0}, {}
    for seed = 1, seeds do
        local game = Play(n, seed, casual)
        list[seed] = game
        if game.won then
            wins = wins + 1
            lefts[#lefts + 1] = game.movesLeft
            stars[game.stars] = stars[game.stars] + 1
            if n >= 5 and n <= 40 and not casual then pooled[#pooled + 1] = game.movesLeft / spec.moves end
        end
    end
    local median = Median(lefts)
    local row = {spec = spec, wins = wins, seeds = seeds, median = median, stars = stars}
    if casual then casuals[n] = row else games[n], levels[n] = list, row end
    print(("L%-4d %-7s %-22s moves %2d %-9s wins %2d/%2d (%3d%%)  median left %s  stars %d/%d/%d"):format(n, casual and "casual" or "greedy",
        spec.name, spec.moves, spec.boss and ("hp " .. spec.boss.hp) or "", wins, seeds, math.floor(100 * wins / seeds + .5),
        median and ("%2d"):format(median) or " -", stars[1], stars[2], stars[3]))
end
for n = 1, 40 do Run(n, 16) end
for n = 1, 40 do Run(n, 12, true) end
for n = 41, 140 do Run(n, 8) end

-- The calibration stays inside its knobs.
for n = 1, 40 do
    local spec = levels[n].spec
    equal(math.abs(spec.moves - DESIGN[n]) <= 4, true, "level " .. n .. ": moves " .. spec.moves .. " within 4 of the design's " .. DESIGN[n])
    if DESIGN_HP[n] then
        equal(math.abs(spec.boss.hp - DESIGN_HP[n]) <= DESIGN_HP[n] * .25, true, "level " .. n .. ": boss health within 25% of the design's")
    end
end
-- Greedy wins.
local short = {}
for n = 1, 140 do
    local level = levels[n]
    local share = level.wins / level.seeds
    local need = n <= 10 and .8 or n <= 40 and .6 or .25
    if level.spec.boss then need = math.max(need, .6) end
    if share < need then short[#short + 1] = ("%d (%d%% < %d%%)"):format(n, math.floor(100 * share + .5), math.floor(100 * need + .5)) end
end
equal(table.concat(short, ", "), "", "greedy wins: 80% on 1-10, 60% on 11-40 and every boss, 25% on every made level")
local made, total, open, openN = 0, 0, 0, 0
for n = 41, 140 do
    made, total = made + levels[n].wins, total + levels[n].seeds
    if levels[n].spec.k <= 2 then open, openN = open + levels[n].wins, openN + levels[n].seeds end
end
print(("Made levels 41-140: %d%% won, a zone's first two %d%%"):format(math.floor(100 * made / total + .5), math.floor(100 * open / openN + .5)))
equal(made / total >= .65, true, "the made levels: 65% won on average")
equal(open / openN >= .8, true, "a zone's first two made levels open it gently: 80% on average")
-- Casual wins.
local function CasualShare(from, to)
    local wins, seeds, low = 0, 0, 1
    for n = from, to do
        wins, seeds = wins + casuals[n].wins, seeds + casuals[n].seeds
        low = math.min(low, casuals[n].wins / casuals[n].seeds)
    end
    return wins / seeds, low
end
local early, earlyLow = CasualShare(1, 10)
local later, laterLow = CasualShare(11, 40)
print(("Casual: levels 1-10 %d%% (lowest %d%%), 11-40 %d%% (lowest %d%%)"):format(math.floor(100 * early + .5),
    math.floor(100 * earlyLow + .5), math.floor(100 * later + .5), math.floor(100 * laterLow + .5)))
equal(early >= .85 and earlyLow >= .65, true, "a casual player wins levels 1-10 nearly always (85% on average, none under 65%)")
equal(later >= .55 and laterLow >= .3, true, "and most of 11-40 (55% on average, none under 30%)")
-- Not too easy.
local easy = {}
for n = 5, 40 do
    local level = levels[n]
    local floor = level.spec.moves <= DESIGN[n] - 4
    if level.median and level.median > level.spec.moves * .6 and not floor and not level.spec.card then easy[#easy + 1] = n end
end
equal(table.concat(easy, " "), "", "written levels from 5: greedy's median win leaves at most 60% of the moves (bar a new card's level or one at its floor)")
local share = Median(pooled)
print(("Pooled greedy median of moves left on wins (levels 5-40): %d%% of the limit"):format(math.floor(100 * share + .5)))
equal(share <= .45, true, "pooled over levels 5-40: greedy's median win leaves at most 45% of the moves")
-- Stars on levels 1 to 20 (casual).
local wins, two, three = 0, 0, 0
for n = 1, 20 do
    local stars = casuals[n].stars
    wins, two, three = wins + stars[1] + stars[2] + stars[3], two + stars[2] + stars[3], three + stars[3]
end
print(("Stars on levels 1-20 (casual): 3 stars %d%%, 2 or 3 %d%% of wins"):format(math.floor(100 * three / wins + .5), math.floor(100 * two / wins + .5)))
equal(three / wins >= .2 and three / wins <= .65, true, "3 stars on 20 to 65% of casual wins (levels 1-20)")
equal(two / wins >= .5 and two / wins <= .95, true, "2 or 3 stars on 50 to 95% of casual wins (levels 1-20)")
-- Far bosses stay beatable, far levels winnable.
for _, n in ipairs({100, 300, 500}) do
    local beaten = 0
    for seed = 1, 8 do if Play(n, seed).won then beaten = beaten + 1 end end
    print(("Boss of level %d (%s, health %d): beaten %d/8"):format(n, B.LevelSpec(n).boss.name, B.LevelSpec(n).boss.hp, beaten))
    equal(beaten >= 2, true, "level " .. n .. "'s boss can be beaten")
end
do
    local walls = {}
    for n = 400, 500, 4 do
        local won = 0
        for seed = 1, 4 do if Play(n, seed).won then won = won + 1 end end
        if won < 1 then walls[#walls + 1] = n end
    end
    print(("Levels 400-500, every 4th: %s"):format(#walls == 0 and "none a wall" or ("walls at " .. table.concat(walls, " "))))
    equal(table.concat(walls, " "), "", "levels 400 to 500 (every 4th): greedy wins at least 1 in 4")
end

-- Coins: levels 1 to 40 in order, each attempt (the bot's games, losses first) through Progress.
do
    local low, opened = 0, 0
    local afford20
    for n = 1, 40 do
        for _, game in ipairs(games[n]) do
            local report = P:Finish("blast", n, game.result)
            low = math.min(low, P:Coins())
            if game.won then
                opened = report.opened or opened
                break
            end
        end
        if n == 20 then
            local cheapest
            for _, power in ipairs(P.POWERS) do
                if P:Unlocked(power) then cheapest = math.min(cheapest or math.huge, P:Price(power)) end
            end
            afford20 = math.floor(P:Coins() / cheapest)
        end
    end
    print(("Coins: %d by level 40 (%d earned), %d power-ups affordable at level 20"):format(P:Coins(), P:Data().earned, afford20))
    equal(low >= 0, true, "coins never below 0")
    equal(P:Level("blast"), 41, "every level opened without spending a coin")
    equal(P:Data().earned >= 1000, true, "at least 1,000 coins earned by level 40")
    equal(afford20 >= 5, true, "at least five power-ups affordable by level 20")
end

print("Blast balance checks passed: " .. M.checks .. " assertions.")
