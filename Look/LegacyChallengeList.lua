-- The Legacy window's Challenges page as EraUI draws it (registry
-- "legacyWindow"), in place of the game's category list and its 122-tall
-- challenge cards (about one and a half fit at once): one 1.x quest log
-- list on the parchment's upper part and, under a rule, the chosen
-- challenge's details (Look/LegacyChallengeDetail.lua), all from the game's
-- own data read as its own page reads it (Look/LegacyChallengeData.lua):
--   * the game's search box and filter stay, in a strip at the parchment's
--     top, and the list honours both exactly;
--   * the categories as headers with the old plus and minus, the top level
--     in gold, the ones under them in brown ink and further in, each with
--     how many of its challenges are done and the game's own "new" mark
--     while it has one (only read: the game clears it from its own list, and
--     EraUI runs none of that code); folding is kept for the session,
--     and at first only the way to the player's class's category is open
--     (as the game opens it); while a search is typed every header is open
--     (what is folded then is forgotten with the search);
--   * the challenges as 16-tall rows under their category: the icon on a
--     dark square, the name gold once done and brown ink before, its
--     points on a talent rank plate at the right, the chosen one on the
--     quest log's highlight bar; 8 rows at once (so the details under them
--     have room for a whole challenge), the 1.x scroll bar with its knob
--     and the mouse wheel;
--   * a row's hover shows EraUI's own tooltip box; a click chooses it; the
--     chat link click links it in the chat box as the game's page does,
--     else the game's watch click tracks it;
--   * a challenge chosen from elsewhere (the tracker, an alert) is chosen
--     here too, its category opened and the list scrolled to it, also when
--     it shows only once the game has cleared a search or the filter for
--     it;
--   * the game's data changing (progress, a challenge done, tracking, the
--     search's results, the filter) draws it again: events and the game's
--     own calls, nothing polled.
-- The game's own rows, cards and their scroll bars are faded and parked
-- left of the window at the size its dressed page gives them (so the game
-- lays nothing out again), so nothing of the game's lies under EraUI's
-- list. That is done out of a fight, with the rest of the dressing; the
-- list and details are EraUI's own frames, so they work in a fight too,
-- where a value the game hides shows the last one read. While the game's
-- gamepad mode is on, its own page shows instead (as LegacyChallenges.lua
-- dresses it), so its gamepad keeps moving through its rows and cards.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local L = Look.Legacy
local D = L.ChallengeData

local C = { folded = {}, searchFolds = {}, items = {}, byId = {}, slots = {}, search = "", homeward = {} }
L.ChallengeList = C
local shows = Look.Weak() -- a list row: the item it shows

