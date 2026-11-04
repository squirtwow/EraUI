-- Upgrade Spell Ranks (/era > Action Bars; Modules/SpellRanks.lua) against a
-- mock of Forever's spellbook (C_SpellBook: every rank listed, the lower
-- ones only hidden on the page), its action slots (GetActionInfo,
-- PickupSpell, PlaceAction, ClearCursor, the cursor) and its gamepad bars'
-- own slots. Learning a new rank moves the slots holding the rank it
-- outgrew up to it, on every page the player fills (1 to 180, the gamepad
-- slots too), but never the vehicle page the game fills itself; a lower rank
-- placed on purpose stays; macros, items and flyouts are never touched, even
-- with the same number; talent spells and spells without ranks are left
-- alone. In a fight nothing is picked up or placed until it ends; with the
-- cursor busy it waits until the cursor is free and never drops what you
-- hold; the spellbook isn't looked at in a fight either. Several ranks at
-- once go straight to the newest; a rank whose text loads late still
-- counts; one you knew already (at login, or when the option was switched
-- on, or back after a respec) never moves anything. A slot read back as
-- anything but the new rank is put back, that spell stays on the rest of
-- the bars and the other spells still move. A game button whose slot key
-- the move leaves tainted asks for a /reload, once. Off: nothing. Secret
-- values are never used. No key is written on the game's frames and no
-- global is made.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Mock widgets --------------------------------------------------------------
-- Each frame's state lives beside it (S), never on it, so a key written on
-- one of the game's frames shows up in writes as "Name.key".
local S = setmetatable({}, { __mode = "k" })
local writes = {}
local frames = {}
local Proto = {}
local function New(kind, name, game)
    local obj = {}
    S[obj] = { kind = kind, name = name, game = game, events = {}, scripts = {} }
    return setmetatable(obj, {
        __index = function(_, key) return Proto[key] end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
function Proto:RegisterEvent(event) S[self].events[event] = true end
function Proto:UnregisterEvent(event) S[self].events[event] = nil end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
local function Noop() end

-- The game -------------------------------------------------------------------
local combat, targeting = false, false
InCombatLockdown = function() return combat end
SpellIsTargeting = function() return targeting end
-- Secret values: a value in secretValues, or anything the game hands back
-- while secretNow is set (one slot's read).
local secretValues, secretNow = {}, false
issecretvalue = function(v) return secretNow or (v ~= nil and secretValues[v] == true) end
CreateFrame = function(kind, name)
    local f = New(kind, name, false)
    frames[#frames + 1] = f
    return f
end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
-- Runs every waiting timer, and the ones they start, a few rounds deep.
local function Run(rounds)
    for _ = 1, rounds or 3 do
        local now = timers
        timers = {}
        for _, fn in ipairs(now) do fn() end
    end
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if S[f].events[event] and S[f].scripts.OnEvent then S[f].scripts.OnEvent(f, event, ...) end
    end
end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

-- The spellbook: skill lines in order, each a list of entries. The class
-- line has the spells; an off-spec line and a hidden line hold ranks the
-- game's own page doesn't show, which must never count.
Enum = { SpellBookSpellBank = { Player = 0, Pet = 1 }, SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 } }
local SPELL, FUTURE, FLYOUT = 1, 2, 4
local book = {
    { name = "General", items = { { id = 6603, name = "Attack", sub = "" } } },
    { name = "Frost", items = {} },
    { name = "Other spec", offSpecID = 64, items = { { id = 99001, name = "Frostbolt", sub = "Rank 11" } } },
    { name = "Hidden", shouldHide = true, items = { { id = 99002, name = "Lesser Heal", sub = "Rank 9" } } },
}
local function Flat()
    local list = {}
    for _, line in ipairs(book) do for _, item in ipairs(line.items) do list[#list + 1] = item end end
    return list
end
local function Find(id)
    for _, item in ipairs(Flat()) do if item.id == id then return item end end
end
local bookReads = 0
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return #book end,
    GetSpellBookSkillLineInfo = function(i)
        local offset = 0
        for j = 1, i - 1 do offset = offset + #book[j].items end
        local line = book[i]
        return { name = line.name, iconID = 1, itemIndexOffset = offset, numSpellBookItems = #line.items,
            isGuild = false, shouldHide = line.shouldHide == true, offSpecID = line.offSpecID }
    end,
    GetSpellBookItemInfo = function(slot, bank)
        assert(bank == 0, "the player's spellbook only")
        bookReads = bookReads + 1
        local item = Flat()[slot]
        if not item then return nil end
        return { actionID = item.id, spellID = item.id, itemType = item.kind or SPELL, name = item.name, subName = item.sub or "",
            iconID = 1, isPassive = item.passive == true, isOffSpec = false }
    end,
    IsClassTalentSpellBookItem = function(slot) return Flat()[slot].talent == true end,
    IsPvPTalentSpellBookItem = function() return false end,
}
local function Teach(id, name, sub, extra)
    local item = { id = id, name = name, sub = sub }
    for k, v in pairs(extra or {}) do item[k] = v end
    table.insert(book[2].items, item)
    return item
end
local function Forget(id)
    for i, item in ipairs(book[2].items) do if item.id == id then table.remove(book[2].items, i); return end end
end

-- Action slots, the cursor, and every call that changes them.
NUM_ACTIONBAR_BUTTONS = 12
MULTIBAR_7_ACTIONBAR_PAGE = 15
C_ActionBar = { GetVehicleBarIndex = function() return 12 end, GetOverrideBarIndex = function() return 18 end,
    GetTempShapeshiftBarIndex = function() return 17 end }
C_GamepadUI = { GetFirstGamepadActionStorageSlotIndex = function() return 301 end,
    IsValidGamepadActionStorageSlotIndex = function(slot) return slot >= 301 and slot <= 340 end }
local actions, cursor = {}, nil
local calls = { pickup = 0, place = 0, clear = 0, combat = 0, global = 0 }
local secretSlot
GetActionInfo = function(slot)
    secretNow = false
    local a = actions[slot]
    if slot == secretSlot then secretNow = true end
    if a then return a[1], a[2], a[3] end
end
GetCursorInfo = function()
    secretNow = false
    if not cursor then return nil end
    if cursor[1] == "spell" then return "spell", 7, "spell", cursor[2] end
    return cursor[1], cursor[2]
end
-- A spell picks up when it's in the spellbook (pickupAs: the client hands
-- back another spell than the one asked for).
local pickupAs = {}
local function Pick(id)
    calls.pickup = calls.pickup + 1
    if combat then calls.combat = calls.combat + 1 end
    local item = Find(id)
    if item and (item.kind or SPELL) == SPELL then cursor = { "spell", pickupAs[id] or id } end
end
C_Spell = { PickupSpell = Pick }
PickupSpell = function(id) calls.global = calls.global + 1; Pick(id) end
-- The game's buttons' slot key: secure unless taintedKeys says otherwise.
-- slotEventTaints plays a client that fires ACTIONBAR_SLOT_CHANGED inside
-- PlaceAction, so the game's button showing that slot redraws in the
-- caller's tainted run and its key turns tainted.
local taintedKeys = setmetatable({}, { __mode = "k" })
local slotEventTaints = false
issecurevariable = function(t, key)
    if key == "action" and taintedKeys[t] then return false, "EraUI" end
    return true
end
PlaceAction = function(slot)
    calls.place = calls.place + 1
    if combat then calls.combat = calls.combat + 1 end
    if not cursor then return end
    local before = actions[slot]
    actions[slot] = cursor
    cursor = before
    if slotEventTaints then
        for _, button in ipairs(rawget(ActionBarButtonEventsFrame, "frames")) do
            if rawget(button, "action") == slot then taintedKeys[button] = true end
        end
    end
end
ClearCursor = function()
    calls.clear = calls.clear + 1
    if combat then calls.combat = calls.combat + 1 end
    cursor = nil
end

-- The game's own action buttons (slot i on button i), listed on the game's
-- events frame, all watched for keys written on them.
ActionBarButtonEventsFrame = New("Frame", "ActionBarButtonEventsFrame", true)
rawset(ActionBarButtonEventsFrame, "frames", {})
for i = 1, 12 do
    local button = New("CheckButton", "ActionButton" .. i, true)
    rawset(button, "action", i)
    _G["ActionButton" .. i] = button
    table.insert(rawget(ActionBarButtonEventsFrame, "frames"), button)
end
local before = {}
for key in pairs(_G) do before[key] = true end

-- EraUI ----------------------------------------------------------------------
local settings = { enabled = true, upgradeSpellRanks = true }
local printed = {}
local E
local function Session()
    frames = {}
    E = { modules = {} }
    function E:GetSetting(key) return settings[key] end
    function E:Print(message) printed[#printed + 1] = message end
    function E:RegisterModule(name, module) self.modules[name] = module end
    assert(loadfile("Modules/SpellRanks.lua"))("EraUI", E)
    local module = E.modules.SpellRanks
    module:Initialize()
    return module
end
local function Last() return printed[#printed] end
local function Bars(list)
    local out = {}
    for i, slot in ipairs(list) do
        local a = actions[slot]
        out[i] = slot .. "=" .. (a and (a[1] .. ":" .. tostring(a[2])) or "empty")
    end
    return table.concat(out, " ")
end
local function Learn(id, name, sub, extra)
    Teach(id, name, sub, extra)
    Fire("LEARNED_SPELL_IN_SKILL_LINE", id, 2, false)
    Fire("SPELLS_CHANGED")
    Run()
end
local function Calls() return calls.pickup .. "/" .. calls.place .. "/" .. calls.clear end

-- Frostbolt: ranks 1 to 7. Lesser Heal: 1 to 5. Fireball: 1 to 3.
local FB = { 116, 205, 837, 7322, 8406, 8407, 10181, 10182 }
local LH = { 2050, 2052, 2053, 2054, 2055 }
local FIRE = { 133, 143, 145 }
Teach(FB[1], "Frostbolt", "Rank 1"); Teach(FB[2], "Frostbolt", "Rank 2")
Teach(LH[1], "Lesser Heal", "Rank 1"); Teach(LH[2], "Lesser Heal", "Rank 2")
Teach(FIRE[1], "Fireball", "Rank 1")
Teach(11426, "Ice Barrier", "Rank 1", { talent = true })
Teach(1953, "Blink", "")
Teach(12494, "Frostbite", "Rank 1", { passive = true })
Teach(30000, "Frost Ward", "Rank 3", { kind = FUTURE })
-- What's on the bars: the main Frostbolt (Rank 2) on every kind of page, a
-- Rank 1 kept on purpose, a macro, an item and a flyout with Rank 2's own
-- number, Fireball, a talent, a spell without ranks.
actions = {
    [1] = { "spell", FB[2] }, [2] = { "spell", FB[1] }, [3] = { "macro", FB[2] }, [4] = { "item", FB[2] },
    [5] = { "spell", FIRE[1] }, [6] = { "spell", 11426 }, [7] = { "spell", 1953 }, [8] = { "flyout", FB[2] },
    [10] = { "spell", LH[2] }, [11] = { "spell", LH[2] }, [12] = { "spell", LH[1] },
    [30] = { "spell", FB[2] }, [140] = { "spell", FB[2] }, [150] = { "spell", FB[2] }, [180] = { "spell", FB[2] },
    [181] = { "spell", FB[2] }, [301] = { "spell", FB[2] }, [341] = { "spell", FB[2] },
}
local WATCH = { 1, 2, 3, 4, 8, 30, 140, 150, 180, 181, 301, 341 }

-- Login: the starting point. What you know stays where you put it.
local R = Session()
Fire("PLAYER_ENTERING_WORLD"); Fire("SPELLS_CHANGED"); Run()
equal(Calls() .. " " .. #printed, "0/0/0 0", "login: nothing picked up, placed or said")
equal(Bars(WATCH), "1=spell:205 2=spell:116 3=macro:205 4=item:205 8=flyout:205 30=spell:205 140=spell:205 150=spell:205 180=spell:205 181=spell:205 301=spell:205 341=spell:205",
    "login: the bars as they were")

-- Frostbolt Rank 3: every slot with Rank 2 the player fills moves up.
Learn(FB[3], "Frostbolt", "Rank 3")
equal(Bars(WATCH), "1=spell:837 2=spell:116 3=macro:205 4=item:205 8=flyout:205 30=spell:837 140=spell:205 150=spell:837 180=spell:837 181=spell:205 301=spell:837 341=spell:205",
    "Rank 3: Rank 2 moved up on pages 1, 3, 13 and 15 and the gamepad bar; the kept Rank 1, the macro, item and flyout, the vehicle page and the slots past the last stay")
equal(Calls() .. " " .. tostring(cursor), "5/5/5 nil", "one pick-up, one place and one clear a button; the cursor ends empty")
equal(Last(), "Frostbolt moved up to Rank 3 on 5 buttons.", "one quiet line: the spell, its rank and how many buttons")
equal(calls.global, 0, "the game's C_Spell.PickupSpell, not the old global")
equal(Bars({ 5, 6, 7, 10, 11, 12 }), "5=spell:133 6=spell:11426 7=spell:1953 10=spell:2052 11=spell:2052 12=spell:2050", "every other spell left alone")

-- In a fight: nothing until it ends, then Rank 3 goes straight to Rank 5
-- (two ranks learned in the fight). The spellbook isn't even looked at in
-- the fight (the game says SPELLS_CHANGED often there: forms, auras).
combat = true
local said = #printed
local reads = bookReads
Learn(FB[4], "Frostbolt", "Rank 4")
Learn(FB[5], "Frostbolt", "Rank 5")
Fire("SPELLS_CHANGED"); Run()
Fire("PLAYER_REGEN_ENABLED") -- (a stray one in the fight changes nothing)
equal(calls.combat .. " " .. Calls() .. " " .. #printed .. " " .. (bookReads - reads), "0 5/5/5 " .. said .. " 0",
    "in a fight: nothing picked up, placed, cleared or said, and no look at the spellbook")
equal(Bars({ 1, 2, 30 }), "1=spell:837 2=spell:116 30=spell:837", "the bars wait")
combat = false
Fire("PLAYER_REGEN_ENABLED")
equal(bookReads > reads, true, "the fight over: one look, then the bars")
equal(Bars(WATCH), "1=spell:8406 2=spell:116 3=macro:205 4=item:205 8=flyout:205 30=spell:8406 140=spell:205 150=spell:8406 180=spell:8406 181=spell:205 301=spell:8406 341=spell:205",
    "the fight over: Rank 3 straight to Rank 5, the rest as before")
equal(Last(), "Frostbolt moved up to Rank 5 on 5 buttons.", "and says so once")

-- The cursor busy: it waits, never dropping what you hold.
local function Held() return cursor and (cursor[1] .. ":" .. tostring(cursor[2])) or "empty" end
cursor = { "item", 6948 }
Learn(FB[6], "Frostbolt", "Rank 6")
equal(Bars({ 1 }) .. " " .. Held() .. " " .. #timers, "1=spell:8406 item:6948 1", "an item on the cursor: nothing moves, the item stays held, a look again booked")
Run(1)
equal(Bars({ 1 }) .. " " .. Held() .. " " .. #timers, "1=spell:8406 item:6948 1", "still held a second later: still waiting")
cursor = nil; targeting = true
Run(1)
equal(Bars({ 1 }) .. " " .. #timers, "1=spell:8406 1", "a spell waiting for its target: still waiting")
targeting = false
Run(1)
equal(Bars({ 1, 2, 30, 301 }) .. " " .. tostring(cursor) .. " " .. #timers, "1=spell:8407 2=spell:116 30=spell:8407 301=spell:8407 nil 0",
    "the cursor free: Rank 5 to Rank 6, and no more waiting")

-- Two ranks at once (a trainer's Train All): Lesser Heal Rank 2 straight to
-- Rank 4, the Rank 1 kept on purpose stays.
Teach(LH[3], "Lesser Heal", "Rank 3"); Teach(LH[4], "Lesser Heal", "Rank 4")
Fire("LEARNED_SPELL_IN_SKILL_LINE", LH[3], 2, false); Fire("LEARNED_SPELL_IN_SKILL_LINE", LH[4], 2, false)
Fire("SPELLS_CHANGED"); Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 10, 11, 12 }), "10=spell:2054 11=spell:2054 12=spell:2050", "Train All: Rank 2 to Rank 4 in one go, Rank 1 kept")
equal(Last(), "Lesser Heal moved up to Rank 4 on 2 buttons.", "one line for it")

-- Two spells at once: one line naming both, in the order of the bars.
Teach(FIRE[2], "Fireball", "Rank 2"); Teach(LH[5], "Lesser Heal", "Rank 5")
Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 5, 10, 11, 12 }), "5=spell:143 10=spell:2055 11=spell:2055 12=spell:2050", "Fireball and Lesser Heal both up")
equal(Last(), "Moved up on your bars: Fireball to Rank 2 (1 button), Lesser Heal to Rank 5 (2 buttons).", "one line for both")

-- A talent's ranks and a spell without ranks are left alone.
local count = Calls()
Learn(13031, "Ice Barrier", "Rank 2", { talent = true })
Learn(31661, "Blink", "")
equal(Bars({ 6, 7 }) .. " " .. Calls(), "6=spell:11426 7=spell:1953 " .. count, "talent and rankless spells untouched")

-- A new rank whose text hasn't loaded yet moves up once it has, even
-- without another word from the game.
local late = Teach(FB[7], "Frostbolt", "")
Fire("LEARNED_SPELL_IN_SKILL_LINE", FB[7], 2, false); Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 1 }), "1=spell:8407", "its rank text not there yet: nothing moves")
late.sub = "Rank 7"
Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 1, 2, 30 }), "1=spell:10181 2=spell:116 30=spell:10181", "the text there: Rank 6 to Rank 7")
Forget(FB[7]); late = Teach(FB[7], "Frostbolt", "")
Fire("SPELLS_CHANGED"); Run()
late.sub = "Rank 7"
actions[1] = { "spell", FB[6] }
Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 1 }), "1=spell:8407", "and only once: a later look leaves a Rank 6 you put back")

