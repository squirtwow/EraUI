-- The mini-games' shared campaign parts on a mock client (Tools/MiniGameMock.lua):
-- the saved progress (Modules/MiniGameProgress.lua: migration and sanitising,
-- the welcome gift, coins, power-ups and prices, Finish and its coins, stars,
-- bests and milestones, the resume store, Reset), art and sounds by role
-- (Modules/MiniGameAssets.lua: fallbacks, faction picks, models and their
-- framing, the tune store, no blacksmith or metal sound anywhere), the level
-- map (Modules/MiniGameMap.lua), the cards (Modules/MiniGameCards.lua), the
-- shop (Modules/MiniGameShop.lua) and the core's new contract (the bigger
-- window, the coin purse, Shown's why, game:Keep as you log out, /era whack
-- <words>). Run: fengari Tools/TestMiniGameProgress.lua
local M = dofile("Tools/MiniGameMock.lua")
local equal, near, Tick = M.equal, M.near, M.Tick
local CORE = {"MiniGames", "MiniGameFX", "MiniGameAssets", "MiniGameProgress", "MiniGameMap", "MiniGameCards", "MiniGameShop"}
local MG, P

local function Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = Copy(v) end
    return out
end
-- A table as one line, keys sorted (to compare whole tables).
local function Dump(value)
    if type(value) ~= "table" then return type(value) == "string" and ("%q"):format(value) or tostring(value) end
    local keys = {}
    for k in pairs(value) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
    end)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = tostring(k) .. "=" .. Dump(value[k]) end
    return "{" .. table.concat(parts, ",") .. "}"
end
local function Core(opts)
    opts = opts or {}
    opts.only = opts.only or CORE
    MG = M.Session(opts)
    P = MG.Progress
    return MG
end
local function Has(list, value)
    for _, each in ipairs(list) do if each == value then return true end end
    return false
end
local function Since(n) return table.concat(M.sounds, " ", n + 1) end

-- The files (Tools/TestRules.mjs checks the list against EraUI.toc) ------------------------

for _, name in ipairs(M.FILES) do equal(type(loadfile("Modules/" .. name .. ".lua")), "function", name .. " loads") end

-- 1. Migration and sanitising --------------------------------------------------------------------

Core()
do
    local d = P:Data()
    equal(Dump(d), Dump(P.Default()), "no record: the version 1 defaults")
    equal(d.version .. " " .. d.stamp .. " " .. d.coins .. " " .. d.blast.level .. " " .. d.whack.stage .. " " .. d.blast.last .. " " .. d.whack.last
        .. " " .. d.blast.look .. " " .. d.whack.mallet, "1 0 0 1 1 level stage stone wood", "level 1, stage 1, no coins")
    equal(EraUIDB.miniGameProgress == d and P:Data() == d, true, "kept in EraUIDB.miniGameProgress, the same table each time")
    equal(d.gifts.welcome, nil, "a new player gets no welcome gift")
end

-- Played the first games: 50 coins once, the old bests and boards untouched.
do
    local best = {blast = 1730, whack = 12}
    local char = {miniGames = {best = {blast = 900, whack = 7}, games = {blast = {board = string.rep("orc,", 63) .. "orc", score = 990, meter = 4, version = 1}}}}
    local bestCopy, charCopy = Dump(best), Dump(char)
    Core({db = {miniGameBest = best, miniGamePosition = {x = 10, y = -20}}, char = char})
    equal(P:Coins() .. " " .. tostring(P:Data().gifts.welcome) .. " " .. P:Data().earned, "50 true 50", "an old player: the 50-coin welcome")
    P:Data()
    equal(P:Coins(), 50, "only once")
    equal(Dump(EraUIDB.miniGameBest) .. Dump(EraUIClassicCharDB), bestCopy .. charCopy, "the old bests and the kept board untouched")
    local db = EraUIDB
    Core({db = db, char = Copy(char)})
    equal(P:Coins(), 50, "another session: no second welcome")
end
Core({db = {miniGameBest = {whack = 0}}, char = {miniGames = {best = {blast = 3}}}})
equal(P:Coins(), 50, "this character's own best counts too")

-- Damaged fields, one by one; good ones and unknown keys stay.
do
    local damaged = {version = 1, stamp = "x", coins = -5, earned = 0 / 0,
        powers = {mallet = 1 / 0, shuffle = 2.5, swap = "3", moves = -1, charge = 1e300, sheep = 4, extra = "kept"},
        unlocked = {shop = true, mallet = "yes", [5] = true, swap = false}, cards = "bad", gifts = {["blast:3"] = true, x = 1},
        blast = {level = 0, stars = "12x", best = {[1] = 900, [2] = -3, [3] = 2.7, [1.5] = 4, note = "kept"}, last = "nope", look = 5,
            tries = -1, wins = 3.9, future = "kept"},
        whack = "bad", future = {deep = {true}}}
    Core({db = {miniGameProgress = damaged}})
    local d = P:Data()
    equal(d == damaged, true, "the same table, fixed in place")
    equal(d.stamp .. " " .. d.coins .. " " .. d.earned, "0 0 0", "a string, a negative and NaN: their defaults")
    equal(d.powers.mallet .. " " .. d.powers.shuffle .. " " .. d.powers.swap .. " " .. d.powers.moves .. " " .. d.powers.charge .. " "
        .. d.powers.sheep .. " " .. d.powers.lust .. " " .. d.powers.extra, "0 2 0 0 99 4 0 kept",
        "power-ups: infinite, a string and a negative to 0, 2.5 floored, huge capped at 99, a missing one 0, unknown kept")
    equal(Dump(d.unlocked) .. " " .. Dump(d.cards) .. " " .. Dump(d.gifts), '{shop=true} {} {blast:3=true}', "sets keep only [name] = true")
    equal(d.blast.level .. " " .. d.blast.stars .. " " .. Dump(d.blast.best) .. " " .. d.blast.last .. " " .. d.blast.look .. " "
        .. d.blast.tries .. " " .. d.blast.wins .. " " .. d.blast.future, '1  {1=900,3=2,note="kept"} level stone 0 3 kept',
        "Blast: level 0 to 1, a bad stars string emptied, bad bests dropped, unknown kept")
    equal(Dump(d.whack), Dump(P.Default().whack), "Whack not a table: its defaults")
    equal(d.future.deep[1], true, "unknown keys kept as they are")
    local once = Dump(d)
    P.Clean(d)
    equal(Dump(d), once, "sanitising twice gives the same table")
    Core({db = {miniGameProgress = {version = 1, coins = 1e9, stamp = 2.5, blast = {level = 1e12, stars = "3212"}}}})
    equal(P:Coins() .. " " .. P:Data().stamp .. " " .. P:Level("blast") .. " " .. P:Stars("blast", 4), "999999 2 1000000 2", "huge coins and levels capped")
    Core({db = {miniGameProgress = {version = 2, coins = 30, newThing = {a = 1}, blast = {level = 5}}}})
    equal(P:Data().version .. " " .. P:Coins() .. " " .. P:Data().newThing.a .. " " .. P:Level("blast"), "2 30 1 5",
        "a newer EraUI's record: read, its version never lowered, its fields kept")
    Core({db = {miniGameProgress = {version = "1", coins = 12}}})
    equal(P:Data().version .. " " .. P:Coins(), "1 12", "a damaged version: fixed, the rest kept")
