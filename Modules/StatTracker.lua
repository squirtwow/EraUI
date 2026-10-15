local _, EraUI = ...

-- Stat Tracker (/era > Character & Spells): a small panel of
-- the stats you tick, updating as buffs, gear, levels and repairs change
-- them. It sits on its own, over the game's usual windows (HIGH, under /era
-- and pop-ups): first at the right of the screen a little above the middle,
-- clear of the side action bars, the minimap and the chat (One line: at the
-- top centre, clear of /era); drag it anywhere: it stays on screen and keeps
-- its place. List puts one stat on each line
-- under an optional "Stats" title; One line puts them side by side, wrapping
-- to a second line on a narrow screen, or, with Stats per Line, into neat
-- rows of that many under each other. Panel Size scales either from 50% to
-- 150%. It shows always, only in a fight or only out of one, and always
-- while /era is open (where it is, never moved or raised for it). A stat
-- that goes up turns green with how much it went up, for five seconds. The
-- stat names match the look (gold, or grey in Dark Mode) or take gold, your
-- class colour, white or a colour of your own.
--
-- The numbers come from the game's own stat functions, the ones Forever's
-- character window uses (Gethe forever branch, Camelot PaperDollFrame.lua
-- and PaperDollFrameStats.lua), each through pcall: UnitStat, UnitAttackPower
-- and UnitRangedAttackPower, GetCritChance and GetRangedCritChance,
-- GetSpellCritChance, the hit modifiers with GetCombatRatingBonus,
-- GetSpellBonusDamage, UnitArmor, GetDodgeChance, GetParryChance,
-- GetBlockChance, GetUnitSpeed (with IsSwimming) and
-- GetInventoryItemDurability. Forever can
-- make them secret (UnitStat and its kin are SecretWhenUnitStatsRestricted):
-- a secret is never compared or added up, and that stat keeps the number it
-- had. They're read again on the game's own events, at most five times a
-- second.
--
-- Everything here is EraUI's own frame and textures: nothing of the game's
-- is hooked, moved or written on, and the game's tooltip is never used.
local Module = {}
EraUI:RegisterModule("StatTracker", Module)

local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
local GAIN_SECONDS = 5           -- how long a stat that went up stays green
local THROTTLE = .2              -- the numbers are read at most five times a second
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF" -- the AFK Screen's title font
local PAD_X, PAD_TOP, PAD_BOTTOM, ROW_H, MIN_WIDTH = 14, 10, 10, 20, 180
local LINE_PAD_X, LINE_PAD_Y, LINE_GAP = 16, 8, 18
-- The first-time spot: the panel's top right corner this far from the
-- middle of the screen's right edge (in the screen's units): a little above
-- the middle, clear of the side action bars (80 in, Classic/ClassicBar.lua),
-- under the minimap, away from the chat.
local HOME_X, HOME_Y = -96, 120
-- One line's first-time spot: its top centre this far below the screen's
-- (in the screen's units). At the right, /era (984 wide, centred, over it)
-- would cover most of a bar of eight stats (about 600 wide).
local LINE_HOME_Y = -14
local SIZE_MIN, SIZE_MAX = 50, 150 -- Panel Size, in percent (statTrackerScale)

-- Every stat in /era's order: its setting ("statTracker" .. id, the ticks
-- are Core/Settings.lua's), its name in the list and on one line, and how
-- it's written: "whole" (1,204), "tenth" (9.4%) or "percent" (100%). The
-- short names are the ones players say: Stam, not Sta.
local STATS = {
    {id = "Strength", label = "Strength", short = "Str", kind = "whole"},
    {id = "Agility", label = "Agility", short = "Agi", kind = "whole"},
    {id = "Stamina", label = "Stamina", short = "Stam", kind = "whole"},
    {id = "Intellect", label = "Intellect", short = "Int", kind = "whole"},
    {id = "Spirit", label = "Spirit", short = "Spirit", kind = "whole"},
    {id = "AttackPower", label = "Attack Power", short = "AP", kind = "whole"},
    {id = "Crit", label = "Crit", short = "Crit", kind = "tenth"},
    {id = "Hit", label = "Hit", short = "Hit", kind = "tenth"},
    {id = "SpellPower", label = "Spell Power", short = "SP", kind = "whole"},
    {id = "SpellCrit", label = "Spell Crit", short = "Spell Crit", kind = "tenth"},
    {id = "Armor", label = "Armor", short = "Armor", kind = "whole"},
    {id = "Dodge", label = "Dodge", short = "Dodge", kind = "tenth"},
    {id = "Parry", label = "Parry", short = "Parry", kind = "tenth"},
    {id = "Block", label = "Block", short = "Block", kind = "tenth"},
    {id = "Speed", label = "Speed", short = "Speed", kind = "percent"},
    {id = "Durability", label = "Durability", short = "Dura", kind = "percent"},
}
Module.STATS = STATS
local ALL = #STATS -- Stats per Line's top end (All, the default): every stat on one line

-- Classic: gold names and white numbers on a near-black panel with a bronze
-- edge and a fine black line inside it. Dark Mode: grey names and light
-- numbers, a thin edge in the Darkness slider's grey (half as light), no line.
local LOOKS = {
    classic = {fill = {.024, .024, .031, .84}, edge = 2, line = true, title = {1, .82, 0}, rule = {.29, .235, .102},
        label = {1, .82, 0}, value = {1, 1, 1}},
    dark = {fill = {.071, .071, .086, .9}, edge = 1, line = false, title = {.925, .925, .94}, rule = {.173, .173, .204},
        label = {.639, .639, .678}, value = {.925, .925, .94}},
}
local BRONZE = {.541, .427, .169}
local GREEN = {.29, .87, .5}
-- Stat Name Colour's own choices (Match look is the look's label colour).
local NAME_COLOURS = {gold = {1, .82, 0}, white = {1, 1, 1}}
local CUSTOM_DEFAULT = "FFD100" -- Core/Init.lua's statTrackerNameCustomColour: the Classic gold

