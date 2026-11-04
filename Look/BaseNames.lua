-- The shared names on the Classic namespace that the files kept from before
-- the rewrite (Classic/ThickFrames.lua, PartyOutline.lua,
-- FloatingComboPoints.lua, DamageMeter.lua), Core/ and Modules/ still call.
-- Each is one of EraUI's own helpers from Look/Base.lua underneath; the art
-- names are Look/ArtKeys.lua's, the engine's Look/Engine.lua and
-- Look/EnginePass.lua's. Names nothing calls any more were left behind.
local _, EraUI = ...
local ns, Look = EraUI.Classic, EraUI.Look

---------------------------------------------------------------------------
-- Post-hooks, each installed once per frame and method (or global, or
-- script). They are kept apart from the Look files' own hooks on the same
-- method. A piece this client lacks is named for the debug report and
-- never errors a whole part.
---------------------------------------------------------------------------

local OWNER = "names"

local function Called(frame)
    local ask = type(frame) == "table" and frame.GetName
    if type(ask) ~= "function" then return "?" end
    local fine, name = pcall(ask, frame)
    return (fine and type(name) == "string") and name or "?"
end

function ns.HookMethod(frame, method, after)
    if not frame then return false end
    return Look.HookOrMiss(frame, Called(frame), method, after, OWNER)
end

function ns.HookGlobal(name, after)
    if Look.HookGlobal(name, after, OWNER) then return true end
    Look.MissingPiece(name)
    return false
end

function ns.HookScriptOnce(frame, script, after)
    return Look.HookScript(frame, script, after, OWNER)
end

-- One record of what this client lacks, shared with the Look files.
ns.missing = Look.missingPieces
ns.MissingPiece = Look.MissingPiece

---------------------------------------------------------------------------
-- Regions, icons and fonts
---------------------------------------------------------------------------

-- Alpha, not Hide: the client shows its own regions again constantly.
ns.Fade = Look.Fade
function ns.Unfade(region)
    Look.Alpha(region, 1)
end

ns.Path = Look.Path
ns.RoundIcon = Look.RoundIcon

-- How bright the dark marble of a list pane is drawn.
ns.PANE_SHADE = 0.9

-- The old gold (1, 0.82, 0) on the game's normal and small fonts. Named
-- font objects are all this file makes as it loads.
if type(CreateFont) == "function" then
    local fine, normal = pcall(Look.GoldFont)
    if fine then ns.FONT_GOLD = normal end
    local fineSmall, small = pcall(Look.GoldFont, true)
    if fineSmall then ns.FONT_GOLD_SMALL = small end
end

---------------------------------------------------------------------------
-- Bars and Flat Bars
---------------------------------------------------------------------------

ns.Refill = Look.Refill
ns.HeldInFight = Look.HeldInFight

-- The /era Flat Bars tick (Core/Settings.lua), live: the unit frames' and
-- cast bars' own refreshers each change their fills; one that answers false
-- has a bar the game guards in a fight, and a pass is booked for the
-- fight's end (ns.ApplyAll books it). True when nothing had to wait.
function ns.RefreshFlatBars()
    local waiting = false
    for _, name in ipairs({ "RefreshUnitFrameFills", "RefreshCastFills" }) do
        local refresh = ns[name]
        if type(refresh) == "function" then
            local fine, done = Look.Try(refresh)
            if fine and done == false then waiting = true end
        end
    end
    if waiting and type(ns.ApplyAll) == "function" then ns.ApplyAll() end
    return not waiting
end
