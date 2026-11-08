-- Ability Trail (/era > Casting > Ability Trail; Modules/AbilityTrail.lua) on
-- a mock of the game: off by default; on, each cast's icon starts by your
-- frame and glides away the chosen way at Speed pixels a second (not from
-- Show For), fading over the last part of Travel Distance and gone at its
-- end; quick casts never land on top of each other; at most Icons show.
-- Scrolling Icons off: a still row, newest first, an icon apart, each fading
-- over its last second of Show For. A cast with a cast time shows as it
-- starts (pulsing softly), lands without a second icon, or gets the red cross when
-- cancelled. Auto attacks, passives and ignored abilities are left out;
-- right-click ignores, drag moves (Reset puts it back; the icon dragged by
-- going ends the drag). Tooltip (it stays with its icon), Spell ID and Pause
-- On Hover (only a mouse moved onto an icon) on your own. Combat Only (the opener too) and each
-- Show In tick. Party: its own switch, direction, size and count; the game
-- hides a party member's spell and cast (secrets), so the spell goes straight
-- to the texture, never read, named or ignored, on an icon the mouse passes
-- through, beside the frame the game shows them in (none: no trail). Unlock:
-- a labelled box on each trail to drag, party trails kept per slot; Lock,
-- a right-click or a fight hides them; Reset puts every trail back.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- Secrets: a table the code may only hand to the texture.
local SecretMeta = {
    __index = function() error("a secret was indexed") end,
    __concat = function() error("a secret was joined") end,
    __eq = function() error("a secret was compared") end,
    __lt = function() error("a secret was compared") end,
    __le = function() error("a secret was compared") end,
}
local function Secret(value) return setmetatable({secretValue = value}, SecretMeta) end
_G.issecretvalue = function(value) return getmetatable(value) == SecretMeta end

-- Mock frames.
local frames, Proto = {}, {}
local function New(kind, name, parent)
    local f = setmetatable({kind = kind, shown = true, scripts = {}, events = {}, unitEvents = {}, points = {}, parent = parent,
        alpha = 1, mouse = kind == "Button"}, {__index = function(_, k)
        if Proto[k] then return Proto[k] end
        if type(k) == "string" and k:match("^[A-Z]") then return function() end end
    end})
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
function Proto:Show() self.shown = true end
function Proto:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Proto:IsShown() return self.shown end
function Proto:IsVisible()
    local f = self
    while f do if not f.shown then return false end; f = f.parent end
    return true
