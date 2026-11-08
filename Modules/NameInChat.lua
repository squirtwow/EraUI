local _, EraUI = ...

-- Name in Chat (/era > Chat & Names > Name in chat; off by default,
-- experimental). The name you set goes in brackets before what you send to
-- your party, raid or guild (a tick each, all on), or Say (a tick, off):
-- "(Squirt) Hello". Whispers, Battle.net whispers, channels, yell and
-- emotes never change.
-- The game tells addons when a typed line is about to go: the edit box's
-- "ChatFrame.OnEditBoxPreSendText" (EventRegistry), after its /command is
-- read and before its text is. The name goes into the box's text then.
-- Nothing of the game's is hooked or replaced, and nothing is written on its
-- frames. A line that is empty, already starts with a name it put on (a line
-- from chat history, even after the name changed), or would not fit the chat
-- box goes as it is: your words are never cut.
local Names = {}
EraUI:RegisterModule("NameInChat", Names)

local EVENT = "ChatFrame.OnEditBoxPreSendText"
-- The chat box holds 255 bytes you see (a link's hidden codes don't count)
-- and 1280 in all. Names are at most 24 letters.
local MOST, ALL, LONGEST = 255, 1280, 24
Names.EVENT, Names.MOST, Names.ALL, Names.LONGEST = EVENT, MOST, ALL, LONGEST
-- Each "(Name) " put on a line this session.
Names.used = {}
-- Each tick, the chat types it covers and its default, should a setting be
-- missing.
local TICKS = {
    {key = "nameInChatParty", on = true, kinds = {"PARTY", "INSTANCE_CHAT"}},
    {key = "nameInChatRaid", on = true, kinds = {"RAID", "RAID_WARNING"}},
    {key = "nameInChatGuild", on = true, kinds = {"GUILD", "OFFICER"}},
    {key = "nameInChatSay", on = false, kinds = {"SAY"}},
}
local TICK_OF = {}
for _, tick in ipairs(TICKS) do
    for _, kind in ipairs(tick.kinds) do TICK_OF[kind] = tick end
end

local function Secret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
-- One of the game's functions: its first answer, nil when it fails or is secret.
local function Ask(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok or Secret(value) then return nil end
    return value
end

-- At most most letters, never cutting one in two.
local function Cap(text, most)
    local count, at = 0, 1
    while at <= #text do
        count = count + 1
        if count > most then return text:sub(1, at - 1) end
        local byte = text:byte(at)
        at = at + ((byte >= 0xF0 and 4) or (byte >= 0xE0 and 3) or (byte >= 0xC0 and 2) or 1)
    end
    return text
end
-- The bytes of a line you see: colour codes and the hidden part of a link
-- left out. A typed bar ("||") stays two bytes and a link's end mark is
-- counted, so it never comes out short.
local function Seen(text)
    text = text:gsub("||", "\1\1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h", "")
    return #text
end
-- The name as it goes in chat: chat codes out, one line, single spaces, no
-- brackets of its own round it, at most 24 letters. "" when there's none.
function Names.Clean(name)
    if Secret(name) or type(name) ~= "string" then return "" end
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|", "")
    name = name:gsub("%c", " "):gsub("%s+", " ")
    name = name:match("^%s*(.-)%s*$")
    local inner = name:match("^%((.-)%)$")
    if inner then name = inner:match("^%s*(.-)%s*$") end
    return (Cap(name, LONGEST):gsub("%s+$", ""))
end
-- "(Name) ", or nil with no name.
function Names.Prefix(name)
    name = Names.Clean(name)
    if name == "" then return nil end
    return "(" .. name .. ") "
end

function Names:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("nameInChat") == true
end
-- Whether this chat type gets the name: its tick is on.
function Names.Covers(kind)
    local tick = type(kind) == "string" and TICK_OF[kind] or nil
    if not tick then return false end
    local value = EraUI:GetSetting(tick.key)
    if value == nil then value = tick.on end
    return value == true
end
-- The line with the name before it and the "(Name) " used, or nil to leave
-- it as it is.
function Names:Words(text, kind)
    if Secret(kind) or type(kind) ~= "string" or not Names.Covers(kind) then return nil end
    if Secret(text) or type(text) ~= "string" or not text:find("%S") then return nil end
    local prefix = Names.Prefix(EraUI:GetSetting("nameInChatName"))
    if not prefix then return nil end
    local body = text:match("^%s*(.*)$")
    if body:sub(1, #prefix) == prefix then return nil end
    for used in pairs(Names.used) do
        if body:sub(1, #used) == used then return nil end
    end
    local words = prefix .. body
    if Seen(words) > MOST or #words >= ALL then return nil end
    return words, prefix
end

-- The edit box's chat type: its own method, else its attribute.
local function KindOf(editBox)
    local kind = type(editBox.GetChatType) == "function" and Ask(editBox.GetChatType, editBox) or nil
    if kind == nil and type(editBox.GetAttribute) == "function" then kind = Ask(editBox.GetAttribute, editBox, "chatType") end
    return kind
end
-- Just before a typed line goes: the name in front, when it's for this
-- line. Chat locked by the game: left alone.
function Names:Apply(editBox)
    if not self:On() or type(editBox) ~= "table" or type(editBox.GetText) ~= "function" or type(editBox.SetText) ~= "function" then return end
    local chat = C_ChatInfo
    if chat and Ask(chat.InChatMessagingLockdown) then return end
    local words, prefix = self:Words(Ask(editBox.GetText, editBox), KindOf(editBox))
    if words and pcall(editBox.SetText, editBox, words) then self.used[prefix] = true end
end
-- The callback gets this module first (its owner), then the edit box.
local function PreSend(first, second)
    local editBox = second
    if first ~= Names then editBox = first end
    local ok, problem = pcall(Names.Apply, Names, editBox)
    if not ok then Names.problem = problem end
end
Names.PreSend = PreSend

-- Listens while it's on, and stops when it's off: one callback, never two.
function Names:Refresh()
    local registry = EventRegistry
    if type(registry) ~= "table" or type(registry.RegisterCallback) ~= "function" then return end
    if self:On() then
        if self.listening then return end
        self.listening = pcall(registry.RegisterCallback, registry, EVENT, PreSend, Names) == true
    elseif self.listening then
        if type(registry.UnregisterCallback) == "function" then pcall(registry.UnregisterCallback, registry, EVENT, Names) end
        self.listening = false
    end
end

function Names:Initialize()
    self:Refresh()
end
