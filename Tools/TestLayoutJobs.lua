-- The "EraUI" Edit Mode layout and the layout jobs (Look/LayoutKit.lua,
-- LayoutJobs.lua and TurnOff.lua; clean-room 2026-10-21) on the sealed mock
-- of Forever (Tools/WindowMockGame.lua) with a model of Edit Mode's
-- manager, its layouts and C_EditMode. What 12-windows-settings.md section
-- 10 asks: every layout write only as a Classic reload ends the session;
-- the jobs in their order (reset, adopt, fit, the band's pins, previous,
-- classic, select) and the queue emptied; the fresh layout made from the
-- game's Classic preset and dressed (chat, unit frames, icon counts, the
-- band's pins), put after the account layouts, saved and made active; an
-- existing one refreshed; the unit frames moved only through their plain
-- ...Base methods; the requests and their refusals; the check after login
-- never switching a layout itself (it queues one more try instead); the
-- first-login question; the Edit Mode write prompt; the hand-back.
-- Run from the addon folder: fengari Tools/TestLayoutJobs.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local Mock = dofile("Tools/WindowMockGame.lua")
local FILES = { "Look/Base.lua", "Look/LayoutKit.lua", "Look/LayoutJobs.lua", "Look/TurnOff.lua" }
local game, st, env, ns, Look, Lay, editor, info, log
setmetatable(_G, { __index = function(_, key) return env and rawget(env, key) end })

local KIND = { Preset = 0, Account = 1, Character = 2 }
local SYSTEM = { ActionBar = 0, ChatFrame = 2, UnitFrame = 3 }
local SETTING = { NumIcons = 1, AlwaysShowButtons = 5 }
local UNITS = { Player = 1, Target = 2, Focus = 3 }

