-- EraUI window chrome.
-- The old window chrome on Blizzard's panel frames: the metal nine-slice
-- border with the round portrait, the small X close button, the stone title
-- strip, and the character-sheet style tabs along the bottom. Frames are
-- reskinned in place when they exist; load-on-demand windows are skinned when
-- their Blizzard addon loads.
local _, EraUI = ...
local ns = EraUI.Classic

local CORNER, EDGE = 132, 128
local BOTTOM_LIFT = 10
local MAP_LIFT = 5
local METAL = "frameMetal"

local CORNERS = {
    portrait = {
        TopLeftCorner = { 0.263671875, 0.521484375, 0.263671875, 0.521484375 },
        TopRightCorner = { 0.001953125, 0.259765625, 0.263671875, 0.521484375 },
        BottomLeftCorner = { 0.001953125, 0.259765625, 0.001953125, 0.259765625 },
        BottomRightCorner = { 0.263671875, 0.521484375, 0.001953125, 0.259765625 },
    },
    plain = {
        TopLeftCorner = { 0.525390625, 0.783203125, 0.001953125, 0.259765625 },
        TopRightCorner = { 0.001953125, 0.259765625, 0.263671875, 0.521484375 },
        BottomLeftCorner = { 0.001953125, 0.259765625, 0.001953125, 0.259765625 },
        BottomRightCorner = { 0.263671875, 0.521484375, 0.001953125, 0.259765625 },
    },
}
local EDGES = {
    TopEdge = { key = "frameMetalH", coords = { 0, 1, 0.263671875, 0.263671875 + 48 / 512 }, w = EDGE, h = 48, tileH = true },
    BottomEdge = { key = "frameMetalH", coords = { 0, 1, 0.001953125, 0.259765625 }, w = EDGE, h = CORNER, tileH = true },
    LeftEdge = { key = "frameMetalV", coords = { 0.001953125, 0.259765625, 0, 1 }, w = CORNER, h = EDGE, tileV = true },
    RightEdge = { key = "frameMetalV", coords = { 0.263671875, 0.521484375, 0, 1 }, w = CORNER, h = EDGE, tileV = true },
}

local active = false
local skinnedWindows = {}

local WINDOW_AFTER = setmetatable({}, { __mode = "k" })

local function NineSlice(frame, style, lift)
    local slice = frame.NineSlice
    if not slice then return false end
    local corners = CORNERS[style] or CORNERS.portrait
    for key, coords in pairs(corners) do
        local tex = slice[key]
        if tex then
            ns.SetTex(tex, METAL)
            tex:SetSize(CORNER, CORNER)
            tex:SetTexCoord(unpack(coords))
            if style == "plain" and key == "TopLeftCorner" then
                local point, rel, relPoint, x, y = tex:GetPoint(1)
                if point and x and x < -8 then tex:SetPoint(point, rel, relPoint, -8, y) end
            end
            if key == "BottomLeftCorner" or key == "BottomRightCorner" then
                local point, rel, relPoint, x, y = tex:GetPoint(1)
                if point then
                    if tex.fcuiBaseY == nil then tex.fcuiBaseY = y or 0 end
                    tex:SetPoint(point, rel, relPoint, x or 0, tex.fcuiBaseY + (tonumber(lift) or BOTTOM_LIFT))
                end
            end
        end
    end
    for key, edge in pairs(EDGES) do
        local tex = slice[key]
        if tex then
            local primary, fallback = ns.TexPath(edge.key)
            local ok = tex:SetTexture(primary, edge.tileH, edge.tileV)
            if ok == false then tex:SetTexture(fallback, edge.tileH, edge.tileV) end
            tex:SetSize(edge.w, edge.h)
            tex:SetTexCoord(unpack(edge.coords))
        end
    end
    return true
end

function ns.SkinCloseButton(button, keepPosition)
    if not button then return end
    button:SetSize(32, 32)
    ns.SetButtonTex(button, "Normal", "closeUp")
    ns.SetButtonTex(button, "Pushed", "closeDown")
    ns.SetButtonTex(button, "Disabled", "closeDisabled")
    ns.SetButtonTex(button, "Highlight", "closeHighlight")
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        local tex = button["Get" .. state .. "Texture"](button)
        if tex then
            tex:SetTexCoord(0, 1, 0, 1)
            tex:ClearAllPoints()
            tex:SetAllPoints(button)
            if state == "Highlight" then tex:SetBlendMode("ADD") end
        end
    end
    if not keepPosition then
        local parent = button:GetParent()
        local corner = parent and parent.NineSlice and parent.NineSlice.TopRightCorner
        button:ClearAllPoints()
        if corner then
            button:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
        else
            button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 4.6, 5)
        end
    end
end

local function LiftTab(tab)
    local point, rel, relPoint, x, y = tab:GetPoint(1)
    if not point or rel ~= tab:GetParent() then return end
    if tab.fcuiLiftedY == y then return end
    tab.fcuiLiftedY = (y or 0) + (tonumber(tab.fcuiLift) or BOTTOM_LIFT)
    tab:SetPoint(point, rel, relPoint, x or 0, tab.fcuiLiftedY)
end

