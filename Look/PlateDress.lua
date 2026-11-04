-- The 1.x nameplate on one of the game's plates: the 128 x 16 rounded border
-- with the level slot at its right end (a skull for foes far above you), a
-- 102 x 8 health bar in the shaded fill, the name above, debuffs above the
-- name, and the cast bar in the same border underneath. Friendly players in
-- blue (green while PvP flagged), or every player in class colour while
-- "Class colored nameplates" is on.
--
-- Only the plate's own children are touched (never the protected plate
-- base), so this also runs in a fight. EraUI's pieces and its notes about
-- each plate are kept in weak tables, never on the game's frames.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local P = {}
Look.Plates = P

P.active = false
P.dressed = Look.Weak() -- unit frame: true while it wears the look
P.pieces = Look.Weak()  -- unit frame: { border, level, skull, castLeft, castRight }

-- The bundled border is the 128 x 32 original (the client's own is a wider
-- redraw), used either way; Dark Mode greys it.
Look.DefineArt("nameplateBorder", nil, "Nameplate-Border", "nameplateBorder", true)
Look.DefineArt("plateFill", "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill", "UI-TargetingFrame-BarFill")
local SKULL = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull"

local HEALTH_FADES = Look.Words("bgTexture selectedBorder deselectedOverlay Text LeftText RightText")
local FRAME_FADES = Look.Words("LevelFrame PlayerLevelDiffFrame ClassificationFrame")
local CAST_FADES = Look.Words("Background Border CastTargetNameText")
local PIECE_KEYS = Look.Words("border level skull castLeft castRight")

local function Forbidden(frame)
    local fine, answer = Look.Ask(frame, "IsForbidden")
    return fine and answer == true
end

-- The plate scale from the game's own size setting.
-- (1 to 5; missing reads as 2; anything else counts as the plain size.)
local SIZES = { 0.8, 1.0, 1.25, 1.4, 1.6 }
function P.Scale()
    local cvars = C_CVar
    local read = type(cvars) == "table" and cvars.GetCVar or nil
    local fine, value = false, nil
    if type(read) == "function" then fine, value = pcall(read, "nameplateSize") end
    if not fine or value == nil or Look.Secret(value) then return SIZES[2] end
    local size = tonumber(value)
    return (size and SIZES[size]) or 1
end

-- Every plate's unit frame (never a forbidden one), each handed to visit.
function P.Each(visit)
    local source = C_NamePlate
    local list = type(source) == "table" and source.GetNamePlates or nil
    if type(list) ~= "function" then return end
    local fine, plates = pcall(list)
    if not fine or type(plates) ~= "table" then return end
    for _, plate in ipairs(plates) do
        local unitFrame = type(plate) == "table" and plate.UnitFrame or nil
        if unitFrame and not Forbidden(plate) and not Forbidden(unitFrame) then Look.Try(visit, unitFrame) end
    end
end

-- The unit frame of one unit's plate, or nil.
function P.ForUnit(unit)
    local source = C_NamePlate
    local find = type(source) == "table" and source.GetNamePlateForUnit or nil
    if type(find) ~= "function" or type(unit) ~= "string" then return nil end
    local fine, plate = pcall(find, unit)
    local unitFrame = fine and type(plate) == "table" and plate.UnitFrame or nil
    if not unitFrame or Forbidden(plate) or Forbidden(unitFrame) then return nil end
    return unitFrame
end

-- Core/Integration.lua's question (each side's /era switch); everything
-- when nothing answers.
local function Allowed(unitFrame)
    if type(ns.PlateAllowed) ~= "function" then return true end
    local fine, allowed = pcall(ns.PlateAllowed, unitFrame)
    return fine and allowed and true or false
end

---------------------------------------------------------------------------
-- Colours and the level
---------------------------------------------------------------------------

