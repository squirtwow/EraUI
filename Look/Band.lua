-- The stone band itself: the frame and its 1.x art, the gryphons, the
-- max-level cap, the band's scale and place, and every Blizzard action bar's
-- buttons laid in their classic slots. The micro menu, bags, XP strips, cast
-- bar and the watchers are in the other Look/Band*.lua files; Look/BandModule.lua
-- runs them in order as one pass.
--
-- Blizzard's bars are Edit Mode frames: they are moved only through their
-- plain ...Base methods (Look.Place, Look.Rescale) and never in a fight, so
-- no Edit Mode snap record carries EraUI's taint. The buttons themselves are
-- never moved; each one's holder (the bar's per-button container) is.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Shape = Look.Shape
local Number, Pin, Saved = Look.Number, Look.Pin, Look.Saved

-- The band's state. Tests may hand in a frame (band.frame) and the active
-- flag; nothing here is for players to set.
local band = {
    active = false,  -- the band is applied
    pending = false, -- an apply waits for the fight to end
    scale = 1,       -- band units to UIParent units
    width = 1024,
    originX = 0,     -- the band's bottom-left from UIParent's BOTTOM, in UIParent units
    originY = 0,
    lift = 0,        -- 9 while both XP strips show
}
Look.band = band

local GROW = 45 / 36 -- Default Bar Size: the game's own 45-unit buttons

---------------------------------------------------------------------------
-- What EraUI changed on Blizzard's frames, first seen, for the restore
---------------------------------------------------------------------------

local originals = Look.Weak() -- frame: { scale, parent, width, height }
Look.originals = originals

function Look.Remember(changed)
    if not changed or originals[changed] then return end
    originals[changed] = {
        scale = changed.GetScale and Number(changed:GetScale()) or nil,
        parent = changed.GetParent and changed:GetParent() or nil,
        width = changed.GetWidth and Number(changed:GetWidth()) or nil,
        height = changed.GetHeight and Number(changed:GetHeight()) or nil,
    }
end

---------------------------------------------------------------------------
-- The frame
---------------------------------------------------------------------------

function Look.BuildBand()
    if band.frame then return band.frame end
    band.frame = CreateFrame("Frame", "EraUIClassicBar", UIParent)
    band.frame:SetFrameStrata("MEDIUM")
    band.frame:SetFrameLevel(1)
    band.frame:SetSize(1024, Shape.HEIGHT)
    band.frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOM", -512, 0)
    return band.frame
end

local function BandTexture(layer, sublevel)
    return band.frame:CreateTexture(nil, layer, nil, sublevel or 0)
end

---------------------------------------------------------------------------
-- Settings the band reads from Edit Mode
---------------------------------------------------------------------------

local function BarSetting(owner, settingName)
    local settings = Enum and Enum.EditModeActionBarSetting
    return Look.EditSetting(owner, settings and settings[settingName])
end
Look.BarSetting = BarSetting

-- A bar's icon scale: its Edit Mode Icon Size (else its own first scale),
-- grown to the game's size with Default Bar Size.
function Look.IconScale(owner)
    if not owner then return 1 end
    local size = BarSetting(owner, "IconSize")
    local scale = size and size / 100
    if not scale or scale <= 0 then
        local first = originals[owner]
        scale = (first and first.scale) or Number(owner.GetScale and owner:GetScale())
    end
    scale = (scale and scale > 0) and scale or 1
    return Saved().defaultBarSize and scale * GROW or scale
end

function Look.PagesHidden(owner)
    return BarSetting(owner, "HideBarScrolling") == 1
end

-- How many icons Edit Mode lets the bar show, or nil when it won't say. The
-- stance, pet and possess bars have no such setting (Edit Mode answers 0), and
-- every bar answers 0 until Edit Mode has set it up.
function Look.IconCount(owner)
    if not owner then return nil end
    for _, count in ipairs({ BarSetting(owner, "NumIcons") or 0, Number(owner.numButtonsShowable) or 0 }) do
        if count >= 1 then return count end
    end
    return nil
end

function Look.MainIcons(owner)
    return Look.IconCount(owner) or 12
end

---------------------------------------------------------------------------
-- The shape: what sits on the band now
---------------------------------------------------------------------------

