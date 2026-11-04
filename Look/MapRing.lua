-- The round 1.x minimap: the cluster's frame (its scale, sizes and the map's
-- mask), the stone ring and its top bar, the north tag or the rotating
-- compass, the zone name in the classic font, Forever's pieces put aside,
-- and other addons' minimap buttons told to place themselves.
--
-- Places are in map units (pixels at the cluster's own scale) from the
-- map's centre. Edit Mode's Minimap Size goes on the cluster rather than
-- the game's container, so all of it scales together and every place stays
-- the same at any size.
local _, EraUI = ...
local Look = EraUI.Look
local Map = Look.Map

---------------------------------------------------------------------------
-- The frame: scale, sizes, anchors, mask
---------------------------------------------------------------------------

function Map.LayFrame(cluster, backdrop, map)
    local container = cluster.MinimapContainer
    -- Forever puts Edit Mode's size on the container; it goes up a level.
    if container and Look.Number(container:GetScale()) ~= 1 then container:SetScale(1) end
    Map.SetClusterScale(cluster, Map.EditSize(cluster) * (Map.worn and Map.size or 1))
    local header = cluster.ZoneTextButton
    if header and Look.Number(header:GetScale()) ~= 1 then header:SetScale(1) end

    cluster:SetSize(192, 192)
    map:SetSize(140, 140)
    if container then
        container:SetSize(140, 140)
        Look.Pin(container, "CENTER", cluster, "TOP", 9, -92)
        Look.Pin(map, "CENTER", container, "CENTER", 0, 0)
    else
        Look.Pin(map, "CENTER", cluster, "TOP", 9, -92)
    end
    backdrop:SetSize(192, 192)
    Look.Pin(backdrop, "CENTER", cluster, "CENTER", 0, -20)
    -- Every pass: the game puts its own mask back when rotation changes.
    map:SetMaskTexture(Map.worn and Map.WHITE or Map.RoundMask())
end

---------------------------------------------------------------------------
-- The stone ring, its top bar and the compass
---------------------------------------------------------------------------

-- EraUI's three pieces, made once (at an apply) and set again each apply.
function Map.MakeRingArt(cluster, backdrop, map)
    local bar = Look.OwnTexture(cluster, "ringBar", "ARTWORK")
    Look.Art(bar, "mapBorder")
    Look.Crop(bar, 0.25, 1, 0, 0.125)
    bar:SetSize(192, 32)
    Look.Pin(bar, "TOPRIGHT", cluster, "TOPRIGHT", 0, 0)

    local ring = Look.OwnTexture(backdrop, "ring", "ARTWORK")
    Look.Art(ring, "mapBorder")
    Look.Crop(ring, 0.25, 1, 0.125, 0.875)
    Look.Fill(ring, backdrop)

    local north = Look.OwnTexture(backdrop, "north", "OVERLAY")
    Look.Art(north, "mapNorth")
    Look.Crop(north, 0, 1, 0, 1)
    north:SetSize(16, 16)
    Look.Pin(north, "CENTER", map, "CENTER", 0, 67)
end

-- Which of them show: the ring and its bar on the round map only; the north
-- tag while the map doesn't rotate; the 1.x compass ring (the game's own
-- texture, given the old art) while it does, round only.
function Map.LayRingArt(cluster, backdrop, map)
    local round = not Map.worn
    local turning = Map.Rotating()
    Look.Shown(Look.OwnPiece(cluster, "ringBar"), round)
    Look.Shown(Look.OwnPiece(backdrop, "ring"), round)
    Look.Shown(Look.OwnPiece(backdrop, "north"), not turning)
    Look.Fade(backdrop.StaticOverlayTexture)
    local compass = MinimapCompassTexture
    if compass then
        Look.Art(compass, "mapCompass")
        Look.Crop(compass, 0, 1, 0, 1)
        compass:SetSize(256, 256)
        Look.Pin(compass, "CENTER", map, "CENTER", -2, 0)
        compass:SetDrawLayer("OVERLAY")
        Look.Shown(compass, turning and round)
    end
    Look.Fade(MinimapCompassTextureUnderlay)
end

-- The pieces made for the round look hidden (Minimap turned off).
function Map.HideRingArt()
    if MinimapCluster then Look.Shown(Look.OwnPiece(MinimapCluster, "ringBar"), false) end
    if MinimapBackdrop then
        Look.Shown(Look.OwnPiece(MinimapBackdrop, "ring"), false)
        Look.Shown(Look.OwnPiece(MinimapBackdrop, "north"), false)
    end
end

---------------------------------------------------------------------------
-- The zone name
---------------------------------------------------------------------------

-- Across the stone bar, or the square's top strip. The classic 12 pt face
-- and size only (never a font object), so the game's PvP colour stays. The
-- zone button keeps opening the world map; only its size, place and
-- Forever's header art change.
function Map.LayZone(cluster, map)
    local relative, x, y = cluster, 0, -12
    if Map.worn then relative, x, y = map, 0, 12 end
    local button = cluster.ZoneTextButton
    if button then
        button:SetSize(140, 12)
        Look.Pin(button, "CENTER", relative, "TOP", x, y)
        Map.QuietHeader(button)
    end
    local name = MinimapZoneText
    if name then
        name:SetSize(140, 12)
        name:SetJustifyH("CENTER")
        local classic = GameFontNormal
        if classic and type(classic.GetFont) == "function" then
            local face, height, flags = classic:GetFont()
            if face and Look.Number(height) then name:SetFont(face, height, flags or "") end
        end
        Look.Pin(name, "CENTER", relative, "TOP", x, y)
    end
end

---------------------------------------------------------------------------
-- Pieces put aside
---------------------------------------------------------------------------

function Map.FadeLanding()
    local landing = ExpansionLandingPageMinimapButton
    if not landing then return end
    landing:SetAlpha(0)
    landing:EnableMouse(false)
end

function Map.HideCompartment()
    if AddonCompartmentFrame then AddonCompartmentFrame:Hide() end
end

function Map.PutAside(cluster)
    local difficulty = cluster.InstanceDifficulty
    if difficulty then Look.Pin(difficulty, "TOPLEFT", cluster, "TOPLEFT", 22, -17) end
    Map.FadeLanding()
    Map.HideCompartment()
end

---------------------------------------------------------------------------
-- Other addons' minimap buttons
---------------------------------------------------------------------------

-- The button library, if an addon has loaded it (asked for quietly), puts
-- each of its buttons on the ring or the square's edge again, as the
-- shape (MapSquare) now says. Each one protected.
function Map.TellLibraries()
    if not LibStub then return end
    local found, icons = pcall(LibStub, "LibDBIcon-1.0", true)
    if not found or type(icons) ~= "table" then return end
    if type(icons.GetButtonList) ~= "function" or type(icons.Refresh) ~= "function" then return end
    local listed, names = pcall(icons.GetButtonList, icons)
    if not listed or type(names) ~= "table" then return end
    for _, name in ipairs(names) do pcall(icons.Refresh, icons, name) end
end
