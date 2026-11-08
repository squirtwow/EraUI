-- Name in Chat (/era > Chat & Names > Name in chat; Modules/NameInChat.lua)
-- through a fake EventRegistry and a fake chat edit box, sent the way the
-- game sends a typed line (its pre-send notice, then the text read): off by
-- default; on, "(Name) " before party, instance, raid, raid warning, guild
-- and officer lines, Say only when ticked, never whispers, channels, yell or
-- emotes, even with every tick on; each tick on and off; no second name on a
-- line from history, even after a rename; too long (the bytes you see, links'
-- hidden codes not counted, or the box's 1280 in all), empty name or line, a
-- secret or odd chat type, chat locked: as it is; the name cleaned (codes, spaces, brackets, length); live on and off
-- with exactly one callback; nothing written on the box; no error ever.
-- Run from the addon folder.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local SECRET = setmetatable({}, {__tostring = function() return "SECRET" end})
_G.issecretvalue = function(value) return value == SECRET end
local lockdown = false
_G.C_ChatInfo = {InChatMessagingLockdown = function() return lockdown end}

-- The game's EventRegistry, as its callback registry works: one callback
-- per owner and event, called with the owner first.
local registry = {callbacks = {}, registers = 0, unregisters = 0}
function registry:RegisterCallback(event, fn, owner)
    assert(type(event) == "string" and type(fn) == "function" and owner ~= nil, "bad RegisterCallback")
    self.registers = self.registers + 1
    self.callbacks[event] = self.callbacks[event] or {}
    self.callbacks[event][owner] = fn
end
function registry:UnregisterCallback(event, owner)
    self.unregisters = self.unregisters + 1
    if self.callbacks[event] then self.callbacks[event][owner] = nil end
end
function registry:TriggerEvent(event, ...)
    for owner, fn in pairs(self.callbacks[event] or {}) do fn(owner, ...) end
end
function registry:Count(event)
    local n = 0
    for _ in pairs(self.callbacks[event] or {}) do n = n + 1 end
    return n
end
_G.EventRegistry = registry

-- A chat edit box: its methods, its text and attributes; any key written
-- on it is noted (there must be none).
local writes = 0
local function Box(kind, text, how)
    local state = {text = text or "", attributes = {chatType = kind}, sets = 0}
    local methods = {}
    function methods:GetText()
        if how == "textErrors" then error("no text") end
        if how == "secretText" then return SECRET end
        return state.text
    end
    function methods:SetText(value)
        if how == "setErrors" then error("can't set") end
        state.sets = state.sets + 1
        state.text = value
    end
    function methods:GetAttribute(name) return state.attributes[name] end
    if how ~= "attributeOnly" then
        function methods:GetChatType()
            if how == "typeErrors" then error("no type") end
            return self:GetAttribute("chatType")
        end
    end
    local box = setmetatable({}, {__index = methods, __newindex = function() writes = writes + 1 end})
    return box, state
end
-- Sends a line as the game does: the notice, then what the box holds.
local EVENT = "ChatFrame.OnEditBoxPreSendText"
local function Send(kind, text, how)
    local box, state = Box(kind, text, how)
    registry:TriggerEvent(EVENT, box)
    return state.text, state.sets
end

local settings
local function Load()
    settings = {enabled = true, nameInChat = false, nameInChatName = "", nameInChatParty = true, nameInChatRaid = true,
        nameInChatGuild = true, nameInChatSay = false}
    local E = {modules = {}}
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    function E:GetSetting(key) return settings[key] end
    assert(loadfile("Modules/NameInChat.lua"))("EraUI", E)
    local names = E.modules.NameInChat
    names:Initialize()
    return names, E
end

-- The defaults line up with Core/Init.lua.
do
    local real = {}
    local era, make = _G.EraUI, _G.CreateFrame
    _G.CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
    assert(loadfile("Core/Init.lua"))("EraUI", real)
    _G.EraUI, _G.CreateFrame = era, make
    local d = real.settingDefaults
    equal(tostring(d.nameInChat) .. " [" .. tostring(d.nameInChatName) .. "] " .. tostring(d.nameInChatParty) .. tostring(d.nameInChatRaid)
        .. tostring(d.nameInChatGuild) .. tostring(d.nameInChatSay) .. " " .. tostring(real.reloadSettings.nameInChat),
        "false [] truetruetruefalse nil", "off by default, no name, party, raid and guild ticked, say not, no reload")
end

-- Off: nothing listens, a line goes as it is.
local names = Load()
settings.nameInChatName = "Squirt"
equal(registry:Count(EVENT) .. " " .. registry.registers, "0 0", "off: no callback")
equal(Send("PARTY", "Hello"), "Hello", "off: the line as it is")

-- On: one callback, owned by the module.
settings.nameInChat = true
names:Refresh()
equal(registry:Count(EVENT) .. " " .. registry.registers .. " " .. tostring(registry.callbacks[EVENT][names] ~= nil), "1 1 true",
    "on: one callback, the module its owner")
names:Refresh(); names:Refresh()
equal(registry:Count(EVENT) .. " " .. registry.registers, "1 1", "refreshed while on: still one, never registered again")

-- Each chat type, with the ticks as they come.
local ON = {PARTY = true, INSTANCE_CHAT = true, RAID = true, RAID_WARNING = true, GUILD = true, OFFICER = true}
for _, kind in ipairs({"PARTY", "INSTANCE_CHAT", "RAID", "RAID_WARNING", "GUILD", "OFFICER", "SAY", "WHISPER", "BN_WHISPER",
    "CHANNEL", "YELL", "EMOTE", "AFK", "DND"}) do
    local text, sets = Send(kind, "Hello")
    equal(text .. " " .. sets, ON[kind] and "(Squirt) Hello 1" or "Hello 0", kind .. (ON[kind] and ": the name before it" or ": as it is"))
end
equal(Send("PARTY", "Hello there, pull in 5"), "(Squirt) Hello there, pull in 5", "the whole line kept after the name")

-- Each tick off, then on.
local TICKS = {nameInChatParty = {"PARTY", "INSTANCE_CHAT"}, nameInChatRaid = {"RAID", "RAID_WARNING"},
    nameInChatGuild = {"GUILD", "OFFICER"}, nameInChatSay = {"SAY"}}
for key, kinds in pairs(TICKS) do
    local was = settings[key]
    for _, value in ipairs({false, true}) do
        settings[key] = value
        for _, kind in ipairs(kinds) do
            equal(Send(kind, "Hi"), value and "(Squirt) Hi" or "Hi", key .. " " .. tostring(value) .. ": " .. kind)
        end
    end
    -- A missing tick takes its default.
    settings[key] = nil
    for _, kind in ipairs(kinds) do
        equal(Send(kind, "Hi"), key ~= "nameInChatSay" and "(Squirt) Hi" or "Hi", key .. " missing: its default for " .. kind)
    end
    settings[key] = was
end
equal(settings.nameInChatSay, false, "Say back off")

-- Every tick on: whispers, Battle.net whispers, channels, yell, emotes, AFK
-- and DND still go as they are.
for key in pairs(TICKS) do settings[key] = true end
for _, kind in ipairs({"WHISPER", "BN_WHISPER", "CHANNEL", "YELL", "EMOTE", "AFK", "DND"}) do
    local text, sets = Send(kind, "Hello")
    equal(text .. " " .. sets, "Hello 0", "every tick on, " .. kind .. ": as it is")
end
settings.nameInChatSay = false

-- A line from chat history already has the name: never a second one.
local text, sets = Send("GUILD", "(Squirt) Hello")
equal(text .. " " .. sets, "(Squirt) Hello 0", "already starting with the name: as it is")
equal(Send("GUILD", "  (Squirt) Hello"), "  (Squirt) Hello", "and with spaces before it")
equal(Send("GUILD", "(Squirt)Hello"), "(Squirt) (Squirt)Hello", "only the name and its space count as the name")
equal(Send("GUILD", "   Hello"), "(Squirt) Hello", "spaces before the words go")

-- After a rename, a line from history keeps the name it went with.
settings.nameInChatName = "Sq"
equal(Send("PARTY", "hi"), "(Sq) hi", "a short name")
settings.nameInChatName = "Squirt"
text, sets = Send("PARTY", "(Sq) hi")
equal(text .. " " .. sets, "(Sq) hi 0", "renamed: a line from history keeps its old name, never two")
equal(Send("PARTY", "(Bob) hi"), "(Squirt) (Bob) hi", "brackets it never put on: the name before them")

-- Too long for the chat box's 255 bytes you see: as it is, never cut.
local fits = string.rep("a", 255 - #"(Squirt) ")
equal(Send("PARTY", fits), "(Squirt) " .. fits, "255 with the name: sent with it")
text, sets = Send("PARTY", fits .. "b")
equal(#text .. " " .. sets, (#fits + 1) .. " 0", "256 with the name: as it is, every letter kept")
local letters = string.rep("\195\169", 123)
equal(Send("PARTY", letters), "(Squirt) " .. letters, "counted in bytes: 9 + 246 is 255")
equal(Send("PARTY", letters .. "x"), letters .. "x", "and one more byte is too long")

-- Links: their hidden codes don't count to the 255, only their words (and
-- their end mark, to be safe).
local LINK = "|cffa335ee|Hitem:16922::::::::60:::::::::|h[Leggings of Transcendence]|h|r"
local loot = "need " .. LINK .. " " .. LINK .. " " .. LINK .. " " .. LINK
equal(#loot > 255, true, "four links pass 255 bytes in all")
equal(Send("RAID", loot), "(Squirt) " .. loot, "four links: the name before them")
local linked = string.rep("a", 246 - 29) .. LINK
equal(Send("PARTY", linked), "(Squirt) " .. linked, "a link counts 29 you see: 9 + 217 + 29 is 255")
equal(Send("PARTY", "b" .. linked), "b" .. linked, "and one more is too long")
-- A typed bar ("||") is never taken for a colour code.
local bars = string.rep("||cffffffff", 22)
equal(Send("PARTY", bars), "(Squirt) " .. bars, "typed bars count as typed: 9 + 242")
equal(Send("PARTY", bars .. "||cffffffff"), bars .. "||cffffffff", "9 + 253 is too long")
-- Never past the box's 1280 bytes in all (one spare).
local function Heavy(n) return "|Hitem:" .. string.rep("1", n) .. "|h[x]|h" end
equal(Send("PARTY", Heavy(1256)), "(Squirt) " .. Heavy(1256), "1279 bytes in all with the name: sent with it")
equal(Send("PARTY", Heavy(1257)), Heavy(1257), "1280 in all: as it is")

-- No name, no words: as it is.
for _, name in ipairs({"", "   ", "()", "|cffff0000|r"}) do
    settings.nameInChatName = name
    text, sets = Send("PARTY", "Hello")
    equal(text .. " " .. sets, "Hello 0", "name [" .. name .. "]: nothing before the line")
end
settings.nameInChatName = nil
equal(Send("PARTY", "Hello"), "Hello", "name missing: as it is")
settings.nameInChatName = SECRET
equal(Send("PARTY", "Hello"), "Hello", "name secret: as it is")
settings.nameInChatName = 42
equal(Send("PARTY", "Hello"), "Hello", "name not words: as it is")
settings.nameInChatName = "Squirt"
for _, line in ipairs({"", "   ", "\t"}) do
    text, sets = Send("PARTY", line)
    equal(text .. "|" .. sets, line .. "|0", "line [" .. line .. "]: as it is, nothing set")
end

-- The chat type: secret, missing or odd is as it is; read from the
-- attribute when the box has no method or its method fails.
equal(Send(SECRET, "Hello"), "Hello", "secret chat type: as it is")
equal(Send(nil, "Hello"), "Hello", "no chat type: as it is")
equal(Send(7, "Hello"), "Hello", "a number for a chat type: as it is")
equal(Send("party", "Hello"), "Hello", "not the game's own word: as it is")
equal(Send("PARTY", "Hello", "attributeOnly"), "(Squirt) Hello", "no GetChatType: the chatType attribute")
equal(Send("PARTY", "Hello", "typeErrors"), "(Squirt) Hello", "GetChatType fails: the attribute")
text, sets = Send("PARTY", "Hello", "secretText")
equal(text .. " " .. sets, "Hello 0", "secret text: left alone")

-- Nothing the box does wrong stops the line or makes an error.
equal(pcall(Send, "PARTY", "Hello", "textErrors"), true, "GetText fails: no error")
equal(pcall(Send, "PARTY", "Hello", "setErrors"), true, "SetText fails: no error")
equal(names.problem, nil, "nothing went wrong in the module itself")
equal(pcall(registry.TriggerEvent, registry, EVENT, nil), true, "no box: no error")
equal(pcall(registry.TriggerEvent, registry, EVENT, "box"), true, "not a box: no error")
equal(pcall(registry.TriggerEvent, registry, EVENT, {}), true, "a box with no methods: no error")

-- Chat locked by the game: as it is.
lockdown = true
equal(Send("PARTY", "Hello"), "Hello", "chat locked: as it is")
lockdown = false

-- Called as a closure (no owner first), the box still counts.
do
    local box, state = Box("RAID", "Go")
    names.PreSend(box)
    equal(state.text, "(Squirt) Go", "the callback without its owner first")
end

-- The name as it goes in chat.
local CLEAN = {
    {"Squirt", "Squirt"},
    {"  Squirt  ", "Squirt"},
    {"Squ    irt", "Squ irt"},
    {"Squ\nirt", "Squ irt"},
    {"(Squirt)", "Squirt"},
    {"( Squirt )", "Squirt"},
    {"Squ(ir)t", "Squ(ir)t"},
    {"|cffff0000Squirt|r", "Squirt"},
    {"Sq|uirt", "Squirt"},
    {"|TInterface\\Icons\\INV_Misc_QuestionMark:0|tSquirt", "Squirt"},
    {"|Hplayer:Squirt|hSquirt|h", "Squirt"},
    {string.rep("x", 30), string.rep("x", 24)},
    {string.rep("x", 23) .. " yz", string.rep("x", 23)},
    {string.rep("\195\169", 30), string.rep("\195\169", 24)},
    {"\226\152\133Squirt", "\226\152\133Squirt"},
    {"", ""}, {"   ", ""}, {"()", ""},
}
for _, case in ipairs(CLEAN) do
    equal(names.Clean(case[1]), case[2], "clean [" .. case[1] .. "]")
end
equal(names.Clean(nil) .. names.Clean(SECRET) .. names.Clean(5), "", "no name, a secret one or a number: none")
equal(names.LONGEST .. " " .. names.MOST .. " " .. names.ALL, "24 255 1280",
    "at most 24 letters, lines at most 255 bytes you see and under 1280 in all")
settings.nameInChatName = " |cff00ff00Squirt|r "
equal(Send("PARTY", "Hello"), "(Squirt) Hello", "a saved name with codes and spaces goes in clean")
settings.nameInChatName = "(Scarykid)"
equal(Send("PARTY", "Hello"), "(Scarykid) Hello", "a name already in brackets gets one pair")
settings.nameInChatName = "Squirt"

-- EraUI switched off as a whole: as it is.
settings.enabled = false
equal(Send("PARTY", "Hello"), "Hello", "EraUI off: as it is")
settings.enabled = true

-- Live: off stops listening, on listens again, never two at once.
settings.nameInChat = false
equal(Send("PARTY", "Hello"), "Hello", "switched off, before its refresh: the line as it is")
names:Refresh()
equal(registry:Count(EVENT) .. " " .. registry.unregisters, "0 1", "off: the callback is gone")
equal(Send("PARTY", "Hello"), "Hello", "off: as it is")
names:Refresh()
equal(registry.unregisters, 1, "off again: nothing more to undo")
for _ = 1, 3 do
    settings.nameInChat = true; names:Refresh()
    equal(registry:Count(EVENT), 1, "on again: one callback")
    equal(Send("RAID", "Hi"), "(Squirt) Hi", "on again: the name goes in")
    settings.nameInChat = false; names:Refresh()
    equal(registry:Count(EVENT), 0, "off again: none")
end
equal(registry.registers .. " " .. registry.unregisters, "4 4", "one register for each time it went on, one unregister each time off")
settings.nameInChat = true; names:Refresh()

-- A second load (a /reload) is one callback too: the same event, its own owner.
do
    registry.callbacks = {}
    registry.registers = 0
    local again = Load()
    settings.nameInChatName, settings.nameInChat = "Squirt", true
    again:Refresh()
    equal(registry:Count(EVENT) .. " " .. registry.registers, "1 1", "reloaded and on: one callback")
end

-- No EventRegistry in this game: nothing listens, no error.
do
    _G.EventRegistry = nil
    local ok = pcall(function()
        local alone = Load()
        settings.nameInChat = true
        alone:Refresh()
    end)
    equal(ok, true, "no EventRegistry: no error")
    _G.EventRegistry = registry
end

equal(writes, 0, "nothing written on the edit box")

print("TestNameInChat: " .. checks .. " checks passed")
