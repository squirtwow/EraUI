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
local SLOT_ACROSS, SLOT_DOWN = 42, 41

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
-- rows past four, its top, the extra rows in bands of up to five, then its
-- money strip.
local function BackpackBands(plan)
    local bands = plan.bands
    if plan.extra == 0 then
        bands[1] = PackBand(0, 1, 255)
        return
    end
    bands[1] = PackBand(0, PACK_SPLIT, 210)
    Bands(plan.extra, 5, function(n)
        bands[#bands + 1] = BagBand(215, n * SLOT_DOWN)
    end)
    bands[#bands + 1] = PackBand(PACK_SPLIT, 1, 45)
end

-- What a window of `size` slots wears. backpack: the backpack style (the
-- backpack, or the One Bag window); reversed: the One Bag window's fill.
function B.Plan(size, columns, backpack, reversed)
    local plan = {
        size = size, columns = columns, backpack = backpack and true or false, reversed = reversed and true or false,
        rows = math.ceil(size / columns), wider = SLOT_ACROSS * (columns - 4), bands = {},
    }
    plan.twoSlot = not plan.backpack and size % 4 == 2
    plan.extra = plan.backpack and math.max(0, plan.rows - 4) or 0
    plan.width = 192 + plan.wider
    if plan.backpack then
        BackpackBands(plan)
        plan.height = 240 + SLOT_DOWN * plan.extra
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
