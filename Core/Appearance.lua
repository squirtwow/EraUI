local _, EraUI = ...
local ns = EraUI.Classic
local decorative = {}
for key in ("questLogTopLeft questLogTopRight questLogBotLeft questLogBotRight questLogDualLeft questLogDualRight questLogEmptyTopLeft questLogEmptyTopRight questLogEmptyBotLeft questLogEmptyBotRight questLogTabLeft questLogTabMiddle questLogTabRight endCap barBody barKeyring maxLevel slotEmpty slotNormal targetingFrame targetingElite targetingRare targetingRareElite targetingMinus targetOfTarget smallTargetingFrame levelBackground castBorder castBorderSmall minimapBorder minimapBackground trackingBorder nameplateBorder frameMetal frameMetalH frameMetalV frameSheet marbleBg rockBg tabActive tabInactive optionsTabActive optionsTabInactive scrollKnob charScrollBar lootPanel merchantBottom merchantLabelSlots bagComponents backpackBg bankFloor skillsBarBorder charGeneralTopLeft charGeneralTopRight charGeneralBotLeft charGeneralBotRight"
    -- Added with the Darkness slider: the minimap's ring, zoom buttons and
    -- clock, the reputation bar's frame and the latency bar. Frame art only;
    -- icons (bags, micro menu) keep their colours.
    .." compassRing zoomInUp zoomInDown zoomInDisabled zoomOutUp zoomOutDown zoomOutDisabled clockBackground repBar performanceBar"
    -- And the gold ring of Forever's day/night button (its moon and sun keep their colours).
    .." dielBorder"):gmatch("%S+") do decorative[key]=true end

-- Darkness: 40 (light grey) to 90 (near black); 58 is the original Dark Mode
-- grey (.42, .44, .48). The slight blue of that grey is kept at every step.
ns.DARKNESS_MIN, ns.DARKNESS_MAX, ns.DARKNESS_DEFAULT = 40, 90, 58
function ns.DarkGrey()
    local d = tonumber(EraUI:GetSetting("darkModeDarkness")) or ns.DARKNESS_DEFAULT
    d = math.max(ns.DARKNESS_MIN, math.min(ns.DARKNESS_MAX, d))
    local v = 1 - d / 100
    return v, math.min(1, v * 44 / 42), math.min(1, v * 48 / 42)
end

-- Textures given the dark grey, so the slider can re-tint them live. Weak
-- keys: a texture the game lets go of drops out by itself.
local tinted = setmetatable({}, { __mode = "k" })
-- Class-coloured borders and their full class colour, for "Darken class
-- colours too" (off unless ticked).
local classTinted = setmetatable({}, { __mode = "k" })

-- How much darker than the original grey the slider is: 1 at 58 (or less),
-- down to about a quarter at 90. Class colours are multiplied by it.
local function ClassShade()
    if not EraUI:GetSetting("darkenClassColours") then return 1 end
    return math.min(1, (ns.DarkGrey()) / .42)
end

local function PaintClass(texture, r, g, b)
    local f = ClassShade()
    texture:SetVertexColor(r * f, g * f, b * f)
end

-- Texture-only, called by EraUI's existing artwork application. No scanning,
-- native setter hooks, timers, geometry changes, or protected value reads.
function ns.ThemeTexture(texture,key)
    if not texture or not EraUI:GetSetting("darkMode") or not decorative[key] then return end
    local borderUnit
    local owner=texture
    while owner do
        if owner==CharacterFrame or owner==PartyFrame or owner==CompactRaidFrameContainer then return end
        if owner==PlayerFrame then borderUnit="player"
        elseif owner==TargetFrame then borderUnit="target"
        elseif owner==FocusFrame then borderUnit="focus" end
        local name=owner.GetName and owner:GetName()
        if name and (name:match("^PartyMemberFrame") or name:match("^CompactParty") or name:match("^CompactRaid") or name:match("^RaidFrame")) then return end
        owner=owner.GetParent and owner:GetParent()
    end
    -- Normal frame shell only: leave rare/elite classification art and all
    -- fills, icons, flash/status textures under their existing ownership.
    local isPlayer=borderUnit and UnitIsPlayer(borderUnit)
    if issecretvalue and issecretvalue(isPlayer) then isPlayer=false end
    if isPlayer and key=="targetingFrame" and EraUI:GetSetting("classColourBorders") then
        local _,class=UnitClass(borderUnit)
        if not (issecretvalue and issecretvalue(class)) then
            local colour=(CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[class])
                or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
            if class=="PALADIN" then colour={r=.96,g=.55,b=.73} end
            if colour then
                tinted[texture]=nil
                classTinted[texture]={colour.r,colour.g,colour.b}
                PaintClass(texture,colour.r,colour.g,colour.b);return
            end
        end
    end
    classTinted[texture]=nil
    tinted[texture]=true
    texture:SetVertexColor(ns.DarkGrey())
