local _, E = ...

-- The grid that opens off a slot on the Trinket Bar (Modules/TrinketBar.lua):
-- every item in your bags that goes in that slot, a tile each with its own
-- icon, its cooldown sweep and the time left, so you can see which ones are
-- ready before you pick. Click a tile to put it on. It opens as you point at
-- a slot (Open List: Hover) or on a left-click (Click), and closes as the
-- mouse leaves both the slot and the grid, on the next pick, or with the bar.
--
-- Icons per Row says how many tiles lie across (three to eight, six to start
-- with); the grid goes on down the screen for as many as you carry, with no
-- limit on how many it shows. Pointing at a tile names it and says what its
-- use does, in EraUI's own small box (Modules/TrinketKit.lua K.Tip), never
-- the game's tooltip, which Forever taints as soon as an addon drives it.
--
-- The grid is EraUI's own plain frame on UIParent, never a child of a slot,
-- so making it, showing it, filling it and greying it are ordinary code and
-- work in a fight as well: the game never lets gear change in one, so each
-- tile fades and the foot says why instead of a click doing nothing. Forever
-- keeps a bag's cooldown secret in a fight too, so a tile's two numbers go
-- to its sweep as they are, no time is written, and the tick leaves that tile
-- alone until the game says the cooldown changed again.
--
-- With Queue in a Fight on, a click in a fight keeps that trinket for the
-- slot and it goes on the moment the fight ends: the tile and the slot wear
-- the Queued strip, one item waits a slot, and clicking the queued one again
-- takes it back. The waiting list itself is the sets' (Modules/TrinketSets.lua),
-- the only one on the bar, and every swap goes through its Equip, in a fight
-- or out of one. Queue in a Fight off: a fight refuses the swap as it always
-- did.
local L = {}
E.TrinketList = L

local TILE, INSET, GAP, PAD = 32, 1, 4, 6
local MIN_W, TITLE_H, FOOT_H = 186, 16, 15
local ACROSS_MIN, ACROSS_MAX, ACROSS_DEFAULT = 3, 8, 6
local TICK = .1 -- how often the time left on a tile is redrawn
local function K() return E.TrinketKit end
local function Sets() return E.TrinketSets end

local frame, title, foot, hint, box
local tiles = {}
local entries = {}
local closing, ticking = false, 0
L.rows = tiles

local function Across() return K().Setting("trinketGridColumns", ACROSS_MIN, ACROSS_MAX, ACROSS_DEFAULT) end

---------------------------------------------------------------------------
-- A tile
---------------------------------------------------------------------------

-- The same bag slot holding the same item: a tile and what is queued for the
-- slot are one and the same thing. Plain numbers from the kit's own bag read,
-- so they are safe to compare.
local function Same(a, b)
    return a ~= nil and b ~= nil and a.bag == b.bag and a.slot == b.slot and a.id == b.id
end

-- A tile's click, out of a fight or in one: the sets put the item on now or
-- keep it for the fight's end (Queue in a Fight), so there is one way in and
-- one waiting list. The one already queued, clicked again, is taken back. The
-- strips are drawn by the sets themselves, so nothing is redrawn here.
local function TileClick(tile)
    local kit, sets = K(), Sets()
    local entry = tile.entry
    if not (entry and sets) then return end
    if kit.Fight() and Same(sets.Queued(L.slot), entry) then
        sets.Forget(L.slot)
        return
    end
    local how, why = sets.Equip(entry, L.slot)
    if how == "now" then L.Close(); return end
    if how == nil and why == "fight" then E:Status(kit.REFUSED) end
end

-- Pointing at a tile: its edge brightens and the box above it says what it
-- is and what its use does.
local function TileEnter(tile)
    local kit = K()
    local entry = tile.entry
    if not entry then return end
    tile.edge:SetVertexColor(1, .82, .3, 1)
    local use = kit.Use(entry.id)
    kit.Tip(tile, entry.name, use and ("Use: " .. use) or nil)
end

local function TileLeave(tile)
    local kit = K()
    tile.edge:SetVertexColor(kit.GREY[1], kit.GREY[2], kit.GREY[3], .8)
    kit.Untip(tile)
