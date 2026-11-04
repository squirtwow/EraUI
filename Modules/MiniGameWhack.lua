local _, EraUI = ...

-- Whack (/era > Screen & Cursor > Mini-games; /era whack; experimental):
-- Whack-a-Gnome for the Horde, Whack-a-Peon for the Alliance (the faction
-- UnitFactionGroup gives; an unknown one gets the gnome). Stage by stage, or a
-- Quick round: after a 3, 2, 1 count heads rise out of nine holes for a
-- moment, quicker as the round goes on; click one before it ducks for a point
-- and a "Bonk!". Golden heads pay more, your own side's workers cost points,
-- and every 5th stage a boss needs three bonks. The rules are the plain
-- functions in Modules/MiniGameWhackStages.lua (no frames: Tools/TestMiniGames.lua
-- plays them); this file draws a round in the mini-games window
-- (Modules/MiniGames.lua), which pauses it whenever the window hides, and
-- Modules/MiniGameWhackHud.lua runs the stage map, the cards, the HUD and
-- /era whack tune.
--
-- The look: a grassy field (Durotar's red dirt and dry grass for peons,
-- Elwynn's green grass for gnomes), darker at its edges, with three rows of
-- dirt mounds, smaller further back. The target is the game's own 3D model (a
-- PlayerModel framed head and shoulders, Whack.FRAMING), else its round
-- portrait, and it rises out of its hole: each hole draws its mound and hole
-- (behind the target), then the target, then a cover of the same ground below
-- the hole's near edge, so the part of the target still under ground never
-- shows. The rows are layered from the back, so a front mound is always over
-- the row behind it. A golden head glows gold, one of your own side shows a
-- ring in your side's colour, a boss a red glow. A mallet (ellipses cut from
-- the portrait mask's disc, turned with SetRotation) rests with its striking
-- face on the pointer's tip over the field and swings down from there at each
-- click; the game's pointer stays as it is.
local MG = EraUI.MiniGames
if not MG then return end

local Whack = MG.Whack or {}
MG.Whack = Whack

-- The targets. file, atlas, icon: the round portrait's art (Interface\CharacterFrame,
-- then the race icon atlas, then the head's item icon, should the client refuse
-- one). displays: the 3D model (CreatureDisplayInfo, build 1.60.1.70707: the
-- Gnomeregan Evacuee and Tinkmaster Overspark; the Lazy Peon and an orc with
-- the peon's voice). key, decoy, boss: their framing keys (Whack.FRAMING), the
-- decoy's and boss's art being the roles "whack." .. decoy and "whack." .. boss
-- (Modules/MiniGameAssets.lua). ground: the field's tiles by file ID (Elwynn's
-- grass with earth from the Ironforge tileset; Durotar's dry grass and red
-- dirt), each with a stand-in, and a flat colour should the client refuse
-- both. voice: MiniGames.SOUNDS names (a list: one of them).
Whack.TARGETS = {
    gnome = {key = "gnome", decoy = "decoyHorde", boss = "bossGnome", zone = "elwynn",
        prefix = "Whack-a-", accent = "Gnome", noun = "gnome",
        file = "Interface\\CharacterFrame\\TemporaryPortrait-Male-Gnome", atlas = "raceicon128-gnome-male",
        icon = "Interface\\Icons\\INV_Misc_Head_Gnome_01",
        displays = {6973, 7028},
        ground = {field = {187126, 188581}, fieldTint = {.9, .92, .86}, fieldFlat = {.26, .34, .1},
            mound = {188581, 188579}, moundTint = {.8, .76, .72}, lipTint = {1, .96, .9}, moundFlat = {.4, .32, .24},
            wall = {332326, 188581}, wallTint = {.45, .36, .3}, dust = {.84, .76, .6}},
        voice = {up = {"gnomeUp", "gnomeHello"}, hit = {"gnomeHit", "gnomeWound"}, crit = "gnomeCrit",
            go = "gnomeHello", done = "cheerGnome", laugh = "gnomeLaugh", decoy = {"peonWhat", "peonUp"}, boss = "voiceMekkatorque"}},
    peon = {key = "peon", decoy = "decoyAlliance", boss = "bossPeon", zone = "durotar",
        prefix = "Whack-a-", accent = "Peon", noun = "peon",
        file = "Interface\\CharacterFrame\\TemporaryPortrait-Male-Orc", atlas = "raceicon128-orc-male",
        icon = "Interface\\Icons\\INV_Misc_Head_Orc_01",
        displays = {10038, 9574},
        ground = {field = {332329, 187021}, fieldTint = {.8, .78, .76}, fieldFlat = {.42, .24, .13},
            mound = {187017, 187113}, moundTint = {.84, .8, .76}, lipTint = {1, .95, .9}, moundFlat = {.5, .3, .17},
            wall = {332326, 187017}, wallTint = {.45, .33, .25}, dust = {.72, .5, .34}},
        voice = {up = {"peonWhat", "peonUp"}, hit = {"peonHit", "orcWound"}, crit = "orcCrit",
            go = "peonReady", done = "peonDone", laugh = "orcLaugh", decoy = "voicePeasant", boss = "voiceGrunt"}},
}
Whack.MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
-- The 3D targets: on unless set false (Whack.Models(false) turns them off
-- live); turns: each column's facing (radians), the outer ones turned a
-- little towards the middle. Animations (AnimationData, build 1.60.1.70707):
-- what a head does as it comes up, when bonked (a streak's milestone: the big
-- flinch) and peeking between rounds (the laugh once one is over).
Whack.models = true
Whack.MODEL = {turns = {.38, 0, -.38}, pop = {0, 64, 82, 0, 67}, hit = 9, crit = 10, idle = 0, laugh = 70}
-- Your side's colour (a worker of your own side shows a ring of it), the
-- golden head's and the boss's glow.
Whack.SIDE = {Alliance = {.25, .55, 1}, Horde = {.95, .22, .15}}
Whack.AURA = {golden = {1, .82, .25}, boss = {1, .25, .12}}

-- The Horde whacks gnomes, the Alliance peons.
function Whack.Target(faction)
    if faction == "Alliance" then return Whack.TARGETS.peon end
    return Whack.TARGETS.gnome
