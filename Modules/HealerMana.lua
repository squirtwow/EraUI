local _, EraUI = ...

-- Healer Mana (/era > Group & Invites > Healer mana): a small floating
-- panel of the healers in your party or raid, a line each: the name in its
-- class colour, a mana bar with the mana left on it, and a cup with
-- "Drinking" while they drink. Healers are players with the Healer role,
-- or, with no role set, priests, druids, paladins and shamans; Every Mana
-- User shows everyone who uses mana instead, and Include Me adds you. Up to
-- ten lines, grown down from the top, by group and then name. It shows in a
-- party or a raid (each its own tick), while unlocked to place it (sample
-- lines when nobody counts yet) and while /era is open.
--
-- Unlock (/era's Move Panel) lets it be dragged anywhere; a right-click on
-- it, Lock or a fight starting locks it. Locked, it takes no mouse at all,
-- so clicks go through to the world. Its place is EraUI's own
-- (healerManaPosition, its top left corner in the screen's units), kept on
-- screen; Reset puts it back at its first spot.
--
-- Forever (wow-ui-source forever 71037, Blizzard_APIDocumentationGenerated)
-- makes other players' UnitPower, UnitPowerMax and UnitPowerPercent secret
-- in a fight. A secret is never compared, added up, joined or tested here:
-- the bar takes the game's numbers as they are (StatusBar SetMinMaxValues
-- and SetValue take secrets), and the percent is the game's own, through
-- its 0 to 100 curve, straight into SetFormattedText (as Forever Enhanced
-- Raid Frames shows secret health in game). Low Mana Colour is worked out
-- here only while the numbers can be read; while they're secret the game
-- picks the colour itself through a colour curve (C_CurveUtil's, the way
-- Blizzard's aura buttons colour a dispel type), and if that fails the bar
-- stays blue. Auras are secret in a fight too, so a drink is looked for
-- only out of one (Drinking goes as a fight starts, and is looked for again
-- as it ends). Names and classes can be secret: a secret name still shows
-- (SetText takes it) but sorts last, and a player whose class and role the
-- game hides isn't counted. Casts are never read (the game hides them).
--
-- Everything here is EraUI's own frames and textures: nothing of the
-- game's is hooked, moved or written on, there are no key bindings, and
-- the game's tooltip is never used.
local Module = {}
EraUI:RegisterModule("HealerMana", Module)

local MAX_ROWS = 10
local MANA = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local TITLE_FONT = "Fonts\\MORPHEUS.TTF" -- the Stat Tracker's title font
local CUP = "Interface\\Icons\\INV_Drink_07" -- the game's drink icon (Wowhead Forever, spell 430)
local FILL, SOLID = "Interface\\TargetingFrame\\UI-StatusBar", "Interface\\Buttons\\WHITE8X8"
local PAD_X, PAD_TOP, PAD_BOTTOM, TITLE_H, ROW_H, NAME_W, GAP, BAR_H, HINT_H = 8, 7, 7, 22, 18, 74, 6, 13, 16
local WIDTH_MIN, WIDTH_MAX, WIDTH_DEFAULT = 100, 240, 130 -- Bar Width, in pixels (healerManaWidth)
local SIZE_MIN, SIZE_MAX = 50, 150 -- Size, in percent (healerManaScale)
local LOW_MAX = 60 -- Low Mana Colour's top end, in percent (healerManaLow); 0 is off
-- The first-time spot: the panel's top right corner this far from the
-- middle of the screen's right edge, clear of the side action bars (80 in)
-- and under the Stat Tracker's first spot.
local HOME_X, HOME_Y = -96, -110
local BLUE = {.15, .4, 1} -- EraUI's mana blue (Modules/ResourceBar.lua)
local AMBER = {1, .65, .1}
local GREY = {.45, .45, .5}
-- Classic: a near-black panel with a bronze edge and a fine black line
-- inside it, a gold title. Dark Mode: a dark panel, a thin edge in the
-- Darkness slider's grey (half as light), a light title. As the Stat Tracker.
local LOOKS = {
    classic = {fill = {.024, .024, .031, .84}, edge = 2, line = true, title = {1, .82, 0}, rule = {.29, .235, .102}},
    dark = {fill = {.071, .071, .086, .9}, edge = 1, line = false, title = {.925, .925, .94}, rule = {.173, .173, .204}},
}
local BRONZE = {.541, .427, .169}
local HEALERS = {PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true}
local MANA_USERS = {PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true, MAGE = true, WARLOCK = true, HUNTER = true}
-- Forever's drink buffs (Wowhead Forever, 22 Nov 2026): every "Drink" from
-- level 5 water up, and "Refreshment". Matched by spell ID, so any
-- language works, or by the English name for one not listed.
local DRINK_IDS = {[430] = true, [431] = true, [432] = true, [1133] = true, [1135] = true, [1137] = true, [10250] = true,
    [22734] = true, [24355] = true, [25696] = true, [26261] = true, [26402] = true, [26473] = true, [26475] = true,
    [29007] = true, [446714] = true, [167152] = true}
local DRINK_NAMES = {Drink = true, Refreshment = true}
Module.DRINK_IDS, Module.DRINK_NAMES = DRINK_IDS, DRINK_NAMES
-- The lines shown while unlocked (or /era is open) with nobody to show.
local SAMPLES = {
    {sample = true, name = "Priest", class = "PRIEST", mana = 85},
    {sample = true, name = "Druid", class = "DRUID", mana = 42, drinking = true},
    {sample = true, name = "Shaman", class = "SHAMAN", mana = 18},
}

local panel, events, fill, title, rule, hint, box
local edges, lines = {}, {}      -- the edge's four strips, and the fine line's inside it
local rows = {}                  -- the line frames, made as they're first needed
local roster = {}                -- who shows now, in order
local inRaid, grouped = false, false
local fighting, queued, watching, hooked, dragging = false, false, false, false, false
local scaled = 1                 -- the Size it wears now
local percentCurve, colourCurve, colourAt

local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Public(v) and type(v) == "number" end
local function Word(v) return Public(v) and type(v) == "string" and v ~= "" end
local function Ran(ok, ...) if ok then return ... end end
-- One of the game's functions: what it returns, or nothing when the game
-- hasn't got it or it fails.
local function Call(fn, ...)
    if type(fn) == "function" then return Ran(pcall(fn, ...)) end
end
local function Yes(v) return Public(v) and v == true end
local function Enabled()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("healerMana") == true
end
-- A slider's setting as a whole number in its range; unreadable: its default.
local function Setting(key, low, high, default)
    local v = tonumber(EraUI:GetSetting(key))
    if not v or v ~= v or v == math.huge or v == -math.huge then v = default end
    return math.floor(math.max(low, math.min(high, v)) + .5)
end
local function BarWidth() return Setting("healerManaWidth", WIDTH_MIN, WIDTH_MAX, WIDTH_DEFAULT) end
local function Scale() return Setting("healerManaScale", SIZE_MIN, SIZE_MAX, 100) / 100 end
local function Low() return Setting("healerManaLow", 0, LOW_MAX, 30) end

-- Curves -------------------------------------------------------------------------

-- The game's percent from 0 to 100: its own curve, or one made like it.
local function PercentCurve()
    if percentCurve == nil then
        percentCurve = false
        if CurveConstants and CurveConstants.ScaleTo100 then
            percentCurve = CurveConstants.ScaleTo100
        elseif C_CurveUtil and C_CurveUtil.CreateCurve then
            local ok, curve = pcall(function()
                local c = C_CurveUtil.CreateCurve()
                if Enum and Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Linear) end
                c:AddPoint(0, 0)
                c:AddPoint(1, 100)
                return c
            end)
            if ok and curve then percentCurve = curve end
        end
    end
    return percentCurve or nil
end
-- Amber from empty up to Low Mana Colour, blue from just past it to full,
-- for the game to evaluate a secret mana with. Made again when the line moves.
local function ColourCurve(low)
    if colourAt ~= low then
        colourAt, colourCurve = low, false
        if low > 0 and C_CurveUtil and C_CurveUtil.CreateColorCurve and type(CreateColor) == "function" then
            local ok, curve = pcall(function()
                local c = C_CurveUtil.CreateColorCurve()
                if Enum and Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Linear) end
                local amber, blue = CreateColor(AMBER[1], AMBER[2], AMBER[3], 1), CreateColor(BLUE[1], BLUE[2], BLUE[3], 1)
                c:AddPoint(0, amber)
                c:AddPoint(low / 100, amber)
                c:AddPoint(low / 100 + .0001, blue)
                c:AddPoint(1, blue)
                return c
            end)
            if ok and curve then colourCurve = curve end
        end
    end
    return colourCurve or nil
