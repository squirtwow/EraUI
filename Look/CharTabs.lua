-- The character window's bottom tabs and the game's side pane (Classic look,
-- "characterSheet").
--
-- Tabs: Forever's window has side icon tabs (ModeTabs). EraUI draws a 1.x
-- tab along the window's foot for each one the game shows, and lays the
-- game's own tab, invisible, over it: the click lands on the game's tab and
-- the game switches panes itself. EraUI's tabs never take the mouse. The
-- game's hover tooltip on its tab is left to the game.
--
-- Side pane: the 1.x window is one pane wide. The game's right-hand pane
-- (stats list, titles, sets, sidebar tabs, the expand arrow) is kept
-- invisible and click-through: alpha 0, and the mouse off on it and five
-- levels down. Only what EraUI turned off is turned back on.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Char

local TAB_WORDS = { PaperDollFrame = "CHARACTER", ReputationFrame = "REPUTATION", TokenFrame = "CURRENCY",
    SkillsFrame = "SKILLS" }
local TAB_FALLBACK = { PaperDollFrame = "Character", ReputationFrame = "Reputation", TokenFrame = "Currency",
    PVPRankFrame = "PvP", SkillsFrame = "Skills", StatisticsFrame = "Stats" }
local ACTIVE = { key = "tabActive", height = 35, bottom = 0.546875 }
local INACTIVE = { key = "tabInactive", height = 32, bottom = 1 }
local PIECES = { { "left", 0, 0.15625 }, { "middle", 0.15625, 0.84375 }, { "right", 0.84375, 1 } }

C.tabs = {}               -- index: EraUI's tab
local tabParts = Look.Weak() -- EraUI's tab: { label, art = {}, glow = {} }

---------------------------------------------------------------------------
-- EraUI's tabs
---------------------------------------------------------------------------

local function TabLabel(frameName)
    if frameName == "PVPRankFrame" then return "PvP" end
    if frameName == "StatisticsFrame" then return "Stats" end
    local word = TAB_WORDS[frameName]
    if word then return C.Text(word, TAB_FALLBACK[frameName]) end
    return tostring(frameName or "")
end

local function PaintTab(tab, selected)
    local parts = tabParts[tab]
    local look = selected and ACTIVE or INACTIVE
    for i, piece in ipairs(PIECES) do
        for _, texture in ipairs({ parts.art[i], parts.glow[i] }) do
            Look.Art(texture, look.key)
            Look.Crop(texture, piece[2], piece[3], 0, look.bottom)
            texture:SetHeight(look.height)
        end
    end
    parts.label:SetFontObject(selected and GameFontHighlightSmall or GameFontNormalSmall)
end

local function MakeTab(sheet, index)
    local tab = CreateFrame("Button", "EraUIClassicCharacterTab" .. index, sheet)
    tab:SetSize(106, 32)
    tab:EnableMouse(false)
    local parts = { art = {}, glow = {} }
    for i, layer in ipairs({ "BACKGROUND", "HIGHLIGHT" }) do
        local set = i == 1 and parts.art or parts.glow
        for j, piece in ipairs(PIECES) do set[j] = Look.OwnTexture(tab, layer .. piece[1], layer) end
        set[1]:SetWidth(20)
        Look.Pin(set[1], "TOPLEFT", tab, "TOPLEFT", 0, 0)
        set[3]:SetWidth(20)
        Look.Pin(set[3], "TOPRIGHT", tab, "TOPRIGHT", 0, 0)
        set[2]:ClearAllPoints()
        set[2]:SetPoint("TOPLEFT", set[1], "TOPRIGHT")
        set[2]:SetPoint("TOPRIGHT", set[3], "TOPLEFT")
    end
    for _, glow in ipairs(parts.glow) do
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.35)
    end
    parts.label = Look.OwnLabel(tab, "label", "GameFontNormalSmall", "OVERLAY")
    parts.label:SetJustifyH("CENTER")
    if parts.label.SetWordWrap then parts.label:SetWordWrap(false) end
    Look.Pin(parts.label, "CENTER", tab, "CENTER", 0, -3)
    tabParts[tab] = parts
    return tab
end

-- The tab's width from its label: the label's own width plus 30, at most 106.
local function FitTab(tab, text)
    local label = tabParts[tab].label
    label:SetWidth(0)
    label:SetText(text)
    local width = math.min(106, math.ceil(Look.Number(label:GetStringWidth()) or 76) + 30)
    tab:SetWidth(width)
    label:SetWidth(width - 20)
end

