-- Classic character window: Melee Attack and Ranged Attack from the Skills
-- list (Classic/CharacterSheet.lua, the real file).
-- Forever 1.60.1 (70170) has no UnitAttackBothHands or UnitRangedAttack. The
-- rating is then the equipped weapon's skill line, read by ID with
-- C_SkillInfo.GetSkillLineInfoByID: main hand for melee (Unarmed when empty or
-- not a weapon, Feral Combat for a druid in a form), the ranged slot for
-- ranged (Bows, Guns, Crossbows, Thrown, Wands). Base plus modifier, green up
-- and red down. A client with the old functions keeps the old output.
-- Run: fengari Tools/TestAttackRating.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local SECRET = setmetatable({}, {
    __tostring = function() error("secret turned to text") end,
    __concat = function() error("secret joined to text") end,
    __eq = function() error("secret compared") end,
    __lt = function() error("secret compared") end, __le = function() error("secret compared") end,
    __sub = function() error("secret used in arithmetic") end, __add = function() error("secret used in arithmetic") end,
    __index = function() error("secret indexed") end,
})

local GREEN, RED, WHITE = "|cff20ff20", "|cffff2020", "|cffffffff"
local function White(n) return WHITE .. n .. "|r" end
local function Green(n) return GREEN .. n .. "|r" end
local function Red(n) return RED .. n .. "|r" end

-- A permissive widget: the methods below keep state; any other method whose
-- name starts with one of these verbs is a recorded no-op.
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Lock", "Unlock", "Add",
    "Clear", "Raise", "Lower", "Update" }
