-- Group Finder skin (Classic/GroupFinder.lua), with the real file.
-- * The game's line across the top of Create Listing (build 70009 and later:
--   LFGListingFrame.DividerFrame.Divider, a fixed 454 long for its own 458
--   wide window) is hidden with alpha 0 once EraUI cuts the window to the
--   social window's width, so it no longer sticks out of both sides. Alpha
--   only: nothing shown, hidden, moved, resized or written on the game's
--   frames. It's a child of the listing page, so this covers the category
--   list and the activity view alike; Group Browser and the who list hide
--   the whole page.
-- Run: fengari Tools/TestGroupFinder.lua (from the addon folder).
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

-- A permissive widget: the methods below keep state; any other method (a
-- name starting with one of these verbs) is a no-op. Every method call is
-- logged by name, so a test can see exactly what was done to a frame.
-- Other keys are plain fields (nil unless set), like a child the frame
-- doesn't have.
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear", "Hook", "Is" }
local Methods = {}
local function IsMethodName(key)
    if type(key) ~= "string" then return false end
    if Methods[key] then return true end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local function Widget(props)
    local w = props or {}
    w.log = {}
    if w.shown == nil then w.shown = true end
    w.points = w.points or {}
    w.scripts = w.scripts or {}
    w.attrs = w.attrs or {}
    return setmetatable(w, { __index = function(_, key)
        if not IsMethodName(key) then return nil end
        local method = Methods[key]
        return function(self, ...)
            self.log[#self.log + 1] = { key, ... }
            if method then return method(self, ...) end
        end
    end })
end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:IsShown() return self.shown end
function Methods:GetWidth() return self.width or 0 end
function Methods:GetHeight() return self.height or 0 end
function Methods:SetSize(w, h) self.width, self.height = w, h end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Methods:GetAttribute(key) return self.attrs[key] end
function Methods:GetAlpha() return self.alpha or 1 end
function Methods:SetAlpha(a) self.alpha = a end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:IsMouseEnabled() return true end
function Methods:IsObjectType() return false end
function Methods:GetRegions() return end

local function Session()
    local s = { frames = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    s.env = env
    env.CreateFrame = function()
        local f = Widget({ events = {} })
        function f:RegisterEvent(event) self.events[event] = true end
        s.frames[#s.frames + 1] = f
        return f
    end
    env.InCombatLockdown = function() return false end
    env.FriendsFrame = Widget({ width = 360, height = 424 })
    function s.Fire(event, ...)
        for _, f in ipairs(s.frames) do
            local handler = f.scripts.OnEvent
            if f.events[event] and handler then handler(f, event, ...) end
        end
    end
    function s.Tick(times)
        for _ = 1, times or 1 do
            for _, f in ipairs(s.frames) do
                local tick = f.scripts.OnUpdate
                if tick then tick(f, 0.2) end
            end
        end
    end
    -- SafeCall runs straight through, so an error fails the test.
    local ns = { modules = {} }
    function ns.RegisterModule(key, module) ns.modules[key] = module end
    function ns.SafeCall(fn, ...) return fn(...) end
    s.ns = ns
    assert(loadfile("Classic/GroupFinder.lua", "t", env))("EraUI", { Classic = ns })
    return s
end

-- The game's window as its addon builds it. withDivider = false: a build
-- before 70009, which had no line.
local function GameWindow(s, withDivider)
    local env = s.env
    env.LFGParentFrame = Widget({ width = 458, height = 535, selectedTab = 1 })
    local listing = Widget({ parent = env.LFGParentFrame })
    listing.BackButton = Widget({ parent = listing })
    if withDivider ~= false then
        listing.DividerFrame = Widget({ parent = listing, width = 11, height = 454 })
        listing.DividerFrame.Divider = Widget({ parent = listing.DividerFrame, width = 11, height = 454 })
    end
    env.LFGListingFrame = listing
    return listing
end

-- The test reads the stand-ins' fields, not their methods, so its own
-- reads stay out of the call log.
local function Alpha(w) return w.alpha or 1 end

local function Keys(t)
    local keys = {}
    for key in pairs(t) do keys[key] = true end
    return keys
end

-- Keys on t that weren't there before, apart from the stand-in's own record
-- of the alpha (the real frame keeps that inside the game).
local function NewKeys(t, before)
    local found = {}
    for key in pairs(t) do
        if not before[key] and key ~= "alpha" then found[#found + 1] = tostring(key) end
    end
    table.sort(found)
    return table.concat(found, ",")
end

-- 1. The window already loaded when the skin applies.
do
    local s = Session()
    local listing = GameWindow(s)
    local frame, line = listing.DividerFrame, listing.DividerFrame.Divider
    local frameKeys, lineKeys = Keys(frame), Keys(line)
    s.ns.modules.groupFinder.apply()
    Equal(s.env.LFGParentFrame.width, 360, "setup: the window is cut to the social window's width")
    -- Turned 90 degrees, the line's height is its length on screen.
    Equal(line.height > s.env.LFGParentFrame.width, true, "setup: the game's line is longer than the window")
    Equal(Alpha(frame) * Alpha(line), 0, "the game's line is hidden in the narrower window")
    Equal(#line.log, 1, "one call on the line")
    Equal(line.log[1][1], "SetAlpha", "and it's SetAlpha")
    Equal(line.log[1][2], 0, "to 0")
    Equal(#frame.log, 0, "its frame is left alone (not hidden, moved, resized or scaled)")
    Equal(line.shown and frame.shown, true, "nothing hidden")
    Equal(line.height, 454, "the line keeps its own size")
    Equal(NewKeys(frame, frameKeys), "", "no key written on its frame")
    Equal(NewKeys(line, lineKeys), "", "no key written on the line")
    s.Tick(5)
    Equal(Alpha(frame) * Alpha(line), 0, "still hidden after more passes")
    Equal(#line.log, 1, "and not written again")
end

-- 2. The game loads its window on demand: the skin applies first, the line
-- is hidden as soon as the window loads.
do
    local s = Session()
    s.ns.modules.groupFinder.apply()
    s.Fire("ADDON_LOADED", "SomeOtherAddon")
    local listing = GameWindow(s)
    local line = listing.DividerFrame.Divider
    Equal(Alpha(line), 1, "setup: not touched before the game's window loads")
    s.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
    Equal(Alpha(listing.DividerFrame) * Alpha(line), 0, "hidden once the game's window loads")
end

-- 3. A build before 70009 (no line): no error, the rest is still dressed.
do
    local s = Session()
    local listing = GameWindow(s, false)
    s.ns.modules.groupFinder.apply()
    local p = listing.BackButton.points[1]
    Equal(p and p[1], "BOTTOMLEFT", "no line: Back is still placed")
    Equal(s.env.LFGParentFrame.width, 360, "no line: the window is still cut")
end

-- 4. The skin off: the game's line is left as it is.
do
    local s = Session()
    local listing = GameWindow(s)
    s.Fire("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
    s.Tick(3)
    Equal(Alpha(listing.DividerFrame.Divider), 1, "skin off: the line is the game's")
    Equal(#listing.DividerFrame.Divider.log, 0, "skin off: nothing done to it")
end

print("Group Finder checks passed: " .. checks .. " assertions.")
