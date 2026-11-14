-- The 1.x bag sheet behind a bag window: what to draw for a window of a given
-- size and kind (a plan, worked out without touching any frame), and drawing
-- it in horizontal bands from the top down. Numbers are the 1.x art's own
-- pixels at the window's scale 1.
--
-- A band is three kinds of piece cut from the same rows of its sheet: the
-- right end (sheet columns 204 to 256), one or more copies of the 42-wide
-- column just left of it (162 to 204, one slot apart) and the left part (0
-- to 162). The right end is pinned and the rest hangs off it leftwards, so a
-- band is 256 wide at four columns and 42 wider per column past four, and
-- reaches 64 past the window's left edge, as the old bag frame did.
local _, EraUI = ...
local Look = EraUI.Look
local B = Look.Bags

local BAG_ROWS, BAG_COLS = 512, 256 -- UI-Bag-Components
local PACK_SPLIT = 210 / 255        -- UI-BackpackBackground: top part, money strip below
-- The money strip cut for more strips under it: its box with the two dark
-- rows above it (sheet rows 212 to 230; the gold edge is rows 214 to 229)
-- drawn once more per strip between the strip and its bottom edge (rows 230
-- on).
local STRIP_CUT, BOX_TOP = 230 / 256, 212 / 256
local SLOT_ACROSS, SLOT_DOWN = 42, 41

-- One more strip's height (the box's 18 sheet rows, 1:1).
B.STRIP_TALL = 18

-- Sheet columns of the three kinds of piece: left edge, right edge, width.
local PIECES = {
    right = { 204, 256, 52 },
    column = { 162, 204, 42 },
    left = { 0, 162, 162 },
}

---------------------------------------------------------------------------
-- The plan
---------------------------------------------------------------------------

-- A band cut from the bag sheet's rows `from` to `to`, drawn `tall` high.
local function BagRows(from, to, tall)
    return { key = "bagSheet", top = from / BAG_ROWS, bottom = to / BAG_ROWS, tall = tall }
end

-- The same, drawn 1:1: `tall` rows down from `from`.
local function BagBand(from, tall)
    return BagRows(from, from + tall, tall)
end

local function PackBand(top, bottom, tall)
    return { key = "backpackSheet", top = top, bottom = bottom, tall = tall }
end

-- Rows of slots in bands of at most `most` rows.
local function Bands(rowsLeft, most, each)
    local first = true
    while rowsLeft > 0 do
        local n = math.min(most, rowsLeft)
        each(n, first)
        first = false
        rowsLeft = rowsLeft - n
    end
end