local panel, events, fill, title, rule
local edges, lines = {}, {}      -- the edge's four strips, and the fine line's inside it
local rows = {}                  -- stat id -> its name, number and gain font strings
local shown = {}                 -- stat id -> the number on show, rounded as written
local gains = {}                 -- stat id -> {amount, ends}: how much it went up lately, green until ends
local fighting, queued, watching, hooked = false, false, false, false
local dragging                   -- a drag under way
local scaled = 1                 -- the Panel Size it wears now
local homed                      -- the layout whose first-time spot it holds ("list" or "line"), nil at a saved spot
local wet, drying = false, false -- in the water at the last read, and a look booked for when you're out
local soaked = false             -- in the water at the read before this one

local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Public(v) and type(v) == "number" end
local function Ran(ok, ...) if ok then return ... end end
-- One of the game's functions: what it returns, or nothing when the game
-- hasn't got it or it fails.
local function Call(fn, ...)
    if type(fn) == "function" then return Ran(pcall(fn, ...)) end
end
local function Enabled()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("statTracker") == true
end

-- Reading ----------------------------------------------------------------------

-- A part of a stat: a number to show; false when the game won't say (a
-- secret); nil when there's nothing to say (no such function, it failed or
-- gave nothing), so that part is left out.
local function Part(v)
    if Number(v) then return v end
    if Public(v) then return nil end
    return false
