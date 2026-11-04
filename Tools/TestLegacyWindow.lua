-- The Legacy window in the 1.x look (registry "legacyWindow", Look/Legacy*.lua)
-- on a sealed mock of Forever's Legacy window built from the camelot XML
-- (Tools/LegacyMockGame.lua: any key EraUI writes on one of the game's
-- objects fails; no GameTooltip, no MouseIsOver, no key bindings). It checks:
--   1. the registry entry, its default (on) and its reload note;
--   2. the frame: the window at the 1.x spellbook's size (where the game
--      puts it), the game's frame art and page backdrops faded, the
--      spellbook's four pieces at their own size (no stretched middle),
--      Black Pages' cover over the parchment as the spellbook's, the crest in
--      the ring, the title, the red X, the page tabs along the foot and
--      following the page shown;
--   3. the Progress Track: the ring, label and shorter bar at the top, the
--      cards down the page (slot, name, plate, check, names gold once
--      earned) inside the list and the parchment, laid out again each time
--      the game sets its track up, the arrows at the foot, a scrolling track
--      paging by the game's arrows;
--   4. the Challenges with the game's gamepad mode on (the game's own page,
--      dressed): the bar in the band, the category list on the top part and
--      the challenges under it, all inside the parchment; quest-log rows,
--      cards (text narrowed, points plate under the icon), objectives, the
--      drop down and scroll bars, painted again after the game's own
--      repaints;
--   4b. the Challenges as EraUI draws them (no gamepad): the game's search
--      and filter in their strip, its rows and cards faded and parked out of
--      reach; EraUI's list (8 rows, headers gold and brown, folding kept for
--      the session and open while searching, counts, icons, plates, the
--      highlight bar, the 1.x scroll bar and the wheel) equal to the game's
--      own results under every filter and search; the details (name, date,
--      plate, text, objectives with checks and bars, reward words, the Track
--      box and the game's tracking calls, its limit and rule, scrolling);
--      EraUI's tooltip box; the chat link and watch clicks; a challenge
--      chosen from elsewhere (its category opened, scrolled to, through a
--      search or filter the game clears); updates on the game's events; a
--      fight with hidden values; the gamepad mode coming and going; off and
--      on; Dark Windows and Black Pages;
--   5. the Legacy Tree: the side tabs, the points in the band, the emblem,
--      name, spent points and search above the tree, the tree centred in
--      its box and brought closer together when it is bigger (every talent
--      inside), Apply/undo/reset at the foot, the talents' sockets by state,
--      their ranks as the old talent window's ("current/max" in its small
--      font on the old rank box, sized for "max/max", in the state's
--      colour; made from the talent's ranks on 70450, where the game writes
--      only the current rank), the 1.x links and their places, redrawn when
--      the talents move, gates;
--   6. the game's controls: still shown, at full alpha, taking the mouse,
--      their scripts untouched; none of EraUI's frames takes the mouse;
--   7. Dark Mode, Dark Windows and Black Pages with the real
--      Core/Appearance.lua;
--   8. nothing done in a fight, booked for its end; once dressed, the size
--      and layout hold when the window opens in a fight (the cards and
--      talents the game lays out again laid out again);
--   9. off: everything back (the window's size and the pages' layout, the
--      cards in the game's row, the talents where the game put them) and
--      EraUI's art hidden; on again: laid out again; off from login: nothing
--      touched at all;
--  10. Squirt's in-game round (22 Oct, screenshots 474-487): the ink on the
--      normal parchment is the quest log's and reads (Dark Windows keeps its
--      light text); the Challenges list has 8 rows and a usual challenge's
--      whole details show without scrolling; Apply, undo and reset sit above
--      the parchment's burnt rim; the scroll bars' knobs show in Dark Mode
--      too; the three real trees (and Adventure as the game showed it, one
--      talent off the grid) fitted with no two talents or rank boxes
--      touching, with their real most ranks, on both builds;
--  11. build 70532 (live Forever; every section above is Squirt's 70450):
--      the game's new unnamed rank box faded (found by its art, or by its
--      place on a client that doesn't name it), its "current/max" in white
--      kept as the rank in the old colours, the reward cards' new hover
--      glow faded (the game's hover and tooltip still working), in a fight,
--      off and on again.
-- Run from the addon folder: fengari Tools/TestLegacyWindow.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-3 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function Colour(colour, rgb, label)
    Near(colour[1], rgb[1], label .. " (red)")
    Near(colour[2], rgb[2], label .. " (green)")
    Near(colour[3], rgb[3], label .. " (blue)")
end

local Mock = dofile("Tools/LegacyMockGame.lua")
local FILES = { "Look/Base.lua", "Look/SpellKit.lua", "Look/TalentKit.lua", "Look/LegacyKit.lua", "Look/LegacyShell.lua",
    "Look/LegacyRewards.lua", "Look/LegacyChallenges.lua", "Look/LegacyChallengeData.lua", "Look/LegacyChallengeList.lua",
    "Look/LegacyChallengeDetail.lua", "Look/LegacyTree.lua", "Look/LegacyEdges.lua", "Look/LegacyModule.lua" }
local BOOK = "Interface\\Spellbook\\UI-SpellbookPanel-"
local GOLD, INK, LIGHT, DIM = { 1, 0.82, 0 }, { 0.18, 0.12, 0.06 }, { 0.9, 0.9, 0.88 }, { 0.66, 0.5, 0.18 }
local GREY_INK = { 0.2, 0.2, 0.2 }

-- A session: the mock, EraUI's files, a first pass. opts: off (the setting
-- off from login), settings, appearance (the real Core/Appearance.lua),
-- gamepad (the game's gamepad mode on: the Challenges page stays the game's
-- own, dressed), build (the client's: 70450 unless set, or 70532).
local function Session(opts)
    opts = opts or {}
    local game = Mock.New({ build = opts.build })
    game.gamepad = opts.gamepad == true
    for key, value in pairs(opts.settings or {}) do game.settings[key] = value end
    local Look = game.Load(FILES)
    if opts.appearance then
        local env = setmetatable({ CreateFrame = false }, { __index = game.env })
        game.E.modules = game.E.modules or {}
        assert(loadfile("Core/Appearance.lua", "t", env))("EraUI", game.E)
    end
    if opts.off then game.ns.db.legacyWindow = false end
    game.Pass()
    return game, Look
end

local function S(game, obj) return game.st[obj] end
local function Piece(Look, owner, purpose) return Look.OwnPiece(owner, "legacy." .. purpose) end
local function Anchor(game, region, point)
    local s = game.st[region]
    local anchor = s.points[point or s.order[1]]
    if not anchor then return "none" end
    local relative = anchor[2]
    local name = relative and (relative:GetName() or tostring(game.st[relative].kind)) or "nil"
    return string.format("%s %s %s %g,%g", anchor[1], name, anchor[3], anchor[4], anchor[5])
end
local function Field(obj, key) return rawget(obj, key) end
local function Numbers(list)
    local out = {}
    for i, value in ipairs(list) do out[i] = string.format("%g", value) end
    return table.concat(out, ",")
end
local function Coords(game, texture) return Numbers(game.st[texture].coords) end
local function Errors(game, label) Equal(#game.errors, 0, label .. ": no errors (" .. tostring(game.errors[1]) .. ")") end

-- Where a piece is (the mock's layout solver), in the window's units from its
-- top left, down counted positive: left, top, right, foot.
local function Box(g, obj, win)
    local l, b, r, t = g.Rect(obj)
    local wl, _, _, wt = g.Rect(win)
    assert(l and wl, "no rect for a piece")
    return l - wl, wt - t, r - wl, wt - b
end
-- A piece wholly inside an area { left, top, right, bottom } (window units).
local function Within(g, obj, win, area, label)
    local l, t, r, f = Box(g, obj, win)
    checks = checks + 1
    local slack = 0.01
    if l < area.left - slack or t < area.top - slack or r > area.right + slack or f > area.bottom + slack then
        error(string.format("%s: at %g,%g to %g,%g, outside %g,%g to %g,%g", label, l, t, r, f, area.left, area.top,
            area.right, area.bottom), 2)
    end
end
-- Two pieces clear of each other.
local function Apart(g, a, b, win, label)
    local al, at, ar, af = Box(g, a, win)
    local bl, bt, br, bf = Box(g, b, win)
    checks = checks + 1
    if al < br - 0.01 and bl < ar - 0.01 and at < bf - 0.01 and bt < af - 0.01 then error(label .. ": they overlap", 2) end
end
local WHOLE = { left = 0, top = 0, right = 336, bottom = 422 }

---------------------------------------------------------------------------
-- 1. The registry entry
---------------------------------------------------------------------------

do
    local game, Look = Session()
    local ns = game.ns
    Equal(ns.DB_DEFAULTS.legacyWindow, true, "on by default (Squirt's call)")
    Equal(ns.RELOAD_KEYS.legacyWindow, true, "turning it off asks for a reload")
    local module = game.Module("legacyWindow")
    Equal(module ~= nil and type(module.apply) == "function" and type(module.restore) == "function", true, "registered with apply and restore")
    Equal(Look.Legacy.active, true, "on after the first pass")
    Equal(Look.Legacy.applied, false, "nothing dressed before the game's Legacy addon loads")
    Errors(game, "registry")
end

---------------------------------------------------------------------------
-- 2. The frame
---------------------------------------------------------------------------

-- With the game's gamepad mode on: the Challenges page here is the game's
-- own, dressed (EraUI's own list and details: section 4b).
local game, Look = Session({ gamepad = true })
local st, ns, L = game.st, game.ns, Look.Legacy
-- The game's controls and their scripts before EraUI sees them.
local window = game.LoadAddOn()
Equal(L.applied, true, "dressed as the addon loads")
Equal(L.dressed, true, "the whole window")
local tabs = Field(window, "Tabs")
local rewards, challenges, tree = Field(window, "RewardTrackPage"), Field(window, "ChallengesPage"), Field(window, "TreePage")

Equal(S(game, Field(window, "NineSlice")).alpha, 0, "the game's nine-slice faded")
Equal(S(game, Field(window, "Bg")).alpha, 0, "the game's rock faded")
Equal(S(game, Field(window, "TopTileStreaks")).alpha, 0, "the streaks faded")
for _, page in ipairs({ rewards, challenges, tree }) do Equal(S(game, Field(page, "Background")).alpha, 0, "a page's backdrop faded") end

-- The window at the 1.x spellbook's size: the frame the spellbook's own
-- 384 x 512 sheet shows (15 in, 15 down). Where it opens stays the game's.
Equal(st[window].width .. "x" .. st[window].height, "336x422", "the window at the 1.x spellbook's size")
Equal(L.WIDE .. "x" .. L.TALL, "336x422", "the kit's size for it")
Equal(Anchor(game, window), "TOPLEFT UIParent TOPLEFT 51,-116", "where the game's panel manager put it, left alone")
-- The spellbook's four pieces, exactly as the spellbook lays them: their
-- own files and sizes, uncut, the sheet's top left 15 out past the window's.
local SHEET = { { "TopLeft", 256, -15, 15 }, { "TopRight", 128, 241, 15 }, { "BotLeft", 256, -15, -241 }, { "BotRight", 128, 241, -241 } }
local across, down = 0, 0
for i, part in ipairs(SHEET) do
    local piece = Piece(Look, window, "sheet" .. part[1])
    Equal(S(game, piece).file, BOOK .. part[1], part[1] .. ": the spellbook's own file")
    Equal(Look.ART["sb" .. part[1]].client, BOOK .. part[1], part[1] .. ": the very art key the spellbook's pages use")
    Equal(Coords(game, piece), "0,1,0,1", part[1] .. ": uncut, nothing stretched")
    Equal(st[piece].width .. "x" .. st[piece].height, part[2] .. "x256", part[1] .. ": at its own size")
    Equal(Anchor(game, piece), string.format("TOPLEFT LegacySystemFrame TOPLEFT %d,%d", part[3], part[4]), part[1] .. ": in its place on the sheet")
    Equal(st[piece].layer, "BACKGROUND", part[1] .. ": under everything of the game's")
    Equal(game.dark[piece], "trim", part[1] .. ": handed to Dark Windows as trim, as the spellbook's")
    if i <= 2 then across = across + part[2] end
    if i % 2 == 1 then down = down + 256 end
end
Equal(across .. "x" .. down, Look.Spells.WIDTH .. "x" .. Look.Spells.HEIGHT, "the sheet the spellbook's own 384 x 512")
Equal(Piece(Look, window, "shell2.1"), nil, "no stretched middle piece")

local cover = Piece(Look, window, "cover")
Equal(st[cover].shown, false, "Black Pages' cover made hidden")
Equal(game.dark[cover], "cover", "handed to Dark Windows as the cover")
do
    local l, t, r, f = Box(game, cover, window)
    Equal(string.format("%g,%g %gx%g", l, t, r - l, f - t), "7,60 322x356",
        "over the parchment alone, the spellbook's cover (322 x 356 at its 22, 75)")
end
-- The pages follow the window (the game anchors them to it).
for _, key in ipairs({ "RewardTrackPage", "ChallengesPage", "TreePage" }) do Within(game, Field(window, key), window, WHOLE, key .. " inside the window") end
local disc = Piece(Look, window, "disc")
Equal(Anchor(game, disc), "CENTER LegacySystemFrame TOPLEFT 24,-22", "the dark disc in the ring")
local portrait = Field(Field(window, "PortraitContainer"), "portrait")
Equal(st[portrait].width .. "x" .. st[portrait].height, "40x55", "the game's crest sized for the ring")
Equal(Anchor(game, portrait), "CENTER LegacySystemFrame TOPLEFT 24,-22", "in the ring")
Equal(st[portrait].atlas, "Legacy-up-c60", "the game's own crest kept")
local titles = Field(window, "TitleContainer")
Equal(Anchor(game, titles, "TOPLEFT") .. " / " .. Anchor(game, titles, "TOPRIGHT"),
    "TOPLEFT LegacySystemFrame TOPLEFT 58,1 / TOPRIGHT LegacySystemFrame TOPRIGHT -40,1", "the title on the strip")
Colour(st[Field(titles, "TitleText")].textColour, LIGHT, "the title light")
local close = Field(window, "CloseButton")
Equal(st[close].width, 32, "the red X 32 square")
Equal(st[close:GetNormalTexture()].file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up", "in the 1.x red art")
Equal(Anchor(game, close), "CENTER LegacySystemFrame TOPRIGHT -11,-10", "in the frame's corner box")
Equal(game.dark[close], "cross", "handed to Dark Windows")

-- The page tabs.
local WORDS = { "Rewards", "Challenges", "Legacy Tree" }
for i, tab in ipairs(tabs) do
    for _, key in ipairs({ "Background", "Icon", "SelectedTexture", "HighlightTexture" }) do
        Equal(S(game, Field(tab, key)).alpha, 0, "tab " .. i .. ": the game's " .. key .. " faded")
    end
    Equal(st[Field(tab, "TabGlow")].colour[4], 0, "tab " .. i .. ": its animated glow faded by its colour")
    Equal(st[tab].width .. "x" .. st[tab].height, "100x28", "tab " .. i .. ": the spellbook tab's size")
    Equal(st[Piece(Look, tab, "tabLabel")].text, WORDS[i], "tab " .. i .. " says " .. WORDS[i])
    Equal(S(game, Piece(Look, tab, "tabOff")).file, "Interface\\Spellbook\\UI-SpellBook-Tab-Unselected", "tab " .. i .. ": the red-brown tab")
    Equal(st[Piece(Look, tab, "tabGlow")].layer, "HIGHLIGHT", "tab " .. i .. ": the old glow on hover")
end
Equal(Anchor(game, tabs[1]), "TOPLEFT LegacySystemFrame BOTTOMLEFT 14,2", "the tabs along the foot")
Equal(Anchor(game, tabs[2]), "LEFT Frame RIGHT 8,0", "side by side")
Equal(st[tabs[2]].points.LEFT[2], tabs[1], "the second after the first")
Equal(S(game, Piece(Look, tabs[3], "tabOn")).file, "Interface\\Spellbook\\UI-SpellBook-Tab3-Selected", "the third tab's own raised art")
local function Raised(i) return st[Piece(Look, tabs[i], "tabOn")].shown and not st[Piece(Look, tabs[i], "tabOff")].shown end
Equal(Raised(1) and not Raised(2) and not Raised(3), true, "the first page's tab raised")
Errors(game, "the frame")

-- The game's controls: kept with their scripts.
local function Control(list, obj, label) list[#list + 1] = { obj, label } end
local function Snapshot(list)
    for _, entry in ipairs(list) do
        local s = st[entry[1]]
        entry.scripts = {}
        for script, fn in pairs(s.scripts) do entry.scripts[script] = fn end
    end
end

---------------------------------------------------------------------------
-- 3. The Progress Track
---------------------------------------------------------------------------

window:Show()
Equal(rewards:IsVisible(), true, "the Progress Track shows first")
local track = Field(rewards, "LegacyRewardProgressFrame")
local cards = Field(track, "Elements")
Equal(#cards, 4, "four cards")
local PARCHMENT = { left = 7, top = 60, right = 329, bottom = 416 }
local clip = Field(track, "ClipFrame")
Equal(st[track].width .. "x" .. st[track].height, "312x228", "the game's track as the list's box")
Equal(Anchor(game, track), "TOPLEFT LegacySystemFrame TOPLEFT 12,-162", "under the bar and its rule")
Within(game, clip, window, PARCHMENT, "the list (the track's clip frame) on the parchment")
-- Down the page like a quest's rewards, in the game's order, 57 apart.
local function CardsDown(g, look, list, clipFrame, win, label)
    for i, card in ipairs(list) do
        Equal(Anchor(g, card), string.format("CENTER Frame CENTER 0,%g", 88 - (i - 1) * 57), label .. ": card " .. i .. " in its row")
        Equal(g.st[card].points.CENTER[2], clipFrame, label .. ": on the list's own clip frame")
        Equal(g.st[card].width .. "x" .. g.st[card].height, "312x52", label .. ": card " .. i .. " a row's size")
        Within(g, card, win, (function() local l, t, r, f = Box(g, clipFrame, win) return { left = l, top = t, right = r, bottom = f } end)(),
            label .. ": card " .. i .. " inside the list")
        if i > 1 then Apart(g, list[i - 1], card, win, label .. ": cards " .. (i - 1) .. " and " .. i .. " clear of each other") end
    end
end
CardsDown(game, Look, cards, clip, window, "first shown")
for i, card in ipairs(cards) do
    local earned = i <= 2
    for _, key in ipairs({ "RewardCardBG", "LevelSquare", "IconBorder", "EarnedCheckmark" }) do
        Equal(S(game, Field(card, key)).alpha, 0, "card " .. i .. ": the game's " .. key .. " faded")
    end
    local icon, name, level = Field(card, "Icon"), Field(card, "RewardName"), Field(card, "Level")
    Equal(st[icon].width .. " " .. Anchor(game, icon), "40 LEFT Frame LEFT 10,0", "card " .. i .. ": its icon at the left")
    Equal(st[name].width .. " " .. st[name].justify .. " " .. Anchor(game, name), "184 LEFT LEFT Texture RIGHT 14,0",
        "card " .. i .. ": its name beside the icon, read from the left")
    Equal(Anchor(game, level), "CENTER Frame RIGHT -30,0", "card " .. i .. ": its points at the right")
    Apart(game, name, Piece(Look, card, "plate"), window, "card " .. i .. ": the name clear of the plate")
    local socket = Piece(Look, card, "socket")
    Equal(S(game, socket).file, "Interface\\Spellbook\\UI-Spellbook-SpellBackground", "card " .. i .. ": the spellbook's amber slot")
    Equal(st[socket].desaturated, not earned, "card " .. i .. ": the slot greyed until earned")
    Equal(S(game, Piece(Look, card, "ring")).file, "Interface\\Buttons\\UI-Quickslot2", "card " .. i .. ": the old ring")
    Equal(S(game, Piece(Look, card, "plate")).file, "Interface\\TalentFrame\\TalentFrame-RankBorder", "card " .. i .. ": its points on a rank plate")
    Equal(Anchor(game, Piece(Look, card, "plate")), "CENTER FontString CENTER 0,0", "card " .. i .. ": the plate under the game's number")
    Equal(st[Piece(Look, card, "check")].shown, earned, "card " .. i .. ": the old check once earned")
    Colour(st[name].textColour, earned and GOLD or INK, "card " .. i .. ": its name")
end
-- The page shown again: the game hands its cards out again (in another
-- order) and lays them in a row; EraUI lays them down the page again.
game.Run(tabs[2], "OnMouseUp", "LeftButton", true)
game.Run(tabs[1], "OnMouseUp", "LeftButton", true)
cards = Field(track, "Elements")
CardsDown(game, Look, cards, clip, window, "shown again")
Equal(Field(cards[1], "level"), 1, "the first reward first")
Equal(st[Field(cards[1], "RewardName")].shadowColour[4], 1, "an earned name has the black shadow")
Equal(game.dark[Field(cards[3], "RewardName")], "text", "a name not earned yet is page text for Dark Windows")
Colour(st[Field(rewards, "PointsLabel")].textColour, GOLD, "Legacy Points in gold")
-- The Legacy points: the game's retail crown faded, its number in gold in
-- the Legacy Tree's emblem ring on a dark disc, just over "Legacy Points".
local RANK = "Interface\\TalentFrame\\TalentFrame-RankBorder"
local crown, bigPoints, pointsLabel = Field(rewards, "Icon"), Field(rewards, "Points"), Field(rewards, "PointsLabel")
Equal(st[crown].alpha, 0, "the Progress Track's retail crown faded")
Equal(st[crown].atlas, "Legacy-Rewards-Tracker-Icon", "its own art left as it is")
local pointsRing, pointsDisc = Piece(Look, rewards, "pointsRing"), Piece(Look, rewards, "pointsDisc")
local treeRing = Piece(Look, Field(Field(tree, "LegacyTreeTraitPanel"), "SelectedTreeIcon"), "ring")
Equal(S(game, pointsRing).file, "Interface\\Spellbook\\ProfessionsBook", "the points in the professions book's ring")
Equal(Coords(game, pointsRing), Coords(game, treeRing), "cut as the Legacy Tree's emblem ring")
Equal(st[pointsRing].width .. "x" .. st[pointsRing].height, "84x84", "the big ring at the top left of the page")
Equal(st[pointsRing].shown and st[pointsDisc].shown, true, "ring and disc shown")
Equal(Anchor(game, pointsRing), "CENTER LegacySystemFrame TOPLEFT 56,-106", "at the parchment's top left")
Within(game, pointsRing, window, PARCHMENT, "the ring on the parchment")
Equal(game.dark[pointsRing], "trim", "the ring handed to Dark Windows as trim, as the tree's")
Equal(S(game, pointsDisc).file, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "on a disc")
Colour(st[pointsDisc].colour, L.DISC, "as dark as the crest's")
Equal(Anchor(game, pointsDisc), "CENTER LegacySystemFrame TOPLEFT 56,-106", "inside the ring")
Equal(st[pointsDisc].layer .. st[pointsDisc].sublevel .. " " .. st[pointsRing].layer .. st[pointsRing].sublevel, "BORDER0 BORDER1",
    "the disc under the ring, both under the number (ARTWORK)")
Equal(Anchor(game, bigPoints), "CENTER LegacySystemFrame TOPLEFT 56,-106", "the game's own number in the ring's middle")
Equal(st[bigPoints].text, "16", "the game's points")
Colour(st[bigPoints].textColour, GOLD, "in gold")
Equal(st[bigPoints].font, game.env.Game32Font_Shadow2, "in the game's own big font (the text the same size)")
Equal(st[bigPoints].alpha, 1, "the number itself shows")
Equal(Anchor(game, pointsLabel), "LEFT LegacySystemFrame TOPLEFT 108,-88", "Legacy Points beside the ring")
local bar = Field(rewards, "LegacyRewardProgressBar")
local backing = Field(rewards, "ProgressBarBackground")
Equal(st[backing].width .. "x" .. st[backing].height .. " " .. Anchor(game, backing), "206x12 LEFT LegacySystemFrame TOPLEFT 110,-118",
    "the bar shorter, under Legacy Points")
Within(game, bar, window, { left = 105, top = 60, right = 324, bottom = 156 }, "the bar (and its rim, 5 out) between the ring and the rule")
Apart(game, bar, pointsRing, window, "the bar clear of the ring")
Equal(st[bar:GetStatusBarTexture()].file, Look.MEDIA .. "UI-Character-Skills-Bar", "the bar's old skill bar fill")
Colour(st[bar].barColour, L.PURPLE, "in the Legacy purple")
Equal(st[Field(bar, "ProgressBarFrame")].alpha, 0, "its modern frame faded")
Equal(S(game, Piece(Look, bar, "rimmiddle")).file, Look.MEDIA .. "UI-Character-Skills-BarBorder", "in the skill bar's rim")
Equal(st[backing].alpha, 0, "its modern backing faded")
Equal(st[Piece(Look, rewards, "rule")].shown, true, "a thin rule over the list")
Equal(Anchor(game, Piece(Look, rewards, "rule"), "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 16,-156", "between the top and the list")
local nextArrow = Field(track, "RightButton")
Equal(st[nextArrow:GetNormalTexture()].file, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "the track's arrows are the spellbook's")
Equal(Coords(game, nextArrow:GetNormalTexture()), "0,1,0,1", "the game's mirror on the right arrow taken off")
Equal(st[Field(track, "LeftButton"):GetNormalTexture()].file, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", "and the left one")
Equal(Anchor(game, Field(track, "LeftButton")) .. " / " .. Anchor(game, nextArrow),
    "CENTER LegacySystemFrame TOPLEFT 140,-403 / CENTER LegacySystemFrame TOPLEFT 196,-403", "the arrows at the parchment's foot")
for _, key in ipairs({ "LeftButton", "RightButton", "JumpLeftButton", "JumpRightButton" }) do
    Within(game, Field(track, key), window, PARCHMENT, "the " .. key .. " on the parchment")
    Apart(game, Field(track, key), clip, window, "the " .. key .. " under the list")
end
Equal(st[nextArrow].shown, false, "four rewards fit: the game shows no arrows")
-- The game refreshes the track (more earned): painted again at once.
game.renown = 3
rewards:OnTrackUpdate()
Colour(st[Field(cards[3], "RewardName")].textColour, GOLD, "a card earned since: gold after the game's refresh")
Colour(st[Field(cards[4], "RewardName")].textColour, INK, "one not earned: the game's grey painted over in ink again")
Equal(st[Piece(Look, cards[3], "check")].shown, true, "with its check")
CardsDown(game, Look, cards, clip, window, "after the game's refresh")
Equal(game.cardTips, nil, "no hover yet")
game.Run(cards[2], "OnEnter")
Equal(game.cardTips, 1, "hovering a reward still shows the game's tooltip")
Errors(game, "the Progress Track")

-- More rewards than fit: the game's track scrolls and shows its arrows; the
-- list shows four from the one before the game's chosen one, the others
-- out of the list (clipped away), and the game's arrows page it.
do
    local g, look = Session()
    g.rewardLevels = { 1, 2, 3, 4, 5, 6 }
    local w = g.LoadAddOn()
    w:Show()
    local page = Field(w, "RewardTrackPage")
    local t = Field(page, "LegacyRewardProgressFrame")
    local c = Field(t, "ClipFrame")
    local function Seen()
        local shown = {}
        local cl, ct, cr, cf = Box(g, c, w)
        for i, card in ipairs(Field(t, "Elements")) do
            local l, top, r, f = Box(g, card, w)
            if l >= cl - 0.01 and r <= cr + 0.01 and top >= ct - 0.01 and f <= cf + 0.01 then
                table.insert(shown, i)
            else
                Equal(l >= cr, true, "a card not in the four is right of the list (clipped away)")
            end
        end
        return table.concat(shown, ",")
    end
    Equal(g.st[Field(t, "RightButton")].shown, true, "six rewards: the game shows its arrows")
    Equal(Seen(), "1,2,3,4", "the first four shown first")
    g.Run(Field(t, "RightButton"), "OnClick", "LeftButton")
    g.Run(Field(t, "RightButton"), "OnClick", "LeftButton")
    g.Run(Field(t, "RightButton"), "OnClick", "LeftButton")
    Equal(Field(t, "selectedIndex"), 4, "the game's arrow chose the fourth")
    Equal(Seen(), "3,4,5,6", "the list follows the game's choice")
    g.Run(Field(t, "LeftButton"), "OnClick", "LeftButton")
    g.Run(Field(t, "LeftButton"), "OnClick", "LeftButton")
    Equal(Seen(), "1,2,3,4", "and back")
    -- In a fight too: the game's arrows page it, and the game choosing the
    -- card it already has (its jump arrows can) moves its first card without
    -- refreshing the track; the list stays.
    g.combat = true
    g.Run(Field(t, "RightButton"), "OnClick", "LeftButton")
    Equal(Field(t, "selectedIndex"), 3, "in a fight: the game's arrow chose the third")
    Equal(Seen(), "2,3,4,5", "in a fight: the list follows the game's arrows")
    t:SetSelection(Field(t, "selectedIndex"))
    Equal(Seen(), "2,3,4,5", "in a fight: the game choosing the same card again leaves the list as it is")
    g.combat = false
    Errors(g, "a scrolling track")
end

---------------------------------------------------------------------------
-- 4. The Challenges
---------------------------------------------------------------------------

game.Run(tabs[2], "OnMouseUp", "LeftButton", true)
Equal(challenges:IsVisible() and not rewards:IsVisible(), true, "the second tab shows the Challenges (the game's own click)")
Equal(Raised(2) and not Raised(1), true, "its tab raised, the first lowered")
Equal(st[Field(titles, "TitleText")].text, "Legacy Challenges", "the game's title")
local list = Field(challenges, "CategoryList")
local rows = Field(Field(list, "ScrollBox"), "frames")
Equal(#rows, 4, "four category rows")
local function RowText(i) return st[Field(rows[i], "ButtonText")] end
for i, row in ipairs(rows) do
    Equal(st[row:GetNormalTexture()].alpha, 0, "row " .. i .. ": its card art faded")
    Equal(st[row:GetHighlightTexture()].alpha, 0, "row " .. i .. ": its glow faded")
    Equal(st[row].normalFont, game.env.GameFontNormal, "row " .. i .. ": the quest log's font")
    Equal(Anchor(game, Field(row, "ButtonText"), "LEFT"), "LEFT Button LEFT 22,0", "row " .. i .. ": text after the plus and minus")
    Equal(Anchor(game, Field(row, "CollapseButton")), "LEFT Button LEFT 2,0", "row " .. i .. ": the plus and minus at the left")
    Equal(Anchor(game, Field(row, "NotificationIcon")), "RIGHT Button RIGHT -6,0", "row " .. i .. ": the unviewed mark at the right")
    Equal(S(game, Piece(Look, row, "glow")).file, "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "row " .. i .. ": the quest log's hover bar")
end
Colour(RowText(1).textColour, GOLD, "a header in gold")
Equal(RowText(1).shadowColour[4], 1, "with the black shadow")
Colour(RowText(2).textColour, INK, "a category in brown ink")
Equal(RowText(2).shadowColour[4], 0, "with no shadow")
Colour(RowText(3).textColour, GOLD, "the picked category in gold")
Equal(st[Piece(Look, rows[3], "pick")].shown and not st[Piece(Look, rows[2], "pick")].shown, true, "on the highlight bar")
Equal(st[Field(Field(rows[1], "CollapseButton"), "Icon")].file, "Interface\\Buttons\\UI-MinusButton-Up", "an open header's old minus")
Equal(st[Field(Field(rows[4], "CollapseButton"), "Icon")].file, "Interface\\Buttons\\UI-PlusButton-Up", "a folded header's old plus")
-- The game's own hover colour and fold: painted again.
rows[2]:CheckHighlightTitle()
Colour(RowText(2).textColour, INK, "after the game's hover colour: brown again")
Field(rows[4], "CollapseButton"):UpdateCollapsedState(false)
Equal(st[Field(Field(rows[4], "CollapseButton"), "Icon")].file, "Interface\\Buttons\\UI-MinusButton-Up", "unfolded: the old minus")
Equal(st[Field(Field(rows[4], "CollapseButton"), "Icon")].width, 14, "at the old size")
local filter = Field(list, "FilterDropdown")
Equal(st[Field(filter, "Background")].alpha, 0, "the filter's modern art faded")
Equal(Look.OwnPiece(filter, "dropLeft") ~= nil, true, "in the old label frame")
Equal(Look.OwnPiece(Field(list, "ScrollBar").Back, "arrowArt") ~= nil, true, "the list's 1.x scroll arrows")
Equal(Look.OwnPiece(Field(list, "ScrollBar"), "tracktop") ~= nil, true, "its stone column")
local summary = Field(challenges, "LegacyChallengePointSummary")
Equal(st[Field(summary, "ProgressBarBackground")].alpha, 0, "the points bar's backing faded")
Colour(st[Field(summary, "PointsBar")].barColour, L.PURPLE, "the points bar as the old skill bar")
-- Where everything is: the bar in the stone band under the title, the list
-- on the parchment's top part, a rule, the challenges under it.
Equal(st[summary].width .. "x" .. st[summary].height .. " " .. Anchor(game, summary), "206x36 TOPLEFT LegacySystemFrame TOPLEFT 110,-18",
    "the points summary in the band")
do
    local l, t, r, f = Box(game, Field(summary, "PointsBar"), window)
    Near((t + f) / 2 + 1.5, 39, "the bar's middle on the band's (its skill bar rim round it)")
    Equal(l >= 100 and r <= 330, true, "the bar right of the ring, inside the frame")
end
Within(game, Field(summary, "PointsBar"), window, { left = 70, top = 21, right = 336, bottom = 58 }, "the bar in the band")
Equal(Anchor(game, list, "TOPLEFT") .. " / " .. Anchor(game, list, "BOTTOMRIGHT"),
    "TOPLEFT LegacySystemFrame TOPLEFT 8,-62 / BOTTOMRIGHT LegacySystemFrame TOPRIGHT -8,-212", "the categories on the top part")
Within(game, list, window, PARCHMENT, "the category list on the parchment")
for key, label in pairs({ SearchBox = "the search", FilterDropdown = "the filter", ScrollBox = "the rows", ScrollBar = "the rows' scroll bar" }) do
    Within(game, Field(list, key), window, PARCHMENT, label .. " on the parchment")
    Within(game, Field(list, key), window, { left = 8, top = 62, right = 328, bottom = 212 }, label .. " in the list's part")
end
Apart(game, Field(list, "SearchBox"), Field(list, "FilterDropdown"), window, "the search and the filter side by side")
for i, row in ipairs(rows) do
    Near(row:GetWidth(), Field(list, "ScrollBox"):GetWidth(), "row " .. i .. ": as wide as its box (the game's scroll box)")
end
Equal(st[Piece(Look, challenges, "rule")].shown, true, "a thin rule between the two parts")
Equal(Anchor(game, Piece(Look, challenges, "rule"), "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 16,-216", "under the list")
for _, piece in ipairs(st[Field(challenges, "VerticalDivider")].regions) do
    Equal(st[piece].alpha, 0, "the game's divider down the middle faded")
end
local pane = Field(challenges, "DetailPane")
Equal(Anchor(game, pane, "TOPLEFT") .. " / " .. Anchor(game, pane, "BOTTOMRIGHT"),
    "TOPLEFT LegacySystemFrame TOPLEFT 8,-220 / BOTTOMRIGHT LegacySystemFrame BOTTOMRIGHT -30,8", "the challenges under the rule")
Within(game, pane, window, PARCHMENT, "the challenges on the parchment")
Within(game, Field(pane, "ScrollBar"), window, PARCHMENT, "their scroll bar on the parchment")
Within(game, Field(pane, "ScrollBar"), window, { left = 8, top = 220, right = 329, bottom = 416 }, "under the rule")
-- The header's crown: faded, the points on the Progress Track's rank plate
-- left of the bar, the game's own number on it.
local headerShield = Field(summary, "Shield")
local headerPoints = Field(headerShield, "Points")
local function HeaderPlate(shield, relativeKind, x, label)
    local plate = Piece(Look, shield, "plate")
    local number = Field(shield, "Points")
    Equal(st[Field(shield, "Icon")].alpha, 0, label .. ": the retail crown faded")
    Equal(S(game, plate).file, RANK, label .. ": the points on a rank plate")
    Equal(st[plate].width .. "x" .. st[plate].height, "44x36", label .. ": the Progress Track's plate size")
    Equal(st[plate].shown, true, label .. ": the plate shown")
    Equal(Anchor(game, plate), "CENTER " .. relativeKind .. " LEFT " .. x .. ",0", label .. ": where the crown sat, clear of what it heads")
    Equal(Anchor(game, number), "CENTER " .. relativeKind .. " LEFT " .. x .. ",0", label .. ": the game's own number on it")
    Equal(st[number].font, game.env.GameFontHighlight, label .. ": in the 15 / 25 / 40 / 55's size")
    Colour(st[number].textColour, { 1, 1, 1 }, label .. ": white, as the game has it")
    Equal(st[number].alpha, 1, label .. ": the number itself shows")
    Equal(st[shield].alpha .. " " .. st[shield].width .. "x" .. st[shield].height, "1 46x64", label .. ": the crown's button left as it is")
end
HeaderPlate(headerShield, "StatusBar", -20, "the Challenges header")
Equal(st[Piece(Look, headerShield, "plate")].points.CENTER[2], Field(summary, "PointsBar"), "left of the points bar itself")
Equal(st[headerPoints].text, "16", "the game's points")

local challengeCards = Field(Field(pane, "ScrollBox"), "frames")
local done, open = challengeCards[1], challengeCards[2]
for i, card in ipairs(challengeCards) do
    for _, key in ipairs({ "Background", "BackgroundTop", "BackgroundMiddle", "BackgroundBottom", "SelectedOverlay", "TitleBar", "PlusMinus" }) do
        Equal(st[Field(card, key)].alpha, 0, "challenge " .. i .. ": the game's " .. key .. " faded")
    end
    Equal(st[Field(Field(card, "Icon"), "frame")].alpha, 0, "challenge " .. i .. ": its icon frame faded")
    Equal(S(game, Piece(Look, Field(card, "Icon"), "socket")).file, "Interface\\Spellbook\\UI-Spellbook-SpellBackground", "challenge " .. i .. ": the icon in the slot")
    Colour(st[Field(card, "Description")].textColour, INK, "challenge " .. i .. ": its text in brown ink")
    Equal(st[Piece(Look, card, "rule")].shown, true, "challenge " .. i .. ": a rule under it")
    -- Laid out in the narrower card: as wide as the game's box, its text
    -- narrowed to it (the same font), its points plate under the icon.
    Near(card:GetWidth(), 294, "challenge " .. i .. ": as wide as the game's box")
    local cardArea = (function() local l, t, r, f = Box(game, card, window) return { left = l, top = t, right = r, bottom = f } end)()
    for _, key in ipairs({ "Description", "HiddenDescription" }) do
        Equal(st[Field(card, key)].width, 182, "challenge " .. i .. ": its " .. key .. " narrowed to the card")
        Within(game, Field(card, key), window, cardArea, "challenge " .. i .. ": its " .. key .. " inside the card")
    end
    Equal(st[Field(card, "Label")].width, 211, "challenge " .. i .. ": its name kept to the card (the game makes it 320)")
    Within(game, Field(card, "Label"), window, cardArea, "challenge " .. i .. ": its name inside the card")
    Within(game, Field(card, "Shield"), window, cardArea, "challenge " .. i .. ": its points inside the card")
    Apart(game, Field(card, "Shield"), Field(card, "Description"), window, "challenge " .. i .. ": its points clear of its text")
    Apart(game, Field(card, "Shield"), Field(card, "Label"), window, "challenge " .. i .. ": and of its name")
end
-- Each challenge's points: the game's crown and number faded, the crown's
-- button (its tooltip) the plate's size under the icon, EraUI's rank plate
-- on it, EraUI's number on that copied from the game's. worth: the points
-- the game shows on it (0: none).
local function ChallengePoints(g, look, card, worth, label)
    local shield = Field(card, "Shield")
    local plate, mirror = Piece(look, shield, "plate"), Piece(look, shield, "points")
    Equal(g.st[Field(shield, "Icon")].alpha, 0, label .. ": the retail crown faded")
    Equal(g.st[Field(shield, "Points")].alpha, 0, label .. ": the game's own number faded (its font is set again each time)")
    Equal(g.st[plate].shown, worth > 0, label .. ": a rank plate while it has points")
    Equal(g.st[mirror].shown, worth > 0, label .. ": EraUI's number with it")
    if worth > 0 then Equal(g.st[mirror].text, tostring(worth), label .. ": the game's number") end
    Equal(g.st[shield].width .. "x" .. g.st[shield].height .. " " .. Anchor(g, shield), "40x32 CENTER Texture BOTTOM 0,-6",
        label .. ": the crown's button the plate's size, under the icon")
    Equal(g.st[shield].points.CENTER[2], Field(Field(card, "Icon"), "texture"), label .. ": the icon itself")
    Equal(Anchor(g, plate), "CENTER Button CENTER 0,0", label .. ": the plate on it")
    Equal(Anchor(g, mirror), "CENTER Texture CENTER 0,0", label .. ": the number on the plate")
    Equal(g.st[plate].width .. "x" .. g.st[plate].height .. " " .. g.st[mirror].font, "40x32 GameFontHighlight",
        label .. ": the plate's size, the 15 / 25 / 40 / 55's number size")
    Equal(Anchor(g, Piece(look, shield, "check")), "CENTER Texture TOPRIGHT 0,0", label .. ": the old check at the slot's corner")
end
ChallengePoints(game, Look, done, 1, "the done challenge")
ChallengePoints(game, Look, open, 3, "the other")
Equal(S(game, Piece(Look, Field(done, "Shield"), "plate")).file, RANK, "the talent window's rank plate")
Colour(st[Field(done, "Label")].textColour, GOLD, "a done challenge's name in gold")
Colour(st[Field(open, "Label")].textColour, INK, "one not done yet in brown ink (dim gold read poorly on the parchment)")
Equal(st[Field(open, "Label")].shadowColour[4], 0, "with no shadow, as ink")
Equal(st[Piece(Look, Field(done, "Shield"), "check")].shown, true, "the old check on a done one")
Equal(st[Piece(Look, Field(open, "Shield"), "check")].shown, false, "not on the other")
-- A done challenge's date (the game's, beside the crown's check, which moved
-- under the icon with its button): at the card's top right where the game
-- shows it, in ink, clear of the icon, the points, the name and the text.
do
    local date = Field(Field(done, "Shield"), "DateCompleted")
    Equal(st[date].shown and st[date].text, "10/21/26", "a done challenge's date shown (the game's words)")
    Equal(st[Field(Field(open, "Shield"), "DateCompleted")].shown, false, "none on one not done")
    Equal(Anchor(game, date), "TOPRIGHT EventButton TOPRIGHT -10,-8", "its date at the card's top right")
    local l, t, r, f = Box(game, done, window)
    Within(game, date, window, { left = l, top = t, right = r, bottom = f }, "the date inside its card")
    for key, label in pairs({ Label = "its name", Description = "its text", Shield = "its points" }) do
        Apart(game, date, Field(done, key), window, "the date clear of " .. label)
    end
    Apart(game, date, Field(Field(done, "Icon"), "texture"), window, "the date clear of its icon")
    Colour(st[date].textColour, INK, "the date in brown ink")
end
Equal(st[Piece(Look, open, "sign")].shown and S(game, Piece(Look, open, "sign")).file, "Interface\\Buttons\\UI-PlusButton-Up", "the old plus on one with objectives")
Equal(st[Piece(Look, done, "sign")].shown, false, "none without")
-- The game's own click opens it: picked, its objectives shown.
game.Run(open, "OnClick", "LeftButton")
Equal(st[Piece(Look, open, "pick")].shown, true, "the picked challenge on the highlight bar")
Colour(st[Field(open, "Label")].textColour, GOLD, "its name gold")
Equal(S(game, Piece(Look, open, "sign")).file, "Interface\\Buttons\\UI-MinusButton-Up", "the old minus when open")
local objectives = {}
for row in game.env.LegacyChallengeObjectives.criteriaPool:EnumerateActive() do objectives[#objectives + 1] = row end
Equal(#objectives, 2, "two objectives")
for _, row in ipairs(objectives) do
    local doneRow = st[Field(row, "Check")].shown
    Equal(st[Field(row, "Background")].alpha, 0, "an objective's bar art faded")
    Equal(st[Piece(Look, row, "check")].shown, doneRow, "the old check on a done objective")
    Colour(st[Field(row, "Name")].textColour, doneRow and INK or GREY_INK, "its words in ink (the quest log's grey while not done)")
    Colour(st[Field(row, "ProgressBar")].barColour, L.GREEN_BAR, "its bar as the old skill bar")
end
ChallengePoints(game, Look, open, 3, "opened by the game's click")
-- The Legacy points change (a challenge done): the game sets its numbers
-- again through its own callbacks; they stay on the plate and in the ring.
game.SetPoints(17)
Equal(st[headerPoints].text, "17", "the header's points the game's new ones")
HeaderPlate(headerShield, "StatusBar", -20, "the Challenges header after the change")
Equal(st[bigPoints].text, "17", "the Progress Track's too")
Colour(st[bigPoints].textColour, GOLD, "still gold")
Equal(Anchor(game, bigPoints), "CENTER LegacySystemFrame TOPLEFT 56,-106", "still in the ring")
-- The game hands its challenge cards out again with other points (one
-- worth none): EraUI's numbers follow the card each one is now.
game.challenges[1].points, game.challenges[2].points = 0, 5
pane:GenerateDataProvider()
for i, card in ipairs(Field(Field(pane, "ScrollBox"), "frames")) do
    local worth = game.challenges[Field(card, "id")].points
    ChallengePoints(game, Look, card, worth, "handed out again, challenge " .. i)
end
game.challenges[1].points, game.challenges[2].points = 1, 3
pane:GenerateDataProvider()
ChallengePoints(game, Look, Field(Field(pane, "ScrollBox"), "frames")[1], 1, "and back")
Errors(game, "the Challenges")

---------------------------------------------------------------------------
-- 4b. The Challenges page as EraUI draws it (no gamepad): one quest-log
-- list and the chosen challenge's details, from the game's data
---------------------------------------------------------------------------

-- A list's items as the mock's reference has them: "C<category>", "A<id>".
local function Keys(items)
    local out = {}
    for _, item in ipairs(items) do out[#out + 1] = item.head and ("C" .. item.head.id) or ("A" .. item.entry.id) end
    return table.concat(out, " ")
end
-- Every category of the list's tree.
local function EachNode(nodes, fn)
    for _, node in ipairs(nodes or {}) do
        fn(node)
        EachNode(node.kids, fn)
    end
end
-- The row of EraUI's list showing a challenge, or a category's header, in
-- the rows now (nil: not in them).
local function RowNow(C, id, header)
    local first = math.floor((C.listBar:GetValue() or 0) + 0.5)
    for i, slot in ipairs(C.slots) do
        local item = C.items[first + i]
        local shown = item and (header and item.head or (not header and item.entry))
        if shown and shown.id == id and slot:IsShown() then return slot end
    end
    return nil
end
-- The same, the list scrolled to it first when it is listed but not in the
-- rows now (8 rows show; nil: not listed at all).
local function RowOf(C, id, header)
    local found = RowNow(C, id, header)
    if found then return found end
    for place, item in ipairs(C.items) do
        local shown = header and item.head or (not header and item.entry)
        if shown and shown.id == id then
            C.listBar:SetValue(place - 1)
            return RowNow(C, id, header)
        end
    end
    return nil
end
local function HeadRow(C, id) return RowOf(C, id, true) end
-- A challenge of the mock's by its name.
local function IdOf(g, name)
    for id, a in pairs(g.achs) do
        if a.name == name then return id end
    end
end
local function Overlap(g, a, b, win)
    local al, at, ar, af = Box(g, a, win)
    local bl, bt, br, bf = Box(g, b, win)
    return al < br - 0.01 and bl < ar - 0.01 and at < bf - 0.01 and bt < af - 0.01
end

do
    local g, look = Session()
    local LC = look.Legacy
    local C, D = LC.ChallengeList, LC.ChallengeData
    local w = g.LoadAddOn()
    w:Show()
    local tabsC = Field(w, "Tabs")
    g.Run(tabsC[2], "OnMouseUp", "LeftButton", true)
    local page = Field(w, "ChallengesPage")
    local list, pane = Field(page, "CategoryList"), Field(page, "DetailPane")
    local box, boxBar = Field(list, "ScrollBox"), Field(list, "ScrollBar")
    local PARCH = { left = 7, top = 60, right = 329, bottom = 416 }
    Equal(page:IsVisible() and C.mode, "own", "no gamepad: the Challenges page is EraUI's own")
    Equal(g.st[C.holder].shown, true, "its list and details shown")
    -- The game's search results come a frame after the page shows; until
    -- then nothing is listed and nothing says there is nothing.
    Equal(#C.items .. " " .. tostring(g.st[C.empty].shown), "0 false", "waiting for the game's search results: an empty list, no words")
    g.NextFrame()
    Equal(#C.items > 0, true, "the game's results in: listed")

    -- Where everything is.
    Equal(Anchor(g, list, "TOPLEFT") .. " / " .. Anchor(g, list, "BOTTOMRIGHT"),
        "TOPLEFT LegacySystemFrame TOPLEFT 8,-62 / BOTTOMRIGHT LegacySystemFrame TOPRIGHT -8,-92",
        "the game's list frame narrowed to the strip its search and filter sit in")
    for key, label in pairs({ SearchBox = "the game's search", FilterDropdown = "the game's filter" }) do
        local piece = Field(list, key)
        Equal(g.st[piece].alpha .. " " .. tostring(g.Visible(piece)), "1 true", label .. " shows")
        Within(g, piece, w, { left = 7, top = 60, right = 329, bottom = 96 }, label .. " in the strip at the parchment's top")
        Apart(g, piece, C.area, w, label .. " clear of EraUI's list")
    end
    Equal(g.st[list].alpha, 1, "the list frame itself keeps its alpha (its search and filter show)")
    Equal(g.st[box].alpha .. "/" .. g.st[boxBar].alpha .. "/" .. g.st[pane].alpha, "0/0/0",
        "the game's rows, their scroll bar and its challenge cards faded")
    for _, piece in ipairs({ box, boxBar, pane }) do
        local l, _, r = Box(g, piece, w)
        Equal(r < -2000, true, "parked far left of the window, out of sight and out of reach")
    end
    do
        local l, t, r, f = Box(g, box, w)
        Equal(string.format("%gx%g", r - l, f - t), "292x110", "the game's rows parked at the size the dressed page gives them")
        l, t, r, f = Box(g, pane, w)
        Equal(string.format("%gx%g", r - l, f - t), "298x194", "the cards too")
    end
    Equal(string.format("%d rows %dx%d", #C.slots, g.st[C.slots[1]].width, g.st[C.slots[1]].height), "8 rows 284x16",
        "eight 16-tall rows at once (fewer than the first build's 12: room for the details)")
    do
        local l, t, r, f = Box(g, C.area, w)
        Equal(string.format("%g,%g to %g,%g", l, t, r, f), "12,98 to 296,226", "the list on the parchment's upper part")
        Equal((f - t) / 16, 8, "room for exactly its eight rows")
        l, t, r, f = Box(g, C.detail, w)
        Equal(string.format("%g,%g to %g,%g", l, t, r, f), "12,234 to 296,404", "the details under it, 170 tall")
        Equal(f <= PARCH.bottom - look.Legacy.EDGE, true, "the details end above the parchment's burnt rim")
    end
    Equal(g.st[C.area].clips, true, "the list clips its rows")
    Equal(g.st[C.area].wheel and g.st[C.detail].wheel, true, "both take the mouse wheel")
    Equal(Anchor(g, Piece(look, page, "rule"), "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 16,-230", "the rule between them")
    for _, bar in ipairs({ C.listBar, C.detailBar }) do
        local _, down = look.ScrollArrows(bar)
        local _, _, _, f = Box(g, down, w)
        Equal(f <= PARCH.bottom - look.Legacy.EDGE, true, "a scroll bar's down arrow above the burnt rim")
    end
    for _, part in ipairs({ C.area, C.detail, C.listBar, C.detailBar }) do Within(g, part, w, PARCH, "on the parchment") end
    Within(g, (look.ScrollArrows(C.listBar)), w, PARCH, "the list bar's arrows on the parchment")
    Apart(g, look.OwnPiece(C.listBar, "columntop"), Field(list, "FilterDropdown"), w, "the list bar's stone column clear of the game's filter")
    Apart(g, look.OwnPiece(C.listBar, "columntop"), Field(list, "SearchBox"), w, "and of its search")
    -- Nothing of the game's that takes the mouse lies under EraUI's list or
    -- details (shown or faded).
    local under = 0
    for _, obj in ipairs(g.FindAll(function(s) return s.game and s.mouse == true and s.kind ~= "Texture" end)) do
        if g.Visible(obj) and g.Rect(obj) then
            if Overlap(g, obj, C.area, w) or Overlap(g, obj, C.detail, w) then under = under + 1 end
        end
    end
    Equal(under, 0, "nothing of the game's taking the mouse under EraUI's list or details")
    Errors(g, "EraUI's Challenges page: its places")

    -- The list: the categories as headers (only the way to the player's
    -- class's category open, as the game opens it), the challenges under.
    local function Expect(names, label)
        local out = {}
        for _, item in ipairs(C.items) do out[#out + 1] = item.head and item.head.name or item.entry.name end
        Equal(table.concat(out, ", "), names, label)
    end
    Expect("Classes, Druid, Hunter, Mage, Paladin, Priest, Novice Priest, Experienced Priest, Master Priest, Rogue, Shaman, "
        .. "Warlock, Warrior, Tradeskills, Player vs. Player, Adventure, Dungeons, Raids",
        "the categories in the game's order, the priest's open (done ones first), the empty ones left out")
    local function Row(i) return C.slots[i] end
    local function Words(i) return g.st[Piece(look, Row(i), "words")] end
    Equal(Words(1).text .. " / " .. Words(2).text .. " / " .. Words(7).text, "Classes / Druid / Novice Priest", "rows show them in order")
    Colour(Words(1).textColour, GOLD, "a top header in gold")
    Equal(Words(1).shadowColour[4], 1, "with the black shadow")
    Colour(Words(2).textColour, INK, "a category under it in brown ink")
    Equal(Words(2).shadowColour[4], 0, "with none")
    Colour(Words(7).textColour, GOLD, "a done challenge gold")
    Colour(Words(8).textColour, INK, "one done by another character is not done here: brown ink")
    Colour(g.st[Piece(look, Row(2), "count")].textColour, GREY_INK, "a header's count in the quest log's grey (it was near the parchment's own colour)")
    Equal(g.st[Piece(look, Row(2), "count")].shadowColour[4], 0, "with no shadow")
    Equal(g.st[Piece(look, Row(1), "fold")].file .. " " .. g.st[Piece(look, Row(2), "fold")].file,
        "Interface\\Buttons\\UI-MinusButton-Up Interface\\Buttons\\UI-PlusButton-Up", "the old minus open, plus folded")
    Equal(Anchor(g, Piece(look, Row(1), "fold")) .. " / " .. Anchor(g, Piece(look, Row(2), "fold")) .. " / " .. Anchor(g, Piece(look, Row(7), "backing")),
        "LEFT Button LEFT 2,0 / LEFT Button LEFT 16,0 / LEFT Button LEFT 32,0", "each level further in")
    Equal(g.st[Piece(look, Row(1), "count")].text .. " " .. g.st[Piece(look, Row(6), "count")].text, "2 / 27 1 / 3",
        "a header's done ones out of the challenges under it")
    Equal(g.st[Piece(look, Row(7), "face")].file, "Interface\\Icons\\Ach_" .. g.PriestNovice, "a challenge's own icon")
    Equal(g.st[Piece(look, Row(7), "face")].width, 14, "small")
    Equal(g.st[Piece(look, Row(7), "backing")].shown and g.st[Piece(look, Row(1), "backing")].shown == false, true, "on a dark square; none on a header")
    Equal(g.st[Piece(look, Row(8), "face")].desaturated, true, "not done: its icon grey")
    Equal(g.st[Piece(look, Row(7), "plate")].file, "Interface\\TalentFrame\\TalentFrame-RankBorder", "its points on a rank plate")
    Equal(g.st[Piece(look, Row(7), "points")].text .. " " .. Anchor(g, Piece(look, Row(7), "plate")), "1 CENTER Button RIGHT -16,0",
        "the game's points at the row's right")
    Equal(g.st[Piece(look, Row(1), "plate")].shown, false, "no plate on a header")
    Equal(C.sel, g.PriestNovice, "the first challenge showing is chosen")
    Equal(g.st[Piece(look, Row(7), "pick")].shown and not g.st[Piece(look, Row(8), "pick")].shown, true, "on the quest log's highlight bar")
    Equal(g.st[Piece(look, Row(7), "pick")].file, "Interface\\QuestFrame\\UI-QuestLogTitleHighlight", "the quest log's own bar")
    Equal(g.st[Piece(look, Row(7), "glow")].layer, "HIGHLIGHT", "and the same bar on hover")
    Equal(g.st[C.listBar].max, 10, "18 items, 8 rows: the bar scrolls by 10")
    Equal(g.st[C.slots[1]].mouse, true, "EraUI's own rows take the mouse")
    -- The ninth item (one not done), below the eight rows: scrolled to.
    Colour(g.st[Piece(look, RowOf(C, g.PriestMaster), "words")].textColour, INK, "one not done brown ink")
    C.listBar:SetValue(0)

    -- The same results as the game's own page, everything open: the filter
    -- and the search followed exactly.
    local function AllOpen()
        EachNode(C.roots, function(node) C.folded[node.id] = false end)
        C.Refresh()
    end
    AllOpen()
    Equal(Keys(C.items), table.concat(g.Reference(), " "), "everything open: the game's categories and challenges, in its order")
    Equal(#C.items, 19 + 47, "every category the game lists (19, the two empty ones left out) and every challenge (47)")
    g.SetFilter("Completed", false)
    Equal(Keys(C.items), table.concat(g.Reference(), " "), "done ones hidden by the game's filter: the game's list")
    Equal(C.byId[g.PriestNovice], nil, "a done one gone")
    Equal(C.byId[g.PriestExperienced], nil, "one done by another character too (the game's range skips every done one)")
    Equal(C.byId[g.PriestMaster] ~= nil, true, "an unfinished one stays")
    g.SetFilter("Completed", true)
    g.SetFilter("Incomplete", false)
    Equal(Keys(C.items), table.concat(g.Reference(), " "), "unfinished ones hidden: the game's list")
    Equal(C.byId[g.PriestExperienced], nil, "one done by another character counts as unfinished")
    Equal(C.byId[g.zulGurub] ~= nil and C.byId[g.honor] == nil, true, "done ones only")
    g.SetFilter("Completed", false)
    Equal(#C.items .. " " .. tostring(g.st[C.empty].shown), "0 true", "both boxes off: nothing, and the game's words saying so")
    Equal(g.st[C.empty].text, "No challenges found", "the game's own words")
    g.SetFilter("Completed", true)
    g.SetFilter("Incomplete", true)
    local search = Field(list, "SearchBox")
    local everything = Keys(C.items)
    search:SetText("priest")
    Equal(Keys(C.items), everything, "typed: the list waits for the game's results (a frame later)")
    g.NextFrame()
    Equal(Keys(C.items), table.concat(g.Reference(), " "), "searched: the game's results")
    Expect("Classes, Priest, Novice Priest, Experienced Priest, Master Priest", "only the priest's challenges")
    search:SetText("victor")
    g.NextFrame()
    Equal(Keys(C.items), table.concat(g.Reference(), " "), "another search: the game's results")
    Expect("Player vs. Player, Battlegrounds, Warsong Victor, Arathi Victor", "every header open while searching")
    search:SetText("nothing like it")
    g.NextFrame()
    Equal(#C.items .. " " .. tostring(g.st[C.empty].shown), "0 true", "nothing found: the game's words")
    search:SetText("")
    g.NextFrame()
    Equal(Keys(C.items), table.concat(g.Reference(), " "), "the search cleared: everything (still all open, as left)")
    Errors(g, "EraUI's Challenges page: the game's results")

    -- Folding, kept for the session; while searching every header is open
    -- and what is folded then is forgotten with the search.
    for key in pairs(C.folded) do C.folded[key] = nil end
    C.Refresh()
    C.listBar:SetValue(0)
    Equal(#C.items, 18, "folded as at first again")
    g.Run(Row(2), "OnClick", "LeftButton")
    Equal(#C.items .. " " .. Words(3).text, "21 Novice Druid", "a header clicked opens: its challenges under it")
    Equal(g.st[Piece(look, Row(2), "fold")].file, "Interface\\Buttons\\UI-MinusButton-Up", "its minus")
    g.Run(Row(1), "OnClick", "LeftButton")
    Expect("Classes, Tradeskills, Player vs. Player, Adventure, Dungeons, Raids", "a top header folds everything under it")
    g.Run(tabsC[1], "OnMouseUp", "LeftButton", true)
    g.Run(tabsC[2], "OnMouseUp", "LeftButton", true)
    g.NextFrame()
    Expect("Classes, Tradeskills, Player vs. Player, Adventure, Dungeons, Raids", "the page shown again: folded as left")
    search:SetText("novice")
    g.NextFrame()
    Equal(Words(1).text .. " " .. g.st[Piece(look, Row(1), "fold")].file, "Classes Interface\\Buttons\\UI-MinusButton-Up",
        "while searching every header is open")
    g.Run(HeadRow(C, 15576), "OnClick", "LeftButton")
    Expect("Classes, Adventure, Quests, Questing Novice", "folded while searching")
    search:SetText("")
    g.NextFrame()
    Expect("Classes, Tradeskills, Player vs. Player, Adventure, Dungeons, Raids", "the search gone: the session's folding back")
    Equal(next(C.searchFolds) == nil and C.folded[15576] == true, true, "the search's own folds forgotten, the session's untouched")
    g.Run(Row(1), "OnClick", "LeftButton")
    Expect("Classes, Druid, Novice Druid, Experienced Druid, Master Druid, Hunter, Mage, Paladin, Priest, Novice Priest, "
        .. "Experienced Priest, Master Priest, Rogue, Shaman, Warlock, Warrior, Tradeskills, Player vs. Player, Adventure, "
        .. "Dungeons, Raids", "opened again: as left inside it (the druid's open, the priest's open)")
    g.Run(HeadRow(C, 15577), "OnClick", "LeftButton")

    -- Scrolling: the bar and the wheel (two rows a notch).
    C.listBar:SetValue(0)
    Equal(g.st[C.listBar].max, 10, "the bar's range")
    g.Run(C.area, "OnMouseWheel", -1)
    Equal(C.listBar:GetValue() .. " " .. Words(1).text, "2 Hunter", "the wheel down: two rows further")
    g.Run(C.area, "OnMouseWheel", -5)
    Equal(C.listBar:GetValue() .. " " .. Words(8).text, "10 Raids", "to the end")
    g.Run(C.area, "OnMouseWheel", 10)
    Equal(C.listBar:GetValue() .. " " .. Words(1).text, "0 Classes", "and back up")
    Errors(g, "EraUI's Challenges page: folding and scrolling")

    -- The details: the chosen challenge.
    local sheet = C.sheet
    local function SheetPiece(purpose) return g.st[Piece(look, sheet, purpose)] end
    local function SheetLines()
        local out = {}
        for _, region in ipairs(g.st[sheet].regions) do
            local s = g.st[region]
            if s.kind == "FontString" and s.shown and s.text and s.text ~= "" and region ~= Piece(look, sheet, "title")
                and region ~= Piece(look, sheet, "date") and region ~= Piece(look, sheet, "worth") and region ~= Piece(look, sheet, "track") then
                out[#out + 1] = s.text
            end
        end
        return table.concat(out, " | ")
    end
    local function Meters()
        local out = {}
        for _, child in ipairs(g.st[sheet].children) do
            if g.st[child].kind == "StatusBar" and g.st[child].shown then out[#out + 1] = child end
        end
        return out
    end
    local function Checks()
        local n = 0
        for _, region in ipairs(g.st[sheet].regions) do
            if g.st[region].file == "Interface\\Buttons\\UI-CheckBox-Check" and g.st[region].shown then n = n + 1 end
        end
        return n
    end
    C.Want(g.PriestNovice)
    Equal(SheetPiece("title").text, "Novice Priest", "the chosen challenge's name")
    Colour(SheetPiece("title").textColour, GOLD, "gold: done")
    Equal(SheetPiece("date").shown and SheetPiece("date").text, "10/21/26", "the date it was done, as the game shows it")
    Colour(SheetPiece("date").textColour, INK, "in ink")
    Equal(SheetPiece("face").file, "Interface\\Icons\\Ach_" .. g.PriestNovice, "its icon")
    Equal(SheetPiece("socket").file, "Interface\\Spellbook\\UI-Spellbook-SpellBackground", "in the spellbook's slot")
    Equal(SheetPiece("plate").shown and SheetPiece("worth").text, "1", "its points on the rank plate")
    Equal(Anchor(g, Piece(look, sheet, "plate")), "CENTER Texture BOTTOM 0,-6", "under the icon")
    Equal(g.st[C.tick].shown, false, "done by this character: no Track box (as the game's card)")
    Equal(SheetLines(), "Reach level 25 for the first time on a Priest. | Reach level 25", "its text and its objective")
    Equal(#Meters(), 1, "a counted objective as a bar")
    -- Another one chosen by a click.
    g.Run(RowOf(C, g.PriestMaster), "OnClick", "LeftButton")
    Equal(C.sel .. " " .. tostring(g.focused), g.PriestMaster .. " " .. g.PriestMaster, "a click chooses it (the game's focus with it)")
    Equal(g.st[Piece(look, RowOf(C, g.PriestMaster), "pick")].shown, true, "the highlight bar moves to it")
    Equal(g.st[Piece(look, RowOf(C, g.PriestNovice), "pick")].shown, false, "and off the one before")
    Equal(g.st[Piece(look, RowOf(C, g.PriestMaster), "face")].desaturated, false, "the chosen one's icon in colour")
    Equal(SheetPiece("title").text, "Master Priest", "its details")
    Colour(SheetPiece("title").textColour, INK, "brown ink: not done")
    Equal(SheetPiece("date").shown, false, "no date")
    local meter = Meters()[1]
    Equal(g.st[meter].min .. "-" .. g.st[meter].max .. " at " .. g.st[meter].value, "0-60 at 32", "the count on the old skill bar")
    Equal(g.st[Piece(look, meter, "count")].text, "32 / 60", "with its numbers")
    Colour(g.st[meter].barColour, LC.GREEN_BAR, "in the challenge's green")
    Equal(g.st[meter:GetStatusBarTexture()].file, look.MEDIA .. "UI-Character-Skills-Bar", "the old skill bar's fill")
    Equal(g.st[Piece(look, meter, "rimmiddle")].file, look.MEDIA .. "UI-Character-Skills-BarBorder", "in its rim")
    Equal(g.st[C.tick].shown, true, "not done: the Track box")
    Equal(C.tick:GetChecked(), false, "not ticked")
    Equal(SheetPiece("track").text .. " " .. tostring(SheetPiece("track").shown), "Track true", "the game's word for it")
    Equal(g.st[C.tick].mouse, true, "it takes the mouse")
    Equal(g.st[C.tick:GetCheckedTexture()].file, "Interface\\Buttons\\UI-CheckBox-Check", "the old check box")
    -- Tracked by the game's own calls.
    g.Run(C.tick, "OnClick", "LeftButton")
    Equal(table.concat(g.trackCalls, ","), "start " .. g.PriestMaster, "Track: the game's StartTracking")
    Equal(g.st[C.tick].checked, true, "ticked")
    g.Run(C.tick, "OnClick", "LeftButton")
    Equal(g.trackCalls[2], "stop " .. g.PriestMaster, "again: the game's StopTracking")
    Equal(g.st[C.tick].checked, false, "not ticked")
    -- One done by another character: the game's card offers Track.
    g.Run(RowOf(C, g.PriestExperienced), "OnClick", "LeftButton")
    Equal(g.st[C.tick].shown, true, "done by another character: Track still offered, as the game's card")
    -- The game's limit and its words.
    for i = 1, 10 do g.tracked[5000 + i] = true end
    g.Run(RowOf(C, g.PriestMaster), "OnClick", "LeftButton")
    g.Run(C.tick, "OnClick", "LeftButton")
    Equal(g.uiErrors[1], "You may only track 10 achievements at a time.", "too many tracked: the game's words")
    Equal(g.tracked[g.PriestMaster], nil, "and not tracked")
    for i = 1, 10 do g.tracked[5000 + i] = nil end
    -- The game's rule against tracking: no Track box.
    g.rules[7] = true
    C.DrawDetail()
    Equal(g.st[C.tick].shown, false, "the game's rule off: no Track box")
    g.rules[7] = nil
    C.DrawDetail()
    Equal(g.st[C.tick].shown, true, "and back")
    -- A challenge with three objectives (one done, one counted) and reward words.
    C.Want(g.deadmines)
    Equal(C.sel, g.deadmines, "chosen")
    Equal(SheetPiece("worth").text, "2", "its Legacy points")
    Equal(SheetLines(), "Earn The Deadmines. | Defeat Rhahk'Zor | Defeat Sneed | Clear the dungeon | Reward: a Legacy chest",
        "its text, its objectives and its reward words")
    Equal(Checks(), 1, "the old check on the done objective only")
    local lines = {}
    for _, region in ipairs(g.st[sheet].regions) do
        local s = g.st[region]
        if s.kind == "FontString" and s.shown then lines[s.text] = s end
    end
    Colour(lines["Defeat Rhahk'Zor"].textColour, INK, "a done objective in ink")
    Colour(lines["Defeat Sneed"].textColour, GREY_INK, "one not done in the quest log's grey")
    Equal(lines["Defeat Sneed"].shadowColour[4], 0, "no shadow on ink")
    Equal(g.st[Piece(look, Meters()[1], "count")].text, "3 / 5", "the counted one's bar")
    do
        local sheetTall = g.st[sheet].height
        Equal(sheetTall > C.DETAIL_H, true, "longer than the details' part: the sheet as tall as what is drawn")
        Equal(g.st[C.detailBar].max, sheetTall - C.DETAIL_H, "its 1.x bar scrolls by what reaches past")
        local bottom = 0
        for _, region in ipairs(g.st[sheet].regions) do
            local s = g.st[region]
            if s.kind == "FontString" and s.shown and s.points.TOPLEFT then bottom = math.max(bottom, -s.points.TOPLEFT[5] + 12) end
        end
        Equal(bottom <= sheetTall, true, "every line inside the sheet")
        g.Run(C.detail, "OnMouseWheel", -1)
        Equal(g.st[C.detailBar].value, math.min(20, sheetTall - C.DETAIL_H), "the mouse wheel scrolls the details")
        Equal(g.st[C.detail].scroll, g.st[C.detailBar].value, "the sheet with it")
        C.DrawDetail(true)
        Equal(g.st[C.detailBar].value, 0, "drawn afresh from the top")
    end
    -- A step of a chain: the chain's points, as the game's card.
    C.Want(g.delverTwo)
    Equal(SheetPiece("worth").text, "25", "a chain's step shows the chain's points (the game's card)")
    Equal(g.st[Piece(look, RowOf(C, g.delverTwo), "points")].text, "25", "on its row too")
    -- None: no plate.
    C.Want(g.zulGurub)
    Equal(SheetPiece("plate").shown or SheetPiece("worth").shown, false, "worth no points: no plate")
    Equal(g.st[Piece(look, RowOf(C, g.zulGurub), "plate")].shown, false, "nor on its row")
    -- Long details scroll.
    do
        local sheetTall = g.st[sheet].height
        Equal(sheetTall >= C.DETAIL_H, true, "the sheet at least the details' height")
        Equal(g.st[C.detailBar].max, sheetTall - C.DETAIL_H, "its bar's range what reaches past")
    end
    Errors(g, "EraUI's Challenges page: the details")

    -- Hover: EraUI's own tooltip box (the mock fails any GameTooltip read).
    local row = RowOf(C, g.zulGurub)
    g.Enter(row)
    Equal(g.TipText(), "Zul'Gurub | Earn Zul'Gurub. | Completed on 10/21/26", "hovering a challenge: EraUI's box with its name, text and date")
    g.Leave(row)
    Equal(g.TipText(), nil, "gone on leaving")
    g.Enter(HeadRow(C, 15640))
    Equal(g.TipText(), nil, "no tooltip on a header")
    g.Leave(HeadRow(C, 15640))
    -- The chat link click: linked as the game's page does; the watch click
    -- (no chat box taking it): tracked.
    local before = C.sel
    local molten, onyxia = IdOf(g, "Molten Core"), IdOf(g, "Onyxia's Lair")
    g.modified.CHATLINK = true
    g.Run(RowOf(C, molten), "OnClick", "LeftButton")
    Equal(g.linked[#g.linked], "|cffffff00|Hachievement:" .. molten .. ":Player-1:0:0:0:0:0:0:0:0|h[Molten Core]|h|r",
        "the chat link click: the game's link in the chat box")
    Equal(C.sel, before, "nothing else done")
    g.chatOpen = false
    g.modified.QUESTWATCHTOGGLE = true
    g.Run(RowOf(C, onyxia), "OnClick", "LeftButton")
    Equal(g.tracked[onyxia], true, "no chat box: the watch click tracks it")
    Equal(C.sel, before, "without choosing it")
    g.modified.CHATLINK, g.modified.QUESTWATCHTOGGLE = nil, nil
    g.chatOpen = true
    Errors(g, "EraUI's Challenges page: hover and clicks")

    -- Chosen from elsewhere (the tracker, an alert: the game's window): its
    -- category opened and the list scrolled to it.
    for key in pairs(C.folded) do C.folded[key] = nil end
    C.Refresh()
    C.listBar:SetValue(0)
    local warsong = IdOf(g, "Warsong Victor")
    w:SelectChallenge(warsong)
    Equal(C.sel, warsong, "chosen from elsewhere")
    Equal(C.folded[15610] == false and C.folded[15611] == false, true, "its category and the one above opened")
    Equal(RowNow(C, warsong) ~= nil, true, "the list scrolled to it")
    Equal(SheetPiece("title").text, "Warsong Victor", "its details")
    -- Hidden by a search: the game clears it; chosen when its results come.
    search:SetText("priest")
    g.NextFrame()
    w:SelectChallenge(molten)
    Equal(search:GetText(), "", "the game cleared its search for it")
    Equal(C.sel ~= molten, true, "not chosen before the game's results come")
    g.NextFrame()
    Equal(C.sel, molten, "chosen once the game's results came")
    Equal(RowNow(C, molten) ~= nil, true, "and scrolled to")
    -- Hidden by the filter: the game resets it.
    g.SetFilter("Completed", false)
    Equal(C.byId[g.PriestNovice], nil, "a done one hidden by the filter")
    w:SelectChallenge(g.PriestNovice)
    Equal(C.sel .. " " .. tostring(g.env.LegacyChallengeFilters.Completed.value), g.PriestNovice .. " true",
        "the game reset its filter for it: chosen")
    Equal(RowNow(C, g.PriestNovice) ~= nil, true, "and scrolled to")
    Errors(g, "EraUI's Challenges page: chosen from elsewhere")

    -- The game's data changing: drawn again.
    C.Want(g.PriestMaster)
    g.achs[g.PriestMaster].criteria[1].quantity = 40
    g.Fire("CRITERIA_UPDATE")
    Equal(g.st[Piece(look, Meters()[1], "count")].text .. " " .. g.st[Meters()[1]].value, "40 / 60 40", "progress: the bar follows")
    g.tracked[g.PriestMaster] = true
    g.Fire("CONTENT_TRACKING_UPDATE", 2, g.PriestMaster, true)
    Equal(g.st[C.tick].checked, true, "tracked elsewhere: ticked")
    g.tracked[g.PriestMaster] = nil
    -- The priest's header on the top row, its challenges under it (8 rows
    -- show; nothing scrolls, so nothing is drawn again, before the marks).
    for place, item in ipairs(C.items) do
        if item.head and item.head.id == 15581 then C.listBar:SetValue(place - 1) end
    end
    g.Earn(g.PriestMaster)
    Colour(g.st[Piece(look, RowOf(C, g.PriestMaster), "words")].textColour, GOLD, "done: its name gold")
    Equal(SheetPiece("date").shown and SheetPiece("date").text, "10/21/26", "its date")
    Equal(g.st[C.tick].shown, false, "no Track box any more")
    Equal(g.st[Piece(look, HeadRow(C, 15581), "count")].text, "2 / 3", "its category's count")
    -- The game's "new" marks: set by the game after EraUI heard the event,
    -- shown on the headers a frame later; never cleared by EraUI (the
    -- mock's MarkCategoryViewed fails if called).
    Equal(g.st[Piece(look, HeadRow(C, 15581), "new")].shown, false, "the game's new mark not set yet")
    g.NextFrame()
    Equal(g.st[Piece(look, HeadRow(C, 15581), "new")].shown and g.st[Piece(look, HeadRow(C, 15576), "new")].shown, true,
        "the game's new mark on the category and the one above it")
    Equal(g.st[Piece(look, HeadRow(C, 15581), "new")].atlas, "UI-HUD-MicroMenu-Communities-Icon-Notification", "the game's own mark")
    Equal(g.st[Piece(look, HeadRow(C, 15582), "new")].shown, false, "none on a category with nothing new")
    Equal(g.st[Piece(look, RowOf(C, g.PriestMaster), "new")].shown, false, "none on a challenge's row")
    g.Run(RowOf(C, g.PriestMaster), "OnClick", "LeftButton")
    g.Run(HeadRow(C, 15581), "OnClick", "LeftButton")
    g.Run(HeadRow(C, 15581), "OnClick", "LeftButton")
    Equal(g.unviewed[15581], true, "EraUI's clicks leave the game's marks to the game's own list")
    Errors(g, "EraUI's Challenges page: updates")

    -- In a fight: EraUI's own frames keep working; a value the game hides
    -- shows the last one read; nothing of the game's moves.
    local parked = Anchor(g, box)
    g.combat = true
    g.secret = "fields"
    g.Fire("ACHIEVEMENT_EARNED", 1)
    g.Fire("CRITERIA_UPDATE")
    Equal(Words(1).text ~= nil and #C.items > 0, true, "in a fight with hidden values: still listed")
    Equal(g.st[Piece(look, RowOf(C, g.PriestMaster), "words")].text, "Master Priest", "the last name read")
    Equal(SheetPiece("title").text .. " " .. SheetPiece("worth").text, "Master Priest 1", "the details from the last values read")
    Colour(g.st[Piece(look, RowOf(C, g.PriestMaster), "words")].textColour, GOLD, "done as last read")
    g.Run(RowOf(C, g.PriestNovice), "OnClick", "LeftButton")
    Equal(C.sel, g.PriestNovice, "a click chooses in a fight")
    Equal(SheetPiece("title").text, "Novice Priest", "its details from the last values read")
    g.Run(HeadRow(C, 15581), "OnClick", "LeftButton")
    Equal(RowOf(C, g.PriestNovice), nil, "a header folds in a fight")
    g.Run(HeadRow(C, 15581), "OnClick", "LeftButton")
    g.secret = "all"
    local count = #C.items
    C.Refresh()
    Equal(#C.items, count, "the whole list hidden: the last one kept")
    g.Run(tabsC[1], "OnMouseUp", "LeftButton", true)
    g.Run(tabsC[2], "OnMouseUp", "LeftButton", true)
    Equal(#C.items .. " " .. Anchor(g, box), count .. " " .. parked, "shown again in a fight: listed, the game's rows still parked")
    g.gamepad = true
    LC.ChallengeMode(page, w)
    g.Run(tabsC[1], "OnMouseUp", "LeftButton", true)
    g.Run(tabsC[2], "OnMouseUp", "LeftButton", true)
    Equal(C.mode .. " " .. Anchor(g, box) .. " " .. g.st[box].alpha, "own " .. parked .. " 0",
        "the gamepad mode coming in a fight: nothing of the game's moves until it ends")
    g.gamepad = false
    C.Want(g.DruidNovice)
    Equal(C.sel .. " " .. tostring(C.folded[15577]), g.DruidNovice .. " false", "chosen from elsewhere in the fight: from the list read last")
    Equal(g.st[Piece(look, C.sheet, "title")].text, "Novice Druid", "its details from the last values read")
    g.secret = nil
    g.Fire("ACHIEVEMENT_SEARCH_UPDATED")
    Equal(g.st[Piece(look, RowOf(C, g.DruidNovice), "words")].text, "Novice Druid", "values back: read again")
    g.combat = false
    g.Fire("PLAYER_REGEN_ENABLED")
    Errors(g, "EraUI's Challenges page: a fight")

    -- With the game's gamepad mode: the game's own page (its gamepad moves
    -- through its rows and cards), then EraUI's again.
    g.gamepad = true
    g.Run(tabsC[1], "OnMouseUp", "LeftButton", true)
    g.Run(tabsC[2], "OnMouseUp", "LeftButton", true)
    Equal(C.mode .. " " .. tostring(g.st[C.holder].shown), "game false", "gamepad: EraUI's page hidden")
    Equal(g.st[box].alpha .. "/" .. g.st[boxBar].alpha .. "/" .. g.st[pane].alpha, "1/1/1", "the game's rows and cards shown")
    Equal(Anchor(g, box, "TOPLEFT"), "TOPLEFT Frame TOPLEFT 8,-35", "its rows back in its list")
    Equal(Anchor(g, list, "TOPLEFT") .. " / " .. Anchor(g, list, "BOTTOMRIGHT"),
        "TOPLEFT LegacySystemFrame TOPLEFT 8,-62 / BOTTOMRIGHT LegacySystemFrame TOPRIGHT -8,-212", "the dressed page's list")
    Equal(Anchor(g, pane, "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 8,-220", "and its cards")
    Equal(Anchor(g, Piece(look, page, "rule"), "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 16,-216", "its rule")
    g.Fire("ACHIEVEMENT_EARNED", 1)
    Errors(g, "the gamepad's page")
    g.gamepad = false
    g.Run(tabsC[1], "OnMouseUp", "LeftButton", true)
    g.Run(tabsC[2], "OnMouseUp", "LeftButton", true)
    Equal(C.mode .. " " .. tostring(g.st[C.holder].shown) .. " " .. g.st[box].alpha, "own true 0", "no gamepad again: EraUI's page")
    Equal(Anchor(g, box) == parked, true, "the game's rows parked again")

    -- EraUI's frames in the window that take the mouse: only this page's
    -- rows, Track box and scroll bars, none over the game's controls.
    local mouseOwn = g.FindAll(function(s, obj)
        if s.game or s.mouse ~= true then return false end
        local up = s.parent
        while up do
            if up == w then return true end
            up = g.st[up].parent
        end
        return false
    end)
    local allowed = {}
    for _, slot in ipairs(C.slots) do allowed[slot] = true end
    allowed[C.tick] = true
    Equal(#mouseOwn, #C.slots + 1, "EraUI's frames taking the mouse found")
    for _, obj in ipairs(mouseOwn) do
        Equal(allowed[obj], true, "an EraUI frame taking the mouse is one of this page's rows or its Track box")
        if g.Rect(obj) then
            for _, key in ipairs({ "SearchBox", "FilterDropdown" }) do Apart(g, obj, Field(list, key), w, "clear of the game's " .. key) end
            Within(g, obj, w, PARCH, "on the parchment")
        end
    end
    Errors(g, "EraUI's frames")

    -- Off: the game's own page exactly as it was; on again: EraUI's.
    g.ns.db.legacyWindow = false
    g.Pass()
    Equal(g.st[C.holder].shown, false, "off: EraUI's page hidden")
    Equal(g.st[box].alpha .. "/" .. g.st[boxBar].alpha .. "/" .. g.st[pane].alpha, "1/1/1", "the game's rows and cards back")
    Equal(Anchor(g, box, "TOPLEFT") .. " / " .. Anchor(g, box, "BOTTOMRIGHT"), "TOPLEFT Frame TOPLEFT 8,-35 / BOTTOMRIGHT Frame BOTTOMRIGHT -20,5",
        "its rows on their own anchors")
    Equal(Anchor(g, list, "TOPLEFT") .. " / " .. Anchor(g, list, "BOTTOMLEFT"), "TOPLEFT Frame TOPLEFT 6,-80 / BOTTOMLEFT Frame BOTTOMLEFT 0,8",
        "its list down the left")
    Equal(Anchor(g, pane, "BOTTOMRIGHT") .. " " .. tostring(g.st[pane].points.TOPLEFT), "BOTTOMRIGHT Frame BOTTOMRIGHT -24,8 nil", "its cards at the right")
    local filterUpdates = g.filterUpdates or 0
    g.Fire("ACHIEVEMENT_EARNED", 1)
    g.SetFilter("Completed", true)
    Equal(C.mode, nil, "off: nothing follows the game")
    Errors(g, "off")
    g.ns.db.legacyWindow = true
    g.Pass()
    Equal(C.mode .. " " .. tostring(g.st[C.holder].shown) .. " " .. g.st[box].alpha, "own true 0", "on again: EraUI's page")
    Equal(Anchor(g, box) == parked, true, "the game's rows parked again")
    g.Run(tabsC[1], "OnMouseUp", "LeftButton", true)
    g.Run(tabsC[2], "OnMouseUp", "LeftButton", true)
    g.NextFrame()
    Equal(#C.items > 0 and g.st[C.slots[1]].shown, true, "listed again")
    Errors(g, "on again")
end

-- Dark Windows and Black Pages: the ink turns light like the rest of the
-- window's page text; gold stays gold.
do
    local g, look = Session({ appearance = true, settings = { darkMode = true, darkWindows = true, blackPages = true, darkModeDarkness = 70 } })
    local C = look.Legacy.ChallengeList
    local w = g.LoadAddOn()
    w:Show()
    g.Run(Field(w, "Tabs")[2], "OnMouseUp", "LeftButton", true)
    g.NextFrame()
    local light = g.ns.DARK_PAGE_TEXT
    local function Words(i) return g.st[Piece(look, C.slots[i], "words")] end
    Colour(Words(1).textColour, GOLD, "Black Pages: a top header still gold")
    Colour(Words(2).textColour, light, "a category's brown ink light")
    Colour(Words(8).textColour, light, "a challenge not done light")
    Colour(Words(7).textColour, GOLD, "a done one gold")
    C.Want(g.PriestMaster)
    Colour(g.st[Piece(look, C.sheet, "title")].textColour, light, "the details' ink light")
    -- (Choosing it scrolled the 8 rows to it: back to the top.)
    C.listBar:SetValue(0)
    Colour(Words(2).textColour, light, "the top rows again: a category still light")
    g.settings.darkWindows = false
    g.ns.RefreshDarkWindows()
    Colour(Words(2).textColour, INK, "Dark Windows off: brown ink again at once")
    Colour(g.st[Piece(look, C.sheet, "title")].textColour, INK, "in the details too")
    Errors(g, "EraUI's Challenges page in Dark Mode")
end

-- Y opened for the first time in a fight, on the Challenges page: the
-- game's own page until the fight ends, then EraUI's, drawn at once (the
-- page stays shown, so no show of its own draws it).
do
    local g, look = Session()
    local C = look.Legacy.ChallengeList
    g.combat = true
    local w = g.LoadAddOn()
    w:Show()
    g.Run(Field(w, "Tabs")[2], "OnMouseUp", "LeftButton", true)
    g.NextFrame()
    local box = Field(Field(Field(w, "ChallengesPage"), "CategoryList"), "ScrollBox")
    Equal(tostring(C.mode) .. " " .. g.st[box].alpha, "nil 1", "first opened in a fight: the game's own page")
    g.combat = false
    g.Fire("PLAYER_REGEN_ENABLED")
    Equal(C.mode .. " " .. g.st[box].alpha, "own 0", "the fight over: EraUI's page")
    Equal(#C.items > 0 and g.st[C.slots[1]].shown, true, "listed at once, the page still showing")
    Equal(C.sel .. " " .. tostring(g.st[Piece(look, C.sheet, "title")].text), g.PriestNovice .. " Novice Priest",
        "the first challenge chosen and its details drawn")
    Errors(g, "first opened in a fight")
end

-- A place in a category's count with no challenge behind it: left out, as
-- the game's page leaves it out, and everything else listed.
do
    local g, look = Session()
    local C = look.Legacy.ChallengeList
    g.gaps[15630] = 2
    local w = g.LoadAddOn()
    w:Show()
    g.Run(Field(w, "Tabs")[2], "OnMouseUp", "LeftButton", true)
    g.NextFrame()
    for _, node in pairs(C.nodes or {}) do C.folded[node.id] = false end
    C.Refresh()
    Equal(Keys(C.items), table.concat(g.Reference(), " "), "a gap in a category: the game's list, the gap left out")
    Equal(#C.items, 19 + 46, "every other challenge listed")
    Errors(g, "a gap in a category")
end

---------------------------------------------------------------------------
-- 5. The Legacy Tree
---------------------------------------------------------------------------

game.Run(tabs[3], "OnMouseUp", "LeftButton", true)
Equal(tree:IsVisible(), true, "the third tab shows the Legacy Tree")
Equal(Raised(3), true, "its tab raised")
local selector = Field(tree, "LegacyTreeSelectionPanel")
Equal(Anchor(game, selector), "TOP LegacySystemFrame TOPRIGHT 17,-50", "the trees' list just outside the right edge")
local treeButtons = Field(selector, "treeButtons")
for i, button in ipairs(treeButtons) do
    Equal(st[button].width .. "x" .. st[button].height, "32x32", "tree " .. i .. ": a spellbook tab's size")
    Equal(Anchor(game, button), "TOPLEFT LegacySystemFrame TOPRIGHT 1," .. (-50 - (i - 1) * 47), "tree " .. i .. ": down the right edge")
    for _, key in ipairs({ "Background", "SelectedGlow", "Ring", "CheckedTexture" }) do
        Equal(st[Field(button, key)].alpha, 0, "tree " .. i .. ": the game's " .. key .. " faded")
    end
    Equal(S(game, Piece(Look, button, "plate")).file, "Interface\\Spellbook\\SpellBook-SkillLineTab", "tree " .. i .. ": on the old tab plate")
    Equal(st[Piece(Look, button, "checked")].shown, i == 1, "tree " .. i .. ": the old glow only while chosen")
end
game.Run(treeButtons[2], "OnClick", "LeftButton")
Equal(st[Piece(Look, treeButtons[2], "checked")].shown and not st[Piece(Look, treeButtons[1], "checked")].shown, true,
    "the game's own click moves the glow")
local panel = Field(tree, "LegacyTreeTraitPanel")
local emblem = Field(panel, "SelectedTreeIcon")
-- Above the tree: the emblem in its ring at the parchment's top left, the
-- points spent on a plate at its foot, the name beside it, the search under
-- the name, a rule; all on the parchment, none over another.
Equal(st[emblem].width, 46, "the chosen tree's emblem")
Equal(Anchor(game, emblem), "CENTER LegacySystemFrame TOPLEFT 42,-96", "at the parchment's top left")
Equal(st[Field(emblem, "Ring")].alpha, 0, "its modern ring faded")
Equal(S(game, Piece(Look, emblem, "ring")).file, "Interface\\Spellbook\\ProfessionsBook", "in the old professions book ring")
Equal(st[Piece(Look, emblem, "ring")].width, 60, "the ring round it")
Within(game, Piece(Look, emblem, "ring"), window, PARCHMENT, "the ring on the parchment")
local treeName = Field(emblem, "SelectedTreeLabel")
Equal(st[treeName].text, "Adventure", "the game's own tree name")
Colour(st[treeName].textColour, GOLD, "in gold")
Equal(st[treeName].font, game.env.GameFontNormalLarge, "in the old large font")
Equal(Anchor(game, treeName) .. " " .. st[treeName].justify, "LEFT LegacySystemFrame TOPLEFT 84,-80 LEFT", "beside the ring")
local spent = Field(panel, "SpentPointsFrame")
Equal(st[Field(spent, "Background")].alpha, 0, "the spent circle faded")
Equal(S(game, Piece(Look, spent, "plate")).file, "Interface\\TalentFrame\\TalentFrame-RankBorder", "the points spent on a rank plate")
Equal(Anchor(game, spent), "CENTER CheckButton BOTTOMRIGHT 0,4", "at the emblem's foot")
local treeSearch = Field(panel, "SearchBox")
Equal(Anchor(game, treeSearch), "LEFT LegacySystemFrame TOPLEFT 98,-110", "the game's search under the name")
Within(game, treeSearch, window, PARCHMENT, "the search on the parchment")
Apart(game, treeSearch, Piece(Look, spent, "plate"), window, "the search clear of the spent points")
Apart(game, treeSearch, treeName, window, "and of the name")
Apart(game, treeName, Piece(Look, emblem, "ring"), window, "the name clear of the ring")
Equal(Anchor(game, Piece(Look, tree, "rule"), "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 16,-131", "a rule over the tree")
-- EraUI's own label the ranks are measured with: in the rank font, never
-- shown (it holds whichever rank was measured last).
do
    local measure = Piece(Look, tree, "rankMeasure")
    Equal(st[measure].font .. " " .. tostring(st[measure].shown), "GameFontNormalSmall false", "the ranks' measuring label, hidden")
end
-- The header's crown: the points on a plate just before "Available points",
-- in the stone band under the title.
local treeSummary = Field(tree, "LegacyTreePointSummary")
local treeShield = Field(treeSummary, "Shield")
HeaderPlate(treeShield, "FontString", -16, "the Legacy Tree header")
Equal(Anchor(game, treeSummary), "TOPLEFT LegacySystemFrame TOPLEFT 85,-15", "the points in the band")
do
    local _, t, _, f = Box(game, Field(treeSummary, "AvailablePointsLabel"), window)
    Near((t + f) / 2, 39, "Available points on the band's middle")
end
Equal(st[Piece(Look, treeShield, "plate")].points.CENTER[2], Field(treeSummary, "AvailablePointsLabel"), "before the Available points text itself")
Equal(st[Field(treeShield, "Points")].text, "17", "the game's points (changed on the Challenges page)")
game.SetPoints(18)
Equal(st[Field(treeShield, "Points")].text .. " / " .. st[Field(treeSummary, "AvailablePointsLabel")].text, "18 / Available points: 18",
    "the game's own number follows the next change")
HeaderPlate(treeShield, "FontString", -16, "the Legacy Tree header after the change")
local apply = Field(panel, "ApplyButton")
Equal(st[apply:GetNormalTexture()].file, "Interface\\Buttons\\UI-Panel-Button-Up", "Apply as the old red button")
Equal(st[Field(apply, "YellowGlow")].alpha, 0, "its modern glow faded")
Equal(st[Field(Field(panel, "UndoButton"), "Icon")].file, "Interface\\Buttons\\UI-RotationLeft-Button-Up", "undo as the old round arrow")
Equal(st[Field(Field(panel, "ResetButton"), "Icon")].file, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", "reset as the old round X")
Equal(Anchor(game, apply), "CENTER LegacySystemFrame TOPLEFT 148,-390", "Apply at the parchment's foot")
-- Inside the parchment, above its burnt rim (in game Apply sat on the rim,
-- screenshot 487), undo and reset with it.
local CLEAR = { left = PARCHMENT.left + 8, top = PARCHMENT.top, right = PARCHMENT.right - 8, bottom = PARCHMENT.bottom - L.EDGE }
for _, key in ipairs({ "ApplyButton", "UndoButton", "ResetButton" }) do
    Within(game, Field(panel, key), window, PARCHMENT, key .. " on the parchment")
    Within(game, Field(panel, key), window, CLEAR, key .. " above the parchment's burnt rim")
end
Equal(st[Field(panel, "ResetButton")].points.LEFT[2], apply, "reset (and undo) beside Apply, where the game anchors them")

-- The tree's box: the game's talent holder (the panel less its padding).
local holder = Field(panel, "ButtonsParent")
do
    local l, t, r, f = Box(game, holder, window)
    Equal(string.format("%g,%g to %g,%g", l, t, r, f), "12,134 to 324,376", "the talents' holder is the tree's box, under the header, over Apply")
    Apart(game, holder, apply, window, "Apply clear of the tree (the holder takes the mouse)")
    Apart(game, holder, treeSearch, window, "the search clear of it too")
    Apart(game, holder, Piece(Look, spent, "plate"), window, "and the spent points")
end
local byNode = Field(panel, "byNode")
-- What of a talent shows (window units: left, top, right, foot): its icon
-- with a 1 rim (its socket's edge) and its rank box's drawn part: the
-- stretched middle ("plate", the plate's height) and past it the drawn
-- share of the plate's two ends, as measured in game (screenshot 485: 0.44
-- of the plate's art across, 0.42 down, round its middle). The box counts
-- even while hidden.
local function Footprint(g, look, button, win)
    local l, t, r, f = Box(g, Field(button, "Icon"), win)
    l, t, r, f = l - 1, t - 1, r + 1, f + 1
    local ml, mt, mr, mf = Box(g, Piece(look, button, "plate"), win)
    local size, cy = mf - mt, (mt + mf) / 2
    local hw, hh = size * 0.44 / 2, size * 0.42 / 2
    return math.min(l, ml - hw), math.min(t, cy - hh), math.max(r, mr + hw), math.max(f, cy + hh)
end
-- A talent's rank as the old talent window's, on every build: the game's
-- rank text faded; EraUI's own "current/max" (words) in the old small font
-- (5 across a character in the mock) on the rank box, in its state's
-- colour. The box: the old rank plate's art, its two ends at their own
-- size (half the plate each) and a sliver of its middle stretched for the
-- widest rank the talent can show ("max/max", widest) with 5 clear of the
-- box's drawn edge (L.PLATE_SEEN) on either side, so a point spent never
-- resizes it; over the icon's corner, 2 in. Shown only with a rank.
local RANK_CUTS = { plate = "0.48,0.52,0,1", plateLeft = "0,0.5,0,1", plateRight = "0.5,1,0,1" }
local function RankBox(g, look, button, words, widest, colour, label)
    local mid, rank = Piece(look, button, "plate"), Piece(look, button, "rank")
    local s = g.st
    Equal(s[Field(button, "SpendText")].alpha, 0, label .. ": the game's rank text faded")
    local size = s[mid].height
    for purpose, cut in pairs(RANK_CUTS) do
        local piece = Piece(look, button, purpose)
        Equal(s[piece].file, RANK, label .. ": its box from the old rank plate (" .. purpose .. ")")
        Equal(Coords(g, piece), cut, label .. ": the plate's art cut across (" .. purpose .. ")")
        Equal(s[piece].layer .. s[piece].sublevel, "OVERLAY1", label .. ": over the icon (" .. purpose .. ")")
        Near(s[piece].height, size, label .. ": the plate's height (" .. purpose .. ")")
        Equal(s[piece].shown, words ~= "", label .. ": shown with a rank (" .. purpose .. ")")
    end
    Equal(size >= 32 and size <= 44, true, label .. ": the plate's own size")
    for _, purpose in ipairs({ "plateLeft", "plateRight" }) do
        Near(s[Piece(look, button, purpose)].width, size / 2, label .. ": the " .. purpose .. " end at its own size")
    end
    Equal(Anchor(g, mid) .. " " .. tostring(s[mid].points.CENTER[2] == Field(button, "Icon")), "CENTER Texture BOTTOMRIGHT -2,2 true",
        label .. ": the box over the icon's corner, as the old plate")
    Equal(Anchor(g, Piece(look, button, "plateLeft")) .. " " .. tostring(s[Piece(look, button, "plateLeft")].points.RIGHT[2] == mid),
        "RIGHT Texture LEFT 0,0 true", label .. ": its left end before its middle")
    Equal(Anchor(g, Piece(look, button, "plateRight")) .. " " .. tostring(s[Piece(look, button, "plateRight")].points.LEFT[2] == mid),
        "LEFT Texture RIGHT 0,0 true", label .. ": its right end after it")
    Near(s[mid].width, math.max(1, #widest * 5 + 2 * 5 - size * look.Legacy.PLATE_SEEN[1]), label .. ": sized for " .. widest)
    -- In game 0.44 of the plate's art across is drawn: the rank at least 4
    -- clear of the drawn edge either side (a digit in the old window's box,
    -- about 4.5).
    checks = checks + 1
    if #words * 5 + 8 > s[mid].width + size * 0.44 + 1e-6 then error(label .. ": the rank too tight in its box", 2) end
    Equal(s[rank].text, words, label .. ": the rank " .. words)
    Equal(s[rank].font, "GameFontNormalSmall", label .. ": in the old talent window's small font")
    Equal(s[rank].layer .. s[rank].sublevel, "OVERLAY2", label .. ": over its box")
    Equal(Anchor(g, rank) .. " " .. tostring(s[rank].points.CENTER[2] == mid), "CENTER Texture CENTER 0,0 true", label .. ": on the box")
    Colour(s[rank].textColour, colour, label .. ": in its state's colour")
    Equal(s[rank].shown, words ~= "", label .. ": shown with a rank")
end
-- In a fight EraUI touches only its own pieces: its writes (calls from a
-- Look/ file) on the game's own talent pieces (every region or frame a
-- talent carries by key, and 70532's unnamed rank box) are recorded while
-- the watch runs. The talents' own anchors are not watched (laid out again
-- in a fight on purpose), nor the game's own writes. Returns the stop,
-- which gives the writes seen.
local FIGHT_SETTERS = { "SetAlpha", "SetVertexColor", "SetTextColor", "SetShadowColor", "SetShadowOffset", "SetShown",
    "Show", "Hide", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale",
    "SetFontObject", "SetAtlas", "SetTexture", "SetTexCoord", "SetText", "SetDrawLayer", "SetBlendMode", "SetDesaturated",
    "SetJustifyH" }
local function FightWatch(g, pool)
    local Proto = getmetatable(g.env.UIParent).__index
    local watched, writes, kept = {}, {}, {}
    for button in pool:EnumerateActive() do
        for key, value in pairs(button) do
            if type(value) == "table" and g.st[value] and value ~= button then watched[value] = key end
        end
        if g.rankBoxes and g.rankBoxes[button] then watched[g.rankBoxes[button]] = "rank box" end
    end
    for _, name in ipairs(FIGHT_SETTERS) do
        local real = rawget(Proto, name)
        if type(real) == "function" then
            kept[name] = real
            rawset(Proto, name, function(self, ...)
                if watched[self] then
                    local info = debug.getinfo(2, "S")
                    if info and tostring(info.source):find("Look/", 1, true) then
                        writes[#writes + 1] = watched[self] .. ":" .. name
                    end
                end
                return real(self, ...)
            end)
        end
    end
    return function()
        for name, real in pairs(kept) do rawset(Proto, name, real) end
        return table.concat(writes, ", ")
    end
end
-- Every talent and its plate inside the box (nothing cut off) and on the
-- parchment, no two of them nearer than 2 (never touching), the tree
-- centred in the box (its margins the same either side, within 2).
local function TreeFits(g, look, pnl, win, label)
    local hold = Field(pnl, "ButtonsParent")
    local hl, ht, hr, hf = Box(g, hold, win)
    local area = { left = hl, top = ht, right = hr, bottom = hf }
    local seen = {}
    local left, right, top, foot = math.huge, -math.huge, math.huge, -math.huge
    for button in Field(pnl, "talentButtonCollection"):EnumerateActive() do
        local name = label .. ": talent " .. tostring(Field(button, "nodeID"))
        Within(g, Field(button, "Icon"), win, area, name .. "'s icon inside the box")
        local l, t, r, f = Footprint(g, look, button, win)
        checks = checks + 1
        if l < hl - 0.01 or t < ht - 0.01 or r > hr + 0.01 or f > hf + 0.01 then
            error(string.format("%s: it or its plate at %g,%g to %g,%g, outside the box %g,%g to %g,%g", name, l, t, r, f, hl, ht, hr, hf), 2)
        end
        Within(g, Field(button, "Icon"), win, PARCHMENT, name .. "'s icon on the parchment")
        for _, other in ipairs(seen) do
            local apartX = math.max(l - other[3], other[1] - r)
            local apartY = math.max(t - other[4], other[2] - f)
            checks = checks + 1
            if apartX < 2 and apartY < 2 then
                error(string.format("%s and talent %s touch (%g across, %g down between them)", name, other[5], apartX, apartY), 2)
            end
        end
        seen[#seen + 1] = { l, t, r, f, tostring(Field(button, "nodeID")) }
        left, right, top, foot = math.min(left, l), math.max(right, r), math.min(top, t), math.max(foot, f)
    end
    Equal(#seen > 0, true, label .. ": talents shown")
    checks = checks + 1
    if math.abs((left - hl) - (hr - right)) > 2 or math.abs((top - ht) - (hf - foot)) > 2 then
        error(string.format("%s: not centred (margins %g / %g across, %g / %g down)", label, left - hl, hr - right, top - ht, hf - foot), 2)
    end
end
TreeFits(game, Look, panel, window, "the tree")
-- Down the tree fits at the game's spacing. Across, its talents 60 apart in
-- a row are closer than any real tree's: spread just enough for the rank
-- boxes ("1/1" to "5/5": 15 wide in the rank font, 5 clear either side, so
-- 25 drawn, its middle 2 in from the icon's corner) and 4 to the next
-- talent's rim (half its 46 icon, and 1).
local SX = ((23 + 1) + (23 - 2 + 25 / 2) + 4) / 60
Near(Look.Legacy.treeScale.x, SX, "a row closer than its rank boxes allow: spread across just enough")
Equal(Look.Legacy.treeScale.y, 1, "down, where the tree fits: the game's spacing")
local DX, DY = st[byNode[1]].points.CENTER[4] - 200, st[byNode[1]].points.CENTER[5] + 100
-- Where a talent the game put at gx, gy is now (the tree moved to its box,
-- spread across by SX).
local function NearSpot(button, gx, gy, label)
    local at = st[button].points.CENTER
    Equal(Anchor(game, button):match("^CENTER Frame TOPLEFT") ~= nil, true, label .. ": on the holder")
    Near(at[4], 200 + DX + (gx - 200) * SX, label .. " (across)")
    Near(at[5], gy + DY, label .. " (down)")
end
NearSpot(byNode[2], 260, -100, "the next talent the game's 60 further on, spread to 61.5")
-- The game placing one talent again on its own (UpdateTalentButtonPosition,
-- which nothing hooks): the watch fits it to the tree again.
byNode[2]:SetPoint("CENTER", holder, "TOPLEFT", 260, -100)
game.Tick(0.15)
NearSpot(byNode[2], 260, -100, "the game placing a talent again: the watch fits it again")
local function Socket(id) return st[Piece(Look, byNode[id], "socket")] end
for id, button in pairs(byNode) do
    for _, key in ipairs({ "StateBorder", "Shadow", "Ghost", "SpendText", "SpendTextShadow1" }) do
        Equal(st[Field(button, key)].alpha, 0, "talent " .. id .. ": the game's " .. key .. " faded")
    end
    for _, key in ipairs({ "StateBorderHover", "Glow", "DisabledOverlay" }) do
        Equal(st[Field(button, key)].colour[4], 0, "talent " .. id .. ": the game's " .. key .. " faded by its colour")
    end
    Equal(Socket(id).file, "Interface\\Buttons\\UI-EmptySlot-White", "talent " .. id .. ": in the old socket")
    Equal(st[Socket(id) and Piece(Look, button, "socket")].layer, "BACKGROUND", "talent " .. id .. ": under its icon")
end
Colour(Socket(1).colour, L.STATE.learned, "a learned talent's socket gold")
Colour(Socket(2).colour, L.STATE.open, "an open one green")
Colour(Socket(3).colour, L.STATE.locked, "a locked one grey")
-- Build 70450 (this session): the game writes only the current rank, and
-- nothing on a talent not taken that can't be yet. EraUI's rank shows
-- "current/max" on every talent, made from the talent's own ranks.
Equal(st[Field(byNode[1], "SpendText")].text .. "|" .. st[Field(byNode[2], "SpendText")].text .. "|"
    .. st[Field(byNode[3], "SpendText")].text, "1|0|", "70450: the game's own rank text, the current rank or nothing")
RankBox(game, Look, byNode[1], "1/1", "1/1", L.STATE.learned, "70450, a maxed talent")
RankBox(game, Look, byNode[2], "0/2", "2/2", L.STATE.open, "70450, an open one")
RankBox(game, Look, byNode[3], "0/3", "3/3", L.STATE.locked, "70450, a locked one (the game shows nothing)")
RankBox(game, Look, byNode[4], "0/5", "5/5", L.STATE.locked, "70450, a locked one of five")
-- The game's own click takes a rank; its state and rank come back painted.
game.Run(byNode[2], "OnClick", "LeftButton")
RankBox(game, Look, byNode[2], "1/2", "2/2", L.STATE.open, "70450, one rank taken of two: still green")
Colour(Socket(2).colour, L.STATE.open, "still open: green")
game.Run(byNode[2], "OnClick", "LeftButton")
Colour(Socket(2).colour, L.STATE.learned, "learned by the game's click: gold")
RankBox(game, Look, byNode[2], "2/2", "2/2", L.STATE.learned, "70450, maxed by the game's click: gold")
Equal(st[Field(byNode[2], "DisabledOverlay")].colour[4], 0, "the overlay the game set again stays faded")
-- The game setting a talent's state again (its next visual update).
byNode[3]:ApplyVisualState("refund")
Colour(Socket(3).colour, L.STATE.refund, "one that can't be taken back red")
RankBox(game, Look, byNode[3], "0/3", "3/3", L.STATE.refund, "70450, one that can't be taken back: red")
-- A talent whose ranks can't be read (no node, the game's rank blank): no
-- rank and no box; its ranks back, both back.
do
    local kept = Field(byNode[5], "nodeInfo")
    game.Own(byNode[5], "nodeInfo", nil)
    Field(byNode[5], "SpendText"):SetText("")
    byNode[5]:UpdateNonStateVisuals()
    RankBox(game, Look, byNode[5], "", "", L.STATE.locked, "70450, no ranks to read")
    game.Own(byNode[5], "nodeInfo", kept)
    byNode[5]:UpdateSpendText()
    RankBox(game, Look, byNode[5], "0/1", "1/1", L.STATE.locked, "70450, its ranks back")
end

-- The links.
local branches, heads
local edgesSeen = {}
for edge in Field(panel, "edgePool"):EnumerateActive() do edgesSeen[#edgesSeen + 1] = edge end
Equal(#edgesSeen, 4, "four links")
local function EdgeFrom(a, b)
    for _, edge in ipairs(edgesSeen) do
        if Field(edge, "startButton") == byNode[a] and Field(edge, "endButton") == byNode[b] then return edge end
    end
end
for _, child in ipairs(st[holder].children) do
    if not st[child].game and st[child].level == 1050 then branches = child end
    if not st[child].game and st[child].level == 1150 then heads = child end
end
Equal(branches ~= nil and heads ~= nil, true, "EraUI's two layers on the talents' holder (under and over the talents at 1100)")
Equal(st[branches].mouse ~= true and st[heads].mouse ~= true, true, "neither takes the mouse")
-- Each link's pieces, found by where they start.
local function PiecesAt(layer)
    local found = {}
    for _, region in ipairs(st[layer].regions) do
        if st[region].shown then
            local at = st[region].points.TOPLEFT
            found[#found + 1] = { region = region, x = at[4], y = at[5], w = st[region].width, h = st[region].height }
        end
    end
    return found
end
-- A piece starting at x, y of the game's tree as EraUI spread it (talent 1
-- at 200, -100 as the game put it; across by SX from it: talent 2 at 261.5,
-- talent 4 at 323), moved as the tree was to its box.
local function Find(found, x, y)
    for _, piece in ipairs(found) do
        if math.abs(piece.x - (x + DX)) < 1e-3 and math.abs(piece.y - (y + DY)) < 1e-3 then return piece end
    end
end
local across = Look.Talent.LINK_ART.across
local branchesNow, headsNow = PiecesAt(branches), PiecesAt(heads)
-- Along a row (1 to 2, lit): 15.5 apart, the pieces at 0.6.
local row = Find(branchesNow, 221.8, -90.4)
Equal(row ~= nil, true, "a link along the row: its branch from the first talent's side")
Near(row.w, 17.9, "to the next one's side")
Near(row.h, 19.2, "at the gap's scale")
Equal(S(game, row.region).file, "Interface\\TalentFrame\\UI-TalentBranches", "from the old branch sheet")
Equal(Coords(game, row.region), Numbers(across[1]), "lit (the link is active)")
local rowHead = Find(headsNow, 226.5, -90.4)
Equal(rowHead ~= nil and S(game, rowHead.region).file, "Interface\\TalentFrame\\UI-TalentArrows", "its head from the old arrow sheet")
Equal(Coords(game, rowHead.region), Numbers(Look.Talent.LINK_ART.headRight[1]), "pointing right, lit")
-- Straight down (1 to 3, not lit).
local down = Find(branchesNow, 190.4, -121.8)
Equal(down ~= nil, true, "a link down the column")
Near(down.h, 16.4, "from the first talent's foot to the next one's top")
Equal(Coords(game, down.region), Numbers(Look.Talent.LINK_ART.down[2]), "not lit")
Equal(Find(headsNow, 190.4, -125) ~= nil, true, "its head at the next one's top")
-- Down and across (2 to 4): a branch along the row, one down, the head.
local along = Find(branchesNow, 282.1, -80.8)
Equal(along ~= nil, true, "down and across: along the row first")
Near(along.w, 60.1, "to the far column")
local shaft = Find(branchesNow, 303.8, -100)
Equal(shaft ~= nil, true, "then down the column")
Near(shaft.h, 94.6, "to above the talent")
Equal(Find(headsNow, 303.8, -173) ~= nil, true, "and the head")
-- Up the tree (3 to 5): the game's own art kept.
local up = EdgeFrom(3, 5)
Equal(st[Field(up, "Line")].alpha, 1, "a link up the tree keeps the game's line")
Equal(st[Field(EdgeFrom(1, 2), "Line")].alpha, 0, "the others' lines faded")
Equal(st[Field(EdgeFrom(1, 2), "ArrowHead")].alpha, 0, "and their heads")
Equal(#branchesNow, 4, "four branches in all")
Equal(#headsNow, 3, "three heads")
-- The game places its talents again (all 10 further left): fitted again
-- to the same places, every link drawn again there.
game.pan = 10
panel:UpdateAllTalentButtonPositions()
NearSpot(byNode[2], 260, -100, "placed again by the game: fitted again")
Equal(Find(PiecesAt(branches), 221.8, -90.4) ~= nil, true, "the row's branch with the talents")
Equal(#PiecesAt(branches), 4, "none left over")
game.pan = 0
panel:UpdateAllTalentButtonPositions()
TreeFits(game, Look, panel, window, "placed again")
-- Another tree: the game lets go of every talent and link and makes them
-- again (from its pools); the pieces follow, none left over.
game.gate = true
game.Run(treeButtons[1], "OnClick", "LeftButton")
Equal(#PiecesAt(branches), 4, "a new tree: four branches again")
Equal(#PiecesAt(heads), 3, "three heads")
local gate
for g in Field(panel, "gatePool"):EnumerateActive() do gate = g end
Equal(st[Field(gate, "LockIcon")].alpha, 0, "a gate's modern lock faded")
Colour(st[Field(gate, "GateText")].textColour, L.RED, "its words in the old red")
TreeFits(game, Look, panel, window, "another tree")
Errors(game, "the Legacy Tree")

-- A tree bigger than the box (Squirt's Professions tree: four columns and
-- four rows 91 apart in the game's 920-wide window): its talents brought
-- closer together, every one inside the box, its middle on the box's; the
-- talents keep their size and their links follow them.
do
    local g, look = Session()
    local COLUMNS, ROWS = { 239, 330, 420, 511 }, { -85, -176, -267, -357 }
    g.nodes = {}
    for id, at in ipairs({ { 2, 1 }, { 1, 2 }, { 2, 2 }, { 3, 2 }, { 1, 3 }, { 2, 3 }, { 3, 3 }, { 4, 3 }, { 2, 4 } }) do
        table.insert(g.nodes, { id = id, x = COLUMNS[at[1]], y = ROWS[at[2]], state = id == 2 and "maxed" or "locked", ranks = id == 2 and 1 or 0 })
    end
    g.links = { { 1, 3, true }, { 3, 4, false }, { 5, 6, false }, { 7, 8, false }, { 6, 9, false } }
    local w = g.LoadAddOn()
    w:Show()
    g.Run(Field(w, "Tabs")[3], "OnMouseUp", "LeftButton", true)
    local p = Field(Field(w, "TreePage"), "LegacyTreeTraitPanel")
    TreeFits(g, look, p, w, "a big tree")
    local scale = look.Legacy.treeScale
    -- The box 242 tall; a talent reaches 24 above its middle (half its 46
    -- icon and the rim) and below it to its plate's drawn foot.
    local below = 46 / 2 - 2 + 41.4 * look.Legacy.PLATE_SEEN[2] / 2
    Near(scale.y, (242 - 24 - below) / 272, "brought closer by the box's room over the tree's height (272)")
    Near(scale.x, scale.y, "the same across (no two talents would touch)")
    local nodesNow = Field(p, "byNode")
    local a, b = g.st[nodesNow[2]].points.CENTER, g.st[nodesNow[3]].points.CENTER
    Near(b[4] - a[4], 91 * scale.x, "two talents in a row closer by that much")
    Equal(g.st[Field(nodesNow[1], "Icon")].width, 46, "each talent its own size")
    local drawn = 0
    for _, child in ipairs(g.st[Field(p, "ButtonsParent")].children) do
        if not g.st[child].game and g.st[child].level == 1050 then
            for _, region in ipairs(g.st[child].regions) do
                if g.st[region].shown then drawn = drawn + 1 end
            end
        end
    end
    Equal(drawn >= 4, true, "the links drawn between the closer talents")
    -- Shown again (the game loads the tree again, as on every show): fitted again.
    g.Run(Field(w, "Tabs")[1], "OnMouseUp", "LeftButton", true)
    g.Run(Field(w, "Tabs")[3], "OnMouseUp", "LeftButton", true)
    TreeFits(g, look, p, w, "the big tree shown again")
    Errors(g, "a big tree")
end

---------------------------------------------------------------------------
-- 6. The game's controls keep working
---------------------------------------------------------------------------

local controls = {}
for i, tab in ipairs(tabs) do Control(controls, tab, "page tab " .. i) end
Control(controls, close, "the X")
for i, button in ipairs(treeButtons) do Control(controls, button, "tree " .. i) end
for id, button in pairs(byNode) do Control(controls, button, "talent " .. id) end
Control(controls, apply, "Apply")
Control(controls, Field(panel, "UndoButton"), "undo")
Control(controls, Field(panel, "ResetButton"), "reset")
for i, row in ipairs(rows) do
    Control(controls, row, "category " .. i)
    Control(controls, Field(row, "CollapseButton"), "fold " .. i)
end
for i, card in ipairs(challengeCards) do
    Control(controls, card, "challenge " .. i)
    Control(controls, Field(card, "Shield"), "challenge " .. i .. "'s points (its tooltip)")
end
Control(controls, treeSummary, "the Legacy Tree's points (their tooltip)")
for i, card in ipairs(cards) do Control(controls, card, "reward " .. i) end
for _, key in ipairs({ "LeftButton", "RightButton" }) do Control(controls, Field(track, key), "track " .. key) end
Control(controls, filter, "the filter")
Control(controls, Field(list, "SearchBox"), "the challenge search")
Control(controls, Field(panel, "SearchBox"), "the tree search")
for _, entry in ipairs(controls) do
    local s = st[entry[1]]
    Equal(s.alpha, 1, entry[2] .. ": at full alpha")
    Equal(s.mouse, true, entry[2] .. ": takes the mouse")
end
-- Their scripts are the game's own: each set once, by the game.
local scriptsBefore = {}
for _, entry in ipairs(controls) do
    for script, fn in pairs(st[entry[1]].scripts) do scriptsBefore[entry[1]] = scriptsBefore[entry[1]] or {}; scriptsBefore[entry[1]][script] = fn end
end
L.Dress()
game.Tick(0.3)
for _, entry in ipairs(controls) do
    for script, fn in pairs(scriptsBefore[entry[1]] or {}) do
        Equal(st[entry[1]].scripts[script], fn, entry[2] .. ": its " .. script .. " still the game's")
    end
end
Equal(type(st[tabs[1]].scripts.OnMouseUp), "function", "the tabs keep their own click")
game.Run(Field(challengeCards[1], "Shield"), "OnEnter")
Equal(game.shieldTips, 1, "hovering a challenge's plate still shows the game's tooltip")
game.Run(treeSummary, "OnEnter")
Equal(game.summaryTips, 1, "hovering the Legacy Tree's points still shows the game's tooltip")
-- Every frame of EraUI's in the window: never takes the mouse.
local mine = game.FindAll(function(s, obj)
    if s.game or s.kind == "Texture" or s.kind == "FontString" or s.kind == "Font" or s.kind == "MaskTexture" then return false end
    local up = s.parent
    while up do
        if up == window then return true end
        up = st[up].parent
    end
    return false
end)
Equal(#mine >= 3, true, "EraUI's own frames found in the window")
for _, frame in ipairs(mine) do Equal(st[frame].mouse ~= true, true, "an EraUI frame in the window takes no mouse") end
-- Clicks still do the game's work.
game.Run(tabs[1], "OnMouseUp", "LeftButton", true)
Equal(rewards:IsVisible() and Raised(1), true, "the first tab back to the Progress Track")
game.Run(close, "OnClick", "LeftButton")
Equal(window:IsShown(), false, "the X closes the window")
Errors(game, "the controls")

-- A row the game makes while the window is open, with none of the calls
-- EraUI follows: dressed by the 0.1 s watch.
window:Show()
game.Run(tabs[2], "OnMouseUp", "LeftButton", true)
local rowPool
do
    local shown = Field(Field(list, "ScrollBox"), "frames")
    local extra = game.Make(function()
        local made = game.New("Button", nil, Field(list, "ScrollBox"))
        st[made].width, st[made].height = 300, 25
        made:SetNormalTexture("Legacy-Challenge-Left-Sub-Tab")
        made:SetHighlightTexture("Legacy-Challenge-Left-Sub-Tab")
        game.Text(made, "ButtonText", "ARTWORK", { 1, 0.82, 0 }):SetText("Shaman")
        return made
    end)
    table.insert(shown, extra)
    rowPool = extra
end
game.Tick(0.15)
Equal(st[rowPool:GetNormalTexture()].alpha, 0, "a row made outside the game's usual calls: dressed by the watch")
Colour(st[Field(rowPool, "ButtonText")].textColour, INK, "and painted")
Errors(game, "the watch")

---------------------------------------------------------------------------
-- 7. Dark Mode, Dark Windows and Black Pages (the real Core/Appearance.lua)
---------------------------------------------------------------------------

do
    local dark = Session({ appearance = true, settings = { darkMode = true, darkWindows = true, blackPages = false, darkModeDarkness = 58 } })
    local darkWindow = dark.LoadAddOn()
    darkWindow:Show()
    local lookD = dark.Look
    local piece = Piece(lookD, darkWindow, "sheetTopLeft")
    local shade = { dark.ns.DarkPageShade() }
    for _, name in ipairs({ "TopLeft", "TopRight", "BotLeft", "BotRight" }) do
        Colour(dark.st[Piece(lookD, darkWindow, "sheet" .. name)].colour, shade,
            "Dark Windows: the spellbook's " .. name .. " piece in the page shade, as the spellbook's")
    end
    Equal(dark.st[Piece(lookD, darkWindow, "cover")].shown, false, "no cover without Black Pages")
    local card = Field(Field(Field(darkWindow, "RewardTrackPage"), "LegacyRewardProgressFrame"), "Elements")[4]
    Colour(dark.st[Field(card, "RewardName")].textColour, dark.ns.DARK_PAGE_TEXT, "brown page text turns light")
    Colour(dark.st[Field(Field(darkWindow, "RewardTrackPage"), "PointsLabel")].textColour, GOLD, "gold names stay gold")
    -- The Legacy points: the ring trim like the tree's, the numbers kept
    -- readable (gold in the ring, white on the plates, which keep their own
    -- colours).
    local rewardsD = Field(darkWindow, "RewardTrackPage")
    local ringD = Piece(lookD, rewardsD, "pointsRing")
    local headerD = Field(Field(Field(darkWindow, "ChallengesPage"), "LegacyChallengePointSummary"), "Shield")
    local treeHeaderD = Field(Field(Field(darkWindow, "TreePage"), "LegacyTreePointSummary"), "Shield")
    local function PointsReadable(label)
        Colour(dark.st[Field(rewardsD, "Points")].textColour, GOLD, label .. ": the points in the ring stay gold")
        for _, shield in ipairs({ headerD, treeHeaderD }) do
            Colour(dark.st[Field(shield, "Points")].textColour, { 1, 1, 1 }, label .. ": a header's number stays white")
            Colour(dark.st[Piece(lookD, shield, "plate")].colour, { 1, 1, 1 }, label .. ": on its plate in the plate's own colours")
        end
    end
    Colour(dark.st[ringD].colour, shade, "Dark Windows: the points ring in the page shade, as the tree's emblem ring")
    PointsReadable("Dark Windows")
    dark.settings.blackPages = true
    dark.ns.RefreshDarkWindows()
    local coverD = dark.st[Piece(lookD, darkWindow, "cover")]
    Equal(coverD.shown, true, "Black Pages: the cover over the parchment")
    Colour(coverD.solid, dark.ns.DARK_BLACK_COVER, "in its near black")
    do
        local l, t, r, f = Box(dark, Piece(lookD, darkWindow, "cover"), darkWindow)
        Equal(string.format("%g,%g to %g,%g", l, t, r, f), "7,60 to 329,416", "exactly over the parchment, as the spellbook's cover")
    end
    Colour(dark.st[piece].colour, { dark.ns.DarkGrey() }, "the frame pieces take Dark Mode's grey")
    Colour(dark.st[ringD].colour, { dark.ns.DarkGrey() }, "Black Pages: the points ring takes the grey too, so it shows on the black")
    Colour(dark.st[Piece(lookD, rewardsD, "pointsDisc")].colour, L.DISC, "its disc keeps its dark")
    PointsReadable("Black Pages")
    dark.settings.darkModeDarkness = 90
    dark.ns.RefreshDarkWindows()
    Colour(dark.st[piece].colour, { dark.ns.DarkGrey() }, "and follow the Darkness slider")
    dark.settings.darkWindows = false
    dark.ns.RefreshDarkWindows()
    Equal(dark.st[Piece(lookD, darkWindow, "cover")].shown, false, "Dark Windows off: the cover goes")
    Colour(dark.st[piece].colour, { 1, 1, 1 }, "the pieces their own colours")
    -- Black Pages on, the look off (its cover hidden with it) and on again
    -- in the same session: the cover comes back.
    dark.settings.darkWindows = true
    dark.ns.RefreshDarkWindows()
    Equal(dark.st[Piece(lookD, darkWindow, "cover")].shown, true, "Black Pages again: the cover")
    dark.ns.db.legacyWindow = false
    dark.Pass()
    Equal(dark.st[Piece(lookD, darkWindow, "cover")].shown, false, "the look off: the cover hidden")
    dark.ns.db.legacyWindow = true
    dark.Pass()
    Equal(dark.st[Piece(lookD, darkWindow, "cover")].shown, true, "the look on again: the cover back over the parchment")
    Errors(dark, "Dark Mode")
end

---------------------------------------------------------------------------
-- 8. Nothing in a fight
---------------------------------------------------------------------------

do
    local fight, lookF = Session()
    fight.combat = true
    local fightWindow = fight.LoadAddOn()
    fightWindow:Show()
    local LF = lookF.Legacy
    Equal(LF.applied, false, "loaded in a fight: nothing dressed")
    Equal(fight.st[Field(fightWindow, "NineSlice")].alpha, 1, "the game's frame untouched")
    Equal(fight.st[fightWindow].width .. "x" .. fight.st[fightWindow].height, "920x575", "the game's own size until the fight ends")
    Equal(Piece(lookF, fightWindow, "sheetTopLeft"), nil, "no art of EraUI's made")
    Equal(fight.st[Field(fightWindow, "Tabs")[1]].width, 61, "the tabs untouched")
    Equal(fight.st[Field(Field(fightWindow, "RewardTrackPage"), "Icon")].alpha, 1, "the Progress Track's crown untouched")
    Equal(Piece(lookF, Field(fightWindow, "RewardTrackPage"), "pointsRing"), nil, "no ring made")
    Equal(LF.booked, true, "booked for the fight's end")
    fight.Tick(0.3)
    Equal(LF.applied, false, "the watch waits too")
    fight.combat = false
    fight.Fire("PLAYER_REGEN_ENABLED")
    Equal(LF.applied and fight.st[Field(fightWindow, "NineSlice")].alpha == 0, true, "dressed when the fight ends")
    Equal(fight.st[fightWindow].width .. "x" .. fight.st[fightWindow].height, "336x422", "at the spellbook's size then")
    do
        local t = Field(Field(fightWindow, "RewardTrackPage"), "LegacyRewardProgressFrame")
        CardsDown(fight, lookF, Field(t, "Elements"), Field(t, "ClipFrame"), fightWindow, "dressed at the fight's end")
    end
    -- Dressed, then a fight: the game's refresh isn't painted over.
    local page = Field(fightWindow, "RewardTrackPage")
    local card = Field(Field(page, "LegacyRewardProgressFrame"), "Elements")[4]
    fight.combat = true
    fight.renown = 1
    page:OnTrackUpdate()
    Colour(fight.st[Field(card, "RewardName")].textColour, { 0.5, 0.5, 0.5 }, "in a fight the game's own colour stays")
    fight.Tick(0.3)
    Colour(fight.st[Field(card, "RewardName")].textColour, { 0.5, 0.5, 0.5 }, "the watch waits")
    fight.combat = false
    fight.Fire("PLAYER_REGEN_ENABLED")
    Colour(fight.st[Field(card, "RewardName")].textColour, INK, "painted again when the fight ends (the window open)")
    Errors(fight, "the fight")
end

-- Dressed, then a fight. Each time a page shows, the game hands its pooled
-- cards, rows, talents and links out again (the tree loads again whole):
-- EraUI's own tabs, checks, bars, sockets and links follow, so none points
-- at the wrong thing or goes missing; the game's own pieces keep what the
-- game set until the fight ends. (The game's own Challenges page here, with
-- its gamepad mode on; EraUI's own page in a fight: section 4b.)
do
    local g, lookG = Session({ gamepad = true })
    local LG = lookG.Legacy
    local w = g.LoadAddOn()
    w:Show()
    local tabsG = Field(w, "Tabs")
    local function RaisedG(i) return g.st[Piece(lookG, tabsG[i], "tabOn")].shown and not g.st[Piece(lookG, tabsG[i], "tabOff")].shown end
    g.Run(tabsG[2], "OnMouseUp", "LeftButton", true)
    g.Run(tabsG[3], "OnMouseUp", "LeftButton", true)
    local treePage = Field(w, "TreePage")
    local panelG = Field(treePage, "LegacyTreeTraitPanel")
    local holderG = Field(panelG, "ButtonsParent")
    local branchesG, headsG
    for _, child in ipairs(g.st[holderG].children) do
        if not g.st[child].game and g.st[child].level == 1050 then branchesG = child end
        if not g.st[child].game and g.st[child].level == 1150 then headsG = child end
    end
    local function Seen(layer)
        local n = 0
        for _, region in ipairs(g.st[layer].regions) do
            if g.Visible(region) then n = n + 1 end
        end
        return n
    end
    -- How one link shows: "1.x" (EraUI's branch at its place), "game" (the
    -- game's own line) or "none".
    local function LinkLook(a, b, x, y)
        local byNodeG = Field(panelG, "byNode")
        for edge in Field(panelG, "edgePool"):EnumerateActive() do
            if Field(edge, "startButton") == byNodeG[a] and Field(edge, "endButton") == byNodeG[b] then
                for _, region in ipairs(g.st[branchesG].regions) do
                    local at = g.st[region].points.TOPLEFT
                    if g.Visible(region) and at and math.abs(at[4] - x) < 1e-3 and math.abs(at[5] - y) < 1e-3 then return "1.x" end
                end
                return g.st[Field(edge, "Line")].alpha == 1 and "game" or "none"
            end
        end
        return "missing"
    end
    -- Each link's first branch where the game's tree has it, moved as the
    -- tree was moved to its box.
    local dx = g.st[Field(panelG, "byNode")[1]].points.CENTER[4] - 200
    local dy = g.st[Field(panelG, "byNode")[1]].points.CENTER[5] + 100
    -- (The tree spread across as in section 5: talent 2 at 261.5.)
    local LINKS = { { 1, 2, 221.8 + dx, -90.4 + dy }, { 1, 3, 190.4 + dx, -121.8 + dy }, { 2, 4, 282.1 + dx, -80.8 + dy } }
    Equal(Seen(branchesG) .. "/" .. Seen(headsG), "4/3", "before the fight: the tree's links drawn")
    w:Hide()
    Equal(Seen(branchesG) + Seen(headsG), 0, "the window closed: its links hidden with it")

    g.combat = true
    local stopWatch = FightWatch(g, Field(panelG, "talentButtonCollection"))
    -- The game's states change, then the window opens in the fight on the
    -- tree, which loads again from the pools.
    g.nodes[1].state, g.nodes[3].state = "open", "maxed"
    g.nodes[2].max = 5
    w:Show()
    Equal(treePage:IsVisible() and LG.applied, true, "opened on the Legacy Tree in the fight")
    -- The size and layout hold: the game set none of it again; the tree it
    -- loaded again is fitted again in the fight (the talents' anchors).
    Equal(g.st[w].width .. "x" .. g.st[w].height, "336x422", "in a fight: the window still the spellbook's size")
    TreeFits(g, lookG, panelG, w, "in a fight, the tree loaded again")
    Equal(Anchor(g, Field(panelG, "ApplyButton")), "CENTER LegacySystemFrame TOPLEFT 148,-390", "in a fight: Apply still at the foot")
    local drawn = 0
    for _, link in ipairs(LINKS) do
        local look = LinkLook(link[1], link[2], link[3], link[4])
        Equal(look == "1.x" or look == "game", true, "in a fight: the link " .. link[1] .. " to " .. link[2] .. " still shows (" .. look .. ")")
        if look == "1.x" then drawn = drawn + 1 end
    end
    Equal(drawn >= 2, true, "in a fight: the links EraUI took over before drawn again on the talents the game handed out")
    local byNodeG = Field(panelG, "byNode")
    for id, state in pairs({ [1] = "open", [2] = "open", [3] = "learned", [4] = "locked", [5] = "locked" }) do
        Colour(g.st[Piece(lookG, byNodeG[id], "socket")].colour, LG.STATE[state], "in a fight: talent " .. id .. "'s socket follows the game's state")
        Equal(g.st[Field(byNodeG[id], "StateBorder")].alpha, 0, "talent " .. id .. ": the game's border stays faded")
    end
    -- Their ranks too (EraUI's own label and box): from the node each one
    -- was handed (one with more ranks now), in its state's colour; the
    -- game's rank text stays faded.
    for id, rank in pairs({ [1] = { "1/1", "1/1", "open" }, [2] = { "0/5", "5/5", "open" }, [3] = { "0/3", "3/3", "learned" },
        [4] = { "0/5", "5/5", "locked" }, [5] = { "0/1", "1/1", "locked" } }) do
        RankBox(g, lookG, byNodeG[id], rank[1], rank[2], LG.STATE[rank[3]], "in a fight: talent " .. id)
    end
    -- A page chosen in the fight: its tab raised, the cards' checks and
    -- slots following the game's; the names keep the game's colours.
    g.renown = 1
    g.Run(tabsG[1], "OnMouseUp", "LeftButton", true)
    Equal(RaisedG(1) and not RaisedG(3), true, "a page chosen in a fight raises its own tab")
    local trackG = Field(Field(w, "RewardTrackPage"), "LegacyRewardProgressFrame")
    -- The game laid its cards in a row again: laid down the page again.
    CardsDown(g, lookG, Field(trackG, "Elements"), Field(trackG, "ClipFrame"), w, "in a fight")
    local cardsG = Field(trackG, "Elements")
    for i, card in ipairs(cardsG) do
        Equal(g.st[Piece(lookG, card, "check")].shown, i <= 1, "in a fight: card " .. i .. "'s check follows the game's")
        Equal(g.st[Piece(lookG, card, "socket")].desaturated, i > 1, "in a fight: card " .. i .. "'s slot follows it too")
    end
    Colour(g.st[Field(cardsG[2], "RewardName")].textColour, { 0.5, 0.5, 0.5 }, "in a fight the names keep the game's colours")
    -- The challenges in the fight: no category picked any more and no
    -- challenge done (so a mark left on whichever row or card the game
    -- hands out again would show).
    for _, data in ipairs(g.categories) do data.selected = nil end
    for _, data in ipairs(g.challenges) do data.completed = nil end
    -- And the Legacy points change in the fight, the challenges' with them
    -- (one worth none now): the game's own numbers stay on EraUI's plates and
    -- in its ring; EraUI's own copies follow the cards handed out again.
    g.challenges[1].points, g.challenges[2].points = 0, 7
    g.SetPoints(20)
    local rewardsG = Field(w, "RewardTrackPage")
    Equal(g.st[Field(rewardsG, "Points")].text, "20", "in a fight: the Progress Track's points the game's new ones")
    Colour(g.st[Field(rewardsG, "Points")].textColour, GOLD, "still gold")
    Equal(Anchor(g, Field(rewardsG, "Points")), "CENTER LegacySystemFrame TOPLEFT 56,-106", "still in the ring")
    Equal(g.st[Field(rewardsG, "Icon")].alpha, 0, "the crown still faded")
    g.Run(tabsG[2], "OnMouseUp", "LeftButton", true)
    Equal(RaisedG(2), true, "its tab raised")
    local headerG = Field(Field(Field(w, "ChallengesPage"), "LegacyChallengePointSummary"), "Shield")
    Equal(g.st[Field(headerG, "Points")].text, "20", "in a fight: the header's points the game's new ones")
    Equal(Anchor(g, Field(headerG, "Points")) .. " / " .. tostring(g.st[Field(headerG, "Icon")].alpha), "CENTER StatusBar LEFT -20,0 / 0",
        "still on the plate, the crown still faded")
    for i, card in ipairs(Field(Field(Field(Field(w, "ChallengesPage"), "DetailPane"), "ScrollBox"), "frames")) do
        ChallengePoints(g, lookG, card, g.challenges[Field(card, "id")].points, "in a fight, challenge " .. i)
    end
    Equal(Anchor(g, Field(Field(w, "ChallengesPage"), "CategoryList"), "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 8,-62",
        "in a fight: the categories still on the top part")
    Equal(Anchor(g, Field(Field(w, "ChallengesPage"), "DetailPane"), "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 8,-220",
        "and the challenges under them")
    local listG = Field(Field(w, "ChallengesPage"), "CategoryList")
    local rowsG = Field(Field(listG, "ScrollBox"), "frames")
    for i, row in ipairs(rowsG) do
        Equal(g.st[Piece(lookG, row, "pick")].shown, false, "in a fight: no highlight bar left on row " .. i)
    end
    Colour(g.st[Field(rowsG[2], "ButtonText")].textColour, GOLD, "the words keep the game's colour in the fight")
    local cardBox = Field(Field(Field(w, "ChallengesPage"), "DetailPane"), "ScrollBox")
    for i, card in ipairs(Field(cardBox, "frames")) do
        Equal(g.st[Piece(lookG, Field(card, "Shield"), "check")].shown, false, "in a fight: no check left on challenge " .. i)
    end
    -- Back on the tree, still in the fight: it loads again.
    g.Run(tabsG[3], "OnMouseUp", "LeftButton", true)
    for _, link in ipairs(LINKS) do
        local look = LinkLook(link[1], link[2], link[3], link[4])
        Equal(look == "1.x" or look == "game", true, "in a fight again: the link " .. link[1] .. " to " .. link[2] .. " shows (" .. look .. ")")
    end
    Equal(stopWatch(), "", "in a fight: nothing of the game's talent pieces touched by EraUI")
    Errors(g, "a fight after dressing")

    -- The fight ends with the tree open: every link drawn again without the
    -- game loading the tree, and the rest painted again.
    g.combat = false
    g.Fire("PLAYER_REGEN_ENABLED")
    for _, link in ipairs(LINKS) do
        Equal(LinkLook(link[1], link[2], link[3], link[4]), "1.x", "the fight over: the link " .. link[1] .. " to " .. link[2] .. " in the 1.x art")
    end
    Equal(Seen(branchesG) .. "/" .. Seen(headsG), "4/3", "four branches and three heads, none left over")
    local upEdge
    for edge in Field(panelG, "edgePool"):EnumerateActive() do
        if Field(edge, "startButton") == Field(panelG, "byNode")[3] and Field(edge, "endButton") == Field(panelG, "byNode")[5] then upEdge = edge end
    end
    Equal(g.st[Field(upEdge, "Line")].alpha, 1, "a link up the tree has the game's line again")
    Colour(g.st[Field(rowsG[2], "ButtonText")].textColour, INK, "a category in brown again")
    Errors(g, "after the fight")

    -- The game handing two of its links new talents in a fight (as its
    -- pools do): the one EraUI took over gets a pair it can't draw (up the
    -- tree), the one showing the game's art a pair it could.
    local byNodeNow = Field(panelG, "byNode")
    local taken
    for edge in Field(panelG, "edgePool"):EnumerateActive() do
        if Field(edge, "startButton") == byNodeNow[1] and Field(edge, "endButton") == byNodeNow[2] then taken = edge end
    end
    g.combat = true
    g.Own(taken, "startButton", byNodeNow[3])
    g.Own(taken, "endButton", byNodeNow[5])
    taken:UpdateState()
    g.Own(upEdge, "startButton", byNodeNow[1])
    g.Own(upEdge, "endButton", byNodeNow[2])
    upEdge:UpdateState()
    Equal(g.st[Field(taken, "Line")].alpha, 0, "in a fight: the game's line EraUI faded stays faded")
    Equal(g.st[Field(upEdge, "Line")].alpha, 1, "in a fight: the game's own line that shows stays shown (EraUI fades nothing then)")
    Equal(LinkLook(1, 2, LINKS[1][3], LINKS[1][4]), "game", "so that link shows the game's art until the fight ends")
    g.combat = false
    g.Fire("PLAYER_REGEN_ENABLED")
    Equal(g.st[Field(taken, "Line")].alpha, 1, "the fight over: the link up the tree gets the game's line back")
    Equal(LinkLook(1, 2, LINKS[1][3], LINKS[1][4]), "1.x", "and the other is drawn in the 1.x art")
    Errors(g, "links handed out in a fight")
end

---------------------------------------------------------------------------
-- 9. Off
---------------------------------------------------------------------------

ns.db.legacyWindow = false
game.Pass()
Equal(L.active, false, "off")
Equal(ns.needsReload, true, "a reload asked for (the shared 1.x skins clear then)")
Equal(st[Field(window, "NineSlice")].alpha, 1, "off: the game's nine-slice back")
Equal(st[Field(rewards, "Background")].alpha, 1, "a page's backdrop back")
Equal(st[Piece(Look, window, "sheetTopLeft")].shown, false, "the spellbook's pieces hidden")
Equal(st[Piece(Look, window, "disc")].shown, false, "the disc hidden")
-- The game's own size and layout back.
Equal(st[window].width .. "x" .. st[window].height, "920x575", "off: the window its own size")
Equal(Anchor(game, window), "TOPLEFT UIParent TOPLEFT 51,-116", "where the game put it")
Equal(Anchor(game, list, "TOPLEFT") .. " / " .. Anchor(game, list, "BOTTOMLEFT"), "TOPLEFT Frame TOPLEFT 6,-80 / BOTTOMLEFT Frame BOTTOMLEFT 0,8",
    "the categories back down the left")
Equal(Anchor(game, pane, "BOTTOMRIGHT") .. " " .. tostring(st[pane].points.TOPLEFT), "BOTTOMRIGHT Frame BOTTOMRIGHT -24,8 nil",
    "the challenges back at the right")
Equal(st[summary].width .. " " .. Anchor(game, summary), "520 TOPLEFT Frame TOPLEFT 280,-25", "the points bar back in the header")
Equal(st[track].width .. "x" .. st[track].height .. " " .. Anchor(game, track), "849x270 TOP StatusBar BOTTOM 0,2", "the track back under its bar")
for i, card in ipairs(Field(track, "Elements")) do
    Equal(st[card].width .. "x" .. st[card].height, "216x241", "off: card " .. i .. " its own size")
    if i == 1 then
        Equal(Anchor(game, card), "LEFT Frame LEFT 0,0", "off: the first card at the track's left, as the game lays it")
    else
        Equal(Anchor(game, card) .. " " .. tostring(st[card].points.LEFT[2] == Field(track, "Elements")[i - 1]), "LEFT Frame RIGHT -5,0 true",
            "off: card " .. i .. " after the one before, in the game's row")
    end
    Equal(st[Field(card, "Icon")].width .. " " .. st[Field(card, "RewardName")].width .. " " .. st[Field(card, "RewardName")].justify,
        "64 120 CENTER", "off: card " .. i .. "'s icon and name their own")
end
Equal(st[panel].width .. "x" .. st[panel].height .. " " .. Anchor(game, panel), "775x550 BOTTOMRIGHT Frame BOTTOMRIGHT -6,8", "the tree's panel back")
Equal(Anchor(game, Field(panel, "byNode")[2]), "CENTER Frame TOPLEFT 260,-100", "a talent back where the game put it")
Equal(Anchor(game, apply), "BOTTOM Frame BOTTOM 0,10", "Apply back")
Equal(Anchor(game, emblem), "LEFT Frame LEFT 55,20", "the emblem back")
for i, card in ipairs(Field(Field(pane, "ScrollBox"), "frames")) do
    Equal(st[Field(card, "Description")].width .. " " .. st[Field(card, "Label")].width, "400 320", "off: challenge " .. i .. "'s text its own width")
    Equal(Anchor(game, Field(Field(card, "Shield"), "DateCompleted")), "RIGHT Texture LEFT 0,0", "off: challenge " .. i .. "'s date beside its check again")
    Equal(st[Field(card, "Shield")].width .. " " .. Anchor(game, Field(card, "Shield")), "64 TOPRIGHT EventButton TOPRIGHT -6,-2",
        "off: challenge " .. i .. "'s crown back at the right")
end
Equal(st[tabs[1]].width .. "x" .. st[tabs[1]].height, "61x55", "the tabs their own size")
Equal(Anchor(game, tabs[1]), "TOPLEFT LegacySystemFrame TOPRIGHT 0,-60", "back down the right side")
Equal(st[Piece(Look, tabs[1], "tabOn")].shown or st[Piece(Look, tabs[1], "tabOff")].shown, false, "the red-brown tab art hidden")
Equal(st[Field(tabs[1], "TabGlow")].colour[4], 1, "the tab glow's colour back")
Equal(st[portrait].width .. "x" .. st[portrait].height, "45x62", "the crest its own size")
Equal(Anchor(game, portrait), "TOPLEFT LegacySystemFrame TOPLEFT 2,10", "in its own place")
Equal(Anchor(game, titles, "TOPLEFT"), "TOPLEFT LegacySystemFrame TOPLEFT 58,-1", "the title in its own place")
Equal(st[treeButtons[1]].width, 67, "the tree buttons their own size")
Equal(st[emblem].width, 110, "the emblem its own size")
Equal(Anchor(game, Field(byNode[1], "SpendText")), "BOTTOM Button BOTTOM 11,4", "a rank in its own place")
Equal(st[Field(byNode[1], "StateBorder")].alpha, 1, "a talent's border back")
Equal(st[Piece(Look, byNode[1], "socket")].shown, false, "its socket hidden")
for id, button in pairs(Field(panel, "byNode")) do
    Equal(st[Field(button, "SpendText")].alpha, 1, "off: talent " .. id .. "'s own rank text back")
    for _, purpose in ipairs({ "plate", "plateLeft", "plateRight", "rank" }) do
        Equal(st[Piece(Look, button, purpose)].shown, false, "off: talent " .. id .. ": EraUI's rank box hidden (" .. purpose .. ")")
    end
end
Equal(#PiecesAt(branches) + #PiecesAt(heads), 0, "no link pieces left")
-- The game's crowns back, their numbers in them as the game had them.
Equal(st[crown].alpha, 1, "off: the Progress Track's crown back")
Equal(Anchor(game, bigPoints), "CENTER Texture CENTER 0,-10", "its number back in it")
Colour(st[bigPoints].textColour, { 1, 1, 1 }, "in the game's white")
Equal(st[pointsRing].shown or st[pointsDisc].shown, false, "the ring and disc hidden")
for _, shield in ipairs({ headerShield, treeShield }) do
    local number = Field(shield, "Points")
    Equal(st[Field(shield, "Icon")].alpha, 1, "off: a header's crown back")
    Equal(Anchor(game, number), "TOPRIGHT Button TOPRIGHT -2,-31", "its number back in it")
    Equal(st[number].font, game.env.GameFontNormalMed3, "in its own font")
    Colour(st[number].textColour, { 1, 1, 1 }, "white again (put back after its font, which brings gold)")
    Equal(st[Piece(Look, shield, "plate")].shown, false, "the plate hidden")
end
for i, card in ipairs(Field(Field(pane, "ScrollBox"), "frames")) do
    local shield = Field(card, "Shield")
    Equal(st[Field(shield, "Icon")].alpha .. "/" .. st[Field(shield, "Points")].alpha, "1/1", "off: challenge " .. i .. "'s crown and number back")
    Equal(st[Piece(Look, shield, "plate")].shown or st[Piece(Look, shield, "points")].shown, false, "EraUI's plate and number hidden")
end
-- The game's refresh is its own again.
window:Show()
game.Run(tabs[1], "OnMouseUp", "LeftButton", true)
rewards:OnTrackUpdate()
Colour(st[Field(Field(track, "Elements")[4], "RewardName")].textColour, { 0.5, 0.5, 0.5 }, "off: the game's own colours, not painted over")
game.Pass()
Equal(L.applied, false, "another pass while off changes nothing")
Errors(game, "off")

-- On again in the same session: everything dressed afresh.
ns.db.legacyWindow = true
game.Pass()
Equal(L.applied, true, "on again: dressed")
Equal(st[Piece(Look, window, "sheetTopLeft")].shown and st[Field(window, "NineSlice")].alpha == 0, true, "the frame dressed again")
Equal(st[window].width .. "x" .. st[window].height, "336x422", "on again: the spellbook's size")
CardsDown(game, Look, Field(track, "Elements"), clip, window, "on again")
Equal(st[tabs[1]].width .. " " .. Anchor(game, tabs[1]), "100 TOPLEFT LegacySystemFrame BOTTOMLEFT 14,2", "the tabs along the foot again")
Equal(Raised(1) and not Raised(2), true, "the shown page's tab raised again")
Colour(st[Field(Field(track, "Elements")[1], "RewardName")].textColour, GOLD, "the cards painted again")
Equal(st[Piece(Look, Field(track, "Elements")[1], "socket")].shown, true, "their slots shown again")
game.Run(tabs[3], "OnMouseUp", "LeftButton", true)
for id, button in pairs(Field(panel, "byNode")) do
    Equal(st[Piece(Look, button, "socket")].shown, true, "talent " .. id .. ": its socket back")
end
Equal(#PiecesAt(branches), 4, "the links drawn again")
Equal(#PiecesAt(heads), 3, "with their heads")
TreeFits(game, Look, panel, window, "on again")
game.Run(tabs[2], "OnMouseUp", "LeftButton", true)
Equal(st[crown].alpha .. " " .. tostring(st[pointsRing].shown), "0 true", "on again: the points back in the ring")
HeaderPlate(headerShield, "StatusBar", -20, "on again, the Challenges header")
HeaderPlate(treeShield, "FontString", -16, "on again, the Legacy Tree header")
for i, card in ipairs(Field(Field(pane, "ScrollBox"), "frames")) do
    ChallengePoints(game, Look, card, game.challenges[Field(card, "id")].points, "on again, challenge " .. i)
end
local seenPieces = 0
for _, layer in ipairs({ branches, heads }) do
    for _, region in ipairs(st[layer].regions) do
        if game.Visible(region) then seenPieces = seenPieces + 1 end
    end
end
Equal(seenPieces, 0, "the tree hidden: its link pieces hidden with it")
Errors(game, "on again")
ns.db.legacyWindow = false
game.Pass()

do
    local fresh, lookO = Session({ off = true })
    local offWindow = fresh.LoadAddOn()
    offWindow:Show()
    fresh.Tick(0.3)
    Equal(lookO.Legacy.applied, false, "off from login: nothing dressed")
    Equal(fresh.st[Field(offWindow, "NineSlice")].alpha, 1, "the game's frame as it is")
    Equal(Piece(lookO, offWindow, "sheetTopLeft"), nil, "no art of EraUI's")
    Equal(fresh.st[offWindow].width, 920, "the window its own size")
    Equal(fresh.hookCounts[offWindow], nil, "no hook on the game's window")
    Equal(fresh.st[Field(offWindow, "Tabs")[1]].width, 61, "the tabs the game's")
    Errors(fresh, "off from login")
end

---------------------------------------------------------------------------
-- 10. Squirt's in-game round (22 Oct, private server, screenshots 474-487)
---------------------------------------------------------------------------

-- 10a. The ink on the normal parchment: the quest log's (Look/QuestLogDetail.lua
-- Inks(): its details' brown, the grey of a finished objective), dark enough
-- to read on the parchment as it shows in game (sampled from screenshot 481:
-- 153, 119, 75). The first build's "faded" ink (0.45, 0.36, 0.24) came out at
-- 1.5 : 1 there, the near-invisible "0 / 3".
do
    local LK = Look.Legacy
    Colour(LK.INK, { 0.18, 0.12, 0.06 }, "the ink: the quest log's brown")
    Colour(LK.FADED_INK, { 0.2, 0.2, 0.2 }, "greyed: the quest log's grey for a finished objective")
    local function Linear(c) return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
    local function Luminance(rgb) return 0.2126 * Linear(rgb[1]) + 0.7152 * Linear(rgb[2]) + 0.0722 * Linear(rgb[3]) end
    local function Contrast(a, b)
        local la, lb = Luminance(a), Luminance(b)
        return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
    end
    local PAGE = { 153 / 255, 119 / 255, 75 / 255 }
    Equal(Contrast(LK.INK, PAGE) >= 3.5, true, "the ink reads on the parchment (" .. string.format("%.2f", Contrast(LK.INK, PAGE)) .. " : 1)")
    Equal(Contrast(LK.FADED_INK, PAGE) >= 3, true, "greyed text still reads (" .. string.format("%.2f", Contrast(LK.FADED_INK, PAGE)) .. " : 1)")
    Equal(Luminance(LK.FADED_INK) > Luminance(LK.INK), true, "and is lighter than the ink, so it shows as greyed")
end
-- Dark Windows keeps its colours: the game's card for a challenge not done
-- (the gamepad page) in dim gold with the black shadow, as before; without
-- Dark Windows it is ink (section 4).
do
    local g, look = Session({ appearance = true, gamepad = true, settings = { darkMode = true, darkWindows = true, blackPages = true, darkModeDarkness = 58 } })
    local w = g.LoadAddOn()
    w:Show()
    g.Run(Field(w, "Tabs")[2], "OnMouseUp", "LeftButton", true)
    local paneD = Field(Field(w, "ChallengesPage"), "DetailPane")
    local cardsD = Field(Field(paneD, "ScrollBox"), "frames")
    Colour(g.st[Field(cardsD[2], "Label")].textColour, DIM, "Dark Windows: one not done in dim gold, as before")
    Equal(g.st[Field(cardsD[2], "Label")].shadowColour[4], 1, "with its black shadow")
    Colour(g.st[Field(cardsD[1], "Label")].textColour, GOLD, "a done one gold")
    -- The game's thin bars (this page's): their 1.x knob out of Dark Mode's tint too.
    local listD = Field(Field(w, "ChallengesPage"), "CategoryList")
    for _, bar in ipairs({ Field(listD, "ScrollBar"), Field(paneD, "ScrollBar") }) do
        local knob = look.OwnPiece(Field(bar, "Track"), "knob")
        Equal(knob ~= nil and g.st[knob].file, look.MEDIA .. "UI-ScrollBar-Knob", "the gamepad page's bar: the 1.x knob")
        Colour(g.st[knob].colour, { 1, 1, 1 }, "in its own colours in Dark Mode")
    end
    Errors(g, "10a: Dark Windows keeps its colours")
end

-- 10b. The Challenges details: room for a usual challenge's whole details.
-- The mock gives every line 12; here the lines take the game's heights (the
-- title 20, the quest font 15 a line, the small fonts 13) and wrap at the
-- line's width (about 6.6 across a letter, 6 in the small fonts), as in
-- game, where "Earn 1 Legacy Point." was cut off at the foot (482).
do
    local g, look = Session()
    local Proto = getmetatable(g.env.UIParent).__index
    local LINE = { GameFontNormalLarge = 20, QuestTitleFont = 20, GameFontHighlight = 15, QuestFont = 15,
        GameFontHighlightSmall = 13, GameFontNormalSmall = 13, QuestFontNormalSmall = 13 }
    local own = Proto.GetStringHeight
    Proto.GetStringHeight = function(self)
        local s = g.st[self]
        local font = type(s.font) == "string" and s.font or (type(s.font) == "table" and s.font:GetName()) or ""
        local line = LINE[font] or 14
        local letter = line >= 20 and 10 or (line >= 15 and 6.6 or 6)
        local wide = (s.width or 0) > 0 and s.width or 1e9
        return math.max(1, math.ceil(#tostring(s.text or "") * letter / wide)) * line
    end
    for _, key in ipairs({ "WarriorNovice", "WarriorExperienced", "WarriorMaster" }) do g.achs[g[key]].reward = "Earn 1 Legacy Point." end
    -- One with no objective of its own (as Novice Warrior shows in game).
    g.achs[g.WarriorExperienced].criteria = {}
    local C = look.Legacy.ChallengeList
    local w = g.LoadAddOn()
    w:Show()
    g.Run(Field(w, "Tabs")[2], "OnMouseUp", "LeftButton", true)
    g.NextFrame()
    Equal(C.DETAIL_H, 170, "the details' part 170 tall (114 before)")
    for _, key in ipairs({ "WarriorNovice", "WarriorExperienced", "WarriorMaster" }) do
        C.Want(g[key])
        Equal(C.sel, g[key], key .. ": chosen")
        Equal(g.st[C.detailBar].max, 0, key .. ": its whole details show, nothing to scroll")
        Equal(g.st[C.detailBar:GetThumbTexture()].shown, false, key .. ": so its bar shows no knob, as 1.x's")
        local reward, deepest = nil, 0
        for _, region in ipairs(g.st[C.sheet].regions) do
            local s = g.st[region]
            if s.kind == "FontString" and s.shown and s.points.TOPLEFT and s.text and s.text ~= "" then
                local foot = -s.points.TOPLEFT[5] + region:GetStringHeight()
                deepest = math.max(deepest, foot)
                if s.text == "Earn 1 Legacy Point." then reward = foot end
            end
        end
        Equal(reward ~= nil, true, key .. ": its reward words drawn")
        Equal(deepest <= C.DETAIL_H, true, key .. ": every line inside the details' part (the last ends at " .. deepest .. ")")
        Equal(g.st[Piece(look, C.sheet, "title")].text ~= nil and g.st[Piece(look, C.sheet, "plate")].shown, true, key .. ": its name and points")
    end
    C.Want(g.deadmines)
    Equal(g.st[C.detailBar].max > 0, true, "a longer one (three objectives, one counted, reward words) still scrolls")
    Equal(g.st[C.detailBar:GetThumbTexture()].shown, true, "its bar's knob shows then")
    Proto.GetStringHeight = own
    Errors(g, "10b: the details")
end

-- 10c. The scroll bars' knobs: the 1.x knob shows on the list's bar and the
-- details' while they scroll, in its own colours in every mode (Dark Mode's
-- tint made it a dark square on the dark column, 474: out of sight).
do
    for _, dark in ipairs({ false, true }) do
        local settings = dark and { darkMode = true, darkWindows = true, blackPages = true, darkModeDarkness = 70 } or {}
        local g, look = Session({ appearance = true, settings = settings })
        local mode = dark and "Dark Mode" or "normal"
        local C = look.Legacy.ChallengeList
        local w = g.LoadAddOn()
        w:Show()
        g.Run(Field(w, "Tabs")[2], "OnMouseUp", "LeftButton", true)
        g.NextFrame()
        C.Want(g.deadmines)
        for label, bar in pairs({ list = C.listBar, details = C.detailBar }) do
            local knob = bar:GetThumbTexture()
            Equal(g.st[knob].file, look.MEDIA .. "UI-ScrollBar-Knob", mode .. ", the " .. label .. ": the 1.x knob")
            Equal(g.st[knob].shown, true, mode .. ", the " .. label .. ": shown while it scrolls")
            Equal(g.st[knob].alpha == nil or g.st[knob].alpha == 1, true, mode .. ", the " .. label .. ": not faded")
            Colour(g.st[knob].colour or { 1, 1, 1 }, { 1, 1, 1 }, mode .. ", the " .. label .. ": in its own colours")
            Equal(g.st[knob].layer, "ARTWORK", mode .. ", the " .. label .. ": over its stone column")
        end
        if dark then
            g.settings.darkModeDarkness = 90
            g.ns.RefreshDarkness()
            g.ns.RefreshDarkWindows()
            Colour(g.st[C.listBar:GetThumbTexture()].colour, { 1, 1, 1 }, "the Darkness slider moved: still its own colours")
            Colour(g.st[look.OwnPiece(C.listBar, "columntop")].colour, { g.ns.DarkGrey() },
                "its stone column keeps Dark Mode's grey, so the knob stands out on it")
        end
        Errors(g, "10c: the knobs, " .. mode)
    end
end

-- 10d. The three Legacy trees as the game places them (TraitNode positions,
-- camelot 70425: posX / 10 across, -posY / 10 down; the game's choice
-- talent in Adventure, 110298, a circle template that showed 47 across in
-- game, 485: modelled as a 47 icon), and Adventure as the game showed it in
-- Squirt's round (485, 478): that choice talent off the grid at 3150, 75
-- from the one before it, where it and that one's rank plate met. Every one
-- fitted so no two talents or rank boxes touch, none cut off, centred. A
-- row of talents closer than any tree's: spread. Each talent with its own
-- most ranks (TraitNodeEntry MaxRanks, 70425: 1, 2, 3 or 5), so every rank
-- box is as wide as in game; the crowded row ends in one of 10 ("10/10",
-- the widest box; five talents with such boxes side by side would be wider
-- than the page, and no Legacy talent has more than 5 ranks). On both
-- builds: 70450 (EraUI makes "0/5" from the node) and
-- 70532 (the game writes it).
do
    -- { posX, posY, most ranks, icon (the choice talent's 47) }
    local TREES = {
        Professions = { { 3300, 850, 5 }, { 2400, 1750, 5 }, { 3300, 1750, 2 }, { 4200, 1750, 1 }, { 2400, 2650, 5 },
            { 3300, 2650, 3 }, { 4200, 2650, 1 }, { 5100, 2650, 1 }, { 3300, 3550, 2 } },
        Adventure = { { 3300, 850, 2 }, { 2400, 1750, 5 }, { 3300, 1750, 1, 47 }, { 4200, 1750, 1 }, { 5100, 1750, 1 },
            { 2400, 2650, 5 }, { 3300, 2650, 3 }, { 4200, 2650, 1 }, { 3300, 3550, 2 } },
        Resourcefulness = { { 3300, 850, 5 }, { 2400, 1750, 3 }, { 3300, 1750, 2 }, { 4200, 1750, 1 }, { 5100, 1750, 1 },
            { 2400, 2650, 2 }, { 4200, 2650, 1 }, { 2400, 3550, 5 }, { 3300, 3550, 5 } },
        ["Adventure as shown in game"] = { { 3300, 850, 2 }, { 2400, 1750, 5 }, { 3150, 1750, 1, 47 }, { 4200, 1750, 1 },
            { 5100, 1750, 1 }, { 2400, 2650, 5 }, { 3300, 2650, 3 }, { 4200, 2650, 1 }, { 3300, 3550, 2 } },
        ["a crowded row"] = { { 2400, 1750, 5 }, { 2700, 1750, 2 }, { 3000, 1750, 3 }, { 3300, 1750, 1 }, { 3600, 1750, 10 } },
        -- The widest box between two narrower ones: the tree's edges are
        -- the outer talents' own boxes (centred by them, not the widest).
        ["a wide box in the middle"] = { { 2400, 1750, 1 }, { 3300, 1750, 10 }, { 4200, 1750, 1 } },
    }
    local ORDER = { "Professions", "Adventure", "Resourcefulness", "Adventure as shown in game", "a crowded row",
        "a wide box in the middle" }
    for _, build in ipairs({ 70450, 70532 }) do
        local g, look = Session({ build = build })
        local function Use(name)
            g.nodes = {}
            for id, spot in ipairs(TREES[name]) do
                -- Every talent shows its rank (0/5), locked ones too.
                table.insert(g.nodes, { id = id, x = spot[1] / 10, y = -spot[2] / 10, max = spot[3], icon = spot[4],
                    state = id % 3 == 0 and "locked" or "open", ranks = 0 })
            end
            g.links = {}
        end
        Use(ORDER[1])
        local w = g.LoadAddOn()
        w:Show()
        g.Run(Field(w, "Tabs")[3], "OnMouseUp", "LeftButton", true)
        local p = Field(Field(w, "TreePage"), "LegacyTreeTraitPanel")
        local buttons = Field(Field(Field(w, "TreePage"), "LegacyTreeSelectionPanel"), "treeButtons")
        for i, name in ipairs(ORDER) do
            local label = build .. ", " .. name
            Use(name)
            g.Run(buttons[(i - 1) % 3 + 1], "OnClick", "LeftButton")
            TreeFits(g, look, p, w, label)
            local scale = look.Legacy.treeScale
            if name == "Adventure as shown in game" then
                Equal(scale.x > scale.y, true, label .. ": spread across for the talent off the grid, rows as the box allows")
            elseif name == "a crowded row" then
                Equal(scale.x > 1, true, label .. ": spread further apart than the game has them")
            elseif name == "Adventure" then
                -- Its choice talent's 47 icon and its rank box need a hair
                -- more across than the rows' spacing gives (62.5 against
                -- 62.3): never closer, at most 1% wider.
                Equal(scale.x >= scale.y and scale.x < scale.y * 1.01, true, label .. ": across a hair wider for the rank boxes, if at all")
            else
                Near(scale.x, scale.y, label .. ": the same spacing both ways (on the grid, nothing touches)")
            end
            for id, button in pairs(Field(p, "byNode")) do
                local most = g.nodes[id].max
                RankBox(g, look, button, "0/" .. most, most .. "/" .. most, look.Legacy.STATE[id % 3 == 0 and "locked" or "open"],
                    label .. ", talent " .. id)
            end
            -- Shown again in a fight (the game loads it again): fitted the same.
            g.combat = true
            g.Run(Field(w, "Tabs")[1], "OnMouseUp", "LeftButton", true)
            g.Run(Field(w, "Tabs")[3], "OnMouseUp", "LeftButton", true)
            TreeFits(g, look, p, w, label .. ", loaded again in a fight")
            g.combat = false
            g.Fire("PLAYER_REGEN_ENABLED")
        end
        Errors(g, "10d: the real trees, " .. build)
    end
end

---------------------------------------------------------------------------
-- 11. Build 70532 (live Forever; Squirt's beta and private server are on
--     70450, every section above): the game's new rank box behind each
--     talent's rank (unnamed, "Talents-Square-Box-c60"), its ranks always
--     "current/max" in white, and each reward card's new hover glow
--     (Highlight). Faded, the rank as the old talent window's, on and off.
---------------------------------------------------------------------------

do
    local g, look = Session({ build = 70532 })
    local LG = look.Legacy
    local w = g.LoadAddOn()
    w:Show()
    local tabsG = Field(w, "Tabs")
    -- The Progress Track: the glow faded with the rest of the card's art;
    -- the game still shows it on hover and hides it on leave (unseen), and
    -- its tooltip still shows.
    local trackG = Field(Field(w, "RewardTrackPage"), "LegacyRewardProgressFrame")
    local function Glows(label)
        for i, card in ipairs(Field(trackG, "Elements")) do
            local glow = Field(card, "Highlight")
            Equal(g.st[glow].alpha, 0, label .. ", card " .. i .. ": the game's hover glow faded")
            Equal(type(g.st[glow].atlas), "string", label .. ", card " .. i .. ": its art the game's own, left as it is")
        end
    end
    Glows("70532")
    local card = Field(trackG, "Elements")[2]
    g.Run(card, "OnEnter")
    Equal(g.st[Field(card, "Highlight")].shown, true, "70532, hovered: the game shows its glow")
    Equal(g.st[Field(card, "Highlight")].alpha, 0, "but it stays faded")
    Equal(g.cardTips, 1, "the game's tooltip still shows")
    g.Run(card, "OnLeave")
    Equal(g.st[Field(card, "Highlight")].shown or g.cardTipsHidden ~= 1, false, "left: the game hides it and its tooltip")
    -- The page shown again: the cards handed out again, still faded.
    g.Run(tabsG[2], "OnMouseUp", "LeftButton", true)
    g.Run(tabsG[1], "OnMouseUp", "LeftButton", true)
    Glows("70532, shown again")
    CardsDown(g, look, Field(trackG, "Elements"), Field(trackG, "ClipFrame"), w, "70532")

    -- The Legacy Tree.
    g.Run(tabsG[3], "OnMouseUp", "LeftButton", true)
    local panelG = Field(Field(w, "TreePage"), "LegacyTreeTraitPanel")
    local function Boxes(label)
        for id, button in pairs(Field(panelG, "byNode")) do
            local box = g.rankBoxes[button]
            Equal(g.st[box].atlas, "Talents-Square-Box-c60", label .. ", talent " .. id .. ": the game's rank box (no key)")
            Equal(g.st[box].alpha, 0, label .. ", talent " .. id .. ": faded, found by its art")
            Equal(g.st[Field(button, "SpendText")].alpha, 0, label .. ", talent " .. id .. ": the game's rank text faded")
        end
    end
    Boxes("70532")
    local byNodeG = Field(panelG, "byNode")
    -- The game writes "current/max" on every talent itself, in white.
    Equal(g.st[Field(byNodeG[3], "SpendText")].text, "0/3", "70532: the game's own rank current/max, a locked talent too")
    Colour(g.st[Field(byNodeG[3], "SpendText")].textColour, { 1, 1, 1 }, "in white whatever its state")
    -- EraUI's rank: the game's words, in the old colours by state.
    RankBox(g, look, byNodeG[1], "1/1", "1/1", LG.STATE.learned, "70532, a maxed talent: gold")
    RankBox(g, look, byNodeG[2], "0/2", "2/2", LG.STATE.open, "70532, an open one: green")
    RankBox(g, look, byNodeG[3], "0/3", "3/3", LG.STATE.locked, "70532, a locked one: grey")
    RankBox(g, look, byNodeG[4], "0/5", "5/5", LG.STATE.locked, "70532, a locked one of five")
    RankBox(g, look, byNodeG[5], "0/1", "1/1", LG.STATE.locked, "70532, a locked one of one")
    TreeFits(g, look, panelG, w, "70532, the tree")
    Near(LG.treeScale.x, SX, "70532: the row spread across just enough, as on 70450")
    Equal(LG.treeScale.y, 1, "70532: down, the game's spacing, as on 70450")
    -- The game's clicks: a rank taken (still green), then maxed (gold).
    g.Run(byNodeG[2], "OnClick", "LeftButton")
    RankBox(g, look, byNodeG[2], "1/2", "2/2", LG.STATE.open, "70532, one rank taken of two")
    g.Run(byNodeG[2], "OnClick", "LeftButton")
    RankBox(g, look, byNodeG[2], "2/2", "2/2", LG.STATE.learned, "70532, maxed by the game's click")
    byNodeG[1]:ApplyVisualState("refund")
    RankBox(g, look, byNodeG[1], "1/1", "1/1", LG.STATE.refund, "70532, one that can't be taken back: red")
    -- What the game wrote is the rank shown, even when its node says
    -- otherwise until the game writes again (EraUI never makes its own
    -- over the game's "current/max").
    g.Own(byNodeG[4], "nodeInfo", { currentRank = 2, maxRanks = 5, ranksPurchased = 2 })
    byNodeG[4]:UpdateNonStateVisuals()
    RankBox(g, look, byNodeG[4], "0/5", "5/5", LG.STATE.locked, "70532, the game's own words, not the node's")
    byNodeG[4]:UpdateSpendText()
    RankBox(g, look, byNodeG[4], "2/5", "5/5", LG.STATE.locked, "70532, the game's next words")
    -- The game's own words kept as it writes them (a client whose fraction
    -- reads otherwise): the box sized for the widest in the same words.
    g.env.GENERIC_FRACTION_STRING = "%d of %d"
    g.Run(Field(Field(Field(w, "TreePage"), "LegacyTreeSelectionPanel"), "treeButtons")[1], "OnClick", "LeftButton")
    byNodeG = Field(panelG, "byNode")
    RankBox(g, look, byNodeG[3], "0 of 3", "3 of 3", LG.STATE.locked, "70532, the game's own words kept")
    TreeFits(g, look, panelG, w, "70532, wider words")
    g.env.GENERIC_FRACTION_STRING = "%d/%d"
    Errors(g, "70532")

    -- In a fight: the tree loaded again from the pools (one talent with more
    -- ranks now): the boxes stay faded, the ranks follow the nodes handed out.
    g.combat = true
    local stopWatch = FightWatch(g, Field(panelG, "talentButtonCollection"))
    g.nodes[2].max = 3
    g.Run(tabsG[1], "OnMouseUp", "LeftButton", true)
    g.Run(tabsG[3], "OnMouseUp", "LeftButton", true)
    byNodeG = Field(panelG, "byNode")
    Boxes("70532, in a fight")
    RankBox(g, look, byNodeG[2], "0/3", "3/3", LG.STATE.open, "70532, in a fight: a talent handed out again")
    RankBox(g, look, byNodeG[3], "0/3", "3/3", LG.STATE.locked, "70532, in a fight: another")
    TreeFits(g, look, panelG, w, "70532, in a fight")
    -- A point taken in the fight is the game's business (its own click): the
    -- rank follows on EraUI's own pieces only.
    g.Run(byNodeG[2], "OnClick", "LeftButton")
    RankBox(g, look, byNodeG[2], "1/3", "3/3", LG.STATE.open, "70532, in a fight: a rank taken")
    byNodeG[3]:ApplyVisualState("refund")
    RankBox(g, look, byNodeG[3], "0/3", "3/3", LG.STATE.refund, "70532, in a fight: one that can't be taken back")
    Equal(stopWatch(), "", "70532, in a fight: nothing of the game's talent pieces touched by EraUI (its rank box included)")
    g.combat = false
    g.Fire("PLAYER_REGEN_ENABLED")
    Errors(g, "70532, a fight")

    -- Off: the game's rank boxes, rank text and hover glows back; EraUI's
    -- ranks and boxes hidden.
    g.ns.db.legacyWindow = false
    g.Pass()
    for id, button in pairs(Field(panelG, "byNode")) do
        Equal(g.st[g.rankBoxes[button]].alpha, 1, "70532, off: talent " .. id .. "'s rank box back")
        Equal(g.st[Field(button, "SpendText")].alpha, 1, "70532, off: its rank text back")
        for _, purpose in ipairs({ "plate", "plateLeft", "plateRight", "rank" }) do
            Equal(g.st[Piece(look, button, purpose)].shown, false, "70532, off: EraUI's " .. purpose .. " hidden")
        end
    end
    for i, each in ipairs(Field(trackG, "Elements")) do
        Equal(g.st[Field(each, "Highlight")].alpha, 1, "70532, off: card " .. i .. "'s hover glow back")
    end
    -- On again: faded again.
    g.ns.db.legacyWindow = true
    g.Pass()
    g.Run(tabsG[1], "OnMouseUp", "LeftButton", true)
    Glows("70532, on again")
    g.Run(tabsG[3], "OnMouseUp", "LeftButton", true)
    Boxes("70532, on again")
    Errors(g, "70532, off and on")
end

-- 70532's rank box found either way: by its art, or on a client that
-- doesn't name its art, as the one texture the game hangs from its rank
-- text; faded all the same, nothing else of the talent's with it (the
-- 70450 tree above, with no box, keeps its own pieces).
for _, case in ipairs({ { "unnamed art", "boxArtUnread" }, { "hung from the button", "boxElsewhere" } }) do
    local g, look = Session({ build = 70532 })
    g[case[2]] = true
    local w = g.LoadAddOn()
    w:Show()
    g.Run(Field(w, "Tabs")[3], "OnMouseUp", "LeftButton", true)
    local panelG = Field(Field(w, "TreePage"), "LegacyTreeTraitPanel")
    for id, button in pairs(Field(panelG, "byNode")) do
        local box, label = g.rankBoxes[button], case[1] .. ", talent " .. id
        if case[2] == "boxArtUnread" then
            Equal(g.st[box].atlas == nil and g.st[box].file, 5432100, label .. ": a file, no atlas")
        else
            Equal(g.st[box].points.CENTER[2], button, label .. ": not on the rank text")
        end
        Equal(g.st[box].alpha, 0, label .. ": the game's rank box faded")
        Equal(g.st[Field(button, "Icon")].alpha, 1, label .. ": its icon kept")
        local info = Field(button, "nodeInfo")
        RankBox(g, look, button, info.currentRank .. "/" .. info.maxRanks, info.maxRanks .. "/" .. info.maxRanks,
            look.Legacy.STATE[look.Legacy.NodeState(button)], label)
    end
    Errors(g, case[1])
end
for id, button in pairs(byNode) do
    Equal(st[Field(button, "Icon")].alpha, 1, "70450, talent " .. id .. ": its icon never faded (no rank box to find)")
end

-- Build 70450 (above): its reward cards have no hover glow, and nothing
-- reads one.
Equal(Field(Field(Field(Field(window, "RewardTrackPage"), "LegacyRewardProgressFrame"), "Elements")[1], "Highlight"), nil,
    "70450: no hover glow on a card")

print(("Legacy window checks passed: %d assertions."):format(checks))
