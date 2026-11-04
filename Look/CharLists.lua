-- The character window's list tabs (Classic look, "characterSheet"):
-- Reputation, Skills, Currency and Statistics put in the 1.x list area with
-- the old scroll column, 20-unit rows, the 1.x skill and reputation bars,
-- plus and minus headers; the Reputation column labels; the PvP panel moved
-- into the window's upper area.
--
-- Blizzard's rows are about 33 tall. The Skills and Reputation boxes are
-- shrunk so their rows come out about 20 tall, as in 1.x, and each row's
-- content is scaled back up, so text and bars keep their normal size.
-- The game still handles every click, expand and collapse.
local _, EraUI = ...
local Look = EraUI.Look
local C = Look.Char

local SKILL_SCALE, REP_SCALE = 20 / 33, 0.76
C.LISTS = {
    { name = "SkillsFrame", kind = "skills", scale = SKILL_SCALE, foot = 224 },
    { name = "ReputationFrame", kind = "reputation", scale = REP_SCALE, foot = 86 },
    { name = "TokenFrame", foot = 86 },
    { name = "StatisticsFrame", foot = 86 },
}
local BAR_LOOK = {
    skills = { inset = 0, coords = { 0, 1, 0, 0.5 }, fillHeight = 15, header = "GameFontHighlight" },
    reputation = { inset = 2, coords = { 0, 1, 0, 1 }, fillHeight = 11, header = "GameFontNormal" },
}

local dressedFor = Look.Weak()   -- row: the element data it was last dressed for
local barHooked = Look.Weak()    -- game bar: true once its post-hooks are in
local covers = Look.Weak()       -- header row: EraUI's frame over it
local listsSet = Look.Weak()     -- list frame: true once its poll and hooks are in
local repClickHooked = Look.Weak()

---------------------------------------------------------------------------
-- Bars
---------------------------------------------------------------------------

-- A region stretched across another: its ends at the owner's ends shifted by
-- the given amounts, centred on it, `tall` high.
local function Across(region, owner, leftShift, rightShift, tall)
    region:ClearAllPoints()
    for edge, shift in pairs({ LEFT = leftShift, RIGHT = rightShift }) do region:SetPoint(edge, owner, edge, shift, 0) end
    region:SetHeight(tall)
end

local function PaintFill(bar)
    local dressed, fill = C.fills[bar], bar.Fill
    if not dressed or not fill then return end
    Look.Art(fill, "skillsBar")
    local crop = dressed.coords
    Look.Crop(fill, crop[1], crop[2], crop[3], crop[4])
    fill:SetHeight(dressed.height)
    if dressed.kind == "skills" then fill:SetVertexColor(0, 0, 0.5) end
end

-- " / " in the rank becomes "/" ("121 / 150" reads "121/150").
local function TightRank(bar)
    local text = bar.Text
    local words = text and text:GetText()
    if type(words) ~= "string" or Look.Secret(words) or not words:find(" / ", 1, true) then return end
    text:SetText((words:gsub(" / ", "/")))
end

local function Repaint(bar)
    PaintFill(bar)
    C.FitFill(bar)
end

local function Blue(bar)
    if bar.Fill then bar.Fill:SetVertexColor(0, 0, 0.5) end
end

-- The bar kept in 1.x art after the game's own updates. Each runs inside the
-- game's row set-up, so a problem goes to the error handler instead.
local function KeepBar(bar, kind)
    if barHooked[bar] then return end
    barHooked[bar] = true
    local function After(fn) return function() if C.active then Look.Try(fn, bar) end end end
    Look.Hook(bar, "SetFillTextureByColorType", After(Repaint))
    Look.HookScript(bar, "OnSizeChanged", After(C.FitFill))
    if kind == "skills" then
        Look.Hook(bar, "UpdateBarColor", After(Blue))
        Look.Hook(bar, "SetText", After(TightRank))
    end
end

local function FadeRowBits(content)
    Look.EachRegion(content.BackgroundHighlight, Look.Fade)
    Look.Fade(content.AccountWideIcon)
end