end
local function First(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return Part(v)
end
-- The highest of the parts given (those left out skipped), or nil; nil too
-- when any of them won't say, so a part kept secret never leaves a lower
-- number on show.
local function Highest(...)
    local best
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if v == false then return nil end
        if v ~= nil and (best == nil or v > best) then best = v end
    end
    return best
end
local function Attribute(index)
    local _, effective = Call(UnitStat, "player", index)
    return Part(effective)
end
-- Attack power as the character window adds it up: base, buffs and
-- debuffs, never under 0.
local function Power(fn)
    local base, up, down = Call(fn, "player")
    if Number(base) and Number(up) and Number(down) then return math.max(0, base + up + down) end
    if Public(base) and Public(up) and Public(down) then return nil end
    return false
end
-- Hit from gear and talents for one kind of attack, as the character window
-- adds it up: its modifier and its rating's bonus.
local function HitFor(rating, modifier)
    local extra = First(modifier)
    if not extra or rating == nil or type(GetCombatRatingBonus) ~= "function" then return extra end
    local bonus = First(GetCombatRatingBonus, rating)
    if bonus == false then return false end
    return extra + (bonus or 0)
end
-- Each school's number from fn (holy to arcane), the highest; nil when any won't say.
local function BestSchool(fn)
    local best
    for school = 2, type(MAX_SPELL_SCHOOLS) == "number" and MAX_SPELL_SCHOOLS or 7 do
        local v = First(fn, school)
        if v == false then return nil end
        best = Highest(best, v)
    end
    return best
end
-- Each stat's number now; nil or false when the game won't say (the stat
-- keeps its number). Attack power and crit: melee or ranged, whichever is
-- higher. Hit: the best of melee, ranged and spells, as the character window
-- shows it. Spell power: the strongest school. Speed: your run speed as a
-- share of the normal one (mounts and Sprint count; standing still doesn't).
-- In water Forever most likely gives your swim speed in its place (4.72 of
-- 7, the 67% seen in game), so while you swim Speed keeps the run speed it
-- had, and is read again once you're out (Update looks each second until
-- then). A leap out of the water counts as wet until you land, as Forever's
-- character window keeps its swim reading while you fall after a swim
-- (Camelot PaperDollFrame.lua, MovementSpeed_OnUpdate).
-- Durability: the average of the gear you wear that has any.
local READ = {
    Strength = function() return Attribute(1) end,
    Agility = function() return Attribute(2) end,
    Stamina = function() return Attribute(3) end,
    Intellect = function() return Attribute(4) end,
    Spirit = function() return Attribute(5) end,
    AttackPower = function() return Highest(Power(UnitAttackPower), Power(UnitRangedAttackPower)) end,
    Crit = function() return Highest(First(GetCritChance), First(GetRangedCritChance)) end,
    Hit = function()
        return Highest(HitFor(CR_HIT_MELEE, GetHitModifier), HitFor(CR_HIT_RANGED, GetRangedHitModifier),
            HitFor(CR_HIT_SPELL, GetSpellHitModifier))
    end,
    SpellPower = function() return BestSchool(GetSpellBonusDamage) end,
    -- Forever's character window asks without a school; a game wanting one
    -- (asking without fails) gets each school in turn.
    SpellCrit = function()
        local all = First(GetSpellCritChance)
        if all ~= nil then return all end
        return BestSchool(GetSpellCritChance)
    end,
    Armor = function()
        local _, effective = Call(UnitArmor, "player")
        return Part(effective)
    end,
    Dodge = function() return First(GetDodgeChance) end,
    Parry = function() return First(GetParryChance) end,
    Block = function() return First(GetBlockChance) end,
    Speed = function()
        local swimming = Call(IsSwimming)
        if not Public(swimming) then return false end
        if swimming == true then wet = true; return nil end
        -- Still in the air after a swim: still wet. When the game won't say
        -- whether you fall, the number is kept and a look booked.
        if soaked then
            local falling = Call(IsFalling)
            if not Public(falling) then wet = true; return false end
            if falling == true then wet = true; return nil end
        end
        local _, run = Call(GetUnitSpeed, "player")
        local normal = type(BASE_MOVEMENT_SPEED) == "number" and BASE_MOVEMENT_SPEED > 0 and BASE_MOVEMENT_SPEED or 7
        run = Part(run)
        if run then return run / normal * 100 end
        return run
    end,
    -- Gear without durability is skipped; nothing worn that has any is 100%.
    Durability = function()
        if type(GetInventoryItemDurability) ~= "function" then return nil end
        local total, count = 0, 0
        for slot = 1, 19 do
            local current, maximum = Call(GetInventoryItemDurability, slot)
            if not (Public(current) and Public(maximum)) then return false end
            if current ~= nil or maximum ~= nil then
                if not (Number(current) and Number(maximum)) then return false end
                if maximum > 0 then total, count = total + current / maximum, count + 1 end
            end
        end
        return count > 0 and total / count * 100 or 100
    end,
}

local function Round(stat, v)
    if stat.kind == "tenth" then return math.floor(v * 10 + .5) / 10 end
    return math.floor(v + .5)
end
-- A number as it's written on the panel: 1,204 (the game's own grouping),
-- 9.4% or 100%.
local function Written(stat, v)
    if stat.kind == "tenth" then return string.format("%.1f%%", v) end
    if stat.kind == "percent" then return string.format("%d%%", v) end
    if v >= 1000 and type(BreakUpLargeNumbers) == "function" then
        local ok, text = pcall(BreakUpLargeNumbers, v)
        if ok and type(text) == "string" then return text end
    end
    return string.format("%d", v)
