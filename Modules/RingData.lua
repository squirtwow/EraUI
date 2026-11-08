local _, E = ...

-- Action Rings' saved rings (Modules/ActionRings.lua): this character's own
-- (spells differ by class), in EraUIClassicCharDB.actionRings =
-- {version = 1, rings = {[slot] = ring}}, slots 1 to 10, one per key.
-- A ring is {name, kind, slices}. Kind "custom" holds the slices you put in
-- it; the ready-made kinds (quest, raid, world, mounts, class) fill
-- themselves each time they're applied (Modules/RingFill.lua) and keep no
-- slices. A slice is {kind, id, name, icon, rank, hand}: name and icon are
-- kept to show it while it can't be used; rank ("top" or "exact") says
-- whether a spell follows the highest rank you know or keeps the one you put
-- in; hand (16 or 17) puts a poison on that weapon.
-- What a slice does is Attr: the secure attributes its click needs, which
-- Modules/RingSecure.lua writes on the ring's button. Everything read from
-- the game goes through pcall, and a hidden (secret) answer counts as unknown.
local D = {}
E.RingData = D

D.VERSION = 1
D.RINGS, D.SLICES, D.NAME_LETTERS = 10, 16, 24
D.RING_KINDS = {custom = true, quest = true, raid = true, world = true, mounts = true, class = true}
D.KIND_NAMES = {custom = "My Ring", quest = "Quest Items", raid = "Raid Markers", world = "World Markers", mounts = "Mounts"}
-- What a slice's id is, by kind.
D.ID_TYPES = {spell = "number", item = "number", macro = "string", mount = "number", pet = "string", toy = "number",
    equipmentset = "string", raidtarget = "number", worldmarker = "number"}
-- World markers' own numbers for the raid icons, in the raid icons' order
-- (Star, Circle, Diamond, Triangle, Moon, Square, Cross, Skull), as the
-- game's raid manager pairs them; and back.
D.WORLD_FOR_RAID = {5, 6, 3, 2, 7, 1, 4, 8}
D.RAID_FOR_WORLD = {}
for raid, world in ipairs(D.WORLD_FOR_RAID) do D.RAID_FOR_WORLD[world] = raid end
D.MARKER_NAMES = {"Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull"}
D.MARKER_ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"
D.CLEAR_ICON = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
D.UNKNOWN_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

---------------------------------------------------------------------------
-- Reading the game
---------------------------------------------------------------------------

function D.Public(v) return not (issecretvalue and issecretvalue(v)) end
function D.Num(v) return D.Public(v) and type(v) == "number" and v == v end
function D.Str(v) return D.Public(v) and type(v) == "string" and v ~= "" end
function D.Yes(v) return D.Public(v) and v == true end

local function Clean(n, v, ...)
    if n <= 0 then return end
    if not D.Public(v) then v = nil end
    if n == 1 then return v end
    return v, Clean(n - 1, ...)
end
local function After(ok, ...)
    if not ok then return end
    return Clean(select("#", ...), ...)
end
-- One of the game's functions: its answers, a secret one as nil; nothing at
-- all when it's missing or fails.
function D.Call(fn, ...)
    if type(fn) ~= "function" then return end
    return After(pcall(fn, ...))
end
-- A field of a table the game gave: nil when it's hidden.
function D.Field(t, key)
    if type(t) ~= "table" then return nil end
    local ok, value = pcall(function() return t[key] end)
    if not ok or not D.Public(value) then return nil end
    return value
end

---------------------------------------------------------------------------
-- Names and checking what's saved
---------------------------------------------------------------------------