-- Layout data as Edit Mode keeps it: systems with anchors and settings records.
local function Systems()
    return {
        { system = SYSTEM.ChatFrame, systemIndex = 1, isInDefaultPosition = true,
            anchorInfo = { point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", offsetX = 35, offsetY = 95 } },
        { system = SYSTEM.UnitFrame, systemIndex = UNITS.Player, isInDefaultPosition = true, anchorInfo = { point = "CENTER" } },
        { system = SYSTEM.UnitFrame, systemIndex = UNITS.Target, isInDefaultPosition = true, anchorInfo = { point = "CENTER" } },
        { system = SYSTEM.UnitFrame, systemIndex = UNITS.Focus, isInDefaultPosition = true, anchorInfo = { point = "CENTER" } },
        { system = SYSTEM.ActionBar, systemIndex = 1, isInDefaultPosition = true, anchorInfo = { point = "BOTTOM" },
            settings = { { setting = SETTING.NumIcons, value = 12 }, { setting = SETTING.AlwaysShowButtons, value = 1 } } },
        { system = SYSTEM.ActionBar, systemIndex = 2, isInDefaultPosition = false, anchorInfo = { point = "LEFT" },
            anchorInfo2 = { point = "RIGHT" }, settings = { { setting = SETTING.NumIcons, value = 7 } } },
    }
end
local function Preset(name, index)
    return { layoutName = name, layoutType = KIND.Preset, layoutIndex = index, systems = Systems() }
end
local function SystemOf(layout, kind, index)
    for _, system in ipairs(layout.systems) do
        if system.system == kind and system.systemIndex == index then return system end
    end
end
local function SettingOf(system, setting)
    for _, record in ipairs(system.settings or {}) do
        if record.setting == setting then return record.value end
    end
end

local function Session(options)
    options = options or {}
    game = Mock.New()
    st, env, ns = game.st, game.env, game.ns
    log = {}
    local function Note(text) log[#log + 1] = text .. (ns.sessionEnding and "" or " (mid-session)") end
    env.Enum = { EditModeLayoutType = KIND, EditModePresetLayouts = { Modern = 0, Classic = 1 },
        EditModePresetLayoutsMeta = { NumValues = 2 }, EditModeSystem = SYSTEM, EditModeActionBarSetting = SETTING,
        EditModeUnitFrameSystemIndices = UNITS }
    info = { layouts = { Preset("Modern", 0), Preset("Classic", 1),
        { layoutName = "Mine", layoutType = KIND.Account, systems = Systems() } }, activeLayout = 3 }
    for _, layout in ipairs(options.more or {}) do table.insert(info.layouts, layout) end
    if options.active then info.activeLayout = options.active end
    editor = {
        layoutInfo = info,
        GetLayouts = function() return info.layouts end,
        GetActiveLayoutInfo = function() return info.layouts[info.activeLayout] end,
        AreLayoutsFullyMaxed = function() return options.maxed == true end,
        IsEditModeActive = function() return game.editOpen == true end,
        SaveLayouts = function() Note("manager save") end,
        UpdateSystemAnchorInfo = function(_, frame) Note("anchor " .. frame:GetName()) end,
        OnSystemSettingChange = function(_, bar, setting, value)
            Note("set " .. bar:GetName() .. " " .. setting .. "=" .. value)
            st[bar].icons = value
        end,
        SelectLayout = function() error("EraUI switched a layout itself") end,
    }
    env.EditModeManagerFrame = editor
    env.EditModePresetLayoutManager = { GetCopyOfPresetLayouts = function() return { Preset("Modern", 0), Preset("Classic", 1) } end }
    env.C_EditMode = {
        SaveLayouts = function(given) Note("save " .. tostring(given == info)) end,
        SetActiveLayout = function(index)
            Note("activate " .. index)
            info.activeLayout = index
        end,
        OnLayoutAdded = function(index, a, b) Note("added " .. index .. " " .. tostring(a) .. " " .. tostring(b)) end,
    }
    env.C_UI = { Reload = function() Note("reload") end }
    -- The bars and unit frames: Edit Mode frames, written by the game only.
    game.Building(function()
        local function Bar(name, index, icons, home)
            local bar = game.New("Frame", name, env.UIParent)
            game.Own(bar, "system", SYSTEM.ActionBar)
            game.Own(bar, "systemIndex", index)
            st[bar].icons, st[bar].home = icons, home
            game.Own(bar, "GetSettingValue", function(self, setting)
                if setting == SETTING.NumIcons then return st[self].icons end
            end)
            game.Own(bar, "IsInDefaultPosition", function(self) return st[self].home end)
            game.Own(bar, "ResetToDefaultPosition", function(self)
                Note("home " .. self:GetName())
                st[self].home = true
            end)
        end
        Bar("MainActionBar", 1, 12, true)
        Bar("MultiBarBottomLeft", 2, 7, false)
        Bar("MultiBarRight", 4, 12, true)
        Bar("MultiBarLeft", 5, 12, true)
        -- The shaman's totem bar, away from its default (EraUI's pin or the
        -- player's place): a layout reset puts it home too, and the band's
        -- pins then put it over the small row again (Look/BandPins.lua).
        local totem = game.New("Frame", "MultiCastActionBarFrame", env.UIParent)
        game.Own(totem, "system", 17)
        st[totem].home = false
        game.Own(totem, "IsInDefaultPosition", function(self) return st[self].home end)
        game.Own(totem, "ResetToDefaultPosition", function(self)
            Note("home " .. self:GetName())
            st[self].home = true
        end)
        local function Unit(name, index, x, y)
            local unit = game.New("Frame", name, env.UIParent)
            game.Own(unit, "system", SYSTEM.UnitFrame)
            game.Own(unit, "systemIndex", index)
            unit:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", x, y)
            -- Edit Mode's own overrides: never called by EraUI.
            game.Own(unit, "ClearAllPoints", function() error("Edit Mode's ClearAllPoints run by EraUI") end)
            game.Own(unit, "SetPoint", function() error("Edit Mode's SetPoint run by EraUI") end)
            local proto = getmetatable(unit).__index
            game.Own(unit, "ClearAllPointsBase", function(self)
                Note("clear " .. self:GetName())
                proto.ClearAllPoints(self)
            end)
            game.Own(unit, "SetPointBase", function(self, ...) proto.SetPoint(self, ...) end)
        end
        Unit("PlayerFrame", UNITS.Player, 4, -4)
        Unit("TargetFrame", UNITS.Target, 300, -4)
        Unit("FocusFrame", UNITS.Focus, 250, -165)
    end)
    ns.db = { classicBar = true }
    for key, value in pairs(options.saved or {}) do ns.db[key] = value end
    Look = game.Load(FILES)
    Lay = Look.Layout
    -- The band's side (area 01), recorded.
    function ns.PinBandBars() Note("pin") end
    function ns.UnpinBandBars() Note("unpin") end
    function ns.AdoptBandBars() Note("adopt") end
    function ns.MirrorSave() Note("mirror") end
    function ns.ApplyAll() Note("pass") end
    function ns.BandPinAnchors()
        return { { name = "MainActionBar", system = SYSTEM.ActionBar, systemIndex = 1,
            anchorInfo = { point = "BOTTOM", relativeTo = "EraUIClassicBar", relativePoint = "BOTTOM", offsetX = 0, offsetY = 12 } },
            { name = "MultiBarBottomLeft", system = SYSTEM.ActionBar, systemIndex = 2,
            anchorInfo = { point = "BOTTOMLEFT", relativeTo = "EraUIClassicBar", relativePoint = "TOPLEFT", offsetX = 8, offsetY = 2 } } }
    end
    return game
end
local function Log() return table.concat(log, ", ") end
local function Popup(name)
    for i = #game.popups, 1, -1 do
        if game.popups[i][1] == name then return game.popups[i] end
    end
    return nil
end
local function Printed(text)
    for _, line in ipairs(game.printed) do
        if line == text then return true end
    end
    return false
end
local function NoErrors(label)
    Equal(table.concat(game.errors, " || "), "", label .. ": no error handed to the game's error handler")
end
local function MidSession()
    for _, line in ipairs(log) do
        if line:find("(mid-session)", 1, true) and not line:find("^reload") and not line:find("^pass") then return line end
    end
    return "none"
end

---------------------------------------------------------------------------
-- Setting up the EraUI layout: asked for, then made as the session ends
---------------------------------------------------------------------------
Session()
Equal(tostring(ns.ClassicLayoutActive()) .. " " .. tostring(ns.LayoutWritable()), "false true", "Mine: not ours, writable")
game.combat = true
ns.CreateClassicLayout()
Equal(Printed("Layouts can't change in combat.") and ns.db.layoutJobs == nil, true, "refused in a fight")
game.combat = false
ns.CreateClassicLayout()
Equal(ns.db.previousLayout .. " " .. tostring(ns.db.layoutPrompted), "Mine true", "the active layout remembered, the question answered")
local counts = ns.db.layoutJobs.classic.counts
Equal(counts[1] .. " " .. counts[2] .. " " .. counts[4] .. " " .. counts[5], "12 7 12 12", "each bar's icon count by its Edit Mode index")
Equal(Popup(Lay.POPUP_RELOAD)[2], "setting up the EraUI layout", "asks to reload, with the reason")
Equal(Log(), "", "nothing written yet")
Equal(env.StaticPopupDialogs[Lay.POPUP_RELOAD].text, "EraUI: %s. It's done as the interface reloads.", "the reload question")
-- The reload: every job, in order, as the session ends.
ns.ReloadForLayout()
Equal(ns.sessionEnding, true, "the session marked as ending")
local fresh = info.layouts[4]
Equal(fresh.layoutName .. " " .. fresh.layoutType .. " " .. fresh.layoutIndex, "EraUI 1 1", "a copy of the Classic preset, an account layout called EraUI")
Equal(#info.layouts .. " " .. info.layouts[3].layoutName, "4 Mine", "put after the last account layout")
Equal(Log(), "pin, save true, added 4 true false, activate 4, mirror, reload", "pins, the layout saved, added, made active, the mirror, the reload")
Equal(ns.db.layoutSelectPending == true and ns.db.layoutJobs == nil, true, "pending a check, the queue emptied")
-- How it was dressed (fresh).
local chat = SystemOf(fresh, SYSTEM.ChatFrame, 1)
Equal(string.format("%s %s %s %d,%d %s", chat.anchorInfo.point, chat.anchorInfo.relativeTo, chat.anchorInfo.relativePoint,
    chat.anchorInfo.offsetX, chat.anchorInfo.offsetY, tostring(chat.isInDefaultPosition)), "BOTTOMLEFT UIParent BOTTOMLEFT 35,145 false",
    "the chat lifted to 145")
local player, target, focus = SystemOf(fresh, SYSTEM.UnitFrame, 1), SystemOf(fresh, SYSTEM.UnitFrame, 2), SystemOf(fresh, SYSTEM.UnitFrame, 3)
Equal(string.format("%s %d,%d / %d,%d / %d,%d", player.anchorInfo.point, player.anchorInfo.offsetX, player.anchorInfo.offsetY,
    target.anchorInfo.offsetX, target.anchorInfo.offsetY, focus.anchorInfo.offsetX, focus.anchorInfo.offsetY),
    "TOPLEFT 4,-4 / 250,-2 / 250,-165", "the unit frames on their 1.x spots")
local main, left = SystemOf(fresh, SYSTEM.ActionBar, 1), SystemOf(fresh, SYSTEM.ActionBar, 2)
Equal(SettingOf(main, SETTING.NumIcons) .. " " .. SettingOf(left, SETTING.NumIcons), "12 7", "the counts read before")
Equal(SettingOf(main, SETTING.AlwaysShowButtons), 0, "Always Show Buttons off on a fresh layout")
Equal(main.anchorInfo.relativeTo .. " " .. left.anchorInfo.relativePoint .. " " .. tostring(left.anchorInfo2), "EraUIClassicBar TOPLEFT nil",
    "the band's pins, second anchors gone")
Equal(ns.db.barPins.EraUI.MainActionBar[1] .. " " .. ns.db.barPins.EraUI.MultiBarBottomLeft[3], "BOTTOM 8", "the pins written down")
Equal(MidSession(), "none", "no layout write mid-session")
NoErrors("setting up")
-- Default interface bar size on: the larger counts.
Session({ saved = { defaultBarSize = true } })
ns.CreateClassicLayout()
counts = ns.db.layoutJobs.classic.counts
Equal(counts[1] .. " " .. counts[2] .. " " .. counts[4] .. " " .. counts[5], "10 10 8 8", "the larger size's counts")
-- A full Edit Mode and no Edit Mode.
Session({ maxed = true })
ns.CreateClassicLayout()
Equal(Printed("Edit Mode has no room for another layout. Delete one first.") and ns.db.layoutJobs == nil, true, "no room: refused")
env.EditModeManagerFrame = nil
ns.CreateClassicLayout()
Equal(Printed("Edit Mode layouts aren't available."), true, "no Edit Mode: refused")
-- Asked for with "reload now": the reload runs at once.
Session()
ns.CreateClassicLayout(true)
Equal(log[#log], "reload", "reload now")
-- In a fight the Classic reload only reloads.
Session()
ns.CreateClassicLayout()
game.combat = true
ns.ReloadForLayout()
Equal(Log() .. " " .. tostring(ns.db.layoutJobs ~= nil), "reload (mid-session) true", "in a fight: only the reload, the jobs kept")
game.combat = false
-- Jobs only while the session ends.
ns.QueueLayoutJob("adopt", true)
ns.RunLayoutJobsBeforePin()
ns.RunLayoutJobsAfterPin()
Equal(ns.db.layoutJobs.classic ~= nil and ns.db.layoutJobs.adopt == true and #info.layouts == 3 and not Log():find("adopt"), true, "not ending: the jobs wait")
Equal(ns.ApplyClassicFrameSpots(), false, "nor do the frame spots")
-- The next login with the jobs still waiting: a reminder.
ns.SelectClassicLayoutIfPending()
Equal(Popup(Lay.POPUP_RELOAD)[2], "a layout change you asked for is still waiting", "the reminder")
NoErrors("refusals")

---------------------------------------------------------------------------
-- Refreshing an existing EraUI layout
---------------------------------------------------------------------------
local ours = { layoutName = "EraUI", layoutType = KIND.Account, systems = Systems() }
Session({ more = { ours }, active = 4 })
ns.db.barPins = { EraUI = { MultiBarBottomLeft = { "BOTTOMLEFT", "TOPLEFT", 8, 2 } } }
ns.CreateClassicLayout()
Equal(tostring(ns.db.previousLayout) .. " " .. Popup(Lay.POPUP_RELOAD)[2], "nil switching to your EraUI layout", "already ours: not remembered as earlier")
ns.ReloadForLayout()
Equal(#info.layouts, 4, "no new layout")
Equal(Log(), "pin, save true, activate 4, mirror, reload", "refreshed, saved and made active")
local chat2 = SystemOf(ours, SYSTEM.ChatFrame, 1)
Equal(chat2.anchorInfo.offsetY .. " " .. tostring(SettingOf(SystemOf(ours, SYSTEM.ActionBar, 1), SETTING.AlwaysShowButtons)), "95 1",
    "not fresh: the chat and Always Show Buttons left alone")
Equal(SystemOf(ours, SYSTEM.UnitFrame, 1).anchorInfo.point, "TOPLEFT", "the unit frames always placed")
Equal(SystemOf(ours, SYSTEM.ActionBar, 2).anchorInfo.relativeTo, "EraUIClassicBar", "a moved bar already pinned: pinned again")
NoErrors("refreshing")
-- A moved bar not pinned before keeps its place.
local ours2 = { layoutName = "EraUI", layoutType = KIND.Account, systems = Systems() }
Session({ more = { ours2 }, active = 4 })
ns.CreateClassicLayout()
ns.ReloadForLayout()
Equal(SystemOf(ours2, SYSTEM.ActionBar, 2).anchorInfo.point .. " " .. SystemOf(ours2, SYSTEM.ActionBar, 1).anchorInfo.relativeTo,
    "LEFT EraUIClassicBar", "a moved, unpinned bar keeps its place; a bar at home is pinned")

---------------------------------------------------------------------------
-- reset, adopt and fit (before the pins), previous and select (after)
---------------------------------------------------------------------------
local mine = { layoutName = "EraUI", layoutType = KIND.Account, systems = Systems() }
Session({ more = { mine }, active = 4, saved = { microPos = { 1 }, microScale = 1.2, barDragged = true, barOffsetX = 4,
    previousLayout = "Mine", defaultBarSize = true } })
Equal(ns.ClassicLayoutActive(), true, "ours")
ns.ResetClassicLayout()
ns.QueueLayoutJob("adopt", true)
Equal(ns.FitBarsToSize(true), true, "the counts differ: fit queued")
Equal(Popup(Lay.POPUP_RELOAD)[2], "the bars go to ten and eight icons to fit the larger bar", "the fit's reason")
Equal(ns.db.layoutJobs.fit, "big", "fit big")
Equal(ns.RestorePreviousLayout(), true, "back to Mine queued")
Equal(Popup(Lay.POPUP_RELOAD)[2], "switching back to your Mine layout", "its reason")
log = {}
ns.ReloadForLayout()
Equal(Log(), table.concat({ "mirror", "home MultiBarBottomLeft", "home MultiCastActionBarFrame", "pass", "clear TargetFrame", "anchor TargetFrame", "manager save",
    "manager save", "adopt", "set MainActionBar 1=10", "set MultiBarBottomLeft 1=10", "set MultiBarRight 1=8", "set MultiBarLeft 1=8",
    "manager save", "pass", "pin", "activate 3", "mirror", "reload" }, ", "),
    "reset (positions, a pass, the frame spots, a save), adopt, fit, the pins, previous, the mirror, the reload")
Equal(tostring(ns.db.microPos) .. " " .. tostring(ns.db.barDragged) .. " " .. tostring(ns.db.barOffsetX), "nil false nil", "reset's saved places cleared")
Equal(ns.db.previousLayout .. " " .. tostring(ns.db.layoutJobs), " nil", "previous used up, the queue emptied")
local targetFrame = env.TargetFrame
Equal(string.format("%s %d,%d", st[targetFrame].points.TOPLEFT[3], st[targetFrame].points.TOPLEFT[4], st[targetFrame].points.TOPLEFT[5]),
    "TOPLEFT 250,-4", "the target frame on its 1.x spot, through its plain Base methods")
Equal(Printed("The player, target and focus frames moved to their 1.x spots."), true, "and said so")
NoErrors("the jobs")
-- Fit with nothing to change clears a queued fit.
info.activeLayout = 4
ns.QueueLayoutJob("fit", "normal")
for _, name in ipairs({ "MainActionBar", "MultiBarBottomLeft", "MultiBarRight", "MultiBarLeft" }) do st[env[name]].icons = 12 end
Equal(ns.FitBarsToSize(false), false, "already twelve: nothing to fit")
Equal(ns.db.layoutJobs.fit, nil, "the queued fit dropped")
-- Not ours: no fit, no reset.
Session()
Equal(ns.FitBarsToSize(true), false, "not ours: no fit")
ns.ResetClassicLayout()
Equal(ns.db.layoutJobs, nil, "not ours: no reset")
-- Restore with nothing written down, or a layout gone.
Equal(ns.RestorePreviousLayout(), nil, "nothing written down")
Equal(Printed("No earlier layout was written down. Pick one in Edit Mode."), true, "said")
ns.db.previousLayout = "Gone"
ns.RestorePreviousLayout()
Equal(Printed("Your Gone layout is gone."), true, "a layout gone")

---------------------------------------------------------------------------
-- The check after login (never a layout switch mid-session)
---------------------------------------------------------------------------
local built = { layoutName = "EraUI", layoutType = KIND.Account, systems = Systems() }
Session({ more = { built }, saved = { layoutSelectPending = true } })
ns.SelectClassicLayoutIfPending()
Equal(ns.db.layoutSelectTries .. " " .. tostring(ns.db.layoutJobs.select), "1 true", "the first miss: select queued")
Equal(Popup(Lay.POPUP_RELOAD)[2], "the EraUI layout is ready; one more reload switches to it", "and asked")
ns.db.layoutJobs = nil
ns.SelectClassicLayoutIfPending()
Equal(tostring(ns.db.layoutSelectPending) .. " " .. ns.db.layoutSelectTries .. " " .. tostring(ns.db.layoutJobs.select), "false 0 true",
    "the second miss: one last try queued for the next reload")
Equal(Printed("The EraUI layout didn't switch on by itself. One more reload tries again, or pick EraUI in Edit Mode.")
    and Popup(Lay.POPUP_RELOAD)[2] == "switching to your EraUI layout", true, "said and asked")
Equal(Log(), "", "nothing switched or saved mid-session")
log = {}
ns.ReloadForLayout()
Equal(Log(), "pin, activate 4, mirror, reload", "the select job at the reload")
-- Ours already active: settled.
Session({ more = { built }, active = 4, saved = { layoutSelectPending = true, layoutSelectTries = 1 } })
ns.SelectClassicLayoutIfPending()
Equal(tostring(ns.db.layoutSelectPending) .. " " .. ns.db.layoutSelectTries, "false 0", "switched: settled")
-- In a fight: wait.
Session({ more = { built }, saved = { layoutSelectPending = true } })
game.combat = true
ns.SelectClassicLayoutIfPending()
Equal(tostring(ns.db.layoutSelectTries) .. " " .. #game.popups, "nil 0", "in a fight: nothing")
NoErrors("the check after login")

---------------------------------------------------------------------------
-- The first-login question, the Edit Mode write prompt
---------------------------------------------------------------------------
Session()
ns.CheckLayoutPosition()
Equal(tostring(ns.db.layoutPrompted) .. " " .. tostring(Popup(Lay.POPUP_QUESTION) ~= nil), "true true", "asked once")
game.popups = {}
ns.CheckLayoutPosition()
Equal(#game.popups, 0, "never twice")
Equal(env.StaticPopupDialogs[Lay.POPUP_QUESTION].button1 .. " / " .. env.StaticPopupDialogs[Lay.POPUP_QUESTION].button2,
    "Set up and reload / Keep my layout", "its buttons")
env.StaticPopupDialogs[Lay.POPUP_QUESTION].OnAccept()
Equal(log[#log], "reload", "set up and reload")
Session({ saved = { classicBar = false } })
ns.CheckLayoutPosition()
Equal(tostring(ns.db.layoutPrompted) .. " " .. #game.popups, "nil 0", "the band off: no question")
Session({ more = { built }, active = 4 })
ns.CheckLayoutPosition()
Equal(tostring(ns.db.layoutPrompted) .. " " .. #game.popups, "true 0", "ours already: answered, not asked")
Session()
local onEdit
function ns.OnEditMode(fn) onEdit = fn end
ns.WatchEditWrites()
ns.WatchEditWrites()
ns.editWrote = true
game.editOpen = true
onEdit()
Equal(#game.popups, 0, "Edit Mode still open: wait")
game.editOpen = false
onEdit()
Equal(tostring(ns.editWrote) .. " " .. tostring(Popup(Lay.POPUP_EDIT) ~= nil), "nil true", "closed: the prompt, once")

---------------------------------------------------------------------------
-- The hand-back and turning off
---------------------------------------------------------------------------
Session({ more = { built }, active = 4, saved = { previousLayout = "Mine", cvarWas = { nameplateStyle = "0", autoLootDefault = "1" } } })
local written = {}
function ns.SetCVar(name, value) written[#written + 1] = name .. "=" .. value end
ns.HandBack()
table.sort(written)
Equal(tostring(ns.handingBack) .. " " .. Log() .. " " .. tostring(ns.db.layoutSelectPending), "true activate 3 (mid-session) true",
    "the earlier layout made active (at logout)")
Equal(table.concat(written, " ") .. " " .. tostring(ns.db.cvarWas), "autoLootDefault=1 nameplateStyle=0 nil", "each setting put back, the record cleared")
Session({ more = { built }, active = 4 })
ns.HandBack()
Equal(Log(), "activate 1 (mid-session)", "no earlier layout written down: the first")
Session()
ns.HandBack()
Equal(Log(), "", "not ours: no layout switched")
game.combat = true
ns.TurnOffCleanly()
Equal(Printed("Turning EraUI off has to wait until you're out of a fight."), true, "not in a fight")
NoErrors("the hand-back")

print("Layout jobs checks passed: " .. checks .. " assertions.")
