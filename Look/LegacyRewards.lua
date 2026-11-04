-- The Legacy window's Progress Track page in the 1.x look (registry
-- "legacyWindow"), laid out on the spellbook-sized parchment like a quest's
-- reward list:
--   * at the top, the Legacy points in gold in the professions book's round
--     ring on a dark disc where the game's retail crown was, "Legacy Points"
--     in gold beside it and the points bar, shorter, as the old skill bar
--     under that, a thin rule below;
--   * the game's own reward cards down the page, one under the other: each
--     icon in the spellbook's amber slot and ring (dimmed until earned), its
--     name beside it (gold once earned, brown before), the points it needs on
--     a talent rank plate at the right, the old check once earned;
--   * the track's arrows (the game shows them only when its track has more
--     rewards than fit) as the spellbook's page arrows at the foot; then the
--     list shows four from the game's chosen one.
-- The game's own card art is faded, its hover glow too (the card's retail
-- art again, added in build 70532); the cards, their tooltips and the
-- arrows keep working. The game lays its cards out in a row afresh each
-- time the page shows: they are laid out again down the page after it, in
-- a fight too (their anchors only, see Look/LegacyKit.lua); dressed when
-- the game sets the track up and after each of its refreshes (in a fight,
-- EraUI's own slot and check only).
local _, EraUI = ...
local Look = EraUI.Look
local L = Look.Legacy

local dressed = L.Record(Look.Weak()) -- a reward card: { socket, ring, plate, check }
-- Highlight: from build 70532 (the game only sets its art and shows or
-- hides it, so its alpha holds); none before.
local CARD_FADED = { "RewardCardBG", "LevelSquare", "IconBorder", "EarnedCheckmark", "Highlight" }
local ARROWS = { "LeftButton", "RightButton", "JumpLeftButton", "JumpRightButton" }

-- The page's places (window units from its top left, down positive).
local RING_X, RING_Y, RING, DISC = 56, 106, 84, 68 -- the points ring
local LABEL_X, LABEL_Y = 108, 88                    -- "Legacy Points"
local BAR_X, BAR_Y, BAR_W, BAR_H = 110, 118, 206, 12 -- the points bar's backing
local RULE_Y = 156
-- The list: the game's track (its clip frame) from LIST_Y down, its cards
-- one under another, SLOTS of them, PITCH apart; the arrows under it.
local LIST_X, LIST_Y, LIST_W, LIST_H = 12, 162, 312, 228
local CARD_W, CARD_H, PITCH, SLOTS = 312, 52, 57, 4
local ICON = 40
local ARROW, ARROW_Y, ARROW_LEFT, ARROW_RIGHT = 26, 403, 140, 196
-- A card not in the list's four: right of the clip frame, so it is clipped
-- away (no art, no mouse) until it is in the four again.
local AWAY = CARD_W + 120

local function DressCard(card)
    for _, key in ipairs(CARD_FADED) do L.Fade(L.Field(card, key)) end
    L.Size(card, CARD_W, CARD_H)
    local icon = L.Field(card, "Icon")
    local own = {}
    if icon then
        L.Size(icon, ICON, ICON)
        L.Pin(icon, "LEFT", card, "LEFT", 10, 0)
        own.socket, own.ring = L.Slot(card, icon, "BACKGROUND")
    end
    local name = L.Field(card, "RewardName")
    if name and icon then
        L.Width(name, CARD_W - ICON - 10 - 14 - 64)
        L.Justify(name, "LEFT")
        L.Pin(name, "LEFT", icon, "RIGHT", 14, 0)
    end
    local level = L.Field(card, "Level")
    if level then
        L.Pin(level, "CENTER", card, "RIGHT", -30, 0)
        own.plate = L.Plate(card, "plate")
        Look.Pin(own.plate, "CENTER", level, "CENTER", 0, 0)
    end
    own.check = L.Check(card, "check", 26)
    if icon then Look.Pin(own.check, "CENTER", icon, "TOPRIGHT", -2, -2) end
    dressed[card] = own
    return own
end

---------------------------------------------------------------------------
-- The list: the game's cards down the page
---------------------------------------------------------------------------

-- The first card of the four the list shows: the first, or (when the game's
-- track scrolls) the one before the game's chosen one, kept in range.
local function First(track, count)
    if count <= SLOTS then return 1 end
    local chosen = Look.Number(L.Field(track, "selectedIndex")) or 1
    return math.max(1, math.min(count - SLOTS + 1, chosen - 1))
end

-- Each card by its middle on the clip frame's middle (one anchor, the kind
-- the game moves its first card by when its track scrolls, so a move of the
-- game's replaces EraUI's instead of fighting it). Anchors only: also in a
-- fight, right after the game laid them out in a row again.
function L.LayCards(page)
    local track = L.Field(page, "LegacyRewardProgressFrame")
    local clip = track and L.Field(track, "ClipFrame")
    local cards = track and L.Field(track, "Elements")
    if not clip or type(cards) ~= "table" then return end
    local first = First(track, #cards)
    local top = LIST_H / 2 - CARD_H / 2
    for i, card in ipairs(cards) do
        local slot = i - first
        if slot >= 0 and slot < SLOTS then
            Look.Pin(card, "CENTER", clip, "CENTER", 0, top - slot * PITCH)
        else
            Look.Pin(card, "CENTER", clip, "CENTER", AWAY, 0)
        end
    end
end

-- Off: the cards back in the game's row (as its own set up lays them: the
-- first at the clip frame's left, or its middle when the track scrolls, each
-- next one after the one before).
L.Undo(function()
    local window = L.Window and L.Window()
    local page = window and L.Field(window, "RewardTrackPage")
    local track = page and L.Field(page, "LegacyRewardProgressFrame")
    local clip = track and L.Field(track, "ClipFrame")
    local cards = track and L.Field(track, "Elements")
    if not clip or type(cards) ~= "table" then return end
    local spacing = Look.Number(L.Field(track, "elementSpacing")) or 0
    local offset = Look.Number(L.Field(track, "offset")) or 0
    for i, card in ipairs(cards) do
        card:ClearAllPoints()
        if i > 1 then
            card:SetPoint("LEFT", cards[i - 1], "RIGHT", spacing, 0)
        elseif L.Field(track, "disableCentering") == true then
            card:SetPoint("LEFT", clip, "LEFT", 0, 0)
        else
            card:SetPoint("CENTER", clip, "CENTER", -offset, 0)
        end
    end
end)

