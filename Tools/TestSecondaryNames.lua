-- Hide Surnames (Modules/SecondaryNames.lua) on a small mock of the game.
-- The game's surname switches: left alone while the option is off and EraUI
-- never owned them (the game's own "My surname" box keeps the player's
-- choice through every loading screen, 2026-10-17 audit A4); owned and kept
-- at "0" while it is on; given back once, at the game's default, when it
-- goes off. On Tooltips Too: players' names on unit tooltips trimmed to the
-- first name from the game's own unit tooltip post-call, only with both
-- switches on, only for players, never with a hidden value, and nothing on
-- the tooltip but the name line's text.
-- Run from the addon directory.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local settings = {}
local cvars, defaults, writes = {}, {UnitSurnameOwn = "1"}, {}
local postCalls, hooks = {}, {}
local secrets = setmetatable({}, {__mode = "k"})
local units = {}
local frames = {}

issecretvalue = function(value) return type(value) == "table" and secrets[value] == true end
C_CVar = {
    GetCVar = function(name) return cvars[name] end,
    SetCVar = function(name, value) writes[#writes + 1] = name .. "=" .. value; cvars[name] = value end,
    GetCVarDefault = function(name) return defaults[name] end,
}
CHAT_FRAMES = {}
hooksecurefunc = function(name) hooks[#hooks + 1] = name end
CreateFrame = function()
    local f = {events = {}, scripts = {}}
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(kind, fn) self.scripts[kind] = fn end
    frames[#frames + 1] = f
    return f
end
Enum = {TooltipDataType = {Item = 0, Spell = 1, Unit = 2}, TooltipDataLineType = {None = 0, UnitName = 2}}
Constants = {CharacterNameSeparatorConsts = {CHARACTERNAME_SURNAME_SEPARATOR = " "}}
TooltipDataProcessor = {AddTooltipPostCall = function(kind, fn) postCalls[#postCalls + 1] = {kind = kind, fn = fn} end}
UnitTokenFromGUID = function(guid) return units[guid] and units[guid].token end
UnitName = function(unit)
    for _, record in pairs(units) do
        if record.token == unit then return record.first, record.surname end
    end
end

EraUIDB = {}
local E = {modules = {}}
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return settings[key] end
assert(loadfile("Modules/SecondaryNames.lua"))("EraUI", E)
local M = E.modules.SecondaryNames

local function Fire(event)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end
local function Tick(seconds)
    for _, f in ipairs(frames) do
        if f.scripts.OnUpdate then f.scripts.OnUpdate(f, seconds) end
    end
end

---------------------------------------------------------------------------
-- The game's surname switches (audit A4)
---------------------------------------------------------------------------

-- Off, never owned: the player's own "My surname" choice (off) stays.
cvars.UnitSurnameOwn = "0"
settings.hideSecondaryNames = false
M:Initialize()
Fire("PLAYER_ENTERING_WORLD")
Tick(3); Tick(3)
Equal(#writes, 0, "off and never owned: no surname switch written at login, a loading screen or later")
Equal(cvars.UnitSurnameOwn, "0", "the game's My surname box keeps the player's choice")
Equal(EraUIDB.secondaryNamesOwned, nil, "not owned")
Equal(#postCalls, 0, "with Hide Surnames off nothing is added to the game's tooltips")

-- Switched on: owned, every switch the game has at "0", none made up.
cvars.UnitSurnameOwn = "1"
settings.hideSecondaryNames = true
M:Apply()
Equal(table.concat(writes, ","), "UnitSurnameOwn=0", "on: the game's one surname switch at 0, no unknown switch created")
Equal(EraUIDB.secondaryNamesOwned, true, "on: owned")
Equal(#postCalls .. " " .. tostring(postCalls[1] and postCalls[1].kind), "1 2", "on: one post-call on the game's unit tooltips")
-- While on, a switch the game puts back is set again within two seconds.
cvars.UnitSurnameOwn = "1"
Tick(1)
Equal(cvars.UnitSurnameOwn, "1", "not before two seconds")
Tick(1.5)
Equal(cvars.UnitSurnameOwn, "0", "kept at 0 while on")
M:Apply(); M:Apply()
Equal(#postCalls, 1, "the post-call is added once, however often it applies")

-- A lost SavedVariables file (the flag gone) with the option still on: owned again.
EraUIDB = {}
writes = {}
M:Apply()
Equal(tostring(EraUIDB.secondaryNamesOwned) .. " " .. #writes, "true 0", "still on after lost SavedVariables: owned again, nothing to change")

-- Switched off: each switch back at the game's default once, then the player's.
writes = {}
settings.hideSecondaryNames = false
M:Apply()
Equal(table.concat(writes, ","), "UnitSurnameOwn=1", "off: given back once, at the game's default")
Equal(EraUIDB.secondaryNamesOwned, nil, "no longer owned")
writes = {}
cvars.UnitSurnameOwn = "0" -- the player unticks the game's box afterwards
Fire("PLAYER_ENTERING_WORLD"); Tick(5); M:Apply()
Equal(#writes .. " " .. cvars.UnitSurnameOwn, "0 0", "a later loading screen writes nothing: the player's choice stays")
-- An old copy's backup key is never used.
EraUIDB.secondaryNameBackup = "0"
settings.hideSecondaryNames = true; M:Apply()
Equal(EraUIDB.secondaryNameBackup, nil, "the old backup key is dropped, never restored")
settings.hideSecondaryNames = false; M:Apply()
Equal(cvars.UnitSurnameOwn, "1", "off again: the game's default, never an old saved 0")

-- /era reset (Core/Commands.lua) hands owned switches back before its
-- reload: afterwards Hide Surnames is off and nothing records the ownership.
writes = {}
M:HandBack()
Equal(#writes, 0, "reset while never owned: nothing written")
settings.hideSecondaryNames = true; M:Apply()
Equal(cvars.UnitSurnameOwn .. " " .. tostring(EraUIDB.secondaryNamesOwned), "0 true", "on again: owned")
writes = {}
M:HandBack()
Equal(table.concat(writes, ",") .. " " .. tostring(EraUIDB.secondaryNamesOwned), "UnitSurnameOwn=1 nil",
    "reset while owned: given back at the game's default before the reload")
Equal(M.handingBack, nil, "the hand-back is over")
EraUIDB, settings.hideSecondaryNames = {}, false -- the reload after the reset
writes = {}
Fire("PLAYER_ENTERING_WORLD"); Tick(5)
Equal(#writes .. " " .. cvars.UnitSurnameOwn, "0 1", "after the reset: nothing written, the game's default stays")

---------------------------------------------------------------------------
-- On Tooltips Too
---------------------------------------------------------------------------

local Trim = postCalls[1].fn
local function Label(text)
    local label = {text = text}
    function label:GetText() return self.text end
    function label:SetText(value) self.text = value; self.sets = (self.sets or 0) + 1 end
    return label
end
-- A tooltip whose own methods are counted, so the trim is seen to call none
-- but IsForbidden, and to write no key on it.
local calls = {}
local function Tooltip(first, second, forbidden)
    local tip = {TextLeft1 = Label(first), TextLeft2 = Label(second or "")}
    function tip:IsForbidden() calls[#calls + 1] = "IsForbidden"; return forbidden == true end
    for _, method in ipairs({"AddLine", "AddDoubleLine", "SetText", "Show", "Hide", "SetOwner", "ClearLines", "GetUnit", "NumLines", "GetName"}) do
        tip[method] = function() calls[#calls + 1] = method end
    end
    return tip
end
local function Keys(tip)
    local list = {}
    for key in pairs(tip) do list[#list + 1] = tostring(key) end
    table.sort(list)
    return table.concat(list, ",")
end
local function Data(guid, index)
    return {type = 2, guid = guid, lines = {{type = 2, lineIndex = index or 1, leftText = "?"}, {type = 0, lineIndex = (index or 1) + 1}}}
end
units["Player-1-0001"] = {token = "mouseover", first = "Zriel", surname = "Gustbellow"}
units["Player-1-0002"] = {token = "target", first = "Light", surname = nil}
units["Player-1-0003"] = {token = "party1", first = "Tabitantu Stagkiller", surname = nil}
units["Creature-0-1-2-3-4-5"] = {token = "npc", first = "Stormwind", surname = "Guard"}

settings.hideSecondaryNames, settings.hideSecondaryNamesTooltips = true, true
local tip = Tooltip("Zriel Gustbellow")
local before = Keys(tip)
calls = {}
Trim(tip, Data("Player-1-0001"))
Equal(tip.TextLeft1.text, "Zriel", "a player's name line: the first name alone")
Equal(table.concat(calls, ","), "IsForbidden", "no tooltip method run but IsForbidden")
Equal(Keys(tip), before, "no key written on the tooltip")
Equal(tip.TextLeft1.sets, 1, "the name line's text set once")
Trim(tip, Data("Player-1-0001"))
Equal(tip.TextLeft1.sets, 1, "a name already trimmed is left alone")

tip = Tooltip("Sergeant Zriel Gustbellow")
Trim(tip, Data("Player-1-0001"))
Equal(tip.TextLeft1.text, "Sergeant Zriel", "a title before the name is kept")
tip = Tooltip("|cff40c040Zriel Gustbellow|r <AFK>")
Trim(tip, Data("Player-1-0001"))
Equal(tip.TextLeft1.text, "|cff40c040Zriel|r <AFK>", "colour and what follows the name are kept")
tip = Tooltip("Tabitantu Stagkiller")
Trim(tip, Data("Player-1-0003"))
Equal(tip.TextLeft1.text, "Tabitantu", "a whole name given as one value is trimmed too")
tip = Tooltip("Somebody", "Zriel Gustbellow")
Trim(tip, Data("Player-1-0001", 2))
Equal(tip.TextLeft1.text .. "|" .. tip.TextLeft2.text, "Somebody|Zriel", "the line the game marks as the name, not just the first")

-- Left alone.
local function Untouched(label, text, data, setup, undo)
    if setup then setup() end
    local t = Tooltip(text)
    Trim(t, data)
    Equal(t.TextLeft1.text, text, label)
    if undo then undo() end
end
Untouched("no surname: nothing to trim", "Light", Data("Player-1-0002"))
Untouched("an NPC is never touched", "Stormwind Guard", Data("Creature-0-1-2-3-4-5"))
Untouched("no unit for the GUID: left alone", "Zriel Gustbellow", Data("Player-1-0099"))
Untouched("On Tooltips Too off", "Zriel Gustbellow", Data("Player-1-0001"),
    function() settings.hideSecondaryNamesTooltips = false end, function() settings.hideSecondaryNamesTooltips = true end)
Untouched("Hide Surnames off", "Zriel Gustbellow", Data("Player-1-0001"),
    function() settings.hideSecondaryNames = false end, function() settings.hideSecondaryNames = true end)
Untouched("another name on the line: left alone", "Someone Else", Data("Player-1-0001"))
do
    local t = Tooltip("Zriel Gustbellow", nil, true)
    Trim(t, Data("Player-1-0001"))
    Equal(t.TextLeft1.text, "Zriel Gustbellow", "a forbidden tooltip is never touched")
end
-- Hidden values: the GUID, the unit, the name or the line's text.
local hidden = {}
secrets[hidden] = true
Untouched("a hidden GUID", "Zriel Gustbellow", {type = 2, guid = hidden, lines = {}})
do
    local real = UnitTokenFromGUID
    UnitTokenFromGUID = function() return hidden end
    Untouched("a hidden unit", "Zriel Gustbellow", Data("Player-1-0001"))
    UnitTokenFromGUID = function() error("no such unit") end
    Untouched("a failing unit lookup", "Zriel Gustbellow", Data("Player-1-0001"))
    UnitTokenFromGUID = real
    units["Player-1-0001"].surname = hidden
    Untouched("a hidden surname", "Zriel Gustbellow", Data("Player-1-0001"))
    units["Player-1-0001"].surname = "Gustbellow"
    units["Player-1-0001"].first = hidden
    Untouched("a hidden first name", "Zriel Gustbellow", Data("Player-1-0001"))
    units["Player-1-0001"].first = "Zriel"
    local t = Tooltip("Zriel Gustbellow")
    t.TextLeft1.text = hidden
    Trim(t, Data("Player-1-0001"))
    Equal(t.TextLeft1.text, hidden, "a hidden name line is never read into, nor set")
    local data = Data("Player-1-0001")
    data.lines[1].lineIndex = hidden
    t = Tooltip("Zriel Gustbellow")
    Trim(t, data)
    Equal(t.TextLeft1.text, "Zriel", "a hidden line number: the first line")
end
-- Odd data never errors.
Trim(nil, nil); Trim(Tooltip("x"), nil); Trim(Tooltip("x"), {guid = "Player-1-0001", lines = "?"})
Trim({}, Data("Player-1-0001"))
Equal(true, true, "odd tooltips and data pass without an error")
-- A game without the post-call API or the unit type: nothing added, no error.
do
    local real = TooltipDataProcessor
    TooltipDataProcessor = nil
    M.watchingTooltips = nil
    M:WatchTooltips()
    Equal(M.watchingTooltips, nil, "no post-call API: nothing watched")
    TooltipDataProcessor = real
    M:WatchTooltips()
    Equal(#postCalls, 2, "and asked again once it is there")
end

print("Secondary names checks passed: " .. checks .. " assertions.")
