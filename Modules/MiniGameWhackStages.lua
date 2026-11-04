local _, EraUI = ...

-- Whack's rules (experimental, with the mini-games): a round, its stages and
-- what can pop out of a hole. Plain functions with no frames (Tools/TestMiniGames.lua
-- and Tools/TestWhackStages.lua play them); Modules/MiniGameWhack.lua draws a
-- round and Modules/MiniGameWhackHud.lua runs the stages, cards and map. This
-- file loads first, so it makes MiniGames.Whack; the others keep it.
--
-- A round: a 3, 2, 1, then heads come up one at a time (two at once on later
-- stages) for a moment each, quicker as the round goes on, until its time is
-- up. The round always runs its full length; a stage is won when its goals
-- are met at the end. What can come up:
--   normal  the target (a gnome for the Horde, a peon for the Alliance): +1
--   golden  the target in gold, up for less time: +3 and 5 coins
--   decoy   a worker of your own side: hitting one costs 3 points (never under
--           0) and your streak, and never counts for a goal
--   boss    the Boss Peon or Boss Gnome on a boss stage, at set times: each
--           hit sends him to another hole (boss.up seconds there); 3 hits in
--           a row beat him (+2 a hit, +5 more for the beating); left alone
--           too long in a hole, he ducks and his hits start again. Nothing
--           else pops up while he's out.
-- Whack.STAGES[n] (1 to 20, written) and Whack.StageSpec(n) (made from 21 on,
-- the same every time): {length, speed, golden, decoy, double (chances a pop
-- is golden, a decoy, or brings a second head), goals = {{id = "bonk"|"golden"|
-- "score"|"boss", need}}, stars = {score for 2, score for 3}, boss = {need, at
-- = {seconds}, up} or nil, card (a how-it-works card shown before its first try)}.
-- Whack.Timing(elapsed, spec) -> up, gap: how long a head stays up, and the
-- pause before the next.
-- Whack.New(random, spec) a Quick round (spec: Whack.QuickSpec(extras)),
-- Whack.NewStage(n, random) a stage. Then Begin (with its 3, 2, 1) or Start,
-- Advance(state, dt) -> happened, Hit(state, hole) -> "normal"|"golden"|"decoy"|
-- "bossHit"|"bossBeaten"|false, Miss, Pause, Resume, Finish, AddTime (+10
-- seconds after a lost stage), Have(state, goal), GoalsMet, Stars, GoalText.
-- Whack.SaveStage(state) -> a snapshot table (MiniGames.Progress:SaveResume) and
-- Whack.LoadStage(t, random) -> the round paused (or its lost end), or nil when
-- the snapshot is damaged.
-- Whack.SKINS (the mallets' colours) and Whack.FRAMING (each 3D target's
-- camera, which /era whack tune changes and saves).
local MG = EraUI.MiniGames
if not MG then return end