function ns.FitBottomTab(tab)
    LiftTab(tab)
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    if not text then return end
    local width = math.ceil(text:GetStringWidth() or 0) + (tab.fcuiPad or 50)
    tab:SetWidth(width)
    if tab.Middle then tab.Middle:SetWidth(width - 40) end
    if tab.MiddleActive then tab.MiddleActive:SetWidth(width - 40) end
end
if type(PanelTemplates_TabResize) == "function" then
    hooksecurefunc("PanelTemplates_TabResize", function(tab) if tab and tab.fcuiTab then ns.FitBottomTab(tab) end end)
end

function ns.SkinBottomTab(tab)
    if not tab or not tab.Left then return end
    local pieces = {
        { tab.LeftActive, "tabActive", { 0, 0.15625, 0, 0.546875 }, 20, 35, "TOPLEFT", 0, 0 },
        { tab.RightActive, "tabActive", { 0.84375, 1, 0, 0.546875 }, 20, 35, "TOPRIGHT", 0, 0 },
        { tab.MiddleActive, "tabActive", { 0.15625, 0.84375, 0, 0.546875 }, 88, 35 },
        { tab.Left, "tabInactive", { 0, 0.15625, 0, 1 }, 20, 32, "TOPLEFT", 0, -4 },
        { tab.Right, "tabInactive", { 0.84375, 1, 0, 1 }, 20, 32, "TOPRIGHT", 0, -4 },
        { tab.Middle, "tabInactive", { 0.15625, 0.84375, 0, 1 }, 88, 32 },
    }
    for _, p in ipairs(pieces) do
        local tex = p[1]
        if tex then
            ns.SetTex(tex, p[2])
            tex:SetTexCoord(unpack(p[3]))
            tex:SetSize(p[4], p[5])
            if tex.SetHorizTile then tex:SetHorizTile(false) end
            if p[6] then
                tex:ClearAllPoints()
                tex:SetPoint(p[6], tab, p[6], p[7], p[8])
            end
        end
    end
    for _, key in ipairs({ "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
        if tab[key] then tab[key]:SetAlpha(0) end
    end
    tab.fcuiTab = true
    ns.FitBottomTab(tab)
    ns.SetButtonTex(tab, "Highlight", "tabHighlight")
    local hl = tab:GetHighlightTexture()
    if hl then
        hl:SetTexCoord(0, 1, 0, 1)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 5)
        hl:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 0)
        hl:SetBlendMode("ADD")
    end
end

function ns.SkinTopTab(tab)
    if not tab or not tab.Left then return end
    local pieces = {
        { tab.LeftActive, "tabActive", { 0, 0.15625, 0.546875, 0 }, 20, 35, "BOTTOMLEFT" },
        { tab.RightActive, "tabActive", { 0.84375, 1, 0.546875, 0 }, 20, 35, "BOTTOMRIGHT" },
        { tab.MiddleActive, "tabActive", { 0.15625, 0.84375, 0.546875, 0 }, 88, 35 },
        { tab.Left, "tabInactive", { 0, 0.15625, 1, 0 }, 20, 32, "BOTTOMLEFT" },
        { tab.Right, "tabInactive", { 0.84375, 1, 1, 0 }, 20, 32, "BOTTOMRIGHT" },
        { tab.Middle, "tabInactive", { 0.15625, 0.84375, 1, 0 }, 88, 32 },
    }
    for _, p in ipairs(pieces) do
        local tex = p[1]
        if tex then
            ns.SetTex(tex, p[2])
            tex:SetTexCoord(p[3][1], p[3][2], p[3][3], p[3][4])
            tex:SetSize(p[4], p[5])
            if tex.SetHorizTile then tex:SetHorizTile(false) end
            if p[6] then
                tex:ClearAllPoints()
                tex:SetPoint(p[6], tab, p[6], 0, 0)
            end
        end
    end
    for _, pair in ipairs({ { tab.Middle, tab.Left, tab.Right }, { tab.MiddleActive, tab.LeftActive, tab.RightActive } }) do
        local middle, left, right = pair[1], pair[2], pair[3]
        if middle and left and right then
            middle:ClearAllPoints()
            middle:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
            middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
        end
    end
    for _, key in ipairs({ "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do
        if tab[key] then tab[key]:SetAlpha(0) end
    end
    tab.fcuiTab = true
    tab.fcuiPad = tab.fcuiPad or 36
    ns.FitBottomTab(tab)
    ns.SetButtonTex(tab, "Highlight", "tabHighlight")
    local hl = tab:GetHighlightTexture()
    if hl then
        hl:SetTexCoord(0, 1, 1, 0)
        hl:ClearAllPoints()
        hl:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 0)
        hl:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, -5)
        hl:SetBlendMode("ADD")
    end
end

local function SkinMaxMin(button)
    if not button or not button.MaximizeButton then return end
    local pairs_ = { { button.MaximizeButton, "bigger" }, { button.MinimizeButton, "smaller" } }
    for _, p in ipairs(pairs_) do
        local b, key = p[1], p[2]
        if b then
            ns.SetButtonTex(b, "Normal", key .. "Up")
            ns.SetButtonTex(b, "Pushed", key .. "Down")
            ns.SetButtonTex(b, "Disabled", key .. "Disabled")
            ns.SetButtonTex(b, "Highlight", "closeHighlight")
            for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
                local tex = b["Get" .. state .. "Texture"](b)
                if tex then tex:SetTexCoord(0, 1, 0, 1); tex:ClearAllPoints(); tex:SetAllPoints(b) end
            end
            b:SetHitRectInsets(5, 5, 5, 5)
        end
    end
