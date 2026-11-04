-- The window chrome's kit (the "panels" look on the game's own windows): the
-- 1.x art it wears, the metal border on a window's nine-slice, the red X,
-- the bigger/smaller pair, the bottom and top tabs and their fit, and the
-- public names other files call (SkinCloseButton, SkinBottomTab,
-- FitBottomTab, SkinMaxMinButtons, WindowPiece, PanelButton).
--
-- Everything EraUI remembers about the game's frames (the corners' first
-- height, each tab's lift and padding, which tabs are EraUI's) lives in weak
-- tables here, never on the frames. Only colours, art, sizes and anchors of
-- the game's regions are set; no script of the game's is replaced.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local C = {}
Look.Chrome = C

-- The art. Corners go through the art lookup (Dark Mode greys them); the
-- edges, stone, streaks, title strip and floor are put on straight from
-- their files (Dark Windows paints them instead).
do
    local define, FRAME, BUTTONS, PAPER = Look.DefineArt, "Interface\\FrameGeneral\\", "Interface\\Buttons\\",
        "Interface\\PaperDollInfoFrame\\"
    define("frameMetal", FRAME .. "UIFrameMetal", "UIFrameMetal", "frameMetal")
    define("frameMetalH", FRAME .. "UIFrameMetalHorizontal", "UIFrameMetalHorizontal")
    define("frameMetalV", FRAME .. "UIFrameMetalVertical", "UIFrameMetalVertical")
    define("frameSheet", nil, "_UI-Frame", nil, true)
    define("tabActive", PAPER .. "UI-Character-ActiveTab", "UI-Character-ActiveTab", "tabActive")
    define("tabInactive", PAPER .. "UI-Character-InActiveTab", "UI-Character-InActiveTab", "tabInactive")
    define("tabHighlight", PAPER .. "UI-Character-Tab-RealHighlight", "UI-Character-Tab-RealHighlight")
    for state, key in pairs({ Up = "Up", Down = "Down", Disabled = "Disabled" }) do
        define("bigger" .. key, BUTTONS .. "UI-Panel-BiggerButton-" .. state, "UI-Panel-BiggerButton-" .. state)
        define("smaller" .. key, BUTTONS .. "UI-Panel-SmallerButton-" .. state, "UI-Panel-SmallerButton-" .. state)
    end
    define("namePlate", nil, "UI-QuestItemNameFrame", nil, true)
    define("lootPanel", nil, "UI-LootPanel", "lootPanel", true)
    define("lootIcon", nil, "LootPanel-Icon", nil, true)
    define("lootSkull", "Interface\\TargetingFrame\\TargetDead", "TargetDead")
    define("merchantBottom", nil, "UI-Merchant-BottomBorder", "merchantBottom", true)
    define("merchantLabelSlots", nil, "UI-Merchant-LabelSlots", "merchantLabelSlots", true)
end

-- Records about the game's frames (weak keys).
C.cornerFirstY = Look.Weak() -- bottom corner texture: the y it had before any lift
C.tabNotes = Look.Weak()     -- tab: { lift, padding, liftedTo, top }
C.ourTabs = Look.Weak()      -- tab: true once EraUI dressed it (the resize hook refits these)
C.dressed = Look.Weak()      -- window: the options it was dressed with
C.mine = Look.Weak()         -- texture or font string EraUI made on a game frame: true

