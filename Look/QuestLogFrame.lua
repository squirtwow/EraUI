-- The classic quest log window itself (registry "questLog"): EraUI's own
-- frame EraUIClassicQuestLog, built the first time it is opened, never at
-- login. Two layouts, switched by questLogDual:
--   * single pane, the 1.x log (384 x 512): the four-piece art with the
--     book, the title, the red X, the quest count box, the All tab, the
--     Track Quest and Double pane radios, a six-row list over the
--     parchment detail, and Abandon Quest, Share Quest and Exit;
--   * double pane, the wider 3.x log (680 x 440): the list (21 rows) on
--     the left, the quest on the right, the count box and the Double pane
--     radio at the top, Show Map at the top right, and Abandon, Share,
--     Track and Close along the foot.
-- Every piece is EraUI's own; what the window keeps lives on Look.Quest.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Q = Look.Quest
local parts = Q.parts

local SINGLE_ART = { { "questLogTopLeft", 256, 256, "TOPLEFT" }, { "questLogTopRight", 128, 256, "TOPRIGHT" },
    { "questLogBotLeft", 256, 256, "BOTTOMLEFT" }, { "questLogBotRight", 128, 256, "BOTTOMRIGHT" } }
-- The 3.x art overhangs the 680 x 440 window on purpose.
local DOUBLE_ART = { { "questLogDualLeft", 512, 512, 0 }, { "questLogDualRight", 256, 512, 512 } }
-- The empty log's 320 x 384 block: key, size, its top-left in the block.
local EMPTY_ART = { { "questLogEmptyTopLeft", 256, 256, 0, 0 }, { "questLogEmptyTopRight", 64, 256, 256, 0 },
    { "questLogEmptyBotLeft", 256, 128, 0, 256 }, { "questLogEmptyBotRight", 64, 128, 256, 256 } }

---------------------------------------------------------------------------
-- The shell: art, book, title, X
---------------------------------------------------------------------------

local function Shell(window)
    parts.single, parts.double = {}, {}
    for i, piece in ipairs(SINGLE_ART) do
        local sheet = Look.OwnTexture(window, "single" .. i, "BACKGROUND")
        Look.Art(sheet, piece[1])
        sheet:SetSize(piece[2], piece[3])
        Look.Pin(sheet, piece[4], window, piece[4], 0, 0)
        parts.single[i] = sheet
    end
    for i, piece in ipairs(DOUBLE_ART) do
        local sheet = Look.OwnTexture(window, "double" .. i, "BACKGROUND")
        Look.Art(sheet, piece[1])
        sheet:SetSize(piece[2], piece[3])
        Look.Pin(sheet, "TOPLEFT", window, "TOPLEFT", piece[4], 0)
        parts.double[i] = sheet
    end
    parts.book = Look.OwnTexture(window, "book", "ARTWORK")
    Look.Art(parts.book, "questLogBook")
    parts.book:SetSize(64, 64)
    parts.title = Look.OwnLabel(window, "title", "GameFontHighlight", "OVERLAY")
    parts.title:SetText(Q.Say("QUEST_LOG", "Quest Log"))
    local shut = Look.Build("Button", window, nil, { size = { 32, 32 } })
    Look.SkinCloseButton(shut)
    shut:SetScript("OnClick", function() Q.Hide() end)
    parts.close = shut
end

---------------------------------------------------------------------------
-- The quest count box ("Quests: 7/20"), growing leftwards from its cap
---------------------------------------------------------------------------

local function CountBox(window)
    local slices = {}
    for i, cut in ipairs({ { 0, 1 / 16 }, { 1 / 16, 15 / 16 }, { 15 / 16, 1 } }) do
        local slice = Look.OwnTexture(window, "count" .. i, "ARTWORK")
        slice:SetTexture(Q.FILES.inputBorder)
        Look.Crop(slice, cut[1], cut[2], 0, 0.625)
        slice:SetSize(i == 2 and 20 or 8, 20)
        slices[i] = slice
    end
    Look.Pin(slices[2], "RIGHT", slices[3], "LEFT", 0, 0)
    Look.Pin(slices[1], "RIGHT", slices[2], "LEFT", 0, 0)
    local words = Look.OwnLabel(window, "count", "GameFontNormalSmall", "OVERLAY")
    words:SetTextColor(Q.Yellow())
    Look.Pin(words, "RIGHT", slices[3], "RIGHT", -6, 0)
    parts.countCap, parts.countMiddle, parts.countText = slices[3], slices[2], words
end

function Q.FillCount()
    local have, most = Q.QuestCount()
    local words = parts.countText
    words:SetText(Q.Say("QUESTS", "Quests") .. ": " .. have .. "/" .. most)
    parts.countMiddle:SetWidth(math.max(20, Look.Number(words:GetStringWidth()) or 20))
