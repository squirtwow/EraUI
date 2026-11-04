-- The layout jobs, run only as a Classic reload ends the session
-- (ns.ReloadForLayout): before the band pins its bars (reset, adopt, fit),
-- then after (previous, classic, select), then the queue is emptied. Also
-- making or refreshing the "EraUI" layout itself, putting the player,
-- target and focus frames on their 1.x spots (through their plain ...Base
-- methods, only here), and the check, 3 seconds after the first world
-- entry, that the switch to the EraUI layout took.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Lay = Look.Layout

-- (The shaman's totem bar too: back to default here, the band's pins then
-- put it over the small row again, Look/BandPins.lua.)
local RESET_FRAMES = Look.Words([[MainActionBar MainMenuBar MultiBarBottomLeft MultiBarBottomRight MultiBarRight
    MultiBarLeft StanceBar PetActionBar PossessActionBar MainStatusTrackingBarContainer SecondaryStatusTrackingBarContainer
    BagsBar MicroMenuContainer MultiCastActionBarFrame]])
-- Player, target and focus: their 1.x top-left offsets from the screen's.
local SPOTS = { { "PlayerFrame", 4, -4 }, { "TargetFrame", 250, -4 }, { "FocusFrame", 250, -165 } }

local function Saving()
    local editor = Lay.Manager()
    if editor and type(editor.SaveLayouts) == "function" then Look.Try(editor.SaveLayouts, editor) end
end

local function RunPass()
    if type(ns.ApplyAll) == "function" then ns.ApplyAll() end
end

-- A frame's own scale (1 when it can't be read or makes no sense).
local function ScaleOf(frame)
    local own = Look.Number(frame:GetScale())
    return (own and own > 0) and own or 1
end

---------------------------------------------------------------------------
-- The unit frames' 1.x spots (part of a layout reset)
---------------------------------------------------------------------------

local function OnSpot(unitFrame, x, y)
    local point, relative, relativePoint, ax, ay = unitFrame:GetPoint(1)
    local k = ScaleOf(unitFrame)
    ax, ay = Look.Number(ax), Look.Number(ay)
    if point ~= "TOPLEFT" or relativePoint ~= "TOPLEFT" or relative ~= UIParent or not ax or not ay then return false end
    return math.abs(ax - x / k) <= 0.5 and math.abs(ay - y / k) <= 0.5
end

local function FrameSpots()
    if ns.sessionEnding ~= true or Look.InFight() or not Lay.Ours() then return false end
    local editor = Lay.Manager()
    if not editor or type(editor.UpdateSystemAnchorInfo) ~= "function" or type(editor.SaveLayouts) ~= "function" then
        return false
    end
    local anyMoved = false
    for _, spot in ipairs(SPOTS) do
        local unitFrame = _G[spot[1]]
        if type(unitFrame) == "table" and unitFrame.system ~= nil and not OnSpot(unitFrame, spot[2], spot[3]) then
            local k = ScaleOf(unitFrame)
            Look.ClearPoints(unitFrame)
            Look.AddPoint(unitFrame, "TOPLEFT", UIParent, "TOPLEFT", spot[2] / k, spot[3] / k)
            Look.Try(editor.UpdateSystemAnchorInfo, editor, unitFrame)
            anyMoved = true
        end
    end
    if anyMoved then
        Saving()
        Lay.Say("The player, target and focus frames moved to their 1.x spots.")
    end
    return anyMoved
end

---------------------------------------------------------------------------
-- Before the band pins
---------------------------------------------------------------------------

local function ResetJob(saved)
    if Look.InFight() or not Lay.Ours() then return end
    saved.microPos, saved.microScale = nil, nil
    if type(ns.MirrorSave) == "function" then Look.Try(ns.MirrorSave) end
    saved.barDragged, saved.barOffsetX, saved.barOffsetY = false, nil, nil
    for _, name in ipairs(RESET_FRAMES) do
        local system = _G[name]
        if type(system) == "table" and system.system ~= nil and Look.InDefaultPosition(system) == false then
            Look.Ask(system, "ResetToDefaultPosition")
        end
    end
    local pins = saved.barPins
    if type(pins) == "table" then pins[Lay.NAME] = nil end
    RunPass()
    FrameSpots()
    Saving()
end

local function AdoptJob()
    if type(ns.AdoptBandBars) == "function" then Look.Try(ns.AdoptBandBars) end
end

local function FitJob(_, size)
    if not Lay.Ours() then return end
    local editor, setting = Lay.Manager(), Lay.IconSetting()
    if not editor or type(editor.OnSystemSettingChange) ~= "function" or setting == nil then return end
    local changed = false
    for _, pair in ipairs(Lay.FIT) do
        local bar = _G[pair[1]]
        local wanted = (size == "big") and pair[2] or 12
        if type(bar) == "table" and bar.system ~= nil and Look.EditSetting(bar, setting) ~= wanted
            and Look.Try(editor.OnSystemSettingChange, editor, bar, setting, wanted) then
            changed = true
        end
    end
    if changed then
        Saving()
        RunPass()
    end
