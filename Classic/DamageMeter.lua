-- Classic presentation for Blizzard's Damage Meter: the dark tooltip-style
-- frame and grey border, the Classic bar texture and fonts, and silver header
-- buttons.
-- Visual only. Every button, menu, name and number stays Blizzard's. The
-- meter's values are secret in combat, so nothing here reads, compares or
-- formats them, and every hook runs after Blizzard's own update.
local _, EraUI = ...
local ns = EraUI.Classic

local ADDON_NAME = "Blizzard_DamageMeter"
local BORDER = "Interface\\AddOns\\EraUI\\Media\\TooltipBorder.tga"
local FILL = { .016, .016, .02, .9 } -- Same values as the Classic tooltips.
local ROW_BG = { 0, 0, 0, .35 }

local active, watcher = false, nil
local windows = setmetatable({}, { __mode = "k" }) -- session or source window -> backdrop
local entries = setmetatable({}, { __mode = "k" })
local boxes = setmetatable({}, { __mode = "k" })
local ROW_OWNER = {}

local function Public(v) return not (issecretvalue and issecretvalue(v)) end

local function NewBackdrop(owner)
    local backdrop = CreateFrame("Frame", nil, owner, "BackdropTemplate")
    backdrop:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = BORDER, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    backdrop:SetBackdropBorderColor(1, 1, 1, 1)
    backdrop:EnableMouse(false)
    return backdrop
end

-- Blizzard re-levels each window so newer ones draw above older ones; the
-- backdrop follows so it always sits just beneath its own window.
local function Beneath(backdrop, owner)
    local level = owner:GetFrameLevel()
    if Public(level) and type(level) == "number" then backdrop:SetFrameLevel(math.max(0, level - 1)) end
end

-- Blizzard's Edit Mode background opacity drives the fill, so the native
-- slider keeps working instead of EraUI adding a second one.
local function SetFill(backdrop, alpha)
    if not Public(alpha) or type(alpha) ~= "number" then alpha = 1 end
    backdrop:SetBackdropColor(FILL[1], FILL[2], FILL[3], FILL[4] * alpha)
end

-- Blizzard applies its text-size setting as a text scale; keep it across the
-- font change.
local function Font(region, object)
    if not region or not region.SetFontObject or not object then return end
    local scale = region.GetTextScale and region:GetTextScale()
    region:SetFontObject(object)
    if Public(scale) and type(scale) == "number" and region.SetTextScale then region:SetTextScale(scale) end
end

local function Silver(texture)
    if not texture then return end
    texture:SetDesaturated(true)
    texture:SetVertexColor(.9, .9, .9)
end

-- Rows ---------------------------------------------------------------------

-- Blizzard re-sets the row background atlas on every style change and its
-- alpha on every background update.
local function PaintRow(entry)
    local bar = entry.StatusBar
    if not bar then return end
    if bar.Background then bar.Background:SetColorTexture(ROW_BG[1], ROW_BG[2], ROW_BG[3], ROW_BG[4]) end
    if bar.BackgroundEdge then bar.BackgroundEdge:SetAlpha(0) end
end

local function SkinEntry(entry)
    if not active or type(entry) ~= "table" or entries[entry] or not entry.StatusBar then return end
    entries[entry] = true
    local bar = entry.StatusBar
    -- TexPath also returns a fallback path, which the client would read as a
    -- draw layer; pass the texture alone.
    bar:SetStatusBarTexture((ns.TexPath("statusBar")))
    -- Blizzard caches the bar colour and repaints only when it changes, so the
    -- new texture is handed the current colour once. Colours come from class
    -- or ally/enemy tables, never from combat values.
    local colour, texture = entry.statusBarColor, bar:GetStatusBarTexture()
    if texture and type(colour) == "table" and colour.GetRGB then texture:SetVertexColor(colour:GetRGB()) end
    Font(bar.Name, GameFontHighlight)
    Font(bar.Value, GameFontHighlight)
    PaintRow(entry)
    ns.HookMethod(entry, "UpdateStyle", PaintRow)
    ns.HookMethod(entry, "UpdateBackground", PaintRow)
end

local function WatchRows(scrollBox)
    if not scrollBox or boxes[scrollBox] then return end
    boxes[scrollBox] = true
    if ScrollUtil and ScrollUtil.AddAcquiredFrameCallback then
        ScrollUtil.AddAcquiredFrameCallback(scrollBox, function(_, frame) SkinEntry(frame) end, ROW_OWNER)
    end
    if scrollBox.ForEachFrame then scrollBox:ForEachFrame(SkinEntry) end
end

-- Header -------------------------------------------------------------------

local function SilverDropdown(dropdown, ...)
    if not dropdown then return end
    local keys = { ... }
    local function Paint(self)
        for _, key in ipairs(keys) do Silver(self[key]) end
    end
    Paint(dropdown)
    ns.HookMethod(dropdown, "OnButtonStateChanged", Paint)
