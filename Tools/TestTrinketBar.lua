-- The Trinket Bar (Modules/TrinketKit.lua, TrinketList.lua, TrinketBar.lua,
-- TrinketMenu.lua, TrinketSets.lua, TrinketSetList.lua; /era > Action Bars >
-- Trinkets, the rows at the end)
-- against a mock of the game. Off by default: no bar, no button, no events.
-- On: EraUI's own bar of plain buttons, each with the worn icon, a cooldown
-- sweep, the time left and the ready glow; an empty slot keeps the paper
-- doll's art. Nothing on the bar uses a trinket, so no slot is a secure
-- frame and no attribute is written on one; the mock still throws on a
-- secure frame touched in a fight, and a secure button made here proves it,
-- so the bar's own freedom to lay itself out mid-fight is checked, not
-- assumed. Show Both Slots, Show Your Rings, Ready Glow, Time Left on Icon,
-- Two Rows, Up and Down (all four shapes), Icon Size and Open List (Hover or
-- Click). A left-click opens the grid of what you carry for that slot, Icons
-- per Row wide and as many rows down as it takes with no cap, each tile with
-- its own icon, its bag cooldown and the time left; pointing at one names it
-- and says what its use does in EraUI's own box, and a click puts it on. In a
-- fight the game refuses a swap, so every tile fades and a click queues that
-- trinket for the slot instead (Queue in a Fight), one to a slot, with the
-- Queued strip on the slot and on its tile until the fight ends and it goes
-- on, found again in whatever bag slot it sits in by then; clicking the queued
-- one again takes it back, and with that option off a fight refuses the swap
-- as it always did. A right-click
-- opens the quick menu of the same options,
-- which closes on a click elsewhere or on Escape and stays shut in a fight,
-- as the drag does. Secrets (Forever's cooldowns in a fight) are tables that
-- refuse to be compared, added up or joined, as in the game: they go to the
-- sweep as they are. Drag, the saved place and Reset. Then your sets
-- (Modules/TrinketSets.lua, TrinketSetList.lua): saved from what you wear in
-- the slots you can see, named, renamed, saved over and deleted, as many as
-- you want, this character's own and checked as they are read; loaded out of
-- a fight they come out of your bags by item ID, in one a set is kept and
-- goes on the moment the fight ends, said once; the same two trinkets the
-- other way round are already on you; an item that has gone is named and the
-- rest of the set still loads. Then the ten set keys
-- (Modules/TrinketKeys.lua): ten plain buttons the game's Key Bindings menu
-- clicks, made whether the bar is on or off, each entry reading with the name
-- of the set it puts on, a set stepped along the ten and round through none,
-- no two sets ever on one key, a key's down and up clicks counting as one
-- press, and a press in a fight keeping the set for the fight's end. Then the
-- cooldown alerts (Modules/TrinketAlerts.lua), all four off to start with: a
-- short line in the middle of the screen as a trinket on the bar comes off
-- cooldown, which comes from the slot's own Cooldown widget and so works in a
-- fight with nothing read or compared, but is never said of a trinket that was
-- never on cooldown nor of one whose cooldown began in the fight; the same
-- words in chat and a sound with them where those are ticked; one line for one
-- trinket however many things see it; a line that fades itself and leaves
-- nothing ticking; and the thirty-second warning, one timer worked out from
-- plain numbers alone, dropped when the trinket comes off and silent when
-- another one is in the slot by the time it is due. No key
-- is written on the game's frames, no binding is ever set, and the game's
-- tooltip and hooks are never used.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack

-- Secrets ------------------------------------------------------------------------
local secretKind = setmetatable({}, { __mode = "k" })
local function Refuse(what) return function() error("a secret was " .. what, 2) end end
local SecretMeta = {
    __index = Refuse("indexed"), __newindex = Refuse("written to"), __concat = Refuse("joined"), __len = Refuse("measured"),
    __eq = Refuse("compared"), __lt = Refuse("compared"), __le = Refuse("compared"), __call = Refuse("called"),
    __add = Refuse("added up"), __sub = Refuse("added up"), __mul = Refuse("added up"), __div = Refuse("added up"),
    __mod = Refuse("added up"), __pow = Refuse("added up"), __unm = Refuse("added up"),
    __tostring = function() return "<secret>" end,
}
local function Secret(kind) local s = setmetatable({}, SecretMeta); secretKind[s] = kind; return s end
issecretvalue = function(v) return v ~= nil and secretKind[v] ~= nil end
local realType = type
type = function(v) if v ~= nil and secretKind[v] then return secretKind[v] end return realType(v) end

-- Mock widgets ------------------------------------------------------------------
-- Each object's state lives beside it (S), so anything written on a frame by
-- the module shows as a plain key, and the game's own frames are never
-- touched. A frame made from a secure template throws on the mutations the
-- game protects while a fight is on.
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local all = {}
local combat = false
local function New(kind, name, parent, template)
    local o = {}
    S[o] = { kind = kind, name = name, parent = parent, template = template, shown = true, points = {}, scripts = {},
        hooks = {}, events = {}, attributes = {}, count = {}, strata = "MEDIUM", text = "", alpha = 1,
        secure = template ~= nil and template:find("SecureActionButton", 1, true) ~= nil }
    all[#all + 1] = o
    return setmetatable(o, { __index = function(_, key)
        local method = Proto[key]
        if method then return method end
        if realType(key) == "string" and key:match("^%u") then error("the mock has no " .. kind .. ":" .. key, 2) end
    end })
end
local function Count(o, what) S[o].count[what] = (S[o].count[what] or 0) + 1 end
-- The game refuses these on a protected frame while a fight is on.
local function Guard(o, what)
    if combat and S[o].secure then error("a secure frame was " .. what .. " in a fight", 2) end
end
function Proto:SetSize(w, h) Guard(self, "resized"); S[self].w, S[self].h = w, h end
function Proto:SetWidth(w) Guard(self, "resized"); S[self].w = w end
function Proto:SetHeight(h) Guard(self, "resized"); S[self].h = h end
function Proto:GetWidth() return S[self].w end
function Proto:GetHeight() return S[self].h end
function Proto:GetLeft() return S[self].left end
function Proto:GetTop() return S[self].top end
function Proto:GetBottom() return S[self].bottom end
function Proto:IsShown() return S[self].shown end
function Proto:Show() Guard(self, "shown"); S[self].shown = true; Count(self, "shown") end
function Proto:Hide()
    Guard(self, "hidden")
    S[self].shown = false
    Count(self, "hidden")
    if S[self].scripts.OnHide then S[self].scripts.OnHide(self) end
end
function Proto:SetShown(v) if v then self:Show() else self:Hide() end end
function Proto:SetPoint(...) Guard(self, "moved"); table.insert(S[self].points, { ... }) end
function Proto:ClearAllPoints() Guard(self, "moved"); S[self].points = {} end
function Proto:SetAllPoints(to) S[self].points = { { "ALL", to } } end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
function Proto:HookScript(name, fn) S[self].hooks[name] = S[self].hooks[name] or {}; table.insert(S[self].hooks[name], fn) end
function Proto:RegisterEvent(event) S[self].events[event] = true end
function Proto:UnregisterAllEvents() S[self].events = {}; Count(self, "unregister") end
function Proto:SetFrameStrata(v) S[self].strata = v end
function Proto:SetClampedToScreen(v) S[self].clamped = v end
function Proto:SetMovable(v) S[self].movable = v end
function Proto:SetDontSavePosition(v) S[self].dontSave = v end
function Proto:EnableMouse(v) Guard(self, "given or refused the mouse"); S[self].mouse = v and true or false end
function Proto:RegisterForDrag(...) S[self].drag = table.concat({ ... }, ",") end
-- The key catcher behind binding a set's key in the panel.
function Proto:EnableKeyboard(v) S[self].keyboard = v and true or false end
function Proto:SetPropagateKeyboardInput(v) S[self].propagate = v and true or false end
function Proto:RegisterForClicks(...) Guard(self, "told which clicks to take"); S[self].clicks = table.concat({ ... }, ",") end
function Proto:SetAttribute(key, value) Guard(self, "written to"); S[self].attributes[key] = value end
function Proto:GetAttribute(key) return S[self].attributes[key] end
function Proto:IsMouseOver() return S[self].over == true end
function Proto:Click(mouse)
    local fn = S[self].scripts.OnClick
    if fn then fn(self, mouse or "LeftButton") end
end
-- As in the client: a frame you drag is marked moved by you unless told not to save it.
function Proto:StartMoving() Count(self, "moving"); S[self].userPlaced = true end
function Proto:StopMovingOrSizing() Count(self, "stopped") end
function Proto:SetUserPlaced(v) S[self].userPlaced = v end
function Proto:CreateTexture(_, layer) local t = New("Texture", nil, self); S[t].layer = layer; return t end
function Proto:CreateFontString(_, layer) local f = New("FontString", nil, self); S[f].layer = layer; return f end
function Proto:SetTexture(t) S[self].texture = t end
function Proto:SetVertexColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:SetColorTexture(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:SetTexCoord() end
function Proto:SetBlendMode(v) S[self].blend = v end
function Proto:SetDesaturated(v) S[self].grey = v and true or false end
function Proto:SetAlpha(v) S[self].alpha = v end
function Proto:GetAlpha() return S[self].alpha end
function Proto:SetFont(file, size) S[self].font, S[self].size = file, size; return true end
function Proto:SetShadowColor() end
function Proto:SetShadowOffset() end
function Proto:SetWordWrap(v) S[self].wrap = v end
function Proto:SetJustifyH(v) S[self].justify = v end
function Proto:SetText(text) S[self].text = text end
function Proto:GetText() return S[self].text end
function Proto:SetTextColor(r, g, b) S[self].textColour = { r, g, b } end
-- The cooldown widget takes the game's numbers as they are, secret or not.
function Proto:SetCooldown(start, length) S[self].sweep = { start, length }; Count(self, "sweep") end
function Proto:Clear() S[self].sweep = nil; Count(self, "clear") end
function Proto:SetDrawEdge(v) S[self].edge = v end
function Proto:SetDrawBling(v) S[self].bling = v end
function Proto:SetHideCountdownNumbers(v) S[self].plain = v end
function Proto:SetSwipeColor(r, g, b, a) S[self].swipeColour = { r, g, b, a } end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:GetFrameLevel() return S[self].level or 1 end
-- The slider in the quick menu (/era's own shape, Core/SettingsRows.lua).
function Proto:SetBackdrop(b) S[self].backdrop = b end
function Proto:SetBackdropColor(r, g, b, a) S[self].backColour = { r, g, b, a } end
function Proto:SetBackdropBorderColor(r, g, b, a) S[self].borderColour = { r, g, b, a } end
function Proto:SetOrientation(v) S[self].orientation = v end
function Proto:SetMinMaxValues(low, high) S[self].range = { low, high } end
function Proto:SetValueStep(v) S[self].step = v end
function Proto:SetObeyStepOnDrag(v) S[self].obey = v end
function Proto:SetThumbTexture(t) S[self].thumbArt = t end
function Proto:GetThumbTexture()
    if not S[self].thumb then S[self].thumb = New("Texture", nil, self) end
    return S[self].thumb
end
-- As in the game: a slider told a value tells its own OnValueChanged.
function Proto:SetValue(v)
    S[self].value = v
    local fn = S[self].scripts.OnValueChanged
    if fn then fn(self, v) end
end
function Proto:GetValue() return S[self].value end

-- The game -------------------------------------------------------------------
InCombatLockdown = function() return combat end
local now = 1000
GetTime = function() return now end
-- The game's own timers: what was asked for, and how long it asked to wait
-- (the cooldown alerts' thirty-second warning asks for one moment, so the
-- wait itself is read as well as the work).
local timers, delays = {}, {}
C_Timer = { After = function(seconds, fn) timers[#timers + 1] = fn; delays[#delays + 1] = seconds end }
local function Flush()
    for _ = 1, 20 do
        if #timers == 0 then return end
        local due = timers; timers = {}
        for _, fn in ipairs(due) do fn() end
    end
    error("timers did not settle")
end
CreateFrame = function(kind, name, parent, template)
    local f = New(kind, name, parent, template)
    if name then _G[name] = f end
    return f
end
UIParent = New("Frame", "UIParent")
S[UIParent].h, S[UIParent].w = 768, 1024
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
NUM_BAG_SLOTS = 4
-- The game's own Escape list: a window's name goes in it once, and the game
-- hides that window on Escape.
UISpecialFrames = {}
-- The game's own sound kits, and what was played (Play A Sound).
SOUNDKIT = { IG_MAINMENU_OPTION_CHECKBOX_ON = 856, U_CHAT_SCROLL_BUTTON = 1115 }
local sounds = {}
PlaySound = function(kit) sounds[#sounds + 1] = kit end
-- The game's tooltip, hooks and bindings: never used.
local forbidden = {}
local function Forbid(name) return function() forbidden[#forbidden + 1] = name end end
GameTooltip = setmetatable({}, { __index = function(_, key) forbidden[#forbidden + 1] = "GameTooltip." .. tostring(key); return function() end end })
hooksecurefunc, SetOverrideBinding = Forbid("hooksecurefunc"), Forbid("SetOverrideBinding")
-- SetBinding is allowed from 27 Nov 2026 and watched instead of forbidden, so
-- a set's key can be bound in the panel rather than hunted down in the game's
-- own menu (Squirt asked for it; the classic talents offer already sets one
-- the same way). SetOverrideBinding stays forbidden: that one is what causes
-- secret-compare errors on this client, and it is a different call.
local bindings, bound = {}, {}
-- The modifiers the key catcher reads, as the game gives them.
ctrl, shift, alt = false, false, false
IsControlKeyDown = function() return ctrl end
IsShiftKeyDown = function() return shift end
IsAltKeyDown = function() return alt end
SetBinding = function(key, action)
    if type(key) ~= "string" or key == "" then return false end
    bindings[#bindings + 1] = key .. (action and (" -> " .. action) or " (cleared)")
    if action then bound[action] = key else
        for a, k in pairs(bound) do if k == key then bound[a] = nil end end
    end
    return true
end
local saved = 0
SaveBindings = function() saved = saved + 1 end
GetCurrentBindingSet = function() return 1 end

-- What you wear, what you carry and what the client knows about each item.
-- use: the name of the item's own on-use spell, as GetItemSpell gives it;
-- an item without one (the Amulet) has none, and its hover box is one line.
local ITEMS = {
    [4500] = { loc = "INVTYPE_TRINKET", icon = "art.sunstone", name = "Sunstone", use = "Sunlight" },
    [4501] = { loc = "INVTYPE_TRINKET", icon = "art.bauble", name = "Bauble", use = "Pop It" },
    [4502] = { loc = "INVTYPE_TRINKET", icon = "art.amulet", name = "Amulet" },
    [4700] = { loc = "INVTYPE_FINGER", icon = "art.signet", name = "Signet" },
    [4701] = { loc = "INVTYPE_FINGER", icon = "art.band", name = "Band" },
    [9000] = { loc = "INVTYPE_WEAPON", icon = "art.axe", name = "Axe" },
}
-- Sixteen more trinkets, Stone A to Stone P, for a bagful the old list of
-- fourteen lines could not have shown.
local MANY = {}
for i = 1, 16 do
    local id = 4600 + i
    ITEMS[id] = { loc = "INVTYPE_TRINKET", icon = "art.stone" .. i, name = "Stone " .. string.char(64 + i) }
    MANY[i] = id
end
local game
local function Reset()
    game = {
        worn = { [13] = 4500, [11] = 4700 },
        cd = {},
        bagCd = {},
        bags = { [0] = { 4501, 9000 }, [1] = { 4502, 4701 }, [2] = {}, [3] = {}, [4] = {} },
        picked = {}, equipped = {}, cleared = 0, secret = false,
    }
end
Reset()
GetInventoryItemID = function(unit, slot)
    assert(unit == "player", "your own slots only")
    return game.worn[slot]
end
GetInventoryItemTexture = function(unit, slot)
    local id = game.worn[slot]
    return id and ITEMS[id].icon or nil
end
GetInventoryItemCooldown = function(unit, slot)
    local sweep = game.cd[slot]
    if not sweep then return 0, 0, 1 end
    if game.secret then return Secret("number"), Secret("number"), 1 end
    return sweep[1], sweep[2], 1
end
C_Container = {
    GetContainerNumSlots = function(bag) return game.bags[bag] and #game.bags[bag] or 0 end,
    GetContainerItemID = function(bag, slot) return game.bags[bag] and game.bags[bag][slot] or nil end,
    GetContainerItemLink = function(bag, slot)
        local id = game.bags[bag] and game.bags[bag][slot]
        return id and ("|cffffffff|Hitem:" .. id .. "|h[" .. ITEMS[id].name .. "]|h|r") or nil
    end,
    PickupContainerItem = function(bag, slot) game.picked[#game.picked + 1] = bag .. ":" .. slot end,
    -- A bag item's cooldown, secret in a fight exactly as a worn slot's is.
    GetContainerItemCooldown = function(bag, slot)
        local sweep = game.bagCd[bag] and game.bagCd[bag][slot]
        if not sweep then return 0, 0, 1 end
        if game.secret then return Secret("number"), Secret("number"), 1 end
        return sweep[1], sweep[2], 1
    end,
}
C_Item = {
    GetItemInfoInstant = function(id)
        local item = ITEMS[id]
        if not item then return nil end
        return id, "Armor", "Miscellaneous", item.loc, item.icon
    end,
    GetItemInfo = function(id) return ITEMS[id] and ITEMS[id].name or nil end,
    GetItemSpell = function(id)
        local item = ITEMS[id]
        if not (item and item.use) then return nil end
        return item.use, 1234
    end,
}
EquipCursorItem = function(slot) game.equipped[#game.equipped + 1] = slot end
ClearCursor = function() game.cleared = game.cleared + 1 end

-- EraUI: the real defaults (Core/Init.lua), its settings and a stand-in for /era.
local real = {}
local era = _G.EraUI
assert(loadfile("Core/Init.lua"))("EraUI", real)
_G.EraUI = era
local settings, saves, said = {}, 0, nil
for key, value in pairs(real.settingDefaults) do settings[key] = value end
local E = { modules = {}, Classic = { DarkGrey = function() return .42, .44, .48 end } }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return settings[key] end
function E:GetSavedSetting(key) return settings[key] end
function E:SetSetting(key, value) settings[key] = value end
function E:SaveSettings() saves = saves + 1 end
function E:Status(text) said = text end
-- EraUI's own hover box (Look/Base.lua): what a grid tile shows as you point
-- at it, instead of the game's tooltip, which Forever taints as soon as an
-- addon drives it.
local tip
E.Look = {
    ShowTip = function(owner, side, rows)
        local words = {}
        for _, row in ipairs(rows) do words[#words + 1] = row[1] end
        tip = { owner = owner, side = side, text = table.concat(words, " / ") }
    end,
    HideTip = function(owner) if tip and (owner == nil or tip.owner == owner) then tip = nil end end,
}
-- The names the game's Key Bindings menu shows for the ten trinket set keys
-- are Core/Init.lua's own globals, so the real ones are used here. The key a
-- player has set on an entry is read and never written: EraUI sets none, and
E.SetTrinketSetBindingName = real.SetTrinketSetBindingName
GetBindingKey = function(action) return bound[action] end
GetBindingText = function(key) return type(key) == "string" and (key:gsub("SHIFT%-", "Shift ")) or nil end
local mark = #all
assert(loadfile("Modules/TrinketKit.lua"))("EraUI", E)
assert(loadfile("Modules/TrinketList.lua"))("EraUI", E)
assert(loadfile("Modules/TrinketBar.lua"))("EraUI", E)
assert(loadfile("Modules/TrinketMenu.lua"))("EraUI", E)
assert(loadfile("Modules/TrinketSets.lua"))("EraUI", E)
assert(loadfile("Modules/TrinketKeys.lua"))("EraUI", E)
assert(loadfile("Modules/TrinketAlerts.lua"))("EraUI", E)
local Module, Kit, Listing, Quick = E.modules.TrinketBar, E.TrinketKit, E.TrinketList, E.TrinketMenu
local Keys, Saved, Alerts = E.TrinketKeys, E.TrinketSets, E.TrinketAlerts
-- A set key: the name the game's menu shows for it, and the button it clicks.
local function Menu(slot) return _G["BINDING_NAME_CLICK EraUITrinketSetButton" .. slot .. ":LeftButton"] end
local function KeyButton(slot) return _G["EraUITrinketSetButton" .. slot] end

-- Helpers ------------------------------------------------------------------------
local function Driver()
    for i = mark + 1, #all do
        local f = all[i]
        if S[f].kind == "Frame" and S[f].scripts.OnEvent and S[f].parent == nil then return f end
    end
end
local function Fire(event)
    local f = Driver()
    assert(S[f].events[event], event .. " registered")
    S[f].scripts.OnEvent(f, event)
end
-- The frame that waits for a fight to end: the sets' own one, which the
-- queued trinkets wait in as well, and never the bar's.
local function Waiter()
    local driver = Driver()
    for i = mark + 1, #all do
        local f = all[i]
        if f ~= driver and S[f].kind == "Frame" and S[f].scripts.OnEvent and S[f].parent == nil then return f end
    end
end
local function Turn(key, value) settings[key] = value; Module:Refresh(); Flush() end
local function Tick(seconds)
    local bar = _G.EraUITrinketBar
    now = now + seconds
    S[bar].scripts.OnUpdate(bar, seconds)
end
local function Slot(number) return _G["EraUITrinketSlot" .. number] end
local function Point(f)
    local p = S[f].points[1]
    if not p then return "none" end
    local to = p[2] == UIParent and "UIParent" or (S[p[2]] and S[p[2]].name or tostring(p[2]))
    local function N(v) return (string.format("%.4f", v or 0):gsub("%.?0+$", "")) end
    return table.concat({ p[1], to, p[3], N(p[4]), N(p[5]) }, " ")
end
local function Attrs(number)
    local button = Slot(number)
    return tostring(button:GetAttribute("type1")) .. " " .. tostring(button:GetAttribute("item1"))
end
local function Visible()
    local out = {}
    for _, info in ipairs(Kit.SLOTS) do
        local button = Slot(info.slot)
        if button and S[button].shown then out[#out + 1] = tostring(info.slot) end
    end
    return table.concat(out, ",")
end
-- The grid's tiles on show, in order, by the name of the item on each
-- (greyed ones in brackets).
local function Lines()
    local out = {}
    for _, row in ipairs(Listing.rows) do
        if S[row].shown then
            local name = row.entry and row.entry.name or "?"
            out[#out + 1] = row.greyed and ("(" .. name .. ")") or name
        end
    end
    return table.concat(out, ",")
end
-- The grid's own size, how many tiles are on it and where each row of them
-- starts, so the shape is read whole rather than tile by tile.
local function Spread()
    local list = _G.EraUITrinketList
    local out, seen, count = {}, {}, 0
    for _, tile in ipairs(Listing.rows) do
        if S[tile].shown then
            count = count + 1
            local p = S[tile].points[1]
            if not seen[p[5]] then seen[p[5]] = true; out[#out + 1] = p[4] .. "," .. p[5] end
        end
    end
    return S[list].w .. "x" .. S[list].h .. " " .. count .. " tiles, rows at " .. table.concat(out, " ")
end
-- The tile the named item is on.
local function TileOf(name)
    for _, tile in ipairs(Listing.rows) do
        if S[tile].shown and tile.entry and tile.entry.name == name then return tile end
    end
end
-- The grid's own tick, which runs only while it is open (a hidden frame's
-- OnUpdate never runs in the game either).
local function Flick(seconds)
    local list = _G.EraUITrinketList
    now = now + seconds
    S[list].scripts.OnUpdate(list, seconds)
end
-- The grid's foot: its line, and the second line under it in a fight saying
-- what a click does there.
local function Foot()
    local list = _G.EraUITrinketList
    local out = {}
    for _, f in ipairs(all) do
        if S[f].parent == list and S[f].kind == "FontString" and S[f].size == 10 and S[f].shown then
            out[#out + 1] = S[f].text
        end
    end
    return table.concat(out, " / ")
end
-- The Queued strip across the top of a slot or a grid tile: the word on it
-- while it shows, nothing while it does not.
local function Queued(f)
    local strip = f.mark
    if not strip then return "no strip" end
    if not S[strip.strip].shown then return "" end
    return S[strip.word].shown and S[strip.word].text or "strip with no word"
end
-- The quick menu's own rows, top to bottom: a tick row as "+Label" while it
-- is on and "-Label" while it is off, an action row by its words alone.
local function MenuRows()
    local menu = _G.EraUITrinketMenu
    local out = {}
    for _, f in ipairs(all) do
        if S[f].parent == menu and S[f].kind == "Button" and f.label then
            local text = S[f.label].text
            if f.mark then text = (S[f.mark].shown and "+" or "-") .. text end
            out[#out + 1] = text
        end
    end
    return table.concat(out, ",")
end
local function MenuRow(label)
    local menu = _G.EraUITrinketMenu
    for _, f in ipairs(all) do
        if S[f].parent == menu and S[f].kind == "Button" and f.label and S[f.label].text == label then return f end
    end
end
-- The screen-wide button under the menu: a click on it is a click elsewhere.
local function Catcher()
    for i = mark + 1, #all do
        local f = all[i]
        -- The catcher has no name of its own; the set keys' buttons do.
        if S[f].kind == "Button" and S[f].parent == UIParent and S[f].name == nil and S[f].scripts.OnClick then return f end
    end
end
local function MenuSlider()
    local menu = _G.EraUITrinketMenu
    for _, f in ipairs(all) do
        if S[f].parent == menu and S[f].kind == "Slider" then return f end
    end
end
-- The cooldown alerts (Modules/TrinketAlerts.lua): the line in the middle of
-- the screen, what it says, and whether it is still up.
local function Alert() return _G.EraUITrinketAlert end
local function Said()
    local line = Alert()
    if not line then return "no line" end
    for _, f in ipairs(all) do
        if S[f].parent == line and S[f].kind == "FontString" then
            return (S[line].shown and "" or "(gone) ") .. S[f].text
        end
    end
    return "no words"
end
-- The line's box, which the bar paints with its own (Dark Mode).
local function LineFill()
    for _, f in ipairs(all) do
        if S[f].parent == Alert() and S[f].kind == "Texture" and S[f].layer == "BACKGROUND" then
            return table.concat(S[f].colour, ",")
        end
    end
    return "no fill"
end
-- Its own fade, which runs only while a line is up: what it looks like after
-- that long.
local function Fade(seconds)
    local line = Alert()
    local fn = line and S[line].scripts.OnUpdate
    if not fn then return "no tick" end
    now = now + seconds
    fn(line, seconds)
    return tostring(S[line].shown) .. " " .. string.format("%.2f", S[line].alpha)
end
-- The game's own Cooldown widget saying its sweep has run out, which is the
-- one honest word for "ready" in a fight, where the numbers are secret.
local function Done(button)
    local fn = S[button.cd].scripts.OnCooldownDone
    assert(fn, "a slot's sweep says when it has run out")
    fn(button.cd)
end
-- What the module asked the game to wait, in order, since the last look.
local function Waits()
    local out = {}
    for index, seconds in ipairs(delays) do
        out[index] = realType(seconds) == "number" and string.format("%g", seconds) or tostring(seconds)
    end
    delays = {}
    return table.concat(out, ",")
end
local function Played()
    local out = table.concat(sounds, ",")
    for at = #sounds, 1, -1 do sounds[at] = nil end
    return out
end
local function MenuSizeText()
    local menu = _G.EraUITrinketMenu
    for _, f in ipairs(all) do
        if S[f].parent == menu and S[f].kind == "FontString" and S[f].size == 11 and S[f].text:find("^Icon Size") then return f end
    end
end

---------------------------------------------------------------------------
-- Off by default: nothing made, nothing watched
---------------------------------------------------------------------------
equal(settings.trinketBar, false, "off by default")
equal(tostring(settings.trinketBarBoth) .. " " .. tostring(settings.trinketBarRings) .. " " .. tostring(settings.trinketBarGlow)
    .. " " .. tostring(settings.trinketBarTwoRows) .. " " .. settings.trinketBarOpen .. " " .. settings.trinketBarSize,
    "true false true false hover 36", "defaults: both slots, no rings, glow on, one row, hover, 36 px")
equal(tostring(settings.trinketBarTime) .. " " .. tostring(settings.trinketBarColumn), "true false",
    "the time left shows, and the slots lie in a row")
equal(settings.trinketGridColumns, 6, "the swap list holds six icons a row to start with")
equal(settings.trinketBarQueue, true, "and a click in a fight queues the trinket for the fight's end")
equal(tostring(settings.trinketBarReady) .. " " .. tostring(settings.trinketBarWarn) .. " "
    .. tostring(settings.trinketBarChat) .. " " .. tostring(settings.trinketBarSound), "false false false false",
    "the four cooldown alerts are all off to start with")
for key in pairs(real.settingDefaults) do
    if key:find("^trinket") then equal(real.reloadSettings[key], nil, key .. " applies live, not on reload") end
end
Module:Initialize()
equal(_G.EraUITrinketBar, nil, "off: no bar made")
equal(Slot(13), nil, "off: no slot made")
equal(_G.EraUITrinketMenu, nil, "off: no quick menu made")
equal(Alert(), nil, "off: no alert line made either")
-- The ten trinket set keys (Bindings.xml, Core/Init.lua, the ten buttons in
-- Modules/TrinketKeys.lua): made as the addon loads whether the bar is
-- switched on or not, because a key puts a set on with no bar on screen.
equal(KeyButton(1) ~= nil and KeyButton(10) ~= nil and KeyButton(11) == nil, true,
    "off: the ten set keys have their buttons all the same, and there is no eleventh")
local keyOne = KeyButton(1)
equal(tostring(S[keyOne].secure) .. " " .. tostring(S[keyOne].template) .. " " .. S[keyOne].w .. "x" .. S[keyOne].h
    .. " " .. S[keyOne].alpha .. " " .. tostring(S[keyOne].mouse) .. " " .. S[keyOne].clicks,
    "false nil 1x1 0 false AnyDown,AnyUp",
    "each a plain one-pixel button, invisible, taking no mouse, taking a key's down and up clicks")
equal(tostring(keyOne:GetAttribute("type1")) .. " " .. tostring(keyOne:GetAttribute("useOnKeyDown")),
    "nil nil", "and nothing is written on it: loading a set is ordinary code")
equal(#Keys.buttons .. " " .. tostring(Keys.buttons[3] == KeyButton(3)), "10 true",
    "the ten are kept in one place, under the names Bindings.xml clicks")
equal(Menu(1) .. " / " .. Menu(10), "Trinket Set 1 / Trinket Set 10",
    "the game's menu shows Trinket Set 1 to 10 while no set answers to one")
local watched = 0
for _ in pairs(S[Driver()].events) do watched = watched + 1 end
equal(watched, 0, "off: no events watched")

---------------------------------------------------------------------------
-- On: the bar, its plain slots and what each shows
---------------------------------------------------------------------------
Turn("trinketBar", true)
local bar = _G.EraUITrinketBar
local s = S[bar]
equal(bar ~= nil and s.parent == UIParent and s.shown, true, "on: EraUI's own bar on the screen, shown")
equal(tostring(s.clamped) .. " " .. tostring(s.movable) .. " " .. tostring(s.mouse) .. " " .. tostring(s.drag) .. " "
    .. s.strata .. " " .. tostring(s.dontSave), "true true false LeftButton MEDIUM true",
    "clamped, movable, no mouse while locked (clicks go through), MEDIUM, the game keeps no place of its own")
equal(Point(bar), "BOTTOM UIParent BOTTOM 300 150", "first time: above the action bars, to their right")
for _, event in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN",
    "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    equal(S[Driver()].events[event], true, event .. " watched")
end
equal(Visible(), "13,14", "both trinket slots, the rings left out")
local one, two = Slot(13), Slot(14)
equal(tostring(S[one].secure) .. " " .. tostring(S[one].template), "false nil",
    "a slot is a plain button: nothing on the bar uses a trinket, so there is nothing for the game to protect")
equal(S[one].clicks, "AnyUp", "it takes every button's up click")
equal(Attrs(13), "nil nil", "the worn trinket is not written on it as an item")
equal(Attrs(14), "nil nil", "nor is anything on an empty slot")
equal(S[one].w .. "x" .. S[one].h .. " " .. S[bar].w .. "x" .. S[bar].h, "36x36 87x46", "36 px slots; the bar fits its two")
equal(Point(one) .. " / " .. Point(two), "TOPLEFT EraUITrinketBar TOPLEFT 5 -5 / TOPLEFT EraUITrinketBar TOPLEFT 46 -5",
    "side by side, five in from the bar's corner")
equal(S[one.icon].texture .. " " .. tostring(S[one.icon].grey) .. " " .. S[one.icon].alpha, "art.sunstone false 1",
    "the worn trinket's own icon")
equal(S[two.icon].texture .. " " .. tostring(S[two.icon].grey) .. " " .. S[two.icon].alpha,
    "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket true 0.5", "an empty slot: the paper doll's art, greyed and faded")
equal(tostring(S[two.cd].sweep) .. " " .. S[two.time].text, "nil ", "an empty slot has no sweep and no time")
-- A client that answers for its paper doll slots: its own art is used.
GetInventorySlotInfo = function(name) return nil, "art.empty." .. name end
Fire("PLAYER_EQUIPMENT_CHANGED")
equal(S[two.icon].texture, "art.empty.Trinket1Slot", "an empty slot takes the game's own art for it")
GetInventorySlotInfo = nil
Fire("PLAYER_EQUIPMENT_CHANGED")

---------------------------------------------------------------------------
-- Cooldowns, the time left and the ready glow
---------------------------------------------------------------------------
-- The game's own sweep, never one of ours. It was lightened on 26 Nov and
-- Squirt asked for the game's own back on 27 Nov, having seen its clock on
-- the character sheet: a washed sweep reads as broken beside it. The edge
-- line is what keeps a slot legible at this size instead.
equal(tostring(S[one.cd].swipeColour) .. " " .. tostring(S[one.cd].edge) .. " " .. tostring(S[one.cd].template),
    "nil true CooldownFrameTemplate",
    "the game's own sweep from its own template, with the rim line sweeping round it")
game.cd[13] = { now, 30 }
Fire("SPELL_UPDATE_COOLDOWN")
equal(S[one.cd].sweep[1] .. "," .. S[one.cd].sweep[2] .. " " .. S[one.time].text, now .. ",30 30", "used: the sweep and the time left")
Tick(20)
equal(S[one.time].text, "10", "ten seconds to go")
Tick(5.5)
equal(S[one.time].text, "4.5", "under ten: tenths")
equal(S[one.glow].shown, false, "no glow while it runs")
Tick(5)
equal(S[one.time].text .. " " .. tostring(S[one.cd].sweep) .. " " .. tostring(S[one.glow].shown), " nil true",
    "run out: the sweep goes, the time goes, the slot glows")
local bright = S[one.glow].alpha
Tick(.6)
equal(S[one.glow].alpha ~= bright and S[one.glow].shown, true, "the glow pulses")
Tick(4)
equal(S[one.glow].shown, false, "and goes after a few seconds")
Tick(2)
equal(S[one.glow].shown, false, "and stays off while nothing is on cooldown")
-- Time Left on Icon: the seconds on the icon, or the sweep alone without them.
game.cd[13] = { now, 30 }
Fire("SPELL_UPDATE_COOLDOWN")
equal(S[one.time].text, "30", "the seconds left are written on the icon")
Turn("trinketBarTime", false)
equal(tostring(S[one.cd].sweep ~= nil) .. " '" .. S[one.time].text .. "'", "true ''",
    "Time Left on Icon off: the sweep still runs, the seconds go")
Tick(1)
equal(S[one.time].text, "", "and the tick leaves them off")
Turn("trinketBarTime", true)
equal(S[one.time].text, "29", "on again: the seconds are back")
game.cd[13] = nil
Fire("SPELL_UPDATE_COOLDOWN")
Tick(5)
equal(S[one.glow].shown, false, "nothing on cooldown again")
-- Ready Glow off: nothing glows.
game.cd[13] = { now, 2 }
Fire("SPELL_UPDATE_COOLDOWN")
Turn("trinketBarGlow", false)
Tick(3)
equal(tostring(S[one.glow].shown) .. " " .. S[one.time].text, "false ", "Ready Glow off: no glow when it comes back")
settings.trinketBarGlow = true

---------------------------------------------------------------------------
-- A fight: secret cooldowns, and a bar that keeps working
---------------------------------------------------------------------------
game.cd[13] = { now, 120 }
game.secret = true
combat = true
-- The mock is as strict as the game: a secure frame shown, moved, resized or
-- written to in a fight throws. Nothing on the bar is one any more, so this
-- is proved on a secure button made here, and the bar is free to lay itself
-- out mid-fight.
local proof = CreateFrame("Button", nil, UIParent, "SecureActionButtonTemplate")
equal(pcall(function() proof:Show() end), false, "the mock still refuses a secure frame shown in a fight")
equal(pcall(function() proof:SetAttribute("item1", "item:1") end), false, "nor written to")
equal(pcall(function() proof:SetSize(40, 40) end), false, "nor resized")
equal(pcall(function() one:Show(); one:SetSize(36, 36); one:EnableMouse(false)
    one:SetPoint("TOPLEFT", bar, "TOPLEFT", 5, -5) end), true,
    "a trinket slot is shown, sized, moved and given the mouse in a fight with no complaint")
Fire("PLAYER_REGEN_DISABLED")
Fire("SPELL_UPDATE_COOLDOWN")
equal(issecretvalue(S[one.cd].sweep[1]) and S[one.time].text, "", "in a fight the game's secret numbers go to the sweep, no time is written")
local sweeps = S[one.cd].count.sweep
Tick(1)
equal(S[one.cd].count.sweep, sweeps, "the tick leaves a secret cooldown alone (a secret is never compared)")
-- A change asked for in a fight is made in the fight: there is nothing left
-- to wait for, so nothing is said about waiting.
said = nil
Turn("trinketBarRings", true)
equal(Visible() .. " | " .. tostring(said), "13,14,11,12 | nil", "the rings go on the bar in the fight, nothing said")
Turn("trinketBarTwoRows", true)
equal(S[bar].w .. "x" .. S[bar].h .. " | " .. tostring(said), "87x87 | nil", "and Two Rows takes hold in the fight too")
equal(Module:SetUnlocked(true), false, "no unlocking in a fight")
Turn("trinketBarTwoRows", false)
game.secret = false
combat = false
Fire("PLAYER_REGEN_ENABLED")
equal(Visible(), "13,14,11,12", "the fight over: the rings are still there")
equal(S[Slot(11).icon].texture .. " " .. S[Slot(12).icon].texture,
    "art.signet Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger", "a worn ring, and the empty ring slot's own art")
equal(Attrs(11), "nil nil", "nothing written on the worn ring's slot either")

---------------------------------------------------------------------------
-- The four shapes: Two Rows and Up and Down, each way, at four slots and two
---------------------------------------------------------------------------
-- A row, a column, two rows and two columns. Four slots: 169x46, 46x169,
-- 87x87 either way, but a row fills across first and a column down first.
local function Shape()
    local out = {}
    for _, info in ipairs(Kit.SLOTS) do
        local button = Slot(info.slot)
        if button and S[button].shown then
            local p = S[button].points[1]
            out[#out + 1] = info.slot .. "@" .. p[4] .. "," .. p[5]
        end
    end
    return S[bar].w .. "x" .. S[bar].h .. " " .. table.concat(out, " ")
end
equal(Shape(), "169x46 13@5,-5 14@46,-5 11@87,-5 12@128,-5", "one row: all four side by side")
Turn("trinketBarColumn", true)
equal(Shape(), "46x169 13@5,-5 14@5,-46 11@5,-87 12@5,-128", "Up and Down: all four in a column")
Turn("trinketBarTwoRows", true)
equal(Shape(), "87x87 13@5,-5 14@5,-46 11@46,-5 12@46,-46", "Up and Down with Two Rows: two columns, filled downwards")
Turn("trinketBarColumn", false)
equal(Shape(), "87x87 13@5,-5 14@46,-5 11@5,-46 12@46,-46", "Two Rows alone: two rows, filled across")
Turn("trinketBarRings", false)
equal(Shape(), "46x87 13@5,-5 14@5,-46", "two slots in two rows: one above the other")
Turn("trinketBarColumn", true)
equal(Shape(), "87x46 13@5,-5 14@46,-5", "two slots in two columns: side by side")
Turn("trinketBarTwoRows", false)
equal(Shape(), "46x87 13@5,-5 14@5,-46", "two slots in a column")
Turn("trinketBarColumn", false)
equal(Shape(), "87x46 13@5,-5 14@46,-5", "and back to a row")
Turn("trinketBarBoth", false)
equal(Visible(), "13", "Show Both Slots off: your first trinket alone")
Turn("trinketBarBoth", true)
Turn("trinketBarSize", 48)
equal(S[one].w .. " " .. S[bar].w .. "x" .. S[bar].h .. " " .. Point(two), "48 111x58 TOPLEFT EraUITrinketBar TOPLEFT 58 -5",
    "Icon Size: bigger slots, the bar with them")
Turn("trinketBarSize", 36)

---------------------------------------------------------------------------
-- The grid: what you carry, and putting it on
---------------------------------------------------------------------------
S[one].scripts.OnEnter(one)
local listing = _G.EraUITrinketList
equal(listing ~= nil and S[listing].parent == UIParent and S[listing].shown, true,
    "hover: the grid opens, EraUI's own frame on UIParent (never under a slot)")
equal(Lines(), "Amulet,Bauble", "the trinkets in your bags, by name; the axe and the ring left out")
equal(Foot(), "", "nothing to say out of a fight")
equal(Point(listing), "BOTTOM EraUITrinketSlot13 TOP 0 6", "over the slot it belongs to, so it never covers what sits under the bar")
do
    -- A bar at the top of the screen: no room over it, so under it.
    local was = S[one].top
    S[one].top = 760
    Listing.Open(13, "trinket", one, "Trinket 1")
    equal(Point(listing), "TOP EraUITrinketSlot13 BOTTOM 0 -6", "under the slot when there is no room over it")
    S[one].top = was
    Listing.Open(13, "trinket", one, "Trinket 1")
end
equal(Spread(), "186x60 2 tiles, rows at 6,-22", "a tile each, side by side under its title")
local row = Listing.rows[1]
equal(S[row.icon].texture .. " " .. row.entry.name .. " " .. S[row].w .. "x" .. S[row].h, "art.amulet Amulet 32x32",
    "a tile: the item's own icon on a 32 square")
equal(tostring(S[row.cd].swipeColour) .. " " .. tostring(S[row.cd].template), "nil CooldownFrameTemplate",
    "its sweep is the game's own from its own template, as the bar's own slots are")
-- Pointing at a tile: EraUI's own box above it, never the game's tooltip.
S[row].scripts.OnEnter(row)
equal(tostring(tip and tip.text) .. " " .. tostring(tip and tip.side) .. " " .. tostring(tip and tip.owner == row),
    "Amulet TOP true", "an item with no use is named alone, in EraUI's own box above the tile")
S[row].scripts.OnLeave(row)
equal(tip, nil, "and the box goes as the mouse leaves")
local bauble = TileOf("Bauble")
S[bauble].scripts.OnEnter(bauble)
equal(tostring(tip and tip.text) .. " " .. table.concat(S[bauble.edge].colour, ","), "Bauble / Use: Pop It 1,0.82,0.3,1",
    "one with a use says what it does under its name, and the tile's edge lights up")
S[bauble].scripts.OnLeave(bauble)
equal(tostring(tip) .. " " .. table.concat(S[bauble.edge].colour, ","), "nil 0.5,0.5,0.55,0.8",
    "and the edge goes back to grey")
-- A tile's own cooldown, read from the bag slot it sits in.
game.bagCd[0] = { [1] = { now, 45 } }
Fire("BAG_UPDATE_DELAYED")
bauble = TileOf("Bauble")
equal(S[bauble.cd].sweep[1] .. "," .. S[bauble.cd].sweep[2] .. " " .. S[bauble.time].text, now .. ",45 45",
    "a trinket in your bags that is on cooldown: the sweep and the seconds left on its tile")
Flick(36)
equal(S[bauble.time].text, "9.0", "the grid's own tick counts it down")
equal(tostring(S[TileOf("Amulet").cd].sweep) .. " '" .. S[TileOf("Amulet").time].text .. "'", "nil ''",
    "one that is ready carries no sweep and no time, so you can see it is")
game.bagCd[0] = nil
Fire("BAG_UPDATE_DELAYED")
-- No cap: the old list of lines stopped at fourteen, the grid shows the lot.
for i = 1, 8 do game.bags[2][i], game.bags[3][i] = MANY[i], MANY[i + 8] end
Fire("BAG_UPDATE_DELAYED")
equal(Spread(), "224x132 18 tiles, rows at 6,-22 6,-58 6,-94",
    "eighteen trinkets in your bags: every one of them, six across and three rows down")
equal(Lines():find("^Amulet,Bauble,Stone A,") ~= nil and Lines():find(",Stone P$") ~= nil, true,
    "in one list by name, from Amulet to Stone P")
-- Icons per Row: how wide it is, live.
Turn("trinketGridColumns", 3)
equal(Spread(), "186x240 18 tiles, rows at 6,-22 6,-58 6,-94 6,-130 6,-166 6,-202",
    "three a row: the same eighteen, six rows deep")
Turn("trinketGridColumns", 8)
equal(Spread(), "296x132 18 tiles, rows at 6,-22 6,-58 6,-94", "eight a row: a wider grid, three rows again")
Turn("trinketGridColumns", 6)
game.bags[2], game.bags[3] = {}, {}
Fire("BAG_UPDATE_DELAYED")
equal(Spread() .. " / " .. tostring(S[Listing.rows[3]].shown) .. " " .. tostring(Listing.rows[3].entry),
    "186x60 2 tiles, rows at 6,-22 / false nil", "put away again: the grid shrinks and the spare tiles empty")
row = Listing.rows[1]
row:Click()
equal(table.concat(game.picked, ",") .. " / " .. table.concat(game.equipped, ",") .. " / " .. tostring(S[listing].shown),
    "1:1 / 13 / false", "a click puts it on through the game's own bag calls, and the grid closes")
-- The bags changing while it is open.
S[two].scripts.OnEnter(two)
equal(Lines(), "Amulet,Bauble", "the second slot's grid: the same trinkets")
game.bags[1][1] = nil
game.bags[1] = { 4701 }
Fire("BAG_UPDATE_DELAYED")
equal(Lines() .. " / " .. Spread(), "Bauble / 186x60 1 tiles, rows at 6,-22",
    "an item gone from the bags goes from the open grid")
game.bags[0] = {}
Fire("BAG_UPDATE_DELAYED")
equal(Lines() .. " / " .. Foot() .. " / " .. Spread(), " / Nothing in your bags to put on. / 186x47 0 tiles, rows at ",
    "nothing left: no tiles, and the grid says so")
game.bags[0] = { 4501, 9000 }
game.bags[1] = { 4502, 4701 }
Fire("BAG_UPDATE_DELAYED")
equal(Lines(), "Amulet,Bauble", "and they come back")
---------------------------------------------------------------------------
-- A swap in a fight: Queue in a Fight
---------------------------------------------------------------------------
-- The game never lets gear change in a fight, so a click keeps that trinket
-- for the slot instead and it goes on the moment the fight ends. The grid is
-- open on your second trinket slot here.
game.picked, game.equipped = {}, {}
combat = true
game.secret = true
Fire("PLAYER_REGEN_DISABLED")
equal(Listing.slot, 14, "the grid is open on your second trinket slot")
equal(Lines() .. " / " .. Foot(),
    "(Amulet),(Bauble) / You can't change gear in a fight. / Click one to queue it instead.",
    "in a fight every tile fades, and the grid says why and what a click does there instead")
-- Nothing in your bags for that slot: the refusal alone, because there is no
-- tile to click.
local bag0, bag1 = game.bags[0], game.bags[1]
game.bags[0], game.bags[1] = {}, {}
Fire("BAG_UPDATE_DELAYED")
equal("'" .. Lines() .. "' / " .. Foot(), "'' / You can't change gear in a fight.",
    "an empty grid in a fight says the refusal alone and never tells you to click one")
game.bags[0], game.bags[1] = bag0, bag1
Fire("BAG_UPDATE_DELAYED")
equal(Foot(), "You can't change gear in a fight. / Click one to queue it instead.",
    "and the queue line is back as soon as there is something to click")
bauble = TileOf("Bauble")
equal(tostring(S[bauble].mouse) .. " " .. tostring(S[bauble.icon].grey) .. " " .. tostring(S[bauble.shade].shown),
    "true true true", "a faded tile still takes the mouse and keeps its highlight, so a click can queue it")
game.bagCd[0] = { [1] = { now, 45 } }
Flick(.2)
equal(issecretvalue(S[bauble.cd].sweep[1]) and S[bauble.time].text, "",
    "a trinket used in the fight: a bag's cooldown is secret too, so the tick hands the tile's sweep the two"
    .. " numbers as they are and writes no time")
local sweeps = S[bauble.cd].count.sweep
Flick(1)
equal(S[bauble.cd].count.sweep, sweeps, "and the tick leaves that tile alone (a secret is never compared)")
-- The click itself: nothing moves, the trinket waits for the slot, and the
-- slot and its tile both say so.
said = nil
bauble = TileOf("Bauble")
bauble:Click()
equal(table.concat(game.picked, ",") .. " / " .. table.concat(game.equipped, ",") .. " / " .. tostring(said),
    " /  / Trinket Bar: Your trinkets change when this fight ends.",
    "a click in a fight picks nothing up and says in chat when it will happen")
equal(Queued(bauble) .. " / " .. Queued(two) .. " / " .. Queued(one) .. " / " .. #Saved.Waiting(),
    "Queued / Queued /  / 1",
    "the tile and the slot it was queued for wear the Queued strip, your other slot does not, and one thing waits")
equal(tostring(S[bauble.icon].grey) .. " " .. S[bauble.icon].alpha, "false 1",
    "the one you queued keeps its colour while the rest of them stay faded")
equal(Queued(TileOf("Amulet")), "", "and nothing is on the one you did not pick")
-- One trinket waits a slot, so another tile clicked moves the queue to it.
said = nil
TileOf("Amulet"):Click()
equal(Queued(TileOf("Amulet")) .. " / " .. Queued(bauble) .. " / " .. #Saved.Waiting() .. " / " .. tostring(said),
    "Queued /  / 1 / nil", "another tile clicked in the same fight: the queue moves to it, nothing said twice")
-- The queued one clicked again takes it back.
TileOf("Amulet"):Click()
local waiter = Waiter()
equal(Queued(TileOf("Amulet")) .. " / " .. Queued(two) .. " / " .. tostring(Saved.Waiting()) .. " / "
    .. tostring(S[waiter].events.PLAYER_REGEN_ENABLED), " /  / nil / nil",
    "clicked again: the strips go, nothing waits, and the end of the fight stops being watched")
-- Queue in a Fight off: the refusal alone, and tiles that take no mouse.
Turn("trinketBarQueue", false)
equal(Foot() .. " / " .. tostring(S[TileOf("Bauble")].mouse) .. " / " .. tostring(S[TileOf("Bauble").shade].shown),
    "You can't change gear in a fight. / false / false",
    "Queue in a Fight off: the grid says the refusal alone and no tile takes the mouse")
said = nil
TileOf("Bauble"):Click()
equal(tostring(said) .. " / " .. table.concat(game.picked, ",") .. " / " .. tostring(Saved.Waiting()) .. " / " .. game.cleared,
    "You can't change gear in a fight. /  / nil / 1",
    "and a click that gets through is refused with the reason in chat, picking nothing up and queueing nothing")
equal(select(2, Kit.Equip({ bag = 0, slot = 1 }, 13)), "fight", "the kit itself refuses a swap in a fight")
Turn("trinketBarQueue", true)
-- The fight over: what was queued goes on, out of the bag slot it sits in by
-- then, and the strips come off.
said = nil
TileOf("Bauble"):Click()
equal(#Saved.Waiting() .. " " .. Queued(two), "1 Queued", "queued again for the fight's end")
-- The strip belongs to the slot it was queued for, and to no other.
S[one].scripts.OnEnter(one)
equal(Listing.slot .. " / " .. Queued(TileOf("Bauble")) .. " / " .. Queued(two) .. " / " .. Queued(one),
    "13 /  / Queued / ", "your first slot's grid wears no strip, and your second slot keeps its own")
S[two].scripts.OnEnter(two)
equal(Listing.slot .. " / " .. Queued(TileOf("Bauble")), "14 / Queued",
    "back on the slot it was queued for: that tile says so again")
game.bags[0] = { 9000, 4501 } -- the Bauble moved about while the fight went on
combat = false
game.secret = false
game.bagCd[0] = nil
Fire("PLAYER_REGEN_ENABLED")
S[waiter].scripts.OnEvent(waiter, "PLAYER_REGEN_ENABLED")
equal(table.concat(game.picked, ",") .. " / " .. table.concat(game.equipped, ",") .. " / " .. tostring(Saved.Waiting()),
    "0:2 / 14 / nil",
    "the fight over: the trinket you queued goes on, found again in the bag slot it sits in now, and nothing waits")
equal(Queued(two) .. " / " .. Queued(TileOf("Bauble")) .. " / " .. Foot() .. " / " .. tostring(S[TileOf("Bauble")].mouse),
    " /  /  / true", "the strips come off, and out of the fight the tiles are live again")
-- A queued trinket that is nowhere in your bags by the time the fight ends:
-- that slot is left as it is, and the trinket is named once.
game.picked, game.equipped = {}, {}
combat = true
game.secret = true
Fire("PLAYER_REGEN_DISABLED")
TileOf("Bauble"):Click()
game.bags[0] = { 9000 }
said = nil
combat = false
game.secret = false
Fire("PLAYER_REGEN_ENABLED")
S[waiter].scripts.OnEvent(waiter, "PLAYER_REGEN_ENABLED")
equal(table.concat(game.picked, ",") .. " / " .. tostring(said) .. " / " .. Queued(two),
    " / Trinket Bar: Bauble is not in your bags any more. / ",
    "put away before the fight ended: named in chat, nothing picked up for it, and the strip still comes off")
game.bags[0] = { 4501, 9000 }
Fire("BAG_UPDATE_DELAYED")
game.picked, game.equipped = {}, {}
-- One queue a slot: your two trinket slots each keep their own, and both go
-- on when the fight ends.
combat = true
game.secret = true
Fire("PLAYER_REGEN_DISABLED")
S[one].scripts.OnEnter(one)
TileOf("Bauble"):Click()
S[two].scripts.OnEnter(two)
TileOf("Amulet"):Click()
equal(#Saved.Waiting() .. " / " .. Queued(one) .. " / " .. Queued(two), "2 / Queued / Queued",
    "a trinket queued for each slot: both of them wait, and both slots say so")
combat = false
game.secret = false
Fire("PLAYER_REGEN_ENABLED")
S[waiter].scripts.OnEvent(waiter, "PLAYER_REGEN_ENABLED")
equal(table.concat(game.picked, ",") .. " / " .. table.concat(game.equipped, ",") .. " / " .. Queued(one) .. " / "
    .. Queued(two) .. " / " .. tostring(Saved.Waiting()), "0:1,1:1 / 13,14 /  /  / nil",
    "the fight over: both go on, in the order you asked for them, and both strips come off")
Listing.Close()
game.picked, game.equipped = {}, {}
-- Open List: Click. Hover opens nothing; a left-click opens and closes it.
Listing.Close()
Turn("trinketBarOpen", "click")
S[one].scripts.OnEnter(one)
equal(Listing.Shown(), false, "Click: pointing at a slot opens nothing")
one:Click("LeftButton")
equal(Listing.Shown() and Listing.slot, 13, "a left-click opens it")
one:Click("LeftButton")
equal(Listing.Shown(), false, "and a second left-click closes it")
one:Click("MiddleButton")
equal(Listing.Shown() and Listing.slot, 13, "any other button opens it too")
Listing.Close()
Turn("trinketBarOpen", "hover")
-- Leaving both the slot and the grid closes it a moment later.
S[one].scripts.OnEnter(one)
equal(Listing.Shown(), true, "hover again")
S[one].scripts.OnLeave(one)
S[listing].over = true
Flush()
equal(Listing.Shown(), true, "the mouse on the grid keeps it open")
S[listing].over = false
S[listing].scripts.OnLeave(listing)
Flush()
equal(Listing.Shown(), false, "the mouse away from both: closed")
-- A ring slot offers rings only.
Turn("trinketBarRings", true)
S[Slot(11)].scripts.OnEnter(Slot(11))
equal(Lines(), "Band", "a ring slot's grid: the ring in your bags, no trinkets")
Listing.Close()
Turn("trinketBarRings", false)

---------------------------------------------------------------------------
-- The quick menu: a right-click on a slot
---------------------------------------------------------------------------
equal(_G.EraUITrinketMenu, nil, "no quick menu until one is asked for")
one:Click("RightButton")
local quick = _G.EraUITrinketMenu
equal(quick ~= nil and S[quick].parent == UIParent and S[quick].shown, true,
    "a right-click opens it, EraUI's own frame on UIParent")
equal(S[quick].strata .. " " .. S[Catcher()].strata .. " " .. tostring(S[Catcher()].shown),
    "FULLSCREEN_DIALOG FULLSCREEN true", "it sits over the screen-wide button that closes it")
equal(Point(quick), "TOP EraUITrinketSlot13 BOTTOM 0 -6", "under the slot it was opened from")
equal(MenuRows(), "+Show Both Slots,-Show Your Rings,+Ready Glow,+Time Left on Icon,-Two Rows,-Up and Down,"
    .. "Unlock to move,Trinket sets,All settings",
    "its rows: the bar's six ticks as they stand, then Unlock to move, Trinket sets and All settings")
equal(S[MenuSizeText()].text, "Icon Size: 36 px", "and Icon Size at what is saved")
-- One of the two is up at a time.
one:Click("LeftButton")
equal(tostring(Listing.Shown()) .. " " .. tostring(Quick.Shown()), "true false", "a left-click swaps the menu for the grid")
one:Click("RightButton")
equal(tostring(Listing.Shown()) .. " " .. tostring(Quick.Shown()), "false true", "and a right-click swaps it back")
-- A tick here is the change /era makes: saved, and the bar follows at once.
local before = saves
MenuRow("Show Your Rings"):Click()
equal(tostring(settings.trinketBarRings) .. " " .. Visible() .. " " .. (saves - before), "true 13,14,11,12 1",
    "Show Your Rings ticked in the menu: saved, and the rings go on the bar")
equal(MenuRows():find("+Show Your Rings", 1, true) ~= nil and Quick.Shown(), true,
    "the menu's own tick fills in, and it stays open")
MenuRow("Show Your Rings"):Click()
equal(tostring(settings.trinketBarRings) .. " " .. Visible(), "false 13,14", "clicked again: off again")
MenuRow("Up and Down"):Click()
equal(tostring(settings.trinketBarColumn) .. " " .. Shape(), "true 46x87 13@5,-5 14@5,-46",
    "Up and Down in the menu stands the bar up")
MenuRow("Up and Down"):Click()
equal(tostring(settings.trinketBarColumn) .. " " .. Shape(), "false 87x46 13@5,-5 14@46,-5", "and lays it back down")
-- Icon Size: the same slider as /era's, live as it moves.
MenuSlider():SetValue(48)
equal(settings.trinketBarSize .. " " .. S[MenuSizeText()].text .. " " .. S[one].w, "48 Icon Size: 48 px 48",
    "the menu's slider: saved, said and the slots with it")
MenuSlider():SetValue(36)
equal(settings.trinketBarSize .. " " .. S[one].w, "36 36", "and back again")
equal(S[MenuSlider()].range[1] .. " to " .. S[MenuSlider()].range[2] .. " by " .. S[MenuSlider()].step
    .. " " .. S[MenuSlider()].orientation, "24 to 56 by 2 HORIZONTAL", "its range is Icon Size's own")
-- /era open on the same page: its own rows follow what the menu saved, so
-- the two never show different things.
E.settingsFrame = { checks = {
    trinketBarTwoRows = { rowKind = "tick", SetChecked = function(self, value) self.on = value end },
    trinketBarSize = { rowKind = "slider", SetChecked = function(self) self.reads = (self.reads or 0) + 1 end },
} }
MenuRow("Two Rows"):Click()
equal(tostring(E.settingsFrame.checks.trinketBarTwoRows.on) .. " " .. tostring(settings.trinketBarTwoRows), "true true",
    "a tick in the menu ticks the same row in /era")
MenuRow("Two Rows"):Click()
equal(tostring(E.settingsFrame.checks.trinketBarTwoRows.on), "false", "and unticks it again")
MenuSlider():SetValue(40)
equal(tostring(E.settingsFrame.checks.trinketBarSize.reads) .. " " .. settings.trinketBarSize, "1 40",
    "and the menu's slider has /era's Icon Size row read it afresh")
MenuSlider():SetValue(36)
E.settingsFrame = nil
-- Unlock to move: the menu goes, the bar is ready for a drag.
MenuRow("Unlock to move"):Click()
equal(tostring(Quick.Shown()) .. " " .. tostring(Module.unlocked) .. " " .. tostring(S[bar].mouse), "false true true",
    "Unlock to move: the menu closes and the bar takes the mouse")
equal(S[Catcher()].shown, false, "the screen-wide button goes with it")
one:Click("RightButton")
equal(tostring(Module.unlocked) .. " " .. tostring(Quick.Shown()), "false false",
    "a right-click on a slot locks the bar again instead of opening the menu")
-- All settings: /era, open at the Trinket Bar's own rows. Trinket sets: the
-- same window, open at Your Sets with your saved sets under it.
E.modules.Settings = { ShowSettings = function() said = "/era shown" end }
E.settingsFrame = { JumpTo = function(_, key) said = said .. " at " .. key end }
one:Click("RightButton")
MenuRow("All settings"):Click()
equal(said .. " " .. tostring(Quick.Shown()), "/era shown at trinketBar false",
    "All settings opens /era at the Trinket Bar and closes the menu")
one:Click("RightButton")
MenuRow("Trinket sets"):Click()
equal(said .. " " .. tostring(Quick.Shown()), "/era shown at trinketBarSets false",
    "Trinket sets opens the same window at Your Sets and closes the menu")
E.modules.Settings, E.settingsFrame = nil, nil
-- A click anywhere else closes it, and so does Escape: the game hides the
-- window whose name it finds in its own list.
one:Click("RightButton")
Catcher():Click()
equal(tostring(Quick.Shown()) .. " " .. tostring(S[Catcher()].shown), "false false", "a click elsewhere closes it")
equal(table.concat(UISpecialFrames, ","), "EraUITrinketMenu", "its name is in the game's Escape list, once")
one:Click("RightButton")
quick:Hide()
equal(tostring(Quick.Shown()) .. " " .. tostring(S[Catcher()].shown) .. " " .. tostring(Quick.anchor), "false false nil",
    "Escape hides it, and the screen-wide button and the slot it belonged to go with it")
-- A fight keeps it shut, the way it keeps the drag locked.
one:Click("RightButton")
combat = true
Fire("PLAYER_REGEN_DISABLED")
equal(Quick.Shown(), false, "a fight starting shuts an open menu")
one:Click("RightButton")
equal(Quick.Shown(), false, "and no right-click opens one in a fight")
combat = false
Fire("PLAYER_REGEN_ENABLED")
one:Click("RightButton")
equal(Quick.Shown(), true, "out of the fight it opens again")
Quick.Close()

---------------------------------------------------------------------------
-- Move Bar: the drag, the saved place and Reset
---------------------------------------------------------------------------
equal(Module:SetUnlocked(true), true, "unlocked out of a fight")
equal(tostring(S[bar].mouse) .. " " .. tostring(S[bar].h), "true 60", "unlocked: it takes the mouse and makes room for the hint")
equal(tostring(S[one].mouse) .. " " .. tostring(S[two].mouse), "false false",
    "and its slots take none, so a drag can start anywhere on it")
S[bar].left, S[bar].top = 420, 600
S[bar].scripts.OnDragStart(bar)
equal(S[bar].count.moving, 1, "a left drag moves it")
local before = saves
S[bar].scripts.OnDragStop(bar)
equal(settings.trinketBarPosition.x .. "," .. settings.trinketBarPosition.y .. " " .. (saves - before) .. " " .. tostring(S[bar].userPlaced),
    "420,-168 1 false", "dropped: its corner kept in the screen's units, saved, the game's own mark let go")
equal(Point(bar), "TOPLEFT UIParent TOPLEFT 420 -168", "and it sits there")
-- Loaded again from that saved place, as after a reload.
Turn("trinketBar", false)
Turn("trinketBar", true)
equal(Point(_G.EraUITrinketBar), "TOPLEFT UIParent TOPLEFT 420 -168", "switched on again: back at the place it kept")
S[bar].scripts.OnMouseUp(bar, "RightButton")
equal(tostring(Module.unlocked) .. " " .. tostring(S[one].mouse), "false true",
    "a right-click on the bar locks it, and the slots take the mouse again")
Module:ResetPosition()
equal(tostring(settings.trinketBarPosition) .. " " .. Point(bar), "nil BOTTOM UIParent BOTTOM 300 150", "Reset: back to the first-time spot")

---------------------------------------------------------------------------
-- Your sets: saving what you wear, and putting it back on
---------------------------------------------------------------------------
EraUIClassicCharDB = {}
game.picked, game.equipped = {}, {} -- the grid's own clicks, read already
-- A set's name and what it holds, slot by slot.
local function SetText(index)
    local set = Saved.Set(index)
    if not set then return "none" end
    local out = {}
    for _, info in ipairs(Kit.SLOTS) do
        local id = set.items[info.slot]
        if id then out[#out + 1] = info.slot .. "=" .. ((ITEMS[id] and ITEMS[id].name) or id) end
    end
    return set.name .. ": " .. table.concat(out, " ")
end
-- What the game was asked to pick up and put on since the last look.
local function Did()
    local out = table.concat(game.picked, ",") .. " / " .. table.concat(game.equipped, ",")
    game.picked, game.equipped = {}, {}
    return out
end
equal(Saved.Count() .. " " .. tostring(EraUIClassicCharDB.trinketSets.version), "0 1",
    "no sets to start with, and this character's own table made for them")
-- Save what I'm wearing: the slots the bar is showing, and no others.
equal(Saved.New(), 1, "the first set saved")
equal(SetText(1), "Set 1: 13=Sunstone", "what you wear in the slots you can see; your ring is hidden, so it is not in it")
Turn("trinketBarRings", true)
equal(Saved.New(), 2, "a second set")
equal(SetText(2), "Set 2: 13=Sunstone 11=Signet", "with Show Your Rings on, your rings go in as well")
game.worn[13] = 4502
Turn("trinketBarRings", false)
equal(tostring(Saved.Over(2)) .. " " .. SetText(2), "true Set 2: 13=Amulet 11=Signet",
    "Save Over writes the slots you can see and leaves the hidden ring in the set")
game.worn[13] = 4500
-- A name as typed: codes out, trimmed, 24 letters at most.
equal(Saved.Rename(Saved.Set(1), "|cffff0000Fire|r fight"), "Fire fight", "a name with colour codes in it comes out plain")
equal(Saved.Rename(Saved.Set(1), "   "), "Fire fight", "nothing typed keeps the name it had")
equal(Saved.Rename(Saved.Set(1), string.rep("x", 40)), string.rep("x", 24), "a long name is cut to 24 letters")
Saved.Rename(Saved.Set(1), "Fire fight")
equal(Saved.Set(Saved.New()).name, "Set 1", "a new set takes the lowest Set number no set is called")
-- Every change to the sets is kept there and then (Core/Persistence.lua holds
-- a copy of this character's sets for a client that loses its SavedVariables).
-- Without this it would hold none of the sets made this session until the
-- next logout, so a session that ended badly lost the lot. A ring changed in
-- its own editor is kept the same way (Modules/ActionRings.lua).
local kept = saves
local mine = Saved.New("Kept")
local madeIt = saves - kept
Saved.Over(mine)
local savedOver = saves - kept
Saved.Rename(Saved.Set(mine), "Kept well")
local renamed = saves - kept
Saved.Key(Saved.Set(mine), 4)
local keyed = saves - kept
Saved.Delete(mine)
equal(madeIt .. "," .. savedOver .. "," .. renamed .. "," .. keyed .. "," .. (saves - kept), "1,2,3,4,5",
    "a set made, saved over, renamed, given a key and deleted: every one of them writes the settings recovery")
-- What is saved is checked as it is read.
EraUIClassicCharDB.trinketSets = { version = 1, sets = { { name = "Good", items = { [13] = 4500, [14] = "no", [11] = 1.5 } },
    { items = { [13] = 1 } }, "junk" } }
equal(Saved.Count() .. " " .. SetText(1), "1 Good: 13=Sunstone",
    "a set with no name, a junk one and items that are not whole numbers all go")
EraUIClassicCharDB.trinketSets = { version = 9, sets = { { name = "Old" } } }
equal(Saved.Count() .. " " .. tostring(EraUIClassicCharDB.trinketSets.old.version), "0 9",
    "a table from another version starts empty, with a copy of it kept")
-- Putting a set on: the item comes out of your bags by its ID, from wherever
-- it sits now.
EraUIClassicCharDB.trinketSets = nil
equal(Saved.Count(), 0, "a fresh list")
game.worn[13] = 4501
local kept = Saved.New("Bauble set")
game.worn[13] = 4500
equal(SetText(kept) .. " " .. Did(), "Bauble set: 13=Bauble  / ", "saved while you wore the Bauble, nothing picked up")
equal(Saved.Wear(kept), "now", "loaded out of a fight: at once")
equal(Did(), "0:1 / 13", "the Bauble comes out of the bag it is in now and goes in your first trinket slot")
game.worn[13] = 4501
equal(Saved.Wear(kept) .. " " .. Did(), "now  / ", "the same set again, already on you: nothing is picked up")
-- Both trinket slots hold the same kind of thing, so the same two trinkets
-- the other way round are already the set you saved.
game.worn[13], game.worn[14] = 4501, 4502
local pair = Saved.New("Pair")
game.worn[13], game.worn[14] = 4502, 4501
equal(SetText(pair) .. " / " .. Saved.Wear(pair) .. " " .. Did(), "Pair: 13=Bauble 14=Amulet / now  / ",
    "the two of them swapped round: nothing moves")
-- A set saved with one slot empty holds nothing for that slot, so loading it
-- leaves that slot as it is: its trinket goes back in the slot it was saved
-- in, not in the first free one.
game.worn[13], game.worn[14] = nil, 4501
local second = Saved.New("Second slot")
game.worn[13], game.worn[14] = 4500, 4502
equal(SetText(second) .. " / " .. Saved.Wear(second) .. " " .. Did(), "Second slot: 14=Bauble / now 0:1 / 14",
    "a set with nothing saved for your first slot puts its own trinket back in your second and leaves the first alone")
-- The other way round, where the first free slot is the right one anyway.
game.worn[13], game.worn[14] = 4501, nil
local first = Saved.New("First slot")
game.worn[13], game.worn[14] = 4500, 4502
equal(SetText(first) .. " / " .. Saved.Wear(first) .. " " .. Did(), "First slot: 13=Bauble / now 0:1 / 13",
    "and one saved for your first slot goes back in that one")
Saved.Delete(first)
Saved.Delete(second)
-- An item that is not in your bags any more: that slot is left as it is and
-- named, and the rest of the set still goes on.
game.worn[13], game.worn[14] = 4601, 4502
local gone = Saved.New("Gone")
game.worn[13], game.worn[14] = 4500, nil
said = nil
local how, line = Saved.Wear(gone)
equal(how .. " | " .. Did() .. " | " .. tostring(said),
    "now | 1:1 / 14 | Trinket Bar: Stone A is not in your bags any more.",
    "the Amulet goes on, the trinket that has gone is named in chat, and the set still loads")
equal(line, "Stone A is not in your bags any more.", "and the panel is told the same, without the bar's name in front of it")
-- In a fight the game refuses a swap, so the set is kept and goes on the
-- moment the fight ends. One line says so, once a fight.
combat = true
game.secret = true
Fire("PLAYER_REGEN_DISABLED")
said = nil
equal(Saved.Wear(kept) .. " " .. Did() .. " " .. tostring(said),
    "later  /  Trinket Bar: Your trinkets change when this fight ends.",
    "asked for in a fight: kept, nothing picked up, and chat says when it happens")
local waiter = Waiter()
equal(#Saved.Waiting() .. " " .. tostring(S[waiter].events.PLAYER_REGEN_ENABLED), "1 true",
    "one thing waits, and the end of the fight is watched while it does")
said = nil
equal(Saved.Wear(pair) .. " " .. tostring(said) .. " " .. #Saved.Waiting(), "later nil 1",
    "a second set asked for in the same fight: nothing said twice, and only the last one waits")
equal(Saved.Apply(), false, "and nothing goes on while the fight is still on")
combat = false
game.secret = false
-- The bar and the sets hear the fight's end for themselves, as in the game.
Fire("PLAYER_REGEN_ENABLED")
S[waiter].scripts.OnEvent(waiter, "PLAYER_REGEN_ENABLED")
equal(Did() .. " " .. tostring(Saved.Waiting()) .. " " .. tostring(S[waiter].events.PLAYER_REGEN_ENABLED),
    "0:1,1:1 / 13,14 nil nil", "the fight over: the set waiting goes on, nothing waits and nothing is watched")
-- A set deleted while it waits goes out of the waiting list with it.
combat = true
Fire("PLAYER_REGEN_DISABLED")
equal(Saved.Wear(1), "later", "kept for the fight's end again")
equal(tostring(Saved.Delete(1)) .. " " .. tostring(Saved.Waiting()) .. " " .. Saved.Count(), "true nil 2",
    "deleted while it waited: nothing waits now")
combat = false
Fire("PLAYER_REGEN_ENABLED")
S[waiter].scripts.OnEvent(waiter, "PLAYER_REGEN_ENABLED")
equal(Did(), " / ", "so the fight ending puts nothing on")
equal(tostring(Saved.Wear(99)) .. " " .. tostring(select(2, Saved.Wear(99))), "nil gone",
    "a set that is not there loads nothing")
-- A set and a queued trinket wait in the one list, and it is done in the
-- order you asked for it: the trinket you queued after the set is the last
-- thing to go on, so that one slot ends on it and the rest of the set still
-- goes on.
EraUIClassicCharDB = {}
game.worn[13], game.worn[14] = 4501, 4502
local both = Saved.New("Both")
game.worn[13], game.worn[14] = 4500, nil
Did()
combat = true
Fire("PLAYER_REGEN_DISABLED")
equal(Saved.Wear(both), "later", "the set kept for the fight's end")
local amulet
for _, entry in ipairs(Kit.Bags("trinket")) do if entry.name == "Amulet" then amulet = entry end end
equal(Saved.Equip(amulet, 13) .. " " .. #Saved.Waiting(), "later 2",
    "then a trinket queued into your first slot: two things wait, not one instead of the other")
combat = false
Fire("PLAYER_REGEN_ENABLED")
S[waiter].scripts.OnEvent(waiter, "PLAYER_REGEN_ENABLED")
equal(Did(), "0:1,1:1,1:1 / 13,14,13",
    "the fight over: the set goes on, then the trinket you queued, so your first slot is the one you queued")
equal(tostring(Saved.Waiting()) .. " " .. tostring(S[waiter].events.PLAYER_REGEN_ENABLED), "nil nil",
    "and nothing is left waiting or watched")
-- A queued trinket out of a fight goes straight on.
equal(Saved.Equip(amulet, 14) .. " " .. Did() .. " " .. tostring(Saved.Waiting()), "now 1:1 / 14 nil",
    "out of a fight the same click puts it on there and then and queues nothing")
equal(tostring(Saved.Equip("not an item", 14)) .. " " .. tostring(select(2, Saved.Equip("not an item", 14))),
    "nil gone", "and something that is not a bag slot at all puts nothing on")
-- The sets are this character's own: the saved table being replaced is read
-- afresh, never remembered.
EraUIClassicCharDB = { trinketSets = { version = 1, sets = { { name = "Another", items = {} } } } }
equal(Saved.Count() .. " " .. Saved.Set(1).name, "1 Another", "another character's table is read afresh")
EraUIClassicCharDB = {}
for i = 1, 30 do Saved.New("Set " .. i) end
equal(Saved.Count() .. " " .. Saved.Set(30).name, "30 Set 30", "as many sets as you want: nothing caps the list")

---------------------------------------------------------------------------
-- The ten set keys: a set on a key, and the key pressed
---------------------------------------------------------------------------
-- You keep as many sets as you like, and any of them can answer to one of
-- the ten Trinket Set keys in the game's own Key Bindings menu. The key is
-- yours to set there; EraUI only reads it and writes the set's name beside
-- the entry.
do
    EraUIClassicCharDB = {}
    game.worn[13], game.worn[14] = 4500, nil
    local fire = Saved.Set(Saved.New("Fire fight"))
    game.worn[13] = 4502
    local cold = Saved.Set(Saved.New("Cold fight"))
    game.worn[13] = 4500
    Did()
    equal(tostring(fire.key) .. " " .. Menu(3), "nil Trinket Set 3", "a set answers to no key until you give it one")
    equal(tostring(Saved.Key(fire, 3)) .. " " .. Menu(3), "true Trinket Set 3: Fire fight",
        "given key 3: the game's own menu reads that key with the set's name")
    -- Two sets can never answer to the same key, so taking one clears it from
    -- the set that had it, and that set is given back to be named.
    local ok, lost = Saved.Key(cold, 3)
    equal(tostring(ok) .. " " .. (lost and lost.name or "none") .. " " .. tostring(fire.key) .. " " .. Menu(3),
        "true Fire fight nil Trinket Set 3: Cold fight", "the same key again: the set that held it loses it")
    equal(tostring(Saved.Key(cold, 11)) .. " " .. tostring(cold.key), "false 3", "there is no eleventh key")
    equal(tostring(Saved.NextKey(nil, 1)) .. "," .. tostring(Saved.NextKey(3, 1)) .. "," .. tostring(Saved.NextKey(10, 1))
        .. "," .. tostring(Saved.NextKey(nil, -1)) .. "," .. tostring(Saved.NextKey(1, -1)),
        "1,4,nil,10,nil", "stepping along them: on from no key is key 1, on from key 10 is no key, and back the other way")
    -- The key a player has set is read as the game writes it, and never set.
    bound["CLICK EraUITrinketSetButton3:LeftButton"] = "SHIFT-F7"
    equal(tostring(Keys.KeyText(3)) .. " " .. tostring(Keys.KeyText(4)), "Shift F7 nil",
        "the key you set on an entry reads back; an entry with none reads as nothing")
    -- The press itself. A key sends a down click and an up click, which are
    -- the one press.
    said = nil
    KeyButton(3):Click("LeftButton")
    equal(Did() .. " " .. tostring(said), "1:1 / 13 Trinket Bar: Put on Cold fight.",
        "the key puts its set on out of a fight, out of the bag it is in now, and says which")
    said = nil
    KeyButton(3):Click("LeftButton")
    equal(Did() .. " " .. tostring(said), " /  nil", "the second click of the same press does nothing")
    now = now + 1
    said = nil
    KeyButton(3):Click("LeftButton")
    equal(tostring(said), "Trinket Bar: Put on Cold fight.", "a fresh press answers again")
    -- Each key keeps its own press, so one key straight after another answers.
    Saved.Key(fire, 5)
    now = now + 1
    said = nil
    KeyButton(5):Click("LeftButton")
    local first = said
    KeyButton(3):Click("LeftButton")
    equal(tostring(first) .. " / " .. tostring(said), "Trinket Bar: Put on Fire fight. / Trinket Bar: Put on Cold fight.",
        "a second key pressed straight after the first is a press of its own")
    Did()
    said = nil
    now = now + 1
    KeyButton(7):Click("LeftButton")
    equal(Did() .. " " .. tostring(said), " /  Trinket Bar: no set is on Trinket Set 7 yet.",
        "a key no set answers to says so and moves nothing")
    -- In a fight the game refuses a gear swap, so the key keeps the set and
    -- it goes on the moment the fight ends: the sets' own waiting list, not a
    -- second one.
    combat = true
    game.secret = true
    Fire("PLAYER_REGEN_DISABLED")
    said = nil
    now = now + 1
    KeyButton(3):Click("LeftButton")
    equal(Did() .. " " .. tostring(said) .. " " .. #Saved.Waiting(),
        " /  Trinket Bar: Your trinkets change when this fight ends. 1",
        "pressed in a fight: nothing moves, chat says when it will, and the set waits")
    combat = false
    game.secret = false
    Fire("PLAYER_REGEN_ENABLED")
    local waiting = Waiter()
    S[waiting].scripts.OnEvent(waiting, "PLAYER_REGEN_ENABLED")
    equal(Did() .. " " .. tostring(Saved.Waiting()), "1:1 / 13 nil", "the fight over: the key's set goes on")
    -- The game's menu keeps up with the sets themselves.
    Saved.Rename(cold, "Cold snap")
    equal(Menu(3), "Trinket Set 3: Cold snap", "renamed: the menu's name follows")
    equal(tostring(Saved.Delete(Saved.IndexOf(cold))) .. " " .. Menu(3), "true Trinket Set 3",
        "deleted: its key is free again and the menu shows the plain name")
    -- A junk key, and two sets saved on the same one: checked as they are read.
    EraUIClassicCharDB.trinketSets = { version = 1, sets = { { name = "First", items = {}, key = 2 },
        { name = "Second", items = {}, key = 2 }, { name = "Third", items = {}, key = 0 },
        { name = "Fourth", items = {}, key = 2.5 } } }
    equal(tostring(Saved.Set(1).key) .. "," .. tostring(Saved.Set(2).key) .. "," .. tostring(Saved.Set(3).key)
        .. "," .. tostring(Saved.Set(4).key), "2,nil,nil,nil",
        "the first set keeps the key two of them were saved on, and a key that is not one of the ten goes")
    -- A key works with the bar switched off, and says so once a session.
    local lines = {}
    local status = E.Status
    E.Status = function(self, text) lines[#lines + 1] = text; status(self, text) end
    Saved.Key(Saved.Set(1), 5)
    Turn("trinketBar", false)
    now = now + 1
    KeyButton(5):Click("LeftButton")
    equal(table.concat(lines, " | "), "Trinket Bar: Put on First. | Trinket Bar: Your sets load with the bar switched off.",
        "the bar off: the key loads its set all the same, and one line says it does")
    for at = #lines, 1, -1 do lines[at] = nil end
    now = now + 1
    KeyButton(5):Click("LeftButton")
    equal(table.concat(lines, " | "), "Trinket Bar: Put on First.", "and that line is said once a session, not every press")
    E.Status = status
    Turn("trinketBar", true)
    EraUIClassicCharDB = {}
    game.worn[13], game.worn[14] = 4500, nil
    Did()
end

---------------------------------------------------------------------------
-- The cooldown alerts: ready, and thirty seconds before
---------------------------------------------------------------------------
-- All four off to start with, so none of this happens until you ask for it.
-- The ready line stands on the slot's own Cooldown widget, which counts the
-- game's own numbers itself, so it works in a fight where they are secret.
-- The thirty-second warning is worked out from plain numbers alone, which
-- means out of a fight, and sets one timer for the moment it is due.
game.cd = {}
Fire("SPELL_UPDATE_COOLDOWN")
Waits()
said = nil
game.cd[13] = { now, 20 }
Fire("SPELL_UPDATE_COOLDOWN")
Tick(21)
equal(tostring(Alert()) .. " " .. tostring(said) .. " '" .. Waits() .. "'", "nil nil ''",
    "off: a trinket coming ready makes no line, says nothing and asks the game to wait for nothing")
-- Say When One Is Ready.
Turn("trinketBarReady", true)
now = now + 5
game.cd[13] = { now, 20 }
Fire("SPELL_UPDATE_COOLDOWN")
equal(Said(), "no line", "while a cooldown runs there is nothing on screen")
said = nil
Tick(21)
equal(Said() .. " | " .. tostring(said), "Sunstone is ready. | nil",
    "run out: the trinket's own name on screen, and nothing in chat until that is asked for")
local alertLine = Alert()
equal(S[alertLine].name .. " " .. Point(alertLine) .. " " .. S[alertLine].w .. "x" .. S[alertLine].h
    .. " " .. S[alertLine].strata .. " " .. tostring(S[alertLine].mouse),
    "EraUITrinketAlert CENTER UIParent CENTER 0 140 272x26 HIGH false",
    "EraUI's own frame in the middle of the screen, sized as it is made, taking no mouse")
-- It fades itself, and its tick goes back to nothing as it ends.
equal(Fade(1), "true 1.00", "the line is held whole for a moment")
equal(Fade(2), "true 0.58", "then it fades")
equal(Fade(1), "false 1.00", "and goes")
equal(Fade(1), "no tick", "with its tick put back to nothing, so none of it runs between lines")
-- Dark Mode: the bar paints every part of itself, the line with them.
settings.darkMode = true
Module:Paint()
equal(LineFill(), "0.071,0.071,0.086,0.9", "Dark Mode: the line's box follows the bar's")
settings.darkMode = nil
Module:Paint()
equal(LineFill(), "0.024,0.024,0.031,0.84", "and the classic box comes back")
-- Say It In Chat Too and Play A Sound.
Turn("trinketBarChat", true)
Turn("trinketBarSound", true)
now = now + 5
game.cd[13] = { now, 20 }
Fire("SPELL_UPDATE_COOLDOWN")
said = nil
Tick(21)
equal(Said() .. " | " .. tostring(said) .. " | " .. Played(),
    "Sunstone is ready. | Trinket Bar: Sunstone is ready. | 856",
    "the same words in chat with the bar's own name in front, and one of the game's own sounds")
local kits = SOUNDKIT
SOUNDKIT = nil
now = now + 5
game.cd[13] = { now, 20 }
Fire("SPELL_UPDATE_COOLDOWN")
Tick(21)
equal("'" .. Played() .. "' " .. Said(), "'' Sunstone is ready.", "a client without the game's sound kits stays silent")
SOUNDKIT = kits
-- The widget and the bar's own tick can both see one cooldown run out, and
-- that is one trinket coming ready, so it is one line.
now = now + 5
game.cd[13] = { now, 20 }
Fire("SPELL_UPDATE_COOLDOWN")
now = now + 21
said = nil
Done(one)
equal(Said() .. " | " .. tostring(said), "Sunstone is ready. | Trinket Bar: Sunstone is ready.",
    "the widget's own word for a sweep running out is the line, with no number read")
said = nil
Tick(.2)
equal(tostring(said), "nil", "and the bar's tick seeing the same thing a breath later says nothing twice")
-- A fight: the game keeps its cooldowns secret, so the slot's own widget is
-- the only honest word for ready, and that is what the line stands on.
now = now + 5
game.cd[13] = { now, 120 }
Fire("SPELL_UPDATE_COOLDOWN")
combat = true
game.secret = true
Fire("PLAYER_REGEN_DISABLED")
Fire("SPELL_UPDATE_COOLDOWN")
equal(issecretvalue(S[one.cd].sweep[1]), true, "in the fight the game's secret numbers go to the sweep as they are")
now = now + 5
said = nil
Done(one)
equal(Said() .. " | " .. tostring(said), "Sunstone is ready. | Trinket Bar: Sunstone is ready.",
    "and the line still comes in the fight, with nothing read, compared or added up")
-- A slot with no cooldown on it: a sweep that has only been cleared must
-- never announce a trinket that was never on cooldown.
combat = false
game.secret = false
game.cd[13] = nil
Fire("PLAYER_REGEN_ENABLED")
combat = true
game.secret = true
Fire("PLAYER_REGEN_DISABLED")
Fire("SPELL_UPDATE_COOLDOWN")
now = now + 5
said = nil
Done(one)
equal(tostring(said), "nil", "a slot with nothing on cooldown says nothing when its sweep is cleared")
-- A cooldown that starts inside the fight has no readable numbers at all, so
-- it is left alone rather than guessed at, and it is said properly once the
-- fight is over and the game's numbers can be read again.
game.cd[13] = { now, 60 }
Fire("SPELL_UPDATE_COOLDOWN")
said = nil
Done(one)
equal(tostring(said), "nil", "a cooldown begun in the fight is never announced from a secret")
combat = false
game.secret = false
Fire("PLAYER_REGEN_ENABLED")
now = now + 61
said = nil
Tick(.2)
equal(Said() .. " | " .. tostring(said), "Sunstone is ready. | Trinket Bar: Sunstone is ready.",
    "the fight over, the game's numbers readable again, and its end is said then")
-- Warn Thirty Seconds Before: one timer, for the moment thirty seconds are
-- left, worked out from the game's own plain numbers.
Turn("trinketBarWarn", true)
game.cd[13] = nil
Fire("SPELL_UPDATE_COOLDOWN")
Waits()
now = now + 5
game.cd[13] = { now, 90 }
Fire("SPELL_UPDATE_COOLDOWN")
equal(Waits(), "60", "a ninety second cooldown asks the game to wait sixty seconds")
Tick(1)
equal("'" .. Waits() .. "' " .. tostring(Alerts.Pending(13) ~= nil), "'' true",
    "and the ten reads a second after that ask for nothing more: one timer a cooldown")
now = now + 60
said = nil
Flush()
equal(Said() .. " | " .. tostring(said),
    "Sunstone is ready in 30 seconds. | Trinket Bar: Sunstone is ready in 30 seconds.",
    "thirty seconds before it is ready: its own line, in the same words")
Tick(.2)
equal("'" .. Waits() .. "' " .. tostring(Alerts.Pending(13)), "'' nil", "and nothing more is asked for once it is said")
-- Under thirty seconds left the first time the numbers can be read, which is
-- a cooldown begun in a fight and read at the fight's end: nothing to warn
-- about, so nothing is set.
game.cd[13] = nil
Fire("SPELL_UPDATE_COOLDOWN")
Waits()
now = now + 5
game.cd[13] = { now - 100, 120 }
Fire("SPELL_UPDATE_COOLDOWN")
equal("'" .. Waits() .. "' " .. tostring(Alerts.Pending(13)), "'' nil",
    "a cooldown with under thirty seconds left when it is first read warns about nothing")
-- The trinket taken off while its cooldown ran: its warning goes with it, and
-- the timer that was already out finds nothing waiting.
game.cd[13], game.cd[14] = nil, nil
game.worn[14] = 4501
Fire("PLAYER_EQUIPMENT_CHANGED")
Waits()
now = now + 5
game.cd[14] = { now, 90 }
Fire("SPELL_UPDATE_COOLDOWN")
equal(Waits() .. " " .. tostring(Alerts.Pending(14) ~= nil), "60 true", "your second slot keeps its own warning")
game.worn[14] = nil
Fire("PLAYER_EQUIPMENT_CHANGED")
said = nil
Flush()
equal(tostring(Alerts.Pending(14)) .. " " .. tostring(said), "nil nil",
    "the trinket taken off: the warning is dropped and the timer that was out says nothing")
-- The slot holding another trinket by the time the warning is due: the
-- warning was about the one that was on, so it is not said about this one.
game.worn[14] = 4501
Fire("PLAYER_EQUIPMENT_CHANGED")
now = now + 5
game.cd[14] = { now, 90 }
Fire("SPELL_UPDATE_COOLDOWN")
Waits()
game.worn[14] = 4502
said = nil
Flush()
equal(tostring(said), "nil", "a slot holding another trinket by then says nothing")
-- A slot taken off the bar while its cooldown runs: its sweep and its
-- warning go with it, so a slot you cannot see never glows or announces
-- anything. Refresh is called here without flushing the timers, so what the
-- slot leaving really drops is what is checked.
game.cd[13], game.cd[14] = nil, nil
game.worn[14] = 4501
Fire("PLAYER_EQUIPMENT_CHANGED")
now = now + 5
game.cd[14] = { now, 90 }
Fire("SPELL_UPDATE_COOLDOWN")
equal(tostring(Alerts.Pending(14) ~= nil) .. " " .. tostring(S[two.cd].sweep ~= nil), "true true",
    "your second slot on cooldown, with its warning waiting")
settings.trinketBarBoth = false
Module:Refresh()
equal(tostring(Alerts.Pending(14)) .. " " .. tostring(S[two.cd].sweep) .. " " .. tostring(S[two].shown),
    "nil nil false", "Show Both Slots off: the slot goes, and its sweep and its waiting warning go with it")
now = now + 5
said = nil
Done(two)
equal(tostring(said) .. " " .. tostring(S[two.glow].shown), "nil false",
    "so that slot's own widget running out later says nothing and glows nothing")
Flush()
equal(tostring(said), "nil", "and the warning timer that was already out finds nothing waiting")
settings.trinketBarBoth = true
Module:Refresh()
Waits()
Flush()
-- The bar switched off takes its alerts with it.
game.cd[14] = nil
game.worn[14] = 4501
Fire("PLAYER_EQUIPMENT_CHANGED")
now = now + 5
game.cd[13] = { now, 2 }
Fire("SPELL_UPDATE_COOLDOWN")
now = now + 3
Tick(.2)
game.cd[14] = { now, 90 }
Fire("SPELL_UPDATE_COOLDOWN")
equal(tostring(Alerts.Shown()) .. " " .. tostring(Alerts.Pending(14) ~= nil), "true true",
    "a line up, and a warning waiting on the other slot")
Turn("trinketBar", false)
equal(tostring(Alerts.Shown()) .. " " .. tostring(Alerts.Pending(14)), "false nil",
    "the bar off: no line left on screen and nothing waiting for a bar that is not there")
-- Back as the rest of the suite has them.
for _, key in ipairs({ "trinketBarReady", "trinketBarWarn", "trinketBarChat", "trinketBarSound" }) do
    settings[key] = false
end
game.cd = {}
game.worn[13], game.worn[14] = 4500, nil
Turn("trinketBar", true)
Fire("PLAYER_EQUIPMENT_CHANGED")
Waits()
Played()

---------------------------------------------------------------------------
-- Off again
---------------------------------------------------------------------------
said = nil
one:Click("RightButton")
equal(Quick.Shown(), true, "the quick menu open")
combat = true
Turn("trinketBar", false)
equal(tostring(S[bar].shown) .. " " .. Visible() .. " | " .. tostring(said), "false  | nil",
    "switched off in a fight: the bar and its slots go there and then, nothing said about waiting for it")
equal(tostring(Quick.Shown()) .. " " .. Attrs(13), "false nil nil", "the quick menu goes with it, and no slot holds an item")
combat = false
watched = 0
for _ in pairs(S[Driver()].events) do watched = watched + 1 end
equal(watched .. " " .. tostring(Listing.Shown()), "0 false", "off: nothing watched and no grid")

-- Nothing of the game's touched -----------------------------------------------
local touched = {}
for key in pairs(UIParent) do touched[#touched + 1] = tostring(key) end
equal(table.concat(touched, ",") .. "|" .. table.concat(forbidden, ","), "|",
    "no key written on UIParent; no tooltip, hooks or bindings")

local moduleChecks = checks

---------------------------------------------------------------------------
-- /era > Action Bars > Trinkets
---------------------------------------------------------------------------
-- The real window (Tools/SettingsMock.lua); the module's stand-in counts what
-- the rows ask of it.
local M = dofile("Tools/SettingsMock.lua")
local Session, Open, Flush2 = M.Session, M.Open, M.Flush
local function Keys(f) return table.concat(M.Keys(f), ",") end
local told
local calls = { refresh = 0, unlock = {}, reset = 0 }
local stub = { unlocked = false }
function stub:Refresh() calls.refresh = calls.refresh + 1 end
function stub:SetUnlocked(on)
    calls.unlock[#calls.unlock + 1] = tostring(on)
    if not self.allowed then return false end
    self.unlocked = on
    return true
end
function stub:ResetPosition() calls.reset = calls.reset + 1 end
-- The window's own item data answers for the sets panel too: the same
-- trinkets as above, by their ID alone, because a saved set has no bag slot
-- to read a link from.
local itemInfo = C_Item.GetItemInfo
C_Item.GetItemInfo = function(id)
    if ITEMS[id] then return ITEMS[id].name end
    return itemInfo(id)
end
C_Item.GetItemInfoInstant = function(id)
    local item = ITEMS[id]
    if not item then return nil end
    return id, "Armor", "Miscellaneous", item.loc, item.icon
end
local Ex, f = Session("ROGUE", nil, nil, nil, function(Ex)
    Ex.modules.TrinketBar = stub
    -- The sets, their keys and their panel, as the game loads them: the kit
    -- does every read, so what you wear and carry above answers here as well,
    -- and the names in the game's Key Bindings menu are Core/Init.lua's own.
    -- EraUI's own hover box, which a cell and the key button use instead of
    -- the game's tooltip.
    Ex.SetTrinketSetBindingName = real.SetTrinketSetBindingName
    Ex.Look = {
        ShowTip = function(owner, side, rows)
            local words = {}
            for _, row in ipairs(rows) do words[#words + 1] = row[1] end
            tip = { owner = owner, side = side, text = table.concat(words, " / ") }
        end,
        HideTip = function(owner) if tip and (owner == nil or tip.owner == owner) then tip = nil end end,
    }
    assert(loadfile("Modules/TrinketKit.lua"))("EraUI", Ex)
    assert(loadfile("Modules/TrinketSets.lua"))("EraUI", Ex)
    assert(loadfile("Modules/TrinketSetList.lua"))("EraUI", Ex)
    assert(loadfile("Modules/TrinketKeys.lua"))("EraUI", Ex)
end)
for key, value in pairs(real.settingDefaults) do
    if key:find("^trinket") then Ex.settings[key], Ex.settingDefaults[key] = value, value end
end
Ex.Status = function(_, text) told = text end
f:Hide(); f:Show(); Flush2()
Open(f, "actionBars", "trinkets")
equal(f.sectionAbout:GetText(), "The stone dock, the Classic action buttons, action rings and your trinkets.",
    "Action Bars says it has your trinkets")
equal(Keys(f), "trinketBar", "its switch alone while it's off")
local switch = f.checks.trinketBar
equal(switch.text:GetText() .. " " .. tostring(switch:GetChecked()), "Trinket Bar false", "its tick, off")
switch:Click(); Flush2()
equal(tostring(Ex.settings.trinketBar) .. " " .. calls.refresh .. " " .. tostring(told),
    "true 1 Trinket Bar enabled. Move Bar under it puts it where you want.", "switched on: the bar follows, chat says how to move it")
equal(Keys(f), "trinketBar,trinketBarUnlock,trinketBarBoth,trinketBarRings,trinketBarGlow,trinketBarTime,trinketBarTwoRows,"
    .. "trinketBarColumn,trinketBarQueue,trinketBarReady,trinketBarWarn,trinketBarChat,trinketBarSound,"
    .. "trinketBarOpen,trinketBarTimeStyle,trinketBarSize,trinketGridColumns,trinketBarPlace,trinketBarSets",
    "its options show under it, in order, the four alerts with them, and Your Sets after them")
M.NoOverlaps(f, "Trinket Bar"); M.Fits(f, "Trinket Bar")
equal(tostring(f.checks.trinketBarBoth:GetChecked()) .. " " .. tostring(f.checks.trinketBarRings:GetChecked()) .. " "
    .. tostring(f.checks.trinketBarGlow:GetChecked()) .. " " .. tostring(f.checks.trinketBarTwoRows:GetChecked()),
    "true false true false", "Show Both Slots and Ready Glow on, Show Your Rings and Two Rows off")
equal(f.checks.trinketBarTime.text:GetText() .. " " .. tostring(f.checks.trinketBarTime:GetChecked()) .. " / "
    .. f.checks.trinketBarColumn.text:GetText() .. " " .. tostring(f.checks.trinketBarColumn:GetChecked()),
    "Time Left on Icon true / Up and Down false", "Time Left on Icon on, Up and Down off")
equal(f.checks.trinketBarQueue.text:GetText() .. " " .. tostring(f.checks.trinketBarQueue:GetChecked()),
    "Queue in a Fight true", "Queue in a Fight on, so a click in a fight is never wasted")
equal(f.checks.trinketBarReady.text:GetText() .. " / " .. f.checks.trinketBarWarn.text:GetText() .. " / "
    .. f.checks.trinketBarChat.text:GetText() .. " / " .. f.checks.trinketBarSound.text:GetText() .. " / "
    .. tostring(f.checks.trinketBarReady:GetChecked()) .. tostring(f.checks.trinketBarWarn:GetChecked())
    .. tostring(f.checks.trinketBarChat:GetChecked()) .. tostring(f.checks.trinketBarSound:GetChecked()),
    "Say When One Is Ready / Warn Thirty Seconds Before / Say It In Chat Too / Play A Sound / falsefalsefalsefalse",
    "the four cooldown alerts, all off")
equal(f.checks.trinketBarSize.text:GetText() .. " / " .. f.checks.trinketGridColumns.text:GetText(),
    "Icon Size: 36 px / Icons per Row: 6", "both sliders at their defaults")
f.checks.trinketBarRings:Click(); Flush2()
equal(tostring(Ex.settings.trinketBarRings) .. " " .. calls.refresh .. " " .. told, "true 2 Trinket Bar: Show Your Rings on.",
    "a tick: saved, the bar follows, said")
f.checks.trinketBarSize.slider:SetValue(48)
equal(Ex.settings.trinketBarSize .. " " .. f.checks.trinketBarSize.text:GetText() .. " " .. calls.refresh, "48 Icon Size: 48 px 3",
    "Icon Size saved, the bar follows")
f.checks.trinketGridColumns.slider:SetValue(4)
equal(Ex.settings.trinketGridColumns .. " " .. f.checks.trinketGridColumns.text:GetText() .. " " .. calls.refresh,
    "4 Icons per Row: 4 4", "Icons per Row saved, and the open grid follows")
f.checks.trinketGridColumns.slider:SetValue(6)
-- An alert tick is saved and said like every other tick here.
f.checks.trinketBarReady:Click(); Flush2()
equal(tostring(Ex.settings.trinketBarReady) .. " " .. told, "true Trinket Bar: Say When One Is Ready on.",
    "ticking Say When One Is Ready: saved and said")
f.checks.trinketBarReady:Click(); Flush2()
equal(tostring(Ex.settings.trinketBarReady) .. " " .. told, "false Trinket Bar: Say When One Is Ready off.",
    "and off again")
-- Open List: Hover or Click.
local choice = f.checks.trinketBarOpen
equal(choice.text:GetText() .. " " .. choice.buttons[1].label:GetText() .. "/" .. choice.buttons[2].label:GetText(),
    "Open List Hover/Click", "the choice row")
choice.buttons[2]:Click(); Flush2()
equal(Ex.settings.trinketBarOpen .. " " .. told, "click Trinket Bar: left-click a slot to open the list.", "Click chosen")
choice.buttons[1]:Click(); Flush2()
equal(Ex.settings.trinketBarOpen .. " " .. told, "hover Trinket Bar: the list opens as you point at a slot.", "Hover chosen")
-- Move Bar: Unlock, then Lock; refused while the module says no.
local unlock = f.checks.trinketBarUnlock
unlock.button:Click()
equal(table.concat(calls.unlock, ",") .. " " .. unlock.button.label:GetText() .. " " .. told,
    "true Unlock Trinket Bar: switch it on first, then unlock.", "the module says no: the button stays Unlock")
stub.allowed = true
unlock.button:Click()
equal(unlock.button.label:GetText() .. " " .. told, "Lock Trinket Bar: drag it to move it. Lock, or right-click it, when you're done.",
    "unlocked: the button says Lock")
stub.unlocked = false
stub.watch(false)
equal(unlock.button.label:GetText(), "Unlock", "the bar locking itself (a right-click, a fight) puts the button back")
unlock.button:Click()
unlock.button:Click()
equal(unlock.button.label:GetText() .. " " .. told, "Unlock Trinket Bar: locked.", "Lock again")
f.checks.trinketBarPlace.button:Click()
equal(calls.reset .. " " .. told, "1 Trinket Bar: it's back where it starts.", "Reset Position")
-- The footer: each row's own words and default.
local function Hover(key) local _, help, extras = M.Hover(f, f.checks[key]); return help, extras end
local help, extras = Hover("trinketBar")
equal(help:find("Left-click a slot to swap it from your bags, right-click it for these options", 1, true) ~= nil and extras,
    "Default: Off.", "the switch: what it does, off by default")
_, extras = Hover("trinketBarTime")
equal(extras, "Default: On.", "Time Left on Icon on by default")
_, extras = Hover("trinketBarColumn")
equal(extras, "Default: Off.", "Up and Down off by default")
help, extras = Hover("trinketBarQueue")
equal(help:find("keeps that item and puts it on the moment the fight ends", 1, true) ~= nil and extras,
    "Default: On.", "Queue in a Fight says what it does with a click in a fight, and is on by default")
help, extras = Hover("trinketBarReady")
equal(help:find("in the middle of the screen as a trinket on the bar comes off cooldown", 1, true) ~= nil and extras,
    "Default: Off.", "Say When One Is Ready says where the line shows, and is off by default")
help, extras = Hover("trinketBarWarn")
equal(help:find("One whose cooldown started in a fight is worked out at the fight's end", 1, true) ~= nil and extras,
    "Default: Off.", "the thirty second warning says plainly when it can be worked out, and is off by default")
_, extras = Hover("trinketBarChat")
equal(extras, "Default: Off.", "Say It In Chat Too off by default")
_, extras = Hover("trinketBarSound")
equal(extras, "Default: Off.", "Play A Sound off by default")
_, extras = Hover("trinketBarSize")
equal(extras, "Default: 36 px.", "Icon Size's default")
_, extras = Hover("trinketGridColumns")
equal(extras, "Default: 6.", "Icons per Row's default")
_, extras = Hover("trinketBarOpen")
equal(extras, "Default: Hover.", "Open List's default")
_, extras = Hover("trinketBarBoth")
equal(extras, "Default: On.", "Show Both Slots on by default")
_, extras = Hover("trinketBarRings")
equal(extras, "Default: Off.", "Show Your Rings off by default")
_, extras = Hover("trinketBarUnlock")
equal(extras, "", "Move Bar has no default")
_, extras = Hover("trinketBarSets")
equal(extras, "", "nor Your Sets")
for key in pairs(f.checks) do
    if key:find("^trinket") then
        local words = Hover(key)
        equal(M.LinesIn(words, 570, 12) <= 2 and words:find("\226\128\148", 1, true) == nil, true,
            key .. " fits two footer lines, no em dash: " .. words)
    end
end
---------------------------------------------------------------------------
-- Your Sets: the sets panel in the window
---------------------------------------------------------------------------
-- Show Your Rings was ticked above, so all four slots are on show here.
local Store, Panel = Ex.TrinketSets, Ex.TrinketSetList
local heading, panel = f.checks.trinketBarSets, Panel.panel
equal(heading.rowKind .. " " .. tostring(heading.wide) .. " " .. heading.text:GetText(), "heading true Your Sets",
    "Your Sets: a heading on a whole line")
equal(tostring(panel ~= nil and heading.inlinePanel == panel) .. " " .. tostring(panel ~= nil and panel:IsShown()),
    "true true", "with the sets panel under it")
equal(panel:GetTop() <= heading:GetBottom() - 5.99 and panel:GetLeft() == f.settingsContent:GetLeft(), true,
    "6 under its row, at the page's left")
equal(Store.Count() .. " " .. tostring(panel.none:IsShown()), "0 true", "no sets yet, and the panel says so")
M.NoOverlaps(f, "Trinket sets"); M.Fits(f, "Trinket sets")
-- What each line shows: a cell for every slot you can see, with what the set
-- holds for it.
local function Cells(line)
    local out = {}
    for _, cell in ipairs(line.cells) do
        if cell:IsShown() then out[#out + 1] = cell.itemName or "-" end
    end
    return table.concat(out, ",")
end
panel.save:Click()
local setLine = panel.lines[1]
equal(Store.Count() .. " " .. setLine.nameBox:GetText() .. " " .. tostring(setLine:IsShown()) .. " "
    .. tostring(panel.none:IsShown()), "1 Set 1 true false", "Save What I'm Wearing: a line for it, named Set 1")
equal(Cells(setLine), "Sunstone,-,Signet,-", "a cell for each slot you can see: what it holds, and the empty ones")
equal(panel.hint:GetText(), "Saved Set 1.", "and the panel says what it did")
-- Typing in the name box renames it.
setLine.nameBox:SetFocus()
setLine.nameBox:SetText("Fire fight")
setLine.nameBox:ClearFocus()
equal(Store.Set(1).name .. " / " .. panel.hint:GetText(), "Fire fight / Renamed Fire fight.", "the name as typed")
-- Save Over: what you have on now, with a hidden slot left alone.
game.worn[13] = 4502
setLine.over:Click()
equal(Cells(setLine) .. " / " .. panel.hint:GetText(), "Amulet,-,Signet,- / Saved what you have on into Fire fight.",
    "Save Over writes the slots you can see")
-- Load: the set back on, out of a fight.
game.worn[13] = 4500
local picked = #game.picked
setLine.load:Click()
equal(#game.picked - picked .. " " .. game.equipped[#game.equipped] .. " " .. panel.hint:GetText(),
    "1 13 Put on Fire fight.", "Load takes the Amulet out of your bags and puts it in your first trinket slot")
-- The key it answers to, bound in the panel itself (27 Nov 2026): a
-- left-click waits for a key, the next keypress is bound to it, and a
-- right-click takes it off again. A free slot of the ten is picked for you,
-- so the game's own menu still shows and changes it as before.
local keyOf = setLine.key
equal(keyOf.label:GetText() .. " " .. tostring(Store.Set(1).key), "No key nil",
    "a saved set answers to no key until you give it one")
keyOf:Click("LeftButton")
equal(keyOf.label:GetText() .. " " .. tostring(Store.Set(1).key), "Press a key nil",
    "a click waits for one, and nothing is set until a key is pressed")
keyOf:Fire("OnEnter")
equal(tip and tip.text, "Press a key / Press the key you want, Ctrl and Shift included. Escape leaves it as it was."
    .. " / A key already used elsewhere is taken for this.",
    "and it says so, in EraUI's own box")
keyOf:Fire("OnLeave")
-- Escape leaves everything alone.
Panel.catcher.scripts.OnKeyDown(Panel.catcher, "ESCAPE")
equal(keyOf.label:GetText() .. " " .. tostring(Store.Set(1).key) .. " " .. #bindings, "No key nil 0",
    "Escape leaves it as it was, with no binding written")
-- A real key, with its modifiers, goes on the first free slot.
keyOf:Click("LeftButton")
ctrl = true
Panel.catcher.scripts.OnKeyDown(Panel.catcher, "1")
ctrl = false
equal(Store.Set(1).key .. " / " .. bindings[#bindings] .. " / " .. panel.hint:GetText(),
    "1 / CTRL-1 -> CLICK EraUITrinketSetButton1:LeftButton / Fire fight is on CTRL-1.",
    "the key is bound to the set's own slot, and the panel says which key")
equal(_G["BINDING_NAME_CLICK EraUITrinketSetButton1:LeftButton"], "Trinket Set 1: Fire fight",
    "and the game's own menu reads that key with the set's name")
Panel.Refresh()
equal(keyOf.label:GetText(), "CTRL-1", "the button reads the key itself, not the slot it sits in")
keyOf:Fire("OnEnter")
equal(tip and tip.text, "On CTRL-1 / Press that key and this set goes on, wherever the trinkets are sitting."
    .. " / Left-click, then press a key. Right-click takes the key off.",
    "pointing at it names the key in EraUI's own box")
keyOf:Fire("OnLeave")
equal(tip, nil, "and the box goes as you leave it")
-- A modifier on its own is not a key.
keyOf:Click("LeftButton")
Panel.catcher.scripts.OnKeyDown(Panel.catcher, "LSHIFT")
equal(keyOf.label:GetText(), "Press a key", "a modifier on its own is not taken as the key")
Panel.catcher.scripts.OnKeyDown(Panel.catcher, "ESCAPE")
-- And a right-click takes the key off.
local was = #bindings
keyOf:Click("RightButton")
equal(tostring(Store.Set(1).key) .. " / " .. bindings[#bindings] .. " / " .. (#bindings - was),
    "nil / CTRL-1 (cleared) / 1", "a right-click takes the key off the set and clears the binding")
equal(keyOf.label:GetText(), "No key", "and the button says so again")
equal(_G["BINDING_NAME_CLICK EraUITrinketSetButton1:LeftButton"], "Trinket Set 1",
    "so the game's menu shows that key's plain name again")
-- Put one back for the rest of the checks below.
keyOf:Click("LeftButton")
ctrl = true
Panel.catcher.scripts.OnKeyDown(Panel.catcher, "1")
ctrl = false
-- As many sets as you want: the panel grows with the list, so the page
-- scrolls and no set is ever out of reach.
panel.save:Click()
local tall = panel:GetHeight()
panel.save:Click(); Flush2()
equal(Store.Count() .. " " .. tostring(panel:GetHeight() > tall) .. " " .. tostring(panel.lines[3]:IsShown()),
    "3 true true", "three sets, three lines, and a taller panel")
equal(f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + .01 and f.settingsScrollHint:IsShown(), true,
    "the page scrolls with the panel open")
M.NoOverlaps(f, "Trinket sets, three of them"); M.Fits(f, "Trinket sets, three of them")
-- Two sets can never answer to the same key, so taking one says which set
-- lost it, and the game's menu follows the key to its new set.
panel.lines[2].key:Click("LeftButton")
ctrl = true
Panel.catcher.scripts.OnKeyDown(Panel.catcher, "1")
ctrl = false
equal(panel.lines[2].key.label:GetText() .. " / " .. panel.lines[1].key.label:GetText(),
    "CTRL-1 / CTRL-1",
    "a second set takes its own free slot, and the key it was given is bound to that slot")
equal(_G["BINDING_NAME_CLICK EraUITrinketSetButton2:LeftButton"], "Trinket Set 2: " .. Store.Set(2).name,
    "and that entry in the game's menu reads with the set that has it")
-- Delete asks first, and anything else takes the question back.
panel.lines[3].delete:Click()
equal(panel.lines[3].delete.label:GetText() .. " " .. Store.Count(), "Delete? 3", "Delete asks first")
panel.lines[3].delete:Click()
equal(Store.Count() .. " " .. tostring(panel.lines[3]:IsShown()) .. " " .. panel.hint:GetText(),
    "2 false Set 2 deleted.", "and a second click deletes it")
panel.lines[2].delete:Click()
equal(panel.lines[2].delete.label:GetText(), "Delete?", "it asks about the next one")
panel.lines[1].load:Click()
equal(panel.lines[2].delete.label:GetText() .. " " .. Store.Count(), "Delete 2",
    "anything else in the panel takes the question back")
-- One line asks at a time: Delete on another line takes the question back
-- from the line that had it, so no line is left saying Delete? while a click
-- on it would only ask again.
panel.lines[1].delete:Click()
panel.lines[2].delete:Click()
equal(panel.lines[1].delete.label:GetText() .. " / " .. panel.lines[2].delete.label:GetText() .. " / " .. Store.Count(),
    "Delete / Delete? / 2", "Delete on another line: the first asks no more, and nothing is deleted")
panel.lines[1].delete:Click()
equal(panel.lines[1].delete.label:GetText() .. " / " .. panel.lines[2].delete.label:GetText() .. " / " .. Store.Count(),
    "Delete? / Delete / 2", "and the question moves back the same way")
-- In a fight the game refuses a swap, so Load keeps the set for the fight's
-- end; saving, renaming and deleting are not gear and go through as ever.
M.S.combat = true
picked = #game.picked
panel.lines[1].load:Click()
equal(#game.picked - picked .. " / " .. panel.hint:GetText() .. " / " .. tostring(told),
    "0 / Your trinkets change when this fight ends. / Trinket Bar: Your trinkets change when this fight ends.",
    "Load in a fight: nothing moves, and the panel and chat both say when it will")
panel.save:Click(); Flush2()
equal(Store.Count() .. " " .. tostring(panel.lines[3]:IsShown()), "3 true", "a set is still saved in a fight")
-- The game refuses a binding change in a fight, so the panel says so plainly
-- instead of waiting for a key it could never set (27 Nov 2026). Saving and
-- renaming still work in one, as above.
panel.lines[1].key:Click("LeftButton")
equal(panel.lines[1].key.label:GetText() .. " / " .. (#game.picked - picked) .. " / " .. panel.hint:GetText(),
    "CTRL-1 / 0 / You can't change a key in a fight.",
    "a key cannot be bound in a fight, it says so, and no gear moves for it")
M.NoOverlaps(f, "Trinket sets in a fight")
M.S.combat = false
Store.Apply()
equal(#game.picked - picked, 1, "the fight over: the set that was waiting goes on")

-- Search finds them by their own words.
local found = M.Results(f, "trinket")
equal(table.concat(found, ","), "trinketBar,trinketBarUnlock,trinketBarBoth,trinketBarRings,trinketBarGlow,trinketBarTime,"
    .. "trinketBarTwoRows,trinketBarColumn,trinketBarQueue,trinketBarReady,trinketBarWarn,trinketBarChat,"
    .. "trinketBarSound,trinketBarOpen,trinketBarTimeStyle,trinketBarSize,trinketGridColumns,trinketBarPlace,"
    .. "trinketBarSets",
    "trinket finds all nineteen")
equal(table.concat(M.Results(f, "save a set"), ","):find("trinketBarSets", 1, true) ~= nil, true, "save a set finds Your Sets")
equal(table.concat(M.Results(f, "trinket set key"), ","):find("trinketBarSets", 1, true) ~= nil, true,
    "trinket set key finds Your Sets, where a set is given one")
equal(table.concat(M.Results(f, "swap"), ","):find("trinketBar", 1, true) ~= nil, true, "swap finds the bar")
equal(table.concat(M.Results(f, "column"), ","):find("trinketBarColumn", 1, true) ~= nil, true, "column finds Up and Down")
equal(table.concat(M.Results(f, "icons per row"), ","):find("trinketGridColumns", 1, true) ~= nil, true,
    "icons per row finds the grid's own slider")
equal(table.concat(M.Results(f, "queue"), ","):find("trinketBarQueue", 1, true) ~= nil, true,
    "queue finds Queue in a Fight")
f.searchBox:SetText(""); Flush2()
switch:Click(); Flush2()
equal(tostring(Ex.settings.trinketBar) .. " " .. tostring(told) .. " " .. Keys(f), "false Trinket Bar disabled. trinketBar",
    "off again: said, its rows fold away")
equal(tostring(Panel.panel:IsShown()) .. " " .. tostring(Panel.panel:IsVisible()), "false false",
    "and the sets panel goes with its row, not just out of sight")
equal("'" .. Panel.panel.hint:GetText() .. "' " .. tostring(Panel.said) .. " " .. tostring(Panel.armed), "'' nil nil",
    "what it last said goes with it, so the page never opens on a line about a set loaded or deleted minutes ago")
equal(f:JumpTo("trinketBarSize"), switch, "a jump to a folded slider lands on the switch")

print("Trinket Bar checks passed: " .. checks .. " assertions (" .. moduleChecks .. " on the bar, " .. (checks - moduleChecks) .. " on /era).")