end

function ns.SkinWindow(frame, opts)
    if ns.WindowAllowed and not ns.WindowAllowed(frame) then return end
    if not frame or not active then return end
    opts = opts or {}
    local name = frame:GetName()
    if not NineSlice(frame, opts.portrait == false and "plain" or "portrait", opts.lift) then return end
    frame.fcui = frame.fcui or {}
    local portrait = frame.PortraitContainer and frame.PortraitContainer.portrait or (name and _G[name .. "Portrait"])
    if portrait and opts.portrait ~= false then
        portrait:SetSize(61, 61)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", -6, 8)
        if ns.WatchPortrait then ns.WatchPortrait(portrait) end
    end
    if frame.TitleContainer then
        frame.TitleContainer:ClearAllPoints()
        frame.TitleContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", opts.portrait == false and 6 or 58, 0)
        frame.TitleContainer:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -58, 0)
    end
    if opts.backing ~= false then
        local backing = ns.OwnTexture(frame, "backing", "BACKGROUND", -2)
        backing:SetTexture(ns.TexPath("rockBg"), "REPEAT", "REPEAT")
        backing:SetHorizTile(true)
        backing:SetVertTile(true)
        backing:SetTexCoord(0, 1, 0, 1)
        local bg = frame.Bg or (frame:GetName() and _G[frame:GetName() .. "Bg"])
        if bg and bg.SetAlpha and bg.IsObjectType and bg:IsObjectType("Texture") then
            local atlas = bg.GetAtlas and bg:GetAtlas()
            local file = bg.GetTexture and bg:GetTexture()
            local parchment = (type(atlas) == "string" and atlas:lower():find("parchment", 1, true) ~= nil)
                or (type(file) == "string" and file:lower():find("parchment", 1, true) ~= nil)
            if parchment then bg:SetAlpha(1) else bg:SetAlpha(0) end
        end
        if frame.TopTileStreaks then frame.TopTileStreaks:SetAlpha(0) end
        backing:ClearAllPoints()
        backing:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(tonumber(opts.backingRight) or 0), tonumber(opts.backingBottom) or 0)
        backing:Show()
        local streaks = ns.OwnTexture(frame, "streaks", "BACKGROUND", -1)
        streaks:SetTexture(ns.TexPath("frameSheet"), "REPEAT", "CLAMP")
        streaks:SetHorizTile(true)
        streaks:SetTexCoord(0, 1, 0.671875, 0.9609375)
        streaks:SetHeight(37)
        streaks:ClearAllPoints()
        streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -21)
        streaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -21)
        streaks:Show()
        local inset = frame.Inset or (name and _G[name .. "Inset"])
        local floor = ns.OwnTexture(frame, "insetFloor", "BACKGROUND", -1)
        if inset and inset.GetObjectType and inset:GetObjectType() == "Frame" then
            if inset.NineSlice then
                for _, region in ipairs({ inset.NineSlice:GetRegions() }) do
                    if region:IsObjectType("Texture") then region:SetAlpha(0) end
                end
            end
            if inset.Bg and inset.Bg.SetAlpha then inset.Bg:SetAlpha(0) end
            floor:SetTexture(ns.TexPath("marbleBg"), "REPEAT", "REPEAT")
            floor:SetHorizTile(true)
            floor:SetVertTile(true)
            floor:SetTexCoord(0, 1, 0, 1)
            floor:ClearAllPoints()
            floor:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, 0)
            floor:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
            floor:Show()
        else
            floor:Hide()
        end
    elseif frame.fcui and frame.fcui.backing then
        frame.fcui.backing:Hide()
        if frame.fcui.streaks then frame.fcui.streaks:Hide() end
        if frame.fcui.insetFloor then frame.fcui.insetFloor:Hide() end
    end
    local strip = ns.OwnTexture(frame, "titleStrip", "BACKGROUND")
    strip:SetTexture(ns.TexPath("frameSheet"), "REPEAT", "CLAMP")
    strip:SetHorizTile(true)
    strip:SetTexCoord(0, 1, 0.2890625, 0.421875)
    strip:SetHeight(17)
    strip:ClearAllPoints()
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", opts.portrait == false and 6 or 2, -3)
    strip:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -25, -3)
    strip:Show()
    ns.SkinCloseButton(frame.CloseButton or (name and _G[name .. "CloseButton"]))
    if frame.MaximizeMinimizeButton then
        SkinMaxMin(frame.MaximizeMinimizeButton)
        frame.MaximizeMinimizeButton:SetSize(32, 32)
        local close = frame.CloseButton or (name and _G[name .. "CloseButton"])
        if close then
            frame.MaximizeMinimizeButton:ClearAllPoints()
            frame.MaximizeMinimizeButton:SetPoint("RIGHT", close, "LEFT", 8.5, 0)
        end
    end
    if frame.TabSystem then
        for _, tab in ipairs({ frame.TabSystem:GetChildren() }) do
            tab.fcuiLift = opts.tabLift or opts.lift
            ns.SkinBottomTab(tab)
        end
    end
    if name then
        for i = 1, 10 do
            local numbered = _G[name .. "Tab" .. i]
            if numbered then
                numbered.fcuiLift = opts.tabLift or opts.lift
                if opts.topTabs then ns.SkinTopTab(numbered) else ns.SkinBottomTab(numbered) end
            end
        end
    end
    if ns.SkinScrollBarsUnder then ns.SkinScrollBarsUnder(frame, 5) end
    if opts.after then opts.after(frame) end
    skinnedWindows[frame] = true
