-- The Classic unit frames (Look/Unit*.lua), combo points (Look/ComboPoints.lua)
-- and status report (Look/Status.lua), clean-room 2026-10-21, on a mock of
-- Forever's player, target, focus (each with its target of target), pet and
-- party frames, the raid manager and the buff arrow. Every piece is placed
-- through its anchors, so each check reads where it really sits from its
-- frame's top left (y up). Checked against Tools/ClassicSpecs/03-unit-frames.md:
--   * each frame's 1.x geometry (sections 6 to 11), and Portrait Debuffs' badge
--     offsets from the portrait's centre (20.5);
--   * the classification art for every kind, a hidden classification keeping
--     the last, a minor mob without power or plate, the elite flag (7.4);
--   * the skull rule, secrets included (7.5); the PvP banner (5.6);
--   * the player's rest and fight icons (6.4) and name repair (6.6);
--   * Hide Aggro Highlight on each of the five glows (13); restore hiding
--     EraUI's own pieces (16.2, 17);
--   * the raid manager's tab (12) and the buff arrow (14);
--   * EraUI's own combo orbs on a client without ComboFrame (18.3, 18.4);
--   * the status text: settings changed, the 78-character wrapping, other
--     addons, blocked calls, and the chat offer once per session (19).
-- No key may be written on the game's objects, and no error reported.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack
local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local function N(v) return string.format("%g", math.floor(v * 1000 + .5) / 1000) end

-- Mock widgets ------------------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's objects shows up in writes as "Name.key". Hooks run after
-- the method, as the game's hooksecurefunc does.
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes, made = {}, {}
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear" }
local function Verb(key)
    if type(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local function Noop() end
local function New(kind, name, parent, game, layer, sub)
    local obj = {}
    S[obj] = { kind = kind, name = name, parent = parent, game = game, points = {}, scripts = {}, events = {}, hooks = {},
        scriptHooks = {}, w = 0, h = 0, alpha = 1, shown = true, level = (parent and S[parent] and S[parent].level or 0) + 1,
        layer = layer, sub = sub, mouse = true }
    made[#made + 1] = obj
    return setmetatable(obj, {
        __index = function(_, key)
            local fn = Proto[key] or (Verb(key) and Noop)
            if not fn then return nil end
            return function(self, ...)
                local r = pack(fn(self, ...))
                local st = S[self]
                for _, hook in ipairs(st and st.hooks[key] or {}) do hook(self, ...) end
                return unpack(r, 1, r.n)
            end
        end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end,
    __eq = function() error("secret compared") end, __lt = function() error("secret compared") end,
    __le = function() error("secret compared") end, __concat = function() error("secret joined") end })
issecretvalue = function(v) return rawequal(v, SECRET) end
function Proto:GetName() return S[self].name end
function Proto:GetParent() return S[self].parent end
function Proto:SetParent(p) S[self].parent = p end
function Proto:GetFrameLevel() return S[self].level end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:GetScale() return S[self].scale or 1 end
function Proto:SetScale(v) S[self].scale = v end
function Proto:IsShown() return S[self].shown end
function Proto:Show() S[self].shown = true end
function Proto:Hide() S[self].shown = false end
function Proto:SetShown(v) S[self].shown = v and true or false end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    local p = { point, rel or S[self].parent, relPoint or point, x or 0, y or 0 }
    for i, old in ipairs(S[self].points) do if old[1] == point then S[self].points[i] = p return end end
    table.insert(S[self].points, p)
end
function Proto:SetAllPoints(rel)
    rel = rel or S[self].parent
    S[self].points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end
function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i) local p = S[self].points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Proto:SetSize(w, h) S[self].w, S[self].h = w, h end
function Proto:SetWidth(w) S[self].w = w end
function Proto:SetHeight(h) S[self].h = h end
function Proto:GetSize() return S[self].w, S[self].h end
function Proto:GetWidth() return S[self].w end
function Proto:GetHeight() return S[self].h end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
function Proto:HookScript(name, fn) S[self].scriptHooks[name] = S[self].scriptHooks[name] or {}; table.insert(S[self].scriptHooks[name], fn) end
function Proto:RegisterEvent(e) S[self].events[e] = true end
function Proto:RegisterUnitEvent(e) S[self].events[e] = true end
function Proto:IsProtected() return S[self].protected == true end
function Proto:EnableMouse(on) S[self].mouse = on and true or false end
function Proto:IsMouseEnabled() return S[self].mouse end
function Proto:CreateTexture(_, layer, _, sub) return New("Texture", nil, self, false, layer or "ARTWORK", sub) end
function Proto:CreateFontString(_, layer) return New("FontString", nil, self, false, layer or "OVERLAY") end
function Proto:SetTexture(file) local s = S[self]; s.file, s.atlas, s.colour = file, nil, nil; return true end
function Proto:GetTexture() return S[self].file end
function Proto:SetColorTexture(r, g, b, a) S[self].colour = table.concat({ r, g, b, a }, ","); S[self].file = nil end
function Proto:SetTexCoord(...) local c = {}; for i, v in ipairs({ ... }) do c[i] = N(v) end; S[self].coords = table.concat(c, ",") end
function Proto:SetDrawLayer(layer, sub) S[self].layer, S[self].sub = layer, sub end
function Proto:SetBlendMode(mode) S[self].blend = mode end
function Proto:SetAtlas(atlas) S[self].atlas = atlas end
function Proto:GetAtlas() return S[self].atlas end
function Proto:RemoveMaskTexture(mask) S[self].unmasked = S[mask] and S[mask].name or "?" end
function Proto:GetRegions() return unpack(S[self].regions or {}) end
function Proto:SetText(text) S[self].text = text end
function Proto:GetText() return S[self].text end
function Proto:SetTextColor(r, g, b) S[self].textColour = { r, g, b } end
function Proto:GetTextColor() local c = S[self].textColour or { 1, 1, 1 }; return c[1], c[2], c[3] end
function Proto:SetJustifyH(j) S[self].justify = j end
function Proto:GetJustifyH() return S[self].justify end
function Proto:SetStatusBarTexture(file)
    local s = S[self]
    s.fill = s.fill or New("Texture", nil, self, s.game)
    S[s.fill].file = file
end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:SetStatusBarColor(r, g, b) S[self].barColour = table.concat({ N(r), N(g), N(b) }, ",") end
function Proto:GetStatusBarColor() return 1, 1, 1, 1 end
function Proto:SetMinMaxValues(lo, hi) S[self].range = { lo, hi } end
function Proto:SetValue(v) S[self].value = v end
-- The mouse near an object (IsMouseOver with its insets).
local mouseNear = false
function Proto:IsMouseOver(...) S[self].asked = table.concat({ ... }, ","); return mouseNear end

-- Where a region sits (left, top, right, bottom; y up), through its anchors.
local FRAC = { TOPLEFT = { 0, 0 }, TOP = { .5, 0 }, TOPRIGHT = { 1, 0 }, LEFT = { 0, .5 }, CENTER = { .5, .5 },
    RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 1 }, BOTTOM = { .5, 1 }, BOTTOMRIGHT = { 1, 1 } }
