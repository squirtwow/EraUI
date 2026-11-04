-- Watching the band: Edit Mode (watched by polling, never hooked, so EraUI's
-- code stays out of Edit Mode's own passes), the left button let go after a
-- drag, and the position keeper that puts the bars back when the client moves
-- them by itself (target and focus changes, pet, stance and vehicle bars,
-- Edit Mode re-applying at a level-up). In a fight only unprotected bag and
-- micro buttons are touched; everything else waits for the fight's end.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Shape = Look.Shape
local Number = Look.Number
local band = Look.band

local OWNED = Look.Words([[MainActionBar MultiBarBottomLeft MultiBarBottomRight MultiBarRight MultiBarLeft StanceBar
    PetActionBar PossessActionBar MicroMenuContainer BagsBar MainStatusTrackingBarContainer
    SecondaryStatusTrackingBarContainer]])
local HOLDERS = Look.Words("BottomManagedFrameContainer RightManagedFrameContainer MicroMenu BagsBar")
local SETTINGS_WATCHED = Look.Words("MultiBarBottomLeft MultiBarBottomRight MultiBarRight MultiBarLeft StanceBar PetActionBar")
local NO_SELECTION = Look.Words("MicroMenuContainer MainStatusTrackingBarContainer SecondaryStatusTrackingBarContainer")

---------------------------------------------------------------------------
-- Snapshots
---------------------------------------------------------------------------

local function Text(value)
    if Look.Secret(value) then return "?" end
    local n = Number(value)
    return n and string.format("%.1f", n) or tostring(value)
end

-- A frame's first anchor, size, scale and shown state as one word.
local function Describe(watched)
    if type(watched) ~= "table" or not watched.GetPoint then return "-" end
    local point, relative, relativePoint, x, y = watched:GetPoint(1)
    return table.concat({ Text(point), tostring(Look.AnchorName(relative)), Text(relativePoint), Text(x), Text(y),
        Text(watched:GetWidth()), Text(watched:GetHeight()), Text(watched:GetScale()),
        watched:IsShown() and "1" or "0" }, ",")
end

local function WatchedFrames()
    local found = {}
    for _, kind in ipairs(HOLDERS) do found[#found + 1] = _G[kind] or false end
    for _, kind in ipairs(OWNED) do found[#found + 1] = _G[kind] or false end
    local firstMicro = Look.MicroList()[1]
    local _, leftCap, rightCap = Look.EndCaps()
    for _, extra in ipairs({ MainMenuBarBackpackButton or false, firstMicro or false, leftCap or false, rightCap or false }) do
        found[#found + 1] = extra
    end
    return found
end

local function ShownCount(members)
    local shown = 0
    for _, member in ipairs(members) do
        if member and member:IsShown() then shown = shown + 1 end
    end
    return shown
end

-- The rows: every bag button, the key ring, the reagent bag and every micro button.
local function RowMembers()
    local row, slim, round = Look.BagRow()
    local members = {}
    for _, member in ipairs(row) do if member then members[#members + 1] = member end end
    if slim then members[#members + 1] = slim end
    if round then members[#members + 1] = round end
    for _, member in ipairs(Look.MicroList()) do members[#members + 1] = member end
    return members
end

local snapshot, rowShot = {}, nil

local function DescribeRows()
    local words = {}
    for _, member in ipairs(RowMembers()) do words[#words + 1] = Describe(member) end
    return table.concat(words, "|")
end

local function Counts()
    return ShownCount(Look.MicroList()) .. "/" .. ShownCount((Look.BagRow()))
end

function Look.SnapshotRows()
    rowShot = DescribeRows()
end

function Look.Snapshot()
    snapshot = { counts = Counts(), bar = Describe(Look.MainBar()) }
    for index, watched in ipairs(WatchedFrames()) do snapshot[index] = Describe(watched) end
    Look.SnapshotRows()
end

local function Shifted()
    for index, watched in ipairs(WatchedFrames()) do
        if snapshot[index] ~= Describe(watched) then return true end
    end
    return snapshot.counts ~= Counts()
end

local function RowsShifted()
    return rowShot ~= nil and rowShot ~= DescribeRows()
end

local function RowsLocked()
    for _, member in ipairs(RowMembers()) do
        if member.IsProtected and member:IsProtected() then return true end
    end
    return false
end

---------------------------------------------------------------------------
-- The piece in the player's hand
---------------------------------------------------------------------------

local function InHand()
    for _, kind in ipairs(OWNED) do
        local system = _G[kind]
        if system and system.isDragging then return system end
    end
    local _, leftCap, rightCap = Look.EndCaps()
    if leftCap and leftCap.isDragging then return leftCap, "left" end
    if rightCap and rightCap.isDragging then return rightCap, "right" end
    return band.microMoving and band.group or nil
end

-- While Action Bar 1 is dragged the band rides along; another band bar's
-- row follows its bar.
local function RideAlong(held)
    if Look.InFight() then return end
    if held == Look.MainBar() then
        local point, relative = band.frame:GetPoint(1)
        if relative ~= held or point ~= "BOTTOMLEFT" then Look.Pin(band.frame, "BOTTOMLEFT", held, "BOTTOMLEFT", -8, -4) end
        return
    end
    local row = Look.rows[held]
    if row and Look.onBand[held] and select(2, row:GetPoint(1)) ~= held then
        Look.Pin(row, "BOTTOMLEFT", held, "BOTTOMLEFT")
    end
end

---------------------------------------------------------------------------
-- The position keeper
---------------------------------------------------------------------------

local upChecks = 0
local quickRuns, restUntil, lastRun = 0, 0, 0

-- More than 8 passes each under 1 s apart pause passes for 0.6 s.
local function TooMany()
    local now = GetTime and GetTime() or 0
    if now < restUntil then return true end
    quickRuns = (now - lastRun < 1) and quickRuns + 1 or 1
    lastRun = now
    if quickRuns > 8 and not (band.dragging and Look.EditModeOpen()) then
        quickRuns, restUntil = 0, now + 0.6
        return true
    end
    return false
end

local function LeftDown()
    return IsMouseButtonDown ~= nil and IsMouseButtonDown("LeftButton") and true or false
end

-- In a fight: note it, and put back only bag and micro buttons none of which
-- is protected.
local function FightCheck()
    if Look.EditModeOpen() then
        band.editedInFight = true
    elseif not band.notedInFight and Shifted() then
        band.notedInFight, band.shiftInFight = true, true
        Look.Note("a band bar moved in a fight")
    end
    if RowsShifted() and not RowsLocked() then
        Look.LayBagButtons()
        Look.LayMicroButtons()
        Look.SnapshotRows()
        Look.PlaceCastBar()
    end
end

function Look.CheckPositions()
    if not band.active or not band.frame then return end
    local held, side = InHand()
    if held then
        band.dragging, band.waitRelease, upChecks = held, true, 0
        if side then band.capInHand = { held, side } end
        if held == BagsBar then band.bagsInHand = true end
        RideAlong(held)
        return
    end
    if band.waitRelease then
        if not LeftDown() then upChecks = upChecks + 1 end
        if upChecks < 30 then return end
        band.waitRelease = false
    end
    if Look.InFight() then return FightCheck() end
    if band.notedInFight or band.editedInFight then
        if band.shiftInFight then Look.Note("the band was put back after a fight") end
        band.notedInFight, band.editedInFight, band.shiftInFight = false, false, false
    end
    if (Shifted() or RowsShifted()) and not TooMany() then Look.RunBandLayout() end
end

---------------------------------------------------------------------------
-- Letting go in Edit Mode
---------------------------------------------------------------------------

-- Action Bar 1 dragged, unless it was dropped within 40 units of its home.
local function SnapHome()
    local saved, main, shape = ns.db, Look.MainBar(), band.shape
    if not saved or not main or not shape then return end
    if snapshot.bar ~= Describe(main) then saved.barDragged = true end
    local left, bottom = Look.Rect(main)
    local middle = (Number(UIParent:GetWidth()) or 0) / 2
    if not saved.barDragged or not left then return end
    local homeX, homeY = Look.MainHome(shape.width, band.scale)
    if math.abs(left - middle - homeX) <= 40 and math.abs(bottom - homeY) <= 40 then saved.barDragged = false end
end

-- A gryphon let go near its slot follows the band again (held); elsewhere it
-- stays where Edit Mode put it (moved).
local function LetGoCap(cap, side)
    local saved, frame, shape = ns.db, band.frame, band.shape
    if not saved or not frame or not shape then return end
    local keys = side == "left" and Look.CAP_SIDES[1] or Look.CAP_SIDES[2]
    local pixels = Number(UIParent:GetEffectiveScale()) or 1
    local bandPixels, capPixels = Number(frame:GetEffectiveScale()) or pixels, Number(cap:GetEffectiveScale()) or pixels
    local bandLeft, bandBottom = Number(frame:GetLeft()), Number(frame:GetBottom())
    local capLeft, capBottom = Number(cap:GetLeft()), Number(cap:GetBottom())
    if not (bandLeft and bandBottom and capLeft and capBottom) then return end
    local homeLeft = (bandLeft + Shape.CapHomeX(shape.width, side) - 64) * bandPixels
    local held = Shape.CapHeld(capLeft * capPixels, capBottom * capPixels, homeLeft, bandBottom * bandPixels, 48 * pixels)
    saved.capMoved = type(saved.capMoved) == "table" and saved.capMoved or {}
    saved[keys[3]] = held
    saved.capMoved[keys[2]] = (not held) or nil
    Look.Save()
end

local function LetGo()
    if not band.active then return end
    SnapHome()
    if band.bagsInHand then band.bagDrop, band.bagsInHand = true, false end
    if band.capInHand then LetGoCap(band.capInHand[1], band.capInHand[2]) end
    band.capInHand, band.dragging, band.waitRelease = nil, nil, false
    if not Look.InFight() then Look.RunBandLayout() end
    Look.Queue()
end

local function EditModeTurned(open)
    band.dragging, band.capInHand, band.bagsInHand, band.waitRelease, band.preview = nil, nil, nil, false, nil
    if not open then Look.ForgetMicroChange() end
    Look.Queue()
end

---------------------------------------------------------------------------
-- The ticks
---------------------------------------------------------------------------

local editing, buttonWasDown = false, false
local lastPagesHidden, lastBarShapes = nil, {}

local function EveryFrame()
    local open = Look.EditModeOpen()
    if open ~= editing then
        editing = open
        EditModeTurned(open)
    end
    local down = LeftDown()
    if open and buttonWasDown and not down then LetGo() end
    buttonWasDown = down
end

local function BarShape(owner)
    if not owner then return "-" end
    return ("%s:%s:%s"):format(tostring(owner.isHorizontal), tostring(Number(owner.numRows)), tostring(Look.IconCount(owner)))
end

-- Edit Mode open: a pass when Hide Bar Scrolling or a bar's shape changed,
-- EraUI-owned pieces without Edit Mode's own selection, Save and Revert kept
-- usable for a micro change, the bag bar's drop preview.
local function EditModeTick()
    local pagesHidden = Look.PagesHidden(Look.MainBar())
    local changed = lastPagesHidden ~= nil and pagesHidden ~= lastPagesHidden
    lastPagesHidden = pagesHidden
    for _, kind in ipairs(NO_SELECTION) do
        local chosen = _G[kind] and _G[kind].Selection
        if chosen and chosen:IsShown() then chosen:Hide() end
    end
    Look.KeepSaveRevert()
    for _, kind in ipairs(SETTINGS_WATCHED) do
        local now = BarShape(_G[kind])
        changed = changed or (lastBarShapes[kind] ~= nil and lastBarShapes[kind] ~= now)
        lastBarShapes[kind] = now
    end
    if changed then Look.Queue() end
    Look.PreviewBags()
end

-- Edit Mode has Action Bar 1 back at its default place (its Reset To
-- Default Position): no longer dragged, and the band goes home.
local function MainBackHome()
    local saved, main = ns.db, Look.MainBar()
    if saved and saved.barDragged and main and not main.isDragging and Look.InDefaultPosition(main) == true then
        saved.barDragged = false
        Look.Queue()
    end
end

local function SlowTick()
    if not band.active then return end
    if editing then EditModeTick() end
    Look.FadeAllStripDividers()
    Look.ShowMicroHandle(editing)
    Look.KeepBagPanel()
    if not Look.InFight() and not band.dragging then
        Look.FadeCaps()
        Look.RecheckCaps()
        MainBackHome()
    end
end

local function TenthTick()
    if not band.active then return end
    Look.KeepBagWindows()
    Look.CheckStripGeometry()
    Look.CheckPositions()
    ns.RefreshMicroButtons()
end

local function TwentiethTick()
    if not band.active then return end
    Look.CheckStripState()
    Look.KeepStripAlpha()
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local keeper
local KEEPER_EVENTS = Look.Words([[PLAYER_TARGET_CHANGED PLAYER_FOCUS_CHANGED PLAYER_REGEN_DISABLED PLAYER_REGEN_ENABLED
    PET_BAR_UPDATE UPDATE_SHAPESHIFT_FORMS UPDATE_BONUS_ACTIONBAR UPDATE_VEHICLE_ACTIONBAR UPDATE_OVERRIDE_ACTIONBAR]])

-- The band's bars' Edit Mode selections take no mouse in a fight.
local function SelectionsTakeMouse(take)
    for owner in pairs(Look.onBand) do
        local chosen = owner.Selection
        if chosen and not (Look.InFight() and chosen:IsProtected()) then chosen:EnableMouse(take) end
    end
end

local function KeeperEvent(_, event)
    if not band.active then return end
    if event == "PLAYER_REGEN_DISABLED" then
        Look.Note("a fight starts")
        Look.CheckPositions()
        return SelectionsTakeMouse(false)
    end
    if event == "PLAYER_REGEN_ENABLED" then SelectionsTakeMouse(true) end
    Look.CheckPositions()
end

-- Once a second out of a fight, the keeper takes the last place in line for
-- the fight's start, so its final pass comes after other addons' moves.
local function StayLast()
    if not keeper or Look.InFight() then return end
    keeper:UnregisterEvent("PLAYER_REGEN_DISABLED")
    keeper:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local started = false
function Look.StartWatchers()
    if started then return end
    started = true
    keeper = CreateFrame("Frame")
    for _, event in ipairs(KEEPER_EVENTS) do Look.Listen(keeper, event) end
    Look.Listen(keeper, "UNIT_PET", "player")
    keeper:SetScript("OnEvent", KeeperEvent)
    Look.Every(0, EveryFrame)
    Look.Every(0.1, TenthTick)
    Look.Every(0.05, TwentiethTick)
    Look.Every(function() return editing and 0.05 or 0.2 end, SlowTick)
    Look.Every(1, StayLast)
end