local function Unpack(colour)
    if type(colour) ~= "table" then return nil end
    local r, g, b = Look.Number(colour.r), Look.Number(colour.g), Look.Number(colour.b)
    if r and g and b then return r, g, b end
    return nil
end

local function LevelColour(unit, level)
    local hostile = UnitCanAttack("player", unit)
    if Look.Secret(hostile) or not hostile then return 1, 0.82, 0 end
    local info, colourOf = C_PlayerInfo, GetDifficultyColor
    if type(info) == "table" and type(info.GetContentDifficultyCreatureForPlayer) == "function" and type(colourOf) == "function" then
        local fine, difficulty = pcall(info.GetContentDifficultyCreatureForPlayer, unit)
        if fine and difficulty ~= nil and not Look.Secret(difficulty) then
            local asked, colour = pcall(colourOf, difficulty)
            local r, g, b = Unpack(asked and colour or nil)
            if r then return r, g, b end
        end
    end
    if type(GetCreatureDifficultyColor) == "function" then
        local fine, colour = pcall(GetCreatureDifficultyColor, level)
        local r, g, b = Unpack(fine and colour or nil)
        if r then return r, g, b end
    end
    return 1, 0.82, 0
end

function P.Level(unitFrame)
    local pieces = P.pieces[unitFrame]
    local unit = unitFrame and unitFrame.unit
    if not pieces or not pieces.level or not unit then return end
    local level = UnitLevel(unit)
    if level == nil or Look.Secret(level) then
        pieces.level:SetText("")
        pieces.skull:Hide()
    elseif Look.SkullLevel(level, unit) then
        pieces.level:SetText("")
        pieces.skull:Show()
    else
        pieces.skull:Hide()
        pieces.level:SetText(tostring(level))
        pieces.level:SetTextColor(LevelColour(unit, level))
    end
end

-- A player's health: their class colour with "Class colored nameplates",
-- else blue for a friend (green while PvP flagged); hostile players and
-- everything else keep the game's colour.
function P.Colour(unitFrame)
    if not P.active or not unitFrame or Forbidden(unitFrame) then return end
    local health = Look.Path(unitFrame, "HealthBarsContainer", "healthBar")
    local unit = unitFrame.unit or unitFrame.displayedUnit
    if not health or not unit then return end
    local person = UnitIsPlayer(unit)
    if Look.Secret(person) or not person then return end
    if ns.db and ns.db.classColorPlates == true then
        local _, class = UnitClass(unit)
        if Look.Secret(class) then return end
        local r, g, b = Unpack(type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] or nil)
        if r then health:SetStatusBarColor(r, g, b) end
        return
    end
    local friend = UnitIsFriend("player", unit)
    if Look.Secret(friend) or not friend then return end
    local flagged = UnitIsPVP(unit)
    if not Look.Secret(flagged) and flagged then health:SetStatusBarColor(0, 1, 0) else health:SetStatusBarColor(0, 0, 1) end
end

function ns.NamePlateClassColor(unitFrame)
    P.Colour(unitFrame)
end

---------------------------------------------------------------------------
-- Dressing
---------------------------------------------------------------------------

local function Shade(fill)
    if not fill then return end
    Look.Art(fill, "plateFill")
    Look.Crop(fill, 0, 1, 0, 1)
end

local function Pieces(unitFrame, health, castBar)
    local pieces = P.pieces[unitFrame]
    if pieces then return pieces end
    pieces = {}
    pieces.border = Look.OwnTexture(health, "plateBorder", "OVERLAY", 2)
    pieces.level = Look.OwnLabel(health, "plateLevel", "SystemFont_NamePlateLevel", "OVERLAY")
    if pieces.level.SetDrawLayer then pieces.level:SetDrawLayer("OVERLAY", 3) end
    pieces.level:SetShadowColor(0, 0, 0, 1)
    pieces.level:SetShadowOffset(1, -1)
    pieces.skull = Look.OwnTexture(health, "plateSkull", "OVERLAY", 3)
    pieces.skull:SetTexture(SKULL)
    pieces.skull:SetSize(12, 12)
    pieces.skull:Hide()
    for _, region in ipairs({ pieces.level, pieces.skull }) do
        Look.Pin(region, "CENTER", pieces.border, "RIGHT", -11.5, 0)
    end
    if castBar then
        pieces.castLeft = Look.OwnTexture(castBar, "plateCastLeft", "OVERLAY", 2)
        pieces.castRight = Look.OwnTexture(castBar, "plateCastRight", "OVERLAY", 2)
    end
    P.pieces[unitFrame] = pieces
    return pieces
