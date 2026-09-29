-- Run the actual update check: versions shared with guild and group, never in
-- combat and not too often, one chat line when someone has a newer EraUI,
-- and nothing but a version number read from a message.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local now, combat, guild, raid, party, instance = 100, false, true, false, false, false
local sentMessages, printed, timers, frames = {}, {}, {}, {}
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
local registered
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix) registered = prefix end,
    IsAddonMessagePrefixRegistered = function(prefix) return prefix == registered end,
    SendAddonMessage = function(prefix, text, channel)
        assert(not combat, "addon message sent in combat")
        sentMessages[#sentMessages + 1] = prefix .. "|" .. text .. "|" .. channel
    end,
}
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(e) self.events[e] = true end
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
assert(loadfile("Modules/UpdateCheck.lua"))("EraUI", E)
local M = E.modules.UpdateCheck
M:Initialize()
local function Sent() local text = table.concat(sentMessages, ";"); sentMessages = {}; return text end

Equal(registered, "EraUI", "listening from the moment the file loads")
Equal(M:Status(), "Update notice: on, listening", "and /era status says so")

-- Comparing versions.
Equal(M.Newer("1.2.1", "1.2.0"), true, "a later patch is newer")
Equal(M.Newer("1.10.0", "1.9.9"), true, "numbers, not text")
Equal(M.Newer("1.2", "1.2.0"), false, "1.2 is 1.2.0")
Equal(M.Newer("1.1.0", "1.2.0"), false, "older isn't newer")
Equal(M.Newer("100.0.0", "1.2.0"), false, "a made-up far-off version isn't believed")
Equal(M.Newer("1.2.1; print(1)", "1.2.0"), false, "anything but a version is ignored")

-- Sharing.
Equal(registered, "EraUI", "its own hidden message channel")
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

-- Hearing.
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.2.0", "GUILD", "Squirt-Zephras")
Equal(#printed, 0, "the same version says nothing")
Fire("CHAT_MSG_ADDON", "EraUI", "v:9.9.9", "GUILD", "Zriel-Zephras")
Equal(#printed, 0, "your own share coming back is ignored")
Fire("CHAT_MSG_ADDON", "Other", "v:9.9.9", "GUILD", "Squirt-Zephras")
Equal(#printed, 0, "other addons' messages are ignored")
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.3.0", "GUILD", "Squirt-Zephras")
Equal(printed[1], "Version 1.3.0 is out (you have 1.2.0). Update from CurseForge or GitHub.", "a newer version is announced")
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.4.0", "PARTY", "Coww-Zephras")
Equal(#printed, 1, "once a session")
now = now + 61
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.1.0", "GUILD", "Rumble-Zephras")
Equal(Sent(), "EraUI|v:1.2.0|GUILD", "an older version hears yours back")
Fire("CHAT_MSG_ADDON", "EraUI", "v:1.1.0", "GUILD", "Bella-Zephras")
Equal(Sent(), "", "without flooding the channel")

-- Whispers: anyone can whisper, so only one from yourself is believed.
assert(loadfile("Modules/UpdateCheck.lua"))("EraUI", E)
M = E.modules.UpdateCheck
printed, sentMessages = {}, {}
M:Heard("v:99.0.0", "WHISPER", "Coww")
M:Heard("v:9.9.9", "WHISPER", "Coww-Zephras")
M:Heard("v:9.9.9", "WHISPER", nil)
Equal(#printed, 0, "a whisper from someone else is ignored")
M:Heard("v:1.1.0", "WHISPER", "Coww")
Equal(Sent(), "", "and never answered")
-- Public channels, say and yell could be anyone too.
M:Heard("v:99.0.0", "CHANNEL", "Coww-Zephras")
M:Heard("v:99.0.0", "SAY", "Coww")
M:Heard("v:99.0.0", "YELL", "Coww")
M:Heard("v:1.1.0", "SAY", "Coww")
Equal(#printed .. " " .. Sent(), "0 ", "a public channel, say or yell is ignored and never answered")
M:Heard("v:1.3.0", "GUILD", "Squirt-Zephras")
Equal(printed[1], "Version 1.3.0 is out (you have 1.2.0). Update from CurseForge or GitHub.",
    "so it can't use up the real notice")

-- A sender the game hides is never compared.
assert(loadfile("Modules/UpdateCheck.lua"))("EraUI", E)
M = E.modules.UpdateCheck
printed = {}
issecretvalue = function(value) return value == "Hidden Sender" end
M:Heard("v:9.9.9", "GUILD", "Hidden Sender")
M:Heard("v:9.9.9", "WHISPER", "Hidden Sender")
issecretvalue = nil
Equal(#printed, 0, "a hidden sender says nothing")

-- Testing it on yourself: a whisper to yourself counts.
M:Heard("v:9.9.9", "WHISPER", "Zriel")
Equal(printed[1], "Version 9.9.9 is out (you have 1.2.0). Update from CurseForge or GitHub.", "a whisper to yourself tests it")
M:Heard("v:9.9.9", "WHISPER", "Zriel-Zephras")
Equal(#printed, 1, "still once a session")

-- On Forever the game gives your surname as UnitName's second value, and a
-- whisper to yourself comes from "First Surname".
assert(loadfile("Modules/UpdateCheck.lua"))("EraUI", E)
M = E.modules.UpdateCheck
printed = {}
UnitName = function() return "Zriel", "Gustbellow" end
M:Heard("v:9.9.9", "WHISPER", "Zriel Gustbellow")
Equal(printed[1], "Version 9.9.9 is out (you have 1.2.0). Update from CurseForge or GitHub.", "a whisper from First Surname is yours")
M:Heard("v:9.9.9", "GUILD", "Zriel Gustbellow")
M:Heard("v:9.9.9", "WHISPER", "Zriel Otherperson")
Equal(#printed, 1, "your own guild share is ignored, and a different surname isn't you")
UnitName = function() return "Zriel" end

-- Switched off: nothing shared or said.
assert(loadfile("Modules/UpdateCheck.lua"))("EraUI", E)
M = E.modules.UpdateCheck
settings.updateCheck = false
printed, sentMessages = {}, {}
M:Share()
M:Heard("v:1.3.0", "GUILD", "Squirt")
Equal(#sentMessages + #printed, 0, "off: silent both ways")
Equal(M:Status(), "Update notice: off", "and /era status says it's off")

io.write("Update check checks passed: " .. checks .. " assertions.\n")
