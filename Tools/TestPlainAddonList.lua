-- Plain AddOn List (/era > Windows & Tooltips; Modules/PlainAddonList.lua)
-- on a small mock of the game's AddOn list: off by default (the game's
-- category headings and nested parts stay); on, every time the game fills the
-- list it shows as one plain list in addon order, every addon the game kept
-- and only those (its search still filters, typed or not), collapsed
-- categories' addons too, nothing nested. Off again, the grouped list is back
-- on the game's next fill. It never enables or disables an addon, and waits
-- for the list to load. Run from the addon folder.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- The game's tree list: nodes with children, enumerated depth first,
-- collapsed ones' children included (as EnumerateEntireRange does).
local function Node(parent, data)
    local node = {nodes = {}, parent = parent, data = data}
    function node:GetData() return self.data end
    function node:Insert(childData)
        local child = Node(self, childData)
        self.nodes[#self.nodes + 1] = child
        return child
    end
    function node:SetCollapsed(c) self.collapsed = c end
    function node:GetDepth() return self.parent and self.parent:GetDepth() + 1 or 0 end
    return node
end
_G.CreateTreeDataProvider = function()
    local provider = {node = Node(nil, nil)}
    function provider:Insert(data) return self.node:Insert(data) end
    function provider:GetRootNode() return self.node end
    function provider:SetSortComparator() end
    function provider:EnumerateEntireRange()
        local stack = {}
        for i = #self.node.nodes, 1, -1 do stack[#stack + 1] = self.node.nodes[i] end
        local index = 0
        return function()
            local top = table.remove(stack)
            if not top then return nil end
            index = index + 1
            for i = #top.nodes, 1, -1 do stack[#stack + 1] = top.nodes[i] end
            return index, top
        end
    end
    return provider
end
_G.ScrollBoxConstants = {RetainScrollPosition = true}

-- The addons, in the game's index order: categories, a group parent with its
-- parts (one part listed before its parent), and plain ones.
local ADDONS = {
    {name = "Satchel", title = "Satchel", category = "Bags"},
    {name = "Satchel_Config", title = "Satchel Config", group = "Satchel"},
    {name = "Opener", title = "Opener"},
    {name = "BossTimers", title = "Boss Timers", category = "Boss Mods"},
    {name = "BossTimers_Bars", title = "Boss Timers Bars", group = "BossTimers", category = "Boss Mods"},
    {name = "EraUI", title = "EraUI", category = "UI"},
    {name = "QuestHelp_Extra", title = "Quest Help Extra", group = "QuestHelp"},
    {name = "QuestHelp", title = "Quest Help", category = "Quests"},
    {name = "Zed", title = "Zed"},
}
local toggled = 0
_G.C_AddOns = {
    GetNumAddOns = function() return #ADDONS end,
    EnableAddOn = function() toggled = toggled + 1 end,
    DisableAddOn = function() toggled = toggled + 1 end,
}
local collapsed = {["Boss Mods"] = true}

-- The game's AddOn list frame: a scroll box and a search box whose own
-- copy of the fill function runs before any hook on its script.
local sets, retained
local function ListFrame()
    local box = {}
    function box:GetDataProvider() return self.provider end
    function box:SetDataProvider(provider, keep) self.provider = provider; sets = sets + 1; retained = keep end
    local search = {text = "", hooks = {}}
    function search:GetText() return self.text end
    function search:HookScript(script, fn) assert(script == "OnTextChanged"); self.hooks[#self.hooks + 1] = fn end
    return {ScrollBox = box, SearchBox = search, shown = false, IsShown = function(self) return self.shown end}
end
-- The game's fill (as AddonList_Update: categories, group parents, parts,
-- the search over title, group and category).
local fills = 0
local function GameFill()
    fills = fills + 1
    local provider = CreateTreeDataProvider()
    local categories, groups, pending = {}, {}, {}
    local filter = AddonList.SearchBox:GetText():lower()
    for i, addon in ipairs(ADDONS) do
        local group = addon.group or addon.name
        local category = addon.category
        local match = filter == "" or addon.title:lower():find(filter, 1, true) or group:lower():find(filter, 1, true)
            or (category and category:lower():find(filter, 1, true))
        if match then
            if groups[group] then
                groups[group]:Insert({addonIndex = i})
            elseif addon.name == group then
                local parent = provider
                if category then
                    if not categories[category] then
                        categories[category] = provider:Insert({category = category})
                        categories[category]:SetCollapsed(collapsed[category])
                    end
                    parent = categories[category]
                end
                groups[group] = parent:Insert({addonIndex = i})
                for _, child in ipairs(pending[group] or {}) do groups[group]:Insert(child) end
                pending[group] = nil
            else
                pending[group] = pending[group] or {}
                table.insert(pending[group], {addonIndex = i})
            end
        end
    end
    for _, children in pairs(pending) do for _, child in ipairs(children) do provider:Insert(child) end end
    AddonList.ScrollBox:SetDataProvider(provider, ScrollBoxConstants.RetainScrollPosition)
end
-- Typing in the search box: its own copy first, then its hooks.
local captured
local function Type(text)
    AddonList.SearchBox.text = text
    captured()
    for _, fn in ipairs(AddonList.SearchBox.hooks) do fn(AddonList.SearchBox) end
end

-- Post-hooks as the game makes them.
_G.hooksecurefunc = function(name, after)
    local original = _G[name]
    _G[name] = function(...) original(...); after(...) end
end
local frames = {}
_G.CreateFrame = function()
    local f = {events = {}, scripts = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- The list as it shows: "Category[a,b(c)]" for the grouped one, "a,b,c" for
-- a plain one; depth says whether anything is nested.
local function Shown()
    local provider = AddonList.ScrollBox:GetDataProvider()
    local parts, deepest = {}, 0
    for _, node in provider:EnumerateEntireRange() do
        local data = node:GetData()
        parts[#parts + 1] = data.category and ("[" .. data.category .. "]") or ADDONS[data.addonIndex].name
        deepest = math.max(deepest, node:GetDepth())
    end
    return table.concat(parts, ","), deepest
end

-- A mock EraUI.
local settings
local function Load(listLoaded)
    frames, sets, fills, toggled = {}, 0, 0, 0
    _G.AddonList, _G.AddonList_Update, captured = nil, nil, nil
    local function Arrive()
        _G.AddonList = ListFrame()
        _G.AddonList_Update = GameFill
        captured = GameFill
    end
    if listLoaded then Arrive() end
    settings = {enabled = true, plainAddonList = false}
    local E = {modules = {}}
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    function E:GetSetting(key) return settings[key] end
    assert(loadfile("Modules/PlainAddonList.lua"))("EraUI", E)
    local list = E.modules.PlainAddonList
    list:Initialize()
    return list, Arrive
end

-- Off (the default): the game's own grouped list.
local list = Load(true)
AddonList_Update()
local grouped, depth = Shown()
equal(grouped, "[Bags],Satchel,Satchel_Config,Opener,[Boss Mods],BossTimers,BossTimers_Bars,[UI],EraUI,[Quests],QuestHelp,QuestHelp_Extra,Zed",
    "off by default: the game's categories and nested parts")
equal(depth, 3, "off: parts nested under their parent, under a category")
equal(sets, 1, "off: only the game's own fill sets the list")

-- On: the next fill shows one plain list in addon order, no headings,
-- nothing nested, collapsed Boss Mods' addons included.
settings.plainAddonList = true
list:Refresh()
AddonList_Update()
local plain
plain, depth = Shown()
equal(plain, "Satchel,Satchel_Config,Opener,BossTimers,BossTimers_Bars,EraUI,QuestHelp_Extra,QuestHelp,Zed",
    "on: one plain list in addon order, every addon, no headings")
equal(depth .. " " .. sets .. " " .. tostring(retained), "1 3 true", "nothing nested; the plain list set after the game's, keeping the scroll position")
equal(fills .. " " .. toggled, "2 0", "the game's own fill still runs; no addon enabled or disabled")

-- Typed search: the box's own copy of the fill runs, then the plain list
-- of the addons it kept.
Type("timers")
equal(Shown(), "BossTimers,BossTimers_Bars", "a search: the plain list of the addons the game kept")
Type("bags")
equal(Shown(), "Satchel", "a category's name finds its addons, as the game's search does (no heading)")
Type("")
equal((Shown()), plain, "search cleared: every addon again")

-- The same fill seen twice changes nothing more.
local before = sets
list:Flatten()
equal(sets, before, "an already plain list is left as it is")

-- Off again: the game's grouped list on its next fill.
settings.plainAddonList = false
list:Refresh()
equal((Shown()), plain, "switched off: nothing changes until the game fills the list")
AddonList_Update()
equal((Shown()), grouped, "the next fill: the grouped list is back")
Type("timers")
equal(Shown(), "[Boss Mods],BossTimers,BossTimers_Bars", "off: the search shows the game's own grouping")
Type("")

-- On with the list open: plain at once.
AddonList.shown = true
settings.plainAddonList = true
list:Refresh()
equal((Shown()), plain, "switched on with the list open: plain at once")
AddonList.shown = false

-- The list loads later (on demand): hooked when it arrives, plain on its first fill.
local arrive
list, arrive = Load(false)
settings.plainAddonList = true
list:Refresh()
equal(list.hooked, nil, "no AddOn list yet: nothing hooked")
arrive()
Fire("ADDON_LOADED", "Blizzard_AddOnList")
equal(list.hooked, true, "it loads: hooked")
AddonList_Update()
equal((Shown()), plain, "its first fill: the plain list")
Type("quest")
equal(Shown(), "QuestHelp_Extra,QuestHelp", "its search too")

-- EraUI switched off as a whole: the game's list.
settings.enabled = false
AddonList.SearchBox.text = ""
AddonList_Update()
equal((Shown()), grouped, "EraUI off: the game's grouped list")
settings.enabled = true

-- A list it can't read: left alone, no error.
local odd = {}
AddonList.ScrollBox.provider = odd
before = sets
equal(list:Flatten(), false, "a list without the game's tree methods: left alone")
equal(sets, before, "nothing set")

io.write("Plain AddOn List checks passed: " .. checks .. " assertions.\n")
