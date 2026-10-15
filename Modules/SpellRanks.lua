local _, EraUI = ...

-- Upgrade Spell Ranks (/era > Action Bars). Forever keeps a
-- spell on its old rank when you train a new one. With this on, the rank you
-- just outgrew moves up to the new one wherever it sits on your bars: every
-- action slot the game's bars use (action bar addons use the same ones) and
-- the gamepad bars' own. Only the slots holding the previous highest rank
-- change, so a lower rank placed on purpose (a healer's downrank) stays.
-- Macros, items and everything else are never touched. In a fight it waits
-- until the fight ends; while the cursor holds something it waits until the
-- cursor is free. Talent spells and spells without ranks are left alone.
--
-- How a new rank is told apart: a look at the spellbook keeps each spell's
-- highest rank by name. Forever's spellbook lists every rank you know (the
-- page only hides the lower ones, C_SpellBook.IsSpellBookItemLowRank), so
-- the old rank's spell ID is always there. A later look that finds a higher
-- rank the game has just taught (LEARNED_SPELL_IN_SKILL_LINE, or a spell no
-- look had seen since the first) moves the old rank's slots up to it. The
-- first look after login, or after the option is switched on, is only the
-- starting point: what you know then stays where you put it.
--
-- Nothing is written on the game's frames. The only calls that change
-- anything are the game's own action slot ones (pick up the spell, place it,
-- clear the cursor), out of combat; each slot is read back afterwards and put
-- back as it was if it isn't the new rank. If the game redraws its own
-- buttons inside that call, their slot key could be left tainted for a
-- fight: the buttons are read (never written) before and after a pass, and
-- one line asks for a /reload if one went from secure to tainted.
local Module = {}
EraUI:RegisterModule("SpellRanks", Module)

local wipe = wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
local GAMEPAD_SLOTS = 400        -- the most gamepad slots looked at past the first one
local best = {}                  -- spell name -> its highest rank: {rank = 3, id = spellID, text = "Rank 3"}
local known = {}                 -- every spell ID a look has seen
local fresh = {}                 -- spell IDs first seen after the starting point
local learned = {}               -- spell IDs the game said it taught since then
local pending = {}               -- old rank's spell ID -> new rank's spell ID, still to place
local labels = {}                -- new rank's spell ID -> {name, text}, for the chat line
local ready = false              -- the starting look has been taken
local scanQueued, cursorWait = false, false
local scanAfterFight = false     -- a look was asked for in a fight
local warned = false             -- the /reload line has been said this session

local function Public(v) return not (issecretvalue and issecretvalue(v)) end
local function Number(v) return Public(v) and type(v) == "number" end
local function Enabled()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("upgradeSpellRanks") == true
end

-- "Rank 3" (or the client's own word for rank): the number at its end.
local function RankOf(text)
    if not Public(text) or type(text) ~= "string" then return nil end
    return tonumber(text:match("^%D*(%d+)%s*$"))
end

-- A talent's spell (class or PvP talent) is left alone, and so is one the
-- game won't say about.
local function Asked(fn, slot, bank)
    if not fn then return false end
    local ok, yes = pcall(fn, slot, bank)
    if not ok or not Public(yes) then return true end
    return yes and true or false
end
local function Talent(api, slot, bank)
    return Asked(api.IsClassTalentSpellBookItem, slot, bank) or Asked(api.IsPvPTalentSpellBookItem, slot, bank)
end

-- One spellbook entry: its spell ID goes in ids whatever it is (its rank
-- text may not be loaded yet), and a ranked, castable, non-talent spell
-- counts towards its name's highest rank in tops.
local function Entry(api, slot, bank, tops, ids)
    local ok, item = pcall(api.GetSpellBookItemInfo, slot, bank)
    if not ok or type(item) ~= "table" then return end
    local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell or 1
    if not Public(item.itemType) or item.itemType ~= spellType then return end
    local id = item.actionID
    if not Number(id) then id = item.spellID end
    if not Number(id) then return end
    ids[id] = true
    if not Public(item.isPassive) or item.isPassive then return end
    local name = item.name
    if not Public(name) or type(name) ~= "string" or name == "" then return end
    local rank = RankOf(item.subName)
    if not rank or Talent(api, slot, bank) then return end
    local top = tops[name]
    if not top or rank > top.rank then tops[name] = {rank = rank, id = id, text = item.subName} end
end

-- A look at the player's spellbook (not the pet's): each spell's highest
-- rank by name, and every spell ID. Hidden, guild and other-spec lines are
-- skipped, like the game's own page does. Nil when it can't be read.
local function Look()
    local api = C_SpellBook
    if not (api and api.GetNumSpellBookSkillLines and api.GetSpellBookSkillLineInfo and api.GetSpellBookItemInfo) then return nil end
    local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
    local ok, lines = pcall(api.GetNumSpellBookSkillLines)
    if not ok or not Number(lines) then return nil end
    local tops, ids = {}, {}
    for line = 1, lines do
        local okLine, info = pcall(api.GetSpellBookSkillLineInfo, line)
        if okLine and type(info) == "table" and Public(info.shouldHide) and Public(info.isGuild) and Public(info.offSpecID)
            and not info.shouldHide and not info.isGuild and (info.offSpecID == nil or info.offSpecID == 0)
            and Number(info.itemIndexOffset) and Number(info.numSpellBookItems) then
            for slot = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                Entry(api, slot, bank, tops, ids)
            end
        end
    end
    return tops, ids
