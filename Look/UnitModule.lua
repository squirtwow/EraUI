-- The unit frames' registry entry ("unitFrames"): one pass dresses every
-- frame from scratch (the Classic places first, Thick Frames on top when
-- wanted), out of a fight; the keepers keep the look whole between passes and
-- in fights; one event frame of EraUI's own feeds the bars and runs the
-- keepers and a 0.25 s check. Also Match Focus Size and pixel snapping, the
-- only moves of the game's Edit Mode frames, made through their plain ...Base
-- methods and never in a fight (Edit Mode's own methods would write its snap
-- records with EraUI's taint).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local UF = Look.UF

---------------------------------------------------------------------------
-- Edit Mode frames: Match Focus Size and pixel snapping
---------------------------------------------------------------------------

-- The plain SetScaleBase, then every anchor put back so the frame stays
-- where it was on the screen (what Edit Mode's own SetScale does next,
-- without its records).
function UF.Rescale(frame, newScale)
    if not frame or Look.InFight() then return false end
    local old = Look.Number(frame:GetScale())
    if old and math.abs(old - newScale) < 0.0001 then return false end
    local base = frame.SetScaleBase
    if type(base) ~= "function" then
        frame:SetScale(newScale)
        return true
    end
    if not old or old <= 0 then return false end
    local count = Look.Number(frame:GetNumPoints()) or 0
    local anchors = {}
    for i = 1, count do
        local point, relative, relativePoint, x, y = frame:GetPoint(i)
        if Look.Secret(point) or Look.Secret(relative) or Look.Secret(relativePoint) or not Look.Number(x) or not Look.Number(y) then
            return false
        end
        anchors[i] = { point, relative, relativePoint, x, y }
    end
    base(frame, newScale)
    local ratio = old / newScale
    for _, anchor in ipairs(anchors) do
        Look.AddPoint(frame, anchor[1], anchor[2], anchor[3], anchor[4] * ratio, anchor[5] * ratio)
    end
    return true
end

-- The focus at the target's scale. The game's small mode stays the game's:
-- only its health text gets the target frame's font back (the large one is
-- made for the small scale). The game's own SetSmallSize is never run.
function UF.MatchFocus()
    if not UF.Setting("matchFocusSize") or Look.InFight() or not FocusFrame or not TargetFrame then return end
    local scale = Look.Number(TargetFrame:GetScale())
    if scale and scale > 0 then UF.Rescale(FocusFrame, scale) end
    if FocusFrame.smallSize and TextStatusBarText then
        local text = Look.Path(FocusFrame, "TargetFrameContent", "TargetFrameContentMain", "HealthBarsContainer", "HealthBar",
            "TextString")
        if text then text:SetFontObject(TextStatusBarText) end
    end
end

-- Each frame's first anchor on whole screen units.
function UF.SnapPixels()
    if Look.InFight() then return end
    for _, called in ipairs(Look.Words("PlayerFrame TargetFrame FocusFrame PetFrame")) do
        local frame = _G[called]
        local point, relative, relativePoint, x, y
        if frame then point, relative, relativePoint, x, y = frame:GetPoint(1) end
        if not (Look.Secret(point) or Look.Secret(relative) or Look.Secret(relativePoint)) and point
            and Look.Number(x) and Look.Number(y) then
            local scale = Look.Number(frame:GetScale())
            if not scale or scale <= 0 then scale = 1 end
            local sx, sy = x * scale, y * scale
            local nx, ny = math.floor(sx + 0.5), math.floor(sy + 0.5)
            if math.abs(sx - nx) > 0.01 or math.abs(sy - ny) > 0.01 then
                Look.AddPoint(frame, point, relative, relativePoint, nx / scale, ny / scale)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Keepers, fills and the events
---------------------------------------------------------------------------

local KEEPERS = {
    function() UF.KeepPlayerArt() end,
    function() UF.KeepParty() end,
    function() UF.KeepPet() end,
    function() UF.KeepPlayerState() end,
    function() UF.KeepPlayerRole() end,
    function() UF.KeepPlayerPvp() end,
    function() UF.KeepPlayerSpots() end,
    function() UF.KeepTarget(TargetFrame) end,
    function() UF.KeepTarget(FocusFrame) end,
}