-- A rank you knew already never moves anything when it comes back (a
-- respec, a spell the game took away a moment).
Forget(FB[7]); Fire("SPELLS_CHANGED"); Run()
Teach(FB[7], "Frostbolt", "Rank 7"); Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 1 }), "1=spell:8407", "Rank 7 back: the Rank 6 on purpose stays")

-- Secret values: a slot that reads secret is skipped, a spellbook entry
-- with a secret rank never counts.
actions[1] = { "spell", FB[7] }
actions[20] = { "spell", FB[7] }; secretSlot = 20
local secretRank = Teach(99003, "Frostbolt", "Rank 12 ")
secretValues["Rank 12 "] = true
Learn(FB[8], "Frostbolt", "Rank 8")
equal(Bars({ 1, 20 }), "1=spell:10182 20=spell:10181", "Rank 8: the slot that reads secret is left alone; the secret Rank 12 never counted")
secretSlot = nil; Forget(99003); secretValues["Rank 12 "] = nil
equal(secretRank.sub, "Rank 12 ", "(the secret entry was there all along)")

-- A slot that reads back as anything but the new rank is put back, and
-- that spell stays as it is on the rest of the bars; any other spell
-- waiting still moves up. One line names each spell that couldn't.
Teach(5143, "Arcane Missiles", "Rank 1"); actions[50] = { "spell", 5143 }
actions[60] = { "spell", FIRE[2] }
Fire("SPELLS_CHANGED"); Run()
pickupAs[FIRE[3]] = 31661; pickupAs[5144] = 31661
Teach(FIRE[3], "Fireball", "Rank 3"); Teach(2056, "Lesser Heal", "Rank 6"); Teach(5144, "Arcane Missiles", "Rank 2")
local p0, l0, c0 = calls.pickup, calls.place, calls.clear
Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 5, 10, 11, 12, 50, 60 }) .. " " .. tostring(cursor), "5=spell:143 10=spell:2056 11=spell:2056 12=spell:2050 50=spell:5143 60=spell:143 nil",
    "the client placed another spell: Fireball and Arcane Missiles put back, Lesser Heal still up, the cursor empty")