local function Rect(obj, depth)
    local s = S[obj]
    depth = (depth or 0) + 1
    assert(depth < 40, "anchor loop")
    if s.fixed then return s.fixed[1], s.fixed[2], s.fixed[1] + s.w, s.fixed[2] - s.h end
    assert(#s.points > 0, tostring(s.name or s.kind) .. " has no place")
    local w, h = s.w or 0, s.h or 0
    if s.kind == "FontString" and h == 0 then h = 12 end
    local left, right, top, bottom, cx, cy
    for _, p in ipairs(s.points) do
        local l, t, r, b = Rect(p[2], depth)
        local f, g = FRAC[p[3]], FRAC[p[1]]
        local ax, ay = l + f[1] * (r - l) + p[4], t - f[2] * (t - b) + p[5]
        if g[1] == 0 then left = ax elseif g[1] == 1 then right = ax else cx = ax end
        if g[2] == 0 then top = ay elseif g[2] == 1 then bottom = ay else cy = ay end
    end
    if not left then left = right and right - w or cx - w / 2 end
    right = right or left + w
    if not top then top = bottom and bottom + h or cy + h / 2 end
    bottom = bottom or top - h
    return left, top, right, bottom
end
local function Rel(obj, frame)
    local fl, ft = Rect(frame)
    local l, t, r, b = Rect(obj)
    return N(l - fl) .. "," .. N(t - ft) .. "," .. N(r - fl) .. "," .. N(b - ft)
end
local function Centre(obj, frame)
    local fl, ft = Rect(frame)
    local l, t, r, b = Rect(obj)
    return N((l + r) / 2 - fl) .. "," .. N((t + b) / 2 - ft)
end
local function Fire(obj, event, ...) S[obj].scripts.OnEvent(obj, event, ...) end

-- The game -----------------------------------------------------------------------------
local combat, now = false, 100
InCombatLockdown = function() return combat end
GetTime = function() return now end
CreateFrame = function(kind, name, parent)
    local f = New(kind, name, parent, false)
    if name then _G[name] = f end
    return f
end
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    if t == _G then
        local old = _G[key]
        _G[key] = function(...) local r = pack(old(...)); fn(...); return unpack(r, 1, r.n) end
    else
        local s = S[t]
        s.hooks[key] = s.hooks[key] or {}
        table.insert(s.hooks[key], fn)
    end
end
C_Timer = { After = Noop }
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 }, PRIEST = { r = 1, g = 1, b = 1 } }
GameFontNormalSmall, TextStatusBarText = { name = "GameFontNormalSmall" }, { name = "TextStatusBarText" }
local unit = {} -- what each unit answers
local function People()
    unit = {
        names = { player = "Zriel", target = "Hogger", focus = "Brannoc", targettarget = "Zriel", focustarget = "Zriel", pet = "Fang",
            party1 = "Elsa" },
        kind = {}, level = { player = 10, target = 10, focus = 10 }, attack = {}, ffa = {}, pvp = {}, faction = {},
        resting = false, busy = false, players = { player = true, party1 = true }, classes = { player = "WARRIOR", party1 = "PRIEST" },
        power = {}, most = {},
    }
end
UnitExists = function(u) return unit.names[u] ~= nil end
UnitName = function(u) return unit.names[u] end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end
UnitPower = function(u) local v = unit.power[u]; if v == nil then return 30 end; return v end
UnitPowerMax = function(u) local v = unit.most[u]; if v == nil then return 100 end; return v end
UnitPowerType = function(u) if u == "target" then return 1, "RAGE" end return 0, "MANA" end
UnitIsPlayer = function(u) return unit.players[u] or false end
UnitClass = function(u) local c = unit.classes[u]; return c, c end
UnitClassification = function(u) return unit.kind[u] end
UnitLevel = function(u) return unit.level[u] or 10 end
UnitCanAttack = function(_, u) local v = unit.attack[u]; if v == nil then return true end; return v end
UnitIsPVPFreeForAll = function(u) return unit.ffa[u] or false end
UnitIsPVP = function(u) return unit.pvp[u] or false end
UnitFactionGroup = function(u) return unit.faction[u] or "Alliance" end
UnitAffectingCombat = function() return unit.busy end
IsResting = function() return unit.resting end

local game
local function G(kind, name, parent, w, h, layer)
    local o = New(kind, name, parent, true, layer)
    if w then S[o].w, S[o].h = w, h end
    return o
end
local function Put(obj, key, value) rawset(obj, key, value); return value end
local function Fixed(obj, l, t) S[obj].fixed = { l, t } end
local function Keys(owner, prefix, kind, list)
    for _, key in ipairs(list) do Put(owner, key, G(kind, prefix .. key, owner)) end
end
local OVERLAYS = { "MyHealPredictionBar", "OtherHealPredictionBar", "HealAbsorbBar", "TotalAbsorbBar" }
local function HealthPieces(bar, prefix)
    for _, key in ipairs(OVERLAYS) do
        local piece = Put(bar, key, G("StatusBar", prefix .. key, bar))
        Put(piece, "Fill", G("Texture", prefix .. key .. "Fill", piece))
    end
    Keys(bar, prefix, "Texture", { "OverAbsorbGlow", "OverHealAbsorbGlow" })
end

