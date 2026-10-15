-- EraUI Thick Frames.
-- Appearance > Style > Frame Style (off unless ticked; needs Unit Frames).
-- The unit frames in EraUI's look (Classic/UnitFrames.lua) can wear a thick
-- look instead of the Classic art: a near-black plate with round corners
-- round each frame's name and bars, so the frame stands out from the world
-- behind it. The name sits straight on the plate over the
-- bars (no lighter strip behind it, so an empty bar never reads as a table
-- row), the bars are taller, the bar text (still the game's own) sits at the
-- bar's end away from the portrait (a "Dead" too), and the level sits in a
-- small pill under the portrait; a target's reaction colour is a faint line
-- under its name (the names on the big frames sit a little high in their
-- row, so the line never touches a letter's tail), gone while it's dead, and
-- a dead target, a minor mob or one with no power at all has no power row:
-- its plate ends under the health bar (nor a stray 0 of the game's in it).
-- The power bar's text sits a unit above the bar's middle, inside the bar.
-- The bars and their tracks have rounded ends (two end masks each, or none),
-- the player's red health-loss flash too.
-- Mirrored for the target and focus;
-- the target of target, the pet and (with Classic Party Frames, its own
-- tick) EraUI's Classic-style party frames get smaller plates. Portrait
-- Rings (its own tick) adds a thick dark ring round each round portrait,
-- which overlaps the plate's end. An elite target gets a small gold pip on
-- top of its portrait, a rare one silver.
-- Edge (its own choice under the tick, "thickFrameEdge"): Dark, the default,
-- keeps every edge near black; Class colour adds a fine line just inside the
-- plate, the ring and the level's pill, rounded like them: your class colour
-- on your frame and your pet's, a player's on theirs (target, focus, target
-- of target, party), an elite's gold or a rare's silver on a target or
-- focus, and none (dark) on any other NPC. The full class colour: Dark
-- Mode's "Darken class colours too" isn't applied (darkened, the yellows went
-- olive).
--
-- How: Classic/UnitFrames.lua places every frame in its Classic look as
-- before, then hands it here to wear the thick look, or to take it off. All
-- that's drawn is EraUI's own textures, made the first time a frame wears
-- the look and then only shown, hidden and toned: on EraUI's own host frame
-- (player, target, focus, party) or on the game's frame itself (pet, targets
-- of target), kept in a weak table either way, so no key is ever written on
-- the game's frames. The game's own pieces (names, levels, bar texts, the
-- reaction colour, the Classic art) are only re-anchored, sized, faded and
-- shown again: cosmetic setters. Every piece is pinned from the numbers
-- below, nothing is read back from the game's layout. A switch in /era made
-- in a fight waits for its end with the rest of the unit frames' pass (Edge
-- doesn't need to: it only tones and shows EraUI's own textures); the
-- keepers that run in fights only follow the look each frame already wears.
-- The Classic flash and status glows are left as they are.
local _, EraUI = ...
local ns = EraUI.Classic

local T = {}
ns.Thick = T

local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) end
local function Round(v) return math.floor(v + .5) end

-- The plate's near black (Rounded Cast Bars' shell), the bars' track a touch
-- lighter, and the marks for an elite (gold) or rare (silver) target. A rare
-- elite is silver, as the game's own frame has it on Forever.
local SHELL = { .05, .05, .06 }
local TRACK = { .075, .078, .094 }
local GOLD = { .85, .68, .29 }
local SILVER = { .77, .79, .83 }
local BLACK = { 0, 0, 0 }
local MARKS = { elite = GOLD, worldboss = GOLD, rare = SILVER, rareelite = SILVER }
-- A paladin's class colour everywhere in EraUI (the game's is a pale pink).
local PALADIN = { .96, .55, .73 }

-- Where everything sits, in frame units from the frame's top and from the
-- side its portrait is on: the left for the player, pet, party and targets
-- of target; the right for the target and focus, which mirror the player.
-- Built from the portrait as Classic/UnitFrames.lua places it (its offset
-- from that side and from the top, and its size: the same numbers as
-- there), the edge, the corner radius, the bars' width, the heights of the
-- name's row (its "strip", drawn as nothing: only the name and the reaction
-- line are pinned to it) and the two bars, the gap between them and the
-- room the name and the bar text keep from the ends. The ring is the edge's
-- width round the portrait; the plate starts just past the portrait's
-- middle, so the portrait and its
-- ring overlap its end, and reaches an edge's width past the bars; the bars
-- start an edge's width past the ring. The big frames (player, target,
-- focus) also get the level's pill under the portrait and the elite's pip
-- on top of it, and their names sit NAME_Y above the row's middle: the
-- game's small font draws low in its box (in game its capitals reach 2.5
-- above the box's middle, a "g" with its shadow 7 below), so centred, the
-- tails touched the reaction line at the row's foot. cut: the power row and
-- its gap, which the plate loses when a target or focus shows no power row.
local NAME_Y = 3
local function Geometry(side, x, top, size, edge, corner, width, strip, health, power, gap, pad, big)
    local r = size / 2
    local cx, cy = x + r, -(top + r)
    local barX = cx + r + 2 * edge
    local plateX = Round(cx + 2)
    local plateH = strip + gap + health + gap + power + 2 * edge
    local plateY = Round(cy + plateH / 2)
    local barY = plateY - edge
    local g = {
        side = side, edge = edge, corner = corner, pad = pad, cx = cx, cy = cy, radius = r,
        nameY = big and NAME_Y or 0, cut = gap + power,
        plate = { plateX, plateY, barX + width + edge - plateX, plateH },
        strip = { barX, barY, width, strip },
        health = { barX, barY - strip - gap, width, health },
        power = { barX, barY - strip - gap - health - gap, width, power },
    }
    if big then
        g.pill = cy - r - edge - 3
        g.pip = cy + r + edge
    end
    return g
