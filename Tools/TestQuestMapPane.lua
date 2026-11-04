-- The world map's quest pane in the quest log's manner (Look/QuestMapPane.lua,
-- registry "questMapPane", clean-room 2026-10-21) on Tools/QuestMockGame.lua.
-- Checked: the details' height (one bottom anchor each added to the details
-- and their text area, the game's own top and width kept; resizes coalesced
-- to one re-measure a frame; the scroll kept valid; the game's rewards
-- height handed back to it; nothing in a fight, caught up after it; restore
-- gives back the exact size and anchors, a queued re-measure inert after
-- it; re-apply follows the current map); the marble floor and the
-- parchment; the list's own art faded; headers and titles dressed once per
-- pooled button (icons, glow, fonts, colours, the old check box, colour
-- back on leave); the details' art faded and their words in brown ink, never
-- inside buttons; the reload note only when something was undone; a client
-- without the pane. No key written on the game's frames (sealed mock).
-- Run: fengari Tools/TestQuestMapPane.lua
local Mock = dofile("Tools/QuestMockGame.lua")
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
game.log = { { header = "Elwynn Forest" }, 101, 102, { header = "Westfall", collapsed = true }, 103 }
game.quests = {
    [101] = { title = "Wolves", level = 15, difficultyLevel = 15 },
    [102] = { title = "Bears", level = 4 },
    [103] = { title = "Defias", level = 12 },
}
game.env.QuestMapFrame.DetailsFrame:Show()
local Q = game.Load()
local env, ns, Look = game.env, game.ns, game.Look
local map = env.QuestMapFrame
local quests, details = map.QuestsFrame, map.DetailsFrame
local text = details.ScrollFrame
local rewards = details.RewardsFrameContainer.RewardsFrame
local abandon = game.State(details.AbandonButton).scripts.OnClick
game.Login()

---------------------------------------------------------------------------
-- The details' height
---------------------------------------------------------------------------

