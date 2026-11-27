-- Healer Mana (Modules/HealerMana.lua; /era > Group & Invites > Healer
-- mana, the rows at the end) against a mock of the game. Off by default: no
-- panel, no events. On: EraUI's own panel, sized at once, clamped, movable
-- only while unlocked (locked it takes no mouse), a line each for the
-- healers in a party or raid (the Healer role, or a healing class with no
-- role; Tank and Damage never), by group then name, at most ten; Include
-- Me, Every Mana User, Show in Party and Show in Raid. Each line's bar takes
-- the game's mana as it is; the percent is the game's own through its 0 to
-- 100 curve; Low Mana Colour turns it amber where the numbers can be read,
-- and in a fight hands the game a colour curve (blue if that fails).
-- Drinking from a drink buff (by spell ID or name, a hidden buff passed
-- over), read out of a fight only and only for the lines shown: it goes as
-- a fight starts and is read again as it ends. One power event per line
-- (UNIT_POWER_FREQUENT), and while hidden the lines listen for nothing. Secrets
-- (Forever's restricted mana, names, classes, roles, auras) are tables that
-- refuse to be compared, added up, joined, indexed or measured, as in the
-- game: they go to the widgets as they are. Offline and Dead lines. Unlock
-- (sample lines with nobody to show), drag and its saved place, right-click
-- and a fight lock it, Reset, Size, Bar Width, the /era preview, Classic and
-- Dark Mode looks. No key is written on the game's frames, and the game's
-- tooltip, hooks, bindings and casts are never used.
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
-- As in the game, a secret says what type it is.
local realType = type
type = function(v) if v ~= nil and secretKind[v] then return secretKind[v] end return realType(v) end

-- Mock widgets ------------------------------------------------------------------
-- Each object's state lives beside it (S), so anything written on a frame
-- by the module shows as a plain key, and the game's own frames are never
-- touched (UIParent's keys are checked at the end).
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local all = {}
local function New(kind, name, parent)
    local o = {}
    S[o] = { kind = kind, name = name, parent = parent, shown = true, points = {}, scripts = {}, hooks = {}, events = {}, units = {},
        count = {}, strata = "MEDIUM", text = "", scale = 1 }
    all[#all + 1] = o
    return setmetatable(o, { __index = function(_, key)
        local method = Proto[key]
        if method then return method end
        if realType(key) == "string" and key:match("^%u") then error("the mock has no " .. kind .. ":" .. key, 2) end
    end })
end
local function Count(o, what) S[o].count[what] = (S[o].count[what] or 0) + 1 end
function Proto:SetSize(w, h) S[self].w, S[self].h = w, h end
function Proto:SetWidth(w) S[self].w = w end
function Proto:SetHeight(h) S[self].h = h end
function Proto:GetHeight() return S[self].h end
function Proto:GetWidth() return S[self].w end
function Proto:IsShown() return S[self].shown end
function Proto:Show() S[self].shown = true; for _, fn in ipairs(S[self].hooks.OnShow or {}) do fn(self) end end
function Proto:Hide()
    S[self].shown = false
    if S[self].scripts.OnHide then S[self].scripts.OnHide(self) end
    for _, fn in ipairs(S[self].hooks.OnHide or {}) do fn(self) end
end
function Proto:SetShown(v) if v then self:Show() else self:Hide() end end
function Proto:SetPoint(...) table.insert(S[self].points, { ... }) end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetAllPoints(to) S[self].points = { { "ALL", to } } end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:HookScript(name, fn) S[self].hooks[name] = S[self].hooks[name] or {}; table.insert(S[self].hooks[name], fn) end
function Proto:RegisterEvent(event) S[self].events[event] = true end
function Proto:RegisterUnitEvent(event, unit) S[self].units[event] = unit end
function Proto:UnregisterAllEvents() S[self].events, S[self].units = {}, {}; Count(self, "unregister") end
function Proto:SetFrameStrata(v) S[self].strata = v end
function Proto:SetScale(v) S[self].scale = v end
function Proto:SetClampedToScreen(v) S[self].clamped = v end
function Proto:SetMovable(v) S[self].movable = v end
function Proto:SetDontSavePosition(v) S[self].dontSave = v end
function Proto:EnableMouse(v) S[self].mouse = v and true or false end
function Proto:RegisterForDrag(...) S[self].drag = table.concat({ ... }, ",") end
-- As in the client: a frame you drag is marked moved by you unless told not to save it.
function Proto:StartMoving() Count(self, "moving"); S[self].userPlaced = true end
function Proto:StopMovingOrSizing() Count(self, "stopped") end
function Proto:SetUserPlaced(v) S[self].userPlaced = v end
function Proto:GetLeft() return S[self].left end
function Proto:GetTop() return S[self].top end
function Proto:CreateTexture(_, layer) local t = New("Texture", nil, self); S[t].layer = layer; return t end
function Proto:CreateFontString() return New("FontString", nil, self) end
function Proto:SetColorTexture(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:SetTexture(t) S[self].texture = t end
function Proto:SetTexCoord() end
function Proto:SetFont(file, size) S[self].font, S[self].size = file, size; return true end
function Proto:SetShadowColor() end
function Proto:SetShadowOffset() end
function Proto:SetWordWrap() end
function Proto:SetJustifyH(v) S[self].justify = v end
function Proto:SetText(text) S[self].text = text; S[self].args = nil end
function Proto:GetText() return S[self].text end
function Proto:SetFormattedText(format, ...)
    local args, hidden = { n = select("#", ...), ... }, false
    for i = 1, args.n do if issecretvalue(args[i]) then hidden = true end end
    S[self].format, S[self].args = format, args
    S[self].text = hidden and "<secret>" or string.format(format, ...)
end
function Proto:SetTextColor(r, g, b) S[self].textColour = { r, g, b } end
function Proto:SetStatusBarTexture(t) S[self].texture = t end
function Proto:SetMinMaxValues(low, high) S[self].low, S[self].high = low, high end
function Proto:SetValue(v) S[self].value = v; Count(self, "value") end
function Proto:SetStatusBarColor(r, g, b) S[self].barColour = { r, g, b } end

-- The game -------------------------------------------------------------------
local combat = false
InCombatLockdown = function() return combat end
GetTime = function() return 100 end
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function Flush()
    for _ = 1, 20 do
        if #timers == 0 then return end
        local due = timers; timers = {}
        for _, fn in ipairs(due) do fn() end
    end
    error("timers did not settle")
end
CreateFrame = function(kind, name, parent)
    local f = New(kind, name, parent)
    if name then _G[name] = f end
    return f
end
UIParent = New("Frame", "UIParent")
S[UIParent].h = 768
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
Enum = { PowerType = { Mana = 0 }, LuaCurveType = { Linear = 0, Step = 1 } }
RAID_CLASS_COLORS = { PRIEST = { r = 1, g = 1, b = 1 }, SHAMAN = { r = 0, g = .44, b = .87 }, DRUID = { r = 1, g = .49, b = .04 },
    PALADIN = { r = .5, g = .5, b = .5 }, WARRIOR = { r = .78, g = .61, b = .43 }, MAGE = { r = .25, g = .78, b = .92 } }
-- The game's tooltip, hooks, bindings and casts: never used.
local forbidden = {}
local function Forbid(name) return function() forbidden[#forbidden + 1] = name end end
GameTooltip = setmetatable({}, { __index = function(_, key) forbidden[#forbidden + 1] = "GameTooltip." .. tostring(key); return function() end end })
hooksecurefunc, SetOverrideBinding, SetBinding = Forbid("hooksecurefunc"), Forbid("SetOverrideBinding"), Forbid("SetBinding")
UnitCastingInfo, UnitChannelInfo = Forbid("UnitCastingInfo"), Forbid("UnitChannelInfo")

-- Colours and curves, as Forever's: a curve evaluates a 0 to 1 mana.
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(self) return self.r, self.g, self.b end } end
local made = {}
local function NewCurve(colour)
    local c = { colour = colour, points = {} }
    function c:SetType(kind) self.kind = kind end
    function c:AddPoint(x, y) self.points[#self.points + 1] = { x, y } end
    function c:Evaluate(x)
        local p = self.points
        if x <= p[1][1] then return p[1][2] end
        for i = 2, #p do
            if x <= p[i][1] then
                local t = (x - p[i - 1][1]) / (p[i][1] - p[i - 1][1])
                if not self.colour then return p[i - 1][2] + (p[i][2] - p[i - 1][2]) * t end
                local a, b = p[i - 1][2], p[i][2]
                return CreateColor(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
            end
        end
        return p[#p][2]
    end
    made[#made + 1] = c
    return c
end
C_CurveUtil = { CreateCurve = function() return NewCurve(false) end, CreateColorCurve = function() return NewCurve(true) end }

-- The group: each unit's player. In a fight (restricted) the game hides
-- everyone's mana but yours, and their auras.
local game
local function Person(name, class, role, power, max, extra)
    local p = { name = name, surname = "Ashdown", class = class, role = role or "NONE", power = power, max = max or 1000 }
    for k, v in pairs(extra or {}) do p[k] = v end
    return p
end
local function Reset()
    game = { raid = false, grouped = false, restricted = false, colourFails = false, units = {}, party = 0, raidSize = 0,
        player = Person("Squirt", "PRIEST", "NONE", 800, 1000, { guid = "Player-1" }) }
    game.units.player = game.player
end
Reset()
local function Hidden(unit) return game.restricted and unit ~= "player" end
local function Unit(unit) return game.units[unit] end
UnitExists = function(unit) return Unit(unit) ~= nil end
UnitClass = function(unit)
    local p = Unit(unit)
    if not p then return nil end
    if p.secretClass then return Secret("string"), Secret("string") end
    return p.class:sub(1, 1) .. p.class:sub(2):lower(), p.class
end
UnitName = function(unit)
    local p = Unit(unit)
    if not p then return nil end
    if p.secretName then return Secret("string"), Secret("string") end
    return p.name, p.surname
end
UnitGroupRolesAssigned = function(unit)
    local p = Unit(unit)
    if p and p.secretRole then return Secret("string") end
    return p and p.role or "NONE"
end
UnitPowerType = function(unit) local p = Unit(unit); return p and (p.powerType or 0) or 0, "MANA" end
local asked = { power = 0, percent = 0, auras = 0 }
UnitPower = function(unit, kind)
    assert(kind == 0, "mana asked for")
    asked.power = asked.power + 1
    if Hidden(unit) then return Secret("number") end
    return Unit(unit).power
end
UnitPowerMax = function(unit, kind)
    assert(kind == 0, "mana asked for")
    if Hidden(unit) then return Secret("number") end
    return Unit(unit).max
end
-- The secret colour the game hands back for a curve in a fight.
local secretColour
UnitPowerPercent = function(unit, kind, unmodified, curve)
    assert(kind == 0 and unmodified == false and curve ~= nil, "mana's percent through a curve")
    asked.percent = asked.percent + 1
    local p = Unit(unit)
    if Hidden(unit) then
        if curve.colour then
            if game.colourFails then error("no colour today") end
            secretColour = { Secret("number"), Secret("number"), Secret("number") }
            return { GetRGB = function() return secretColour[1], secretColour[2], secretColour[3] end }
        end
        return Secret("number")
    end
    return curve:Evaluate(p.max > 0 and p.power / p.max or 0)
end
UnitIsUnit = function(a, b) return a == b or (b == "player" and game.me == a) end
UnitGUID = function(unit) local p = Unit(unit); return p and p.guid end
UnitIsConnected = function(unit) local p = Unit(unit); return p ~= nil and not p.offline end
UnitIsDeadOrGhost = function(unit) local p = Unit(unit); return p ~= nil and p.dead == true end
IsInRaid = function() return game.raid end
IsInGroup = function() return game.grouped end
GetNumSubgroupMembers = function() return game.party end
GetNumGroupMembers = function() return game.raid and game.raidSize or (game.grouped and game.party + 1 or 0) end
GetRaidRosterInfo = function(i)
    local p = Unit("raid" .. i)
    if not p then return nil end
    return p.name, 0, p.group
end
C_UnitAuras = { GetAuraDataByIndex = function(unit, index, filter)
    assert(filter == "HELPFUL", "buffs only")
    asked.auras = asked.auras + 1
    local p = Unit(unit)
    local aura = p and p.auras and p.auras[index]
    if not aura then return nil end
    if Hidden(unit) or p.secretAuras then return { spellId = Secret("number"), name = Secret("string") } end
    return aura
end }

local function Party(list)
    game.raid, game.grouped, game.party, game.me = false, true, #list, nil
    for unit in pairs(game.units) do if unit ~= "player" then game.units[unit] = nil end end
    for i, p in ipairs(list) do game.units["party" .. i] = p end
end
local function Raid(list)
    game.raid, game.grouped, game.party, game.raidSize, game.me = true, true, 4, #list, nil
    for unit in pairs(game.units) do if unit ~= "player" then game.units[unit] = nil end end
    for i, p in ipairs(list) do
        game.units["raid" .. i] = p
        if p == game.player then game.me = "raid" .. i end
    end
end

-- EraUI: the real defaults (Core/Init.lua), its settings and a stand-in for /era.
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
local window = New("Frame", "EraUISettingsFrame")
S[window].shown = false
E.settingsFrame = window
local mark = #all
assert(loadfile("Modules/HealerMana.lua"))("EraUI", E)
local Module = E.modules.HealerMana

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
-- A unit event, to each frame listening for that unit (the game filters them).
local function UnitFire(unit, event, ...)
    local heard = 0
    for _, f in ipairs(all) do
        if S[f].units[event] == unit and S[f].scripts.OnEvent then heard = heard + 1; S[f].scripts.OnEvent(f, event, unit, ...) end
    end
    return heard
end
local panel
local function Shown() return panel ~= nil and S[panel].shown end
-- The lines on show, top to bottom.
local function RowFrames()
    local out = {}
    for _, f in ipairs(all) do
        if S[f].parent == panel and S[f].kind == "Frame" and S[f].shown then out[#out + 1] = f end
    end
    table.sort(out, function(a, b) return S[a].points[1][5] > S[b].points[1][5] end)
    return out
end
-- Each line as "Name text[ Drinking]".
local function Lines()
    local out = {}
    for i, row in ipairs(RowFrames()) do
        local name = S[row.name].text
        if issecretvalue(name) then name = "<secret>" end
        out[i] = name .. " " .. tostring(S[row.value].text) .. ((S[row.cup].shown and S[row.drink].shown) and " Drinking" or "")
    end
    return table.concat(out, " | ")
end
local function Row(name)
    for _, row in ipairs(RowFrames()) do if S[row.name].text == name then return row end end
end
local function Colour(c) return c and string.format("%.2f,%.2f,%.2f", c[1], c[2], c[3]) or "nil" end
local function BarColour(row) return Colour(S[row.bar].barColour) end
local function Point(f)
    local p = S[f].points[1]
    local to = p[2] == UIParent and "UIParent" or tostring(p[2])
    local function N(v) return (string.format("%.4f", v):gsub("%.?0+$", "")) end
    return table.concat({ p[1], to, p[3], N(p[4]), N(p[5]) }, " ")
end
local function Turn(key, value) settings[key] = value; Module:Refresh(); Flush() end
local function Count(o, what) return S[o].count[what] or 0 end
local AMBER, BLUE, GREY_BAR = "1.00,0.65,0.10", "0.15,0.40,1.00", "0.45,0.45,0.50"

-- Off by default: nothing made, nothing watched --------------------------------
equal(settings.healerMana, false, "off by default")
equal(tostring(settings.healerManaSelf) .. " " .. tostring(settings.healerManaAll) .. " " .. tostring(settings.healerManaParty) .. " "
    .. tostring(settings.healerManaRaid) .. " " .. settings.healerManaWidth .. " " .. settings.healerManaScale .. " " .. settings.healerManaLow,
    "false false true true 130 100 30", "defaults: not you, healers only, party and raid, 130 px, 100%, amber at 30%")
for key in pairs(real.settingDefaults) do
    if key:find("^healerMana") then equal(real.reloadSettings[key], nil, key .. " applies live, not on reload") end
end
Module:Initialize()
equal(_G.EraUIHealerMana, nil, "off: no panel made")
local registered = 0
for _ in pairs(S[Driver()].events) do registered = registered + 1 end
equal(registered, 0, "off: no events watched")

-- A party: who counts --------------------------------------------------------------
-- Zelda a priest with no role (counts), Bram a shaman set Healer (counts),
-- Corin a druid set Tank and Dax a paladin set Damage (never), Ulf a
-- warrior (never).
local zelda = Person("Zelda", "PRIEST", "NONE", 200, 1000)
local bram = Person("Bram", "SHAMAN", "HEALER", 750, 1000)
local corin = Person("Corin", "DRUID", "TANK", 500, 1000)
local dax = Person("Dax", "PALADIN", "DAMAGER", 900, 1000)
Party({ zelda, bram, corin, dax })
Turn("healerMana", true)
panel = _G.EraUIHealerMana
local s = S[panel]
equal(panel ~= nil and s.parent == UIParent and Shown(), true, "on in a party: EraUI's own panel on the screen, shown")
equal(tostring(s.clamped) .. " " .. tostring(s.movable) .. " " .. tostring(s.mouse) .. " " .. tostring(s.drag) .. " " .. s.strata .. " " .. tostring(s.dontSave),
    "true true false LeftButton MEDIUM true", "clamped, movable, no mouse while locked (clicks go through), MEDIUM like unit frames, the game keeps no place of its own")
equal(Point(panel), "TOPRIGHT UIParent RIGHT -96 -110", "first time: at the right of the screen, under the middle")
equal(Lines(), "Bram 75% | Zelda 20%", "the Healer role and a healing class with no role, by name; Tank and Damage left out, you too")
local zrow, brow = Row("Zelda"), Row("Bram")
equal(Colour(S[brow.name].textColour) .. " " .. Colour(S[zrow.name].textColour), "0.00,0.44,0.87 1.00,1.00,1.00", "names in their class colour")
equal(S[zrow.bar].low .. " " .. S[zrow.bar].high .. " " .. S[zrow.bar].value, "0 1000 200", "the bar: the game's mana")
equal(S[zrow.value].format .. " " .. string.format("%g", S[zrow.value].args[1]), "%.0f%% 20", "the percent: the game's, through its 0 to 100 curve")
local percent = made[1]
equal(percent.colour == false and percent.kind == 0 and #percent.points == 2 and percent.points[1][1] .. "," .. percent.points[1][2] .. " "
    .. percent.points[2][1] .. "," .. percent.points[2][2], "0,0 1,100", "the curve: linear, 0 to 100")
equal(BarColour(zrow) .. " " .. BarColour(brow), AMBER .. " " .. BLUE, "Low Mana Colour: amber at 20%, blue at 75%")
equal(S[zrow.bar].w .. " " .. s.w .. " " .. s.h, "130 226 72", "130 px bars; the panel fits its two lines")
equal(Point(zrow) .. " / " .. Point(brow), "TOPLEFT " .. tostring(panel) .. " TOPLEFT 8 -47 / TOPLEFT " .. tostring(panel) .. " TOPLEFT 8 -29",
    "lines grow down from under the title")
local title
for _, f in ipairs(all) do if S[f].parent == panel and S[f].kind == "FontString" and S[f].text == "Healer Mana" then title = f end end
equal(title ~= nil and S[title].font .. " " .. Colour(S[title].textColour), "Fonts\\MORPHEUS.TTF 1.00,0.82,0.00", "the Healer Mana title, gold in the Classic look")
-- Each line listens for its own unit only; the panel for the group.
for _, event in ipairs({ "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION", "UNIT_AURA", "UNIT_NAME_UPDATE" }) do
    equal(S[zrow].units[event] .. " " .. S[brow].units[event], "party1 party2", event .. " for each line's unit only")
end
-- UNIT_POWER_FREQUENT hears every change: UNIT_POWER_UPDATE as well would run each line twice.
equal(tostring(S[zrow].units.UNIT_POWER_UPDATE) .. " " .. tostring(S[zrow].events.UNIT_POWER_UPDATE), "nil nil", "UNIT_POWER_UPDATE not listened for")
for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
    equal(S[Driver()].events[event], true, event .. " watched")
end

-- Mana as it changes ----------------------------------------------------------------
zelda.power = 640
local before = Count(zrow.bar, "value")
equal(UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA"), 1, "one line hears its unit")
equal(S[zrow.bar].value .. " " .. S[zrow.value].text .. " " .. BarColour(zrow), "640 64% " .. BLUE, "mana up: the bar, the percent, blue again")
UnitFire("party1", "UNIT_POWER_FREQUENT", "RAGE")
equal(Count(zrow.bar, "value"), before + 1, "another kind of power changes nothing")
zelda.max = 1600
UnitFire("party1", "UNIT_MAXPOWER", "MANA")
equal(S[zrow.bar].high .. " " .. S[zrow.value].text .. " " .. BarColour(zrow), "1600 40% " .. BLUE, "more mana at most: the bar's top and the percent")
zelda.power, zelda.max = 200, 1000
before = Count(zrow.bar, "value")
equal(UnitFire("party1", "UNIT_POWER_UPDATE", "MANA") .. " " .. UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA") .. " " .. (Count(zrow.bar, "value") - before),
    "0 1 1", "one mana change: one update, not two")
settings.healerManaLow = 0
UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA")
equal(BarColour(zrow), BLUE, "Low Mana Colour off: blue at 20%")
settings.healerManaLow = 20
UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA")
equal(BarColour(zrow), AMBER, "at the line itself: amber (at or under)")
settings.healerManaLow = 15
UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA")
equal(BarColour(zrow), BLUE, "over the line: blue")
settings.healerManaLow = 30

-- Include Me, Every Mana User --------------------------------------------------------
Turn("healerManaSelf", true)
equal(Lines(), "Bram 75% | Squirt 80% | Zelda 20%", "Include Me: you, a priest with no role, by name")
Turn("healerManaSelf", false)
Turn("healerManaAll", true)
equal(Lines(), "Bram 75% | Corin 50% | Dax 90% | Zelda 20%", "Every Mana User: the tank druid and the damage paladin too")
equal(S[title].text, "Mana", "its title says Mana")
game.units.party3 = Person("Ulf", "WARRIOR", "TANK", 0, 100, { powerType = 1 })
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(Lines(), "Bram 75% | Dax 90% | Zelda 20%", "a warrior never")
Turn("healerManaAll", false)
equal(S[title].text, "Healer Mana", "and back to Healer Mana")
-- A mage set Healer counts: the role wins.
game.units.party3 = Person("Maya", "MAGE", "HEALER", 300, 1000)
Fire("PLAYER_ROLES_ASSIGNED"); Flush()
equal(Lines(), "Bram 75% | Maya 30% | Zelda 20%", "the Healer role counts, whatever the class")
game.units.party3 = corin
Fire("GROUP_ROSTER_UPDATE"); Flush()

-- Drinking, out of a fight -----------------------------------------------------------
zelda.auras = { { spellId = 1243, name = "Power Word: Fortitude" }, { spellId = 430, name = "Drink" } }
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20% Drinking", "a drink buff: the cup and Drinking")
equal(S[zrow.cup].texture .. " " .. S[zrow.drink].text, "Interface\\Icons\\INV_Drink_07 Drinking", "the game's drink icon")
zelda.auras = { { spellId = 999999, name = "Refreshment" } }
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20% Drinking", "Refreshment by its name")
zelda.auras = { { spellId = 26473, name = "Trinken" } }
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20% Drinking", "a drink by its spell ID, in any language")
-- A buff the game always hides, out of a fight too: passed over, never read.
zelda.auras = { { spellId = Secret("number"), name = Secret("string") }, { spellId = 430, name = "Drink" } }
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20% Drinking", "a hidden buff before the drink: passed over, the drink still found")
zelda.auras = { { spellId = 1243, name = Secret("string") }, { spellId = Secret("number"), name = "Drink" } }
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20% Drinking", "half hidden: a hidden name passed over, a drink found by its name")
zelda.auras = { { spellId = Secret("number"), name = Secret("string") } }
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20%", "only a hidden buff: no drink")
zelda.auras = { { spellId = 1243, name = "Power Word: Fortitude" } }
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20%", "no drink: no cup")
-- Auras the game hides out of a fight: no drink said, nothing read from them.
zelda.auras, zelda.secretAuras = { { spellId = 430, name = "Drink" } }, true
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20%", "hidden auras: no drink, no error")
zelda.secretAuras = nil
UnitFire("party1", "UNIT_AURA")
equal(Lines(), "Bram 75% | Zelda 20% Drinking", "drinking again")

-- A fight: the game hides their mana and auras --------------------------------------
combat, game.restricted = true, true
Fire("PLAYER_REGEN_DISABLED")
equal(Lines(), "Bram 75% | Zelda 20%", "a fight starts: Drinking goes (the game hides auras now)")
local reads = asked.auras
UnitFire("party1", "UNIT_AURA")
equal(asked.auras .. " " .. Lines(), reads .. " Bram 75% | Zelda 20%", "in a fight no aura is read")
UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA")
local bar = S[zrow.bar]
equal(issecretvalue(bar.high) and issecretvalue(bar.value) and bar.low == 0, true, "the bar takes the game's secret mana as it is")
equal(S[zrow.value].format .. " " .. tostring(issecretvalue(S[zrow.value].args[1])) .. " " .. S[zrow.value].text, "%.0f%% true <secret>",
    "the percent: the game's secret, straight to the text")
equal(issecretvalue(bar.barColour[1]) and bar.barColour[1] == secretColour[1] and bar.barColour[3] == secretColour[3], true,
    "Low Mana Colour: the game's own colour from a curve, never read")
local colours = made[#made]
equal(colours.colour == true and colours.kind == 0 and #colours.points, 4, "a linear colour curve of four points")
local p = colours.points
equal(string.format("%g %s %g %s %g %s %g %s", p[1][1], Colour({ p[1][2].r, p[1][2].g, p[1][2].b }), p[2][1], Colour({ p[2][2].r, p[2][2].g, p[2][2].b }),
    p[3][1], Colour({ p[3][2].r, p[3][2].g, p[3][2].b }), p[4][1], Colour({ p[4][2].r, p[4][2].g, p[4][2].b })),
    "0 " .. AMBER .. " 0.3 " .. AMBER .. " 0.3001 " .. BLUE .. " 1 " .. BLUE, "amber from empty to 30%, blue just past it")
equal(Colour({ colours:Evaluate(.25):GetRGB() }) .. " " .. Colour({ colours:Evaluate(.5):GetRGB() }), AMBER .. " " .. BLUE,
    "the curve: amber under the line, blue over it")
game.colourFails = true
UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA")
equal(BarColour(zrow), BLUE, "the game can't give a colour: blue")
game.colourFails = false
settings.healerManaLow = 0
UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA")
equal(BarColour(zrow), BLUE, "Low Mana Colour off in a fight: blue, no curve asked")
settings.healerManaLow = 30
-- Someone joins in the fight: the panel follows; their auras aren't read.
game.units.party3 = Person("Ivy", "DRUID", "NONE", 100, 1000, { auras = { { spellId = 430, name = "Drink" } } })
reads = asked.auras
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(Lines() .. " " .. asked.auras, "Bram <secret> | Ivy <secret> | Zelda <secret> " .. reads, "a new line in a fight, its mana the game's, no aura read")
-- The fight ends: the numbers read again, Drinking looked for again.
combat, game.restricted = false, false
Fire("PLAYER_REGEN_ENABLED")
equal(Lines(), "Bram 75% | Ivy 10% Drinking | Zelda 20% Drinking", "out of the fight: plain numbers and Drinking again")
equal(BarColour(Row("Ivy")) .. " " .. BarColour(Row("Bram")), AMBER .. " " .. BLUE, "colours worked out here again")
game.units.party3 = corin
zelda.auras = nil
Fire("GROUP_ROSTER_UPDATE"); Flush()

-- Offline and Dead ------------------------------------------------------------------
bram.offline = true
UnitFire("party2", "UNIT_CONNECTION")
equal(S[brow.value].text .. " " .. BarColour(brow) .. " " .. S[brow.bar].value, "Offline " .. GREY_BAR .. " 0", "offline: an empty grey bar")
bram.offline, bram.dead = nil, true
UnitFire("party2", "UNIT_POWER_FREQUENT", "MANA")
equal(S[brow.value].text .. " " .. BarColour(brow), "Dead " .. GREY_BAR, "dead: Dead in grey")
bram.dead = nil
UnitFire("party2", "UNIT_POWER_FREQUENT", "MANA")
equal(S[brow.value].text, "75%", "back")

-- Show in Party ------------------------------------------------------------------------
-- How many unit events the panel's lines listen for.
local function Heard()
    local n = 0
    for _, f in ipairs(all) do if S[f].parent == panel then for _ in pairs(S[f].units) do n = n + 1 end end end
    return n
end
Turn("healerManaParty", false)
equal(Shown(), false, "Show in Party off: hidden in a party")
local power = asked.power
equal(Heard() .. " " .. UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA") .. " " .. (asked.power - power), "0 0 0",
    "hidden: its lines listen for nothing, no mana read")
Turn("healerManaParty", true)
equal(tostring(Shown()) .. " " .. Lines() .. " " .. Heard(), "true Bram 75% | Zelda 20% 12", "on: shown, its lines listening again")
Party({ corin, dax })
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(tostring(Shown()) .. " " .. Heard(), "false 0", "no healers in the party: hidden, listening for nothing")
Party({})
game.grouped = false
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(Shown(), false, "on your own: hidden")

-- A raid ----------------------------------------------------------------------------
local raiders = {
    Person("Ash", "PRIEST", "NONE", 500, 1000, { group = 2 }),
    Person("Yara", "DRUID", "NONE", 600, 1000, { group = 1 }),
    Person("Mira", "PALADIN", "HEALER", 700, 1000, { group = 1 }),
    game.player,
    Person("Kel", "SHAMAN", "NONE", 0, 1000, { group = 3, offline = true }),
    Person("Bo", "PRIEST", "NONE", 0, 1000, { group = 2, dead = true }),
    Person("Rex", "WARRIOR", "NONE", 0, 100, { group = 1, powerType = 1 }),
}
game.player.group = 1
for i = 1, 7 do raiders[#raiders + 1] = Person("Heal" .. i, "PRIEST", "NONE", 400, 1000, { group = 4 + math.floor(i / 2) }) end
Raid(raiders)
local auraReads = asked.auras
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(Lines(), "Mira 70% | Yara 60% | Ash 50% | Bo Dead | Kel Offline | Heal1 40% | Heal2 40% | Heal3 40% | Heal4 40% | Heal5 40%",
    "by group then name, you left out, at most ten")
equal(asked.auras - auraReads, 10, "twelve healers, only the ten shown looked at for a drink")
equal(Colour(S[Row("Mira").name].textColour), "0.96,0.55,0.73", "a paladin in EraUI's pink")
equal(S[Row("Mira")].units.UNIT_POWER_FREQUENT .. " " .. S[Row("Ash")].units.UNIT_POWER_FREQUENT, "raid3 raid1", "raid lines listen for their raid unit")
equal(s.h, 7 + 22 + 10 * 18 + 7, "ten lines tall")
Turn("healerManaSelf", true)
equal(Lines():sub(1, 40), "Mira 70% | Squirt 80% | Yara 60% | Ash 5", "Include Me in a raid: you in your group")
Turn("healerManaSelf", false)
Turn("healerManaRaid", false)
power = asked.power
equal(tostring(Shown()) .. " " .. Heard() .. " " .. UnitFire("raid3", "UNIT_POWER_FREQUENT", "MANA") .. " " .. (asked.power - power), "false 0 0 0",
    "Show in Raid off: hidden in a raid, its ten lines listening for nothing")
Turn("healerManaRaid", true)
equal(tostring(Shown()) .. " " .. Heard(), "true 60", "on: shown, ten lines listening")
-- Names, classes and roles the game hides.
raiders[2].secretName = true
raiders[1].secretClass, raiders[1].secretRole = true, true
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(Lines():sub(1, 30), "Mira 70% | <secret> 60% | Bo D", "a hidden name shows as it is, last in its group; a hidden class and role don't count")
local hiddenRow = RowFrames()[2]
equal(issecretvalue(S[hiddenRow.name].text) and Colour(S[hiddenRow.name].textColour), "1.00,0.49,0.04", "the hidden name straight to the text, still in its class colour")
Turn("healerManaAll", true)
equal(Lines():find("Ash", 1, true) ~= nil and Lines():find("Rex", 1, true) == nil, true, "Every Mana User: a hidden class counts by the power it uses now")
raiders[1].powerType = 1
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(Lines():find("Ash", 1, true), nil, "and not while that's rage")
raiders[1].powerType = nil
Turn("healerManaAll", false)
raiders[2].secretName, raiders[1].secretClass, raiders[1].secretRole = nil, nil, nil

-- Unlock, drag, lock -------------------------------------------------------------------
Party({})
game.grouped = false
Fire("GROUP_ROSTER_UPDATE"); Flush()
local watched = {}
Module.watch = function(on) watched[#watched + 1] = tostring(on) end
equal(Module:SetUnlocked(true), true, "unlocked")
equal(Shown() and s.mouse and s.h, 7 + 22 + 3 * 18 + 16 + 7, "on your own, unlocked: shown, taking the mouse, sample lines and the hint")
equal(Lines(), "Priest 85% | Druid 42% Drinking | Shaman 18%", "the sample lines")
equal(BarColour(Row("Shaman")) .. " " .. BarColour(Row("Priest")), AMBER .. " " .. BLUE, "a sample low on mana in amber")
local hint
for _, f in ipairs(all) do if S[f].parent == panel and S[f].kind == "FontString" and S[f].text == "Drag to move. Right-click to lock." then hint = f end end
equal(hint ~= nil and S[hint].shown, true, "how to move it, under the lines")
s.scripts.OnDragStart(panel)
s.left, s.top = 412.4, 560.6
s.scripts.OnDragStop(panel)
equal(Count(panel, "moving") .. " " .. Count(panel, "stopped") .. " " .. tostring(s.userPlaced), "1 1 false", "dragged, stopped, the game's mark let go")
equal(settings.healerManaPosition.x .. "," .. settings.healerManaPosition.y .. " " .. saves, "412,-207 1", "its top left corner kept, in the screen's units")
equal(Point(panel), "TOPLEFT UIParent TOPLEFT 412 -207", "and held there")
s.scripts.OnMouseUp(panel, "LeftButton")
equal(Module.unlocked, true, "a left click doesn't lock it")
s.scripts.OnMouseUp(panel, "RightButton")
equal(tostring(Module.unlocked) .. " " .. tostring(Shown()) .. " " .. tostring(s.mouse) .. " " .. table.concat(watched, ","), "false false false true,false",
    "a right-click locks it: on your own it hides, no mouse, /era hears of it")
s.scripts.OnDragStart(panel)
equal(Count(panel, "moving"), 1, "locked: no drag")
equal(Module:SetUnlocked(true), true, "unlocked again")
s.scripts.OnDragStart(panel)
s.left, s.top = 100, 700
combat = true
Fire("PLAYER_REGEN_DISABLED")
equal(tostring(Module.unlocked) .. " " .. settings.healerManaPosition.x .. "," .. settings.healerManaPosition.y .. " " .. table.concat(watched, ","),
    "false 100,-68 true,false,true,false", "a fight locks it, ending a drag where it is")
combat = false
Fire("PLAYER_REGEN_ENABLED")
-- Size: the same spot on screen at any size.
Module:SetUnlocked(true)
Turn("healerManaScale", 150)
equal(s.scale .. " " .. Point(panel), "1.5 TOPLEFT UIParent TOPLEFT 66.6667 -45.3333", "Size 150%: bigger, at the same spot")
Turn("healerManaScale", 999)
equal(s.scale, 1.5, "never over 150%")
Turn("healerManaScale", "big")
equal(s.scale, 1, "unreadable: 100%")
-- Bar Width.
Turn("healerManaWidth", 200)
equal(S[Row("Priest").bar].w .. " " .. s.w, "200 296", "Bar Width 200: longer bars, a wider panel")
Turn("healerManaWidth", 20)
equal(S[Row("Priest").bar].w, 100, "never under 100")
Turn("healerManaWidth", 130)
-- Flat Bars: a plain fill.
Turn("flatBars", true)
equal(S[Row("Priest").bar].texture, "Interface\\Buttons\\WHITE8X8", "Flat Bars: a plain fill")
Turn("flatBars", false)
equal(S[Row("Priest").bar].texture, "Interface\\TargetingFrame\\UI-StatusBar", "and the Classic bar again")
-- Reset.
Module:ResetPosition()
equal(tostring(settings.healerManaPosition) .. " " .. Point(panel), "nil TOPRIGHT UIParent RIGHT -96 -110", "Reset: back at its first spot")
Module:SetUnlocked(false)
equal(Shown(), false, "locked on your own: hidden")

-- The /era preview, and Dark Mode --------------------------------------------------------
window:Show()
equal(Shown() and Lines(), "Priest 85% | Druid 42% Drinking | Shaman 18%", "/era open: the preview, where it is")
equal(tostring(s.mouse) .. " " .. Point(panel), "false TOPRIGHT UIParent RIGHT -96 -110", "never moved for it, and locked")
window:Hide()
equal(Shown(), false, "/era closed: hidden again")
settings.darkMode = true
Module:Paint()
equal(Colour(S[title].textColour), "0.93,0.93,0.94", "Dark Mode: a light title")
local edge
for _, f in ipairs(all) do if S[f].parent == panel and S[f].kind == "Texture" and S[f].layer == "BORDER" and S[f].colour and S[f].colour[1] < .3 and S[f].colour[1] > .2 then edge = f end end
equal(edge ~= nil and Colour(S[edge].colour), "0.21,0.22,0.24", "an edge in the Darkness grey, half as light")
settings.darkMode = false
Module:Paint()

-- Off again --------------------------------------------------------------------------
Party({ zelda, bram })
Fire("GROUP_ROSTER_UPDATE"); Flush()
equal(Shown(), true, "a party again: shown")
Module:SetUnlocked(true)
Turn("healerMana", false)
local listening = 0
for _, f in ipairs(all) do
    for _ in pairs(S[f].units) do listening = listening + 1 end
    if S[f].name ~= nil and S[f].name ~= "EraUIHealerMana" and S[f].name ~= "UIParent" and S[f].name ~= "EraUISettingsFrame" then listening = listening + 100 end
end
local driverEvents = 0
for _ in pairs(S[Driver()].events) do driverEvents = driverEvents + 1 end
equal(tostring(Shown()) .. " " .. listening .. " " .. driverEvents .. " " .. tostring(Module.unlocked) .. " " .. tostring(s.mouse), "false 0 0 false false",
    "off: hidden, locked, no line or group events")
equal(Module:SetUnlocked(true), false, "off: nothing to unlock")
UnitFire("party1", "UNIT_POWER_FREQUENT", "MANA")
equal(Shown(), false, "and nothing comes back")

-- Nothing of the game's touched -----------------------------------------------------------
local touched = {}
for key in pairs(UIParent) do touched[#touched + 1] = tostring(key) end
equal(table.concat(touched, ",") .. "|" .. table.concat(forbidden, ","), "|", "no key written on UIParent; no tooltip, hooks, bindings or casts")

-- /era > Group & Invites > Healer mana -----------------------------------------------------
-- The real window (Tools/SettingsMock.lua); the module's stand-in counts
-- what the rows ask of it.
local moduleChecks = checks
local M = dofile("Tools/SettingsMock.lua")
local Session, Open, Flush2 = M.Session, M.Open, M.Flush
local function Keys(f) return table.concat(M.Keys(f), ",") end
local said
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
local Ex, f = Session("PRIEST", nil, nil, nil, function(Ex) Ex.modules.HealerMana = stub end)
for key, value in pairs(real.settingDefaults) do
    if key:find("^healerMana") then Ex.settings[key], Ex.settingDefaults[key] = value, value end
end
Ex.Status = function(_, text) said = text end
f:Hide(); f:Show(); Flush2()
Open(f, "group")
equal(f.sectionAbout:GetText(), "Friends, guild, group finder, invites and healer mana.", "Group & Invites says it has healer mana")
equal(Keys(f), "socialWindows,groupFinderPvp,blockDuels,blockPartyInvites,partyFromFriends,inviteFromWhispers,autoSummon,autoResurrect,releasePvP,healerMana",
    "Healer Mana: its switch alone while it's off, after Invites and requests")
local switch = f.checks.healerMana
equal(switch.text:GetText() .. " " .. tostring(switch:GetChecked()), "Healer Mana false", "its tick, off")
switch:Click(); Flush2()
equal(tostring(Ex.settings.healerMana) .. " " .. calls.refresh .. " " .. tostring(said), "true 1 Healer Mana enabled. It shows in a party or raid; Unlock under it to move it.",
    "switched on: the panel follows, chat says how to move it")
equal(Keys(f):match("healerMana.*$"), "healerMana,healerManaUnlock,healerManaSelf,healerManaAll,healerManaParty,healerManaRaid,healerManaWidth,"
    .. "healerManaScale,healerManaLow,healerManaPlace", "its options show under it, in order")
M.NoOverlaps(f, "Healer Mana"); M.Fits(f, "Healer Mana")
equal(tostring(f.checks.healerManaSelf:GetChecked()) .. " " .. tostring(f.checks.healerManaAll:GetChecked()) .. " " .. tostring(f.checks.healerManaParty:GetChecked())
    .. " " .. tostring(f.checks.healerManaRaid:GetChecked()), "false false true true", "Include Me and Every Mana User off, Show in Party and Raid on")
equal(f.checks.healerManaWidth.text:GetText() .. " / " .. f.checks.healerManaScale.text:GetText() .. " / " .. f.checks.healerManaLow.text:GetText(),
    "Bar Width: 130 px / Size: 100% / Low Mana Colour: 30%", "the sliders at their defaults")
f.checks.healerManaSelf:Click(); Flush2()
equal(tostring(Ex.settings.healerManaSelf) .. " " .. calls.refresh .. " " .. said, "true 2 Healer Mana: Include Me on.", "a tick: saved, the panel follows, said")
f.checks.healerManaRaid:Click(); Flush2()
equal(tostring(Ex.settings.healerManaRaid) .. " " .. said, "false Healer Mana: Show in Raid off.", "Show in Raid off")
f.checks.healerManaWidth.slider:SetValue(200)
equal(Ex.settings.healerManaWidth .. " " .. f.checks.healerManaWidth.text:GetText() .. " " .. calls.refresh, "200 Bar Width: 200 px 4", "Bar Width saved, the panel follows")
f.checks.healerManaScale.slider:SetValue(75)
equal(Ex.settings.healerManaScale .. " " .. f.checks.healerManaScale.text:GetText(), "75 Size: 75%", "Size in percent")
f.checks.healerManaLow.slider:SetValue(0)
equal(Ex.settings.healerManaLow .. " " .. f.checks.healerManaLow.text:GetText(), "0 Low Mana Colour: Off", "Low Mana Colour at 0 says Off")
f.checks.healerManaLow.slider:SetValue(45)
equal(f.checks.healerManaLow.text:GetText(), "Low Mana Colour: 45%", "and a percent")
-- Move Panel: Unlock, then Lock; refused while the module says no.
local unlock = f.checks.healerManaUnlock
unlock.button:Click()
equal(table.concat(calls.unlock, ",") .. " " .. unlock.button.label:GetText() .. " " .. said, "true Unlock Healer Mana: switch it on first, then unlock.",
    "the module says no: the button stays Unlock")
stub.allowed = true
unlock.button:Click()
equal(unlock.button.label:GetText() .. " " .. said, "Lock Healer Mana: drag the panel to move it. Lock, or right-click it, when you're done.", "unlocked: the button says Lock")
stub.unlocked = false
stub.watch(false)
equal(unlock.button.label:GetText(), "Unlock", "the panel locking itself (a right-click, a fight) puts the button back")
unlock.button:Click()
unlock.button:Click()
equal(table.concat(calls.unlock, ",") .. " " .. unlock.button.label:GetText() .. " " .. said, "true,true,true,false Unlock Healer Mana: panel locked.", "Lock again")
f.checks.healerManaPlace.button:Click()
equal(calls.reset .. " " .. said, "1 Healer Mana: the panel is back where it starts.", "Reset Position")
-- The footer: each row's own words and default.
local function Hover(key) local _, help, extras = M.Hover(f, f.checks[key]); return help, extras end
local help, extras = Hover("healerMana")
equal(help:find("Out of a fight it shows who's drinking.", 1, true) ~= nil and extras, "Default: Off.", "the switch: what it shows, off by default")
help, extras = Hover("healerManaLow")
equal(help:find("In a fight the game can hide other players' mana, and then it stays blue.", 1, true) ~= nil and extras, "Default: 30%.",
    "Low Mana Colour says it stays blue where the game hides the mana")
_, extras = Hover("healerManaWidth")
equal(extras, "Default: 130 px.", "Bar Width's default")
_, extras = Hover("healerManaScale")
equal(extras, "Default: 100%.", "Size's default")
_, extras = Hover("healerManaParty")
equal(extras, "Default: On.", "Show in Party on by default")
help, extras = Hover("healerManaAll")
equal(help:find("priests, druids, paladins and shamans", 1, true) ~= nil and extras, "Default: Off.", "Every Mana User says who counts as a healer")
_, extras = Hover("healerManaUnlock")
equal(extras, "", "Move Panel has no default")
for key in pairs(f.checks) do
    if key:find("^healerMana") then
        local words = Hover(key)
        equal(M.LinesIn(words, 570, 12) <= 2 and words:find("\226\128\148", 1, true) == nil, true, key .. " fits two footer lines, no em dash: " .. words)
    end
end
-- Search finds them by their words, never by a class name.
local found = M.Results(f, "healer mana")
equal(table.concat(found, ","), "healerMana,healerManaUnlock,healerManaSelf,healerManaAll,healerManaParty,healerManaRaid,healerManaWidth,"
    .. "healerManaScale,healerManaLow,healerManaPlace", "healer mana finds all ten")
equal(table.concat(M.Results(f, "drinking"), ","), "healerMana", "drinking finds the switch")
local druid = table.concat(M.Results(f, "druid"), ",")
equal(druid:find("healerMana", 1, true), nil, "druid finds none of them")
f.searchBox:SetText(""); Flush2()
switch:Click(); Flush2()
equal(tostring(Ex.settings.healerMana) .. " " .. tostring(said) .. " " .. tostring(Keys(f):find("healerManaUnlock", 1, true)), "false Healer Mana disabled. nil",
    "off again: said, its rows fold away")
equal(f:JumpTo("healerManaLow"), switch, "a jump to a folded slider lands on the switch")

print("Healer Mana checks passed: " .. checks .. " assertions (" .. moduleChecks .. " on the panel, " .. (checks - moduleChecks) .. " on /era).")
