local _, E = ...

-- Action Rings' ready-made rings and the editor's pickers
-- (Modules/ActionRings.lua). A ready-made ring fills itself each time it's
-- applied, in a fixed order, at most 16 slices, leaving out what you can't
-- use: Quest Items (usable quest items, then items that start a quest),
-- Raid Markers, World Markers (only on a client that has them), Mounts
-- (favourites first, then bag mounts) and your class's ring
-- (Modules/RingClassData.lua). Spells are kept by name at the highest rank
-- you know (BestRanks: one look at your spellbook, kept until it changes).
-- Everything is read through RingData's guarded calls.
local F = {}
E.RingFill = F

local function D() return E.RingData end

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------

local ranks -- the last look at the spellbook, until SPELLS_CHANGED

-- "Rank 3" (or the client's own word): its number; 0 for a spell without ranks.
function F.RankOf(text)
    if not D().Str(text) then return 0 end
    return tonumber(text:match("(%d+)%s*$")) or 0
end

function F.SpellName(id)
    local Data = D()
    if not Data.Num(id) then return nil end
    local name = Data.Call(C_Spell and C_Spell.GetSpellName, id)
    if not Data.Str(name) and C_Spell and C_Spell.GetSpellInfo then
        name = Data.Field(Data.Call(C_Spell.GetSpellInfo, id), "name")
    end
    return Data.Str(name) and name or nil
end
function F.SpellIcon(id)
    local Data = D()
    if not Data.Num(id) then return nil end
    local icon = Data.Call(C_Spell and C_Spell.GetSpellTexture, id)
    if icon == nil and C_Spell and C_Spell.GetSpellInfo then icon = Data.Field(Data.Call(C_Spell.GetSpellInfo, id), "iconID") end
    return icon
end
-- A spell's name and its rank number (nil when it has none).
function F.SpellRank(id)
    local Data = D()
    local text = Data.Call(C_Spell and C_Spell.GetSpellSubtext, id)
    local rank = F.RankOf(text)
    return F.SpellName(id), rank > 0 and rank or nil
end

-- One look at your spellbook (not your pet's): every spell ID in it, and
-- each castable spell's highest rank by name ({id, rank}; rank 0 for one
-- without ranks). Hidden, guild and other-spec lines are skipped, as the
-- game's own page does.
function F.BestRanks()
    if ranks then return ranks end
    local Data = D()
    local byName, known = {}, {}
    local api = C_SpellBook
    local lines = api and Data.Call(api.GetNumSpellBookSkillLines)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    for line = 1, Data.Num(lines) and lines or 0 do
        local info = Data.Call(api.GetSpellBookSkillLineInfo, line)
        local offset, count = Data.Field(info, "itemIndexOffset"), Data.Field(info, "numSpellBookItems")
        local hidden = Data.Field(info, "shouldHide") or Data.Field(info, "isGuild")
        local offSpec = Data.Field(info, "offSpecID")
        if Data.Num(offset) and Data.Num(count) and not hidden and (offSpec == nil or offSpec == 0) then
            for slot = offset + 1, offset + count do
                F.Note(Data.Call(api.GetSpellBookItemInfo, slot, bank), spellType, byName, known)
            end
        end
    end
    F.EachProfessionSlot(function(slot)
        F.Note(Data.Call(api.GetSpellBookItemInfo, slot, bank), spellType, byName, known)
    end)
    ranks = {byName = byName, known = known}
    return ranks
end
-- Each profession's spellbook slots, which no skill line covers (its book:
-- spellOffset + 1 to + numAbilities).
function F.EachProfessionSlot(fn)
    local Data = D()
    if not (C_SpellBook and type(GetProfessions) == "function") then return end
    -- Primary, primary, then the secondary ones; a gap where one isn't learned.
    local indexes = {Data.Call(GetProfessions)}
    for i = 1, 6 do
        local index = indexes[i]
        local count, offset
        if Data.Num(index) then count, offset = select(5, Data.Call(GetProfessionInfo, index)) end
        if Data.Num(count) and Data.Num(offset) then
            for slot = offset + 1, offset + count do fn(slot) end
        end
    end
end
function F.Note(item, spellType, byName, known)
    local Data = D()
    if Data.Field(item, "itemType") ~= spellType then return end
    local id = Data.Field(item, "actionID")
    if not Data.Num(id) then id = Data.Field(item, "spellID") end
    if not Data.Num(id) then return end
    known[id] = true
    if Data.Field(item, "isPassive") ~= false then return end
    local name = Data.Field(item, "name")
    if not Data.Str(name) then return end
    local rank = F.RankOf(Data.Field(item, "subName"))
    local top = byName[name]
    if not top or rank > top.rank then byName[name] = {id = id, rank = rank} end
