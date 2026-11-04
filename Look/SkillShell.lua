-- The old skill windows' shell, shared by the trade skill window and the
-- trainer: the iron-bordered list box with its tab, the All button and the
-- Filter drop down above it, the rows, the 1.x scroll bar beside them with
-- its stone column, the detail box and the foot box. Also the public inset
-- box maker (ns.SkillInsetBox: the talents window and the windows skin use
-- it too). Every piece is EraUI's own.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local unpack = unpack or table.unpack
local DIALOG_EDGE = "Interface\\DialogFrame\\UI-DialogBox-Border"
local PLUS, MINUS = "Interface\\Buttons\\UI-PlusButton-Up", "Interface\\Buttons\\UI-MinusButton-Up"
Look.FOLD_OPEN, Look.FOLD_SHUT = MINUS, PLUS

-- An inset box: the iron dialog border (edge 16 unless given) over, unless
-- bare, a marble floor (Look.InsetBox, the one copy, at the lifted 1.35).
ns.SkillInsetBox = function(parent, edge, bare)
    return Look.InsetBox(parent, edge, bare)
end

local function Above(frame, base, add)
    frame:SetFrameLevel((Look.Number(base:GetFrameLevel()) or 0) + add)
end

-- Two anchors at once: each { point, relative, relativePoint, x, y }.
local function Span(region, first, second)
    region:ClearAllPoints()
    region:SetPoint(unpack(first))
    region:SetPoint(unpack(second))
end
Look.Span = Span

local function Marble(texture)
    texture:SetVertexColor(1.35, 1.35, 1.35)
    Look.TileArt(texture, "marbleBg")
end
Look.SkillMarble = Marble

-- A piece of the dialog border's strip, cut to one of its 32-wide pieces
-- (left and right of x, every row from 0.0625 to 0.9375), as frame metal.
local function Strip(owner, purpose, cut, sideways)
    local piece = Look.OwnTexture(owner, purpose, "BORDER")
    piece:SetTexture(DIALOG_EDGE)
    if sideways then
        piece:SetTexCoord(cut[1], 0.9375, cut[2], 0.9375, cut[1], 0.0625, cut[2], 0.0625)
    else
        Look.Crop(piece, cut[1], cut[2], 0.0625, 0.9375)
    end
    if ns.ThemeTexture then ns.ThemeTexture(piece, "frameMetal") end
    piece:ClearAllPoints()
    return piece
end

-- The border strip's pieces (x from, x to).
local CUTS = { corner = { 0.5078125, 0.6171875 }, farCorner = { 0.6328125, 0.7421875 }, left = { 0.0078125, 0.1171875 },
    top = { 0.2578125, 0.3671875 }, right = { 0.1328125, 0.2421875 } }

