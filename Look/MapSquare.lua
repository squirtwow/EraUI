-- Square Minimap (Map & Minimap, off by default) and its Square Size: the
-- map square in a thin near-black frame of EraUI's own with a fine line
-- just round it (muted bronze, or the Darkness grey in Dark Mode), the zone
-- name on the frame's deeper top strip, the zoom buttons and the eye on the
-- square's edges, other addons told the map is square. Worn only while the
-- minimap look is applied. Switched live from /era, never in a fight.
--
-- Also what other files call: SquareMinimapOn (MinimapTools),
-- RefreshSquareMinimap (/era's tick and slider) and RefreshSquareMinimapLine
-- (the Darkness slider).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Map = Look.Map

local BRONZE = { 0.55, 0.46, 0.27 }
-- Left, bottom, right, top in map units from the map's centre (the map
-- spans -70 to 70). The edge: 4 wide, the top 22 deep for the zone name.
-- The line: 1 wide, 1 to 2 out from the map, square at the corners. Each
-- set tiles its band with no gap and no overlap.
local EDGE = { { -74, 70, 74, 92 }, { -74, -74, 74, -70 }, { -74, -70, -70, 70 }, { 70, -70, 74, 70 } }
local LINE = { { -72, 71, 72, 72 }, { -72, -72, 72, -71 }, { -72, -71, -71, 71 }, { 71, -71, 72, 71 } }

local frame = { edge = {}, line = {} } -- EraUI's eight strips, once made
local tone -- the line's colour as last set ("r g b")
local squaredMask -- the hybrid map's mask EraUI made square

---------------------------------------------------------------------------
-- Wanted and size
---------------------------------------------------------------------------

function Map.SquareWanted()
    return Map.applied and Look.Enabled() and Look.Setting("squareMinimap") == true
end

-- Square Size as a factor: the saved percent (unreadable gives 100),
-- clamped to 75 to 150.
function Map.SquareSize()
    local percent = tonumber(Look.Setting("squareMinimapScale"))
    if not percent or percent ~= percent or percent == math.huge or percent == -math.huge then percent = 100 end
    return Look.Clamp(percent, 75, 150) / 100
end

---------------------------------------------------------------------------
-- EraUI's frame round the map
---------------------------------------------------------------------------

