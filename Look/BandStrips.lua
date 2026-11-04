-- The XP and reputation strips: the game's two status tracks laid along the
-- band's top (the lower strip) and just above it (the upper strip), with a
-- flat fill in the 1.x colours under the 1.x frame art, the old rested tick,
-- and the rested part as a faint blue. The game re-anchors them often
-- (casts, damage, Edit Mode); EraUI's single anchor goes straight back in the
-- same call, so a strip never shows at the game's place for a frame.
--
-- Names used here: a track is one of the game's two status containers; a
-- meter is one of a track's bars; its gauge is the meter's status bar.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Shape = Look.Shape
local Number, Pin, Alpha = Look.Number, Look.Pin, Look.Alpha
local band = Look.band

local PURPLE, BLUE, GREEN = { 0.58, 0, 0.55 }, { 0, 0.39, 0.88 }, { 0, 0.6, 0.1 }
-- The first matching word in a gauge's atlas name picks its colour.
local ATLAS_WORDS = {
    { "Rested", BLUE }, { "Experience", PURPLE }, { "Faction-Red", { 0.8, 0.13, 0.13 } },
    { "Faction-Orange", { 1, 0.5, 0 } }, { "Faction-Yellow", { 1, 1, 0 } }, { "Faction-Green", GREEN },
    { "Faction-Blue", { 0, 0.6, 1 } }, { "Honor", { 1, 0.24, 0 } }, { "Artifact", { 0.9, 0.8, 0.6 } },
    { "Azerite", { 1, 0.8, 0.2 } },
}
-- A watched faction's reaction (2 or lower, 3, 4) picks its colour; higher is green.
local REACTION_COLOUR = { { 0.8, 0.3, 0.22 }, { 0.8, 0.3, 0.22 }, { 0.75, 0.27, 0 }, { 0.9, 0.7, 0 } }
local FADES = Look.Words("FadeInAnimation FadeOutAnimation")
local ANY_FADE = Look.Words("FadeInAnimation FadeOutAnimation MaxLevelFadeOutAnimation")

local function Tracks()
    return MainStatusTrackingBarContainer, SecondaryStatusTrackingBarContainer
end

local function EachMeter(track, visit)
    if track and type(track.bars) == "table" then
        for _, meter in pairs(track.bars) do visit(meter) end
    end
end

local function ShownMeter(track)
    if not track or type(track.bars) ~= "table" then return nil end
    for _, meter in pairs(track.bars) do
        if meter.IsShown and meter:IsShown() then return meter end
    end
    return nil
end

local function IsXP(meter)
    return meter ~= nil and meter.ExhaustionTick ~= nil
end

-- The lower and the upper strip's tracks: the main one below, unless both
-- show a meter and only the secondary shows the XP one.
function Look.StripRoles()
    local main, second = Tracks()
    local below, above = ShownMeter(main), ShownMeter(second)
    if below and above and IsXP(above) and not IsXP(below) then return second, main end
    return main, second
end

function Look.BothStrips()
    local main, second = Tracks()
    return ShownMeter(main) ~= nil and ShownMeter(second) ~= nil
end

-- A word for the strips' current state: which show a meter, and the swap.
local function StripState()
    local main, second = Tracks()
    local lower = Look.StripRoles()
    return (ShownMeter(main) and "1" or "0") .. (ShownMeter(second) and "1" or "0") .. (lower == main and "m" or "s")
end

---------------------------------------------------------------------------
-- The anchor keeper
---------------------------------------------------------------------------

local wishes = Look.Weak() -- region: { point, relative, relativePoint, x, y, its track }
local busyWriting = false

local function Locked(region)
    return region ~= nil and region.IsProtected ~= nil and region:IsProtected() and true or false
end

