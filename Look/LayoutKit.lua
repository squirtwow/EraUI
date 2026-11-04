-- The "EraUI" Edit Mode layout: the questions the band asks (is the active
-- layout writable, is it EraUI's), the layout jobs queued for the next
-- Classic reload, the reload ask, and the requests that queue them (make or
-- switch to the EraUI layout, go back to the earlier one, reset it, fit the
-- bars to the button size). Every Edit Mode layout write happens only as the
-- session ends (Look/LayoutJobs.lua), never in the middle of one.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local Lay = {}
Look.Layout = Lay

Lay.NAME = "EraUI"
Lay.POPUP_RELOAD = "ERAUI_CLASSIC_LAYOUT_RELOAD"
Lay.POPUP_EDIT = "ERAUI_CLASSIC_EDIT_WROTE"
Lay.POPUP_QUESTION = "ERAUI_CLASSIC_LAYOUT_QUESTION"
-- The bars the button size changes, with their count at the larger size.
Lay.FIT = { { "MainActionBar", 10 }, { "MultiBarBottomLeft", 10 }, { "MultiBarRight", 8 }, { "MultiBarLeft", 8 } }

function Lay.Say(text)
    if type(ns.Print) == "function" then ns.Print(text) end
end

local function Popup(name, text, accept, yes, no)
    if type(StaticPopupDialogs) ~= "table" then return end
    StaticPopupDialogs[name] = { text = text, button1 = yes, button2 = no, OnAccept = accept, timeout = 0,
        whileDead = true, hideOnEscape = true, preferredIndex = 3 }
end

local function ReloadNow()
    if type(ns.ReloadForLayout) == "function" then ns.ReloadForLayout() end
end

local NOW_WORD, LATER_WORD = RELOADUI or "Reload Now", LATER or "Later"
Popup(Lay.POPUP_RELOAD, "EraUI: %s. It's done as the interface reloads.", ReloadNow, NOW_WORD, LATER_WORD)
Popup(Lay.POPUP_EDIT, "EraUI made a change for you in Edit Mode. Reload to finish it; until then the action bars can error in a fight.",
    ReloadNow, NOW_WORD, LATER_WORD)
Popup(Lay.POPUP_QUESTION,
    "EraUI: set up the classic layout now? It adds an Edit Mode layout called EraUI with everything in its 1.x place and switches to it. Your own layout and keybinds stay in the list. The interface reloads.",
    function() Lay.Create(true) end, "Set up and reload", "Keep my layout")

---------------------------------------------------------------------------
-- Questions
---------------------------------------------------------------------------

function Lay.Manager()
    local editor = EditModeManagerFrame
    return type(editor) == "table" and editor or nil
end

function Lay.Active()
    local fine, layout = Look.Ask(Lay.Manager(), "GetActiveLayoutInfo")
    return fine and type(layout) == "table" and layout or nil
end

-- Edit Mode's "number of icons" setting, or nil on a client without it.
function Lay.IconSetting()
    local settings = Enum and Enum.EditModeActionBarSetting
    return settings and settings.NumIcons
end

-- The active layout isn't one of the game's presets (unknown: no).
local function Writable()
    local layout, kinds = Lay.Active(), Enum and Enum.EditModeLayoutType
    if layout == nil or kinds == nil or kinds.Preset == nil then return false end
    return layout.layoutType ~= kinds.Preset
end

function Lay.Ours()
    local layout = Lay.Active()
    return layout ~= nil and layout.layoutName == Lay.NAME
end

-- Every layout the manager knows, or nil.
function Lay.Layouts()
    local fine, layouts = Look.Ask(Lay.Manager(), "GetLayouts")
    return fine and type(layouts) == "table" and layouts or nil
end

-- The index (and record) of the layout with that name, any kind unless
-- notPreset.
function Lay.Find(name, notPreset)
    local kinds = Enum and Enum.EditModeLayoutType
    local presetKind = kinds and kinds.Preset
    for where, record in ipairs(Lay.Layouts() or {}) do
        if type(record) == "table" and record.layoutName == name then
            if not (notPreset and record.layoutType == presetKind) then return where, record end
        end
    end
    return nil
end

function Lay.Maxed()
    local fine, full = Look.Ask(Lay.Manager(), "AreLayoutsFullyMaxed")
    return fine and full == true
end

---------------------------------------------------------------------------
-- Jobs and the reload ask
---------------------------------------------------------------------------

function Lay.Queue(name, value)
    local saved = ns.db
    if saved == nil then return end
    if type(saved.layoutJobs) ~= "table" then saved.layoutJobs = {} end
    saved.layoutJobs[name] = value
end

function Lay.Jobs()
    local queued = ns.db and ns.db.layoutJobs
    return type(queued) == "table" and queued or nil
end

function Lay.Ask(reason)
    if StaticPopup_Show then StaticPopup_Show(Lay.POPUP_RELOAD, reason) end
end

local function ReloadOrAsk(reloadNow, reason)
    if reloadNow then ReloadNow() else Lay.Ask(reason) end
end

local FIGHT_LINE, MISSING_LINE = "Layouts can't change in combat.", "Edit Mode layouts aren't available."

---------------------------------------------------------------------------
-- Requests
---------------------------------------------------------------------------

-- Each listed bar's icon count, by its Edit Mode index (the larger size's
-- counts with Default interface bar size on).
local COUNTED = Look.Words("MainActionBar MultiBarBottomLeft MultiBarBottomRight MultiBarRight MultiBarLeft MultiBar5 MultiBar6 MultiBar7")
local function IconCounts()
    local found, setting, larger = {}, Lay.IconSetting(), {}
    local bigger = ns.db and ns.db.defaultBarSize == true
    for _, pair in ipairs(Lay.FIT) do larger[pair[1]] = pair[2] end
    for _, barName in ipairs(COUNTED) do
        local system = _G[barName]
        local slot = type(system) == "table" and Look.Number(system.systemIndex)
        if slot then
            local icons = Look.EditSetting(system, setting)
            if icons and icons >= 1 and icons <= 12 then found[slot] = icons end
            if bigger and larger[barName] then found[slot] = larger[barName] end
        end
    end
    return found
