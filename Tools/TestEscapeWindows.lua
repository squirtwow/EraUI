-- Escape closes EraUI's own windows (Classic/Widgets.lua ns.CloseOnEscape)
-- through the game's list of windows Escape closes, UISpecialFrames, never by
-- binding the key: a binding changed from addon code has the game rebuild
-- your action bars and state inside the addon's code, which then breaks on
-- your hidden health (thousands of errors, 2026-10-06). The real Widgets.lua
-- runs on a mock game whose frames run OnShow and OnHide as the game does
-- (on what you see, so hiding the interface hides its windows too), and
-- whose Escape hides every listed window that's shown, as does the
-- interface coming back after Alt+Z. Any key binding call stops the test.
-- Tools/TestSpellBookToggle.lua checks the spellbook's Escape with its
-- secure layer, in and out of a fight.
-- Run with: fengari Tools/TestEscapeWindows.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat = false
local frames = {}
InCombatLockdown = function() return combat end
for _, name in ipairs({ "SetBinding", "SetBindingClick", "SetBindingItem", "SetBindingMacro", "SetBindingSpell",
    "SetOverrideBinding", "SetOverrideBindingClick", "SetOverrideBindingItem", "SetOverrideBindingMacro",
    "SetOverrideBindingSpell", "ClearOverrideBinding", "ClearOverrideBindings", "SaveBindings", "LoadBindings" }) do
    _G[name] = function() error(name .. " called: Escape must never change a key binding") end
end

-- Frames: shown or not, and on screen when they and everything they sit in
-- are shown. OnShow and OnHide run as what you see changes, for the frame
-- and for everything in it; a hook runs after the script.
local Frame
local function Visible(f)
    while f do
        if not f.shown then return false end
        f = f.parent
    end
    return true
end
local function Run(f, key)
    if f.scripts[key] then f.scripts[key](f) end
    for _, fn in ipairs(f.hooks[key] or {}) do fn(f) end