end
-- The approved mockup's Thick border (6) and Tall bars (28 and 13) at the
-- unit frames' size: an edge of 5 and bars 21 and 10 tall on the big frames,
-- an edge of 4 on the small ones. The corners a touch rounder than the
-- mockup's (8 and 6 where 6 and 5 read as square in game), so they show as
-- round at the game's own scale.
local GEOMETRY = {
    player = Geometry("LEFT", 23, 16, 64, 5, 8, 119, 13, 21, 10, 2, 5, true),
    target = Geometry("RIGHT", 22, 16, 64, 5, 8, 119, 13, 21, 10, 2, 5, true),
    pet = Geometry("LEFT", 7, 6, 37, 4, 6, 69, 10, 10, 6, 1, 3),
    party = Geometry("LEFT", 7, 14, 37, 4, 6, 70, 10, 10, 6, 1, 3),
    tot = Geometry("LEFT", 5, 5, 35, 4, 6, 44, 10, 8, 4, 1, 3),
}
GEOMETRY.focus = GEOMETRY.target
T.GEOMETRY = GEOMETRY
-- The level's pill (fill, line, black rim) and the pip (gem, black rim and
-- the plate's near black round it, each a square turned on its corner).
local PILL = { 22, 12 }
local PIP = { 6, 8, 10 }
-- The reaction colour's line under the name: one unit, kept the name's room
-- from both ends, and faint.
local UNDERLINE, UNDERLINE_ALPHA = 1, .7
-- The power bar's texts a unit above its middle: the game's font fills the
-- 10-unit bar, and on the bar's middle its foot spilled a unit below it.
local POWER_TEXT_Y = 1

-- Under a thick target or focus (Classic/UnitFrames.lua, Classic/CastBars.lua):
-- the aura row clear of the plate (from the faded art's foot; Classic 32),
-- the target of target clear of the level's pill (its top; Classic -69), and
-- the cast bar, when the game keeps it under the frame rather than the
-- auras, clear of both and of Rounded Cast Bars' shell (from the frame's
-- foot; Classic 3, -25 with a target of target, -9 for an elite).
T.AURA_Y = 20
T.TOT_Y = -92
local CAST_Y, CAST_TOT_Y = -2, -42

-- frame: { kind, g, canvas, on, plate, line, lineGap, strip, tracks, ring,
-- pill, pillLine, pip, gem, flat, shaped, edges, all, faded, hidden, unit,
-- classification, rings, lined, ringed, lr, lg, lb, short, bars, caps, square }
local worn = setmetatable({}, { __mode = "k" })

function T.Want(kind)
    if EraUI:GetSetting("thickFrames") ~= true or GEOMETRY[kind] == nil then return false end
    if kind == "party" then return EraUI:GetSetting("thickFrameParty") == true end
    return true
end

function T.Worn(frame)
    local s = frame and worn[frame]
    return s ~= nil and s.on == true
end

local function Rings()
    return EraUI:GetSetting("thickFrameRings") == true
end

-- Edge: "class" draws the fine line in class colours; anything else (the
-- default "dark") keeps every edge near black.
local function ClassEdge()
    return EraUI:GetSetting("thickFrameEdge") == "class"
end

-- Placing -------------------------------------------------------------------------

-- A piece by its top corner on the portrait's side, x in from that side.
local function Pin(region, canvas, side, x, y, w, h)
    region:ClearAllPoints()
    region:SetSize(w, h)
    if side == "RIGHT" then
        region:SetPoint("TOPRIGHT", canvas, "TOPRIGHT", -x, y)
    else
        region:SetPoint("TOPLEFT", canvas, "TOPLEFT", x, y)
    end
end

-- A piece by its centre.
local function Centre(region, canvas, side, x, y, w, h)
    region:ClearAllPoints()
    region:SetSize(w, h)
    if side == "RIGHT" then
        region:SetPoint("CENTER", canvas, "TOPRIGHT", -x, y)
    else
        region:SetPoint("CENTER", canvas, "TOPLEFT", x, y)
    end
end

-- Which half of the round mask a piece on the near (portrait) side or the
-- far side takes, so a mirrored frame gets its corners the right way round.
local function Half(side, near)
    if (side == "RIGHT") == near then return .5, 1 end
    return 0, .5
