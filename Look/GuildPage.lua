-- The Guild page's frame (Classic look, spec 10 section 8):
-- EraUIClassicGuildPanel on the social window, built once at the first guild
-- pass. Show Offline Members in its pill above the page; the stone band and
-- four column headers (the player view: Name, Zone, Lvl, Class; the status
-- view: Name, Rank, Note, Last Online); the roster rows with their 1.x
-- scroll bar and stone column; the member and online counts; the view
-- toggle; the message of the day in its box between two stone bars; and
-- Guild Information, Add Member and Guild Control at the foot. What the page
-- does lives in Look/GuildRoster.lua and Look/GuildMember.lua.
local _, EraUI = ...
local Look = EraUI.Look
local S = Look.Social
local G = S.guild
local parts = G.parts

local function Column(key, x, width, word, fallback)
    return { key = key, x = x, width = width, label = function() return S.Say(word, fallback) end }
end

G.VIEWS = {
    player = { Column("name", 4, 96, "NAME", "Name"), Column("zone", 100, 112, "ZONE", "Zone"),
        Column("level", 212, 34, "LEVEL_ABBR", "Lvl"), Column("class", 246, 92, "CLASS", "Class") },
    status = { Column("name", 4, 96, "NAME", "Name"), Column("rank", 100, 80, "RANK", "Rank"),
        Column("note", 180, 84, "LABEL_NOTE", "Note"), Column("lastOnline", 264, 74, "LASTONLINE", "Last Online") },
}
G.view = "player"

function G.Columns()
    return G.VIEWS[G.view] or G.VIEWS.player
end

---------------------------------------------------------------------------
-- Pieces
---------------------------------------------------------------------------

-- Show Offline Members: a check button in the old filter pill, its box at
-- the right, above the page's top-right corner.
local function OfflinePill(page)
    local pill = Look.Build("CheckButton", page, nil, { size = { 210, 23 } })
    Look.Pin(pill, "TOPRIGHT", page, "TOPRIGHT", 0, 30)
    local right = Look.OwnTexture(pill, "pillRight", "BACKGROUND")
    local middle = Look.OwnTexture(pill, "pillMiddle", "BACKGROUND")
    local left = Look.OwnTexture(pill, "pillLeft", "BACKGROUND")
    for piece, spec in pairs({ [right] = { 12, 0.90625, 1 }, [middle] = { 186, 0.09375, 0.90625 }, [left] = { 12, 0, 0.09375 } }) do
        Look.Art(piece, "socialFilterBorder")
        piece:SetSize(spec[1], 28)
        Look.Crop(piece, spec[2], spec[3], 0, 1)
    end
    Look.Pin(right, "TOPRIGHT", pill, "TOPRIGHT", 0, 3)
    Look.Pin(middle, "RIGHT", right, "LEFT", 0, 0)
    Look.Pin(left, "RIGHT", middle, "LEFT", 0, 0)
    local box = Look.OwnTexture(pill, "box", "ARTWORK")
    box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    box:SetSize(22, 22)
    Look.Pin(box, "RIGHT", pill, "RIGHT", -6, 2)
    pill:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    pill:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    for _, face in ipairs({ pill:GetCheckedTexture(), pill:GetHighlightTexture() }) do
        face:SetSize(22, 22)
        Look.Pin(face, "CENTER", box, "CENTER", 0, 0)
    end
    local check = pill:GetCheckedTexture()
    if check.SetDrawLayer then check:SetDrawLayer("OVERLAY") end
    pill:GetHighlightTexture():SetBlendMode("ADD")
    local label = Look.OwnLabel(pill, "label", "GameFontHighlightSmall", "ARTWORK")
    Look.Pin(label, "CENTER", pill, "CENTER", -3, 2)
    label:SetText(S.Say("SHOW_OFFLINE_MEMBERS", "Show Offline Members"))
    pill:SetScript("OnClick", function(self) G.OfflineClicked(self:GetChecked() and true or false) end)
    parts.offline = pill
end

local function Headers(page)
    local row = Look.Build("Frame", page, nil, { size = { 322, 20 } })
    row:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    row:SetPoint("TOPRIGHT", page, "TOPRIGHT", -22, 0)
    parts.headerRow = row
    parts.headers = {}
    local previous
    for i, column in ipairs(G.Columns()) do
        local header = S.ColumnHeader(row, { width = column.width, label = column.label() }, previous, function()
            G.HeaderClicked(i)
        end)
        parts.headers[i] = header
        previous = header
    end
end

