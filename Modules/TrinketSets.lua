local _, E = ...

-- Trinket sets (/era > Action Bars > Trinkets > Your Sets, the panel in
-- Modules/TrinketSetList.lua): a name and the item each slot held, so you can
-- put a whole set of trinkets back on with one click. They are this
-- character's own (your trinkets are), in EraUIClassicCharDB.trinketSets =
-- {version = 1, sets = {{name = "Fire fight", items = {[13] = 4500}, key = 3}}},
-- and there is no limit on how many you keep. key is one of the ten Trinket
-- Set keys in the game's Key Bindings menu (Modules/TrinketKeys.lua), or
-- nothing; no two sets ever hold the same one.
--
-- The game never lets gear change in a fight, so a set asked for in one is
-- kept and put on the moment the fight ends. That waiting list is here, and
-- it is the only one: anything else on the bar that has to wait for a fight
-- to end waits in it. It works with the bar switched off, and nothing of it
-- runs while the list is empty (the fight's end is watched only while
-- something waits).
--
-- A trinket clicked in the grid during a fight waits in the same list, one
-- item to a slot (Queue in a Fight). That is what the Queued strip on a slot
-- and on its tile reads, clicking the queued one again takes it back, and the
-- list is done in the order you asked for it, so a trinket queued after a set
-- leaves that one slot on the trinket.
--
-- Nothing here reads the game: the slots, what you wear, what you carry and
-- putting an item on are all Modules/TrinketKit.lua's, so one file still owns
-- every read and a hidden (secret) answer counts as unknown there.
local S = {}
E.TrinketSets = S

S.VERSION = 1
S.NAME_LETTERS = 24

local function K() return E.TrinketKit end
local function Keys() return E.TrinketKeys end
local function Grid() return E.TrinketList end

