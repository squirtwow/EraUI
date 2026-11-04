-- The Legacy window's kit (Classic look, registry "legacyWindow"): what the
-- 1.x dressing of Forever's Legacy window (Blizzard_LegacySystem, opened on
-- Y: the Progress Track, Legacy Challenges and Legacy Tree pages) keeps
-- between its files (Look.Legacy), its 1.x art by key, and the small tools
-- every page uses:
--   * a journal of what was changed on the game's own pieces (alpha, vertex
--     alpha, anchors, size, text colour and shadow, font, art), so turning
--     the look off puts each piece back;
--   * EraUI's own textures, labels and frames on the game's frames, recorded
--     so turning the look off hides them;
--   * readers (an atlas name, a field, a number), all secret-safe;
--   * the 1.x pieces the pages share: gold names with a black shadow, brown
--     page text that Dark Windows lightens, a slot socket and ring round an
--     icon, the old check mark, a bar in the skill bar's rim, the quest log's
--     highlight bar, a thin rule, the professions book's round ring and the
--     talent window's rank plate (where the game draws its retail crowns
--     with the Legacy points in them, the points go in these);
--   * post-hooks that do their work only while the look is on, never in a
--     fight (L.After); and a few that only colour, show or hide EraUI's own
--     pieces, which keep doing that in a fight (L.AfterOwn);
--   * the window's size, the spellbook's (L.WIDE x L.TALL), and where its
--     parchment is (L.PAGE), which every page lays its pieces out in.
-- The game's frames only ever get cosmetic setters (alpha, colour, art,
-- size, anchors of plain unprotected frames): no key is written on them,
-- every record lives in a weak table here, and no frame of EraUI's that
-- takes the mouse is ever laid over the game's controls.
--
-- One thing of the game's is set in a fight too: the anchors of the plain
-- frames the game hands out again each time a page shows (the reward cards
-- and the talents). The game lays those out afresh on every show, so they
-- are laid out again after it, or Y opened in a fight would show them where
-- the 920-wide window had them. Only ClearAllPoints and SetPoint on frames
-- with no secure template and no size change: no Blizzard code runs from it
-- and nothing of the game's protected is touched. Sizes and every other
-- frame's place are set out of a fight only (the game never sets them
-- again, so they hold).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local L = { active = false, applied = false }
Look.Legacy = L

L.ADDON = "Blizzard_LegacySystem"
L.GOLD = { 1, 0.82, 0 }
L.LIGHT = { 0.9, 0.9, 0.88 }      -- the title on its dark strip
-- Text on the normal parchment: the quest log's own inks (its details'
-- brown and the grey of a finished objective, Look/QuestLogDetail.lua), so
-- it reads as clearly as the quest log does. Dark Windows makes both light.
L.INK = { 0.18, 0.12, 0.06 }      -- text on the parchment
L.FADED_INK = { 0.2, 0.2, 0.2 }   -- text for what isn't done yet: greyed, still dark enough to read
L.DIM_GOLD = { 0.66, 0.5, 0.18 }  -- a name not done yet, with Dark Windows (the gamepad page's cards)
L.RED = { 1, 0.12, 0.12 }
L.PURPLE = { 0.55, 0.27, 0.78 }   -- the Legacy point bars
L.GREEN_BAR = { 0.12, 0.6, 0.12 } -- a challenge's own progress
L.RULE = { 0.36, 0.24, 0.1, 0.55 }
L.DISC = { 0.13, 0.12, 0.11 }     -- the dark disc inside a round ring
-- A talent's socket by its state (the old talent window's colours).
L.STATE = { learned = { 1, 0.82, 0 }, open = { 0.1, 1, 0.1 }, locked = { 0.5, 0.5, 0.5 }, refund = { 1, 0.1, 0.1 } }

