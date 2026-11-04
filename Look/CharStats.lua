-- The character window's 1.x stat boxes (Classic look, "characterSheet"):
-- the five attributes and Armor on the left; Melee Attack, Power, Damage,
-- Ranged Attack, Power and Damage on the right; the five resistances up the
-- model's right edge (Forever only). Hovering a line shows its numbers in
-- EraUI's own small tooltip.
--
-- Melee and Ranged Attack: Forever has no UnitAttackBothHands or
-- UnitRangedAttack, so the rating is the equipped weapon's skill line, read
-- by its ID the way the game's own stat tooltips do. The Skills window's
-- list and selection are never touched.
local _, EraUI = ...
local Look = EraUI.Look
local C = Look.Char

local STRIP = { 0, 0.8984375 }
local UNARMED, FERAL = 162, 3014
-- The game's own weapon subclass to skill line pairs (Camelot's
-- PaperDollFrameStats.lua), by slot.
local MELEE_LINES = { [0] = 44, [1] = 172, [4] = 54, [5] = 160, [6] = 229, [7] = 43, [8] = 55, [10] = 136, [13] = 162,
    [15] = 173 }
local RANGED_LINES = { [2] = 45, [3] = 46, [16] = 176, [18] = 226, [19] = 228 }
-- school, icon rows on the resistance sheet (top to bottom: Arcane, Fire,
-- Nature, Frost, Shadow).
local SCHOOLS = { { 6, 0.2265625, 0.33984375 }, { 2, 0, 0.11328125 }, { 3, 0.11328125, 0.2265625 },
    { 4, 0.33984375, 0.453125 }, { 5, 0.453125, 0.56640625 } }
C.SCHOOLS = SCHOOLS

local rows = {} -- name: EraUI's row { frame, label, value, title, line }
C.statRows = rows

---------------------------------------------------------------------------
-- The boxes
---------------------------------------------------------------------------

-- One box: top cap, a middle of the given height, bottom cap (the cap's
-- place may be given outright).
local function Box(owner, x, y, middle, capAt)
    local top = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
    local mid = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
    local foot = owner:CreateTexture(nil, "BACKGROUND", nil, 1)
    for piece, spec in pairs({ [top] = { 16, 0, 0.125 }, [mid] = { middle, 0.125, 0.1953125 },
        [foot] = { 16, 0.484375, 0.609375 } }) do
        Look.Art(piece, "statBackground")
        piece:SetSize(115, spec[1])
        Look.Crop(piece, STRIP[1], STRIP[2], spec[2], spec[3])
    end
    Look.Pin(top, "TOPLEFT", owner, "TOPLEFT", x, y)
    Look.Pin(mid, "TOPLEFT", top, "BOTTOMLEFT", 0, 0)
    if capAt then Look.Pin(foot, "TOPLEFT", owner, "TOPLEFT", capAt[1], capAt[2])
    else Look.Pin(foot, "TOPLEFT", mid, "BOTTOMLEFT", 0, 0) end
end

local function ShowRowTip(row)
    if not row.title then return end
    local lines = { { row.title, 1, 1, 1 } }
    if row.line then lines[2] = { row.line, C.GOLD[1], C.GOLD[2], C.GOLD[3], 220 } end
    Look.ShowTip(row.frame, "RIGHT", lines)
end

local function Row(owner, name, text, anchor)
    local frame = Look.Build("Frame", owner, nil, { size = { 104, 13 }, mouse = true })
    Look.Pin(frame, "TOPLEFT", anchor[1], anchor[2], anchor[3], anchor[4])
    local row = { frame = frame }
    row.label = Look.OwnLabel(frame, "label", "GameFontNormalSmall")
    Look.Pin(row.label, "LEFT", frame, "LEFT", 0, 0)
    row.label:SetText(text)
    row.value = Look.OwnLabel(frame, "value", "GameFontHighlightSmall")
    row.value:SetJustifyH("RIGHT")
    Look.Pin(row.value, "RIGHT", frame, "RIGHT", 0, 0)
    frame:SetScript("OnEnter", function() ShowRowTip(row) end)
    frame:SetScript("OnLeave", function() Look.HideTip(frame) end)
    rows[name] = row
    return frame