-- Every keeper, each on its own (an error is reported, the rest still run).
function UF.KeepAll()
    if not UF.active then return end
    for _, keeper in ipairs(KEEPERS) do Look.Try(keeper) end
end

local function FillUnit(unit, which)
    for frame, kind in pairs(UF.dressed) do
        if UF.UnitOf(frame, kind) == unit then
            local record = UF.Peek(frame)
            if which == "health" then UF.FillHealth(record and record.health, unit)
            else UF.FillPower(record and record.power, unit) end
        end
    end
end

-- Every dressed frame whose unit exists: the modern PvP background faded,
-- both bars filled.
function UF.UpdateAll()
    for frame, kind in pairs(UF.dressed) do
        local unit = UF.UnitOf(frame, kind)
        local record = UF.Peek(frame)
        if record and UF.Exists(unit) then
            if kind ~= "party" then UF.FadePvpBackground(frame) end
            UF.FillHealth(record.health, unit)
            UF.FillPower(record.power, unit)
        end
    end
end

local HEALTH_EVENTS = Look.Words("UNIT_HEALTH UNIT_MAXHEALTH")
local POWER_EVENTS = Look.Words("UNIT_POWER_UPDATE UNIT_MAXPOWER UNIT_DISPLAYPOWER UNIT_POWER_FREQUENT")
local ROSTER_EVENTS = Look.Words("GROUP_ROSTER_UPDATE PARTY_MEMBER_ENABLE PARTY_MEMBER_DISABLE PLAYER_LEVEL_UP PLAYER_LEVEL_CHANGED")
-- Each runs the keepers and a full update. PLAYER_PVP_FLAG_CHANGED (build
-- 70170) is followed like a faction change: the banner follows the flag at once.
local CHANGE_EVENTS = Look.Words([[PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED PLAYER_UPDATE_RESTING PLAYER_REGEN_DISABLED
    PLAYER_FLAGS_CHANGED UNIT_CLASSIFICATION_CHANGED UNIT_FACTION PLAYER_PVP_FLAG_CHANGED UNIT_LEVEL
    UNIT_ENTERED_VEHICLE UNIT_EXITED_VEHICLE UNIT_PET]])

local kindOf = {}
for _, list in ipairs({ { HEALTH_EVENTS, "health" }, { POWER_EVENTS, "power" }, { ROSTER_EVENTS, "roster" },
    { CHANGE_EVENTS, "change" } }) do
    for _, event in ipairs(list[1]) do kindOf[event] = list[2] end
end
kindOf.PLAYER_ENTERING_WORLD = "world"
kindOf.PLAYER_REGEN_ENABLED = "peace"

local function OnEvent(_, event, unit)
    if not UF.active then return end
    local kind = kindOf[event]
    if kind == "health" or kind == "power" then
        if unit == "pet" then UF.RepaintPet() end
        FillUnit(unit, kind)
        return
    end
    if kind == "roster" then
        UF.DressPartySoon(true)
    elseif kind == "world" then
        UF.DressPartySoon(false)
        UF.UpdateAll()
        return
    elseif kind == "peace" and UF.waiting then
        UF.waiting = false
        Look.Queue()
    end
    UF.KeepAll()
    UF.UpdateAll()
end

-- The 0.25 s check: the player's power when no event came, the aura rows,
-- the raid manager's tab, the pet's bars, then the keepers.
local lastPower, lastMost
local function PowerFallback()
    local record = PlayerFrame and UF.dressed[PlayerFrame] == "player" and UF.Peek(PlayerFrame)
    if not record or not record.power then return end
    local now, most = UnitPower("player"), UnitPowerMax("player")
    if Look.Secret(now) or Look.Secret(most) then
        -- A secret is never kept: comparing it later would be an error.
        lastPower, lastMost = nil, nil
        UF.FillPower(record.power, "player")
    elseif now ~= lastPower or most ~= lastMost then
        lastPower, lastMost = now, most
        UF.FillPower(record.power, "player")
    end