-- The window at the spellbook's size: its four 1.x pieces at their own size
-- (384 x 512 together) show a frame 336 x 422 from 15 in and 15 down; the
-- window is that frame. The spellbook's parchment inside it, in the window's
-- own units from its top left (down counted positive): 7 to 329 across, 60
-- to 416 down (Black Pages' cover goes there). Above the parchment, under
-- the title strip, the frame's stone band runs from 21 to 58 down.
L.WIDE, L.TALL = 336, 422
L.PAGE = { left = 7, top = 60, right = 329, bottom = 416 }
L.BAND = 39 -- the band's middle, down from the window's top
-- The parchment art's burnt rim along its foot, about this deep inside
-- L.PAGE: buttons and text stay above it (L.PAGE.bottom - L.EDGE).
L.EDGE = 10

---------------------------------------------------------------------------
-- Art (keys other areas may already have made are left as they are)
---------------------------------------------------------------------------

do
    local function Once(key, client, bundled, theme, first)
        if not Look.ART[key] then Look.DefineArt(key, client, bundled, theme, first) end
    end
    local BUTTONS, TALENTS = "Interface\\Buttons\\", "Interface\\TalentFrame\\"
    Once("legacyRing", "Interface\\Spellbook\\ProfessionsBook")
    Once("legacyPlate", TALENTS .. "TalentFrame-RankBorder")
    Once("legacySocket", BUTTONS .. "UI-EmptySlot-White")
    Once("legacyBranches", TALENTS .. "UI-TalentBranches")
    Once("legacyArrows", TALENTS .. "UI-TalentArrows")
    Once("legacyCheck", BUTTONS .. "UI-CheckBox-Check")
    Once("legacyPlus", BUTTONS .. "UI-PlusButton-Up")
    Once("legacyMinus", BUTTONS .. "UI-MinusButton-Up")
    Once("legacyPlusGlow", BUTTONS .. "UI-PlusButton-Hilight")
    Once("legacyBar", "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "UI-QuestLogTitleHighlight")
    Once("legacyDisc", "Interface\\CharacterFrame\\TempPortraitAlphaMask", "TempPortraitAlphaMask")
    Once("legacyUndo", BUTTONS .. "UI-RotationLeft-Button-Up", "UI-RotationLeft-Button-Up")
    Once("legacyReset", BUTTONS .. "UI-GroupLoot-Pass-Up")
    Once("legacyRoundGlow", BUTTONS .. "ButtonHilight-Round", "ButtonHilight-Round")
    Once("skillsBar", nil, "UI-Character-Skills-Bar", nil, true)
    Once("skillsBarBorder", nil, "UI-Character-Skills-BarBorder", "skillsBarBorder", true)
end

---------------------------------------------------------------------------
-- Readers
---------------------------------------------------------------------------

-- The look may work now: on, and not in a fight.
function L.On()
    return L.active == true and not Look.InFight()
end

-- Dark Windows greys (or blackens) the parchment now.
function L.Darkened()
    return type(ns.DarkWindowsOn) == "function" and ns.DarkWindowsOn() == true
end

-- A key of the game's frame, read raw (nil when hidden from addons).
function L.Field(frame, key)
    if type(frame) ~= "table" then return nil end
    local value = rawget(frame, key)
    if Look.Secret(value) then return nil end
    return value
end

-- A texture's atlas name, lower case, or "".
function L.AtlasOf(texture)
    if not texture or type(texture.GetAtlas) ~= "function" then return "" end
    local fine, named = pcall(texture.GetAtlas, texture)
    if not fine or Look.Secret(named) or type(named) ~= "string" then return "" end
    return named:lower()
end

function L.IsShown(region)
    if not region or type(region.IsShown) ~= "function" then return false end
    local shown = region:IsShown()
    return not Look.Secret(shown) and shown == true
end

-- Each frame a scroll box shows, through whichever walker the client has
-- (an error of EraUI's for one frame is reported, the rest still done).
function L.EachShown(scroll, fn)
    if not scroll then return end
    if type(scroll.ForEachFrame) == "function" then
        pcall(scroll.ForEachFrame, scroll, function(frame) Look.Try(fn, frame) end)
        return
    end
    if type(scroll.GetFrames) ~= "function" then return end
    local fine, list = pcall(scroll.GetFrames, scroll)
    if fine and type(list) == "table" then
        for i = 1, #list do fn(list[i]) end
    end
end

-- Each active frame of one of the game's pools.
function L.EachActive(pool, fn)
    if type(pool) ~= "table" or type(pool.EnumerateActive) ~= "function" then return end
    local fine, walker, state, first = pcall(pool.EnumerateActive, pool)
    if not fine or type(walker) ~= "function" then return end
    local found = {}
    for frame in walker, state, first do found[#found + 1] = frame end
    for _, frame in ipairs(found) do Look.Try(fn, frame) end
end

---------------------------------------------------------------------------
-- The journal: what was there before EraUI changed a piece of the game's
---------------------------------------------------------------------------

local was = { alpha = Look.Weak(), vertex = Look.Weak(), points = Look.Weak(), size = Look.Weak(),
    colour = Look.Weak(), shadow = Look.Weak(), font = Look.Weak(), art = Look.Weak(), buttonFont = Look.Weak(),
    width = Look.Weak(), justify = Look.Weak() }
L.was = was
local made = Look.Weak() -- EraUI's own pieces on the game's frames: true
local records = {}       -- each file's own "dressed" records, emptied when the look comes off
-- What puts back the frames the game hands out again (their places are not
-- journalled: the game may hand a frame a new neighbour since), run first.
L.undo = {}

function L.Undo(fn)
    L.undo[#L.undo + 1] = fn
end

-- A file's record of what it dressed: emptied when everything is put back,
-- so the look coming on again dresses all of it afresh.
function L.Record(record)
    records[#records + 1] = record
    return record
end

local function Numbers(...)
    local out = { ... }
    for i = 1, select("#", ...) do out[i] = Look.Number(out[i]) or 1 end
    return out
end

-- Faded by its alpha (the game never sets it again).
function L.Fade(region)
    if not region or type(region.SetAlpha) ~= "function" then return end
    if was.alpha[region] == nil then was.alpha[region] = Look.Number(region:GetAlpha()) or 1 end
    region:SetAlpha(0)
end

-- Shown again as it was (a piece EraUI could not stand in for after all).
function L.Unfade(region)
    local alpha = region and was.alpha[region]
    if alpha == nil then return end
    region:SetAlpha(alpha)
    was.alpha[region] = nil
end

-- Faded by its colour's alpha (a piece the game sets the alpha of, or
-- animates).
function L.Hush(region)
    if not region or type(region.SetVertexColor) ~= "function" then return end
    if was.vertex[region] == nil then was.vertex[region] = Numbers(region:GetVertexColor()) end
    local own = was.vertex[region]
    region:SetVertexColor(own[1], own[2], own[3], 0)
end

local function KeepPoints(region)
    if was.points[region] ~= nil then return end
    local kept = {}
    local count = Look.Number(region:GetNumPoints()) or 0
    for i = 1, count do kept[i] = { region:GetPoint(i) } end
    was.points[region] = kept
end

-- One anchor (the game's own anchors kept first).
function L.Pin(region, point, relative, relativePoint, x, y)
    if not region then return end
    KeepPoints(region)
    Look.Pin(region, point, relative, relativePoint, x, y)
end

-- Two anchors: { point, relative, relativePoint, x, y } each.
function L.Pins(region, first, second)
    if not region then return end
    KeepPoints(region)
    region:ClearAllPoints()
    region:SetPoint(first[1], first[2], first[3], first[4], first[5])
    region:SetPoint(second[1], second[2], second[3], second[4], second[5])
end

function L.Size(region, wide, tall)
    if not region then return end
    if was.size[region] == nil then
        was.size[region] = { Look.Number(region:GetWidth()) or 0, Look.Number(region:GetHeight()) or 0 }
    end
    region:SetSize(wide, tall)
end

-- A text's width alone (its height left to its words).
function L.Width(region, wide)
    if not region or type(region.SetWidth) ~= "function" then return end
    if was.width[region] == nil then was.width[region] = Look.Number(region:GetWidth()) or 0 end
    region:SetWidth(wide)
end

-- A text's side ("LEFT", "CENTER", "RIGHT").
function L.Justify(text, side)
    if not text or type(text.SetJustifyH) ~= "function" then return end
    if was.justify[text] == nil then
        local own = type(text.GetJustifyH) == "function" and text:GetJustifyH() or nil
        was.justify[text] = (type(own) == "string" and not Look.Secret(own)) and own or "CENTER"
    end
    text:SetJustifyH(side)
end

-- One anchor on the window, x across and y down from its top left (the
-- numbers of L.PAGE and L.BAND).
function L.At(region, point, window, x, y)
    L.Pin(region, point, window, "TOPLEFT", x, -y)
end

-- A text's colour and shadow (shadow true: the black shadow; false: none).
function L.Paint(text, rgb, shadow)
    if not text or type(text.SetTextColor) ~= "function" then return end
    if was.colour[text] == nil then was.colour[text] = Numbers(text:GetTextColor()) end
    text:SetTextColor(rgb[1], rgb[2], rgb[3])
    if shadow ~= nil and type(text.SetShadowColor) == "function" then
        if was.shadow[text] == nil and type(text.GetShadowColor) == "function" then
            was.shadow[text] = Numbers(text:GetShadowColor())
        end
        text:SetShadowColor(0, 0, 0, shadow and 1 or 0)
        if shadow and text.SetShadowOffset then text:SetShadowOffset(1, -1) end
    end
end

-- A text's font. A font brings its own colour and shadow with it, so the
-- text's own are kept too (put back after the font when the look comes off).
function L.Font(text, font)
    if not text or not font or type(text.SetFontObject) ~= "function" then return end
    if was.font[text] == nil then was.font[text] = text.GetFontObject and text:GetFontObject() or false end
    if was.colour[text] == nil and type(text.GetTextColor) == "function" then was.colour[text] = Numbers(text:GetTextColor()) end
    if was.shadow[text] == nil and type(text.GetShadowColor) == "function" then
        was.shadow[text] = Numbers(text:GetShadowColor())
    end
    text:SetFontObject(font)
end

-- A button's own normal and highlight fonts.
function L.ButtonFonts(button, font)
    if not button or not font or type(button.SetNormalFontObject) ~= "function" then return end
    if was.buttonFont[button] == nil then
        was.buttonFont[button] = { button.GetNormalFontObject and button:GetNormalFontObject() or false,
            button.GetHighlightFontObject and button:GetHighlightFontObject() or false }
    end
    button:SetNormalFontObject(font)
    if button.SetHighlightFontObject then button:SetHighlightFontObject(font) end
end

-- A piece of the game's re-arted: its own atlas or file and crop kept.
function L.KeepArt(texture)
    if not texture or was.art[texture] ~= nil then return end
    local atlas = L.AtlasOf(texture)
    local file = texture.GetTexture and texture:GetTexture() or nil
    if Look.Secret(file) then file = nil end
    was.art[texture] = { atlas = atlas ~= "" and texture:GetAtlas() or nil, file = file,
        coords = { texture:GetTexCoord() }, size = { Look.Number(texture:GetWidth()) or 0, Look.Number(texture:GetHeight()) or 0 } }
end

---------------------------------------------------------------------------
-- EraUI's own pieces on the game's frames
---------------------------------------------------------------------------

-- EraUI's own texture (made once per frame and purpose), shown unless
-- quiet (its shown state left alone: pieces that follow a state).
function L.Own(owner, purpose, layer, sublevel, quiet)
    local key = "legacy." .. purpose
    local fresh = Look.OwnPiece(owner, key) == nil
    local piece = Look.OwnTexture(owner, key, layer, sublevel)
    made[piece] = true
    if not quiet then
        Look.Shown(piece, true)
    elseif fresh then
        piece:Hide()
    end
    return piece
end

function L.Label(owner, purpose, font, layer)
    local label = Look.OwnLabel(owner, "legacy." .. purpose, font, layer)
    made[label] = true
    Look.Shown(label, true)
    return label
end

-- A frame of EraUI's own that never takes the mouse.
function L.Frame(parent, width, height)
    local frame = Look.Build("Frame", parent, nil, { size = { width or 1, height or 1 } })
    frame:EnableMouse(false)
    made[frame] = true
    return frame
end

-- force: painted again even when Dark Windows thinks it already is (a piece
-- the look hid when it came off, now dressed again).
function L.Dark(texture, role, force)
    if texture and type(ns.DarkWindowArt) == "function" then ns.DarkWindowArt(texture, role, force) end
end

---------------------------------------------------------------------------
-- Putting it all back
---------------------------------------------------------------------------

local function Back(region, kept)
    region:ClearAllPoints()
    for _, anchor in ipairs(kept) do
        if anchor[1] then region:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4] or 0, anchor[5] or 0) end
    end
end

-- One piece of the game's back on its own anchors while the look stays on
-- (the Challenges page going back to the game's list for a gamepad).
function L.PutBack(region)
    local kept = region and was.points[region]
    if not kept then return end
    Back(region, kept)
    was.points[region] = nil
end

local RESTORERS = {
    alpha = function(region, alpha) region:SetAlpha(alpha) end,
    vertex = function(region, c) region:SetVertexColor(c[1], c[2], c[3], c[4]) end,
    points = Back,
    size = function(region, s) region:SetSize(s[1], s[2]) end,
    width = function(region, wide) region:SetWidth(wide) end,
    justify = function(text, side) text:SetJustifyH(side) end,
    colour = function(text, c) text:SetTextColor(c[1], c[2], c[3], c[4]) end,
    shadow = function(text, c) text:SetShadowColor(c[1], c[2], c[3], c[4]) end,
    font = function(text, font) if font then text:SetFontObject(font) end end,
    buttonFont = function(button, fonts)
        if fonts[1] then button:SetNormalFontObject(fonts[1]) end
        if fonts[2] and button.SetHighlightFontObject then button:SetHighlightFontObject(fonts[2]) end
    end,
    art = function(texture, art)
        if art.atlas then
            texture:SetAtlas(art.atlas)
        elseif art.file ~= nil then
            texture:SetTexture(art.file)
        end
        if #art.coords == 8 then texture:SetTexCoord(unpack(art.coords)) end
        if art.size[1] > 0 and art.size[2] > 0 then texture:SetSize(art.size[1], art.size[2]) end
    end,
}

-- In this order: a text's font before its colour and shadow (the font
-- brings its own, which the text's own then replace).
local ORDER = { "alpha", "vertex", "points", "size", "width", "justify", "art", "buttonFont", "font", "colour", "shadow" }

-- Everything back as it was (out of a fight; safe to repeat).
function L.RestoreAll()
    if Look.InFight() then return false end
    for _, fn in ipairs(L.undo) do Look.Try(fn) end
    for _, kind in ipairs(ORDER) do
        local restore, book = RESTORERS[kind], was[kind]
        for region, kept in pairs(book) do
            Look.Try(restore, region, kept)
            book[region] = nil
        end
    end
    for piece in pairs(made) do
        if piece.Hide then piece:Hide() end
    end
    for _, record in ipairs(records) do
        for key in pairs(record) do record[key] = nil end
    end
    return true
end

---------------------------------------------------------------------------
-- Post-hooks: the work only while the look is on; the game's own pieces
-- never changed in a fight
---------------------------------------------------------------------------

local function Guarded(fn)
    return function(...)
        if L.On() then Look.Try(fn, ...) end
    end
end

-- A method the game's frame carries as its own (a mixin's, copied on).
function L.After(frame, method, fn)
    if type(frame) ~= "table" or type(rawget(frame, method)) ~= "function" then return false end
    return Look.HookOwn(frame, method, Guarded(fn))
end

-- The same, for work that touches only EraUI's own pieces (their colour,
-- art or shown state) while Look.InFight() is true and reads the game's:
-- done in a fight too, so what the game repaints mid-fight (a page chosen,
-- a tree loaded again, a list scrolled) never leaves an EraUI tab, check,
-- bar, socket or link on the wrong thing. Out of a fight fn may dress the
-- game's own pieces as L.After's do. In a fight it may also lay out again
-- the frames the game has just handed out again (see the top of this file).
local function WhileOn(fn)
    return function(...)
        if L.active == true then Look.Try(fn, ...) end
    end
end

function L.AfterOwn(frame, method, fn)
    if type(frame) ~= "table" or type(rawget(frame, method)) ~= "function" then return false end
    return Look.HookOwn(frame, method, WhileOn(fn))
end

function L.AfterOwnScript(frame, script, fn)
    return Look.HookScript(frame, script, WhileOn(fn), "legacy")
end

---------------------------------------------------------------------------
-- The 1.x pieces the pages share
---------------------------------------------------------------------------

function L.GoldName(text)
    L.Paint(text, L.GOLD, true)
end

-- Page text: brown ink on the parchment, lightened by Dark Windows (as the
-- spellbook's small text is); force paints it again after the game did.
function L.Ink(text, rgb)
    if not text then return end
    L.Paint(text, rgb or L.INK, false)
    if type(ns.DarkWindowText) == "function" then ns.DarkWindowText(text, true) end
end

-- The spellbook's amber slot behind an icon (its visible square 2 out from
-- the icon on every side) and the old button ring round it.
function L.Slot(owner, icon, layer)
    local across = (Look.Number(icon:GetWidth()) or 36) + 4
    local socket = L.Own(owner, "socket", layer or "BACKGROUND", -1)
    Look.Art(socket, "sbEmptySlot")
    local side = across * 64 / 41
    socket:SetSize(side, side)
    Look.Pin(socket, "TOPLEFT", icon, "TOPLEFT", -2, 2)
    L.Dark(socket, "page")
    local ring = L.Own(owner, "ring", "OVERLAY", -1)
    Look.Art(ring, "slotNormal")
    local round = (across - 4) * 64 / 36
    ring:SetSize(round, round)
    Look.Pin(ring, "CENTER", icon, "CENTER", 0, 0)
    return socket, ring
end

-- The round emblem ring on the professions book's sheet, at a size (the
-- chosen tree's emblem, the Progress Track's points); trim for Dark Windows.
local RING_CUT = { 0.43359375, 0.72265625, 0.1484375, 0.7265625 }

function L.Ring(owner, purpose, size, layer, sublevel)
    local ring = L.Own(owner, purpose, layer or "OVERLAY", sublevel or 0)
    Look.Art(ring, "legacyRing")
    Look.Crop(ring, RING_CUT[1], RING_CUT[2], RING_CUT[3], RING_CUT[4])
    ring:SetSize(size, size)
    L.Dark(ring, "trim")
    return ring
end

-- The talent window's rank plate (the Progress Track's 15 / 25 / 40 / 55
-- are on it at 44 x 36), left alone by Dark Windows: its light number reads
-- on any page.
L.PLATE_W, L.PLATE_H = 44, 36

function L.Plate(owner, purpose, layer, sublevel, quiet, wide, tall)
    local plate = L.Own(owner, purpose, layer or "OVERLAY", sublevel or -1, quiet)
    Look.Art(plate, "legacyPlate")
    plate:SetSize(wide or L.PLATE_W, tall or L.PLATE_H)
    return plate
end

-- A page header's crown with the Legacy points in it (the game's
-- LegacyPointShield) as a rank plate: the crown faded, the plate x from the
-- left of what the crown heads (the points bar, the points text), and the
-- game's own number on it in the 15 / 25 / 40 / 55's size. The game only
-- ever sets that number's text again, so it stays right by itself; the
-- crown's button keeps its place and mouse.
function L.ShieldPlate(shield, beside, x)
    if not shield then return nil end
    local number = L.Field(shield, "Points")
    L.Fade(L.Field(shield, "Icon"))
    local plate = L.Plate(shield, "plate", "ARTWORK", 0)
    if beside then
        Look.Pin(plate, "CENTER", beside, "LEFT", x, 0)
        if number then L.Pin(number, "CENTER", beside, "LEFT", x, 0) end
    else
        Look.Pin(plate, "CENTER", number or shield, "CENTER", 0, 0)
    end
    L.Font(number, GameFontHighlight)
    return plate
