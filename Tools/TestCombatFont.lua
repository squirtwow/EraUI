-- Run the actual damage text font module and the chat link toggle: which font
-- the game is given at login, the world text size, and clicking a link again
-- to close its tooltip.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat = false
local cvars = { WorldTextScale = "1" }
InCombatLockdown = function() return combat end
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value) assert(not combat, "CVar set in combat"); cvars[name] = value end,
}

local settings = {}
local frames = {}
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end
-- Blizzard's combat text font, for your own heals and the damage you take.
CombatTextFont = { file = "Fonts\\FRIZQT__.TTF", size = 25, flags = "OUTLINE" }
function CombatTextFont:GetFont() return self.file, self.size, self.flags end
function CombatTextFont:SetFont(file, size, flags) self.file, self.size, self.flags = file, size, flags end
-- That combat text gives each message's text CombatTextFont as it shows.
local function FontString()
    local text = {}
    function text:SetFontObject(object) self.file, self.size, self.flags = object:GetFont() end
    function text:GetFont() return self.file, self.size, self.flags end
    function text:SetFont(file, size, flags) self.file, self.size, self.flags = file, size, flags end
    return text
end
CombatText = {}
function CombatText:InitializeFontString(text) text:SetFontObject(CombatTextFont) end
hooksecurefunc = function(a, b, c)
    local owner, name, hook = _G, a, b
    if type(a) == "table" then owner, name, hook = a, b, c end
    local original = owner[name]
    owner[name] = function(...) original(...); hook(...) end
end
EraUIDB = { enabled = true }
local function Module()
    local E = { modules = {}, settingDefaults = { damageFont = "pepsi", linkToggle = true } }
    function E:RegisterModule(name, module) self.modules[name] = module end
    function E:GetSavedSetting(key) return settings[key] end
    E.GetSetting = E.GetSavedSetting
    assert(loadfile("Modules/CombatFont.lua"))("EraUI", E)
    return E
end
local E = Module()

-- The font -------------------------------------------------------------------------------

local ORIGINAL = "Fonts\\FRIZQT__.TTF"
DAMAGE_TEXT_FONT = ORIGINAL
settings.damageFont = "pepsi"
E:ApplyCombatFont()
Equal(DAMAGE_TEXT_FONT, "Interface\\AddOns\\EraUI\\Media\\Fonts\\PEPSI_pl.ttf", "Pepsi given to the game by default")
Equal(CombatTextFont.file, DAMAGE_TEXT_FONT, "and to the combat text over you, for your own heals")
Equal(CombatTextFont.size == 25 and CombatTextFont.flags, "OUTLINE", "keeping its size and outline")
local hooked = CombatText.InitializeFontString
E:ApplyCombatFont()
Equal(CombatText.InitializeFontString, hooked, "the combat text is hooked once")
CombatTextFont.file = ORIGINAL -- even if the game puts its own font back
local message = FontString()
CombatText:InitializeFontString(message)
Equal(message.file, "Interface\\AddOns\\EraUI\\Media\\Fonts\\PEPSI_pl.ttf", "each message over you still gets the font")
Equal(message.size == 25 and message.flags, "OUTLINE", "at the game's size and outline")
EraUIDB.enabled = false
message = FontString()
CombatText:InitializeFontString(message)
Equal(message.file, ORIGINAL, "left alone while EraUI is off")
EraUIDB.enabled = true
settings.damageFont = "bangers"
E:ApplyCombatFont()
Equal(DAMAGE_TEXT_FONT, "Interface\\AddOns\\EraUI\\Media\\Fonts\\Bangers-Regular.ttf", "a bundled font")
settings.damageFont = "skurri"
E:ApplyCombatFont()
Equal(DAMAGE_TEXT_FONT, "Fonts\\SKURRI.TTF", "or one that ships with the game")
DAMAGE_TEXT_FONT = ORIGINAL
settings.damageFont = "blizzard"
E:ApplyCombatFont()
Equal(DAMAGE_TEXT_FONT, ORIGINAL, "Blizzard default leaves the game's font alone")
settings.damageFont = "bangers"
CombatTextFont.file = ORIGINAL
for _, f in ipairs(frames) do
    if f.events.ADDON_LOADED then f.onEvent(f, "ADDON_LOADED", "Blizzard_CombatText") end