end

-- Old rank to new, joined onto anything already waiting: Rank 1 waiting for
-- Rank 2 goes straight to Rank 3 when that comes before the bars are free.
local function Queue(old, new, name, text)
    for from, to in pairs(pending) do
        if to == old then pending[from] = new end
    end
    pending[old] = new
    labels[new] = {name = name, text = text}
end

-- Looks again and compares with the last look.
function Module:Scan()
    local tops, ids = Look()
    if not tops then return end
    if not ready then
        -- The starting point needs the spellbook to be there.
        if next(ids) == nil then return end
        wipe(best); wipe(known); wipe(fresh); wipe(learned)
        for name, top in pairs(tops) do best[name] = top end
        for id in pairs(ids) do known[id] = true end
        ready = true
        return
    end
    for id in pairs(ids) do
        if not known[id] then known[id] = true; fresh[id] = true end
    end
    for name, top in pairs(tops) do
        local before = best[name]
        if before and top.rank > before.rank and top.id ~= before.id and (learned[top.id] or fresh[top.id]) then
            Queue(before.id, top.id, name, top.text)
        end
        -- Once a look has seen it at the top, it's no longer new: a rank
        -- that drops away and comes back (a respec) moves nothing.
        best[name] = top
        fresh[top.id], learned[top.id] = nil, nil
    end
end