function Look.ReadShape()
    local saved = Saved()
    local oneBar = saved.oneBar == true
    local bagBar = BagsBar
    if bagBar and saved.bagsHeld and Look.InDefaultPosition(bagBar) == true then saved.bagsHeld = false end
    local on = {
        microOn = not oneBar and Look.MicroPlace() == nil,
        bagsOn = not oneBar and not (bagBar and Look.Moved(bagBar) and not saved.bagsHeld),
        bagsFirst = saved.bagsFirst == true,
    }
    local preview = band.preview
    if preview and not oneBar then on = preview end
    local main = Look.MainBar()
    return Shape.Compute({
        microOn = on.microOn, bagsOn = on.bagsOn, bagsFirst = on.bagsFirst,
        pages = not Look.PagesHidden(main), icons = Look.MainIcons(main),
        microCount = Look.MicroCount and Look.MicroCount() or 0,
        microScale = Number(saved.microScale) or 1,
    })
end

---------------------------------------------------------------------------
-- Scale and place
---------------------------------------------------------------------------

-- Action Bar 1 follows the player's hand while it is dragged, or stays where
-- it was dragged to (barDragged, and Edit Mode still has it moved).
function Look.BarDragged(main)
    if main == nil then return false end
    return main.isDragging and true or (Saved().barDragged and Look.Moved(main)) and true or false
end

-- Action Bar 1's home, its bottom-left from UIParent's BOTTOM (UIParent units).
function Look.MainHome(width, scale)
    local saved = Saved()
    return ((Number(saved.barOffsetX) or 0) - width / 2 + 8) * scale, ((Number(saved.barOffsetY) or 0) + 4) * scale
end

function Look.PlaceBand(shape)
    local frame, main, scale = band.frame, Look.MainBar(), band.scale
    frame:SetScale(scale)
    frame:SetSize(shape.width, Shape.HEIGHT)
    local middle = (Number(UIParent:GetWidth()) or 0) / 2
    if main and Look.BarDragged(main) then
        band.dragged = true
        Pin(frame, "BOTTOMLEFT", main, "BOTTOMLEFT", -8, -4)
        local left, bottom = Look.Rect(main)
        if left then band.originX, band.originY = left - middle - 8 * scale, bottom - 4 * scale end
        return
    end
    band.dragged = false
    local saved = Saved()
    local offsetX, offsetY = Number(saved.barOffsetX) or 0, Number(saved.barOffsetY) or 0
    Pin(frame, "BOTTOMLEFT", UIParent, "BOTTOM", offsetX - shape.width / 2, offsetY)
    band.originX, band.originY = (offsetX - shape.width / 2) * scale, offsetY * scale
    if main then
        Look.Remember(main)
        Look.Rescale(main, 1)
        local homeX, homeY = Look.MainHome(shape.width, scale)
        Look.Place(main, "BOTTOMLEFT", UIParent, "BOTTOM", homeX, homeY)
    end
end

-- A band point (band units from its bottom-left) in UIParent units from
-- UIParent's BOTTOM.
function Look.BandPoint(x, y)
    return band.originX + x * band.scale, band.originY + y * band.scale
end

---------------------------------------------------------------------------
-- The art
---------------------------------------------------------------------------

function Look.PaintBand(shape)
    band.slices = band.slices or {}
    local faces = band.slices
    for i, slice in ipairs(shape.slices) do
        faces[i] = faces[i] or BandTexture("BACKGROUND")
        local piece = Shape.PIECES[slice.piece]
        Look.Art(faces[i], piece.sheet)
        Look.Crop(faces[i], slice.from / 256, slice.to / 256, piece.rows[1] / piece.sheetHeight,
            piece.rows[2] / piece.sheetHeight)
        faces[i]:SetSize(slice.width, Shape.BODY)
        Pin(faces[i], "BOTTOMLEFT", band.frame, "BOTTOMLEFT", slice.x, 0)
        faces[i]:Show()
    end
    for i = #shape.slices + 1, #faces do faces[i]:Hide() end
end

