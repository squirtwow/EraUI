-- The stat panes (Look/CharPanes.lua, registry "statPanes", clean-room
-- 2026-10-21) on Tools/CharMockGame.lua: two 2.x boxes in place of the 1.x
-- stat boxes, each listing a section of the game's own character stats,
-- filled by the game's own stat functions and hovered with the game's own
-- stat hover (the panes' lines come from the game's CharacterStatFrameTemplate,
-- so EraUI's code never touches the game's tooltip).
-- Checked: the sections (the game's player ones, EraUI's own five when the
-- game has none, Resistances last, their keys); a saved key that matches
-- nothing; what is left out (showFunc, hideAt, an error, a hidden line, an
-- empty value); the resistance lines; scrolling; the stats kept hidden; a
-- pick saved at once; on and off against the 1.x boxes and the model; only
-- while the window's look is on; the drop list; the hover.
-- Run: fengari Tools/TestStatPanes.lua
local Mock = dofile("Tools/CharMockGame.lua")
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

local function Session(opts)
    opts = opts or {}
    opts.db = opts.db or { statPanes = true }
    local game = Mock.New(opts)
    local C = game.Load()
    game.Pass()
    game.Open("PaperDollFrame")
    local s = { game = game, C = C, env = game.env, P = C.StatPanes() }
    function s.Lines(pane)
        local out = {}
        for _, line in ipairs(pane.lines) do
            if line:IsShown() then out[#out + 1] = line.Label:GetText() .. "=" .. line.Value:GetText() end
        end
        return table.concat(out, " ")
    end
    function s.Clean(label)
        Equal(#game.errors, 0, label .. ": nothing reached the error handler (" .. tostring(game.errors[1]) .. ")")
    end
    return s
end

-- The sections and the default picks.
do
    local s = Session()
    local game, C, P = s.game, s.C, s.P
    local sections = C.StatSections()
    Equal(#sections, 6, "the game's five player sections, then Resistances")
    local labels = {}
    for i, section in ipairs(sections) do
        labels[i] = section.label
        Equal(section.key, "section" .. i, "section " .. i .. "'s key")
    end
    Equal(table.concat(labels, ","), "General,Primary Attributes,Weapons,Modifiers,Defense,Resistances", "in the game's order (the pet's left out)")
    local left, right = P.panes[1], P.panes[2]
    Equal(game.ns.db.statPaneLeft, "section2", "the left pane's default key")
    Equal(left.text:GetText(), "Primary Attributes", "the left pane shows Primary Attributes")
    Equal(right.text:GetText(), "Weapons", "the right pane shows Weapons")
    Equal(s.Lines(left), "Strength:=20 Agility:=25 Stamina:=22 Intellect:=18 Spirit:=19", "the game fills the lines")
    Equal(s.Lines(right), "Mainhand_damage:=5 Ranged_damage:=3 Attack_ap:=40", "lines at their hide value left out")
    -- Places and levels.
    local host = s.env.PaperDollFrame
    Near(left.frame:GetLeft() - host:GetLeft(), 66, "the left pane at (66, -286)")
    Near(left.frame:GetTop() - host:GetTop(), -286, "its y")
    Equal(select(2, right.frame:GetPoint(1)), left.frame, "the right pane beside it")
    Near(left.frame:GetWidth(), 115, "115 wide")
    Near(left.frame:GetHeight(), 108, "108 tall")
    True(left.frame:GetFrameLevel() >= s.env.CharacterModelScene:GetFrameLevel() + 5, "above the model")
    True(left.frame:GetFrameLevel() >= host:GetFrameLevel() + 2, "above the paper doll")
    Equal(left.head:GetFrameLevel(), left.frame:GetFrameLevel() + 2, "the head 2 above its pane")
    local line = left.lines[2]
    Near(line:GetWidth(), 103, "a line is 103 wide")
    Near(line:GetTop() - left.frame:GetTop(), -28 - 13, "the second line 13 below the first")
    -- The 1.x boxes swapped out, the model shorter.
    Equal(C.statBox:IsShown(), false, "the 1.x boxes hidden")
    Near(s.env.CharacterModelScene:GetHeight(), 213, "the model 11 shorter")
    s.Clean("sections")
end

-- What is left out, and the resistances.
do
    local s = Session({ db = { statPanes = true, statPaneLeft = "section5", statPaneRight = "section6" } })
    local game, P = s.game, s.P
    local left, right = P.panes[1], P.panes[2]
    Equal(s.Lines(left), "Defense:=60 Dodge:=6 Armor:=50", "Block without a shield (showFunc) and Parry at 0 left out")
    game.shield = true
    game.statError = "DODGE"
    game.Fire("UNIT_STATS", "player")
    Equal(s.Lines(left), "Defense:=60 Block:=5 Armor:=50", "a shield shows Block; an erroring stat is left out")
    game.statError, game.statHides = nil, "DEFENSE"
    game.Fire("UNIT_STATS", "player")
    Equal(s.Lines(left), "Dodge:=6 Block:=5 Armor:=50", "a line the game hid is left out")
    game.statHides, game.statEmpty = nil, "ARMOR"
    game.Fire("UNIT_STATS", "player")
    Equal(s.Lines(left), "Defense:=60 Dodge:=6 Block:=5", "an empty value is left out")
    Equal(s.Lines(right), "Arcane:=3 Fire:=5 Frost:=10 Nature:=0 Shadow:=0", "the resistances, by school name")
    local icon = right.lines[1].Icon
    Equal(icon:IsShown(), true, "a resistance line shows its icon")
    True(icon:GetTexture():find("ResistanceIcons"), "from the resistance sheet")
    Equal(table.concat(game.State(icon).coords, ","), "0,1,0.2265625,0.33984375", "Arcane's icon")
    Equal(select(2, right.lines[1].Label:GetPoint(1)), icon, "its label beside the icon")
    Equal(left.lines[1].Icon:IsShown(), false, "no icon elsewhere")
    s.Clean("left out")
end

-- Scrolling, withheld stats, a pick, the drop list.
do
    local s = Session({ db = { statPanes = true, statPaneLeft = "section4", statPaneRight = "nonsense" } })
    local game, env, P = s.game, s.env, s.P
    for i, stat in ipairs({ "HITCHANCE", "HASTE", "EXPERTISE", "ARMORPEN", "SPELLPOWER", "SPELLHEALING", "SPELLPENETRATION" }) do
        game.statValues[stat] = i
    end
    game.Fire("UNIT_STATS", "player")
    local left, right = P.panes[1], P.panes[2]
    Equal(right.text:GetText(), "Weapons", "a saved key that matches nothing: the pane's default")
    Equal(left.count, 8, "eight Modifiers lines to show")
    Equal(left.lines[1].Label:GetText(), "Hitchance:", "the first at the top")
    game.Run(left.frame, "OnMouseWheel", -1)
    Equal(left.offset, 1, "a notch down scrolls one line")
    Equal(left.lines[1].Label:GetText(), "Critchance:", "the lines follow")
    game.Run(left.frame, "OnMouseWheel", -5)
    Equal(left.offset, 2, "never past the last line")
    game.Run(left.frame, "OnMouseWheel", 9)
    Equal(left.offset, 0, "never above the first")
    -- The game keeps the stats hidden: the old lines stay.
    local before = s.Lines(left)
    game.stats[1] = { 1, SECRET, 0, 0 }
    game.statValues.HITCHANCE = 99
    game.Fire("UNIT_STATS", "player")
    Equal(s.Lines(left), before, "numbers withheld: the old lines stay")
    game.stats[1] = { 20, 20, 0, 0 }
    -- The drop list.
    local saves = game.saves
    game.Run(left.head, "OnClick")
    local drop = left.drop
    True(drop and drop.frame:IsShown(), "a click on the head opens its list")
    Equal(game.sounds[#game.sounds], "on", "with the tick sound")
    Equal(drop.frame:GetFrameStrata(), "FULLSCREEN_DIALOG", "over everything")
    Equal(select(2, drop.frame:GetPoint(1)), left.head, "under the head")
    Equal(select(5, drop.frame:GetPoint(1)), 6, "6 up into it")
    Equal(table.concat(game.State(drop.marks[4]).coords, ","), "0,0.5,0.5,1", "the chosen section marked")
    Equal(table.concat(game.State(drop.marks[1]).coords, ","), "0.5,1,0.5,1", "the others not")
    Equal(game.escaped, drop.frame, "Escape closes the list (the engine's stand-in)")
    local darkList = false
    for _, entry in ipairs(game.darkened) do if entry[1] == "DarkBackdrop" and entry[2] == drop.frame then darkList = true end end
    True(darkList, "the list handed to Dark Windows")
    local rows = { drop.frame:GetChildren() }
    game.Run(rows[1], "OnClick")
    Equal(drop.frame:IsShown(), false, "a pick closes the list")
    Equal(game.ns.db.statPaneLeft, "section1", "and saves the key")
    True(game.saves > saves, "saved to the mirror at once")
    Equal(left.text:GetText(), "General", "the pane shows it")
    Equal(left.offset, 0, "from the top")
    game.Run(left.head, "OnClick")
    left.frame:Hide()
    Equal(drop.frame:IsShown(), false, "the list follows its pane")
    left.frame:Show()
    s.Clean("scrolling")
end

-- The hover is the game's own.
do
    local s = Session({ db = { statPanes = true, statPaneLeft = "section5" } })
    local game, P = s.game, s.P
    local left = P.panes[1]
    local tips = game.gameTips
    game.Run(left.lines[1], "OnEnter")
    Equal(game.gameTips, tips + 1, "a line's hover runs the game's stat tooltip")
    Equal(game.lastStatTip[1], "DEFENSE 60", "with the game's text")
    game.Run(left.lines[1], "OnLeave")
    Equal(game.gameTipHides, 1, "and the game's own hide on leave")
    game.Run(left.lines[3], "OnEnter")
    Equal(game.richTips, 1, "a stat with its own hover runs that instead")
    s.Clean("hover")
end

-- On and off, and only with the window's look.
do
    local s = Session({ db = { statPanes = false } })
    local game, C, P = s.game, s.C, s.P
    Equal(P.built, false, "off at login: no panes")
    Equal(C.statBox:IsShown(), true, "the 1.x boxes show")
    game.ns.db.statPanes = true
    game.Pass()
    Equal(P.panes[1].frame:IsShown(), true, "on: the panes show")
    Equal(C.statBox:IsShown(), false, "the boxes hide")
    Near(s.env.CharacterModelScene:GetHeight(), 213, "the model shorter")
    game.ns.db.statPanes = false
    game.Pass()
    Equal(P.panes[1].frame:IsShown(), false, "off: the panes hide")
    Equal(C.statBox:IsShown(), true, "the boxes come back")
    Near(s.env.CharacterModelScene:GetHeight(), 224, "the model full height")
    game.ns.db.statPanes, game.ns.db.characterSheet = true, false
    game.Pass()
    Equal(P.panes[1].frame:IsShown(), false, "never on the game's own sheet")
    Equal(C.statBox:IsShown(), false, "nor the 1.x boxes")
    game.ns.db.statPanes = false
    game.Pass()
    Equal(C.statBox:IsShown(), false, "turning the panes off doesn't bring the boxes back on the game's sheet")
    s.Clean("on and off")
end
do
    local s = Session({ db = { statPanes = true, characterSheet = false } })
    Equal(s.P.built, false, "the window off at login: the panes are never built")
    s.Clean("never built")
end

-- The game without its stat table: EraUI's own five, then Resistances.
do
    local s = Session({ noStatCategories = true, db = { statPanes = true, statPaneRight = "section5" } })
    local labels = {}
    for i, section in ipairs(s.C.StatSections()) do labels[i] = section.label end
    Equal(table.concat(labels, ","), "General,Primary Attributes,Weapons,Modifiers,Defense,Resistances", "the fallback sections")
    Equal(s.Lines(s.P.panes[1]), "Strength:=20 Agility:=25 Intellect:=18 Stamina:=22 Spirit:=19", "the fallback's own order")
    Equal(s.Lines(s.P.panes[2]), "Defense:=60 Dodge:=6 Block:=5 Armor:=50", "the fallback's Defense ends with Armor (Parry at 0 left out)")
    s.game.ns.db.statPaneRight = "section3"
    s.game.Fire("UNIT_STATS", "player")
    Equal(s.Lines(s.P.panes[2]), "Mainhand_damage:=5 Ranged_damage:=3 Attack_ap:=40", "the fallback's Weapons: the main hand always, the rest left out at 0")
    s.Clean("fallback")
end

-- Without the game's line template: plain lines, filled the same way.
do
    local s = Session({ before = function(game) game.noStatTemplate = true end })
    Equal(s.Lines(s.P.panes[1]), "Strength:=20 Agility:=25 Stamina:=22 Intellect:=18 Spirit:=19", "plain lines still filled")
    s.Clean("no template")
end

print("Stat pane checks passed: " .. checks .. " assertions.")
