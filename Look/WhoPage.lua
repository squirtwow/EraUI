-- The Who page's frame (Classic look, spec 10 section 7): EraUIClassicWhoPanel
-- on the social window, built once at the first Who pass. Top to bottom:
-- the stone band and four column headers (Name, the chosen second column,
-- Lvl, Class) with the second column's drop down, the list of up to 30 rows
-- with its 1.x scroll bar and stone column, "N found", the search line
-- across the window, and Refresh, Add Friend and Group Invite at the foot.
-- Down the window's right edge, optional: three round side tabs leading to
-- the group finder, behind a page-turn arrow. What the page does lives in
-- Look/WhoList.lua; this file only lays it out and wires its controls.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local W = S.who
local parts = W.parts

-- The second column: what it can show, its label and the entry's field.
W.SECOND = {
    zone = { label = function() return S.Say("ZONE", "Zone") end },
    guild = { label = function() return S.Say("GUILD", "Guild") end },
    race = { label = function() return S.Say("RACE", "Race") end },
}

function W.SecondField()
    local chosen = Look.Saved().whoColumn
    if type(chosen) == "string" and W.SECOND[chosen] then return chosen end
    return "zone"
end

-- The columns' places in a row (x, width) and their header labels.
W.COLUMNS = {
    { key = "name", x = 4, width = 104 },
    { key = "second", x = 108, width = 104 },
    { key = "level", x = 212, width = 34 },
    { key = "class", x = 246, width = 92 },
}

local function HeaderLabel(column)
    if column.key == "name" then return S.Say("NAME", "Name") end
    if column.key == "level" then return S.Say("LEVEL_ABBR", "Lvl") end
    if column.key == "class" then return S.Say("CLASS", "Class") end
    return W.SECOND[W.SecondField()].label()
end
W.HeaderLabel = HeaderLabel

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------

local function Headers(page)
    local row = Look.Build("Frame", page, nil, { size = { 322, 20 } })
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", page, "TOPRIGHT", -22, 0)
    parts.headerRow = row
    parts.headers = {}
    local previous
    for i, column in ipairs(W.COLUMNS) do
        local header = S.ColumnHeader(row, { width = column.width, label = HeaderLabel(column) }, previous, function()
            W.HeaderClicked(i)
        end)
        parts.headers[i] = header
        previous = header
    end
    -- The second column's drop down: Zone, Guild or Race.
    local drop = Look.Build("Button", row, nil, { size = { 22, 22 } })
    Look.Pin(drop, "RIGHT", parts.headers[2], "RIGHT", 1, 0)
    drop:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    drop:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
    local glow = Look.StateArt(drop, "Highlight", "mouseHighlight")
    if glow then glow:SetBlendMode("ADD") end
    drop:SetScript("OnClick", function() W.OpenColumnMenu() end)
    parts.columnDrop = drop
end

local function ListBox(page)
    -- The foot's divider (invisible; it holds the layout) and the list box
    -- reaching from under the headers down to it, both the window's edge
    -- less 5 on each side.
    local footLine = Look.StoneBar(page)
    footLine:SetAlpha(0)
    Look.Pin(footLine, "BOTTOMLEFT", page, "BOTTOMLEFT", -3, 18)
    footLine:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 3, 18)
    parts.divider = footLine
    local box = S.SectionBox(page)
    box:SetPoint("TOPLEFT", parts.headerRow, "BOTTOMLEFT", -3, -5)
    box:SetPoint("BOTTOMRIGHT", footLine, "TOPRIGHT", 0, 1)
    parts.box = box
    local found = Look.Label(box, "GameFontNormalSmall", "ARTWORK")
    found:SetHeight(12)
    S.Colour(found, S.GOLD)
    Look.Pin(found, "CENTER", box, "BOTTOM", 0, 19)
    parts.found = found
    -- The list: 8 in and 4 down, its right 26 short of the box's, its foot
    -- 2 above the found text.
    local area = Look.Build("Frame", box, nil, { size = { 290, 200 } })
    area:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -4)
    area:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 27)
    parts.area = area
    -- Its 1.x scroll bar, a little taller than the default one.
    local slider = Look.ClassicScrollBar(box, area, function() W.Fill() end, true)
    Look.Pin(slider, "TOPLEFT", area, "TOPRIGHT", 6, -14)
    slider:SetPoint("BOTTOMLEFT", area, "BOTTOMRIGHT", 6, 4)
    Look.ScrollColumn(slider)
    parts.bar = slider
    S.Wheel(area, slider)
    parts.rows = {}
    for i = 1, 30 do
        local row = S.ListRow(area, i, W.COLUMNS)
        row:SetScript("OnClick", W.RowClicked)
        row:SetScript("OnDoubleClick", W.RowDoubleClicked)
        parts.rows[i] = row
    end
