-- EraUI settings panel.
-- The settings window in the dress of the old options dialogs: the dialog box
-- with its header plate, the category list and the page each in a thin-bordered
-- inset, the old blue bar under the chosen category, and every control in the
-- old widget art. Blizzard's panel, lists and controls keep their behavior.
local _, EraUI = ...
local ns = EraUI.Classic

local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background"
local DIALOG_BORDER = "Interface\\DialogFrame\\UI-DialogBox-Border"
local DIALOG_HEADER = "Interface\\DialogFrame\\UI-DialogBox-Header"
local INSET_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
local INSET_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

local active = false

local function Inset(parent, key, anchorTo, l, t, r, b)
    parent.fcui = parent.fcui or {}
    local inset = parent.fcui[key]
    if not inset then
        inset = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        inset:SetBackdrop({
            bgFile = INSET_BG, edgeFile = INSET_BORDER, tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        inset:SetBackdropColor(0.34, 0.32, 0.30, 0.55)
        inset:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        inset:SetFrameLevel(parent:GetFrameLevel())
        parent.fcui[key] = inset
    end
    inset:ClearAllPoints()
    inset:SetPoint("TOPLEFT", anchorTo, "TOPLEFT", l, t)
    inset:SetPoint("BOTTOMRIGHT", anchorTo, "BOTTOMRIGHT", r, b)
    inset:Show()
    return inset
end

local function Yellow(text)
    if text and text.SetTextColor then text:SetTextColor(1, 0.82, 0) end
end

local function SkinSettingRow(row)
    if not active or not row then return end
    Yellow(row.Text)
    if row.Checkbox then ns.SkinCheckbox(row.Checkbox) end
    if row.SliderWithSteppers then ns.SkinSliderWithSteppers(row.SliderWithSteppers) end
    if row.Control then
        if row.Control.Dropdown then ns.SkinDropdown(row.Control.Dropdown) end
        if row.Control.IncrementButton then ns.SkinStepper(row.Control.IncrementButton, true) end
        if row.Control.DecrementButton then ns.SkinStepper(row.Control.DecrementButton, false) end
    end
    local button = row.Button
    if button and button.IsObjectType and button:IsObjectType("Button") then
        local left = button.Left
        local atlas = left and left.GetAtlas and left:GetAtlas() or ""
        if atlas:find("ListExpand") then
            if not button.fcuiHeader then
                button.fcuiHeader = true
                ns.FadeRegions(button)
                local hl = button:GetHighlightTexture()
                if hl then hl:SetAlpha(0) end
                if button.Text then
                    button.Text:SetFontObject(ns.FONT_GOLD)
                    Yellow(button.Text)
                    button.Text:SetJustifyH("LEFT")
                    button.Text:ClearAllPoints()
                    button.Text:SetPoint("LEFT", button, "LEFT", 8, 0)
                    button.Text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
                end
                local glow = ns.OwnTexture(button, "headerGlow", "HIGHLIGHT")
                ns.SetTex(glow, "questLogHighlight")
                glow:SetTexCoord(0, 1, 0, 1)
                glow:SetBlendMode("ADD")
                glow:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -4)
                glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 4)
            end
        else
            ns.SkinRedButton(button)
        end
    end
    if row.Title and row.Title.SetFontObject and not row.Text then row.Title:SetFontObject("GameFontHighlightLarge") end
end

local function SkinCategoryRow(row)
    if not active or not row or row.fcuiCategory then return end
    row.fcuiCategory = true
    if row.Background then
        row.Background:SetAlpha(0)
        if row.Label then row.Label:SetFontObject("GameFontHighlight") end
    end
    local tex = row.Texture
    if tex and row.IsObjectType and row:IsObjectType("Button") then
        if row.Label then
            Yellow(row.Label)
            hooksecurefunc(row.Label, "SetFontObject", function(label) if active then Yellow(label) end end)
        end
        local function Dress()
            ns.SetTex(tex, "questLogHighlight")
            tex:SetTexCoord(0, 1, 0, 1)
            tex:SetVertexColor(1, 1, 0)
            tex:SetBlendMode("ADD")
        end
        Dress()
        hooksecurefunc(tex, "SetAtlas", function() if active then Dress() end end)
    end
end

