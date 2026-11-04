-- The band's geometry as plain arithmetic, with no frames: how wide the 1.x
-- stone band is, where each part of it sits, and which slices of the two
-- Blizzard sheets paint it. Also the small decisions made when a piece is
-- dropped in Edit Mode (near the band or not, which side, a gryphon held or
-- moved). Everything is in band units: pixels of the 1.x art at band scale 1.
local _, EraUI = ...
local Look = EraUI.Look

local Shape = {}
Look.Shape = Shape

Shape.HEIGHT = 53       -- the band frame: the 43-unit body plus the XP strip above it
Shape.BODY = 43
Shape.HALF = 512        -- the left half: twelve 42-unit slots and their ends
Shape.SLOT = 42         -- one action slot's pitch
Shape.BAGS = 182        -- the bag area (the key ring sheet's right-most columns)
Shape.NOOK = 36         -- the page arrow nook
Shape.POST = 8          -- the closing stone post
Shape.MICRO_ROOM = 280  -- room for the micro buttons before they shrink
Shape.MICRO_PITCH = 25  -- 28-unit buttons overlapping by 3
Shape.MICRO_MAX, Shape.MICRO_MIN = 330, 50

-- The four 256-unit pieces: their sheet, the rows of the band body (drawn 43
-- tall) and the rows of the 10-unit XP strip (always from the dwarf sheet).
Shape.PIECES = {
    { sheet = "dwarf", sheetHeight = 256, rows = { 213, 256 }, strip = { 203, 213 } },
    { sheet = "dwarf", sheetHeight = 256, rows = { 149, 192 }, strip = { 139, 149 } },
    { sheet = "keyring", sheetHeight = 128, rows = { 85, 128 }, strip = { 75, 85 } },
    { sheet = "keyring", sheetHeight = 128, rows = { 21, 64 }, strip = { 11, 21 } },
}
Shape.POST_COLUMNS = { 82, 90 } -- piece 4's stone post
Shape.BAG_COLUMNS = { 74, 256 } -- piece 4's bag area

-- The micro menu's region: the room its shown buttons need, shrunk to fit and
-- scaled by its own size. Returns the region width, the fit now, and the fit
-- at size 1.
function Shape.MicroFit(count, microScale)
    count = math.max(0, tonumber(count) or 0)
    local need = Shape.MICRO_PITCH * count + 3
    local fitAtOne = math.min(1, Shape.MICRO_ROOM / need)
    local fit = fitAtOne * (tonumber(microScale) or 1)
    local region = math.ceil(45 + need * fit + 5)
    region = math.max(Shape.MICRO_MIN, math.min(Shape.MICRO_MAX, region))
    return region, fit, fitAtOne
end

-- Action Bar 1's shown icons (1 to 12; anything else counts as 12).
function Shape.Icons(value)
    local icons = tonumber(value)
    if not icons or icons < 1 or icons > 12 or icons ~= math.floor(icons) then return 12 end
    return icons
end

local function Add(list, piece, x, width, from, to)
    if width <= 0 then return end
    list[#list + 1] = { piece = piece, x = x, width = width, from = from, to = to }
end

-- The slices that paint a band of this shape, left to right, the post last.
-- Each: piece (1 to 4), x and width on the band, from and to (the sheet's
-- columns shown).
function Shape.Slices(s)
    local list, cut, base = {}, s.cut, s.base
    if cut < 256 then
        Add(list, 1, 0, 256 - cut, cut, 256)
        Add(list, 2, 256 - cut, 256, 0, 256)
    else
        Add(list, 2, 0, Shape.HALF - cut, cut - 256, 256)
    end
    if s.microLeads and s.pages then
        local first = math.min(s.region, 256)
        Add(list, 3, base, first, 0, first)
        if s.region > 256 then Add(list, 4, base + 256, s.region - 256, 0, s.region - 256) end
    elseif s.pages then
        Add(list, 3, s.nookX, Shape.NOOK, 0, Shape.NOOK)
    end
    if s.bagsOn then Add(list, 4, s.bagsX, Shape.BAGS, Shape.BAG_COLUMNS[1], Shape.BAG_COLUMNS[2]) end
    if s.microOn and not (s.microLeads and s.pages) then
        local width = s.microEnd - s.microStart
        local first = math.min(width, 219)
        Add(list, 3, s.microStart, first, 37, 37 + first)
        if width > first then Add(list, 4, s.microStart + first, width - first, 0, width - first) end
    end
    Add(list, 4, s.width - Shape.POST, Shape.POST, Shape.POST_COLUMNS[1], Shape.POST_COLUMNS[2])
    return list
end

-- The band's shape from what sits on it:
--   microOn, bagsOn, bagsFirst (only with both on), pages (the page arrows
--   show), icons (Action Bar 1's icon count), microCount (shown micro
--   buttons, the shop never counted), microScale.
-- Returns: width, cut, base (where the right half starts), the micro region
-- (microStart, microEnd, microX: its first button), bagsX, nookX, region and
-- the fits, and the slices.
function Shape.Compute(input)
    local s = {}
    s.microOn = input.microOn and true or false
    s.bagsOn = input.bagsOn and true or false
    s.bagsFirst = (input.bagsFirst and s.microOn and s.bagsOn) and true or false
    s.pages = input.pages ~= false
    s.icons = Shape.Icons(input.icons)
    s.cut = Shape.SLOT * (12 - s.icons)
    s.base = Shape.HALF - s.cut
    s.region, s.fit, s.fitAtOne = Shape.MicroFit(input.microCount, input.microScale)
    s.microLeads = s.microOn and not s.bagsFirst
    local x = s.base
    if s.microLeads then
        s.microStart = x
        if s.pages then
            s.microX = x + 43
            s.microEnd = x + s.region
        else
            s.microX = x + 8
            s.microEnd = x + s.region - 37
        end
        x = s.microEnd
        if s.bagsOn then
            s.bagsX = x
            x = x + Shape.BAGS
        end
    else
        if s.pages then
            s.nookX = x
            x = x + Shape.NOOK
        end
        if s.bagsOn then
            s.bagsX = x
            x = x + Shape.BAGS
        end
        if s.microOn then
            s.microStart = x
            s.microX = x + 8
            s.microEnd = x + s.region - 37
            x = s.microEnd
        end
    end
    s.width = x
    s.slices = Shape.Slices(s)
    return s
end

-- A gryphon's home: its bottom-centre, from the band's left, in band units.
function Shape.CapHomeX(width, side)
    if side == "left" then return -32 end
    return width + 32
end

-- A dropped piece is near the band when its bottom is within the tolerance of
-- the band's bottom and its middle lies over the band's right half (a little
-- past either end). All values in the same units; tolerance scales the 48 and
-- the 96.
function Shape.NearBand(bottom, middle, bandBottom, rightHalfStart, bandRight, tolerance)
    if not (bottom and middle and bandBottom and rightHalfStart and bandRight) then return false end
    local unit = (tolerance or 48) / 48
    return math.abs(bottom - bandBottom) <= 48 * unit
        and middle >= rightHalfStart - 48 * unit and middle <= bandRight + 96 * unit
end

-- Which side a dropped piece takes: true when it goes first (leftmost). The
-- margin keeps the current choice until the piece clearly crosses the line.
function Shape.GoesFirst(middle, line, wasFirst, margin)
    margin = margin or 16
    if wasFirst then return middle < line + margin end
    return middle < line - margin
end

-- A gryphon let go in Edit Mode is held (it follows the band again) when its
-- bottom-left lands within the tolerance of its home's bottom-left.
function Shape.CapHeld(left, bottom, homeLeft, homeBottom, tolerance)
    if not (left and bottom and homeLeft and homeBottom) then return false end
    tolerance = tolerance or 48
    return math.abs(left - homeLeft) <= tolerance and math.abs(bottom - homeBottom) <= tolerance
end
