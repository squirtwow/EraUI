-- EraUI's Classic engine, part one: the namespace every Classic file shares
-- (EraUI.Classic), the Classic settings table (EraUIClassicDB) with the
-- value each setting starts at, the copy of every changed setting kept in
-- one account CVar (Forever often forgets its saved files), and the small
-- helpers the rest lean on: chat lines, protected calls, the build check.
--
-- Loaded before Core/Appearance.lua, which adds Dark Mode to this same table
-- as it loads, and before every file that registers a part of the look.
-- Needs nothing but the game's API (a test loads it with Core/Init.lua and
-- Core/Persistence.lua alone). Part two, Look/EnginePass.lua, has the list
-- of look parts, the pass, the toggles and the events after the first load.
local ADDON, EraUI = ...

local ns = {}
EraUI.Classic = ns
ns.ADDON = ADDON

local COPY_CVAR = "EraUIClassicSettings"
local CHAT_PREFIX = "|cffe6c56cEraUI:|r "

local unpack = unpack or table.unpack

local function Hidden(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

---------------------------------------------------------------------------
-- Where every Classic setting starts. The CVar copy keeps only values that
-- differ from these, so none of them may ever change: a changed start would
-- silently change a player's choice. Files that load later add their own
-- keys to this same table before the saved table is read.
---------------------------------------------------------------------------

local STARTS = {}
ns.DB_DEFAULTS = STARTS

local function StartAs(value, keys)
    for key in keys:gmatch("%S+") do STARTS[key] = value end
end

StartAs(true, [[classicBar buttons castAnim emptySlots squareIcons professionsBook tradeSkill trainer
    tradeSkillSearch talents hideBuffArrow spellDrag bagsBesideBars gameDamageNumbers hideExtraBars unitFrames
    castBars mirrorTimers comboPoints welcomeNote minimap namePlates fullPlates questTracker questLog
    unitFramePlayer unitFrameTarget unitFrameFocus unitFramePet unitFrameParty questMapPane gameMenu settingsPanel
    panels bags characterSheet spellBook guildRoster whoList spellBookSearch]])
StartAs(false, [[oneBar defaultBarSize oneBag bagsAboveRow barDragged bagsHeld capHeldLeft capHeldRight
    whoTabs spellBookTopRank layoutSelectPending pinShape bagsFirst hideLastNames classColorHealth
    classColorPlates mapFade questLogDual statPanes damageMeter welcomed]])
StartAs(0, "barOffsetX barOffsetY bagsSnapScale layoutSelectTries")
StartAs(1, "dbVersion microScale")
StartAs("", "previousLayout microPosText")
STARTS.oneBagColumns = 8

-- Settings nothing reads any more: the old bar scale, the old minimap
-- button and its angle (EraUI's own button is Modules/MinimapTools.lua's),
-- the copies of /era's retired reminder place and size, and the professions
-- window's old tab arrow. Taken out of the saved table and its CVar copy each
-- time it loads, never written back.
local RETIRED = { "barScale", "minimapButton", "minimapButtonAngle", "eraui_reminderX", "eraui_reminderY",
    "eraui_reminderScale", "professionTabs" }
ns.RETIRED_KEYS = RETIRED
STARTS.whoColumn, STARTS.textureSource = "zone", "builtin"
STARTS.statPaneLeft, STARTS.statPaneRight = "section2", "section3"

-- The parts that leave old art on screen when switched off (or, for the
-- spellbook, hand back entries that misbehave): turning one off asks for a
-- reload. groupFinder has no start of its own (Core/Integration.lua sets it
-- from the group finder's /era setting).
local reloadAsked = {}
for key in ([[bags castBars characterSheet classicBar comboPoints gameMenu minimap namePlates panels
    professionsBook tradeSkill groupFinder questMapPane questTracker settingsPanel unitFrames spellBook]]):gmatch("%S+") do
    reloadAsked[key] = true
end
ns.RELOAD_KEYS = reloadAsked

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

-- A developer tool may listen to EraUI's log lines: it is handed the
-- namespace through EraUIClassic_AttachDevTools and sets ns.devLog (a
-- function given each line) and ns.devFlush. Without one nothing is kept:
-- EraUI never writes a file.
local function DevLine(line)
    local sink = ns.devLog
    if type(sink) == "function" then pcall(sink, line) end
end

local function DevFlush()
    local flush = ns.devFlush
    if type(flush) == "function" then pcall(flush) end
end

-- A heading line for the debug commands' output.
local function DevHeading(title)
    local stamp = type(date) == "function" and date("%Y-%m-%d %H:%M:%S") or "?"
    DevLine("=== " .. tostring(title) .. " " .. stamp .. " ===")
end

-- One chat line after the gold "EraUI:". A value the game keeps hidden is
-- never turned into text.
local function Say(message)
    local text = Hidden(message) and "<protected value>" or tostring(message)
    local chat = DEFAULT_CHAT_FRAME
    if chat and chat.AddMessage then chat:AddMessage(CHAT_PREFIX .. text) end
    DevLine(text)
end

-- WoW: Forever reports an interface number in the 16000s. Branches key off
-- the build, never off whether some function happens to exist.
local function IsForever()
    if type(GetBuildInfo) ~= "function" then return false end
    local interface = select(4, GetBuildInfo())
    return type(interface) == "number" and interface >= 16000 and interface < 17000
end

-- fn(...) in a protected call: an error is shown through the game's error
-- handler, never stops the caller. Returns ok, then the first result (or the
-- error).
local function Shown(problem)
    local handler = type(geterrorhandler) == "function" and geterrorhandler()
    if handler then pcall(handler, problem) end
    return problem
end

local function Protected(fn, ...)
    local count, given = select("#", ...), { ... }
    return xpcall(function() return fn(unpack(given, 1, count)) end, Shown)
end

-- Action Bar 1 under either of its names.
local function MainBar()
    return _G.MainActionBar or _G.MainMenuBar
end

ns.Persist, ns.FlushNotice, ns.BeginOutput, ns.Print = DevLine, DevFlush, DevHeading, Say
ns.OnForever, ns.SafeCall, ns.GetMainBar = IsForever, Protected, MainBar

-- A developer tool's way in (nothing in EraUI calls it).
EraUIClassic_AttachDevTools = function(attach)
    if type(attach) == "function" then attach(ns) end
end

---------------------------------------------------------------------------
-- The CVar copy of the Classic settings. One string: "key=value" pairs,
-- sorted, joined by ";"; each value a letter and its text (b1 or b0 for a
-- yes or no, n and a number, s and a word). Used only on Forever, where the
-- saved file is often not read back; elsewhere the saved file is enough.
---------------------------------------------------------------------------

local function CopyUsable()
    local cvars = C_CVar
    return ns.OnForever() and type(cvars) == "table" and type(cvars.RegisterCVar) == "function"
        and type(cvars.SetCVar) == "function" and type(cvars.GetCVar) == "function"
end

-- A value as the copy writes it, or nil when it isn't kept. Numbers are
-- written the way the game's Lua turns them into text.
local function Coded(value)
    local kind = type(value)
    if kind == "boolean" then return value and "b1" or "b0" end
    if kind == "number" then return "n" .. string.format("%.14g", value) end
    if kind == "string" and not value:find("[;=]") then return "s" .. value end
    return nil
end

local function Decoded(kind, text)
    if kind == "b" then return text == "1" end
    if kind == "n" then return tonumber(text) end
    return text
end

-- The micro menu's own place as text, "point,relPoint,x,y" (x and y to one
-- decimal), so it survives a lost saved table.
local function MenuPlaceText(place)
    if type(place) ~= "table" or type(place[1]) ~= "string" then return "" end
    local other = type(place[2]) == "string" and place[2] or place[1]
    return string.format("%s,%s,%.1f,%.1f", place[1], other, tonumber(place[3]) or 0, tonumber(place[4]) or 0)
end

-- Writes every changed Classic setting into the CVar. Nothing while a
-- settings reset waits for its reload. Core/Integration.lua puts its own
-- step in front (EraUI's /era choices copied in first), so it is reached as
-- ns.MirrorSave everywhere.
local function SaveCopy()
    local saved, keeper = ns.db, EraUI.Persistence
    if (keeper and keeper.resetting) or not saved or not CopyUsable() then return end
    saved.microPosText = MenuPlaceText(saved.microPos)
    local parts = {}
    for key, start in pairs(STARTS) do
        local now = saved[key]
        if now ~= nil and now ~= start then
            local text = Coded(now)
            if text then parts[#parts + 1] = key .. "=" .. text end
        end
    end
    table.sort(parts)
    pcall(C_CVar.SetCVar, COPY_CVAR, table.concat(parts, ";"))
end
ns.MirrorSave = SaveCopy

-- The copy read back over the saved table. The CVar is read before it is
-- registered, so registering never resets a value the game kept.
local function ReadCopy(saved)
    if not CopyUsable() then return end
    local cvars = C_CVar
    local fine, text = pcall(cvars.GetCVar, COPY_CVAR)
    if not fine or text == nil then
        pcall(cvars.RegisterCVar, COPY_CVAR, "")
        fine, text = pcall(cvars.GetCVar, COPY_CVAR)
    end
    if not fine or type(text) ~= "string" then return end
    ns.copyText = text
    -- Each pair on its own (an empty one matches nothing).
    for pair in (text .. ";"):gmatch("(.-);") do
        local key, kind, rest = pair:match("^([%w_]+)=([bns])(.*)$")
        local value = key and Decoded(kind, rest)
        if value ~= nil then saved[key] = value end
    end
    if saved.microPos == nil and type(saved.microPosText) == "string" then
        local point, other, x, y = saved.microPosText:match("^(%u+),(%u+),(%-?[%d.]+),(%-?[%d.]+)$")
        x, y = tonumber(x), tonumber(y)
        if point and x and y then saved.microPos = { point, other, x, y } end
    end
end

-- When EraUI's saved files are read: after Core/Init.lua (which may have
-- emptied them for a settings reset) and before Core/Integration.lua (which
-- needs the table and the copy read). Done even with EraUI turned off.
local reader = CreateFrame("Frame")
reader:RegisterEvent("ADDON_LOADED")
reader:SetScript("OnEvent", function(_, _, loaded)
    if loaded ~= ADDON then return end
    EraUIClassicDB = EraUIClassicDB or {}
    local saved = EraUIClassicDB
    ns.db = saved
    for key, start in pairs(STARTS) do
        if saved[key] == nil then saved[key] = start end
    end
    saved.lastOutput = nil
    ReadCopy(saved)
    for _, key in ipairs(RETIRED) do saved[key] = nil end
end)