end

---------------------------------------------------------------------------
-- The All tab and the two radios
---------------------------------------------------------------------------

local function AllTab(window)
    local holder = Look.Build("Frame", window, nil, { size = { 54, 32 } })
    local tab = Look.Build("Button", holder, nil, { size = { 40, 22 } })
    Look.Pin(tab, "TOPLEFT", holder, "TOPLEFT", 0, -2)
    -- The sort tab's three pieces in a row behind it, from 6 left and 8 above.
    local before
    for _, part in ipairs({ { "Left", 8 }, { "Middle", 38 }, { "Right", 8 } }) do
        local piece = Look.OwnTexture(holder, "tab" .. part[1], "BACKGROUND")
        Look.Art(piece, "questLogTab" .. part[1])
        piece:SetSize(part[2], 32)
        if before then
            Look.Pin(piece, "LEFT", before, "RIGHT", 0, 0)
        else
            Look.Pin(piece, "TOPLEFT", tab, "TOPLEFT", -6, 8)
        end
        before = piece
    end
    local icon = Look.OwnTexture(tab, "icon", "ARTWORK")
    icon:SetSize(16, 16)
    Look.Pin(icon, "LEFT", tab, "LEFT", 3, 0)
    icon:SetTexture(Q.FILES.minus)
    local glow = Look.OwnTexture(tab, "glow", "HIGHLIGHT")
    glow:SetTexture(Q.FILES.plusGlow)
    glow:SetBlendMode("ADD")
    Look.Fill(glow, icon)
    local label = Look.OwnLabel(tab, "label", "GameFontNormal", "ARTWORK")
    label:SetTextColor(Q.Yellow())
    Look.Pin(label, "LEFT", tab, "LEFT", 20, 0)
    label:SetText(Q.Say("ALL", "All"))
    tab:SetScript("OnClick", function() Q.AllTabClicked() end)
    parts.allHolder, parts.allTab, parts.allIcon = holder, tab, icon
end

-- A 1.x radio: the four-state sheet (rest, checked, hover) and its words.
local function Radio(window, words)
    local radio = Look.Build("CheckButton", window, nil, { size = { 20, 20 } })
    radio:SetNormalTexture(Q.FILES.radio)
    radio:SetCheckedTexture(Q.FILES.radio)
    radio:SetHighlightTexture(Q.FILES.radio)
    Look.Crop(radio:GetNormalTexture(), 0, 0.25, 0, 1)
    Look.Crop(radio:GetCheckedTexture(), 0.25, 0.5, 0, 1)
    local hover = radio:GetHighlightTexture()
    Look.Crop(hover, 0.5, 0.75, 0, 1)
    hover:SetBlendMode("ADD")
    local label = Look.OwnLabel(radio, "words", "GameFontHighlightSmall", "ARTWORK")
    Look.Pin(label, "LEFT", radio, "RIGHT", 1, 0)
    label:SetText(words)
    return radio
end

local function Radios(window)
    parts.trackRadio = Radio(window, Q.Say("TRACK_QUEST", "Track Quest"))
    parts.trackRadio:SetScript("OnClick", function(radio) Q.TrackRadioClicked(radio) end)
    parts.dualRadio = Radio(window, "Double pane")
    parts.dualRadio:SetScript("OnClick", function(radio) Q.DualRadioClicked(radio) end)
end

---------------------------------------------------------------------------
-- Show Map (double pane): its own refusal in a fight; out of one, the
-- shared secure pad over it opens the map through the game's own path
---------------------------------------------------------------------------

local function ShowMapButton(window)
    local button = Look.Build("Button", window, nil, { size = { 110, 24 } })
    local icon = Look.OwnTexture(button, "icon", "ARTWORK")
    icon:SetTexture(Q.FILES.mapButton)
    Look.Crop(icon, 0.125, 0.875, 0, 0.5)
    icon:SetSize(36, 24)
    Look.Pin(icon, "RIGHT", button, "RIGHT", 0, 0)
    local label = Look.OwnLabel(button, "label", "GameFontNormal", "ARTWORK")
    label:SetTextColor(Q.Yellow())
    Look.Pin(label, "RIGHT", icon, "LEFT", -2, 0)
    label:SetText(Q.Say("SHOW_MAP", "Show Map"))
    local glow = Look.OwnTexture(button, "glow", "HIGHLIGHT")
    glow:SetTexture(Q.FILES.squareGlow)
    glow:SetBlendMode("ADD")
    Look.Fill(glow, icon)
    button:SetScript("OnClick", function() Q.ShowMapClicked() end)
    if type(ns.MapPad) == "function" then ns.MapPad(button, "DIALOG", function() Q.Hide() end) end
    parts.showMap = button
end

