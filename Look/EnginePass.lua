-- EraUI's Classic engine, part two: the ordered list of look parts and the
-- pass that puts each one on (or takes it off when its setting is off), the
-- Edit Mode watch, the record of calls the game refused, the toggles, the one
-- guarded way to write a game setting, the reload question, and the timing at
-- login, entering the world and logout.
--
-- Every call to the pass, the save and the toggle goes through the
-- namespace, never a private copy: Core/Integration.lua replaces those three
-- (and OpenOptions and FirstRun) with wrappers as it loads, and the wrappers
-- must run at login, for a queued pass, after a fight and at logout.
local ADDON, EraUI = ...
local ns = EraUI.Classic

local Protected = ns.SafeCall
local RELOAD_QUESTION = "ERAUICLASSIC_RELOAD"

-- The game's own floating damage numbers live in two settings.
local DAMAGE_SETTINGS = {}
for name in ("floatingCombatTextCombatDamage floatingCombatTextCombatDamage_v2"):gmatch("%S+") do
    DAMAGE_SETTINGS[#DAMAGE_SETTINGS + 1] = name
end

local engine = { ready = false, afterFight = false, queued = false, worldSeen = false }

local function Hidden(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

local function InFight()
    return type(InCombatLockdown) == "function" and InCombatLockdown() and true or false
end

local function EraUIOn()
    if type(EraUI.GetSetting) ~= "function" then return true end
    return EraUI:GetSetting("enabled") ~= false
end

local function EditModeOpen()
    local editor = EditModeManagerFrame
    if type(editor) ~= "table" or type(editor.IsEditModeActive) ~= "function" then return false end
    local fine, open = pcall(editor.IsEditModeActive, editor)
    return fine and open == true
end

---------------------------------------------------------------------------
-- The look's parts, in .toc order (the band lays out before the page arrows
-- restyle it; the button art goes on after the band scaled the buttons).
-- An entry is { apply, restore, init (optional) }; a key may be registered
-- twice (the band and the page arrows are both classicBar). Only a saved
-- false switches an entry off: no saved value counts as on.
---------------------------------------------------------------------------

local parts, results = {}, {}

local function Register(key, entry)
    entry.key = key
    parts[#parts + 1] = entry
end

-- One part, put on or taken off. Only putting on leaves a result.
local function Visit(saved, entry)
    if saved[entry.key] == false then
        if type(entry.restore) == "function" then Protected(entry.restore) end
        return
    end
    if type(entry.apply) ~= "function" then return end
    local ok, problem = Protected(entry.apply)
    results[entry.key] = { ok = ok, error = (not ok) and tostring(problem) or nil }
end

-- One pass over every part. In a fight it is kept for the fight's end (the
-- way other files book a pass: they call this in a fight). Each restore
-- runs on every pass while its part is off, so each must be cheap to repeat.
local function Pass()
    local saved = ns.db
    if not saved or not engine.ready or not EraUIOn() then return end
    if InFight() then
        engine.afterFight = true
        return
    end
    for _, entry in ipairs(parts) do Visit(saved, entry) end
    ns.MirrorSave()
end

-- At most one pass a frame: the first ask books it for the next frame.
local function QueuedPass()
    engine.queued = false
    ns.ApplyAll()
end

local function Queue()
    if engine.queued then return end
    engine.queued = true
    if C_Timer and C_Timer.After then C_Timer.After(0, QueuedPass) else QueuedPass() end
end

---------------------------------------------------------------------------
-- Edit Mode is watched, never hooked: asking the manager whether it is open
-- leaves its own passes alone (party and raid frames are laid out inside
-- them). One frame looks every 0.1 s once anything wants to know.
---------------------------------------------------------------------------

local editWatch = { told = {}, open = false, waited = 0 }

local function EditModeLook(_, elapsed)
    editWatch.waited = editWatch.waited + (elapsed or 0)
    if editWatch.waited < 0.1 then return end
    editWatch.waited = 0
    local open = EditModeOpen()
    if open == editWatch.open then return end
    editWatch.open = open
    for _, tell in ipairs(editWatch.told) do Protected(tell, open) end
end

local function WatchEditMode(fn)
    if type(fn) ~= "function" then return false end
    table.insert(editWatch.told, fn)
    if not editWatch.frame then
        editWatch.open = EditModeOpen()
        editWatch.frame = CreateFrame("Frame")
        editWatch.frame:SetScript("OnUpdate", EditModeLook)
    end
    return true
end

---------------------------------------------------------------------------
-- What the game refused this addon (blocked or forbidden), newest first,
-- the last five: read by /era audit, the status report and the debug
-- report.
---------------------------------------------------------------------------

local refusals = {}

local function Refused(event, who, what)
    if who ~= ADDON then return end
    local note = { event = event, func = Hidden(what) and "?" or tostring(what), combat = InFight(), editMode = EditModeOpen() }
    note.time = type(date) == "function" and date("%H:%M:%S") or "?"
    table.insert(refusals, 1, note)
    while #refusals > 5 do table.remove(refusals) end
    if type(ns.OfferStatus) == "function" then Protected(ns.OfferStatus) end
end

---------------------------------------------------------------------------
-- Game settings (CVars)
---------------------------------------------------------------------------

local function Settings()
    local cvars = C_CVar
    if type(cvars) ~= "table" or type(cvars.GetCVar) ~= "function" then return nil end
    return cvars
end

-- A game setting's text, or nil when it can't be read.
local function ReadSetting(cvars, name)
    local fine, now = pcall(cvars.GetCVar, name)
    if not fine or now == nil or Hidden(now) then return nil end
    return tostring(now)
end

-- The one guarded way the Classic look writes a game setting. Never in a
-- fight (the game refuses guarded ones then), never the value it already
-- has (the game refuses that too). The value from before EraUI first
-- changed it is kept (cvarWas), so turning EraUI off can hand it back.
-- True when the setting holds the value.
local function WriteSetting(name, value)
    local cvars = Settings()
    if name == nil or value == nil or InFight() or not cvars or type(cvars.SetCVar) ~= "function" then return false end
    local before = ReadSetting(cvars, name)
    if before == tostring(value) then return true end
    local saved = ns.db
    if before ~= nil and saved and not ns.handingBack then
        if type(saved.cvarWas) ~= "table" then saved.cvarWas = {} end
        if saved.cvarWas[name] == nil then saved.cvarWas[name] = before end
    end
    local wrote, answer = pcall(cvars.SetCVar, name, value)
    return wrote and answer ~= false
end

-- The game's damage numbers read into gameDamageNumbers: on when either of
-- its two settings is on; left as it was when neither can be read.
local function ReadDamageNumbers()
    local saved, cvars = ns.db, Settings()
    if not saved or not cvars then return end
    local readAny, on = false, false
    for _, setting in ipairs(DAMAGE_SETTINGS) do
        local text = ReadSetting(cvars, setting)
        if text ~= nil then
            readAny = true
            on = on or text == "1"
        end
    end
    if readAny then saved.gameDamageNumbers = on end
end

-- Both of the game's damage-number settings, written straight.
local function WriteDamageNumbers(on)
    local cvars = Settings()
    if not cvars or type(cvars.SetCVar) ~= "function" then return end
    for _, setting in ipairs(DAMAGE_SETTINGS) do pcall(cvars.SetCVar, setting, on and "1" or "0") end
end

---------------------------------------------------------------------------
-- Toggles and the reload question
---------------------------------------------------------------------------

local function ReloadNow()
    if type(ns.ReloadForLayout) == "function" then return ns.ReloadForLayout() end
    if C_UI and C_UI.Reload then C_UI.Reload() elseif ReloadUI then ReloadUI() end
end

-- The question asked when a part that leaves old art behind is turned off.
if type(StaticPopupDialogs) == "table" then
    local question = { timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3, OnAccept = ReloadNow }
    question.text = "Some of the old art stays on screen until the interface reloads."
    question.button1, question.button2 = RELOADUI or "Reload Now", LATER or "Later"
    StaticPopupDialogs[RELOAD_QUESTION] = question
end

-- What a few switches also change in the game itself.
local SIDE_EFFECTS = {
    gameDamageNumbers = function(saved) WriteDamageNumbers(saved.gameDamageNumbers) end,
    defaultBarSize = function(saved)
        if type(ns.FitBarsToSize) == "function" then Protected(ns.FitBarsToSize, saved.defaultBarSize == true) end
    end,
    oneBag = function(saved) ns.SetCVar("combinedBags", saved.oneBag and "1" or "0") end,
}

-- After an option list or a slash command wrote ns.db[key]: the game
-- settings a few switches mirror, a pass, the option list again, and the
-- reload question when a part that leaves art behind went off.
local function Toggled(key)
    local saved = ns.db
    if saved == nil then return end
    local extra = SIDE_EFFECTS[key]
    if extra then extra(saved) end
    ns.ApplyAll()
    if type(ns.RefreshOptionsWindow) == "function" then ns.RefreshOptionsWindow() end
    local wentOff = ns.RELOAD_KEYS[key] and saved[key] == false
    if wentOff and type(StaticPopup_Show) == "function" then StaticPopup_Show(RELOAD_QUESTION) end
end

---------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------

-- A pass on the next frame, through whatever QueueApply is by then.
local function PassSoon()
    ns.QueueApply()
end

-- After Core/Init.lua's own login (EraUI's modules already set up).
local function LoggedIn()
    if not EraUIOn() then return end
    engine.ready = true
    ns.ReadGameDamageNumbers()
    local saved = ns.db
    for _, entry in ipairs(parts) do
        if saved and saved[entry.key] ~= false and type(entry.init) == "function" then Protected(entry.init) end
    end
    ns.ApplyAll()
    ns.OnEditMode(PassSoon)
    if type(ns.WatchEditWrites) == "function" then Protected(ns.WatchEditWrites) end