end

-- 2. Coins, power-ups and prices -------------------------------------------------------------------

Core()
do
    equal(P:AddCoins(25, "test") .. " " .. P:Data().earned, "25 25", "coins added and counted as earned")
    equal(P:AddCoins(-3) .. " " .. P:AddCoins(2.9) .. " " .. P:AddCoins(0 / 0) .. " " .. P:AddCoins("x"), "25 27 27 27", "never negative, whole only")
    equal(P:AddCoins(2e6), 999999, "capped at 999,999")
    equal(tostring(P:Spend(1000000)) .. " " .. tostring(P:Spend(-1)) .. " " .. P:Coins(), "false false 999999", "can't spend more than you have, nor less than 0")
    equal(tostring(P:Spend(999999)) .. " " .. tostring(P:Spend(1)) .. " " .. P:Coins(), "true false 0", "spent to 0, never below")
    equal(P:Price("moves", 0) .. "," .. P:Price("moves", 1) .. "," .. P:Price("moves", 2) .. "," .. P:Price("moves", 3) .. "," .. P:Price("moves"),
        "60,90,120,120,60", "the +5 moves ladder: 60, 90, 120, 120")
    equal(P:Price("time", 0) .. "," .. P:Price("time", 1) .. "," .. P:Price("time", 5) .. " " .. tostring(P:Price("nothing")),
        "40,60,80 nil", "Whack's +10 seconds: 40, 60, 80; an unknown item has no price")
    local ok, why = P:Buy("mallet")
    equal(tostring(ok) .. " " .. why, "false locked", "a power-up not yet open can't be bought")
    P:Unlock("mallet")
    local price
    ok, why, price = P:Buy("mallet")
    equal(tostring(ok) .. " " .. why .. " " .. price, "false coins 40", "not enough coins: says how many it needs")
    P:AddCoins(100)
    local saves = M.saves()
    ok, why, price = P:Buy("mallet")
    equal(tostring(ok) .. " " .. tostring(why) .. " " .. price .. " " .. P:Coins() .. " " .. P:Count("mallet"), "true nil 40 60 1", "bought: 40 coins, one Mallet")
    equal(M.saves() > saves, true, "a purchase is saved")
    ok, why, price = P:BuyAndUse("mallet")
    equal(tostring(ok) .. " " .. price .. " " .. P:Coins() .. " " .. P:Count("mallet"), "true 0 60 0", "buy and use: the one owned is used, no coins")
    ok, why, price = P:BuyAndUse("mallet")
    equal(tostring(ok) .. " " .. price .. " " .. P:Coins() .. " " .. P:Count("mallet"), "true 40 20 0", "none owned: bought and used at once")
    equal(tostring(P:Use("mallet")) .. " " .. tostring(P:Use("nothing")), "false false", "none left to use")
    equal(P:Give("mallet", 200) .. " " .. P:Give("nothing", 2), "99 0", "at most 99 of a power-up")
    P:AddCoins(100)
    ok, why, price = P:BuyAndUse("time", 1)
    equal(tostring(ok) .. " " .. price .. " " .. P:Coins(), "true 60 60", "Whack's +10 seconds: the second in a round costs 60")
    ok, why = P:Buy("mallet:bone")
    equal(tostring(ok) .. " " .. why, "false locked", "a milestone mallet can't be bought")
    ok, why = P:Buy("mallet:gnomish")
    equal(tostring(ok) .. " " .. why, "false coins", "the Gnomish mallet needs 250 coins")
    P:AddCoins(300)
    ok = P:Buy("mallet:gnomish")
    equal(tostring(ok) .. " " .. tostring(P:Unlocked("mallet:gnomish")) .. " " .. P:Coins(), "true true 110", "bought: it's yours")
    ok, why = P:Buy("mallet:gnomish")
    equal(tostring(ok) .. " " .. why, "false owned", "never twice")
    equal(tostring(P:SetMallet("gnomish")) .. " " .. P:Mallet() .. " " .. tostring(P:SetMallet("frost")) .. " " .. P:Mallet(), "true gnomish false gnomish",
        "a mallet you have can be used; one you don't, not")
    equal(tostring(P:Unlocked("mallet:wood")) .. " " .. tostring(P:Unlocked("zone:elwynn")) .. " " .. tostring(P:Unlocked("look:stone")), "true true true",
        "the wooden mallet, the first zone and the stone board are always open")
    local stamp = P:Data().stamp
    P:AddCoins(1)
    equal(P:Data().stamp, stamp + 1, "every change bumps the stamp")
end

-- 3. Finish: coins, stars, bests, the next level -----------------------------------------------------