-- From the foot up: the buttons, the lower stone bar, the message box, the
-- upper stone bar, then the list box up to the headers. Every band reaches
-- 3 past the page on each side (the window's edge less 5).
local function Across(piece, below, rise, tall)
    piece:ClearAllPoints()
    if below then
        piece:SetPoint("BOTTOMLEFT", below, "TOPLEFT", 0, rise)
        piece:SetPoint("BOTTOMRIGHT", below, "TOPRIGHT", 0, rise)
    else
        piece:SetPoint("BOTTOMLEFT", parts.page, "BOTTOMLEFT", -3, rise)
        piece:SetPoint("BOTTOMRIGHT", parts.page, "BOTTOMRIGHT", 3, rise)
    end
    if tall then piece:SetHeight(tall) end
end

local function Foot(page)
    local add = Look.PanelButton(page, S.Say("ADDMEMBER", "Add Member"), 118)
    Look.Pin(add, "BOTTOM", page, "BOTTOM", 4, -8)
    local control = Look.PanelButton(page, S.Say("GUILDCONTROL", "Guild Control"), 110)
    Look.Pin(control, "LEFT", add, "RIGHT", 2, 0)
    local info = Look.PanelButton(page, S.Say("GUILD_INFORMATION", "Guild Information"), 126)
    Look.Pin(info, "RIGHT", add, "LEFT", 1, 0)
    add:SetScript("OnClick", function() G.AddMember() end)
    control:SetScript("OnClick", function() G.GuildControl() end)
    info:SetScript("OnClick", function() G.GuildInformation() end)
    parts.addMember, parts.guildControl, parts.guildInfo = add, control, info
    local lower = Look.StoneBar(page)
    Across(lower, nil, 15, 6)
    local message = S.SectionBox(page)
    Across(message, lower, 1, 74)
    local upper = Look.StoneBar(page)
    Across(upper, message, 1, 6)
    parts.lowerBar, parts.messageBox, parts.upperBar = lower, message, upper
    local heading = Look.Label(message, "GameFontNormalSmall", "ARTWORK")
    S.Colour(heading, S.GOLD)
    Look.Pin(heading, "TOPLEFT", message, "TOPLEFT", 8, -8)
    local locale = type(GetLocale) == "function" and GetLocale() or ""
    if locale == "enUS" or locale == "enGB" then
        heading:SetText("Guild Message Of The Day:")
    else
        heading:SetText(S.Say("GUILD_MOTD_LABEL", "Message of the Day") .. ":")
    end
    local text = Look.Label(message, "GameFontHighlightSmall", "ARTWORK")
    text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -3)
    text:SetPoint("BOTTOMRIGHT", message, "BOTTOMRIGHT", -8, 6)
    text:SetJustifyH("LEFT")
    if text.SetJustifyV then text:SetJustifyV("TOP") end
    parts.motdHeading, parts.motd = heading, text
end

local function ViewToggle(box)
    local toggle = Look.Build("Button", box, nil, { size = { 28, 28 } })
    Look.Pin(toggle, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -8, 2)
    Look.StateArt(toggle, "Normal", "sbNextUp")
    Look.StateArt(toggle, "Pushed", "sbNextDown")
    local glow = Look.StateArt(toggle, "Highlight", "mouseHighlight")
    if glow then glow:SetBlendMode("ADD") end
    toggle:SetScript("OnClick", function() G.FlipView() end)
    toggle:SetScript("OnEnter", function(self) G.ViewTip(self) end)
    toggle:SetScript("OnLeave", function(self) Look.HideTip(self) end)
    parts.viewToggle = toggle
end

local function List(page)
    local box = S.SectionBox(page)
    box:SetPoint("TOPLEFT", parts.headerRow, "BOTTOMLEFT", -3, -5)
    box:SetPoint("BOTTOMRIGHT", parts.upperBar, "TOPRIGHT", 0, 1)
    parts.box = box
    local members = Look.Label(box, "GameFontNormalSmall", "ARTWORK")
    members:SetHeight(12)
    S.Colour(members, S.GOLD)
    Look.Pin(members, "BOTTOMLEFT", box, "BOTTOMLEFT", 8, 6)
    local online = Look.Label(box, "GameFontHighlightSmall", "ARTWORK")
    online:SetTextColor(0.1, 1, 0.1)
    Look.Pin(online, "LEFT", members, "RIGHT", 4, 0)
    parts.members, parts.online = members, online
    local area = Look.Build("Frame", box, nil, { size = { 290, 190 } })
    area:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -4)
    area:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -26, 22)
    parts.area = area
    local bar = Look.ClassicScrollBar(box, area, function() G.Fill() end, true)
    Look.ScrollColumn(bar)
    parts.bar = bar
    S.Wheel(area, bar)
    parts.rows = {}
    for i = 1, 30 do
        local row = S.ListRow(area, i, G.Columns())
        row:SetScript("OnClick", G.RowClicked)
        row:SetScript("OnDoubleClick", G.RowDoubleClicked)
        parts.rows[i] = row
    end
    ViewToggle(box)
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

function G.Build()
    if parts.page then return parts.page end
    local page = S.PageFrame("EraUIClassicGuildPanel")
    parts.page = page
    OfflinePill(page)
    S.HeaderBand(page)
    Headers(page)
    Foot(page)
    List(page)
    page:SetScript("OnShow", function() G.PageShown() end)
    page:SetScript("OnHide", function() G.PageHidden() end)
    S.KeepSwept(page, "guild")
    G.Listen()
    return page
end
