-- Classic character window: Melee Attack and Ranged Attack in the 1.x stat
-- boxes (Look/CharStats.lua, clean-room 2026-10-21), on Tools/CharMockGame.lua.
-- Forever has no UnitAttackBothHands or UnitRangedAttack. The rating is then
-- the equipped weapon's skill line, read by ID with
-- C_SkillInfo.GetSkillLineInfoByID: main hand for melee (Unarmed when empty
-- or not a weapon, Feral Combat for a druid in a form), the ranged slot for
-- ranged (Bows, Guns, Crossbows, Thrown, Wands). Rank plus modifier, green up
-- and red down, the hover in EraUI's own tooltip. A client with the old
-- functions keeps the old output. The Skills window's list and selection are
-- never touched, and no secret is ever compared or handed to the game.
-- Run: fengari Tools/TestAttackRating.lua
local Mock = dofile("Tools/CharMockGame.lua")
local SECRET, Strip = Mock.SECRET, Mock.Strip
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end

local GREEN, RED, WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"
local function White(n) return WHITE .. n .. "|r" end
local function Green(n) return GREEN .. n .. "|r" end
local function Red(n) return RED .. n .. "|r" end

-- A level 2 rogue's skill lines. Every rank is different, so a number names
-- its skill.
local SKILLS = {
    [173] = { "Daggers", 10 }, [176] = { "Thrown", 7 }, [43] = { "Swords", 9 }, [55] = { "Two-Handed Swords", 4 },
    [162] = { "Unarmed", 3 }, [45] = { "Bows", 6 }, [46] = { "Guns", 5 }, [226] = { "Crossbows", 8 }, [228] = { "Wands", 2 },
    [229] = { "Polearms", 11 }, [44] = { "Axes", 12 }, [172] = { "Two-Handed Axes", 13 }, [54] = { "Maces", 14 },
    [160] = { "Two-Handed Maces", 16 }, [136] = { "Staves", 17 }, [3014] = { "Feral Combat", 15 },
}
-- Blizzard's own pairs (Camelot PaperDollFrameStats.lua WEAPON_SUBCLASS_TO_SKILL_ID), by slot.
local BLIZZARD = { [0] = 44, [1] = 172, [2] = 45, [3] = 46, [4] = 54, [5] = 160, [6] = 229, [7] = 43, [8] = 55, [10] = 136,
    [13] = 162, [15] = 173, [16] = 176, [18] = 226, [19] = 228 }
local RANGED_KINDS = { [2] = true, [3] = true, [16] = true, [18] = true, [19] = true }
local MAIN, RANGED = 16, 18

local function Session(opts)
    opts = opts or {}
    local game = Mock.New({ before = opts.before })
    for id, skill in pairs(SKILLS) do
        game.skills[id] = { name = skill[1], rank = skill[2], maxRank = 300, modifier = 0, skillID = id, isHeader = false }
    end
    for subclass = 0, 20 do game.items[1000 + subclass] = { 2, subclass } end
    game.items[8], game.items[9] = { 4, 0 }, { 2, 20 } -- armour; a fishing pole
    if opts.old then
        game.env.UnitAttackBothHands = function() return opts.old[1], opts.old[2], 0, 0 end
        game.env.UnitRangedAttack = function() return opts.old[3], opts.old[4] end
    end
    for event in pairs(opts.unknown or {}) do game.unknownEvents[event] = true end
    local C = game.Load()
    local Look = game.Look
    local shown = {}
    local realTip = Look.ShowTip
    Look.ShowTip = function(owner, side, rows)
        shown = {}
        for i, row in ipairs(rows) do shown[i] = row[1] end
        return realTip(owner, side, rows)
    end
    game.Pass()
    game.Open("PaperDollFrame")
    local s = { game = game, C = C, env = game.env }
    function s.Melee() return C.statRows.melee.value:GetText() end
    function s.Ranged() return C.statRows.ranged.value:GetText() end
    function s.Line(name) return C.statRows[name].line end
    function s.Refresh() game.Fire("UNIT_INVENTORY_CHANGED", "player") end
    function s.Hover(name)
        local frame = C.statRows[name].frame
        shown = {}
        game.Run(frame, "OnEnter")
        game.Run(frame, "OnLeave")
        return shown
    end
    return s
