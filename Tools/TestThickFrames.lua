-- Thick Frames (Appearance > Style > Frame Style) on the real
-- Classic/ThickFrames.lua and Classic/UnitFrames.lua, with Classic/Textures.lua,
-- Classic/Skin.lua, Core/Appearance.lua (Dark Mode's grey, the Darkness
-- slider, Darken class colours too) and Classic/CastBars.lua (where the
-- target's cast bar sits), against a mock of the game's player, target and
-- focus frames (each with its target of target, aura row and cast bar), pet
-- and a Classic party frame, keyed as Forever builds them. Every piece's place
-- is worked out through its anchors. Checked: off is today's look exactly and
-- nothing is made (the same as a game without the file); on, each frame's
-- plate, name row (nothing drawn behind the name), bar tracks, portrait ring
-- and level pill sit where the approved mockup puts them, mirrored on the
-- target and focus, the plate tiled with no gap, its round corners (8 on the
-- big frames, 6 on the small) the right way round; the game's own name,
-- level, bar texts (one number and "Dead" at the far end, both numbers each
-- the same room from its end, the power bar's a unit above its middle; a
-- dead or powerless target's power texts faded with its empty row, their
-- own alpha back after), reaction colour (a faint one-unit line, gone
-- while dead, no longer greyed by the Darkness slider) and threat number
-- moved onto them, the Classic art faded. Frame Edge: Dark (the default, and
-- anything not "class") shows no line anywhere, the pip still marks an elite
-- or a rare; Class colour draws the fine line, rounded like the plate (its
-- shape again, the near black one unit in), round the ring and the pill:
-- your class on your frame and your pet's, a player's on theirs (target,
-- focus, target of target, party), an elite's gold or a rare's silver, none
-- on other NPCs or when the game keeps who it is secret, in full colour
-- whatever the Darkness slider and Darken class colours too; switched live,
-- in a fight too; a new party member's colour at the roster change in a
-- fight; nothing shown on frames switched off. Portrait Rings and Classic
-- Party Frames; the aura row,
-- target of target and cast bar moved clear of it all; switched live both
-- ways back to today's look exactly; a switch in a fight waits for its end
-- while the keepers keep each frame's look whole; Unit Frames off; Flat Bars
-- either way; no key written on the game's frames and no new call on the
-- Edit Mode frames.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack
local pack = table.pack or function(...) return { n = select("#", ...), ... } end
local function N(v) return string.format("%g", math.floor(v * 1000 + .5) / 1000) end
local function C(r, g, b, a) return string.format("%.3f,%.3f,%.3f,%.3f", r, g, b, a or 1) end

-- Mock widgets ------------------------------------------------------------------------
-- Each object's state lives beside it (S), never on it, so a key written on
-- one of the game's objects shows up in writes as "Name.key"; while logging,
-- every call made on one of them is listed as "Name:Method".
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes, calls, logging = {}, {}, false
local all = {} -- every object made, in order
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
    local s = { kind = kind, name = name, parent = parent, game = game, points = {}, w = 0, h = 0, alpha = 1, shown = true,
        level = (parent and S[parent] and S[parent].level or 0) + 1, layer = layer, sub = sub or 0, tint = C(1, 1, 1, 1),
        coords = "0,1,0,1", scripts = {}, events = {}, hooks = {}, justify = "CENTER", kids = {} }
    -- EraUI's own objects are named by where they hang: the parent's name,
    -- then the kind and how many of that kind EraUI hung there before.
    if not name then
        local p = parent and S[parent]
        local n = 1
        if p then p.kids[kind] = (p.kids[kind] or 0) + 1; n = p.kids[kind] end
        s.label = (p and (p.name or p.label) or "?") .. "/" .. kind .. "#" .. n
    end
    S[obj] = s
    all[#all + 1] = obj
    return setmetatable(obj, {
        __index = function(_, key)
            local fn = Proto[key] or (Verb(key) and Noop)
            if not fn then return nil end
            return function(self, ...)
                local st = S[self]
                if logging and st and st.game then calls[#calls + 1] = tostring(st.name) .. ":" .. key end
                local r = pack(fn(self, ...))
                local hooks = st and st.hooks[key]
                if hooks then for _, h in ipairs(hooks) do h(self, ...) end end
                return unpack(r, 1, r.n)
            end
        end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].name or S[t].kind) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
local function Label(obj) local s = S[obj]; return s and (s.name or s.label) or tostring(obj) end
function Proto:GetName() return S[self].name end
function Proto:GetParent() return S[self].parent end
function Proto:SetParent(p) S[self].parent = p end
function Proto:IsObjectType(kind) return S[self].kind == kind end
function Proto:GetObjectType() return S[self].kind end
function Proto:GetFrameLevel() return S[self].level end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:GetScale() return S[self].scale or 1 end
function Proto:SetScale(v) S[self].scale = v end
function Proto:IsShown() return S[self].shown end
function Proto:IsVisible()
    local s = S[self]
    if not s.shown then return false end
    return s.parent == nil or s.parent:IsVisible()
end
function Proto:Show() S[self].shown = true end
function Proto:Hide() S[self].shown = false end
function Proto:SetShown(v) S[self].shown = v and true or false end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(point, rel, relPoint, x, y)
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    table.insert(S[self].points, { point, rel or S[self].parent, relPoint or point, x or 0, y or 0 })
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
function Proto:HookScript() end
function Proto:RegisterEvent(e) S[self].events[e] = true end
function Proto:RegisterUnitEvent(e) S[self].events[e] = true end
function Proto:IsProtected() return S[self].protected == true end
function Proto:IsMouseOver() return false end
function Proto:CreateTexture(_, layer, _, sub) return New("Texture", nil, self, false, layer or "ARTWORK", sub) end
function Proto:CreateFontString(_, layer) return New("FontString", nil, self, false, layer or "OVERLAY") end
function Proto:CreateMaskTexture() return New("MaskTexture", nil, self, false) end
-- Art the game can't find (a file added without restarting the game):
-- SetTexture says false, as the game's does.
local missing = {}
function Proto:SetTexture(file, wrapH, wrapV)
    local s = S[self]
    s.texture, s.colour, s.atlas, s.wrap = file, nil, nil, wrapH and (wrapH .. "," .. tostring(wrapV)) or nil
    return not missing[file]
end
-- Masks on a texture: Forever takes three and throws at a fourth.
function Proto:AddMaskTexture(mask)
    local s = S[self]
    s.masks = s.masks or {}
    if #s.masks >= 3 then error("a texture takes at most 3 masks") end
    s.masks[#s.masks + 1] = mask
end
function Proto:RemoveMaskTexture(mask)
    local list = S[self].masks or {}
    for i, m in ipairs(list) do if m == mask then table.remove(list, i) return end end
end
function Proto:GetNumMaskTextures() return #(S[self].masks or {}) end
function Proto:GetTexture() return S[self].texture end
function Proto:SetColorTexture(r, g, b, a) local s = S[self]; s.colour, s.texture, s.atlas = C(r, g, b, a), nil, nil end
function Proto:SetVertexColor(r, g, b, a) S[self].tint = C(r, g, b, a) end
function Proto:SetTexCoord(...) local c = {}; for i, v in ipairs({ ... }) do c[i] = N(v) end; S[self].coords = table.concat(c, ",") end
function Proto:SetDrawLayer(layer, sub) S[self].layer, S[self].sub = layer, sub or 0 end
function Proto:GetDrawLayer() return S[self].layer, S[self].sub end
function Proto:SetAtlas(atlas) S[self].atlas = atlas end
function Proto:GetAtlas() return S[self].atlas end
function Proto:SetRotation(r) S[self].rotation = r end
function Proto:SetStatusBarTexture(file)
    local s = S[self]
    s.fill = s.fill or New("Texture", s.name and (s.name .. "Fill") or nil, self, s.game)
    S[s.fill].texture = file
end
function Proto:GetStatusBarTexture()
    local s = S[self]
    s.fill = s.fill or New("Texture", s.name and (s.name .. "Fill") or nil, self, s.game)
    return s.fill
end
function Proto:SetStatusBarColor(r, g, b, a) S[self].barColour = C(r, g, b, a) end
function Proto:GetStatusBarColor() return 1, 1, 1, 1 end
function Proto:SetText(text) S[self].text = text end
function Proto:GetText() return S[self].text end
function Proto:SetJustifyH(j) S[self].justify = j end
function Proto:GetJustifyH() return S[self].justify end
function Proto:SetFontObject(font) S[self].font = font end
function Proto:GetStringWidth() return 20 end
function Proto:GetRegions() end
function Proto:GetChildren() end

-- Where a region sits on the screen (left, top, right, bottom; y goes up),
-- worked out through its anchors as the game lays it out. The game's frames
-- have a fixed place; everything else is placed by its points and size.
local FRAC = { TOPLEFT = { 0, 0 }, TOP = { .5, 0 }, TOPRIGHT = { 1, 0 }, LEFT = { 0, .5 }, CENTER = { .5, .5 },
    RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 1 }, BOTTOM = { .5, 1 }, BOTTOMRIGHT = { 1, 1 } }
local function Rect(obj, depth)
    local s = S[obj]
    depth = (depth or 0) + 1
    assert(depth < 40, "anchor loop at " .. Label(obj))
    if s.fixed then return s.fixed[1], s.fixed[2], s.fixed[1] + s.w, s.fixed[2] - s.h end
    assert(#s.points > 0, Label(obj) .. " has no place")
    local w, h = s.w or 0, s.h or 0
    if s.kind == "FontString" and h == 0 then h = 12 end
    local left, right, top, bottom, cx, cy
    for _, p in ipairs(s.points) do
        local l, t, r, b = Rect(p[2], depth)
        local f = assert(FRAC[p[3]], "point " .. tostring(p[3]))
        local ax, ay = l + f[1] * (r - l) + p[4], t - f[2] * (t - b) + p[5]
        local g = assert(FRAC[p[1]], "point " .. tostring(p[1]))
        if g[1] == 0 then left = ax elseif g[1] == 1 then right = ax else cx = ax end
        if g[2] == 0 then top = ay elseif g[2] == 1 then bottom = ay else cy = ay end
    end
    if not left then left = right and right - w or cx - w / 2 end
    right = right or left + w
    if not top then top = bottom and bottom + h or cy + h / 2 end
    bottom = bottom or top - h
    return left, top, right, bottom
end
-- A region's rect from a frame's top left, as "left,top,right,bottom".
local function Rel(obj, frame)
    local fl, ft = Rect(frame)
    local l, t, r, b = Rect(obj)
    return N(l - fl) .. "," .. N(t - ft) .. "," .. N(r - fl) .. "," .. N(b - ft)
end
-- The bounding rect of several regions, the same way.
local function RelAll(list, frame)
    local fl, ft = Rect(frame)
    local L, T, R, B
    for _, obj in ipairs(list) do
        local l, t, r, b = Rect(obj)
        L, T, R, B = math.min(L or l, l), math.max(T or t, t), math.max(R or r, r), math.min(B or b, b)
    end
    return N(L - fl) .. "," .. N(T - ft) .. "," .. N(R - fl) .. "," .. N(B - ft)
end
local function Centre(obj, frame)
    local fl, ft = Rect(frame)
    local l, t, r, b = Rect(obj)
    return N((l + r) / 2 - fl) .. "," .. N((t + b) / 2 - ft)
end
local function Size(obj) local l, t, r, b = Rect(obj); return N(r - l) .. "x" .. N(t - b) end

-- The game -----------------------------------------------------------------------
local combat = false
local now = 100
local secret = {}
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
secret[SECRET] = true
issecretvalue = function(v) return v ~= nil and secret[v] == true end
InCombatLockdown = function() return combat end
GetTime = function() return now end
CreateFrame = function(kind, name, parent) return New(kind, name, parent, false) end
CreateFont = function() return { SetFontObject = Noop, SetTextColor = Noop } end
CreateColor = function(r, g, b) return { GetRGB = function() return r, g, b end } end
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    local own = rawget(t, key)
    if t == _G or own then
        local old = own or _G[key]
        rawset(t, key, function(...) local r = pack(old(...)); fn(...); return unpack(r, 1, r.n) end)
    else
        local s = S[t]
        s.hooks[key] = s.hooks[key] or {}
        table.insert(s.hooks[key], fn)
    end
end
C_Timer = { After = Noop }
RAID_CLASS_COLORS = { WARRIOR = { r = .78, g = .61, b = .43 }, PRIEST = { r = 1, g = 1, b = 1 }, PALADIN = { r = .96, g = .55, b = .73 } }

-- Who is who: the player, an NPC target and focus, their targets, the pet and
-- a priest in the party.
local units, classification, players, classes, dead
local function People()
    units = { player = "Zriel", target = "Hogger", targettarget = "Zriel", focus = "Brannoc", focustarget = "Zriel", pet = "Fang", party1 = "Elsa" }
    classification = { target = "normal", focus = "normal" }
    players = { player = true, targettarget = true, focustarget = true, party1 = true }
    classes = { player = "WARRIOR", targettarget = "WARRIOR", focustarget = "WARRIOR", party1 = "PRIEST" }
    dead = {}
end
UnitIsDeadOrGhost = function(unit) return dead[unit] or false end
UnitExists = function(unit) return units[unit] ~= nil end
UnitName = function(unit) return units[unit] end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end
local powerNow = {} -- a unit's power when not 30
UnitPower = function(unit) local now = powerNow[unit]; if now == nil then return 30 end; return now end
local powerMax = {} -- a unit's power ceiling when not 100 (0: no power at all)
UnitPowerMax = function(unit) local most = powerMax[unit]; if most == nil then return 100 end; return most end
-- Forever's UnitPowerType returns nothing for a unit with no power (a beast).
local noPowerType = {}
UnitPowerType = function(unit) if noPowerType[unit] then return end; return 0, "MANA" end
UnitIsPlayer = function(unit) return players[unit] or false end
UnitClass = function(unit) local c = classes[unit]; return c, c end
UnitClassification = function(unit) return classification[unit] or "normal" end
UnitLevel = function() return 10 end
UnitCanAttack = function() return true end
UnitIsPVP = function() return false end
UnitFactionGroup = function() return "Alliance" end
UnitAffectingCombat = function() return false end
IsResting = function() return false end

-- The game's frames, keyed as Forever's templates build them (keys set before
-- EraUI loads, as the game's XML does), each with a place on the screen.
local function G(kind, name, parent, w, h, layer, sub)
    local o = New(kind, name, parent, true, layer, sub)
    if w then S[o].w, S[o].h = w, h end
    return o
end
local function Put(obj, key, value) rawset(obj, key, value); return value end
local function Fixed(obj, l, t) S[obj].fixed = { l, t } end
local game -- the game's pieces, by name
local REACTION = C(1, .1, .1, 1) -- the game's own reaction colour (hostile)

-- The game's own masks on the pet's fills, and any others on the player's
-- health-loss fill besides its HealthBarMask.
local gameMasks = { PetFrameHealthBar = 1, PetFrameManaBar = 1, PlayerFrameHealthBarAnimatedLoss = 0 }
local function Texts(bar, name, keys)
    for _, key in ipairs(keys) do Put(bar, key, G("FontString", name .. key, bar)) end
end
local function Build()
    all, writes, calls = {}, {}, {}
    People()
    for _, t in ipairs({ powerNow, powerMax, noPowerType }) do for k in pairs(t) do t[k] = nil end end
    UIParent = G("Frame", "UIParent", nil, 2000, 1000)
    Fixed(UIParent, 0, 0)
    -- Player (Camelot PlayerFrame: 232x100).
    PlayerFrame = G("Button", "PlayerFrame", UIParent, 232, 100)
    Fixed(PlayerFrame, 100, -100)
    local pc = Put(PlayerFrame, "PlayerFrameContainer", G("Frame", "PlayerFrameContainer", PlayerFrame))
    Put(pc, "FrameTexture", G("Texture", "PlayerFrameTexture", pc))
    Put(pc, "AlternatePowerFrameTexture", G("Texture", "PlayerAlternatePowerFrameTexture", pc))
    Put(pc, "FrameFlash", G("Texture", "PlayerFrameFlash", pc))
    Put(pc, "PlayerPortrait", G("Texture", "PlayerPortrait", pc, 60, 60, "BACKGROUND"))
    Put(pc, "PlayerPortraitMask", G("MaskTexture", "PlayerPortraitMask", pc, 60, 60))
    local content = Put(PlayerFrame, "PlayerFrameContent", G("Frame", "PlayerFrameContent", PlayerFrame))
    local main = Put(content, "PlayerFrameContentMain", G("Frame", "PlayerFrameContentMain", content))
    local contextual = Put(content, "PlayerFrameContentContextual", G("Frame", "PlayerFrameContentContextual", content))
    local hc = Put(main, "HealthBarsContainer", G("Frame", "PlayerHealthBarsContainer", main))
    Texts(Put(hc, "HealthBar", G("StatusBar", "PlayerFrameHealthBar", hc)), "PlayerHealth", { "TextString", "LeftText", "RightText" })
    -- The red health-loss bar (Forever's PlayerFrame.xml), its fill masked by
    -- the container's HealthBarMask at load (PlayerFrame_OnLoadBase), plus
    -- gameMasks' more for a check.
    local healthMask = Put(hc, "HealthBarMask", G("MaskTexture", "PlayerFrameHealthBarMask", hc))
    local loss = Put(hc, "PlayerFrameHealthBarAnimatedLoss", G("StatusBar", "PlayerFrameHealthBarAnimatedLoss", hc))
    loss:GetStatusBarTexture():AddMaskTexture(healthMask)
    for i = 1, gameMasks.PlayerFrameHealthBarAnimatedLoss do loss:GetStatusBarTexture():AddMaskTexture(G("MaskTexture", "PlayerLossMask" .. i, loss)) end
    local manaArea = Put(main, "ManaBarArea", G("Frame", "PlayerManaBarArea", main))
    Texts(Put(manaArea, "ManaBar", G("StatusBar", "PlayerFrameManaBar", manaArea)), "PlayerMana", { "TextString", "LeftText", "RightText" })
    Put(main, "StatusTexture", G("Texture", "PlayerStatusTexture", main))
    Put(contextual, "GroupIndicator", G("Frame", "PlayerFrameGroupIndicator", contextual, 60, 14))
    Put(contextual, "LeaderIcon", G("Texture", "PlayerLeaderIcon", contextual))
    PlayerName = G("FontString", "PlayerName", main, 96, 12)
    S[PlayerName].justify = "LEFT"
    PlayerLevelText = G("FontString", "PlayerLevelText", main)
    -- Target and focus (TargetFrameTemplate: 232x100), each with a target of
    -- target (120x49), an aura row and a cast bar (TargetSpellBarMixin's own
    -- AdjustPosition, no aura rows shown).
    local function TargetLike(name, unit, l, t)
        local frame = G("Button", name, UIParent, 232, 100)
        Fixed(frame, l, t)
        Put(frame, "unit", unit)
        local c = Put(frame, "TargetFrameContainer", G("Frame", name .. "Container", frame))
        Put(c, "Portrait", G("Texture", name .. "Portrait", c, 58, 58, "BACKGROUND"))
        Put(c, "PortraitMask", G("MaskTexture", name .. "PortraitMask", c, 58, 58))
        Put(c, "FrameTexture", G("Texture", name .. "FrameTexture", c))
        Put(c, "Flash", G("Texture", name .. "Flash", c))
        Put(c, "BossPortraitFrameTexture", G("Texture", name .. "BossPortraitFrameTexture", c))
        local ct = Put(frame, "TargetFrameContent", G("Frame", name .. "Content", frame))
        local m = Put(ct, "TargetFrameContentMain", G("Frame", name .. "ContentMain", ct))
        local x = Put(ct, "TargetFrameContentContextual", G("Frame", name .. "ContentContextual", ct))
        local h = Put(m, "HealthBarsContainer", G("Frame", name .. "HealthBarsContainer", m))
        Texts(h, name .. "Health", { "LeftText", "RightText", "DeadText", "UnconsciousText" })
        Texts(Put(h, "HealthBar", G("StatusBar", name .. "HealthBar", h)), name .. "Health", { "TextString" })
        Texts(Put(m, "ManaBar", G("StatusBar", name .. "ManaBar", m)), name .. "Mana", { "TextString", "LeftText", "RightText" })
        local reaction = Put(m, "ReputationColor", G("Texture", name .. "ReputationColor", m))
        S[reaction].tint = REACTION
        Put(m, "Name", G("FontString", name .. "Name", m, 90, 12))
        S[m.Name].justify = "LEFT"
        Put(m, "LevelText", G("FontString", name .. "LevelText", m))
        Put(x, "HighLevelTexture", G("Texture", name .. "HighLevelTexture", x))
        Put(x, "LeaderIcon", G("Texture", name .. "LeaderIcon", x))
        Put(x, "RaidTargetIcon", G("Texture", name .. "RaidTargetIcon", x))
        Put(x, "QuestIcon", G("Texture", name .. "QuestIcon", x))
        Put(x, "NumericalThreat", G("Frame", name .. "NumericalThreat", x, 49, 18))
        local auras = G("Frame", name .. "Auras", x, 1, 1)
        Put(frame, "GetAuraContainer", function() return auras end)
        local tot = Put(frame, "totFrame", G("Button", name .. "ToT", frame, 120, 49))
        Put(tot, "unit", unit .. "target")
        Put(tot, "HealthBar", G("StatusBar", name .. "ToTHealthBar", tot))
        Put(tot, "ManaBar", G("StatusBar", name .. "ToTManaBar", tot))
        Put(tot, "FrameTexture", G("Texture", name .. "ToTFrameTexture", tot, nil, nil, "BACKGROUND", 2))
        Put(tot, "Portrait", G("Texture", name .. "ToTPortrait", tot, 37, 37, "BACKGROUND", 1))
        Put(tot, "Name", G("FontString", name .. "ToTName", tot, 68, 10))
        S[tot.Name].justify = "LEFT"
        local bar = Put(frame, "spellbar", G("StatusBar", name .. "SpellBar", frame, 150, 10))
        Put(bar, "AdjustPosition", function(self)
            local parent = self:GetParent()
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 43, parent.haveToT and -46 or 5)
        end)
        return frame
    end
    TargetFrame = TargetLike("TargetFrame", "target", 500, -100)
    FocusFrame = TargetLike("FocusFrame", "focus", 500, -400)
    -- The pet (PetFrame: its portrait in the background, its own bars).
    PetFrame = G("Button", "PetFrame", PlayerFrame, 120, 49)
    Fixed(PetFrame, 100, -300)
    Put(PetFrame, "unit", "pet")
    PetPortrait = G("Texture", "PetPortrait", PetFrame, 37, 37, "BACKGROUND", 0)
    PetFrameTexture = G("Texture", "PetFrameTexture", PetFrame, nil, nil, "BORDER")
    PetFrameFlash = G("Texture", "PetFrameFlash", PetFrame)
    PetName = G("FontString", "PetName", PetFrame, 68, 10)
    S[PetName].justify = "LEFT"
    PetFrameHealthBar = G("StatusBar", "PetFrameHealthBar", PetFrame, 70, 10)
    PetFrameManaBar = G("StatusBar", "PetFrameManaBar", PetFrame, 74, 7)
    PetFrameHealthBarText, PetFrameHealthBarTextLeft = G("FontString", "PetFrameHealthBarText", PetFrameHealthBar), G("FontString", "PetFrameHealthBarTextLeft", PetFrameHealthBar)
    PetFrameHealthBarTextRight = G("FontString", "PetFrameHealthBarTextRight", PetFrameHealthBar)
    PetFrameManaBarText = G("FontString", "PetFrameManaBarText", PetFrameManaBar)
    PetFrameManaBarTextLeft = G("FontString", "PetFrameManaBarTextLeft", PetFrameManaBar)
    PetFrameManaBarTextRight = G("FontString", "PetFrameManaBarTextRight", PetFrameManaBar)
    -- Forever masks the pet's fills once, at load (Mainline PetFrame.lua:
    -- PetFrameHealthBar:GetStatusBarTexture():AddMaskTexture(PetFrameHealthBarMask)),
    -- one of the three masks a texture takes.
    for _, bar in ipairs({ PetFrameHealthBar, PetFrameManaBar }) do
        for i = 1, gameMasks[S[bar].name] do bar:GetStatusBarTexture():AddMaskTexture(G("MaskTexture", S[bar].name .. "Mask" .. i, bar)) end
    end
    PetAttackModeTexture = G("Texture", "PetAttackModeTexture", PetFrame)
    -- A Classic party frame (PartyMemberFrameTemplate: 120x53).
    local member = G("Button", "PartyMemberFrame1", UIParent, 120, 53)
    Fixed(member, 100, -500)
    S[member].level = 5
    Put(member, "unit", "party1")
    Put(member, "Texture", G("Texture", "PartyTexture", member, nil, nil, "ARTWORK"))
    Put(member, "Portrait", G("Texture", "PartyPortrait", member, 37, 37, "BACKGROUND"))
    Put(member, "Name", G("FontString", "PartyName", member, 57, 12))
    S[member.Name].justify = "LEFT"
    Put(member, "Flash", G("Texture", "PartyFlash", member))
    local phc = Put(member, "HealthBarContainer", G("Frame", "PartyHealthBarContainer", member))
    Texts(phc, "PartyHealth", { "CenterText", "LeftText", "RightText" })
    Put(phc, "HealthBar", G("StatusBar", "PartyHealthBar", phc))
    Texts(Put(member, "ManaBar", G("StatusBar", "PartyManaBar", member)), "PartyMana", { "CenterText", "LeftText", "RightText" })
    PartyFrame = G("Frame", "PartyFrame", UIParent)
    Put(PartyFrame, "PartyMemberFramePool", { EnumerateActive = function() return pairs({ [member] = true }) end })
    game = { member = member }
end

-- EraUI --------------------------------------------------------------------------
local settings, E, ns, modules, queued, booked
local function Settings(extra)
    settings = { enabled = true, unitFrames = true, castBars = true, darkModeDarkness = 58 }
    for k, v in pairs(extra or {}) do settings[k] = v end
end
-- A fresh game and EraUI on it. thick: load Classic/ThickFrames.lua (false
-- plays a game without the file).
local function Session(extra, thick)
    Settings(extra)
    Build()
    ns, modules, queued, booked = {}, {}, 0, 0
    E = { Classic = ns, modules = {} }
    function E:GetSetting(key) return settings[key] end
    function E:GetSavedSetting(key) return settings[key] end
    function E:RegisterModule(name, mod) self.modules[name] = mod end
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.SafeCall = function(fn, ...) local ok, err = pcall(fn, ...); assert(ok, err); return ok end
    ns.QueueApply = function() queued = queued + 1 end
    ns.ApplyAll = function() booked = booked + 1 end
    assert(loadfile("Classic/Textures.lua"))("EraUI", E)
    assert(loadfile("Core/Appearance.lua"))("EraUI", E)
    assert(loadfile("Classic/Skin.lua"))("EraUI", E)
    if thick ~= false then assert(loadfile("Classic/ThickFrames.lua"))("EraUI", E) end
    assert(loadfile("Classic/UnitFrames.lua"))("EraUI", E)
    assert(loadfile("Classic/CastBars.lua"))("EraUI", E)
    modules.unitFrames.apply()
    modules.castBars.apply()
end
local function Apply() modules.unitFrames.apply() end
-- An event reaching the unit frames' driver, and its 0.25 s check.
local function Driver()
    for _, obj in ipairs(all) do
        local s = S[obj]
        if not s.game and s.events.PLAYER_TARGET_CHANGED and s.scripts.OnUpdate and s.events.UNIT_HEALTH then return obj end
    end
end
local function Fire(event, ...)
    local d = Driver()
    S[d].scripts.OnEvent(d, event, ...)
end
local function Tick() local d = Driver(); S[d].scripts.OnUpdate(d, .3) end
local function Switch(key, value)
    settings[key] = value
    return ns.RefreshThickFrames()
end

-- Thick Frames' own pieces per frame (its weak table, read for the checks).
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
local function Worn(frame) return Find(ns.Thick.Worn, "worn")[frame] end
local function Plate(s) return s.plate end

-- Everything of the game's (and EraUI's own Classic pieces) as one line each:
-- place, size, alpha, whether it shows, art, colours, text and alignment.
-- skip: labels left out (pieces only one of two games has).
local function Snapshot()
    local out = {}
    for _, obj in ipairs(all) do
        local s = S[obj]
        local points = {}
        for _, p in ipairs(s.points) do points[#points + 1] = table.concat({ p[1], Label(p[2]), p[3], N(p[4]), N(p[5]) }, " ") end
        out[Label(obj)] = table.concat({ table.concat(points, ";"), N(s.w or 0) .. "x" .. N(s.h or 0), N(s.alpha), tostring(s.shown),
            tostring(s.texture), tostring(s.colour), s.tint, s.coords, tostring(s.text), s.justify, tostring(s.layer) .. tostring(s.sub),
            Label(s.parent), tostring(s.level), tostring(s.barColour), "masks " .. #(s.masks or {}) }, " | ")
    end
    return out
end
local function SameAs(want, got, label)
    local diff = {}
    for key, line in pairs(want) do
        if got[key] ~= line then diff[#diff + 1] = key .. ": " .. tostring(got[key]) .. " (want " .. line .. ")" end
    end
    table.sort(diff)
    equal(#diff == 0 and "same" or table.concat(diff, "\n"), "same", label)
end
local function Count() return #all end

local GOLD, SILVER = C(.85, .68, .29), C(.77, .79, .83)
local WARRIOR, PRIEST, PINK = C(.78, .61, .43), C(1, 1, 1), C(.96, .55, .73)
local SHELL = C(.05, .05, .06)
local SOLID, MASK = "Interface\\Buttons\\WHITE8X8", "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local function Grey(d)
    local v = 1 - d / 100
    return C(v, math.min(1, v * 44 / 42), math.min(1, v * 48 / 42))
end
-- A piece's colour: a piece of the round mask by its tint, a flat one by its own.
local function Hue(tex) local st = S[tex]; return st.texture == MASK and st.tint or st.colour end
-- The fine line on a frame: "none" when not one piece of it shows (the
-- plate's line and the near black one unit in, the pill's line, and the
-- ring's while the ring shows), else its one colour. Every piece must agree:
-- all shown or none, one colour, and the ring's line never without its ring.
local function Line(s)
    local pieces, gaps = {}, {}
    for _, tex in ipairs(s.line) do pieces[#pieces + 1] = tex end
    for _, tex in ipairs(s.pillLine or {}) do pieces[#pieces + 1] = tex end
    if S[s.ring[1]].shown then pieces[#pieces + 1] = s.ring[2]
    elseif S[s.ring[2]].shown then return "the ring's line without its ring" end
    for _, tex in ipairs(s.lineGap) do gaps[#gaps + 1] = tex end
    local seen, on, all = {}, 0, #pieces + #gaps
    for _, tex in ipairs(pieces) do if S[tex].shown then on = on + 1; seen[Hue(tex) or "no colour"] = true end end
    for _, tex in ipairs(gaps) do
        if S[tex].shown then on = on + 1 end
        if Hue(tex) ~= SHELL then return "the gap inside the line not near black" end
    end
    if on == 0 then return "none" end
    if on < all then return "partly shown (" .. on .. " of " .. all .. ")" end
    local list = {}
    for colour in pairs(seen) do list[#list + 1] = colour end
    table.sort(list)
    return table.concat(list, " / ")
end
local function Shown(list) local n = 0; for _, t in ipairs(list) do if S[t].shown then n = n + 1 end end; return n end
-- Seven pieces tiling a rounded rectangle exactly, nothing twice: four
-- corner quarters of the round mask the right way round (c square), the
-- middle at full height, the two ends between the corners. Returns its rect
-- from the frame's top left.
local function Rounded(pieces, frame, c, label)
    local fl, ft = Rect(frame)
    local L, T, R, B = Rect(pieces[5])
    local area = 0
    for _, piece in ipairs(pieces) do
        local l, t, r, b = Rect(piece)
        L, T, R, B = math.min(L, l), math.max(T, t), math.max(R, r), math.min(B, b)
        area = area + (r - l) * (t - b)
    end
    equal(N(area), N((R - L) * (T - B)), label .. ": the pieces fill it exactly")
    for i = 1, 4 do
        local l, t = Rect(pieces[i])
        local corner = (math.abs(l - L) < .01 and "0,0.5" or "0.5,1") .. "," .. (math.abs(t - T) < .01 and "0,0.5" or "0.5,1")
        equal(S[pieces[i]].coords .. " " .. tostring(S[pieces[i]].texture) .. " " .. Size(pieces[i]), corner .. " " .. MASK .. " " .. c .. "x" .. c,
            label .. ": corner " .. i .. " the right quarter, " .. c .. " round")
    end
    return L - fl, T - ft, R - fl, B - ft
end

-- 1. Off (the default): today's look exactly, nothing made ----------------------------
Session({}, false)
local without, withoutCount = Snapshot(), Count()
Session({})
SameAs(without, Snapshot(), "off: every game piece and every Classic piece of EraUI's as in a game without the file")
equal(Count(), withoutCount, "off: nothing made")
equal(ns.Thick.Worn(PlayerFrame) or ns.Thick.Worn(TargetFrame) or ns.Thick.Worn(PetFrame), false, "off: no frame wears it")
equal(table.concat(writes, ","), "", "off: no key written on the game's frames")
-- The Classic places stand: the aura row (32 up from the art's foot), the
-- target of target (-69) and the cast bar (5 from the game, 3 from EraUI).
TargetFrame.spellbar:AdjustPosition()
local p = { TargetFrame.spellbar:GetPoint(1) }
equal(p[1] .. " " .. N(p[4]) .. " " .. N(p[5]), "TOPLEFT 43 3", "off: the cast bar where EraUI always put it")
equal(Rel(TargetFrame.totFrame, TargetFrame), "124,-69,244,-118", "off: the target of target where it always was")
local classicOff = Snapshot()

-- 2. On: every frame's look, where the mockup puts it ------------------------------------
local ON = { thickFrames = true, thickFrameRings = true, thickFrameParty = true }
Session(ON)
local atLogin = Snapshot()
equal(table.concat(writes, ","), "", "on: no key written on the game's frames")
local host = function(frame) return ns.UnitFrameOwn(frame, "host") end
local function Bars(frame) local h = host(frame); return h.fcui.health, h.fcui.power end
-- Each frame's pieces in the session running now.
local ps, ts, fs, os, es, ms, member, tot, tm, auras
local function Grab()
    ps, ts, fs, es = Worn(PlayerFrame), Worn(TargetFrame), Worn(FocusFrame), Worn(PetFrame)
    member, tot = game.member, TargetFrame.totFrame
    ms, os = Worn(member), Worn(tot)
    tm, auras = TargetFrame.TargetFrameContent.TargetFrameContentMain, TargetFrame:GetAuraContainer()
end
Grab()
-- A plate is tiled by its seven pieces with no gap and nothing twice, its
-- corners quarters of the round mask the right way round, corner round (8
-- on the big frames, 6 on the small); its fine line the same shape inset in
-- from it (3 on the big frames, 2 on the small: 2 to 1 units outside the
-- bars), its corners that much less round, and the near black one unit in
-- from the line, one less again, so the line is one unit wide all the way
-- round, corners too. Every piece of the look drawn under the portrait, on
-- the frame's canvas.
local function Tiled(s, frame, label, corner, inset)
    local pl, pt, pr, pb = Rounded(s.plate, frame, corner, label .. " plate")
    local ll, lt, lr, lb = Rounded(s.line, frame, corner - inset, label .. " line")
    local gl, gt, gr, gb = Rounded(s.lineGap, frame, corner - inset - 1, label .. " line's inside")
    equal(N(ll - pl) .. "," .. N(pt - lt) .. "," .. N(pr - lr) .. "," .. N(lb - pb), table.concat({ inset, inset, inset, inset }, ","),
        label .. ": the line " .. inset .. " in from the plate all round")
    equal(N(gl - ll) .. "," .. N(lt - gt) .. "," .. N(lr - gr) .. "," .. N(gb - lb), "1,1,1,1", label .. ": the near black one unit inside the line")
    for _, tex in ipairs(s.lineGap) do equal(Hue(tex), SHELL, label .. ": inside the line near black") end
end
local function Layers(s, canvas, label, under)
    local wrong = {}
    for _, tex in ipairs(s.all) do
        local st = S[tex]
        if st.parent ~= canvas then wrong[#wrong + 1] = "parent " .. Label(st.parent) end
        if under and (st.layer ~= "BACKGROUND" or st.sub >= under) then wrong[#wrong + 1] = st.layer .. st.sub end
    end
    equal(table.concat(wrong, ","), "", label .. ": every piece on its canvas" .. (under and ", under the portrait's sublevel" or ""))
end

-- The player.
local ph, pp = Bars(PlayerFrame)
equal(RelAll(ps.plate, PlayerFrame), "57,-19,221,-77", "player: the plate from just past the portrait's middle to past the bars")
Tiled(ps, PlayerFrame, "player", 8, 3)
equal(Rel(ps.strip, PlayerFrame) .. " " .. S[ps.strip].colour, "97,-24,216,-37 " .. C(0, 0, 0, 0),
    "player: the name's row at the plate's top, nothing drawn behind the name (no lighter strip)")
equal(Rel(ph, PlayerFrame) .. " " .. Rel(pp, PlayerFrame), "97,-39,216,-60 97,-62,216,-72", "player: taller bars, health 21 and power 10, 119 wide")
equal(Rel(ps.tracks.health, PlayerFrame) .. " " .. Rel(ps.tracks.power, PlayerFrame), "97,-39,216,-60 97,-62,216,-72", "player: a track behind each bar")
equal(RelAll(ps.line, PlayerFrame) .. " " .. RelAll(ps.lineGap, PlayerFrame), "60,-22,218,-74 61,-23,217,-73",
    "player: the fine line's place, one unit, 2 to 1 outside the bars")
equal(Line(ps), "none", "player: Frame Edge's default (Dark): no line at all, every edge near black")
equal(Centre(PlayerFrame.PlayerFrameContainer.PlayerPortrait, PlayerFrame), "55,-48", "player: the portrait where EraUI puts it")
for i, size in ipairs({ "74x74", "68x68", "66x66" }) do
    equal(Centre(ps.ring[i], PlayerFrame) .. " " .. Size(ps.ring[i]) .. " " .. tostring(S[ps.ring[i]].shown), "55,-48 " .. size .. " " .. tostring(i ~= 2),
        "player: ring piece " .. i .. " round the portrait (64), dark: no line on it")
end
equal(S[ps.ring[1]].colour == nil and S[ps.ring[1]].texture, MASK, "player: the ring is the round mask")
equal(Hue(ps.ring[1]) .. " " .. Hue(ps.ring[3]), SHELL .. " " .. SHELL, "player: the ring near black")
equal(RelAll(ps.pill, PlayerFrame) .. " " .. RelAll(ps.pillLine, PlayerFrame), "42,-80,68,-96 43,-81,67,-95",
    "player: the pill under the portrait, clear of it and inside the frame (its line one in from its rim)")
equal(Shown(ps.pill) .. " " .. Shown(ps.pillLine), "6 0", "player: the pill's black rim and fill, no line (dark)")
equal(Centre(PlayerLevelText, PlayerFrame), "55,-88", "player: the level on the pill")
local rest = ns.UnitFrameOwn(PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual, "rest")
equal(Centre(rest, PlayerFrame) .. " " .. Size(rest), "55,-88 24x24", "player: the rest icon on the pill in the level's place")
equal(Rel(PlayerName, PlayerFrame) .. " " .. S[PlayerName].justify, "102,-21.5,211,-33.5 LEFT",
    "player: the name in its row, from its left, 3 above the row's middle (as the target's, clear of where its reaction line goes)")
-- Where a font string is pinned: "POINT on the bar's POINT x".
local function At(fs, bar)
    local p1 = S[fs].points[1]
    return #S[fs].points .. " " .. p1[1] .. (p1[2] == bar and "" or " (not the bar)") .. " " .. p1[3] .. " " .. N(p1[4]) .. "," .. N(p1[5])
end
local pmain = PlayerFrame.PlayerFrameContent.PlayerFrameContentMain
local phb, pmb = pmain.HealthBarsContainer.HealthBar, pmain.ManaBarArea.ManaBar
equal(At(phb.TextString, ph) .. " | " .. At(phb.LeftText, ph) .. " | " .. At(phb.RightText, ph), "1 RIGHT RIGHT -5,0 | 1 LEFT LEFT 5,0 | 1 RIGHT RIGHT -5,0",
    "player: the game's one-number text at the bar's far end; both numbers each 5 in from their end (the Classic look's 6 and 4)")
equal(At(pmb.TextString, pp) .. " | " .. At(pmb.LeftText, pp) .. " | " .. At(pmb.RightText, pp), "1 RIGHT RIGHT -5,1 | 1 LEFT LEFT 5,1 | 1 RIGHT RIGHT -5,1",
    "player: the power bar's texts the same, a unit above its middle (the game's font fills the 10-unit bar; on the middle it spilled a unit below)")
equal(N(S[PlayerFrame.PlayerFrameContainer.FrameTexture].alpha) .. N(S[PlayerFrame.PlayerFrameContainer.AlternatePowerFrameTexture].alpha), "00", "player: the Classic art faded")
equal(S[host(PlayerFrame).fcui.barBg].shown, false, "player: the Classic bars' backing hidden")
local group = PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.GroupIndicator
equal(Rel(group, PlayerFrame), "97,-3,157,-17", "player: the group number just above the plate")
equal(Shown(ps.pip), 0, "player: no pip")
Layers(ps, host(PlayerFrame), "player")
local function Sub(tex) return S[tex].layer .. S[tex].sub end
equal(table.concat({ Sub(ps.plate[1]), Sub(ps.line[1]), Sub(ps.line[5]), Sub(ps.lineGap[1]), Sub(ps.lineGap[5]), Sub(ps.tracks.health), Sub(ps.ring[1]),
    Sub(ps.ring[2]), Sub(ps.ring[3]), Sub(ps.pill[1]), Sub(ps.pillLine[1]), Sub(ps.pill[4]) }, " "),
    "BACKGROUND-8 BACKGROUND-7 BACKGROUND-7 BACKGROUND-6 BACKGROUND-6 BACKGROUND-5 BACKGROUND-4 BACKGROUND-3 BACKGROUND-2 BORDER-8 BORDER-7 BORDER-6",
    "player: plate, line, the near black inside it, tracks, the ring's three circles, then the pill's rim, line and fill over them")
local portraitLevel = S[PlayerFrame.PlayerFrameContainer].level
equal(S[host(PlayerFrame)].level < portraitLevel, true, "player: all of it under the portrait's container")

-- The target: mirrored.
local th, tp = Bars(TargetFrame)
equal(RelAll(ts.plate, TargetFrame), "12,-19,176,-77", "target: the plate mirrored, its end under the portrait")
Tiled(ts, TargetFrame, "target", 8, 3)
equal(Rel(ts.strip, TargetFrame) .. " " .. Rel(th, TargetFrame) .. " " .. Rel(tp, TargetFrame), "17,-24,136,-37 17,-39,136,-60 17,-62,136,-72",
    "target: name row and bars mirrored")
equal(RelAll(ts.line, TargetFrame) .. " " .. Line(ts), "15,-22,173,-74 none", "target: the line's place mirrored, none shown (dark)")
equal(Centre(TargetFrame.TargetFrameContainer.Portrait, TargetFrame), "178,-48", "target: the portrait where EraUI puts it")
for i, size in ipairs({ "74x74", "68x68", "66x66" }) do
    equal(Centre(ts.ring[i], TargetFrame) .. " " .. Size(ts.ring[i]), "178,-48 " .. size, "target: ring piece " .. i .. " round its portrait")
end
equal(RelAll(ts.pill, TargetFrame), "165,-80,191,-96", "target: the pill under its portrait")
equal(Centre(tm.LevelText, TargetFrame) .. " " .. Centre(TargetFrame.TargetFrameContent.TargetFrameContentContextual.HighLevelTexture, TargetFrame),
    "178,-88 178,-88", "target: the level and the skull on the pill")
equal(Rel(tm.Name, TargetFrame) .. " " .. S[tm.Name].justify, "22,-21.5,131,-33.5 LEFT", "target: the name in its row, from its left, 3 above the row's middle")
local reaction = tm.ReputationColor
equal(Rel(reaction, TargetFrame) .. " " .. S[reaction].texture .. " " .. S[reaction].tint .. " " .. tostring(S[reaction].shown) .. " " .. N(S[reaction].alpha),
    "22,-36,131,-37 " .. SOLID .. " " .. REACTION .. " true 0.7",
    "target: the game's reaction colour a faint one-unit line under the name, the name's room in from both ends, its colour the game's")
-- The line never touches a letter: the game's small font draws low in its
-- box (measured in game on "Young Wetlands Cr...", 1.24 px a unit: capitals
-- 2.5 above the box's middle, the "g" with its shadow 7 below, where it cut
-- through the line), so the name sits high enough for the tails to clear the
-- line by more than a unit and a half, and its capitals stay that far under
-- Edge's class-colour line too; the line clears the health bar as well.
local GLYPH_UP, GLYPH_DOWN = 2.5, 7
local function Clearance(name, line, frame, s)
    local _, nt, _, nb = Rect(name)
    local _, lt, _, lb = Rect(line)
    local healthBar = Bars(frame)
    local _, ht = Rect(healthBar)
    local _, edgeTop = Rect(s.line[5])
    local mid = (nt + nb) / 2
    return (mid - GLYPH_DOWN) - lt, edgeTop - 1 - (mid + GLYPH_UP), lb - ht
end
local tails, caps, bar = Clearance(tm.Name, reaction, TargetFrame, ts)
equal(tails >= 1.5 and caps >= 1.5 and bar >= 1.5, true, "target: the line clear of the name's tails (" .. N(tails) .. "), the capitals clear of the edge line ("
    .. N(caps) .. "), the line clear of the health bar (" .. N(bar) .. ")")
equal(N(Rect(reaction) - Rect(ts.strip)) .. " " .. N(select(3, Rect(ts.strip)) - select(3, Rect(reaction))), "5 5",
    "target: the line inset the name's room from both ends of the row")
-- "Dead" and "Unconscious" where the number goes (the far end, under the
-- name's start), both numbers each 5 in from their end; the power bar's too.
local hbc, tmb = tm.HealthBarsContainer, tm.ManaBar
equal(At(hbc.HealthBar.TextString, th) .. " | " .. At(hbc.DeadText, th) .. " | " .. At(hbc.UnconsciousText, th) .. " | " .. At(hbc.LeftText, th)
    .. " | " .. At(hbc.RightText, th), "1 LEFT LEFT 5,0 | 1 LEFT LEFT 5,0 | 1 LEFT LEFT 5,0 | 1 LEFT LEFT 5,0 | 1 RIGHT RIGHT -5,0",
    "target: the number, Dead and Unconscious at the bar's far end (the left, in line with the name), both numbers 5 in from each end")
equal(At(tmb.TextString, tp) .. " | " .. At(tmb.LeftText, tp) .. " | " .. At(tmb.RightText, tp), "1 LEFT LEFT 5,1 | 1 LEFT LEFT 5,1 | 1 RIGHT RIGHT -5,1",
    "target: the power bar's texts the same, a unit above its middle")
local fmb = FocusFrame.TargetFrameContent.TargetFrameContentMain.ManaBar
local _, fp = Bars(FocusFrame)
equal(At(fmb.TextString, fp) .. " | " .. At(fmb.LeftText, fp) .. " | " .. At(fmb.RightText, fp), "1 LEFT LEFT 5,1 | 1 LEFT LEFT 5,1 | 1 RIGHT RIGHT -5,1",
    "focus: its power bar's texts as the target's")
-- Dead (or a ghost): the reaction line, the empty power row and the game's
-- power texts in it (a stray 0) go, the plate ends an edge under the health
-- bar (no empty band where the row was), and all come back with it alive,
-- each text with its own alpha; an answer the game keeps secret leaves them all.
local TALL, SHORT = "12,-19,176,-77", "12,-19,176,-65"
local function PowerTexts() return N(S[tmb.TextString].alpha) .. " " .. N(S[tmb.LeftText].alpha) .. " " .. N(S[tmb.RightText].alpha) end
local function DeadLook()
    return N(S[reaction].alpha) .. " " .. tostring(S[ts.tracks.power].shown) .. " " .. PowerTexts() .. " " .. RelAll(ts.plate, TargetFrame)
end
S[tmb.RightText].alpha = .6 -- an alpha of its own, to be given back
equal(DeadLook(), "0.7 true 1 1 0.6 " .. TALL, "alive: the faint line, the power track, the power texts as they were, the plate full height")
dead.target = true
Fire("PLAYER_TARGET_CHANGED")
equal(DeadLook(), "0 false 0 0 0 " .. SHORT, "target dead: no reaction line, no power row, no stray number in it, the plate ends under the health bar")
Tiled(ts, TargetFrame, "target, short", 8, 3)
equal(RelAll(ts.line, TargetFrame), "15,-22,173,-62", "target, short: the fine line's shape follows the plate (3 in, round)")
local _, _, _, healthFoot = Rect(th)
local _, _, _, plateFoot = Rect(ts.plate[5])
equal(N(healthFoot - plateFoot), "5", "target, short: the plate's edge under the health bar as round the rest")
equal(N(S[fmb.TextString].alpha) .. " " .. RelAll(fs.plate, FocusFrame), "1 " .. TALL, "the focus, alive, keeps its power text and its full plate")
dead.target = SECRET
Tick()
equal(DeadLook(), "0.7 true 1 1 0.6 " .. TALL, "dead kept secret: the faint line, the track and the texts, the full plate, nothing compared")
dead.target = true
Tick()
equal(DeadLook(), "0 false 0 0 0 " .. SHORT, "dead again")
dead.target = nil
Tick()
equal(DeadLook(), "0.7 true 1 1 0.6 " .. TALL, "alive again: all back, each text with its own alpha")
Tiled(ts, TargetFrame, "target, full again", 8, 3)
-- Switched off while it's dead: the texts' own alpha back with the rest;
-- on again, dimmed again at the next keeper pass.
dead.target = true
Tick()
Switch("thickFrames", false)
equal(PowerTexts(), "1 1 0.6", "switched off with the target dead: the power texts' own alpha back")
Switch("thickFrames", true)
Tick()
equal(DeadLook(), "0 false 0 0 0 " .. SHORT, "on again, still dead: dimmed again")
dead.target = nil
Tick()
S[tmb.RightText].alpha = 1
-- A unit with no power at all (a beast), as probed in game on a Young
-- Wetlands Crocolisk: print(UnitPowerType, UnitPower, UnitPowerMax) gave
-- "nil 0 0". No power row, no text in it, the plate ends under the health.
noPowerType.target, powerNow.target, powerMax.target = true, 0, 0
Fire("PLAYER_TARGET_CHANGED")
equal(DeadLook(), "0.7 false 0 0 0 " .. SHORT, "a beast as probed (nil, 0, 0): no power row or texts, the plate ends under its health, the reaction line stays")
-- The same beast while Forever restricts its power (a fight): the addon's
-- UnitPower and UnitPowerMax come back secret (a chat print still shows
-- them as 0), but UnitPowerType, with no secret rule, still hands back
-- nothing. In game the row showed like this: the old check only read the
-- ceiling, and a secret ceiling keeps the row.
powerNow.target, powerMax.target = SECRET, SECRET
combat = true
Tick()
equal(DeadLook(), "0.7 false 0 0 0 " .. SHORT, "the beast in a fight, its power numbers secret: still no row, from its power type")
combat = false
-- A caster with a secret ceiling keeps its row; a plain ceiling of 0 doesn't.
noPowerType.target = nil
Tick()
equal(DeadLook(), "0.7 true 1 1 1 " .. TALL, "a caster, its power kept secret: its row and the full plate, nothing compared")
powerNow.target, powerMax.target = 0, 0
Tick()
equal(DeadLook(), "0.7 false 0 0 0 " .. SHORT, "a power ceiling of 0: no row")
powerNow.target, powerMax.target = nil, nil
Tick()
equal(DeadLook(), "0.7 true 1 1 1 " .. TALL, "power back: the row and the full plate back")
-- The game hides its own power bar (Forever's CheckClassification does for
-- a minor mob, its texts too): no row, even when the classification reads
-- as normal; shown again, the row is back.
tmb:Hide()
Tick()
equal(DeadLook(), "0.7 false 1 1 1 " .. SHORT, "the game hid its power bar: no row, the plate ends under the health")
S[tmb].shown = SECRET
Tick()
equal(DeadLook(), "0.7 true 1 1 1 " .. TALL, "whether it shows kept secret: the row, nothing compared")
tmb:Show()
Tick()
equal(DeadLook(), "0.7 true 1 1 1 " .. TALL, "the game shows it again: the row")
equal(tostring(S[fs.tracks.power].shown), "true", "the focus keeps its own track")
local threat = TargetFrame.TargetFrameContent.TargetFrameContentContextual.NumericalThreat
equal(Rel(threat, TargetFrame), "61.5,1,110.5,-17", "target: the threat number on the plate's top")
-- Edit Mode's focus size anchors it to the reaction colour's top again,
-- adding a point without clearing the old one: the keeper puts it back.
threat:SetPoint("BOTTOM", tm.ReputationColor, "TOP", 0, -1)
Fire("PLAYER_TARGET_CHANGED")
equal(Rel(threat, TargetFrame) .. " " .. threat:GetNumPoints(), "61.5,1,110.5,-17 1", "target: the game moves the threat number, the keeper puts it back")
equal(N(S[TargetFrame.TargetFrameContainer.FrameTexture].alpha), "0", "target: the Classic art faded")
-- The focus: the same as the target.
equal(RelAll(fs.plate, FocusFrame) .. " " .. Centre(fs.ring[1], FocusFrame), "12,-19,176,-77 178,-48", "focus: as the target")
local fmain = FocusFrame.TargetFrameContent.TargetFrameContentMain
tails, caps, bar = Clearance(fmain.Name, fmain.ReputationColor, FocusFrame, fs)
equal(tails >= 1.5 and caps >= 1.5 and bar >= 1.5, true, "focus: its line clear of the name too (" .. N(tails) .. ", " .. N(caps) .. ", " .. N(bar) .. ")")
-- The aura row, the target of target and the cast bar clear of it all.
equal(Rel(auras, TargetFrame), "25,-84,26,-85", "target: the aura row starts under the plate (32 up from the art's foot became 20)")
equal(Rel(tot, TargetFrame), "124,-92,244,-141", "target of target: under the target's pill")
local _, _, _, pillBottom = Rect(ts.pill[1])
local _, plateTop = Rect(os.plate[5])
equal(plateTop < pillBottom, true, "target of target: its plate below the target's pill")
-- Its ring against the pill's near round end (the rim's half circle).
local capL, capT, capR, capB = Rect(ts.pill[1])
local ringL, ringT, ringR, ringB = Rect(os.ring[1])
local gap = math.sqrt(((ringL + ringR) / 2 - capR) ^ 2 + ((ringT + ringB) / 2 - (capT + capB) / 2) ^ 2) - (ringR - ringL) / 2 - (capR - capL)
equal(gap > 0, true, "target of target: its ring clear of the pill's round end (" .. N(gap) .. ")")
local tcx, tcy = Rect(ts.ring[1]); local orx, ory = Rect(os.ring[1])
local d = math.sqrt(((tcx + 37) - (orx + 21.5)) ^ 2 + ((tcy - 37) - (ory - 21.5)) ^ 2)
equal(d > 37 + 21.5, true, "target of target: its ring clear of the target's (" .. N(d) .. ")")
TargetFrame.spellbar:AdjustPosition()
p = { TargetFrame.spellbar:GetPoint(1) }
equal(p[1] .. " " .. N(p[4]) .. " " .. N(p[5]), "TOPLEFT 43 -2", "target: the cast bar just under the pill")
Put(TargetFrame, "haveToT", true)
TargetFrame.spellbar:AdjustPosition()
p = { TargetFrame.spellbar:GetPoint(1) }
local _, _, _, totBottom = Rect(os.ring[1])
local _, barTop = Rect(TargetFrame.spellbar)
equal(p[1] .. " " .. N(p[4]) .. " " .. N(p[5]) .. " " .. tostring(barTop + 4 < totBottom), "TOPLEFT 43 -42 true",
    "target: with a target of target the cast bar (and a rounded shell) under it")
rawset(TargetFrame, "haveToT", nil)
-- The target of target's own look.
local oh, op = ns.UnitFrameOwn(tot, "totHealth"), ns.UnitFrameOwn(tot, "totPower")
equal(RelAll(os.plate, tot) .. " " .. Rel(os.strip, tot) .. " " .. Rel(oh, tot) .. " " .. Rel(op, tot),
    "25,-6,96,-38 48,-10,92,-20 48,-21,92,-29 48,-30,92,-34", "target of target: plate, name row and bars")
Tiled(os, tot, "target of target", 6, 2)
equal(Centre(os.ring[1], tot) .. " " .. Size(os.ring[1]) .. " " .. Centre(tot.Portrait, tot), "22.5,-22.5 43x43 22.5,-22.5", "target of target: ring round its portrait")
equal(Rel(tot.Name, tot), "51,-10,89,-20", "target of target: the name in the strip")
local totArt = ns.UnitFrameOwn(tot, "artHolder").fcui.art
equal(tostring(S[totArt].shown) .. " " .. tostring(S[ns.UnitFrameOwn(tot, "barBg")].shown), "false false", "target of target: EraUI's Classic art and backing hidden")
equal(os.pill, nil, "target of target: no pill")
Layers(os, tot, "target of target", 1)
-- The game rewrites its name and the target changes: the keeper keeps it in the strip.
tot.Name:ClearAllPoints(); tot.Name:SetPoint("TOPLEFT", tot.Portrait, "TOPRIGHT", 2, 0)
Fire("PLAYER_TARGET_CHANGED")
Tick()
equal(Rel(tot.Name, tot) .. " " .. tostring(S[totArt].shown), "51,-10,89,-20 false", "target of target: after the keepers, still in the strip, Classic art still hidden")
-- The pet.
equal(RelAll(es.plate, PetFrame) .. " " .. Rel(es.strip, PetFrame) .. " " .. Rel(PetFrameHealthBar, PetFrame) .. " " .. Rel(PetFrameManaBar, PetFrame),
    "28,-6,125,-42 52,-10,121,-20 52,-21,121,-31 52,-32,121,-38", "pet: plate, name row and its own bars in it")
Tiled(es, PetFrame, "pet", 6, 2)
equal(Centre(es.ring[1], PetFrame) .. " " .. Size(es.ring[1]) .. " " .. Centre(PetPortrait, PetFrame), "25.5,-24.5 45x45 25.5,-24.5", "pet: ring round its portrait")
equal(Rel(PetName, PetFrame) .. " " .. N(S[PetFrameTexture].alpha), "55,-10,118,-20 0", "pet: the name in its row, the Classic art faded")
equal(At(PetFrameHealthBarText, PetFrameHealthBar) .. " | " .. At(PetFrameHealthBarTextLeft, PetFrameHealthBar) .. " | " .. At(PetFrameHealthBarTextRight, PetFrameHealthBar)
    .. " | " .. At(PetFrameManaBarText, PetFrameManaBar) .. " | " .. At(PetFrameManaBarTextLeft, PetFrameManaBar) .. " | " .. At(PetFrameManaBarTextRight, PetFrameManaBar),
    "1 RIGHT RIGHT -3,0 | 1 LEFT LEFT 3,0 | 1 RIGHT RIGHT -3,0 | 1 RIGHT RIGHT -3,1 | 1 LEFT LEFT 3,1 | 1 RIGHT RIGHT -3,1",
    "pet: the one-number text at the far end, both numbers 3 in from each end; the power bar's a unit above its middle")
Layers(es, PetFrame, "pet", 0)
-- The party member (Classic Party Frames).
local mh, mp = Bars(member)
equal(RelAll(ms.plate, member) .. " " .. Rel(ms.strip, member) .. " " .. Rel(mh, member) .. " " .. Rel(mp, member),
    "28,-14,126,-50 52,-18,122,-28 52,-29,122,-39 52,-40,122,-46", "party: plate, name row and bars")
Tiled(ms, member, "party", 6, 2)
equal(Centre(ms.ring[1], member) .. " " .. Centre(member.Portrait, member), "25.5,-32.5 25.5,-32.5", "party: ring round its portrait")
equal(Rel(member.Name, member) .. " " .. N(S[member.Texture].alpha), "55,-17,119,-29 0", "party: the name in its row, the Classic art faded")
local phc2, pmana = member.HealthBarContainer, member.ManaBar
equal(At(phc2.CenterText, mh) .. " | " .. At(phc2.LeftText, mh) .. " | " .. At(phc2.RightText, mh) .. " | " .. At(pmana.CenterText, mp)
    .. " | " .. At(pmana.LeftText, mp) .. " | " .. At(pmana.RightText, mp),
    "1 RIGHT RIGHT -3,0 | 1 LEFT LEFT 3,0 | 1 RIGHT RIGHT -3,0 | 1 RIGHT RIGHT -3,1 | 1 LEFT LEFT 3,1 | 1 RIGHT RIGHT -3,1",
    "party: the same, the power bar's left number 3 in (the Classic look's 7), its texts a unit above its middle")
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Line(s), "none", "dark by default: no line on any frame (" .. s.kind .. ")") end
Layers(ms, host(member), "party")
-- Rounded ends: every frame's bars (their fills) and the tracks behind them
-- carry two masks of ours, a half circle at each end (CLAMP-wrapped, so the
-- rest of the bar is untouched): half the bar's height wide, its full
-- height, made on the bar (a fill) or the frame's canvas (a track).
local CAP = "Interface\\AddOns\\EraUI\\Media\\ThickBarCap"
local function Ours(tex)
    local list = {}
    for _, m in ipairs(S[tex].masks or {}) do
        if tostring(S[m].texture):sub(1, #CAP) == CAP then list[#list + 1] = m end
    end
    return list
end
local function EndsOf(tex, anchor, owner)
    local list = Ours(tex)
    if #list == 0 then return "square" end
    if #list ~= 2 then return #list .. " masks" end
    local al, at, ar, ab = Rect(anchor)
    local h = at - ab
    local wrong = {}
    for i, side in ipairs({ "Left", "Right" }) do
        local m = S[list[i]]
        local l, t, r, b = Rect(list[i])
        local x = i == 1 and al or ar - h / 2
        if m.texture ~= CAP .. side .. ".tga" or m.wrap ~= "CLAMP,CLAMP" then wrong[#wrong + 1] = side .. " art " .. tostring(m.texture) .. " " .. tostring(m.wrap) end
        if math.abs(l - x) > .01 or math.abs(r - l - h / 2) > .01 or math.abs(t - at) > .01 or math.abs(b - ab) > .01 then
            wrong[#wrong + 1] = side .. " cap at " .. N(l - al) .. "," .. N(at - t) .. " " .. N(r - l) .. "x" .. N(t - b)
        end
        if m.parent ~= owner then wrong[#wrong + 1] = side .. " made on " .. Label(m.parent) end
    end
    return #wrong == 0 and "round" or table.concat(wrong, "; ")
end
local function Ends(s, health, power)
    return table.concat({ EndsOf(S[health].fill, health, health), EndsOf(s.tracks.health, s.tracks.health, s.canvas),
        EndsOf(S[power].fill, power, power), EndsOf(s.tracks.power, s.tracks.power, s.canvas) }, " ")
end
-- The game's red health-loss bar, which the unit frames lay over the
-- player's health bar.
local function LossBar() return PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.PlayerFrameHealthBarAnimatedLoss end
-- Every frame's ends, in the session running now: player, target, focus,
-- target of target, pet, party, then the player's red health-loss fill
-- (its masks made on and pinned to the player's health bar).
local function EveryEnds()
    local h1, p1 = Bars(PlayerFrame)
    local h2, p2 = Bars(TargetFrame)
    local h3, p3 = Bars(FocusFrame)
    local h6, p6 = Bars(game.member)
    local t = TargetFrame.totFrame
    return table.concat({ Ends(Worn(PlayerFrame), h1, p1), Ends(Worn(TargetFrame), h2, p2), Ends(Worn(FocusFrame), h3, p3),
        Ends(Worn(t), ns.UnitFrameOwn(t, "totHealth"), ns.UnitFrameOwn(t, "totPower")), Ends(Worn(PetFrame), PetFrameHealthBar, PetFrameManaBar),
        Ends(Worn(game.member), h6, p6), "loss " .. EndsOf(S[LossBar()].fill, h1, h1) }, " | ")
end
local function Every(word, loss)
    local one = table.concat({ word, word, word, word }, " ")
    return table.concat({ one, one, one, one, one, one, "loss " .. (loss or word) }, " | ")
end
local ROUND, SQUARE = Every("round"), Every("square")
equal(EveryEnds(), ROUND, "rounded ends on every frame's bars and tracks (player, target, focus, target of target, pet, party) and the player's red health-loss bar")
equal(N(select(3, Rect(Ours(S[ph].fill)[1])) - Rect(ph)) .. " " .. N(select(3, Rect(Ours(S[PetFrameManaBar].fill)[1])) - Rect(PetFrameManaBar)),
    "10.5 3", "the ends half the bar's height: 10.5 on the 21-unit health bar, 3 on the pet's 6-unit power bar")
equal(#S[S[PetFrameHealthBar].fill].masks .. " " .. #S[S[PetFrameManaBar].fill].masks, "3 3", "the pet's fills: the game's own mask and our two, the most a texture takes")
equal(#S[S[LossBar()].fill].masks .. " " .. tostring(S[LossBar()].parent == ph), "2 true",
    "the red health-loss bar on the player's health bar: our two masks only (the unit frames took the game's own off)")
-- Flat Bars and the game setting a bar's art again keep the same fill, and
-- with it the ends.
settings.flatBars = true
ns.RefreshFlatBars()
PetFrameHealthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
equal(EveryEnds(), ROUND, "Flat Bars and a new fill art: still round")
settings.flatBars = nil
ns.RefreshFlatBars()
-- A bar handed a new fill texture: each frame's keeper rounds the new one
-- at its next pass (the party's when the game redraws its art).
do -- (in a block: the main chunk is near Lua's 200 locals)
    local function NewFill(bar) S[bar].fill = New("Texture", nil, bar, false, "ARTWORK") end
    NewFill(ph)
    Tick()
    equal(EveryEnds(), ROUND, "the player's bar given a new fill: the keeper rounds it at its next pass")
    NewFill(LossBar())
    Tick()
    equal(EveryEnds(), ROUND, "the red health-loss bar given a new fill: the player's keeper rounds it too")
    NewFill((Bars(TargetFrame)))
    NewFill((Bars(FocusFrame)))
    Tick()
    equal(EveryEnds(), ROUND, "the target's and focus's bars given new fills: their keeper rounds them")
    NewFill(ns.UnitFrameOwn(tot, "totHealth"))
    Tick()
    equal(EveryEnds(), ROUND, "the target of target's bar given a new fill: the target keeper rounds it")
    -- (in a fight, where only the party keeper runs: the full dressing waits)
    combat = true
    NewFill((Bars(member)))
    member.Texture:SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn")
    Tick()
    equal(EveryEnds(), ROUND, "the party member's bar given a new fill in a fight: the party keeper rounds it")
    combat = false
    -- The game guarding the loss bar in a fight (EraUI leaves its fill art
    -- then too): a new fill of its waits, square, for the pass after the fight.
    S[LossBar()].protected = true
    combat = true
    NewFill(LossBar())
    Tick()
    equal(EveryEnds(), Every("round", "square"), "the loss bar guarded in a fight: its new fill left alone, every other bar round")
    combat = false
    Tick()
    equal(EveryEnds(), ROUND, "after the fight: the keeper rounds it")
    S[LossBar()].protected = nil
end
equal(S[host(member)].level < S[member].level, true, "party: under the party frame and its portrait")

-- 3. The line and the marks -----------------------------------------------------------
local function Classify(unit, value)
    classification[unit] = value
    Fire("UNIT_CLASSIFICATION_CHANGED", unit)
end
-- Frame Edge Dark (the default): no line whatever the classification; the
-- pip marks an elite or a rare (gold, silver); a minor mob has no power track.
for _, case in ipairs({ { "elite", GOLD }, { "worldboss", GOLD }, { "rare", SILVER }, { "rareelite", SILVER }, { "normal" }, { "minus" },
    { "trivial" } }) do
    Classify("target", case[1])
    equal(Line(ts) .. " " .. Shown(ts.pip) .. " " .. (case[2] and S[ts.gem].colour or "-") .. " " .. tostring(S[ts.tracks.power].shown) .. " " .. RelAll(ts.plate, TargetFrame),
        "none " .. (case[2] and 3 or 0) .. " " .. (case[2] or "-") .. " " .. tostring(case[1] ~= "minus") .. " " .. (case[1] == "minus" and SHORT or TALL),
        "dark, target " .. case[1] .. ": no line, its pip and power track (a minor mob none, its plate ending under the health)")
end
Classify("target", "elite")
equal(Centre(ts.pip[1], TargetFrame) .. " " .. Size(ts.pip[1]) .. " " .. Size(ts.gem) .. " " .. N(S[ts.gem].rotation), "178,-11 10x10 6x6 0.785",
    "elite: the pip a turned square on top of the ring")
-- Frame Edge: Class colour, switched live (Core/Settings.lua calls this).
local function Edge(value) settings.thickFrameEdge = value; ns.RefreshThickFrameLines() end
Edge("class")
equal(Line(ps) .. " | " .. Line(es) .. " | " .. Line(os) .. " | " .. Line(ms), WARRIOR .. " | " .. WARRIOR .. " | " .. WARRIOR .. " | " .. PRIEST,
    "class colour: yours on your frame and your pet's, a player's on the target of target and the party member")
equal(Line(ts) .. " " .. Shown(ts.pip) .. " | " .. Line(fs), GOLD .. " 3 | none", "class colour: an elite target gold, with its pip; an NPC focus no line")
equal(Shown(ps.line) .. " " .. Shown(ps.lineGap) .. " " .. Shown(ps.pillLine) .. " " .. tostring(S[ps.ring[2]].shown), "7 7 3 true",
    "class colour: the whole line shows, round the plate, the ring and the pill")
for _, case in ipairs({ { "worldboss", GOLD }, { "rare", SILVER }, { "rareelite", SILVER }, { "normal", "none" }, { "minus", "none" },
    { "trivial", "none" }, { "elite", GOLD } }) do
    Classify("target", case[1])
    equal(Line(ts) .. " " .. Shown(ts.pip), case[2] .. " " .. (case[2] == "none" and 0 or 3), "class colour, target " .. case[1])
end
Classify("target", SECRET)
equal(Line(ts) .. " " .. Shown(ts.pip), GOLD .. " 3", "a fight hides the classification: the elite's line and pip kept")
Classify("target", "normal")
units.target, players.target, classes.target = "Elsa", true, "PRIEST"
Fire("PLAYER_TARGET_CHANGED")
equal(Line(ts), PRIEST, "a player target: their class colour")
classes.target = "PALADIN"
Fire("PLAYER_TARGET_CHANGED")
equal(Line(ts), PINK, "a paladin: pink, as everywhere in EraUI")
players.target = SECRET
Fire("PLAYER_TARGET_CHANGED")
equal(Line(ts), "none", "who it is kept secret: no line, nothing compared")
players.target = true
classes.target = SECRET
RAID_CLASS_COLORS[SECRET] = { r = 0, g = 1, b = 0 } -- so a secret used as a key would show
Fire("PLAYER_TARGET_CHANGED")
equal(Line(ts), "none", "a secret class: no line, never looked up")
RAID_CLASS_COLORS[SECRET] = nil
classes.target = "PRIEST"
Fire("PLAYER_TARGET_CHANGED")
-- The target of target follows whoever it is now.
players.targettarget, classes.targettarget = false, nil
Fire("PLAYER_TARGET_CHANGED")
equal(Line(os), "none", "an NPC target of target: no line")
players.targettarget, classes.targettarget = true, "WARRIOR"
Fire("PLAYER_TARGET_CHANGED")
equal(Line(os), WARRIOR, "you as the target of target again: your colour")
-- The full class colour, whatever Dark Mode's slider and Darken class colours too.
settings.darkMode, settings.darkenClassColours, settings.darkModeDarkness = true, true, 90
ns.RefreshDarkness()
equal(Line(ps) .. " " .. Line(ts), WARRIOR .. " " .. PRIEST, "Dark Mode at 90 with Darken class colours too: the full class colours")
settings.darkMode, settings.darkenClassColours, settings.darkModeDarkness = nil, nil, 58
-- Portrait Rings off: the ring's line goes with the ring, the rest stays.
Switch("thickFrameRings", false)
equal(tostring(S[ps.ring[2]].shown) .. " " .. Line(ps), "false " .. WARRIOR, "Portrait Rings off: the ring's line goes with it, the rest stays")
Switch("thickFrameRings", true)
equal(tostring(S[ps.ring[2]].shown) .. " " .. Line(ps), "true " .. WARRIOR, "and back with it")
-- Back to Dark: every line gone at once; anything but "class" is dark.
local function Lines() local out = {}; for i, s in ipairs({ ps, ts, fs, os, es, ms }) do out[i] = Line(s) end; return table.concat(out, " | ") end
local CLASS_LINES = table.concat({ WARRIOR, PRIEST, "none", WARRIOR, WARRIOR, PRIEST }, " | ")
local NO_LINES = "none | none | none | none | none | none"
for _, value in ipairs({ "dark", "class", "bogus", "class", "nil" }) do
    Edge(value ~= "nil" and value or nil)
    equal(Lines(), value == "class" and CLASS_LINES or NO_LINES, "Frame Edge " .. value .. ": player, target, focus (an NPC), target of target, pet, party")
end
equal(table.concat(writes, ","), "", "Frame Edge: no key written on the game's frames")
-- Dark Mode (as loaded): still no line; the reaction line keeps the game's
-- colour (its Classic backing, which Dark Mode greys, never put on).
local dark = { darkMode = true }
for k, v in pairs(ON) do dark[k] = v end
Session(dark)
Grab()
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Line(s), "none", "Dark Mode: no line (" .. s.kind .. ")") end
equal(S[tm.ReputationColor].tint .. " " .. S[tm.ReputationColor].texture, REACTION .. " " .. SOLID, "Dark Mode: the reaction line in the game's colour")
-- Dark Mode, Thick Frames switched on live: the Classic look's backing made
-- the reaction colour Dark Mode's grey; once thick, the Darkness slider
-- leaves it alone, so the game's own colour stays. Off again: greyed as before.
Session({ darkMode = true, thickFrameRings = true })
Grab()
reaction = tm.ReputationColor
equal(S[reaction].tint, Grey(58), "Dark Mode, the Classic look: the reaction's backing in Dark Mode's grey, as always")
Switch("thickFrames", true)
reaction:SetVertexColor(1, .1, .1) -- the game colours it again (a new target)
settings.darkModeDarkness = 90
ns.RefreshDarkness()
equal(S[reaction].tint, REACTION, "switched on live: the slider no longer greys the reaction line, the game's colour stays")
Switch("thickFrames", false)
equal(S[reaction].tint, Grey(90), "off again: the Classic backing in Dark Mode's grey, as before")
equal(table.concat(writes, ","), "", "Dark Mode: no key written on the game's frames")
-- Thick Frames off with Edge on Class colour: the Darkness slider's call
-- (Dark Mode on) and Edge's own leave every plate bare.
local classEdge = { thickFrameEdge = "class" }
for k, v in pairs(ON) do classEdge[k] = v end
Session(classEdge)
Grab()
equal(Line(ps) .. " " .. Line(ms), WARRIOR .. " " .. PRIEST, "Edge on Class colour: the lines while on")
Switch("thickFrames", false)
settings.darkMode = true
ns.RefreshDarkness()
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Shown(s.all), 0, "off, Dark Mode's slider: nothing shows (" .. s.kind .. ")") end
ns.RefreshThickFrameLines()
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Shown(s.all), 0, "off, Edge switched: nothing shows (" .. s.kind .. ")") end

-- 4. Portrait Rings and Classic Party Frames ------------------------------------------
Session(ON)
Grab()
equal(Switch("thickFrameRings", false), true, "Portrait Rings off: at once")
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do
    equal(Shown(s.ring) .. " " .. Shown(s.plate) .. " " .. Shown({ s.tracks.health, s.tracks.power }), "0 7 2",
        "Portrait Rings off: no ring, the rest stays (" .. s.kind .. ")")
end
equal(Centre(ts.pip[1], TargetFrame), "178,-11", "the pip stays put without the ring")
Switch("thickFrameRings", true)
equal(Shown(ps.ring) .. Shown(ms.ring), "22", "Portrait Rings on again: dark, so its two near-black circles and no line")
equal(Switch("thickFrameParty", false), true, "Classic Party Frames off: at once")
equal(Shown(ms.all) .. " " .. N(S[member.Texture].alpha) .. " " .. Rel(member.Name, member) .. " " .. tostring(S[ns.UnitFrameOwn(member, "barBg")].shown),
    "0 1 49,-7,49,-19 true", "Classic Party Frames off: the party frame Classic again")
equal(Shown(ps.plate) .. Shown(es.plate), "77", "the other frames stay thick")
Switch("thickFrameParty", true)
equal(Shown(ms.plate) .. " " .. N(S[member.Texture].alpha), "7 0", "Classic Party Frames on again")

-- 5. Live off and on: today's look exactly -------------------------------------------------
equal(Switch("thickFrames", false), true, "off at once")
local made = Count()
-- (the game moves its cast bars at the next cast)
local function Casts() TargetFrame.spellbar:AdjustPosition(); FocusFrame.spellbar:AdjustPosition() end
Casts()
p = { TargetFrame.spellbar:GetPoint(1) }
equal(N(p[5]) .. " " .. Rel(tot, TargetFrame) .. " " .. Rel(auras, TargetFrame), "3 124,-69,244,-118 25,-72,26,-73", "off: cast bar, target of target and aura row back")
SameAs(classicOff, Snapshot(), "switched off: every game piece and EraUI's Classic pieces as in a game that never had it on")
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Shown(s.all), 0, "off: every piece hidden (" .. s.kind .. ")") end
equal(EveryEnds(), SQUARE, "off: every mask of ours off the bars and tracks (the Classic look's bars square as today)")
equal(#S[S[PetFrameHealthBar].fill].masks, 1, "off: the pet's fill keeps the game's own mask")
equal(table.concat(writes, ","), "", "off: no key written on the game's frames")
Switch("thickFrames", true)
Casts()
SameAs(atLogin, Snapshot(), "on again: the same as on at login")
equal(Count(), made, "on again: nothing new made")
equal(EveryEnds(), ROUND, "on again: round again, with the same masks")
-- With Class colour too: off and on again, the lines as they were.
Edge("class")
local classOn = Snapshot()
Switch("thickFrames", false)
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Shown(s.all), 0, "class colour, off: every piece hidden (" .. s.kind .. ")") end
Switch("thickFrames", true)
SameAs(classOn, Snapshot(), "class colour, on again: the same lines as before")
Edge(nil)
equal(Lines(), NO_LINES, "back to dark: no line anywhere")
-- The calls EraUI makes on the Edit Mode frames themselves: none new with
-- it on (the pet's only to make its pieces, the first time).
local function OnFrames(list)
    local out = {}
    for _, call in ipairs(list) do
        local who = call:match("^(%w+):")
        if who == "PlayerFrame" or who == "TargetFrame" or who == "FocusFrame" or who == "PetFrame" then out[call] = true end
    end
    return out
end
logging = true
calls = {}
Apply()
local onCalls = OnFrames(calls)
settings.thickFrames = false
calls = {}
Apply()
local offCalls = OnFrames(calls)
logging = false
equal(tostring(onCalls["PlayerFrame:GetFrameLevel"]) .. " " .. tostring(onCalls["PetFrame:SetSize"]), "true true",
    "the calls are seen (the Classic look's own reads and the pet's size)")
local extra = {}
for call in pairs(onCalls) do if not offCalls[call] then extra[#extra + 1] = call end end
for call in pairs(offCalls) do if not onCalls[call] then extra[#extra + 1] = call end end
equal(table.concat(extra, ","), "", "no call on the player, target, focus or pet frames that the Classic look doesn't make")
settings.thickFrames = true
Apply()

-- 6. In a fight: a switch waits for the end, the keepers keep each look whole ----------
combat = true
local before = Snapshot()
equal(Switch("thickFrames", false), false, "off in a fight: it waits")
SameAs(before, Snapshot(), "in the fight nothing changes")
-- The game moves the player's name and level, and the target changes:
-- the keepers put them back in the look each frame wears.
PlayerName:ClearAllPoints(); PlayerName:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 88, -27)
PlayerLevelText:ClearAllPoints(); PlayerLevelText:SetPoint("CENTER", PlayerFrame, "TOPLEFT", 10, 10)
Tick()
equal(Rel(PlayerName, PlayerFrame) .. " " .. Centre(PlayerLevelText, PlayerFrame), "102,-21.5,211,-33.5 55,-88", "in the fight the keeper keeps the thick spots")
Classify("target", "elite")
equal(Shown(ts.pip) .. " " .. Rel(auras, TargetFrame) .. " " .. Centre(tm.LevelText, TargetFrame), "3 25,-84,26,-85 178,-88", "the target keeper too")
-- Frame Edge switched in the fight: at once (EraUI's own textures only), and back.
Edge("class")
equal(Line(ps) .. " " .. Line(ts), WARRIOR .. " " .. GOLD, "Frame Edge in a fight: the lines at once")
Edge(nil)
equal(Line(ps) .. " " .. Line(ts), "none none", "and gone at once")
-- The game puts its own party art back in the fight (a new member, a
-- vehicle): the keeper puts the art's place back but keeps the name in the
-- strip and the art faded (the full dressing waits for the fight's end).
member.Texture:SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn")
Tick()
equal(Rel(member.Name, member) .. " " .. N(S[member.Texture].alpha), "55,-17,119,-29 0", "party: in the fight the keeper keeps the name in the strip, the art faded")
-- Edge on Class colour and someone else in that party slot in the fight (a
-- paladin): on the roster change the game redraws the party art (Forever's
-- PartyMemberFrame OnEvent, GROUP_ROSTER_UPDATE: UpdateMember, UpdateArt),
-- and the keeper gives the line the new member's colour, no pass needed.
Edge("class")
equal(Line(ms), PRIEST, "Edge on Class colour in the fight: the party member's line")
local function Roster(name, class)
    units.party1, classes.party1 = name, class
    member.Texture:SetAtlas("UI-HUD-UnitFrame-Party-PortraitOn")
    Fire("GROUP_ROSTER_UPDATE")
end
Roster("Arlen", "PALADIN")
equal(Line(ms) .. " " .. N(S[member.Texture].alpha), PINK .. " 0", "a paladin in that slot in the fight: the line takes their colour at the roster change")
Roster("Elsa", "PRIEST")
equal(Line(ms), PRIEST, "and back")
Edge(nil)
Classify("target", "normal")
combat = false
local q = queued
Fire("PLAYER_REGEN_ENABLED")
equal(queued, q + 1, "the fight's end books the pass")
Apply() -- the pass, as Classic/Core.lua runs it
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Shown(s.all), 0, "after the fight: off (" .. s.kind .. ")") end
Casts()
SameAs(classicOff, Snapshot(), "after the fight: today's look exactly")
combat = true
equal(Switch("thickFrames", true), false, "on in a fight: it waits")
equal(Shown(ps.plate), 0, "nothing shows in the fight")
Tick()
equal(Rel(PlayerName, PlayerFrame), "97,-30,197,-42", "the keeper keeps the Classic spot meanwhile")
combat = false
Apply()
equal(Shown(ps.plate) .. Shown(ts.plate), "77", "after the fight: on")
Classify("target", "normal")

-- 7. Flat Bars either way, Unit Frames off ------------------------------------------------
settings.flatBars = true
ph = Bars(PlayerFrame)
ns.RefreshFlatBars()
equal(S[S[ph].fill].texture .. " " .. Rel(ph, PlayerFrame), SOLID .. " 97,-39,216,-60", "Flat Bars on: the solid fill, the thick bar's size kept")
settings.flatBars = nil
ns.RefreshFlatBars()
equal(S[S[ph].fill].texture, "Interface\\TargetingFrame\\UI-StatusBar", "Flat Bars off: the shaded fill")
equal(EveryEnds(), ROUND, "after the fight's pass, Flat Bars either way: round")
modules.unitFrames.restore()
for _, s in ipairs({ ps, ts, fs, os, es, ms }) do equal(Shown(s.all), 0, "Unit Frames off: every piece hidden (" .. s.kind .. ")") end
equal(EveryEnds(), SQUARE, "Unit Frames off: no mask of ours left")
equal(N(S[PlayerFrame.PlayerFrameContainer.FrameTexture].alpha) .. N(S[PetFrameTexture].alpha) .. N(S[member.Texture].alpha), "111", "Unit Frames off: the art back")
equal(table.concat(writes, ","), "", "no key written on the game's frames, all the way through")

-- 8. Square rather than half rounded ---------------------------------------------------
-- The art not found (a new file needs a full restart of the game, not a
-- /reload): no mask on anything, every bar square, the look otherwise whole.
for _, side in ipairs({ "Left", "Right" }) do
    missing[CAP .. side .. ".tga"] = true
    Session(ON)
    Grab()
    equal(EveryEnds(), SQUARE, "the " .. side:lower() .. " end's art missing: every bar and track square, none half rounded")
    equal(#S[S[PetFrameHealthBar].fill].masks, 1, "the " .. side:lower() .. " end's art missing: the pet's fill only the game's own mask")
    equal(Shown(ps.plate) .. Shown(ts.plate), "77", "the " .. side:lower() .. " end's art missing: the look otherwise on")
    missing[CAP .. side .. ".tga"] = nil
end
-- A fill that already carries two masks of the game's (here the pet's
-- power bar, rounded after its health bar): the second of ours would be its
-- fourth and throw, so the first comes off again, and so do the ones its
-- health bar and track already took: that frame (both bars, both tracks)
-- stays square; the others are round.
gameMasks.PetFrameManaBar = 2
Session(ON)
Grab()
local R4, S4 = "round round round round", "square square square square"
local PET_SQUARE = table.concat({ R4, R4, R4, R4, S4, R4, "loss round" }, " | ")
equal(EveryEnds(), PET_SQUARE, "the pet's power fill already holding two masks: the whole pet square, not half, the other frames round")
equal(#S[S[PetFrameHealthBar].fill].masks .. " " .. #S[S[PetFrameManaBar].fill].masks, "1 2", "the pet's fills: only the game's own left")
Switch("thickFrames", false)
Switch("thickFrames", true)
equal(EveryEnds(), PET_SQUARE, "off and on again: the pet stays square for the session, the rest round again")
gameMasks.PetFrameManaBar = 1
-- The player's red health-loss fill already holding two other masks: the
-- second of ours would be its fourth, so the whole player frame stays
-- square (its bars, tracks and the loss fill), the others round.
gameMasks.PlayerFrameHealthBarAnimatedLoss = 2
Session(ON)
Grab()
equal(EveryEnds(), table.concat({ S4, R4, R4, R4, R4, R4, "loss square" }, " | "), "the loss fill holding two other masks: the player's frame square, not half, the others round")
equal(#S[S[LossBar()].fill].masks, 2, "the loss fill: only its two other masks left")
gameMasks.PlayerFrameHealthBarAnimatedLoss = 0
Session(ON)
Grab()
equal(EveryEnds(), ROUND, "back to the game's one mask: round everywhere")

print("Thick Frames checks passed: " .. checks .. " assertions.")
