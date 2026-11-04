-- The objective tracker in the old quest watch's manner
-- (Look/QuestTracker.lua, registry "questTracker", clean-room 2026-10-21)
-- on Tools/QuestMockGame.lua.
-- Checked: the whole tracker's header (art faded and its atlases cleared,
-- the gold 12 point title, the 1.x collapse button's boxes, shown only
-- while the tracker is collapsed, hidden again after the game's own
-- update); each section's header (the same, its own boxes, and its own
-- collapsed state read again after an update: the old "open" art bug);
-- blocks already there and blocks added later (titles in 11 point and
-- their difficulty colour, gold without a level, the game's own colour
-- for a hidden level or quest; objective lines and dashes in 10 point,
-- grey, white once started, green when done or complete, the game's own
-- for failed lines and hidden text; the item button's 1.x ring); hooks
-- once; dressing in a fight; never the tracker's own layout run; the map
-- list's older background; turning it off (only when it went on, the
-- header given back, the reload note); off since login; a client without
-- the tracker. No key written on the game's frames (sealed mock).
-- Run: fengari Tools/TestQuestTracker.lua
local Mock = dofile("Tools/QuestMockGame.lua")
local SECRET = Mock.SECRET
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
local function Colour(actual, r, g, b, label)
    Near(actual[1], r, label .. " (red)")
    Near(actual[2], g, label .. " (green)")
    Near(actual[3], b, label .. " (blue)")
end

local game = Mock.New()
game.quests = {
    [101] = { title = "Wolves", difficultyLevel = 15 },
    [102] = { title = "Bears", difficultyLevel = 0 },
    [103] = { title = "Hidden level", difficultyLevel = SECRET },
    [104] = { title = "Broken", difficultyError = true },
    [105] = { title = "Murlocs", difficultyLevel = 9 },
}
local env = game.env
local quests = env.QuestObjectiveTracker
local early = game.Block(quests, 101, "Wolves", { "3/8 Wolf slain" }, true)
local Q = game.Load()
local ns, Look = game.ns, game.Look
local updates = game.trackerUpdates or 0
game.Login()
local tracker = env.ObjectiveTrackerFrame
local header = tracker.Header

-- Each state's box on the 128 x 64 sheet (x from-to, y from-to).
local function Box(texture, x1, x2, y1, y2, label)
    local coords = game.State(texture).coords
    Near(coords[1], x1 / 128, label .. ": left")
    Near(coords[2], x2 / 128, label .. ": right")
    Near(coords[3], y1 / 64, label .. ": top")
    Near(coords[4], y2 / 64, label .. ": bottom")
end
local function Plain(owner, label)
    for _, key in ipairs({ "Background", "Shine", "Glow" }) do
        local s = game.State(owner[key])
        Equal(s.alpha, 0, label .. ": " .. key .. " faded")
        Equal(s.atlas, nil, label .. ": " .. key .. "'s atlas cleared")
    end
    local face, size, flags = owner.Text:GetFont()
    Equal(face, "Fonts\\FRIZQT__.TTF", label .. ": the standard font")
    Equal(size, 12, label .. ": 12 point")
    Equal(flags, "", label .. ": no outline")
    Colour(game.State(owner.Text).textColour, 1, 0.82, 0, label .. ": gold")
    Equal(game.State(owner.Text).shadowOffset[1] .. game.State(owner.Text).shadowOffset[2], "1-1", label .. ": a black shadow")
    local button = owner.MinimizeButton
    Near(button:GetWidth(), 15, label .. ": the button 15 wide")
    Near(button:GetHeight(), 14, label .. ": and 14 tall")
    True(game.State(button:GetNormalTexture()).file:find("QuestTrackerButtons") ~= nil, label .. ": the 1.x button sheet")
    Equal(game.State(button:GetNormalTexture()).theme, nil, label .. ": not tinted")
end

---------------------------------------------------------------------------
-- The whole tracker's header
---------------------------------------------------------------------------

Plain(header, "the whole tracker's header")
False(header:IsShown(), "hidden while the tracker is open")
Box(header.MinimizeButton:GetNormalTexture(), 18, 33, 35, 49, "open, at rest")
Box(header.MinimizeButton:GetPushedTexture(), 1, 16, 35, 49, "open, pressed")
Equal(game.State(header.MinimizeButton:GetNormalTexture()).points.TOPLEFT[2], header.MinimizeButton, "filling the button")
tracker:SetCollapsed(true)
True(header:IsShown(), "shown while the tracker is collapsed")
Box(header.MinimizeButton:GetNormalTexture(), 35, 50, 49, 63, "collapsed, at rest")
Box(header.MinimizeButton:GetPushedTexture(), 35, 50, 33, 47, "collapsed, pressed")
tracker:SetCollapsed(false)
False(header:IsShown(), "gone again once open")
tracker:Update()
False(header:IsShown(), "the game's own update shows it; it goes again")

