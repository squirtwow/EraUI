-- The window chrome's extras: what a few windows wear besides the common
-- chrome (Look/ChromeWindow.lua). Each is a function(window, options) the
-- window list hands to the dressing (Look/ChromeModule.lua). The loot
-- window's are in Look/ChromeLoot.lua.
--
-- Hooks are post-hooks through Look, installed once; what EraUI made or
-- noted about the game's frames is kept in weak tables (C.mine and the
-- records below), never on them.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Chrome

local X = {}
C.extras = X

local shortened = Look.Weak() -- NPC window: true once made shorter
local hookedOnce = {}         -- what a one-time hook was put on: true
local platesOn = Look.Weak()  -- reward button: its name plate

local function Once(key)
    if hookedOnce[key] then return false end
    hookedOnce[key] = true
    return true
end

-- On the next frame (the game's own call finished first).
local function Soon(run)
    local timers = C_Timer
    if type(timers) == "table" and type(timers.After) == "function" then timers.After(0, run) else run() end
end

-- Every texture region of a frame and of its children, all the way down,
-- faded (EraUI's own pieces excepted).
function C.FadeDown(frame, depth)
    depth = depth or 0
    if frame == nil or depth > 12 then return end
    Look.EachRegion(frame, function(piece)
        if C.IsTexture(piece) and not C.mine[piece] then Look.Fade(piece) end
    end)
    local fine, kids = pcall(function() return { frame:GetChildren() } end)
    if not fine then return end
    for _, kid in ipairs(kids) do C.FadeDown(kid, depth + 1) end
end

---------------------------------------------------------------------------
-- The world map's border
---------------------------------------------------------------------------

function X.WorldMap(border, options)
    Look.Fade(Look.Path(border, "PortraitContainer", "portrait"))
    local x, metal = border.CloseButton, Look.Path(border, "NineSlice", "TopRightCorner")
    if x and metal then Look.Pin(x, "TOPRIGHT", metal, "TOPRIGHT", 0.6, -11) end
    local pair = border.MaximizeMinimizeFrame
    if pair and pair.MaximizeButton then
        ns.SkinMaxMinButtons(pair)
        pair:SetSize(32, 32)
        if x then Look.Pin(pair, "RIGHT", x, "LEFT", 8, 0) end
    end
    local map = WorldMapFrame
    if map == nil or not Once("worldMapSize") then return end
    -- The map changes size: dressed again on the next frame, while on.
    local function DressAgain()
        if C.applied then Look.Try(C.Dress, border, options) end
    end
    local function Resized() Soon(DressAgain) end
    Look.Hook(map, "Minimize", Resized)
    Look.Hook(map, "Maximize", Resized)
end

---------------------------------------------------------------------------
-- The merchant
---------------------------------------------------------------------------

local function MerchantButtons()
    local junk, buyback, tenth = MerchantSellAllJunkButton, MerchantBuyBackItem, MerchantItem10
    if MerchantFrame and junk then Look.Pin(junk, "BOTTOMLEFT", MerchantFrame, "BOTTOMLEFT", 176, 33) end
    if buyback and tenth then Look.Pin(buyback, "TOPLEFT", tenth, "BOTTOMLEFT", 44, -53) end
end

-- The old merchant foot: the game's own bottom-left piece in its left part,
-- EraUI's piece beside it in the right part, shown exactly while the left is.
local function MerchantFoot(merchant)
    local foot = MerchantFrameBottomLeftBorder
    if foot == nil then return end
    Look.Art(foot, "merchantBottom")
    Look.Crop(foot, 0, 1, 0, 0.4765625)
    foot:SetSize(256, 61)
    foot:SetDrawLayer("OVERLAY", 0)
    Look.Pin(foot, "BOTTOMLEFT", merchant, "BOTTOMLEFT", 1, 26)
    foot:SetAlpha(1)
    local tail = C.Piece(merchant, "merchantFootRight", "OVERLAY", 0)
    Look.Art(tail, "merchantBottom")
    Look.Crop(tail, 0, 0.296875, 0.4765625, 0.953125)
    tail:SetSize(76, 61)
    Look.Pin(tail, "LEFT", foot, "RIGHT", 0, 0)
    tail:SetAlpha(1)
    Look.Shown(tail, foot:IsShown())
    if not Once("merchantFoot") then return end
    -- The left part's own show and hide, when the client gives a texture
    -- those scripts; else the game's two merchant pages, the only places
    -- that show and hide it (a script the region lacks would be an error).
    local asked, scripted = Look.Ask(foot, "HasScript", "OnShow")
    if asked and scripted == true then
        Look.HookScript(foot, "OnShow", function() tail:Show() end, "chrome")
        Look.HookScript(foot, "OnHide", function() tail:Hide() end, "chrome")
        return
    end
    local function Follow() Look.Shown(tail, foot:IsShown()) end
    Look.HookGlobal("MerchantFrame_UpdateMerchantInfo", Follow)
    Look.HookGlobal("MerchantFrame_UpdateBuybackInfo", Follow)
end

function X.Merchant(merchant)
    Look.EachRegion(merchant, function(piece)
        if C.IsTexture(piece) and not C.mine[piece] then Look.Fade(piece) end
    end)
    for _, part in ipairs({ C.Part(merchant, "Inset", "Inset"), MerchantExtraCurrencyInset, MerchantExtraCurrencyBg,
        MerchantMoneyInset }) do
        C.FadeDown(part)
    end
    Look.Try(MerchantFoot, merchant)
    MerchantButtons()
    if Once("merchantRepair") then Look.HookGlobal("MerchantFrame_UpdateRepairButtons", MerchantButtons) end
    for i = 1, 13 do
        local slot = (i <= 12) and _G["MerchantItem" .. i .. "NameFrame"] or MerchantBuyBackItemNameFrame
        if slot then
            Look.Art(slot, "merchantLabelSlots")
            Look.Crop(slot, 0, 1, 0, 1)
        end
    end
end

---------------------------------------------------------------------------
-- Friends, collections
---------------------------------------------------------------------------

-- The window's marble floor tinted.
local function FloorTint(window, r, g, b)
    local marble = C.Found(window, "insetFloor")
    if marble then marble:SetVertexColor(r, g, b) end
end

function X.Friends(friends)
    local wide = Look.Number(friends:GetWidth())
    if wide and math.abs(wide - 385) <= 1 then friends:SetWidth(360) end
    FloorTint(friends, 0.9, 0.9, 0.9)
end

function X.Collections(journal)
    FloorTint(journal, 0.45, 0.42, 0.38)
end

---------------------------------------------------------------------------
-- Quest and gossip NPC windows: 69 shorter, reward items on name plates
---------------------------------------------------------------------------

local SHORTER = 69

local function Height(frame) return Look.Number(frame and frame:GetHeight()) end

-- A scroll frame's page cut to the scroll frame's height when taller.
local function FitPage(scroller)
    local fine, sheet = Look.Ask(scroller, "GetScrollChild")
    local room = Height(scroller)
    local tall = fine and Height(sheet) or nil
    if not (tall and room) or tall <= room + 0.5 then return end
    sheet:SetHeight(room)
    Look.Ask(scroller, "UpdateScrollChildRect")
end

-- A second anchor ending the region at the window's new foot.
local function NewFoot(region, window)
    local x = select(4, region:GetPoint(1))
    region:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", Look.Number(x) or 7, 27)
end

local function Shorter(frame, over)
    local tall = Height(frame)
    if tall and tall > over then frame:SetHeight(tall - SHORTER) end
end

local function Shorten(window, scrolls, panels, grounds)
    if not shortened[window] then
        shortened[window] = true
        Shorter(window, 469.99)
        for _, scroller in ipairs(scrolls) do Shorter(scroller, 200) end
        for _, panel in ipairs(panels) do
            Shorter(panel, 400)
            local bg = panel.Bg
            if bg and bg:GetPoint(1) == "TOPLEFT" then NewFoot(bg, window) end
        end
        for _, ground in ipairs(grounds) do
            if ground:GetPoint(1) then NewFoot(ground, window) end
        end
    end
    for _, scroller in ipairs(scrolls) do FitPage(scroller) end
end

local function Listed(names)
    local found = {}
    for _, called in ipairs(names) do
        if _G[called] then found[#found + 1] = _G[called] end
    end
    return found
end

-- Each reward button wears the old item name plate behind its name, once.
local function RewardPlate(button)
    if not button or platesOn[button] then return end
    local plate = button:CreateTexture(nil, "BACKGROUND", nil, 1)
    platesOn[button] = plate
    C.mine[plate] = true
    Look.Art(plate, "namePlate")
    Look.Crop(plate, 0, 1, 0, 1)
    local wide, tall = Look.Number(button:GetWidth()) or 143, Look.Number(button:GetHeight()) or 40
    Look.FitNamePlate(plate, button, 38, wide - 40, math.max(36, tall - 2))
    Look.Fade(button.NameFrame)
    Look.Fade(button.IconBorder)
end

local function EachButton(list)
    if type(list) ~= "table" then return end
    for _, button in pairs(list) do
        if type(button) == "table" then RewardPlate(button) end
    end
end

function X.QuestRewards()
    for _, holder in ipairs({ QuestInfoRewardsFrame, MapQuestInfoRewardsFrame }) do
        if holder then
            EachButton(holder.RewardButtons)
            EachButton(holder.SpellRewardButtons)
        end
    end
    for i = 1, 40 do
        local item = _G["QuestInfoItem" .. i]
        if item == nil then break end
        RewardPlate(item)
    end
end

local QUEST_SCROLLS = Look.Words("QuestDetailScrollFrame QuestProgressScrollFrame QuestRewardScrollFrame QuestGreetingScrollFrame")
local QUEST_PANELS = Look.Words("QuestFrameDetailPanel QuestFrameProgressPanel QuestFrameRewardPanel QuestFrameGreetingPanel")

function X.Quest(window)
    Shorten(window, Listed(QUEST_SCROLLS), Listed(QUEST_PANELS), {})
    X.QuestRewards()
    if not Once("questRewards") then return end
    local function Again()
        if C.applied then Look.Try(X.QuestRewards) end
    end
    Look.HookGlobal("QuestInfo_Display", Again)
    Look.HookGlobal("QuestInfo_ShowRewards", Again)
end

function X.Gossip(window)
    local greeting = window.GreetingPanel
    local scrolls, panels, grounds = {}, {}, {}
    if greeting then
        panels[1] = greeting
        scrolls[1] = greeting.ScrollBox
    end
    grounds[1] = window.Background
    Shorten(window, scrolls, panels, grounds)
end

---------------------------------------------------------------------------
-- Trade, item text, guild control, the bank, the group finder's listing
---------------------------------------------------------------------------

function X.Trade(trade)
    local overlay = trade.RecipientOverlay
    local ring = overlay and overlay.portraitFrame
    if ring == nil then return end
    Look.Art(ring, "frameMetal")
    local cut = C.Cut(135, 135)
    Look.Crop(ring, cut[1], cut[2], cut[3], cut[4])
    ring:SetSize(132, 132)
    local face = overlay.portrait
    if face then
        face:SetSize(61, 61)
        Look.Pin(ring, "TOPLEFT", face, "TOPLEFT", -7, 8)
    end
end

-- The book's scroll bar shows only while there is something to scroll
-- (when the bar can't say, it counts as yes).
local function ScrollShown(bar)
    local fine, scrollable = pcall(bar.HasScrollableExtent, bar)
    local wanted = (fine and not scrollable) and 0 or 1
    if math.abs((Look.Number(bar:GetAlpha()) or 1) - wanted) > 0.01 then bar:SetAlpha(wanted) end
end

local function ColumnFloor(bar)
    local top, foot = Look.OwnPiece(bar, "tracktop"), Look.OwnPiece(bar, "trackfoot")
    if not (top and foot) or Look.OwnPiece(bar, "chrome.columnFloor") then return end
    local black = Look.OwnTexture(bar, "chrome.columnFloor", "BACKGROUND", -1)
    C.mine[black] = true
    black:SetColorTexture(0.04, 0.04, 0.04, 1)
    black:SetPoint("TOPLEFT", top, "TOPLEFT", 5, -4)
    black:SetPoint("BOTTOMRIGHT", foot, "BOTTOMRIGHT", -5, 4)
end

function X.ItemText(window)
    local bar = Look.Path(ItemTextScrollFrame, "ScrollBar")
    if bar == nil or bar.Track == nil then return end
    Look.ThinScrollBar(bar)
    Look.TrackColumn(bar)
    ColumnFloor(bar)
    if Once("itemTextWatch") then
        local watch = Look.Build("Frame", window, nil, { size = { 1, 1 } })
        watch:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
        local waited = 0
        watch:SetScript("OnUpdate", function(_, elapsed)
            waited = waited + (Look.Number(elapsed) or 0)
            if waited < 0.05 then return end
            waited = 0
            ScrollShown(bar)
        end)
        watch:SetScript("OnShow", function() ScrollShown(bar) end)
    end
    ScrollShown(bar)
end

-- What one of guild control's widgets is, for its 1.x skin.
local function WidgetSkin(widget)
    local kind = widget.GetObjectType and widget:GetObjectType()
    if kind == "CheckButton" then return Look.SkinCheckBox end
    if kind == "Button" and widget.Left and widget.Middle and widget.Right then return Look.SkinRedButton end
    if widget.Button and widget.Text and widget.Arrow then return Look.SkinDropdown end
    return nil
end

local function GuildControlWidgets(frame, depth)
    if depth > 5 then return end
    local fine, kids = pcall(function() return { frame:GetChildren() } end)
    for _, kid in ipairs(fine and kids or {}) do
        local skin = WidgetSkin(kid)
        if skin then Look.Try(skin, kid) end
        GuildControlWidgets(kid, depth + 1)
    end
end

function X.GuildControl(window)
    GuildControlWidgets(window, 1)
    local gold = Look.GoldFont()
    Look.EachRegion(window, function(piece)
        if piece.IsObjectType and piece:IsObjectType("FontString") and piece.SetFontObject then piece:SetFontObject(gold) end
    end)
end

function X.Bank(bank)
    if type(ns.SkinBank) == "function" then Look.Try(ns.SkinBank, bank) end
end

function X.Listing(listing)
    local shut = LFGParentFrameCloseButton
    if shut == nil then return end
    ns.SkinCloseButton(shut, true)
    local metal = Look.Path(listing, "NineSlice", "TopRightCorner")
    if metal then
        Look.Pin(shut, "TOPRIGHT", metal, "TOPRIGHT", 0.6, -11)
    else
        Look.Pin(shut, "TOPRIGHT", listing, "TOPRIGHT", 4.6, 5)
    end
    shut:SetFrameLevel((Look.Number(listing:GetFrameLevel()) or 0) + 20)
end

---------------------------------------------------------------------------
-- Inspect, macros
---------------------------------------------------------------------------

-- Each frame while inspecting: the side tabs out of sight and out of reach,
-- the two bottom tabs shown exactly while the side tabs' guild tab is.
local function InspectTabs()
    local tabs = Look.Path(InspectFrame, "ModeTabs")
    if tabs == nil then return end
    if Look.Number(tabs:GetAlpha()) ~= 0 then tabs:SetAlpha(0) end
    for _, side in ipairs(type(tabs.Tabs) == "table" and tabs.Tabs or {}) do
        if side.IsMouseEnabled and side:IsMouseEnabled() then side:EnableMouse(false) end
    end
    local guildShown = tabs.GuildTab ~= nil and tabs.GuildTab:IsShown()
    Look.Shown(InspectFrameTab1, guildShown)
    Look.Shown(InspectFrameTab2, guildShown)
end

function X.Inspect(window)
    local slots = type(INSPECTPAPERDOLLFRAME_SLOTS) == "table" and INSPECTPAPERDOLLFRAME_SLOTS or {}
    for _, slot in ipairs(slots) do
        local button = type(slot) == "string" and _G[slot] or slot
        if type(button) == "table" then Look.Fade(button.BorderFrame) end
    end
    if Once("inspectWatch") then
        local watch = Look.Build("Frame", window, nil, { size = { 1, 1 } })
        watch:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
        watch:SetScript("OnUpdate", function() Look.Try(InspectTabs) end)
    end
    InspectTabs()
end

-- The macro text box's border pieces drained and dimmed (its middle kept).
local function Greyed(piece)
    piece:SetDesaturated(true)
    piece:SetVertexColor(0.85, 0.85, 0.85)
end

function X.Macro(window)
    local inset = C.Part(window, "Inset")
    local general, own = MacroFrameTab1, MacroFrameTab2
    if general and inset then Look.Pin(general, "BOTTOMLEFT", inset, "TOPLEFT", 50, -2) end
    if general and own then Look.Pin(own, "BOTTOMLEFT", general, "BOTTOMRIGHT", 2, 0) end
    local picker = MacroSelector
    if picker then
        Look.Pin(picker, "TOPLEFT", window, "TOPLEFT", 7, -63)
        local slider = picker.ScrollBar
        if slider then
            slider:ClearAllPoints()
            slider:SetPoint("TOPLEFT", picker, "TOPRIGHT", -3, 0)
            slider:SetPoint("BOTTOMLEFT", picker, "BOTTOMRIGHT", -3, 2)
        end
    end
    local slice = Look.Path(MacroFrameTextBackground, "NineSlice")
    Look.EachRegion(slice, function(piece)
        if C.IsTexture(piece) and piece ~= slice.Center then Greyed(piece) end
    end)
    if Once("macroFoot") then
        local foot = Look.InsetBox(window, 20, true)
        foot:SetPoint("TOPLEFT", window, "BOTTOMLEFT", -1, 34)
        foot:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 1, 0)
        foot:SetFrameLevel(Look.Number(window:GetFrameLevel()) or 0)
    end
end
