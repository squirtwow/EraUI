-- The Legacy window's Challenges page in the 1.x look (registry
-- "legacyWindow"), as the old quest log on the spellbook-sized parchment:
--   * the category list in the top part: its search and filter on top,
--     headers in gold with the old plus and minus at the left, categories in
--     brown ink, the picked one gold on the quest log's highlight bar, the
--     same bar on hover; the old drop down and scroll bar;
--   * a thin rule, then the chosen category's challenges scrolling in the
--     lower part: no card art, the icon in the spellbook's slot and ring, its
--     Legacy points on a talent rank plate under it (the game's retail crown
--     faded, the plate where the crown's tooltip now is), the name gold (done
--     or picked) or dim, the text in brown ink and narrowed to the page, a
--     thin rule between them, the old plus and minus and check mark, the
--     date a done one was earned in ink at its top right, the picked one on
--     the highlight bar; each challenge's own objectives in ink
--     with the old check and their bars as the old skill bar;
--   * the points bar in the frame's stone band under the title, as the old
--     skill bar with the points on a rank plate left of it (the header's
--     crown faded).
-- The game's own rows, cards, search, filter and tracking keep working;
-- each is dressed the first time it shows and painted again after each of
-- the game's own refreshes (in a fight, EraUI's own bars, signs and checks
-- only; the words keep the game's colours until it ends).
-- This dressed page is what shows while the game's gamepad mode is on (its
-- gamepad moves through the game's own rows and cards). Otherwise EraUI's
-- own list and details stand in for the rows and cards
-- (Look/LegacyChallengeList.lua, LegacyChallengeDetail.lua): the game's
-- search and filter stay, in a strip at the parchment's top, and its rows,
-- cards and their scroll bars are faded and parked left of the window, at
-- the size this page gives them (L.CHALLENGE_PARK).
local _, EraUI = ...
local Look = EraUI.Look
local L = Look.Legacy

local rows = L.Record(Look.Weak())     -- a category row: { glow, pick }
local cards = L.Record(Look.Weak())    -- a challenge: { socket, ring, rule, glow, pick, sign, check, plate, points }
local criteria = L.Record(Look.Weak()) -- an objective: { check }

-- The page's places (window units from its top left, down positive): the
-- points bar's summary in the band, the list over the top part of the
-- parchment, a rule, the challenges under it (their scroll bar, which hangs
-- off the pane's right, still on the parchment).
local SUMMARY_X, SUMMARY_W, SUMMARY_H = 110, 206, 36
local LIST_TOP, LIST_BOTTOM, SIDE = 62, 212, 8
local RULE_Y = 216
local PANE_TOP, PANE_RIGHT, PANE_FOOT = 220, 30, 8
-- A challenge's text: as wide as the card leaves it from where the game
-- starts it (100 in with the plus and minus) to 12 short of its right.
local CARD_W = L.WIDE - SIDE - PANE_RIGHT - 4
local TEXT_W = CARD_W - 100 - 12
local NAME_W = CARD_W - 75 - 8 -- the name starts 75 in
local PLATE_W, PLATE_H = 40, 32
-- The sizes this page gives the game's rows' box (the list less the game's
-- own insets: 8 and 20 across, 35 and 5 down) and its challenges' pane, so
-- parked at them the game lays nothing out again.
L.CHALLENGE_PARK = { box = { L.WIDE - 2 * SIDE - 28, LIST_BOTTOM - LIST_TOP - 40 },
    pane = { L.WIDE - SIDE - PANE_RIGHT, L.TALL - PANE_FOOT - PANE_TOP } }

---------------------------------------------------------------------------
-- The category list
---------------------------------------------------------------------------

local function FoldArt(fold, collapsed)
    local icon = L.Field(fold, "Icon")
    if icon then
        L.KeepArt(icon)
        Look.Art(icon, collapsed and "legacyPlus" or "legacyMinus")
        Look.Crop(icon, 0, 1, 0, 1)
        icon:SetSize(14, 14)
    end
    local glow = fold.GetHighlightTexture and fold:GetHighlightTexture()
    if glow then
        L.KeepArt(glow)
        Look.Art(glow, "legacyPlusGlow")
        Look.Crop(glow, 0, 1, 0, 1)
        glow:SetBlendMode("ADD")
    end
end

-- EraUI's own bar for the picked row (in a fight too: the game hands its
-- rows out again as the list changes) and, out of a fight, the row's words.
local function PaintRow(row)
    local own = rows[row]
    if not own then return end
    local header = L.Field(row, "collapsable") == true
    local picked = not header and L.Field(row, "selected") == true
    Look.Shown(own.pick, picked)
    if Look.InFight() then return end
    local text = L.Field(row, "ButtonText")
    if header or picked then L.GoldName(text) else L.Ink(text) end
