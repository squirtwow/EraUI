-- The classic talents key offer (Look/TalentKey.lua, Squirt's go of
-- 2026-10-24) on Tools/TalentMockGame.lua, with the talent window's own
-- files and Core/Commands.lua (for /era talentkey). The mock's key binding
-- calls all fail as always; this test swaps only the two the offer may make
-- (SetBinding, SaveBindings) for recorders and adds what it reads
-- (GetBindingAction, GetCurrentBindingSet, ReloadUI, C_RestrictedActions,
-- EraUIDB). Every other binding call still fails the test.
-- Checked: nothing made at load; the window (size, place, words, buttons,
-- Escape, Dark Mode's hand-overs); when it shows (a few seconds into the
-- world, or the talent window opening first; once a session; waiting behind
-- the welcome and What's New); when it never asks (talents off, an answer
-- kept, a fight, a restriction, N already ours or set to something else,
-- N unreadable, hidden or failing); Use N's exact calls in order, refused
-- in a fight and under a restriction, a refused key; Not now, Escape, Don't
-- ask again and the answers kept; /era talentkey.
-- Run: fengari Tools/TestTalentKey.lua
local Mock = dofile("Tools/TalentMockGame.lua")
local SECRET = Mock.SECRET
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function True(value, label) Equal(value and true or false, true, label) end
local function False(value, label) Equal(value and true or false, false, label) end

local OURS = "CLICK EraUIClassicTalentsBind:LeftButton"
local WORDS = {
    title = "Classic Talents",
    question = "Use N to open the classic talents?",
    quiet = "N will no longer open the game's own talent window.",
    fight = "Use N works once you're out of combat.",
    blocked = "Use N can't change keys here right now. Try again later.",
    failed = "The game didn't take N. Nothing was changed.",
}

local function Tree()
    return { config = 7, tree = 900, unspent = 0, staged = 0,
        nodes = { [101] = { id = 101, group = 11, x = 1000, y = 2000, ranks = 1, max = 1, staged = 0, spell = 1001 } },
        groups = { { groupID = 11, displayName = "Arms", orderIndex = 1 } } }
end