end

local function Resistances(paper)
    local column = Look.Build("Frame", paper, nil, { size = { 32, 160 } })
    Look.Pin(column, "TOPRIGHT", paper, "TOPLEFT", 297, -77)
    C.resistRows = {}
    for i, school in ipairs(SCHOOLS) do
        local row = Look.Build("Frame", column, nil, { size = { 32, 29 }, mouse = true })
        Look.Pin(row, "TOPLEFT", column, "TOPLEFT", 0, -29 * (i - 1))
        local icon = Look.OwnTexture(row, "icon", "BACKGROUND")
        Look.Art(icon, "resistIcons")
        Look.Crop(icon, 0, 1, school[2], school[3])
        Look.Fill(icon, row)
        local number = Look.OwnLabel(row, "number", "GameFontHighlightSmall")
        Look.Pin(number, "BOTTOM", row, "BOTTOM", 0, 3)
        local id = school[1]
        local name = C.Text("DAMAGE_SCHOOL" .. (id + 1), nil) or C.Text("RESISTANCE" .. id .. "_NAME", "Resistance " .. id)
        local words = name .. " " .. C.Text("RESISTANCE", "Resistance")
        row:SetScript("OnEnter", function() Look.ShowTip(row, "RIGHT", { { words, 1, 1, 1 } }) end)
        row:SetScript("OnLeave", function() Look.HideTip(row) end)
        C.resistRows[i] = { frame = row, number = number, school = id }
    end
    C.resistColumn = column
end

function C.MakeStats(paper)
    local box = Look.Build("Frame", paper, nil, { size = { 230, 78 } })
    Look.Pin(box, "TOPLEFT", paper, "TOPLEFT", 67, -291)
    Box(box, 0, 0, 53)
    Box(box, 115, 0, 12, { 115, -28 })
    Box(box, 115, -46, 11)
    local last
    for i = 1, 5 do
        local text = C.Text("SPELL_STAT" .. i .. "_NAME", ({ "Strength", "Agility", "Stamina", "Intellect", "Spirit" })[i])
        last = Row(box, "stat" .. i, text, last and { last, "BOTTOMLEFT", 0, 0 } or { box, "TOPLEFT", 6, -3 })
    end
    Row(box, "armor", C.Text("ARMOR", "Armor"), { last, "BOTTOMLEFT", 0, 0 })
    local attack = C.Text("ATTACK_POWER", "Power")
    local damage = C.Text("DAMAGE", "Damage")
    last = Row(box, "melee", C.Text("MELEE_ATTACK", "Melee Attack"), { box, "TOPLEFT", 122, -2 })
    last = Row(box, "meleePower", attack, { last, "BOTTOMLEFT", 5, 1 })
    last = Row(box, "meleeDamage", damage, { last, "BOTTOMLEFT", 0, 1 })
    last = Row(box, "ranged", C.Text("RANGED_ATTACK", "Ranged Attack"), { last, "BOTTOMLEFT", -5, -6 })
    last = Row(box, "rangedPower", attack, { last, "BOTTOMLEFT", 5, 1 })
    Row(box, "rangedDamage", damage, { last, "BOTTOMLEFT", 0, 1 })
    C.statBox = box
    Resistances(paper)
end

-- The 1.x boxes shown or hidden (the stat panes take their place).
function C.SetClassicStatsShown(on)
    Look.Shown(C.statBox, on)
end

function C.ShowResistances(on)
    Look.Shown(C.resistColumn, on and C.OnForever())
end

---------------------------------------------------------------------------
-- The weapon skill rating (Forever)
---------------------------------------------------------------------------

local function DruidInForm()
    if type(UnitClass) ~= "function" or type(GetShapeshiftForm) ~= "function" then return false end
    local _, token = UnitClass("player")
    if Look.Secret(token) or token ~= "DRUID" then return false end
    local fine, form = pcall(GetShapeshiftForm)
    form = fine and Look.Number(form)
    return form ~= nil and form ~= false and form ~= 0
end