-- The max-level cap: four strips of the 1.x art over the band's top, cut at
-- its right end. Shown only while no XP strip shows.
function Look.LayMaxLevel(shape, shown)
    band.maxLevel = band.maxLevel or {}
    local width = shape and shape.width or band.width
    if shown == nil then shown = band.maxShown end
    for i = 1, 4 do
        local strip = band.maxLevel[i]
        if not strip then
            strip = BandTexture("BACKGROUND")
            band.maxLevel[i] = strip
            Look.Art(strip, "maxLevel")
        end
        local x = (i - 1) * 256
        local w = math.min(256, width - x)
        if w <= 0 then
            strip:Hide()
        else
            w = math.max(1, w)
            Look.Crop(strip, 0, w / 256, (i - 1) * 8 / 32, ((i - 1) * 8 + 7) / 32)
            strip:SetSize(w, 7)
            Pin(strip, "BOTTOMLEFT", band.frame, "TOPLEFT", x, -11)
            strip:SetShown(shown and true or false)
        end
    end
end

function Look.ShowMaxLevel(shown)
    band.maxShown = shown and true or false
    if band.frame and band.maxLevel then Look.LayMaxLevel(nil, band.maxShown) end
end

---------------------------------------------------------------------------
-- The gryphons, on Edit Mode's end caps
---------------------------------------------------------------------------

-- Each side: its name, the game's cap key, and the saved "held" key.
local CAP_SIDES = { { "left", "LeftEndCap", "capHeldLeft" }, { "right", "RightEndCap", "capHeldRight" } }
Look.CAP_SIDES = CAP_SIDES

function Look.EndCaps()
    local main = Look.MainBar()
    local holder = main and main.EndCaps
    if type(holder) ~= "table" then return nil end
    return holder, holder.LeftEndCap, holder.RightEndCap
end

-- Moved: let go away from its slot (capMoved), or out of its default place in
-- Edit Mode, and not held. Edit Mode's default place clears both flags.
function Look.CapMoved(cap, capName, heldKey)
    local saved = ns.db
    if not cap or not saved then return false end
    local asked, ready = Look.Ask(cap, "IsInitialized")
    local default -- nil until Edit Mode has set the cap up
    if asked and ready == true then default = Look.InDefaultPosition(cap) end
    if default == true then
        saved[heldKey] = false
        if type(saved.capMoved) == "table" then saved.capMoved[capName] = nil end
        return false
    end
    if saved[heldKey] then return false end
    if type(saved.capMoved) == "table" and saved.capMoved[capName] then return true end
    return default == false
end

function Look.CapShown(cap)
    if not EraUI:GetSetting("gryphons") then return false end
    if not cap then return true end
    local settings = Enum and Enum.EditModeMainActionBarEndCapSetting
    local hidden = Look.EditSetting(cap, settings and settings.Hidden)
    if hidden ~= nil then return hidden ~= 1 end
    return rawget(cap, "isVisible") ~= false
end

-- Every texture on the game's two cap frames faded; their holder kept shown.
function Look.FadeCaps()
    local holder, leftCap, rightCap = Look.EndCaps()
    if not holder or Look.InFight() then return end
    Look.Shown(holder, true)
    for _, cap in ipairs({ leftCap or false, rightCap or false }) do
        Look.EachRegion(cap or nil, function(piece)
            if (Number(piece.GetAlpha and piece:GetAlpha()) or 1) > 0 then Look.Fade(piece) end
        end)
    end
end

-- A gryphon on its cap frame; a cap neither moved nor in the player's hand
-- is placed over the gryphon's home slot first (128 band units square).
local function SeatGryphon(gryphon, cap, side, homeX)
    local frame = band.frame
    gryphon:ClearAllPoints()
    if not cap then
        gryphon:SetPoint("BOTTOM", frame, "BOTTOMLEFT", homeX, 0)
        return
    end
    if not cap.isDragging and not Look.CapMoved(cap, side[2], side[3]) and not Look.InFight() then
        local capScale = Number(cap:GetEffectiveScale())
        local ratio = (capScale and capScale > 0) and (Number(frame:GetEffectiveScale()) or 1) / capScale or 1
        cap:SetSize(128 * ratio, 128 * ratio)
        Look.Place(cap, "BOTTOM", frame, "BOTTOMLEFT", homeX * ratio, 0)
    end
    gryphon:SetPoint("BOTTOM", cap, "BOTTOM", 0, 0)
end