end

-- One tile, made the first time the grid needs that many: EraUI's own icon,
-- edge, sweep and time on a plain button. Nothing here is a secure frame, so
-- a tile is made, placed and shown in a fight as happily as out of one.
local function Tile(index)
    local tile = tiles[index]
    if tile then return tile end
    local kit = K()
    tile = CreateFrame("Button", nil, frame)
    tile:SetSize(TILE, TILE)
    -- ARTWORK, not BACKGROUND: the edge below is one solid fill across the
    -- whole tile, so on BACKGROUND the icon would sit under it and every
    -- trinket would come out washed grey. The icon is inset by one, so the
    -- fill shows as the tile's edge around it.
    tile.icon = tile:CreateTexture(nil, "ARTWORK")
    tile.icon:SetPoint("TOPLEFT", tile, "TOPLEFT", INSET, -INSET)
    tile.icon:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -INSET, INSET)
    tile.edge = tile:CreateTexture(nil, "BORDER")
    tile.edge:SetTexture(kit.FILL)
    tile.edge:SetVertexColor(kit.GREY[1], kit.GREY[2], kit.GREY[3], .8)
    tile.edge:SetAllPoints(tile)
    tile.shade = tile:CreateTexture(nil, "HIGHLIGHT")
    tile.shade:SetTexture(kit.FILL)
    tile.shade:SetVertexColor(1, .82, .3, .14)
    tile.shade:SetAllPoints(tile)
    tile.cd = CreateFrame("Cooldown", nil, tile, "CooldownFrameTemplate") -- its own swipe, as on a slot
    tile.cd:SetAllPoints(tile.icon)
    tile.cd:EnableMouse(false)
    tile.cd:SetDrawEdge(true) -- the sweeping rim line, as on a slot
    tile.cd:SetDrawBling(false)
    tile.cd:SetHideCountdownNumbers(true)
    -- The game's own swipe, as on a slot: the same clock in both places.
    tile.time = kit.Text(tile, 10)
    tile.time:SetJustifyH("CENTER")
    tile.time:SetPoint("BOTTOM", tile, "BOTTOM", 0, 1)
    tile.time:SetTextColor(1, .95, .7)
    -- The Queued strip, the same one a slot on the bar wears.
    tile.mark = kit.QueueStrip(tile)
    tile:SetScript("OnClick", TileClick)
    tile:SetScript("OnEnter", TileEnter)
    tile:SetScript("OnLeave", TileLeave)
    tiles[index] = tile
    return tile
end