end

-- The unviewed mark at the row's right end (the game moves it each time).
local function PlaceNote(row)
    local note = L.Field(row, "NotificationIcon")
    if note then L.Pin(note, "RIGHT", row, "RIGHT", -6, 0) end
end

local function DressRow(row)
    local own = {}
    rows[row] = own
    L.Fade(row.GetNormalTexture and row:GetNormalTexture())
    L.Fade(row.GetHighlightTexture and row:GetHighlightTexture())
    L.ButtonFonts(row, GameFontNormal)
    own.glow = L.Bar(row, "glow")
    Look.Inside(own.glow, row, 2, 1, 2, 1)
    own.pick = L.Bar(row, "pick", "BACKGROUND", 0.55)
    Look.Inside(own.pick, row, 2, 1, 2, 1)
    local fold = L.Field(row, "CollapseButton")
    if fold then
        L.Pin(fold, "LEFT", row, "LEFT", 2, 0)
        L.Size(fold, 18, 18)
        L.After(fold, "UpdateCollapsedState", FoldArt)
        FoldArt(fold, L.Field(fold, "collapsed") == true)
    end
    local text = L.Field(row, "ButtonText")
    if text then L.Pins(text, { "LEFT", row, "LEFT", 22, 0 }, { "RIGHT", row, "RIGHT", -8, 0 }) end
    PlaceNote(row)
    L.AfterOwn(row, "CheckHighlightTitle", PaintRow)
    L.AfterOwn(row, "SetSelected", PaintRow)
    L.AfterOwn(row, "Init", function(self)
        PaintRow(self)
        if not Look.InFight() then PlaceNote(self) end
    end)
end

local fresh = false -- while true, only what isn't dressed yet is painted

local function Row(row)
    if type(row) ~= "table" or not L.Field(row, "ButtonText") then return end
    if rows[row] and fresh then return end
    if not rows[row] then DressRow(row) end
    PaintRow(row)
end

---------------------------------------------------------------------------
-- The challenges and their objectives
---------------------------------------------------------------------------

local CARD_FADED = { "Background", "BackgroundTop", "BackgroundMiddle", "BackgroundBottom", "SelectedOverlay", "TitleBar",
    "PlusMinus" }

local function PaintObjective(row)
    local own = criteria[row]
    if not own then return end
    local done = L.IsShown(L.Field(row, "Check"))
    Look.Shown(own.check, done)
    if Look.InFight() then return end
    L.Ink(L.Field(row, "Name"), done and L.INK or L.FADED_INK)
end

local function DressObjective(row)
    local own = {}
    criteria[row] = own
    for _, key in ipairs({ "Background", "ProgressBarBackground", "Check" }) do L.Fade(L.Field(row, key)) end
    own.check = L.Check(row, "check", 18)
    local mark = L.Field(row, "Check")
    if mark then Look.Pin(own.check, "CENTER", mark, "CENTER", 0, 0) end
    L.SkillBar(L.Field(row, "ProgressBar"), L.GREEN_BAR)
    L.AfterOwn(row, "Init", PaintObjective)
end

local function Objective(row)
    if type(row) ~= "table" or not L.Field(row, "Name") then return end
    if criteria[row] and fresh then return end
    if not criteria[row] then DressObjective(row) end
    PaintObjective(row)
end

-- The open challenge's objectives (the game's one shared objectives frame).
function L.Objectives()
    local holder = _G.LegacyChallengeObjectives
    local pool = holder and L.Field(holder, "criteriaPool")
    if pool then L.EachActive(pool, Objective) end
end

-- A challenge's Legacy points: the game's crown and its number faded (the
-- game sets the number's font again each time it hands the card out, in a
-- fight too); the crown's button (its points tooltip) made the plate's size
-- and hung under the icon, overlapping the slot's foot like the talent
-- window's rank plates, so the text has the card's width; EraUI's rank plate
-- on it and EraUI's own number on that, copied from the game's.
local function DressPoints(own, shield, holder)
    local number = L.Field(shield, "Points")
    L.Fade(L.Field(shield, "Icon"))
    L.Fade(number)
    L.Size(shield, PLATE_W, PLATE_H)
    if holder then L.Pin(shield, "CENTER", holder, "BOTTOM", 0, -6) end
    own.plate = L.Plate(shield, "plate", "ARTWORK", 0, true, PLATE_W, PLATE_H)
    Look.Pin(own.plate, "CENTER", shield, "CENTER", 0, 0)
    own.points = L.Label(shield, "points", "GameFontHighlight", "OVERLAY")
    Look.Pin(own.points, "CENTER", own.plate, "CENTER", 0, 0)
