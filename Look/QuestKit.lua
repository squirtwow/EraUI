-- The quest area's kit (Classic look, spec 09: the quest log window, the
-- objective tracker's 1.x dressing and the world map's quest pane). The
-- three parts share it through Look.Quest:
--   * the Classic settings they read, with their defaults (only where the
--     engine has none of its own), and the text form of the quest log's
--     saved place (kept in the settings mirror, so it outlives a reload on
--     Forever, where a saved table can be lost);
--   * the 1.x quest art by key, each frame piece with its own Dark Mode key;
--   * the 1.x difficulty colours and the quest yellow;
--   * careful readers of the game's quest log (every call protected, a
--     hidden value read as missing), watching, the party and the tags;
--   * small helpers: the game's words with a fallback, sounds, fonts, coins;
--   * quest voices: Squirt's voice-over addon's small public API, asked
--     only when it is loaded (the list's voice seals).
-- Nothing here touches a game frame.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local Q = { parts = {}, rows = {}, folded = {}, entries = {} }
Look.Quest = Q

do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    local wanted = { questTracker = true, questLog = true, questLogDual = false, questMapPane = true,
        questLogPosText = "" }
    if engine then
        for key, value in pairs(wanted) do
            if engine[key] == nil then engine[key] = value end
        end
    end
end

---------------------------------------------------------------------------
-- Art
---------------------------------------------------------------------------

do
    local QUEST_FOLDER = "Interface\\QuestFrame\\"
    -- The quest log's frame art exists only as EraUI's copies (the client
    -- ships near-black stand-ins under the same names): the copy first.
    local copies = Look.Words([[questLogTopLeft:UI-QuestLog-TopLeft questLogTopRight:UI-QuestLog-TopRight
        questLogBotLeft:UI-QuestLog-BotLeft questLogBotRight:UI-QuestLog-BotRight
        questLogDualLeft:UI-QuestLogDualPane-Left questLogDualRight:UI-QuestLogDualPane-Right
        questLogEmptyTopLeft:UI-QuestLog-Empty-TopLeft questLogEmptyTopRight:UI-QuestLog-Empty-TopRight
        questLogEmptyBotLeft:UI-QuestLog-Empty-BotLeft questLogEmptyBotRight:UI-QuestLog-Empty-BotRight]])
    for _, pair in ipairs(copies) do
        local key, file = pair:match("^(%w+):(.+)$")
        Look.DefineArt(key, nil, file, key, true)
    end
    for _, part in ipairs({ "Left", "Middle", "Right" }) do
        local file = "UI-QuestLogSortTab-" .. part
        Look.DefineArt("questLogTab" .. part, QUEST_FOLDER .. file, file, "questLogTab" .. part)
    end
    -- Not Dark Mode's: the book, the title glow, the reward plate, the
    -- tracker's buttons and the map pane's parchment keep their colours.
    Look.DefineArt("questLogBook", QUEST_FOLDER .. "UI-QuestLog-BookIcon", "UI-QuestLog-BookIcon")
    Look.DefineArt("questLogHighlight", QUEST_FOLDER .. "UI-QuestLogTitleHighlight", "UI-QuestLogTitleHighlight")
    Look.DefineArt("questRewardPlate", nil, "UI-QuestItemNameFrame", nil, true)
    Look.DefineArt("questTrackerButtons", "Interface\\Buttons\\QuestTrackerButtons", "QuestTrackerButtons")
    Look.DefineArt("questParchment", nil, "QuestBG", nil, true)
end

-- Files the look sets straight from the client.
Q.FILES = {
    plus = "Interface\\Buttons\\UI-PlusButton-Up",
    minus = "Interface\\Buttons\\UI-MinusButton-Up",
    plusGlow = "Interface\\Buttons\\UI-PlusButton-Hilight",
    check = "Interface\\Buttons\\UI-CheckBox-Check",
    box = "Interface\\Buttons\\UI-CheckBox-Up",
    boxGlow = "Interface\\Buttons\\UI-CheckBox-Highlight",
    radio = "Interface\\Buttons\\UI-RadioButton",
    inputBorder = "Interface\\Common\\Common-Input-Border",
    mapButton = "Interface\\QuestFrame\\UI-QuestMap_Button",
    squareGlow = "Interface\\Buttons\\ButtonHilight-Square",
}

---------------------------------------------------------------------------
-- Words, sounds, fonts
---------------------------------------------------------------------------

-- The game's own words for a global name, or the English stand-in.
function Q.Say(name, fallback)
    local said = _G[name]
    if type(said) == "string" and said ~= "" and not Look.Secret(said) then return said end
    return fallback
end

function Q.Sound(name)
    local kits = SOUNDKIT
    local kit = type(kits) == "table" and kits[name] or nil
    if kit and type(PlaySound) == "function" then pcall(PlaySound, kit) end
end

-- The first of the named font objects this client has (GameFontNormal if none).
function Q.Font(...)
    for i = 1, select("#", ...) do
        local font = _G[(select(i, ...))]
        if font ~= nil then return font end
    end
    return GameFontNormal
end

---------------------------------------------------------------------------
-- Colours
---------------------------------------------------------------------------

-- A number from an optional function of the game's, asked quietly.
local function Asked(fn, ...)
    if type(fn) ~= "function" then return nil end
    local fine, value = pcall(fn, ...)
    if not fine then return nil end
    return Look.Number(value)
end
Q.Asked = Asked

-- The quest yellow (the count box, the All tab, Show Map, a level 0 quest).
function Q.Yellow() return 1, 0.92, 0 end

-- How far below you a quest may be and still give a fair reward.
local function FairGap()
    return Asked(UnitQuestTrivialLevelRange, "player") or Asked(GetQuestGreenRange) or 5
end

-- The 1.x difficulty colour of a quest of this level against yours.
function Q.LevelColor(level)
    local quest = Look.Number(level) or 0
    if quest <= 0 then return Q.Yellow() end
    local mine = Asked(UnitLevel, "player")
    if not mine or mine < 1 then mine = 1 end
    local over = quest - mine
    if over >= 5 then return 1, 0.1, 0.1 end
    if over >= 3 then return 1, 0.5, 0.25 end
    if over >= -2 then return Q.Yellow() end
    if mine - quest <= FairGap() then return 0.25, 0.75, 0.25 end
    return 0.5, 0.5, 0.5
end

-- The list's header grey: the game's own header colour, else 0.7.
function Q.HeaderColor()
    local colours = QuestDifficultyColors
    local header = type(colours) == "table" and colours.header or nil
    if type(header) == "table" then
        local r, g, b = Look.Number(header.r), Look.Number(header.g), Look.Number(header.b)
        if r and g and b then return r, g, b end
    end
    return 0.7, 0.7, 0.7
end

---------------------------------------------------------------------------
-- The game's quest log, read carefully
---------------------------------------------------------------------------

local function Log() return type(C_QuestLog) == "table" and C_QuestLog or {} end

-- A plain yes from the game (a hidden or failed answer is a no).
local function Yes(fn, ...)
    if type(fn) ~= "function" then return false end
    local fine, answer = pcall(fn, ...)
    return fine and not Look.Secret(answer) and answer == true
end
Q.Yes = Yes

function Q.EntryCount()
    return Asked(Log().GetNumQuestLogEntries) or 0
end

-- How many quests you have and may have ("Quests: 7/20").
function Q.QuestCount()
    local log = Log()
    local have = 0
    if type(log.GetNumQuestLogEntries) == "function" then
        local fine, _, quests = pcall(log.GetNumQuestLogEntries)
        have = fine and Look.Number(quests) or 0
    end
    local most = Asked(log.GetMaxNumQuestsCanAccept) or Look.Number(MAX_QUESTS) or 20
    return have, most
end

function Q.Info(index)
    local reader = Log().GetInfo
    if type(reader) ~= "function" then return nil end
    local fine, info = pcall(reader, index)
    if fine and type(info) == "table" then return info end
    return nil
end

function Q.IndexOf(questID)
    return Asked(Log().GetLogIndexForQuestID, questID)
end

function Q.GameSelection()
    return Asked(Log().GetSelectedQuest)
end

function Q.SelectInGame(questID)
    local setter = Log().SetSelectedQuest
    if questID and type(setter) == "function" then pcall(setter, questID) end
end

-- A string the game hands over, when it is readable and not empty.
function Q.Words(value)
    if Look.Secret(value) or type(value) ~= "string" or value == "" then return nil end
    return value
end

---------------------------------------------------------------------------
-- Watching (the tracker), the party, tags
---------------------------------------------------------------------------

function Q.Watched(questID)
    local reader = Log().GetQuestWatchType
    if not questID or type(reader) ~= "function" then return false end
    local fine, kind = pcall(reader, questID)
    return fine and kind ~= nil and not Look.Secret(kind)
end

-- Unwatching asks the game first (it can refuse while a quest is tracked
-- automatically); a client without that question lets it through.
local function MayUnwatch()
    local utilities = QuestUtil
    local ask = type(utilities) == "table" and utilities.CanRemoveQuestWatch or nil
    if type(ask) ~= "function" then return true end
    return Yes(ask)
end

function Q.SetWatched(questID, wanted)
    local log = Log()
    if not questID then return end
    if wanted then
        local kinds = Enum and Enum.QuestWatchType
        if type(log.AddQuestWatch) == "function" then pcall(log.AddQuestWatch, questID, kinds and kinds.Manual) end
    elseif MayUnwatch() and type(log.RemoveQuestWatch) == "function" then
        pcall(log.RemoveQuestWatch, questID)
    end
end

function Q.FlipWatch(questID)
    Q.SetWatched(questID, not Q.Watched(questID))
end

function Q.InGroup()
    return Yes(IsInGroup)
end

-- The party members on a quest, by name (a hidden name shows as the unit).
function Q.PartyOn(questID)
    local names = {}
    local size = Asked(GetNumSubgroupMembers) or 0
    local onQuest = Log().IsUnitOnQuest
    if size <= 0 or not questID or type(onQuest) ~= "function" then return names end
    for i = 1, size do
        local unit = "party" .. i
        if Yes(onQuest, unit, questID) then
            local fine, name = pcall(UnitName, unit)
            names[#names + 1] = (fine and Q.Words(name)) or unit
        end
    end
    return names
end

-- The quest's tag, the first that applies: failed, complete, daily or
-- weekly, the game's tag name, group.
function Q.Tag(info)
    local log, questID = Log(), info and info.questID
    if not questID then return nil end
    if Yes(log.IsFailed, questID) then return Q.Say("FAILED", "Failed") end
    if Yes(log.IsComplete, questID) then return Q.Say("COMPLETE", "Complete") end
    local often, kinds = info.frequency, Enum and Enum.QuestFrequency
    if often ~= nil and not Look.Secret(often) and type(kinds) == "table" then
        if often == kinds.Daily then return Q.Say("DAILY", "Daily") end
        if often == kinds.Weekly then return Q.Say("WEEKLY", "Weekly") end
    end
    if type(log.GetQuestTagInfo) == "function" then
        local fine, tag = pcall(log.GetQuestTagInfo, questID)
        local named = fine and type(tag) == "table" and Q.Words(tag.tagName)
        if named then return named end
    end
    local group = Look.Number(info.suggestedGroup)
    if group and group > 0 then return Q.Say("GROUP", "Group") end
    return nil
end

-- Money as the game writes it (coin icons), else the plain amount.
function Q.Coins(amount)
    local readers = { C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString, GetCoinTextureString }
    for i = 1, 2 do
        local reader = readers[i]
        if type(reader) == "function" then
            local fine, text = pcall(reader, amount)
            if fine and type(text) == "string" and not Look.Secret(text) then return text end
        end
    end
    return tostring(amount)
end

-- A modified click the player set up ("CHATLINK", "QUESTWATCHTOGGLE").
function Q.Modified(action)
    return Yes(IsModifiedClick, action)
end

---------------------------------------------------------------------------
-- Quest voices (the list's voice seals)
---------------------------------------------------------------------------
-- Squirt's voice-over addon offers a small public API on its global table
-- (API 1: SealArt, ToggleQuest, Watch). Neither addon needs the other:
-- without it (or with an API EraUI doesn't know) nothing here does
-- anything, so the list is as it always was. Every call is protected and
-- only a plain answer is used.

local function Voices()
    local api = AzerothSpeaks
    if type(api) ~= "table" or Look.Number(api.API) ~= 1 then return nil end
    return api
end

-- The seal's picture for a quest that has a voice (while the voice addon
-- shows seals), else nil.
function Q.VoiceSeal(questID)
    local api = Voices()
    if not api or not Look.Number(questID) or type(api.SealArt) ~= "function" then return nil end
    local fine, art = pcall(api.SealArt, questID)
    if fine and Q.Words(art) then return art end
    return nil
end

-- A seal's click: the voice addon plays the quest's text (or pauses it, or
-- carries on, while it is the one playing).
function Q.PlayVoice(questID)
    local api = Voices()
    if not api or not Look.Number(questID) or type(api.ToggleQuest) ~= "function" then return false end
    local fine, played = pcall(api.ToggleQuest, questID)
    return fine and played == true
end

-- Asks the voice addon, once, to say when its seals change (its voices
-- load, its seals or its colours are switched), so an open log redraws.
local listening = false
function Q.ListenForVoices(redraw)
    if listening then return end
    local api = Voices()
    if not api or type(api.Watch) ~= "function" then return end
    local fine, taken = pcall(api.Watch, redraw)
    listening = fine and taken == true
end
