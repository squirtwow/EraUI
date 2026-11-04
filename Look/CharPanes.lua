-- The stat panes (Classic look, "statPanes", off by default; the Classic
-- option list and /eraui-classic statPanes on|off): two 2.x boxes in place
-- of the 1.x stat boxes, each with a drop down naming a section of the
-- game's own character stats. The lines, numbers and hover tooltips are the
-- game's own: each line is filled by the game's stat function, and hovering
-- it runs the game's own stat hover, as the game's stat list does.
--
-- Shown only while the character window's 1.x look is on.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Char

local LINES, LINE_H = 6, 13
local DEFAULT_PLACE = { statPaneLeft = 2, statPaneRight = 3 }
local RESISTS = { { "ARCANE_RESIST", 6 }, { "FIRE_RESIST", 2 }, { "FROST_RESIST", 4 }, { "NATURE_RESIST", 3 },
    { "SHADOW_RESIST", 5 } }
-- EraUI's own five, in order; a stat marked * is left out at 0.
local FALLBACK = {
    { "STAT_CATEGORY_GENERAL", "General", "HEALTH POWER MOVESPEED" },
    { "STAT_CATEGORY_PRIMARY_ATTRIBUTES", "Primary Attributes", "STRENGTH AGILITY INTELLECT STAMINA SPIRIT" },
    { "STAT_CATEGORY_WEAPONS", "Weapons", "MAINHAND_DAMAGE OFFHAND_DAMAGE* RANGED_DAMAGE* ATTACK_AP* RANGED_ATTACK_AP*" },
    { "STAT_CATEGORY_MODIFIERS", "Modifiers",
        "HITCHANCE* CRITCHANCE* HASTE* EXPERTISE* ARMORPEN* SPELLPOWER* SPELLHEALING* SPELLPENETRATION*" },
    { "STAT_CATEGORY_DEFENSE", "Defense", "DEFENSE DODGE* BLOCK* PARRY* ARMOR" },
}

local P = { on = false, built = false, panes = {} }
local sections

---------------------------------------------------------------------------
-- The sections
---------------------------------------------------------------------------

local function IconRows(school)
    for _, each in ipairs(C.SCHOOLS) do
        if each[1] == school then return each[2], each[3] end
    end
end

