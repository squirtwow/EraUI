-- Whack's campaign (Modules/MiniGameWhackStages.lua, MiniGameWhack.lua and
-- MiniGameWhackHud.lua) on the mini-games' mock client (Tools/MiniGameMock.lua).
-- Checks: stages 1 to 20 as written, the made stages the same every time with
-- a boss every 5th and their speed and chances capped; the timing floors;
-- golden heads (forced for a golden goal, up the stage's floor), decoys
-- (points lost, never under 0, the streak gone, never counted), two heads at
-- once (the second up longer), the boss (he jumps to another hole after each
-- hit, three in a row beat him, his hits gone when he gets away, nothing else
-- popping while he's up); goals met mid-round, the round played to its end, won or lost, +10
-- seconds; saving and loading a round (and refusing a damaged one); the stage
-- map, intro, win and lose cards, coins, unlocks and how-it-works cards;
-- landing keeps the round for the next flight, on another character too; the
-- decoy's ring, the golden glow, the boss's size, models and chip; framing and
-- /era whack tune (clamped, applied, saved, reset); no forbidden sound in a
-- whole stage; a walk cut short, a stage kept from a Quick round, a Quick
-- round's golden coins; a bot with one pointer: the stages climb gently.
-- Run: fengari Tools/TestWhackStages.lua
local M = dofile("Tools/MiniGameMock.lua")
local equal, near = M.equal, M.near
local FILES = {"MiniGames", "MiniGameFX", "MiniGameAssets", "MiniGameProgress", "MiniGameMap", "MiniGameCards", "MiniGameShop",
    "MiniGameWhackStages", "MiniGameWhack", "MiniGameWhackHud"}
local MG, W
local function Session(opts)
    opts = opts or {}
    opts.only = opts.only or FILES
    MG = M.Session(opts)
    W = MG.Whack
    return MG
end
local function Game() return MG.games.whack end
local function Rng(seed)
    local s = seed % 2147483647
    if s == 0 then s = 1 end
    return function(low, high)
        s = s * 16807 % 2147483647
        return low + math.floor(s / 2147483647 * (high - low + 1))
    end
end
local function Const(value) return function(low, high) return math.max(low, math.min(high, value)) end end
local function Card() return MG.Card.Frame("whack") end
local function Button(label)
    for _, button in ipairs(Card().buttons) do
        if button.shown and button.label.text == label then return button end
    end
end
local function Has(list, text)
    for _, value in ipairs(list) do if value == text then return true end end
    return false
end

-- The stages as written -------------------------------------------------------------------------

Session()
do
    -- A number to three places, whole ones without a point.
    local function G(x)
        local r = math.floor(x * 1000 + .5)
        if r % 1000 == 0 then return ("%d"):format(r / 1000) end
        return (("%.3f"):format(r / 1000):gsub("0+$", ""))
    end
    local function Row(spec)
        local goals = {}
        for _, goal in ipairs(spec.goals) do goals[#goals + 1] = goal.id .. " " .. goal.need end
        local boss = spec.boss and (spec.boss.need .. " at " .. table.concat(spec.boss.at, "/") .. " up " .. G(spec.boss.up)) or ""
        return ("%s|%d|%s|%s|%s|%s|%d,%d|%s|%s"):format(table.concat(goals, ", "), spec.length, G(spec.speed), G(spec.golden), G(spec.decoy),
            G(spec.double), spec.stars[1], spec.stars[2], boss, spec.card or "")
    end
    local WANT = {
        "bonk 10|30|1|0|0|0|16,22||", "bonk 14|30|1|0|0|0|19,25||", "bonk 12, golden 1|30|1|0.1|0|0|20,27||golden",
        "bonk 16|30|1.02|0.08|0.12|0|21,28||decoy", "boss 1, bonk 10|30|1.02|0.08|0.1|0|22,30|1 at 6/14/22 up 0.95|bossPeon",
        "bonk 18|30|1.05|0.08|0.12|0|23,30||", "score 22|30|1.05|0.1|0.12|0|27,34||", "bonk 18, golden 2|30|1.08|0.1|0.12|0|26,33||",
        "bonk 20|30|1.1|0.08|0.15|0|26,33||", "boss 2|35|1.1|0.08|0.12|0|26,34|2 at 5/12/19/26 up 0.9|",
        "bonk 22|35|1.12|0.08|0.15|0.2|29,37||double", "bonk 16, golden 3|35|1.12|0.12|0.15|0.2|30,38||",
        "score 30|35|1.15|0.1|0.18|0.2|36,44||", "bonk 24|35|1.15|0.08|0.18|0.25|31,39||",
        "boss 2, bonk 14|35|1.15|0.08|0.15|0.2|32,40|2 at 5/12/19/26 up 0.9|", "bonk 26|35|1.18|0.08|0.18|0.25|33,42||",
        "golden 3, score 30|35|1.18|0.12|0.18|0.25|36,45||", "bonk 26|35|1.2|0.08|0.2|0.25|35,44||",
        "score 30|35|1.2|0.1|0.2|0.3|40,48||", "boss 3|40|1.22|0.08|0.18|0.25|38,48|3 at 5/12/19/26/33 up 0.85|",
    }
    for n = 1, 20 do equal(Row(W.StageSpec(n)), WANT[n], "stage " .. n .. " as written") end
    equal(W.StageSpec(0).n .. " " .. W.StageSpec(-3).n .. " " .. W.StageSpec("x").n, "1 1 1", "an odd stage number is stage 1")

    -- The made stages: the same every time, a boss every 5th, capped.
    local first = {}
    for n = 21, 400 do first[n] = Row(W.StageSpec(n)) end
    local same, bossOk, capped, goalsOk = true, true, true, true
    for n = 21, 400 do
        local spec = W.StageSpec(n)
        if Row(spec) ~= first[n] then same = false end
        if (spec.boss ~= nil) ~= (n % 5 == 0) then bossOk = false end
        if spec.speed > 1.4 + 1e-9 or spec.decoy > .25 + 1e-9 or spec.double > .35 + 1e-9 or spec.length ~= 40 then capped = false end
        if spec.boss and (spec.boss.need > 3 or spec.boss.up < .7 - 1e-9 or #spec.goals ~= 1) then capped = false end
        if not (spec.stars[1] < spec.stars[2]) then goalsOk = false end
        local seen, plain = {}, false
        for _, goal in ipairs(spec.goals) do
            if seen[goal.id] then goalsOk = false end
            seen[goal.id] = true
            if goal.id ~= "golden" then plain = true end
            if goal.id == "bonk" and goal.need > 40 or goal.id == "score" and goal.need > 50 then capped = false end
        end
        if not plain or #spec.goals < 1 or #spec.goals > 2 then goalsOk = false end
    end
    equal(same, true, "the made stages are the same every time")
    equal(bossOk, true, "a boss every 5th stage, never between")
    equal(capped, true, "their speed, chances, needs and bosses capped")
    equal(goalsOk, true, "one or two goals, never the same twice, never golden heads alone, 3 stars above 2")
    local reloaded = {}
    Session()
    for n = 21, 60 do reloaded[#reloaded + 1] = Row(W.StageSpec(n)) == first[n] and "" or tostring(n) end
    equal(table.concat(reloaded), "", "and after loading the file again (no random rolls)")
    equal(Row(W.StageSpec(25)), "boss 3|40|1.24|0.1|0.205|0.275|49,63|3 at 5/12/19/26/33 up 0.835|", "stage 25: a boss to beat three times")
    equal(Row(W.StageSpec(30)), "boss 3|40|1.26|0.1|0.23|0.3|49,63|3 at 5/12/19/26/33 up 0.82|", "stage 30 the same, a little quicker")
    -- Made needs: a share of the heads a round brings (decoys left out), about
    -- half at stage 21, never more than .65 of them.
    local shares, over = {}, false
    for n = 21, 300 do
        local spec = W.StageSpec(n)
        local heads = W.Pops(spec) * (1 - spec.decoy)
        for _, goal in ipairs(spec.goals) do
            if goal.id == "bonk" then
                shares[n] = goal.need / heads
                if goal.need > heads * W.MADE.share[3] + .5 then over = true end
            end
        end
    end
    local first21 = shares[21] or shares[22] or shares[23]
    equal(first21 ~= nil and first21 > .4 and first21 < .55 and not over, true, "made bonk needs: about half the heads early, never over .65")

    -- The timing: a floor for each stage's heads, from .8 s on stage 1 down a
    -- little a stage to UP_MIN; a Quick round as the first game.
    local low, gold = math.huge, math.huge
    for n = 1, 200 do
        local spec = W.StageSpec(n)
        for t = 0, spec.length, 1 do
            local up = W.Timing(t, spec)
            low = math.min(low, up)
            gold = math.min(gold, W.HeadTime(up, "golden"))
        end
    end
    equal(low >= W.UP_MIN and gold >= W.GOLDEN_MIN, true, "a stage's heads never up under " .. W.UP_MIN .. " s (golden " .. W.GOLDEN_MIN .. " s)")
    near((W.Timing(30)), .5, "a Quick round still ends at half a second up")
    near((W.Timing(30, W.StageSpec(1))), .8, "stage 1's end: its floor, .8 s")
    near((W.Timing(35, W.StageSpec(19))), .8 - .003 * 18, "stage 19's a little lower")
    near(W.UpMin(W.StageSpec(400)), W.UP_MIN, "far stages: UP_MIN")
    near(W.HeadTime(.5, "golden", true, W.StageSpec(12)), W.UpMin(W.StageSpec(12)), "a golden head the goal needs: up the stage's floor")
    near(W.HeadTime(.5, "golden", false, W.StageSpec(12)), W.GOLDEN_MIN, "a chance golden head: quick")
end

-- The rules ------------------------------------------------------------------------------------

do
    -- Golden heads forced for a golden goal: g + 1 of them over a round no one hits.
    for _, n in ipairs({3, 8, 12, 17}) do
        local s = W.NewStage(n, Const(1000))
        W.Start(s)
        local golden = 0
        while s.phase == "playing" do
            local happened = W.Advance(s, .05)
            if happened.popKind == "golden" then golden = golden + 1 end
        end
        local need = 0
        for _, goal in ipairs(W.StageSpec(n).goals) do if goal.id == "golden" then need = goal.need end end
        equal(golden, need + 1, "stage " .. n .. ": " .. (need + 1) .. " golden heads forced for a goal of " .. need)
    end
    local s = W.NewStage(1, Const(1000))
    equal(#s.forced, 0, "no golden goal, none forced")

    -- A golden head: 3 points, up for less time.
    s = W.NewStage(3, Const(1))
    W.Start(s)
    local happened = W.Advance(s, .6)
    equal(happened.popKind, "golden", "every roll low: a golden head")
    near(s.upFor, W.HeadTime(W.Timing(.6, s.spec), "golden"), "up for less time")
    equal(W.Hit(s, s.hole) .. " " .. s.score .. " " .. s.bonks .. " " .. s.golden .. " " .. s.streak, "golden 3 1 1 1", "hit: 3 points, a bonk and a golden one")

    -- A decoy: 3 points off (never under 0), the streak gone, never counted.
    s = W.NewStage(4, Const(1000))
    W.Start(s)
    W.Advance(s, .6)
    s.kind, s.score, s.streak, s.bestStreak = "decoy", 2, 4, 4
    equal(W.Hit(s, s.hole) .. " " .. s.score .. " " .. s.streak .. " " .. s.bonks .. " " .. s.decoys .. " " .. s.bestStreak,
        "decoy 0 0 0 1 4", "hitting your own side: -3 (but not under 0), the streak gone, no bonk")
    s.score = 9
    W.Advance(s, 2)
    s.kind, s.streak = "decoy", 3
    happened = W.Advance(s, s.upFor + .01)
    equal(happened.duckedKind .. " " .. s.streak .. " " .. s.score, "decoy 3 9", "a decoy left alone: nothing lost")

    -- Two at once.
    s = W.NewStage(11, Const(1))
    W.Start(s)
    happened = W.Advance(s, .6)
    equal(happened.popped ~= nil and happened.popped2 ~= nil and s.hole ~= s.hole2, true, "two heads up at once, in two holes")
    local first, second = s.hole, s.hole2
    near(s.upFor2 - s.upFor, W.SECOND_EXTRA, "the second head stays up a little longer (one pointer reaches it after the first)")
    equal(W.Hit(s, second) ~= false and s.hole2 == nil and s.hole == first, true, "the second hit, the first still up")
    equal(W.Hit(s, first) ~= false and s.hole == nil, true, "then the first")
    s = W.NewStage(11, Const(1))
    W.Start(s)
    W.Advance(s, .6)
    s.kind2, s.streak, s.upFor = "normal", 3, 5
    happened = W.Advance(s, s.upFor2 + .01)
    equal(happened.ducked2 ~= nil and s.hole ~= nil and s.streak, 0, "a second head left to duck ends the streak too")

    -- The boss: up at his times, nothing else popping while he's out, three hits beat him.
    s = W.NewStage(5, Const(1000))
    W.Start(s)
    local up
    for _ = 1, 200 do
        happened = W.Advance(s, .05)
        if happened.bossUp then up = happened.bossUp break end
    end
    equal(up ~= nil and s.kind .. " " .. tostring(s.elapsed >= 6 - 1e-9), "boss true", "the Boss comes up at 6 s")
    local pops, hole = s.pops, s.hole
    W.Advance(s, .5)
    equal(s.hole .. " " .. s.pops, hole .. " " .. pops, "no other head pops while he's up")
    local hit1 = W.Hit(s, hole)
    local hop = s.hole
    equal(hit1 .. " " .. tostring(hop ~= nil and hop ~= hole) .. " " .. s.score .. " " .. s.bossHits .. " " .. tostring(W.Hit(s, hole)),
        "bossHit true 2 1 false", "a hit: +2, and he jumps to another hole (the old one is empty now)")
    near(s.upFor, s.spec.boss.up, "his time in the new hole starts again")
    equal(W.Hit(s, s.hole) .. " " .. s.score .. " " .. s.bossHits, "bossHit 4 2", "the second: +2, off again")
    equal(W.Hit(s, s.hole) .. " " .. s.score .. " " .. s.beaten .. " " .. tostring(s.hole), "bossBeaten 11 1 nil", "the third in a row beats him: +2 and +5, he ducks")
    for _ = 1, 400 do
        happened = W.Advance(s, .05)
        if happened.bossUp then break end
    end
    equal(s.kind .. " " .. tostring(s.elapsed >= 14 - 1e-9), "boss true", "his next showing at 14 s")
    W.Hit(s, s.hole)
    W.Hit(s, s.hole)
    local gone
    for _ = 1, 100 do
        happened = W.Advance(s, .05)
        if happened.bossGone then gone = happened.bossGone break end
    end
    equal(gone ~= nil and s.bossHits .. " " .. s.beaten .. " " .. s.streak, "0 1 0", "two hits and he gets away: his hits gone, the streak too")
    equal(W.BossTime(s.spec, 4) .. " " .. W.BossTime(s.spec, 5), "29 36", "after his listed times, every 7 s")

    -- Goals met mid-round: said once; the round plays to its end; won with stars.
    s = W.NewStage(1, Rng(5))
    W.Start(s)
    local said, saidAt = 0, nil
    while s.phase == "playing" do
        happened = W.Advance(s, .05)
        if happened and happened.goalDone then said, saidAt = said + 1, s.elapsed end
        if s.hole and s.phase == "playing" then W.Hit(s, s.hole) end
    end
    equal(said .. " " .. tostring(saidAt < 25) .. " " .. s.outcome .. " " .. tostring(s.elapsed >= 30 - 1e-9), "1 true won true",
        "every goal met: said once, the round played to its end, won")
    equal(W.Stars(s), s.score >= 22 and 3 or s.score >= 16 and 2 or 1, "stars by its score")
    s = W.NewStage(2, Rng(5))
    W.Start(s)
    W.Advance(s, 40)
    equal(s.outcome .. " " .. W.Stars(s) .. " " .. tostring(W.GoalsMet(s)), "lost 0 false", "no hits: lost, no stars")
    -- +10 seconds after a loss: the round carries on, paused, ten seconds longer.
    equal(W.AddTime(s) and s.phase .. " " .. s.length .. " " .. math.floor(s.left + .5) .. " " .. s.extra, "paused 40 10 1", "+10 seconds: paused, 10 s left")
    W.Resume(s)
    W.Advance(s, 11)
    equal(s.phase .. " " .. s.outcome, "over lost", "and then over again")
    equal(W.AddTime(W.NewStage(1)), false, "no extra time for a round not lost")
    -- A Quick round: no goals, never won or lost.
    s = W.New(Rng(3))
    W.Start(s)
    W.Advance(s, 31)
    equal(s.mode .. " " .. s.outcome .. " " .. tostring(W.GoalsMet(s)) .. " " .. s.length, "quick done false 30", "a Quick round: 30 s, no goals")
    equal(W.QuickSpec(true).golden .. " " .. W.QuickSpec(true).decoy .. " " .. W.QuickSpec(false).golden, "0.08 0.1 0",
        "golden heads and decoys in a Quick round once stage 4 is cleared")
    equal(W.GoalText({id = "bonk", need = 10}, "peon", "Peon") .. " | " .. W.GoalText({id = "golden", need = 1}, "gnome", "Gnome") .. " | "
        .. W.GoalText({id = "boss", need = 1}, "peon", "Peon") .. " | " .. W.GoalText({id = "boss", need = 3}, "gnome", "Gnome") .. " | "
        .. W.GoalText({id = "score", need = 22}, "peon", "Peon"),
        "Bonk 10 peons | Bonk 1 golden gnome | Beat the Boss Peon | Beat the Boss Gnome 3 times | Score 22", "goals in words")
end

-- Saving and loading -----------------------------------------------------------------------------

do
    local s = W.NewStage(8, Rng(11))
    W.Start(s)
    for _ = 1, 160 do
        W.Advance(s, .05)
        if s.hole and s.kind ~= "decoy" then W.Hit(s, s.hole) end
    end
    local t = W.SaveStage(s)
    local back = W.LoadStage(t, Rng(1))
    local same = true
    for _, field in ipairs({"stage", "score", "streak", "bestStreak", "misses", "bonks", "golden", "decoys", "beaten", "pops", "elapsed",
        "length", "extra", "forcedNext", "bossNext"}) do
        if back[field] ~= s[field] then same = false end
    end
    equal(same and back.phase .. " " .. back.was .. " " .. tostring(back.hole) .. " " .. back.wait, "paused playing nil " .. W.FIRST_POP,
        "a round mid-stage saved and loaded: the same, paused, no head up, the next a moment after Resume")
    equal(t.v .. " " .. t.mode .. " " .. t.stage .. " " .. tostring(t.outcome), "1 stage 8 nil", "the snapshot names its stage")
    local function Broken(change)
        local copy = {}
        for key, value in pairs(t) do copy[key] = value end
        change(copy)
        return W.LoadStage(copy) == nil
    end
    local refused = Broken(function(c) c.v = 2 end) and Broken(function(c) c.mode = "dance" end) and Broken(function(c) c.stage = 0 end)
        and Broken(function(c) c.score = -1 end) and Broken(function(c) c.golden = c.bonks + 1 end) and Broken(function(c) c.length = 31 end)
        and Broken(function(c) c.elapsed = c.length + 1 end) and Broken(function(c) c.outcome = "won" end) and Broken(function(c) c.score = 0 / 0 end)
        and Broken(function(c) c.bonks = 2.5 end) and Broken(function(c) c.forced = 99 end) and Broken(function(c) c.streak = c.bestStreak + 1 end)
    equal(refused and W.LoadStage(nil) == nil and W.LoadStage("x") == nil, true, "a damaged snapshot is refused")
    -- A lost stage's snapshot brings its lose card back.
    s = W.NewStage(2, Rng(3))
    W.Start(s)
    W.Advance(s, 31)
    t = W.SaveStage(s)
    back = W.LoadStage(t)
    equal(t.outcome .. " " .. back.phase .. " " .. back.outcome, "lost over lost", "a lost stage waiting on its lose card")
    s.paid = true
    equal(W.SaveStage(s).outcome, nil, "once left, it isn't lost and waiting")
    -- A Quick round with its golden heads.
    s = W.New(Rng(3), W.QuickSpec(true))
    W.Start(s)
    W.Advance(s, 5)
    back = W.LoadStage(W.SaveStage(s))
    equal(back.mode .. " " .. back.spec.golden .. " " .. back.elapsed, "quick 0.08 " .. s.elapsed, "a Quick round too, its golden heads kept")
end

-- The stage map and the cards ------------------------------------------------------------------

Session({random = Rng(7)})
MG:Open("whack", "command")
do
    local game, map = Game(), Game().map
    equal(game.screen .. " " .. tostring(map:IsShown()) .. " " .. tostring(game.root.shown), "map true false", "/era whack: the stage map")
    equal(map.title.text .. " | " .. map.sub.text, "Elwynn Forest | Stages 1 to 10, 0 of 30 stars", "ten stages a page, in a zone")
    equal(map.ground.texture, 187126, "on the gnomes' grass (Elwynn's)")
    map:Show(2)
    equal(map.title.text .. " " .. tostring(map.ground.texture), "Westfall 188991", "the next page: Westfall, on its own ground")
    map:Show(5)
    equal(map.title.text, "Elwynn Forest", "four zones, then round again")
    map:Show(1)
    local target = W.TARGETS.peon
    equal(W.PageZone(target, 1) .. " " .. W.PageZone(target, 11) .. " " .. W.PageZone(target, 25) .. " " .. W.PageZone(target, 31),
        "durotar barrens mulgore silverpine", "the peons' pages: Durotar, the Barrens, Mulgore, Silverpine")
    local home = W.TARGETS.gnome.ground
    equal(W.Look(W.TARGETS.gnome, "elwynn") == home and W.Look(W.TARGETS.gnome, "westfall").field[1], 188991, "home's own look; elsewhere that zone's ground")
    equal(map.nodes[1].state .. " " .. map.nodes[2].state .. " " .. map.nodes[5].role .. " " .. map.nodes[10].role, "open locked map.nodeBoss map.nodeBoss",
        "stage 1 open, the rest locked, a boss every 5th")
    equal(map.nodes[5].portrait.shown and map.nodes[5].portrait.texture, "Interface\\Icons\\INV_Misc_Head_Gnome_01", "the Boss Gnome's face on his node")
    map.nodes[2]:Click()
    equal(M.Shell().note.text, "Clear stage 1 first.", "a locked stage says so")
    map.nodes[1]:Click()
    local card = Card()
    equal(MG.Card.Shown("whack") and card.title.text .. " | " .. card.lines[1].text.text .. " | " .. card.big.text, "Stage 1 | Bonk 10 gnomes | 30 seconds",
        "a stage's intro: its goal and its time")
    equal(Button("Start") ~= nil and Button("Map") ~= nil, true, "Start and Map")
    Button("Start"):Click()
    equal(tostring(MG.Card.Shown("whack")) .. " " .. game.screen .. " " .. game.state.phase .. " " .. game.state.stage, "false stage countdown 1",
        "Start: the field, counting down")
    equal(game.hud.title.text .. " | " .. game.hud.chips[1].text.text .. " | " .. tostring(game.hud.chips[2].shown) .. " " .. tostring(game.hud.boss.shown),
        "Stage 1 | 0/10 | false false", "the HUD: the stage and its goal")
    equal(M.Shell().where.text .. " | " .. M.Shell().best.text, "Stage 1 | Best 0", "the header names the stage and its best")
    equal(EraUIDB.miniGameResume.whack.stage .. " " .. EraUIDB.miniGameProgress.whack.last, "1 stage", "saved as it starts, so even a fresh start carries on")
    -- Play it through, every head hit.
    local function Play()
        for _ = 1, 2000 do
            local s = game.state
            if s.phase == "over" then return end
            M.Tick(.05)
            s = game.state
            if s.phase == "playing" then
                if s.hole and s.kind ~= "decoy" then game.holes[s.hole]:Click("LeftButton") end
                if s.hole2 and s.kind2 ~= "decoy" then game.holes[s.hole2]:Click("LeftButton") end
            end
        end
    end
    local P = MG.Progress
    Play()
    local stars = W.Stars(game.state)
    card = Card()
    equal(card.title.text .. " | " .. tostring(stars >= 1), "Stage 1 cleared! | true", "the win card")
    equal(game.hud.chips[1].check.shown and game.hud.chips[1].text.text, "10/10", "the goal ticked on the HUD")
    equal(P:Level("whack") .. " " .. P:Stars("whack", 1) .. " " .. P:Coins(), "2 " .. stars .. " " .. (15 + 5 * stars),
        "stage 2 open, its stars kept, 15 coins and 5 a star")
    equal(EraUIDB.miniGameResume.whack, nil, "nothing left waiting")
    equal(Button("Next") ~= nil and Button("Map") ~= nil, true, "Next and Map")
    Button("Next"):Click()
    equal(game.screen, "map", "Next: the map")
    M.Tick(3)
    card = Card()
    equal(MG.Card.Shown("whack") and card.title.text, "Stage 2", "the glow walks on, then stage 2's intro")
    -- Stage 2 lost: the lose card, +10 seconds for coins, Try again.
    Button("Start"):Click()
    for _ = 1, 700 do M.Tick(.05) end
    card = Card()
    equal(game.state.outcome .. " | " .. card.title.text .. " | " .. card.lines[1].progress.text, "lost | Time's up | 0/14", "no hits: Time's up, how far you got")
    local more = Button("+10 seconds")
    equal(more ~= nil and more.sub.text, "40 coins", "+10 seconds for 40 coins")
    equal(EraUIDB.miniGameResume.whack.outcome, "lost", "the lose card kept for the next flight")
    local coins = P:Coins()
    if coins >= 40 then P:Spend(coins - 30) end
    more:Click()
    equal(M.Shell().note.text .. " " .. tostring(MG.Card.Shown("whack")), "Not enough coins. You need 40. true", "not enough coins: says so")
    P:AddCoins(100)
    coins = P:Coins()
    more:Click()
    equal(game.state.phase .. " " .. game.state.length .. " " .. P:Coins() .. " " .. game.button.label.text, "paused 40 " .. (coins - 40) .. " Resume",
        "bought: 10 more seconds, paused")
    game.button:Click()
    for _ = 1, 230 do M.Tick(.05) end
    equal(game.state.outcome, "lost", "lost again")
    equal(Button("+10 seconds").sub.text, "60 coins", "the next +10 seconds costs more")
    coins = P:Coins()
    Button("Try again"):Click()
    equal(P:Coins() .. " " .. game.state.phase .. " " .. game.state.stage .. " " .. P:Level("whack"), (coins + 2) .. " countdown 2 2",
        "Try again: the loss pays 2 coins, stage 2 from its start")
    Play()
    equal(game.state.outcome .. " | " .. Card().lines[1].text.text, "won | New: The shop", "stage 2 cleared opens the shop")
    Button("Map"):Click()
    equal(MG.Card.Shown("whack") and Card().title.text, "The shop", "its how-it-works card")
    Button("Got it"):Click()
    equal(game.screen .. " " .. tostring(MG.Card.Shown("whack")) .. " " .. tostring(P:Seen("shop")), "map false true", "then the map")
    equal(map.nodes[1].stars[1].shown and map.nodes[3].state, "open", "stars under the stages cleared, stage 3 open")
    -- The shop from the map.
    game.shopButton:Click()
    equal(MG.Shop.Shown("whack"), true, "the shop opens")
    MG.Shop.Close("whack")
    -- Stage 3's first try: the golden head's how-it-works card first.
    map.nodes[3]:Click()
    equal(Card().title.text, "Golden gnome", "a new kind of head: how it works first")
    Button("Got it"):Click()
    equal(Card().title.text .. " | " .. Card().lines[2].text.text, "Stage 3 | Bonk 1 golden gnome", "then the intro")
    Button("Map"):Click()
    map.nodes[3]:Click()
    equal(Card().title.text, "Stage 3", "seen once only")
    Button("Map"):Click()
end
-- An unknown command, and the shop still locked on a new account.
Session()
MG:Open("whack", "command")
do
    local game = Game()
    game.shopButton:Click()
    equal(M.Shell().note.text .. " " .. tostring(MG.Shop.Shown("whack")), "Clear stage 2 to open the shop. false", "the shop opens at stage 2")
    equal(MG:Command("whack", "dance"), false, "an unknown word: not handled")
    equal(M.printed[#M.printed], "Unknown mini-game command: dance", "and said")
end

-- Flights: the round waits for the next one, on any character ------------------------------------

local account
Session({db = {miniGameFlight = "whack"}, random = Rng(3)})
do
    M.TakeOff(3)
    local game = Game()
    equal(game.screen .. " " .. Card().title.text, "stage Stage 1", "a first flight: stage 1's intro")
    game.button:Click()
    M.Tick(4)
    local hits = 0
    for _ = 1, 200 do
        M.Tick(.05)
        local s = game.state
        if s.hole and s.kind ~= "decoy" then
            game.holes[s.hole]:Click("LeftButton")
            hits = hits + 1
        end
        if hits == 3 then break end
    end
    local at = game.state.elapsed
    M.Land()
    equal(M.Showing() or game.state.phase .. " " .. game.state.score, "paused 3", "landed: the stage paused, not ended")
    account = EraUIDB
end
Session({db = account, char = {}, random = Rng(4)})
do
    M.TakeOff(3)
    local game = Game()
    equal(game.screen .. " " .. game.state.mode .. " " .. game.state.stage .. " " .. game.state.score .. " " .. game.state.phase .. " " .. game.button.label.text,
        "stage stage 1 3 paused Resume", "the next flight, on another character: the same stage, 3 points, paused")
    equal(M.Shell().note.text, "Carrying on with stage 1. Click Resume.", "and says so")
    game.button:Click()
    M.Tick(1)
    equal(game.state.phase, "playing", "Resume carries on")
    M.Land()
end
-- A lose card waiting comes back on the next flight.
Session({db = account, random = Rng(5)})
do
    M.TakeOff(3)
    local game = Game()
    game.button:Click()
    M.Tick(40)
    equal(game.state.outcome .. " " .. Card().title.text, "lost Time's up", "lost on a flight")
    M.Land()
end
Session({db = account, random = Rng(6)})
do
    M.TakeOff(3)
    equal(Game().state.outcome .. " " .. tostring(MG.Card.Shown("whack")) .. " " .. Card().title.text, "lost true Time's up",
        "the next flight: the lose card again, +10 seconds still on offer")
    local coins = MG.Progress:Coins()
    Button("Map"):Click()
    equal(MG.Progress:Coins() .. " " .. tostring(EraUIDB.miniGameResume.whack), (coins + 2) .. " nil", "leaving it pays the loss's coins")
    M.Land()
end
-- A Quick round waits too; the last kind of round is what a flight brings.
Session({db = {miniGameFlight = "whack"}, random = Rng(8)})
do
    MG:Open("whack", "command")
    Game().button:Click()
    M.Tick(5)
    MG:Close("hand")
    account = EraUIDB
end
Session({db = account, random = Rng(9)})
do
    M.TakeOff(3)
    equal(Game().screen .. " " .. Game().state.phase .. " " .. M.Shell().note.text, "quick paused Carrying on with your Quick round. Click Resume.",
        "a Quick round left on the ground carries on in the air")
    Game().button:Click()
    M.Tick(30)
    equal(Game().state.phase, "over", "played out")
    M.Land()
    M.TakeOff(3)
    equal(Game().screen .. " " .. Game().state.phase .. " " .. M.Shell().note.text, "quick ready Click Start, then whack the gnome.",
        "the next flight: a fresh Quick round, as that was the last")
    M.Land()
end
-- A damaged snapshot is dropped: the next stage's intro instead.
Session({db = {miniGameFlight = "whack", miniGameResume = {version = 1, whack = {v = 1, mode = "stage", stage = 1, score = -5}}}})
do
    M.TakeOff(3)
    equal(Game().state.phase .. " " .. Card().title.text .. " " .. tostring(EraUIDB.miniGameResume.whack), "ready Stage 1 nil",
        "a damaged round is dropped, stage 1's intro instead")
    M.Land()
end

-- Carry on from the map ----------------------------------------------------------------------------

Session({random = Rng(13)})
MG:Open("whack", "command")
do
    local game = Game()
    MG.Progress:Data().whack.stage = 2
    game:StartStage(1)
    M.Tick(5)
    local score = game.state.score
    for _ = 1, 40 do
        M.Tick(.05)
        if game.state.hole and game.state.kind ~= "decoy" then game.holes[game.state.hole]:Click("LeftButton") end
    end
    score = game.state.score
    MG:Close("hand")
    MG:Open("whack", "command")
    local map = game.map
    equal(tostring(map.nodes[1].carry.shown) .. " " .. tostring(map.nodes[2].carry.shown), "true false", "Carry on under stage 1 only")
    map.nodes[2]:Click()
    equal(Card().sub.text, "Stage 1 in progress will be left.", "another stage's intro says the waiting one will be left")
    Button("Map"):Click()
    map.nodes[1]:Click()
    equal(Button("Carry on") ~= nil and Button("Start again") ~= nil and Button("Map") ~= nil, true, "its own intro: Carry on, Start again, Map")
    Button("Carry on"):Click()
    equal(game.screen .. " " .. game.state.phase .. " " .. game.state.score .. " " .. game.button.label.text, "stage paused " .. score .. " Resume",
        "Carry on: the round as left, paused")
    game.mapButton:Click()
    map.nodes[1]:Click()
    Button("Start again"):Click()
    equal(game.state.phase .. " " .. game.state.score, "countdown 0", "Start again: from its start")
end

-- Kinds of head in the window --------------------------------------------------------------------

Session({models = true, random = Rng(12)})
MG:Open("whack", "command")
do
    local game = Game()
    game:StartStage(5)
    M.Tick(3.2)
    local hole = game.holes[2]
    local g = hole.g
    -- A decoy: your side's worker (the Horde's: a peon), a ring of your side's colour.
    game:Popped(2, "decoy")
    equal(hole.model.display .. " " .. hole.model.zoom .. " " .. tostring(hole.ring.shown) .. " " .. table.concat(hole.ring.vertex, ",", 1, 3),
        "10038 0.65 true " .. table.concat(W.SIDE.Horde, ","), "a decoy: the Lazy Peon, framed, ringed in the Horde's red")
    near(hole.model.insets[4], g.bh * .25, "the head high in its frame (a quarter left empty under it)")
    game.state.hole, game.state.kind, game.state.score, game.state.streak = 2, "decoy", 1, 2
    local before = #M.sounds
    hole:Click("LeftButton")
    local played = table.concat(M.sounds, " ", before + 1)
    equal(game.state.score .. " " .. game.state.streak .. " " .. M.Shell().note.text, "0 0 Oops, that's one of yours!", "hit: points lost, the streak gone, said")
    equal(played:find("91242:SFX", 1, true) ~= nil and (played:find("7194:SFX", 1, true) or played:find("7121:SFX", 1, true)) ~= nil, true,
        "a boing and the peon's complaint")
    -- A golden head: gold glow; hit, coins.
    game:Popped(4, "golden")
    local golden = game.holes[4]
    equal(golden.aura.shown and golden.aura.atlas .. " " .. golden.aura.blend .. " " .. golden.model.display, "BonusChest-CircleGlow ADD 6973",
        "a golden head: the gnome in a gold glow")
    game.state.hole, game.state.kind = 4, "golden"
    before = #M.sounds
    golden:Click("LeftButton")
    played = table.concat(M.sounds, " ", before + 1)
    equal(played:find("722:SFX", 1, true) ~= nil and played:find("40345:SFX", 1, true) ~= nil and game.state.golden, 1, "a squish and coins")
    -- The boss: 1.25 times the size, Mekkatorque, the HUD's boss chip.
    game:Popped(7, "boss")
    local boss = game.holes[7]
    near(boss.body.w, boss.g.bw * 1.25, "the boss: 1.25 times the size")
    equal(boss.model.display .. " " .. boss.model.zoom .. " " .. boss.model.w, "7006 0.45 " .. boss.g.bw * 1.25, "High Tinker Mekkatorque, a wider shot")
    game.state.hole, game.state.kind, game.state.bossHits = 7, "boss", 0
    before = #M.sounds
    boss:Click("LeftButton")
    played = table.concat(M.sounds, " ", before + 1)
    game:PaintHud()
    equal(game.hud.boss.shown and game.hud.boss.name.text .. " | " .. game.hud.boss.text.text, "Boss Gnome | Beaten 0/1", "the boss chip")
    equal(game.hud.boss.pips[1].vertex[1] > .9 and game.hud.boss.pips[2].vertex[1] < .5, true, "a pip filled for his hit")
    local to = game.state.hole
    equal(played:find("722:SFX", 1, true) ~= nil and to ~= 7 and boss.knocked and boss.hold > 0, true, "a hit: a squish, a flinch, and down he goes")
    local there = game.holes[to]
    equal(there.kind .. " " .. there.model.display .. " " .. tostring(there.aura.shown), "boss 7006 true", "he comes up in another hole, glowing red")
    there:Click("LeftButton")
    before = #M.sounds
    game.holes[game.state.hole]:Click("LeftButton")
    played = table.concat(M.sounds, " ", before + 1)
    equal(game.state.beaten .. " " .. tostring(played:find("50111:SFX", 1, true) ~= nil), "1 true", "the third in a row: beaten, his fall")
    -- Back to normal: the target's own model and size.
    game:Popped(7, "normal")
    equal(boss.model.display .. " " .. boss.body.w .. " " .. tostring(boss.aura.shown), "6973 " .. boss.g.bw .. " false", "the next head in that hole: a gnome again")
end
Session({models = true, faction = "Alliance"})
MG:Open("whack", "command")
do
    local game = Game()
    equal(game.map.ground.texture, 187021, "the Alliance's map: Durotar's ground")
    game:StartStage(5)
    game:Popped(1, "decoy")
    game:Popped(2, "boss")
    equal(game.holes[1].model.display .. " " .. game.holes[2].model.display .. " " .. table.concat(game.holes[1].ring.vertex, ",", 1, 3),
        "89 4259 " .. table.concat(W.SIDE.Alliance, ","), "an Alliance player's decoy: a peasant ringed in blue; the boss: an Orgrimmar grunt")
end
-- No models: portraits for each kind.
Session()
MG:Open("whack", "command")
do
    local game = Game()
    game:Popped(1, "decoy")
    game:Popped(2, "boss")
    equal(game.holes[1].face.texture .. " " .. game.holes[2].face.texture, "134170 Interface\\Icons\\INV_Misc_Head_Gnome_01", "no models: the decoy's and the boss's icons")
    game:Popped(1, "normal")
    equal(game.holes[1].face.texture .. " " .. table.concat(game.holes[1].face.coords, ","), "Interface\\CharacterFrame\\TemporaryPortrait-Male-Gnome 0,1,0,1",
        "and the gnome's portrait again, uncropped")
end

-- Coins: a boss stage's bonus, golden heads paid on a loss too ---------------------------------------

Session({random = Rng(31)})
MG:Open("whack", "command")
do
    local game, P = Game(), MG.Progress
    local function Play(only)
        for _ = 1, 2000 do
            local s = game.state
            if s.phase == "over" then return end
            M.Tick(.05)
            s = game.state
            if s.phase == "playing" then
                if s.hole and s.kind ~= "decoy" and (not only or s.kind == only) then game.holes[s.hole]:Click("LeftButton") end
                if s.hole2 and s.kind2 ~= "decoy" and (not only or s.kind2 == only) then game.holes[s.hole2]:Click("LeftButton") end
            end
        end
    end
    P:Data().whack.stage = 5
    local coins = P:Coins()
    game:StartStage(5)
    Play()
    local stars, golden = W.Stars(game.state), game.state.golden
    equal(game.state.outcome .. " " .. tostring(game.state.beaten >= 3), "won true", "the Boss Gnome beaten at every showing, stage 5 won")
    equal(P:Coins() - coins, 15 + 5 * stars + 40 + 5 * golden, "a boss stage's first clear: 15, 5 a star, 40 for the boss, 5 a golden head")
    equal(Card().coins.text ~= nil and P:Level("whack"), 6, "stage 6 open")
    MG.Card.Hide("whack")
    coins = P:Coins()
    game:StartStage(3)
    Play("golden")
    golden = game.state.golden
    equal(game.state.outcome .. " " .. tostring(golden >= 1), "lost true", "stage 3: only golden heads hit, lost")
    Button("Map"):Click()
    equal(P:Coins() - coins, 2 + 5 * golden, "the loss pays 2, and 5 for each golden head")
end

-- Framing and /era whack tune ------------------------------------------------------------------------

Session({models = true, commands = true})
MG:Open("whack", "command")
do
    local game = Game()
    local model = game.holes[1].model
    equal(model.zoom .. " " .. model.camera .. " " .. table.concat(model.position, ",") .. " " .. model.rotation, "0.55 1 0,0,0 0.38",
        "the gnome framed head and shoulders, its column's turn")
    near(model.insets[4], game.holes[1].g.bh * .2, "a fifth of its frame left empty under it")
    M.printed[#M.printed + 1] = "-"
    SlashCmdList.ERAUI("whack tune zoom .9")
    equal(M.printed[#M.printed], "Whack tune gnome: zoom 0.90, cam 1.00, up 0.00, turn 0, body 1.00, peek 0.60, lift 0.20.", "/era whack tune zoom .9: said")
    local all = true
    for _, hole in ipairs(game.holes) do if hole.model.zoom ~= .9 then all = false end end
    equal(all and EraUIDB.miniGameTune.gnome.zoom, .9, "every hole at once, and saved")
    MG:Command("whack", "tune zoom 5")
    MG:Command("whack", "tune turn 400")
    MG:Command("whack", "tune up -9")
    MG:Command("whack", "tune bossgnome body 3")
    equal(EraUIDB.miniGameTune.gnome.zoom .. " " .. EraUIDB.miniGameTune.gnome.turn .. " " .. EraUIDB.miniGameTune.gnome.up .. " "
        .. EraUIDB.miniGameTune.bossGnome.body, "1 180 -2 1.6", "kept in range")
    near(model.rotation, .38 + math.pi, "turned")
    MG:Command("whack", "tune peek .9")
    game:Screen("quick")
    M.Tick(1)
    near(game.holes[5].up, .9, "the peek between rounds as tuned")
    MG:Command("whack", "tune")
    equal(M.printed[#M.printed]:find("^Whack tune gnome: zoom 1.00, cam 1.00, up %-2.00, turn 180, body 1.00, peek 0.90") ~= nil, true, "tune alone says the values")
    MG:Command("whack", "tune nonsense 2")
    equal(M.printed[#M.printed], "Whack tune fields: zoom, cam, up, turn, body, peek, lift.", "an unknown field: the list")
    MG:Command("whack", "tune zoom lots")
    equal(M.printed[#M.printed], "Whack tune zoom takes a number from 0 to 1.", "not a number: the range")
    MG:Command("whack", "tune cursor off")
    equal(M.printed[#M.printed], "The game's pointer always shows over the field; the mallet sits on its tip.", "the pointer is left alone")
    MG:Command("whack", "tune reset")
    equal(tostring(EraUIDB.miniGameTune.gnome) .. " " .. tostring(EraUIDB.miniGameTune.bossGnome) .. " " .. model.zoom, "nil nil 0.55", "reset: the defaults back")
end

-- Sounds in a whole stage ---------------------------------------------------------------------------

Session({random = Rng(21)})
MG:Open("whack", "command")
do
    local game = Game()
    MG.Progress:Data().whack.stage = 20
    game:StartStage(15)
    local before = #M.sounds
    for _ = 1, 900 do
        M.Tick(.05)
        local s = game.state
        if s.phase == "over" then break end
        if s.hole then game.holes[s.hole]:Click("LeftButton") end
        if s.hole2 then game.holes[s.hole2]:Click("LeftButton") end
        if MG.Jitter() < .05 then game.field:Click("LeftButton") end
    end
    local bad, kinds = {}, {}
    for index = before + 1, #M.sounds do
        local id = tonumber(M.sounds[index]:match("^(%d+):"))
        if id and MG.FORBIDDEN_SOUNDS[id] then bad[#bad + 1] = id end
        if id then kinds[id] = true end
    end
    equal(game.state.phase .. " " .. #bad, "over 0", "a whole stage with decoys, golden heads and the boss: no blacksmith or metal sound")
    equal(kinds[722] and kinds[856] and kinds[219930] and kinds[91242] and kinds[50111] or false, true, "squishes, clicks, whooshes, boings, the boss's fall")
end

-- A walk cut short, a stage kept from a Quick round, a Quick round's golden coins ------------------

Session({random = Rng(4)})
MG:Open("whack", "command")
do
    local game = Game()
    game:StartStage(1)
    M.Tick(3.2)
    local s = game.state
    s.bonks, s.score, s.elapsed = 12, 30, s.length - .01
    M.Tick(.1)
    equal(s.outcome .. " " .. tostring(MG.Card.Shown("whack")), "won true", "stage 1 won, its card up")
    Button("Next"):Click()
    M.Tick(.1)
    equal(game.screen .. " " .. tostring(game.map.walking), "map true", "Next: the glow walks to stage 2")
    game.button:Click()
    for _ = 1, 40 do M.Tick(.05) end
    equal(game.screen .. " " .. game.state.mode .. " " .. tostring(MG.Card.Shown("whack")), "quick quick false",
        "Quick round mid-walk: it plays, no stage 2 intro over it")
    -- Hidden mid-walk: no intro waiting.
    game:ToMap()
    game:Next(1)
    MG:Close("hand")
    MG:Open("whack", "switch")
    equal(game.screen .. " " .. tostring(MG.Card.Shown("whack")), "map false", "the window hidden mid-walk: no stale intro")
end
Session({random = Rng(6), db = {miniGameProgress = {version = 1, coins = 0, cards = {golden = true, shop = true},
    blast = {level = 1}, whack = {stage = 5, stars = "1111"}}}})
MG:Open("whack", "command")
do
    local game, P = Game(), MG.Progress
    game:StartStage(3)
    M.Tick(6)
    game:ToMap()
    equal(P:Resume("whack").mode .. " " .. P:Resume("whack").stage .. " " .. tostring(game:Waiting()), "stage 3 3", "stage 3 waits on the map")
    game.button:Click()
    M.Tick(5)
    MG:Close("hand")
    equal(P:Resume("whack").mode .. " " .. P:Resume("whack").stage .. " " .. tostring(game:Waiting()), "stage 3 3",
        "a Quick round played and paused: stage 3 still waits")
    MG:Open("whack", "command")
    game.button:Click()
    game.button:Click()
    local s = game.state
    equal(s.mode .. " " .. s.phase, "quick playing", "the Quick round resumed from the map")
    s.score, s.golden, s.bonks = 20, 2, 10
    s.elapsed = s.length - .01
    local coins = P:Coins()
    M.Tick(.1)
    equal(s.outcome .. " " .. (P:Coins() - coins) .. " " .. P:Resume("whack").stage, "done 14 3",
        "a Quick round over: 4 coins for 20 points and 5 a golden head; stage 3 still waits")
    game:Intro(3)
    equal(Button("Carry on") ~= nil, true, "and its intro says Carry on")
end

-- Reset --------------------------------------------------------------------------------------------

Session({random = Rng(2)})
MG:Open("whack", "command")
do
    local game = Game()
    game:StartStage(1)
    M.Tick(5)
    MG.Progress:Reset()
    equal(game.state.mode .. " " .. game.state.phase .. " " .. game.screen .. " " .. tostring(EraUIDB.miniGameResume), "quick ready map nil",
        "progress reset: no round kept, the map")
end

-- A one-pointer bot: it sees a head come up and needs about `react` seconds
-- (a little more or less each time) to reach and click it, one at a time,
-- the oldest first, and .3 s to move on after a hit; it bonks one decoy in
-- seven. The boss after a hit is a new head in a new hole. ------------------------------------------

do
    local MOVE = .3
    local function Play(n, seed, react)
        local s = W.NewStage(n, Rng(seed))
        local roll = Rng(seed + 99)
        W.Start(s)
        local busy, t, seen = 0, 0, {}
        while s.phase == "playing" do
            W.Advance(s, .05)
            t, busy = t + .05, busy - .05
            for slot = 1, 2 do
                local hole, kind = s.hole, s.kind
                if slot == 2 then hole, kind = s.hole2, s.kind2 end
                if hole and not seen[hole] then
                    seen[hole] = {at = t, need = react + (roll(0, 1000) / 1000 - .4) * .25, skip = kind == "decoy" and roll(1, 7) > 1}
                end
            end
            for hole in pairs(seen) do if hole ~= s.hole and hole ~= s.hole2 then seen[hole] = nil end end
            if busy <= 0 then
                local pick, pickAt
                for hole, h in pairs(seen) do
                    if not h.skip and t - h.at >= h.need and (not pickAt or h.at < pickAt) then pick, pickAt = hole, h.at end
                end
                if pick then
                    W.Hit(s, pick)
                    seen[pick] = nil
                    busy = MOVE
                end
            end
        end
        return s.outcome == "won"
    end
    local function Share(react, from, to, seeds, bossOnly)
        local wins, games, worst = 0, 0, 1
        for n = from, to do
            if not bossOnly or W.StageSpec(n).boss then
                local won = 0
                for seed = 1, seeds do if Play(n, seed * 31 + n, react) then won = won + 1 end end
                wins, games, worst = wins + won, games + seeds, math.min(worst, won / seeds)
            end
        end
        return wins / games, worst
    end
    local half, halfWorst = Share(.5, 1, 60, 6)
    local quick = Share(.45, 1, 60, 4)
    local slowEarly = Share(.6, 1, 30, 4)
    local slowLate = Share(.6, 41, 60, 4)
    local bossEarly = Share(.6, 5, 15, 6, true)
    print(("Whack one-pointer bot, stages 1-60: .5 s wins %d%% (worst stage %d%%), .45 s %d%%; .6 s wins %d%% of 1-30, %d%% of 41-60, early bosses %d%%."):format(
        math.floor(half * 100 + .5), math.floor(halfWorst * 100 + .5), math.floor(quick * 100 + .5), math.floor(slowEarly * 100 + .5),
        math.floor(slowLate * 100 + .5), math.floor(bossEarly * 100 + .5)))
    equal(half >= .9 and halfWorst >= .33, true, "a half-second player wins nearly every stage to 60, none a wall")
    equal(quick >= .95, true, "a quicker one nearly all")
    equal(slowEarly >= .8, true, "a slower one (.6 s) still gets through the first 30")
    equal(slowLate < slowEarly - .1, true, "and finds 41-60 harder: the stages climb")
    equal(bossEarly >= .8, true, "the early bosses can be caught as they jump")
end

print("Whack stages checks passed: " .. M.checks .. " assertions.")
