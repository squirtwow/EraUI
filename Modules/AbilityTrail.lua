local _, EraUI = ...

-- Ability Trail (/era > Casting > Ability Trail; off by default). Two trails,
-- each with its own switch, direction, icon size and number of icons: yours,
-- by your frame, and your party's, beside each member's frame. With
-- Scrolling Icons (on by default) each ability you use shows as an icon at
-- the start of the trail, then glides away at Speed pixels a second and
-- slowly fades out near the end of Travel Distance; a quick next cast never
-- lands on top of the last one, the trail is nudged along to make room. Off,
-- the icons stay in a still row, newest at the start and older ones an icon
-- apart, each fading out over its last second of Show For. A cast with a cast
-- time shows as it starts, pulsing softly while it's being cast; cancelled
-- or interrupted, it turns grey with a red cross. Border is the icons' edge:
-- Match look (black in Dark Mode, silver in the Classic look), black, the
-- trail's class colour (each party member's own) or a colour picked. Combat Only adds icons only
-- in a fight (the cast that starts one too); Show In leaves out the world,
-- dungeons, raids or battlegrounds. Unlock shows a labelled box on each trail
-- to drag it (kept for the account, party trails per slot; one never moved
-- stays by its party frame); Reset puts them all back. Right-click one of
-- your icons to ignore that ability (kept for the account; /era clears the
-- list). Hovering one of yours names it (Tooltip, with its Spell ID if
-- chosen) and, once the mouse moves onto it, holds your trail still (Pause
-- On Hover; icons coming to a mouse left still never hold it).
-- On Forever the game hides which spell a party member cast (a secret value,
-- UNIT_SPELLCAST_SUCCEEDED's SecretWhenUnitSpellCastRestricted): their spell
-- can't be read, matched or named, only handed to C_Spell.GetSpellTexture
-- and Texture:SetTexture, which both take secrets. So party icons show as
-- they come, with no name, no ignore list and no mouse (clicks go through
-- to the world). Your own casts are never secret: auto attacks, passives and
-- ignored abilities are left out, and hovering one names it.
-- Nothing of the game's is hooked or written on: its party and player frames
-- are only read (their unit and place) and anchored to; the tooltip is
-- EraUI's own frame.
local Trail = {}
EraUI:RegisterModule("AbilityTrail", Trail)

local MAX = 10          -- the most icons a trail can hold
local GAP = 4           -- pixels kept between icons
local FADE_PART = .35   -- the last part of the trip, where a gliding icon fades out
local HELD = 1.5        -- seconds a cast out of a fight waits for the fight it may start (Combat Only)
local MOVED = .25       -- seconds the mouse counts as just moved (Pause On Hover)
local EDGE = {.04, .04, .05}     -- black, like the game's buttons
local SILVER = {.62, .62, .66}   -- Match look in the Classic look
local BORDERS = {auto = true, black = true, class = true, custom = true}
local WHITE = "Interface\\Buttons\\WHITE8X8"
local CROSS = "Interface\\RaidFrame\\ReadyCheck-NotReady"
local PARTY_UNITS = {"party1", "party2", "party3", "party4"}
local SLOT = {party1 = 1, party2 = 2, party3 = 3, party4 = 4}
local NAMES = {player = "You", party1 = "Party 1", party2 = "Party 2", party3 = "Party 3", party4 = "Party 4"}
local EVENTS = {"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED"}
-- Auto Attack, Auto Shot and Shoot: the white swings, never news.
local SKIP = {[6603] = true, [75] = true, [5019] = true}
-- Where each direction starts from the anchor, and which way icons travel.
local DIRECTIONS = {
    right = {"LEFT", "RIGHT", 1, 0}, left = {"RIGHT", "LEFT", -1, 0},
    up = {"BOTTOM", "TOP", 0, 1}, down = {"TOP", "BOTTOM", 0, -1},
}
-- Show In: the tick for each kind of place IsInInstance names. Any other
-- (or none read) counts as the world.
local PLACES = {none = "abilityTrailInWorld", party = "abilityTrailInDungeons", scenario = "abilityTrailInDungeons",
    raid = "abilityTrailInRaids", pvp = "abilityTrailInBattlegrounds", arena = "abilityTrailInBattlegrounds"}

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

local function Number(key, low, high, default)
    local value = tonumber(EraUI:GetSetting(key))
    if not value or value ~= value then return default end
    return math.max(low, math.min(high, math.floor(value + .5)))
end

local function Way(key)
    local value = EraUI:GetSetting(key)
    return DIRECTIONS[value] and value or "right"
end

-- A tick that may not be saved yet: its default then.
local function Ticked(key, default)
    local value = EraUI:GetSetting(key)
    if value == nil then return default end
    return value == true
end

-- The options as they are now: each trail's own (you, party) and the shared ones.
function Trail:Options()
    return {
        you = {direction = Way("abilityTrailDirection"), size = Number("abilityTrailSize", 20, 64, 36),
            count = Number("abilityTrailCount", 1, MAX, 5)},
        party = {direction = Way("abilityTrailPartyDirection"), size = Number("abilityTrailPartySize", 20, 64, 29),
            count = Number("abilityTrailPartyCount", 1, MAX, 5)},
        scroll = Ticked("abilityTrailScroll", true),
        speed = Number("abilityTrailSpeed", 4, 60, 12),
        distance = Number("abilityTrailDistance", 50, 600, 200),
        seconds = Number("abilityTrailSeconds", 2, 30, 10),
        combatOnly = Ticked("abilityTrailCombatOnly", false),
        tooltip = Ticked("abilityTrailTooltip", true),
        pause = Ticked("abilityTrailPauseOnHover", true),
        spellID = Ticked("abilityTrailSpellID", false),
        border = BORDERS[EraUI:GetSetting("abilityTrailBorder")] and EraUI:GetSetting("abilityTrailBorder") or "auto",
        borderColour = EraUI:GetSetting("abilityTrailBorderColour"),
    }
end

local function HexColour(hex)
    if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x$") then return nil end
    return {tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255}
end

-- A unit's class colour, or nil while the game keeps it hidden.
local function ClassColour(unit)
    local fine, _, file = pcall(UnitClass, unit)
    if not fine or not Public(file) or type(file) ~= "string" then return nil end
    local get = C_ClassColor and C_ClassColor.GetClassColor
    local colour = (get and get(file)) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[file])
    if not colour then return nil end
    return {colour.r, colour.g, colour.b}
