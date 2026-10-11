-- EraUI social window.
-- The 1.x social window: its tabs in the old order and the old names, and the
-- Who list rebuilt as one of them. The client answers /who with a window of
-- its own; this takes that job while the toggle is on.
local _, EraUI = ...
local ns = EraUI.Classic

local ROW_H = 16
local active = false
local panel, tab
local SelectOurTab
local results = {}
local sortField = "name"
local sortReverse = false

local COLUMNS = {
    { key = "name", label = NAME or "Name", x = 4, w = 104, justify = "LEFT" },
    { key = "zone", label = ZONE or "Zone", x = 108, w = 104, justify = "LEFT" },
    { key = "level", label = LEVEL_ABBR or "Lvl", x = 212, w = 34, justify = "LEFT" },
    { key = "class", label = CLASS or "Class", x = 246, w = 92, justify = "LEFT" },
}

local WHO_FIELDS = {
    { key = "zone", label = ZONE or "Zone" },
    { key = "guild", label = GUILD or "Guild" },
    { key = "race", label = _G.RACE or "Race" },
}
local function WhoField()
    local want = ns.db and ns.db.whoColumn
    for _, field in ipairs(WHO_FIELDS) do
        if field.key == want then return field end
    end
    return WHO_FIELDS[1]
end

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function Safe(v, fallback)
    if v == nil or IsSecret(v) then return fallback end
    return v
end

local function Collect()
    wipe(results)
    if not (C_FriendList and C_FriendList.GetNumWhoResults and C_FriendList.GetWhoInfo) then return 0 end
    local ok, shown, total = pcall(C_FriendList.GetNumWhoResults)
    if not ok then return 0 end
    shown = Safe(shown, 0) or 0
    for i = 1, shown do
        local fine, info = pcall(C_FriendList.GetWhoInfo, i)
        if fine and type(info) == "table" and info.fullName and not IsSecret(info.fullName) then
            results[#results + 1] = {
                name = info.fullName,
                guild = Safe(info.fullGuildName, ""),
                zone = Safe(info.area, ""),
                level = Safe(info.level, 0),
                class = Safe(info.classStr, ""),
                classFile = Safe(info.filename, nil),
                race = Safe(info.raceStr, ""),
            }
        end
    end
    local key = sortField or "name"
    if key == "zone" then key = WhoField().key end
    table.sort(results, function(a, b)
        local x, y = a[key], b[key]
        if x == y then x, y = a.name, b.name end
        if type(x) == "string" then x, y = x:lower(), tostring(y):lower() end
        if sortReverse then return x > y end
        return x < y
    end)
    return Safe(total, shown) or shown
end

local function RowCount()
    if not panel then return 0 end
    return math.max(1, math.floor((panel.list:GetHeight() or 0) / ROW_H))
end

