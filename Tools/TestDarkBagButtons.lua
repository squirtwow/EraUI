-- Dark Bag Buttons (/era: Appearance > Dark Mode > Bars and windows) on the
-- real Classic/BarSkins.lua, against a mock of Forever's bag bar: the
-- backpack, four bag slots, the reagent bag and the key ring, each with its
-- icon and the line the game shows while that bag is open, and the game's own
-- updates as Forever's code runs them (a bag slot's update sets the icon,
-- puts its colour back, refreshes the frame art and ends by greying a bag
-- that's being moved). Off by default: nothing is hooked or painted. On in
-- Dark Mode: every icon grey at .6, all alike, and the open-bag line dark,
-- after every one of those updates; a skin that recolours the line after the
-- game (as a button skin addon does) is painted over once the slot's update
-- ends. Off again: each texture gets back the colour it had (the game's, a
-- broken item's red, a skin's), then is left alone. EraUI's own Classic bag
-- art shows an open bag pressed in instead of its additive glow. A secret
-- colour is never compared or kept, other item buttons are never touched,
-- and no key is written on the game's frames.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Mock widgets --------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's objects shows up in writes as "Name.key".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes = {}
local function Noop() end
-- Placement calls EraUI's Classic bag art makes: allowed, nothing to check.
-- Anything else a mock lacks is nil, as on the game.
for _, name in ipairs({ "SetTexCoord", "ClearAllPoints", "SetSize", "SetPoint", "SetAllPoints", "SetDrawLayer",
    "SetWidth", "SetFontObject" }) do Proto[name] = Noop end