local function BuildGame()
    writes, made = {}, {}
    People()
    UIParent = G("Frame", "UIParent", nil, 2000, 1000)
    Fixed(UIParent, 0, 0)
    -- The player (232 x 100 on Forever).
    PlayerFrame = G("Button", "PlayerFrame", UIParent, 232, 100)
    Fixed(PlayerFrame, 100, -100)
    local pc = Put(PlayerFrame, "PlayerFrameContainer", G("Frame", "PlayerFrameContainer", PlayerFrame))
    Keys(pc, "Player", "Texture", { "FrameTexture", "AlternatePowerFrameTexture", "FrameFlash", "PlayerPortrait" })
    Put(pc, "PlayerPortraitMask", G("MaskTexture", "PlayerPortraitMask", pc))
    local content = Put(PlayerFrame, "PlayerFrameContent", G("Frame", "PlayerFrameContent", PlayerFrame))
    local main = Put(content, "PlayerFrameContentMain", G("Frame", "PlayerFrameContentMain", content))
    local ctx = Put(content, "PlayerFrameContentContextual", G("Frame", "PlayerFrameContentContextual", content))
    local hc = Put(main, "HealthBarsContainer", G("Frame", "PlayerHealthBarsContainer", main))
    local hb = Put(hc, "HealthBar", G("StatusBar", "PlayerFrameHealthBar", hc))
    Keys(hb, "PlayerHealth", "FontString", { "TextString", "LeftText", "RightText" })
    HealthPieces(hb, "Player")
    Put(hc, "HealthBarMask", G("MaskTexture", "PlayerHealthBarMask", hc))
    local loss = Put(hc, "PlayerFrameHealthBarAnimatedLoss", G("StatusBar", "PlayerFrameHealthBarAnimatedLoss", hc))
    loss:SetStatusBarTexture("game's loss fill")
    local area = Put(main, "ManaBarArea", G("Frame", "PlayerManaBarArea", main))
    Keys(Put(area, "ManaBar", G("StatusBar", "PlayerFrameManaBar", area)), "PlayerMana", "FontString", { "TextString", "LeftText", "RightText" })
    Keys(main, "Player", "Texture", { "StatusTexture", "LevelBackgroundCircle" })
    Keys(ctx, "Player", "Texture", { "PrestigePortrait", "PrestigeBadge", "PlayerRestLoop", "AttackIcon", "PlayerPortraitCornerIcon",
        "RoleIcon", "LeaderIcon", "PVPIcon" })
    Put(ctx, "GroupIndicator", G("Frame", "PlayerFrameGroupIndicator", ctx, 60, 14))
    local circle = Put(ctx, "PlayerLevelCircle", G("Texture", "PlayerLevelCircle", ctx))
    circle:SetAtlas("UI-HUD-UnitFrame-Player-SmallCircle")
    S[ctx].regions = { circle }
    PlayerName = G("FontString", "PlayerName", main)
    PlayerLevelText = G("FontString", "PlayerLevelText", main)
    PlayerPVPTimerText = G("FontString", "PlayerPVPTimerText", ctx)
    -- Target and focus (232 x 100), each with a target of target (120 x 49).
    local function TargetLike(name, who, l, t)
        local frame = G("Button", name, UIParent, 232, 100)
        Fixed(frame, l, t)
        Put(frame, "unit", who)
        local c = Put(frame, "TargetFrameContainer", G("Frame", name .. "Container", frame))
        Keys(c, name, "Texture", { "Portrait", "FrameTexture", "Flash", "BossPortraitFrameTexture" })
        Put(c, "PortraitMask", G("MaskTexture", name .. "PortraitMask", c))
        local ct = Put(frame, "TargetFrameContent", G("Frame", name .. "Content", frame))
        local m = Put(ct, "TargetFrameContentMain", G("Frame", name .. "ContentMain", ct))
        local x = Put(ct, "TargetFrameContentContextual", G("Frame", name .. "ContentContextual", ct))
        local h = Put(m, "HealthBarsContainer", G("Frame", name .. "HealthBarsContainer", m))
        Keys(h, name .. "Health", "FontString", { "LeftText", "RightText", "DeadText", "UnconsciousText" })
        local bar = Put(h, "HealthBar", G("StatusBar", name .. "HealthBar", h))
        Keys(bar, name .. "Health", "FontString", { "TextString" })
        HealthPieces(bar, name)
        Put(h, "HealthBarMask", G("MaskTexture", name .. "HealthBarMask", h))
        Keys(Put(m, "ManaBar", G("StatusBar", name .. "ManaBar", m)), name .. "Mana", "FontString", { "TextString", "LeftText", "RightText" })
        Keys(m, name, "Texture", { "ReputationColor", "LevelBackgroundCircle" })
        Keys(m, name, "FontString", { "Name", "LevelText" })
        Keys(x, name, "Texture", { "HighLevelTexture", "LeaderIcon", "RaidTargetIcon", "QuestIcon", "PvpIcon", "BossIcon",
            "PrestigePortrait", "PrestigeBadge" })
        Put(x, "NumericalThreat", G("Frame", name .. "NumericalThreat", x, 49, 18))
        local auras = G("Frame", name .. "Auras", x, 1, 1)
        Put(frame, "GetAuraContainer", function() return auras end)
        local tot = Put(frame, "totFrame", G("Button", name .. "ToT", frame, 120, 49))
        Put(tot, "unit", who .. "target")
        Keys(tot, name .. "ToT", "StatusBar", { "HealthBar", "ManaBar" })
        Keys(tot, name .. "ToT", "Texture", { "FrameTexture", "Portrait" })
        Put(tot, "Name", G("FontString", name .. "ToTName", tot))
        return frame
    end
    TargetFrame = TargetLike("TargetFrame", "target", 500, -100)
    FocusFrame = TargetLike("FocusFrame", "focus", 500, -400)
    -- The pet.
    PetFrame = G("Button", "PetFrame", UIParent)
    Fixed(PetFrame, 100, -300)
    Put(PetFrame, "unit", "pet")
    PetPortrait = G("Texture", "PetPortrait", PetFrame, 37, 37)
    PetName = G("FontString", "PetName", PetFrame)
    PetFrameTexture, PetFrameFlash = G("Texture", "PetFrameTexture", PetFrame), G("Texture", "PetFrameFlash", PetFrame)
    PetAttackModeTexture, PetHitIndicator = G("Texture", "PetAttackModeTexture", PetFrame), G("FontString", "PetHitIndicator", PetFrame)
    for _, bar in ipairs({ "PetFrameHealthBar", "PetFrameManaBar" }) do
        _G[bar] = G("StatusBar", bar, PetFrame)
        _G[bar .. "Mask"] = G("MaskTexture", bar .. "Mask", PetFrame)
        for _, suffix in ipairs({ "Text", "TextLeft", "TextRight" }) do _G[bar .. suffix] = G("FontString", bar .. suffix, _G[bar]) end
    end
    -- A party member (120 x 53).
    local member = G("Button", "PartyMemberFrame1", UIParent, 120, 53)
    Fixed(member, 100, -500)
    S[member].level = 5
    Put(member, "unit", "party1")
    Keys(member, "Party", "Texture", { "Texture", "Portrait", "Flash" })
    S[member.Portrait].w, S[member.Portrait].h = 37, 37
    Put(member, "Name", G("FontString", "PartyName", member))
    local phc = Put(member, "HealthBarContainer", G("Frame", "PartyHealthBarContainer", member))
    Keys(phc, "PartyHealth", "FontString", { "CenterText", "LeftText", "RightText" })
    HealthPieces(Put(phc, "HealthBar", G("StatusBar", "PartyHealthBar", phc)), "Party")
    Put(phc, "HealthBarMask", G("MaskTexture", "PartyHealthBarMask", phc))
    Keys(Put(member, "ManaBar", G("StatusBar", "PartyManaBar", member)), "PartyMana", "FontString", { "CenterText", "LeftText", "RightText" })
    local overlay = Put(member, "PartyMemberOverlay", G("Frame", "PartyMemberOverlay", member))
    overlay:SetAllPoints(member)
    Keys(overlay, "Party", "Texture", { "LeaderIcon", "PVPIcon", "RoleIcon" })
    S[overlay.RoleIcon].w, S[overlay.RoleIcon].h = 12, 12
    PartyFrame = G("Frame", "PartyFrame", UIParent)
    Put(PartyFrame, "PartyMemberFramePool", { EnumerateActive = function() return pairs({ [member] = true }) end })
    -- The raid manager and its fold tab (16 x 35), and the buff arrow.
    CompactRaidFrameManager = G("Frame", "CompactRaidFrameManager", UIParent, 200, 150)
    Fixed(CompactRaidFrameManager, 0, -300)
    Put(CompactRaidFrameManager, "Background", G("Texture", "RaidManagerBackground", CompactRaidFrameManager))
    local tab = Put(CompactRaidFrameManager, "toggleButtonForward", G("Button", "RaidManagerTab", CompactRaidFrameManager, 16, 35))
    tab:SetPoint("RIGHT", CompactRaidFrameManager, "RIGHT", -7, 0)
    local faces = {}
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        faces[state] = G("Texture", "RaidTab" .. state, tab)
        Put(tab, "Get" .. state .. "Texture", function() return faces[state] end)
    end
    BuffFrame = G("Frame", "BuffFrame", UIParent)
    Put(BuffFrame, "CollapseAndExpandButton", G("Button", "BuffArrow", BuffFrame))
    game = { member = member, tab = tab, faces = faces }
end
C_Texture = { GetAtlasInfo = function(name)
    if name ~= "gm-btnforward-normal" then return nil end
    return { file = 4242, leftTexCoord = 0.5, rightTexCoord = 0.75, topTexCoord = 0, bottomTexCoord = 0.5 }
end }

