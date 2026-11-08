local _, EraUI = ...

-- Azeroth Blast (/era > Screen & Cursor > Mini-games; /era blast; experimental):
-- a match-three of Horde and Alliance races on an 8 x 8 board, in the
-- mini-games window (Modules/MiniGames.lua). Click a piece, then one next to
-- it (or drag it there): a swap that lines up three or more of a race, or
-- makes a 2 x 2 square of one, clears them, their loot flying to the score;
-- the pieces above fall into the gaps, new ones drop in, and any match
-- that makes clears too. A swap that matches nothing swaps back, unless a
-- special is in it. Stuck? The Hint button (or 15 seconds with no move)
-- shows the best move, then rests for 30.
--
-- Specials keep their race (the Hearthstone has none):
--   four in a line  Charge: clears its row (a line across) or its column (a line down)
--   an L or a T     Explosive Sheep: clears the 3 x 3 round it
--   a 2 x 2 square  Gryphon (Alliance players) or Wind Rider (Horde): clears one piece elsewhere
--   five in a line  Hearthstone: swapped with any piece, clears every piece of that race
-- Swapped with the piece next to it (a race's or a special, never a relic),
-- a special fires at once, no match needed, and the swap is a move: a
-- Charge, Sheep or flyer fires from the cell it lands on, and any match the
-- swap lines up clears with it. A special caught in a clear fires too. Two specials swapped together:
-- Charge + Sheep a cross three wide, Charge + Charge a row and a column,
-- Sheep + Sheep the 5 x 5 round it, Hearthstone + Hearthstone the whole
-- board, a Gryphon or Wind Rider + any special: both fire.
-- Clearing the other faction's races fills the Bloodlust meter (Heroism for
-- the Alliance); full, points count double for 10 seconds, then it fills
-- again. 10 points a piece; about one piece in 25 bursts into epic loot (a
-- purple flash), 50 more. No move left: the board is shuffled.
--
-- The board, its score and the meter are kept for this character
-- (MiniGames:CharData), so a flight's board waits for the next flight; New
-- board starts again, the old score kept as a best when it is one. The
-- rules are the plain functions in MiniGames.Blast (no frames:
-- Tools/TestAzerothBlast.lua plays them); the view (Modules/MiniGameBlastView.lua,
-- MiniGameBlastHud.lua and MiniGameBlastGame.lua, which registers the game)
-- replays what a move did (the swap, each clear and fall) and draws the board.
--
-- Levels (state.mode == "level", made by Blast.NewLevel in
-- Modules/MiniGameBlastLevels.lua): the same rules with holes, blockers,
-- goals, a move limit and bosses. These functions hand a level's own parts
-- to Modules/MiniGameBlastGoals.lua (Blast.ArrangeLevel, LevelStep, Exits,
-- FlyerTarget, LevelSwap); Free play (no mode) plays exactly as before.
--
-- Art and sounds: the race portraits (Interface\CharacterFrame, the 1.x unit
-- frame faces, with the raceicon128 atlases should the client refuse one),
-- the icons of Charge (spell 100), Explosive Sheep (item 4384), Hearthstone
-- (item 6948), the gryphon and wind rider mounts, Bloodlust and Heroism, and
-- the loot icons below: every one in this client's ManifestInterfaceData or
-- UiTextureAtlasMember, the item and spell icons by their Item and SpellMisc
-- rows (build 1.60.1.70707). The board's own art is listed with the view
-- (Modules/MiniGameBlastView.lua); its sounds are the core's (MiniGames.SOUNDS),
-- only with Mini-game Sounds on.
local MG = EraUI.MiniGames
if not MG then return end

local Blast = {}
MG.Blast = Blast
Blast.SIZE = 8
Blast.POINTS = 10        -- a piece cleared
Blast.EPIC_BONUS = 50    -- an epic piece, on top of its 10
Blast.EPIC_ODDS = 25     -- one cleared piece in this many is epic loot
Blast.METER_FULL = 30    -- the other faction's pieces that fill Bloodlust / Heroism
Blast.LUST_TIME = 10     -- seconds of double points once it's full
Blast.LUST_MULT = 2
Blast.CALM_AFTER = 12    -- a chain this long: new pieces stop making matches where they can
Blast.STEP_LIMIT = 40    -- one this long ends with the board laid out afresh
Blast.TRIES = 12         -- layouts tried for one with a move, before the fixed one

local N = Blast.SIZE
local CELLS = N * N
local PORTRAIT = "Interface\\CharacterFrame\\TemporaryPortrait-Male-"
local ICON = "Interface\\Icons\\"