end

-- The first time into the world only: three seconds on, the EraUI layout
-- picked if one was waiting, then the first run (the welcome, the /era
-- hint and What's New, through Core/Integration.lua). Even with EraUI
-- turned off: the first run checks that itself.
local function FirstRunLater()
    if type(ns.SelectClassicLayoutIfPending) == "function" then Protected(ns.SelectClassicLayoutIfPending) end
    if type(ns.FirstRun) == "function" then Protected(ns.FirstRun) end
end

local function EnteredWorld()
    PassSoon()
    if engine.worldSeen then return end
    engine.worldSeen = true
    if type(ns.FirstRun) ~= "function" then return end
    if C_Timer and C_Timer.After then C_Timer.After(3, FirstRunLater) else FirstRunLater() end
end

-- The last save, then, if EraUI is off for the next load, every game
-- setting and the layout it changed handed back: the last EraUI code to
-- run before a disable takes effect.
local function LoggingOut()
    ns.MirrorSave()
    if type(ns.BeingTurnedOff) ~= "function" or type(ns.HandBack) ~= "function" then return end
    local fine, off = pcall(ns.BeingTurnedOff)
    if fine and off == true then Protected(ns.HandBack) end
end

local function FightOver()
    if not engine.afterFight then return end
    engine.afterFight = false
    ns.ApplyAll()
end

local ON_EVENT = {
    PLAYER_LOGIN = LoggedIn,
    PLAYER_ENTERING_WORLD = EnteredWorld,
    PLAYER_LOGOUT = LoggingOut,
    UI_SCALE_CHANGED = PassSoon,
    DISPLAY_SIZE_CHANGED = PassSoon,
    PLAYER_REGEN_ENABLED = FightOver,
}

local timing = CreateFrame("Frame")
for event in pairs(ON_EVENT) do pcall(timing.RegisterEvent, timing, event) end
pcall(timing.RegisterEvent, timing, "ADDON_ACTION_BLOCKED")
pcall(timing.RegisterEvent, timing, "ADDON_ACTION_FORBIDDEN")
timing:SetScript("OnEvent", function(_, event, ...)
    local run = ON_EVENT[event]
    if run then return run() end
    Refused(event, ...)
end)

-- The AddOns compartment's EraUI entry (named in the .toc): EraUI's
-- settings, through whatever OpenOptions is by then.
local function CompartmentClicked()
    if type(ns.OpenOptions) == "function" then ns.OpenOptions() end
end

-- The public names. ApplyAll, MirrorSave (Look/Engine.lua) and
-- ToggleChanged are the ones Core/Integration.lua wraps.
ns.modules, ns.applyResults, ns.blocked = parts, results, refusals
ns.RegisterModule, ns.ApplyAll, ns.QueueApply = Register, Pass, Queue
ns.OnEditMode, ns.ToggleChanged = WatchEditMode, Toggled
ns.SetCVar, ns.ReadGameDamageNumbers = WriteSetting, ReadDamageNumbers
EraUIClassic_OnAddonCompartmentClick = CompartmentClicked
