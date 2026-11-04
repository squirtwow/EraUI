-- The talent window itself (Classic look, registry "talents"): EraUI's own
-- frame EraUIClassicTalents, built the first time it is opened, never at
-- login. 384 x 512, at the window's own scale:
--   * the old character-sheet shell over the old talent frame's lower half,
--     the round portrait, the title and the red X;
--   * the "Points spent" strip in the skill bar's rim;
--   * the tree view (296 x 332) with the class background, the branch lines
--     under the talents and the arrow heads over them, and the 1.x scroll
--     bar with its stone column;
--   * the stone foot: the undo button, the points box, Apply Changes;
--   * the three tree tabs under it.
-- Every piece is EraUI's own; what the window keeps lives on Look.Talent.
local _, EraUI = ...
local Look = EraUI.Look
local T = Look.Talent
local parts = T.parts

---------------------------------------------------------------------------
-- The shell, portrait, title and X
---------------------------------------------------------------------------

-- Art key, width, the corner it hangs from.
local SHELL = {
    { "charGeneralTopLeft", 256, "TOPLEFT" }, { "charGeneralTopRight", 128, "TOPRIGHT" },
    { "talentSheetLeft", 256, "BOTTOMLEFT" }, { "talentSheetRight", 128, "BOTTOMRIGHT" },
}

local function Shell(window)
    for index, piece in ipairs(SHELL) do
        local sheet = Look.OwnTexture(window, "shell" .. index, "BORDER")
        Look.Art(sheet, piece[1])
        Look.Crop(sheet, 0, 1, 0, 1)
        sheet:SetSize(piece[2], 256)
        Look.Pin(sheet, piece[3], window, piece[3], 0, 0)
    end
    parts.portrait = Look.OwnTexture(window, "portrait", "BACKGROUND")
    parts.portrait:SetSize(60, 60)
    Look.Pin(parts.portrait, "TOPLEFT", window, "TOPLEFT", 7, -6)
    parts.title = Look.OwnLabel(window, "title", "GameFontNormal", "ARTWORK")
    Look.Pin(parts.title, "CENTER", window, "CENTER", 6, 232)
    parts.title:SetText(T.Say("TALENTS", "Talents"))
    local shut = Look.Build("Button", window, nil, { size = { 32, 32 } })
    Look.Pin(shut, "CENTER", window, "TOPRIGHT", -46, -24)
    Look.SkinCloseButton(shut)
    shut:SetScript("OnClick", function() window:Hide() end)
    parts.close = shut
end

---------------------------------------------------------------------------
-- The points-spent strip: a thin black bar in the skill bar's rim
---------------------------------------------------------------------------

-- Each rim piece: its share of the sheet's width (out of 256).
local RIM = { left = { 0, 14 }, middle = { 14, 242 }, right = { 242, 256 } }

local function Strip(window)
    local strip = Look.Build("Frame", window, nil, { size = { 258, 13 } })
    Look.Pin(strip, "TOP", window, "TOP", 12, -48)
    local shade = Look.OwnTexture(strip, "shade", "BACKGROUND")
    shade:SetColorTexture(0, 0, 0, 0.6)
    Look.Inside(shade, strip, 1, 0, 1, 0)
    local rim = {}
    for side, cut in pairs(RIM) do
        rim[side] = Look.OwnTexture(strip, "rim" .. side, "ARTWORK")
        Look.Art(rim[side], "skillsBarBorder")
        Look.Crop(rim[side], cut[1] / 256, cut[2] / 256, 0, 1)
        rim[side]:ClearAllPoints()
    end
    for side, sign in pairs({ LEFT = -1, RIGHT = 1 }) do
        local cap = rim[side:lower()]
        cap:SetWidth(14)
        cap:SetPoint("TOP" .. side, strip, "TOP" .. side, 5 * sign, 5)
        cap:SetPoint("BOTTOM" .. side, strip, "BOTTOM" .. side, 5 * sign, -5)
    end
    rim.middle:SetPoint("TOPLEFT", rim.left, "TOPRIGHT")
    rim.middle:SetPoint("BOTTOMRIGHT", rim.right, "BOTTOMLEFT")
    parts.spent = Look.OwnLabel(strip, "spent", "GameFontNormalSmall", "OVERLAY")
    Look.Pin(parts.spent, "CENTER", strip, "CENTER", 0, 0)
    parts.strip = strip
end

---------------------------------------------------------------------------
-- The tree view
---------------------------------------------------------------------------

local CORNERS = { "TopLeft", "TopRight", "BottomLeft", "BottomRight" }