-- One tile's sweep and the seconds left on it. The grid is there to show
-- what is ready, so its tiles always carry their time (Time Left on Icon is
-- about the bar's own slots). In a fight the game keeps the bags' cooldowns
-- secret: the two numbers go to the sweep as they are, never read here, and
-- no time is written.
local function Sweep(tile)
    local kit = K()
    local cd, text, entry = tile.cd, tile.time, tile.entry
    local start, length
    if entry then start, length = kit.BagSweep(entry.bag, entry.slot) end
    if start == nil or length == nil then
        cd:Clear()
        text:SetText("")
        tile.hidden = false
        return
    end
    if not (kit.Num(start) and kit.Num(length)) then
        if not pcall(cd.SetCooldown, cd, start, length) then cd:Clear() end
        text:SetText("")
        -- A secret is never compared, so the tick leaves this tile alone
        -- until the game says the cooldown changed again.
        tile.hidden = true
        return
    end
    tile.hidden = false
    local now = kit.Call(GetTime)
    local left = 0
    if start > 0 and length > 1.5 and kit.Num(now) then left = start + length - now end
    if left > 0 then
        cd:SetCooldown(start, length)
        text:SetText(kit.TimeText(left, E:GetSetting("trinketBarTimeStyle")))
        return
    end
    cd:Clear()
    text:SetText("")
end

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------

-- The seconds on the tiles, while the grid is up. A hidden frame's OnUpdate
-- never runs, so nothing of this ticks while the grid is closed.
local function OnUpdate(_, elapsed)
    ticking = ticking + (elapsed or 0)
    if ticking < TICK then return end
    ticking = 0
    for _, tile in ipairs(tiles) do
        if tile.entry and not tile.hidden and tile:IsShown() then Sweep(tile) end
    end
end

-- Closed, however it closed: no hover box left behind.
local function Drop()
    local kit = K()
    for _, tile in ipairs(tiles) do kit.Untip(tile) end
end

-- Made once, the first time the grid opens. Sized as it is made: Forever may
-- never draw a frame laid out under one without a size.
local function Build()
    if frame then return end
    local kit = K()
    frame = CreateFrame("Frame", "EraUITrinketList", UIParent)
    frame:SetSize(MIN_W, PAD * 2 + TITLE_H + TILE)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    box = kit.Box(frame)
    title = kit.Text(frame, 12)
    title:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -PAD)
    -- The foot: one line, with a second under it in a fight to say what a
    -- click does there (Fill places the first above the second).
    foot = kit.Text(frame, 10)
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD - 1)
    foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD - 1)
    foot:SetWordWrap(true)
    hint = kit.Text(frame, 10)
    hint:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD - 1)
    hint:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD - 1)
    hint:SetWordWrap(true)
    hint:Hide()
    frame:SetScript("OnLeave", function() L.CloseSoon() end)
    frame:SetScript("OnUpdate", OnUpdate)
    frame:SetScript("OnHide", Drop)
    L.frame = frame
end

function L.Paint()
    if not frame then return end
    local kit = K()
    local look = kit.Look()
    kit.Paint(box)
    title:SetTextColor(look.word[1], look.word[2], look.word[3])
end

---------------------------------------------------------------------------
-- Filling it
---------------------------------------------------------------------------

-- A tile's Queued strip, and how it reads: in a fight nothing can go on now,
-- so the tiles fade, and the one queued for the slot keeps its colour and
-- wears the strip.
local function Mark(tile, queued)
    local chosen = Same(queued, tile.entry)
    K().ShowQueue(tile.mark, chosen)
    local dim = tile.greyed == true and not chosen
    tile.icon:SetDesaturated(dim)
    tile.icon:SetAlpha(dim and .5 or 1)
end

-- Every tile: its icon, its sweep, its time and its Queued strip, faded in a
-- fight. The foot says why in a fight, and what a click does there instead
-- with Queue in a Fight on, or that there is nothing to put on. The frame is
-- sized here, before Place works out from its height whether it goes under
-- the slot or over it.
local function Fill()
    local kit, sets = K(), Sets()
    local fighting = kit.Fight()
    -- In a fight a tile is still live while a click can queue it; without
    -- that it takes no mouse, as it always did.
    local queueing = fighting and sets ~= nil and sets.Queueing()
    local queued = sets and sets.Queued(L.slot) or nil
    local live = not fighting or queueing
    local count = #entries
    local across = math.max(1, math.min(Across(), count))
    local down = math.ceil(count / across)
    local top = PAD + TITLE_H
    for index = 1, math.max(count, #tiles) do
        local entry = entries[index]
        local tile = tiles[index]
        if entry then tile = Tile(index) end
        if tile and entry then
            tile.entry, tile.greyed = entry, fighting
            tile.icon:SetTexture(entry.icon or kit.EMPTY)
            Mark(tile, queued)
            local place = index - 1
            local column, row = place % across, math.floor(place / across)
            tile:SetSize(TILE, TILE)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + column * (TILE + GAP), -(top + row * (TILE + GAP)))
            tile:EnableMouse(live)
            tile.shade:SetShown(live)
            Sweep(tile)
            tile:Show()
        elseif tile then
            tile.entry, tile.hidden = nil, false
            tile.cd:Clear()
            tile.time:SetText("")
            kit.ShowQueue(tile.mark, false)
            kit.Untip(tile)
            tile:Hide()
        end
    end
    local note, more
    if fighting then
        note = kit.REFUSED
        -- Only where there is a tile to click: an empty grid must never tell
        -- you to click one.
        if queueing and count > 0 then more = kit.QUEUE_FOOT end
    elseif count == 0 then note = "Nothing in your bags to put on." end
    local feet = (note and 1 or 0) + (more and 1 or 0)
    -- The first line sits above the second when there is one, so the two
    -- together are the foot and neither has to wrap.
    foot:SetText(note or "")
    foot:SetTextColor(kit.GOLD[1], kit.GOLD[2], kit.GOLD[3])
    foot:SetShown(note ~= nil)
    foot:ClearAllPoints()
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, PAD - 1 + (more and FOOT_H or 0))
    foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, PAD - 1 + (more and FOOT_H or 0))
    hint:SetText(more or "")
    hint:SetTextColor(kit.GREY[1], kit.GREY[2], kit.GREY[3])
    hint:SetShown(more ~= nil)
    local grid = down > 0 and (down * TILE + (down - 1) * GAP) or 0
    frame:SetWidth(math.max(MIN_W, PAD * 2 + across * TILE + (across - 1) * GAP))
    frame:SetHeight(top + grid + (feet > 0 and (GAP + FOOT_H * feet) or 0) + PAD)