-- A set made, renamed, saved over, deleted or pointed at another key. Two
-- things follow every change. The ten Trinket Set entries in the game's Key
-- Bindings menu read the name of the set each one puts on
-- (Modules/TrinketKeys.lua), so those names are written again. And the
-- settings recovery is written again (Core/Persistence.lua keeps a copy of
-- this character's sets for a client that loses its SavedVariables): without
-- this it would hold none of the sets made this session until the next
-- logout, so a session that ended badly lost them all. A ring changed in its
-- own editor is kept the same way (Modules/ActionRings.lua Edited).
local function Kept()
    local keys = Keys()
    if keys and keys.Names then keys.Names() end
    if E.SaveSettings then E:SaveSettings() end
end

---------------------------------------------------------------------------
-- What is saved
---------------------------------------------------------------------------

-- A name as typed: colour and texture codes and bars out, spaces trimmed, at
-- most 24 letters (UTF-8 safe). Nothing left: nil.
function S.CleanName(text, most)
    if type(text) ~= "string" or not K().Public(text) then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|", "")
    text = text:gsub("%c", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    most = most or S.NAME_LETTERS
    local out, count = {}, 0
    for letter in text:gmatch("[\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > most then break end
        out[count] = letter
    end
    text = table.concat(out):match("^%s*(.-)%s*$")
    return text ~= "" and text or nil
end

-- A whole key slot, 1 to 10, or nil.
function S.ValidKey(slot)
    if type(slot) ~= "number" or slot ~= slot or slot % 1 ~= 0 then return nil end
    if slot < 1 or slot > K().KEYS then return nil end
    return slot
end

-- A set as it may be kept, or nil: a name, one whole item ID for each of
-- the four slots, and the key slot it answers to if it has one. An item is
-- kept by its ID, as the game gives it, so any copy of the right item does
-- the job.
function S.ValidSet(set)
    if type(set) ~= "table" then return nil end
    local name = S.CleanName(set.name)
    if not name then return nil end
    local out = {name = name, items = {}, key = S.ValidKey(set.key)}
    local items = type(set.items) == "table" and set.items or {}
    for _, info in ipairs(K().SLOTS) do
        local id = items[info.slot]
        if type(id) == "number" and id == id and id > 0 and id <= 2147483647 and id % 1 == 0 then
            out.items[info.slot] = id
        end
    end
    return out
end

-- The saved table checked. One of an unknown version starts empty, a copy of
-- it kept under old.
function S.Validate(store)
    local out = {version = S.VERSION, sets = {}}
    if type(store) ~= "table" then return out end
    if store.version ~= S.VERSION then
        out.old = store
        return out
    end
    if type(store.sets) == "table" then
        local taken = {}
        for _, set in ipairs(store.sets) do
            local good = S.ValidSet(set)
            if good then
                -- Two sets can never answer to the same key: the first of
                -- them in the list keeps it.
                if good.key and taken[good.key] then good.key = nil end
                if good.key then taken[good.key] = true end
                out.sets[#out.sets + 1] = good
            end
        end
    end
    if store.old ~= nil then out.old = store.old end
    return out
end

-- This character's sets, checked once a session (and again should the saved
-- table be replaced).
function S.Load()
    if type(EraUIClassicCharDB) ~= "table" then EraUIClassicCharDB = {} end
    local store = S.Validate(EraUIClassicCharDB.trinketSets)
    EraUIClassicCharDB.trinketSets = store
    S.store = store
    return store
end
function S.Store()
    if S.store and type(EraUIClassicCharDB) == "table" and EraUIClassicCharDB.trinketSets == S.store then return S.store end
    return S.Load()
end
function S.Sets() return S.Store().sets end
function S.Set(index) return S.Store().sets[index] end
function S.Count() return #S.Store().sets end
-- Where a set sits in the list now, or nil once it has been deleted.
function S.IndexOf(set)
    for index, other in ipairs(S.Store().sets) do
        if other == set then return index end
    end
end
-- The set one of the ten keys puts on, and where it sits in the list.
function S.Keyed(slot)
    if S.ValidKey(slot) == nil then return nil end
    for index, set in ipairs(S.Store().sets) do
        if set.key == slot then return set, index end
    end
end

---------------------------------------------------------------------------
-- Making and changing sets
---------------------------------------------------------------------------

-- "Set 1", or the lowest number no set is called yet.
local function NewName()
    local sets = S.Sets()
    local used = {}
    for _, set in ipairs(sets) do used[set.name] = true end
    for n = 1, #sets + 1 do
        local name = "Set " .. n
        if not used[name] then return name end
    end
    return "Set"
end

-- What you wear in the slots the bar shows now, by item ID. An empty slot
-- holds nothing, so nothing is kept for it.
function S.Wearing()
    local kit = K()
    local items = {}
    for _, info in ipairs(kit.Shown()) do
        local id = kit.Worn(info.slot)
        if id ~= nil then items[info.slot] = id end
    end
    return items
end

-- A new set of what you wear: its place in the list. It answers to no key
-- until you point it at one.
function S.New(name)
    local sets = S.Sets()
    sets[#sets + 1] = {name = S.CleanName(name) or NewName(), items = S.Wearing()}
    Kept()
    return #sets
end

-- What you wear now into a set you already have. A slot the bar is not
-- showing keeps what the set had for it, so hiding your rings never empties
-- them out of your sets.
function S.Over(index)
    local set = S.Set(index)
    if not set then return false end
    local worn = S.Wearing()
    for _, info in ipairs(K().Shown()) do set.items[info.slot] = worn[info.slot] end
    Kept()
    return true
end

-- Renamed: the name it now has. Nothing typed leaves the old name alone.
function S.Rename(set, text)
    if type(set) ~= "table" or not S.IndexOf(set) then return nil end
    local name = S.CleanName(text)
    if name then
        set.name = name
        Kept()
    end
    return set.name
end

-- A set pointed at one of the ten keys, or at none (slot nil). Two sets can
-- never answer to the same key, so taking one clears it from whichever set
-- held it; that set is given back, so the panel can say which lost its key.
function S.Key(set, slot)
    if type(set) ~= "table" or not S.IndexOf(set) then return false end
    if slot ~= nil and S.ValidKey(slot) == nil then return false end
    local lost
    if slot ~= nil then
        lost = S.Keyed(slot)
        if lost == set then
            lost = nil
        elseif lost then
            lost.key = nil
        end
    end
    set.key = slot
    Kept()
    return true, lost
end

-- The key slot after (step 1) or before (step -1) the one a set answers to,
-- going round through no key at all, so a click steps along the ten.
function S.NextKey(slot, step)
    local most = K().KEYS
    local at = S.ValidKey(slot) or 0
    at = at + (step == -1 and -1 or 1)
    if at < 0 then at = most end
    if at > most then at = 0 end
    if at == 0 then return nil end
    return at
end

---------------------------------------------------------------------------
-- Waiting for the fight to end
---------------------------------------------------------------------------

-- Queue in a Fight (on): a click in the grid during a fight keeps that item
-- for the slot. Off, the grid refuses the swap in a fight as it always did.
function S.Queueing() return E:GetSetting("trinketBarQueue") ~= false end

-- The bar's slots and the open grid both wear a Queued strip for what is
-- waiting, so both are drawn again whenever the waiting list changes.
local function Marked()
    local bar = E.modules and E.modules.TrinketBar
    if bar and bar.Marks then bar:Marks() end
    local grid = Grid()
    if grid and grid.Marks then grid.Marks() end
end

-- The ordered list of what is waiting, or nil while nothing is. A step says
-- what to do: {kind = "set", set = the set itself} for a whole set, or
-- {kind = "slot", slot = 13, entry = the bag entry} for one trinket queued
-- into one slot. A set step holds the set itself, never its place in the
-- list, so deleting or renaming another one while you wait changes nothing.
local waiting, told, watcher

local function Watch(on)
    if not on then
        if watcher then watcher:UnregisterAllEvents() end
        return
    end
    if not watcher then
        watcher = CreateFrame("Frame")
        watcher:SetScript("OnEvent", function() S.Apply() end)
    end
    pcall(watcher.RegisterEvent, watcher, "PLAYER_REGEN_ENABLED")
end

local function Empty()
    waiting, told = nil, false
    Watch(false)
end

-- Whatever is queued for one slot, out of the list. Answers whether anything
-- was.
local function Drop(slot)
    if not waiting then return false end
    local gone = false
    for at = #waiting, 1, -1 do
        local step = waiting[at]
        if step.kind == "slot" and step.slot == slot then
            table.remove(waiting, at)
            gone = true
        end
    end
    return gone
end

-- One more thing to do when the fight ends. A set covers every slot the bar
-- shows, so asking for one forgets every step asked for before it: one set
-- waits at a time and the last one you asked for is the one you get. One
-- trinket into one slot takes the place of whatever was queued for that slot
-- and goes to the end of the list, so the last thing you asked for is the
-- last thing done.
function S.Want(step)
    if type(step) ~= "table" then return false end
    if step.kind == "set" then
        waiting = nil
    elseif step.kind == "slot" then
        if not (K().Num(step.slot) and type(step.entry) == "table") then return false end
        Drop(step.slot)
    else
        return false
    end
    waiting = waiting or {}
    waiting[#waiting + 1] = step
    Watch(true)
    Marked()
    return true
end

function S.Waiting() return waiting end

-- What is queued for a slot, or nothing: the item a click in the grid asked
-- for while the fight was on. The Queued strip on a slot and the one on its
-- tile both read this.
function S.Queued(slot)
    if not waiting then return nil end
    for _, step in ipairs(waiting) do
        if step.kind == "slot" and step.slot == slot then return step.entry end
    end
end

-- The trinket queued for a slot taken back (its tile clicked again). With
-- nothing left waiting, the end of the fight stops being watched.
function S.Forget(slot)
    if not Drop(slot) then return false end
    if #waiting == 0 then Empty() end
    Marked()
    return true
end

-- Said once a fight, as the bar's own lines are.
function S.Later()
    if told then return false end
    told = true
    E:Status(K().SAID .. K().LATER)
    return true
end

---------------------------------------------------------------------------
-- Putting a set on
---------------------------------------------------------------------------

-- What loading a set has to do, in the slots the bar shows: the items it
-- wants that are not on you already, and the slots left to put them in. Both
-- trinket slots hold the same kind of thing, so a set whose two trinkets are
-- on the other way round is already on you and nothing moves. A slot the set
-- holds nothing for is left alone: loading a set puts things on, it never
-- takes them off.
function S.Jobs(set)
    local kit = K()
    local jobs = {}
    if type(set) ~= "table" or type(set.items) ~= "table" then return jobs end
    local kinds, order = {}, {}
    for _, info in ipairs(kit.Shown()) do
        local group = kinds[info.kind]
        if not group then
            group = {slots = {}, want = {}}
            kinds[info.kind], order[#order + 1] = group, info.kind
        end
        group.slots[#group.slots + 1] = info
        local id = set.items[info.slot]
        -- The slot the set holds it for goes with it, so it can go back where
        -- it was saved.
        if id ~= nil then group.want[#group.want + 1] = {slot = info.slot, id = id} end
    end
    for _, kind in ipairs(order) do
        local group = kinds[kind]
        -- How many of each item the set still wants out of your bags, once
        -- the slots already holding one are counted off, and which slots are
        -- left to fill.
        local left, free = {}, {}
        for _, want in ipairs(group.want) do left[want.id] = (left[want.id] or 0) + 1 end
        for _, info in ipairs(group.slots) do
            local worn = kit.Worn(info.slot)
            local have = (worn ~= nil and left[worn]) or 0
            if have > 0 then left[worn] = have - 1
            else free[#free + 1] = info end
        end
        -- What is left to put on, in the set's own order.
        local todo = {}
        for _, want in ipairs(group.want) do
            local have = left[want.id] or 0
            if have > 0 then
                left[want.id] = have - 1
                todo[#todo + 1] = want
            end
        end
        -- Each one into the slot the set holds it for while that slot is free,
        -- so a slot the set holds nothing for is left as it is; the rest take
        -- the free slots that are over, in the bar's own order.
        local open, over = {}, {}
        for _, info in ipairs(free) do open[info.slot] = true end
        for _, want in ipairs(todo) do
            if open[want.slot] then
                open[want.slot] = nil
                jobs[#jobs + 1] = {slot = want.slot, kind = kind, id = want.id}
            else
                over[#over + 1] = want
            end
        end
        for _, want in ipairs(over) do
            for _, info in ipairs(free) do
                if open[info.slot] then
                    open[info.slot] = nil
                    jobs[#jobs + 1] = {slot = info.slot, kind = kind, id = want.id}
                    break
                end
            end
        end
    end
    return jobs
end

-- A set onto you, now: each item it wants, found in your bags by its ID (a
-- bag can have moved since it was saved, so they are looked up afresh) and
-- put on through the kit. An item that is nowhere in your bags leaves that
-- slot as it is and is named in missing; the rest of the set still goes on.
function S.Put(set, missing)
    local kit = K()
    local jobs = S.Jobs(set)
    local carried, done = {}, 0
    for _, job in ipairs(jobs) do
        local bags = carried[job.kind]
        if not bags then
            bags = kit.Bags(job.kind)
            carried[job.kind] = bags
        end
        local found
        for _, entry in ipairs(bags) do
            if entry.id == job.id and not entry.taken then found = entry; break end
        end
        if found then found.taken = true end
        if found and kit.Equip(found, job.slot) then
            done = done + 1
        elseif missing then
            missing[#missing + 1] = kit.ById(job.id) or "Item"
        end
    end
    return done, #jobs
end

-- One queued trinket onto its slot. Your bags change while a fight goes on,
-- so the item is looked up afresh by its ID and put on from wherever it sits
-- now. Nowhere in your bags: that slot is left as it is and the item is named
-- in missing, as a set's own missing item is.
local function PutOne(step, missing)
    local kit = K()
    local entry = step.entry
    if type(entry) ~= "table" then return false end
    local info = kit.Info(step.slot)
    local found
    for _, other in ipairs(kit.Bags(info and info.kind or "trinket")) do
        if other.id == entry.id then found = other; break end
    end
    if found and kit.Equip(found, step.slot) then return true end
    if missing then missing[#missing + 1] = entry.name or kit.ById(entry.id) or "Item" end
    return false
end

-- Everything waiting, in the order it was asked for, out of a fight only.
-- Then the list is empty again and nothing is watched. The line about an item
-- that has gone is said once, with every name in it.
function S.Apply()
    local kit = K()
    if kit.Fight() then return false end
    local steps = waiting
    Empty()
    if not steps then return false end
    local missing = {}
    for _, step in ipairs(steps) do
        -- A set deleted while it waited is simply not put on.
        if step.kind == "set" then
            if S.IndexOf(step.set) then S.Put(step.set, missing) end
        elseif step.kind == "slot" then
            PutOne(step, missing)
        end
    end
    Marked()
    local line
    if #missing > 0 then
        line = string.format(kit.SKIPPED, table.concat(missing, ", "))
        E:Status(kit.SAID .. line)
    end
    return true, line
end

-- One item onto one slot, however the fight stands: put on there and then out
-- of a fight, or queued for the moment the fight ends in one, with the line
-- about the wait said once a fight. Answers "now", "later", or nothing and
-- the reason (the kit's "fight" where Queue in a Fight is off). The grid's
-- own clicks come through here, so there is one way in and one waiting list.
function S.Equip(entry, slot)
    local kit = K()
    if not kit.Fight() then
        local done, why = kit.Equip(entry, slot)
        if done then return "now" end
        return nil, why or "gone"
    end
    if not S.Queueing() then return nil, "fight" end
    if not S.Want({kind = "slot", slot = slot, entry = entry}) then return nil, "gone" end
    S.Later()
    return "later"
end

-- A set put on: at once out of a fight, or kept and put on the moment the
-- fight ends, with one line in chat saying so. Answers "now" (and the line
-- about anything that had gone), "later", or nil and "gone" for a set that
-- is not there.
function S.Wear(index)
    local set = S.Set(index)
    if not set then return nil, "gone" end
    S.Want({kind = "set", set = set})
    if K().Fight() then
        S.Later()
        return "later"
    end
    local _, line = S.Apply()
    return "now", line
end

-- Deleted. A set waiting for the fight to end goes out of the waiting list
-- with it, and anything else waiting stays. Its key is free again, and the
-- game's menu shows that key's plain name once more.
function S.Delete(index)
    local sets = S.Store().sets
    local set = sets[index]
    if not set then return false end
    table.remove(sets, index)
    Kept()
    if waiting then
        for at = #waiting, 1, -1 do
            if waiting[at].set == set then table.remove(waiting, at) end
        end
        if #waiting == 0 then Empty() end
    end
    return true
end
