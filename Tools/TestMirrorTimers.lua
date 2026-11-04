-- The breath, fatigue and feign death timers (Look/MirrorTimers.lua, registry
-- entry "mirrorTimers", clean-room 2026-10-21) against a mock of the game's
-- MirrorTimerContainer as Forever builds it (Blizzard_MirrorTimer: three
-- timer frames, each with StatusBar, Border, TextBorder, Text and an unnamed
-- background, plus Edit Mode's Selection child). The game's frames and
-- pieces are sealed: a key written on one fails. Checked: nothing made before
-- the look applies; every timer's size, dark strip, bar, fill, colour per
-- kind, border, plate and label; one event frame for the three events, the
-- look back one frame after each; Dark Mode's border tint; an erroring timer
-- leaves the others dressed; in fights too; restore and repeats.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack

-- Mock objects: state kept beside each object (never on it) --------------------
local state = setmetatable({}, { __mode = "k" })
local Methods = {}
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local made = { frames = 0, regions = 0 }

local function Object(kind, parent, name)
    local obj = {}
    state[obj] = { kind = kind, parent = parent, name = name, anchors = {}, w = 0, h = 0, alpha = 1, shown = true,
        coords = "0,1,0,1", children = {} }
    return setmetatable(obj, {
        __index = Methods,
        __newindex = function(t, key, value)
            if state[t].sealed then error("a key (" .. tostring(key) .. ") written on the game's " .. tostring(state[t].name), 2) end
            rawset(t, key, value)
        end,
    })
end
local function Sealed(obj) state[obj].sealed = true; return obj end
local function Put(owner, key, value) rawset(owner, key, value); return value end

local function F(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = string.format("%g", (select(i, ...))) end
    return table.concat(out, ",")
end
function Methods:SetSize(w, h) state[self].w, state[self].h = w, h end
function Methods:GetSize() return state[self].w, state[self].h end
function Methods:ClearAllPoints() state[self].anchors = {} end
function Methods:SetPoint(point, relative, relativePoint, x, y)
    local list = state[self].anchors
    for i, old in ipairs(list) do if old[1] == point then table.remove(list, i) break end end
    list[#list + 1] = { point, relative, relativePoint or point, x or 0, y or 0 }
end
function Methods:SetAllPoints(relative)
    state[self].anchors = { { "TOPLEFT", relative, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0 } }
end
function Methods:SetTexture(file) state[self].file, state[self].atlas, state[self].colour = file, nil, nil; return true end
function Methods:SetAtlas(atlas) state[self].atlas, state[self].file = atlas, nil end
function Methods:SetColorTexture(...) state[self].colour, state[self].file, state[self].atlas = F(...), nil, nil end
function Methods:SetTexCoord(...) state[self].coords = F(...) end
function Methods:SetVertexColor(...) state[self].tint = F(...) end
function Methods:SetAlpha(a) state[self].alpha = a end
function Methods:Show() state[self].shown = true end
function Methods:Hide() state[self].shown = false end
function Methods:SetShown(on) state[self].shown = on and true or false end
function Methods:IsShown() return state[self].shown end
function Methods:SetFontObject(font) state[self].font = type(font) == "string" and font or tostring(font) end
function Methods:SetStatusBarTexture(file)
    if state[self].broken then error("this bar is broken") end
    state[self].fill = file
end
function Methods:SetStatusBarColor(...) state[self].fillColour = F(...) end
function Methods:GetAttribute(key) return state[self].attributes and state[self].attributes[key] end
function Methods:GetChildren() return unpack(state[self].children) end
function Methods:CreateTexture(_, layer, _, sublevel)
    made.regions = made.regions + 1
    local texture = Object("Texture", self)
    state[texture].layer, state[texture].sublevel = layer, sublevel
    state[self].own = texture
    return texture
end
function Methods:RegisterEvent(event) state[self].events[event] = true end
function Methods:SetScript(script, fn)
    if state[self].sealed then error("a script set on the game's " .. tostring(state[self].name)) end
    state[self].scripts[script] = fn
end

-- The game -----------------------------------------------------------------------
local combat, later = false, {}
InCombatLockdown = function() return combat end
issecretvalue = function(value) return value == SECRET end
C_Timer = { After = function(seconds, fn) later[#later + 1] = { seconds, fn } end }
local function NextFrame()
    local due = later
    later = {}
    for _, entry in ipairs(due) do entry[2]() end
    return #due
end
local own = {} -- EraUI's own frames
CreateFrame = function(kind, name, parent)
    made.frames = made.frames + 1
    local frame = Object(kind, parent, name)
    state[frame].events, state[frame].scripts = {}, {}
    own[#own + 1] = frame
    return frame
end
local function Fire(event)
    for _, frame in ipairs(own) do
        local handler = state[frame].scripts.OnEvent
        if handler and state[frame].events[event] then handler(frame, event) end
    end
end

local timers, selection
local function Game()
    MirrorTimerContainer = Object("Frame", nil, "MirrorTimerContainer")
    timers = {}
    for i = 1, 3 do
        local timer = Object("Frame", MirrorTimerContainer, "MirrorTimer" .. i)
        state[timer].w, state[timer].h = 206, 32
        local bar = Put(timer, "StatusBar", Object("StatusBar", timer, "MirrorTimer" .. i .. "StatusBar"))
        state[bar].w, state[bar].h, state[bar].fill = 195, 13, "ui-castingbar-filling-standard"
        state[bar].anchors = { { "TOP", timer, "TOP", 0, -2 } }
        local plate = Put(timer, "TextBorder", Object("Texture", timer, "TextBorder"))
        state[plate].atlas = "ui-castingbar-textbox"
        local border = Put(timer, "Border", Object("Texture", timer, "Border"))
        state[border].atlas = "ui-castingbar-frame"
        state[border].anchors = { { "TOPLEFT", bar, "TOPLEFT", -2, 2 }, { "BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2 } }
        local label = Put(timer, "Text", Object("FontString", timer, "Text"))
        state[label].font = "GameFontHighlightSmall"
        state[label].anchors = { { "TOPLEFT", bar, "BOTTOMLEFT", 0, 0 }, { "BOTTOMRIGHT", plate, "BOTTOMRIGHT", 0, 2 } }
        for _, piece in ipairs({ timer, bar, plate, border, label }) do Sealed(piece) end
        timers[i] = timer
    end
    selection = Sealed(Object("Frame", MirrorTimerContainer, "Selection"))
    state[MirrorTimerContainer].children = { timers[1], timers[2], timers[3], selection }
    Sealed(MirrorTimerContainer)
end

local settings, ns, modules, order, themed, reported
geterrorhandler = function() return function(problem) reported[#reported + 1] = tostring(problem) end end
local function Load()
    settings, modules, order, themed, reported = {}, {}, {}, {}, {}
    own, later, made, combat = {}, {}, { frames = 0, regions = 0 }, false
    Game()
    ns = {}
    ns.RegisterModule = function(key, entry) modules[key] = entry; order[#order + 1] = key end
    ns.ThemeTexture = function(texture, key) themed[#themed + 1] = key; if settings.darkMode then texture:SetVertexColor(.42, .44, .48) end end
    local E = { Classic = ns, GetSetting = function(_, key) return settings[key] end }
    -- The shared base, the cast art (Look/CastKit.lua, before it in the .toc), the timers.
    for _, file in ipairs({ "Look/Base.lua", "Look/CastKit.lua", "Look/MirrorTimers.lua" }) do assert(loadfile(file))("EraUI", E) end
end
local function Where(obj, i)
    local a = state[obj].anchors[i or 1]
    if not a then return "none" end
    local relative = a[2] and (state[a[2]].name or state[a[2]].kind) or "nil"
    return a[1] .. ">" .. relative .. ":" .. a[3] .. "(" .. F(a[4], a[5]) .. ")"
end

-- 1. Before it applies: nothing made, nothing touched ------------------------------
Load()
equal(order[1], "mirrorTimers", "registered as mirrorTimers")
equal(modules.mirrorTimers.init, nil, "no login step")
equal(made.frames .. " " .. made.regions, "0 0", "loaded: no frame or texture made yet")
modules.mirrorTimers.restore()
equal(made.frames .. " " .. made.regions .. " " .. tostring(ns.needsReload), "0 0 true", "off from the start: nothing made, the reload flag set")
equal(state[timers[1].TextBorder].alpha, 1, "and the plate as the game has it")

-- 2. Applied: each timer in the 1.x look --------------------------------------------
Load()
rawset(timers[1], "timer", "BREATH")
rawset(timers[2], "timer", "EXHAUSTION")
modules.mirrorTimers.apply()
equal(made.frames .. " " .. made.regions, "1 3", "one event frame, one dark strip per timer")
for i, timer in ipairs(timers) do
    local s, bar = state[timer], state[timer.StatusBar]
    equal(s.w .. "x" .. s.h, "206x26", "timer " .. i .. ": 206 x 26")
    local strip = state[s.own]
    equal(strip.layer .. " " .. strip.sublevel .. " " .. strip.colour .. " " .. tostring(strip.shown), "BACKGROUND 0 0,0,0,0.5 true",
        "timer " .. i .. ": EraUI's strip, black at half alpha, behind")
    equal(Where(s.own, 1) .. " " .. Where(s.own, 2), "TOPLEFT>MirrorTimer" .. i .. ":TOPLEFT(5,-2) BOTTOMRIGHT>MirrorTimer" .. i
        .. ":BOTTOMRIGHT(-5,11)", "timer " .. i .. ": the strip 196 x 13 behind the bar")
    equal(bar.w .. "x" .. bar.h .. " " .. #bar.anchors .. " " .. Where(timer.StatusBar), "195x13 1 TOP>MirrorTimer" .. i .. ":TOP(0,-2)",
        "timer " .. i .. ": the bar 195 x 13 at the top")
    equal(bar.fill, "Interface\\TargetingFrame\\UI-StatusBar", "timer " .. i .. ": the shaded 1.x fill")
    local border = state[timer.Border]
    equal(tostring(border.file) .. " " .. border.coords .. " " .. border.w .. "x" .. border.h .. " " .. #border.anchors .. " "
        .. Where(timer.Border), "Interface\\CastingBar\\UI-CastingBar-Border 0,1,0,1 256x64 1 TOP>MirrorTimer" .. i .. ":TOP(0,25)",
        "timer " .. i .. ": the cast bar's border round it")
    equal(state[timer.TextBorder].alpha, 0, "timer " .. i .. ": no plate under the label")
    local label = state[timer.Text]
    equal(label.font .. " " .. #label.anchors .. " " .. Where(timer.Text), "GameFontHighlight 1 TOP>MirrorTimer" .. i .. ":TOP(0,-2)",
        "timer " .. i .. ": the label on the bar")
end
equal(state[timers[1].StatusBar].fillColour .. " " .. state[timers[2].StatusBar].fillColour .. " " .. state[timers[3].StatusBar].fillColour,
    "0,0.5,1 1,0.9,0 0,0.5,1", "breath blue, fatigue yellow, a timer not running blue")
equal(state[selection].own == nil and state[selection].w == 0, true, "Edit Mode's selection (no StatusBar) left alone")
equal(table.concat(themed, ","), "castBorder,castBorder,castBorder", "each border through Dark Mode's tint, as castBorder")
local events = {}
for event in pairs(state[own[1]].events) do events[#events + 1] = event end
table.sort(events)
equal(table.concat(events, " "), "MIRROR_TIMER_START MIRROR_TIMER_STOP PLAYER_ENTERING_WORLD", "the three events, not the pause")

-- The kind: the timer field, else a type field, else the attribute, else breath.
local function Colour(set)
    Load()
    set(timers[1])
    modules.mirrorTimers.apply()
    return state[timers[1].StatusBar].fillColour
end
equal(Colour(function(t) rawset(t, "timer", "DEATH") end), "1,0.7,0", "DEATH")
equal(Colour(function(t) rawset(t, "timer", "FEIGNDEATH") end), "1,0.7,0", "feign death")
equal(Colour(function(t) rawset(t, "timer", "SOMETHING") end), "0,0.5,1", "an unknown kind: breath's blue")
equal(Colour(function(t) rawset(t, "type", "EXHAUSTION") end), "1,0.9,0", "a type field")
equal(Colour(function(t) state[t].attributes = { timer = "EXHAUSTION" } end), "1,0.9,0", "the timer attribute")
equal(Colour(function(t) rawset(t, "timer", SECRET); rawset(t, "type", "EXHAUSTION") end), "1,0.9,0", "a hidden timer field is passed over")
equal(Colour(function() end), "0,0.5,1", "nothing at all: breath")

-- 3. The game sets a timer up again: EraUI's look back a frame later ---------------
Load()
modules.mirrorTimers.apply()
local function GameSetup(timer)
    local bar = timer.StatusBar
    state[bar].fill = "ui-castingbar-filling-applyingcrafting"
    rawset(timer, "timer", "BREATH")
end
for _, event in ipairs({ "MIRROR_TIMER_START", "MIRROR_TIMER_STOP", "PLAYER_ENTERING_WORLD" }) do
    GameSetup(timers[2])
    Fire(event)
    equal(state[timers[2].StatusBar].fill, "ui-castingbar-filling-applyingcrafting", event .. ": nothing inside the game's own setup")
    equal(NextFrame(), 1, event .. ": one dressing booked, a frame later")
    equal(state[timers[2].StatusBar].fill, "Interface\\TargetingFrame\\UI-StatusBar", event .. ": the 1.x fill back")
end
equal(made.frames .. " " .. made.regions, "1 3", "nothing new made on later passes and events")
-- In a fight too (the timers aren't protected).
combat = true
GameSetup(timers[3])
Fire("MIRROR_TIMER_START")
NextFrame()
equal(state[timers[3].StatusBar].fill .. " " .. state[timers[3].StatusBar].fillColour, "Interface\\TargetingFrame\\UI-StatusBar 0,0.5,1",
    "underwater in a fight: dressed all the same")
combat = false

-- The fill doesn't follow Flat Bars; the bundled copy when chosen.
settings.flatBars = true
modules.mirrorTimers.apply()
equal(state[timers[1].StatusBar].fill, "Interface\\TargetingFrame\\UI-StatusBar", "Flat Bars on: the timers keep the shaded fill")
ns.db = { textureSource = "bundled" }
modules.mirrorTimers.apply()
equal(state[timers[1].StatusBar].fill, "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-StatusBar", "the bundled art when chosen")
ns.db = nil

-- Dark Mode: the border tinted the Darkness grey.
Load()
settings.darkMode = true
modules.mirrorTimers.apply()
equal(state[timers[1].Border].tint, "0.42,0.44,0.48", "Dark Mode: the border grey")

-- 4. One timer that errors: the others are still dressed ------------------------
Load()
state[timers[1].StatusBar].broken = true
modules.mirrorTimers.apply()
equal(#reported .. " " .. state[timers[2].StatusBar].fill .. " " .. state[timers[3].StatusBar].fill,
    "1 Interface\\TargetingFrame\\UI-StatusBar Interface\\TargetingFrame\\UI-StatusBar", "an error is reported, the other timers dressed")
reported = {}

-- 5. Off: the strip hidden, the plate back, the reload flag; events do nothing ---
Load()
modules.mirrorTimers.apply()
ns.needsReload = nil
modules.mirrorTimers.restore()
for i, timer in ipairs(timers) do
    equal(tostring(state[state[timer].own].shown) .. " " .. state[timer.TextBorder].alpha, "false 1", "timer " .. i .. ": strip hidden, plate back")
end
equal(ns.needsReload, true, "the reload flag set")
equal(state[timers[1].StatusBar].fill .. " " .. state[timers[1]].w, "Interface\\TargetingFrame\\UI-StatusBar 206",
    "the rest stays until the reload")
GameSetup(timers[1])
Fire("MIRROR_TIMER_START")
equal(NextFrame() .. " " .. state[timers[1].StatusBar].fill, "0 ui-castingbar-filling-applyingcrafting", "off: an event dresses nothing")
modules.mirrorTimers.restore()
equal(made.frames .. " " .. made.regions, "1 3", "restore again: cheap, nothing made")
modules.mirrorTimers.apply()
equal(tostring(state[state[timers[1]].own].shown) .. " " .. state[timers[1].TextBorder].alpha .. " " .. made.regions, "true 0 3",
    "on again: the same strip shown, the plate faded")

-- Every game frame and piece above is sealed: a key written on one would have failed.
equal(table.concat(reported, " | "), "", "no error reported along the way")
print("Mirror timer checks passed: " .. checks .. " assertions.")