end

-- The old check mark (made hidden).
function L.Check(owner, purpose, size)
    local mark = L.Own(owner, purpose, "OVERLAY", 2, true)
    Look.Art(mark, "legacyCheck")
    mark:SetSize(size or 24, size or 24)
    return mark
end

-- The quest log's title highlight: on hover (layer HIGHLIGHT) or, made
-- hidden, as a picked row's bar.
function L.Bar(owner, purpose, layer, alpha)
    local drawLayer = layer or "HIGHLIGHT"
    local bar = L.Own(owner, purpose, drawLayer, 0, drawLayer ~= "HIGHLIGHT")
    Look.Art(bar, "legacyBar")
    bar:SetBlendMode("ADD")
    bar:SetAlpha(alpha or 1)
    return bar
end

-- Every texture of one of the game's frames faded (a divider's art).
function L.FadeArt(frame)
    Look.EachRegion(frame, function(piece)
        if piece.IsObjectType and piece:IsObjectType("Texture") then L.Fade(piece) end
    end)
end

-- A thin brown rule across the parchment, y down from the window's top,
-- 9 in from either side of the parchment.
function L.Rule(page, window, y)
    if not (page and window) then return nil end
    local rule = L.Own(page, "rule", "ARTWORK", 0)
    rule:SetColorTexture(L.RULE[1], L.RULE[2], L.RULE[3], L.RULE[4])
    rule:ClearAllPoints()
    rule:SetPoint("TOPLEFT", window, "TOPLEFT", L.PAGE.left + 9, -y)
    rule:SetPoint("TOPRIGHT", window, "TOPLEFT", L.PAGE.right - 9, -y)
    rule:SetHeight(2)
    return rule
