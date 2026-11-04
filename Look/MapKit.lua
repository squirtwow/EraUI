-- The minimap look's kit (registry entry "minimap", from /era's Minimap):
-- its state, its 1.x art, and the few careful moves it makes on the game's
-- minimap cluster, an Edit Mode frame.
--
-- The area's files, in .toc order:
--   MapKit      this file
--   MapRing     the frame's size and mask, the stone ring, the compass, the
--               zone name, the pieces put aside, other addons' buttons
--   MapControls the buttons round the ring (zoom, tracking, mail, calendar,
--               day and night, clock, the event link)
--   MapEye      the queue eye, its watcher and the "Default Size" button
--   MapSquare   Square Minimap and Square Size, and what /era calls live
--   MapModule   one layout in order, the hooks, turning the look on and off
-- (Map fade, the "mapFade" entry, is Look/MapFadeSwitch.lua.)
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local Map = {
    applied = false, -- the look is on: applied this session, not restored since
    worn = false,    -- Square Minimap is worn right now
    size = 1,        -- the Square Size factor in use while it is worn
}
Look.Map = Map

Map.WHITE = "Interface\\Buttons\\WHITE8X8"
-- The hybrid map's own round mask file (Blizzard's XML sets it so).
Map.ROUND_FILE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
Map.CLAMP = "CLAMPTOBLACKADDITIVE"

-- The registry key's default, only where the engine has none of its own.
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine and engine.minimap == nil then engine.minimap = true end
end

---------------------------------------------------------------------------
-- Art (the last name is Dark Mode's key: Core/Appearance.lua greys those)
---------------------------------------------------------------------------

do
    local FOLDER = "Interface\\Minimap\\"
    local function MapArt(key, file, theme, bundledFirst, bundledName)
        Look.DefineArt(key, FOLDER .. file, bundledName or file, theme, bundledFirst)
    end
    MapArt("mapBorder", "UI-Minimap-Border", "minimapBorder")
    MapArt("mapTrackBack", "UI-Minimap-Background", "minimapBackground")
    MapArt("mapGoldRing", "MiniMap-TrackingBorder", "trackingBorder")
    MapArt("mapCompass", "CompassRing", "compassRing")
    MapArt("mapNorth", "CompassNorthTag")
    MapArt("mapZoomGlow", "UI-Minimap-ZoomButton-Highlight")
    -- The client's file under this name isn't the magnifying glass any more:
    -- EraUI's copy comes first.
    MapArt("mapGlass", "Tracking\\None", nil, true, "Tracking-None")
    for _, way in ipairs({ "In", "Out" }) do
        for _, look in ipairs({ "Up", "Down", "Disabled" }) do
            local file = "UI-Minimap-Zoom" .. way .. "Button-" .. look
            MapArt("zoom" .. way .. look, file, "zoom" .. way .. look)
        end
    end
    Look.DefineArt("mapCalendar", "Interface\\Calendar\\UI-Calendar-Button", "UI-Calendar-Button")
    Look.DefineArt("mapClock", "Interface\\TimeManager\\ClockBackground", "ClockBackground", "clockBackground")
end

-- The round mask's file through the art lookup (no tint: it's a mask).
function Map.RoundMask()
    return Look.FirstPath("portraitMask") or Map.ROUND_FILE
end

---------------------------------------------------------------------------
-- Reads
---------------------------------------------------------------------------

-- Edit Mode's Minimap Size as a factor; 1 when it can't be read or is 0.
function Map.EditSize(cluster)
    local sizes = Enum and Enum.EditModeMinimapSetting
    local percent = sizes and Look.EditSetting(cluster, sizes.Size)
    if not percent or percent <= 0 then return 1 end
    return percent / 100
end

-- The game's "Rotate Minimap" setting.
function Map.Rotating()
    local read = C_CVar and C_CVar.GetCVarBool
    if type(read) ~= "function" then return false end
    local fine, on = pcall(read, "rotateMinimap")
    return fine and not Look.Secret(on) and on == true