local function RangedSlotID()
    local slot = CharacterRangedSlot
    local id = slot and Look.Number(slot:GetID())
    return id or INVSLOT_RANGED or 18
end

-- The item's class and subclass, or nil when they can't be read.
local function ItemKind(itemID)
    local lookup = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if type(lookup) ~= "function" then return nil end
    local fine, _, _, _, _, _, class, subclass = pcall(lookup, itemID)
    if not fine then return nil end
    class = Look.Number(class)
    if not class then return nil end
    return class, subclass
end

-- The skill line for the weapon the player fights with, or nil.
local function SkillLine(ranged)
    if not ranged and DruidInForm() then return FERAL end
    local itemID = GetInventoryItemID("player", ranged and RangedSlotID() or (INVSLOT_MAINHAND or 16))
    if Look.Secret(itemID) then return nil end
    if itemID == nil then return (not ranged) and UNARMED or nil end
    local class, subclass = ItemKind(itemID)
    if not class then return nil end
    if class ~= 2 then return (not ranged) and UNARMED or nil end
    subclass = Look.Number(subclass)
    if not subclass then return nil end
    return (ranged and RANGED_LINES or MELEE_LINES)[subclass]
end

local function Wording(amount, name)
    local pattern = WEAPON_SKILL_RANK_TOOLTIP
    if type(pattern) == "string" then
        local fine, text = pcall(string.format, pattern, amount, name)
        if fine and type(text) == "string" then return text end
    end
    return "Your " .. name .. " skill: " .. amount
end

-- The rating's value and tooltip line, or nil (shown as "--").
function C.WeaponRating(ranged)
    local id = SkillLine(ranged)
    local lookup = C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID
    if not id or type(lookup) ~= "function" then return nil end
    local fine, info = pcall(lookup, id)
    if not fine or Look.Secret(info) or type(info) ~= "table" then return nil end
    local rank = Look.Number(info.rank)
    if not rank then return nil end
    local modifier = Look.Number(info.modifier) or 0
    local value, detail = C.Bonus(rank, modifier > 0 and modifier or 0, modifier < 0 and modifier or 0)
    local name, line = info.name, nil
    if type(name) == "string" and not Look.Secret(name) and name ~= "" then
        line = Wording(detail or C.Whole(rank), name)
    end
    return value, line
end

---------------------------------------------------------------------------
-- The numbers
---------------------------------------------------------------------------

local function Put(name, value, title, line)
    local row = rows[name]
    row.value:SetText(value)
    row.title, row.line = title, line
end

local function Numbers(fn, ...)
    if type(fn) ~= "function" then return end
    local fine, a, b, c, d, e = pcall(fn, ...)
    if fine then return a, b, c, d, e end
end

local function Span(low, high)
    low, high = Look.Number(low) or 0, Look.Number(high) or 0
    return math.max(1, math.floor(low)) .. " - " .. math.max(1, math.ceil(high))
end

-- An attack row on a client with the old functions: base and modifier,
-- the modifier as the bonus (a negative one stays white, as it always was).
local function OldAttack(fn)
    local base, modifier = Numbers(fn, "player")
    local value = C.Bonus(base, modifier, 0)
    return value
end

local function Attack(name, ranged, old)
    local title = ranged and C.Text("RANGED_ATTACK", "Ranged Attack") or C.Text("MELEE_ATTACK", "Melee Attack")
    if type(old) == "function" then
        Put(name, OldAttack(old), title, nil)
        return
    end
    local value, line = C.WeaponRating(ranged)
    Put(name, value or "--", title, line)
end

local function Attributes()
    for i = 1, 5 do
        local _, effective, bonus, penalty = Numbers(UnitStat, "player", i)
        effective, bonus, penalty = Look.Number(effective) or 0, Look.Number(bonus) or 0, Look.Number(penalty) or 0
        local value, detail = C.Bonus(effective - bonus - penalty, bonus, penalty)
        local text = rows["stat" .. i].label:GetText() or ""
        Put("stat" .. i, value, text .. " " .. C.Whole(effective), detail)
    end
    local _, effective, _, bonus, penalty = Numbers(UnitArmor, "player")
    effective, bonus, penalty = Look.Number(effective) or 0, Look.Number(bonus) or 0, Look.Number(penalty) or 0
    local value, detail = C.Bonus(effective - bonus - penalty, bonus, penalty)
    Put("armor", value, C.Text("ARMOR", "Armor") .. " " .. C.Whole(effective), detail)
