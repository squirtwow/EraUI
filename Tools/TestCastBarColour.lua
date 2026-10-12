-- Cast Bar Colour (/era: Casting) on the real Classic/CastBars.lua,
-- Classic/Textures.lua, Classic/Skin.lua and Core/Appearance.lua, against
-- the game's player, pet, target, focus and boss cast bars as Forever builds
-- them (the same sealed mock as Tools/TestRoundedCastBars.lua: writing a key
-- on the game's bars fails, and EraUI running one of the game's own methods
-- fails). Checked: Match look (the default) is today's colours exactly
-- without Dark Mode, at every step of a cast, a channel, a finish, an
-- interrupt and a cast that can't be interrupted, on every bar; with Dark
-- Mode it is the light grey, following a Dark Mode switch; Yellow, Grey,
-- Class and Custom colour the player's and pet's casts and channels (and a
-- channel's end), interrupted casts stay red, ones that can't be interrupted
-- grey (even after the game shows the bar again with EraUI's own fill), a
-- finished cast still flashes green; the target's, focus's and bosses' bars
-- keep the Classic colours whatever is chosen; the choice applies live,
-- mid-cast, to the player's and pet's bars only; Flat Bars and Rounded Cast
-- Bars on and off keep the colour; secret atlas names and a secret class are
-- never used. (The /era rows: Tools/TestSettingsLayout.lua; the saved
-- choice: Tools/TestPersistence.lua.)
local checks = 0
local function equal(a, b, label)
    checks = checks + 1
    assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
unpack = unpack or table.unpack
-- A colour as text, to six figures.
local function Col(c) return string.format("%g,%g,%g,%g", c[1], c[2], c[3], c[4] or 1) end

-- Mock objects ------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- per-object state, never on the object
-- A secret value that isn't a number: anything but passing it on fails.
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end,
    __index = function() error("indexed a secret value", 2) end })
local SECRET_NUM = 4321.5 -- a secret number: still a number, as the game's are
local leaks = {} -- setters given a secret value they don't take
local blizzardCalling = false
local Proto = {}
local made = {} -- frames made by EraUI, in order
local regions = {} -- textures and font strings made by EraUI, in order
local order = 0

local function New(kind, parent, name, layer)
    local obj = {}
    order = order + 1
    S[obj] = { kind = kind, parent = parent, name = name, layer = layer, points = {}, w = 0, h = 0, alpha = 1, shown = true,
        tint = { 1, 1, 1, 1 }, coords = { 0, 1, 0, 1 }, blend = "BLEND", writes = 0, scripts = {}, hooks = {}, level = 1,
        justify = "CENTER", order = order }
    return setmetatable(obj, {
        __index = function(_, key) return Proto[key] end,
        __newindex = function(t, key, value)
            if S[t].sealed then error("wrote key '" .. tostring(key) .. "' on a Blizzard object", 2) end
            rawset(t, key, value)
        end,
    })
end
local function Seal(obj) S[obj].sealed = true end