end

-- The edge a trail's icons get now.
function Trail:EdgeColour(trail, options)
    local border = options.border
    if border == "class" then return ClassColour(trail.unit) or EDGE end
    if border == "custom" then return HexColour(options.borderColour) or SILVER end
    if border == "black" then return EDGE end
    return EraUI:GetSetting("darkMode") == true and EDGE or SILVER
end

function Trail:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("abilityTrail") == true
end

-- Party trails have their own switch: they show with or without yours.
function Trail:PartyOn()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("abilityTrailParty") == true
end

-- The ignore list: spell ID (as text) to its name, kept for the account.
function Trail:Ignored()
    local list = EraUI:GetSetting("abilityTrailIgnore")
    if type(list) ~= "table" then return {} end
    return list
end

function Trail:IgnoredCount()
    local n = 0
    for _ in pairs(self:Ignored()) do n = n + 1 end
    return n
end

local function SpellName(id)
    local get = C_Spell and C_Spell.GetSpellName
    local ok, name = pcall(get or function() end, id)
    if ok and Public(name) and type(name) == "string" and name ~= "" then return name end
end

-- Your items' icons by the spell they cast when used (a potion's, a
-- trinket's, the Hearthstone's): such a spell often has no icon of its own,
-- so the game would show its blank one. Learned from your bags and what you
-- wear, looked over again after they change (stale), and never forgotten in a
-- session, so the last potion of a stack still finds its icon once it's gone.
local itemIcons, itemsStale = {}, true

local function Read(get, ...)
    if type(get) ~= "function" then return nil end
    local ok, a, b = pcall(get, ...)
    if ok and Public(a) and Public(b) then return a, b end
end

local function Learn(itemID, icon)
    if type(itemID) ~= "number" or icon == nil then return end
    local _, spellID = Read(C_Item and C_Item.GetItemSpell or GetItemSpell, itemID)
    if type(spellID) == "number" then itemIcons[spellID] = icon end
end

local function LookOverItems()
    itemsStale = false
    local box = C_Container
    if box then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            local slots = Read(box.GetContainerNumSlots, bag)
            for slot = 1, type(slots) == "number" and slots or 0 do
                local info = Read(box.GetContainerItemInfo, bag, slot)
                if type(info) == "table" then Learn(info.itemID, info.iconFileID) end
            end
        end
    end
    for slot = 1, 19 do
        Learn(Read(GetInventoryItemID, "player", slot), Read(GetInventoryItemTexture, "player", slot))
    end
end