end

-- Reading --------------------------------------------------------------------

-- Who counts: the Healer role when one is set (Tank or Damage never does),
-- else a healing class; with Every Mana User, every class that uses mana (or,
-- when the game hides the class, whoever uses mana now). Nothing the game
-- hides is guessed at.
local function Counts(unit, class, every)
    if every then
        if class then return MANA_USERS[class] == true end
        local kind = Call(UnitPowerType, unit)
        return Number(kind) and kind == MANA
    end
    local role = Call(UnitGroupRolesAssigned, unit)
    if Word(role) then
        if role == "HEALER" then return true end
        if role == "TANK" or role == "DAMAGER" then return false end
    end
    return class ~= nil and HEALERS[class] == true
end
-- Whether a raid unit is you: the game says so, or your GUIDs match.
local function Mine(unit)
    local same = Call(UnitIsUnit, unit, "player")
    if Public(same) and same ~= nil then return same == true end
    local guid, mine = Call(UnitGUID, unit), Call(UnitGUID, "player")
    return Word(guid) and Word(mine) and guid == mine
end
-- A drink buff on them, out of a fight only. A buff whose spell or name the
-- game hides (some always are) is passed over, never read; the buffs, or
-- the list, hidden or unreadable: no drink.
local function Drinking(unit)
    local get = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
    if fighting or type(get) ~= "function" then return false end
    for i = 1, 40 do
        local ok, aura = pcall(get, unit, i, "HELPFUL")
        if not ok or not Public(aura) or aura == nil or type(aura) ~= "table" then return false end
        local id, name = aura.spellId, aura.name
        if Number(id) and DRINK_IDS[id] then return true end
        if Word(name) and DRINK_NAMES[name] then return true end
    end
    return false