-- true: exactly the one wished anchor; false: not; nil: a secret value.
local function Exactly(region, wish)
    if region:GetNumPoints() ~= 1 then return false end
    local point, relative, relativePoint, x, y = region:GetPoint(1)
    if Look.Secret(point) or Look.Secret(relativePoint) or Look.Secret(x) or Look.Secret(y) then return nil end
    x, y = Number(x), Number(y)
    return point == wish[1] and relative == wish[2] and relativePoint == wish[3] and x ~= nil and y ~= nil
        and math.abs(x - wish[4]) < 0.01 and math.abs(y - wish[5]) < 0.01
end

local function WriteWish(region, wish)
    busyWriting = true
    Look.ClearPoints(region)
    Look.AddPoint(region, wish[1], wish[2], wish[3], wish[4], wish[5])
    busyWriting = false
end

local function InHand(region)
    return region.isDragging or region.isInEditMode
end

-- After the game re-anchors a strip piece: EraUI's own anchor straight back.
local function KeepAnchor(region)
    local wish = wishes[region]
    if not wish or busyWriting or band.laying then return end
    if not band.active or not Look.Enabled() or Look.EditModeOpen() then return end
    local track = wish[6] or region
    if InHand(region) or InHand(track) then return end
    if Look.InFight() and (Locked(region) or Locked(track)) then return end
    if Exactly(region, wish) == false then WriteWish(region, wish) end
end

-- The wish is published before it is written, so a role swap wins.
local function Wish(region, track, point, relative, relativePoint, x, y)
    local wish = { point, relative, relativePoint, x, y, track }
    wishes[region] = wish
    Look.Hook(region, "SetPoint", KeepAnchor)
    Look.Hook(region, "SetAllPoints", KeepAnchor)
    -- Only the containers are Edit Mode systems with an anchor of their own.
    if region == track then Look.Hook(region, "ApplySystemAnchor", KeepAnchor) end
    if not InHand(region) and not InHand(track) and Exactly(region, wish) ~= true then WriteWish(region, wish) end
end

function Look.KeepStrips()
    for region in pairs(wishes) do KeepAnchor(region) end
end

function Look.ForgetStrips()
    for region in pairs(wishes) do wishes[region] = nil end
end

---------------------------------------------------------------------------
-- Colour
---------------------------------------------------------------------------

local lastAtlas = Look.Weak()  -- gauge: the atlas the game last gave it
local saidRested = Look.Weak() -- XP meter: what the game last said about rest

local function AtlasOf(gauge)
    if type(lastAtlas[gauge]) == "string" then return lastAtlas[gauge] end
    local fill = gauge.GetStatusBarTexture and gauge:GetStatusBarTexture()
    local fine, atlas = Look.Ask(fill, "GetAtlas")
    return (fine and type(atlas) == "string") and atlas or nil
end

local function Rested(meter, gauge)
    local restPart = meter.ExhaustionLevelFillBar
    if restPart and restPart:IsShown() and (Number(restPart:GetWidth()) or 0) > 0 then return true end
    if (GetXPExhaustion and Number(GetXPExhaustion()) or 0) > 0 then return true end
    if saidRested[meter] then return true end
    local atlas = AtlasOf(gauge)
    if atlas and atlas:find("Rested", 1, true) then return true end
    return GetRestState ~= nil and Number((GetRestState())) == 1
end

-- For /eraui-classic bars: the atlas the band kept for a meter's fill and
-- whether it counts the meter as rested (reads only).
function Look.StripNotes(meter)
    local gauge = meter and meter.StatusBar
    if not gauge then return nil, nil end
    return AtlasOf(gauge), IsXP(meter) and Rested(meter, gauge) or false
end

local function Reaction()
    if not (C_Reputation and C_Reputation.GetWatchedFactionData) then return nil end
    local fine, watched = pcall(C_Reputation.GetWatchedFactionData)
    return (fine and type(watched) == "table") and Number(watched.reaction) or nil
end

local function ColourOf(meter, gauge)
    if IsXP(meter) then return Rested(meter, gauge) and BLUE or PURPLE end
    if meter.factionID ~= nil then
        local standing = Reaction()
        if standing and standing <= 4 then return REACTION_COLOUR[math.max(1, math.floor(standing))] end
        return GREEN
    end
    local atlas = AtlasOf(gauge)
    for _, entry in ipairs(atlas and ATLAS_WORDS or {}) do
        if atlas:find(entry[1], 1, true) then return entry[2] end
    end
    return PURPLE
