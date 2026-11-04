-- /eraui-classic (also /era-classic): the Classic look's own commands. A
-- bare /eraui-classic opens the options (in game: /era). Diagnostics for bug
-- reports live in Look/ClassicDebug.lua.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local Lay = Look.Layout

local S = {}
Look.Slash = S

local function Say(text)
    if type(ns.Print) == "function" then ns.Print(text) end
end
S.Say = Say

local RESET_HELP = "  /eraui-classic reset - asks first, then resets the Classic look's own options and saved positions (outside combat)"

function S.Help()
    Say("commands:")
    Say("  /eraui-classic - opens the options")
    Say("  /eraui-classic settings - the same options in the game's Settings window")
    for _, entry in ipairs(type(ns.TOGGLES) == "table" and ns.TOGGLES or {}) do
        Say("  /eraui-classic " .. entry[1] .. " on|off - " .. entry[2])
    end
    Say("  /eraui-classic textures builtin|bundled - where the old art is read from")
    Say("  /eraui-classic status - a report of your version, build, changed settings and other addons, for bug reports")
    Say("  /eraui-classic debug - client and frame details for bug reports")
    Say("  /eraui-classic layout - makes and switches to a fresh classic Edit Mode layout")
    Say("  /eraui-classic prompt - asks the first login layout question again")
    Say("  /eraui-classic welcome - shows the welcome again")
    Say(RESET_HELP)
end

-- /eraui-classic reset's question (its texts are Squirt's own).
local CLASSIC_RESET = {
    title = "Reset Classic look",
    question = "Reset the Classic look's own options and saved positions to their defaults?",
    combat = "Finish combat before resetting the Classic look.",
}
-- EraUI's own records in the same table outlive the reset, as they aren't
-- the Classic look's options: the notes seen, the welcome and set up done,
-- the game settings and Edit Mode layout to hand back when EraUI is turned
-- off, the one-time moves, and /era's own choices (the eraui_ copies).
-- Wiping them brought What's New and the set up line back, handed back
-- EraUI's values and layout instead of the player's, and after a restart ran
-- the old move again, switching windows back on.
local KEPT = {}
for _, key in ipairs(Look.Words([[updateNotesSeen erauiWelcomeSeen erauiSetupComplete cvarWas previousLayout
    erauiMigrated erauiSettingsMenuMigrated erauiNumericSettingsMirrored]])) do
    KEPT[key] = true
end
local function Kept(key)
    return KEPT[key] or (type(key) == "string" and key:find("^eraui_") ~= nil)
end

function CLASSIC_RESET.run()
    local saved = ns.db
    if not saved then return end
    local keep = {}
    for key, value in pairs(saved) do
        if Kept(key) then keep[key] = value end
    end
    for key in pairs(saved) do saved[key] = nil end
    for key, value in pairs(type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or {}) do saved[key] = value end
    for key, value in pairs(keep) do saved[key] = value end
    Say("defaults restored")
    if type(ns.ApplyAll) == "function" then ns.ApplyAll() end
end
S.CLASSIC_RESET = CLASSIC_RESET

local function Textures(choice)
    local saved = ns.db
    if not saved or (choice ~= "builtin" and choice ~= "bundled") then
        return Say("/eraui-classic textures builtin|bundled")
    end
    saved.textureSource = choice
    Say("textures = " .. choice)
    if type(ns.ApplyAll) == "function" then ns.ApplyAll() end
end

-- A switch by its key (any case), when its default is a true/false one.
local function Switch(word, choice)
    local defaults = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or {}
    for key, value in pairs(defaults) do
        if type(value) == "boolean" and key:lower() == word then
            local saved = ns.db
            if not saved then return true end
            local now
            if choice == "on" or choice == "true" or choice == "1" then now = true
            elseif choice == "off" or choice == "false" or choice == "0" then now = false
            else now = saved[key] == false end
            saved[key] = now
            Say(key .. " = " .. tostring(now))
            if type(ns.ToggleChanged) == "function" then ns.ToggleChanged(key) end
            return true
        end
    end
    return false
end

local function Adopt()
    if ns.ClassicLayoutActive() and ns.db and ns.db.classicBar ~= false then
        ns.QueueLayoutJob("adopt", true)
        return ns.AskLayoutReload("every bar goes back onto the classic bar and is locked there")
    end
    Say("Can't do that now: the classic bar is off, or another Edit Mode layout is active.")
end

local function Dev(argument)
    local saved = ns.db
    if saved then
        saved.welcomed = false
        saved.layoutPrompted = nil
    end
    Say("welcome and layout question reset")
    if argument == "reload" then ns.ReloadForLayout() end
end

-- The first-login layout question again, whatever was answered before.
local function Prompt()
    if ns.db then ns.db.layoutPrompted = nil end
    if StaticPopup_Show then StaticPopup_Show(Lay.POPUP_QUESTION) end
end

local function Sweep()
    local saved = ns.db
    if not saved then return end
    saved.sweepTrace = not saved.sweepTrace or nil
    if type(ns.SweepFriendsReport) == "function" then Look.Try(ns.SweepFriendsReport) end
    Say("sweep trace " .. (saved.sweepTrace and "on" or "off") .. ": open the Who list or the guild roster")
end

local COMMANDS = {
    settings = function() ns.OpenBlizzardSettings() end,
    help = S.Help,
    status = function() if type(ns.ShowStatus) == "function" then ns.ShowStatus() end end,
    toggles = function() S.Toggles() end,
    debug = function() S.Debug() end,
    dmg = function() S.DamageMeter() end,
    sweep = Sweep,
    off = function() Lay.AskTurnOff() end,
    adopt = Adopt,
    targettrace = function() S.TargetTrace() end,
    bars = function() S.Bars() end,
    hit = function() S.Hit() end,
    pin = function() Say("bars are locked into the layout when a Classic reload runs") end,
    layout = function() ns.CreateClassicLayout() end,
    welcome = function() ns.ShowWelcome() end,
    dev = Dev,
    prompt = Prompt,
    reset = function() if EraUI.AskReset then EraUI:AskReset(CLASSIC_RESET) end end,
    textures = Textures,
}
COMMANDS.report = COMMANDS.status

SLASH_ERAUICLASSIC1 = "/eraui-classic"
SLASH_ERAUICLASSIC2 = "/era-classic"
SlashCmdList.ERAUICLASSIC = function(message)
    local text = type(message) == "string" and message:lower() or ""
    -- A command and at most one word after it; anything longer opens the
    -- options like a bare command.
    local command, argument = text:match("^%s*(%S*)%s*(%S*)%s*$")
    command, argument = command or "", argument or ""
    if command == "" then
        if type(ns.OpenOptions) == "function" then ns.OpenOptions() end
        return
    end
    local run = COMMANDS[command]
    if run then return run(argument) end
    if not Switch(command, argument) then S.Help() end
end
