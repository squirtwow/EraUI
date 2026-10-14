-- Stat Tracker (Modules/StatTracker.lua; /era: Character & Spells, the rows
-- in Tools/TestSettingsLayout.lua) against a mock of the game's stat
-- functions, events and frames. Off by default: no panel, no events. On:
-- EraUI's own panel, sized at once, movable, clamped to the screen, with the
-- approved eight stats in /era's order, read from the functions Forever's
-- character window uses and written 1,204 / 9.4% / 100%. A stat that goes up
-- turns green with how much for five seconds (added up, taken off when it
-- drops); nothing green the first time, after a tick or the switch comes
-- back, or with Gains in Green off. Events are yours only and read at most
-- five times a second. Secret numbers (Forever's restricted stats) are never
-- compared or added up: the stat keeps its number. Speed in water (and in a
-- leap out of it, until you land) keeps the run speed (Forever most likely
-- gives the swim speed in its place) and is read again once you're out.
-- List or One line (short names: Stam, Spirit, Spell Crit, Dura; the room
-- for a line; Stats per Line's grid of rows under each other, All by
-- default, the screen's room still counting), the title, the three Show It
-- choices, the /era preview (shown
-- where it is, on its own HIGH layer, never moved or raised by /era), the
-- first-time spots (a list at the right of the screen, one line at the top
-- centre, clear of /era; a saved spot always wins), the drag and its saved
-- place, Panel Size (50% to 150%, the same spot on screen at any size),
-- Classic and Dark Mode looks, Stat Name Colour (Match look, Gold, Class with
-- custom class colours first, White, Custom). No key is ever written on the
-- game's frames, and the game's tooltip, hooks and bindings are never used.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack

-- Secret numbers: tables the game calls numbers. Any sum or comparison on
-- one is an error here, as it is in the game.
local secrets = setmetatable({}, { __mode = "k" })
local realType = type
type = function(v) if secrets[v] then return "number" end return realType(v) end
local function Secret() local s = {}; secrets[s] = true; return s end
issecretvalue = function(v) return v ~= nil and secrets[v] == true end

-- Mock widgets ------------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's frames shows up in writes as "Name.key".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes, frames = {}, {}
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear" }
local function Verb(key)
    if realType(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local function Noop() end
local function New(kind, name, parent, game)
    local obj = {}
    S[obj] = { kind = kind, name = name, parent = parent, game = game, points = {}, scripts = {}, hooks = {}, shown = true,
        level = 1, strata = "MEDIUM", events = {}, units = {}, text = "" }
    frames[#frames + 1] = obj
    return setmetatable(obj, {
        __index = function(_, key) return Proto[key] or (Verb(key) and Noop) or nil end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
function Proto:GetName() return S[self].name end
function Proto:GetParent() return S[self].parent end
function Proto:SetSize(w, h) S[self].w, S[self].h = w, h end
function Proto:SetWidth(w) S[self].w = w end
function Proto:SetHeight(h) S[self].h = h end
function Proto:GetWidth() return S[self].w end
function Proto:GetHeight() return S[self].h end
function Proto:IsShown() return S[self].shown end
function Proto:Show() S[self].shown = true; for _, fn in ipairs(S[self].hooks.OnShow or {}) do fn(self) end end
function Proto:Hide()
    S[self].shown = false
    if S[self].scripts.OnHide then S[self].scripts.OnHide(self) end
    for _, fn in ipairs(S[self].hooks.OnHide or {}) do fn(self) end
end
function Proto:SetShown(v) if v then self:Show() else self:Hide() end end
function Proto:SetFrameStrata(v) S[self].strata = v end
function Proto:GetFrameStrata() return S[self].strata end
function Proto:SetScale(v) S[self].scale = v end
function Proto:GetScale() return S[self].scale or 1 end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:GetFrameLevel() return S[self].level end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(...) table.insert(S[self].points, { ... }) end
function Proto:GetPoint(i) local p = S[self].points[i or 1]; if p then return unpack(p, 1, 5) end end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
function Proto:HookScript(name, fn) S[self].hooks[name] = S[self].hooks[name] or {}; table.insert(S[self].hooks[name], fn) end
function Proto:CreateTexture(_, layer, _, sublevel)
    local t = New("Texture", nil, self, false)
    S[t].layer, S[t].sublevel = layer, sublevel
    return t
end
function Proto:CreateFontString() return New("FontString", nil, self, false) end
function Proto:SetColorTexture(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:SetText(text) S[self].text = text end
function Proto:GetText() return S[self].text end
function Proto:SetTextColor(r, g, b) S[self].textColour = { r, g, b } end
function Proto:SetFont(file, size) S[self].font, S[self].size = file, size; return true end
function Proto:GetStringWidth() return #(S[self].text or "") * 7 end
function Proto:RegisterEvent(event) S[self].events[event] = true end
function Proto:RegisterUnitEvent(event, unit) S[self].events[event] = true; S[self].units[event] = unit end
function Proto:UnregisterAllEvents() S[self].events, S[self].units = {}, {}; S[self].unregistered = (S[self].unregistered or 0) + 1 end
function Proto:SetClampedToScreen(v) S[self].clamped = v end
function Proto:SetMovable(v) S[self].movable = v end
function Proto:EnableMouse(v) S[self].mouse = v end
function Proto:RegisterForDrag(...) S[self].drag = table.concat({ ... }, ",") end
-- As in the client: a frame you drag is marked moved by you (its place then
-- kept by the game's layout cache) unless told not to save it.
function Proto:StartMoving() S[self].moving = (S[self].moving or 0) + 1; S[self].userPlaced = true end
function Proto:SetUserPlaced(v) S[self].userPlaced = v end
function Proto:SetDontSavePosition(v) S[self].dontSave = v end
function Proto:StopMovingOrSizing() S[self].stopped = (S[self].stopped or 0) + 1 end
function Proto:GetLeft() return S[self].left end
function Proto:GetTop() return S[self].top end

-- The game -------------------------------------------------------------------
local now, combat = 100, false
GetTime = function() return now end
InCombatLockdown = function() return combat end
local timers = {}
C_Timer = { After = function(delay, fn) timers[#timers + 1] = { at = now + delay, fn = fn } end }
-- Moves the clock on, running each timer due on the way at its own time.
local function Wait(seconds)
    local target = now + (seconds or 0)
    for _ = 1, 200 do
        local due
        for i, t in ipairs(timers) do if t.at <= target + 1e-9 and (not due or t.at < timers[due].at) then due = i end end
        if not due then now = target; return end
        local t = table.remove(timers, due)
        if t.at > now then now = t.at end
        t.fn()
    end
    error("timers did not settle")
end
local function Pending() return #timers end
CreateFrame = function(kind, name, parent)
    local f = New(kind, name, parent, false)
    if name then _G[name] = f end
    return f
end
UIParent = New("Frame", "UIParent", nil, true)
S[UIParent].h = 768
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
BreakUpLargeNumbers = function(v)
    local text = tostring(v):gsub("%.0$", "")
    local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end
-- The game's tooltip, hooks and bindings: never used.
local forbidden = {}
GameTooltip = setmetatable({}, { __index = function(_, key) forbidden[#forbidden + 1] = "GameTooltip." .. tostring(key); return Noop end })
hooksecurefunc = function() forbidden[#forbidden + 1] = "hooksecurefunc" end
SetOverrideBinding = function() forbidden[#forbidden + 1] = "SetOverrideBinding" end

-- Your character: a level 30 rogue, as in the mockup.
local game
local function Character()
    game = {
        stat = { 58, 112, 89, 31, 44 },
        melee = { 300, 86, 0 }, ranged = { 140, 0, 0 },
        crit = 9.4, rangedCrit = 7.1, spellCrit = 2.1,
        hit = 3, rangedHit = 1, spellHit = 3, bonus = { [6] = 0, [7] = 0, [8] = .4 },
        schools = { [2] = 10, [3] = 25, [4] = 0, [5] = 0, [6] = 18, [7] = 0 },
        armor = 1204, dodge = 10.8, parry = 5, block = 0, run = 7, swim = 4.72, swimming = false, falling = false, leaping = false,
        gear = { [1] = { 100, 100 }, [5] = { 80, 100 }, [16] = { 162, 200 } },
        class = "ROGUE",
    }
end
Character()
local reads = 0
UnitStat = function(unit, index)
    assert(unit == "player", "your stats only")
    reads = reads + 1
    local v = game.stat[index]
    return 0, v, 0, 0
end
UnitAttackPower = function() return game.melee[1], game.melee[2], game.melee[3] end
UnitRangedAttackPower = function() return game.ranged[1], game.ranged[2], game.ranged[3] end
GetCritChance = function() return game.crit end
GetRangedCritChance = function() return game.rangedCrit end
GetSpellCritChance = function(school) assert(school == nil, "Forever's window asks without a school"); return game.spellCrit end
CR_HIT_MELEE, CR_HIT_RANGED, CR_HIT_SPELL = 6, 7, 8
GetCombatRatingBonus = function(rating) return game.bonus[rating] end
GetHitModifier = function() return game.hit end
GetRangedHitModifier = function() return game.rangedHit end
GetSpellHitModifier = function() return game.spellHit end
MAX_SPELL_SCHOOLS = 7
GetSpellBonusDamage = function(school) return game.schools[school] end
UnitArmor = function() return 1000, game.armor, game.armor, 0 end
GetDodgeChance = function() return game.dodge end
GetParryChance = function() return game.parry end
GetBlockChance = function() return game.block end
BASE_MOVEMENT_SPEED = 7
-- As seen in game: in water Forever's second number is (most likely) the
-- swim speed; leaping says it still is in a leap out of the water, which
-- Forever's character window allows for while you fall after a swim.
GetUnitSpeed = function() return 0, (game.swimming or game.leaping) and game.swim or game.run, 7, game.swim end
IsSwimming = function() return game.swimming end
IsFalling = function() return game.falling end
UnitClass = function(unit) assert(unit == "player", "your class only"); return "Class", game.class end
-- A paladin's own entry differs here, so EraUI's pink is seen to win.
RAID_CLASS_COLORS = { ROGUE = { r = 1, g = .96, b = .41 }, PALADIN = { r = .5, g = .5, b = .5 } }
GetInventoryItemDurability = function(slot)
    local item = game.gear[slot]
    if item then return item[1], item[2] end
end

-- EraUI: the real defaults (Core/Init.lua), its settings and its own /era window.
local real = {}
local era = _G.EraUI
assert(loadfile("Core/Init.lua"))("EraUI", real)
_G.EraUI = era
local settings, saves = {}, 0
for key, value in pairs(real.settingDefaults) do settings[key] = value end
local grey = { .42, .44, .48 }
local E = { modules = {}, Classic = { DarkGrey = function() return grey[1], grey[2], grey[3] end } }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return settings[key] end
function E:SetSetting(key, value) settings[key] = value end
function E:SaveSettings() saves = saves + 1 end
assert(loadfile("Modules/StatTracker.lua"))("EraUI", E)
local Module = E.modules.StatTracker
local panel

-- Helpers ------------------------------------------------------------------------
-- The Stat Tracker's event frame (Core/Init.lua made one of its own above).
local mark = #frames
local function Events()
    for i = mark + 1, #frames do if S[frames[i]].scripts.OnEvent then return frames[i] end end
end
local function Fire(event, unit)
    local f = Events()
    assert(S[f].events[event], event .. " registered")
    S[f].scripts.OnEvent(f, event, unit)
end
local function Shown() return panel ~= nil and S[panel].shown end
-- The texts on show, top to bottom then left to right: "Name value [gain]".
local function Fonts()
    local out = {}
    for _, f in ipairs(frames) do
        local s = S[f]
        if s.kind == "FontString" and s.parent == panel and s.shown and s.points[1] then out[#out + 1] = f end
    end
    table.sort(out, function(a, b)
        local pa, pb = S[a].points[1], S[b].points[1]
        if pa[5] ~= pb[5] then
            if math.abs(pa[5] - pb[5]) > 3 then return pa[5] > pb[5] end
        end
        return pa[4] < pb[4]
    end)
    return out
end
local function Lines()
    local out, line, y = {}, nil, nil
    for _, f in ipairs(Fonts()) do
        local p = S[f].points[1]
        if S[f].text ~= "Stats" then
            if y == nil or math.abs(p[5] - y) > 3 then line = {}; out[#out + 1] = line; y = p[5] end
            line[#line + 1] = S[f].text
        end
    end
    for i, l in ipairs(out) do out[i] = table.concat(l, " ") end
    return table.concat(out, " | ")
end
local function Find(text)
    for _, f in ipairs(Fonts()) do if S[f].text == text then return f end end
end
local function Colour(c) return c and string.format("%.3f,%.3f,%.3f", c[1], c[2], c[3]) or "nil" end
-- A number as it reads ("812", "333.333"), whole or not.
local function G(v) return realType(v) == "number" and string.format("%.6g", v) or tostring(v) end
local function Turn(key, value) settings[key] = value; Module:Refresh() end
local function Tick(list) for _, stat in ipairs(Module.STATS) do settings["statTracker" .. stat.id] = list[stat.id] == true end; Module:Refresh() end

-- Off by default: nothing made, nothing watched --------------------------------
equal(settings.statTracker, false, "off by default")
Module:Initialize()
equal(_G.EraUIStatTracker, nil, "off: no panel made")
local events = Events()
local registered = 0
for _ in pairs(S[events].events) do registered = registered + 1 end
equal(registered, 0, "off: no events watched")

-- On: the approved eight, in /era's order -------------------------------------
Turn("statTracker", true)
panel = _G.EraUIStatTracker
local s = S[panel]
equal(panel ~= nil and s.parent == UIParent and Shown(), true, "on: EraUI's own panel on the screen, shown")
equal(s.w > 0 and s.h > 0, true, "sized")
equal(tostring(s.clamped) .. " " .. tostring(s.movable) .. " " .. tostring(s.mouse) .. " " .. tostring(s.drag) .. " " .. s.strata .. " " .. G(s.scale),
    "true true true LeftButton HIGH 1", "clamped to the screen, movable, dragged with the left button, over the game's windows (HIGH), its own size")
-- Where it's held: "POINT to RELATIVE x y" (+n for any more points).
local function Point()
    local p = s.points[1]
    local to = p[2] == UIParent and "UIParent" or tostring(p[2])
    return table.concat({ p[1], to, p[3], G(p[4]), G(p[5]) }, " ") .. (#s.points == 1 and "" or " +" .. (#s.points - 1))
end
equal(Point(), "TOPRIGHT UIParent RIGHT -96 120",
    "first time: on its own at the right of the screen, a little above the middle, clear of the side bars and the minimap")
equal(Lines(), "Agility 112 | Stamina 89 | Attack Power 386 | Crit 9.4% | Hit 3.4% | Armor 1,204 | Dodge 10.8% | Speed 100%",
    "the approved eight: names and numbers, as written")
local title = Find("Stats")
equal(title ~= nil and S[title].font .. " " .. S[title].size .. " " .. Colour(S[title].textColour), "Fonts\\MORPHEUS.TTF 16 1.000,0.820,0.000",
    "the Stats title, gold in the Classic look")
equal(Colour(S[Find("Agility")].textColour) .. " " .. Colour(S[Find("112")].textColour), "1.000,0.820,0.000 1.000,1.000,1.000", "gold names, white numbers")
-- Names at the left, numbers at the right, a line each.
local agility, number, stamina = S[Find("Agility")], S[Find("112")], S[Find("Stamina")]
equal(agility.points[1][4] .. " " .. (number.points[1][4] + #"112" * 7) .. " " .. (s.w - 14), "14 " .. (s.w - 14) .. " " .. (s.w - 14), "names 14 in, numbers 14 from the right edge")
equal(agility.points[1][5] - stamina.points[1][5], 20, "a line every 20")
equal(s.w >= 180, true, "at least 180 wide")
-- Every event: yours only.
for _, event in ipairs({ "UNIT_STATS", "UNIT_AURA", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_RESISTANCES" }) do
    equal(S[events].events[event] and S[events].units[event], "player", event .. " watched for you only")
end
for _, event in ipairs({ "COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_DURABILITY",
    "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    equal(S[events].events[event], true, event .. " watched")
end

-- Every stat, from the functions the character window uses ---------------------
local ALL = {}
for _, stat in ipairs(Module.STATS) do ALL[stat.id] = true end
Tick(ALL)
equal(Lines(), "Strength 58 | Agility 112 | Stamina 89 | Intellect 31 | Spirit 44 | Attack Power 386 | Crit 9.4% | Hit 3.4% | Spell Power 25"
    .. " | Spell Crit 2.1% | Armor 1,204 | Dodge 10.8% | Parry 5.0% | Block 0.0% | Speed 100% | Durability 87%",
    "all sixteen: attack power and crit the higher of melee and ranged, hit the best of the three, spell power the best school, durability the average")
-- A hunter's ranged attack power and crit are higher: those show.
game.ranged, game.rangedCrit = { 420, 20, -5 }, 11.25
Fire("UNIT_RANGED_ATTACK_POWER", "player"); Wait(.2)
equal(Find("435") ~= nil and Find("11.3%") ~= nil, true, "the higher of melee and ranged: 420 + 20 - 5, and 11.25% written 11.3%")
Character()
-- Durability: nothing worn that has any is 100%; Speed: run speed, never movement.
game.gear = {}
game.run = 7 * 1.7
Fire("UPDATE_INVENTORY_DURABILITY"); Wait(.2)
equal(Find("Durability") and S[Find("100%")] and Find("170%") ~= nil, true, "no gear with durability: 100%; Sprint's run speed: 170%")
-- Spell crit for a game that wants a school: the best school's.
GetSpellCritChance = function(school) assert(school ~= nil, "a school wanted"); return school == 3 and 4.5 or 1 end
game.schools[3] = 0; game.schools[6] = 0
Fire("SPELL_POWER_CHANGED"); Wait(.2)
equal(Find("4.5%") ~= nil and Find("10") ~= nil, true, "a game wanting a school: each in turn, the best (4.5%); spell power the best school left (10)")
GetSpellCritChance = function() return game.spellCrit end
-- A function the game hasn't got: that part is left out.
local ranged = GetRangedCritChance
GetRangedCritChance = nil
game.crit = 6.2
Fire("COMBAT_RATING_UPDATE"); Wait(.2)
equal(Find("6.2%") ~= nil, true, "no ranged crit function: melee crit alone")
GetRangedCritChance = ranged
Character()
Fire("PLAYER_EQUIPMENT_CHANGED"); Wait(.2)
Tick({ Agility = true, Stamina = true, AttackPower = true, Crit = true, Hit = true, Armor = true, Dodge = true, Speed = true })
Wait(5.3)

-- Gains in green -----------------------------------------------------------------
equal(settings.statTrackerGains, true, "Gains in Green on by default")
equal(Find("+138") == nil and Colour(S[Find("386")].textColour), "1.000,1.000,1.000", "nothing green the first time")
-- Battle Shout: 138 attack power.
game.melee[2] = 86 + 138
Fire("UNIT_ATTACK_POWER", "player")
equal(Find("524"), nil, "read a moment later, not at once")
Wait(.2)
local power, gain = S[Find("524")], S[Find("+138")]
equal(Colour(power.textColour) .. " " .. Colour(gain and gain.textColour), "0.290,0.870,0.500 0.290,0.870,0.500", "gone up: green, with +138 after it")
equal(gain.size .. " " .. (gain.points[1][4] + #"+138" * 7), "11 " .. (s.w - 14), "the gain smaller, at the right edge")
equal(power.points[1][4] + #"524" * 7, gain.points[1][4] - 5, "the number just before it")
-- Mark of the Wild a moment later: 12 more, added up.
Wait(2)
game.melee[2] = game.melee[2] + 12
Fire("UNIT_ATTACK_POWER", "player"); Wait(.2)
equal(Find("+150") ~= nil and Find("536") ~= nil, true, "a second rise within the green: +150 in all")
-- Five seconds after the last rise it goes back to white.
Wait(4.7)
equal(Find("+150") ~= nil, true, "still green 4.7 seconds on")
Wait(.6)
equal(Find("+150") == nil and Colour(S[Find("536")].textColour), "1.000,1.000,1.000", "five seconds on: white, no gain")
-- A drop takes off the gain, and ends it when used up.
game.melee[2] = game.melee[2] + 100
Fire("UNIT_ATTACK_POWER", "player"); Wait(.2)
game.melee[2] = game.melee[2] - 40
Fire("UNIT_ATTACK_POWER", "player"); Wait(.2)
equal(Find("+60") ~= nil and Find("596") ~= nil, true, "up 100, down 40: +60, still green")
game.melee[2] = game.melee[2] - 80
Fire("UNIT_ATTACK_POWER", "player"); Wait(.2)
equal(Find("+60") == nil and Find("+20") == nil and Colour(S[Find("516")].textColour), "1.000,1.000,1.000", "dropped below where it was: no gain, white")
-- Tenths and percents: +0.3% crit, Sprint +70% speed.
game.crit = 9.7
game.run = 11.9
Fire("COMBAT_RATING_UPDATE"); Wait(.2)
equal(Find("+0.3%") ~= nil and Find("9.7%") ~= nil and Find("+70%") ~= nil and Find("170%") ~= nil, true, "+0.3% crit and +70% speed")
Wait(5.3)
game.crit, game.run = 9.4, 7
Fire("COMBAT_RATING_UPDATE"); Wait(.2)
equal(Find("+0.3%") == nil and Find("9.4%") ~= nil and Find("100%") ~= nil, true, "back down: no gain")
-- Gains in Green off during a gain: white at once, nothing new waiting.
game.stat[2] = 116
Fire("UNIT_STATS", "player"); Wait(.2)
equal(Find("+4") ~= nil and Colour(S[Find("116")].textColour), "0.290,0.870,0.500", "up 4: green")
local waiting = Pending()
Turn("statTrackerGains", false)
equal(Find("+4") == nil and Colour(S[Find("116")].textColour), "1.000,1.000,1.000", "Gains in Green off during a gain: white at once, no gain")
equal(Pending(), waiting, "and nothing new waiting")
-- Gains in Green off: never green.
game.stat[2] = 124
Fire("UNIT_STATS", "player"); Wait(.2)
equal(Find("+8") == nil and Colour(S[Find("124")].textColour), "1.000,1.000,1.000", "Gains in Green off: up, but white")
Turn("statTrackerGains", true)
-- A stat unticked and ticked again starts afresh: no false gain.
Tick({ Stamina = true, AttackPower = true })
game.stat[2] = 140
Tick({ Agility = true, Stamina = true, AttackPower = true })
equal(Find("140") ~= nil and Find("+20") == nil, true, "ticked again: its number, nothing green")

-- Read at most five times a second, for you only -----------------------------------
Wait(6)
reads = 0
for _ = 1, 10 do Fire("UNIT_AURA", "player") end
equal(Pending(), 1, "ten auras at once: one read waiting")
Wait(.2)
equal(reads, 2, "read once (Agility and Stamina from UnitStat)")
reads = 0
Fire("UNIT_AURA", "target"); Fire("UNIT_STATS", "party1")
equal(Pending() .. " " .. reads, "0 0", "another unit's events: nothing read")

-- Secrets: never compared or added up; the last number stays --------------------
Tick({ Agility = true, Stamina = true, AttackPower = true, Crit = true, Hit = true, Armor = true, Dodge = true, Speed = true, Durability = true })
Wait(6)
local before = Lines()
equal(before, "Agility 140 | Stamina 89 | Attack Power 516 | Crit 9.4% | Hit 3.4% | Armor 1,204 | Dodge 10.8% | Speed 100% | Durability 87%",
    "before the fight")
local real_ = { UnitStat = UnitStat, UnitAttackPower = UnitAttackPower, GetCritChance = GetCritChance, GetUnitSpeed = GetUnitSpeed,
    UnitArmor = UnitArmor, GetInventoryItemDurability = GetInventoryItemDurability, GetCombatRatingBonus = GetCombatRatingBonus,
    GetDodgeChance = GetDodgeChance }
UnitStat = function() return Secret(), Secret(), Secret(), Secret() end
-- Melee secret, ranged not: still waits, never the lower ranged number.
UnitAttackPower = function() return Secret(), 0, 0 end
GetCritChance = function() return Secret() end
game.rangedCrit = 1
GetUnitSpeed = function() return Secret(), Secret(), Secret(), Secret() end
UnitArmor = function() return Secret(), Secret(), Secret(), Secret() end
GetCombatRatingBonus = function() return Secret() end
GetDodgeChance = function() return Secret() end
GetInventoryItemDurability = function() return Secret(), 100 end
Fire("UNIT_STATS", "player"); Fire("UPDATE_INVENTORY_DURABILITY"); Wait(.2)
equal(Lines(), before, "in a fight with secret numbers, some only in part: every stat keeps its last number, nothing green")
-- Ticked during the fight, never read yet: "--" until the game says.
Tick({ Agility = true, Stamina = true, Strength = true })
equal(Lines(), "Strength -- | Agility 140 | Stamina 89", "a stat the game hasn't said yet: --")
for name, fn in pairs(real_) do _G[name] = fn end
Character()
game.stat[2], game.stat[3] = 140, 95
Fire("UNIT_STATS", "player"); Wait(.2)
equal(Lines(), "Strength 58 | Agility 140 | Stamina 95 +6", "numbers again after the fight: Strength read, Stamina green from its last number")
Wait(5.3)

-- Speed in water: the run speed kept, read again once you're out ------------------
-- Forever gives the swim speed (4.72 of 7, 67%) in the run speed's place
-- while you swim, which showed as Speed 67% in game.
Tick({ Agility = true, Speed = true })
Wait(6)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 0", "on land: 100%, nothing booked")
game.swimming = true
Fire("UNIT_AURA", "player"); Wait(.2)
equal(Lines(), "Agility 140 | Speed 100%", "swimming: Speed keeps your run speed, never the swim speed's 67%")
equal(Pending(), 1, "one look booked for when you're out")
Wait(3.5)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 1", "still swimming a while: the same, one look booked at a time")
for _ = 1, 3 do Fire("UNIT_AURA", "player"); Wait(.2) end
equal(Pending(), 1, "auras while you swim: each read, still one look booked")
-- Sprint in the water: the run speed it brings shows once you're out, with
-- no event, and as a gain; leaving the water alone is never one.
game.run = 11.9
Wait(1.2)
equal(Lines(), "Agility 140 | Speed 100%", "Sprint while swimming: still the run speed from before")
game.swimming = false
Wait(1.2)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 170% +70% 1", "out of the water: read again within a second, no event needed; only the gain's end booked")
Wait(5.3)
game.run = 7
game.swimming = true
Fire("UNIT_AURA", "player"); Wait(.2)
game.swimming = false
Wait(1.5)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 0", "a swim and back, Sprint gone in the water: 100% again and nothing booked")
-- Ticked while swimming: "--" until you're out.
Tick({ Agility = true })
game.swimming = true
Tick({ Agility = true, Speed = true })
equal(Lines(), "Agility 140 | Speed --", "ticked in the water: -- (never 67%)")
game.swimming = false
Wait(1.5)
equal(Lines(), "Agility 140 | Speed 100%", "and its number once you're out")
-- A leap out of the water: out of it but still in the air, the game still
-- giving 4.72. Still wet until you land: no 67%, no false gain.
game.swimming = true
Fire("UNIT_AURA", "player"); Wait(.2)
game.swimming, game.falling, game.leaping = false, true, true
Wait(1.2)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 1", "a leap out of the water: Speed keeps your run speed, never 67% or a gain; still looking")
Fire("UNIT_AURA", "player"); Wait(.2)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 1", "an event mid-leap: the same")
-- The game won't say whether you fall: the number kept, still looking.
local falling = IsFalling
IsFalling = function() return Secret() end
Wait(1.2)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 1", "falling a secret after a swim: Speed keeps its number, still looking")
IsFalling = falling
game.falling, game.leaping = false, false
Wait(1.2)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 0", "landed: the run speed read again, no gain, nothing booked")
-- A jump on land is no swim: the run speed as ever.
game.falling, game.run = true, 11.9
Fire("UNIT_AURA", "player"); Wait(.2)
equal(Find("170%") ~= nil, true, "a jump on land, Sprint on: 170%")
game.falling, game.run = false, 7
Fire("UNIT_AURA", "player"); Wait(5.3)
-- The game won't say whether you swim (a secret): Speed keeps its number;
-- a game without IsSwimming reads the run speed as before.
local swimming = IsSwimming
IsSwimming = function() return Secret() end
game.run = 11.9
Fire("UNIT_AURA", "player"); Wait(.2)
equal(Lines() .. " " .. Pending(), "Agility 140 | Speed 100% 0", "swimming a secret: Speed keeps its number, nothing booked")
IsSwimming = nil
Fire("UNIT_AURA", "player"); Wait(.2)
equal(Find("170%") ~= nil, true, "no IsSwimming: the run speed as before")
IsSwimming = swimming
game.run = 7
Fire("UNIT_AURA", "player"); Wait(5.3)

-- List or One line, and the title ---------------------------------------------------
Tick({ Agility = true, Stamina = true, AttackPower = true })
Turn("statTrackerTitle", false)
equal(Find("Stats") == nil and agility.points[1][5], -10, "no title: the first line at the top")
Turn("statTrackerTitle", true)
equal(Find("Stats") ~= nil and S[Find("Agility")].points[1][5], -36, "the title: 20 for it and 6 for its line, then the stats")
-- Stats per Line is at All (16) by default: One line as it always was (the
-- checks below and the narrow screen's centred lines).
equal(settings.statTrackerPerLine, 16, "Stats per Line: All by default")
Turn("statTrackerLayout", "line")
equal(Lines(), "Agi 140 Stam 95 AP 386", "one line: short names and numbers side by side, Stamina as Stam")
equal(Find("Stats"), nil, "no title on one line")
local agi, sta = S[Find("Agi")].points[1], S[Find("Stam")].points[1]
local lastNumber = S[Find("386")]
equal(agi[4] .. " " .. agi[5] .. " " .. sta[5] .. " " .. s.h .. " " .. s.w, "16 -8 -8 30 " .. (lastNumber.points[1][4] + #"386" * 7 + 16),
    "16 in, 8 down, all on one line 30 tall, as wide as its stats")
equal(sta[4] - (S[Find("140")].points[1][4] + #"140" * 7), 18, "18 between stats")
game.stat[2] = 150
Fire("UNIT_STATS", "player"); Wait(.2)
equal(Find("+10") ~= nil and S[Find("+10")].points[1][4] == S[Find("150")].points[1][4] + #"150" * 7 + 4, true, "one line: the gain just after its number")
Wait(5.3)
-- All sixteen on a narrow screen (500 wide): as many to a line as fit 20
-- clear of each side, the rest below in the same order, each line centred.
Tick(ALL)
local wide = Lines()
equal(wide:find(" | ", 1, true), nil, "a screen of unknown width: all sixteen on one line")
equal(wide, "Str 58 Agi 150 Stam 95 Int 31 Spirit 44 AP 386 Crit 9.4% Hit 3.4% SP 25 Spell Crit 2.1% Armor 1,204 Dodge 10.8% Parry 5.0%"
    .. " Block 0.0% Speed 100% Dura 87%", "every short name as players say it: Stam, Spirit, Spell Crit, Dura")
S[UIParent].w = 500
Module:Refresh()
local bars = {}
for part in (Lines() .. " | "):gmatch("(.-) | ") do bars[#bars + 1] = part end
equal(#bars > 1 and table.concat(bars, " ") == wide, true, "a narrow screen: the same stats in the same order, on " .. #bars .. " lines")
equal(s.w <= 460 and s.h == 30 + (#bars - 1) * 20, true, "no wider than the screen less 20 each side (" .. s.w .. "); 20 taller for each line below (" .. s.h .. ")")
local lefts, rights = {}, {}
for _, f in ipairs(Fonts()) do
    local p = S[f].points[1]
    local k = math.floor((-p[5] - 8) / 20 + .5)
    lefts[k] = math.min(lefts[k] or math.huge, p[4])
    rights[k] = math.max(rights[k] or 0, p[4] + #S[f].text * 7)
end
local centred = true
for k, left in pairs(lefts) do
    if rights[k] > s.w - 16 or math.abs((left - 16) - (s.w - 16 - rights[k])) > 1 then centred = false end
end
equal(centred, true, "each line centred, nothing past the panel's edge")
-- At 150% fewer fit to a line: still no wider on screen than the screen less 20 each side.
Turn("statTrackerScale", 150)
local big = {}
for part in (Lines() .. " | "):gmatch("(.-) | ") do big[#big + 1] = part end
equal(#big > #bars and table.concat(big, " ") == wide and s.w * 1.5 <= 460, true,
    "150% on the narrow screen: the same stats on " .. #big .. " lines, " .. G(s.w * 1.5) .. " wide on screen")
-- The room for a line, in the panel's own units: (screen - 40) / size, less
-- 16 each side. On a 560-wide screen at 150% that's 314.7, so a line of 316
-- (Parry to Dura) no longer fits: five lines, packed in order.
local spans, rest = {}, wide .. " "
for _, stat in ipairs(Module.STATS) do
    local value
    value, rest = rest:match("^" .. stat.short .. " (%S+) (.*)$")
    spans[#spans + 1] = { text = stat.short .. " " .. value, width = (#stat.short + #value) * 7 + 6 }
end
local function Pack(room)
    local out, width = {}, 0
    for _, span in ipairs(spans) do
        if #out > 0 and width + 18 + span.width <= room then
            out[#out] = out[#out] .. " " .. span.text; width = width + 18 + span.width
        else
            out[#out + 1] = span.text; width = span.width
        end
    end
    return table.concat(out, " | "), #out
end
S[UIParent].w = 560
Module:Refresh()
local packed, count = Pack((560 - 40) / 1.5 - 16 * 2)
equal(packed .. " (" .. count .. ")", "Str 58 Agi 150 Stam 95 Int 31 Spirit 44 | AP 386 Crit 9.4% Hit 3.4% SP 25 | Spell Crit 2.1% Armor 1,204 Dodge 10.8%"
    .. " | Parry 5.0% Block 0.0% Speed 100% | Dura 87% (5)", "room (560 - 40) / 1.5 - 32 packs the sixteen on five lines")
equal(Lines(), packed, "150% on a 560-wide screen: the panel's lines just so")
S[UIParent].w = 500
Turn("statTrackerScale", 100)
S[UIParent].w = nil
Tick({ Agility = true, Stamina = true, AttackPower = true })
Turn("statTrackerLayout", "list")
-- Nothing ticked: hidden even when on.
Tick({})
equal(Shown(), false, "nothing ticked: hidden")
Tick({ Agility = true, Stamina = true, AttackPower = true, Crit = true, Hit = true, Armor = true, Dodge = true, Speed = true })
equal(Shown(), true, "ticked again: shown")

-- Show It: always, only in a fight, only out of one, and while /era is open -------
Turn("statTrackerShow", "combat")
equal(Shown(), false, "only in a fight: hidden out of one")
Fire("PLAYER_REGEN_DISABLED")
equal(Shown(), true, "a fight starts: shown at once")
Fire("PLAYER_REGEN_ENABLED")
equal(Shown(), false, "it ends: hidden at once")
Turn("statTrackerShow", "calm")
equal(Shown(), true, "only out of a fight: shown")
Fire("PLAYER_REGEN_DISABLED")
equal(Shown(), false, "hidden in a fight")
Fire("PLAYER_REGEN_ENABLED")
Turn("statTrackerShow", "combat")
-- Switched off in a fight that ends while it's off, then on again: the fight
-- is asked again, not remembered (hidden); and the other way round.
combat = true
Fire("PLAYER_REGEN_DISABLED")
equal(Shown(), true, "only in a fight: shown in one")
Turn("statTracker", false)
combat = false
Turn("statTracker", true)
equal(Shown(), false, "off in a fight, the fight over, on again: hidden")
Turn("statTracker", false)
combat = true
Turn("statTracker", true)
equal(Shown(), true, "off out of a fight, a fight starts, on again: shown")
combat = false
Fire("PLAYER_REGEN_ENABLED")
-- /era open: shown whatever Show It says, so it can be placed, but where it
-- is and as it is: never moved beside or under /era, never raised over it.
E.settingsFrame = CreateFrame("Frame", "EraUISettingsFrame", UIParent)
S[E.settingsFrame].level = 40
E.settingsFrame:Hide()
Fire("UNIT_STATS", "player"); Wait(.2)
local level = s.level
E.settingsFrame:Show()
equal(tostring(Shown()) .. " " .. s.strata .. " " .. G(s.level) .. " " .. Point(), "true HIGH " .. G(level) .. " TOPRIGHT UIParent RIGHT -96 120",
    "/era open: shown, on its own layer and level, at its own spot")
-- One line, never dragged: its own first-time spot at the top centre (at
-- the right /era would cover most of the bar), never pinned to /era.
Turn("statTrackerLayout", "line")
equal(tostring(Shown()) .. " " .. s.strata .. " " .. Point(), "true HIGH TOP UIParent TOP 0 -14",
    "one line with /era open, never dragged: at the top centre of the screen, clear of /era")
Turn("statTrackerScale", 50)
equal(G(s.scale) .. " " .. Point(), "0.5 TOP UIParent TOP 0 -28", "one line at 50%: the same spot on the screen")
Turn("statTrackerScale", 100)
Turn("statTrackerLayout", "list")
equal(Point(), "TOPRIGHT UIParent RIGHT -96 120", "back to a list, never dragged: the list's spot again")
E.settingsFrame:Hide()
equal(tostring(Shown()) .. " " .. s.strata .. " " .. Point(), "false HIGH TOPRIGHT UIParent RIGHT -96 120", "/era closed: hidden again (only in a fight), nothing moved")
Turn("statTrackerShow", "always")
equal(Shown(), true, "always: shown")
-- Panel Size before any drag: the first-time spot stays put on the screen.
Turn("statTrackerScale", 50)
equal(G(s.scale) .. " " .. Point(), "0.5 TOPRIGHT UIParent RIGHT -192 240", "50% never dragged: half size, its offsets doubled in its own units, the same spot")
Turn("statTrackerScale", 100)
equal(G(s.scale) .. " " .. Point(), "1 TOPRIGHT UIParent RIGHT -96 120", "100% again")

-- Dragged anywhere, its place saved ---------------------------------------------
equal(Point(), "TOPRIGHT UIParent RIGHT -96 120", "first time, /era closed: its own spot")
s.scripts.OnDragStart(panel)
-- /era opening (or a stat changing) in the middle of a drag never moves it.
E.settingsFrame:Show()
Fire("UNIT_STATS", "player"); Wait(.2)
equal(Point(), "TOPRIGHT UIParent RIGHT -96 120", "mid-drag, /era opening: left where the drag has it")
Turn("statTrackerLayout", "line")
equal(Point(), "TOPRIGHT UIParent RIGHT -96 120", "mid-drag, a switch to one line: left where the drag has it")
Turn("statTrackerLayout", "list")
s.left, s.top = 812.4, 503.6
s.scripts.OnDragStop(panel)
equal(s.moving .. " " .. s.stopped .. " " .. settings.statTrackerPosition.x .. "," .. settings.statTrackerPosition.y .. " " .. saves,
    "1 1 812,-264 1", "a drag: moved, stopped, its top left corner saved from the screen's, settings saved")
equal(tostring(s.dontSave) .. " " .. tostring(s.userPlaced), "true false", "its place EraUI's own: never in the game's layout cache, the drag's mark let go")
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "held there by its top left corner, one point")
-- A saved spot always wins: one line stays where it was dragged.
Turn("statTrackerLayout", "line")
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "dragged once: one line keeps the spot it was dragged to")
Turn("statTrackerScale", 50)
equal(Point(), "TOPLEFT UIParent TOPLEFT 1624 -528", "and at 50%, placed again: still that spot")
Turn("statTrackerScale", 100)
Turn("statTrackerLayout", "list")
-- Dragged once: /era open leaves it where it was put.
E.settingsFrame:Hide(); E.settingsFrame:Show()
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "/era open after a drag: where it was dragged to")
E.settingsFrame:Hide()
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "and /era closed")
-- Hidden in the middle of a drag (/era closed with Escape, only in a fight):
-- the drag ends there and that spot is kept; nothing is left half-dragged.
Turn("statTrackerShow", "combat")
E.settingsFrame:Show()
s.scripts.OnDragStart(panel)
s.left, s.top = 600, 700
E.settingsFrame:Hide()
equal(tostring(Shown()) .. " " .. s.stopped .. " " .. settings.statTrackerPosition.x .. "," .. settings.statTrackerPosition.y, "false 2 600,-68",
    "hidden mid-drag: the drag stopped, that spot kept")
E.settingsFrame:Show()
equal(Point(), "TOPLEFT UIParent TOPLEFT 600 -68", "/era open again: where the drag left it")
E.settingsFrame:Hide()
s.left, s.top = 812.4, 503.6
s.scripts.OnDragStart(panel); s.scripts.OnDragStop(panel)
Turn("statTrackerShow", "always")
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "dragged back")

-- Panel Size: its scale, live, the same spot on screen at any size ----------------
equal(settings.statTrackerScale .. " " .. G(s.scale), "100 1", "100% by default")
Turn("statTrackerScale", 50)
equal(G(s.scale) .. " " .. Point(), "0.5 TOPLEFT UIParent TOPLEFT 1624 -528", "50%: half size, held at the same spot on the screen")
-- Dragged at 50%: its edges are in its own (half-size) units, saved in the screen's.
s.scripts.OnDragStart(panel)
s.left, s.top = 1000.4, 1100
s.scripts.OnDragStop(panel)
equal(settings.statTrackerPosition.x .. "," .. settings.statTrackerPosition.y .. " " .. Point(), "500,-218 TOPLEFT UIParent TOPLEFT 1000 -436",
    "a drag at 50%: its top left corner saved in the screen's units")
Turn("statTrackerScale", 150)
equal(G(s.scale) .. " " .. Point(), "1.5 TOPLEFT UIParent TOPLEFT 333.333 -145.333", "150%: half as big again, the same spot on the screen")
-- Out of range or unreadable: 50% to 150%, else 100%.
Turn("statTrackerScale", 400)
equal(G(s.scale), "1.5", "400 saved: no more than 150%")
Turn("statTrackerScale", 10)
equal(G(s.scale), "0.5", "10 saved: no less than 50%")
Turn("statTrackerScale", "big")
equal(G(s.scale), "1", "not a number: 100%")
Turn("statTrackerScale", 150)
-- A size change in the middle of a drag waits for the drag to end.
s.scripts.OnDragStart(panel)
Turn("statTrackerScale", 100)
equal(G(s.scale), "1.5", "mid-drag: the size waits")
s.left, s.top = 541.6, 336
s.scripts.OnDragStop(panel)
equal(settings.statTrackerPosition.x .. "," .. settings.statTrackerPosition.y, "812,-264", "the drag at 150% saved in the screen's units")
Module:Refresh()
equal(G(s.scale) .. " " .. Point(), "1 TOPLEFT UIParent TOPLEFT 812 -264", "the drag over, the next change gives it its size: 100%, the same spot")

-- Stats per Line: One line's stats in rows of that many, a grid -------------------
-- Every text on show with its place, and the panel's size.
local function Snapshot()
    local out = {}
    for _, f in ipairs(Fonts()) do
        local p = S[f].points[1]
        out[#out + 1] = S[f].text .. "@" .. G(p[4]) .. "," .. G(p[5])
    end
    return table.concat(out, " ") .. " " .. G(s.w) .. "x" .. G(s.h)
end
local function Spot(text) local p = S[Find(text)].points[1]; return G(p[4]) .. "," .. G(p[5]) end
-- The stats ({short name, number[, gain]} in order) laid out columns to a
-- line: each on its own line 20 apart, every name in a column at one x,
-- every number in it at one x just after its widest name, each column 18
-- clear of the widest number (and gain) of the one before it.
local function Aligned(cells, columns)
    local names, numbers, widest, rights = {}, {}, {}, {}
    for i, cell in ipairs(cells) do
        local column, line = (i - 1) % columns + 1, math.floor((i - 1) / columns)
        local name, number = S[Find(cell[1])].points[1], S[Find(cell[2])].points[1]
        if name[5] ~= -(8 + line * 20) or number[5] ~= name[5] then return cell[1] .. " not on line " .. (line + 1) end
        names[column], numbers[column] = names[column] or name[4], numbers[column] or number[4]
        if name[4] ~= names[column] or number[4] ~= numbers[column] then return cell[1] .. " out of its column" end
        widest[column] = math.max(widest[column] or 0, #cell[1] * 7)
        local right = number[4] + #cell[2] * 7
        if cell[3] then right = S[Find(cell[3])].points[1][4] + #cell[3] * 7 end
        rights[column] = math.max(rights[column] or 0, right)
    end
    for column = 1, #names do
        if numbers[column] ~= names[column] + widest[column] + 6 then return "column " .. column .. "'s numbers not just after its widest name" end
        if column > 1 and names[column] ~= rights[column - 1] + 18 then return "column " .. column .. " not 18 after the one before" end
    end
    return "lined up"
end
local EIGHT = { { "Agi", "150" }, { "Stam", "95" }, { "AP", "386" }, { "Crit", "9.4%" }, { "Hit", "3.4%" }, { "Armor", "1,204" },
    { "Dodge", "10.8%" }, { "Speed", "100%" } }
equal(settings.statTrackerPerLine .. " " .. settings.statTrackerLayout .. " " .. Point(), "16 list TOPLEFT UIParent TOPLEFT 812 -264",
    "All by default, a list, where it was dragged")
local list = Snapshot()
-- A list never wraps by it: one stat a line whatever it says.
Turn("statTrackerPerLine", 3)
equal(Snapshot(), list, "a list: Stats per Line changes nothing")
Turn("statTrackerPerLine", 16)
Turn("statTrackerLayout", "line")
local all = Snapshot()
equal(Lines() .. " " .. s.h, "Agi 150 Stam 95 AP 386 Crit 9.4% Hit 3.4% Armor 1,204 Dodge 10.8% Speed 100% 30", "All: the eight on one line")
-- As many to a line as there are stats, or more: just as All.
for _, count in ipairs({ 8, 10, 15 }) do
    Turn("statTrackerPerLine", count)
    equal(Snapshot(), all, count .. " per line with eight ticked: the same single line as All")
end
-- Fewer: rows of that many under each other, in order, the text its size.
Turn("statTrackerPerLine", 4)
equal(Lines() .. " " .. s.h, "Agi 150 Stam 95 AP 386 Crit 9.4% | Hit 3.4% Armor 1,204 Dodge 10.8% Speed 100% 50", "4 per line: two rows of four, 20 taller")
equal(Aligned(EIGHT, 4), "lined up", "4 per line: a grid, names and numbers in columns")
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "its top left corner where it was")
local sizes = {}
for _, f in ipairs(Fonts()) do sizes[S[f].size] = true end
equal(sizes[13] and not sizes[11] and next(sizes, next(sizes)) == nil, true, "the text keeps its size (13)")
-- 3 per line, worked out: Agi / Crit / Dodge, then Stam / Hit / Speed, then
-- AP / Armor. Names at 16, 110 and 197; numbers after each column's widest
-- name (35) and 6; 18 between columns; 70 tall.
Turn("statTrackerPerLine", 3)
equal(Lines(), "Agi 150 Stam 95 AP 386 | Crit 9.4% Hit 3.4% Armor 1,204 | Dodge 10.8% Speed 100%", "3 per line: three rows, the last short")
equal(table.concat({ Spot("Agi"), Spot("150"), Spot("Crit"), Spot("9.4%"), Spot("Dodge"), Spot("10.8%"), Spot("Stam"), Spot("95"), Spot("Speed"),
    Spot("100%"), Spot("AP"), Spot("386"), Spot("Armor"), Spot("1,204") }, " ") .. " " .. G(s.w) .. "x" .. G(s.h),
    "16,-8 57,-8 16,-28 57,-28 16,-48 57,-48 110,-8 151,-8 110,-48 151,-48 197,-8 238,-8 197,-28 238,-28 289x70",
    "3 per line: each column's names at one x, its numbers at one x, the panel as wide as the grid")
equal(Aligned(EIGHT, 3), "lined up", "3 per line: a grid")
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "still its top left corner where it was")
Turn("statTrackerPerLine", 7)
equal(Lines(), "Agi 150 Stam 95 AP 386 Crit 9.4% Hit 3.4% Armor 1,204 Dodge 10.8% | Speed 100%", "7 per line: seven, then one")
equal(Aligned(EIGHT, 7), "lined up", "7 per line: a grid")
Turn("statTrackerPerLine", 1)
equal(Lines() .. " " .. s.h, "Agi 150 | Stam 95 | AP 386 | Crit 9.4% | Hit 3.4% | Armor 1,204 | Dodge 10.8% | Speed 100% 170", "1 per line: a column of eight")
equal(Aligned(EIGHT, 1), "lined up", "1 per line: the names and numbers each in one column")
-- Never dragged: it stays at the top centre as it changes, as with Panel Size.
local saved = settings.statTrackerPosition
settings.statTrackerPosition = nil
Turn("statTrackerPerLine", 4)
equal(Point() .. " " .. G(s.w), "TOP UIParent TOP 0 -14 " .. G(s.w), "never dragged: at the top centre")
Turn("statTrackerPerLine", 2)
equal(Point() .. " " .. tostring(s.h > 50), "TOP UIParent TOP 0 -14 true", "fewer to a line: still centred at the top, taller")
settings.statTrackerPosition = saved
Turn("statTrackerPerLine", 4)
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "its dragged spot back")
-- Only ticked stats count: unticked ones leave no gap.
Tick({ Stamina = true, AttackPower = true, Hit = true, Armor = true, Dodge = true, Speed = true })
equal(Lines(), "Stam 95 AP 386 Hit 3.4% Armor 1,204 | Dodge 10.8% Speed 100%", "six ticked, 4 per line: four, then two")
equal(Aligned({ { "Stam", "95" }, { "AP", "386" }, { "Hit", "3.4%" }, { "Armor", "1,204" }, { "Dodge", "10.8%" }, { "Speed", "100%" } }, 4), "lined up",
    "the six in a grid of their own")
Tick({ Stamina = true, AttackPower = true })
equal(Lines() .. " " .. s.h, "Stam 95 AP 386 30", "two ticked, 4 per line: one line")
-- A longer name above a shorter one: the column's numbers go after its widest
-- name (Spirit), not its last (Crit).
Tick({ Spirit = true, AttackPower = true, Crit = true, Dodge = true })
Turn("statTrackerPerLine", 2)
equal(Snapshot(), "Spirit@16,-8 44@64,-8 AP@110,-8 386@151,-8 Crit@16,-28 9.4%@64,-28 Dodge@110,-28 10.8%@151,-28 202x50",
    "Crit's number under Spirit's, after the column's widest name")
Turn("statTrackerPerLine", 4)
Tick({ Agility = true, Stamina = true, AttackPower = true, Crit = true, Hit = true, Armor = true, Dodge = true, Speed = true })
-- Panel Size: the same rows at any size, its top left corner kept.
local rows4 = Lines()
local wide4 = s.w
Turn("statTrackerScale", 150)
equal(Lines() .. " " .. G(s.w) .. " " .. G(s.scale) .. " " .. Point(), rows4 .. " " .. G(wide4) .. " 1.5 TOPLEFT UIParent TOPLEFT 541.333 -176",
    "150%: the same rows, half as big again, its top left corner on the same spot")
Turn("statTrackerScale", 100)
-- The screen's edge still counts: whichever gives fewer to a line wins. On a
-- 500-wide screen four fit at 100% (330 of 428); at 150% the room is
-- (500 - 40) / 1.5 - 32 = 274.7, so three; 2 per line stays two.
S[UIParent].w = 500
Module:Refresh()
equal(Lines(), rows4, "a 500-wide screen at 100%: four to a line, as asked")
Turn("statTrackerScale", 150)
equal(Lines(), "Agi 150 Stam 95 AP 386 | Crit 9.4% Hit 3.4% Armor 1,204 | Dodge 10.8% Speed 100%", "at 150% four won't fit: three to a line")
equal(Aligned(EIGHT, 3) .. " " .. tostring(s.w * 1.5 <= 460), "lined up true", "still a grid, no wider on screen than the screen less 20 each side")
Turn("statTrackerPerLine", 2)
equal(Lines(), "Agi 150 Stam 95 | AP 386 Crit 9.4% | Hit 3.4% Armor 1,204 | Dodge 10.8% Speed 100%", "2 per line at 150%: two, fewer than fit")
equal(Aligned(EIGHT, 2), "lined up", "2 per line: a grid")
-- A screen too narrow for even two: one to a line.
S[UIParent].w = 260
Module:Refresh()
equal(Aligned(EIGHT, 1), "lined up", "a very narrow screen: one to a line")
S[UIParent].w = nil
Turn("statTrackerScale", 100)
Turn("statTrackerPerLine", 4)
-- Gains in Green: the gain just after its number; its column makes room, the
-- grid still lined up.
game.stat[3] = 101
Fire("UNIT_STATS", "player"); Wait(.2)
local plus = S[Find("+6")].points[1]
equal(Spot("+6") .. " " .. Colour(S[Find("101")].textColour), G(S[Find("101")].points[1][4] + #"101" * 7 + 4) .. "," .. G(S[Find("Stam")].points[1][5] - 2)
    .. " 0.290,0.870,0.500", "Stam up 6: green, +6 just after its number")
equal(S[Find("AP")].points[1][4] >= plus[4] + #"+6" * 7 + 18, true, "the next column moves over for it: nothing overlaps")
EIGHT[2] = { "Stam", "101", "+6" }
equal(Aligned(EIGHT, 4), "lined up", "names and numbers still in their columns")
EIGHT[2] = { "Stam", "95" }
game.stat[3] = 95
Wait(5.3)
Fire("UNIT_STATS", "player"); Wait(.2)
equal(Find("+6") == nil and Lines(), rows4, "the gain over: the grid as before")
-- Show Title never shows on one line; Stat Name Colour colours the names.
equal(tostring(settings.statTrackerTitle) .. " " .. tostring(Find("Stats") ~= nil), "true false", "Show Title on: still no title on one line")
Turn("statTrackerNameColour", "class")
equal(Colour(S[Find("Stam")].textColour) .. " " .. Colour(S[Find("Speed")].textColour) .. " " .. Colour(S[Find("95")].textColour),
    "1.000,0.960,0.410 1.000,0.960,0.410 1.000,1.000,1.000", "Class: the grid's names in a rogue's yellow, the numbers white")
Turn("statTrackerNameColour", "auto")
-- Not a whole number (a hand-edited or damaged save): rounded, as the slider rounds.
local four = Snapshot()
Turn("statTrackerPerLine", 3.6)
equal(Snapshot(), four, "3.6 saved: rounded to 4, as the slider rounds")
-- A number it can't read (lost or broken): All; below 1: one a line; above 16: All.
Turn("statTrackerPerLine", "big")
equal(Snapshot(), all, "unreadable: All")
Turn("statTrackerPerLine", 0)
equal(Aligned(EIGHT, 1), "lined up", "0 saved: one to a line")
Turn("statTrackerPerLine", 40)
equal(Snapshot(), all, "40 saved: All")
Turn("statTrackerPerLine", 16)
equal(Snapshot(), all, "All again: as it always was")
Turn("statTrackerLayout", "list")
equal(Snapshot(), list, "back to a list: as before")

-- Looks: Classic and Dark Mode --------------------------------------------------------
local function Strips()
    local edge, line, fill = {}, {}, nil
    for _, f in ipairs(frames) do
        local t = S[f]
        if t.kind == "Texture" and t.parent == panel then
            if t.layer == "BACKGROUND" then fill = t
            elseif t.layer == "BORDER" and t.sublevel == 1 then line[#line + 1] = t
            elseif t.layer == "BORDER" then edge[#edge + 1] = t end
        end
    end
    return edge, line, fill
end
local edge, line, fill = Strips()
equal(#edge .. " " .. Colour(edge[1].colour) .. " " .. (edge[1].h or edge[1].w) .. " " .. #line .. " " .. tostring(line[1].shown)
    .. " " .. Colour(fill.colour) .. " " .. fill.colour[4], "4 0.541,0.427,0.169 2 4 true 0.024,0.024,0.031 0.84",
    "Classic: a bronze edge 2 thick, a fine black line inside it, a near-black fill")
settings.darkMode = true
Turn("statTracker", true)
edge, line, fill = Strips()
equal(Colour(edge[1].colour) .. " " .. (edge[1].h or edge[1].w) .. " " .. tostring(line[1].shown) .. " " .. Colour(fill.colour) .. " " .. fill.colour[4],
    "0.210,0.220,0.240 1 false 0.071,0.071,0.086 0.9", "Dark Mode: a thin edge in the Darkness grey, half as light; no fine line")
equal(Colour(S[Find("Agility")].textColour) .. " " .. Colour(S[Find("150")].textColour) .. " " .. Colour(S[Find("Stats")].textColour),
    "0.639,0.639,0.678 0.925,0.925,0.940 0.925,0.925,0.940", "grey names, light numbers and title")
grey = { .2, .21, .23 }
Module:Paint()
equal(Colour(edge[1].colour), "0.100,0.105,0.115", "the Darkness slider: the edge follows at once")

-- Stat Name Colour: the names only; the numbers and the title keep theirs -------
local function Names()
    return Colour(S[Find("Agility")].textColour) .. " " .. Colour(S[Find("Stamina")].textColour)
end
local function Others() return Colour(S[Find("150")].textColour) .. " " .. Colour(S[Find("Stats")].textColour) end
local darkOthers = Others()
equal(settings.statTrackerNameColour .. " " .. settings.statTrackerNameCustomColour, "auto FFD100", "Match look by default; Custom starts at the Classic gold")
Turn("statTrackerNameColour", "gold")
equal(Names() .. " " .. Others(), "1.000,0.820,0.000 1.000,0.820,0.000 " .. darkOthers, "Gold in Dark Mode: gold names, the numbers and title as they were")
settings.darkMode = false
Turn("statTrackerNameColour", "auto")
equal(Names() .. " " .. Others(), "1.000,0.820,0.000 1.000,0.820,0.000 1.000,1.000,1.000 1.000,0.820,0.000", "Match look in Classic: gold names, white numbers")
Turn("statTrackerNameColour", "white")
equal(Names() .. " " .. Others(), "1.000,1.000,1.000 1.000,1.000,1.000 1.000,1.000,1.000 1.000,0.820,0.000", "White: white names, the title still gold")
Turn("statTrackerNameColour", "class")
equal(Names(), "1.000,0.960,0.410 1.000,0.960,0.410", "Class: a rogue's yellow")
-- Class colours set by the player's own class colour addon come first.
CUSTOM_CLASS_COLORS = { ROGUE = { r = .2, g = .6, b = 1 } }
Module:Refresh()
equal(Names(), "0.200,0.600,1.000 0.200,0.600,1.000", "Class with custom class colours: those first")
CUSTOM_CLASS_COLORS = nil
Module:Refresh()
equal(Names(), "1.000,0.960,0.410 1.000,0.960,0.410", "and the game's again without them")
game.class = "PALADIN"
Module:Refresh()
equal(Names(), "0.960,0.550,0.730 0.960,0.550,0.730", "a paladin: EraUI's pink")
game.class = Secret()
Module:Refresh()
equal(Names(), "1.000,0.820,0.000 1.000,0.820,0.000", "the class a secret: the look's own")
game.class = "SHAMAN"
Module:Refresh()
equal(Names(), "1.000,0.820,0.000 1.000,0.820,0.000", "a class the game has no colour for: the look's own")
game.class = "ROGUE"
settings.statTrackerNameCustomColour = "3366FF"
Turn("statTrackerNameColour", "custom")
equal(Names(), "0.200,0.400,1.000 0.200,0.400,1.000", "Custom: the colour picked")
settings.statTrackerNameCustomColour = "nope"
Module:Refresh()
equal(Names(), "1.000,0.820,0.000 1.000,0.820,0.000", "a broken custom colour: the gold")
Turn("statTrackerNameColour", "rainbow")
equal(Names(), "1.000,0.820,0.000 1.000,0.820,0.000", "an unknown choice: Match look")
-- One line: its short names take the colour too, and a gain stays green.
settings.statTrackerNameCustomColour = "3366FF"
Turn("statTrackerNameColour", "custom")
Turn("statTrackerLayout", "line")
game.stat[3] = 99
Fire("UNIT_STATS", "player"); Wait(.2)
equal(Colour(S[Find("Stam")].textColour) .. " " .. Colour(S[Find("99")].textColour) .. " " .. Colour(S[Find("+4")].textColour),
    "0.200,0.400,1.000 0.290,0.870,0.500 0.290,0.870,0.500", "one line: Stam in the custom colour, its gain still green")
Wait(5.3)
Turn("statTrackerLayout", "list")
settings.statTrackerNameCustomColour = "FFD100"
Turn("statTrackerNameColour", "auto")

-- Off: hidden, nothing watched; on again starts afresh ----------------------------
local letGo = S[events].unregistered or 0
Turn("statTracker", false)
equal(tostring(Shown()) .. " " .. (S[events].unregistered - letGo), "false 1", "off: hidden, every event let go")
registered = 0
for _ in pairs(S[events].events) do registered = registered + 1 end
equal(registered, 0, "no event watched")
game.stat[2] = 170
Turn("statTracker", true)
equal(Shown() and Find("170") ~= nil and Find("+20") == nil, true, "on again: its numbers, nothing green")
equal(Point(), "TOPLEFT UIParent TOPLEFT 812 -264", "still where it was dragged")
-- Logging in (or a /reload) in a fight: only in a fight shows straight away.
Turn("statTrackerShow", "combat")
combat = true
Fire("PLAYER_ENTERING_WORLD"); Wait(.2)
equal(Shown(), true, "entering the world in a fight: shown")
combat = false
Fire("PLAYER_REGEN_ENABLED")
equal(Shown(), false, "the fight ends: hidden")
Turn("statTrackerShow", "always")
-- A new session (a /reload) at 50%: made at that size where it was dragged
-- to, the numbers read at once.
settings.statTrackerScale = 50
local E2 = { modules = {}, Classic = E.Classic, RegisterModule = E.RegisterModule, GetSetting = E.GetSetting, SetSetting = E.SetSetting,
    SaveSettings = E.SaveSettings }
assert(loadfile("Modules/StatTracker.lua"))("EraUI", E2)
E2.modules.StatTracker:Initialize()
local fresh = S[_G.EraUIStatTracker]
equal(tostring(_G.EraUIStatTracker ~= panel) .. " " .. table.concat({ fresh.points[1][1], G(fresh.points[1][4]), G(fresh.points[1][5]) }, " ") .. " " .. G(fresh.scale)
    .. " " .. fresh.strata .. " " .. tostring(fresh.shown), "true TOPLEFT 1624 -528 0.5 HIGH true",
    "a new session: its own panel at its size where it was dragged, on its own layer, shown")

-- Nothing of the game's touched -----------------------------------------------------
equal(#writes, 0, "no key written on the game's frames (" .. table.concat(writes, ", ") .. ")")
equal(#forbidden, 0, "no tooltip, hook or binding (" .. table.concat(forbidden, ", ") .. ")")

print("Stat Tracker checks passed: " .. checks .. " assertions.")
