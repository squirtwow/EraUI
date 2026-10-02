-- Boss cast bars and Forever Enhanced Cooldown Manager's Raid Timers: the real
-- Classic/CastBars.lua against Blizzard's Boss1-5 spell bars, sealed (writing a
-- key on them fails), and a stand-in for that addon's public API. EraUI styles
-- the boss bars as before unless the API says the other addon does: then it
-- puts back exactly what it changed, touches them no more, and dresses them
-- again when they're handed back, all without a reload. No addon, one without
-- the API, an API that fails or answers anything but true: EraUI's look, as today.
-- EraUI shares the bars at login (its init), so a /reload in a fight, which
-- holds its first pass back, doesn't hold the hand-over back; and a bar that
-- can't be resized in a fight gets Blizzard's size when the fight ends.
local checks = 0
local function equal(a, b, label)
    checks = checks + 1
    assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
unpack = unpack or table.unpack

-- Mock objects ------------------------------------------------------------------------

local S = setmetatable({}, { __mode = "k" }) -- per-object state, never on the object
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local SECRET_SIZE = 12345.5 -- a secret number: still a number, as the game's are
local leaks = {} -- setters given a secret value
local blizzardCalling, otherCalling = false, false
local Proto = {}

local function New(kind, parent, name)
    local obj = {}
    S[obj] = { kind = kind, parent = parent, name = name, points = {}, w = 0, h = 0, alpha = 1, shown = true,
        tint = { 1, 1, 1, 1 }, coords = { 0, 0, 0, 1, 1, 0, 1, 1 }, blend = "BLEND", writes = 0 }
    return setmetatable(obj, {
        __index = function(_, key) return Proto[key] end,
        __newindex = function(t, key, value)
            if S[t].sealed then error("wrote key '" .. tostring(key) .. "' on a Blizzard frame", 2) end
            rawset(t, key, value)
        end,
    })
end

-- Every setter: no secret value passed on, and a write by EraUI counted (not
-- Blizzard's own, not the other addon's).
local function Setter(name, fn)
    Proto[name] = function(self, ...)
        for i = 1, select("#", ...) do
            local v = select(i, ...)
            -- Noted as well as thrown: the hand-over runs inside a pcall.
            if v == SECRET or v == SECRET_SIZE then
                leaks[#leaks + 1] = name
                error(name .. " was given a secret value")
            end
        end
        if S[self].sealed and not blizzardCalling and not otherCalling then S[self].writes = S[self].writes + 1 end
        return fn(self, ...)
    end
end

local function Coords(...)
    local n = select("#", ...)
    if n == 4 then
        local l, r, t, b = ...
        return { l, t, l, b, r, t, r, b }
    end
    return { ... }
end

Setter("ClearAllPoints", function(self) S[self].points = {} end)
Setter("SetPoint", function(self, point, rel, relPoint, x, y)
    table.insert(S[self].points, { point, rel, relPoint or point, x or 0, y or 0 })
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
    if s.refuses then error("refused") end
    s.atlas, s.texture, s.colour = atlas, nil, nil
    s.coords = { 0, 0, 0, 1, 1, 0, 1, 1 }
end)
Setter("SetTexture", function(self, texture)
    local s = S[self]
    s.texture, s.atlas, s.colour = texture, nil, nil
    return true
end)
Setter("SetColorTexture", function(self, r, g, b, a)
    local s = S[self]
    s.colour, s.atlas, s.texture = table.concat({ r, g, b, a or 1 }, ","), nil, nil
end)
Setter("SetTexCoord", function(self, ...) S[self].coords = Coords(...) end)
Setter("SetVertexColor", function(self, r, g, b, a) S[self].tint = { r, g, b, a or 1 } end)
Setter("SetBlendMode", function(self, mode) S[self].blend = mode end)
Setter("SetFontObject", function(self, font)
    if type(font) == "string" then font = _G[font] end
    S[self].font = font
end)
Setter("SetAlpha", function(self, a) S[self].alpha = a end)
Setter("Show", function(self) S[self].shown = true end)
Setter("Hide", function(self) S[self].shown = false end)
Setter("SetShown", function(self, v) S[self].shown = v and true or false end)
Setter("SetStatusBarTexture", function(self, texture)
    local fill = S[self].fill
    S[fill].texture, S[fill].atlas = texture, nil
end)
Setter("SetStatusBarColor", function(self, r, g, b) S[self].fillColour = string.format("%g,%g,%g", r, g, b) end)
Setter("SetScale", function(self, scale) S[self].scale = scale end)
Setter("SetMinMaxValues", function() end)
Setter("SetValue", function() end)

function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i)
    local p = S[self].points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Proto:GetSize()
    local s = S[self]
    if s.secretSize then return SECRET_SIZE, SECRET_SIZE end
    return s.w, s.h
