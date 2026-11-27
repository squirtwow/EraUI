local _, E = ...

-- The Trinket Bar's shared parts (Modules/TrinketBar.lua for the bar,
-- Modules/TrinketList.lua for the grid that opens off a slot,
-- Modules/TrinketMenu.lua for the quick menu, Modules/TrinketSets.lua and
-- Modules/TrinketSetList.lua for your saved sets, Modules/TrinketKeys.lua for
-- the ten keys a set can answer to, Modules/TrinketAlerts.lua for the
-- cooldown alerts): the inventory slots it
-- shows, the reads of what you wear and carry, putting an item on, the time
-- left in words, the hover box, the Queued strip, and the near-black box,
-- tick boxes and slider they are all drawn in.
--
-- Forever keeps a cooldown secret in a fight, and an item's name or icon can
-- come back hidden too, so nothing here is compared, joined or added up
-- until it is known to be a plain number or word; the raw answers go to the
-- widgets as they are. Every call into the game goes through Call, so a
-- client without one of them leaves the bar empty instead of erroring.
local K = {}
E.TrinketKit = K

-- The slots, in the order the bar lays them out. The two rings come only
-- with Show Your Rings (off by default).
K.SLOTS = {
    { slot = 13, kind = "trinket", label = "Trinket 1", doll = "Trinket0Slot", main = true },
    { slot = 14, kind = "trinket", label = "Trinket 2", doll = "Trinket1Slot" },
    { slot = 11, kind = "ring", label = "Ring 1", doll = "Finger0Slot" },
    { slot = 12, kind = "ring", label = "Ring 2", doll = "Finger1Slot" },
}
-- What a bag item must be to go in a slot's list.
K.WORN = { trinket = "INVTYPE_TRINKET", ring = "INVTYPE_FINGER" }
-- How many trinket set keys the game's Key Bindings menu holds
-- (Bindings.xml, Core/Init.lua, Modules/TrinketKeys.lua). You keep as many
-- sets as you like; ten of them at a time can answer to a key.
K.KEYS = 10
K.FILL = "Interface\\Buttons\\WHITE8X8"
K.GLOW = "Interface\\Buttons\\UI-ActionButton-Border" -- a square glow (ADD)
K.EMPTY = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket"
K.EMPTY_RING = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger"
K.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
-- Why a swap is refused. The game itself never lets gear change in a fight,
-- so the list says so instead of trying and failing quietly.
K.REFUSED = "You can't change gear in a fight."
-- A set asked for in a fight, and a set's item that is not in your bags any
-- more (Modules/TrinketSets.lua). The bar says these in chat with SAID in
-- front of them; the sets panel shows them as they are.
K.LATER = "Your trinkets change when this fight ends."
K.SKIPPED = "%s is not in your bags any more."
K.SAID = "Trinket Bar: "
-- Queue in a Fight: the game refuses the swap, so a click in the grid keeps
-- that item for the slot instead and it goes on the moment the fight ends.
-- The second line of the grid's foot says so, and the slot and the tile wear
-- the strip. Each line is short enough to read whole at the grid's narrowest.
K.QUEUED = "Queued"
K.QUEUE_FOOT = "Click one to queue it instead."
K.QUEUE_H = 9
-- The cooldown alerts (Modules/TrinketAlerts.lua, all off to start with): the
-- line as a trinket on the bar comes off cooldown, and the one thirty seconds
-- before it does. Both show in the middle of the screen and, with Say It In
-- Chat Too, in your own chat with SAID in front of them.
K.READY = "%s is ready."
K.SOON = "%s is ready in %d seconds."
-- Classic: a near-black box with a bronze edge. Dark Mode: a dark box with a
-- thin edge in the Darkness slider's grey (half as light). As the Stat
-- Tracker and the Healer Mana panel.
K.LOOKS = {
    classic = { fill = { .024, .024, .031, .84 }, edge = 2, word = { 1, .82, 0 } },
    dark = { fill = { .071, .071, .086, .9 }, edge = 1, word = { .925, .925, .94 } },
}
K.BRONZE = { .541, .427, .169 }
K.GOLD = { .93, .75, .32 }
K.GREY = { .5, .5, .55 }
-- A tick box's and a slider's dark middle, and the one-pixel edge both wear:
-- /era's own (Core/SettingsRows.lua), so the quick menu's rows look like the
-- same rows in the options window.
K.ROW_FILL = { .06, .065, .075 }
K.BACKDROP = { bgFile = K.FILL, edgeFile = K.FILL, edgeSize = 1 }

