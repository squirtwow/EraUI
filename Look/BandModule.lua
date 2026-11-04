-- The band's entry in the Classic engine's registry ("classicBar"): one full
-- layout per pass, out of a fight, each step on its own so one failing step
-- never stops the rest; turning it off undoes what EraUI changed and leaves
-- the rest to the reload Action Bars needs anyway.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local band = Look.band

ns.bandPasses, ns.stripPasses = ns.bandPasses or 0, ns.stripPasses or 0

-- The Classic settings this area reads, with their defaults (only where the
-- engine has none of its own).
do
    local wanted = {
        classicBar = true, buttons = true, castAnim = true, emptySlots = true, squareIcons = true, oneBar = false,
        defaultBarSize = false,
        hideExtraBars = true, bagsBesideBars = true, bagsAboveRow = false, oneBag = false, oneBagColumns = 8,
        barOffsetX = 0, barOffsetY = 0, barDragged = false, capHeldLeft = false, capHeldRight = false, bagsHeld = false,
        bagsSnapScale = 0, bagsFirst = false, microPosText = "", microScale = 1, pinShape = false, textureSource = "builtin",
    }
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or {}
    for key, value in pairs(wanted) do
        if engine[key] == nil then engine[key] = value end
    end
end

---------------------------------------------------------------------------
-- One pass
---------------------------------------------------------------------------

-- In order: the shape, the band's scale and place, its art, the bars, the
-- bags and menu, the strips.
local function LayEverything()
    ns.bandPasses = 1 + (ns.bandPasses or 0)
    -- The micro menu's place and its text mirror kept in step, as the engine
    -- saves the mirror after every pass.
    if ns.db then ns.db.microPosText = Look.EncodePlace(Look.MicroPlace()) end
    Look.Try(Look.FinishBagDrop)
    band.lift = Look.BothStrips() and 9 or 0
    local shape = Look.ReadShape()
    band.shape, band.width, band.scale = shape, shape.width, Look.IconScale(Look.MainBar())
    for _, step in ipairs({ Look.PlaceBand, Look.PaintBand, Look.LayCaps, Look.LayMaxLevel, Look.FadeMainArt,
        Look.LayMainRow, Look.PlacePageArrows, Look.LayUpperBars, Look.LaySmallRow, Look.LaySideBars,
        Look.LayExtraBars }) do
        Look.Try(step, shape)
    end
    Look.HookGlobal("MultiActionBar_Update", Look.FollowGameBars)
    Look.Try(Look.LayBags, shape)
    Look.Try(Look.LayMicro, shape)
    Look.Try(Look.LayoutStrips)
end

-- The band's full layout now (out of a fight), then the snapshot the keeper
-- compares against and the cast bar's place.
function Look.RunBandLayout()
    if not band.active or not band.frame or Look.InFight() then return end
    band.laying = true
    Look.Try(LayEverything)
    band.laying = false
    Look.Try(Look.Snapshot)
    Look.Try(Look.PlaceCastBar)
end

---------------------------------------------------------------------------
-- Turning the band off
---------------------------------------------------------------------------

-- A frame EraUI changed gets its first parent, size and scale back.
local function GiveBackFrame(changed)
    local first = Look.originals[changed]
    if not first then return end
    if first.parent and changed:GetParent() ~= first.parent then
        changed:SetParent(first.parent)
        if first.width and first.height then changed:SetSize(first.width, first.height) end
    end
    if first.scale then
        local rescale = changed.SetScaleBase or changed.SetScale
        rescale(changed, first.scale)
    end
    Look.originals[changed] = nil
end

local function SelectionsBack()
    for _, barName in ipairs(Look.Words([[MainActionBar MainMenuBar MultiBarBottomLeft MultiBarBottomRight
        MultiBarRight MultiBarLeft StanceBar PetActionBar PossessActionBar]])) do
        local owner = _G[barName]
        local box = owner and owner.Selection
        if box then
            Look.Fill(box, owner)
            box:EnableMouse(true)
        end
        if owner then Look.onBand[owner] = nil end
    end