end
function Proto:GetWidth() return S[self].w end
function Proto:GetHeight() return S[self].h end
function Proto:GetAtlas() return S[self].atlas end
function Proto:GetTexture() return S[self].texture end
function Proto:GetTexCoord() return unpack(S[self].coords) end
function Proto:GetVertexColor() return unpack(S[self].tint) end
function Proto:GetBlendMode()
    if S[self].broken then error("can't be read") end
    return S[self].blend
end
function Proto:GetFontObject() return S[self].font end
function Proto:GetAlpha() return S[self].alpha end
function Proto:IsShown() return S[self].shown end
function Proto:GetParent() return S[self].parent end
function Proto:GetName() return S[self].name end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:GetScale() return S[self].scale or 1 end
function Proto:IsProtected() return S[self].protected == true end
function Proto:CreateTexture() return New("Texture", self) end

local function Seal(obj) S[obj].sealed = true end

-- Blizzard's fonts, by name like the game's.
for _, name in ipairs({ "SystemFont_Shadow_Small", "GameFontHighlight", "FECMFont10" }) do _G[name] = { name = name } end

-- Blizzard's code runs as itself; a hook runs as the addon's code.
hooksecurefunc = function(t, key, hook)
    if type(t) == "string" then t, key, hook = _G, t, key end
    local original = t[key]
    rawset(t, key, function(...)
        original(...)
        local was = blizzardCalling
        blizzardCalling = false
        hook(...)
        blizzardCalling = was
    end)
end
local function Blizzard(bar, method, ...)
    blizzardCalling = true
    bar[method](bar, ...)
    blizzardCalling = false
end

-- Blizzard's Boss1-5 spell bars (SmallCastingBarFrameTemplate, 120x10): its art,
-- anchors and fonts as the template has them, and the methods EraUI hooks.
local PIECES = { "TextBorder", "Background", "BorderShield", "Icon", "Border", "Spark", "Flash", "Text" }
local function Region(bar, key, kind)
    local r = New(kind or "Texture", bar)
    rawset(bar, key, r)
    return r