local function UpdateRows()
    if not panel then return end
    local offset = math.floor((panel.bar:GetValue() or 0) + 0.5)
    local shown = RowCount()
    for i, row in ipairs(panel.rows) do
        local entry = i <= shown and results[offset + i] or nil
        if entry then
            row.entry = entry
            row.Name:SetText(entry.name)
            row.Zone:SetText(entry[WhoField().key] or "")
            row.Level:SetText(entry.level)
            row.Class:SetText(entry.class)
            row.Name:SetTextColor(1, 0.82, 0)
            row.Zone:SetTextColor(1, 1, 1)
            row.Level:SetTextColor(1, 1, 1)
            local color = entry.classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[entry.classFile]
            if color then row.Class:SetTextColor(color.r, color.g, color.b) else row.Class:SetTextColor(1, 1, 1) end
            row.Selected:SetShown(panel.selected == offset + i)
            row:Show()
        else
            row.entry = nil
            row:Hide()
        end
    end
    panel.bar:SetRange(math.max(0, #results - shown))
end

local function SelectedEntry()
    return panel and panel.selected and results[panel.selected]
end

local function UpdateButtons()
    if not panel then return end
    local entry = SelectedEntry()
    panel.add:SetEnabled(entry and true or false)
    panel.invite:SetEnabled(entry and true or false)
end

local function DressWindow()
    if FriendsFrameTitleText then FriendsFrameTitleText:SetText(WHO_LIST or "Who List") end
end

local function Refresh()
    if not panel or not panel:IsShown() then return end
    local total = Collect()
    panel.found:SetText(format(WHO_NUM_RESULTS or "%d People Found", total or #results))
    DressWindow()
    UpdateRows()
    UpdateButtons()
end
ns.RefreshWhoList = Refresh

local rowMenu
local function ShowRowMenu(entry)
    if not rowMenu then
        rowMenu = ns.RowMenu({
            { WHISPER or "Whisper", function(who) ns.Whisper(who.name) end },
            { INVITE or "Invite", function(who) if C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(who.name) end end },
            { ADD_FRIEND or "Add Friend", function(who) if C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(who.name) end end },
            { IGNORE or "Ignore", function(who) if C_FriendList and C_FriendList.AddIgnore then C_FriendList.AddIgnore(who.name) end end },
        })
    end
    rowMenu:Follow(panel)
    rowMenu:Open(entry, entry.name)
end

local function Row_OnClick(self, button)
    if not self.entry then return end
    for i, entry in ipairs(results) do
        if entry == self.entry then panel.selected = i end
    end
    UpdateRows()
    UpdateButtons()
    -- /who names are "First Surname" on Forever: no menu on your own line.
    if button == "RightButton" and not EraUI:IsPlayer(self.entry.name) then
        ShowRowMenu(self.entry)
    end
end

local function Row_OnDoubleClick(self)
    if self.entry then ns.Whisper(self.entry.name) end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(row)
    sel:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    sel:SetBlendMode("ADD")
    sel:SetVertexColor(1, 0.82, 0, 1)
    sel:SetTexCoord(0, 0.97, 0, 1)
    sel:Hide()
    row.Selected = sel

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestLogTitleHighlight")
    highlight:SetBlendMode("ADD")
    highlight:SetVertexColor(1, 0.82, 0, 1)
    highlight:SetTexCoord(0, 0.97, 0, 1)

    for _, column in ipairs(COLUMNS) do
        local text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        text:SetPoint("LEFT", row, "LEFT", column.x, 0)
        text:SetWidth(column.w)
        text:SetJustifyH(column.justify)
        text:SetWordWrap(false)
        row[column.key:gsub("^%l", string.upper)] = text
    end
    row:SetScript("OnClick", Row_OnClick)
    row:SetScript("OnDoubleClick", Row_OnDoubleClick)
    return row
end

local function Header_OnClick(self)
    if sortField == self.key then
        sortReverse = not sortReverse
    else
        sortField, sortReverse = self.key, false
    end
    Refresh()
end

local BLIZZARD_PANELS = { "FriendsListFrame", "IgnoreListFrame", "WhoFrame", "RaidFrame", "QuickJoinFrame", "FriendsFrameBroadcastInput" }

local function HideRowMenu()
    if rowMenu and rowMenu:IsShown() then rowMenu:Hide() end
end

local function CloseClientWhoWindow()
    local who = _G["LFGWhoListFrame"]
    local parent = _G["LFGParentFrame"]
    if not (FriendsFrame and FriendsFrame:IsVisible()) then return end
    if who and who:IsShown() and parent and parent:IsShown() then
        local first = _G["LFGParentFrameTab1_OnClick"]
        if type(first) == "function" then pcall(first) end
        ns.HidePanel(parent)
    end
end

local mousePending = false
local settle = CreateFrame("Frame")
settle:RegisterEvent("PLAYER_REGEN_ENABLED")
settle:SetScript("OnEvent", function()
    if not mousePending then return end
    mousePending = false
    for _, name in ipairs(BLIZZARD_PANELS) do
        local frame = _G[name]
        if frame and frame.EnableMouse then
            frame:EnableMouse(not (frame.fcuiGuildHidden or frame.fcuiWhoHidden))
        end
    end
end)

local function HideBlizzardPanels()
    CloseClientWhoWindow()
    for _, name in ipairs(BLIZZARD_PANELS) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:SetAlpha(0)
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(false)
            else
                mousePending = true
            end
            frame.fcuiWhoHidden = true
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(0) end
    ns.SweepFriendsFrame("fcuiWhoSwept", true)
    ns.KeepFriendsSwept(panel, "fcuiWhoSwept")
end

local function ShowBlizzardPanels()
    for _, name in ipairs(BLIZZARD_PANELS) do
        local frame = _G[name]
        if frame and frame.fcuiWhoHidden then
            frame:SetAlpha(1)
            if frame.EnableMouse and not InCombatLockdown() then
                frame:EnableMouse(true)
            else
                mousePending = true
            end
            frame.fcuiWhoHidden = nil
        end
    end
    local header = FriendsFrame and FriendsFrame.FriendsTabHeader
    if header then header:SetAlpha(1) end
    ns.SweepFriendsFrame("fcuiWhoSwept", false)
end

local function Build()
    local host = FriendsFrame
    if not host then return end
    panel = CreateFrame("Frame", "EraUIClassicWhoPanel", host)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 8, -64)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -8, 12)
    panel:SetFrameLevel(host:GetFrameLevel() + 6)
    panel:Hide()

    panel.add = ns.PanelButton(panel, ADD_FRIEND or "Add Friend", 127)
    panel.add:SetPoint("BOTTOM", panel, "BOTTOM", -6, -7)
    panel.refresh = ns.PanelButton(panel, REFRESH or "Refresh", 112)
    panel.refresh:SetPoint("RIGHT", panel.add, "LEFT", 1.5, 0)
    panel.refresh:SetScript("OnClick", function()
        if C_FriendList and C_FriendList.SendWho then
            pcall(C_FriendList.SendWho, panel.query and panel.query:GetText() or "")
        end
    end)
    panel.add:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_FriendList and C_FriendList.AddFriend then C_FriendList.AddFriend(entry.name) end
    end)
    panel.invite = ns.PanelButton(panel, GROUP_INVITE or "Group Invite", 123)
    panel.invite:SetPoint("LEFT", panel.add, "RIGHT", -3.5, 0)
    panel.invite:SetScript("OnClick", function()
        local entry = SelectedEntry()
        if entry and C_PartyInfo and C_PartyInfo.InviteUnit then C_PartyInfo.InviteUnit(entry.name) end
    end)

    panel.divider = ns.StoneBar(panel)
    panel.divider:SetAlpha(0)
    panel.divider:SetPoint("BOTTOM", panel.refresh, "TOP", 0, 3)
    panel.divider:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.divider:SetPoint("RIGHT", host, "RIGHT", -5, 0)

    local headerBand = CreateFrame("Frame", nil, panel)
    headerBand:SetHeight(22)
    headerBand:SetPoint("TOP", panel, "TOP", 0, 1)
    headerBand:SetPoint("LEFT", host, "LEFT", 5, 0)
    headerBand:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    local stone = ns.StoneFill(headerBand, "BACKGROUND")
    stone:SetAllPoints(headerBand)

    local headerRow = CreateFrame("Frame", nil, panel)
    headerRow:SetHeight(20)
    headerRow:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    headerRow:SetPoint("RIGHT", panel, "RIGHT", -22, 0)
    local lastHeader
    for _, column in ipairs(COLUMNS) do
        lastHeader = ns.ColumnHeader(headerRow, column, lastHeader, Header_OnClick)
        if column.key == "zone" then
            local header = lastHeader
            if header.Text then header.Text:SetText(WhoField().label) end
            local arrow = CreateFrame("Button", nil, header)
            arrow:SetSize(22, 22)
            arrow:SetPoint("RIGHT", header, "RIGHT", 1, 0)
            arrow:SetNormalTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Up")
            arrow:SetPushedTexture("Interface/ChatFrame/UI-ChatIcon-ScrollDown-Down")
            arrow:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
            local entries = {}
            for _, field in ipairs(WHO_FIELDS) do
                entries[#entries + 1] = { field.label, function()
                    ns.db.whoColumn = field.key
                    if header.Text then header.Text:SetText(field.label) end
                    sortField, sortReverse = "zone", false
                    Refresh()
                end }
            end
            local menu
            arrow:SetScript("OnClick", function()
                if not menu then
                    menu = ns.RowMenu(entries)
                    menu:Follow(panel)
                end
                menu:Open(WHO_FIELDS, "")
            end)
        end
    end

    panel.listBox = ns.SectionBox(panel)
    panel.listBox:SetPoint("TOP", headerRow, "BOTTOM", 0, -5)
    panel.listBox:SetPoint("LEFT", host, "LEFT", 5, 0)
    panel.listBox:SetPoint("RIGHT", host, "RIGHT", -5, 0)
    panel.listBox:SetPoint("BOTTOM", panel.divider, "TOP", 0, 1)

    panel.found = panel.listBox:CreateFontString(nil, "ARTWORK")
    panel.found:SetFontObject(ns.FONT_GOLD_SMALL or "GameFontNormalSmall")
    panel.found:SetPoint("BOTTOM", panel.listBox, "BOTTOM", 0, 19)

    panel.query = CreateFrame("EditBox", nil, panel.listBox, "InputBoxTemplate")
    panel.query:SetPoint("BOTTOMLEFT", panel.listBox, "BOTTOMLEFT", 6, -7)
    panel.query:SetPoint("RIGHT", panel.listBox, "RIGHT", -2, 0)
    panel.query:SetHeight(18)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        local piece = panel.query[key]
        if piece and piece.SetDesaturated then
            piece:SetDesaturated(true)
            piece:SetVertexColor(0.85, 0.85, 0.85)
        end
    end
    local lens = panel.query:CreateTexture(nil, "OVERLAY")
    lens:SetTexture("Interface/Common/UI-Searchbox-Icon")
    lens:SetSize(14, 14)
    lens:SetPoint("LEFT", panel.query, "LEFT", 1, -2)
    lens:SetVertexColor(0.6, 0.6, 0.6)
    panel.query:SetTextInsets(16, 20, 0, 0)
    local clear = CreateFrame("Button", nil, panel.query)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", panel.query, "RIGHT", -3, 0)
    clear:SetNormalTexture("Interface/FriendsFrame/ClearBroadcastIcon")
    clear:SetHighlightTexture("Interface/FriendsFrame/ClearBroadcastIcon", "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", function()
        panel.query:SetText("")
        panel.query:ClearFocus()
    end)
    clear:Hide()
    panel.query:HookScript("OnTextChanged", function(self)
        clear:SetShown((self:GetText() or "") ~= "")
    end)
    local queryBox = CreateFrame("Frame", nil, panel.listBox, BackdropTemplateMixin and "BackdropTemplate" or nil)
    queryBox:SetPoint("TOP", panel.query, "TOP", 0, 7)
    queryBox:SetPoint("BOTTOM", panel.query, "BOTTOM", 0, -7)
    queryBox:SetPoint("LEFT", host, "LEFT", -2, 0)
    queryBox:SetPoint("RIGHT", host, "RIGHT", 0, 0)
    queryBox:SetFrameLevel(panel.query:GetFrameLevel())
    if queryBox.SetBackdrop then
        queryBox:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = 20,
            insets = { left = 5, right = 5, top = 5, bottom = 5 },
        })
        -- Dark Windows: the border takes Dark Mode's grey (no fill).
        if ns.DarkBackdrop then ns.DarkBackdrop(queryBox, false) end
    end
    panel.queryBox = queryBox
    panel.query:SetAutoFocus(false)
    panel.query:SetFontObject("ChatFontNormal")
    panel.query:SetMaxLetters(60)
    panel.query:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    panel.query:SetScript("OnEnterPressed", function(self)
        if C_FriendList and C_FriendList.SendWho then pcall(C_FriendList.SendWho, self:GetText() or "") end
        self:ClearFocus()
    end)

    local list = CreateFrame("Frame", nil, panel.listBox)
    list:SetPoint("TOPLEFT", panel.listBox, "TOPLEFT", 8, -4)
    list:SetPoint("BOTTOMRIGHT", panel.found, "TOPRIGHT", 0, 2)
    list:SetPoint("RIGHT", panel.listBox, "RIGHT", -26, 0)
    list:EnableMouseWheel(true)
    panel.list = list

    panel.bar = ns.ClassicScrollBar(panel, list, function() UpdateRows() end)
    panel.bar:ClearAllPoints()
    panel.bar:SetPoint("TOPLEFT", list, "TOPRIGHT", 6, -14)
    panel.bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", 6, 4)
    panel.bar.hideWhenIdle = true
    if ns.ScrollColumnOn then ns.ScrollColumnOn(panel.bar) end
    list:SetScript("OnMouseWheel", function(_, delta)
        panel.bar:SetValue((panel.bar:GetValue() or 0) - delta)
    end)

    panel.rows = {}
    for i = 1, 30 do panel.rows[i] = CreateRow(list, i) end

    panel:SetScript("OnShow", function()
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, true) end
        Refresh()
    end)
    panel:SetScript("OnHide", function()
        if C_FriendList and C_FriendList.SetWhoToUi then pcall(C_FriendList.SetWhoToUi, false) end
    end)

    local driver = CreateFrame("Frame")
    driver:RegisterEvent("WHO_LIST_UPDATE")
    driver:SetScript("OnEvent", function()
        if not active then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
        DressWindow()
        Refresh()
        C_Timer.After(0, function()
            if active and panel and panel:IsShown() then
                HideBlizzardPanels()
                SelectOurTab(true)
                DressWindow()
            end
        end)
    end)
    panel.driver = driver
    driver:SetScript("OnUpdate", function()
        if not active then return end
        local who = _G["LFGWhoListFrame"]
        if not who or not who:IsVisible() then return end
        if InCombatLockdown() and not (FriendsFrame and FriendsFrame:IsVisible()) then return end
        ns.OpenWhoList()
        HideBlizzardPanels()
    end)