-- EraUI ---------------------------------------------------------------------------------
local settings, E, ns, modules, queued
local reported = {}
geterrorhandler = function() return function(problem) reported[#reported + 1] = tostring(problem) end end
local FILES = { "Look/Base.lua", "Look/UnitKit.lua", "Look/UnitPlayer.lua", "Look/UnitTarget.lua", "Look/UnitToT.lua", "Look/UnitSmall.lua",
    "Look/UnitModule.lua", "Look/UnitExtras.lua", "Look/ComboPoints.lua", "Look/Status.lua" }
local function Session(extra, before, offAtLogin)
    settings = { enabled = true }
    for k, v in pairs(extra or {}) do settings[k] = v end
    BuildGame()
    if before then before() end
    ns, modules, queued = { db = {} }, {}, 0
    E = { Classic = ns }
    function E:GetSetting(key) return settings[key] end
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.QueueApply = function() queued = queued + 1 end
    ns.ApplyAll = Noop
    for _, file in ipairs(FILES) do assert(loadfile(file))("EraUI", E) end
    if offAtLogin then modules.unitFrames.restore() else modules.unitFrames.apply() end
end
local function UF() return E.Look.UF end
local function Driver() return UF().listener end
local function Event(event, ...) Fire(Driver(), event, ...) end
local function Tick() S[Driver()].scripts.OnUpdate(Driver(), .3) end
local function Own(frame, key) return ns.UnitFrameOwn(frame, key) end
local PATH = "Interface\\TargetingFrame\\"

-- 1. Geometry --------------------------------------------------------------------------
Session()
do
    local f = PlayerFrame
    local pc, main = f.PlayerFrameContainer, f.PlayerFrameContent.PlayerFrameContentMain
    local ctx = f.PlayerFrameContent.PlayerFrameContentContextual
    equal(Rel(pc.FrameTexture, f) .. " " .. S[pc.FrameTexture].coords .. " " .. S[pc.FrameTexture].file .. " " .. S[pc.FrameTexture].layer,
        "-19,-4,213,-104 1,0.094,0,0.781 " .. PATH .. "UI-TargetingFrame BORDER", "player: the target frame's art, mirrored")
    equal(Rel(pc.AlternatePowerFrameTexture, f) .. " " .. S[pc.AlternatePowerFrameTexture].coords, "-19,-4,213,-104 1,0.094,0,0.781",
        "player: the alternate art the same")
    equal(Rel(pc.FrameFlash, f) .. " " .. S[pc.FrameFlash].coords .. " " .. S[pc.FrameFlash].layer, "-6,-4,236,-97 0.945,0,0,0.182 BACKGROUND",
        "player: the red glow, mirrored")
    equal(Rel(main.StatusTexture, f) .. " " .. S[main.StatusTexture].blend .. " " .. tostring(S[main.StatusTexture].parent == ctx),
        "16,-12,206,-78 ADD true", "player: the status glow, additive, on the contextual frame")
    equal(Rel(pc.PlayerPortrait, f) .. " " .. Centre(pc.PlayerPortrait, f) .. " " .. Rel(pc.PlayerPortraitMask, f),
        "23,-16,87,-80 55,-48 23,-16,87,-80", "player: the 64-unit portrait and its mask")
    equal(S[pc.PlayerPortraitMask].file, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "player: the round mask")
    equal(Rel(Own(f, "barBg"), f) .. " " .. S[Own(f, "barBg")].colour .. " " .. S[Own(f, "barBg")].layer, "87,-26,206,-67 0,0,0,0.5 BACKGROUND",
        "player: the bars' black backing")
    equal(Rel(Own(f, "health"), f) .. " " .. Rel(Own(f, "power"), f), "87,-45,206,-57 87,-56,206,-68", "player: EraUI's bars")
    equal(S[Own(f, "health")].barColour .. " " .. S[Own(f, "power")].barColour, "0,1,0 0,0,1", "player: green health, mana blue")
    equal(Rel(main.HealthBarsContainer.HealthBar, f) .. " " .. N(S[main.HealthBarsContainer].alpha) .. " " .. N(S[main.ManaBarArea].alpha),
        "87,-45,206,-57 0 0", "player: the game's bar under EraUI's, its containers faded")
    local hb = main.HealthBarsContainer.HealthBar
    equal(Centre(hb.TextString, f) .. " " .. Rel(hb.LeftText, f):match("^[^,]+") .. " " .. S[hb.TextString].layer,
        "146.5,-51 93 OVERLAY", "player: the game's health texts on EraUI's bar")
    equal(tostring(S[hb.TextString].parent == Own(f, "holder")), "true", "player: on the text holder")
    equal(S[Own(f, "holder")].level, S[ctx].level + 3, "player: the text holder over the contextual frame")
    equal(S[Own(f, "host")].level .. " " .. S[pc].level .. " " .. S[ctx].level, (S[f].level + 1) .. " " .. (S[f].level + 3) .. " " .. (S[f].level + 4),
        "player: host, art and contextual levels")
    local loss = main.HealthBarsContainer.PlayerFrameHealthBarAnimatedLoss
    equal(tostring(S[loss].parent == Own(f, "health")) .. " " .. Rel(loss, f) .. " " .. tostring(S[S[loss].fill].unmasked),
        "true 87,-45,206,-57 PlayerHealthBarMask", "player: the red loss bar on EraUI's, the game's health mask taken off")
    equal(S[hb.MyHealPredictionBar.Fill].unmasked .. " " .. Rel(hb.MyHealPredictionBar, f), "PlayerHealthBarMask 87,-45,206,-57",
        "player: a heal piece on EraUI's bar, unmasked")
    equal(Rel(hb.OverAbsorbGlow, f):match("^[^,]+") .. " " .. Rel(hb.OverHealAbsorbGlow, f):match("^[^,]+"), "199 94",
        "player: the absorb glows at the bar's ends, 7 in")
    equal(Rel(PlayerName, f) .. " " .. S[PlayerName].justify .. " " .. tostring(S[PlayerName].parent == ctx), "97,-30,197,-42 CENTER true",
        "player: the name centred on its strip")
    equal(Centre(PlayerLevelText, f) .. " " .. table.concat(S[PlayerLevelText].textColour, ","), "36,-71 1,0.82,0", "player: the gold level on its badge")
    local rest, fight = Own(ctx, "rest"), Own(ctx, "fight")
    equal(Rel(rest, f) .. " " .. S[rest].coords .. " " .. Rel(fight, f) .. " " .. S[fight].coords,
        "20,-54,51,-85 0,0.5,0,0.422 21,-53,53,-84 0.5,1,0,0.484", "player: the rest and fight icons")
    equal(Rel(ctx.LeaderIcon, f) .. " " .. Rel(ctx.GroupIndicator, f), "21,-16,37,-32 97,-6,157,-20", "player: the leader crown and group number")
    equal(Rel(Own(f, "banner"), f), "-1,-22,63,-86", "player: the PvP banner's spot")
    for _, key in ipairs({ "PrestigePortrait", "PrestigeBadge", "PlayerRestLoop", "AttackIcon", "PlayerPortraitCornerIcon", "PlayerLevelCircle" }) do
        equal(N(S[ctx[key]].alpha), "0", "player: " .. key .. " faded")
    end
    equal(N(S[main.LevelBackgroundCircle].alpha), "0", "player: the level circle faded")
    -- Portrait Debuffs' masks assume the badge 23 below and 19 left of the portrait's centre.
    local pcx, pcy = Centre(pc.PlayerPortrait, f):match("^(.-),(.*)$")
    local lcx, lcy = Centre(PlayerLevelText, f):match("^(.-),(.*)$")
    equal(N(lcx - pcx) .. "," .. N(lcy - pcy), "-19,-23", "player: the badge where Portrait Debuffs expects it")
end
do
    local f = TargetFrame
    local c, main, ctx = f.TargetFrameContainer, f.TargetFrameContent.TargetFrameContentMain, f.TargetFrameContent.TargetFrameContentContextual
    equal(Rel(c.FrameTexture, f) .. " " .. S[c.FrameTexture].coords .. " " .. S[c.FrameTexture].file,
        "20,-4,252,-104 0.094,1,0,0.781 " .. PATH .. "UI-TargetingFrame", "target: the 1.x art")
    equal(Rel(c.Portrait, f) .. " " .. Centre(c.Portrait, f), "146,-16,210,-80 178,-48", "target: the portrait on the right")
    equal(Rel(Own(f, "barBg"), f) .. " " .. Rel(Own(f, "health"), f) .. " " .. Rel(Own(f, "power"), f), "27,-45,146,-70 27,-45,146,-57 27,-56,146,-68",
        "target: backing and bars on the left")
    equal(S[Own(f, "power")].barColour, "1,0,0", "target: rage red")
    equal(Rel(main.ReputationColor, f) .. " " .. S[main.ReputationColor].file, "27,-26,146,-45 " .. PATH .. "UI-TargetingFrame-LevelBackground",
        "target: the reaction plate")
    equal(Rel(main.Name, f), "36,-30,136,-42", "target: the name")
    equal(Centre(main.LevelText, f) .. " " .. Rel(ctx.HighLevelTexture, f), "198,-71 189,-63,205,-79", "target: level and skull on the badge")
    local pcx, pcy = Centre(c.Portrait, f):match("^(.-),(.*)$")
    local lcx, lcy = Centre(main.LevelText, f):match("^(.-),(.*)$")
    equal(N(lcx - pcx) .. "," .. N(lcy - pcy), "20,-23", "target: the badge where Portrait Debuffs expects it")
    equal(Rel(ctx.LeaderIcon, f) .. " " .. Centre(ctx.RaidTargetIcon, f) .. " " .. Rel(ctx.QuestIcon, f),
        "192,-14,208,-30 180,-18 132,-16,164,-48", "target: leader, raid marker and quest badge")
    equal(Rel(ctx.NumericalThreat, f) .. " " .. Rel(Own(f, "banner"), f), "61.5,-8,110.5,-26 193,-22,257,-86", "target: threat number and banner")
    equal(Rel(f:GetAuraContainer(), f), "25,-72,26,-73", "target: the aura row under the art")
    -- In place: left alone (its anchors never cleared); moved by the game:
    -- put back, in a fight too unless the game guards it, then after it.
    local auras = f:GetAuraContainer()
    local anchors = S[auras].points
    Tick()
    equal(S[auras].points == anchors, true, "the aura row in place: not touched")
    auras:ClearAllPoints(); auras:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    combat = true
    Tick()
    equal(Rel(auras, f), "25,-72,26,-73", "moved by the game in a fight: put back at once")
    S[auras].protected = true
    auras:ClearAllPoints(); auras:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    Tick()
    equal(Rel(auras, f), "0,-100,1,-101", "guarded in a fight: left where the game put it")
    combat = false
    local before = queued
    Event("PLAYER_REGEN_ENABLED")
    equal(Rel(auras, f) .. " " .. (queued - before), "25,-72,26,-73 1", "after the fight: put back, a pass booked")
    S[auras].protected = nil
    -- The frame art (the aura row hangs on it) is re-dressed on every keeper
    -- pass, fights included: in place, its anchor is left alone.
    local artPoints = S[c.FrameTexture].points
    combat = true
    Tick()
    combat = false
    equal(S[c.FrameTexture].points == artPoints, true, "the frame art in place: not re-anchored by a keeper pass")
    c.FrameTexture:ClearAllPoints(); c.FrameTexture:SetPoint("CENTER", f, "CENTER", 0, 0)
    Tick()
    equal(Rel(c.FrameTexture, f), "20,-4,252,-104", "moved by the game: put back on the next keeper pass")
    equal(N(S[main.HealthBarsContainer.HealthBar].alpha) .. N(S[main.ManaBar].alpha), "00", "target: the game's bars faded")
    local tot = f.totFrame
    equal(Rel(tot, f), "124,-69,244,-118", "target of target: below and right of its owner")
    equal(Rel(Own(tot, "totArt"), tot) .. " " .. S[Own(tot, "totArt")].coords .. " " .. S[Own(tot, "totArt")].file,
        "0,0,93,-45 0.016,0.727,0,0.703 " .. PATH .. "UI-TargetofTargetFrame", "target of target: its art")
    equal(Rel(tot.Portrait, tot) .. " " .. Rel(tot.Name, tot) .. " " .. S[tot.Name].justify, "5,-5,40,-40 42,-30,142,-42 LEFT",
        "target of target: portrait, and the name starting at the bars")
    equal(Rel(Own(tot, "barBg"), tot) .. " " .. Rel(Own(tot, "totHealth"), tot) .. " " .. Rel(Own(tot, "totPower"), tot),
        "45,-15,91,-30 45,-15,91,-22 45,-23,91,-30", "target of target: backing and bars")
    equal(S[Own(tot, "artHolder")].level > math.max(S[Own(tot, "totHealth")].level, S[Own(tot, "totPower")].level), true,
        "target of target: the art over its bars")
end
do
    local f = PetFrame
    equal(S[f].w .. "x" .. S[f].h, "128x53", "pet: the small frame")
    equal(Rel(PetPortrait, f) .. " " .. Rel(PetName, f) .. " " .. Rel(PetFrameTexture, f), "7,-6,44,-43 53,-8,53,-20 0,-2,128,-66",
        "pet: portrait, name, art")
    equal(Rel(PetFrameFlash, f) .. " " .. S[PetFrameFlash].coords, "-4,11,124,-53 0,1,1,0", "pet: its glow, upside down")
    equal(Rel(PetFrameHealthBar, f) .. " " .. Rel(PetFrameManaBar, f) .. " " .. N(S[PetFrameHealthBarMask].alpha),
        "47,-22,116,-30 47,-29,116,-37 0", "pet: its own bars restyled, their masks faded")
    equal(S[PetFrameHealthBar].barColour .. " " .. S[PetFrameManaBar].barColour, "0,1,0 0,0,1", "pet: green and mana blue")
    equal(Rel(PetAttackModeTexture, f) .. " " .. Centre(PetHitIndicator, f), "6,-9,82,-73 28,-27", "pet: attack glow and hit numbers")
    local m = game.member
    equal(Rel(m.Texture, m) .. " " .. S[m.Texture].layer .. S[m.Texture].sub .. " " .. Rel(m.Portrait, m) .. " " .. Rel(m.Name, m),
        "0,-10,128,-74 ARTWORK7 7,-14,44,-51 49,-7,49,-19", "party: art, portrait, name")
    equal(Rel(m.Flash, m) .. " " .. Rel(Own(m, "barBg"), m) .. " " .. S[Own(m, "barBg")].sub, "-3,-6,125,-70 45,-19,117,-39 -7", "party: glow and backing")
    equal(Rel(Own(m, "health"), m) .. " " .. Rel(Own(m, "power"), m), "45,-19,115,-29 41,-30,115,-37", "party: EraUI's bars")
    local o = m.PartyMemberOverlay
    equal(Rel(o.LeaderIcon, m) .. " " .. Rel(o.PVPIcon, m):match("^[^,]+,[^,]+") .. " " .. Rel(o.RoleIcon, m),
        "0,-8,16,-24 -9,-23 7,-41,19,-53", "party: leader, PvP and role icons")
    equal(S[Own(m, "host")].level, S[m].level - 1, "party: the host one level under the frame")
    equal(S[m.HealthBarContainer.CenterText].parent == Own(m, "holder") and S[Own(m, "holder")].level == S[m].level + 3, true,
        "party: its texts on the holder above it")
end
equal(table.concat(writes, ","), "", "no key written on the game's frames")

-- 2. Classification, skull, PvP ---------------------------------------------------------
do
    local f, c = TargetFrame, TargetFrame.TargetFrameContainer
    local main = f.TargetFrameContent.TargetFrameContentMain
    local function Kind(kind)
        unit.kind.target = kind
        Event("UNIT_CLASSIFICATION_CHANGED", "target")
        return S[c.FrameTexture].file:sub(#PATH + 1) .. " " .. S[c.Flash].file:sub(#PATH + 1) .. " " .. S[c.Flash].coords .. " "
            .. Rel(c.Flash, f) .. " " .. tostring(Own(f, "haveElite")) .. " " .. N(S[Own(f, "power")].alpha) .. " "
            .. S[Own(f, "barBg")].h .. " " .. tostring(S[main.ReputationColor].shown)
    end
    local TALL = "UI-TargetingFrame-Flash 0,0.945,0.182,0.4 -2,5,240,-107 true 1 25 true"
    equal(Kind("elite"), "UI-TargetingFrame-Elite " .. TALL, "an elite: the dragon")
    equal(Kind("worldboss"), "UI-TargetingFrame-Elite " .. TALL, "a world boss: the dragon")
    equal(Kind("rareelite"), "UI-TargetingFrame-Rare-Elite " .. TALL, "a rare elite: the silver dragon")
    equal(Kind("rare"), "UI-TargetingFrame-Rare UI-TargetingFrame-Flash 0,0.945,0,0.182 -4,-4,238,-97 true 1 25 true", "a rare")
    equal(Kind("minus"), "UI-TargetingFrame-Minus UI-TargetingFrame-Minus-Flash 0,1,0,1 -4,-4,252,-132 nil 0 12 false",
        "a minor mob: small art, no power, no plate")
    equal(Kind("normal"), "UI-TargetingFrame UI-TargetingFrame-Flash 0,0.945,0,0.182 -4,-4,238,-97 nil 1 25 true", "a normal mob")
    equal(Kind("trivial"), Kind("normal"), "anything else: the normal art")
    Kind("elite")
    equal(Kind(SECRET):sub(1, 23), "UI-TargetingFrame-Elite", "a hidden classification keeps the last (no drop to normal mid-fight)")
    equal(Kind(nil):sub(1, 23), "UI-TargetingFrame-Elite", "none while the unit exists: the last")
    unit.names.target = nil
    equal(Kind(nil):sub(1, 18) .. " " .. tostring(Own(f, "haveElite")), "UI-TargetingFrame  nil", "none and no unit: normal")
    unit.names.target = "Hogger"
    equal(Own(FocusFrame, "lastClassification"), "normal", "the focus keeps its own")

    local ctx = f.TargetFrameContent.TargetFrameContentContextual
    local function Skull(level, attack, mine)
        unit.level.target, unit.attack.target, unit.level.player = level, attack, mine or 10
        Event("UNIT_LEVEL", "target")
        return tostring(S[ctx.HighLevelTexture].shown) .. " " .. tostring(S[main.LevelText].shown)
    end
    equal(Skull(21), "true false", "more than ten above you: the skull instead of the level")
    equal(Skull(20), "false true", "ten above: the level")
    equal(Skull(-1), "true false", "a boss: the skull")
    equal(Skull(30, false), "false true", "a friend (can't be attacked): never a skull")
    equal(Skull(30, SECRET), "true false", "a hidden 'can attack': the rule goes on")
    equal(Skull(SECRET), "false true", "a hidden level: no skull")
    equal(Skull(nil), "false true", "no level: no skull")
    equal(Skull(30, true, SECRET), "false true", "your own level hidden: no skull")
    -- The boss rule comes before the others (spec 7.5's order).
    equal(Skull(-1, false), "true false", "a boss level on a friend: still the skull")
    equal(Skull(-1, true, SECRET), "true false", "a boss level with your own level hidden: still the skull")
    Skull(10)

    local banner, icon = Own(f, "banner"), ctx.PvpIcon
    local function PvP(ffa, flagged, side)
        unit.ffa.target, unit.pvp.target, unit.faction.target = ffa, flagged, side
        Event("PLAYER_PVP_FLAG_CHANGED")
        return tostring(S[banner].shown) .. " " .. tostring(S[banner].shown and S[banner].file:sub(#PATH + 1)) .. " " .. N(S[icon].alpha)
    end
    equal(PvP(true, false), "true UI-PVP-FFA 0", "free-for-all: the FFA banner, the game's icon faded")
    equal(PvP(false, true, "Horde"), "true UI-PVP-Horde 0", "flagged Horde")
    equal(PvP(false, true, "Alliance"), "true UI-PVP-Alliance 0", "flagged Alliance")
    equal(PvP(false, true, "Neutral"), "false false 0", "flagged, no known faction: no banner")
    equal(PvP(false, false), "false false 0", "not flagged: no banner, the game's faded")
    equal(PvP(SECRET, false), "false false 1", "the game won't say (a fight): the game's own icon shows")
    equal(PvP(false, SECRET), "false false 1", "a hidden flag: the same")
    PvP(false, false)
end

-- 3. The player: rest and fight icons, name repair ------------------------------------------
do
    local ctx = PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual
    local rest, fight = Own(ctx, "rest"), Own(ctx, "fight")
    local function State(resting, busy, flag, hate)
        unit.resting, unit.busy = resting, busy
        rawset(PlayerFrame, "inCombat", flag)
        rawset(PlayerFrame, "onHateList", hate)
        Tick()
        return tostring(S[rest].shown) .. " " .. tostring(S[fight].shown) .. " " .. tostring(S[PlayerLevelText].shown)
    end
    equal(State(false, false), "false false true", "neither: the level")
    equal(State(true, false), "true false false", "resting: Zzz in the level's place")
    equal(State(false, true), "false true false", "fighting: the crossed swords")
    equal(State(true, true), "false false true", "resting in a fight: neither (as 1.x)")
    equal(State(false, false, 1), "false true false", "the game's own in-combat flag counts")
    equal(State(false, false, nil, 1), "false true false", "on a hate list: the swords")
    State(true, false)
    equal(State(SECRET, false), "true false false", "a hidden answer changes nothing")
    equal(State(true, false, SECRET), "true false false", "a hidden in-combat flag on the frame changes nothing")
    State(false, false)
    equal(State(false, false, nil, SECRET), "false false true", "a hidden hate-list flag changes nothing")
    State(false, false)
    equal(S[ctx.RoleIcon].shown, false, "the modern role icon hidden")

    local function Name(text, hide)
        S[PlayerName].text = text
        settings.hideSecondaryNames = hide
        Tick()
        settings.hideSecondaryNames = nil
        return tostring(S[PlayerName].text)
    end
    equal(Name(""), "Zriel", "a blank name repaired")
    equal(Name("Unknown"), "Zriel", "'Unknown' repaired")
    equal(Name("Warrior"), "Warrior", "another addon's label left alone")
    equal(Name("Zriel Dawnbrook", true), "Zriel", "surnames hidden: the first name")
    unit.names.player = SECRET
    equal(Name("", true), "", "a hidden name: nothing written")
    unit.names.player = "Zriel"

    -- Hidden health goes straight to EraUI's bar (5.4), never compared.
    local health, most = UnitHealth, UnitHealthMax
    UnitHealth, UnitHealthMax = function() return SECRET end, function() return SECRET end
    Event("UNIT_HEALTH", "target")
    local bar = Own(TargetFrame, "health")
    equal(tostring(S[bar].value) .. " " .. tostring(S[bar].range[2]), "<secret> <secret>", "hidden health: straight to the bar")
    UnitHealth, UnitHealthMax = health, most
    Event("UNIT_HEALTH", "target")
end

-- 4. Hide Aggro Highlight on each of the five glows ---------------------------------------------
do
    local glows = { PlayerFrame.PlayerFrameContainer.FrameFlash, PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture,
        TargetFrame.TargetFrameContainer.Flash, FocusFrame.TargetFrameContainer.Flash, PetFrameFlash }
    local function Alphas() local out = {}; for i, g in ipairs(glows) do out[i] = N(S[g].alpha) end; return table.concat(out, "") end
    Session({ disableAggroHighlight = true })
    glows = { PlayerFrame.PlayerFrameContainer.FrameFlash, PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.StatusTexture,
        TargetFrame.TargetFrameContainer.Flash, FocusFrame.TargetFrameContainer.Flash, PetFrameFlash }
    equal(Alphas(), "00000", "on: every glow at 0 as it's dressed")
    for _, g in ipairs(glows) do g:SetAlpha(0.8); g:Show() end
    equal(Alphas(), "00000", "the game pulsing or showing them: back to 0 at once")
    equal(N(S[game.member.Flash].alpha), "1", "the party glow is not held")
    settings.disableAggroHighlight = false
    for _, g in ipairs(glows) do g:SetAlpha(0.8) end
    equal(Alphas(), "0.80.80.80.80.8", "option off: the game's alpha left alone")
    Session()
    glows = { PlayerFrame.PlayerFrameContainer.FrameFlash, TargetFrame.TargetFrameContainer.Flash }
    equal(Alphas(), "11", "off: the player's and target's glow at 1 when dressed")
end

-- 5. Restore hides EraUI's own pieces ---------------------------------------------------------
do
    unit.resting = true
    Tick()
    modules.unitFrames.restore()
    local ctx = PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual
    local tot, m = TargetFrame.totFrame, game.member
    local shown = {}
    for _, piece in ipairs({ Own(PlayerFrame, "host"), Own(ctx, "rest"), Own(ctx, "fight"), Own(PlayerFrame, "banner"), Own(TargetFrame, "host"),
        Own(tot, "artHolder"), Own(tot, "barHost"), Own(tot, "barBg"), Own(m, "host"), Own(m, "barBg") }) do
        shown[#shown + 1] = tostring(S[piece].shown)
    end
    equal(table.concat(shown, " "), "false false false false false false false false false false", "every piece of EraUI's own hidden")
    equal(tostring(S[PlayerLevelText].shown), "true", "the level shows again")
    local main = TargetFrame.TargetFrameContent.TargetFrameContentMain
    equal(N(S[main.HealthBarsContainer.HealthBar].alpha) .. N(S[main.ManaBar].alpha) .. N(S[tot.FrameTexture].alpha)
        .. N(S[m.HealthBarContainer].alpha), "1111", "the game's bars and art back to alpha 1")
    equal(ns.needsReload, true, "a reload clears the rest")
    unit.resting = false
    -- A per-frame key off: that frame only.
    Session()
    ns.db.unitFrameTarget = false
    modules.unitFrames.apply()
    equal(tostring(S[Own(TargetFrame, "host")].shown) .. " " .. tostring(S[Own(PlayerFrame, "host")].shown), "false true",
        "Classic target frame off: only the target restored")
end

-- 6. The raid manager's tab and the buff arrow ------------------------------------------------
do
    Session()
    local manager, tab, faces = CompactRaidFrameManager, game.tab, game.faces
    local function Faces() local out = {}; for _, k in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do out[#out + 1] = N(S[faces[k]].alpha) end; return table.concat(out) end
    equal(N(S[manager.Background].alpha) .. " " .. Rel(tab, manager), "1 177,0,193,-35", "open: the background shows, the tab at the top right")
    local art = {}
    for _, obj in ipairs(made) do if S[obj].parent == tab and S[obj].kind == "Texture" and not S[obj].game then art[#art + 1] = obj end end
    equal(#art, 3, "the tab's own art: three textures")
    equal(S[art[1]].layer .. " " .. S[art[1]].coords .. " " .. S[art[1]].file, "BACKGROUND 0.75,0.5,0,0.5 4242", "the whole atlas mirrored")
    equal(S[art[2]].layer .. " " .. S[art[2]].coords .. " " .. N(S[art[2]].w), "ARTWORK 0.58,0.67,0,0.5 5.76", "its middle 36%, 36% wide")
    equal(S[art[3]].layer .. " " .. S[art[3]].colour, "HIGHLIGHT 1,1,1,0.12", "a faint white hover")
    equal(Faces(), "0000", "the button's own faces hidden")
    for _, f in pairs(faces) do S[f].alpha = 1 end
    for _, hook in ipairs(S[tab].scriptHooks.OnEnter or {}) do hook(tab) end
    equal(Faces(), "0000", "the game lights them on hover: off again")
    rawset(manager, "collapsed", true)
    Tick()
    equal(N(S[manager.Background].alpha), "0", "folded: the background hidden")
    combat = true
    rawset(manager, "collapsed", false)
    tab:ClearAllPoints(); tab:SetPoint("RIGHT", manager, "RIGHT", -7, 0)
    Tick()
    equal(N(S[manager.Background].alpha) .. " " .. Rel(tab, manager), "1 177,-57.5,193,-92.5",
        "in a fight: the background follows, the tab isn't moved (a secure manager)")
    combat = false
    Event("PLAYER_REGEN_ENABLED")
    Tick()
    equal(N(S[manager.Background].alpha) .. " " .. Rel(tab, manager), "1 177,0,193,-35", "after the fight: open, the tab back at the top right")
    modules.unitFrames.restore()
    equal(N(S[manager.Background].alpha) .. " " .. Rel(tab, manager) .. " " .. tostring(S[art[1]].shown) .. tostring(S[art[2]].shown) .. " " .. Faces(),
        "1 177,-57.5,193,-92.5 falsefalse 1111", "restore: the game's tab as it was")

    local button = BuffFrame.CollapseAndExpandButton
    mouseNear = false
    modules.hideBuffArrow.apply()
    local ticker -- the Look folder's shared ticker (Look.Every), made by the first watch
    for _, obj in ipairs(made) do if S[obj].scripts.OnUpdate and not next(S[obj].events) then ticker = obj end end
    equal(N(S[button].alpha) .. " " .. S[button].asked .. " " .. tostring(S[button].mouse), "0 6,-6,-6,6 true", "the arrow hidden (still clickable), asked with 6-unit insets")
    mouseNear = true
    S[ticker].scripts.OnUpdate(ticker, 0.06)
    equal(N(S[button].alpha), "1", "the mouse near: it shows")
    S[button].mouse = false
    mouseNear = false
    S[ticker].scripts.OnUpdate(ticker, 0.06)
    equal(N(S[button].alpha) .. " " .. tostring(S[button].mouse), "0 true", "the mouse away: hidden again, kept clickable")
    modules.hideBuffArrow.restore()
    S[ticker].scripts.OnUpdate(ticker, 0.06)
    equal(N(S[button].alpha) .. " " .. tostring(S[button].mouse), "1 true", "restore: always shown")

    -- The look off since login: restore runs on every pass and leaves the
    -- raid manager (a secure frame EraUI never dressed) to the game.
    Session(nil, nil, true)
    local fresh, freshTab = CompactRaidFrameManager, game.tab
    S[fresh.Background].alpha = 0.5
    freshTab:ClearAllPoints(); freshTab:SetPoint("LEFT", fresh, "LEFT", 3, 0)
    modules.unitFrames.restore()
    equal(N(S[fresh.Background].alpha) .. " " .. Rel(freshTab, fresh) .. " " .. N(S[game.faces.Normal].alpha),
        "0.5 3,-57.5,19,-92.5 1", "the look off since login: the raid manager left as the game has it")
end

-- 7. EraUI's own combo orbs (a client without ComboFrame) -------------------------------------
do
    local fades = {}
    UIFrameFadeIn = function(region, seconds, from, to) fades[#fades + 1] = "in " .. seconds; region:SetAlpha(to) end
    UIFrameFade = function(region, info) fades[#fades + 1] = info.mode .. " " .. info.timeToFade; region:SetAlpha(info.endAlpha) end
    Enum = { PowerType = { ComboPoints = 4 } }
    Session(nil, function() ComboFrame = nil end)
    unit.power.player, unit.most.player = 0, 5
    modules.comboPoints.apply()
    local combo = E.Look.combo
    local orbs = combo.orbs
    equal(type(orbs) == "table" and #orbs, 5, "five orbs made")
    equal(S[orbs.frame].shown, false, "no points: hidden")
    local ring = TargetFrame.TargetFrameContainer.Portrait
    local spots = {}
    for i, orb in ipairs(orbs) do spots[i] = Centre(orb.holder, ring) end
    equal(table.concat(spots, " "), "57.069,-2.124 65.074,-11.333 69.842,-22.565 70.905,-34.721 68.16,-46.61",
        "down the portrait's right side (39 from its centre, 50 to -22 degrees)")
    equal(S[orbs[1].socket].coords .. " " .. S[orbs[1].lit].coords .. " " .. S[orbs[1].shine].blend, "0,0.375,0,1 0.375,0.563,0,1 ADD", "socket, lit, shine")
    local function Lit() local out = {}; for i, orb in ipairs(orbs) do out[i] = N(S[orb.lit].alpha) end; return table.concat(out) end
    unit.power.player = 2
    fades = {}
    combo.Update()
    equal(tostring(S[orbs.frame].shown) .. " " .. Lit(), "true 11000", "two points: two lit")
    equal(table.concat(fades, ","), "in 0.3,in 0.4,IN 0.3,in 0.4,IN 0.3", "faded in, each new point with its glint")
    fades = {}
    unit.power.player = 3
    combo.Update()
    equal(Lit() .. " " .. table.concat(fades, ","), "11100 in 0.4,IN 0.3", "a third: only the new one glints")
    unit.power.player = SECRET
    fades = {}
    combo.Update()
    equal(Lit() .. " " .. #fades .. " " .. tostring(S[orbs.frame].shown), "11100 0 true", "a hidden count keeps the last known")
    unit.most.player = SECRET
    combo.Update()
    equal(tostring(S[orbs[5].holder].shown), "true", "a hidden maximum keeps the last known")
    unit.most.player, unit.power.player = 3, 1
    combo.Update()
    equal(tostring(S[orbs[4].holder].shown) .. " " .. Lit(), "false 10000", "a maximum of three: two orbs hidden, points spent unlit")
    unit.attack.target = false
    combo.Update()
    equal(tostring(S[orbs.frame].shown) .. " " .. Lit(), "false 00000", "a friendly target: hidden")
    unit.attack.target = SECRET
    unit.power.player = 2
    combo.Update()
    equal(tostring(S[orbs.frame].shown), "true", "a hidden 'can attack': shown")
    unit.names.target = nil
    combo.Update()
    equal(tostring(S[orbs.frame].shown), "false", "no target: hidden")
    unit.names.target = "Hogger"
    modules.comboPoints.restore()
    equal(tostring(S[orbs.frame].shown), "false", "restore: hidden")
    ComboFrame = nil
end

-- 8. The status report's text ---------------------------------------------------------------
do
    Session()
    -- /era's own defaults: an eraui_ copy is measured against these.
    E.settingDefaults = { cursorRing = true }
    ns.DB_DEFAULTS = { unitFrames = true, comboPoints = true, hideBuffArrow = true, barScale = 1, whoColumn = "zone", dbVersion = 1,
        textureSource = "builtin", welcomed = false, microPos = false, someTable = {} }
    ns.db = { unitFrames = false, comboPoints = true, hideBuffArrow = true, barScale = 1.5, whoColumn = "level", dbVersion = 7,
        textureSource = "bundled", welcomed = true, eraui_cursorRing = false, someTable = { 1 } }
    ns.TOGGLES = { { "unitFrames", "Classic unit frames" }, { "eraui_cursorRing", "Cursor ring" }, { "eraui_otherThing", "Other" } }
    local addons = { { "EraUI", "1.7.3" }, { "Blizzard_Professions", "1" }, { "Questie", "11.0" }, { "Details", "" }, { "Unloaded", "2" } }
    C_AddOns = {
        GetAddOnMetadata = function(name) for _, a in ipairs(addons) do if a[1] == name then return a[2] end end end,
        GetNumAddOns = function() return #addons end,
        GetAddOnInfo = function(i) return addons[i][1] end,
        IsAddOnLoaded = function(i) return addons[i][1] ~= "Unloaded" end,
    }
    GetBuildInfo = function() return "1.60.1", "70425", "Oct 1 2026", 16001 end
    GetLocale = function() return "enGB" end
    GetPhysicalScreenSize = function() return 2560, 1440 end
    C_CVar = { GetCVar = function(name) return name == "gxMaximize" and "0" or nil end }
    S[UIParent].effective = 0.71
    Proto.GetEffectiveScale = function(self) return S[self].effective or 1 end
    GetRealZoneText = function() return "Elwynn Forest" end
    date = function() return "17:52:58" end
    local text = ns.StatusText()
    local lines = {}
    for line in (text .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    equal(lines[1], "EraUI 1.7.3", "the version from the .toc")
    equal(lines[2], "Client: 1.60.1 (70425), toc 16001, enGB", "the client")
    equal(lines[3], "Display: 2560x1440 windowed, UI scale 0.71", "the display")
    equal(lines[4], "Character: WARRIOR 10, Elwynn Forest", "the character")
    equal(lines[5] .. "|" .. lines[6], "Settings changed: barScale=1.5, eraui_cursorRing=false, unitFrames=false, |    whoColumn=level",
        "changed settings, sorted; bookkeeping keys and tables left out; an option with no default off; wrapped before 78")
    equal(lines[7], "Other addons on (2): Details, Questie 11.0", "other loaded addons, not EraUI or Blizzard's, sorted, with versions")
    equal(lines[8], "Blocked by the game this session: nothing", "nothing blocked")
    -- The game blocks two of EraUI's calls (and one of another addon's).
    local watch
    for _, obj in ipairs(made) do if S[obj].events.ADDON_ACTION_BLOCKED then watch = obj end end
    combat = true
    Fire(watch, "ADDON_ACTION_BLOCKED", "EraUI", "FocusFrame:SetPointBase()")
    combat = false
    Fire(watch, "ADDON_ACTION_FORBIDDEN", "EraUI", "CastSpellByName()")
    Fire(watch, "ADDON_ACTION_BLOCKED", "Other", "Something()")
    text = ns.StatusText()
    equal(text:match("Blocked by the game this session:.*$"),
        "Blocked by the game this session:\n    17:52:58 forbidden CastSpellByName()\n    17:52:58 blocked FocusFrame:SetPointBase() (in combat)",
        "EraUI's blocked calls, newest first, in combat marked")
    for i = 1, 6 do Fire(watch, "ADDON_ACTION_BLOCKED", "EraUI", "Call" .. i .. "()") end
    local count = select(2, ns.StatusText():gsub("\n    17:52:58", ""))
    equal(count, 5, "at most five kept")
    -- Wrapping at 78: a long list breaks before the item that would run past it.
    ns.db, ns.TOGGLES = {}, {}
    ns.DB_DEFAULTS = {}
    for i = 1, 12 do
        local key = "aFairlyLongSettingName" .. string.format("%02d", i)
        ns.DB_DEFAULTS[key], ns.db[key] = false, true
    end
    lines = {}
    for line in (ns.StatusText() .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    local longest, continued = 0, 0
    for i = 5, 10 do
        if lines[i]:find("^Settings changed: ") or lines[i]:find("^    aFairly") then
            longest = math.max(longest, #lines[i])
            if lines[i]:find("^    ") then continued = continued + 1 end
        end
    end
    equal(longest <= 78 and continued >= 3, true, "the list wrapped within 78 characters, continued four spaces in (" .. longest .. ", " .. continued .. ")")
    -- 18 + 31 = 49, a second 31 would make 80: one item on the first line,
    -- then two a line (4 + 31 + 31 = 66, a third would make 97).
    equal(lines[5] .. "|" .. lines[6], "Settings changed: aFairlyLongSettingName01=true, |    aFairlyLongSettingName02=true, "
        .. "aFairlyLongSettingName03=true, ", "each line as full as 78 allows")
    equal(lines[11], "    aFairlyLongSettingName12=true", "the last item without its comma")
    -- Audit A25: a player who changed nothing reads "none". EraUI's own
    -- records, the keys copied from /era (and the minimap button it keeps
    -- off), /era copies at their defaults and copies with no default (a class
    -- reminder's) are all left out; a real /era change still shows.
    E.classicMapping = { classicBar = "actionBars", unitFrames = "unitFrames" }
    E.settingDefaults = { actionBars = true, unitFrames = true, hideEmptyActionSlots = false, cursorRing = false }
    ns.DB_DEFAULTS = { classicBar = true, unitFrames = true, emptySlots = true, namePlates = true, minimapButton = true,
        welcomeNote = true, hideLastNames = false, spellBookTopRank = false, erauiMigrated = false, erauiSettingsMenuMigrated = false,
        erauiNumericSettingsMirrored = false, erauiWelcomeSeen = false, erauiSetupComplete = false, updateNotesSeen = "",
        savedSimplifiedTypes = "", eraui_actionBars = true, eraui_unitFrames = true, eraui_hideEmptyActionSlots = false,
        eraui_cursorRing = false, eraui_reminder_HUNTER_pet = true }
    ns.db = { classicBar = true, unitFrames = true, emptySlots = false, namePlates = true, minimapButton = false, welcomeNote = false,
        hideLastNames = false, spellBookTopRank = true, erauiMigrated = true, erauiSettingsMenuMigrated = true,
        erauiNumericSettingsMirrored = true, erauiWelcomeSeen = true, erauiSetupComplete = true, updateNotesSeen = "1.7.3",
        savedSimplifiedTypes = "1", eraui_actionBars = true, eraui_unitFrames = true, eraui_hideEmptyActionSlots = false,
        eraui_cursorRing = false, eraui_reminder_HUNTER_pet = false, eraui_showAllSpellRanks = false }
    ns.TOGGLES = { { "classicBar", "Classic main menu bar" }, { "groupFinder", "Classic group finder" }, { "eraui_gryphons", "Gryphons" } }
    E.classicMapping.groupFinder = "groupFinderPvp"
    ns.db.groupFinder = false
    lines = {}
    for line in (ns.StatusText() .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    equal(lines[5], "Settings changed: none, all as shipped", "A25: nothing changed: none, all as shipped")
    ns.db.eraui_cursorRing, ns.db.unitFrames = true, false
    lines = {}
    for line in (ns.StatusText() .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    equal(lines[5], "Settings changed: eraui_cursorRing=true", "A25: an /era choice shows once, as its eraui_ line (not the Classic copy of it)")
    E.classicMapping, E.settingDefaults = nil, nil
    -- The window and the chat offer.
    ns.StatusText = function() return "replaced" end
    ns.ShowStatus()
    equal(type(EraUIClassicStatus) == "table" and S[EraUIClassicStatus].shown, true, "the window, by its global name, built on first open")
    local said = {}
    ns.Print = function(line) said[#said + 1] = line end
    ns.ChatLink = function(target, label) return "[" .. label .. "|" .. target .. "]" end
    ns.OfferStatus()
    ns.OfferStatus()
    equal(#said .. " " .. said[1], "1 the game blocked something this addon tried to do. If anything looks broken, [open the status report|status] "
        .. "and send it with a note of what you were doing.", "the chat offer, once per session, with its link")
    Proto.GetEffectiveScale = nil
end

equal(table.concat(writes, ","), "", "no key written on the game's frames")
equal(table.concat(reported, " | "), "", "no error reported along the way")
print("Unit frame look checks passed: " .. checks .. " assertions.")