end

local colouring = false

local function Recolour(meter)
    local gauge = meter and meter.StatusBar
    if not gauge or colouring or not band.active then return end
    colouring = true
    gauge:SetStatusBarTexture(Look.ART.statusFill.bundled)
    local colour = ColourOf(meter, gauge)
    gauge:SetStatusBarColor(colour[1], colour[2], colour[3])
    colouring = false
end

function Look.RecolourStrips(forgetRested)
    local main, second = Tracks()
    for _, track in ipairs({ main or false, second or false }) do
        EachMeter(track or nil, function(meter)
            if forgetRested then saidRested[meter] = nil end
            Recolour(meter)
        end)
    end
end

---------------------------------------------------------------------------
-- Look
---------------------------------------------------------------------------

local stripArt = Look.Weak()  -- gauge: its four 1.x art textures
local quickened = Look.Weak() -- track: its fades shortened
local pipDressed = Look.Weak() -- exhaustion tick: skinned

local function Quicken(track)
    if quickened[track] then return end
    quickened[track] = true
    for _, which in ipairs(FADES) do
        local fade = track[which]
        for _, step in ipairs(fade and fade.GetAnimations and { fade:GetAnimations() } or {}) do
            if step.SetDuration then step:SetDuration(0.02) end
            if step.SetStartDelay then step:SetStartDelay(0) end
        end
    end
end

function Look.FadeStripDividers(track)
    local dividers = track and track.HorizontalDividersPool
    if type(dividers) == "table" and type(dividers.EnumerateActive) == "function" then
        for divider in dividers:EnumerateActive() do Look.Fade(divider) end
    end
end

-- The 1.x frame art over the fill, stretched so whole notches (20 across
-- 1024 units) fit the strip; the last piece cut at the strip's end.
local function PaintStripArt(gauge, role, width)
    local faces = stripArt[gauge]
    if not faces then
        faces = {}
        for i = 1, 4 do faces[i] = gauge:CreateTexture(nil, "ARTWORK", nil, 1) end
        stripArt[gauge] = faces
    end
    local notches = math.max(1, math.floor(width / 51.2 + 0.5))
    local span = 256 * width / (notches * 51.2)
    for i, face in ipairs(faces) do
        local x = (i - 1) * span
        local shown = math.min(span, width - x)
        if shown <= 0 then
            face:Hide()
        elseif role == "lower" then
            local rows = Shape.PIECES[i].strip
            Look.Art(face, "dwarf")
            Look.Crop(face, 0, shown / span, rows[1] / 256, rows[2] / 256)
            face:SetSize(shown, 10)
            Pin(face, "BOTTOMLEFT", gauge, "BOTTOMLEFT", x, 0)
            face:Show()
        else
            Look.Art(face, "repStrip")
            Look.Crop(face, 0, shown / span, (i - 1) * 12 / 64, ((i - 1) * 12 + 11) / 64)
            face:SetSize(shown, 11)
            Pin(face, "TOPLEFT", gauge, "TOPLEFT", x, 2)
            face:Show()
        end
    end
end

local function DressPip(pip)
    if not pip or pipDressed[pip] then return end
    pipDressed[pip] = true
    pip:SetSize(32, 32)
    local plain = pip.Normal or (pip.GetNormalTexture and pip:GetNormalTexture())
    local lit = pip.Highlight or (pip.GetHighlightTexture and pip:GetHighlightTexture())
    if plain and Look.Art(plain, "tickNormal") then Look.Fill(plain, pip) end
    if lit and Look.Art(lit, "tickHighlight") then Look.Fill(lit, pip) end
end