local function New(kind, name, game)
    local obj = {}
    S[obj] = { kind = kind, name = name, game = game, colour = { 1, 1, 1, 1 }, grey = false, blend = "BLEND",
        alpha = 1, shown = true, colours = 0 }
    return setmetatable(obj, {
        __index = Proto,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
local secret = {}
issecretvalue = function(v) return v ~= nil and secret[v] == true end
-- A texture: its colour (each SetVertexColor counted), grey or not, file and
-- blend. Forever may reset a texture's colour when its file changes; the mock
-- does, the worst case, so every repaint has to come from a hook.
function Proto:SetVertexColor(r, g, b, a)
    local s = S[self]
    s.colour, s.colours = { r, g, b, a or 1 }, s.colours + 1
end
function Proto:GetVertexColor()
    local s = S[self]
    if s.secretColour then return s.secretColour, s.secretColour, s.secretColour, s.secretColour end
    return s.colour[1], s.colour[2], s.colour[3], s.colour[4]
end
function Proto:SetDesaturated(v) S[self].grey = v and true or false end
function Proto:IsDesaturated() return S[self].grey end
local function NewFile(self, file) local s = S[self]; s.file, s.colour, s.grey = file, { 1, 1, 1, 1 }, false; return true end
Proto.SetTexture, Proto.SetAtlas = NewFile, NewFile
function Proto:SetBlendMode(mode) S[self].blend = mode end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:Show() S[self].shown = true end
function Proto:Hide() S[self].shown = false end
function Proto:SetShown(v) S[self].shown = v and true or false end
function Proto:IsShown() return S[self].shown end
function Proto:GetWidth() return 30 end
function Proto:GetName() return S[self].name end
-- Frames: their state textures, ID, and the scripts EraUI's own watchers keep.
function Proto:GetNormalTexture() return S[self].normal end
function Proto:GetPushedTexture() return S[self].pushed end
function Proto:GetHighlightTexture() return S[self].highlight end
function Proto:GetID() return S[self].id end
function Proto:RegisterEvent(event) S[self].events = S[self].events or {}; S[self].events[event] = true end
function Proto:SetScript(kind, fn) S[self].scripts = S[self].scripts or {}; S[self].scripts[kind] = fn end

-- The game -------------------------------------------------------------------
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
local inventory, broken, locked = {}, {}, {}
GetInventoryItemTexture = function(_, id) return inventory[id] end
local EMPTY_BAG = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"

-- The item-button calls as Forever has them (Blizzard_ItemButton): the button's
-- own method when it has one, its icon otherwise.
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
-- A bag slot's update, in Forever's order (PaperDollItemSlotButton_Update).
function PaperDollItemSlotButton_Update(self)
    local id = self:GetID()
    SetItemButtonTexture(self, inventory[id] or EMPTY_BAG)
    if broken[id] then SetItemButtonTextureVertexColor(self, .9, 0, 0) else SetItemButtonTextureVertexColor(self, 1, 1, 1) end
    SetItemButtonQuality(self, 1)
    SetItemButtonDesaturated(self, locked[id] == true)
end

-- The bag bar: methods and keys put on as the game's XML and mixins do.
local function Put(obj, key, value) rawset(obj, key, value); return value end
local updates = 0
local function UpdateTextures(self)
    updates = updates + 1
    local s = S[self]
    if s.bagIcon then self.icon:SetTexture(s.bagIcon) end
    s.normal:SetAtlas("ui-hud-actionbar-iconframe-bags")
    self.SlotHighlightTexture:SetAtlas("ui-hud-actionbar-iconframe-bags")
end
local function BagButton(name, id, bagIcon)
    local b = New("ItemButton", name, true)
    local s = S[b]
    s.id, s.bagIcon = id, bagIcon
    s.normal, s.pushed, s.highlight = New("Texture", name .. "Normal", true), New("Texture", name .. "Pushed", true),
        New("Texture", name .. "Highlight", true)
    Put(b, "icon", New("Texture", name .. "Icon", true))
    Put(b, "SlotHighlightTexture", New("Texture", name .. "SlotHighlight", true))
    Put(b, "IconBorder", New("Texture", name .. "IconBorder", true))
    Put(b, "CircleMask", New("Texture", name .. "CircleMask", true))
    Put(b, "Count", New("FontString", name .. "Count", true))
    Put(b, "UpdateTextures", UpdateTextures)
    Put(b, "SetItemButtonTexture", function(self, texture) self.icon:SetTexture(texture); self:UpdateTextures() end)
    Put(b, "SetItemButtonTextureVertexColor", function(self, r, g, b2) self.icon:SetVertexColor(r, g, b2) end)
    Put(b, "SetItemButtonQuality", function(self) self:UpdateTextures() end)
    _G[name] = b
    return b
end
local backpack = BagButton("MainMenuBarBackpackButton", 0, "Interface\\Icons\\ui-hud-actionbar-bag")
Put(backpack, "FreeSlots", New("FontString", "MainMenuBarBackpackButtonFreeSlots", true))
local slots = {}
for i = 0, 3 do slots[i] = BagButton("CharacterBag" .. i .. "Slot", 20 + i) end
local reagent = BagButton("CharacterReagentBag0Slot", 24)
local keyring = BagButton("KeyRingButton", -2, "Interface\\ICONS\\ui-hud-actionbar-keyring")
local all = { backpack, slots[0], slots[1], slots[2], slots[3], reagent, keyring }
-- Each bag's own bright icon (the HD icon pack's teal, yellow-green and pink).
inventory[20], inventory[21], inventory[22] = "Bag_Teal", "Bag_YellowGreen", "Bag_Pink"
-- A bag in a container window, not on the bar: never touched.
local item = New("ItemButton", "ContainerFrame1Item1", true)
Put(item, "icon", New("Texture", "ContainerFrame1Item1Icon", true))

-- At login the game fills every slot; a button skin addon then skins the
-- bar, recolouring the open-bag line light grey after each texture update.
local SKIN = { .85, .87, .9, 1 }
for _, b in ipairs(all) do
    if S[b].bagIcon then b:UpdateTextures() else PaperDollItemSlotButton_Update(b) end
end
local function Skin(b) b.SlotHighlightTexture:SetVertexColor(SKIN[1], SKIN[2], SKIN[3], SKIN[4]) end
for _, b in ipairs(all) do hooksecurefunc(b, "UpdateTextures", Skin); Skin(b) end
hooks = 0

-- EraUI ----------------------------------------------------------------------
local E = { modules = {}, Classic = {}, settings = { enabled = true, darkMode = true, darkMenuBar = true } }
function E:GetSetting(key) return self.settings[key] end
local ns = E.Classic
-- Classic/Textures.lua: the file is set (which, as on the game, may reset its colour).
ns.SetTex = function(texture, key) texture:SetTexture(key); S[texture].key = key; return true end
ns.SetButtonTex = Noop
assert(loadfile("Classic/BarSkins.lua"))("EraUI", E)
local watch
for _, f in ipairs(frames) do if S[f].events and S[f].events.PLAYER_ENTERING_WORLD then watch = f end end
local function World() S[watch].scripts.OnEvent(watch, "PLAYER_ENTERING_WORLD") end

local function C(texture) local c = S[texture].colour; return string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]) end
local GREY, OPEN, WHITE, SKINNED = "0.60,0.60,0.60", "0.00,0.00,0.00", "1.00,1.00,1.00", "0.85,0.87,0.90"
local function Look(b) return C(b.icon) .. (S[b.icon].grey and " grey" or " colour") .. " | " .. C(b.SlotHighlightTexture) end
local DARK, PLAIN = GREY .. " grey | " .. OPEN, WHITE .. " colour | " .. SKINNED
local function Every(want, label)
    for _, b in ipairs(all) do equal(Look(b), want, label .. ": " .. S[b].name) end