-- The card's look for whether it is earned (the game's own check shown).
-- In a fight only EraUI's own check and slot follow (on a card dressed
-- before it: the game hands its cards out again each time the page shows);
-- the name keeps the game's colour until the fight ends.
local function PaintCard(card)
    local fight = Look.InFight()
    local own = dressed[card]
    if not own then
        if fight then return end
        own = DressCard(card)
    end
    local earned = L.IsShown(L.Field(card, "EarnedCheckmark"))
    Look.Shown(own.check, earned)
    if own.socket then
        own.socket:SetDesaturated(not earned)
        own.socket:SetAlpha(earned and 1 or 0.7)
    end
    if fight then return end
    local name = L.Field(card, "RewardName")
    if earned then L.GoldName(name) else L.Ink(name) end
end
L.PaintCard = PaintCard

-- Every card (fresh: only the ones not dressed yet).
function L.RewardCards(page, fresh)
    local track = L.Field(page, "LegacyRewardProgressFrame")
    local cards = track and L.Field(track, "Elements")
    if type(cards) ~= "table" then return end
    for _, card in ipairs(cards) do
        if not (fresh and dressed[card]) then Look.Try(PaintCard, card) end
    end
end

-- The paragon level at the track's end (shown only for some tracks).
local function Paragon(track)
    local clip = L.Field(track, "ClipFrame")
    local paragon = clip and L.Field(clip, "ParagonLevelFrame")
    if not paragon then return end
    for _, key in ipairs({ "Divider", "LabelBackground", "IconBorder" }) do L.Fade(L.Field(paragon, key)) end
    L.Ink(L.Field(paragon, "Label"))
    L.GoldName(L.Field(paragon, "Level"))