end

-- The frame level a control sits at: five over the map's own.
function Map.Above(map)
    return (Look.Number(map:GetFrameLevel()) or 0) + 5
end

---------------------------------------------------------------------------
-- The engine
---------------------------------------------------------------------------

-- Asks EraUI's pass for the end of the fight (in a fight the engine only
-- notes that one is wanted).
function Map.Book()
    if type(ns.ApplyAll) == "function" then Look.Try(ns.ApplyAll) end
end

-- EraUI's own minimap button and the drawer's place themselves again (on
-- the ring or round the square; Modules/MinimapTools.lua).
function Map.TellTools()
    local tools = EraUI.modules and EraUI.modules.MinimapTools
    if type(tools) ~= "table" then return end
    if type(tools.Position) == "function" then Look.Try(tools.Position, tools) end
    if type(tools.PlaceDrawerButton) == "function" then Look.Try(tools.PlaceDrawerButton, tools) end
end

---------------------------------------------------------------------------
-- The cluster's scale (an Edit Mode frame)
---------------------------------------------------------------------------

-- Edit Mode's own SetScale, SetPoint and ClearAllPoints write snap records;
-- run from EraUI's code they would carry its taint into the game's moves in
-- a fight. So the scale goes on through the plain SetScaleBase, and every
-- anchor is put back through SetPointBase with its offsets times old / new:
-- the anchored corner stays where Edit Mode put it, any snap included, as
-- Edit Mode's own SetScale would leave it. Never in a fight: EraUI's pass
-- after it is booked instead.
function Map.SetClusterScale(cluster, wanted)
    local before = Look.Number(cluster:GetScale())
    if before and math.abs(before - wanted) <= 0.001 then return end
    if Look.InFight() then
        Map.Book()
        return
    end
    local plainBase = cluster.SetScaleBase
    if type(plainBase) ~= "function" then
        -- Not an Edit Mode frame on this client: its own SetScale is plain.
        local own = cluster.SetScale
        own(cluster, wanted)
        return
    end
    local anchors = {}
    for i = 1, (Look.Number(cluster:GetNumPoints()) or 0) do anchors[i] = { cluster:GetPoint(i) } end
    plainBase(cluster, wanted)
    if not before or before <= 0 then return end
    local keep = before / wanted
    for _, anchor in ipairs(anchors) do
        Look.AddPoint(cluster, anchor[1], anchor[2], anchor[3], (anchor[4] or 0) * keep, (anchor[5] or 0) * keep)
    end
end

---------------------------------------------------------------------------
-- Forever's header buttons (the zone bar, tracking, the calendar)
---------------------------------------------------------------------------

-- Each draws its art in a StateTexture, whose atlas the game sets again on
-- every hover and click (its alpha it leaves), and glows through an
-- additive AddTexture, whose alpha and shown state it sets each time (its
-- art it never sets). So: the art faded, the glow left with no art. The
-- glow's atlas is noted the first time, in EraUI's own table, for the zone
-- bar's return.
local glowAtlas = Look.Weak() -- an AddTexture: its atlas, or false

function Map.QuietHeader(header)
    if header == nil then return end
    Look.Fade(header.StateTexture)
    local shine = header.AddTexture
    if shine == nil then return end
    if glowAtlas[shine] == nil then
        local fine, named = Look.Ask(shine, "GetAtlas")
        glowAtlas[shine] = (fine and type(named) == "string" and not Look.Secret(named)) and named or false
    end
    shine:SetTexture(nil)
end

-- The header art back (the zone bar, when Minimap is turned off).
function Map.LoudHeader(header)
    if header == nil then return end
    Look.Alpha(header.StateTexture, 1)
    local shine = header.AddTexture
    if shine == nil then return end
    local named = glowAtlas[shine]
    glowAtlas[shine] = nil
    if named then shine:SetAtlas(named, true) end
end