-- The game's tab laid over EraUI's: all its points, two levels above it,
-- no hit insets, the mouse on.
local function Overlay(mode, mine)
    if not C.Free(mode) then return end
    local pinned = mode:GetNumPoints() == 2 and select(2, mode:GetPoint(1)) == mine and select(2, mode:GetPoint(2)) == mine
    if not pinned then
        mode:ClearAllPoints()
        mode:SetAllPoints(mine)
    end
    local wanted = (Look.Number(mine:GetFrameLevel()) or 1) + 2
    if (Look.Number(mode:GetFrameLevel()) or 0) < wanted then mode:SetFrameLevel(wanted) end
    if not pinned and mode.SetHitRectInsets then pcall(mode.SetHitRectInsets, mode, 0, 0, 0, 0) end
    if mode.IsMouseEnabled and not mode:IsMouseEnabled() then C.Mouse(mode, true) end
end

local hoverHooked = Look.Weak()
local function WatchHover(mode, mine)
    if hoverHooked[mode] then return end
    hoverHooked[mode] = true
    Look.HookScript(mode, "OnEnter", function() if C.active then mine:LockHighlight() end end)
    Look.HookScript(mode, "OnLeave", function() mine:UnlockHighlight() end)
end

local function ModeTabs(sheet)
    local holder = sheet.ModeTabs
    return holder and type(holder.Tabs) == "table" and holder.Tabs or nil
end

-- Every tab placed: the first shown one at the foot of the art, each next
-- one overlapping the last by 15.
function C.LayTabs(sheet)
    local modes = ModeTabs(sheet)
    if not modes then return C.LayGameTabs(sheet) end
    local anchor = C.sheetArt.general[3]
    local last
    for index, mode in ipairs(modes) do
        local mine = C.tabs[index] or MakeTab(sheet, index)
        C.tabs[index] = mine
        local shown = mode:IsShown() and true or false
        Look.Shown(mine, shown and C.active)
        if shown then
            FitTab(mine, TabLabel(mode.frameName))
            PaintTab(mine, mode.frameName ~= nil and mode.frameName == sheet.activeSubframe)
            if last then Look.Pin(mine, "LEFT", last, "RIGHT", -15, 0)
            elseif anchor then Look.Pin(mine, "BOTTOMLEFT", anchor, "BOTTOMLEFT", 14, 46) end
            last = mine
            Overlay(mode, mine)
            WatchHover(mode, mine)
        end
    end
end

-- Every frame while the window shows: the game's tabs back over EraUI's.
function C.KeepModeTabs(sheet)
    local modes = ModeTabs(sheet)
    if not modes then return end
    for index, mode in ipairs(modes) do
        local mine = C.tabs[index]
        if mine and mode:IsShown() then Overlay(mode, mine) end
    end
end

function C.HideTabs()
    for _, tab in pairs(C.tabs) do tab:Hide() end
end

---------------------------------------------------------------------------
-- Other clients: the game's own bottom tabs in 1.x art (not on Forever)
---------------------------------------------------------------------------

local gameTabParts = Look.Weak()

local function DressGameTab(tab)
    local parts = gameTabParts[tab]
    if not parts then
        parts = {}
        for _, piece in ipairs(PIECES) do
            parts["on" .. piece[1]] = Look.OwnTexture(tab, "on" .. piece[1], "BACKGROUND")
            parts["off" .. piece[1]] = Look.OwnTexture(tab, "off" .. piece[1], "BACKGROUND")
        end
        for _, key in ipairs(Look.Words("Left Middle Right LeftActive MiddleActive RightActive LeftHighlight MiddleHighlight RightHighlight")) do
            Look.Fade(tab[key])
        end
        gameTabParts[tab] = parts
        local glow = tab.GetHighlightTexture and tab:GetHighlightTexture()
        if glow then
            Look.Art(glow, "tabHighlight")
            glow:ClearAllPoints()
            glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 5)
            glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 0)
            glow:SetBlendMode("ADD")
        end
    end
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    local width = math.ceil(Look.Number(text and text:GetStringWidth()) or 40) + 50
    tab:SetWidth(width)
    for _, look in ipairs({ { "on", ACTIVE, 0 }, { "off", INACTIVE, -4 } }) do
        for _, piece in ipairs(PIECES) do
            local texture = parts[look[1] .. piece[1]]
            Look.Art(texture, look[2].key)
            Look.Crop(texture, piece[2], piece[3], 0, look[2].bottom)
            texture:SetSize(piece[1] == "middle" and (width - 40) or 20, look[2].height)
        end
        local left, right, middle = parts[look[1] .. "left"], parts[look[1] .. "right"], parts[look[1] .. "middle"]
        Look.Pin(left, "TOPLEFT", tab, "TOPLEFT", 0, look[3])
        Look.Pin(right, "TOPRIGHT", tab, "TOPRIGHT", 0, look[3])
        Look.Pin(middle, "TOPLEFT", left, "TOPRIGHT", 0, 0)
    end
    local selected = PanelTemplates_GetSelectedTab and PanelTemplates_GetSelectedTab(tab:GetParent()) == tab:GetID()
    for _, piece in ipairs(PIECES) do
        Look.Shown(parts["on" .. piece[1]], selected)
        Look.Shown(parts["off" .. piece[1]], not selected)
    end
end

