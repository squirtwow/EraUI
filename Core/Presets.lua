-- Presets switch EraUI's Classic look as one group and leave every
-- quality-of-life choice alone. "Quality of Life only" keeps Blizzard's modern
-- interface.
-- Used by the /era setup walkthrough and the Presets window in /era.
local _, E = ...
local P = {}
E.Presets = P

-- The Classic skins, all on by default; presets switch these together.
P.LOOK = {
    "actionBars", "unitFrames", "castBars", "minimap", "friendlyNameplates", "enemyNameplates",
    "characterPanel", "spellbook", "talentWindow", "bagsBank", "merchantSkin", "mailSkin", "auctionHouse",
    "professions", "trainer", "questLog", "questDialogs", "questTracker", "socialWindows", "groupFinderPvp",
    "gameMenu", "blizzardSettings", "lootWindow", "popups", "tooltipSkin", "otherWindows",
}
-- Optional looks: Quality of Life only switches them off too; the Classic
-- look leaves them as chosen. Dark Aura Borders is not one: it only shows in
-- Dark Mode, so presets leave it alone and choosing Dark Mode later gives it.
P.LOOK_EXTRAS = { "damageMeterSkin", "classColourBorders", "darkMode" }

P.NAMES = { classic = "Classic look", qol = "Quality of Life only", custom = "Custom" }

-- With Questie's tracker chosen, EraUI's Quest Tracker option is off on
-- purpose (see QuestTrackerChoice), which still counts as the Classic look.
-- Only while Questie is installed with its tracker on: an old choice must
-- never keep the Classic tracker off after Questie is gone.
local function QuestieTrackerChosen()
    local tracker = E.modules and E.modules.QuestTrackerChoice
    return E:GetSavedSetting("questTrackerChoice") == "questie"
        and tracker ~= nil and tracker:QuestieTrackerOn() == true
end

local function Wanted(name, key)
    if name == "classic" then
        if key == "questTracker" and QuestieTrackerChosen() then return false end
        return true
    end
    return false
end

local function Saved(key)
    return E:GetSavedSetting(key) and true or false
end

-- The settings a preset would change, as { key = value }, and how many.
function P:Changes(name)
    local changes, count = {}, 0
    for _, key in ipairs(self.LOOK) do
        local want = Wanted(name, key)
        if Saved(key) ~= want then changes[key] = want; count = count + 1 end
    end
    if name == "qol" then
        for _, key in ipairs(self.LOOK_EXTRAS) do
            if Saved(key) then changes[key] = false; count = count + 1 end
        end
    end
    return changes, count
end

-- "classic" when every Classic skin is on, "qol" when all are off,
-- otherwise "custom". Optional looks and QoL options never affect it.
function P:Current()
    local classic, qol = true, true
    for _, key in ipairs(self.LOOK) do
        local on = Saved(key)
        if on ~= Wanted("classic", key) then classic = false end
        if on then qol = false end
    end
    return classic and "classic" or qol and "qol" or "custom"
end

-- Saves the preset's settings. Most are visual and apply on the next reload;
-- callers reload from their own click.
function P:Apply(name)
    local changes, count = self:Changes(name)
    self.applying = true
    for key, value in pairs(changes) do E:SetSetting(key, value) end
    self.applying = false
    return count
end

-- The plain X of the /era window, shared by EraUI's own pop-ups.
function E:CreateCloseX(parent, onClick)
    local close = CreateFrame("Button", nil, parent)
    close:SetSize(36, 36)
    close:SetPoint("TOPRIGHT", -8, -8)
    local label = close:CreateFontString(nil, "OVERLAY")
    local font, _, flags = GameFontHighlight:GetFont()
    label:SetFont(font, 20, flags or "")
    label:SetTextColor(.58, .62, .68)
    label:SetPoint("CENTER")
    label:SetText("X")
    close:SetScript("OnClick", onClick)
    close:SetScript("OnEnter", function() label:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() label:SetTextColor(.58, .62, .68) end)
    close.label = label
    return close
end

-- Presets window ----------------------------------------------------------------

local window

local function ClassColour()
    local _, class = UnitClass("player")
    local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
        or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
    if c then return c.r, c.g, c.b end
    return .7, .7, .7
end

local function PaintButton(button, strong)
    local r, g, b = ClassColour()
    local k = strong and .3 or .2
    button:SetBackdropColor(r * k, g * k, b * k, 1)
    button:SetBackdropBorderColor(r, g, b, 1)
end