end

local function AuraRows()
    for _, frame in ipairs({ TargetFrame or false, FocusFrame or false }) do
        if frame and UF.dressed[frame] and frame:IsShown() then UF.KeepAuras(frame) end
    end
end

local waited = 0
local function Check(_, elapsed)
    if not UF.active then return end
    waited = waited + (elapsed or 0)
    if waited < 0.25 then return end
    waited = 0
    Look.Try(PowerFallback)
    Look.Try(AuraRows)
    Look.Try(UF.RaidTab)
    Look.Try(UF.RepaintPet)
    UF.KeepAll()
end

local function Listener()
    if UF.listener then return UF.listener end
    local listener = CreateFrame("Frame")
    for event in pairs(kindOf) do Look.Listen(listener, event) end
    listener:SetScript("OnEvent", OnEvent)
    listener:SetScript("OnUpdate", Check)
    UF.listener = listener
    return listener
end

---------------------------------------------------------------------------
-- The pass and turning it off
---------------------------------------------------------------------------

local function Pass()
    UF.active = true
    UF.WatchLevel()
    Listener()
    if UF.FrameOn("unitFramePlayer") then Look.Try(UF.DressPlayer) else Look.Try(UF.RestorePlayer) end
    if UF.FrameOn("unitFrameTarget") then Look.Try(UF.DressTarget, TargetFrame, "target")
    else Look.Try(UF.RestoreTarget, TargetFrame) end
    if UF.FrameOn("unitFrameFocus") then
        Look.Try(UF.MatchFocus)
        Look.Try(UF.DressTarget, FocusFrame, "focus")
    else
        Look.Try(UF.RestoreTarget, FocusFrame)
    end
    if UF.FrameOn("unitFramePet") then
        Look.Try(UF.DressPet)
    else
        UF.petDressed = nil
        if PetFrame then UF.ThickCall("Off", PetFrame) end
    end
    if UF.FrameOn("unitFrameParty") then Look.Try(UF.DressParty) else Look.Try(UF.RestoreParty) end
    UF.raidSeen = nil
    Look.Try(UF.RaidTab)
    Look.Try(UF.SnapPixels)
    UF.KeepAll()
    Look.Try(UF.UpdateAll)
end

-- Cheap and safe to repeat (it runs on every pass while the look is off).
local function TakeOff()
    UF.active = false
    Look.Try(UF.RaidTabBack)
    Look.Try(UF.RestorePlayer)
    Look.Try(UF.RestoreTarget, TargetFrame)
    Look.Try(UF.RestoreTarget, FocusFrame)
    Look.Try(UF.RestoreParty)
    UF.petDressed = nil
    if PetFrame then UF.ThickCall("Off", PetFrame) end
    ns.needsReload = true
end

ns.RegisterModule("unitFrames", { apply = Pass, restore = TakeOff })

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

-- Flat Bars switched live (from the shared RefreshFlatBars): EraUI's own
-- bars, the heal and absorb fills, the red loss bar and the pet's bars take
-- the current fill, each in its own colour. False when a bar the game guards
-- in a fight has to wait (the caller books the pass after it).
function ns.RefreshUnitFrameFills()
    if not UF.active then return true end
    local done = true
    for bar in pairs(UF.ownBars) do
        if Look.HeldInFight(bar) then done = false else Look.Refill(bar, UF.PaintOwn) end
    end
    local fill = Look.BarFill("statusBar")
    for texture in pairs(UF.overlayFills) do texture:SetTexture(fill) end
    for loss in pairs(UF.lossBars) do
        if Look.HeldInFight(loss) then done = false else Look.Refill(loss, UF.PaintFill) end
    end
    UF.RepaintPet()
    return done
end

-- Thick Frames, Portrait Rings and Classic Party Frames switched in /era.
function ns.RefreshThickFrames()
    if not UF.active then return true end
    if Look.InFight() then
        UF.waiting = true
        return false
    end
    Pass()
    return true
end