local function DressMeter(meter, role, width, height)
    local gauge = meter.StatusBar
    if not gauge then return end
    Look.Fade(gauge.Background)
    PaintStripArt(gauge, role, width)
    local restPart = meter.ExhaustionLevelFillBar
    if restPart and restPart.SetParent then
        if restPart:GetParent() ~= gauge then restPart:SetParent(gauge) end
        restPart:SetDrawLayer("BACKGROUND", 0)
        restPart:SetColorTexture(BLUE[1], BLUE[2], BLUE[3], 0.15)
        Pin(restPart, "BOTTOMLEFT", gauge, "BOTTOMLEFT", 0, 0)
        restPart:SetHeight(height)
    end
    if meter.ExhaustionTick then
        DressPip(meter.ExhaustionTick)
        Look.Hook(meter.ExhaustionTick, "UpdateTickPosition", function() Recolour(meter) end)
    end
    Look.Hook(gauge, "SetBarTexture", function(self, atlas)
        if type(atlas) == "string" then lastAtlas[self] = atlas end
        Recolour(meter)
    end)
    Look.Hook(meter, "UpdateStatusBarTextures", function(self, isRested)
        saidRested[self] = isRested and true or false
        Recolour(self)
    end)
    Recolour(meter)
end

local function TrackLocked(track)
    if Locked(track) then return true end
    local locked = false
    EachMeter(track, function(meter)
        locked = locked or Locked(meter) or Locked(meter.StatusBar)
    end)
    return locked
end

local function LayStrip(track, role, bandWidth)
    if not track or type(track.bars) ~= "table" then return end
    if Look.InFight() and TrackLocked(track) then return end
    local height, width = role == "lower" and 10 or 7, math.max(1, bandWidth - 4)
    if role == "lower" then
        Wish(track, track, "TOP", band.frame, "TOP", 0, -1)
    else
        Wish(track, track, "BOTTOM", band.frame, "TOP", 0, 2)
    end
    local now = Number(track:GetScale())
    if not now or math.abs(now - band.scale) > 0.0001 then
        local rescale = track.SetScaleBase or track.SetScale
        rescale(track, band.scale)
    end
    track:SetSize(width, height)
    EachMeter(track, function(meter)
        Wish(meter, track, "TOPLEFT", track, "TOPLEFT", 0, 0)
        meter:SetSize(width, height)
        local gauge = meter.StatusBar
        if gauge then
            Wish(gauge, track, "TOPLEFT", meter, "TOPLEFT", 0, 0)
            gauge:SetSize(width, height)
            DressMeter(meter, role, width, height)
        end
    end)
    Look.Fade(track.BarFrameTexture)
    Quicken(track)
    Look.FadeStripDividers(track)
    Look.Hook(track, "UpdateDividers", function(self)
        if band.active then Look.FadeStripDividers(self) end
    end)
end

local laid = {} -- what the strips were last laid for