---------------------------------------------------------------------------
-- Reading the game
---------------------------------------------------------------------------

function K.Public(v) return not (issecretvalue and issecretvalue(v)) end
function K.Num(v) return K.Public(v) and type(v) == "number" end
function K.Word(v) return K.Public(v) and type(v) == "string" and v ~= "" end
local function Ran(ok, ...) if ok then return ... end end
-- One of the game's functions: what it returns, or nothing when the game
-- hasn't got it or the call fails.
function K.Call(fn, ...)
    if type(fn) == "function" then return Ran(pcall(fn, ...)) end
end
function K.Fight() return K.Call(InCombatLockdown) == true end

-- The slots the bar shows now: your first trinket, the second with Show Both
-- Slots, then the two rings with Show Your Rings. The bar lays these out and
-- a set covers these, so the two can never disagree about which slots you
-- can see.
function K.Shown()
    local list = {}
    local both = E:GetSetting("trinketBarBoth") ~= false
    local rings = E:GetSetting("trinketBarRings") == true
    for _, info in ipairs(K.SLOTS) do
        local take
        if info.kind == "ring" then take = rings
        elseif info.main then take = true
        else take = both end
        if take then list[#list + 1] = info end
    end
    return list
end

-- One slot's own row in SLOTS, by the inventory slot number: what kind of
-- item goes in it, and what it is called. Nothing for a slot that is not one
-- of the four.
function K.Info(slot)
    if not K.Num(slot) then return nil end
    for _, info in ipairs(K.SLOTS) do
        if info.slot == slot then return info end
    end
end

-- What is in a slot now: its item ID and its icon, either of which the game
-- may leave out (an empty slot) or keep hidden.
function K.Worn(slot)
    local id = K.Call(GetInventoryItemID, "player", slot)
    local icon = K.Call(GetInventoryItemTexture, "player", slot)
    return K.Num(id) and id or nil, (icon ~= nil and K.Public(icon)) and icon or nil
end

-- The art for an empty slot: the game's own for that paper doll slot, or
-- the plain trinket or ring picture.
function K.EmptyArt(info)
    local _, art = K.Call(GetInventorySlotInfo, info and info.doll)
    if K.Word(art) then return art end
    return (info and info.kind == "ring") and K.EMPTY_RING or K.EMPTY
end

-- A slot's cooldown as the game gives it: start and length, each a plain
-- number, a secret (in a fight) or nothing at all. Never read here.
function K.Sweep(slot)
    local start, length = K.Call(GetInventoryItemCooldown, "player", slot)
    return start, length
end

-- A bag item's cooldown, the same way: Forever keeps these secret in a fight
-- just as it does a worn slot's, so the two answers are handed to a Cooldown
-- widget as they are and never read.
function K.BagSweep(bag, slot)
    local fn = (C_Container and C_Container.GetContainerItemCooldown) or _G.GetContainerItemCooldown
    local start, length = K.Call(fn, bag, slot)
    return start, length
end

-- The time left in words, on a slot and on a grid tile. Two ways of writing
-- it, because a trinket's cooldown is usually minutes and "17:43" is more
-- than anyone reads at a glance (Squirt, 27 Nov 2026, wanting it the way the
-- cooldown manager writes it):
--   "short"  whole minutes while over one, rounded up: 18m, 2m, then plain
--            seconds under a minute and tenths under ten.
--   "clock"  minutes and seconds together: 17:43.
-- Only ever a plain number gets this far.
function K.TimeText(left, style)
    if left >= 60 then
        if style == "clock" then
            return string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
        end
        return string.format("%dm", math.ceil(left / 60))
    end
    if left >= 10 then return string.format("%d", math.floor(left + .5)) end
    return string.format("%.1f", left)
end

-- An item's kind and icon from the client's own data (no name needed, so it
-- answers for an item the game hasn't finished loading).
function K.Where(id)
    local instant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    local _, _, _, place, icon = K.Call(instant, id)
    return K.Word(place) and place or nil, (icon ~= nil and K.Public(icon)) and icon or nil
end

-- An item's name: the bag link's words first (they are there as soon as the
-- bag is), then the client's item data, else the plain word.
function K.Name(bag, slot, id)
    local link = (C_Container and C_Container.GetContainerItemLink) or _G.GetContainerItemLink
    local text = K.Call(link, bag, slot)
    local named = K.Word(text) and text:match("%[(.-)%]")
    if K.Word(named) then return named end
    local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    local name = K.Call(info, id)
    if K.Word(name) then return name end
    return "Item"
end

-- An item by its ID alone: its name and icon from the client's own data, for
-- a saved set, where there is no bag slot to read a link from. Nothing for an
-- item the client doesn't know.
function K.ById(id)
    if not K.Num(id) then return nil end
    local _, icon = K.Where(id)
    local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    local name = K.Call(info, id)
    return K.Word(name) and name or nil, icon
end

-- What an item does when you use it, by the name of its own spell: the use
-- line for the grid's hover box, without a tooltip (Forever taints as soon
-- as an addon drives the game's). Nothing for an item with no use.
function K.Use(id)
    local spell = (C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
    local name = K.Call(spell, id)
    return K.Word(name) and name or nil
end

-- Everything in your bags that goes in that kind of slot, by name. One
-- entry a bag slot, so two of the same item are both offered.
function K.Bags(kind)
    local want = K.WORN[kind]
    local out = {}
    if not want then return out end
    local slots = (C_Container and C_Container.GetContainerNumSlots) or _G.GetContainerNumSlots
    local item = (C_Container and C_Container.GetContainerItemID) or _G.GetContainerItemID
    local last = K.Num(NUM_BAG_SLOTS) and NUM_BAG_SLOTS or 4
    for bag = 0, last do
        local count = K.Call(slots, bag)
        if K.Num(count) then
            for slot = 1, count do
                local id = K.Call(item, bag, slot)
                if K.Num(id) then
                    local place, icon = K.Where(id)
                    if place == want then
                        out[#out + 1] = { bag = bag, slot = slot, id = id, icon = icon, name = K.Name(bag, slot, id) }
                    end
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.name ~= b.name then return a.name < b.name end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end)
    return out
end

-- Puts a bag item on, through the game's own bag calls: the item picked up
-- and dropped on the slot. Never in a fight, where the game refuses a swap
-- anyway: the list greys out and says so instead. Anything the client
-- hasn't got, or a call that fails, leaves the cursor empty.
function K.Equip(entry, slot)
    if K.Fight() then return false, "fight" end
    if type(entry) ~= "table" or not K.Num(entry.bag) or not K.Num(entry.slot) or not K.Num(slot) then return false, "gone" end
    local pick = (C_Container and C_Container.PickupContainerItem) or _G.PickupContainerItem
    local put = _G.EquipCursorItem
    if type(pick) ~= "function" or type(put) ~= "function" then return false, "gone" end
    K.Call(ClearCursor)
    if not pcall(pick, entry.bag, entry.slot) then K.Call(ClearCursor); return false, "gone" end
    if not pcall(put, slot) then K.Call(ClearCursor); return false, "gone" end
    return true
end

---------------------------------------------------------------------------
-- The box the bar and the list wear
---------------------------------------------------------------------------

-- The look now, and the colour of its edge.
function K.Look()
    if E:GetSetting("darkMode") then
        local r, g, b = .42, .44, .48
        local grey = E.Classic and E.Classic.DarkGrey
        if grey then r, g, b = grey() end
        return K.LOOKS.dark, { r * .5, g * .5, b * .5 }
    end
    return K.LOOKS.classic, K.BRONZE
end

-- A fill and four edge strips on a frame, made once. The strips are placed
-- again at each paint, so a size change needs no new textures.
function K.Box(frame)
    local parts = { fill = frame:CreateTexture(nil, "BACKGROUND"), edges = {} }
    for i = 1, 4 do parts.edges[i] = frame:CreateTexture(nil, "BORDER") end
    parts.frame = frame
    return parts
end

function K.Paint(parts)
    if not parts then return end
    local look, edge = K.Look()
    local frame, size = parts.frame, look.edge
    parts.fill:SetTexture(K.FILL)
    parts.fill:SetVertexColor(look.fill[1], look.fill[2], look.fill[3], look.fill[4])
    parts.fill:SetAllPoints(frame)
    local top, bottom, left, right = parts.edges[1], parts.edges[2], parts.edges[3], parts.edges[4]
    for _, strip in ipairs(parts.edges) do
        strip:SetTexture(K.FILL)
        strip:SetVertexColor(edge[1], edge[2], edge[3], 1)
        strip:ClearAllPoints()
    end
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(size)
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(size)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -size)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, size)
    left:SetWidth(size)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -size)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, size)
    right:SetWidth(size)