end

-- Dark Windows (on with Dark Mode, its own tick): what Dark Mode left light
-- in EraUI's classic windows follows the Darkness slider too. The red panel
-- buttons lose their red and take a lifted grey: a dark grey at Darkness 58,
-- near black with faint lighter edges at 90. Their glow only loses its
-- colour. Frame art (the game menu's border and header plate, the
-- Professions window's frame) takes the grey itself. Parchment (the
-- spellbook's and professions book's pages) goes a darker brown-grey, held
-- at PAGE_FLOOR from about Darkness 80 on so the text on it stays readable,
-- and the small dark text on it ("Passive", the page number) turns a light
-- warm grey-gold. Labels and spell names keep their gold. Only colours are
-- set, Blizzard's own pieces included; each piece keeps the look it was last
-- given, so a pass with nothing new sets nothing, and force paints it again
-- after the game redraws it. Off, a piece gets its own colours back once and
-- is then left alone; one Dark Mode tints by itself keeps that grey.
local BUTTON_LIFT, BUTTON_GAIN = .1, 2
local PAGE_LIFT, PAGE_GAIN, PAGE_FLOOR = .36, .43, .45
local PAGE_TEXT = { .87, .81, .66 }
local DESATURATED = { button = true, glow = true }
local darkArt = setmetatable({}, { __mode = "k" })      -- texture: its role
local darkText = setmetatable({}, { __mode = "k" })     -- font string: its own colour
local darkBackdrop = setmetatable({}, { __mode = "k" }) -- backdrop frame: true
local darkLast = setmetatable({}, { __mode = "k" })     -- piece: the look it was last given

function ns.DarkWindowsOn()
    return (EraUI:GetSetting("enabled") and EraUI:GetSetting("darkMode") and EraUI:GetSetting("darkWindows"))
        and true or false
end

-- The buttons' grey: Dark Mode's, lifted so the art's own shading still shows.
local function Lifted()
    local r, g, b = ns.DarkGrey()
    return math.min(1, BUTTON_LIFT + r * BUTTON_GAIN), math.min(1, BUTTON_LIFT + g * BUTTON_GAIN),
        math.min(1, BUTTON_LIFT + b * BUTTON_GAIN)
end
ns.DarkButtonGrey = Lifted

-- Parchment's shade: darker with the slider, never below the floor; a touch
-- more blue than red takes the yellow out, for a brown-grey.
local function PageShade()
    local v = math.max(PAGE_FLOOR, math.min(1, PAGE_LIFT + (ns.DarkGrey()) * PAGE_GAIN))
    return v, v, math.min(1, v * 1.06)
end
ns.DarkPageShade = PageShade
ns.DARK_PAGE_FLOOR, ns.DARK_PAGE_TEXT = PAGE_FLOOR, PAGE_TEXT

-- A piece's look for its role: desaturated or not (nil: left as it is), and
-- its colour.
local function Look(role, on, texture)
    local desaturate
    if DESATURATED[role] then desaturate = on end
    if not on then
        if tinted[texture] then return desaturate, ns.DarkGrey() end
        return desaturate, 1, 1, 1
    end
    if role == "button" then return true, Lifted() end
    if role == "glow" then return true, 1, 1, 1 end
    if role == "page" then return nil, PageShade() end
    return nil, ns.DarkGrey()
end

local function Unchanged(piece, d, r, g, b)
    local last = darkLast[piece]
    return last ~= nil and last[1] == d and last[2] == r and last[3] == g and last[4] == b
end

local function Remember(piece, on, d, r, g, b)
    if not on then darkLast[piece] = nil return end
    local last = darkLast[piece] or {}
    last[1], last[2], last[3], last[4] = d, r, g, b
    darkLast[piece] = last