-- A skill or reputation bar in 1.x art: the dark blue (or standing-coloured)
-- fill drawn as the bar's share, EraUI's name beside it, its border or plate.
function C.DressBar(bar, kind, nameText)
    local look = BAR_LOOK[kind]
    C.FadeAtlas(bar, "stat-bar-bg")
    C.fills[bar] = { inset = look.inset, coords = look.coords, kind = kind, height = look.fillHeight }
    local fill = bar.Fill
    if fill then
        if bar.Mask then pcall(fill.RemoveMaskTexture, fill, bar.Mask) end
        fill:SetDrawLayer("BACKGROUND", 0)
        PaintFill(bar)
        Look.Pin(fill, "LEFT", bar, "LEFT", kind == "reputation" and 1 or 0, 0)
    end
    local name = Look.OwnLabel(bar, "name", kind == "skills" and "GameFontNormalSmall" or "GameFontHighlightSmall", "OVERLAY")
    name:SetText(nameText or "")
    name:SetJustifyH("LEFT")
    if name.SetWordWrap then name:SetWordWrap(false) end
    if kind == "skills" then
        Look.Pin(name, "LEFT", bar, "LEFT", 6, 1)
        local border = Look.OwnTexture(bar, "border", "BORDER")
        Look.Art(border, "skillsBarBorder")
        Look.Crop(border, 0, 1, 0, 1)
        Across(border, bar, -5, 5, 32)
        local rank = bar.Text
        if rank then
            rank:SetFontObject(GameFontHighlightSmall)
            Look.Pin(rank, "LEFT", name, "RIGHT", 10, -1)
            rank:SetWidth(128)
            rank:SetJustifyH("LEFT")
            TightRank(bar)
        end
    else
        name:SetWidth(104)
        Look.Pin(name, "LEFT", bar, "LEFT", -119, 0)
        if bar.Text then bar.Text:SetFontObject(GameFontHighlightSmall) end
        local plate = Look.OwnTexture(bar, "plate", "BORDER")
        Look.Art(plate, "repPlate")
        plate:SetSize(256, 21)
        Look.Crop(plate, 0, 1, 0, 0.328125)
        Look.Pin(plate, "TOPLEFT", bar, "TOPLEFT", -126, 4)
        local cap = Look.OwnTexture(bar, "plateCap", "BORDER")
        Look.Art(cap, "repPlate")
        cap:SetSize(16, 21)
        Look.Crop(cap, 0, 0.0625, 0.34375, 0.671875)
        Look.Pin(cap, "TOPLEFT", plate, "TOPRIGHT", 0, 0)
    end
    KeepBar(bar, kind)
    C.FitFill(bar)
end

local function DressToggle(row, kind, bar)
    local toggle = row.ToggleCollapseButton
    if not toggle then return end
    local up = kind == "skills" and 33 / 20 or 1 / REP_SCALE
    if toggle:GetParent() == row then toggle:SetScale(up) end
    toggle:SetSize(16, 16)
    Look.Pin(toggle, "RIGHT", bar, "LEFT", kind == "skills" and -2 or -122, 0)
    for state, file in pairs({ Normal = "UI-PlusButton-Up", Pushed = "UI-PlusButton-Down" }) do
        local give, read = toggle["Set" .. state .. "Texture"], toggle["Get" .. state .. "Texture"]
        if type(give) == "function" then
            give(toggle, C.BUTTONS .. file)
            local face = read(toggle)
            if face then
                face:SetTexture(C.BUTTONS .. file)
                Look.Crop(face, 0, 1, 0, 1)
                Look.Fill(face, toggle)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function RepClicked(clicked)
    if C.active and C.RepRowClicked then C.RepRowClicked(clicked) end
end

-- An entry: its content drawn back at normal size, the game's bar in 1.x art
-- (a skill's across the row, a faction's 137 x 13 from 130 in), EraUI's name
-- on it. A faction's row also opens the 1.x detail box when clicked.
local ENTRY_BAR = { skills = "SkillsBar", reputation = "ReputationBar" }
local function DressEntry(row, kind)
    local inside = row.Content
    inside:SetScale(kind == "skills" and 33 / 20 or 1 / REP_SCALE)
    if kind == "reputation" and not repClickHooked[row] then
        repClickHooked[row] = true
        Look.HookScript(row, "OnClick", RepClicked)
    end
    local bar = inside[ENTRY_BAR[kind]]
    if bar == nil then return end
    FadeRowBits(inside)
    if kind == "skills" then
        Across(bar, row, 20, -8, 15)
    else
        bar:SetSize(137, 13)
        Look.Pin(bar, "LEFT", row, "LEFT", 130, 0)
    end
    C.DressBar(bar, kind, inside.Name and inside.Name:GetText())
    Look.Fade(inside.Name)
    DressToggle(row, kind, bar)