end

-- Each job, in this order, cleared as it runs.
local BEFORE = { { "reset", ResetJob }, { "adopt", AdoptJob }, { "fit", FitJob } }

local function BeforePin()
    if ns.sessionEnding ~= true then return end
    local jobs, saved = Lay.Jobs(), ns.db
    if jobs == nil or saved == nil then return end
    for _, job in ipairs(BEFORE) do
        local value = jobs[job[1]]
        if value then
            jobs[job[1]] = nil
            Look.Try(job[2], saved, value)
        end
    end
end

---------------------------------------------------------------------------
-- The EraUI layout's data
---------------------------------------------------------------------------

-- A system's setting value, in either shape the layout data may use: a
-- list of { setting, value } records (Edit Mode's own), or value by setting.
local function SetSetting(system, setting, value)
    if type(system.settings) ~= "table" then system.settings = {} end
    local settings = system.settings
    local records = next(settings) == nil
    for _, record in pairs(settings) do
        if type(record) == "table" then
            records = true
            if record.setting == setting then
                record.value = value
                return
            end
        end
    end
    if records then settings[#settings + 1] = { setting = setting, value = value } else settings[setting] = value end
end

-- One anchor for a system, its second one gone, out of its default spot.
local function Anchor(system, point, relativeTo, relativePoint, x, y)
    system.anchorInfo, system.anchorInfo2, system.isInDefaultPosition =
        { point = point, relativeTo = relativeTo, relativePoint = relativePoint, offsetX = x, offsetY = y }, nil, false
end

local function KeepPin(name, at)
    local saved = ns.db
    if type(saved.barPins) ~= "table" then saved.barPins = {} end
    local ours = saved.barPins[Lay.NAME]
    if type(ours) ~= "table" then
        ours = {}
        saved.barPins[Lay.NAME] = ours
    end
    ours[name] = { at.point, at.relativePoint, at.offsetX, at.offsetY }
end

local function Pinned(name)
    local pins = type(ns.db.barPins) == "table" and ns.db.barPins[Lay.NAME]
    return type(pins) == "table" and pins[name] ~= nil
end

local function UnitSpot(system, units)
    local spots = { [units.Player or -1] = { 4, -4 }, [units.Target or -2] = { 250, -2 }, [units.Focus or -3] = { 250, -165 } }
    local spot = spots[system.systemIndex]
    if spot then Anchor(system, "TOPLEFT", "UIParent", "TOPLEFT", spot[1], spot[2]) end
end

local function DressSystem(system, fresh, counts, pins)
    local kinds = Enum and Enum.EditModeSystem
    if not kinds then return end
    local kind = system.system
    if fresh and kind == kinds.ChatFrame then
        local at = system.anchorInfo
        if type(at) == "table" and at.point == "BOTTOMLEFT" and (Look.Number(at.offsetY) or 0) < 145 then
            Anchor(system, "BOTTOMLEFT", "UIParent", "BOTTOMLEFT", 35, 145)
        end
    end
    local units = Enum.EditModeUnitFrameSystemIndices
    if kind == kinds.UnitFrame and units then UnitSpot(system, units) end
    local barSettings = Enum.EditModeActionBarSetting
    if kind == kinds.ActionBar and barSettings then
        local count = counts and counts[system.systemIndex]
        if count == nil and fresh then count = 12 end
        if count ~= nil and barSettings.NumIcons ~= nil then SetSetting(system, barSettings.NumIcons, count) end
        if fresh and barSettings.AlwaysShowButtons ~= nil then SetSetting(system, barSettings.AlwaysShowButtons, 0) end
    end
    for _, pin in ipairs(pins) do
        local same = pin.system == kind and pin.systemIndex == system.systemIndex
        if same and (fresh or system.isInDefaultPosition or Pinned(pin.name)) then
            local at = pin.anchorInfo
            Anchor(system, at.point, at.relativeTo, at.relativePoint, at.offsetX, at.offsetY)
            KeepPin(pin.name, at)
        end
    end
end

local function DressLayout(layout, fresh, counts)
    local pins = {}
    if type(ns.BandPinAnchors) == "function" then
        local fine, given = pcall(ns.BandPinAnchors)
        if fine and type(given) == "table" then pins = given end
    end
    for _, system in ipairs(type(layout.systems) == "table" and layout.systems or {}) do
        if type(system) == "table" then DressSystem(system, fresh, counts, pins) end
    end
end

-- Where a new account layout goes: after the last account layout, else
-- after the presets.
local function NewIndex(layouts)
    local kinds = Enum and Enum.EditModeLayoutType
    local lastAccount
    for index, layout in ipairs(layouts) do
        if kinds and layout.layoutType == kinds.Account then lastAccount = index end
    end
    if lastAccount then return lastAccount + 1 end
    local meta = Enum and Enum.EditModePresetLayoutsMeta
    return (meta and Look.Number(meta.NumValues) or 2) + 1
end

-- A copy of the game's Classic preset (found by its own index), else the
-- second preset, else the first.
local function Fresh()
    local fine, copies = Look.Ask(EditModePresetLayoutManager, "GetCopyOfPresetLayouts")
    if not fine or type(copies) ~= "table" then return nil end
    local presets = Enum and Enum.EditModePresetLayouts
    local classic = presets and presets.Classic
    for _, layout in ipairs(copies) do
        if type(layout) == "table" and classic ~= nil and layout.layoutIndex == classic then return layout end
    end
    return copies[2] or copies[1]
end

-- The EraUI layout made (or refreshed), saved and made active.
local function BuildLayout(counts)
    local editor = Lay.Manager()
    local info, api = editor and editor.layoutInfo, C_EditMode
    if type(info) ~= "table" or type(info.layouts) ~= "table" or type(api) ~= "table" or type(api.SaveLayouts) ~= "function"
        or type(api.SetActiveLayout) ~= "function" or type(EditModePresetLayoutManager) ~= "table" then
        return
    end
    local index, layout = Lay.Find(Lay.NAME, true)
    if layout then
        DressLayout(layout, false, counts)
        Look.Try(api.SaveLayouts, info)
    else
        if Lay.Maxed() then return end
        layout = Fresh()
        if type(layout) ~= "table" then return end
        DressLayout(layout, true, counts)
        layout.layoutType = Enum and Enum.EditModeLayoutType and Enum.EditModeLayoutType.Account or 1
        layout.layoutName = Lay.NAME
        index = NewIndex(info.layouts)
        table.insert(info.layouts, index, layout)
        Look.Try(api.SaveLayouts, info)
        if type(api.OnLayoutAdded) == "function" then Look.Try(api.OnLayoutAdded, index, true, false) end
    end
    Look.Try(api.SetActiveLayout, index)
    ns.db.layoutSelectPending = true
end

---------------------------------------------------------------------------
-- After the band pins
---------------------------------------------------------------------------

local function Activate(index)
    local api = C_EditMode
    if not index or type(api) ~= "table" or type(api.SetActiveLayout) ~= "function" then return false end
    return (Look.Try(api.SetActiveLayout, index))
end

local function AfterPin()
    if ns.sessionEnding ~= true then return end
    local jobs, saved = Lay.Jobs(), ns.db
    if jobs == nil or saved == nil then return end
    if jobs.previous and Activate(Lay.Find(jobs.previous)) then saved.previousLayout = "" end
    local wanted = jobs.classic
    if wanted then Look.Try(BuildLayout, type(wanted) == "table" and wanted.counts or nil) end
    if jobs.select then Activate((Lay.Find(Lay.NAME, true))) end
    saved.layoutJobs = nil
end

-- The engine's Classic reload: the jobs, the band's pins and the mirror,
-- out of a fight; then the reload (in a fight too, with nothing else run).
local function ReloadAfterJobs()
    local ui = C_UI
    if type(ui) ~= "table" or type(ui.Reload) ~= "function" then return end
    local saved = ns.db
    if saved and not Look.InFight() then
        ns.sessionEnding = true
        Look.Try(BeforePin)
        local bandOn = saved.classicBar ~= false
        if bandOn and type(ns.PinBandBars) == "function" then
            Look.Try(ns.PinBandBars)
        elseif not bandOn and not saved.bandHandedBack and type(ns.UnpinBandBars) == "function" then
            Look.Try(ns.UnpinBandBars)
        end
        Look.Try(AfterPin)
        if type(ns.MirrorSave) == "function" then Look.Try(ns.MirrorSave) end
    end
    ui.Reload()
end

---------------------------------------------------------------------------
-- After the first world entry: did the switch to the EraUI layout take?
---------------------------------------------------------------------------

local function ConfirmSwitch()
    local saved = ns.db
    if saved == nil then return end
    local jobs = Lay.Jobs()
    if jobs and next(jobs) ~= nil then return Lay.Ask("a layout change you asked for is still waiting") end
    if not saved.layoutSelectPending or not Lay.Manager() or Look.InFight() then return end
    if Lay.Ours() or not Lay.Find(Lay.NAME, true) then
        saved.layoutSelectPending, saved.layoutSelectTries = false, 0
        return
    end
    local tries = Look.Number(saved.layoutSelectTries) or 0
    if tries < 1 then
        saved.layoutSelectTries = tries + 1
        Lay.Queue("select", true)
        return Lay.Ask("the EraUI layout is ready; one more reload switches to it")
    end
    -- It still didn't take: one last try at the next Classic reload (never
    -- a layout switch from EraUI's code in the middle of a session).
    saved.layoutSelectPending, saved.layoutSelectTries = false, 0
    Lay.Queue("select", true)
    Lay.Say("The EraUI layout didn't switch on by itself. One more reload tries again, or pick EraUI in Edit Mode.")
    Lay.Ask("switching to your EraUI layout")
end

ns.ApplyClassicFrameSpots, ns.RunLayoutJobsBeforePin, ns.RunLayoutJobsAfterPin = FrameSpots, BeforePin, AfterPin
ns.ReloadForLayout, ns.SelectClassicLayoutIfPending = ReloadAfterJobs, ConfirmSwitch
