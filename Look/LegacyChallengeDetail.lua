-- The Legacy window's Challenges page as EraUI draws it: the chosen
-- challenge's details under the list's rule (Look/LegacyChallengeList.lua),
-- drawn like the quest log's details from the top down on a sheet that
-- scrolls (the 1.x scroll bar, the mouse wheel):
--   * its icon in the spellbook's slot and ring, the points its card shows
--     on a talent rank plate under it, its name (gold once done, brown ink
--     before) and, once done, the date the game shows; the Track box at the
--     top right while the game's card would show one (tracked, or not done
--     yet), the game's own tracking calls behind it;
--   * its text, then each objective: the old check on a done one, its
--     words in brown ink (the quest log's grey while not done), a counted
--     one as the old skill bar with its count; its reward words last.
-- The details' part is tall enough for a usual challenge (text, one
-- objective, reward words) to show whole; a longer one scrolls.
-- The ink turns light while Dark Windows greys the page. Lines, checks and
-- bars are pooled and drawn afresh each time; every value comes through
-- Look/LegacyChallengeData.lua (one the game hides shows the last one read).
local _, EraUI = ...
local Look = EraUI.Look
local L = Look.Legacy
local C = L.ChallengeList
local D = L.ChallengeData

local lines, checks, meters = {}, {}, {}
local pen = { lines = 0, checks = 0, meters = 0, y = 0 }
local ICON, PLATE_W, PLATE_H, TRACK_W, METER_H = 32, 40, 32, 64, 12
local HEADER = { "face", "title", "date", "plate", "worth", "socket", "ring", "track" }

-- The first of the named font objects this client has.
local function Font(...)
    for i = 1, select("#", ...) do
        local font = _G[(select(i, ...))]
        if font ~= nil then return font end
    end
    return GameFontNormal
end

local function Height(words)
    local tall = Look.Number(words:GetStringHeight())
    if not tall or tall < 1 then return 12 end
    return tall
end

local function Piece(purpose)
    return Look.OwnPiece(C.sheet, "legacy." .. purpose)
end

---------------------------------------------------------------------------
-- The sheet and its pieces (made once, with the page)
---------------------------------------------------------------------------

function C.MakeDetail(holder, wide, tall)
    local scroller = Look.Build("ScrollFrame", holder, nil, { size = { wide, tall }, wheel = true })
    local sheet = Look.Build("Frame", scroller, nil, { size = { wide, tall } })
    scroller:SetScrollChild(sheet)
    local slider = Look.ClassicScrollBar(holder, scroller, function(value) scroller:SetVerticalScroll(value) end)
    Look.ScrollColumn(slider)
    L.KnobShows(slider:GetThumbTexture())
    scroller:SetScript("OnMouseWheel", function(_, notches)
        slider:SetValue((Look.Number(slider:GetValue()) or 0) - (Look.Number(notches) or 0) * 20)
    end)
    local picture = Look.OwnTexture(sheet, "legacy.face", "ARTWORK")
    picture:SetSize(ICON, ICON)
    picture:SetTexture(D.QUESTION)
    Look.Pin(picture, "TOPLEFT", sheet, "TOPLEFT", 6, -6)
    local title = Look.OwnLabel(sheet, "legacy.title", "GameFontNormalLarge", "ARTWORK")
    title:SetJustifyH("LEFT")
    Look.Pin(title, "TOPLEFT", sheet, "TOPLEFT", 6 + ICON + 8, -6)
    local date = Look.OwnLabel(sheet, "legacy.date", "GameFontHighlightSmall", "ARTWORK")
    date:SetJustifyH("LEFT")
    -- The points on the talent window's rank plate over the slot's foot.
    local plate = Look.OwnTexture(sheet, "legacy.plate", "ARTWORK", 2)
    Look.Art(plate, "legacyPlate")
    plate:SetSize(PLATE_W, PLATE_H)
    Look.Pin(plate, "CENTER", picture, "BOTTOM", 0, -6)
    local worth = Look.OwnLabel(sheet, "legacy.worth", "GameFontHighlight", "OVERLAY")
    Look.Pin(worth, "CENTER", plate, "CENTER", 0, 0)
    local tick = Look.Build("CheckButton", sheet, nil, { size = { 20, 20 }, mouse = true })
    Look.SkinCheckBox(tick)
    Look.Pin(tick, "TOPRIGHT", sheet, "TOPRIGHT", -4, -3)
    local said = Look.OwnLabel(sheet, "legacy.track", "GameFontNormalSmall", "ARTWORK")
    said:SetText(D.Say("TRACK_ACHIEVEMENT", "Track"))
    Look.Pin(said, "RIGHT", tick, "LEFT", -2, 0)
    tick:SetScript("OnClick", function() C.TrackClicked() end)
    C.detail, C.sheet, C.detailBar, C.tick = scroller, sheet, slider, tick