local Whack = MG.Whack or {}
MG.Whack = Whack
Whack.ROUND = 30      -- seconds a Quick round lasts
Whack.HOLES = 9       -- three rows of three
Whack.COUNTDOWN = 3   -- seconds of "3, 2, 1" before a round plays
Whack.FIRST_POP = .6  -- seconds from the start of play to the first head
Whack.STEP = .05      -- the rules move in steps this long (a long frame takes several)
-- How long a head stays up, and the pause before the next one: from 1 s up
-- and .45 s apart as a round starts to half a second up and .15 s apart at its
-- end, all divided by the stage's speed; never under the stage's floor
-- (Whack.UpMin: .8 s on stage 1, a little less each stage, UP_MIN from about
-- stage 50), GOLDEN_MIN for a golden head (which stays GOLDEN_UP of the time;
-- one a golden goal needs keeps the stage's floor). The second head of two
-- stays SECOND_EXTRA longer, so one pointer can reach it after the first. A
-- bot with one pointer (Tools/TestWhackStages.lua) shows the slope.
Whack.UP_START, Whack.UP_END = 1, .5
Whack.GAP_START, Whack.GAP_END = .45, .15
Whack.UP_MIN, Whack.GOLDEN_MIN, Whack.GOLDEN_UP = .5, .5, .8
Whack.FLOOR_START, Whack.FLOOR_STEP = .8, .003
Whack.SECOND_EXTRA = .35
Whack.POINTS = {normal = 1, golden = 3, decoy = -3, bossHit = 2, bossBeaten = 5}
Whack.BOSS_HITS = 3   -- hits in a row beat the boss (he hops to another hole after each)
Whack.BOSS_EVERY = 7  -- seconds between his showings after the listed ones
Whack.EXTRA = 10      -- seconds +10 seconds adds
Whack.MAX = {score = 99999, count = 9999, extra = 20}
-- The words for every fifth hit in a row (the last one from then on).
Whack.STREAKS = {"On a roll!", "Unstoppable!", "Whack master!", "Legendary!"}

-- The stages ----------------------------------------------------------------------------------

local function Goal(id, need) return {id = id, need = need} end
local BOSS5 = {5, 12, 19, 26}
Whack.STAGES = {
    {goals = {Goal("bonk", 10)}, length = 30, speed = 1, golden = 0, decoy = 0, double = 0, stars = {16, 22}},
    {goals = {Goal("bonk", 14)}, length = 30, speed = 1, golden = 0, decoy = 0, double = 0, stars = {19, 25}},
    {goals = {Goal("bonk", 12), Goal("golden", 1)}, length = 30, speed = 1, golden = .1, decoy = 0, double = 0, stars = {20, 27}, card = "golden"},
    {goals = {Goal("bonk", 16)}, length = 30, speed = 1.02, golden = .08, decoy = .12, double = 0, stars = {21, 28}, card = "decoy"},
    {goals = {Goal("boss", 1), Goal("bonk", 10)}, length = 30, speed = 1.02, golden = .08, decoy = .1, double = 0, stars = {22, 30},
        boss = {need = 1, at = {6, 14, 22}, up = .95}, card = "bossPeon"},
    {goals = {Goal("bonk", 18)}, length = 30, speed = 1.05, golden = .08, decoy = .12, double = 0, stars = {23, 30}},
    {goals = {Goal("score", 22)}, length = 30, speed = 1.05, golden = .1, decoy = .12, double = 0, stars = {27, 34}},
    {goals = {Goal("bonk", 18), Goal("golden", 2)}, length = 30, speed = 1.08, golden = .1, decoy = .12, double = 0, stars = {26, 33}},
    {goals = {Goal("bonk", 20)}, length = 30, speed = 1.1, golden = .08, decoy = .15, double = 0, stars = {26, 33}},
    {goals = {Goal("boss", 2)}, length = 35, speed = 1.1, golden = .08, decoy = .12, double = 0, stars = {26, 34},
        boss = {need = 2, at = BOSS5, up = .9}},
    {goals = {Goal("bonk", 22)}, length = 35, speed = 1.12, golden = .08, decoy = .15, double = .2, stars = {29, 37}, card = "double"},
    {goals = {Goal("bonk", 16), Goal("golden", 3)}, length = 35, speed = 1.12, golden = .12, decoy = .15, double = .2, stars = {30, 38}},
    {goals = {Goal("score", 30)}, length = 35, speed = 1.15, golden = .1, decoy = .18, double = .2, stars = {36, 44}},
    {goals = {Goal("bonk", 24)}, length = 35, speed = 1.15, golden = .08, decoy = .18, double = .25, stars = {31, 39}},
    {goals = {Goal("boss", 2), Goal("bonk", 14)}, length = 35, speed = 1.15, golden = .08, decoy = .15, double = .2, stars = {32, 40},
        boss = {need = 2, at = BOSS5, up = .9}},
    {goals = {Goal("bonk", 26)}, length = 35, speed = 1.18, golden = .08, decoy = .18, double = .25, stars = {33, 42}},
    {goals = {Goal("golden", 3), Goal("score", 30)}, length = 35, speed = 1.18, golden = .12, decoy = .18, double = .25, stars = {36, 45}},
    {goals = {Goal("bonk", 26)}, length = 35, speed = 1.2, golden = .08, decoy = .2, double = .25, stars = {35, 44}},
    {goals = {Goal("score", 30)}, length = 35, speed = 1.2, golden = .1, decoy = .2, double = .3, stars = {40, 48}},
    {goals = {Goal("boss", 3)}, length = 40, speed = 1.22, golden = .08, decoy = .18, double = .25, stars = {38, 48},
        boss = {need = 3, at = {5, 12, 19, 26, 33}, up = .85}},
}
for n, spec in ipairs(Whack.STAGES) do spec.n = n end
-- The made stages (21 on): their numbers, and the caps on how hard they get
-- ({start, per stage past 20, cap}). Their needs are a share of the heads a
-- round brings (Whack.Pops, decoys left out): share {start, per stage, cap},
-- so a quicker stage asks for more heads but never all of them; score needs
-- scoreK of that. The boss's time in each hole: bossUp {start, per stage, floor}.
Whack.MADE = {length = 40, speed = {1.22, .004, 1.4}, golden = .1, decoy = {.18, .005, .25}, double = {.25, .005, .35},
    share = {.45, .003, .65}, scoreK = 1.15, golden3 = 3, bossAt = {5, 12, 19, 26, 33}, bossUp = {.85, .003, .7}}

-- Park-Miller rolls from a seed: a float from 0 to 1 each call.
local function Rolls(seed)
    local s = seed % 2147483647
    if s == 0 then s = 1 end
    return function()
        s = s * 16807 % 2147483647
        return s / 2147483647
    end
end
local function Made(n)
    local M, d = Whack.MADE, n - 20
    local roll = Rolls(n * 6271 + 31)
    local spec = {n = n, length = M.length, golden = M.golden,
        speed = math.min(M.speed[3], M.speed[1] + M.speed[2] * d),
        decoy = math.min(M.decoy[3], M.decoy[1] + M.decoy[2] * d),
        double = math.min(M.double[3], M.double[1] + M.double[2] * d)}
    -- Needs: a share of the heads this round brings (not counting decoys).
    local heads = Whack.Pops(spec) * (1 - spec.decoy)
    local share = math.min(M.share[3], M.share[1] + M.share[2] * d)
    local bonk = math.floor(heads * share + .5)
    local score = math.floor(heads * share * M.scoreK + .5)
    local target
    if n % 5 == 0 then
        local need = math.min(3, 1 + math.floor(n / 10))
        spec.boss = {need = need, at = M.bossAt, up = math.max(M.bossUp[3], M.bossUp[1] - M.bossUp[2] * d)}
        spec.goals = {Goal("boss", need)}
        target = need * 9 + 12
    else
        local count = roll() < .5 and 1 or 2
        local first = roll() < .5 and "bonk" or "score"
        spec.goals = {Goal(first, first == "bonk" and bonk or score)}
        target = spec.goals[1].need
        if count == 2 then
            if roll() < .5 then
                spec.goals[2] = Goal("golden", M.golden3)
            else
                local other = first == "bonk" and "score" or "bonk"
                spec.goals[2] = Goal(other, other == "bonk" and bonk or score)
                target = math.max(target, spec.goals[2].need)
            end
        end
    end
    spec.stars = {math.ceil(target * 1.25), math.ceil(target * 1.6)}
    return spec
end
-- Stage n's spec (never changed by the caller).
function Whack.StageSpec(n)
    n = math.max(1, math.floor(tonumber(n) or 1))
    return Whack.STAGES[n] or Made(n)
end
-- A Quick round: 30 seconds, no goals; golden heads and decoys once stage 4 is cleared (extras).
function Whack.QuickSpec(extras)
    return {quick = true, length = Whack.ROUND, speed = 1, golden = extras and .08 or 0, decoy = extras and .1 or 0,
        double = 0, goals = {}, extras = extras and true or false}
end
local QUICK = Whack.QuickSpec(false)

-- Timing ----------------------------------------------------------------------------------------

-- A stage's floor for how long a head stays up: .8 s on stage 1, down
-- FLOOR_STEP a stage to UP_MIN (a Quick round has none).
function Whack.UpMin(spec)
    local n = tonumber(spec and spec.n) or 1
    return math.max(Whack.UP_MIN, Whack.FLOOR_START - Whack.FLOOR_STEP * (n - 1))
end
-- How long a head stays up, and the pause after it, this far into a round.
function Whack.Timing(elapsed, spec)
    spec = spec or QUICK
    local length = tonumber(spec.length) or Whack.ROUND
    local speed = tonumber(spec.speed) or 1
    local share = math.max(0, math.min(1, (tonumber(elapsed) or 0) / length))
    local up = (Whack.UP_START + (Whack.UP_END - Whack.UP_START) * share) / speed
    -- A Quick round keeps the first game's timing (half a second up at its end).
    if not spec.quick then up = math.max(Whack.UpMin(spec), up) end
    return up, (Whack.GAP_START + (Whack.GAP_END - Whack.GAP_START) * share) / speed
end
-- How long a head of this kind stays up (a golden one less, never too little;
-- one a golden goal needs, forced, never under its stage's floor).
function Whack.HeadTime(up, kind, forced, spec)
    if kind == "golden" then
        local least = forced and spec and not spec.quick and Whack.UpMin(spec) or Whack.GOLDEN_MIN
        return math.max(least, up * Whack.GOLDEN_UP)
    end
    return up
end
-- About how many heads come up in a round no one hits (the golden pops are spread over it).
function Whack.Pops(spec)
    local t, n = Whack.FIRST_POP, 0
    while t < spec.length do
        n = n + 1
        local up, gap = Whack.Timing(t, spec)
        t = t + up + gap
    end
    return n
end
-- The pop numbers made golden for a golden goal of g: g + 1 of them, evenly spaced.
function Whack.Forced(spec)
    local g = 0
    for _, goal in ipairs(spec.goals or {}) do if goal.id == "golden" then g = goal.need end end
    if g <= 0 then return {} end
    local total, out = Whack.Pops(spec), {}
    for k = 1, g + 1 do
        local at = math.max(1, math.floor(total * k / (g + 2) + .5))
        if out[#out] and at <= out[#out] then at = out[#out] + 1 end
        out[k] = at
    end
    return out
end
-- When the boss's next showing is due (index: his showings so far + 1).
function Whack.BossTime(spec, index)
    local at = spec.boss and spec.boss.at
    if not at or #at == 0 then return nil end
    if at[index] then return at[index] end
    return at[#at] + Whack.BOSS_EVERY * (index - #at)
end

-- A round ---------------------------------------------------------------------------------------

local function Clear(state, phase)
    local spec = state.spec
    state.phase, state.score, state.elapsed = phase, 0, 0
    state.length = spec.length
    state.left = state.length
    state.hole, state.kind, state.last, state.upFor, state.wait, state.pops = nil, nil, nil, 0, Whack.FIRST_POP, 0
    state.hole2, state.kind2, state.upFor2 = nil, nil, 0
    state.count, state.streak, state.bestStreak, state.misses, state.was = 0, 0, 0, 0, nil
    state.bonks, state.golden, state.decoys, state.beaten, state.bossHits, state.extra = 0, 0, 0, 0, 0, 0
    state.forced, state.forcedNext = Whack.Forced(spec), 1
    state.bossNext = 1
    state.bossAt = Whack.BossTime(spec, 1)
    state.outcome, state.met, state.paid = nil, false, false
end
-- A Quick round before it starts. random(low, high): MiniGames.Random unless
-- given. phase: "ready", "countdown" (the 3, 2, 1; count: its seconds left),
-- "playing", "paused" (was: the phase it left) or "over"; hole and kind: the
-- head that's up (hole2 and kind2: a second one); streak: hits in a row
-- (bestStreak: the round's longest).
function Whack.New(random, spec)
    local state = {mode = "quick", spec = spec or QUICK, random = random, happened = {}}
    Clear(state, "ready")
    return state
end
function Whack.NewStage(n, random)
    local spec = Whack.StageSpec(n)
    local state = {mode = "stage", stage = spec.n or n, spec = spec, random = random, happened = {}}
    Clear(state, "ready")
    return state
end

local function Roll(state, low, high)
    local random = state.random or MG.Random
    local value = math.floor(tonumber(random(low, high)) or low)
    return math.max(low, math.min(high, value))
end
local function Chance(state, p)
    if type(p) ~= "number" or p <= 0 then return false end
    return Roll(state, 1, 1000) <= p * 1000
end
-- Any hole but the last one a head was in (and but avoid, a head up now).
function Whack.PickHole(state, avoid)
    local free = {}
    for hole = 1, Whack.HOLES do
        if hole ~= state.last and hole ~= avoid then free[#free + 1] = hole end
    end
    return free[Roll(state, 1, #free)]
end

-- A round played at once.
function Whack.Start(state) Clear(state, "playing") end
-- A round with its 3, 2, 1 first.
function Whack.Begin(state)
    Clear(state, "countdown")
    state.count = Whack.COUNTDOWN
end
function Whack.Pause(state)
    if state.phase ~= "playing" and state.phase ~= "countdown" then return false end
    state.was, state.phase = state.phase, "paused"
    return true
end
function Whack.Resume(state)
    if state.phase ~= "paused" then return false end
    state.phase, state.was = state.was or "playing", nil
    return true
end

-- Goals ---------------------------------------------------------------------------------------

-- How far a goal is: bonk counts normal and golden heads, golden the golden
-- ones, boss the boss's beatings, score the score.
function Whack.Have(state, goal)
    local id = goal.id
    if id == "bonk" then return state.bonks end
    if id == "golden" then return state.golden end
    if id == "boss" then return state.beaten end
    if id == "score" then return state.score end
    return 0
end
-- Every goal met (a Quick round has none: never).
function Whack.GoalsMet(state)
    local goals = state.spec.goals or {}
    if #goals == 0 then return false end
    for _, goal in ipairs(goals) do
        if Whack.Have(state, goal) < goal.need then return false end
    end
    return true
end
-- A won stage's stars: 1, 2 from the spec's first score, 3 from its second.
function Whack.Stars(state)
    if state.outcome ~= "won" then return 0 end
    local stars = state.spec.stars or {}
    if state.score >= (stars[2] or math.huge) then return 3 end
    if state.score >= (stars[1] or math.huge) then return 2 end
    return 1
end
-- A goal in words: noun "gnome" or "peon" (Noun: "Gnome" or "Peon").
function Whack.GoalText(goal, noun, Noun)
    local need, id = goal.need, goal.id
    local plural = need == 1 and noun or noun .. "s"
    if id == "bonk" then return ("Bonk %d %s"):format(need, plural) end
    if id == "golden" then return ("Bonk %d golden %s"):format(need, plural) end
    if id == "boss" then
        if need == 1 then return ("Beat the Boss %s"):format(Noun) end
        return ("Beat the Boss %s %d times"):format(Noun, need)
    end
    return ("Score %d"):format(need)
end

-- Ends a round counting down, played or paused (its time ran out). A stage
-- is won when its goals are met.
function Whack.Finish(state)
    local phase = state.phase
    if phase ~= "playing" and phase ~= "paused" and phase ~= "countdown" then return false end
    state.phase, state.left, state.was, state.count = "over", 0, nil, 0
    state.elapsed = math.min(state.elapsed, state.length)
    if state.hole then state.last = state.hole end
    state.hole, state.kind, state.hole2, state.kind2, state.bossHits = nil, nil, nil, nil, 0
    if state.mode == "stage" then
        state.outcome = Whack.GoalsMet(state) and "won" or "lost"
    else
        state.outcome = "done"
    end
    return true
end
-- +10 seconds on a lost stage: the round carries on, paused, from where it ended.
function Whack.AddTime(state)
    if state.mode ~= "stage" or state.phase ~= "over" or state.outcome ~= "lost" or state.paid then return false end
    state.extra = state.extra + 1
    state.length = state.length + Whack.EXTRA
    state.left = state.length - state.elapsed
    state.phase, state.was, state.outcome = "paused", "playing", nil
    state.wait = Whack.FIRST_POP
    return true
end

-- Popping and ducking ------------------------------------------------------------------------

local function Duck(state)
    state.last, state.hole, state.kind = state.hole, nil, nil
    local _, gap = Whack.Timing(state.elapsed, state.spec)
    state.wait = gap
end
local function Duck2(state) state.hole2, state.kind2 = nil, nil end
local function BossDone(state)
    state.bossHits = 0
    state.bossNext = state.bossNext + 1
    state.bossAt = Whack.BossTime(state.spec, state.bossNext)
end
-- What pops: a golden head the goal needs (forced: true), else by chance.
local function PopKind(state)
    local forced = state.forced[state.forcedNext]
    if forced and state.pops >= forced then
        state.forcedNext = state.forcedNext + 1
        return "golden", true
    end
    if Chance(state, state.spec.golden) then return "golden" end
    if Chance(state, state.spec.decoy) then return "decoy" end
    return "normal"
end
local function SecondKind(state)
    if Chance(state, state.spec.golden) then return "golden" end
    if Chance(state, state.spec.decoy) then return "decoy" end
    return "normal"
end
local function Pop(state, happened)
    state.pops = state.pops + 1
    state.hole = Whack.PickHole(state, state.hole2)
    local kind, forced = PopKind(state)
    state.kind = kind
    local up = Whack.Timing(state.elapsed, state.spec)
    state.upFor = Whack.HeadTime(up, kind, forced, state.spec)
    happened.popped, happened.popKind = state.hole, state.kind
    if not state.hole2 and Chance(state, state.spec.double) then
        state.hole2 = Whack.PickHole(state, state.hole)
        state.kind2 = SecondKind(state)
        state.upFor2 = Whack.HeadTime(up, state.kind2) + Whack.SECOND_EXTRA
        happened.popped2, happened.popKind2 = state.hole2, state.kind2
    end
end
local function BossUp(state, happened)
    state.hole = Whack.PickHole(state, state.hole2)
    state.kind, state.bossHits = "boss", 0
    state.upFor = state.spec.boss.up
    happened.bossUp = state.hole
end
-- A hit that didn't beat him: off to another hole, his time there starting again.
local function BossHop(state)
    state.last = state.hole
    state.hole = Whack.PickHole(state, state.hole2)
    state.upFor = state.spec.boss.up
end
-- The 3, 2, 1. Returns the seconds left over once it's done (nil while it runs).
local function Count(state, dt, happened)
    local before = math.ceil(state.count - 1e-9)
    state.count = state.count - dt
    if state.count > 1e-9 then
        local now = math.ceil(state.count - 1e-9)
        if now < before then happened.count = now end
        return nil
    end
    local left = -state.count
    state.count, state.phase = 0, "playing"
    happened.go = true
    return left
end
-- One step of a round being played.
local function Step(state, step, happened)
    state.elapsed = state.elapsed + step
    state.left = math.max(0, state.length - state.elapsed)
    if state.elapsed >= state.length - 1e-9 then
        Whack.Finish(state)
        happened.over = true
        return
    end
    if state.hole2 then
        state.upFor2 = state.upFor2 - step
        if state.upFor2 <= 1e-9 then
            happened.ducked2, happened.duckedKind2 = state.hole2, state.kind2
            if state.kind2 ~= "decoy" then state.streak = 0 end
            Duck2(state)
        end
    end
    if state.hole then
        state.upFor = state.upFor - step
        if state.upFor <= 1e-9 then
            if state.kind == "boss" then
                happened.bossGone = state.hole
                BossDone(state)
            else
                happened.ducked, happened.duckedKind = state.hole, state.kind
            end
            if state.kind ~= "decoy" then state.streak = 0 end
            Duck(state)
        end
    elseif state.bossAt and state.elapsed >= state.bossAt - 1e-9 then
        BossUp(state, happened)
    else
        state.wait = state.wait - step
        if state.wait <= 1e-9 then Pop(state, happened) end
    end
end
local FIELDS = {"count", "go", "popped", "popKind", "popped2", "popKind2", "ducked", "duckedKind", "ducked2", "duckedKind2",
    "bossUp", "bossGone", "goalDone", "over"}
-- dt seconds of a round. Returns what happened in them (nil when nothing
-- could; the same table each time, so read it at once): count, the 3, 2, 1
-- reaching 2 or 1; go, play starting; popped and popKind, the hole a head came
-- up in and what it is (popped2 and popKind2: a second head with it); ducked
-- and duckedKind, a head going back down unhit (its streak gone, unless it was
-- a decoy; ducked2 the same for a second head); bossUp, the hole the boss came
-- up in; bossGone, his hole as he ducks unbeaten; goalDone, the step every
-- goal is first met; over, the round's time ran out.
function Whack.Advance(state, dt)
    local phase = state.phase
    if phase ~= "playing" and phase ~= "countdown" then return nil end
    dt = tonumber(dt) or 0
    if dt <= 0 then return nil end
    local happened = state.happened or {}
    state.happened = happened
    for _, field in ipairs(FIELDS) do happened[field] = nil end
    if not state.met and Whack.GoalsMet(state) then
        state.met = true
        happened.goalDone = true
    end
    if phase == "countdown" then
        dt = Count(state, dt, happened)
        if not dt then return happened end
    end
    while dt > 1e-9 and state.phase == "playing" do
        local step = math.min(dt, Whack.STEP)
        dt = dt - step
        Step(state, step, happened)
    end
    return happened
end

-- A click on a hole: what it hit ("normal", "golden", "decoy", "bossHit",
-- "bossBeaten"), or false. A head hit ducks at once; the boss hops to
-- another hole (state.hole) until his third hit.
function Whack.Hit(state, hole)
    if state.phase ~= "playing" or hole == nil then return false end
    local second = hole == state.hole2
    if hole ~= state.hole and not second then return false end
    local kind = second and state.kind2 or state.kind
    local P = Whack.POINTS
    if kind == "decoy" then
        state.score = math.max(0, state.score + P.decoy)
        state.streak, state.decoys = 0, state.decoys + 1
    else
        state.streak = state.streak + 1
        if state.streak > state.bestStreak then state.bestStreak = state.streak end
    end
    if kind == "boss" then
        state.bossHits = state.bossHits + 1
        state.score = state.score + P.bossHit
        if state.bossHits < Whack.BOSS_HITS then
            BossHop(state)
            return "bossHit"
        end
        state.beaten = state.beaten + 1
        state.score = state.score + P.bossBeaten
        BossDone(state)
        Duck(state)
        return "bossBeaten"
    end
    if kind ~= "decoy" then
        state.score = state.score + (kind == "golden" and P.golden or P.normal)
        state.bonks = state.bonks + 1
        if kind == "golden" then state.golden = state.golden + 1 end
    end
    if second then Duck2(state) else Duck(state) end
    return kind
end
-- A click that hit nothing while a round plays: the streak is gone.
function Whack.Miss(state)
    if state.phase ~= "playing" then return false end
    state.streak, state.misses = 0, state.misses + 1
    return true
end
-- The word for a streak this long, on every fifth hit in a row; else nil.
function Whack.StreakWord(streak)
    if type(streak) ~= "number" or streak < 5 or streak % 5 ~= 0 then return nil end
    local words = Whack.STREAKS
    return words[math.min(#words, streak / 5)]
end

-- Saving and loading ----------------------------------------------------------------------------

local COUNTS = {"score", "streak", "bestStreak", "misses", "bonks", "golden", "decoys", "beaten", "pops"}
-- A round being played, paused or lost (its lose card waiting) as a small table.
function Whack.SaveStage(state)
    local t = {v = 1, mode = state.mode, stage = state.mode == "stage" and state.stage or nil, elapsed = state.elapsed,
        length = state.length, extra = state.extra, forced = state.forcedNext, bossNext = state.bossNext,
        extras = state.mode == "quick" and state.spec.extras or nil,
        outcome = (state.phase == "over" and state.outcome == "lost" and not state.paid) and "lost" or nil}
    for _, field in ipairs(COUNTS) do t[field] = state[field] end
    return t
end
local function Whole(value, low, high)
    return type(value) == "number" and value == value and value == math.floor(value) and value >= low and value <= high
end
-- A snapshot back as a round: paused where it was (no head up, the next a
-- moment after Resume), or over and lost when its lose card was waiting. nil
-- when anything in it is wrong.
function Whack.LoadStage(t, random)
    if type(t) ~= "table" or t.v ~= 1 then return nil end
    local state
    if t.mode == "stage" then
        if not Whole(t.stage, 1, 1000000) then return nil end
        state = Whack.NewStage(t.stage, random)
    elseif t.mode == "quick" then
        state = Whack.New(random, Whack.QuickSpec(t.extras == true))
    else
        return nil
    end
    local max = Whack.MAX
    if not Whole(t.extra, 0, max.extra) or t.length ~= state.spec.length + Whack.EXTRA * t.extra then return nil end
    if t.extra > 0 and t.mode ~= "stage" then return nil end
    if type(t.elapsed) ~= "number" or t.elapsed ~= t.elapsed or t.elapsed < 0 or t.elapsed > t.length + 1e-6 then return nil end
    for _, field in ipairs(COUNTS) do
        if not Whole(t[field], 0, field == "score" and max.score or max.count) then return nil end
    end
    if t.golden > t.bonks or t.streak > t.bestStreak then return nil end
    if not Whole(t.forced, 1, #state.forced + 1) or not Whole(t.bossNext, 1, max.count) then return nil end
    if t.outcome ~= nil and (t.outcome ~= "lost" or t.mode ~= "stage") then return nil end
    for _, field in ipairs(COUNTS) do state[field] = t[field] end
    state.extra, state.length, state.elapsed = t.extra, t.length, t.elapsed
    state.left = math.max(0, state.length - state.elapsed)
    state.forcedNext, state.bossNext = t.forced, t.bossNext
    state.bossAt = Whack.BossTime(state.spec, state.bossNext)
    state.met = Whack.GoalsMet(state)
    if t.outcome == "lost" then
        state.phase, state.outcome, state.left = "over", "lost", 0
    else
        state.phase, state.was = "paused", "playing"
    end
    return state
end

-- Mallets and framing ------------------------------------------------------------------------

-- The mallet skins' colours, part by part (Whack.MALLET's order: the handle, its
-- shine, the grip, the head, its shine, the bands, the striking face); glow: a
-- soft light on the head. Ids and names as MiniGames.Progress.SKINS.
Whack.SKINS = {
    {id = "wood", name = "Wooden mallet", icon = "mallet.1", handle = {.40, .25, .12}, shine = {.74, .54, .32}, grip = {.24, .15, .08},
        head = {.60, .40, .20}, headShine = {.86, .64, .38}, bands = {.32, .30, .30}, face = {.90, .74, .48}},
    {id = "bone", name = "Bone mallet", icon = "mallet.2", handle = {.82, .78, .66}, shine = {.95, .92, .82}, grip = {.35, .22, .12},
        head = {.88, .84, .72}, headShine = {1, .97, .88}, bands = {.45, .30, .16}, face = {.95, .9, .78}},
    {id = "frost", name = "Frost mallet", icon = "mallet.3", handle = {.55, .70, .85}, shine = {.85, .95, 1}, grip = {.2, .28, .4},
        head = {.6, .85, 1}, headShine = {.9, 1, 1}, bands = {.3, .45, .6}, face = {.8, .95, 1}, glow = true},
    {id = "golden", name = "Golden mallet", icon = "mallet.4", handle = {.55, .38, .12}, shine = {.85, .65, .3}, grip = {.3, .2, .08},
        head = {1, .8, .25}, headShine = {1, .95, .6}, bands = {.7, .5, .15}, face = {1, .88, .45}},
    {id = "fel", name = "Felfire mallet", icon = "mallet.5", handle = {.25, .2, .18}, shine = {.45, .4, .3}, grip = {.15, .1, .08},
        head = {.35, .9, .2}, headShine = {.7, 1, .5}, bands = {.15, .35, .1}, face = {.55, 1, .35}, glow = true},
    {id = "gnomish", name = "Gnomish mallet", icon = "mallet.6", handle = {.55, .35, .2}, shine = {.8, .6, .4}, grip = {.2, .35, .2},
        head = {.8, .5, .25}, headShine = {1, .75, .45}, bands = {.25, .55, .35}, face = {.95, .65, .35}, price = 250},
}
Whack.SKIN_PARTS = {"handle", "shine", "grip", "head", "headShine", "bands", "bands", "face"}
function Whack.Skin(id)
    for _, skin in ipairs(Whack.SKINS) do if skin.id == id then return skin end end
    return Whack.SKINS[1]
end

-- Each 3D target's camera (MiniGames:Tune keys; /era whack tune changes them):
-- zoom (SetPortraitZoom: 0 the whole body, 1 the face), cam
-- (SetCamDistanceScale), up (SetPosition's height), turn (degrees, added to
-- its column's), body (the target's frame times this: the bosses 1.25), lift
-- (SetViewInsets: this share of the frame's height left empty under the
-- picture, so the head sits high in its hole) and peek (how far the one between
-- rounds shows, a share of all the way up). Head and shoulders, as the game's
-- own quest portraits frame a face.
Whack.FRAMING = {
    peon = {zoom = .65, cam = 1, up = 0, turn = 0, body = 1, lift = .25, peek = .6},
    gnome = {zoom = .55, cam = 1, up = 0, turn = 0, body = 1, lift = .2, peek = .6},
    bossPeon = {zoom = .45, cam = 1, up = 0, turn = 0, body = 1.25, lift = .2, peek = .6},
    bossGnome = {zoom = .45, cam = 1, up = 0, turn = 0, body = 1.25, lift = .2, peek = .6},
    decoyAlliance = {zoom = .6, cam = 1, up = 0, turn = 0, body = 1, lift = .25, peek = .6},
    decoyHorde = {zoom = .65, cam = 1, up = 0, turn = 0, body = 1, lift = .25, peek = .6},
}
-- The range /era whack tune keeps each field in.
Whack.TUNE_RANGE = {zoom = {0, 1}, cam = {.3, 3}, up = {-2, 2}, turn = {-180, 180}, body = {.6, 1.6}, peek = {.3, 1}, lift = {0, .6}}
Whack.TUNE_FIELDS = {"zoom", "cam", "up", "turn", "body", "peek", "lift"}
if MG.TuneDefaults then
    for key, framing in pairs(Whack.FRAMING) do MG:TuneDefaults(key, framing) end
end
