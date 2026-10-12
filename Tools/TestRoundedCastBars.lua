-- Rounded Cast Bars (Appearance > Style > Frame Style) on the real
-- Classic/CastBars.lua, Classic/Textures.lua, Classic/Skin.lua,
-- Core/Appearance.lua (the Darkness slider), Modules/ClassAccents.lua and
-- Modules/AdvancedCastBar.lua, against the game's player, pet, target, focus
-- and boss cast bars as Forever builds them (CastingBarFrameTemplate and
-- SmallCastingBarFrameTemplate: their art, anchors and fonts). The game's bars
-- and their pieces are sealed: writing a key on them fails, and EraUI running
-- one of the game's own methods fails. Checked: off is today's look exactly
-- (and nothing is made); on, the player's, pet's, target's and focus's bars
-- get the near-black shell with soft corners, the icon in its own tile, the
-- name left and the time right (from secret values only through the font
-- string), Flat Bars' fill, the fine line per look (bronze, the Darkness grey
-- live, the class colour from Class-coloured Cast Border), the Advanced Cast
-- Bar's line; boss bars untouched; the live switch both ways back to today's
-- look exactly; a protected bar waits for the end of a fight.
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
    Method("HandleCastStart", function(self, event, spec)
        self:UpdateBarFillTexture(spec.channel and "ui-castingbar-filling-channel" or "ui-castingbar-filling-standard")
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

-- A region's place in the bar's own space (the bar's top left at 0, 0; up is
-- positive), from its anchors on the bar.
local function At(bar, point, x, y)
    local w, h = S[bar].w, S[bar].h
    local spots = {
        TOPLEFT = { 0, 0 }, TOPRIGHT = { w, 0 }, BOTTOMLEFT = { 0, -h }, BOTTOMRIGHT = { w, -h },
        LEFT = { 0, -h / 2 }, RIGHT = { w, -h / 2 }, TOP = { w / 2, 0 }, BOTTOM = { w / 2, -h }, CENTER = { w / 2, -h / 2 },
    }
    local spot = assert(spots[point], "no spot " .. tostring(point))
    return spot[1] + x, spot[2] + y
end
local function Rect(region, bar)
    local s = S[region]
    local left, right, top, bottom
    for _, p in ipairs(s.points) do
        assert(p[2] == bar, "every piece is pinned to the bar itself")
        local x, y = At(bar, p[3], p[4], p[5])
        local point = p[1]
        if point:find("LEFT") then left = x elseif point:find("RIGHT") then right = x end
        if point:find("TOP") then top = y elseif point:find("BOTTOM") then bottom = y end
        if point == "LEFT" or point == "RIGHT" or point == "CENTER" then
            top, bottom = y + s.h / 2, y - s.h / 2
        end
        if point == "CENTER" then left, right = x - s.w / 2, x + s.w / 2 end
    end
    left = left or right - s.w
    right = right or left + s.w
    top = top or bottom + s.h
    bottom = bottom or top - s.h
    return left, right, top, bottom
end
local function R(region, bar)
    local l, r, t, b = Rect(region, bar)
    return string.format("%g,%g,%g,%g", l, r, t, b)
end

local settings, ns, E, modules, booked, bars
local function Game()
    combat = false
    made, regions, hooks, leaks, units, durations = {}, {}, {}, {}, {}, {}
    settings = { enabled = true, castBars = true, darkModeDarkness = 58 }
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

local ROUNDED = { "player", "pet", "target", "focus" }
local ALL = { "player", "pet", "target", "focus", "boss1", "boss2", "boss3" }
local function Cast(key, spec)
    spec = spec or {}
    Blizzard(bars[key], "HandleCastStart", spec.channel and "UNIT_SPELLCAST_CHANNEL_START" or "UNIT_SPELLCAST_START", {
        name = spec.name or "Aimed Shot", icon = spec.icon or 135130, total = spec.total or 2, channel = spec.channel })
end
local function Value(key, value) Blizzard(bars[key], "SetValue", value) end
local function Finish(key) Blizzard(bars[key], "FinishSpell") end
local function Looks(keys)
    local out = {}
    for _, key in ipairs(keys or ALL) do out[#out + 1] = key .. ": " .. Look(bars[key]) end
    return table.concat(out, "\n")
end
-- The frames' own OnUpdate, as the game runs them while they show.
local function Tick(elapsed)
    for _, f in ipairs(made) do
        local update = S[f].scripts.OnUpdate
        if update and f:IsVisible() then update(f, elapsed or .1) end
    end
end
local function Switch(on)
    settings.roundedCastBars = on or nil
    return ns.RefreshRoundedCasts()
end
-- The shell EraUI made for a bar: its two frames (under and over the bar).
local function Shell(bar)
    local under, over
    for _, f in ipairs(made) do
        if S[f].parent == bar then
            if S[f].scripts.OnUpdate then over = over or f else under = under or f end
        end
    end
    return under, over
end
local function Kids(frame, kind, layer)
    local out = {}
    for _, r in ipairs(regions) do
        if S[r].parent == frame and S[r].kind == kind and (not layer or S[r].layer == layer) then out[#out + 1] = r end
    end
    table.sort(out, function(a, b) return S[a].order < S[b].order end)
    return out
end

-- 1. Off (the default): today's look exactly, and nothing made ------------------------------
Game()
local pristine = Looks()
modules.castBars.apply()
for _, key in ipairs(ALL) do Cast(key) end
equal(#made .. " " .. #regions, "0 0", "off: Cast Bars makes no frame, texture or font string")
equal(Look(bars.player):find("size 195x13", 1, true) ~= nil and Look(bars.target):find("size 150x10", 1, true) ~= nil, true,
    "off: the Classic sizes, 195x13 and 150x10")
local p = S[bars.player.Border]
equal(p.texture .. " " .. p.alpha .. " " .. S[bars.player.Text].justify .. " " .. S[bars.player.Spark].w .. " " .. S[bars.player.Flash].texture
    .. " " .. table.concat(S[bars.player.Flash].tint, ","),
    "Interface\\CastingBar\\UI-CastingBar-Border 1 CENTER 32 Interface\\CastingBar\\UI-CastingBar-Flash 1,1,1,1",
    "off: the Classic border, the name centred, the 32 spark and the Classic flash")
local ct = S[bars.player.CastTimeText]
equal(ct.points[1][1] .. ">" .. ct.points[1][3] .. " " .. ct.points[1][4] .. " " .. ct.font.name, "LEFT>RIGHT 10 GameFontHighlightLarge",
    "off: the game's own cast time where the game put it")
local ti = S[bars.target.Icon]
equal(ti.w .. "x" .. ti.h .. " " .. table.concat(ti.coords, ",") .. " " .. ti.points[1][1] .. ">" .. ti.points[1][3] .. " " .. ti.points[1][4],
    "18x18 0,1,0,1 RIGHT>LEFT -3.5", "off: the target's icon where EraUI's Classic look puts it")
equal(S[bars.target.BorderShield].texture, "Interface\\CastingBar\\UI-CastingBar-Small-Shield", "off: the Classic shield")
local offHooks = {}
for id, n in pairs(hooks) do offHooks[#offHooks + 1] = id .. "=" .. n end
table.sort(offHooks)
local offLooks = Looks()
equal(offLooks ~= pristine, true, "off: EraUI's Classic look on (not the game's)")

-- The same game with the option on, then off again, live, must end exactly here.
local function Scenario(roundTrip)
    Game()
    modules.castBars.apply()
    for _, key in ipairs(ALL) do Cast(key) end
    if roundTrip then
        Switch(true)
        for _, key in ipairs(ALL) do Cast(key, { name = "Frostbolt", icon = 135846 }) end
        Tick(.1)
        Switch(false)
        Switch(true)
        Switch(false)
    else
        for _, key in ipairs(ALL) do Cast(key, { name = "Frostbolt", icon = 135846 }) end
    end
    for _, key in ipairs(ALL) do Cast(key, { name = "Arcane Shot", icon = 132218, channel = key == "target" }) end
    Value("player", .5)
    Finish("pet")
    return Looks()
end
local today = Scenario(false)
local back = Scenario(true)
equal(back, today, "on, then off again (twice), live: every bar exactly today's look")
local shownAfter = 0
for _, f in ipairs(made) do if f:IsVisible() then shownAfter = shownAfter + 1 end end
equal(shownAfter, 0, "and every frame EraUI made is hidden")

-- 2. On, live, mid-cast: the shell, the tile, the name and the time ----------------------
Game()
modules.castBars.apply()
for _, key in ipairs(ALL) do Cast(key) end
Blizzard(bars.target, "UpdateBarFillTexture", "ui-castingbar-filling-channel")
local colours = {}
for _, key in ipairs(ALL) do colours[key] = table.concat(S[bars[key]].rgb, ",") end
local bossLooks, bossWrites = Looks({ "boss1", "boss2", "boss3" }), 0
for i = 1, 3 do bossWrites = bossWrites + Writes(bars["boss" .. i]) end
local done = Switch(true)
equal(tostring(done) .. " " .. booked, "true 0", "ticked out of a fight: done at once, nothing booked")
equal(#made, 8, "two frames for each of the four bars, none for the bosses")
for _, key in ipairs(ROUNDED) do
    local bar = bars[key]
    local under, over = Shell(bar)
    equal(under ~= nil and over ~= nil, true, key .. ": a frame under the bar and one over it")
    equal(S[under].level .. " " .. S[over].level, (S[bar].level - 1) .. " " .. (S[bar].level + 1), key .. ": the shell one level under the bar, the time one over")
    equal(under:IsVisible() and over:IsVisible(), true, key .. ": both show with the bar")
    equal(table.concat(S[bar].rgb, ","), colours[key], key .. ": its fill keeps its colour")
end
for i = 1, 3 do
    local boss = bars["boss" .. i]
    equal(Shell(boss), nil, "boss " .. i .. ": no shell")
end
local after = 0
for i = 1, 3 do after = after + Writes(bars["boss" .. i]) end
equal(Looks({ "boss1", "boss2", "boss3" }) .. " " .. (after - bossWrites), bossLooks .. " 0", "boss bars untouched: the same look, nothing written")
-- Their casts while it's on: EraUI's Classic look as before, no shell.
for i = 1, 3 do Cast("boss" .. i) end
equal(Looks({ "boss1", "boss2", "boss3" }) .. " " .. #made, bossLooks .. " 8", "boss casts with it on: the Classic look as before, nothing made")
-- The game can re-level the bar's children (Edit Mode's lock moves the
-- player's bar to the player frame; that bar is raised as it shows): the
-- next dressing puts the shell back under the bar, so it never covers the
-- fill, whether or not the bar's own level changed.
do
    local bar = bars.player
    local under = Shell(bar)
    S[under].level = S[bar].level + 1
    Cast("player")
    equal(S[under].level, S[bar].level - 1, "a shell the game lifted over the bar goes back under it at the next cast")
    S[bar].level = S[bar].level + 5
    Cast("player")
    equal(S[under].level, S[bar].level - 1, "and under the bar after the bar itself is raised")
    S[bar].level = S[bar].level - 5
    Cast("player")
    equal(S[under].level, S[bar].level - 1, "and back")
end

-- The geometry, per look (the player's and pet's Classic bar, the target's and focus's small one).
local GEOMETRY = {
    player = { w = 195, h = 18, edge = 5, corner = 6, inset = 6, room = 40, font = "GameFontHighlight" },
    pet = { w = 195, h = 18, edge = 5, corner = 6, inset = 6, room = 40, font = "GameFontHighlight" },
    target = { w = 150, h = 14, edge = 4, corner = 5, inset = 4, room = 32, font = "SystemFont_Shadow_Small" },
    focus = { w = 150, h = 14, edge = 4, corner = 5, inset = 4, room = 32, font = "SystemFont_Shadow_Small" },
}
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
for _, key in ipairs(ROUNDED) do
    local bar, g = bars[key], GEOMETRY[key]
    local under, over = Shell(bar)
    equal(S[bar].w .. "x" .. S[bar].h, g.w .. "x" .. g.h, key .. ": the bar " .. g.w .. "x" .. g.h)
    local left = -(3 + g.h + g.edge)
    local body = Kids(under, "Texture", "BACKGROUND")
    equal(#body, 7, key .. ": the shell's body, seven pieces")
    -- Four corners: quarters of the round mask, near black, corner x corner.
    local corners = { { left, left + g.corner, g.edge, g.edge - g.corner }, { g.w + g.edge - g.corner, g.w + g.edge, g.edge, g.edge - g.corner },
        { left, left + g.corner, -g.h - g.edge + g.corner, -g.h - g.edge }, { g.w + g.edge - g.corner, g.w + g.edge, -g.h - g.edge + g.corner, -g.h - g.edge } }
    local quarters = { "0,0.5,0,0.5", "0.5,1,0,0.5", "0,0.5,0.5,1", "0.5,1,0.5,1" }
    for i = 1, 4 do
        local c = S[body[i]]
        equal(R(body[i], bar) .. " " .. c.texture .. " " .. table.concat(c.coords, ",") .. " " .. table.concat(c.tint, ","),
            string.format("%g,%g,%g,%g", unpack(corners[i])) .. " " .. MASK .. " " .. quarters[i] .. " 0.05,0.05,0.06,1",
            key .. ": corner " .. i .. " a quarter of the round mask, near black")
    end
    -- Three bands, near black; together with the corners they fill the shell
    -- with no gap and nothing outside it.
    for i = 5, 7 do equal(table.concat(S[body[i]].colour, ","), "0.05,0.05,0.06,1", key .. ": band " .. i - 4 .. " near black") end
    local L, Rr, T, B = left, g.w + g.edge, g.edge, -g.h - g.edge
    local gaps, outside = 0, 0
    for _, piece in ipairs(body) do
        local l, r, t, b = Rect(piece, bar)
        if l < L - 1e-6 or r > Rr + 1e-6 or t > T + 1e-6 or b < B - 1e-6 then outside = outside + 1 end
    end
    for x = L + .25, Rr - .25, .5 do
        for y = B + .25, T - .25, .5 do
            local covered = false
            for _, piece in ipairs(body) do
                local l, r, t, b = Rect(piece, bar)
                if x >= l and x <= r and y <= t and y >= b then covered = true break end
            end
            if not covered then gaps = gaps + 1 end
        end
    end
    equal(gaps .. " " .. outside, "0 0", key .. ": the shell filled edge to edge, " .. (Rr - L) .. "x" .. (T - B))
    -- The fine line: one unit wide, 2 to 1 units past the tile and the bar.
    local line = Kids(under, "Texture", "BORDER")
    local tile = 3 + g.h
    local want = { { -tile - 2, g.w + 2, 2, 1 }, { -tile - 2, g.w + 2, -g.h - 1, -g.h - 2 }, { -tile - 2, -tile - 1, 1, -g.h - 1 }, { g.w + 1, g.w + 2, 1, -g.h - 1 } }
    for i = 1, 4 do equal(R(line[i], bar), string.format("%g,%g,%g,%g", unpack(want[i])), key .. ": line " .. i) end
    -- The name at the bar's left, clear of the time at its right.
    local text = S[bar.Text]
    equal(#text.points .. " " .. text.points[1][1] .. ">" .. text.points[1][3] .. " " .. text.points[1][4] .. " " .. text.points[2][1] .. ">"
        .. text.points[2][3] .. " " .. text.points[2][4] .. " " .. text.justify,
        "2 LEFT>LEFT " .. g.inset .. " RIGHT>RIGHT " .. -g.room .. " LEFT", key .. ": the name left-aligned at the bar's left")
    local time = Kids(over, "FontString")[1]
    local ts = S[time]
    equal(ts.points[1][1] .. ">" .. ts.points[1][3] .. " " .. ts.points[1][4] .. " " .. ts.justify .. " " .. ts.font.name,
        "RIGHT>RIGHT " .. -g.inset .. " RIGHT " .. g.font, key .. ": the time right-aligned at the bar's right, in the name's font")
    -- The Classic border faded, the spark as tall as the shell, the flash soft and even.
    local spark, flash = S[bar.Spark], S[bar.Flash]
    equal(S[bar.Border].alpha .. " " .. spark.w .. "x" .. spark.h .. " " .. flash.texture .. " " .. flash.blend .. " "
        .. table.concat(flash.tint, ",") .. " " .. R(bar.Flash, bar),
        "0 " .. (g.h + 2 * g.edge) .. "x" .. (g.h + 2 * g.edge) .. " Interface\\Buttons\\WHITE8X8 ADD 1,1,1,0.4 0," .. g.w .. ",0," .. -g.h,
        key .. ": border faded, spark inside the shell, a soft flash over the bar")
end
-- The icon in its tile: the player's and pet's own icon is hidden by the game
-- in this look, so EraUI's shows its spell; the target's and focus's is the
-- game's own, which EraUI already places, moved in.
for _, key in ipairs({ "player", "pet" }) do
    local bar = bars[key]
    local under = Shell(bar)
    local icon = Kids(under, "Texture", "ARTWORK")[1]
    equal(R(icon, bar) .. " " .. tostring(S[icon].shown) .. " " .. S[icon].texture .. " " .. table.concat(S[icon].coords, ","),
        "-21,-3,0,-18 true 135130 0.07,0.93,0.07,0.93", key .. ": EraUI's icon in the tile, the spell's own")
    equal(table.concat(S[bar.Icon].coords, ",") .. " " .. tostring(S[bar.Icon].shown), "0,1,0,1 false", key .. ": the game's icon left as it is, hidden")
end
for _, key in ipairs({ "target", "focus" }) do
    local bar = bars[key]
    local under = Shell(bar)
    local icon = Kids(under, "Texture", "ARTWORK")[1]
    equal(R(bar.Icon, bar) .. " " .. table.concat(S[bar.Icon].coords, ",") .. " " .. tostring(S[icon].shown),
        "-17,-3,0,-14 0.07,0.93,0.07,0.93 false", key .. ": the game's icon moved into the tile, EraUI's own hidden")
    local shield = S[bar.BorderShield]
    local l, r, t, b = Rect(bar.BorderShield, bar)
    equal(shield.atlas .. " " .. string.format("%.2f %.2f %.2f %.2f", r - l, t - b, (l + r) / 2, (t + b) / 2) .. " " .. shield.w .. "x" .. shield.h,
        "ui-castingbar-shield 20.30 23.10 -10.00 -6.00 29x56", key .. ": the game's shield round the tile, its own size unchanged")
end

-- The time left, as the bar goes.
Cast("player", { total = 2, icon = 136116, name = "Fireball" })
Value("player", .5)
Tick(.1)
local function Time(key) local _, over = Shell(bars[key]); return S[Kids(over, "FontString")[1]].text end
local under = Shell(bars.player)
equal(Time("player") .. " " .. S[Kids(under, "Texture", "ARTWORK")[1]].texture, "1.5 136116", "a new cast: 1.5 left, and the tile shows its spell")
Value("player", 1.3)
Tick(.01)
equal(Time("player"), "1.5", "a few times a second, not every frame")
Tick(.05)
equal(Time("player"), "0.7", "then 0.7 left")
Cast("target", { total = 3, channel = true })
Value("target", 3.2)
Tick(.1)
equal(Time("target"), "3.2", "a channel: what's left of it")
-- The game keeps the focus's numbers from addons: its own duration for the
-- cast is passed to the font string, never worked on.
Cast("focus", { total = 2 })
S[bars.focus].secretValues = true
durations.focus = SECRET_NUM
Tick(.1)
equal(Time("focus") .. " " .. #leaks, "<secret> 0", "secret numbers: the game's own time left, through the font string only")
durations.focus = "secret object"
Tick(.1)
equal(Time("focus") .. " " .. #leaks, " 0", "a duration that can't be read: no time")
durations.focus = nil
Tick(.1)
equal(Time("focus"), "", "no duration: no time")
S[bars.focus].secretValues = nil
Finish("player")
Tick(.1)
equal(Time("player"), "", "the cast done: no time")
-- The player's bar has the game's own cast time (Edit Mode's Show Cast Time):
-- moved inside at the right, and EraUI's own then waits.
local own = S[bars.player.CastTimeText]
equal(#own.points .. " " .. own.points[1][1] .. ">" .. own.points[1][3] .. " " .. own.points[1][4] .. " " .. own.font.name,
    "1 RIGHT>RIGHT -6 GameFontHighlight", "the game's own cast time inside the bar at the right")
Cast("player", { total = 2 })
Value("player", .5)
Blizzard(bars.player.CastTimeText, "Show")
Tick(.1)
equal(Time("player"), "", "Show Cast Time on: only the game's own time shows")
Blizzard(bars.player.CastTimeText, "Hide")
Tick(.1)
equal(Time("player"), "1.5", "off again: EraUI's")
equal(table.concat(leaks, ","), "", "no secret value passed to a setter that doesn't take one")

-- 3. Flat Bars: the fill solid with the shell, in each cast's colour -------------------------
local SOLID, SHADED = "Interface\\Buttons\\WHITE8X8", "Interface\\TargetingFrame\\UI-StatusBar"
for _, key in ipairs(ROUNDED) do colours[key] = table.concat(S[bars[key]].rgb, ",") end
settings.flatBars = true
ns.RefreshFlatBars()
for _, key in ipairs(ROUNDED) do
    equal(S[S[bars[key]].fill].texture .. " " .. table.concat(S[bars[key]].rgb, ","), SOLID .. " " .. colours[key], key .. ": Flat Bars' solid fill, same colour")
end
Cast("target", { channel = true, total = 4 })
Blizzard(bars.target, "UpdateBarFillTexture", "ui-castingbar-filling-channel")
equal(S[S[bars.target].fill].texture .. " " .. table.concat(S[bars.target].rgb, ",", 1, 3) .. " " .. S[bars.target].w .. "x" .. S[bars.target].h,
    SOLID .. " 0,1,0 150x14", "the next channel's fill: solid, green, the rounded size kept")
settings.flatBars = nil
ns.RefreshFlatBars()
equal(S[S[bars.player].fill].texture, SHADED, "Flat Bars off: the Classic fill again under the shell")

-- 4. The line per look: bronze, the Darkness grey (live), the class colour -------------------
local function LineOf(key)
    local under = Shell(bars[key])
    local line = Kids(under, "Texture", "BORDER")
    local first = Col(S[line[1]].colour)
    for i = 2, 4 do if Col(S[line[i]].colour) ~= first then return "mixed" end end
    return first
end
local function Grey(d)
    local v = 1 - d / 100
    return string.format("%g,%g,%g,1", v, math.min(1, v * 44 / 42), math.min(1, v * 48 / 42))
end
for _, key in ipairs(ROUNDED) do equal(LineOf(key), "0.55,0.46,0.27,1", key .. ": Classic: the muted bronze line") end
-- Dark Mode (after its reload): the Darkness grey, and the slider moves it at once.
Game()
settings.darkMode = true
modules.castBars.apply()
for _, key in ipairs(ROUNDED) do Cast(key) end
Switch(true)
for _, key in ipairs(ROUNDED) do equal(LineOf(key), Grey(58), key .. ": Dark Mode: the Darkness grey (58)") end
settings.darkModeDarkness = 90
ns.RefreshDarkness()
for _, key in ipairs(ROUNDED) do equal(LineOf(key), Grey(90), key .. ": Darkness 90: near black at once") end
settings.darkModeDarkness = 40
ns.RefreshDarkness()
equal(LineOf("player"), Grey(40), "Darkness 40: light grey")
-- Class-coloured Cast Border (Modules/ClassAccents.lua): a player's bar takes
-- its class colour on the line, an NPC's keeps the look's; no copy of the
-- faded border is made.
settings.castBarClassBorder = true
settings.unitFrames = true
units.player = { player = true, class = "HUNTER" }
units.target = { player = true, class = "PALADIN" }
units.focus = { player = false }
assert(loadfile("Modules/ClassAccents.lua"))("EraUI", E)
local accents = E.modules.ClassAccents
local before = #made
accents:Refresh()
equal(#made - before, 0, "no outline made for a bar wearing the shell")
equal(LineOf("player") .. " | " .. LineOf("target") .. " | " .. LineOf("focus") .. " | " .. LineOf("pet"),
    "0.67,0.83,0.45,1 | 0.96,0.55,0.73,1 | " .. Grey(40) .. " | " .. Grey(40),
    "the player's line in the hunter's colour, a paladin target's in its pink, an NPC focus and the pet in the look's grey")
settings.darkModeDarkness = 90
ns.RefreshDarkness()
equal(LineOf("player") .. " | " .. LineOf("focus"), "0.67,0.83,0.45,1 | " .. Grey(90), "the slider leaves a class colour alone")
-- The target changes to an NPC: its line goes back to the look's.
units.target = { player = false }
accents:Refresh()
equal(LineOf("target"), Grey(90), "an NPC target: the look's line again")
settings.castBarClassBorder = nil
units.target = { player = true, class = "MAGE" }
accents:Refresh()
equal(LineOf("player"), Grey(90), "Class-coloured Cast Border off: the look's line")
-- Rounded off: Class-coloured Cast Border is today's outline again.
settings.castBarClassBorder = true
accents:Refresh()
before = #made
-- Switching off asks Class-coloured Cast Border for its outline straight away.
Switch(false)
local outlines = 0
for i = before + 1, #made do
    local parent = S[made[i]].parent
    if parent == bars.player or parent == bars.target then outlines = outlines + 1 end
end
equal(outlines .. " " .. tostring(made[before + 1] and made[before + 1]:IsShown()), "2 true",
    "rounded off: the player's and the mage target's class outline, as before")
Switch(true)
equal(made[before + 1]:IsShown(), false,
    "on again: the copy goes the moment the shell goes on, before Class-coloured Cast Border refreshes (the striped bar seen in game)")
equal(made[before + 1].art:IsShown(), false,
    "and its art on the bar itself too (hidden with the frame, never left showing when no OnHide fires)")
accents:Refresh()
equal(tostring(made[before + 1]:IsShown()) .. " " .. LineOf("player"), "false 0.67,0.83,0.45,1", "on again: the outline hidden, the line class-coloured")

-- 5. The Advanced Cast Bar: the same fine line only ------------------------------------------
settings.advancedCastBar = true
settings.castBarClassBorder = nil
settings.darkModeDarkness = 58
UnitCastingInfo = function() return "Fireball", "", 135812, 1000, 3000, false, "x", false, 133 end
GetNetStats = function() return 0, 0, 0, 0 end
Enum = {}
assert(loadfile("Modules/AdvancedCastBar.lua"))("EraUI", E)
local advanced = E.modules.AdvancedCastBar
advanced:Initialize()
local function Find(fn, wanted, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for i = 1, 200 do
        local key, value = debug.getupvalue(fn, i)
        if not key then break end
        if key == wanted then return value end
        if type(value) == "function" then
            local found = Find(value, wanted, seen)
            if found then return found end
        end
    end
end
local lines = Find(advanced.Refresh, "lines")
local abar, iconEdge = EraUIAdvancedCastBar, Find(advanced.Refresh, "iconEdge")
equal(#lines .. " " .. tostring(lines[1]:IsShown()), "4 true", "Rounded Cast Bars on: four line strips on the Advanced Cast Bar, shown")
local function Strip(i)
    local s = S[lines[i]]
    local a, b = s.points[1], s.points[2]
    return a[1] .. ">" .. Name(a[2], abar) .. ":" .. a[3] .. "(" .. a[4] .. "," .. a[5] .. ") " .. b[1] .. ">" .. Name(b[2], abar) .. ":"
        .. b[3] .. "(" .. b[4] .. "," .. b[5] .. ")"
end
equal(S[iconEdge].parent == abar, true, "setup: the icon's edge is the bar's")
equal(Strip(1) .. " | " .. Strip(2) .. " | " .. Strip(3) .. " | " .. Strip(4),
    "TOPLEFT>Frame:TOPLEFT(-2,2) BOTTOMRIGHT>bar:TOPRIGHT(2,1) | TOPLEFT>Frame:BOTTOMLEFT(-2,-1) BOTTOMRIGHT>bar:BOTTOMRIGHT(2,-2) | "
        .. "TOPLEFT>Frame:TOPLEFT(-2,1) BOTTOMRIGHT>Frame:BOTTOMLEFT(-1,-1) | TOPLEFT>bar:TOPRIGHT(1,1) BOTTOMRIGHT>bar:BOTTOMRIGHT(2,-1)",
    "one unit wide, 2 to 1 units past the icon and the bar")
equal(Col(S[lines[1]].colour), Grey(58), "Dark Mode: the Darkness grey")
settings.darkModeDarkness = 90
ns.RefreshDarkness()
equal(Col(S[lines[3]].colour), Grey(90), "the slider moves it at once")
settings.castBarClassBorder = true
advanced:Refresh()
equal(Col(S[lines[2]].colour), "0.67,0.83,0.45,1", "Class-coloured Cast Border: the player's class colour")
settings.darkMode = nil
settings.castBarClassBorder = nil
advanced:Refresh()
equal(Col(S[lines[4]].colour), "0.55,0.46,0.27,1", "Classic: the muted bronze")
settings.roundedCastBars = nil
advanced:Refresh()
equal(tostring(lines[1]:IsShown()) .. tostring(lines[4]:IsShown()), "falsefalse", "Rounded Cast Bars off: the line hidden, its own look as before")
settings.roundedCastBars = true
settings.castBars = false
advanced:Refresh()
equal(tostring(lines[1]:IsShown()), "false", "Cast Bars off: no line either")
settings.castBars = true
advanced:Refresh()
equal(tostring(lines[1]:IsShown()), "true", "and back")
-- Off from the start: nothing made.
Game()
settings.advancedCastBar = true
assert(loadfile("Modules/AdvancedCastBar.lua"))("EraUI", E)
E.modules.AdvancedCastBar:Initialize()
equal(#Find(E.modules.AdvancedCastBar.Refresh, "lines"), 0, "Rounded Cast Bars off: no line made on the Advanced Cast Bar")
UnitCastingInfo = function() end

-- 6. A protected bar in a fight waits for the pass after it --------------------------------------
Game()
modules.castBars.apply()
for _, key in ipairs(ROUNDED) do Cast(key) end
local targetBefore = Look(bars.target)
S[bars.target].protected = true
combat = true
done = Switch(true)
equal(tostring(done) .. " " .. booked .. " " .. tostring(Look(bars.target) == targetBefore) .. " " .. tostring(Shell(bars.target) == nil),
    "false 1 true true", "ticked in a fight: the protected target bar waits, one pass booked, nothing made on it")
equal(S[bars.player].h .. " " .. tostring(Shell(bars.player) ~= nil), "18 true", "the other bars at once")
Cast("target")
equal(tostring(Look(bars.target) == targetBefore) .. " " .. booked, "true 2", "a cast in the fight: the target bar still waits, the pass asked for again")
combat = false
modules.castBars.apply()
equal(S[bars.target].w .. "x" .. S[bars.target].h .. " " .. tostring(Shell(bars.target) ~= nil), "150x14 true", "the pass after the fight: the target bar too")
-- Off in a fight: it keeps the rounded look until the fight ends, then today's.
combat = true
done = Switch(false)
equal(tostring(done) .. " " .. S[bars.target].h .. " " .. S[bars.player].h, "false 14 13", "unticked in a fight: the protected bar keeps it, the rest go at once")
combat = false
modules.castBars.apply()
Cast("target")
equal(S[bars.target].h .. " " .. tostring((Shell(bars.target)):IsShown()), "10 false", "after the fight: today's look")
-- Not protected, in a fight: no wait.
Game()
modules.castBars.apply()
combat = true
done = Switch(true)
equal(tostring(done) .. " " .. booked .. " " .. S[bars.target].h, "true 0 14", "not protected: at once, even in a fight")
combat = false

-- 7. Edit Mode locks the player's bar to the player frame (the small look) and back --------------
Game()
modules.castBars.apply()
Switch(true)
Cast("player")
Blizzard(bars.player, "SetLook", "UNITFRAME")
local under2 = Shell(bars.player)
local own2 = Kids(under2, "Texture", "ARTWORK")[1]
equal(S[bars.player].w .. "x" .. S[bars.player].h .. " " .. R(bars.player.Icon, bars.player) .. " " .. tostring(S[own2].shown),
    "150x14 -17,-3,0,-14 false", "locked to the player frame: the small look, the game's icon in the tile")
equal(R(Kids(under2, "Texture", "BORDER")[3], bars.player), "-19,-18,1,-15", "the line follows the smaller tile")
Blizzard(bars.player, "SetLook", "CLASSIC")
equal(S[bars.player].w .. "x" .. S[bars.player].h .. " " .. table.concat(S[bars.player.Icon].coords, ",") .. " " .. tostring(S[own2].shown),
    "195x18 0,1,0,1 true", "on its own again: the Classic size, EraUI's icon, the game's icon untrimmed")
-- The pet's bar follows the lock too, and the game sizes it after its look
-- (PlayerFrame_AttachCastBar / DetachCastBar: SetLook, then SetWidth and
-- SetHeight): its next cast gives it the rounded size again, the game's own
-- icon in the tile while it's locked.
Blizzard(bars.pet, "SetLook", "UNITFRAME")
Blizzard(bars.pet, "SetWidth", 150)
Blizzard(bars.pet, "SetHeight", 10)
Cast("pet")
local petUnder = Shell(bars.pet)
equal(S[bars.pet].w .. "x" .. S[bars.pet].h .. " " .. R(bars.pet.Icon, bars.pet) .. " " .. table.concat(S[bars.pet.Icon].coords, ",") .. " "
    .. tostring(S[Kids(petUnder, "Texture", "ARTWORK")[1]].shown) .. " " .. R(Kids(petUnder, "Texture", "BORDER")[3], bars.pet),
    "150x14 -17,-3,0,-14 0.07,0.93,0.07,0.93 false -19,-18,1,-15",
    "the pet's bar locked to the player frame: the small rounded look at its next cast, the game's icon in the tile")
Blizzard(bars.pet, "SetLook", "CLASSIC")
Blizzard(bars.pet, "SetWidth", 195)
Blizzard(bars.pet, "SetHeight", 13)
Cast("pet")
equal(S[bars.pet].w .. "x" .. S[bars.pet].h .. " " .. table.concat(S[bars.pet.Icon].coords, ",") .. " " .. tostring(S[Kids(petUnder, "Texture", "ARTWORK")[1]].shown),
    "195x18 0,1,0,1 true", "unlocked: the Classic rounded size, EraUI's icon, the game's untrimmed")

-- 8. Cast Bars switched off: the shells go with it ---------------------------------------------
Game()
modules.castBars.apply()
Switch(true)
modules.castBars.restore()
local visible = 0
for _, f in ipairs(made) do if f:IsVisible() then visible = visible + 1 end end
equal(visible .. " " .. S[bars.player.Border].alpha .. " " .. S[bars.target.Text].justify, "0 1 CENTER", "Cast Bars off: every shell hidden, the border and name as the game has them")
equal(ns.RefreshRoundedCasts(), true, "and the switch then does nothing")

-- 9. Nothing written on the game's bars, nothing of theirs run or replaced ---------------------------
-- Every bar and piece above is sealed: a key written on one, a script set on
-- one or one of the game's methods run by EraUI would have failed. (No
-- GameTooltip and no key written in the code itself: Tools/TestRules.mjs.)
equal(table.concat(leaks, ","), "", "no secret value passed to a setter that doesn't take one")
local hooked = {}
for id, n in pairs(hooks) do hooked[#hooked + 1] = id .. "=" .. n end
table.sort(hooked)
equal(table.concat(hooked, " "), table.concat(offHooks, " "), "on and off: the same post-hooks as today, none added for the shell")

print("Rounded Cast Bars checks passed: " .. checks .. " assertions.")
