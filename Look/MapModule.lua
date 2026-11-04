-- The minimap look's registry entry ("minimap", from /era's Minimap): one
-- layout in its order, the post-hooks that run it again after the game's
-- own passes, and turning the look on and off.
--
-- The game runs its cluster's Layout often (it is a resizing layout frame),
-- and each run lays EraUI's look out again: the layout sets the same sizes
-- and anchors every time, makes nothing new after the first time and never
-- asks for another Layout. In a fight the game's passes can still run it;
-- then the cluster is never rescaled (EraUI's pass after the fight is booked)
-- and the eye isn't moved, and the rest (cosmetic, on frames the game
-- doesn't guard) goes on as usual.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Map = Look.Map

-- Each step protected on its own: a piece this client lacks never stops the
-- rest of the layout.
function Map.Layout()
    local cluster, backdrop, map = MinimapCluster, MinimapBackdrop, Minimap
    if not (cluster and backdrop and map) then
        Look.MissingPiece("MinimapCluster")
        return
    end
    local Try = Look.Try
    Try(Map.LayFrame, cluster, backdrop, map)
    Try(Map.LayRingArt, cluster, backdrop, map)
    Try(Map.LayZone, cluster, map)
    local above = Map.Above(map)
    Try(Map.LayZoom, backdrop, map, above)
    Try(Map.LayTracking, cluster, backdrop, above)
    Try(Map.LayMail, cluster, map, above)
    Try(Map.LayCalendar, map, above)
    Try(Map.LayDiel, cluster, map)
    Try(Map.LayClock, map, above)
    Try(Map.LayEye, backdrop)
    Try(Map.LayEventLink, backdrop, map)
    Try(Map.PutAside, cluster)
    Try(Map.DressSquare, cluster, map)
    Try(Map.TellLibraries)
end

---------------------------------------------------------------------------
-- The hooks (installed once, at the first apply)
---------------------------------------------------------------------------

local hooksIn = false

local function LayAgain()
    if Map.applied then Map.Layout() end
end

local function LandingAgain()
    if Map.applied then Map.FadeLanding() end
end

local function CompartmentAgain()
    if Map.applied then Map.HideCompartment() end
end

local function InstallHooks(cluster)
    Look.HookOrMiss(cluster, "MinimapCluster", "Layout", LayAgain)
    Look.HookOrMiss(cluster, "MinimapCluster", "SetRotateMinimap", LayAgain)
    Look.HookOrMiss(cluster.IndicatorFrame, "MinimapCluster.IndicatorFrame", "Layout", LayAgain)
    -- (No hook on the queue eye's UpdatePosition: camelot's eye has none, so
    -- it only ever showed as a missing piece. Look/MapEye.lua follows the
    -- eye's own anchor instead.)
    Look.HookOrMiss(AddonCompartmentFrame, "AddonCompartmentFrame", "UpdateDisplay", CompartmentAgain)
    local calendar = GameTimeFrame
    if calendar and type(calendar.SetDate) == "function" then
        Look.HookOrMiss(calendar, "GameTimeFrame", "SetDate", Map.SkinCalendar)
    elseif not Look.HookGlobal("GameTimeFrame_SetDate", Map.SkinCalendar) then
        Look.MissingPiece("GameTimeFrame_SetDate")
    end
    Look.HookOrMiss(ExpansionLandingPageMinimapButton, "ExpansionLandingPageMinimapButton", "UpdateIcon", LandingAgain)
    Look.HookScript(Minimap, "OnLeave", Map.KeepZoomShown)
    Map.WatchRotation()
end

---------------------------------------------------------------------------
-- On (each pass, never in a fight) and off
---------------------------------------------------------------------------

local function MinimapOn()
    Map.applied = true
    local frameOfMap = MinimapCluster
    if frameOfMap == nil then
        Look.MissingPiece("MinimapCluster")
        return
    end
    local wear = Map.SquareWanted()
    local switched = wear ~= Map.worn
    Map.worn, Map.size = wear, Map.SquareSize()
    if MinimapBackdrop and Minimap then Look.Try(Map.MakeRingArt, frameOfMap, MinimapBackdrop, Minimap) end
    Map.Layout()
    if switched then Map.TellTools() end
    if not hooksIn then
        hooksIn = true
        InstallHooks(frameOfMap)
    end
end

-- Minimap is a reload setting: turning it off puts back only what's cheap
-- to put back (the square, EraUI's ring art, Forever's zone bar) and the
-- rest goes with the reload. It runs on every pass while Minimap is off,
-- whether or not the look was ever applied, so it's safe to repeat.
local function MinimapOff()
    Map.applied = false
    if Map.worn then
        Map.worn = false
        Map.TakeOffSquare()
        Map.TellTools()
    end
    Map.HideRingArt()
    Map.LoudHeader(MinimapCluster and MinimapCluster.ZoneTextButton)
    ns.needsReload = true
end

ns.RegisterModule("minimap", { apply = MinimapOn, restore = MinimapOff })