end
-- The spellbook changed (a new spell or rank): the next look is a fresh one.
function F.Invalidate() ranks = nil end

-- Whether you know a spell: in the last look at your spellbook, or by the game's word.
function F.Known(id)
    local Data = D()
    if not Data.Num(id) then return false end
    if F.BestRanks().known[id] then return true end
    if IsPlayerSpell and Data.Call(IsPlayerSpell, id) == true then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and Data.Call(C_SpellBook.IsSpellKnown, id) == true then return true end
    return IsSpellKnown ~= nil and Data.Call(IsSpellKnown, id) == true
end

-- A spell slice at the highest rank you know, or nil while you know none.
local function Spell(id)
    local slice = {kind = "spell", id = id, rank = "top"}
    local cast = D().Resolve(slice, F.BestRanks().byName)
    if not cast then return nil end
    slice.name, slice.icon = F.SpellName(cast), F.SpellIcon(cast)
    return slice
end
F.Spell = Spell

---------------------------------------------------------------------------
-- Bags
---------------------------------------------------------------------------

-- Each item in your bags, once per item ID, in bag order: fn(itemID, info, bag, slot).
function F.EachBagItem(fn)
    local Data = D()
    local api = C_Container
    if not api then return end
    local seen = {}
    for bag = 0, NUM_BAG_SLOTS or 4 do
        local slots = Data.Call(api.GetContainerNumSlots, bag)
        for slot = 1, Data.Num(slots) and slots or 0 do
            local info = Data.Call(api.GetContainerItemInfo, bag, slot)
            local id = Data.Field(info, "itemID")
            if Data.Num(id) and not seen[id] then
                seen[id] = true
                fn(id, info, bag, slot)
            end
        end
    end
end

local function ItemClass(id)
    local Data = D()
    local _, _, _, _, icon, classID, subID = Data.Call(C_Item and C_Item.GetItemInfoInstant or GetItemInfoInstant, id)
    return classID, subID, icon
end
local function UseSpell(id)
    local Data = D()
    local name, spellID = Data.Call(C_Item and C_Item.GetItemSpell or GetItemSpell, id)
    return Data.Str(name) or Data.Num(spellID)
end
local function ItemSlice(id, info, hand)
    local Data = D()
    local name = Data.Field(info, "itemName")
    if not Data.Str(name) then name = Data.ItemName(id) end
    local icon = Data.Field(info, "iconFileID")
    if icon == nil then icon = Data.ItemIcon(id) end
    return {kind = "item", id = id, name = name, icon = icon, hand = hand}
end