-- Three Horde races and three Alliance ones, all of the first six of each side.
Blast.RACES = {
    {id = "orc", name = "orc", faction = "Horde", file = PORTRAIT .. "Orc", atlas = "raceicon128-orc-male"},
    {id = "tauren", name = "tauren", faction = "Horde", file = PORTRAIT .. "Tauren", atlas = "raceicon128-tauren-male"},
    {id = "undead", name = "undead", faction = "Horde", file = PORTRAIT .. "Scourge", atlas = "raceicon128-undead-male"},
    {id = "human", name = "human", faction = "Alliance", file = PORTRAIT .. "Human", atlas = "raceicon128-human-male"},
    {id = "dwarf", name = "dwarf", faction = "Alliance", file = PORTRAIT .. "Dwarf", atlas = "raceicon128-dwarf-male"},
    {id = "nightelf", name = "night elf", faction = "Alliance", file = PORTRAIT .. "NightElf", atlas = "raceicon128-nightelf-male"},
}
Blast.RACE, Blast.KINDS = {}, {}
for index, race in ipairs(Blast.RACES) do
    Blast.RACE[race.id] = race
    Blast.KINDS[index] = race.id
end
local KINDS = Blast.KINDS

Blast.ICONS = {
    charge = ICON .. "Ability_Warrior_Charge",      -- Charge (spell 100)
    sheep = ICON .. "Spell_Nature_Polymorph",       -- Explosive Sheep (item 4384)
    hearth = ICON .. "INV_Misc_Rune_01",            -- Hearthstone (item 6948)
    gryphon = ICON .. "Ability_Mount_Gryphon_01",
    windrider = ICON .. "Ability_Mount_Wyvern_01",
    bloodlust = ICON .. "Spell_Nature_BloodLust",
    heroism = ICON .. "Ability_Shaman_Heroism",
}
-- What a cleared piece bursts into: coins, potions, weapons and armour.
Blast.LOOT = {}
for index, name in ipairs({"INV_Misc_Coin_01", "INV_Misc_Coin_03", "INV_Misc_Coin_05", "INV_Potion_51", "INV_Potion_54",
    "INV_Potion_24", "INV_Potion_32", "INV_Sword_04", "INV_Axe_01", "INV_Mace_01", "INV_Chest_Chain_05", "INV_Helmet_01",
    "INV_Boots_01", "INV_Shield_04", "INV_Gauntlets_04", "INV_Misc_Gem_Ruby_01"}) do
    Blast.LOOT[index] = ICON .. name
end
Blast.EPIC_LOOT = {}
for index, name in ipairs({"INV_Sword_39", "INV_Hammer_Unique_Sulfuras", "INV_Misc_Head_Dragon_01", "INV_Spear_08"}) do
    Blast.EPIC_LOOT[index] = ICON .. name
end
-- The game's own sound kit UI_EPICLOOT_TOAST (the others are the core's).
MG.SOUNDS.epic = MG.SOUNDS.epic or 31578

