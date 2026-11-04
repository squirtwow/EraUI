-- The Legacy Tree's links in the 1.x look (registry "legacyWindow"): each
-- of the game's arrows between two talents redrawn from the old talent
-- window's branch and arrow sheets, lit once the link is active. A link
-- along a row is a branch and an arrow head at the next talent's side; a
-- link down a column a branch and a head at its top; a link down and across
-- a branch along the row, one down the column and the head (as the old
-- trees drew them). Pieces scale with the gap they cross. The branches sit
-- on a layer of EraUI's under the talents, the heads on one over them;
-- neither takes the mouse. The game's own line and head are faded; a link
-- EraUI can't place (a talent placed some other way, a link up the tree)
-- keeps the game's own art. The game loads the whole tree again each time
-- the page shows, handing its links new pairs of talents: in a fight a link
-- whose art EraUI took over before is drawn again (EraUI's own pieces
-- only), any other keeps the game's art until the fight ends.
local _, EraUI = ...
local Look = EraUI.Look
local L = Look.Legacy

local edges = L.Record(Look.Weak()) -- one of the game's links: { slot, drawn, plain }
local layers = Look.Weak() -- a tree panel: { holder, branches, heads }
local GAME_ART = { "Line", "ArrowHead", "GhostLine", "GhostArrowHead" }
local slots = 0

-- EraUI's two layers on the panel's button holder (made once).
local function Layers(panel)
    local holder = L.Field(panel, "ButtonsParent")
    if not holder then return nil end
    local own = layers[panel]
    if not own then
        local base = Look.Number(holder:GetFrameLevel()) or 0
        own = { holder = holder, branches = L.Frame(holder, 8, 8), heads = L.Frame(holder, 8, 8) }
        own.branches:SetAllPoints(holder)
        own.branches:SetFrameLevel(base + 50)
        own.heads:SetAllPoints(holder)
        own.heads:SetFrameLevel(base + 150)
        layers[panel] = own
    end
    Look.Shown(own.branches, true)
    Look.Shown(own.heads, true)
    return own
end

---------------------------------------------------------------------------
-- Where the pieces go
---------------------------------------------------------------------------

-- A talent's middle on the holder (as the game places it), or nil.
local function Middle(button, holder)
    local point, relative, relativePoint, x, y = button:GetPoint(1)
    x, y = Look.Number(x), Look.Number(y)
    if point ~= "CENTER" or relative ~= holder or relativePoint ~= "TOPLEFT" or not x or not y then return nil end
    return x, y
end

local function Half(button)
    local icon = L.Field(button, "Icon")
    local across = icon and Look.Number(icon:GetWidth()) or Look.Number(button:GetWidth())
    return (across or 40) / 2
end

-- The old pieces were drawn for a 26 gap; here they follow the gap.
local function Scale(gap)
    return math.max(0.6, math.min(1.2, gap / 26))
end

-- The pieces of one link, each { kind, left, top, width, height } on the
-- holder (y up), or nil for a link EraUI doesn't draw.
function L.LinkPlan(holder, start, finish)
    local sx, sy = Middle(start, holder)
    local ex, ey = Middle(finish, holder)
    if not (sx and ex) then return nil end
    local hs, he = Half(start), Half(finish)
    local pieces = {}
    local function Put(kind, left, top, wide, tall)
        if wide >= 1 and tall >= 1 then pieces[#pieces + 1] = { kind, left, top, wide, tall } end
    end
    if math.abs(ey - sy) < 2 then
        if math.abs(ex - sx) < 2 then return nil end
        local right = ex > sx
        local k = Scale(math.abs(ex - sx) - hs - he)
        local from = right and (sx + hs - 2 * k) or (ex + he - 2 * k)
        local to = right and (ex - he + 2 * k) or (sx - hs + 2 * k)
        Put("across", from, sy + 16 * k, to - from, 32 * k)
        local headX = right and (ex - he - 4 * k) or (ex + he + 4 * k)
        Put(right and "headRight" or "headLeft", headX - 16 * k, ey + 16 * k, 32 * k, 32 * k)
        return pieces
    end
    if ey > sy then return nil end
    local k = Scale((sy - ey) - hs - he)
    if math.abs(ex - sx) < 2 then
        local top, bottom = sy - hs + 2 * k, ey + he - 2 * k
        Put("down", ex - 16 * k, top, 32 * k, top - bottom)
    else
        local right = ex > sx
        local from = right and (sx + hs - 2 * k) or (ex - 16 * k)
        local to = right and (ex + 16 * k) or (sx - hs + 2 * k)
        Put("across", from, sy + 16 * k, to - from, 32 * k)
        local bottom = ey + he + 2 * k
        Put("down", ex - 16 * k, sy, 32 * k, sy - bottom)
    end
    Put("headDown", ex - 16 * k, ey + he + 20 * k, 32 * k, 32 * k)
    return pieces
end

---------------------------------------------------------------------------
-- Drawing them
---------------------------------------------------------------------------

local PIECES = { "a", "b", "head" }

local function Piece(layer, own, name)
    local head = name == "head"
    return L.Own(head and layer.heads or layer.branches, "link" .. own.slot .. name, "ARTWORK", 0, true)
end

local function HidePieces(layer, own)
    own.drawn = false
    if not layer then return end
    for _, name in ipairs(PIECES) do
        local piece = Look.OwnPiece(name == "head" and layer.heads or layer.branches, "legacy.link" .. own.slot .. name)
        if piece then piece:Hide() end
    end
end

local function GameArt(edge, faded)
    for _, key in ipairs(GAME_ART) do
        local piece = L.Field(edge, key)
        if faded then L.Fade(piece) else L.Unfade(piece) end
    end
end

-- The game's own line and head already faded (a link of the game's EraUI
-- drew before, handed a new pair of talents).
local function Faded(edge)
    for _, key in ipairs(GAME_ART) do
        local piece = L.Field(edge, key)
        if piece and L.was.alpha[piece] == nil then return false end
    end
    return true