-- Usable quest items first, then items that start a quest, in bag order.
function F.QuestItems()
    local Data = D()
    local usable, starters = {}, {}
    local api = C_Container
    F.EachBagItem(function(id, info, bag, slot)
        local quest = api and Data.Call(api.GetContainerItemQuestInfo, bag, slot)
        local isQuest = Data.Field(quest, "isQuestItem") == true
        if not isQuest and ItemClass(id) == 12 then isQuest = true end
        local questID, active = Data.Field(quest, "questID"), Data.Field(quest, "isActive")
        if isQuest and UseSpell(id) then
            usable[#usable + 1] = ItemSlice(id, info)
        elseif Data.Num(questID) and active == false then
            starters[#starters + 1] = ItemSlice(id, info)
        end
    end)
    for _, slice in ipairs(starters) do usable[#usable + 1] = slice end
    return usable
end

---------------------------------------------------------------------------
-- Markers, mounts, pets, toys, macros and sets
---------------------------------------------------------------------------

function F.RaidMarkers()
    local list = {}
    for raid = 1, 8 do list[raid] = {kind = "raidtarget", id = raid} end
    list[9] = {kind = "raidtarget", id = 0}
    return list
end
-- Only on a client with ground markers (whether the server places them is
-- for the player's test in a group).
function F.WorldMarkersAvailable() return type(PlaceRaidMarker) == "function" end
function F.WorldMarkers()
    if not F.WorldMarkersAvailable() then return {} end
    local list = {}
    for raid = 1, 8 do list[raid] = {kind = "worldmarker", id = D().WORLD_FOR_RAID[raid]} end
    list[9] = {kind = "worldmarker", id = 0}
    return list
end

-- Your collected mounts, favourites first then by name; then mounts in your
-- bags (reins and whistles) the journal hasn't named already.
function F.Mounts()
    local Data = D()
    local list, named = {}, {}
    local journal = C_MountJournal
    local ids = journal and Data.Call(journal.GetMountIDs)
    if type(ids) == "table" then
        for _, id in ipairs(ids) do
            local name, _, icon, usable, favourite = Data.MountInfo(id)
            if usable and Data.Str(name) then
                list[#list + 1] = {kind = "mount", id = id, name = name, icon = icon, favourite = favourite}
                named[name] = true
            end
        end
    end
    table.sort(list, function(a, b)
        if a.favourite ~= b.favourite then return a.favourite end
        return a.name < b.name
    end)
    for _, slice in ipairs(list) do slice.favourite = nil end
    F.EachBagItem(function(id, info)
        local classID, subID = ItemClass(id)
        if classID == 15 and subID == 5 then
            local slice = ItemSlice(id, info)
            if not (slice.name and named[slice.name]) then list[#list + 1] = slice end
        end
    end)
    return list
end

-- A rogue's poisons: the highest rank it carries of each kind, for the main
-- hand, then (with a weapon in the off hand) the same for the off hand.
function F.Poisons()
    local Data = D()
    local data = E.PoisonData
    local list = {}
    if not (data and data.families) then return list end
    local byKey = {}
    for _, family in ipairs(data.families) do byKey[family.key] = family end
    local carried = {}
    for _, key in ipairs(E.RingClassData.POISON_ORDER) do
        local family = byKey[key]
        local ranks = family and family.ranks or {}
        for r = #ranks, 1, -1 do
            local count = Data.Call(C_Item and C_Item.GetItemCount or GetItemCount, ranks[r].item)
            if Data.Num(count) and count > 0 then carried[#carried + 1] = ranks[r].item; break end
        end
    end
    local off = Data.Call(GetInventoryItemID, "player", 17)
    local offWeapon = Data.Num(off) and ItemClass(off) == 2
    for _, hand in ipairs({16, 17}) do
        if hand == 16 or offWeapon then
            for _, id in ipairs(carried) do list[#list + 1] = ItemSlice(id, nil, hand) end
        end
    end
    return list
end

-- Your class's ring: each spell at the highest rank you know; a pick, the
-- first of its spells you know.
function F.ClassRing(token)
    local data = E.RingClassData and E.RingClassData[token]
    if type(data) ~= "table" then return {} end
    if data.poisons then return F.Poisons() end
    local list = {}
    for _, entry in ipairs(data) do
        for _, id in ipairs(type(entry) == "table" and entry.pick or {entry}) do
            local slice = Spell(id)
            if slice then list[#list + 1] = slice; break end
        end
    end
    return list
end

local function ClassToken()
    local _, token = D().Call(UnitClass, "player")
    return D().Str(token) and token or nil
end
F.ClassToken = ClassToken

-- A ring's slices now, at most 16: a ready-made ring's fill, or copies of
-- yours (so nothing the view or the buttons note lands in what's saved).
function F.Slices(ring)
    local list
    local kind = ring and ring.kind
    if kind == "custom" then
        list = {}
        for i, slice in ipairs(ring.slices or {}) do
            local copy = {}
            for key, value in pairs(slice) do copy[key] = value end
            list[i] = copy
        end
    elseif kind == "quest" then list = F.QuestItems()
    elseif kind == "raid" then list = F.RaidMarkers()
    elseif kind == "world" then list = F.WorldMarkers()
    elseif kind == "mounts" then list = F.Mounts()
    elseif kind == "class" then list = F.ClassRing(ClassToken())
    else list = {} end
    for i = #list, D().SLICES + 1, -1 do list[i] = nil end
    return list
end

---------------------------------------------------------------------------
-- The editor's pickers: everything of a kind you could put in a ring
---------------------------------------------------------------------------

-- Your spellbook's spells (not passive), the highest rank of each, by line.
function F.PickSpells()
    local Data = D()
    local list, seen = {}, {}
    local best = F.BestRanks().byName
    local api = C_SpellBook
    local lines = api and Data.Call(api.GetNumSpellBookSkillLines)
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    for line = 1, Data.Num(lines) and lines or 0 do
        local info = Data.Call(api.GetSpellBookSkillLineInfo, line)
        local offset, count = Data.Field(info, "itemIndexOffset"), Data.Field(info, "numSpellBookItems")
        local hidden = Data.Field(info, "shouldHide") or Data.Field(info, "isGuild")
        if Data.Num(offset) and Data.Num(count) and not hidden then
            for slot = offset + 1, offset + count do
                local item = Data.Call(api.GetSpellBookItemInfo, slot, bank)
                local name = Data.Field(item, "name")
                local top = Data.Str(name) and best[name]
                if top and not seen[name] then
                    seen[name] = true
                    list[#list + 1] = {kind = "spell", id = top.id, rank = "top", name = name, icon = F.SpellIcon(top.id)}
                end
            end
        end
    end
    return list
end

-- Each profession's own spells.
function F.PickProfessions()
    local Data = D()
    local list = {}
    local api = C_SpellBook
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    F.EachProfessionSlot(function(slot)
        local item = Data.Call(api.GetSpellBookItemInfo, slot, bank)
        local id = Data.Field(item, "spellID") or Data.Field(item, "actionID")
        if Data.Num(id) and Data.Field(item, "isPassive") ~= true then
            list[#list + 1] = {kind = "spell", id = id, rank = "top", name = Data.Field(item, "name"), icon = F.SpellIcon(id)}
        end
    end)
    return list
end

-- Bag items with a Use, or that start a quest.
function F.PickItems()
    local Data = D()
    local list = {}
    local api = C_Container
    F.EachBagItem(function(id, info, bag, slot)
        local quest = api and Data.Call(api.GetContainerItemQuestInfo, bag, slot)
        if UseSpell(id) or Data.Num(Data.Field(quest, "questID")) then list[#list + 1] = ItemSlice(id, info) end
    end)
    return list
end

F.PickMounts = F.Mounts

-- Your pets (the Collections list, with its own search and filters).
function F.PickPets()
    local Data = D()
    local list = {}
    local journal = C_PetJournal
    local count = journal and Data.Call(journal.GetNumPets)
    for i = 1, Data.Num(count) and count or 0 do
        local guid, _, owned, custom, _, _, revoked, name, icon = Data.Call(journal.GetPetInfoByIndex, i)
        if Data.Str(guid) and owned == true and revoked ~= true then
            list[#list + 1] = {kind = "pet", id = guid, name = Data.Str(custom) and custom or name, icon = icon}
        end
    end
    return list
end

-- Your toys (the Toy Box's list, with its own search and filters).
function F.PickToys()
    local Data = D()
    local list = {}
    local box = C_ToyBox
    local count = box and Data.Call(box.GetNumFilteredToys)
    for i = 1, Data.Num(count) and count or 0 do
        local id = Data.Call(box.GetToyFromIndex, i)
        if Data.Num(id) and id > 0 and Data.Call(PlayerHasToy, id) == true then
            local _, name, icon = Data.Call(box.GetToyInfo, id)
            list[#list + 1] = {kind = "toy", id = id, name = name, icon = icon}
        end
    end
    return list
end

-- Account macros, then this character's.
function F.PickMacros()
    local Data = D()
    local list = {}
    local account, character = Data.Call(GetNumMacros)
    local first = tonumber(MAX_ACCOUNT_MACROS) or 120
    local function Add(index)
        local name, icon = Data.Call(GetMacroInfo, index)
        if Data.Str(name) then list[#list + 1] = {kind = "macro", id = name, name = name, icon = icon} end
    end
    for i = 1, Data.Num(account) and account or 0 do Add(i) end
    for i = 1, Data.Num(character) and character or 0 do Add(first + i) end
    return list
end

function F.PickSets()
    local Data = D()
    local list = {}
    local sets = C_EquipmentSet
    local ids = sets and Data.Call(sets.GetEquipmentSetIDs)
    for _, id in ipairs(type(ids) == "table" and ids or {}) do
        local name, icon = Data.Call(sets.GetEquipmentSetInfo, id)
        if Data.Str(name) then list[#list + 1] = {kind = "equipmentset", id = name, name = name, icon = icon} end
    end
    return list
end

-- Raid markers, then (on their own row in the editor: the second return,
-- the places a new row starts) the world markers, which look the same.
function F.PickMarkers()
    local list = F.RaidMarkers()
    local breaks = {}
    for i, slice in ipairs(F.WorldMarkers()) do
        if i == 1 then breaks[#list + 1] = true end
        list[#list + 1] = slice
    end
    return list, breaks
end

-- The pickers, in the editor's order: {id, button name, list (and where its
-- new rows start), empty line}.
F.PICKERS = {
    {"spells", "Spells", F.PickSpells, "No spells found."},
    {"professions", "Professions", F.PickProfessions, "No profession spells found."},
    {"items", "Items", F.PickItems, "No usable items in your bags."},
    {"mounts", "Mounts", F.PickMounts, "No mounts found."},
    {"pets", "Pets", F.PickPets, "No pets found. Clear the search in Collections, or drag one in."},
    {"toys", "Toys", F.PickToys, "No toys yet. Clear the search in Collections, or drag one in."},
    {"macros", "Macros", F.PickMacros, "No macros yet."},
    {"sets", "Sets", F.PickSets, "No equipment sets yet. Make one in your character window."},
    {"markers", "Markers", F.PickMarkers, "No markers."},
}