end

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------

-- The next pooled line at x, pen.y down, `wide` across.
local function Line(font, x, wide)
    pen.lines = pen.lines + 1
    local line = lines[pen.lines]
    if not line then
        line = C.sheet:CreateFontString(nil, "ARTWORK")
        line:SetJustifyH("LEFT")
        lines[pen.lines] = line
    end
    line:SetFontObject(font)
    line:SetWidth(wide)
    Look.Pin(line, "TOPLEFT", C.sheet, "TOPLEFT", x, -pen.y)
    line:Show()
    return line
end

-- Words in ink (faded: lighter), the pen moved past them and a gap.
local function Write(font, words, x, wide, gap, faded)
    local line = Line(font, x, wide)
    line:SetText(words)
    C.Colour(line, false, faded)
    pen.y = pen.y + Height(line) + (gap or 4)
    return line
end

local function Check(x, y)
    pen.checks = pen.checks + 1
    local tick = checks[pen.checks]
    if not tick then
        tick = C.sheet:CreateTexture(nil, "OVERLAY")
        Look.Art(tick, "legacyCheck")
        tick:SetSize(16, 16)
        checks[pen.checks] = tick
    end
    Look.Pin(tick, "TOPLEFT", C.sheet, "TOPLEFT", x, -y)
    tick:Show()
    return tick
end

-- The next pooled bar as the old skill bar, with its count on it.
local function Meter(x, wide)
    pen.meters = pen.meters + 1
    local meter = meters[pen.meters]
    if not meter then
        meter = Look.Build("StatusBar", C.sheet, nil, { size = { wide, METER_H } })
        meters[pen.meters] = meter
    end
    meter:SetSize(wide, METER_H)
    L.SkillBar(meter, L.GREEN_BAR)
    Look.Pin(meter, "TOPLEFT", C.sheet, "TOPLEFT", x, -(pen.y + 3))
    meter:Show()
    local count = Look.OwnLabel(meter, "legacy.count", "GameFontHighlightSmall", "OVERLAY")
    Look.Pin(count, "CENTER", meter, "CENTER", 0, 0)
    count:Show()
    pen.y = pen.y + METER_H + 11
    return meter, count
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------