equal((calls.pickup - p0) .. "/" .. (calls.place - l0) .. "/" .. (calls.clear - c0), "6/6/6",
    "a failed slot is tried and put back once; Fireball's second button isn't tried at all")
equal(printed[#printed - 1], "Lesser Heal moved up to Rank 6 on 2 buttons.", "the spell that moved says so")
equal(Last(), "Fireball and Arcane Missiles couldn't move up on some of your buttons, so they're left as they were.", "and one line names both that couldn't")
pickupAs[FIRE[3]] = nil; pickupAs[5144] = nil

-- The old global when the client has no C_Spell.PickupSpell.
C_Spell = nil
Learn(10183, "Frostbolt", "Rank 9")
equal(Bars({ 1, 30, 301 }) .. " " .. calls.global, "1=spell:10183 30=spell:10183 301=spell:10183 5", "PickupSpell when C_Spell has none, once a button")
C_Spell = { PickupSpell = Pick }

-- Switched off while waiting for a fight to end: nothing happens after it.
combat = true
Learn(10184, "Frostbolt", "Rank 10")
settings.upgradeSpellRanks = false; R:Refresh()
combat = false
count = Calls()
Fire("PLAYER_REGEN_ENABLED"); Run()
equal(Bars({ 1 }) .. " " .. Calls(), "1=spell:10183 " .. count, "switched off in the fight: the old rank stays after it")

-- Off: learning changes nothing.
said = #printed
Learn(10185, "Frostbolt", "Rank 11")
equal(Bars({ 1, 30 }) .. " " .. Calls() .. " " .. #printed, "1=spell:10183 30=spell:10183 " .. count .. " " .. said, "off: nothing moves, nothing said")

-- Switched on again: a fresh starting point, so ranks learned while it was
-- off stay where they are; the next one learned moves the highest up.
actions[30] = { "spell", 10185 }
settings.upgradeSpellRanks = true; R:Refresh()
equal(Bars({ 1, 30 }) .. " " .. Calls(), "1=spell:10183 30=spell:10185 " .. count, "switched on: nothing moves")
Learn(10186, "Frostbolt", "Rank 12")
equal(Bars({ 1, 30 }), "1=spell:10183 30=spell:10186", "the next rank: only the highest (Rank 11) moves up, Rank 9 stays")

-- A new session whose spellbook arrives late: the starting point waits for
-- it, then nothing moves for what was known.
local savedBook = book
book = { { name = "General", items = {} } }
actions[40] = { "spell", 2050 }
R = Session()
Run()
book = savedBook
Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 40 }), "40=spell:2050", "spellbook late at login: Lesser Heal Rank 1 stays (Rank 5 was known)")
-- A rank's text late at login: known at the start, so it never moves anything.
Teach(20001, "Frost Nova", "Rank 1"); local nova = Teach(20002, "Frost Nova", "")
actions[41] = { "spell", 20001 }
R:Refresh()
nova.sub = "Rank 2"
Fire("SPELLS_CHANGED"); Run()
equal(Bars({ 41 }), "41=spell:20001", "a rank whose text loads after the start is not new")