end

-- A 1.x scroll bar's knob (its handle) in its own colours in every mode,
-- as the bar's arrows are: Dark Mode tints the knob's art with its grey,
-- which left a dark square on the dark stone column, out of sight. Only
-- EraUI's own knob texture is touched; it still shows only while there is
-- something to scroll.
function L.KnobShows(knob)
    if not knob or type(knob.SetVertexColor) ~= "function" then return end
    if type(ns.UntintTexture) == "function" then ns.UntintTexture(knob) end
    knob:SetVertexColor(1, 1, 1)
end

-- Each rim piece: its share of the skill bar border's width (of 256).
local RIM = { left = { 0, 14 }, middle = { 14, 242 }, right = { 242, 256 } }

-- One of the game's status bars as the old skill bar: the 1.x fill in a
-- colour, a dark well under it, the skill bar's rim round it, and the game's
-- own frame art faded. Its text stays on top.
function L.SkillBar(bar, rgb)
    if not bar or type(bar.SetStatusBarTexture) ~= "function" then return end
    L.Fade(bar.ProgressBarFrame)
    local fill = Look.FirstPath("skillsBar")
    if fill then bar:SetStatusBarTexture(fill) end
    if bar.SetStatusBarColor then bar:SetStatusBarColor(rgb[1], rgb[2], rgb[3]) end
    local well = L.Own(bar, "well", "BACKGROUND", -1)
    well:SetColorTexture(0, 0, 0, 0.6)
    Look.Fill(well, bar)
    local rim = {}
    for side, cut in pairs(RIM) do
        local piece = L.Own(bar, "rim" .. side, "OVERLAY", -1)
        Look.Art(piece, "skillsBarBorder")
        Look.Crop(piece, cut[1] / 256, cut[2] / 256, 0, 1)
        piece:ClearAllPoints()
        rim[side] = piece
    end
    for side, sign in pairs({ LEFT = -1, RIGHT = 1 }) do
        local cap = rim[side:lower()]
        cap:SetWidth(14)
        cap:SetPoint("TOP" .. side, bar, "TOP" .. side, 5 * sign, 5)
        cap:SetPoint("BOTTOM" .. side, bar, "BOTTOM" .. side, 5 * sign, -5)
    end
    rim.middle:SetPoint("TOPLEFT", rim.left, "TOPRIGHT")
    rim.middle:SetPoint("BOTTOMRIGHT", rim.right, "BOTTOMLEFT")
end
