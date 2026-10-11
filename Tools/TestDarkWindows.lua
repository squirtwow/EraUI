-- Dark Windows on the real Core/Appearance.lua and the windows it darkens
-- (Classic/Widgets.lua, Core/ClassicWidgets.lua, Classic/OptionsWindow.lua,
-- Classic/GameMenu.lua, Classic/SpellBook.lua, Classic/Professions.lua). In
-- Dark Mode, with its tick on: the classic red buttons lose their red and
-- take the lifted grey, their glow only its colour; the game menu's border
-- and header plate take Dark Mode's grey and its fill the buttons' grey; the
-- spellbook's and the Professions window's parchment goes the brown-grey
-- page shade, never below the floor, and the small dark text on it turns
-- light while spell names keep their gold; the Professions window's frame
-- takes the grey, Blizzard's own cards included, painted again when the game
-- fills a card. All follow the Darkness slider; a pass with nothing new sets
-- nothing; off, every piece gets its own colours back once and is then left
-- alone (one Dark Mode tints by itself keeps that grey); without Dark Mode
-- nothing is touched or hooked, the Professions window included. (The
-- trainer's own glow copy is checked in Tools/TestTrainer.lua.)
-- EraUI's other dialog boxes (Modules/Popups.lua, Classic/Status.lua,
-- Classic/Welcome.lua, Classic/Widgets.lua's drop down lists, Core/Utils.lua,
-- the inset boxes of Classic/Controls.lua and Classic/TradeSkill.lua) and a
-- window skinned by Classic/Panels.lua: borders and header plates in the
-- grey, fills times the buttons' grey (their own colour kept, a box with no
-- fill left without one), restored with the tick. Black Pages: the empty
-- slots, professions pages, cards and spell plates go a desaturated near
-- black that stays at every Darkness, and EraUI's flat near-black cover
-- shows over the spellbook's parchment alone; the spellbook's four pieces
-- (its frame, title strip and icon ring are drawn in them), the rings and the
-- bars' frames take the frame's grey and follow the slider; the text keeps
-- its colours, and the game's dark small text on the Professions window's
-- spell plates and cards turns light only while the pages are black; off
-- gives today's exact brown-grey; both ways live. The class trainer, built
-- on the real skill shell: every edge and border piece of its window and
-- boxes, the money box's gold-edged border included, in Dark Mode's grey,
-- and its greeting's room between the title strip and the list.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
local function Near(a, b) return math.abs(a - b) < 1e-6 end

-- A permissive widget: the methods below keep state; any other method whose
-- name starts with one of these verbs is a no-op, so the modules' layout
-- calls need no list. Other keys are plain fields (nil unless set).
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Lock", "Unlock", "Add", "Clear",
    "Raise", "Lower", "Update", "Play", "Stop" }
