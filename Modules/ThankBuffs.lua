local _, EraUI = ...

-- Thank for Buffs (/era > Chat & Names > Thank for buffs; off by default,
-- experimental). When another player buffs you, they get one whisper of
-- thanks. Every buff one caster gives within two seconds of the last goes in
-- the same whisper ("Thanks for the Mark of the Wild and Thorns!"), then
-- nothing more to them for 30 minutes. Your group, guild, friends, fights
-- and instances can each be skipped (ticks under the switch). The words are
-- yours: %name% is their first name, %spell% the buffs ("A", "A and B",
-- "A, B and C").
-- A buff is reported twice: by the combat log, which names any caster but
-- which this game may hold back (restricted, or its fields secret), and by
-- your own UNIT_AURA, whose caster is a unit token (none for a stranger,
-- though the game may still give their GUID). Both go into one queue per
-- caster (GUID, else name), so a buff counts once. A caster the game hides
-- is still thanked when a unit token shows them (target, focus, mouseover,
-- a nameplate, the group), else when the game can name their GUID (a
-- player it has seen nearby; a whole name from either lookup beats a first
-- name alone). A caster with neither gets nothing: the combat log's first
-- name alone is never whispered.
-- Only real players: never you, a pet, an NPC, an item or the zone, and no
-- lasting aura (a group member's, not a spell cast on you).
-- Who was thanked is kept for this character through a /reload
-- (EraUIClassicCharDB.thankBuffsQuiet, by GUID and whole name, on the
-- server's clock), so the 30 minutes hold across a reload or relog. It is
-- written straight into that table: no settings save or backup runs for it.
local Thanks = {}
EraUI:RegisterModule("ThankBuffs", Thanks)

local WAIT, QUIET, MOST = 2, 30 * 60, 255
local DEFAULT = "Thanks for the %spell%!"
Thanks.WAIT, Thanks.QUIET, Thanks.DEFAULT = WAIT, QUIET, DEFAULT
-- The skip ticks' defaults, should a setting be missing.
local SKIPS = {thankBuffsSkipGroup = true, thankBuffsSkipGuild = true, thankBuffsSkipFriends = false,
    thankBuffsSkipCombat = true, thankBuffsSkipInstances = true}
-- Your own auras, your pet's and your vehicle's never count.
local OWN = {player = true, pet = true, vehicle = true}
-- Where a caster may be found when only their GUID is known.
local LOOK = {"target", "focus", "mouseover", "softfriend"}
local GROUP_UNITS = {{"party", 4}, {"raid", 40}}
local NAMEPLATES = 40

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
local function Index(t, key) return t[key] end
-- A field of something the game gave: its value, or nil and true when it's
-- secret or reading it fails.
local function Read(t, key)
    if Secret(t) then return nil, true end
    if type(t) ~= "table" then return nil, false end
    local ok, value = pcall(Index, t, key)
    if not ok or Secret(value) then return nil, true end
    return value, false
end
-- One of the game's functions: its first two answers, a secret one as nil.
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, first, second = pcall(fn, ...)
    if not ok then return nil end
    if Secret(first) then first = nil end
    if Secret(second) then second = nil end
    return first, second
end
local function Plain(text)
    if Secret(text) or type(text) ~= "string" then return nil end
    text = text:match("^%s*(.-)%s*$")
    return text ~= "" and text or nil
end
local function Key(name) return type(name) == "string" and name:lower() or nil end
local function Now() return type(GetTime) == "function" and GetTime() or 0 end
-- Seconds on a clock a /reload doesn't reset (the server's), for the quiet.
local function Stamp()
    local clock = (type(GetServerTime) == "function" and GetServerTime) or (type(time) == "function" and time) or nil
    local value = clock and Ask(clock)
    return type(value) == "number" and value or Now()
end
local function Separator()
    local sep = Constants and Constants.CharacterNameSeparatorConsts
    sep = sep and sep.CHARACTERNAME_SURNAME_SEPARATOR
    return (type(sep) == "string" and sep ~= "") and sep or " "
end

-- A name as chat calls it ("First Surname"), then the first name, from the
-- two values the game gives (a first name and a surname). A name that is
-- already whole is kept as it is; with no surname the name stands alone.
local function Whole(first, surname)
    first, surname = Plain(first), Plain(surname)
    if not first then return nil end
    local sep = Separator()
    if surname and not first:find(sep, 1, true) then return first .. sep .. surname, first end
    return first, first:match("^(%S+)") or first
end
-- A unit's name as chat calls it, then its first name.
local function UnitWhole(unit) return Whole(Ask(UnitName, unit)) end
local function MyGuid()
    local guid = Ask(UnitGUID, "player")
    return type(guid) == "string" and guid or nil
end
local function IsPlayerGuid(guid) return type(guid) == "string" and guid:sub(1, 7) == "Player-" end
-- The unit token that shows this GUID now, if any does.
local function UnitOf(guid)
    if type(guid) ~= "string" then return nil end
    for _, unit in ipairs(LOOK) do if Ask(UnitGUID, unit) == guid then return unit end end
    for _, group in ipairs(GROUP_UNITS) do
        for i = 1, group[2] do if Ask(UnitGUID, group[1] .. i) == guid then return group[1] .. i end end
    end
    for i = 1, NAMEPLATES do if Ask(UnitGUID, "nameplate" .. i) == guid then return "nameplate" .. i end end
end
-- GetPlayerInfoByGUID's name and the answer after it.
local function InfoName(guid)
    local _, _, _, _, _, name, after = GetPlayerInfoByGUID(guid)
    return name, after
end
-- One lookup's name for a GUID, then the first name. The "Unknown" the game
-- shows while it still fetches a name counts as none.
local function Looked(fn, guid)
    local target, first = Whole(Ask(fn, guid))
    if first ~= nil and (first == UNKNOWNOBJECT or first == UNKNOWN) then return nil end
    return target, first
end
-- A player's name from their GUID alone, for when no unit token shows them:
-- the game knows a player it has seen (one nearby, mostly). Never yours.
-- A whole name from either lookup beats a first name alone.
local function GuidWhole(guid)
    if not IsPlayerGuid(guid) or guid == MyGuid() then return nil end
    local sep = Separator()
    local target, first = Looked(UnitNameFromGUID, guid)
    if target and target:find(sep, 1, true) then return target, first end
    local other, otherFirst = Looked(InfoName, guid)
    if other and (not target or other:find(sep, 1, true)) then return other, otherFirst end
    return target, first
end
-- A spell's name from its ID, when the report's own name was hidden.
local function SpellName(spellId)
    if type(spellId) ~= "number" then return nil end
    local spell = C_Spell
    local name = spell and Plain((Ask(spell.GetSpellName, spellId)))
    if not name and spell then
        local info = Ask(spell.GetSpellInfo, spellId)
        name = type(info) == "table" and Plain((Read(info, "name"))) or nil
    end
    return name or Plain((Ask(GetSpellInfo, spellId)))
end
-- Whether the combat log is held back from addons now (unreadable counts).
local function LogRestricted()
    local log = C_CombatLog
    local check = log and log.IsCombatLogRestricted
    if type(check) ~= "function" then return false end
    local ok, restricted = pcall(check)
    if not ok or Secret(restricted) then return true end
    return restricted == true
end
-- A buff on you that never runs out: a group member's aura, not a spell
-- they cast on you (only when the game says its duration).
local function Lasting(spellId)
    local auras = C_UnitAuras
    if type(spellId) ~= "number" or not auras then return false end
    local aura = Ask(auras.GetPlayerAuraBySpellID, spellId)
    return type(aura) == "table" and Read(aura, "duration") == 0
end

function Thanks:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("thankBuffs") == true
end
local function Skips(key)
    local value = EraUI:GetSetting(key)
    if value == nil then value = SKIPS[key] end
    return value == true
end
local function InFight()
    if Ask(InCombatLockdown) then return true end
    return Ask(UnitAffectingCombat, "player") and true or false
end
local function InInstance()
    local inside, kind = Ask(IsInInstance)
    return (inside and kind ~= "none") and true or false
end
local function InGroup(entry)
    local unit = entry.unit
    if unit and (unit:find("^party%d") or unit:find("^raid%d")) then return true end
    if unit and (Ask(UnitInParty, unit) or Ask(UnitInRaid, unit)) then return true end
    local guid = entry.guid
    if not guid then return false end
    if Ask(IsGUIDInGroup, guid) then return true end
    for _, group in ipairs(GROUP_UNITS) do
        for i = 1, group[2] do if Ask(UnitGUID, group[1] .. i) == guid then return true end end
    end
    return false
end
-- Whether your guild's member list (asked for while Skip Your Guild is on)
-- has them, by GUID or by whole name (a realm after a "-" left off).
local function OnRoster(entry)
    local count = Ask(GetNumGuildMembers)
    if type(count) ~= "number" or type(GetGuildRosterInfo) ~= "function" then return false end
    local want = Key(entry.target)
    for i = 1, math.min(count, 1000) do
        local row = {pcall(GetGuildRosterInfo, i)}
        if row[1] == true then
            local guid, name = row[18], Plain(row[2])
            if entry.guid and not Secret(guid) and guid == entry.guid then return true end
            if want and name and (Key(name) == want or Key(name:match("^([^%-]+)")) == want) then return true end
        end
    end
    return false
end
-- Your guild: by the unit's guild name, else what the game says of the
-- GUID or name, else its member list; unreadable counts as not.
local function InGuild(entry)
    local mine = Plain((Ask(GetGuildInfo, "player")))
    if entry.unit and mine and Plain((Ask(GetGuildInfo, entry.unit))) == mine then return true end
    if entry.guid and Ask(IsGuildMember, entry.guid) then return true end
    local guild = C_GuildInfo
    if entry.target and guild and Ask(guild.MemberExistsByName, entry.target) then return true end
    if not (mine or Ask(IsInGuild)) then return false end
    return OnRoster(entry)
end
-- A character friend or a Battle.net friend.
local function IsFriend(entry)
    local list, net = C_FriendList, C_BattleNet
    if entry.guid then
        if list and Ask(list.IsFriend, entry.guid) then return true end
        if net and type((Ask(net.GetAccountInfoByGUID, entry.guid))) == "table" then return true end
    end
    if entry.target and list and type((Ask(list.GetFriendInfo, entry.target))) == "table" then return true end
    return false
end
-- Within the 30 minutes (a stamp far ahead of the clock doesn't count).
local function Recent(at, now)
    if type(at) ~= "number" then return false end
    local age = now - at
    return age < QUIET and age > -QUIET
end
-- This character's saved list of who was thanked when; made only to write.
local function QuietList(make)
    local char = EraUIClassicCharDB
    local list = type(char) == "table" and char.thankBuffsQuiet or nil
    if type(list) == "table" then return list end
    if not make then return {} end
    if type(char) ~= "table" then char = {}; EraUIClassicCharDB = char end
    list = {}
    char.thankBuffsQuiet = list
    return list
end
-- Thanked in the last 30 minutes.
function Thanks:Quiet(guid, target)
    local quiet, now = QuietList(false), Stamp()
    return (guid ~= nil and Recent(quiet[guid], now)) or (target ~= nil and Recent(quiet[Key(target)], now)) or false
end
-- Notes a thanks (by GUID and whole name), dropping any older than 30 minutes.
function Thanks:Remember(guid, target)
    local quiet, now = QuietList(true), Stamp()
    for key, at in pairs(quiet) do
        if not Recent(at, now) then quiet[key] = nil end
    end
    if guid then quiet[guid] = now end
    if Key(target) then quiet[Key(target)] = now end
end
-- Asks the game for your guild's member list (it answers later), so a
-- guildmate passing with no unit token is still found by name.
function Thanks:AskRoster()
    if not self:On() or not Skips("thankBuffsSkipGuild") or not Ask(IsInGuild) then return end
    local guild = C_GuildInfo
    Ask((guild and guild.GuildRoster) or GuildRoster)
end

-- The words ---------------------------------------------------------------

-- "A", "A and B", "A, B and C".
function Thanks.Join(list)
    local n = #list
    if n == 0 then return "" end
    if n == 1 then return list[1] end
    return table.concat(list, ", ", 1, n - 1) .. " and " .. list[n]
end
-- At most most bytes, never cutting a letter in two.
local function Fit(text, most)
    if #text <= most then return text end
    local cut = most
    while cut > 0 do
        local byte = text:byte(cut + 1)
        if not byte or byte < 0x80 or byte >= 0xC0 then break end
        cut = cut - 1
    end
    return text:sub(1, cut)
end
-- The whisper: your words (empty: the default) with %name% and %spell% put
-- in; chat codes taken out, on one line, short enough to send.
function Thanks.Words(template, first, spells)
    local values = {name = first or "", spell = Thanks.Join(spells or {})}
    local function Fill(text)
        text = text:gsub("%%(%a+)%%", function(word) return values[word:lower()] end)
        text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|", "")
        return Plain((text:gsub("[\r\n]+", " ")))
    end
    local text = Fill(Plain(template) or DEFAULT) or Fill(DEFAULT) or ""
    return Fit(text, MOST)
end
local function Whisper(target, text)
    local chat = C_ChatInfo
    local send = (chat and chat.SendChatMessage) or SendChatMessage
    if type(send) ~= "function" or not Plain(target) or text == "" then return false end
    return (pcall(send, text, "WHISPER", nil, target))
end

-- The queue ---------------------------------------------------------------

local function FlushLater() Thanks:Flush() end
local function Merge(entry, report)
    entry.guid = entry.guid or report.guid
    entry.target = entry.target or report.target
    entry.first = entry.first or report.first
    if report.unit then entry.unit = report.unit end
end
-- This caster's place in the queue (by GUID, else by whole name).
function Thanks:Entry(report)
    local guid, target = report.guid, Key(report.target)
    for _, entry in ipairs(self.pending) do
        if (guid and entry.guid == guid) or (target and Key(entry.target) == target) then
            Merge(entry, report)
            return entry
        end
    end
    local entry = {spells = {}, seen = {}}
    Merge(entry, report)
    self.pending[#self.pending + 1] = entry
    return entry
end
-- One report: why it's skipped now ("skipped: ..." is returned), or its
-- buff in its caster's queue and the wait started again.
function Thanks:Take(report)
    local why = report.why
    if not why then
        if Skips("thankBuffsSkipCombat") and InFight() then why = "in a fight"
        elseif Skips("thankBuffsSkipInstances") and InInstance() then why = "in an instance"
        elseif self:Quiet(report.guid, report.target) then why = "thanked already" end
    end
    if why then return "skipped: " .. why end
    local entry = self:Entry(report)
    local spell = report.spell
    if spell and not entry.seen[Key(spell)] then
        entry.seen[Key(spell)] = true
        entry.spells[#entry.spells + 1] = spell
    end
    entry.due = Now() + WAIT
    if C_Timer and C_Timer.After then C_Timer.After(WAIT + .05, FlushLater) end
end
-- Whether a token from a moment ago still shows this caster: by GUID, else
-- by the whole name read then. Neither known: it can't be trusted.
local function Shows(unit, entry)
    if not unit then return false end
    if entry.guid then return Ask(UnitGUID, unit) == entry.guid end
    return entry.target ~= nil and Key((UnitWhole(unit))) == Key(entry.target)
end
-- Why this caster's whisper doesn't go, or nil.
function Thanks:Holds(entry)
    if not self:On() then return "switched off" end
    -- The token again: one from a moment ago may show someone else now, so
    -- it's kept (for the name and the group and guild checks) only while it
    -- still shows the caster.
    local unit, hadToken = entry.unit, entry.unit ~= nil
    if not Shows(unit, entry) then unit = nil end
    if not unit and entry.guid then unit = UnitOf(entry.guid) end
    entry.unit = unit
    if not entry.target and unit then entry.target, entry.first = UnitWhole(unit) end
    -- Nothing shows them: the game may know their GUID's name by now.
    if not entry.target and not unit then
        local target, first = GuidWhole(entry.guid)
        if target then entry.target, entry.first = target, first end
    end
    if not entry.target then return (unit or hadToken) and "name hidden" or entry.first and "first name only" or "no unit token" end
    if EraUI:IsPlayer(entry.target, entry.guid) then return "your own" end
    if Skips("thankBuffsSkipCombat") and InFight() then return "in a fight" end
    if Skips("thankBuffsSkipInstances") and InInstance() then return "in an instance" end
    if Skips("thankBuffsSkipGroup") and InGroup(entry) then return "your group" end
    if Skips("thankBuffsSkipGuild") and InGuild(entry) then return "your guild" end
    if Skips("thankBuffsSkipFriends") and IsFriend(entry) then return "your friend" end
    if self:Quiet(entry.guid, entry.target) then return "thanked already" end
    local chat = C_ChatInfo
    if chat and Ask(chat.InChatMessagingLockdown) then return "chat locked" end
end
-- One caster's whisper: "whispered" is returned, or why not.
function Thanks:Send(entry)
    local why = self:Holds(entry)
    if why then return "skipped: " .. why end
    local spells = #entry.spells > 0 and entry.spells or {"buff"}
    local text = Thanks.Words(EraUI:GetSetting("thankBuffsMessage"), entry.first or entry.target:match("^(%S+)"), spells)
    if Whisper(entry.target, text) then
        self:Remember(entry.guid, entry.target)
        return "whispered"
    end
    return "skipped: the game didn't send it"
end
-- Every caster whose wait is over.
function Thanks:Flush()
    local now, due, keep = Now(), {}, {}
    for _, entry in ipairs(self.pending) do
        if (entry.due or 0) <= now + .01 then due[#due + 1] = entry else keep[#keep + 1] = entry end
    end
    self.pending = keep
    for _, entry in ipairs(due) do self:Send(entry) end
end

-- What the game reports ---------------------------------------------------

-- The caster's name from the combat log ("First Surname"), else from a unit
-- token showing their GUID, else what the game knows of that GUID; the
-- log's first name alone isn't whispered.
local function Named(report, name)
    if name and name:find(Separator(), 1, true) then
        report.target, report.first = name, name:match("^(%S+)")
        return
    end
    local unit = UnitOf(report.guid)
    if unit then
        report.unit = unit
        report.target, report.first = UnitWhole(unit)
    else
        local target, first = GuidWhole(report.guid)
        report.target, report.first = target, first or name
    end
end
-- A combat log row: a buff put on you, or put on again, by someone else.
-- Nothing is read from a restricted log; a row with a secret field is
-- skipped (the aura report covers it). logState says how the log was last.
function Thanks:OnLog()
    local info = CombatLogGetCurrentEventInfo
    if type(info) ~= "function" then self.logState = "missing"; return end
    if LogRestricted() then self.logState = "restricted"; return end
    local ok, _, subevent, _, sourceGUID, sourceName, _, _, destGUID, _, _, _, spellId, spellName, _, auraType = pcall(info)
    if not ok then self.logState = "unreadable"; return end
    if Secret(subevent) or Secret(destGUID) then self.logState = "secret"; return end
    self.logState = "working"
    if subevent ~= "SPELL_AURA_APPLIED" and subevent ~= "SPELL_AURA_REFRESH" then return end
    local me = MyGuid()
    if not me or destGUID ~= me then return end
    local secret = Secret(sourceGUID) or Secret(sourceName) or Secret(spellId) or Secret(spellName) or Secret(auraType)
    if not secret and (auraType ~= "BUFF" or sourceGUID == me) then return end
    local report = {spell = Plain(spellName) or SpellName(not Secret(spellId) and spellId or nil),
        spellId = (not Secret(spellId) and type(spellId) == "number") and spellId or nil}
    if secret then
        report.why = "secret"
    elseif not IsPlayerGuid(sourceGUID) then
        report.why = type(sourceGUID) == "string" and "not a player" or "caster hidden"
    else
        report.guid = sourceGUID
        Named(report, Plain(sourceName))
        if Lasting(report.spellId) then report.why = "a lasting aura" end
    end
    self:Take(report)
end
-- One aura just put on you (UNIT_AURA's addedAuras): its caster's token,
-- else the GUID the game gives for its caster, else nobody.
function Thanks:FromAura(aura)
    local helpful, hiddenHelp = Read(aura, "isHelpful")
    local unit, hiddenUnit = Read(aura, "sourceUnit")
    local name = Read(aura, "name")
    local spellId = Read(aura, "spellId")
    if helpful == false then return end
    if not hiddenUnit and type(unit) == "string" and (OWN[unit] or Ask(UnitIsUnit, unit, "player")) then return end
    local report = {spell = Plain(name) or SpellName(spellId), spellId = type(spellId) == "number" and spellId or nil}
    if hiddenHelp or hiddenUnit then
        report.why = "secret"
        return self:Take(report)
    end
    if helpful ~= true then return end
    if type(unit) == "string" then
        if Ask(UnitIsPlayer, unit) ~= true then
            report.why = "not a player"
            return self:Take(report)
        end
        local guid = Ask(UnitGUID, unit)
        report.unit, report.guid = unit, type(guid) == "string" and guid or nil
        report.target, report.first = UnitWhole(unit)
    else
        -- No token: the game may still give its caster's GUID.
        local auras, instance = C_UnitAuras, Read(aura, "auraInstanceID")
        local guid = (auras and instance ~= nil) and Ask(auras.GetAuraCasterGUID, "player", instance) or nil
        if type(guid) ~= "string" then
            report.why = "caster hidden"
            return self:Take(report)
        end
        if not IsPlayerGuid(guid) then
            report.why = "not a player"
            return self:Take(report)
        end
        if guid == MyGuid() then return end
        report.guid = guid
        Named(report, nil)
    end
    if Read(aura, "duration") == 0 then report.why = "a lasting aura" end
    self:Take(report)
end
-- UNIT_AURA for you: each aura it says was added. A secret list is skipped.
function Thanks:OnAura(info)
    local added, hidden = Read(info, "addedAuras")
    if hidden then
        return self:Take({why = "secret"})
    end
    if type(added) ~= "table" then return end
    for i = 1, 100 do
        local aura, secret = Read(added, i)
        if secret then
            self:Take({why = "secret"})
        elseif aura == nil then
            return
        else
            self:FromAura(aura)
        end
    end
end

local function Report(problem)
    if geterrorhandler then geterrorhandler()(problem) end
end
local function OnEvent(_, event, unit, info)
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local ok, problem = pcall(Thanks.OnLog, Thanks)
        if not ok then Report(problem) end
    elseif event == "UNIT_AURA" then
        -- Auras listed as you arrive somewhere were cast before: left out.
        if Secret(unit) or unit ~= "player" or Now() < (Thanks.calmUntil or 0) then return end
        local ok, problem = pcall(Thanks.OnAura, Thanks, info)
        if not ok then Report(problem) end
    elseif event == "PLAYER_ENTERING_WORLD" then
        Thanks.calmUntil = Now() + 3
        Thanks:AskRoster()
    end
end

-- Listens while it's on, and stops (dropping the queue) when it's off.
function Thanks:Refresh()
    self.pending = self.pending or {}
    if not self:On() then
        if self.frame and self.listening then self.frame:UnregisterAllEvents() end
        self.listening, self.pending = false, {}
        return
    end
    self:AskRoster()
    if self.listening then return end
    local frame = self.frame or CreateFrame("Frame")
    self.frame = frame
    frame:SetScript("OnEvent", OnEvent)
    if not (frame.RegisterUnitEvent and pcall(frame.RegisterUnitEvent, frame, "UNIT_AURA", "player")) then
        frame:RegisterEvent("UNIT_AURA")
    end
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- The combat log may be refused to addons here: then the aura report
    -- alone is used.
    if type(CombatLogGetCurrentEventInfo) ~= "function" then
        self.logState = "missing"
    else
        local ok, registered = pcall(frame.RegisterEvent, frame, "COMBAT_LOG_EVENT_UNFILTERED")
        self.logState = (ok and registered ~= false) and "working" or "not registered"
    end
    self.listening = true
end

function Thanks:Initialize()
    self:Refresh()
end