function Trail:ItemIcon(spellID)
    if type(spellID) ~= "number" then return nil end
    if itemsStale then LookOverItems() end
    return itemIcons[spellID]
end
function Trail:ItemsChanged() itemsStale = true end

-- One of your own casts worth showing: not an auto attack, a passive or
-- one you ignored.
function Trail:Wanted(id)
    if type(id) ~= "number" or SKIP[id] then return false end
    if self:Ignored()[tostring(id)] then return false end
    local passive = C_Spell and C_Spell.IsSpellPassive
    if passive then
        local ok, yes = pcall(passive, id)
        if ok and Public(yes) and yes then return false end
    end
    return true
end

-- Show In: whether new icons show where you are now.
function Trail:Here()
    local kind = "none"
    if IsInInstance then
        local ok, _, where = pcall(IsInInstance)
        if ok and Public(where) and type(where) == "string" and PLACES[where] then kind = where end
    end
    return EraUI:GetSetting(PLACES[kind]) ~= false
end

-- In a fight (Combat Only): the game's lockdown, or the player in combat.
local function InFight()
    if InCombatLockdown and InCombatLockdown() then return true end
    if UnitAffectingCombat then
        local ok, yes = pcall(UnitAffectingCombat, "player")
        if ok and Public(yes) and yes then return true end
    end
    return false
end

