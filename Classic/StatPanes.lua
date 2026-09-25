-- EraUI stat panes.
-- The 2.x character sheet's stat panes, as a toggle for players who prefer
-- them: two boxes under the model, each with a drop down naming what it
-- lists, and the lines beneath. What the boxes can list is what this
-- client's own character window lists, section for section.
local _, EraUI = ...
local ns = EraUI.Classic

local active = false
local panes
local hostFrame
local Raise

local ROWS = 6
local PANE_W, ROW_H = 115, 13
local HEAD_W, HEAD_H, HEAD_OUT = PANE_W, 24, 14
local ROWS_TOP = HEAD_H + 4

local FALLBACK = {
    { label = "General", stats = { { stat = "HEALTH" }, { stat = "POWER" }, { stat = "MOVESPEED" } } },
    { label = "Primary Attributes", stats = { { stat = "STRENGTH" }, { stat = "AGILITY" }, { stat = "INTELLECT" },
        { stat = "STAMINA" }, { stat = "SPIRIT" } } },
    { label = "Weapons", stats = { { stat = "MAINHAND_DAMAGE" }, { stat = "OFFHAND_DAMAGE", hideAt = 0 },
        { stat = "RANGED_DAMAGE", hideAt = 0 }, { stat = "ATTACK_AP", hideAt = 0 }, { stat = "RANGED_ATTACK_AP", hideAt = 0 } } },
    { label = "Modifiers", stats = { { stat = "HITCHANCE", hideAt = 0 }, { stat = "CRITCHANCE", hideAt = 0 },
        { stat = "HASTE", hideAt = 0 }, { stat = "EXPERTISE", hideAt = 0 }, { stat = "ARMORPEN", hideAt = 0 },
        { stat = "SPELLPOWER", hideAt = 0 }, { stat = "SPELLHEALING", hideAt = 0 }, { stat = "SPELLPENETRATION", hideAt = 0 } } },
    { label = "Defense", stats = { { stat = "DEFENSE" }, { stat = "DODGE", hideAt = 0 }, { stat = "BLOCK", hideAt = 0 },
        { stat = "PARRY", hideAt = 0 }, { stat = "ARMOR" } } },
}

local RESISTANCES = {
    { stat = "ARCANE_RESIST", school = 6, coords = { 0, 1, 0.2265625, 0.33984375 } },
    { stat = "FIRE_RESIST", school = 2, coords = { 0, 1, 0, 0.11328125 } },
    { stat = "FROST_RESIST", school = 4, coords = { 0, 1, 0.33984375, 0.453125 } },
    { stat = "NATURE_RESIST", school = 3, coords = { 0, 1, 0.11328125, 0.2265625 } },
    { stat = "SHADOW_RESIST", school = 5, coords = { 0, 1, 0.453125, 0.56640625 } },
}

local sections