-- An ordinary bag: a top, its remaining rows in bands of up to six, a lip.
-- The one-row and usual tops stretch their sheet rows (2 to 86, 2 to 94) a
-- little to 86 and 94 high, as the 1.x bag did; everything else is 1:1.
local function OrdinaryBands(plan)
    local bands = plan.bands
    if plan.twoSlot then
        bands[1] = BagBand(97, 72)
    elseif plan.rows == 1 then
        bands[1] = BagRows(2, 86, 86)
    else
        bands[1] = BagRows(2, 94, 94)
    end
    Bands(plan.rows - 1, 6, function(n, first)
        if first then bands[#bands + 1] = BagBand(181, n * SLOT_DOWN - 9)
        else bands[#bands + 1] = BagBand(213, n * SLOT_DOWN) end
    end)
    bands[#bands + 1] = BagBand(169, 10)
end

-- The backpack and the One Bag window: the backpack sheet whole; or, with
-- rows past four or more strips, its top, the extra rows in bands of up to
-- five, then its money strip (with more strips: the strip down to its box's
-- end, the box again once per strip, the strip's bottom edge).
local function BackpackBands(plan)
    local bands = plan.bands
    if plan.extra == 0 and plan.strips == 0 then
        bands[1] = PackBand(0, 1, 255)
        return
    end
    bands[1] = PackBand(0, PACK_SPLIT, 210)
    Bands(plan.extra, 5, function(n)
        bands[#bands + 1] = BagBand(215, n * SLOT_DOWN)
    end)
    if plan.strips == 0 then
        bands[#bands + 1] = PackBand(PACK_SPLIT, 1, 45)
        return
    end
    bands[#bands + 1] = PackBand(PACK_SPLIT, STRIP_CUT, 19)
    for _ = 1, plan.strips do bands[#bands + 1] = PackBand(BOX_TOP, STRIP_CUT, B.STRIP_TALL) end
    bands[#bands + 1] = PackBand(STRIP_CUT, 1, 26)
end

-- What a window of `size` slots wears. backpack: the backpack style (the
-- backpack, or the One Bag window); reversed: the One Bag window's fill;
-- strips: how many more money strips go under the gold's (backpack style
-- only), the window that much taller.
function B.Plan(size, columns, backpack, reversed, strips)
    local plan = {
        size = size, columns = columns, backpack = backpack and true or false, reversed = reversed and true or false,
        rows = math.ceil(size / columns), wider = SLOT_ACROSS * (columns - 4), bands = {},
    }
    plan.twoSlot = not plan.backpack and size % 4 == 2
    plan.extra = plan.backpack and math.max(0, plan.rows - 4) or 0
    plan.strips = plan.backpack and type(strips) == "number" and math.max(0, math.floor(strips)) or 0
    plan.width = 192 + plan.wider
    if plan.backpack then
        BackpackBands(plan)
        plan.height = 240 + SLOT_DOWN * plan.extra + B.STRIP_TALL * plan.strips
    else
        OrdinaryBands(plan)
        local tall = 0
        for _, band in ipairs(plan.bands) do tall = tall + band.tall end
        plan.height = tall
    end
    return plan
end

-- Where a slot cell's bottom-right corner goes: the window's point and the
-- offset from it. c counts columns from the right, r rows from the bottom.
function B.Spot(plan, c, r)
    local x = -12 - SLOT_ACROSS * c
    if plan.backpack then return "TOPRIGHT", x, -211 - SLOT_DOWN * plan.extra + SLOT_DOWN * r end
    return "BOTTOMRIGHT", x, 9 + SLOT_DOWN * r
end

-- The cell of the i-th of `count` items. Bags fill from the bottom-right,
-- leftwards, then upwards (the part-filled row is the top one, filled from
-- its right). The One Bag window takes its items last first and fills in
-- reading order from the top-left (the part-filled row is the bottom one).
function B.Cell(plan, i, count)
    local columns = plan.columns
    if plan.reversed then
        local j = count - i
        return columns - 1 - (j % columns), plan.rows - 1 - math.floor(j / columns)
    end
    local k = i - 1
    return k % columns, math.floor(k / columns)
end

---------------------------------------------------------------------------
-- The gold strip and the watched currencies on it
---------------------------------------------------------------------------

-- The money strip's box is the backpack sheet's columns 81 to 243 and rows
-- 214 to 229 (gold edge included). Hung from the window's top-right, the
-- inside of its gold edge runs from 18 past the window's left edge to 13
-- short of its right: 161 across at four columns, 42 more per column. The
-- gold is pinned 6 in from the window's right and 215 down (41 more per
-- extra row); its last coin ends 13 further in, 6 inside the box. The
-- currencies keep the same 6 on the left (from 24 across), end 19 short of
-- the window's right on the strips under the gold's, and stay 6 apart, from
-- each other and from the gold.
B.MONEY_RIGHT, B.MONEY_TOP = 6, 215
local TOKEN_LEFT, TOKEN_END, TOKEN_GAP = 24, 19, 6

-- How far down the gold's top is.
function B.MoneyTop(plan)
    return B.MONEY_TOP + SLOT_DOWN * plan.extra
end

-- Where the watched currencies go: `widths` holds each one's width (amount
-- and icon) in the game's watched order, `gold` the gold's width (0: none
-- shown). Each gets { x, strip } (x from the window's left edge; strip 1 is
-- the gold's, 2 the one under it, and so on), or false when it is wider
-- than a whole strip. The gold's strip takes them from its left while the
-- next one fits left of the gold; the rest go on the strips under it, each
-- from its left, a new strip whenever the next one would run past the end.
-- Returns the spots and how many strips under the gold's are needed.
function B.TokenSpots(plan, widths, gold)
    local spots, count = {}, #widths
    local edge = plan.width - TOKEN_END
    if gold > 0 then edge = plan.width - B.MONEY_RIGHT - gold - TOKEN_GAP end
    local x, i = TOKEN_LEFT, 1
    while i <= count and x + widths[i] <= edge do
        spots[i] = { x, 1 }
        x = x + widths[i] + TOKEN_GAP
        i = i + 1
    end
    local last, strip = plan.width - TOKEN_END, 1
    x = math.huge
    for j = i, count do
        local wide = widths[j]
        if TOKEN_LEFT + wide > last then
            spots[j] = false
        else
            if x + wide > last then strip, x = strip + 1, TOKEN_LEFT end
            spots[j] = { x, strip }
            x = x + wide + TOKEN_GAP
        end
    end
    return spots, strip - 1
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

local function Purpose(band, piece) return "bagBand" .. band .. piece end

local function Cut(texture, kind, band)
    local cols = PIECES[kind]
    Look.Art(texture, band.key)
    Look.Crop(texture, cols[1] / BAG_COLS, cols[2] / BAG_COLS, band.top, band.bottom)
    texture:SetSize(cols[3], band.tall)
    texture:SetAlpha(1)
    texture:Show()
end

-- One band: its right end hung from `above` (the window's top-right for the
-- first band, else the band above's right end), the columns and the left
-- part hung off it leftwards. Returns the right end.
local function DrawBand(window, index, band, copies, above)
    local right = B.Own(window, Purpose(index, "R"), -1)
    Cut(right, "right", band)
    if above then Look.Pin(right, "TOPRIGHT", above, "BOTTOMRIGHT", 0, 0)
    else Look.Pin(right, "TOPRIGHT", window, "TOPRIGHT", 0, 0) end
    local hangFrom = right
    for j = 1, copies do
        local column = B.Own(window, Purpose(index, "C" .. j), -1)
        Cut(column, "column", band)
        Look.Pin(column, "TOPRIGHT", hangFrom, "TOPLEFT", 0, 0)
        hangFrom = column
    end
    for j = copies + 1, math.huge do
        local spare = Look.OwnPiece(window, Purpose(index, "C" .. j))
        if not spare then break end
        spare:Hide()
    end
    local left = B.Own(window, Purpose(index, "L"), -1)
    Cut(left, "left", band)
    Look.Pin(left, "TOPRIGHT", hangFrom, "TOPLEFT", 0, 0)
    return right
end

-- A band drawn before and not wanted now, every piece of it hidden.
local function HideBand(window, index)
    local right = Look.OwnPiece(window, Purpose(index, "R"))
    if not right then return false end
    right:Hide()
    local left = Look.OwnPiece(window, Purpose(index, "L"))
    if left then left:Hide() end
    for j = 1, math.huge do
        local column = Look.OwnPiece(window, Purpose(index, "C" .. j))
        if not column then break end
        column:Hide()
    end
    return true
end

function B.DrawSheet(window, plan)
    local copies = math.max(1, plan.columns - 3)
    local above
    for index, band in ipairs(plan.bands) do
        above = DrawBand(window, index, band, copies, above)
    end
    local index = #plan.bands + 1
    while HideBand(window, index) do index = index + 1 end
end

-- Plain stone over the cells no slot fills (none on a two-slot top, whose
-- art already shows a two-cell row): from the first empty cell's corner, one
-- right and one down, stretching left over every empty cell.
function B.DrawStone(window, plan, count)
    local missing = plan.rows * plan.columns - count
    if missing <= 0 or plan.twoSlot then
        local stone = Look.OwnPiece(window, "bagStone")
        if stone then stone:Hide() end
        return
    end
    local stone = B.Own(window, "bagStone", 0)
    Look.Art(stone, "bagSheet")
    Look.Crop(stone, 110 / BAG_COLS, 158 / BAG_COLS, 126 / BAG_ROWS, 160 / BAG_ROWS)
    stone:SetSize(missing * SLOT_ACROSS - 3, 37)
    local c, r = 0, 0
    if not plan.reversed then c, r = count % plan.columns, math.floor(count / plan.columns) end
    local point, x, y = B.Spot(plan, c, r)
    Look.Pin(stone, "BOTTOMRIGHT", window, point, x + 1, y - 1)
    stone:SetAlpha(1)
    stone:Show()
end