-- The list's tab: 80 x 22 standing on the list box's top-left, drawn from
-- the dialog border, over a marble floor.
local function ListTab(panel, listBox)
    local tab = Look.Build("Frame", panel, nil, { size = { 80, 22 } })
    Look.Pin(tab, "BOTTOMLEFT", listBox, "TOPLEFT", 0, 0)
    Above(tab, listBox, 3)
    local near, far = Strip(tab, "corner", CUTS.corner), Strip(tab, "farCorner", CUTS.farCorner)
    near:SetSize(32, 32)
    far:SetSize(32, 32)
    Look.Pin(near, "TOPLEFT", tab, "TOPLEFT", 0, 0)
    Look.Pin(far, "TOPRIGHT", tab, "TOPRIGHT", 0, 0)
    Span(Strip(tab, "left", CUTS.left), { "TOPLEFT", near, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", listBox, "TOPLEFT", 32, -32 })
    Span(Strip(tab, "top", CUTS.top, true), { "TOPLEFT", near, "TOPRIGHT", 0, 0 }, { "BOTTOMRIGHT", far, "BOTTOMLEFT", 0, 0 })
    Span(Strip(tab, "right", CUTS.right), { "TOPLEFT", far, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, -11 })
    local ground = Look.OwnTexture(tab, "floor", "BACKGROUND")
    Marble(ground)
    Span(ground, { "TOPLEFT", tab, "TOPLEFT", 8, -8 }, { "BOTTOMRIGHT", tab, "BOTTOMRIGHT", -8, -13 })
    return tab
end

-- A stone strip (a frame of its own, the rock tiled on it).
local function Stone(panel, listBox, first, second, across, tall)
    local strip = Look.Build("Frame", panel, nil, { size = { 8, 8 } })
    Above(strip, listBox, 4)
    local rock = Look.OwnTexture(strip, "rock", "ARTWORK")
    Look.TileArt(rock, "rockBg")
    Look.Fill(rock, strip)
    Span(strip, first, second)
    if across then strip:SetHeight(tall) else strip:SetWidth(tall) end
    return strip
end

local function Stones(panel, listBox, tab)
    return {
        Stone(panel, listBox, { "BOTTOMLEFT", tab, "BOTTOMRIGHT", 0, 0 }, { "BOTTOMRIGHT", listBox, "TOPRIGHT", 0, 0 }, true, 8),
        Stone(panel, listBox, { "BOTTOMLEFT", tab, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", tab, "TOPRIGHT", 0, 0 }, true, 8),
        Stone(panel, listBox, { "TOPLEFT", tab, "TOPRIGHT", 0, 0 }, { "BOTTOMLEFT", tab, "BOTTOMRIGHT", 0, -8 }, false, 8),
    }
end

-- The All button: a plus or minus and "All".
local function AllButton(panel, tab)
    local all = Look.Build("Button", panel, nil, { size = { 60, 18 } })
    Look.Pin(all, "TOPLEFT", panel, "TOPLEFT", 17, -68)
    Above(all, tab, 2)
    local sign = Look.OwnTexture(all, "icon", "ARTWORK")
    sign:SetSize(14, 14)
    Look.Pin(sign, "LEFT", all, "LEFT", 0, 0)
    sign:SetTexture(Look.FOLD_OPEN)
    local word = Look.OwnLabel(all, "label", "GameFontNormal", "ARTWORK")
    Look.Pin(word, "LEFT", sign, "RIGHT", 4, 0)
    word:SetText(_G.ALL or "All")
    return all, sign
end

local function Filter(panel)
    local button = Look.Build("Button", panel, nil, { size = { 118, 27 } })
    Look.Pin(button, "TOPRIGHT", panel, "TOPRIGHT", -9, -57)
    Above(button, panel, 12)
    local arrow = Look.DressDropdown(button, 14)
    local word = Look.OwnLabel(button, "label", "GameFontHighlightSmall", "ARTWORK")
    Look.Pin(word, "RIGHT", arrow, "LEFT", 1, 1)
    word:SetText(_G.FILTER or "Filter")
    return button
end

-- The 1.x bar beside the list, its stone column behind it and a marble
-- fill; the wheel over the rows moves it two rows a notch.
local function ScrollBar(panel, listBox, list, onScroll, idle)
    local bar = Look.ClassicScrollBar(panel, listBox, onScroll, idle)
    Span(bar, { "TOPLEFT", listBox, "TOPRIGHT", -9, -27 }, { "BOTTOMLEFT", listBox, "BOTTOMRIGHT", -9, 22 })
    Above(bar, listBox, 6)
    Look.ScrollColumn(bar)
    local fill = Look.OwnTexture(bar, "fill", "BORDER")
    Marble(fill)
    Look.Fill(fill, bar)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, notches)
        bar:SetValue((Look.Number(bar:GetValue()) or 0) - 2 * (Look.Number(notches) or 0))
    end)
    return bar
end

local function Boxes(panel, shell)
    local listBox = shell.listBox
    local detailBox = Look.InsetBox(panel, 32)
    Span(detailBox, { "TOPLEFT", listBox, "BOTTOMLEFT", 0, 12 }, { "BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 33 })
    Above(detailBox, listBox, 2)
    local footBox = Look.InsetBox(panel, 20, true)
    Span(footBox, { "TOPLEFT", detailBox, "BOTTOMLEFT", 0, 7 }, { "BOTTOMRIGHT", panel, "BOTTOMRIGHT", 1, 2 })
    Above(footBox, listBox, 1)
    local detail = Look.Build("Frame", detailBox, nil, { size = { 100, 100 } })
    Look.Fill(detail, detailBox)
    shell.detailBox, shell.footBox, shell.detail = detailBox, footBox, detail
end

-- The shell on a panel. options: rows (8 unless given), makeRow(list, i),
-- onScroll(value), idle (the scroll bar hides while there's nothing to
-- scroll). Returns its pieces.
function Look.SkillShell(panel, options)
    local count = options.rows or 8
    local shell = { rows = {} }
    local listBox = Look.InsetBox(panel, 32)
    listBox:SetHeight(count * 16 + 25)
    Span(listBox, { "TOPLEFT", panel, "TOPLEFT", -2, -75 }, { "RIGHT", panel, "RIGHT", -15, 0 })
    Look.Fade(listBox.TopLeftCorner)
    shell.listBox = listBox
    shell.tab = ListTab(panel, listBox)
    shell.stones = Stones(panel, listBox, shell.tab)
    shell.all, shell.allIcon = AllButton(panel, shell.tab)
    shell.filter = Filter(panel)
    local list = Look.Build("Frame", listBox, nil, { size = { 100, count * 16 } })
    Span(list, { "TOPLEFT", listBox, "TOPLEFT", 17, -17 }, { "BOTTOMRIGHT", listBox, "BOTTOMRIGHT", -14, 10 })
    shell.list = list
    for i = 1, count do
        local row = options.makeRow(list, i)
        row:SetHeight(16)
        Span(row, { "TOPLEFT", list, "TOPLEFT", 0, (1 - i) * 16 }, { "RIGHT", list, "RIGHT", 0, 0 })
        shell.rows[i] = row
    end
    shell.bar = ScrollBar(panel, listBox, list, options.onScroll, options.idle)
    Boxes(panel, shell)
    return shell
end

-- A list row of the old windows: a selection bar, a hover glow, a fold
-- icon and a single line of text (template: nil, or a secure one).
local LISTBOX = "Interface\\Buttons\\UI-Listbox-Highlight2"
function Look.SkillRow(list, template)
    local row = CreateFrame("Button", nil, list, template)
    row:SetSize(100, 16)
    local chosen = Look.OwnTexture(row, "selected", "BACKGROUND")
    chosen:SetTexture(LISTBOX)
    Look.Fill(chosen, row)
    chosen:Hide()
    local glow = Look.OwnTexture(row, "hover", "HIGHLIGHT")
    glow:SetTexture(LISTBOX)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.25)
    Look.Fill(glow, row)
    local sign = Look.OwnTexture(row, "fold", "ARTWORK")
    sign:SetSize(14, 14)
    Look.Pin(sign, "LEFT", row, "LEFT", 3, 0)
    local words = Look.OwnLabel(row, "text", "GameFontNormal", "ARTWORK")
    words:SetJustifyH("LEFT")
    if words.SetWordWrap then words:SetWordWrap(false) end
    return row, { bar = chosen, hover = glow, icon = sign, text = words }
end

-- A row's text from x across its left to 4 in from its right.
function Look.SkillRowText(parts, row, x)
    Span(parts.text, { "LEFT", row, "LEFT", x, 0 }, { "RIGHT", row, "RIGHT", -4, 0 })
end