local function Button(parent, label, width, height, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    button.label:SetPoint("TOP", 0, -10)
    button.label:SetText(label)
    button:SetScript("OnClick", onClick)
    button:SetScript("OnEnter", function(self) PaintButton(self, true) end)
    button:SetScript("OnLeave", function(self) PaintButton(self, false) end)
    return button
end

local function Choose(name)
    local _, count = P:Changes(name)
    window.pending = name
    window.choices:Hide()
    window.confirm:Show()
    if count == 0 then
        window.message:SetText("You're already using " .. P.NAMES[name] .. ".")
        window.apply:Hide()
        window.back.label:SetText("OK")
    else
        window.message:SetText(string.format("%s changes %d setting%s and reloads your UI.\nYour Quality of Life choices stay as they are.",
            P.NAMES[name], count, count == 1 and "" or "s"))
        window.apply:Show()
        window.back.label:SetText("Back")
    end
end

function P:ApplyAndReload()
    -- The client only honours a reload from a live click outside combat, and
    -- only while the clicked window is still shown.
    if InCombatLockdown() then
        window.message:SetText("|cffff5555Finish combat first, then apply again.|r")
        return
    end
    self:Apply(window.pending)
    ReloadUI()
end

local function Build()
    window = CreateFrame("Frame", "EraUIPresets", UIParent, "BackdropTemplate")
    window:SetSize(460, 250)
    window:SetPoint("CENTER", 0, 80)
    -- The same foreground layer as the Changelog window, above /era.
    window:SetFrameStrata("FULLSCREEN_DIALOG")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", window.StopMovingOrSizing)
    window:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    window:SetBackdropColor(.026, .029, .037, 1)
    window:SetBackdropBorderColor(.19, .20, .24, 1)
    window:Hide()
    table.insert(UISpecialFrames, "EraUIPresets")

    window.stripe = window:CreateTexture(nil, "ARTWORK")
    window.stripe:SetPoint("TOPLEFT", 1, -1)
    window.stripe:SetPoint("TOPRIGHT", -1, -1)
    window.stripe:SetHeight(3)
    local title = window:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -24)
    title:SetText("Presets")
    window.current = window:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    window.current:SetPoint("TOPRIGHT", -52, -28)

    window.choices = CreateFrame("Frame", nil, window)
    window.choices:SetAllPoints()
    local function Choice(name, caption, x)
        local button = Button(window.choices, P.NAMES[name], 190, 110, function() Choose(name) end)
        button:SetPoint("TOPLEFT", x, -64)
        local note = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        note:SetPoint("TOPLEFT", 12, -34)
        note:SetWidth(166)
        note:SetJustifyH("LEFT")
        note:SetTextColor(.72, .74, .8)
        note:SetText(caption)
        return button
    end
    window.classic = Choice("classic", "The 2004 interface: action bars, unit frames, windows and more.", 24)
    window.qol = Choice("qol", "Keep Blizzard's modern interface and use only EraUI's Quality of Life options.", 246)
    local footer = window.choices:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    footer:SetPoint("BOTTOM", 0, 20)
    footer:SetWidth(412)
    footer:SetText("Your Quality of Life choices are never changed by a preset.")

    window.confirm = CreateFrame("Frame", nil, window)
    window.confirm:SetAllPoints()
    window.confirm:Hide()
    window.message = window.confirm:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    window.message:SetPoint("TOPLEFT", 24, -72)
    window.message:SetWidth(412)
    window.message:SetJustifyH("LEFT")
    window.apply = Button(window.confirm, "Apply & reload", 160, 34, function() P:ApplyAndReload() end)
    window.apply:SetPoint("BOTTOMRIGHT", -24, 24)
    window.apply.label:SetPoint("TOP", 0, -10)
    window.back = Button(window.confirm, "Back", 110, 34, function()
        if not window.apply:IsShown() then window:Hide(); return end -- "OK": nothing to change.
        window.confirm:Hide()
        window.choices:Show()
    end)
    window.back:SetPoint("BOTTOMLEFT", 24, 24)

    window.close = E:CreateCloseX(window, function() window:Hide() end)
end

function P:Show()
    if not window then Build() end
    local r, g, b = ClassColour()
    window.stripe:SetColorTexture(r, g, b, 1)
    window.current:SetText("Current: " .. P.NAMES[self:Current()])
    for _, button in ipairs({ window.classic, window.qol, window.apply, window.back }) do PaintButton(button, false) end
    window.confirm:Hide()
    window.choices:Show()
    window:Show()
    window:Raise()
end