-- Every action slot the player fills: the game's pages of twelve up to the
-- last multi-bar page (15 on Forever, so 1 to 180), less the vehicle,
-- override and temporary shapeshift pages the game fills itself, then the
-- gamepad bars' own slots where the client has them.
local function Slots()
    local per = tonumber(NUM_ACTIONBAR_BUTTONS) or 12
    local pages = tonumber(MULTIBAR_7_ACTIONBAR_PAGE) or 10
    local skip, list, listed = {}, {}, {}
    local bars = C_ActionBar or {}
    for _, page in ipairs({"GetVehicleBarIndex", "GetOverrideBarIndex", "GetTempShapeshiftBarIndex"}) do
        if bars[page] then
            local ok, index = pcall(bars[page])
            if ok and Number(index) then skip[index] = true end
        end
    end
    for slot = 1, pages * per do
        if not skip[math.floor((slot - 1) / per) + 1] then list[#list + 1] = slot; listed[slot] = true end
    end
    local pad = C_GamepadUI
    if pad and pad.GetFirstGamepadActionStorageSlotIndex and pad.IsValidGamepadActionStorageSlotIndex then
        local ok, first = pcall(pad.GetFirstGamepadActionStorageSlotIndex)
        if ok and Number(first) and first > 0 then
            for slot = first, first + GAMEPAD_SLOTS - 1 do
                local okValid, valid = pcall(pad.IsValidGamepadActionStorageSlotIndex, slot)
                if not okValid or not Public(valid) or not valid then break end
                if not listed[slot] then list[#list + 1] = slot; listed[slot] = true end
            end
        end
    end
    return list
end

-- What a slot holds, as the game says ("spell", spellID), or nothing when
-- it can't be read or is secret.
local function ActionAt(slot)
    if not GetActionInfo then return nil end
    local ok, kind, id = pcall(GetActionInfo, slot)
    if not ok or not Public(kind) or not Public(id) then return nil end
    return kind, id
end

-- What the cursor holds ("spell", "item"...), false when it's free, or "?"
-- when it can't be told. A spell waiting for its target counts as held.
local function Cursor()
    if not GetCursorInfo then return "?" end
    local ok, kind = pcall(GetCursorInfo)
    if not ok or not Public(kind) then return "?" end
    if kind ~= nil then return kind end
    if SpellIsTargeting then
        local okTarget, targeting = pcall(SpellIsTargeting)
        if not okTarget or not Public(targeting) or targeting then return "?" end
    end
    return false
end

local function Pickup(spellID)
    local pick = C_Spell and C_Spell.PickupSpell or PickupSpell
    if pick then pcall(pick, spellID) end
end
local function Clear()
    if ClearCursor then pcall(ClearCursor) end
end

-- One slot from the old rank to the new: true when it holds the new rank.
-- Anything else puts the old rank back.
local function Swap(slot, old, new)
    Pickup(new)
    if Cursor() ~= "spell" then Clear(); return false end
    pcall(PlaceAction, slot)
    Clear()
    local kind, id = ActionAt(slot)
    if kind == "spell" and id == new then return true end
    if kind ~= "spell" or id ~= old then
        Pickup(old)
        if Cursor() == "spell" then pcall(PlaceAction, slot) end
        Clear()
    end
    return false
end

local function Buttons(count) return count .. (count == 1 and " button" or " buttons") end
-- One quiet line: the spell and how many buttons moved up.
local function Report(moved, order)
    if #order == 0 then return end
    if #order == 1 then
        local label = labels[order[1]]
        EraUI:Print(label.name .. " moved up to " .. label.text .. " on " .. Buttons(moved[order[1]]) .. ".")
        return
    end
    local parts = {}
    for _, new in ipairs(order) do
        parts[#parts + 1] = labels[new].name .. " to " .. labels[new].text .. " (" .. Buttons(moved[new]) .. ")"
    end
    EraUI:Print("Moved up on your bars: " .. table.concat(parts, ", ") .. ".")
end
-- "Fireball", "Fireball and Frostbolt", "Fireball, Frostbolt and Blizzard".
local function Names(list)
    if #list == 1 then return list[1] end
    return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

-- The game's own action buttons whose slot key reads secure now (read
-- only), or nil when the game can't say.
local function SecureButtons()
    local events = ActionBarButtonEventsFrame
    local list = issecurevariable and type(events) == "table" and events.frames
    if type(list) ~= "table" then return nil end
    local secure = {}
    for _, button in pairs(list) do
        local ok, yes = pcall(issecurevariable, button, "action")
        if ok and Public(yes) and yes then secure[button] = true end
    end
    return secure
end
-- One of them tainted since: the game redrew it inside EraUI's call, and it
-- could misbehave in a fight until a /reload.
local function Tainted(secure)
    for button in pairs(secure) do
        local ok, yes = pcall(issecurevariable, button, "action")
        if ok and Public(yes) and not yes then return true end
    end
    return false
end

-- Tries again in a second while the cursor is busy.
local function WaitForCursor()
    if cursorWait or not (C_Timer and C_Timer.After) then return end
    cursorWait = true
    C_Timer.After(1, function()
        cursorWait = false
        Module:Apply()
    end)
end

-- Moves every waiting rank up on the bars, out of combat with a free cursor.
function Module:Apply()
    if not Enabled() or next(pending) == nil then return end
    -- In a fight: PLAYER_REGEN_ENABLED brings it back.
    if InCombatLockdown() then return end
    if Cursor() ~= false then WaitForCursor(); return end
    if not PlaceAction then wipe(pending); return end
    local moved, order, broken, failed, secure = {}, {}, {}, {}, nil
    for _, slot in ipairs(Slots()) do
        local kind, id = ActionAt(slot)
        local new = kind == "spell" and pending[id]
        -- A spell one button didn't take stays as it is on the rest of the
        -- bars; every other spell waiting still moves up.
        if new and not broken[new] then
            if secure == nil then secure = SecureButtons() or false end
            if Swap(slot, id, new) then
                if not moved[new] then moved[new] = 0; order[#order + 1] = new end
                moved[new] = moved[new] + 1
            else
                broken[new] = true
                failed[#failed + 1] = labels[new].name
            end
        end
    end
    wipe(pending)
    Report(moved, order)
    if #failed > 0 then
        EraUI:Print(Names(failed) .. " couldn't move up on some of your buttons, so they're left as they were.")
    end
    if secure and not warned and Tainted(secure) then
        warned = true
        EraUI:Print("Please /reload before your next fight: the game's action buttons didn't take the rank change cleanly.")
    end
    wipe(labels)
end

-- Looks again and moves what's waiting up. A look in a fight would be
-- wasted (the bars can't change until it ends), so it waits for the end too.
local function ScanNow()
    if not Enabled() then return end
    if InCombatLockdown() then scanAfterFight = true; return end
    scanAfterFight = false
    Module:Scan()
    Module:Apply()
end

local function QueueScan()
    if scanQueued then return end
    if not (C_Timer and C_Timer.After) then ScanNow(); return end
    -- A trainer's Train All teaches several at once: one look after them.
    scanQueued = true
    C_Timer.After(.2, function()
        scanQueued = false
        ScanNow()
    end)
end

-- The option switched: a fresh starting point, nothing waiting.
function Module:Refresh()
    ready = false
    scanAfterFight = false
    wipe(best); wipe(known); wipe(fresh); wipe(learned); wipe(pending); wipe(labels)
    if Enabled() then self:Scan() end
end

function Module:Initialize()
    local events = CreateFrame("Frame")
    for _, event in ipairs({"PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_REGEN_ENABLED"}) do
        pcall(events.RegisterEvent, events, event)
    end
    events:SetScript("OnEvent", function(_, event, spellID)
        if not Enabled() then return end
        if event == "PLAYER_REGEN_ENABLED" then
            if scanAfterFight then ScanNow() else Module:Apply() end
            return
        end
        if event == "LEARNED_SPELL_IN_SKILL_LINE" and ready and Number(spellID) then learned[spellID] = true end
        QueueScan()
    end)
    if Enabled() then QueueScan() end
end