end
Equal(CombatTextFont.file, "Interface\\AddOns\\EraUI\\Media\\Fonts\\Bangers-Regular.ttf", "reapplied when Blizzard's combat text loads")
settings.damageFont = "comic sans"
Equal(E:CombatFont().key, "pepsi", "an unknown choice reads as the default")
local files, keys = {}, {}
for _, font in ipairs(E.CombatFonts) do
    Equal(keys[font.key], nil, font.key .. " listed once")
    keys[font.key] = true
    if font.file and font.file:find("Media\\Fonts\\", 1, true) then files[#files + 1] = font.file:match("([^\\]+)$") end
end
Equal(#files, 10, "Pepsi and nine free fonts bundled (their files are checked by Tools/CheckFonts.mjs)")

-- A new font waits for the next login.
local waiting = Module()
settings.damageFont = "pepsi"
Equal(waiting:CombatFontWaiting(), false, "nothing waiting before the font is applied")
waiting:ApplyCombatFont()
Equal(waiting:CombatFontWaiting(), false, "nor with the font the game loaded")
settings.damageFont = "bangers"
waiting:ApplyCombatFont()
Equal(waiting:CombatFontWaiting(), true, "a new font waits for a log out")
settings.damageFont = "pepsi"
Equal(waiting:CombatFontWaiting(), false, "and not once it's back")
settings.damageFont = "bangers"

-- The size ---------------------------------------------------------------------------------

Equal(E:CombatTextScale(), 100, "size read from the game's world text scale")
Equal(E:SetCombatTextScale(150), true, "size set")
Equal(cvars.WorldTextScale, "1.5", "as the game's own scale")
E:SetCombatTextScale(900)
Equal(cvars.WorldTextScale, "2.5", "kept within its limits")
E:SetCombatTextScale(10)
Equal(cvars.WorldTextScale, "0.5", "at both ends")
combat = true
Equal(E:SetCombatTextScale(100), false, "never changed in combat")
Equal(cvars.WorldTextScale, "0.5", "left as it was")
combat = false
-- Newer clients renamed the setting.
cvars = { WorldTextScale_v2 = "1.2" }
local newer = Module()
Equal(newer:CombatTextScale(), 120, "the renamed setting is read")
newer:SetCombatTextScale(150)
Equal(cvars.WorldTextScale_v2, "1.5", "and set")
-- Or found among the game's settings under another name.
cvars = { worldTextScale_v3 = "0.8" }
C_Console = { GetAllCommands = function() return { { command = "nameplateMaxDistance" }, { command = "worldTextScale_v3" } } end }
Equal(Module():CombatTextScale(), 80, "found by name among the game's settings")
cvars = {}
local none = Module()
Equal(none:CombatTextScale(), nil, "no setting: no size")
Equal(none:SetCombatTextScale(100), false, "and nothing changed")
C_Console = nil

-- Clicking a chat link again closes its tooltip ---------------------------------------------

local modified = false
IsModifiedClick = function() return modified end
local tooltip = { shown = false, scripts = {} }
function tooltip:IsShown() return self.shown end
function tooltip:Hide()
    if self.shown then
        self.shown = false
        for _, fn in ipairs(self.scripts.OnHide or {}) do fn(self) end
    end
end
function tooltip:HookScript(event, fn)
    self.scripts[event] = self.scripts[event] or {}
    table.insert(self.scripts[event], fn)
end
ItemRefTooltip = tooltip
local blizzardToggles = false -- whether the game itself already closes a repeated link
SetItemRef = function(link)
    if modified or not link:find("^item:") and not link:find("^spell:") then return end
    if blizzardToggles and tooltip.shown and tooltip.link == link then tooltip:Hide(); return end
    tooltip.shown, tooltip.link = true, link
end
assert(loadfile("Modules/ExtraQoL.lua"))("EraUI", E)
E.modules.ExtraQoL:SetupLinkToggle()
settings.linkToggle = true

local sword, shield = "item:19019", "item:17066"
SetItemRef(sword)
Equal(tooltip.shown, true, "first click shows the item")
SetItemRef(sword)
Equal(tooltip.shown, false, "clicking it again closes it")
SetItemRef(sword)
Equal(tooltip.shown, true, "and again opens it")
SetItemRef(shield)
Equal(tooltip.shown and tooltip.link, shield, "another link swaps to it")
SetItemRef(shield)
Equal(tooltip.shown, false, "then closes on its second click")
SetItemRef(sword)
modified = true
SetItemRef(sword)
Equal(tooltip.shown, true, "Shift or Ctrl clicks never close it")
modified = false
tooltip:Hide()
SetItemRef("fcui:welcome")
SetItemRef(sword)
Equal(tooltip.shown, true, "EraUI's own links don't count")
settings.linkToggle = false
SetItemRef(sword)
Equal(tooltip.shown, true, "switched off, the game's own behaviour stays")
settings.linkToggle = true
tooltip:Hide()
blizzardToggles = true
SetItemRef(sword)
SetItemRef(sword)
Equal(tooltip.shown, false, "if the game already closes it, it stays closed")
SetItemRef(sword)
Equal(tooltip.shown, true, "and the next click opens it, not closes it straight away")

io.write("Damage font and link toggle checks passed: " .. checks .. " assertions.\n")