end

-- The search line: a box across the list box's foot with a lens, a clear
-- button and the old dialog border round it.
local CLEAR_ICON = "Interface\\FriendsFrame\\ClearBroadcastIcon"

-- The box's three edge pieces greyed a little (0.85, no colour).
local function GreyEdges(field)
    for _, side in ipairs(Look.Words("Left Middle Right")) do
        local edge = field[side]
        if edge then
            edge:SetDesaturated(true)
            Look.Tint(edge, { 0.85, 0.85, 0.85 })
        end
    end
end

local function Eraser(field)
    local eraser = Look.Build("Button", field, nil, { size = { 17, 17 }, hidden = true })
    Look.Pin(eraser, "RIGHT", field, "RIGHT", -3, 0)
    eraser:SetNormalTexture(CLEAR_ICON)
    eraser:SetHighlightTexture(CLEAR_ICON)
    Look.Alpha(eraser:GetNormalTexture(), 0.6)
    eraser:GetHighlightTexture():SetBlendMode("ADD")
    eraser:SetScript("OnClick", function()
        field:SetText("")
        field:ClearFocus()
    end)
    Look.HookScript(field, "OnTextChanged", function(self)
        local typed = self:GetText()
        Look.Shown(eraser, type(typed) == "string" and typed ~= "")
    end, "whoSearch")
    return eraser
end