end

local function Ticked()
    local list = {}
    for _, stat in ipairs(STATS) do
        if EraUI:GetSetting("statTracker" .. stat.id) == true then list[#list + 1] = stat end
    end
    return list
end

-- Reads the stats on show. A number higher than the one before adds to that
-- stat's gain, green for GAIN_SECONDS from now; a lower one takes off it (a
-- gain used up goes). A stat the game won't say about keeps its number.
-- Stats not on show are forgotten, so a stat ticked again starts afresh.
-- True when a gain began, so the green can be taken off when it ends.
local function Read(list, now)
    local greens = EraUI:GetSetting("statTrackerGains") == true
    local on, began = {}, false
    soaked, wet = wet, false
    for _, stat in ipairs(list) do
        on[stat.id] = true
        local raw = READ[stat.id]()
        if raw then
            local value, before = Round(stat, raw), shown[stat.id]
            shown[stat.id] = value
            if greens and before ~= nil and value ~= before then
                local gain = gains[stat.id]
                local live = gain ~= nil and gain.ends > now
                local amount = Round(stat, (live and gain.amount or 0) + value - before)
                if value > before then
                    gains[stat.id] = {amount = amount, ends = now + GAIN_SECONDS}
                    began = true
                elseif live and amount > 0 then
                    gain.amount = amount
                else
                    gains[stat.id] = nil
                end
            end
        end
    end
    for id in pairs(shown) do
        if not on[id] then shown[id], gains[id] = nil, nil end
    end
    if not greens then wipe(gains) end
    return began
end

-- The panel -----------------------------------------------------------------

local function Look()
    if EraUI:GetSetting("darkMode") then
        local r, g, b = .42, .44, .48
        local grey = EraUI.Classic and EraUI.Classic.DarkGrey
        if grey then r, g, b = grey() end
        return LOOKS.dark, {r * .5, g * .5, b * .5}
    end
    return LOOKS.classic, BRONZE
end

