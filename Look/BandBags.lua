-- The bag buttons on the band: the backpack, four bag slots and the key ring
-- in the band's bag area (or on a stone floor of their own when the bag bar
-- is moved away, or in the corner with One Bar), the bag bar dropped back
-- onto the band in Edit Mode, the opened bag windows kept clear of the side
-- bars, and EraUI's extra ticks under Edit Mode's bag dialog.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Shape = Look.Shape
local Number, Pin, Shown, Saved = Look.Number, Look.Pin, Look.Shown, Look.Saved
local band = Look.band

local SLOT_NAMES = Look.Words("CharacterBag0Slot CharacterBag1Slot CharacterBag2Slot CharacterBag3Slot")
local ROW_W, ROW_H = 181, 39 -- the row: 30 + 32 + 96 + 23 (the slim slot)

-- The row, right to left: the backpack, the bag slots, the slim slot (the key
-- ring, or the reagent bag in its art) and the small round reagent bag.
function Look.BagRow()
    local row = { MainMenuBarBackpackButton }
    for _, slotName in ipairs(SLOT_NAMES) do row[#row + 1] = _G[slotName] or false end
    if KeyRingButton then return row, KeyRingButton, CharacterReagentBag0Slot end
    return row, CharacterReagentBag0Slot, nil
end

local function InRow(candidate)
    local row, slim, round = Look.BagRow()
    if candidate == slim or candidate == round then return true end
    for _, member in ipairs(row) do
        if member == candidate then return true end
    end
    return false
end

-- The bag bar's own Edit Mode size.
local function BarSize()
    return BagsBar and Number(BagsBar:GetScale()) or 1
end

-- The buttons take the bag bar's Edit Mode size, except a size left over
-- from before they were dropped back onto the band.
local function RowScale()
    local size, kept = BarSize(), Number(Saved().bagsSnapScale) or 0
    if kept > 0 and math.abs(size - kept) < 0.001 then return 1 end
    return size
end

---------------------------------------------------------------------------
-- The floating floor under the bags while they are off the band
---------------------------------------------------------------------------

local floorFrame

local function Floor()
    if floorFrame then return floorFrame end
    floorFrame = Look.Build("Frame", band.frame, nil, { size = { Shape.BAGS, Shape.BODY }, hidden = true })
    local piece = Shape.PIECES[4]
    local top, base = piece.rows[1] / piece.sheetHeight, piece.rows[2] / piece.sheetHeight
    local stone = floorFrame:CreateTexture(nil, "BACKGROUND")
    Look.Art(stone, piece.sheet)
    Look.Crop(stone, Shape.BAG_COLUMNS[1] / 256, Shape.BAG_COLUMNS[2] / 256, top, base)
    stone:SetAllPoints(floorFrame)
    local post = floorFrame:CreateTexture(nil, "BORDER")
    Look.Art(post, piece.sheet)
    Look.Crop(post, Shape.POST_COLUMNS[2] / 256, Shape.POST_COLUMNS[1] / 256, top, base) -- mirrored
    post:SetSize(Shape.POST, Shape.BODY)
    Pin(post, "BOTTOMLEFT", floorFrame, "BOTTOMLEFT")
    band.bagFloor = floorFrame
    return floorFrame
end

local function Unlit(owner)
    Look.EachRegion(owner, function(piece)
        if piece.GetAlpha and (Number(piece:GetAlpha()) or 1) > 0 then Look.Fade(piece) end
    end)
end

---------------------------------------------------------------------------
-- Laying the row
---------------------------------------------------------------------------

local function Seat(member, width, height, scale, level)
    Look.Remember(member)
    if member:GetParent() ~= band.frame then member:SetParent(band.frame) end
    member:SetSize(width, height)
    member:SetScale(scale)
    member:SetFrameLevel(level)
    member:ClearAllPoints()
    Shown(member, true)
end

local function RowLocked(row, slim, round)
    for _, member in ipairs({ row[1] or false, slim or false, round or false }) do
        if member and member.IsProtected and member:IsProtected() then return true end
    end
    return false
end

-- Only the buttons (no bag bar move, no floor): at the end of every layout,
-- and in a fight when none of them is protected.
function Look.LayBagButtons(scale, hangFrom)
    local row, slim, round = Look.BagRow()
    local pack = row[1]
    if not pack or (Look.InFight() and RowLocked(row, slim, round)) then return false end
    scale = scale or band.bagScale or 1
    hangFrom = hangFrom or BagsBar or band.frame
    local level = Look.ButtonLevel()
    Seat(pack, 30, 30, scale, level)
    pack:SetPoint("BOTTOMRIGHT", hangFrom, "BOTTOMRIGHT", 0, 4.5)
    ns.SkinBagButton(pack, 30, true)
    local leftOf = pack
    for i = 2, #row do
        local slot = row[i]
        if slot then
            Seat(slot, 30, 30, scale, level)
            slot:SetPoint("BOTTOMRIGHT", leftOf, "BOTTOMLEFT", -2, 0)
            ns.SkinBagButton(slot, 30, false)
            leftOf = slot
        end
    end
    if slim then
        Seat(slim, 18, 39, scale, level)
        slim:SetPoint("RIGHT", leftOf, "LEFT", -5, 0)
        ns.SkinKeyRing(slim)
    end
    if round then
        Seat(round, 17, 17, scale, level + 2)
        round:SetPoint("CENTER", leftOf, "LEFT", -2, 0)
        ns.SkinBagButton(round, 17, false, false, true)
    end
    return true
end

-- Where the row lives: "band", "corner" (One Bar) or "away" (moved in Edit Mode).
local function RowHome(shape)
    if shape.bagsOn then return "band" end
    if Saved().oneBar and not (BagsBar and Look.Moved(BagsBar)) then return "corner" end
    return "away"
end

-- The bag bar itself over the row, so Edit Mode's box fits the buttons.
local function SeatBagBar(home, shape, scale)
    local bar = BagsBar
    if not bar or bar.isDragging then return end
    Look.Remember(bar)
    if home == "away" then
        bar:SetSize(ROW_W, ROW_H)
        return
    end
    local own, bandScale = BarSize(), band.scale
    local toOwn = scale * bandScale / own -- band units to the bag bar's own
    if home == "band" then
        local x, y = Look.BandPoint(shape.bagsX + Shape.BAGS - 4, 6 - 4.5 * scale)
        Look.Place(bar, "BOTTOMRIGHT", UIParent, "BOTTOM", x / own, y / own)
    else
        local menuHeight = Look.MicroPlace() and 0 or Shape.BODY * (Number(Saved().microScale) or 1) / bandScale
        local x, y = (-6 - 4 * scale) * bandScale, (menuHeight + 6 * scale) * bandScale
        Look.Place(bar, "BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", x / own, y / own)
    end
    bar:SetSize(ROW_W * toOwn, ROW_H * toOwn)
end

function Look.LayBags(shape)
    if Look.InFight() then return end
    local home = RowHome(shape)
    local scale = home == "away" and BarSize() / band.scale or RowScale()
    band.bagMode, band.bagScale = home, scale
    SeatBagBar(home, shape, scale)
    Shown(BagBarExpandToggle, false)
    Look.LayBagButtons(scale, BagsBar or band.frame)
    if BagsBar then
        Unlit(BagsBar)
        for _, child in ipairs({ BagsBar:GetChildren() }) do
            if not InRow(child) then Unlit(child) end
        end
    end
    if home == "band" then
        Shown(floorFrame, false)
        return
    end
    local underneath = Floor()
    underneath:SetScale(scale)
    Pin(underneath, "BOTTOMRIGHT", MainMenuBarBackpackButton, "BOTTOMRIGHT", 4, -6)
    underneath:SetFrameLevel(math.max(1, Look.ButtonLevel() - 1))
    underneath:Show()
end

---------------------------------------------------------------------------
-- Dropping the bag bar back onto the band (Edit Mode)
---------------------------------------------------------------------------

-- While the bag bar is in the player's hand, the band shows where it would go.
function Look.PreviewBags()
    local bar, now = BagsBar, band.shape
    if not bar or not bar.isDragging or Saved().oneBar or not now then return end
    band.bagsInHand = true
    local near, middle = Look.NearBand(bar)
    local want = { microOn = now.microOn, bagsOn = near and true or false,
        bagsFirst = near and Look.DropSide(middle, false) or false }
    local shown = band.preview
    if shown and shown.microOn == want.microOn and shown.bagsOn == want.bagsOn and shown.bagsFirst == want.bagsFirst then return end
    band.preview = want
    if Look.RunBandLayout and not Look.InFight() then Look.RunBandLayout() end
end

-- At the layout after the bag bar is let go: back on the band (held, its size
-- remembered, the side from where it landed), or away.
function Look.FinishBagDrop()
    if not band.bagDrop or Look.InFight() then return end
    band.bagDrop, band.preview = false, nil
    local saved = ns.db
    if not saved or saved.oneBar then return end
    local near, middle = Look.NearBand(BagsBar)
    saved.bagsHeld = near and true or false
    saved.bagsSnapScale = near and BarSize() or 0
    if near then saved.bagsFirst = Look.DropSide(middle, false) end
    Look.Save()
end

---------------------------------------------------------------------------
-- Opened bag windows
---------------------------------------------------------------------------

local shifted, sized = false, false
local gameSize = Look.Weak() -- bag window: the game's own scale for it
local ourSize = Look.Weak()  -- bag window: the scale EraUI last gave it

-- The width the side bar columns cover at the screen's right edge.
local function ColumnsWidth()
    local edge = Number(UIParent:GetRight()) or Number(UIParent:GetWidth())
    local leftMost
    for _, column in ipairs({ MultiBarRight or false, MultiBarLeft or false }) do
        if edge and column and column:IsVisible() and (Number(column:GetAlpha()) or 1) > 0 then
            local l, b, r, t = Look.Rect(column)
            if l and (t - b) > 2 * (r - l) and edge - r <= 100 then leftMost = math.min(leftMost or l, l) end
        end
    end
    return leftMost and (edge - leftMost) or 0
end

local function OpenWindows()
    local fine, windows = Look.Ask(ContainerFrameSettingsManager, "GetBagsShown")
    return (fine and type(windows) == "table") and windows or {}
end

local function GameAnchors()
    local reanchor = UpdateContainerFrameAnchors
    if type(reanchor) == "function" then pcall(reanchor) end
end

-- The game's own scale for a bag window: its global helper when the client has
-- one, else the scale it had before EraUI's.
local function GameSize(window)
    local helper = _G.GetContainerScale
    if type(helper) == "function" then
        local fine, size = pcall(helper)
        if fine and Number(size) then return size end
    end
    local now = Number(window:GetScale()) or 1
    if not (ourSize[window] and math.abs(now - ourSize[window]) < 0.0001) then gameSize[window] = now end
    return gameSize[window] or now
end

-- The first window beside the side bar columns (or above the bag buttons).
local function PlaceFirstWindow(window, saved)
    local point, relative, relativePoint, x, y = window:GetPoint(1)
    if saved.bagsAboveRow then
        if relative ~= MainMenuBarBackpackButton or point ~= "BOTTOMRIGHT" then
            Pin(window, "BOTTOMRIGHT", MainMenuBarBackpackButton, "TOPRIGHT", 0, 10)
        end
        return
    end
    if relative == MainMenuBarBackpackButton then
        GameAnchors()
        point, relative, relativePoint, x, y = window:GetPoint(1)
    end
    if saved.bagsBesideBars == false or point ~= "BOTTOMRIGHT" or relativePoint ~= "BOTTOMRIGHT"
        or relative ~= window:GetParent() then
        return
    end
    local covered, scale = ColumnsWidth(), Number(window:GetScale()) or 1
    if covered > 0 and scale > 0 then
        local want = -(covered + 10) / scale
        if not Number(x) or math.abs(Number(x) - want) > 0.5 then window:SetPoint(point, relative, relativePoint, want, y) end
        shifted = true
    elseif shifted then
        shifted = false
        GameAnchors()
    end
end

function Look.KeepBagWindows()
    local saved = ns.db
    if not band.active or not saved then return end
    local windows = OpenWindows()
    local first = windows[1]
    if first and not (Look.InFight() and first.IsProtected and first:IsProtected()) then PlaceFirstWindow(first, saved) end
    if saved.bagWindowsFollow and (band.bagMode ~= "band" or saved.oneBar) then
        sized = true
        local barSize = BarSize()
        for _, window in ipairs(windows) do
            local want = GameSize(window) * barSize
            if math.abs((Number(window:GetScale()) or 1) - want) > 0.001 then
                window:SetScale(want)
                ourSize[window] = want
            end
        end
    elseif sized then
        sized = false
        for _, window in ipairs(windows) do
            if ourSize[window] then
                window:SetScale(gameSize[window] or 1)
                ourSize[window] = nil
            end
        end
    end
end

---------------------------------------------------------------------------
-- EraUI's ticks under Edit Mode's bag dialog
---------------------------------------------------------------------------

local panel

local function Toggled(key)
    if type(ns.ToggleChanged) == "function" then Look.Try(ns.ToggleChanged, key) end
end

local function Tick(owner, words, key, below, after)
    local box = CreateFrame("CheckButton", nil, owner, "UICheckButtonTemplate")
    box:SetSize(30, 30)
    if below then Pin(box, "TOPLEFT", below, "BOTTOMLEFT", 0, -2) else Pin(box, "TOPLEFT", owner, "TOPLEFT", 22, -14) end
    local caption = Look.Label(box, "GameFontHighlightMedium")
    Pin(caption, "LEFT", box, "RIGHT", 4, 0)
    caption:SetText(words)
    box:SetScript("OnClick", function(self)
        local saved = ns.db
        if not saved then return end
        saved[key] = self:GetChecked() and true or false
        if after then after(key) end
        Look.Save()
        Look.RefreshBagPanel()
    end)
    return box
end

-- Edit Mode's own size back to 100 for the bag bar; the shared options code
-- asks for a reload when Edit Mode closes (editWrote).
local function ResetBagSize()
    local editor, dialogFrame = EditModeManagerFrame, EditModeSystemSettingsDialog
    local settings = Enum and Enum.EditModeBagsSetting
    if not (editor and BagsBar and settings and settings.Size) then return end
    Look.Try(editor.OnSystemSettingChange, editor, BagsBar, settings.Size, 100)
    ns.editWrote = true
    if dialogFrame and dialogFrame.UpdateDialog then Look.Try(dialogFrame.UpdateDialog, dialogFrame, BagsBar) end
end

local function ColumnsSlider(owner, caption)
    local made, knob = pcall(CreateFrame, "Frame", nil, owner, "MinimalSliderWithSteppersTemplate")
    if not (made and knob) then return nil end
    knob:SetSize(180, 32)
    Pin(knob, "LEFT", caption, "RIGHT", 10, 0)
    local labels = {}
    local mixin = MinimalSliderWithSteppersMixin
    if mixin and mixin.Label then labels[mixin.Label.Right] = function(value) return tostring(math.floor(value + 0.5)) end end
    local fewest, most = ns.ONE_BAG_COLUMNS_MIN or 4, ns.ONE_BAG_COLUMNS_MAX or 16
    knob:Init(Number(Saved().oneBagColumns) or 8, fewest, most, most - fewest, labels)
    if mixin and mixin.Event then
        knob:RegisterCallback(mixin.Event.OnValueChanged, function(_, value)
            if owner.filling or type(ns.SetOneBagColumns) ~= "function" then return end
            Look.Try(ns.SetOneBagColumns, math.floor((Number(value) or 8) + 0.5))
        end, owner)
    end
    return knob
end

local function Panel()
    if panel then return panel end
    panel = Look.Build("Frame", UIParent, nil, { size = { 300, 184 }, strata = "DIALOG", level = 200, hidden = true })
    local fine, border = pcall(CreateFrame, "Frame", nil, panel, "DialogBorderTranslucentTemplate")
    if fine and border then
        border:SetAllPoints(panel)
    else
        local shade = panel:CreateTexture(nil, "BACKGROUND")
        shade:SetAllPoints()
        shade:SetColorTexture(0, 0, 0, 0.85)
    end
    panel.follow = Tick(panel, "Opened bags take this size too", "bagWindowsFollow")
    panel.above = Tick(panel, "Opened bags above the bag buttons", "bagsAboveRow", panel.follow, Toggled)
    panel.oneBag = Tick(panel, "One bag: all bags open as one window", "oneBag", panel.above, Toggled)
    panel.columnsCaption = Look.Label(panel, "GameFontHighlightMedium")
    Pin(panel.columnsCaption, "TOPLEFT", panel.oneBag, "BOTTOMLEFT", 4, -10)
    panel.columnsCaption:SetText("One bag columns")
    panel.columns = ColumnsSlider(panel, panel.columnsCaption)
    local note = Look.Label(panel, "GameFontDisableSmall")
    Pin(note, "BOTTOMLEFT", panel, "BOTTOMLEFT", 22, 16)
    note:SetText("These apply and save the moment you change them. No Save needed.")
    local sizeBack = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    if ns.DarkNativeButton then ns.DarkNativeButton(sizeBack) end
    sizeBack:SetHeight(28)
    sizeBack:SetFrameLevel(210)
    sizeBack:SetText("Reset To Default Size")
    sizeBack:SetScript("OnClick", ResetBagSize)
    sizeBack:Hide()
    panel.sizeBack = sizeBack
    panel:SetScript("OnShow", function() Look.RefreshBagPanel() end)
    return panel
end

function Look.RefreshBagPanel()
    if not panel or not panel:IsShown() then return end
    local saved = Saved()
    panel.follow:SetChecked(saved.bagWindowsFollow == true)
    panel.above:SetChecked(saved.bagsAboveRow == true)
    panel.oneBag:SetChecked(saved.oneBag == true)
    local usable = saved.oneBag == true
    if panel.columns then
        panel.filling = true
        pcall(panel.columns.SetValue, panel.columns, Number(saved.oneBagColumns) or 8)
        panel.filling = false
        Look.Alpha(panel.columns, usable and 1 or 0.4)
        pcall(panel.columns.SetEnabled, panel.columns, usable)
    end
    panel.columnsCaption:SetFontObject(usable and "GameFontHighlightMedium" or "GameFontDisableMed3")
end

-- Shown while Edit Mode's dialog is open for the bag bar: full width, hanging
-- just under it.
function Look.KeepBagPanel()
    local dialogFrame = EditModeSystemSettingsDialog
    local forBags = Look.EditModeOpen() and dialogFrame ~= nil and dialogFrame:IsShown() and BagsBar ~= nil
        and dialogFrame.attachedToSystem == BagsBar
    if not forBags then
        Shown(panel, false)
        return
    end
    local under = Panel()
    under:ClearAllPoints()
    under:SetPoint("TOPLEFT", dialogFrame, "BOTTOMLEFT", 0, 6)
    under:SetPoint("TOPRIGHT", dialogFrame, "BOTTOMRIGHT", 0, 6)
    under:SetHeight(184)
    local revert = dialogFrame.Buttons and dialogFrame.Buttons.RevertChangesButton
    if revert then
        Pin(under.sizeBack, "LEFT", revert, "RIGHT", 4, 0)
        under.sizeBack:SetPoint("RIGHT", dialogFrame, "RIGHT", -16, 0)
    end
    Shown(under.sizeBack, revert ~= nil)
    Shown(under, true)
end
