-- The breath, fatigue and feign death timers in the 1.x look (registry entry
-- "mirrorTimers", on with Cast Bars): the cast bar's border round a plain
-- bar, blue for breath and yellow while you tire, the label on the bar
-- instead of on a plate. EraUI never moves the game's timer stack (an Edit
-- Mode frame); it only dresses the three timers in it, running or not, and
-- does so in fights too (they aren't protected).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local state = { on = false }
local backings = Look.Weak() -- a timer frame: EraUI's dark strip behind its bar
local watcher

-- Each timer's colour by the game's name for it; breath's blue for any other.
local TINT = {}
for kind, r, g, b in ("BREATH=0/0.5/1 EXHAUSTION=1/0.9/0 DEATH=1/0.7/0 FEIGNDEATH=1/0.7/0"):gmatch("(%u+)=([%d.]+)/([%d.]+)/([%d.]+)") do
    TINT[kind] = { tonumber(r), tonumber(g), tonumber(b) }
end

local function Word(value)
    if Look.Secret(value) or type(value) ~= "string" then return nil end
    return value
end

-- Which timer this frame shows: its own field, a type field, its attribute.
local function TimerKind(frame)
    local kind = Word(frame.timer) or Word(frame.type)
    if kind then return kind end
    local asked, named = Look.Ask(frame, "GetAttribute", "timer")
    return (asked and Word(named)) or "BREATH"
end

-- EraUI's 196 x 13 dark strip behind the bar, made once per timer.
local function Backing(frame)
    local backing = backings[frame]
    if not backing then
        backing = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
        backing:SetColorTexture(0, 0, 0, 0.5)
        backings[frame] = backing
    end
    Look.Pin(backing, "TOPLEFT", frame, "TOPLEFT", 5, -2)
    backing:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 11)
    Look.Shown(backing, true)
end

local function DressTimer(frame)
    frame:SetSize(206, 26)
    Backing(frame)
    local meter = frame.StatusBar
    meter:SetSize(195, 13)
    Look.Pin(meter, "TOP", frame, "TOP", 0, -2)
    meter:SetStatusBarTexture(Look.FirstPath("statusBar"))
    meter:SetStatusBarColor(unpack(TINT[TimerKind(frame)] or TINT.BREATH))
    local edge = frame.Border
    if edge then
        Look.Art(edge, "castBorder")
        Look.Crop(edge, 0, 1, 0, 1)
        edge:SetSize(256, 64)
        Look.Pin(edge, "TOP", frame, "TOP", 0, 25)
    end
    Look.Alpha(frame.TextBorder, 0)
    local label = frame.Text
    if label then
        label:SetFontObject("GameFontHighlight")
        Look.Pin(label, "TOP", frame, "TOP", 0, -2)
    end
end

-- The timers in the game's stack (its children that carry a StatusBar).
local function Timers()
    local found = {}
    local stack = MirrorTimerContainer
    if stack and type(stack.GetChildren) == "function" then
        for _, child in ipairs({ stack:GetChildren() }) do
            if type(child) == "table" and child.StatusBar then found[#found + 1] = child end
        end
    end
    return found
end

local function DressTimers()
    if state.on then
        for _, frame in ipairs(Timers()) do Look.Try(DressTimer, frame) end
    end
end

-- The game sets a timer up afresh (its modern fill back) on these events:
-- EraUI's look goes back on a frame later, outside the game's own setup.
local function AfterSetup()
    if state.on then C_Timer.After(0, DressTimers) end
end

local function TimersOn()
    state.on = true
    if not watcher then
        watcher = CreateFrame("Frame")
        for _, event in ipairs(Look.Words("MIRROR_TIMER_START MIRROR_TIMER_STOP PLAYER_ENTERING_WORLD")) do
            Look.Listen(watcher, event)
        end
        watcher:SetScript("OnEvent", AfterSetup)
    end
    DressTimers()
end

-- Off (every pass while it's off): EraUI's strip hidden, the plate back.
-- The rest comes back with the reload.
local function TimersOff()
    state.on = false
    for _, frame in ipairs(Timers()) do
        Look.Shown(backings[frame], false)
        Look.Alpha(frame.TextBorder, 1)
    end
    ns.needsReload = true
end

ns.RegisterModule("mirrorTimers", { apply = TimersOn, restore = TimersOff })
