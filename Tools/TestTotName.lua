-- The target of target's name (Classic/UnitFrames.lua) against a mock of the
-- game's target and focus frames. The client never rewrites that name when
-- the target of target becomes you, so the previous name lingered (seen in
-- game 2026-10-13: a Forsaken Herbalist targeting you showed "Forsaken
-- Seeker", the previous target). EraUI checks the name for a moment after
-- each change and puts the right one back; a name that already fits is left
-- alone, and so is one another addon swaps in once the moment has passed
-- (the privacy addon relabels names as they are written). No key is ever
-- written on the game's frames.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack

-- Mock widgets --------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's frames shows up in writes as "Name.key".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes = {}
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
        __index = function(_, key) return Proto[key] or (Verb(key) and Noop) or nil end,
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
function Proto:IsProtected() return false end
function Proto:CreateTexture() return New("Texture", nil, self, false) end
function Proto:CreateFontString() return New("FontString", nil, self, false) end
function Proto:SetTexture(file) S[self].file = file; return true end
function Proto:SetStatusBarTexture(file)
    local s = S[self]
    s.fill = s.fill or New("Texture", nil, self, s.game)
    S[s.fill].file = file
end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:SetStatusBarColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:GetStatusBarColor() local c = S[self].colour or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
-- Font strings: the text, and how many times EraUI wrote it.
-- relabel: another addon's hook that swaps every text written for its own label.
function Proto:SetText(text)
    local s = S[self]
    s.text, s.sets = text, (s.sets or 0) + 1
    if s.relabel then s.text = s.relabel end
end
function Proto:GetText() return S[self].text end

-- The game -------------------------------------------------------------------
local now = 100
GetTime = function() return now end
InCombatLockdown = function() return false end
local secret = {}
issecretvalue = function(v) return v ~= nil and secret[v] == true end
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
-- Who each unit is (UnitName's first value: the first name only, as on Forever).
local names = { player = "Zriel", target = "Forsaken Herbalist", targettarget = "Forsaken Seeker",
    focus = "Forsaken Seeker", focustarget = "Zriel" }
UnitExists = function(unit) return names[unit] ~= nil end
UnitName = function(unit) return names[unit] end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 30 end
UnitPowerMax = function() return 100 end
UnitPowerType = function() return 0, "MANA" end
UnitIsPlayer = function() return false end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitClassification = function() return "normal" end
UnitLevel = function() return 10 end
UnitCanAttack = function() return true end
UnitIsPVP = function() return false end
UnitFactionGroup = function() return "Alliance" end
UnitAffectingCombat = function() return false end
IsResting = function() return false end

local settings = { enabled = true, matchFocusSize = false, hideSecondaryNames = false }
local E = { GetSetting = function(_, key) return settings[key] end }
local ns, modules = {}, {}

-- The game's frames (keys set before EraUI loads, as the game's XML does).
local function G(kind, name, parent) return New(kind, name, parent, true) end
local function Put(obj, key, value) rawset(obj, key, value); return value end
PlayerFrame = G("Button", "PlayerFrame", UIParent)
Put(PlayerFrame, "PlayerFrameContainer", G("Frame", "PlayerFrameContainer", PlayerFrame))
local content = Put(PlayerFrame, "PlayerFrameContent", G("Frame", "PlayerFrameContent", PlayerFrame))
local main = Put(content, "PlayerFrameContentMain", G("Frame", "PlayerFrameContentMain", content))
Put(content, "PlayerFrameContentContextual", G("Frame", "PlayerFrameContentContextual", content))
local container = Put(main, "HealthBarsContainer", G("Frame", "PlayerHealthBarsContainer", main))
Put(container, "HealthBar", G("StatusBar", "PlayerFrameHealthBar", container))
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
    Put(hc, "HealthBar", G("StatusBar", name .. "HealthBar", hc))
    Put(m, "ManaBar", G("StatusBar", name .. "ManaBar", m))
    local tot = Put(frame, "totFrame", G("Button", name .. "ToT", frame))
    Put(tot, "unit", unit .. "target")
    Put(tot, "HealthBar", G("StatusBar", name .. "ToTHealthBar", tot))
    Put(tot, "ManaBar", G("StatusBar", name .. "ToTManaBar", tot))
    Put(tot, "Name", G("FontString", name .. "ToTName", tot))
    return frame
end
TargetFrame = TargetLike("TargetFrame", "target")
FocusFrame = TargetLike("FocusFrame", "focus")
PetFrame = G("Button", "PetFrame", UIParent)
Put(PetFrame, "unit", "pet")
PetFrameHealthBar = G("StatusBar", "PetFrameHealthBar", PetFrame)
PetFrameManaBar = G("StatusBar", "PetFrameManaBar", PetFrame)
PartyFrame = G("Frame", "PartyFrame", UIParent)
Put(PartyFrame, "PartyMemberFramePool", { EnumerateActive = function() return pairs({}) end })

-- The client wrote both names before EraUI loaded.
local tName, fName = TargetFrame.totFrame.Name, FocusFrame.totFrame.Name
S[tName].text, S[fName].text = "Forsaken Seeker", "Zriel"

E.Classic = ns
ns.RegisterModule = function(key, mod) modules[key] = mod end
ns.SafeCall = function(fn, ...) local ok, err = pcall(fn, ...); assert(ok, err); return ok end
ns.QueueApply, ns.ApplyAll = Noop, Noop
assert(loadfile("Classic/Textures.lua"))("EraUI", E)
assert(loadfile("Classic/Skin.lua"))("EraUI", E)
assert(loadfile("Classic/UnitFrames.lua"))("EraUI", E)
modules.unitFrames.apply()

local holder = S[ns.UnitFrameOwn(TargetFrame.totFrame, "artHolder")].scripts
local function Event() holder.OnEvent(nil, "UNIT_TARGET", "target") end
local function Tick(seconds) now = now + seconds; holder.OnUpdate(nil, seconds) end
local function Sets(label) return S[label].sets or 0 end

-- Names that already fit are left alone.
equal(S[tName].text .. "|" .. S[fName].text .. "|" .. Sets(tName) .. "|" .. Sets(fName), "Forsaken Seeker|Zriel|0|0",
    "at login both names fit: nothing written")

-- The bug: the Herbalist targets you, the client recolours but never rewrites
-- the name, so the previous one stays. EraUI puts yours back at once.
names.targettarget = "Zriel"
Event()
equal(S[tName].text, "Zriel", "the target of target became you: your name, not the previous one")

-- The client writes the old name again a moment later: put back within the moment.
S[tName].text = "Forsaken Seeker"
Tick(.2)
equal(S[tName].text, "Zriel", "a late stale write from the client is undone within the moment")

-- Once the moment has passed, another addon's label (the privacy addon's) stays.
Tick(1)
S[tName].text = "Warrior"
local before = Sets(tName)
Tick(.2); Tick(.2); Tick(1)
equal(S[tName].text .. "|" .. (Sets(tName) - before), "Warrior|0", "after the moment another addon's label is left alone")