local function HexRGB(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then hex = CUSTOM_DEFAULT end
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
-- Your class colour (a paladin's pink, as everywhere in EraUI), or the
-- look's own when the game won't say.
local function ClassRGB(look)
    local _, class = Call(UnitClass, "player")
    if Public(class) and type(class) == "string" then
        if class == "PALADIN" then return .96, .55, .73 end
        local colour = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
        if colour and Number(colour.r) and Number(colour.g) and Number(colour.b) then return colour.r, colour.g, colour.b end
    end
    return look.label[1], look.label[2], look.label[3]
end
-- The stat names' colour (Stat Name Colour): the look's own (Match look,
-- and anything unknown), gold, your class colour, white or your own.
local function NameRGB(look)
    local choice = EraUI:GetSetting("statTrackerNameColour")
    local colour = NAME_COLOURS[choice]
    if colour then return colour[1], colour[2], colour[3] end
    if choice == "class" then return ClassRGB(look) end
    if choice == "custom" then return HexRGB(EraUI:GetSetting("statTrackerNameCustomColour")) end
    return look.label[1], look.label[2], look.label[3]
end

-- Panel Size as a scale, 0.5 to 1.5.
local function Scale()
    local size = tonumber(EraUI:GetSetting("statTrackerScale")) or 100
    return math.max(SIZE_MIN, math.min(SIZE_MAX, size)) / 100
end
-- Stats per Line (One line only), 1 to every stat there is, rounded as the
-- slider rounds; unreadable: All.
local function PerLine()
    local count = tonumber(EraUI:GetSetting("statTrackerPerLine")) or ALL
    return math.floor(math.max(1, math.min(ALL, count)) + .5)
end
-- Where it was dragged to (its top left corner, from the screen's, in the
-- screen's units whatever its size), or nil.
local function Saved()
    local spot = EraUI:GetSetting("statTrackerPosition")
    if type(spot) == "table" and type(spot.x) == "number" and type(spot.y) == "number" then return spot end
end
local function Line() return EraUI:GetSetting("statTrackerLayout") == "line" end
-- The layout whose first-time spot it should hold, or nil (it has a saved spot).
local function Home()
    if Saved() then return nil end
    return Line() and "line" or "list"
end
-- Its saved place (that always wins), or its layout's first-time spot: a
-- list at the right (HOME), one line at the top centre (LINE_HOME_Y). A
-- point's offsets are in the panel's own scaled units, so they're divided
-- by its size: the spot stays put on the screen whatever the size.
local function Place()
    local spot = Saved()
    panel:ClearAllPoints()
    homed = Home()
    if spot then
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", spot.x / scaled, spot.y / scaled)
    elseif homed == "line" then
        panel:SetPoint("TOP", UIParent, "TOP", 0, LINE_HOME_Y / scaled)
    else
        panel:SetPoint("TOPRIGHT", UIParent, "RIGHT", HOME_X / scaled, HOME_Y / scaled)
    end
end
-- After a drag: where its top left corner is now, from the screen's, in
-- the screen's units (its own edges times its size).
local function Save()
    dragging = false
    if panel.SetUserPlaced then panel:SetUserPlaced(false) end
    local left, top, height = panel:GetLeft(), panel:GetTop(), UIParent:GetHeight()
    if not (Number(left) and Number(top) and Number(height)) then return end
    EraUI:SetSetting("statTrackerPosition", {x = math.floor(left * scaled + .5), y = math.floor(top * scaled - height + .5)})
    if EraUI.SaveSettings then EraUI:SaveSettings() end
    Place()
end
-- Panel Size changed: the new size, held at the same spot. Layout changed
-- before it was ever dragged: that layout's first-time spot. Never in the
-- middle of a drag (it follows at the next change).
local function Resize()
    if dragging then return end
    local scale = Scale()
    if scale == scaled and Home() == homed then return end
    scaled = scale
    panel:SetScale(scale)
    Place()
end

local function Text(size, font)
    local text = panel:CreateFontString(nil, "OVERLAY")
    if text:SetFont(font or FONT, size, "") == false then text:SetFont(FONT, size, "") end
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    text:Hide()
    return text
end

-- Made once, the first time it's switched on. Sized at once: Forever may
-- never draw a frame laid out under one without a size. HIGH: over the
-- game's windows and bars (MEDIUM and under), under /era and the game's
-- pop-ups (DIALOG); nothing of /era's moves or raises it.
local function Build()
    if panel then return end
    panel = CreateFrame("Frame", "EraUIStatTracker", UIParent)
    panel:SetSize(MIN_WIDTH, 60)
    panel:SetFrameStrata("HIGH")
    scaled = Scale()
    panel:SetScale(scaled)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    -- Its place is EraUI's own (statTrackerPosition, in the screen's units):
    -- the game's layout cache never keeps one of its own, which would be in
    -- the panel's scaled units and could put it back elsewhere after a size
    -- change (Save also lets go of the "moved by you" mark a drag gives it).
    if panel.SetDontSavePosition then panel:SetDontSavePosition(true) end
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) dragging = true; self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Save() end)
    -- Hidden in the middle of a drag (/era closed with Escape, say): the drag
    -- ends there and that spot is kept, so nothing is left half-dragged.
    panel:SetScript("OnHide", function(self) if dragging then self:StopMovingOrSizing(); Save() end end)
    panel:Hide()
    fill = panel:CreateTexture(nil, "BACKGROUND")
    for i = 1, 4 do
        edges[i] = panel:CreateTexture(nil, "BORDER")
        lines[i] = panel:CreateTexture(nil, "BORDER", nil, 1)
    end
    title = Text(16, TITLE_FONT)
    title:SetText("Stats")
    rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:Hide()
    for _, stat in ipairs(STATS) do rows[stat.id] = {label = Text(13), value = Text(13), delta = Text(11)} end
    Place()