end

local function DressHealth(unitFrame, health, pieces)
    Shade(health.barTexture or (health.GetStatusBarTexture and health:GetStatusBarTexture()))
    P.Colour(unitFrame)
    local border = pieces.border
    Look.Art(border, "nameplateBorder")
    Look.Crop(border, 0, 1, 0.5, 1)
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", health, "TOPLEFT", -5, 4)
    border:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 21, -4)
    border:Show()
    for _, key in ipairs(HEALTH_FADES) do Look.Fade(health[key]) end
    for _, key in ipairs(FRAME_FADES) do Look.Fade(unitFrame[key]) end
    P.Level(unitFrame)
    local name = unitFrame.name
    if name then
        name:ClearAllPoints()
        name:SetPoint("BOTTOM", border, "TOP", 0, 2)
        name:SetWidth(0)
        if name.SetJustifyH then name:SetJustifyH("CENTER") end
        name:SetShadowColor(0, 0, 0, 1)
        name:SetShadowOffset(1, -1)
        local debuffs = Look.Path(unitFrame, "AurasFrame", "DebuffListFrame")
        if debuffs then
            debuffs:ClearAllPoints()
            debuffs:SetPoint("LEFT", border, "LEFT", 0, 0)
            debuffs:SetPoint("BOTTOM", name, "TOP", 0, 4)
        end
    end
end

-- One half of the cast bar's border.
local function CastHalf(half, left, right)
    Look.Art(half, "nameplateBorder")
    Look.Crop(half, left, right, 0.5, 1)
    half:SetSize(64, 16)
    half:Show()
end

local function DressCast(box, castBar, pieces)
    castBar:ClearAllPoints()
    castBar:SetPoint("TOPLEFT", box, "TOPLEFT", 0, 0)
    castBar:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 16, 0)
    Shade(castBar.GetStatusBarTexture and castBar:GetStatusBarTexture())
    local channel = castBar.channeling
    if not Look.Secret(channel) and channel then castBar:SetStatusBarColor(0, 1, 0) else castBar:SetStatusBarColor(1, 0.7, 0) end
    local left, right = pieces.castLeft, pieces.castRight
    CastHalf(left, 0, 0.5)
    CastHalf(right, 0.5, 0)
    Look.Pin(left, "TOPLEFT", castBar, "TOPLEFT", -5, 4)
    Look.Pin(right, "TOPRIGHT", castBar, "TOPRIGHT", 5, 4)
    for _, key in ipairs(CAST_FADES) do Look.Fade(castBar[key]) end
    local icon = castBar.Icon
    if icon then
        icon:SetSize(14, 14)
        Look.Pin(icon, "RIGHT", left, "LEFT", -1, 0)
    end
    local text = castBar.Text
    if text then
        Look.Pin(text, "CENTER", castBar, "CENTER", 0, 0)
        if text.SetJustifyH then text:SetJustifyH("CENTER") end
    end
end

