-- The classic spellbook's pages and parts (Look/Spell*.lua, clean-room
-- 2026-10-21) on Tools/SpellMockGame.lua: what a page lists (search across
-- the school lines, the highest-rank rule, future spells and flyouts left
-- out, the pet's pages, page memory and clamping), the secure containers
-- (exactly one shown for each chooser value, page sets 1 to n for page n,
-- room for five lines or four and the pet, the dynamic container's key, the
-- pads armed only where a line has a container), drawing in a fight (live,
-- or dimmed when the secure side isn't ready), the art and its places, the
-- ring colours, the usable tint and the cooldown, the tab makers other
-- windows borrow, the window manager's traits and the layer following the
-- book, Combat Spell Dragging (off by default now and experimental; only
-- the game's own items lent, handed back on close, on the talents page and
-- when turned off, never a guarded one moved in a fight), the registry
-- entries, the debug line, and the spell tooltip in EraUI's own box.
local Mock = dofile("Tools/SpellMockGame.lua")
local checks = 0
local function Equal(a, b, label)
    checks = checks + 1
    assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function Near(a, b) return type(a) == "number" and math.abs(a - b) < 1e-6 end

local FILES = { "Look/SpellKit.lua", "Look/SpellPage.lua", "Look/SpellLayer.lua", "Look/SpellDraw.lua",
    "Look/SpellOpen.lua", "Look/SpellDrag.lua", "Look/SpellModule.lua" }

-- lines: as Mock.SpellBook; pet: pet spell items or nil.
local function Session(lines, pet, setup)
    local game = Mock.New()
    local env = game.env
    Mock.SpellBook(game, lines, pet)
    Mock.GameSpellbook(game)
    env.UnitLevel = function() return 20 end
    if setup then setup(game) end
    game.Load("Look/Base.lua")
    game.Load("Look/Escape.lua")
    for _, file in ipairs(FILES) do game.Load(file) end
    game.Login()
    local S = game.E.Look.Spells
    local s = { game = game, env = env, S = S }
    function s.Open()
        env.EraUIClassicSpellBookBind:Click("LeftButton", false)
        game.Settle()
    end
    function s.Slots()
        local out = {}
        for i, entry in ipairs(S.slots) do out[i] = entry.slot or "-" end
        return table.concat(out, ",")
    end
    function s.ShownBoxes()
        local out = {}
        for i, box in ipairs(S.boxes) do if box.frame:IsShown() then out[#out + 1] = i end end
        return table.concat(out, ",")
    end
    function s.ShownSets(box)
        local out = {}
        for p, page in ipairs(box.sets) do if page.frame:IsShown() then out[#out + 1] = p end end
        return table.concat(out, ",")
    end
    return s
end

local function Items(list)
    local out = {}
    for i, entry in ipairs(list) do out[i] = entry end
    return out
end

---------------------------------------------------------------------------
-- What a page lists
---------------------------------------------------------------------------
do
    local general = { name = "General", count = 6, items = Items({
        { name = "Attack", subName = "" }, { name = "Fireball", subName = "Rank 1" }, { name = "Fireball", subName = "Rank 3" },
        { name = "Fireball", subName = "Rank 2" }, { name = "Frost Ward", subName = "Rank 1", itemType = 2 },
        { name = "Portals", subName = "", itemType = 4 } }) }
    local fire = { name = "Fire", count = 3, items = Items({ { name = "Scorch", subName = "Rank 1" },
        { name = "Scorch", subName = "Rank 1" }, { name = "Flamestrike", subName = "Rank 2" } }) }
    local s = Session({ general, fire }, { { name = "Claw", subName = "Rank 2" }, { name = "Growl", subName = "Rank 1" } })
    local S = s.S
    local function List(view, top) return table.concat(S.ListFor(view, top), ",") end
    Equal(List({ pet = false, line = 1, search = "" }), "1,2,3,4", "a line's slots, future spells and flyouts left out")
    Equal(List({ pet = false, line = 1, search = "" }, true), "1,3", "highest ranks only: Rank 3 kept, rankless kept")
    Equal(List({ pet = false, line = 2, search = "" }, true), "8,9", "on a tie the later one stays")
    Equal(List({ pet = false, line = 1, search = "fire" }), "2,3,4", "a search runs across every line (in lower case)")
    Equal(List({ pet = false, line = 2, search = "RANK 2" }), "4,9", "and matches the sub name too")
    Equal(List({ pet = false, line = 1, search = "ward" }), "", "never a future spell")
    Equal(List({ pet = true, line = 1, search = "" }), "1,2", "the pet's pages: every pet spell")
    Equal(List({ pet = true, line = 1, search = "gro" }), "2", "a pet search")
    s.game.secret = "hidden"
    s.env.C_SpellBook.GetSpellBookItemInfo(2, 0).name = "hidden"
    Equal(List({ pet = false, line = 1, search = "hid" }), "", "a secret name never matches")
    s.env.C_SpellBook.GetSpellBookItemInfo(2, 0).name = "Fireball"
    s.game.secret = nil
    Equal(S.PageCount({}), 1, "at least one page")
    Equal(S.PageCount({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 }), 2, "twelve a page")
    Equal(S.PetTitle(), "Cat", "the pet tab's title from the pet family")
    Equal(s.game.ns.SpellBookPetTitle(), "Cat", "and through ns.SpellBookPetTitle")
end

-- A crafting spell on a line without a tab (a rogue's Poisons) joins the
-- General page and the search; that line's other spells never do.
do
    local function Book(withHidden)
        local lines = { { name = "General", count = 2 }, { name = "Combat", count = 1 } }
        if withHidden then
            lines[3] = { name = "Hidden", count = 3, hidden = true, items = Items({ { name = "Poisons", subName = "" },
                { name = "Other Thing", subName = "" }, { name = "Poison Lore", subName = "", passive = true } }) }
        end
        return lines
    end
    local function Crafts(game)
        game.env.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function(id) return id == 5004 or id == 5006 end }
    end
    local s = Session(Book(true), nil, Crafts)
    local S = s.S
    local function List(view) return table.concat(S.ListFor(view, true), ",") end
    Equal(#S.Lines(), 2, "the hidden line still gets no tab")
    Equal(List({ pet = false, line = 1, search = "" }), "1,2,4", "a hidden line's crafting spell shows on General")
    Equal(List({ pet = false, line = 2, search = "" }), "3", "and only on General")
    Equal(List({ pet = false, line = 2, search = "poi" }), "4", "the search finds it (never a passive)")
    Equal(List({ pet = false, line = 1, search = "other" }), "", "a hidden line's other spells stay out")
    local plain = Session(Book(false), nil, Crafts)
    Equal(table.concat(plain.S.ListFor({ pet = false, line = 1, search = "" }, true), ","), "1,2",
        "a character without one: General unchanged")
    local noApi = Session(Book(true))
    Equal(table.concat(noApi.S.ListFor({ pet = false, line = 1, search = "" }, true), ","), "1,2",
        "no crafting check in the game: General unchanged")
    -- As Forever has it for a rogue: the line holding Poisons isn't counted
    -- and gives no line info, so its spells are found by slot past the others.
    local lines = Book(true)
    lines[3].hidden, lines[3].uncounted = nil, true
    local past = Session(lines, nil, Crafts)
    local function Past(view) return table.concat(past.S.ListFor(view, true), ",") end
    Equal(#past.S.Lines() .. " " .. Past({ pet = false, line = 1, search = "" }), "2 1,2,4",
        "a crafting spell on an uncounted line: on General, still no tab for its line")
    Equal(Past({ pet = false, line = 2, search = "poi" }) .. " | " .. Past({ pet = false, line = 1, search = "other" }), "4 | ",
        "the search finds it; that line's other spells stay out")
    -- The professions sit past the counted lines too (First Aid here, slot
    -- 7, and its own crafting spell): they have the Professions window, so
    -- only Poisons joins General.
    local withAid = Book(true)
    withAid[3].hidden, withAid[3].uncounted = nil, true
    withAid[4] = { name = "First Aid", count = 1, items = Items({ { name = "First Aid", subName = "Journeyman" } }) }
    -- And the copy Forever keeps elsewhere, under the profession's name (slot 8).
    withAid[5] = { name = "Elsewhere", count = 1, items = Items({ { name = "First Aid", subName = "Journeyman" } }) }
    local aid = Session(withAid, nil, function(game)
        game.env.C_TradeSkillUI = { CanTradeSkillShowCraftingUI = function(id) return id == 5004 or id == 5007 or id == 5008 end }
        game.env.GetProfessions = function() return nil, nil, 9 end
        game.env.GetProfessionInfo = function(index) if index == 9 then return "First Aid", 1, 150, 225, 1, 6, 129 end end
    end)
    Equal(table.concat(aid.S.ListFor({ pet = false, line = 1, search = "" }, true), ","), "1,2,4",
        "a profession's crafting spell stays in the Professions window")
    Equal(table.concat(aid.S.ListFor({ pet = false, line = 1, search = "first" }, true), ","), "",
        "and out of the search")
end

---------------------------------------------------------------------------
-- Containers, page sets and pads
---------------------------------------------------------------------------
do
    local lines = {}
    for i = 1, 7 do lines[i] = { name = "Line" .. i, count = i == 1 and 30 or 4 } end
    local s = Session(lines)
    local S, game = s.S, s.game
    s.Open()
    Equal(#S.Lines(), 7, "setup: seven lines with a tab")
    Equal(S.lineBox[1] == S.boxes[1] and S.lineBox[5] == S.boxes[5] and S.lineBox[6] == nil and S.petBox == nil, true,
        "no pet: five lines get a container of their own")
    Equal(#S.boxes[1].sets, 3, "30 spells: three page sets")
    for value, index in pairs({ p = 1, pl = 2, pla = 3, play = 4, playe = 5, player = 6 }) do
        S.chooser.attrs.unit = value
        game.Watch()
        Equal(s.ShownBoxes(), tostring(index), "chooser " .. value .. ": container " .. index .. " alone")
    end
    S.chooser.attrs.unit = "none"
    game.Watch()
    Equal(s.ShownBoxes(), "", "chooser none: none")
    S.Refresh()
    game.Settle()
    Equal(s.ShownBoxes() .. " " .. s.ShownSets(S.boxes[1]), "1 1", "line 1, page 1: its container, page set 1")
    S.TurnPage(1)
    S.TurnPage(1)
    Equal(s.ShownSets(S.boxes[1]) .. " " .. S.page, "1,2,3 3", "page 3: page sets 1 to 3 up (the later over the earlier)")
    Equal(S.boxes[1].sets[3].frame.level > S.boxes[1].sets[2].frame.level, true, "a later page set draws above")
    S.TurnPage(1)
    Equal(S.page, 3, "no page past the last")
    Equal(s.Slots(), "25,26,27,28,29,30,-,-,-,-,-,-", "the third page's six spells and empty slots")
    local box = S.boxes[1]
    Equal(S.PadArmed(box.sets[1].next) and S.PadArmed(box.sets[2].next) and not S.PadArmed(box.sets[3].next), true,
        "next page pads armed while there is a page after")
    Equal(not S.PadArmed(box.sets[1].prev) and S.PadArmed(box.sets[2].prev), true, "previous page pads from page 2")
    for i = 1, 8 do
        Equal(S.PadArmed(box.tabPads[i]) and box.tabPads[i]:IsShown(), i <= 5, "school tab pad " .. i .. (i <= 5 and " armed" or " hidden"))
    end
    Equal(box.petPad:IsShown() or box.bookPad:IsShown(), false, "no pet: no pet pad, and the book pad only on the pet's")
    -- A line without a container of its own: the dynamic one, keyed by the line.
    S.SchoolTabClick(S.skillTabs[6], 6)
    Equal(s.ShownBoxes() .. " " .. tostring(S.boxes[6].key), "6 line:6", "line 6: the dynamic container keyed line:6")
    Equal(s.Slots(), "47,48,49,50,-,-,-,-,-,-,-,-", "its spells")
    S.SchoolTabClick(S.skillTabs[1], 1)
    Equal(S.page, 3, "line 1 kept its page this session")
    -- A search: the dynamic container keyed by bank and text.
    S.book.Search:SetText("Line2")
    S.book.Search:Fire("OnTextChanged")
    Equal(s.ShownBoxes() .. " " .. tostring(S.boxes[6].key), "6 player:line2", "a search: the dynamic container keyed by it")
    Equal(s.Slots(), "31,32,33,34,-,-,-,-,-,-,-,-", "the search's spells")
    S.book.Search:SetText("")
    S.book.Search:Fire("OnTextChanged")
    -- In a fight the art follows the secure clicks: a school tab pad.
    game.EnterCombat()
    local pad = S.boxes[1].tabPads[2]
    pad:Click("LeftButton", false)
    game.Settle()
    Equal(s.ShownBoxes(), "2", "in a fight a school tab pad chooses line 2's container")
    -- The one refresh the secure side queued (no second one comes in game)
    -- draws the tabs from what the click chose.
    Equal(S.skillTabs[2]:GetChecked() and not S.skillTabs[1]:GetChecked(), true,
        "and its one refresh checks line 2's school tab, not line 1's")
    S.Refresh()
    Equal(S.view.line .. " " .. s.Slots():sub(1, 11), "2 31,32,33,34", "and the art follows it at once")
    Equal(S.slots[1].shade == nil or not S.slots[1].shade:IsShown(), true, "a ready container is live: no shade")
    game.LeaveCombat()
end

-- Room for four lines and the pet; pads to it and back.
do
    local lines = {}
    for i = 1, 6 do lines[i] = { name = "Line" .. i, count = 2 } end
    local s = Session(lines, { { name = "Claw" }, { name = "Bite" } })
    local S = s.S
    s.Open()
    Equal(S.lineBox[4] == S.boxes[4] and S.lineBox[5] == nil and S.petBox == S.boxes[5], true,
        "with pet spells: four lines, then the pet's container")
    Equal(S.PadArmed(S.boxes[1].petPad) and S.boxes[1].petPad:IsShown(), true, "the pet pad on a line's container")
    Equal(S.boxes[5].bookPad:IsShown() and S.PadArmed(S.boxes[5].bookPad), true, "the book pad on the pet's")
    Equal(S.boxes[5].tabPads[1]:IsShown(), false, "no school tab pads on the pet's")
    local petSpell = S.boxes[5].sets[1].buttons[1]
    Equal(tostring(petSpell:GetAttribute("type1")) .. " " .. tostring(petSpell:GetAttribute("spell")), "spell 6001",
        "a pet's spell (a PetAction item, not a flyout) armed with its spell id")
    S.OnBookTab(S.bookTabs[3])
    Equal(S.view.pet and s.ShownBoxes() == "5", true, "the pet tab: the pet's container")
    Equal(S.skillTabs[1]:IsShown() or S.book.Ranks:IsShown(), false, "no school tabs or ranks tick on the pet tab")
    Equal(S.bookTabs[3]:IsShown() and S.bookTabs[3].text == "Cat" and not S.bookTabs[3]:IsEnabled(), true,
        "the pet tab named for the family, selected")
    s.game.petItems[2], s.game.petItems[1] = nil, nil
    S.Refresh()
    Equal(S.view.pet, false, "losing the pet while on its tab goes back to the player's")
end

-- In a fight the pet pad and the Spellbook pad: the one refresh each click
-- queues draws the book tabs, the school tabs and the ranks tick for the
-- pages the click put up.
do
    local lines = {}
    for i = 1, 3 do lines[i] = { name = "Line" .. i, count = 2 } end
    local s = Session(lines, { { name = "Claw" }, { name = "Bite" } })
    local S, game = s.S, s.game
    s.Open()
    game.EnterCombat()
    S.boxes[1].petPad:Click("LeftButton", false)
    game.Settle()
    Equal(s.ShownBoxes() .. " " .. tostring(S.view.pet), "4 true", "in a fight the pet pad puts the pet's pages up")
    Equal(not S.bookTabs[3]:IsEnabled() and S.bookTabs[1]:IsEnabled(), true, "its one refresh: the pet tab selected")
    Equal(S.book.Ranks:IsShown() or S.skillTabs[1]:IsShown(), false, "and no ranks tick or school tabs on the pet's pages")
    S.boxes[4].bookPad:Click("LeftButton", false)
    game.Settle()
    Equal(s.ShownBoxes() .. " " .. tostring(S.view.pet), "1 false", "the Spellbook pad: line 1's pages back")
    Equal(S.bookTabs[3]:IsEnabled() and not S.bookTabs[1]:IsEnabled() and S.skillTabs[1]:GetChecked() == true, true,
        "its one refresh: the Spellbook tab selected and line 1's school tab checked")
    Equal(S.book.Ranks:IsShown(), true, "and the ranks tick back")
    game.LeaveCombat()
end

-- A fight before the secure side is ready: the plain list, dimmed.
do
    local s = Session({ { name = "General", count = 3, items = Items({ {}, { passive = true }, {} }) } })
    local S, game = s.S, s.game
    s.Open()
    game.EnterCombat()
    S.dirty = true -- a spell learned in the fight: the pages can't be rebuilt until it ends
    S.Refresh()
    Equal(S.slots[1].shade ~= nil and S.slots[1].shade:IsShown(), true, "not ready in a fight: a spell is dimmed")
    Equal(S.slots[2].shade == nil or not S.slots[2].shade:IsShown(), true, "never a passive")
    game.LeaveCombat()
    Equal(S.dirty, false, "rebuilt when the fight ends")
    Equal(S.slots[1].shade:IsShown(), false, "and live again")
end

---------------------------------------------------------------------------
-- The art
---------------------------------------------------------------------------
do
    local s = Session({ { name = "General", count = 3, items = Items({ { subName = "" }, { passive = true, subName = "" }, { offSpec = true } }) } })
    local S, env, game = s.S, s.env, s.game
    local book = env.EraUIClassicSpellBook
    Equal(book.width .. "x" .. book.height .. " " .. book.strata, "384x512 MEDIUM", "the book: 384 x 512, MEDIUM")
    local p = book.points[1]
    Equal(p[1] .. " " .. p[4] .. " " .. p[5], "TOPLEFT 0 -104", "at the top left, 104 down")
    local cover = S.cover
    Equal(cover.layer .. " " .. tostring(cover.sublevel) .. " " .. cover.width .. "x" .. cover.height, "BACKGROUND 1 322x356",
        "the cover over the parchment alone")
    Equal(cover.points[1][4] .. "," .. cover.points[1][5] .. " " .. tostring(cover.shown) .. " " .. tostring(cover.colourTexture),
        "22,-75 false nil", "at 22, -75, made hidden with no colour")
    for i, at in ipairs({ { 34, -85 }, { 34, -136 }, [6] = { 34, -340 }, [7] = { 191, -85 }, [12] = { 191, -340 } }) do
        local f = S.slots[i].frame
        Equal(f.points[1][4] .. "," .. f.points[1][5], at[1] .. "," .. at[2], "slot " .. i .. "'s place")
    end
    Equal(S.slots[1].frame.width, 37, "slots 37 across")
    s.Open()
    Equal(S.slots[1].sub.text .. "|" .. S.slots[2].sub.text, "|Passive", "the sub text, Passive for a passive without one")
    Equal(S.slots[1].name.points[1][5] .. " " .. S.slots[3].name.points[1][5], "1 3", "the name 1 up alone, 3 up over a rank")
    Equal(S.slots[3].icon.desaturated, true, "an off-spec spell's icon desaturated")
    Equal(S.slots[2].ring.colour[1] .. S.slots[2].ring.colour[2] .. S.slots[2].ring.colour[3], "000", "a passive's ring black")
    Equal(S.slots[1].ring.colour[1], 1, "the others white (no Dark Windows)")
    Equal(S.slots[4].icon:IsShown() or S.slots[4].name:IsShown(), false, "an empty slot shows nothing")
    Equal(Near(S.slots[2].name.textColour[1], 0.77), true, "a passive's name in the passive gold")
    game.ns.DarkWindowsOn = function() return true end
    game.ns.DarkGrey = function() return 0.3, 0.31, 0.32 end
    S.Refresh()
    Equal(Near(S.slots[1].ring.colour[1], 0.3) and S.slots[2].ring.colour[1] == 0, true, "Dark Windows: Dark Mode's grey, passives still black")
    -- The usable tint (only in a fight) and the cooldown.
    env.C_SpellBook.IsSpellBookItemUsable = function(slot) if slot == 1 then return false, true end return false, false end
    S.Cooldowns()
    Equal(S.slots[1].icon.colour[1], 1, "out of a fight the icon is white")
    game.EnterCombat()
    S.Cooldowns()
    Equal(S.slots[1].icon.colour[1] .. "," .. S.slots[1].icon.colour[3], "0.5,1", "in a fight, no power: blue-grey")
    Equal(S.slots[3].icon.colour[1], 0.4, "can't be cast: grey")
    game.secret = "nope"
    env.C_SpellBook.IsSpellBookItemUsable = function() return "nope", false end
    S.Cooldowns()
    Equal(S.slots[1].icon.colour[1], 1, "a hidden answer: white")
    game.secret = nil
    game.LeaveCombat()
    env.C_SpellBook.GetSpellBookItemCooldown = function() return { startTime = 50, duration = 8, isEnabled = true, modRate = 1 } end
    S.Cooldowns()
    Equal(S.slots[1].cooldown.cooldown and S.slots[1].cooldown.cooldown[2], 8, "the cooldown from start and duration")
    env.C_SpellBook.GetSpellBookItemCooldown = function() return { startTime = 50, duration = 8, isEnabled = false } end
    S.Cooldowns()
    Equal(S.slots[1].cooldown.cooldown, nil, "cleared when off")
    local used
    env.C_SpellBook.GetSpellBookItemCooldownDuration = function() return "duration" end
    S.slots[1].cooldown.SetCooldownFromDurationObject = function(_, object, flag) used = tostring(object) .. tostring(flag) end
    S.Cooldowns()
    Equal(used, "durationtrue", "the secret-safe duration object first")
    -- The page arrows, the page line and the wheel.
    Equal(book.PageText.text, "Page 1", "the page line")
    Equal(book.PrevPage.enabled or book.NextPage.enabled, false, "one page: both arrows off")
    -- Tooltip: the game's own data in EraUI's box (never GameTooltip).
    local shown
    for _, f in ipairs(game.frames) do if S.spellOf[f] and f:IsVisible() then shown = f; break end end
    env.C_TooltipInfo = { GetSpellBookItem = function(slot) return { lines = { { leftText = "Spell " .. slot }, { leftText = "Instant", rightText = "8 yd" } } } end }
    shown:Fire("OnEnter")
    local tip = game.E.Look.TipOwner()
    Equal(tip, shown, "hovering a spell shows EraUI's own tooltip")
    shown:Fire("OnLeave")
    Equal(game.E.Look.TipOwner(), nil, "and leaving hides it")
end

---------------------------------------------------------------------------
-- The tab makers other windows use
---------------------------------------------------------------------------
do
    local s = Session({ { name = "General", count = 1 } })
    local ns, env = s.game.ns, s.env
    local parent = env.CreateFrame("Frame", nil, env.UIParent)
    local first = ns.NewSideTab(parent, 1, nil)
    local second = ns.NewSideTab(parent, 2, first)
    Equal(first.width .. "x" .. first.height .. " " .. tostring(first.shown), "32x32 false", "a side tab: 32 x 32, hidden")
    Equal(first.points[1][1] .. " " .. first.points[1][3] .. " " .. first.points[1][4] .. " " .. first.points[1][5], "TOPLEFT TOPRIGHT -32 -65",
        "the first at the parent's top right (-32, -65)")
    Equal(second.points[1][2] == first and second.points[1][3] == "BOTTOMLEFT" and second.points[1][5] == -17, true, "the next 17 below")
    Equal(first.checkedFace.blend .. " " .. first.highlightFace.blend, "ADD ADD", "glow and checked additive")
    first.tooltip = "Friends"
    first:Fire("OnEnter")
    Equal(s.game.E.Look.TipOwner(), first, "its tooltip field shown in EraUI's box")
    first:Fire("OnLeave")
    local tab1 = ns.NewBookTab(parent, 1, nil)
    local tab3 = ns.NewBookTab(parent, 3, ns.NewBookTab(parent, 2, tab1))
    Equal(tab1.width .. "x" .. tab1.height, "128x64", "a book tab: 128 x 64")
    Equal(tab1.points[1][1] .. " " .. tab1.points[1][3] .. " " .. tab1.points[1][4] .. " " .. tab1.points[1][5], "CENTER BOTTOMLEFT 79 61",
        "the first centred on the parent's bottom left (79, 61)")
    Equal(tab3.points[1][1] .. " " .. tab3.points[1][3] .. " " .. tab3.points[1][4], "LEFT RIGHT -20", "the next 20 over the last one's right edge")
    Equal(tab3.disabledFace.file:find("Tab3%-Selected") ~= nil and tab1.disabledFace.file:find("Tab1%-Selected") ~= nil, true,
        "the selected art by index")
end

---------------------------------------------------------------------------
-- The window manager's traits, and the layer following the book
---------------------------------------------------------------------------
do
    local s = Session({ { name = "General", count = 2 } })
    local S, game, Look = s.S, s.game, s.game.E.Look
    s.Open()
    Equal(Look.WindowTrait(S.book, "width"), 392, "the book's slot is 392 wide")
    Equal(Look.WindowTrait(S.book, "hold")(), nil, "out of a fight it holds no place")
    S.book:ClearAllPoints()
    S.book:SetPoint("TOPLEFT", s.env.UIParent, "TOPLEFT", 352, -104)
    Equal(S.layer.points[1][4], 352, "the layer follows the book out of a fight")
    game.EnterCombat()
    Equal(Look.WindowTrait(S.book, "hold")(), 352, "in a fight with the layer up the book holds its place")
    S.book:ClearAllPoints()
    S.book:SetPoint("TOPLEFT", s.env.UIParent, "TOPLEFT", 0, -104)
    Equal(S.book.points[1][4] .. " " .. S.layer.points[1][4], "352 352", "moved in a fight, the book goes back over its layer")
    -- Held open by its layer in a fight: a close asked by code does nothing
    -- (the layer can't come down), and a hide from elsewhere (the window
    -- manager, an NPC window) brings the art back next frame.
    game.ns.HideSpellBook()
    Equal(S.book:IsShown() and S.book.alpha == 1, true, "in a fight, held by its layer: HideSpellBook leaves it open")
    S.book:Hide()
    Equal(S.book:IsShown(), false, "hidden from elsewhere")
    game.Settle()
    Equal(S.book:IsShown(), true, "the art comes back next frame, over its still open layer")
    game.LeaveCombat()
    Equal(S.LayerUp() and S.layer:IsShown(), true, "after the fight the layer stays up with the open book")
end

---------------------------------------------------------------------------
-- Combat Spell Dragging (off by default; lent only the game's own items)
---------------------------------------------------------------------------
do
    local s = Session({ { name = "General", count = 8 } })
    local S, game = s.S, s.game
    Equal(S.DragOn(), false, "a missing setting means dragging is off")
    Equal(s.env.EraUIClassicSpellBookBind.attrs.type, "click", "and the key button only flips the layer")
end
do
    local s = Session({ { name = "General", count = 8 } }, nil, function(game) game.ns.db.spellDrag = true end)
    local S, game = s.S, s.game
    game.AddonWrote(game.gameItems[2], "slotIndex")
    s.Open()
    game.Tick(0.1)
    local items = game.gameItems
    Equal(items[1].parent, s.env.UIParent, "an item of the game's own lent: on the screen's root")
    Equal(items[1].alpha .. " " .. items[1].strata, "0 FULLSCREEN_DIALOG", "invisible, above everything")
    Equal(items[2].parent ~= s.env.UIParent, true, "an item whose slot an addon wrote: never lent")
    Equal(game.gameBook.alpha, 0, "the game's own book unseen")
    Equal(game.gameBook.points[1][3] .. " " .. game.gameBook.points[1][4], "TOPRIGHT 4000", "and off the screen")
    Equal(game.gameBook.attrs["UIPanelLayout-width"], 1, "taking no room in the panel layout")
    -- The game's book on its talents page: everything back, seen.
    game.Native(function() game.gameBook.SpellBookFrame.shown = false; game.gameBook.TalentsFrame.shown = true end)
    game.Tick(0.1)
    Equal(items[1].parent ~= s.env.UIParent and game.gameBook.alpha == 1, true, "the talents page: items back, window seen")
    Equal(game.gameBook.points[1][3] .. " " .. game.gameBook.points[1][4], "TOPLEFT 16", "back where the game had it")
    game.Native(function() game.gameBook.SpellBookFrame.shown = true; game.gameBook.TalentsFrame.shown = false end)
    game.Tick(0.1)
    Equal(items[1].parent, s.env.UIParent, "the spellbook page again: lent again")
    -- Closing EraUI's book hands them back and closes the game's.
    s.Open()
    game.Tick(0.1)
    Equal(items[1].parent ~= s.env.UIParent and items[1].alpha == 1, true, "closed: handed back as it was")
    Equal(game.gameBook:IsShown(), false, "the game's book closed with it")
    -- A guarded item is never moved in a fight.
    s.Open()
    game.Tick(0.1)
    rawset(items[3], "protected", true)
    game.EnterCombat()
    S.SetPage(1)
    game.ns.modules.spellBook.restore()
    Equal(items[3].parent, s.env.UIParent, "in a fight a guarded item stays where it is")
    game.LeaveCombat()
    game.ns.modules.spellBook.restore()
    Equal(items[3].parent ~= s.env.UIParent and items[1].parent ~= s.env.UIParent, true, "turned off: every item back")
    Equal(game.gameBook.alpha, 1, "and the game's book seen again")
end

---------------------------------------------------------------------------
-- The registry entries, the micro pad and the debug line
---------------------------------------------------------------------------
do
    local s = Session({ { name = "General", count = 4, items = Items({ { subName = "Rank 1" }, { subName = "Rank 2", name = "General 1" } }) } })
    local S, game, ns = s.S, s.game, s.game.ns
    local order = {}
    for _, module in ipairs(ns.modules) do order[#order + 1] = module.key end
    Equal(table.concat(order, ","), "spellBook,spellBookTopRank,spellBookSearch", "the registry entries in order")
    Equal(type(ns.modules.spellBook.init), "function", "spellBook has a one-time init")
    s.Open()
    local built = 0
    local build = S.BuildPages
    S.BuildPages = function(...) built = built + 1; return build(...) end
    game.Pass()
    Equal(built, 0, "a pass with the rule unchanged lists nothing again")
    ns.db.spellBookTopRank = true
    game.Pass()
    Equal(built, 1, "the highest-rank rule changed: listed again at once")
    Equal(s.Slots():sub(1, 5), "2,3,4", "only the highest rank shown")
    S.BuildPages = build
    ns.db.spellBookSearch = false
    S.book.Search:SetText("x")
    game.Pass()
    Equal(tostring(S.book.Search:IsShown()) .. "|" .. S.book.Search.text, "false|", "search off: emptied and hidden")
    ns.db.spellBookSearch = true
    game.Pass()
    Equal(S.book.Search:IsShown(), true, "on: shown again")
    s.env.KeybindFrames_InQuickKeybindMode = function() return true end
    Equal(game.pad.when(), false, "the micro pad steps aside in quick keybind mode")
    s.env.KeybindFrames_InQuickKeybindMode = nil
    Equal(ns.SpellBookBindInfo(), "keys <TOGGLESPELLBOOK=P> (the game's own spellbook); book built true; book protected false",
        "the debug line")
    Equal(ns.ToggleSpellBook(), true, "ToggleSpellBook while on")
    ns.db.spellBook = false
    game.Pass()
    Equal(S.book:IsShown() or ns.ToggleSpellBook() or ns.ShowSpellBookBank(false) or ns.SpellBookActive(), false,
        "off: hidden, and the toggles say false")
    Equal(game.pad.when(), false, "and the micro pad hides")
end

print("Spellbook checks passed: " .. checks .. " assertions.")
