-- Run from the addon root. Forever's chat code is ChatFrameUtil; the old
-- ChatEdit_ and ChatFrame_ names are deprecated copies that the game loads
-- only while its deprecation fallbacks are on (Blizzard_DeprecatedChatInfo).
-- The real Classic/TradeSkill.lua (shift-click a recipe to link it) and
-- Classic/Skin.lua (ns.Whisper, used by the Guild and Who lists) must use
-- ChatFrameUtil first and the old names only where a client has nothing else.
-- The spellbook's shift-click is checked in Tools/TestSpellBookToggle.lua.
local checks = 0
local function Equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local env = setmetatable({}, { __index = _G })
env._G = env
env.CreateFont = function() return setmetatable({}, { __index = function() return function() end end }) end
local ns = { RegisterModule = function() end }
assert(loadfile("Classic/Skin.lua", "t", env))("EraUI", { Classic = ns })
assert(loadfile("Classic/TradeSkill.lua", "t", env))("EraUI", { Classic = ns })

-- The profession list's click handler, a local of TradeSkill.lua.
local function Find(fn, wanted, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for i = 1, 200 do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = Find(value, wanted, seen)
            if found then return found end
        end
    end
end
local rowClick = Find(ns.ShowTradeSkill, "Row_OnClick")
Equal(type(rowClick), "function", "the profession list's click handler")

-- What reached chat, for each mix of the two APIs. new: ChatFrameUtil
-- (Forever), old: the deprecated names.
local said
local function Chat(new, old)
    said = {}
    local function Note(text) said[#said + 1] = text end
    env.ChatFrameUtil = new and {} or nil
    env.ChatEdit_InsertLink, env.ChatEdit_ChooseBoxForSend, env.ChatEdit_ActivateChat, env.ChatFrame_SendTell = nil, nil, nil, nil
    for _, api in ipairs({ new and "new", old and "old" }) do
        local function InsertLink(link) Note(api .. " link " .. link); return true end
        local function ChooseBoxForSend(frame) Note(api .. " choose" .. (frame == env.DEFAULT_CHAT_FRAME and " chat frame" or "")); return env.box end
        local function ActivateChat(box) Note(api .. " activate" .. (box == env.box and " box" or "")) end
        local function SendTell(name) Note(api .. " tell " .. name) end
        if api == "new" then
            env.ChatFrameUtil.InsertLink, env.ChatFrameUtil.ChooseBoxForSend = InsertLink, ChooseBoxForSend
            env.ChatFrameUtil.ActivateChat, env.ChatFrameUtil.SendTell = ActivateChat, SendTell
        elseif api == "old" then
            env.ChatEdit_InsertLink, env.ChatEdit_ChooseBoxForSend = InsertLink, ChooseBoxForSend
            env.ChatEdit_ActivateChat, env.ChatFrame_SendTell = ActivateChat, SendTell
        end
    end
end
local function Said() return table.concat(said, ", ") end

-- ---- Shift-click a recipe in the profession window -------------------------------------
local LINK = "|cffffd000|Henchant:8681|h[Instant Poison]|h|r"
env.C_TradeSkillUI = { GetRecipeLink = function(id) return id == 8681 and LINK or nil end }
env.IsModifiedClick = function(action) return action == "CHATLINK" end
local row = { line = { info = { recipeID = 8681 } } }
local function ShiftClick(new, old, label)
    Chat(new, old)
    local ok, err = pcall(rowClick, row, "LeftButton")
    Equal(ok, true, label .. ": shift-clicking a recipe is not an error (" .. tostring(err) .. ")")
    return Said()
end
Equal(ShiftClick(true, false, "Forever"), "new link " .. LINK, "Forever: the recipe's link goes to chat through ChatFrameUtil")
Equal(ShiftClick(false, true, "old client"), "old link " .. LINK, "old client: through ChatEdit_InsertLink")
Equal(ShiftClick(true, true, "both"), "new link " .. LINK, "both: ChatFrameUtil only")
Equal(ShiftClick(false, false, "neither"), "", "neither: no link, no error")
env.C_TradeSkillUI.GetRecipeLink = function() return nil end
Equal(ShiftClick(true, true, "no link"), "", "a recipe the game gives no link for: nothing sent")

-- ---- Whisper from the Guild and Who lists ------------------------------------------------
env.DEFAULT_CHAT_FRAME = {}
local function Box()
    local box = { shown = false }
    function box:SetText(text) self.text = text end
    function box:Show() self.shown = true end
    function box:SetFocus() self.focus = true end
    function box:GetNumLetters() return #(self.text or "") end
    function box:SetCursorPosition(n) self.cursor = n end
    return box
end
local function Whisper(new, old, label, hasBox)
    env.box = hasBox ~= false and Box() or nil
    env.ChatFrame1EditBox = nil
    Chat(new, old)
    local ok, err = pcall(ns.Whisper, "Squirt Tester")
    Equal(ok, true, label .. ": whispering is not an error (" .. tostring(err) .. ")")
    local box = env.box
    if box then
        Equal(box.text, "/w Squirt Tester ", label .. ": the box holds the whisper line")
        Equal(box.cursor, #"/w Squirt Tester ", label .. ": with the cursor after it")
        Equal(box.focus, true, label .. ": ready to type")
    end
    return Said()
end
Equal(Whisper(true, false, "Forever"), "new choose chat frame, new activate box",
    "Forever: ChatFrameUtil picks and opens the chat box")
Equal(Whisper(false, true, "old client"), "old choose chat frame, old activate box", "old client: the old names")
Equal(Whisper(true, true, "both"), "new choose chat frame, new activate box", "both: ChatFrameUtil only")
-- Neither: the first chat window's box, shown by hand.
env.box = nil
Chat(false, false)
local box = Box()
env.ChatFrame1EditBox = box
local ok, err = pcall(ns.Whisper, "Squirt Tester")
Equal(ok, true, "neither: whispering is not an error (" .. tostring(err) .. ")")
Equal(box.shown and box.text, "/w Squirt Tester ", "neither: the first chat box is shown with the whisper line")
Equal(Said(), "", "neither: nothing else asked")
env.ChatFrame1EditBox = nil
-- No chat box at all: the game's own whisper opener.
Equal(Whisper(true, false, "no box", false), "new choose chat frame, new tell Squirt Tester",
    "no box, Forever: ChatFrameUtil.SendTell")
Equal(Whisper(false, true, "no box, old client", false), "old choose chat frame, old tell Squirt Tester",
    "no box, old client: ChatFrame_SendTell")
Equal(Whisper(true, true, "no box, both", false), "new choose chat frame, new tell Squirt Tester",
    "no box, both: ChatFrameUtil only")
Equal(Whisper(false, false, "no box, neither", false), "", "no box, neither: nothing, no error")
-- No name: nothing happens.
Chat(true, true)
ns.Whisper("")
Equal(Said(), "", "an empty name whispers no one")

print("Chat link and whisper checks passed: " .. checks .. " assertions.")