end
local function BossBar(i)
    local frame = New("Button", nil, "Boss" .. i .. "TargetFrame")
    local bar = New("StatusBar", frame, "Boss" .. i .. "TargetFrameSpellBar")
    S[bar].fill = New("Texture", bar)
    S[bar].w, S[bar].h = 120, 10
    local function Place(r, ...)
        for _, p in ipairs({ ... }) do table.insert(S[r].points, { p[1], bar, p[2] or p[1], p[3], p[4] }) end
    end
    -- Pieces held by two corners: the size they're laid out at, as the game reads it.
    local t = Region(bar, "TextBorder"); S[t].atlas = "ui-castingbar-textbox"; S[t].w, S[t].h = 120, 22
    Place(t, { "TOPLEFT", nil, 0, 0 }, { "BOTTOMRIGHT", nil, 0, -12 })
    t = Region(bar, "Background"); S[t].atlas = "ui-castingbar-background"; S[t].w, S[t].h = 120, 10
    Place(t, { "TOPLEFT", nil, 0, 0 }, { "BOTTOMRIGHT", nil, 0, 0 })
    t = Region(bar, "BorderShield"); S[t].atlas = "ui-castingbar-shield"; S[t].w, S[t].h = 29, 33; S[t].shown = false
    Place(t, { "TOPLEFT", nil, -27, 4 })
    t = Region(bar, "Icon"); S[t].w, S[t].h = 20, 20; S[t].texture = 136048
    Place(t, { "RIGHT", "LEFT", -2, -5 })
    t = Region(bar, "Border"); S[t].atlas = "ui-castingbar-frame"; S[t].w, S[t].h = 122, 14
    Place(t, { "TOPLEFT", nil, -1, 2 }, { "BOTTOMRIGHT", nil, 1, -2 })
    t = Region(bar, "Spark"); S[t].atlas = "ui-castingbar-pip"; S[t].w, S[t].h = 6, 16
    Place(t, { "CENTER", nil, 0, 0 })
    t = Region(bar, "Flash"); S[t].atlas = "ui-castingbar-full-glow-standard"; S[t].blend = "ADD"; S[t].w, S[t].h = 122, 12
    Place(t, { "TOPLEFT", nil, -1, 1 }, { "BOTTOMRIGHT", nil, 1, -1 })
    t = Region(bar, "Text", "FontString"); S[t].font = SystemFont_Shadow_Small; S[t].w, S[t].h = 120, 16
    Place(t, { "TOPLEFT", nil, 0, -8 }, { "TOPRIGHT", nil, 0, -8 })
    rawset(bar, "boss", "boss" .. i)
    local function Method(name, fn)
        rawset(bar, name, function(self, ...)
            assert(blizzardCalling, "EraUI ran Blizzard's " .. name)
            if fn then fn(self, ...) end
        end)
    end
    Method("SetLook")
    Method("UpdateShownState", function(self) self:Show() end)
    Method("UpdateBarFillTexture", function(self, atlas) S[S[self].fill].atlas, S[S[self].fill].texture = atlas, nil end)
    Method("ShowSpark", function(self) self.Spark:Show() end)
    Method("PlayFadeAnim")
    Method("PlayFinishAnim")
    Method("PlayInterruptAnims")
    Method("AdjustPosition", function(self)
        self:ClearAllPoints()
        self:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -100, 17)
    end)
    rawset(frame, "spellbar", bar)
    Seal(frame)
    Seal(bar)
    Seal(S[bar].fill)
    for _, key in ipairs(PIECES) do Seal(bar[key]) end
    return frame, bar
end