local function Geometry(track)
    if not track then return "-" end
    local point, _, _, x, y = track:GetPoint(1)
    local parts = { track:IsShown() and "1" or "0", Look.Secret(point) and "?" or tostring(point) }
    local values = { Number(x) or "?", Number(y) or "?", Number(track:GetWidth()) or "?", Number(track:GetHeight()) or "?",
        Number(track:GetScale()) or "?" }
    for _, value in ipairs(values) do
        parts[#parts + 1] = type(value) == "number" and string.format("%.1f", value) or value
    end
    local meters, size = 0, 0
    EachMeter(track, function(meter)
        meters = meters + 1
        size = size + (Number(meter:GetWidth()) or 0) + (Number(meter:GetHeight()) or 0)
    end)
    parts[#parts + 1] = meters .. ":" .. string.format("%.1f", size)
    return table.concat(parts, ",")
end

function Look.LayoutStrips()
    if not band.frame then return end
    local lower, upper = Look.StripRoles()
    LayStrip(lower, "lower", band.width)
    LayStrip(upper, "upper", band.width)
    local main, second = Tracks()
    Look.ShowMaxLevel(not ((main ~= nil and main:IsShown()) or (second ~= nil and second:IsShown())))
    laid.state, laid.main, laid.second = StripState(), Geometry(main), Geometry(second)
end

---------------------------------------------------------------------------
-- When the strips change
---------------------------------------------------------------------------

local function Fading(track)
    for _, which in ipairs(track and ANY_FADE or {}) do
        local fade = track[which]
        if fade and fade.IsPlaying and fade:IsPlaying() then return true end
    end
    return false
end

local function AnyFading()
    local main, second = Tracks()
    return Fading(main) or Fading(second)
end

local function CountStripPass()
    ns.stripPasses = 1 + (ns.stripPasses or 0)
end

-- Every 0.05 s: the shown meters and the swap. A change re-lays the strips and
-- the cast bar; the two strips coming or going lifts the bars above (a pass).
function Look.CheckStripState()
    if not band.active or not band.frame or Look.InFight() or AnyFading() then return end
    local state = StripState()
    if state == laid.state then return end
    local bothBefore = laid.state ~= nil and laid.state:sub(1, 2) == "11"
    CountStripPass()
    Look.LayoutStrips()
    if Look.PlaceCastBar then Look.PlaceCastBar() end
    if bothBefore ~= (state:sub(1, 2) == "11") then Look.Queue() end
end

-- Every 0.1 s: a track moved, resized or rescaled re-lays only the strips.
function Look.CheckStripGeometry()
    if not band.active or not band.frame or Look.InFight() then return end
    local main, second = Tracks()
    if Geometry(main) == laid.main and Geometry(second) == laid.second then return end
    CountStripPass()
    Look.LayoutStrips()
end

-- Every 0.05 s: a track with a shown meter, not fading, at full alpha.
function Look.KeepStripAlpha()
    if not band.active then return end
    local main, second = Tracks()
    for _, track in ipairs({ main or false, second or false }) do
        if track and ShownMeter(track) and not Fading(track) and (Number(track:GetAlpha()) or 1) < 1 then Alpha(track, 1) end
    end
end

function Look.FadeAllStripDividers()
    local main, second = Tracks()
    Look.FadeStripDividers(main)
    Look.FadeStripDividers(second)
end

-- Questions the reputation window asks before it re-enables its tick.
ns.StatusBarsBusy = function()
    return band.active == true and (AnyFading() or StripState() ~= laid.state)
end

ns.StatusBarsShowFaction = function()
    local main, second = Tracks()
    for _, track in ipairs({ main or false, second or false }) do
        local meter = track and ShownMeter(track)
        if meter and not IsXP(meter) and meter.factionID ~= nil then return true end
    end
    return false
end

-- Off: the game's art back; EraUI's strip art hidden; the keeper stands down.
function Look.RestoreStrips()
    Look.ForgetStrips()
    local main, second = Tracks()
    for _, track in ipairs({ main or false, second or false }) do
        if track then
            Alpha(track, 1)
            Alpha(track.BarFrameTexture, 1)
            local dividers = track.HorizontalDividersPool
            if type(dividers) == "table" and type(dividers.EnumerateActive) == "function" then
                for divider in dividers:EnumerateActive() do Alpha(divider, 1) end
            end
            EachMeter(track, function(meter)
                for _, face in ipairs(meter.StatusBar and stripArt[meter.StatusBar] or {}) do face:Hide() end
                Alpha(meter.StatusBar and meter.StatusBar.Background, 1)
            end)
        end
    end
    laid.state, laid.main, laid.second = nil, nil, nil
end

-- At a fight's end the keeper puts back what it had to leave; the XP events
-- recolour.
local stripEvents = CreateFrame("Frame")
stripEvents:RegisterEvent("PLAYER_REGEN_ENABLED")
for _, event in ipairs(Look.Words("UPDATE_EXHAUSTION PLAYER_UPDATE_RESTING PLAYER_XP_UPDATE PLAYER_ENTERING_WORLD")) do
    Look.Listen(stripEvents, event)
end
stripEvents:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        Look.KeepStrips()
    elseif band.active then
        Look.RecolourStrips(event == "PLAYER_ENTERING_WORLD")
    end
end)
