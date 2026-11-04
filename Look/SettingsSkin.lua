-- The game's Settings window as the old options dialog: the dialog box and
-- header plate, the category list and the page each in a thin bordered
-- inset, the old highlight bar under the chosen category, and every control
-- in the old art (check boxes, sliders, drop downs, arrows, scroll bars,
-- tabs, red buttons). Built the first time the window opens while on; a
-- small watcher on it dresses the rows the game makes or reuses as pages
-- scroll. The Settings window isn't one the game guards, and only colours,
-- art, anchors and EraUI's own frames are touched, so this also runs in a
-- fight.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local T = { applied = false, built = false }
Look.SettingsSkin = T

local categoryRows = Look.Weak() -- a category row: true once dressed
local rowData = Look.Weak()      -- a settings row: the element data it was dressed for
local expanders = Look.Weak()    -- an expand header button: true once dressed
local insets = Look.Weak()       -- a place (category list, page): its inset box
local NO_DATA = {}
local TITLE_GLOW = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"

local function SettingsWindow()
    return SettingsPanel
end

local function FadeTextures(owner)
    Look.EachRegion(owner, function(piece)
        if piece.IsObjectType and piece:IsObjectType("Texture") then Look.Fade(piece) end
    end)
end

-- A thin bordered inset of EraUI's own on the window, made once per place.
local function Inset(place, left, top, right, bottom)
    local window = SettingsWindow()
    local box = insets[place]
    if box == nil then
        box = Look.Build("Frame", window, "BackdropTemplate", { size = { 64, 64 } })
        box:SetFrameLevel(Look.Number(window:GetFrameLevel()) or 0)
        box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 } })
        box:SetBackdropColor(0.34, 0.32, 0.30, 0.55)
        box:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
        insets[place] = box
    end
    Look.Inside(box, place, left, -top, -right, bottom)
    return box
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

-- The chosen category's bar: the old highlight in yellow, additive.
local function Highlight(bar)
    if not T.applied or bar == nil then return end
    bar:SetTexture(TITLE_GLOW)
    Look.Crop(bar, 0, 1, 0, 1)
    bar:SetVertexColor(1, 1, 0)
    bar:SetBlendMode("ADD")
end

local function Gold(label)
    if T.applied and label then label:SetTextColor(1, 0.82, 0) end
end

local function DressCategory(entry)
    if categoryRows[entry] then return end
    categoryRows[entry] = true
    if entry.Background ~= nil then
        Look.Fade(entry.Background)
        if entry.Label and GameFontHighlight then entry.Label:SetFontObject(GameFontHighlight) end
    end
    local isButton = entry.GetObjectType and entry:GetObjectType() == "Button"
    if not isButton or entry.Texture == nil then return end
    if entry.Label then
        Gold(entry.Label)
        Look.Hook(entry.Label, "SetFontObject", Gold)
    end
    Highlight(entry.Texture)
    Look.Hook(entry.Texture, "SetAtlas", Highlight)
end

-- An expand header: the game's art faded, its text gold from end to end,
-- the old highlight bar on hover.
local function Expander(header)
    if expanders[header] then return end
    expanders[header] = true
    FadeTextures(header)
    Look.Fade(header.GetHighlightTexture and header:GetHighlightTexture() or nil)
    local words = header.Text
    if words then
        words:SetFontObject(Look.GoldFont())
        if words.SetJustifyH then words:SetJustifyH("LEFT") end
        Look.Inside(words, header, 8, 0, 8, 0)
    end
    local hover = Look.OwnTexture(header, "settingsGlow", "HIGHLIGHT")
    hover:SetTexture(TITLE_GLOW)
    hover:SetBlendMode("ADD")
    Look.Inside(hover, header, 0, 4, 0, 4)
end

local function Expandable(header)
    local fine, atlas = Look.Ask(header.Left, "GetAtlas")
    return fine and type(atlas) == "string" and not Look.Secret(atlas) and atlas:find("ListExpand", 1, true) ~= nil
end

local function DressSetting(entry)
    if entry.Text then entry.Text:SetTextColor(1, 0.82, 0) end
    Look.SkinCheckBox(entry.Checkbox)
    Look.SkinSlider(entry.SliderWithSteppers)
    local control = entry.Control
    if control ~= nil then
        Look.SkinDropdown(control.Dropdown)
        Look.SkinStepper(control.IncrementButton, true)
        Look.SkinStepper(control.DecrementButton, false)
    end
    local inner = entry.Button
    if inner and inner.GetObjectType and inner:GetObjectType() == "Button" then
        if Expandable(inner) then Expander(inner) else Look.SkinRedButton(inner) end
    end
    if entry.Title and not entry.Text and GameFontHighlightLarge then entry.Title:SetFontObject(GameFontHighlightLarge) end