-- EraUI's own piece on a game window, recorded so other code can find it
-- (and so fading the game's art can pass over it).
local PIECE_PREFIX = "chrome."
function C.Piece(window, piece, layer, sublevel)
    local made = Look.OwnTexture(window, PIECE_PREFIX .. piece, layer, sublevel)
    C.mine[made] = true
    return made
end

function C.Found(window, piece)
    return Look.OwnPiece(window, PIECE_PREFIX .. piece)
end

-- The window chrome's piece by name: "backing" (the stone), "streaks",
-- "titleStrip" or "insetFloor"; nil when it was never made.
function ns.WindowPiece(window, piece)
    if not window or type(piece) ~= "string" then return nil end
    return C.Found(window, piece)
end

function C.Name(frame)
    local fine, called = Look.Ask(frame, "GetName")
    return fine and type(called) == "string" and called or nil
end

-- A frame's own field, else the global "<name><suffix>".
function C.Part(frame, field, suffix)
    local own = frame and frame[field]
    if own then return own end
    local called = C.Name(frame)
    return called and _G[called .. (suffix or field)] or nil
end

function C.IsTexture(region)
    return region ~= nil and type(region.IsObjectType) == "function" and region:IsObjectType("Texture")
end

---------------------------------------------------------------------------
-- The metal border
---------------------------------------------------------------------------

-- The metal sheet is 512 square: each corner is a 132 square cut from it,
-- by its left and top pixel. The ring's top left holds the round portrait
-- hole. A window without the ring swaps only its top left for the plain
-- piece (a top left shape): its other three corners are the ring window's,
-- so they meet the same edges.
local SHEET = 512
local function Cut(left, top)
    return { left / SHEET, (left + 132) / SHEET, top / SHEET, (top + 132) / SHEET }
end
local CORNERS = { TopLeftCorner = Cut(135, 135), TopRightCorner = Cut(1, 135), BottomLeftCorner = Cut(1, 1),
    BottomRightCorner = Cut(135, 1) }
local PLAIN_CORNER = Cut(269, 1)
C.Cut = Cut
-- Edge: sheet, crop, size, wraps across (else down).
local EDGES = {
    TopEdge = { "frameMetalH", { 0, 1, 0.263671875, 0.263671875 + 48 / 512 }, 128, 48, true },
    BottomEdge = { "frameMetalH", { 0, 1, 0.001953125, 0.259765625 }, 128, 132, true },
    LeftEdge = { "frameMetalV", { 0.001953125, 0.259765625, 0, 1 }, 132, 128, false },
    RightEdge = { "frameMetalV", { 0.263671875, 0.521484375, 0, 1 }, 132, 128, false },
}
C.EDGE_KEYS = { "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }

-- A bottom corner raised by lift from where the game first had it (so a
-- second dressing never raises it twice).
local function Raise(corner, lift)
    local point, relative, relativePoint, x, y = corner:GetPoint(1)
    x, y = Look.Number(x), Look.Number(y)
    if type(point) ~= "string" or not x or not y then return end
    if C.cornerFirstY[corner] == nil then C.cornerFirstY[corner] = y end
    corner:ClearAllPoints()
    corner:SetPoint(point, relative, relativePoint, x, C.cornerFirstY[corner] + lift)
end

-- The plain top left keeps its anchor but never sits more than 8 out.
local function Tuck(corner)
    local point, relative, relativePoint, x, y = corner:GetPoint(1)
    x = Look.Number(x)
    if type(point) == "string" and x and x < -8 then
        corner:ClearAllPoints()
        corner:SetPoint(point, relative, relativePoint, -8, Look.Number(y) or 0)
    end
end

function C.Border(slice, ring, lift)
    for key, crop in pairs(CORNERS) do
        local corner = slice[key]
        if corner then
            Look.Art(corner, "frameMetal")
            local plain = key == "TopLeftCorner" and not ring
            local cut = plain and PLAIN_CORNER or crop
            Look.Crop(corner, cut[1], cut[2], cut[3], cut[4])
            corner:SetSize(132, 132)
            if plain then Tuck(corner) end
            if key == "BottomLeftCorner" or key == "BottomRightCorner" then Raise(corner, lift) end
        end
    end
    for _, key in ipairs(C.EDGE_KEYS) do
        local edge, shape = slice[key], EDGES[key]
        if edge then
            Look.PlainArt(edge, shape[1], shape[5], not shape[5])
            Look.Crop(edge, shape[2][1], shape[2][2], shape[2][3], shape[2][4])
            edge:SetSize(shape[3], shape[4])
        end
    end
end

---------------------------------------------------------------------------
-- The red X and the bigger/smaller pair
---------------------------------------------------------------------------

-- The 1.x red X (32 x 32, the minimise-button art, handed to Dark Windows),
-- placed at the top right of its window's metal (or of the window) unless
-- keepPosition.
function ns.SkinCloseButton(button, keepPosition)
    if not button then return end
    Look.SkinCloseButton(button)
    if keepPosition then return end
    local holder = button:GetParent()
    local corner = holder and holder.NineSlice and holder.NineSlice.TopRightCorner
    if corner then
        Look.Pin(button, "TOPRIGHT", corner, "TOPRIGHT", 0.6, -11)
    elseif holder then
        Look.Pin(button, "TOPRIGHT", holder, "TOPRIGHT", 4.6, 5)
    end
end

-- One of the pair: each state from its sheet, filling the button, the X's
-- glow, the hit area 5 in on every side, handed to Dark Windows.
local function PairButton(button, sheet)
    if not button then return end
    for state, art in pairs({ Normal = sheet .. "Up", Pushed = sheet .. "Down", Disabled = sheet .. "Disabled",
        Highlight = "closeHighlight" }) do
        local face = Look.StateArt(button, state, art)
        if face then
            Look.Fill(face, button)
            Look.Crop(face, 0, 1, 0, 1)
            if state == "Highlight" then face:SetBlendMode("ADD") end
        end
    end
    if button.SetHitRectInsets then button:SetHitRectInsets(5, 5, 5, 5) end
    if ns.DarkCloseButton then ns.DarkCloseButton(button) end
end

-- The bigger/smaller pair on a frame holding MaximizeButton and
-- MinimizeButton.
function ns.SkinMaxMinButtons(pair)
    if not pair then return end
    PairButton(pair.MaximizeButton, "bigger")
    PairButton(pair.MinimizeButton, "smaller")
end

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------

local function Notes(tab)
    local notes = C.tabNotes[tab]
    if not notes then
        notes = {}
        C.tabNotes[tab] = notes
    end
    return notes
end

-- The text a tab shows: its Text, else its font string.
local function TabText(tab)
    return tab.Text or (tab.GetFontString and tab:GetFontString())
end

-- A tab hung straight on its own parent is lifted once (and again only once
-- something else has moved it); its width follows its text plus padding.
-- padding and lift, when given, are kept for this tab from now on.
function ns.FitBottomTab(tab, padding, lift)
    if not tab then return end
    local notes = Notes(tab)
    if Look.Number(padding) then notes.padding = padding end
    if Look.Number(lift) then notes.lift = lift end
    local point, relative, relativePoint, x, y = tab:GetPoint(1)
    x, y = Look.Number(x), Look.Number(y)
    if type(point) == "string" and x and y and relative ~= nil and relative == tab:GetParent() then
        if notes.liftedTo == nil or math.abs(y - notes.liftedTo) > 0.01 then
            local raised = y + (notes.lift or 10)
            tab:SetPoint(point, relative, relativePoint, x, raised)
            notes.liftedTo = raised
        end
    end
    local text = TabText(tab)
    local across = text and Look.Number(text:GetStringWidth())
    if not across then return end
    local wide = math.ceil(across) + (notes.padding or (notes.top and 36 or 50))
    tab:SetWidth(wide)
    for _, key in ipairs({ "Middle", "MiddleActive" }) do
        local middle = tab[key]
        if middle and middle.SetWidth then middle:SetWidth(wide - 40) end
    end
end

-- Pieces: art key, crop top and bottom, height, the y of its top (bottom
-- tabs) from the tab's top.
local TAB_PIECES = {
    { "LeftActive", "tabActive", 0, 0.15625, 0.546875, 35, 0 },
    { "RightActive", "tabActive", 0.84375, 1, 0.546875, 35, 0 },
    { "MiddleActive", "tabActive", 0.15625, 0.84375, 0.546875, 35 },
    { "Left", "tabInactive", 0, 0.15625, 1, 32, -4 },
    { "Right", "tabInactive", 0.84375, 1, 1, 32, -4 },
    { "Middle", "tabInactive", 0.15625, 0.84375, 1, 32 },
}

local function TabGlow(tab, flipped)
    local glow = tab.GetHighlightTexture and tab:GetHighlightTexture()
    if not glow then
        if type(tab.SetHighlightTexture) ~= "function" then return end
        local path = Look.FirstPath("tabHighlight")
        if not path then return end
        tab:SetHighlightTexture(path)
        glow = tab:GetHighlightTexture()
    end
    if not glow then return end
    Look.Art(glow, "tabHighlight")
    glow:ClearAllPoints()
    if flipped then
        Look.Crop(glow, 0, 1, 1, 0)
        glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 0)
        glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, -5)
    else
        Look.Crop(glow, 0, 1, 0, 1)
        glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 5)
        glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 0)
    end
    glow:SetBlendMode("ADD")
