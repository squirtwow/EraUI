-- Run the actual update check: EraUI's own shares with guild and group (for
-- EraUI 1.7.2 and older), never in combat and not too often, a version read
-- from nothing but a number, and the one chat line a session said by the
-- shared update notices (Core/SquirtVersions.lua, tested on its own in
-- TestSquirtVersions.lua), however a newer EraUI is heard.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local now, combat, guild, raid, party, instance = 100, false, true, false, false, false
local sentMessages, printed, said, timers, frames = {}, {}, {}, {}, {}
local settings = { enabled = true, updateCheck = true }
EraUIDB = {} -- saved settings have loaded
GetTime = function() return now end
InCombatLockdown = function() return combat end
IsInGuild = function() return guild end
IsInRaid = function() return raid end
LE_PARTY_CATEGORY_INSTANCE = 2
IsInGroup = function(category) if category == 2 then return instance end return party or raid or instance end
UnitName = function() return "Zriel" end
Ambiguate = function(name) return (name:gsub("%-.*$", "")) end
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, line) said[#said + 1] = line end }
local registered = {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) registered[prefix] = true end,
    IsAddonMessagePrefixRegistered = function(prefix) return registered[prefix] == true end,
    SendAddonMessage = function(prefix, text, channel)
        assert(not combat, "addon message sent in combat")
        sentMessages[#sentMessages + 1] = prefix .. "|" .. text .. "|" .. channel
    end,
}
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(_, fn) self.onEvent = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do if f.events[event] then f.onEvent(f, event, ...) end end
end
local E = { modules = {}, version = "1.2.0" }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return settings[key] end
function E:Print(message) printed[#printed + 1] = message end
assert(loadfile("Core/Utils.lua"))("EraUI", E) -- the shared "is this me" helper

-- A fresh session: the shared notices and this module loaded, and EraUI
-- registered with them as at login.
local M, shared
local function Load()
    SquirtVersions = nil
    frames = {}
    assert(loadfile("Core/SquirtVersions.lua"))()
    shared = SquirtVersions
    assert(loadfile("Modules/UpdateCheck.lua"))("EraUI", E)
    M = E.modules.UpdateCheck
    M:Initialize()
    said = {}
end
Load()
local function Sent() local text = table.concat(sentMessages, ";"); sentMessages = {}; return text end
local LINE = "|cffd8b25cEraUI|r %s is out (you have %s). Update on CurseForge."

Equal(registered.EraUI, true, "listening for older versions from the moment the file loads")
Equal(registered.SquirtVersions, true, "and the shared notices too")
Equal(M:Status(), "Update notice: on, listening, on, the channel not joined yet, 0 players heard, 0 sent", "and /era status says so")

-- Registered with the shared notices: its code, title, gold and version, and the Update Notice tick.
local entry = shared.addons.ER
Equal(entry and entry.title .. " " .. entry.colour .. " " .. entry.version, "EraUI d8b25c 1.2.0", "EraUI is in the shared notices")
Equal(shared:Payload("H"), "H1:ER=1.2.0", "and shares its version there")
settings.updateCheck = false
Equal(shared:Payload("H"), nil, "not with Update Notice off")
Equal(shared:Wanted(), false, "and the shared notices want nothing for it")
settings.updateCheck = true

-- Comparing versions.
Equal(M.Newer("1.2.1", "1.2.0"), true, "a later patch is newer")
Equal(M.Newer("1.10.0", "1.9.9"), true, "numbers, not text")
Equal(M.Newer("1.2", "1.2.0"), false, "1.2 is 1.2.0")
Equal(M.Newer("1.1.0", "1.2.0"), false, "older isn't newer")
Equal(M.Newer("100.0.0", "1.2.0"), false, "a made-up far-off version isn't believed")
Equal(M.Newer("1.2.1; print(1)", "1.2.0"), false, "anything but a version is ignored")

-- Sharing, for older versions.
Fire("PLAYER_ENTERING_WORLD")
Equal(Sent(), "", "not straight away")
for _, fn in ipairs(timers) do fn() end
timers = {}
Equal(Sent(), "EraUI|v:1.2.0|GUILD", "shared with the guild once in the world")
party = true
now = now + 10
Fire("GROUP_ROSTER_UPDATE")
Equal(Sent(), "EraUI|v:1.2.0|PARTY", "and a new group, without repeating the guild")
Fire("GROUP_ROSTER_UPDATE")
Equal(Sent(), "", "not again within a minute")
now = now + 61
combat = true
Fire("GROUP_ROSTER_UPDATE")
Equal(Sent(), "", "never in combat")
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(Sent(), "EraUI|v:1.2.0|GUILD;EraUI|v:1.2.0|PARTY", "but straight after")
party, raid = false, true
now = now + 61
Fire("GROUP_ROSTER_UPDATE")
Equal(Sent():find("|RAID", 1, true) ~= nil, true, "a raid uses the raid channel")
raid, instance = false, true
now = now + 61
Fire("GROUP_ROSTER_UPDATE")
Equal(Sent():find("|INSTANCE_CHAT", 1, true) ~= nil, true, "a dungeon finder group, the instance channel")
instance = false

-- Hearing an older version's share.
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.2.0", "GUILD", "Squirt-Zephras")
Equal(#said, 0, "the same version says nothing")
Fire("CHAT_MSG_ADDON", "EraUI", "v:9.9.9", "GUILD", "Zriel-Zephras")
Equal(#said, 0, "your own share coming back is ignored")
Fire("CHAT_MSG_ADDON", "Other", "v:9.9.9", "GUILD", "Squirt-Zephras")
Equal(#said, 0, "other addons' messages are ignored")
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.3.0", "GUILD", "Squirt-Zephras")
Equal(said[1], LINE:format("1.3.0", "1.2.0"), "a newer version is announced by the shared notices")
Equal(#printed, 0, "and not by EraUI's own Print")
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.4.0", "PARTY", "Coww-Zephras")
Fire("CHAT_MSG_ADDON", "SquirtVersions", "H1:ER=1.5.0", "GUILD", "Bella-Zephras")
Equal(#said, 1, "once a session, however it's heard")
now = now + 61
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.1.0", "GUILD", "Rumble-Zephras")
Equal(Sent(), "EraUI|v:1.2.0|GUILD", "an older version hears yours back")
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.1.0", "GUILD", "Bella-Zephras")
Equal(Sent(), "", "without flooding the channel")
issecretvalue = function(value) return value == "EraUI" end
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.1.0", "GUILD", "Rumble-Zephras")
issecretvalue = nil
Equal(Sent(), "", "a secret message name is never compared")

-- The shared notices' own messages: the same single line.
Load()
Fire("CHAT_MSG_ADDON", "SquirtVersions", "H1:ER=1.6.0", "GUILD", "Bella-Zephras")
Equal(said[1], LINE:format("1.6.0", "1.2.0"), "heard through the shared notices")
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.7.0", "GUILD", "Squirt-Zephras")
Equal(#said, 1, "and not again from an older version's share")

-- Whispers: anyone can whisper, so only one from yourself is believed.
Load()
sentMessages = {}
M:Heard("v:99.0.0", "WHISPER", "Coww")
M:Heard("v:9.9.9", "WHISPER", "Coww-Zephras")
M:Heard("v:9.9.9", "WHISPER", nil)
Equal(#said, 0, "a whisper from someone else is ignored")
M:Heard("v:1.1.0", "WHISPER", "Coww")
Equal(Sent(), "", "and never answered")
-- Public channels, say and yell could be anyone too.
M:Heard("v:99.0.0", "CHANNEL", "Coww-Zephras")
M:Heard("v:99.0.0", "SAY", "Coww")
M:Heard("v:99.0.0", "YELL", "Coww")
M:Heard("v:1.1.0", "SAY", "Coww")
Equal(#said .. " " .. Sent(), "0 ", "a public channel, say or yell is ignored and never answered")
M:Heard("v:1.3.0", "GUILD", "Squirt-Zephras")
Equal(said[1], LINE:format("1.3.0", "1.2.0"), "so it can't use up the real notice")

-- A sender the game hides is never compared.
Load()
issecretvalue = function(value) return value == "Hidden Sender" end
M:Heard("v:9.9.9", "GUILD", "Hidden Sender")
M:Heard("v:9.9.9", "WHISPER", "Hidden Sender")
issecretvalue = nil
Equal(#said, 0, "a hidden sender says nothing")

-- Testing it on yourself: a whisper to yourself counts.
M:Heard("v:9.9.9", "WHISPER", "Zriel")
Equal(said[1], LINE:format("9.9.9", "1.2.0"), "a whisper to yourself tests it")
M:Heard("v:9.9.9", "WHISPER", "Zriel-Zephras")
Equal(#said, 1, "still once a session")

-- On Forever the game gives your surname as UnitName's second value, and a
-- whisper to yourself comes from "First Surname".
UnitName = function() return "Zriel", "Gustbellow" end
Load()
M:Heard("v:9.9.9", "WHISPER", "Zriel Gustbellow")
Equal(said[1], LINE:format("9.9.9", "1.2.0"), "a whisper from First Surname is yours")
M:Heard("v:9.9.9", "GUILD", "Zriel Gustbellow")
M:Heard("v:9.9.9", "WHISPER", "Zriel Otherperson")
Equal(#said, 1, "your own guild share is ignored, and a different surname isn't you")
Load()
M:Heard("v:9.9.9", "WHISPER", "Zriel")
Equal(#said, 0, "with a surname, someone called just Zriel isn't you")
M:Heard("v:9.9.9", "GUILD", "Zriel")
Equal(said[1], LINE:format("9.9.9", "1.2.0"), "so their guild share counts")
UnitName = function() return "Zriel" end

-- A development copy runs as "dev" (no number in its .toc): it shares
-- nothing, and no version it hears is newer or older than it.
E.version = "dev"
Load()
sentMessages = {}
now = now + 61
M:Share()
Equal(Sent(), "", "dev: nothing shared")
Equal(M.Newer("9.9.9", "dev") or M.Newer("dev", "1.0.0"), false, "dev: never newer or older")
M:Heard("v:9.9.9", "GUILD", "Squirt-Zephras")
M:Heard("v:1.0.0", "GUILD", "Rumble-Zephras")
Fire("CHAT_MSG_ADDON", "SquirtVersions", "H1:ER=9.9.9", "GUILD", "Bella-Zephras")
Equal(#said .. " " .. Sent(), "0 ", "dev: nothing said, nothing shared back")
Equal(shared:Payload("H"), nil, "and nothing in the shared notices")
E.version = "1.2.0"

-- Switched off: nothing shared or said, and the shared notices hear of it.
Load()
settings.updateCheck = false
M:Refresh()
sentMessages = {}
M:Share()
M:Heard("v:1.3.0", "GUILD", "Squirt")
Fire("CHAT_MSG_ADDON", "SquirtVersions", "H1:ER=1.6.0", "GUILD", "Bella-Zephras")
Equal(#sentMessages + #said + #printed, 0, "off: silent both ways")
Equal(frames[1].events.CHAT_MSG_ADDON, nil, "the shared notices stop listening")
Equal(M:Status(), "Update notice: off", "and /era status says it's off")

io.write("Update check checks passed: " .. checks .. " assertions.\n")