end

local function EachFrame(box, visit)
    if box == nil or type(box.ForEachFrame) ~= "function" then return end
    local found = {}
    pcall(box.ForEachFrame, box, function(frame) found[#found + 1] = frame end)
    for _, frame in ipairs(found) do Look.Try(visit, frame) end
end

local function DressIfNew(entry)
    local fine, data = Look.Ask(entry, "GetElementData")
    data = fine and data or NO_DATA
    if rowData[entry] == data and data ~= NO_DATA then return end
    rowData[entry] = data
    DressSetting(entry)
end

-- Every 0.05 s while the window shows: new category rows dressed, and each
-- settings row whose data changed since (rows are reused as pages scroll).
function T.Watch()
    if not T.applied then return end
    local window = SettingsWindow()
    EachFrame(Look.Path(window, "CategoryList", "ScrollBox"), DressCategory)
    EachFrame(Look.Path(window, "Container", "SettingsList", "ScrollBox"), DressIfNew)
end

---------------------------------------------------------------------------
-- The look
---------------------------------------------------------------------------

local function FadeOldArt(window)
    FadeTextures(window.NineSlice)
    local backing = window.Bg
    Look.EachRegion(backing, Look.Fade)
    local fine, parts = pcall(function() return backing and { backing:GetChildren() } or {} end)
    for _, part in ipairs(fine and parts or {}) do Look.EachRegion(part, Look.Fade) end
    FadeTextures(window)
end

local function Lists(window)
    local sidebar = window.CategoryList
    if sidebar ~= nil then
        local box = Inset(sidebar, 0, 8, 8, -8)
        if window.GameTab then Look.Pin(window.GameTab, "BOTTOMLEFT", box, "TOPLEFT", 10, -2) end
        if sidebar.ScrollBar then Look.ThinScrollBar(sidebar.ScrollBar) end
    end
    if window.Container then Inset(window.Container, -8, 8, 8, -8) end
    local settingsList = Look.Path(window, "Container", "SettingsList")
    if settingsList == nil then return end
    local header = settingsList.Header
    if header then
        FadeTextures(header)
        if header.DefaultsButton then Look.SkinRedButton(header.DefaultsButton) end
        if header.Title and GameFontHighlightLarge then header.Title:SetFontObject(GameFontHighlightLarge) end
    end
    if settingsList.ScrollBar then Look.ThinScrollBar(settingsList.ScrollBar) end
end

local function Watcher(window)
    local watcher = Look.Build("Frame", window, nil, { size = { 1, 1 } })
    watcher:SetPoint("TOPLEFT", window, "TOPLEFT", 0, 0)
    local waited = 0
    watcher:SetScript("OnUpdate", function(_, elapsed)
        waited = waited + (Look.Number(elapsed) or 0)
        if waited < 0.05 then return end
        waited = 0
        T.Watch()
    end)
    return watcher
end

local function Build()
    local window = SettingsWindow()
    if T.built or window == nil then return end
    T.built = true
    FadeOldArt(window)
    T.box = Look.DialogBox(window)
    T.plate = Look.HeaderPlate(window, "ARTWORK")
    local heading = Look.Path(window, "NineSlice", "Text")
    if heading then
        heading:SetFontObject(Look.GoldFont())
        Look.Pin(heading, "TOP", T.plate, "TOP", 0, -14)
    end
    if window.ClosePanelButton then
        ns.SkinCloseButton(window.ClosePanelButton, true)
        Look.Pin(window.ClosePanelButton, "TOPRIGHT", window, "TOPRIGHT", -4, -4)
    end
    Look.SkinMinimalTab(window.GameTab)
    Look.SkinMinimalTab(window.AddOnsTab)
    Look.SkinRedButton(window.CloseButton)
    Look.SkinRedButton(window.ApplyButton)
    Lists(window)
    T.watcher = Watcher(window)
    T.Watch()
end

local function Opened()
    if T.applied then Look.Try(Build) end
end

local function SettingsOn()
    T.applied = true
    local window = SettingsWindow()
    if window == nil then return end
    Look.HookScript(window, "OnShow", Opened, "settingsPanel")
    if window:IsShown() then Opened() end
end

-- Every pass while off: the reload note only when the look went on.
local function SettingsOff()
    if T.built then ns.needsReload = true end
    T.applied = false
end

ns.RegisterModule("settingsPanel", { apply = SettingsOn, restore = SettingsOff })