end
local function Colours()
    local n = 0
    for _, b in ipairs(all) do n = n + S[b.icon].colours + S[b.SlotHighlightTexture].colours end
    return n
end

-- Off by default: entering the world hooks and paints nothing.
equal(watch ~= nil, true, "waits for the world")
local before = Colours()
World()
equal(hooks .. " " .. (Colours() - before), "0 0", "off: nothing hooked, nothing painted")
Every(PLAIN, "off")
-- The bags' own updates while off: still nothing of EraUI's.
PaperDollItemSlotButton_Update(slots[0]); backpack:UpdateTextures()
Every(PLAIN, "off, after the game's updates")

-- The tick on (Settings calls the refresh): every icon grey and darker, all
-- alike, every open-bag line dark, the skin's colour kept for later.
E.settings.darkBagButtons = true
ns.RefreshDarkBagButtons()
Every(DARK, "on")
equal(hooks, 9, "hooked once: each of the 7 buttons' texture update and the game's two icon calls")
equal(S[slots[0].icon].file .. " " .. S[backpack.icon].file, "Bag_Teal Interface\\Icons\\ui-hud-actionbar-bag", "the icons themselves are the game's")

-- The game's own updates, each ending dark.
PaperDollItemSlotButton_Update(slots[0])
equal(Look(slots[0]), DARK, "a bag slot's update (its colour put back, art refreshed, lock checked): still dark")
backpack:UpdateTextures()
equal(Look(backpack), DARK, "the backpack's art refreshed (its icon set again): still dark")
SetItemButtonQuality(slots[1], 3)
equal(Look(slots[1]), DARK, "a quality change refreshes the art: still dark")
-- A bag being moved: the game greys it, then gives its colour back: grey and dark throughout.
locked[21] = true; SetItemButtonDesaturated(slots[1], true)
equal(Look(slots[1]), DARK, "a bag picked up: grey and dark")
locked[21] = nil; SetItemButtonDesaturated(slots[1], false)
equal(Look(slots[1]), DARK, "put down: still grey and dark")
-- A new bag in an empty slot: the same.
inventory[23] = "Bag_Orange"; PaperDollItemSlotButton_Update(slots[3])
equal(Look(slots[3]) .. " " .. S[slots[3].icon].file, DARK .. " Bag_Orange", "a new bag: its icon, grey and dark")
-- Every pass and event again changes nothing, and adds no hook.
ns.RefreshDarkBagButtons(); World(); ns.RefreshDarkBagButtons()
Every(DARK, "again")
equal(hooks, 9, "no hook added by later passes")

-- A skin hooked after EraUI (skinned again later) still loses to a slot's
-- update: the update's last calls are the ones EraUI follows.
hooksecurefunc(slots[2], "UpdateTextures", Skin); hooks = hooks - 1
PaperDollItemSlotButton_Update(slots[2])
equal(Look(slots[2]), DARK, "a skin hooked after EraUI: the slot's update still ends dark")

-- Other item buttons are never touched, by the game's calls or the tick.
SetItemButtonDesaturated(item, true); SetItemButtonTextureVertexColor(item, .5, .5, .5)
equal(C(item.icon) .. " " .. tostring(S[item.icon].grey), "0.50,0.50,0.50 true", "a container item keeps what the game gave it")

-- A broken item's red (the game's colour for broken or unusable gear): kept
-- under the grey and given back with the tick off.
broken[22] = true; PaperDollItemSlotButton_Update(slots[2])
equal(Look(slots[2]), DARK, "red from the game: dark while on")