end

-- A rectangle with soft corners: four quarters of the round portrait mask
-- the game ships (as Rounded Cast Bars' shell), the middle at full height
-- and the two ends between the corners.
local function PinRounded(pieces, canvas, side, rect, c)
    local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
    local corners = { { x, y, true, true }, { x + w - c, y, false, true }, { x, y - h + c, true, false }, { x + w - c, y - h + c, false, false } }
    for i, spot in ipairs(corners) do
        local left, right = Half(side, spot[3])
        local top = spot[4] and 0 or .5
        pieces[i]:SetTexCoord(left, right, top, top + .5)
        Pin(pieces[i], canvas, side, spot[1], spot[2], c, c)
    end
    Pin(pieces[5], canvas, side, x + c, y, w - 2 * c, h)
    Pin(pieces[6], canvas, side, x, y - c, c, h - 2 * c)
    Pin(pieces[7], canvas, side, x + w - c, y - c, c, h - 2 * c)
end

-- A pill on its centre: two halves of the round mask and the middle.
local function PinPill(pieces, canvas, side, cx, cy, w, h)
    local x, y = cx - w / 2, cy + h / 2
    local left, right = Half(side, true)
    pieces[1]:SetTexCoord(left, right, 0, 1)
    Pin(pieces[1], canvas, side, x, y, h / 2, h)
    Pin(pieces[2], canvas, side, x + h / 2, y, w - h, h)
    left, right = Half(side, false)
    pieces[3]:SetTexCoord(left, right, 0, 1)
    Pin(pieces[3], canvas, side, x + w - h / 2, y, h / 2, h)
end

-- The plate and the fine line's shape inside it (the plate's own, inset to
-- 2 to 1 units outside the bars, the near black one unit in from it, so its
-- corners are round too): full height, or short, ending an edge under the
-- health bar when a target or focus shows no power row. Pinned only when
-- that changes (EraUI's own textures, so in a fight too).
local function Fit(s, short)
    if s.short == short then return end
    s.short = short
    local g, p = s.g, s.g.plate
    local h = short and p[4] - g.cut or p[4]
    local inset = g.edge - 2
    local c = g.corner - inset
    PinRounded(s.plate, s.canvas, g.side, { p[1], p[2], p[3], h }, g.corner)
    PinRounded(s.line, s.canvas, g.side, { p[1] + inset, p[2] - inset, p[3] - 2 * inset, h - 2 * inset }, c)
    PinRounded(s.lineGap, s.canvas, g.side, { p[1] + inset + 1, p[2] - inset - 1, p[3] - 2 * inset - 2, h - 2 * inset - 2 }, c - 1)
end

-- Making ------------------------------------------------------------------------

local function Piece(s, layer, sub)
    local tex = s.canvas:CreateTexture(nil, layer, nil, sub)
    s.all[#s.all + 1] = tex
    return tex
end

-- A flat piece of colour, or a piece of the round mask tinted (shaped). One
-- made without a colour is a piece of the fine line: Tone colours it.
local function Flat(s, layer, sub, c)
    local tex = Piece(s, layer, sub)
    if c then tex:SetColorTexture(c[1], c[2], c[3], 1) else s.flat[#s.flat + 1] = tex end
    return tex
end
local function Shaped(s, layer, sub, c)
    local tex = Piece(s, layer, sub)
    ns.SetTex(tex, "portraitMask")
    tex:SetTexCoord(0, 1, 0, 1)
    if c then tex:SetVertexColor(c[1], c[2], c[3], 1) else s.shaped[#s.shaped + 1] = tex end
    return tex
end
local function Rounded(s, layer, sub, c)
    local pieces = {}
    for i = 1, 4 do pieces[i] = Shaped(s, layer, sub, c) end
    for i = 5, 7 do pieces[i] = Flat(s, layer, sub, c) end
    return pieces
end
local function Pill(s, sub, c)
    return { Shaped(s, "BORDER", sub, c), Flat(s, "BORDER", sub, c), Shaped(s, "BORDER", sub, c) }
end

-- Everything a frame wears, made and pinned once (each kind's place never
-- changes), then only shown, hidden and toned. All of it sits under the
-- portrait: on the game's frame (pet, targets of target) in the background
-- below the portrait's own sublevel; on EraUI's host (the rest), a frame the
-- portrait's container sits over. Bottom up: the plate; the fine line (the
-- plate's own shape 2 to 1 units outside the bars in the line's colour, the
-- near black again one unit in from it, so its corners are round too); the
-- name's row (nothing drawn: an anchor) and the bars' tracks; then the ring
-- (near black, the line, then a near-black gap the portrait sits in); the
-- pill (black rim, the line, near-black fill) and the pip over them. The
-- line's pieces (edges, and the ring's) show only with a colour for them.
local function Build(frame, kind, canvas)
    local g = GEOMETRY[kind]
    local side = g.side
    local s = { kind = kind, g = g, canvas = canvas, all = {}, flat = {}, shaped = {}, edges = {}, faded = {}, hidden = {}, caps = {} }
    s.plate = Rounded(s, "BACKGROUND", -8, SHELL)
    s.line = Rounded(s, "BACKGROUND", -7)
    s.lineGap = Rounded(s, "BACKGROUND", -6, SHELL)
    Fit(s, false)
    for _, list in ipairs({ s.line, s.lineGap }) do
        for _, tex in ipairs(list) do s.edges[#s.edges + 1] = tex end
    end
    s.strip = Piece(s, "BACKGROUND", -5)
    s.strip:SetColorTexture(0, 0, 0, 0)
    Pin(s.strip, canvas, side, unpack(g.strip))
    s.tracks = { health = Flat(s, "BACKGROUND", -5, TRACK), power = Flat(s, "BACKGROUND", -5, TRACK) }
    Pin(s.tracks.health, canvas, side, unpack(g.health))
    Pin(s.tracks.power, canvas, side, unpack(g.power))
    local r = g.radius
    local body, ring, gap = Shaped(s, "BACKGROUND", -4, SHELL), Shaped(s, "BACKGROUND", -3), Shaped(s, "BACKGROUND", -2, SHELL)
    Centre(body, canvas, side, g.cx, g.cy, 2 * (r + g.edge), 2 * (r + g.edge))
    Centre(ring, canvas, side, g.cx, g.cy, 2 * r + 4, 2 * r + 4)
    Centre(gap, canvas, side, g.cx, g.cy, 2 * r + 2, 2 * r + 2)
    s.ring = { body, ring, gap }
    if g.pill then
        local rim, line, fill = Pill(s, -8, BLACK), Pill(s, -7), Pill(s, -6, SHELL)
        PinPill(rim, canvas, side, g.cx, g.pill, PILL[1] + 4, PILL[2] + 4)
        PinPill(line, canvas, side, g.cx, g.pill, PILL[1] + 2, PILL[2] + 2)
        PinPill(fill, canvas, side, g.cx, g.pill, PILL[1], PILL[2])
        for _, tex in ipairs(line) do s.edges[#s.edges + 1] = tex end
        s.pill = { rim[1], rim[2], rim[3], fill[1], fill[2], fill[3] }
        s.pillLine = line
        s.pillMiddle = fill[2]
        s.pip = {}
        for i, size in ipairs({ PIP[3], PIP[2], PIP[1] }) do
            local square = Flat(s, "BORDER", -6 + i, i == 1 and SHELL or i == 2 and BLACK or GOLD)
            Centre(square, canvas, side, g.cx, g.pip, size, size)
            if square.SetRotation then square:SetRotation(math.pi / 4) end
            s.pip[i] = square
        end
        s.gem = s.pip[3]
    end
    worn[frame] = s
    return s
end

-- Colours -----------------------------------------------------------------------

-- A player's class colour, in full (a paladin's pink, as everywhere in
-- EraUI). Nothing for an NPC, or when the game keeps who it is from addons.
local function ClassColour(unit)
    if not unit then return end
    local player = UnitIsPlayer(unit)
    if IsSecret(player) or not player then return end
    local _, class = UnitClass(unit)
    if IsSecret(class) or type(class) ~= "string" then return end
    if class == "PALADIN" then return PALADIN[1], PALADIN[2], PALADIN[3] end
    local colour = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if colour then return colour.r, colour.g, colour.b end
end

-- The fine line's colour with Edge's Class colour: an elite's gold or a
-- rare's silver (mark: the target and focus only), else who it is (unit:
-- yours on your frame and your pet's), else none. Dark: always none.
local function EdgeColour(unit, mark)
    if not ClassEdge() then return end
    if mark then return mark[1], mark[2], mark[3] end
    return ClassColour(unit)
end

-- A frame's fine line for who it is now (unit) and, on the target and focus,
-- its classification: coloured, or hidden when there's no colour for it
-- (the ring's part only with Portrait Rings too); the pip for an elite or a
-- rare whatever the edge. Each texture set only when its colour or its
-- showing changes.
local function Tone(s, unit, classification)
    s.unit, s.classification = unit, classification
    local mark = (s.kind == "target" or s.kind == "focus") and MARKS[classification] or nil
    local r, g, b = EdgeColour(unit, mark)
    local lined = r ~= nil
    if lined and (s.lr ~= r or s.lg ~= g or s.lb ~= b) then
        s.lr, s.lg, s.lb = r, g, b
        for _, tex in ipairs(s.flat) do tex:SetColorTexture(r, g, b, 1) end
        for _, tex in ipairs(s.shaped) do tex:SetVertexColor(r, g, b, 1) end
    end
    local ringed = lined and s.rings == true
    if s.lined ~= lined or s.ringed ~= ringed then
        s.lined, s.ringed = lined, ringed
        for _, tex in ipairs(s.edges) do tex:SetShown(lined) end
        s.ring[2]:SetShown(ringed)
    end
    if s.pip then
        for _, tex in ipairs(s.pip) do tex:SetShown(mark ~= nil) end
        if mark then s.gem:SetColorTexture(mark[1], mark[2], mark[3], 1) end
    end
end

-- Rounded bar ends ----------------------------------------------------------------

-- Each bar's fill and its track get a half circle at both ends: two masks
-- (Media/ThickBarCapLeft.tga and ThickBarCapRight.tga, Tools/GenerateBarCaps.mjs),
-- each half the bar's height wide at one end, CLAMP-wrapped so past its flat
-- side the rest of the bar is untouched. Never more than two of ours on a
-- texture: Forever takes three masks on one and throws at a fourth (the
-- pet's own bars already carry the game's). A fill keeps its masks when the
-- game or EraUI sets its art again (SetStatusBarTexture keeps the same
-- texture; Forever's own target frame adds its bar masks once, at load, the
-- same way); the keepers check the fill each pass in case it's a new one.
-- All or nothing per frame: if the art doesn't load or any texture won't
-- take both masks, every mask comes off that frame's bars and tracks and
-- they stay square for the session rather than half rounded. Off takes them
-- all off (the Classic look's bars are square as today); EraUI's own
-- textures and the fill's own mask calls only, never a key on the game's
-- frames.
local CAP_FILE = "Interface\\AddOns\\EraUI\\Media\\ThickBarCap%s.tga"

-- The two masks for one texture, made on owner (the bar for a fill, the
-- canvas for a track) and pinned to the ends of anchor, h (the bar's
-- height) tall; nil when the art doesn't load.
local function CapMasks(owner, anchor, h)
    if not owner or not owner.CreateMaskTexture then return end
    local masks = {}
    for i, side in ipairs({ "Left", "Right" }) do
        local mask = owner:CreateMaskTexture()
        masks[i] = mask
        if mask:SetTexture(CAP_FILE:format(side), "CLAMP", "CLAMP") == false then
            for _, made in ipairs(masks) do made:Hide() end
            return
        end
        local edge = i == 1 and "LEFT" or "RIGHT"
        mask:SetPoint("TOP" .. edge, anchor, "TOP" .. edge, 0, 0)
        mask:SetPoint("BOTTOM" .. edge, anchor, "BOTTOM" .. edge, 0, 0)
        mask:SetWidth(h / 2)
    end
    return masks
end

-- Every mask of ours off this frame's textures.
local function SquareEnds(s)
    for tex, cap in pairs(s.caps) do
        if cap.on then
            cap.on = false
            for _, mask in ipairs(cap.masks) do pcall(tex.RemoveMaskTexture, tex, mask) end
        end
    end
end

-- One texture's two masks on (made the first time); false when it can't
-- take both (whatever it took comes off again).
local function CapOn(s, tex, owner, anchor, h)
    if not tex or not tex.AddMaskTexture or not tex.RemoveMaskTexture then return false end
    local cap = s.caps[tex]
    if not cap then
        cap = { masks = CapMasks(owner, anchor, h) or false }
        s.caps[tex] = cap
    end
    if not cap.masks then return false end
    if cap.on then return true end
    for i, mask in ipairs(cap.masks) do
        if not pcall(tex.AddMaskTexture, tex, mask) then
            for j = 1, i - 1 do pcall(tex.RemoveMaskTexture, tex, cap.masks[j]) end
            return false
        end
    end
    cap.on = true
    return true
end

-- The frame's bars (s.bars: EraUI's own, or the pet's) and their tracks
-- rounded, or the frame square for good when any of them can't be. On the
-- player, the game's red health-loss bar too (s.loss: Classic/UnitFrames.lua
-- lays it over EraUI's health bar and takes its own mask off), or each hit
-- flashes square red corners round the health bar's round ends; its masks
-- made on and pinned to that health bar. Left for the pass after a fight
-- while the game guards it, as its fill art is.
local function RoundEnds(s)
    if s.square or not s.bars then return end
    local g = s.g
    for _, key in ipairs({ "health", "power" }) do
        local bar, h = s.bars[key], g[key][4]
        local fill = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
        if not (CapOn(s, fill, bar, bar, h) and CapOn(s, s.tracks[key], s.canvas, s.tracks[key], h)) then
            s.square = true
            SquareEnds(s)
            return
        end
    end
    local loss = s.loss
    if not loss or (ns.HeldInFight and ns.HeldInFight(loss)) then return end
    local fill, health = loss.GetStatusBarTexture and loss:GetStatusBarTexture(), s.bars.health
    if fill and not CapOn(s, fill, health, health, g.health[4]) then
        s.square = true
        SquareEnds(s)
    end
end

-- Wearing and taking off ----------------------------------------------------------

-- A game piece faded while the look shows (its own alpha noted first), or
-- one of EraUI's Classic pieces hidden; both given back when it goes.
local function Fade(s, region)
    if not region then return end
    if s.faded[region] == nil then
        local alpha = region:GetAlpha()
        s.faded[region] = (not IsSecret(alpha) and type(alpha) == "number") and alpha or 1
    end
    region:SetAlpha(0)
end
local function Hold(s, region)
    if not region then return end
    s.hidden[region] = true
    region:Hide()
end
-- A game piece at a set alpha while the look shows (its own noted first, as
-- Fade does, and given back the same way).
local function Dim(s, region, alpha)
    if not region then return end
    if s.faded[region] == nil then
        local was = region:GetAlpha()
        s.faded[region] = (not IsSecret(was) and type(was) == "number") and was or 1
    end
    region:SetAlpha(alpha)
end
-- A piece Dim set given its own alpha back while the look stays (nothing
-- when it isn't dimmed).
local function Undim(s, region)
    local alpha = region and s.faded[region]
    if alpha == nil then return end
    s.faded[region] = nil
    region:SetAlpha(alpha)
end

-- The look on a frame: its plate and tracks shown (and the name's row, an
-- anchor), the ring with Portrait Rings, the pill on the big frames, the
-- fine line as Tone says; its bars (EraUI's own, or the pet's) in the plate.
local function Wear(frame, kind, canvas, health, power, bg)
    local s = worn[frame] or Build(frame, kind, canvas)
    local g = s.g
    for _, list in ipairs({ s.plate, { s.strip, s.tracks.health, s.tracks.power }, s.pill or {} }) do
        for _, tex in ipairs(list) do tex:Show() end
    end
    s.rings = Rings()
    s.ring[1]:SetShown(s.rings)
    s.ring[3]:SetShown(s.rings)
    if health then Pin(health, canvas, g.side, unpack(g.health)) end
    if power then Pin(power, canvas, g.side, unpack(g.power)) end
    s.bars = (health and power) and { health = health, power = power } or nil
    RoundEnds(s)
    Hold(s, bg)
    s.on = true
    Tone(s, s.unit, s.classification)
    return s
end

-- Off: EraUI's pieces hidden, the game's faded pieces and EraUI's Classic
-- ones back. Its places are the Classic look's again from the pass that
-- calls this (Classic/UnitFrames.lua). A frame that never wore it is left
-- alone.
function T.Off(frame)
    local s = frame and worn[frame]
    if not s or not s.on then return end
    s.on = false
    s.lined, s.ringed = nil, nil
    SquareEnds(s)
    for _, tex in ipairs(s.all) do tex:Hide() end
    for region, alpha in pairs(s.faded) do region:SetAlpha(alpha) end
    for region in pairs(s.hidden) do region:Show() end
    s.faded, s.hidden = {}, {}
end

-- The game's pieces -------------------------------------------------------------

-- The name in its row on the plate, from the row's left (on the big frames
-- NAME_Y above its middle, clear of the reaction line).
local function Name(label, s)
    if not label then return end
    label:ClearAllPoints()
    label:SetPoint("LEFT", s.strip, "LEFT", s.g.pad, s.g.nameY)
    label:SetWidth(s.g.strip[3] - 2 * s.g.pad)
    label:SetJustifyH("LEFT")
end

-- The bar text that shows one number (and the target's "Dead" or
-- "Unconscious") moves to the bar's end away from the portrait, in line with
-- the name; the left and right ones (both numbers shown) stay at the ends,
-- each the same room in from its end. dy: the power bar's (POWER_TEXT_Y),
-- else on the bar's middle.
local function FarText(text, bar, s, dy)
    if not text or not bar then return end
    text:ClearAllPoints()
    if s.g.side == "RIGHT" then
        text:SetPoint("LEFT", bar, "LEFT", s.g.pad, dy or 0)
    else
        text:SetPoint("RIGHT", bar, "RIGHT", -s.g.pad, dy or 0)
    end
end
local function EndTexts(left, right, bar, s, dy)
    if not bar then return end
    if left then
        left:ClearAllPoints()
        left:SetPoint("LEFT", bar, "LEFT", s.g.pad, dy or 0)
    end
    if right then
        right:ClearAllPoints()
        right:SetPoint("RIGHT", bar, "RIGHT", -s.g.pad, dy or 0)
    end
end

-- On the level's pill.
local function OnPill(region, s, size)
    if not region or not s.pillMiddle then return end
    if size then region:SetSize(size, size) end
    region:ClearAllPoints()
    region:SetPoint("CENTER", s.pillMiddle, "CENTER", 0, 0)
end

-- Player: the bars in EraUI's host (host), the rest and fight icons (rest,
-- attack: EraUI's own) on the pill in the level's place, the group number
-- above the plate.
function T.Player(frame, host, health, power, bg, rest, attack)
    local s = Wear(frame, "player", host, health, power, bg)
    local container = frame.PlayerFrameContainer
    if container then
        Fade(s, container.FrameTexture)
        Fade(s, container.AlternatePowerFrameTexture)
    end
    local main = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentMain")
    local healthBar, manaBar = ns.Path(main, "HealthBarsContainer", "HealthBar"), ns.Path(main, "ManaBarArea", "ManaBar")
    s.loss = ns.Path(main, "HealthBarsContainer", "PlayerFrameHealthBarAnimatedLoss")
    if healthBar then
        FarText(healthBar.TextString, health, s)
        EndTexts(healthBar.LeftText, healthBar.RightText, health, s)
    end
    if manaBar then
        FarText(manaBar.TextString, power, s, POWER_TEXT_Y)
        EndTexts(manaBar.LeftText, manaBar.RightText, power, s, POWER_TEXT_Y)
    end
    OnPill(rest, s, 24)
    OnPill(attack, s, 24)
    local group = ns.Path(frame, "PlayerFrameContent", "PlayerFrameContentContextual", "GroupIndicator")
    if group then
        group:ClearAllPoints()
        group:SetPoint("BOTTOMLEFT", host, "TOPLEFT", s.g.strip[1], s.g.plate[2] + 2)
    end
    T.KeepPlayer(frame)
    Tone(s, "player")
end

-- The player's name and level, put back on every keeper pass (the game moves them).
function T.KeepPlayer(frame)
    local s = worn[frame]
    if not s or not s.on then return end
    Name(PlayerName, s)
    OnPill(PlayerLevelText, s)
    RoundEnds(s)
end

-- The threat number on the plate's top. The game anchors it to the reaction
-- colour's top again when Edit Mode switches the focus's size (FocusFrameMixin:
-- SetSmallSize adds a point without clearing the old one), which on a thick
-- frame is the line under the name, so the keeper puts it back when it has
-- moved.
local function Threat(frame, s, always)
    local threat = ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "NumericalThreat")
    if not threat then return end
    if not always then
        local point, relativeTo = threat:GetPoint(1)
        if threat:GetNumPoints() == 1 and point == "BOTTOM" and relativeTo == s.canvas then return end
    end
    threat:ClearAllPoints()
    threat:SetPoint("BOTTOM", s.canvas, "TOP", -30, s.g.plate[2] + 2)
end

-- Whether a unit is dead or a ghost, or has no power at all (a beast: its
-- power bar is always empty). An answer the game keeps secret: no.
-- No power: Forever's UnitPowerType hands back nothing for such a unit
-- ("MayReturnNothing"; probed in game on a beast: nil, 0, 0) and has no
-- secret rule, or a plain power ceiling of 0. The ceiling alone wasn't
-- enough: a beast in game still showed its row (the keeper did run: its
-- level was on the pill), which only a secret ceiling explains, and Forever
-- makes UnitPowerMax secret while it restricts a unit's power
-- (SecretWhenUnitPowerMaxRestricted; a chat print shows a secret's number).
-- A caster (its power type known) with a secret ceiling keeps its row.
local function Gone(unit)
    local dead = unit and UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    return not IsSecret(dead) and dead == true
end
local function Powerless(unit)
    if not unit then return false end
    if UnitPowerType then
        local ok, kind = pcall(UnitPowerType, unit)
        if ok and not IsSecret(kind) and kind == nil then return true end
    end
    if not UnitPowerMax then return false end
    local ok, most = pcall(UnitPowerMax, unit)
    return ok and not IsSecret(most) and most == 0
end
-- Whether the game hid its own power bar: Forever's target frame does for a
-- minor mob (TargetFrameMixin:CheckClassification: ManaBar:Hide()), the
-- only time it does. Read only; a secret answer: no.
local function GameHidPower(mana)
    if not mana or not mana.IsShown then return false end
    local shown = mana:IsShown()
    return not IsSecret(shown) and shown == false
end

-- The reaction line's alpha: faint, and none while the unit is dead.
local function Underline(s, reaction, unit)
    Dim(s, reaction, Gone(unit) and 0 or UNDERLINE_ALPHA)
end

-- Target and focus (kind): mirrored. The reaction colour (the game's own
-- ReputationColor, coloured by the game; Class Accents' class colour on a
-- player) is a faint line under the name, the name's room in from both ends;
-- Dark Mode's grey, left on it by the Classic look's backing, no longer
-- follows the Darkness slider. "Dead" sits where the number does. The threat
-- number sits on the plate's top.
function T.Target(frame, kind, host, health, power, bg)
    local s = Wear(frame, kind, host, health, power, bg)
    local container = frame.TargetFrameContainer
    if container then Fade(s, container.FrameTexture) end
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    if main then
        Name(main.Name, s)
        local reaction = main.ReputationColor
        if reaction then
            if ns.UntintTexture then ns.UntintTexture(reaction) end
            ns.SetTex(reaction, "statusBarSolid")
            reaction:SetTexCoord(0, 1, 0, 1)
            reaction:ClearAllPoints()
            reaction:SetSize(s.g.strip[3] - 2 * s.g.pad, UNDERLINE)
            reaction:SetPoint("BOTTOMLEFT", s.strip, "BOTTOMLEFT", s.g.pad, 0)
            Underline(s, reaction, kind)
        end
        local bars, mana = main.HealthBarsContainer, main.ManaBar
        if bars then
            FarText(bars.HealthBar and bars.HealthBar.TextString, health, s)
            FarText(bars.DeadText, health, s)
            FarText(bars.UnconsciousText, health, s)
            EndTexts(bars.LeftText, bars.RightText, health, s)
        end
        if mana then
            FarText(mana.TextString, power, s, POWER_TEXT_Y)
            EndTexts(mana.LeftText, mana.RightText, power, s, POWER_TEXT_Y)
        end
    end
    Threat(frame, s, true)
end

-- The target's or focus's level and skull on the pill, its reaction line, and
-- its line and pip for who it is now (unit) and its classification as the
-- unit frames last read it (a fight can hide it: they keep the last one). A
-- minor mob has no power bar (nor when the game hid its own), so no power
-- row either; nor a dead unit or one with no power at all: the track goes
-- and the plate ends under the health bar, so no empty row sits under it,
-- and the game's power texts (a stray 0) fade with it, their alpha given
-- back when the row returns. Every keeper pass.
local function Blank(s, text, empty)
    if empty then Dim(s, text, 0) else Undim(s, text) end
end
function T.KeepTarget(frame, unit, classification)
    local s = worn[frame]
    if not s or not s.on then return end
    local main = ns.Path(frame, "TargetFrameContent", "TargetFrameContentMain")
    OnPill(main and main.LevelText, s)
    OnPill(ns.Path(frame, "TargetFrameContent", "TargetFrameContentContextual", "HighLevelTexture"), s, 16)
    if main and main.ReputationColor then Underline(s, main.ReputationColor, unit) end
    Threat(frame, s)
    local mana = main and main.ManaBar
    local empty = Gone(unit) or Powerless(unit)
    local row = classification ~= "minus" and not empty and not GameHidPower(mana)
    s.tracks.power:SetShown(row)
    Fit(s, not row)
    if mana then
        Blank(s, mana.TextString, empty)
        Blank(s, mana.LeftText, empty)
        Blank(s, mana.RightText, empty)
    end
    RoundEnds(s)
    Tone(s, unit, classification)
end

-- A target of target (tot): its bars (totHealth, totPower) are EraUI's own;
-- EraUI's Classic art (art) and bars' backing (bg) hidden.
function T.Tot(tot, art, bg, health, power)
    local s = Wear(tot, "tot", tot, health, power, bg)
    Hold(s, art)
    T.KeepTot(tot)
end

-- Its name, and its line for whoever it is now (the game's own unit, only
-- read), on every pass of the target's keeper.
function T.KeepTot(tot)
    local s = worn[tot]
    if not s or not s.on then return end
    Name(tot.Name, s)
    RoundEnds(s)
    Tone(s, tot.unit)
end

-- The pet: the game's own bars sit in the plate; its line is yours.
function T.Pet(frame)
    local s = Wear(frame, "pet", frame, PetFrameHealthBar, PetFrameManaBar)
    Fade(s, PetFrameTexture)
    Name(PetName, s)
    FarText(PetFrameHealthBarText, PetFrameHealthBar, s)
    EndTexts(PetFrameHealthBarTextLeft, PetFrameHealthBarTextRight, PetFrameHealthBar, s)
    FarText(PetFrameManaBarText, PetFrameManaBar, s, POWER_TEXT_Y)
    EndTexts(PetFrameManaBarTextLeft, PetFrameManaBarTextRight, PetFrameManaBar, s, POWER_TEXT_Y)
    Tone(s, "player")
end

-- A Classic party frame (Classic Party Frames): like the pet; its line is
-- the member's (the game's own unit, only read).
function T.Party(frame, host, health, power, bg)
    local s = Wear(frame, "party", host, health, power, bg)
    Fade(s, frame.Texture)
    T.KeepParty(frame)
    local bars, mana = frame.HealthBarContainer, frame.ManaBar
    if bars then
        FarText(bars.CenterText, health, s)
        EndTexts(bars.LeftText, bars.RightText, health, s)
    end
    if mana then
        FarText(mana.CenterText, power, s, POWER_TEXT_Y)
        EndTexts(mana.LeftText, mana.RightText, power, s, POWER_TEXT_Y)
    end
end

-- Its name in its row and its line for whoever it is now (the game's own
-- unit, only read), on the party keeper's passes, in a fight too: the game
-- redraws a party frame's art for a new member or a roster change, and the
-- keeper puts it back through here.
function T.KeepParty(frame)
    local s = worn[frame]
    if not s or not s.on then return end
    Name(frame.Name, s)
    RoundEnds(s)
    Tone(s, frame.unit, nil)
end

-- Classic/CastBars.lua: where a thick target's or focus's cast bar sits
-- under the frame (nil: the frame isn't thick). haveToT is the game's own
-- flag, only read.
function ns.ThickCastY(frame)
    if not T.Worn(frame) then return nil end
    return frame.haveToT and CAST_TOT_Y or CAST_Y
end

-- Edge switched in /era (Core/Settings.lua): every frame wearing the
-- look takes its new edge at once, in a fight too (EraUI's own textures
-- only). The Darkness slider calls it as well (Core/Appearance.lua
-- RefreshDarkness), though nothing of the look follows it any more.
function ns.RefreshThickFrameLines()
    for _, s in pairs(worn) do
        if s.on then
            s.lr = nil
            Tone(s, s.unit, s.classification)
        end
    end
end
