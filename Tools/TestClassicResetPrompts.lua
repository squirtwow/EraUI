-- The two older resets ask first too, in EraUI's own reset prompt
-- (Core/Commands.lua): "Reset toggles" on the game's Options > AddOns > EraUI
-- page (and the same button on the old options window), and /eraui-classic
-- reset (/era-classic reset). Runs the real button, the real slash command and
-- the real prompt: the click or the command alone resets nothing; Reset in
-- the prompt does exactly what the old code did (the old code is copied below
-- and run on the same settings, call for call); Cancel, the X and Escape do
-- nothing; a fight refuses like /era reset; closing the page closes its
-- question; the one prompt asks one question at a time; the help and hover
-- text say each asks; no dashes in what a player reads.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat = false
local chat, log = {}, {}
local eraResets, reloads = 0, 0
local created = {}

InCombatLockdown = function() return combat end
UnitClass = function() return "Rogue", "ROGUE" end
RAID_CLASS_COLORS = { ROGUE = { r = 1, g = .96, b = .41 } }
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
GameFontHighlight = { GetFont = function() return "font", 12, "" end }
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
ReloadUI = function() reloads = reloads + 1 end

-- Anything a frame is asked that the test does not care about is a quiet
-- no-op (methods are the capitalised keys); what matters is recorded.
local function Methods(t)
    return setmetatable(t, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() return Methods({}) end end
    end })