-- A name as typed: colour and texture codes and bars out, spaces trimmed,
-- at most most letters (24 for a ring; UTF-8 safe). Empty: nil.
function D.CleanName(text, most)
    if not D.Public(text) or type(text) ~= "string" then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|", "")
    text = text:gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    most = most or D.NAME_LETTERS
    local out, count = {}, 0
    for letter in text:gmatch("[\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > most then break end
        out[count] = letter
    end
    text = table.concat(out):match("^%s*(.-)%s*$")
    return text ~= "" and text or nil
end

-- A ready-made ring's name, or a new empty one's: "Mage Ring" for the class ring.
function D.DefaultName(kind)
    if kind == "class" then
        local className = D.Call(UnitClass, "player")
        return (D.Str(className) and className or "Class") .. " Ring"
    end
    return D.KIND_NAMES[kind] or D.KIND_NAMES.custom
end

-- A slice as it may be kept, or nil: unknown kinds, ids of the wrong type
-- and markers out of range go.
function D.ValidSlice(slice)
    if type(slice) ~= "table" then return nil end
    local kind, id = slice.kind, slice.id
    local want = D.ID_TYPES[kind]
    if not want or type(id) ~= want then return nil end
    if want == "number" then
        if id ~= id or id % 1 ~= 0 or id > 2147483647 then return nil end
        local marker = kind == "raidtarget" or kind == "worldmarker"
        if marker and (id < 0 or id > 8) then return nil end
        if not marker and id < 1 then return nil end
    elseif #id > 64 then
        return nil
    end
    local out = {kind = kind, id = id, name = D.CleanName(slice.name, 64)}
    local icon = slice.icon
    if (type(icon) == "number" and icon == icon and icon > 0) or (type(icon) == "string" and icon ~= "" and #icon <= 200) then
        out.icon = icon
    end
    if kind == "spell" then out.rank = slice.rank == "exact" and "exact" or "top" end
    if kind == "item" and (slice.hand == 16 or slice.hand == 17) then out.hand = slice.hand end
    return out
end

-- A ring as it may be kept, or nil. A ready-made ring keeps no slices.
function D.ValidRing(ring)
    if type(ring) ~= "table" or not D.RING_KINDS[ring.kind] then return nil end
    local out = {kind = ring.kind, name = D.CleanName(ring.name) or D.DefaultName(ring.kind)}
    if ring.kind == "custom" then
        out.slices = {}
        if type(ring.slices) == "table" then
            for _, slice in ipairs(ring.slices) do
                local good = D.ValidSlice(slice)
                if good and #out.slices < D.SLICES then out.slices[#out.slices + 1] = good end
            end
        end
    end
    return out
end

-- The saved table checked: rings only at slots 1 to 10. One of an unknown
-- version starts empty, a copy of it kept under old.
function D.Validate(store)
    local out = {version = D.VERSION, rings = {}}
    if type(store) ~= "table" then return out end
    if store.version ~= D.VERSION then
        out.old = store
        return out
    end
    if type(store.rings) == "table" then
        for slot = 1, D.RINGS do out.rings[slot] = D.ValidRing(store.rings[slot]) end
    end
    if store.old ~= nil then out.old = store.old end
    return out
end

-- This character's rings, checked once a session (and again should the
-- saved table be replaced).
function D.Load()
    if type(EraUIClassicCharDB) ~= "table" then EraUIClassicCharDB = {} end
    local store = D.Validate(EraUIClassicCharDB.actionRings)
    EraUIClassicCharDB.actionRings = store
    D.store = store
    return store
end
function D.Store()
    if D.store and type(EraUIClassicCharDB) == "table" and EraUIClassicCharDB.actionRings == D.store then return D.store end
    return D.Load()
end
function D.Ring(slot) return D.Store().rings[slot] end
function D.Count()
    local count = 0
    for slot = 1, D.RINGS do if D.Store().rings[slot] then count = count + 1 end end
    return count
end

---------------------------------------------------------------------------
-- Changing rings (the editor, Modules/RingEditor.lua)
---------------------------------------------------------------------------

-- A new ring of that kind in the lowest free slot: its slot, or nil and
-- "full" with ten already.
function D.NewRing(kind)
    if not D.RING_KINDS[kind] then return nil, "kind" end
    local rings = D.Store().rings
    for slot = 1, D.RINGS do
        if not rings[slot] then
            rings[slot] = {kind = kind, name = D.DefaultName(kind), slices = kind == "custom" and {} or nil}
            return slot
        end
    end
    return nil, "full"
end
function D.DeleteRing(slot) D.Store().rings[slot] = nil end
-- Renamed (an empty name puts the kind's own back): the name it now has.
function D.Rename(slot, text)
    local ring = D.Ring(slot)
    if not ring then return nil end
    ring.name = D.CleanName(text) or D.DefaultName(ring.kind)
    return ring.name
end
-- A ready-made ring turned into one of your own, holding what it holds now.
function D.MakeEditable(slot, slices)
    local ring = D.Ring(slot)
    if not ring or ring.kind == "custom" then return false end
    ring.kind, ring.slices = "custom", {}
    for _, slice in ipairs(slices or {}) do
        local good = D.ValidSlice(slice)
        if good and #ring.slices < D.SLICES then ring.slices[#ring.slices + 1] = good end
    end
    return true
end
-- Adds a slice after slice after (or at the end): its place, or nil and why
-- ("full", "ready" for a ready-made ring, "bad").
function D.AddSlice(slot, slice, after)
    local ring = D.Ring(slot)
    if not ring then return nil, "bad" end
    if ring.kind ~= "custom" then return nil, "ready" end
    local good = D.ValidSlice(slice)
    if not good then return nil, "bad" end
    if #ring.slices >= D.SLICES then return nil, "full" end
    local at = #ring.slices + 1
    if type(after) == "number" and after >= 0 and after < #ring.slices then at = after + 1 end
    table.insert(ring.slices, at, good)
    return at
end
-- Moves slice k one place (step -1 earlier, 1 later): its new place, or nil.
function D.MoveSlice(slot, k, step)
    local ring = D.Ring(slot)
    local slices = ring and ring.slices
    local to = type(k) == "number" and k + step
    if not slices or not slices[k] or not to or to < 1 or to > #slices then return nil end
    slices[k], slices[to] = slices[to], slices[k]
    return to
end
function D.RemoveSlice(slot, k)
    local ring = D.Ring(slot)
    if not ring or not ring.slices or not ring.slices[k] then return false end
    table.remove(ring.slices, k)
    return true
end
-- Keep This Rank: a spell slice stays on the rank it holds, or follows the highest.
function D.SetKeepRank(slot, k, keep)
    local ring = D.Ring(slot)
    local slice = ring and ring.slices and ring.slices[k]
    if not slice or slice.kind ~= "spell" then return false end
    slice.rank = keep and "exact" or "top"
    return true
end

---------------------------------------------------------------------------
-- What a slice is and does
---------------------------------------------------------------------------

local function Fill() return E.RingFill end

-- A spell slice's spell ID to cast now: the rank it holds when it keeps it
-- (and you know it), else the highest rank you know of its name, else its
-- own ID if you know it. Nil while you know none.
function D.Resolve(slice, ranks)
    local F = Fill()
    local id = slice.id
    local name = F.SpellName(id) or slice.name
    if slice.rank == "exact" and F.Known(id) then return id end
    local top = ranks and name and ranks[name]
    if top and D.Num(top.id) then return top.id end
    if F.Known(id) then return id end
    return nil
end

local function MountInfo(id)
    local journal = C_MountJournal
    if not journal then return end
    local name, spellID, icon, _, _, _, favourite, _, _, hide, collected = D.Call(journal.GetMountInfoByID, id)
    return name, spellID, icon, collected == true and hide ~= true, favourite == true
end
D.MountInfo = MountInfo

local function PetInfo(guid)
    local journal = C_PetJournal
    if not journal then return end
    local species, custom, _, _, _, _, _, name, icon = D.Call(journal.GetPetInfoByPetID, guid)
    local revoked = D.Call(journal.PetIsRevoked, guid)
    return D.Str(custom) and custom or name, icon, D.Num(species) and revoked ~= true
end

local function SetID(name)
    local sets = C_EquipmentSet
    if not sets then return nil end
    local id = D.Call(sets.GetEquipmentSetID, name)
    return D.Num(id) and id or nil
end

-- The secure attributes a slice's click needs now: type, key, value,
-- action, slot (target-slot). No type when it can't do anything now (a
-- spell you don't know, a macro that's gone): it keeps its place, greyed.
-- ctx.ranks: the highest rank of each spell you know, by name.
function D.Attr(slice, ctx)
    local kind, id = slice.kind, slice.id
    if kind == "spell" then
        local cast = D.Resolve(slice, ctx and ctx.ranks)
        if cast then return "spell", "spell", cast end
    elseif kind == "item" then
        return "item", "item", "item:" .. id, nil, slice.hand
    elseif kind == "macro" then
        local index = D.Call(GetMacroIndexByName, id)
        if D.Num(index) and index > 0 then return "macro", "macro", id end
    elseif kind == "mount" then
        local _, spellID, _, usable = MountInfo(id)
        if usable and D.Num(spellID) then return "spell", "spell", spellID end
    elseif kind == "pet" then
        local _, _, owned = PetInfo(id)
        if owned then return "macro", "macrotext", "/summonpet " .. id end
    elseif kind == "toy" then
        if D.Call(PlayerHasToy, id) == true then return "toy", "toy", id end
    elseif kind == "equipmentset" then
        if SetID(id) then return "equipmentset", "equipmentset", id end
    elseif kind == "raidtarget" then
        if id == 0 then return "raidtarget", "marker", nil, "clear" end
        return "raidtarget", "marker", id, "toggle"
    elseif kind == "worldmarker" then
        if type(PlaceRaidMarker) ~= "function" then return nil end
        if id == 0 then return "worldmarker", "marker", nil, "clear" end
        return "worldmarker", "marker", id, "toggle"
    end
    return nil
end

local function MarkerName(raid)
    if raid == 0 then return nil end
    local name = _G["RAID_TARGET_" .. raid]
    return D.Str(name) and name or D.MARKER_NAMES[raid]
end
local function ItemName(id)
    local name = D.Call(C_Item and C_Item.GetItemNameByID, id)
    if not D.Str(name) then name = D.Call(C_Item and C_Item.GetItemInfo or GetItemInfo, id) end
    return D.Str(name) and name or nil
end
D.ItemName = ItemName
local function ItemIcon(id)
    local icon = D.Call(C_Item and C_Item.GetItemIconByID, id)
    if icon == nil then
        local _, _, _, _, instant = D.Call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, id)
        icon = instant
    end
    return icon