end
-- One player's line: their unit, name (a secret one kept as it is, sorted
-- last), class, group and place in the roster.
local function Entry(unit, index, group, every)
    if not Yes(Call(UnitExists, unit)) then return nil end
    local _, class = Call(UnitClass, unit)
    if not Word(class) then class = nil end
    if not Counts(unit, class, every) then return nil end
    local name = Call(UnitName, unit)
    local entry = {unit = unit, index = index, group = group, class = class, name = name}
    if Word(name) then entry.sortName = string.lower(name) end
    return entry
end
local function Before(a, b)
    if a.group ~= b.group then return a.group < b.group end
    if a.sortName and b.sortName then
        if a.sortName ~= b.sortName then return a.sortName < b.sortName end
    elseif a.sortName or b.sortName then
        return a.sortName ~= nil
    end
    return a.index < b.index
end
-- The players to show: a raid's by its roster (raid1 to raid40, their group
-- from it), a party's members (and you), each counted as above, sorted by
-- group then name, at most ten. Only those ten are looked at for a drink.
local function Read()
    local list = {}
    local every, me = EraUI:GetSetting("healerManaAll") == true, EraUI:GetSetting("healerManaSelf") == true
    inRaid, grouped = Yes(Call(IsInRaid)), Yes(Call(IsInGroup))
    if inRaid then
        local count = Call(GetNumGroupMembers)
        count = Number(count) and math.min(40, count) or 0
        for i = 1, count do
            local unit = "raid" .. i
            if me or not Mine(unit) then
                local _, _, group = Call(GetRaidRosterInfo, i)
                list[#list + 1] = Entry(unit, i, Number(group) and group or 9, every)
            end
        end
    elseif grouped then
        local count = Call(GetNumSubgroupMembers)
        count = Number(count) and math.min(4, count) or 0
        for i = 1, count do list[#list + 1] = Entry("party" .. i, i, 1, every) end
        if me then list[#list + 1] = Entry("player", 0, 1, every) end
    end
    table.sort(list, Before)
    for i = #list, MAX_ROWS + 1, -1 do list[i] = nil end
    for i = 1, #list do list[i].drinking = Drinking(list[i].unit) end
    return list
end

-- A line ----------------------------------------------------------------------

local function Paint(bar, colour) bar:SetStatusBarColor(colour[1], colour[2], colour[3]) end
-- The game's colour for a secret mana, never read here.
local function CurveColour(bar, unit, curve)
    local colour = UnitPowerPercent(unit, MANA, false, curve)
    bar:SetStatusBarColor(colour:GetRGB())
end
-- The game's own percent, 0 to 100, never read here.
local function CurvePercent(text, unit, curve)
    text:SetFormattedText("%.0f%%", UnitPowerPercent(unit, MANA, false, curve))
end
-- Blue, or amber at or under Low Mana Colour.
local function Tint(row, unit, power, most)
    local low = Low()
    if low <= 0 then return Paint(row.bar, BLUE) end
    if Number(power) and Number(most) then
        return Paint(row.bar, (most > 0 and power * 100 <= low * most) and AMBER or BLUE)
    end
    local curve = ColourCurve(low)
    if not (curve and type(UnitPowerPercent) == "function" and pcall(CurveColour, row.bar, unit, curve)) then Paint(row.bar, BLUE) end
end
-- A sample line's bar and words: plain numbers.
local function Sample(row, entry)
    row.bar:SetMinMaxValues(0, 100)
    row.bar:SetValue(entry.mana)
    row.value:SetFormattedText("%d%%", entry.mana)
    local low = Low()
    Paint(row.bar, (low > 0 and entry.mana <= low) and AMBER or BLUE)
end
-- A line's mana: the bar (the game's numbers as they are), its percent and
-- its colour; Offline or Dead in grey instead.
local function Update(row)
    local entry = row.entry
    if not entry then return end
    if entry.sample then return Sample(row, entry) end
    local unit, bar = entry.unit, row.bar
    local word
    if type(UnitIsConnected) == "function" then
        local online = Call(UnitIsConnected, unit)
        if Public(online) and not online then word = "Offline" end
    end
    if not word and Yes(Call(UnitIsDeadOrGhost, unit)) then word = "Dead" end
    if word then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        row.value:SetText(word)
        return Paint(bar, GREY)
    end
    local power, most = Call(UnitPower, unit, MANA), Call(UnitPowerMax, unit, MANA)
    if Public(most) and not (Number(most) and most > 0) then
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
    else
        pcall(bar.SetMinMaxValues, bar, 0, most)
        if Public(power) and not Number(power) then bar:SetValue(0) else pcall(bar.SetValue, bar, power) end
    end
    local curve = PercentCurve()
    if not (curve and type(UnitPowerPercent) == "function" and pcall(CurvePercent, row.value, unit, curve)) then
        if Number(power) and Number(most) and most > 0 then
            row.value:SetFormattedText("%d%%", math.floor(power / most * 100 + .5))
        else
            row.value:SetText("")
        end
    end
    Tint(row, unit, power, most)
end
-- The cup and its word, while they drink.
local function ShowDrink(row)
    local on = row.entry ~= nil and row.entry.drinking == true
    row.cup:SetShown(on)
    row.drink:SetShown(on)
end
-- The name in its class colour (a paladin's pink, as everywhere in EraUI);
-- a secret name goes to the text as it is, in white.
local function ClassRGB(class)
    if class == "PALADIN" then return .96, .55, .73 end
    local colour = class and ((CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class]) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]))
    if colour and Number(colour.r) and Number(colour.g) and Number(colour.b) then return colour.r, colour.g, colour.b end
    return .92, .92, .94
