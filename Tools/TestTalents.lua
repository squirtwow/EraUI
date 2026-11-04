-- The talent window (Look/Talent*.lua, registry "talents", clean-room
-- 2026-10-21) on Tools/TalentMockGame.lua: EraUI's own window
-- EraUIClassicTalents over Forever's trait tree.
-- Checked: built only when first opened; the frame, its art and Dark Mode's
-- keys; the strip, points box, foot and tabs; reading the tree (tabs in
-- their order, points, staged, what is left out, secrets); the grid (rows
-- from the whole tree's top, columns from each tree's left, child heights
-- 332/392/455); socket colours, rank plates, the question mark; every kind
-- of link and its art; the tooltip lines (rank, gates, prerequisites, next
-- rank, "Click to learn", data lines, the fallback) in EraUI's own tooltip;
-- staging, refunds, Apply (the game's commit, "too fast", the fallback) and
-- the undo button; the seven refresh events; scrolling; the micro buttons
-- (quick keybind mode, a fight), the named click target, the inspect
-- button and inspecting; Escape, the game menu, the window manager;
-- turning it off and on; no key written on the game's frames, no key
-- binding, no GameTooltip.
-- Run: fengari Tools/TestTalents.lua
local Mock = dofile("Tools/TalentMockGame.lua")
local SECRET, Plain = Mock.SECRET, Mock.Plain
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function True(value, label) Equal(value and true or false, true, label) end
local function False(value, label) Equal(value and true or false, false, label) end

---------------------------------------------------------------------------
-- A warrior's tree as Forever gives it: three groups out of order, talents
-- 600 tree units apart, some hidden, out of every tab or with a secret spot.
---------------------------------------------------------------------------

local TOP = 2000 -- the tree's top row, in tree units
local function WarriorTree()
    local nodes = {}
    local function Add(id, group, left, column, tier, fields)
        local node = { id = id, group = group, x = left + 600 * column, y = TOP + 600 * tier, ranks = 0, max = 1, staged = 0 }
        for key, value in pairs(fields or {}) do node[key] = value end
        nodes[id] = node
    end
    -- Arms (group 11): five rows.
    Add(101, 11, 1000, 0, 0, { ranks = 5, max = 5, spell = 1001,
        edges = { { targetNode = 104, type = 2 }, { targetNode = 102, type = 0 } } })
    Add(102, 11, 1000, 1, 0, { ranks = 1, max = 3, spell = 1002,
        edges = { { targetNode = 103, type = 1 }, { targetNode = 105, type = 2 } } })
    Add(103, 11, 1000, 2, 0, { spell = 1003, edges = { { targetNode = 107, type = 2 } } })
    Add(104, 11, 1000, 0, 1, { buyable = false, spell = 1004, edges = { { targetNode = 999, type = 1 } } })
    Add(105, 11, 1000, 2, 1, { ranks = 2, max = 3, buyable = false, spell = 1005 })
    Add(106, 11, 1000, 3, 1, { buyable = false, edges = { { targetNode = 104, type = 1 } } })
    Add(107, 11, 1000, 0, 2, { spell = 1007, icon = "Interface\\Icons\\Custom", gates = { 501, 502, 503 } })
    Add(108, 11, 1000, 1, 2, { hidden = true, spell = 1008 })
    Add(109, 11, 1000, 2, 2, { spell = 1009, override = { posX = SECRET } })
    Add(110, 99, 1000, 3, 2, { spell = 1010 })
    Add(111, 11, 1000, 1, 4, { spell = 1011 })
    -- Fury (group 12): nothing in the tree's top row; its own left edge.
    Add(201, 12, 5000, 0, 1, { spell = 2001 })
    Add(202, 12, 5000, 3, 5, { spell = 2002 })
    -- Protection (group 13): seven rows.
    Add(301, 13, 9000, 1, 0, { spell = 3001, ranks = 1 })
    Add(302, 13, 9000, 2, 6, { spell = 3002 })
    return { config = 7, tree = 900, unspent = 5, staged = 0, nodes = nodes,
        groups = { { groupID = 12, displayName = "Fury", orderIndex = 2 }, { groupID = 11, displayName = "Arms", orderIndex = 1 },
            { groupID = 13, displayName = "Protection", orderIndex = 3 } } }
end

local function MageTree()
    local nodes = {
        [701] = { id = 701, group = 71, x = 0, y = 0, ranks = 2, max = 2, staged = 0, spell = 7001 },
        [702] = { id = 702, group = 71, x = 600, y = 0, ranks = 0, max = 3, staged = 0, spell = 7002 },
    }
    return { config = -1, tree = 950, unspent = 3, staged = 0, nodes = nodes,
        groups = { { groupID = 71, displayName = "Arcane", orderIndex = 1 }, { groupID = 72, displayName = "Fire", orderIndex = 2 } } }
end

local NAMES = { [1001] = "Deflection", [1002] = "Improved Rend", [1003] = "Improved Charge", [1004] = "Tactical Mastery",
    [1005] = "Anger Management", [1007] = "Deep Wounds", [1011] = "Mortal Strike", [2001] = "Cruelty", [2002] = "Bloodthirst",
    -- 7001: a two-rank Arcane talent in the top row (Arcane Focus left the
    -- tree in build 1.60.1.70707).
    [3001] = "Shield Specialization", [3002] = "Shield Slam", [7001] = "Wand Specialization", [7002] = "Arcane Mind" }

local function Session(options)
    options = options or {}
    options.db = options.db or {}
    local game = Mock.New(options)
    game.trees.player = WarriorTree()
    for id, name in pairs(NAMES) do game.spellNames[id] = name end
    game.conditions[501] = { isGate = true, isMet = false, spentAmountRequired = 10 }
    game.conditions[502] = { isGate = true, isMet = true, spentAmountRequired = 5 }
    game.conditions[503] = { isGate = false, isMet = false, spentAmountRequired = 15 }
    game.entryText[1020] = function(rank)
        return { { leftText = "Rend lasts " .. (rank * 3) .. " sec longer." } }
    end
    game.entryText[1070] = function()
        return { { leftText = "Deep Wounds", leftColor = { r = 1, g = 1, b = 1 } },
            { leftText = "Melee", rightText = "Instant", rightColor = { r = 0.5, g = 0.6, b = 0.7 } },
            { leftText = SECRET }, { leftText = "" }, { leftText = "One line only", wrapText = false },
            { leftText = "Your critical strikes cause the target to bleed." } }
    end
    local T = game.Load()
    local s = { game = game, T = T, env = game.env, st = game.State, Look = game.Look }
    -- Every tooltip EraUI shows, as the rows it was given.
    local show = s.Look.ShowTip
    s.Look.ShowTip = function(owner, side, rows)
        s.tipOwner, s.tipSide, s.tip = owner, side, rows
        return show(owner, side, rows)
    end
    -- Each pass of the window reads the tree's config once.
    s.reads = 0
    local info = game.env.C_Traits.GetConfigInfo
    game.env.C_Traits.GetConfigInfo = function(...)
        s.reads = s.reads + 1
        return info(...)
    end
    function s.Window() return game.env.EraUIClassicTalents end
    function s.Open()
        game.env.TalentMicroButton:Click("LeftButton")
        return s.Window()
    end
    -- The talent button standing at (x, y) in the scroll child, shown.
    function s.ButtonAt(x, y)
        for _, child in ipairs({ T.parts.child:GetChildren() }) do
            local _, _, _, px, py = child:GetPoint(1)
            if child:IsShown() and child:GetObjectType() == "Button" and px == x and py == y then return child end
        end
    end
    function s.Face(button, file)
        for _, region in ipairs({ button:GetRegions() }) do
            local state = game.State(region)
            if state.file == file or state.kind == file then return region end
        end
    end
    function s.Pieces(owner, file)
        local found = {}
        for _, region in ipairs({ owner:GetRegions() }) do
            if region:IsShown() and game.State(region).file == file then found[#found + 1] = region end
        end
        return found
    end
    function s.TipText()
        local out = {}
        for _, row in ipairs(s.tip or {}) do
            out[#out + 1] = row[1] .. (row.right and (" | " .. row.right[1]) or "")
        end
        return table.concat(out, " / ")
    end
    function s.Clean(label)
        Equal(#game.errors, 0, label .. ": nothing handed to the error handler (" .. tostring(game.errors[1]) .. ")")
        Equal(game.scriptSets, s.expectSets or game.scriptSets, label .. ": scripts set on the game's frames")
    end
    return s
end

---------------------------------------------------------------------------
-- Loading and the first pass
---------------------------------------------------------------------------
do
    local s = Session({ inspectButton = true })
    local game, env, T = s.game, s.env, s.T
    Equal(#game.ns.modules, 1, "one registry entry")
    Equal(game.ns.modules[1].key, "talents", "registered as talents")
    True(type(game.ns.modules[1].apply) == "function" and type(game.ns.modules[1].restore) == "function", "with apply and restore")
    Equal(game.ns.db.talents, true, "talents on by default")
    Equal(rawget(env, "EraUIClassicTalents"), nil, "the window isn't made at load")
    Equal(rawget(env, "EraUIClassicTalentsBind"), nil, "nor the click target")
    False(T.active, "inactive before the first pass")
    Equal(game.ns.ToggleTalents(), false, "ToggleTalents does nothing while inactive")
    Equal(rawget(env, "EraUIClassicTalents"), nil, "and builds nothing")

    game.Pass()
    True(T.active, "active after the pass")
    Equal(rawget(env, "EraUIClassicTalents"), nil, "the window still isn't made")
    True(env.EraUIClassicTalentsBind ~= nil, "the named click target is made at the first apply")
    for _, name in ipairs({ "TalentMicroButton", "PlayerSpellsMicroButton" }) do
        True(env[name]:GetScript("OnClick") ~= game.GameClick, name .. ": EraUI's click while on")
    end
    True(game.inspectButton:GetScript("OnClick") ~= game.GameClick, "the inspect window's talents button too")
    local sets = game.scriptSets
    Equal(sets, 3, "three scripts set on the game's buttons")
    game.Pass()
    game.Pass()
    Equal(game.scriptSets, sets, "a pass sets nothing again while EraUI's click is still there")
    s.expectSets = sets
    s.Clean("first pass")
end

---------------------------------------------------------------------------
-- The window: frame, art, words, tabs, foot
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, T, st = s.game, s.env, s.T, s.game.State
    game.settings.darkMode = true
    game.Pass()
    local window = s.Open()
    True(window ~= nil and window:IsShown(), "the micro button opens the window")
    Equal(game.gameClicks, 0, "the game's own window never opens")
    Equal(window:GetName(), "EraUIClassicTalents", "named EraUIClassicTalents")
    Equal(window:GetParent(), env.UIParent, "a child of UIParent")
    Equal(window:GetWidth() .. "x" .. window:GetHeight(), "384x512", "384 x 512")
    Equal(window:GetFrameStrata(), "MEDIUM", "strata MEDIUM")
    True(window:IsToplevel(), "comes to the front when clicked")
    True(window:IsMouseEnabled(), "takes the mouse")
    False(st(window).movable, "not movable")
    local point, relative, relativePoint, x, y = window:GetPoint(1)
    Equal(table.concat({ point, relative:GetName(), relativePoint, x, y }, " "), "TOPLEFT UIParent TOPLEFT 0 -104", "first anchor")
    Equal(#game.registered, 1, "registered with the window manager once")
    Equal(game.registered[1].frame, window, "the window")
    Equal(game.registered[1].shares, true, "as a window that shares")
    local listed = 0
    for _, name in ipairs(env.UISpecialFrames) do if name == "EraUIClassicTalents" then listed = listed + 1 end end
    Equal(listed, 1, "on the game's Escape list by its name")
    Equal(game.sounds[#game.sounds], "IG_CHARACTER_INFO_OPEN", "the open sound")
    Equal(st(T.parts.portrait).portrait, "player", "your portrait")
    Equal(T.parts.portrait:GetWidth() .. "x" .. T.parts.portrait:GetHeight(), "60x60", "60 x 60 portrait")
    Equal(T.parts.portrait:GetDrawLayer(), "BACKGROUND", "on the BACKGROUND layer")
    Equal(select(4, T.parts.portrait:GetPoint(1)) .. "," .. select(5, T.parts.portrait:GetPoint(1)), "7,-6", "at (7, -6)")
    Equal(T.parts.title:GetText(), "Talents", "titled Talents")
    Equal(st(T.parts.title).font, "GameFontNormal", "in GameFontNormal")
    Equal(table.concat({ select(3, T.parts.title:GetPoint(1)), select(4, T.parts.title:GetPoint(1)), select(5, T.parts.title:GetPoint(1)) }, " "),
        "CENTER 6 232", "centred 24 below the top")

    -- The shell and Dark Mode's keys.
    local files, themes = {}, {}
    for _, region in ipairs({ window:GetRegions() }) do
        local state = st(region)
        if state.layer == "BORDER" then
            files[#files + 1] = state.file .. "@" .. state.points[state.order[1]][1] .. "=" .. state.width .. "x" .. state.height
            themes[#themes + 1] = state.theme
        end
    end
    Equal(table.concat(files, " "), "Interface\\PaperDollInfoFrame\\UI-Character-General-TopLeft@TOPLEFT=256x256 "
        .. "Interface\\PaperDollInfoFrame\\UI-Character-General-TopRight@TOPRIGHT=128x256 "
        .. "Interface\\TalentFrame\\UI-TalentFrame-BotLeft@BOTTOMLEFT=256x256 "
        .. "Interface\\TalentFrame\\UI-TalentFrame-BotRight@BOTTOMRIGHT=128x256", "the four frame pieces")
    Equal(table.concat(themes, " "), "charGeneralTopLeft charGeneralTopRight frameSheet frameSheet", "through Dark Mode under their keys")

    -- The red X.
    local close = T.parts.close
    Equal(close:GetWidth() .. "x" .. close:GetHeight(), "32x32", "the X is 32 x 32")
    Equal(table.concat({ close:GetPoint(1) }, " ", 1, 1) .. " " .. select(3, close:GetPoint(1)) .. " " .. select(4, close:GetPoint(1))
        .. " " .. select(5, close:GetPoint(1)), "CENTER TOPRIGHT -46 -24", "its centre at the top-right (-46, -24)")
    Equal(st(close:GetNormalTexture()).file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "the 1.x X art")

    -- The strip.
    local strip = T.parts.strip
    Equal(strip:GetWidth() .. "x" .. strip:GetHeight(), "258x13", "the strip is 258 x 13")
    Equal(table.concat({ select(1, strip:GetPoint(1)), select(3, strip:GetPoint(1)), select(4, strip:GetPoint(1)), select(5, strip:GetPoint(1)) }, " "),
        "TOP TOP 12 -48", "its top centre at (12, -48) from the window's top")
    Equal(T.parts.spent:GetText(), "Points spent in Arms Talents: |cffffffff8|r", "points spent in the first tab, the number white")
    local rims, shade = {}, nil
    for _, region in ipairs({ strip:GetRegions() }) do
        local state = st(region)
        if state.theme == "skillsBarBorder" then rims[#rims + 1] = state end
        if state.solid then shade = state end
    end
    Equal(#rims, 3, "three rim pieces through Dark Mode as skillsBarBorder")
    Equal(table.concat(shade.solid, ","), "0,0,0,0.6", "a black fill at 0.6")

    -- The foot.
    local foot = T.parts.foot
    Equal(foot:GetWidth() .. "x" .. foot:GetHeight(), "338x26", "the foot is 338 x 26")
    local stone = foot:GetRegions()
    Equal(st(stone).theme, "rockBg", "its stone through Dark Mode as rockBg")
    True(st(stone).htile and st(stone).vtile, "tiled")
    local undo, box, apply = T.parts.undo, T.parts.box, T.parts.apply
    Equal(undo:GetWidth() .. "x" .. undo:GetHeight(), "28x22", "the undo button is 28 x 22")
    Equal(select(4, undo:GetPoint(1)) .. "," .. select(5, undo:GetPoint(1)), "16,-411", "at (16, -411)")
    Equal(st(T.parts.undoMark).file, "Interface/Buttons/UI-RotationLeft-Button-Up", "the rotate arrow without the atlas")
    Equal(T.parts.undoMark:GetWidth() .. "x" .. T.parts.undoMark:GetHeight(), "13x13", "13 x 13")
    Equal(box:GetWidth() .. "x" .. box:GetHeight(), "196x24", "the points box is 196 x 24")
    Equal(st(box).backdrop.edgeFile, "Interface\\DialogFrame\\UI-DialogBox-Border", "in the old dialog border")
    Equal(st(box).backdrop.edgeSize, 16, "a 16 edge")
    Equal(st(box).backdrop.bgFile, nil, "no floor")
    Equal(select(2, box:GetPoint(1)), undo, "beside the undo button")
    Equal(T.parts.points:GetText(), "Talent Points: |cffffffff5|r", "the unspent points, white")
    Equal(apply:GetText(), "Apply Changes", "Apply Changes")
    Equal(apply:GetWidth() .. "x" .. apply:GetHeight(), "104x22", "104 x 22")
    Equal(select(2, apply:GetPoint(1)), box, "beside the box")
    False(apply:IsEnabled(), "Apply off with nothing staged")
    False(undo:IsEnabled(), "undo off with nothing staged")
    True(T.parts.undoMark:IsDesaturated(), "the undo arrow grey")
    Equal(T.parts.undoMark:GetAlpha(), 0.5, "at half alpha")
    local handed = {}
    for _, entry in ipairs(game.darkened) do handed[entry[2]] = (handed[entry[2]] or "") .. entry[1] .. tostring(entry[3]) end
    Equal(handed[undo], "DarkRedButtonnil", "the undo button handed to Dark Windows")
    Equal(handed[apply], "DarkRedButtonnil", "and Apply")
    Equal(handed[close], "DarkCloseButtonnil", "the X too")
    Equal(handed[box], "DarkBackdropfalse", "the box as a border with no fill")

    -- The undo button's tooltip, even while it is off.
    game.Enter(undo)
    Equal(s.TipText(), "Reset Pending Changes", "the undo tooltip")
    Equal(s.tipOwner, undo, "beside the button")
    game.Leave(undo)
    Equal(s.Look.TipOwner(), nil, "gone on leave")

    -- The tabs.
    local tabs = T.parts.tabs
    Equal(#tabs, 3, "three tabs")
    Equal(table.concat({ tabs[1]:GetText() and "" or "", s.Face(tabs[1], "FontString"):GetText(), s.Face(tabs[2], "FontString"):GetText(),
        s.Face(tabs[3], "FontString"):GetText() }, " "), " Arms Fury Protection", "named for the trees in their order")
    Equal(tabs[1]:GetWidth(), 4 * 6 + 40, "a tab's width: its words plus 40")
    Equal(tabs[3]:GetWidth(), 10 * 6 + 40, "the third one's too")
    Equal(table.concat({ select(1, tabs[1]:GetPoint(1)), select(3, tabs[1]:GetPoint(1)), select(4, tabs[1]:GetPoint(1)), select(5, tabs[1]:GetPoint(1)) }, " "),
        "TOPLEFT BOTTOMLEFT 15 78", "the first tab under the foot")
    Equal(select(2, tabs[2]:GetPoint(1)), tabs[1], "each next one beside the last")
    Equal(select(4, tabs[2]:GetPoint(1)), -15, "overlapping it by 15")
    local function TabLook(tab)
        local shown, label = {}, s.Face(tab, "FontString")
        for _, region in ipairs({ tab:GetRegions() }) do
            local state = st(region)
            if state.kind == "Texture" and state.layer == "BACKGROUND" and region:IsShown() then
                shown[#shown + 1] = state.theme .. "/" .. state.height .. "/" .. select(5, region:GetPoint(1))
            end
        end
        local r, g, b = label:GetTextColor()
        return table.concat(shown, " ") .. " " .. r .. "," .. g .. "," .. b .. " " .. select(5, label:GetPoint(1))
    end
    -- (The middle piece hangs from the caps, so it sits at their height.)
    Equal(TabLook(tabs[1]), "tabActive/35/0 tabActive/35/0 tabActive/35/0 1,1,1 -5", "the selected tab raised, white words 5 down")
    Equal(TabLook(tabs[2]), "tabInactive/32/-4 tabInactive/32/0 tabInactive/32/-4 1,0.82,0 -3", "the others lowered, gold words 3 down")
    local caps = {}
    for _, region in ipairs({ tabs[2]:GetRegions() }) do
        local state = st(region)
        if state.layer == "BACKGROUND" and region:IsShown() then caps[#caps + 1] = table.concat(state.coords, ",") end
    end
    Equal(table.concat(caps, " "), "0,0.15625,0,1 0.15625,0.84375,0,1 0.84375,1,0,1", "the lowered pieces' regions")
    caps = {}
    for _, region in ipairs({ tabs[1]:GetRegions() }) do
        local state = st(region)
        if state.layer == "BACKGROUND" and region:IsShown() then caps[#caps + 1] = table.concat(state.coords, ",") end
    end
    Equal(table.concat(caps, " "), "0,0.15625,0,0.546875 0.15625,0.84375,0,0.546875 0.84375,1,0,0.546875", "the raised ones'")
    local glow = tabs[1]:GetHighlightTexture()
    Equal(st(glow).file, "Interface\\PaperDollInfoFrame\\UI-Character-Tab-RealHighlight", "the tab glow")
    Equal(st(glow).blend, "ADD", "additive")
    Equal(select(4, glow:GetPoint("TOPLEFT")) .. "," .. select(5, glow:GetPoint("TOPLEFT")), "3,5", "from (3, 5)")
    s.Clean("the window")
end

---------------------------------------------------------------------------
-- Reading the tree: the grid, states and the background
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, T, st = s.game, s.env, s.T, s.game.State
    game.Pass()
    s.Open()
    local picture = T.model
    Equal(#picture.tabs, 3, "three tabs")
    Equal(picture.tabs[1].name .. " " .. picture.tabs[2].name .. " " .. picture.tabs[3].name, "Arms Fury Protection", "sorted by orderIndex")
    Equal(picture.tabs[1].spent .. " " .. picture.tabs[2].spent .. " " .. picture.tabs[3].spent, "8 0 1", "each tab's points spent")
    Equal(picture.unspent, 5, "the unspent points")
    Equal(picture.staged, false, "nothing staged")
    Equal(picture.byNode[108], nil, "a hidden talent is left out")
    Equal(picture.byNode[109], nil, "and one whose place is secret")
    Equal(picture.byNode[110], nil, "and one in no tab")
    Equal(#picture.tabs[1].nodes, 8, "eight Arms talents")
    Equal(picture.tabs[1].tiers .. " " .. picture.tabs[2].tiers .. " " .. picture.tabs[3].tiers, "5 6 7", "rows per tab")
    Equal(picture.byNode[201].tier .. "," .. picture.byNode[201].column, "1,0", "rows count from the whole tree's top, columns from the tab's left")
    Equal(T.ChildHeight(5) .. " " .. T.ChildHeight(6) .. " " .. T.ChildHeight(7), "332 392 455", "child heights for 5, 6 and 7 rows")
    Equal(T.parts.child:GetHeight(), 332, "five rows fit the view")

    local where = { [101] = { 35, -20 }, [102] = { 98, -20 }, [103] = { 161, -20 }, [104] = { 35, -83 }, [105] = { 161, -83 },
        [106] = { 224, -83 }, [107] = { 35, -146 }, [111] = { 98, -272 } }
    for id, spot in pairs(where) do
        True(s.ButtonAt(spot[1], spot[2]) ~= nil, "talent " .. id .. " at (" .. spot[1] .. ", " .. spot[2] .. ")")
    end
    local shown = 0
    for _, child in ipairs({ T.parts.child:GetChildren() }) do
        if child:IsShown() and child:GetObjectType() == "Button" then shown = shown + 1 end
    end
    Equal(shown, 8, "only the selected tab's talents shown")

    local function Look(id)
        local button = s.ButtonAt(where[id][1], where[id][2])
        local socket = s.Face(button, "Interface\\Buttons\\UI-EmptySlot-White")
        local plate = s.Face(button, "Interface\\TalentFrame\\TalentFrame-RankBorder")
        local icon, rank
        for _, region in ipairs({ button:GetRegions() }) do
            local state = st(region)
            if state.layer == "BORDER" then icon = region end
            if state.kind == "FontString" then rank = region end
        end
        local r, g, b = socket:GetVertexColor()
        return table.concat({ r, g, b }, ",") .. " " .. tostring(icon:IsDesaturated()) .. " " .. tostring(plate:IsShown())
            .. " " .. (rank:IsShown() and rank:GetText() or "-") .. " " .. tostring(st(icon).file)
    end
    Equal(Look(101), "1,0.82,0 false true 5 501001", "fully ranked: gold, in colour, plate shown")
    Equal(Look(102), "0.1,1,0.1 false true 1 501002", "ranked and can buy more: green")
    Equal(Look(103), "0.1,1,0.1 false true 0 501003", "can be bought: green with its plate")
    Equal(Look(104), "0.5,0.5,0.5 true false - 501004", "not yet available: grey and desaturated, no plate")
    Equal(Look(105), "1,0.82,0 false true 2 501005", "ranked but can't buy more: gold")
    Equal(Look(106), "0.5,0.5,0.5 true false - Interface\\Icons\\INV_Misc_QuestionMark", "no spell: the question mark")
    Equal(Look(107), "0.1,1,0.1 false true 0 Interface\\Icons\\Custom", "the definition's own icon first")

    local button = s.ButtonAt(35, -20)
    Equal(button:GetWidth() .. "x" .. button:GetHeight(), "37x37", "a talent button is 37 x 37")
    Equal(table.concat(st(button).clicks, ","), "LeftButtonUp,RightButtonUp", "takes left and right up clicks")
    local socket = s.Face(button, "Interface\\Buttons\\UI-EmptySlot-White")
    Equal(socket:GetWidth() .. " " .. socket:GetDrawLayer() .. " " .. select(5, socket:GetPoint(1)), "64 BACKGROUND -1", "the socket: 64, BACKGROUND, 1 below centre")
    local plate = s.Face(button, "Interface\\TalentFrame\\TalentFrame-RankBorder")
    Equal(table.concat({ plate:GetWidth(), plate:GetDrawLayer(), select(3, plate:GetPoint(1)), select(4, plate:GetPoint(1)), select(5, plate:GetPoint(1)) }, " "),
        "32 OVERLAY BOTTOMRIGHT -2 2", "the rank plate at the lower right")
    local glow = s.Face(button, "Interface\\Buttons\\ButtonHilight-Square")
    Equal(glow:GetDrawLayer() .. " " .. st(glow).blend, "HIGHLIGHT ADD", "the highlight, additive")

    -- The class background for each tab.
    local function Back()
        local back = T.parts.back
        return st(back.TopLeft).file and (back.TopLeft:IsShown() and st(back.TopLeft).file or "hidden") or "none"
    end
    Equal(Back(), "Interface\\TalentFrame\\WarriorArms-TopLeft", "the Arms background")
    local back = T.parts.back
    Near(back.TopLeft:GetHeight(), 332 * 256 / 331, "the top pieces stretch with the child")
    Near(back.BottomLeft:GetHeight(), 332 * 75 / 331, "and the bottom ones")
    Equal(back.TopLeft:GetWidth() .. " " .. back.TopRight:GetWidth(), "256 64", "256 and 64 wide")
    Equal(select(4, back.BottomLeft:GetTexCoord()), 75 / 128, "the bottom pieces use the top 75/128")
    Equal(select(2, back.TopRight:GetPoint(1)), back.TopLeft, "the pieces hang from the top-left one")
    T.parts.tabs[2]:Click()
    Equal(Back(), "Interface\\TalentFrame\\WarriorFury-TopLeft", "Fury's on the second tab")
    Equal(T.parts.child:GetHeight(), 392, "six rows: 392")
    Near(back.TopLeft:GetHeight(), 392 * 256 / 331, "stretched to it")
    True(s.ButtonAt(35, -83) ~= nil, "Fury's first talent in the second row")
    T.parts.tabs[3]:Click()
    Equal(Back(), "Interface\\TalentFrame\\WarriorProtection-TopLeft", "Protection's on the third")
    Equal(T.parts.child:GetHeight(), 455, "seven rows: 455")
    game.units.player = { "Squirt", "Monk", "MONK" }
    T.Refresh()
    Equal(Back(), "hidden", "no background for a class without one")
    game.units.player = { "Squirt", "Warrior", SECRET }
    T.Refresh()
    Equal(Back(), "hidden", "nor for a hidden class")
    s.Clean("reading")
end

---------------------------------------------------------------------------
-- Links
---------------------------------------------------------------------------
do
    local s = Session()
    local game, T, st = s.game, s.T, s.game.State
    game.Pass()
    s.Open()
    local picture = T.model
    local links = T.Links(picture, picture.tabs[1])
    local seen = {}
    for _, link in ipairs(links) do seen[#seen + 1] = link.from.id .. ">" .. link.to.id .. (link.lit and "*" or "") end
    Equal(table.concat(seen, " "), "101>104* 102>103 102>105 103>107 106>104",
        "decor-only links, links out of the tree and nowhere are skipped; lit when the source is maxed")
    local function Pieces(from, to)
        local out = {}
        for _, piece in ipairs(T.LinkPieces(picture.byNode[from], picture.byNode[to])) do
            out[#out + 1] = table.concat({ piece.kind, piece.x, piece.y, piece.w, piece.h }, ",")
        end
        return table.concat(out, " ")
    end
    Equal(Pieces(101, 104), "down,37.5,-55,32,30 headDown,37.5,-63,32,32", "a straight drop")
    Equal(Pieces(102, 103), "across,133,-22.5,30,32 headRight,141,-22.5,32,32", "sideways to the right")
    Equal(Pieces(106, 104), "across,70,-85.5,156,32 headLeft,60,-85.5,32,32", "sideways to the left")
    Equal(Pieces(102, 105), "across,133,-22.5,62.5,32 down,163.5,-38.5,32,42.5 headDown,163.5,-63,32,32", "an elbow to the right")
    Equal(Pieces(103, 107), "across,37.5,-22.5,125.5,32 down,37.5,-38.5,32,105.5 headDown,37.5,-126,32,32", "an elbow to the left")
    Equal(Pieces(104, 101), "", "nothing drawn up the tree")

    local lines = s.Pieces(T.parts.child, "Interface\\TalentFrame\\UI-TalentBranches")
    local heads = s.Pieces(T.parts.heads, "Interface\\TalentFrame\\UI-TalentArrows")
    Equal(#lines .. " " .. #heads, "7 5", "seven lines and five heads drawn")
    Equal(lines[1]:GetDrawLayer(), "ARTWORK", "lines on the child's ARTWORK layer")
    Equal(T.parts.heads:GetFrameLevel(), T.parts.child:GetFrameLevel() + 5, "heads five levels above the child")
    Equal(select(2, heads[1]:GetPoint(1)), T.parts.child, "placed from the child's top-left")
    Equal(table.concat({ lines[1]:GetTexCoord() }, ","), "0,0.125,0,0.484375", "a lit drop's region")
    Equal(table.concat({ heads[1]:GetTexCoord() }, ","), "0,0.5,0,0.5", "a lit head's region")
    Equal(table.concat({ lines[2]:GetTexCoord() }, ","), "0.2578125,0.3828125,0.5,1", "an unlit line along a row")
    Equal(table.concat({ heads[2]:GetTexCoord() }, ","), "1,0.5,0.5,1", "an unlit right head: the left one mirrored")
    Equal(table.concat({ heads[5]:GetTexCoord() }, ","), "0.5,1,0.5,1", "an unlit left head")
    Equal(lines[3]:GetWidth() .. "x" .. lines[3]:GetHeight(), "62.5x32", "lines sized to their run")
    -- A tab with no links puts every piece away.
    T.parts.tabs[2]:Click()
    Equal(#s.Pieces(T.parts.child, "Interface\\TalentFrame\\UI-TalentBranches") .. " "
        .. #s.Pieces(T.parts.heads, "Interface\\TalentFrame\\UI-TalentArrows"), "0 0", "Fury has no links")
    s.Clean("links")
end

---------------------------------------------------------------------------
-- Tooltips (EraUI's own)
---------------------------------------------------------------------------
do
    local s = Session()
    local game, T = s.game, s.T
    game.Pass()
    s.Open()
    local function Hover(x, y)
        local button = s.ButtonAt(x, y)
        game.Enter(button)
        return button
    end
    local button = Hover(35, -146) -- Deep Wounds: gates, a prerequisite, two-column and odd data lines
    Equal(s.tipOwner, button, "the tooltip belongs to the talent")
    Equal(s.tipSide, "RIGHT", "to its right")
    Equal(T.hovered, button, "remembered as hovered")
    Equal(s.TipText(), "Deep Wounds / Rank 0/1 / Requires 10 points in Arms Talents / Requires 1 point in Improved Charge / "
        .. "Deep Wounds / Melee | Instant / One line only / Your critical strikes cause the target to bleed. / Click to learn",
        "name, rank, unmet gate (the tab's name), prerequisite, the data lines, Click to learn")
    local rows = s.tip
    Equal(table.concat({ rows[1][2], rows[1][3], rows[1][4] }, ","), "1,1,1", "the name in white")
    Equal(table.concat({ rows[3][2], rows[3][3], rows[3][4], rows[3][5] }, ","), "1,0.1,0.1,260", "the gate in red, wrapped")
    Equal(rows[4][5], 260, "the prerequisite wrapped too")
    Equal(table.concat({ rows[6].right[2], rows[6].right[3], rows[6].right[4] }, ","), "0.5,0.6,0.7", "a two-column line in its colours")
    Equal(rows[6][5], nil, "never wrapped")
    Equal(table.concat({ rows[7][2], rows[7][3], rows[7][4] }, ","), "1,0.82,0", "a data line with no colour in gold")
    Equal(rows[7][5], nil, "a line that asks not to wrap doesn't")
    Equal(rows[8][5], 260, "the rest wrap")
    Equal(table.concat({ rows[9][2], rows[9][3], rows[9][4] }, ","), "0.1,1,0.1", "Click to learn in green")
    game.Leave(button)
    Equal(T.hovered, nil, "forgotten on leave")
    Equal(s.Look.TipOwner(), nil, "the tooltip hidden")

    Hover(98, -20) -- Improved Rend, 1 of 3: the next rank
    Equal(s.TipText(), "Improved Rend / Rank 1/3 / Rend lasts 3 sec longer. /   / Next rank: / Rend lasts 6 sec longer. / Click to learn",
        "this rank's words, then the next rank's")
    Hover(35, -20) -- Deflection, 5 of 5
    Equal(s.TipText(), "Deflection / Rank 5/5", "fully ranked: no next rank, nothing to learn")
    Hover(161, -83) -- Anger Management 2/3, can't buy: a prerequisite from a source at 1 of 3
    Equal(s.TipText(), "Anger Management / Rank 2/3 / Requires 3 point in Improved Rend /   / Next rank:",
        "a prerequisite names its source's max rank")
    Hover(224, -83) -- no spell: the fallback
    Equal(s.TipText(), "  / Rank 0/1", "no spell name: a blank line and the rank")

    -- Shown in EraUI's own tooltip: a two-column line keeps its right text.
    Hover(35, -146)
    local tip
    for _, obj in ipairs(game.made) do
        if game.State(obj).strata == "TOOLTIP" then tip = obj end
    end
    True(tip ~= nil and tip:IsShown(), "EraUI's own tooltip frame shows")
    local rights = {}
    for _, region in ipairs({ tip:GetRegions() }) do
        if region:IsShown() and game.State(region).justify == "RIGHT" then rights[#rights + 1] = region:GetText() end
    end
    Equal(table.concat(rights, ","), "Instant", "the right-hand text in its own place")
    -- The next tooltip is one line (the undo button's): the right text of
    -- Deep Wounds' sixth line is put away, not left floating under it.
    game.Enter(T.parts.undo)
    local stale = {}
    for _, region in ipairs({ tip:GetRegions() }) do
        if region:IsShown() and game.State(region).justify == "RIGHT" then stale[#stale + 1] = region:GetText() end
    end
    Equal(table.concat(stale, ","), "", "a shorter tooltip next puts the sixth line's right text away")
    s.Clean("tooltips")
end

do -- The words' stand-ins, and the fallback without the trait entry lines
    local s = Session({ noWords = { TOOLTIP_TALENT_PREREQ = true, TOOLTIP_TALENT_RANK = true, TALENTS = true, TALENT_POINTS = true,
        TOOLTIP_TALENT_LEARN = true }, noTraitEntry = true })
    local game, T = s.game, s.T
    game.Pass()
    s.Open()
    Equal(T.parts.title:GetText(), "Talents", "Talents without the game's word")
    Equal(T.parts.points:GetText(), "Talent Points: |cffffffff5|r", "Talent Points too")
    game.Enter(s.ButtonAt(35, -146))
    Equal(s.TipText(), "Deep Wounds / Its own words. /   / Rank 0/1 / Click to learn",
        "without the game's trait lines: the spell's own lines, a blank line and the rank")
    s.Clean("stand-ins")

    local t = Session({ noWords = { TOOLTIP_TALENT_PREREQ = true } })
    t.game.Pass()
    t.Open()
    t.game.Enter(t.ButtonAt(161, -83))
    Equal(t.TipText(), "Anger Management / Rank 2/3 / Requires 3 points in Improved Rend /   / Next rank:", "plural for a talent of more ranks")
    t.game.Enter(t.ButtonAt(35, -146))
    True(t.TipText():find("Requires 1 point in Improved Charge", 1, true) ~= nil, "singular for one rank")
    t.Clean("prerequisite stand-ins")
end

---------------------------------------------------------------------------
-- Staging, refunds, Apply and undo
---------------------------------------------------------------------------
do
    local s = Session()
    local game, T = s.game, s.T
    game.Pass()
    s.Open()
    local charge = s.ButtonAt(161, -20)
    game.Enter(charge)
    charge:Click("LeftButton")
    Equal(#game.purchases, 1, "a left click stages a rank")
    Equal(game.purchases[1][1] .. ":" .. game.purchases[1][2], "7:103", "in your config, on that talent")
    True(T.model.staged, "something is staged")
    Equal(T.parts.points:GetText(), "Talent Points: |cffffffff4|r", "the points drop at once")
    True(T.parts.apply:IsEnabled() and T.parts.undo:IsEnabled(), "Apply and undo light up")
    False(T.parts.undoMark:IsDesaturated(), "the undo arrow in colour")
    Equal(T.parts.undoMark:GetAlpha(), 1, "at full alpha")
    Equal(s.TipText(), "Improved Charge / Rank 1/1 / Requires 3 point in Improved Rend", "the tooltip rebuilt after the click")
    Equal(s.Look.TipOwner(), charge, "the clicked talent keeps its tooltip (its button is never hidden in between)")
    Equal(T.hovered, charge, "and is still the hovered one")
    local wounds = s.ButtonAt(35, -146)
    wounds:Click("LeftButton")
    Equal(#game.purchases, 2, "another talent staged")
    wounds:Click("RightButton")
    Equal(#game.refunds, 1, "a right click takes a staged rank back")
    Equal(game.refunds[1][2], 107, "from that talent")
    s.ButtonAt(35, -83):Click("LeftButton")
    Equal(#game.purchases, 2, "a talent that can't be bought isn't")
    local before = s.reads
    s.ButtonAt(35, -20):Click("RightButton")
    Equal(#game.refunds, 1, "nor one with nothing staged taken back")
    Equal(s.reads, before + 1, "the window still refreshes")

    game.combat = true
    s.ButtonAt(98, -20):Click("LeftButton")
    s.ButtonAt(161, -20):Click("RightButton")
    T.parts.apply:Click()
    Equal(#game.purchases .. " " .. #game.refunds .. " " .. #game.commits, "2 1 0", "nothing staged, refunded or applied in a fight")
    game.combat = false

    -- Undo.
    T.parts.undo:Click()
    Equal(game.rollbacks, 1, "the undo button rolls the config back")
    Equal(game.sounds[#game.sounds], "IG_MAINMENU_OPTION_CHECKBOX_OFF", "with its sound")
    False(T.model.staged, "nothing staged after")
    False(T.parts.apply:IsEnabled(), "Apply off again")

    -- Apply.
    s.ButtonAt(161, -20):Click("LeftButton")
    T.parts.apply:Click()
    Equal(#game.commits, 1, "Apply commits")
    Equal(game.commits[1].saved, nil, "with no saved config")
    Equal(game.persisted[#game.persisted], "talents: commit called=true result=true", "a line for the developer sink")
    False(T.model.staged, "learned")
    Equal(#game.messages, 0, "no message")
    s.ButtonAt(98, -20):Click("LeftButton")
    game.commitResult = false
    T.parts.apply:Click()
    Equal(game.persisted[#game.persisted], "talents: commit called=true result=false", "a refused commit noted")
    Equal(#game.messages, 1, "the game's 'too fast' message")
    Equal(table.concat(game.messages[1], ","), "Too fast,1,0.1,0.1", "in red")
    s.Clean("learning")

    local t = Session({ noClassTalents = true })
    t.game.Pass()
    t.Open()
    t.ButtonAt(161, -20):Click("LeftButton")
    t.T.parts.apply:Click()
    Equal(#t.game.traitCommits, 1, "without the class talents commit: the trait tree's own")
    Equal(t.game.traitCommits[1], 7, "with the config")
    t.Clean("trait commit")
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
do
    local s = Session()
    local game, T = s.game, s.T
    game.Pass()
    s.Open()
    for _, event in ipairs({ "TRAIT_CONFIG_UPDATED", "TRAIT_TREE_CURRENCY_INFO_UPDATED", "TRAIT_NODE_CHANGED",
        "PLAYER_TALENT_UPDATE", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_LEVEL_UP", "PLAYER_LEVEL_CHANGED" }) do
        local before = s.reads
        game.Fire(event)
        game.Fire(event)
        Equal(s.reads, before, event .. ": nothing at once")
        game.Tick(0.05)
        Equal(s.reads, before + 1, event .. ": one refresh on the next frame")
    end
    game.trees.player.unspent = 6
    game.Fire("PLAYER_LEVEL_CHANGED")
    game.Tick(0.05)
    Equal(T.parts.points:GetText(), "Talent Points: |cffffffff6|r", "a new level's point shows straight away")
    s.Window():Hide()
    Equal(game.sounds[#game.sounds], "IG_CHARACTER_INFO_CLOSE", "the close sound")
    local before = s.reads
    game.Fire("PLAYER_LEVEL_UP")
    game.Tick(0.05)
    Equal(s.reads, before, "nothing while the window is closed")
    T.active = false
    s.Window():Show()
    Equal(s.reads, before, "and nothing while the window is off")
    T.active = true
    s.Window():Hide()

    -- A tooltip rebuilt when the game's data comes in, at most every 0.2 s.
    s.Open()
    local button = s.ButtonAt(98, -20)
    game.Enter(button)
    local shown = 0
    local show = s.Look.ShowTip
    s.Look.ShowTip = function(...) shown = shown + 1 return show(...) end
    game.Fire("TOOLTIP_DATA_UPDATE")
    Equal(shown, 1, "rebuilt when the data comes in")
    game.Fire("TOOLTIP_DATA_UPDATE")
    game.Fire("TOOLTIP_DATA_UPDATE")
    Equal(shown, 1, "not again within 0.2 s")
    game.Tick(0.25)
    Equal(shown, 2, "but once more when the 0.2 s are up")
    game.Leave(button)
    game.Fire("TOOLTIP_DATA_UPDATE")
    game.Tick(0.25)
    Equal(shown, 2, "nothing once it's gone")
    s.Clean("events")
end

do -- A refresh while a talent is hovered: its tooltip stays, brought up to date
    local s = Session()
    local game, T = s.game, s.T
    game.trees.player.unspent = 0
    game.Pass()
    s.Open()
    local charge = s.ButtonAt(161, -20)
    game.Enter(charge)
    Equal(s.TipText(), "Improved Charge / Rank 0/1 / Requires 3 point in Improved Rend", "no points: nothing to learn")
    game.trees.player.unspent = 1
    game.Fire("PLAYER_LEVEL_CHANGED")
    game.Tick(0.05)
    Equal(s.Look.TipOwner(), charge, "the hovered talent keeps its tooltip through a refresh")
    Equal(T.hovered, charge, "still hovered")
    Equal(s.TipText(), "Improved Charge / Rank 0/1 / Requires 3 point in Improved Rend / Click to learn",
        "and it shows the new point")
    -- A tab with fewer talents puts the spare buttons away: the one under the
    -- mouse (Mortal Strike, the eighth) loses it, and its tooltip goes.
    local strike = s.ButtonAt(98, -272)
    game.Enter(strike)
    Equal(s.Look.TipOwner(), strike, "Mortal Strike's tooltip")
    T.parts.tabs[2]:Click()
    False(strike:IsShown(), "a spare button put away")
    Equal(T.hovered, nil, "no longer hovered")
    Equal(s.Look.TipOwner(), nil, "its tooltip gone")
    s.Clean("hovered refresh")
end

do -- The game menu hook is the talent window's own: another area's hook on the same script still goes in
    local s = Session()
    local game, env, Look = s.game, s.env, s.Look
    local theirs = 0
    Look.HookScript(env.GameMenuFrame, "OnShow", function() theirs = theirs + 1 end)
    game.Pass()
    s.Open()
    env.GameMenuFrame:Show()
    False(s.Window():IsShown(), "the game menu closes the talent window")
    Equal(theirs, 1, "and the other hook on the menu runs too")
    env.GameMenuFrame:Hide()
    s.Open()
    s.Window():Hide()
    s.Open()
    env.GameMenuFrame:Show()
    Equal(#(game.State(env.GameMenuFrame).hooks.OnShow or {}), 2, "each hook on the menu once")
    s.Clean("menu hooks")
end

---------------------------------------------------------------------------
-- Scrolling
---------------------------------------------------------------------------
do
    local s = Session()
    local game, T, st = s.game, s.T, s.game.State
    game.Pass()
    s.Open()
    local view, bar = T.parts.view, T.parts.bar
    Equal(view:GetWidth() .. "x" .. view:GetHeight(), "296x332", "the view is 296 x 332")
    Equal(table.concat({ view:GetPoint("TOPLEFT") }, " ", 3, 5), "TOPLEFT 22 -77", "at (22, -77)")
    Equal(table.concat({ view:GetPoint("BOTTOMRIGHT") }, " ", 3, 5), "TOPLEFT 318 -409", "pinned by two corners")
    Equal(view:GetScrollChild(), T.parts.child, "the child scrolls")
    True(st(view).wheel, "the wheel on")
    Equal(bar:GetWidth(), 16, "the bar is 16 wide")
    Equal(table.concat({ bar:GetPoint("TOPLEFT") }, " ", 3, 5), "TOPRIGHT 6 -16", "6 right of the view, 16 in")
    Equal(bar:GetHeight(), 300, "300 tall")
    local up, down = s.Look.ScrollArrows(bar)
    Equal(st(bar:GetThumbTexture()).theme, "scrollKnob", "the knob through Dark Mode")
    False(bar:GetThumbTexture():IsShown(), "no knob with nothing to scroll")
    True(bar:IsShown(), "the bar stays")
    False(up:IsEnabled() or down:IsEnabled(), "both arrows off")
    local column = {}
    for _, region in ipairs({ bar:GetRegions() }) do
        local state = st(region)
        if state.theme == "charScrollBar" then column[#column + 1] = region end
    end
    Equal(#column, 3, "the stone column's three pieces through Dark Mode")
    Equal(column[1]:GetWidth() .. " " .. column[1]:GetHeight() .. " " .. tostring(column[1]:IsShown()), "31 233 true", "a 233 top")
    Equal(column[3]:GetHeight() .. " " .. tostring(column[3]:IsShown()), "108 true", "the 108 foot")
    False(column[2]:IsShown(), "no middle")
    Equal(select(2, column[1]:GetPoint(1)), up, "hung from the up arrow")

    T.parts.tabs[3]:Click()
    Equal(select(2, bar:GetMinMaxValues()), 123, "Protection scrolls 455 - 332")
    True(bar:GetThumbTexture():IsShown(), "the knob shows")
    False(up:IsEnabled(), "up off at the top")
    True(down:IsEnabled(), "down on")
    down:Click()
    Equal(bar:GetValue(), 20, "an arrow moves 20")
    Equal(view:GetVerticalScroll(), 20, "the view follows")
    Equal(game.sounds[#game.sounds], "U_CHAT_SCROLL_BUTTON", "with the scroll sound")
    game.Run(view, "OnMouseWheel", -1)
    Equal(bar:GetValue(), 50, "a wheel notch down moves 30")
    game.Run(view, "OnMouseWheel", 1)
    Equal(bar:GetValue(), 20, "and up")
    game.Run(view, "OnMouseWheel", -10)
    Equal(bar:GetValue(), 123, "never past the end")
    False(down:IsEnabled(), "down off at the end")
    s.Window():Hide()
    s.Open()
    Equal(bar:GetValue(), 123, "the place is kept through closing and opening")
    Equal(T.tab, 3, "and the tab")
    T.parts.tabs[3]:Click()
    Equal(bar:GetValue(), 123, "clicking the selected tab does nothing")
    T.parts.tabs[1]:Click()
    Equal(bar:GetValue(), 0, "another tab goes back to the top")
    Equal(game.sounds[#game.sounds], "IG_CHARACTER_INFO_TAB", "with the tab sound")
    s.Clean("scrolling")
end

---------------------------------------------------------------------------
-- No tree, fewer tabs, secrets
---------------------------------------------------------------------------
do
    local s = Session()
    local game, T = s.game, s.T
    game.Pass()
    s.Open()
    T.parts.tabs[3]:Click()
    Equal(T.tab, 3, "third tab")
    table.remove(game.trees.player.groups, 3)
    T.Refresh()
    Equal(T.tab, 1, "fewer tabs than the selected one: back to the first")
    False(T.parts.tabs[3]:IsShown(), "the missing tree's tab hidden")
    local player = game.trees.player
    game.trees.player = nil
    T.Refresh()
    Equal(T.model, nil, "no tree")
    for _, child in ipairs({ T.parts.child:GetChildren() }) do
        if child:GetObjectType() == "Button" then False(child:IsShown(), "no talent shown without a tree") end
    end
    Equal(#s.Pieces(T.parts.child, "Interface\\TalentFrame\\UI-TalentBranches"), 0, "no lines")
    False(T.parts.tabs[1]:IsShown(), "no tabs")
    T.parts.apply:Click()
    T.parts.undo:Click()
    Equal(#game.commits .. " " .. game.rollbacks, "0 0", "nothing to apply or undo")
    game.trees.player = player
    player.nodes[102].override = { ranksPurchased = SECRET, maxRanks = SECRET, canPurchaseRank = SECRET }
    T.Refresh()
    local rend = T.model.byNode[102]
    Equal(rend.ranks .. "/" .. rend.max .. " " .. tostring(rend.canBuy), "0/1 false", "secret ranks count as missing")
    game.Enter(s.ButtonAt(98, -20))
    True(s.TipText():find("Rank 0/1", 1, true) ~= nil, "and the tooltip copes")
    s.Clean("no tree")

    local t = Session({ groupsBroken = true })
    t.game.Pass()
    t.Open()
    Equal(t.T.model, nil, "groups that aren't a table: no tree")
    Equal(t.T.parts.title:GetText(), "Talents", "the first open's title stays")
    t.Clean("broken groups")

    local u = Session({ noCombatConfig = true })
    u.game.Pass()
    u.Open()
    Equal(u.T.model and u.T.model.config, 7, "the active config when the spec group's is missing")
    u.Clean("active config")
end

---------------------------------------------------------------------------
-- Ways in: micro buttons, the click target, quick keybind mode, a fight
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, T = s.game, s.env, s.T
    game.Pass()
    s.Open()
    True(s.Window():IsShown(), "open")
    env.PlayerSpellsMicroButton:Click("LeftButton")
    False(s.Window():IsShown(), "the other micro button closes it")
    game.quickBind = true
    env.TalentMicroButton:Click("LeftButton")
    False(s.Window():IsShown(), "nothing in quick keybind mode")
    game.quickBind = false
    game.combat = true
    env.TalentMicroButton:Click("LeftButton")
    False(s.Window():IsShown(), "in a fight not at once")
    game.Tick(0.05)
    True(s.Window():IsShown(), "but on the next frame")
    game.combat = false
    s.Window():Hide()

    local target = env.EraUIClassicTalentsBind
    Equal(target:GetParent(), env.UIParent, "the click target is a child of UIParent")
    Equal(table.concat(game.State(target).clicks, ","), "AnyDown,AnyUp", "registered for any down and up click")
    target:Click("LeftButton", true)
    target:Click("LeftButton", false)
    True(s.Window():IsShown(), "a key press (down and up) opens it once")
    game.Tick(0.3)
    target:Click("LeftButton", true)
    target:Click("LeftButton", false)
    False(s.Window():IsShown(), "and closes it once")
    Equal(game.gameClicks, 0, "the game's own window never opened")

    -- Escape and the game menu.
    s.Open()
    env.GameMenuFrame:Show()
    False(s.Window():IsShown(), "the game menu closes it")
    env.GameMenuFrame:Hide()
    s.Open()
    game.combat = true
    env.GameMenuFrame:Show()
    True(s.Window():IsShown(), "not in a fight")
    game.combat = false
    env.GameMenuFrame:Hide()
    s.Window():Hide()
    s.Open()
    s.Window():Hide()
    local listed = 0
    for _, name in ipairs(env.UISpecialFrames) do if name == "EraUIClassicTalents" then listed = listed + 1 end end
    Equal(listed, 1, "listed for Escape once however often it opens")
    Equal(#game.registered, 1, "registered with the window manager once")
    Equal(game.ns.ToggleTalents(), true, "ToggleTalents works while on")
    True(s.Window():IsShown(), "and opens it")
    s.Clean("ways in")
end

---------------------------------------------------------------------------
-- Inspecting another player
---------------------------------------------------------------------------
do
    local s = Session({ inspectButton = true })
    local game, env, T, st = s.game, s.env, s.T, s.game.State
    game.trees.inspect = MageTree()
    game.units.target = { "Jaina", "Mage", "MAGE" }
    game.units.focus = { "Gurgle", "Rogue", "ROGUE" }
    game.Pass()
    s.Open()
    T.parts.tabs[2]:Click()
    game.Inspect("target")
    game.inspectButton:Click("LeftButton")
    local window = s.Window()
    True(window:IsShown(), "the inspect button opens the window")
    Equal(T.unit, "target", "on the inspected unit")
    Equal(T.tab, 1, "from the first tab")
    Equal(T.parts.title:GetText(), "Jaina", "titled with their name")
    Equal(st(T.parts.portrait).portrait, "target", "their portrait")
    Equal(T.parts.points:GetText(), "", "no points text")
    Equal(st(T.parts.back.TopLeft).file, "Interface\\TalentFrame\\MageArcane-TopLeft", "their class's background")
    Equal(T.model.config, -1, "the inspect config")
    local Keep = s.Look.WindowTrait(window, "keep")
    Equal(type(Keep), "function", "the window manager's keep question, in EraUI's own record (Look.WindowTraits)")
    Equal(Keep(), env.InspectFrame, "the inspect window kept open beside it")
    local focus = s.ButtonAt(98, -20)
    game.Enter(focus)
    False(s.TipText():find("Click to learn", 1, true), "no Click to learn while inspecting")
    focus:Click("LeftButton")
    focus:Click("RightButton")
    T.parts.apply:Click()
    Equal(#game.purchases .. " " .. #game.refunds .. " " .. #game.commits, "0 0 0", "read only")
    False(T.parts.apply:IsEnabled() or T.parts.undo:IsEnabled(), "Apply and undo stay off")

    game.Own(env.InspectFrame, "unit", "focus")
    game.Tick(0.25)
    Equal(T.unit, "focus", "follows a new player in the inspect window")
    Equal(T.parts.title:GetText(), "Gurgle", "their name")
    Equal(st(T.parts.portrait).portrait, "focus", "their portrait")
    Equal(st(T.parts.back.TopLeft).file, "Interface\\TalentFrame\\RogueAssassination-TopLeft", "their background")

    env.InspectFrame:Hide()
    game.Tick(0.25)
    False(window:IsShown(), "closing the inspect window closes it")
    Equal(T.unit, nil, "the unit forgotten")
    Equal(Keep(), nil, "nothing kept beside it then")

    game.Inspect("target")
    game.inspectButton:Click("LeftButton")
    env.TalentMicroButton:Click("LeftButton")
    True(window:IsShown(), "the micro button while inspecting: open again")
    Equal(T.unit, nil, "on your own trees")
    Equal(T.parts.title:GetText(), "Talents", "titled Talents again")
    Equal(T.parts.points:GetText(), "Talent Points: |cffffffff5|r", "your points")
    window:Hide()

    game.validInspect = false
    game.inspectButton:Click("LeftButton")
    False(window:IsShown(), "nothing without valid inspect data")
    game.validInspect = true
    game.units.target = { SECRET, "Mage", "MAGE" }
    game.inspectButton:Click("LeftButton")
    Equal(T.parts.title:GetText(), "Talents", "a hidden name: Talents")
    window:Hide()
    s.expectSets = 3
    s.Clean("inspecting")

    -- An inspect window loaded later, and one without a talents button.
    local t = Session({ inspectButton = true, inspectLate = true })
    t.game.Pass()
    t.game.LoadInspect()
    True(t.game.inspectButton:GetScript("OnClick") ~= t.game.GameClick, "a late inspect window's button taken while on")
    local u = Session({ inspectButton = true, inspectLate = true, db = { talents = false } })
    u.game.Pass()
    u.game.LoadInspect()
    Equal(u.game.inspectButton:GetScript("OnClick"), u.game.GameClick, "left alone while off")
    local v = Session()
    v.game.Pass()
    True(v.T.active, "no talents button on this client is harmless")
    v.Clean("no inspect button")
end

---------------------------------------------------------------------------
-- Off and on again
---------------------------------------------------------------------------
do
    local s = Session({ inspectButton = true })
    local game, env, T = s.game, s.env, s.T
    game.Pass()
    s.Open()
    game.ns.db.talents = false
    game.Pass()
    False(T.active, "off")
    False(s.Window():IsShown(), "the window hidden")
    for _, name in ipairs({ "TalentMicroButton", "PlayerSpellsMicroButton" }) do
        Equal(env[name]:GetScript("OnClick"), game.GameClick, name .. ": the game's own click back")
    end
    Equal(game.inspectButton:GetScript("OnClick"), game.GameClick, "the inspect button's too")
    env.TalentMicroButton:Click("LeftButton")
    Equal(game.gameClicks, 1, "the game's own window opens")
    env.EraUIClassicTalentsBind:Click("LeftButton", true)
    False(s.Window():IsShown(), "the click target does nothing while off")
    Equal(game.ns.ToggleTalents(), false, "nor ToggleTalents")
    local sets = game.scriptSets
    game.Pass()
    game.Pass()
    Equal(game.scriptSets, sets, "restoring again changes nothing")
    game.ns.db.talents = true
    game.Pass()
    True(env.TalentMicroButton:GetScript("OnClick") ~= game.GameClick, "on again: EraUI's click")
    -- Another addon's click on the button is never taken away by the restore.
    local theirs = function() end
    env.PlayerSpellsMicroButton:SetScript("OnClick", theirs)
    game.ns.db.talents = false
    game.Pass()
    Equal(env.PlayerSpellsMicroButton:GetScript("OnClick"), theirs, "another addon's click is left alone")
    Equal(env.TalentMicroButton:GetScript("OnClick"), game.GameClick, "the other gets the game's back")
    s.expectSets = game.scriptSets
    s.Clean("off and on")

    -- Off from the first load: nothing taken, nothing made.
    local t = Session({ db = { talents = false } })
    t.game.Pass()
    Equal(t.game.scriptSets, 0, "nothing set on the game's buttons")
    Equal(rawget(t.env, "EraUIClassicTalents"), nil, "no window")
    t.Clean("off from the start")
end

---------------------------------------------------------------------------
-- The atlas when the client has it
---------------------------------------------------------------------------
do
    local s = Session({ atlases = { ["talents-button-undo"] = true } })
    s.game.Pass()
    s.Open()
    Equal(s.game.State(s.T.parts.undoMark).atlas, "talents-button-undo", "the game's undo atlas")
    Equal(s.T.parts.undoMark:GetWidth(), 13, "still 13 x 13")
    s.Clean("atlas")
end

---------------------------------------------------------------------------
-- The shared pieces this area added to Look/Base.lua, on their other paths
---------------------------------------------------------------------------
do
    local s = Session()
    local game, env, Look, st = s.game, s.env, s.Look, s.game.State
    s.game.settings.darkMode = true
    local box = Look.InsetBox(env.UIParent, 32)
    local floor = Look.OwnPiece(box, "floor")
    True(floor ~= nil, "an inset box with its floor")
    Equal(st(floor).file, "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-Background-Marble", "the bundled marble")
    Equal(st(floor).theme, "marbleBg", "through Dark Mode as marbleBg")
    Equal(table.concat(st(floor).colour, ",", 1, 3), "1.35,1.35,1.35", "lifted to 1.35 (07-spells 7.3: the one copy kept)")
    Near(select(4, floor:GetPoint("TOPLEFT")), 8, "a quarter of the edge in")
    Near(select(5, floor:GetPoint("TOPLEFT")), -8, "from the top too")
    Near(st(box).backdrop.insets.left, 8, "the border's insets too")
    local area = Look.Build("Frame", env.UIParent, nil, { size = { 100, 60 } })
    local seen = {}
    local bar = Look.ClassicScrollBar(env.UIParent, area, function(value) seen[#seen + 1] = value end, true)
    Look.ScrollRange(bar, 0)
    False(bar:IsShown(), "a bar asked to hide while idle hides with nothing to scroll")
    Look.ScrollRange(bar, -5)
    Equal(select(2, bar:GetMinMaxValues()), 0, "a range below 0 is 0")
    Look.ScrollRange(bar, 40, 15)
    True(bar:IsShown(), "and shows with something to scroll")
    local _, down = Look.ScrollArrows(bar)
    down:Click()
    Equal(bar:GetValue(), 15, "its arrows move by the step given")
    Equal(seen[#seen], 15, "and the callback hears the value")
    Look.ScrollColumn(bar)
    local pieces = 0
    for _, region in ipairs({ bar:GetRegions() }) do
        if st(region).theme == "charScrollBar" and region:IsShown() then pieces = pieces + 1 end
    end
    Equal(pieces, 0, "a bar too short (28 + 41 < 132) has no column")
    bar:SetHeight(400)
    local top, middle = Look.OwnPiece(bar, "columntop"), Look.OwnPiece(bar, "columnmiddle")
    Equal(top:GetHeight(), 256, "a tall bar: the top at its full 256")
    Equal(select(4, top:GetTexCoord()), 1, "all of its sheet")
    True(middle:IsShown(), "and a middle between it and the foot")
    Equal(Look.ScrollArrows(env.UIParent), nil, "no arrows for a frame that isn't such a bar")
    -- The tooltip: a two-column line never wraps; a later tip without one
    -- puts the right text away; the tip's width takes both texts.
    Look.ShowTip(area, "RIGHT", { { "Title", 1, 1, 1 }, { "Left words", 1, 1, 1, 30, right = { "Right", 1, 1, 1 } } })
    local tip
    for _, obj in ipairs(game.made) do if st(obj).strata == "TOOLTIP" then tip = obj end end
    local lefts, rights = {}, {}
    for _, region in ipairs({ tip:GetRegions() }) do
        if st(region).kind == "FontString" and region:IsShown() then
            local list = st(region).justify == "RIGHT" and rights or lefts
            list[#list + 1] = region
        end
    end
    Equal(lefts[2]:GetWidth(), 0, "the left text of a two-column line keeps its own width")
    Equal(tip:GetWidth(), 18 + 10 * 6 + 12 + 5 * 6, "the tip as wide as both texts and the gap")
    Equal(select(3, rights[1]:GetPoint(1)) .. " " .. select(4, rights[1]:GetPoint(1)), "TOPRIGHT -9", "the right text to the tip's right edge")
    Look.ShowTip(area, "RIGHT", { { "Only", 1, 1, 1 }, { "Lines", 1, 1, 1 } })
    False(rights[1]:IsShown(), "put away when the next tip has none")
    Look.ShowTip(area, "RIGHT", { { "Title", 1, 1, 1 }, { "Left", 1, 1, 1, nil, right = { "Right", 1, 1, 1 } } })
    True(rights[1]:IsShown(), "back for a tip that has one")
    Look.ShowTip(area, "RIGHT", { { "Just one line", 1, 1, 1 } })
    False(rights[1]:IsShown(), "put away when the next tip is shorter")
    Equal(Look.TipOwner(), area, "the tip's owner")
    Look.HideTip(env.UIParent)
    Equal(Look.TipOwner(), area, "hiding someone else's tip leaves it")
    Look.HideTip(area)
    Equal(Look.TipOwner(), nil, "hidden by its owner")
    s.Clean("shared pieces")
end

print("Talent window checks passed: " .. checks .. " assertions.")