-- The game's player sections in its order (EraUI's own five if the game
-- has none), then the resistances; keys "section1", "section2"...
function C.StatSections()
    if sections then return sections end
    sections = {}
    if type(PAPERDOLL_STATCATEGORIES) == "table" then
        for _, category in ipairs(PAPERDOLL_STATCATEGORIES) do
            if type(category) == "table" and category.unit == "player" and type(category.stats) == "table" then
                sections[#sections + 1] = { label = category.categoryName, stats = category.stats }
            end
        end
    end
    if #sections == 0 then
        for _, made in ipairs(FALLBACK) do
            local stats = {}
            for _, word in ipairs(Look.Words(made[3])) do
                local stat, mark = word:match("^([%u_]+)(%*?)$")
                stats[#stats + 1] = { stat = stat, hideAt = (mark == "*") and 0 or nil }
            end
            sections[#sections + 1] = { label = C.Text(made[1], made[2]), stats = stats }
        end
    end
    local resist = { label = C.Text("RESISTANCE_LABEL", "Resistances"), stats = {}, resist = true }
    for _, pair in ipairs(RESISTS) do
        local top, bottom = IconRows(pair[2])
        resist.stats[#resist.stats + 1] = { stat = pair[1], school = pair[2], top = top, bottom = bottom }
    end
    sections[#sections + 1] = resist
    for i, section in ipairs(sections) do
        section.key = "section" .. i
        if type(section.label) ~= "string" then section.label = section.key end
    end
    return sections
end

-- The section a pane shows: its saved key, else its default place, else
-- the first.
local function SectionFor(pane)
    local list = C.StatSections()
    local saved = Look.Saved()[pane.setting]
    for _, section in ipairs(list) do
        if section.key == saved then return section end
    end
    return list[DEFAULT_PLACE[pane.setting]] or list[1]
end

---------------------------------------------------------------------------
-- Lines: filled by the game
---------------------------------------------------------------------------

local function LabelFrom(line, besideIcon)
    line.Label:ClearAllPoints()
    if besideIcon then line.Label:SetPoint("LEFT", line.Icon, "RIGHT", 3, 0)
    else line.Label:SetPoint("LEFT", line, "LEFT", 0, 0) end
    line.Label:SetPoint("RIGHT", line.Value, "LEFT", -2, 0)
end

local function MakeLine(pane, index)
    local made, line = pcall(CreateFrame, "Frame", nil, pane.frame, "CharacterStatFrameTemplate")
    if not made or not line then line = CreateFrame("Frame", nil, pane.frame) end
    line:SetSize(103, LINE_H)
    Look.Fade(line.Background)
    line.Value = line.Value or line:CreateFontString(nil, "ARTWORK")
    line.Label = line.Label or line:CreateFontString(nil, "ARTWORK")
    line.Icon = line.Icon or line:CreateTexture(nil, "ARTWORK")
    line.Value:SetFontObject(GameFontHighlightSmall)
    line.Value:SetJustifyH("RIGHT")
    Look.Pin(line.Value, "RIGHT", line, "RIGHT", 0, 0)
    line.Label:SetFontObject(GameFontNormalSmall)
    line.Label:SetJustifyH("LEFT")
    for _, text in ipairs({ line.Value, line.Label }) do
        if text.SetWordWrap then text:SetWordWrap(false) end
    end
    line.Icon:SetSize(12, 12)
    Look.Pin(line.Icon, "LEFT", line, "LEFT", 0, 0)
    line.Icon:Hide()
    LabelFrom(line, false)
    if index then
        Look.Pin(line, "TOPLEFT", pane.frame, "TOPLEFT", 6, -28 - LINE_H * (index - 1))
        line:EnableMouse(true)
    else
        line:SetAlpha(0)
        line:EnableMouse(false)
    end
    return line
end

-- One stat on a line, by the game's own function. False when there's
-- nothing to show (no function, hidden by the game, at its hide value, an
-- empty value, or an error).
local function Fill(line, entry, section)
    local info = type(PAPERDOLL_STATINFO) == "table" and PAPERDOLL_STATINFO[entry.stat]
    if type(info) ~= "table" or type(info.updateFunc) ~= "function" then return false end
    if type(entry.showFunc) == "function" then
        local fine, show = pcall(entry.showFunc)
        if not fine or not show then return false end
    end
    line.tooltip, line.tooltip2, line.tooltip3 = nil, nil, nil
    line.onEnterFunc, line.UpdateTooltip, line.numericValue = nil, nil, nil
    line:Show()
    line.Value:SetText("")
    if not pcall(info.updateFunc, line, "player") then return false end
    if not line:IsShown() then return false end
    local number = line.numericValue
    if entry.hideAt ~= nil and not Look.Secret(number) and entry.hideAt == number then return false end
    local text = line.Value:GetText()
    if not Look.Secret(text) and (text == nil or text == "") then return false end
    LabelFrom(line, section.resist)
    if section.resist then
        local school = C.Text("DAMAGE_SCHOOL" .. (entry.school + 1), "")
        line.Label:SetText(string.format(C.Text("STAT_FORMAT", "%s:"), school))
        Look.Art(line.Icon, "resistIcons")
        Look.Crop(line.Icon, 0, 1, entry.top or 0, entry.bottom or 1)
        line.Icon:Show()
    else
        line.Icon:Hide()
    end
    return true
end

---------------------------------------------------------------------------
-- The panes
---------------------------------------------------------------------------

local function Raise(pane)
    local host, scene = P.host, C.Model()
    local level = Look.Number(pane.frame:GetFrameLevel()) or 1
    level = math.max(level, (Look.Number(host:GetFrameLevel()) or 1) + 2)
    if scene then level = math.max(level, (Look.Number(scene:GetFrameLevel()) or 1) + 5) end
    pane.frame:SetFrameLevel(level)
    pane.head:SetFrameLevel(level + 2)
end

local function RefreshPane(pane)
    Raise(pane)
    local section = SectionFor(pane)
    pane.text:SetText(section.label)
    local shown = {}
    for _, entry in ipairs(section.stats) do
        if Fill(P.probe, entry, section) then shown[#shown + 1] = entry end
    end
    pane.count = #shown
    pane.offset = Look.Clamp(pane.offset, 0, math.max(0, #shown - LINES))
    for i, line in ipairs(pane.lines) do
        local entry = shown[pane.offset + i]
        if not (entry and Fill(line, entry, section)) then line:Hide() end
    end
end

-- Every line again (with the game keeping the stats hidden, the old lines
-- stay).
function C.UpdateStatPanes()
    if not (P.on and P.built) then return end
    local fine, _, first = pcall(UnitStat, "player", 1)
    if fine and Look.Secret(first) then return end
    for _, pane in ipairs(P.panes) do Look.Try(RefreshPane, pane) end
end

local function Pick(pane, section)
    if ns.db then ns.db[pane.setting] = section.key end
    pane.offset = 0
    Look.Try(RefreshPane, pane)
    Look.Save()
end

local function OpenList(pane)
    if not pane.drop then
        local entries = {}
        for _, section in ipairs(C.StatSections()) do
            entries[#entries + 1] = { label = section.label, pick = function() Pick(pane, section) end,
                chosen = function() return SectionFor(pane) == section end }
        end
        pane.drop = Look.DropList(entries)
        pane.drop.Follow(pane.frame)
    end
    if PlaySound and SOUNDKIT then PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) end
    pane.drop.Toggle(pane.head)
end

local function Wheel(pane, delta)
    local moved = Look.Clamp(pane.offset - (Look.Number(delta) or 0), 0, math.max(0, (pane.count or 0) - LINES))
    if moved ~= pane.offset then
        pane.offset = moved
        Look.Try(RefreshPane, pane)
    end
end

local function MakePane(host, setting, anchor)
    local frame = Look.Build("Frame", host, nil, { size = { 115, 28 + LINES * LINE_H + 2 }, wheel = true })
    Look.Pin(frame, "TOPLEFT", anchor[1], anchor[2], anchor[3], anchor[4])
    local pane = { frame = frame, setting = setting, offset = 0, lines = {} }
    local box = Look.Build("Frame", frame, "BackdropTemplate", { size = { 115, 80 } })
    box:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -23)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, -3)
    box:SetFrameLevel(Look.Number(frame:GetFrameLevel()) or 1)
    box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    box:SetBackdropColor(0, 0, 0, 0.55)
    box:SetBackdropBorderColor(1, 1, 1, 1)
    local head = Look.Build("Button", frame, nil, { size = { 115, 24 } })
    Look.Pin(head, "TOP", frame, "TOP", 0, -1)
    local arrow = Look.DressDropdown(head, 14)
    pane.text = Look.OwnLabel(head, "text", "GameFontHighlightSmall", "ARTWORK")
    pane.text:SetJustifyH("LEFT")
    if pane.text.SetWordWrap then pane.text:SetWordWrap(false) end
    pane.text:SetPoint("LEFT", head, "LEFT", 9, 1)
    pane.text:SetPoint("RIGHT", arrow, "LEFT", 3, 1)
    head:SetScript("OnClick", function() OpenList(pane) end)
    pane.head = head
    for i = 1, LINES do pane.lines[i] = MakeLine(pane, i) end
    frame:SetScript("OnMouseWheel", function(_, delta) Wheel(pane, delta) end)
    P.panes[#P.panes + 1] = pane
    return pane
end

-- The host the panes are built on (the sheet passes it on every layout).
function C.StatPanesHost(frame)
    if frame then P.host = frame end
end

local function Build()
    if P.built or not P.host then return end
    P.built = true
    local left = MakePane(P.host, "statPaneLeft", { P.host, "TOPLEFT", 66, -286 })
    MakePane(P.host, "statPaneRight", { left.frame, "TOPRIGHT", 0, 0 })
    P.probe = MakeLine(left, nil)
end

local function ShowPanes(on)
    for _, pane in ipairs(P.panes) do Look.Shown(pane.frame, on) end
end

local function PanesOn()
    if not C.active then
        P.on = false
        ShowPanes(false)
        return
    end
    P.on = true
    C.StatPanesHost(PaperDollFrame)
    Build()
    if not P.built then return end
    ShowPanes(true)
    for _, pane in ipairs(P.panes) do Raise(pane) end
    C.SetClassicStatsShown(false)
    C.UpdateStatPanes()
end

local function PanesOff()
    P.on = false
    ShowPanes(false)
    if C.active and C.built then C.SetClassicStatsShown(true) end
end

ns.RegisterModule("statPanes", { apply = PanesOn, restore = PanesOff })

-- What the tests read.
function C.StatPanes()
    return P
end