function Look.LayCaps(shape)
    band.caps = band.caps or { left = BandTexture("OVERLAY", 5), right = BandTexture("OVERLAY", 5) }
    local _, leftCap, rightCap = Look.EndCaps()
    for _, side in ipairs(CAP_SIDES) do
        local gryphon = band.caps[side[1]]
        local cap = side[1] == "left" and leftCap or rightCap
        Look.Art(gryphon, "endCap")
        gryphon:SetSize(128, 128)
        if side[1] == "right" then Look.Crop(gryphon, 1, 0, 0, 1) else Look.Crop(gryphon, 0, 1, 0, 1) end
        SeatGryphon(gryphon, cap, side, Shape.CapHomeX(shape.width, side[1]))
        gryphon:SetShown(Look.CapShown(cap))
    end
    Look.FadeCaps()
end

-- The gryphons' visibility again (the setting, Edit Mode's Hidden).
function Look.RecheckCaps()
    if not band.caps then return end
    local _, leftCap, rightCap = Look.EndCaps()
    band.caps.left:SetShown(Look.CapShown(leftCap))
    band.caps.right:SetShown(Look.CapShown(rightCap))
end

---------------------------------------------------------------------------
-- Action Bar 1's own art
---------------------------------------------------------------------------

local function FadeDividers(owner)
    for _, poolKey in ipairs(Look.Words("HorizontalDividersPool VerticalDividersPool")) do
        local pool = owner[poolKey]
        if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
            for divider in pool:EnumerateActive() do Look.Fade(divider) end
        end
    end
end

local function DividersAgain(owner)
    if band.active then FadeDividers(owner) end
end

-- The game's frame art faded (Hide Bar Art is ignored on purpose: the client
-- flips it by itself while a spell is dragged). Dividers fade, now and after
-- each of the bar's own updates.
function Look.FadeMainArt()
    local main = Look.MainBar()
    if not main then return end
    Look.Fade(main.BorderArt)
    FadeDividers(main)
    Look.Hook(main, "UpdateDividers", DividersAgain)
end

---------------------------------------------------------------------------
-- Bars: each bar's shown buttons in rows on an EraUI row frame
---------------------------------------------------------------------------

local rows = Look.Weak()   -- bar: its row frame
local boxes = Look.Weak()  -- bar: the box its Edit Mode selection is pinned to
local onBand = Look.Weak() -- bar: true while laid on the band
Look.rows, Look.boxes, Look.onBand = rows, boxes, onBand

