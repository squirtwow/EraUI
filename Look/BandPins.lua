-- Edit Mode layout pins, written only as the session ends (just before a
-- reload). The band moves Blizzard's bars away from their default spots; if
-- the active Edit Mode layout still says "default", the game puts them back
-- by itself, in a fight too (a level-up re-applies the layout), where EraUI
-- may not move them. So the band's places are written into the layout first.
-- The shared options code sets ns.sessionEnding and calls these.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Number = Look.Number
local band = Look.band

local PINNED_KINDS = Look.Words([[MainActionBar MainMenuBar MultiBarBottomLeft MultiBarBottomRight MultiBarRight
    MultiBarLeft StanceBar PetActionBar PossessActionBar MainStatusTrackingBarContainer
    SecondaryStatusTrackingBarContainer]])
-- The shaman's totem bar. Since 70425 it is one of Edit Mode's bottom bars
-- (Camelot's EditModeUtil.GetBottomActionBars), stacked above Action Bar 1
-- whenever it shows or hides. With every other bottom bar pinned, Blizzard
-- stacked it alone, over the band's left rows (2026-10-17 audit A5). The
-- band never lays it: as the session ends it is pinned just above the
-- band's small row (stance, possess, pet), at the row's start, clear of
-- every row (room kept for the two-strip lift), unless the player moved it.
local TOTEM = "MultiCastActionBarFrame"
local TOTEM_X, TOTEM_Y, ONE_BAR_LIFT = 30, 104 + 30 + 4 + 9, 42
local HANDED_BACK = Look.Words("BagsBar MicroMenuContainer " .. TOTEM)
for _, kind in ipairs(PINNED_KINDS) do HANDED_BACK[#HANDED_BACK + 1] = kind end

local function EditSystem(candidate)
    return type(candidate) == "table" and candidate.system ~= nil and type(candidate.IsInDefaultPosition) == "function"
end

-- Shown band frames Edit Mode has in their default place (and, with pins,
-- those EraUI pinned before). Empty while the band is off.
local function Gather(withPins)
    local found = {}
    for _, kind in ipairs(band.active and PINNED_KINDS or {}) do
        local system = _G[kind]
        if EditSystem(system) and system:IsShown()
            and (Look.InDefaultPosition(system) == true or (withPins and Look.PinnedByEraUI(system))) then
            found[#found + 1] = system
        end
    end
    return found
end

local function Asks(question)
    if type(question) ~= "function" then return false end
    local fine, answer = pcall(question)
    return fine and answer and true or false
end

-- Each end cap that isn't the player's own placement goes back to Edit
-- Mode's default.
local function CapsHome()
    local _, leftCap, rightCap = Look.EndCaps()
    local any = false
    for index, side in ipairs(Look.CAP_SIDES) do
        local cap = index == 1 and leftCap or rightCap
        if EditSystem(cap) and not Look.CapMoved(cap, side[2], side[3]) and Look.InDefaultPosition(cap) == false
            and pcall(cap.ResetToDefaultPosition, cap) then
            any = true
        end
    end
    return any
end

local function LayoutRecord(editor, system)
    local fine, record = pcall(editor.GetActiveLayoutSystemInfo, editor, system.system, system.systemIndex)
    if fine and type(record) == "table" then return record end
    local own = rawget(system, "systemInfo")
    return type(own) == "table" and own or nil
end

-- Bottom-left to UIParent's BOTTOM at the same spot on screen, unless it is
-- already anchored to UIParent by two different points.
local function ToBottom(system)
    local from, relative, to = system:GetPoint(1)
    if relative == UIParent and from ~= to then return end
    local left, bottom = Number(system:GetLeft()), Number(system:GetBottom())
    local own, root, across = Number(system:GetEffectiveScale()), Number(UIParent:GetEffectiveScale()),
        Number(UIParent:GetWidth())
    if not (left and bottom and own and root and across) or own <= 0 then return end
    Look.ClearPoints(system)
    Look.AddPoint(system, "BOTTOMLEFT", UIParent, "BOTTOM", left - across / 2 * root / own, bottom)
end

-- The totem bar while EraUI may pin it: Edit Mode has it at its default
-- spot, or at EraUI's own pin. Hidden too (it shows from level 20, and a
-- shared layout serves every character), never once the player moved it.
local function TotemToPin()
    local totem = _G[TOTEM]
    if not band.active or not EditSystem(totem) then return nil end
    if Look.InDefaultPosition(totem) == true or Look.PinnedByEraUI(totem) then return totem end
end

-- Its spot, bottom-left from UIParent's BOTTOM in UIParent units (One Bar
-- stacks the rows higher), or nil before the band has been placed.
local function TotemSpot()
    if not Number(band.originX) or not Number(band.originY) or not Number(band.scale) then return nil end
    return Look.BandPoint(TOTEM_X, TOTEM_Y + (ns.db and ns.db.oneBar and ONE_BAR_LIFT or 0))
end

-- Puts the totem bar on its spot (its plain ...Base methods); it, or nil.
local function PlaceTotem()
    local totem = TotemToPin()
    local x, y = TotemSpot()
    if not totem or not x then return nil end
    local own = Number(totem:GetScale())
    own = (own and own > 0) and own or 1
    Look.ClearPoints(totem)
    Look.AddPoint(totem, "BOTTOMLEFT", UIParent, "BOTTOM", x / own, y / own)
    return totem
end

-- The frame's place written into the layout, and kept as EraUI's pin.
-- True when the layout changed.
local function Record(editor, system, pins)
    local fine, moved = pcall(editor.UpdateSystemAnchorInfo, editor, system)
    local record = fine and LayoutRecord(editor, system)
    local anchor = record and record.anchorInfo
    if type(anchor) == "table" and system:GetName() then
        pins[system:GetName()] = { anchor.point, anchor.relativePoint, anchor.offsetX, anchor.offsetY }
    end
    return fine and moved and true or false
end

local function Pin()
    if not ns.sessionEnding or not band.active or Look.InFight() or not Asks(ns.LayoutWritable) then return false end
    local editor = EditModeManagerFrame
    local layout = Look.LayoutName()
    if not editor or not layout or type(editor.UpdateSystemAnchorInfo) ~= "function"
        or type(editor.SaveLayouts) ~= "function" then
        return false
    end
    local saved = ns.db
    saved.barPins = type(saved.barPins) == "table" and saved.barPins or {}
    saved.barPins[layout] = type(saved.barPins[layout]) == "table" and saved.barPins[layout] or {}
    local pins, wrote = saved.barPins[layout], false
    for _, system in ipairs(Gather(true)) do
        ToBottom(system)
        if Record(editor, system, pins) then wrote = true end
    end
    local totem = PlaceTotem()
    if totem and Record(editor, totem, pins) then wrote = true end
    wrote = CapsHome() or wrote
    if wrote then pcall(editor.SaveLayouts, editor) end
    saved.pinShape = true
    return wrote
end

-- Each frame to pin, with the anchor that keeps it where the band has it
-- (bottom-left to UIParent's BOTTOM), for the shared options code's "EraUI"
-- layout.
local function PinAnchors()
    local records, across = {}, Number(UIParent:GetWidth())
    if not across then return records end
    for _, system in ipairs(Gather(true)) do
        local left, bottom, own = Number(system:GetLeft()), Number(system:GetBottom()), Number(system:GetScale())
        if left and bottom and own and own > 0 then
            records[#records + 1] = { name = system:GetName(), system = system.system, systemIndex = system.systemIndex,
                anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM",
                    offsetX = (left - across / 2 / own) * own, offsetY = bottom * own } }
        end
    end
    local totem, x, y = TotemToPin(), TotemSpot()
    if totem and x then
        records[#records + 1] = { name = TOTEM, system = totem.system, systemIndex = totem.systemIndex,
            anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = x, offsetY = y } }
    end
    return records