local function Sections()
    if sections then return sections end
    sections = {}
    local listed = type(PAPERDOLL_STATCATEGORIES) == "table" and PAPERDOLL_STATCATEGORIES or nil
    if listed then
        for _, category in ipairs(listed) do
            if category.unit == "player" and type(category.stats) == "table" then
                sections[#sections + 1] = { label = category.categoryName or "", stats = category.stats }
            end
        end
    end
    if #sections == 0 then
        for _, section in ipairs(FALLBACK) do sections[#sections + 1] = section end
    end
    sections[#sections + 1] = { label = RESISTANCE_LABEL or "Resistances", stats = RESISTANCES, resistances = true }
    for index, section in ipairs(sections) do section.key = "section" .. index end
    return sections
end

local function SectionByKey(key, fallback)
    local list = Sections()
    for _, section in ipairs(list) do
        if section.key == key then return section end
    end
    return list[fallback] or list[1]
end

local function NumbersWithheld()
    if not issecretvalue or not UnitStat then return false end
    local _, probe = UnitStat("player", 1)
    return issecretvalue(probe) and true or false
end

local function ShowTip(row)
    if type(row.onEnterFunc) == "function" then
        pcall(row.onEnterFunc, row)
    elseif row.tooltip and type(PaperDollStatTooltip) == "function" then
        pcall(PaperDollStatTooltip, row)
    end
end

local function Line(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(PANE_W - 12, ROW_H)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, -ROWS_TOP - (index - 1) * ROW_H)
    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(ROW_H - 1, ROW_H - 1)
    row.Icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Icon:Hide()
    row.Value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.Value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.Value:SetJustifyH("RIGHT")
    row.Value:SetWordWrap(false)
    row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    row.Label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.Label:SetPoint("RIGHT", row.Value, "LEFT", -2, 0)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetWordWrap(false)
    row:EnableMouse(true)
    row:SetScript("OnEnter", ShowTip)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function ClearLine(row)
    row.tooltip, row.tooltip2, row.tooltip3 = nil, nil, nil
    row.onEnterFunc, row.UpdateTooltip, row.numericValue = nil, nil, nil
end

local function FillLine(row, entry, resistances)
    local info = type(PAPERDOLL_STATINFO) == "table" and PAPERDOLL_STATINFO[entry.stat]
    if not info or type(info.updateFunc) ~= "function" then return false end
    if type(entry.showFunc) == "function" then
        local ok, show = pcall(entry.showFunc)
        if ok and not show then return false end
    end
    ClearLine(row)
    row:Show()
    row.Value:SetText("")
    if not pcall(info.updateFunc, row, "player") then return false end
    if not row:IsShown() then return false end
    if entry.hideAt ~= nil and entry.hideAt == row.numericValue then return false end
    local text = row.Value:GetText()
    if text == nil or text == "" then return false end
    row.Label:ClearAllPoints()
    if resistances then
        local school = _G["DAMAGE_SCHOOL" .. (entry.school + 1)]
        if school then row.Label:SetText(string.format(STAT_FORMAT or "%s:", school)) end
        ns.SetTex(row.Icon, "charResistIcons")
        row.Icon:SetTexCoord(unpack(entry.coords))
        row.Icon:Show()
        row.Label:SetPoint("LEFT", row.Icon, "RIGHT", 3, 0)
    else
        row.Icon:Hide()
        row.Label:SetPoint("LEFT", row, "LEFT", 0, 0)
    end
    row.Label:SetPoint("RIGHT", row.Value, "LEFT", -2, 0)
    return true
end

local function Pane(parent, side, fallback)
    local pane = CreateFrame("Frame", nil, parent)
    pane:SetSize(PANE_W, ROWS_TOP + ROWS * ROW_H + 2)
    pane.side, pane.fallback, pane.offset = side, fallback, 0

    local box = CreateFrame("Frame", nil, pane, BackdropTemplateMixin and "BackdropTemplate" or nil)
    box:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, -(ROWS_TOP - 5))
    box:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, -3)
    box:SetFrameLevel(pane:GetFrameLevel())
    if box.SetBackdrop then
        box:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        box:SetBackdropColor(0, 0, 0, 0.55)
        box:SetBackdropBorderColor(1, 1, 1, 1)
    end
    pane.box = box

    local head = CreateFrame("Button", nil, pane)
    head:SetSize(HEAD_W, HEAD_H)
    head:SetPoint("TOP", pane, "TOP", 0, -1)
    local arrow = ns.DressDropdown(head, HEAD_OUT)
    head.text = head:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    head.text:SetPoint("LEFT", head, "LEFT", 9, 1)
    head.text:SetPoint("RIGHT", arrow, "LEFT", 3, 1)
    head.text:SetJustifyH("LEFT")
    head.text:SetWordWrap(false)
    pane.head = head

    pane.rows = {}
    for i = 1, ROWS do pane.rows[i] = Line(pane, i) end
    pane.scratch = Line(pane, 1)
    pane.scratch:SetAlpha(0)
    pane.scratch:EnableMouse(false)
    pane.scratch:Hide()

    local function Pick(section)
        ns.db[pane.side] = section.key
        pane.offset = 0
        ns.UpdateStatPanes()
    end
    head:SetScript("OnClick", function(self)
        if not pane.list then
            local entries = {}
            for _, section in ipairs(Sections()) do
                entries[#entries + 1] = { section.label, function() Pick(section) end, function()
                    return SectionByKey(ns.db[pane.side], pane.fallback) == section
                end }
            end
            pane.list = ns.DropList(entries)
            pane.list:Follow(pane)
        end
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        pane.list:Toggle(self)
    end)

    pane:EnableMouseWheel(true)
    pane:SetScript("OnMouseWheel", function(self, delta)
        local over = math.max(0, (self.lineCount or 0) - ROWS)
        local offset = math.max(0, math.min(over, self.offset - delta))
        if offset ~= self.offset then
            self.offset = offset
            ns.UpdateStatPanes()
        end
    end)
    return pane
end

local function Build()
    if panes then return panes end
    local host = hostFrame or PaperDollFrame
    if not host then return nil end
    panes = {
        left = Pane(host, "statPaneLeft", 2),
        right = Pane(host, "statPaneRight", 3),
    }
    panes.left:SetPoint("TOPLEFT", host, "TOPLEFT", 66, -286)
    panes.right:SetPoint("TOPLEFT", panes.left, "TOPRIGHT", 0, 0)
    return panes
end

local function UpdatePane(pane)
    local section = SectionByKey(ns.db[pane.side], pane.fallback)
    pane.head.text:SetText(section.label)
    local shown = {}
    for _, entry in ipairs(section.stats) do
        if FillLine(pane.scratch, entry, section.resistances) then shown[#shown + 1] = entry end
    end
    pane.scratch:Hide()
    pane.lineCount = #shown
    pane.offset = math.max(0, math.min(pane.offset, math.max(0, #shown - ROWS)))
    for i, row in ipairs(pane.rows) do
        local entry = shown[i + pane.offset]
        if entry and FillLine(row, entry, section.resistances) then row:Show() else row:Hide() end
    end
end

function ns.UpdateStatPanes()
    if not active or not panes then return end
    Raise()
    if NumbersWithheld() then return end
    UpdatePane(panes.left)
    UpdatePane(panes.right)
end

function ns.StatPanesHost(frame)
    hostFrame = frame
end

Raise = function()
    local over = CharacterModelScene and CharacterModelScene:GetFrameLevel() or 0
    for _, pane in pairs(panes) do
        local level = math.max(pane:GetParent():GetFrameLevel() + 2, over + 5)
        if pane:GetFrameLevel() < level then
            pane:SetFrameLevel(level)
            pane.head:SetFrameLevel(level + 2)
        end
    end
end

local function Apply()
    active = true
    if not Build() then return end
    panes.left:Show()
    panes.right:Show()
    Raise()
    if ns.SetClassicStatsShown then ns.SetClassicStatsShown(false) end
    ns.UpdateStatPanes()
end

local function Restore()
    active = false
    if panes then
        panes.left:Hide()
        panes.right:Hide()
    end
    if ns.SetClassicStatsShown then ns.SetClassicStatsShown(true) end
end

ns.RegisterModule("statPanes", { apply = Apply, restore = Restore })
