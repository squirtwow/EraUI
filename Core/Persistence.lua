-- Versioned recovery for settings the Forever client may lose from SavedVariables.
-- Only settings data is encoded. No Lua source is evaluated when reading it.
local _, E = ...
local P = {}
E.Persistence = P
local PREFIX = "EraUIRecovery1"
local RESET_CVAR = PREFIX .. "Reset"
local CHUNK, MAX_CHUNKS = 900, 128
local LIMIT = CHUNK * MAX_CHUNKS
local layouts = {
    mapPosition=true, mapSize=true, minimapButtonPosition=true,
    minimapDrawerButtonPosition=true, minimapDrawerOrder=true,
    comboPointPosition=true, energyBarPosition=true, resourceBarPositions=true,
    swingTimerPosition=true, rangedSwingTimerPosition=true, advancedCastBarPosition=true,
    statTrackerPosition=true, rewardProfiles=true,
    -- Ability Trail's places (yours, and each party slot's) and its ignore
    -- list (Modules/AbilityTrail.lua).
    abilityTrailPosition=true, abilityTrailPartyPositions=true, abilityTrailIgnore=true,
    -- The mini-games window's place and the account's best scores (Modules/MiniGames.lua),
    -- and their levels, coins and unlocks (Modules/MiniGameProgress.lua; the newer stamp wins).
    miniGamePosition=true, miniGameBest=true, miniGameProgress=true,
}
local reminderTypes = {
    reminderGroup="boolean", reminderCombat="boolean", reminderSize="number", reminderClickable="boolean", reminderMana="boolean", reminderRage="boolean",
    reminderCombatClick="boolean", reminderPoisonClick="boolean",
    reminderSpotVersion="number",
}
local classes = {WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,
    SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true}

local function SettingType(key)
    if type(key) ~= "string" then return end
    if layouts[key] then return "table" end
    if reminderTypes[key] then return reminderTypes[key] end
    if key == "showAllSpellRanks" then return "boolean" end
    if key == "cameraZoomBackup" then return "string" end
    if key == "afkScreenVersion" then return "number" end -- the one-time AFK Screen switch-on
    if key == "combatDragVersion" then return "number" end -- the one-time Combat Spell Dragging switch-off
    if key == "layoutNotice" then return "number" end -- the one-time new /era layout note
    if key == "layoutWelcome" then return "number" end -- the grouped layout's one-time welcome card
    if key == "tourOffer" then return "number" end -- a new player's one-time offer of the walkthrough
    if key == "justAddedVersion" then return "string" end -- the version "just added" was decided for
    if key == "justAddedFrom" then return "string" end -- and the version that account updated from
    if key == "newsTourSeen" then return "string" end -- the release whose walkthrough of what's new was opened
    if key == "talentKeyPrompt" then return "string" end -- the classic talents key offer's answer: "never" or "used"
    local default = E.settingDefaults[key]
    if default ~= nil then return type(default) end
    local prefix, class = key:match("^(reminder%w*)_([A-Z]+)_[%w]+$")
    if classes[class] then
        if prefix == "reminder" then return "boolean" end
        if prefix == "reminderChoice" or prefix == "reminderLast" or prefix == "reminderLimit"
            or prefix == "reminderPX" or prefix == "reminderPY" then return "number" end
    end
end

local function Finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end

-- A character's kept minimap zooms (Remember Minimap Zoom, Modules/MinimapZoom.lua):
-- only its two finite numbers, so nothing else in them can stop a backup.
local function Zooms(value)
    if type(value) ~= "table" then return nil end
    local out
    for _, place in ipairs({"outdoor", "indoor"}) do
        if Finite(value[place]) then out = out or {}; out[place] = value[place] end
    end
    return out
end