-- Everything EraUI could change on a boss bar, as one line (the fill aside).
local function Look(bar)
    local s = S[bar]
    local out = { "size " .. tostring(s.w) .. "x" .. tostring(s.h) }
    for _, key in ipairs(PIECES) do
        local r = S[bar[key]]
        local points = {}
        for _, p in ipairs(r.points) do
            local rel = p[2] == bar and "bar" or (p[2] and (S[p[2]].name or S[p[2]].kind)) or "nil"
            points[#points + 1] = p[1] .. ">" .. rel .. ":" .. tostring(p[3]) .. "(" .. tostring(p[4]) .. "," .. tostring(p[5]) .. ")"
        end
        out[#out + 1] = key .. "[" .. tostring(r.atlas or r.texture or r.colour) .. " coords " .. table.concat(r.coords, ",")
            .. " tint " .. table.concat(r.tint, ",") .. " " .. r.blend .. " font " .. tostring(r.font and r.font.name)
            .. " alpha " .. tostring(r.alpha) .. " shown " .. tostring(r.shown) .. " " .. tostring(r.w) .. "x" .. tostring(r.h)
            .. " at " .. table.concat(points, " ") .. "]"
    end
    return table.concat(out, " ")
end
local function Writes(bar)
    local n = S[bar].writes + S[S[bar].fill].writes
    for _, key in ipairs(PIECES) do n = n + S[bar[key]].writes end
    return n
end

-- The game and EraUI ----------------------------------------------------------------------

local combat = false
InCombatLockdown = function() return combat end
-- EraUI's own event frames, and the game's events sent to them.
local watchers = {}
CreateFrame = function()
    local f = { events = {} }
    function f:RegisterEvent(event) self.events[event] = true end
    function f:SetScript(_, fn) self.onEvent = fn end
    watchers[#watchers + 1] = f
    return f
end
local function Fire(event)
    for _, f in ipairs(watchers) do
        if f.events[event] and f.onEvent then f.onEvent(f, event) end
    end
end
issecretvalue = function(v) return v == SECRET or v == SECRET_SIZE end
GetTime = function() return 0 end
UnitChannelInfo = function() end
CreateColor = function(r, g, b) return { GetRGB = function() return r, g, b end } end

local bars, target, modules
local function Game(api)
    _G.ForeverEnhancedCooldownManagerAPI = api
    watchers, combat = {}, false
    bars = {}
    local frames = {}
    for i = 1, 5 do frames[i], bars[i] = BossBar(i) end
    BossTargetFrameContainer = { BossTargetFrames = frames }
    -- The target's spell bar: never handed over.
    local targetFrame = New("Frame", nil, "TargetFrame")
    local container = New("Frame", targetFrame)
    rawset(targetFrame, "GetAuraContainer", function() return container end)
    target = New("StatusBar", targetFrame, "TargetFrameSpellBar")
    S[target].fill = New("Texture", target)
    for _, key in ipairs({ "Border", "Spark", "Flash", "Background", "BorderShield", "Icon" }) do Region(target, key) end
    Region(target, "Text", "FontString")
    rawset(target, "AdjustPosition", function() end)
    rawset(target, "UpdateBarFillTexture", function(self, atlas)
        assert(blizzardCalling, "EraUI ran Blizzard's UpdateBarFillTexture")
        S[S[self].fill].atlas, S[S[self].fill].texture = atlas, nil
    end)
    rawset(targetFrame, "spellbar", target)
    TargetFrame = targetFrame
    modules = {}
    local ns = {
        RegisterModule = function(key, mod) modules[key] = mod end,
        -- With Dark Mode, as ThemeTexture does: the border darkened.
        SetTex = function(texture, key)
            local ok = texture:SetTexture("Classic\\" .. key)
            if key == "castBorderSmall" then texture:SetVertexColor(.42, .44, .48) end
            return ok
        end,
        HookMethod = function(frame, method, fn)
            if type(frame[method]) ~= "function" then return false end
            hooksecurefunc(frame, method, fn)
            return true
        end,
    }
    local E = { Classic = ns, GetSetting = function() return false end }
    assert(loadfile("Classic/CastBars.lua"))("EraUI", E)
end

-- A stand-in for the other addon's public API, its boss cast bar switch, and
-- what it does as the bars change hands: on, the callback first, then its own
-- look; off, Blizzard's look back first, then the callback.
local other
local function API()
    other = { on = false, shares = {}, heard = {} }
    local api = { version = 1 }
    function api.StylesBossCastBars() return other.on end
    function api.ShareBossCastBars(addon, callback)
        other.shares[#other.shares + 1] = addon
        other.callback = callback
        return true
    end
    return setmetatable({}, { __index = api, __newindex = function() error("read-only", 2) end, __metatable = false })
end
local function OtherLook(on)
    otherCalling = true
    for _, bar in ipairs(bars) do
        for _, key in ipairs({ "Border", "Background", "TextBorder" }) do bar[key]:SetAlpha(on and 0 or 1) end
        bar.Text:SetFontObject(on and "FECMFont10" or "SystemFont_Shadow_Small")
        if on then bar:SetStatusBarTexture("FECM flat") end
    end
    otherCalling = false
end
local function Switch(on)
    if on and not other.on then
        other.on = true
        if other.callback then other.callback() end
        local looks = {}
        for i, bar in ipairs(bars) do looks[i] = Look(bar) end
        other.heard[#other.heard + 1] = looks
        OtherLook(true)
    elseif not on and other.on then
        OtherLook(false)
        other.on = false
        if other.callback then other.callback() end
    end
end

-- A cast's fill, as Blizzard picks it.
local function Filled(bar, atlas)
    Blizzard(bar, "UpdateBarFillTexture", atlas)
end
-- Everything Blizzard does to a boss bar in a cast, in its order.
local function Cast(bar, atlas)
    Blizzard(bar, "UpdateBarFillTexture", atlas)
    Blizzard(bar, "ShowSpark")
    Blizzard(bar, "UpdateShownState")
    Blizzard(bar, "SetLook", "UNITFRAME")
    Blizzard(bar, "PlayFadeAnim")
    Blizzard(bar, "PlayInterruptAnims")
    Blizzard(bar, "PlayFinishAnim")
    Blizzard(bar, "AdjustPosition")
end

-- Every boss bar's look, one line each.
local function Looks()
    local out = {}
    for i, bar in ipairs(bars) do out[i] = Look(bar) end
    return out
end
local function All(looks, look)
    for _, each in ipairs(looks) do
        if each ~= look then return false end
    end
    return #looks == 5
end
local function AllWrites()
    local n = 0
    for _, bar in ipairs(bars) do n = n + Writes(bar) end
    return n
end

-- 1. No other addon: EraUI's look on the boss bars, as today ---------------------------------
Game(nil)
local pristine = Look(bars[1])
equal(All(Looks(), pristine), true, "Blizzard's five boss bars, all alike")
modules.castBars.apply()
local eraLook = Look(bars[1])
equal(eraLook ~= pristine and All(Looks(), eraLook), true, "no other addon: EraUI dresses all five boss bars")
equal(S[bars[1]].w .. "x" .. S[bars[1]].h .. " " .. S[bars[1].Border].texture .. " " .. S[bars[1].Icon].w,
    "150x10 Classic\\castBorderSmall 18", "the small Classic look")
Filled(bars[1], "ui-castingbar-filling-channel")
equal(S[S[bars[1]].fill].texture .. " " .. S[bars[1]].fillColour, "Interface\\TargetingFrame\\UI-StatusBar 0,1,0",
    "a boss channel in Classic green")
Cast(bars[1], "ui-castingbar-filling-standard")
equal(Look(bars[1]), eraLook, "and EraUI's look kept through a whole cast")
equal(S[target.Border].texture, "Classic\\castBorderSmall", "the target's bar too")

-- 2. The other addon without the API (an older one), or an API without the answer --------------
for _, case in ipairs({
    { "an older one, no API", nil },
    { "an API without the answer", { version = 1 } },
    { "an API that isn't a table", function() return true end },
}) do
    Game(case[2])
    modules.castBars.apply()
    Filled(bars[2], "ui-castingbar-filling-standard")
    equal(tostring(All(Looks(), eraLook)) .. " " .. S[bars[2]].fillColour, "true 1,0.7,0", case[1] .. ": EraUI's look, as today")
end

-- 3. The API, its switch off: EraUI's look, and EraUI says once that it steps back -------------
Game(API())
-- Blizzard may give a bar's name a font of its own: it's that one that comes back.
S[bars[2].Text].font = GameFontHighlight
local pristine2 = Look(bars[2])
-- Blizzard's look on each bar, as it was.
local function Blizzards(looks)
    return looks[2] == pristine2 and looks[1] == pristine and looks[3] == pristine and looks[4] == pristine
        and looks[5] == pristine
end
modules.castBars.apply()
modules.castBars.apply()
equal(tostring(All(Looks(), eraLook)) .. " " .. #other.shares .. " " .. tostring(other.shares[1]) .. " " .. type(other.callback),
    "true 1 EraUI function", "switch off: EraUI's look; it shares the bars once, by its folder name")
Filled(bars[1], "ui-castingbar-uninterruptable")
equal(S[bars[1]].fillColour, "0.5,0.5,0.5", "casts still EraUI's")

-- 4. Switched on at runtime: Blizzard's look back exactly, before the other look goes on --------
Switch(true)
equal(Blizzards(other.heard[1]), true, "ticked: by the callback, all five boss bars are back to Blizzard's look exactly")
equal(table.concat(S[bars[1].Border].tint, ","), "1,1,1,1", "Dark Mode's border tint gone")
equal(S[bars[5]].w .. " " .. S[bars[5].Border].atlas .. " " .. S[bars[5].BorderShield].atlas .. " " .. S[bars[5].Flash].atlas
    .. " " .. S[bars[5].Spark].blend .. " " .. S[bars[5].Spark].w .. " " .. S[bars[5].TextBorder].atlas .. " "
    .. tostring(S[bars[5].TextBorder].shown) .. " " .. S[bars[5].Icon].w,
    "120 ui-castingbar-frame ui-castingbar-shield ui-castingbar-full-glow-standard BLEND 6 ui-castingbar-textbox true 20",
    "size, frame, shield, flash, spark, name box and icon all Blizzard's")
local held = AllWrites()
for _, bar in ipairs(bars) do Cast(bar, "ui-castingbar-filling-standard") end
modules.castBars.apply()
equal(AllWrites() - held, 0, "then EraUI touches them no more: casts, every hook, and its own passes")
local now = Looks()
other.callback()
equal((AllWrites() - held) .. " " .. tostring(Looks()[2] == now[2]), "0 true", "a callback with nothing changed: EraUI writes nothing")
equal(S[S[bars[1]].fill].atlas .. " " .. S[bars[1].Border].alpha .. " " .. S[bars[1].Text].font.name,
    "ui-castingbar-filling-standard 0 FECMFont10", "Blizzard's fill and the other look left as they are")
equal(S[target.Border].texture .. " " .. S[S[target].fill].texture, "Classic\\castBorderSmall Interface\\TargetingFrame\\UI-StatusBar",
    "the target's bar stays EraUI's")
Filled(target, "ui-castingbar-filling-channel")
equal(S[S[target].fill].texture .. " " .. S[target].fillColour, "Interface\\TargetingFrame\\UI-StatusBar 0,1,0",
    "and its casts too: only the boss bars are handed over")

-- 5. Switched off: EraUI's look back at once, and on the next casts ---------------------------
Switch(false)
equal(All(Looks(), eraLook), true, "unticked: EraUI's look back on all five at once")
Filled(bars[1], "ui-castingbar-interrupted")
equal(S[bars[1]].fillColour, "1,0,0", "and its red when a boss cast is broken off")
Cast(bars[1], "ui-castingbar-filling-standard")
equal(Look(bars[1]), eraLook, "and its look through the next cast")
-- On and off again: the look kept from the first time is put back.
Switch(true)
equal(Blizzards(other.heard[2]), true, "ticked again: Blizzard's look again")
Switch(false)
equal(All(Looks(), eraLook), true, "unticked again: EraUI's again")

-- 6. On before EraUI loads: the boss bars are never touched ------------------------------------
Game(API())
other.on = true
modules.castBars.apply()
Cast(bars[3], "ui-castingbar-filling-channel")
modules.castBars.apply()
equal(AllWrites() .. " " .. tostring(All(Looks(), pristine)), "0 true", "already on at login: EraUI never touches a boss bar")
equal(S[target.Border].texture, "Classic\\castBorderSmall", "the target's bar still EraUI's")
Switch(false)
equal(All(Looks(), eraLook), true, "handed back later: EraUI's look then")
Switch(true)
equal(All(other.heard[1], pristine), true, "and taken again: Blizzard's look, read when EraUI first dressed them")

-- 7. Errors and odd answers from the API: EraUI's look, as today, and no error ------------------
local function Odd(label, api)
    Game(api)
    local ok, err = pcall(modules.castBars.apply)
    equal(ok, true, label .. ": no error (" .. tostring(err) .. ")")
    Cast(bars[1], "ui-castingbar-filling-standard")
    Filled(bars[2], "ui-castingbar-filling-channel")
    equal(tostring(All(Looks(), eraLook)) .. " " .. S[bars[2]].fillColour, "true 0,1,0", label .. ": EraUI's look")
end
Odd("the answer fails", setmetatable({}, { __index = {
    StylesBossCastBars = function() error("broken") end,
    ShareBossCastBars = function() return true end } }))
Odd("sharing fails", setmetatable({}, { __index = {
    StylesBossCastBars = function() return false end,
    ShareBossCastBars = function() error("broken") end } }))
Odd("reading the API fails", setmetatable({}, { __index = function() error("broken") end }))
for _, answer in ipairs({ "true", 1, SECRET, {} }) do
    Odd("an answer of " .. tostring(answer), { StylesBossCastBars = function() return answer end })
end

-- 8. Sharing waits for the API, and is tried again on the next pass ------------------------------
Game(nil)
modules.castBars.apply()
_G.ForeverEnhancedCooldownManagerAPI = API()
modules.castBars.apply()
equal(#other.shares, 1, "the API there later: shared on the next pass")
Switch(true)
equal(All(other.heard[1], pristine), true, "and its callback works from then on")
local tries = 0
Game(setmetatable({}, { __index = {
    StylesBossCastBars = function() return false end,
    ShareBossCastBars = function() tries = tries + 1; return tries > 1 end } }))
modules.castBars.apply()
modules.castBars.apply()
modules.castBars.apply()
equal(tries, 2, "not heard the first time: tried again, then no more")

-- 9. Cast Bars switched off in EraUI while the other addon has the boss bars ---------------------
Game(API())
modules.castBars.apply()
Switch(true)
held = AllWrites()
modules.castBars.restore()
modules.castBars.restore()
equal((AllWrites() - held) .. " " .. S[target.Border].atlas, "0 ui-castingbar-frame",
    "switched off: the boss bars left to the other addon, the target's put back")
Switch(false)
equal(All(Looks(), pristine), true, "handed back while EraUI's off: Blizzard's look stays")
-- Switched off while EraUI still has them: its usual partial put back, as today.
Game(API())
modules.castBars.apply()
modules.castBars.restore()
equal(S[bars[1].Border].atlas .. " " .. S[bars[1].TextBorder].alpha, "ui-castingbar-frame 1", "EraUI's own boss bars: put back as today")
Switch(true)
equal(All(other.heard[1], pristine), true, "then taken: Blizzard's look in full")

-- 10. A size that can't be read, and a bar that can't be resized in a fight ---------------------
Game(API())
S[bars[1].Icon].secretSize = true
modules.castBars.apply()
Switch(true)
local icon = S[bars[1].Icon]
equal(icon.w .. " " .. icon.points[1][1] .. " " .. icon.points[1][4] .. "," .. icon.points[1][5] .. " " .. S[bars[1].Border].atlas,
    "18 RIGHT -2,-5 ui-castingbar-frame", "a secret size: left as it is, the rest put back")
equal(other.heard[1][2] .. " " .. other.heard[1][5], pristine .. " " .. pristine, "the other bars in full")
equal(table.concat(leaks, ","), "", "no secret value ever passed to a setter")
-- Its spark's size secret too, read after the icon's: still nothing passed on, the rest put back.
Game(API())
S[bars[1].Icon].secretSize, S[bars[1].Spark].secretSize = true, true
modules.castBars.apply()
Switch(true)
equal(table.concat(leaks, ",") .. " " .. S[bars[1].Spark].atlas .. " " .. S[bars[1].Spark].blend .. " " .. S[bars[1].Border].atlas,
    " ui-castingbar-pip BLEND ui-castingbar-frame", "two secret sizes: nothing passed on, the rest put back")
-- A piece that can't be read at all: left as it is, every other piece put back.
Game(API())
S[bars[1].Flash].broken = true
modules.castBars.apply()
Switch(true)
equal(S[bars[1].Flash].texture .. " " .. S[bars[1].Spark].atlas .. " " .. S[bars[1].Border].atlas .. " " .. S[bars[1]].w,
    "Classic\\castFlashSmall ui-castingbar-pip ui-castingbar-frame 120", "a piece that can't be read: only it stays EraUI's")
equal(other.heard[1][2], pristine, "and the other bars in full")
-- A piece whose art won't go back: the others still do.
Game(API())
modules.castBars.apply()
for _, key in ipairs(PIECES) do S[bars[1][key]].refuses = key == "Spark" end
Switch(true)
local rest = {}
for _, key in ipairs({ "Border", "Flash", "Background", "BorderShield", "TextBorder" }) do rest[#rest + 1] = S[bars[1][key]].atlas end
equal(table.concat(rest, " ") .. " " .. S[bars[1].Icon].w .. " " .. S[bars[1].Text].points[1][5] .. " " .. S[bars[1]].w,
    "ui-castingbar-frame ui-castingbar-full-glow-standard ui-castingbar-background ui-castingbar-shield ui-castingbar-textbox 20 -8 120",
    "a piece that won't go back: every other piece put back")
-- Protected in a fight: its art goes back at once, its own size when the fight ends.
Game(API())
modules.castBars.apply()
S[bars[1]].protected = true
combat = true
Switch(true)
equal(S[bars[1]].w .. " " .. S[bars[2]].w .. " " .. S[bars[1].Border].atlas, "150 120 ui-castingbar-frame",
    "protected in a fight: its size waits, its art is put back")
held = AllWrites()
for _, bar in ipairs(bars) do Cast(bar, "ui-castingbar-filling-standard") end
equal((AllWrites() - held) .. " " .. S[bars[1]].w, "0 150", "through the fight: nothing touched, its size still waiting")
combat = false
Fire("PLAYER_REGEN_ENABLED")
equal(S[bars[1]].w .. " " .. tostring(Look(bars[1]) == Look(bars[2])) .. " " .. (AllWrites() - held), "120 true 2",
    "the fight over: Blizzard's size back (its width and height only), under the other look like the rest")
Fire("PLAYER_REGEN_ENABLED")
equal(AllWrites() - held, 2, "and only once")
-- Handed back in the same fight: EraUI's own size stays after it, then taken
-- again in the next fight: Blizzard's size when that one ends.
Game(API())
modules.castBars.apply()
S[bars[1]].protected = true
combat = true
Switch(true)
Switch(false)
combat = false
Fire("PLAYER_REGEN_ENABLED")
equal(Look(bars[1]), eraLook, "handed back in the fight: EraUI's look and size kept after it")
combat = true
Switch(true)
combat = false
Fire("PLAYER_REGEN_ENABLED")
equal(tostring(Look(bars[1]) == Look(bars[2])) .. " " .. S[bars[1]].w, "true 120", "taken in the next fight: Blizzard's size after it")
-- Not protected, in a fight: no wait.
Game(API())
modules.castBars.apply()
combat = true
Switch(true)
equal(S[bars[1]].w .. " " .. #watchers, "120 0", "not protected: its size back at once, nothing left waiting")
combat = false

-- 11. Shared at login, before EraUI's first pass (after a /reload in a fight that
-- pass waits for the fight's end): the other addon can take the bars at once.
Game(API())
equal(type(modules.castBars.init), "function", "Cast Bars has a login step")
modules.castBars.init()
equal(#other.shares .. " " .. tostring(other.shares[1]) .. " " .. AllWrites(), "1 EraUI 0", "at login: shared, nothing touched")
combat = true
Switch(true)
equal(AllWrites() .. " " .. tostring(All(other.heard[1], pristine)), "0 true", "taken in the fight: no EraUI look to put away")
combat = false
modules.castBars.apply()
Cast(bars[2], "ui-castingbar-filling-channel")
equal(AllWrites() .. " " .. #other.shares .. " " .. S[target.Border].texture, "0 1 Classic\\castBorderSmall",
    "EraUI's pass after the fight: boss bars left alone, shared only once, the target's bar EraUI's")
Switch(false)
equal(All(Looks(), eraLook), true, "handed back: EraUI's look")
Switch(true)
equal(All(other.heard[2], pristine), true, "taken again: Blizzard's look, read when EraUI first dressed them")
-- No other addon at login: nothing shared, EraUI's look at its first pass.
Game(nil)
modules.castBars.init()
modules.castBars.apply()
equal(All(Looks(), eraLook), true, "no other addon at login: EraUI's look, as today")

print("Boss cast bar checks passed: " .. checks .. " assertions.")