end

local function BlizzardTabs()
    local tabs = {}
    for i = 1, 8 do
        local frame = _G["FriendsFrameTab" .. i]
        if frame then tabs[#tabs + 1] = frame end
    end
    return tabs
end

function SelectOurTab(on)
    if not tab then return end
    if on then
        if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
        for _, other in ipairs(BlizzardTabs()) do
            if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(other) end
        end
    else
        if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    end
    if ns.FitBottomTab then ns.FitBottomTab(tab) end
end

local finderTabs, finderToggle = {}, nil
local function FinderOpen() return ns.db and ns.db.whoTabs and true or false end

local function SyncFinderTabs()
    local open = FinderOpen()
    if open and ns.WarmGroupFinder then ns.WarmGroupFinder() end
    for _, side in ipairs(finderTabs) do
        side:SetShown(open)
        side:SetChecked(side.who and true or false)
    end
    if finderToggle and finderToggle.open ~= open then
        finderToggle.open = open
        local name = open and "PrevPage" or "NextPage"
        finderToggle:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-" .. name .. "-Up")
        finderToggle:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-" .. name .. "-Down")
    end
end

local function TurnFinderTo(index)
    local frame = _G["LFGParentFrame"]
    local turn = _G["LFGParentFrameTab" .. index .. "_OnClick"]
    if frame and frame:IsShown() and type(turn) == "function" and frame.selectedTab ~= index then turn() end
end

local function BuildFinderTabs(host)
    if finderToggle or not ns.NewSideTab then return end
    local FINDER = {
        { index = 1, icon = "Interface/Icons/INV_Helmet_08", text = _G.LFG_LIST_TAB_1 or "Create Listing" },
        { index = 2, icon = "Interface/Icons/Achievement_General_StayClassy", text = _G.LFG_LIST_TAB_2 or "Group Browser" },
        { who = true, icon = "Interface/Icons/INV_OwlDragonMount", text = _G.LFG_LIST_TAB_3 or WHO or "Who" },
    }
    for i, entry in ipairs(FINDER) do
        local side = ns.NewSideTab(panel, i, finderTabs[i - 1])
        if i == 1 then
            side:ClearAllPoints()
            side:SetPoint("TOPLEFT", host, "TOPRIGHT", -3, -58)
        end
        side:SetNormalTexture(entry.icon)
        side.tooltip = entry.text
        side.who = entry.who
        side:SetScript("OnClick", function(self)
            self:SetChecked(self.who and true or false)
            if self.who then return end
            if InCombatLockdown() then
                if UIErrorsFrame and ERR_NOT_IN_COMBAT then UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1) end
                return
            end
            PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
            local frame = _G["LFGParentFrame"]
            if frame and frame:IsShown() then
                TurnFinderTo(entry.index)
            else
                local show = _G["LFGVanilla_ShowFrame"]
                if type(show) == "function" then show(entry.index) end
            end
            if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
        end)
        finderTabs[i] = side
        if not entry.who and ns.MapPad and _G["LFDMicroButton"] then
            ns.MapPad(side, "HIGH", function()
                PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
                TurnFinderTo(entry.index)
                if FriendsFrame and FriendsFrame:IsShown() then ns.HidePanel(FriendsFrame) end
                C_Timer.After(0, function() TurnFinderTo(entry.index) end)
            end, _G["LFDMicroButton"], function()
                local frame = _G["LFGParentFrame"]
                return not (frame and frame:IsShown())
            end)
        end
    end
    finderToggle = CreateFrame("Button", "EraUIClassicWhoTabsToggle", panel)
    finderToggle:SetSize(24, 24)
    finderToggle:SetPoint("TOPRIGHT", host, "TOPRIGHT", -8, -28)
    finderToggle:SetFrameLevel(panel:GetFrameLevel() + 20)
    finderToggle:SetHighlightTexture("Interface/Buttons/UI-Common-MouseHilight", "ADD")
    finderToggle:SetScript("OnClick", function()
        ns.db.whoTabs = not FinderOpen()
        if ns.MirrorSave then ns.MirrorSave() end
        SyncFinderTabs()
    end)
    finderToggle:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(_G.LOOKING_FOR_GROUP or _G.GROUP_FINDER or "Group Finder")
        GameTooltip:Show()
    end)
    finderToggle:SetScript("OnLeave", function() GameTooltip:Hide() end)
    SyncFinderTabs()