end

-- The character sheet's tab art on one of the game's tabs: on its foot
-- (bottom), or flipped onto its top edge (top, the macro window's). Needs
-- the tab's Left piece.
local function DressTab(tab, flipped, padding, lift)
    if not tab or not tab.Left then return end
    for _, shape in ipairs(TAB_PIECES) do
        local piece = tab[shape[1]]
        if piece then
            Look.Art(piece, shape[2])
            if flipped then Look.Crop(piece, shape[3], shape[4], shape[5], 0) else Look.Crop(piece, shape[3], shape[4], 0, shape[5]) end
            if piece.SetHorizTile then piece:SetHorizTile(false) end
            piece:SetHeight(shape[6])
            if shape[7] ~= nil then
                piece:SetWidth(20)
                local side = shape[1]:find("Left") and "LEFT" or "RIGHT"
                piece:ClearAllPoints()
                if flipped then
                    piece:SetPoint("BOTTOM" .. side, tab, "BOTTOM" .. side, 0, 0)
                else
                    piece:SetPoint("TOP" .. side, tab, "TOP" .. side, 0, shape[7])
                end
            elseif flipped then
                local left, right = tab[shape[1]:gsub("Middle", "Left")], tab[shape[1]:gsub("Middle", "Right")]
                if left and right then
                    piece:ClearAllPoints()
                    piece:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", 0, 0)
                    piece:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT", 0, 0)
                end
            end
        end
    end
    for _, key in ipairs({ "LeftHighlight", "MiddleHighlight", "RightHighlight" }) do Look.Fade(tab[key]) end
    C.ourTabs[tab] = true
    Notes(tab).top = flipped or nil
    ns.FitBottomTab(tab, padding, lift)
    TabGlow(tab, flipped)
end

function ns.SkinBottomTab(tab, padding, lift)
    DressTab(tab, false, padding, lift)
end

function C.SkinTopTab(tab, padding, lift)
    DressTab(tab, true, padding, lift)
end

-- The game resizing a tab EraUI dressed: fitted again at once.
Look.HookGlobal("PanelTemplates_TabResize", function(tab)
    if tab and C.ourTabs[tab] then Look.Try(ns.FitBottomTab, tab) end
end)

---------------------------------------------------------------------------
-- The red panel button (one maker, Look/Base.lua's)
---------------------------------------------------------------------------

function ns.PanelButton(parent, text, width)
    return Look.PanelButton(parent, text, width)
end