-- A character's mini-game best scores (Modules/MiniGames.lua): only
-- {best = {[game] = a whole number, 0 or more}}. Azeroth Blast's kept board
-- stays out, so the backup stays small.
local function Bests(value)
    local best = type(value) == "table" and value.best
    if type(best) ~= "table" then return nil end
    local out
    for id, score in pairs(best) do
        if type(id) == "string" and Finite(score) and score >= 0 then
            out = out or {}
            out[id] = math.floor(score)
        end
    end
    return out and {best = out} or nil
end

-- A character's Action Rings (Modules/RingData.lua) for the backup: the
-- version, each ring's name and kind, and each slice's kind, id, name, rank
-- and hand, nothing else (no icons: the game gives them again). At most ten
-- rings of sixteen slices, every string kept short.
local function Short(text) return type(text) == "string" and text:sub(1, 64) or nil end
local function Rings(value)
    if type(value) ~= "table" or type(value.rings) ~= "table" then return nil end
    local out = {version = Finite(value.version) and value.version or 1, rings = {}}
    for slot = 1, 10 do
        local ring = value.rings[slot]
        if type(ring) == "table" and type(ring.kind) == "string" then
            local copy = {kind = Short(ring.kind), name = Short(ring.name)}
            if type(ring.slices) == "table" then
                copy.slices = {}
                for _, slice in ipairs(ring.slices) do
                    if #copy.slices >= 16 then break end
                    local id = type(slice) == "table" and slice.id or nil
                    if id ~= nil and type(slice.kind) == "string" and (Finite(id) or type(id) == "string") then
                        copy.slices[#copy.slices + 1] = {kind = Short(slice.kind), id = type(id) == "string" and Short(id) or id,
                            name = Short(slice.name), rank = Short(slice.rank), hand = Finite(slice.hand) and slice.hand or nil}
                    end
                end
            end
            out.rings[slot] = copy
        end
    end
    return out
end
P.Rings = Rings

-- A character's class tools for the backup, without the Training Guide's
-- trainer quotes: a cache the next trainer visit fills again, and by far the
-- largest part of a character (a whole class list). With it, about six
-- characters at their trainers in one session filled the backup.
local function ToolsToKeep(tools)
    local out = {}
    if type(tools) ~= "table" then return out end
    for key, value in pairs(tools) do
        if key ~= "trainingGuide" then out[key] = value end
    end
    return out
end

-- The other character seen longest ago (a record from before the stamps
-- counts as oldest), never the one playing now.
local function Oldest(characters, current)
    local found, at
    for key, record in pairs(characters) do
        if key ~= current then
            local seen = type(record) == "table" and Finite(record.seen) and record.seen or 0
            if not found or seen < at or (seen == at and tostring(key) < tostring(found)) then found, at = key, seen end
        end
    end
    return found
end