end

local function ShowWho()
    if not panel then return end
    BuildFinderTabs(FriendsFrame)
    SyncFinderTabs()
    if ns.HideGuildRoster then ns.HideGuildRoster() end
    HideBlizzardPanels()
    panel:Show()
    SelectOurTab(true)
    DressWindow()
    Refresh()
end
ns.ShowWhoList = ShowWho

local function HideWho()
    if not panel then return end
    HideRowMenu()
    panel:Hide()
    SelectOurTab(false)
    ShowBlizzardPanels()
    if ns.RestoreFriendsTitle then ns.RestoreFriendsTitle() end
end
ns.HideWhoList = HideWho

function ns.OpenWhoList()
    if not active or not FriendsFrame then return false end
    if not panel then Build() end
    if not ns.ShowPanel(FriendsFrame) then return false end
    ShowWho()
    return true
end

-- The friends key on Forever. With the game's newer social window switched on
-- (C_SocialUI), every way into the friends list opens that window instead:
-- the friends key, /friends, /ignore, the chat friends button, a friend
-- request toast, the guild key's /friends. While this option is on those show
-- this classic window on its Friends list, and the same key closes it again.
-- Raid, Quick Join and Recruit A Friend only exist in the newer window while
-- it is on, so those requests are left to it.
-- Post-hooks only: by the time they run the game has opened its window, and it
-- is closed again before the next frame is drawn. Windows change only through
-- ns.ShowPanel and ns.HidePanel (the game's panel manager runs those as its
-- own); none of the game's openers, tabs or clicks are run from here. The game
-- refuses an addon's window changes in a fight, so a request made there keeps
-- the game's window and it turns into the classic one when the fight ends.
local socialHooked = {}
local friendsHiddenAt, ignoreHiddenAt, closedAt
local waiting, waitingTab = false, nil

