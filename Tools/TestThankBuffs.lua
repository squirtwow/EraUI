-- Thank for Buffs (/era > Chat & Names > Thank for buffs; Modules/ThankBuffs.lua)
-- on a small mock of the game: off by default; on, another player's buffs
-- within two seconds make one whisper, then 30 minutes of quiet; each skip
-- tick (Skip Your Guild by the member list too); secret fields (an erroring
-- metatable) and a restricted combat log falling back to UNIT_AURA; a
-- stranger with no unit token named from their GUID (UnitNameFromGUID, else
-- GetPlayerInfoByGUID; a whole name from either first; "Unknown" is none),
-- and with neither no whisper; a token that moved on never whispered; the
-- placeholders; never you, a pet, an NPC or a lasting aura; nothing saved
-- but the quiet, written with no settings save, and kept through a /reload.
-- What became of each report is read from what Take and Send return
-- ("whispered" or "skipped: <why>"); the module keeps no record of it.
-- Run from the addon folder.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local SECRET = setmetatable({}, {__tostring = function() return "SECRET" end})
_G.issecretvalue = function(value) return value == SECRET end
-- A table any read of which fails, as the game's secret aura data can.
local function Erroring() return setmetatable({}, {__index = function() error("secret aura field") end}) end

-- The world: units by token, each {guid, first, surname, player, guild, party, raid}.
local ME = "Player-1-ME"
local units, now, timers, whispers = {}, 0, {}, {}
local world = {}
local function Reset()
    units = {player = {guid = ME, first = "Tabitantu", surname = "Stagkiller", player = true, guild = "Filth"}}
    timers, whispers = {}, {}
    world = {combat = false, instance = false, restricted = false, lockdown = false, friends = {}, bnet = {}, guildGuids = {},
        casterGuids = {}, lasting = {}, roster = {}, names = {}, info = {}, groupGuids = {}, asked = {}}