end

-- A font string in the box's own font, made on a frame.
function K.Text(frame, size, layer)
    local text = frame:CreateFontString(nil, layer or "OVERLAY")
    if text:SetFont(K.FONT, size, "") == false then text:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
    text:SetShadowColor(0, 0, 0, 1)
    text:SetShadowOffset(1, -1)
    text:SetJustifyH("LEFT")
    return text
end

-- The box that shows as you point at a grid tile: EraUI's own small frame
-- (Look/Base.lua), above the tile, the item's name in the big font and its
-- use line under it in grey. Never the game's tooltip, which Forever taints
-- as soon as an addon drives it. A client or a test without Look shows
-- nothing instead of erroring.
function K.Tip(owner, title, lines)
    local Look = E.Look
    if not (Look and Look.ShowTip and owner and K.Word(title)) then return end
    local rows = { { title, 1, 1, 1 } }
    if type(lines) == "table" then
        for _, line in ipairs(lines) do
            if K.Word(line) then rows[#rows + 1] = { line, .62, .64, .68 } end
        end
    elseif K.Word(lines) then
        rows[2] = { lines, .62, .64, .68 }
    end
    Look.ShowTip(owner, "TOP", rows)
end

function K.Untip(owner)
    local Look = E.Look
    if Look and Look.HideTip then Look.HideTip(owner) end
end

-- The Queued strip across the top of a slot or a grid tile: a thin gold bar
-- with the word on it, so one look says what goes on the moment the fight
-- ends. Made hidden; the caller shows it with ShowQueue. One place owns it,
-- so the slot and the tile wear the same mark.
function K.QueueStrip(owner)
    local mark = { strip = owner:CreateTexture(nil, "OVERLAY") }
    mark.strip:SetTexture(K.FILL)
    mark.strip:SetVertexColor(K.GOLD[1], K.GOLD[2], K.GOLD[3], .85)
    mark.strip:SetHeight(K.QUEUE_H)
    mark.strip:SetPoint("TOPLEFT", owner, "TOPLEFT", 1, -1)
    mark.strip:SetPoint("TOPRIGHT", owner, "TOPRIGHT", -1, -1)
    mark.strip:Hide()
    mark.word = K.Text(owner, 8)
    mark.word:SetJustifyH("CENTER")
    mark.word:SetText(K.QUEUED)
    mark.word:SetTextColor(.05, .04, .02)
    mark.word:SetPoint("LEFT", mark.strip, "LEFT", 0, 0)
    mark.word:SetPoint("RIGHT", mark.strip, "RIGHT", 0, 0)
    mark.word:Hide()
    return mark
end

function K.ShowQueue(mark, on)
    if not mark then return end
    on = on and true or false
    mark.strip:SetShown(on)
    mark.word:SetShown(on)
end

-- A tick box, in /era's own shape (Core/SettingsRows.lua Rows.TickBox): a 14
-- square with a grey edge round a dark middle, and an 8 square in gold the
-- caller shows while the option is on. The caller places the box.
function K.TickBox(owner)
    local box = owner:CreateTexture(nil, "ARTWORK")
    box:SetSize(14, 14)
    box:SetColorTexture(K.GREY[1], K.GREY[2], K.GREY[3], 1)
    local fill = owner:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    fill:SetColorTexture(K.ROW_FILL[1], K.ROW_FILL[2], K.ROW_FILL[3], 1)
    local mark = owner:CreateTexture(nil, "OVERLAY")
    mark:SetSize(8, 8)
    mark:SetPoint("CENTER", box, "CENTER", 0, 0)
    mark:SetColorTexture(K.GOLD[1], K.GOLD[2], K.GOLD[3], 1)
    mark:Hide()
    return box, fill, mark
end

-- A slider, in /era's own shape (Core/SettingsRows.lua Rows.MakeSlider): 12
-- high, a dark fill, a thin grey edge and a gold thumb. Built here, not
-- called out of the options window, so the bar keeps no hold on it. The
-- caller sizes and places it.
function K.Slider(frame, low, high, step)
    local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    slider:SetHeight(12)
    slider:SetBackdrop(K.BACKDROP)
    slider:SetBackdropColor(K.ROW_FILL[1], K.ROW_FILL[2], K.ROW_FILL[3], 1)
    slider:SetBackdropBorderColor(K.GREY[1], K.GREY[2], K.GREY[3], 1)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)
    slider:SetThumbTexture(K.FILL)
    slider:GetThumbTexture():SetSize(10, 20)
    slider:GetThumbTexture():SetVertexColor(K.GOLD[1], K.GOLD[2], K.GOLD[3])
    return slider
end

-- A slider's setting as a whole number in its range; unreadable: its default.
function K.Setting(key, low, high, default)
    local v = tonumber(E:GetSetting(key))
    if not v or v ~= v or v == math.huge or v == -math.huge then v = default end
    return math.floor(math.max(low, math.min(high, v)) + .5)
end
