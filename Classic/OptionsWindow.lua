-- EraUI options dialog.
-- The 1.x options dialog: the dialog box border and dark background, the
-- header plate with the title, one classic checkbox per module (checked is
-- the classic look, unchecked the modern one) and the old panel buttons.
local _, EraUI = ...
local ns = EraUI.Classic

local TITLE = "EraUI"
local WIDTH, ROW = 470, 24
local LIST_ROWS, INDENT, COLUMNS = 10, 22, 2
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local CHECK = "Interface\\Buttons\\UI-CheckBox-"
local PANEL_BUTTON = "Interface\\Buttons\\UI-Panel-Button-"

local window

function ns.PanelButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width or 96, 22)
    local ok = button:SetNormalTexture(PANEL_BUTTON .. "Up")
    if ok == false then
        button:Hide()
        button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        button:SetSize(width or 96, 22)
        button:SetText(text)
        return button
    end
    button:SetPushedTexture(PANEL_BUTTON .. "Down")
    button:SetDisabledTexture(PANEL_BUTTON .. "Disabled")
    button:SetHighlightTexture(PANEL_BUTTON .. "Highlight")
    for _, tex in ipairs({ button:GetNormalTexture(), button:GetPushedTexture(), button:GetDisabledTexture(), button:GetHighlightTexture() }) do
        tex:SetTexCoord(0, 0.625, 0, 0.6875)
    end
    button:GetHighlightTexture():SetBlendMode("ADD")
    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetFontObject(ns.FONT_GOLD or "GameFontNormal")
    label:SetPoint("CENTER", 0, -1)
    label:SetText(text)
    button:SetFontString(label)
    button:SetNormalFontObject(ns.FONT_GOLD or "GameFontNormal")
    button:SetDisabledFontObject("GameFontDisable")
    button:SetHighlightFontObject("GameFontHighlight")
    return button
end

local function ShowTooltip(self)
    if not self.tooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(self.label, 1, 1, 1)
    GameTooltip:AddLine(self.tooltip, nil, nil, nil, true)
    GameTooltip:Show()
end

local function Stepper(parent, key, label, tooltip, low, high, apply)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(24, 24)
    row.key, row.label, row.tooltip = key, label, tooltip
    local function Arrow(kind, x)
        local button = CreateFrame("Button", nil, row)
        button:SetSize(16, 16)
        button:SetPoint("LEFT", row, "LEFT", x, 0)
        button:SetNormalTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Up")
        button:SetPushedTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Down")
        button:SetDisabledTexture("Interface\\Buttons\\UI-" .. kind .. "Button-Disabled")
        button:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")
        button:GetHighlightTexture():SetBlendMode("ADD")
        return button
    end
    row.minus = Arrow("Minus", 4)
    row.value = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.value:SetPoint("LEFT", row.minus, "RIGHT", 2, 0)
    row.value:SetWidth(20)
    row.value:SetJustifyH("CENTER")
    row.plus = Arrow("Plus", 42)
    local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", row.plus, "RIGHT", 4, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    row.text = text
    function row:Sync()
        local value = tonumber(ns.db[key]) or low
        self.value:SetText(value)
        self.minus:SetEnabled(self.on ~= false and value > low)
        self.plus:SetEnabled(self.on ~= false and value < high)
    end
    function row:SetChecked() self:Sync() end
    function row:SetEnabled(on)
        self.on = on and true or false
        self:Sync()
    end
    local function Step(by)
        return function()
            apply(math.max(low, math.min(high, (tonumber(ns.db[key]) or low) + by)))
            row:Sync()
        end
    end
    row.minus:SetScript("OnClick", Step(-1))
    row.plus:SetScript("OnClick", Step(1))
    row:EnableMouse(true)
    row:SetScript("OnEnter", ShowTooltip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function Checkbox(parent, key, label, tooltip)
    local box = CreateFrame("CheckButton", nil, parent)
    box:SetSize(24, 24)
    box:SetNormalTexture(CHECK .. "Up")
    box:SetPushedTexture(CHECK .. "Down")
    box:SetHighlightTexture(CHECK .. "Highlight")
    box:GetHighlightTexture():SetBlendMode("ADD")
    box:SetCheckedTexture(CHECK .. "Check")
    box:SetDisabledCheckedTexture(CHECK .. "Check-Disabled")
    box.key, box.label, box.tooltip = key, label, tooltip
    local text = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", box, "RIGHT", 2, 1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:SetText(label)
    box.text = text
    box:SetScript("OnEnter", ShowTooltip)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)
    box:SetScript("OnClick", function(self)
        ns.db[self.key] = self:GetChecked() and true or false
        ns.ToggleChanged(self.key)
        local owner = self.owner or window
        if owner and owner.Refresh then owner:Refresh() end
    end)
    return box
end

