local _, E = ...

-- The trinket set keys (the game's Key Bindings menu, AddOns > EraUI: ten
-- entries, Trinket Set 1 to Trinket Set 10). Each entry clicks one of the
-- ten plain buttons made here, and each button puts on the set pointed at it
-- in /era > Action Bars > Trinkets > Your Sets. You keep as many sets as you
-- like (Modules/TrinketSets.lua); ten of them at a time can answer to a key.
--
-- The entry's own name in that menu reads with the set's name, "Trinket Set
-- 3: Fire fight". That is one global word the game reads each time the list
-- draws a row (Core/Init.lua), never a key written as the game runs: Forever
-- gives secret-compare errors the moment an addon sets a binding, so EraUI
-- sets none and the key itself is yours to choose in that menu. The keys are
-- read here and nothing else: Bindings.xml is read once as the game starts,
-- so a copy of EraUI that had no trinket keys needs the game restarted, not
-- a reload, before the ten entries show in the menu.
--
-- A key works with the bar switched off, so the buttons are made whatever
-- the options say and nothing here is secure: a set goes on through
-- Modules/TrinketSets.lua, which puts it on out of a fight and keeps it for
-- the fight's end in one.
local Keys = {}
E.TrinketKeys = Keys

Keys.NAME = "EraUITrinketSetButton"
Keys.PLAIN = "Trinket Set "
-- A key sends a down click and an up click; both are the one press.
local GAP = .2

local function K() return E.TrinketKit end
local function Sets() return E.TrinketSets end

Keys.buttons = {}
local pressed = {}

---------------------------------------------------------------------------
-- What the game's menu shows
---------------------------------------------------------------------------

-- The key a set key answers to, as the game writes it ("F7"), or nothing.
-- Read only: nothing here ever sets a binding.
function Keys.KeyText(slot)
    local kit = K()
    if not kit.Num(slot) then return nil end
    local key = kit.Call(GetBindingKey, "CLICK " .. Keys.NAME .. slot .. ":LeftButton")
    if not kit.Word(key) then return nil end
    local text = kit.Call(GetBindingText, key)
    return kit.Word(text) and text or key
end

-- What each of the ten entries is called in the menu now: the name of the
-- set that answers to it, or the plain name where no set does. Written again
-- whenever a set is made, renamed, deleted or pointed at another key.
function Keys.Names()
    local sets = Sets()
    if not (sets and type(E.SetTrinketSetBindingName) == "function") then return false end
    for slot = 1, K().KEYS do
        local set = sets.Keyed(slot)
        E:SetTrinketSetBindingName(slot, set and set.name or nil)
    end
    return true
end

---------------------------------------------------------------------------
-- A key pressed
---------------------------------------------------------------------------

-- The set on that key, put on: at once out of a fight, kept and put on the
-- moment the fight ends in one (the sets say that themselves). One plain
-- line says what went on, and with the bar switched off one more line, once
-- a session, says the keys work anyway.
function Keys.Load(slot)
    local kit, sets = K(), Sets()
    if not (sets and kit.Num(slot)) then return false end
    local set, index = sets.Keyed(slot)
    if not set then
        E:Status(kit.SAID .. "no set is on " .. Keys.PLAIN .. slot .. " yet.")
        return false
    end
    local name = set.name
    local how, line = sets.Wear(index)
    -- A set with an item that has gone names it itself, so the only line
    -- left to say is the plain one about a set that went straight on.
    if how == "now" and not line then E:Status(kit.SAID .. "Put on " .. name .. ".") end
    if E:GetSetting("trinketBar") ~= true and not Keys.toldOff then
        Keys.toldOff = true
        E:Status(kit.SAID .. "Your sets load with the bar switched off.")
    end
    return how ~= nil, how
end

-- A key's click: one press, whichever of its two clicks comes first. Each
-- key has its own last press, so two keys one after the other both answer.
local function Press(button)
    local kit = K()
    local slot = button.keySlot
    local now = kit.Call(GetTime)
    if kit.Num(now) then
        local was = pressed[slot]
        if was and now - was < GAP then return end
        pressed[slot] = now
    end
    Keys.Load(slot)
end

---------------------------------------------------------------------------
-- The buttons
---------------------------------------------------------------------------

-- The ten buttons, made once: plain, one pixel, invisible, taking no mouse
-- of their own, and taking a key's down and up clicks. Nothing a key does
-- here is protected, so there is nothing secure about them and nothing that
-- has to wait for a fight to end.
function Keys.Build()
    if Keys.built then return true end
    for slot = 1, K().KEYS do
        local button = CreateFrame("Button", Keys.NAME .. slot, UIParent)
        button.keySlot = slot
        button:SetSize(1, 1)
        button:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
        button:SetAlpha(0)
        button:EnableMouse(false)
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetScript("OnClick", Press)
        Keys.buttons[slot] = button
    end
    Keys.built = true
    return true
end

-- At load (Modules/TrinketBar.lua's Initialize, which runs whether the bar
-- is switched on or off): the ten buttons, and the ten names as the sets
-- now stand.
function Keys.Start()
    Keys.Build()
    Keys.Names()
end