---------------------------------------------------------------------------
-- The list area, the detail pane and their 1.x scroll bars
---------------------------------------------------------------------------

local function Panes(window)
    local list = Look.Build("Frame", window, nil, { size = { 300, 93 }, wheel = true })
    list:SetClipsChildren(true)
    local detail = Look.Build("ScrollFrame", window, nil, { size = { 300, 260 }, wheel = true })
    local page = Look.Build("Frame", detail, nil, { size = { 300, 260 } })
    detail:SetScrollChild(page)
    parts.list, parts.detail, parts.page = list, detail, page
    parts.listBar = Look.ClassicScrollBar(window, list, function() Q.ListMoved() end)
    parts.detailBar = Look.ClassicScrollBar(window, detail, function(value) detail:SetVerticalScroll(value) end)
    list:SetScript("OnMouseWheel", function(_, notches)
        local bar = parts.listBar
        bar:SetValue((Look.Number(bar:GetValue()) or 0) - (Look.Number(notches) or 0))
    end)
    detail:SetScript("OnMouseWheel", function(_, notches)
        local bar = parts.detailBar
        bar:SetValue((Look.Number(bar:GetValue()) or 0) - (Look.Number(notches) or 0) * 20)
    end)
end

---------------------------------------------------------------------------
-- The foot: the red panel buttons
---------------------------------------------------------------------------

local function Foot(window)
    parts.abandon = Look.PanelButton(window, Q.Say("ABANDON_QUEST", "Abandon Quest"), 125)
    parts.share = Look.PanelButton(window, Q.Say("SHARE_QUEST", "Share Quest"), 123)
    parts.track = Look.PanelButton(window, Q.Say("TRACK_QUEST_ABBREV", "Track"), 104)
    parts.exit = Look.PanelButton(window, Q.Say("EXIT", "Exit"), 77)
    parts.abandon:SetScript("OnClick", function() Q.Abandon() end)
    parts.share:SetScript("OnClick", function() Q.Share() end)
    parts.track:SetScript("OnClick", function() Q.TrackClicked() end)
    parts.exit:SetScript("OnClick", function() Q.Hide() end)
end

---------------------------------------------------------------------------
-- The empty log: the 1.x art and the game's "You have no quests" words
---------------------------------------------------------------------------

local function EmptyPane(window)
    local pane = Look.Build("Frame", window, nil, { size = { 384, 512 }, hidden = true })
    Look.Pin(pane, "TOPLEFT", window, "TOPLEFT", 19, -73)
    parts.emptyArt = {}
    for i, piece in ipairs(EMPTY_ART) do
        local sheet = Look.OwnTexture(pane, "empty" .. i, "BACKGROUND")
        Look.Art(sheet, piece[1])
        sheet:SetSize(piece[2], piece[3])
        Look.Pin(sheet, "TOPLEFT", pane, "TOPLEFT", piece[4], -piece[5])
        parts.emptyArt[i] = sheet
    end
    local words = Look.OwnLabel(pane, "words", "GameFontHighlight", "ARTWORK")
    words:SetWidth(200)
    words:SetText(Q.Say("QUESTLOG_NO_QUESTS_TEXT",
        "You have no quests. Look for exclamation marks over the heads of characters to find quests."))
    parts.empty, parts.emptyText = pane, words
end

---------------------------------------------------------------------------
-- The two layouts
---------------------------------------------------------------------------

-- Each layout's numbers: frame size, book, title drop, the list and detail
-- (left, top, width, height), each bar's gap right of its area and its
-- top and bottom insets, the rows shown.
local LAYOUT = {
    [false] = { size = { 384, 512 }, book = 4, title = 17, list = { 19, 75, 300, 93 }, detail = { 19, 175, 300, 260 },
        listBar = { 7, 16, 16 }, detailBar = { 7, 16, 16 }, rows = 6 },
    [true] = { size = { 680, 440 }, book = 6, title = 19, list = { 20, 76, 296, 332 }, detail = { 352, 80, 292, 328 },
        listBar = { 10, 14, 14 }, detailBar = { 12, 10, 14 }, rows = 21 },
}

local function Area(region, window, spot)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", window, "TOPLEFT", spot[1], -spot[2])
    region:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", spot[1] + spot[3], -(spot[2] + spot[4]))
    region:SetSize(spot[3], spot[4])
end

local function BarBeside(bar, area, gaps)
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", area, "TOPRIGHT", gaps[1], -gaps[2])
    bar:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", gaps[1], gaps[3])
end

local function Button(button, text, width)
    button:SetText(text)
    button:SetWidth(width)
end