end

local function CollapseIcon(texture, row)
    local asked, collapsed = Look.Ask(row, "IsCollapsed")
    texture:SetTexture(C.BUTTONS .. ((asked and collapsed) and "UI-PlusButton-Up" or "UI-MinusButton-Up"))
    texture:SetSize(16, 16)
end

local function FadeHeaderArt(row)
    C.FadeAtlas(row, "collapseexpand")
    Look.Fade(row.StateIcon)
end

-- Skills and Reputation headers: EraUI's name and plus or minus on a frame
-- over the row, drawn at normal size.
local function DressListHeader(row, kind)
    FadeHeaderArt(row)
    local cover = covers[row]
    if not cover then
        cover = Look.Build("Frame", row, nil, { size = { 1, 1 } })
        Look.Fill(cover, row)
        covers[row] = cover
    end
    cover:SetScale(kind == "skills" and 33 / 20 or 1 / REP_SCALE)
    local name = Look.OwnLabel(cover, "name", BAR_LOOK[kind].header, "OVERLAY")
    name:SetFontObject(kind == "skills" and GameFontHighlight or GameFontNormal)
    name:SetText(row.Name and row.Name:GetText() or "")
    Look.Pin(name, "LEFT", cover, "LEFT", 26, 0)
    Look.Fade(row.Name)
    local icon = Look.OwnTexture(cover, "icon", "ARTWORK")
    CollapseIcon(icon, row)
    Look.Pin(icon, "LEFT", cover, "LEFT", 7, 0)
end

-- Currency and Statistics headers: the game's name moved and re-fonted,
-- EraUI's plus or minus beside it (their entries are left alone).
local function DressPlainHeader(row)
    FadeHeaderArt(row)
    local name = row.Name
    if name then
        name:SetFontObject(GameFontNormal)
        Look.Pin(name, "LEFT", row, "LEFT", 26, 0)
    end
    local icon = Look.OwnTexture(row, "icon", "ARTWORK")
    CollapseIcon(icon, row)
    Look.Pin(icon, "LEFT", row, "LEFT", 7, 0)
end

local function DressRow(spec, row)
    local data = C.RowData(row)
    if not data then return end
    dressedFor[row] = data
    if row.Content then
        if spec.kind then DressEntry(row, spec.kind) end
    elseif spec.kind then
        DressListHeader(row, spec.kind)
    else
        DressPlainHeader(row)
    end
end

function C.DressRows(spec, list, onlyChanged)
    if not C.active then return end
    C.EachRow(list.ScrollBox, function(row)
        if onlyChanged and dressedFor[row] == C.RowData(row) then return end
        Look.Try(DressRow, spec, row)
    end)
end