local function SocialSystemOn()
    local api = C_SocialUI
    if not (api and api.IsSystemEnabled) then return false end
    local ok, on = pcall(api.IsSystemEnabled)
    return ok and on == true
end

local function Redirecting()
    if not active or not FriendsFrame or not SocialUIFrame then return false end
    if EraUI.GetSetting and EraUI:GetSetting("enabled") == false then return false end
    return SocialSystemOn()
end

-- One reading from one of the game's frames, nil when it can't answer.
local function Ask(frame, method)
    local fn = frame and frame[method]
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, frame)
    if ok then return value end
end

-- The newer window's pages this window shows: friends, and friend requests
-- (they head the classic friends list).
local function FriendsPage(tabType)
    local types = SocialUITabType
    return tabType ~= nil and types ~= nil and (tabType == types.Friends or tabType == types.FriendRequests)
end

local function WantsIgnoreList(social)
    local sides = SocialUISideWindowType
    local side = Ask(social, "GetActiveSideWindowType")
    return sides ~= nil and side ~= nil and side == sides.IgnoreListFrame
end

local function GuildPageShown()
    local guild = _G["EraUIClassicGuildPanel"]
    return guild and guild:IsShown() and true or false
end

-- Open already on the Who or Guild page: back to Friends, as its tab does.
-- Our own pages step aside; the game's tab is never clicked from here, since
-- its click would run the game's tab code as EraUI's.
local function ShowFriendsPage()
    local whoUp, guildUp = panel and panel:IsShown(), GuildPageShown()
    if not (whoUp or guildUp) then return end
    if whoUp then HideWho() end
    if guildUp and ns.HideGuildRoster then ns.HideGuildRoster() end
    local first = _G["FriendsFrameTab1"]
    if first and PanelTemplates_SelectTab then PanelTemplates_SelectTab(first) end
    if first and ns.FitBottomTab then ns.FitBottomTab(first) end