-- The pieces only one layout has, and the foot's buttons.
local function SingleFoot(window)
    Button(parts.abandon, Q.Say("ABANDON_QUEST", "Abandon Quest"), 125)
    Button(parts.share, Q.Say("SHARE_QUEST", "Share Quest"), 123)
    Button(parts.exit, Q.Say("EXIT", "Exit"), 77)
    Look.Pin(parts.abandon, "BOTTOMLEFT", window, "BOTTOMLEFT", 17, 54)
    Look.Pin(parts.exit, "BOTTOMRIGHT", window, "BOTTOMRIGHT", -43, 54)
    Look.Pin(parts.share, "RIGHT", parts.exit, "LEFT", 0, 0)
end

local function DoubleFoot(window)
    Button(parts.abandon, Q.Say("ABANDON_QUEST_ABBREV", "Abandon"), 104)
    Button(parts.share, Q.Say("SHARE_QUEST_ABBREV", "Share"), 104)
    Button(parts.track, Q.Say("TRACK_QUEST_ABBREV", "Track"), 104)
    Button(parts.exit, Q.Say("CLOSE", "Close"), 80)
    Look.Pin(parts.abandon, "BOTTOMLEFT", window, "BOTTOMLEFT", 16, 8)
    Look.Pin(parts.share, "LEFT", parts.abandon, "RIGHT", -4, 0)
    Look.Pin(parts.track, "LEFT", parts.share, "RIGHT", 2, 0)
    Look.Pin(parts.exit, "BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8)
end

local function SingleTop(window)
    Look.Pin(parts.close, "TOPRIGHT", window, "TOPRIGHT", -30, -8)
    Look.Pin(parts.countCap, "TOPRIGHT", window, "TOPRIGHT", -47, -41)
    Look.Pin(parts.allHolder, "TOPLEFT", window, "TOPLEFT", 70, -48)
    Look.Pin(parts.trackRadio, "LEFT", parts.allHolder, "RIGHT", 5, 17)
    Look.Pin(parts.dualRadio, "LEFT", parts.allHolder, "RIGHT", 5, 0)
    Look.Pin(parts.emptyText, "TOP", window, "TOP", -20, -105)
end

local function DoubleTop(window)
    Look.Pin(parts.close, "TOPRIGHT", window, "TOPRIGHT", 3, -8)
    Look.Pin(parts.countCap, "TOPLEFT", window, "TOPLEFT", 190, -40)
    Look.Pin(parts.dualRadio, "LEFT", parts.countCap, "RIGHT", 8, 0)
    Look.Pin(parts.showMap, "TOPRIGHT", window, "TOPRIGHT", -36, -40)
    Look.Pin(parts.emptyText, "TOP", parts.list, "TOP", 0, -30)
end

-- The window in one layout or the other (every value of the other undone).
function Q.Lay(double)
    local window = Q.window
    if not window then return end
    double = double and true or false
    Q.double = double
    local shape = LAYOUT[double]
    window:SetSize(shape.size[1], shape.size[2])
    for _, sheet in ipairs(parts.single) do Look.Shown(sheet, not double) end
    for _, sheet in ipairs(parts.double) do Look.Shown(sheet, double) end
    for _, sheet in ipairs(parts.emptyArt) do Look.Shown(sheet, not double) end
    Look.Pin(parts.book, "TOPLEFT", window, "TOPLEFT", shape.book, -shape.book)
    Look.Pin(parts.title, "TOP", window, "TOP", 0, -shape.title)
    Area(parts.list, window, shape.list)
    Area(parts.detail, window, shape.detail)
    parts.page:SetWidth(shape.detail[3])
    BarBeside(parts.listBar, parts.list, shape.listBar)
    BarBeside(parts.detailBar, parts.detail, shape.detailBar)
    Q.rowsShown = shape.rows
    for _, row in ipairs(Q.rows) do row:SetWidth(shape.list[3]) end
    if double then DoubleTop(window) else SingleTop(window) end
    if double then DoubleFoot(window) else SingleFoot(window) end
    Look.Shown(parts.allHolder, not double)
    Look.Shown(parts.trackRadio, not double)
    Look.Shown(parts.showMap, double)
    Look.Shown(parts.track, double)
end

---------------------------------------------------------------------------
-- Building it (the first time it is opened)
---------------------------------------------------------------------------

function Q.Build()
    if Q.window then return Q.window end
    local window = Look.Build("Frame", UIParent, nil, { name = "EraUIClassicQuestLog", size = { 384, 512 },
        strata = "HIGH", movable = true, clamped = true, mouse = true, drag = "LeftButton", hidden = true })
    window:SetToplevel(true)
    Q.window = window
    Shell(window)
    CountBox(window)
    AllTab(window)
    Radios(window)
    ShowMapButton(window)
    Panes(window)
    Foot(window)
    EmptyPane(window)
    Q.MakeRows(parts.list)
    Q.MakeDetail(parts.page)
    Q.Lay(Look.Saved().questLogDual == true)
    Q.Wire(window)
    return window
end
