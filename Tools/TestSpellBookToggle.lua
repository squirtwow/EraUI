-- The classic spellbook's opening and closing (Look/Spell*.lua, clean-room
-- 2026-10-21) with the real Modules/TrainingGuide.lua and the engine's
-- Escape helper, on Tools/SpellMockGame.lua: secure clicks act as the game
-- runs them, unit watches show the secure frames, and any change EraUI
-- makes to a protected frame in a fight, or any secure frame made in one,
-- fails. EraUI changes no key binding (Squirt's call, 2026-10-21): the
-- micro button's secure pad clicks EraUIClassicSpellBookBind, which opens
-- EraUI's book in and out of a fight; the game's own spellbook key opens
-- the game's own spellbook; a key the player sets on Classic Spellbook in
-- the game's Key Bindings (Bindings.xml, 2026-10-22) clicks the key button
-- too. Run twice: with Combat Spell Dragging, and without (the default now).
local Mock = dofile("Tools/SpellMockGame.lua")
local checks = 0
local function Equal(a, b, label)
    checks = checks + 1
    assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end

local SPELL_FILES = { "Look/SpellKit.lua", "Look/SpellPage.lua", "Look/SpellLayer.lua", "Look/SpellDraw.lua",
    "Look/SpellOpen.lua", "Look/SpellDrag.lua", "Look/SpellModule.lua" }

local function Session(drag)
    local game = Mock.New()
    local env = game.env
    Mock.SpellBook(game, { { name = "General", count = 8 }, { name = "Marksmanship", count = 8 } })
    Mock.GameSpellbook(game)
    env.UnitClass = function() return "Hunter", "HUNTER" end
    env.UnitRace = function() return "Orc", "Orc", 2 end
    env.UnitFactionGroup = function() return "Horde" end
    env.UnitLevel = function() return 20 end
    env.UnitName = function() return "Squirt" end
    env.Enum.TrainerType = { General = 0 }
    game.ns.db.spellDrag = drag
    local E = game.E
    E.ClassTools = {
        Options = function() return {} end,
        Known = function() return false end,
        Skin = function() end,
        Text = function(parent, text) local fs = parent:CreateFontString(); fs.text = text; return fs end,
        Spell = function() return nil end,
    }
    game.Load("Look/Base.lua")
    game.Load("Look/Escape.lua") -- the base's Escape helper (ns.CloseOnEscape)
    game.Load("Modules/TrainingGuide.lua")
    for _, file in ipairs(SPELL_FILES) do game.Load(file) end
    E.modules.TrainingGuide:Initialize()
    game.Login()
    local s = { game = game, env = env, S = E.Look.Spells }
    function s.Book() return env.EraUIClassicSpellBook end
    function s.Layer() return env.EraUIClassicSpellBookClicks end
    function s.Guide() return env.EraUITrainingGuide end
    function s.Open() local b = s.Book(); return b:IsShown() and b:GetAlpha() > 0 end
    -- The micro button: its secure pad clicks the key button (down, then up).
    function s.Micro()
        local key = env.EraUIClassicSpellBookBind
        key:Click("LeftButton", true)
        key:Click("LeftButton", false)
        game.Settle()
    end
    -- The game's own spellbook key.
    function s.GameKey()
        env.PlayerSpellsUtil.ToggleSpellBookFrame()
        game.Settle()
    end
    -- Secure buttons a click would reach on the spell pages (under the chooser).
    function s.LivePages()
        local n = 0
        local function Walk(f)
            for _, child in ipairs(f.children) do
                if child.template and child.template:find("Secure") and child.mouse ~= false
                    and (child.attrs.type or child.attrs.type1) and child:IsVisible() then n = n + 1 end
                Walk(child)
            end
        end
        Walk(s.S.chooser)
        return n
    end
    function s.LiveSpells()
        local n = 0
        for _, f in ipairs(game.frames) do
            if f.template and f.template:find("Secure") and f.attrs.type1 == "spell" and f.mouse ~= false and f:IsVisible() then n = n + 1 end
        end
        return n
    end
    function s.Click(frame)
        frame:Click("LeftButton", false)
        game.Settle()
    end
    function s.Escape()
        local found = env.CloseSpecialWindows()
        game.Settle()
        return found
    end
    return s
end

for _, drag in ipairs({ true, false }) do
    local how = drag and " (spell dragging)" or " (no spell dragging)"
    local s = Session(drag)
    local game, env = s.game, s.env
    local book, layer = s.Book(), s.Layer()
    Equal(book ~= nil and layer ~= nil, true, "book and click layer built at login" .. how)
    Equal(env.EraUIClassicSpellBookBind.attrs.type, drag and "macro" or "click", "key button wired" .. how)
    Equal(layer.attrs.type ~= nil and layer.attrs.unit, "none", "click layer linked and down while closed" .. how)
    Equal(s.Open(), false, "book starts closed" .. how)
    Equal(game.pad and game.pad.real == env.SpellbookMicroButton and game.pad.target == env.EraUIClassicSpellBookBind, true,
        "the spellbook micro button gets a secure pad that clicks the key button" .. how)
    Equal(game.pad.when(), true, "the pad shows while the book is on" .. how)
    Equal(game.registered and game.registered.frame == book and game.registered.shares, true,
        "the book is a sharing window of the window manager" .. how)
    Equal(book.Search ~= nil and book.Ranks ~= nil and book.PageText ~= nil and book.PrevPage ~= nil and book.NextPage ~= nil
        and #book.Buttons == 12 and #book.SkillTabs == 8 and book.TrainTab ~= nil and book.Title ~= nil and #book.BookTabs == 3
        and type(book.SetLayer) == "function" and type(book.Refresh) == "function", true,
        "the book carries what the Training Guide uses" .. how)

    -- The micro button opens, closes, opens.
    s.Micro()
    Equal(s.Open(), true, "the micro button opens the book" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "player true", "open book raises the click layer" .. how)
    Equal(s.LiveSpells() > 0, true, "spells on the page can be clicked" .. how)
    if drag then
        Equal(game.gameBook:IsShown() and game.gameBook:GetAlpha() == 0, true, "the game's own book opens with it, unseen")
    end
    s.Micro()
    Equal(s.Open(), false, "it closes the book" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "closed book lowers the click layer" .. how)
    if drag then Equal(game.gameBook:IsShown(), false, "the game's own book closes with it") end
    s.Micro()
    Equal(s.Open(), true, "and opens it again" .. how)

    -- The Training Guide tab.
    s.Click(book.TrainTab)
    Equal(book.trainingShown, true, "Training Guide tab selected" .. how)
    Equal(s.Guide():IsShown(), true, "guide shown in the book" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "guide keeps the click layer down" .. how)
    Equal(s.LiveSpells(), 0, "no spell can be clicked through the guide" .. how)
    s.Micro()
    Equal(s.Open(), false, "the micro button closes the book from the Training Guide" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "and leaves the click layer down" .. how)
    s.Micro()
    Equal(s.Open(), true, "it opens it again" .. how)
    Equal(book.trainingShown and s.Guide():IsVisible(), true, "still on the Training Guide" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "reopened guide keeps the layer down" .. how)
    Equal(s.LiveSpells(), 0, "nothing clickable through the reopened guide" .. how)
    s.Micro()
    Equal(s.Open(), false, "closes it again" .. how)
    s.Micro()
    Equal(s.Open(), true, "and opens it again" .. how)

    -- Back to the spells from a school tab.
    s.Click(book.SkillTabs[1])
    Equal(book.trainingShown, false, "school tab leaves the guide" .. how)
    Equal(s.Guide():IsShown(), false, "guide hidden" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "player true", "click layer back up" .. how)
    Equal(s.LiveSpells() > 0, true, "spells clickable again" .. how)
    s.Micro()
    Equal(s.Open(), false, "closes the spell pages" .. how)
    s.Micro()
    Equal(s.Open(), true, "opens the spell pages" .. how)

    -- A fight on the spell pages.
    game.EnterCombat()
    s.Micro()
    Equal(s.Open(), false, "the micro button closes the spell pages in a fight" .. how)
    Equal(layer.attrs.unit, "none", "click layer down in a fight" .. how)
    Equal(s.LiveSpells(), 0, "nothing clickable on the closed book in a fight" .. how)
    s.Micro()
    Equal(s.Open(), true, "and opens them in a fight" .. how)
    Equal(s.LiveSpells() > 0, true, "spells clickable in a fight" .. how)
    game.LeaveCombat()
    Equal(s.Open(), true, "book stays open after the fight" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "player true", "layer up after the fight" .. how)

    -- A fight with the Training Guide already open.
    s.Click(book.TrainTab)
    Equal(book.trainingShown, true, "guide open before the fight" .. how)
    game.EnterCombat()
    Equal(s.LivePages(), 0, "no spell page clickable through the guide as the fight starts" .. how)
    s.Click(book.SkillTabs[1])
    Equal(book.trainingShown, true, "a school tab can't leave the guide in a fight" .. how)
    s.Micro()
    Equal(layer.attrs.unit, "player", "first press in a fight raises the layer" .. how)
    Equal(s.Open(), true, "and the book stays open" .. how)
    Equal(s.Guide():IsVisible(), true, "guide still shown" .. how)
    Equal(s.LivePages(), 0, "no spell, page arrow or tab pad clickable through the guide in a fight" .. how)
    Equal(s.LiveSpells(), 0, "no spell clickable through the guide in a fight" .. how)
    s.Micro()
    Equal(s.Open(), false, "second press closes the book in a fight" .. how)
    Equal(layer.attrs.unit, "none", "layer down" .. how)
    s.Micro()
    Equal(s.Open(), true, "reopens it in a fight, on the guide" .. how)
    Equal(book.trainingShown and s.Guide():IsVisible(), true, "reopened on the guide" .. how)
    Equal(s.LivePages(), 0, "still nothing clickable through the guide" .. how)
    s.Micro()
    Equal(s.Open(), false, "closed again in a fight" .. how)
    game.LeaveCombat()
    Equal(s.Open(), false, "book stays closed after the fight" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "layer down after the fight" .. how)
    s.Micro()
    Equal(s.Open(), true, "opens it after the fight, on the guide" .. how)
    Equal(book.trainingShown, true, "guide kept" .. how)
    Equal(layer.attrs.unit .. " " .. tostring(layer:IsShown()), "none false", "layer down on the guide" .. how)
    s.Micro()
    Equal(s.Open(), false, "and closes it" .. how)

    -- A fight starting with the book closed on the guide.
    game.EnterCombat()
    s.Micro()
    Equal(s.Open(), true, "opens the closed guide in a fight" .. how)
    Equal(s.LivePages(), 0, "nothing clickable through the guide opened in a fight" .. how)
    s.Micro()
    Equal(s.Open(), false, "closes it in a fight" .. how)
    game.LeaveCombat()

    -- The guide left after the fight: the spell pages work again.
    s.Micro()
    s.Click(book.SkillTabs[2])
    Equal(book.trainingShown, false, "guide left after the fight" .. how)
    Equal(s.LivePages() > 0 and s.LiveSpells() > 0, true, "spell pages clickable again" .. how)
    game.EnterCombat()
    Equal(s.LiveSpells() > 0, true, "and in the next fight" .. how)
    game.LeaveCombat()
    s.Micro()
    Equal(s.Open(), false, "closes the spell pages at the end" .. how)

    -- Escape: the game's own list (through the stand-in).
    Equal(s.Escape(), nil, "closed, Escape goes on to the game's menu" .. how)
    s.Micro()
    Equal(s.Escape(), 1, "open, Escape is the book's" .. how)
    Equal(tostring(s.Open()) .. " " .. layer.attrs.unit .. " " .. tostring(layer:IsShown()), "false none false",
        "Escape closes the book and lowers its click layer" .. how)
    Equal(s.Escape(), nil, "then goes on to the game's menu" .. how)
    s.Micro()
    game.EnterCombat()
    Equal(tostring(s.Escape()) .. " " .. tostring(s.Open()), "nil true",
        "in a fight the first Escape goes straight on to the game, the book held open" .. how)
    s.Micro()
    Equal(s.Open(), false, "the micro button still closes it in the fight" .. how)
    Equal(s.Escape(), nil, "closed, Escape goes on to the game's menu" .. how)
    s.Micro()
    Equal(s.Open(), true, "and opens it" .. how)
    Equal(s.Escape(), nil, "held open again: Escape still goes on to the game" .. how)
    game.LeaveCombat()
    Equal(s.Escape(), 1, "after the fight, Escape is the book's again" .. how)
    Equal(tostring(s.Open()) .. " " .. layer.attrs.unit, "false none", "and closes it" .. how)
    s.Micro()
    s.Click(book.TrainTab)
    game.EnterCombat()
    Equal(tostring(s.Escape()) .. " " .. tostring(s.Open()), "1 false", "in a fight, Escape closes the book on the guide" .. how)
    Equal(s.Escape(), nil, "then goes on to the game's menu" .. how)
    game.LeaveCombat()
    s.Micro()
    Equal(tostring(s.Open()) .. " " .. tostring(book.trainingShown), "true true", "open on the guide again" .. how)
    game.EnterCombat()
    s.Micro()
    Equal(tostring(s.Open()) .. " " .. layer.attrs.unit, "true player", "a press in a fight raises the layer, the book open" .. how)
    Equal(tostring(s.Escape()) .. " " .. tostring(s.Open()), "nil true", "held: Escape goes on to the game" .. how)
    s.Micro()
    Equal(tostring(s.Open()) .. " " .. tostring(s.Escape()), "false nil", "closes it, and Escape still goes on to the game" .. how)
    game.LeaveCombat()
    Equal(tostring(s.Open()) .. " " .. tostring(s.Escape()), "false nil", "closed after the fight, nothing for Escape" .. how)
    s.Micro()
    Equal(s.Escape(), 1, "opened after the fight, Escape is the book's" .. how)
    s.Micro()
    s.Click(book.SkillTabs[1])
    Equal(book.trainingShown, false, "back on the spell pages" .. how)
    s.Micro()
    Equal(s.Open(), false, "closed at the end" .. how)

    -- Squirt's call: no key binding; the game's own key opens the game's book.
    s.GameKey()
    Equal(game.gameBook:IsShown() and game.gameBook:GetAlpha() == 1, true, "the spellbook key opens the game's own book, seen" .. how)
    Equal(s.Open(), false, "and not EraUI's" .. how)
    s.GameKey()
    s.Micro()
    Equal(s.Open(), true, "the micro button still opens EraUI's book" .. how)
    if drag then
        -- With dragging the game's (lent, unseen) book is already open: its
        -- key first closes that one, and EraUI's book stays.
        s.GameKey()
        Equal(tostring(s.Open()) .. " " .. tostring(game.gameBook:IsShown()), "true false",
            "with dragging the game's key first shuts the lent book, EraUI's stays")
    end
    s.GameKey()
    Equal(s.Open(), false, "the game's key out of a fight: EraUI's book makes way for the game's" .. how)
    Equal(game.gameBook:IsShown() and game.gameBook:GetAlpha() == 1, true, "and the game's book is the one seen" .. how)
    s.GameKey()
    Equal(#game.errors, 0, "no error reported" .. how)
end

-- A book the game counts as protected: in a fight the micro button closes it
-- by fading it out (it stays shown until the fight ends).
for _, drag in ipairs({ true, false }) do
    local how = drag and " (spell dragging)" or " (no spell dragging)"
    local s = Session(drag)
    local book = s.Book()
    s.Micro()
    book.protected = true
    s.game.EnterCombat()
    Equal(tostring(s.Escape()) .. " " .. tostring(s.Open()), "nil true", "protected and held open: Escape goes on to the game" .. how)
    s.Micro()
    Equal(tostring(book:IsShown()) .. " " .. book:GetAlpha(), "true 0", "the protected book fades out in the fight" .. how)
    Equal(s.Escape(), nil, "faded out: Escape goes on to the game's menu" .. how)
    book.protected = false
    s.game.LeaveCombat()
    Equal(tostring(book:IsShown()) .. " " .. tostring(s.Escape()), "false nil", "closed after the fight, nothing for Escape" .. how)
end

-- The Classic Spellbook entry in the game's Key Bindings (Bindings.xml,
-- CLICK EraUIClassicSpellBookBind:LeftButton), set by the player himself:
-- the game clicks the named key button as the key goes down and again as it
-- comes up, each only when the button takes that click. The down click does
-- nothing and the up click acts, so a press toggles the book once, however
-- long the key is held, in a fight too. Nothing changes a binding (the mock
-- fails on any binding call).
for _, drag in ipairs({ true, false }) do
    local how = drag and " (spell dragging)" or " (no spell dragging)"
    local s = Session(drag)
    local game, env = s.game, s.env
    local key = env.EraUIClassicSpellBookBind
    local takes = {}
    for _, kind in ipairs(key.clicks or {}) do takes[kind] = true end
    Equal(takes.AnyDown == true and takes.AnyUp == true, true, "the key button takes a key's down and up clicks" .. how)
    local function KeyDown()
        if takes.AnyDown or takes.LeftButtonDown then key:Click("LeftButton", true) end
        game.Settle()
    end
    local function KeyUp()
        if takes.AnyUp or takes.LeftButtonUp then key:Click("LeftButton", false) end
        game.Settle()
    end
    local function Press() KeyDown(); KeyUp() end
    KeyDown()
    Equal(s.Open(), false, "the key going down opens nothing yet" .. how)
    KeyUp()
    Equal(s.Open(), true, "its release opens EraUI's book" .. how)
    Equal(game.gameBook:IsShown() and game.gameBook:GetAlpha() == 1, false, "never the game's own book, seen" .. how)
    KeyDown()
    Equal(s.Open(), true, "the next press going down leaves it open" .. how)
    KeyUp()
    Equal(s.Open(), false, "and its release closes it" .. how)
    game.EnterCombat()
    Press()
    Equal(s.Open(), true, "a press opens it in a fight" .. how)
    Equal(s.LiveSpells() > 0, true, "its spells clickable in the fight" .. how)
    Press()
    Equal(s.Open(), false, "the next press closes it in the fight" .. how)
    Press()
    game.LeaveCombat()
    Equal(s.Open(), true, "opened in the fight, it stays open after" .. how)
    Press()
    Equal(s.Open(), false, "and a press closes it after the fight" .. how)
    Equal(#game.errors, 0, "no error reported" .. how)
end

-- Shift-click a spell to link it (Forever's ChatFrameUtil; the old name only
-- when that is all there is).
do
    local s = Session(false)
    local env, S = s.env, s.S
    s.Micro()
    local spell
    for _, f in ipairs(s.game.frames) do
        if S.spellOf[f] and f:IsVisible() then spell = f; break end
    end
    Equal(spell ~= nil, true, "a spell on the open page")
    local slot = S.spellOf[spell].slot
    local link = env.C_SpellBook.GetSpellBookItemLink(slot)
    local function ShiftClick(new, old, label)
        local got = {}
        env.ChatFrameUtil = new and { InsertLink = function(text) got[#got + 1] = "new " .. text; return true end } or nil
        env.ChatEdit_InsertLink = old and function(text) got[#got + 1] = "old " .. text end or nil
        local ok, err = pcall(s.Click, spell)
        Equal(ok, true, label .. ": shift-clicking a spell is not an error (" .. tostring(err) .. ")")
        return table.concat(got, ", ")
    end
    s.game.modified = "CHATLINK"
    Equal(ShiftClick(true, false, "Forever"), "new " .. link, "Forever: the spell's link goes to chat through ChatFrameUtil")
    Equal(ShiftClick(false, true, "old client"), "old " .. link, "old client: through ChatEdit_InsertLink")
    Equal(ShiftClick(true, true, "both"), "new " .. link, "both: ChatFrameUtil only")
    Equal(ShiftClick(false, false, "neither"), "", "neither: no link, no error")
    s.game.modified = nil
    Equal(ShiftClick(true, true, "plain click"), "", "a plain click links nothing")
    Equal(s.game.casts[#s.game.casts], 5000 + slot, "and casts the spell (its own id)")
end

print("Spellbook key checks passed: " .. checks .. " assertions.")
