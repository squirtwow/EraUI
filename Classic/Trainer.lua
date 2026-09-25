-- EraUI trainer window.
-- The trainer's window as the old one: the greeting under the title, the All
-- tab and the filter, the list of what the trainer teaches under its headers
-- (green for what can be learned now, red for what cannot yet, gray for what
-- is known), the chosen service below with what it needs and what it costs,
-- and your money, Train and Exit along the foot.
local _, EraUI = ...
local ns = EraUI.Classic

local active = false
local panel
local ROW_H, LIST_ROWS = 16, 9
local lines, collapsed = {}, {}
local selected

local KIND_COLOR = {
    available = { 0.1, 1, 0.1 },
    unavailable = { 1, 0.1, 0.1 },
    used = { 0.5, 0.5, 0.5 },
}
local HEADER_COLOR = { 1, 0.82, 0 }
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"

local CLIENT_PIECES = { "FilterDropdown", "FilterInputHint", "TrainButton", "trainingPoints", "skillStepButton",
    "bottomInset", "BG", "Inset" }
local CLIENT_SHRUNK = { "ScrollBox", "ScrollBar" }

local function Services()
    local count = GetNumTrainerServices and GetNumTrainerServices() or 0
    local order, groups = {}, {}
    for index = 1, count do
        local name, kind, texture, level, sub, category = GetTrainerServiceInfo(index)
        if name then
            if not category or category == "" then category = OTHER or "Other" end
            if not groups[category] then
                groups[category] = {}
                order[#order + 1] = category
            end
            local group = groups[category]
            group[#group + 1] = { index = index, name = name, kind = kind, texture = texture, level = level, sub = sub }
        end
    end
    return order, groups
end

local function Collect()
    wipe(lines)
    local order, groups = Services()
    for _, category in ipairs(order) do
        lines[#lines + 1] = { header = true, id = category, name = category }
        if not collapsed[category] then
            for _, service in ipairs(groups[category]) do lines[#lines + 1] = service end
        end
    end
end

local function ServiceByIndex(index)
    for _, line in ipairs(lines) do
        if not line.header and line.index == index then return line end
    end
end

local function AllCollapsed()
    local any = false
    for _, line in ipairs(lines) do
        if line.header then
            any = true
            if not collapsed[line.id] then return false end
        end
    end
    return any
end

local UpdateDetail

local function FitList()
    local over = math.max(0, #lines - LIST_ROWS)
    panel.bar:SetRange(over)
    panel.listBox:SetPoint("RIGHT", panel, "RIGHT", over > 0 and -15 or 0, 0)
end

local function UpdateRows()
    if not panel then return end
    local offset = math.floor((panel.bar:GetValue() or 0) + 0.5)
    for i, row in ipairs(panel.rows) do
        local line = lines[offset + i]
        row.line = line
        if not line then
            row:Hide()
        else
            row:Show()
            if line.header then
                row.toggle:SetTexture(collapsed[line.id] and PLUS or MINUS)
                row.toggle:Show()
                row.text:SetPoint("LEFT", row, "LEFT", 21, 0)
                row.text:SetText(line.name)
                row.text:SetTextColor(unpack(HEADER_COLOR))
                row.selectedTex:Hide()
            else
                row.toggle:Hide()
                row.text:SetPoint("LEFT", row, "LEFT", 33, 0)
                local label = line.name
                if line.sub and line.sub ~= "" then label = label .. " (" .. line.sub .. ")" end
                row.text:SetText(label)
                local color = KIND_COLOR[line.kind] or KIND_COLOR.used
                if line.index == selected then
                    row.selectedTex:SetVertexColor(unpack(color))
                    row.selectedTex:Show()
                    row.text:SetTextColor(1, 1, 1)
                else
                    row.selectedTex:Hide()
                    row.text:SetTextColor(unpack(color))
                end
            end
        end
    end
    panel.collapseAll.icon:SetTexture(AllCollapsed() and PLUS or MINUS)
end

local function Select(index)
    selected = index
    if index and SelectTrainerService then pcall(SelectTrainerService, index) end
    UpdateRows()
    UpdateDetail()
end

local function Row_OnClick(self)
    local line = self.line
    if not line then return end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    if line.header then
        collapsed[line.id] = (not collapsed[line.id]) or nil
        panel.refresh()
    else
        Select(line.index)
    end
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp")
    local sel = row:CreateTexture(nil, "BACKGROUND")
    sel:SetAllPoints(row)
    sel:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    sel:Hide()
    row.selectedTex = sel
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(0.25)
    local toggle = row:CreateTexture(nil, "ARTWORK")
    toggle:SetSize(14, 14)
    toggle:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.toggle = toggle
    local text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    row.text = text
    row:SetScript("OnClick", Row_OnClick)
    return row
end

local function Coins(amount)
    if C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString then return C_CurrencyInfo.GetCoinTextureString(amount) end
    if GetCoinTextureString then return GetCoinTextureString(amount) end
    if GetMoneyString then return GetMoneyString(amount) end
    return tostring(amount)
end

local function Requirements(line)
    local parts = {}
    local WHITE, RED = "|cffffffff", "|cffff2020"
    local function Plain(text)
        return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end
    local function Add(text, met)
        text = Plain(text)
        if not met then
            text = text:gsub("(%d+)", RED .. "%1|r" .. WHITE, 1)
        end
        parts[#parts + 1] = WHITE .. text .. "|r"
    end
    if line.level and line.level > 1 then
        Add(string.format(TRAINER_REQ_LEVEL or "Level %d", line.level), (UnitLevel("player") or 0) >= line.level)
    end
    if GetTrainerServiceSkillReq then
        local ok, skill, rank, has = pcall(GetTrainerServiceSkillReq, line.index)
        if ok and skill and rank and rank > 0 then
            Add(string.format(TRAINER_REQ_SKILL_RANK or "%s (%d)", skill, rank), has and true or false)
        end
    end
    if GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq then
        local okCount, count = pcall(GetTrainerServiceNumAbilityReq, line.index)
        for i = 1, (okCount and count or 0) do
            local ok, ability, has = pcall(GetTrainerServiceAbilityReq, line.index, i)
            if ok and ability then
                parts[#parts + 1] = ((has and WHITE) or RED) .. Plain(ability) .. "|r"
            end
        end
    end
    return table.concat(parts, ", ")
end

UpdateDetail = function()
    if not panel then return end
    local detail = panel.detail
    local line = selected and ServiceByIndex(selected)
    local money = GetMoney and GetMoney() or 0
    if not line then
        detail.iconButton:Hide()
        detail.name:SetText("")
        detail.sub:SetText("")
        detail.requires:SetText("")
        detail.cost:SetText("")
        detail.text:SetText("")
        panel.train:Disable()
        return
    end
    detail.iconButton:Show()
    detail.icon:SetTexture(line.texture)
    detail.name:SetText(line.name)
    detail.sub:SetText((line.sub and line.sub ~= "") and ("(" .. line.sub .. ")") or "")
    local needs = Requirements(line)
    detail.requires:SetText(needs ~= "" and ((REQUIRES_LABEL or "Requires:") .. " " .. needs) or "")
    local cost = 0
    if GetTrainerServiceCost then
        local ok, value = pcall(GetTrainerServiceCost, line.index)
        if ok and type(value) == "number" then cost = value end
    end
    if cost > 0 then
        local coins = Coins(cost)
        detail.cost:SetText((COSTS_LABEL or "Cost:") .. " " .. (cost > money and "|cffff2020" or "|cffffffff") .. coins .. "|r")
    else
        detail.cost:SetText("")
    end
    local words = ""
    if GetTrainerServiceDescription then
        local ok, text = pcall(GetTrainerServiceDescription, line.index)
        if ok and type(text) == "string" then words = text end
    end
    detail.text:SetText(words)
    panel.train:SetEnabled(line.kind == "available" and cost <= money)
end

local function Refresh()
    if not panel or not active then return end
    Collect()
    FitList()
    if not (selected and ServiceByIndex(selected)) then
        selected = nil
        for _, line in ipairs(lines) do
            if not line.header and line.kind == "available" then selected = line.index break end
        end
        if not selected then
            for _, line in ipairs(lines) do
                if not line.header then selected = line.index break end
            end
        end
        if selected and SelectTrainerService then pcall(SelectTrainerService, selected) end
    end
    local greeting = GetTrainerGreetingText and GetTrainerGreetingText() or ""
    panel.greeting:SetText(greeting or "")
    UpdateRows()
    UpdateDetail()
end

local function HideClientPieces(hide)
    local host = ClassTrainerFrame
    if not host then return end
    for _, key in ipairs(CLIENT_PIECES) do
        local piece = host[key]
        if piece and piece.SetAlpha then piece:SetAlpha(hide and 0 or 1) end
    end
    if ClassTrainerStatusBar then ClassTrainerStatusBar:SetAlpha(hide and 0 or 1) end
    local floor = host.fcui and host.fcui.insetFloor
    if floor then floor:SetAlpha(hide and 0 or 1) end
    local oval = _G["ClassTrainerFrameMoneyBg"]
    if oval then
        oval:ClearAllPoints()
        oval:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", hide and 4 or 5, hide and -3 or -9)
        oval:SetAlpha(hide and 0 or 1)
        if hide and panel and panel.oval then
            local width = panel.oval:GetWidth()
            if width and width > 0 then oval:SetWidth(width) end
        elseif not hide then
            oval:SetWidth(148)
        end
    end
    if host.money and panel then
        host.money:SetFrameLevel(panel:GetFrameLevel() + (hide and 8 or 0))
    end
    for _, key in ipairs(CLIENT_SHRUNK) do
        local piece = host[key]
        if piece and piece.SetScale then
            piece:SetScale(hide and 0.01 or 1)
            piece:SetAlpha(hide and 0 or 1)
        end
    end
end

local function Build()
    local host = ClassTrainerFrame
    if panel or not host then return panel end
    local hideClient = HideClientPieces
    panel = CreateFrame("Frame", "EraUIClassicTrainer", host)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    panel:SetFrameLevel(host:GetFrameLevel() + 120)
    panel:EnableMouse(true)

    local words = CreateFrame("Frame", nil, panel)
    words:SetAllPoints(panel)
    words:SetFrameLevel(panel:GetFrameLevel() + 3)
    panel.greeting = words:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.greeting:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -30)
    panel.greeting:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    panel.greeting:SetHeight(36)
    panel.greeting:SetJustifyH("LEFT")
    panel.greeting:SetJustifyV("TOP")

    ns.OldSkillShell(panel, { rows = LIST_ROWS, createRow = CreateRow, onScroll = function() UpdateRows() end })
    local gap = CreateFrame("Frame", nil, panel)
    gap:SetFrameLevel(panel:GetFrameLevel() + 1)
    gap:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -50)
    gap:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    gap:SetPoint("BOTTOM", panel.listBox, "TOP", 0, -8)
    local gapStone = gap:CreateTexture(nil, "BACKGROUND")
    gapStone:SetAllPoints(gap)
    gapStone:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
    gapStone:SetHorizTile(true)
    gapStone:SetVertTile(true)
    ns.ThemeTexture(gapStone, "rockBg")
    panel.collapseAll:SetScript("OnClick", function()
        local fold = not AllCollapsed()
        for _, line in ipairs(lines) do
            if line.header then collapsed[line.id] = fold or nil end
        end
        panel.refresh()
    end)
    panel.filter:SetScript("OnClick", function(self)
        if not panel.filterList then
            local function Item(label, kind)
                return { label, function()
                    local on = GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind)
                    if SetTrainerServiceTypeFilter then SetTrainerServiceTypeFilter(kind, not on) end
                    Refresh()
                end, function() return GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind) and true or false end }
            end
            panel.filterList = ns.DropList({
                Item(AVAILABLE or "Available", "available"),
                Item(UNAVAILABLE or "Unavailable", "unavailable"),
                Item(USED or "Already Known", "used"),
            })
            panel.filterList:Follow(panel)
        end
        panel.filterList:Toggle(self)
    end)

    local detail = panel.detail
    local iconButton = CreateFrame("Button", nil, detail)
    iconButton:SetSize(37, 37)
    iconButton:SetPoint("TOPLEFT", detail, "TOPLEFT", 20, -18)
    detail.iconButton = iconButton
    detail.icon = iconButton:CreateTexture(nil, "ARTWORK")
    detail.icon:SetAllPoints(iconButton)
    iconButton:SetScript("OnEnter", function(self)
        if not selected or not GameTooltip.SetTrainerService then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(GameTooltip.SetTrainerService, GameTooltip, selected)
        GameTooltip:Show()
    end)
    iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    detail.name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detail.name:SetPoint("TOPLEFT", iconButton, "TOPRIGHT", 8, -2)
    detail.name:SetJustifyH("LEFT")
    detail.sub = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.sub:SetPoint("LEFT", detail.name, "RIGHT", 4, 0)
    detail.requires = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.requires:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -3)
    detail.requires:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    detail.requires:SetJustifyH("LEFT")
    detail.cost = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    detail.cost:SetPoint("TOPLEFT", detail, "TOPLEFT", 21, -62)
    detail.cost:SetJustifyH("LEFT")
    detail.text = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.text:SetPoint("TOPLEFT", detail.cost, "BOTTOMLEFT", 0, -6)
    detail.text:SetPoint("RIGHT", detail, "RIGHT", -16, 0)
    detail.text:SetJustifyH("LEFT")
    detail.text:SetJustifyV("TOP")

    local exit = ns.PanelButton(panel, EXIT or "Exit", 84)
    exit:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 11)
    exit:SetScript("OnClick", function()
        if HideUIPanel and ClassTrainerFrame then HideUIPanel(ClassTrainerFrame) end
    end)
    local train = ns.PanelButton(panel, TRAIN or "Train", 84)
    train:SetPoint("RIGHT", exit, "LEFT", -3, 0)
    train:SetScript("OnClick", function()
        if selected and BuyTrainerService then BuyTrainerService(selected) end
    end)
    panel.train = train
    local moneyBox = ns.SkillInsetBox(panel, 16, true)
    moneyBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 4)
    moneyBox:SetPoint("RIGHT", train, "LEFT", 1, 0)
    moneyBox:SetHeight(32)
    for _, button in ipairs({ train, exit }) do
        local box = ns.SkillInsetBox(panel, 16, true)
        box:SetPoint("TOP", moneyBox, "TOP", 0, 0)
        box:SetPoint("BOTTOM", moneyBox, "BOTTOM", 0, 0)
        box:SetPoint("LEFT", button, "LEFT", -4, 0)
        box:SetPoint("RIGHT", button, "RIGHT", 4, 0)
        box:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    end
    local oval = panel:CreateTexture(nil, "ARTWORK")
    oval:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame-Border")
    oval:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, -3)
    oval:SetPoint("RIGHT", train, "LEFT", -5, 0)
    oval:SetHeight(34)
    panel.oval = oval
    panel.detailBox:ClearAllPoints()
    panel.detailBox:SetPoint("TOPLEFT", panel.listBox, "BOTTOMLEFT", 0, 12)
    panel.detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 25)
    panel.footBox:ClearAllPoints()
    panel.footBox:SetPoint("TOPLEFT", panel.detailBox, "BOTTOMLEFT", 0, 11)
    panel.footBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2)
    panel.footBox:SetFrameLevel(panel.detailBox:GetFrameLevel() + 1)
    for _, key in ipairs({ "TopEdge", "TopLeftCorner", "TopRightCorner" }) do
        if panel.footBox[key] then panel.footBox[key]:SetAlpha(0) end
    end

    panel.bar.hideWhenIdle = true
    panel.refresh = Refresh
    panel.hideClient = hideClient
    panel:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.2 then return end
        self.since = 0
        if active then panel.hideClient(true) end
    end)
    panel:SetScript("OnShow", Refresh)
    return panel
end

local function Open()
    if not active or not ClassTrainerFrame then return end
    Build()
    HideClientPieces(true)
    panel:Show()
    Refresh()
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if not active then return end
    if event == "TRAINER_CLOSED" then
        selected = nil
        return
    end
    if event == "PLAYER_MONEY" then
        if panel and panel:IsVisible() then UpdateDetail() end
        return
    end
    Open()
end)

local function Apply()
    active = true
    for _, event in ipairs({ "TRAINER_SHOW", "TRAINER_UPDATE", "TRAINER_CLOSED", "TRAINER_DESCRIPTION_UPDATE",
        "TRAINER_SERVICE_INFO_NAME_UPDATE", "PLAYER_MONEY" }) do
        pcall(events.RegisterEvent, events, event)
    end
    if ClassTrainerFrame and ClassTrainerFrame:IsShown() then Open() end
end

local function Restore()
    active = false
    events:UnregisterAllEvents()
    if panel then panel:Hide() end
    HideClientPieces(false)
end

ns.RegisterModule("trainer", { apply = Apply, restore = Restore })
