local _, EraUI = ...

-- Azeroth Blast's board (experimental, with the mini-games): the drawing and
-- the beats a move plays out in, for Free play and the levels alike. Owned
-- by the Blast view; the rules are Modules/MiniGameBlast.lua and its level
-- files, the HUD, power-ups and edge glow Modules/MiniGameBlastHud.lua, the
-- screens and flow Modules/MiniGameBlastGame.lua (which registers the game).
--
-- The board: tiles in the zone's own ground (Free play: the look picked, the
-- old stone at first) in a rim of your side's metal. Each piece is a race's
-- face on a plate of its own bright colour and shape, a small pip of its
-- side's colour at the bottom right (Horde red, Alliance blue), a special's
-- badge at the top right: in a soft light of the special's colour, swelling
-- gently in its gold ring, a star glinting on it now and then, the whole
-- piece in a pulsing glow of that colour (never over the face). Blockers: oil under a piece, ice and webs over it,
-- crates, skulls and relics in place of one (a relic on a gold glow), arrows
-- under the exits, and no tile at all on a hole. A move plays out in beats:
-- the swap slides (back with a boing when it matches nothing); each clear
-- flashes and pops its pieces (sparks in the race's colour, loot flying to
-- the score, the points rising, ice cracking, crates splintering, oil
-- splashing), the specials fire, the boss is hit; the pieces fall in with a
-- bounce; relics reaching an exit fly off; the boss strikes back. Everything
-- is made once and reused; the window's update moves it (game:Update) and
-- the effects kit (Modules/MiniGameFX.lua) the rest. A helper: no update,
-- timer or animation of its own.
--
-- VIEW CONTRACT (for the HUD and game files): MiniGames.BlastView = {V, PAINT,
-- OPTS, NOTES, game}. game is the one table the three files fill with
-- methods; game:MakeBoard(shell, play), :Look(key), :Paint(board), :Dress(cell,
-- piece), :SyncOil(), :PaintOil(i), :PaintCells(), :Select(i), :Calm(),
-- :ShowHint(asked), :ClearHint(), :Shine(dt), :Queue(beat), :QueueSteps(result),
-- :Play(elapsed), :Done(cut) (then game:Ended(cut) when the game file has it),
-- :Once(name), game.FallAt. MiniGames.Blast.VIEW is V.
local MG = EraUI.MiniGames
if not MG or not MG.Blast then return end

local Blast = MG.Blast
local N = Blast.SIZE
local CELLS = N * N
local Cell = Blast.Cell

-- The layout, in the play area (412 x 500, y down from its top left). The
-- board 26..386 across and 78..438 down: the HUD above it (4..60), the
-- power-up bar under it (458..498) and the Bloodlust / Heroism bands round
-- it (3 to 16 px out) never touch.
local V = {
    -- A darker ground (TILE_SHADE) and a 3 px dark rim round each plate, so
    -- the pieces stand out even on the warm zones' sand and dirt.
    CELL = 45, TOP = 78, TILE = 43, RIM = 3, TILE_SHADE = .6, PLATE_DARK = .25,
    PLATE = 41, PLATE_RIM = 47, FACE = 33, SHEEN = 26, HOVER = 47,
    PIP = 12, PIP_RIM = 16, PIP_X = 13, PIP_Y = -13,
    -- A special's badge at the top right: its ring (which never swells)
    -- just fits the cell (13 + 9.5 = 22.5, half of CELL) and keeps off the
    -- face (its edge 8.9 px from the face's centre, the old badge 7.9), the
    -- light round it sits on the plate under the face, and a glint flares on
    -- it every GLINT_EVERY seconds for GLINT_LIFE.
    BADGE = 17, BADGE_RING = 19, BADGE_X = 13, BADGE_Y = 13, BADGE_GLOW = 38,
    GLINT = 20, GLINT_EVERY = 2.6, GLINT_LIFE = .55,
    GLOW = 76, PICK = 52, HINT = 56,
    OIL = 43, ICE = 41, WEB = 43, CRATE = 39, SKULL = 36, RELIC = 34, RELIC_GLOW = 50,
    EXIT_W = 30, EXIT_H = 16, EXIT_IN = 6,
    SLIDE = .13, BURST = .3, FALL = .22, FALL_ROW = .03, FADE = .34, LAND = .74,
    EXIT = .45, BOSS = .7, SMASH = .22, BOOST = .45,
    FLASHES = 12, STREAKS = 8, FLYERS = 12, SWIRLS = 4, EXITS = 8,
    LOOT_FLY = 5,
    LEVEL = {board = 2, top = 6, over = 12, hud = 14, edge = 10, sky = 30},
    -- The HUD strip and its boxes, the power-up bar and the edge glow (Modules/MiniGameBlastHud.lua).
    HUD_H = 62,
    MOVES = {x = 8, y = 4, w = 76, h = 56},
    GOALS = {x = 92, y = 4, w = 76, h = 56, gap = 6},
    BOSS_CHIP = {x = 92, y = 4, w = 240, h = 56, portrait = 48},
    METER = {x = 336, y = 4, w = 70, h = 56},
    POWER = {y = 458, size = 40, gap = 10, icon = 34},
    -- The runners 12 px wide, 10 px out: 4 to 16 px out, clear of the HUD (60) and the bar (458).
    EDGE = {inner = 5, innerOut = 3, outer = 8, outerOut = 8, runner = 12, runnerOut = 10, speed = 220, pulse = 2.5},
    MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask",
    STONE = "Interface\\Garrison\\ClassHallBackground",
    BADGE_ATLAS = "GarrMission_PortraitRing",
    HINT_ATLAS = "talents-node-circle-greenglow",
    SWIRL_ATLAS = "powerswirlanimation-whirls",
    FACE_COORDS = {.1, .9, .08, .88},
}
V.BOARD = V.CELL * N
V.LEFT = (MG.CONTENT_W - V.BOARD) / 2
V.BOTTOM = V.TOP + V.BOARD
-- Where the header's score is from the holder's top left, should the client not say (loot flies there).
V.SCORE_X, V.SCORE_Y = MG.CONTENT_W - 60, MG.CONTENT_Y - 23
Blast.VIEW = V
local ART = MG.ART or {}
local QUARTER = MG.QUARTER or {}
local EMPTY = {}

local PAINT = {
    white = {1, 1, 1}, gold = {1, .84, .35}, pick = {1, .97, .85},
    -- The side's pip in a pale ring, so it shows on a plate of its own colour.
    pip = {Horde = {.86, .16, .1}, Alliance = {.18, .44, 1}}, pipRim = {.96, .95, .9},
    metal = {Horde = {.66, .48, .28}, Alliance = {.86, .68, .27}},
    lust = {Horde = {.92, .16, .1}, Alliance = {.22, .52, 1}},
    lustText = {Horde = {1, .4, .3}, Alliance = {.5, .75, 1}},
    special = {charge = {1, .62, .18}, sheep = {1, .45, .85}, flyer = {.45, .82, 1}, hearth = {.3, .6, 1}},
    hearthPlate = {.16, .3, .7},
    epic = {.7, .32, 1}, hint = {.4, 1, .5}, buzz = {1, .22, .18},
    chain = {{.12, 1, 0}, {0, .44, .87}, {.64, .21, .93}, {1, .5, 0}},
    -- A boss action's colour on the cells it strikes, and each blocker's bits as it breaks.
    action = {oil = {.25, .18, .08}, freeze = {.6, .85, 1}, crates = {.75, .5, .25}, skulls = {.9, .9, .85}, web = {.9, .9, .95}},
    bits = {ice = {.65, .88, 1}, web = {.95, .95, 1}, crate = {.72, .5, .26}, skull = {.92, .9, .82}, oil = {.12, .08, .04},
        relic = {1, .84, .35}},
    -- Each race's plate (Modules/MiniGameAssets.lua's piece.<race>.colour is the one source).
    race = {},
}
local PLATE_FALLBACK = {orc = {.24, .74, .22}, tauren = {.98, .56, .12}, undead = {.12, .76, .72},
    human = {.22, .46, 1}, dwarf = {.9, .22, .18}, nightelf = {.96, .5, .95}}
for _, race in ipairs(Blast.RACES) do
    local fallback = PLATE_FALLBACK[race.id]
    local r, g, b = fallback[1], fallback[2], fallback[3]
    if MG.Colour3 then r, g, b = MG:Colour3("piece." .. race.id .. ".colour", fallback) end
    PAINT.race[race.id] = {r, g, b}