-- A session: a login or a /reload. options: saved (EraUIDB), key (what N
-- does: the game's talents unless given), off (the Talents setting off).
local function Session(options)
    options = options or {}
    local game = Mock.New({ db = { talents = not options.off } })
    game.trees.player = Tree()
    game.spellNames[1001] = "Deflection"
    local env = game.env
    local s = { game = game, env = env, log = {}, printed = {}, saves = 0, reads = 0, restricted = {}, took = true }
    s.key = options.key == nil and "TOGGLETALENTS" or options.key
    env.EraUIDB = options.saved or {}
    env.GetBindingAction = function(key, ...)
        s.reads = s.reads + 1
        s.readArgs = select("#", ...) == 0 and key or (key .. "+" .. select("#", ...))
        if s.readFails then error("bindings not ready") end
        if key ~= "N" then return "" end
        return s.key
    end
    env.SetBinding = function(...)
        local args = { ... }
        for i = 1, select("#", ...) do args[i] = tostring(args[i]) end
        s.log[#s.log + 1] = "SetBinding " .. select("#", ...) .. " " .. table.concat(args, "|")
        return s.took
    end
    env.GetCurrentBindingSet = function()
        s.log[#s.log + 1] = "GetCurrentBindingSet"
        return 2
    end
    env.SaveBindings = function(...)
        s.log[#s.log + 1] = "SaveBindings " .. select("#", ...) .. " " .. tostring((...))
    end
    env.ReloadUI = function()
        local window = rawget(env, "EraUIClassicTalentKey")
        s.log[#s.log + 1] = "ReloadUI " .. tostring(env.EraUIDB.talentKeyPrompt) .. " " .. tostring(window and window:IsShown())
    end
    -- As the game documents it: every restriction reads false while its own
    -- ADDON_RESTRICTION_STATE_CHANGED is being dispatched.
    env.C_RestrictedActions = { IsAddOnRestrictionActive = function(kind)
        if s.restrictionFails then error("unknown restriction " .. tostring(kind)) end
        if s.dispatching then return false end
        return s.restricted[kind] or false
    end }
    env.SlashCmdList = {}
    function game.E:Print(text) s.printed[#s.printed + 1] = text end
    function game.E:SaveSettings() s.saves = s.saves + 1 end
    game.ns.Print = function(text) s.printed[#s.printed + 1] = text end
    s.T = game.Load()
    assert(loadfile("Look/TalentKey.lua", "t", env))("EraUI", game.E)
    assert(loadfile("Core/Commands.lua", "t", env))("EraUI", game.E)
    s.Look = game.Look
    game.Pass()

    function s.Window() return rawget(env, "EraUIClassicTalentKey") end
    function s.Shown()
        local window = s.Window()
        return window ~= nil and window:IsShown()
    end
    function s.Button(text)
        for _, child in ipairs({ s.Window():GetChildren() }) do
            if child:GetObjectType() == "Button" and child:GetText() == text then return child end
        end
    end
    function s.Line(purpose) return s.Look.OwnPiece(s.Window(), purpose) end
    function s.Note() return s.Line("note"):GetText() end
    function s.Enter() game.Fire("PLAYER_ENTERING_WORLD", true, false) end
    function s.Talents() env.TalentMicroButton:Click("LeftButton") end
    function s.TalentWindow() return rawget(env, "EraUIClassicTalents") end
    -- The game's Escape: every listed window that is open, hidden.
    function s.Escape()
        for _, name in ipairs(env.UISpecialFrames) do
            local frame = rawget(env, name)
            if frame and frame:IsShown() then frame:Hide() end
        end
    end
    function s.Slash(text) env.SlashCmdList.ERAUI(text) end
    -- A restriction coming on or off, its event dispatched as the game does.
    function s.Restrict(kind, on)
        s.restricted[kind] = on or nil
        s.dispatching = true
        game.Fire("ADDON_RESTRICTION_STATE_CHANGED", kind, on and 1 or 0)
        s.dispatching = false
    end
    function s.Clean(label)
        Equal(#game.errors, 0, label .. ": nothing handed to the error handler (" .. tostring(game.errors[1]) .. ")")
    end
    return s
end

---------------------------------------------------------------------------
-- Loading, then the offer a few seconds into the world
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, T = s.game, s.env, s.T
    Equal(s.Window(), nil, "nothing made at load")
    Equal(type(T.OfferKey) .. " " .. type(game.ns.AskTalentKey), "function function", "the talent window's hook and /era's way in")
    True(T.active, "the classic talents on after the first pass")
    Equal(s.reads, 0, "N not read at load")
    s.Enter()
    game.Tick(4.9)
    False(s.Shown(), "not at once on entering the world")
    game.Tick(0.2)
    True(s.Shown(), "five seconds in, it asks")
    Equal(s.readArgs, "N", "N read with the key alone")
    Equal(#s.log, 0, "asking changes no key")

    -- The window.
    local window = s.Window()
    local state = game.State(window)
    Equal(window:GetWidth() .. "x" .. window:GetHeight(), "380x150", "380 x 150, sized as it is made")
    Equal(state.strata .. " " .. tostring(state.toplevel) .. " " .. tostring(state.mouse) .. " " .. tostring(state.clamped),
        "DIALOG true true true", "a dialog: on top, takes the mouse, kept on screen")
    local point, relative, relativePoint, x, y = window:GetPoint(1)
    Equal(point .. " " .. tostring(relative == env.UIParent) .. " " .. relativePoint .. " " .. x .. " " .. y, "TOP true TOP 0 -150",
        "at the top of the screen")
    Equal(window:GetParent(), env.UIParent, "a child of UIParent")
    Equal(state.backdrop.edgeFile, "Interface\\DialogFrame\\UI-DialogBox-Border", "the old dialog border")
    Equal(state.backdrop.bgFile, "Interface\\DialogFrame\\UI-DialogBox-Background", "and its background")
    Equal(s.Line("title"):GetText(), WORDS.title, "the title")
    Equal(s.Line("question"):GetText(), WORDS.question, "the question")
    Equal(s.Line("quiet"):GetText(), WORDS.quiet, "the quiet line")
    Equal(s.Line("quiet"):GetText():find("experimental", 1, true), nil, "no experimental on the quiet line")
    Equal(table.concat(game.State(s.Line("quiet")).textColour, ","), "0.7,0.7,0.7", "in grey")
    Equal(s.Note(), "", "no note")
    for _, purpose in ipairs({ "question", "quiet", "note" }) do
        Equal(s.Line(purpose):GetWidth(), 336, purpose .. ": 336 wide, wrapping inside the box")
    end
    local plate = s.Look.OwnPiece(window, "headerPlate")
    Equal(game.State(plate).file, "Interface\\DialogFrame\\UI-DialogBox-Header", "the header plate")
    Equal(select(2, s.Line("title"):GetPoint(1)), plate, "the title on it")
    local order, widths = {}, {}
    for _, child in ipairs({ window:GetChildren() }) do
        order[#order + 1] = child:GetText()
        widths[#widths + 1] = child:GetWidth()
    end
    Equal(table.concat(order, ", "), "Use N, Not now, Don't ask again", "three buttons, in order")
    Equal(table.concat(widths, " "), "100 100 124", "their widths")
    local use, later, never = s.Button("Use N"), s.Button("Not now"), s.Button("Don't ask again")
    Equal(select(2, later:GetPoint(1)), use, "Not now right of Use N")
    Equal(select(2, never:GetPoint(1)), later, "Don't ask again right of Not now")
    Equal(select(1, use:GetPoint(1)) .. " " .. select(4, use:GetPoint(1)) .. " " .. select(5, use:GetPoint(1)), "BOTTOMLEFT 22 18",
        "the row along the bottom")
    True(use:IsEnabled(), "Use N ready")
    -- Dark Mode: the box, the plate and the three buttons handed over.
    local handed = {}
    for _, entry in ipairs(game.darkened) do
        if entry[2] == window then handed[#handed + 1] = entry[1]
        elseif entry[2] == plate then handed[#handed + 1] = entry[1] .. "(" .. tostring(entry[3]) .. ")"
        elseif entry[2] == use or entry[2] == later or entry[2] == never then handed[#handed + 1] = entry[1] end
    end
    Equal(table.concat(handed, " "), "DarkBackdrop DarkWindowArt(frame) DarkRedButton DarkRedButton DarkRedButton",
        "Dark Mode's hand-overs: the box, the plate as frame art, the buttons")
    local listed = 0
    for _, name in ipairs(env.UISpecialFrames) do if name == "EraUIClassicTalentKey" then listed = listed + 1 end end
    Equal(listed, 1, "on Escape's list once")
    for key, text in pairs(WORDS) do
        False(text:find("\226\128\148", 1, true) or text:find("\226\128\147", 1, true), key .. ": no em or en dash")
    end

    -- Use N: the key, the save, the answer and the reload, in that order.
    use:Click("LeftButton")
    Equal(table.concat(s.log, "; "), "SetBinding 2 N|" .. OURS .. "; GetCurrentBindingSet; SaveBindings 1 2; ReloadUI used true",
        "Use N: N set to the Classic Talents entry, the current set saved, the answer kept, the game reloaded with the window still up")
    Equal(env.EraUIDB.talentKeyPrompt, "used", "Use N's answer kept")
    True(s.saves > 0, "and the settings backup told")
    s.Clean("use")
end

-- After the reload: N is ours, so it never asks again.
do
    local s = Session({ saved = { talentKeyPrompt = "used" }, key = OURS })
    s.Enter()
    s.game.Tick(10)
    False(s.Shown(), "after Use N's reload: no offer")
    s.Talents()
    True(s.TalentWindow():IsShown(), "the classic talents open")
    False(s.Shown(), "and still no offer")
    s.Clean("after use")
end

---------------------------------------------------------------------------
-- Once a session; Not now, Escape, Don't ask again
---------------------------------------------------------------------------
do
    local s = Session()
    local game = s.game
    s.Enter()
    game.Tick(5.1)
    True(s.Shown(), "asked")
    s.Button("Not now"):Click("LeftButton")
    False(s.Shown(), "Not now closes it")
    Equal(s.game.env.EraUIDB.talentKeyPrompt, nil, "and keeps no answer")
    Equal(#s.log, 0, "and changes no key")
    s.Talents()
    True(s.TalentWindow():IsShown(), "the talent window opens")
    False(s.Shown(), "but the offer came once this session")
    s.Enter()
    game.Tick(10)
    False(s.Shown(), "entering the world again (a portal) doesn't ask again")
    s.Clean("not now")

    -- The next session asks again.
    local again = Session({ saved = s.env.EraUIDB })
    again.Enter()
    again.game.Tick(5.1)
    True(again.Shown(), "the next session asks again")
    -- Escape is Not now.
    again.Escape()
    False(again.Shown(), "Escape closes it")
    Equal(again.env.EraUIDB.talentKeyPrompt, nil, "as Not now: no answer kept")
    Equal(#again.log, 0, "no key changed")
    again.Clean("escape")

    -- Don't ask again.
    local third = Session({ saved = again.env.EraUIDB })
    third.Enter()
    third.game.Tick(5.1)
    True(third.Shown(), "asked once more")
    third.Button("Don't ask again"):Click("LeftButton")
    False(third.Shown(), "Don't ask again closes it")
    Equal(third.env.EraUIDB.talentKeyPrompt, "never", "and keeps never")
    True(third.saves > 0, "the settings backup told")
    Equal(#third.log, 0, "no key changed")
    third.Clean("never")

    local fourth = Session({ saved = third.env.EraUIDB })
    fourth.Enter()
    fourth.game.Tick(10)
    False(fourth.Shown(), "never: not on entering the world")
    fourth.Talents()
    False(fourth.Shown(), "nor when the talents open")
    fourth.Clean("never kept")
end

---------------------------------------------------------------------------
-- The talent window opening first
---------------------------------------------------------------------------
do
    local s = Session()
    s.Enter()
    s.game.Tick(1)
    s.Talents()
    True(s.TalentWindow():IsShown(), "the talents opened before the five seconds")
    True(s.Shown(), "the offer comes with them")
    s.Button("Not now"):Click("LeftButton")
    s.game.Tick(10)
    False(s.Shown(), "and not again when the five seconds are up")
    s.Clean("talents first")

    -- With no world entered yet in the test at all.
    local t = Session()
    t.Talents()
    True(t.Shown(), "the first opening asks on its own")
    t.Clean("talents only")
end

---------------------------------------------------------------------------
-- When it never asks
---------------------------------------------------------------------------
local function NeverAsked(label, options, prepare)
    local s = Session(options)
    if prepare then prepare(s) end
    s.Enter()
    s.game.Tick(10)
    False(s.Shown(), label .. ": not on entering the world")
    s.game.combat = false
    if not s.T.active then
        Equal(s.game.ns.ToggleTalents(), false, label .. ": the classic talents are off")
    else
        s.Talents()
        True(s.TalentWindow():IsShown(), label .. ": the talents open")
        False(s.Shown(), label .. ": and no offer with them")
    end
    Equal(#s.log, 0, label .. ": no key changed")
    s.Clean(label)
    return s
end

NeverAsked("Talents off", { off = true })
NeverAsked("answered never", { saved = { talentKeyPrompt = "never" } })
NeverAsked("answered Use N", { saved = { talentKeyPrompt = "used" } })
NeverAsked("N already ours", { key = OURS })
NeverAsked("N set to something else", { key = "ACTIONBUTTON5" })
NeverAsked("N hidden", { key = SECRET })
NeverAsked("N not text", { key = 5 })
NeverAsked("N unreadable", nil, function(s) s.readFails = true end)
NeverAsked("no binding read", nil, function(s) s.env.GetBindingAction = nil end)
NeverAsked("a restriction", nil, function(s) s.restricted[1] = true end)
NeverAsked("a map restriction", nil, function(s) s.restricted[4] = true end)
NeverAsked("a hidden restriction", nil, function(s) s.restricted[2] = SECRET end)

do
    -- N free (nothing on it) is offered too.
    local s = Session({ key = "" })
    s.Enter()
    s.game.Tick(5.1)
    True(s.Shown(), "N with nothing on it: offered")
    s.Clean("N free")
    -- The chat restriction doesn't hold a key back; a restriction this
    -- client doesn't know isn't one.
    local t = Session()
    t.restricted[5] = true
    t.Enter()
    t.game.Tick(5.1)
    True(t.Shown(), "the chat restriction alone: offered")
    local u = Session()
    u.restrictionFails = true
    u.Enter()
    u.game.Tick(5.1)
    True(u.Shown(), "a restriction call that fails: offered")
    u.Clean("restriction call fails")
end

-- In a fight at the five seconds: not then, but the talents opening after
-- the fight asks.
do
    local s = Session()
    local game = s.game
    s.Enter()
    game.combat = true
    game.Tick(5.1)
    False(s.Shown(), "in a fight: not at the five seconds")
    s.Talents()
    game.Tick(0.1)
    True(s.TalentWindow():IsShown(), "the talents open in the fight")
    False(s.Shown(), "with no offer")
    s.TalentWindow():Hide()
    game.combat = false
    s.Talents()
    True(s.Shown(), "after the fight, opening the talents asks")
    s.Clean("fight first")

    -- Only the session's first entering of the world counts: a loading
    -- screen later (a portal) doesn't start the five seconds again.
    local t = Session()
    t.Enter()
    t.game.combat = true
    t.game.Tick(5.1)
    False(t.Shown(), "in a fight at the five seconds: not asked")
    t.game.combat = false
    t.Enter()
    t.game.Tick(10)
    False(t.Shown(), "a later loading screen doesn't ask")
    t.Talents()
    True(t.Shown(), "the talents opening still asks")
    t.Clean("portal")
end

-- Behind EraUI's welcome and What's New: waits for them to close.
do
    local s = Session()
    local game, env = s.game, s.env
    local welcome = env.CreateFrame("Frame", "EraUIWelcome", env.UIParent)
    local updates = env.CreateFrame("Frame", "EraUIUpdates", env.UIParent)
    updates:Hide()
    s.Enter()
    game.Tick(5.1)
    False(s.Shown(), "the welcome is up: it waits")
    welcome:Hide()
    updates:Show()
    game.Tick(5)
    False(s.Shown(), "What's New is up: it waits")
    updates:Hide()
    game.Tick(5)
    True(s.Shown(), "both closed: it asks")
    s.Clean("busy")
end

---------------------------------------------------------------------------
-- Use N refused: a fight, a restriction, a key the game refuses
---------------------------------------------------------------------------
do
    local s = Session()
    local game = s.game
    s.Enter()
    game.Tick(5.1)
    local use = s.Button("Use N")
    -- A fight starts with the window up (the lockdown follows the event).
    game.Fire("PLAYER_REGEN_DISABLED")
    False(use:IsEnabled(), "a fight starting: Use N waits")
    Equal(s.Note(), WORDS.fight, "with a note")
    game.combat = true
    game.Run(use, "OnClick", "LeftButton")
    Equal(#s.log, 0, "a click in the fight changes no key")
    True(s.Shown(), "the window stays")
    Equal(s.game.env.EraUIDB.talentKeyPrompt, nil, "no answer kept")
    game.combat = false
    game.Fire("PLAYER_REGEN_ENABLED")
    True(use:IsEnabled(), "the fight over: Use N ready")
    Equal(s.Note(), "", "the note gone")

    -- A restriction comes on: it reads as on only after its event.
    s.Restrict(1, true)
    game.Tick(0.05)
    False(use:IsEnabled(), "an encounter: Use N waits")
    Equal(s.Note(), WORDS.blocked, "with its note")
    game.Run(use, "OnClick", "LeftButton")
    Equal(#s.log, 0, "a click under the restriction changes no key")
    s.Restrict(1, false)
    game.Tick(0.05)
    True(use:IsEnabled(), "the restriction over: Use N ready")

    -- The game refuses the key: nothing saved, kept or reloaded.
    s.took = false
    use:Click("LeftButton")
    Equal(table.concat(s.log, "; "), "SetBinding 2 N|" .. OURS, "the key asked for once")
    Equal(s.Note(), WORDS.failed, "the note says the game didn't take it")
    True(s.Shown(), "the window stays")
    Equal(s.game.env.EraUIDB.talentKeyPrompt, nil, "no answer kept")
    s.log = {}
    s.took = SECRET
    use:Click("LeftButton")
    Equal(table.concat(s.log, "; "), "SetBinding 2 N|" .. OURS, "a hidden answer from the game counts as refused")
    Equal(s.Note(), WORDS.failed, "the same note")
    -- Then it takes it.
    s.log = {}
    s.took = true
    use:Click("LeftButton")
    Equal(table.concat(s.log, "; "), "SetBinding 2 N|" .. OURS .. "; GetCurrentBindingSet; SaveBindings 1 2; ReloadUI used true",
        "taken: saved, kept, reloaded")
    s.Clean("refused")
end

-- While the window is closed, fights come and go without touching it.
do
    local s = Session()
    s.Enter()
    s.game.Tick(5.1)
    s.Button("Not now"):Click("LeftButton")
    s.game.Fire("PLAYER_REGEN_DISABLED")
    s.game.Fire("PLAYER_REGEN_ENABLED")
    False(s.Shown(), "a fight doesn't bring it back")
    s.Clean("closed")
end

---------------------------------------------------------------------------
-- /era talentkey
---------------------------------------------------------------------------
do
    -- "never" forgotten, and the window opens.
    local s = Session({ saved = { talentKeyPrompt = "never" } })
    s.Slash("talentkey")
    True(s.Shown(), "/era talentkey opens it")
    Equal(s.env.EraUIDB.talentKeyPrompt, nil, "never forgotten")
    s.Button("Not now"):Click("LeftButton")
    s.Slash("  TalentKey ")
    True(s.Shown(), "again and again, any case")
    s.Escape()
    s.Talents()
    False(s.Shown(), "the session's offer is spent")
    s.Clean("slash")

    local function Said(options, prepare, line, label)
        local t = Session(options)
        if prepare then prepare(t) end
        t.Slash("talentkey")
        False(t.Shown(), label .. ": no window")
        Equal(t.printed[#t.printed], line, label .. ": says why")
        Equal(#t.log, 0, label .. ": no key changed")
        t.Clean(label)
    end
    Said({ off = true }, nil, "The classic talents are off. Turn on Talents in /era first.", "talents off")
    Said({ key = OURS }, nil, "N already opens the classic talents.", "N already ours")
    Said({ key = "MOVEFORWARD" }, nil, "N is set to something else. Pick a key for Classic Talents in Key Bindings > AddOns.",
        "N set to something else")
    Said({ key = SECRET }, nil, "Your keys can't be read right now. Try again in a moment.", "N hidden")
    Said(nil, function(t) t.readFails = true end, "Your keys can't be read right now. Try again in a moment.", "N unreadable")

    -- In a fight it opens with Use N waiting; "used" isn't forgotten.
    local u = Session({ saved = { talentKeyPrompt = "used" } })
    u.game.combat = true
    u.Slash("talentkey")
    True(u.Shown(), "in a fight: it opens")
    False(u.Button("Use N"):IsEnabled(), "with Use N waiting")
    Equal(u.Note(), WORDS.fight, "and the fight's note")
    Equal(u.env.EraUIDB.talentKeyPrompt, "used", "Use N's answer isn't forgotten")
    u.game.combat = false
    u.game.Fire("PLAYER_REGEN_ENABLED")
    True(u.Button("Use N"):IsEnabled(), "the fight over: ready")
    u.Button("Use N"):Click("LeftButton")
    Equal(table.concat(u.log, "; "), "SetBinding 2 N|" .. OURS .. "; GetCurrentBindingSet; SaveBindings 1 2; ReloadUI used true",
        "Use N from /era talentkey: the same calls")
    u.Clean("slash fight")

    -- Not loaded: /era says so.
    local v = Session()
    v.game.ns.AskTalentKey = nil
    v.Slash("talentkey")
    Equal(v.printed[#v.printed], "The classic talents key offer is not available.", "/era talentkey without the offer says so")
end

print("Talents key offer checks passed: " .. checks .. " assertions.")
