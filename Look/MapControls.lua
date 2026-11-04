-- The buttons round the 1.x minimap, each at its old spot: zoom in and out
-- (always shown, with light + and - drawn on in Dark Mode), the magnifying
-- glass for tracking, mail in a gold ring, the calendar page with today's
-- date, Forever's day and night, the clock plate, and Forever's event link.
-- Each is laid out again on every layout pass (the game's own passes undo
-- them). "above" is the map's frame level + 5.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Map = Look.Map

local unpack = unpack or table.unpack

-- A control's seat: its parent (when given), frame level and size.
local function Seat(control, parent, level, width, height)
    if parent then control:SetParent(parent) end
    control:SetFrameLevel(level)
    control:SetSize(width, height or width)
end

local function FullCrop(texture)
    Look.Crop(texture, 0, 1, 0, 1)
end

-- A button state's face: the art, the whole sheet, the whole button.
local function Face(owner, state, key, additive)
    local face = Look.StateArt(owner, state, key)
    if not face then return nil end
    FullCrop(face)
    Look.Fill(face, owner)
    if additive then face:SetBlendMode("ADD") end
    return face
end

-- EraUI's gold ring on a control: one texture of its own, at its top left.
local function GoldRing(control, layer, across)
    local ring = Look.OwnTexture(control, "goldRing", layer)
    Look.Art(ring, "mapGoldRing")
    ring:SetSize(across, across)
    Look.Pin(ring, "TOPLEFT", control, "TOPLEFT", 0, 0)
end

-- Every texture on a control but the ones kept, faded.
local function FadeOthers(control, keep)
    Look.EachRegion(control, function(piece)
        if not keep[piece] and piece:IsObjectType("Texture") then piece:SetAlpha(0) end
    end)
end

---------------------------------------------------------------------------
-- Zoom
---------------------------------------------------------------------------

-- round: from the backdrop's centre; square: from the map's, on its right
-- edge above the corner.
local ZOOMS = {
    { key = "ZoomIn", art = "zoomIn", round = { 72, -25 }, square = { 78, -20 }, plus = true },
    { key = "ZoomOut", art = "zoomOut", round = { 50, -43 }, square = { 78, -44 } },
}
local ZOOM_FACES = { { "Normal", "Up" }, { "Pushed", "Down" }, { "Disabled", "Disabled" } }
local ZOOM_HIT = { 4, 4, 2, 6 }

-- Dark Mode greys the zoom art, and its + and - with it: EraUI draws light
-- ones over each button, made once, dimmed while the map can't zoom further.
local glyphs = Look.Weak()  -- a zoom button: its bars
local looked = Look.Weak()  -- a zoom button: Dark Mode was asked about it

local function GlyphShade(zoomButton)
    local bars = glyphs[zoomButton]
    if bars == nil then return end
    local asked, usable = Look.Ask(zoomButton, "IsEnabled")
    local alpha = (asked and usable == false) and 0.4 or 1
    for _, bar in ipairs(bars) do bar:SetAlpha(alpha) end
end

