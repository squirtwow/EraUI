-- The classic quest log window (Look/Quest*.lua, registry "questLog" and
-- "questLogDual", clean-room 2026-10-21) on Tools/QuestMockGame.lua:
-- EraUI's own window EraUIClassicQuestLog over the game's quest log.
-- Checked: the settings' defaults and the registry order; nothing built at
-- login; the frame, its art and Dark Mode's keys, the count box, the All
-- tab, both radios, the panes and their bars, the foot; the list (what is
-- left out, the game's folded headers opened, EraUI's own folding, rows,
-- tags in their order, the party prefix with hidden names, the width cap,
-- the check mark, colours, the selection and its fallbacks, scrolling,
-- clicks, hovers); the detail (order and gaps, inks and Dark Mode, fonts,
-- timer, money, rewards and their plates and tooltips, pooling, height);
-- Abandon, Share, Track, Exit; double pane both ways and the radio's pass;
-- the empty log; the micro button's pad and the named click target, the
-- game's own click kept; events, quest NPC windows, the game menu, Escape,
-- the window manager, a fight; the saved place winning (across a reload);
-- the map's quest list setting; Show Map; turning it off and on.
-- Also: no key written on the game's frames (sealed mock), no key binding,
-- no GameTooltip, no error reported.
-- Run: fengari Tools/TestQuestLog.lua
local Mock = dofile("Tools/QuestMockGame.lua")
local SECRET, Plain = Mock.SECRET, Mock.Plain
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

---------------------------------------------------------------------------
-- A log: two sections, a hidden quest, a task and a bounty left out
---------------------------------------------------------------------------

local function Quests(game)
    game.log = { { header = "Elwynn Forest" }, 101, 102, 103, { header = "Westfall", sortKey = 7 }, 104, 105, 106, 107,
        108, 109, 110 }
    game.quests = {
        [101] = { title = "Wolves", level = 8, difficultyLevel = 8, watched = true, pushable = true,
            objectivesText = "Kill 8 wolves.", description = "The wolves are a menace.", money = 2000,
            board = { { "Wolf slain: 3/8", "monster", false }, { "", "item", true } },
            choices = { { name = "Sword", texture = "sword", count = 1, quality = 2, itemID = 5 },
                { name = "Axe", texture = "axe", count = 1, itemID = 6 }, { name = nil, texture = "staff", count = 2, itemID = 77 } },
            rewards = { { name = "Potion", texture = "potion", count = 3, itemID = 7 } }, rewardMoney = 250, xp = 1250 },
        [102] = { title = "Bears", level = 12, difficultyLevel = 12, failed = true, description = "Bears." },
        [103] = { title = "Murlocs", level = 10, difficultyLevel = 10, complete = true, frequency = 1 },
        [104] = { title = "Defias", level = 15, difficultyLevel = 15, frequency = 1 },
        [105] = { title = "Harvest", level = 13, difficultyLevel = 13, frequency = 2 },
        [106] = { title = "Old Tower", level = 4, difficultyLevel = 4, tag = "Elite", group = 3 },
        [107] = { title = "Gnolls", level = 7, difficultyLevel = 7, group = 2 },
        [108] = { title = "Hidden", level = 7, hidden = true },
        [109] = { title = "Task", level = 7, task = true },
        [110] = { title = "Bounty", level = 7, bounty = true },
    }
end

local function Session(options)
    options = options or {}
    local game = Mock.New(options)
    Quests(game)
    if options.setup then options.setup(game) end
    local Q = game.Load()
    if options.login ~= false then game.Login() end
    return game, Q, game.ns, game.env
end

local function Anchor(game, region, point)
    local spot = game.State(region).points[point]
    if not spot then return nil end
    return spot
end
local function At(game, region, point, relative, relativePoint, x, y, label)
    local spot = Anchor(game, region, point)
    True(spot ~= nil, label .. ": has " .. point)
    Equal(spot[2], relative, label .. ": relative to")
    Equal(spot[3], relativePoint, label .. ": its point")
    Near(spot[4], x, label .. ": x")
    Near(spot[5], y, label .. ": y")
