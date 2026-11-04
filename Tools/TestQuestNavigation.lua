-- Opening the classic quest log on a chosen quest (Look/QuestLogOpen.lua,
-- clean-room 2026-10-21) on Tools/QuestMockGame.lua: ns.ShowQuestLog(id),
-- Questie's "open quest log" action, and a quest title clicked in the
-- objective tracker.
-- Checked: Questie loading late is wrapped once (only its tracker module
-- imported); a title action opens the window on the quest, scrolled into
-- view, the detail from its top, Questie's own handler and the map left
-- alone; a quest in a folded section opens only its own header (in the game
-- and in EraUI's folding); Questie's other actions untouched; its own
-- handler kept for an unknown quest (receiver, arguments, every result), in
-- a fight, with EraUI off and with the log off; no wrapper stacked on a
-- re-apply. The tracker's title click: the game's handler first, then the
-- map closed and the log opened on the quest; a right click, a link, a
-- watch toggle, a fight or the log off leave it to the game.
-- Run: fengari Tools/TestQuestNavigation.lua
local Mock = dofile("Tools/QuestMockGame.lua")
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function True(value, label) Equal(value and true or false, true, label) end
local function False(value, label) Equal(value and true or false, false, label) end

-- Header A with quests 101 to 108, header B (place 10) with 109 to 112;
-- every quest with a long story, so its detail can scroll.
local function Log(game)
    game.log = { { header = "A" } }
    for id = 101, 108 do game.log[#game.log + 1] = id end
    game.log[#game.log + 1] = { header = "B" }
    for id = 109, 112 do game.log[#game.log + 1] = id end
    for id = 101, 112 do
        game.quests[id] = { title = "Quest " .. id, level = 10, difficultyLevel = 10, description = string.rep("words ", 300) }
    end
end

local game = Mock.New()
Log(game)
local Q = game.Load()
game.Login()
local ns, env = game.ns, game.env

---------------------------------------------------------------------------
-- Questie, loaded after EraUI
---------------------------------------------------------------------------

local questie = game.MakeQuestie()
local own = questie.ShowQuestLog
local objective, finisher = questie.ShowObjectiveOnMap, questie.ShowFinisherOnMap
game.Fire("ADDON_LOADED", "Questie")
local wrapped = questie.ShowQuestLog
True(wrapped ~= own, "Questie loading late is wrapped")
Equal(#game.questieImports, 1, "one module imported")
Equal(game.questieImports[1], "TrackerUtils", "only its tracker module")

-- Something else shown first, its detail scrolled down.
ns.ShowQuestLog(101)
local window, P = env.EraUIClassicQuestLog, Q.parts
P.detailBar:SetValue(99)
Equal(P.detailBar:GetValue(), 99, "the detail scrolled down")
env.WorldMapFrame:Show()
local hidden = game.hiddenPanels or 0
questie:ShowQuestLog({ Id = 112 })
Equal(questie.nativeCalls, 0, "Questie's own handler not called")
True(env.WorldMapFrame:IsShown(), "the map left open")
Equal(game.hiddenPanels or 0, hidden, "nothing closed through the game's panels")
env.WorldMapFrame:Hide()
True(window:IsShown(), "the classic log shows")
Equal(game.selected, 112, "112 selected in the game")
Equal(Q.selected, 112, "and in the log")
Equal(Q.ListOffset(), 8, "the list scrolled so 112 is the last row shown")
Equal(P.detailBar:GetValue(), 0, "the detail from its top")
questie:ShowQuestLog({ Id = 101 })
Equal(Q.ListOffset(), 1, "a quest above the rows becomes the first row (its header scrolled past)")

-- A quest in a folded section.
ns.QuestLogSetAllCollapsed(true)
game.log[10].collapsed = true
questie:ShowQuestLog({ Id = 109 })
Equal(game.expanded[#game.expanded], 10, "the game's header B opened")
Equal(game.selected, 109, "109 selected")
Equal(#Q.entries, 6, "A still folded, B open: six entries")
True(Q.entries[1].header and Q.entries[1].folded, "A folded")
Equal(Q.entries[3].quest, 109, "109 the third entry")
Equal(Q.ListOffset(), 0, "the list offset clamped")

-- Questie's other actions.
Equal(questie.ShowObjectiveOnMap, objective, "its objective handler untouched")
Equal(questie.ShowFinisherOnMap, finisher, "its finisher handler untouched")
questie:ShowObjectiveOnMap({})
questie:ShowFinisherOnMap({})
Equal(questie.objective + questie.finisher, 2, "both still work")

-- Questie's own handler, whenever the log can't take it.
local first, second, third = questie:ShowQuestLog({ Id = 999 }, "extra", nil)
Equal(first, "native", "an unknown quest: Questie's own")
Equal(second, nil, "its nil result kept")
Equal(third, 2, "its arguments kept")
game.Fight(true)
questie:ShowQuestLog({ Id = 101 })
Equal(game.selected, 109, "in a fight nothing changes")
Equal(ns.ShowQuestLog(101), false, "and the log won't open directly either")
game.Fight(false)
game.settings.enabled = false
questie:ShowQuestLog({ Id = 101 })
Equal(game.selected, 109, "EraUI off: Questie's own")
game.settings.enabled = true
ns.db.questLog = false
game.Pass()
False(window:IsShown(), "the log off: closed")
questie:ShowQuestLog({ Id = 101 })
Equal(game.selected, 109, "and Questie's own used")
questie:ShowQuestLog({ Id = 0 })
questie:ShowQuestLog("not a quest")
ns.db.questLog = true
game.Pass()
game.Fire("ADDON_LOADED", "Questie")
Equal(questie.ShowQuestLog, wrapped, "no second wrapper")
questie:ShowQuestLog({ Id = 101 })
Equal(game.selected, 101, "the classic log takes it again")
Equal(questie.nativeCalls, 6, "Questie's own reached only when the log couldn't take it")

---------------------------------------------------------------------------
-- Questie there before EraUI
---------------------------------------------------------------------------

local early = Mock.New()
Log(early)
local earlyQuestie = early.MakeQuestie()
local earlyOwn = earlyQuestie.ShowQuestLog
early.Load()
early.Login()
True(earlyQuestie.ShowQuestLog ~= earlyOwn, "Questie already there: wrapped at login")
earlyQuestie:ShowQuestLog({ Id = 105 })
Equal(early.selected, 105, "and it opens the log")

---------------------------------------------------------------------------
-- A quest title clicked in the objective tracker
---------------------------------------------------------------------------

ns.HideQuestLog()
local tracker = env.QuestObjectiveTracker
local block = game.Block(tracker, 110, "Quest 110", { "Thing: 0/4" })
env.WorldMapFrame:Hide()
tracker:OnBlockHeaderClick(block, "LeftButton")
Equal(game.headerClicks, 1, "the game's own handler first")
False(env.WorldMapFrame:IsShown(), "the map it opened closed again")
True(window:IsShown(), "the classic log opens")
Equal(game.selected, 110, "on that quest")
ns.HideQuestLog()
tracker:OnBlockHeaderClick(block, "RightButton")
False(window:IsShown(), "a right click is the game's (its menu)")
for _, action in ipairs({ "CHATLINK", "QUESTWATCHTOGGLE" }) do
    game.modified[action] = true
    tracker:OnBlockHeaderClick(block, "LeftButton")
    False(window:IsShown(), action .. ": the game's")
    game.modified[action] = nil
end
game.Fight(true)
tracker:OnBlockHeaderClick(block, "LeftButton")
True(env.WorldMapFrame:IsShown(), "in a fight the map the game opened stays")
False(window:IsShown(), "and the log stays shut")
game.Fight(false)
env.WorldMapFrame:Hide()
local campaign = env.CampaignQuestObjectiveTracker
local story = game.Block(campaign, 111, "Quest 111", {})
campaign:OnBlockHeaderClick(story, "LeftButton")
Equal(game.selected, 111, "a campaign title too")
ns.HideQuestLog()
ns.db.questLog = false
game.Pass()
env.WorldMapFrame:Hide()
tracker:OnBlockHeaderClick(block, "LeftButton")
True(env.WorldMapFrame:IsShown(), "with the log off, the game's map")
False(window:IsShown(), "and no log")

Equal(#game.errors + #early.errors, 0, "no error reported: " .. tostring(game.errors[1]))
print("Quest navigation checks passed: " .. checks .. " assertions.")