local function IsMethodName(key)
    if type(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local FONT_COLOURS = {
    SubSpellFont = { .35, .2, 0, 1 }, GameFontBlack = { 0, 0, 0, 1 }, GameFontNormal = { 1, .82, 0, 1 },
}
local Methods = {}
local textures, fonts, frames = {}, {}, {}
local function Widget(props)
    local w = props or {}
    w.points, w.scripts, w.hooks, w.attrs, w.sets = {}, {}, {}, {}, 0
    if w.shown == nil then w.shown = true end
    return setmetatable(w, { __index = function(_, key)
        local method = Methods[key]
        if method then return method end
        if IsMethodName(key) then return function() end end
    end })
end
local function Texture(parent)
    local t = Widget({ objectType = "Texture", parent = parent, colour = { 1, 1, 1 } })
    textures[#textures + 1] = t
    return t
end
-- What the player sees: a texture's colour and whether it is desaturated;
-- sets counts every colour call.
function Methods:SetVertexColor(r, g, b) self.colour = { r, g, b }; self.sets = self.sets + 1 end
function Methods:SetDesaturated(on) self.desaturated = on and true or false; self.sets = self.sets + 1 end
function Methods:SetTextColor(r, g, b, a) self.textColour = { r, g, b, a }; self.sets = self.sets + 1 end
function Methods:GetTextColor() local c = self.textColour; return c[1], c[2], c[3], c[4] end
function Methods:SetBackdropColor(r, g, b, a) self.fill = { r, g, b, a }; self.sets = self.sets + 1 end
function Methods:SetBackdropBorderColor(r, g, b, a) self.border = { r, g, b, a }; self.sets = self.sets + 1 end
-- The backdrop a frame was given, so every classic dialog box can be found.
function Methods:SetBackdrop(info) self.backdrop = info end
function Methods:GetStringHeight() return 0 end
function Methods:SetTexture(file) self.file = file; return true end
function Methods:SetColorTexture(r, g, b, a) self.colourTexture = { r, g, b, a }; self.sets = self.sets + 1 end
function Methods:Show() if not self.shown then self.shown = true; self:Fire("OnShow") end end
function Methods:Hide() self.shown = false end
function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Methods:IsProtected() return false end
function Methods:IsObjectType(kind) return self.objectType == kind end
function Methods:GetObjectType() return self.objectType end
function Methods:GetName() return self.name end
function Methods:GetParent() return self.parent end
function Methods:GetWidth() return self.width or 0 end
function Methods:SetWidth(v) self.width = v end
function Methods:GetHeight() return self.height or 0 end
function Methods:SetHeight(v) self.height = v end
function Methods:SetSize(w, h) self.width, self.height = w, h end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Methods:GetPoint(i) local p = self.points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Methods:GetAlpha() return self.alpha or 1 end
function Methods:SetAlpha(a) self.alpha = a end
function Methods:IsMouseEnabled() return self.mouse ~= false end
function Methods:EnableMouse(on) self.mouse = on and true or false end
function Methods:IsMouseOver() return false end
function Methods:GetFrameLevel() return self.level or 1 end
function Methods:SetFrameLevel(v) self.level = v end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:GetScript(name) return self.scripts[name] end
function Methods:HookScript(name, fn)
    self.hooks[name] = self.hooks[name] or {}
    table.insert(self.hooks[name], fn)
end
function Methods:Fire(name, ...)
    if self.scripts[name] then self.scripts[name](self, ...) end
    for _, fn in ipairs(self.hooks[name] or {}) do fn(self, ...) end
end
function Methods:GetAttribute(key) return self.attrs[key] end
function Methods:SetAttribute(key, value) self.attrs[key] = value end
function Methods:SetText(text) self.text = text end
function Methods:GetText() return self.text end
function Methods:SetFormattedText(text) self.text = text end
function Methods:SetChecked(on) self.checked = on and true or false end
function Methods:GetChecked() return self.checked end
function Methods:SetID(id) self.id = id end
function Methods:GetID() return self.id or 0 end
function Methods:GetStringWidth() return 0 end
function Methods:Clear() end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetFontString() return self.fontString end
function Methods:SetFontString(text) self.fontString = text end
function Methods:GetRegions() return table.unpack(self.regions or {}) end
function Methods:GetChildren() return end
function Methods:CreateTexture(_, layer, _, sublevel)
    local t = Texture(self)
    t.layer, t.sublevel = layer, sublevel
    return t
end
function Methods:CreateMaskTexture() return Widget({ objectType = "MaskTexture" }) end
function Methods:CreateFontString(_, _, template)
    local colour = FONT_COLOURS[template] or { 1, 1, 1, 1 }
    local f = Widget({ objectType = "FontString", parent = self, template = template,
        textColour = { colour[1], colour[2], colour[3], colour[4] } })
    fonts[#fonts + 1] = f
    return f
end
-- A button's state textures: one texture per state, made on first use.
for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked" }) do
    Methods["Set" .. state .. "Texture"] = function(self, file)
        self.stateTex = self.stateTex or {}
        local t = self.stateTex[state]
        if not t then t = Texture(self); self.stateTex[state] = t end
        t.file = file
    end
    Methods["Get" .. state .. "Texture"] = function(self) return self.stateTex and self.stateTex[state] end
end

local combat = false
local env = setmetatable({}, { __index = _G })
env._G = env
env.CreateFrame = function(kind, name, parent, template)
    local f = Widget({ objectType = kind, name = name, parent = parent, template = template, events = {} })
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterEvent(event) self.events[event] = nil end
    function f:UnregisterAllEvents() self.events = {} end
    if template == "ProfessionStatusBarTemplate" then
        for _, key in ipairs({ "BGLeft", "BGMiddle", "BGRight", "capLeft", "capRight", "Bar" }) do f[key] = Texture(f) end
        f.rankText = f:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    end
    frames[#frames + 1] = f
    if name then env[name] = f end
    return f
end
-- An event to one listener (the others are not under test here).
local function FireTo(f, event, ...)
    if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
end
env.hooksecurefunc = function(object, method, hook)
    if type(object) == "string" then object, method, hook = env, object, method end
    local original = object[method]
    object[method] = function(...)
        local a, b, c = original(...)
        hook(...)
        return a, b, c
    end
end
env.unpack = table.unpack
env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
env.InCombatLockdown = function() return combat end
env.IsLoggedIn = function() return true end
env.GetTime = function() return 100 end
env.C_Timer = { After = function() end }
env.UIParent = Widget({ objectType = "Frame", name = "UIParent" })
env.GameTooltip = Widget({ objectType = "GameTooltip" })
env.UISpecialFrames = {}
env.SubSpellFont, env.GameFontHighlightSmall, env.GameFontNormal, env.GameFontHighlight = {}, {}, {}, {}
env.Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { FutureSpell = 2, Flyout = 3 } }
-- A book with one line of two spells, the second a racial passive.
env.C_SpellBook = {
    HasPetSpells = function() return 0 end,
    GetNumSpellBookSkillLines = function() return 0 end,
    GetSpellBookSkillLineInfo = function(line) if line == 1 then return { itemIndexOffset = 0, numSpellBookItems = 2 } end end,
    GetSpellBookItemType = function() return 1 end,
    GetSpellBookItemInfo = function(slot)
        if slot == 1 then return { name = "Fireball", iconID = 1, subName = "Rank 1", itemType = 1, actionID = 133, spellID = 133 } end
        if slot == 2 then return { name = "Perception", iconID = 2, subName = "Racial Passive", isPassive = true, itemType = 1, spellID = 20600 } end
    end,
}
local function Colour(r, g, b) return { GetRGB = function() return r, g, b end } end
env.NORMAL_FONT_COLOR, env.PASSIVE_SPELL_FONT_COLOR = Colour(1, .82, 0), Colour(.77, .64, 0)
env.SOUNDKIT = setmetatable({}, { __index = function() return 0 end })
env.PlaySound = function() end
env.RegisterUnitWatch = function() end
env.SPELLBOOK, env.PAGE_NUMBER = "Spellbook", "Page %d"
env.GetProfessions = function() end
env.issecretvalue = function() return false end
env.StaticPopupDialogs = {}
env.BackdropTemplateMixin = {}
for _, name in ipairs({ "PROFESSIONS_FIRST_PROFESSION", "PROFESSIONS_SECOND_PROFESSION", "PROFESSIONS_COOKING",
    "PROFESSIONS_FISHING", "PROFESSIONS_FIRST_AID", "PROFESSIONS_MISSING_PROFESSION" }) do env[name] = name end

local E = { modules = {}, settings = { enabled = true, darkMode = true, darkWindows = true, darkModeDarkness = 90 } }
function E:GetSetting(key) return self.settings[key] end
function E:RegisterModule(name, m) self.modules[name] = m end
local ns = { db = {}, modules = {} }
E.Classic = ns
function ns.RegisterModule(key, m) ns.modules[key] = m end
function ns.SafeCall(fn, ...) return fn(...) end
function ns.Persist() end
function ns.MissingPiece() end
function ns.RegisterClassicWindow() end
function ns.SkinCloseButton() end
function ns.HidePanel() end
function ns.RoundIcon() end
function ns.HookMethod(frame, method, fn) env.hooksecurefunc(frame, method, fn) end
function ns.OwnTexture(frame, key, layer, sublevel)
    frame.fcui = frame.fcui or {}
    if not frame.fcui[key] then frame.fcui[key] = frame:CreateTexture(nil, layer, nil, sublevel) end
    return frame.fcui[key]
end
ns.FONT_GOLD = "GameFontNormal"

-- The game's help tips: one pool of glow boxes (HelpTip, as "You have unspent
-- talent points" over the menu bar) and the help plates' tooltip, the same
-- box. A fill with its gradient, eight glow edges, an arrow and its glow.
function Methods:SetGradient(orientation, low, high) self.gradient = { orientation, low, high }; self.sets = self.sets + 1 end
env.CreateColor = function(r, g, b, a) return { r, g, b, a } end
local TIP_EDGES = { "GlowTopLeft", "GlowTopRight", "GlowBottomLeft", "GlowBottomRight", "GlowTop", "GlowBottom",
    "GlowLeft", "GlowRight" }
local function GlowBox(name)
    local f = env.CreateFrame("Frame", name, env.UIParent, "HelpTipTemplate")
    f.BG = Texture(f)
    f.BG.gradient = { "VERTICAL", { .23, .19, 0, 1 }, { 0, 0, 0, 1 } }
    for _, key in ipairs(TIP_EDGES) do f[key] = Texture(f) end
    f.Text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLeft")
    f.CloseButton = env.CreateFrame("Button", nil, f)
    f.CloseButton.Texture = Texture(f.CloseButton)
    f.Arrow = env.CreateFrame("Frame", nil, f)
    f.Arrow.Arrow, f.Arrow.Glow = Texture(f.Arrow), Texture(f.Arrow)
    return f
end
local tipActive, tipFree = {}, {}
env.HelpTip = { framePool = { EnumerateActive = function() return pairs(tipActive) end } }
function env.HelpTip:Show(_, info)
    for f in pairs(tipActive) do if f.Text.text == info.text then return true end end -- already showing
    local f = table.remove(tipFree) or GlowBox()
    tipActive[f] = true
    f.Text:SetText(info.text)
    f:Show()
    return true
end
function env.HelpTip:Release(f) tipActive[f] = nil; f:Hide(); tipFree[#tipFree + 1] = f end
env.HelpPlateTooltip = GlowBox("HelpPlateTooltip")
env.HelpPlateTooltip.shown, env.HelpPlateTooltip.Arrow = false, nil
for _, key in ipairs({ "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "ArrowGlowUp", "ArrowGlowDown",
    "ArrowGlowLeft", "ArrowGlowRight" }) do env.HelpPlateTooltip[key] = Texture(env.HelpPlateTooltip) end

local function Load(path) assert(loadfile(path, "t", env))("EraUI", E) end
Load("Core/ClassicAssets.lua")
Load("Core/ClassicWidgets.lua")
Load("Classic/Textures.lua")
Load("Core/Appearance.lua")
Load("Classic/Widgets.lua")
Load("Classic/OptionsWindow.lua")

-- Darkness 90's grey (Core/Appearance.lua): .10 with Dark Mode's slight blue.
local function Grey() return ns.DarkGrey() end
local function Lift(v) return math.min(1, .1 + v * 2) end
local function Page() local v = math.max(.45, math.min(1, .36 + (ns.DarkGrey()) * .43)); return v, v, math.min(1, v * 1.06) end
local function Is(t, r, g, b) return Near(t.colour[1], r) and Near(t.colour[2], g) and Near(t.colour[3], b) end
local function IsGrey(t) return Is(t, Grey()) end
local function IsPage(t) return Is(t, Page()) end
local function IsButton(t)
    local r, g, b = Grey()
    return t.desaturated == true and Is(t, Lift(r), Lift(g), Lift(b))
end
local function IsWhite(t) return Is(t, 1, 1, 1) end
local PAGE_TEXT = { .87, .81, .66 }
local function IsLight(f) local c = f.textColour; return Near(c[1], .87) and Near(c[2], .81) and Near(c[3], .66) end
-- Every piece Dark Windows looks after, for counting what a pass sets. (Dark
-- Mode's own tinted textures are left out: the slider re-tints those on
-- every pass, as before Dark Windows.)
local watched = {}
local function Watch(list) for _, piece in ipairs(list) do watched[#watched + 1] = piece end end
local function Sets()
    local n = 0
    for _, piece in ipairs(watched) do n = n + piece.sets end
    return n
end

---------------------------------------------------------------------------
-- The rules themselves.
---------------------------------------------------------------------------
equal(Near((Grey()), .10), true, "Darkness 90: Dark Mode's grey is .10")
equal(ns.DARK_PAGE_FLOOR, .45, "the parchment's floor")
equal(ns.DARK_PAGE_TEXT[1] == PAGE_TEXT[1] and ns.DARK_PAGE_TEXT[3] == PAGE_TEXT[3], true, "the light page text")
for darkness = 40, 90 do
    E.settings.darkModeDarkness = darkness
    local r, g, b = ns.DarkPageShade()
    equal(r >= .45 and g >= .45 and b >= .45 and r <= 1 and b <= 1, true, "Darkness " .. darkness .. ": the page never below the floor")
    equal(b > r, true, "Darkness " .. darkness .. ": a touch more blue, for a brown-grey")
    local br = ns.DarkButtonGrey()
    equal(br > (Grey()) and br <= 1, true, "Darkness " .. darkness .. ": the buttons' grey is lifted")
    if darkness > 40 then
        E.settings.darkModeDarkness = darkness - 1
        local before, pageBefore = ns.DarkButtonGrey(), ns.DarkPageShade()
        equal(before >= br and pageBefore >= r, true, "Darkness " .. darkness .. ": never lighter than one step lighter")
    end
end
E.settings.darkModeDarkness = 90
equal(Near(ns.DarkButtonGrey(), .3), true, "Darkness 90: buttons near black (.3 of the desaturated art)")
equal(Near((ns.DarkPageShade()), .45), true, "Darkness 90: the page at its floor")
E.settings.darkModeDarkness = 58
equal(Near(ns.DarkButtonGrey(), .94), true, "Darkness 58: buttons a clearly dark grey (.94 of the desaturated art)")
equal(Near((ns.DarkPageShade()), .36 + .42 * .43), true, "Darkness 58: the page about .54")
E.settings.darkModeDarkness = 90
-- Black Pages: a dark neutral close to the game menu's fill (the buttons'
-- grey on the dialog background), the same at every Darkness; only with
-- Dark Windows, which only shows in Dark Mode.
local BLACK = { .13, .13, .14 }
equal(ns.DARK_BLACK_PAGE[1] == BLACK[1] and ns.DARK_BLACK_PAGE[2] == BLACK[2] and ns.DARK_BLACK_PAGE[3] == BLACK[3], true,
    "the black page's shade")
equal(BLACK[1] < .45 * .5 and BLACK[3] - BLACK[1] < .02, true, "near black and close to neutral, well under the brown-grey floor")
-- The spellbook's cover: a flat colour, the black page on its parchment
-- (about .43 bright once desaturated), so both books match.
local COVER = ns.DARK_BLACK_COVER
for i = 1, 3 do equal(Near(COVER[i], BLACK[i] * .43), true, "the cover's flat near black, channel " .. i) end
equal(ns.BlackPagesOn(), false, "Black Pages off unless ticked")
E.settings.blackPages = true
equal(ns.BlackPagesOn(), true, "Black Pages on with its tick, Dark Windows and Dark Mode")
E.settings.darkWindows = false
equal(ns.BlackPagesOn(), false, "not without Dark Windows")
E.settings.darkWindows, E.settings.darkMode = true, false
equal(ns.BlackPagesOn(), false, "nor without Dark Mode")
E.settings.darkMode, E.settings.enabled = true, false
equal(ns.BlackPagesOn(), false, "nor with EraUI off")
E.settings.enabled, E.settings.blackPages = true, nil

---------------------------------------------------------------------------
-- Red buttons, from every place EraUI draws them.
---------------------------------------------------------------------------
local function NewButton() return env.CreateFrame("Button", nil, env.UIParent) end
local skinned, classicOwned, panel = NewButton(), NewButton(), ns.PanelButton(env.UIParent, "Reload UI", 130)
ns.SkinRedButton(skinned)
E:SkinClassicRedButton(classicOwned, "Test")
local red = { skinned, classicOwned, panel }
local function AllButtons(check, label)
    for i, button in ipairs(red) do
        for _, state in ipairs({ "Normal", "Pushed", "Disabled" }) do
            equal(check(button.stateTex[state]), true, label .. ": button " .. i .. " " .. state)
        end
    end
end
local function AllGlows(check, label)
    for i, button in ipairs(red) do equal(check(button.stateTex.Highlight), true, label .. ": button " .. i .. " glow") end
end
local function WatchButton(button)
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do Watch({ button.stateTex[state] }) end
end
for i, button in ipairs(red) do
    equal(button.stateTex.Normal.file:find("UI%-Panel%-Button%-Up") ~= nil, true, "button " .. i .. " wears the red panel art")
    WatchButton(button)
end
AllButtons(IsButton, "Darkness 90")
AllGlows(function(t) return t.desaturated == true and IsWhite(t) end, "Darkness 90: the glow only loses its colour")
equal(panel.fontString.sets, 0, "labels keep their gold")

local before = Sets()
ns.RefreshDarkWindows(); ns.RefreshDarkWindows()
equal(Sets(), before, "a pass with nothing new sets nothing")
ns.DarkRedButton(skinned)
equal(Sets(), before, "nor does registering a button again")

-- The Darkness slider re-tints at once (through RefreshDarkness).
E.settings.darkModeDarkness = 58; ns.RefreshDarkness()
AllButtons(IsButton, "Darkness 58")
equal(Near(skinned.stateTex.Normal.colour[1], .94), true, "Darkness 58: dark grey, not near black")

---------------------------------------------------------------------------
-- The game menu.
---------------------------------------------------------------------------
local menu = env.CreateFrame("Frame", "GameMenuFrame", env.UIParent)
menu.Header = env.CreateFrame("Frame", nil, menu)
menu.Header.Text = menu.Header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
menu.Header.LeftBG, menu.Header.RightBG, menu.Header.CenterBG = Texture(), Texture(), Texture()
local menuButtons = { NewButton(), NewButton(), NewButton() }
menu.buttonPool = { EnumerateActive = function() local i = 0; return function() i = i + 1; return menuButtons[i] end end }
menu.InitButtons = function() end
menu.Layout = function() end
Load("Classic/GameMenu.lua")
ns.modules.gameMenu.apply()
local backing
for _, f in ipairs(frames) do if f.template == "BackdropTemplate" and f.parent == menu then backing = f end end
local plate = menu.Header.fcui.plate
equal(backing ~= nil and plate ~= nil, true, "the game menu's box and header plate are drawn")
equal(plate.file:find("UI%-DialogBox%-Header") ~= nil, true, "the plate is the dialog header")
local r, g, b = Grey()
equal(Near(backing.border[1], r) and Near(backing.border[3], b), true, "the box's border takes Dark Mode's grey")
equal(Near(backing.fill[1], Lift(r)) and Near(backing.fill[3], Lift(b)), true, "its fill darkens with the buttons' grey")
equal(IsGrey(plate), true, "the header plate takes Dark Mode's grey")
for i, button in ipairs(menuButtons) do
    for _, state in ipairs({ "Normal", "Pushed", "Disabled" }) do
        equal(IsButton(button.stateTex[state]), true, "game menu button " .. i .. " " .. state)
    end
    equal(button.stateTex.Highlight.desaturated, true, "game menu button " .. i .. " glow without its colour")
    WatchButton(button)
end
red[#red + 1] = menuButtons[1]
Watch({ backing, plate })
before = Sets()
menu:Fire("OnShow")
ns.RefreshDarkWindows()
equal(Sets(), before, "the menu opening again sets nothing new")

---------------------------------------------------------------------------
-- The spellbook.
---------------------------------------------------------------------------
Load("Classic/SpellBook.lua")
ns.modules.spellBook.apply()
local book = env.EraUIClassicSpellBook
equal(book ~= nil, true, "the classic spellbook is built")
local pages, empties = {}, {}
for _, t in ipairs(textures) do
    if t.file and t.file:find("UI%-SpellbookPanel%-[TB]o[pt]%a+$") then pages[#pages + 1] = t end
    if t.file and t.file:find("UI%-Spellbook%-SpellBackground") then empties[#empties + 1] = t end
end
equal(#pages, 4, "the book's four page pieces")
equal(#empties, 12, "twelve empty-slot squares")
-- The four pieces hold the book's frame, title strip and icon ring as well
-- as its parchment, so Black Pages blacks out the parchment with EraUI's own
-- cover instead: the art's parchment runs from 22 to 343 across and 75 to
-- 430 down (Media/Classic/UI-SpellbookPanel-*.blp); the frame is outside it.
local cover = book.PageCover
equal(cover ~= nil and cover.objectType == "Texture" and cover.parent == book, true, "the book's page cover is EraUI's own")
for i, t in ipairs(pages) do
    equal(t.layer == "BACKGROUND" and (t.sublevel or 0) == 0, true, "setup: page piece " .. i .. " on the background")
end
equal(cover.layer == "BACKGROUND" and cover.sublevel == 1, true, "the cover above the four pieces, under the text and slots")
local at = cover.points[1]
equal(#cover.points == 1 and at[1] == "TOPLEFT" and at[2] == book and at[3] == "TOPLEFT" and at[4] == 22 and at[5] == -75, true,
    "the cover starts at the parchment's top left corner")
equal(cover.width == 343 - 22 + 1 and cover.height == 430 - 75 + 1, true, "the cover ends at its bottom right: the parchment alone")
equal(cover.shown, false, "the cover hidden without Black Pages")
equal(cover.colourTexture, nil, "and given no colour")
-- Showing or hiding the cover counts as setting it.
function cover:SetShown(on) self.sets = self.sets + 1; Methods.SetShown(self, on) end
Watch({ cover })
local subs, names = {}, {}
for _, f in ipairs(fonts) do
    if f.template == "SubSpellFont" then subs[#subs + 1] = f end
    if f.template == "GameFontNormal" and f.parent and f.parent.parent == book then names[#names + 1] = f end
end
equal(#subs, 12, "twelve spell subtexts")
equal(#names >= 12, true, "the spell names")
local pageText = book.PageText
Watch(pages); Watch(empties); Watch(subs); Watch(names); Watch({ pageText })
local function BookAt(check, label)
    for i, t in ipairs(pages) do equal(check(t), true, label .. ": page piece " .. i) end
    for i, t in ipairs(empties) do equal(check(t), true, label .. ": empty slot " .. i) end
end
E.settings.darkModeDarkness = 90; ns.RefreshDarkness()
BookAt(IsPage, "Darkness 90")
for i, t in ipairs(pages) do
    equal(t.desaturated, nil, "page piece " .. i .. " keeps its own colours, only shaded (never desaturated: its frame is in it)")
end
equal(empties[1].desaturated, false, "an empty slot keeps its own colours, only shaded")
equal(cover.shown, false, "Darkness 90: the cover still hidden")
for i, f in ipairs(subs) do equal(IsLight(f), true, "subtext " .. i .. " (Passive, Racial) lightened") end
equal(IsLight(pageText), true, "the page number lightened")
for i, f in ipairs(names) do equal(f.sets, 0, "spell name " .. i .. " keeps its gold") end
E.settings.darkModeDarkness = 58; ns.RefreshDarkness()
BookAt(IsPage, "Darkness 58")
equal(Near(pages[1].colour[1], .36 + .42 * .43), true, "Darkness 58: the page lighter than at 90")
E.settings.darkModeDarkness = 40; ns.RefreshDarkness()
BookAt(IsPage, "Darkness 40")
E.settings.darkModeDarkness = 90; ns.RefreshDarkness()
before = Sets()
ns.RefreshDarkWindows(); ns.RefreshDarkness()
equal(Sets(), before, "Darkness unchanged: the slider's pass sets nothing new")
-- The frame round each slot: the book's refresh used to make it light again;
-- with Dark Windows on it keeps Dark Mode's grey.
local slotFrames = {}
for i, btn in ipairs(book.Buttons) do
    slotFrames[i] = btn.normal
    btn.normal:SetVertexColor(1, 1, 1)
end
equal(#slotFrames, 12, "twelve slot frames")
book:Refresh()
equal(book.Buttons[1].slot == 1 and book.Buttons[2].isPassive == true and book.Buttons[3].slot == nil, true,
    "setup: a spell, a passive and empty slots on the page")
for i, t in ipairs(slotFrames) do
    if i == 2 then equal(Is(t, 0, 0, 0), true, "after a refresh: a passive's slot frame stays black")
    else equal(IsGrey(t), true, "after a refresh: slot frame " .. i .. " in Dark Mode's grey") end
end
local fireball, perception = book.Buttons[1].SpellName, book.Buttons[2].SpellName
equal(fireball.textColour[1] == 1 and fireball.textColour[2] == .82, true, "a spell name keeps its gold")
equal(perception.textColour[1] == .77, true, "a passive's name keeps the game's passive gold")
equal(IsLight(book.Buttons[2].SpellSubName) and book.Buttons[2].SpellSubName.text == "Racial Passive", true,
    "\"Racial Passive\" under it in the light grey-gold")

---------------------------------------------------------------------------
-- The Professions window: EraUI's book on Blizzard's frame.
---------------------------------------------------------------------------
local prof = env.CreateFrame("Frame", "ProfessionsFrame", env.UIParent)
prof.shown = false
prof.BookPage = env.CreateFrame("Frame", nil, prof)
prof.CraftingPage = env.CreateFrame("Frame", nil, prof)
prof.CraftingPage.shown = false
prof.ProfessionsOverviewTab = env.CreateFrame("Frame", nil, prof)
prof.rightProfessionTabs = {}
local content = env.CreateFrame("Frame", nil, prof.BookPage)
prof.BookPage.ProfessionsContentFrame = content
local cards = {}
-- Blizzard's cards, with their dark "learn a profession" header and text
-- (shown when the skin is off).
FONT_COLOURS.CardHeader = { .15, .1, .1, 1 }
-- Each spell button draws its gold name and its dark brown rank (the game's
-- SubSpellFont) beside it, over EraUI's plate; each card has a dark rank
-- line and a gold name of its own (Blizzard's book, the skin off). The game
-- hands them out as the button's and card's regions.
local plateNames, plateSubs, cardRanks, cardNames = {}, {}, {}, {}
local function Card(key, spells)
    local card = env.CreateFrame("Frame", nil, content)
    card.Background = Texture(card)
    card.missingHeader = card:CreateFontString(nil, "ARTWORK", "CardHeader")
    card.missingText = card:CreateFontString(nil, "ARTWORK", "SubSpellFont")
    local rank = card:CreateFontString(nil, "ARTWORK", "SubSpellFont")
    local name = card:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    cardRanks[#cardRanks + 1], cardNames[#cardNames + 1] = rank, name
    card.regions = { card.Background, card.missingHeader, card.missingText, rank, name }
    for n = 1, spells do
        local button = env.CreateFrame("CheckButton", nil, card)
        local spell = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        local sub = button:CreateFontString(nil, "ARTWORK", "SubSpellFont")
        button.regions = { Texture(button), spell, sub }
        plateNames[#plateNames + 1], plateSubs[#plateSubs + 1] = spell, sub
        card["SpellButton" .. n] = button
    end
    content[key] = card
    cards[#cards + 1] = card
    return card
end
for i = 1, 2 do Card("PrimaryProfession" .. i, 2) end
for i = 1, 3 do Card("SecondaryProfession" .. i, 4) end
local formatted = 0
-- Blizzard filling a card sets its art and its text up again.
function prof.BookPage:FormatProfession(card)
    formatted = formatted + 1
    card.Background:SetVertexColor(1, 1, 1)
    card.missingText:SetTextColor(.35, .2, 0, 1)
end
-- The window's frame: Blizzard's nine-slice (one corner already in Dark
-- Mode's grey from EraUI's metal border) and EraUI's title strip and stone.
prof.NineSlice = env.CreateFrame("Frame", nil, prof)
local corner = Texture(prof.NineSlice)
ns.SetTex(corner, "frameMetal")
prof.NineSlice.regions = { corner, Texture(prof.NineSlice), Texture(prof.NineSlice), Texture(prof.NineSlice) }
ns.OwnTexture(prof, "titleStrip", "BACKGROUND")
ns.OwnTexture(prof, "streaks", "BACKGROUND", -1)
ns.OwnTexture(prof, "backing", "BACKGROUND", -2)
equal(IsGrey(corner), true, "setup: Dark Mode's own grey on the metal corner")

local loadedBefore = #frames
Load("Classic/Professions.lua")
local darkWatch
for i = loadedBefore + 1, #frames do if frames[i].events.ADDON_LOADED then darkWatch = frames[i] end end
equal(darkWatch ~= nil and darkWatch.events.PLAYER_REGEN_ENABLED, true, "the window's hooks wait for it to load, out of a fight")
ns.modules.professionsBook.apply()
local function Find(pattern)
    local out = {}
    for _, t in ipairs(textures) do if type(t.file) == "string" and t.file:find(pattern) then out[#out + 1] = t end end
    return out
end
local bookPages, sheet = Find("Professions%-Book%-"), Find("ProfessionsBook$")
equal(#bookPages, 2, "the book's two pages")
equal(#sheet, 2 + 2 * 2 + 3 * 4, "two emblem rings and sixteen spell plates")
local barArt = {}
for _, f in ipairs(frames) do
    if f.template == "ProfessionStatusBarTemplate" then
        for _, key in ipairs({ "BGLeft", "BGMiddle", "BGRight", "capLeft", "capRight" }) do barArt[#barArt + 1] = f[key] end
        equal(f.Bar.sets, 0, "a rank bar's green fill keeps its colour")
    end
end
equal(#barArt, 25, "the five rank bars' frames")
Watch(bookPages); Watch(sheet); Watch(barArt)
for _, card in ipairs(cards) do Watch({ card.Background }) end
Watch({ prof.NineSlice.regions[2], prof.NineSlice.regions[3], prof.NineSlice.regions[4], prof.fcui.titleStrip,
    prof.fcui.streaks, prof.fcui.backing })
local function ProfessionsAt(check, label)
    for i, t in ipairs(bookPages) do equal(check(t), true, label .. ": book page " .. i) end
    for i, t in ipairs(sheet) do equal(check(t), true, label .. ": ring or plate " .. i) end
    for i, t in ipairs(barArt) do equal(check(t), true, label .. ": rank bar piece " .. i) end
    for i, card in ipairs(cards) do equal(check(card.Background), true, label .. ": card " .. i) end
end
ProfessionsAt(IsPage, "Darkness 90")
for i, t in ipairs(prof.NineSlice.regions) do equal(IsGrey(t), true, "Darkness 90: the window's frame piece " .. i) end
for _, key in ipairs({ "titleStrip", "streaks", "backing" }) do equal(IsGrey(prof.fcui[key]), true, "Darkness 90: its " .. key) end
local missingTexts, darkHeaders, lightHeaders = {}, {}, {}
for _, f in ipairs(fonts) do
    local c = f.textColour
    if f.template == nil and f.parent and f.parent.primary ~= nil then
        if f == f.parent.missingText then missingTexts[#missingTexts + 1] = f end
        if f == f.parent.missingHeader then
            if f.parent.primary then lightHeaders[#lightHeaders + 1] = f else darkHeaders[#darkHeaders + 1] = f end
        end
    end
end
equal(#missingTexts, 5, "five 'learn a profession' texts")
for i, f in ipairs(missingTexts) do equal(IsLight(f), true, "missing text " .. i .. " lightened") end
equal(#darkHeaders, 3, "three dark secondary headers")
for i, f in ipairs(darkHeaders) do equal(IsLight(f), true, "secondary header " .. i .. " lightened") end
for i, f in ipairs(lightHeaders) do
    equal(Near(f.textColour[1], .85) and f.sets == 1, true, "primary header " .. i .. " was light already: left alone")
end
Watch(missingTexts); Watch(darkHeaders); Watch(lightHeaders)
-- Blizzard's cards (the skin off): their dark "learn a profession" text light too.
local cardTexts = {}
for _, card in ipairs(cards) do cardTexts[#cardTexts + 1] = card.missingHeader; cardTexts[#cardTexts + 1] = card.missingText end
for i, f in ipairs(cardTexts) do equal(IsLight(f), true, "Blizzard's card text " .. i .. " lightened") end
Watch(cardTexts)
-- The game's own small dark text on the spell plates and cards (a spell's
-- rank under its name, a card's rank line): readable on the brown-grey, so
-- left exactly as the game drew it until Black Pages (below). Gold names
-- are never touched.
local function OwnBrown(f) local c = f.textColour; return Near(c[1], .35) and Near(c[2], .2) and Near(c[3], 0) and c[4] == 1 end
equal(#plateSubs .. " " .. #cardRanks, "16 5", "setup: sixteen spell ranks on their plates, five card rank lines")
for i, f in ipairs(plateSubs) do equal(f.sets == 0 and OwnBrown(f), true, "Black Pages off: a spell's rank on its plate " .. i .. " as the game drew it") end
for i, f in ipairs(cardRanks) do equal(f.sets == 0 and OwnBrown(f), true, "Black Pages off: a card's rank line " .. i .. " as the game drew it") end
local function GoldUntouched(label)
    for i, f in ipairs(plateNames) do equal(f.sets == 0 and f.textColour[2] == .82, true, label .. ": a spell's gold name " .. i .. " untouched") end
    for i, f in ipairs(cardNames) do equal(f.sets == 0 and f.textColour[2] == .82, true, label .. ": a card's gold name " .. i .. " untouched") end
end
GoldUntouched("Black Pages off")
Watch(plateSubs); Watch(cardRanks); Watch(plateNames); Watch(cardNames)

-- Nothing new, nothing set: the watch's next passes and the slider at 90.
local watch
for _, f in ipairs(frames) do if f.events.SKILL_LINES_CHANGED then watch = f end end
local function NextPass()
    FireTo(watch, "SKILL_LINES_CHANGED"); watch.since = 1; watch.scripts.OnUpdate(watch, 0)
end
before = Sets()
NextPass()
ns.RefreshDarkness()
equal(Sets(), before, "the book's next pass and an unchanged slider set nothing")

-- Hooked once the window is there, in Dark Mode, out of a fight.
equal(formatted, 0, "setup: Blizzard hasn't filled a card")
equal(prof.hooks.OnShow, nil, "setup: nothing hooked on the window yet")
combat = true
FireTo(darkWatch, "ADDON_LOADED", "Blizzard_Professions")
equal(prof.hooks.OnShow, nil, "not hooked in a fight")
combat = false
FireTo(darkWatch, "PLAYER_REGEN_ENABLED")
equal(#prof.hooks.OnShow, 1, "hooked once the fight is over")
equal(next(darkWatch.events), nil, "then it stops listening")
FireTo(darkWatch, "ADDON_LOADED", "Blizzard_Professions")
equal(#prof.hooks.OnShow, 1, "and hooks only once")
-- Blizzard filling a card again: painted again at once (force).
prof.BookPage:FormatProfession(cards[3])
equal(formatted, 1, "Blizzard's own FormatProfession ran")
equal(IsPage(cards[3].Background), true, "the card Blizzard filled is dark again at once")
equal(IsLight(cards[3].missingText), true, "and its text light again at once")
before = Sets()
prof:Show()
equal(Sets(), before, "opening the window with nothing new sets nothing")

-- The slider: everything follows at once.
E.settings.darkModeDarkness = 58; ns.RefreshDarkness()
ProfessionsAt(IsPage, "Darkness 58")
for i, t in ipairs(prof.NineSlice.regions) do equal(IsGrey(t), true, "Darkness 58: the window's frame piece " .. i) end
BookAt(IsPage, "Darkness 58 again")
AllButtons(IsButton, "Darkness 58 again")
equal(IsGrey(plate) and Near(backing.border[1], (Grey())), true, "Darkness 58: the game menu's box")

---------------------------------------------------------------------------
-- EraUI's other dialog boxes: the pop-ups' box, the status report, the
-- welcome, the drop down lists, the report window's box, the skill windows'
-- inset boxes; and the skinned windows' metal edges, stone and title strip.
-- (The guild member box, the reputation detail, the equipment pane, the
-- options window, the settings skin and the who list's search box are built
-- deep inside their windows: Tools/TestRules.mjs checks from the source
-- that every classic dialog border and header plate is handed over.)
---------------------------------------------------------------------------
-- Loads a file whose shared helpers would replace this mock's, keeps what it
-- makes, then puts the mock's helpers back.
local function LoadBeside(path, use)
    local kept = {}
    for key, value in pairs(ns) do kept[key] = value end
    Load(path)
    local made = use()
    for key, value in pairs(kept) do ns[key] = value end
    return made
end
local function BorderIs(box, r, g, b) return Near(box.border[1], r) and Near(box.border[2], g) and Near(box.border[3], b) end
local function FillIs(box, r, g, b, a)
    return Near(box.fill[1], r) and Near(box.fill[2], g) and Near(box.fill[3], b) and box.fill[4] == a
end
local function DarkBox(box, own)
    local r, g, b = Grey()
    if not BorderIs(box, r, g, b) then return false end
    if own == false then return box.fill == nil end
    own = own or { 1, 1, 1, 1 }
    return FillIs(box, own[1] * Lift(r), own[2] * Lift(g), own[3] * Lift(b), own[4])
end

-- Pop-ups: EraUI's box behind the game's own (Modules/Popups.lua).
local popup = env.CreateFrame("Frame", "StaticPopup1", env.UIParent)
popup.Buttons = { NewButton(), NewButton() }
E.settings.popups = true
Load("Modules/Popups.lua")
E.modules.ClassicPanels:Initialize()
local popupArt
for _, f in ipairs(frames) do if f.parent == popup and f.backdrop then popupArt = f end end
equal(popupArt ~= nil and popupArt.backdrop.edgeFile:find("UI%-DialogBox%-Border") ~= nil, true, "the pop-up's box is the dialog art")
equal(DarkBox(popupArt), true, "the pop-up's box: border in Dark Mode's grey, fill in the buttons' grey")
equal(IsButton(popup.Buttons[1].stateTex.Normal), true, "and its buttons dark, as before")
-- The status report and the welcome: box and header plate.
Load("Classic/Status.lua")
ns.StatusText = function() return "" end
ns.ShowStatus()
local status = env.EraUIClassicStatus
ns.OnForever = function() return true end
Load("Classic/Welcome.lua")
ns.ShowWelcome()
local welcome = env.EraUIClassicWelcome
equal(status ~= nil and welcome ~= nil, true, "setup: the status report and the welcome are built")
equal(DarkBox(status) and DarkBox(welcome), true, "the status report's and the welcome's boxes")
-- A drop down list and the report window's box (Core/Utils.lua: its own
-- dark brown fill, darker still).
local dropList = ns.DropList({ { "One", function() end } })
equal(DarkBox(dropList), true, "a drop down list's box")
Load("Core/Utils.lua")
local REPORT_FILL = { .16, .12, .08, .96 }
local reportBox = E:AddClassicBackdrop(env.CreateFrame("Frame", nil, env.UIParent), 3)
equal(DarkBox(reportBox, REPORT_FILL), true, "the report window's box: its brown fill darker, its alpha kept")
-- The skill windows' inset boxes: the iron border only (no fill to set).
local controlsBox = LoadBeside("Classic/Controls.lua", function() return ns.SkillInsetBox(env.UIParent, 16) end)
local tradeBox = LoadBeside("Classic/TradeSkill.lua", function() return ns.SkillInsetBox(env.UIParent, 32, true) end)
equal(DarkBox(controlsBox, false) and DarkBox(tradeBox, false), true, "the inset boxes' iron border in Dark Mode's grey, no fill set")
equal(IsGrey(controlsBox.floor), true, "an inset box's floor keeps Dark Mode's own grey")
-- A skinned window (Classic/Panels.lua): Dark Mode tints the metal corners;
-- Dark Windows the edges, the stone, its streaks and the title strip.
local taxi = env.CreateFrame("Frame", "TaxiFrame", env.UIParent)
taxi.NineSlice = env.CreateFrame("Frame", nil, taxi)
local CORNER_KEYS = { "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner" }
local EDGE_KEYS = { "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }
for _, key in ipairs(CORNER_KEYS) do taxi.NineSlice[key] = Texture(taxi.NineSlice) end
for _, key in ipairs(EDGE_KEYS) do taxi.NineSlice[key] = Texture(taxi.NineSlice) end
local skinWindow = LoadBeside("Classic/Panels.lua", function() ns.modules.panels.apply(); return ns.SkinWindow end)
local taxiArt = {}
for _, key in ipairs(EDGE_KEYS) do taxiArt[#taxiArt + 1] = taxi.NineSlice[key] end
for _, key in ipairs({ "backing", "streaks", "titleStrip" }) do taxiArt[#taxiArt + 1] = taxi.fcui[key] end
equal(#taxiArt, 7, "setup: the window's four edges, stone, streaks and title strip")
for _, key in ipairs(CORNER_KEYS) do equal(IsGrey(taxi.NineSlice[key]), true, "a skinned window's " .. key .. ": Dark Mode's own grey") end
for i, t in ipairs(taxiArt) do equal(IsGrey(t) and t.desaturated == nil, true, "a skinned window's frame art " .. i .. " in Dark Mode's grey") end
Watch(taxiArt)
-- Skinned again (the world map does on resizing): its art painted again once.
before = Sets()
skinWindow(taxi, {})
equal(Sets() - before, #taxiArt, "skinning the window again paints its art again, once each")

-- Every classic dialog box and header plate this test has built: dark.
local dialogBoxes, headers = {}, {}
for _, f in ipairs(frames) do
    if f.backdrop and type(f.backdrop.edgeFile) == "string" and f.backdrop.edgeFile:find("UI%-DialogBox%-Border") then
        dialogBoxes[#dialogBoxes + 1] = f
    end
end
for _, t in ipairs(textures) do
    if type(t.file) == "string" and t.file:find("UI%-DialogBox%-Header") then headers[#headers + 1] = t end
end
equal(#dialogBoxes, 8, "the game menu, pop-up, status, welcome, drop down, report and two inset boxes")
equal(#headers, 3, "the game menu's, the status report's and the welcome's header plates")
for i, box in ipairs(dialogBoxes) do equal(BorderIs(box, Grey()), true, "dialog box " .. i .. ": its border in Dark Mode's grey") end
for i, t in ipairs(headers) do equal(IsGrey(t), true, "header plate " .. i .. " in Dark Mode's grey") end
Watch(dialogBoxes); Watch(headers)
before = Sets()
ns.RefreshDarkWindows(); ns.RefreshDarkness()
popup:Fire("OnShow"); env.EraUIClassicStatus:Fire("OnShow")
equal(Sets(), before, "the boxes: a pass with nothing new sets nothing")
-- The slider: every box follows.
E.settings.darkModeDarkness = 90; ns.RefreshDarkness()
equal(DarkBox(popupArt) and DarkBox(status) and DarkBox(reportBox, REPORT_FILL) and DarkBox(tradeBox, false), true,
    "Darkness 90: the boxes follow the slider")
for i, t in ipairs(taxiArt) do equal(IsGrey(t), true, "Darkness 90: the window's frame art " .. i) end
for i, t in ipairs(headers) do equal(IsGrey(t), true, "Darkness 90: header plate " .. i) end
E.settings.darkModeDarkness = 58; ns.RefreshDarkness()
equal(DarkBox(popupArt) and DarkBox(welcome) and DarkBox(dropList) and DarkBox(controlsBox, false), true,
    "Darkness 58: the boxes follow back")

---------------------------------------------------------------------------
-- The class trainer (Classic/Trainer.lua on the real skill shell of
-- Classic/TradeSkill.lua, its inset boxes and Classic/Controls.lua's, in a
-- window skinned by Classic/Panels.lua): every edge and border piece of the
-- window and its boxes in Dark Mode's grey at Darkness 90, the money box's
-- gold-edged border included; all follow the slider; with the tick off,
-- Dark Windows' pieces get their own colours back and Dark Mode's own keep
-- its grey. And the greeting's room, against the real shell and title strip.
---------------------------------------------------------------------------
do
    local host = env.CreateFrame("Frame", "ClassTrainerFrame", env.UIParent)
    host.shown = false
    host.NineSlice = env.CreateFrame("Frame", nil, host)
    for _, key in ipairs(CORNER_KEYS) do host.NineSlice[key] = Texture(host.NineSlice) end
    for _, key in ipairs(EDGE_KEYS) do host.NineSlice[key] = Texture(host.NineSlice) end
    for _, key in ipairs({ "TrainButton", "money", "ScrollBox" }) do host[key] = env.CreateFrame("Frame", nil, host) end
    E.settings.darkModeDarkness = 90; ns.RefreshDarkness()
    skinWindow(host, {})
    env.RegisterStateDriver, env.UnregisterStateDriver = function() end, function() end
    -- The shell's scroll bar (Classic/Skin.lua, not loaded here): a bar with
    -- its two arrows, so the scroll column is drawn round it.
    ns.ClassicScrollBar = function(parent)
        local bar = env.CreateFrame("Slider", nil, parent)
        bar.up, bar.down = env.CreateFrame("Button", nil, bar), env.CreateFrame("Button", nil, bar)
        return bar
    end
    Load("Classic/Trainer.lua")
    ns.modules.trainer.apply()
    local trainer = env.EraUIClassicTrainer
    equal(trainer ~= nil and trainer.parent == host and trainer.listBox ~= nil, true, "setup: the classic trainer built on the real shell")
    local function Within(piece, root)
        local p = piece.parent
        while p do if p == root then return true end; p = p.parent end
        return false
    end
    -- Edge and border art: the metal corners and edges, the dialog border
    -- (inset boxes, the list's tab), the money box's border, the stone, the
    -- marble floors and the scroll column.
    local EDGE_ART = { ["Interface\\DialogFrame\\UI-DialogBox-Border"] = true, ["Interface\\MoneyFrame\\UI-MoneyFrame-Border"] = true }
    for _, key in ipairs({ "frameMetal", "frameMetalH", "frameMetalV", "frameSheet", "rockBg", "marbleBg", "charScrollBar" }) do
        local primary, fallback = ns.TexPath(key)
        EDGE_ART[primary], EDGE_ART[fallback] = true, true
    end
    local art, boxes, has = {}, {}, {}
    for _, t in ipairs(textures) do
        if Within(t, host) and EDGE_ART[t.file] then art[#art + 1] = t; has[t] = true end
    end
    for _, f in ipairs(frames) do if Within(f, host) and f.backdrop then boxes[#boxes + 1] = f end end
    local own = { trainer.oval, host.fcui.backing, host.fcui.streaks, host.fcui.titleStrip }
    for _, key in ipairs(EDGE_KEYS) do own[#own + 1] = host.NineSlice[key] end
    for i, t in ipairs(own) do equal(has[t], true, "setup: the trainer's edge piece " .. i .. " is found by its art") end
    for _, key in ipairs(CORNER_KEYS) do equal(has[host.NineSlice[key]], true, "setup: its " .. key .. " too") end
    equal(trainer.oval.file, "Interface\\MoneyFrame\\UI-MoneyFrame-Border", "setup: the money box's gold-edged border")
    equal(#art >= 25, true, "setup: the window's and the shell's edge art all found (" .. #art .. ")")
    equal(#boxes, 6, "the list, details and footer boxes and the money, Train and Exit boxes")
    local function AllDark(label)
        for i, t in ipairs(art) do equal(IsGrey(t), true, label .. ": trainer edge piece " .. i .. " (" .. tostring(t.file) .. ")") end
        for i, box in ipairs(boxes) do
            equal(BorderIs(box, Grey()) and box.fill == nil, true, label .. ": trainer box " .. i .. "'s border, no fill set")
        end
    end
    AllDark("Darkness 90")
    equal(Near(trainer.oval.colour[1], .1) and trainer.oval.desaturated == nil, true, "the money box's border near black at 90, only its colour set")
    equal(trainer.trainHighlight ~= nil and trainer.trainHighlight.desaturated == true, true, "Train's glow loses its colour, as before")
    E.settings.darkModeDarkness = 58; ns.RefreshDarkness()
    AllDark("Darkness 58")
    -- The tick off: Dark Windows' pieces their own colours, Dark Mode's own grey kept.
    local mine = {}
    for _, t in ipairs(own) do mine[t] = true end
    E.settings.darkWindows = false; ns.RefreshDarkWindows()
    for i, t in ipairs(art) do
        equal(mine[t] and IsWhite(t) or (not mine[t] and IsGrey(t)), true, "tick off: trainer edge piece " .. i .. (mine[t] and " its own colours" or " keeps Dark Mode's grey"))
    end
    for i, box in ipairs(boxes) do equal(BorderIs(box, 1, 1, 1), true, "tick off: trainer box " .. i .. "'s border as before") end
    E.settings.darkWindows = true; ns.RefreshDarkWindows()
    AllDark("tick back on")
    -- The greeting's room: below the window's title strip, above the list's
    -- tab and Filter, on a frame above the stone between them.
    local function Y(frame, point)
        for _, p in ipairs(frame.points) do if p[1] == point then return p[5], p[2] end end
    end
    local strip = host.fcui.titleStrip
    local stripTop = Y(strip, "TOPLEFT")
    local listTop, listRel = Y(trainer.listBox, "TOPLEFT")
    local tabTop = listTop + trainer.allTab.height
    local filterTop, filterRel = Y(trainer.filter, "TOPRIGHT")
    local boxTop, topRel = Y(trainer.greetingBox, "TOPLEFT")
    local boxBottom, bottomRel = Y(trainer.greetingBox, "BOTTOMRIGHT")
    equal(listRel == trainer and filterRel == trainer and topRel == trainer and bottomRel == trainer, true,
        "setup: the list, Filter and greeting placed on the trainer layout (the window's own size)")
    equal(boxTop < stripTop - strip.height, true, "the greeting starts below the title strip (" .. boxTop .. " under " .. (stripTop - strip.height) .. ")")
    equal(boxBottom > tabTop and boxBottom > filterTop, true,
        "the greeting ends above the list's tab (" .. tabTop .. ") and Filter (" .. filterTop .. "): " .. boxBottom)
    equal(boxTop - boxBottom >= 30, true, "two lines of the window's font fit")
    local gap
    for _, f in ipairs(frames) do if f.parent == trainer and Y(f, "TOPLEFT") == -50 then gap = f end end
    equal(gap ~= nil and trainer.greetingBox.level > gap.level, true, "above the stone between the greeting and the list")
    equal(trainer.greeting.parent, trainer.greetingBox, "the text on that frame")
    equal(trainer.greetingBox.mouse, nil, "which takes no mouse input")
    ns.ClassicScrollBar = nil
end

---------------------------------------------------------------------------
-- Black Pages: the spellbook's and the Professions window's pages near
-- black instead of brown-grey; the spellbook's frame (drawn in its four
-- pieces), the rings and bars' frames take the frame's grey; the text keeps
-- its colours; the frame art follows the slider.
---------------------------------------------------------------------------
local rings, plates = {}, {}
for _, t in ipairs(sheet) do if t.width == 72 then rings[#rings + 1] = t else plates[#plates + 1] = t end end
equal(#rings == 2 and #plates == 16, true, "setup: two emblem rings and sixteen spell plates")
local function IsBlack(t) return t.desaturated == true and Is(t, BLACK[1], BLACK[2], BLACK[3]) end
local function IsBrown(t) return t.desaturated == false and IsPage(t) end
-- The cover: shown in its flat near black, or hidden.
local function CoverIs(shown)
    if not shown then return cover.shown == false end
    local c = cover.colourTexture
    return cover.shown == true and c ~= nil and c[1] == COVER[1] and c[2] == COVER[2] and c[3] == COVER[3] and c[4] == 1
end
-- check: the pages; trim: the spellbook's four pieces, rings and bars'
-- frames (never desaturated); covered: the spellbook's cover shown.
local function PagesAt(check, trim, covered, label)
    for i, t in ipairs(empties) do equal(check(t), true, label .. ": empty slot " .. i) end
    for i, t in ipairs(bookPages) do equal(check(t), true, label .. ": professions page " .. i) end
    for i, t in ipairs(plates) do equal(check(t), true, label .. ": spell plate " .. i) end
    for i, card in ipairs(cards) do equal(check(card.Background), true, label .. ": card " .. i) end
    for i, t in ipairs(pages) do
        equal(t.desaturated == nil and trim(t), true, label .. ": spellbook piece " .. i .. " (frame, title strip, icon ring)")
    end
    for i, t in ipairs(rings) do equal(t.desaturated == nil and trim(t), true, label .. ": emblem ring " .. i) end
    for i, t in ipairs(barArt) do equal(t.desaturated == nil and trim(t), true, label .. ": rank bar piece " .. i) end
    equal(CoverIs(covered), true, label .. ": the spellbook's cover " .. (covered and "shown, near black" or "hidden"))
end
local function TextKept(label)
    for i, f in ipairs(subs) do equal(IsLight(f), true, label .. ": subtext " .. i .. " light") end
    equal(IsLight(pageText), true, label .. ": the page number light")
    for i, f in ipairs(missingTexts) do equal(IsLight(f), true, label .. ": missing text " .. i .. " light") end
    for i, f in ipairs(darkHeaders) do equal(IsLight(f), true, label .. ": secondary header " .. i .. " light") end
    for i, f in ipairs(cardTexts) do equal(IsLight(f), true, label .. ": Blizzard's card text " .. i .. " light") end
    for i, f in ipairs(names) do
        local c = f.textColour
        equal(c[1] >= .77 and c[2] >= .64 and c[3] == 0, true, label .. ": spell name " .. i .. " keeps its gold")
    end
end
local function FrameArtAt(label)
    for i = 2, 4 do equal(IsGrey(prof.NineSlice.regions[i]), true, label .. ": the window's frame piece " .. i) end
    for _, key in ipairs({ "titleStrip", "streaks", "backing" }) do equal(IsGrey(prof.fcui[key]), true, label .. ": its " .. key) end
    for i, t in ipairs(taxiArt) do equal(IsGrey(t), true, label .. ": a skinned window's frame art " .. i) end
    AllButtons(IsButton, label)
    equal(IsGrey(plate) and DarkBox(backing) and DarkBox(popupArt), true, label .. ": the game menu's and the pop-up's boxes")
end
-- The game's dark small text on the Professions window's plates and cards:
-- light while the pages are black (it can't be read on them otherwise), the
-- game's own brown the rest of the time; gold names never touched.
local function PlateText(light, label)
    for _, list in ipairs({ { plateSubs, "a spell's rank on its plate " }, { cardRanks, "a card's rank line " } }) do
        for i, f in ipairs(list[1]) do
            equal(light and IsLight(f) or (not light and OwnBrown(f)), true, label .. ": " .. list[2] .. i .. (light and " light" or " its own brown"))
        end
    end
    GoldUntouched(label)
end
local function PlateTextSets()
    local n = 0
    for _, list in ipairs({ plateSubs, cardRanks }) do for _, f in ipairs(list) do n = n + f.sets end end
    return n
end
-- Off (the default): today's brown-grey, exactly, the cover hidden.
PagesAt(IsBrown, IsPage, false, "Black Pages off")
TextKept("Black Pages off")
PlateText(false, "Black Pages off")
equal(PlateTextSets(), 0, "Black Pages off: the plates' and cards' small text never set")
-- On: black at once, live; the spellbook's frame in Dark Mode's grey.
E.settings.blackPages = true; ns.RefreshDarkWindows()
PagesAt(IsBlack, IsGrey, true, "Black Pages on")
TextKept("Black Pages on")
PlateText(true, "Black Pages on")
equal(PlateTextSets(), #plateSubs + #cardRanks, "Black Pages on: each piece of that text set once")
FrameArtAt("Black Pages on")
before = Sets()
ns.RefreshDarkWindows(); ns.RefreshDarkness(); NextPass(); prof:Fire("OnShow"); menu:Fire("OnShow")
equal(Sets(), before, "Black Pages: a pass with nothing new sets nothing")
-- The slider: the black stays black and isn't set again; the spellbook's
-- frame, the rings, bars' frames and frame art follow.
local function PageSets()
    local n = cover.sets
    for _, list in ipairs({ empties, bookPages, plates }) do for _, t in ipairs(list) do n = n + t.sets end end
    for _, card in ipairs(cards) do n = n + card.Background.sets end
    return n
end
local function BookFrameSets()
    local n = 0
    for _, t in ipairs(pages) do n = n + t.sets end
    return n
end
local pageSets, bookFrameSets, plateTextSets = PageSets(), BookFrameSets(), PlateTextSets()
E.settings.darkModeDarkness = 90; ns.RefreshDarkness()
PagesAt(IsBlack, IsGrey, true, "Black Pages at Darkness 90")
FrameArtAt("Black Pages at Darkness 90")
equal(PageSets(), pageSets, "the slider sets nothing on the black pages or the cover")
equal(BookFrameSets() - bookFrameSets, #pages, "the slider re-tints the spellbook's frame, once a piece")
equal(Near(pages[1].colour[1], .1), true, "Darkness 90: the spellbook's frame near black with the others")
E.settings.darkModeDarkness = 40; ns.RefreshDarkness()
PagesAt(IsBlack, IsGrey, true, "Black Pages at Darkness 40")
FrameArtAt("Black Pages at Darkness 40")
equal(Near(pages[1].colour[1], .6), true, "Darkness 40: the spellbook's frame a lighter grey")
E.settings.darkModeDarkness = 58; ns.RefreshDarkness()
PagesAt(IsBlack, IsGrey, true, "Black Pages at Darkness 58")
equal(PageSets(), pageSets, "the black pages and the cover still set only once")
PlateText(true, "Black Pages through the slider")
equal(PlateTextSets(), plateTextSets, "the slider sets nothing on the plates' and cards' small text")
-- Blizzard filling a card again: black again at once.
local missingSets = cards[2].missingText.sets
plateSubs[3]:SetTextColor(.35, .2, 0, 1) -- the game drawing card 2's first spell's rank again
prof.BookPage:FormatProfession(cards[2])
equal(IsBlack(cards[2].Background), true, "Black Pages: the card Blizzard filled is black again at once")
equal(IsLight(cards[2].missingText), true, "Black Pages: and its text light again at once")
equal(cards[2].missingText.sets - missingSets, 2, "the card's own text: Blizzard's colour and one repaint, not two")
equal(IsLight(plateSubs[3]) and IsLight(cardRanks[2]), true, "Black Pages: a spell's rank the game drew again light again at once")
GoldUntouched("Black Pages: Blizzard filling a card")
-- The spellbook's refresh keeps the slot frames' grey and the names' gold.
book:Refresh()
for i, t in ipairs(slotFrames) do
    if i == 2 then equal(Is(t, 0, 0, 0), true, "Black Pages: a passive's slot frame stays black")
    else equal(IsGrey(t), true, "Black Pages: slot frame " .. i .. " in Dark Mode's grey") end
end
equal(fireball.textColour[1] == 1 and fireball.textColour[2] == .82, true, "Black Pages: a spell name keeps its gold")
equal(IsLight(book.Buttons[2].SpellSubName), true, "Black Pages: \"Racial Passive\" stays light")
-- Dark Windows off with Black Pages still ticked: everything as before.
E.settings.darkWindows = false; ns.RefreshDarkWindows()
PagesAt(function(t) return t.desaturated == false and IsWhite(t) end, IsWhite, false, "Dark Windows off, Black Pages ticked")
PlateText(false, "Dark Windows off, Black Pages ticked")
before = Sets()
ns.RefreshDarkWindows(); ns.RefreshDarkness()
prof.BookPage:FormatProfession(cards[1])
equal(Sets() - before, 2, "Dark Windows off: the hidden cover and the small text left alone after (only Blizzard's own card colours)")
E.settings.darkWindows = true; ns.RefreshDarkWindows()
PagesAt(IsBlack, IsGrey, true, "Dark Windows back on: black again")
PlateText(true, "Dark Windows back on")
-- Off again, live: today's brown-grey exactly; and on again.
E.settings.blackPages = false; ns.RefreshDarkWindows()
PagesAt(IsBrown, IsPage, false, "Black Pages off again")
TextKept("Black Pages off again")
PlateText(false, "Black Pages off again")
FrameArtAt("Black Pages off again")
plateTextSets = PlateTextSets()
ns.RefreshDarkWindows(); NextPass(); prof:Fire("OnShow"); prof.BookPage:FormatProfession(cards[3])
equal(PlateTextSets(), plateTextSets, "Black Pages off: the small text left as the game drew it after")
E.settings.blackPages = true; ns.RefreshDarkWindows()
PagesAt(IsBlack, IsGrey, true, "Black Pages on again")
PlateText(true, "Black Pages on again")
E.settings.blackPages = nil; ns.RefreshDarkWindows()
PagesAt(IsBrown, IsPage, false, "Black Pages back to its default")
PlateText(false, "Black Pages back to its default")

---------------------------------------------------------------------------
-- The tick off: every piece its own colours back, once; then left alone.
---------------------------------------------------------------------------
E.settings.darkWindows = false; ns.RefreshDarkWindows()
AllButtons(function(t) return t.desaturated == false and IsWhite(t) end, "tick off: the red art as before")
AllGlows(function(t) return t.desaturated == false and IsWhite(t) end, "tick off: the glow as before")
BookAt(IsWhite, "tick off: the spellbook's parchment")
equal(cover.shown, false, "tick off: the spellbook's cover hidden")
ProfessionsAt(IsWhite, "tick off: the professions book")
for i, f in ipairs(subs) do
    local c = f.textColour
    equal(Near(c[1], .35) and Near(c[2], .2) and Near(c[3], 0) and c[4] == 1, true, "tick off: subtext " .. i .. " its own brown again")
end
equal(pageText.textColour[1] == 0 and pageText.textColour[3] == 0, true, "tick off: the page number black again")
book:Refresh()
for i, t in ipairs(slotFrames) do
    if i == 2 then equal(Is(t, 0, 0, 0), true, "tick off: the passive's slot frame black")
    else equal(IsWhite(t), true, "tick off: slot frame " .. i .. " as the book draws it") end
end
for i, f in ipairs(missingTexts) do equal(Near(f.textColour[1], .1), true, "tick off: missing text " .. i .. " its own colour") end
for i, card in ipairs(cards) do
    local h, t = card.missingHeader.textColour, card.missingText.textColour
    equal(Near(h[1], .15) and Near(h[3], .1) and Near(t[1], .35) and Near(t[2], .2), true, "tick off: Blizzard's card " .. i .. " text its own colours")
end
equal(IsGrey(corner), true, "tick off: Dark Mode's own grey stays on the metal corner")
for i = 2, 4 do equal(IsWhite(prof.NineSlice.regions[i]), true, "tick off: frame piece " .. i .. " white again") end
equal(IsWhite(plate) and backing.border[1] == 1 and backing.fill[1] == 1, true, "tick off: the game menu's box as before")
for i, box in ipairs(dialogBoxes) do equal(BorderIs(box, 1, 1, 1) and box.border[4] == 1, true, "tick off: dialog box " .. i .. "'s border as before") end
equal(FillIs(popupArt, 1, 1, 1, 1) and FillIs(status, 1, 1, 1, 1) and FillIs(welcome, 1, 1, 1, 1) and FillIs(dropList, 1, 1, 1, 1), true,
    "tick off: the boxes' fills white again")
equal(FillIs(reportBox, REPORT_FILL[1], REPORT_FILL[2], REPORT_FILL[3], REPORT_FILL[4]), true, "tick off: the report box's own brown fill again")
equal(controlsBox.fill == nil and tradeBox.fill == nil, true, "tick off: the inset boxes still have no fill set")
for i, t in ipairs(headers) do equal(IsWhite(t), true, "tick off: header plate " .. i .. " as before") end
for i, t in ipairs(taxiArt) do equal(IsWhite(t), true, "tick off: a skinned window's frame art " .. i .. " as before") end
for _, key in ipairs(CORNER_KEYS) do equal(IsGrey(taxi.NineSlice[key]), true, "tick off: its " .. key .. " keeps Dark Mode's own grey") end
before = Sets()
ns.RefreshDarkWindows(); ns.RefreshDarkness()
E.settings.darkModeDarkness = 90; ns.RefreshDarkness()
prof:Fire("OnShow"); NextPass(); menu:Fire("OnShow")
popup:Fire("OnShow"); skinWindow(taxi, {})
prof.BookPage:FormatProfession(cards[4])
equal(IsWhite(cards[4].Background), true, "tick off: a card Blizzard fills stays as Blizzard drew it")
equal(Sets() - before, 2, "tick off: left alone after (only Blizzard's own card colour and text colour)")
equal(IsGrey(corner), true, "Dark Mode's own grey on the corner still follows the slider")
-- A button made while the tick is off is left alone too, then darkened with the tick.
local late = NewButton()
ns.SkinRedButton(late)
equal(late.stateTex.Normal.sets, 0, "tick off: a new red button is left as it is")
red[#red + 1] = late
WatchButton(late)

-- Back on: dark again at once.
E.settings.darkWindows = true; ns.RefreshDarkWindows()
AllButtons(IsButton, "tick back on")
BookAt(IsPage, "tick back on")
ProfessionsAt(IsPage, "tick back on")
equal(IsLight(subs[1]) and IsLight(missingTexts[1]) and IsLight(cardTexts[2]), true, "tick back on: the small text light again")
book:Refresh()
for i, t in ipairs(slotFrames) do
    if i ~= 2 then equal(IsGrey(t), true, "tick back on: slot frame " .. i .. " grey after a refresh") end
end
equal(DarkBox(popupArt) and DarkBox(welcome) and DarkBox(reportBox, REPORT_FILL) and DarkBox(controlsBox, false), true,
    "tick back on: the boxes dark again")
for i, box in ipairs(dialogBoxes) do equal(BorderIs(box, Grey()), true, "tick back on: dialog box " .. i .. "'s border") end
for i, t in ipairs(headers) do equal(IsGrey(t), true, "tick back on: header plate " .. i) end
for i, t in ipairs(taxiArt) do equal(IsGrey(t), true, "tick back on: a skinned window's frame art " .. i) end

-- Dark Mode off (after a reload) or EraUI off: as without Dark Windows.
E.settings.enabled = false; ns.RefreshDarkWindows()
AllButtons(function(t) return t.desaturated == false and IsWhite(t) end, "EraUI off")
BookAt(IsWhite, "EraUI off")
E.settings.enabled = true; ns.RefreshDarkWindows()
AllButtons(IsButton, "EraUI back on")

---------------------------------------------------------------------------
-- Without Dark Mode: nothing touched, nothing hooked.
---------------------------------------------------------------------------
E.settings.darkMode = false
local plain = NewButton()
ns.SkinRedButton(plain)
E:SkinClassicRedButton(plain, "Test")
local plainPage = Texture()
ns.DarkWindowArt(plainPage, "page")
local plainText = env.UIParent:CreateFontString(nil, "ARTWORK", "SubSpellFont")
ns.DarkWindowText(plainText)
local plainRank = env.UIParent:CreateFontString(nil, "ARTWORK", "SubSpellFont")
ns.DarkBlackPageText(plainRank)
local plainBox = env.CreateFrame("Frame", nil, env.UIParent, "BackdropTemplate")
ns.DarkBackdrop(plainBox)
local plainInset = env.CreateFrame("Frame", nil, env.UIParent, "BackdropTemplate")
ns.DarkBackdrop(plainInset, false)
local plainBlack = env.CreateFrame("Frame", nil, env.UIParent, "BackdropTemplate")
ns.DarkBackdrop(plainBlack, { 0, 0, 0, 1 })
local plainTrim, plainHeader, plainCover = Texture(), Texture(), Texture()
ns.DarkWindowArt(plainTrim, "trim")
ns.DarkWindowArt(plainHeader, "frame")
plainCover.shown = false
ns.DarkWindowArt(plainCover, "cover")
E.settings.blackPages = true
ns.RefreshDarkWindows()
equal(plain.stateTex.Normal.sets + plain.stateTex.Highlight.sets + plainPage.sets + plainText.sets + plainBox.sets
    + plainInset.sets + plainBlack.sets + plainTrim.sets + plainHeader.sets + plainCover.sets + plainRank.sets, 0,
    "without Dark Mode nothing is set, Black Pages ticked or not")
equal(plainCover.shown, false, "without Dark Mode a cover stays hidden")
-- A spellbook built without Dark Mode: its cover is made hidden and stays so.
Load("Classic/SpellBook.lua")
ns.modules.spellBook.apply()
local plainBook = env.EraUIClassicSpellBook
equal(plainBook ~= book and plainBook.PageCover ~= nil, true, "setup: a second spellbook, built without Dark Mode")
equal(plainBook.PageCover.shown == false and plainBook.PageCover.colourTexture == nil, true,
    "without Dark Mode the spellbook's cover is made hidden, with no colour")
equal(ns.DarkWindowsOn() or ns.BlackPagesOn(), false, "and Dark Windows and Black Pages are off")
E.settings.blackPages = nil

-- Nor is Blizzard's Professions window hooked: a fresh load on a fresh
-- window, with Dark Mode off. Its watch stops listening once in the world.
local plainProf = env.CreateFrame("Frame", "ProfessionsFrame", env.UIParent)
plainProf.BookPage = env.CreateFrame("Frame", nil, plainProf)
local function BlizzardFormat() end
plainProf.BookPage.FormatProfession = BlizzardFormat
local plainLoaded = #frames
Load("Classic/Professions.lua")
local plainWatch
for i = plainLoaded + 1, #frames do if frames[i].events.ADDON_LOADED then plainWatch = frames[i] end end
equal(plainWatch ~= nil and plainWatch.events.PLAYER_ENTERING_WORLD, true, "setup: the fresh load's watch")
FireTo(plainWatch, "ADDON_LOADED", "Blizzard_Professions")
equal(plainProf.hooks.OnShow, nil, "without Dark Mode: the Professions window isn't hooked when it loads")
FireTo(plainWatch, "PLAYER_ENTERING_WORLD")
equal(plainProf.hooks.OnShow, nil, "nor on entering the world")
equal(next(plainWatch.events), nil, "without Dark Mode: the watch stops listening once in the world")
plainWatch.scripts.OnEvent(plainWatch, "PLAYER_REGEN_ENABLED")
equal(plainProf.hooks.OnShow, nil, "nor if a fight's end still reached it")
equal(plainProf.BookPage.FormatProfession, BlizzardFormat, "and Blizzard's FormatProfession is left as it is")

---------------------------------------------------------------------------
-- The game's help tips ("You have unspent talent points" and the like) and
-- the help plates' tooltip: the fill takes the frame grey, still fading to
-- black at the top; the glow edges and arrows lose their gold for the
-- buttons' lifted grey; the text and the close cross keep their colours.
-- Follows the slider; off, the fill's gold-brown and the edges' own colours
-- come back once; without Dark Mode nothing is touched.
---------------------------------------------------------------------------
local function TipPieces(f)
    local list = { f.BG }
    for _, key in ipairs(TIP_EDGES) do list[#list + 1] = f[key] end
    for _, key in ipairs({ "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "ArrowGlowUp", "ArrowGlowDown",
        "ArrowGlowLeft", "ArrowGlowRight" }) do list[#list + 1] = f[key] end
    if f.Arrow then list[#list + 1] = f.Arrow.Arrow; list[#list + 1] = f.Arrow.Glow end
    return list
end
local function FillIs(t, r, g, b)
    local low, high = t.gradient[2], t.gradient[3]
    return t.gradient[1] == "VERTICAL" and Near(low[1], r) and Near(low[2], g) and Near(low[3], b)
        and high[1] == 0 and high[2] == 0 and high[3] == 0
end
local function DarkTip(f, label)
    local r, g, b = Grey()
    equal(FillIs(f.BG, r, g, b), true, label .. ": the fill in the frame grey, black at the top")
    local edges = 0
    for _, t in ipairs(TipPieces(f)) do
        if t ~= f.BG then
            equal(IsButton(t), true, label .. ": a glow edge or arrow in the lifted grey")
            edges = edges + 1
        end
    end
    return edges
end
E.settings.darkMode, E.settings.darkWindows, E.settings.blackPages, E.settings.darkModeDarkness = true, true, nil, 90
env.HelpTip:Show(env.UIParent, { text = "You have unspent talent points." })
local tip = next(tipActive)
equal(DarkTip(tip, "Darkness 90"), 10, "the talents tip: eight glow edges, its arrow and the arrow's glow")
equal(tip.Text.textColour[1] == 1 and tip.Text.textColour[3] == 1 and tip.Text.sets == 0, true, "its white text is left alone")
equal(tip.CloseButton.Texture.sets, 0, "and its yellow close cross")
Watch(TipPieces(tip))
ns.RefreshDarkWindows() -- the earlier sections' pieces catch up with the settings above first
local before = Sets()
env.HelpTip:Show(env.UIParent, { text = "You have unspent talent points." })
ns.RefreshDarkWindows()
equal(Sets(), before, "shown again, or a pass with nothing new: nothing set again")
E.settings.darkModeDarkness = 58; ns.RefreshDarkness()
DarkTip(tip, "Darkness 58")
-- A tip the pool hands out again is still dark; a new one is painted as it shows.
env.HelpTip:Release(tip)
env.HelpTip:Show(env.UIParent, { text = "Another tip." })
equal(next(tipActive), tip, "setup: the pool hands the same box out again")
DarkTip(tip, "a reused box")
env.HelpTip:Show(env.UIParent, { text = "A second tip at once." })
local second
for f in pairs(tipActive) do if f ~= tip then second = f end end
DarkTip(second, "a second box")
-- The help plates' tooltip, the same box with four arrows of its own.
env.HelpPlateTooltip:Show()
equal(DarkTip(env.HelpPlateTooltip, "help plate tooltip"), 16, "the help plates' tooltip: its edges and all eight arrow pieces")
-- Off: everything back once, then left alone.
E.settings.darkWindows = false; ns.RefreshDarkWindows()
for _, f in ipairs({ tip, second, env.HelpPlateTooltip }) do
    equal(FillIs(f.BG, .23, .19, 0), true, "off: the fill's gold-brown is back")
    for _, t in ipairs(TipPieces(f)) do
        if t ~= f.BG then equal(t.desaturated == false and IsWhite(t), true, "off: an edge or arrow's own colours back") end
    end
end
Watch(TipPieces(second)); Watch(TipPieces(env.HelpPlateTooltip))
before = Sets()
ns.RefreshDarkWindows(); env.HelpTip:Show(env.UIParent, { text = "You have unspent talent points." })
equal(Sets(), before, "off: nothing set again")
E.settings.darkWindows = true; ns.RefreshDarkWindows()
DarkTip(tip, "on again")
-- Without Dark Mode (it needs a reload): a new box is never touched.
E.settings.darkMode = false
for f in pairs(tipActive) do env.HelpTip:Release(f) end
local fresh = GlowBox()
tipFree[#tipFree + 1] = fresh
env.HelpTip:Show(env.UIParent, { text = "You have unspent talent points." })
equal(next(tipActive), fresh, "setup: a box made without Dark Mode")
local touched = 0
for _, t in ipairs(TipPieces(fresh)) do touched = touched + t.sets end
equal(touched, 0, "without Dark Mode: a help tip is left exactly as the game drew it")
E.settings.darkMode, E.settings.darkModeDarkness = true, 90

print("Dark windows checks passed: " .. checks .. " assertions.")