end
local CHAIN = {"Double!", "Triple!", "Unstoppable!", "Legendary!"}
local NOTES = {
    first = "Click a piece, then one next to it to swap.",
    nomatch = "No match there, so they swap back.",
    shuffled = "No moves left, so the board was shuffled.",
    fresh = "A new board.",
    best = "A new board. That last one was a new best!",
    landed = "Your board from your last flight is kept.",
    landedLevel = "Your level waits for your next flight.",
    epic = "Epic loot! 50 more for each.",
    chain = "A chain of %d!",
    lust = "%s! Double points for 10 seconds.",
    lustMoves = "%s! Double points for 3 moves.",
    over = "%s is over. Fill the meter again.",
    charge = "Charge made: swap it with any piece to clear its line.",
    sheep = "Explosive Sheep made: swap with any piece to blast round it.",
    flyer = "%s made: swap with any piece to clear one elsewhere.",
    hearth = "Hearthstone made: swap it with any piece to clear that race.",
    hearthUsed = "Hearthstone: every %s cleared!",
    charges = "Two Charges: a row and a column!",
    sheeps = "Two Sheep: a huge blast!",
    chargesheep = "Charge and Sheep: a cross three wide!",
    hearths = "Two Hearthstones: the whole board!",
    flyerCombo = "%s combo: both fire!",
    hint = "Swap the two glowing pieces.",
    locked = {ice = "Frozen pieces can't move. Match next to them.",
        web = "Webbed pieces can't move. Match them to break the web.",
        crate = "Crates can't move. Match next to them.", skull = "Skulls can't move. Match next to them."},
    relicOut = "A relic is out!",
    bossStrike = "%s Clear it to hit him full.",
}
-- The effects' options, filled in before each call (the kit only reads them).
local OPTS = {
    spark = {count = 5, texture = ART.bursts, coords = QUARTER.white, size = 13, speed = 95, life = .45, gravity = 170, spin = .6},
    points = {size = 18, rise = 36, life = .9},
    epicText = {colour = PAINT.epic, size = 20, rise = 46, life = 1.1, y = 14},
    epicPulse = {colour = PAINT.epic, texture = ART.glow, scale = 2.6, alpha = .95, life = .55, grow = 1.3},
    epicSpark = {count = 10, texture = ART.spark, colour = PAINT.epic, size = 16, speed = 120, life = .6},
    puff = {count = 6, texture = ART.smoke, coords = QUARTER.white, blend = "BLEND", colour = {.93, .93, .96},
        size = 24, speed = 60, life = .7, spin = .25, shrink = 0, alpha = .85},
    shock = {texture = ART.ring, colour = {1, .85, .55}, alpha = .9, life = .42, grow = 1.6},
    flare = {texture = ART.flare, colour = {1, .9, .6}, alpha = 1, life = .3, grow = 1.4},
    hearthPulse = {colour = PAINT.special.hearth, alpha = .8, life = .45, scale = 1.8},
    hearthSpark = {count = 10, texture = ART.spark, colour = PAINT.special.hearth, size = 14, speed = 90, life = .6, spin = .5},
    land = {colour = PAINT.special.flyer, alpha = .85, life = .35, scale = 2},
    landSpark = {count = 8, texture = ART.spark, colour = PAINT.special.flyer, size = 12, speed = 100, life = .45},
    made = {alpha = .9, life = .5, scale = 2.2, grow = 1.25},
    buzz = {colour = PAINT.buzz, alpha = .55, life = .3, scale = 1.5},
    chain = {size = 30, life = 1.1},
    lust = {size = 34, life = 1.9, glow = {0, 0, 0}},
    lustSpark = {count = 16, texture = ART.spark, size = 16, speed = 130, life = .6},
    best = {size = 30, life = 1.6, colour = PAINT.gold},
    -- Blockers breaking: bits flying (in the blocker's colour) and a flash.
    bits = {count = 7, texture = ART.bursts, coords = QUARTER.white, size = 11, speed = 110, life = .5, gravity = 260, spin = .8},
    splat = {count = 6, texture = ART.smoke, coords = QUARTER.white, blend = "BLEND", size = 16, speed = 55, life = .5,
        gravity = 120, shrink = .3, alpha = .9},
    crack = {texture = ART.starburst, alpha = .8, life = .3, scale = 1.4, grow = 1.25},
    relicGlow = {colour = PAINT.gold, alpha = .9, life = .5, scale = 2.2, grow = 1.3},
    relicSpark = {count = 14, texture = ART.spark, colour = PAINT.gold, size = 15, speed = 120, life = .6},
    relicText = {colour = PAINT.gold, size = 18, rise = 40, life = 1},
    strike = {alpha = .85, life = .55, scale = 1.6, grow = 1.2},
    smash = {texture = ART.ring, colour = {1, .85, .45}, alpha = .95, life = .35, grow = 1.7, scale = 1.6},
    smashSpark = {count = 12, texture = ART.spark, colour = {1, .85, .45}, size = 14, speed = 140, life = .45},
    boosted = {colour = PAINT.gold, alpha = .9, life = .6, scale = 2.4, grow = 1.3},
}

-- The one table the view, the HUD and the game file fill with methods.
local game = {beats = {}, clock = 0, idle = 0, stamp = 0, heard = {}, oil = {}}
MG.BlastView = {V = V, PAINT = PAINT, OPTS = OPTS, NOTES = NOTES, game = game}

function game:Faction()
    if self.state then return self.state.faction end
    return MG.Faction() == "Alliance" and "Alliance" or "Horde"
end
function game:LustName() return self:Faction() == "Alliance" and "Heroism" or "Bloodlust" end
function game:FlyerName() return self:Faction() == "Alliance" and "Gryphon" or "Wind Rider" end
function game:Badge(special)
    if special == "flyer" then return self:Faction() == "Alliance" and Blast.ICONS.gryphon or Blast.ICONS.windrider end
    return special and special ~= "hearth" and Blast.ICONS[special] or nil
end

-- Art ---------------------------------------------------------------------------------------

local function HasAtlas(name)
    local info = type(C_Texture) == "table" and C_Texture.GetAtlasInfo
    if type(name) ~= "string" or type(info) ~= "function" then return false end
    local ok, found = pcall(info, name)
    return ok and found ~= nil
end
-- An atlas the client has, else a file (a path or file ID): "atlas", "file" or nil.
local function Art(texture, atlas, file)
    if atlas and type(texture.SetAtlas) == "function" and HasAtlas(atlas) and pcall(texture.SetAtlas, texture, atlas) then
        return "atlas"
    end
    if file ~= nil and texture:SetTexture(file) ~= false then return "file" end
    return nil
end
-- A texture of light (added, never laid over): the file, else a faint flat white, tinted.
local function Lit(texture, file, colour)
    if file == nil or texture:SetTexture(file) == false then texture:SetColorTexture(1, 1, 1, .2) end
    texture:SetBlendMode("ADD")
    if colour then texture:SetVertexColor(colour[1], colour[2], colour[3], 1) end
    return texture
end
-- A plain disc (the portrait mask), tinted; a flat square should the client refuse it.
local function Disc(texture, colour, alpha)
    if texture:SetTexture(V.MASK) == false then texture:SetColorTexture(1, 1, 1, 1) end
    texture:SetVertexColor(colour[1], colour[2], colour[3], alpha or 1)
    return texture
end
-- A texture cut round by the portrait mask; one mask can cut several. Returns the mask.
local function Round(owner, texture, mask)
    if type(texture.AddMaskTexture) ~= "function" then return nil end
    if not mask then
        if type(owner.CreateMaskTexture) ~= "function" then return nil end
        mask = owner:CreateMaskTexture()
        mask:SetTexture(V.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(texture)
    end
    texture:AddMaskTexture(mask)
    return mask
end
local function Square(owner, layer, size, sublevel, x, y)
    local texture = owner:CreateTexture(nil, layer, nil, sublevel)
    texture:SetSize(size, size)
    texture:SetPoint("CENTER", owner, "CENTER", x or 0, y or 0)
    return texture
end
MG.BlastView.Lit, MG.BlastView.Disc, MG.BlastView.Round, MG.BlastView.Square = Lit, Disc, Round, Square
-- A race's face: its portrait cropped to the face, else its race icon should the client refuse it.
function Blast.PutFace(texture, race)
    if texture:SetTexture(race.file) ~= false then
        local c = V.FACE_COORDS
        texture:SetTexCoord(c[1], c[2], c[3], c[4])
        return "file"
    end
    if race.atlas and HasAtlas(race.atlas) and type(texture.SetAtlas) == "function" and pcall(texture.SetAtlas, texture, race.atlas) then
        return "atlas"
    end
    return "missing"
end
-- A race's plate (its own shape and colour) and the darker rim behind it.
function game:PaintPlate(plate, rim, race, size)
    local colour = PAINT.race[race] or PAINT.white
    local role = "plate." .. race
    local k = V.PLATE_DARK
    local dark = {colour[1] * k, colour[2] * k, colour[3] * k}
    MG:Art(plate, role, {tint = colour, colour = {colour[1], colour[2], colour[3], 1}})
    MG:Art(rim, role, {tint = dark, colour = {dark[1], dark[2], dark[3], 1}})
    local entry = MG.Asset and MG:Asset(role)
    local stretch = entry and entry.stretch
    local w = stretch and (stretch[1] or 1) or 1
    plate:SetSize(size * w, size)
    local around = size * V.PLATE_RIM / V.PLATE
    rim:SetSize(around * w, around)
end

-- A piece's parts: its glow, plate and rim, a sheen, the face (or a
-- Hearthstone's icon), a blocker in its place, ice and webs over it, the
-- crate's hits, its side's pip and a special's badge (its light and glint) and line.
local function MakeMarks(owner, art)
    art.streak = Square(art, "OVERLAY", 10, 2)
    if art.streak:SetTexture(ART.castSpark) == false then art.streak:SetColorTexture(1, .82, .3, .9) end
    art.streak:SetBlendMode("ADD")
    art.streak:Hide()
    art.pipRim = Disc(Square(art, "OVERLAY", V.PIP_RIM, 3, V.PIP_X, V.PIP_Y), PAINT.pipRim)
    art.pip = Square(art, "OVERLAY", V.PIP, 4, V.PIP_X, V.PIP_Y)
    art.pip:SetTexture(V.MASK)
    -- The badge's light: on the plate, under the face, so the portrait is never dimmed or washed out.
    art.badgeGlow = Lit(Square(art, "ARTWORK", V.BADGE_GLOW, -1, V.BADGE_X, V.BADGE_Y), ART.glow)
    art.badgeGlow:Hide()
    art.badgeRing = Square(art, "OVERLAY", V.BADGE_RING, 5, V.BADGE_X, V.BADGE_Y)
    if not (owner.badgeAtlas and Art(art.badgeRing, owner.badgeAtlas)) then Disc(art.badgeRing, {.78, .6, .26}) end
    art.badge = Square(art, "OVERLAY", V.BADGE, 6, V.BADGE_X, V.BADGE_Y)
    art.badge:SetTexCoord(.08, .92, .08, .92)
    Round(art, art.badge)
    art.glint = Lit(Square(art, "OVERLAY", V.GLINT, 7, V.BADGE_X, V.BADGE_Y), ART.spark)
    art.glint:SetAlpha(0)
    art.glint:Hide()
    art.badgeRing:Hide()
    art.badge:Hide()
end
local function MakeArt(owner, cell)
    local art = CreateFrame("Frame", nil, cell)
    art:SetSize(V.CELL, V.CELL)
    art:SetPoint("CENTER", cell, "CENTER", 0, 0)
    art.glow = Lit(Square(art, "BACKGROUND", V.GLOW), ART.glow)
    art.glow:Hide()
    art.relicGlow = Lit(Square(art, "BACKGROUND", V.RELIC_GLOW, 1), ART.glow, PAINT.gold)
    art.relicGlow:SetAlpha(.6)
    art.relicGlow:Hide()
    art.rim = Square(art, "BORDER", V.PLATE_RIM)
    art.plate = Square(art, "BORDER", V.PLATE, 1)
    art.sheen = Lit(Square(art, "BORDER", V.SHEEN, 2, 0, 6), V.MASK, PAINT.white)
    art.sheen:SetAlpha(.14)
    art.face = Square(art, "ARTWORK", V.FACE)
    local mask = Round(art, art.face)
    art.full = Square(art, "ARTWORK", V.FACE, 1)
    art.full:SetTexture(Blast.ICONS.hearth)
    art.full:SetTexCoord(.08, .92, .08, .92)
    Round(art, art.full, mask)
    art.full:Hide()
    art.block = Square(art, "ARTWORK", V.CRATE, 2)
    art.block:Hide()
    art.ice = Square(art, "OVERLAY", V.ICE)
    art.ice:Hide()
    art.web = Square(art, "OVERLAY", V.WEB, 1)
    art.web:Hide()
    art.count = MG.Text(art, "", 12, false, true)
    art.count:SetPoint("BOTTOMRIGHT", art, "BOTTOMRIGHT", -5, 5)
    art.count:SetJustifyH("RIGHT")
    art.flash = Lit(Square(art, "OVERLAY", V.FACE + 6, 7), V.MASK)
    art.flash:Hide()
    -- The pointer over a piece: a soft light over its plate (the cell's own
    -- highlight sits under the piece, so it hardly shows).
    art.hover = Lit(Square(art, "OVERLAY", V.HOVER, 7), V.MASK, PAINT.pick)
    art.hover:SetAlpha(.22)
    art.hover:Hide()
    MakeMarks(owner, art)
    art:Hide()
    return art
end
local function MakeCell(owner, board, index)
    local r, c = Cell(index)
    local cell = CreateFrame("Button", nil, board)
    cell:SetSize(V.CELL, V.CELL)
    cell:SetPoint("TOPLEFT", board, "TOPLEFT", (c - 1) * V.CELL, -(r - 1) * V.CELL)
    cell.index = index
    cell.tile = Square(cell, "BACKGROUND", V.TILE)
    cell.oil = Square(cell, "BACKGROUND", V.OIL, 2)
    cell.oil:Hide()
    cell.hover = Square(cell, "HIGHLIGHT", V.TILE)
    cell.hover:SetColorTexture(1, .9, .6, .18)
    cell.hover:SetBlendMode("ADD")
    cell.art = MakeArt(owner, cell)
    cell.dx, cell.dy, cell.alpha, cell.scale = 0, 0, 1, 1
    cell:RegisterForClicks("LeftButtonDown", "RightButtonDown")
    cell:SetScript("OnClick", function(self, button) owner:Pick(self.index, button) end)
    cell:SetScript("OnEnter", function(self)
        self.art.hover:SetShown(not self.hole and self.piece ~= nil)
        owner:Drag(self.index)
    end)
    cell:SetScript("OnLeave", function(self) self.art.hover:Hide() end)
    return cell
end

-- The board's rim (flat metal, never a gradient) and the dark line inside it.
local function Plate(parent, sublevel, out)
    local plate = parent:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    plate:SetSize(V.BOARD + 2 * out, V.BOARD + 2 * out)
    plate:SetPoint("TOPLEFT", parent, "TOPLEFT", V.LEFT - out, -V.TOP + out)
    return plate
end
local function MakeTop(self)
    local top = CreateFrame("Frame", nil, self.board)
    top:SetSize(V.BOARD, V.BOARD)
    top:SetPoint("TOPLEFT", self.board, "TOPLEFT", 0, 0)
    top:SetFrameLevel(self.play:GetFrameLevel() + V.LEVEL.top)
    self.top = top
    self.flashes = {}
    for k = 1, V.FLASHES do
        local flash = top:CreateTexture(nil, "ARTWORK")
        flash:SetColorTexture(1, .86, .45, 1)
        flash:SetBlendMode("ADD")
        flash:Hide()
        self.flashes[k] = flash
    end
    self.freeStreaks = {}
    for k = 1, V.STREAKS do
        local streak = top:CreateTexture(nil, "OVERLAY")
        streak:SetSize(120, 26)
        streak:SetPoint("CENTER", top, "TOPLEFT", 0, 0)
        Lit(streak, ART.streak, PAINT.special.charge)
        streak.owner, streak.home = self, top
        streak:Hide()
        self.freeStreaks[k] = streak
    end
end
-- Over the board's edge: the exits' arrows (they reach past the board's bottom).
local function MakeOver(self)
    local over = CreateFrame("Frame", nil, self.play)
    over:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    over:SetPoint("TOPLEFT", self.play, "TOPLEFT", 0, 0)
    over:SetFrameLevel(self.play:GetFrameLevel() + V.LEVEL.over)
    self.over = over
    self.exits = {}
    for c = 1, V.EXITS do
        local exit = over:CreateTexture(nil, "ARTWORK")
        exit:SetSize(V.EXIT_W, V.EXIT_H)
        exit:SetPoint("TOP", over, "TOPLEFT", V.LEFT + (c - .5) * V.CELL, -(V.BOTTOM - V.EXIT_IN))
        exit:Hide()
        self.exits[c] = exit
    end
end
local function MakeFlyer(self, sky)
    local fly = CreateFrame("Frame", nil, sky)
    fly:SetSize(48, 48)
    fly:SetPoint("CENTER", sky, "TOPLEFT", 0, 0)
    fly.glow = Lit(Square(fly, "BACKGROUND", 40), ART.glow)
    fly.icon = Square(fly, "ARTWORK", 24)
    fly.icon:SetTexCoord(.08, .92, .08, .92)
    fly.owner, fly.home = self, sky
    fly:Hide()
    return fly
end
-- Over everything in the play area (under the cards): the picked piece's
-- ring, the hint's glows, flying icons and the Hearthstone's swirls.
local function MakeSky(self)
    local sky = CreateFrame("Frame", nil, self.play)
    sky:SetSize(MG.CONTENT_W, MG.CONTENT_H)
    sky:SetPoint("TOPLEFT", self.play, "TOPLEFT", 0, 0)
    sky:SetFrameLevel(self.play:GetFrameLevel() + V.LEVEL.sky)
    self.sky = sky
    local picker = {}
    picker.glow = Lit(sky:CreateTexture(nil, "BORDER"), ART.glow, PAINT.gold)
    picker.glow:SetSize(V.PICK + 14, V.PICK + 14)
    picker.ring = Lit(sky:CreateTexture(nil, "ARTWORK"), ART.ring, PAINT.pick)
    picker.ring:SetSize(V.PICK, V.PICK)
    picker.glow:Hide()
    picker.ring:Hide()
    self.picker = picker
    self.hintGlows = {}
    for k = 1, 2 do
        local glow = sky:CreateTexture(nil, "ARTWORK", nil, 1)
        glow:SetSize(V.HINT, V.HINT)
        if Art(glow, V.HINT_ATLAS, ART.ring) ~= "atlas" then glow:SetVertexColor(PAINT.hint[1], PAINT.hint[2], PAINT.hint[3], 1) end
        glow:SetBlendMode("ADD")
        glow:Hide()
        self.hintGlows[k] = glow
    end
    self.freeFlyers = {}
    for k = 1, V.FLYERS do self.freeFlyers[k] = MakeFlyer(self, sky) end
    self.freeSwirls = {}
    for k = 1, V.SWIRLS do
        local swirl = sky:CreateTexture(nil, "ARTWORK", nil, 2)
        swirl:SetSize(40, 40)
        swirl:SetPoint("CENTER", sky, "TOPLEFT", 0, 0)
        Art(swirl, V.SWIRL_ATLAS, ART.glowRing)
        swirl:SetBlendMode("ADD")
        swirl:SetVertexColor(.35, .62, 1, 1)
        swirl.owner, swirl.home = self, sky
        swirl:Hide()
        self.freeSwirls[k] = swirl
    end
end

-- The board in play (a frame of the play area, 412 x 500).
function game:MakeBoard(shell, play)
    self.badgeAtlas = HasAtlas(V.BADGE_ATLAS) and V.BADGE_ATLAS or nil
    Plate(play, 1, 9):SetColorTexture(0, 0, 0, .35)
    self.rim = Plate(play, 2, V.RIM)
    Plate(play, 3, 1):SetColorTexture(0, 0, 0, 1)
    local board = CreateFrame("Frame", nil, play)
    board:SetSize(V.BOARD, V.BOARD)
    -- Pinned by two corners, as Forever wants of a frame that clips.
    board:SetPoint("TOPLEFT", play, "TOPLEFT", V.LEFT, -V.TOP)
    board:SetPoint("BOTTOMRIGHT", play, "TOPLEFT", V.LEFT + V.BOARD, -V.BOTTOM)
    board:SetFrameLevel(play:GetFrameLevel() + V.LEVEL.board)
    -- New pieces drop in from above it: only what's on the board shows.
    if board.SetClipsChildren then board:SetClipsChildren(true) end
    local back = board:CreateTexture(nil, "BACKGROUND", nil, -8)
    back:SetAllPoints(board)
    back:SetColorTexture(.012, .012, .016, 1)
    self.board = board
    self.cells = {}
    for index = 1, CELLS do self.cells[index] = MakeCell(self, board, index) end
    MakeTop(self)
    MakeOver(self)
    MakeSky(self)
end

-- Drawing ----------------------------------------------------------------------------------------

-- The board's look: "stone" (the old slate) or a zone's ground in its tint,
-- alternate cells a shade darker, holes with no tile; the rim your side's
-- metal warmed by the zone's colour.
function game:Look(key)
    self.look = key or "stone"
    local faction = self:Faction()
    local metal = PAINT.metal[faction] or PAINT.metal.Alliance
    local tint
    if self.look ~= "stone" then
        local zone
        for _, each in ipairs(Blast.ZONES or EMPTY) do if each.key == self.look then zone = each end end
        local fallback = zone and zone.tint or {.6, .6, .6}
        tint = {MG:Colour3("zone." .. self.look .. ".tint", fallback)}
    end
    local state = self.state
    for index, cell in ipairs(self.cells or EMPTY) do
        local r, c = Cell(index)
        local light = (r + c) % 2 == 0
        local tile = cell.tile
        local left, top, span = (c - 1) * V.CELL / 256, (r - 1) * V.CELL / 256, V.TILE / 256
        if tint then
            local k = (light and 1 or .85) * V.TILE_SHADE
            local dark = {tint[1] * k * .3, tint[2] * k * .3, tint[3] * k * .3, 1}
            MG:Art(tile, "zone." .. self.look .. ".ground", {wrap = "REPEAT", coords = {left, left + span, top, top + span},
                tint = {tint[1] * k, tint[2] * k, tint[3] * k}, plain = true, colour = dark})
        elseif tile:SetTexture(V.STONE, "REPEAT", "REPEAT") ~= false then
            tile:SetTexCoord(left, left + span, top, top + span)
            local k = light and 1 or .8
            tile:SetVertexColor(k * .92, k * .94, k, 1)
        else
            local k = light and .1 or .075
            tile:SetColorTexture(k, k * 1.04, k * 1.18, 1)
        end
        local hole = state ~= nil and Blast.Hole ~= nil and Blast.Hole(state, index) or false
        cell.hole = hole
        tile:SetShown(not hole)
        cell.hover:SetShown(not hole)
    end
    if self.rim then
        local r, g, b = metal[1], metal[2], metal[3]
        if tint then r, g, b = r * .65 + tint[1] * .35, g * .65 + tint[2] * .35, b * .65 + tint[3] * .35 end
        self.rim:SetColorTexture(r, g, b, 1)
        self.rimColour = {r, g, b}
    end
    self:PaintExits()
end
-- The exits' arrows under their cells (levels with relics).
function game:PaintExits()
    local exits = self.state and self.state.exits or EMPTY
    for c, arrow in ipairs(self.exits or EMPTY) do
        if exits[(N - 1) * N + c] == true then MG:Art(arrow, "exit") else arrow:Hide() end
    end
end
-- Oil under a cell, as shown now (self.oil, which a move's beats change step by step).
function game:PaintOil(index)
    local cell = self.cells and self.cells[index]
    if not cell then return end
    local layers = self.oil[index] or 0
    if layers <= 0 or cell.hole then
        cell.oil:Hide()
        return
    end
    MG:Art(cell.oil, layers >= 2 and "block.oil2" or "block.oil")
    cell.oil:SetAlpha(.9)
end
-- The oil as the rules hold it now (Free play: none).
function game:SyncOil()
    local cells = self.state and self.state.cells or EMPTY
    for index = 1, CELLS do
        local info = cells[index]
        self.oil[index] = info and info.oil or 0
        self:PaintOil(index)
    end
end
-- A special's marks: its own icon drawn whole where the face was (as a
-- Hearthstone's is), on its race's plate, with the race's face small in the
-- corner ring in a light of the special's colour; a glint, its glow, and a
-- Charge's line across or down.
function game:Mark(art, piece)
    local special = piece.special
    local icon = self:Badge(special)
    local race = icon and not piece.block and Blast.RACE[piece.kind] or nil
    if icon or special == "hearth" then
        art.full:SetTexture(icon or Blast.ICONS.hearth)
        art.full:SetTexCoord(.08, .92, .08, .92)
    end
    if icon then
        art.full:SetShown(true)
        art.face:SetShown(false)
    end
    art.badged = race ~= nil
    art.badge:SetShown(art.badged)
    art.badgeRing:SetShown(art.badged)
    art.badgeGlow:SetShown(art.badged)
    if race then
        Blast.PutFace(art.badge, race)
        art.badge:SetSize(V.BADGE, V.BADGE)
    end
    local colour = special and PAINT.special[special]
    art.glow:SetShown(colour ~= nil)
    art.glint:SetShown(colour ~= nil)
    art.glint:SetAlpha(0)
    art.glinting = nil
    if colour then
        art.glow:SetVertexColor(colour[1], colour[2], colour[3], 1)
        art.badgeGlow:SetVertexColor(colour[1], colour[2], colour[3], 1)
        -- The glint: a paler light of the same colour.
        art.glint:SetVertexColor((1 + colour[1]) / 2, (1 + colour[2]) / 2, (1 + colour[3]) / 2, 1)
    end
    art.charge = special == "charge"
    if art.charge then
        if piece.dir == "col" then
            art.streak:SetSize(10, V.FACE + 8)
            art.streak:SetTexCoord(0, 1, 0, 1)
        else
            -- The spark's art stands up: turned to lie across.
            art.streak:SetSize(V.FACE + 8, 10)
            art.streak:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
        end
    end
    art.streak:SetShown(art.charge)
end
-- A blocker in a piece's place: a crate (its hits), a skull or a relic.
local function DressBlock(art, piece)
    local block = piece.block
    art.relicGlow:SetShown(block == "relic")
    if block == "crate" then
        art.block:SetSize(V.CRATE, V.CRATE)
        MG:Art(art.block, (piece.hits or 1) <= 1 and "block.crateCrack" or "block.crate")
        art.count:SetText((piece.hits or 1) >= 3 and tostring(piece.hits) or "")
    elseif block == "skull" then
        art.block:SetSize(V.SKULL, V.SKULL)
        MG:Art(art.block, "block.skull")
        art.count:SetText("")
    elseif block == "relic" then
        art.block:SetSize(V.RELIC, V.RELIC)
        MG:Art(art.block, "relic." .. (piece.relic or 1))
        art.count:SetText("")
    else
        art.block:Hide()
        art.count:SetText("")
    end
end
-- A cell shows a piece (nil: empty).
function game:Dress(cell, piece)
    if cell.piece == piece then return end
    cell.piece = piece
    local art = cell.art
    if not piece then
        art:Hide()
        cell.shiny = nil
        return
    end
    art:Show()
    local hearth = piece.special == "hearth"
    local race = not piece.block and not hearth and Blast.RACE[piece.kind] or nil
    local plated = race ~= nil or hearth
    if race then
        if art.raceShown ~= race.id then
            art.raceShown = race.id
            self:PaintPlate(art.plate, art.rim, race.id, V.PLATE)
            art.face.how = Blast.PutFace(art.face, race)
        end
        local pip = PAINT.pip[race.faction]
        art.pip:SetVertexColor(pip[1], pip[2], pip[3], 1)
    elseif hearth then
        art.raceShown = nil
        local plate = PAINT.hearthPlate
        Disc(art.plate, plate)
        Disc(art.rim, {plate[1] * .5, plate[2] * .5, plate[3] * .5})
        art.plate:SetSize(V.PLATE, V.PLATE)
        art.rim:SetSize(V.PLATE_RIM, V.PLATE_RIM)
    end
    art.plate:SetShown(plated)
    art.rim:SetShown(plated)
    art.sheen:SetShown(plated)
    art.face:SetShown(race ~= nil)
    art.full:SetShown(hearth)
    art.pip:SetShown(race ~= nil)
    art.pipRim:SetShown(race ~= nil)
    DressBlock(art, piece)
    if piece.ice then MG:Art(art.ice, piece.ice >= 2 and "block.ice" or "block.iceCrack") else art.ice:Hide() end
    if piece.web then MG:Art(art.web, "block.web") else art.web:Hide() end
    self:Mark(art, piece)
    cell.shiny = piece.special ~= nil
end

-- A piece's place, size and fade in its cell. Its offsets are in its own
-- (scaled) units, so a piece popping as it falls stays on its path.
local function Place(cell)
    local scale = cell.scale
    cell.art:SetPoint("CENTER", cell, "CENTER", cell.dx / scale, cell.dy / scale)
end
local function Offset(cell, dx, dy)
    if cell.dx == dx and cell.dy == dy then return end
    cell.dx, cell.dy = dx, dy
    Place(cell)
end
local function Scale(cell, scale)
    if cell.scale == scale then return end
    cell.scale = scale
    cell.art:SetScale(scale)
    if cell.dx ~= 0 or cell.dy ~= 0 then Place(cell) end
end
local function Fade(cell, alpha)
    if cell.alpha == alpha then return end
    cell.alpha = alpha
    cell.art:SetAlpha(alpha)
end
MG.BlastView.Offset, MG.BlastView.Scale, MG.BlastView.Fade = Offset, Scale, Fade
function game:Paint(board)
    for index, cell in ipairs(self.cells or EMPTY) do self:Dress(cell, board[index]) end
end
-- The board as the rules hold it now: pieces and oil.
function game:PaintCells()
    if not (self.cells and self.state) then return end
    self:Paint(self.state.board)
    self:SyncOil()
end
-- The picked piece: a pale ring round it, pulsing, the piece a little bigger.
function game:Select(index)
    local old = self.selected
    self.selected = index
    if old and self.cells and old ~= index and not self.busy then Scale(self.cells[old], 1) end
    local picker = self.picker
    if not picker then return end
    picker.on = index ~= nil
    if index then
        local art = self.cells[index].art
        picker.ring:ClearAllPoints()
        picker.ring:SetPoint("CENTER", art, "CENTER", 0, 0)
        picker.glow:ClearAllPoints()
        picker.glow:SetPoint("CENTER", art, "CENTER", 0, 0)
        Scale(self.cells[index], 1.1)
    end
    picker.ring:SetShown(picker.on)
    picker.glow:SetShown(picker.on)
end
-- Every piece back in its place, whole; the lit areas gone.
function game:Calm()
    for _, cell in ipairs(self.cells or EMPTY) do
        Offset(cell, 0, 0)
        Fade(cell, 1)
        Scale(cell, cell.index == self.selected and 1.1 or 1)
        if cell.flashing then
            cell.flashing = nil
            cell.art.flash:Hide()
        end
        cell.drop, cell.hop, cell.made = nil, nil, nil
    end
    for _, flash in ipairs(self.flashes or EMPTY) do flash:Hide() end
end
-- The areas a blast lit ({top row, left column, bottom row, right column}).
function game:LightAreas(rects)
    local used = 0
    for _, rect in ipairs(rects or EMPTY) do
        used = used + 1
        local flash = self.flashes[used]
        if not flash then break end
        flash:ClearAllPoints()
        flash:SetPoint("TOPLEFT", self.top, "TOPLEFT", (rect[2] - 1) * V.CELL, -(rect[1] - 1) * V.CELL)
        flash:SetSize((rect[4] - rect[2] + 1) * V.CELL, (rect[3] - rect[1] + 1) * V.CELL)
        flash:SetAlpha(.45)
        flash:Show()
    end
end

-- A special's glint: every GLINT_EVERY seconds (t: each cell's own clock) a
-- pale star swells on its badge, turning a little as it goes, and fades.
local function Glint(art, t)
    local share = (t % V.GLINT_EVERY) / V.GLINT_LIFE
    if share >= 1 then
        if art.glinting then
            art.glinting = nil
            art.glint:SetAlpha(0)
        end
        return
    end
    art.glinting = true
    local s = math.sin(math.pi * share)
    local size = math.max(1, V.GLINT * s)
    art.glint:SetSize(size, size)
    art.glint:SetAlpha(.9 * s)
    if art.glint.SetRotation then art.glint:SetRotation(share * math.pi / 2) end
end
-- What moves while nothing is played: the picked piece's ring pulsing, a
-- hint's pieces bobbing, the specials shimmering (the edge glow is the
-- HUD's): their glow, badge and its light pulse, their glint flares now and then.
function game:Shine(dt)
    local t = self.clock
    local picker = self.picker
    if picker and picker.on then
        local s = .5 + .5 * math.sin(t * 7)
        local size = V.PICK + 5 * s
        picker.ring:SetAlpha(.55 + .45 * s)
        picker.ring:SetSize(size, size)
        picker.glow:SetAlpha(.3 + .2 * s)
    end
    if self.hintA then self:Bob(dt) end
    for _, cell in ipairs(self.cells) do
        if cell.shiny then
            local art = cell.art
            local s = .5 + .5 * math.sin(t * 3.2 + cell.index * .9)
            local size = V.GLOW * (.92 + .14 * s)
            art.glow:SetAlpha(.55 + .45 * s)
            art.glow:SetSize(size, size)
            if art.badged then
                -- The badge swells inside its ring, by 7% at most; the ring stays put, inside the cell.
                local k = 1 + .07 * s
                art.badge:SetSize(V.BADGE * k, V.BADGE * k)
                art.badgeGlow:SetAlpha(.5 + .45 * s)
            end
            if art.charge then art.streak:SetAlpha(.5 + .5 * s) end
            Glint(art, t + cell.index * .37)
        end
    end
    if self.MoveEdge then self:MoveEdge(dt) end
    if self.ShineHud then self:ShineHud(dt) end
end

-- Hints -------------------------------------------------------------------------------------------

-- The best move's two pieces glow and lean towards each other, until the
-- next click. asked: by the Hint button (with a click), which in a level
-- serves its goals (Blast.GoalHint); the one that shows by itself after a
-- while is only the biggest clear (Blast.Hint), so a level never plays itself.
-- Either kind starts the cooldown both wait for (the window's clock, so
-- closing the window doesn't run it down).
function game:HintWait()
    return math.max(0, (self.hintReady or 0) - self.clock)
end
function game:ShowHint(asked)
    if self.busy or not (self.state and self.cells) or self.state.outcome or self:HintWait() > 0 then return false end
    local a, b
    if self.state.mode == "level" and asked then a, b = Blast.GoalHint(self.state) else a, b = Blast.Hint(self.state.board) end
    if not a then return false end
    self:ClearHint()
    self.hintA, self.hintB, self.hintT = a, b, 0
    self.hintReady = self.clock + Blast.HINT_COOLDOWN
    local glows = self.hintGlows
    glows[1]:ClearAllPoints()
    glows[1]:SetPoint("CENTER", self.cells[a].art, "CENTER", 0, 0)
    glows[2]:ClearAllPoints()
    glows[2]:SetPoint("CENTER", self.cells[b].art, "CENTER", 0, 0)
    glows[1]:SetAlpha(.5)
    glows[2]:SetAlpha(.5)
    glows[1]:Show()
    glows[2]:Show()
    MG:Note(NOTES.hint)
    if asked then MG:Sound("uiClick") end
    return true
end
function game:ClearHint()
    local a, b = self.hintA, self.hintB
    self.hintA, self.hintB, self.idle = nil, nil, 0
    for _, glow in ipairs(self.hintGlows or EMPTY) do glow:Hide() end
    if a and self.cells and not self.busy then
        Offset(self.cells[a], 0, 0)
        Offset(self.cells[b], 0, 0)
    end
end
function game:Bob(dt)
    self.hintT = (self.hintT or 0) + dt
    local lean = 3.5 * (.5 - .5 * math.cos(self.hintT * math.pi * 3))
    local ra, ca = Cell(self.hintA)
    local rb, cb = Cell(self.hintB)
    local dx, dy = (cb - ca) * lean, (ra - rb) * lean
    Offset(self.cells[self.hintA], dx, dy)
    Offset(self.cells[self.hintB], -dx, -dy)
    local alpha = .5 + .5 * lean / 3.5
    self.hintGlows[1]:SetAlpha(alpha)
    self.hintGlows[2]:SetAlpha(alpha)
end

-- Effects ----------------------------------------------------------------------------------------

-- A cell's middle from the play area's top left (the sky's), and from the board's.
local function SkySpot(i)
    local r, c = Cell(i)
    return V.LEFT + (c - .5) * V.CELL, -(V.TOP + (r - .5) * V.CELL)
end
local function BoardSpot(i)
    local r, c = Cell(i)
    return (c - .5) * V.CELL, -(r - .5) * V.CELL
end
MG.BlastView.SkySpot = SkySpot
local function Middle(region)
    if not region or type(region.GetCenter) ~= "function" then return nil end
    local ok, x, y = pcall(region.GetCenter, region)
    if ok and type(x) == "number" and type(y) == "number" then return x, y end
    return nil
end
-- Where the header's score is, from the play area's top left.
function game:ScoreSpot()
    local shell, holder = MG.window, self.holder
    local x, y = Middle(shell and shell.score)
    if x and holder and type(holder.GetLeft) == "function" and type(holder.GetTop) == "function" then
        local left, top = holder:GetLeft(), holder:GetTop()
        if type(left) == "number" and type(top) == "number" then return x - left, y - top end
    end
    return V.SCORE_X, V.SCORE_Y
end
-- A sound once in a beat, however many of its pieces want it.
function game:Once(name)
    if self.heard[name] == self.stamp then return end
    self.heard[name] = self.stamp
    MG:Sound(name)
end

-- Flying icons: loot from a cleared piece to the score, a flyer to its
-- target, a relic to its goal. One frame of one: it may rise out of its
-- cell first (wait), then flies a curve to its end, shrinking on the way.
local function FlyStep(share, fly)
    local t, rise = 0, 0
    if share < fly.wait then
        rise = fly.rise * math.sin(share / fly.wait * math.pi / 2)
    else
        t = (share - fly.wait) / (1 - fly.wait)
        t = t * t
        rise = fly.rise * (1 - t)
    end
    local u = 1 - t
    local x = u * u * fly.x0 + 2 * u * t * fly.cx + t * t * fly.x1
    local y = u * u * fly.y0 + 2 * u * t * fly.cy + t * t * fly.y1 + rise
    fly:SetPoint("CENTER", fly.home, "TOPLEFT", x, y)
    local grow = share < fly.wait and (.55 + .45 * share / fly.wait) or (1 - fly.shrink * t)
    local size = fly.size * grow
    fly.icon:SetSize(size, size)
    fly.glow:SetSize(size * 1.8, size * 1.8)
    fly:SetAlpha(share > .85 and (1 - share) / .15 or 1)
end
local function FlyDone(fly, cleared)
    fly:Hide()
    local owner = fly.owner
    owner.freeFlyers[#owner.freeFlyers + 1] = fly
    if cleared then return end
    if fly.ding then MG:Sound(fly.epic and "coins" or "coin") end
    if fly.land and owner.cells then
        local cell = owner.cells[fly.land]
        MG:Pulse(cell, OPTS.land)
        MG:Burst(cell, OPTS.landSpark)
    end
    if fly.chime then MG:Sound("chime") end
end
function game:TakeFlyer()
    local free = self.freeFlyers
    local fly = free and free[#free]
    if not fly then return nil end
    free[#free] = nil
    fly.icon:SetTexCoord(.08, .92, .08, .92)
    fly.icon:SetVertexColor(1, 1, 1, 1)
    fly.chime = nil
    return fly
end
function game:Launch(fly, life)
    FlyStep(0, fly)
    fly:Show()
    MG:Tween(life, FlyStep, FlyDone, fly)
end
-- A cleared piece's loot, popping up and flying to the score. order: its
-- place among this clear's (the first rings as it arrives).
function game:FlyLoot(gone, order, tx, ty)
    local fly = self:TakeFlyer()
    if not fly then return false end
    fly.icon:SetTexture(gone.loot)
    local glow = gone.epic and PAINT.epic or PAINT.gold
    fly.glow:SetVertexColor(glow[1], glow[2], glow[3], 1)
    fly.glow:SetAlpha(gone.epic and 1 or .55)
    local x, y = SkySpot(gone.i)
    fly.x0, fly.y0, fly.x1, fly.y1 = x, y, tx, ty
    fly.cx, fly.cy = x + (tx - x) * .2, math.max(y, ty) + 40
    fly.wait, fly.rise, fly.shrink, fly.size = .22, 12, .45, gone.epic and 30 or 24
    fly.ding, fly.epic, fly.land = order == 0, gone.epic and true or false, nil
    self:Launch(fly, .62 + .06 * order)
    return true
end
-- A Gryphon or Wind Rider swooping from its cell to its target.
function game:Swoop(from, to)
    local fly = self:TakeFlyer()
    if not fly then return false end
    fly.icon:SetTexture(self:Badge("flyer"))
    local glow = PAINT.special.flyer
    fly.glow:SetVertexColor(glow[1], glow[2], glow[3], 1)
    fly.glow:SetAlpha(.9)
    local x0, y0 = SkySpot(from)
    local x1, y1 = SkySpot(to)
    fly.x0, fly.y0, fly.x1, fly.y1 = x0, y0, x1, y1
    fly.cx, fly.cy = (x0 + x1) / 2, math.max(y0, y1) + 60
    fly.wait, fly.rise, fly.shrink, fly.size = 0, 0, 0, 30
    fly.ding, fly.epic, fly.land = false, false, to
    self:Launch(fly, .26)
    return true
end
-- A relic leaving by its exit: it drops through the arrow, then flies to its goal.
function game:FlyRelic(gone, tx, ty)
    local fly = self:TakeFlyer()
    if not fly then return false end
    if MG:Art(fly.icon, "relic." .. (gone.piece.relic or 1)) == nil then fly.icon:SetTexture(Blast.EPIC_LOOT[1]) end
    fly.icon:Show()
    fly.glow:SetVertexColor(PAINT.gold[1], PAINT.gold[2], PAINT.gold[3], 1)
    fly.glow:SetAlpha(1)
    local x, y = SkySpot(gone.i)
    fly.x0, fly.y0, fly.x1, fly.y1 = x, y, tx, ty
    fly.cx, fly.cy = x, -(V.BOTTOM + 30)
    fly.wait, fly.rise, fly.shrink, fly.size = 0, 0, .3, 34
    fly.ding, fly.epic, fly.land, fly.chime = false, false, nil, true
    self:Launch(fly, .55)
    return true
end

-- A Charge's streak: its size and texture coords for the way it heads, its
-- bright head first (the art's head is on its left).
local function Head(streak, way)
    if way == "left" then
        streak:SetSize(120, 26)
        streak:SetTexCoord(0, 1, 0, 1)
    elseif way == "right" then
        streak:SetSize(120, 26)
        streak:SetTexCoord(1, 0, 0, 1)
    elseif way == "up" then
        streak:SetSize(26, 120)
        streak:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1)
    else
        streak:SetSize(26, 120)
        streak:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
    end
end
local function StreakStep(share, streak)
    local x = streak.x0 + (streak.x1 - streak.x0) * share
    local y = streak.y0 + (streak.y1 - streak.y0) * share
    streak:SetPoint("CENTER", streak.home, "TOPLEFT", x, y)
    streak:SetAlpha(share < .7 and 1 or (1 - share) / .3)
end
local function StreakDone(streak)
    streak:Hide()
    local free = streak.owner.freeStreaks
    free[#free + 1] = streak
end
function game:Streak(x0, y0, x1, y1, way)
    local free = self.freeStreaks
    local streak = free and free[#free]
    if not streak then return false end
    free[#free] = nil
    Head(streak, way)
    streak.x0, streak.y0, streak.x1, streak.y1 = x0, y0, x1, y1
    StreakStep(0, streak)
    streak:Show()
    MG:Tween(.3, StreakStep, StreakDone, streak)
    return true
end
-- Two streaks from a cell to both ends of its row or its column.
function game:Streaks(i, dir)
    local x, y = BoardSpot(i)
    if dir == "col" then
        self:Streak(x, y, x, 70, "up")
        self:Streak(x, y, x, -V.BOARD - 70, "down")
    else
        self:Streak(x, y, -70, y, "left")
        self:Streak(x, y, V.BOARD + 70, y, "right")
    end
end

-- The Hearthstone's blue swirl, spinning out from a cell.
local function SwirlStep(share, swirl)
    local size = swirl.size * (.35 + .65 * (1 - (1 - share) * (1 - share)))
    swirl:SetSize(size, size)
    if swirl.SetRotation then swirl:SetRotation(-share * math.pi * 3) end
    swirl:SetAlpha(share < .2 and share / .2 or (1 - share) / .8)
end
local function SwirlDone(swirl)
    swirl:Hide()
    if swirl.SetRotation then swirl:SetRotation(0) end
    local free = swirl.owner.freeSwirls
    free[#free + 1] = swirl
end
function game:Swirl(i, big)
    local free = self.freeSwirls
    local swirl = free and free[#free]
    if swirl then
        free[#free] = nil
        swirl.size = 100 * big
        local x, y = SkySpot(i)
        swirl:SetPoint("CENTER", swirl.home, "TOPLEFT", x, y)
        SwirlStep(0, swirl)
        swirl:Show()
        MG:Tween(.75, SwirlStep, SwirlDone, swirl)
    end
    MG:Burst(self.cells[i], OPTS.hearthSpark)
end
-- The Explosive Sheep's smoke, its shockwave and a flare.
function game:Poof(i, big)
    local cell, puff = self.cells[i], OPTS.puff
    puff.count, puff.size, puff.speed = math.floor(6 * big + .5), 26 * big, 64 * big
    MG:Burst(cell, puff)
    OPTS.shock.w, OPTS.shock.h = 120 * big, 120 * big
    MG:Pulse(cell, OPTS.shock)
    OPTS.flare.w, OPTS.flare.h = 88 * big, 88 * big
    MG:Pulse(cell, OPTS.flare)
end

-- A special caught in a clear, as it fires.
local FIRE = {}
function FIRE.charge(self, shot)
    self:Streaks(shot.i, shot.dir)
    self:Once("charge")
    self:Once("shout")
    MG:Shake(4, .28)
end
function FIRE.sheep(self, shot)
    self:Poof(shot.i, 1)
    self:Once("sheep")
    self:Once("boom")
    MG:Shake(6, .32)
end
function FIRE.flyer(self, shot)
    if shot.target then self:Swoop(shot.i, shot.target) end
    self:Once("whoosh")
end
function FIRE.hearth(self, shot)
    self:Swirl(shot.i, 1)
    self:Once("hearthCast")
    MG:Shake(5, .3)
end
-- Two specials swapped together (or a Hearthstone with a piece), as the
-- first clear of their move shows. Their areas centre on b.
local COMBO = {}
function COMBO.charges(self, beat)
    self:Streaks(beat.b, "row")
    self:Streaks(beat.b, "col")
    self:Once("charge")
    self:Once("shout")
    MG:Shake(7, .4)
end
function COMBO.sheeps(self, beat)
    self:Poof(beat.b, 1.8)
    self:Once("sheep")
    self:Once("boom")
    MG:Shake(9, .45)
end
function COMBO.chargesheep(self, beat)
    self:Streaks(beat.b, "row")
    self:Streaks(beat.b, "col")
    self:Poof(beat.b, 1.3)
    self:Once("charge")
    self:Once("boom")
    MG:Shake(8, .42)
end
function COMBO.hearth(self, beat)
    local swapped = beat.swapped
    local at = swapped and swapped[beat.b] and swapped[beat.b].special == "hearth" and beat.b or beat.a
    self:Swirl(at, 1.3)
    self:Once("hearthCast")
    self:Once("hearthArrive")
    for _, gone in ipairs(beat.step.cleared) do MG:Pulse(self.cells[gone.i], OPTS.hearthPulse) end
    MG:Shake(5, .35)
end
function COMBO.hearths(self, beat)
    self:Swirl(beat.a, 2)
    self:Swirl(beat.b, 2)
    self:Once("hearthCast")
    self:Once("hearthArrive")
    self:Once("boom")
    MG:Shake(11, .55)
end

-- The cleared pieces' sparks, each in its race's colour (a Hearthstone's blue).
local function Sparks(self, step)
    local opts = OPTS.spark
    opts.count = math.max(2, math.min(6, math.floor(72 / math.max(1, #step.cleared))))
    for _, gone in ipairs(step.cleared) do
        opts.colour = PAINT.race[gone.piece.kind] or PAINT.special.hearth
        MG:Burst(self.cells[gone.i], opts)
    end
end
-- Some of their loot flies to the score (every epic piece's).
local function Loot(self, step)
    local every = math.max(1, math.ceil(#step.cleared / V.LOOT_FLY))
    local tx, ty = self:ScoreSpot()
    local sent = 0
    for k, gone in ipairs(step.cleared) do
        if (gone.epic or (k - 1) % every == 0) and self:FlyLoot(gone, sent, tx, ty) then sent = sent + 1 end
    end
end
-- The clear's points rising from its middle; an epic piece's purple flash and its 50.
local function Points(self, step)
    local cleared = step.cleared
    local at = cleared[math.ceil(#cleared / 2)] or (step.broken and step.broken[1]) or (step.hits and step.hits[1])
    if not at or not step.points or step.points <= 0 then return end
    local opts = OPTS.points
    opts.colour = (step.mult or 1) > 1 and PAINT.lustText[self:Faction()] or PAINT.gold
    opts.size = math.min(26, 17 + math.floor(#cleared / 3))
    MG:FloatText(self.cells[at.i], "+" .. step.points, opts)
    if (step.epics or 0) <= 0 then return end
    for _, gone in ipairs(cleared) do
        if gone.epic then
            local cell = self.cells[gone.i]
            MG:Pulse(cell, OPTS.epicPulse)
            MG:Burst(cell, OPTS.epicSpark)
            MG:FloatText(cell, "Epic! +" .. Blast.EPIC_BONUS * (step.mult or 1), OPTS.epicText)
        end
    end
    if self.epicSound then
        self.epicSound = false
        MG:Sound("epic")
    end
end
-- A chain's step: a pop, from the second step a sound a step higher and a
-- word, and a shake for a long chain or a big clear.
local function Chain(self, step, index)
    MG:Sound("pop")
    if index >= 2 then MG:Sound("chain", index - 1) end
    if index >= 2 and self.clock >= (self.bannerUntil or 0) then
        local k = math.min(index, #CHAIN + 1) - 1
        local opts = OPTS.chain
        opts.colour, opts.glow = PAINT.chain[k], PAINT.chain[k]
        opts.sub = index >= 4 and NOTES.chain:format(index) or nil
        MG:Banner(CHAIN[k], opts)
    end
    if index >= 3 then
        MG:Shake(2 + index, .3)
    elseif #step.cleared >= 4 then
        MG:Shake(2.5, .22)
    end
end
-- Blockers hit in a clear: ice cracks or shatters, webs tear, crates
-- splinter, skulls burst, oil splashes away (a sound for each kind, once).
local HIT_SOUND = {ice = "iceCrack", oil = "oilSplat", crate = "crateBreak", skull = "crateBreak", web = "pop"}
local function Hits(self, step)
    local bits = OPTS.bits
    for _, hit in ipairs(step.hits or EMPTY) do
        local cell = self.cells[hit.i]
        local art, what, left = cell.art, hit.what, hit.left or 0
        bits.colour = PAINT.bits[what] or PAINT.white
        if what == "oil" then
            self.oil[hit.i] = left
            self:PaintOil(hit.i)
            OPTS.splat.colour = PAINT.bits.oil
            MG:Burst(cell, OPTS.splat)
        elseif what == "ice" then
            if left > 0 then MG:Art(art.ice, "block.iceCrack") else art.ice:Hide() end
            OPTS.crack.colour = PAINT.bits.ice
            MG:Pulse(cell, OPTS.crack)
            MG:Burst(cell, bits)
        elseif what == "crate" then
            if left > 0 then
                MG:Art(art.block, left <= 1 and "block.crateCrack" or "block.crate")
                art.count:SetText(left >= 3 and tostring(left) or "")
                MG:Pop(art, {peak = 1.12, life = .2})
            end
            MG:Burst(cell, bits)
        elseif what == "skull" or what == "web" then
            if what == "web" then art.web:Hide() end
            MG:Burst(cell, bits)
        end
        if HIT_SOUND[what] then self:Once(HIT_SOUND[what]) end
    end
end
MG.BlastView.Hits = Hits

-- Bloodlust or Heroism starts: its roar (or cast), the drums, a banner (no
-- coloured glow behind it), sparks from the meter's icon, and the edge glow
-- (the HUD's PaintMeter).
function game:LustOn()
    self.lustPending = false
    local faction, name = self:Faction(), self:LustName()
    local colour = PAINT.lust[faction]
    local level = self.state and self.state.mode == "level"
    MG:Note((level and NOTES.lustMoves or NOTES.lust):format(name))
    MG:Sound(faction == "Alliance" and "heroism" or "bloodlust")
    if self.state and self.state.lust > 0 then MG:Sound("drums") end
    local opts = OPTS.lust
    opts.colour = PAINT.lustText[faction]
    opts.sub = level and "Double points for 3 moves" or "Double points for 10 seconds"
    MG:Banner(name .. "!", opts)
    self.bannerUntil = self.clock + 1.6
    OPTS.lustSpark.colour = colour
    if self.meter then MG:Burst(self.meter.icon, OPTS.lustSpark) end
    MG:Shake(5, .4)
    if self.PaintMeter then self:PaintMeter(true) end
end
function game:LustOver()
    local words = NOTES.over:format(self:LustName())
    if self.busy then self.after = words else MG:Note(words) end
    MG:StopSound("drums")
end

-- Playing out a move ----------------------------------------------------------------------------

function game:Queue(beat)
    beat.t = 0
    self.beats[#self.beats + 1] = beat
    self.busy = true
end
-- A fall takes longer the further its pieces drop.
local function FallTime(step)
    local most = 0
    for _, rows in pairs(step.fall or EMPTY) do if rows > most then most = rows end end
    return V.FALL + V.FALL_ROW * most
end
-- Each step of a result as its beats: a clear (its pops, then the fall), a
-- relic out (it flies off, then the fall) or the boss's strike.
function game:QueueSteps(result)
    local clears = 0
    for index, step in ipairs(result.steps or EMPTY) do
        local kind = step.kind or "clear"
        if kind == "boss" then
            self:Queue({kind = "boss", step = step, dur = V.BOSS})
        elseif kind == "exit" then
            self:Queue({kind = "exit", step = step, dur = V.EXIT})
            self:Queue({kind = "fall", step = step, dur = FallTime(step)})
        else
            clears = clears + 1
            local first = index == 1
            self:Queue({kind = "burst", step = step, index = step.index or clears, dur = V.BURST, a = result.a, b = result.b,
                combo = first and result.combo or nil, swapped = first and result.swapped or nil})
            self:Queue({kind = "fall", step = step, dur = FallTime(step)})
        end
    end
end

-- A falling piece's height over its place: faster and faster, it lands,
-- hops up a little and settles.
local function FallAt(share, drop, hop)
    if share >= 1 then return 0 end
    if share < V.LAND then
        local q = share / V.LAND
        return drop * (1 - q * q)
    end
    return (hop or 0) * math.sin(math.pi * (share - V.LAND) / (1 - V.LAND))
end
game.FallAt = FallAt

-- The beats: what each does as it starts, every frame (share: 0 to 1 of its time) and as it ends.
local BEGIN, DURING, FINISH = {}, {}, {}
MG.BlastView.BEGIN, MG.BlastView.DURING, MG.BlastView.FINISH = BEGIN, DURING, FINISH
local function Nothing() end
-- The swap slides (and back, with a boing, when it matched nothing).
function BEGIN.slide() MG:Sound("whoosh") end
function game:Buzz(beat)
    beat.buzzed = true
    MG:Sound("boing")
    MG:Pulse(self.cells[beat.a], OPTS.buzz)
    MG:Pulse(self.cells[beat.b], OPTS.buzz)
end
function DURING.slide(self, beat, share)
    local ra, ca = Cell(beat.a)
    local rb, cb = Cell(beat.b)
    local q = share
    if beat.back then
        q = share < .5 and share * 2 or (1 - share) * 2
        if share >= .5 and not beat.buzzed then self:Buzz(beat) end
    end
    local dx, dy = (cb - ca) * V.CELL * q, (ra - rb) * V.CELL * q
    Offset(self.cells[beat.a], dx, dy)
    Offset(self.cells[beat.b], -dx, -dy)
end
function FINISH.slide(self, beat)
    if beat.back and not beat.buzzed then self:Buzz(beat) end
    Offset(self.cells[beat.a], 0, 0)
    Offset(self.cells[beat.b], 0, 0)
    if beat.board then self:Paint(beat.board) end
    if beat.moves and self.ShowMoves then self:ShowMoves(beat.moves) end
end
-- A clear: the pieces flash, swell and pop, with everything they set off.
function BEGIN.burst(self, beat)
    local step = beat.step
    self.stamp = self.stamp + 1
    self:Paint(step.before)
    for _, list in ipairs({step.cleared, step.broken or EMPTY}) do
        for _, gone in ipairs(list) do
            local cell = self.cells[gone.i]
            cell.flashing = true
            cell.art.flash:SetAlpha(0)
            cell.art.flash:Show()
        end
    end
    self:LightAreas(step.flashes)
    self.shownScore, self.shownMeter = step.score, step.meter
    MG:SetScore(step.score)
    Sparks(self, step)
    Loot(self, step)
    Points(self, step)
    Hits(self, step)
    for _, shot in ipairs(step.fired or EMPTY) do
        local fire = FIRE[shot.special]
        if fire then fire(self, shot) end
    end
    local combo = beat.combo and COMBO[beat.combo]
    if combo then combo(self, beat) end
    if step.lust then self:LustOn() end
    Chain(self, step, beat.index or 1)
    if self.StepHud then self:StepHud(step) end
end
function DURING.burst(self, beat, share)
    local scale, alpha, flash
    if share < .3 then
        local q = share / .3
        scale, alpha, flash = 1 + .26 * (1 - (1 - q) * (1 - q)), 1, .9 * q
    else
        local q = (share - .3) / .7
        scale, alpha, flash = 1.26 - 1.08 * q * q, 1 - q, .9 * (1 - q)
    end
    local step = beat.step
    for _, list in ipairs({step.cleared, step.broken or EMPTY}) do
        for _, gone in ipairs(list) do
            local cell = self.cells[gone.i]
            Scale(cell, scale)
            Fade(cell, alpha)
            cell.art.flash:SetAlpha(flash)
        end
    end
    for _, area in ipairs(self.flashes) do
        if area:IsShown() then area:SetAlpha(.45 * (1 - share)) end
    end
end
function FINISH.burst(self, beat)
    local step = beat.step
    for _, list in ipairs({step.cleared, step.broken or EMPTY}) do
        for _, gone in ipairs(list) do
            local cell = self.cells[gone.i]
            cell.art:Hide()
            cell.piece = false
            cell.shiny = nil
        end
    end
    self:Calm()
end
-- The pieces above fall into the gaps and new ones drop in, each landing
-- with a hop; a special made swells as it lands, a relic dropping in glows.
function BEGIN.fall(self, beat)
    local step = beat.step
    self:Calm()
    self:Paint(step.after)
    for index, cell in ipairs(self.cells) do
        local rows = step.fall[index] or 0
        cell.drop = rows * V.CELL
        cell.hop = rows > 0 and math.min(7, 2 + rows) or 0
        Offset(cell, 0, cell.drop)
    end
    for _, make in ipairs(step.made or EMPTY) do
        for index = 1, CELLS do
            if step.after[index] == make.piece then
                local cell = self.cells[index]
                cell.made = true
                OPTS.made.colour = PAINT.special[make.piece.special] or PAINT.gold
                MG:Pulse(cell, OPTS.made)
            end
        end
    end
    for _, came in ipairs(step.relicsIn or EMPTY) do
        local cell = self.cells[came.i]
        if cell then MG:Pulse(cell, OPTS.relicGlow) end
    end
    if step.made and step.made[1] then MG:Sound("chime") end
end
function DURING.fall(self, beat, share)
    local swell = 1 + .3 * math.sin(math.pi * share)
    for _, cell in ipairs(self.cells) do
        if cell.drop and (cell.drop > 0 or cell.hop > 0) then Offset(cell, 0, FallAt(share, cell.drop, cell.hop)) end
        if cell.made then Scale(cell, swell) end
    end
end
function FINISH.fall(self) self:Calm() end
-- A board laid out afresh fades in, row by row from the top.
function BEGIN.fade(self, beat)
    self:Calm()
    self:PaintCells()
    for _, cell in ipairs(self.cells) do Fade(cell, 0) end
    if beat.sound then MG:Sound(beat.sound) end
end
function DURING.fade(self, beat, share)
    for _, cell in ipairs(self.cells) do
        local row = math.floor((cell.index - 1) / N)
        local alpha = math.max(0, math.min(1, share * 1.8 - row * .1))
        Fade(cell, alpha)
        Offset(cell, 0, 14 * (1 - alpha))
    end
end
function FINISH.fade(self) self:Calm() end
-- Relics reaching an exit fly off through it to their goal, the points rising.
function BEGIN.exit(self, beat)
    local step = beat.step
    self.stamp = self.stamp + 1
    self:Paint(step.before)
    local tx, ty
    if self.GoalSpot then tx, ty = self:GoalSpot("relic") end
    if not tx then tx, ty = self:ScoreSpot() end
    for _, gone in ipairs(step.relicsOut or EMPTY) do
        local cell = self.cells[gone.i]
        MG:Pulse(cell, OPTS.relicGlow)
        MG:Burst(cell, OPTS.relicSpark)
        self:FlyRelic(gone, tx, ty)
        cell.art:Hide()
        cell.piece = false
        cell.shiny = nil
    end
    if step.relicsOut and step.relicsOut[1] then
        MG:FloatText(self.cells[step.relicsOut[1].i], "+" .. (step.points or 0), OPTS.relicText)
        MG:Note(NOTES.relicOut)
    end
    self.shownScore = step.score
    MG:SetScore(step.score or 0)
    self:Once("relicDrop")
    if self.StepHud then self:StepHud(step) end
end
DURING.exit, FINISH.exit = Nothing, Nothing
-- The boss strikes back: his portrait shakes and roars, the cells he picks
-- flash his action's colour, then his mess drops onto them with a pop.
local ACTION_SOUND = {oil = "oilSplat", freeze = "iceFreeze", crates = "crateBreak", skulls = "boing", web = "squish"}
local function Strike(self, beat)
    beat.struck = true
    local step = beat.step
    self:Paint(step.after)
    for i, layers in pairs(step.oil or EMPTY) do
        self.oil[i] = layers
        self:PaintOil(i)
    end
    for _, i in ipairs(step.cells or EMPTY) do
        local cell = self.cells[i]
        if cell then MG:Pop(cell.art, {peak = 1.3, life = .3}) end
    end
    MG:Sound(ACTION_SOUND[step.action] or "pop")
end
function BEGIN.boss(self, beat)
    local step = beat.step
    self.stamp = self.stamp + 1
    self:Paint(step.before)
    if self.BossStrikes then self:BossStrikes(step) end
    local strike = OPTS.strike
    strike.colour = PAINT.action[step.action] or PAINT.buzz
    for _, i in ipairs(step.cells or EMPTY) do
        local cell = self.cells[i]
        if cell then MG:Pulse(cell, strike) end
    end
    if step.text then MG:Note(NOTES.bossStrike:format(step.text)) end
end
function DURING.boss(self, beat, share)
    if share >= .45 and not beat.struck then Strike(self, beat) end
end
function FINISH.boss(self, beat)
    if not beat.struck then Strike(self, beat) end
    if beat.step.text then self.after = NOTES.bossStrike:format(beat.step.text) end
end
-- The Mallet comes down on a cell.
function BEGIN.smash(self, beat)
    local cell = self.cells[beat.i]
    if cell then
        MG:Pulse(cell, OPTS.smash)
        MG:Burst(cell, OPTS.smashSpark)
    end
    MG:Shake(5, .25)
    MG:Sound("squish")
    MG:Sound("powerUse")
end
DURING.smash, FINISH.smash = Nothing, Nothing
-- A level's boosters show as it starts: the Charge and the Sheep glow, Bloodlust / Heroism lights.
function BEGIN.boost(self, beat)
    local boosted = beat.boosted or EMPTY
    for _, special in ipairs({"charge", "sheep"}) do
        local i = boosted[special]
        local cell = i and self.cells[i]
        if cell then
            OPTS.boosted.colour = PAINT.special[special]
            MG:Pulse(cell, OPTS.boosted)
            MG:Burst(cell, OPTS.landSpark)
        end
    end
    if boosted.charge or boosted.sheep then MG:Sound("chime") end
    if boosted.lust then self:LustOn() end
end
DURING.boost, FINISH.boost = Nothing, Nothing

-- The beats of a move, played in turn; the time left after one goes to the next.
function game:Play(elapsed)
    while true do
        local beat = self.beats[1]
        if not beat then break end
        if not beat.started then
            beat.started = true
            BEGIN[beat.kind](self, beat)
        end
        beat.t = beat.t + elapsed
        if beat.t < beat.dur then
            DURING[beat.kind](self, beat, beat.t / beat.dur)
            return
        end
        elapsed = beat.t - beat.dur
        table.remove(self.beats, 1)
        FINISH[beat.kind](self, beat)
    end
    self:Done()
end
-- The move played out (or cut short: cut, the window hiding): the board as
-- it now is, the HUD, the note; then what the game does at a level's end.
function game:Done(cut)
    self.beats = {}
    self.busy = false
    self.shownScore, self.shownMeter, self.lustPending, self.epicSound = nil, nil, false, false
    self.idle = 0
    if not (self.cells and self.state) then return end
    self:Calm()
    self:PaintCells()
    MG:SetScore(self.state.score)
    if self.PaintHud then self:PaintHud(true) end
    if self.after then MG:Note(self.after) end
    self.after = nil
    if self.Ended then self:Ended(cut) end
end
