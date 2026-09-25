-- EraUI shared control skins.
-- The close button, bottom tabs and the classic panel button, used across
-- the window modules.
local _, EraUI = ...
local ns = EraUI.Classic

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

function ns.FitBottomTab(tab)
    local text = tab.Text or (tab.GetFontString and tab:GetFontString())
    if not text then return end
    local width = math.ceil(text:GetStringWidth() or 0) + (tab.fcuiPad or 50)
    tab:SetWidth(width)
    if tab.Middle then tab.Middle:SetWidth(width - 40) end
    if tab.MiddleActive then tab.MiddleActive:SetWidth(width - 40) end
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

function ns.PanelButton(parent, text, width)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width or 96, 22)
    button:SetText(text)
    EraUI:SkinClassicRedButton(button, "CharacterPanel")
    return button
end

-- An inset box with an iron border, shared by the skill windows.
local MARBLE_SHADE = 0.9
function ns.SkillInsetBox(parent, edge, bare)
    edge = edge or 16
    local inset = edge / 4
    local box = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    if not bare then
        local floor = box:CreateTexture(nil, "BACKGROUND")
        floor:SetTexture(ns.TexPath("marbleBg"), "REPEAT", "REPEAT")
        floor:SetHorizTile(true)
        floor:SetVertTile(true)
        floor:SetTexCoord(0, 1, 0, 1)
        floor:SetVertexColor(MARBLE_SHADE, MARBLE_SHADE, MARBLE_SHADE)
        ns.ThemeTexture(floor, "marbleBg")
        floor:SetPoint("TOPLEFT", box, "TOPLEFT", inset, -inset)
        floor:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -inset, inset)
        box.floor = floor
    end
    if box.SetBackdrop then
        box:SetBackdrop({
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            edgeSize = edge,
            insets = { left = inset, right = inset, top = inset, bottom = inset },
        })
    end
    return box
end