end
local function Name(row)
    local entry = row.entry
    if Word(entry.name) then row.name:SetText(entry.name)
    elseif Public(entry.name) then row.name:SetText("")
    else pcall(row.name.SetText, row.name, entry.name) end
    row.name:SetTextColor(ClassRGB(entry.class))
end

-- UNIT_POWER_FREQUENT alone for mana: it hears every change, so the
-- slower UNIT_POWER_UPDATE as well would only run each line twice.
local ROW_EVENTS = {"UNIT_POWER_FREQUENT", "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_CONNECTION", "UNIT_NAME_UPDATE",
    "UNIT_AURA"}
local function Queue()
    if queued then return end
    queued = true
    if C_Timer and C_Timer.After then C_Timer.After(.1, function() Module:Rebuild() end) else Module:Rebuild() end
end
-- A line's own events, its unit's only (the game filters them, so a secret
-- payload never has to be read). Mana for a power event; a drink out of a
-- fight; a name or the roster read again.
local function RowEvent(row, event, unit, kind)
    local entry = row.entry
    if not entry or entry.sample then return end
    if row.loose and not (Word(unit) and unit == entry.unit) then return end
    if event == "UNIT_AURA" then
        if fighting then return end
        entry.drinking = Drinking(entry.unit)
        return ShowDrink(row)
    end
    if event == "UNIT_NAME_UPDATE" then return Queue() end
    if event == "UNIT_POWER_FREQUENT" and Word(kind) and kind ~= "MANA" then return end
    Update(row)
