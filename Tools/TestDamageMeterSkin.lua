-- Run the actual Damage Meter skin against fixtures shaped like Blizzard's
-- session windows, rows and breakdown window. Combat values are secret
-- sentinels whose text, bar value, arithmetic and comparison all fail, so any
-- read of names or numbers fails the suite.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Near(actual, expected, label)
    checks = checks + 1
    assert(type(actual) == "number" and math.abs(actual - expected) < 1e-6,
        label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local secret = setmetatable({}, {
    __sub = function() error("secret arithmetic") end, __add = function() error("secret arithmetic") end,
    __div = function() error("secret arithmetic") end, __lt = function() error("secret comparison") end,
    __le = function() error("secret comparison") end, __concat = function() error("secret formatting") end,
})
issecretvalue = function(value) return value == secret end
local combat = false
InCombatLockdown = function() return combat end

-- hooksecurefunc: the original runs first, then the hook, like the client.
function hooksecurefunc(target, name, fn)
    if type(target) == "string" then target, name, fn = _G, target, name end
    local original = target[name]
    assert(type(original) == "function", "hooked a missing method " .. tostring(name))
    target[name] = function(...)
        local a, b, c = original(...)
        fn(...)
        return a, b, c
    end
end

local function Region(parent)
    local r = { parent = parent, alpha = 1, shown = true, points = {}, hooks = {} }
    function r:SetAlpha(value) self.alpha = value end
    function r:GetAlpha() return self.alpha end
    function r:SetShown(value) self.shown = value and true or false end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:IsShown() return self.shown end
    function r:ClearAllPoints() self.points = {} end
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:SetAllPoints(target) self.allPoints = target or true end
    function r:SetSize(w, h) self.width, self.height = w, h end
    function r:SetHeight(h) self.height = h end
    function r:SetAtlas(atlas) self.atlas, self.file, self.colorTexture, self.desaturated = atlas, nil, nil, false end
    function r:SetTexture(file) self.file, self.atlas = file, nil end
    function r:SetColorTexture(...) self.colorTexture, self.atlas = { ... }, nil end
    function r:SetVertexColor(...) self.vertex = { ... } end
    function r:SetDesaturated(value) self.desaturated = value end
    function r:SetBlendMode(mode) self.blend = mode end
    function r:SetFontObject(font) self.font = font; self.textScale = 1 end -- Models a scale reset.
    function r:SetTextScale(scale) self.textScale = scale end
    function r:GetTextScale() return self.textScale end
    function r:GetText() error("addon read row text") end
    return r
end

local frames = {}
local function Frame(parent)
    local f = Region(parent)
    f.level = parent and (parent.level + 1) or 1
    f.scripts, f.events = {}, {}
    function f:SetFrameLevel(level) self.level = level end
    function f:GetFrameLevel() return self.level end
    function f:EnableMouse(value) self.mouse = value end
    function f:CreateTexture() return Region(self) end
    function f:SetScript(key, fn) self.scripts[key] = fn end
    function f:HookScript(key, fn)
        self.hooks[key] = self.hooks[key] or {}
        table.insert(self.hooks[key], fn)
    end
    function f:Fire(key, ...)
        if self.scripts[key] then self.scripts[key](self, ...) end
        for _, fn in ipairs(self.hooks[key] or {}) do fn(self, ...) end
    end
    function f:RegisterEvent(event) self.events[event] = true end
    function f:UnregisterEvent(event) self.events[event] = nil end
    function f:SetBackdrop(value) self.backdrop = value end
    function f:SetBackdropColor(...) self.fill = { ... } end
    function f:SetBackdropBorderColor(...) self.edge = { ... } end
    frames[#frames + 1] = f
    return f
end
local created = {}
CreateFrame = function(kind, name, parent, template)
    local f = Frame(parent)
    f.template = template
    created[#created + 1] = f
    return f
end

GameFontHighlight = { name = "GameFontHighlight" }
ScrollUtil = {
    AddAcquiredFrameCallback = function(scrollBox, callback, owner, iterateExisting)
        assert(not iterateExisting, "existing rows are iterated with the frame signature")
        scrollBox.callbacks[#scrollBox.callbacks + 1] = function(frame) callback(owner, frame, {}, true) end
    end,
}

-- Blizzard fixtures ---------------------------------------------------------

local CLASS_ORANGE = { GetRGB = function() return 1, .49, .04 end }
local function Entry(parent)
    local e = Frame(parent)
    local bar = Frame(e)
    e.StatusBar = bar
    bar.Name, bar.Value = Region(bar), Region(bar)
    bar.Name.textScale, bar.Value.textScale = 1.25, 1.25
    bar.Background, bar.BackgroundEdge = Region(bar), Region(bar)
    bar.Background.atlas = "ui-damagemeters-bar-shadowbg"
    bar.fill = Region(bar)
    bar.fill.atlas = "UI-HUD-CoolDownManager-Bar"
    function bar:SetStatusBarTexture(file, layer)
        assert(layer == nil, "SetStatusBarTexture given a second argument (read as a draw layer)")
        self.fill = Region(self); self.fill.file = file
    end
    function bar:GetStatusBarTexture() return self.fill end
    function bar:GetValue() error("addon read bar value") end
    e.value, e.valuePerSecond = secret, secret
    e.statusBarColor = CLASS_ORANGE
    e.styleCalls = 0
    function e:UpdateStyle()
        self.styleCalls = self.styleCalls + 1
        self.StatusBar.Background:SetAtlas("ui-damagemeters-bar-shadowbg")
        self.StatusBar.BackgroundEdge:SetShown(true)
    end
    function e:UpdateBackground()
        self.StatusBar.Background:SetAlpha(1)
        self.StatusBar.BackgroundEdge:SetAlpha(1)
    end
    return e
end

local function ScrollBox(parent)
    local box = Frame(parent)
    box.callbacks, box.active = {}, {}
    function box:ForEachFrame(fn) for _, frame in ipairs(self.active) do fn(frame, {}) end end
    function box:Acquire(frame)
        frame = frame or Entry(self)
        self.active[#self.active + 1] = frame
        for _, callback in ipairs(self.callbacks) do callback(frame) end
        return frame
    end
    return box
end

local function Dropdown(parent, ...)
    local d, keys = Frame(parent), { ... }
    for _, key in ipairs(keys) do d[key] = Region(d); d[key].atlas = "common-dropdown-" .. key end
    function d:OnButtonStateChanged()
        for _, key in ipairs(keys) do self[key]:SetAtlas("common-dropdown-" .. key .. "-hover") end
    end
    return d
end

local function SessionWindow(parent)
    local w = Frame(parent)
    w.Header = Region(w)
    w.Header.atlas = "ui-damagemeters-header-bar"
    w.SessionTimer = Region(w)
    w.MinimizeButton = Frame(w)
    local normal, pushed, highlight = Region(w.MinimizeButton), Region(w.MinimizeButton), Region(w.MinimizeButton)
    function w.MinimizeButton:GetNormalTexture() return normal end
    function w.MinimizeButton:GetPushedTexture() return pushed end
    function w.MinimizeButton:GetHighlightTexture() return highlight end
    w.SettingsDropdown = Dropdown(w, "Icon")
    w.SessionDropdown = Dropdown(w, "Background", "Arrow")
    w.SessionDropdown.SessionName = Region(w.SessionDropdown)
    w.DamageMeterTypeDropdown = Dropdown(w, "Arrow")
    w.DamageMeterTypeDropdown.TypeName = Region(w.DamageMeterTypeDropdown)
    local container = Frame(w)
    w.MinimizeContainer = container
    container.Background = Region(container)
    container.Background.alpha = 0
    container.NotActive = Region(container)
    container.ScrollBox = ScrollBox(container)
    container.LocalPlayerEntry = Entry(container)
    local source = Frame(container)
    container.SourceWindow = source
    source.Background = Region(source)
    source.ScrollBox = ScrollBox(source)
    w.backgroundAlpha = .5
    function w:GetBackgroundAlpha() return self.backgroundAlpha end
    function w:UpdateBackground() self.MinimizeContainer.Background:SetAlpha(self.backgroundAlpha) end
    function w:SetMinimized(minimized)
        self.isMinimized = minimized
        normal:SetAtlas(minimized and "ui-questtrackerbutton-expand-all" or "ui-questtrackerbutton-collapse-all")
        pushed:SetAtlas("pressed")
        self.MinimizeContainer:SetShown(not minimized)
    end
    w:UpdateBackground()
    return w
end

local function NewMeter()
    local meter = Frame(nil)
    meter.windowDataList = {}
    function meter:SetupSessionWindow(index, windowData)
        windowData.sessionWindow = windowData.sessionWindow or SessionWindow(self)
        windowData.sessionWindow:SetFrameLevel(index)
        windowData.sessionWindow:Show()
        if type(windowData.minimized) == "boolean" then windowData.sessionWindow:SetMinimized(windowData.minimized) end
    end
    return meter
end

-- EraUI namespace -----------------------------------------------------------

local modules, missing = {}, {}
local hooked = setmetatable({}, { __mode = "k" })
local ns = {
    FONT_GOLD = { name = "EraUIClassicGold" },
    RegisterModule = function(key, mod) mod.key = key; modules[key] = mod end,
    TexPath = function(key) return "tex:" .. key, "bundled:" .. key end, -- Path plus fallback, like the real helper.
    Fade = function(region) if region then region:SetAlpha(0) end end,
    SafeCall = function(fn, ...) return pcall(fn, ...) end,
    MissingPiece = function(name) missing[#missing + 1] = name end,
}
function ns.HookMethod(frame, method, fn)
    if not frame or type(frame[method]) ~= "function" then ns.MissingPiece(tostring(method)); return false end
    hooked[frame] = hooked[frame] or {}
    if hooked[frame][method] then return true end
    hooked[frame][method] = true
    hooksecurefunc(frame, method, fn)
    return true
end
local scriptHooks = {}
function ns.HookScriptOnce(frame, script, fn)
    scriptHooks[frame] = scriptHooks[frame] or {}
    if scriptHooks[frame][script] then return end
    scriptHooks[frame][script] = true
    frame:HookScript(script, fn)
end

local E = { Classic = ns }
assert(loadfile("Classic/DamageMeter.lua"))("EraUI", E)
local M = modules.damageMeter
Equal(type(M), "table", "module registers under the damageMeter key")

-- Loads after EraUI: waits for Blizzard_DamageMeter -------------------------

DamageMeter = nil
M.apply()
local watcher = created[#created]
Equal(watcher.events.ADDON_LOADED, true, "waits for the Blizzard addon when the meter is not loaded yet")
DamageMeter = NewMeter()
local first = { damageMeterType = 0 }
DamageMeter.windowDataList[1] = first
DamageMeter:SetupSessionWindow(1, first)
local window = first.sessionWindow
watcher.scripts.OnEvent(watcher, "ADDON_LOADED", "SomeOtherAddon")
Equal(window.Header.alpha, 1, "another addon loading does not skin")
watcher.scripts.OnEvent(watcher, "ADDON_LOADED", "Blizzard_DamageMeter")
Equal(watcher.events.ADDON_LOADED, nil, "the watcher stops after the meter loads")

-- Window frame ---------------------------------------------------------------

local function BackdropOf(owner)
    for _, f in ipairs(created) do if f.parent == owner and f.template == "BackdropTemplate" then return f end end
end
local backdrop = BackdropOf(window)
Equal(backdrop ~= nil, true, "session window gets a Classic backdrop")
Equal(backdrop.backdrop.edgeFile, "Interface\\AddOns\\EraUI\\Media\\TooltipBorder.tga", "uses the tooltip border")
Equal(backdrop.mouse, false, "backdrop never takes clicks")
Equal(backdrop.level, 0, "backdrop sits beneath window 1")
Equal(window.Header.alpha, 0, "modern header art hidden")
Near(backdrop.fill[4], .9 * .5, "fill follows Blizzard's background opacity")
Equal(window.MinimizeContainer.Background.alpha, 0, "modern background hidden")
window.backgroundAlpha = 1
window:UpdateBackground()
Near(backdrop.fill[4], .9, "fill follows a changed Edit Mode background opacity")
Equal(window.MinimizeContainer.Background.alpha, 0, "modern background stays hidden after Blizzard updates it")
window.backgroundAlpha = 0
window:UpdateBackground()
Near(backdrop.fill[4], 0, "zero Edit Mode opacity gives a see-through fill")
Equal(window.MinimizeContainer.Background.alpha, 0, "zero opacity keeps the modern background hidden")
window.backgroundAlpha = .5
window:UpdateBackground()
Near(backdrop.fill[4], .9 * .5, "fill returns when opacity is raised again")

Equal(window.SessionTimer.font, ns.FONT_GOLD, "timer uses Classic gold")
Equal(window.DamageMeterTypeDropdown.TypeName.font, ns.FONT_GOLD, "title uses Classic gold")
Equal(window.SessionDropdown.SessionName.font, ns.FONT_GOLD, "session letter uses Classic gold")
Equal(window.MinimizeContainer.NotActive.font, ns.FONT_GOLD, "idle text uses Classic gold")

-- Header buttons stay silver through Blizzard's state repaints.
Equal(window.SettingsDropdown.Icon.desaturated, true, "cog is silver")
Equal(window.SessionDropdown.Background.desaturated, true, "session button is silver")
Equal(window.DamageMeterTypeDropdown.Arrow.desaturated, true, "type arrow is silver")
window.SettingsDropdown:OnButtonStateChanged()
window.SessionDropdown:OnButtonStateChanged()
window.DamageMeterTypeDropdown:OnButtonStateChanged()
Equal(window.SettingsDropdown.Icon.desaturated, true, "cog stays silver after hover")
Equal(window.SessionDropdown.Arrow.desaturated, true, "session arrow stays silver after hover")
Equal(window.DamageMeterTypeDropdown.Arrow.desaturated, true, "type arrow stays silver after hover")
Equal(window.SettingsDropdown.Icon.atlas, "common-dropdown-Icon-hover", "Blizzard still chooses the button state art")

-- Minimise ---------------------------------------------------------------------

local button = window.MinimizeButton
local normal = button:GetNormalTexture()
Equal(normal.desaturated, true, "minimise button is silver like the other buttons")
Equal(button:GetHighlightTexture().desaturated, true, "minimise hover glow is silver, not red")
window:SetMinimized(true)
Equal(normal.atlas, "ui-questtrackerbutton-expand-all", "Blizzard still chooses the expand art")
Equal(normal.desaturated, true, "expand art is silver")
Equal(button:GetPushedTexture().desaturated, true, "pressed art is silver")
Equal(backdrop.divider.shown, false, "header divider hidden while minimised")
Equal(backdrop.points[2][2], window.Header, "minimised frame shrinks to the header")
window:SetMinimized(false)
Equal(normal.atlas, "ui-questtrackerbutton-collapse-all", "Blizzard still chooses the collapse art")
Equal(normal.desaturated, true, "collapse art stays silver")
Equal(backdrop.divider.shown, true, "divider returns when expanded")
Equal(backdrop.points[2][2], window, "expanded frame covers the window")

-- Rows ---------------------------------------------------------------------------

local box = window.MinimizeContainer.ScrollBox
local row = box:Acquire()
local bar = row.StatusBar
Equal(bar.fill.file, "tex:statusBar", "row uses the Classic bar texture")
Equal(bar.fill.vertex and bar.fill.vertex[2], .49, "current class colour handed to the new texture")
Equal(bar.Name.font, GameFontHighlight, "row name uses the Classic font")
Equal(bar.Value.font, GameFontHighlight, "row value uses the Classic font")
Equal(bar.Name.textScale, 1.25, "Blizzard's text size survives the font change")
Equal(bar.Background.colorTexture and bar.Background.colorTexture[4], .35, "row background is flat dark")
Equal(bar.BackgroundEdge.alpha, 0, "modern row edge hidden")
row:UpdateStyle()
Equal(bar.Background.colorTexture and bar.Background.colorTexture[4], .35, "row background repainted after a style change")
row:UpdateBackground()
Equal(bar.BackgroundEdge.alpha, 0, "row edge stays hidden after a background update")
Equal(row.styleCalls, 1, "Blizzard's own style pass still runs once")

-- Pooled frames are reacquired; they must not stack extra hooks or textures.
local texture = bar.fill
box:Acquire(row)
Equal(bar.fill, texture, "a reacquired row is not re-textured")
row:UpdateStyle()
Equal(row.styleCalls, 2, "hooks are not duplicated on reacquire")

Equal(window.MinimizeContainer.LocalPlayerEntry.StatusBar.fill.file, "tex:statusBar", "pinned own-player row skinned")

-- Combat: values are secret, new rows and windows still skin without reads.
combat = true
local combatRow = box:Acquire()
Equal(combatRow.StatusBar.fill.file, "tex:statusBar", "rows acquired in combat are skinned")

-- Breakdown window -------------------------------------------------------------------

local source = window.MinimizeContainer.SourceWindow
Equal(source.Background.alpha, 0, "breakdown modern background hidden")
local sourceBackdrop = BackdropOf(source)
Equal(sourceBackdrop ~= nil, true, "breakdown window gets a Classic backdrop")
Near(sourceBackdrop.fill[4], .9, "breakdown fill is the tooltip opacity")
local spellRow = source.ScrollBox:Acquire()
Equal(spellRow.StatusBar.fill.file, "tex:statusBar", "breakdown rows skinned")

-- Extra windows from the cog menu --------------------------------------------------

local second = { damageMeterType = 1 }
DamageMeter.windowDataList[2] = second
DamageMeter:SetupSessionWindow(2, second)
local extra = second.sessionWindow
Equal(extra.Header.alpha, 0, "new window made in combat is skinned")
Equal(BackdropOf(extra).level, 1, "new window's backdrop sits beneath it")
local extraRow = extra.MinimizeContainer.ScrollBox:Acquire()
Equal(extraRow.StatusBar.fill.file, "tex:statusBar", "new window rows skinned")
combat = false

-- Re-showing a hidden window reuses it without a second backdrop.
local before = #created
DamageMeter:SetupSessionWindow(2, second)
Equal(#created, before, "a reused window is not given a second backdrop")

-- Minimised on load: the saved state is honoured.
local third = { minimized = true }
DamageMeter.windowDataList[3] = third
DamageMeter:SetupSessionWindow(3, third)
Equal(third.sessionWindow.MinimizeButton:GetNormalTexture().desaturated, true,
    "a window restored minimised has a silver button")

-- Setting off (next load): nothing new is skinned.
M.restore()
local plain = box:Acquire()
Equal(plain.StatusBar.fill.atlas, "UI-HUD-CoolDownManager-Bar", "disabled skin leaves new rows native")

-- Already-loaded meter: apply skins immediately without a watcher.
local loadedBefore = #created
DamageMeter = NewMeter()
local solo = {}
DamageMeter.windowDataList[1] = solo
DamageMeter:SetupSessionWindow(1, solo)
M.apply()
Equal(solo.sessionWindow.Header.alpha, 0, "an already-loaded meter is skinned on apply")
local extraWatchers = 0
for i = loadedBefore + 1, #created do if created[i].events.ADDON_LOADED then extraWatchers = extraWatchers + 1 end end
Equal(extraWatchers, 0, "no second load watcher")
Equal(#missing, 0, "every expected Blizzard piece was found")

print("Damage meter skin checks passed: " .. checks .. " assertions.")