end

local function ShowClassicFriends(ignore)
    if FriendsFrame:IsShown() then
        if not ignore then ShowFriendsPage() end
    elseif not ns.ShowPanel(FriendsFrame) then
        return
    end
    -- The ignore list is a plain child of this window (display only).
    local list = ignore and FriendsFrame.IgnoreListWindow
    if list and not list:IsShown() then list:Show() end
end

-- mode "toggle": asked again while this window is open, it closes; "open":
-- it stays. anyTab: the request was for the friends list whichever page the
-- newer window remembered; otherwise only its friends pages come over here.
local function Redirect(mode, anyTab)
    if not Redirecting() then return end
    local social = SocialUIFrame
    if not social:IsShown() then
        -- A hook further in has dealt with it. If that was a toggle closing
        -- this window and the request is an open, it opens again.
        if mode == "open" and closedAt and closedAt == GetTime() and not InCombatLockdown() then
            closedAt = nil
            ShowClassicFriends(false)
        end
        return
    end
    local tabType = Ask(social, "GetSelectedTab")
    if not anyTab and not FriendsPage(tabType) then return end
    if InCombatLockdown() then
        waiting, waitingTab = true, tabType
        return
    end
    waiting, waitingTab = false, nil
    local ignore = WantsIgnoreList(social)
    -- The game's window can take this one's place as it opens: hidden in this
    -- same frame still counts as open.
    local wasOpen = FriendsFrame:IsShown() or friendsHiddenAt == GetTime()
    ns.HidePanel(social)
    if mode == "toggle" and wasOpen then
        local list = FriendsFrame.IgnoreListWindow
        local listWasUp = list and (list:IsShown() or (not FriendsFrame:IsShown() and ignoreHiddenAt == GetTime()))
        if ignore and list and not listWasUp then
            -- /ignore with the friends list open shows its ignore list, as before.
            ShowClassicFriends(true)
            return
        end
        ns.HidePanel(FriendsFrame)
        closedAt = GetTime()
        return
    end
    ShowClassicFriends(ignore)