end
-- Listening for its unit, or for nothing.
local function Listen(row, unit)
    if row.unit == unit then return end
    row:UnregisterAllEvents()
    row.unit, row.loose = unit, false
    if not unit then return end
    for _, event in ipairs(ROW_EVENTS) do
        if not (row.RegisterUnitEvent and pcall(row.RegisterUnitEvent, row, event, unit)) then
            row.loose = true
            pcall(row.RegisterEvent, row, event)
        end
    end
end

local function Font(parent, size)
    local text = parent:CreateFontString(nil, "OVERLAY")
    if text:SetFont(FONT, size, "") == false then text:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:SetWordWrap(false)
    return text
end
-- A line, made the first time it's needed and kept: the name at the left,
-- the bar after it with the percent at its right end and the cup with
-- Drinking at its left.
local function Row(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Frame", nil, panel)
    row:SetSize(NAME_W + GAP + WIDTH_DEFAULT, ROW_H)
    row.name = Font(row, 12)
    row.name:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.name:SetWidth(NAME_W)
    row.name:SetJustifyH("LEFT")
    local bar = CreateFrame("StatusBar", nil, row)
    bar:SetSize(WIDTH_DEFAULT, BAR_H)
    bar:SetPoint("LEFT", row, "LEFT", NAME_W + GAP, 0)
    bar:SetStatusBarTexture(FILL)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    Paint(bar, BLUE)
    row.bar = bar
    row.back = bar:CreateTexture(nil, "BACKGROUND")
    row.back:SetAllPoints(bar)
    row.back:SetColorTexture(.06, .06, .08, .9)
    row.value = Font(bar, 10)
    row.value:SetPoint("RIGHT", bar, "RIGHT", -3, 0)
    row.value:SetJustifyH("RIGHT")
    row.cup = bar:CreateTexture(nil, "OVERLAY")
    row.cup:SetSize(BAR_H - 2, BAR_H - 2)
    row.cup:SetPoint("LEFT", bar, "LEFT", 2, 0)
    row.cup:SetTexture(CUP)
    row.cup:SetTexCoord(.08, .92, .08, .92)
    row.drink = Font(bar, 10)
    row.drink:SetPoint("LEFT", row.cup, "RIGHT", 2, 0)
    row.drink:SetText("Drinking")
    row.drink:SetTextColor(.7, .85, 1)
    row.cup:Hide()
    row.drink:Hide()
    row:SetScript("OnEvent", RowEvent)
    row:Hide()
    rows[i] = row
    return row
end

-- The panel ---------------------------------------------------------------

local function Look()
    if EraUI:GetSetting("darkMode") then
        local r, g, b = .42, .44, .48
        local grey = EraUI.Classic and EraUI.Classic.DarkGrey
        if grey then r, g, b = grey() end
        return LOOKS.dark, {r * .5, g * .5, b * .5}
    end
    return LOOKS.classic, BRONZE
end
-- Where it was dragged to (its top left corner, from the screen's, in the
-- screen's units whatever its size), or nil.
local function Saved()
    local spot = EraUI:GetSetting("healerManaPosition")
    if type(spot) == "table" and Number(spot.x) and Number(spot.y) then return spot end
end
-- Its saved place, or the first-time spot. A point's offsets are in the
-- panel's own scaled units, so they're divided by its size: the spot stays
-- put on the screen whatever the size.
local function Place()
    local spot = Saved()
    panel:ClearAllPoints()
    if spot then
        panel:SetPoint("TOPLEFT", UIParent, "TOPLEFT", spot.x / scaled, spot.y / scaled)
    else
        panel:SetPoint("TOPRIGHT", UIParent, "RIGHT", HOME_X / scaled, HOME_Y / scaled)
    end
end
-- After a drag: where its top left corner is now, in the screen's units.
local function Save()
    dragging = false
    panel:StopMovingOrSizing()
    if panel.SetUserPlaced then panel:SetUserPlaced(false) end
    local left, top, height = panel:GetLeft(), panel:GetTop(), UIParent:GetHeight()
    if Number(left) and Number(top) and Number(height) then
        EraUI:SetSetting("healerManaPosition", {x = math.floor(left * scaled + .5), y = math.floor(top * scaled - height + .5)})
        if EraUI.SaveSettings then EraUI:SaveSettings() end
    end
    Place()
end
-- Size changed: the new size, held at the same spot (never mid-drag).
local function Resize()
    if dragging then return end
    local scale = Scale()
    if scale == scaled then return end
    scaled = scale
    panel:SetScale(scale)
    Place()
end

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

-- Made once, the first time it's switched on. Sized at once: Forever may
-- never draw a frame laid out under one without a size. MEDIUM, with the
-- unit and raid frames. Locked it takes no mouse; unlocked, a left drag
-- moves it and a right-click locks it.
local function Build()
    if panel then return end
    panel = CreateFrame("Frame", "EraUIHealerMana", UIParent)
    panel:SetSize(PAD_X * 2 + NAME_W + GAP + WIDTH_DEFAULT, 80)
    panel:SetFrameStrata("MEDIUM")
    scaled = Scale()
    panel:SetScale(scaled)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    -- Its place is EraUI's own (healerManaPosition): the game's layout cache
    -- never keeps one of its own (Save also lets go of the "moved by you"
    -- mark a drag gives it).
    if panel.SetDontSavePosition then panel:SetDontSavePosition(true) end
    panel:EnableMouse(false)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        if not Module.unlocked then return end
        dragging = true
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function() if dragging then Save() end end)
    panel:SetScript("OnMouseUp", function(_, button) if button == "RightButton" and Module.unlocked then Module:SetUnlocked(false) end end)
    -- Hidden in the middle of a drag: the drag ends there and that spot is kept.
    panel:SetScript("OnHide", function() if dragging then Save() end end)
    panel:Hide()
    fill = panel:CreateTexture(nil, "BACKGROUND")
    for i = 1, 4 do
        edges[i] = panel:CreateTexture(nil, "BORDER")
        lines[i] = panel:CreateTexture(nil, "BORDER", nil, 1)
    end
    title = panel:CreateFontString(nil, "OVERLAY")
    if title:SetFont(TITLE_FONT, 14, "") == false then title:SetFont(FONT, 14, "") end
    title:SetShadowColor(0, 0, 0, 1)
    title:SetShadowOffset(1, -1)
    title:SetJustifyH("LEFT")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_X, -PAD_TOP)
    rule = panel:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_X, -(PAD_TOP + TITLE_H - 4))
    rule:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PAD_X, -(PAD_TOP + TITLE_H - 4))
    -- Unlocked: a gold box over it and how to move it, under the lines.
    box = panel:CreateTexture(nil, "OVERLAY")
    box:SetAllPoints(panel)
    box:SetColorTexture(.93, .75, .32, .14)
    box:Hide()
    hint = Font(panel, 10)
    hint:SetJustifyH("LEFT")
    hint:SetText("Drag to move. Right-click to lock.")
    hint:SetTextColor(.93, .75, .32)
    hint:Hide()
    Place()