-- A bar's buttons: its own list, else the classic names.
function Look.BarButtons(owner)
    if type(owner) ~= "table" then return {} end
    if type(owner.actionButtons) == "table" and #owner.actionButtons > 0 then return owner.actionButtons end
    local stem = owner == Look.MainBar() and "ActionButton" or (owner.GetName and owner:GetName() or "?") .. "Button"
    local found = {}
    for slot = 1, 12 do found[#found + 1] = _G[stem .. slot] end
    return found
end

-- The buttons the bar shows, up to Edit Mode's icon count.
local function ShownButtons(owner)
    local shown, limit = {}, Look.IconCount(owner) or 12
    for _, actionButton in ipairs(Look.BarButtons(owner)) do
        local holder = actionButton.container or actionButton
        if #shown < limit and holder.IsShown and holder:IsShown() then shown[#shown + 1] = actionButton end
    end
    return shown
end

local function OneRow(owner)
    local count = Number(owner.numRows)
    return count == nil or count == 1
end

-- On the band: not moved in Edit Mode, horizontal, one row.
function Look.BandEligible(owner)
    return owner ~= nil and not Look.Moved(owner) and owner.isHorizontal ~= false and OneRow(owner)
end

-- In the classic side column: not moved, vertical (or unknown), one column.
local function ColumnEligible(owner)
    return owner ~= nil and not Look.Moved(owner) and owner.isHorizontal ~= true and OneRow(owner)
end

local function RowFor(owner)
    rows[owner] = rows[owner] or Look.Build("Frame", UIParent, nil, { size = { 1, 1 } })
    return rows[owner]
end

-- The bar's Edit Mode selection pinned (two corners) to a box over its shown
-- buttons, out of a fight.
local function PinSelection(owner, row, corner, width, height)
    local chosen = owner.Selection
    if not chosen or Look.InFight() then return end
    boxes[owner] = boxes[owner] or CreateFrame("Frame", nil, row)
    local box = boxes[owner]
    if box:GetParent() ~= row then box:SetParent(row) end
    box:SetSize(math.max(1, width), math.max(1, height))
    Pin(box, corner, row, corner)
    chosen:ClearAllPoints()
    for _, point in ipairs(Look.Words("TOPLEFT BOTTOMRIGHT")) do chosen:SetPoint(point, box, point, 0, 0) end
end

-- The row frame's place: on the band (band units), in the side column, or on
-- the bar wherever Edit Mode has it. Returns the row's scale against UIParent
-- and the corner the buttons grow from.
local function SeatRow(owner, row, place, horizontal)
    local corner = horizontal and "BOTTOMLEFT" or "TOPLEFT"
    if place.where == "band" then
        if row:GetParent() ~= band.frame then row:SetParent(band.frame) end
        row:SetScale(1)
        Pin(row, "BOTTOMLEFT", band.frame, "BOTTOMLEFT", place.x, place.y)
        return band.scale, corner
    end
    if row:GetParent() ~= UIParent then row:SetParent(UIParent) end
    row:SetScale(place.iconScale)
    if place.where == "column" then
        Pin(row, "TOPRIGHT", UIParent, "BOTTOMRIGHT", place.right, place.top)
        return place.iconScale, "TOPLEFT"
    end
    Pin(row, corner, owner, corner)
    return place.iconScale, corner
end

-- The bar frame itself: scale 1, covering its shown buttons, at its row's
-- spot (never pulled out of the player's hand).
local function SeatBar(owner, place, width, height)
    Look.Remember(owner)
    Look.Rescale(owner, 1)
    owner:SetSize(math.max(1, width * place.iconScale), math.max(1, height * place.iconScale))
    onBand[owner] = place.where == "band" or nil
    if owner.isDragging then return end
    if place.where == "band" then
        local x, y = Look.BandPoint(place.x, place.y)
        Look.Place(owner, "BOTTOMLEFT", UIParent, "BOTTOM", x, y)
    elseif place.where == "column" then
        Look.Place(owner, "TOPRIGHT", UIParent, "BOTTOMRIGHT", place.right * place.iconScale, place.top * place.iconScale)
    end
end

-- Lays a bar's shown buttons at the classic pitch. place:
--   pitch, size (42 and 36, or 33 and 30), iconScale
--   where = "band" (x, y in band units), "column" (right, top in the bar's
--   icon units, from UIParent's bottom-right) or "edit" (wherever Edit Mode
--   has the bar)
--   wider: extra width for the selection box (Action Bar 1's page arrows)
-- Returns the number of buttons laid.
function Look.LayRow(owner, place)
    if not owner or Look.InFight() then return 0 end
    local shown = ShownButtons(owner)
    local count = #shown
    local horizontal = place.where == "band" or (place.where == "edit" and owner.isHorizontal ~= false)
    local perLine = math.max(1, count)
    if place.where ~= "column" then perLine = math.max(1, math.ceil(perLine / math.max(1, Number(owner.numRows) or 1))) end
    local along, lines = math.max(1, math.min(count, perLine)), math.max(1, math.ceil(count / perLine))
    local width, height = (along - 1) * place.pitch + place.size, (lines - 1) * place.pitch + place.size
    if not horizontal then width, height = height, width end
    local row = RowFor(owner)
    local rowScale, corner = SeatRow(owner, row, place, horizontal)
    local toRow = place.iconScale / rowScale -- classic units to the row's own
    row:SetSize(width * toRow, height * toRow)
    for index, actionButton in ipairs(shown) do
        local holder = actionButton.container or actionButton
        local own = Number(actionButton:GetWidth()) or 45
        own = own > 0 and own or 45
        Look.Remember(holder)
        holder:SetScale(place.size / own * place.iconScale)
        local line, step = math.floor((index - 1) / perLine), (index - 1) % perLine
        local across, down = step * place.pitch, line * place.pitch
        if not horizontal then across, down = line * place.pitch, -step * place.pitch end
        local toHolder = own / place.size -- classic units to the holder's own
        Pin(holder, corner, row, corner, across * toHolder, down * toHolder)
    end
    SeatBar(owner, place, width, height)
    PinSelection(owner, row, corner, width * toRow + (place.wider or 0) / rowScale, height * toRow)
    return count
end

local BIG, SMALL = { pitch = 42, size = 36 }, { pitch = 33, size = 30 }

local function Placing(kind, where, extra)
    local place = { pitch = kind.pitch, size = kind.size, where = where }
    for key, value in pairs(extra or {}) do place[key] = value end
    return place
end

-- Action Bar 1: always on the band, its first slot at band (8, 4).
function Look.LayMainRow(shape)
    local main = Look.MainBar()
    if not main then return end
    Look.LayRow(main, Placing(BIG, "band", { x = 8, y = 4, iconScale = Look.IconScale(main),
        wider = shape.pages and 36 * band.scale or 0 }))
end

-- A bar on the band at (x, y) when it may sit there, else where Edit Mode has it.
local function BandOrEdit(owner, kind, x, y)
    if not owner then return false end
    local iconScale = Look.IconScale(owner)
    if Look.BandEligible(owner) then
        Look.LayRow(owner, Placing(kind, "band", { x = x, y = y, iconScale = iconScale }))
        return true
    end
    Look.LayRow(owner, Placing(kind, "edit", { iconScale = iconScale }))
    return false
end

-- Bars 2 and 3 above the band (bar 3 over the right half, or with One Bar
-- stacked over bar 2).
function Look.LayUpperBars(shape)
    local lift = band.lift or 0
    BandOrEdit(MultiBarBottomLeft, BIG, 8, 55 + lift)
    if Saved().oneBar then
        BandOrEdit(MultiBarBottomRight, BIG, 8, 97 + lift)
    else
        BandOrEdit(MultiBarBottomRight, BIG, shape.base + 8, 55 + lift)
    end
end

-- The small row: stance, possess and pet bars with 30-unit buttons. After
-- each of the first two laid on the band and shown, the row moves on by its
-- whole button list.
function Look.LaySmallRow()
    local x, y = 30, 104 + (Saved().oneBar and 42 or 0) + (band.lift or 0)
    for _, owner in ipairs({ StanceBar or false, PossessActionBar or false }) do
        if owner and BandOrEdit(owner, SMALL, x, y) and owner:IsShown() then
            x = x + #Look.BarButtons(owner) * 33 + 8
        end
    end
    BandOrEdit(PetActionBar, SMALL, math.max(36, x), y)
end

-- Bars 4 and 5 in two columns down the right edge.
function Look.LaySideBars()
    local outer, inner = MultiBarRight, MultiBarLeft
    local outerScale, outerInColumn = 1, false
    if outer then
        outerScale = Look.IconScale(outer)
        outerInColumn = ColumnEligible(outer)
        Look.LayRow(outer, Placing(BIG, outerInColumn and "column" or "edit", { right = -2, top = 602, iconScale = outerScale }))
    end
    if inner then
        local innerScale = Look.IconScale(inner)
        local right = -2
        if outerInColumn and outer:IsShown() then right = (-2 - 36) * (outerScale / innerScale) - 6 end
        Look.LayRow(inner, Placing(BIG, ColumnEligible(inner) and "column" or "edit",
            { right = right, top = 602, iconScale = innerScale }))
    end
end

---------------------------------------------------------------------------
-- Bars 6 to 8: hidden by alpha (keybinds still work) unless turned on
---------------------------------------------------------------------------

local EXTRA = Look.Words("MultiBar5 MultiBar6 MultiBar7")

function Look.ShowExtraBars(show)
    for _, extraName in ipairs(EXTRA) do
        local extra = _G[extraName]
        if extra then
            Look.Alpha(extra, show and 1 or 0)
            for _, actionButton in ipairs(Look.InFight() and {} or Look.BarButtons(extra)) do
                if actionButton.IsMouseEnabled and actionButton:IsMouseEnabled() ~= show then actionButton:EnableMouse(show) end
            end
        end
    end
end

function Look.LayExtraBars()
    Look.ShowExtraBars(Saved().hideExtraBars == false)
end

-- After the game updates its extra bars: turning bar 6, 7 or 8 on in the
-- game's own settings turns Hide Extra Bars off.
function Look.FollowGameBars()
    local saved = ns.db
    if not band.active or not saved or saved.hideExtraBars == false then return end
    local reader = type(Settings) == "table" and Settings.GetValue
    if type(reader) ~= "function" then return end
    for number = 6, 8 do
        local fine, turnedOn = pcall(reader, "PROXY_SHOW_ACTIONBAR_" .. number)
        if fine and turnedOn == true then
            saved.hideExtraBars = false
            Look.ShowExtraBars(true)
            if type(ns.RefreshOptionsWindow) == "function" then Look.Try(ns.RefreshOptionsWindow) end
            Look.Save()
            return
        end
    end
end