local function SearchLine()
    local box = parts.box
    local field = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
    field:SetHeight(18)
    field:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 6, -7)
    field:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -2, -7)
    GreyEdges(field)
    if ChatFontNormal then field:SetFontObject(ChatFontNormal) end
    field:SetAutoFocus(false)
    field:SetMaxLetters(60)
    field:SetTextInsets(16, 20, 0, 0)
    local glass = Look.OwnTexture(field, "lens", "OVERLAY")
    glass:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    glass:SetSize(14, 14)
    Look.Tint(glass, { 0.6, 0.6, 0.6 })
    Look.Pin(glass, "LEFT", field, "LEFT", 1, -2)
    local eraser = Eraser(field)
    field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    field:SetScript("OnEnterPressed", function(self)
        W.Send(self:GetText() or "")
        self:ClearFocus()
    end)
    -- The border: 7 above and below the box, from 2 left of the window to
    -- its right edge (13 left of the box, 7 right of it).
    local band = Look.Build("Frame", box, "BackdropTemplate", { size = { 360, 32 } })
    band:SetPoint("TOPLEFT", field, "TOPLEFT", -13, 7)
    band:SetPoint("BOTTOMRIGHT", field, "BOTTOMRIGHT", 7, -7)
    band:SetFrameLevel(Look.Number(field:GetFrameLevel()) or 1)
    band:SetBackdrop({ edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", edgeSize = 20,
        insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    if ns.DarkBackdrop then ns.DarkBackdrop(band, false) end
    parts.search, parts.searchClear, parts.searchBorder = field, eraser, band
end

local function Buttons(page)
    local add = Look.PanelButton(page, S.Say("ADD_FRIEND", "Add Friend"), 127)
    Look.Pin(add, "BOTTOM", page, "BOTTOM", -6, -7)
    local refresh = Look.PanelButton(page, S.Say("REFRESH", "Refresh"), 112)
    Look.Pin(refresh, "RIGHT", add, "LEFT", 1.5, 0)
    local invite = Look.PanelButton(page, S.Say("GROUP_INVITE", "Group Invite"), 123)
    Look.Pin(invite, "LEFT", add, "RIGHT", -3.5, 0)
    add:SetScript("OnClick", function() W.AddFriend() end)
    invite:SetScript("OnClick", function() W.Invite() end)
    refresh:SetScript("OnClick", function()
        local text = parts.search and parts.search:GetText()
        W.Send(type(text) == "string" and text or "")
    end)
    parts.addFriend, parts.refresh, parts.invite = add, refresh, invite
end

---------------------------------------------------------------------------
-- The group finder's side tabs and their page-turn arrow
---------------------------------------------------------------------------

local SIDE_TABS = {
    { icon = "Interface/Icons/INV_Helmet_08", tip = function() return S.Say("LFG_LIST_TAB_1", "Create Listing") end },
    { icon = "Interface/Icons/Achievement_General_StayClassy", tip = function() return S.Say("LFG_LIST_TAB_2", "Group Browser") end },
    { icon = "Interface/Icons/INV_OwlDragonMount", tip = function() return S.Say("LFG_LIST_TAB_3", S.Say("WHO", "Who")) end },
}
W.SIDE_TABS = SIDE_TABS

local function ArrowArt(arrow, open)
    if W.arrowOpen == open then return end
    W.arrowOpen = open
    Look.StateArt(arrow, "Normal", open and "sbPrevUp" or "sbNextUp")
    Look.StateArt(arrow, "Pushed", open and "sbPrevDown" or "sbNextDown")
end
W.ArrowArt = ArrowArt

local function ArrowTip(arrow)
    local words = S.Say("LOOKING_FOR_GROUP", S.Say("GROUP_FINDER", "Group Finder"))
    Look.ShowTip(arrow, "RIGHT", { { words, 1, 1, 1 } })
end

function W.BuildSideTabs()
    if parts.sideTabs then return parts.sideTabs end
    local page, window = parts.page, FriendsFrame
    if type(ns.NewSideTab) ~= "function" then return nil end
    local tabs, previous = {}, nil
    for i, spec in ipairs(SIDE_TABS) do
        local tab = ns.NewSideTab(page, i, previous)
        tab:SetNormalTexture(spec.icon)
        tab.tooltip, tab.tooltipText = spec.tip(), spec.tip()
        if i == 1 then Look.Pin(tab, "TOPLEFT", window, "TOPRIGHT", -3, -58) end
        tab:SetScript("OnClick", function(self) W.SideTabClicked(self, i) end)
        tabs[i] = tab
        previous = tab
    end
    parts.sideTabs = tabs
    -- A secure click on the game's group finder button lies over Create
    -- Listing and Group Browser while the finder is shut (so the finder
    -- opens out of a fight from the player's own click); it stands aside in
    -- a fight, when the tab's own click says no.
    if type(ns.MapPad) == "function" and LFDMicroButton then
        for i = 1, 2 do
            ns.MapPad(tabs[i], "HIGH", function() W.SideTabReleased(i) end, LFDMicroButton, function()
                return not (LFGParentFrame and LFGParentFrame:IsShown())
            end)
        end
    end
    return tabs
end

local function Arrow(page)
    local window = FriendsFrame
    local arrow = Look.Build("Button", page, nil, { name = "EraUIClassicWhoTabsToggle", size = { 24, 24 } })
    Look.Pin(arrow, "TOPRIGHT", window, "TOPRIGHT", -8, -28)
    arrow:SetFrameLevel((Look.Number(page:GetFrameLevel()) or 1) + 20)
    local glow = Look.StateArt(arrow, "Highlight", "mouseHighlight")
    if glow then glow:SetBlendMode("ADD") end
    ArrowArt(arrow, Look.Saved().whoTabs == true)
    arrow:SetScript("OnClick", function() W.FlipSideTabs() end)
    arrow:SetScript("OnEnter", ArrowTip)
    arrow:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    parts.arrow = arrow
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function W.Build()
    if parts.page then return parts.page end
    local page = S.PageFrame("EraUIClassicWhoPanel")
    parts.page = page
    S.HeaderBand(page)
    Headers(page)
    ListBox(page)
    SearchLine()
    Buttons(page)
    Arrow(page)
    page:SetScript("OnShow", function() W.PageShown() end)
    page:SetScript("OnHide", function() W.PageHidden() end)
    S.KeepSwept(page, "who")
    W.Listen()
    return page
end