end

-- The game's number copied onto EraUI's plate, both shown only while the
-- game shows one (none for a challenge worth no points). EraUI's own
-- pieces only, so in a fight too.
local function PaintPoints(own, shield)
    if not own.points then return end
    local number = L.Field(shield, "Points")
    local words = number and number:GetText()
    if Look.Secret(words) then words = nil end
    if type(words) == "number" then words = tostring(words) end
    local worth = type(words) == "string" and words ~= "" and L.IsShown(number)
    if worth then own.points:SetText(words) end
    Look.Shown(own.points, worth)
    Look.Shown(own.plate, worth)
end

-- EraUI's own bar, plus or minus, check and points (in a fight too: the
-- game hands its cards out again as the list changes) and, out of a fight,
-- the words.
local function PaintCard(card)
    local own = cards[card]
    if not own then return end
    local picked = L.IsShown(L.Field(card, "SelectedOverlay"))
    local done = L.Field(card, "completed") == true
    Look.Shown(own.pick, picked)
    local sign = L.Field(card, "PlusMinus")
    local signed = L.IsShown(sign)
    Look.Shown(own.sign, signed)
    if signed then Look.Art(own.sign, L.AtlasOf(sign):find("minus", 1, true) and "legacyMinus" or "legacyPlus") end
    local shield = L.Field(card, "Shield")
    Look.Shown(own.check, L.IsShown(shield and L.Field(shield, "Check")))
    if shield then PaintPoints(own, shield) end
    if Look.InFight() then return end
    local name = L.Field(card, "Label")
    -- The game makes the name 320 wide each time it hands the card out (for
    -- its 516-wide card): kept to this card, a long name wrapping as the
    -- quest log's did.
    L.Width(name, NAME_W)
    -- Not done: brown ink on the parchment (dim gold read poorly on it);
    -- dim gold with Dark Windows, as before.
    if done or picked then
        L.GoldName(name)
    elseif L.Darkened() then
        L.Paint(name, L.DIM_GOLD, true)
    else
        L.Paint(name, L.INK, false)
    end
    L.Ink(L.Field(card, "Description"))
    L.Ink(L.Field(card, "HiddenDescription"))
    if shield then L.Ink(L.Field(shield, "DateCompleted")) end
end

local function DressCard(card)
    local own = {}
    cards[card] = own
    for _, key in ipairs(CARD_FADED) do L.Fade(L.Field(card, key)) end
    local icon = L.Field(card, "Icon")
    local face = icon and L.Field(icon, "texture")
    if face then
        L.Fade(L.Field(icon, "frame"))
        own.socket, own.ring = L.Slot(icon, face, "BACKGROUND")
    end
    -- The description and its full copy (shown when open) narrowed to the
    -- card (the game makes them 400 wide once, for its 516-wide card).
    L.Width(L.Field(card, "Description"), TEXT_W)
    L.Width(L.Field(card, "HiddenDescription"), TEXT_W)
    local shield = L.Field(card, "Shield")
    if shield then
        L.Fade(L.Field(shield, "CheckBackground"))
        L.Fade(L.Field(shield, "Check"))
        -- The old check at the slot's top right, as on the reward list.
        own.check = L.Check(shield, "check", 22)
        if face then Look.Pin(own.check, "CENTER", face, "TOPRIGHT", 0, 0) end
        DressPoints(own, shield, face)
        -- The date a done one was earned hangs beside the crown's check,
        -- which moved under the icon with its button: kept at the card's
        -- top right, where the game shows it (the game only sets its words).
        local date = L.Field(shield, "DateCompleted")
        if date then L.Pin(date, "TOPRIGHT", card, "TOPRIGHT", -10, -8) end
    end
    own.rule = L.Own(card, "rule", "BACKGROUND", 1)
    own.rule:SetColorTexture(L.RULE[1], L.RULE[2], L.RULE[3], L.RULE[4])
    own.rule:SetHeight(1)
    own.rule:ClearAllPoints()
    own.rule:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 12, 1)
    own.rule:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -12, 1)
    own.glow = L.Bar(card, "glow", nil, 0.5)
    Look.Inside(own.glow, card, 4, 3, 4, 3)
    own.pick = L.Bar(card, "pick", "BACKGROUND", 0.4)
    Look.Inside(own.pick, card, 4, 3, 4, 3)
    own.sign = L.Own(card, "sign", "OVERLAY", 1, true)
    own.sign:SetSize(16, 16)
    local sign = L.Field(card, "PlusMinus")
    if sign then Look.Pin(own.sign, "CENTER", sign, "CENTER", 0, 0) end
    for _, method in ipairs({ "RefreshStateArt", "UpdatePlusMinusTexture", "Init" }) do L.AfterOwn(card, method, PaintCard) end
    L.After(card, "DisplayObjectives", function() L.Objectives() end)