end

-- Blizzard swaps the collapse/expand art on every minimise, so the silver is
-- reapplied after it, matching the cog and dropdown buttons.
local function PaintMinimize(window)
    local button = window.MinimizeButton
    if not button then return end
    Silver(button:GetNormalTexture())
    Silver(button:GetPushedTexture())
    Silver(button:GetHighlightTexture())
end

-- A minimised window keeps only its header, so the frame shrinks to fit it.
local function LayoutWindow(window)
    local backdrop = windows[window]
    if not backdrop then return end
    local minimized = window.isMinimized == true
    backdrop:ClearAllPoints()
    backdrop:SetPoint("TOPLEFT", window, "TOPLEFT", -4, 0)
    if minimized and window.Header then
        backdrop:SetPoint("BOTTOMRIGHT", window.Header, "BOTTOMRIGHT", 4, 0)
    else
        backdrop:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 4, -4)
    end
    backdrop.divider:SetShown(not minimized)
    Beneath(backdrop, window)
    PaintMinimize(window)
end

-- Windows ------------------------------------------------------------------

local function SkinSourceWindow(source)
    if not source or windows[source] then return end
    local backdrop = NewBackdrop(source)
    windows[source] = backdrop
    backdrop:SetAllPoints(source)
    SetFill(backdrop, 1)
    Beneath(backdrop, source)
    ns.Fade(source.Background)
    ns.HookScriptOnce(source, "OnShow", function(self) Beneath(backdrop, self) end)
    WatchRows(source.ScrollBox)
end

local function SkinWindow(window)
    if not active or type(window) ~= "table" then return end
    if windows[window] then
        LayoutWindow(window)
        return
    end
    local container = window.MinimizeContainer
    if not container then
        ns.MissingPiece("DamageMeterSessionWindow.MinimizeContainer")
        return
    end

    local backdrop = NewBackdrop(window)
    windows[window] = backdrop
    local divider = backdrop:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(.55, .55, .55, .6)
    divider:SetHeight(1)
    if window.Header then
        divider:SetPoint("TOPLEFT", window.Header, "BOTTOMLEFT", 6, 1)
        divider:SetPoint("TOPRIGHT", window.Header, "BOTTOMRIGHT", -2, 1)
    end
    backdrop.divider = divider

    ns.Fade(window.Header)
    local background = container.Background
    local alpha = window.GetBackgroundAlpha and window:GetBackgroundAlpha()
    SetFill(backdrop, alpha)
    if background then
        background:SetAlpha(0)
        local hiding = false
        hooksecurefunc(background, "SetAlpha", function(self, value)
            if hiding or not Public(value) or type(value) ~= "number" then return end
            SetFill(backdrop, value)
            hiding = true
            self:SetAlpha(0)
            hiding = false
        end)
    end

    Font(window.SessionTimer, ns.FONT_GOLD)
    Font(container.NotActive, ns.FONT_GOLD)
    local typeDropdown = window.DamageMeterTypeDropdown
    if typeDropdown then Font(typeDropdown.TypeName, ns.FONT_GOLD) end
    local sessionDropdown = window.SessionDropdown
    if sessionDropdown then Font(sessionDropdown.SessionName, ns.FONT_GOLD) end
    SilverDropdown(typeDropdown, "Arrow")
    SilverDropdown(sessionDropdown, "Background", "Arrow")
    SilverDropdown(window.SettingsDropdown, "Icon")

    ns.HookMethod(window, "SetMinimized", LayoutWindow)
    ns.HookScriptOnce(window, "OnShow", LayoutWindow)
    LayoutWindow(window)

    WatchRows(container.ScrollBox)
    SkinEntry(container.LocalPlayerEntry)
    SkinSourceWindow(container.SourceWindow)
end

-- Module -------------------------------------------------------------------

local function SkinAll()
    local meter = _G.DamageMeter
    if type(meter) ~= "table" or type(meter.SetupSessionWindow) ~= "function" then return false end
    -- Every new, reused or re-shown window passes through here, including
    -- the extra windows made from the cog menu.
    ns.HookMethod(meter, "SetupSessionWindow", function(_, _, windowData)
        if type(windowData) == "table" then SkinWindow(windowData.sessionWindow) end
    end)
    for _, windowData in pairs(meter.windowDataList or {}) do
        if type(windowData) == "table" then SkinWindow(windowData.sessionWindow) end
    end
    return true
end

local function Apply()
    active = true
    if SkinAll() then return end
    if watcher then return end
    watcher = CreateFrame("Frame")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(self, _, name)
        if name ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")
        if active then ns.SafeCall(SkinAll) end
    end)
end

-- A reload setting, like the other Classic window skins: turning it off takes
-- effect on the next load, so nothing is unpicked live.
local function Restore()
    active = false
end

ns.RegisterModule("damageMeter", { apply = Apply, restore = Restore })