end

local function ArtBack(owner)
    Look.EachRegion(owner, function(piece) Look.Alpha(piece, 1) end)
end

local function ButtonsBack()
    for _, micro in ipairs(Look.MicroList()) do
        ns.UnskinMicroButton(micro)
        Look.microOnBand[micro] = nil
        Look.PaintMenu(micro)
    end
    local row, slim, round = Look.BagRow()
    for _, bag in ipairs(row) do
        if bag then ns.UnskinBagButton(bag) end
    end
    if slim then
        ns.UnskinKeyRing(slim)
        ns.UnskinBagButton(slim)
    end
    if round then ns.UnskinBagButton(round) end
end

local function TakeDown()
    band.restorePending = false
    band.active = false
    SelectionsBack()
    for _, piece in ipairs({ band.frame or false, band.bagFloor or false }) do
        if piece then piece:Hide() end
    end
    Look.ShowExtraBars(true)
    ButtonsBack()
    for changed in pairs(Look.originals) do GiveBackFrame(changed) end
    local world = Look.WorldMapButton()
    for _, micro in ipairs(Look.MicroList()) do
        -- (The shop and any hidden leftovers were parked off the screen while
        -- the band was on.)
        if micro ~= world and micro.GetNumPoints
            and (micro:GetNumPoints() == 0 or micro == StoreMicroButton or Look.parkedMicro[micro]) then
            Look.parkedMicro[micro] = nil
            Look.Pin(micro, "CENTER", MicroMenu or UIParent, "CENTER")
        end
    end
    world:Hide()
    local main = Look.MainBar()
    Look.Alpha(main and main.BorderArt, 1)
    local _, leftCap, rightCap = Look.EndCaps()
    ArtBack(leftCap)
    ArtBack(rightCap)
    Look.Alpha(StoreMicroButton, 1)
    Look.Alpha(MicroMenu and MicroMenu.BorderArt, 1)
    Look.Alpha(MicroMenu and MicroMenu.BackgroundArt, 1)
    ArtBack(BagsBar)
    Look.Shown(BagBarExpandToggle, true)
    Look.RestoreStrips()
    Look.RestorePageFrame()
    ns.needsReload = true
end

---------------------------------------------------------------------------
-- The registry entry
---------------------------------------------------------------------------

local settler = CreateFrame("Frame")

local function Settle(_, event)
    if event == "PLAYER_REGEN_ENABLED" then
        if band.restorePending then TakeDown() elseif band.pending then Look.Queue() end
        return
    end
    -- The client settles its layouts late after a loading screen.
    for _, delay in ipairs({ 0.5, 1.5, 3 }) do C_Timer.After(delay, Look.Queue) end
end

-- Once, at login, while the band is on then.
local function StartBand()
    Look.StartWatchers()
    if MicroMenu then Look.Hook(MicroMenu, "UpdateHelpTicketButtonAnchor", Look.AnchorHelpTicket) end
    for _, event in ipairs(Look.Words("PLAYER_REGEN_ENABLED PLAYER_ENTERING_WORLD")) do settler:RegisterEvent(event) end
    settler:SetScript("OnEvent", Settle)
end

local function ApplyBand()
    local frame = Look.BuildBand()
    band.active = true
    if ns.db then ns.db.bandHandedBack = nil end
    Look.Shown(frame, true)
    band.pending = Look.InFight()
    if not band.pending then Look.RunBandLayout() end
end

-- Cheap to repeat: nothing unless the band was on; in a fight, after it.
local function RestoreBand()
    if not band.active then return end
    if Look.InFight() then
        band.restorePending = true
        return
    end
    TakeDown()
end

ns.RegisterModule("classicBar", { init = StartBand, apply = ApplyBand, restore = RestoreBand })

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------

ns.ClassicBarActive = function() return band.active == true end

-- ns.ForEachActionButton (every button the classic style dresses) comes from
-- Look/ButtonStyle.lua, loaded next.