-- Length-prefixed strings preserve punctuation, UTF-8 names and negative coordinates.
local function Encode(value, depth, seen)
    depth, seen = depth or 0, seen or {}
    assert(depth <= 8, "settings nesting too deep")
    local kind = type(value)
    if kind == "boolean" then return value and "t" or "f" end
    if kind == "number" then
        assert(Finite(value), "invalid settings number")
        return "n" .. string.format("%.17g", value) .. ":"
    end
    if kind == "string" then return "s" .. #value .. ":" .. value end
    assert(kind == "table" and not seen[value], "invalid settings table")
    seen[value] = true
    local keys = {}
    for key in pairs(value) do
        assert(type(key) == "string" or Finite(key), "invalid settings key")
        keys[#keys+1] = key
    end
    table.sort(keys, function(a,b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
    end)
    local parts = {"d", tostring(#keys), ":"}
    for _, key in ipairs(keys) do
        parts[#parts+1] = Encode(key, depth+1, seen)
        parts[#parts+1] = Encode(value[key], depth+1, seen)
    end
    seen[value] = nil
    return table.concat(parts)
end

local function Decode(text)
    assert(type(text) == "string" and #text <= LIMIT, "settings payload too large")
    local at, nodes = 1, 0
    local function Number()
        local stop = text:find(":", at, true)
        assert(stop and stop-at <= 32, "invalid settings length")
        local n = tonumber(text:sub(at, stop-1))
        at = stop+1
        assert(Finite(n), "invalid settings number")
        return n
    end
    local Read
    Read = function(depth)
        nodes = nodes+1
        assert(depth <= 8 and nodes <= 20000, "settings structure too large")
        local kind = text:sub(at,at)
        at = at+1
        if kind == "t" then return true end
        if kind == "f" then return false end
        if kind == "n" then return Number() end
        assert(kind == "s" or kind == "d", "invalid settings token")
        local count = Number()
        assert(count >= 0 and count == math.floor(count) and count <= LIMIT, "invalid settings count")
        if kind == "s" then
            assert(at+count-1 <= #text, "incomplete settings string")
            local value = text:sub(at, at+count-1)
            at = at+count
            return value
        end
        local value = {}
        for _=1,count do
            local key = Read(depth+1)
            assert((type(key) == "string" or Finite(key)) and value[key] == nil, "invalid settings key")
            value[key] = Read(depth+1)
        end
        return value
    end
    local value = Read(0)
    assert(at == #text+1, "trailing settings data")
    return value
end

local function Checksum(text)
    local sum = 0.0
    for i=1,#text do sum = (sum*33.0 + text:byte(i)) % 2147483647 end
    return string.format("%.0f", sum)
end

local function ReadCVar(name)
    if not (C_CVar and C_CVar.GetCVar) then return end
    local ok, value = pcall(C_CVar.GetCVar, name)
    if ok and type(value) == "string" then return value end
end
local function WriteCVar(name, value)
    if not (C_CVar and C_CVar.SetCVar and C_CVar.RegisterCVar) then return false end
    if ReadCVar(name) == nil then pcall(C_CVar.RegisterCVar, name, "") end
    local ok = pcall(C_CVar.SetCVar, name, value)
    return ok and ReadCVar(name) == value
end

function E:CharacterIdentity()
    local fn = UnitFullName or UnitName
    if not fn then return end
    local ok, name, realm = pcall(fn, "player")
    if not ok or (issecretvalue and issecretvalue(name)) or type(name) ~= "string" or name == "" then return end
    if issecretvalue and issecretvalue(realm) then return end
    if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
    if (issecretvalue and issecretvalue(realm)) or type(realm) ~= "string" or realm == "" then return end
    return name .. "-" .. realm, name
end

local function Snapshot(db)
    local out = {}
    for key, value in pairs(db or {}) do
        if type(value) == SettingType(key) then out[key] = value end
    end
    return out
end

function P:LoadAccount()
    if self.loaded then return end
    self.loaded = true
    self.store = {version=1, account={}, characters={}}
    local ns = E.Classic
    self.available = ns and ns.OnForever() and C_CVar and C_CVar.GetCVar and C_CVar.SetCVar and C_CVar.RegisterCVar
    if not self.available then return end
    local manifest = ReadCVar(PREFIX .. "Head")
    if manifest and manifest ~= "" then
        local bank, count, checksum = manifest:match("^([AB]):(%d+):(%d+)$")
        count = tonumber(count)
        local ok, store, payload = pcall(function()
            assert(bank and count and count >= 1 and count <= MAX_CHUNKS, "invalid recovery header")
            local chunks = {}
            for i=1,count do chunks[i] = assert(ReadCVar(PREFIX .. bank .. i), "missing recovery chunk") end
            local text = table.concat(chunks)
            assert(Checksum(text) == checksum, "incomplete recovery data")
            local data = Decode(text)
            assert(type(data) == "table" and data.version == 1 and type(data.account) == "table"
                and type(data.characters) == "table", "unsupported recovery version")
            return data, text
        end)
        if not ok then
            -- Keep SavedVariables and the unreadable backup rather than replacing it.
            self.blocked = true
            E:Print("Settings recovery could not be read; keeping SavedVariables. " .. tostring(store))
            return
        end
        self.store, self.bank, self.lastPayload = store, bank, payload
        -- The mini-games' progress changes between backups (a level played, then
        -- logged out): the record with the newer stamp wins, SavedVariables' on a tie.
        local mine = EraUIDB.miniGameProgress
        -- A complete snapshot owns omissions too, so reset positions cannot reappear.
        for key in pairs(EraUIDB) do
            if SettingType(key) then EraUIDB[key] = E.settingDefaults[key] end
        end
        for key, value in pairs(Snapshot(store.account)) do EraUIDB[key] = value end
        local restored = EraUIDB.miniGameProgress
        local restoredStamp = type(restored) == "table" and Finite(restored.stamp) and restored.stamp or -1
        if type(mine) == "table" and Finite(mine.stamp) and mine.stamp >= restoredStamp then
            EraUIDB.miniGameProgress = mine
        end
    else
        -- Earlier mirrors saved dynamic reminder booleans but never restored them.
        for key, value in pairs(ns.db or {}) do
            local setting = type(key) == "string" and key:match("^eraui_(.+)$")
            if setting and SettingType(setting) and E.settingDefaults[setting] == nil
                and EraUIDB[setting] == nil and type(value) == SettingType(setting) then
                EraUIDB[setting] = value
            end
        end
    end
end

function P:LoadCharacter()
    if not self.loaded or self.character then return end
    local key = E:CharacterIdentity()
    if not key then return end
    self.character = key
    EraUIClassicCharDB = EraUIClassicCharDB or {}
    local saved = self.store.characters[key]
    -- Each character's record carries the load it was last seen at, so a
    -- backup out of room lets the longest-unseen characters go first. The
    -- same character logging in again keeps its number (nothing to write).
    local loads = Finite(self.store.loads) and self.store.loads or 0
    if not (type(saved) == "table" and saved.seen == loads and loads > 0) then loads = loads + 1 end
    self.store.loads, self.seen = loads, loads
    if type(saved) == "table" then
        -- The trainer quotes aren't backed up: the ones SavedVariables hold stay.
        local quotes = type(EraUIClassicCharDB.classTools) == "table" and EraUIClassicCharDB.classTools.trainingGuide
        EraUIClassicCharDB.classTools = type(saved.classTools) == "table" and saved.classTools or {}
        if type(quotes) == "table" then EraUIClassicCharDB.classTools.trainingGuide = quotes end
        if type(saved.onboarding) == "table" then EraUIClassicCharDB.onboarding = saved.onboarding end
        if type(saved.swing) == "table" then self.characterSwing = saved.swing end
        local zooms = Zooms(saved.minimapZoom)
        if zooms then EraUIClassicCharDB.minimapZoom = zooms end
        -- Action Rings come back only when SavedVariables lost them.
        local rings = Rings(saved.actionRings)
        if rings and EraUIClassicCharDB.actionRings == nil then EraUIClassicCharDB.actionRings = rings end
        -- Best scores only rise: the higher of the backup's and SavedVariables'.
        local bests = Bests(saved.miniGames)
        if bests then
            local games = type(EraUIClassicCharDB.miniGames) == "table" and EraUIClassicCharDB.miniGames or {}
            EraUIClassicCharDB.miniGames = games
            if type(games.best) ~= "table" then games.best = {} end
            for id, score in pairs(bests.best) do
                local have = games.best[id]
                if not (Finite(have) and have >= score) then games.best[id] = score end
            end
        end
    end
end

function P:Save()
    if not self.loaded or not self.available or self.blocked or self.resetting or not EraUIDB then return end
    self.store.account = Snapshot(EraUIDB)
    if self.character then
        local char = EraUIClassicCharDB or {}
        self.store.characters[self.character] = {
            classTools=ToolsToKeep(char.classTools), onboarding=char.onboarding or {}, swing=E.charSettings or self.characterSwing or {},
            minimapZoom=Zooms(char.minimapZoom), miniGames=Bests(char.miniGames), actionRings=Rings(char.actionRings), seen=self.seen,
        }
    end
    local ok, payload = pcall(Encode, self.store)
    -- Too big: the other characters seen longest ago go, one at a time. This
    -- character and the account's settings always stay.
    while ok and #payload > LIMIT do
        local oldest = Oldest(self.store.characters, self.character)
        if oldest == nil then break end
        self.store.characters[oldest] = nil
        ok, payload = pcall(Encode, self.store)
    end
    if not ok or #payload > LIMIT then
        -- An older snapshot left in place would be read back over newer
        -- SavedVariables at the next load, so the header goes: SavedVariables win.
        if ReadCVar(PREFIX .. "Head") ~= "" then WriteCVar(PREFIX .. "Head", "") end
        self.lastPayload = nil
        if not self.warned then E:Print("Settings recovery could not be saved; your saved settings are used instead."); self.warned=true end
        return false
    end
    if payload == self.lastPayload then return self:FinishReset() end
    local bank = self.bank == "A" and "B" or "A"
    local count = math.ceil(#payload/CHUNK)
    -- Write and verify the inactive bank before publishing its header. Interrupted
    -- or truncated writes leave the previous complete snapshot as the active one.
    for i=1,count do
        if not WriteCVar(PREFIX .. bank .. i, payload:sub((i-1)*CHUNK+1, i*CHUNK)) then
            if not self.warned then E:Print("Settings recovery write failed; keeping the previous backup."); self.warned=true end
            return false
        end
    end
    local oldHead = ReadCVar(PREFIX .. "Head") or ""
    if not WriteCVar(PREFIX .. "Head", bank .. ":" .. count .. ":" .. Checksum(payload)) then
        if ReadCVar(PREFIX .. "Head") ~= oldHead and not WriteCVar(PREFIX .. "Head", oldHead) then self.blocked=true end
        if not self.warned then E:Print("Settings recovery header could not be saved."); self.warned=true end
        return false
    end
    self.bank, self.lastPayload, self.warned = bank, payload, nil
    return self:FinishReset()
end

function E:SaveSettings()
    if P.queued or P.resetting or not P.loaded then return end
    P.queued = true
    C_Timer.After(.2, function() P.queued=false; P:Save() end)
end

function P:Reset()
    if InCombatLockdown and InCombatLockdown() then
        E:Print("Finish combat before resetting EraUI settings.")
        return false
    end
    -- Keep every live table/alias valid until reload. This durable request wins
    -- over both SavedVariables written at logout and any older recovery banks.
    if not WriteCVar(RESET_CVAR, "1") then
        E:Print("The settings reset could not be saved. Your settings have been kept.")
        return false
    end
    self.resetting = true
    return true
end

function P:PrepareReset()
    if ReadCVar(RESET_CVAR) ~= "1" then return end
    self.resetting = true
    -- Leave the marker in place on failure, so the next load retries instead of
    -- silently reviving old preferences. The recovery header is cleared last.
    for _, name in ipairs({"EraUIClassicSettings", "EraUICharSwing", "EraUIOnboarding", PREFIX .. "Head"}) do
        local value = ReadCVar(name)
        if value and value ~= "" and not WriteCVar(name, "") then
            E:Print("The settings reset could not finish. Reload to retry.")
            return false
        end
    end
    EraUIDB, EraUIClassicDB, EraUIClassicCharDB = {}, {}, {}
    self.resetting, self.finishingReset = nil, true
    return true
end

function P:FinishReset()
    if not self.finishingReset then return true end
    -- Clear the request only after a complete fresh snapshot was verified.
    -- An interrupted startup therefore retries the reset on the next load.
    if not WriteCVar(RESET_CVAR, "") then return false end
    self.finishingReset = nil
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent", function() P:Save() end)