local function Glyphs(zoomButton, plus)
    if looked[zoomButton] then return end
    looked[zoomButton] = true
    if not Look.Setting("darkMode") then return end
    local bars = {}
    local sizes = plus and { { 10, 3 }, { 3, 10 } } or { { 10, 3 } }
    for _, size in ipairs(sizes) do
        local bar = zoomButton:CreateTexture(nil, "OVERLAY", nil, 7)
        bar:SetColorTexture(0.85, 0.85, 0.87, 1)
        bar:SetSize(size[1], size[2])
        Look.Pin(bar, "CENTER", zoomButton, "CENTER", -0.5, 1.5)
        bars[#bars + 1] = bar
    end
    glyphs[zoomButton] = bars
    Look.HookScript(zoomButton, "OnEnable", GlyphShade)
    Look.HookScript(zoomButton, "OnDisable", GlyphShade)
    GlyphShade(zoomButton)
end

function Map.LayZoom(backdrop, map, above)
    for _, zoom in ipairs(ZOOMS) do
        local zoomButton = map[zoom.key]
        if zoomButton then
            Seat(zoomButton, backdrop, above, 32)
            for _, face in ipairs(ZOOM_FACES) do Face(zoomButton, face[1], zoom.art .. face[2]) end
            Face(zoomButton, "Highlight", "mapZoomGlow", true)
            zoomButton:SetHitRectInsets(unpack(ZOOM_HIT))
            if Map.worn then
                Look.Pin(zoomButton, "CENTER", map, "CENTER", zoom.square[1], zoom.square[2])
            else
                Look.Pin(zoomButton, "CENTER", backdrop, "CENTER", zoom.round[1], zoom.round[2])
            end
            zoomButton:Show()
            Glyphs(zoomButton, zoom.plus)
        end
    end
end

-- 1.x showed both all the time; the game hides them when the mouse leaves
-- the map (run after it, from Minimap's OnLeave).
function Map.KeepZoomShown()
    if not Map.applied or not Minimap then return end
    for _, zoom in ipairs(ZOOMS) do
        local zoomButton = Minimap[zoom.key]
        if zoomButton then zoomButton:Show() end
    end
end

---------------------------------------------------------------------------
-- Tracking: the magnifying glass in its gold ring
---------------------------------------------------------------------------

-- The glass is the button's own normal and pushed art (the game no longer
-- sets either), so the button keeps it by itself: nothing polls it.
local GLASS = { { "Normal", 6, -6 }, { "Pushed", 8, -8 } }

function Map.LayTracking(cluster, backdrop, above)
    local track = cluster.Tracking
    if not track then return end
    Seat(track, backdrop, above, 32)
    Look.Pin(track, "TOPLEFT", backdrop, "TOPLEFT", 9, -45)
    local backing = track.Background
    if backing then
        Look.Art(backing, "mapTrackBack")
        FullCrop(backing)
        backing:SetSize(25, 25)
        Look.Pin(backing, "TOPLEFT", track, "TOPLEFT", 2, -4)
        backing:SetAlpha(0.6)
    end
    GoldRing(track, "BORDER", 54)
    local lens = track.Button
    if not lens then return end
    Seat(lens, nil, above + 1, 32)
    Look.Pin(lens, "TOPLEFT", track, "TOPLEFT", 0, 0)
    Map.QuietHeader(lens)
    for _, face in ipairs(GLASS) do
        local glass = Look.StateArt(lens, face[1], "mapGlass")
        if glass then
            FullCrop(glass)
            glass:SetSize(20, 20)
            Look.Pin(glass, "TOPLEFT", track, "TOPLEFT", face[2], face[3])
        end
    end
    Face(lens, "Highlight", "mapZoomGlow", true)
end

---------------------------------------------------------------------------
-- Mail (and the crafting order indicator beside it)
---------------------------------------------------------------------------

function Map.LayMail(cluster, map, above)
    local signs = cluster.IndicatorFrame
    if not signs then return end
    Seat(signs, cluster, above, 33)
    Look.Pin(signs, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
    local post = signs.MailFrame
    if post then
        post:SetSize(33, 33)
        Look.Pin(post, "TOPRIGHT", map, "TOPRIGHT", 24, -37)
        GoldRing(post, "OVERLAY", 52)
        local letter = MiniMapMailIcon
        if letter then
            letter:SetTexture("Interface\\Icons\\INV_Letter_15")
            letter:SetSize(18, 18)
            Look.Pin(letter, "TOPLEFT", post, "TOPLEFT", 7, -6)
        end
    end
    local orders = signs.CraftingOrderFrame
    if orders then
        orders:SetSize(33, 33)
        Look.Pin(orders, "TOPLEFT", signs, "TOPLEFT", 0, 0)
    end
end

---------------------------------------------------------------------------
-- The calendar page
---------------------------------------------------------------------------

local CALENDAR_HIT = { 6, 0, 5, 10 }
-- The sheet's two pages: left, right, top, bottom.
local PAGE_UP, PAGE_DOWN = { 0, 0.390625, 0, 0.78125 }, { 0.5, 0.890625, 0, 0.78125 }

local function DayOfMonth()
    local dates = C_DateAndTime
    if not dates or type(dates.GetCurrentCalendarTime) ~= "function" then return nil end
    local fine, now = pcall(dates.GetCurrentCalendarTime)
    return fine and type(now) == "table" and Look.Number(now.monthDay) or nil
end

-- Today's date on the page, in the 1.x black font.
local function WriteDay(page)
    local digits = page:GetFontString()
    if not digits then
        page:SetNormalFontObject("GameFontBlack")
        digits = page:CreateFontString(nil, "OVERLAY", "GameFontBlack")
        page:SetFontString(digits)
    end
    digits:SetFontObject("GameFontBlack")
    Look.Pin(digits, "CENTER", page, "CENTER", -1, -1)
    digits:SetDrawLayer("OVERLAY")
    local today = DayOfMonth()
    if today then page:SetText(today) end
end

local function PageFace(page, state, crop)
    local face = Face(page, state, "mapCalendar")
    if not face then return nil end
    Look.Crop(face, crop[1], crop[2], crop[3], crop[4])
    face:SetDrawLayer("BACKGROUND")
    return face
end

-- The 1.x page from the calendar sheet, today's date on it, Forever's
-- header art and every other texture on the button (its invite and alarm
-- glows too, as the old look had it) faded. Again after the game sets the
-- date (loading screens, invites).
function Map.SkinCalendar()
    local page = GameTimeFrame
    if not Map.applied or not page then return end
    local keep = {}
    for _, face in pairs({ up = PageFace(page, "Normal", PAGE_UP), down = PageFace(page, "Pushed", PAGE_DOWN),
        glow = Face(page, "Highlight", "mapZoomGlow", true) }) do
        keep[face] = true
    end
    Map.QuietHeader(page)
    FadeOthers(page, keep)
    WriteDay(page)
end

function Map.LayCalendar(map, above)
    local page = GameTimeFrame
    if not page then return end
    Seat(page, map, above, 40)
    Look.Pin(page, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
    page:SetHitRectInsets(unpack(CALENDAR_HIT))
    Map.SkinCalendar()
end

---------------------------------------------------------------------------
-- Day and night (Forever), the clock, the event link
---------------------------------------------------------------------------

-- Forever sets day and night to one over the container's scale; with the
-- container at 1 here it goes back to 1 and takes the cluster's size with
-- the rest. Under the calendar. In Dark Mode its gold ring greys like the
-- stone ring (its moon or sun keeps its colours).
function Map.LayDiel(cluster, map)
    local cycle = cluster.DielFrame
    if not cycle then return end
    if Look.Number(cycle:GetScale()) ~= 1 then cycle:SetScale(1) end
    Look.Pin(cycle, "TOPRIGHT", map, "TOPRIGHT", 20, -2)
    local tint = ns.ThemeTexture
    if type(tint) ~= "function" then return end
    local skyArt = cycle.Background
    Look.EachRegion(cycle, function(piece)
        if piece ~= skyArt and piece:IsObjectType("Texture") then tint(piece, "dielBorder") end
    end)
end

-- The clock on its 1.x plate across the bottom of the map.
local PLATE_CROP = { 0.015625, 0.8125, 0.015625, 0.390625 }

function Map.LayClock(map, above)
    local timer = TimeManagerClockButton
    if not timer then return end
    Seat(timer, map, above, 60, 28)
    Look.Pin(timer, "CENTER", map, "CENTER", 0, -75)
    local plate = Look.OwnTexture(timer, "plate", "BORDER")
    FadeOthers(timer, { [plate] = true })
    Look.Art(plate, "mapClock")
    Look.Crop(plate, PLATE_CROP[1], PLATE_CROP[2], PLATE_CROP[3], PLATE_CROP[4])
    Look.Fill(plate, timer)
    plate:SetAlpha(1)
    local hands = TimeManagerClockTicker
    if hands then Look.Pin(hands, "CENTER", timer, "CENTER", 3, 1) end
end

-- Forever's event link (shown by the game only while it has one): on the
-- ring's upper left above tracking, or the square's left edge. Nothing else
-- of it changes.
function Map.LayEventLink(backdrop, map)
    local urlButton = backdrop.ExternalEventURLButton
    if urlButton == nil then return end
    local x, y = -62, 52
    if Map.worn then x, y = -78, 50 end
    Look.Pin(urlButton, "CENTER", map, "CENTER", x, y)
end