end

-- The look: its fill, edge, fine line, title and the line under it. Also
-- run by the Darkness slider (Core/Appearance.lua).
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

local function Previewing()
    local settings = EraUI.settingsFrame
    return settings ~= nil and settings:IsShown() == true
end
-- Shown in a party or raid with someone to show (each its own tick), and
-- always while unlocked or while /era is open.
local function Wanted()
    if not Enabled() then return false end
    if Module.unlocked or Previewing() then return true end
    if not grouped or #roster == 0 then return false end
    if inRaid then return EraUI:GetSetting("healerManaRaid") ~= false end
    return EraUI:GetSetting("healerManaParty") ~= false
end

-- The title, a line for each player (the samples when there's nobody and
-- it shows to be placed), and the hint while unlocked; the panel takes the
-- size of what's on it.
local function Layout()
    local list = roster
    if #list == 0 and (Module.unlocked or Previewing()) then list = SAMPLES end
    local width = BarWidth()
    local texture = EraUI:GetSetting("flatBars") and SOLID or FILL
    title:SetText(EraUI:GetSetting("healerManaAll") == true and "Mana" or "Healer Mana")
    local y = PAD_TOP + TITLE_H
    for i = 1, MAX_ROWS do
        local entry = list[i]
        local row = entry and Row(i) or rows[i]
        if row then
            row.entry = entry
            if entry then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_X, -y)
                row:SetSize(NAME_W + GAP + width, ROW_H)
                row.bar:SetWidth(width)
                row.bar:SetStatusBarTexture(texture)
                Listen(row, not entry.sample and entry.unit or nil)
                Name(row)
                Update(row)
                ShowDrink(row)
                row:Show()
                y = y + ROW_H
            else
                Listen(row, nil)
                row:Hide()
            end
        end
    end
    hint:ClearAllPoints()
    hint:SetPoint("TOPLEFT", panel, "TOPLEFT", PAD_X, -(y + 2))
    hint:SetShown(Module.unlocked == true)
    if Module.unlocked then y = y + HINT_H end
    box:SetShown(Module.unlocked == true)
    panel:EnableMouse(Module.unlocked == true)
    panel:SetSize(PAD_X * 2 + NAME_W + GAP + width, y + PAD_BOTTOM)