local function SkinPanel()
    local panel = SettingsPanel
    if not panel or panel.fcuiSkinned then return end
    panel.fcuiSkinned = true
    panel.fcui = panel.fcui or {}
    if panel.NineSlice then
        for _, region in ipairs({ panel.NineSlice:GetRegions() }) do
            if region:IsObjectType("Texture") then region:SetAlpha(0) end
        end
    end
    if panel.Bg then
        ns.FadeRegions(panel.Bg)
        for _, child in ipairs({ panel.Bg:GetChildren() }) do ns.FadeRegions(child) end
    end
    ns.FadeRegions(panel)
    local box = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    box:SetBackdrop({
        bgFile = DIALOG_BG, edgeFile = DIALOG_BORDER, tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    box:SetAllPoints(panel)
    box:SetFrameLevel(panel:GetFrameLevel())
    box:SetBackdropColor(1, 1, 1, 1)
    panel.fcui.box = box
    local plate = ns.OwnTexture(panel, "plate", "ARTWORK", 0)
    plate:SetTexture(DIALOG_HEADER)
    plate:SetSize(256, 64)
    plate:ClearAllPoints()
    plate:SetPoint("TOP", panel, "TOP", 0, 12)
    plate:Show()
    local title = panel.NineSlice and panel.NineSlice.Text
    if title then
        title:SetFontObject(ns.FONT_GOLD)
        title:ClearAllPoints()
        title:SetPoint("TOP", plate, "TOP", 0, -14)
    end
    ns.SkinCloseButton(panel.ClosePanelButton, true)
    if panel.ClosePanelButton then
        panel.ClosePanelButton:ClearAllPoints()
        panel.ClosePanelButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    end
    ns.SkinMinimalTab(panel.GameTab)
    ns.SkinMinimalTab(panel.AddOnsTab)
    ns.SkinRedButton(panel.CloseButton)
    ns.SkinRedButton(panel.ApplyButton)
    local categories = panel.CategoryList
    if categories then
        local listInset = Inset(panel, "listInset", categories, 0, 8, 8, -8)
        if panel.GameTab then
            panel.GameTab:ClearAllPoints()
            panel.GameTab:SetPoint("BOTTOMLEFT", listInset, "TOPLEFT", 10, -2)
        end
        ns.SkinMinimalScrollBar(categories.ScrollBar)
        if categories.ScrollBox and categories.ScrollBox.ForEachFrame then categories.ScrollBox:ForEachFrame(SkinCategoryRow) end
    end
    if panel.Container then Inset(panel, "pageInset", panel.Container, -8, 8, 8, -8) end
    local list = panel.Container and panel.Container.SettingsList
    if list then
        if list.Header then
            ns.FadeRegions(list.Header)
            if list.Header.DefaultsButton then ns.SkinRedButton(list.Header.DefaultsButton) end
            if list.Header.Title then list.Header.Title:SetFontObject("GameFontHighlightLarge") end
        end
        ns.SkinMinimalScrollBar(list.ScrollBar)
        if list.ScrollBox and list.ScrollBox.ForEachFrame then list.ScrollBox:ForEachFrame(SkinSettingRow) end
    end
    if not panel.fcuiLook then
        panel.fcuiLook = CreateFrame("Frame", nil, panel)
        panel.fcuiLook:SetScript("OnUpdate", function(self, elapsed)
            self.since = (self.since or 0) + elapsed
            if self.since < 0.05 then return end
            self.since = 0
            if not active then return end
            local cats = panel.CategoryList and panel.CategoryList.ScrollBox
            if cats and cats.ForEachFrame then cats:ForEachFrame(SkinCategoryRow) end
            local rows = panel.Container and panel.Container.SettingsList and panel.Container.SettingsList.ScrollBox
            if rows and rows.ForEachFrame then
                rows:ForEachFrame(function(row)
                    local data = row.GetElementData and row:GetElementData()
                    if data == nil or row.fcuiDressedFor ~= data then
                        row.fcuiDressedFor = data
                        SkinSettingRow(row)
                    end
                end)
            end
        end)
    end
end

local hooked = false
local function Apply()
    active = true
    if not SettingsPanel then ns.MissingPiece("SettingsPanel") return end
    if not hooked then
        hooked = true
        SettingsPanel:HookScript("OnShow", function() if active then SkinPanel() end end)
    end
    if SettingsPanel:IsShown() then SkinPanel() end
end

local function Restore()
    active = false
    ns.needsReload = true
end

ns.RegisterModule("settingsPanel", { apply = Apply, restore = Restore })
