-- Where the old Classic options page lives: the page in the game's Settings
-- (Options > AddOns > EraUI, the "options" registry entry registers it at
-- login) and the floating window (ns.OpenOptions; Core/Integration.lua
-- replaces that with /era's own settings, so players open /era instead).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local O = Look.Options

-- The floating window's page and the Settings page: width, rows in view,
-- the search box's top and the list's top.
local FLOATING = { width = 470, visible = 10, searchTop = -50, listTop = -110 }
local CANVAS_ROWS, CANVAS_SEARCH, CANVAS_LIST = 16, -16, -76
local floating, canvas, category

local function Floating()
    if floating then return floating end
    local made = Look.Build("Frame", UIParent, "BackdropTemplate", { name = "EraUIClassicOptions", size = { 470, 458 },
        strata = "HIGH", movable = true, clamped = true, mouse = true, drag = "LeftButton" })
    made:SetToplevel(true)
    made:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    made:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    made:SetBackdropColor(1, 1, 1, 1)
    made:SetBackdropBorderColor(1, 1, 1, 1)
    if ns.DarkBackdrop then ns.DarkBackdrop(made) end
    local shade = Look.OwnTexture(made, "shade", "BACKGROUND", -8)
    shade:SetColorTexture(0.03, 0.03, 0.03, 0.45)
    Look.Inside(shade, made, 11, 12, 12, 11)
    made:SetScript("OnDragStart", made.StartMoving)
    made:SetScript("OnDragStop", made.StopMovingOrSizing)
    local plate = Look.HeaderPlate(made, "ARTWORK")
    local heading = Look.OwnLabel(made, "heading", "GameFontNormal", "OVERLAY")
    Look.Pin(heading, "TOP", plate, "TOP", 0, -14)
    heading:SetText("EraUI")
    local shut = CreateFrame("Button", nil, made, "UIPanelCloseButton")
    ns.SkinCloseButton(shut, true)
    Look.Pin(shut, "TOPRIGHT", made, "TOPRIGHT", -6, -6)
    shut:SetScript("OnClick", function() made:Hide() end)
    made:Hide()
    floating = made
    if type(ns.CloseOnEscape) == "function" then ns.CloseOnEscape(made) end
    O.Build(made, FLOATING)
    return made
end

-- The page for the game's Settings, built once (also ns.optionsCanvas).
local function Canvas()
    if canvas then return canvas end
    canvas = Look.Build("Frame", UIParent, nil, { name = "EraUIClassicOptionsCanvas", size = { 620, 560 }, hidden = true })
    canvas:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    ns.optionsCanvas = canvas
    local across = math.max(470, Look.Number(canvas:GetWidth()) or 620)
    O.Build(canvas, { width = across, visible = CANVAS_ROWS, searchTop = CANVAS_SEARCH, listTop = CANVAS_LIST })
    return canvas
end

-- The floating window, shown or hidden. (Core/Integration.lua replaces
-- this with /era; the window is kept as OpenDetailedOptions.)
local function Toggle()
    local made = Floating()
    if made:IsShown() then made:Hide() else made:Show() end
end

-- Both pages read again, each only while it shows.
local function RefreshShown()
    for _, page in ipairs({ floating, canvas }) do
        if page and page:IsShown() then O.Refresh(page) end
    end
end

-- Options > AddOns > EraUI in the game's Settings.
local function RegisterPage()
    local settings = Settings
    if type(settings) ~= "table" or type(settings.RegisterCanvasLayoutCategory) ~= "function" then return end
    local fine, made = pcall(settings.RegisterCanvasLayoutCategory, Canvas(), "EraUI")
    if not fine or made == nil then return end
    category = made
    if type(settings.RegisterAddOnCategory) == "function" then Look.Try(settings.RegisterAddOnCategory, made) end
end

local function OpenInSettings()
    local settings = Settings
    if category and type(settings) == "table" and type(settings.OpenToCategory) == "function" then
        local id = type(category.GetID) == "function" and category:GetID() or category.ID
        if Look.Try(settings.OpenToCategory, id) then return end
    end
    if type(ns.Print) == "function" then ns.Print("Use /eraui-classic help for commands.") end
end

local function Nothing() end

ns.OptionsCanvas, ns.OpenOptions, ns.RefreshOptionsWindow, ns.OpenBlizzardSettings = Canvas, Toggle, RefreshShown, OpenInSettings

-- No look of its own: its one-time init (at login) registers the page.
ns.RegisterModule("options", { init = RegisterPage, apply = Nothing, restore = Nothing })