end

function ns.SkinQuestReward(button)
    if not button or button.fcuiReward then return end
    button.fcuiReward = true
    local box = ns.OwnTexture(button, "nameBox", "BACKGROUND", 1)
    ns.SetTex(box, "lootNameFrame")
    box:SetTexCoord(0, 1, 0, 1)
    local width = (button:GetWidth() or 143) - 40
    local height = math.max(36, (button:GetHeight() or 40) - 2)
    ns.FitNamePlate(box, button, 38, width, height)
    box:Show()
    if button.NameFrame then button.NameFrame:SetAlpha(0) end
    if button.IconBorder then button.IconBorder:SetAlpha(0) end
end

function ns.SkinQuestRewards()
    for _, name in ipairs({ "QuestInfoRewardsFrame", "MapQuestInfoRewardsFrame" }) do
        local frame = _G[name]
        if frame then
            for _, key in ipairs({ "RewardButtons", "SpellRewardButtons" }) do
                for _, button in ipairs(frame[key] or {}) do ns.SkinQuestReward(button) end
            end
        end
    end
    local i = 1
    while _G["QuestInfoItem" .. i] do
        ns.SkinQuestReward(_G["QuestInfoItem" .. i])
        i = i + 1
    end
end

local LOOT_HUSHED = { "NameFrame", "BorderFrame", "HighlightNameFrame", "PushedNameFrame", "QualityStripe", "QualityText" }
local function SkinLootElement(element)
    for _, key in ipairs(LOOT_HUSHED) do
        local piece = element[key]
        if piece and piece:GetAlpha() > 0 then piece:SetAlpha(0) end
    end
    if element.fcuiLoot then return end
    element.fcuiLoot = true
    local box = ns.OwnTexture(element, "nameBox", "BACKGROUND", 1)
    ns.SetTex(box, "lootNameFrame")
    box:SetTexCoord(0, 1, 0, 1)
    box:SetSize(130, 62)
    box:ClearAllPoints()
    if element.Item then
        box:SetPoint("LEFT", element.Item, "LEFT", 30, 0)
    else
        box:SetPoint("LEFT", element, "LEFT", 35, 0)
    end
    box:Show()
    if element.Text and element.Item then
        element.Text:ClearAllPoints()
        element.Text:SetPoint("LEFT", element.Item, "RIGHT", 8, 0)
        element.Text:SetSize(93, 38)
        element.Text:SetJustifyV("MIDDLE")
    end
end

local LOOT_W, LOOT_H, LOOT_ROW = 170, 240, 41

local function FadeBlizzardArt(frame, keep)
    for _, region in ipairs({ frame:GetRegions() }) do
        local ours = frame.fcui and (function()
            for _, tex in pairs(frame.fcui) do if tex == region then return true end end
        end)()
        if not ours then
            if region:IsObjectType("Texture") then
                region:SetAlpha(0)
            elseif region:IsObjectType("FontString") and not keep[region] then
                region:SetAlpha(0)
            end
        end
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if not keep[child] then FadeBlizzardArt(child, keep) end
    end
end

local LOOT_ROWS, LOOT_PAGE_ROWS = 4, 3
local LootPager
local function LootPageStep(box, rows)
    local range = box.GetDerivedScrollRange and box:GetDerivedScrollRange() or 0
    if range <= 0 then return 1 end
    return (rows * LOOT_ROW) / range
end

local function SyncLootBoxes(frame)
    local box = frame.ScrollBox
    if not box or not box.ForEachFrame then return end
    box:ForEachFrame(function(element)
        local nameBox = element.fcui and element.fcui.nameBox
        if nameBox then
            local filled = element.Item == nil or element.Item:IsShown()
            if element.Text and (element.Text:GetText() or "") == "" then filled = false end
            nameBox:SetShown(filled and true or false)
        end
    end)
end

local function UpdateLootPages(frame)
    SyncLootBoxes(frame)
    local box, pager = frame.ScrollBox, frame.fcuiPager
    if not box or not pager then return end
    local total = box.GetDataProviderSize and box:GetDataProviderSize() or 0
    local paged = total > LOOT_ROWS
    pager:SetShown(paged)
    box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, paged and (LOOT_H - 71 - LOOT_PAGE_ROWS * LOOT_ROW) or 8)
    if paged then
        local pct = box.GetScrollPercentage and box:GetScrollPercentage() or 0
        pager.up:SetEnabled(pct > 0.001)
        pager.down:SetEnabled(pct < 0.999)
    end
end

