-- Bag Addon Windows (/era: Appearance > Dark Mode > Bars and windows, under
-- Dark Bag Buttons) on the real Look/BarArt.lua, against a mock bag addon
-- built the way the one Squirt uses builds its window on Forever: a row of
-- bag slot buttons along the window's top (item buttons with the game's item
-- button methods copied on, each refreshed by its own Init), the same row
-- for another character's bags (SetItemDetails), and under the items the
-- coin for currencies, the special bags' buttons (a quiver's arrows, an herb
-- bag's leaf: each made hidden, then shown, and reused for another kind of
-- bag by setting its icon while hidden) and the item buttons. The addon
-- names every button it makes through its skin API (its active skin first,
-- then each listener) and tags its bag slots and special bags' buttons.
--
-- Off by default: nothing joined, hooked or painted. Dark Bag Buttons alone:
-- the bag bar only. Both: every bag slot and special bag's button grey at
-- .6, all alike, quivers and profession bags too, after each of the addon's
-- own updates (a new bag, another character's bags, a fight greying them, a
-- skin's tint, a special bag's button reused); the coin and the items keep
-- their look. Off again, or Dark Bag Buttons off, or EraUI off: each one
-- gets back exactly its own colour and grey, then is left alone. A window
-- built later is joined as it's made; the addon loading after EraUI is
-- joined as it loads; no bag addon, or one without the skin API, is no
-- error. No key is written on its frames.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Mock widgets --------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's or the addon's objects shows up in writes as "Name.key".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes = {}
local scriptHooks = 0 -- HookScript calls (state kept beside the frame, never on it)
local function Noop() end
for _, name in ipairs({ "SetTexCoord", "ClearAllPoints", "SetSize", "SetPoint", "SetAllPoints", "SetDrawLayer",
    "SetWidth", "SetFontObject" }) do Proto[name] = Noop end