end
local function Family(f, list)
    list[#list + 1] = f
    for _, child in ipairs(f.children) do Family(child, list) end
    return list
end
local function Toggle(f, on)
    if f.shown == on then return end
    local family = Family(f, {})
    local was = {}
    for i, member in ipairs(family) do was[i] = Visible(member) end
    f.shown = on
    for i, member in ipairs(family) do
        local now = Visible(member)
        if now ~= was[i] then Run(member, now and "OnShow" or "OnHide") end
    end
end
Frame = function(name, parent)
    local f = { name = name, parent = parent, shown = true, scripts = {}, hooks = {}, events = {}, children = {} }
    if parent then parent.children[#parent.children + 1] = f end
    function f:GetName() return self.name end
    function f:Show() Toggle(self, true) end
    function f:Hide() Toggle(self, false) end
    function f:SetShown(on) Toggle(self, on and true or false) end
    function f:IsShown() return self.shown end
    function f:IsVisible() return Visible(self) end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:HookScript(key, fn)
        self.hooks[key] = self.hooks[key] or {}
        table.insert(self.hooks[key], fn)
    end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:CreateTexture() return Frame(nil, self) end
    function f:CreateFontString() return Frame(nil, self) end
    function f:GetStringWidth() return 40 end
    -- Anything else the look needs (sizes, points, art): accepted, and kept
    -- out of what's checked.
    setmetatable(f, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
    frames[#frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = function(_, name, parent) return Frame(name, parent) end
UIParent = Frame()
local function Fire(event)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event) end
    end
end

-- The game's list and its Escape (UIParentPanelManager.lua CloseSpecialWindows).
UISpecialFrames = { "GameMenuFrame" }
local function Escape()
    local found
    for _, name in pairs(UISpecialFrames) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            frame:Hide()
            found = 1
        end
    end
    return found
end
-- The game closes every listed window the same way whenever it closes all
-- windows, the interface coming back after Alt+Z among them (UIParent.lua
-- OnShow, Game.lua UI.TopLevelParentShown, CloseAllWindows).
UIParent:SetScript("OnShow", function() Escape() end)
local function Listed(name)
    local count = 0
    for _, listed in ipairs(UISpecialFrames) do
        if listed == name then count = count + 1 end
    end
    return count
end

local ns = {}
assert(loadfile("Classic/Widgets.lua"))("EraUI", { Classic = ns })
Equal(type(ns.CloseOnEscape), "function", "Widgets.lua gives windows their Escape")
Equal(#UISpecialFrames, 1, "loading lists nothing")

-- A named window, closed by hiding it (the options window, /era status,
-- talents): listed as it is, once however often it's asked.
local status = Frame("EraUIClassicStatus", UIParent)
status:Hide()
Equal(ns.CloseOnEscape(status), nil, "a named window needs no follow function")
ns.CloseOnEscape(status)
Equal(Listed("EraUIClassicStatus") .. " " .. #UISpecialFrames, "1 2", "a named window: on the list by its name, once")
Equal(Escape(), nil, "closed, Escape leaves it to the game's menu")
status:Show()
Equal(tostring(Escape()) .. " " .. tostring(status:IsShown()), "1 false", "open, Escape closes it")

-- A window that closes its own way (the quest log, the spellbook): a
-- stand-in on the list, shown while the window is; Escape hides the stand-in
-- and the stand-in runs the window's closer.
local closes = 0
local refuse = false
local book = Frame("EraUIClassicSpellBook", UIParent)
book:Hide()
ns.CloseOnEscape(book, function(self)
    closes = closes + 1
    if not refuse then self:Hide() end
end)
local standIn = _G[UISpecialFrames[#UISpecialFrames]]
Equal(Listed("EraUIClassicSpellBook") .. " " .. tostring(standIn ~= nil and standIn ~= book), "0 true",
    "a window with a closer is listed through a stand-in")
Equal(UISpecialFrames[#UISpecialFrames]:find("^EraUIClassic") ~= nil, true, "named as EraUI's own")
Equal(tostring(standIn.parent) .. " " .. tostring(standIn:IsShown()), "nil false",
    "the stand-in sits in nothing, and is hidden while the window is")
book:Show()
Equal(standIn:IsShown(), true, "shown as the window opens")
Equal(tostring(Escape()) .. " " .. closes .. " " .. tostring(book:IsShown()) .. " " .. tostring(standIn:IsShown()),
    "1 1 false false", "Escape: the window's own closer closes it")
book:Show()
book:Hide()
Equal(tostring(standIn:IsShown()) .. " " .. closes, "false 1", "closed some other way, the stand-in follows and the closer isn't run")

-- The interface hidden (Alt+Z): the window's OnHide runs, but it is still
-- open, so its stand-in stays. Bringing the interface back (Alt+Z again, or
-- Escape, which brings it back first) has the game close every listed
-- window, as it does its own: through the window's own closer.
book:Show()
UIParent:Hide()
Equal(tostring(book:IsShown()) .. " " .. tostring(book:IsVisible()) .. " " .. tostring(standIn:IsShown()) .. " " .. closes,
    "true false true 1", "the interface hidden: the window stays open, and so does its stand-in")
UIParent:Show()
Equal(tostring(book:IsShown()) .. " " .. tostring(standIn:IsShown()) .. " " .. closes, "false false 2",
    "the interface back: the game closes it, through its own closer")
Equal(Escape(), nil, "then Escape goes on to the game's menu")

-- A closer that leaves the window open anyway: that Escape is spent, and
-- the stand-in stays down until the window shows again or the fight ends.
book:Show()
combat, refuse = true, true
Equal(tostring(Escape()) .. " " .. closes .. " " .. tostring(book:IsShown()), "1 3 true", "in a fight the closer may keep it open")
Equal(Escape(), nil, "then Escape goes on to the game's menu")
combat, refuse = false, false
Fire("PLAYER_REGEN_ENABLED")
Equal(standIn:IsShown(), true, "after the fight, listed again while it's open")
Equal(tostring(Escape()) .. " " .. tostring(book:IsShown()), "1 false", "and Escape closes it")
Fire("PLAYER_REGEN_ENABLED")
Equal(standIn:IsShown(), false, "a closed window's stand-in stays hidden")

-- A window Escape can't close in a fight while held says so (the
-- spellbook while its secure layer holds it open): its stand-in steps
-- aside as the fight starts, without running the closer, so the very
-- first Escape goes on to the game. The returned function follows held
-- changing with no show or hide; after the fight it's listed again.
local holds = false
local keptCloses = 0
local kept = Frame("EraUIClassicKept", UIParent)
kept:Hide()
local follow = ns.CloseOnEscape(kept, function(self)
    keptCloses = keptCloses + 1
    self:Hide()
end, function() return holds end)
local keptIn = _G[UISpecialFrames[#UISpecialFrames]]
Equal(tostring(type(follow)) .. " " .. tostring(keptIn ~= standIn), "function true", "a stand-in of its own, and a follow function")
kept:Show()
holds = true
Equal(tostring(Escape()) .. " " .. keptCloses .. " " .. tostring(kept:IsShown()), "1 1 false",
    "out of a fight held doesn't count: Escape closes it")
kept:Show()
Fire("PLAYER_REGEN_DISABLED") -- lockdown starts just after this event
combat = true
Equal(tostring(keptIn:IsShown()) .. " " .. keptCloses .. " " .. tostring(kept:IsShown()), "false 1 true",
    "held as the fight starts: the stand-in steps aside, the closer not run")
Equal(Escape(), nil, "so the first Escape goes on to the game's menu")
holds = false
follow()
Equal(keptIn:IsShown(), true, "no longer held: the follow function lists it again")
holds = true
follow()
Equal(tostring(keptIn:IsShown()) .. " " .. keptCloses, "false 1", "held again: off the list, quietly")
kept:Hide()
kept:Show()
Equal(keptIn:IsShown(), false, "opened while held in the fight: still off the list")
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(keptIn:IsShown(), true, "after the fight, listed again")
Equal(tostring(Escape()) .. " " .. keptCloses .. " " .. tostring(kept:IsShown()), "1 2 false", "and Escape closes it")
holds = false

-- A window with no name (a drop down's list): a stand-in too, closed by
-- hiding it.
local list = ns.DropList({ { "First", function() end }, { "Second", function() end } })
Equal(list:GetName(), nil, "the list has no name")
local listIn = _G[UISpecialFrames[#UISpecialFrames]]
Equal(tostring(listIn ~= nil and listIn ~= standIn) .. " " .. tostring(listIn:IsShown()), "true false", "listed through a stand-in of its own")
list:Show()
Equal(tostring(Escape()) .. " " .. tostring(list:IsShown()) .. " " .. tostring(listIn:IsShown()), "1 false false", "Escape closes it")

-- Everything open at once: one Escape closes them all.
status:Show()
book:Show()
kept:Show()
list:Show()
Escape()
Equal(tostring(status:IsShown()) .. " " .. tostring(book:IsShown()) .. " " .. tostring(kept:IsShown()) .. " " .. tostring(list:IsShown()),
    "false false false false", "one Escape closes every listed window that's open")
Equal(#UISpecialFrames, 5, "the game's own entry and one for each window, nothing else")

print("Escape window checks passed: " .. checks .. " assertions.")
