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
function Methods:SetBackdropColor(r, g, b) self.fill = { r, g, b }; self.sets = self.sets + 1 end
function Methods:SetBackdropBorderColor(r, g, b) self.border = { r, g, b }; self.sets = self.sets + 1 end
function Methods:SetTexture(file) self.file = file; return true end
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
function Methods:CreateTexture() return Texture(self) end
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
equal(pages[1].desaturated, nil, "the page keeps its own colours, only shaded")
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
local function Card(key, spells)
    local card = env.CreateFrame("Frame", nil, content)
    card.Background = Texture(card)
    for n = 1, spells do card["SpellButton" .. n] = env.CreateFrame("CheckButton", nil, card) end
    content[key] = card
    cards[#cards + 1] = card
    return card
end
for i = 1, 2 do Card("PrimaryProfession" .. i, 2) end
for i = 1, 3 do Card("SecondaryProfession" .. i, 4) end
local formatted = 0
function prof.BookPage:FormatProfession(card) formatted = formatted + 1; card.Background:SetVertexColor(1, 1, 1) end
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
-- The tick off: every piece its own colours back, once; then left alone.
---------------------------------------------------------------------------
E.settings.darkWindows = false; ns.RefreshDarkWindows()
AllButtons(function(t) return t.desaturated == false and IsWhite(t) end, "tick off: the red art as before")
AllGlows(function(t) return t.desaturated == false and IsWhite(t) end, "tick off: the glow as before")
BookAt(IsWhite, "tick off: the spellbook's parchment")
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
equal(IsGrey(corner), true, "tick off: Dark Mode's own grey stays on the metal corner")
for i = 2, 4 do equal(IsWhite(prof.NineSlice.regions[i]), true, "tick off: frame piece " .. i .. " white again") end
equal(IsWhite(plate) and backing.border[1] == 1 and backing.fill[1] == 1, true, "tick off: the game menu's box as before")
before = Sets()
ns.RefreshDarkWindows(); ns.RefreshDarkness()
E.settings.darkModeDarkness = 90; ns.RefreshDarkness()
prof:Fire("OnShow"); NextPass(); menu:Fire("OnShow")
prof.BookPage:FormatProfession(cards[4])
equal(IsWhite(cards[4].Background), true, "tick off: a card Blizzard fills stays as Blizzard drew it")
equal(Sets() - before, 1, "tick off: left alone after (only Blizzard's own card colour)")
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
equal(IsLight(subs[1]) and IsLight(missingTexts[1]), true, "tick back on: the small text light again")
book:Refresh()
for i, t in ipairs(slotFrames) do
    if i ~= 2 then equal(IsGrey(t), true, "tick back on: slot frame " .. i .. " grey after a refresh") end
end

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
local plainBox = env.CreateFrame("Frame", nil, env.UIParent, "BackdropTemplate")
ns.DarkBackdrop(plainBox)
ns.RefreshDarkWindows()
equal(plain.stateTex.Normal.sets + plain.stateTex.Highlight.sets + plainPage.sets + plainText.sets + plainBox.sets, 0,
    "without Dark Mode nothing is set")
equal(ns.DarkWindowsOn(), false, "and Dark Windows is off")

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

print("Dark windows checks passed: " .. checks .. " assertions.")