-- A plate leaving the look (its unit is no longer one the switches allow,
-- or the look went off): EraUI's pieces hidden, the containers at scale 1,
-- the faded pieces given their alpha back. The game lays the rest out
-- again when the plate next takes a unit.
function P.Release(unitFrame)
    if not P.dressed[unitFrame] then return end
    P.dressed[unitFrame] = nil
    local pieces = P.pieces[unitFrame]
    for _, key in ipairs(PIECE_KEYS) do
        if pieces and pieces[key] then pieces[key]:Hide() end
    end
    local healthBox, castBox = unitFrame.HealthBarsContainer, unitFrame.CastBarsContainer
    for _, box in ipairs({ healthBox, castBox }) do
        if box then box:SetScale(1) end
    end
    local health = healthBox and healthBox.healthBar
    for _, key in ipairs(HEALTH_FADES) do Look.Alpha(health and health[key], 1) end
    for _, key in ipairs(FRAME_FADES) do Look.Alpha(unitFrame[key], 1) end
    local castBar = castBox and castBox.castBar
    for _, key in ipairs(CAST_FADES) do Look.Alpha(castBar and castBar[key], 1) end
end

-- One plate, each time (while the look is on and the plate's side allowed).
function P.Dress(unitFrame)
    if not P.active or not unitFrame or Forbidden(unitFrame) then return end
    local healthBox, castBox = unitFrame.HealthBarsContainer, unitFrame.CastBarsContainer
    local health = healthBox and healthBox.healthBar
    if not health or not castBox then return end
    if not Allowed(unitFrame) then
        P.Release(unitFrame)
        return
    end
    local castBar = castBox.castBar
    local pieces = Pieces(unitFrame, health, castBar)
    local scale = P.Scale()
    healthBox:SetScale(scale)
    castBox:SetScale(scale)
    castBox:ClearAllPoints()
    castBox:SetSize(102, 8)
    castBox:SetPoint("BOTTOM", unitFrame, "BOTTOM", 0, 4)
    healthBox:ClearAllPoints()
    healthBox:SetSize(102, 8)
    healthBox:SetPoint("BOTTOM", castBox, "TOP", 0, 10)
    health:ClearAllPoints()
    health:SetAllPoints(healthBox)
    DressHealth(unitFrame, health, pieces)
    if castBar and pieces.castLeft then DressCast(castBox, castBar, pieces) end
    P.dressed[unitFrame] = true
end

function P.DressAll()
    P.Each(P.Dress)
end

-- The fill wears the game's own art again (an atlas; EraUI's shade is a file).
local function Atlased(fill)
    local fine, atlas = Look.Ask(fill, "GetAtlas")
    return fine and not Look.Secret(atlas) and type(atlas) == "string" and atlas ~= ""
end

-- The sweep's look at one plate, every 0.2 s. A plate not in the look yet,
-- or one the game has laid out again (its health box back on the game's own
-- two points, where EraUI gives it one), is dressed whole; one whose side is
-- no longer allowed leaves the look. Otherwise only what can change: the
-- fill shaded again when the game put its own art back, and the colour.
function P.Keep(unitFrame)
    if not P.dressed[unitFrame] then return P.Dress(unitFrame) end
    if not Allowed(unitFrame) then return P.Release(unitFrame) end
    local healthBox = unitFrame.HealthBarsContainer
    local fine, points = Look.Ask(healthBox, "GetNumPoints")
    if not fine or Look.Secret(points) or points ~= 1 then return P.Dress(unitFrame) end
    local health = healthBox.healthBar
    local fill = health and (health.barTexture or (health.GetStatusBarTexture and health:GetStatusBarTexture()))
    if Atlased(fill) then Shade(fill) end
    P.Colour(unitFrame)
end

-- The cast bar's look alone, put back after the game's own cast bar has
-- drawn a cast (which resets its fill and colour). A plate not in the look
-- yet is dressed whole.
function P.CastLook(unitFrame)
    if not P.active or not unitFrame or Forbidden(unitFrame) then return end
    if not P.dressed[unitFrame] then return P.Dress(unitFrame) end
    local castBox = unitFrame.CastBarsContainer
    local castBar = castBox and castBox.castBar
    local pieces = P.pieces[unitFrame]
    if castBar and pieces and pieces.castLeft then DressCast(castBox, castBar, pieces) end
end