end
local function Words(game, Q, row) return Plain(game.Look.OwnLabel(row, "title"):GetText()) end
local function Visible(Q)
    local shown = {}
    for _, row in ipairs(Q.rows) do if row:IsShown() then shown[#shown + 1] = row end end
    return shown
end

---------------------------------------------------------------------------
-- Load and login: defaults, registry, the ways in, nothing built
---------------------------------------------------------------------------

local game, Q, ns, env = Session()
local defaults = ns.DB_DEFAULTS
Equal(defaults.questTracker, true, "questTracker defaults on")
Equal(defaults.questLog, true, "questLog defaults on")
Equal(defaults.questLogDual, false, "questLogDual defaults off")
Equal(defaults.questMapPane, true, "questMapPane defaults on")
Equal(defaults.questLogPosText, "", "the saved place's mirror text starts empty")
local keys = {}
for _, module in ipairs(ns.modules) do keys[#keys + 1] = module.key end
Equal(table.concat(keys, " "), "questTracker questLog questLogDual questMapPane", "the registry entries, in the old order")
True(game.Module("questLog").init ~= nil, "questLog has its one-time login step")
Equal(env.EraUIClassicQuestLog, nil, "the window is not built at login")
for _, name in ipairs({ "ShowQuestLog", "HideQuestLog", "ToggleQuestLog", "QuestLogSetAllCollapsed", "QuestLogSetDual" }) do
    Equal(type(ns[name]), "function", "ns." .. name)
end
local target = env.EraUIClassicQuestLogBind
True(target ~= nil, "the named click target EraUIClassicQuestLogBind")
False(target:IsMouseEnabled(), "which takes no mouse")
At(game, target, "TOPLEFT", env.UIParent, "TOPLEFT", -500, 500, "and sits off the screen")
local pad = game.PadFor(env.QuestLogMicroButton)
True(pad ~= nil, "a secure pad over the quest micro button")
Equal(pad.target, target, "which clicks the named click target")
Equal(pad.after, nil, "with nothing after")
Equal(game.State(env.QuestLogMicroButton).scripts.OnClick, game.ownMicroClick, "the micro button's own click is never replaced")
True(pad.when(), "the pad is up while the log is on")
game.quickBind = true
False(pad.when(), "and steps aside in the game's quick keybind mode")
game.quickBind = false
Equal(#game.State(env.GameMenuFrame).hooks.OnShow, 1, "the game menu hooked once")
Equal(game.hookCounts[env.QuestObjectiveTracker].OnBlockHeaderClick, 1, "the tracker's title click post-hooked")
Equal(game.hookCounts[env.CampaignQuestObjectiveTracker].OnBlockHeaderClick, 1, "and the campaign tracker's")
game.Pass()
Equal(game.hookCounts[env.QuestObjectiveTracker].OnBlockHeaderClick, 1, "never twice")

---------------------------------------------------------------------------
-- The window, single pane
---------------------------------------------------------------------------

Equal(ns.ShowQuestLog(), true, "the log opens")
local window = env.EraUIClassicQuestLog
local s = game.State(window)
Equal(s.parent, env.UIParent, "a child of UIParent")
Equal(s.strata, "HIGH", "strata HIGH")
True(s.toplevel and s.movable and s.clamped and s.mouse, "top level, movable, clamped, takes the mouse")
Equal(s.drag, "LeftButton", "dragged with the left button")
Near(window:GetWidth(), 384, "384 wide")
Near(window:GetHeight(), 512, "512 tall")
At(game, window, "TOPLEFT", env.UIParent, "TOPLEFT", 0, -104, "its place")
Equal(#game.registered, 1, "one of EraUI's windows for the shared manager")
Equal(game.registered[1].frame, window, "this one")
Equal(game.registered[1].shares, nil, "not sharing its slot")
Equal(game.escapes[1].frame, window, "closed by Escape")
True(game.escapes[1].closer ~= nil, "through its own closer")
Equal(game.follows[1].entry, env.QuestLogMicroButton, "the micro button follows it")
True(game.follows[1].isShown(), "pressed while it is shown")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LOG_OPEN", "the open sound")
True(game.microRefreshes > 0, "the micro buttons checked at once")

local P = Q.parts
local Look = game.Look
local SINGLE = { { "questLogTopLeft", 256, 256, "TOPLEFT" }, { "questLogTopRight", 128, 256, "TOPRIGHT" },
    { "questLogBotLeft", 256, 256, "BOTTOMLEFT" }, { "questLogBotRight", 128, 256, "BOTTOMRIGHT" } }
for i, piece in ipairs(SINGLE) do
    local sheet = P.single[i]
    local t = game.State(sheet)
    Equal(t.theme, piece[1], piece[1] .. ": its Dark Mode key")
    True(t.file:find("Media\\Classic\\UI%-QuestLog%-") ~= nil, piece[1] .. ": EraUI's copy")
    Equal(t.layer, "BACKGROUND", piece[1] .. ": BACKGROUND")
    Near(t.width, piece[2], piece[1] .. ": width")
    Near(t.height, piece[3], piece[1] .. ": height")
    At(game, sheet, piece[4], window, piece[4], 0, 0, piece[1])
    True(sheet:IsShown(), piece[1] .. ": shown in single pane")
end
for i, key in ipairs({ "questLogDualLeft", "questLogDualRight" }) do
    Equal(game.State(P.double[i]).theme, key, key .. ": its Dark Mode key")
    False(P.double[i]:IsShown(), key .. ": hidden in single pane")
end
local book = game.State(P.book)
True(book.file:find("UI%-QuestLog%-BookIcon") ~= nil, "the book")
Equal(book.theme, nil, "the book keeps its colours")
Near(book.width, 64, "the book is 64 across")
At(game, P.book, "TOPLEFT", window, "TOPLEFT", 4, -4, "the book")
Equal(P.title:GetText(), "Quest Log", "the title")
Equal(game.State(P.title).layer, "OVERLAY", "the title over the art")
At(game, P.title, "TOP", window, "TOP", 0, -17, "the title")
Near(P.close:GetWidth(), 32, "the X is 32 across")
At(game, P.close, "TOPRIGHT", window, "TOPRIGHT", -30, -8, "the X")
True(game.State(P.close:GetNormalTexture()).file:find("UI%-Panel%-MinimizeButton%-Up") ~= nil, "the 1.x X")
local darkX = false
for _, entry in ipairs(game.darkened) do if entry[1] == "DarkCloseButton" and entry[2] == P.close then darkX = true end end
True(darkX, "the X handed to Dark Windows")
P.close:Click()
False(window:IsShown(), "the X closes the log")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LOG_CLOSE", "the close sound")
ns.ShowQuestLog()

-- The count box.
Equal(P.countText:GetText(), "Quests: 10/20", "the quest count (the game's own count of quests)")
Colour({ P.countText:GetTextColor() }, 1, 0.92, 0, "the count in the quest yellow")
At(game, P.countCap, "TOPRIGHT", window, "TOPRIGHT", -47, -41, "the count box's right cap")
local caps = {}
for i = 1, 3 do caps[i] = Look.OwnPiece(window, "count" .. i) end
for i, cut in ipairs({ { 0, 1 / 16 }, { 1 / 16, 15 / 16 }, { 15 / 16, 1 } }) do
    local t = game.State(caps[i])
    Equal(t.file, "Interface\\Common\\Common-Input-Border", "count piece " .. i .. ": the input border")
    Near(t.coords[1], cut[1], "count piece " .. i .. ": its left cut")
    Near(t.coords[2], cut[2], "count piece " .. i .. ": its right cut")
    Near(t.coords[4], 0.625, "count piece " .. i .. ": the top five eighths")
end
Near(game.State(caps[3]).width, 8, "the right cap 8 wide")
Near(game.State(caps[2]).width, #"Quests: 10/20" * 6, "the middle as wide as the words")
At(game, caps[2], "RIGHT", caps[3], "LEFT", 0, 0, "the middle left of the cap")
At(game, caps[1], "RIGHT", caps[2], "LEFT", 0, 0, "the left cap left of the middle")
At(game, P.countText, "RIGHT", caps[3], "RIGHT", -6, 0, "the words 6 in from the right cap's edge")
game.maxQuests = nil
game.env.C_QuestLog.GetMaxNumQuestsCanAccept = function() return nil end
game.env.MAX_QUESTS = 25
Q.FillCount()
Equal(P.countText:GetText(), "Quests: 10/25", "MAX_QUESTS when the game won't say")
game.env.MAX_QUESTS = nil
Q.FillCount()
Equal(P.countText:GetText(), "Quests: 10/20", "else 20")
Near(game.State(caps[2]).width, #"Quests: 10/20" * 6, "the middle follows the words")
game.env.C_QuestLog.GetMaxNumQuestsCanAccept = function() return game.maxQuests end
game.maxQuests = 20

-- The All tab and the radios.
At(game, P.allHolder, "TOPLEFT", window, "TOPLEFT", 70, -48, "the All tab's holder")
Near(P.allHolder:GetWidth(), 54, "the holder 54 wide")
Near(P.allTab:GetWidth(), 40, "the tab 40 x 22")
At(game, P.allTab, "TOPLEFT", P.allHolder, "TOPLEFT", 0, -2, "the tab 2 down in its holder")
local tabArt = { Look.OwnPiece(P.allHolder, "tabLeft"), Look.OwnPiece(P.allHolder, "tabMiddle"), Look.OwnPiece(P.allHolder, "tabRight") }
for i, key in ipairs({ "questLogTabLeft", "questLogTabMiddle", "questLogTabRight" }) do
    Equal(game.State(tabArt[i]).theme, key, key .. ": its Dark Mode key")
    Equal(game.State(tabArt[i]).layer, "BACKGROUND", key .. ": behind the tab")
end
Near(game.State(tabArt[2]).width, 38, "the middle 38 wide")
At(game, tabArt[1], "TOPLEFT", P.allTab, "TOPLEFT", -6, 8, "the tab art's left piece")
At(game, tabArt[3], "LEFT", tabArt[2], "RIGHT", 0, 0, "joined in a row")
Equal(game.State(P.allIcon).file, "Interface\\Buttons\\UI-MinusButton-Up", "the All icon: minus while open")
local allGlow = Look.OwnPiece(P.allTab, "glow")
Equal(game.State(allGlow).layer, "HIGHLIGHT", "the tab's hover glow")
Equal(game.State(allGlow).blend, "ADD", "additive")
local allLabel = Look.OwnLabel(P.allTab, "label")
Equal(allLabel:GetText(), "All", "the tab's label")
At(game, allLabel, "LEFT", P.allTab, "LEFT", 20, 0, "20 in")
At(game, P.trackRadio, "LEFT", P.allHolder, "RIGHT", 5, 17, "Track Quest above the middle of the tab")
At(game, P.dualRadio, "LEFT", P.allHolder, "RIGHT", 5, 0, "Double pane beside it")
for _, radio in ipairs({ P.trackRadio, P.dualRadio }) do
    Equal(game.State(radio).kind, "CheckButton", "a radio is a check button")
    Near(radio:GetWidth(), 20, "20 x 20")
    local rest, on, hover = game.State(radio:GetNormalTexture()), game.State(radio:GetCheckedTexture()),
        game.State(radio:GetHighlightTexture())
    Equal(rest.file, "Interface\\Buttons\\UI-RadioButton", "the 1.x radio sheet")
    Near(rest.coords[2], 0.25, "at rest: the first quarter")
    Near(on.coords[1], 0.25, "checked: the second quarter")
    Near(hover.coords[1], 0.5, "hover: the third quarter")
    Equal(hover.blend, "ADD", "the hover additive")
end
Equal(Look.OwnLabel(P.trackRadio, "words"):GetText(), "Track Quest", "Track Quest's words")
Equal(Look.OwnLabel(P.dualRadio, "words"):GetText(), "Double pane", "Double pane's words")
False(P.showMap:IsShown(), "Show Map only in double pane")
local mapPad = game.PadFor(P.showMap)
True(mapPad ~= nil, "Show Map has the secure pad")
Equal(mapPad.strata, "DIALOG", "at DIALOG")
True(mapPad.target == nil and mapPad.after ~= nil, "clicking the minimap's zone button, then closing the log")

-- The panes, their bars and the foot.
At(game, P.list, "TOPLEFT", window, "TOPLEFT", 19, -75, "the list area")
Near(P.list:GetWidth(), 300, "the list 300 wide")
Near(P.list:GetHeight(), 93, "and 93 tall")
True(game.State(P.list).clips, "the list clips its rows")
At(game, P.detail, "TOPLEFT", window, "TOPLEFT", 19, -175, "the detail pane 7 below the list")
At(game, P.detail, "BOTTOMRIGHT", window, "TOPLEFT", 319, -435, "pinned by two corners")
Near(P.detail:GetHeight(), 260, "260 tall")
Equal(game.State(P.detail).scrollChild, P.page, "its page")
At(game, P.listBar, "TOPLEFT", P.list, "TOPRIGHT", 7, -16, "the list bar 7 right, 16 in")
At(game, P.listBar, "BOTTOMLEFT", P.list, "BOTTOMRIGHT", 7, 16, "and 16 in at the bottom")
At(game, P.detailBar, "TOPLEFT", P.detail, "TOPRIGHT", 7, -16, "the detail bar 7 right")
At(game, P.detailBar, "BOTTOMLEFT", P.detail, "BOTTOMRIGHT", 7, 16, "and 16 in at the bottom")
local footWords = { { P.abandon, "Abandon Quest", 125 }, { P.share, "Share Quest", 123 }, { P.exit, "Exit", 77 } }
for _, foot in ipairs(footWords) do
    Equal(foot[1]:GetText(), foot[2], foot[2] .. ": its words")
    Near(foot[1]:GetWidth(), foot[3], foot[2] .. ": its width")
    Near(foot[1]:GetHeight(), 22, foot[2] .. ": 22 tall")
    local red = false
    for _, entry in ipairs(game.darkened) do if entry[1] == "DarkRedButton" and entry[2] == foot[1] then red = true end end
    True(red, foot[2] .. ": a red panel button for Dark Windows")
end
At(game, P.abandon, "BOTTOMLEFT", window, "BOTTOMLEFT", 17, 54, "Abandon Quest")
At(game, P.exit, "BOTTOMRIGHT", window, "BOTTOMRIGHT", -43, 54, "Exit")
At(game, P.share, "RIGHT", P.exit, "LEFT", 0, 0, "Share Quest left of Exit")
False(P.track:IsShown(), "the Track button only in double pane")
False(P.empty:IsShown(), "the empty art hidden while there are quests")
At(game, P.empty, "TOPLEFT", window, "TOPLEFT", 19, -73, "the empty pane")
for i, key in ipairs({ "questLogEmptyTopLeft", "questLogEmptyTopRight", "questLogEmptyBotLeft", "questLogEmptyBotRight" }) do
    Equal(game.State(P.emptyArt[i]).theme, key, key .. ": its Dark Mode key")
end
At(game, P.emptyArt[4], "TOPLEFT", P.empty, "TOPLEFT", 256, -256, "the empty art's last piece")

---------------------------------------------------------------------------
-- The list
---------------------------------------------------------------------------

local rows = Visible(Q)
Equal(#rows, 6, "six rows in single pane")
Equal(#Q.entries, 9, "two headers and seven quests (hidden, task and bounty left out)")
Equal(Words(game, Q, rows[1]), "Elwynn Forest", "a header's words")
Equal(Words(game, Q, rows[2]), "  Wolves", "a quest's words: two spaces first")
Colour({ Look.OwnLabel(rows[1], "title"):GetTextColor() }, 0.75, 0.75, 0.75, "a header in the game's header grey")
Equal(game.State(Look.OwnPiece(rows[1], "icon")).file, "Interface\\Buttons\\UI-MinusButton-Up", "an open header's minus")
True(Look.OwnPiece(rows[1], "icon"):IsShown(), "the icon on headers")
False(Look.OwnPiece(rows[2], "icon"):IsShown(), "no icon on quests")
local headerGlow = game.State(rows[1]:GetHighlightTexture())
Equal(headerGlow.file, "Interface\\Buttons\\UI-PlusButton-Hilight", "a header's hover glow")
At(game, rows[1]:GetHighlightTexture(), "TOPLEFT", Look.OwnPiece(rows[1], "icon"), "TOPLEFT", 0, 0, "over its icon")
for i = 2, 6 do
    At(game, Q.rows[i], "TOPLEFT", Q.rows[i - 1], "BOTTOMLEFT", 0, -0.6, "row " .. i .. " a 15.6 pitch")
end
Near(rows[1]:GetHeight(), 15, "rows 15 tall")
Equal(Q.selected, 101, "nothing chosen yet: the first quest")
Equal(game.selected, 101, "and the game's selection follows")
-- Colours by level (you are 10): 8 yellow, 12 yellow, 15 red, 13 orange,
-- 4 grey (6 below, past 5), 7 green.
Colour(game.State(Look.OwnLabel(rows[2], "title")).textColour, 1, 0.92, 0, "two below: yellow")
Q.parts.listBar:SetValue(3)
Equal(Q.ListOffset(), 3, "the list scrolled by its bar")
Equal(Words(game, Q, Q.rows[1]), "  Murlocs", "the rows follow the bar")
local tags = {}
for i = 1, 6 do tags[i] = Plain(Look.OwnLabel(Q.rows[i], "tag"):GetText()) end
Equal(tags[1], "(Complete)", "complete before daily")
Equal(tags[2], "", "a header has no tag")
Equal(tags[3], "(Daily)", "daily")
Equal(tags[4], "(Weekly)", "weekly")
Equal(tags[5], "(Elite)", "the game's tag name before group")
Equal(tags[6], "(Group)", "group")
Colour(game.State(Look.OwnLabel(Q.rows[3], "title")).textColour, 1, 0.1, 0.1, "five above: red")
Colour(game.State(Look.OwnLabel(Q.rows[4], "title")).textColour, 1, 0.5, 0.25, "three above: orange")
Colour(game.State(Look.OwnLabel(Q.rows[5], "title")).textColour, 0.5, 0.5, 0.5, "six below: grey")
Colour(game.State(Look.OwnLabel(Q.rows[6], "title")).textColour, 0.25, 0.75, 0.25, "three below: green")
Colour(game.State(Look.OwnLabel(Q.rows[6], "tag")).textColour, 0.25, 0.75, 0.25, "the tag in the same colour")
game.greenRange = 2
Q.Refresh()
Colour(game.State(Look.OwnLabel(Q.rows[6], "title")).textColour, 0.5, 0.5, 0.5, "the game's green range (2): grey")
game.greenRange = nil
-- The width cap: a long title with a tag.
game.quests[104].title = string.rep("x", 60)
Q.Refresh()
local longRow, longTag = Q.rows[3], Look.OwnLabel(Q.rows[3], "tag")
Near(Look.OwnLabel(longRow, "title"):GetWidth(), 275 - (#"(Daily)" * 6 + 15), "the title capped at 275 less the tag and 15")
game.quests[104].title = "Defias"
Q.Refresh()
Near(Look.OwnLabel(longRow, "title"):GetWidth(), #"  Defias" * 6, "a short title at its own width")
True(longTag:IsShown(), "the tag shown")
Q.parts.listBar:SetValue(0)
-- The check mark beside a watched quest.
local check = Look.OwnPiece(Q.rows[2], "check")
True(check:IsShown(), "a watched quest has the check mark")
Equal(game.State(check).file, "Interface\\Buttons\\UI-CheckBox-Check", "the 1.x check")
Equal(game.State(check).layer, "OVERLAY", "over the words")
At(game, check, "LEFT", Q.rows[2], "LEFT", 20 + #"  Wolves" * 6 + 4, 0, "4 right of the title's end")
False(Look.OwnPiece(Q.rows[3], "check"):IsShown(), "no mark on a quest not watched")
-- The selected quest.
local chosen = game.State(Q.rows[2])
True(chosen.highlightLocked, "the selected quest's glow held on")
Colour(game.State(Q.rows[2]:GetHighlightTexture()).colour, 1, 0.92, 0, "in the quest's colour")
True(game.State(Q.rows[2]:GetHighlightTexture()).file:find("UI%-QuestLogTitleHighlight") ~= nil, "the 1.x title glow")
At(game, Q.rows[2]:GetHighlightTexture(), "TOPLEFT", Q.rows[2], "TOPLEFT", 0, 0, "filling the row")
False(game.State(Q.rows[3]).highlightLocked, "the others not held")
Colour(game.State(Q.rows[3]:GetHighlightTexture()).colour, 1, 1, 1, "their glow white")
Colour(game.State(Look.OwnLabel(Q.rows[2], "tag")).textColour, 1, 1, 1, "the selected quest's tag white")

-- The party: plain yes only; a hidden name shows as the unit.
game.party = 3
game.partyOn[101] = { party1 = true, party2 = true, party3 = SECRET }
game.names = { party1 = "Ayla", party2 = SECRET }
Q.Refresh()
Equal(Words(game, Q, Q.rows[2]), "  [2] Wolves", "two of the party on it (a hidden answer doesn't count)")
game.partyOn[101].party3 = "error"
Q.Refresh()
Equal(Words(game, Q, Q.rows[2]), "  [2] Wolves", "nor one that errors")
-- The hover.
game.Enter(Q.rows[2])
local tip = Look.TipOwner()
Equal(tip, Q.rows[2], "a quest's tooltip beside its row")
Colour(game.State(Look.OwnLabel(Q.rows[2], "title")).textColour, 1, 1, 1, "the words white while hovered")
game.Leave(Q.rows[2])
Equal(Look.TipOwner(), nil, "gone on leaving")
Colour(game.State(Look.OwnLabel(Q.rows[2], "title")).textColour, 1, 0.92, 0, "the colour back")
-- What the tooltip says.
local shown = {}
local realShow = Look.ShowTip
Look.ShowTip = function(owner, side, lines) shown = { owner = owner, side = side, lines = lines } return realShow(owner, side, lines) end
game.Enter(Q.rows[3])
Equal(shown.side, "RIGHT", "to the right")
Equal(shown.lines[1][1], "Bears", "the title")
Colour({ shown.lines[1][2], shown.lines[1][3], shown.lines[1][4] }, 1, 1, 1, "in white")
Equal(shown.lines[2][1], "Failed", "the tag")
Colour({ shown.lines[2][2], shown.lines[2][3], shown.lines[2][4] }, 0.8, 0.8, 0.8, "in grey")
game.Leave(Q.rows[3])
game.Enter(Q.rows[2])
Equal(#shown.lines, 5, "with party members (and no tag): title, blank, the line, two names")
Equal(shown.lines[2][1], " ", "a blank line")
Equal(shown.lines[3][1], "Party members that are on this quest:", "the party line")
Colour({ shown.lines[3][2], shown.lines[3][3], shown.lines[3][4] }, 1, 0.82, 0, "in gold")
Equal(shown.lines[4][1], "Ayla", "a name")
Colour({ shown.lines[4][2], shown.lines[4][3], shown.lines[4][4] }, 1, 1, 1, "in white")
Equal(shown.lines[5][1], "party2", "a hidden name as its unit")
game.Leave(Q.rows[2])
game.Enter(Q.rows[1])
Equal(Look.TipOwner(), nil, "a header has no tooltip")
Colour(game.State(Look.OwnLabel(Q.rows[1], "title")).textColour, 1, 1, 1, "but its words go white")
game.Leave(Q.rows[1])
Colour(game.State(Look.OwnLabel(Q.rows[1], "title")).textColour, 0.75, 0.75, 0.75, "and back")
-- A hovered quest line that a refresh turns into a header loses its tooltip.
game.Enter(Q.rows[2])
Equal(Look.TipOwner(), Q.rows[2], "a hovered quest line has its tooltip")
ns.QuestLogSetAllCollapsed(true)
Q.Refresh()
True(Q.entries[2] and Q.entries[2].header, "folded, that line now shows a header")
Equal(Look.TipOwner(), nil, "and the quest's tooltip is gone")
ns.QuestLogSetAllCollapsed(false)
Q.Refresh()
game.Leave(Q.rows[2])
Look.ShowTip = realShow
game.party, game.partyOn, game.names = 0, {}, {}

-- Clicks: select, Shift (watch), chat link.
Q.rows[3]:Click("LeftButton")
Equal(Q.selected, 102, "a click chooses the quest")
Equal(game.selected, 102, "in the game too")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LIST_SELECT", "with its sound")
Q.rows[3]:Click("RightButton")
Equal(Q.selected, 102, "a right click acts the same")
game.shift = true
Q.rows[3]:Click("LeftButton")
True(game.quests[102].watched, "Shift-click watches it")
Equal(game.lastWatchKind, 1, "as a manual watch")
Q.rows[3]:Click("LeftButton")
False(game.quests[102].watched, "and unwatches it")
game.quests[102].watched = true
game.canUnwatch = false
Q.rows[3]:Click("LeftButton")
True(game.quests[102].watched, "unless the game won't let it go")
game.canUnwatch, game.shift = true, false
game.quests[102].watched = false
game.modified.CHATLINK = true
game.chatOpen = true
Q.rows[2]:Click("LeftButton")
Equal(game.chat[1], "|Hquest:101|h", "the chat-link click puts the quest's link in chat")
Equal(Q.selected, 102, "and chooses nothing")
game.chatOpen = false
Q.rows[2]:Click("LeftButton")
Equal(Q.selected, 101, "with no chat box open it chooses as usual")
game.modified.CHATLINK = nil

-- Folding: headers, the All tab, the game's own folding.
Q.rows[1]:Click("LeftButton")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LIST_CLOSE", "folding sounds")
Equal(#Q.entries, 6, "Elwynn's three quests folded away")
Equal(game.State(Look.OwnPiece(Q.rows[1], "icon")).file, "Interface\\Buttons\\UI-PlusButton-Up", "a folded header's plus")
Equal(Q.selected, 104, "the selection moves to the first quest still listed")
Equal(game.State(P.allIcon).file, "Interface\\Buttons\\UI-MinusButton-Up", "not every header folded: minus")
P.allTab:Click()
Equal(#Q.entries, 2, "the All tab folds every header")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LIST_CLOSE", "with the closing sound")
Equal(game.State(P.allIcon).file, "Interface\\Buttons\\UI-PlusButton-Up", "every header folded: plus")
Equal(Q.selected, nil, "no quest left to choose")
False(P.abandon:IsEnabled(), "Abandon needs a quest")
False(P.trackRadio:IsEnabled(), "so does Track Quest")
P.trackRadio:Click()
False(P.trackRadio:GetChecked(), "with no quest Track Quest unchecks itself")
P.allTab:Click()
Equal(#Q.entries, 9, "and opens them all again")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LIST_OPEN", "with the opening sound")
Q.rows[1]:Click("LeftButton")
Q.rows[1]:Click("LeftButton")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LIST_OPEN", "unfolding one header sounds too")
game.log[5].collapsed = true
Q.Refresh()
Equal(game.expanded[#game.expanded], 5, "a header the game folded is opened in the game")
False(game.log[5].collapsed, "so every quest can be read")
Equal(#Q.entries, 9, "EraUI's own folding is what hides quests")
ns.QuestLogSetAllCollapsed(true)
Equal(#Q.entries, 9, "ns.QuestLogSetAllCollapsed doesn't refresh by itself")
Q.Refresh()
Equal(#Q.entries, 2, "it folded every listed header")
ns.QuestLogSetAllCollapsed(false)
Q.Refresh()
Equal(#Q.entries, 9, "and forgets the folding")
True(Q.folded[7] == nil and Q.folded["Elwynn Forest"] == nil, "keys: the sort key, else the title")

-- Scrolling: the bar's range, the wheel.
local bar = P.listBar
Equal(select(2, bar:GetMinMaxValues()), 3, "the bar's range: entries less the rows shown")
game.Run(P.list, "OnMouseWheel", -1)
Equal(Q.ListOffset(), 1, "the wheel moves one row a notch")
game.Run(P.list, "OnMouseWheel", -5)
Equal(Q.ListOffset(), 3, "never past the end")
game.Run(P.list, "OnMouseWheel", 9)
Equal(Q.ListOffset(), 0, "nor before the start")

---------------------------------------------------------------------------
-- The detail
---------------------------------------------------------------------------

game.Run(Q.rows[2], "OnClick", "LeftButton")
Equal(Q.selected, 101, "Wolves chosen")
local lines = {}
for _, region in ipairs(game.State(P.page).regions) do
    if game.State(region).kind == "FontString" and region:IsShown() then lines[#lines + 1] = region end
end
local function Says(i) return Plain(lines[i]:GetText()) end
Equal(Says(1), "Wolves", "the title first")
At(game, lines[1], "TOPLEFT", P.page, "TOPLEFT", 5, -5, "5 in at the top-left")
Equal(game.State(lines[1]).font, game.env.QuestFont_Large, "the title font (the first this client has)")
Near(lines[1]:GetWidth(), 285, "lines 285 wide")
Equal(Says(2), "Kill 8 wolves.", "the objectives text")
Equal(game.State(lines[2]).font, game.env.QuestFont, "in the body font")
Near(lines[2]:GetWidth(), 275, "275 wide")
At(game, lines[2], "TOPLEFT", lines[1], "BOTTOMLEFT", 0, -5, "5 below the title")
Equal(Says(3), "Wolf slain: 3/8", "the first objective")
Equal(game.State(lines[3]).font, game.env.QuestFontNormalSmall, "in the small font")
At(game, lines[3], "TOPLEFT", lines[2], "BOTTOMLEFT", 0, -10, "10 below")
Colour(game.State(lines[3]).textColour, 0.18, 0.12, 0.06, "in parchment ink")
Equal(Says(4), "item (Complete)", "a finished objective (its type when it has no text) with (Complete)")
At(game, lines[4], "TOPLEFT", lines[3], "BOTTOMLEFT", 0, -2, "2 below the one before")
Colour(game.State(lines[4]).textColour, 0.2, 0.2, 0.2, "greyed")
Equal(Says(5), "Required Money: 2000c", "the money it asks for")
At(game, lines[5], "TOPLEFT", lines[4], "BOTTOMLEFT", 0, -4, "4 below the objectives")
Colour(game.State(lines[5]).textColour, 1, 0.1, 0.1, "red while you are short")
Equal(Says(6), "Description", "the description heading")
At(game, lines[6], "TOPLEFT", lines[5], "BOTTOMLEFT", 0, -10, "10 below")
Equal(Says(7), "The wolves are a menace.", "the description")
At(game, lines[7], "TOPLEFT", lines[6], "BOTTOMLEFT", 0, -5, "5 below")
Equal(Says(8), "Rewards", "the rewards heading")
At(game, lines[8], "TOPLEFT", lines[7], "BOTTOMLEFT", 0, -10, "10 below")
Equal(Says(9), "Choose one of the following rewards:", "the choices label")
At(game, lines[9], "TOPLEFT", lines[8], "BOTTOMLEFT", 0, -5, "5 below")
True(game.choiceCurrencies == true, "choices counted with currencies")
local plates = {}
for _, child in ipairs(game.State(P.page).children) do
    if child:IsShown() and game.State(child).kind == "Button" then plates[#plates + 1] = child end
end
Equal(#plates, 4, "three choices and one item")
local scale = 141 / 147
Near(plates[1]:GetScale(), scale, "plates scaled so two and a gap fill 285")
At(game, plates[1], "TOPLEFT", lines[9], "BOTTOMLEFT", 0, -4 / scale, "the first plate 4 below the label")
At(game, plates[2], "TOPLEFT", plates[1], "TOPRIGHT", 3 / scale, 0, "the second 3 right of it")
At(game, plates[3], "TOPLEFT", plates[1], "BOTTOMLEFT", 0, -4 / scale, "the third starts a row")
local first = plates[1]
local icon = Look.OwnPiece(first, "icon")
Near(game.State(icon).width, 39, "the icon 39 x 39")
Equal(game.State(icon).file, "sword", "its texture")
local plateArt = Look.OwnPiece(first, "frame")
True(game.State(plateArt).file:find("UI%-QuestItemNameFrame") ~= nil, "the 1.x name plate")
Equal(game.State(plateArt).theme, nil, "not tinted")
Equal(game.State(plateArt).sublevel, 1, "above the icon's layer")
At(game, plateArt, "LEFT", icon, "RIGHT", -10, 0, "its left 10 inside the icon's edge")
local name = Look.OwnLabel(first, "name")
Equal(name:GetText(), "Sword", "the item's name")
Equal(game.State(name).maxLines, 3, "at most three lines")
At(game, name, "LEFT", plateArt, "LEFT", 15, 0, "15 into the plate")
False(Look.OwnLabel(first, "count"):IsShown(), "no count for one")
Equal(Look.OwnLabel(plates[3], "name"):GetText(), "item 77", "a reward with no name: item and its ID")
Equal(Look.OwnLabel(plates[3], "count"):GetText(), "2", "a count above one")
local itemsLabel = lines[10]
Equal(Plain(itemsLabel:GetText()), "You will also receive:", "items after choices")
At(game, itemsLabel, "TOPLEFT", plates[3], "BOTTOMLEFT", 0, -5, "5 below the last row of plates")
Equal(Says(11), "250c", "the money beside it")
At(game, lines[11], "TOPLEFT", itemsLabel, "TOPLEFT", #"You will also receive:" * 6 + 15, 0, "15 right of the label's words")
At(game, plates[4], "TOPLEFT", itemsLabel, "BOTTOMLEFT", 0, -4 / scale, "the item's plate under the label")
Equal(Says(12), "Experience: 1,250", "the experience")
At(game, lines[12], "TOPLEFT", plates[4], "BOTTOMLEFT", 0, -4, "4 below")
-- The page's height and the detail bar.
local pageTop = P.page:GetTop()
local lastBottom = lines[12]:GetBottom()
Near(P.page:GetHeight(), math.max(260, pageTop - lastBottom + 12), "the page reaches the last line and 12 more")
Equal(select(2, P.detailBar:GetMinMaxValues()), P.page:GetHeight() - 260, "the detail bar's range")
game.Run(P.detail, "OnMouseWheel", -1)
Near(P.detailBar:GetValue(), math.min(20, P.page:GetHeight() - 260), "the wheel moves the detail 20 a notch")
Near(P.detail:GetVerticalScroll(), P.detailBar:GetValue(), "the pane follows its bar")
-- A reward's tooltip: the game's own data, in EraUI's box.
game.Enter(plates[1])
Equal(Look.TipOwner(), plates[1], "a reward's tooltip")
Equal(game.tipAsked[1], "choice", "asked of the game's tooltip data: a choice")
Equal(game.tipAsked[2], 1, "the first")
Equal(game.tipAsked[3], 101, "of this quest")
game.Leave(plates[1])
Equal(Look.TipOwner(), nil, "gone on leaving")
game.env.C_TooltipInfo.GetQuestLogItem = function() return nil end
local fallback = {}
Look.ShowTip = function(owner, side, lines2) fallback = lines2 return realShow(owner, side, lines2) end
game.Enter(plates[1])
Equal(fallback[1][1], "Sword", "no data: the name")
Colour({ fallback[1][2], fallback[1][3], fallback[1][4] }, 0.12, 1, 0, "in its quality colour")
game.Leave(plates[1])
Look.ShowTip = realShow
game.modified.CHATLINK, game.chatOpen = true, true
plates[4]:Click()
Equal(game.chat[#game.chat], "|Hitem:reward1:101|h", "a chat-link click on a reward links it")
game.modified.CHATLINK, game.chatOpen = nil, false
-- Dark Mode's near-white ink.
game.settings.darkMode = true
Q.Refresh()
Colour(game.State(lines[1]).textColour, 0.88, 0.87, 0.83, "Dark Mode: the ink near white")
Colour(game.State(lines[4]).textColour, 0.88, 0.87, 0.83, "finished lines too")
game.settings.darkMode = false
-- Pooled: a smaller quest leaves nothing behind.
game.Run(Q.rows[3], "OnClick", "LeftButton")
local after = 0
for _, region in ipairs(game.State(P.page).regions) do
    if game.State(region).kind == "FontString" and region:IsShown() then after = after + 1 end
end
Equal(after, 3, "Bears: title, description heading, description")
Equal(Plain(lines[1]:GetText()), "Bears - (Failed)", "a failed quest's title")
At(game, lines[2], "TOPLEFT", lines[1], "BOTTOMLEFT", 0, -10, "the heading 10 below (no objectives, no money)")
for _, plate in ipairs(plates) do False(plate:IsShown(), "no plate left over") end
Near(P.page:GetHeight(), 260, "a short quest: the pane's own height")
Equal(select(2, P.detailBar:GetMinMaxValues()), 0, "nothing to scroll")
Equal(P.detailBar:GetValue(), 0, "a newly chosen quest starts at the top")
-- A timer, redrawn once a second.
game.quests[102].timeLeft = 90
game.Run(Q.rows[3], "OnClick", "LeftButton")
Equal(Plain(lines[2]:GetText()), "Time Remaining: 90 sec", "the time left")
At(game, lines[2], "TOPLEFT", lines[1], "BOTTOMLEFT", 0, -10, "10 below")
game.quests[102].timeLeft = 89
game.Tick(0.5)
Equal(Plain(lines[2]:GetText()), "Time Remaining: 90 sec", "not before a second")
game.Tick(0.55)
Equal(Plain(lines[2]:GetText()), "Time Remaining: 89 sec", "redrawn after a second")
game.quests[102].timeLeft = nil
Q.Refresh()
-- Money you have: finished ink; a quest with nothing to reward.
game.quests[101].money = 500
game.Run(Q.rows[2], "OnClick", "LeftButton")
Colour(game.State(lines[5]).textColour, 0.2, 0.2, 0.2, "money you have: the finished ink")
game.quests[101].money = 2000

---------------------------------------------------------------------------
-- The foot: Abandon, Share, Track Quest
---------------------------------------------------------------------------

True(P.abandon:IsEnabled(), "Abandon with a quest chosen")
False(P.share:IsEnabled(), "Share needs a group")
game.inGroup = true
Q.Refresh()
True(P.share:IsEnabled(), "in a group with a quest that can be shared")
game.quests[101].pushable = SECRET
Q.Refresh()
False(P.share:IsEnabled(), "a hidden answer is a no")
game.quests[101].pushable = true
Q.Refresh()
P.share:Click()
Equal(game.pushes[1], 2, "Share pushes the quest's place in the log")
game.inGroup = false
game.Run(P.share, "OnClick", "LeftButton")
Equal(game.messages[#game.messages][1], "You are not in a party.", "not in a group: the red line")
Colour({ game.messages[#game.messages][2], game.messages[#game.messages][3], game.messages[#game.messages][4] }, 1, 0.1, 0.1, "in red")
Equal(#game.pushes, 1, "and nothing shared")
P.abandon:Click()
Equal(game.abandonSet, 101, "the quest set for abandoning")
Equal(game.popups[1][1] .. game.popups[1][2], "hideABANDON_QUEST_WITH_ITEMS", "no items: the other pop-up hidden")
Equal(game.popups[2][2], "ABANDON_QUEST", "the game's own pop-up")
Equal(game.popups[2][3], "Wolves", "with the quest's name")
Equal(game.sounds[#game.sounds], "sound:IG_QUEST_LOG_ABANDON_QUEST", "the abandon sound")
game.quests[101].abandonItems = { 11, 12 }
game.itemNames = { [11] = "Rope" }
P.abandon:Click()
Equal(game.popups[3][1] .. game.popups[3][2], "hideABANDON_QUEST", "with items: the plain pop-up hidden")
Equal(game.popups[4][2], "ABANDON_QUEST_WITH_ITEMS", "the pop-up with items")
Equal(game.popups[4][4], "Rope, 12", "naming them (an unknown one by its ID)")
True(P.trackRadio:GetChecked(), "Track Quest checked for a watched quest")
P.trackRadio:Click()
False(game.quests[101].watched, "unchecking it unwatches the quest")
Equal(game.sounds[#game.sounds], "sound:IG_MAINMENU_OPTION_CHECKBOX_OFF", "with the box sound")
P.trackRadio:Click()
True(game.quests[101].watched, "checking it watches it again")
Equal(game.sounds[#game.sounds], "sound:IG_MAINMENU_OPTION_CHECKBOX_ON", "and its sound")
P.exit:Click()
False(window:IsShown(), "Exit closes the log")

---------------------------------------------------------------------------
-- Double pane, and back
---------------------------------------------------------------------------

ns.ShowQuestLog()
local passes = game.passes
P.dualRadio:Click()
Equal(ns.db.questLogDual, true, "the radio saves the choice")
Equal(game.passes, passes + 1, "and runs a full pass")
True(game.optionsRefreshes > 0, "and refreshes the Classic option list")
Near(window:GetWidth(), 680, "680 wide")
Near(window:GetHeight(), 440, "440 tall")
for i = 1, 4 do False(P.single[i]:IsShown(), "the single pane's art hidden") end
for i = 1, 2 do True(P.double[i]:IsShown(), "the 3.x art shown") end
At(game, P.double[2], "TOPLEFT", window, "TOPLEFT", 512, 0, "the right half from 512")
At(game, P.book, "TOPLEFT", window, "TOPLEFT", 6, -6, "the book")
At(game, P.title, "TOP", window, "TOP", 0, -19, "the title")
At(game, P.close, "TOPRIGHT", window, "TOPRIGHT", 3, -8, "the X")
At(game, P.countCap, "TOPLEFT", window, "TOPLEFT", 190, -40, "the count box grows left from 190")
At(game, P.dualRadio, "LEFT", P.countCap, "RIGHT", 8, 0, "Double pane beside it")
True(P.dualRadio:GetChecked(), "and checked")
False(P.allHolder:IsShown(), "no All tab")
False(P.trackRadio:IsShown(), "no Track Quest radio")
True(P.showMap:IsShown(), "Show Map shown")
At(game, P.showMap, "TOPRIGHT", window, "TOPRIGHT", -36, -40, "at the top right")
At(game, P.list, "TOPLEFT", window, "TOPLEFT", 20, -76, "the list")
Near(P.list:GetHeight(), 332, "332 tall")
Near(P.list:GetWidth(), 296, "296 wide")
At(game, P.detail, "TOPLEFT", window, "TOPLEFT", 352, -80, "the detail beside it")
Near(P.detail:GetWidth(), 292, "292 wide")
Near(P.detail:GetHeight(), 328, "328 tall")
Near(P.page:GetWidth(), 292, "the page as wide as the pane")
At(game, P.listBar, "TOPLEFT", P.list, "TOPRIGHT", 10, -14, "the list bar 10 right, 14 in")
At(game, P.detailBar, "TOPLEFT", P.detail, "TOPRIGHT", 12, -10, "the detail bar 12 right, 10 in at the top")
At(game, P.detailBar, "BOTTOMLEFT", P.detail, "BOTTOMRIGHT", 12, 14, "and 14 at the bottom")
Equal(#Visible(Q), 9, "every entry in the 21 rows")
Near(Q.rows[1]:GetWidth(), 296, "rows as wide as the list")
local dualFoot = { { P.abandon, "Abandon", 104 }, { P.share, "Share", 104 }, { P.track, "Track", 104 }, { P.exit, "Close", 80 } }
for _, foot in ipairs(dualFoot) do
    Equal(foot[1]:GetText(), foot[2], foot[2] .. ": its double-pane words")
    Near(foot[1]:GetWidth(), foot[3], foot[2] .. ": its width")
end
At(game, P.abandon, "BOTTOMLEFT", window, "BOTTOMLEFT", 16, 8, "Abandon")
At(game, P.share, "LEFT", P.abandon, "RIGHT", -4, 0, "Share 4 inside Abandon's edge")
At(game, P.track, "LEFT", P.share, "RIGHT", 2, 0, "Track 2 right of Share")
At(game, P.exit, "BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 8, "Close")
True(P.track:IsShown(), "Track shown")
P.track:Click()
False(game.quests[101].watched, "Track flips the watch")
Equal(game.sounds[#game.sounds], "sound:IG_MAINMENU_OPTION_CHECKBOX_ON", "with the box sound")
P.track:Click()
P.dualRadio:Click()
Equal(ns.db.questLogDual, false, "unticked: single pane saved")
Near(window:GetWidth(), 384, "back to 384")
At(game, P.book, "TOPLEFT", window, "TOPLEFT", 4, -4, "the book back")
At(game, P.close, "TOPRIGHT", window, "TOPRIGHT", -30, -8, "the X back")
At(game, P.countCap, "TOPRIGHT", window, "TOPRIGHT", -47, -41, "the count box back")
At(game, P.dualRadio, "LEFT", P.allHolder, "RIGHT", 5, 0, "the radio back")
At(game, P.list, "TOPLEFT", window, "TOPLEFT", 19, -75, "the list back")
At(game, P.listBar, "TOPLEFT", P.list, "TOPRIGHT", 7, -16, "its bar back")
Equal(P.exit:GetText(), "Exit", "Exit back")
Near(P.exit:GetWidth(), 77, "77 wide again")
At(game, P.share, "RIGHT", P.exit, "LEFT", 0, 0, "Share back beside Exit")
False(P.track:IsShown(), "Track hidden again")
False(P.showMap:IsShown(), "Show Map hidden again")
Equal(#Visible(Q), 6, "six rows again")
Near(Q.rows[1]:GetWidth(), 300, "300 wide again")
-- The registry entry switches it on a pass, both ways.
ns.db.questLogDual = true
game.Pass()
Near(window:GetWidth(), 680, "a pass with questLogDual on: double pane")
ns.db.questLogDual = false
game.Pass()
Near(window:GetWidth(), 384, "and off: single pane")

---------------------------------------------------------------------------
-- The empty log
---------------------------------------------------------------------------

local keep = game.log
game.log = {}
Q.Refresh()
True(P.empty:IsShown(), "no quests: the empty art")
False(P.detail:IsShown(), "no detail")
False(P.listBar:IsShown() or P.detailBar:IsShown(), "no scroll bars")
False(P.allHolder:IsShown(), "no All tab")
Equal(P.countText:GetText(), "Quests: 0/20", "nothing counted")
Equal(P.emptyText:GetText(), "You have no quests.", "the game's words")
Near(P.emptyText:GetWidth(), 200, "200 wide")
At(game, P.emptyText, "TOP", window, "TOP", -20, -105, "under the title")
ns.db.questLogDual = true
game.Pass()
for i = 1, 4 do False(P.emptyArt[i]:IsShown(), "double pane: no empty art") end
At(game, P.emptyText, "TOP", P.list, "TOP", 0, -30, "the words under the list's top")
ns.db.questLogDual = false
game.Pass()
for i = 1, 4 do True(P.emptyArt[i]:IsShown(), "single pane: the empty art back") end
game.log = keep
Q.Refresh()
True(P.detail:IsShown() and P.listBar:IsShown() and P.allHolder:IsShown(), "quests again: all back")
False(P.empty:IsShown(), "the empty art gone")

---------------------------------------------------------------------------
-- Events, quest NPC windows, the game menu, Escape
---------------------------------------------------------------------------

game.log[#game.log + 1] = 111
game.quests[111] = { title = "New one", level = 10, difficultyLevel = 10 }
game.Fire("QUEST_LOG_UPDATE")
Equal(#Q.entries, 10, "a quest log update refreshes the list")
game.log[#game.log] = nil
game.Fire("UNIT_QUEST_LOG_CHANGED", "party1")
Equal(#Q.entries, 10, "another unit's change is not ours")
game.Fire("UNIT_QUEST_LOG_CHANGED", "player")
Equal(#Q.entries, 9, "the player's is")
for _, event in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING", "GOSSIP_SHOW" }) do
    ns.ShowQuestLog()
    game.Fire(event)
    False(window:IsShown(), event .. " closes the log")
end
ns.ShowQuestLog()
game.Fight(true)
env.GameMenuFrame:Show()
True(window:IsShown(), "the game menu in a fight leaves it")
env.GameMenuFrame:Hide()
game.Fight(false)
env.GameMenuFrame:Show()
False(window:IsShown(), "the game menu closes it")
env.GameMenuFrame:Hide()
ns.ShowQuestLog()
game.Escape()
False(window:IsShown(), "Escape closes it")

---------------------------------------------------------------------------
-- A fight; the micro button's pad and the named click target
---------------------------------------------------------------------------

game.Fight(true)
Equal(ns.ShowQuestLog(101), false, "never opened in a fight")
False(window:IsShown(), "still closed")
game.PadClick(env.QuestLogMicroButton)
False(window:IsShown(), "the micro button's pad can't open it in a fight")
game.Fight(false)
game.now = game.now + 1
game.PadClick(env.QuestLogMicroButton)
True(window:IsShown(), "the micro button opens EraUI's log")
Equal(game.gameMicroClicks, 0, "the game's own click never ran")
game.now = game.now + 1
game.Fight(true)
game.PadClick(env.QuestLogMicroButton)
False(window:IsShown(), "in a fight it still closes it")
game.Fight(false)
game.now = game.now + 1
target:Click("LeftButton", true)
target:Click("LeftButton", false)
True(window:IsShown(), "a key press's down and up click toggle it once")
game.now = game.now + 1
ns.ToggleQuestLog()
False(window:IsShown(), "ns.ToggleQuestLog closes it")
ns.ToggleQuestLog()
True(window:IsShown(), "and opens it")
ns.HideQuestLog()
False(window:IsShown(), "ns.HideQuestLog closes it")

-- The Classic Quest Log entry in the game's Key Bindings (Bindings.xml,
-- CLICK EraUIClassicQuestLogBind:LeftButton), set by the player himself:
-- the game clicks the target as the key goes down and again as it comes
-- up. One toggle a press, however long the key is held; the pad's single
-- click still toggles at once.
local takes = {}
for _, kind in ipairs(game.State(target).clicks or {}) do takes[kind] = true end
True(takes.AnyDown == true and takes.AnyUp == true, "the target takes a key's down and up clicks")
game.now = game.now + 1
target:Click("LeftButton", true)
True(window:IsShown(), "a bound key opens the log as it goes down")
game.now = game.now + 0.5
target:Click("LeftButton", false)
True(window:IsShown(), "held half a second, its release leaves the log open")
game.now = game.now + 1
target:Click("LeftButton", true)
game.now = game.now + 0.5
target:Click("LeftButton", false)
False(window:IsShown(), "the next press, held as long, closes it")
game.now = game.now + 1
game.PadClick(env.QuestLogMicroButton)
True(window:IsShown(), "after a key press the micro button's pad opens it at once")
game.now = game.now + 1
game.PadClick(env.QuestLogMicroButton)
False(window:IsShown(), "and closes it")
game.now = game.now + 1
target:Click("LeftButton", true)
target:Click("LeftButton", false)
True(window:IsShown(), "a quick press opens it")
game.now = game.now + 1
game.Fight(true)
target:Click("LeftButton", true)
target:Click("LeftButton", false)
False(window:IsShown(), "in a fight a press closes it")
game.now = game.now + 1
target:Click("LeftButton", true)
target:Click("LeftButton", false)
False(window:IsShown(), "and can't open it (the log never opens in a fight)")
game.Fight(false)
game.now = game.now + 1
target:Click("LeftButton", true)
target:Click("LeftButton", false)
True(window:IsShown(), "after the fight a press opens it again")
ns.HideQuestLog()
False(window:IsShown(), "closed again")

---------------------------------------------------------------------------
-- The saved place wins (across a reload)
---------------------------------------------------------------------------

game.slotX = 352
ns.ShowQuestLog()
At(game, window, "TOPLEFT", env.UIParent, "TOPLEFT", 352, -104, "never dragged: the window manager's slot")
game.Run(window, "OnDragStart")
True(game.State(window).moving, "a drag moves it")
window:ClearAllPoints()
window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 640, -200)
local saves = game.saves
game.Run(window, "OnDragStop")
False(game.State(window).moving, "dropped")
local pos = ns.db.questLogPos
Equal(pos[1] .. pos[2] .. pos[3] .. pos[4], "TOPLEFTTOPLEFT640-200", "its place saved")
Equal(ns.db.questLogPosText, "TOPLEFT,TOPLEFT,640.0,-200.0", "and its text for the settings mirror")
Equal(game.saves, saves + 1, "the mirror written")
ns.HideQuestLog()
ns.ShowQuestLog()
At(game, window, "TOPLEFT", env.UIParent, "TOPLEFT", 640, -200, "the saved place wins over the manager's slot")
window:ClearAllPoints()
window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 0, -104)
At(game, window, "TOPLEFT", env.UIParent, "TOPLEFT", 640, -200, "whatever moves it")
Equal(Look.WindowTrait(window, "hold")(), 640, "it tells the window manager to hold its x")
-- A reload on Forever: the table lost, the mirror's text kept.
local game2, Q2, ns2, env2 = Session({ db = { questLogPosText = "TOPLEFT,TOPLEFT,640.0,-200.0" } })
ns2.ShowQuestLog()
At(game2, env2.EraUIClassicQuestLog, "TOPLEFT", env2.UIParent, "TOPLEFT", 640, -200, "after a reload: the saved place")
Equal(type(ns2.db.questLogPos), "table", "read back into its table")
Equal(Look.WindowTrait(window, "hold") ~= nil, true, "the hold question set")
local game3, _, ns3, env3 = Session()
ns3.ShowQuestLog()
Equal(game3.Look.WindowTrait(env3.EraUIClassicQuestLog, "hold")(), nil, "never dragged: nothing held")

---------------------------------------------------------------------------
-- The map's quest list setting; Show Map
---------------------------------------------------------------------------

game.cvars.questLogOpen = "1"
game.Tick(0.6)
Equal(game.cvars.questLogOpen, "0", "the map opens without its quest list while the log is on")
local writes = #game.cvarWrites
game.Tick(0.6)
Equal(#game.cvarWrites, writes, "written only when it was on")
ns.ShowQuestLog()
ns.db.questLogDual = true
game.Pass()
game.Fight(true)
P.showMap:Click()
Equal(game.messages[#game.messages][1], "You can't do that while in combat", "Show Map in a fight: the red line")
True(window:IsShown(), "and nothing else")
game.Fight(false)
P.showMap:Click()
False(window:IsShown(), "its own click closes the log")
True(env.WorldMapFrame:IsShown(), "and opens the map")
env.WorldMapFrame:Hide()
ns.ShowQuestLog()
game.PadClick(P.showMap)
True(env.WorldMapFrame:IsShown(), "its pad opens the map through the minimap's zone button")
False(window:IsShown(), "then closes the log")
env.WorldMapFrame:Hide()
ns.db.questLogDual = false
game.Pass()

---------------------------------------------------------------------------
-- Off and on
---------------------------------------------------------------------------

ns.ShowQuestLog()
ns.db.questLog = false
game.Pass()
False(window:IsShown(), "turned off: closed")
Equal(ns.ShowQuestLog(), false, "and it won't open")
False(pad.when(), "the micro button's pad stands aside (the game's own click again)")
game.cvars.questLogOpen = "1"
game.Tick(0.6)
Equal(game.cvars.questLogOpen, "1", "the map's quest list left to the game")
game.now = game.now + 1
target:Click("LeftButton")
False(window:IsShown(), "the click target does nothing while off")
ns.db.questLog = true
game.Pass()
True(ns.ShowQuestLog(), "on again: it opens")
Equal(#game.registered, 1, "registered once")

-- A login with the log off: no hooks, no target, no pad.
local game4, _, ns4, env4 = Session({ db = { questLog = false } })
Equal(env4.EraUIClassicQuestLogBind, nil, "off at login: no click target")
Equal(game4.PadFor(env4.QuestLogMicroButton), nil, "and no pad")
Equal(ns4.ShowQuestLog(), false, "and no log")

Equal(#game.errors, 0, "no error reported: " .. tostring(game.errors[1]))
Equal(#game2.errors + #game3.errors + #game4.errors, 0, "none in the other sessions")
print("Quest log checks passed: " .. checks .. " assertions.")