end

local function Visibility()
    if panel then panel:SetShown(Wanted()) end
end
-- /era opening or closing: the preview (where it is, never moved for it).
local function HookSettings()
    local settings = EraUI.settingsFrame
    if hooked or not settings then return end
    hooked = true
    settings:HookScript("OnShow", function() if Enabled() then Module:Rebuild() end end)
    settings:HookScript("OnHide", function() if Enabled() then Module:Rebuild() end end)
end

-- The roster read again, the lines laid out and the panel shown or hidden.
-- Not wanted (Show in Party or Raid off, nobody to show): hidden, its lines
-- emptied and listening for nothing.
function Module:Rebuild()
    queued = false
    if not Enabled() then return end
    Build()
    HookSettings()
    roster = Read()
    if not Wanted() then
        for _, row in ipairs(rows) do Listen(row, nil); row.entry = nil; row:Hide() end
        panel:EnableMouse(false)
        panel:Hide()
        return
    end
    Layout()
    Visibility()
end

-- Unlock (or Lock). Nothing to unlock while it's off. watch(on) hears of
-- each change (/era's Move Panel button). A drag going on as it locks ends
-- first, kept where it is.
function Module:SetUnlocked(on)
    on = on and true or false
    if on and not Enabled() then return false end
    if not on and dragging then Save() end
    self.unlocked = on
    if panel or on then self:Rebuild() end
    if self.watch then self.watch(on) end
    return true
end

-- Reset: back to the first-time spot.
function Module:ResetPosition()
    EraUI:SetSetting("healerManaPosition", nil)
    if EraUI.SaveSettings then EraUI:SaveSettings() end
    if panel and not dragging then Place() end
end

-- The group changing, roles set, a fight starting (it locks, and Drinking
-- goes: the game hides auras in a fight) and ending (Drinking looked for
-- again, the mana read again now it can be).
local EVENTS = {"GROUP_ROSTER_UPDATE", "PLAYER_ROLES_ASSIGNED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED",
    "PLAYER_REGEN_ENABLED"}
local function Watch()
    if watching then return end
    watching = true
    for _, event in ipairs(EVENTS) do pcall(events.RegisterEvent, events, event) end
end
local function OnEvent(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        fighting = true
        if Module.unlocked then Module:SetUnlocked(false) end
        for _, row in ipairs(rows) do
            if row.entry and not row.entry.sample then row.entry.drinking = false; ShowDrink(row) end
        end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        fighting = false
        for _, row in ipairs(rows) do
            if row.entry and not row.entry.sample then
                row.entry.drinking = Drinking(row.entry.unit)
                ShowDrink(row)
                Update(row)
            end
        end
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then fighting = InCombatLockdown() and true or false end
    Queue()
end

-- Its switch, ticks and sliders in /era, all at once.
function Module:Refresh()
    if not events then return end
    if not Enabled() then
        if watching then events:UnregisterAllEvents(); watching = false end
        for _, row in ipairs(rows) do Listen(row, nil); row.entry = nil; row:Hide() end
        roster = {}
        if self.unlocked then
            if dragging then Save() end
            self.unlocked = false
            if self.watch then self.watch(false) end
        end
        if panel then panel:EnableMouse(false); panel:Hide() end
        return
    end
    -- Off (or not yet started), no fight was watched: ask whether you're in one.
    if not watching then fighting = InCombatLockdown() and true or false end
    Watch()
    Build()
    Resize()
    self:Paint()
    self:Rebuild()
end

function Module:Initialize()
    events = CreateFrame("Frame")
    events:SetScript("OnEvent", OnEvent)
    self:Refresh()
end
