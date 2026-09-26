-- Classic trainer layout over the client's real training controls. Compact
-- rows forward hardware clicks securely to Blizzard's own pooled buttons;
-- neither selection fields nor the purchase handler are written/called here.
local _, EraUI = ...
local ns = EraUI.Classic
local active, hooked, refreshing, queued, routesValid = false, false, false, false, false
local panel, bridge
local ROW_H, LIST_ROWS = 16, 9
local lines, collapsed, nativeRows, nativeCategories, saved = {}, {}, {}, {}, {}
local PLUS = "Interface\\Buttons\\UI-PlusButton-Up"
local MINUS = "Interface\\Buttons\\UI-MinusButton-Up"
local COLORS = { available = { .1, 1, .1 }, unavailable = { 1, .1, .1 }, used = { .5, .5, .5 } }
local Refresh, UpdateRows
local history, phase, lastRefresh = {}, "not refreshed", {}

local function ReadServiceCount()
    if not GetNumTrainerServices then return "unavailable" end
    local ok, count = pcall(GetNumTrainerServices)
    return ok and count or "unavailable"
end

local function Record(event)
    history[#history + 1] = event .. ": services=" .. tostring(ReadServiceCount())
    if #history > 10 then table.remove(history, 1) end
end

local function Remember(frame)
    if not frame or saved[frame] then return end
    local keep = { alpha = frame:GetAlpha() }
    if frame.GetFrameLevel then
        keep.level, keep.scale = frame:GetFrameLevel(), frame:GetScale()
        keep.width, keep.height, keep.points = frame:GetWidth(), frame:GetHeight(), {}
        for i = 1, frame:GetNumPoints() do keep.points[i] = { frame:GetPoint(i) } end
    end
    saved[frame] = keep
end

local function Fade(frame)
    if frame then Remember(frame); frame:SetAlpha(0) end
end

local function PetTrainer()
    return C_Trainer.GetTrainerType() == Enum.TrainerType.Pet
end

local function Selection()
    local host = ClassTrainerFrame
    local index = host and host.selectedService
    return index and ((host.displayIndexToSkillIndex and host.displayIndexToSkillIndex[index]) or index)
end

local function Queue()
    if not active or refreshing then return end
    -- A native refresh can recycle buttons before the next render pass. Clear
    -- old routes immediately rather than leave a stale service clickable.
    if panel and routesValid and not InCombatLockdown() then
        for _, row in ipairs(panel.rows) do
            row:SetAttribute("type1", nil)
            row:SetAttribute("clickbutton", nil)
        end
        routesValid = false
    end
    if queued then return end
    queued = true
    C_Timer.After(0, function()
        queued = false
        if active and not InCombatLockdown() and ClassTrainerFrame and ClassTrainerFrame:IsShown() then Refresh() end
    end)
end

-- Changing a virtualized list's height can initialize pooled buttons. Do this
-- in restricted execution, so their native displayIndex/data is not written
-- by an addon-context initializer. The invisible viewport materializes all
-- services, including those beyond the compact list's current scroll page.
local function NativeViewport(height, scale)
    bridge:SetAttribute("height", height)
    bridge:SetAttribute("scale", scale)
    bridge:Execute([[
        local box = self:GetFrameRef("list")
        local height, scale = self:GetAttribute("height"), self:GetAttribute("scale")
        if box:GetScale() ~= scale then box:SetScale(scale) end
        if box:GetHeight() ~= height then box:SetHeight(height) end
    ]])
end

local function Bind(row, target)
    row:SetAttribute("type1", target and "click" or nil)
    row:SetAttribute("clickbutton", target)
end

local function AllCollapsed()
    local any = false
    for _, line in ipairs(lines) do
        if line.header then
            any = true
            if not line.closed then return false end
        end
    end
    return any
end

local function Collect()
    wipe(nativeRows); wipe(nativeCategories); wipe(lines)
    local host = ClassTrainerFrame
    host.ScrollBox:ForEachFrame(function(button)
        local node = button:GetElementData()
        local data = node and (node.data or node)
        if data and data.skillIndex then
            nativeRows[data.skillIndex] = button
        elseif data and data.categoryInfo then
            nativeCategories[data.categoryInfo.name] = { button = button, closed = node:IsCollapsed() }
        end
    end)
    local step = GetTrainerServiceStepIndex and GetTrainerServiceStepIndex()
    if step and host.skillStepButton then nativeRows[step] = host.skillStepButton end
    local order, groups = {}, {}
    for index = 1, GetNumTrainerServices() do
        local name, kind, icon, level, rank, category = GetTrainerServiceInfo(index)
        if name then
            if not category or category == "" then category = OTHER or "Other" end
            if not groups[category] then groups[category] = {}; order[#order + 1] = category end
            local group = groups[category]
            group[#group + 1] = { index = index, name = name, kind = kind, icon = icon, level = level, rank = rank }
        end
    end
    for _, category in ipairs(order) do
        local native = nativeCategories[category]
        local closed = collapsed[category] or (native and native.closed)
        lines[#lines + 1] = { header = true, name = category, closed = closed, native = native }
        if not closed then
            for _, service in ipairs(groups[category]) do lines[#lines + 1] = service end
        end
    end
end

UpdateRows = function()
    if not panel or InCombatLockdown() then return end
    local offset = math.floor((panel.bar:GetValue() or 0) + .5)
    local selected = Selection()
    for i, row in ipairs(panel.rows) do
        local line = lines[offset + i]
        row.line = line
        Bind(row, nil)
        if not line then row:Hide()
        else
            row:Show()
            row.text:ClearAllPoints()
            row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.text:SetPoint("LEFT", row, "LEFT", line.header and 21 or 33, 0)
            row.selectedTex:Hide()
            if line.header then
                row.toggle:SetTexture(line.closed and PLUS or MINUS)
                row.toggle:Show()
                row.text:SetText(line.name)
                row.text:SetTextColor(1, .82, 0)
                -- Reopen a category collapsed by the native UI through its
                -- actual category button, never through an addon Lua call.
                if line.native and line.native.closed then Bind(row, line.native.button) end
            else
                row.toggle:Hide()
                row.text:SetText(line.name .. ((line.rank and line.rank ~= "") and (" (" .. line.rank .. ")") or ""))
                local color = COLORS[line.kind] or COLORS.used
                row.text:SetTextColor(unpack(color))
                if line.index == selected then
                    row.selectedTex:SetVertexColor(unpack(color))
                    row.selectedTex:Show()
                    row.text:SetTextColor(1, 1, 1)
                end
                -- No fallback to an insecure selection call if a native row
                -- has not materialized yet. A subsequent native update binds it.
                Bind(row, nativeRows[line.index])
            end
        end
    end
    panel.collapseAll.icon:SetTexture(AllCollapsed() and PLUS or MINUS)
    if #lines == 0 then
        local count = GetNumTrainerServices()
        panel.empty:SetText(count > 0 and "Loading abilities..." or "No abilities match the current filters.")
        panel.empty:Show()
    else
        panel.empty:Hide()
    end
    routesValid = true
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate")
    row:SetHeight(ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -(index - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -(index - 1) * ROW_H)
    row:SetAttribute("useOnKeyDown", false)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row.selectedTex = row:CreateTexture(nil, "BACKGROUND")
    row.selectedTex:SetAllPoints(row)
    row.selectedTex:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
    highlight:SetBlendMode("ADD")
    highlight:SetAlpha(.25)
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(14, 14)
    row.toggle:SetPoint("LEFT", row, "LEFT", 3, 0)
    row.text = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)
    row:SetScript("PostClick", function(self, button, down)
        if down or button ~= "LeftButton" or InCombatLockdown() then return end
        local line = self.line
        if line and line.header then
            if line.native and line.native.closed then collapsed[line.name] = nil
            else collapsed[line.name] = not collapsed[line.name] or nil end
        end
        Queue()
    end)
    return row
end

local function Requirements(index, level)
    local parts = {}
    local function Add(text, met)
        parts[#parts + 1] = (met and "|cffffffff" or "|cffff2020") .. text .. "|r"
    end
    if level and level > 1 then
        Add(string.format(TRAINER_REQ_LEVEL or "Level %d", level), (UnitLevel(PetTrainer() and "pet" or "player") or 0) >= level)
    end
    local skill, rank, has = GetTrainerServiceSkillReq(index)
    if skill and rank then Add(string.format(TRAINER_REQ_SKILL_RANK or "%s (%d)", skill, rank), has) end
    for i = 1, GetTrainerServiceNumAbilityReq(index) do
        local ability, met = GetTrainerServiceAbilityReq(index, i)
        if ability then Add(ability, met) end
    end
    return table.concat(parts, ", ")
end

local function UpdateDetail()
    local detail, selected = panel.detail, Selection()
    local name, kind, icon, level, rank
    if selected then name, kind, icon, level, rank = GetTrainerServiceInfo(selected) end
    panel.train:SetEnabled(ClassTrainerFrame.TrainButton:IsEnabled())
    local pet = PetTrainer()
    panel.points:SetShown(pet)
    if pet then
        local total, used = C_PetInfo.GetPetTrainingPoints()
        panel.points:SetFormattedText(TRAINING_POINTS or "Training Points: %d", math.max(total - used, 0))
    end
    detail.iconButton:SetShown(name ~= nil)
    detail.name:SetText(name or "")
    detail.sub:SetText((rank and rank ~= "") and ("(" .. rank .. ")") or "")
    detail.requires:SetText(""); detail.cost:SetText(""); detail.text:SetText("")
    if not name then return end
    detail.icon:SetTexture(icon)
    local needs = Requirements(selected, level)
    detail.requires:SetText(needs ~= "" and ((REQUIRES_LABEL or "Requires:") .. " " .. needs) or "")
    local cost = GetTrainerServiceCost(selected) or 0
    if kind ~= "used" and cost > 0 then
        local available, text = GetMoney(), nil
        if pet then
            local total, used = C_PetInfo.GetPetTrainingPoints()
            available = total - used
            text = string.format(TRAINING_POINTS_ABBREV or "%s TP", tostring(cost))
        else
            text = C_CurrencyInfo.GetCoinTextureString(cost)
        end
        detail.cost:SetText((COSTS_LABEL or "Cost:") .. " " .. (available >= cost and "|cffffffff" or "|cffff2020") .. text .. "|r")
    end
    detail.text:SetText(GetTrainerServiceDescription(selected) or "")
end

local function Build()
    if panel then return end
    local host = ClassTrainerFrame
    panel = CreateFrame("Frame", "EraUIClassicTrainer", host, "SecureHandlerStateTemplate")
    panel:SetAllPoints(host)
    panel:SetFrameLevel(host:GetFrameLevel() + 120)
    panel:EnableMouse(true)
    panel:Hide()
    bridge = CreateFrame("Frame", nil, nil, "SecureHandlerStateTemplate")
    bridge:SetFrameRef("list", host.ScrollBox)
    bridge:SetFrameRef("panel", panel)
    ns.OldSkillShell(panel, { rows = LIST_ROWS, createRow = CreateRow, onScroll = function() UpdateRows() end })
    panel.empty = panel.list:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    panel.empty:SetPoint("TOPLEFT", panel.list, "TOPLEFT", 8, -16)
    panel.empty:SetPoint("RIGHT", panel.list, "RIGHT", -8, 0)
    panel.empty:SetJustifyH("CENTER")
    panel.empty:SetWordWrap(true)
    panel.empty:Hide()
    panel.greeting = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    panel.greeting:SetPoint("TOPLEFT", panel, "TOPLEFT", 72, -30)
    panel.greeting:SetPoint("RIGHT", panel, "RIGHT", -14, 0)
    panel.greeting:SetHeight(36)
    panel.greeting:SetJustifyH("LEFT")
    panel.greeting:SetJustifyV("TOP")
    local gap = CreateFrame("Frame", nil, panel)
    gap:SetFrameLevel(panel:GetFrameLevel() + 1)
    gap:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -50)
    gap:SetPoint("RIGHT", panel, "RIGHT", -4, 0)
    gap:SetPoint("BOTTOM", panel.listBox, "TOP", 0, -8)
    local stone = gap:CreateTexture(nil, "BACKGROUND")
    stone:SetAllPoints(gap)
    stone:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
    stone:SetHorizTile(true)
    stone:SetVertTile(true)
    ns.ThemeTexture(stone, "rockBg")
    panel.collapseAll:SetScript("OnClick", function()
        if InCombatLockdown() then return end
        local fold = not AllCollapsed()
        for _, line in ipairs(lines) do if line.header then collapsed[line.name] = fold or nil end end
        Refresh()
    end)
    panel.filter:SetScript("OnClick", function(self)
        if InCombatLockdown() then return end
        if not panel.filterList then
            local function Item(label, kind)
                return { label, function()
                    SetTrainerServiceTypeFilter(kind, not GetTrainerServiceTypeFilter(kind))
                    Queue()
                end, function() return GetTrainerServiceTypeFilter(kind) end }
            end
            panel.filterList = ns.DropList({ Item(AVAILABLE or "Available", "available"),
                Item(UNAVAILABLE or "Unavailable", "unavailable"), Item(USED or "Already Known", "used") })
            panel.filterList:Follow(panel)
        end
        panel.filterList:Toggle(self)
    end)
    local detail = panel.detail
    detail.iconButton = CreateFrame("Button", nil, detail)
    detail.iconButton:SetSize(37, 37)
    detail.iconButton:SetPoint("TOPLEFT", detail, "TOPLEFT", 20, -18)
    detail.icon = detail.iconButton:CreateTexture(nil, "ARTWORK")
    detail.icon:SetAllPoints(detail.iconButton)
    detail.iconButton:SetScript("OnEnter", function(self)
        local selected = Selection()
        if selected then GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetTrainerService(selected); GameTooltip:Show() end
    end)
    detail.iconButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    detail.name = detail:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    detail.name:SetPoint("TOPLEFT", detail.iconButton, "TOPRIGHT", 8, -2)
    detail.name:SetJustifyH("LEFT")
    detail.sub = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.sub:SetPoint("LEFT", detail.name, "RIGHT", 4, 0)
    detail.requires = detail:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    detail.requires:SetPoint("TOPLEFT", detail.name, "BOTTOMLEFT", 0, -3)
    detail.requires:SetPoint("RIGHT", detail, "RIGHT", -14, 0)
    detail.requires:SetJustifyH("LEFT")
    detail.requires:SetWordWrap(true)
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
    exit:SetScript("OnClick", function() if not InCombatLockdown() then HideUIPanel(host) end end)
    panel.train = ns.PanelButton(panel, TRAIN or "Train", 84)
    panel.train:SetPoint("RIGHT", exit, "LEFT", -3, 0)
    panel.train:EnableMouse(false) -- artwork only; the actual native button is over it
    -- Combat must not remove the entire presentation and expose an empty
    -- native shell. A transparent input shield blocks only the training click.
    panel.trainBlocker = CreateFrame("Frame", nil, panel, "SecureHandlerBaseTemplate")
    panel.trainBlocker:SetAllPoints(panel.train)
    panel.trainBlocker:SetFrameLevel(panel:GetFrameLevel() + 31)
    panel.trainBlocker:EnableMouse(true)
    panel.trainBlocker:Hide()
    local moneyBox = ns.SkillInsetBox(panel, 16, true)
    moneyBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 1, 4)
    moneyBox:SetPoint("RIGHT", panel.train, "LEFT", 1, 0)
    moneyBox:SetHeight(32)
    for _, button in ipairs({ panel.train, exit }) do
        local box = ns.SkillInsetBox(panel, 16, true)
        box:SetPoint("TOP", moneyBox, "TOP", 0, 0)
        box:SetPoint("BOTTOM", moneyBox, "BOTTOM", 0, 0)
        box:SetPoint("LEFT", button, "LEFT", -4, 0)
        box:SetPoint("RIGHT", button, "RIGHT", 4, 0)
        box:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    end
    panel.points = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    panel.points:SetPoint("LEFT", moneyBox, "LEFT", 14, 0)
    panel.points:SetPoint("RIGHT", moneyBox, "RIGHT", -8, 0)
    panel.points:SetJustifyH("LEFT")
    panel.oval = panel:CreateTexture(nil, "ARTWORK")
    panel.oval:SetTexture("Interface\\MoneyFrame\\UI-MoneyFrame-Border")
    panel.oval:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, -3)
    panel.oval:SetPoint("RIGHT", panel.train, "LEFT", -5, 0)
    panel.oval:SetHeight(34)
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
    bridge:SetFrameRef("trainBlocker", panel.trainBlocker)
    for i, row in ipairs(panel.rows) do bridge:SetFrameRef("row" .. i, row) end
    bridge:SetAttribute("_onstate-combat", [[
        if newstate == "1" then
            self:GetFrameRef("trainBlocker"):Show()
            for i = 1, 9 do self:GetFrameRef("row" .. i):SetAttribute("type1", nil) end
        else
            self:GetFrameRef("trainBlocker"):Hide()
        end
    ]])
    RegisterStateDriver(bridge, "combat", "[combat] 1; 0")
end

local function Layout()
    local host = ClassTrainerFrame
    for _, key in ipairs({ "FilterDropdown", "FilterInputHint", "trainingPoints", "skillStepButton", "bottomInset", "BG", "Inset", "ScrollBox", "ScrollBar" }) do Fade(host[key]) end
    Fade(ClassTrainerStatusBar)
    Fade(host.fcui and host.fcui.insetFloor)
    local train = host.TrainButton
    Remember(train)
    train:SetAlpha(0)
    train:ClearAllPoints()
    train:SetAllPoints(panel.train)
    train:SetFrameLevel(panel:GetFrameLevel() + 30)
    Remember(host.money)
    host.money:SetFrameLevel(panel:GetFrameLevel() + 8)
    local oval = ClassTrainerFrameMoneyBg
    if oval then
        -- The native money frame is anchored to this texture. Do not alter
        -- the texture's anchors, so Restore can leave all money geometry intact.
        Remember(host.money)
        host.money:ClearAllPoints()
        host.money:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 18, 13)
    end
    Fade(oval)
    NativeViewport(math.max(330, (GetNumTrainerServices() * 2 + 1) * 47), .01)
end

Refresh = function()
    if refreshing or not active or InCombatLockdown() or not ClassTrainerFrame or not ClassTrainerFrame:IsShown() then return end
    refreshing = true
    phase = "build"
    lastRefresh.beforeBuild = ReadServiceCount()
    Build()
    -- Show the fully built overlay before fading any native controls. The
    -- native OnShow post-hook also runs this pass before the first paint.
    if not panel:IsShown() then bridge:Execute([[self:GetFrameRef("panel"):Show()]]) end
    phase = "layout"
    lastRefresh.beforeLayout = ReadServiceCount()
    Layout()
    phase = "collect"
    lastRefresh.afterLayout = ReadServiceCount()
    Collect()
    phase = "rows"
    panel.greeting:SetText(GetTrainerGreetingText() or "")
    panel.bar:SetRange(math.max(0, #lines - LIST_ROWS))
    UpdateRows()
    phase = "detail"
    UpdateDetail()
    refreshing = false
    phase = "complete"
end

local function Hook()
    if hooked or not ClassTrainerFrame or type(ClassTrainerFrame_InitServiceButton) ~= "function" then return end
    hooked = true
    for _, name in ipairs({ "ClassTrainerFrame_InitServiceButton", "ClassTrainerFrame_InitCategoryButton", "ClassTrainerFrame_Update", "ClassTrainer_SetSelection", "ClassTrainerFrame_UpdateTrainingPoints" }) do
        hooksecurefunc(name, Queue)
    end
    ClassTrainerFrame:HookScript("OnShow", function()
        Record("native shown")
        if active and not InCombatLockdown() then Refresh() end
    end)
    ClassTrainerFrame:HookScript("OnHide", function() Record("native hidden") end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, addon)
    if not active then return end
    if event == "ADDON_LOADED" and addon ~= "Blizzard_TrainerUI" then return end
    if event:find("^TRAINER_") then Record(event) end
    if event == "TRAINER_CLOSED" then return end
    Hook()
    Queue()
end)

local function Apply()
    active = true
    for _, event in ipairs({ "ADDON_LOADED", "TRAINER_SHOW", "TRAINER_CLOSED", "TRAINER_UPDATE", "TRAINER_DESCRIPTION_UPDATE", "UNIT_PET_TRAINING_POINTS", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED" }) do events:RegisterEvent(event) end
    Hook()
    if ClassTrainerFrame then
        Build()
        RegisterStateDriver(bridge, "combat", "[combat] 1; 0")
        Refresh()
    end
end

local function Restore()
    if InCombatLockdown() then return end
    active = false
    events:UnregisterAllEvents()
    if panel then
        UnregisterStateDriver(bridge, "combat")
        panel.trainBlocker:Hide()
        panel:Hide()
        for _, row in ipairs(panel.rows) do Bind(row, nil) end
        routesValid = false
    end
    local box = ClassTrainerFrame and ClassTrainerFrame.ScrollBox
    local keep = box and saved[box]
    if keep then NativeViewport(keep.height, keep.scale) end
    for frame, original in pairs(saved) do
        frame:SetAlpha(original.alpha)
        if original.level then
            frame:SetFrameLevel(original.level)
            if frame ~= box then frame:SetScale(original.scale); frame:SetSize(original.width, original.height) end
            frame:ClearAllPoints()
            for _, point in ipairs(original.points) do frame:SetPoint(unpack(point)) end
        end
    end
    wipe(saved)
end

-- Read-only snapshot for the existing status report. In particular, do not
-- toggle filters or request a native refresh while diagnosing an empty list.
function ns.TrainerDiagnostics()
    local host = ClassTrainerFrame
    if not host then return nil end
    local result = { "Trainer diagnostics (compact layout):" }
    local function Add(text) result[#result + 1] = "    " .. text end
    Add("active=" .. tostring(active) .. ", phase=" .. phase .. ", refreshing=" .. tostring(refreshing) .. ", queued=" .. tostring(queued))
    Add("host shown=" .. tostring(host:IsShown()) .. ", panel shown=" .. tostring(panel and panel:IsShown()) .. ", combat=" .. tostring(InCombatLockdown()))
    local count, named, samples = ReadServiceCount(), 0, {}
    if type(count) == "number" then
        for i = 1, count do
            local name, kind = GetTrainerServiceInfo(i)
            if name then named = named + 1 end
            if i <= 3 then samples[#samples + 1] = i .. ":" .. tostring(name) .. " (" .. tostring(kind) .. ")" end
        end
    end
    Add("API services=" .. tostring(count) .. ", named=" .. named .. ", rendered lines=" .. #lines)
    if #samples > 0 then Add(table.concat(samples, "; ")) end
    for _, kind in ipairs({ "available", "unavailable", "used" }) do
        Add("filter " .. kind .. "=" .. tostring(GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind)))
    end
    Add("last refresh services: before build=" .. tostring(lastRefresh.beforeBuild) .. ", before layout=" .. tostring(lastRefresh.beforeLayout) .. ", after layout=" .. tostring(lastRefresh.afterLayout))
    local nativeCount, bound, shown = 0, 0, 0
    if host.ScrollBox and host.ScrollBox.ForEachFrame then host.ScrollBox:ForEachFrame(function() nativeCount = nativeCount + 1 end) end
    if panel then
        for _, row in ipairs(panel.rows) do
            if row:IsShown() then shown = shown + 1 end
            if row:GetAttribute("clickbutton") then bound = bound + 1 end
        end
    end
    Add("native rows=" .. nativeCount .. ", compact shown=" .. shown .. ", bound=" .. bound .. ", selection=" .. tostring(Selection()))
    if host.ScrollBox then Add("native viewport height=" .. tostring(host.ScrollBox:GetHeight()) .. ", scale=" .. tostring(host.ScrollBox:GetScale())) end
    for _, entry in ipairs(history) do Add(entry) end
    return result
end

ns.RegisterModule("trainer", { apply = Apply, restore = Restore })
