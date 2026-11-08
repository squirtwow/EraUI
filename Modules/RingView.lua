local _, E = ...

-- How an Action Ring looks (Modules/ActionRings.lua): the slices' icons, cut
-- round, each with a thin coloured rim and a faint dark edge, on a circle
-- round the cursor with nothing behind them (the world shows between). In
-- the middle a hollow ring marks where letting go picks nothing; a small
-- arrow just outside it turns to face the slice the mouse points at, and
-- that slice's rim lights in the accent colour. The name shows on a small
-- plate under the ring. Icons show cooldowns and item counts, and grey out
-- while they can't be used. With Ring Motion on, the icons swirl in to their
-- places as a ring opens and swirl out round the middle as it closes (the
-- picked one glows first); off, a ring just shows and goes.
--
-- Each ring's face is an ordinary frame inside its hit frame
-- (Modules/RingSecure.lua), so the game's secure code shows and hides it with
-- the ring. Nothing under a hit frame has an OnShow, OnHide or OnSizeChanged
-- script: those would run inside the secure click. Opening and closing come
-- from the button's PostClick; the per-frame work is the face's OnUpdate,
-- which runs on the next frame and only while the ring shows. In a fight this
-- file only changes textures, font strings, cooldowns and its own ordinary
-- frames, and never reads the hit frame's place: the ring's centre is worked
-- out the way the secure code works it out (Modules/RingSnippet.lua's Clamp:
-- the cursor where it opened, moved in from the screen's edges far enough for
-- the whole ring and its name to show).
-- The secure code hides the face the moment you let go, so the swirl out
-- plays on a frame of its own on the screen (V.swirl): never under or pinned
-- to a ring, placed from the ring's centre, made once out of combat (with the
-- first face), and hidden when its swirl ends (its OnUpdate then stops).
-- Art: the game's round portrait mask (the icons' shape and their cooldown
-- sweep) and white square (the arrow's arms, the plate), and EraUI's own ring
-- sheet (the rims, the middle ring, the dark edges) and trail dot (shade, glow).
local V = {}
E.RingView = V

V.ICON, V.PAD = 36, 14
V.GROW = 1.18 -- the lit icon's size
V.faces = {}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MEDIA = "Interface\\AddOns\\EraUI\\Media\\"
local SHEET = MEDIA .. "CursorRings" -- EraUI's ring sheet (Modules/CursorRing.lua)
local DOT = MEDIA .. "CursorTrailDot"
local EASE = 14 -- the arrow and the lit icon catch up in about 70 ms
local STUCK = 20 -- a ring open this long out of a fight lost its key's release
-- Ring Motion. The swirl in: each icon from OPEN_FROM times the ring's
-- radius and OPEN_TURN degrees anticlockwise of its place, clockwise to it
-- over OPEN_TIME seconds (eased out), fading in. The swirl out: each icon
-- CLOSE_TURN degrees clockwise round the middle while its distance grows to
-- CLOSE_TO times (eased in) over CLOSE_TIME, at full strength until
-- CLOSE_FADE of the way (so it is still seen far out), then fading; the
-- middle ring and the arrow stay full for MIDDLE_WAIT (until the icons are
-- nearly gone), then fade by MIDDLE_END. The picked slice glows for GLOW_TIME.
V.OPEN_TIME, V.OPEN_FROM, V.OPEN_TURN = .15, 1.6, 60
V.CLOSE_TIME, V.CLOSE_TO, V.CLOSE_TURN, V.CLOSE_FADE = .35, 2.2, 70, .75
V.MIDDLE_WAIT, V.MIDDLE_END, V.GLOW_TIME = .3, .45, .15
-- The middle ring's line, the arrow's arms (long, wide; as thick as the
-- middle ring's line) and its gap outside the middle ring, in face units;
-- the arms' dark shadow (its margin round each arm, its strength).
V.MIDDLE_LINE, V.ARM, V.ARM_WIDTH, V.ARROW_GAP = 4, 13, 4, 3
V.ARM_SHADE, V.ARM_SHADE_ALPHA = 1, .45
-- Round icons: the rim is RIM wider than the icon with a RIM_LINE line (on
-- the icon's edge, about 1 inside and 1.5 out); the dark edge a disc EDGE
-- wider; the soft shade SHADE of the icon past each side.
local RIM, RIM_LINE, EDGE, SHADE = 3, 2.5, 7, .35
local EDGE_ALPHA, SHADE_ALPHA, MIDDLE_SHADE = .65, .5, .35
-- The name's plate under the ring: its gap under the face, the line's
-- height, and the plate's margin round the words (sides, then top and bottom).
local LABEL_GAP, LABEL_HEIGHT, PLATE_X, PLATE_Y = 6, 14, 8, 4
V.STRATA = "FULLSCREEN_DIALOG" -- above every window, /era's included (as the hit frames)
-- What an empty ring says, by its kind (a ready-made ring can't be filled by hand).
V.EMPTY = {custom = "Empty ring. Add slices in /era.", quest = "No quest items", mounts = "No mounts yet",
    world = "No world markers here", class = "No class spells yet", rogue = "No poisons in your bags"}

local function RS() return E.RingSnippet end
local function D() return E.RingData end

-- How far apart the closest two of n slices sit on a ring of radius 1. The
-- icons are round, so that is the straight line between two neighbours.
function V.Spread(n)
    n = n or 0
    if n < 2 then return 2 end
    return 2 * math.sin(math.pi / n)
end
-- The ring's radius for n slices, 78 at least: room along the ring for every
-- icon, and no two icons touching (their dark edges included), one of them lit.
function V.Radius(n)
    n = n or 0
    local arc = math.ceil(n * (V.ICON + 10) / (2 * math.pi))
    local apart = math.ceil(((1 + V.GROW) / 2 * V.ICON + EDGE) / V.Spread(n))
    return math.max(78, arc, apart)
end
-- The inside of the middle ring: about a third of the ring's radius, never
-- inside the middle where letting go picks nothing (RingSnippet's DEAD).
function V.Middle(n) return math.max(RS().DEAD, V.Radius(n) / 3) end
-- How far out the arrow's point is: past the middle ring and its gap, by
-- the arms' reach back from the point.
function V.Tip(n) return V.Middle(n) + V.MIDDLE_LINE + V.ARROW_GAP + (V.ARM - V.ARM_WIDTH / 2) * math.sqrt(.5) end
-- How far the ring reaches from its centre, in face units: up and to the
-- sides (past the icons, the lit one grown, with room to spare; the widest
-- name plate is this wide), and down (to the bottom of the name's plate).
-- The secure code keeps this much screen round a ring (RingSecure.Apply:
-- ring-edge, ring-foot).
function V.Edge(n) return V.Radius(n) + V.ICON / 2 + V.PAD end
function V.Foot(n) return V.Edge(n) + LABEL_GAP + LABEL_HEIGHT + PLATE_Y + 2 end
-- The widest a name can be: its plate then spans the ring, no wider.
function V.LabelWidth(n) return 2 * (V.Edge(n) - PLATE_X) end
function V.Motion() return E:GetSetting("actionRingMotion") ~= false end

-- An empty ring's words.
function V.EmptyText(kind)
    local F = E.RingFill
    if kind == "class" and F and F.ClassToken and F.ClassToken() == "ROGUE" then kind = "rogue" end
    return V.EMPTY[kind] or "Empty ring."
end

---------------------------------------------------------------------------
-- Colours: Classic bronze and gold, or Dark Mode grey and your class colour
---------------------------------------------------------------------------

function V.ClassColour()
    local _, class = D().Call(UnitClass, "player")
    if class == "PALADIN" then return .96, .55, .73 end
    local colour = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if colour then return colour.r, colour.g, colour.b end
    return .85, .7, .36
end
-- Read each time a face is laid out or opens, so the Darkness slider shows
-- at the next open. rim: every slice's rim (and the editor preview's icon
-- outlines); accent: the lit slice's rim, the middle ring, the arrow and the
-- glows (Classic: the game's gold; Dark Mode: your class colour, as Dark
-- Mode's class-coloured edges). dial and band: the name's plate and its edge.
-- Dark Mode's rims are the Darkness grey kept between RIM_LOW and RIM_HIGH
-- (its slight blue kept): a muted grey on the bare world at every Darkness,
-- never white rims at the lightest or lost on the dark edge at the darkest,
-- so the lit slice's class colour stands out from them.
local RIM_LOW, RIM_HIGH = .3, .5
function V.Palette()
    local palette = {class = {V.ClassColour()}}
    if E:GetSetting("darkMode") == true then
        local classic = E.Classic
        local r, g, b = .42, .44, .48
        if classic and classic.DarkGrey then r, g, b = classic.DarkGrey() end
        palette.dial = {r * .22, g * .22, b * .22, .88}
        palette.band = {math.min(1, r * 1.6), math.min(1, g * 1.6), math.min(1, b * 1.6)}
        local rim = math.max(RIM_LOW, math.min(RIM_HIGH, r))
        local lift = r > 0 and rim / r or 1
        palette.rim = {rim, math.min(1, g * lift), math.min(1, b * lift)}
        palette.accent = palette.class
    else
        palette.dial = {.07, .055, .04, .85}
        palette.band = {.78, .62, .31}
        palette.rim = {.55, .45, .2}
        palette.accent = {1, .82, 0}
    end
    return palette
end

---------------------------------------------------------------------------
-- Art
---------------------------------------------------------------------------

local function Texture(owner, layer, sub, path)
    local texture = owner:CreateTexture(nil, layer, nil, sub)
    if path then texture:SetTexture(path) end
    return texture
end

-- EraUI's ring sheet: 8 x 8 cells of 128, each a ring 120 across whose line
-- is (cell + 1) / 128 of that (the last cell a disc). Shows on a texture the
-- ring `across` wide outside with a line at most `line` thick (so its inside
-- never comes in), and gives the texture's size for it.
function V.RingCell(texture, across, line)
    local index = math.max(1, math.min(64, math.floor(line / across * 128))) - 1
    local column, row = index % 8, math.floor(index / 8)
    texture:SetTexture(SHEET)
    texture:SetTexCoord(column / 8, (column + 1) / 8, row / 8, (row + 1) / 8)
    return across * 128 / 120
end

-- A texture pinned round a frame by its corners, out past each side.
local function Pin(texture, frame, out)
    texture:SetPoint("TOPLEFT", frame, "TOPLEFT", -out, out)
    texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", out, -out)
end

-- An icon cut round by the game's portrait mask (where the client has masks).
function V.Round(owner, texture)
    if type(owner.CreateMaskTexture) ~= "function" or type(texture.AddMaskTexture) ~= "function" then return end
    local mask = owner:CreateMaskTexture()
    mask:SetTexture(DISC, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(texture)
    texture:AddMaskTexture(mask)
    texture.mask = mask
end

-- A round icon's parts on its frame (sized as made, V.ICON): a soft dark
-- shade and a dark edge behind it so it reads on bright and dark ground, the
-- icon cut round, and its rim. Pinned by their corners, they follow the
-- frame's size (the lit icon grows). Used by the face and the swirl out.
function V.RoundParts(frame)
    local size = V.ICON
    frame.shade = Texture(frame, "BACKGROUND", 0, DOT)
    frame.shade:SetVertexColor(0, 0, 0, SHADE_ALPHA)
    Pin(frame.shade, frame, size * SHADE)
    frame.edge = Texture(frame, "BACKGROUND", 1)
    Pin(frame.edge, frame, (V.RingCell(frame.edge, size + EDGE, size + EDGE) - size) / 2)
    frame.edge:SetVertexColor(0, 0, 0, EDGE_ALPHA)
    frame.icon = Texture(frame, "ARTWORK", 0)
    frame.icon:SetAllPoints(frame)
    frame.icon:SetTexCoord(.08, .92, .08, .92)
    V.Round(frame, frame.icon)
    frame.rim = Texture(frame, "ARTWORK", 2)
    Pin(frame.rim, frame, (V.RingCell(frame.rim, size + RIM, RIM_LINE) - size) / 2)
end

-- The middle ring on two textures: a hollow ring whose inside is `inner`
-- out from the centre, over a wider faint dark one.
function V.MiddleArt(middle, shade, inner)
    local across = 2 * (inner + V.MIDDLE_LINE)
    local art = V.RingCell(middle, across, V.MIDDLE_LINE)
    middle:SetSize(art, art)
    art = V.RingCell(shade, across + 3, V.MIDDLE_LINE + 3)
    shade:SetSize(art, art)
end

-- The arrow: two bars (the old needle's turned bars) meeting at its point,
-- each over a slightly bigger dark bar (arms.shades) so it reads on bright
-- ground as the icons and the middle ring do.
function V.Arms(owner)
    local arms = {shades = {}}
    for i = 1, 2 do
        local shade = Texture(owner, "ARTWORK", 2, WHITE)
        shade:SetSize(V.ARM_WIDTH + 2 * V.ARM_SHADE, V.ARM + 2 * V.ARM_SHADE)
        shade:SetVertexColor(0, 0, 0, V.ARM_SHADE_ALPHA)
        arms.shades[i] = shade
        arms[i] = Texture(owner, "ARTWORK", 3, WHITE)
        arms[i]:SetSize(V.ARM_WIDTH, V.ARM)
    end
    return arms
end
-- How strongly the arrow shows, its shadow with it.
function V.ArrowAlpha(arms, alpha)
    for i = 1, 2 do
        arms[i]:SetAlpha(alpha)
        arms.shades[i]:SetAlpha(alpha)
    end
end
-- Its point `tip` out from owner's centre at bearing (degrees, 0 up,
-- clockwise), each arm running back from it 135 degrees either side.
function V.Arrow(owner, arms, tip, bearing, alpha)
    local a = math.rad(bearing)
    local tx, ty = tip * math.sin(a), tip * math.cos(a)
    local reach = (V.ARM - V.ARM_WIDTH) / 2
    for i = 1, 2 do
        local along = math.rad(bearing + (i == 1 and 135 or 225))
        local x, y = tx + reach * math.sin(along), ty + reach * math.cos(along)
        local arm, shade = arms[i], arms.shades[i]
        arm:SetPoint("CENTER", owner, "CENTER", x, y)
        arm:SetRotation(-along)
        shade:SetPoint("CENTER", owner, "CENTER", x, y)
        shade:SetRotation(-along)
    end
    V.ArrowAlpha(arms, alpha)
end

---------------------------------------------------------------------------
-- Faces
---------------------------------------------------------------------------

-- One slice's icon: an ordinary frame (sized as made) with its round parts,
-- a cooldown (no template, so no template scripts; a round sweep) and count.
function V.SlotFrame(face, k)
    local slot = face.slots[k]
    if slot then return slot end
    slot = CreateFrame("Frame", nil, face)
    slot:SetSize(V.ICON, V.ICON)
    slot:EnableMouse(false)
    V.RoundParts(slot)
    slot.cd = CreateFrame("Cooldown", nil, slot)
    slot.cd:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    slot.cd:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    slot.cd:EnableMouse(false)
    slot.cd:SetDrawEdge(false)
    slot.cd:SetDrawBling(false)
    slot.cd:SetHideCountdownNumbers(true)
    if type(slot.cd.SetSwipeTexture) == "function" then pcall(slot.cd.SetSwipeTexture, slot.cd, DISC) end
    if type(slot.cd.SetUseCircularEdge) == "function" then pcall(slot.cd.SetUseCircularEdge, slot.cd, true) end
    slot.count = slot:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    slot.count:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 2, -1)
    slot.size, slot.home, slot.angle, slot.radius = V.ICON, 0, 0, 0
    face.slots[k] = slot
    return slot
end

-- A ring's face, made once inside its hit frame, out of combat.
function V.Face(slot, hit)
    local face = V.faces[slot]
    if face then return face end
    local size = 2 * (V.Radius(0) + V.ICON / 2 + V.PAD)
    face = CreateFrame("Frame", nil, hit)
    face:SetSize(size, size)
    face:SetPoint("CENTER", hit, "CENTER", 0, 0)
    face:EnableMouse(false)
    face.slot, face.n, face.R, face.ringScale, face.list = slot, 0, V.Radius(0), 1, {}
    -- The lit icon's glow, under the icons.
    face.glow = Texture(face, "BACKGROUND", 0, DOT)
    face.glow:SetBlendMode("ADD")
    face.glow:SetSize(V.ICON * 2.2, V.ICON * 2.2)
    face.glow:Hide()
    face.middleShade = Texture(face, "BORDER", 0)
    face.middleShade:SetPoint("CENTER", face, "CENTER", 0, 0)
    face.middle = Texture(face, "BORDER", 1)
    face.middle:SetPoint("CENTER", face, "CENTER", 0, 0)
    face.arms = V.Arms(face)
    -- The name, on its plate under the icons.
    face.label = face:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    face.label:SetPoint("TOP", face, "BOTTOM", 0, -LABEL_GAP)
    face.label:SetHeight(LABEL_HEIGHT)
    face.label:SetJustifyH("CENTER")
    face.label:SetWordWrap(false)
    face.plateEdge = Texture(face, "BACKGROUND", 1, WHITE)
    face.plateEdge:SetPoint("TOPLEFT", face.label, "TOPLEFT", -PLATE_X - 1, PLATE_Y + 1)
    face.plateEdge:SetPoint("BOTTOMRIGHT", face.label, "BOTTOMRIGHT", PLATE_X + 1, -PLATE_Y - 1)
    face.plate = Texture(face, "BACKGROUND", 2, WHITE)
    face.plate:SetPoint("TOPLEFT", face.label, "TOPLEFT", -PLATE_X, PLATE_Y)
    face.plate:SetPoint("BOTTOMRIGHT", face.label, "BOTTOMRIGHT", PLATE_X, -PLATE_Y)
    face.slots = {}
    face:SetScript("OnUpdate", V.Update)
    V.faces[slot] = face
    return face
end

-- Icon k at `angle` (degrees, 0 up, clockwise), `radius` out from the middle.
function V.Place(face, slot, angle, radius)
    slot.angle, slot.radius = angle, radius
    local a = math.rad(angle)
    slot:SetPoint("CENTER", face, "CENTER", radius * math.sin(a), radius * math.cos(a))
end

-- Lays a ring out for its slices (out of combat, with its attributes):
-- icon k at its bearing on a circle of radius R, the middle ring inside.
function V.Layout(slot, hit, list, ring, scale)
    local face = V.Face(slot, hit)
    local n = #list
    local R = V.Radius(n)
    local size = 2 * (R + V.ICON / 2 + V.PAD)
    face.n, face.R, face.list, face.ringScale = n, R, list, scale or 1
    face.ringName, face.ringKind = ring and ring.name or nil, ring and ring.kind or nil
    face.labelText = nil
    face.inner, face.arrowAt = V.Middle(n), V.Tip(n)
    face:SetSize(size, size)
    face:SetScale(face.ringScale)
    V.MiddleArt(face.middle, face.middleShade, face.inner)
    for k = 1, math.max(n, #face.slots) do
        if k <= n then
            local frame = V.SlotFrame(face, k)
            frame.home = RS().SliceAngle(k, n)
            frame:ClearAllPoints()
            V.Place(face, frame, frame.home, R)
            frame.icon:SetTexture(list[k].icon)
            frame.icon:SetDesaturated(not list[k].ready)
            frame:SetAlpha(list[k].ready and 1 or .45)
            frame.count:SetText("")
            frame.cd:Clear()
            frame:Show()
        elseif face.slots[k] then
            face.slots[k]:Hide()
        end
    end
    V.Rest(face)
    V.Paint(face)
    V.SwirlFrame()
end

-- The face's colours, from the look in use now.
function V.Paint(face)
    local palette = V.Palette()
    local accent, rim, band = palette.accent, palette.rim, palette.band
    face.accent, face.rimColour = accent, rim
    face.middle:SetVertexColor(accent[1], accent[2], accent[3], 1)
    face.middleShade:SetVertexColor(0, 0, 0, MIDDLE_SHADE)
    for _, arm in ipairs(face.arms) do arm:SetVertexColor(accent[1], accent[2], accent[3], 1) end
    for _, slot in ipairs(face.slots) do
        slot.tint = rim
        slot.rim:SetVertexColor(rim[1], rim[2], rim[3], 1)
    end
    face.plate:SetVertexColor(palette.dial[1], palette.dial[2], palette.dial[3], palette.dial[4])
    face.plateEdge:SetVertexColor(band[1], band[2], band[3], .45)
    face.glow:SetVertexColor(accent[1], accent[2], accent[3], .6)
end

-- A face at rest: nothing lit, every icon its own size, in its place.
function V.Rest(face)
    face.lit, face.bearing, face.motion, face.come, face.out = 0, nil, nil, 1, false
    face.glow:Hide()
    for k, slot in ipairs(face.slots) do
        slot.size = V.ICON
        slot:SetSize(V.ICON, V.ICON)
        if k <= face.n then V.Place(face, slot, slot.home, face.R) end
    end
end

---------------------------------------------------------------------------
-- Opening and closing (from the ring button's PostClick)
---------------------------------------------------------------------------

-- Where the secure code put a ring opened with the cursor at (cx, cy), in
-- screen pixels: RingSnippet.Clamp in UIParent's units (the screen frame's),
-- with this face's reach (as RingSecure.Apply wrote it), back in pixels.
function V.Centre(face, cx, cy)
    local Data = D()
    local ui = UIParent:GetEffectiveScale()
    local w, h = UIParent:GetWidth(), UIParent:GetHeight()
    if not (Data.Num(ui) and Data.Num(w) and Data.Num(h)) or ui <= 0 or w <= 0 or h <= 0 then return cx, cy end
    local scale = face.ringScale or 1
    local x, y = RS().Clamp(cx / ui, cy / ui, w, h, V.Edge(face.n) * scale, V.Foot(face.n) * scale)
    return x * ui, y * ui
end

-- A ring opened: its centre is the cursor now, moved in from the screen's
-- edges as the secure code moved it (V.ox, V.oy: the cursor where it opened).
-- Any swirl out still playing stops at once; with Ring Motion on the icons
-- start their swirl in (from the first frame drawn).
function V.Opened(slot)
    local hit, face = E.RingSecure.hits[slot], V.faces[slot]
    if not (hit and face) or not hit:IsShown() then return false end
    if V.open == slot then return true end
    if V.open and V.faces[V.open] then V.Rest(V.faces[V.open]) end
    V.StopSwirl()
    local cx, cy = GetCursorPosition()
    if not (D().Num(cx) and D().Num(cy)) then cx, cy = 0, 0 end
    local x, y = V.Centre(face, cx, cy)
    V.open, V.cx, V.cy, V.ox, V.oy, V.openedAt = slot, x, y, cx, cy, GetTime()
    V.Rest(face)
    if V.Motion() then face.motion = 0 end
    face.since = 0
    V.Paint(face)
    V.RefreshFace(face)
    V.Update(face, 0)
    return true
end

-- A ring closed (a pick, a tap, a cancel or a greyed slice): with Ring
-- Motion on its icons swirl out where they were, the picked one glowing.
function V.Closed(slot, chosen)
    if V.open ~= slot then return end
    local face = V.faces[slot]
    V.open = nil
    if not face then return end
    if V.Motion() then
        local picked = (type(chosen) == "number" and chosen > 0 and chosen <= face.n) and chosen or 0
        V.SwirlOut(face, picked)
    end
    V.Rest(face)
end

-- Every ring put away (the module's CLOSE): at once, no swirl.
function V.Reset()
    if V.open and V.faces[V.open] then V.Rest(V.faces[V.open]) end
    V.open = nil
    V.StopSwirl()
end

-- The cursor's offset from the open ring's centre, then where it opened
-- (0, 0 unless the ring was moved in from an edge), in face units.
function V.Offset(face)
    local cx, cy = GetCursorPosition()
    if not (D().Num(cx) and D().Num(cy)) then return nil end
    local unit = (UIParent:GetEffectiveScale() or 1) * face.ringScale
    if unit <= 0 then return nil end
    return (cx - V.cx) / unit, (cy - V.cy) / unit, ((V.ox or V.cx) - V.cx) / unit, ((V.oy or V.cy) - V.cy) / unit
end

-- The shortest turn from one bearing to another, -180 to 180.
function V.Turn(from, to) return (to - from + 540) % 360 - 180 end

local function Ease(current, target, share) return current + (target - current) * share end

-- Every frame while a ring is open: the swirl in, the arrow, the lit slice,
-- the names, the cooldowns twice a second.
function V.Update(face, elapsed)
    if V.open ~= face.slot and not V.Opened(face.slot) then return end
    elapsed = elapsed or 0
    local dx, dy, ox, oy = V.Offset(face)
    if not dx then return end
    local snip = RS()
    local dead, tap, reach = snip.DEAD, snip.TAP, snip.Reach(face.ringScale)
    local lit = snip.Pick(dx, dy, face.n, dead, ox, oy, tap, reach)
    -- Ring Motion off: the arrow and the lit icon's size snap.
    local share = V.Motion() and math.min(1, elapsed * EASE) or 1
    local mx, my = dx - ox, dy - oy
    local out = dx * dx + dy * dy >= dead * dead and mx * mx + my * my >= tap * tap
        and math.abs(dx) <= reach and math.abs(dy) <= reach
    -- The first time out of the middle the arrow snaps to the cursor (no
    -- spin up from straight up); then it glides the shortest way round.
    -- Inside the middle (or not yet moved from where a ring moved in from an
    -- edge opened, or off the hit frame on a very wide screen) it stays where
    -- it was, faint: a release there picks nothing.
    if out then
        local target = snip.Bearing(dx, dy)
        face.bearing = face.bearing and (face.bearing + V.Turn(face.bearing, target) * share) % 360 or target
    end
    face.lit, face.out = lit, out
    -- The swirl in: 0 to 1, eased out; 1 once done (or with Ring Motion off).
    local come = 1
    if face.motion then
        face.motion = face.motion + elapsed
        local p = math.min(1, face.motion / V.OPEN_TIME)
        come = 1 - (1 - p) * (1 - p)
        if p >= 1 then face.motion = nil end
    end
    face.come = come
    V.Icons(face, lit, share, come)
    V.Pointer(face, out, come)
    V.Label(face)
    face.since = (face.since or 0) + elapsed
    if face.since >= .5 then
        face.since = 0
        V.RefreshFace(face)
    end
    if V.openedAt and GetTime() - V.openedAt > STUCK and not InCombatLockdown() then E.RingSecure.CloseAll() end
end

-- Every icon: its place (in the swirl in, coming round clockwise from
-- further out), its size (the lit one grows), its rim (the lit one's in the
-- accent colour) and how strongly it shows; the glow under the lit one.
function V.Icons(face, lit, share, come)
    local back, far = V.OPEN_TURN * (1 - come), face.R * (V.OPEN_FROM - (V.OPEN_FROM - 1) * come)
    if come >= 1 then back, far = 0, face.R end
    for k = 1, face.n do
        local slot = face.slots[k]
        if slot.radius ~= far or slot.angle ~= slot.home - back then V.Place(face, slot, slot.home - back, far) end
        local goal = V.ICON * (k == lit and V.GROW or 1)
        local size = Ease(slot.size or V.ICON, goal, share)
        if math.abs(size - goal) < .01 then size = goal end
        if size ~= slot.size then
            slot.size = size
            slot:SetSize(size, size)
        end
        local ready = face.list[k].ready and not slot.greyed
        slot:SetAlpha((ready and (k == lit and 1 or .78) or .45) * come)
        local tint = k == lit and face.accent or face.rimColour
        if slot.tint ~= tint then
            slot.tint = tint
            slot.rim:SetVertexColor(tint[1], tint[2], tint[3], 1)
        end
    end
    local slot = lit > 0 and face.slots[lit]
    if slot then
        local a = math.rad(slot.angle)
        face.glow:SetPoint("CENTER", face, "CENTER", slot.radius * math.sin(a), slot.radius * math.cos(a))
        face.glow:SetAlpha(come)
        face.glow:Show()
    else
        face.glow:Hide()
    end
end

-- The arrow, turned to face.bearing (straight up until the cursor first
-- leaves the middle); faint inside the middle. The middle ring fades in
-- with the icons.
function V.Pointer(face, out, come)
    local alpha = (out and 1 or .25) * come
    face.arrowAlpha = alpha
    V.Arrow(face, face.arms, face.arrowAt, face.bearing or 0, alpha)
    face.middle:SetAlpha(come)
    face.middleShade:SetAlpha(come)
end

-- A font string's whole width, whatever width it was given before: the
-- game measures inside a width already set, so a long name after a short one
-- came back cut ("Heart..."). Its own unbounded width where the client has
-- it, else measured with its width cleared.
function V.Measure(text)
    local Data = D()
    local width = Data.Call(text.GetUnboundedStringWidth, text)
    if Data.Num(width) then return width end
    text:SetWidth(0)
    width = Data.Call(text.GetStringWidth, text)
    return Data.Num(width) and width or nil
end

-- The words under the ring: the lit slice's name (Slice Names), else the
-- ring's own, muted; an empty ring says why (by its kind). The plate is as
-- wide as the words, at most the ring's width (longer ones end in "...").
function V.SetLabel(face, text)
    if face.labelText == text then return end
    face.labelText = text
    face.label:SetText(text)
    local width = V.Measure(face.label)
    local most = V.LabelWidth(face.n)
    face.label:SetWidth(width and math.min(most, width + 2) or most)
    face.plate:SetShown(text ~= "")
    face.plateEdge:SetShown(text ~= "")
end
function V.Label(face)
    local slice = face.lit > 0 and face.list[face.lit]
    if slice and E:GetSetting("actionRingNames") ~= false then
        V.SetLabel(face, slice.name or "")
        face.label:SetTextColor(1, 1, 1)
        return
    end
    V.SetLabel(face, face.n == 0 and V.EmptyText(face.ringKind) or (face.ringName or ""))
    face.label:SetTextColor(.62, .64, .68)
end

---------------------------------------------------------------------------
-- The swirl out: its own frame on the screen, not under a ring
---------------------------------------------------------------------------

-- Made once, out of combat (with the first face laid out): a copy of every
-- icon (16), the middle ring, the arrow and the picked slice's glow.
function V.SwirlFrame()
    if V.swirl then return V.swirl end
    local swirl = CreateFrame("Frame", nil, UIParent)
    swirl:SetSize(1, 1)
    swirl:SetFrameStrata(V.STRATA)
    swirl:EnableMouse(false)
    swirl:SetPoint("CENTER", UIParent, "BOTTOMLEFT", 0, 0)
    swirl.glow = Texture(swirl, "BACKGROUND", 0, DOT)
    swirl.glow:SetBlendMode("ADD")
    swirl.glow:Hide()
    swirl.middleShade = Texture(swirl, "BORDER", 0)
    swirl.middleShade:SetPoint("CENTER", swirl, "CENTER", 0, 0)
    swirl.middle = Texture(swirl, "BORDER", 1)
    swirl.middle:SetPoint("CENTER", swirl, "CENTER", 0, 0)
    swirl.arms = V.Arms(swirl)
    swirl.ghosts = {}
    for k = 1, RS().SLICES do
        local ghost = CreateFrame("Frame", nil, swirl)
        ghost:SetSize(V.ICON, V.ICON)
        ghost:EnableMouse(false)
        V.RoundParts(ghost)
        ghost.angle, ghost.radius, ghost.base, ghost.size, ghost.x, ghost.y = 0, 0, 1, V.ICON, 0, 0
        ghost:Hide()
        swirl.ghosts[k] = ghost
    end
    swirl.n, swirl.picked, swirl.t = 0, 0, 0
    swirl:Hide()
    swirl:SetScript("OnUpdate", V.SwirlStep)
    V.swirl = swirl
    return swirl
end

-- Stops the swirl out at once (a ring opening, every ring put away).
function V.StopSwirl()
    if V.swirl then V.swirl:Hide() end
end

-- Copies the closing face onto the swirl frame (each icon where it is now,
-- at its size, with its picture, greying, rim and strength; the middle ring
-- and the arrow as they were), placed from the ring's centre on the screen
-- and scaled as the ring, then plays it.
function V.SwirlOut(face, picked)
    local swirl = V.swirl
    if not swirl then return end
    local Data = D()
    local ui = UIParent:GetEffectiveScale()
    if not (Data.Num(ui) and ui > 0) then ui = 1 end
    local scale = face.ringScale or 1
    swirl:SetScale(scale)
    swirl:SetPoint("CENTER", UIParent, "BOTTOMLEFT", V.cx / (ui * scale), V.cy / (ui * scale))
    for k, ghost in ipairs(swirl.ghosts) do
        local slot = k <= face.n and face.slots[k]
        if slot then
            ghost.angle, ghost.radius, ghost.base, ghost.size = slot.angle, slot.radius, slot:GetAlpha(), slot.size
            ghost:SetSize(slot.size, slot.size)
            ghost.icon:SetTexture(face.list[k].icon)
            ghost.icon:SetDesaturated(slot.greyed and true or false)
            local tint = slot.tint or face.rimColour
            ghost.rim:SetVertexColor(tint[1], tint[2], tint[3], 1)
            ghost:Show()
        else
            ghost:Hide()
        end
    end
    local accent = face.accent
    V.MiddleArt(swirl.middle, swirl.middleShade, face.inner)
    swirl.middle:SetVertexColor(accent[1], accent[2], accent[3], 1)
    swirl.middleShade:SetVertexColor(0, 0, 0, MIDDLE_SHADE)
    for _, arm in ipairs(swirl.arms) do arm:SetVertexColor(accent[1], accent[2], accent[3], 1) end
    swirl.glow:SetVertexColor(accent[1], accent[2], accent[3], 1)
    swirl.come, swirl.arrowAlpha = face.come or 1, face.arrowAlpha or .25
    V.Arrow(swirl, swirl.arms, face.arrowAt, face.bearing or 0, swirl.arrowAlpha)
    swirl.n, swirl.picked, swirl.t = face.n, picked or 0, 0
    swirl:Show()
    V.SwirlStep(swirl, 0)
end

-- Every frame of the swirl out (only while it shows): each icon turns
-- clockwise round the middle as it moves out (eased in), fading near the
-- end; the picked one's glow flashes and fades; the middle ring and arrow
-- stay, then fade. Hidden when done.
function V.SwirlStep(swirl, elapsed)
    swirl.t = (swirl.t or 0) + (elapsed or 0)
    local t = swirl.t
    local p = math.min(1, t / V.CLOSE_TIME)
    local go = p * p
    local fade = 1 - math.max(0, math.min(1, (p - V.CLOSE_FADE) / (1 - V.CLOSE_FADE)))
    local turn, grow = V.CLOSE_TURN * go, 1 + (V.CLOSE_TO - 1) * go
    for k = 1, swirl.n do
        local ghost = swirl.ghosts[k]
        local a, r = math.rad(ghost.angle + turn), ghost.radius * grow
        ghost.x, ghost.y = r * math.sin(a), r * math.cos(a)
        ghost:SetPoint("CENTER", swirl, "CENTER", ghost.x, ghost.y)
        ghost:SetAlpha(ghost.base * fade)
    end
    local chosen = swirl.picked > 0 and swirl.ghosts[swirl.picked]
    if chosen and t < V.GLOW_TIME then
        local g = t / V.GLOW_TIME
        local size = chosen.size * (2.2 + .6 * g)
        swirl.glow:SetSize(size, size)
        swirl.glow:SetPoint("CENTER", swirl, "CENTER", chosen.x, chosen.y)
        swirl.glow:SetAlpha(1 - g)
        swirl.glow:Show()
    else
        swirl.glow:Hide()
    end
    local stay = 1 - math.max(0, math.min(1, (t - V.MIDDLE_WAIT) / (V.MIDDLE_END - V.MIDDLE_WAIT)))
    swirl.middle:SetAlpha(swirl.come * stay)
    swirl.middleShade:SetAlpha(swirl.come * stay)
    V.ArrowAlpha(swirl.arms, swirl.arrowAlpha * stay)
    if t >= V.CLOSE_TIME and t >= V.MIDDLE_END then swirl:Hide() end
end

---------------------------------------------------------------------------
-- Cooldowns, counts and greying
---------------------------------------------------------------------------

-- A spell's sweep only from the game's duration object (which it may keep
-- secret in a fight; handed on as it is), an item's from public numbers.
function V.Cooldown(cooldown, slice)
    local Data = D()
    if slice.kind == "spell" then
        local info = Data.Call(C_Spell and C_Spell.GetSpellCooldown, slice.cast)
        if Data.Field(info, "isEnabled") == false then cooldown:Clear(); return end
        if Data.Field(info, "isOnGCD") == true then return end
        local get = C_Spell and C_Spell.GetSpellCooldownDuration
        local ok, duration = false, nil
        if get then ok, duration = pcall(get, slice.cast, true) end
        if not (ok and cooldown.SetCooldownFromDurationObject and pcall(cooldown.SetCooldownFromDurationObject, cooldown, duration)) then
            cooldown:Clear()
        end
    elseif slice.kind == "item" or slice.kind == "toy" then
        local start, length = Data.Call(C_Item and C_Item.GetItemCooldown or GetItemCooldown, slice.id)
        if Data.Num(start) and Data.Num(length) and start > 0 and length > 1.5 then cooldown:SetCooldown(start, length)
        else cooldown:Clear() end
    else
        cooldown:Clear()
    end
end

-- Cooldowns, counts and greying for every slice of a face (Cooldowns &
-- Counts off: neither). Greyed: a slice that can't be used now, a spell the
-- game says isn't usable, an item you have none of.
function V.RefreshFace(face)
    local Data = D()
    local show = E:GetSetting("actionRingCooldowns") ~= false
    for k = 1, face.n do
        local slice, slot = face.list[k], face.slots[k]
        local greyed, count = not slice.ready, nil
        if slice.ready and slice.kind == "item" then
            count = Data.Call(C_Item and C_Item.GetItemCount or GetItemCount, slice.id)
            if Data.Num(count) and count == 0 then greyed = true end
        elseif slice.ready and slice.kind == "spell" then
            if Data.Call(C_Spell and C_Spell.IsSpellUsable or IsUsableSpell, slice.cast) == false then greyed = true end
        end
        slot.greyed = greyed
        slot.icon:SetDesaturated(greyed)
        slot.count:SetText((show and Data.Num(count) and count > 1) and tostring(count) or "")
        if show and slice.ready then V.Cooldown(slot.cd, slice) else slot.cd:Clear() end
    end
end

-- The open ring's, when the game says cooldowns, bags or usability changed.
function V.RefreshOpen()
    local face = V.open and V.faces[V.open]
    if face then V.RefreshFace(face) end
end
