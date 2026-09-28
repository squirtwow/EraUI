-- The font of the damage and healing numbers over targets. The game reads it
-- once as you log in, so a new choice shows after logging out and back in; a
-- /reload isn't enough. The size is the game's own world text scale, which
-- applies at once.
local _, EraUI = ...

local PATH = "Interface\\AddOns\\EraUI\\Media\\Fonts\\"

-- In the order the settings list them. Blizzard's own leaves the game's font
-- alone; the rest are bundled with EraUI or ship with the game.
EraUI.CombatFonts = {
    { key = "blizzard", name = "Blizzard default" },
    { key = "pepsi", name = "Pepsi", file = PATH .. "PEPSI_pl.ttf" },
    { key = "bangers", name = "Bangers", file = PATH .. "Bangers-Regular.ttf" },
    { key = "luckiestguy", name = "Luckiest Guy", file = PATH .. "LuckiestGuy-Regular.ttf" },
    { key = "lilitaone", name = "Lilita One", file = PATH .. "LilitaOne-Regular.ttf" },
    { key = "titanone", name = "Titan One", file = PATH .. "TitanOne-Regular.ttf" },
    { key = "blackopsone", name = "Black Ops One", file = PATH .. "BlackOpsOne-Regular.ttf" },
    { key = "russoone", name = "Russo One", file = PATH .. "RussoOne-Regular.ttf" },
    { key = "bungee", name = "Bungee", file = PATH .. "Bungee-Regular.ttf" },
    { key = "permanentmarker", name = "Permanent Marker", file = PATH .. "PermanentMarker-Regular.ttf" },
    { key = "pressstart2p", name = "Press Start 2P", file = PATH .. "PressStart2P-Regular.ttf" },
    { key = "skurri", name = "Skurri", file = "Fonts\\SKURRI.TTF" },
    { key = "morpheus", name = "Morpheus", file = "Fonts\\MORPHEUS.TTF" },
    { key = "friz", name = "Friz Quadrata", file = "Fonts\\FRIZQT__.TTF" },
    { key = "arialn", name = "Arial Narrow", file = "Fonts\\ARIALN.TTF" },
}

-- The chosen font; anything unknown reads as the default.
function EraUI:CombatFont()
    local key = self:GetSavedSetting("damageFont")
    for _, font in ipairs(self.CombatFonts) do
        if font.key == key then return font end
    end
    for _, font in ipairs(self.CombatFonts) do
        if font.key == self.settingDefaults.damageFont then return font end
    end
end

-- Your own heals and the damage you take scroll above your character in
-- Blizzard's combat text, which has a font of its own. It keeps its size and
-- outline, and changes at once.
local function ApplySelfText(file)
    local font = CombatTextFont
    if not (file and font and font.GetFont and font.SetFont) then return end
    local _, size, flags = font:GetFont()
    font:SetFont(file, size or 25, flags or "OUTLINE")
end

-- That combat text gives each message CombatTextFont just before it shows,
-- so the chosen font goes on straight after, whatever that font holds.
local hookedSelfText
local function HookSelfText()
    if hookedSelfText or not (CombatText and CombatText.InitializeFontString and hooksecurefunc) then return end
    hookedSelfText = true
    hooksecurefunc(CombatText, "InitializeFontString", function(_, text)
        local font = EraUIDB and EraUIDB.enabled ~= false and EraUI:CombatFont()
        if not (font and font.file and text and text.GetFont and text.SetFont) then return end
        local _, size, flags = text:GetFont()
        text:SetFont(font.file, size or 25, flags or "OUTLINE")
    end)
end

-- Called as EraUI's settings load, before the game reads the font at login,
-- and again whenever the choice changes.
function EraUI:ApplyCombatFont()
    local font = self:CombatFont()
    -- The font the game took as it loaded; a new choice waits for the next login.
    if self.combatFontAtLoad == nil then self.combatFontAtLoad = font and font.key or false end
    if not (font and font.file) then return end
    DAMAGE_TEXT_FONT = font.file
    ApplySelfText(font.file)
    HookSelfText()
end

-- Whether the chosen font is a new one, which the game only shows after you
-- log out and back in.
function EraUI:CombatFontWaiting()
    local font = self:CombatFont()
    return self.combatFontAtLoad ~= nil and font ~= nil and font.key ~= self.combatFontAtLoad
end

-- Blizzard's combat text loads when first needed; the font follows it.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(self, _, name)
    if name ~= "Blizzard_CombatText" then return end
    self:UnregisterAllEvents()
    if EraUIDB and EraUIDB.enabled ~= false then EraUI:ApplyCombatFont() end
end)

-- The game's world text scale, the size of those numbers. Newer clients
-- renamed the setting, so use whichever one this client has.
EraUI.COMBAT_TEXT_SCALE = { min = 50, max = 250 } -- percent
local SCALE_SETTINGS = { "WorldTextScale_v2", "WorldTextScale" }
local scaleSetting -- false once looked for and not found

local function ScaleSetting()
    if scaleSetting ~= nil then return scaleSetting or nil end
    if not (C_CVar and C_CVar.GetCVar) then return nil end
    scaleSetting = false
    for _, name in ipairs(SCALE_SETTINGS) do
        if C_CVar.GetCVar(name) ~= nil then scaleSetting = name; return name end
    end
    -- Otherwise look for it among all of the game's settings.
    local ok, all = pcall(function() return C_Console and C_Console.GetAllCommands and C_Console.GetAllCommands() end)
    for _, info in ipairs(ok and type(all) == "table" and all or {}) do
        local name = type(info) == "table" and info.command
        if type(name) == "string" and name:lower():find("^worldtextscale") and C_CVar.GetCVar(name) ~= nil then
            scaleSetting = name
            return name
        end
    end
    return nil
end

function EraUI:CombatTextScale()
    local name = ScaleSetting()
    local value = name and C_CVar and C_CVar.GetCVar and tonumber(C_CVar.GetCVar(name))
    return value and math.floor(value * 100 + .5) or nil
end

function EraUI:SetCombatTextScale(percent)
    local name = ScaleSetting()
    if InCombatLockdown() or not (name and C_CVar and C_CVar.SetCVar) then return false end
    local limits = self.COMBAT_TEXT_SCALE
    percent = math.max(limits.min, math.min(limits.max, math.floor(percent + .5)))
    return pcall(C_CVar.SetCVar, name, tostring(percent / 100))
end