-- The tooltip: EraUI's own, in the game's tooltip look. Its name, the spell
-- ID when chosen, and what a click does.
local function ShowTip(button, options)
    local entry = button.entry
    if not entry then return end
    local tip = Trail.tip
    if not tip then
        tip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        tip:SetFrameStrata("TOOLTIP")
        tip:SetBackdrop({bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16, insets = {left = 4, right = 4, top = 4, bottom = 4}})
        tip:SetBackdropColor(0, 0, 0, .9)
        tip.text = tip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tip.text:SetPoint("TOPLEFT", 10, -10)
        tip.text:SetWidth(200)
        tip.text:SetJustifyH("LEFT")
        Trail.tip = tip
    end
    local lines = {"|cffffd200" .. (entry.name or "?") .. "|r"}
    if options.spellID and type(entry.id) == "number" then lines[#lines + 1] = "|cffb4b4b4Spell ID: " .. entry.id .. "|r" end
    lines[#lines + 1] = "|cff99ccffRight-click to ignore it. Drag to move the trail.|r"
    tip.text:SetText(table.concat(lines, "\n"))
    tip:SetSize(220, (tip.text:GetStringHeight() or 30) + 20)
    tip:ClearAllPoints()
    tip:SetPoint("BOTTOMLEFT", button, "TOPRIGHT", 4, 4)
    -- The icon it's on and what that showed: another icon going leaves it
    -- be, and a new ability on this icon renames it (Trail:Draw).
    tip.owner, tip.entry = button, entry
    tip:Show()
end

-- Hides the tooltip: any (owner nil), or only while it's on that icon.
local function HideTip(owner)
    local tip = Trail.tip
    if not tip or (owner and tip.owner ~= owner) then return end
    tip:Hide()
    tip.owner, tip.entry = nil, nil
end

-- A trail: its holder (where it starts), its icons and what they show.
local trails = {}

-- Whether the mouse moved in the last moment. An icon gliding (or showing)
-- under a mouse left still gets the mouse too, but only a mouse moved onto
-- one holds the trail (Pause On Hover). Read each frame while icons show;
-- fresh: a new start, where it is now counts as no move.
function Trail:Moved(fresh)
    local now = GetTime()
    if fresh then self.movedAt = nil end
    if GetCursorPosition then
        local ok, x, y = pcall(GetCursorPosition)
        if ok and type(x) == "number" and type(y) == "number" then
            if not fresh and self.cursorX and (x ~= self.cursorX or y ~= self.cursorY) then self.movedAt = now end
            self.cursorX, self.cursorY = x, y
        end
    else
        -- No way to tell: every hover counts as the mouse moving there.
        return true
    end
    return self.movedAt ~= nil and now - self.movedAt <= MOVED
end

-- The mouse on one of your icons: moved there, it holds your trail still
-- (Pause On Hover); it shows the tooltip (Tooltip); leaving lets it go on.
function Trail:EnterIcon(icon)
    local options, trail = self:Options(), trails.player
    if trail then
        trail.under = icon
        if options.pause and icon.entry and self:Moved() then trail.hover = icon end
    end
    if options.tooltip then ShowTip(icon, options) end
end

function Trail:LeaveIcon(icon)
    local trail = trails.player
    if trail then
        if trail.hover == icon then trail.hover = nil end
        if trail.under == icon then trail.under = nil end
    end
    HideTip(icon)
end

local function Icon(trail, index)
    local icon = trail.icons[index]
    if icon then return icon end
    icon = CreateFrame("Button", nil, trail.holder)
    icon.edge = icon:CreateTexture(nil, "BACKGROUND")
    icon.edge:SetAllPoints()
    icon.art = icon:CreateTexture(nil, "ARTWORK")
    icon.art:SetPoint("TOPLEFT", 2, -2)
    icon.art:SetPoint("BOTTOMRIGHT", -2, 2)
    icon.art:SetTexCoord(.08, .92, .08, .92)
    icon.cross = icon:CreateTexture(nil, "OVERLAY")
    icon.cross:SetPoint("TOPLEFT", 4, -4)
    icon.cross:SetPoint("BOTTOMRIGHT", -4, 4)
    icon.cross:SetTexture(CROSS)
    icon.cross:Hide()
    if trail.unit == "player" then
        icon:RegisterForClicks("RightButtonUp")
        icon:RegisterForDrag("LeftButton")
        icon:SetScript("OnClick", function(self) if self.entry then Trail:Ignore(self.entry) end end)
        icon:SetScript("OnDragStart", function(self) Trail:StartDrag("player", self) end)
        icon:SetScript("OnDragStop", function() Trail:StopDrag("player") end)
        icon:SetScript("OnEnter", function(self) Trail:EnterIcon(self) end)
        icon:SetScript("OnLeave", function(self) Trail:LeaveIcon(self) end)
        -- Gone (its ability's trip over): no tooltip, no hold, and a drag
        -- started on it ends (a hidden frame never hears the mouse let go).
        icon:SetScript("OnHide", function(self)
            Trail:LeaveIcon(self)
            if Trail.dragFrom == self then Trail:StopDrag("player") end
        end)
    else
        icon:EnableMouse(false)
    end
    icon:Hide()
    trail.icons[index] = icon
    return icon
end

local function NewTrail(unit)
    local holder = CreateFrame("Frame", unit == "player" and "EraUIAbilityTrail" or nil, UIParent)
    holder:SetSize(36, 36)
    holder:SetFrameStrata("MEDIUM")
    holder:SetClampedToScreen(true)
    holder:SetMovable(true)
    if holder.SetDontSavePosition then holder:SetDontSavePosition(true) end
    local trail = {unit = unit, holder = holder, icons = {}, entries = {}}
    trails[unit] = trail
    return trail
end

-- The frame the game shows a party member in (the party frames, or the
-- raid-style ones), read only.
local function PartyFrameFor(unit)
    local pool = PartyFrame and PartyFrame.PartyMemberFramePool
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
        for member in pool:EnumerateActive() do
            if member.unit == unit and member.IsVisible and member:IsVisible() then return member end
        end
    end
    for i = 1, 5 do
        local member = _G["CompactPartyFrameMember" .. i]
        if member and (member.unit == unit or member.displayedUnit == unit) and member:IsVisible() then return member end
    end
    for i = 1, 4 do
        local member = _G["PartyMemberFrame" .. i]
        if member and member.unit == unit and member:IsVisible() then return member end
    end
end

-- A trail's own measures: yours, or the party's.
local function Measures(trail, options)
    return trail.unit == "player" and options.you or options.party
end

-- A kept spot ({x, y} from the screen's top left), or nil.
local function Spot(value)
    if type(value) == "table" and tonumber(value.x) and tonumber(value.y) then return tonumber(value.x), tonumber(value.y) end
end

local function PartySpots()
    local list = EraUI:GetSetting("abilityTrailPartyPositions")
    return type(list) == "table" and list or {}
end

-- Puts a trail's holder where it starts: yours where you moved it, or by
-- your frame; a party member's where you moved that slot's, else at their
-- frame's edge, the way it goes. While unlocked a party trail with neither
-- shows in a spot of its own, so its box can be moved.
function Trail:Place(trail, options)
    options = options or self:Options()
    local mine = Measures(trail, options)
    local way = DIRECTIONS[mine.direction]
    local holder = trail.holder
    holder:SetSize(mine.size, mine.size)
    holder:ClearAllPoints()
    if trail.unit == "player" then
        local x, y = Spot(EraUI:GetSetting("abilityTrailPosition"))
        if x then
            holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
        elseif PlayerFrame then
            holder:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 40, 8)
        else
            holder:SetPoint("CENTER", UIParent, "CENTER", 0, -120)
        end
        trail.anchored = true
        return
    end
    local slot = SLOT[trail.unit]
    local x, y = Spot(PartySpots()[slot])
    if x then
        holder:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
        trail.anchored = true
        holder:Show()
        return
    end
    -- No party frame showing them (a raid, or another addon's frames): no
    -- trail, rather than one in the middle of the screen.
    local frame = PartyFrameFor(trail.unit)
    trail.anchored = frame ~= nil
    if frame then
        holder:SetPoint(way[1], frame, way[2], way[3] * GAP, way[4] * GAP)
        holder:Show()
    elseif self.unlocked then
        holder:SetPoint("CENTER", UIParent, "CENTER", -260, 120 - (slot - 1) * 60)
        holder:Show()
    else
        holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        holder:Hide()
    end
end

-- How see-through an icon is: gliding, full until the last part of the
-- trip, then fading; still, full until its last second of Show For.
local function Alpha(entry, options, fade)
    if options.scroll then
        local left = options.distance - entry.pos
        return left < fade and math.max(0, left / fade) or 1
    end
    local left = options.seconds - (entry.age or 0)
    return left < 1 and math.max(0, left) or 1
end

-- While the mouse is over one of your icons, your trail holds still: once
-- it moved onto it, or moves while an icon that came to it is under it.
function Trail:Paused(trail, options)
    local under = trail.under
    if not trail.hover and under and options.pause and under:IsShown() and under.entry
        and (not under.IsMouseOver or under:IsMouseOver()) and self:Moved() then
        trail.hover = under
    end
    local icon = trail.hover
    if not icon then return false end
    if not (options.pause and icon:IsShown() and icon.entry) or (icon.IsMouseOver and not icon:IsMouseOver()) then
        trail.hover = nil
        return false
    end
    return true
end

-- Moves (or ages) every icon on by elapsed seconds, drops the ones at the
-- end of their trip, past Show For or past Icons, and draws them. Gliding,
-- each moves Speed pixels a second and keeps an icon apart from the newer
-- one; still, each sits an icon on from the newer one. Returns whether any
-- icon still shows.
function Trail:Draw(trail, elapsed, options)
    options = options or self:Options()
    local mine = Measures(trail, options)
    local way = DIRECTIONS[mine.direction]
    local size, step = mine.size, mine.size + GAP
    local entries = trail.entries
    if not elapsed or self:Paused(trail, options) then elapsed = 0 end
    for i, entry in ipairs(entries) do
        if options.scroll then
            entry.pos = (entry.pos or 0) + options.speed * elapsed
            local newer = entries[i - 1]
            if newer and entry.pos < newer.pos + step then entry.pos = newer.pos + step end
        else
            entry.age = (entry.age or 0) + elapsed
        end
    end
    for i = #entries, 1, -1 do
        local entry = entries[i]
        local over
        if options.scroll then over = entry.pos >= options.distance else over = entry.age >= options.seconds end
        if i > mine.count or over then
            if trail.casting == entry then trail.casting = nil end
            table.remove(entries, i)
        end
    end
    if not options.scroll then
        for i, entry in ipairs(entries) do entry.pos = (i - 1) * step end
    end
    local fade = options.distance * FADE_PART
    local edge = self:EdgeColour(trail, options)
    -- A cast still being cast pulses softly (its picture between 55% and full).
    local pulse = .775 + .225 * math.cos((GetTime() or 0) * 6)
    for index = 1, MAX do
        local entry = entries[index]
        local icon = trail.icons[index]
        if entry then
            icon = Icon(trail, index)
            icon:SetSize(size, size)
            icon:ClearAllPoints()
            icon:SetPoint(way[1], trail.holder, way[1], way[3] * entry.pos, way[4] * entry.pos)
            icon.edge:SetColorTexture(edge[1], edge[2], edge[3], 1)
            icon.art:SetTexture(entry.texture)
            icon.art:SetAlpha(entry.casting and pulse or 1)
            if icon.art.SetDesaturated then icon.art:SetDesaturated(entry.cancelled == true) end
            icon.cross:SetShown(entry.cancelled == true)
            icon:SetAlpha(Alpha(entry, options, fade))
            icon.entry = entry
            icon:Show()
            -- The tooltip on this icon names what it shows now.
            local tip = Trail.tip
            if tip and tip.owner == icon and tip.entry ~= entry and tip:IsShown() then ShowTip(icon, options) end
        elseif icon then
            icon.entry = nil
            icon:Hide()
        end
    end
    return #entries > 0
end

-- A new icon at the start of its trail, pushing the others on.
function Trail:Insert(trail, entry, options)
    table.insert(trail.entries, 1, entry)
    if not trail.anchored then self:Place(trail, options) end
    self:Draw(trail, 0, options)
    self:Tick()
    return entry
end

-- A cast: a new icon at the start of that trail, unless Show In leaves out
-- where you are. With Combat Only, out of a fight it waits a moment for the
-- fight it may start (an opener), then goes. casting: it has a cast time
-- and is still being cast. Returns the entry once it shows.
function Trail:Add(unit, spellID, casting, castGUID)
    local trail = trails[unit]
    if not trail or not self:Here() then return end
    local entry = {pos = 0, age = 0, casting = casting or nil}
    if unit == "player" or Public(spellID) then
        if not self:Wanted(spellID) then return end
        entry.id, entry.name = spellID, SpellName(spellID)
    end
    if Public(castGUID) and type(castGUID) == "string" then entry.guid = castGUID end
    -- A secret spell (a party member's) goes straight to the texture: the
    -- game takes it there, and nothing here reads it.
    local get = C_Spell and C_Spell.GetSpellTexture
    if not get then return end
    local ok, texture = pcall(get, spellID)
    if not ok then return end
    -- Yours from an item (a potion, a trinket): the item's own icon.
    local item = unit == "player" and self:ItemIcon(spellID) or nil
    if item ~= nil then texture = item end
    if Public(texture) and texture == nil then return end
    entry.texture = texture
    local options = self:Options()
    if options.combatOnly and not InFight() then
        trail.held, trail.heldAt = entry, GetTime()
        return
    end
    trail.held = nil
    return self:Insert(trail, entry, options)
end

-- A fight starts: a cast held just before it (the one that started it)
-- shows after all.
function Trail:FightStarted()
    local now = GetTime()
    local options = self:Options()
    for _, trail in pairs(trails) do
        local entry = trail.held
        trail.held = nil
        if entry and now - (trail.heldAt or 0) <= HELD then
            self:Insert(trail, entry, options)
            if entry.casting then trail.casting = entry end
        end
    end
end

-- The cast being cast on this trail, if this event is about it: the same
-- cast when the game says which (yours), else the one cast last (a party
-- member's, whose cast is hidden).
local function Current(trail, castGUID)
    local entry = trail.casting
    if not entry then return nil end
    if entry.guid and Public(castGUID) and type(castGUID) == "string" and castGUID ~= entry.guid then return nil end
    return entry
end

-- A unit's cast events: a cast with a cast time shows as it starts; when
-- it lands it just loses its gold edge (no second icon); cancelled or
-- interrupted it gets the red cross. Instant ones show as they land.
function Trail:OnCast(unit, event, castGUID, spellID)
    local trail = trails[unit]
    if not trail then return end
    if event == "UNIT_SPELLCAST_START" then
        -- A cast the game never finished telling us about stops waiting.
        if trail.casting then trail.casting.casting = nil end
        trail.casting = self:Add(unit, spellID, true, castGUID)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local entry = Current(trail, castGUID)
        if entry then
            entry.casting, trail.casting = nil, nil
            self:Draw(trail, 0)
        else
            self:Add(unit, spellID)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local entry = Current(trail, castGUID)
        if entry then
            entry.casting, entry.cancelled, trail.casting = nil, true, nil
            self:Draw(trail, 0)
        elseif trail.held and trail.held.casting then
            trail.held = nil
        end
    end
end

-- Moves every trail on each frame while any icon shows, then stops. It
-- keeps an eye on the mouse meanwhile (Pause On Hover): where it is as the
-- trail starts isn't a move.
function Trail:Tick()
    if self.ticking then return end
    self.ticking = true
    self:Moved(true)
    self.driver:SetScript("OnUpdate", function(_, elapsed)
        self:Moved()
        local options, busy = self:Options(), false
        for _, trail in pairs(trails) do
            if self:Draw(trail, elapsed, options) then busy = true end
        end
        if not busy then
            self.ticking = false
            self.driver:SetScript("OnUpdate", nil)
        end
    end)
end

-- Right-click: that ability goes on the ignore list and off the trail.
function Trail:Ignore(entry)
    if type(entry.id) ~= "number" then return end
    local list = EraUI:GetSetting("abilityTrailIgnore")
    if type(list) ~= "table" then list = {} end
    list[tostring(entry.id)] = entry.name or "?"
    EraUI:SetSetting("abilityTrailIgnore", list)
    if EraUI.SaveSettings then EraUI:SaveSettings() end
    local trail = trails.player
    for i = #trail.entries, 1, -1 do
        if trail.entries[i].id == entry.id then
            if trail.casting == trail.entries[i] then trail.casting = nil end
            table.remove(trail.entries, i)
        end
    end
    self:Draw(trail, 0)
    HideTip()
    EraUI:Print("Ability Trail: " .. (entry.name or "that ability") .. " is ignored. /era > Casting > Ability Trail > Ignored Abilities clears the list.")
end

function Trail:ClearIgnored()
    EraUI:SetSetting("abilityTrailIgnore", nil)
    if EraUI.SaveSettings then EraUI:SaveSettings() end
end

-- Whether a trail is switched on (yours, or the party's).
function Trail:Live(trail)
    if trail.unit == "player" then return self:On() end
    return self:PartyOn()
end

-- Dragging a trail (an icon of yours, or its box while unlocked): kept where
-- you let go, in the screen's units; a party trail by its slot. from: the
-- frame it started on (hidden mid-drag, it ends the drag).
function Trail:StartDrag(unit, from)
    unit = unit or "player"
    local trail = trails[unit]
    if not trail then return end
    self.dragging, self.dragFrom = unit, from
    trail.holder:StartMoving()
end

function Trail:StopDrag(unit)
    unit = unit or "player"
    local trail = trails[unit]
    if not (trail and self.dragging == unit) then return end
    self.dragging, self.dragFrom = nil, nil
    local holder = trail.holder
    holder:StopMovingOrSizing()
    if holder.SetUserPlaced then holder:SetUserPlaced(false) end
    local left, top, height = holder:GetLeft(), holder:GetTop(), UIParent:GetHeight()
    if Public(left) and Public(top) and type(left) == "number" and type(top) == "number" and type(height) == "number" then
        local spot = {x = math.floor(left + .5), y = math.floor(top - height + .5)}
        if unit == "player" then
            EraUI:SetSetting("abilityTrailPosition", spot)
        else
            local list = {}
            for slot, kept in pairs(PartySpots()) do list[slot] = kept end
            list[SLOT[unit]] = spot
            EraUI:SetSetting("abilityTrailPartyPositions", list)
        end
        if EraUI.SaveSettings then EraUI:SaveSettings() end
    end
    self:Place(trail)
    self:DrawBox(trail)
end

-- Reset: every trail back, yours under your frame, each party trail at
-- its member's frame.
function Trail:ResetPosition()
    EraUI:SetSetting("abilityTrailPosition", nil)
    EraUI:SetSetting("abilityTrailPartyPositions", nil)
    if EraUI.SaveSettings then EraUI:SaveSettings() end
    local options = self:Options()
    for _, trail in pairs(trails) do
        self:Place(trail, options)
        self:DrawBox(trail, options)
    end
end

-- Unlocked: a labelled box over each trail that is on, the length of its
-- icons' way, to drag it by. Right-click a box (or Lock) hides them.
local function Box(trail)
    local box = trail.box
    if box then return box end
    box = CreateFrame("Frame", nil, trail.holder, "BackdropTemplate")
    box:SetFrameLevel((trail.holder:GetFrameLevel() or 1) + 20)
    box:SetBackdrop({bgFile = WHITE, edgeFile = WHITE, edgeSize = 1})
    box:SetBackdropColor(.93, .75, .32, .18)
    box:SetBackdropBorderColor(.93, .75, .32, .9)
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.label:SetPoint("CENTER", box, "CENTER", 0, 0)
    box.label:SetText(NAMES[trail.unit])
    box:EnableMouse(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", function(self) Trail:StartDrag(trail.unit, self) end)
    box:SetScript("OnDragStop", function() Trail:StopDrag(trail.unit) end)
    box:SetScript("OnHide", function(self) if Trail.dragFrom == self then Trail:StopDrag(trail.unit) end end)
    box:SetScript("OnMouseUp", function(_, button) if button == "RightButton" then Trail:SetUnlocked(false) end end)
    box:Hide()
    trail.box = box
    return box
end

function Trail:DrawBox(trail, options)
    if not (self.unlocked and self:Live(trail)) then
        if trail.box then trail.box:Hide() end
        return
    end
    options = options or self:Options()
    local mine = Measures(trail, options)
    local way = DIRECTIONS[mine.direction]
    local long = options.scroll and options.distance + mine.size or mine.count * (mine.size + GAP) - GAP
    local box = Box(trail)
    box:ClearAllPoints()
    box:SetPoint(way[1], trail.holder, way[1], 0, 0)
    if way[3] ~= 0 then box:SetSize(long, mine.size) else box:SetSize(mine.size, long) end
    box:Show()
end

-- Unlock (or Lock) every trail that is on. Nothing to unlock with both off.
-- Fight starting locks them. watch(on) hears of each change (/era's button).
-- A drag still going as they lock ends first, kept where it is (its box
-- won't hear the mouse let go once hidden).
function Trail:SetUnlocked(on)
    on = on and true or false
    if on and not (self:On() or self:PartyOn()) then return false end
    if not on and self.dragging then self:StopDrag(self.dragging) end
    -- The trails that are on exist before their boxes show.
    if on then self:Refresh() end
    self.unlocked = on
    local options = self:Options()
    for _, trail in pairs(trails) do
        self:Place(trail, options)
        self:DrawBox(trail, options)
    end
    if self.watch then self.watch(on) end
    return true
end

-- Events: your casts, each party member's (a frame each: the unit can't be
-- told from a secret payload), and the group changing.
local function Listen(frame, unit)
    local filtered = frame.RegisterUnitEvent ~= nil
    for _, event in ipairs(EVENTS) do
        if not (filtered and pcall(frame.RegisterUnitEvent, frame, event, unit)) then
            filtered = false
            pcall(frame.RegisterEvent, frame, event)
        end
    end
    frame.filtered = filtered
end

local function Caster(unit)
    local frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function(_, event, who, castGUID, spellID)
        -- Without a unit filter (a client lacking RegisterUnitEvent), only
        -- a plain unit token that is this one counts.
        if not frame.filtered and not (Public(who) and who == unit) then return end
        local ok, err = pcall(Trail.OnCast, Trail, unit, event, castGUID, spellID)
        if not ok and not Trail.lastError then Trail.lastError = tostring(err) end
    end)
    return frame
end

local function Clear(trail)
    if not trail then return end
    trail.entries, trail.casting, trail.held, trail.hover, trail.under = {}, nil, nil, nil, nil
    Trail:Draw(trail, 0)
end

local DRIVER_EVENTS = {"GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "BAG_UPDATE_DELAYED",
    "PLAYER_EQUIPMENT_CHANGED"}

local function OnDriverEvent(_, event)
    if event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" then
        Trail:ItemsChanged()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        if Trail.unlocked then Trail:SetUnlocked(false) end
        Trail:FightStarted()
        return
    end
    for _, unit in ipairs(PARTY_UNITS) do
        local trail = trails[unit]
        if trail then
            if not UnitExists(unit) then Clear(trail) end
            Trail:Place(trail)
        end
    end
    if trails.player then Trail:Place(trails.player) end
end

-- Follows the options: listening, placing and clearing as they change.
function Trail:Refresh()
    local on, party = self:On(), self:PartyOn()
    if (on or party) and not self.driver then
        self.driver = CreateFrame("Frame")
        self.driver:SetScript("OnEvent", OnDriverEvent)
        self.casters = {}
    end
    if not self.driver then return end
    for _, event in ipairs(DRIVER_EVENTS) do
        if on or party then self.driver:RegisterEvent(event) else self.driver:UnregisterEvent(event) end
    end
    if not (on or party) and self.unlocked then
        self.unlocked = false
        if self.watch then self.watch(false) end
    end
    -- You.
    if on and not trails.player then NewTrail("player") end
    local mine = self.casters.player
    if on then
        if not mine then mine = Caster("player"); self.casters.player = mine end
        Listen(mine, "player")
    elseif mine then
        mine:UnregisterAllEvents()
        Clear(trails.player)
    end
    -- Your party.
    for _, unit in ipairs(PARTY_UNITS) do
        local caster = self.casters[unit]
        if party then
            if not trails[unit] then NewTrail(unit) end
            if not caster then caster = Caster(unit); self.casters[unit] = caster end
            Listen(caster, unit)
        elseif caster then
            caster:UnregisterAllEvents()
            Clear(trails[unit])
        end
    end
    local options = self:Options()
    for _, trail in pairs(trails) do
        self:Place(trail, options)
        self:Draw(trail, 0, options)
        self:DrawBox(trail, options)
    end
end

function Trail:Initialize()
    self:Refresh()
end
