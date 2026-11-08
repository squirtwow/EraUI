local _, EraUI = ...

-- Azeroth Blast's zones and levels (experimental, with the mini-games): one
-- path for both sides, ten zones of ten levels, the 10th a boss; after
-- level 100 the zones come round again a tier harder ("Elwynn Forest 2").
-- Levels 1 to 40 are written out (Blast.LEVELS); from 41 on each is made
-- from its number alone (no random, no clock: the same level every time).
-- Blast.NewLevel lays one out; the rules it plays by are in
-- Modules/MiniGameBlastGoals.lua (its contract at the top).
--
--   Blast.ZONES[k] = {key, name, tint, boss = {name, every, actions = {{kind, count, layers, hits}}}}
--   Blast.Zone(n) -> zone, tier, k (1..10 within the zone), zoneIndex
--   Blast.LevelSpec(n) -> spec = {n, zone (key), zoneIndex, tier, k, name, moves, kinds (5 or 6),
--       grid (8 rows of 8 joined by "/"), shape (a named grid, or nil), goals = {{id, token
--       (collect: "foe1".."pal3"), need, name (boss)}}, exits = {columns} or nil,
--       relics = {need, max, cols, byExit} or nil, boss = {key, name, hp, every, actions} or nil,
--       stars = {moves to spare for 2 stars, for 3} (Blast.StarMarks(moves)), card (a
--       how-it-works card id) or nil}; an oil goal's need counts spots, not layers
--   Blast.NewLevel(n, random, faction, boosters) -> state; boosters = {charge, sheep, lust}
--       (each true to use it); state.boosted = {charge = i, sheep = i, lust = true}
--   Blast.LevelState(spec, random, faction) -> a state with no pieces yet (LoadLevel's start)
--   Blast.ParseGrid(grid) -> 64 characters, or nil; Blast.GridCounts(chars) -> counts
-- Grid characters: "." a piece, "#" a hole, "o"/"O" a piece on 1/2 layers of
-- oil, "i"/"I" a frozen piece (1/2 ice), "w" a webbed piece, "1".."3" a
-- crate of that many hits, "s" a skull, "r" a relic.
local MG = EraUI.MiniGames
if not MG or not MG.Blast then return end

local Blast = MG.Blast
local N = Blast.SIZE
local CELLS = N * N
local Index, Cell = Blast.Index, Blast.Cell
local EMPTY = {}

-- Stars: 2 with STAR2 and 3 with STAR3 of the move limit left at a win
-- (spec.stars, in moves); a boss's health from BOSS_HP_K a move; MOVE_BONUS
-- points each move left at a win. Calibrated by Tools/TestBlastBalance.lua's bots.
Blast.STAR2, Blast.STAR3, Blast.BOSS_HP_K, Blast.MOVE_BONUS = .25, .5, 50, 100
Blast.TIER_CAP = 2   -- a boss's health stops growing after tier 2 (level 300)
-- A made boss's health this much more at the top of the climb (d 1). 0: a
-- boss always strikes on time now, and more health on top made the far ones walls.
Blast.BOSS_HP_CLIMB = 0
Blast.ZONE_EVERY = false   -- made bosses: true keeps a zone's own faster countdown (3) from the start
-- Made bosses past these shares of the climb (d: 0 at level 41, 1 from 240)
-- strike with one more each time, and (past FAST_AT) every 3 moves instead
-- of 4. Now that a boss always strikes on time, FAST_AT is never reached.
Blast.BOSS_MORE_AT, Blast.BOSS_FAST_AT = .8, 2
-- The generator's moves: how many moves one unit of each goal takes, and
-- how much fewer the climb leaves (MADE_SQUEEZE times d off the 1.45 margin).
Blast.WORK = {collect = .6, enemy = .35, oil = .7, ice = .6, crate = .8, web = 1.4, relic = 9}
Blast.MADE_SQUEEZE = .1

local function Action(kind, count, extra)
    local action = {kind = kind, count = count}
    for key, value in pairs(extra or EMPTY) do action[key] = value end
    return action
end
Blast.ZONES = {
    {key = "elwynn", name = "Elwynn Forest", tint = {.55, .78, .45},
        boss = {name = "Hogger", every = 4, actions = {Action("oil", 3)}}},
    {key = "durotar", name = "Durotar", tint = {.85, .55, .38},
        boss = {name = "Zalazane", every = 4, actions = {Action("freeze", 3)}}},
    {key = "westfall", name = "Westfall", tint = {.85, .75, .45},
        boss = {name = "Edwin VanCleef", every = 4, actions = {Action("crates", 2, {hits = 2})}}},
    {key = "barrens", name = "The Barrens", tint = {.8, .7, .45},
        boss = {name = "Mutanus the Devourer", every = 3, actions = {Action("skulls", 2)}}},
    {key = "duskwood", name = "Duskwood", tint = {.4, .45, .6},
        boss = {name = "Stitches", every = 4, actions = {Action("web", 3), Action("skulls", 2)}}},
    {key = "stranglethorn", name = "Stranglethorn Vale", tint = {.35, .7, .4},
        boss = {name = "King Bangalash", every = 4, actions = {Action("skulls", 2), Action("oil", 3)}}},
    {key = "tanaris", name = "Tanaris", tint = {.95, .8, .5},
        boss = {name = "Gahz'rilla", every = 4, actions = {Action("freeze", 3), Action("crates", 2, {hits = 2})}}},
    {key = "blackrock", name = "Blackrock Mountain", tint = {.95, .45, .25},
        boss = {name = "Ragnaros", every = 3, actions = {Action("oil", 3, {layers = 2}), Action("skulls", 2)}}},
    {key = "plaguelands", name = "Eastern Plaguelands", tint = {.6, .65, .5},
        boss = {name = "Kel'Thuzad", every = 3, actions = {Action("freeze", 3), Action("skulls", 2)}}},
    {key = "silithus", name = "Silithus", tint = {.85, .7, .5},
        boss = {name = "C'Thun", every = 3, actions = {Action("web", 3), Action("crates", 2, {hits = 2}), Action("skulls", 2)}}},
}
-- Level n's zone, its tier (0 for levels 1 to 100), its place in the zone
-- (1..10, 10 the boss) and the zone's number.
function Blast.Zone(n)
    local zoneIndex = math.floor((n - 1) / 10) % #Blast.ZONES + 1
    return Blast.ZONES[zoneIndex], math.floor((n - 1) / 100), (n - 1) % 10 + 1, zoneIndex
end
local function ZoneName(zone, tier) return zone.name .. (tier > 0 and (" " .. (tier + 1)) or "") end
local function Round50(x) return math.floor(x / 50 + .5) * 50 end
Blast.Round50 = Round50
-- The moves to spare for 2 and 3 stars with this move limit.
function Blast.StarMarks(moves)
    local two = math.max(1, math.floor(Blast.STAR2 * moves + .5))
    return {two, math.max(two + 1, math.floor(Blast.STAR3 * moves + .5))}
end

-- Boards -------------------------------------------------------------------------------------------

Blast.GRIDS = {
    FULL      = "......../......../......../......../......../......../......../........",
    CORNERS   = "#......#/......../......../......../......../......../......../#......#",
    DIAMOND   = "##....##/#......#/......../......../......../......../#......#/##....##",
    HOURGLASS = "......../......../#......#/##....##/##....##/#......#/......../........",
    PILLARS   = "......../......../..#..#../..#..#../..#..#../..#..#../......../........",
    RING      = "......../......../......../...##.../...##.../......../......../........",
    BOWL      = "###..###/##....##/#......#/......../......../......../......../........",
    CROSS     = "##....##/##....##/......../......../......../......../##....##/##....##",
}
local LEGEND = {["."] = true, ["#"] = true, o = true, O = true, i = true, I = true, w = true, ["1"] = true, ["2"] = true,
    ["3"] = true, s = true, r = true}
-- A grid's 64 characters from the top left, or nil when it isn't 8 rows of 8.
function Blast.ParseGrid(grid)
    if type(grid) ~= "string" then return nil end
    local chars = {}
    for row in (grid .. "/"):gmatch("([^/]*)/") do
        if #row ~= N then return nil end
        for c = 1, N do
            local ch = row:sub(c, c)
            if not LEGEND[ch] then return nil end
            chars[#chars + 1] = ch
        end
    end
    if #chars ~= CELLS then return nil end
    return chars
end
local function Join(chars)
    local rows = {}
    for r = 1, N do rows[r] = table.concat(chars, "", (r - 1) * N + 1, r * N) end
    return table.concat(rows, "/")
end
-- What a grid holds: oil (layers) and oilCells, ice (frozen pieces) and
-- iceLayers, crate and crateHits, web, relic, skull, holes, playable.
function Blast.GridCounts(chars)
    local n = {oil = 0, oilCells = 0, ice = 0, iceLayers = 0, crate = 0, crateHits = 0, web = 0, relic = 0, skull = 0,
        holes = 0, playable = 0}
    for _, ch in ipairs(chars) do
        if ch == "#" then n.holes = n.holes + 1 else n.playable = n.playable + 1 end
        if ch == "o" or ch == "O" then n.oil, n.oilCells = n.oil + (ch == "O" and 2 or 1), n.oilCells + 1
        elseif ch == "i" or ch == "I" then n.ice, n.iceLayers = n.ice + 1, n.iceLayers + (ch == "I" and 2 or 1)
        elseif tonumber(ch) then n.crate, n.crateHits = n.crate + 1, n.crateHits + tonumber(ch)
        elseif ch == "w" then n.web = n.web + 1
        elseif ch == "r" then n.relic = n.relic + 1
        elseif ch == "s" then n.skull = n.skull + 1 end
    end
    return n
end
-- The goals that need every blocker of their kind: oil counts spots (a dark one takes two hits).
local COUNTED = {oil = "oilCells", ice = "ice", crate = "crate", web = "web"}

-- Levels 1 to 40 ----------------------------------------------------------------------------------
-- Each: goals, moves, grid (a named one or one of G below), kinds (races
-- that drop), then card (its how-it-works card), exits and max (relics on
-- the board at once), hp and every (a boss's health and how often he acts).
-- Oil, ice, crate and web goals need everything of that kind in the grid
-- (oil: every spot clean).

local G = {
    [4] = "......../......../..oooo../..oOOo../..oOOo../..oooo../......../........",
    [6] = "......../......../......../.OOOOOO./.OOOOOO./......../......../........",
    [7] = "......../.o....o./......../...oo.../...oo.../......../.o....o./........",
    [9] = "......../......../......../......../......../......../oooooooo/OOOOOOOO",
    [11] = "......../......../......../iiiiiiii/......../.iiiiii./......../........",
    [12] = "......../.i....i./......../..iiii../......../.i....i./......../........",
    [13] = "......../......../..IiiI../......../......../..IiiI../......../........",
    [14] = "......../oo....oo/oo....oo/...ii.../...ii.../oo....oo/......../...ii...",
    [16] = "......../......../.21..12./.12..21./......../......../......../........",
    [17] = "......../......../......../2..22..2/2......2/......../......../........",
    [18] = "oooooooo/......../..1111../......../......../..1..1../......../oooooooo",
    [19] = "......../.I....I./..iiii../......../...33.../..2..2../.I....I./...ii...",
    [20] = "......../......../......../..i..i../..i..i../......../......../........",
    [22] = "1......1/......../..2222../......../......../..1..1../......../2......2",
    [23] = "......../......../......../...r..../......../......../......../........",
    [24] = "....r.../......../......../oo....oo/......../.oo..oo./......../..o..o..",
    [25] = "......../..1..1../......../.2....2./......../..1..1../......../........",
    [26] = "...r..../......../.i....i./..i..i../..i..i../.i....i./......../........",
    [27] = "###..###/##....##/#......#/......../..OOOO../..OOOO../.O....O./.O....O.",
    [28] = ".r....r./......../1......1/..2..2../......../1......1/..1..1../........",
    [29] = "......../.ii..ii./.ii..ii./o......o/oo....oo/o......o/.ii..ii./oo....oo",
    [30] = "......../......../.2....2./......../......../.2....2./......../........",
    [31] = "##....##/##....##/..oooo../.o....o./.o....o./..oooo../##....##/##....##",
    [32] = "......../......../.w.ww.w./......../......../.w.ww.w./......../........",
    [33] = "......../ww....ww/......../...ww.../...ww.../......../.w....w./........",
    [34] = "..r...../......../......../.w.ww.w./......../......../..w..w../........",
    [35] = "......../.3....3./......../..1221../..1221../......../.3....3./........",
    [36] = "......../.IIIIII./...ii.../.w....w./.w....w./......../.IiiiiI./.w....w.",
    [37] = "...r..../......../#oooooo#/##oOOo##/##....##/#......#/.oo..oo./.o....o.",
    [38] = "......../.1....1./..i..i../.2.ii.2./.2.ii.2./..i..i../.1....1./........",
    [39] = "..r..r../......../oo....oo/oo.ww.oo/oo.ww.oo/oo....oo/.w....w./........",
    [40] = "......../......../......../...ss.../......../......../......../........",
}
-- Calibrated (moves within 4 of the design's, boss health within 25%) by
-- Tools/TestBlastBalance.lua's bots, the design's numbers in each comment.
-- Goals ask for more pieces rather than fewer moves (a quick player still
-- earns 3 stars), and the hard spikes got their design moves back: a player
-- who finds the best move half the time wins levels 1 to 10 nearly always
-- and most later ones. Since a special fires when swapped with any piece
-- (7 Nov 2026), the levels that made easier have fewer moves (9, 22, 24, 26,
-- 28, 29, 33, 34, 36, 37, 39; each still within 4 of its design) and 7 and
-- 33 ask for a few more pieces: greedy's wins had come to leave half their
-- moves, past the 45% line.
local ROWS = {
    {"collect foe1 14", 16, "FULL", 5, card = "goals"},                        -- 20
    {"collect foe2 20", 16, "FULL", 5},                                         -- 20
    {"collect foe1 14, collect foe3 14", 18, "FULL", 5},                        -- 22
    {"oil", 18, 4, 5, card = "oil"},                                            -- 22
    {"score 1200", 16, "CORNERS", 5, card = "holes"},                           -- 20
    {"oil", 20, 6, 5},                                                          -- 24
    {"collect foe2 24, oil", 20, 7, 5},                                         -- 24
    {"enemy 50", 18, "DIAMOND", 5},                                             -- 22
    {"oil", 26, 9, 5},                                                          -- 26
    {"boss", 20, "FULL", 5, card = "boss", hp = 1250, every = 4},               -- 24, 1000
    {"ice", 16, 11, 5, card = "ice"},                                           -- 20
    {"ice, collect foe1 22", 20, 12, 5},                                        -- 24
    {"ice, collect foe3 14", 18, 13, 6},                                        -- 22
    {"oil, ice", 26, 14, 6},                                                    -- 26
    {"enemy 50", 20, "HOURGLASS", 6},                                           -- 24
    {"crate", 18, 16, 6, card = "crate"},                                       -- 22
    {"crate, collect foe2 12", 26, 17, 6},                                      -- 26
    {"oil, crate", 28, 18, 6},                                                  -- 28
    {"ice, crate", 24, 19, 6},                                                  -- 28
    {"boss", 26, 20, 6, hp = 1350, every = 4},                                  -- 26, 1100
    {"collect foe1 16, collect foe2 16", 30, "PILLARS", 6},                     -- 26
    {"crate", 24, 22, 6},                                                       -- 26
    {"relic 1", 24, 23, 6, exits = {4, 5}, max = 1, card = "relic"},            -- 24
    {"relic 2, oil", 30, 24, 6, exits = {2, 5}, max = 2},                       -- 30
    {"score 2000, crate", 24, 25, 6},                                           -- 28
    {"relic 2, ice", 24, 26, 6, exits = {4, 5}, max = 1},                       -- 28
    {"oil", 26, 27, 6},                                                         -- 30
    {"relic 2, crate", 30, 28, 6, exits = {2, 7}, max = 2},                     -- 32
    {"ice, oil, collect foe3 14", 28, 29, 6},                                   -- 32
    {"boss", 28, 30, 6, hp = 1550, every = 4},                                  -- 28, 1250
    {"enemy 60, oil", 26, 31, 6},                                               -- 30
    {"web", 20, 32, 6, card = "web"},                                           -- 24
    {"web, collect pal1 16", 24, 33, 6},                                        -- 28
    {"relic 2, web", 28, 34, 6, exits = {3, 6}, max = 2},                       -- 30
    {"crate", 26, 35, 6},                                                       -- 30
    {"ice, web", 28, 36, 6},                                                    -- 32
    {"oil, relic 1", 34, 37, 6, exits = {4, 5}, max = 1},                       -- 34
    {"score 2400, crate, ice", 28, 38, 6},                                      -- 32
    {"relic 2, oil, web", 36, 39, 6, exits = {3, 6}, max = 2},                  -- 36
    {"boss", 30, 40, 6, card = "skull", hp = 1500, every = 3},                  -- 30, 1350
}
local function Goals(text)
    local goals = {}
    for part in (text .. ","):gmatch("%s*([^,]+),") do
        local id, a, b = part:match("^(%a+)%s*(%w*)%s*(%d*)$")
        local goal = {id = id}
        if id == "collect" then goal.token, goal.need = a, tonumber(b)
        elseif a ~= "" then goal.need = tonumber(a) end
        goals[#goals + 1] = goal
    end
    return goals
end
Blast.LEVELS = {}
for n, row in ipairs(ROWS) do
    local named = type(row[3]) == "string" and row[3] or nil
    Blast.LEVELS[n] = {goals = Goals(row[1]), moves = row[2], grid = named and Blast.GRIDS[named] or G[row[3]], shape = named,
        kinds = row[4], card = row.card, exits = row.exits, max = row.max, hp = row.hp, every = row.every}
end

-- Made levels ---------------------------------------------------------------------------------------

-- Park-Miller from a whole seed: float() in [0, 1), int(a, b) a..b.
function Blast.Rng(seed)
    local s = math.floor(seed) % 2147483647
    if s <= 0 then s = 1 end
    local rng = {}
    function rng.float()
        s = (s * 16807) % 2147483647
        return s / 2147483647
    end
    function rng.int(a, b) return a + math.floor(rng.float() * (b - a + 1)) end
    return rng
end
local function Weighted(rng, list, skip)
    local total = 0
    for _, entry in ipairs(list) do if not skip[entry[1]] then total = total + entry[2] end end
    local x = rng.float() * total
    local last
    for _, entry in ipairs(list) do
        if not skip[entry[1]] then
            last = entry[1]
            x = x - entry[2]
            if x < 0 then return entry[1] end
        end
    end
    return last
end
local SHAPES = {{"FULL", 4}, {"CORNERS", 2}, {"DIAMOND", 2}, {"PILLARS", 2}, {"RING", 2}, {"HOURGLASS", 1}, {"BOWL", 1},
    {"CROSS", 1}}
local BOSS_SHAPES = {PILLARS = true}   -- left out of a boss level's draw
-- A zone's first two levels open it gently: none of the tight boards, and
-- OPENER_MOVES more moves. The boards with gaps give Blast.TIGHT_MOVES[shape]
-- more anywhere (pieces fall round their gaps, so matches come slower).
local OPENER_SHAPES = {PILLARS = true, CROSS = true, BOWL = true}
Blast.OPENER_MOVES = 4
Blast.TIGHT_MOVES = {PILLARS = 3, CROSS = 3, BOWL = 3, HOURGLASS = 2, RING = 2}
Blast.MADE_MAX_MOVES = 40   -- past this, a made level's blockers are cut (largest first) until its moves fit
local GOAL_WEIGHTS = {{"collect", 3}, {"oil", 3}, {"ice", 2}, {"crate", 2}, {"relic", 2}, {"web", 2}, {"enemy", 1},
    {"score", 1}}
local RACE_TOKENS = {"foe1", "foe2", "foe3", "pal1", "pal2", "pal3"}
local ACTION_CHAR = {oil = "o", freeze = "i", web = "w", skulls = "s"}

-- Relics drop in these columns (a made level lays the first in the grid):
-- drawn from the level's own seed among its exit columns, so each one falls
-- straight to an exit. (Calibrated: drawn from any column, the bot brought
-- almost none out, as each needed sideways swaps with a match.)
local function RelicCols(rng, exits, need)
    local cols = {}
    for k = 1, need do cols[k] = exits[rng.int(1, #exits)] end
    return cols
end
-- The top cell of column c that isn't a hole.
local function TopOf(chars, c)
    for r = 1, N do if chars[Index(r, c)] ~= "#" then return Index(r, c) end end
    return nil
end
-- The exits {c, 9 - c}: c drawn 2..4 (an exit on the side of the board left
-- relics stuck in a corner), moved up then down to a column whose
-- bottom cell isn't a hole.
local function Exits(rng, chars)
    local c = rng.int(2, 4)
    local bottom = function(col) return chars[Index(N, col)] ~= "#" end
    if not bottom(c) then
        local found
        for up = c + 1, 4 do if bottom(up) then found = up; break end end
        if not found then for down = c - 1, 1, -1 do if bottom(down) then found = down; break end end end
        c = found or 4
    end
    return {c, N + 1 - c}
end
-- Blockers laid in mirrored pairs: a cell in the left half drawn by the
-- seed and its twin in the right half. requests: {{char = fn() -> character,
-- count, blocks}} in order; counts cut (largest first) until the blockers
-- fill at most half the board. A request that blocks (ice, crates, webs)
-- stays off the avoid columns (a relic's way down to its exit).
local function Place(rng, chars, requests, avoid)
    local counts = Blast.GridCounts(chars)
    local cap = math.floor(counts.playable / 2) - counts.relic
    local total = 0
    for _, req in ipairs(requests) do
        req.pairs = math.ceil(math.max(0, req.count) / 2)
        total = total + req.pairs * 2
    end
    while total > cap do
        local largest
        for _, req in ipairs(requests) do if req.pairs > 0 and (not largest or req.pairs > largest.pairs) then largest = req end end
        if not largest then break end
        largest.pairs, total = largest.pairs - 1, total - 2
    end
    local free = {}
    for r = 1, N do
        for c = 1, N / 2 do
            if chars[Index(r, c)] == "." and chars[Index(r, N + 1 - c)] == "." then free[#free + 1] = Index(r, c) end
        end
    end
    for _, req in ipairs(requests) do
        for _ = 1, req.pairs do
            local spots = {}
            for k, i in ipairs(free) do
                local _, c = Cell(i)
                if not (req.blocks and avoid and avoid[c]) then spots[#spots + 1] = k end
            end
            if #spots == 0 then break end
            local i = table.remove(free, spots[rng.int(1, #spots)])
            local r, c = Cell(i)
            local ch = req.char()
            chars[i], chars[Index(r, N + 1 - c)] = ch, ch
        end
    end
end
local function Clamp(x, low, high) return math.max(low, math.min(high, x)) end
-- A made boss level: moves, health from BOSS_HP_K (its tier capped), his
-- zone's actions (one more each later on) and a few of his first blocker to start.
local function MadeBoss(spec, rng, chars, zone, d)
    local moves = 26 + math.floor(6 * d) + rng.int(0, 2)
    local hp = Round50(moves * Blast.BOSS_HP_K * (1 + .03 * (spec.zoneIndex - 1) + .1 * math.min(spec.tier, Blast.TIER_CAP))
        * (1 + Blast.BOSS_HP_CLIMB * d))
    local actions = {}
    for k, action in ipairs(zone.boss.actions) do
        actions[k] = Action(action.kind, action.count + (d > Blast.BOSS_MORE_AT and 1 or 0), {layers = action.layers, hits = action.hits})
    end
    local first = zone.boss.actions[1]
    local char = ACTION_CHAR[first.kind] or tostring(first.hits or 2)
    if first.kind == "oil" and (first.layers or 1) > 1 then char = "O" end
    Place(rng, chars, {{count = rng.int(0, 4), char = function() return char end}})
    spec.moves = moves
    local every = 4 - (d > Blast.BOSS_FAST_AT and 1 or 0)
    if Blast.ZONE_EVERY then every = math.min(zone.boss.every, every) end
    spec.boss = {key = zone.key, name = zone.boss.name, hp = hp, every = every, actions = actions}
    spec.goals[1] = {id = "boss", need = 1, name = zone.boss.name}
end
-- A made level's goals: 1 to 3 kinds drawn without repeats (never both
-- enemy and score), their blockers laid, then moves from the work they take.
local function MadeGoals(spec, rng, chars, k, d)
    local count = k <= 2 and 1 or k <= 8 and 2 or (rng.float() < .5 and 3 or 2)
    local skip, requests, work = {}, {}, {}
    for _ = 1, count do
        local id = Weighted(rng, GOAL_WEIGHTS, skip)
        skip[id] = true
        if id == "enemy" then skip.score = true elseif id == "score" then skip.enemy = true end
        local goal = {id = id}
        spec.goals[#spec.goals + 1] = goal
        if id == "collect" then
            goal.token, goal.need = RACE_TOKENS[rng.int(1, 6)], 12 + math.floor(10 * d) + rng.int(0, 4)
            work[#work + 1] = goal.need * Blast.WORK.collect
        elseif id == "enemy" then
            goal.need = 30 + math.floor(20 * d)
            work[#work + 1] = goal.need * Blast.WORK.enemy
        elseif id == "oil" then
            local thick = .3 + .4 * d
            requests[#requests + 1] = {count = 10 + math.floor(10 * d) + rng.int(0, 4), char = function() return rng.float() < thick and "O" or "o" end}
        elseif id == "ice" then
            local thick = .25 + .5 * d
            requests[#requests + 1] = {count = 6 + math.floor(8 * d) + rng.int(0, 2), blocks = true,
                char = function() return rng.float() < thick and "I" or "i" end}
        elseif id == "crate" then
            requests[#requests + 1] = {count = 6 + math.floor(6 * d) + rng.int(0, 2), blocks = true, char = function()
                local hits = 1
                if rng.float() < d then hits = hits + 1 end
                if rng.float() < d / 2 then hits = hits + 1 end
                return tostring(hits)
            end}
        elseif id == "web" then
            requests[#requests + 1] = {count = 6 + math.floor(6 * d), blocks = true, char = function() return "w" end}
        elseif id == "relic" then
            goal.need = 2 + (d > .5 and 1 or 0)
            spec.exits = Exits(rng, chars)
            local cols = RelicCols(rng, spec.exits, goal.need)
            spec.relics = {need = goal.need, max = goal.need >= 3 and 2 or 1, cols = cols, byExit = false}
            chars[TopOf(chars, cols[1])] = "r"
            work[#work + 1] = goal.need * Blast.WORK.relic
        end
    end
    -- Blockers laid, the moves worked out; too many moves: one pair fewer of
    -- the largest request, laid again (the same every time for this level).
    local base, avoid = {}, spec.exits and {[spec.exits[1]] = true} or nil
    for i = 1, CELLS do base[i] = chars[i] end
    local extra = (k <= 2 and Blast.OPENER_MOVES or 0) + (Blast.TIGHT_MOVES[spec.shape] or 0)
    local moves
    for _ = 1, 40 do
        for i = 1, CELLS do chars[i] = base[i] end
        Place(rng, chars, requests, avoid)
        local counts = Blast.GridCounts(chars)
        local all = {counts.oil * Blast.WORK.oil, counts.iceLayers * Blast.WORK.ice, counts.crateHits * Blast.WORK.crate,
            counts.web * Blast.WORK.web}
        for _, w in ipairs(work) do all[#all + 1] = w end
        local most, sum = 0, 0
        for _, w in ipairs(all) do most, sum = math.max(most, w), sum + w end
        moves = math.ceil((most + .5 * (sum - most)) * (1.45 - Blast.MADE_SQUEEZE * d)) + 4 + extra
        if moves <= Blast.MADE_MAX_MOVES then break end
        local largest
        for _, req in ipairs(requests) do if req.count > 2 and (not largest or req.count > largest.count) then largest = req end end
        if not largest then break end
        largest.count = largest.count - 2
    end
    spec.moves = Clamp(moves, 16, Blast.MADE_MAX_MOVES)
    for _, goal in ipairs(spec.goals) do
        if goal.id == "score" then goal.need = Round50(38 * spec.moves) end
    end
end
local function Made(n)
    local zone, tier, k, zoneIndex = Blast.Zone(n)
    local rng = Blast.Rng(n * 7919 + 17)
    local d = math.min(1, (n - 40) / 200)
    -- A boss fights on an open board (Pillars' short columns left him shielded
    -- all fight); a zone's first two levels on an easy one.
    local shape = Weighted(rng, SHAPES, k == 10 and BOSS_SHAPES or k <= 2 and OPENER_SHAPES or EMPTY)
    local chars = Blast.ParseGrid(Blast.GRIDS[shape])
    local spec = {n = n, zone = zone.key, zoneIndex = zoneIndex, tier = tier, k = k, name = ZoneName(zone, tier), kinds = 6,
        shape = shape, goals = {}}
    if k == 10 then MadeBoss(spec, rng, chars, zone, d) else MadeGoals(spec, rng, chars, k, d) end
    spec.grid = Join(chars)
    return spec
end
-- A written level's spec from its row.
local function Written(n)
    local row = Blast.LEVELS[n]
    local zone, tier, k, zoneIndex = Blast.Zone(n)
    local spec = {n = n, zone = zone.key, zoneIndex = zoneIndex, tier = tier, k = k, name = ZoneName(zone, tier),
        moves = row.moves, kinds = row.kinds, grid = row.grid, shape = row.shape, card = row.card, goals = {}}
    for i, goal in ipairs(row.goals) do
        spec.goals[i] = {id = goal.id, token = goal.token, need = goal.need}
        if goal.id == "boss" then spec.goals[i].need, spec.goals[i].name = 1, zone.boss.name end
    end
    if row.exits then
        local need = 0
        for _, goal in ipairs(spec.goals) do if goal.id == "relic" then need = goal.need end end
        spec.exits = {row.exits[1], row.exits[2]}
        if n <= 30 then
            spec.relics = {need = need, max = row.max, cols = {row.exits[1], row.exits[2]}, byExit = true}
        else
            spec.relics = {need = need, max = row.max, cols = RelicCols(Blast.Rng(n * 7919 + 17), spec.exits, need), byExit = false}
        end
    end
    if row.hp then
        local actions = {}
        for i, action in ipairs(zone.boss.actions) do actions[i] = Action(action.kind, action.count, {layers = action.layers, hits = action.hits}) end
        spec.boss = {key = zone.key, name = zone.boss.name, hp = row.hp, every = row.every, actions = actions}
    end
    return spec
end
-- Level n's spec (a new table each time; the same for the same n).
function Blast.LevelSpec(n)
    n = tonumber(n)
    if not n or n ~= n or n < 1 or n ~= math.floor(n) or n > 1000000 then return nil end
    local spec = Blast.LEVELS[n] and Written(n) or Made(n)
    local counts = Blast.GridCounts(Blast.ParseGrid(spec.grid))
    for _, goal in ipairs(spec.goals) do
        if COUNTED[goal.id] then goal.need = counts[COUNTED[goal.id]] end
    end
    spec.stars = Blast.StarMarks(spec.moves)
    return spec
end

-- A level started --------------------------------------------------------------------------------

-- A state for spec with its holes, oil, exits, goals, boss and relics, and no pieces yet.
function Blast.LevelState(spec, random, faction)
    faction = faction == "Alliance" and "Alliance" or "Horde"
    local state = {mode = "level", level = spec.n, spec = spec, random = random, faction = faction,
        kinds = Blast.KindsFor(spec.kinds, faction), score = 0, meter = 0, lust = 0, moves = 0, nextId = 0, board = {},
        cells = {}, exits = {}, movesLeft = spec.moves, extra = 0, epics = 0, goals = {}}
    local chars = Blast.ParseGrid(spec.grid)
    for i, ch in ipairs(chars) do
        if ch == "#" then state.cells[i] = {hole = true}
        elseif ch == "o" or ch == "O" then state.cells[i] = {oil = ch == "O" and 2 or 1} end
    end
    for _, c in ipairs(spec.exits or EMPTY) do state.exits[Index(N, c)] = true end
    local foe = faction == "Alliance" and "Horde" or "Alliance"
    for k, goal in ipairs(spec.goals) do
        state.goals[k] = {id = goal.id, token = goal.token, race = goal.token and Blast.RaceOf(goal.token, faction) or nil,
            foe = goal.id == "enemy" and foe or nil, name = goal.name, need = goal.need, have = 0}
    end
    if spec.boss then
        local boss = spec.boss
        state.boss = {key = boss.key, name = boss.name, hp = boss.hp, max = boss.hp, every = boss.every, timer = boss.every,
            actions = boss.actions, next = 1}
    end
    if spec.relics then
        local onGrid = Blast.GridCounts(chars).relic
        state.relics = {need = spec.relics.need, max = spec.relics.max, onBoard = onGrid, spawned = onGrid, out = 0,
            cols = spec.relics.cols, byExit = spec.relics.byExit}
    end
    return state
end
-- A starting booster: a random plain piece (not frozen or webbed) made a
-- Charge (its line by the roll) or an Explosive Sheep.
local function Boost(state, special)
    local spots = {}
    for i = 1, CELLS do if Blast.Plain(state.board[i]) then spots[#spots + 1] = i end end
    if #spots == 0 then return nil end
    local i = spots[Blast.Roll(state, 1, #spots, "booster")]
    local dir = special == "charge" and (Blast.Roll(state, 1, 2, "booster") == 1 and "row" or "col") or nil
    state.board[i] = Blast.Piece(state, state.board[i].kind, special, dir)
    return i
end
-- Level n laid out for faction (random: the tests' roll, else MiniGames.Random).
function Blast.NewLevel(n, random, faction, boosters)
    local spec = Blast.LevelSpec(n)
    if not spec then return nil end
    local state = Blast.LevelState(spec, random, faction)
    local relicN = 0
    for i, ch in ipairs(Blast.ParseGrid(spec.grid)) do
        local over
        if ch == "i" or ch == "I" then over = {ice = ch == "I" and 2 or 1}
        elseif ch == "w" then over = {web = true}
        elseif tonumber(ch) then over = {block = "crate", hits = tonumber(ch)}
        elseif ch == "s" then over = {block = "skull"}
        elseif ch == "r" then
            relicN = relicN + 1
            over = {block = "relic", relic = (relicN - 1) % Blast.RELIC_LOOKS + 1}
        end
        if over then state.board[i] = Blast.Make(state, nil, over) end
    end
    Blast.ArrangeLevel(state)
    boosters = type(boosters) == "table" and boosters or EMPTY
    state.boosted = {}
    if boosters.charge then state.boosted.charge = Boost(state, "charge") end
    if boosters.sheep then state.boosted.sheep = Boost(state, "sheep") end
    if boosters.lust then state.lust, state.boosted.lust = Blast.LUST_MOVES, true end
    return state
end