end

-- Four strips, size thick, inset in from the panel's edge.
local function Strips(list, inset, size)
    local top, bottom, left, right = list[1], list[2], list[3], list[4]
    top:ClearAllPoints()
    top:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -inset)
    top:SetHeight(size)
    bottom:ClearAllPoints()
    bottom:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", inset, inset)
    bottom:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, inset)
    bottom:SetHeight(size)
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT", panel, "TOPLEFT", inset, -inset - size)
    left:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", inset, inset + size)
    left:SetWidth(size)
    right:ClearAllPoints()
    right:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -inset, -inset - size)
    right:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -inset, inset + size)
    right:SetWidth(size)
end

-- The look: its fill, edge, fine line, title and the line under the title.
-- Also run by the Darkness slider (Core/Appearance.lua).
function Module:Paint()
    if not panel then return end
    local look, edge = Look()
    local width = look.edge
    fill:ClearAllPoints()
    fill:SetPoint("TOPLEFT", panel, "TOPLEFT", width, -width)
    fill:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -width, width)
    fill:SetColorTexture(look.fill[1], look.fill[2], look.fill[3], look.fill[4])
    Strips(edges, 0, width)
    Strips(lines, width, 1)
    for i = 1, 4 do
        edges[i]:SetColorTexture(edge[1], edge[2], edge[3], 1)
        lines[i]:SetColorTexture(0, 0, 0, 1)
        lines[i]:SetShown(look.line)
    end
    title:SetTextColor(look.title[1], look.title[2], look.title[3])
    rule:SetColorTexture(look.rule[1], look.rule[2], look.rule[3], 1)
end

local function At(text, x, y)
    text:ClearAllPoints()
    text:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -y)
    text:Show()
end
local function Width(text) return math.ceil(text:GetStringWidth() or 0) end