end

-- The Queued strip on every tile, after the waiting list changed (the sets
-- call this; nothing is read from the bags again). Nothing while it is shut.
function L.Marks()
    if not (frame and frame:IsShown()) then return end
    local sets = Sets()
    local queued = sets and sets.Queued(L.slot) or nil
    for _, tile in ipairs(tiles) do
        if tile.entry and tile:IsShown() then Mark(tile, queued) end
    end
end

-- Over the slot, so it never covers what sits under the bar (Squirt keeps
-- the bar just above his target frame, 27 Nov 2026), or under it when there
-- is no room above (a bar near the top of the screen). An unreadable spot
-- leaves it over.
local function Place(anchor)
    local kit = K()
    local top, height, screen = anchor:GetTop(), frame:GetHeight(), UIParent and UIParent:GetHeight()
    local above = true
    if kit.Num(top) and kit.Num(height) and kit.Num(screen) and top + height + 10 > screen then above = false end
    frame:ClearAllPoints()
    if above then frame:SetPoint("BOTTOM", anchor, "TOP", 0, 6)
    else frame:SetPoint("TOP", anchor, "BOTTOM", 0, -6) end
end

---------------------------------------------------------------------------
-- Opening and closing
---------------------------------------------------------------------------

function L.Shown() return frame ~= nil and frame:IsShown() end

-- The grid for one slot: what you carry for it, under (or over) that slot.
function L.Open(slot, kind, anchor, label)
    if not (K() and anchor) then return false end
    Build()
    L.slot, L.kind, L.anchor = slot, kind, anchor
    entries = K().Bags(kind)
    title:SetText(label or "Swap")
    L.Paint()
    Fill()
    Place(anchor)
    frame:Show()
    return true
end

function L.Close()
    L.slot, L.kind, L.anchor = nil, nil, nil
    if frame then frame:Hide() end
end

function L.Toggle(slot, kind, anchor, label)
    if L.Shown() and L.slot == slot then L.Close(); return false end
    return L.Open(slot, kind, anchor, label)
end

-- The mouse left the slot or the grid: closed a moment later, unless it is
-- on one of them by then (so it can be moved from the slot onto the grid).
function L.CloseSoon()
    if closing or not L.Shown() then return end
    closing = true
    C_Timer.After(.25, function()
        closing = false
        if not L.Shown() then return end
        if L.Over() then return end
        L.Close()
    end)
end

function L.Over()
    local anchor = L.anchor
    if frame and frame:IsShown() and frame:IsMouseOver() then return true end
    return anchor ~= nil and anchor:IsShown() and anchor:IsMouseOver() == true
end

-- The bags changed, a fight started or ended, or Icons per Row moved: the
-- tiles again. Nothing while it is closed.
function L.Refresh()
    if not L.Shown() then return end
    local kit = K()
    entries = kit.Bags(L.kind)
    Fill()
    if L.anchor then Place(L.anchor) end
end
