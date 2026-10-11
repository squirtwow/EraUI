-- Flat Bars (/era: Appearance > Style > Frame Style) on the real unit frames:
-- Classic/Textures.lua, Classic/Skin.lua and Classic/UnitFrames.lua against a
-- mock of the game's player (with its heal prediction, absorb and health-loss
-- bars), target and focus (each with its target of target), pet and party
-- frames. Off: every bar EraUI owns or dresses has today's Classic shaded
-- fill, exactly (texture source "bundled" too). On: the client's solid white
-- square on every one of them, the colours unchanged. Switched live both
-- ways, the switch changes the fill and nothing else (only texture and
-- colour calls, no key written on the game's frames); a pass writes no key on
-- the game's frames either way. The pet's kept bars stay solid
-- through their 0.25 s repaint after the game changes them. A protected bar
-- in a fight waits for the pass after it (booked), the rest change at once.
-- With the unit frames switched off, the game's pieces are left alone.
-- (The cast bars: Tools/TestBossCastBars.lua; the Advanced Cast Bar:
-- Tools/TestChannelTiming.lua; the /era row: Tools/TestSettingsLayout.lua.)
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack

local SHADED = "Interface\\TargetingFrame\\UI-StatusBar"
local SOLID = "Interface\\Buttons\\WHITE8X8"
local BUNDLED_SHADED = "Interface\\AddOns\\EraUI\\Media\\Classic\\UI-StatusBar"

-- Mock widgets --------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's frames shows up: writes lists them as "Name.key".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes = {}
local calls, logging = {}, false
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear" }
local function Verb(key)
    if type(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local function Noop() end
local function New(kind, name, parent, game)
    local obj = {}
    S[obj] = { kind = kind, name = name, parent = parent, game = game, points = {}, scripts = {}, level = 1, shown = true, alpha = 1 }
    return setmetatable(obj, {
        __index = function(_, key)
            local fn = Proto[key] or (Verb(key) and Noop)
            if not fn then return nil end
            return function(self, ...)
                if logging then calls[#calls + 1] = key end
                return fn(self, ...)
            end
        end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
function Proto:GetName() return S[self].name end
function Proto:GetParent() return S[self].parent end
function Proto:SetParent(p) S[self].parent = p end
function Proto:IsObjectType(kind) return S[self].kind == kind end
function Proto:GetFrameLevel() return S[self].level end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:GetScale() return 1 end
function Proto:IsShown() return S[self].shown end
function Proto:Show() S[self].shown = true end
function Proto:Hide() S[self].shown = false end
function Proto:SetShown(v) S[self].shown = v and true or false end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(...) table.insert(S[self].points, { ... }) end
function Proto:SetAllPoints(rel) S[self].points = { { "TOPLEFT", rel }, { "BOTTOMRIGHT", rel } } end
function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i) local p = S[self].points[i or 1]; if p then return unpack(p, 1, 5) end end
function Proto:SetSize(w, h) S[self].w, S[self].h = w, h end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
function Proto:HookScript() end
function Proto:IsProtected() return S[self].protected == true end
function Proto:CreateTexture() return New("Texture", nil, self, false) end
function Proto:CreateFontString() return New("FontString", nil, self, false) end
-- Textures: the file shown and the tex coords.
function Proto:SetTexture(file) S[self].file = file; return true end
function Proto:SetTexCoord(...) S[self].coords = table.concat({ ... }, ",") end
-- Status bars: the fill is a texture of the bar's own; a new colour is the
-- bar's (the game's default is white). forgetful: a new fill drops the bar's
-- colour, so a switch that counted on the game keeping it shows up.
local forgetful = false
function Proto:SetStatusBarTexture(file)
    local s = S[self]
    s.fill = s.fill or New("Texture", nil, self, s.game)
    S[s.fill].file = file
    s.fillSets = (s.fillSets or 0) + 1
    if forgetful then s.colour = nil end
end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:SetStatusBarColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:GetStatusBarColor()
    local c = S[self].colour or { 1, 1, 1, 1 }
    return c[1], c[2], c[3], c[4]
end

-- The game -------------------------------------------------------------------
local combat = false
InCombatLockdown = function() return combat end
issecretvalue = function() return false end
CreateFrame = function(kind, name, parent)
    local f = New(kind, name, parent, false)
    if name then _G[name] = f end
    return f
end
CreateFont = function() return { SetFontObject = Noop, SetTextColor = Noop } end
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    local old = t[key]
    t[key] = function(...) old(...); fn(...) end
end
C_Timer = { After = Noop }
UIParent = New("Frame", "UIParent", nil, true)
UnitExists = function() return true end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 30 end
UnitPowerMax = function() return 100 end
-- The target and its target use rage, everyone else mana, so the colours differ.
UnitPowerType = function(unit)
    if unit == "target" or unit == "targettarget" then return 1, "RAGE" end
    return 0, "MANA"
end
UnitIsPlayer = function() return false end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitClassification = function() return "normal" end
UnitName = function() return "Name" end
UnitLevel = function() return 10 end
UnitCanAttack = function() return true end
UnitIsPVP = function() return false end
UnitFactionGroup = function() return "Alliance" end
UnitAffectingCombat = function() return false end
IsResting = function() return false end

local settings = { enabled = true, matchFocusSize = false }
local E = { GetSetting = function(_, key) return settings[key] end }
local ns, modules, booked
local OVERLAYS = { "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }
local bars -- every bar EraUI owns or dresses: { label, bar }, plus the overlay fills: { label, texture }

-- The game's frames (keys set before EraUI loads, as the game's XML does),
-- and a fresh EraUI on them. flat: Flat Bars at login.
local function Game(flat, source)
    settings.flatBars = flat
    writes = {}
    local function G(kind, name, parent) return New(kind, name, parent, true) end
    local function Put(obj, key, value) rawset(obj, key, value); return value end
    local fills = {}
    local function Overlays(health, who)
        for _, key in ipairs(OVERLAYS) do
            local piece = Put(health, key, G("Frame", who .. key, health))
            fills[#fills + 1] = { who .. " " .. key, Put(piece, "Fill", G("Texture", who .. key .. "Fill", piece)) }
        end
    end
    PlayerFrame = G("Button", "PlayerFrame", UIParent)
    Put(PlayerFrame, "PlayerFrameContainer", G("Frame", "PlayerFrameContainer", PlayerFrame))
    local content = Put(PlayerFrame, "PlayerFrameContent", G("Frame", "PlayerFrameContent", PlayerFrame))
    local main = Put(content, "PlayerFrameContentMain", G("Frame", "PlayerFrameContentMain", content))
    Put(content, "PlayerFrameContentContextual", G("Frame", "PlayerFrameContentContextual", content))
    local container = Put(main, "HealthBarsContainer", G("Frame", "PlayerHealthBarsContainer", main))
    Overlays(Put(container, "HealthBar", G("StatusBar", "PlayerFrameHealthBar", container)), "player")
    local loss = Put(container, "PlayerFrameHealthBarAnimatedLoss", G("StatusBar", "PlayerFrameHealthBarAnimatedLoss", container))
    loss:SetStatusBarTexture("game's loss fill")
    loss:SetStatusBarColor(1, 0, 0, 1)
    Put(container, "HealthBarMask", G("MaskTexture", "PlayerHealthBarMask", container))
    local manaArea = Put(main, "ManaBarArea", G("Frame", "PlayerManaBarArea", main))
    Put(manaArea, "ManaBar", G("StatusBar", "PlayerFrameManaBar", manaArea))
    local function TargetLike(name, unit)
        local frame = G("Button", name, UIParent)
        Put(frame, "unit", unit)
        Put(frame, "TargetFrameContainer", G("Frame", name .. "Container", frame))
        local c = Put(frame, "TargetFrameContent", G("Frame", name .. "Content", frame))
        local m = Put(c, "TargetFrameContentMain", G("Frame", name .. "ContentMain", c))
        Put(c, "TargetFrameContentContextual", G("Frame", name .. "ContentContextual", c))
        local hc = Put(m, "HealthBarsContainer", G("Frame", name .. "HealthBarsContainer", m))
        Overlays(Put(hc, "HealthBar", G("StatusBar", name .. "HealthBar", hc)), unit)
        Put(m, "ManaBar", G("StatusBar", name .. "ManaBar", m))
        local tot = Put(frame, "totFrame", G("Button", name .. "ToT", frame))
        Put(tot, "HealthBar", G("StatusBar", name .. "ToTHealthBar", tot))
        Put(tot, "ManaBar", G("StatusBar", name .. "ToTManaBar", tot))
        return frame
    end
    TargetFrame = TargetLike("TargetFrame", "target")
    FocusFrame = TargetLike("FocusFrame", "focus")
    PetFrame = G("Button", "PetFrame", UIParent)
    Put(PetFrame, "unit", "pet")
    PetFrameHealthBar = G("StatusBar", "PetFrameHealthBar", PetFrame)
    PetFrameManaBar = G("StatusBar", "PetFrameManaBar", PetFrame)
    local member = G("Button", "PartyMemberFrame1", UIParent)
    Put(member, "unit", "party1")
    local hc = Put(member, "HealthBarContainer", G("Frame", "PartyHealthBarContainer", member))
    Overlays(Put(hc, "HealthBar", G("StatusBar", "PartyHealthBar", hc)), "party")
    Put(member, "ManaBar", G("StatusBar", "PartyManaBar", member))
    PartyFrame = G("Frame", "PartyFrame", UIParent)
    Put(PartyFrame, "PartyMemberFramePool", { EnumerateActive = function() return pairs({ [member] = true }) end })

    ns, modules, booked = {}, {}, 0
    E.Classic = ns
    if source then ns.db = { textureSource = source } end
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.SafeCall = function(fn, ...) local ok, err = pcall(fn, ...); assert(ok, err); return ok end
    ns.QueueApply, ns.ApplyAll = Noop, function() booked = booked + 1 end
    assert(loadfile("Classic/Textures.lua"))("EraUI", E)
    assert(loadfile("Classic/Skin.lua"))("EraUI", E)
    assert(loadfile("Classic/UnitFrames.lua"))("EraUI", E)
    modules.unitFrames.apply()

    -- EraUI's own pieces are kept beside the game's frames (ns.UnitFrameOwn),
    -- never on them.
    local function Own(frame, label)
        local host = ns.UnitFrameOwn(frame, "host")
        return { { label .. " health", host.fcui.health, true }, { label .. " power", host.fcui.power, true } }
    end
    bars = {}
    for _, list in ipairs({ Own(PlayerFrame, "player"), Own(TargetFrame, "target"), Own(FocusFrame, "focus"), Own(member, "party") }) do
        for _, entry in ipairs(list) do bars[#bars + 1] = entry end
    end
    for _, frame in ipairs({ TargetFrame, FocusFrame }) do
        local tot = frame.totFrame
        bars[#bars + 1] = { S[frame].name .. " target of target health", ns.UnitFrameOwn(tot, "totHealth"), true }
        bars[#bars + 1] = { S[frame].name .. " target of target power", ns.UnitFrameOwn(tot, "totPower"), true }
    end
    bars[#bars + 1] = { "player health loss", loss }
    bars[#bars + 1] = { "pet health", PetFrameHealthBar }
    bars[#bars + 1] = { "pet power", PetFrameManaBar }
    bars.fills = fills
    return member
end

-- What every bar and fill shows: "label=file" lines, its colour, and the
-- own bars' tex coords; and whether every one shows file.
local function Shown()
    local out = {}
    for _, entry in ipairs(bars) do out[#out + 1] = entry[1] .. "=" .. tostring(S[S[entry[2]].fill].file) end
    for _, entry in ipairs(bars.fills) do out[#out + 1] = entry[1] .. "=" .. tostring(S[entry[2]].file) end
    return out
end
local function All(file)
    local wrong = {}
    for _, line in ipairs(Shown()) do
        if line:sub(-#file - 1) ~= "=" .. file then wrong[#wrong + 1] = line end
    end
    return #wrong == 0 and "all" or table.concat(wrong, "; ")
end
local function Colours()
    local out = {}
    for _, entry in ipairs(bars) do out[#out + 1] = entry[1] .. ":" .. table.concat({ entry[2]:GetStatusBarColor() }, ",") end
    return table.concat(out, " ")
end
local function Coords()
    local out = {}
    for _, entry in ipairs(bars) do
        if entry[3] then out[#out + 1] = tostring(S[S[entry[2]].fill].coords) end
    end
    return table.concat(out, " ")
end
-- The twelve own bars, each on its whole sheet.
local WHOLE = {}
for i = 1, 12 do WHOLE[i] = "0,1,0,1" end
WHOLE = table.concat(WHOLE, " ")
local function Unique(list)
    local seen, out = {}, {}
    for _, item in ipairs(list) do if not seen[item] then seen[item] = true; out[#out + 1] = item end end
    table.sort(out)
    return table.concat(out, ",")
end
-- The calls made on any widget while fn runs, as one sorted list of names.
local ALLOWED = { SetStatusBarTexture = true, GetStatusBarTexture = true, SetTexCoord = true, GetStatusBarColor = true,
    SetStatusBarColor = true, SetTexture = true, IsProtected = true, GetParent = true }
local function Watch(fn)
    calls, logging = {}, true
    local before = #writes
    local result = fn()
    logging = false
    local odd = {}
    for _, name in ipairs(calls) do if not ALLOWED[name] then odd[#odd + 1] = name end end
    return result, #writes - before, Unique(odd)
end
local function Find(fn, wanted, seen)
    seen = seen or {}
    if seen[fn] then return end
    seen[fn] = true
    for i = 1, 200 do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then return value end
        if type(value) == "function" then
            local found = Find(value, wanted, seen)
            if found then return found end
        end
    end
end

-- 1. Off (the default): today's Classic shaded fill, exactly ---------------------------------
Game(false)
equal(#bars .. " " .. #bars.fills, "15 16", "twelve own bars, the health-loss bar, two pet bars and sixteen overlay fills")
equal(All(SHADED), "all", "off: every bar and fill has the Classic shaded fill")
equal(Coords(), WHOLE, "off: the own bars' whole sheet, as before")
equal(ns.TexPath("statusBar"), SHADED, "the shaded fill is the statusBar key's")
local offColours = Colours()
equal(offColours:find("player health:0,1,0", 1, true) ~= nil and offColours:find("target power:1,0,0", 1, true) ~= nil
    and offColours:find("player health loss:1,0,0,1", 1, true) ~= nil and offColours:find("pet health:0,1,0", 1, true) ~= nil,
    true, "the bars' own colours: green health, red rage, the game's red loss bar")
local offWrites = Unique(writes)
-- No key on any of the game's frames (player, target, focus, their targets of
-- target, pet, party member, or a piece of one): a value EraUI writes there
-- carries its taint into Blizzard's own code that reads it in a fight.
equal(offWrites, "", "a pass writes no key on the game's frames")
Game(false, "bundled")
equal(All(BUNDLED_SHADED), "all", "off with the bundled art chosen: the bundled shaded copy, as before")

-- 2. On at login: the solid square on every one, colours as they were -----------------------
Game(true)
equal(All(SOLID), "all", "on at login: every bar and fill solid")
equal(ns.TexPath("statusBarSolid"), SOLID, "the solid fill is the client's own white square")
equal(ns.BarFill("statusBar"), SOLID, "ns.BarFill gives the solid square while it's on")
equal(Coords(), WHOLE, "on: the own bars' tex coords as before")
equal(Colours(), offColours, "on: every bar's colour the same as with it off")
equal(Unique(writes), offWrites, "a pass writes the same keys on the game's frames either way")
Game(true, "bundled")
equal(All(SOLID), "all", "on with the bundled art chosen: the same solid square (it ships with the client)")

-- 3. Switched live, both ways (the colours kept even if the game dropped them) ------------------
Game(false)
forgetful = true
settings.flatBars = true
local done, keys, odd = Watch(ns.RefreshFlatBars)
equal(All(SOLID), "all", "ticked: every bar and fill solid at once")
equal(tostring(done) .. " " .. keys .. " [" .. odd .. "] " .. booked, "true 0 [] 0",
    "only fills and colours change, no key on the game's frames, nothing waits")
equal(Colours(), offColours, "ticked: colours unchanged")
equal(Coords(), WHOLE, "ticked: the own bars' tex coords kept")
settings.flatBars = false
done, keys, odd = Watch(ns.RefreshFlatBars)
equal(All(SHADED), "all", "unticked: the Classic shaded fill back on every one")
equal(tostring(done) .. " " .. keys .. " [" .. odd .. "]", "true 0 []", "unticked: fills and colours only, no keys")
equal(Colours(), offColours, "unticked: colours unchanged")
-- A bar repainted since (the game's own colour change) keeps its new colour.
bars[1][2]:SetStatusBarColor(.2, .4, .6, 1)
settings.flatBars = true
ns.RefreshFlatBars()
equal(table.concat({ bars[1][2]:GetStatusBarColor() }, ","), "0.2,0.4,0.6,1", "a switch keeps the colour a bar has now")
forgetful = false
-- The next pass (a target change, Edit Mode, a reload) keeps the choice.
modules.unitFrames.apply()
equal(All(SOLID), "all", "the next pass keeps them solid")
settings.flatBars = false
modules.unitFrames.apply()
equal(All(SHADED), "all", "and with it off, shaded")

-- 4. The pet's kept bars through their 0.25 s repaint -------------------------------------------
local driver = Find(modules.unitFrames.apply, "driver")
equal(type(driver), "table", "the unit frames' driver")
settings.flatBars = true
-- The game puts its own fill back on the pet's bars (a new pet, a vehicle).
PetFrameHealthBar:SetStatusBarTexture("game's pet fill")
PetFrameManaBar:SetStatusBarTexture("game's pet fill")
S[driver].scripts.OnUpdate(driver, .3)
equal(S[S[PetFrameHealthBar].fill].file .. " " .. S[S[PetFrameManaBar].fill].file, SOLID .. " " .. SOLID,
    "on: the repaint puts the solid fill back on the pet's bars")
equal(table.concat({ PetFrameHealthBar:GetStatusBarColor() }, ","), "0,1,0", "in the pet's green")
settings.flatBars = false
PetFrameHealthBar:SetStatusBarTexture("game's pet fill")
S[driver].scripts.OnUpdate(driver, .3)
equal(S[S[PetFrameHealthBar].fill].file, SHADED, "off: the repaint puts the shaded fill back, as before")
-- In a fight too, as before (only a texture and a colour).
combat = true
settings.flatBars = true
PetFrameHealthBar:SetStatusBarTexture("game's pet fill")
S[driver].scripts.OnUpdate(driver, .3)
equal(S[S[PetFrameHealthBar].fill].file, SOLID, "in a fight the repaint keeps them solid too")
combat = false

-- 5. A protected bar in a fight waits for the pass after it -----------------------------------
Game(false)
local held, heldLoss = bars[1][2], bars[13][2]
S[held].protected, S[heldLoss].protected = true, true
local heldSets = S[held].fillSets
combat = true
settings.flatBars = true
done, keys = Watch(ns.RefreshFlatBars)
equal(tostring(done) .. " " .. booked .. " " .. keys, "false 1 0", "in a fight: something waits, one pass booked for its end, no keys")
equal(S[S[held].fill].file .. " " .. S[held].fillSets - heldSets .. " " .. S[S[heldLoss].fill].file, SHADED .. " 0 " .. SHADED,
    "the protected bars left alone in the fight")
local others = 0
for i, entry in ipairs(bars) do
    if i ~= 1 and i ~= 13 and S[S[entry[2]].fill].file == SOLID then others = others + 1 end
end
equal(others, #bars - 2, "every other bar solid at once")
combat = false
modules.unitFrames.apply() -- the booked pass, as Classic/Core.lua runs it at PLAYER_REGEN_ENABLED
equal(All(SOLID), "all", "after the fight: the pass gives them the solid fill too")

-- 6. Unit frames switched off: the game's pieces are left alone --------------------------------
Game(false)
modules.unitFrames.restore()
PetFrameHealthBar:SetStatusBarTexture("game's pet fill")
settings.flatBars = true
done, keys = Watch(ns.RefreshFlatBars)
equal(tostring(done) .. " " .. keys .. " " .. S[S[PetFrameHealthBar].fill].file .. " " .. S[bars.fills[1][2]].file,
    "true 0 game's pet fill " .. SHADED, "unit frames off: no game piece touched")

print("Flat Bars checks passed: " .. checks .. " assertions.")