end

-- The game hides this window's Friends tab while the newer window is on; it
-- stays, so the Who and Guild pages lead back to it. The Recent Allies and
-- Recruit A Friend tabs at the top stay as the game has them (an empty page
-- while the newer window is on): opening the newer window from here would run
-- the game's opener as EraUI, taint the page it remembers, and the game would
-- then refuse its own Raid and Quick Join opens in a fight.
local function KeepFriendsTab()
    if not Redirecting() then return end
    local first = _G["FriendsFrameTab1"]
    if first and not first:IsShown() then first:Show() end
end

local function HookSocialEntries()
    if not socialHooked.friendsFrame and FriendsFrame then
        socialHooked.friendsFrame = true
        FriendsFrame:HookScript("OnHide", function() friendsHiddenAt = GetTime() end)
        local list = FriendsFrame.IgnoreListWindow
        if list and list.HookScript then list:HookScript("OnHide", function() ignoreHiddenAt = GetTime() end) end
        if type(FriendsFrame_Update) == "function" then hooksecurefunc("FriendsFrame_Update", KeepFriendsTab) end
    end
    local function Global(name, hook)
        if socialHooked[name] or type(_G[name]) ~= "function" then return end
        socialHooked[name] = true
        hooksecurefunc(name, hook)
    end
    local friendsTab = FRIEND_TAB_FRIENDS or 1
    Global("ToggleFriendsFrame", function(tab)
        if tab == nil or tab == friendsTab then Redirect("toggle", true) end
    end)
    Global("ToggleFriendsPanel", function() Redirect("toggle", true) end)
    Global("ToggleIgnorePanel", function() Redirect("toggle", true) end)
    Global("OpenFriendsFrame", function(tab)
        if tab == nil or tab == friendsTab then Redirect("open", true) end
    end)
    -- Every way the game opens its window runs SocialUIControl.Toggle, whatever
    -- asked; a request for one of its pages has picked that page by then.
    local control = SocialUIControl
    if type(control) == "table" then
        if not socialHooked.toggle and type(control.Toggle) == "function" then
            socialHooked.toggle = true
            hooksecurefunc(control, "Toggle", function() Redirect("toggle", false) end)
        end
        if not socialHooked.openToTab and type(control.OpenToTab) == "function" then
            socialHooked.openToTab = true
            hooksecurefunc(control, "OpenToTab", function() Redirect("open", false) end)
        end
    end
    -- Anything else that opens it on a friends page: a frame later.
    local social = SocialUIFrame
    if not socialHooked.socialFrame and social and social.HookScript then
        socialHooked.socialFrame = true
        social:HookScript("OnShow", function()
            if Redirecting() and C_Timer and C_Timer.After then
                C_Timer.After(0, function() Redirect("open", false) end)
            end
        end)
    end