-- The icon, plate, name, date and Track box; how far down they reach.
local function Header(entry, wide)
    local sheet = C.sheet
    local picture = Piece("face")
    picture:SetTexture(entry.icon or D.QUESTION)
    Look.Crop(picture, 0.08, 0.92, 0.08, 0.92)
    picture:SetDesaturated(false)
    Look.Shown(picture, true)
    L.Slot(sheet, picture, "BACKGROUND")
    local worth = (Look.Number(entry.worth) or 0) > 0
    Look.Shown(Piece("plate"), worth)
    local number = Piece("worth")
    Look.Shown(number, worth)
    if worth then number:SetText(tostring(entry.worth)) end
    local tracking = D.TrackShown(entry)
    Look.Shown(C.tick, tracking)
    Look.Shown(Piece("track"), tracking)
    if tracking then
        C.tick:SetChecked(D.Tracked(entry.id))
        C.Colour(Piece("track"), false)
    end
    local left = 6 + ICON + 8
    local title = Piece("title")
    title:SetFontObject(Font("QuestTitleFont", "GameFontNormalLarge"))
    title:SetWidth(wide - left - (tracking and TRACK_W or 6))
    title:SetText(entry.name)
    C.Colour(title, entry.done)
    Look.Shown(title, true)
    local y = 6 + Height(title)
    local date = Piece("date")
    Look.Shown(date, entry.date ~= nil)
    if entry.date then
        date:SetText(entry.date)
        C.Colour(date, false)
        Look.Pin(date, "TOPLEFT", sheet, "TOPLEFT", left, -(y + 2))
        y = y + 2 + Height(date)
    end
    -- Clear of the slot and the plate hanging under it.
    return math.max(y, 6 + ICON + PLATE_H / 2) + 8
end

-- Each objective: the old check on a done one, its words, a counted one's
-- bar with its count.
local function Objectives(id, wide)
    local small = Font("QuestFontNormalSmall", "GameFontHighlightSmall")
    for _, goal in ipairs(D.Objectives(id)) do
        if goal.done then Check(3, pen.y - 2) end
        if goal.text ~= "" or not goal.counted then
            Write(small, goal.text, 22, wide - 28, goal.counted and 0 or 3, not goal.done)
        end
        if goal.counted then
            local meter, count = Meter(24, wide - 40)
            meter:SetMinMaxValues(0, goal.required)
            meter:SetValue(math.min(goal.quantity, goal.required))
            count:SetText(string.format(D.Say("GENERIC_FRACTION_STRING_WITH_SPACING", "%d / %d"), goal.quantity, goal.required))
        end
    end
end

local function Draw(entry)
    local wide = C.DETAIL_W
    pen.y = Header(entry, wide)
    if entry.description ~= "" then
        Write(Font("QuestFont", "GameFontHighlight"), entry.description, 6, wide - 12, 8)
    end
    Objectives(entry.id, wide)
    if entry.reward ~= "" then
        pen.y = pen.y + 4
        Write(Font("QuestFontNormalSmall", "GameFontHighlightSmall"), entry.reward, 6, wide - 12, 4)
    end
end

-- Everything pooled put away, then the chosen challenge drawn (top: back to
-- the sheet's top; a newly chosen one always is) and the bar's range set
-- from how far it reaches.
function C.DrawDetail(top)
    local sheet = C.sheet
    if not sheet then return end
    for _, line in ipairs(lines) do line:Hide() end
    for _, tick in ipairs(checks) do tick:Hide() end
    for _, meter in ipairs(meters) do meter:Hide() end
    pen.lines, pen.checks, pen.meters, pen.y = 0, 0, 0, 0
    local id = C.sel
    local entry = id and (D.Info(id) or D.Known(id)) or nil
    local tall = C.DETAIL_H
    if not entry then
        for _, purpose in ipairs(HEADER) do Look.Shown(Piece(purpose), false) end
        Look.Shown(C.tick, false)
        C.drawn = nil
        sheet:SetHeight(tall)
        Look.ScrollRange(C.detailBar, 0, 20)
        return
    end
    if top or C.drawn ~= id then
        C.drawn = id
        C.detailBar:SetValue(0)
    end
    Look.Try(Draw, entry)
    local used = math.max(tall, pen.y + 6)
    sheet:SetHeight(used)
    Look.ScrollRange(C.detailBar, used - tall, 20)
end

-- The Track box: the game's own tracking call, then drawn again from what
-- the game says now.
function C.TrackClicked()
    local id = C.sel
    if id then
        local on = D.ToggleTrack(id)
        C.Sound(on and "IG_MAINMENU_OPTION_CHECKBOX_ON" or "IG_MAINMENU_OPTION_CHECKBOX_OFF")
    end
    C.DrawDetail()
end
