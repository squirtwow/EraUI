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
    comboPointPosition=true, energyBarPosition=true, resourceBarPositions=true,
    swingTimerPosition=true, rangedSwingTimerPosition=true, advancedCastBarPosition=true,
    rewardProfiles=true,
}
local reminderTypes = {
    reminderGroup="boolean", reminderCombat="boolean", reminderSize="number", reminderClickable="boolean",
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
    local default = E.settingDefaults[key]
    if default ~= nil then return type(default) end
    local prefix, class = key:match("^(reminder%w*)_([A-Z]+)_[%w]+$")
    if classes[class] then
        if prefix == "reminder" then return "boolean" end
        if prefix == "reminderChoice" or prefix == "reminderPX" or prefix == "reminderPY" then return "number" end
    end
end

local function Finite(n)
    return type(n) == "number" and n == n and n > -math.huge and n < math.huge
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
        -- A complete snapshot owns omissions too, so reset positions cannot reappear.
        for key in pairs(EraUIDB) do
            if SettingType(key) then EraUIDB[key] = E.settingDefaults[key] end
        end
        for key, value in pairs(Snapshot(store.account)) do EraUIDB[key] = value end
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
    if type(saved) == "table" then
        EraUIClassicCharDB.classTools = type(saved.classTools) == "table" and saved.classTools or {}
        if type(saved.onboarding) == "table" then EraUIClassicCharDB.onboarding = saved.onboarding end
        if type(saved.swing) == "table" then self.characterSwing = saved.swing end
    end
end

function P:Save()
    if not self.loaded or not self.available or self.blocked or self.resetting or not EraUIDB then return end
    self.store.account = Snapshot(EraUIDB)
    if self.character then
        local char = EraUIClassicCharDB or {}
        self.store.characters[self.character] = {
            classTools=char.classTools or {}, onboarding=char.onboarding or {}, swing=E.charSettings or self.characterSwing or {},
        }
    end
    local ok, payload = pcall(Encode, self.store)
    if not ok or #payload > LIMIT then
        if not self.warned then E:Print("Settings recovery could not be saved; keeping the previous backup."); self.warned=true end
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