local function Build(canvas)
    local width = canvas and (canvas:GetWidth() or WIDTH) or WIDTH
    if width < WIDTH then width = WIDTH end
    local listRows = canvas and LIST_ROWS + 6 or LIST_ROWS
    local frame = canvas
    if not frame then
        frame = CreateFrame("Frame", "EraUIClassicOptions", UIParent, "BackdropTemplate")
        frame:SetBackdrop({
            bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 },
        })
        frame:SetFrameStrata("HIGH")
        frame:SetToplevel(true)
        local fill = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        fill:SetColorTexture(0.03, 0.03, 0.03, 0.45)
        fill:SetPoint("TOPLEFT", frame, "TOPLEFT", 11, -12)
        fill:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 11)
        frame:SetPoint("CENTER")
        frame:SetMovable(true)
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", frame.StartMoving)
        frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
        frame:SetClampedToScreen(true)
        frame:Hide()

        local header = frame:CreateTexture(nil, "ARTWORK")
        header:SetTexture(DIALOG_HEADER)
        header:SetSize(256, 64)
        header:SetPoint("TOP", frame, "TOP", 0, 12)
        local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", header, "TOP", 0, -14)
        title:SetText(TITLE)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
        close:SetScript("OnClick", function() frame:Hide() end)
        if ns.SkinCloseButton then ns.SkinCloseButton(close, true) end
    end

    local LIST_TOP, LIST_W = canvas and -76 or -110, width - 70
    local list = CreateFrame("ScrollFrame", nil, frame)
    list:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, LIST_TOP)
    list:SetSize(LIST_W, listRows * ROW)
    list:SetClipsChildren(true)
    local child = CreateFrame("Frame", nil, list)
    child:SetSize(LIST_W, 1)
    list:SetScrollChild(child)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta) frame.listBar:SetValue(frame.listBar:GetValue() - delta * ROW) end)
    frame.listBar = ns.ClassicScrollBar(frame, list, function(value) list:SetVerticalScroll(value) end)
    frame.list, frame.listChild = list, child

    frame.boxes = {}
    local rows = {}
    for _, entry in ipairs(ns.TOGGLES) do rows[#rows + 1] = entry end
    for _, entry in ipairs(rows) do
        local box = Checkbox(child, entry[1], entry[2], entry[3])
        box.parent = entry.parent
        box.owner = frame
        box.text:SetWidth(LIST_W / COLUMNS - 30 - (entry.parent and INDENT or 0))
        frame.boxes[#frame.boxes + 1] = box
        if entry[1] == "oneBag" and ns.SetOneBagColumns then
            local columns = Stepper(child, "oneBagColumns", "One bag columns",
                "How many slots across the one bag window is. The old bags were four across; more makes the window wider and shorter.",
                ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16, ns.SetOneBagColumns)
            columns.parent = "oneBag"
            columns.owner = frame
            columns.text:SetWidth(LIST_W / COLUMNS - 70 - INDENT)
            frame.boxes[#frame.boxes + 1] = columns
        end
    end

    local search = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    search:SetSize(width - 60, 20)
    search:SetPoint("TOP", frame, "TOP", 4, canvas and -16 or -50)
    search:SetAutoFocus(false)
    search:SetFontObject("ChatFontNormal")
    search:SetMaxLetters(40)
    local hint = search:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    hint:SetPoint("LEFT", search, "LEFT", 2, 0)
    hint:SetText("Search toggles")
    search.hint = hint
    frame.search = search
    local clear = CreateFrame("Button", nil, search)
    clear:SetSize(17, 17)
    clear:SetPoint("RIGHT", search, "RIGHT", -3, 0)
    clear:SetNormalTexture("Interface\\FriendsFrame\\ClearBroadcastIcon")
    clear:SetHighlightTexture("Interface\\FriendsFrame\\ClearBroadcastIcon", "ADD")
    clear:GetNormalTexture():SetAlpha(0.6)
    clear:SetScript("OnClick", function() search:SetText("") search:ClearFocus() end)
    clear:Hide()
    search.clear = clear

    function frame:PlaceBoxes(text)
        text = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        local own, hit = {}, {}
        for _, box in ipairs(self.boxes) do
            if text == "" or box.label:lower():find(text, 1, true) or (box.tooltip or ""):lower():find(text, 1, true) then
                own[box.key] = true
                hit[box.key] = true
            end
        end
        for _, box in ipairs(self.boxes) do
            if own[box.key] then
                local head = box.parent or box.key
                hit[head] = true
                for _, other in ipairs(self.boxes) do
                    if other.parent == head then hit[other.key] = true end
                end
            end
        end
        local groups, count = {}, 0
        for _, box in ipairs(self.boxes) do
            if not hit[box.key] then
                box:Hide()
            elseif not box.parent then
                local group = { box }
                for _, other in ipairs(self.boxes) do
                    if other.parent == box.key and hit[other.key] then group[#group + 1] = other end
                end
                groups[#groups + 1] = group
                count = count + #group
            end
        end
        local half = math.max(1, math.ceil(count / COLUMNS))
        local colW = LIST_W / COLUMNS
        local column, row, per = 0, 0, 0
        for _, group in ipairs(groups) do
            if column < COLUMNS - 1 and row > 0 and row + #group > half then
                column, row = column + 1, 0
            end
            for _, box in ipairs(group) do
                box:ClearAllPoints()
                box:SetPoint("TOPLEFT", self.listChild, "TOPLEFT", column * colW + (box.parent and INDENT or 0), -row * ROW)
                box:Show()
                row = row + 1
            end
            if row > per then per = row end
        end
        self.listChild:SetHeight(math.max(1, per * ROW))
        self.listBar:SetRange(math.max(0, per * ROW - listRows * ROW), ROW)
        self.search.hint:SetShown(text == "")
        self.search.clear:SetShown(text ~= "")
    end
    search:SetScript("OnTextChanged", function(self) frame:PlaceBoxes(self:GetText()) end)
    search:SetScript("OnEscapePressed", function(self) self:SetText("") self:ClearFocus() end)
    search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    frame:PlaceBoxes("")

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    note:SetPoint("BOTTOM", frame, "BOTTOM", 0, 78)
    note:SetTextColor(1, 0.35, 0.25)
    frame.note = note

    local NOT_IN_ALL = { minimapButton = true, welcomeNote = true }
    local function InAll(key) return not key:match("^eraui_") and ns.DB_DEFAULTS[key] ~= false and not NOT_IN_ALL[key] end
    local all = ns.PanelButton(frame, "Toggle all", 100)
    all:SetPoint("TOPRIGHT", search, "BOTTOM", -3, -6)
    all:SetScript("OnClick", function()
        local anyOff = false
        for _, entry in ipairs(rows) do
            if InAll(entry[1]) and ns.db[entry[1]] == false then anyOff = true end
        end
        local wentOff = false
        for _, entry in ipairs(rows) do
            if InAll(entry[1]) then
                local on = anyOff and true or false
                if not on and ns.db[entry[1]] ~= false and ns.RELOAD_KEYS[entry[1]] then wentOff = true end
                ns.db[entry[1]] = on
            end
        end
        ns.ApplyAll()
        frame:Refresh()
        if wentOff and StaticPopup_Show then StaticPopup_Show("ERAUICLASSIC_RELOAD") end
    end)
    all.tooltip = "Turns every piece of the classic look on, or off if they are all on already. The extras that start off (One bar, One bag, Default interface bar size), the minimap button and the welcome note are left as they are."
    all.label = "Toggle all"
    all:SetScript("OnEnter", ShowTooltip)
    all:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local defaults = ns.PanelButton(frame, "Reset toggles", 100)
    defaults:SetPoint("TOPLEFT", search, "BOTTOM", 3, -6)
    defaults:SetScript("OnClick", function()
        local wentOff = false
        local wasBig = ns.db.defaultBarSize == true
        for _, entry in ipairs(rows) do
            local want = ns.DB_DEFAULTS[entry[1]]
            if want == false and ns.db[entry[1]] ~= false and ns.RELOAD_KEYS[entry[1]] then wentOff = true end
            ns.db[entry[1]] = want
            if entry[1]:match("^eraui_") then ns.ToggleChanged(entry[1]) end
        end
        if wasBig and ns.db.defaultBarSize ~= true and ns.FitBarsToSize then ns.FitBarsToSize(false) end
        ns.ApplyAll()
        frame:Refresh()
        if wentOff and StaticPopup_Show then StaticPopup_Show("ERAUICLASSIC_RELOAD") end
    end)
    defaults.tooltip = "Puts every checkbox back to its default. Nothing to do with edit mode layouts."
    defaults.label = "Reset toggles"
    defaults:SetScript("OnEnter", ShowTooltip)
    defaults:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local reload = ns.PanelButton(frame, "Reload UI", 130)
    reload:SetPoint("BOTTOM", frame, "BOTTOM", 0, 22)
    reload:SetScript("OnClick", function() ns.ReloadForLayout() end)

    if not canvas then frame:SetSize(WIDTH, 110 + LIST_ROWS * ROW + 108) end

    function frame:Refresh()
        if ns.ReadGameDamageNumbers then ns.ReadGameDamageNumbers() end
        for _, box in ipairs(self.boxes) do
            box:SetChecked(ns.db[box.key] ~= false)
            local on = not box.parent or ns.db[box.parent] ~= false
            box:SetEnabled(on)
            box.text:SetFontObject(on and "GameFontHighlight" or "GameFontDisable")
        end
        self.note:SetText(ns.needsReload and "Reload the interface to clear the old art from the pieces you turned off." or "")
    end
    frame:SetScript("OnShow", frame.Refresh)
    if not canvas and ns.CloseOnEscape then ns.CloseOnEscape(frame) end
    return frame
end

function ns.OptionsCanvas()
    if ns.optionsCanvas then return ns.optionsCanvas end
    local canvas = CreateFrame("Frame", "EraUIClassicOptionsCanvas", UIParent)
    canvas:SetSize(620, 560)
    canvas:Hide()
    ns.optionsCanvas = Build(canvas)
    return ns.optionsCanvas
end

function ns.RefreshOptionsWindow()
    if window and window:IsShown() then window:Refresh() end
    local canvas = ns.optionsCanvas
    if canvas and canvas:IsShown() then canvas:Refresh() end
end

function ns.OpenOptions()
    if not window then window = Build() end
    if window:IsShown() then
        window:Hide()
    else
        window:Show()
    end
end