local function New(kind, name, foreign)
    local obj = {}
    S[obj] = { kind = kind, name = name, foreign = foreign, colour = { 1, 1, 1, 1 }, grey = false, alpha = 1,
        shown = true, colours = 0 }
    return setmetatable(obj, {
        __index = Proto,
        __newindex = function(t, key, value)
            if S[t].foreign then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
local function Put(obj, key, value) rawset(obj, key, value); return value end
issecretvalue = function() return false end
-- A texture: its colour (each SetVertexColor counted), grey or not, file.
-- A new file resets its colour and grey (the worst case), so every repaint
-- has to come from a hook.
function Proto:SetVertexColor(r, g, b, a)
    local s = S[self]
    s.colour, s.colours = { r, g, b, a or 1 }, s.colours + 1
end
function Proto:GetVertexColor() local c = S[self].colour; return c[1], c[2], c[3], c[4] end
function Proto:SetDesaturated(v) S[self].grey = v and true or false end
function Proto:IsDesaturated() return S[self].grey end
local function NewFile(self, file) local s = S[self]; s.file, s.colour, s.grey = file, { 1, 1, 1, 1 }, false; return true end
Proto.SetTexture, Proto.SetAtlas = NewFile, NewFile
function Proto:SetBlendMode() end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
-- Showing a hidden frame runs its OnShow, then each hook on it.
function Proto:Show()
    local s = S[self]
    if s.shown then return end
    s.shown = true
    if s.scripts and s.scripts.OnShow then s.scripts.OnShow(self) end
    for _, fn in ipairs(s.hooked and s.hooked.OnShow or {}) do fn(self) end
end
function Proto:Hide() S[self].shown = false end
function Proto:HookScript(kind, fn)
    local s = S[self]
    s.hooked = s.hooked or {}
    s.hooked[kind] = s.hooked[kind] or {}
    table.insert(s.hooked[kind], fn)
    scriptHooks = scriptHooks + 1
end
local function Hooked(obj)
    local n = 0
    for _, list in pairs(S[obj].hooked or {}) do n = n + #list end
    return n
end
function Proto:IsShown() return S[self].shown end
function Proto:GetWidth() return 37 end
function Proto:GetName() return nil end
function Proto:GetID() return S[self].id end
function Proto:RegisterEvent(event) S[self].events = S[self].events or {}; S[self].events[event] = true end
function Proto:UnregisterAllEvents() S[self].events = {} end
function Proto:SetScript(kind, fn) S[self].scripts = S[self].scripts or {}; S[self].scripts[kind] = fn end

-- The game ---------------------------------------------------------------------
local hooks = 0
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    hooks = hooks + 1
    local old = t[key]
    t[key] = function(...) old(...); fn(...) end
end
local frames = {}
CreateFrame = function(kind)
    local f = New(kind or "Frame", nil, false)
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        local s = S[f]
        if s.events and s.events[event] and s.scripts and s.scripts.OnEvent then s.scripts.OnEvent(f, event, ...) end
    end
end
GetInventoryItemTexture = function() return nil end
-- The item-button calls as Forever has them (Blizzard_ItemButton): the
-- button's own method when it has one, its icon otherwise.
function SetItemButtonTexture(button, texture)
    if button.SetItemButtonTexture then button:SetItemButtonTexture(texture) else button.icon:SetTexture(texture) end
end
function SetItemButtonTextureVertexColor(button, r, g, b)
    if button.SetItemButtonTextureVertexColor then button:SetItemButtonTextureVertexColor(r, g, b)
    else button.icon:SetVertexColor(r, g, b) end
end
function SetItemButtonDesaturated(button, desaturated)
    local icon = button.icon or button.Icon
    if icon then icon:SetDesaturated(desaturated) end
end
function SetItemButtonQuality(button, quality)
    if button.SetItemButtonQuality then button:SetItemButtonQuality(quality) end
end
-- As the game has them, before any hook (each session below starts clean).
local GAME_GREY, GAME_COLOUR = SetItemButtonDesaturated, SetItemButtonTextureVertexColor
-- The bag bar's backpack, to show Dark Bag Buttons' own buttons go their own way.
local backpack = New("ItemButton", "MainMenuBarBackpackButton", true)
Put(backpack, "icon", New("Texture", "MainMenuBarBackpackButtonIcon", true))
Put(backpack, "SlotHighlightTexture", New("Texture", "MainMenuBarBackpackButtonSlotHighlight", true))
Put(backpack, "UpdateTextures", function(self) self.icon:SetTexture("Interface\\Icons\\ui-hud-actionbar-bag") end)
_G.MainMenuBarBackpackButton = backpack
backpack:UpdateTextures()

-- The bag addon -----------------------------------------------------------------
-- The game's ItemButton widget, as its intrinsic copies these onto each one.
local ITEM_BUTTON = {
    SetItemButtonTexture = function(self, texture)
        self.icon:SetTexture(texture)
        if texture then self.icon:Show() else self.icon:Hide() end
    end,
    SetItemButtonTextureVertexColor = function(self, r, g, b) self.icon:SetVertexColor(r, g, b) end,
    SetItemButtonQuality = function(self, quality) S[self].quality = quality; self.IconBorder:SetVertexColor(1, 1, 1) end,
    SetItemButtonCount = function(self, count) S[self].count = count end,
}
-- What the player wears: a plain bag, a quiver, an herb satchel, another
-- bag, and the empty fifth slot. Another character's bags: an ammo pouch,
-- an enchanting bag, a soul bag.
local worn = { "Bag_Teal", "Quiver", "HerbSatchel", "Bag_Pink" }
local alts = { "AmmoPouch", "EnchantingBag", "SoulBag", "Bag_Orange" }
-- A live slot: its Init sets the worn bag's icon, its quality, its free
-- slots and the icon's alpha.
local LIVE_SLOT = {
    Init = function(self)
        local id = self:GetID()
        self:SetItemButtonTexture(worn[id])
        self:SetItemButtonQuality(worn[id] and 1 or 0)
        self:SetItemButtonCount(id * 4)
        self.icon:SetAlpha(1)
    end,
}
-- Another character's slot: its details, then the game's call taking off any grey.
local CACHED_SLOT = {
    UpdateTextures = function() end,
    SetItemDetails = function(self, details)
        self:SetItemButtonTexture(details.iconTexture)
        self:SetItemButtonQuality(details.quality)
        SetItemButtonDesaturated(self, false)
    end,
}
local function ItemButton(name, mixin)
    local b = New("ItemButton", name, true)
    Put(b, "icon", New("Texture", name .. ".icon", true))
    Put(b, "IconBorder", New("Texture", name .. ".IconBorder", true))
    Put(b, "SlotBackground", New("Texture", name .. ".SlotBackground", true))
    for key, fn in pairs(ITEM_BUTTON) do Put(b, key, fn) end
    for key, fn in pairs(mixin or {}) do Put(b, key, fn) end
    return b
end
local function IconButton(name, art)
    local b = New("Button", name, true)
    Put(b, "Icon", New("Texture", name .. ".Icon", true))
    b.Icon:SetTexture(art)
    return b
end
-- Another addon's post-hook on one of these buttons (a skin's), never counted as EraUI's.
local function Also(obj, key, fn)
    local old = rawget(obj, key)
    rawset(obj, key, function(...) old(...); fn(...) end)
end
-- The active skin tints a special bag's icon after each new icon: the
-- addon's own colour, kept under the grey and given back exactly.
local TINT = { Quiver = { 1, .85, .55 }, HerbSatchel = { .75, 1, .75 }, AmmoPouch = { .9, .8, .7 } }
local function Skin(button)
    Also(button, "SetItemButtonTexture", function(self, texture)
        local tint = TINT[texture]
        if tint then self.icon:SetVertexColor(tint[1], tint[2], tint[3]) end
    end)
end

local function LoadAddon(withApi)
    local addon = { all = {}, listeners = {}, named = {} }
    local api = { Skins = {} }
    if withApi ~= false then
        api.Skins.GetAllFrames = function() return addon.all end
        api.Skins.RegisterListener = function(fn) addon.listeners[#addon.listeners + 1] = fn end
    end
    _G.Baganator = { API = api }
    -- Its own AddFrame: once a frame, its skin first, then each listener.
    function addon.AddFrame(kind, region, tags)
        if addon.named[region] then return end
        addon.named[region] = true
        local details = { regionType = kind, region = region, tags = tags }
        addon.all[#addon.all + 1] = details
        if kind == "ItemButton" then Skin(region) end
        for _, fn in ipairs(addon.listeners) do pcall(fn, details) end
    end
    return addon
end
-- One window: five live slots (four bags and the reagent bag's), five for
-- another character, then the coin for currencies, the special bags'
-- buttons (the quiver's, the herb bag's), and an item.
local function BuildWindow(addon, group)
    local view = { live = {}, cached = {} }
    for index = 1, 5 do
        local slot = ItemButton(group .. "Live" .. index, LIVE_SLOT)
        S[slot].id = index
        view.live[index] = slot
        addon.AddFrame("ItemButton", slot, { "containerBag" })
    end
    for index = 1, 5 do
        local slot = ItemButton(group .. "Cached" .. index, CACHED_SLOT)
        addon.AddFrame("ItemButton", slot, { "containerBag" })
        slot:UpdateTextures()
        Put(slot, "isBag", true)
        S[slot].id = index
        view.cached[index] = slot
        addon.AddFrame("ItemButton", slot)
    end
    view.coin = IconButton(group .. "Currency", "Currency.png")
    addon.AddFrame("IconButton", view.coin, { "currency" })
    -- Each special bag's button: its icon set, hidden, named, then shown
    -- once the window is laid out.
    view.sections = {}
    for index, art in ipairs({ "Ammunition", "Mobile-Herbalism" }) do
        local section = IconButton(group .. "Section" .. index, art)
        section:Hide()
        addon.AddFrame("IconButton", section, { "collapsingBagSection" })
        section:Show()
        view.sections[index] = section
    end
    view.item = ItemButton(group .. "Item", {})
    addon.AddFrame("ItemButton", view.item)
    view.item:SetItemButtonTexture("Arrow")
    return view
end
local function Refresh(view) for _, slot in ipairs(view.live) do slot:Init() end end
local function ShowAlt(view)
    for index, slot in ipairs(view.cached) do slot:SetItemDetails({ iconTexture = alts[index], quality = 1 }) end
end
-- The addon greys its live slots in a fight, and takes the grey off after.
local function Fight(view, on) for _, slot in ipairs(view.live) do SetItemButtonDesaturated(slot, on) end end
-- The addon reuses a special bag's button for another kind of bag: hidden,
-- a new icon (which, at worst, loses its colour and grey), shown again.
local function Reuse(section, art) section:Hide(); section.Icon:SetAtlas(art); section:Hide(); section:Show() end

-- Reading the look ---------------------------------------------------------------
local function C(texture) local c = S[texture].colour; return string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]) end
local function Face(b) return b.icon or b.Icon end
local function Look(b) return C(Face(b)) .. (S[Face(b)].grey and " grey" or " colour") end
local GREY, WHITE = "0.60,0.60,0.60", "1.00,1.00,1.00"
local DARK, PLAIN = GREY .. " grey", WHITE .. " colour"
local function Own(name) local t = TINT[name]; return t and string.format("%.2f,%.2f,%.2f colour", t[1], t[2], t[3]) or PLAIN end
-- Every bag button on a window: its live and cached slots, its special bags' buttons.
local function Slots(view)
    local all = {}
    for _, group in ipairs({ view.live, view.cached, view.sections }) do
        for _, s in ipairs(group) do all[#all + 1] = s end
    end
    return all
end
local function Every(view, want, label)
    for _, slot in ipairs(Slots(view)) do equal(Look(slot), want, label .. ": " .. S[slot].name) end
end
-- Each one's own look: its bag's tint (a quiver's, an herb satchel's), or
-- white; a special bag's button keeps its icon's own colours (white).
local function Owns(view, label, greyLive)
    for index, slot in ipairs(view.live) do
        local want = Own(worn[index])
        if greyLive then want = want:gsub(" colour$", " grey") end
        equal(Look(slot), want, label .. ": " .. S[slot].name)
    end
    for index, slot in ipairs(view.cached) do equal(Look(slot), Own(alts[index]), label .. ": " .. S[slot].name) end
    for _, section in ipairs(view.sections) do equal(Look(section), PLAIN, label .. ": " .. S[section].name) end
end
-- The coin for currencies and the items are never touched.
local function Untouched(view, label)
    equal(C(view.coin.Icon) .. " " .. tostring(S[view.coin.Icon].grey) .. " " .. S[view.coin.Icon].colours,
        WHITE .. " false 0", label .. ": the coin for currencies")
    equal(Hooked(view.coin), 0, label .. ": the coin not hooked")
    equal(Look(view.item) .. " " .. S[view.item.icon].colours, PLAIN .. " 0", label .. ": an item in the bags")
end
local function Colours(view)
    local n = 0
    for _, slot in ipairs(Slots(view)) do n = n + S[Face(slot)].colours end
    return n
end

-- EraUI ----------------------------------------------------------------------------
local function LoadEraUI(settings)
    SetItemButtonDesaturated, SetItemButtonTextureVertexColor = GAME_GREY, GAME_COLOUR
    local E = { modules = {}, Classic = {}, settings = settings }
    function E:GetSetting(key) return self.settings[key] end
    assert(loadfile("Look/Base.lua"))("EraUI", E)
    assert(loadfile("Look/BarArt.lua"))("EraUI", E)
    return E, E.Classic
end
local function World() Fire("PLAYER_ENTERING_WORLD") end

---------------------------------------------------------------------------------
-- The usual order: the bag addon loads before EraUI and builds its window at
-- login, before the world.
---------------------------------------------------------------------------------
local addon = LoadAddon()
local E, ns = LoadEraUI({ enabled = true, darkMode = true })
local view = BuildWindow(addon, "blizzard")
hooks, scriptHooks = 0, 0
Refresh(view); ShowAlt(view)
Owns(view, "the addon's own look")

-- Off by default (Core/Init.lua: Tools/TestPersistence.lua): the world, the
-- addon's updates and a refresh join, hook and paint nothing.
local before = Colours(view)
World(); Refresh(view); ShowAlt(view); ns.RefreshDarkBagButtons()
Reuse(view.sections[1], "Ammunition")
-- (The addon's own calls only: the quiver's, the herb satchel's and the ammo pouch's tints.)
equal(#addon.listeners .. " " .. hooks .. " " .. scriptHooks .. " " .. (Colours(view) - before), "0 0 0 3",
    "off: nothing joined, hooked or painted")
Owns(view, "off")
Untouched(view, "off")

-- Dark Bag Buttons alone: the bag bar goes dark, the bag addon's slots don't,
-- and EraUI still doesn't join it.
E.settings.darkBagButtons = true
ns.RefreshDarkBagButtons()
equal(Look(backpack), DARK, "Dark Bag Buttons: the bag bar's backpack dark")
equal(#addon.listeners, 0, "Dark Bag Buttons alone: the bag addon not joined")
Refresh(view); ShowAlt(view)
Owns(view, "Dark Bag Buttons alone")
local barHooks = hooks

-- The tick on (Settings calls the same refresh): every slot and special
-- bag's button grey and darker, all alike, a quiver and an herb satchel too,
-- the skin's tints kept for later; the coin and the items as they were.
E.settings.darkBagAddonSlots = true
ns.RefreshDarkBagButtons()
equal(#addon.listeners, 1, "on: joined through the skin API once")
Every(view, DARK, "on")
Untouched(view, "on")
equal(S[view.live[2].icon].file .. " " .. S[view.live[3].icon].file, "Quiver HerbSatchel", "the icons themselves are the addon's")
equal(S[view.sections[1].Icon].file .. " " .. S[view.sections[2].Icon].file, "Ammunition Mobile-Herbalism",
    "the special bags' buttons keep the addon's icons")
local slotHooks = hooks - barHooks
-- A live slot follows Init and the three item-button methods it has;
-- another character's follows SetItemDetails and UpdateTextures instead of Init.
equal(slotHooks, 5 * 4 + 5 * 5, "each slot's own updates hooked once")
-- A special bag's button has no update of its own: its showing is followed.
equal(scriptHooks .. " " .. Hooked(view.sections[1]) .. " " .. Hooked(view.sections[2]), "2 1 1",
    "each special bag's button: its showing hooked once, nothing else's")
equal(Look(backpack), DARK, "the bag bar stays dark")

-- The addon's own updates after EraUI's: each ends dark.
Refresh(view)
Every(view, DARK, "the addon refreshes its slots")
worn[4] = "Bag_Green"; view.live[4]:Init()
equal(Look(view.live[4]) .. " " .. S[view.live[4].icon].file, DARK .. " Bag_Green", "a new bag: its icon, grey and dark")
ShowAlt(view)
Every(view, DARK, "another character's bags (an ammo pouch, an enchanting bag, a soul bag)")
SetItemButtonQuality(view.live[1], 4)
equal(Look(view.live[1]), DARK, "a quality change: still dark")
SetItemButtonTextureVertexColor(view.live[2], .5, .2, .2)
equal(Look(view.live[2]), DARK, "the game's colour call: still dark")
view.live[2]:Init()
Fight(view, true)
Every(view, DARK, "a fight: the addon greys its slots, still dark")
Fight(view, false)
Every(view, DARK, "after the fight: still grey and dark")
-- A special bag's button reused for another kind of bag (a new icon while
-- it's hidden, then shown): its new icon, grey and dark.
Reuse(view.sections[1], "Mobile-Enginnering")
equal(Look(view.sections[1]) .. " " .. S[view.sections[1].Icon].file, DARK .. " Mobile-Enginnering",
    "a special bag's button reused: its new icon, grey and dark")
Reuse(view.sections[1], "Ammunition")
-- A skin hooked after EraUI: the slot's Init ends with EraUI's look all the
-- same. (Then it stops tinting, and the next Init takes its tint as gone.)
local lateSkin = true
Also(view.live[1], "SetItemButtonTexture", function(self) if lateSkin then self.icon:SetVertexColor(.3, .6, 1) end end)
view.live[1]:Init()
equal(Look(view.live[1]), DARK, "a skin hooked after EraUI: Init still ends dark")
lateSkin = false
view.live[1]:Init()
Untouched(view, "after the addon's updates")
-- Every later pass and event (the window closed and opened again too) adds
-- no hook and changes nothing.
local settled, settledScripts = hooks, scriptHooks
ns.RefreshDarkBagButtons(); World(); ns.RefreshDarkBagButtons()
for _, section in ipairs(view.sections) do section:Hide(); section:Show() end
Every(view, DARK, "again")
equal(hooks .. " " .. scriptHooks .. " " .. #addon.listeners, settled .. " " .. settledScripts .. " 1",
    "no hook or listener added by later passes")

-- A new window (a new skin builds its own): joined as the addon makes it.
local second = BuildWindow(addon, "dark")
Refresh(second); ShowAlt(second)
Every(second, DARK, "a window built later")
Untouched(second, "a window built later")

-- Off again in a fight: each slot gets back exactly its own look (the skin's
-- tints, the white, the fight's grey on the live slots), then is left alone.
Fight(view, true)
E.settings.darkBagAddonSlots = false
ns.RefreshDarkBagButtons()
Owns(view, "off in a fight", true)
equal(Look(backpack), DARK, "off: the bag bar keeps Dark Bag Buttons")
Fight(view, false)
Owns(view, "after the fight")
before = Colours(view)
Refresh(view); ShowAlt(view); ns.RefreshDarkBagButtons(); World()
Reuse(view.sections[2], "Mobile-Enginnering"); Reuse(view.sections[2], "Mobile-Herbalism")
Owns(view, "off: the addon's updates show its own look")
-- Only the addon's own calls: the quiver's and the herb satchel's tint after
-- each live refresh, the ammo pouch's after another character's.
equal(Colours(view) - before, 3, "off: EraUI paints nothing more")
Owns(second, "off: the later window")

-- On again, then Dark Bag Buttons off: the slots go back too, and come back
-- dark with it. EraUI off: the tick waits.
E.settings.darkBagAddonSlots = true
ns.RefreshDarkBagButtons()
Every(view, DARK, "on again")
E.settings.darkBagButtons = false
ns.RefreshDarkBagButtons()
Owns(view, "Dark Bag Buttons off")
equal(Look(backpack), PLAIN, "Dark Bag Buttons off: the bag bar's own look")
Refresh(view); ShowAlt(view)
Owns(view, "Dark Bag Buttons off: the addon's updates")
E.settings.darkBagButtons = true
ns.RefreshDarkBagButtons()
Every(view, DARK, "Dark Bag Buttons on again")
E.settings.enabled = false
ns.RefreshDarkBagButtons()
Owns(view, "EraUI off")
E.settings.enabled = true
ns.RefreshDarkBagButtons()
Every(view, DARK, "EraUI on again")
Every(second, DARK, "EraUI on again, the later window")

equal(#writes, 0, "no key written on the game's or the addon's frames (" .. table.concat(writes, ", ") .. ")")

---------------------------------------------------------------------------------
-- The tick saved on, Dark Bag Buttons saved off: nothing joined at all.
---------------------------------------------------------------------------------
frames, hooks, scriptHooks = {}, 0, 0
addon = LoadAddon()
E, ns = LoadEraUI({ enabled = true, darkBagAddonSlots = true })
view = BuildWindow(addon, "blizzard")
World(); Refresh(view); ShowAlt(view); ns.RefreshDarkBagButtons()
Reuse(view.sections[1], "Mobile-Enginnering")
equal(#addon.listeners .. " " .. hooks .. " " .. scriptHooks, "0 0 0", "Dark Bag Buttons off: the tick waits, nothing joined or hooked")
Owns(view, "Dark Bag Buttons off at login")

---------------------------------------------------------------------------------
-- Both saved on: the world joins the window built at login.
---------------------------------------------------------------------------------
frames = {}
addon = LoadAddon()
E, ns = LoadEraUI({ enabled = true, darkBagButtons = true, darkBagAddonSlots = true })
view = BuildWindow(addon, "blizzard")
equal(#addon.listeners, 0, "before the world: nothing joined yet")
World()
Refresh(view); ShowAlt(view)
Every(view, DARK, "both saved on: dark from the world")

---------------------------------------------------------------------------------
-- No bag addon: no error, nothing joined. It loading later (after EraUI):
-- joined as it loads, its window dark as it's built. Another addon loading
-- joins nothing.
---------------------------------------------------------------------------------
frames = {}
_G.Baganator = nil
E, ns = LoadEraUI({ enabled = true, darkBagButtons = true, darkBagAddonSlots = true })
World(); ns.RefreshDarkBagButtons(); ns.RefreshDarkBagButtons()
Fire("ADDON_LOADED", "SomeOtherAddon")
addon = LoadAddon()
Fire("ADDON_LOADED", "SomeOtherAddon")
equal(#addon.listeners, 0, "another addon loading: the bag addon not joined yet")
Fire("ADDON_LOADED", "Baganator")
equal(#addon.listeners, 1, "the bag addon loading after EraUI: joined as it loads")
view = BuildWindow(addon, "blizzard")
Refresh(view); ShowAlt(view)
Every(view, DARK, "its window, built after it loads")
Untouched(view, "loaded later")
Fire("ADDON_LOADED", "Baganator"); ns.RefreshDarkBagButtons()
equal(#addon.listeners, 1, "joined once")

-- It loading while the tick is off: joined when the tick comes on.
frames = {}
_G.Baganator = nil
E, ns = LoadEraUI({ enabled = true, darkBagButtons = true, darkBagAddonSlots = true })
World()
E.settings.darkBagAddonSlots = false
ns.RefreshDarkBagButtons()
addon = LoadAddon()
view = BuildWindow(addon, "blizzard")
Fire("ADDON_LOADED", "Baganator")
Refresh(view); ShowAlt(view)
equal(#addon.listeners, 0, "loaded while the tick is off: not joined")
Owns(view, "loaded while the tick is off")
-- Switched on in a fight, with the addon's slots already greyed: that grey
-- is theirs, given back when the tick goes off again before the fight ends.
Fight(view, true)
E.settings.darkBagAddonSlots = true
ns.RefreshDarkBagButtons()
Every(view, DARK, "the tick on in a fight: its window joined and dark")
E.settings.darkBagAddonSlots = false
ns.RefreshDarkBagButtons()
Owns(view, "off again in the same fight: the addon's own grey back", true)
Fight(view, false)
Owns(view, "after the fight")
E.settings.darkBagAddonSlots = true
ns.RefreshDarkBagButtons()
Every(view, DARK, "the tick on again")

-- A bag addon without the skin API: nothing, no error.
frames = {}
addon = LoadAddon(false)
E, ns = LoadEraUI({ enabled = true, darkBagButtons = true, darkBagAddonSlots = true })
view = BuildWindow(addon, "blizzard")
World(); Refresh(view); ShowAlt(view); ns.RefreshDarkBagButtons()
Fire("ADDON_LOADED", "Baganator")
Owns(view, "no skin API: left alone")

equal(#writes, 0, "still no key written on the game's or the addon's frames (" .. table.concat(writes, ", ") .. ")")

print("Bag addon window checks passed: " .. checks .. " assertions.")