---------------------------------------------------------------------------
-- The character scroll column (the lists' scroll bars)
---------------------------------------------------------------------------

local function FitColumnTop(bar, top)
    local height = Look.Clamp((Look.Number(bar:GetHeight()) or 0) + 17 - 108, 1, 256)
    top:SetHeight(height)
    Look.Crop(top, 0, 0.484375, 0, height / 256)
end

function C.ScrollColumn(bar)
    if not Look.ClaimScrollBar(bar) then return end
    local top = Look.OwnTexture(bar, "columnTop", "BACKGROUND", 0)
    Look.Art(top, "charScrollBar")
    top:SetWidth(31)
    Look.Pin(top, "TOPLEFT", bar, "TOPLEFT", -8, 9)
    FitColumnTop(bar, top)
    Look.HookScript(bar, "OnSizeChanged", function() FitColumnTop(bar, top) end)
    local bottom = Look.OwnTexture(bar, "columnBottom", "BACKGROUND", 1)
    Look.Art(bottom, "charScrollBar")
    bottom:SetSize(31, 108)
    Look.Crop(bottom, 0.515625, 1, 0, 0.421875)
    Look.Pin(bottom, "BOTTOMLEFT", bar, "BOTTOMLEFT", -8, -8)
    local track = bar.Track
    if track then
        Look.Fade(track.Begin)
        Look.Fade(track.Middle)
        Look.Fade(track.End)
        if track.Thumb then track.Thumb:SetWidth(16) end
    end
    Look.Knob(bar, 7)
    for _, pair in ipairs({ { bar.Back, "scrollUpButtonUp", "TOP", 4 }, { bar.Forward, "scrollDownButtonUp", "BOTTOM", -4 } }) do
        local arrow = pair[1]
        if arrow then
            arrow:SetSize(16, 16)
            local face = Look.OwnPiece(arrow, "arrowArt")
            for _, state in ipairs(Look.Words("Normal Pushed Disabled Highlight")) do
                local read = arrow["Get" .. state .. "Texture"]
                Look.Fade(type(read) == "function" and read(arrow) or nil)
            end
            Look.EachRegion(arrow, function(piece) if piece ~= face then Look.Fade(piece) end end)
            face = face or Look.OwnTexture(arrow, "arrowArt", "ARTWORK")
            Look.Art(face, pair[2])
            Look.Crop(face, 0.25, 0.75, 0.25, 0.75)
            Look.Fill(face, arrow)
            face:SetAlpha(1)
            Look.Pin(arrow, pair[3], bar, pair[3], 3, pair[4])
        end
    end
end

---------------------------------------------------------------------------
-- The lists
---------------------------------------------------------------------------

local function PlaceBox(spec, list, sheet)
    local box = list.ScrollBox
    if not box then return end
    local scale = spec.scale or 1
    if spec.scale then box:SetScale(scale) end
    box:ClearAllPoints()
    box:SetPoint("TOPLEFT", sheet, "TOPLEFT", 12 / scale, -76 / scale)
    box:SetPoint("BOTTOMRIGHT", sheet, "BOTTOMRIGHT", -66 / scale, spec.foot / scale)
    for _, child in ipairs({ box:GetChildren() }) do
        if child ~= box.ScrollTarget then C.FadeAtlas(child, "scrollline") end
    end
    local bar = list.ScrollBar
    if bar then
        C.ScrollColumn(bar)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, -4)
        bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 4)
    end
end

local function RepLabels(list, sheet)
    for _, label in ipairs({ { "faction", "FACTION", "Faction", 86 }, { "standing", "STANDING", "Standing", 215 } }) do
        local text = Look.OwnLabel(list, label[1], "GameFontHighlight", "ARTWORK")
        text:SetText(C.Text(label[2], label[3]))
        Look.Pin(text, "TOPLEFT", sheet, "TOPLEFT", label[4], -59)
        text:Show()
    end
end

function C.ShowRepLabels(on)
    local list = ReputationFrame
    if not list then return end
    for _, purpose in ipairs({ "faction", "standing" }) do Look.Shown(Look.OwnPiece(list, purpose), on) end
end

-- Once per list, even before the window is first on: a poll that re-dresses
-- rows the game refilled while scrolling, and a post-hook on its Update.
local function SetUpList(spec, list)
    if listsSet[list] then return end
    listsSet[list] = true
    C.Poll(list, 0.05, function() C.DressRows(spec, list, true) end)
    if type(list.Update) == "function" and list.ScrollBox and type(list.ScrollBox.ForEachFrame) == "function" then
        Look.Hook(list, "Update", function() C.DressRows(spec, list, false) end)
    end
    Look.HookScript(list, "OnShow", function() if C.active then Look.Try(C.SkinList, spec) end end)
end

function C.SkinList(spec)
    local list, sheet = _G[spec.name], CharacterFrame
    if not list or not sheet then return end
    SetUpList(spec, list)
    if not C.active then return end
    PlaceBox(spec, list, sheet)
    C.DressRows(spec, list, false)
    local filter = list.filterDropdown
    if filter and C.Free(filter) then Look.Pin(filter, "TOPRIGHT", sheet, "TOPRIGHT", -40, -62) end
    if spec.kind == "reputation" then RepLabels(list, sheet) end
    if spec.kind == "skills" and C.DressSkillPane then
        Look.Try(C.DressSkillPane)
        if C.WatchSkillPane then C.WatchSkillPane() end
    end
end

-- The PvP rank panel in the window's upper area.
function C.SkinPvP()
    local panel = PVPRankFrame and PVPRankFrame.MainInfoFrame
    if not (C.active and panel and C.Free(panel)) then return end
    panel:ClearAllPoints()
    panel:SetPoint("TOPLEFT", CharacterFrame, "TOPLEFT", 6, -70)
    panel:SetPoint("BOTTOMRIGHT", CharacterFrame, "TOPRIGHT", -6, -205)
end

function C.SkinAllLists()
    for _, spec in ipairs(C.LISTS) do Look.Try(C.SkinList, spec) end
    Look.Try(C.SkinPvP)
end