LootPager = function(frame)
    if frame.fcuiPager then UpdateLootPages(frame) return end
    local box = frame.ScrollBox
    if not box then return end
    local pager = CreateFrame("Frame", nil, frame)
    pager:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    pager:SetSize(LOOT_W, 40)
    frame.fcuiPager = pager
    local function Arrow(kind, x)
        local button = CreateFrame("Button", nil, pager)
        button:SetSize(32, 32)
        button:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x, 6)
        button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. kind .. "-Up")
        button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. kind .. "-Down")
        button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-Scroll" .. kind .. "-Disabled")
        button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        return button
    end
    pager.up = Arrow("Up", 23)
    pager.down = Arrow("Down", 146)
    local prev = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    prev:SetPoint("LEFT", pager.up, "RIGHT", 2, 0)
    prev:SetText(PREV or "Prev")
    local nxt = pager:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    nxt:SetPoint("RIGHT", pager.down, "LEFT", -2, 0)
    nxt:SetText(NEXT or "Next")
    local function Page(direction)
        if not box.GetScrollPercentage or not box.SetScrollPercentage then return end
        local pct = box:GetScrollPercentage() + direction * LootPageStep(box, LOOT_PAGE_ROWS)
        box:SetScrollPercentage(math.max(0, math.min(1, pct)))
        PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
        UpdateLootPages(frame)
    end
    pager.up:SetScript("OnClick", function() Page(-1) end)
    pager.down:SetScript("OnClick", function() Page(1) end)
    local look = CreateFrame("Frame", nil, frame)
    look:SetScript("OnShow", function(self) self.since = 1 end)
    look:SetScript("OnUpdate", function(self, elapsed)
        self.since = (self.since or 0) + elapsed
        if self.since < 0.02 then return end
        self.since = 0
        if box.ForEachFrame then box:ForEachFrame(SkinLootElement) end
        UpdateLootPages(frame)
    end)
    frame:HookScript("OnShow", function() UpdateLootPages(frame) end)
    local slots = CreateFrame("Frame", nil, pager)
    for _, event in ipairs({ "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED", "LOOT_OPENED" }) do
        pcall(slots.RegisterEvent, slots, event)
    end
    slots:SetScript("OnEvent", function()
        C_Timer.After(0, function() if frame:IsShown() then UpdateLootPages(frame) end end)
    end)
    UpdateLootPages(frame)
end

local function SkinLoot(frame)
    local close = frame.ClosePanelButton or frame.CloseButton
    local title = frame.TitleContainer and frame.TitleContainer.TitleText
    local keep = {}
    if frame.ScrollBox then keep[frame.ScrollBox] = true end
    if close then keep[close] = true end
    if title then keep[title] = true end
    FadeBlizzardArt(frame, keep)
    if frame.fcui and frame.fcui.titleStrip then frame.fcui.titleStrip:Hide() end
    frame.GetPanelMaxHeight = function() return LOOT_H end
    frame.Resize = function(self) self:SetSize(LOOT_W, LOOT_H) end
    frame:SetSize(LOOT_W, LOOT_H)
    local art = ns.OwnTexture(frame, "lootPanel", "BACKGROUND", -2)
    ns.SetTex(art, "lootPanel")
    art:SetTexCoord(0, 1, 0, 1)
    art:SetSize(256, 256)
    art:ClearAllPoints()
    art:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 4)
    art:Show()
    local icon = ns.OwnTexture(frame, "lootIcon", "BACKGROUND", -1)
    ns.SetTex(icon, "lootIcon")
    icon:SetSize(58, 58)
    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -5)
    icon:Show()
    local skull = ns.OwnTexture(frame, "lootSkull", "ARTWORK", 0)
    ns.SetTex(skull, "lootSkull")
    skull:SetSize(58, 58)
    skull:ClearAllPoints()
    skull:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -5)
    skull:Show()
    if title then
        title:ClearAllPoints()
        title:SetPoint("CENTER", frame, "TOPLEFT", 115, -24)
    end
    if close then
        ns.SkinCloseButton(close)
        close:ClearAllPoints()
        close:SetPoint("CENTER", frame, "TOPLEFT", 177, -21)
    end
    local box = frame.ScrollBox
    if box then
        box:ClearAllPoints()
        box:SetPoint("TOPLEFT", frame, "TOPLEFT", 21, -71)
        box:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 10, 8)
        local view = box.GetView and box:GetView()
        if view and not view.fcuiLoot then
            view.fcuiLoot = true
            if view.SetElementExtent then view:SetElementExtent(LOOT_ROW) end
            if view.SetPadding then view:SetPadding(0, 0, 0, 0, 0) end
            if box.FullUpdate then box:FullUpdate(ScrollBoxConstants and ScrollBoxConstants.UpdateImmediately) end
        end
        if box.ForEachFrame then box:ForEachFrame(SkinLootElement) end
    end
    if frame.ScrollBar then frame.ScrollBar:SetAlpha(0) end
    LootPager(frame)
end

local NPC_WINDOW_TRIM = 69

local function FitPages(scrolls)
    for _, scroll in ipairs(scrolls or {}) do
        if type(scroll) == "string" then scroll = _G[scroll] end
        local page = scroll and scroll.GetScrollChild and scroll:GetScrollChild()
        local room = scroll and scroll.GetHeight and scroll:GetHeight()
        if page and room and room > 0 and page.GetHeight and (page:GetHeight() or 0) > room + 0.5 then
            page:SetHeight(room)
            if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
        end
    end
end