-- With that addon relabelling every write (it hooks SetText), it still wins
-- after a change: EraUI writes the real name once and the label goes straight back.
S[tName].relabel = "Warrior"
names.targettarget = "Brannoc"
Event()
equal(S[tName].text, "Warrior", "a relabelling addon keeps its label on a change")
S[tName].relabel = nil

-- A name shown with its surname fits (UnitName gives the first name only)...
names.targettarget = "Kaelis"
S[tName].text = "Kaelis Dawnbrook"
Event()
Tick(.2)
equal(S[tName].text, "Kaelis Dawnbrook", "a name with its surname is left as it is")
-- ...unless secondary names are hidden.
settings.hideSecondaryNames = true
Event()
equal(S[tName].text, "Kaelis", "secondary names hidden: the first name only")
-- The client writes the full name again long after the change (seen in game:
-- a player targeting themselves showed "Light" on the target frame but
-- "Light Jack" on its target of target): trimmed whenever it shows up.
Tick(1)
S[tName].text = "Kaelis Dawnbrook"
Tick(.2)
equal(S[tName].text, "Kaelis", "secondary names hidden: a later full name is trimmed too")
-- Another addon's label is still left alone.
S[tName].text = "Warrior"
Tick(.2)
equal(S[tName].text, "Warrior", "secondary names hidden: another addon's label stays")
settings.hideSecondaryNames = false
Tick(1)

-- No target of target, then the same one back with a stale name: fixed again.
names.targettarget = nil
Event()
names.targettarget = "Kaelis"
S[tName].text = "Forsaken Seeker"
Tick(.2)
equal(S[tName].text, "Kaelis", "back after a gap: checked again")

-- A secret name (in a fight on Forever) is never compared or written.
names.targettarget = "Hidden One"
secret["Hidden One"] = true
S[tName].text = "Forsaken Seeker"
before = Sets(tName)
Event()
equal(Sets(tName) - before, 0, "a secret name: nothing written")
secret["Hidden One"] = nil

-- The focus's target of target is kept the same way.
local focusHolder = S[ns.UnitFrameOwn(FocusFrame.totFrame, "artHolder")].scripts
names.focustarget = "Merrin"
focusHolder.OnEvent(nil, "UNIT_TARGET", "focus")
equal(S[fName].text, "Merrin", "the focus's target of target too")

equal(#writes, 0, "no key written on the game's frames (" .. table.concat(writes, ", ") .. ")")

print("Target of target name checks passed: " .. checks .. " assertions.")