end
function Proto:SetShown(v) if v then self:Show() else self:Hide() end end
function Proto:SetScript(k, fn) self.scripts[k] = fn end
function Proto:GetScript(k) return self.scripts[k] end
function Proto:RegisterEvent(e) self.events[e] = true end
function Proto:UnregisterEvent(e) self.events[e] = nil end
function Proto:RegisterUnitEvent(e, unit) self.unitEvents[e] = unit end
function Proto:UnregisterAllEvents() self.events, self.unitEvents = {}, {} end
function Proto:SetPoint(...) self.points[#self.points + 1] = {...} end
function Proto:ClearAllPoints() self.points = {} end
function Proto:SetSize(w, h) self.width, self.height = w, h end
function Proto:SetAlpha(a) self.alpha = a end
function Proto:EnableMouse(v) self.mouse = v and true or false end
function Proto:CreateFontString() return New("FontString", nil, self) end
function Proto:CreateTexture() return New("Texture", nil, self) end
function Proto:SetText(t) self.text = t end
function Proto:SetTexture(t) self.texture = t end
function Proto:SetDesaturated(v) self.grey = v and true or false end
function Proto:SetColorTexture(r, g, b) self.colour = string.format("%.2f,%.2f,%.2f", r, g, b) end
function Proto:SetTextColor(r, g, b) self.textColour = string.format("%.2f,%.2f,%.2f", r, g, b) end
function Proto:GetStringHeight() return 30 end
function Proto:StartMoving() self.moving = true end
function Proto:StopMovingOrSizing() self.moving = false end
function Proto:GetLeft() return self.left or 0 end
function Proto:GetTop() return self.top or 0 end
function Proto:GetHeight() return self.height or 768 end
-- The mouse is over a frame while the test says so (frame:IsMouseOver()).
function Proto:IsMouseOver() return self.over == true end

_G.CreateFrame = function(kind, name, parent) return New(kind, name, parent) end
_G.UIParent = New("Frame")
UIParent.height = 768
_G.PlayerFrame = New("Frame")
_G.GameTooltip = nil -- never used: the tooltip is the module's own
local now, fighting, place = 100, false, "none"
_G.GetTime = function() return now end
-- A cast still being cast: its picture pulses between 55% and full.
local function Pulse() return string.format("%.3f", .775 + .225 * math.cos(now * 6)) end
-- The mouse: it moves only when the test moves it (Pause On Hover holds
-- only for a mouse moved onto an icon, not one an icon came to).
local cursorX = 0
_G.GetCursorPosition = function() return cursorX, 300 end
local function MoveMouse() cursorX = cursorX + 5 end
_G.InCombatLockdown = function() return fighting end
_G.UnitAffectingCombat = function() return fighting end
_G.IsInInstance = function() return place ~= "none", place end
local exists = {party1 = true, party2 = true}
_G.UnitExists = function(unit) return exists[unit] == true end
local names = {[100] = "Sinister Strike", [101] = "Eviscerate", [102] = "Kick", [103] = "Sprint", [104] = "Gouge",
    [105] = "Evasion", [106] = "Frostbolt", [107] = "Blink", [6603] = "Auto Attack", [200] = "Sharpened Claws"}
local passives = {[200] = true}
_G.C_Spell = {
    GetSpellTexture = function(id)
        if issecretvalue(id) then return Secret("icon of a hidden spell") end
        return 1000 + id
    end,
    GetSpellName = function(id) return names[id] end,
    IsSpellPassive = function(id) return passives[id] == true end,
}
local printed = {}
local settings, saves

-- The party: the game's party frames (a pool of members, each with its unit).
local members = {}
_G.PartyFrame = {PartyMemberFramePool = {EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return members[i] end
end}}

local function Load()
    frames = {}
    settings, saves = {enabled = true, darkMode = true, abilityTrail = false, abilityTrailParty = false, abilityTrailDirection = "right",
        abilityTrailSize = 36, abilityTrailCount = 5, abilityTrailSeconds = 10, abilityTrailDistance = 200}, 0
    _G.EraUIAbilityTrail = nil
    local E = {modules = {}}
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    function E:GetSetting(key) return settings[key] end
    function E:SetSetting(key, value) settings[key] = value end
    function E:Print(message) printed[#printed + 1] = message end
    function E:SaveSettings() saves = saves + 1 end
    assert(loadfile("Modules/AbilityTrail.lua"))("EraUI", E)
    local trail = E.modules.AbilityTrail
    trail:Initialize()
    return trail
end

-- A cast event for a unit (instant by default: it just lands).
local function Event(unit, event, castGUID, spellID)
    for _, f in ipairs(frames) do
        if f.unitEvents[event] == unit and f.scripts.OnEvent then f.scripts.OnEvent(f, event, unit, castGUID, spellID) end
    end
end
local function Cast(unit, spellID) Event(unit, "UNIT_SPELLCAST_SUCCEEDED", "Cast-" .. tostring(spellID), spellID) end
local function Fire(event)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end
-- Time passes: the trail moves as it would, frame by frame.
local function Pass(seconds, trail)
    now = now + seconds
    if trail.driver and trail.driver.scripts.OnUpdate then trail.driver.scripts.OnUpdate(trail.driver, seconds) end
end
-- The icons showing on a holder, the newest (nearest the start) first.
local function Icons(holder)
    local list = {}
    for _, f in ipairs(frames) do
        if f.kind == "Button" and f.parent == holder and f.shown and f.points[1] and f.points[1][2] == holder then list[#list + 1] = f end
    end
    local function Along(icon) local p = icon.points[1]; return math.abs(p[4]) + math.abs(p[5]) end
    table.sort(list, function(a, b) return Along(a) < Along(b) end)
    return list
end
local function Offsets(holder)
    local out = {}
    for i, icon in ipairs(Icons(holder)) do
        local p = icon.points[1]
        out[i] = string.format("%g", math.abs(p[4]) + math.abs(p[5]))
    end
    return table.concat(out, ",")
end
local function Textures(holder)
    local out = {}
    for i, icon in ipairs(Icons(holder)) do out[i] = tostring(icon.art.texture) end
    return table.concat(out, ",")
end
local function Alphas(holder)
    local out = {}
    for i, icon in ipairs(Icons(holder)) do out[i] = string.format("%.2f", icon.alpha) end
    return table.concat(out, ",")
end
local function Listening()
    local n = 0
    for _, f in ipairs(frames) do
        for _ in pairs(f.events) do n = n + 1 end
        for _ in pairs(f.unitEvents) do n = n + 1 end
    end
    return n
end
local function ClearIcons(trail)
    settings.abilityTrail = false
    trail:Refresh()
    settings.abilityTrail = true
    trail:Refresh()
end

-- Off (the default): nothing listened to, nothing shown.
local trail = Load()
equal(Listening() .. " " .. tostring(EraUIAbilityTrail), "0 nil", "off by default: no events, no trail")

-- On: your cast's icon starts by your frame.
settings.abilityTrail = true
trail:Refresh()
local holder = EraUIAbilityTrail
local anchor = holder.points[1]
equal(anchor[1] .. " " .. tostring(anchor[2] == PlayerFrame) .. " " .. anchor[3], "TOPLEFT true BOTTOMLEFT", "the trail starts under your frame")
equal(trail.casters.player.unitEvents.UNIT_SPELLCAST_START .. " " .. trail.casters.player.unitEvents.UNIT_SPELLCAST_INTERRUPTED,
    "player player", "it listens to your casts starting, landing and being interrupted")
Cast("player", 100)
local icons = Icons(holder)
local p = icons[1].points[1]
equal(#icons .. " " .. icons[1].art.texture .. " " .. icons[1].width .. " " .. icons[1].edge.colour .. " " .. p[1] .. " " .. string.format("%g", p[4]),
    "1 1100 36 0.04,0.04,0.05 LEFT 0", "a cast: its icon, 36 px, at the start of the trail")
equal(tostring(icons[1].mouse) .. " " .. tostring(icons[1].cross.shown) .. " " .. icons[1].alpha, "true false 1",
    "your icons take the mouse, no cross, full")
equal(icons[1].age, nil, "no age label any more")

-- Auto attacks and passives are left out.
Cast("player", 6603)
Cast("player", 200)
equal(Textures(holder), "1100", "auto attack and a passive left out")

-- It glides at Speed: 12 px a second by default, whatever Show For says.
Pass(2, trail)
equal(Offsets(holder), "24", "two seconds on: 24 px along")

-- Three quick casts never land on top of each other: one icon apart.
Cast("player", 100)
Cast("player", 100)
equal(Offsets(holder) .. " " .. Textures(holder), "0,40,80 1100,1100,1100", "three Sinister Strikes: three icons, 40 px apart")

-- They fade over the last part of the trip, then go at the end.
Pass(5, trail)
icons = Icons(holder)
equal(Offsets(holder), "60,100,140", "all moving on together, 60 px in five seconds")
equal(string.format("%.2f %.2f", icons[3].alpha, icons[1].alpha), "0.86 1.00", "the oldest fading near the end; the newest full")
Pass(5.5, trail)
equal(Offsets(holder), "126,166", "the oldest gone at the end of its trip")
Pass(20, trail)
equal(#Icons(holder) .. " " .. tostring(trail.driver.scripts.OnUpdate), "0 nil", "all gone, and the trail stops moving")

-- Speed: slower or faster, within 4 to 60 px a second; Show For doesn't change it.
settings.abilityTrailSpeed = 30
Cast("player", 101)
Pass(1, trail)
equal(Offsets(holder), "30", "Speed 30: 30 px a second")
settings.abilityTrailSpeed, settings.abilityTrailSeconds = 4, 2
ClearIcons(trail)
Cast("player", 101)
Pass(1, trail)
equal(Offsets(holder), "4", "Speed 4: 4 px a second, Show For 2 changes nothing while gliding")
settings.abilityTrailSpeed = 500
Pass(1, trail)
equal(Offsets(holder), "64", "Speed past 60 is 60")
settings.abilityTrailSpeed, settings.abilityTrailSeconds = nil, 10
ClearIcons(trail)

-- Travel Distance: a shorter trip at the same speed, fading over its last part.
settings.abilityTrailDistance = 100
Cast("player", 101)
Pass(8, trail)
equal(Offsets(holder) .. " " .. Alphas(holder), "96 0.11", "100 px trip: 96 px along after 8 s, nearly faded")
Pass(1, trail)
equal(#Icons(holder), 0, "gone at 100 px")
settings.abilityTrailDistance = 200
ClearIcons(trail)

-- At most Icons of them.
settings.abilityTrailCount = 3
for id = 102, 105 do Cast("player", id) end
equal(Textures(holder), "1105,1104,1103", "Icons at 3: only the last three show")
settings.abilityTrailCount = 5
ClearIcons(trail)

-- A cast with a cast time: shows as it starts, pulsing softly, and when it
-- lands it stops pulsing, no second icon. The edge stays the Border's.
Event("player", "UNIT_SPELLCAST_START", "Cast-A", 106)
icons = Icons(holder)
equal(#icons .. " " .. icons[1].art.texture .. " " .. icons[1].edge.colour .. " " .. string.format("%.3f", icons[1].art.alpha),
    "1 1106 0.04,0.04,0.05 " .. Pulse(), "Frostbolt starting: its icon, black edge, pulsing")
Pass(1, trail)
Event("player", "UNIT_SPELLCAST_SUCCEEDED", "Cast-A", 106)
icons = Icons(holder)
equal(#icons .. " " .. icons[1].edge.colour .. " " .. tostring(icons[1].cross.shown) .. " " .. string.format("%.3f", icons[1].art.alpha),
    "1 0.04,0.04,0.05 false 1.000", "it lands: same icon, no longer pulsing")

-- Cancelled or interrupted: grey with the red cross.
Event("player", "UNIT_SPELLCAST_START", "Cast-B", 106)
Event("player", "UNIT_SPELLCAST_INTERRUPTED", "Cast-B", 106)
icons = Icons(holder)
equal(#icons .. " " .. tostring(icons[1].cross.shown) .. " " .. tostring(icons[1].art.grey) .. " " .. icons[1].edge.colour,
    "2 true true 0.04,0.04,0.05", "interrupted: the red cross, grey, the Border's edge")
equal(string.format("%.3f", icons[1].art.alpha), "1.000", "and no longer pulsing")
equal(icons[1].cross.texture, "Interface\\RaidFrame\\ReadyCheck-NotReady", "the cross is the game's red one")
Event("player", "UNIT_SPELLCAST_INTERRUPTED", "Cast-B", 106)
equal(#Icons(holder), 2, "a second interrupt for it adds nothing")

-- An instant one landing while something else is being cast is its own icon.
Event("player", "UNIT_SPELLCAST_START", "Cast-C", 106)
Event("player", "UNIT_SPELLCAST_SUCCEEDED", "Cast-D", 107)
icons = Icons(holder)
equal(Textures(holder), "1107,1106,1106,1106", "Blink mid-cast: a new icon")
equal(string.format("%.3f", icons[2].art.alpha) .. " " .. string.format("%.3f", icons[1].art.alpha), Pulse() .. " 1.000",
    "Frostbolt still pulsing, Blink not")
Event("player", "UNIT_SPELLCAST_SUCCEEDED", "Cast-C", 106)
equal(#Icons(holder) .. " " .. string.format("%.3f", Icons(holder)[2].art.alpha), "4 1.000", "then Frostbolt lands: no new icon, no pulse")
ClearIcons(trail)

-- Border: Match look is black in Dark Mode and silver in the Classic look;
-- Black, Class (your class colour) and Custom (a picked colour) as chosen.
_G.UnitClass = function(unit) if unit == "player" then return "Rogue", "ROGUE" end return "Mage", "MAGE" end
_G.RAID_CLASS_COLORS = {ROGUE = {r = 1, g = .96, b = .41}, MAGE = {r = .25, g = .78, b = .92}}
Cast("player", 100)
local function Edge() return Icons(holder)[1].edge.colour end
equal(Edge(), "0.04,0.04,0.05", "Match look in Dark Mode: black")
settings.darkMode = false
Pass(0, trail)
equal(Edge(), "0.62,0.62,0.66", "Match look in the Classic look: silver")
settings.abilityTrailBorder = "black"
Pass(0, trail)
equal(Edge(), "0.04,0.04,0.05", "Black: black in either look")
settings.abilityTrailBorder = "class"
Pass(0, trail)
equal(Edge(), "1.00,0.96,0.41", "Class: your class colour")
settings.abilityTrailBorder, settings.abilityTrailBorderColour = "custom", "FF0000"
Pass(0, trail)
equal(Edge(), "1.00,0.00,0.00", "Custom: the colour picked")
settings.abilityTrailBorderColour = "nonsense"
Pass(0, trail)
equal(Edge(), "0.62,0.62,0.66", "Custom without a good colour: silver")
settings.abilityTrailBorder = "something else"
Pass(0, trail)
equal(Edge(), "0.62,0.62,0.66", "an unknown choice: Match look")
_G.UnitClass = function() return Secret("class"), Secret("file") end
settings.abilityTrailBorder = "class"
Pass(0, trail)
equal(Edge(), "0.04,0.04,0.05", "Class while the game hides it: black")
settings.abilityTrailBorder, settings.darkMode, settings.abilityTrailBorderColour = nil, true, nil
_G.UnitClass = nil
ClearIcons(trail)

-- The direction and the size follow the options.
settings.abilityTrailDirection, settings.abilityTrailSize = "up", 48
Cast("player", 100)
Cast("player", 101)
icons = Icons(holder)
local second = icons[2].points[1]
equal(second[1] .. " " .. tostring(second[2] == holder) .. string.format(" %g %g ", second[4], second[5]) .. icons[1].width .. " " .. icons[2].width,
    "BOTTOM true 0 52 48 48", "Up: the older one 52 px above the start; Icon Size 48 for all")
settings.abilityTrailDirection, settings.abilityTrailSize = "right", 36
ClearIcons(trail)

-- Scrolling Icons off: a still row, newest at the start, older ones an icon
-- apart, each staying Show For and fading over its last second.
settings.abilityTrailScroll = false
Cast("player", 100)
Pass(3, trail)
Cast("player", 101)
Pass(3, trail)
Cast("player", 102)
equal(Offsets(holder) .. " " .. Textures(holder) .. " " .. Alphas(holder), "0,40,80 1102,1101,1100 1.00,1.00,1.00",
    "still: newest at the start, older ones 40 px apart, full")
Pass(3.5, trail)
equal(Offsets(holder) .. " " .. Alphas(holder), "0,40,80 1.00,1.00,0.50", "they don't move; the oldest in its last second fades")
Pass(0.6, trail)
equal(Offsets(holder) .. " " .. Textures(holder), "0,40 1102,1101", "after Show For (10 s) it's gone and the row closes up")
settings.abilityTrailSeconds = 6
Pass(1, trail)
equal(Textures(holder), "1102", "Show For 6: the one 8 s old goes, the one 5 s old stays")
Pass(4, trail)
equal(#Icons(holder) .. " " .. tostring(trail.driver.scripts.OnUpdate), "0 nil", "all gone, and the trail stops")
settings.abilityTrailSeconds = 10
settings.abilityTrailCount = 2
for id = 102, 104 do Cast("player", id) end
equal(Textures(holder), "1104,1103", "still, Icons 2: the last two")
settings.abilityTrailCount, settings.abilityTrailScroll = 5, true
ClearIcons(trail)

-- Right-click ignores that ability: off the trail now and later, said in chat.
Cast("player", 100)
Cast("player", 101)
icons = Icons(holder)
icons[1].scripts.OnClick(icons[1], "RightButton")
equal(Textures(holder) .. " " .. tostring(settings.abilityTrailIgnore["101"]) .. " " .. saves, "1100 Eviscerate 1",
    "right-click: Eviscerate off the trail, on the ignore list, saved")
equal(printed[#printed]:find("Eviscerate is ignored", 1, true) ~= nil, true, "and said in chat")
Cast("player", 101)
equal(Textures(holder) .. " " .. trail:IgnoredCount(), "1100 1", "ignored: it doesn't come back")
trail:ClearIgnored()
Cast("player", 101)
equal(Textures(holder) .. " " .. trail:IgnoredCount(), "1101,1100 0", "Clear: it shows again")

-- Tooltip (on by default): the module's own, naming it; no spell ID unless chosen.
icons = Icons(holder)
icons[1].scripts.OnEnter(icons[1])
local tip = trail.tip
equal(tostring(tip and tip.shown) .. " " .. tostring(tip.text.text:find("Eviscerate", 1, true) ~= nil) .. " " .. tostring(tip.text.text:find("Spell ID", 1, true)),
    "true true nil", "hover: its own tooltip, with the name, no spell ID")
icons[1].scripts.OnLeave(icons[1])
equal(tip.shown, false, "leaving hides it")
settings.abilityTrailSpellID = true
icons[1].scripts.OnEnter(icons[1])
equal(tip.text.text:find("Spell ID: 101", 1, true) ~= nil, true, "Spell ID on: the ID line")
icons[1].scripts.OnLeave(icons[1])
settings.abilityTrailSpellID, settings.abilityTrailTooltip = nil, false
icons[1].scripts.OnEnter(icons[1])
equal(tip.shown, false, "Tooltip off: no tooltip")
icons[1].scripts.OnLeave(icons[1])
settings.abilityTrailTooltip = nil

-- Pause On Hover (on by default): while the mouse is over one of your icons
-- your trail stops moving, and carries on when it leaves.
equal(Offsets(holder), "0,40", "two icons at the start")
icons = Icons(holder)
icons[2].over = true
MoveMouse()
icons[2].scripts.OnEnter(icons[2])
Pass(3, trail)
equal(Offsets(holder), "0,40", "the mouse on one: the trail holds still")
Cast("player", 102)
equal(Offsets(holder), "0,40,80", "a new cast still pushes them on")
icons[2].over = false
icons[2].scripts.OnLeave(icons[2])
Pass(1, trail)
equal(Offsets(holder), "12,52,92", "the mouse gone: it glides on")
-- The mouse moved off without a leave (the icon went): it goes on all the same.
icons = Icons(holder)
icons[1].scripts.OnEnter(icons[1])
Pass(1, trail)
equal(Offsets(holder), "24,64,104", "no mouse over it any more: no hold")
-- Still icons don't fade while held.
settings.abilityTrailScroll = false
ClearIcons(trail)
Cast("player", 100)
icons = Icons(holder)
icons[1].over = true
MoveMouse()
icons[1].scripts.OnEnter(icons[1])
Pass(20, trail)
equal(#Icons(holder) .. " " .. Alphas(holder), "1 1.00", "still and held: no older, no fading")
icons[1].over = false
icons[1].scripts.OnLeave(icons[1])
Pass(10, trail)
equal(#Icons(holder), 0, "let go: gone after Show For")
-- Pause On Hover off: hovering holds nothing.
settings.abilityTrailScroll, settings.abilityTrailPauseOnHover = true, false
Cast("player", 100)
icons = Icons(holder)
icons[1].over = true
MoveMouse()
icons[1].scripts.OnEnter(icons[1])
Pass(1, trail)
equal(Offsets(holder), "12", "Pause On Hover off: it glides on under the mouse")
icons[1].over = false
icons[1].scripts.OnLeave(icons[1])
settings.abilityTrailPauseOnHover = nil
ClearIcons(trail)
-- An icon that comes to a mouse left still (one shows, or glides, where it
-- sits) doesn't hold the trail: it ages and fades all the same, until the
-- mouse moves on it.
settings.abilityTrailScroll = false
Pass(1, trail)
Cast("player", 100)
icons = Icons(holder)
icons[1].over = true
icons[1].scripts.OnEnter(icons[1])
Pass(9.5, trail)
equal(Alphas(holder), "0.50", "still: an icon showing under a still mouse ages and fades")
MoveMouse()
Pass(5, trail)
equal(Alphas(holder), "0.50", "the mouse moves on it: now it holds")
icons[1].over = false
icons[1].scripts.OnLeave(icons[1])
Pass(1, trail)
equal(#Icons(holder), 0, "let go: gone")
settings.abilityTrailScroll = nil
Cast("player", 100)
Pass(2, trail)
icons = Icons(holder)
icons[1].over = true
icons[1].scripts.OnEnter(icons[1])
Pass(1, trail)
equal(Offsets(holder), "36", "gliding under a still mouse: it carries on")
MoveMouse()
Pass(1, trail)
equal(Offsets(holder), "36", "the mouse moves on it: it holds")
icons[1].over = false
icons[1].scripts.OnLeave(icons[1])
ClearIcons(trail)
-- The tooltip stays with its icon: another icon going leaves it be, and a
-- new ability on the icon under the mouse renames it (a right-click then
-- ignores the one it names).
settings.abilityTrailPauseOnHover = false
Cast("player", 100)
Pass(5, trail)
Cast("player", 101)
icons = Icons(holder)
icons[1].over = true
MoveMouse()
icons[1].scripts.OnEnter(icons[1])
equal(tostring(tip.shown) .. " " .. tostring(tip.text.text:find("Eviscerate", 1, true) ~= nil), "true true", "on the newest: it names Eviscerate")
Pass(12, trail)
equal(#Icons(holder) .. " " .. tostring(tip.shown), "1 true", "the oldest going: the tooltip stays on the icon you're on")
Cast("player", 102)
equal(tostring(tip.shown) .. " " .. tostring(tip.text.text:find("Kick", 1, true) ~= nil) .. " " .. tostring(tip.owner == icons[1]), "true true true",
    "Kick lands on the icon under the mouse: the tooltip names Kick")
icons[1].scripts.OnClick(icons[1], "RightButton")
equal(tostring(settings.abilityTrailIgnore["102"]) .. " " .. tostring(settings.abilityTrailIgnore["101"]), "Kick nil",
    "a right-click ignores the one the tooltip names")
trail:ClearIgnored()
icons[1].over = false
icons[1].scripts.OnLeave(icons[1])
settings.abilityTrailPauseOnHover = nil
ClearIcons(trail)

-- Combat Only: out of a fight no new icons; in one they show; ones already
-- showing finish their trip after it.
settings.abilityTrailCombatOnly = true
Cast("player", 100)
Pass(3, trail)
equal(#Icons(holder), 0, "Combat Only, out of a fight: no icon")
fighting = true
Cast("player", 101)
equal(Textures(holder), "1101", "in a fight: it shows")
fighting = false
Pass(1, trail)
Cast("player", 102)
equal(Offsets(holder) .. " " .. Textures(holder), "12 1101", "the fight over: it carries on, nothing new")
-- The cast that starts a fight (cast just before the game says so) shows.
Cast("player", 103)
Pass(1, trail)
fighting = true
Fire("PLAYER_REGEN_DISABLED")
equal(Textures(holder), "1103,1101", "the opener shows once the fight starts")
fighting = false
Cast("player", 104)
Pass(2, trail)
fighting = true
Fire("PLAYER_REGEN_DISABLED")
equal(Textures(holder), "1103,1101", "but not a cast from well before it")
fighting = false
settings.abilityTrailCombatOnly = nil
ClearIcons(trail)

-- Show In: each place has its tick (IsInInstance's kind); unticked, no new icons there.
for _, case in ipairs({{"none", "abilityTrailInWorld"}, {"party", "abilityTrailInDungeons"}, {"scenario", "abilityTrailInDungeons"},
    {"raid", "abilityTrailInRaids"}, {"pvp", "abilityTrailInBattlegrounds"}, {"arena", "abilityTrailInBattlegrounds"}}) do
    place = case[1]
    settings[case[2]] = false
    Cast("player", 100)
    equal(#Icons(holder), 0, case[2] .. " off: no icons in " .. case[1])
    settings[case[2]] = true
    Cast("player", 100)
    equal(#Icons(holder), 1, case[2] .. " on: icons in " .. case[1])
    settings[case[2]] = nil
    ClearIcons(trail)
end
place = "none"

-- Drag: kept where you let go; Reset puts it back under your frame.
Cast("player", 100)
icons = Icons(holder)
holder.left, holder.top = 300, 500
icons[1].scripts.OnDragStart(icons[1])
equal(holder.moving, true, "dragging an icon moves the trail")
icons[1].scripts.OnDragStop(icons[1])
anchor = holder.points[1]
equal(settings.abilityTrailPosition.x .. "," .. settings.abilityTrailPosition.y .. " " .. anchor[1] .. " " .. tostring(anchor[2] == UIParent)
    .. " " .. anchor[4] .. " " .. anchor[5], "300,-268 TOPLEFT true 300 -268", "let go: kept, and put there")
trail:ResetPosition()
anchor = holder.points[1]
equal(tostring(settings.abilityTrailPosition) .. " " .. tostring(anchor[2] == PlayerFrame), "nil true", "Reset: back under your frame")
-- The icon you drag by gone mid-drag (its trip over): the drag ends, kept where it is.
Cast("player", 100)
icons = Icons(holder)
holder.left, holder.top = 320, 520
icons[1].scripts.OnDragStart(icons[1])
Pass(20, trail)
equal(tostring(holder.moving) .. " " .. tostring(trail.dragging) .. " " .. tostring(settings.abilityTrailPosition and settings.abilityTrailPosition.x),
    "false nil 320", "the icon you drag by gone: the drag ends, kept where it is")
trail:ResetPosition()

-- Party off: nothing listens to the party.
equal(tostring(trail.casters.party1), "nil", "party off: no party listener")
Cast("party1", Secret(102))
equal(trail.lastError, nil, "and a party cast does nothing")

-- On: a party member's hidden spell goes straight to the texture, beside
-- their frame, at the party's own size (29 px by default), the mouse passing through.
members[1] = New("Frame")
members[1].unit = "party1"
settings.abilityTrailParty = true
trail:Refresh()
Event("party1", "UNIT_SPELLCAST_SUCCEEDED", Secret("cast"), Secret(102))
local partyHolder
for _, f in ipairs(frames) do
    if f.kind == "Frame" and f.points[1] and f.points[1][2] == members[1] then partyHolder = f end
end
equal(partyHolder ~= nil and partyHolder.points[1][1] .. " " .. partyHolder.points[1][3], "LEFT RIGHT", "the party trail starts at the right of their frame")
icons = Icons(partyHolder)
equal(#icons .. " " .. tostring(issecretvalue(icons[1].art.texture)) .. " " .. icons[1].width .. " " .. tostring(icons[1].mouse),
    "1 true 29 false", "a hidden spell: its icon handed over unread, 29 px, no mouse")
equal(tostring(icons[1].entry.name) .. " " .. tostring(icons[1].entry.id) .. " " .. tostring(icons[1].entry.guid), "nil nil nil",
    "no name, ID or cast read from it")
-- Party trails glide at the same Speed over the same Travel Distance.
Pass(1, trail)
equal(Offsets(partyHolder), "12", "a party trail moves 12 px a second too")
-- Their hidden cast with a cast time: starts pulsing, lands without a second
-- icon; another one interrupted gets the cross.
Event("party1", "UNIT_SPELLCAST_START", Secret("cast 2"), Secret(106))
equal(#Icons(partyHolder) .. " " .. string.format("%.3f", Icons(partyHolder)[1].art.alpha), "2 " .. Pulse(), "their cast starting: pulsing")
Event("party1", "UNIT_SPELLCAST_SUCCEEDED", Secret("cast 2"), Secret(106))
equal(#Icons(partyHolder) .. " " .. string.format("%.3f", Icons(partyHolder)[1].art.alpha), "2 1.000", "it lands: no second icon, no pulse")
Event("party1", "UNIT_SPELLCAST_START", Secret("cast 3"), Secret(106))
Event("party1", "UNIT_SPELLCAST_INTERRUPTED", Secret("cast 3"), Secret(106))
equal(#Icons(partyHolder) .. " " .. tostring(Icons(partyHolder)[1].cross.shown), "3 true", "interrupted: the cross")
equal(trail.lastError, nil, "nothing went wrong with their hidden casts")
-- A party spell the game doesn't hide is treated like yours (auto attack out).
Cast("party1", 6603)
equal(#Icons(partyHolder), 3, "a plain auto attack from a party member left out")
-- Party's own Icons, Icon Size and Direction (not yours).
settings.abilityTrailPartyCount, settings.abilityTrailPartySize, settings.abilityTrailPartyDirection = 2, 40, "left"
trail:Refresh()
icons = Icons(partyHolder)
equal(#icons .. " " .. icons[1].width .. " " .. partyHolder.points[1][1] .. " " .. partyHolder.points[1][3] .. " " .. icons[1].points[1][1],
    "2 40 RIGHT LEFT RIGHT", "party Icons 2, Icon Size 40, Left: at the left of their frame")
Cast("player", 100)
equal(Icons(holder)[1].width .. " " .. Icons(holder)[1].points[1][1], "36 LEFT", "your trail keeps its own")
settings.abilityTrailPartyCount, settings.abilityTrailPartySize, settings.abilityTrailPartyDirection = nil, nil, nil
trail:Refresh()
-- The shared rules count for party trails too: Show In.
settings.abilityTrailInWorld = false
Event("party1", "UNIT_SPELLCAST_SUCCEEDED", Secret("cast 4"), Secret(103))
equal(#Icons(partyHolder), 2, "World off: no new party icon either")
settings.abilityTrailInWorld = nil

-- No frame showing a party member (a raid, another addon's frames): no trail.
Cast("party2", Secret(103))
local orphan
for _, f in ipairs(frames) do
    if f.kind == "Frame" and f ~= partyHolder and f ~= holder and f.points[1] and f.points[1][2] == UIParent and f.points[1][1] == "CENTER" then orphan = f end
end
equal(orphan ~= nil and orphan.shown, false, "party2 without a frame: its trail hidden, not in the middle of the screen")

-- Unlock: a labelled box on each trail that's on, its icons' length, to drag by.
local function Boxes()
    local out = {}
    for _, f in ipairs(frames) do
        if f.kind == "Frame" and f.label and f.shown and f.parent and f.parent.shown then out[#out + 1] = f.label.text end
    end
    table.sort(out)
    return table.concat(out, ",")
end
local function BoxOf(h)
    for _, f in ipairs(frames) do if f.label and f.parent == h then return f end end
end
local watched
trail.watch = function(on) watched = on end
equal(trail:SetUnlocked(true) and Boxes() .. " " .. tostring(watched), "Party 1,Party 2,Party 3,Party 4,You true", "Unlock: a box for you and each party slot")
local box = BoxOf(holder)
equal(box.width .. "x" .. box.height .. " " .. box.points[1][1] .. " " .. tostring(box.mouse), "236x36 LEFT true",
    "your box: Travel Distance and an icon long, an icon tall, from the start, takes the mouse")
equal(orphan.shown and orphan.points[1][2] == UIParent, true, "party2 without a frame: shown in a spot of its own to move")
-- Dragging party1's box: kept for that slot, put there.
local partyBox = BoxOf(partyHolder)
partyHolder.left, partyHolder.top = 500, 400
partyBox.scripts.OnDragStart(partyBox)
equal(partyHolder.moving, true, "dragging a box moves its trail")
partyBox.scripts.OnDragStop(partyBox)
local kept = settings.abilityTrailPartyPositions
equal(type(kept) == "table" and kept[1] and kept[1].x .. "," .. kept[1].y .. " " .. tostring(kept[2]), "500,-368 nil", "party1's spot kept by its slot")
equal(partyHolder.points[1][1] .. " " .. tostring(partyHolder.points[1][2] == UIParent), "TOPLEFT true", "and put there, off its frame")
-- Still icons: the box is Icons long.
settings.abilityTrailScroll = false
trail:SetUnlocked(true)
equal(box.width, 196, "still: five icons long")
settings.abilityTrailScroll = nil
-- Lock: the boxes go; party2 (no frame, never moved) hides again; party1 stays where it was put.
trail:SetUnlocked(false)
equal(Boxes() .. " " .. tostring(watched) .. " " .. tostring(orphan.shown) .. " " .. tostring(partyHolder.points[1][2] == UIParent), " false false true",
    "Lock: no boxes, party2 hidden again, party1 kept")
-- A right-click on a box locks too; so does a fight starting.
trail:SetUnlocked(true)
box.scripts.OnMouseUp(box, "RightButton")
equal(Boxes(), "", "right-click a box: locked")
trail:SetUnlocked(true)
fighting = true
Fire("PLAYER_REGEN_DISABLED")
fighting = false
equal(Boxes() .. " " .. tostring(trail.unlocked), " false", "a fight starting: locked")
-- A fight starting mid-drag: the drag ends, kept where it is, then locked.
trail:SetUnlocked(true)
holder.left, holder.top = 250, 450
box.scripts.OnDragStart(box)
equal(holder.moving, true, "dragging your box")
fighting = true
Fire("PLAYER_REGEN_DISABLED")
fighting = false
equal(tostring(holder.moving) .. " " .. tostring(trail.dragging) .. " " .. settings.abilityTrailPosition.x .. "," .. settings.abilityTrailPosition.y
    .. " " .. Boxes(), "false nil 250,-318 ", "a fight mid-drag: the drag ends, kept where it was, locked")
-- Reset Positions: every trail back where it starts.
holder.left, holder.top = 100, 600
trail:StartDrag("player"); trail:StopDrag("player")
trail:ResetPosition()
equal(tostring(settings.abilityTrailPosition) .. " " .. tostring(settings.abilityTrailPartyPositions) .. " " .. tostring(holder.points[1][2] == PlayerFrame)
    .. " " .. tostring(partyHolder.points[1][2] == members[1]), "nil nil true true", "Reset: yours under your frame, party1 at its frame")

-- They leave the group: their trail clears.
exists.party1 = nil
Fire("GROUP_ROSTER_UPDATE")
equal(#Icons(partyHolder), 0, "party1 left: their icons go")
exists.party1 = true

-- Party trails have their own switch: on with yours off.
settings.abilityTrail = false
trail:Refresh()
Event("party1", "UNIT_SPELLCAST_SUCCEEDED", Secret("cast 5"), Secret(102))
equal(#Icons(partyHolder) .. " " .. #Icons(holder) .. " " .. tostring(trail.casters.player.unitEvents.UNIT_SPELLCAST_START),
    "1 0 nil", "your trail off, party on: their icons show, yours aren't listened to")
equal(trail:SetUnlocked(true) and Boxes(), "Party 1,Party 2,Party 3,Party 4", "Unlock: only the trails that are on")
trail:SetUnlocked(false)

-- Switched off: everything stops and clears.
settings.abilityTrailParty = false
trail:Refresh()
equal(#Icons(holder) .. " " .. #Icons(partyHolder) .. " " .. Listening(), "0 0 0", "both off: icons gone, nothing listened to")
Cast("player", 100)
equal(#Icons(holder), 0, "and casts show nothing")
equal(tostring(trail:SetUnlocked(true)) .. " " .. Boxes(), "false ", "nothing to unlock with both off")

-- A spell cast by an item (a potion, a trinket): the item's icon, not the
-- spell's blank one; remembered after the last of the stack is drunk.
do
    local bag = {[1] = {itemID = 929, iconFileID = 134831}}
    local itemSpells = {[929] = {"Healing Potion", 441}, [11815] = {"Hand of Justice", 15600}}
    _G.NUM_BAG_SLOTS = 4
    _G.C_Container = {
        GetContainerNumSlots = function(b) return b == 0 and 16 or 0 end,
        GetContainerItemInfo = function(b, slot) return b == 0 and bag[slot] or nil end,
    }
    _G.C_Item = {GetItemSpell = function(id) local s = itemSpells[id]; if s then return s[1], s[2] end end}
    _G.GetInventoryItemID = function(_, slot) return slot == 13 and 11815 or nil end
    _G.GetInventoryItemTexture = function(_, slot) return slot == 13 and 133441 or nil end
    names[441], names[15600] = "Healing Potion", "Hand of Justice"
    local t = Load()
    settings.abilityTrail = true
    t:Refresh()
    local h = EraUIAbilityTrail
    Cast("player", 441)
    Cast("player", 15600)
    Cast("player", 100)
    equal(Textures(h), "1100,133441,134831", "a potion and a trinket show their item's icon; a spell keeps its own")
    bag[1] = nil
    Fire("BAG_UPDATE_DELAYED")
    Cast("player", 441)
    equal(Textures(h):match("^[^,]+"), "134831", "the last potion drunk (gone from the bags): still its icon")
    _G.C_Container, _G.C_Item, _G.GetInventoryItemID, _G.GetInventoryItemTexture = nil, nil, nil, nil
end

io.write("Ability Trail checks passed: " .. checks .. " assertions.\n")
