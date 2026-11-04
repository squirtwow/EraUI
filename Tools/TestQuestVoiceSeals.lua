-- The classic quest log's voice seals (Look/QuestLogList.lua with the
-- voice helpers in Look/QuestKit.lua) on Tools/QuestMockGame.lua. Squirt's
-- voice-over addon, when it is loaded, offers a small public API on its
-- global table (API 1: SealArt, ToggleQuest, Watch); a stand-in for it
-- plays that part here. Checked: with no voice addon, or one whose API
-- EraUI doesn't know or that fails, nothing changes and no error is
-- reported; with it, a quest with a voice gets EraUI's own small seal at
-- its line's right end (none on a quest without, none on a header), its tag
-- moves left of the seal and its title gives the seal room (and the check
-- mark before it); the seals follow the list when it scrolls, folds,
-- refreshes, or switches to double pane; a click plays that quest through
-- the API (the line isn't clicked, so the selection stays); the hover tip;
-- the voice addon saying its seals changed redraws an open log at once
-- (asked once); its seals switched off: gone. No key written on the game's
-- frames (sealed mock), no GameTooltip, no error reported.
-- Run: fengari Tools/TestQuestVoiceSeals.lua
local Mock = dofile("Tools/QuestMockGame.lua")
local Plain = Mock.Plain
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function True(value, label) Equal(value and true or false, true, label) end
local function False(value, label) Equal(value and true or false, false, label) end

local ART = "Interface\\AddOns\\AzerothSpeaks\\Media\\SmallSealHorde.tga"
local VOICED = { [201] = true, [203] = true, [205] = true, [207] = true }

local function Quests(game)
    game.log = { { header = "Valley of Trials" }, 201, 202, 203, 204, { header = "Durotar" }, 205, 206, 207, 208 }
    game.quests = {
        [201] = { title = "Your Place in the World", level = 10, difficultyLevel = 10, watched = true },
        [202] = { title = "Cutting Teeth", level = 10, difficultyLevel = 10 },
        [203] = { title = "Sting of the Scorpid", level = 10, difficultyLevel = 10, tag = "Elite" },
        [204] = { title = "Vile Familiars", level = 10, difficultyLevel = 10 },
        [205] = { title = "Galgar's Cactus Apple Surprise", level = 10, difficultyLevel = 10 },
        [206] = { title = "Lazy Peons", level = 10, difficultyLevel = 10 },
        [207] = { title = "Thazz'ril's Pick", level = 10, difficultyLevel = 10 },
        [208] = { title = "Burning Blade Medallion", level = 10, difficultyLevel = 10 },
    }
end

-- The voice addon's public API, as a stand-in: a seal's picture for a
-- quest with a voice while its seals are on, the quests its seals played,
-- the watchers it was given.
local function Voices(game)
    local api = { API = 1, played = {}, watchers = {}, seals = true }
    function api.SealArt(questID)
        if api.seals and VOICED[questID] then return ART end
        return nil
    end
    function api.ToggleQuest(questID)
        api.played[#api.played + 1] = questID
        return VOICED[questID] == true
    end
    function api.Watch(fn)
        api.watchers[#api.watchers + 1] = fn
        return true
    end
    function api.Changed()
        for _, fn in ipairs(api.watchers) do fn() end
    end
    game.env.AzerothSpeaks = api
    return api
end

local function Session(withVoices)
    local game = Mock.New()
    Quests(game)
    local api = withVoices and Voices(game) or nil
    local Q = game.Load()
    game.Login()
    return game, Q, game.ns, api
end

local function Seal(game, row)
    for _, child in ipairs({ row:GetChildren() }) do
        if not game.IsGame(child) and child:GetObjectType() == "Button" then return child end
    end
end
local function Title(game, row) return Plain(game.Look.OwnLabel(row, "title"):GetText()) end
local IDS = {}
local function QuestOn(game, row)
    local words = Title(game, row):gsub("^%s+", "")
    for id, quest in pairs(IDS) do if quest == words then return id end end
    return nil
end
-- Every shown line: its seal shows exactly for a quest with a voice, and a
-- click on it plays that line's quest.
local function SealsMatch(game, Q, api, label)
    for _, row in ipairs(Q.rows) do
        if row:IsShown() then
            local questID, seal = QuestOn(game, row), Seal(game, row)
            Equal(seal:IsShown(), questID ~= nil and VOICED[questID] == true,
                label .. ": " .. Title(game, row) .. " has a seal only with a voice")
            if seal:IsShown() then
                seal:Click("LeftButton")
                Equal(api.played[#api.played], questID, label .. ": " .. Title(game, row) .. "'s seal plays its own quest")
            end
        end
    end
end

---------------------------------------------------------------------------
-- No voice addon: nothing changes
---------------------------------------------------------------------------

local game, Q, ns = Session(false)
for id, quest in pairs(game.quests) do IDS[id] = quest.title end
ns.ShowQuestLog()
local Look = game.Look
for _, row in ipairs(Q.rows) do
    local seal = Seal(game, row)
    True(seal ~= nil, "every line has its seal button, made with it")
    False(seal:IsShown(), "put away without the voice addon")
    Near(seal:GetWidth(), 14, "14 across")
    Near(seal:GetHeight(), 14, "14 tall, under the line's 15")
end
local elite = Q.rows[4]
Equal(Title(game, elite), "  Sting of the Scorpid", "the Elite quest's line")
local tagSpot = game.State(Look.OwnLabel(elite, "tag")).points.RIGHT
Equal(tagSpot[2], elite, "its tag at the line's right end, as before")
Near(tagSpot[4], -2, "2 in")
game.quests[202].title = string.rep("x", 60)
Q.Refresh()
Near(Look.OwnLabel(Q.rows[3], "title"):GetWidth(), 275, "a long title capped at 275, as before")
game.quests[202].title = "Cutting Teeth"
Q.Refresh()
-- A stranger global or an API EraUI doesn't know: the same.
game.env.AzerothSpeaks = "not a table"
Q.Refresh()
False(Seal(game, Q.rows[2]):IsShown(), "a global that isn't a table: no seals")
game.env.AzerothSpeaks = { API = 2, SealArt = function() return ART end }
Q.Refresh()
False(Seal(game, Q.rows[2]):IsShown(), "an API EraUI doesn't know: no seals")
game.env.AzerothSpeaks = { API = 1, SealArt = function() error("broken") end, Watch = function() error("broken") end }
Q.Refresh()
False(Seal(game, Q.rows[2]):IsShown(), "one that fails: no seals")
-- A picture that isn't a file name: never handed to a texture. (Not a
-- table here: this mock's issecretvalue compares, which a table can't.)
for _, odd in ipairs({ "", 7, true }) do
    game.env.AzerothSpeaks = { API = 1, SealArt = function() return odd end }
    Q.Refresh()
    False(Seal(game, Q.rows[2]):IsShown(), "a picture that isn't a file name (" .. type(odd) .. "): no seal")
end
game.env.AzerothSpeaks = nil
Equal(#game.errors, 0, "and no error reported for any of them")

---------------------------------------------------------------------------
-- With the voice addon
---------------------------------------------------------------------------

local api
game, Q, ns, api = Session(true)
Look = game.Look
Equal(#api.watchers, 0, "nothing asked of the voice addon at login")
ns.ShowQuestLog()
Equal(#api.watchers, 1, "the open log asks once to hear of changes")
Q.Refresh()
Q.Refresh()
Equal(#api.watchers, 1, "only once")
local rows = {}
for _, row in ipairs(Q.rows) do if row:IsShown() then rows[#rows + 1] = row end end
Equal(#rows, 6, "six lines in single pane")
Equal(Title(game, rows[1]), "Valley of Trials", "a header first")
False(Seal(game, rows[1]):IsShown(), "no seal on a header")
local seal = Seal(game, rows[2])
True(seal:IsShown(), "Your Place in the World has a voice: a seal")
Equal(seal:GetParent(), rows[2], "EraUI's own button on its line")
local spot = game.State(seal).points.RIGHT
Equal(spot[2], rows[2], "at its line's right end")
Equal(spot[3], "RIGHT", "its right")
Near(spot[4], -2, "2 in")
Near(spot[5], 0, "level with the line")
local face = Look.OwnPiece(seal, "face")
Equal(game.State(face).file, ART, "the voice addon's own seal picture")
Equal(game.State(face).layer, "ARTWORK", "as its face")
local glow = Look.OwnPiece(seal, "glow")
Equal(game.State(glow).file, ART, "glowing the same while hovered")
Equal(game.State(glow).layer, "HIGHLIGHT", "on hover only")
Equal(game.State(glow).blend, "ADD", "added light")
False(Seal(game, rows[3]):IsShown(), "Cutting Teeth has no voice: none")
True(Seal(game, rows[4]):IsShown(), "Sting of the Scorpid has one")
False(Seal(game, rows[5]):IsShown(), "Vile Familiars: none")
False(Seal(game, rows[6]):IsShown(), "a header again: none")
-- The tag moves left of the seal; on a line without a seal it stays.
tagSpot = game.State(Look.OwnLabel(rows[4], "tag")).points.RIGHT
Equal(tagSpot[2], Seal(game, rows[4]), "the Elite tag sits left of the seal")
Equal(tagSpot[3], "LEFT", "against its left")
Near(tagSpot[4], -2, "2 apart")
Equal(Plain(Look.OwnLabel(rows[4], "tag"):GetText()), "(Elite)", "still the tag")
-- The title gives the seal room, and the check mark before it.
game.quests[201].title = string.rep("x", 60)
game.quests[202].title = string.rep("y", 60)
game.quests[203].title = string.rep("z", 60)
Q.Refresh()
Near(Look.OwnLabel(rows[2], "title"):GetWidth(), 275 - 18 - 20, "a watched quest with a seal: room for the seal and the check mark")
local mark = game.State(Look.OwnPiece(rows[2], "check")).points.LEFT
Near(mark[4] + 16, 20 + 237 + 4 + 16, "the check mark ends")
True(mark[4] + 16 <= 300 - 2 - 14 - 2, "before the seal starts")
Near(Look.OwnLabel(rows[3], "title"):GetWidth(), 275, "no seal: the room as before")
Near(Look.OwnLabel(rows[4], "title"):GetWidth(), 275 - (#"(Elite)" * 6 + 15) - 18, "a tag and a seal: room for both")
game.quests[201].title = "Your Place in the World"
game.quests[202].title = "Cutting Teeth"
game.quests[203].title = "Sting of the Scorpid"
Q.Refresh()
Near(Look.OwnLabel(rows[2], "title"):GetWidth(), #"  Your Place in the World" * 6, "a short title at its own width")

-- A click plays that quest; the line isn't chosen by it.
Equal(Q.selected, 201, "the first quest chosen")
Seal(game, rows[4]):Click("LeftButton")
Equal(api.played[#api.played], 203, "the seal plays its own quest through the voice addon")
Equal(Q.selected, 201, "and the line under it isn't chosen")
Seal(game, rows[4]):Click("LeftButton")
Equal(#api.played, 2, "again: the voice addon is asked again (it pauses)")
-- The hover tip, EraUI's own.
local shown
local realShow = Look.ShowTip
Look.ShowTip = function(owner, side, lines) shown = { owner = owner, side = side, lines = lines } return realShow(owner, side, lines) end
game.Enter(Seal(game, rows[2]))
Equal(Look.TipOwner(), Seal(game, rows[2]), "hovering a seal: its tip")
Equal(shown.lines[1][1], "Play this quest's voice", "says what it does")
Equal(shown.side, "RIGHT", "beside it")
game.Leave(Seal(game, rows[2]))
Equal(Look.TipOwner(), nil, "gone on leaving")
Look.ShowTip = realShow

-- Scrolling: the seals follow the quests down the list.
SealsMatch(game, Q, api, "at the top")
Q.parts.listBar:SetValue(3)
Equal(Title(game, Q.rows[1]), "  Sting of the Scorpid", "scrolled by the bar")
SealsMatch(game, Q, api, "scrolled by 3")
Q.parts.listBar:SetValue(4)
SealsMatch(game, Q, api, "scrolled to the end")
Q.parts.listBar:SetValue(0)
-- Folding: the first header folded, the second's quests move up.
Q.rows[1]:Click("LeftButton")
Equal(Title(game, Q.rows[2]), "Durotar", "Valley of Trials folded")
SealsMatch(game, Q, api, "folded")
False(Seal(game, Q.rows[2]):IsShown(), "the line that had a seal now shows a header: none")
Q.rows[1]:Click("LeftButton")
SealsMatch(game, Q, api, "opened again")
-- A refresh with a quest gone (handed in).
game.log = { { header = "Valley of Trials" }, 202, 203, 204, { header = "Durotar" }, 205, 206, 207, 208 }
game.Fire("QUEST_LOG_UPDATE")
Equal(Title(game, Q.rows[2]), "  Cutting Teeth", "Your Place in the World handed in")
SealsMatch(game, Q, api, "after the refresh")
-- Double pane: every line shows, each seal at its line's right end.
ns.QuestLogSetDual(true)
local shownRows = 0
for _, row in ipairs(Q.rows) do if row:IsShown() then shownRows = shownRows + 1 end end
Equal(shownRows, 9, "double pane: every line (two headers, seven quests)")
SealsMatch(game, Q, api, "double pane")
Equal(game.State(Seal(game, Q.rows[3])).points.RIGHT[2], Q.rows[3], "still at its line's right end")
ns.QuestLogSetDual(false)

-- The voice addon says its seals changed: an open log redraws at once.
api.seals = false
api.Changed()
for _, row in ipairs(Q.rows) do False(Seal(game, row):IsVisible(), "its seals switched off: none, at once") end
api.seals = true
api.Changed()
SealsMatch(game, Q, api, "switched on again")
True(Seal(game, Q.rows[3]):IsShown(), "back at once")
ns.HideQuestLog()
local quiet = pcall(api.Changed)
True(quiet, "told while the log is closed: no error")
-- Its click failing: no error reported.
api.ToggleQuest = function() error("broken") end
ns.ShowQuestLog()
Seal(game, Q.rows[3]):Click("LeftButton")
Equal(#game.errors, 0, "no error reported")

-- A fight changes nothing: the seals are EraUI's own plain buttons.
game.Fight(true)
api.ToggleQuest = function(questID) api.played[#api.played + 1] = questID return true end
Seal(game, Q.rows[3]):Click("LeftButton")
Equal(api.played[#api.played], 203, "in a fight a seal still plays")
game.Fight(false)

Equal(#game.errors, 0, "no error reported")
print("Quest voice seal checks passed: " .. checks .. " assertions.")
