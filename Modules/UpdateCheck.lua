-- Tells you in chat when a newer EraUI is out. An addon can't look at
-- CurseForge, so EraUI shares its version with your guild and group in a
-- hidden addon message, never in combat, and says once a session when
-- someone has a newer one. A message is only ever read as a version number,
-- and a whisper is only believed from yourself.
local _, EraUI = ...
local M = {}
EraUI:RegisterModule("UpdateCheck", M)

local PREFIX = "EraUI"
local WAIT = 60 -- seconds between shares on the same channel
local sent = {} -- channel -> when it was last shared
local pending, told

-- "1.2.0" as numbers, or nil for anything else. Each part stays small, so a
-- made-up message can't claim a far-off version.
local function Parse(text)
    if type(text) ~= "string" or #text > 12 then return nil end
    local a, b, c = text:match("^(%d+)%.(%d+)%.?(%d*)$")
    a, b, c = tonumber(a), tonumber(b), tonumber(c) or 0
    if not (a and b) or a > 99 or b > 99 or c > 99 then return nil end
    return { a, b, c }
end

-- Whether version a is newer than version b.
function M.Newer(a, b)
    a, b = Parse(a), Parse(b)
    if not (a and b) then return false end
    for i = 1, 3 do
        if a[i] ~= b[i] then return a[i] > b[i] end
    end
    return false
end

local function On()
    return EraUIDB ~= nil and EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("updateCheck") ~= false
end

-- Hearing other players' versions needs the message name registered; it's
-- done as the file loads and again at login, and kept for /era status.
local function Listening()
    return C_ChatInfo and C_ChatInfo.IsAddonMessagePrefixRegistered
        and C_ChatInfo.IsAddonMessagePrefixRegistered(PREFIX) or false
end

local function Listen()
    if not (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or Listening() then return end
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    M.listenResult = ok and tostring(result) or ("error: " .. tostring(result))
end

-- The channels you can share with right now.
local function Channels()
    local list = {}
    if IsInGuild and IsInGuild() then list[#list + 1] = "GUILD" end
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        list[#list + 1] = "INSTANCE_CHAT"
    elseif IsInRaid and IsInRaid() then
        list[#list + 1] = "RAID"
    elseif IsInGroup and IsInGroup() then
        list[#list + 1] = "PARTY"
    end
    return list
end

local function Send(channel)
    local now = GetTime()
    if sent[channel] and now - sent[channel] < WAIT then return end
    sent[channel] = now
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, "v:" .. EraUI.version, channel)
    M.lastSend = channel .. ": " .. (ok and tostring(result) or "error")
end

-- Shares your version on every channel you're in, or just one; in combat it
-- waits for the fight to end.
function M:Share(only)
    if not On() or not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
    if InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    for _, channel in ipairs(only and { only } or Channels()) do Send(channel) end
end

local TRUSTED = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }

local function Hidden(value)
    return issecretvalue and issecretvalue(value)
end

function M:Heard(text, channel, sender)
    if not On() or type(text) ~= "string" or Hidden(text) or Hidden(sender) then return end
    local version = text:match("^v:(.+)$")
    if not Parse(version) then return end
    -- Your own shares come back to you and are ignored. A whisper only counts
    -- from yourself, for testing; anyone else's is ignored. Otherwise only the
    -- channels EraUI shares on count, where it's people you play with: a
    -- public channel, say or yell could be anyone. Messages come from
    -- "First Surname", which EraUI:IsPlayer knows is you.
    local mine = EraUI:IsPlayer(sender)
    if channel == "WHISPER" then
        if not mine then return end
    elseif not TRUSTED[channel] or mine then
        return
    end
    if M.Newer(version, EraUI.version) then
        if not told then
            told = true
            EraUI:Print(("Version %s is out (you have %s). Update from CurseForge or GitHub."):format(version, EraUI.version))
        end
    elseif M.Newer(EraUI.version, version) and channel ~= "WHISPER" then
        -- Theirs is older: share yours back, so they hear about it too.
        self:Share(channel)
    end
end

-- A line for /era status.
function M:Status()
    if EraUIDB and EraUI:GetSetting("updateCheck") == false then return "Update notice: off" end
    if Listening() then return "Update notice: on, listening" .. (M.lastSend and (", last shared on " .. M.lastSend) or "") end
    return "Update notice: on, but the game didn't allow listening (" .. tostring(M.listenResult or "no result") .. ")"
end

function M:Initialize()
    Listen()
end

Listen()
local events = CreateFrame("Frame")
events:RegisterEvent("CHAT_MSG_ADDON")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, ...)
    if event == "CHAT_MSG_ADDON" then
        local prefix, text, channel, sender = ...
        if prefix == PREFIX then M:Heard(text, channel, sender) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pending then M:Share() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Once the guild and group are known.
        C_Timer.After(15, function() M:Share() end)
    else
        M:Share()
    end
end)