Equal(game.Flush(), 1, "one re-measure queued")
Near(details:GetHeight(), 499, "the details reach the pane's foot (2 up)")
Near(text:GetHeight(), 427, "the text area keeps the footer's room (29 up)")
Near(details:GetWidth(), 308, "the details keep their width")
Near(text:GetWidth(), 298, "and the text area its width")
Equal(details:GetNumPoints(), 2, "the game's top anchor and EraUI's bottom one")
Equal(game.State(details.AbandonButton).scripts.OnClick, abandon, "the details' own buttons untouched")
Equal(game.rectUpdates, 1, "the game told its text moved")
Equal(#game.rewardHeights, 1, "the rewards re-clipped once")
Equal(game.rewardHeights[1], 160, "at the game's own rewards height")
quests:SetHeight(900)
text:SetVerticalScroll(700)
game.Run(details, "OnSizeChanged")
game.Run(details, "OnSizeChanged")
Equal(#game.timers, 1, "two size changes in a frame: one re-measure")
game.Flush()
Near(details:GetHeight(), 897, "a bigger map: the details follow")
Near(text:GetHeight(), 825, "and the text area")
Near(text:GetVerticalScroll(), 275, "a scroll past the new end clamped to it")
quests:SetHeight(400)
game.Run(details, "OnSizeChanged")
game.Flush()
Near(text:GetHeight(), 325, "a smaller map: the text area shrinks")
Near(text:GetVerticalScroll(), 275, "a scroll still inside is kept")
Equal(#game.rewardHeights, 3, "the rewards re-clipped on each re-measure")
-- A fight: nothing moved or measured until it ends.
game.Fight(true)
env.QuestMapFrame_ShowQuestDetails(101)
game.Run(details, "OnSizeChanged")
game.Flush()
Equal(#game.rewardHeights, 3, "nothing measured in a fight")
game.Fight(false)
game.Flush()
Equal(#game.rewardHeights, 4, "caught up as the fight ends")
-- A hidden pane isn't measured.
details:Hide()
game.Run(details, "OnSizeChanged")
game.Flush()
Equal(#game.rewardHeights, 4, "nothing measured while the details are hidden")
details:Show()
game.Flush()

---------------------------------------------------------------------------
-- The look
---------------------------------------------------------------------------

local floor = Look.OwnPiece(map, "questFloor")
local f = game.State(floor)
True(floor ~= nil and floor:IsShown(), "the marble floor")
Equal(f.layer, "BACKGROUND", "behind the pane")
Equal(f.sublevel, -3, "at the bottom of it")
True(f.file:find("UI%-Background%-Marble") ~= nil, "EraUI's marble")
True(f.htile and f.vtile and f.wrap ~= nil, "tiled both ways")
Equal(f.theme, "marbleBg", "Dark Mode's marble key")
Colour(f.colour, 0.9, 0.9, 0.9, "the pane shade")
Equal(game.State(floor).points.TOPLEFT[2], map, "filling the pane")
local list = map.QuestsFrame.ScrollFrame
Equal(game.State(list.Background).alpha, 0, "the list's own background faded")
Equal(game.State(list.Edge).alpha, 0, "its edge")
for _, piece in ipairs({ list.BorderFrame:GetRegions() }) do Equal(game.State(piece).alpha, 0, "its border") end
local paper = Look.OwnPiece(details, "questParchment")
local p = game.State(paper)
True(p.file:find("QuestBG") ~= nil, "the parchment")
Equal(p.layer .. p.sublevel, "BACKGROUND-2", "behind the text")
Near(p.coords[1], 8 / 512, "cut from 8 across")
Near(p.coords[2], 300 / 512, "to 300")
Near(p.coords[3], 4 / 512, "from 4 down")
Near(p.coords[4], 336 / 512, "to 336")
Equal(p.theme, nil, "not tinted")
Equal(p.points.BOTTOMRIGHT[2], details, "pinned by two corners")
Equal(game.hookCounts[env].QuestLogQuests_Update, 1, "the list's update post-hooked once")
Equal(game.hookCounts[env].QuestMapFrame_ShowQuestDetails, 1, "and the details' show")

-- The list's rows (pooled: after each painting a quest may be on another button).
local headerPool, titlePool = list.headerFramePool, list.titleFramePool
local function Paint()
    env.QuestLogQuests_Update()
    local headers, titles = {}, {}
    for button in headerPool:EnumerateActive() do headers[button.questLogIndex] = button end
    for button in titlePool:EnumerateActive() do titles[button.questID] = button end
    return headers, titles
end
local headers, titles = Paint()
local elwynn, westfall = headers[1], headers[4]
for _, piece in ipairs({ elwynn:GetRegions() }) do
    if piece ~= Look.OwnPiece(elwynn, "questIcon") and piece ~= Look.OwnPiece(elwynn, "questGlow")
        and game.State(piece).kind == "Texture" then
        Equal(game.State(piece).alpha, 0, "a header's own art faded")
    end
end
Equal(game.State(elwynn.CollapseButton).alpha, 0, "its collapse button faded")
False(elwynn.CollapseButton:IsMouseEnabled(), "and out of the mouse's way")
local icon = Look.OwnPiece(elwynn, "questIcon")
Equal(game.State(icon).file, "Interface\\Buttons\\UI-MinusButton-Up", "an open header's minus")
Equal(game.State(Look.OwnPiece(westfall, "questIcon")).file, "Interface\\Buttons\\UI-PlusButton-Up", "a folded one's plus")
Equal(game.State(icon).points.LEFT[4], 4, "4 in")
local glow = game.State(Look.OwnPiece(elwynn, "questGlow"))
Equal(glow.layer .. glow.blend, "HIGHLIGHTADD", "the plus glow on hover")
local words = elwynn.ButtonText
Equal(game.State(words).font, env.GameFontNormal, "the header's words in the normal font")
Equal(game.State(words).points.LEFT[4], 24, "24 in")
Equal(game.State(words).points.RIGHT[4], -4, "to 4 from the right")
Colour(game.State(words).textColour, 1, 0.82, 0, "gold")
Equal(game.State(elwynn).highlightFont, env.GameFontHighlight, "white on hover")
local wolves, bears, defias = titles[101], titles[102], titles[103]
Equal(game.State(wolves.StorylineTexture).alpha, 0, "the storyline mark faded")
Equal(game.State(wolves.TaskIcon).alpha, 0, "the task icon faded")
local band = game.State(wolves.HighlightTexture)
True(band.file:find("UI%-QuestLogTitleHighlight") ~= nil, "the 1.x title glow")
Equal(band.blend, "ADD", "additive")
Near(band.points.TOPLEFT[5], -2, "from 2 down")
Near(band.points.BOTTOMRIGHT[5], 2, "to 2 up")
Equal(game.State(wolves.Checkbox.CheckMark).file, "Interface\\Buttons\\UI-CheckBox-Check", "the old check")
for _, piece in ipairs({ wolves.Checkbox:GetRegions() }) do
    local s = game.State(piece)
    if piece ~= wolves.Checkbox.CheckMark then
        if s.layer == "HIGHLIGHT" then
            Equal(s.file, "Interface\\Buttons\\UI-CheckBox-Highlight", "the box's glow")
            Equal(s.blend, "ADD", "additive")
        else
            Equal(s.file, "Interface\\Buttons\\UI-CheckBox-Up", "the old box")
        end
    end
end
Colour(game.State(wolves.Text).textColour, 1, 0.1, 0.1, "a title in its difficulty colour (its own level)")
Colour(game.State(bears.Text).textColour, 1, 0.82, 0, "no level: gold")
Colour(game.State(bears.TagText).textColour, 1, 0.82, 0, "its tag too")
game.quests[102].difficultyLevel = 4
headers, titles = Paint()
Colour(game.State(titles[102].Text).textColour, 0.5, 0.5, 0.5, "the game's level when the button has none")
wolves = titles[101]
game.Run(wolves, "OnLeave")
Colour(game.State(wolves.Text).textColour, 1, 0.1, 0.1, "the colour put back after the game's own on leaving")
Equal(#game.State(wolves).hooks.OnLeave, 1, "one leave hook")
local made = game.headerMade
headers, titles = Paint()
for _, button in pairs(titles) do Equal(#game.State(button).hooks.OnLeave, 1, "still one per button after another painting") end
Equal(game.headerMade, made, "the pool's buttons reused")
game.log[4].collapsed = false
headers = Paint()
Equal(game.State(Look.OwnPiece(headers[4], "questIcon")).file, "Interface\\Buttons\\UI-MinusButton-Up", "the icon follows the header")
game.quests[103].difficultyError = true
headers, titles = Paint()
Colour(game.State(titles[103].Text).textColour, 1, 0.82, 0, "a level the game can't give: gold")
game.quests[103].difficultyError = nil
headers, titles = Paint()
wolves = titles[101]

-- The details' look.
env.QuestMapFrame_ShowQuestDetails(101)
Equal(game.State(details.Bg).alpha, 0, "the details' own background faded")
Equal(game.State(details.SealMaterialBG).alpha, 0, "and Camelot's themed backdrop over the parchment")
for _, owner in ipairs({ details.BorderFrame, details.BackFrame }) do
    for _, piece in ipairs({ owner:GetRegions() }) do Equal(game.State(piece).alpha, 0, "their border art faded") end
end
for _, key in ipairs({ "Top", "Bottom", "Background" }) do Equal(game.State(rewards[key]).alpha, 0, "the rewards' " .. key) end
for _, words2 in ipairs({ game.detailTitle, game.detailBody, game.detailDeep, rewards.Label }) do
    Colour(game.State(words2).textColour, 0.18, 0.12, 0.06, "the details' words in brown ink")
end
Colour(game.State(game.detailButtonText).textColour, 1, 1, 1, "never inside a button")
game.settings.darkMode = true
env.QuestMapFrame_ShowQuestDetails(101)
Colour(game.State(game.detailTitle).textColour, 0.18, 0.12, 0.06, "Dark Mode leaves the parchment's ink")
game.settings.darkMode = false

---------------------------------------------------------------------------
-- Off, on and off again
---------------------------------------------------------------------------

game.Run(details, "OnSizeChanged")
ns.needsReload = nil
ns.db.questMapPane = false
game.Pass()
Near(details:GetHeight(), 502, "off: the details' own height")
Near(text:GetHeight(), 430, "and the text area's")
Equal(details:GetNumPoints(), 1, "the details back on one anchor")
Equal(text:GetNumPoints(), 1, "so is the text area")
False(floor:IsShown(), "the floor put away")
False(paper:IsShown(), "the parchment put away")
True(ns.needsReload, "a reload asked for the rest")
local measured = #game.rewardHeights
game.Flush()
Equal(#game.rewardHeights, measured, "a re-measure queued before turning off does nothing")
ns.needsReload = nil
game.Pass()
Equal(ns.needsReload, nil, "nothing undone again: no reload note")
env.QuestLogQuests_Update()
Colour(game.State(wolves.Text).textColour, 0.75, 0.61, 0, "off: titles keep the game's colour")
ns.db.questMapPane = true
game.Pass()
game.Flush()
Near(details:GetHeight(), 397, "on again: following the current map")
True(floor:IsShown() and paper:IsShown(), "the floor and parchment back")
ns.db.questMapPane = false
game.Pass()
Near(details:GetHeight(), 502, "off again: the game's own height")
-- Even asked in a fight (the engine waits for its end; a details show
-- doesn't), the details are never moved then; the fight's end fits them.
ns.db.questMapPane = true
game.Fight(true)
game.Module("questMapPane").apply()
env.QuestMapFrame_ShowQuestDetails(101)
Equal(details:GetNumPoints(), 1, "nothing moved in a fight")
game.Fight(false)
Equal(details:GetNumPoints(), 2, "fitted as the fight ends")
game.Flush()
ns.db.questMapPane = false
game.Pass()
Equal(details:GetNumPoints(), 1, "and given back once more")

-- Off since login: nothing touched, no reload note.
local quiet = Mock.New({ db = { questMapPane = false } })
quiet.Load()
quiet.Login()
Equal(quiet.ns.needsReload, nil, "off since login: no reload note")
Equal(quiet.Look.OwnPiece(quiet.env.QuestMapFrame, "questFloor"), nil, "and no floor made")

-- A client without the quest pane.
local bare = Mock.New()
rawset(bare.env, "QuestMapFrame", nil)
bare.Load()
bare.Login()
local named = false
for _, piece in ipairs(bare.missing) do if piece == "QuestMapFrame" then named = true end end
True(named, "a client without it: named as a missing piece")

Equal(#game.errors + #quiet.errors + #bare.errors, 0, "no error reported: " .. tostring(game.errors[1]))
print("Quest map pane checks passed: " .. checks .. " assertions.")