local function IsMethodName(key)
    if type(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local Methods = {}
local function Widget(props)
    local w = props or {}
    if w.shown == nil then w.shown = true end
    w.scripts = w.scripts or {}
    return setmetatable(w, { __index = function(_, key)
        local method = Methods[key]
        if method then return method end
        if IsMethodName(key) then return function() end end
    end })
end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:SetShown(on) self.shown = on and true or false end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown end
function Methods:GetWidth() return self.width or 0 end
function Methods:GetFrameLevel() return 1 end
function Methods:GetID() return self.id or 0 end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:HookScript(name, fn) self.scripts[name] = fn end
function Methods:SetText(text) self.text = text end
function Methods:GetText() return self.text end
function Methods:CreateTexture() return Widget() end
function Methods:CreateFontString() return Widget() end

-- Skill lines on a level 2 rogue (rank, max, modifier) and the rest of the
-- weapon skills. Every rank is different, so a number names its skill.
local SKILLS = {
    [173] = { name = "Daggers", rank = 10, maxRank = 10 },
    [176] = { name = "Thrown", rank = 7, maxRank = 10 },
    [43] = { name = "Swords", rank = 9, maxRank = 10 },
    [55] = { name = "Two-Handed Swords", rank = 4, maxRank = 10 },
    [162] = { name = "Unarmed", rank = 3, maxRank = 10 },
    [45] = { name = "Bows", rank = 6, maxRank = 10 },
    [46] = { name = "Guns", rank = 5, maxRank = 10 },
    [226] = { name = "Crossbows", rank = 8, maxRank = 10 },
    [228] = { name = "Wands", rank = 2, maxRank = 10 },
    [229] = { name = "Polearms", rank = 11, maxRank = 15 },
    [44] = { name = "Axes", rank = 12, maxRank = 15 },
    [172] = { name = "Two-Handed Axes", rank = 13, maxRank = 15 },
    [54] = { name = "Maces", rank = 14, maxRank = 15 },
    [160] = { name = "Two-Handed Maces", rank = 16, maxRank = 20 },
    [136] = { name = "Staves", rank = 17, maxRank = 20 },
    [3014] = { name = "Feral Combat", rank = 15, maxRank = 15 },
}
-- Items: id = { classID, subclassID } (Enum.ItemClass.Weapon is 2).
local ITEMS = {
    [2092] = { 2, 15 },   -- Worn Dagger
    [25861] = { 2, 16 },  -- Crude Throwing Axe (Thrown)
    [1] = { 2, 7 },       -- a one-handed sword
    [2] = { 2, 8 },       -- a two-handed sword
    [3] = { 2, 13 },      -- a fist weapon
    [4] = { 2, 2 },       -- a bow
    [5] = { 2, 3 },       -- a gun
    [6] = { 2, 18 },      -- a crossbow
    [7] = { 2, 19 },      -- a wand
    [8] = { 4, 0 },       -- armour (a non-weapon)
    [9] = { 2, 20 },      -- a fishing pole (no weapon skill)
    [10] = { 2, 6 },      -- a polearm
    [11] = { 4, 7 },      -- an idol-like non-weapon in the ranged slot
}
local MAIN, RANGED = 16, 18

local function Session(opts)
    opts = opts or {}
    local s = { frames = {}, equip = { [MAIN] = 2092, [RANGED] = 25861 }, skills = {}, items = {},
        skillCalls = 0, itemCalls = 0, uiCalls = 0, form = 0, class = "ROGUE", registered = {} }
    for id, info in pairs(SKILLS) do
        local copy = {}
        for k, v in pairs(info) do copy[k] = v end
        copy.skillID, copy.modifier, copy.isHeader, copy.isCollapsed = id, 0, false, false
        s.skills[id] = copy
    end
    for id, pair in pairs(ITEMS) do s.items[id] = pair end
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.unpack = table.unpack
    s.env = env
    local unknown = opts.unknownEvents or {}
    env.CreateFrame = function(_, name, parent)
        local f = Widget({ parent = parent, events = {} })
        function f:RegisterEvent(event)
            if unknown[event] then error("unknown event " .. event) end
            self.events[event] = true
            s.registered[event] = true
        end
        s.frames[#s.frames + 1] = f
        if name then env[name] = f end
        return f
    end
    env.issecretvalue = function(value) return rawequal(value, SECRET) end
    env.StaticPopupDialogs = {}
    env.MELEE_ATTACK, env.RANGED_ATTACK = "Melee Attack", "Ranged Attack"
    env.WEAPON_SKILL_RANK_TOOLTIP = "You have %s skill in %s."
    env.INVSLOT_MAINHAND, env.INVSLOT_RANGED = MAIN, RANGED
    env.CharacterFrame = Widget({ width = 384 })
    env.PaperDollFrame = Widget()
    env.CharacterRangedSlot = Widget({ id = RANGED })
    env.UnitLevel = function() return 2 end
    env.UnitRace = function() return "Human" end
    env.UnitClass = function() return "Rogue", s.class end
    env.UnitStat = function() return 20, 20, 0, 0 end
    env.UnitArmor = function() return 50, 50, 50, 0, 0 end
    env.UnitAttackPower = function() return 40, 0, 0 end
    env.UnitRangedAttackPower = function() return 30, 0, 0 end
    env.UnitDamage = function() return 3, 6 end
    env.UnitRangedDamage = function() return 2, 4, 8 end
    env.UnitResistance = function() return 0, 0 end
    env.GetShapeshiftForm = function() return s.form end
    env.GetInventoryItemID = function(unit, slot)
        Equal(unit, "player", "items are the player's")
        return s.equip[slot]
    end
    s.secretArgs = 0
    env.C_Item = { GetItemInfoInstant = function(itemID)
        s.itemCalls = s.itemCalls + 1
        -- An addon passing a secret in is refused by the game.
        if rawequal(itemID, SECRET) then
            s.secretArgs = s.secretArgs + 1
            error("secret argument")
        end
        if s.itemError then error("item lookup failed") end
        local pair = s.items[itemID]
        if not pair then return end
        return itemID, "Weapon", "Sub", "INVTYPE_WEAPON", 135641, pair[1], pair[2]
    end }
    local function Touch() s.uiCalls = s.uiCalls + 1 end
    env.C_SkillInfo = {
        GetSkillLineInfoByID = function(id)
            s.skillCalls = s.skillCalls + 1
            if s.skillError then error("skill lookup failed") end
            return s.skills[id]
        end,
        -- The index list (headers can be collapsed) and the window's state:
        -- the rating never needs them.
        GetNumSkillLines = function() Touch() return 0 end,
        GetSkillLineInfo = function() Touch() end,
        ExpandSkillHeader = Touch, CollapseSkillHeader = Touch, SetSelectedSkill = Touch, GetSelectedSkill = function() Touch() return 0 end,
    }
    if opts.old then
        env.UnitAttackBothHands = function() return opts.old[1], opts.old[2], 0, 0 end
        env.UnitRangedAttack = function() return opts.old[3], opts.old[4] end
    end
    s.tooltip = { lines = {} }
    function s.tooltip:SetOwner() self.lines = {} end
    function s.tooltip:SetText(text) self.lines[#self.lines + 1] = text end
    function s.tooltip:AddLine(text) self.lines[#self.lines + 1] = text end
    function s.tooltip:Show() end
    function s.tooltip:Hide() end
    env.GameTooltip = s.tooltip

    local ns = { db = {}, modules = {} }
    function ns.RegisterModule(key, module) ns.modules[key] = module end
    function ns.SafeCall(fn, ...) return fn(...) end
    function ns.SetTex() end
    function ns.TexPath(key) return key end
    function ns.Fade() end
    function ns.OnForever() return true end
    function ns.HookMethod() end
    function ns.HookGlobal() end
    function ns.SetCVar() end
    function ns.MissingPiece(name) error("missing " .. name) end
    s.ns = ns
    if opts.before then opts.before(s, env) end
    assert(loadfile("Classic/CharacterSheet.lua", "t", env))("EraUI", { Classic = ns })
    ns.modules.characterSheet.apply()
    local function Row(label)
        for _, f in ipairs(s.frames) do
            if f.label and f.label.text == label then return f end
        end
        error("no row " .. label)
    end
    s.melee, s.ranged = Row("Melee Attack"), Row("Ranged Attack")
    function s.Fire(event, ...)
        for _, f in ipairs(s.frames) do
            local handler = f.scripts.OnEvent
            if f.events[event] and handler then handler(f, event, ...) end
        end
    end
    function s.Refresh() s.Fire("UNIT_INVENTORY_CHANGED", "player") end
    function s.Melee() return s.melee.value.text end
    function s.Ranged() return s.ranged.value.text end
    function s.Hover(row)
        row.scripts.OnEnter(row)
        return s.tooltip.lines
    end
    return s
end

---------------------------------------------------------------------------
-- The level 2 rogue: a dagger and throwing knives, as the Skills tab shows.
---------------------------------------------------------------------------
do
    local s = Session()
    Equal(s.Melee(), White(10), "dagger: the Daggers skill")
    Equal(s.Ranged(), White(7), "thrown: the Thrown skill")
    Equal(s.melee.tip2, "You have 10 skill in Daggers.", "melee hover names the skill")
    Equal(s.ranged.tip2, "You have 7 skill in Thrown.", "ranged hover names the skill")
    local lines = s.Hover(s.melee)
    Equal(lines[1], "Melee Attack", "hover title")
    Equal(lines[2], "You have 10 skill in Daggers.", "hover line")
    lines = s.Hover(s.ranged)
    Equal(lines[1], "Ranged Attack", "ranged hover title")
    Equal(lines[2], "You have 7 skill in Thrown.", "ranged hover line")
    Equal(s.uiCalls, 0, "the Skills window's list and selection are never touched")
end

---------------------------------------------------------------------------
-- Each weapon type to its skill.
---------------------------------------------------------------------------
do
    local s = Session()
    local melee = {
        { 1, 9, "Swords" }, { 2, 4, "Two-Handed Swords" }, { 3, 3, "Unarmed" }, { 10, 11, "Polearms" },
        { nil, 3, "Unarmed" }, { 8, 3, "Unarmed" }, { 2092, 10, "Daggers" },
    }
    for _, case in ipairs(melee) do
        s.equip[MAIN] = case[1]
        s.Refresh()
        local what = case[3] .. " (item " .. tostring(case[1]) .. ")"
        Equal(s.Melee(), White(case[2]), "melee " .. what)
        Equal(s.melee.tip2, "You have " .. case[2] .. " skill in " .. case[3] .. ".", "melee hover " .. what)
    end
    local ranged = { { 4, 6, "Bows" }, { 5, 5, "Guns" }, { 6, 8, "Crossbows" }, { 7, 2, "Wands" }, { 25861, 7, "Thrown" } }
    for _, case in ipairs(ranged) do
        s.equip[RANGED] = case[1]
        s.Refresh()
        Equal(s.Ranged(), White(case[2]), "ranged " .. case[3])
        Equal(s.ranged.tip2, "You have " .. case[2] .. " skill in " .. case[3] .. ".", "ranged hover " .. case[3])
    end
    Equal(s.uiCalls, 0, "no list or selection calls for any weapon")
end

---------------------------------------------------------------------------
-- Every weapon subclass (Enum.ItemWeaponSubclass 0 to 20, 70170 docs) in both
-- slots, against a copy of Blizzard's own WEAPON_SUBCLASS_TO_SKILL_ID
-- (Camelot PaperDollFrameStats.lua, 70170). Melee takes its 10 melee pairs and
-- ranged its 5 ranged ones. Anything else (Warglaive, Bearclaw, Catclaw,
-- Generic, Obsolete3, Fishingpole, or the other slot's types) is "--" with no
-- hover line.
---------------------------------------------------------------------------
do
    local BLIZZARD = {
        [7] = 43, [0] = 44, [2] = 45, [3] = 46, [4] = 54, [8] = 55, [10] = 136, [5] = 160,
        [1] = 172, [15] = 173, [16] = 176, [18] = 226, [19] = 228, [6] = 229, [13] = 162,
    }
    local RANGED_TYPES = { [2] = true, [3] = true, [16] = true, [18] = true, [19] = true }
    local s = Session()
    for sub = 0, 20 do s.items[100 + sub] = { 2, sub } end
    local mapped = { melee = 0, ranged = 0 }
    for _, slot in ipairs({ { MAIN, "melee", false }, { RANGED, "ranged", true } }) do
        for sub = 0, 20 do
            s.equip[slot[1]] = 100 + sub
            s.Refresh()
            local skill = BLIZZARD[sub]
            if (RANGED_TYPES[sub] or false) ~= slot[3] then skill = nil end
            local row, what = s[slot[2]], slot[2] .. " subclass " .. sub
            if skill then
                mapped[slot[2]] = mapped[slot[2]] + 1
                local info = SKILLS[skill]
                Equal(row.value.text, White(info.rank), what .. " (" .. info.name .. ")")
                Equal(row.tip2, "You have " .. info.rank .. " skill in " .. info.name .. ".", what .. " hover")
            else
                Equal(row.value.text, "--", what .. " has no skill in this slot")
                Equal(row.tip2, nil, what .. " has no hover line")
            end
        end
        s.equip[MAIN], s.equip[RANGED] = 2092, 25861
    end
    Equal(mapped.melee, 10, "ten melee weapon types")
    Equal(mapped.ranged, 5, "five ranged weapon types")
    Equal(s.uiCalls, 0, "no list or selection calls for any subclass")
end

---------------------------------------------------------------------------
-- Nothing to read: "--".
---------------------------------------------------------------------------
do
    local s = Session()
    -- Straight from the throwing knives, so a stale Thrown line would show.
    s.equip[RANGED] = 11
    s.Refresh()
    Equal(s.Ranged(), "--", "a non-weapon in the ranged slot")
    Equal(s.ranged.tip2, nil, "and the Thrown hover line is gone")
    s.equip[RANGED] = 25861
    s.Refresh()
    Equal(s.ranged.tip2, "You have 7 skill in Thrown.", "throwing knives back")
    s.equip[RANGED] = nil
    s.Refresh()
    Equal(s.Ranged(), "--", "no ranged weapon")
    Equal(s.ranged.tip2, nil, "no ranged hover line")
    Equal(s.Melee(), White(10), "melee still reads")
    s.equip[RANGED] = 2092
    s.Refresh()
    Equal(s.Ranged(), "--", "a melee weapon in the ranged slot is not a ranged skill")
    s.equip[RANGED] = 25861
    s.equip[MAIN] = 4
    s.Refresh()
    Equal(s.Melee(), "--", "a bow in the main hand is not a melee skill")
    s.equip[MAIN] = 9
    s.Refresh()
    Equal(s.Melee(), "--", "a fishing pole has no weapon skill")
    Equal(s.melee.tip2, nil, "and no hover line")
    s.equip[MAIN] = 999
    s.Refresh()
    Equal(s.Melee(), "--", "an item the game can't describe is not Unarmed")
    s.equip[MAIN] = 2092
    s.skills[173] = nil
    s.Refresh()
    Equal(s.Melee(), "--", "a skill line the player doesn't have")
    Equal(s.Ranged(), White(7), "ranged unaffected")
end

---------------------------------------------------------------------------
-- Gear and buffs that change the skill: green up, red down.
---------------------------------------------------------------------------
do
    local s = Session()
    s.skills[173].modifier = 5
    s.Refresh()
    Equal(s.Melee(), Green(15), "a bonus shows the total in green")
    Equal(s.melee.tip2, "You have 15 (10 base " .. GREEN .. "+5|r) skill in Daggers.", "hover shows base and bonus")
    s.skills[173].modifier = -3
    s.Refresh()
    Equal(s.Melee(), Red(7), "a penalty shows the total in red")
    Equal(s.melee.tip2, "You have 7 (10 base " .. RED .. "-3|r) skill in Daggers.", "hover shows base and penalty")
    s.skills[176].modifier = 2
    s.Refresh()
    Equal(s.Ranged(), Green(9), "ranged bonus in green")
    s.skills[173].modifier = 0
    s.Refresh()
    Equal(s.Melee(), White(10), "back to plain white")
end

---------------------------------------------------------------------------
-- Druid forms use Feral Combat (as the game's own tooltip); others don't.
---------------------------------------------------------------------------
do
    local s = Session()
    s.class = "DRUID"
    s.equip[MAIN] = 10
    s.Refresh()
    Equal(s.Melee(), White(11), "druid out of form: the weapon")
    s.form = 1
    s.Fire("UPDATE_SHAPESHIFT_FORM")
    Equal(s.Melee(), White(15), "druid in a form: Feral Combat, refreshed on the form change")
    Equal(s.melee.tip2, "You have 15 skill in Feral Combat.", "form hover")
    Equal(s.Ranged(), White(7), "the ranged slot ignores the form")
    s.skills[3014] = nil
    s.Refresh()
    Equal(s.Melee(), "--", "no Feral Combat line: nothing to read")
    s.form = SECRET
    s.Refresh()
    Equal(s.Melee(), White(11), "a secret form counts as no form")
    s.class = "WARRIOR"
    s.form = 1
    s.Refresh()
    Equal(s.Melee(), White(11), "a warrior's stance is not a feral form")
end

---------------------------------------------------------------------------
-- Secret values: shown as "--" or left out, never an error.
---------------------------------------------------------------------------
do
    local s = Session()
    s.skills[173].rank = SECRET
    s.Refresh()
    Equal(s.Melee(), "--", "secret rank")
    Equal(s.melee.tip2, nil, "secret rank: no hover line")
    s.skills[173].rank = 10
    s.skills[173].modifier = SECRET
    s.Refresh()
    Equal(s.Melee(), White(10), "secret modifier: the base")
    Equal(s.melee.tip2, "You have 10 skill in Daggers.", "secret modifier: base in the hover")
    s.skills[173].modifier = 0
    s.skills[173].name = SECRET
    s.Refresh()
    Equal(s.Melee(), White(10), "secret name: the number still shows")
    Equal(s.melee.tip2, nil, "secret name: no hover line")
    s.skills[173].name = "Daggers"
    s.skills[173] = SECRET
    s.Refresh()
    Equal(s.Melee(), "--", "secret skill info")
    s.skills[173] = { skillID = 173, name = "Daggers", rank = 10, maxRank = 10, modifier = 0 }
    s.equip[MAIN] = SECRET
    s.Refresh()
    Equal(s.Melee(), "--", "secret item")
    Equal(s.secretArgs, 0, "a secret item is never handed to the game")
    s.equip[MAIN] = 2092
    s.items[2092] = { SECRET, 15 }
    s.Refresh()
    Equal(s.Melee(), "--", "secret item class")
    s.items[2092] = { 2, SECRET }
    s.Refresh()
    Equal(s.Melee(), "--", "secret item subclass")
    s.items[2092] = { 2, 15 }
    s.Refresh()
    Equal(s.Melee(), White(10), "readable again")
end
do
    -- Readable but odd values from the skill lookup.
    local s = Session()
    s.skills[173].name = ""
    s.Refresh()
    Equal(s.Melee(), White(10), "empty name: the number still shows")
    Equal(s.melee.tip2, nil, "empty name: no hover line")
    s.skills[173].name = "Daggers"
    s.skills[173].rank = "10"
    s.Refresh()
    Equal(s.Melee(), "--", "a rank that isn't a number")
    s.skills[173].rank = 10
    s.skills[173].modifier = "5"
    s.Refresh()
    Equal(s.Melee(), White(10), "a modifier that isn't a number counts as none")
    s.skills[173] = 10
    s.Refresh()
    Equal(s.Melee(), "--", "skill info that isn't a table")
    Equal(s.Ranged(), White(7), "ranged unaffected")
end

---------------------------------------------------------------------------
-- Missing or failing game functions: "--" (Unarmed needs no item lookup).
---------------------------------------------------------------------------
do
    local s = Session()
    s.skillError = true
    s.Refresh()
    Equal(s.Melee(), "--", "skill lookup erroring")
    Equal(s.Ranged(), "--", "ranged with the skill lookup erroring")
    s.skillError = false
    s.itemError = true
    s.Refresh()
    Equal(s.Melee(), "--", "item lookup erroring")
    s.equip[MAIN] = nil
    s.Refresh()
    Equal(s.Melee(), White(3), "empty hand needs no item lookup")
    s.itemError = false
    s.env.C_Item = nil
    s.equip[MAIN] = 2092
    s.Refresh()
    Equal(s.Melee(), "--", "no item lookup at all")
    s.env.GetItemInfoInstant = function(itemID)
        local pair = s.items[itemID]
        return itemID, "Weapon", "Sub", "INVTYPE_WEAPON", 1, pair[1], pair[2]
    end
    s.Refresh()
    Equal(s.Melee(), White(10), "the old item lookup where a client has only that")
    s.env.C_SkillInfo.GetSkillLineInfoByID = nil
    s.Refresh()
    Equal(s.Melee(), "--", "no skill lookup")
    Equal(s.melee.tip2, nil, "no skill lookup: no hover line")
    s.env.C_SkillInfo = nil
    s.Refresh()
    Equal(s.Melee(), "--", "no C_SkillInfo")
    Equal(s.Ranged(), "--", "ranged without C_SkillInfo")
end
do
    local s = Session({ before = function(_, env) env.GetShapeshiftForm = nil; env.UnitClass = nil end })
    Equal(s.Melee(), White(10), "no form or class functions: the weapon")
end

---------------------------------------------------------------------------
-- Hover wording: the game's own string, else EraUI's.
---------------------------------------------------------------------------
do
    local s = Session()
    s.env.WEAPON_SKILL_RANK_TOOLTIP = nil
    s.Refresh()
    Equal(s.melee.tip2, "Your Daggers skill: 10", "own wording without the game's string")
    s.env.WEAPON_SKILL_RANK_TOOLTIP = "%d skill %d"
    s.Refresh()
    Equal(s.melee.tip2, "Your Daggers skill: 10", "own wording when the game's string won't format")
    s.env.WEAPON_SKILL_RANK_TOOLTIP = "%2$s %1$s"
    s.Refresh()
    Equal(type(s.melee.tip2), "string", "a reordered string never errors")
end

---------------------------------------------------------------------------
-- Refreshes: skills, gear (by either event) and forms.
---------------------------------------------------------------------------
do
    local s = Session()
    Equal(s.registered.SKILL_LINES_CHANGED, true, "skill changes registered")
    Equal(s.registered.PLAYER_EQUIPMENT_CHANGED, true, "gear changes registered")
    Equal(s.registered.UNIT_INVENTORY_CHANGED, true, "inventory changes registered")
    Equal(s.registered.UPDATE_SHAPESHIFT_FORM, true, "form changes registered")
    s.skills[173].rank = 11
    s.Fire("SKILL_LINES_CHANGED")
    Equal(s.Melee(), White(11), "a skill-up shows at once")
    s.equip[MAIN] = 1
    s.Fire("PLAYER_EQUIPMENT_CHANGED", MAIN, true)
    Equal(s.Melee(), White(9), "a weapon swap shows at once (slot payload)")
    s.equip[RANGED] = 4
    s.Fire("UNIT_INVENTORY_CHANGED", "player")
    Equal(s.Ranged(), White(6), "a ranged swap shows at once")
    s.equip[MAIN] = 2092
    s.Fire("UNIT_INVENTORY_CHANGED", "target")
    Equal(s.Melee(), White(9), "another unit's inventory doesn't refresh")
    s.env.PaperDollFrame.shown = false
    s.Fire("SKILL_LINES_CHANGED")
    Equal(s.Melee(), White(9), "a hidden sheet isn't refreshed")
    s.env.PaperDollFrame.shown = true
    s.Fire("SKILL_LINES_CHANGED")
    Equal(s.Melee(), White(11), "shown again: fresh")
end
do
    -- A game without some of the events: registered one at a time in pcall.
    local s = Session({ unknownEvents = { SKILL_LINES_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true } })
    Equal(s.registered.SKILL_LINES_CHANGED, nil, "unknown event skipped")
    Equal(s.registered.UNIT_AURA, true, "the rest still registered")
    Equal(s.Melee(), White(10), "and the sheet still reads")
end

---------------------------------------------------------------------------
-- A client with the old functions: same output as before, no skill lookup.
---------------------------------------------------------------------------
do
    local s = Session({ old = { 30, 5, 20, 0 } })
    Equal(s.Melee(), Green(35), "old melee with a bonus, as before")
    Equal(s.Ranged(), White(20), "old ranged, as before")
    Equal(s.melee.tip2, nil, "old melee hover unchanged")
    Equal(s.ranged.tip2, nil, "old ranged hover unchanged")
    Equal(s.skillCalls, 0, "no skill lookup with the old functions")
    Equal(s.itemCalls, 0, "no item lookup with the old functions")
    local lines = s.Hover(s.melee)
    Equal(#lines, 1, "old hover is the title only")
    s.equip[RANGED] = nil
    s.Refresh()
    Equal(s.Ranged(), "--", "old client without a ranged weapon")
end
do
    -- The old code's own colouring of a penalty (white) is kept as it was.
    local s = Session({ old = { 30, -3, 20, -2 } })
    Equal(s.Melee(), White(27), "old melee penalty, as before")
    Equal(s.Ranged(), "|cffffffff18|r", "old ranged penalty, as before")
end

print("Attack rating checks passed: " .. checks .. " assertions.")
