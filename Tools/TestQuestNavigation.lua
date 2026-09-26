-- Exercise the real Questie adapter and selected-quest reveal path, with the
-- large quest-window construction replaced by a small scrolling window model.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
unpack = table.unpack or unpack
function wipe(t) for k in pairs(t) do t[k] = nil end end
local combat, enabled, selected = false, true, nil
function InCombatLockdown() return combat end
function ClearOverrideBindings() end
function GetBindingKey() end
local listeners = {}
function CreateFrame()
    local f = { scripts = {}, events = {} }
    function f:SetScript(event, fn) self.scripts[event] = fn end
    function f:RegisterEvent(event) self.events[event] = true end
    listeners[#listeners + 1] = f
    return f
end
local function Event(name, ...)
    for _, f in ipairs(listeners) do if f.events[name] then f.scripts.OnEvent(f, name, ...) end end
end
local catalog = { { isHeader = true, title = "A", questLogIndex = 1 } }
for id = 101, 108 do catalog[#catalog + 1] = { questID = id, title = "Quest " .. id } end
catalog[#catalog + 1] = { isHeader = true, title = "B", questLogIndex = 10 }
for id = 109, 112 do catalog[#catalog + 1] = { questID = id, title = "Quest " .. id } end
C_QuestLog = {
    GetNumQuestLogEntries = function() return #catalog end,
    GetInfo = function(index)
        local copy = {}; for key, value in pairs(catalog[index]) do copy[key] = value end; return copy
    end,
    SetSelectedQuest = function(id) selected = id end,
    GetLogIndexForQuestID = function(id)
        for i, info in ipairs(catalog) do if info.questID == id then return i end end
        return 0
    end,
}
local expanded
function ExpandQuestHeader(index) expanded = index; catalog[index].isCollapsed = false end
local ns, modules = {}, {}
function ns.RegisterModule(key, module) modules[key] = module end
local E = { Classic = ns, GetSetting = function() return enabled end }
assert(loadfile("Classic/QuestLog.lua"))("EraUI", E)
local function Upvalue(fn, wanted, replacement)
    for i = 1, 60 do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then
            if replacement ~= nil then debug.setupvalue(fn, i, replacement) end
            return value
        end
    end
    error("missing upvalue " .. wanted)
end
local update = Upvalue(ns.ShowQuestLog, "UpdateAll")
local collect = Upvalue(update, "CollectEntries")
local window = { shown = false, listBar = { value = 0, max = 0 }, detailBar = { value = 99 } }
function window.listBar:GetValue() return self.value end
function window.listBar:SetValue(value) self.value = math.max(0, math.min(value, self.max)) end
function window.detailBar:SetValue(value) self.value = value end
function window:IsShown() return self.shown end
local function Refresh()
    local entries = collect()
    window.listBar.max = math.max(0, #entries - 6)
    window.listBar:SetValue(window.listBar.value)
end
function window:Show() self.shown = true; Refresh() end
function window:Hide() self.shown = false end
Upvalue(ns.ShowQuestLog, "frame", window)
Upvalue(ns.ShowQuestLog, "UpdateAll", Refresh)
modules.questLog.init()
modules.questLog.apply()

local nativeCalls, objectiveCalls, mapCalls = 0, 0, 0
local utils = {}
local original = function(self, quest, ...)
    Equal(self, utils, "fallback receiver retained")
    nativeCalls = nativeCalls + 1
    return "native", nil, select("#", ...)
end
utils.ShowQuestLog = original
utils.ShowObjectiveOnMap = function() objectiveCalls = objectiveCalls + 1 end
utils.ShowFinisherOnMap = function() mapCalls = mapCalls + 1 end
local objective, finisher = utils.ShowObjectiveOnMap, utils.ShowFinisherOnMap
QuestieLoader = { ImportModule = function(_, name) Equal(name, "TrackerUtils", "only tracker utility imported"); return utils end }
Event("ADDON_LOADED", "Questie")
local wrapped = utils.ShowQuestLog
Equal(wrapped ~= original, true, "late-loaded Questie connected")
WorldMapFrame = { IsShown = function() return true end, Hide = function() error("map should not be opened or closed") end }
utils:ShowQuestLog({ Id = 112 })
Equal(nativeCalls, 0, "title click bypasses map-opening path")
Equal(window.shown, true, "title opens Classic window")
Equal(selected, 112, "correct quest selected")
Equal(window.listBar.value, 8, "offscreen quest scrolled into view")
Equal(window.detailBar.value, 0, "description starts at top")
ns.QuestLogSetAllCollapsed(true)
catalog[10].isCollapsed = true
utils:ShowQuestLog({ Id = 109 })
Equal(expanded, 10, "native collapsed header expanded")
Equal(selected, 109, "quest in collapsed section selected")
local entries = collect()
Equal(#entries, 6, "unrelated Classic section remains collapsed")
Equal(entries[3].questID, 109, "selected category is visible")
Equal(window.listBar.value, 0, "scroll offset clamped after expansion")
Equal(utils.ShowObjectiveOnMap, objective, "objective handler unchanged")
Equal(utils.ShowFinisherOnMap, finisher, "finisher-map handler unchanged")
utils:ShowObjectiveOnMap({})
utils:ShowFinisherOnMap({})
Equal(objectiveCalls, 1, "objective still navigates")
Equal(mapCalls, 1, "finisher still navigates")
local first, second, third = utils:ShowQuestLog({ Id = 999 }, "extra", nil)
Equal(first, "native", "unknown quest uses original handler")
Equal(second, nil, "nil return retained")
Equal(third, 2, "fallback varargs retained")
combat = true
utils:ShowQuestLog({ Id = 101 })
Equal(selected, 109, "combat does not alter Classic selection")
Equal(ns.ShowQuestLog(101), false, "direct opening also respects combat")
combat = false
enabled = false
utils:ShowQuestLog({ Id = 101 })
Equal(selected, 109, "disabled master retains Questie behavior")
enabled = true
modules.questLog.restore()
Equal(window.shown, false, "disabling Classic log closes it")
utils:ShowQuestLog({ Id = 101 })
Equal(selected, 109, "disabled Classic log retains Questie behavior")
modules.questLog.apply()
Event("ADDON_LOADED", "Questie")
Equal(utils.ShowQuestLog, wrapped, "reapply does not stack wrappers")
utils:ShowQuestLog({ Id = 101 })
Equal(selected, 101, "reenable restores Classic routing")
Equal(nativeCalls, 4, "only fallback cases reached native handler")
print("Quest navigation: " .. checks .. " assertions passed")