end
D.ItemIcon = ItemIcon

-- How a slice shows: its name and icon (the kept ones while the game gives
-- none), from what the game says now.
function D.Display(slice, ctx)
    local kind, id = slice.kind, slice.id
    local F = Fill()
    local name, icon
    if kind == "spell" then
        local cast = D.Resolve(slice, ctx and ctx.ranks) or id
        name, icon = F.SpellName(cast), F.SpellIcon(cast)
    elseif kind == "item" then
        name, icon = ItemName(id), ItemIcon(id)
        if slice.hand then
            name = (name or slice.name or "Item") .. (slice.hand == 17 and ", off hand" or ", main hand")
        end
    elseif kind == "macro" then
        local found, art = D.Call(GetMacroInfo, id)
        name, icon = D.Str(found) and found or nil, art
    elseif kind == "mount" then
        name, _, icon = MountInfo(id)
    elseif kind == "pet" then
        name, icon = PetInfo(id)
    elseif kind == "toy" then
        local _, toyName, art = D.Call(C_ToyBox and C_ToyBox.GetToyInfo, id)
        name, icon = toyName, art
    elseif kind == "equipmentset" then
        local set = SetID(id)
        local found, art = D.Call(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo, set)
        name, icon = D.Str(found) and found or id, art
    elseif kind == "raidtarget" then
        name = id == 0 and "Clear" or MarkerName(id)
        icon = id == 0 and D.CLEAR_ICON or D.MARKER_ICON .. id
    elseif kind == "worldmarker" then
        local raid = D.RAID_FOR_WORLD[id] or 0
        name = id == 0 and "Clear All" or MarkerName(raid)
        icon = id == 0 and D.CLEAR_ICON or D.MARKER_ICON .. raid
    end
    if not D.Str(name) then name = slice.name end
    if not (D.Num(icon) or D.Str(icon)) then icon = slice.icon end
    return name or "Unknown", icon or D.UNKNOWN_ICON