end
-- Each page of ten stages in its own zone (the field and the map's ground):
-- the target's home first, then three more with checked ground art, round again.
Whack.PAGES = {gnome = {"elwynn", "westfall", "redridge", "duskwood"}, peon = {"durotar", "barrens", "mulgore", "silverpine"}}
function Whack.PageZone(target, n)
    local list = Whack.PAGES[target.key] or {target.zone}
    local page = math.floor((math.max(1, math.floor(tonumber(n) or 1)) - 1) / 10)
    return list[page % #list + 1]
end
-- The field's look in a zone: the target's own at home; elsewhere that zone's
-- ground (its stand-in for the mounds), in the same light.
function Whack.Look(target, zone)
    local home = target.ground
    local art = MG.ZONE_ART and MG.ZONE_ART[zone]
    if zone == target.zone or not art then return home end
    local tint = art[3]
    local flat = {tint[1] * .5, tint[2] * .5, tint[3] * .5}
    return {field = {art[1], art[2]}, fieldTint = home.fieldTint, fieldFlat = flat, mound = {art[2], art[1]},
        moundTint = home.moundTint, lipTint = home.lipTint, moundFlat = {flat[1] * 1.2, flat[2] * 1.2, flat[3] * 1.2},
        wall = {332326, art[2]}, wallTint = home.wallTint, dust = {.4 + tint[1] * .5, .4 + tint[2] * .5, .4 + tint[3] * .5}}
end
-- The framing key and art role of a kind of head for a target.
function Whack.KindKey(target, kind)
    if kind == "decoy" then return target.decoy end
    if kind == "boss" then return target.boss end
    return target.key
end

-- The field ---------------------------------------------------------------------------------

-- The play area (MiniGames.CONTENT_W x CONTENT_H), x right and y down from
-- its top left; the HUD across its top (HUD_H). ROWS: each row's hole middles
-- and depth (k: its size, the back row smallest). The mound sits a little
-- under its hole; the lip is a lighter ring round the hole. The target's frame
-- (BODY; a boss's BOSS times it) shows SHOWN of its height over the hole's
-- near edge all the way up, and hides wholly under it down. BANDS: the steps
-- the cover takes along the hole's near edge. TILE: field pixels per repeat
-- of a ground tile. The speeds are per second; HOLD: a bonked head's flinch.
local V = {
    W = 412, H = 500, MID = 206, HUD_H = 84,
    ROWS = {{y = 146, k = .86, dx = 120}, {y = 262, k = .93, dx = 128}, {y = 386, k = 1, dx = 136}},
    MOUND_W = 134, MOUND_H = 62, MOUND_Y = 11, HOLE_W = 88, HOLE_H = 29, LIP = 9,
    BODY_W = 80, BODY_H = 100, SHOWN = .68, BOSS = 1.25, BANDS = 8, TILE = 220,
    EDGE = 34, EDGE_ALPHA = .55,
    RISE = 1 / .09, DROP = 1 / .12, KNOCK = 1 / .07, HOLD = .1, FLASH = .15, DIZZY = .7,
    PEEK = .6, PEEK_HOLE = 5,
    BAR_W = 300, BAR_H = 12, BAR_Y = 476, HURRY = 5,
    VOICE_GAP = 1.1,
}
Whack.VIEW = V
local WALL_FLAT = {.16, .11, .08}
local GOLD, WHITE, RED = {1, .84, .3}, {.95, .95, .98}, {1, .35, .3}
local WORDS = {"Bonk!", "Whack!", "Bonk!", "Bop!"}

local function Num(value) return type(value) == "number" and value == value and value > -math.huge and value < math.huge end

-- A hole's sizes and spots in the field (see V), its row's depth applied.
-- top: the target's top all the way up (bossTop: a boss's); bottom: the
-- hole's near edge; c: half the width the cover hides (a boss's and a pixel).
function Whack.Spot(index)
    local row = math.floor((index - 1) / 3) + 1
    local R = V.ROWS[row]
    local k = R.k
    local g = {index = index, row = row, column = (index - 1) % 3 + 1, k = k, cx = V.MID + ((index - 1) % 3 - 1) * R.dx, cy = R.y}
    g.mw, g.mh, g.my = V.MOUND_W * k, V.MOUND_H * k, R.y + V.MOUND_Y * k
    g.hw, g.hh = V.HOLE_W * k, V.HOLE_H * k
    g.lw, g.lh = g.hw + V.LIP * k, g.hh + V.LIP * k * .5
    g.bw, g.bh = V.BODY_W * k, V.BODY_H * k
    g.bottom = g.cy + g.hh / 2
    g.top = g.bottom - g.bh * V.SHOWN
    g.bossTop = g.bottom - g.bh * V.BOSS * V.SHOWN
    g.c = g.bw * V.BOSS / 2 + 1
    return g
end

-- A texture at x, y in the field (from its top left, y down), w x h.
local function Put(texture, holder, x, y, w, h)
    texture:SetSize(w, h)
    texture:SetPoint("TOPLEFT", holder, "TOPLEFT", x, -y)
end
-- The first of a list of tiles the client loads on a texture, or false.
local function Pick(texture, ids)
    for _, id in ipairs(ids) do
        if texture:SetTexture(id, "REPEAT", "REPEAT") ~= false then return id end
    end
    return false
end
-- A texture or mask placed where it lies, never snapped to the screen's
-- pixels: the cover's pieces then meet the ground behind them exactly at any
-- interface scale.
local function Free(region)
    if type(region.SetSnapToPixelGrid) == "function" then pcall(region.SetSnapToPixelGrid, region, false) end
    if type(region.SetTexelSnappingBias) == "function" then pcall(region.SetTexelSnappingBias, region, 0) end
end
-- Ground on a texture at x, y, w x h: the tile laid as if over the whole
-- field, so pieces anywhere line up with each other; else the flat colour.
local function Dirt(texture, id, tint, flat, x, y, w, h)
    Free(texture)
    if id and texture:SetTexture(id, "REPEAT", "REPEAT") ~= false then
        texture:SetTexCoord(x / V.TILE, (x + w) / V.TILE, y / V.TILE, (y + h) / V.TILE)
        texture:SetVertexColor(tint[1], tint[2], tint[3], 1)
        return true
    end
    texture:SetColorTexture(flat[1], flat[2], flat[3], 1)
    return false
end
-- One part of the ground ("field", "mound", "lip" or "wall") painted in the
-- view's look, and kept (view.dirt) so a new look paints it again.
local PARTS = {field = {"field", "fieldTint", "fieldFlat"}, mound = {"mound", "moundTint", "moundFlat"},
    lip = {"mound", "lipTint", "moundFlat"}, wall = {"wall", "wallTint"}}
local function Paint(view, entry)
    local part, look = PARTS[entry.part], view.look
    Dirt(entry.texture, view.ids[part[1]], look[part[2]], part[3] and look[part[3]] or WALL_FLAT, entry.x, entry.y, entry.w, entry.h)
end
local function Ground(view, texture, part, x, y, w, h)
    local entry = {texture = texture, part = part, x = x, y = y, w = w, h = h}
    view.dirt = view.dirt or {}
    view.dirt[#view.dirt + 1] = entry
    Paint(view, entry)
end
-- An oval mask (the portrait mask's disc squashed) made by owner at cx, cy,
-- w x h, on a texture when given. nil when the client has no masks.
local function Oval(owner, texture, holder, cx, cy, w, h)
    if type(owner.CreateMaskTexture) ~= "function" then return nil end
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(Whack.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    Free(mask)
    Put(mask, holder, cx - w / 2, cy - h / 2, w, h)
    if texture and type(texture.AddMaskTexture) == "function" then texture:AddMaskTexture(mask) end
    return mask
end
local function Masked(texture, mask)
    if mask and type(texture.AddMaskTexture) == "function" then texture:AddMaskTexture(mask) end
end
-- A method of a client object through a protected call: whether it ran.
local function Try(object, method, ...)
    local fn = object and object[method]
    if type(fn) ~= "function" then return false end
    return (pcall(fn, object, ...))
end
Whack.Try = Try

-- The target's face on a texture: the portrait, else the race icon, else
-- the head's item icon. Returns which ("file", "atlas", "icon", "missing").
function Whack.PutArt(texture, target)
    if target.file and texture:SetTexture(target.file) ~= false then
        texture:SetTexCoord(0, 1, 0, 1)
        return "file"
    end
    local atlases = type(C_Texture) == "table" and C_Texture.GetAtlasInfo
    if target.atlas and type(texture.SetAtlas) == "function" and type(atlases) == "function" then
        local ok, info = pcall(atlases, target.atlas)
        if ok and info then
            texture:SetAtlas(target.atlas)
            return "atlas"
        end
    end
    if target.icon and texture:SetTexture(target.icon) ~= false then
        texture:SetTexCoord(.08, .92, .08, .92)
        return "icon"
    end
    return "missing"
end

local game = Whack.game or {}
Whack.game = game
game.state, game.clock = game.state or Whack.New(), game.clock or 0

function game:Target() return Whack.Target(MG.Faction()) end
function game:Title()
    local target = self:Target()
    return target.prefix, target.accent
end
function game:Score() return self.state.score end

-- The field's ground under everything, and the button that hears a click
-- that lands on no hole (a whiff). Its tiles, chosen once, go in view.ids.
local function Field(view)
    local holder, root, look = view.holder, view.root, view.look
    local base = root:CreateTexture(nil, "BACKGROUND")
    Put(base, holder, 0, 0, V.W, V.H)
    local probe = root:CreateTexture(nil, "BACKGROUND", nil, -8)
    probe:SetSize(1, 1)
    probe:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    view.ids = {field = Pick(base, look.field), mound = Pick(probe, look.mound), wall = Pick(probe, look.wall)}
    probe:Hide()
    view.probe = probe
    Ground(view, base, "field", 0, 0, V.W, V.H)
    view.ground = base
    local field = CreateFrame("Button", nil, root)
    field:SetSize(V.W, V.H)
    field:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    field:SetFrameLevel(holder:GetFrameLevel() + 1)
    field:RegisterForClicks("LeftButtonDown")
    field:SetScript("OnClick", function() game:Whack(nil) end)
    view.field = field
end

-- Behind the target: the mound, its lip, the hole's wall and its dark
-- depth, a soft light on the mound under the pointer, and the head's aura
-- (golden, your side's ring, the boss's red), which follows the head.
local function Back(view, hole)
    local g, holder = hole.g, view.holder
    local mound = hole:CreateTexture(nil, "BACKGROUND", nil, 1)
    local x, y = g.cx - g.mw / 2, g.my - g.mh / 2
    Put(mound, holder, x, y, g.mw, g.mh)
    Ground(view, mound, "mound", x, y, g.mw, g.mh)
    Oval(hole, mound, holder, g.cx, g.my, g.mw, g.mh)
    local lip = hole:CreateTexture(nil, "BACKGROUND", nil, 2)
    x, y = g.cx - g.lw / 2, g.cy - g.lh / 2
    Put(lip, holder, x, y, g.lw, g.lh)
    Ground(view, lip, "lip", x, y, g.lw, g.lh)
    Oval(hole, lip, holder, g.cx, g.cy, g.lw, g.lh)
    local wall = hole:CreateTexture(nil, "BORDER", nil, 1)
    x, y = g.cx - g.hw / 2, g.cy - g.hh / 2
    Put(wall, holder, x, y, g.hw, g.hh)
    Ground(view, wall, "wall", x, y, g.hw, g.hh)
    Oval(hole, wall, holder, g.cx, g.cy, g.hw, g.hh)
    -- The depth sits low in the hole, so its far wall shows above it.
    local depth = hole:CreateTexture(nil, "BORDER", nil, 2)
    local dw, dh, dy = g.hw * .9, g.hh * .68, g.cy + g.hh * .15
    Put(depth, holder, g.cx - dw / 2, dy - dh / 2, dw, dh)
    depth:SetColorTexture(.02, .014, .01, .96)
    Oval(hole, depth, holder, g.cx, dy, dw, dh)
    local glow = hole:CreateTexture(nil, "HIGHLIGHT")
    Put(glow, holder, g.cx - g.mw * .6, g.my - g.mh * .6, g.mw * 1.2, g.mh * 1.2)
    if glow:SetTexture(MG.ART.glow) == false then glow:Hide() end
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(1, .85, .55, .16)
    hole.aura = hole:CreateTexture(nil, "ARTWORK", nil, 1)
    hole.aura:SetSize(90 * g.k, 90 * g.k)
    hole.ring = hole:CreateTexture(nil, "ARTWORK", nil, 2)
    hole.ring:SetSize(70 * g.k, 70 * g.k)
    hole.aura:Hide()
    hole.ring:Hide()
    hole.mound, hole.lip, hole.wall, hole.depth = mound, lip, wall, depth
end

-- The camera on a hole's model, from its kind's framing (MiniGames:Tune, so
-- /era whack tune's saved values win): portrait zoom, distance, height, its
-- column's turn and the empty share under the picture. Again after every
-- model load (a load resets the camera).
local function Frame(view, hole)
    local model = hole.model
    if not model then return end
    local t = MG:Tune(hole.key or view.target.key)
    Try(model, "SetPortraitZoom", Num(t.zoom) and t.zoom or 0)
    Try(model, "SetCamDistanceScale", Num(t.cam) and t.cam or 1)
    Try(model, "SetPosition", 0, 0, Num(t.up) and t.up or 0)
    local turn, base = Num(t.turn) and t.turn or 0, Whack.MODEL.turns[hole.g.column] or 0
    Try(model, "SetRotation", turn ~= 0 and base + math.rad(turn) or base, false)
    Try(model, "SetViewInsets", 0, 0, 0, (hole.bodyH or hole.g.bh) * (Num(t.lift) and t.lift or 0))
end
Whack.Frame = Frame

-- The 3D model in a hole's target frame, or nil (the client can't, or
-- refuses both of the target's models): then every hole shows the portrait.
local function Model(view, hole, body)
    if not view.models then return nil end
    local g = hole.g
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, body)
    if not ok or type(model) ~= "table" or type(model.SetDisplayInfo) ~= "function" then
        view.models = false
        return nil
    end
    model:SetSize(g.bw, g.bh)
    model:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
    -- Its own level, between the target's frame and the cover in front.
    model:SetFrameLevel(body:GetFrameLevel() + 1)
    if type(model.EnableMouse) == "function" then model:EnableMouse(false) end
    -- Kept as the frame hides; a client that can't keep it keeps it shown
    -- (out of sight under the cover) instead.
    hole.keeps = Try(model, "SetKeepModelOnHide", true)
    local shown
    for _, id in ipairs(view.target.displays) do
        if pcall(model.SetDisplayInfo, model, id) then
            shown = id
            break
        end
    end
    if not shown then
        model:Hide()
        view.models = false
        return nil
    end
    hole.display, hole.displays = shown, {normal = shown, golden = shown}
    hole.model = model
    Frame(view, hole)
    model:SetScript("OnModelLoaded", function(self)
        Frame(view, hole)
        if hole.useModel then Try(self, "SetAnimation", hole.anim or 0) end
    end)
    return model
end

-- The target: a frame that slides up and down, holding the model or the
-- round portrait.
local function Body(view, hole, level)
    local g = hole.g
    local body = CreateFrame("Frame", nil, hole)
    body:SetSize(g.bw, g.bh)
    body:SetFrameLevel(level)
    body:SetPoint("TOPLEFT", view.holder, "TOPLEFT", g.cx - g.bw / 2, -g.bottom)
    local face = body:CreateTexture(nil, "ARTWORK")
    local size = g.bw * .86
    face:SetSize(size, size)
    face:SetPoint("TOP", body, "TOP", 0, -2 * g.k)
    hole.art = Whack.PutArt(face, view.target)
    if type(body.CreateMaskTexture) == "function" and type(face.AddMaskTexture) == "function" then
        local mask = body:CreateMaskTexture()
        mask:SetTexture(Whack.MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(face)
        face:AddMaskTexture(mask)
    end
    hole.body, hole.face = body, face
    hole.bodyW, hole.bodyH, hole.kind, hole.key = g.bw, g.bh, "normal", view.target.key
    hole.model = Model(view, hole, body)
    hole.aura:SetPoint("CENTER", body, "TOP", 0, -g.bh * .3)
    hole.ring:SetPoint("CENTER", body, "TOP", 0, -g.bh * .3)
    body:Hide()
end

-- One piece of the cover: the field, the mound and the lip as they lie
-- there (the same tiles, tints and masks as behind the target).
local function Piece(view, hole, cover, x, y, w, h)
    if w < .25 or h < .05 then return end
    local holder = view.holder
    local field = cover:CreateTexture(nil, "BACKGROUND", nil, 1)
    Put(field, holder, x, y, w, h)
    Ground(view, field, "field", x, y, w, h)
    local mound = cover:CreateTexture(nil, "BACKGROUND", nil, 2)
    Put(mound, holder, x, y, w, h)
    Ground(view, mound, "mound", x, y, w, h)
    Masked(mound, cover.moundMask)
    local lip = cover:CreateTexture(nil, "BACKGROUND", nil, 3)
    Put(lip, holder, x, y, w, h)
    Ground(view, lip, "lip", x, y, w, h)
    Masked(lip, cover.lipMask)
    cover.pieces[#cover.pieces + 1] = field
end
-- In front of the target: the ground below the hole's near edge across a
-- boss's width, down as far as a target sinks (never past the field), in steps
-- along the curve of the edge; then the mound's shadow and the shade on its front.
local function Cover(view, hole, level)
    local g, holder = hole.g, view.holder
    local deep = math.min(g.bh * V.BOSS + 2, V.H - g.bottom)
    local cover = CreateFrame("Frame", nil, hole)
    cover:SetSize(g.mw, g.hh / 2 + deep)
    cover:SetPoint("TOPLEFT", holder, "TOPLEFT", g.cx - g.mw / 2, -g.cy)
    cover:SetFrameLevel(level)
    cover.pieces = {}
    cover.moundMask = Oval(cover, nil, holder, g.cx, g.my, g.mw, g.mh)
    cover.lipMask = Oval(cover, nil, holder, g.cx, g.cy, g.lw, g.lh)
    local a, b, c = g.hw / 2, g.hh / 2, g.c
    local from = c < a and b * math.sqrt(1 - (c / a) ^ 2) or 0
    for band = 0, V.BANDS - 1 do
        local y0, y1 = from + (b - from) * band / V.BANDS, from + (b - from) * (band + 1) / V.BANDS
        -- The edge's width at the band's middle: under a pixel off at its top and bottom.
        local ym = (y0 + y1) / 2
        local inner = a * math.sqrt(math.max(0, 1 - (ym / b) ^ 2))
        if inner < .5 then
            Piece(view, hole, cover, g.cx - c, g.cy + y0, 2 * c, y1 - y0)
        else
            Piece(view, hole, cover, g.cx - c, g.cy + y0, c - inner, y1 - y0)
            Piece(view, hole, cover, g.cx + inner, g.cy + y0, c - inner, y1 - y0)
        end
    end
    Piece(view, hole, cover, g.cx - c, g.bottom, 2 * c, deep)
    local shadow = cover:CreateTexture(nil, "BORDER")
    local sw, sh, sy = g.mw * 1.2, g.mh * .8, g.my + g.mh * .5
    Put(shadow, holder, g.cx - sw / 2, sy - sh / 2, sw, sh)
    if shadow:SetTexture(MG.ART.glow) == false then shadow:Hide() end
    shadow:SetVertexColor(0, 0, 0, .5)
    local shade = cover:CreateTexture(nil, "ARTWORK")
    Put(shade, holder, g.cx - g.mw / 2, g.cy, g.mw, g.my + g.mh / 2 - g.cy)
    MG.Gradient(shade, "VERTICAL", 0, 0, 0, .42, 0, 0, 0, 0)
    Masked(shade, cover.moundMask)
    hole.cover, hole.shade = cover, shade
end

-- Over everything of a hole: where its effects start (spot: the head all
-- the way up; mouth: the hole) and the stars of a bonked head.
local function Over(view, hole, level)
    local g, holder = hole.g, view.holder
    local over = CreateFrame("Frame", nil, hole)
    over:SetSize(g.mw, g.bh)
    over:SetPoint("TOPLEFT", holder, "TOPLEFT", g.cx - g.mw / 2, -g.top)
    over:SetFrameLevel(level)
    local spot = over:CreateTexture(nil, "OVERLAY")
    Put(spot, holder, g.cx - 1, g.top + g.bh * .2 - 1, 2, 2)
    spot:SetColorTexture(0, 0, 0, 0)
    local mouth = over:CreateTexture(nil, "OVERLAY")
    Put(mouth, holder, g.cx - 1, g.cy - 1, 2, 2)
    mouth:SetColorTexture(0, 0, 0, 0)
    hole.stars = {}
    for index = 1, 3 do
        local star = over:CreateTexture(nil, "OVERLAY", nil, 1)
        star:SetSize(12 * g.k, 12 * g.k)
        if star:SetTexture(MG.ART.star) == false then star:SetColorTexture(1, .85, .3, 1) end
        star:Hide()
        hole.stars[index] = star
    end
    hole.over, hole.spot, hole.mouth = over, spot, mouth
end

-- Each row takes five frame levels (the hole, the target, its model, the
-- cover, the stars), the back row lowest; the field's button under them all.
-- A hole's button reaches from a boss's head all the way up to its mound's foot.
local ROW_LEVELS = 5
Whack.ROW_LEVELS = ROW_LEVELS
local function MakeHole(view, index)
    local holder = view.holder
    local g = Whack.Spot(index)
    local base = holder:GetFrameLevel() + 2 + (g.row - 1) * ROW_LEVELS
    local hole = CreateFrame("Button", nil, view.root)
    local top, bottom = g.bossTop - 6 * g.k, g.my + g.mh / 2
    hole:SetSize(g.mw, bottom - top)
    hole:SetPoint("TOPLEFT", holder, "TOPLEFT", g.cx - g.mw / 2, -top)
    hole:SetFrameLevel(base)
    hole.g, hole.index, hole.view = g, index, view
    hole.up, hole.hold, hole.dizzy, hole.flash, hole.knocked = 0, 0, 0, 0, false
    Back(view, hole)
    Body(view, hole, base + 1)
    Cover(view, hole, base + 3)
    Over(view, hole, base + 4)
    hole:RegisterForClicks("LeftButtonDown")
    hole:SetScript("OnClick", function(self) game:Whack(self.index) end)
    return hole
end

-- The field's edges in shadow, over every row.
local function Edges(view, level)
    local holder = view.holder
    local frame = CreateFrame("Frame", nil, view.root)
    frame:SetSize(V.W, V.H)
    frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    frame:SetFrameLevel(level)
    local e, a = V.EDGE, V.EDGE_ALPHA
    local sides = {
        {0, 0, V.W, e, "VERTICAL", 0, a}, {0, V.H - e, V.W, e, "VERTICAL", a, 0},
        {0, 0, e, V.H, "HORIZONTAL", a, 0}, {V.W - e, 0, e, V.H, "HORIZONTAL", 0, a},
    }
    frame.sides = {}
    for index, side in ipairs(sides) do
        local shade = frame:CreateTexture(nil, "ARTWORK")
        Put(shade, holder, side[1], side[2], side[3], side[4])
        MG.Gradient(shade, side[5], 0, 0, 0, side[6], 0, 0, 0, side[7])
        frame.sides[index] = shade
    end
    view.edges = frame
end

-- The round's time: a bar in the field's foreground, in your class colour
-- (red for the last seconds), its seconds on it and a spark at its end.
local function PaintBar(view, hurry)
    local fill = view.timer.fill
    local r, g, b = view.colour[1], view.colour[2], view.colour[3]
    if hurry then r, g, b = .9, .2, .14 end
    MG.Gradient(fill, "VERTICAL", r * .62, g * .62, b * .62, 1, r, g, b, 1)
end
local function Timer(view, level)
    local holder = view.holder
    local frame = CreateFrame("Frame", nil, view.root)
    local w, h = V.BAR_W + 4, V.BAR_H + 4
    frame:SetSize(w, h)
    frame:SetPoint("TOPLEFT", holder, "TOPLEFT", V.MID - w / 2, -(V.BAR_Y - h / 2))
    frame:SetFrameLevel(level)
    local metal = view.metal
    local rim = frame:CreateTexture(nil, "BACKGROUND")
    rim:SetSize(w, h)
    rim:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    rim:SetColorTexture(metal[1] * .6, metal[2] * .6, metal[3] * .6, 1)
    local track = frame:CreateTexture(nil, "BORDER")
    track:SetSize(V.BAR_W, V.BAR_H)
    track:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    track:SetColorTexture(.03, .03, .035, .94)
    local fill = frame:CreateTexture(nil, "ARTWORK")
    fill:SetSize(V.BAR_W, V.BAR_H)
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    local sheen = frame:CreateTexture(nil, "ARTWORK", nil, 1)
    sheen:SetHeight(V.BAR_H / 2)
    sheen:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 0)
    sheen:SetPoint("TOPRIGHT", fill, "TOPRIGHT", 0, 0)
    sheen:SetColorTexture(1, 1, 1, .14)
    local spark = frame:CreateTexture(nil, "OVERLAY")
    spark:SetSize(10, V.BAR_H * 2.4)
    spark:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    if spark:SetTexture(MG.ART.castSpark) == false then spark:SetColorTexture(1, 1, 1, .6) end
    spark:SetBlendMode("ADD")
    spark:Hide()
    local label = MG.Text(frame, tostring(Whack.ROUND), 11, false, true)
    label:SetJustifyH("CENTER")
    label:SetPoint("CENTER", track, "CENTER", 0, 0)
    view.timer = {frame = frame, track = track, fill = fill, spark = spark, label = label}
    PaintBar(view, false)
end

-- The mallet ----------------------------------------------------------------------------------

-- The mallet, ellipses cut from the portrait mask's disc, turned together:
-- {along the handle from the grip, across it, length, thickness, alpha}; its
-- colours come from the skin (Whack.SKINS, part names in Whack.SKIN_PARTS).
local MALLET = {
    {20, 0, 42, 5, 1},          -- the handle
    {21, .8, 36, 1.6, .85},     -- its shine
    {5, 0, 12, 6.4, 1},         -- the grip
    {40, 0, 16, 28, 1},         -- the head
    {37.5, 0, 5, 22, .8},       -- its shine
    {40, -7.5, 16.6, 2.4, 1},   -- its bands
    {40, 7.5, 16.6, 2.4, 1},
    {40, 12.5, 14.5, 6, 1},     -- the face it strikes with
}
-- The striking face's middle (along, across): it rests on the pointer's tip.
local FACE = {MALLET[8][1], MALLET[8][2]}
-- The swing in radians (counter-clockwise from pointing right; the face looks
-- a quarter turn on from the handle, so a turn the other way lifts it):
-- resting, lifted, slammed a little past rest, then settled back on it; and
-- each part's seconds. The face sits on the pointer at rest and at the strike.
local SWING = {rest = math.rad(125), raise = math.rad(85), over = math.rad(131), up = .06, slam = .05, settle = .08}
Whack.MALLET, Whack.SWING, Whack.FACE = MALLET, SWING, FACE
-- Where the grip is from the pointer (x right, y down), so the face's middle
-- is on it at the resting angle.
local GRIP
do
    local c, s, hx, hy = math.cos(SWING.rest), math.sin(SWING.rest), FACE[1], FACE[2]
    GRIP = {-(hx * c - hy * s), hx * s + hy * c}
end
Whack.GRIP = GRIP
-- The angle this long into a swing, or nil once it's over.
function Whack.SwingAngle(t)
    if t < SWING.up then
        local q = t / SWING.up
        return SWING.rest + (SWING.raise - SWING.rest) * q * q
    end
    t = t - SWING.up
    if t < SWING.slam then return SWING.raise + (SWING.over - SWING.raise) * t / SWING.slam end
    t = t - SWING.slam
    if t < SWING.settle then
        local q = 1 - t / SWING.settle
        return SWING.rest + (SWING.over - SWING.rest) * q * q
    end
    return nil
end
-- Where a part's middle is (x right, y down in the field) with the pointer at
-- x, y and the mallet turned to angle.
function Whack.PartAt(x, y, angle, along, across)
    local c, s = math.cos(angle), math.sin(angle)
    local gx, gy = x + GRIP[1], y + GRIP[2]
    return gx + along * c - across * s, gy - (along * s + across * c)
end
local function Mallet(view, level)
    local holder = view.holder
    local frame = CreateFrame("Frame", nil, view.root)
    frame:SetSize(V.W, V.H)
    -- Pinned by two corners, as Forever wants of a frame that clips.
    frame:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", holder, "TOPLEFT", V.W, -V.H)
    frame:SetFrameLevel(level)
    -- Cut at the field's edges (only the mallet: no model is ever in a clipping frame).
    if type(frame.SetClipsChildren) == "function" then frame:SetClipsChildren(true) end
    frame.parts = {}
    -- A soft light on the head of the frost and felfire mallets.
    frame.glow = frame:CreateTexture(nil, "ARTWORK")
    frame.glow:SetSize(44, 44)
    if frame.glow:SetTexture(MG.ART.glow) == false then frame.glow:SetColorTexture(1, 1, 1, .2) end
    frame.glow:SetBlendMode("ADD")
    frame.glow:Hide()
    for index, part in ipairs(MALLET) do
        local texture = frame:CreateTexture(nil, "OVERLAY", nil, math.min(7, index - 1))
        texture:SetSize(part[3], part[4])
        if texture:SetTexture(Whack.MASK) == false then frame.broken = true end
        frame.parts[index] = texture
    end
    -- Where a whiff on the open field puffs its dust.
    frame.spot = frame:CreateTexture(nil, "OVERLAY")
    frame.spot:SetSize(2, 2)
    frame.spot:SetPoint("CENTER", frame, "TOPLEFT", V.MID, -V.H / 2)
    frame.spot:SetColorTexture(0, 0, 0, 0)
    frame:Hide()
    view.mallet = frame
end
-- The mallet in a skin's colours (an unknown one: the wooden mallet).
function game:PaintMallet(id)
    local frame = self.mallet
    if not frame then return end
    local P = MG.Progress
    id = id or (P and P:Mallet()) or "wood"
    local skin = Whack.Skin(id)
    self.skin = skin.id
    for index, part in ipairs(MALLET) do
        local colour = skin[Whack.SKIN_PARTS[index]] or WHITE
        frame.parts[index]:SetVertexColor(colour[1], colour[2], colour[3], part[5])
    end
    local face = skin.face or WHITE
    frame.glow:SetVertexColor(face[1], face[2], face[3], .5)
    frame.glow:SetShown(skin.glow == true)
    self.poseAngle = nil
end
-- The mallet turned to angle, its grip placed for the pointer at aim.
local function PoseMallet(view, angle)
    local frame = view.mallet
    for index = 1, #MALLET do
        local part, texture = MALLET[index], frame.parts[index]
        local x, y = Whack.PartAt(view.aimX, view.aimY, angle, part[1], part[2])
        texture:SetPoint("CENTER", frame, "TOPLEFT", x, -y)
        texture:SetRotation(angle)
    end
    local hx, hy = Whack.PartAt(view.aimX, view.aimY, angle, MALLET[4][1], MALLET[4][2])
    frame.glow:SetPoint("CENTER", frame, "TOPLEFT", hx, -hy)
end
-- The pointer in the field (x right, y down from its top left), or nil when
-- it isn't over the field (or the client won't say).
local function Pointer(view)
    local holder = view.holder
    if type(GetCursorPosition) ~= "function" or type(holder.IsMouseOver) ~= "function" then return nil end
    local ok, over = pcall(holder.IsMouseOver, holder)
    if not ok or over ~= true then return nil end
    local x, y = GetCursorPosition()
    local scale, left, top = holder:GetEffectiveScale(), holder:GetLeft(), holder:GetTop()
    if not (Num(x) and Num(y) and Num(scale) and scale > 0 and Num(left) and Num(top)) then return nil end
    return x / scale - left, top - y / scale
end
-- One frame of the mallet: over the field it sits on the pointer every
-- frame, swinging when clicked; off it, it hides (a swing started by a click
-- finishes where it was).
local function DrawMallet(view, dt)
    local frame = view.mallet
    if not frame or frame.broken then return end
    local x, y = Pointer(view)
    local angle = SWING.rest
    if view.swingT then
        view.swingT = view.swingT + dt
        local swung = Whack.SwingAngle(view.swingT)
        if swung then angle = swung else view.swingT = nil end
    end
    if x then view.aimX, view.aimY = x, y end
    local on = view.aimX ~= nil and (x ~= nil or view.swingT ~= nil)
    if on ~= frame:IsShown() then frame:SetShown(on) end
    if on and (angle ~= view.poseAngle or view.aimX ~= view.poseX or view.aimY ~= view.poseY) then
        view.poseAngle, view.poseX, view.poseY = angle, view.aimX, view.aimY
        PoseMallet(view, angle)
    end
end

-- One frame of the timer: its width, its seconds (a click on each of the
-- last three) and its colour.
local function DrawTimer(view, state)
    local timer = view.timer
    local playing = state.phase == "playing"
    local length = state.length or Whack.ROUND
    local left = (state.phase == "ready" or state.phase == "countdown") and length or state.left
    local share = math.max(0, math.min(1, left / length))
    local width = math.floor(V.BAR_W * share * 2 + .5) / 2
    if width ~= timer.width then
        timer.width = width
        timer.fill:SetShown(width >= .5)
        timer.spark:SetShown(width >= .5 and share < 1)
        if width >= .5 then timer.fill:SetWidth(width) end
    end
    local seconds = math.max(0, math.ceil(left - 1e-9))
    if seconds ~= timer.seconds then
        if playing and timer.seconds and seconds >= 1 and seconds <= 3 then MG:Sound("uiClick") end
        timer.seconds = seconds
        timer.label:SetText(tostring(seconds))
    end
    local hurry = playing and left <= V.HURRY
    if hurry ~= timer.hurry then
        timer.hurry = hurry
        PaintBar(view, hurry)
    end
end
function game:DrawTimer() if self.timer then DrawTimer(self, self.state) end end

-- The holes ---------------------------------------------------------------------------------

-- What a hole's model does now (anim: an AnimationData ID).
local function Animate(hole, anim)
    hole.anim = anim
    if hole.useModel and hole.modelOk and hole.model then Try(hole.model, "SetAnimation", anim) end
end
-- A portrait's colour: red for a bonked head's flinch, gold for a golden one.
local function Tint(hole, hit)
    if hit then hole.face:SetVertexColor(1, .55, .55)
    elseif hole.kind == "golden" then hole.face:SetVertexColor(1, .86, .4)
    else hole.face:SetVertexColor(1, 1, 1) end
end
-- The model or the portrait, whichever the hole shows for its kind.
local function Picture(hole)
    local model = hole.useModel and hole.modelOk
    if hole.model then hole.model:SetShown(model and true or false) end
    hole.face:SetShown(not model)
end
-- The aura behind a head of this kind: gold for a golden one, your side's
-- colour and a ring for a decoy, red for the boss; none for the rest.
local function Aura(view, hole, kind)
    local aura, ring, k = hole.aura, hole.ring, hole.g.k
    ring:Hide()
    if kind == "golden" then
        aura:SetSize(90 * k, 90 * k)
        MG:Art(aura, "whack.golden", {plain = true})
        aura:SetVertexColor(Whack.AURA.golden[1], Whack.AURA.golden[2], Whack.AURA.golden[3], 1)
    elseif kind == "decoy" or kind == "boss" then
        local colour = kind == "boss" and Whack.AURA.boss or (Whack.SIDE[MG.Faction()] or Whack.SIDE.Horde)
        aura:SetSize((kind == "boss" and 120 or 84) * k, (kind == "boss" and 120 or 84) * k)
        if aura:SetTexture(MG.ART.glow) == false then aura:SetColorTexture(colour[1], colour[2], colour[3], .3) end
        aura:SetTexCoord(0, 1, 0, 1)
        aura:SetVertexColor(colour[1], colour[2], colour[3], .8)
        aura:Show()
        if kind == "decoy" then
            if ring:SetTexture(MG.ART.ring) == false then ring:SetColorTexture(colour[1], colour[2], colour[3], .4) end
            ring:SetTexCoord(0, 1, 0, 1)
            ring:SetBlendMode("ADD")
            ring:SetVertexColor(colour[1], colour[2], colour[3], .95)
            ring:Show()
        end
    else
        aura:Hide()
        return
    end
    aura:SetBlendMode("ADD")
end
-- The model's display for a kind, tried once per hole and kept: the target's
-- own for a normal or golden head, the decoy's or the boss's role. false when
-- the client refuses them all (that kind shows its portrait).
local function Display(view, hole, kind)
    local id = hole.displays[kind]
    if id ~= nil then
        if id and hole.display ~= id and pcall(hole.model.SetDisplayInfo, hole.model, id) then hole.display = id end
        return id
    end
    local ok, shown = MG:Model(hole.model, "whack." .. Whack.KindKey(view.target, kind))
    hole.displays[kind] = ok and shown or false
    if ok then hole.display = shown end
    return hole.displays[kind]
end
-- A hole gets ready for a kind of head: its frame's size, its model's
-- display and framing, its portrait, its aura.
function game:SetKind(hole, kind)
    kind = kind or "normal"
    if hole.kind == kind then return end
    hole.kind = kind
    hole.key = Whack.KindKey(self.target, kind)
    local tune = MG:Tune(hole.key)
    local size = Num(tune.body) and tune.body or 1
    local g = hole.g
    hole.bodyW, hole.bodyH = g.bw * size, g.bh * size
    hole.body:SetSize(hole.bodyW, hole.bodyH)
    hole.face:SetSize(hole.bodyW * .86, hole.bodyW * .86)
    if hole.model then
        hole.model:SetSize(hole.bodyW, hole.bodyH)
        hole.modelOk = Display(self, hole, kind) and true or false
        Frame(self, hole)
    end
    if kind == "normal" or kind == "golden" then
        hole.art = Whack.PutArt(hole.face, self.target)
    else
        MG:Art(hole.face, "whack." .. hole.key)
        hole.face:SetShown(true)
    end
    Picture(hole)
    Tint(hole, false)
    hole.aura:SetPoint("CENTER", hole.body, "TOP", 0, -hole.bodyH * .3)
    hole.ring:SetPoint("CENTER", hole.body, "TOP", 0, -hole.bodyH * .3)
    Aura(self, hole, kind)
    hole.y = nil
end
-- Every hole's framing again (after /era whack tune).
function game:Reframe()
    for _, hole in ipairs(self.holes or {}) do
        local kind = hole.kind
        hole.kind = nil
        self:SetKind(hole, kind)
    end
end

-- A head eased out of its hole: quick, a little past where it stops, then
-- settling (p: 0 to 1 of the way). Back down: smoothly, never up first.
local function Rise(p)
    local t = p - 1
    return 1 + 2.4 * t * t * t + 1.4 * t * t
end
local function Sink(p) return p * p * (3 - 2 * p) end
-- How far up the head shows (share: 1 all the way, a peek less), eased
-- from where it was (from, at up = start) towards goal.
local function Height(hole)
    local goal, start = hole.goal or 0, hole.start or 0
    if goal == start then return goal end
    local p = math.max(0, math.min(1, (hole.up - start) / (goal - start)))
    local from = hole.from or 0
    return from + (goal - from) * (goal > start and Rise(p) or Sink(p))
end
local function Place(view, hole)
    local g = hole.g
    hole.share = Height(hole)
    hole.y = g.bottom - hole.bodyH * V.SHOWN * hole.share
    hole.body:SetPoint("TOPLEFT", view.holder, "TOPLEFT", g.cx - hole.bodyW / 2, -hole.y)
end
-- A target shows only while it's up; a model the client can't keep while
-- hidden stays shown, down under its cover.
local function Reveal(hole, on)
    if hole.revealed == on then return end
    if not on and hole.useModel and not hole.keeps then return end
    hole.revealed = on
    hole.body:SetShown(on)
    if not on then return end
    -- A model the client let go of while hidden is set again.
    local model = hole.useModel and hole.modelOk and hole.model
    if model and type(model.GetDisplayInfo) == "function" then
        local ok, id = pcall(model.GetDisplayInfo, model)
        if not ok or id ~= hole.display then Try(model, "SetDisplayInfo", hole.display) end
        Frame(hole.view, hole)
    end
    Animate(hole, hole.anim or 0)
end
-- One frame of a hole: its head eased towards goal (1 up, a peek, 0
-- down), held a moment when bonked, then knocked down quicker than it ducks.
-- A new goal eases on from where the head shows now, so it never jumps.
local function MoveHole(view, hole, goal, dt)
    if hole.flash > 0 then
        hole.flash = hole.flash - dt
        if hole.flash <= 0 then Tint(hole, false) end
    end
    if goal ~= hole.goal then
        hole.from, hole.start, hole.goal = hole.share or 0, hole.up, goal
    end
    if hole.hold > 0 then
        hole.hold = hole.hold - dt
        if hole.hold > 0 then return end
        dt = -hole.hold
        hole.hold = 0
    end
    local up = hole.up
    if up < goal then up = math.min(goal, up + V.RISE * dt)
    elseif up > goal then up = math.max(goal, up - (hole.knocked and V.KNOCK or V.DROP) * dt) end
    if up == hole.up and hole.y then return end
    hole.up = up
    Reveal(hole, up > 0)
    Place(view, hole)
end
-- One frame of a bonked head's stars, circling where its head was.
local function Dizzy(view, hole, dt)
    hole.dizzy = math.max(0, hole.dizzy - dt)
    local stars, g = hole.stars, hole.g
    if hole.dizzy <= 0 then
        for index = 1, #stars do stars[index]:Hide() end
        return
    end
    local spin, alpha = (V.DIZZY - hole.dizzy) * 9, math.min(1, hole.dizzy / V.DIZZY * 3)
    for index = 1, #stars do
        local star, turn = stars[index], spin + index * 2.0944
        star:SetPoint("CENTER", view.holder, "TOPLEFT", g.cx + math.cos(turn) * 17 * g.k, -(g.top + 4 * g.k + math.sin(turn) * 5 * g.k))
        star:SetAlpha(alpha)
        star:Show()
    end
end

function game:DrawHoles(dt)
    local state, holes = self.state, self.holes
    local idle = state.phase == "ready" or state.phase == "over"
    local peek = Num(self.peek) and self.peek or V.PEEK
    local glow = .75 + .25 * math.sin(self.clock * 7)
    for index = 1, #holes do
        local hole = holes[index]
        local goal = (state.hole == index or state.hole2 == index) and 1 or 0
        -- Between rounds one peeks out of the middle hole.
        if idle and index == V.PEEK_HOLE then
            goal = peek
            if hole.kind ~= "normal" and hole.up <= 0 then self:SetKind(hole, "normal") end
            local anim = state.phase == "over" and Whack.MODEL.laugh or Whack.MODEL.idle
            if hole.anim ~= anim then Animate(hole, anim) end
        end
        MoveHole(self, hole, goal, dt)
        if hole.dizzy > 0 then Dizzy(self, hole, dt) end
        if hole.kind == "golden" and hole.aura:IsShown() then hole.aura:SetAlpha(glow) end
    end
end

-- Each hole shows its model (when it has one) or its portrait.
local function UseModels(view, on)
    for _, hole in ipairs(view.holes or {}) do
        hole.useModel = on and hole.model ~= nil
        if hole.modelOk == nil then hole.modelOk = hole.model ~= nil end
        Picture(hole)
        if hole.useModel then Animate(hole, hole.anim or 0) end
    end
end
-- Models on or off (portraits instead), live: /run EraUI.MiniGames.Whack.Models(false)
function Whack.Models(on)
    Whack.models = on ~= false
    UseModels(game, Whack.models)
end
-- The field in the look of stage n's page (Whack.PageZone), painted again
-- only when it changes (a Quick round: n 1, the target's home).
function game:PaintGround(n)
    if not (self.dirt and self.probe) then return end
    local zone = Whack.PageZone(self.target, n)
    if zone == (self.groundZone or self.target.zone) then return end
    self.groundZone = zone
    local look = Whack.Look(self.target, zone)
    self.look = look
    local probe = self.probe
    self.ids = {field = Pick(probe, look.field), mound = Pick(probe, look.mound), wall = Pick(probe, look.wall)}
    for _, entry in ipairs(self.dirt) do Paint(self, entry) end
end

function game:Build(shell, holder, bar)
    self.holder, self.target = holder, self:Target()
    self.look = self.target.ground
    self.models = true -- tried for every hole; the client may refuse (portraits then)
    self.metal = shell.metal or {.7, .58, .36}
    local r, g, b = MG.Colour()
    self.colour = {r, g, b}
    -- Big words in a lighter shade of it, so a dark class colour still reads.
    self.textColour = {r + (1 - r) * .4, g + (1 - g) * .4, b + (1 - b) * .4}
    -- Everything of the field in one frame, hidden while the stage map shows.
    local root = CreateFrame("Frame", nil, holder)
    root:SetSize(V.W, V.H)
    root:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    self.root = root
    Field(self)
    self.holes = {}
    for index = 1, Whack.HOLES do self.holes[index] = MakeHole(self, index) end
    local top = holder:GetFrameLevel() + 2 + #V.ROWS * ROW_LEVELS
    Edges(self, top)
    if self.MakeHud then self:MakeHud(top + 1) end
    Timer(self, top + 2)
    Mallet(self, top + 3)
    self:PaintMallet()
    UseModels(self, Whack.models ~= false)
    self.button = MG.Button(bar, "Start", 110, 28)
    self.button:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    self.button:SetScript("OnClick", function() game:Press() end)
    self.mapButton = MG.Button(bar, "Map", 64, 28)
    self.mapButton:SetPoint("RIGHT", bar, "RIGHT", -116, 0)
    self.mapButton:SetScript("OnClick", function() MG:Sound("uiClick"); game:ToMap() end)
    self.shopButton = MG.Button(bar, "Shop", 70, 28)
    self.shopButton:SetPoint("RIGHT", bar, "RIGHT", -116, 0)
    self.shopButton:SetScript("OnClick", function() MG:Sound("uiClick"); game:OpenShop() end)
    if self.MakeMap then self:MakeMap() end
    self.screen = self.screen or "quick"
    self:Label()
end

-- A voice line from the target (its voice key): with a chance, only that
-- often and never close on another; always without one.
function game:Voice(key, chance)
    local voice = self.target and self.target.voice[key]
    if not voice then return false end
    if chance and (self.clock - (self.voiceAt or -99) < V.VOICE_GAP or MG.Jitter() > chance) then return false end
    if type(voice) == "table" then voice = voice[math.floor(MG.Jitter() * #voice) + 1] end
    if MG:Sound(voice) then
        self.voiceAt = self.clock
        return true
    end
    return false
end

-- Every hole back down and calm, for a new round.
function game:Calm()
    for _, hole in ipairs(self.holes or {}) do
        hole.knocked, hole.hold, hole.dizzy, hole.flash = false, 0, 0, 0
        for _, star in ipairs(hole.stars) do star:Hide() end
        Tint(hole, false)
    end
end

-- The 3, 2, 1 and the start.
function game:Count(seconds)
    MG:Banner(tostring(seconds), {size = 46, life = .85, from = 2.2, glow = self.colour})
    MG:Sound("uiClick")
end
function game:Go()
    MG:Banner("Whack!", {size = 36, life = .75, colour = self.textColour, glow = GOLD})
    MG:Sound("whoosh")
    self:Voice("go")
end

-- The mallet swings at the pointer, else at the hole (or the field's middle).
function game:Swing(hole)
    local x, y = Pointer(self)
    if not x then
        if hole then x, y = hole.g.cx, hole.g.top + hole.g.bh * .2 else x, y = V.MID, V.H / 2 end
    end
    self.aimX, self.aimY, self.swingT = x, y, 0
    local mallet = self.mallet
    if mallet and not mallet.broken then
        mallet.spot:SetPoint("CENTER", mallet, "TOPLEFT", x, -y)
        mallet:Show()
        self.poseAngle, self.poseX, self.poseY = SWING.rest, x, y
        PoseMallet(self, SWING.rest)
    end
end

-- A head bonked: the points, its flinch and stars, a burst, words and sounds
-- (a golden one: coins and gold sparks too).
function game:Bonked(hole, kind)
    local state, k = self.state, hole.g.k
    local streak = state.streak
    local word = Whack.StreakWord(streak)
    hole.knocked, hole.hold, hole.dizzy = true, V.HOLD, V.DIZZY
    Tint(hole, true)
    Animate(hole, word and Whack.MODEL.crit or Whack.MODEL.hit)
    MG:SetScore(state.score)
    MG:Sound("squish")
    if word then
        MG:Sound("boing")
        MG:Sound("chain", streak / 5)
        self:Voice("crit")
    else
        self:Voice("hit", .4)
    end
    MG:Burst(hole.spot, {count = word and 18 or 11, texture = MG.ART.bursts, coords = MG.QUARTER.yellow,
        size = 15 * k, speed = 150, life = .45, gravity = 220, spin = .6})
    MG:Pulse(hole.spot, {texture = MG.ART.starburst, w = 70 * k, h = 70 * k, colour = GOLD, alpha = .95, life = .26, grow = 1.5})
    if kind == "golden" then
        MG:Sound("coins")
        MG:Burst(hole.spot, {count = 16, texture = MG.ART.sparkleGold, blend = "BLEND", size = 14 * k, speed = 130, life = .7, gravity = 90})
        MG:FloatText(hole.spot, "+3", {size = math.floor(22 * k + 2), colour = GOLD, y = 10, rise = 34, life = .8})
    else
        MG:FloatText(hole.spot, WORDS[(state.bonks - 1) % #WORDS + 1], {size = math.floor(20 * k + 2), colour = GOLD, y = 10, rise = 30, life = .7})
    end
    if word then
        MG:FloatText(hole.spot, word, {size = 22, colour = self.textColour, y = -14, rise = 40, life = 1.1, pop = 1.8})
        MG:Shake(5, .25)
    else
        if streak >= 3 then MG:FloatText(hole.spot, streak .. " in a row", {size = 12, colour = WHITE, y = -10, rise = 22, life = .8}) end
        MG:Shake(2, .12)
    end
end
-- One of your own side hit: points lost, a boing and his complaint.
function game:HitDecoy(hole)
    hole.knocked, hole.hold, hole.flash = true, V.HOLD, V.FLASH
    Tint(hole, true)
    Animate(hole, Whack.MODEL.hit)
    MG:SetScore(self.state.score, true)
    MG:Sound("boing")
    self:Voice("decoy")
    MG:FloatText(hole.spot, "-3", {size = 22, colour = RED, y = 10, rise = 30, life = .8})
    MG:Note("Oops, that's one of yours!")
    MG:Shake(3, .15)
end
-- The boss hit: he flinches, ducks and comes up in another hole (the
-- rules' state.hole); the third hit in a row beats him.
function game:HitBoss(hole, result)
    local k = hole.g.k
    MG:SetScore(self.state.score)
    MG:Burst(hole.spot, {count = 12, texture = MG.ART.bursts, coords = MG.QUARTER.red, size = 16 * k, speed = 160, life = .45, gravity = 200})
    if result == "bossBeaten" then
        hole.knocked, hole.hold, hole.dizzy = true, V.HOLD, V.DIZZY
        Tint(hole, true)
        Animate(hole, Whack.MODEL.crit)
        MG:Sound("bossDown")
        MG:Burst(hole.spot, {count = 30, texture = MG.ART.sparkleGold, blend = "BLEND", size = 16, speed = 180, life = 1, gravity = 120})
        MG:FloatText(hole.spot, "Beaten! +7", {size = 22, colour = GOLD, y = -10, rise = 40, life = 1.1, pop = 1.8})
        MG:Shake(7, .35)
        return
    end
    hole.knocked, hole.hold, hole.flash = true, V.HOLD, V.FLASH
    Tint(hole, true)
    Animate(hole, Whack.MODEL.hit)
    MG:Sound("bossHit")
    MG:Sound("squish")
    MG:FloatText(hole.spot, "+2", {size = 20, colour = GOLD, y = 10, rise = 28, life = .7})
    MG:Shake(3, .15)
    local to = self.state.hole
    if to and to ~= hole.index and self.holes[to] then self:Popped(to, "boss", true) end
end

-- A click that hit nothing: a whiff of air and a puff of dust.
function game:Whiff(hole)
    MG:Sound("whoosh")
    local at, k = self.mallet and self.mallet.spot, 1
    if hole then at, k = hole.mouth, hole.g.k end
    MG:Burst(at, {count = 6, texture = MG.ART.smokeToon, blend = "BLEND", colour = self.look.dust, size = 16 * k,
        speed = 36, life = .5, alpha = .55, shrink = 0, angle = math.pi / 2, spread = math.pi * .8})
end

-- A click on a hole (index), or on the open field (nil). Returns what it hit, or false.
function game:Whack(index)
    local state = self.state
    local hole = index and self.holes and self.holes[index] or nil
    self:Swing(hole)
    local result = index and Whack.Hit(state, index) or false
    if result and hole then
        if result == "decoy" then self:HitDecoy(hole)
        elseif result == "bossHit" or result == "bossBeaten" then self:HitBoss(hole, result)
        else self:Bonked(hole, result) end
        if self.PaintHud then self:PaintHud() end
        return result
    end
    Whack.Miss(state)
    self:Whiff(hole)
    return false
end

-- A head comes up: a fresh face of its kind, maybe a word from it. hop: the
-- boss again in another hole after a hit (no words).
function game:Popped(index, kind, hop)
    local hole = self.holes[index]
    hole.knocked, hole.hold, hole.flash = false, 0, 0
    self:SetKind(hole, kind)
    Tint(hole, false)
    local pops = Whack.MODEL.pop
    Animate(hole, pops[(self.state.pops - 1) % #pops + 1])
    if hop then
        MG:Sound("whoosh")
    elseif kind == "decoy" then
        self:Voice("decoy", .5)
    elseif kind == "boss" then
        self:Voice("boss")
        MG:FloatText(hole.spot, "Boss " .. self.target.accent .. "!", {size = 20, colour = RED, y = -16, rise = 26, life = 1})
    else
        if kind == "golden" then
            MG:Burst(hole.spot, {count = 10, texture = MG.ART.sparkleGold, blend = "BLEND", size = 12 * hole.g.k, speed = 70, life = .6})
        end
        self:Voice("up", .3)
    end
end
-- A head ducked unhit: now and then it laughs at you (the boss always does).
function game:Escaped(index, kind)
    self.holes[index].knocked = false
    if kind == "decoy" then return end
    if kind == "boss" then
        self:Voice("laugh")
        MG:FloatText(self.holes[index].spot, "He got away!", {size = 14, colour = WHITE, y = -10, rise = 24, life = 1})
        return
    end
    self:Voice("laugh", .3)
end
-- Every goal met in the middle of a stage.
function game:GoalDone()
    MG:Sound("chime")
    MG:Banner("Goal met!", {size = 26, life = 1.2, colour = self.textColour, glow = GOLD, sub = "Keep going for stars"})
end

function game:Happened(happened)
    if happened.count then self:Count(happened.count) end
    if happened.go then self:Go() end
    if happened.goalDone then self:GoalDone() end
    if happened.ducked then self:Escaped(happened.ducked, happened.duckedKind) end
    if happened.ducked2 then self:Escaped(happened.ducked2, happened.duckedKind2) end
    if happened.bossGone then self:Escaped(happened.bossGone, "boss") end
    if happened.popped then self:Popped(happened.popped, happened.popKind) end
    if happened.popped2 then self:Popped(happened.popped2, happened.popKind2) end
    if happened.bossUp then self:Popped(happened.bossUp, "boss") end
    if happened.over and self.RoundOver then self:RoundOver() end
end

function game:Update(shell, elapsed)
    elapsed = tonumber(elapsed) or 0
    if elapsed < 0 then elapsed = 0 end
    self.clock = self.clock + elapsed
    if self.screen == "map" then return end
    local state = self.state
    local happened = Whack.Advance(state, elapsed)
    if happened then self:Happened(happened) end
    self:DrawHoles(elapsed)
    DrawTimer(self, state)
    DrawMallet(self, elapsed)
    if self.PaintHud then self:PaintHud() end
end

MG:Register("whack", game)