-- Every setter: a secret value only where the game takes one from an addon
-- (texture, text), and a write by EraUI on the game's objects counted.
local SECRET_OK = { SetTexture = true, SetText = true, SetFormattedText = true }
local function Setter(name, fn)
    Proto[name] = function(self, ...)
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            if (v == SECRET or v == SECRET_NUM) and not SECRET_OK[name] then
                leaks[#leaks + 1] = name
                error(name .. " was given a secret value")
            end
        end
        if S[self].sealed and not blizzardCalling then S[self].writes = S[self].writes + 1 end
        return fn(self, ...)
    end
end

Setter("ClearAllPoints", function(self) S[self].points = {} end)
Setter("SetPoint", function(self, point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    table.insert(S[self].points, { point, rel or S[self].parent, relPoint or point, x or 0, y or 0 })
end)
Setter("SetAllPoints", function(self, rel)
    rel = rel or S[self].parent
    S[self].points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end)
Setter("SetSize", function(self, w, h) S[self].w, S[self].h = w, h end)
Setter("SetWidth", function(self, w) S[self].w = w end)
Setter("SetHeight", function(self, h) S[self].h = h end)
Setter("SetAtlas", function(self, atlas)
    local s = S[self]
    s.atlas, s.texture, s.colour = atlas, nil, nil
    s.coords = { 0, 1, 0, 1 }
end)
Setter("SetTexture", function(self, texture)
    local s = S[self]
    s.texture, s.atlas, s.colour = texture, nil, nil
    return true
end)
Setter("SetColorTexture", function(self, r, g, b, a)
    local s = S[self]
    s.colour, s.atlas, s.texture = { r, g, b, a or 1 }, nil, nil
end)
Setter("SetTexCoord", function(self, ...) S[self].coords = { ... } end)
Setter("SetVertexColor", function(self, r, g, b, a) S[self].tint = { r, g, b, a or 1 } end)
Setter("SetBlendMode", function(self, mode) S[self].blend = mode end)
Setter("SetFontObject", function(self, font)
    if type(font) == "string" then font = _G[font] end
    S[self].font = font
end)
Setter("SetJustifyH", function(self, justify) S[self].justify = justify end)
Setter("SetAlpha", function(self, a) S[self].alpha = a end)
Setter("Show", function(self) S[self].shown = true end)
Setter("Hide", function(self) S[self].shown = false end)
Setter("SetShown", function(self, v) S[self].shown = v and true or false end)
Setter("SetStatusBarTexture", function(self, texture)
    local fill = S[self].fill
    S[fill].texture, S[fill].atlas = texture, nil
end)
Setter("SetStatusBarColor", function(self, r, g, b, a) S[self].rgb = { r, g, b, a or 1 } end)
Setter("SetScale", function(self, scale) S[self].scale = scale end)
Setter("SetMinMaxValues", function(self, low, high) S[self].low, S[self].high = low, high end)
Setter("SetValue", function(self, value) S[self].value = value end)
-- As in the game, a font string made without a font can't take text until
-- it has one.
local function FontSet(self, method)
    if S[self].kind == "FontString" and not S[self].font then error(method .. ": Font not set", 3) end
end
Setter("SetText", function(self, text)
    FontSet(self, "SetText")
    S[self].text = text
end)
Setter("SetFormattedText", function(self, format, ...)
    FontSet(self, "SetFormattedText")
    local values = { ... }
    for _, v in ipairs(values) do if v == SECRET or v == SECRET_NUM then S[self].text = "<secret>"; return end end
    S[self].text = string.format(format, ...)
end)
Setter("SetFrameLevel", function(self, level) S[self].level = level end)
Setter("SetFrameStrata", function(self, strata) S[self].strata = strata end)
Setter("SetBackdrop", function(self, backdrop) S[self].backdrop = backdrop end)
Setter("SetBackdropColor", function(self, r, g, b, a) S[self].backdropColour = { r, g, b, a } end)
Setter("SetBackdropBorderColor", function(self, r, g, b, a) S[self].border = { r, g, b, a } end)
for _, name in ipairs({ "EnableMouse", "EnableMouseWheel", "SetMovable", "SetClampedToScreen", "RegisterForClicks",
    "RegisterForDrag", "SetFont", "SetNonSpaceWrap", "SetShadowColor", "SetShadowOffset", "SetTextColor" }) do
    Setter(name, function() end)
end
function Proto:SetScript(event, fn)
    if S[self].sealed then error("EraUI replaced a script on a Blizzard frame", 2) end
    S[self].scripts[event] = fn
end
function Proto:GetScript(event) return S[self].scripts[event] end
function Proto:HookScript(event, fn)
    local list = S[self].hooks[event] or {}
    list[#list + 1] = fn
    S[self].hooks[event] = list
end
function Proto:RegisterEvent(event) S[self].events = S[self].events or {}; S[self].events[event] = true end
Proto.RegisterUnitEvent = Proto.RegisterEvent
function Proto:UnregisterAllEvents() S[self].events = {} end

function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i)
    local p = S[self].points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Proto:GetSize() return S[self].w, S[self].h end
function Proto:GetWidth() return S[self].w end
function Proto:GetHeight() return S[self].h end
function Proto:GetAtlas() return S[self].atlas end
function Proto:GetTexture() return S[self].texture end
function Proto:GetTexCoord() return unpack(S[self].coords) end
function Proto:GetVertexColor() return unpack(S[self].tint) end
function Proto:GetBlendMode() return S[self].blend end
function Proto:GetFontObject() return S[self].font end
function Proto:GetJustifyH() return S[self].justify end
function Proto:GetAlpha() return S[self].alpha end
function Proto:IsShown() return S[self].shown end
function Proto:IsVisible()
    local s = S[self]
    if not s.shown then return false end
    return s.parent == nil or s.parent:IsVisible()
end
function Proto:GetParent() return S[self].parent end
function Proto:GetName() return S[self].name end
function Proto:GetText() return S[self].text end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:GetStatusBarColor()
    local c = S[self].rgb or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
end
function Proto:GetScale() return S[self].scale or 1 end
function Proto:IsProtected() return S[self].protected == true end
function Proto:GetFrameLevel() return S[self].level end
function Proto:GetValue() return S[self].secretValues and SECRET_NUM or S[self].value end
function Proto:GetMinMaxValues()
    if S[self].secretValues then return 0, SECRET_NUM end
    return S[self].low, S[self].high
end
function Proto:IsMouseOver() return false end
function Proto:GetStringWidth() return 0 end
function Proto:GetCenter() return 0, 0 end
function Proto:CreateTexture(name, layer, _, sublevel)
    local t = New("Texture", self, name, layer)
    S[t].sublevel = sublevel
    if not blizzardCalling then regions[#regions + 1] = t end
    return t
end
function Proto:CreateFontString(name, layer, template)
    local t = New("FontString", self, name, layer)
    if template then S[t].font = _G[template] end
    if not blizzardCalling then regions[#regions + 1] = t end
    return t
end

-- Blizzard's fonts, by name like the game's.
for _, name in ipairs({ "SystemFont_Shadow_Small", "GameFontHighlight", "GameFontHighlightSmall", "GameFontHighlightLarge",
    "GameFontNormalSmall" }) do _G[name] = { name = name } end

-- The game's code runs as itself; a hook runs as the addon's code.
local hooks = {} -- "object:method": how many post-hooks
hooksecurefunc = function(t, key, hook)
    if type(t) == "string" then t, key, hook = _G, t, key end
    local original = t[key]
    assert(type(original) == "function", "hooked a missing " .. tostring(key))
    local id = tostring(S[t] and S[t].name or "?") .. ":" .. key
    hooks[id] = (hooks[id] or 0) + 1
    rawset(t, key, function(...)
        local result = original(...)
        local was = blizzardCalling
        blizzardCalling = false
        hook(...)
        blizzardCalling = was
        return result
    end)
end
local function Blizzard(object, method, ...)
    local was = blizzardCalling
    blizzardCalling = true
    object[method](object, ...)
    blizzardCalling = was
end

-- The game and EraUI ----------------------------------------------------------------------

local combat = false
InCombatLockdown = function() return combat end
CreateFrame = function(kind, name, parent)
    local f = New(kind or "Frame", parent, name)
    if parent then S[f].level = S[parent].level + 1 end
    if kind == "StatusBar" then S[f].fill = New("Texture", f) end
    if name then _G[name] = f end
    made[#made + 1] = f
    return f
end
issecretvalue = function(v) return v == SECRET or v == SECRET_NUM end
GetTime = function() return 0 end
C_Timer = { After = function() end }
CreateColor = function(r, g, b) return { GetRGB = function() return r, g, b end } end
CreateFont = function() return { SetFontObject = function() end, SetTextColor = function() end } end
local units = {}
UnitIsPlayer = function(unit) return units[unit] and units[unit].player or false end
UnitClass = function(unit)
    local u = units[unit]
    if u and u.class then return u.class, u.class end
end
UnitCastingInfo = function() end
UnitChannelInfo = function() end
local durations = {} -- unit: what the game's duration object says is left
local function Duration(unit)
    local left = durations[unit]
    if left == "secret object" then return SECRET end
    if left == nil then return nil end
    return { GetRemainingDuration = function() return left end }
end
UnitCastingDuration = Duration
UnitChannelDuration = Duration
RAID_CLASS_COLORS = {
    HUNTER = { r = .67, g = .83, b = .45 }, MAGE = { r = .25, g = .78, b = .92 }, PALADIN = { r = .96, g = .55, b = .73 },
    WARRIOR = { r = .78, g = .61, b = .43 },
}

local PIECES = { "Border", "BorderShield", "Icon", "Spark", "Flash", "Background", "TextBorder", "Flakes01", "Text", "CastTimeText" }

-- A cast bar as the game builds it. small: SmallCastingBarFrameTemplate (the
-- target's, focus's and bosses'), else CastingBarFrameTemplate (the player's
-- and pet's, with the game's own cast time).
local function Bar(name, parent, small)
    local bar = New("StatusBar", parent, name)
    S[bar].fill = New("Texture", bar)
    S[bar].level = parent and S[parent].level - 1 or 3
    S[bar].w, S[bar].h = small and 150 or 208, small and 10 or 11
    S[bar].low, S[bar].high, S[bar].value = 0, 0, 0
    local function Region(key, kind, w, h, ...)
        local r = New(kind or "Texture", bar, nil, "ARTWORK")
        S[r].w, S[r].h = w or 0, h or 0
        for _, p in ipairs({ ... }) do table.insert(S[r].points, { p[1], bar, p[2] or p[1], p[3] or 0, p[4] or 0 }) end
        rawset(bar, key, r)
        return r
    end
    S[Region("TextBorder", nil, 0, 0, { "TOPLEFT" }, { "BOTTOMRIGHT", nil, 0, -12 })].atlas = "ui-castingbar-textbox"
    S[Region("Background", nil, 0, 0, { "TOPLEFT" }, { "BOTTOMRIGHT" })].atlas = "ui-castingbar-background"
    local shield = Region("BorderShield", nil, 29, 33, { "TOPLEFT", nil, -27, 4 })
    S[shield].atlas, S[shield].shown = "ui-castingbar-shield", false
    local icon = Region("Icon", nil, small and 20 or 16, small and 20 or 16, { "RIGHT", "LEFT", small and -2 or -5, small and -5 or 0 })
    S[icon].texture, S[icon].shown = 136048, small and true or false
    S[Region("Border", nil, 0, 0, { "TOPLEFT", nil, -1, 2 }, { "BOTTOMRIGHT", nil, 1, -2 })].atlas = "ui-castingbar-frame"
    S[Region("Spark", nil, 6, 16, { "CENTER" })].atlas = "ui-castingbar-pip"
    local flash = Region("Flash", nil, 0, 0, { "TOPLEFT", nil, -1, 1 }, { "BOTTOMRIGHT", nil, 1, -1 })
    S[flash].atlas, S[flash].blend = "ui-castingbar-full-glow-standard", "ADD"
    S[Region("Flakes01", nil, 20, 20, { "CENTER", nil, 0, -25 })].atlas = "Cast_Standard_Flakes01"
    local text = Region("Text", "FontString", small and 0 or 185, 16, { "TOP", nil, 0, -10 })
    S[text].font = small and SystemFont_Shadow_Small or GameFontHighlightSmall
    if not small then
        local castTime = Region("CastTimeText", "FontString", 0, 0, { "LEFT", "RIGHT", 10, 0 })
        S[castTime].font, S[castTime].shown = GameFontHighlightLarge, false
    end
    -- The game's own methods: EraUI may hook them, never run them.
    local function Method(method, fn)
        rawset(bar, method, function(self, ...)
            assert(blizzardCalling, "EraUI ran Blizzard's " .. method)
            if fn then return fn(self, ...) end
        end)
    end
    Method("SetLook", function(self, look) rawset(self, "look", look) end)
    Method("UpdateShownState", function(self, show) if show ~= nil then self:SetShown(show) end end)
    Method("UpdateBarFillTexture", function(self, atlas) S[S[self].fill].atlas, S[S[self].fill].texture = atlas, nil end)
    Method("ShowSpark", function(self) self.Spark:Show() end)
    Method("PlayFadeAnim")
    Method("PlayFinishAnim")
    Method("PlayInterruptAnims")
    -- A cast starting: the fill, the spark, the values, the name, the icon,
    -- then the bar shows (the order of CastingBarMixin:HandleCastStart).
    -- spec.atlas: the fill the game picks for the cast's type, when it's
    -- neither a plain cast nor a channel (one that can't be interrupted).
    Method("HandleCastStart", function(self, event, spec)
        self:UpdateBarFillTexture(spec.atlas or (spec.channel and "ui-castingbar-filling-channel" or "ui-castingbar-filling-standard"))
        self:ShowSpark()
        self:SetMinMaxValues(0, spec.total)
        self:SetValue(spec.channel and spec.total or 0)
        self.Text:SetText(spec.name)
        self.Icon:SetTexture(spec.icon)
        rawset(self, "casting", not spec.channel or nil)
        rawset(self, "channeling", spec.channel or nil)
        self:UpdateShownState(true)
    end)
    Method("FinishSpell", function(self)
        self:UpdateBarFillTexture("ui-castingbar-full-standard")
        self.Flash:Show()
        self:PlayFadeAnim()
        self:PlayFinishAnim()
        rawset(self, "casting", nil)
        rawset(self, "channeling", nil)
    end)
    Method("HandleChannelUpdateDelayed")
    Method("HandleCastStop")
    Method("HandleInterruptOrSpellFailed")
    if small then
        Method("AdjustPosition", function(self)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", self:GetParent(), "BOTTOMLEFT", 43, 5)
        end)
    end
    Seal(bar)
    Seal(S[bar].fill)
    for _, key in ipairs(PIECES) do if bar[key] then Seal(bar[key]) end end
    return bar
end

-- Everything the game's bar shows, as one line: its size and each piece's
-- art, place, size, tint, font, alignment, alpha and whether it shows.
local function Name(rel, bar)
    if rel == bar then return "bar" end
    if rel == nil then return "nil" end
    return S[rel].name or S[rel].kind
end
local function Look(bar)
    local s = S[bar]
    local out = { "size " .. tostring(s.w) .. "x" .. tostring(s.h) .. " scale " .. tostring(s.scale) }
    for _, key in ipairs(PIECES) do
        local r = bar[key] and S[bar[key]]
        if r then
            local points = {}
            for _, p in ipairs(r.points) do
                points[#points + 1] = p[1] .. ">" .. Name(p[2], bar) .. ":" .. tostring(p[3]) .. "(" .. tostring(p[4]) .. "," .. tostring(p[5]) .. ")"
            end
            local art = r.atlas or r.texture or (r.colour and table.concat(r.colour, ","))
            out[#out + 1] = key .. "[" .. tostring(art) .. " coords " .. table.concat(r.coords, ",") .. " tint " .. table.concat(r.tint, ",")
                .. " " .. r.blend .. " font " .. tostring(r.font and r.font.name) .. " " .. r.justify .. " alpha " .. tostring(r.alpha)
                .. " shown " .. tostring(r.shown) .. " " .. tostring(r.w) .. "x" .. tostring(r.h) .. " at " .. table.concat(points, " ") .. "]"
        end
    end
    return table.concat(out, " ")
end
local function Writes(bar)
    local n = S[bar].writes + S[S[bar].fill].writes
    for _, key in ipairs(PIECES) do if bar[key] then n = n + S[bar[key]].writes end end
    return n
end

-- A new game: the bars, EraUI's Classic files, and settings (Cast Bars on,
-- plus extra). The player is a paladin unless extra says otherwise.
local settings, ns, E, modules, booked, bars
local function Game(extra, class)
    combat = false
    made, regions, hooks, leaks, units, durations = {}, {}, {}, {}, {}, {}
    settings = { enabled = true, castBars = true, darkModeDarkness = 58 }
    for key, value in pairs(extra or {}) do settings[key] = value end
    units.player = { player = true, class = class or "PALADIN" }
    UIParent = New("Frame", nil, "UIParent")
    S[UIParent].level = 10
    local function Unit(name, unit)
        local frame = New("Button", UIParent, name)
        S[frame].level = 5
        local container = New("Frame", frame, name .. "AuraContainer")
        rawset(frame, "GetAuraContainer", function() return container end)
        local bar = Bar(name .. "SpellBar", frame, true)
        rawset(frame, "spellbar", bar)
        rawset(bar, "unit", unit)
        Seal(frame)
        return frame, bar
    end
    bars = {}
    PlayerCastingBarFrame = Bar("PlayerCastingBarFrame", UIParent)
    rawset(PlayerCastingBarFrame, "look", "CLASSIC")
    rawset(PlayerCastingBarFrame, "unit", "player")
    PetCastingBarFrame = Bar("PetCastingBarFrame", UIParent)
    rawset(PetCastingBarFrame, "look", "CLASSIC")
    rawset(PetCastingBarFrame, "unit", "pet")
    TargetFrame, bars.target = Unit("TargetFrame", "target")
    FocusFrame, bars.focus = Unit("FocusFrame", "focus")
    bars.player, bars.pet = PlayerCastingBarFrame, PetCastingBarFrame
    local frames = {}
    for i = 1, 3 do
        frames[i], bars["boss" .. i] = Unit("Boss" .. i .. "TargetFrame", "boss" .. i)
        rawset(bars["boss" .. i], "boss", "boss" .. i)
    end
    BossTargetFrameContainer = { BossTargetFrames = frames }
    EraUIDB = {}
    modules, booked = {}, 0
    ns = {}
    E = { Classic = ns, modules = {} }
    function E:GetSetting(key) return settings[key] end
    function E:GetSavedSetting(key) return settings[key] end
    function E:RegisterModule(name, mod) self.modules[name] = mod end
    function E:SaveSettings() end
    assert(loadfile("Classic/Textures.lua"))("EraUI", E)
    assert(loadfile("Core/Appearance.lua"))("EraUI", E)
    assert(loadfile("Classic/Skin.lua"))("EraUI", E)
    assert(loadfile("Core/CastTiming.lua"))("EraUI", E)
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.HookMethod = function(frame, method, fn)
        if type(frame[method]) ~= "function" then return false end
        hooksecurefunc(frame, method, fn)
        return true
    end
    -- A pass asked for in a fight runs at its end (Classic/Core.lua).
    ns.ApplyAll = function() booked = booked + 1 end
    assert(loadfile("Classic/CastBars.lua"))("EraUI", E)
    made, regions = {}, {} -- Appearance's own watch aside
end

local ALL = { "player", "pet", "target", "focus", "boss1", "boss2", "boss3" }
local OWN = { "player", "pet" }
local OTHERS = { "target", "focus", "boss1", "boss2", "boss3" }
local SOLID, SHADED = "Interface\\Buttons\\WHITE8X8", "Interface\\TargetingFrame\\UI-StatusBar"
local function C(r, g, b) return string.format("%.3f,%.3f,%.3f", r, g, b) end
-- The Classic colours, the light grey and a paladin's pink.
local Y, G, RED, GREY = C(1, .7, 0), C(0, 1, 0), C(1, 0, 0), C(.5, .5, .5)
local LIGHT, PINK = C(.78, .80, .84), C(.96, .55, .73)
local function Fill(key)
    local c = S[bars[key]].rgb
    return c and C(c[1], c[2], c[3]) or "none"
end
local function Texture(key) return S[S[bars[key]].fill].texture end
-- The game picks a bar's fill (UpdateBarFillTexture), shows the bar again
-- (UpdateShownState), starts a cast or channel, finishes a cast.
local function Atlas(key, atlas) Blizzard(bars[key], "UpdateBarFillTexture", atlas) end
local function Shown(key) Blizzard(bars[key], "UpdateShownState", true) end
local function Cast(key, spec)
    spec = spec or {}
    Blizzard(bars[key], "HandleCastStart", spec.channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", {
        name = "Holy Light", icon = 135920, total = 2, channel = spec.channel, atlas = spec.atlas })
end
local function Finish(key) Blizzard(bars[key], "FinishSpell") end

-- Every step of each kind of cast on one bar, and the fill's colour after
-- each: a cast (its fill, the bar shown again, its finish), a channel (its
-- fill, shown again, its end), a cast, an interrupt, a cast that can't be
-- interrupted (shown again), a whole channel, cast and can't-interrupt cast
-- as the game starts them, a tradeskill's fill and an empowered cast's
-- (no atlas). Each step's colour as one line.
local function Life(key)
    local out = {}
    local function Note(step) out[#out + 1] = step .. "=" .. Fill(key) end
    Atlas(key, "ui-castingbar-filling-standard"); Note("cast")
    Shown(key); Note("shown")
    Finish(key); Note("done")
    Atlas(key, "ui-castingbar-filling-channel"); Note("channel")
    Shown(key); Note("shown")
    Atlas(key, "ui-castingbar-full-channel"); Note("channelEnd")
    Atlas(key, "ui-castingbar-filling-standard"); Note("cast")
    Atlas(key, "ui-castingbar-interrupted"); Note("interrupted")
    Atlas(key, "ui-castingbar-uninterruptable"); Note("locked")
    Shown(key); Note("shown")
    Cast(key, { channel = true }); Note("channelStart")
    Cast(key); Note("castStart")
    Cast(key, { atlas = "ui-castingbar-uninterruptable" }); Note("lockedStart")
    Atlas(key, "ui-castingbar-filling-applyingcrafting"); Note("craft")
    Atlas(key, ""); Note("empowered")
    return table.concat(out, " ")
end
-- Today's colours at each of those steps, on every bar: a channel the game
-- shows again with EraUI's own fill (no atlas left to read) turns yellow, as
-- it always has, and so does a cast that can't be interrupted.
local TODAY = table.concat({ "cast=" .. Y, "shown=" .. Y, "done=" .. G, "channel=" .. G, "shown=" .. Y, "channelEnd=" .. G,
    "cast=" .. Y, "interrupted=" .. RED, "locked=" .. GREY, "shown=" .. Y, "channelStart=" .. Y, "castStart=" .. Y,
    "lockedStart=" .. Y, "craft=" .. Y, "empowered=" .. Y }, " ")
-- With a colour of its own (c): casts, channels and a channel's end in it,
-- also after the bar is shown again; a finish green, an interrupt red, a
-- cast that can't be interrupted grey.
local function Chosen(c)
    return table.concat({ "cast=" .. c, "shown=" .. c, "done=" .. G, "channel=" .. c, "shown=" .. c, "channelEnd=" .. c,
        "cast=" .. c, "interrupted=" .. RED, "locked=" .. GREY, "shown=" .. GREY, "channelStart=" .. c, "castStart=" .. c,
        "lockedStart=" .. GREY, "craft=" .. c, "empowered=" .. c }, " ")
end
-- Each bar's life in a new game with these settings.
local function Lives(extra, class)
    Game(extra, class)
    modules.castBars.apply()
    local out = {}
    for _, key in ipairs(ALL) do out[key] = Life(key) end
    return out
end

-- 1. Match look (the default) without Dark Mode: today's colours exactly -------------------
-- (Run against the cast bars before Cast Bar Colour, this section gives the
-- same lines, step by step, on every bar.)
for label, extra in pairs({ unset = {}, ["Match look"] = { castBarColour = "auto" }, Yellow = { castBarColour = "classic" },
    ["an unknown choice"] = { castBarColour = "purple" } }) do
    local lives = Lives(extra)
    for _, key in ipairs(ALL) do equal(lives[key], TODAY, label .. ", Classic look: " .. key .. "'s colours as today") end
    equal(Texture("player") .. " " .. Texture("target"), SHADED .. " " .. SHADED, label .. ": the Classic shaded fill")
end
-- A custom colour saved but not chosen changes nothing.
local lives = Lives({ castBarColour = "auto", castBarCustomColour = "FF8000" })
equal(lives.player .. " | " .. lives.pet, TODAY .. " | " .. TODAY, "a custom colour saved with Match look chosen: today's colours")

-- 2. Match look in Dark Mode: the light grey on your own and your pet's bar ---------------
lives = Lives({ darkMode = true })
for _, key in ipairs(OWN) do equal(lives[key], Chosen(LIGHT), "Dark Mode, Match look: " .. key .. " in the light grey") end
for _, key in ipairs(OTHERS) do equal(lives[key], TODAY, "Dark Mode: " .. key .. " keeps the Classic colours") end
-- Dark Mode switched (it applies with its reload: the setting as loaded):
-- the next cast follows, and so does the colour on show at once.
Game({ darkMode = true })
modules.castBars.apply()
Cast("player"); Cast("pet", { channel = true })
equal(Fill("player") .. " " .. Fill("pet"), LIGHT .. " " .. LIGHT, "Dark Mode: a cast and a channel in the light grey")
settings.darkMode = nil
Cast("player")
equal(Fill("player"), Y, "Dark Mode off: the next cast is Classic yellow")
ns.RefreshCastColours()
equal(Fill("pet"), G, "and the pet's channel on show takes the Classic channel green at once")
settings.darkMode = true
ns.RefreshCastColours()
equal(Fill("player") .. " " .. Fill("pet"), LIGHT .. " " .. LIGHT, "Dark Mode on again: both light grey at once")
-- Picking Yellow in Dark Mode keeps the Classic colours.
lives = Lives({ darkMode = true, castBarColour = "classic" })
equal(lives.player .. " | " .. lives.pet, TODAY .. " | " .. TODAY, "Dark Mode with Yellow chosen: the Classic colours")

-- 3. Each choice on your own and your pet's bar; the others keep the Classic colours -----
local function Each(label, extra, colour, class)
    local got = Lives(extra, class)
    for _, key in ipairs(OWN) do equal(got[key], Chosen(colour), label .. ": " .. key .. "'s casts and channels") end
    for _, key in ipairs(OTHERS) do equal(got[key], TODAY, label .. ": " .. key .. " keeps the Classic colours") end
end
Each("Grey", { castBarColour = "grey" }, LIGHT)
Each("Grey in Dark Mode", { castBarColour = "grey", darkMode = true }, LIGHT)
Each("Class, a paladin", { castBarColour = "class" }, PINK)
Each("Class, a hunter", { castBarColour = "class" }, C(.67, .83, .45), "HUNTER")
Each("Class in Dark Mode, a mage", { castBarColour = "class", darkMode = true }, C(.25, .78, .92), "MAGE")
-- Another addon's class colours win, except a paladin's: pink as everywhere
-- in EraUI (the game's own paladin colour may not be).
CUSTOM_CLASS_COLORS = { HUNTER = { r = .1, g = .2, b = .3 }, PALADIN = { r = 0, g = .44, b = .87 } }
Each("Class with another addon's class colours", { castBarColour = "class" }, C(.1, .2, .3), "HUNTER")
Each("Class: a paladin stays pink", { castBarColour = "class" }, PINK, "PALADIN")
CUSTOM_CLASS_COLORS = nil
Each("Class with no colour for it", { castBarColour = "class" }, LIGHT, "MONK")
Each("Class, the class kept secret", { castBarColour = "class" }, LIGHT, SECRET)
equal(table.concat(leaks, ","), "", "a secret class is never passed on")
Each("Custom", { castBarColour = "custom", castBarCustomColour = "FF8000" }, C(1, 128 / 255, 0))
Each("Custom, lower case", { castBarColour = "custom", castBarCustomColour = "3366cc" }, C(.2, .4, .8))
Each("Custom, not a colour", { castBarColour = "custom", castBarCustomColour = "GGGGGG" }, C(199 / 255, 204 / 255, 214 / 255))
Each("Custom, none saved", { castBarColour = "custom" }, C(199 / 255, 204 / 255, 214 / 255))

-- 4. Live, mid-cast: your own and your pet's bars only ------------------------------------
Game({ castBarColour = "grey" })
modules.castBars.apply()
Cast("player"); Cast("pet", { channel = true }); Cast("target"); Cast("focus", { channel = true }); Cast("boss1")
equal(Fill("player") .. " " .. Fill("pet"), LIGHT .. " " .. LIGHT, "Grey: a cast and a channel")
local others, writes = {}, {}
for _, key in ipairs(OTHERS) do others[key], writes[key] = Fill(key), Writes(bars[key]) end
local ownWrites = Writes(bars.player) + Writes(bars.pet)
settings.castBarColour = "class"
ns.RefreshCastColours()
equal(Fill("player") .. " " .. Fill("pet"), PINK .. " " .. PINK, "Class chosen mid-cast: both bars at once")
equal(Writes(bars.player) + Writes(bars.pet) - ownWrites, 2, "one colour each, nothing else written")
for _, key in ipairs(OTHERS) do
    equal(Fill(key) .. " " .. (Writes(bars[key]) - writes[key]), others[key] .. " 0", key .. " left alone")
end
-- An interrupt stays red and a cast that can't be interrupted grey through a switch.
Atlas("player", "ui-castingbar-interrupted")
Cast("pet", { atlas = "ui-castingbar-uninterruptable" })
settings.castBarColour, settings.castBarCustomColour = "custom", "FF8000"
ns.RefreshCastColours()
equal(Fill("player") .. " " .. Fill("pet"), RED .. " " .. GREY, "Custom chosen: the interrupt stays red, the cast that can't be interrupted grey")
Cast("player"); Cast("pet", { channel = true })
settings.castBarCustomColour = "336699"
ns.RefreshCastColours()
equal(Fill("player") .. " " .. Fill("pet"), C(.2, .4, .6) .. " " .. C(.2, .4, .6), "a new custom colour picked mid-cast: at once")
-- Back to Match look mid-channel: the Classic colours for what's on show.
settings.castBarColour = "auto"
ns.RefreshCastColours()
equal(Fill("player") .. " " .. Fill("pet"), Y .. " " .. G, "Match look again: the cast yellow, the channel green")
Finish("player")
settings.castBarColour = "grey"
ns.RefreshCastColours()
equal(Fill("player") .. " " .. Fill("pet"), G .. " " .. LIGHT, "Grey after a finish: the finished cast stays green, the channel grey")
-- Edit Mode locks the player's bar to the player frame: still yours.
Blizzard(bars.player, "SetLook", "UNITFRAME")
Cast("player")
equal(Fill("player"), LIGHT, "the player's bar locked to the player frame: the chosen colour")
-- From the Classic colours to one of its own mid-cast: the bars were shown
-- again in the Classic colours (no atlas left to read), yet a cast that
-- can't be interrupted stays grey and a channel takes the colour.
for _, from in ipairs({ "auto", "classic" }) do
    Game({ castBarColour = from })
    modules.castBars.apply()
    Cast("player", { atlas = "ui-castingbar-uninterruptable" }); Cast("pet", { channel = true })
    equal(Fill("player") .. " " .. Fill("pet"), Y .. " " .. Y, from .. ": both shown again in yellow, as today")
    settings.castBarColour = "grey"
    ns.RefreshCastColours()
    equal(Fill("player") .. " " .. Fill("pet"), GREY .. " " .. LIGHT,
        from .. " to Grey mid-cast: the cast that can't be interrupted stays grey, the channel light grey")
    Atlas("player", "ui-castingbar-interrupted")
    settings.castBarColour = from
    ns.RefreshCastColours()
    settings.castBarColour = "class"
    ns.RefreshCastColours()
    equal(Fill("player") .. " " .. Fill("pet"), RED .. " " .. PINK, "an interrupt through " .. from .. " and back: still red")
end
-- Before Cast Bars applies (or with it off) nothing is touched.
Game({ castBarColour = "class" })
local untouched = Writes(bars.player) + Writes(bars.pet)
ns.RefreshCastColours()
equal(Writes(bars.player) + Writes(bars.pet) - untouched, 0, "Cast Bars not applied: the switch writes nothing")
modules.castBars.apply()
modules.castBars.restore()
untouched = Writes(bars.player) + Writes(bars.pet)
ns.RefreshCastColours()
equal(Writes(bars.player) + Writes(bars.pet) - untouched, 0, "Cast Bars switched off: nothing either")

-- 5. Flat Bars and Rounded Cast Bars, on and off: the colour stays ------------------------
Game({ castBarColour = "grey", flatBars = true })
modules.castBars.apply()
Cast("player"); Cast("pet", { channel = true }); Cast("target")
equal(Texture("player") .. " " .. Fill("player") .. " " .. Fill("pet") .. " " .. Fill("target"), SOLID .. " " .. LIGHT .. " " .. LIGHT .. " " .. Y,
    "Flat Bars on: the solid fill in the chosen colour; the target's yellow")
settings.flatBars = nil
ns.RefreshFlatBars()
equal(Texture("player") .. " " .. Fill("player") .. " " .. Fill("pet") .. " " .. Fill("target"), SHADED .. " " .. LIGHT .. " " .. LIGHT .. " " .. Y,
    "Flat Bars off: the shaded fill, the colours kept")
settings.castBarColour = "class"
ns.RefreshCastColours()
settings.flatBars = true
ns.RefreshFlatBars()
equal(Texture("pet") .. " " .. Fill("player") .. " " .. Fill("pet"), SOLID .. " " .. PINK .. " " .. PINK, "Flat Bars on again: the class colour kept")
lives = Lives({ castBarColour = "class", flatBars = true })
equal(lives.player .. " | " .. lives.target, Chosen(PINK) .. " | " .. TODAY, "Flat Bars on: every step in the class colour, the target's Classic")
Game({ castBarColour = "class" })
modules.castBars.apply()
Cast("player"); Cast("pet", { channel = true }); Cast("focus")
settings.roundedCastBars = true
ns.RefreshRoundedCasts()
equal(Fill("player") .. " " .. Fill("pet") .. " " .. Fill("focus"), PINK .. " " .. PINK .. " " .. Y, "Rounded Cast Bars on: the colours kept")
equal(S[bars.player].h, 18, "and the rounded look on")
lives = {}
for _, key in ipairs(ALL) do lives[key] = Life(key) end
equal(lives.player .. " | " .. lives.pet .. " | " .. lives.focus, Chosen(PINK) .. " | " .. Chosen(PINK) .. " | " .. TODAY,
    "Rounded Cast Bars: every step in the class colour on yours, the focus's Classic")
settings.roundedCastBars, settings.flatBars = nil, true
ns.RefreshRoundedCasts()
ns.RefreshFlatBars()
Cast("player"); Cast("pet", { channel = true })
equal(Texture("player") .. " " .. Fill("player") .. " " .. Fill("pet") .. " " .. S[bars.player].h, SOLID .. " " .. PINK .. " " .. PINK .. " 13",
    "Rounded off, Flat Bars on: the Classic size, the solid fill, the class colour")

-- 6. Secret atlas names are never read -------------------------------------------------------
Game({ castBarColour = "grey" })
modules.castBars.apply()
Cast("pet", { atlas = "ui-castingbar-uninterruptable" })
S[S[bars.pet].fill].atlas = SECRET
Shown("pet")
equal(Fill("pet") .. " " .. table.concat(leaks, ","), GREY .. " ", "a secret fill name: the kind on show kept, nothing passed on")
S[S[bars.target].fill].atlas = SECRET
Shown("target")
equal(Fill("target"), Y, "the target's: yellow, as always")

-- 7. Nothing written on the game's bars, nothing of theirs run or replaced ------------------
-- Every bar and piece above is sealed: a key written on one, a script set on
-- one or one of the game's methods run by EraUI would have failed. The hooks
-- are today's, whatever colour is chosen.
local function Hooks()
    local out = {}
    for id, n in pairs(hooks) do out[#out + 1] = id .. "=" .. n end
    table.sort(out)
    return table.concat(out, " ")
end
Game()
modules.castBars.apply()
local plain = Hooks()
Game({ castBarColour = "custom", castBarCustomColour = "FF8000" })
modules.castBars.apply()
ns.RefreshCastColours()
equal(Hooks(), plain, "the same post-hooks with any colour, none added")
equal(table.concat(leaks, ","), "", "no secret value passed to a setter that doesn't take one")

print("Cast Bar Colour checks passed: " .. checks .. " assertions.")

