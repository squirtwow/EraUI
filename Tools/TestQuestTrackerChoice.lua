-- Run the actual quest-tracker choice prompt against a fake Questie profile.
-- The prompt must appear only when both trackers are on, sit on the
-- foreground layer above /era, never appear in combat, and change only
-- Questie's tracker on/off preference (never its tracked-quest list).
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat, reloads, timers = false, 0, {}
local Prompt
InCombatLockdown = function() return combat end
-- Like the client: a reload is blocked in combat, or when the clicked window
-- was hidden before the request (it no longer counts as the live click).
ReloadUI = function()
    local prompt = Prompt()
    assert(not combat, "blocked Reload() in combat")
    assert(prompt and prompt.shown, "blocked Reload(): window hidden before the reload request")
    reloads = reloads + 1
end
UnitClass = function() return "Druid", "DRUID" end
RAID_CLASS_COLORS = { DRUID = { r = 1, g = .49, b = .04 } }
UISpecialFrames = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers() local list = timers; timers = {}; for _, fn in ipairs(list) do fn() end end
function hooksecurefunc(target, name, fn)
    local original = target[name]
    target[name] = function(...) local a, b = original(...); fn(...); return a, b end
end

local created = {}
local function Region(parent)
    local r = { parent = parent, shown = true }
    for _, name in ipairs({ "SetPoint", "SetWidth", "SetHeight", "SetJustifyH", "SetTextColor", "SetColorTexture" }) do
        r[name] = function() end
    end
    function r:SetText(text) self.text = text end
    return r
end
local function Frame(parent, name)
    local f = Region(parent)
    f.name, f.scripts, f.events, f.shown = name, {}, {}, true
    for _, method in ipairs({ "SetSize", "SetClampedToScreen", "EnableMouse", "SetMovable", "RegisterForDrag",
        "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor", "StartMoving", "StopMovingOrSizing" }) do
        f[method] = function() end
    end
    function f:SetFrameStrata(strata) self.strata = strata end
    function f:SetToplevel(value) self.toplevel = value end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterEvent(event) self.events[event] = nil end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:Raise() self.raised = (self.raised or 0) + 1 end
    function f:CreateTexture() return Region(self) end
    function f:CreateFontString() return Region(self) end
    function f:Click() if self.scripts.OnClick then self.scripts.OnClick(self) end end
    return f