end

local function PaintArt(texture, force)
    local on = ns.DarkWindowsOn()
    if not on and not darkLast[texture] then return end
    local d, r, g, b = Look(darkArt[texture], on, texture)
    if on and not force and Unchanged(texture, d, r, g, b) then return end
    if d ~= nil then texture:SetDesaturated(d) end
    texture:SetVertexColor(r, g, b)
    Remember(texture, on, d, r, g, b)
end

local function PaintText(text, force)
    local on = ns.DarkWindowsOn()
    if not on and not darkLast[text] then return end
    local own = darkText[text]
    local r, g, b, a = own[1], own[2], own[3], own[4]
    if on then r, g, b = PAGE_TEXT[1], PAGE_TEXT[2], PAGE_TEXT[3] end
    if on and not force and Unchanged(text, nil, r, g, b) then return end
    text:SetTextColor(r, g, b, a)
    Remember(text, on, nil, r, g, b)
end

local function PaintBackdrop(frame, force)
    local on = ns.DarkWindowsOn()
    if not on and not darkLast[frame] then return end
    local r, g, b = 1, 1, 1
    if on then r, g, b = ns.DarkGrey() end
    if on and not force and Unchanged(frame, nil, r, g, b) then return end
    frame:SetBackdropBorderColor(r, g, b)
    if on then frame:SetBackdropColor(Lifted()) else frame:SetBackdropColor(1, 1, 1) end
    Remember(frame, on, nil, r, g, b)
end

-- Registered only while Dark Mode is loaded: it needs a reload to come on,
-- so a piece made without it never needs anything.
-- role: "frame" (the grey), "page" (parchment), "button" or "glow".
function ns.DarkWindowArt(texture, role, force)
    if not texture or not EraUI:GetSetting("darkMode") then return end
    darkArt[texture] = role or "frame"
    PaintArt(texture, force)
end

-- A red panel button's Normal, Pushed and Disabled art, and its glow.
local BUTTON_STATES = { { "GetNormalTexture", "button" }, { "GetPushedTexture", "button" },
    { "GetDisabledTexture", "button" }, { "GetHighlightTexture", "glow" } }
function ns.DarkRedButton(button)
    if not button or not EraUI:GetSetting("darkMode") then return end
    for _, state in ipairs(BUTTON_STATES) do
        local get = button[state[1]]
        local texture = get and get(button)
        if texture then ns.DarkWindowArt(texture, state[2]) end
    end
end

-- Dark text on parchment; its own colour is kept for when Dark Windows is off.
function ns.DarkWindowText(text)
    if not text or not EraUI:GetSetting("darkMode") then return end
    if not darkText[text] then darkText[text] = { text:GetTextColor() } end
    PaintText(text)
end

-- A dialog box's backdrop: its border takes the grey, its fill the buttons'.
function ns.DarkBackdrop(frame)
    if not frame or not frame.SetBackdropBorderColor or not EraUI:GetSetting("darkMode") then return end
    darkBackdrop[frame] = true
    PaintBackdrop(frame)
end

-- Every piece, after the tick, Dark Mode or the Darkness slider changes.
function ns.RefreshDarkWindows()
    for texture in pairs(darkArt) do PaintArt(texture) end
    for text in pairs(darkText) do PaintText(text) end
    for frame in pairs(darkBackdrop) do PaintBackdrop(frame) end
end

-- The Darkness slider and its class colour tick: re-tint what Dark Mode has
-- already tinted, at once.
function ns.RefreshDarkness()
    if not EraUI:GetSetting("darkMode") then return end
    local r, g, b = ns.DarkGrey()
    for texture in pairs(tinted) do texture:SetVertexColor(r, g, b) end
    for texture, c in pairs(classTinted) do PaintClass(texture, c[1], c[2], c[3]) end
    -- Dark Aura Borders' grey line and the tooltips' bevel darken with the
    -- slider too, and so do the menu bar's frames (Dark Menu Bar) and the
    -- classic windows' buttons, boxes and pages (Dark Windows).
    local auras = EraUI.modules.AuraStyle
    if auras and auras.RefreshDarkness then auras:RefreshDarkness() end
    if ns.RefreshDarkMenuBar then ns.RefreshDarkMenuBar() end
    ns.RefreshDarkWindows()
end
