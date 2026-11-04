-- The Legacy window's Legacy Tree page in the 1.x look (registry
-- "legacyWindow"), as the old talent window on the spellbook-sized
-- parchment:
--   * the three trees (Professions, Adventure, Resourcefulness) as the
--     spellbook's icon tabs down the window's right edge: the game's own
--     tree buttons, 32 x 32 on the old tab plate, the old glow while chosen;
--   * the points in the frame's stone band on a rank plate before
--     "Available points" (the game's retail crown faded);
--   * above the tree: the chosen tree's emblem in the old professions book
--     ring, the points spent on a rank plate at its foot, its name in gold
--     beside it and the game's search under the name, then a thin rule;
--   * the tree centred under them, fitted from where the game puts each
--     talent and how big each one is (L.FitTree; the talents themselves
--     keep their size): brought closer together when it is bigger than the
--     page, and spread across or down where two would touch (a talent off
--     the tree's grid, as in Adventure), so no two talents or rank plates
--     ever meet and none is cut off; each talent in the old socket coloured
--     by its state (gold learned, green open, grey locked, red when it
--     can't be taken back), its rank as the old talent window showed it,
--     "current/max" in the old small font on the old rank box sized to it,
--     in the state's colour, the game's own retail border, glows, rank text
--     and rank box faded; the links between them are Look/LegacyEdges.lua's;
--   * Apply Changes as the old red button at the foot, above the
--     parchment's burnt rim, undo and reset as old round buttons beside it.
-- Every button and talent stays the game's own and keeps working; each is
-- dressed the first time it shows and painted again after each of the
-- game's own state changes (in a fight, EraUI's own sockets, plates and
-- tab glow only, and the talents laid out again: the game loads the tree
-- again each time the page shows).
local _, EraUI = ...
local Look = EraUI.Look
local L = Look.Legacy

local nodes = L.Record(Look.Weak()) -- a talent button: { socket, size, plate, left, right, rank, glow, state }
local tabs = L.Record(Look.Weak())  -- a tree button: { checked }
-- A talent's place: { gx, gy (where the game put it), x, y (where EraUI did) }
L.spots = L.Record(Look.Weak())

-- The page's places (window units from its top left, down positive).
local SUMMARY_X = 85                       -- "Available points" in the band (its plate before it)
local EMBLEM, RING, RING_X, RING_Y = 46, 60, 42, 96
local NAME_X, NAME_Y = 84, 80
local SEARCH_X, SEARCH_Y = 98, 110
local SPENT_W, SPENT_H = 36, 30
local RULE_Y = 131
-- Apply's middle: its foot (it is 22 tall; undo and reset beside it 25)
-- above the parchment's burnt rim, not on it.
local APPLY_X, APPLY_Y = 148, L.PAGE.bottom - L.EDGE - 16
-- The tree's box: the game's talent holder, which shows only what is in it,
-- is the panel less 54 at its top and foot (the game's own padding). From
-- under the rule to 3 above Apply.
local TREE_LEFT, TREE_TOP, TREE_RIGHT, PAD = 12, 134, 324, 54
local TREE_FOOT = APPLY_Y - 11 - 3
-- Around each talent: a rim past its icon (its socket's edge), and at least
-- GAP between any two talents' rims or plates.
local RIM, GAP = 1, 4
-- The share of the rank plate's art that is drawn (across, down), as seen
-- in game: the rest of its square is clear.
L.PLATE_SEEN = { 0.46, 0.44 }

-- A talent's rank plate (square) for an icon `across` wide.
local function PlateSize(across)
    return math.max(32, math.min(44, across * 0.9))
end

-- A talent's rank as the old talent window's: "current/max" in its small
-- font on the rank plate's art made a box (its two ends at their own size,
-- a sliver of its middle stretched between them), RANK_PAD clear of the
-- box's drawn edge on either side (about the old window's, a digit in its
-- box). The cuts of the plate's art across.
local RANK_FONT, RANK_PAD = "GameFontNormalSmall", 5
local BOX_LEFT, BOX_MIDDLE, BOX_RIGHT = { 0, 0.5 }, { 0.48, 0.52 }, { 0.5, 1 }
-- The game's own rank box behind its rank text (build 70532 on): it has no
-- key, so it is found by its art (GameBox).
local GAME_BOX = "talents-square-box-c60"

-- EraUI's own hidden label in the rank font that ranks are measured with
-- (made by L.DressTree).
local measure

-- How wide a rank is in the rank font (6 a character until the label is
-- made).
local function Wide(words)
    if words == "" then return 0 end
    if measure then
        measure:SetText(words)
        local wide = Look.Number(measure:GetStringWidth())
        if wide and wide > 0 then return wide end
    end
    return #words * 6
end

-- "current/max" as the game writes it (its own GENERIC_FRACTION_STRING).
local function Fraction(now, most)
    local form = type(GENERIC_FRACTION_STRING) == "string" and GENERIC_FRACTION_STRING or "%d/%d"
    local fine, words = pcall(string.format, form, now, most)
    if fine and type(words) == "string" then return words end
    return now .. "/" .. most
end

-- A talent's rank to show, "current/max", and the widest it can be
-- ("max/max", what its box is sized for, so a point spent moves nothing).
-- From build 70532 the game writes "current/max" itself, kept as it is.
-- Before, it wrote only the current rank (nothing for a talent not taken
-- that can't be yet): then it is made from the talent's own ranks (its
-- node's, as the game reads them). Nothing it can read: "".
local function Ranks(button)
    local info = L.Field(button, "nodeInfo")
    local now = type(info) == "table" and Look.Number(L.Field(info, "currentRank")) or nil
    local most = type(info) == "table" and Look.Number(L.Field(info, "maxRanks")) or nil
    local known = now ~= nil and most ~= nil and most > 0 and now >= 0
    local spend = L.Field(button, "SpendText")
    local said = spend and spend.GetText and spend:GetText()
    if type(said) ~= "string" or Look.Secret(said) then said = "" end
    if said ~= "" and not said:find("^%d+$") then return said, known and Fraction(most, most) or said end
    if known then return Fraction(now, most), Fraction(most, most) end
    return said, said
end

-- The rank box's stretched middle, for its plate's size and the widest rank
-- it shows (its drawn width: this and the plate's own drawn share).
local function BoxMiddle(size, widest)
    return math.max(1, Wide(widest) + 2 * RANK_PAD - size * L.PLATE_SEEN[1])
end

---------------------------------------------------------------------------
-- The trees as the spellbook's side tabs
---------------------------------------------------------------------------

local TAB_FADED = { "Background", "SelectedGlow", "Ring", "CheckedTexture" }
local TAB_PITCH = 47 -- 32 tall, the game's own 15 between

local function PaintTab(button)
    local own = tabs[button]
    if not own then return end
    local fine, checked = pcall(button.GetChecked, button)
    Look.Shown(own.checked, fine and not Look.Secret(checked) and checked == true)
end

local function DressTab(button, window, index)
    local own = {}
    tabs[button] = own
    for _, key in ipairs(TAB_FADED) do L.Fade(L.Field(button, key)) end
    L.Fade(button.GetHighlightTexture and button:GetHighlightTexture())
    L.Size(button, 32, 32)
    L.Pin(button, "TOPLEFT", window, "TOPRIGHT", 1, -50 - (index - 1) * TAB_PITCH)
    local plate = L.Own(button, "plate", "BACKGROUND", -1)
    Look.Art(plate, "sbSkillTab")
    plate:SetSize(64, 64)
    Look.Pin(plate, "TOPLEFT", button, "TOPLEFT", -3, 11)
    own.checked = L.Own(button, "checked", "OVERLAY", 2, true)
    Look.Art(own.checked, "slotChecked")
    own.checked:SetBlendMode("ADD")
    Look.Fill(own.checked, button)
    local glow = L.Own(button, "glow", "HIGHLIGHT", 0)
    Look.Art(glow, "slotHighlight")
    glow:SetBlendMode("ADD")
    Look.Fill(glow, button)
    -- EraUI's own glow only: a tree chosen in a fight moves it too.
    L.AfterOwn(button, "RefreshSelectionVisuals", PaintTab)
end

function L.TreeTabs(selector, window)
    if not (selector and window) then return end
    local list = L.Field(selector, "treeButtons")
    if type(list) ~= "table" then return end
    for index, button in ipairs(list) do
        if not tabs[button] then Look.Try(DressTab, button, window, index) end
        PaintTab(button)
    end
end

local function SideTabs(page, window)
    local selector = L.Field(page, "LegacyTreeSelectionPanel")
    if not selector then return end
    -- Its list (the game lays the buttons out on show) hangs from the
    -- panel's top: the panel's top 16 right of the window's edge puts the
    -- 32-wide column just outside it, as the spellbook's tabs are.
    L.Pin(selector, "TOP", window, "TOPRIGHT", 17, -50)
    L.TreeTabs(selector, window)
    L.After(selector, "UpdateSelection", function(self) L.TreeTabs(self, window) end)
end

---------------------------------------------------------------------------
-- The chosen tree's emblem, name and points
---------------------------------------------------------------------------

-- The emblem in the professions book's round ring (Look/LegacyKit.lua) at
-- the parchment's top left, the points spent on a rank plate at its foot
-- (overlapping the ring like the old talent ranks), the name beside it and
-- the game's search under the name.
local function Emblem(panel, window)
    local emblem = L.Field(panel, "SelectedTreeIcon")
    if not emblem then return end
    for _, key in ipairs({ "Ring", "CheckedTexture" }) do L.Fade(L.Field(emblem, key)) end
    L.Fade(emblem.GetHighlightTexture and emblem:GetHighlightTexture())
    L.Size(emblem, EMBLEM, EMBLEM)
    L.At(emblem, "CENTER", window, RING_X, RING_Y)
    local ring = L.Ring(emblem, "ring", RING, "OVERLAY", 3)
    Look.Pin(ring, "CENTER", emblem, "CENTER", 0, 0)
    local name = L.Field(emblem, "SelectedTreeLabel")
    if name then
        L.Font(name, GameFontNormalLarge)
        L.GoldName(name)
        L.Justify(name, "LEFT")
        L.At(name, "LEFT", window, NAME_X, NAME_Y)
    end
    local spent = L.Field(panel, "SpentPointsFrame")
    if spent then
        L.Fade(L.Field(spent, "Background"))
        L.Pin(spent, "CENTER", emblem, "BOTTOMRIGHT", 0, 4)
        local plate = L.Plate(spent, "plate", "BACKGROUND", 2, false, SPENT_W, SPENT_H)
        Look.Pin(plate, "CENTER", spent, "CENTER", 0, 0)
        local text = L.Field(spent, "Text")
        L.Font(text, GameFontNormalLarge)
        L.GoldName(text)
    end
    L.At(L.Field(panel, "SearchBox"), "LEFT", window, SEARCH_X, SEARCH_Y)
end

---------------------------------------------------------------------------
-- Apply, undo and reset
---------------------------------------------------------------------------

-- One of the game's small icon buttons as an old round button.
local function RoundButton(button, key)
    if not button then return end
    local icon = L.Field(button, "Icon")
    if icon then
        L.KeepArt(icon)
        Look.Art(icon, key)
        Look.Crop(icon, 0, 1, 0, 1)
        icon:SetSize(24, 24)
    end
    local glow = button.GetHighlightTexture and button:GetHighlightTexture()
    if glow then
        L.KeepArt(glow)
        Look.Art(glow, "legacyRoundGlow")
        Look.Crop(glow, 0, 1, 0, 1)
        glow:SetBlendMode("ADD")
    end
end

-- Apply at the parchment's foot, above its burnt rim; undo and reset stay
-- beside it, where the game anchors them (so they move up with it).
local function Buttons(panel, window)
    local apply = L.Field(panel, "ApplyButton")
    if apply then
        Look.SkinRedButton(apply)
        L.Fade(L.Field(apply, "YellowGlow"))
        L.At(apply, "CENTER", window, APPLY_X, APPLY_Y)
    end
    RoundButton(L.Field(panel, "UndoButton"), "legacyUndo")
    RoundButton(L.Field(panel, "ResetButton"), "legacyReset")
end

---------------------------------------------------------------------------
-- The tree fitted to the page
---------------------------------------------------------------------------

-- The panel set so its talent holder (the panel less the game's padding at
-- its top and foot) is the tree's box. The game anchors the panel once and
-- only ever pads the holder inside it, so this holds.
local function TreeBox(panel, window)
    L.Pins(panel, { "TOPLEFT", window, "TOPLEFT", TREE_LEFT, -(TREE_TOP - PAD) },
        { "BOTTOMRIGHT", window, "TOPLEFT", TREE_RIGHT, -(TREE_FOOT + PAD) })
end

-- Where the game put a talent (its middle on the holder's top left, from
-- the talent's place in the tree): its anchor, unless that is still where
-- EraUI put it (then the game's, as kept). Nil for a talent placed some
-- other way.
local function GameSpot(button, holder)
    local point, relative, relativePoint, x, y = button:GetPoint(1)
    x, y = Look.Number(x), Look.Number(y)
    if point ~= "CENTER" or relative ~= holder or relativePoint ~= "TOPLEFT" or not x or not y then return nil end
    local own = L.spots[button]
    if own and own.x and math.abs(own.x - x) < 0.01 and math.abs(own.y - y) < 0.01 then return own.gx, own.gy end
    return x, y
end

-- The talents the game shows, each with where the game put it, and the
-- tree's edges (its talents' middles).
local function Shown(panel, holder)
    local found, edges = {}, { left = math.huge, right = -math.huge, top = -math.huge, foot = math.huge }
    L.EachActive(L.Field(panel, "talentButtonCollection"), function(button)
        local x, y = GameSpot(button, holder)
        if not x then return end
        table.insert(found, { button, x, y })
        edges.left, edges.right = math.min(edges.left, x), math.max(edges.right, x)
        edges.top, edges.foot = math.max(edges.top, y), math.min(edges.foot, y)
    end)
    return found, edges
end

-- How far a talent reaches round its middle (window units): its icon or
-- its button, the bigger, and RIM on every side; at its right and foot its
-- rank box too, which hangs over the icon's corner (its middle 2 in from
-- it): L.PLATE_SEEN of its plate drawn, and across, its middle stretched to
-- the talent's widest rank, so a rank shown later (a point spent) moves
-- nothing.
local function TalentReach(button)
    local icon = L.Field(button, "Icon")
    local iconW = icon and Look.Number(icon:GetWidth()) or 0
    local buttonW = Look.Number(button:GetWidth()) or 0
    local face = iconW > 0 and iconW or buttonW
    local half = math.max(iconW, buttonW) / 2 + RIM
    local corner = face / 2 - 2
    local own = nodes[button]
    local size = own and own.size or PlateSize(face > 0 and face or 40)
    local _, widest = Ranks(button)
    local boxW = (size * L.PLATE_SEEN[1] + BoxMiddle(size, widest)) / 2
    local boxH = size * L.PLATE_SEEN[2] / 2
    return { left = math.max(half, boxW - corner), top = half, right = math.max(half, corner + boxW),
        foot = math.max(half, corner + boxH) }
end

-- Each talent's own reach (kept in its entry, entry[4]) and the most any
-- of the tree's talents reaches each way: what two talents need between
-- them.
local function Reach(found)
    local most = { left = 0, top = 0, right = 0, foot = 0 }
    for _, entry in ipairs(found) do
        local reach = TalentReach(entry[1])
        entry[4] = reach
        for side, far in pairs(reach) do most[side] = math.max(most[side], far) end
    end
    return most
end

-- How far apart the talents go across and down (1: as the game has them).
-- The game's spacing while the tree fits the box, else closer, the same
-- both ways, so nothing is cut off. Then any two that would still be nearer
-- than GAP (a talent off the tree's grid) go further apart, across or down,
-- whichever the box has room for with the least change; with no room
-- either way, as far apart as the box allows.
local function Spacing(found, edges, reach)
    local roomX = (TREE_RIGHT - TREE_LEFT) - reach.left - reach.right
    local roomY = (TREE_FOOT - TREE_TOP) - reach.top - reach.foot
    local spanX, spanY = edges.right - edges.left, edges.top - edges.foot
    local mostX = spanX > 0 and roomX / spanX or math.huge
    local mostY = spanY > 0 and roomY / spanY or math.huge
    local start = math.max(0.05, math.min(1, mostX, mostY))
    local sx, sy = start, start
    local needX, needY = reach.left + reach.right + GAP, reach.top + reach.foot + GAP
    -- Each round settles at least one pair, or nothing changes.
    for _ = 1, #found do
        local changed = false
        for i = 1, #found - 1 do
            for j = i + 1, #found do
                local dx = math.abs(found[i][2] - found[j][2])
                local dy = math.abs(found[i][3] - found[j][3])
                if dx * sx < needX - 0.01 and dy * sy < needY - 0.01 then
                    local wantX = dx > 0 and needX / dx or math.huge
                    local wantY = dy > 0 and needY / dy or math.huge
                    local fitsX, fitsY = dx > 0 and wantX <= mostX, dy > 0 and wantY <= mostY
                    if fitsX and (not fitsY or wantX / sx <= wantY / sy) then
                        sx, changed = wantX, true
                    elseif fitsY then
                        sy, changed = wantY, true
                    elseif dx > 0 and (dy == 0 or dx * mostX / needX >= dy * mostY / needY) then
                        if mostX > sx then sx, changed = mostX, true end
                    elseif dy > 0 and mostY > sy then
                        sy, changed = mostY, true
                    end
                end
            end
        end
        if not changed then break end
    end
    return sx, sy
end

-- Every talent the game shows moved so the tree (with its talents' reach)
-- is centred in the box, spaced by Spacing; the talents keep their size and
-- the links follow them (the game's and EraUI's). Anchors only, so also in
-- a fight (the game lays the tree out again each time the page shows).
-- True when a talent moved.
function L.FitTree(panel)
    local holder = L.Field(panel, "ButtonsParent")
    if not holder then return false end
    local found, edges = Shown(panel, holder)
    if #found == 0 then return false end
    local reach = Reach(found)
    local sx, sy = Spacing(found, edges, reach)
    local wide, tall = TREE_RIGHT - TREE_LEFT, TREE_FOOT - TREE_TOP
    local midX, midY = (edges.left + edges.right) / 2, (edges.top + edges.foot) / 2
    -- The spaced tree's own edges (each talent with its own reach: rank
    -- boxes differ in width), its middle on the box's.
    local left, right, top, foot = math.huge, -math.huge, -math.huge, math.huge
    for _, entry in ipairs(found) do
        local x, y, far = (entry[2] - midX) * sx, (entry[3] - midY) * sy, entry[4]
        left, right = math.min(left, x - far.left), math.max(right, x + far.right)
        top, foot = math.max(top, y + far.top), math.min(foot, y - far.foot)
    end
    local toX, toY = wide / 2 - (left + right) / 2, -tall / 2 - (top + foot) / 2
    local moved = false
    for _, entry in ipairs(found) do
        local button = entry[1]
        local own = L.spots[button]
        if not own then
            own = {}
            L.spots[button] = own
        end
        local x, y = toX + (entry[2] - midX) * sx, toY + (entry[3] - midY) * sy
        local _, _, _, nowX, nowY = button:GetPoint(1)
        nowX, nowY = Look.Number(nowX), Look.Number(nowY)
        local there = nowX and nowY and math.abs(nowX - x) < 0.01 and math.abs(nowY - y) < 0.01
        own.gx, own.gy, own.x, own.y = entry[2], entry[3], x, y
        if not there then
            moved = true
            button:ClearAllPoints()
            button:SetPoint("CENTER", holder, "TOPLEFT", x, y)
        end
    end
    L.treeScale = { x = sx, y = sy }
    return moved
end

-- Off: each talent EraUI moved back where the game put it.
L.Undo(function()
    local window = L.Window and L.Window()
    local page = window and L.Field(window, "TreePage")
    local panel = page and L.Field(page, "LegacyTreeTraitPanel")
    local holder = panel and L.Field(panel, "ButtonsParent")
    if not holder then return end
    local found = Shown(panel, holder)
    for _, entry in ipairs(found) do
        entry[1]:ClearAllPoints()
        entry[1]:SetPoint("CENTER", holder, "TOPLEFT", entry[2], entry[3])
    end
end)

---------------------------------------------------------------------------
-- The talents
---------------------------------------------------------------------------

-- What the game's own border says (its art name): "refund" (red),
-- "open" (green), "locked" (grey) or "learned" (gold).
function L.NodeState(button)
    local border = L.AtlasOf(L.Field(button, "StateBorder"))
    if border:find("red", 1, true) then return "refund" end
    if border:find("green", 1, true) then return "open" end
    for _, word in ipairs({ "disable", "locked", "gray", "grey" }) do
        if border:find(word, 1, true) then return "locked" end
    end
    return "learned"
end

-- The game's rank text too: EraUI's own stands on the rank box (the game
-- only sets its text, colour, font and place, never its alpha).
local NODE_FADED = { "StateBorder", "Shadow", "Ghost", "SpendText", "SpendTextShadow1", "SpendTextShadow2", "SpendTextShadow3",
    "SpendTextShadow4" }
-- Set again or animated by the game: faded by their colour's alpha.
local NODE_HUSHED = { "StateBorderHover", "Glow", "DisabledOverlay" }

-- The talent's socket colour and its rank on the rank box in the same
-- colour (EraUI's own, so also in a fight: the game hands a pooled talent a
-- new node then, and its socket and rank must not keep the old one's); out
-- of a fight, the game's own pieces too.
local function PaintNode(button)
    local own = nodes[button]
    if not own then return end
    if not Look.InFight() then
        for _, key in ipairs(NODE_HUSHED) do L.Hush(L.Field(button, key)) end
    end
    local state = L.NodeState(button)
    local colour = L.STATE[state]
    if own.state ~= state then
        own.state = state
        own.socket:SetVertexColor(colour[1], colour[2], colour[3])
    end
    local words, widest = Ranks(button)
    own.rank:SetText(words)
    own.rank:SetTextColor(colour[1], colour[2], colour[3])
    own.plate:SetWidth(BoxMiddle(own.size, widest))
    local shown = words ~= ""
    for _, piece in ipairs({ own.left, own.plate, own.right, own.rank }) do Look.Shown(piece, shown) end
end

-- The game's own rank box (build 70532 on): its art, or, should a client
-- not name its art, the one texture the game hangs from its rank text.
local function GameBox(piece, spend)
    if L.AtlasOf(piece) == GAME_BOX then return true end
    if not spend or not (piece.IsObjectType and piece:IsObjectType("Texture")) then return false end
    local fine, _, relative = pcall(piece.GetPoint, piece, 1)
    return fine and not Look.Secret(relative) and relative == spend
end

-- The rank box: the plate's art cut across (cut), a plate's size tall.
local function BoxPiece(button, purpose, cut, size, wide)
    local piece = L.Plate(button, purpose, "OVERLAY", 1, true, wide, size)
    Look.Crop(piece, cut[1], cut[2], 0, 1)
    return piece
end

local function DressNode(button)
    local icon = L.Field(button, "Icon")
    if not icon then return end
    local own = {}
    nodes[button] = own
    for _, key in ipairs(NODE_FADED) do L.Fade(L.Field(button, key)) end
    local spend = L.Field(button, "SpendText")
    Look.EachRegion(button, function(piece)
        if GameBox(piece, spend) then L.Fade(piece) end
    end)
    local across = Look.Number(icon:GetWidth()) or 40
    own.socket = L.Own(button, "socket", "BACKGROUND", -1)
    Look.Art(own.socket, "legacySocket")
    own.socket:SetSize(across * 1.5, across * 1.5)
    Look.Pin(own.socket, "CENTER", icon, "CENTER", 0, -1)
    -- The rank box over the icon's corner as the old rank plate was, its
    -- middle (PaintNode stretches it) between its two ends; the rank on it.
    own.size = PlateSize(across)
    own.plate = BoxPiece(button, "plate", BOX_MIDDLE, own.size, 1)
    Look.Pin(own.plate, "CENTER", icon, "BOTTOMRIGHT", -2, 2)
    own.left = BoxPiece(button, "plateLeft", BOX_LEFT, own.size, own.size / 2)
    Look.Pin(own.left, "RIGHT", own.plate, "LEFT", 0, 0)
    own.right = BoxPiece(button, "plateRight", BOX_RIGHT, own.size, own.size / 2)
    Look.Pin(own.right, "LEFT", own.plate, "RIGHT", 0, 0)
    own.rank = L.Label(button, "rank", RANK_FONT, "OVERLAY")
    own.rank:SetDrawLayer("OVERLAY", 2)
    Look.Pin(own.rank, "CENTER", own.plate, "CENTER", 0, 0)
    own.glow = L.Own(button, "glow", "HIGHLIGHT", 0)
    Look.Art(own.glow, "slotHighlight")
    own.glow:SetBlendMode("ADD")
    Look.Fill(own.glow, icon)
    for _, method in ipairs({ "ApplyVisualState", "UpdateSpendText", "UpdateNonStateVisuals" }) do L.AfterOwn(button, method, PaintNode) end
end

function L.Node(button)
    if type(button) ~= "table" then return end
    if not nodes[button] then Look.Try(DressNode, button) end
    PaintNode(button)
end

-- The tier gates: their lock faded, their words in the old red.
local function Gate(gate)
    L.Fade(L.Field(gate, "LockIcon"))
    L.Paint(L.Field(gate, "GateText"), L.RED, true)
end

-- Every talent shown, its links, and the gates (newOnly: only what isn't
-- dressed yet).
function L.Nodes(panel, newOnly)
    if not panel then return end
    L.EachActive(L.Field(panel, "talentButtonCollection"), function(button)
        if not (newOnly and nodes[button]) then L.Node(button) end
    end)
    L.EachActive(L.Field(panel, "gatePool"), Gate)
    if L.Edges then L.Edges(panel) end
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

-- The tree fitted again, and its links drawn again when that moved a talent
-- (EraUI's own link pieces only in a fight, see Look/LegacyEdges.lua).
local function Refit(panel)
    if L.FitTree(panel) and L.Edges then L.Edges(panel, true) end
end
L.Refit = Refit

function L.DressTree(page, window)
    if not (page and window) then return end
    measure = L.Label(page, "rankMeasure", RANK_FONT, "OVERLAY")
    measure:Hide()
    L.FadeArt(L.Field(page, "VerticalDivider"))
    L.Rule(page, window, RULE_Y)
    local summary = L.Field(page, "LegacyTreePointSummary")
    if summary then
        L.Fade(L.Field(summary, "Border"))
        -- In the band; its words' middle (6 under its own) on the band's.
        L.At(summary, "TOPLEFT", window, SUMMARY_X, L.BAND - 6 - 18)
        -- The points on a rank plate just before "Available points".
        L.ShieldPlate(L.Field(summary, "Shield"), L.Field(summary, "AvailablePointsLabel"), -16)
    end
    Look.Try(SideTabs, page, window)
    local panel = L.Field(page, "LegacyTreeTraitPanel")
    if not panel then return end
    Look.Try(TreeBox, panel, window)
    Look.Try(Emblem, panel, window)
    Look.Try(Buttons, panel, window)
    -- The game loads the whole tree again each time the page shows: the
    -- talents fitted again right after (in a fight too), then, out of a
    -- fight, dressed and painted (in one, their own hooks paint EraUI's
    -- pieces).
    L.AfterOwn(panel, "LoadTalentTreeInternal", function(self)
        L.FitTree(self)
        if not Look.InFight() then L.Nodes(self) end
    end)
    -- A talent the game makes again on its own (its kind changed).
    L.AfterOwn(panel, "InstantiateTalentButton", Refit)
    L.AfterOwn(panel, "UpdateAllTalentButtonPositions", function(self)
        L.FitTree(self)
        if L.Edges then L.Edges(self, true) end
    end)
    L.After(panel, "UpdateEdgesForButton", function(self, button)
        L.Node(button)
        if L.EdgesOf then L.EdgesOf(self, button) end
    end)
    L.FitTree(panel)
    L.Nodes(panel)
end