function C.LayGameTabs(sheet)
    local anchor = C.sheetArt.general[3]
    local last
    for index = 1, 6 do
        local tab = _G["CharacterFrameTab" .. index]
        if tab and tab:IsShown() and C.Free(tab) then
            DressGameTab(tab)
            if last then Look.Pin(tab, "LEFT", last, "RIGHT", -15, 0)
            elseif anchor then Look.Pin(tab, "BOTTOMLEFT", anchor, "BOTTOMLEFT", 14, 56) end
            last = tab
        end
    end
end

---------------------------------------------------------------------------
-- Muting the game's side pane
---------------------------------------------------------------------------

local mutedBy = Look.Weak() -- muted frame: { frames EraUI turned the mouse off on }

local function MouseOff(frame, depth, into)
    if not frame or depth > 5 then return end
    if frame.IsMouseEnabled and frame:IsMouseEnabled() and C.Free(frame) then
        if pcall(frame.EnableMouse, frame, false) then into[#into + 1] = frame end
    end
    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do MouseOff(child, depth + 1, into) end
    end
end

function C.Mute(frame)
    if not frame then return end
    if (Look.Number(frame:GetAlpha()) or 1) > 0 then frame:SetAlpha(0) end
    local record = mutedBy[frame]
    if record and not (frame.IsMouseEnabled and frame:IsMouseEnabled()) then return end
    record = record or {}
    mutedBy[frame] = record
    MouseOff(frame, 0, record)
end

function C.Unmute(frame)
    local record = frame and mutedBy[frame]
    if not record then return end
    mutedBy[frame] = nil
    frame:SetAlpha(1)
    for _, each in ipairs(record) do
        if C.Free(each) then pcall(each.EnableMouse, each, true) end
    end
end

local function Sidebars(each)
    if type(PAPERDOLL_SIDEBARS) ~= "table" or type(GetPaperDollSideBarFrame) ~= "function" then return end
    for i = 1, #PAPERDOLL_SIDEBARS do
        local fine, bar = pcall(GetPaperDollSideBarFrame, i)
        if fine and bar then each(bar) end
    end
end

-- The right pane out of sight and out of reach, but for the Skills detail
-- (while Skills shows) and the game's set list (while EraUI's equipment
-- pane is open). The window's invisible right side takes no clicks.
function C.HideSidePane()
    local sheet = CharacterFrame
    if not (C.active and sheet) then return end
    C.Mute(sheet.RightPaneHost)
    local skillPane = SkillsFrame and SkillsFrame.SkillDetailFrame
    for _, pane in ipairs(type(sheet.SidePanes) == "table" and sheet.SidePanes or {}) do
        if pane == skillPane and SkillsFrame:IsShown() then C.Unmute(pane) else C.Mute(pane) end
    end
    for _, frame in ipairs({ CharacterStatsPane or false, CharacterStatsPaneScrollBox or false, PaperDollSidebarTabs or false,
        PaperDollLevelInfo or false }) do
        if frame then C.Mute(frame) end
    end
    local setList = PaperDollFrame and PaperDollFrame.EquipmentManagerPane
    Sidebars(function(bar)
        if bar == setList and C.EquipmentOpen and C.EquipmentOpen() then C.Unmute(bar) else C.Mute(bar) end
    end)
    C.Mute(sheet.RightPaneToggleButton)
    local tabs = sheet.ModeTabs
    if tabs then
        Look.Fade(tabs)
        if not tabs:IsShown() and C.Free(tabs) then tabs:Show() end
    end
    C.TrimHitRect(sheet)
end

local hitInset = Look.Weak()
function C.TrimHitRect(sheet)
    local extra = math.max(0, math.floor((Look.Number(sheet:GetWidth()) or C.SHEET_W) - C.SHEET_W))
    if hitInset[sheet] == extra or not C.Free(sheet) then return end
    hitInset[sheet] = extra
    pcall(sheet.SetHitRectInsets, sheet, 0, extra, 0, 0)
end

-- The window loads with its right pane collapsed (the game's own setting,
-- through the engine's guarded writer: never in a fight, never the same
-- value twice, the old value kept for the hand-back).
function C.WriteCollapsed()
    if type(ns.SetCVar) == "function" then Look.Try(ns.SetCVar, "characterFrameCollapsed", "1") end
end

-- Every frame while the window shows: the side pane hidden again if the
-- game showed it, and the game's tabs back over EraUI's.
function C.WatchSidePane(sheet)
    if C.sideWatch then return end
    C.sideWatch = C.Poll(sheet, 0, function()
        if not C.active then return end
        local tabs, host = PaperDollSidebarTabs, sheet.RightPaneHost
        local back = (tabs and tabs:IsShown() and (Look.Number(tabs:GetAlpha()) or 0) > 0)
            or (host and host:IsShown() and (Look.Number(host:GetAlpha()) or 0) > 0)
        if back then C.HideSidePane() end
        C.KeepModeTabs(sheet)
    end)
end