end

local function Card(card)
    if type(card) ~= "table" or not L.Field(card, "Shield") or not L.Field(card, "Label") then return end
    if cards[card] and fresh then return end
    if not cards[card] then DressCard(card) end
    PaintCard(card)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

-- Every shown category row, challenge and objective, dressed and painted
-- (newOnly: only the ones not dressed yet).
function L.ChallengeLists(page, newOnly)
    if not page then return end
    fresh = newOnly == true
    local list = L.Field(page, "CategoryList")
    if list then L.EachShown(L.Field(list, "ScrollBox"), Row) end
    local pane = L.Field(page, "DetailPane")
    if pane then L.EachShown(L.Field(pane, "ScrollBox"), Card) end
    L.Objectives()
    fresh = false
end

-- The page's parts where they go: the summary in the band, the list on the
-- top part (its search, filter, rows and scroll bar inside it, as the game
-- anchors them), the rule, the challenges' pane under it. The game anchors
-- these once, so they hold.
local function Places(page, window)
    L.FadeArt(L.Field(page, "VerticalDivider"))
    L.Rule(page, window, RULE_Y)
    local summary = L.Field(page, "LegacyChallengePointSummary")
    if summary then
        L.Size(summary, SUMMARY_W, SUMMARY_H)
        -- The bar's middle on the band's (the bar is 3 under the summary's).
        L.At(summary, "TOPLEFT", window, SUMMARY_X, L.BAND - 3 - SUMMARY_H / 2)
    end
    L.Pins(L.Field(page, "CategoryList"), { "TOPLEFT", window, "TOPLEFT", SIDE, -LIST_TOP },
        { "BOTTOMRIGHT", window, "TOPRIGHT", -SIDE, -LIST_BOTTOM })
    L.Pins(L.Field(page, "DetailPane"), { "TOPLEFT", window, "TOPLEFT", SIDE, -PANE_TOP },
        { "BOTTOMRIGHT", window, "BOTTOMRIGHT", -PANE_RIGHT, PANE_FOOT })
end
L.ChallengePlaces = Places

function L.DressChallenges(page, window)
    if not (page and window) then return end
    Look.Try(Places, page, window)
    local summary = L.Field(page, "LegacyChallengePointSummary")
    if summary then
        L.Fade(L.Field(summary, "ProgressBarBackground"))
        local bar = L.Field(summary, "PointsBar")
        L.SkillBar(bar, L.PURPLE)
        -- The plate 20 left of the bar: clear of the skill bar's rim (5 out).
        L.ShieldPlate(L.Field(summary, "Shield"), bar, -20)
    end
    local function Again() L.ChallengeLists(page) end
    local list = L.Field(page, "CategoryList")
    if list then
        Look.SkinDropdown(L.Field(list, "FilterDropdown"))
        local bar = L.Field(list, "ScrollBar")
        if bar then
            Look.ThinScrollBar(bar)
            Look.TrackColumn(bar)
            L.KnobShows(Look.OwnPiece(L.Field(bar, "Track"), "knob"))
        end
        L.After(list, "RefreshCategorySelectionVisuals", Again)
    end
    local pane = L.Field(page, "DetailPane")
    if pane then
        local bar = L.Field(pane, "ScrollBar")
        if bar then
            Look.ThinScrollBar(bar)
            L.KnobShows(Look.OwnPiece(L.Field(bar, "Track"), "knob"))
        end
        for _, method in ipairs({ "GenerateDataProvider", "SelectChallenge", "UpdateChallenge" }) do L.After(pane, method, Again) end
    end
    L.After(page, "UpdateCategoryList", Again)
    Again()
    -- EraUI's own list and details, or (with a gamepad) this page as it is.
    if L.ChallengeMode then Look.Try(L.ChallengeMode, page, window) end
end