end

local socialWatch = CreateFrame("Frame")
socialWatch:RegisterEvent("ADDON_LOADED")
socialWatch:RegisterEvent("PLAYER_REGEN_ENABLED")
socialWatch:SetScript("OnEvent", function(_, event)
    if event == "ADDON_LOADED" then
        if active then HookSocialEntries() end
        return
    end
    -- After a fight: a friends request made in it, if the game's window still
    -- shows the page it opened on.
    local social = SocialUIFrame
    if waiting then
        local tabType = waitingTab
        waiting, waitingTab = false, nil
        if Redirecting() and social and social:IsShown() and Ask(social, "GetSelectedTab") == tabType then
            Redirect("open", true)
        end
    end
end)

local tabGap
local SOCIAL_TAB_PAD = 38
local function PlaceRow()
    local blizzard = BlizzardTabs()
    if not tabGap then
        local first, second
        for _, other in ipairs(blizzard) do
            if other:IsShown() then
                if not first then first = other elseif not second then second = other end
            end
        end
        if first and second and first:GetRight() and second:GetLeft() then
            tabGap = second:GetLeft() - first:GetRight()
        else
            tabGap = -14
        end
    end
    local order = {}
    if blizzard[1] then order[#order + 1] = blizzard[1] end
    if tab then order[#order + 1] = tab end
    local guildTab = _G["EraUIClassicGuildTab"]
    if guildTab then order[#order + 1] = guildTab end
    local communitiesTab = _G["EraUIClassicCommunitiesTab"]
    if communitiesTab then order[#order + 1] = communitiesTab end
    for i = 2, #blizzard do
        if blizzard[i] then order[#order + 1] = blizzard[i] end
    end
    for _, entry in ipairs(order) do
        if entry.fcuiPad ~= SOCIAL_TAB_PAD then
            entry.fcuiPad = SOCIAL_TAB_PAD
            if ns.FitBottomTab then ns.FitBottomTab(entry) end
        end
    end
    local previous
    for _, entry in ipairs(order) do
        if entry:IsShown() then
            entry:ClearAllPoints()
            if previous then
                entry:SetPoint("LEFT", previous, "RIGHT", tabGap, 0)
                entry:SetPoint("BOTTOM", previous, "BOTTOM", 0, 0)
            else
                entry:SetPoint("TOPLEFT", FriendsFrame, "BOTTOMLEFT", 5, 2)
            end
            previous = entry
        end
    end
end
ns.PlaceSocialTabs = PlaceRow

local function BuildTab()
    local host = FriendsFrame
    if not host or tab then return end
    tab = CreateFrame("Button", "EraUIClassicWhoTab", host, "PanelTabButtonTemplate")
    tab:SetID(91)
    tab:SetText(WHO or "Who")
    if ns.SkinBottomTab then ns.SkinBottomTab(tab) end
    SelectOurTab(false)
    tab:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
        ShowWho()
    end)
    for _, other in ipairs(BlizzardTabs()) do
        other:HookScript("OnClick", function() if active then HideWho() end end)
    end
    if type(FriendsFrame_ShowSubFrame) == "function" then
        hooksecurefunc("FriendsFrame_ShowSubFrame", function()
            if active and panel and panel:IsShown() then
                HideBlizzardPanels()
                SelectOurTab(true)
                DressWindow()
            end
        end)
    end
    if type(FriendsFrame_Update) == "function" then
        hooksecurefunc("FriendsFrame_Update", function()
            if active and panel and panel:IsShown() then
                HideBlizzardPanels()
                SelectOurTab(true)
                DressWindow()
            end
        end)
    end
    host:HookScript("OnShow", function() if active then PlaceRow() end end)
    host:HookScript("OnHide", function() if panel then HideWho() end end)
end

local function RenameFirstTab()
    local first = _G["FriendsFrameTab1"]
    if not first or not first.SetText then return end
    first:SetText(FRIENDS or "Friends")
    if ns.FitBottomTab then ns.FitBottomTab(first) end
end

local function Apply()
    active = true
    if not FriendsFrame then ns.MissingPiece("FriendsFrame") return end
    if not panel then Build() end
    BuildTab()
    RenameFirstTab()
    HookSocialEntries()
    if tab then tab:Show() end
    PlaceRow()
end

local function Restore()
    active = false
    HideWho()
    if tab then tab:Hide() end
end

ns.RegisterModule("whoList", { apply = Apply, restore = Restore })