-- The page's places (window units from its top left, down positive): the
-- game's search and filter in a strip, EraUI's list (ROWS rows, ROW_H
-- tall), the rule, the details; each one's scroll bar in its 1.x column
-- right of it.
local STRIP_TOP, STRIP_FOOT, SIDE = 62, 92, 8
-- (The list's top 6 under the strip: its scroll bar's stone column starts 5
-- above its arrow, clear of the game's filter.)
local LIST_X, LIST_TOP, LIST_W = 12, 98, 284
-- 8 rows, not the 12 of the first build: the details under them are then
-- 170 tall, room for a usual challenge's name, points, text, objective and
-- reward words without scrolling (12 rows left 114: about two lines).
local ROW_H, ROWS, INDENT = 16, 8, 14
local LIST_FOOT = LIST_TOP + ROW_H * ROWS
local RULE_Y = LIST_FOOT + 4
-- The details end above the parchment's burnt rim (their last line and
-- the scroll bar's down arrow sat on it).
local DETAIL_TOP, DETAIL_FOOT = RULE_Y + 4, L.PAGE.bottom - L.EDGE - 2
-- Where the game's rows and cards are parked: far left of the window.
local AWAY = -3000
C.ROWS, C.ROW_H = ROWS, ROW_H
C.DETAIL_W, C.DETAIL_H = LIST_W, DETAIL_FOOT - DETAIL_TOP

local EVENTS = { "ACHIEVEMENT_EARNED", "ACHIEVEMENT_SEARCH_UPDATED", "CRITERIA_UPDATE", "CONTENT_TRACKING_UPDATE",
    "TRACKED_ACHIEVEMENT_LIST_CHANGED" }
-- Events that change only the chosen challenge's details.
local DETAIL_ONLY = { CRITERIA_UPDATE = true, CONTENT_TRACKING_UPDATE = true, TRACKED_ACHIEVEMENT_LIST_CHANGED = true }

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------

local function Piece(owner, purpose)
    return Look.OwnPiece(owner, "legacy." .. purpose)
end

local function Sound(name)
    local kits = SOUNDKIT
    local kit = type(kits) == "table" and kits[name] or nil
    if kit and type(PlaySound) == "function" then pcall(PlaySound, kit) end
end
C.Sound = Sound

-- One of the game's modified clicks ("CHATLINK", "QUESTWATCHTOGGLE").
local function Modified(action)
    if type(IsModifiedClick) ~= "function" then return false end
    local ok, on = pcall(IsModifiedClick, action)
    return ok and not Look.Secret(on) and on == true
end

-- Ink on the parchment: the quest log's brown (faded: its grey, for what
-- isn't done and a header's count), or light while Dark Windows greys the
-- page (as the rest of the window's page text).
function C.Ink(faded)
    if type(ns.DarkWindowsOn) == "function" and ns.DarkWindowsOn() then
        local light = type(ns.DARK_PAGE_TEXT) == "table" and ns.DARK_PAGE_TEXT or { 0.87, 0.81, 0.66 }
        local k = faded and 0.78 or 1
        return light[1] * k, light[2] * k, light[3] * k
    end
    local ink = faded and L.FADED_INK or L.INK
    return ink[1], ink[2], ink[3]
end

-- A text in gold with the black shadow, or in ink with none.
function C.Colour(words, gold, faded)
    local r, g, b
    if gold then
        r, g, b = L.GOLD[1], L.GOLD[2], L.GOLD[3]
    else
        r, g, b = C.Ink(faded)
    end
    words:SetTextColor(r, g, b)
    words:SetShadowColor(0, 0, 0, gold and 1 or 0)
    words:SetShadowOffset(1, -1)
end

-- What is typed in the game's search box.
local function SearchWords()
    local list = C.page and L.Field(C.page, "CategoryList")
    local box = list and L.Field(list, "SearchBox")
    local words = box and box:GetText() or ""
    if Look.Secret(words) or type(words) ~= "string" then return C.search end
    return words
end

local function Untip()
    for _, slot in ipairs(C.slots) do Look.HideTip(slot) end
end

---------------------------------------------------------------------------
-- Folding and the items the list shows
---------------------------------------------------------------------------

-- The folds in use: the session's, or while searching the search's own.
local function Folds()
    return C.search ~= "" and C.searchFolds or C.folded
end

-- Folded as the player left it; else open only on the way to the player's
-- class's category, and every header while searching.
local function IsFolded(node)
    local mark = Folds()[node.id]
    if mark ~= nil then return mark end
    if C.search ~= "" then return false end
    return not C.homeward[node.id]
end

-- The list's items: each header ({ head, folded }) and, under an open one,
-- its challenges ({ entry, depth }) then its own categories.
local function Flatten(roots)
    local items = {}
    local function Walk(node)
        local shut = IsFolded(node)
        items[#items + 1] = { head = node, folded = shut }
        if shut then return end
        for _, entry in ipairs(node.own) do items[#items + 1] = { entry = entry, depth = node.depth + 1 } end
        for _, kid in ipairs(node.kids) do Walk(kid) end
    end
    for _, node in ipairs(roots) do Walk(node) end
    return items
end

-- Every category on the way to the player's class's.
local function Homeward(nodes)
    local marks = {}
    local node = nodes and nodes[D.Home() or 0] or nil
    while node do
        marks[node.id] = true
        node = node.parent
    end
    return marks
end

-- A challenge's category and every one above it opened.
local function OpenTo(entry)
    local folds, node = Folds(), entry.node
    while node do
        folds[node.id] = false
        node = node.parent
    end
end

local function FirstEntry(items)
    for _, item in ipairs(items) do
        if item.entry then return item.entry.id end
    end
    return nil
end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------

-- Which of a row's pieces show, for a header and for a challenge (the
-- highlight bar and the plate follow the challenge).
local HEAD_SHOWS = { fold = true, foldGlow = true, words = true, count = true, glow = false, pick = false, backing = false,
    face = false, plate = false, points = false }
local ENTRY_SHOWS = { fold = false, foldGlow = false, words = true, count = false, glow = true, backing = true, face = true,
    new = false }

local function PaintHead(slot, item)
    local node = item.head
    local x = 2 + node.depth * INDENT
    for purpose, on in pairs(HEAD_SHOWS) do Look.Shown(Piece(slot, purpose), on) end
    local sign = Piece(slot, "fold")
    Look.Art(sign, item.folded and "legacyPlus" or "legacyMinus")
    Look.Crop(sign, 0, 1, 0, 1)
    Look.Pin(sign, "LEFT", slot, "LEFT", x, 0)
    local words = Piece(slot, "words")
    Look.Pin(words, "LEFT", slot, "LEFT", x + 18, 0)
    words:SetWidth(LIST_W - x - 18 - 44)
    words:SetText(node.name)
    C.Colour(words, node.depth == 0)
    local count = Piece(slot, "count")
    count:SetText(string.format("%d / %d", node.done or 0, node.total or 0))
    C.Colour(count, false, true)
    Look.Shown(Piece(slot, "new"), D.Unviewed(node.id))
end

local function PaintEntry(slot, item)
    local entry = item.entry
    local x = 4 + item.depth * INDENT
    for purpose, on in pairs(ENTRY_SHOWS) do Look.Shown(Piece(slot, purpose), on) end
    local chosen = entry.id == C.sel
    Look.Shown(Piece(slot, "pick"), chosen)
    Look.Pin(Piece(slot, "backing"), "LEFT", slot, "LEFT", x, 0)
    local picture = Piece(slot, "face")
    picture:SetTexture(entry.icon or D.QUESTION)
    Look.Crop(picture, 0.08, 0.92, 0.08, 0.92)
    picture:SetDesaturated(not entry.done and not chosen)
    local words = Piece(slot, "words")
    Look.Pin(words, "LEFT", slot, "LEFT", x + 20, 0)
    words:SetWidth(LIST_W - x - 20 - 34)
    words:SetText(entry.name)
    C.Colour(words, entry.done)
    local worth = (Look.Number(entry.worth) or 0) > 0
    Look.Shown(Piece(slot, "plate"), worth)
    local points = Piece(slot, "points")
    Look.Shown(points, worth)
    if worth then points:SetText(tostring(entry.worth)) end
end

-- EraUI's tooltip box for a challenge: its name, its text, its reward
-- words, the date it was done.
local function TipRows(entry)
    local lines = { { entry.name, 1, 1, 1 } }
    if entry.description ~= "" then lines[#lines + 1] = { entry.description, 1, 0.82, 0, 260 } end
    if entry.reward ~= "" then lines[#lines + 1] = { entry.reward, 0.1, 1, 0.1, 260 } end
    if entry.date then lines[#lines + 1] = { "Completed on " .. entry.date, 0.75, 0.75, 0.75 } end
    return lines
end
C.TipRows = TipRows

local function HoverIn(slot)
    local item = shows[slot]
    if not (item and item.entry) then
        Look.HideTip(slot)
        return
    end
    Look.ShowTip(slot, "RIGHT", TipRows(item.entry))
end

local function HoverOut(slot)
    Look.HideTip(slot)
end

-- A header folds or opens; a challenge is chosen (or linked, or tracked).
local function Clicked(slot)
    local item = shows[slot]
    if not item then return end
    if item.head then
        C.Fold(item.head)
    else
        C.Pick(item.entry.id)
    end
end

local ROW_SCRIPTS = { OnClick = Clicked, OnEnter = HoverIn, OnLeave = HoverOut }

-- One list row: ROW_H tall, the plus or minus (a header), the icon on its
-- dark square (a challenge), the words, a header's count, the plate and
-- its points at the right, the hover bar and the chosen one's bar.
local function NewRow(area, i)
    local slot = Look.Build("Button", area, nil, { size = { LIST_W, ROW_H }, mouse = true })
    Look.Pin(slot, "TOPLEFT", area, "TOPLEFT", 0, -(i - 1) * ROW_H)
    slot:RegisterForClicks("LeftButtonUp")
    local sign = Look.OwnTexture(slot, "legacy.fold", "ARTWORK")
    sign:SetSize(16, 16)
    Look.Art(sign, "legacyPlus")
    local signGlow = Look.OwnTexture(slot, "legacy.foldGlow", "HIGHLIGHT")
    Look.Art(signGlow, "legacyPlusGlow")
    signGlow:SetBlendMode("ADD")
    signGlow:SetAllPoints(sign)
    for purpose, layer in pairs({ glow = "HIGHLIGHT", pick = "BACKGROUND" }) do
        local glow = Look.OwnTexture(slot, "legacy." .. purpose, layer)
        Look.Art(glow, "legacyBar")
        glow:SetBlendMode("ADD")
        glow:SetAlpha(purpose == "pick" and 0.55 or 1)
        Look.Fill(glow, slot)
    end
    local backing = Look.OwnTexture(slot, "legacy.backing", "ARTWORK", -1)
    backing:SetColorTexture(0, 0, 0, 0.85)
    backing:SetSize(16, 16)
    local picture = Look.OwnTexture(slot, "legacy.face", "ARTWORK", 1)
    picture:SetSize(14, 14)
    picture:SetTexture(D.QUESTION)
    Look.Pin(picture, "CENTER", backing, "CENTER", 0, 0)
    local words = Look.OwnLabel(slot, "legacy.words", "GameFontNormal", "ARTWORK")
    words:SetJustifyH("LEFT")
    words:SetWordWrap(false)
    local count = Look.OwnLabel(slot, "legacy.count", "GameFontNormalSmall", "ARTWORK")
    count:SetJustifyH("RIGHT")
    Look.Pin(count, "RIGHT", slot, "RIGHT", -4, 0)
    -- The game's own "new" mark, left of the count.
    local note = Look.OwnTexture(slot, "legacy.new", "OVERLAY")
    note:SetAtlas("UI-HUD-MicroMenu-Communities-Icon-Notification")
    note:SetSize(12, 12)
    Look.Pin(note, "RIGHT", count, "LEFT", -3, 0)
    note:Hide()
    local plate = Look.OwnTexture(slot, "legacy.plate", "ARTWORK", 2)
    Look.Art(plate, "legacyPlate")
    plate:SetSize(32, 32)
    Look.Pin(plate, "CENTER", slot, "RIGHT", -16, 0)
    local points = Look.OwnLabel(slot, "legacy.points", "GameFontHighlightSmall", "OVERLAY")
    Look.Pin(points, "CENTER", plate, "CENTER", 0, 0)
    for script, run in pairs(ROW_SCRIPTS) do slot:SetScript(script, run) end
    slot:Hide()
    return slot
end

-- The rows from the list bar's place; past the end a row is put away.
local filling = false
function C.FillRows()
    if filling or not C.listBar then return end
    filling = true
    local items = C.items
    local top = math.max(0, #items - ROWS)
    Look.ScrollRange(C.listBar, top, 1)
    local first = Look.Clamp(math.floor((Look.Number(C.listBar:GetValue()) or 0) + 0.5), 0, top)
    for i, slot in ipairs(C.slots) do
        local item = items[first + i]
        shows[slot] = item
        if item then
            Look.Try(item.head and PaintHead or PaintEntry, slot, item)
            Look.Shown(slot, true)
            if Look.TipOwner() == slot then HoverIn(slot) end
        else
            Look.Shown(slot, false)
            Look.HideTip(slot)
        end
    end
    if C.empty then
        Look.Shown(C.empty, #items == 0 and not C.waiting)
        C.Colour(C.empty, false, true)
    end
    filling = false
end

-- The list scrolled so a challenge's row is in it, near the middle.
function C.ScrollTo(id)
    local top = math.max(0, #C.items - ROWS)
    Look.ScrollRange(C.listBar, top, 1)
    for place, item in ipairs(C.items) do
        if item.entry and item.entry.id == id then
            C.listBar:SetValue(Look.Clamp(place - math.ceil(ROWS / 2), 0, top))
            return
        end
    end
end

---------------------------------------------------------------------------
-- Choosing, folding, drawing again
---------------------------------------------------------------------------

-- The list from the tree read last: the challenge asked for from elsewhere
-- chosen (its category opened, the list scrolled to it), else the chosen
-- one kept while the game lists it, else the first one showing.
function C.Layout()
    local roots = C.roots or {}
    local search = SearchWords()
    if search ~= C.search then
        C.search = search
        for key in pairs(C.searchFolds) do C.searchFolds[key] = nil end
    end
    C.homeward = Homeward(C.nodes)
    local byId = {}
    local function Each(nodes)
        for _, node in ipairs(nodes) do
            for _, entry in ipairs(node.own) do
                entry.node = node
                byId[entry.id] = entry
            end
            Each(node.kids)
        end
    end
    Each(roots)
    C.byId = byId
    local wanted = C.wanted and byId[C.wanted] or nil
    if wanted then
        C.sel, C.wanted = wanted.id, nil
        OpenTo(wanted)
    end
    C.items = Flatten(roots)
    if not (C.sel and byId[C.sel]) then C.sel = FirstEntry(C.items) end
    if wanted then C.ScrollTo(C.sel) end
    C.FillRows()
    if C.DrawDetail then C.DrawDetail(wanted ~= nil) end
end

-- The page is EraUI's and shows.
function C.Live()
    return L.active == true and C.mode == "own" and C.page ~= nil and C.page:IsVisible() == true
end

-- The game's data read again and the page drawn from it (a tree the game
-- hides keeps the last one, and so does the wait for the game's search
-- results with nothing typed: the game's own page waits for them too).
function C.Refresh()
    if not C.Live() then return end
    C.waiting = SearchWords() == "" and D.Waiting()
    if not C.waiting then
        local roots, nodes = D.Tree()
        if roots then C.roots, C.nodes = roots, nodes end
    end
    C.Layout()
end

-- Drawn again from what was read (Dark Windows changed).
function C.Repaint()
    C.FillRows()
    if C.DrawDetail then C.DrawDetail() end
end

function C.Fold(node)
    local folds, shut = Folds(), not IsFolded(node)
    folds[node.id] = shut
    Sound(shut and "IG_QUEST_LIST_CLOSE" or "IG_QUEST_LIST_OPEN")
    C.items = Flatten(C.roots or {})
    C.FillRows()
end

-- A challenge's row clicked: linked in chat (the game's chat link click,
-- when a chat box takes it), tracked or not (the game's watch click), or
-- chosen, as the game's own page handles a click.
function C.Pick(id)
    if Modified("CHATLINK") and Look.ChatLink(D.Link(id)) then return end
    if Modified("QUESTWATCHTOGGLE") then
        D.ToggleTrack(id)
        if C.DrawDetail then C.DrawDetail() end
        return
    end
    C.sel, C.wanted = id, nil
    D.Focus(id)
    Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    C.FillRows()
    if C.DrawDetail then C.DrawDetail(true) end
end

-- A challenge chosen from elsewhere (the game's window asked to show it).
function C.Want(id)
    id = Look.Number(id)
    if not id then return end
    C.wanted = id
    if C.Live() then C.Refresh() end
end

---------------------------------------------------------------------------
-- The page: built once, laid out, and the game's own pieces put aside
---------------------------------------------------------------------------

local function Spot(region, window, left, top, right, foot)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", window, "TOPLEFT", left, -top)
    region:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", right, -foot)
    region:SetSize(right - left, foot - top)
end

-- EraUI's parts in their places, pinned by two corners each.
function C.Pin()
    local window = C.window
    if not (window and C.holder) then return end
    Spot(C.holder, window, SIDE, LIST_TOP, L.WIDE - SIDE, DETAIL_FOOT)
    Spot(C.area, window, LIST_X, LIST_TOP, LIST_X + LIST_W, LIST_FOOT)
    if C.detail then Spot(C.detail, window, LIST_X, DETAIL_TOP, LIST_X + LIST_W, DETAIL_FOOT) end
end

local function Heard(_, event)
    if not C.Live() then return end
    if DETAIL_ONLY[event] then
        if C.DrawDetail then C.DrawDetail() end
        return
    end
    C.Refresh()
    -- The game sets its "new" marks on the same event: drawn again after.
    if event == "ACHIEVEMENT_EARNED" and type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if C.Live() then C.FillRows() end
        end)
    end
end

-- The page shown (a page tab, the window opened): out of a fight its
-- layout settled again (the gamepad may have come or gone), then pinned
-- again at once and on the next frame (once the window has its place),
-- and drawn from the game's data.
function C.Shown(page)
    local window = C.window or (L.Window and L.Window())
    if not Look.InFight() then L.ChallengeMode(page, window) end
    if C.mode ~= "own" then return end
    C.Pin()
    if type(C_Timer) == "table" and type(C_Timer.After) == "function" then
        C_Timer.After(0, function()
            if C.Live() then C.Pin() end
        end)
    end
    C.Refresh()
end

-- What the page follows: the filter (and the search's results, which the
-- game's page passes through the same call), a challenge asked for from
-- elsewhere, the page showing and hiding, Dark Windows. EraUI's own frames
-- only, so in a fight too.
local function Follow(page, window)
    L.AfterOwn(page, "OnFilterUpdate", function()
        if C.Live() then C.Refresh() end
    end)
    L.AfterOwn(window, "SelectChallenge", function(_, id) C.Want(id) end)
    Look.HookScript(page, "OnShow", function(self)
        if L.active == true then Look.Try(C.Shown, self) end
    end, "legacyList")
    Look.HookScript(page, "OnHide", function()
        C.wanted = nil
        Untip()
    end, "legacyList")
    if type(ns.RefreshDarkWindows) == "function" then
        Look.Hook(ns, "RefreshDarkWindows", function()
            if C.Live() then C.Repaint() end
        end, "legacyList")
    end
end

local function Build(page, window)
    C.page, C.window = page, window
    local holder = L.Frame(page, L.WIDE - 2 * SIDE, DETAIL_FOOT - LIST_TOP)
    -- Hidden until the page is EraUI's (a build that fails shows nothing).
    holder:Hide()
    local area = Look.Build("Frame", holder, nil, { size = { LIST_W, LIST_FOOT - LIST_TOP }, wheel = true })
    area:SetClipsChildren(true)
    local slots = {}
    for i = 1, ROWS do slots[i] = NewRow(area, i) end
    local slider = Look.ClassicScrollBar(holder, area, function() C.FillRows() end)
    Look.ScrollColumn(slider)
    L.KnobShows(slider:GetThumbTexture())
    area:SetScript("OnMouseWheel", function(_, notches)
        slider:SetValue((Look.Number(slider:GetValue()) or 0) - (Look.Number(notches) or 0) * 2)
    end)
    local empty = Look.OwnLabel(holder, "legacy.empty", "GameFontNormal", "ARTWORK")
    empty:SetText(D.Say("LEGACY_NO_CHALLENGES", "No challenges found."))
    Look.Pin(empty, "TOP", area, "TOP", 0, -40)
    empty:Hide()
    local ear = Look.Build("Frame", holder, nil, { size = { 1, 1 } })
    Look.Pin(ear, "TOPLEFT", holder, "TOPLEFT", 0, 0)
    for _, event in ipairs(EVENTS) do Look.Listen(ear, event) end
    ear:SetScript("OnEvent", Heard)
    C.area, C.slots, C.listBar, C.empty = area, slots, slider, empty
    C.MakeDetail(holder, C.DETAIL_W, C.DETAIL_H)
    Follow(page, window)
    C.holder = holder
    C.Pin()
end

local function Gamepad()
    local util = InputUtil
    if type(util) ~= "table" or type(util.IsGamepadUIEnabled) ~= "function" then return false end
    local ok, on = pcall(util.IsGamepadUIEnabled)
    return ok and not Look.Secret(on) and on == true
end

-- A piece of the game's parked far left of the window at a size (the size
-- the dressed page gives it, so the game lays nothing in it out again).
local function Park(region, window, down, size)
    if not region then return end
    L.Pins(region, { "TOPLEFT", window, "TOPLEFT", AWAY, -down },
        { "BOTTOMRIGHT", window, "TOPLEFT", AWAY + size[1], -(down + size[2]) })
end

-- EraUI's page: the game's rows (and their scroll bar, which hangs off
-- them) and cards faded and parked, its list frame narrowed to the strip
-- its search and filter sit in (the rows parked first, so they keep their
-- size), the rule between EraUI's list and details.
local function OwnLayout(page, window)
    local park = L.CHALLENGE_PARK or { box = { 292, 110 }, pane = { 298, 194 } }
    local list = L.Field(page, "CategoryList")
    if list then
        local box = L.Field(list, "ScrollBox")
        Park(box, window, 0, park.box)
        L.Fade(box)
        L.Fade(L.Field(list, "ScrollBar"))
        L.Fade(L.Field(list, "NoResultsText"))
        L.Pins(list, { "TOPLEFT", window, "TOPLEFT", SIDE, -STRIP_TOP }, { "BOTTOMRIGHT", window, "TOPRIGHT", -SIDE, -STRIP_FOOT })
    end
    local pane = L.Field(page, "DetailPane")
    if pane then
        Park(pane, window, 200, park.pane)
        L.Fade(pane)
    end
    L.Rule(page, window, RULE_Y)
end

-- The game's page again (a gamepad came): its rows and cards back where
-- the dressed page has them, shown.
local function GameLayout(page, window)
    local list = L.Field(page, "CategoryList")
    if list then
        local box = L.Field(list, "ScrollBox")
        L.PutBack(box)
        L.Unfade(box)
        L.Unfade(L.Field(list, "ScrollBar"))
        L.Unfade(L.Field(list, "NoResultsText"))
    end
    L.Unfade(L.Field(page, "DetailPane"))
    if L.ChallengePlaces then L.ChallengePlaces(page, window) end
end

-- EraUI's page, or with the game's gamepad mode the game's own. Out of a
-- fight only (it moves the game's pieces); kept as it is in one.
function L.ChallengeMode(page, window)
    if Look.InFight() or not (page and window) then return end
    if Gamepad() then
        if C.mode == "own" then GameLayout(page, window) end
        C.mode = "game"
        if C.holder then Look.Shown(C.holder, false) end
        return
    end
    if not C.holder then
        -- A build that failed (reported) leaves the game's page as it is.
        if C.broken then return end
        C.broken = true
        Build(page, window)
        C.broken = false
    end
    local before = C.mode
    OwnLayout(page, window)
    C.mode = "own"
    Look.Shown(C.holder, true)
    C.Pin()
    -- Taken over while the page shows (a fight's end after Y was first
    -- opened in it, the gamepad mode gone): drawn now, not on its next show.
    if before ~= "own" and C.Live() then C.Refresh() end
end

-- Off: the journal puts the game's pieces back and hides EraUI's page (its
-- frame is one of the kit's); nothing here follows the game until on again.
L.Undo(function()
    C.mode = nil
    Untip()
end)