end

function Lay.Create(reloadNow)
    if Look.InFight() then return Lay.Say(FIGHT_LINE) end
    local editor, api = Lay.Manager(), C_EditMode
    if not editor or type(editor.GetLayouts) ~= "function" or type(EditModePresetLayoutManager) ~= "table"
        or type(api) ~= "table" or not api.SaveLayouts then
        return Lay.Say(MISSING_LINE)
    end
    local already = Lay.Find(Lay.NAME, true) ~= nil
    if not already and Lay.Maxed() then return Lay.Say("Edit Mode has no room for another layout. Delete one first.") end
    local saved, active = ns.db, Lay.Active()
    local activeName = active and active.layoutName
    if saved and type(activeName) == "string" and activeName ~= Lay.NAME then saved.previousLayout = activeName end
    Lay.Queue("classic", { counts = IconCounts() })
    if saved then saved.layoutPrompted = true end
    ReloadOrAsk(reloadNow, already and "switching to your EraUI layout" or "setting up the EraUI layout")
end

local function BackToPrevious()
    if Look.InFight() then return Lay.Say(FIGHT_LINE) end
    local earlier = ns.db and ns.db.previousLayout
    if type(earlier) ~= "string" or earlier == "" then
        return Lay.Say("No earlier layout was written down. Pick one in Edit Mode.")
    end
    local api = C_EditMode
    if not Lay.Manager() or type(api) ~= "table" or not api.SetActiveLayout then return Lay.Say(MISSING_LINE) end
    if not Lay.Find(earlier) then return Lay.Say("Your " .. earlier .. " layout is gone.") end
    Lay.Queue("previous", earlier)
    Lay.Ask("switching back to your " .. earlier .. " layout")
    return true
end

local function ResetOurs(reloadNow)
    if Look.InFight() then return Lay.Say(FIGHT_LINE) end
    if Lay.Ours() then
        Lay.Queue("reset", true)
        ReloadOrAsk(reloadNow, "the EraUI layout goes back to its defaults")
    end
end

-- With the EraUI layout active: the bars whose icon count isn't the one for
-- this size are queued to change at the next reload. True when queued.
local function FitToSize(big)
    if Lay.Ours() ~= true then return false end
    local setting, mismatch = Lay.IconSetting(), false
    for _, pair in ipairs(Lay.FIT) do
        local system = _G[pair[1]]
        local target = big and pair[2] or 12
        if type(system) == "table" and system.system ~= nil and Look.EditSetting(system, setting) ~= target then mismatch = true end
    end
    if not mismatch then
        local queued = Lay.Jobs()
        if queued then queued.fit = nil end
        return false
    end
    Lay.Queue("fit", big and "big" or "normal")
    Lay.Ask(big and "the bars go to ten and eight icons to fit the larger bar" or "the bars go back to twelve icons")
    return true
end

-- The first-login question (off Forever, and from /eraui-classic prompt):
-- asked once, never while the EraUI layout is already active.
local function FirstLoginQuestion()
    local saved = ns.db
    if saved == nil or saved.classicBar == false then return end
    saved.layoutWarned = nil
    if saved.layoutPrompted then return end
    saved.layoutPrompted = true
    if not Lay.Ours() and StaticPopup_Show then StaticPopup_Show(Lay.POPUP_QUESTION) end
end

-- Once (the engine calls it at login): when Edit Mode closes after the band
-- wrote one of its settings for the player, offer the reload that finishes it.
local watching = false
local function EditModeChanged()
    if Look.EditModeOpen() or not ns.editWrote then return end
    ns.editWrote = nil
    if StaticPopup_Show then StaticPopup_Show(Lay.POPUP_EDIT) end
end
local function WatchWrites()
    if watching or type(ns.OnEditMode) ~= "function" then return end
    watching = true
    ns.OnEditMode(EditModeChanged)
end

ns.LayoutWritable, ns.ClassicLayoutActive, ns.QueueLayoutJob, ns.AskLayoutReload = Writable, Lay.Ours, Lay.Queue, Lay.Ask
ns.CreateClassicLayout, ns.RestorePreviousLayout, ns.ResetClassicLayout = Lay.Create, BackToPrevious, ResetOurs
ns.FitBarsToSize, ns.CheckLayoutPosition, ns.WatchEditWrites = FitToSize, FirstLoginQuestion, WatchWrites