local function View(window)
    local width, height = T.VIEW_W, T.VIEW_H
    local view = Look.Build("ScrollFrame", window, nil, { size = { width, height }, wheel = true })
    view:SetPoint("TOPLEFT", window, "TOPLEFT", 22, -77)
    view:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", 22 + width, -77 - height)
    local child = Look.Build("Frame", view, nil, { size = { width, height } })
    view:SetScrollChild(child)
    -- The class background: four pieces from the child's top-left.
    local back = {}
    for _, corner in ipairs(CORNERS) do back[corner] = Look.OwnTexture(child, "back" .. corner, "BACKGROUND") end
    Look.Pin(back.TopLeft, "TOPLEFT", child, "TOPLEFT", 0, 0)
    Look.Pin(back.TopRight, "TOPLEFT", back.TopLeft, "TOPRIGHT", 0, 0)
    Look.Pin(back.BottomLeft, "TOPLEFT", back.TopLeft, "BOTTOMLEFT", 0, 0)
    Look.Pin(back.BottomRight, "TOPLEFT", back.TopLeft, "BOTTOMRIGHT", 0, 0)
    -- Arrow heads draw over the talents' sockets: a layer five levels up.
    local heads = Look.Build("Frame", child, nil, { size = { width, height } })
    heads:SetAllPoints(child)
    heads:SetFrameLevel((Look.Number(child:GetFrameLevel()) or 1) + 5)
    local bar = Look.ClassicScrollBar(window, view, function(value) view:SetVerticalScroll(value) end)
    Look.ScrollColumn(bar)
    view:SetScript("OnMouseWheel", function(_, notches)
        bar:SetValue((Look.Number(bar:GetValue()) or 0) - (Look.Number(notches) or 0) * 30)
    end)
    parts.view, parts.child, parts.back, parts.heads, parts.bar = view, child, back, heads, bar
end

---------------------------------------------------------------------------
-- The stone foot: undo, the points box, Apply Changes
---------------------------------------------------------------------------

local UNDO_ATLAS, UNDO_FILE = "talents-button-undo", "Interface/Buttons/UI-RotationLeft-Button-Up"

local function AtlasOf(texture)
    local fine, named = pcall(texture.GetAtlas, texture)
    if fine and not Look.Secret(named) and type(named) == "string" and named ~= "" then return named end
    return nil
end

-- The undo arrow: the game's atlas, or the old rotate arrow should this
-- client not have it.
local function UndoMark(button)
    local mark = Look.OwnTexture(button, "undo", "OVERLAY")
    local fine, took = pcall(mark.SetAtlas, mark, UNDO_ATLAS)
    if not (fine and took ~= false and AtlasOf(mark)) then mark:SetTexture(UNDO_FILE) end
    mark:SetSize(13, 13)
    Look.Pin(mark, "CENTER", button, "CENTER", 0, 0)
    return mark
end

local function UndoTip(button)
    Look.ShowTip(button, "RIGHT", { { T.Say("TALENT_FRAME_RESET_BUTTON_TOOLTIP_TITLE", "Reset Pending Changes"), 1, 1, 1 } })
end

local function Foot(window)
    local foot = Look.Build("Frame", window, nil, { size = { 338, 26 } })
    foot:SetPoint("TOPLEFT", window, "TOPLEFT", 14, -409)
    foot:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", 352, -435)
    local stone = Look.OwnTexture(foot, "stone", "BACKGROUND")
    Look.TileArt(stone, "rockBg")
    Look.Fill(stone, foot)
    local above = (Look.Number(foot:GetFrameLevel()) or 1) + 1

    local undo = Look.PanelButton(window, "", 28)
    Look.Pin(undo, "TOPLEFT", window, "TOPLEFT", 16, -411)
    undo:SetFrameLevel(above)
    parts.undoMark = UndoMark(undo)
    if undo.SetMotionScriptsWhileDisabled then undo:SetMotionScriptsWhileDisabled(true) end
    undo:SetScript("OnEnter", UndoTip)
    undo:SetScript("OnLeave", Look.HideTip)
    undo:SetScript("OnClick", function() T.ResetStaged() end)

    local box = Look.InsetBox(window, 16, true)
    box:SetSize(196, 24)
    Look.Pin(box, "LEFT", undo, "RIGHT", 3, 0)
    box:SetFrameLevel(above)
    local well = Look.OwnTexture(box, "well", "BACKGROUND")
    well:SetColorTexture(0, 0, 0, 0.55)
    Look.Inside(well, box, 4, 4, 4, 4)
    parts.points = Look.OwnLabel(box, "points", "GameFontNormalSmall", "ARTWORK")
    Look.Pin(parts.points, "RIGHT", box, "RIGHT", -10, 0)

    local apply = Look.PanelButton(window, "Apply Changes", 104)
    Look.Pin(apply, "LEFT", box, "RIGHT", 3, 0)
    apply:SetFrameLevel(above)
    apply:SetScript("OnClick", function() T.ApplyStaged() end)
    parts.foot, parts.undo, parts.box, parts.apply = foot, undo, box, apply