end
Reset()
_G.GetTime = function() return now end
-- The server's clock: a /reload doesn't start it again.
_G.GetServerTime = function() return 1700000000 + now end
_G.date = function() return "12:00:00" end
_G.C_Timer = {After = function(delay, fn) timers[#timers + 1] = {at = now + delay, fn = fn} end}
local function Advance(seconds)
    now = now + seconds
    local ran = true
    while ran do
        ran = false
        for i, timer in ipairs(timers) do
            if timer.at <= now then table.remove(timers, i); timer.fn(); ran = true; break end
        end
    end
end
_G.UnitGUID = function(unit) return units[unit] and units[unit].guid end
_G.UnitName = function(unit)
    local u = units[unit]
    if not u then return nil end
    return u.first, u.surname
end
-- Names the game knows by GUID with no unit token: {first, second} as
-- UnitNameFromGUID's answers, and as GetPlayerInfoByGUID's 6th and 7th.
-- Every GUID asked about is noted.
_G.UnitNameFromGUID = function(guid)
    world.asked[#world.asked + 1] = guid
    local n = world.names[guid]
    if n then return n[1], n[2] end
end
_G.GetPlayerInfoByGUID = function(guid)
    world.asked[#world.asked + 1] = guid
    local n = world.info[guid]
    if n then return "Druid", "DRUID", "Night Elf", "NightElf", 3, n[1], n[2], 20 end
end
_G.IsGUIDInGroup = function(guid) return world.groupGuids[guid] == true end
_G.UnitIsPlayer = function(unit) return units[unit] ~= nil and units[unit].player == true end
_G.UnitIsUnit = function(a, b) return units[a] ~= nil and units[b] ~= nil and units[a].guid == units[b].guid end
_G.UnitInParty = function(unit) return units[unit] ~= nil and units[unit].party == true end
_G.UnitInRaid = function(unit) return units[unit] and units[unit].raid or nil end
_G.GetGuildInfo = function(unit) return units[unit] and units[unit].guild end
_G.IsGuildMember = function(guid) return world.guildGuids[guid] == true end
-- Your guild's member list: {name, guid} rows, as the 1st and 17th answers.
local rosterAsks = 0
_G.IsInGuild = function() return units.player ~= nil and units.player.guild ~= nil end
_G.GetNumGuildMembers = function() return #world.roster, #world.roster end
_G.GetGuildRosterInfo = function(i)
    local member, out = world.roster[i], {}
    if not member then return nil end
    out[1], out[17] = member.name, member.guid
    return (table.unpack or unpack)(out, 1, 17)
end
_G.C_GuildInfo = {GuildRoster = function() rosterAsks = rosterAsks + 1 end}
_G.InCombatLockdown = function() return world.combat end
_G.UnitAffectingCombat = function() return world.combat end
_G.IsInInstance = function() if world.instance then return true, "party" end return false, "none" end
_G.C_FriendList = {IsFriend = function(guid) return world.friends[guid] == true end, GetFriendInfo = function() return nil end}
_G.C_BattleNet = {GetAccountInfoByGUID = function(guid) return world.bnet[guid] and {accountName = "Pal"} or nil end}
_G.C_UnitAuras = {
    GetAuraCasterGUID = function(_, instance) return world.casterGuids[instance] end,
    GetPlayerAuraBySpellID = function(id) if world.lasting[id] then return {duration = 0} end return {duration = 1800} end,
}
_G.C_Spell = {GetSpellName = function(id) return ({[1126] = "Mark of the Wild", [467] = "Thorns", [1459] = "Arcane Intellect"})[id] end}
_G.C_ChatInfo = {
    SendChatMessage = function(text, kind, language, target) whispers[#whispers + 1] = {text = text, kind = kind, language = language, target = target} end,
    InChatMessagingLockdown = function() return world.lockdown end,
}
-- The combat log: the row now being read.
local logRow
_G.C_CombatLog = {IsCombatLogRestricted = function() return world.restricted end}
_G.CombatLogGetCurrentEventInfo = function() return (table.unpack or unpack)(logRow, 1, 15) end

local frames = {}
local refuseLog = false
_G.CreateFrame = function()
    local f = {events = {}, scripts = {}}
    function f:RegisterEvent(e)
        if e == "COMBAT_LOG_EVENT_UNFILTERED" and refuseLog then error("not for addons") end
        self.events[e] = true
        return true
    end
    function f:RegisterUnitEvent(e, unit) self.events[e] = unit end
    function f:UnregisterAllEvents() self.events = {} end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        local on = f.events[event]
        if on and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end
local errors = {}
_G.geterrorhandler = function() return function(problem) errors[#errors + 1] = tostring(problem) end end

-- The combat log saying a buff went on you (or anything else).
local function Log(sub, sourceGUID, sourceName, spellId, spellName, auraType, destGUID)
    logRow = {now, sub, false, sourceGUID, sourceName, 0x511, 0, destGUID or ME, "Tabitantu Stagkiller", 0x511, 0,
        spellId, spellName, 8, auraType or "BUFF"}
    Fire("COMBAT_LOG_EVENT_UNFILTERED")
end
local instances = 0
local function Aura(fields)
    instances = instances + 1
    local aura = {isHelpful = true, auraInstanceID = instances, duration = 1800}
    for k, v in pairs(fields) do aura[k] = v end
    if fields.noUnit then aura.sourceUnit = nil end
    return aura
end
local function Added(...) Fire("UNIT_AURA", "player", {addedAuras = {...}}) end

local settings
-- Settings saves (each runs the whole save and backup in the game).
local setCalls = 0
-- What became of the reports since the last Fresh, in turn, and the last
-- caster's queue entry Send looked at.
local outcomes, sent = {}, nil
local function Load()
    frames = {}
    settings = {enabled = true, thankBuffs = false, thankBuffsMessage = "Thanks for the %spell%!", thankBuffsSkipGroup = true,
        thankBuffsSkipGuild = true, thankBuffsSkipFriends = false, thankBuffsSkipCombat = true, thankBuffsSkipInstances = true}
    _G.EraUIDB = settings
    local E = {modules = {}}
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    function E:GetSetting(key) return settings[key] end
    function E:SetSetting(key, value) setCalls = setCalls + 1; settings[key] = value end
    assert(loadfile("Core/Utils.lua"))("EraUI", E)
    assert(loadfile("Modules/ThankBuffs.lua"))("EraUI", E)
    local thanks = E.modules.ThankBuffs
    thanks:Initialize()
    -- Each report skipped at once (Take) and each caster's wait (Send),
    -- noted in turn.
    local take, send = thanks.Take, thanks.Send
    function thanks:Take(report)
        local why = take(self, report)
        if why then outcomes[#outcomes + 1] = why end
        return why
    end
    function thanks:Send(entry)
        local result = send(self, entry)
        outcomes[#outcomes + 1] = result
        sent = entry
        return result
    end
    return thanks, E
end
local function Last() return outcomes[#outcomes] or "" end
local function Fresh(thanks)
    Reset(); thanks.pending = {}; outcomes = {}; sent = nil
    _G.EraUIClassicCharDB = {}
end

-- The default lines up with Core/Init.lua.
do
    local real = {}
    local era = _G.EraUI
    assert(loadfile("Core/Init.lua"))("EraUI", real)
    _G.EraUI = era
    local d = real.settingDefaults
    equal(tostring(d.thankBuffs) .. " " .. d.thankBuffsMessage .. " " .. tostring(d.thankBuffsSkipGroup) .. tostring(d.thankBuffsSkipGuild)
        .. tostring(d.thankBuffsSkipFriends) .. tostring(d.thankBuffsSkipCombat) .. tostring(d.thankBuffsSkipInstances) .. " "
        .. tostring(d.thankBuffsProbe) .. " " .. tostring(real.reloadSettings.thankBuffs),
        "false Thanks for the %spell%! truetruefalsetruetrue nil nil", "off by default; the first words; group, guild, combat and instances skipped; no probe; no reload")
end

-- Off: nothing listens, nothing is whispered or looked at.
local thanks = Load()
units.target = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
equal(next(frames[1] and frames[1].events or {}), nil, "off: no events")
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 1126, "Mark of the Wild")
Added(Aura({sourceUnit = "target", name = "Mark of the Wild", spellId = 1126}))
Advance(3)
equal(#whispers .. " " .. #outcomes, "0 0", "off: no whisper, nothing taken")

-- On: listens to your auras (yours only) and the combat log.
settings.thankBuffs = true
thanks:Refresh()
local frame = thanks.frame
equal(tostring(frame.events.UNIT_AURA) .. " " .. tostring(frame.events.COMBAT_LOG_EVENT_UNFILTERED) .. " " .. tostring(frame.events.PLAYER_ENTERING_WORLD)
    .. " " .. thanks.logState, "player true true working", "on: your UNIT_AURA, the combat log and arrivals")
equal(rosterAsks, 1, "on, in a guild, Skip Your Guild ticked: the guild's member list asked for")
settings.thankBuffsSkipGuild = false
thanks:Refresh()
settings.thankBuffsSkipGuild = true
units.player.guild = nil
thanks:Refresh()
units.player.guild = "Filth"
Fire("PLAYER_ENTERING_WORLD")
equal(rosterAsks, 2, "not asked with Skip Your Guild off or out of a guild; asked again on arriving somewhere")
Advance(4)

-- A druid's Mark of the Wild and Thorns, each from both reports, a second
-- apart: one whisper naming both, two seconds after the last, to their whole name.
Fresh(thanks)
units.target = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 1126, "Mark of the Wild")
Added(Aura({sourceUnit = "target", name = "Mark of the Wild", spellId = 1126}))
Advance(1)
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467}))
Advance(1.5)
equal(#whispers, 0, "still waiting: under two seconds since the last buff")
Advance(1)
equal(#whispers, 1, "one whisper for both buffs from both reports")
local w = whispers[1]
equal(w.text .. " | " .. w.kind .. " | " .. tostring(w.language) .. " | " .. w.target, "Thanks for the Mark of the Wild and Thorns! | WHISPER | nil | Zriel Gustbellow",
    "the buffs joined, to First Surname")
equal(table.concat(outcomes, ",") .. " " .. thanks.logState .. " " .. tostring(settings.thankBuffsProbe), "whispered working nil",
    "four reports, one caster: one wait, whispered; the log working; nothing kept of the reports")

-- 30 minutes of quiet: no second whisper for a buff a minute later, nor
-- just inside the half hour, then one just after it.
equal(thanks.QUIET, 1800, "the quiet is 30 minutes")
local quiet = EraUIClassicCharDB.thankBuffsQuiet
local thankedAt = quiet and quiet["Player-1-Z"]
equal(tostring(thankedAt ~= nil and thankedAt == quiet["zriel gustbellow"]) .. " " .. tostring(thankedAt == GetServerTime()), "true true",
    "the thanks is kept for this character by GUID and whole name, on the server's clock")
Advance(60)
Log("SPELL_AURA_REFRESH", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. Last(), "1 skipped: thanked already", "a minute later: quiet")
Advance(thankedAt + 29 * 60 + 50 - GetServerTime())
Log("SPELL_AURA_REFRESH", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. Last(), "1 skipped: thanked already", "29 minutes 50 seconds after: still quiet")
Advance(thankedAt + 30 * 60 + 5 - GetServerTime())
Log("SPELL_AURA_REFRESH", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. (whispers[2] and whispers[2].text or ""), "2 Thanks for the Thorns!", "after 30 minutes: thanked again")

-- Two casters at once: a whisper each.
Fresh(thanks)
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 1126, "Mark of the Wild")
Log("SPELL_AURA_APPLIED", "Player-1-M", "Mira Vale", 1459, "Arcane Intellect")
Advance(3)
equal(#whispers .. " " .. whispers[1].target .. "/" .. whispers[2].target, "2 Zriel Gustbellow/Mira Vale", "two casters, two whispers")

-- Each skip tick: on, no whisper (Send says why); off, a whisper.
local function Case(label, key, setup, why, onIsDefault)
    for _, skip in ipairs({true, false}) do
        Fresh(thanks)
        settings[key] = skip
        local report = setup()
        report()
        Advance(3)
        if skip then
            equal(#whispers .. " " .. Last(), "0 skipped: " .. why, label .. " ticked: skipped")
        else
            equal(#whispers, 1, label .. " unticked: whispered")
        end
    end
    settings[key] = onIsDefault
end
Case("Skip Your Group", "thankBuffsSkipGroup", function()
    units.party1 = {guid = "Player-1-A", first = "Ann", surname = "Oak", player = true, party = true}
    return function() Added(Aura({sourceUnit = "party1", name = "Thorns", spellId = 467})) end
end, "your group", true)
Case("Skip Your Group (a group member seen in the log)", "thankBuffsSkipGroup", function()
    units.party2 = {guid = "Player-1-A", first = "Ann", surname = "Oak", player = true, party = true}
    return function() Log("SPELL_AURA_APPLIED", "Player-1-A", "Ann Oak", 467, "Thorns") end
end, "your group", true)
Case("Skip Your Guild", "thankBuffsSkipGuild", function()
    units.target = {guid = "Player-1-B", first = "Bo", surname = "Elm", player = true, guild = "Filth"}
    return function() Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467})) end
end, "your guild", true)
Case("Skip Your Guild (by GUID)", "thankBuffsSkipGuild", function()
    world.guildGuids["Player-1-B"] = true
    return function() Log("SPELL_AURA_APPLIED", "Player-1-B", "Bo Elm", 467, "Thorns") end
end, "your guild", true)
Case("Skip Your Guild (a guildmate with no token, on the member list by name)", "thankBuffsSkipGuild", function()
    world.roster = {{name = "Ann Oak"}, {name = "Bo Elm-Forever", guid = "Player-1-OLD"}}
    return function() Log("SPELL_AURA_APPLIED", "Player-1-B", "Bo Elm", 467, "Thorns") end
end, "your guild", true)
Case("Skip Your Guild (on the member list by GUID)", "thankBuffsSkipGuild", function()
    world.roster = {{name = SECRET, guid = SECRET}, {name = "Someone Else", guid = "Player-1-B"}}
    return function() Log("SPELL_AURA_APPLIED", "Player-1-B", "Bo Elm", 467, "Thorns") end
end, "your guild", true)
-- Out of a guild, the member list isn't read.
Fresh(thanks)
units.player.guild = nil
world.roster = {{name = "Bo Elm"}}
Log("SPELL_AURA_APPLIED", "Player-1-B", "Bo Elm", 467, "Thorns")
Advance(3)
equal(#whispers, 1, "out of a guild: an old member list doesn't skip anyone")
Case("Skip Your Friends", "thankBuffsSkipFriends", function()
    world.friends["Player-1-C"] = true
    return function() Log("SPELL_AURA_APPLIED", "Player-1-C", "Cy Ash", 467, "Thorns") end
end, "your friend", false)
Case("Skip Your Friends (Battle.net)", "thankBuffsSkipFriends", function()
    world.bnet["Player-1-C"] = true
    return function() Log("SPELL_AURA_APPLIED", "Player-1-C", "Cy Ash", 467, "Thorns") end
end, "your friend", false)
Case("Skip in Combat", "thankBuffsSkipCombat", function()
    world.combat = true
    return function() Log("SPELL_AURA_APPLIED", "Player-1-D", "Dee Yew", 467, "Thorns") end
end, "in a fight", true)
Case("Skip in Dungeons", "thankBuffsSkipInstances", function()
    world.instance = true
    return function() Log("SPELL_AURA_APPLIED", "Player-1-D", "Dee Yew", 467, "Thorns") end
end, "in an instance", true)
-- A fight that starts during the wait skips it too.
Fresh(thanks)
Log("SPELL_AURA_APPLIED", "Player-1-D", "Dee Yew", 467, "Thorns")
world.combat = true
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: in a fight", "a fight starting in the wait: skipped")
-- Guild, group and friends unreadable: they count as not, so a whisper goes.
Fresh(thanks)
local realGuild, realFriends = GetGuildInfo, C_FriendList
_G.GetGuildInfo, _G.C_FriendList = function() error("no guild here") end, nil
settings.thankBuffsSkipFriends = true
units.target = {guid = "Player-1-B", first = "Bo", surname = "Elm", player = true}
Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467}))
Advance(3)
equal(#whispers, 1, "an unreadable guild or friends list: skipped quietly, the whisper goes")
_G.GetGuildInfo, _G.C_FriendList = realGuild, realFriends
settings.thankBuffsSkipFriends = false

-- Secret fields: an aura whose every read fails, a secret caster in the
-- log, a secret list: never an error or a whisper, each skipped as secret.
Fresh(thanks)
Added(Erroring())
equal(#errors .. " " .. #whispers .. " " .. #outcomes .. " " .. Last(), "0 0 1 skipped: secret",
    "an aura that errors on every read: skipped as secret")
Log("SPELL_AURA_APPLIED", SECRET, SECRET, 467, "Thorns")
Advance(3)
equal(#errors .. " " .. #whispers .. " " .. #outcomes .. " " .. Last(), "0 0 2 skipped: secret",
    "a secret caster in the log: skipped as secret")
Fire("UNIT_AURA", "player", setmetatable({}, {__index = function() error("secret list") end}))
equal(#errors .. " " .. #outcomes .. " " .. Last(), "0 3 skipped: secret", "a list that errors: skipped as secret")
Fire("UNIT_AURA", "player", SECRET)
Added(Erroring())
Advance(3)
equal(#errors .. " " .. #whispers .. " " .. #outcomes .. " " .. #thanks.pending, "0 0 5 0", "a secret list, another secret aura: skipped, nothing queued")
Fire("UNIT_AURA", SECRET, {addedAuras = {Aura({sourceUnit = "target", name = "Thorns"})}})
Advance(3)
equal(#errors .. " " .. #whispers .. " " .. #outcomes, "0 0 5", "a secret unit: left alone")
-- Secret fields on an aura of a real caster: secret where it matters, so no whisper.
Fresh(thanks)
units.target = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Added(Aura({sourceUnit = SECRET, name = "Thorns", spellId = 467}))
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: secret", "a secret source unit: no whisper")
-- A secret name, though, only loses the spell's name: the ID gives it.
Fresh(thanks)
units.target = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Added(Aura({sourceUnit = "target", name = SECRET, spellId = 467}))
Advance(3)
equal(#whispers .. " " .. whispers[1].text, "1 Thanks for the Thorns!", "a secret spell name: named from its ID")
-- Secret event type in the log: not even taken.
Fresh(thanks)
Log(SECRET, "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
equal(#outcomes .. " " .. #whispers .. " " .. thanks.logState, "0 0 secret", "a secret log row: the log's state says secret")
-- A log row that can't be read at all: the state says so, nothing breaks.
local realInfo = CombatLogGetCurrentEventInfo
_G.CombatLogGetCurrentEventInfo = function() error("held back") end
Fire("COMBAT_LOG_EVENT_UNFILTERED")
equal(#errors .. " " .. #outcomes .. " " .. thanks.logState, "0 0 unreadable", "an unreadable log row: no error, the state says unreadable")
_G.CombatLogGetCurrentEventInfo = realInfo

-- A restricted combat log: nothing read from it; the aura report alone
-- thanks a caster with a unit token (a nameplate here).
Fresh(thanks)
world.restricted = true
units.nameplate3 = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
equal(#outcomes .. " " .. #thanks.pending .. " " .. thanks.logState, "0 0 restricted", "restricted: the log isn't read")
Added(Aura({sourceUnit = "nameplate3", name = "Thorns", spellId = 467}))
Advance(3)
equal(#whispers .. " " .. whispers[1].target .. " " .. thanks.logState .. " " .. table.concat(outcomes, ","),
    "1 Zriel Gustbellow restricted whispered", "the aura report's unit token: whispered while the log was restricted")
-- The caster's GUID from the aura, shown by a token: thanked.
Fresh(thanks)
world.restricted = true
local hidden = Aura({noUnit = true, name = "Thorns", spellId = 467})
world.casterGuids[hidden.auraInstanceID] = "Player-1-Z"
units.mouseover = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Added(hidden)
Advance(3)
equal(#whispers .. " " .. whispers[1].target .. " " .. Last(), "1 Zriel Gustbellow whispered", "no source unit, its caster's GUID on mouseover: thanked")

-- No unit token and no name for the GUID, no whisper: the caster hidden, a
-- stranger nothing shows and the game can't name, a first name alone in
-- the log.
Fresh(thanks)
Added(Aura({noUnit = true, name = "Thorns", spellId = 467}))
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: caster hidden", "the caster hidden: no whisper")
Fresh(thanks)
hidden = Aura({noUnit = true, name = "Thorns", spellId = 467})
world.casterGuids[hidden.auraInstanceID] = "Player-1-S"
Added(hidden)
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: no unit token", "a stranger no token shows and the game can't name: no whisper")
Fresh(thanks)
Log("SPELL_AURA_APPLIED", "Player-1-S", "Stran", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: first name only", "a first name alone: no whisper")
Fresh(thanks)
units.focus = {guid = "Player-1-S", first = "Stran", surname = "Ger", player = true}
Log("SPELL_AURA_APPLIED", "Player-1-S", "Stran", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. whispers[1].target .. " " .. Last(), "1 Stran Ger whispered", "a first name, but on focus: whispered by the whole name")

-- A stranger no unit token shows, whose GUID the aura gives (as a druid
-- passing by does here): the game names the GUID, and they're thanked.
local STRANGER = "Player-1-S"
local function FromStranger(name, spellId, guid)
    local aura = Aura({noUnit = true, name = name, spellId = spellId})
    world.casterGuids[aura.auraInstanceID] = guid or STRANGER
    Added(aura)
end
-- Whether every GUID the game was asked to name was the caster's.
local function AskedOnly(guid)
    for _, asked in ipairs(world.asked) do if asked ~= guid then return false end end
    return #world.asked > 0
end
local function First(i) return whispers[i] and (whispers[i].target .. " | " .. whispers[i].text) or "-" end
settings.thankBuffsMessage = "Ty %name% for the %spell%"
-- First name and surname as two answers.
Fresh(thanks)
world.names[STRANGER] = {"Zriel", "Gustbellow"}
FromStranger("Mark of the Wild", 1126)
Advance(3)
equal(#whispers .. " " .. First(1) .. " " .. Last() .. " " .. tostring(AskedOnly(STRANGER)),
    "1 Zriel Gustbellow | Ty Zriel for the Mark of the Wild whispered true",
    "a stranger named by GUID (first, surname): one whisper to the whole name, %name% the first name, only their GUID asked")
-- The whole name in one answer, the second empty.
Fresh(thanks)
world.names[STRANGER] = {"Zriel Gustbellow", ""}
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. First(1), "1 Zriel Gustbellow | Ty Zriel for the Thorns", "named by GUID (the whole name, \"\"): whispered as it is")
-- UnitNameFromGUID missing, erroring or secret: GetPlayerInfoByGUID names them.
local realByGuid = UnitNameFromGUID
for _, way in ipairs({"missing", "erroring", "secret"}) do
    Fresh(thanks)
    if way == "missing" then _G.UnitNameFromGUID = nil
    elseif way == "erroring" then _G.UnitNameFromGUID = function() error("not here") end
    else world.names[STRANGER] = {SECRET, SECRET} end
    world.info[STRANGER] = {"Zriel", "Gustbellow"}
    FromStranger("Thorns", 467)
    Advance(3)
    equal(#errors .. " " .. #whispers .. " " .. First(1), "0 1 Zriel Gustbellow | Ty Zriel for the Thorns",
        "UnitNameFromGUID " .. way .. ": named by GetPlayerInfoByGUID")
    _G.UnitNameFromGUID = realByGuid
end
Fresh(thanks)
world.info[STRANGER] = {"Zriel Gustbellow", ""}
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. First(1), "1 Zriel Gustbellow | Ty Zriel for the Thorns", "GetPlayerInfoByGUID's whole name in one answer: whispered as it is")
-- Neither names them, or only someone else: no whisper.
Fresh(thanks)
world.names["Player-1-OTHER"], world.info["Player-1-OTHER"] = {"Quin", "Fir"}, {"Quin", "Fir"}
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. Last() .. " " .. tostring(AskedOnly(STRANGER)), "0 skipped: no unit token true",
    "neither lookup names the caster (another GUID's name known): no whisper")
-- Secret answers from both: no whisper, no error.
Fresh(thanks)
world.names[STRANGER], world.info[STRANGER] = {SECRET, SECRET}, {SECRET, SECRET}
FromStranger("Thorns", 467)
Advance(3)
equal(#errors .. " " .. #whispers .. " " .. Last(), "0 0 skipped: no unit token", "both lookups secret: no whisper, no error")
-- Your own GUID: nothing taken, nothing asked.
Fresh(thanks)
world.names[ME], world.info[ME] = {"Tabitantu", "Stagkiller"}, {"Tabitantu", "Stagkiller"}
FromStranger("Thorns", 467, ME)
Advance(3)
equal(#whispers .. " " .. #outcomes .. " " .. #world.asked, "0 0 0", "your own GUID on the aura: nothing")
-- A unit token showing them still wins over the GUID's name.
Fresh(thanks)
units.mouseover = {guid = STRANGER, first = "Zriel", surname = "Gustbellow", player = true}
world.names[STRANGER] = {"Wrong", "Name"}
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. First(1) .. " " .. #world.asked, "1 Zriel Gustbellow | Ty Zriel for the Thorns 0", "a token shows them: its name, the GUID not asked")
-- A first name alone in the log, the GUID named: whispered by the whole name.
Fresh(thanks)
world.names[STRANGER] = {"Stran", "Ger"}
Log("SPELL_AURA_APPLIED", STRANGER, "Stran", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. First(1), "1 Stran Ger | Ty Stran for the Thorns", "a first name in the log, the GUID named: whispered by the whole name")
-- Two buffs a second apart: one whisper naming both.
Fresh(thanks)
world.names[STRANGER] = {"Zriel", "Gustbellow"}
FromStranger("Mark of the Wild", 1126)
Advance(1)
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. First(1) .. " " .. table.concat(outcomes, ","), "1 Zriel Gustbellow | Ty Zriel for the Mark of the Wild and Thorns whispered",
    "two buffs from a stranger named by GUID: one whisper naming both")
-- Not named as the buff lands, named by the whisper: thanked.
Fresh(thanks)
FromStranger("Thorns", 467)
local queued = #thanks.pending
world.names[STRANGER] = {"Zriel", "Gustbellow"}
Advance(3)
equal(queued .. " " .. #whispers .. " " .. First(1), "1 1 Zriel Gustbellow | Ty Zriel for the Thorns", "named only by the time of the whisper: thanked")
-- A first name alone from UnitNameFromGUID: GetPlayerInfoByGUID's whole
-- name (in one answer, or joined) wins, both asked.
for _, info in ipairs({{"Zriel Gustbellow", ""}, {"Zriel", "Gustbellow"}}) do
    Fresh(thanks)
    world.names[STRANGER], world.info[STRANGER] = {"Zriel", ""}, info
    FromStranger("Thorns", 467)
    Advance(3)
    equal(#whispers .. " " .. First(1) .. " " .. #world.asked, "1 Zriel Gustbellow | Ty Zriel for the Thorns 2",
        "a first name from UnitNameFromGUID, (" .. info[1] .. ", " .. info[2] .. ") from GetPlayerInfoByGUID: the whole name")
end
-- A whole name from UnitNameFromGUID: GetPlayerInfoByGUID not asked.
Fresh(thanks)
world.names[STRANGER], world.info[STRANGER] = {"Zriel", "Gustbellow"}, {"Wrong", "Name"}
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. First(1) .. " " .. #world.asked, "1 Zriel Gustbellow | Ty Zriel for the Thorns 1",
    "a whole name from UnitNameFromGUID: the other lookup not asked")
-- Only a first name from both: that name, as for a unit with no surname.
Fresh(thanks)
world.names[STRANGER], world.info[STRANGER] = {"Zriel", ""}, {"Zriel", ""}
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. First(1), "1 Zriel | Ty Zriel for the Thorns", "only a first name from both lookups: whispered by it, as a unit with no surname")
-- "Unknown" while the game still fetches the name counts as none: named by
-- the whisper, thanked; never named, no whisper and nothing kept.
_G.UNKNOWNOBJECT = "Unknown"
Fresh(thanks)
world.names[STRANGER] = {"Unknown", ""}
FromStranger("Thorns", 467)
world.names[STRANGER] = {"Zriel", "Gustbellow"}
Advance(3)
equal(#whispers .. " " .. First(1), "1 Zriel Gustbellow | Ty Zriel for the Thorns", "\"Unknown\" as the buff lands, named by the whisper: thanked")
Fresh(thanks)
world.names[STRANGER], world.info[STRANGER] = {"Unknown", ""}, {"Unknown", ""}
FromStranger("Thorns", 467)
Advance(3)
equal(#whispers .. " " .. Last() .. " " .. tostring(next(EraUIClassicCharDB.thankBuffsQuiet or {})), "0 skipped: no unit token nil",
    "only \"Unknown\" from both lookups: no whisper, nothing kept")
_G.UNKNOWNOBJECT = nil
settings.thankBuffsMessage = "Thanks for the %spell%!"
-- The skip ticks for a caster known only by GUID and the name the game gave:
-- no unit token in the checks, the name from the GUID.
local function GuidCase(label, key, setup, why, default)
    for _, skip in ipairs({true, false}) do
        Fresh(thanks)
        settings[key] = skip
        world.names[STRANGER] = {"Zriel", "Gustbellow"}
        setup()
        FromStranger("Thorns", 467)
        Advance(3)
        local seen = tostring(sent and sent.unit) .. " " .. tostring(sent and sent.target)
        if skip then
            equal(#whispers .. " " .. Last() .. " " .. seen, "0 skipped: " .. why .. " nil Zriel Gustbellow", label .. " ticked: skipped")
        else
            equal(#whispers .. " " .. seen, "1 nil Zriel Gustbellow", label .. " unticked: whispered")
        end
    end
    settings[key] = default
end
GuidCase("Skip Your Group (named by GUID, in your group by GUID)", "thankBuffsSkipGroup", function()
    world.groupGuids[STRANGER] = true
end, "your group", true)
GuidCase("Skip Your Guild (named by GUID, a guild member by GUID)", "thankBuffsSkipGuild", function()
    world.guildGuids[STRANGER] = true
end, "your guild", true)
GuidCase("Skip Your Guild (named by GUID, on the member list by that name)", "thankBuffsSkipGuild", function()
    world.roster = {{name = "Zriel Gustbellow"}}
end, "your guild", true)
GuidCase("Skip Your Friends (named by GUID, a friend by GUID)", "thankBuffsSkipFriends", function()
    world.friends[STRANGER] = true
end, "your friend", false)
-- A token that moves on during the wait: the name taken when it was read.
Fresh(thanks)
units.nameplate2 = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Added(Aura({sourceUnit = "nameplate2", name = "Thorns", spellId = 467}))
units.nameplate2 = {guid = "Player-1-Q", first = "Quin", surname = "Fir", player = true}
Advance(3)
equal(#whispers .. " " .. whispers[1].target, "1 Zriel Gustbellow", "the token now shows someone else: still the caster thanked")
-- A token whose GUID and name were hidden as the buff landed, showing
-- someone else by the whisper: never whispered (nor group or guild checked).
Fresh(thanks)
units.target = {player = true}
Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467}))
units.target = {guid = "Player-1-Q", first = "Quin", surname = "Fir", player = true}
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: name hidden", "a token with nothing known of the caster: the next player on it isn't whispered")
-- With no GUID but the whole name read then, the token counts only while
-- it shows that name.
Fresh(thanks)
settings.thankBuffsSkipGroup = true
units.party1 = {first = "Ann", surname = "Oak", player = true, party = true}
Added(Aura({sourceUnit = "party1", name = "Thorns", spellId = 467}))
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: your group", "no GUID, the token still showing them: the group check uses it")
Fresh(thanks)
units.target = {first = "Bo", surname = "Elm", player = true}
Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467}))
units.target = {first = "Quin", surname = "Fir", player = true, guild = "Filth"}
Advance(3)
equal(#whispers .. " " .. whispers[1].target, "1 Bo Elm", "no GUID, the token moved on: the name read then, not the new player's guild")

-- Never you, your pet, an NPC, another's pet or a lasting aura.
Fresh(thanks)
units.target = {guid = ME, first = "Tabitantu", surname = "Stagkiller", player = true}
units.pet = {guid = "Pet-1-P", first = "Imp", player = false}
units.partypet1 = {guid = "Pet-1-Q", first = "Wolf", player = false}
Log("SPELL_AURA_APPLIED", ME, "Tabitantu Stagkiller", 467, "Thorns")
Added(Aura({sourceUnit = "player", name = "Thorns"}), Aura({sourceUnit = "pet", name = "Blood Pact"}),
    Aura({sourceUnit = "target", name = "Thorns"}))
local mine = Aura({noUnit = true, name = "Thorns"})
world.casterGuids[mine.auraInstanceID] = ME
Added(mine)
Log("SPELL_AURA_APPLIED", "Player-1-X", "Tabitantu Stagkiller", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. #outcomes .. " " .. Last(), "0 1 skipped: your own", "you: never whispered, and only another GUID with your name is taken")
Fresh(thanks)
units.partypet1 = {guid = "Pet-1-Q", first = "Wolf", player = false}
Log("SPELL_AURA_APPLIED", "Creature-0-1-2-3-4-5", "Priestess of Elune", 1126, "Mark of the Wild")
Log("SPELL_AURA_APPLIED", "Pet-0-1-2", "Imp", 6307, "Blood Pact")
Added(Aura({sourceUnit = "partypet1", name = "Blood Pact"}))
Log("SPELL_AURA_APPLIED", nil, nil, 1126, "Zone Buff")
Advance(3)
equal(#whispers .. " " .. table.concat(outcomes, ","), "0 skipped: not a player,skipped: not a player,"
    .. "skipped: not a player,skipped: caster hidden", "an NPC, a pet, another's pet, the zone: none whispered")
Fresh(thanks)
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns", "DEBUFF")
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns", "BUFF", "Player-1-OTHER")
Log("SPELL_CAST_SUCCESS", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Added(Aura({sourceUnit = "target", isHelpful = false, name = "Curse"}))
Advance(3)
equal(#whispers .. " " .. #outcomes, "0 0", "a debuff, a buff on someone else, a cast: nothing")
Fresh(thanks)
settings.thankBuffsSkipGroup = false
units.party1 = {guid = "Player-1-A", first = "Ann", surname = "Oak", player = true, party = true}
Added(Aura({sourceUnit = "party1", name = "Devotion Aura", duration = 0}))
world.lasting[19746] = true
Log("SPELL_AURA_APPLIED", "Player-1-A", "Ann Oak", 19746, "Devotion Aura")
Advance(3)
equal(#whispers .. " " .. table.concat(outcomes, " / "), "0 skipped: a lasting aura / skipped: a lasting aura",
    "a group member's lasting aura: no thanks")
settings.thankBuffsSkipGroup = true

-- Chat locked: no whisper.
Fresh(thanks)
world.lockdown = true
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
equal(#whispers .. " " .. Last(), "0 skipped: chat locked", "chat locked: no whisper")
-- A whisper the game refuses: never retried.
Fresh(thanks)
local realSend = C_ChatInfo.SendChatMessage
C_ChatInfo.SendChatMessage = function() error("not now") end
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
equal(Last() .. " " .. tostring(thanks:Quiet("Player-1-Z")) .. " " .. #outcomes, "skipped: the game didn't send it false 1", "refused: not counted as thanked, not tried again")
C_ChatInfo.SendChatMessage = realSend

-- Arriving somewhere: the auras listed in the first three seconds were cast before.
Fresh(thanks)
units.target = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Fire("PLAYER_ENTERING_WORLD")
Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467}))
Advance(3.5)
equal(#whispers .. " " .. #outcomes, "0 0", "just arrived: auras already on you are left out")
Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467}))
Advance(3)
equal(#whispers, 1, "after three seconds: thanked")

-- The placeholders and the words.
local W = thanks.Words
equal(W("Hey %name%, thanks for %SPELL%! %foo%", "Zriel", {"Mark of the Wild"}), "Hey Zriel, thanks for Mark of the Wild! %foo%",
    "%name% the first name, %spell% the buff, any case; an unknown one stays")
equal(W("%spell%", "Zriel", {"A", "B", "C"}) .. " / " .. W("%spell%", "Zriel", {"A", "B"}) .. " / " .. W("%spell%", "Zriel", {"A"}),
    "A, B and C / A and B / A", "buffs joined: A, B and C")
equal(W("", "Zriel", {"Thorns"}) .. " / " .. W("   ", "Zriel", {"Thorns"}) .. " / " .. W(nil, "Zriel", {"Thorns"}),
    "Thanks for the Thorns! / Thanks for the Thorns! / Thanks for the Thorns!", "no words: the first ones")
equal(W("%name%", "", {"Thorns"}), "Thanks for the Thorns!", "words that come out empty: the first ones")
equal(W("|cffff0000Ty|r %spell%|| x\nnext", "Zriel", {"Thorns"}), "Ty Thorns x next", "colour codes, bars and line breaks taken out")
local long = W(string.rep("\195\169", 200), "Zriel", {"Thorns"})
equal(#long .. " " .. tostring(long:sub(-2) == "\195\169"), "254 true", "at most 255 bytes, never half a letter")
-- Your own words, from the setting.
Fresh(thanks)
settings.thankBuffsMessage = "Ty %name% for the %spell%"
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 1126, "Mark of the Wild")
Advance(3)
equal(whispers[1].text, "Ty Zriel for the Mark of the Wild", "the saved words, filled in")
settings.thankBuffsMessage = "Thanks for the %spell%!"

-- Nothing of the reports is kept: fifteen buffs nobody can be thanked for
-- save nothing, and the quiet goes straight into its saved table with no
-- settings save.
Fresh(thanks)
local before = {}
for key in pairs(settings) do before[#before + 1] = key end
for i = 1, 15 do Added(Aura({noUnit = true, name = "Buff" .. i})) end
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
local after = {}
for key in pairs(settings) do after[#after + 1] = key end
equal(#outcomes .. " " .. #whispers .. " " .. #before .. "/" .. #after .. " " .. setCalls .. " " .. tostring(next(EraUIClassicCharDB.thankBuffsQuiet) ~= nil),
    "16 1 " .. #before .. "/" .. #before .. " 0 true", "nothing added to EraUIDB, no settings save, only the quiet kept")

-- Switched off in the wait: nothing goes, nothing listens.
Fresh(thanks)
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
settings.thankBuffs = false
thanks:Refresh()
Advance(3)
equal(#whispers .. " " .. tostring(next(frame.events)) .. " " .. #thanks.pending, "0 nil 0", "off in the wait: no whisper, no events, queue dropped")
settings.thankBuffs = true
thanks:Refresh()
equal(frame.events.UNIT_AURA, "player", "on again: listening")

-- A /reload inside the 30 minutes: the quiet holds, as it's saved.
Fresh(thanks)
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 467, "Thorns")
Advance(3)
equal(#whispers, 1, "before the reload: thanked")
thanks = Load()
settings.thankBuffs = true
thanks:Refresh()
Advance(10 * 60)
Log("SPELL_AURA_APPLIED", "Player-1-Z", "Zriel Gustbellow", 1126, "Mark of the Wild")
Advance(3)
equal(#whispers .. " " .. Last(), "1 skipped: thanked already", "after a /reload 10 minutes on: still quiet")
Log("SPELL_AURA_APPLIED", "Player-1-Z2", "Zriel Gustbellow", 1126, "Mark of the Wild")
Advance(3)
equal(#whispers .. " " .. Last(), "1 skipped: thanked already", "and by whole name too")
-- Stamps older than 30 minutes go as the next thanks is noted.
Advance(31 * 60)
Log("SPELL_AURA_APPLIED", "Player-1-M", "Mira Vale", 1459, "Arcane Intellect")
Advance(3)
local kept = {}
for key in pairs(EraUIClassicCharDB.thankBuffsQuiet) do kept[#kept + 1] = key end
table.sort(kept)
equal(#whispers .. " " .. table.concat(kept, ","), "2 Player-1-M,mira vale", "old stamps dropped, the new one kept")

-- A game that refuses the combat log to addons: the aura report alone.
refuseLog = true
thanks = Load()
settings.thankBuffs = true
thanks:Refresh()
Fresh(thanks)
units.target = {guid = "Player-1-Z", first = "Zriel", surname = "Gustbellow", player = true}
Added(Aura({sourceUnit = "target", name = "Thorns", spellId = 467}))
Advance(3)
equal(thanks.logState .. " " .. tostring(thanks.frame.events.COMBAT_LOG_EVENT_UNFILTERED) .. " " .. #whispers .. " " .. Last(),
    "not registered nil 1 whispered", "the log refused: thanked from the aura report")
refuseLog = false
equal(#errors, 0, "no errors reported")

print("TestThankBuffs: " .. checks .. " checks passed")