end

-- In a fight only EraUI's own pieces change: a link whose own art still
-- shows keeps it, and one EraUI can't draw waits, until the fight ends
-- (the dressing booked for then draws both).
local function Draw(panel, edge)
    local own = edges[edge]
    if not own then return end
    local fight = Look.InFight()
    if fight and not Faded(edge) then
        -- The game's art shows until the fight ends; drawn then.
        HidePieces(layers[panel], own)
        own.plain = false
        return
    end
    local layer = Layers(panel)
    if not layer then return end
    local start, finish = L.Field(edge, "startButton"), L.Field(edge, "endButton")
    local plan = start and finish and L.LinkPlan(layer.holder, start, finish)
    HidePieces(layer, own)
    own.plain = false
    if not plan then
        if fight then return end
        own.plain = true
        GameArt(edge, false)
        return
    end
    if not fight then GameArt(edge, true) end
    local info = L.Field(edge, "edgeInfo")
    local lit = type(info) == "table" and L.Field(info, "isActive") == true
    local art = Look.Talent and Look.Talent.LINK_ART or {}
    local branch = 0
    for _, step in ipairs(plan) do
        local shape = art[step[1]]
        if shape then
            local name = "head"
            if not shape.head then
                branch = branch + 1
                name = PIECES[branch]
            end
            local piece = Piece(layer, own, name)
            Look.Art(piece, shape.head and "legacyArrows" or "legacyBranches")
            local crop = lit and shape[1] or shape[2]
            Look.Crop(piece, crop[1], crop[2], crop[3], crop[4])
            piece:SetSize(step[4], step[5])
            Look.Pin(piece, "TOPLEFT", layer.holder, "TOPLEFT", step[2], step[3])
            piece:Show()
            own.drawn = true
        end
    end
end
L.DrawLink = Draw

local function DressEdge(panel, edge)
    slots = slots + 1
    local own = { slot = slots, drawn = false, plain = false }
    edges[edge] = own
    local function Again(self) Draw(panel, self) end
    -- Also in a fight: Draw leaves the game's art alone then.
    L.AfterOwn(edge, "UpdatePosition", Again)
    L.AfterOwn(edge, "UpdateState", Again)
    L.AfterOwnScript(edge, "OnShow", Again)
    -- A link the game lets go of (its holder still showing) takes its
    -- pieces with it (EraUI's own, so in a fight too); its own art stays
    -- faded for the next pair of talents the game hands it. A link hidden
    -- with its page or the window keeps its pieces: they hide and show with
    -- the holder.
    Look.HookScript(edge, "OnHide", function(self)
        local now = edges[self]
        local layer = layers[panel]
        if not now or (layer and not layer.holder:IsVisible()) then return end
        HidePieces(layer, now)
    end, "legacy.hide")
end

-- Every link shown: new ones dressed and drawn; the others drawn again when
-- asked (the talents moved) or when shown without their pieces.
function L.Edges(panel, again)
    local pool = L.Field(panel, "edgePool")
    if not pool then return end
    L.EachActive(pool, function(edge)
        if type(edge) ~= "table" then return end
        local own = edges[edge]
        if not own then
            DressEdge(panel, edge)
            Draw(panel, edge)
        elseif again or (not own.drawn and not own.plain and L.IsShown(edge)) then
            Draw(panel, edge)
        end
    end)
end

-- After the game set one talent's links up: the new ones dressed.
function L.EdgesOf(panel)
    L.Edges(panel, false)
end