end

---------------------------------------------------------------------------
-- The tree tabs
---------------------------------------------------------------------------

-- The raised (selected) and lowered looks: art key, height, how far down
-- from the tab's top, the share of the sheet's height used.
local TAB_LOOKS = {
    raised = { "tabActive", 35, 0, 0.546875 },
    lowered = { "tabInactive", 32, -4, 1 },
}
local TAB_CUTS = { { 0, 0.15625 }, { 0.15625, 0.84375 }, { 0.84375, 1 } }
local tabParts = Look.Weak() -- tab: { raised = {}, lowered = {}, label, words }

local function TabArt(tab, look, name)
    local set = {}
    for index, cut in ipairs(TAB_CUTS) do
        set[index] = Look.OwnTexture(tab, name .. index, "BACKGROUND")
        Look.Art(set[index], look[1])
        Look.Crop(set[index], cut[1], cut[2], 0, look[4])
        set[index]:SetHeight(look[2])
    end
    set[1]:SetWidth(20)
    Look.Pin(set[1], "TOPLEFT", tab, "TOPLEFT", 0, look[3])
    set[3]:SetWidth(20)
    Look.Pin(set[3], "TOPRIGHT", tab, "TOPRIGHT", 0, look[3])
    set[2]:ClearAllPoints()
    set[2]:SetPoint("TOPLEFT", set[1], "TOPRIGHT")
    set[2]:SetPoint("TOPRIGHT", set[3], "TOPLEFT")
    return set
end

local function MakeTab(window, index, previous)
    local tab = Look.Build("Button", window, nil, { size = { 80, 32 } })
    if previous then
        Look.Pin(tab, "TOPLEFT", previous, "TOPRIGHT", -15, 0)
    else
        Look.Pin(tab, "TOPLEFT", window, "BOTTOMLEFT", 15, 78)
    end
    local own = { raised = TabArt(tab, TAB_LOOKS.raised, "raised"), lowered = TabArt(tab, TAB_LOOKS.lowered, "lowered") }
    own.label = Look.OwnLabel(tab, "label", "GameFontNormalSmall", "ARTWORK")
    local glow = Look.StateArt(tab, "Highlight", "tabHighlight")
    if glow then
        Look.Crop(glow, 0, 1, 0, 1)
        glow:ClearAllPoints()
        glow:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, 5)
        glow:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 0)
        glow:SetBlendMode("ADD")
    end
    tab:SetScript("OnClick", function() T.SelectTab(index) end)
    tabParts[tab] = own
    return tab
end

local function Tabs(window)
    parts.tabs = {}
    for index = 1, 3 do parts.tabs[index] = MakeTab(window, index, parts.tabs[index - 1]) end
end

-- A tab's words; its width (the words plus 40) follows only when they change.
function T.NameTab(tab, words)
    local own = tabParts[tab]
    if not own or own.words == words then return end
    own.words = words
    own.label:SetText(words)
    tab:SetWidth(math.ceil(Look.Number(own.label:GetStringWidth()) or 40) + 40)
end

-- Raised with white words 5 below its middle, or lowered with gold words 3
-- below.
function T.RaiseTab(tab, raised)
    local own = tabParts[tab]
    if not own then return end
    for _, piece in ipairs(own.raised) do Look.Shown(piece, raised) end
    for _, piece in ipairs(own.lowered) do Look.Shown(piece, not raised) end
    local colour = raised and T.WHITE or T.GOLD
    own.label:SetTextColor(colour[1], colour[2], colour[3])
    Look.Pin(own.label, "CENTER", tab, "CENTER", 0, raised and -5 or -3)
end

---------------------------------------------------------------------------
-- Building it (once)
---------------------------------------------------------------------------

function T.Build()
    if T.window then return T.window end
    local window = Look.Build("Frame", UIParent, nil, { name = "EraUIClassicTalents", size = { T.WIDTH, T.HEIGHT },
        strata = "MEDIUM", mouse = true, hidden = true })
    window:SetToplevel(true)
    Look.Pin(window, "TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    T.window = window
    for _, step in ipairs({ Shell, Strip, View, Foot, Tabs }) do Look.Try(step, window) end
    if T.Wire then Look.Try(T.Wire, window) end
    return window
end