-- A secret colour (Forever hides some values in a fight) is never compared or
-- kept: the line is painted dark, its last own colour stays the one given back.
S[reagent.SlotHighlightTexture].secretColour = {}
secret[S[reagent.SlotHighlightTexture].secretColour] = true
reagent:UpdateTextures()
S[reagent.SlotHighlightTexture].secretColour = nil
equal(Look(reagent), DARK, "a secret colour: painted dark all the same")

-- Off again: each texture back to its own colour, out of grey, then left alone.
E.settings.darkBagButtons = false
ns.RefreshDarkBagButtons()
for _, b in ipairs(all) do
    local want = b == slots[2] and "0.90,0.00,0.00 colour | " .. SKINNED or PLAIN
    equal(Look(b), want, "off again: " .. S[b].name)
end
broken[22] = nil; PaperDollItemSlotButton_Update(slots[2])
equal(Look(slots[2]), PLAIN, "off: repaired, the game's white")
before = Colours()
local beforeHooks = hooks
PaperDollItemSlotButton_Update(slots[0]); backpack:UpdateTextures(); ns.RefreshDarkBagButtons(); World()
equal(Look(slots[0]) .. " / " .. Look(backpack), PLAIN .. " / " .. PLAIN, "off: the game's updates show the game's look")
-- The game's and the skin's own calls only: the slot's icon colour once, the
-- skin's line after each of the three art refreshes.
equal(Colours() - before, 4, "off: EraUI paints nothing more")
equal(hooks, beforeHooks, "and hooks nothing more")

-- Dark Mode off (after a reload) or EraUI off: the tick waits, nothing dark.
E.settings.darkBagButtons, E.settings.darkMode = true, false
ns.RefreshDarkBagButtons()
Every(PLAIN, "Dark Mode off")
E.settings.darkMode, E.settings.enabled = true, false
ns.RefreshDarkBagButtons()
Every(PLAIN, "EraUI off")
E.settings.enabled = true
ns.RefreshDarkBagButtons()
Every(DARK, "both back on")

-- EraUI's own Classic bag art (the Classic action bar): an open bag shows the
-- slot pressed in, in the dark grey, instead of the additive glow no colour
-- can darken; the icons grey over the Classic art. Off, the glow comes back.
for _, b in ipairs({ backpack, slots[0], slots[1], slots[2], slots[3] }) do ns.SkinBagButton(b, 30, b == backpack) end
local slot = slots[0].SlotHighlightTexture
equal(S[slot].key .. " " .. S[slot].blend .. " " .. C(slot), "slotPushed BLEND " .. OPEN, "Classic art, on: an open bag pressed in, dark")
equal(Look(slots[0]) .. " " .. S[backpack.icon].key, DARK .. " backpackIcon", "Classic art, on: the icons grey and dark over it")
equal(Look(slots[3]) .. " " .. S[slots[3].icon].alpha, DARK .. " 1", "Classic art: a filled slot keeps its full alpha")
inventory[23] = nil; PaperDollItemSlotButton_Update(slots[3])
equal(Look(slots[3]) .. " " .. S[slots[3].icon].alpha, DARK .. " 0.5", "Classic art: an empty slot keeps its faded look, grey and dark")
E.settings.darkBagButtons = false
ns.RefreshDarkBagButtons()
equal(S[slot].key .. " " .. S[slot].blend .. " " .. C(slot), "checked ADD " .. WHITE, "Classic art, off: the glow back, white")
equal(Look(slots[1]), WHITE .. " colour | " .. WHITE, "Classic art, off: the icons in their own colours")
E.settings.darkBagButtons = true
ns.RefreshDarkBagButtons()
equal(S[slot].key .. " " .. S[slot].blend .. " " .. C(slot), "slotPushed BLEND " .. OPEN, "Classic art, on again")
-- Leaving the Classic art: the game's art back, still dark.
ns.UnskinBagButton(slots[0])
equal(Look(slots[0]), DARK, "back to the game's art: still dark")

-- Buttons the game doesn't have are skipped without errors.
_G.KeyRingButton, _G.CharacterReagentBag0Slot = nil, nil
ns.RefreshDarkBagButtons(); World()

equal(#writes, 0, "no key written on the game's frames (" .. table.concat(writes, ", ") .. ")")

print("Dark bag button checks passed: " .. checks .. " assertions.")