end

-- With Action Bars off: the bars back in Blizzard's default places, once.
local function Unpin()
    if not ns.sessionEnding or Look.InFight() or not Asks(ns.LayoutWritable) then return false end
    local editor = EditModeManagerFrame
    if not editor or type(editor.SaveLayouts) ~= "function" then return false end
    local saved, eraLayout, wrote = ns.db, Asks(ns.ClassicLayoutActive), false
    for _, kind in ipairs(HANDED_BACK) do
        local system = _G[kind]
        if EditSystem(system) and Look.InDefaultPosition(system) == false
            and (eraLayout or Look.PinnedByEraUI(system)) and pcall(system.ResetToDefaultPosition, system) then
            wrote = true
        end
    end
    wrote = CapsHome() or wrote
    local layout = Look.LayoutName()
    if layout and type(saved.barPins) == "table" then saved.barPins[layout] = nil end
    saved.barDragged, saved.bandHandedBack = false, true
    if wrote then
        if type(editor.UpdateActionBarPositions) == "function" then pcall(editor.UpdateActionBarPositions, editor) end
        pcall(editor.SaveLayouts, editor)
    end
    return wrote
end

-- The "adopt" layout job: in the "EraUI" layout, every pin-list frame back to
-- its default so the band takes it again. Returns how many. Like every
-- layout write here, only as the session ends (Edit Mode's reset from addon
-- code mid-session would leave EraUI's taint on its snap records).
local function Adopt()
    if not ns.sessionEnding or Look.InFight() or not band.active or not Asks(ns.ClassicLayoutActive) then return 0 end
    local taken = 0
    for _, kind in ipairs(PINNED_KINDS) do
        local system = _G[kind]
        if EditSystem(system) and Look.InDefaultPosition(system) == false
            and pcall(system.ResetToDefaultPosition, system) then
            taken = taken + 1
        end
    end
    if ns.db then ns.db.barDragged = false end
    if Look.RunBandLayout then Look.RunBandLayout() end
    return taken
end

local function OneDecimal(value)
    local n = Number(value)
    return n and string.format("%.1f", n) or "?"
end

local function Describe()
    local frame = band.frame
    if not frame then return "not built" end
    return ("art shown=%s left=%s bottom=%s scale=%s pending=%s"):format(tostring(frame:IsShown()),
        OneDecimal(frame:GetLeft()), OneDecimal(frame:GetBottom()), OneDecimal(frame:GetScale()), tostring(band.pending))
end

ns.BandBarsToUnpinned = function() return Gather(false) end
ns.BandBarsToPin = function() return Gather(true) end
ns.PinBandBars, ns.UnpinBandBars, ns.AdoptBandBars = Pin, Unpin, Adopt
ns.BandPinAnchors, ns.ClassicBarInfo = PinAnchors, Describe