Core()
do
    local r = P:Finish("blast", 1, {won = true, stars = 2, score = 1500, movesLeft = 7, epics = 2})
    equal(r.coins .. " " .. tostring(r.first) .. " " .. r.newStars .. " " .. r.stars .. " " .. r.best .. " " .. tostring(r.newBest) .. " " .. tostring(r.opened),
        "45 true 2 2 1500 false 2", "a first clear: 20 + 10 a star + 1 per 2 moves left + 1 an epic; level 2 opens")
    equal(P:Coins() .. " " .. P:Level("blast") .. " " .. P:Stars("blast", 1) .. " " .. P:BestScore("blast", 1) .. " " .. P:Data().blast.stars,
        "45 2 2 1500 2", "saved: coins, level, stars, best")
    r = P:Finish("blast", 1, {won = true, stars = 3, score = 1400, movesLeft = 1})
    equal(r.coins .. " " .. tostring(r.first) .. " " .. r.newStars .. " " .. P:Stars("blast", 1) .. " " .. P:BestScore("blast", 1) .. " " .. tostring(r.opened),
        "15 false 1 3 1500 nil", "a replay: 5 + 10 for the star above the old best; the best stays; nothing opens")
    r = P:Finish("blast", 1, {won = true, stars = 1, score = 1600})
    equal(r.coins .. " " .. P:Stars("blast", 1) .. " " .. P:BestScore("blast", 1) .. " " .. tostring(r.newBest), "5 3 1600 true", "stars only rise; a higher score is a new best")
    local tries, wins = P:Data().blast.tries, P:Data().blast.wins
    r = P:Finish("blast", 2, {won = false, score = 300, epics = 3})
    equal(r.coins .. " " .. P:Stars("blast", 2) .. " " .. P:Level("blast") .. " " .. P:Data().blast.tries - tries .. " " .. P:Data().blast.wins - wins,
        "5 0 2 1 0", "a loss: 2 coins and the epics still paid, no stars, no level")
    r = P:Finish("blast", 2, {won = true, stars = 1, score = 900, boss = true})
    equal(r.coins, 80, "a boss's first clear: +50")
    equal(P:Data().blast.stars, "31", "stars written in order")
    -- Whack.
    r = P:Finish("whack", 1, {won = true, stars = 3, score = 30, golden = 2})
    equal(r.coins .. " " .. P:Level("whack") .. " " .. P:Stars("whack", 1), "40 2 3", "a first stage: 15 + 5 a star + 5 a golden head")
    r = P:Finish("whack", 1, {won = true, stars = 3, score = 20})
    equal(r.coins, 3, "a replay with no new star: 3")
    r = P:Finish("whack", 2, {won = false, score = 4, golden = 1})
    equal(r.coins, 7, "a lost stage: 2, and its golden heads still paid")
    r = P:Finish("whack", 5, {won = true, stars = 1, score = 30, boss = true})
    equal(r.coins, 60, "a boss stage's first clear: +40")
    r = P:Finish("whack", "quick", {score = 23})
    equal(r.coins .. " " .. P:Level("whack"), "4 6", "a Quick round: 1 coin per 5 points, no stage")
    equal(#P:Finish("nothing", 1, {won = true}).unlocks .. " " .. P:Finish("blast", "x", {won = true}).coins, "0 0", "nonsense: nothing")
    -- Free play: a coin as the score passes each 1,000.
    local kept = {}
    equal(P:FreeCoins(kept, 900) .. " " .. P:FreeCoins(kept, 2100) .. " " .. P:FreeCoins(kept, 2900) .. " " .. kept.coined, "0 2 0 2", "Free play: 1 per 1,000 as you pass it")
    equal(P:FreeCoins(kept, 300) .. " " .. kept.coined .. " " .. P:FreeCoins(kept, 1000), "0 0 1", "a new board starts the count again")
    equal(P:TotalStars("blast", 1, 10) .. " " .. P:TotalStars("whack") .. " " .. P:TotalStars("whack", 2, 4), "4 4 0", "stars added up")
    equal(P:Summary(), ("Blast level %d, Whack stage %d, %d coins."):format(P:Level("blast"), P:Level("whack"), P:Coins()), "the /era line")
end

-- 4. Milestones ----------------------------------------------------------------------------------------

Core()
do
    equal(Dump(P:NextUnlock("blast")), Dump({at = 3, id = "shop", name = "The shop"}), "the next milestone: the shop at level 3")
    local got = {}
    for n = 1, 50 do
        local r = P:Finish("blast", n, {won = true, stars = 1, score = 100})
        local gifts = {}
        for _, gift in ipairs(r.gifts) do gifts[#gifts + 1] = gift.id .. "+" .. gift.count end
        if #r.unlocks > 0 or #gifts > 0 or #r.cards > 0 then
            got[#got + 1] = n .. ":" .. table.concat(r.unlocks, ",") .. "|" .. table.concat(gifts, ",") .. "|" .. table.concat(r.cards, ",")
        end
    end
    equal(table.concat(got, " "), "1:||stars 3:shop,mallet|mallet+3|shop,mallet 5:shuffle|shuffle+2|shuffle 8:moves|moves+2|moves "
        .. "10:zone:durotar,look:elwynn|| 12:swap|swap+2|swap 14:charge|charge+2|charge 18:sheep|sheep+2|sheep "
        .. "20:zone:westfall,look:durotar,mallet:bone|| 25:lust|lust+2|lust 30:zone:barrens,look:westfall|| 35:|charge+2,sheep+2| "
        .. "40:zone:duskwood,look:barrens,mallet:fel|| 45:|swap+1| 50:zone:stranglethorn,look:duskwood||",
        "levels 1 to 50: the milestones, their gifts and how-it-works cards (zones show the map's banner instead)")
    equal(P:Count("mallet") .. P:Count("shuffle") .. P:Count("moves") .. P:Count("swap") .. P:Count("charge") .. P:Count("sheep") .. P:Count("lust"),
        "3223442", "the starter power-ups (and level 35's and 45's gifts)")
    P:Finish("blast", 3, {won = true, stars = 3})
    equal(P:Count("mallet"), 3, "replaying level 3: no more Mallets")
    equal(Dump(P:NextUnlock("blast")), Dump({at = 60, id = "zone:tanaris", name = "Tanaris"}), "the next: a made milestone")
    equal(Dump(P:Looks()), Dump({"stone", "elwynn", "durotar", "westfall", "barrens", "duskwood"}), "the board looks open")
    equal(tostring(P:SetLook("tanaris")) .. " " .. P:Look() .. " " .. tostring(P:SetLook("durotar")) .. " " .. P:Look(), "false stone true durotar",
        "Free play's look: only an open one")
    P:See("stars")
    P:Finish("blast", 1, {won = true, stars = 1})
    equal(P:Seen("stars") and P:Seen("shop") == false, true, "cards seen are kept")
    local whack = {}
    for n = 1, 20 do
        local r = P:Finish("whack", n, {won = true, stars = 1})
        if #r.unlocks > 0 then whack[#whack + 1] = n .. ":" .. table.concat(r.unlocks, ",") end
    end
    equal(table.concat(whack, " "), "10:mallet:frost 20:mallet:golden", "Whack's: the shop (already open), Frost at 10, Golden at 20")
    Core()
    equal(table.concat(P:Finish("whack", 1, {won = true}).unlocks, ",") .. "|" .. table.concat(P:Finish("whack", 2, {won = true}).unlocks, ","),
        "|shop", "on a fresh account Whack's stage 2 opens the shop")
    equal(Dump(P:NextUnlock("whack")), Dump({at = 10, id = "mallet:frost", name = "Frost mallet"}), "Whack's next milestone")
    equal(P:Name("zone:durotar") .. "|" .. P:Name("mallet:frost") .. "|" .. P:Name("look:elwynn") .. "|" .. P:Name("swap") .. "|" .. P:Name("lust"),
        "Durotar|Frost mallet|Elwynn Forest board|Free swap|Start with Bloodlust", "the names of unlocks")
    Core({faction = "Alliance"})
    equal(P:Name("lust") .. "|" .. P:Card("lust").title .. "|" .. P:Card("golden").title .. "|" .. P:Card("decoy").icon .. "|" .. P:Card("bossPeon").title,
        "Start with Heroism|Start with Heroism|Golden peon|whack.decoyAlliance|Boss peon", "worded for your faction")
    Core()
    equal(P:Card("golden").title .. "|" .. P:Card("bossPeon").icon .. "|" .. tostring(P:Card("nothing")), "Golden gnome|whack.bossGnome|nil", "and the Horde's")
end

-- 5. Resume and Reset ----------------------------------------------------------------------------------

Core()
do
    equal(P:Resume("blast"), nil, "nothing to carry on")
    local snapshot = {v = 1, mode = "level", level = 3}
    P:SaveResume("blast", snapshot)
    P:SaveResume("whack", {v = 1, mode = "stage", stage = 2})
    equal(P:Resume("blast") == snapshot and EraUIDB.miniGameResume.version == 1 and P:Resume("whack").stage == 2, true, "kept per game")
    P:SaveResume("blast", nil)
    equal(tostring(P:Resume("blast")) .. " " .. P:Resume("whack").stage, "nil 2", "cleared alone")
    equal(P:SaveResume("other", {}), false, "only the two games")
    EraUIDB.miniGameResume.version = 2
    equal(P:Resume("whack"), nil, "a store of another version isn't read")
    P:SaveResume("whack", {v = 1})
    equal(EraUIDB.miniGameResume.version, 1, "and is replaced on the next save")
end
do
    local char = {miniGames = {best = {blast = 900}, games = {blast = {board = "x", score = 5, version = 1}}}}
    Core({db = {miniGameBest = {blast = 1700}, miniGamePosition = {x = 1, y = -2}, miniGameTune = {peon = {zoom = .9}}}, char = char, closeX = true})
    local game = M.TestGame(MG, "whack")
    MG:Open("whack", "command")
    P:AddCoins(80)
    P:Unlock("mallet")
    P:Give("mallet", 3)
    P:Finish("blast", 1, {won = true, stars = 3, score = 100})
    P:SaveResume("blast", {v = 1})
    local stamp = P:Data().stamp
    local kept = Dump(EraUIDB.miniGameBest) .. Dump(EraUIDB.miniGamePosition) .. Dump(EraUIDB.miniGameTune) .. Dump(EraUIClassicCharDB)
    local saves = M.saves()
    equal(P:Reset(), true, "Reset")
    local d = P:Data()
    equal(d.coins .. " " .. P:Count("mallet") .. " " .. tostring(P:Unlocked("mallet")) .. " " .. P:Level("blast") .. " " .. d.blast.stars .. " "
        .. tostring(EraUIDB.miniGameResume) .. " " .. tostring(d.gifts.welcome), '0 0 false 1  nil nil', "everything from the start, no welcome gift again")
    equal(d.stamp, stamp + 1, "its stamp past the old one's, so an older backup can't bring it back")
    equal(Dump(EraUIDB.miniGameBest) .. Dump(EraUIDB.miniGamePosition) .. Dump(EraUIDB.miniGameTune) .. Dump(EraUIClassicCharDB), kept,
        "bests, the window's place, the tune and the Free play board stay")
    equal(Has(game.calls, "ProgressReset") and M.saves() > saves, true, "every built game told, and saved")
    equal(M.Shell().coins.text, "0", "the header's purse repainted")
end

-- 8. The level map ---------------------------------------------------------------------------------------

local function MapSource(states, picked)
    return {game = "blast", PerPage = 10, noun = "level",
        Page = function(page)
            return {title = "Zone " .. page, sub = ("Levels %d to %d"):format(page * 10 - 9, page * 10), ground = "zone.durotar.ground",
                tint = {.8, .4, .2}, locked = page >= 3, lockText = "Beat Zalazane to open."}
        end,
        Node = function(n)
            local s = states[n] or {}
            return {state = s.state or (n <= states.last and "open" or "locked"), stars = s.stars, boss = n % 10 == 0, art = "zone.durotar.boss",
                carry = s.carry}
        end,
        Pick = function(n) picked[#picked + 1] = n end,
        Last = function() return states.last end}
end
Core()
do
    local game = M.TestGame(MG, "blast")
    MG:Open("blast", "command")
    local picked = {}
    local states = {last = 13, [11] = {state = "done", stars = 2}, [12] = {state = "done", stars = 3, carry = true}, [13] = {state = "open"}}
    local map = MG.Map.New(game.holder, MapSource(states, picked))
    local frame = map.frame
    equal(frame.w .. "x" .. frame.h .. " " .. tostring(frame.sizedFirst) .. " " .. tostring(frame.parent == game.holder) .. " " .. tostring(frame.shown),
        "412x500 true true false", "the map: 412 x 500, sized first, in the game's holder, hidden until shown")
    equal(#map.nodes, 10, "ten nodes a page")
    map:Show()
    equal(map:Page() .. " " .. tostring(map:IsShown()) .. " " .. map.title.text .. " | " .. map.sub.text, "2 true Zone 2 | Levels 11 to 20",
        "it opens on the page of the next level, its banner")
    equal(map.ground.texture .. " " .. map.ground.wrapH .. " " .. ("%.3f"):format(map.ground.vertex[1]), "187021 REPEAT 0.440", "the zone's ground, tiled, its tint darkened")
    local nodes = map.nodes
    equal(nodes[1].art.atlas .. " " .. nodes[3].art.atlas .. " " .. nodes[4].art.atlas .. " " .. nodes[10].art.atlas,
        "talents-node-circle-green talents-node-circle-yellow talents-node-circle-locked BossBanner-SkullCircle", "done, open, locked and boss nodes by role")
    equal(nodes[1].label.text .. " " .. tostring(nodes[10].label.shown) .. " " .. tostring(nodes[10].portrait.shown) .. " " .. tostring(nodes[10].portrait.texture),
        "11 false true 236456", "numbers on the nodes; the boss's portrait instead")
    equal(nodes[10].art.desaturated, true, "a locked boss greyed")
    equal(nodes[1].stars[1].atlas .. " " .. nodes[1].stars[2].atlas .. " " .. nodes[1].stars[3].atlas, "tradeskills-star tradeskills-star tradeskills-star-off",
        "two stars under level 11")
    equal(tostring(nodes[2].carry.shown) .. " " .. tostring(nodes[2].stars[1].shown), "true false", "Carry on instead of stars where a level waits")
    equal(tostring(nodes[3].stars[1].shown) .. " " .. table.concat(nodes[4].label.textColour, ","), "false 0.6,0.6,0.6", "no stars on open ones, grey numbers on locked ones")
    equal(map.glow.shown and map.glow.lastPoint[4] .. "," .. map.glow.lastPoint[5] .. " " .. map.glow.atlas, "268,-420 BonusChest-CircleGlow", "the glow on the next level")
    local dots, colour = 0, nil
    for _, dot in ipairs(map.dots) do
        dots = dots + 1
        if dot.segment == 1 then colour = dot.vertex end
    end
    equal(dots >= 25 and ("%g,%g,%g"):format(colour[1], colour[2], colour[3]), "1,0.9,0.5", "a dotted path (" .. dots .. " dots), gold where it's done")
    equal(MG.FX.tweens[1] ~= nil, true, "the glow pulses on a tween")
    local alpha = map.glow.alpha
    Tick(.2)
    equal(map.glow.alpha ~= alpha, true, "its light rising and falling")
    nodes[3]:Click()
    equal(table.concat(picked, ","), "13", "an open node picked")
    nodes[1]:Click()
    nodes[5]:Click()
    equal(table.concat(picked, ",") .. " | " .. M.Shell().note.text, "13,11 | Clear level 13 first.", "a done one too; a locked one says what to clear")
    equal(tostring(map.prev.shown) .. " " .. tostring(map.next.shown), "true true", "both arrows on page 2 (the next page shows, locked)")
    map.next:Click()
    equal(map:Page() .. " " .. tostring(map.shade.shown) .. " " .. map.lockText.text .. " " .. tostring(map.next.shown) .. " " .. tostring(map.glow.shown)
        .. " " .. nodes[1].alpha, "3 true Beat Zalazane to open. false false 0.55", "a locked page: greyed, what opens it, no further")
    map.prev:Click(); map.prev:Click()
    equal(map:Page() .. " " .. tostring(map.prev.shown), "1 false", "page 1: no going back")
    local clean = true
    for _, f in ipairs(M.frames) do
        local under = f
        while under and under ~= frame do under = under.parent end
        if under and f.scripts.OnUpdate then clean = false end
    end
    equal(clean, true, "no update of its own")
    -- The walk: dot by dot, a step sound every second one, then done.
    map:Show(2)
    local before, ended = #M.sounds, nil
    states.last = 14
    map:Walk(13, 14, function(cleared) ended = cleared end)
    local points = #MG.Map.SEGMENTS[3] + 1
    Tick(MG.Map.STEP * points + .2, .02)
    local _, steps = Since(before):gsub("1209:SFX", "")
    equal(tostring(ended) .. " " .. steps, "false " .. math.floor(points / 2), "the walk: a step sound on every second dot, then done")
    equal(map.glow.lastPoint[4] .. "," .. map.glow.lastPoint[5], "330,-352", "the glow on the next level")
    -- Over the page's end: the next page turns, with a banner.
    states.last = 21
    ended = nil
    before = #M.sounds
    map:Walk(20, 21, function(cleared) ended = cleared end)
    Tick(.5, .02)
    equal(tostring(ended) .. " " .. map:Page() .. " " .. MG.FX.banner.text.text .. " " .. tostring(Since(before):find("63971:SFX", 1, true) ~= nil),
        "false 3 New place: Zone 3 true", "a new zone: the page turns, its name and a fanfare")
    -- Hidden part way: it jumps to the end.
    states.last = 23
    map:Show(3)
    ended = nil
    map:Walk(22, 23, function(cleared) ended = cleared end)
    MG:Close("hand")
    equal(ended, true, "closed mid-walk: done at once, cleared")
    -- Its art refused: plain discs.
    Core({missing = {["talents-node-circle-green"] = true, taxi_frame_green = true, [187021] = true, [187017] = true}})
    game = M.TestGame(MG, "blast")
    MG:Open("blast", "command")
    map = MG.Map.New(game.holder, MapSource({last = 2, [1] = {state = "done", stars = 1}}, {}))
    map:Show()
    equal(map.nodes[1].art.texture .. " " .. ("%g,%g,%g"):format(unpack(map.nodes[1].art.vertex)), "Interface\\Masks\\CircleMask 0.85,0.68,0.3",
        "a refused node: a gold disc")
    equal(map.ground.texture, "Interface\\Garrison\\ClassHallBackground", "a refused ground: the stone tiles")
    equal(M.Shell().note.text, "Next: The shop at level 3.", "the map's note: the next milestone")
end

-- 9. Cards -------------------------------------------------------------------------------------------------

Core()
do
    local blast = M.TestGame(MG, "blast")
    M.TestGame(MG, "whack")
    MG:Open("blast", "command")
    local toggled, clicked = {}, {}
    local card = MG.Card.Show({title = "Level 3", sub = "Elwynn Forest", lines = {
            {icon = "relic.1", text = "Bring down 2 relics", progress = "1/2"}, {icon = "star", text = "Score 800", done = true}},
        big = "20 moves", best = "Best 1,240",
        toggles = {{id = "charge", icon = "boost.charge", count = 2}, {id = "sheep", icon = "boost.sheep", count = 0, price = 60}},
        onToggle = function(id) toggled[#toggled + 1] = id; return true, id == "charge" and 1 or 0 end,
        buttons = {{label = "Play", width = 110, primary = true, onClick = function(c) clicked[#clicked + 1] = c and "play" end},
            {label = "Map", width = 70, onClick = function() clicked[#clicked + 1] = "map" end}}})
    equal(card ~= nil and MG.Card.Shown() and card.dim.level == blast.holder.level + 37 and card.dim.mouse, true,
        "a card over the game, its dim layer taking the clicks")
    equal(card.dim.level < M.Shell().fx.level and card.dim.level > M.Shell().edge.level, true, "over the board and the frame's edge, under the effects")
    equal(card.title.text .. " | " .. card.sub.text .. " | " .. card.big.text .. " | " .. card.best.text, "Level 3 | Elwynn Forest | 20 moves | Best 1,240",
        "its words")
    equal(card.lines[1].text.text .. " " .. card.lines[1].progress.text .. " " .. card.lines[1].icon.texture .. " " .. tostring(card.lines[1].check.shown),
        "Bring down 2 relics 1/2 133639 false", "a goal line: icon, words, progress")
    equal(tostring(card.lines[2].check.shown) .. " " .. card.lines[2].check.atlas .. " " .. tostring(card.lines[3].shown), "true common-icon-checkmark false",
        "a goal done: ticked; unused lines hidden")
    equal(card.toggles[1].count.text .. " " .. card.toggles[2].price.text .. " " .. tostring(card.toggles[3].shown), "2 60 false", "boosters: count, or price at 0")
    card.toggles[1]:Click()
    equal(table.concat(toggled, ",") .. " " .. tostring(card.toggles[1].ring.shown) .. " " .. card.toggles[1].count.text, "charge true 1",
        "a booster clicked: the game says it's on, its ring lit")
    card.buttons[1]:Click(); card.buttons[2]:Click()
    equal(table.concat(clicked, ","), "play,map", "buttons fire")
    equal(tostring(card.buttons[1].glow.shown) .. " " .. tostring(card.buttons[2].glow.shown) .. " " .. card.buttons[1].w .. " " .. tostring(card.buttons[3].shown),
        "true false 110 false", "the main one glows; sizes as asked")
    equal(card.h >= 260 and card.w == 300, true, "300 wide, at least 260 tall")
    -- A win: stars fill one by one, coins count up.
    local before = #M.sounds
    MG.Card.Show({title = "Level 3 cleared!", stars = 2, coins = 45, buttons = {{label = "Next", primary = true}}})
    equal(card.starArt[1].atlas .. " " .. card.coins.text, "tradeskills-star-off +0 coins", "stars empty, coins at 0 to start")
    Tick(1.2, .05)
    equal(card.starArt[1].atlas .. " " .. card.starArt[2].atlas .. " " .. card.starArt[3].atlas .. " " .. card.coins.text,
        "tradeskills-star tradeskills-star tradeskills-star-off +45 coins", "two stars filled, the coins counted up")
    equal(Since(before):find("file 4956080:SFX", 1, true) ~= nil and Since(before):find("file 4956082:SFX", 1, true) ~= nil
        and Since(before):find("40345:SFX", 1, true) ~= nil, true, "a rising sound a star, coins")
    equal(card.lines[1].shown or card.big.shown, false, "one card at a time: the last one's lines gone")
    -- Switching games: each keeps its own.
    MG:Open("whack", "switch")
    equal(MG.Card.Shown() or card:IsVisible(), false, "switched: Whack has no card up, Blast's hidden with it")
    MG:Open("blast", "switch")
    equal(card:IsVisible(), true, "back: Blast's card again")
    MG.Card.Hide()
    equal(MG.Card.Shown(), false, "hidden")
    -- How-it-works cards: each once.
    local done = 0
    equal(MG.Card.HowItWorks({"oil", "nothing", "ice"}, function() done = done + 1 end), true, "how-it-works cards to show")
    equal(card.title.text .. " | " .. card.lines[1].text.text .. " " .. tostring(card.icon.shown) .. " " .. card.icon.texture,
        "Oil | Oil sits under pieces. true 4675225", "the oil card, with its picture")
    card.buttons[1]:Click()
    equal(tostring(P:Seen("oil")) .. " " .. card.title.text .. " " .. done, "true Frozen pieces 0", "Got it: seen, the next")
    card.buttons[1]:Click()
    equal(tostring(P:Seen("ice")) .. " " .. tostring(MG.Card.Shown()) .. " " .. done, "true false 1", "then done")
    equal(MG.Card.HowItWorks("oil", function() done = done + 1 end), false, "seen already: none")
    equal(done, 2, "and done at once")
end

-- 10. The shop ----------------------------------------------------------------------------------------------

Core({closeX = true})
do
    M.TestGame(MG, "blast")
    MG:Open("blast", "command")
    local closed = 0
    equal(MG.Shop.Open("blast", function() closed = closed + 1 end), true, "the shop opens")
    local shop = MG.Shop.Frame()
    equal(MG.Shop.Shown() and shop.w .. "x" .. shop.h .. " " .. shop.coins.text .. " " .. shop.tab, "340x420 0 coins power", "340 x 420, your coins, Power-ups")
    local row = shop.rows[1]
    equal(row.name.text .. " | " .. row.about.text .. " " .. row.alpha .. " " .. tostring(row.buy.shown), "Mallet | Opens at level 3 0.45 false",
        "a locked power-up: greyed, the level that opens it")
    equal(shop.rows[7].name.text .. " " .. tostring(shop.rows[8]), "Bloodlust nil", "seven rows, the Horde's Bloodlust")
    P:Unlock("mallet")
    P:AddCoins(50)
    MG.Shop.Tab(shop, "power")
    equal(row.about.text .. " " .. row.owned.text .. " " .. row.buy.label.text .. " " .. row.alpha, "Smash one piece or blocker. x0 40 1", "open: what it does, owned, price")
    local before = #M.sounds
    row.buy:Click()
    equal(P:Coins() .. " " .. row.owned.text .. " " .. shop.coins.text .. " " .. M.Shell().note.text, "10 x1 10 coins Bought Mallet for 40 coins.",
        "bought: coins, the count and the purse repainted")
    equal(Since(before):find("218228:SFX", 1, true) ~= nil and M.Shell().coins.text, "10", "a coin sound; the header's purse too")
    row.buy:Click()
    equal(P:Coins() .. " " .. M.Shell().note.text, "10 Not enough coins. You need 40.", "not enough coins: says so")
    shop.tabs[2]:Click()
    equal(shop.tab .. " " .. shop.rows[1].name.text .. " " .. shop.rows[1].use.label.text .. " | " .. shop.rows[2].about.text .. " | " .. shop.rows[6].buy.label.text,
        "mallet Wooden mallet In use | Opens at Blast level 20 | 250", "Mallets: the one in use, milestones, the one to buy")
    P:AddCoins(300)
    shop.rows[6].buy:Click()
    equal(tostring(P:Unlocked("mallet:gnomish")) .. " " .. shop.rows[6].use.label.text, "true Use", "bought: ready to use")
    shop.rows[6].use:Click()
    equal(P:Mallet() .. " " .. shop.rows[6].use.label.text .. " " .. shop.rows[1].use.label.text, "gnomish In use Use", "in use")
    shop.close:Click()
    equal(tostring(MG.Shop.Shown()) .. " " .. closed, "false 1", "closed: done")
    M.TestGame(MG, "whack")
    MG:Open("whack", "switch")
    MG.Shop.Open()
    equal(MG.Shop.Frame().tab .. " " .. tostring(MG.Shop.Frame() ~= shop), "mallet true", "Whack's own shop opens on Mallets")
end

-- 11 and 12. Sounds and art by role ------------------------------------------------------------------------

Core({refused = {[140556] = true, [4956082] = true}})
do
    local before = #M.sounds
    MG:Sound("pop")
    equal(Since(before), "140556:SFX 7355:SFX", "a refused sound: its stand-in plays")
    before = #M.sounds
    MG:Sound("star", 2)
    equal(Since(before), "file 4956082:SFX 218238:SFX", "a star's file refused: its kit")
    before = #M.sounds
    MG:Sound("bossRoar.elwynn"); MG:Sound("bossRoar.tanaris"); MG:Sound("bossDown.blackrock")
    equal(Since(before), "1015:SFX 3326:SFX 7555:SFX", "each zone's boss sounds; a zone without its own: the plain one")
    before = #M.sounds
    equal(MG:Sound({"squish", "boing"}) and Since(before), "722:SFX 91242:SFX", "a list of names: each plays")
    local bad = {}
    local function Ids(entry, out)
        if type(entry) == "number" then out[#out + 1] = entry
        elseif type(entry) == "table" then
            if type(entry.id) == "number" and (entry.kind == "kit" or entry.kind == "soundfile") then out[#out + 1] = entry.id end
            if type(entry.id) == "table" and (entry.kind == "kit" or entry.kind == "soundfile") then for _, id in ipairs(entry.id) do out[#out + 1] = id end end
            for _, each in ipairs(entry) do Ids(each, out) end
            if entry.kit then Ids(entry.kit, out) end
            if entry.alt and (entry.kind == nil or entry.kind == "kit" or entry.kind == "soundfile") then Ids(entry.alt, out) end
        end
        return out
    end
    for name, entry in pairs(MG.SOUNDS) do
        for _, id in ipairs(Ids(entry, {})) do if MG.FORBIDDEN_SOUNDS[id] then bad[#bad + 1] = name .. ":" .. id end end
    end
    for role, entry in pairs(MG.ASSET) do
        if role:find("^sound%.") or role:find("%.boss%u") then
            for _, id in ipairs(Ids(entry, {})) do if MG.FORBIDDEN_SOUNDS[id] then bad[#bad + 1] = role .. ":" .. id end end
        end
    end
    equal(table.concat(bad, ","), "", "no blacksmith or metal sound in any sound or role")
    for _, name in ipairs({"pop", "squish", "boing", "whoosh", "chime", "coin", "coins", "star", "win", "lose", "unlock", "bossRoar", "bossHit",
        "bossDown", "iceCrack", "oilSplat", "crateBreak", "relicDrop", "shuffle", "powerUse", "buy", "uiClick", "mapStep"}) do
        equal(MG.SOUNDS[name] ~= nil and MG.ASSET["sound." .. name] ~= nil, true, "sound " .. name .. ": its role and its name")
    end
end
Core({missing = {[2510379] = true}})
do
    local t = M.Shell
    local texture = UIParent:CreateTexture(nil, "ARTWORK")
    equal(MG:Art(texture, "block.oil") .. " " .. texture.texture .. " " .. ("%g,%g,%g"):format(unpack(texture.vertex)) .. " " .. texture.alpha,
        "file 4675225 0.1,0.08,0.06 0.9", "a role's file, tint and alpha")
    equal(MG:Art(texture, "block.ice") .. " " .. texture.atlas, "atlas perks-frozen-icon", "its file refused: its stand-in")
    Core({missing = {[2510379] = true, ["perks-frozen-icon"] = true, [135841] = true}})
    texture = UIParent:CreateTexture(nil, "ARTWORK")
    equal(MG:Art(texture, "block.ice") .. " " .. table.concat(texture.colour, ","), "colour 0.55,0.8,1,0.4", "all refused: the fallback's colour")
    equal(tostring(MG:Art(texture, "no.such.role")) .. " " .. tostring(texture.shown), "nil false", "an unknown role: nothing drawn, hidden")
    equal(MG:Art(texture, "no.such.role", {colour = {1, 0, 0, 1}}) .. " " .. tostring(texture.shown), "colour true", "unless a last colour is given")
    local broken = UIParent:CreateTexture(nil, "ARTWORK")
    broken.SetTexture = function() error("refused") end
    equal(MG:Art(broken, "power.mallet"), nil, "a texture that errors: no error, nothing drawn")
    equal(MG:Art(broken, "card"), "atlas", "an atlas still draws on it")
    texture = UIParent:CreateTexture(nil, "ARTWORK")
    MG:Art(texture, "zone.westfall.ground", {wrap = "REPEAT", coords = {0, 2, 0, 3}})
    equal(texture.texture .. " " .. texture.wrapH .. " " .. table.concat(texture.coords, ","), "188991 REPEAT 0,2,0,3", "tiled with its own coords")
    MG:Art(texture, "zone.tanaris.ground")
    equal(texture.texture, "Interface\\Garrison\\ClassHallBackground", "a zone with no art: the stone tiles")
    MG.ZONE_ALIAS.tanaris = "westfall"
    MG:Art(texture, "zone.tanaris.ground")
    equal(texture.texture, 188991, "a zone key aliased to the art's")
    MG.ZONE_ALIAS.tanaris = nil
    MG:Art(texture, "boost.lust")
    local horde = texture.texture
    M.world.faction = "Alliance"
    MG:Art(texture, "boost.lust")
    equal(horde .. " " .. texture.texture, "136012 132313", "Bloodlust for the Horde, Heroism for the Alliance")
    equal(MG:ArtValue("coin") .. " " .. MG:ArtValue("power.mallet") .. " " .. MG:ArtValue("zone.elwynn.boss") .. " " .. tostring(MG:ArtValue("nothing")),
        "133784 133052 134163 nil", "a value a button can take: never an atlas")
    equal(("%g,%g,%g"):format(MG:Colour3("zone.durotar.tint")) .. " " .. MG:Words("zone.elwynn.bossName") .. " " .. MG:Words("zone.tanaris.bossName", "Gahz'rilla"),
        "0.78,0.4,0.22 Hogger Gahz'rilla", "colours and names by role")
    -- Every role the design names has its art or a fallback.
    local missingRoles = {}
    local roles = {"block.oil", "block.oil2", "block.ice", "block.iceCrack", "block.crate", "block.crateCrack", "block.web", "block.skull",
        "relic.1", "relic.2", "relic.3", "exit", "hole", "power.mallet", "power.shuffle", "power.swap", "power.moves", "boost.charge",
        "boost.sheep", "boost.lust", "coin", "coinBig", "star", "starEmpty", "lock", "check", "map.node", "map.nodeDone", "map.nodeBoss",
        "map.nodeLocked", "map.path", "map.glow", "map.banner", "card", "whack.golden", "whack.decoyAlliance", "whack.decoyHorde",
        "whack.bossPeon", "whack.bossGnome"}
    for n = 1, 6 do roles[#roles + 1] = "mallet." .. n end
    for _, race in ipairs({"orc", "tauren", "undead", "human", "dwarf", "nightelf"}) do roles[#roles + 1] = "plate." .. race end
    for index = 1, 10 do
        for _, part in ipairs({"ground", "icon", "boss", "bossIcon", "frame", "tint"}) do roles[#roles + 1] = "zone." .. P.ZONE_KEYS[index] .. "." .. part end
    end
    for _, role in ipairs(roles) do
        if not (MG:Asset(role) or MG:Fallback(role)) then missingRoles[#missingRoles + 1] = role end
    end
    equal(table.concat(missingRoles, ","), "", "every role has its art or a fallback")
    -- Plate colours far apart.
    local closest = math.huge
    local races = {"orc", "tauren", "undead", "human", "dwarf", "nightelf"}
    for i = 1, 6 do
        for j = i + 1, 6 do
            local a, b = {MG:Colour3("piece." .. races[i] .. ".colour")}, {MG:Colour3("piece." .. races[j] .. ".colour")}
            closest = math.min(closest, math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2))
        end
    end
    equal(closest >= .4, true, "each race's plate colour at least .4 from every other (" .. ("%.2f"):format(closest) .. ")")
    equal(MG:Asset("plate.orc").tint[1] .. " " .. MG:Asset("plate.nightelf").tint[1], "0.3 0.96", "plates tinted their race's colour")
end
-- Models and their framing.
Core({models = true, badModels = {[4259] = true}, db = {miniGameTune = {bossPeon = {zoom = .9, bad = 0 / 0, nope = {}}}}})
do
    local model = CreateFrame("PlayerModel", nil, UIParent)
    MG:TuneDefaults("bossPeon", {zoom = .8, cam = 1.1, up = .2, turn = 10, insets = {0, 0, 0, 25}})
    local ok, id = MG:Model(model, "whack.bossPeon", "bossPeon", .5)
    equal(tostring(ok) .. " " .. id .. " " .. model.display, "true 4602 4602", "its first model refused: the next")
    equal(model.zoom .. " " .. model.camera .. " " .. model.position[3] .. " " .. ("%.4f"):format(model.rotation) .. " " .. model.insets[4],
        "0.9 1.1 0.2 " .. ("%.4f"):format(.5 + math.rad(10)) .. " 25", "framed: saved zoom over the defaults, the turn added to the column's")
    local tune = MG:Tune("bossPeon")
    equal(tostring(tune.bad) .. " " .. tostring(tune.nope) .. " " .. tune.zoom, "nil nil 0.9", "only good saved values")
    MG:SetTune("bossPeon", "up", -.4)
    MG:SetTune("peon", "cursor", false)
    equal(EraUIDB.miniGameTune.bossPeon.up .. " " .. tostring(MG:Tune("peon").cursor) .. " " .. MG:Tune("bossPeon").up, "-0.4 false -0.4", "tune values saved")
    MG:ClearTune("bossPeon")
    equal(MG:Tune("bossPeon").zoom .. " " .. tostring(MG:Tune("peon").cursor), "0.8 false", "one key cleared")
    MG:ClearTune()
    equal(tostring(MG:Tune("peon").cursor), "nil", "all cleared")
    local plain = CreateFrame("Frame", nil, UIParent)
    equal(MG:Model(plain, "whack.bossPeon"), false, "no model frame: no model")
end

-- 13 and 14. The window, the purse, Shown's why and logging out ------------------------------------------

Core({closeX = true})
do
    local whack, blast = M.TestGame(MG, "whack"), M.TestGame(MG, "blast")
    local function Listening(event) return MG.events.events[event] == true end
    equal(Listening("PLAYER_LOGOUT"), false, "logging out isn't heard before a game was opened")
    M.Fire("PLAYER_LOGOUT")
    equal(#whack.calls, 0, "nothing kept then")
    MG:Open("whack", "command")
    local shell = M.Shell()
    equal(shell.w .. "x" .. shell.h .. " " .. shell.content.w .. "x" .. shell.content.h .. " " .. tostring(MG.HEIGHT <= 700), "440x650 412x500 true",
        "the window 440 x 650 (fits a 768-high screen), the play area 412 x 500")
    equal(whack.holder.w .. "x" .. whack.holder.h .. " " .. whack.bar.w .. "x" .. whack.bar.h, "412x500 256x32", "the game's holder and footer strip")
    equal(Listening("PLAYER_LOGOUT"), true, "heard once the window exists")
    equal(whack.calls[#whack.calls] .. " " .. MG.openWhy, "Shown command command", "Shown is told why it opened")
    equal(tostring(shell.coins.shown) .. " " .. shell.coins.text .. " " .. tostring(shell.coin.atlas), "true 0 coin-icon", "the coin purse in the header")
    P:AddCoins(35)
    equal(shell.coins.text, "35", "coins added: the purse repainted")
    equal(shell.best.lastPoint[2] == shell.coin and shell.best.lastPoint[4], -10, "the Best line left of the purse")
    function whack:HeaderBest() return "Stage 3 best 18" end
    MG:PaintHeader()
    equal(shell.best.text .. " " .. shell.where.w, "Stage 3 best 18 " .. (MG.WIDTH - 62 - 46 - 10 - 6 * 15 - (6 * 2 + 3 + 14 + 10)),
        "a game's own best line, the where line in the room left")
    MG:Switch()
    equal(blast.calls[#blast.calls] .. " | " .. whack.calls[#whack.calls], "Shown switch | Pause switch", "a switch: the other shown, the first paused")
    M.Fire("PLAYER_LOGOUT")
    local kept = 0
    for _, call in ipairs(whack.calls) do if call == "Keep" then kept = kept + 1 end end
    equal(kept .. " " .. tostring(Has(blast.calls, "Keep")), "1 true", "logging out: every built game keeps what it has running")
    MG:Close("hand")
    MG.flight.on = true
    MG:Open("whack", "flight")
    equal(whack.calls[#whack.calls], "Shown flight", "a flight says so")
    MG.flight.on = false
end
Core({noInit = true})
equal(M.Shell(), nil, "nothing made before it starts")

-- 15. /era whack <words> ---------------------------------------------------------------------------------

Core({commands = true, closeX = true})
do
    local whack = M.TestGame(MG, "whack")
    SlashCmdList.ERAUI("whack tune zoom .9")
    equal(whack.calls[#whack.calls], "Command tune zoom .9", "/era whack tune zoom .9 reaches Whack's own command")
    equal(M.Showing(), false, "and opens nothing")
    SlashCmdList.ERAUI("whack")
    equal(M.Showing() and MG.current, "whack", "/era whack alone still opens it")
    SlashCmdList.ERAUI("whack nonsense")
    equal(M.printed[#M.printed], "Unknown mini-game command: nonsense", "words it doesn't know: said so")
    SlashCmdList.ERAUI("blast tune")
    equal(M.printed[#M.printed], "Unknown mini-game command: tune", "a game without commands: the same")
    function whack:Command() error("boom") end
    SlashCmdList.ERAUI("whack tune")
    equal(M.printed[#M.printed]:find("A mini-game hit an error", 1, true) ~= nil, true, "a command's error is said once")
end
Core({commands = true, noInit = true})
SlashCmdList.ERAUI("whack tune zoom 1")
equal(M.printed[#M.printed], "Mini-games are not available.", "not started: not available")

print("Mini-game progress checks passed: " .. M.checks .. " assertions.")