end
local function Region(parent)
    local r = Methods({ parent = parent, anchors = {} })
    function r:SetText(text) self.text = text end
    function r:GetText() return self.text end
    function r:SetPoint(...) self.anchors[#self.anchors + 1] = { ... } end
    function r:SetTextColor(...) self.textColour = { ... } end
    function r:SetSize(width, height) self.width, self.height = width, height end
    function r:SetWidth(width) self.width = width end
    function r:SetHeight(height) self.height = height end
    function r:GetWidth() return self.width end
    return r
end
-- Like the client: hiding a frame runs OnHide on it and on every shown frame
-- inside it, and IsShown is the frame's own flag.
local function Fire(frame, event)
    if frame.scripts[event] then frame.scripts[event](frame) end
    for _, fn in ipairs(frame.hooks[event] or {}) do fn(frame) end
end
local function FireDown(frame, event)
    Fire(frame, event)
    for _, child in ipairs(frame.children) do
        if child.shown then FireDown(child, event) end
    end
end
local function Frame(kind, name, parent)
    local f = Region(parent)
    f.kind, f.name, f.scripts, f.hooks, f.children, f.shown = kind, name, {}, {}, {}, true
    if parent and parent.children then parent.children[#parent.children + 1] = f end
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:HookScript(event, fn)
        self.hooks[event] = self.hooks[event] or {}
        table.insert(self.hooks[event], fn)
    end
    function f:IsShown() return self.shown end
    function f:IsVisible()
        return self.shown and (not self.parent or not self.parent.IsVisible or self.parent:IsVisible())
    end
    function f:Show()
        if self.shown then return end
        self.shown = true
        if self:IsVisible() then FireDown(self, "OnShow") end
    end
    function f:Hide()
        if not self.shown then return end
        local was = self:IsVisible()
        self.shown = false
        if was then FireDown(self, "OnHide") end
    end
    function f:SetParent(newParent)
        if self.parent and self.parent.children then
            for i, child in ipairs(self.parent.children) do
                if child == self then table.remove(self.parent.children, i); break end
            end
        end
        self.parent = newParent
        newParent.children[#newParent.children + 1] = self
    end
    function f:SetChecked(on) self.checked = on and true or false end
    function f:GetChecked() return self.checked end
    function f:SetEnabled(on) self.enabled = on end
    function f:CreateTexture() return Region(self) end
    function f:CreateFontString() return Region(self) end
    function f:Click() self.scripts.OnClick(self) end
    return f
end
CreateFrame = function(kind, name, parent)
    local f = Frame(kind, name, parent)
    if name then _G[name] = f end
    created[#created + 1] = f
    return f
end
UIParent = Frame("Frame", "UIParent")
-- The game's Escape for windows listed in UISpecialFrames.
local function PressEscape()
    for _, name in ipairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then frame:Hide() end
    end
end

-- EraUI and its Classic layer, with every call a reset makes recorded.
local E = { modules = {} }
function E:Print(message) chat[#chat + 1] = tostring(message) end
E.Persistence = {
    Reset = function()
        if combat then E:Print("Finish combat before resetting EraUI settings."); return false end
        eraResets = eraResets + 1
        return true
    end,
}
local ns = { modules = {} }
E.Classic = ns
function ns.RegisterModule(key, mod) mod.key = key; ns.modules[#ns.modules + 1] = mod end
local function Snapshot(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    local out = {}
    for _, k in ipairs(keys) do
        local v = t[k]
        if v == nil then v = t[tonumber(k)] end
        out[#out + 1] = k .. "=" .. (type(v) == "table" and "{" .. Snapshot(v) .. "}" or tostring(v))
    end
    return table.concat(out, ",")
end
local function Log(what) log[#log + 1] = what .. " | " .. Snapshot(ns.db) end
function ns.Print(message) chat[#chat + 1] = "classic: " .. tostring(message); Log("Print " .. tostring(message)) end
ns.ApplyAll = function() Log("ApplyAll") end
ns.ToggleChanged = function(key) Log("ToggleChanged " .. key) end
ns.ClassicScrollBar = function() return Methods({}) end
StaticPopup_Show = function(which) Log("StaticPopup_Show " .. tostring(which)) end

assert(loadfile("Core/Presets.lua"))("EraUI", E)
assert(loadfile("Classic/Options.lua"))("EraUI", E)
assert(loadfile("Classic/OptionsWindow.lua"))("EraUI", E)
assert(loadfile("Core/Commands.lua"))("EraUI", E)
-- Options.lua's own needs the game's edit mode; record the call instead.
ns.FitBarsToSize = function(big) Log("FitBarsToSize " .. tostring(big)) end

-- Two Quality of Life rows, as Core/Integration.lua adds them.
ns.TOGGLES[#ns.TOGGLES + 1] = { "eraui_vendorPrice", "QoL: Vendor prices", "Add missing selling prices." }
ns.TOGGLES[#ns.TOGGLES + 1] = { "eraui_gryphons", "QoL: Gryphons", "Show the end caps." }
local OFF = { oneBar = true, defaultBarSize = true, oneBag = true, bagsAboveRow = true, questLogDual = true,
    statPanes = true, classColorHealth = true, classColorPlates = true, mapFade = true, hideLastNames = true,
    spellBookTopRank = true, eraui_gryphons = true }
ns.DB_DEFAULTS = { dbVersion = 1, textureSource = "builtin", microScale = 1, barOffsetX = 0 }
for _, entry in ipairs(ns.TOGGLES) do ns.DB_DEFAULTS[entry[1]] = not OFF[entry[1]] end
-- The real list plus one default-off key, so the old "reload?" branch is run too.
ns.RELOAD_KEYS = { bags = true, castBars = true, characterSheet = true, classicBar = true, comboPoints = true,
    gameMenu = true, minimap = true, namePlates = true, panels = true, professionsBook = true, tradeSkill = true,
    groupFinder = true, questMapPane = true, questTracker = true, settingsPanel = true, unitFrames = true,
    spellBook = true, statPanes = true }

-- Settings to reset: every switch away from its default plus layout leftovers,
-- or only a few switches changed, with nothing that needs a reload.
local function Changed()
    local db = {}
    for k, v in pairs(ns.DB_DEFAULTS) do db[k] = v end
    for _, entry in ipairs(ns.TOGGLES) do db[entry[1]] = not ns.DB_DEFAULTS[entry[1]] end
    db.microPos = { point = "TOP", x = 3 }
    db.layoutJobs = { fit = "big" }
    db.textureSource = "bundled"
    db.microScale = 1.4
    db.extra = 7
    return db
end
local function Lightly()
    local db = {}
    for k, v in pairs(ns.DB_DEFAULTS) do db[k] = v end
    db.castAnim = false
    db.eraui_vendorPrice = false
    db.mapFade = true
    db.microScale = 1.2
    return db
end

-- The old code, exactly as it was before it asked.
local function OldResetToggles(frame)
    local rows = {}
    for _, entry in ipairs(ns.TOGGLES) do rows[#rows + 1] = entry end
    local wentOff = false
    local wasBig = ns.db.defaultBarSize == true
    for _, entry in ipairs(rows) do
        local want = ns.DB_DEFAULTS[entry[1]]
        if want == false and ns.db[entry[1]] ~= false and ns.RELOAD_KEYS[entry[1]] then wentOff = true end
        ns.db[entry[1]] = want
        if entry[1]:match("^eraui_") then ns.ToggleChanged(entry[1]) end
    end
    if wasBig and ns.db.defaultBarSize ~= true and ns.FitBarsToSize then ns.FitBarsToSize(false) end
    ns.ApplyAll()
    frame:Refresh()
    if wentOff and StaticPopup_Show then StaticPopup_Show("ERAUICLASSIC_RELOAD") end
end
local function OldClassicReset()
    wipe(ns.db)
    for k, v in pairs(ns.DB_DEFAULTS) do ns.db[k] = v end
    ns.Print("defaults restored")
    ns.ApplyAll()
end

-- What the old code does from these settings: its calls in order, each with
-- the settings at that moment, and the settings it leaves.
local function Expected(settings, old)
    local saved = log
    log = {}
    ns.db = settings()
    local db = ns.db
    old()
    local result = { calls = table.concat(log, "\n"), after = Snapshot(ns.db), same = ns.db == db }
    log = saved
    return result
end

local function Last() return chat[#chat] end
local prompt
local function Prompt() return _G.EraUIResetPrompt end
-- Nothing reset, nothing applied, no popup, the settings untouched.
local function Untouched(before, label)
    Equal(#log, 0, label .. ": no reset call")
    Equal(Snapshot(ns.db), before, label .. ": settings unchanged")
    Equal(eraResets, 0, label .. ": /era settings not reset")
    Equal(reloads, 0, label .. ": no reload")
end
local everyText = {}
local function Asked(title, question, label)
    prompt = Prompt()
    Equal(prompt ~= nil and prompt:IsShown(), true, label .. ": the prompt opens")
    Equal(prompt.title.text, title, label .. ": its title")
    Equal(prompt.message.text, question, label .. ": its question")
    Equal(prompt.note.text, "", label .. ": no warning to start with")
    Equal(prompt.reset.label.text, "Reset", label .. ": Reset button")
    Equal(prompt.cancel.label.text, "Cancel", label .. ": Cancel button")
    everyText[#everyText + 1] = title
    everyText[#everyText + 1] = question
end

-- The game's Options > AddOns > EraUI page, shown in a stand-in Settings panel.
ns.db = Changed()
local panel = CreateFrame("Frame", "TestSettingsPanel", UIParent)
local canvas = ns.OptionsCanvas()
canvas:SetParent(panel)
canvas:Show()
local function ButtonOn(owner, label)
    local found
    for _, f in ipairs(created) do
        if f.kind == "Button" and f.parent == owner and f.label == label then
            Equal(found, nil, "one " .. label .. " button")
            found = f
        end
    end
    assert(found, "no " .. label .. " button")
    return found
end
local resetToggles = ButtonOn(canvas, "Reset toggles")
local refreshes = 0
do
    local refresh = canvas.Refresh
    canvas.Refresh = function(self, ...) refreshes = refreshes + 1; Log("Refresh"); return refresh(self, ...) end
end
Equal(resetToggles.tooltip, "Asks first, then puts every checkbox back to its default. Nothing to do with edit mode layouts.",
    "Reset toggles: the hover says it asks first")
everyText[#everyText + 1] = resetToggles.tooltip

local TOGGLES_TITLE, TOGGLES_QUESTION = "Reset toggles", "Reset every checkbox on this page to its default?"
local CLASSIC_TITLE, CLASSIC_QUESTION = "Reset Classic look", "Reset the Classic look's own options and saved positions to their defaults?"
local RED_NOTE = "|cffff5555Finish combat first, then click Reset again.|r"

-- In a fight, before the prompt exists: a chat line, no prompt ------------------------------
ns.db = Changed()
local before = Snapshot(ns.db)
combat = true
resetToggles:Click()
Equal(Last(), "Finish combat before resetting the toggles.", "Reset toggles in a fight: says to finish combat")
Equal(Prompt(), nil, "Reset toggles in a fight: no prompt is made")
Untouched(before, "Reset toggles in a fight")
SlashCmdList.ERAUICLASSIC("reset")
Equal(Last(), "Finish combat before resetting the Classic look.", "/eraui-classic reset in a fight: says to finish combat")
Equal(Prompt(), nil, "/eraui-classic reset in a fight: no prompt is made")
Untouched(before, "/eraui-classic reset in a fight")
combat = false

-- Reset toggles: the click alone only asks ----------------------------------------------------
chat = {}
resetToggles:Click()
Asked(TOGGLES_TITLE, TOGGLES_QUESTION, "Reset toggles")
Untouched(before, "Reset toggles alone")
Equal(#chat, 0, "Reset toggles alone prints nothing")
Equal(prompt.name, "EraUIResetPrompt", "the prompt is the one /era reset uses")

-- Cancel, the X, Escape and hover do nothing.
prompt.cancel:Click()
Equal(prompt:IsShown(), false, "Reset toggles: Cancel closes the prompt")
Untouched(before, "Reset toggles: Cancel")
resetToggles:Click(); prompt.close:Click()
Equal(prompt:IsShown(), false, "Reset toggles: the X closes the prompt")
Untouched(before, "Reset toggles: the X")
resetToggles:Click(); PressEscape()
Equal(prompt:IsShown(), false, "Reset toggles: Escape closes the prompt")
Untouched(before, "Reset toggles: Escape")
resetToggles:Click()
for _, event in ipairs({ "OnEnter", "OnLeave" }) do
    prompt.reset.scripts[event](prompt.reset); prompt.cancel.scripts[event](prompt.cancel)
end
Untouched(before, "Reset toggles: hovering the buttons")

-- Closing the page closes its question; another page's closing or another
-- question is left alone.
panel:Hide()
Equal(prompt:IsShown(), false, "the game's options closing closes the Reset toggles question")
Untouched(before, "the page closing")
panel:Show()
resetToggles:Click()
canvas:Hide()
Equal(prompt:IsShown(), false, "leaving the page closes its question")
Untouched(before, "leaving the page")
canvas:Show()

-- A fight that starts with the prompt up: Reset only says to finish.
resetToggles:Click()
chat = {}
combat = true
prompt.reset:Click()
Equal(Last(), "Finish combat before resetting the toggles.", "Reset toggles, a fight: chat says to finish combat")
Equal(prompt:IsShown(), true, "Reset toggles, a fight: the prompt stays up to try again")
Equal(prompt.note.text, RED_NOTE, "Reset toggles, a fight: the prompt says so too, in red")
Untouched(before, "Reset toggles, Reset in a fight")
resetToggles:Click()
Equal(Last(), "Finish combat before resetting the toggles.", "Reset toggles clicked again in a fight: only the chat line")
Untouched(before, "Reset toggles clicked again in a fight")
combat = false

-- Reset does exactly what the button did before, from both kinds of settings.
local function CheckToggles(owner, button, settings, label)
    local want = Expected(settings, function() OldResetToggles(owner) end)
    ns.db = settings()
    local db = ns.db
    button:Click()
    Equal(#log, 0, label .. ": the click alone resets nothing")
    Equal(prompt:IsShown(), true, label .. ": it asks")
    Equal(prompt.message.text, TOGGLES_QUESTION, label .. ": the toggles question")
    Equal(prompt.note.text, "", label .. ": an old warning is gone")
    prompt.reset:Click()
    Equal(table.concat(log, "\n"), want.calls, label .. ": Reset makes the old calls, in order, on the same settings")
    Equal(Snapshot(ns.db), want.after, label .. ": Reset leaves the same settings as before")
    Equal(ns.db == db, want.same, label .. ": the same settings table")
    Equal(prompt:IsShown(), false, label .. ": Reset closes the prompt")
    Equal(eraResets + reloads, 0, label .. ": /era settings not reset, no reload")
    log = {}
end
CheckToggles(canvas, resetToggles, Changed, "Reset toggles, everything changed")
CheckToggles(canvas, resetToggles, Lightly, "Reset toggles, a few changed")
do
    -- The old calls really were made: the reference is not empty.
    local want = Expected(Changed, function() OldResetToggles(canvas) end)
    Equal(want.calls:find("ToggleChanged eraui_vendorPrice", 1, true) ~= nil and want.calls:find("FitBarsToSize false", 1, true) ~= nil
        and want.calls:find("StaticPopup_Show ERAUICLASSIC_RELOAD", 1, true) ~= nil and want.calls:find("\nRefresh", 1, true) ~= nil,
        true, "the old Reset toggles calls are all checked")
    local light = Expected(Lightly, function() OldResetToggles(canvas) end)
    Equal(light.calls:find("FitBarsToSize", 1, true) == nil and light.calls:find("StaticPopup_Show", 1, true) == nil, true,
        "and the quiet case makes neither")
end

-- The old options window has the same button: it asks the same way.
ns.OpenOptions()
local window = _G.EraUIClassicOptions
Equal(window ~= nil and window:IsShown(), true, "the old options window opens")
do
    local refresh = window.Refresh
    window.Refresh = function(self, ...) Log("Refresh window"); return refresh(self, ...) end
end
local windowReset = ButtonOn(window, "Reset toggles")
ns.db = Changed()
before = Snapshot(ns.db)
windowReset:Click()
Asked(TOGGLES_TITLE, TOGGLES_QUESTION, "the window's Reset toggles")
Untouched(before, "the window's Reset toggles alone")
canvas:Hide()
Equal(prompt:IsShown(), true, "another page closing leaves the window's question up")
canvas:Show()
window:Hide()
Equal(prompt:IsShown(), false, "the window closing closes its question")
Untouched(before, "the window closing")
window:Show()
CheckToggles(window, windowReset, Changed, "the window's Reset toggles")

-- /eraui-classic reset: the command alone only asks -------------------------------------------
Equal(SLASH_ERAUICLASSIC1, "/eraui-classic", "the command")
Equal(SLASH_ERAUICLASSIC2, "/era-classic", "and its short name, the same handler")
ns.db = Changed()
before = Snapshot(ns.db)
chat = {}
SlashCmdList.ERAUICLASSIC("reset")
Asked(CLASSIC_TITLE, CLASSIC_QUESTION, "/eraui-classic reset")
Untouched(before, "/eraui-classic reset alone")
Equal(#chat, 0, "/eraui-classic reset alone prints nothing")
prompt.cancel:Click()
Equal(prompt:IsShown(), false, "/eraui-classic reset: Cancel closes the prompt")
Untouched(before, "/eraui-classic reset: Cancel")
SlashCmdList.ERAUICLASSIC("RESET")
Asked(CLASSIC_TITLE, CLASSIC_QUESTION, "/eraui-classic RESET")
prompt.close:Click()
Equal(prompt:IsShown(), false, "/eraui-classic reset: the X closes the prompt")
Untouched(before, "/eraui-classic reset: the X")
SlashCmdList.ERAUICLASSIC("reset"); PressEscape()
Equal(prompt:IsShown(), false, "/eraui-classic reset: Escape closes the prompt")
Untouched(before, "/eraui-classic reset: Escape")
SlashCmdList.ERAUICLASSIC("reset"); panel:Hide()
Equal(prompt:IsShown(), true, "/eraui-classic reset: the options page closing leaves it up")
panel:Show(); prompt:Hide()

-- A fight with the prompt up.
SlashCmdList.ERAUICLASSIC("reset")
chat = {}
combat = true
prompt.reset:Click()
Equal(Last(), "Finish combat before resetting the Classic look.", "/eraui-classic reset, a fight: chat says to finish combat")
Equal(prompt:IsShown(), true, "/eraui-classic reset, a fight: the prompt stays up")
Equal(prompt.note.text, RED_NOTE, "/eraui-classic reset, a fight: the red note")
Untouched(before, "/eraui-classic reset, Reset in a fight")
combat = false

-- Reset does exactly what the command did before.
do
    local want = Expected(Changed, OldClassicReset)
    Equal(want.calls:find("Print defaults restored", 1, true) ~= nil and want.calls:find("\nApplyAll", 1, true) ~= nil, true,
        "the old /eraui-classic reset calls are checked")
    Equal(want.same, true, "the old reset kept the same settings table")
    ns.db = Changed()
    local db = ns.db
    chat = {}
    SlashCmdList.ERAUICLASSIC("reset")
    Equal(#log, 0, "/eraui-classic reset: the command alone resets nothing")
    Equal(prompt.note.text, "", "/eraui-classic reset: the old warning is gone")
    prompt.reset:Click()
    Equal(table.concat(log, "\n"), want.calls, "/eraui-classic reset: Reset makes the old calls, in order")
    Equal(Snapshot(ns.db), want.after, "/eraui-classic reset: Reset leaves the defaults, as before")
    Equal(Snapshot(ns.db), Snapshot(ns.DB_DEFAULTS), "/eraui-classic reset: exactly the defaults")
    Equal(ns.db == db, true, "/eraui-classic reset: the same settings table")
    Equal(prompt:IsShown(), false, "/eraui-classic reset: Reset closes the prompt")
    Equal(Last(), "classic: defaults restored", "/eraui-classic reset: says so, as before")
    Equal(eraResets + reloads, 0, "/eraui-classic reset: /era settings not reset, no reload")
    log = {}
end

-- One question at a time: Reset does only what the prompt is asking now ------------------------
ns.db = Changed()
before = Snapshot(ns.db)
resetToggles:Click()
SlashCmdList.ERAUICLASSIC("reset")
Asked(CLASSIC_TITLE, CLASSIC_QUESTION, "toggles, then /eraui-classic reset")
do
    local want = Expected(Changed, OldClassicReset)
    ns.db = Changed()
    prompt.reset:Click()
    Equal(table.concat(log, "\n"), want.calls, "the later question wins: only the Classic reset runs")
    log = {}
end
ns.db = Changed()
before = Snapshot(ns.db)
SlashCmdList.ERAUICLASSIC("reset")
SlashCmdList.ERAUI("reset")
Asked("Reset EraUI", "Reset all EraUI settings to defaults? This reloads your UI.", "/eraui-classic reset, then /era reset")
canvas:Hide()
Equal(prompt:IsShown(), true, "the options page closing leaves /era reset's question up")
canvas:Show()
prompt.reset:Click()
Equal(eraResets, 1, "/era reset's Reset resets EraUI")
Equal(reloads, 1, "and reloads")
Equal(#log, 0, "and runs neither older reset")
Equal(Snapshot(ns.db), before, "the Classic settings are left to /era reset")
eraResets, reloads = 0, 0
prompt:Hide()
SlashCmdList.ERAUI("reset")
resetToggles:Click()
Asked(TOGGLES_TITLE, TOGGLES_QUESTION, "/era reset, then Reset toggles")
do
    local want = Expected(Changed, function() OldResetToggles(canvas) end)
    ns.db = Changed()
    prompt.reset:Click()
    Equal(table.concat(log, "\n"), want.calls, "only Reset toggles runs")
    Equal(eraResets + reloads, 0, "/era reset's reset does not")
    log = {}
end
local listed = 0
for _, name in ipairs(UISpecialFrames) do if name == "EraUIResetPrompt" then listed = listed + 1 end end
Equal(listed, 1, "one prompt, listed once for Escape")
local prompts = 0
for _, f in ipairs(created) do if f.name == "EraUIResetPrompt" then prompts = prompts + 1 end end
Equal(prompts, 1, "every question reuses the one prompt")

-- Help ----------------------------------------------------------------------------------------
chat = {}
SlashCmdList.ERAUICLASSIC("help")
local resetHelp
for _, line in ipairs(chat) do
    if line:find("/eraui-classic reset", 1, true) then
        Equal(resetHelp, nil, "/eraui-classic help explains reset once")
        resetHelp = line
    end
end
Equal(resetHelp, "classic:   /eraui-classic reset - asks first, then resets the Classic look's own options and saved positions (outside combat)",
    "/eraui-classic help says reset asks first")
everyText[#everyText + 1] = resetHelp

-- No dashes in anything a player reads here -------------------------------------------------
for _, line in ipairs(chat) do everyText[#everyText + 1] = line end
everyText[#everyText + 1] = "Finish combat before resetting the toggles."
everyText[#everyText + 1] = "Finish combat before resetting the Classic look."
for _, text in ipairs(everyText) do
    Equal(text:find("\226\128\148", 1, true) == nil and text:find("\226\128\147", 1, true) == nil, true, "no dash in: " .. text)
end
Equal(refreshes > 0, true, "the page refreshed through the checked path")

print("Classic reset prompts: " .. checks .. " assertions passed")