---------------------------------------------------------------------------
-- Sections
---------------------------------------------------------------------------

local campaign = env.CampaignQuestObjectiveTracker
for _, module in ipairs(tracker.modules) do
    Plain(module.Header, module:GetName())
    Box(module.Header.MinimizeButton:GetNormalTexture(), 35, 50, 17, 31, module:GetName() .. ": open, at rest")
    Box(module.Header.MinimizeButton:GetPushedTexture(), 35, 50, 1, 15, module:GetName() .. ": open, pressed")
end
campaign:SetCollapsed(true)
Box(campaign.Header.MinimizeButton:GetNormalTexture(), 52, 67, 17, 31, "a collapsed section, at rest")
Box(campaign.Header.MinimizeButton:GetPushedTexture(), 52, 67, 1, 15, "a collapsed section, pressed")
tracker:Update()
Box(campaign.Header.MinimizeButton:GetNormalTexture(), 52, 67, 17, 31, "still collapsed art after the tracker updates")
campaign:SetCollapsed(false)
Box(campaign.Header.MinimizeButton:GetNormalTexture(), 35, 50, 17, 31, "open again")
Equal(game.hookCounts[campaign.Header].SetCollapsed, 1, "each section's header hooked once")
Equal(game.hookCounts[quests].AddBlock, 1, "each section's AddBlock hooked once")
Equal(game.hookCounts[header].SetCollapsed, 1, "the whole header hooked once")
Equal(game.hookCounts[tracker].Update, 1, "the tracker's update hooked once")
game.Pass()
game.Pass()
Equal(game.hookCounts[quests].AddBlock, 1, "still once after more passes")
Equal(#game.State(header).hooks.OnShow, 1, "one show hook on the whole header")

---------------------------------------------------------------------------
-- Blocks: titles, objectives, dashes, item buttons
---------------------------------------------------------------------------

local function Font(text) return select(2, text:GetFont()) end
local function TextColour(text) return game.State(text).textColour end
Equal(Font(early.HeaderText), 11, "a block already there: its title 11 point")
Colour(TextColour(early.HeaderText), 1, 0.1, 0.1, "in its difficulty colour (15, you 10)")
local line = early.usedLines[1]
Equal(Font(line.Text), 10, "its objective 10 point")
Colour(TextColour(line.Text), 0.93, 0.93, 0.93, "3/8: started, white")
Equal(Font(line.Dash), 10, "the dash 10 point too")
Colour(TextColour(line.Dash), 0.93, 0.93, 0.93, "the dash in the line's colour")
Equal(game.State(line.Dash).shadowOffset[1], 1, "the dash shadowed")
local item = early.ItemButton
local ring = game.State(item:GetNormalTexture())
True(ring.file:find("UI%-Quickslot2") ~= nil, "the item button's 1.x ring")
Equal(ring.theme, "slotNormal", "Dark Mode's ring key")
Near(ring.width, 26 * 50 / 30, "50/30 of the button across")
Near(ring.height, 26 * 50 / 30, "and down")
Equal(ring.points.CENTER[5], -1, "centred, one down")
Near(ring.coords[2], 1, "the whole sheet")
True(game.State(item:GetPushedTexture()).file:find("UI%-Quickslot%-Depress") ~= nil, "pressed: the 1.x depress")
Equal(#ring.order, 1, "placed once")

-- Blocks added later.
local block = game.Block(quests, 105, "Murlocs", { "0/8 Fin", "8/8 Scale", { "Talk to Gryan", env.OBJECTIVE_TRACKER_COLOR.Complete },
    { "Escort failed", env.OBJECTIVE_TRACKER_COLOR.Failed }, "  12 / 20 Murloc teeth", "Find the camp" }, true)
Equal(Font(block.HeaderText), 11, "a new block dressed through AddBlock")
Colour(TextColour(block.HeaderText), 1, 0.92, 0, "one below you: yellow")
local lines = block.usedLines
Colour(TextColour(lines[1].Text), 0.8, 0.8, 0.8, "0/8: grey")
Colour(TextColour(lines[2].Text), 0.4, 0.75, 0.25, "8/8: green")
Colour(TextColour(lines[3].Text), 0.4, 0.75, 0.25, "no numbers but complete: green")
Colour(TextColour(lines[4].Text), 0.75, 0.1, 0.1, "failed: the game's own colour")
Colour(TextColour(lines[5].Text), 0.93, 0.93, 0.93, "spaces allowed in 12 / 20")
Colour(TextColour(lines[6].Text), 0.8, 0.8, 0.8, "no numbers: grey")
block:AddObjective(1, "4/8 Fin")
Colour(TextColour(lines[1].Text), 0.93, 0.93, 0.93, "the game's own update re-coloured after it")
block:AddObjective(1, SECRET)
Colour(TextColour(lines[1].Text), 0.93, 0.93, 0.93, "hidden text: the colour left as it was")
local before = TextColour(block.HeaderText)
local second = game.Block(quests, 102, "Bears", {})
Colour(TextColour(second.HeaderText), 1, 0.82, 0, "no level: gold")
local hidden = game.Block(quests, 103, "Hidden level", {})
Colour(TextColour(hidden.HeaderText), 0.75, 0.61, 0, "a hidden level: the game's own colour")
Equal(Font(hidden.HeaderText), 11, "but the 1.x size")
local broken = game.Block(quests, 104, "Broken", {})
Colour(TextColour(broken.HeaderText), 1, 0.82, 0, "a level the game can't give: gold")
local secretId = game.Block(quests, SECRET, "Who knows", {})
Colour(TextColour(secretId.HeaderText), 0.75, 0.61, 0, "a hidden quest: the game's own colour")
Colour(before, 1, 0.92, 0, "other titles untouched")
Equal(game.hookCounts[block].SetStringText, 1, "a block's lines hooked once")
quests:AddBlock(block)
Equal(game.hookCounts[block].SetStringText, 1, "still once when it is added again")

-- In a fight: dressed all the same (font, colour, texture only).
game.Fight(true)
local fought = game.Block(quests, 101, "Wolves again", { "8/8 Wolf slain" })
Equal(Font(fought.HeaderText), 11, "a block added in a fight dressed")
Colour(TextColour(fought.usedLines[1].Text), 0.4, 0.75, 0.25, "its lines too")
game.Fight(false)
Equal(game.trackerUpdates or 0, updates + 4, "EraUI never ran the tracker's own update (only the test's two collapses and two updates)")

---------------------------------------------------------------------------
-- The map's quest list background
---------------------------------------------------------------------------

local list = env.QuestScrollFrame
Equal(game.State(list.Background).atlas, "QuestLogBackground", "the older list background at once")
game.emptyList = true
list:UpdateBackground()
Equal(game.State(list.Background).atlas, "NoQuestsBackground", "the older empty background")
game.emptyList = false
list:UpdateBackground()
Equal(game.State(list.Background).atlas, "QuestLogBackground", "after every update")

---------------------------------------------------------------------------
-- Off, and off since login
---------------------------------------------------------------------------

ns.needsReload = nil
ns.db.questTracker = false
game.Pass()
True(header:IsShown(), "off: the header shown again (the game wants it)")
for _, key in ipairs({ "Background", "Shine", "Glow" }) do
    local s = game.State(header[key])
    Equal(s.alpha, 1, key .. " back")
    Equal(s.atlas, "all-" .. key:lower(), key .. "'s own atlas back")
    True(s.atlasSized, key .. " at its own size")
end
Equal(game.State(header.Text).font, env.ObjectiveTrackerHeaderFont, "the header's own font back")
True(ns.needsReload, "a reload asked for the rest")
ns.needsReload = nil
game.Pass()
Equal(ns.needsReload, nil, "a pass with nothing to undo asks nothing")
list:UpdateBackground()
Equal(game.State(list.Background).atlas, "QuestLog-main-background", "the game's list background left alone")
local later = game.Block(quests, 102, "Off", { "8/8 Fin" })
Equal(Font(later.HeaderText), 12, "blocks added while off left to the game")
tracker:SetCollapsed(true)
tracker:SetCollapsed(false)
True(header:IsShown(), "the whole header left to the game")

local quiet = Mock.New({ db = { questTracker = false } })
quiet.Load()
quiet.Login()
Equal(quiet.ns.needsReload, nil, "off since login: no reload note")
Equal(quiet.hookCounts[quiet.env.QuestObjectiveTracker].AddBlock, nil, "and nothing hooked (the quest log's title click aside)")
Equal(quiet.hookCounts[quiet.env.ObjectiveTrackerFrame], nil, "not the tracker's update")
Equal(quiet.State(quiet.env.ObjectiveTrackerFrame.Header.Background).alpha, 1, "nothing faded")

local bare = Mock.New()
rawset(bare.env, "ObjectiveTrackerFrame", nil)
bare.Load()
bare.Login()
local named = false
for _, piece in ipairs(bare.missing) do if piece == "ObjectiveTrackerFrame" then named = true end end
True(named, "a client without the tracker: named as a missing piece")

Equal(#game.errors + #quiet.errors + #bare.errors, 0, "no error reported: " .. tostring(game.errors[1]))
print("Quest tracker checks passed: " .. checks .. " assertions.")