-- Each stat on show: its name (in Stat Name Colour), its number (white, or
-- green while it's gone up lately, with how much after it), "--" until the
-- game has said.
local function Words(list, line, now)
    local look = Look()
    local r, g, b = NameRGB(look)
    for _, stat in ipairs(list) do
        local row, value, gain = rows[stat.id], shown[stat.id], gains[stat.id]
        local green = gain ~= nil and gain.ends > now
        local colour = green and GREEN or look.value
        row.label:SetText(line and stat.short or stat.label)
        row.label:SetTextColor(r, g, b)
        row.value:SetText(value ~= nil and Written(stat, value) or "--")
        row.value:SetTextColor(colour[1], colour[2], colour[3])
        row.delta:SetText(green and ("+" .. Written(stat, gain.amount)) or "")
        row.delta:SetTextColor(GREEN[1], GREEN[2], GREEN[3])
    end
end

-- A stat's number on one line, with its gain after it when it has one.
local function Figure(row)
    local width = Width(row.value)
    if row.delta:GetText() ~= "" then width = width + 4 + Width(row.delta) end
    return width
end

-- Stats per Line below All: the stats in rows of that many under each
-- other, in the panel's order, as a grid: the names in each column lined up,
-- its numbers lined up after its widest name, the next column after its
-- widest number. The text keeps its size. When that many won't fit across
-- the screen (the room below), fewer to a line: whichever is fewer wins.
local function Grid(list, room, columns)
    local names, figures, width
    for count = columns, 1, -1 do
        names, figures, width, columns = {}, {}, (count - 1) * LINE_GAP, count
        for i, stat in ipairs(list) do
            local column, row = (i - 1) % count + 1, rows[stat.id]
            names[column] = math.max(names[column] or 0, Width(row.label))
            figures[column] = math.max(figures[column] or 0, Figure(row))
        end
        for column = 1, count do width = width + names[column] + 6 + figures[column] end
        if width <= room then break end
    end
    local lefts, x = {}, LINE_PAD_X
    for column = 1, columns do
        lefts[column] = x
        x = x + names[column] + 6 + figures[column] + LINE_GAP
    end
    for i, stat in ipairs(list) do
        local column, row = (i - 1) % columns + 1, rows[stat.id]
        local y = LINE_PAD_Y + math.floor((i - 1) / columns) * ROW_H
        local number = lefts[column] + names[column] + 6
        At(row.label, lefts[column], y)
        At(row.value, number, y)
        if row.delta:GetText() ~= "" then At(row.delta, number + Width(row.value) + 4, y + 2) end
    end
    panel:SetSize(width + LINE_PAD_X * 2, LINE_PAD_Y * 2 + 14 + (math.ceil(#list / columns) - 1) * ROW_H)
end

-- One line: short names and numbers side by side, no title. As many as fit
-- across the screen, 20 clear of each side (the mockup's bar), then the rest
-- on a line below, each line centred. The screen in the panel's own units:
-- a bigger Panel Size fits fewer to a line. Stats per Line below All lays
-- them out in the grid above instead.
local function Bar(list)
    local screen = UIParent:GetWidth()
    local room = (Number(screen) and math.max(MIN_WIDTH, (screen - 40) / scaled) or math.huge) - LINE_PAD_X * 2
    local per = PerLine()
    if per < ALL and #list > 0 then return Grid(list, room, math.min(per, #list)) end
    local widths, lineOf, xOf, widest = {0}, {}, {}, 0
    for i, stat in ipairs(list) do
        local row = rows[stat.id]
        local span = Width(row.label) + 6 + Width(row.value)
        if row.delta:GetText() ~= "" then span = span + 4 + Width(row.delta) end
        local n = #widths
        if widths[n] > 0 and widths[n] + LINE_GAP + span > room then n = n + 1; widths[n] = 0 end
        if widths[n] > 0 then widths[n] = widths[n] + LINE_GAP end
        lineOf[i], xOf[i] = n, widths[n]
        widths[n] = widths[n] + span
        widest = math.max(widest, widths[n])
    end
    for i, stat in ipairs(list) do
        local row = rows[stat.id]
        local x = LINE_PAD_X + math.floor((widest - widths[lineOf[i]]) / 2) + xOf[i]
        local y = LINE_PAD_Y + (lineOf[i] - 1) * ROW_H
        At(row.label, x, y)
        x = x + Width(row.label) + 6
        At(row.value, x, y)
        if row.delta:GetText() ~= "" then At(row.delta, x + Width(row.value) + 4, y + 2) end
    end
    panel:SetSize(widest + LINE_PAD_X * 2, LINE_PAD_Y * 2 + 14 + (#widths - 1) * ROW_H)
end

-- List: the title and the line under it, then a line each, the name at the
-- left and the number at the right. One line: the bar above. The panel
-- takes the size of what's on it.
local function Layout(list, now)
    local line = Line()
    local titled = not line and EraUI:GetSetting("statTrackerTitle") == true
    for _, row in pairs(rows) do row.label:Hide(); row.value:Hide(); row.delta:Hide() end
    title:SetShown(titled)
    rule:SetShown(titled)
    Words(list, line, now)
    if line then return Bar(list) end
    local names, numbers = 0, 0
    for _, stat in ipairs(list) do
        local row = rows[stat.id]
        local number = Width(row.value)
        if row.delta:GetText() ~= "" then number = number + 5 + Width(row.delta) end
        names, numbers = math.max(names, Width(row.label)), math.max(numbers, number)
    end
    local width = math.max(MIN_WIDTH, PAD_X * 2 + names + 22 + numbers)
    local y = PAD_TOP
    if titled then
        width = math.max(width, PAD_X * 2 + Width(title))
        At(title, PAD_X, y)
        y = y + 20
        rule:ClearAllPoints()
        rule:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_X, -y)
        rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD_X, -y)
        y = y + 6
    end
    for _, stat in ipairs(list) do
        local row = rows[stat.id]
        local right = width - PAD_X
        At(row.label, PAD_X, y)
        if row.delta:GetText() ~= "" then
            right = right - Width(row.delta)
            At(row.delta, right, y + 2)
            right = right - 5
        end
        At(row.value, right - Width(row.value), y)
        y = y + ROW_H
    end
    panel:SetSize(width, y + PAD_BOTTOM - 6)
end

-- Showing ---------------------------------------------------------------------

local function Previewing()
    local settings = EraUI.settingsFrame
    return settings ~= nil and settings:IsShown() == true
end
local function Wanted(list)
    if not Enabled() or #list == 0 then return false end
    if Previewing() then return true end
    local when = EraUI:GetSetting("statTrackerShow")
    if when == "combat" then return fighting end
    if when == "calm" then return not fighting end
    return true
end
-- Shown or hidden as its settings and the fight say. While /era is open it
-- shows whatever Show It says, where it is, so it can be seen and dragged:
-- /era never moves it, raises it or holds it beside itself.
local function Visibility(list)
    if not panel then return end
    panel:SetShown(Wanted(list or Ticked()))
end
local function HookSettings()
    local settings = EraUI.settingsFrame
    if hooked or not settings then return end
    hooked = true
    settings:HookScript("OnShow", function() Visibility() end)
    settings:HookScript("OnHide", function() Visibility() end)
end

local function Queue()
    if queued then return end
    queued = true
    if C_Timer and C_Timer.After then C_Timer.After(THROTTLE, function() Module:Update() end) else Module:Update() end
end
-- While you swim (Speed keeping its run speed), a look each second, so the
-- run speed is read again soon after you're out: one look booked at a time.
local function Drying()
    if drying or not (C_Timer and C_Timer.After) then return end
    drying = true
    C_Timer.After(1, function() drying = false; Queue() end)
end

-- The numbers read again, the panel laid out and shown or hidden.
function Module:Update()
    queued = false
    if not Enabled() then return end
    Build()
    HookSettings()
    local list, now = Ticked(), GetTime()
    if Read(list, now) and C_Timer and C_Timer.After then C_Timer.After(GAIN_SECONDS + .05, Queue) end
    if wet then Drying() end
    Layout(list, now)
    Visibility(list)
end

-- What changes a stat: its own events (yours only), auras, ratings, spell
-- power, gear, durability and levels. A fight starting or ending only shows
-- or hides it.
local UNIT_EVENTS = {"UNIT_STATS", "UNIT_AURA", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_RESISTANCES", "UNIT_LEVEL"}
local EVENTS = {"COMBAT_RATING_UPDATE", "SPELL_POWER_CHANGED", "SPEED_UPDATE", "PLAYER_EQUIPMENT_CHANGED",
    "UPDATE_INVENTORY_DURABILITY", "PLAYER_LEVEL_UP", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED"}
local function Watch()
    if watching then return end
    watching = true
    for _, event in ipairs(UNIT_EVENTS) do
        if not (events.RegisterUnitEvent and pcall(events.RegisterUnitEvent, events, event, "player")) then
            pcall(events.RegisterEvent, events, event)
        end
    end
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
end
local function OnEvent(_, event, unit)
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        fighting = event == "PLAYER_REGEN_DISABLED"
        Visibility()
        return
    end
    if event:sub(1, 5) == "UNIT_" and not (Public(unit) and unit == "player") then return end
    if event == "PLAYER_ENTERING_WORLD" then fighting = InCombatLockdown() and true or false end
    Queue()
end

-- Its switch, its layout, when it shows, its size, the stats per line, the
-- green, the title, the names' colour and each stat's tick in /era, all at
-- once.
function Module:Refresh()
    if not events then return end
    if not Enabled() then
        if watching then events:UnregisterAllEvents(); watching = false end
        wipe(shown); wipe(gains)
        if panel then panel:Hide() end
        return
    end
    -- Off (or not yet started), no fight was watched: ask whether you're in one.
    if not watching then fighting = InCombatLockdown() and true or false end
    Watch()
    Build()
    Resize()
    self:Paint()
    self:Update()
end

function Module:Initialize()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    self:Refresh()
end