end

local function RangedHeld()
    local slot = CharacterRangedSlot
    if not slot or not slot:IsShown() then return false end
    local itemID = GetInventoryItemID("player", RangedSlotID())
    return Look.Secret(itemID) or itemID ~= nil
end

local function Melee()
    Attack("melee", false, UnitAttackBothHands)
    local value, detail = C.Bonus(Numbers(UnitAttackPower, "player"))
    Put("meleePower", value, C.Text("MELEE_ATTACK_POWER", "Attack Power"), detail)
    Put("meleeDamage", Span(Numbers(UnitDamage, "player")), C.Text("DAMAGE", "Damage"), nil)
end

local function Ranged()
    local rangedTitle = C.Text("RANGED_ATTACK", "Ranged Attack")
    local powerTitle, damageTitle = C.Text("RANGED_ATTACK_POWER", "Ranged Attack Power"), C.Text("DAMAGE", "Damage")
    if not RangedHeld() then
        Put("ranged", "--", rangedTitle, nil)
        Put("rangedPower", "--", powerTitle, nil)
        Put("rangedDamage", "--", damageTitle, nil)
        return
    end
    Attack("ranged", true, UnitRangedAttack)
    local value, detail = C.Bonus(Numbers(UnitRangedAttackPower, "player"))
    Put("rangedPower", value, powerTitle, detail)
    local _, low, high = Numbers(UnitRangedDamage, "player")
    Put("rangedDamage", (Look.Number(high) or 0) > 0 and Span(low, high) or "--", damageTitle, nil)
end

local function ResistanceNumbers()
    for _, row in ipairs(C.resistRows or {}) do
        local shown = "0"
        if type(UnitResistance) == "function" then
            local _, amount = Numbers(UnitResistance, "player", row.school)
            shown = C.Whole(Look.Number(amount) or 0)
        end
        row.number:SetText(shown)
    end
end

-- Every number in the boxes, while the window is on, built and its
-- Character tab shows. The stat panes go first; with the game keeping the
-- stats hidden, the boxes keep their old numbers.
function C.RefreshStats()
    if not (C.active and C.built) or not PaperDollFrame or not PaperDollFrame:IsShown() then return end
    if C.UpdateStatPanes then Look.Try(C.UpdateStatPanes) end
    local _, first = Numbers(UnitStat, "player", 1)
    if Look.Secret(first) then return end
    Look.Try(Attributes)
    Look.Try(Melee)
    Look.Try(Ranged)
    Look.Try(ResistanceNumbers)
end

---------------------------------------------------------------------------
-- The events that change a number
---------------------------------------------------------------------------

local EVENTS = Look.Words([[UNIT_STATS UNIT_ATTACK_POWER UNIT_RANGED_ATTACK_POWER UNIT_DAMAGE UNIT_ATTACK_SPEED
    UNIT_RESISTANCES UNIT_INVENTORY_CHANGED PLAYER_EQUIPMENT_CHANGED UNIT_LEVEL COMBAT_RATING_UPDATE UNIT_AURA
    SKILL_LINES_CHANGED UPDATE_SHAPESHIFT_FORM]])

local function OnStatEvent(_, event, unit)
    if event == "UNIT_LEVEL" then C.WriteLevel() end
    local forPlayer = unit == nil or (not Look.Secret(unit) and unit == "player")
    if forPlayer or event == "PLAYER_EQUIPMENT_CHANGED" then C.RefreshStats() end
end

-- Each event on its own: a client without one still gets the rest.
function C.ListenForStats()
    if C.statListener then return end
    local listener = Look.Build("Frame", nil, nil, { size = { 1, 1 } })
    for _, event in ipairs(EVENTS) do Look.Listen(listener, event) end
    listener:SetScript("OnEvent", OnStatEvent)
    C.statListener = listener
end
