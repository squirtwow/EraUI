local _, EraUI = ...

-- The mini-games' saved progress (experimental, with the mini-games): levels,
-- stars, best scores, coins, power-ups, unlocks and the how-it-works cards
-- seen, shared by every character on the account, so each flight carries on
-- where the last one left off. No frames, no events: plain functions the
-- games call (Tools/TestMiniGameProgress.lua plays them on a mock).
--
-- CORE CONTRACT (for the Blast and Whack builders). local P = MiniGames.Progress
--
-- Saved (EraUIDB, through EraUI:GetSetting/SetSetting):
--   miniGameProgress  the record below (backed up by Core/Persistence.lua; the
--                     newer stamp wins a restore). Never read it directly: P:Data().
--   miniGameResume    {version = 1, blast = snapshot, whack = snapshot}: the level
--                     or stage in progress, as each game saves it (not backed up)
--   miniGameBest, miniGamePosition, miniGameTune and every character's bests and
--   Free play board (EraUIClassicCharDB.miniGames) are never touched here.
-- The record (version 1):
--   {version, stamp, coins, earned, powers = {mallet, shuffle, swap, moves, charge,
--    sheep, lust}, unlocked = {[id] = true}, cards = {[id] = true}, gifts = {["blast:3"] = true},
--    blast = {level, stars = "3210", best = {[n] = score}, last = "level"|"free", look, tries, wins},
--    whack = {stage, stars, best, last = "stage"|"quick", mallet, tries, wins}}
--   stars: one character per level from level 1, "0" not cleared, "1" to "3".
--
-- Reading:
--   P:Data() -> the record, migrated and sanitised (never nil; the only reader)
--   P:Coins() -> n;  P:Count(power) -> n;  P:Unlocked(id) -> bool;  P:Seen(card) -> bool
--   P:Level(game) -> the highest open level ("blast") or stage ("whack"), 1 or more
--   P:Stars(game, n) -> 0..3;  P:TotalStars(game, fromN, toN) -> n;  P:BestScore(game, n) -> n
--   P:Last(game) -> "level"|"free" or "stage"|"quick": what a flight reopens with no snapshot
--   P:Look() -> Free play's board look ("stone" or an unlocked zone key); P:Looks() -> {"stone", ...}
--   P:Mallet() -> Whack's mallet skin id ("wood" ...)
--   P:Price(item, step) -> coins (step: the price ladder's place, 0 first: 60, 90, 120, 120 for +5 moves)
--   P:NextUnlock(game) -> {at = n, id, name} or nil: the next milestone ("Next: %s at level %d.")
--   P:Name(id) -> the player's name of a power, unlock id or card ("Mallet", "Durotar", "Frost mallet")
--   P:Card(id) -> {id, title, lines = {...}, icon = role}: a how-it-works card, worded for your faction
--   P:ZoneKey(index) -> zone key (MiniGames.Blast.ZONES when loaded, else P.ZONE_KEYS)
--   P:Resume(game) -> the snapshot saved for that game, or nil
-- Changing (each bumps stamp; the ones marked * also call EraUI:SaveSettings):
--   P:AddCoins(n, why) -> total;  P:Spend(n) -> ok
--   P:Give(power, n) -> count;  P:Use(power) -> ok *
--   P:Buy(item, step) -> ok, why, price *  (item: a power, "time" for Whack's +10
--       seconds, or a mallet skin "mallet:gnomish"; why: "locked", "coins", "owned", "unknown")
--   P:BuyAndUse(item, step) -> ok, why, price *  (an owned power is used first, for no coins)
--   P:Unlock(id) -> newly *;  P:See(card);  P:Owed(ids) -> the cards of what's open, not seen yet
--   P:SetLast(game, what);  P:SetLook(key) -> ok;  P:SetMallet(id) -> ok
--   P:Finish(game, n, result) -> report *  ONCE PER ATTEMPT: on a win, or when a lost
--       attempt is left (Try again, Map, another level). A +5 moves continue is the
--       same attempt. result = {won, stars (1..3 on a win), score, movesLeft, epics,
--       golden, boss}. report = {coins, first, newStars, stars, best, newBest,
--       opened (the level it opened, or nil), unlocks = {ids}, gifts = {{id, count}},
--       cards = {ids not seen yet, in order: show each with MiniGames.Card.HowItWorks}}.
--       P:Finish("whack", "quick", {score, golden}) pays a Quick round (1 coin per 5
--       points, 5 a golden head).
--   P:FreeCoins(kept, score) -> coins paid: Free play's 1 coin per 1,000 points, as you
--       pass each (kept: the board's CharData table, which keeps "coined")
--   P:SaveResume(game, snapshot or nil): after every move, on every game:Pause(why),
--       on game:Keep() and when a level starts; nil when it ends
--   P:Reset() -> true: both games from the start (coins, power-ups, unlocks and
--       snapshots go; bests, boards, place and tune stay), then game:ProgressReset()
--   P:Changed(save): stamp + 1, the header's coins repainted, saved when asked
-- Tables: P.POWERS (ids in bar order), P.PRICES, P.STARTER, P.COINS (the earning
-- rates), P.SCHEDULE (milestones), P.UNLOCK_AT (power -> Blast level), P.CARDS,
-- P.SKINS (Whack's mallets: id, name, icon role, opens or price), P.ZONE_KEYS, P.ZONE_NAMES.
--
-- The other CORE helpers (each documents itself at its top):
--   Modules/MiniGameAssets.lua  MiniGames:Art(texture, role, opts), :ArtValue(role),
--       :Model(model, role, tuneKey), :FrameModel, :Tune(key), :SetTune, :ClearTune,
--       :TuneDefaults, :Colour3(role), :Words(role), MiniGames.ASSET / FALLBACK / ZONE_ALIAS
--   Modules/MiniGameMap.lua  MiniGames.Map.New(parent, source) -> map:Show(page),
--       :Hide(), :Refresh(), :IsShown(), :Page(), :Walk(from, to, done), :Note()
--   Modules/MiniGameCards.lua  MiniGames.Card.Show(spec), .Hide(), .Shown(), .HowItWorks(ids, done)
--   Modules/MiniGameShop.lua  MiniGames.Shop.Open(game, done), .Close(), .Shown(), .ITEMS
local MG = EraUI.MiniGames
if not MG then return end

local P = {}
MG.Progress = P
P.VERSION = 1
P.MAX_COINS, P.MAX_POWER, P.MAX_LEVEL, P.MAX_COUNT = 999999, 99, 1000000, 4503599627370496
P.POWERS = {"mallet", "shuffle", "swap", "moves", "charge", "sheep", "lust"}
P.BOOSTERS = {charge = true, sheep = true, lust = true}
P.PRICES = {mallet = 40, shuffle = 30, moves = 60, swap = 50, charge = 50, sheep = 60, lust = 70,
    time = 40, ["mallet:gnomish"] = 250}
P.SERVICES = {time = true}   -- bought and used at once, never kept (Whack's +10 seconds)
P.LADDER = {1, 1.5, 2}       -- the price of the 1st, 2nd, 3rd and later extra in one attempt
P.STARTER = {mallet = 3, shuffle = 2, moves = 2, swap = 2, charge = 2, sheep = 2, lust = 2}
-- Coins: a first clear, a replay win, each star (on a first clear; above the old
-- best on a replay), a boss, moves left (1 per movesPer), each epic piece or
-- golden head (win or lose), a loss (a little, so nobody stays stuck), Quick
-- round (1 per quickPer points), Free play (1 per freePer points) and the welcome.
P.COINS = {
    blast = {first = 20, replay = 5, star = 10, boss = 50, movesPer = 2, epic = 1, loss = 2},
    whack = {first = 15, replay = 3, star = 5, boss = 40, golden = 5, loss = 2, quickPer = 5},
    freePer = 1000, welcome = 50,
}
-- Milestones, given on a level's (or stage's) first clear. After Blast level
-- 40 they're made: every 10th level opens the next zone and this zone's board
-- look, every other 5th gives one power-up in turn (P.POWERS order).
P.SCHEDULE = {
    blast = {
        [1] = {cards = {"stars"}},
        [3] = {unlock = {"shop", "mallet"}, give = {mallet = 3}},
        [5] = {unlock = {"shuffle"}, give = {shuffle = 2}},
        [8] = {unlock = {"moves"}, give = {moves = 2}},
        [10] = {unlock = {"zone:durotar", "look:elwynn"}},
        [12] = {unlock = {"swap"}, give = {swap = 2}},
        [14] = {unlock = {"charge"}, give = {charge = 2}},
        [18] = {unlock = {"sheep"}, give = {sheep = 2}},
        [20] = {unlock = {"zone:westfall", "look:durotar", "mallet:bone"}},
        [25] = {unlock = {"lust"}, give = {lust = 2}},
        [30] = {unlock = {"zone:barrens", "look:westfall"}},
        [35] = {give = {charge = 2, sheep = 2}},   -- a gift halfway through the relic levels
        [40] = {unlock = {"zone:duskwood", "look:barrens", "mallet:fel"}},
    },
    whack = {
        [2] = {unlock = {"shop"}},
        [10] = {unlock = {"mallet:frost"}},
        [20] = {unlock = {"mallet:golden"}},
    },
}
P.MADE_FROM = 40   -- Blast milestones past this level are made, not listed
P.GIFT_EVERY = 5
P.UNLOCK_AT = {}
for level, entry in pairs(P.SCHEDULE.blast) do
    for _, id in ipairs(entry.unlock or {}) do P.UNLOCK_AT[id] = level end
end
-- The shared path's zones, ten levels each (the 10th a boss). MiniGames.Blast.ZONES
-- wins once Azeroth Blast's levels are loaded; this list is the same order.
P.ZONE_KEYS = {"elwynn", "durotar", "westfall", "barrens", "duskwood", "stranglethorn", "tanaris", "blackrock",
    "plaguelands", "silithus"}
P.ZONE_NAMES = {elwynn = "Elwynn Forest", durotar = "Durotar", westfall = "Westfall", barrens = "The Barrens",
    duskwood = "Duskwood", stranglethorn = "Stranglethorn Vale", tanaris = "Tanaris", blackrock = "Blackrock Mountain",
    plaguelands = "Eastern Plaguelands", silithus = "Silithus", redridge = "Redridge Mountains", mulgore = "Mulgore",
    silverpine = "Silverpine Forest", stone = "Stone"}
-- Whack's mallets (Whack.SKINS gives their colours; ids and names match).
P.SKINS = {
    {id = "wood", name = "Wooden mallet", icon = "mallet.1"},
    {id = "bone", name = "Bone mallet", icon = "mallet.2", opens = "Blast level 20"},
    {id = "frost", name = "Frost mallet", icon = "mallet.3", opens = "Whack stage 10"},
    {id = "golden", name = "Golden mallet", icon = "mallet.4", opens = "Whack stage 20"},
    {id = "fel", name = "Felfire mallet", icon = "mallet.5", opens = "Blast level 40"},
    {id = "gnomish", name = "Gnomish mallet", icon = "mallet.6", price = 250},
}
P.NAMES = {mallet = "Mallet", shuffle = "Shuffle", swap = "Free swap", moves = "+5 moves", charge = "Start with a Charge",
    sheep = "Start with a Sheep", shop = "The shop", time = "+10 seconds"}
-- How-it-works cards, each shown once. %s: the faction's word (lust: Bloodlust or
-- Heroism; golden and bossPeon: peon or gnome).
P.CARDS = {
    goals = {title = "Level goals", icon = "star", lines = {"Each level has a goal and a set number of moves.",
        "Meet the goal before your moves run out.", "Moves left at the end add to your score."}},
    stars = {title = "Stars", icon = "star", lines = {"Win to earn 1 star. Win with moves to spare for 2 or 3.",
        "Stars earn coins and open new places."}},
    holes = {title = "Gaps", icon = "hole", lines = {"Some boards have gaps.", "Pieces fall straight past them."}},
    oil = {title = "Oil", icon = "block.oil", lines = {"Oil sits under pieces.", "Clear a piece on it to clean it. Dark oil takes two."}},
    ice = {title = "Frozen pieces", icon = "block.ice", lines = {"Frozen pieces can't be moved.",
        "Match them, or next to them, to crack the ice. Thick ice takes two."}},
    crate = {title = "Crates", icon = "block.crate", lines = {"Crates fall like pieces but can't be moved or matched.",
        "Match next to one to break it. Some take 2 or 3 hits."}},
    relic = {title = "Relics", icon = "relic.1", lines = {"Bring relics down to the arrows at the bottom.",
        "Clear the pieces under them so they fall."}},
    web = {title = "Webs", icon = "block.web", lines = {"Webbed pieces can't be moved.", "Match a webbed piece to break the web."}},
    skull = {title = "Skulls", icon = "block.skull", lines = {"Skulls fall like pieces.", "Match next to them to break them."}},
    boss = {title = "Boss fights", icon = "zone.elwynn.boss", lines = {"Your matches hit the boss. The other side's pieces hit harder.",
        "Every few moves he strikes back. While his mess is on the board, he takes half damage."}},
    mallet = {title = "Mallet", icon = "power.mallet", lines = {"Smash any one piece or blocker.", "It costs no move."}},
    shuffle = {title = "Shuffle", icon = "power.shuffle", lines = {"Mix up the pieces when you're stuck.", "It costs no move."}},
    moves = {title = "+5 moves", icon = "power.moves", lines = {"Five more moves for this level."}},
    swap = {title = "Free swap", icon = "power.swap", lines = {"Swap any two pieces side by side, match or not.", "It costs no move."}},
    charge = {title = "Start with a Charge", icon = "boost.charge", lines = {"Pick it before a level to start with a Charge on the board."}},
    sheep = {title = "Start with a Sheep", icon = "boost.sheep", lines = {"Pick it before a level to start with an Explosive Sheep."}},
    lust = {title = "Start with %s", icon = "boost.lust", lines = {"Start a level with double points for 3 moves."}},
    shop = {title = "The shop", icon = "coin", lines = {"Spend coins on power-ups and mallets.", "Coins come from levels, stars and bosses."}},
    golden = {title = "Golden %s", icon = "whack.golden", lines = {"Bonk it for 3 points and 5 coins.", "It's quick!"}},
    decoy = {title = "Don't hit your own", icon = "whack.decoy", lines = {"Your side's workers pop up too.", "Hitting one costs 3 points."}},
    bossPeon = {title = "Boss %s", icon = "whack.boss", lines = {"Bonk him 3 times in a row to beat him.",
        "After each bonk he jumps to another hole."}},
    double = {title = "Two at once", icon = "whack.golden", lines = {"Sometimes two heads pop up together."}},
}

local STAMP_CAP = P.MAX_COUNT
local LAST = {blast = {level = true, free = true}, whack = {stage = true, quick = true}}

local function Finite(value)
    return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end
-- A whole number from low up (floored, at most high), else the default.
local function Whole(value, low, high, default)
    if not Finite(value) then return default end
    value = math.floor(value)
    if value < low then return default end
    if high and value > high then return high end
    return value
end
P.Whole = Whole
local KNOWN = {}
for _, power in ipairs(P.POWERS) do KNOWN[power] = true end

local function Book(kind)
    if kind == "whack" then return {stage = 1, stars = "", best = {}, last = "stage", mallet = "wood", tries = 0, wins = 0} end
    return {level = 1, stars = "", best = {}, last = "level", look = "stone", tries = 0, wins = 0}
end
local function Default()
    local powers = {}
    for _, power in ipairs(P.POWERS) do powers[power] = 0 end
    return {version = P.VERSION, stamp = 0, coins = 0, earned = 0, powers = powers, unlocked = {}, cards = {}, gifts = {},
        blast = Book("blast"), whack = Book("whack")}
end
P.Default = Default

-- Sanitising: each known field fixed on its own, unknown keys left as they are.
local function CleanSet(value)
    if type(value) ~= "table" then return {} end
    for key, on in pairs(value) do
        if type(key) ~= "string" or on ~= true then value[key] = nil end
    end
    return value
end
local function CleanBest(value)
    if type(value) ~= "table" then return {} end
    for key, score in pairs(value) do
        if type(key) == "number" then
            local good = key >= 1 and key == math.floor(key) and Whole(score, 0, STAMP_CAP, nil)
            value[key] = good or nil
        end
    end
    return value
end
local function CleanBook(book, kind)
    if type(book) ~= "table" then return Book(kind) end
    local level = kind == "whack" and "stage" or "level"
    book[level] = Whole(book[level], 1, P.MAX_LEVEL, 1)
    if type(book.stars) ~= "string" or not book.stars:match("^[0-3]*$") then book.stars = "" end
    book.best = CleanBest(book.best)
    if not (type(book.last) == "string" and LAST[kind][book.last]) then book.last = kind == "whack" and "stage" or "level" end
    if kind == "whack" then
        if type(book.mallet) ~= "string" or book.mallet == "" then book.mallet = "wood" end
    elseif type(book.look) ~= "string" or book.look == "" then
        book.look = "stone"
    end
    book.tries = Whole(book.tries, 0, STAMP_CAP, 0)
    book.wins = Whole(book.wins, 0, STAMP_CAP, 0)
    return book
end
local function Clean(record)
    if not Finite(record.version) or record.version < 1 then record.version = P.VERSION end
    record.version = math.floor(record.version)
    record.stamp = Whole(record.stamp, 0, STAMP_CAP, 0)
    record.coins = Whole(record.coins, 0, P.MAX_COINS, 0)
    record.earned = Whole(record.earned, 0, STAMP_CAP, 0)
    if type(record.powers) ~= "table" then record.powers = {} end
    for _, power in ipairs(P.POWERS) do record.powers[power] = Whole(record.powers[power], 0, P.MAX_POWER, 0) end
    record.unlocked = CleanSet(record.unlocked)
    record.cards = CleanSet(record.cards)
    record.gifts = CleanSet(record.gifts)
    record.blast = CleanBook(record.blast, "blast")
    record.whack = CleanBook(record.whack, "whack")
    return record
end
P.Clean = Clean

-- Whether this account played the first games (a best score of either).
local function PlayedBefore()
    for _, id in ipairs({"blast", "whack"}) do
        local _, account = MG:Best(id)
        if (tonumber(account) or 0) > 0 then return true end
    end
    return false
end

function P:Data()
    local record = EraUI:GetSetting("miniGameProgress")
    if record ~= nil and record == self.checked then return record end
    if type(record) ~= "table" or record.version == nil then
        record = Default()
        if PlayedBefore() then
            record.coins, record.earned = P.COINS.welcome, P.COINS.welcome
            record.gifts.welcome = true
        end
        EraUI:SetSetting("miniGameProgress", record)
    else
        Clean(record)
    end
    self.checked = record
    return record
end

function P:Changed(save)
    local data = self:Data()
    data.stamp = math.min(STAMP_CAP, data.stamp + 1)
    if MG.window and MG.PaintCoins then MG:PaintCoins() end
    if save and EraUI.SaveSettings then EraUI:SaveSettings() end
end

-- Coins -----------------------------------------------------------------------------------

function P:Coins() return self:Data().coins end
function P:AddCoins(n, why)
    local data = self:Data()
    n = Whole(n, 0, nil, 0)
    if n <= 0 then return data.coins end
    data.coins = math.min(P.MAX_COINS, data.coins + n)
    data.earned = math.min(STAMP_CAP, data.earned + n)
    self.lastWhy = why
    self:Changed()
    return data.coins
end
function P:Spend(n)
    local data = self:Data()
    n = Whole(n, 0, nil, nil)
    if not n or data.coins < n then return false end
    data.coins = data.coins - n
    self:Changed()
    return true
end

-- Power-ups --------------------------------------------------------------------------------

function P:Count(power)
    if not KNOWN[power] then return 0 end
    return self:Data().powers[power]
end
function P:Give(power, n)
    if not KNOWN[power] then return 0 end
    local powers = self:Data().powers
    powers[power] = math.min(P.MAX_POWER, powers[power] + Whole(n, 0, nil, 0))
    self:Changed()
    return powers[power]
end
function P:Use(power)
    if not KNOWN[power] then return false end
    local powers = self:Data().powers
    if powers[power] < 1 then return false end
    powers[power] = powers[power] - 1
    self:Changed(true)
    return true
end
function P:Price(item, step)
    local base = P.PRICES[item]
    if not base then return nil end
    local ladder = P.LADDER
    local k = ladder[Whole(step, 0, nil, 0) + 1] or ladder[#ladder]
    return math.floor(base * k / 5 + .5) * 5
end
function P:Buy(item, step)
    if type(item) ~= "string" then return false, "unknown" end
    local skin = item:match("^mallet:(%w+)$")
    if not (KNOWN[item] or P.SERVICES[item] or skin) then return false, "unknown" end
    local price = self:Price(item, step)
    if not price then return false, "locked" end
    if skin and self:Unlocked(item) then return false, "owned", price end
    if KNOWN[item] and not self:Unlocked(item) then return false, "locked", price end
    if not self:Spend(price) then return false, "coins", price end
    if skin then
        self:Data().unlocked[item] = true
    elseif KNOWN[item] then
        local powers = self:Data().powers
        powers[item] = math.min(P.MAX_POWER, powers[item] + 1)
    end
    self:Changed(true)
    return true, nil, price
end
function P:BuyAndUse(item, step)
    if KNOWN[item] and self:Count(item) > 0 then return self:Use(item), nil, 0 end
    local ok, why, price = self:Buy(item, step)
    if not ok then return false, why, price end
    if KNOWN[item] then self:Use(item) end
    return true, nil, price
end

-- Unlocks and cards -------------------------------------------------------------------------

function P:ZoneKey(index)
    local zones = MG.Blast and MG.Blast.ZONES
    local zone = type(zones) == "table" and zones[index]
    if type(zone) == "table" then
        local key = zone.key or zone[1]
        if type(key) == "string" then return key end
    end
    return P.ZONE_KEYS[index]
end
local function ZoneName(key)
    local zones = MG.Blast and MG.Blast.ZONES
    if type(zones) == "table" then
        for _, zone in ipairs(zones) do
            if type(zone) == "table" and (zone.key or zone[1]) == key and type(zone.name or zone[2]) == "string" then
                return zone.name or zone[2]
            end
        end
    end
    return P.ZONE_NAMES[key] or tostring(key)
end
function P:Unlocked(id)
    if type(id) ~= "string" then return false end
    if id == "mallet:wood" or id == "look:stone" or id == "zone:" .. tostring(self:ZoneKey(1)) then return true end
    return self:Data().unlocked[id] == true
end
function P:Unlock(id)
    if type(id) ~= "string" or self:Unlocked(id) then return false end
    self:Data().unlocked[id] = true
    self:Changed(true)
    return true
end
function P:Seen(card) return self:Data().cards[card] == true end
function P:See(card)
    if type(card) ~= "string" or self:Seen(card) then return end
    self:Data().cards[card] = true
    self:Changed()
end
-- The how-it-works cards still owed: each of ids (default P.OWED: the shop and
-- the power-ups) open but its card not seen (the window closed before "Got
-- it"), so a level's intro shows them first.
P.OWED = {"shop", "mallet", "shuffle", "moves", "swap", "charge", "sheep", "lust"}
function P:Owed(ids)
    local out = {}
    for _, id in ipairs(type(ids) == "table" and ids or P.OWED) do
        if P.CARDS[id] and self:Unlocked(id) and not self:Seen(id) then out[#out + 1] = id end
    end
    return out
end
local function Lust() return MG.Faction() == "Alliance" and "Heroism" or "Bloodlust" end
local function Worker() return MG.Faction() == "Alliance" and "peon" or "gnome" end
function P:Name(id)
    if id == "lust" then return "Start with " .. Lust() end
    if P.NAMES[id] then return P.NAMES[id] end
    if type(id) ~= "string" then return tostring(id) end
    local kind, key = id:match("^(%a+):(%w+)$")
    if kind == "zone" then return ZoneName(key) end
    if kind == "look" then return ZoneName(key) .. " board" end
    if kind == "mallet" then
        for _, skin in ipairs(P.SKINS) do if skin.id == key then return skin.name end end
    end
    return id
end
function P:Card(id)
    local card = P.CARDS[id]
    if not card then return nil end
    local word = id == "lust" and Lust() or Worker()
    local icon = card.icon
    local alliance = MG.Faction() == "Alliance"
    if icon == "whack.decoy" then icon = alliance and "whack.decoyAlliance" or "whack.decoyHorde"
    elseif icon == "whack.boss" then icon = alliance and "whack.bossPeon" or "whack.bossGnome" end
    local lines = {}
    for index, line in ipairs(card.lines) do lines[index] = line end
    return {id = id, title = card.title:find("%s", 1, true) and card.title:format(word) or card.title, lines = lines, icon = icon}
end

-- Levels, stars and bests ---------------------------------------------------------------------

local function Track(game)
    local data = P:Data()
    return game == "whack" and data.whack or data.blast
end
function P:Level(game)
    local book = Track(game)
    return game == "whack" and book.stage or book.level
end
function P:Stars(game, n)
    n = Whole(n, 1, nil, nil)
    if not n then return 0 end
    return tonumber(Track(game).stars:sub(n, n)) or 0
end
local function SetStars(book, n, stars)
    local text = book.stars
    if #text < n then text = text .. string.rep("0", n - #text) end
    book.stars = text:sub(1, n - 1) .. tostring(stars) .. text:sub(n + 1)
end
function P:TotalStars(game, fromN, toN)
    local text = Track(game).stars
    fromN = Whole(fromN, 1, nil, 1)
    toN = Whole(toN, 1, nil, #text)
    local total = 0
    for n = fromN, math.min(toN, #text) do total = total + (tonumber(text:sub(n, n)) or 0) end
    return total
end
function P:BestScore(game, n) return Track(game).best[n] or 0 end
function P:Last(game) return Track(game).last end
function P:SetLast(game, what)
    if not (LAST[game] and LAST[game][what]) then return false end
    local book = Track(game)
    if book.last ~= what then
        book.last = what
        self:Changed()
    end
    return true
end
function P:Looks()
    local looks = {"stone"}
    for index = 1, #P.ZONE_KEYS do
        local key = self:ZoneKey(index)
        if key and self:Unlocked("look:" .. key) then looks[#looks + 1] = key end
    end
    return looks
end
function P:Look()
    local look = Track("blast").look
    if look == "stone" or self:Unlocked("look:" .. look) then return look end
    return "stone"
end
function P:SetLook(key)
    if type(key) ~= "string" or not self:Unlocked("look:" .. key) then return false end
    Track("blast").look = key
    self:Changed()
    return true
end
function P:Mallet()
    local id = Track("whack").mallet
    if self:Unlocked("mallet:" .. id) then return id end
    return "wood"
end
function P:SetMallet(id)
    if type(id) ~= "string" or not self:Unlocked("mallet:" .. id) then return false end
    Track("whack").mallet = id
    self:Changed()
    return true
end

-- Milestones --------------------------------------------------------------------------------

-- Blast level n's zone (1 to 10 round the path).
local function ZoneIndex(n) return math.floor((n - 1) / 10) % 10 + 1 end
function P:Milestone(game, n)
    local listed = P.SCHEDULE[game] and P.SCHEDULE[game][n]
    if listed or game ~= "blast" or n <= P.MADE_FROM then return listed end
    if n % 10 == 0 then
        local here = ZoneIndex(n)
        return {unlock = {"zone:" .. tostring(self:ZoneKey(here % 10 + 1)), "look:" .. tostring(self:ZoneKey(here))}}
    end
    if n % P.GIFT_EVERY == 0 then
        local power = P.POWERS[(n / P.GIFT_EVERY) % #P.POWERS + 1]
        return {give = {[power] = 1}}
    end
    return nil
end
local function Milestone(self, game, n, report)
    local entry = self:Milestone(game, n)
    if not entry then return end
    local data = self:Data()
    for _, id in ipairs(entry.unlock or {}) do
        if not self:Unlocked(id) then
            data.unlocked[id] = true
            report.unlocks[#report.unlocks + 1] = id
        end
    end
    local key = game .. ":" .. n
    if entry.give and not data.gifts[key] then
        data.gifts[key] = true
        for _, power in ipairs(P.POWERS) do
            local count = entry.give[power]
            if count then
                data.powers[power] = math.min(P.MAX_POWER, data.powers[power] + count)
                report.gifts[#report.gifts + 1] = {id = power, count = count}
            end
        end
    end
    local listed = {}
    for _, card in ipairs(entry.cards or {}) do listed[#listed + 1] = card end
    for _, id in ipairs(report.unlocks) do listed[#listed + 1] = id end
    for _, card in ipairs(listed) do
        if P.CARDS[card] and not data.cards[card] then report.cards[#report.cards + 1] = card end
    end
end
function P:NextUnlock(game)
    local from = self:Level(game)
    for at = from, from + 60 do
        local entry = self:Milestone(game, at)
        for _, id in ipairs(entry and entry.unlock or {}) do
            if not self:Unlocked(id) then return {at = at, id = id, name = self:Name(id)} end
        end
    end
    return nil
end

-- A finished attempt: coins, stars, best, the next level and milestones.
function P:Finish(game, n, result)
    result = type(result) == "table" and result or {}
    local report = {coins = 0, first = false, newStars = 0, stars = 0, best = 0, newBest = false,
        unlocks = {}, gifts = {}, cards = {}}
    if game ~= "blast" and game ~= "whack" then return report end
    local rates = P.COINS[game]
    local score = Whole(result.score, 0, STAMP_CAP, 0)
    if game == "whack" and n == "quick" then
        local coins = math.floor(score / rates.quickPer) + Whole(result.golden, 0, nil, 0) * rates.golden
        if coins > 0 then self:AddCoins(coins, "quick") end
        report.coins = coins
        self:Changed(true)
        return report
    end
    n = Whole(n, 1, P.MAX_LEVEL, nil)
    if not n then return report end
    local book = Track(game)
    book.tries = math.min(STAMP_CAP, book.tries + 1)
    local coins = 0
    local old = self:Stars(game, n)
    report.stars = old
    report.best = book.best[n] or 0
    if result.won then
        book.wins = math.min(STAMP_CAP, book.wins + 1)
        local stars = Whole(result.stars, 1, 3, 1)
        report.first = old == 0
        if report.first then
            coins = rates.first + rates.star * stars + (result.boss and rates.boss or 0)
        else
            coins = rates.replay + rates.star * math.max(0, stars - old)
        end
        if rates.movesPer then coins = coins + math.floor(Whole(result.movesLeft, 0, nil, 0) / rates.movesPer) end
        report.newStars = math.max(0, stars - old)
        report.stars = math.max(old, stars)
        if stars > old then SetStars(book, n, stars) end
        local oldBest = book.best[n] or 0
        if score > oldBest then
            book.best[n] = score
            report.newBest = oldBest > 0
        end
        report.best = book.best[n] or score
        local level = game == "whack" and "stage" or "level"
        if n >= book[level] then
            book[level] = math.min(P.MAX_LEVEL, n + 1)
            report.opened = n + 1
        end
        if report.first then Milestone(self, game, n, report) end
    else
        coins = rates.loss or 0
    end
    if game == "blast" then coins = coins + Whole(result.epics, 0, nil, 0) * rates.epic
    else coins = coins + Whole(result.golden, 0, nil, 0) * rates.golden end
    if coins > 0 then self:AddCoins(coins, game) end
    report.coins = coins
    self:Changed(true)
    return report
end

-- Free play's coins: one per 1,000 points, paid as the score passes each.
function P:FreeCoins(kept, score)
    if type(kept) ~= "table" then return 0 end
    local thousands = math.floor(Whole(score, 0, STAMP_CAP, 0) / P.COINS.freePer)
    local paid = Whole(kept.coined, 0, STAMP_CAP, 0)
    if thousands <= paid then
        kept.coined = thousands
        return 0
    end
    kept.coined = thousands
    self:AddCoins(thousands - paid, "free")
    return thousands - paid
end

-- Resume and reset ----------------------------------------------------------------------------

function P:Resume(game)
    local store = EraUI:GetSetting("miniGameResume")
    if type(store) ~= "table" or store.version ~= 1 then return nil end
    local snapshot = store[game]
    return type(snapshot) == "table" and snapshot or nil
end
function P:SaveResume(game, snapshot)
    if game ~= "blast" and game ~= "whack" then return false end
    local store = EraUI:GetSetting("miniGameResume")
    if type(store) ~= "table" or store.version ~= 1 then
        if snapshot == nil then return true end
        store = {version = 1}
        EraUI:SetSetting("miniGameResume", store)
    end
    store[game] = type(snapshot) == "table" and snapshot or nil
    return true
end
-- Both games from the start. The new record's stamp is past the old one's, so
-- an older backup never brings the old progress back.
function P:Reset()
    local old = EraUI:GetSetting("miniGameProgress")
    local record = Default()
    record.stamp = math.min(STAMP_CAP, (type(old) == "table" and Whole(old.stamp, 0, STAMP_CAP, 0) or 0) + 1)
    EraUI:SetSetting("miniGameProgress", record)
    EraUI:SetSetting("miniGameResume", nil)
    self.checked = record
    for _, game in pairs(MG.games) do
        if game.built and type(game.ProgressReset) == "function" then
            local ok, err = pcall(game.ProgressReset, game)
            if not ok then MG.Report(err) end
        end
    end
    if MG.window and MG.PaintCoins then MG:PaintCoins() end
    if EraUI.SaveSettings then EraUI:SaveSettings() end
    return true
end
-- The /era row's line: where each game is.
function P:Summary()
    return ("Blast level %d, Whack stage %d, %d coins."):format(self:Level("blast"), self:Level("whack"), self:Coins())
end