end
CreateFrame = function(_, name, parent)
    local f = Frame(parent, name)
    created[#created + 1] = f
    return f
end

-- Fake Questie: AceDB-shaped profile and a tracker whose Expand behaves like
-- Questie's header click (ignored in combat).
local questieEnabled = true
local tracked = { [123] = true }
local function NewQuestie(trackerOn, expanded)
    Questie = { db = { profile = { trackerEnabled = trackerOn }, char = { isTrackerExpanded = expanded, TrackedQuests = tracked } } }
    function Questie:IsEnabled() return questieEnabled end
end
local expandCalls = 0
local questieTracker = {}
function questieTracker:Expand()
    expandCalls = expandCalls + 1
    if not InCombatLockdown() and not Questie.db.char.isTrackerExpanded then Questie.db.char.isTrackerExpanded = true end
end
QuestieLoader = { ImportModule = function(_, name) if name == "QuestieTracker" then return questieTracker end end }

-- Fake EraUI settings.
local saved, loaded = {}, {}
local E = { modules = {} }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:CreateCloseX(parent, onClick) local x = CreateFrame("Button", nil, parent); x:SetScript("OnClick", onClick); return x end
function E:GetSavedSetting(key) return saved[key] end
function E:GetSetting(key) if loaded[key] ~= nil then return loaded[key] end return saved[key] end
local function BaseSetSetting(_, key, value) saved[key] = value end

local function Fresh(opts)
    created, timers, reloads, expandCalls, combat = {}, {}, 0, 0, false
    E.SetSetting = BaseSetSetting -- Each load hooks it; start every scenario unhooked.
    -- Setup completion is per character.
    E.Classic = { CharacterSetupComplete = function() return opts.setupComplete ~= false end }
    E.settingsFrame = nil
    saved = { enabled = true, questTracker = opts.classic ~= false, questTrackerChoice = opts.choice or "" }
    loaded = { questTracker = opts.classic ~= false }
    questieEnabled = opts.questieEnabled ~= false
    if opts.questie == false then Questie = nil else NewQuestie(opts.questieTracker ~= false, opts.expanded == true) end
    E.modules = {}
    assert(loadfile("Modules/QuestTrackerChoice.lua"))("EraUI", E)
    local M = E.modules.QuestTrackerChoice
    M:Initialize()
    local events = created[1]
    local function Fire(event) events.scripts.OnEvent(events, event) end
    return M, Fire
end
function Prompt()
    for _, f in ipairs(created) do if f.name == "EraUIQuestTrackerChoice" then return f end end
end
local function Shown() local p = Prompt(); return p ~= nil and p.shown end

-- Login -----------------------------------------------------------------------

local M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD")
Equal(Shown(), false, "waits for Questie to finish loading")
RunTimers()
Equal(Shown(), true, "both trackers on with no choice: asks at login")
local prompt = Prompt()
Equal(prompt.strata, "FULLSCREEN_DIALOG", "prompt sits on the foreground layer above /era")
Equal(prompt.toplevel, true, "prompt comes to the front when clicked")
Equal((prompt.raised or 0) > 0, true, "prompt is raised when shown")
Equal(UISpecialFrames[#UISpecialFrames], "EraUIQuestTrackerChoice", "Escape closes the prompt")
Equal(prompt.classic.note.text:find("Recommended", 1, true) ~= nil, true, "Classic tracker marked recommended")
Equal(prompt.questie.note.text:find("Does not list quests", 1, true) ~= nil, true, "Questie tracker limitation explained")
Fire("PLAYER_ENTERING_WORLD")
RunTimers()
Equal(#timers, 0, "login check runs once per session")

M, Fire = Fresh({ choice = "classic" })
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Equal(Shown(), false, "a saved choice is not asked again at login")

M, Fire = Fresh({ classic = false })
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Equal(Shown(), false, "Classic tracker off: no question")

M, Fire = Fresh({ questie = false })
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Equal(Shown(), false, "Questie not installed: no question")

M, Fire = Fresh({ questieTracker = false })
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Equal(Shown(), false, "Questie's tracker already off: no question")

M, Fire = Fresh({ questieEnabled = false })
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Equal(Shown(), false, "Questie disabled: no question")

-- Combat -------------------------------------------------------------------------

M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD")
combat = true
RunTimers()
Equal(Shown(), false, "never appears in combat")
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(Shown(), true, "appears once combat ends")

-- Turning Quest Tracker on in /era --------------------------------------------------

M, Fire = Fresh({ classic = false, choice = "questie" })
E:SetSetting("questTracker", false)
Equal(Shown(), false, "turning Quest Tracker off does not ask")
E:SetSetting("questTracker", true)
Equal(Shown(), true, "turning Quest Tracker on with Questie's tracker on asks, even after an earlier choice")
Equal(reloads, 0, "asking never reloads by itself")

M, Fire = Fresh({ classic = false, questieTracker = false })
E:SetSetting("questTracker", true)
Equal(Shown(), true, "turning Quest Tracker on asks whenever Questie is installed, even with its tracker off")
Prompt().questie:Click()
Equal(Questie.db.profile.trackerEnabled, true, "choosing Questie turns its tracker on")
Equal(saved.questTracker, false, "and turns EraUI's Classic tracker option off to match")
Equal(reloads, 1, "a tracker that was off only starts after a reload, straight from the click")

M, Fire = Fresh({ classic = false, questieTracker = false })
E:SetSetting("questTracker", true)
combat = true
Prompt().questie:Click()
Equal(reloads, 0, "no reload attempted in combat")
Equal(saved.questTrackerChoice, "", "combat click saves nothing")
Equal(Prompt().footer.text:find("Finish combat", 1, true) ~= nil, true, "explains to finish combat first")
combat = false

M, Fire = Fresh({ classic = false, questie = false })
E:SetSetting("questTracker", true)
Equal(Shown(), false, "turning Quest Tracker on without Questie installed does not ask")

-- Choosing Classic ------------------------------------------------------------------------

M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Prompt().classic:Click()
Equal(saved.questTrackerChoice, "classic", "Classic choice remembered")
Equal(Questie.db.profile.trackerEnabled, false, "Questie's tracker switched off")
Equal(Questie.db.char.TrackedQuests[123], true, "Questie's tracked-quest list is kept")
Equal(reloads, 1, "reloads straight from the click, once")

M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
combat = true
Prompt().classic:Click()
Equal(reloads, 0, "no reload attempted in combat")
Equal(saved.questTrackerChoice, "", "combat click saves nothing")
Equal(Questie.db.profile.trackerEnabled, true, "combat click leaves Questie's tracker on")
Equal(Prompt().footer.text:find("Finish combat", 1, true) ~= nil, true, "explains to finish combat first")
combat = false
Prompt().classic:Click()
Equal(reloads, 1, "the same prompt works once combat ends")

-- Choosing Questie ------------------------------------------------------------------------

M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
local card = { SetChecked = function(self, value) self.checked = value end, checked = true }
E.settingsFrame = { checks = { questTracker = card }, IsShown = function() return true end }
Prompt().questie:Click()
Equal(saved.questTrackerChoice, "questie", "Questie choice remembered")
Equal(Questie.db.profile.trackerEnabled, true, "Questie's tracker stays on")
Equal(saved.questTracker, false, "EraUI's Classic tracker option switched off to match")
Equal(card.checked, false, "the /era Quest Tracker switch shows off")
Equal(expandCalls, 1, "Questie's tracker unfolded through its own Expand")
Equal(Questie.db.char.isTrackerExpanded, true, "Questie's tracker is unfolded")
Equal(reloads, 0, "no reload needed")
Equal(Shown(), false, "prompt closes")

M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
combat = true
Prompt().questie:Click()
Equal(expandCalls, 0, "no header click attempted in combat")
Equal(Questie.db.char.isTrackerExpanded, true, "unfolded state saved for combat choices")
combat = false

-- Closing without choosing ----------------------------------------------------------------

M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Prompt():Hide()
Equal(saved.questTrackerChoice, "", "closing saves no choice")
Equal(Questie.db.profile.trackerEnabled, true, "closing changes nothing in Questie")
M, Fire = Fresh({})
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Equal(Shown(), true, "closed without choosing: asks again next login")

-- Setup walkthrough owns the question -------------------------------------------------------

M, Fire = Fresh({ setupComplete = false })
Fire("PLAYER_ENTERING_WORLD"); RunTimers()
Equal(Shown(), false, "players who have not finished setup are asked there, not at login")

M, Fire = Fresh({ classic = false })
E.settingsFrame = { setupMode = true, IsShown = function() return true end }
E:SetSetting("questTracker", true)
Equal(Shown(), false, "no pop-up over the setup walkthrough")

-- The walkthrough's API: no reloads, reload need reported ---------------------------------

M, Fire = Fresh({ classic = false })
Equal(M:QuestieInstalled(), true, "detects Questie")
Equal(M:NeedsReload(), false, "nothing to reload before a choice")
M:SetChoice("classic")
Equal(saved.questTracker, true, "Classic choice turns the Classic tracker on")
Equal(Shown(), false, "turning it on from a choice does not ask again")
Equal(Questie.db.profile.trackerEnabled, false, "Classic choice switches Questie's tracker off")
Equal(M:NeedsReload(), true, "Classic choice needs a reload")
Equal(reloads, 0, "SetChoice itself never reloads")
M:SetChoice("questie")
Equal(M:NeedsReload(), false, "switching back to Questie needs no reload")
Equal(M:CurrentChoice(), "questie", "latest choice is reported")

M, Fire = Fresh({ questieTracker = false })
M:SetChoice("questie")
Equal(Questie.db.profile.trackerEnabled, true, "Questie choice turns Questie's tracker back on")
Equal(expandCalls, 0, "a tracker that is not running yet is not clicked")
Equal(Questie.db.char.isTrackerExpanded, true, "it will load unfolded")
Equal(M:NeedsReload(), true, "turning Questie's tracker on needs a reload")

-- An old Questie choice is forgotten when the Classic tracker comes back
-- without Questie's tracker.
M, Fire = Fresh({ classic = false, choice = "questie", questieTracker = false })
E:SetSetting("questTracker", true)
Equal(saved.questTrackerChoice, "", "old Questie choice cleared once its tracker is off")
M, Fire = Fresh({ classic = false, choice = "questie", questie = false })
E:SetSetting("questTracker", true)
Equal(saved.questTrackerChoice, "", "old Questie choice cleared once Questie is gone")
Equal(Shown(), false, "and no prompt without Questie")
M, Fire = Fresh({ classic = false, choice = "questie" })
E:SetSetting("questTracker", true)
Equal(saved.questTrackerChoice, "questie", "a live Questie tracker keeps the choice until the prompt is answered")
Equal(Shown(), true, "the prompt asks again")

-- An open /era is refreshed after a choice.
M, Fire = Fresh({})
local refreshed = 0
E.settingsFrame = { checks = {}, IsShown = function() return true end, RefreshHint = function() refreshed = refreshed + 1 end }
M:SetChoice("questie")
Equal(refreshed, 1, "an open /era refreshes its reload hint and preset label")

M, Fire = Fresh({ questie = false })
Equal(M:QuestieInstalled(), false, "no Questie detected")
M:SetChoice("classic")
Equal(saved.questTrackerChoice, "", "no choice saved without Questie")

print("Quest tracker choice checks passed: " .. checks .. " assertions.")