local function ShortenNpcWindow(frame, scrolls, panels, grounds)
    if not frame then return end
    if frame.fcuiShort then
        FitPages(scrolls)
        return
    end
    local height = frame:GetHeight()
    if not height or height < 470 then return end
    frame.fcuiShort = true
    frame:SetHeight(height - NPC_WINDOW_TRIM)
    local function Trim(region, atLeast)
        if type(region) == "string" then region = _G[region] end
        if not region or not region.GetHeight or not region.SetHeight then return end
        local tall = region:GetHeight()
        if tall and tall > atLeast then region:SetHeight(tall - NPC_WINDOW_TRIM) end
    end
    local function Foot(ground)
        if not ground or not ground.SetPoint then return end
        local point, _, _, x = ground:GetPoint(1)
        if point ~= "TOPLEFT" then return end
        ground:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", x or 7, 27)
    end
    for _, scroll in ipairs(scrolls or {}) do Trim(scroll, 200) end
    FitPages(scrolls)
    for _, panel in ipairs(panels or {}) do
        if type(panel) == "string" then panel = _G[panel] end
        Trim(panel, 400)
        if panel and panel.Bg then Foot(panel.Bg) end
    end
    for _, ground in ipairs(grounds or {}) do Foot(ground) end
end

local WINDOWS = {
    { "WorldMapFrame", child = "BorderFrame", portrait = false, backing = false, lift = MAP_LIFT, after = function(border)
        local portrait = border.PortraitContainer and border.PortraitContainer.portrait
        if portrait then portrait:SetAlpha(0) end
        local close = border.CloseButton
        local corner = border.NineSlice and border.NineSlice.TopRightCorner
        if close and corner then
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
        end
        local sizer = border.MaximizeMinimizeFrame
        if sizer and sizer.MaximizeButton then
            SkinMaxMin(sizer)
            sizer:SetSize(32, 32)
            if close then
                sizer:ClearAllPoints()
                sizer:SetPoint("RIGHT", close, "LEFT", 8, 0)
            end
        end
        if not border.fcuiMapHooked and WorldMapFrame then
            border.fcuiMapHooked = true
            for _, method in ipairs({ "Minimize", "Maximize" }) do
                ns.HookMethod(WorldMapFrame, method, function()
                    if active then C_Timer.After(0, function() ns.SkinWindow(border, { portrait = false, backing = false, lift = MAP_LIFT, after = WINDOW_AFTER[border] }) end) end
                end)
            end
        end
    end },
    { "MerchantFrame", lift = 5, after = function(frame)
        local function FadeFrame(f)
            if not f then return end
            for _, region in ipairs({ f:GetRegions() }) do
                if region:IsObjectType("Texture") then region:SetAlpha(0) end
            end
            for _, child in ipairs({ f:GetChildren() }) do FadeFrame(child) end
        end
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("Texture") then
                local ours = false
                for _, tex in pairs(frame.fcui or {}) do if tex == region then ours = true end end
                if not ours then region:SetAlpha(0) end
            end
        end
        FadeFrame(frame.Inset or _G["MerchantFrameInset"])
        FadeFrame(_G["MerchantExtraCurrencyInset"])
        FadeFrame(_G["MerchantExtraCurrencyBg"])
        FadeFrame(_G["MerchantMoneyInset"])
        local left = _G["MerchantFrameBottomLeftBorder"]
        if left then
            ns.SetTex(left, "merchantBottom")
            left:SetTexCoord(0, 1, 0, 0.4765625)
            left:SetSize(256, 61)
            left:ClearAllPoints()
            left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 26)
            left:SetDrawLayer("OVERLAY", 0)
            left:SetAlpha(1)
            local right = ns.OwnTexture(frame, "bottomRight", "OVERLAY", 0)
            ns.SetTex(right, "merchantBottom")
            right:SetTexCoord(0, 0.296875, 0.4765625, 0.953125)
            right:SetSize(76, 61)
            right:ClearAllPoints()
            right:SetPoint("LEFT", left, "RIGHT", 0, 0)
            right:SetAlpha(1)
            if not frame.fcuiBottomHooked then
                frame.fcuiBottomHooked = true
                left:HookScript("OnShow", function() right:Show() end)
                left:HookScript("OnHide", function() right:Hide() end)
            end
            right:SetShown(left:IsShown())
        end
        local function PlaceBottomButtons()
            local junk = _G["MerchantSellAllJunkButton"]
            if junk then
                junk:ClearAllPoints()
                junk:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 176, 33)
            end
            local buyback, item10 = _G["MerchantBuyBackItem"], _G["MerchantItem10"]
            if buyback and item10 then
                buyback:ClearAllPoints()
                buyback:SetPoint("TOPLEFT", item10, "BOTTOMLEFT", 44, -53)
            end
        end
        PlaceBottomButtons()
        ns.HookGlobal("MerchantFrame_UpdateRepairButtons", PlaceBottomButtons)
        for i = 1, 12 do
            local slot = _G["MerchantItem" .. i .. "NameFrame"]
            if slot then
                ns.SetTex(slot, "merchantLabelSlots")
                slot:SetTexCoord(0, 1, 0, 1)
            end
        end
        local buyback = _G["MerchantBuyBackItemNameFrame"]
        if buyback then ns.SetTex(buyback, "merchantLabelSlots") end
    end },
    { "MailFrame", lift = 5 },
    { "FriendsFrame", lift = 5, tabLift = 3, after = function(frame)
        if frame:GetWidth() and math.abs(frame:GetWidth() - 385) < 1 then frame:SetWidth(360) end
        local floor = frame.fcui and frame.fcui.insetFloor
        if floor then floor:SetVertexColor(ns.PANE_SHADE, ns.PANE_SHADE, ns.PANE_SHADE) end
    end },
    { "QuestFrame", lift = 5, backingRight = 5, after = function(frame)
        ShortenNpcWindow(frame, { "QuestDetailScrollFrame", "QuestProgressScrollFrame", "QuestRewardScrollFrame", "QuestGreetingScrollFrame" },
            { "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel", "QuestFrameGreetingPanel" })
        ns.SkinQuestRewards()
        ns.HookGlobal("QuestInfo_Display", ns.SkinQuestRewards)
        ns.HookGlobal("QuestInfo_ShowRewards", ns.SkinQuestRewards)
    end },
    { "GossipFrame", lift = 5, backingRight = 5, after = function(frame)
        local panel = frame.GreetingPanel
        ShortenNpcWindow(frame, { panel and panel.ScrollBox }, { panel }, { frame.Background })
    end },
    { "TradeFrame", lift = 5, after = function(frame)
        local overlay = frame.RecipientOverlay
        if not overlay or not overlay.portraitFrame then return end
        local ring = overlay.portraitFrame
        ns.SetTex(ring, METAL)
        ring:SetTexCoord(unpack(CORNERS.portrait.TopLeftCorner))
        ring:SetSize(CORNER, CORNER)
        local portrait = overlay.portrait
        if portrait then
            portrait:SetSize(61, 61)
            ring:ClearAllPoints()
            ring:SetPoint("TOPLEFT", portrait, "TOPLEFT", -7, 8)
        end
    end },
    { "TaxiFrame" },
    { "DressUpFrame" },
    { "PetStableFrame" },
    { "ItemTextFrame", after = function(frame)
        local scroll = ItemTextScrollFrame
        local bar = scroll and scroll.ScrollBar
        if not bar or not bar.Track then return end
        ns.SkinMinimalScrollBar(bar)
        ns.ScrollTrackArt(bar)
        local art = bar.fcui
        if art and art.trackTop and art.trackBottom and not art.trackFloor then
            local floor = ns.OwnTexture(bar, "trackFloor", "BACKGROUND", -1)
            floor:SetColorTexture(0.04, 0.04, 0.04, 1)
            floor:ClearAllPoints()
            floor:SetPoint("TOPLEFT", art.trackTop, "TOPLEFT", 5, -4)
            floor:SetPoint("BOTTOMRIGHT", art.trackBottom, "BOTTOMRIGHT", -5, 4)
            floor:Show()
        end
        if frame.fcuiBarWatch then return end
        local watch = CreateFrame("Frame", nil, frame)
        frame.fcuiBarWatch = watch
        local function Sync()
            local can = true
            if bar.HasScrollableExtent then
                local ok, result = pcall(bar.HasScrollableExtent, bar)
                if ok then can = result and true or false end
            end
            local alpha = can and 1 or 0
            if math.abs((bar:GetAlpha() or 1) - alpha) > 0.01 then bar:SetAlpha(alpha) end
        end
        watch:SetScript("OnUpdate", function(self, elapsed)
            self.since = (self.since or 0) + elapsed
            if self.since < 0.05 then return end
            self.since = 0
            Sync()
        end)
        watch:SetScript("OnShow", Sync)
        Sync()
    end },
    { "TabardFrame" },
    { "GuildRegistrarFrame" },
    { "PetitionFrame" },
    { "GuildControlUI", addon = "Blizzard_GuildControlUI", portrait = false, after = function(frame)
        local function Dress(node, depth)
            if depth <= 0 or not node.GetChildren then return end
            for _, child in ipairs({ node:GetChildren() }) do
                local kind = child.GetObjectType and child:GetObjectType()
                if kind == "CheckButton" then
                    if ns.SkinCheckbox then ns.SkinCheckbox(child) end
                elseif kind == "Button" and child.Left and child.Middle and child.Right then
                    if ns.SkinRedButton then ns.SkinRedButton(child) end
                elseif child.Button and child.Text and child.Arrow then
                    if ns.SkinDropdown then ns.SkinDropdown(child) end
                end
                Dress(child, depth - 1)
            end
        end
        Dress(frame, 5)
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:IsObjectType("FontString") and region.SetFontObject and ns.FONT_GOLD then
                region:SetFontObject(ns.FONT_GOLD)
            end
        end
    end },
    { "BankFrame", after = function(frame) if ns.SkinBank then ns.SkinBank(frame) end end },
    { "LootFrame", backing = false, after = SkinLoot },
    { "LFGListingFrame", addon = "Blizzard_GroupFinder_VanillaStyle", lift = 5, after = function(frame)
        local close = _G["LFGParentFrameCloseButton"]
        if close then
            ns.SkinCloseButton(close, true)
            local corner = frame.NineSlice and frame.NineSlice.TopRightCorner
            close:ClearAllPoints()
            if corner then
                close:SetPoint("TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
            else
                close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 4.6, 5)
            end
            close:SetFrameLevel(frame:GetFrameLevel() + 20)
        end
    end },
    { "LFGBrowseFrame", addon = "Blizzard_GroupFinder_VanillaStyle", lift = 5 },
    { "LFGWhoListFrame", addon = "Blizzard_GroupFinder_VanillaStyle", lift = 5 },
    { "InspectFrame", addon = "Blizzard_InspectUI", backingBottom = 4, after = function(frame)
        for _, name in ipairs(INSPECTPAPERDOLLFRAME_SLOTS or {}) do
            local slot = _G[name]
            if slot and slot.BorderFrame then slot.BorderFrame:SetAlpha(0) end
        end
        local side = frame.ModeTabs
        if side and not frame.fcuiTabWatch then
            local watch = CreateFrame("Frame", nil, frame)
            frame.fcuiTabWatch = watch
            watch:SetScript("OnUpdate", function()
                if side:GetAlpha() > 0 then side:SetAlpha(0) end
                for _, tab in ipairs(side.Tabs or {}) do
                    if tab:IsMouseEnabled() then tab:EnableMouse(false) end
                end
                local guild = side.GuildTab and side.GuildTab:IsShown() and true or false
                local first, second = _G["InspectFrameTab1"], _G["InspectFrameTab2"]
                if first and first:IsShown() ~= guild then first:SetShown(guild) end
                if second and second:IsShown() ~= guild then second:SetShown(guild) end
            end)
        end
    end },
    { "MacroFrame", addon = "Blizzard_MacroUI", topTabs = true, lift = 2, after = function(frame)
        local first, second = _G["MacroFrameTab1"], _G["MacroFrameTab2"]
        local inset = frame.Inset or _G["MacroFrameInset"]
        if first and inset then
            first:ClearAllPoints()
            first:SetPoint("BOTTOMLEFT", inset, "TOPLEFT", 50, -2)
            if second then
                second:ClearAllPoints()
                second:SetPoint("BOTTOMLEFT", first, "BOTTOMRIGHT", 2, 0)
            end
        end
        local selector = frame.MacroSelector
        if selector then
            selector:ClearAllPoints()
            selector:SetPoint("TOPLEFT", frame, "TOPLEFT", 7, -63)
            local bar = selector.ScrollBar
            if bar then
                bar:ClearAllPoints()
                bar:SetPoint("TOPRIGHT", selector, "TOPRIGHT", -3, 0)
                bar:SetPoint("BOTTOMRIGHT", selector, "BOTTOMRIGHT", -3, 2)
            end
        end
        local box = _G["MacroFrameTextBackground"]
        local slice = box and box.NineSlice
        if slice then
            for _, region in ipairs({ slice:GetRegions() }) do
                if region ~= slice.Center and region.SetDesaturated then
                    region:SetDesaturated(true)
                    region:SetVertexColor(0.85, 0.85, 0.85)
                end
            end
        end
        if ns.SkillInsetBox and not frame.fcuiFoot then
            local foot = ns.SkillInsetBox(frame, 20, true)
            foot:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -1, 34)
            foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 1, 0)
            foot:SetFrameLevel(frame:GetFrameLevel())
            frame.fcuiFoot = foot
        end
    end },
    { "ClassTrainerFrame", addon = "Blizzard_TrainerUI" },
    { "AuctionHouseFrame", addon = "Blizzard_AuctionHouseUI", lift = 9, backingRight = 6, backingBottom = 8 },
    { "CommunitiesFrame", addon = "Blizzard_Communities" },
    { "CollectionsJournal", addon = "Blizzard_Collections", after = function(frame)
        local floor = frame.fcui and frame.fcui.insetFloor
        if floor then floor:SetVertexColor(0.45, 0.42, 0.38) end
    end },
    { "EncounterJournal", addon = "Blizzard_EncounterJournal" },
    { "AchievementFrame", addon = "Blizzard_AchievementUI" },
    { "ProfessionsFrame", addon = "Blizzard_Professions", backingBottom = 4 },
    { "ProfessionsBookFrame", addon = "Blizzard_ProfessionsBook" },
    { "GuildBankFrame", addon = "Blizzard_GuildBankUI" },
    { "CalendarFrame", addon = "Blizzard_Calendar", portrait = false },
    { "ItemSocketingFrame", addon = "Blizzard_ItemSocketingUI" },
    { "AddonList", addon = "Blizzard_AddonList", portrait = false },
}

local watcher

local function SkinKnown()
    for _, entry in ipairs(WINDOWS) do
        local frame = _G[entry[1]]
        if frame and entry.child then frame = frame[entry.child] end
        if frame and not skinnedWindows[frame] then
            WINDOW_AFTER[frame] = entry.after
            ns.SkinWindow(frame, { portrait = entry.portrait, backing = entry.backing, lift = entry.lift, tabLift = entry.tabLift, backingRight = entry.backingRight, backingBottom = entry.backingBottom, topTabs = entry.topTabs, after = entry.after })
        end
    end
end

local function Apply()
    active = true
    SkinKnown()
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:RegisterEvent("ADDON_LOADED")
        watcher:SetScript("OnEvent", function() if active then SkinKnown() end end)
    end
end

local function Restore()
    active = false
    for frame in pairs(skinnedWindows) do
        if frame.fcui and frame.fcui.titleStrip then frame.fcui.titleStrip:Hide() end
    end
    ns.needsReload = true
end

ns.RegisterModule("panels", { apply = Apply, restore = Restore })