-- The board -----------------------------------------------------------------------
-- state.board[i], i = (row - 1) * 8 + column, rows from the top: a piece
-- {id, kind (a race id; nil for the Hearthstone), special ("charge",
-- "sheep", "flyer", "hearth" or nil), dir ("row" or "col", a Charge's)}.
-- A piece is never changed once made, so a copy of the board is a picture of it.

function Blast.Index(r, c) return (r - 1) * N + c end
function Blast.Cell(i) return math.floor((i - 1) / N) + 1, (i - 1) % N + 1 end
local Index, Cell = Blast.Index, Blast.Cell
local function Inside(r, c) return r >= 1 and r <= N and c >= 1 and c <= N end
function Blast.Valid(i) return type(i) == "number" and i >= 1 and i <= CELLS and i == math.floor(i) end
function Blast.Adjacent(a, b)
    if not (Blast.Valid(a) and Blast.Valid(b)) then return false end
    local ra, ca = Cell(a)
    local rb, cb = Cell(b)
    return math.abs(ra - rb) + math.abs(ca - cb) == 1
end
local function KindAt(board, r, c)
    if not Inside(r, c) then return nil end
    local piece = board[Index(r, c)]
    return piece and piece.kind
end
local function Copy(board)
    local copy = {}
    for i = 1, CELLS do copy[i] = board[i] end
    return copy
end
Blast.Copy = Copy

-- A roll: state.random(low, high, why) when the state has one (the tests),
-- else MiniGames.Random. why: "kind", "epic", "loot", "flyer" or "hearth".
local function Roll(state, low, high, why)
    if high <= low then return low end
    local value
    if state.random then value = state.random(low, high, why) else value = MG.Random(low, high) end
    value = math.floor(tonumber(value) or low)
    return math.max(low, math.min(high, value))
end
local function Piece(state, kind, special, dir)
    state.nextId = (state.nextId or 0) + 1
    return {id = state.nextId, kind = kind, special = special, dir = dir}
end
Blast.Roll, Blast.Piece = Roll, Piece
function Blast.Enemy(state, piece)
    local race = piece and piece.kind and Blast.RACE[piece.kind]
    return race ~= nil and race.faction ~= state.faction
end
-- Why a piece can't be swapped, or nil: frozen ("ice"), webbed ("web"), a
-- crate or a skull (levels only; a relic swaps like a piece).
function Blast.Locked(piece)
    if type(piece) ~= "table" then return nil end
    if piece.ice then return "ice" end
    if piece.web then return "web" end
    if piece.block == "crate" or piece.block == "skull" then return piece.block end
    return nil
end
local Locked = Blast.Locked
-- Whether a piece can swap with a special and set it off, no match needed:
-- a race's piece or another special (a relic is neither; a locked piece never moves).
local function Swappable(piece)
    return piece ~= nil and not Locked(piece) and (piece.kind ~= nil or piece.special ~= nil)
end
Blast.Swappable = Swappable
-- A rectangle of the board, cut to fit: {top row, left column, bottom row, right column}.
local function Clip(r1, c1, r2, c2)
    return {math.max(1, r1), math.max(1, c1), math.min(N, r2), math.min(N, c2)}
end
local function EachIn(rect, fn)
    for r = rect[1], rect[3] do
        for c = rect[2], rect[4] do fn(Index(r, c)) end
    end
end
-- The area a Charge or a Sheep at cell i clears as it fires, or nil for a
-- flyer or a Hearthstone (what they hit is rolled as they go).
local function Reach(piece, i)
    local r, c = Cell(i)
    if piece.special == "charge" then return piece.dir == "col" and {1, c, N, c} or {r, 1, r, N} end
    if piece.special == "sheep" then return Clip(r - 1, c - 1, r + 1, c + 1) end
    return nil
end
Blast.Reach = Reach

-- Whether kind at (r, c) would be part of a line of three or a 2 x 2 square
-- with the pieces round it (the piece at (r, c) itself isn't looked at).
function Blast.Makes(board, r, c, kind)
    if not kind then return false end
    local left, right, up, down = 0, 0, 0, 0
    while KindAt(board, r, c - left - 1) == kind do left = left + 1 end
    while KindAt(board, r, c + right + 1) == kind do right = right + 1 end
    if left + right >= 2 then return true end
    while KindAt(board, r - up - 1, c) == kind do up = up + 1 end
    while KindAt(board, r + down + 1, c) == kind do down = down + 1 end
    if up + down >= 2 then return true end
    for top = r - 1, r do
        for side = c - 1, c do
            if Inside(top, side) and Inside(top + 1, side + 1) then
                local square = true
                for rr = top, top + 1 do
                    for cc = side, side + 1 do
                        if not (rr == r and cc == c) and KindAt(board, rr, cc) ~= kind then square = false end
                    end
                end
                if square then return true end
            end
        end
    end
    return false
end

-- Laying a board out ---------------------------------------------------------------

-- Row by row from the top left, each kind chosen so it finishes no line or
-- square with those before it: at most three kinds are ruled out, so a
-- board laid this way never starts with a match.
local function Finishes(board, r, c, kind)
    if KindAt(board, r, c - 1) == kind and KindAt(board, r, c - 2) == kind then return true end
    if KindAt(board, r - 1, c) == kind and KindAt(board, r - 2, c) == kind then return true end
    return KindAt(board, r - 1, c) == kind and KindAt(board, r, c - 1) == kind and KindAt(board, r - 1, c - 1) == kind
end
local function Pick(state, board, r, c)
    local kinds = state.kinds or KINDS
    local start = Roll(state, 1, #kinds, "kind")
    for k = 0, #kinds - 1 do
        local kind = kinds[(start - 1 + k) % #kinds + 1]
        if not Finishes(board, r, c, kind) then return kind end
    end
    return kinds[start]
end
-- The fixed layout, for when no random one had a move: no line, no square,
-- and one move (row 2's first two swapped line up column 1).
function Blast.Pattern(r, c, kinds)
    kinds = kinds or KINDS
    if r == 2 and c == 2 then return kinds[1] end
    return kinds[((c - 1) + 3 * ((r - 1) % 2)) % #kinds + 1]
end
-- A board laid out. keep: the specials stay where they are (a Hearthstone as
-- it is, the others with a race chosen again); else every piece is new and plain.
local function Lay(state, keep, fixed)
    local old, board = state.board or {}, {}
    for r = 1, N do
        for c = 1, N do
            local i = Index(r, c)
            local was = keep and old[i] or nil
            if was and was.special == "hearth" then
                board[i] = was
            else
                local kind = fixed and Blast.Pattern(r, c) or Pick(state, board, r, c)
                board[i] = Piece(state, kind, was and was.special or nil, was and was.dir or nil)
            end
        end
    end
    return board
end
function Blast.Arrange(state, keep)
    -- A level lays only its plain pieces, round its holes, blockers and specials.
    if state.mode == "level" then return Blast.ArrangeLevel(state) end
    for _ = 1, Blast.TRIES do
        local board = Lay(state, keep, false)
        if Blast.FindMove(board) then
            state.board = board
            return board
        end
    end
    state.board = Lay(state, keep, true)
    return state.board
end
-- No move left: the board shuffled. Returns whether it was.
function Blast.Unstick(state)
    if Blast.FindMove(state.board) then return false end
    Blast.Arrange(state, true)
    return true
end

-- A new game: a fresh board, nothing scored. faction: the player's ("Alliance",
-- else the Horde's view: their races are the friendly ones).
function Blast.New(random, faction)
    local state = {random = random, faction = faction == "Alliance" and "Alliance" or "Horde",
        score = 0, meter = 0, lust = 0, moves = 0, nextId = 0, board = {}}
    Blast.Arrange(state, false)
    return state
end
function Blast.Restart(state)
    state.score, state.meter, state.lust, state.moves = 0, 0, 0, 0
    Blast.Arrange(state, false)
end

-- Matches ------------------------------------------------------------------------------

-- Every match standing on the board: lines of three or more of a kind and 2 x 2
-- squares, joined where they share a piece. A group: {cells (in order), kind,
-- runs = {{dir = "row" or "col", cells}}, squares = {{cells}}}.
function Blast.FindGroups(board)
    local shapes = {}
    for line = 1, 2 do
        local dir = line == 1 and "row" or "col"
        for a = 1, N do
            local b = 1
            while b <= N do
                local r, c = a, b
                if dir == "col" then r, c = b, a end
                local kind, length = KindAt(board, r, c), 1
                if kind then
                    -- The next cell's place first: a Hearthstone (no race) there ends the line.
                    while b + length <= N do
                        local nr, nc = a, b + length
                        if dir == "col" then nr, nc = b + length, a end
                        if KindAt(board, nr, nc) ~= kind then break end
                        length = length + 1
                    end
                end
                if kind and length >= 3 then
                    local cells = {}
                    for k = 0, length - 1 do
                        cells[#cells + 1] = dir == "row" and Index(a, b + k) or Index(b + k, a)
                    end
                    shapes[#shapes + 1] = {dir = dir, cells = cells, kind = kind}
                end
                b = b + length
            end
        end
    end
    for r = 1, N - 1 do
        for c = 1, N - 1 do
            local kind = KindAt(board, r, c)
            if kind and KindAt(board, r, c + 1) == kind and KindAt(board, r + 1, c) == kind and KindAt(board, r + 1, c + 1) == kind then
                shapes[#shapes + 1] = {square = true, kind = kind, cells = {Index(r, c), Index(r, c + 1), Index(r + 1, c), Index(r + 1, c + 1)}}
            end
        end
    end
    -- Shapes sharing a piece are one group.
    local owner, groups = {}, {}
    for _, shape in ipairs(shapes) do
        local group
        for _, i in ipairs(shape.cells) do
            local other = owner[i]
            if other and other ~= group then
                if group then
                    -- Two groups this shape joins: the second's into the first.
                    for _, j in ipairs(other.cells) do owner[j] = group; group.cells[#group.cells + 1] = j end
                    for _, run in ipairs(other.runs) do group.runs[#group.runs + 1] = run end
                    for _, square in ipairs(other.squares) do group.squares[#group.squares + 1] = square end
                    other.dead = true
                else
                    group = other
                end
            end
        end
        if not group then
            group = {kind = shape.kind, cells = {}, runs = {}, squares = {}}
            groups[#groups + 1] = group
        end
        for _, i in ipairs(shape.cells) do
            if owner[i] ~= group then owner[i] = group; group.cells[#group.cells + 1] = i end
        end
        if shape.square then group.squares[#group.squares + 1] = shape else group.runs[#group.runs + 1] = shape end
    end
    local found = {}
    for _, group in ipairs(groups) do
        if not group.dead then
            table.sort(group.cells)
            found[#found + 1] = group
        end
    end
    return found
end

-- What a group makes: "hearth" (five in a line), "sheep" (a line across and
-- one down: an L or a T), "charge" and its dir (four in a line), "flyer" (a
-- 2 x 2 square), or nil (three in a line).
function Blast.Shape(group)
    local longest, across, down, dir = 0, false, false, nil
    for _, run in ipairs(group.runs) do
        if #run.cells > longest then longest, dir = #run.cells, run.dir end
        if run.dir == "row" then across = true else down = true end
    end
    if longest >= 5 then return "hearth" end
    if across and down then return "sheep" end
    if longest == 4 then return "charge", dir end
    if #group.squares > 0 then return "flyer" end
    return nil
end
-- Where a group's special goes: the piece you moved (when it's in the
-- group), else the corner of an L or T, else the middle of its longest line,
-- else its square's first piece.
local function Anchor(group, special, prefer)
    local mine = {}
    for _, i in ipairs(group.cells) do mine[i] = true end
    for _, i in ipairs(prefer or {}) do if mine[i] then return i end end
    if special == "sheep" then
        local across = {}
        for _, run in ipairs(group.runs) do
            if run.dir == "row" then for _, i in ipairs(run.cells) do across[i] = true end end
        end
        for _, run in ipairs(group.runs) do
            if run.dir == "col" then for _, i in ipairs(run.cells) do if across[i] then return i end end end
        end
    end
    local best
    for _, run in ipairs(group.runs) do if not best or #run.cells > #best.cells then best = run end end
    if best then return best.cells[math.ceil(#best.cells / 2)] end
    return group.squares[1] and group.squares[1].cells[1] or group.cells[1]
end
Blast.Anchor = Anchor

-- A move, as two cells, or nil: any special with a piece beside it that can
-- set it off (a Hearthstone, a special on its own, two specials together:
-- swapped, they fire), or a swap lining up three or a square. A level's
-- locked pieces (Blast.Locked) never move, its holes hold nothing, and a
-- special swapped with a relic needs a match like any piece.
local AROUND, AHEAD = {{0, 1}, {1, 0}, {0, -1}, {-1, 0}}, {{0, 1}, {1, 0}}
Blast.AROUND, Blast.AHEAD = AROUND, AHEAD
function Blast.FindMove(board)
    for i = 1, CELLS do
        local piece = board[i]
        if piece and piece.special and not Locked(piece) then
            local r, c = Cell(i)
            for _, step in ipairs(AROUND) do
                local rr, cc = r + step[1], c + step[2]
                if Inside(rr, cc) and Swappable(board[Index(rr, cc)]) then return i, Index(rr, cc) end
            end
        end
    end
    for r = 1, N do
        for c = 1, N do
            for _, step in ipairs(AHEAD) do
                local r2, c2 = r + step[1], c + step[2]
                if Inside(r2, c2) then
                    local a, b = Index(r, c), Index(r2, c2)
                    local pa, pb = board[a], board[b]
                    if pa and pb and not Locked(pa) and not Locked(pb) then
                        board[a], board[b] = pb, pa
                        local works = Blast.Makes(board, r, c, pb.kind) or Blast.Makes(board, r2, c2, pa.kind)
                        board[a], board[b] = pa, pb
                        if works then return a, b end
                    end
                end
            end
        end
    end
    return nil
end

-- Hints ---------------------------------------------------------------------------------

Blast.HINT_AFTER = 15     -- seconds with no move before a hint shows by itself
Blast.HINT_COOLDOWN = 30  -- seconds after any hint before the next, asked for or by itself

-- 1 when cell i holds a piece not yet in hit (now it is), else 0.
local function Hit(board, hit, i)
    if board[i] == nil or hit[i] then return 0 end
    hit[i] = true
    return 1
end
-- How good swapping a and b would be, or nil when it's no move: a
-- Hearthstone first (more for each piece of the race it would clear), then
-- two specials, then one special fired with a piece and a swap's matches:
-- each piece they clear, once (a Charge's line, a Sheep's 3 x 3, a flyer
-- and the one piece it hits, the matched pieces), and 4 more for each
-- special a match makes. The board is left as it was.
function Blast.MoveValue(board, a, b)
    if not Blast.Adjacent(a, b) then return nil end
    local pa, pb = board[a], board[b]
    if not (pa and pb) or Locked(pa) or Locked(pb) then return nil end
    local hearthA, hearthB = pa.special == "hearth", pb.special == "hearth"
    if hearthA or hearthB then
        if hearthA and hearthB then return 200 end
        if not (Swappable(pa) and Swappable(pb)) then return nil end
        local kind = hearthA and pb.kind or pa.kind
        local count = 0
        for i = 1, CELLS do if board[i] and board[i].kind == kind then count = count + 1 end end
        return 100 + count
    end
    if pa.special and pb.special then return 90 end
    local ra, ca = Cell(a)
    local rb, cb = Cell(b)
    -- One special with a piece that sets it off: it fires from where it
    -- lands (one from a ends on b, one from b on a).
    local at = (pa.special and Swappable(pb) and b) or (pb.special and Swappable(pa) and a) or nil
    board[a], board[b] = pb, pa
    local value
    if at or Blast.Makes(board, ra, ca, pb.kind) or Blast.Makes(board, rb, cb, pa.kind) then
        local hit = {}
        value = 0
        if at then
            local rect = Reach(board[at], at)
            if rect then
                for r = rect[1], rect[3] do
                    for c = rect[2], rect[4] do value = value + Hit(board, hit, Index(r, c)) end
                end
            else
                value = 1 + Hit(board, hit, at)   -- a flyer: itself and the one piece it hits
            end
        end
        for _, group in ipairs(Blast.FindGroups(board)) do
            for _, i in ipairs(group.cells) do value = value + Hit(board, hit, i) end
            if Blast.Shape(group) then value = value + 4 end
        end
    end
    board[a], board[b] = pa, pb
    return value
end
-- The best move on the board as two cells side by side, or nil when there's
-- none (the first of equals, from the top left).
function Blast.Hint(board)
    local bestA, bestB, best
    for r = 1, N do
        for c = 1, N do
            for _, step in ipairs(AHEAD) do
                local r2, c2 = r + step[1], c + step[2]
                if Inside(r2, c2) then
                    local a, b = Index(r, c), Index(r2, c2)
                    local value = Blast.MoveValue(board, a, b)
                    if value and (best == nil or value > best) then bestA, bestB, best = a, b, value end
                end
            end
        end
    end
    return bestA, bestB
end

-- A move ---------------------------------------------------------------------------------

-- A special firing from cell i: what it clears goes through add. Its record
-- goes in step.fired (a flyer's target, the race a Hearthstone picked) and
-- the area it lit in step.flashes ({top row, left column, bottom row, right column}).
local function Fire(state, step, i, piece, clear, add)
    local board = state.board
    local shot = {i = i, special = piece.special, dir = piece.dir, kind = piece.kind}
    step.fired[#step.fired + 1] = shot
    local rect = Reach(piece, i)
    if piece.special == "flyer" then
        -- In a level it goes for blockers first (Blast.FlyerTarget).
        local spots = {}
        if state.mode == "level" then spots = Blast.FlyerTarget(state, clear)
        else for j = 1, CELLS do if board[j] and not clear[j] then spots[#spots + 1] = j end end end
        if #spots > 0 then
            local j = spots[Roll(state, 1, #spots, "flyer")]
            shot.target = j
            local tr, tc = Cell(j)
            rect = {tr, tc, tr, tc}
        end
    elseif piece.special == "hearth" then
        -- Caught in a clear, a Hearthstone takes a race still on the board.
        local kinds, seen = {}, {}
        for j = 1, CELLS do
            local other = board[j]
            if other and other.kind and not clear[j] and not seen[other.kind] then
                seen[other.kind] = true
                kinds[#kinds + 1] = other.kind
            end
        end
        if #kinds > 0 then
            local kind = kinds[Roll(state, 1, #kinds, "hearth")]
            shot.kind = kind
            for j = 1, CELLS do if board[j] and board[j].kind == kind then add(j) end end
        end
    end
    if rect then
        EachIn(rect, add)
        step.flashes[#step.flashes + 1] = rect
    end
end
Blast.Fire, Blast.Clip, Blast.EachIn = Fire, Clip, EachIn

-- Pieces fall into the gaps, then new ones drop in from the top. Returns how
-- many rows the piece now in each cell fell (a new one from above the board).
-- calm: new pieces are kinds that make no match where one can be found.
local function Fall(state, calm)
    local board, fall, gaps = state.board, {}, {}
    for c = 1, N do
        local write = N
        for r = N, 1, -1 do
            local i = Index(r, c)
            local piece = board[i]
            if piece then
                if r ~= write then
                    board[Index(write, c)] = piece
                    board[i] = nil
                end
                fall[Index(write, c)] = write - r
                write = write - 1
            end
        end
        gaps[c] = write
    end
    for c = 1, N do
        for r = gaps[c], 1, -1 do
            local kind = KINDS[Roll(state, 1, #KINDS, "kind")]
            if calm and Blast.Makes(board, r, c, kind) then
                local start = Roll(state, 1, #KINDS, "kind")
                for k = 0, #KINDS - 1 do
                    local other = KINDS[(start - 1 + k) % #KINDS + 1]
                    if not Blast.Makes(board, r, c, other) then kind = other; break end
                end
            end
            board[Index(r, c)] = Piece(state, kind)
            fall[Index(r, c)] = gaps[c]
        end
    end
    return fall
end

-- One clear: the matched groups and the plan's seeds (a combo's area) go,
-- with whatever the specials caught in them set off; the new specials are
-- put in; the pieces fall and new ones drop. Returns what happened:
-- before (the board first), cleared ({i, piece, loot, epic}, in cell
-- order), fired, made ({i, piece}), flashes, after (the board after the
-- fall), fall, points, mult, score, meter, lust (it started here), enemies, epics.
local function Step(state, plan)
    local board = state.board
    local step = {before = Copy(board), cleared = {}, fired = {}, made = {}, flashes = {}}
    local clear, order, done = {}, {}, {}
    local function Add(i)
        if board[i] and not clear[i] then
            clear[i] = true
            order[#order + 1] = i
        end
    end
    for id in pairs(plan.spent or {}) do done[id] = true end
    for _, rect in ipairs(plan.flashes or {}) do step.flashes[#step.flashes + 1] = rect end
    local made = {}
    for _, group in ipairs(plan.groups or {}) do
        for _, i in ipairs(group.cells) do Add(i) end
        local special, dir = Blast.Shape(group)
        if special then
            made[#made + 1] = {i = Anchor(group, special, plan.prefer), kind = special ~= "hearth" and group.kind or nil,
                special = special, dir = dir}
        end
    end
    for _, i in ipairs(plan.seeds or {}) do Add(i) end
    -- Every special in what's cleared fires once (its blast can catch more).
    local k = 1
    while k <= #order do
        local i = order[k]
        local piece = board[i]
        if piece.special and not done[piece.id] then
            done[piece.id] = true
            Fire(state, step, i, piece, clear, Add)
        end
        k = k + 1
    end
    table.sort(order)
    local mult = state.lust > 0 and Blast.LUST_MULT or 1
    local points, enemies, epics = 0, 0, 0
    for _, i in ipairs(order) do
        local piece = board[i]
        local epic = Roll(state, 1, Blast.EPIC_ODDS, "epic") == 1
        local list = epic and Blast.EPIC_LOOT or Blast.LOOT
        step.cleared[#step.cleared + 1] = {i = i, piece = piece, loot = list[Roll(state, 1, #list, "loot")], epic = epic}
        points = points + Blast.POINTS + (epic and Blast.EPIC_BONUS or 0)
        if epic then epics = epics + 1 end
        if Blast.Enemy(state, piece) then enemies = enemies + 1 end
        board[i] = nil
    end
    points = points * mult
    state.score = state.score + points
    for _, make in ipairs(made) do
        local piece = Piece(state, make.kind, make.special, make.dir)
        board[make.i] = piece
        step.made[#step.made + 1] = {i = make.i, piece = piece}
    end
    -- The meter fills from the other faction's pieces, and not while it's spent.
    if state.lust <= 0 then
        state.meter = state.meter + enemies
        if state.meter >= Blast.METER_FULL then
            state.meter, state.lust, step.lust = 0, Blast.LUST_TIME, true
        end
    end
    step.fall = Fall(state, plan.calm)
    step.after = Copy(board)
    step.points, step.mult, step.score, step.meter = points, mult, state.score, state.meter
    step.enemies, step.epics = enemies, epics
    return step
end

-- Clears until no match stands (a chain this long: the board laid out afresh).
-- In a level each clear is Blast.LevelStep (plan.index: its place in the
-- chain), and relics reaching an exit leave after it (Blast.Exits).
local function Run(state, plan, result)
    local steps = result.steps
    local level, index = state.mode == "level", 0
    while plan do
        if #steps >= Blast.STEP_LIMIT then
            Blast.Arrange(state, true)
            result.settled = true
            return
        end
        plan.calm = #steps + 1 >= Blast.CALM_AFTER
        index = index + 1
        plan.index = index
        local step = level and Blast.LevelStep(state, plan) or Step(state, plan)
        steps[#steps + 1] = step
        if step.lust then result.lustStep = #steps end
        if level then Blast.Exits(state, result) end
        local groups = Blast.FindGroups(state.board)
        plan = #groups > 0 and {groups = groups} or nil
    end
end
Blast.Run = Run

-- Two specials swapped together, a Hearthstone with any piece, or one
-- special with a race's piece: what goes (no match needed). nil: an
-- ordinary swap. After the swap board[b] is the piece you moved (from a)
-- and board[a] the other; areas centre on b. One special on its own
-- (plan.lone: the cell it's in now) fires from where it landed, with any
-- match the swap lines up in the same clear.
function Blast.Combo(state, a, b)
    local board = state.board
    local moved, other = board[b], board[a]
    local first, second = moved.special, other.special
    if not (first or second) then return nil end
    local plan = {seeds = {}, spent = {}, flashes = {}, groups = {}}
    local function Area(rect)
        plan.flashes[#plan.flashes + 1] = rect
        EachIn(rect, function(i) plan.seeds[#plan.seeds + 1] = i end)
    end
    if first == "hearth" or second == "hearth" then
        if first == "hearth" and second == "hearth" then
            plan.combo = "hearths"
            plan.spent[moved.id], plan.spent[other.id] = true, true
            Area({1, 1, N, N})
        else
            local hearth, piece = moved, other
            if second == "hearth" then hearth, piece = other, moved end
            -- A relic has no race: with it a Hearthstone needs a match like any piece.
            if piece.kind == nil and piece.special == nil then return nil end
            plan.combo, plan.hearthKind = "hearth", piece.kind
            plan.spent[hearth.id] = true
            plan.seeds[1] = hearth == moved and b or a
            for i = 1, CELLS do if board[i] and board[i].kind == piece.kind then plan.seeds[#plan.seeds + 1] = i end end
        end
        return plan
    end
    if not (first and second) then
        local at, piece = b, other
        if not first then at, piece = a, moved end
        -- A relic has no race: with it a special needs a match like any piece.
        if piece.kind == nil then return nil end
        plan.lone, plan.seeds[1] = at, at
        plan.groups, plan.prefer = Blast.FindGroups(board), {b, a}
        return plan
    end
    plan.seeds[1], plan.seeds[2] = b, a
    if first == "flyer" or second == "flyer" then
        plan.combo = "flyer"
        return plan
    end
    plan.spent[moved.id], plan.spent[other.id] = true, true
    local r, c = Cell(b)
    if first == "charge" and second == "charge" then
        plan.combo = "charges"
        Area({r, 1, r, N})
        Area({1, c, N, c})
    elseif first == "sheep" and second == "sheep" then
        plan.combo = "sheeps"
        Area(Clip(r - 2, c - 2, r + 2, c + 2))
    else
        plan.combo = "chargesheep"
        Area(Clip(r - 1, 1, r + 1, N))
        Area(Clip(1, c - 1, N, c + 1))
    end
    return plan
end

-- Swaps the piece at a with its neighbour at b. Returns {ok = false, why =
-- "far" or "nomatch"} (the board as it was), or {ok = true, steps (each
-- clear), swapped (the board just after the swap), combo, hearthKind, lone
-- (the cell a special on its own fired from), lustStep, settled,
-- reshuffled, points, scoreBefore, meterBefore}.
-- A level's swap is Blast.LevelSwap (opts.free: a Free swap).
function Blast.Swap(state, a, b, opts)
    if state.mode == "level" then return Blast.LevelSwap(state, a, b, opts) end
    local board = state.board
    if not (Blast.Adjacent(a, b) and board[a] and board[b]) then return {ok = false, why = "far", a = a, b = b} end
    local pa, pb = board[a], board[b]
    board[a], board[b] = pb, pa
    local plan = Blast.Combo(state, a, b)
    if not plan then
        local groups = Blast.FindGroups(board)
        if #groups == 0 then
            board[a], board[b] = pa, pb
            return {ok = false, why = "nomatch", a = a, b = b}
        end
        plan = {groups = groups, prefer = {b, a}}
    end
    local result = {ok = true, a = a, b = b, steps = {}, swapped = Copy(board), combo = plan.combo, hearthKind = plan.hearthKind,
        lone = plan.lone, scoreBefore = state.score, meterBefore = state.meter}
    Run(state, plan, result)
    result.reshuffled = Blast.Unstick(state)
    result.points = state.score - result.scoreBefore
    state.moves = state.moves + 1
    return result
end

-- Clears any matches standing on the board (none after a move or a new
-- board; the tests lay boards that have them). Returns as Swap does.
function Blast.Settle(state)
    local result = {ok = true, steps = {}, scoreBefore = state.score, meterBefore = state.meter}
    local groups = Blast.FindGroups(state.board)
    if #groups > 0 then Run(state, {groups = groups}, result) end
    result.reshuffled = Blast.Unstick(state)
    result.points = state.score - result.scoreBefore
    return result
end

-- Time passing: Bloodlust / Heroism runs down. Returns true as it ends.
-- In a level it lasts moves, not seconds, so time does nothing there.
function Blast.Tick(state, dt)
    if state.mode == "level" or state.lust <= 0 then return false end
    dt = tonumber(dt) or 0
    if dt ~= dt or dt <= 0 then return false end
    state.lust = math.max(0, state.lust - dt)
    return state.lust == 0
end

-- Keeping a board ------------------------------------------------------------------------
-- In the game's table (MiniGames:CharData("blast")): board, one string of
-- the 64 pieces from the top left ("orc", "orc/charge/row", "/hearth"),
-- score and meter.

local SPECIALS = {charge = true, sheep = true, flyer = true, hearth = true}
local function Whole(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return 0 end
    return math.floor(value)
end
function Blast.Save(state, into)
    local pieces = {}
    for i = 1, CELLS do
        local piece = state.board[i]
        local text = piece.kind or ""
        if piece.special then text = text .. "/" .. piece.special .. (piece.dir and ("/" .. piece.dir) or "") end
        pieces[i] = text
    end
    into.board, into.score, into.meter, into.version = table.concat(pieces, ","), state.score, state.meter, 1
end
-- A kept board back into state. Returns false (state left alone) when there's
-- none, or it's damaged or has a match standing.
function Blast.Load(state, from)
    if type(from) ~= "table" or type(from.board) ~= "string" or from.version ~= 1 then return false end
    local board = {}
    for text in (from.board .. ","):gmatch("([^,]*),") do
        local kind, special, dir = text:match("^([%a]*)/?([%a]*)/?([%a]*)$")
        if not kind then return false end
        if special == "" then special = nil end
        if dir == "" then dir = nil end
        if special and not SPECIALS[special] then return false end
        if special == "hearth" then
            if kind ~= "" or dir then return false end
            kind = nil
        elseif not Blast.RACE[kind] then
            return false
        end
        if (special == "charge") ~= (dir == "row" or dir == "col") then return false end
        if #board >= CELLS then return false end
        board[#board + 1] = Piece(state, kind, special, dir)
    end
    if #board ~= CELLS or #Blast.FindGroups(board) > 0 then return false end
    state.board = board
    state.score = Whole(from.score)
    state.meter = math.min(Blast.METER_FULL - 1, Whole(from.meter))
    state.lust, state.moves = 0, 0
    Blast.Unstick(state)
    return true
end