-- A client that redraws its own buttons inside EraUI's call leaves their
-- slot key tainted for a fight: one line asks for a /reload, once a session.
-- No line before then: every pass above left the buttons secure.
for _, message in ipairs(printed) do
    equal(message:find("/reload", 1, true), nil, "no /reload line while the buttons stay secure (" .. message .. ")")
end
-- A button tainted before the move (another addon's doing) never counts.
slotEventTaints = true
taintedKeys[ActionButton2] = true
actions[2] = { "spell", 20002 }
said = #printed
Learn(20003, "Frost Nova", "Rank 3")
equal(Bars({ 2 }) .. " " .. (#printed - said) .. " " .. Last(), "2=spell:20003 1 Frost Nova moved up to Rank 3 on 1 button.",
    "a button already tainted before the move: no /reload line")
-- A secure one tainted by the move: the line.
actions[9] = { "spell", 20003 }
Learn(20004, "Frost Nova", "Rank 4")
equal(Bars({ 2, 9 }) .. " " .. printed[#printed - 1], "2=spell:20004 9=spell:20004 Frost Nova moved up to Rank 4 on 2 buttons.", "both moved up")
equal(Last(), "Please /reload before your next fight: the game's action buttons didn't take the rank change cleanly.",
    "a secure button left tainted by the move: the /reload line")
-- Another one later in the session: no second line.
actions[12] = { "spell", 20004 }
said = #printed
Learn(20005, "Frost Nova", "Rank 5")
equal(Bars({ 2, 9, 12 }) .. " " .. (#printed - said) .. " " .. Last(), "2=spell:20005 9=spell:20005 12=spell:20005 1 Frost Nova moved up to Rank 5 on 3 buttons.",
    "and only once a session")
slotEventTaints = false

-- Nothing written on the game's frames, no global made.
equal(#writes, 0, "no key written on the game's frames (" .. table.concat(writes, ", ") .. ")")
local made = {}
for key in pairs(_G) do if not before[key] then made[#made + 1] = key end end
table.sort(made)
equal(table.concat(made, ","), "", "no global made")
equal(bookReads > 0, true, "the spellbook was read")
print("Spell rank checks passed: " .. checks .. " assertions.")