-- Drawn on the cluster itself, so the zone name and every button (the
-- cluster's children) draw over them; each pinned by two corners to the
-- map.
local function Strips(cluster, map, boxes, layer, into)
    for i, box in ipairs(boxes) do
        local strip = cluster:CreateTexture(nil, layer)
        strip:SetPoint("TOPLEFT", map, "CENTER", box[1], box[4])
        strip:SetPoint("BOTTOMRIGHT", map, "CENTER", box[3], box[2])
        into[i] = strip
    end
end

local function LineTone()
    if Look.Setting("darkMode") and type(ns.DarkGrey) == "function" then return ns.DarkGrey() end
    return BRONZE[1], BRONZE[2], BRONZE[3]
end

local function PaintLine()
    local r, g, b = LineTone()
    local now = string.format("%.4f %.4f %.4f", r, g, b)
    if now == tone then return end
    tone = now
    for _, strip in ipairs(frame.line) do strip:SetColorTexture(r, g, b, 1) end
end

local function ShowStrips(shown)
    for _, set in ipairs({ frame.edge, frame.line }) do
        for _, strip in ipairs(set) do Look.Shown(strip, shown) end
    end
end

---------------------------------------------------------------------------
-- The hybrid map's mask and the shape other addons read
---------------------------------------------------------------------------

-- Where the game uses its hybrid map (loaded only where it's used), its own
-- round mask goes square too, and back to the game's own file after.
local function HybridMask()
    local hybrid = rawget(_G, "HybridMinimap")
    local mask = type(hybrid) == "table" and hybrid.CircleMask or nil
    if Map.worn then
        if mask and mask ~= squaredMask and type(mask.SetTexture) == "function" then
            mask:SetTexture(Map.WHITE, Map.CLAMP, Map.CLAMP)
            squaredMask = mask
        end
    elseif squaredMask then
        squaredMask:SetTexture(Map.ROUND_FILE, Map.CLAMP, Map.CLAMP)
        squaredMask = nil
    end
end

-- Minimap button libraries read a global GetMinimapShape (an addon
-- convention). EraUI answers only while the square is worn and no other
-- addon has answered first, and takes its answer back only while it's
-- still its own: another addon's is never replaced or removed.
local function AnswerSquare()
    return "SQUARE"
end

local function ShapeForOthers()
    local present = rawget(_G, "GetMinimapShape")
    if Map.worn and present == nil then
        rawset(_G, "GetMinimapShape", AnswerSquare)
    elseif not Map.worn and present == AnswerSquare then
        rawset(_G, "GetMinimapShape", nil)
    end
end

---------------------------------------------------------------------------
-- Each layout, and taking it off
---------------------------------------------------------------------------

-- The frame shown (made the first time; worn only ever starts out of a
-- fight) and toned, or hidden; the hybrid mask; the shape.
function Map.DressSquare(cluster, map)
    if Map.worn then
        if not frame.edge[1] then
            Strips(cluster, map, EDGE, "BACKGROUND", frame.edge)
            for _, strip in ipairs(frame.edge) do strip:SetColorTexture(0.05, 0.05, 0.06, 1) end
            Strips(cluster, map, LINE, "BORDER", frame.line)
        end
        PaintLine()
    end
    ShowStrips(Map.worn)
    HybridMask()
    ShapeForOthers()
end

-- The square off while Minimap itself is turned off: the round mask, the
-- cluster back to Edit Mode's size alone, the hybrid mask and the shape
-- given back. (Map.worn is already false.)
function Map.TakeOffSquare()
    ShowStrips(false)
    if Minimap then Minimap:SetMaskTexture(Map.RoundMask()) end
    if MinimapCluster then Map.SetClusterScale(MinimapCluster, Map.EditSize(MinimapCluster)) end
    HybridMask()
    ShapeForOthers()
end

---------------------------------------------------------------------------
-- The rotation watch
---------------------------------------------------------------------------

-- Forever's own minimap code puts its round mask back whenever the map's
-- rotation changes. Edit Mode's tick goes through SetRotateMinimap (hooked
-- in MapModule); the game's Options change the setting directly, so EraUI
-- listens for it and lays the square out again a frame later, after the
-- game's own change.
local rotationWatch

local function RotationChanged(_, _, name)
    if not Map.worn or type(name) ~= "string" or Look.Secret(name) or name:lower() ~= "rotateminimap" then return end
    C_Timer.After(0, function()
        if Map.applied and Map.worn then Map.Layout() end
    end)
end

function Map.WatchRotation()
    if rotationWatch then return end
    rotationWatch = CreateFrame("Frame")
    Look.Listen(rotationWatch, "CVAR_UPDATE")
    rotationWatch:SetScript("OnEvent", RotationChanged)
end

---------------------------------------------------------------------------
-- What other files call
---------------------------------------------------------------------------

-- Worn right now (not merely wanted): false with the look off or not yet
-- applied.
function ns.SquareMinimapOn()
    return Map.worn == true
end

-- /era's Square Minimap tick and Square Size slider. True when done (or
-- nothing needed doing), false when it waits for the fight to end.
function ns.RefreshSquareMinimap()
    local wear, size = Map.SquareWanted(), Map.SquareSize()
    if wear == Map.worn and (not wear or size == Map.size) then return true end
    if Look.InFight() then
        Map.Book()
        return false
    end
    local switched = wear ~= Map.worn
    Map.worn, Map.size = wear, size
    Map.Layout()
    if switched then Map.TellTools() end
    return true
end

-- The Darkness slider (Core/Appearance.lua): the line follows it in Dark
-- Mode. EraUI's own textures only, so a fight doesn't matter.
function ns.RefreshSquareMinimapLine()
    if Map.worn then PaintLine() end
end