end

-- Default: a dagger and throwing knives.
do
    local s = Session()
    Equal(s.Melee(), White("10"), "melee is the Daggers rank in white")
    Equal(s.Ranged(), White("7"), "ranged is the Thrown rank")
    Equal(s.Line("melee"), "You have 10 skill in Daggers.", "melee line")
    Equal(s.Line("ranged"), "You have 7 skill in Thrown.", "ranged line")
    local tip = s.Hover("melee")
    Equal(tip[1], "Melee Attack", "the hover's title")
    Equal(tip[2], "You have 10 skill in Daggers.", "then the line")
    Equal(#tip, 2, "nothing else")
    Equal(s.Hover("ranged")[1], "Ranged Attack", "ranged hover title")
    Equal(s.game.uiCalls, 0, "the Skills list and its selection are never touched")
    Equal(s.game.gameTips, 0, "no game tooltip")
end

-- Every weapon type in both slots, against Blizzard's own pairs.
do
    local s = Session()
    local melee, ranged = 0, 0
    for subclass = 0, 20 do
        s.game.equip[MAIN], s.game.equip[RANGED] = 1000 + subclass, 1000 + subclass
        s.Refresh()
        local wantMelee = (not RANGED_KINDS[subclass]) and BLIZZARD[subclass] or nil
        local wantRanged = RANGED_KINDS[subclass] and BLIZZARD[subclass] or nil
        if wantMelee then
            melee = melee + 1
            Equal(s.Melee(), White(SKILLS[wantMelee][2]), "melee subclass " .. subclass)
            Equal(s.Line("melee"), "You have " .. SKILLS[wantMelee][2] .. " skill in " .. SKILLS[wantMelee][1] .. ".", "melee line " .. subclass)
        else
            Equal(s.Melee(), "--", "no melee skill for subclass " .. subclass)
            Equal(s.Line("melee"), nil, "no melee line for subclass " .. subclass)
        end
        if wantRanged then
            ranged = ranged + 1
            Equal(s.Ranged(), White(SKILLS[wantRanged][2]), "ranged subclass " .. subclass)
        else
            Equal(s.Ranged(), "--", "no ranged skill for subclass " .. subclass)
            Equal(s.Line("ranged"), nil, "no ranged line for subclass " .. subclass)
        end
    end
    Equal(melee, 10, "ten melee types map")
    Equal(ranged, 5, "five ranged types map")
end

-- Nothing to read: "--" and no line.
do
    local s = Session()
    s.game.equip[RANGED] = 8
    s.Refresh()
    Equal(s.Ranged(), "--", "a non-weapon in the ranged slot")
    Equal(s.Line("ranged"), nil, "a stale Thrown line is cleared")
    s.game.equip[RANGED] = nil
    s.Refresh()
    Equal(s.Ranged(), "--", "no ranged weapon")
    Equal(s.C.statRows.rangedPower.value:GetText(), "--", "no ranged power")
    Equal(s.C.statRows.rangedDamage.value:GetText(), "--", "no ranged damage")
    s.game.equip[RANGED] = 1007
    s.Refresh()
    Equal(s.Ranged(), "--", "a melee weapon in the ranged slot")
    s.game.equip[MAIN] = 1002
    s.Refresh()
    Equal(s.Melee(), "--", "a bow in the main hand")
    s.game.equip[MAIN] = 9
    s.Refresh()
    Equal(s.Melee(), "--", "a fishing pole")
    s.game.equip[MAIN] = 77777
    s.Refresh()
    Equal(s.Melee(), "--", "an item the game can't describe is not Unarmed")
    s.game.equip[MAIN] = 8
    s.Refresh()
    Equal(s.Melee(), White("3"), "a non-weapon in the main hand fights Unarmed")
    s.game.equip[MAIN] = nil
    s.Refresh()
    Equal(s.Melee(), White("3"), "an empty main hand fights Unarmed")
    s.game.skills[162] = nil
    s.Refresh()
    Equal(s.Melee(), "--", "a skill line the player doesn't have")
    Equal(s.Line("melee"), nil, "and no line")
end

-- Gear and buffs.
do
    local s = Session()
    s.game.skills[173].modifier = 5
    s.Refresh()
    Equal(s.Melee(), Green("15"), "a +5 modifier shows the total in green")
    Equal(Strip(s.Line("melee")), "You have 15 (10 base +5) skill in Daggers.", "with the base in the line")
    s.game.skills[173].modifier = -3
    s.Refresh()
    Equal(s.Melee(), Red("7"), "a -3 shows red")
    Equal(Strip(s.Line("melee")), "You have 7 (10 base -3) skill in Daggers.", "the penalty in the line")
    s.game.skills[173].modifier = 0
    s.Refresh()
    Equal(s.Melee(), White("10"), "back to plain white")
end

-- Druids: Feral Combat in a form, for melee only.
do
    local s = Session()
    s.game.class, s.game.classToken = "Druid", "DRUID"
    s.game.equip[MAIN] = 1010
    s.Refresh()
    Equal(s.Melee(), White("17"), "out of form: the weapon (Staves)")
    s.game.form = 1
    s.game.Fire("UPDATE_SHAPESHIFT_FORM")
    Equal(s.Melee(), White("15"), "in a form: Feral Combat, refreshed on the form change")
    Equal(s.Ranged(), White("7"), "the ranged slot ignores forms")
    s.game.skills[3014] = nil
    s.Refresh()
    Equal(s.Melee(), "--", "no Feral line")
    s.game.skills[3014] = { name = "Feral Combat", rank = 15, modifier = 0 }
    s.game.form = SECRET
    s.Refresh()
    Equal(s.Melee(), White("17"), "a secret form counts as no form")
    s.game.class, s.game.classToken, s.game.form = "Warrior", "WARRIOR", 2
    s.Refresh()
    Equal(s.Melee(), White("17"), "a warrior's stance is not a form")
end

-- Secrets are never compared, joined or handed to the game.
do
    local s = Session()
    s.game.skills[173].rank = SECRET
    s.Refresh()
    Equal(s.Melee(), "--", "a secret rank")
    Equal(s.Line("melee"), nil, "no line with a secret rank")
    s.game.skills[173].rank, s.game.skills[173].modifier = 10, SECRET
    s.Refresh()
    Equal(s.Melee(), White("10"), "a secret modifier gives the base")
    s.game.skills[173].modifier, s.game.skills[173].name = 0, SECRET
    s.Refresh()
    Equal(s.Melee(), White("10"), "a secret name keeps the number")
    Equal(s.Line("melee"), nil, "with no line")
    s.game.skills[173].name = "Daggers"
    local real = s.game.skills[173]
    s.game.skills[173] = SECRET
    s.Refresh()
    Equal(s.Melee(), "--", "secret skill info")
    s.game.skills[173] = real
    s.game.equip[MAIN] = SECRET
    s.Refresh()
    Equal(s.Melee(), "--", "a secret item")
    Equal(s.game.secretArgs, 0, "a secret item is never passed to the game")
    s.game.equip[MAIN] = 2092
    s.game.items[2092] = { SECRET, 15 }
    s.Refresh()
    Equal(s.Melee(), "--", "a secret item class")
    s.game.items[2092] = { 2, SECRET }
    s.Refresh()
    Equal(s.Melee(), "--", "a secret subclass")
    s.game.items[2092] = { 2, 15 }
    s.Refresh()
    Equal(s.Melee(), White("10"), "readable again: back to normal")
    Equal(#s.game.errors, 0, "no errors reached the error handler")
end

-- Odd values.
do
    local s = Session()
    s.game.skills[173].name = ""
    s.Refresh()
    Equal(s.Melee(), White("10"), "an empty name gives the number")
    Equal(s.Line("melee"), nil, "with no line")
    s.game.skills[173].name, s.game.skills[173].rank = "Daggers", "10"
    s.Refresh()
    Equal(s.Melee(), "--", "a text rank")
    s.game.skills[173].rank, s.game.skills[173].modifier = 10, "5"
    s.Refresh()
    Equal(s.Melee(), White("10"), "a text modifier counts as none")
    s.game.skills[173] = "Daggers 10"
    s.Refresh()
    Equal(s.Melee(), "--", "info that isn't a table")
end

-- Failing calls.
do
    local s = Session()
    s.game.skillError = true
    s.Refresh()
    Equal(s.Melee(), "--", "the skill lookup erroring: melee")
    Equal(s.Ranged(), "--", "the skill lookup erroring: ranged")
    s.game.skillError, s.game.itemError = nil, true
    s.Refresh()
    Equal(s.Melee(), "--", "the item lookup erroring")
    s.game.equip[MAIN] = nil
    s.Refresh()
    Equal(s.Melee(), White("3"), "an empty hand needs no lookup: Unarmed")
    s.game.itemError, s.game.equip[MAIN] = nil, 2092
    local items = s.env.C_Item
    s.env.C_Item = nil
    s.Refresh()
    Equal(s.Melee(), "--", "no C_Item")
    s.env.GetItemInfoInstant = items.GetItemInfoInstant
    s.Refresh()
    Equal(s.Melee(), White("10"), "the old global works where it's the only one")
    s.env.C_SkillInfo.GetSkillLineInfoByID = nil
    s.Refresh()
    Equal(s.Melee(), "--", "no skill lookup")
    s.env.C_SkillInfo = nil
    s.Refresh()
    Equal(s.Melee(), "--", "no C_SkillInfo")
end
do
    local s = Session({ before = function(_, env) env.GetShapeshiftForm, env.UnitClass = nil, nil end })
    Equal(s.Melee(), White("10"), "no form or class functions: the weapon")
end

-- Wording.
do
    local s = Session()
    s.env.WEAPON_SKILL_RANK_TOOLTIP = nil
    s.Refresh()
    Equal(s.Line("melee"), "Your Daggers skill: 10", "without the game's string")
    s.env.WEAPON_SKILL_RANK_TOOLTIP = "%d %d %d"
    s.Refresh()
    Equal(s.Line("melee"), "Your Daggers skill: 10", "a string that won't format")
    s.env.WEAPON_SKILL_RANK_TOOLTIP = "%2$s: %1$s"
    s.Refresh()
    checks = checks + 1
    assert(type(s.Line("melee")) == "string", "a reordered format string never errors")
end

-- Refreshes.
do
    local s = Session()
    for _, event in ipairs({ "SKILL_LINES_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "UPDATE_SHAPESHIFT_FORM" }) do
        s.game.skills[173].rank = s.game.skills[173].rank + 1
        s.game.Fire(event, event == "PLAYER_EQUIPMENT_CHANGED" and 16 or (event == "UNIT_INVENTORY_CHANGED" and "player" or nil))
        Equal(s.Melee(), White(tostring(s.game.skills[173].rank)), event .. " refreshes at once")
    end
    local before = s.Melee()
    s.game.skills[173].rank = 40
    s.game.Fire("UNIT_INVENTORY_CHANGED", "target")
    Equal(s.Melee(), before, "another unit's inventory doesn't refresh")
    s.env.PaperDollFrame:Hide()
    s.Refresh()
    Equal(s.Melee(), before, "a hidden Character tab isn't refreshed")
    s.env.PaperDollFrame:Show()
    Equal(s.Melee(), White("40"), "shown again, it is fresh")
end
do
    local s = Session({ unknown = { UNIT_ATTACK_SPEED = true, COMBAT_RATING_UPDATE = true } })
    s.game.skills[173].rank = 33
    s.game.Fire("SKILL_LINES_CHANGED")
    Equal(s.Melee(), White("33"), "unknown events are skipped one at a time and the rest still register")
end

-- A client with the old functions.
do
    local s = Session({ old = { 30, 5, 25, -2 } })
    Equal(s.Melee(), Green("35"), "the old melee rating: a green bonus")
    Equal(s.Ranged(), White("23"), "the old ranged rating: a penalty shown white, as it always was")
    Equal(s.game.skillCalls or 0, 0, "no skill lookups")
    local tip = s.Hover("melee")
    Equal(#tip, 1, "the hover is the title only")
    Equal(tip[1], "Melee Attack", "the title")
end

print("Attack rating checks passed: " .. checks .. " assertions.")