end

-- The page's Legacy points at the top left of the parchment: the game's
-- crown faded; the ring, its disc and the game's own number in it. The game
-- only sets the number's text again, so it stays right by itself.
local function PointsRing(page, window)
    L.Fade(L.Field(page, "Icon"))
    local disc = L.Own(page, "pointsDisc", "BORDER", 0)
    Look.Art(disc, "legacyDisc")
    disc:SetVertexColor(L.DISC[1], L.DISC[2], L.DISC[3])
    disc:SetSize(DISC, DISC)
    Look.Pin(disc, "CENTER", window, "TOPLEFT", RING_X, -RING_Y)
    local ring = L.Ring(page, "pointsRing", RING, "BORDER", 1)
    Look.Pin(ring, "CENTER", window, "TOPLEFT", RING_X, -RING_Y)
    local number = L.Field(page, "Points")
    if number then
        L.At(number, "CENTER", window, RING_X, RING_Y)
        -- Gold; the game's own big font and shadow kept.
        L.Paint(number, L.GOLD)
    end
end

-- "Legacy Points" beside the ring and the bar under it (the bar hangs from
-- its backing, which is where it goes), a rule under both.
local function PointsBar(page, window)
    local label = L.Field(page, "PointsLabel")
    if label then
        L.At(label, "LEFT", window, LABEL_X, LABEL_Y)
        L.GoldName(label)
    end
    local backing = L.Field(page, "ProgressBarBackground")
    if backing then
        L.Fade(backing)
        L.Size(backing, BAR_W, BAR_H)
        L.At(backing, "LEFT", window, BAR_X, BAR_Y)
    end
    L.SkillBar(L.Field(page, "LegacyRewardProgressBar"), L.PURPLE)
    L.Rule(page, window, RULE_Y)
end

-- The game's track as the list's box (its clip frame fills it), and its
-- arrows under it (each jump arrow stays beside its arrow, as the game has
-- it).
local function ListBox(track, window)
    L.Size(track, LIST_W, LIST_H)
    L.At(track, "TOPLEFT", window, LIST_X, LIST_Y)
    for _, key in ipairs(ARROWS) do
        local arrow = L.Field(track, key)
        if arrow then
            Look.SkinStepper(arrow, L.Field(arrow, "direction") == 1)
            -- The spellbook's page arrow's size (its art is 26 square).
            L.Size(arrow, ARROW, ARROW)
        end
    end
    L.At(L.Field(track, "LeftButton"), "CENTER", window, ARROW_LEFT, ARROW_Y)
    L.At(L.Field(track, "RightButton"), "CENTER", window, ARROW_RIGHT, ARROW_Y)
    Look.Try(Paragon, track)
end

function L.DressRewards(page, window)
    if not (page and window) then return end
    Look.Try(PointsRing, page, window)
    Look.Try(PointsBar, page, window)
    local track = L.Field(page, "LegacyRewardProgressFrame")
    if track then Look.Try(ListBox, track, window) end
    -- Also in a fight: the cards laid out down the page again right after
    -- the game laid them in a row (their anchors only), and PaintCard leaves
    -- the game's own pieces alone then.
    local function Again()
        L.LayCards(page)
        L.RewardCards(page)
    end
    L.AfterOwn(page, "SetupRewardTrack", Again)
    L.AfterOwn(page, "OnTrackUpdate", Again)
    -- The game's track moving its first card to a chosen one (its arrows).
    if track then L.AfterOwn(track, "SetSelection", function() L.LayCards(page) end) end
    Again()
end
