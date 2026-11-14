-- Arrow Keys in Chat (Modules/ExtraQoL.lua, 14 Nov 2026) on a small model of
-- the game's chat boxes. Each box has the game's Alt switch (on by default,
-- as the chat box template sets it). The option turns the switch off on every
-- box, whisper windows opened later too; off puts it back; with the option
-- never on, no box is touched. Run from the addon root.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end

local settings = {}
local E = { modules = {} }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return settings[key] end

local calls = 0
local function Box()
    local box = { alt = true }
    function box:SetAltArrowKeyMode(on) calls = calls + 1; self.alt = on end
    function box:GetAltArrowKeyMode() return self.alt end
    return box
end
NUM_CHAT_WINDOWS = 3
CHAT_FRAMES = { "ChatFrame1", "ChatFrame2", "ChatFrame3" }
for i = 1, 3 do _G["ChatFrame" .. i .. "EditBox"] = Box() end

-- The game's whisper pop-out: a new chat frame and box, listed in CHAT_FRAMES.
local hooked
function FCF_OpenTemporaryWindow()
    local name = "ChatFrame" .. (#CHAT_FRAMES + 1)
    CHAT_FRAMES[#CHAT_FRAMES + 1] = name
    _G[name .. "EditBox"] = Box()
end
function hooksecurefunc(name, after)
    equal(name, "FCF_OpenTemporaryWindow", "the only hook is on opening a whisper window")
    local original = _G[name]
    _G[name] = function(...) original(...); after(...) end
    hooked = true
end
CreateFrame = function()
    return { RegisterEvent = function() end, SetScript = function(self, _, fn) self.onEvent = fn end }
end

assert(loadfile("Modules/ExtraQoL.lua"))("EraUI", E)
local Module = E.modules.ExtraQoL
Module.SetupTooltipIDs, Module.SetupLinkToggle = function() end, function() end
Module.CheckDurability = function() end
Module:Initialize()
equal(hooked, true, "it hooks the whisper window opening")

local function Alts()
    local t = {}
    for _, name in ipairs(CHAT_FRAMES) do t[#t + 1] = tostring(_G[name .. "EditBox"].alt) end
    return table.concat(t, ",")
end

-- Off (the default): nothing touched, at load, on entering the world, or
-- when a whisper window opens.
equal(calls, 0, "off: no box touched at load")
Module.events.onEvent(nil, "PLAYER_ENTERING_WORLD")
FCF_OpenTemporaryWindow()
equal(calls, 0, "off: no box touched on entering the world or a whisper window")
equal(Alts(), "true,true,true,true", "off: every box keeps the game's Alt switch")

-- On: every box, the whisper window included, takes plain arrows.
settings.chatArrowKeys = true
Module:ApplyChatArrows()
equal(Alts(), "false,false,false,false", "on: every chat box takes plain arrows")
FCF_OpenTemporaryWindow()
equal(Alts(), "false,false,false,false,false", "on: a whisper window opened later takes them too")

-- A /reload with it on: applied again on entering the world.
_G.ChatFrame1EditBox.alt = true
Module.events.onEvent(nil, "PLAYER_ENTERING_WORLD")
equal(_G.ChatFrame1EditBox.alt, false, "on: entering the world sets it again")

-- Off again: Alt back on every box, and later whisper windows left alone.
settings.chatArrowKeys = false
Module:ApplyChatArrows()
equal(Alts(), "true,true,true,true,true", "off again: the game's Alt switch back on every box")
local before = calls
Module:ApplyChatArrows()
FCF_OpenTemporaryWindow()
equal(calls, before, "off again: nothing touched after that")

-- A missing box or a frame name with no box is skipped.
CHAT_FRAMES[#CHAT_FRAMES + 1] = "NoSuchFrame"
settings.chatArrowKeys = true
Module:ApplyChatArrows()
equal(_G.ChatFrame2EditBox.alt, false, "a frame with no box is skipped, the rest still set")

print("Chat arrow key checks passed: " .. checks .. " assertions.")
