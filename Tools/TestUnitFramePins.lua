-- Build 70425 on the unit frames (Classic/UnitFrames.lua, with
-- Classic/Textures.lua and Classic/Skin.lua) against a mock of Forever's
-- player, target, focus and party frames, every piece placed through its
-- anchors:
-- * The game's faded health bar, which the incoming heal and absorb pieces
--   are drawn from, stays pinned to EraUI's bar. The game now puts it back in
--   its own spot on every target or focus change and classification change
--   (Camelot TargetFrameMixin:UpdateHealthBarVisuals) and on the player's
--   form or vehicle art (PlayerFrame_UpdateHealthBarVisuals); the keepers
--   pin it back at that event or the next 0.25 s check, in a fight too while
--   the bar isn't protected, and a protected one at the fight's end. A bar
--   already in place is left alone; secret anchors are never compared.
-- * The party role icon: Forever's party art (ToPlayerArt,
--   ToCharacterStyleArt, ToVehicleArt) now adds its own TOPRIGHT point
--   without clearing EraUI's, which stretched the icon across the frame; the
--   party keeper puts it back, in a fight too.
-- With the unit frames off neither is touched. No key on the game's frames.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack
local function N(v) return string.format("%g", math.floor(v * 1000 + .5) / 1000) end

-- Mock widgets ------------------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's objects shows up in writes as "Name.key"; while logging,
-- every call made on one of them is listed as "Name:Method".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes, calls, logging = {}, {}, false
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear" }
local function Verb(key)
    if type(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local function Noop() end
local eraFrames = {}
local function New(kind, name, parent, game)
    local obj = {}
    S[obj] = { kind = kind, name = name, parent = parent, game = game, points = {}, scripts = {}, events = {}, level = 1,
        shown = true, alpha = 1, w = 0, h = 0 }
    if not game then eraFrames[#eraFrames + 1] = obj end
    return setmetatable(obj, {
        __index = function(_, key)
            local fn = Proto[key] or (Verb(key) and Noop)
            if not fn then return nil end
            return function(self, ...)
                local st = S[self]
                if logging and st and st.game then calls[#calls + 1] = tostring(st.name) .. ":" .. key end
                return fn(self, ...)
            end
        end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
local function Label(obj) local s = S[obj]; return s and (s.name or s.kind) or tostring(obj) end
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
-- Anchors as the game keeps them: one per point, a new one on the same
-- point replacing the old. secretPoints: GetPoint and GetNumPoints answer
-- with secrets (a fight can hide them).
local SECRET = setmetatable({}, {
    __tostring = function() return "<secret>" end,
    __eq = function() error("secret compared") end, __lt = function() error("secret compared") end,
    __le = function() error("secret compared") end, __sub = function() error("secret used in arithmetic") end,
})
issecretvalue = function(v) return rawequal(v, SECRET) end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    local p = { point, rel or S[self].parent, relPoint or point, x or 0, y or 0 }
    local points = S[self].points
    for i, old in ipairs(points) do
        if old[1] == point then points[i] = p return end
    end
    points[#points + 1] = p
end
function Proto:SetAllPoints(rel)
    rel = rel or S[self].parent
    S[self].points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end
function Proto:GetNumPoints()
    if S[self].secretPoints then return SECRET end
    return #S[self].points
end
function Proto:GetPoint(i)
    if S[self].secretPoints then return SECRET, SECRET, SECRET, SECRET, SECRET end
    local p = S[self].points[i or 1]
    if p then return p[1], p[2], p[3], p[4], p[5] end
end
function Proto:SetSize(w, h) S[self].w, S[self].h = w, h end
function Proto:SetWidth(w) S[self].w = w end
function Proto:SetHeight(h) S[self].h = h end
function Proto:GetSize() return S[self].w, S[self].h end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
function Proto:HookScript() end
function Proto:RegisterEvent(e) S[self].events[e] = true end
function Proto:RegisterUnitEvent(e) S[self].events[e] = true end
function Proto:IsProtected() return S[self].protected == true end
function Proto:CreateTexture() return New("Texture", nil, self, false) end
function Proto:CreateFontString() return New("FontString", nil, self, false) end
function Proto:SetAtlas(atlas) S[self].atlas = atlas end
function Proto:GetAtlas() return S[self].atlas end
function Proto:SetTexture(file) S[self].file, S[self].atlas = file, nil; return true end
function Proto:SetStatusBarTexture(file)
    local s = S[self]
    s.fill = s.fill or New("Texture", nil, self, s.game)
    S[s.fill].file = file
end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:SetStatusBarColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:GetStatusBarColor() local c = S[self].colour or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end

-- Where a region sits on the screen (left, top, right, bottom; y goes up),
-- worked out through its anchors as the game lays it out.
local FRAC = { TOPLEFT = { 0, 0 }, TOP = { .5, 0 }, TOPRIGHT = { 1, 0 }, LEFT = { 0, .5 }, CENTER = { .5, .5 },
    RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 1 }, BOTTOM = { .5, 1 }, BOTTOMRIGHT = { 1, 1 } }
local function Rect(obj, depth)
    local s = S[obj]
    depth = (depth or 0) + 1
    assert(depth < 40, "anchor loop at " .. Label(obj))
    if s.fixed then return s.fixed[1], s.fixed[2], s.fixed[1] + s.w, s.fixed[2] - s.h end
    assert(#s.points > 0, Label(obj) .. " has no place")
    local left, right, top, bottom, cx, cy
    for _, p in ipairs(s.points) do
        local l, t, r, b = Rect(p[2], depth)
        local f, g = FRAC[p[3]], FRAC[p[1]]
        local ax, ay = l + f[1] * (r - l) + p[4], t - f[2] * (t - b) + p[5]
        if g[1] == 0 then left = ax elseif g[1] == 1 then right = ax else cx = ax end
        if g[2] == 0 then top = ay elseif g[2] == 1 then bottom = ay else cy = ay end
    end
    if not left then left = right and right - s.w or cx - s.w / 2 end
    right = right or left + s.w
    if not top then top = bottom and bottom + s.h or cy + s.h / 2 end
    bottom = bottom or top - s.h
    return left, top, right, bottom
end
-- A region's rect from a frame's top left, as "left,top,right,bottom".
local function Rel(obj, frame)
    local fl, ft = Rect(frame)
    local l, t, r, b = Rect(obj)
    return N(l - fl) .. "," .. N(t - ft) .. "," .. N(r - fl) .. "," .. N(b - ft)
end

-- The game ----------------------------------------------------------------------------
local combat = false
InCombatLockdown = function() return combat end
CreateFrame = function(kind, name, parent)
    local f = New(kind, name, parent, false)
    if name then _G[name] = f end
    return f
end
CreateFont = function() return { SetFontObject = Noop, SetTextColor = Noop } end
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    local old = t[key]
    rawset(t, key, function(...) old(...); fn(...) end)
end
C_Timer = { After = Noop }
GetTime = function() return 100 end
UnitExists = function() return true end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 30 end
UnitPowerMax = function() return 100 end
UnitPowerType = function() return 0, "MANA" end
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

local settings = { enabled = true }
local E = { GetSetting = function(_, key) return settings[key] end }
local ns, modules, queued
local game = {}

-- The game's frames (keys set before EraUI loads, as the game's XML does),
-- each with its place, and a fresh EraUI on them.
local function Session()
    writes, calls, eraFrames = {}, {}, {}
    local function G(kind, name, parent, w, h)
        local o = New(kind, name, parent, true)
        S[o].w, S[o].h = w or 0, h or 0
        return o
    end
    local function Put(obj, key, value) rawset(obj, key, value); return value end
    local function Fixed(obj, l, t) S[obj].fixed = { l, t } end
    local function Overlays(health, who)
        for _, key in ipairs({ "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }) do
            local piece = Put(health, key, G("Frame", who .. key, health))
            Put(piece, "Fill", G("Texture", who .. key .. "Fill", piece))
        end
    end
    UIParent = G("Frame", "UIParent", nil, 2000, 1000)
    Fixed(UIParent, 0, 0)
    -- Player (Camelot PlayerFrame: 232x100; its health bar 124x20 at 87,-46).
    PlayerFrame = G("Button", "PlayerFrame", UIParent, 232, 100)
    Fixed(PlayerFrame, 100, -100)
    Put(PlayerFrame, "PlayerFrameContainer", G("Frame", "PlayerFrameContainer", PlayerFrame))
    local content = Put(PlayerFrame, "PlayerFrameContent", G("Frame", "PlayerFrameContent", PlayerFrame))
    local main = Put(content, "PlayerFrameContentMain", G("Frame", "PlayerFrameContentMain", content))
    Put(content, "PlayerFrameContentContextual", G("Frame", "PlayerFrameContentContextual", content))
    local hc = Put(main, "HealthBarsContainer", G("Frame", "PlayerHealthBarsContainer", main, 124, 15))
    Fixed(hc, 100 + 87, -100 - 46)
    local bar = Put(hc, "HealthBar", G("StatusBar", "PlayerFrameHealthBar", hc, 124, 20))
    bar:SetPoint("TOPLEFT", hc, "TOPLEFT", 0, 3)
    Overlays(bar, "player")
    Put(hc, "HealthBarMask", G("MaskTexture", "PlayerHealthBarMask", hc))
    local manaArea = Put(main, "ManaBarArea", G("Frame", "PlayerManaBarArea", main))
    Put(manaArea, "ManaBar", G("StatusBar", "PlayerFrameManaBar", manaArea))
    -- Target and focus (TargetFrameTemplate: 232x100; the health bar 126x20).
    local function TargetLike(name, unit, l, t)
        local frame = G("Button", name, UIParent, 232, 100)
        Fixed(frame, l, t)
        Put(frame, "unit", unit)
        Put(frame, "TargetFrameContainer", G("Frame", name .. "Container", frame))
        local c = Put(frame, "TargetFrameContent", G("Frame", name .. "Content", frame))
        local m = Put(c, "TargetFrameContentMain", G("Frame", name .. "ContentMain", c))
        Put(c, "TargetFrameContentContextual", G("Frame", name .. "ContentContextual", c))
        local h = Put(m, "HealthBarsContainer", G("Frame", name .. "HealthBarsContainer", m, 126, 15))
        Fixed(h, l + 21, t - 44)
        local hb = Put(h, "HealthBar", G("StatusBar", name .. "HealthBar", h, 126, 20))
        hb:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 3)
        Overlays(hb, unit)
        Put(h, "HealthBarMask", G("MaskTexture", name .. "HealthBarMask", h))
        Put(m, "ManaBar", G("StatusBar", name .. "ManaBar", m))
        return frame
    end
    TargetFrame = TargetLike("TargetFrame", "target", 500, -100)
    FocusFrame = TargetLike("FocusFrame", "focus", 500, -400)
    PetFrame = G("Button", "PetFrame", UIParent)
    Put(PetFrame, "unit", "pet")
    -- A party member (PartyMemberFrameTemplate: 120x53), its overlay over all
    -- of it and the role icon (12x12, TOPRIGHT -5,-5 in the XML).
    local member = G("Button", "PartyMemberFrame1", UIParent, 120, 53)
    Fixed(member, 100, -500)
    Put(member, "unit", "party1")
    Put(member, "Texture", G("Texture", "PartyTexture", member))
    member.Texture:SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn")
    Put(member, "Flash", G("Texture", "PartyFlash", member))
    local phc = Put(member, "HealthBarContainer", G("Frame", "PartyHealthBarContainer", member))
    Put(phc, "HealthBar", G("StatusBar", "PartyHealthBar", phc))
    Put(member, "ManaBar", G("StatusBar", "PartyManaBar", member))
    local overlay = Put(member, "PartyMemberOverlay", G("Frame", "PartyMemberOverlay", member))
    overlay:SetAllPoints(member)
    local role = Put(overlay, "RoleIcon", G("Texture", "PartyRoleIcon", overlay, 12, 12))
    role:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -5, -5)
    PartyFrame = G("Frame", "PartyFrame", UIParent)
    Put(PartyFrame, "PartyMemberFramePool", { EnumerateActive = function() return pairs({ [member] = true }) end })
    game.member, game.role, game.overlay = member, role, overlay

    ns, modules, queued = {}, {}, 0
    E.Classic = ns
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.SafeCall = function(fn, ...) local ok, err = pcall(fn, ...); assert(ok, err); return ok end
    ns.QueueApply = function() queued = queued + 1 end
    ns.ApplyAll = Noop
    ns.MissingPiece = Noop
    assert(loadfile("Classic/Textures.lua"))("EraUI", E)
    assert(loadfile("Classic/Skin.lua"))("EraUI", E)
    assert(loadfile("Classic/UnitFrames.lua"))("EraUI", E)
    modules.unitFrames.apply()
end
-- An event reaching the unit frames' driver, and its 0.25 s check.
local function Driver()
    for _, obj in ipairs(eraFrames) do
        local s = S[obj]
        if s.events.PLAYER_TARGET_CHANGED and s.events.UNIT_HEALTH and s.scripts.OnUpdate then return obj end
    end
end
local function Fire(event, ...) local d = Driver(); S[d].scripts.OnEvent(d, event, ...) end
local function Tick() local d = Driver(); S[d].scripts.OnUpdate(d, .3) end

-- The game's health bar and EraUI's, and the game's own resets of it.
local function BlizzBar(frame)
    local content = frame.PlayerFrameContent or frame.TargetFrameContent
    local main = content.PlayerFrameContentMain or content.TargetFrameContentMain
    return main.HealthBarsContainer.HealthBar
end
local function OurBar(frame) return ns.UnitFrameOwn(frame, "host").fcui.health end
-- TargetFrameMixin:UpdateHealthBarVisuals (Camelot) and
-- PlayerFrame_UpdateHealthBarVisuals (Camelot), run by the game.
local function GameResets(frame)
    local bar = BlizzBar(frame)
    local container = bar:GetParent()
    if frame == PlayerFrame then bar:SetHeight(20) end
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 3)
end
-- Whether the game's bar lies exactly on EraUI's (the heal and absorb pieces
-- then start at EraUI's fill end), else where it is from the frame's corner.
local function OnOurs(frame)
    local blizz, ours = BlizzBar(frame), OurBar(frame)
    local want, got = Rel(ours, frame), Rel(blizz, frame)
    if got == want and blizz:GetNumPoints() == 2 then return "on ours" end
    return got .. " (ours " .. want .. ")"
end
local function All() return OnOurs(PlayerFrame) .. " | " .. OnOurs(TargetFrame) .. " | " .. OnOurs(FocusFrame) end
local ON = "on ours | on ours | on ours"
-- The calls made on the game's health bars while fn runs.
local function BarCalls(fn)
    calls, logging = {}, true
    fn()
    logging = false
    local out = {}
    for _, call in ipairs(calls) do
        if call:find("HealthBar:", 1, true) and not call:find(":Get", 1, true) and not call:find(":IsProtected", 1, true) then
            out[#out + 1] = call
        end
    end
    return table.concat(out, ",")
end

-- 1. The heal and absorb pieces' bar -------------------------------------------------------
Session()
equal(All(), ON, "styled: the game's health bar on EraUI's, player, target and focus")
equal(Rel(OurBar(TargetFrame), TargetFrame) .. " " .. Rel(BlizzBar(TargetFrame), TargetFrame), "27,-45,146,-57 27,-45,146,-57",
    "target: EraUI's bar and the game's under it, 119x12")
local piece = BlizzBar(TargetFrame).MyHealPredictionBar
equal(S[piece].points[1][2] == OurBar(TargetFrame) and #S[piece].points == 2, true, "the heal pieces on EraUI's bar")
-- A new target: the game puts its bar back in its own spot first, then
-- EraUI's driver gets the event.
GameResets(TargetFrame)
equal(OnOurs(TargetFrame), "21,-41,147,-61 (ours 27,-45,146,-57)", "build 70425: the game's new target puts its bar back in its own spot")
Fire("PLAYER_TARGET_CHANGED")
equal(OnOurs(TargetFrame), "on ours", "the target keeper pins it back at the target change")
GameResets(FocusFrame)
Fire("PLAYER_FOCUS_CHANGED")
equal(OnOurs(FocusFrame), "on ours", "the focus too")
GameResets(TargetFrame)
Fire("UNIT_CLASSIFICATION_CHANGED", "target")
equal(OnOurs(TargetFrame), "on ours", "and at a classification change")
-- The player's form or vehicle art (no event of EraUI's): the 0.25 s check.
GameResets(PlayerFrame)
equal(OnOurs(PlayerFrame), "87,-43,211,-63 (ours 87,-45,206,-57)", "the player's form or vehicle art puts its bar back too")
Tick()
equal(OnOurs(PlayerFrame), "on ours", "the player's keeper pins it back at the next check")
-- Already in place: left alone, no call on it.
equal(BarCalls(function() Tick(); Fire("PLAYER_TARGET_CHANGED") end), "", "a bar already on EraUI's: nothing done to it")
-- In a fight: the game's bar isn't protected, so at once.
combat = true
GameResets(TargetFrame)
GameResets(PlayerFrame)
Fire("PLAYER_TARGET_CHANGED")
equal(All(), ON, "in a fight, the bar not protected: pinned back at once")
-- A protected bar in a fight is left alone until the fight ends.
S[BlizzBar(TargetFrame)].protected = true
GameResets(TargetFrame)
equal(BarCalls(function() Fire("PLAYER_TARGET_CHANGED"); Tick() end), "", "a protected bar in a fight: nothing done to it")
equal(OnOurs(TargetFrame), "21,-41,147,-61 (ours 27,-45,146,-57)", "left where the game put it")
combat = false
Fire("PLAYER_REGEN_ENABLED")
equal(OnOurs(TargetFrame), "on ours", "the fight's end: pinned back")
S[BlizzBar(TargetFrame)].protected = nil
-- Secret anchors: pinned again, nothing compared.
GameResets(FocusFrame)
S[BlizzBar(FocusFrame)].secretPoints = true
Fire("PLAYER_FOCUS_CHANGED")
S[BlizzBar(FocusFrame)].secretPoints = nil
equal(OnOurs(FocusFrame), "on ours", "anchors kept secret: pinned, never compared")
equal(table.concat(writes, ","), "", "no key written on the game's frames")
-- Unit frames off: the game's bars left where the game puts them.
modules.unitFrames.restore()
GameResets(TargetFrame)
GameResets(PlayerFrame)
Fire("PLAYER_TARGET_CHANGED")
Tick()
equal(OnOurs(TargetFrame) .. " | " .. OnOurs(PlayerFrame), "21,-41,147,-61 (ours 27,-45,146,-57) | 87,-43,211,-63 (ours 87,-45,206,-57)",
    "unit frames off: the game's bars left alone")

-- 2. The party role icon ---------------------------------------------------------------------
Session()
local member, role, overlay = game.member, game.role, game.overlay
local function Role() return #S[role].points .. " " .. Rel(role, member) end
-- Two points: its width (both ends set; which top wins is the game's).
local function Stretched()
    local l, _, r = Rect(role)
    return #S[role].points .. " points, " .. N(r - l) .. " wide"
end
local HOME = "1 7,-41,19,-53"
local STRETCHED = "2 points, 108 wide"
equal(Role(), HOME, "styled: the role icon at the portrait's foot, 12x12")
-- Forever's party art (ToPlayerArt, ToCharacterStyleArt) on a roster change:
-- the frame's art again, and the icon's TOPRIGHT point added to ours.
local function PlayerArt()
    member.Texture:SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn")
    role:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -5, -7)
end
-- ToVehicleArt: the frame's art hidden (its atlas untouched), the point added.
local function VehicleArt()
    member.Texture:Hide()
    role:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -5, -5)
end
PlayerArt()
equal(Stretched(), STRETCHED, "build 70425: the game's art pass stretches it across the frame")
combat = true
Fire("GROUP_ROSTER_UPDATE")
equal(Role(), HOME, "in a fight: the keeper puts it back at the roster change (was: stretched until the fight's end)")
PlayerArt()
Tick()
equal(Role(), HOME, "and at the 0.25 s check")
VehicleArt()
Tick()
equal(Role(), HOME, "a vehicle's art (the frame's art not redrawn): put back too")
member.Texture:Show()
combat = false
PlayerArt()
Fire("GROUP_ROSTER_UPDATE")
equal(Role(), HOME, "out of a fight: put back")
-- In place: left alone.
calls, logging = {}, true
Tick()
logging = false
local touched = {}
for _, call in ipairs(calls) do if call:find("PartyRoleIcon:", 1, true) and not call:find(":Get", 1, true) then touched[#touched + 1] = call end end
equal(table.concat(touched, ","), "", "an icon already in place: nothing done to it")
-- Secret anchors: put back, nothing compared.
PlayerArt()
S[role].secretPoints = true
Tick()
S[role].secretPoints = nil
equal(Role(), HOME, "anchors kept secret: put back, never compared")
equal(table.concat(writes, ","), "", "no key written on the party frame")
-- Unit frames off: the icon left as the game sets it.
modules.unitFrames.restore()
PlayerArt()
Tick()
equal(Stretched(), STRETCHED, "unit frames off: the icon left alone")

print("Unit frame pin checks passed: " .. checks .. " assertions.")