end

-- The editor's line about a slice: what it is, and why it's greyed.
function D.KindLine(slice, ready, ctx)
    local kind = slice.kind
    local line
    if kind == "spell" then
        if slice.rank == "exact" then
            local _, rank = Fill().SpellRank(slice.id)
            line = "Spell, kept at " .. (rank and ("Rank " .. rank) or "this rank")
        else
            line = "Spell, highest rank you know"
        end
    elseif kind == "item" then
        local count = D.Call(C_Item and C_Item.GetItemCount or GetItemCount, slice.id)
        line = "Item, " .. (D.Num(count) and count or 0) .. " in your bags"
    else
        line = ({macro = "Macro", mount = "Mount", pet = "Pet", toy = "Toy", equipmentset = "Equipment set",
            raidtarget = "Raid marker", worldmarker = "World marker"})[kind] or "Slice"
    end
    if not ready then line = line .. ". Can't be used now." end
    return line
end

---------------------------------------------------------------------------
-- Drag and drop
---------------------------------------------------------------------------

-- The highest rank you know of a spell's name, or nil.
local function TopFor(id)
    local F = Fill()
    local name = F.SpellName(id)
    local top = name and F.BestRanks().byName[name]
    return top
end

-- What the cursor holds (GetCursorInfo's answers) as a new slice, or nil
-- and the line to say. A spell keeps its rank when it's below the highest
-- you know (a deliberate lower rank); the highest follows new ranks.
function D.FromCursor(kind, a, b, c)
    local slice
    if kind == "spell" then
        local id = D.Num(c) and c or nil
        if not id and C_SpellBook and D.Num(a) then
            local info = D.Call(C_SpellBook.GetSpellBookItemInfo, a, b)
            id = D.Num(D.Field(info, "spellID")) and D.Field(info, "spellID") or D.Field(info, "actionID")
        end
        if D.Num(id) then
            local top = TopFor(id)
            slice = {kind = "spell", id = id, rank = (top and D.Num(top.id) and top.id ~= id) and "exact" or "top"}
        end
    elseif kind == "item" or kind == "toy" then
        if D.Num(a) then
            local toy = C_ToyBox and D.Call(C_ToyBox.GetToyInfo, a)
            if kind == "toy" or (toy and D.Call(PlayerHasToy, a) == true) then
                slice = {kind = "toy", id = a}
            else
                slice = {kind = "item", id = a}
            end
        end
    elseif kind == "macro" then
        local name = D.Num(a) and D.Call(GetMacroInfo, a)
        if D.Str(name) then slice = {kind = "macro", id = name} end
    elseif kind == "mount" then
        -- The journal's mount ID, or (on some clients) its place in the list.
        local id
        if D.Num(a) and select(4, MountInfo(a)) then id = a end
        if not id and D.Num(a) and C_MountJournal then
            local mountID = select(12, D.Call(C_MountJournal.GetDisplayedMountInfo, a))
            if D.Num(mountID) then id = mountID end
        end
        if id then slice = {kind = "mount", id = id} end
    elseif kind == "battlepet" then
        if D.Str(a) then slice = {kind = "pet", id = a} end
    elseif kind == "equipmentset" then
        local name = a
        if D.Num(a) then name = D.Call(C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo, a) end
        if D.Str(name) then slice = {kind = "equipmentset", id = name} end
    elseif kind == "companion" then
        -- Older clients' mounts: through the mount journal when it knows them.
        local _, _, spellID = D.Call(GetCompanionInfo, b, a)
        local mountID = D.Num(spellID) and C_MountJournal and D.Call(C_MountJournal.GetMountFromSpell, spellID)
        if D.Num(mountID) then slice = {kind = "mount", id = mountID} end
    end
    if not slice then return nil, "That can't go in a ring." end
    slice.name, slice.icon = D.Display(slice, {ranks = Fill().BestRanks().byName})
    return slice
end
