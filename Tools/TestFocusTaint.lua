-- The focus frame and taint (status report 2026-10-11, after 1.6.0: "Blocked
-- by the game this session: 17:52:58 blocked FocusFrame:SetPointBase() (in
-- combat)", at a level-up in a fight). A mock game that keeps taint the way
-- the client does: every Lua key written while EraUI's code runs carries
-- EraUI's taint (also when EraUI's code calls the game's own functions, which
-- then run as EraUI); the game's code that reads such a key runs tainted from
-- then on in that execution; and a protected call on a protected frame in a
-- fight from a tainted execution is refused and blamed on EraUI.
-- Modelled on Forever's UI code: Edit Mode's overrides and snap records
-- (Blizzard_EditMode/Shared/EditModeSystemTemplates.lua: OnSystemLoad,
-- SetScaleOverride, SetPointOverride, ClearAllPointsOverride,
-- SetSnappedToFrame, ClearFrameSnap), its layout re-apply
-- (Shared/EditModeManager.lua UpdateLayoutInfo: InitSystemAnchors, then
-- UpdateSystems, each frame in its own secureexecuterange call; a level-up
-- re-applies the layout), the focus frame's SetSmallSize and the reads of its
-- aura update (Blizzard_UnitFrame/Mainline/TargetFrame.lua).
-- Checked with Edit Mode's small focus (Use Larger Frame off) snapped to the
-- player frame (the user's Foreverskin layout) and anchored to the screen,
-- Match Focus Size on and off: EraUI's unit frames and cast bars
-- (Classic/Textures.lua, Skin.lua, UnitFrames.lua, CastBars.lua) at login, on
-- events and on their 0.25 s check, in and out of a fight, then the game
-- placing the cast bars and re-applying the layout (unchanged, or changed so
-- its own SetSmallSize runs) in the fight: nothing refused, no key on the
-- game's frames carries EraUI's taint, the game's aura update reads nothing
-- EraUI wrote, the focus is at the target's scale where it was, and the cast
-- bars sit where EraUI puts them (an elite target's lower, read from the
-- flag the unit frames keep). And the mock itself: EraUI running the game's
-- FocusFrame:SetSmallSize (1.6.0's Match Focus Size) or the frame's own
-- SetPoint (before 1.6.0) does get "FocusFrame:SetPointBase()" refused there.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack
local pack = table.pack or function(...) return { n = select("#", ...), ... } end

-- Taint ------------------------------------------------------------------------
local ERAUI = "EraUI"
local tainted = nil -- the running execution's taint: nil (secure) or ERAUI
local combat = false
local refused = {}

-- Runs fn with the given taint, as the client starts an execution: the
-- game's own event handlers secure (nil), EraUI's code as EraUI.
local function Run(taint, fn, ...)
    local saved = tainted
    tainted = taint
    local r = pack(pcall(fn, ...))
    tainted = saved
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
end
-- secureexecuterange: each call starts with the caller's own taint, so one
-- frame's taint never reaches the next one's.
local function SecureRange(list, fn)
    local base = tainted
    for i, v in ipairs(list) do
        tainted = base
        fn(i, v)
    end
    tainted = base
end

-- Mock widgets -----------------------------------------------------------------
-- The C side of each object lives in S; its Lua keys in V, each key's taint
-- in T. The object itself stays empty, so every read and write of a key goes
-- through the metamethods below.
local S = setmetatable({}, { __mode = "k" })
local V = setmetatable({}, { __mode = "k" })
local T = setmetatable({}, { __mode = "k" })
local Proto = {}
local gameObjects = {}
local eraFrames = {}
local PROTECTED = { SetPoint = true, ClearAllPoints = true, SetScale = true, SetAllPoints = true, SetSize = true,
    SetWidth = true, SetHeight = true, SetParent = true, Show = true, Hide = true }
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear" }
local function Verb(key)
    if type(key) ~= "string" or key:match("Base$") or key == "SetSmallSize" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
-- A C method under the name it is called by. A protected one on a protected
-- frame, in a fight, from a tainted execution is refused, as the client does.
local function C(name, method)
    return function(self, ...)
        local s = S[self]
        if PROTECTED[method] and s and s.protected and combat and tainted then
            refused[#refused + 1] = tostring(s.name) .. ":" .. name .. "()"
            return
        end
        local fn = Proto[method]
        if fn then return fn(self, ...) end
    end
end
local function New(kind, name, parent, game)
    local obj = {}
    S[obj] = { kind = kind, name = name, parent = parent, points = {}, scripts = {}, events = {}, level = 1,
        shown = true, alpha = 1, scale = 1 }
    V[obj], T[obj] = {}, {}
    if game then gameObjects[#gameObjects + 1] = obj else eraFrames[#eraFrames + 1] = obj end
    return setmetatable(obj, {
        __index = function(t, key)
            local value, taint = V[t][key], T[t][key]
            if value ~= nil or taint then
                if taint and not tainted then tainted = taint end
                return value
            end
            if Proto[key] or Verb(key) then return C(key, key) end
            return nil
        end,
        __newindex = function(t, key, value)
            V[t][key] = value
            T[t][key] = tainted
        end,
    })
end
local function Resolve(rel) if type(rel) == "string" then return _G[rel] end return rel end
function Proto:GetName() return S[self].name end
function Proto:GetParent() return S[self].parent end
function Proto:SetParent(p) S[self].parent = p end
function Proto:IsObjectType(kind) return S[self].kind == kind end
function Proto:GetFrameLevel() return S[self].level end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:GetScale() return S[self].scale end
function Proto:SetScale(v) S[self].scale = v end
function Proto:IsShown() return S[self].shown end
function Proto:Show() S[self].shown = true end
function Proto:Hide() S[self].shown = false end
function Proto:SetShown(v) S[self].shown = v and true or false end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(point, rel, relPoint, x, y)
    local points = S[self].points
    local p = { point, Resolve(rel), relPoint, x or 0, y or 0 }
    for i, old in ipairs(points) do
        if old[1] == point then points[i] = p return end
    end
    points[#points + 1] = p
end
function Proto:SetAllPoints(rel) S[self].points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } } end
function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i) local p = S[self].points[i or 1]; if p then return unpack(p, 1, 5) end end
function Proto:SetSize(w, h) S[self].w, S[self].h = w, h end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
function Proto:HookScript() end
function Proto:RegisterEvent(event) S[self].events[event] = true end
function Proto:RegisterUnitEvent(event) S[self].events[event] = true end
function Proto:IsProtected() return S[self].protected == true end
function Proto:IsMouseOver() return false end
function Proto:CreateTexture() return New("Texture", nil, self, false) end
function Proto:CreateFontString() return New("FontString", nil, self, false) end
function Proto:SetFontObject(font) S[self].font = font end
function Proto:GetFontObject() return S[self].font end
function Proto:SetStatusBarTexture() local s = S[self]; s.fill = s.fill or New("Texture", nil, self, false) end
function Proto:GetStatusBarTexture() return S[self].fill end
function Proto:SetStatusBarColor(r, g, b, a) S[self].colour = { r, g, b, a } end
function Proto:GetStatusBarColor() local c = S[self].colour or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end

-- The game -----------------------------------------------------------------------
InCombatLockdown = function() return combat end
issecretvalue = function() return false end
CreateFrame = function(kind, name, parent)
    local f = New(kind, name, parent, tainted == nil)
    if name then _G[name] = f end
    return f
end
CreateFont = function() return { SetFontObject = function() end, SetTextColor = function() end } end
CreateColor = function(r, g, b) return { GetRGB = function() return r, g, b end } end
-- A hook's write never carries the caller's taint; the hook itself runs as
-- EraUI and the caller's taint comes back after it.
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    local old = t[key]
    local function hooked(...)
        local r = pack(old(...))
        Run(ERAUI, fn, ...)
        return unpack(r, 1, r.n)
    end
    if V[t] then V[t][key], T[t][key] = hooked, nil else rawset(t, key, hooked) end
end
C_Timer = { After = function() end }
UnitExists = function() return true end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 30 end
UnitPowerMax = function() return 100 end
UnitPowerType = function() return 0, "MANA" end
UnitIsPlayer = function() return false end
UnitClass = function() return "Warrior", "WARRIOR" end
UnitClassification = function(unit) return unit == "target" and "elite" or "normal" end
UnitName = function() return "Name" end
UnitLevel = function() return 18 end
UnitCanAttack = function() return true end
UnitIsPVP = function() return false end
UnitFactionGroup = function() return "Alliance" end
UnitAffectingCombat = function() return combat end
IsResting = function() return false end
TextStatusBarText = { name = "TextStatusBarText" }
TextStatusBarTextLarge = { name = "TextStatusBarTextLarge" }

-- Edit Mode (EditModeSystemTemplates.lua), run by the game, so secure.
local systems
local function SetScaleOverride(self, newScale) -- :117-135
    local oldScale = self:GetScale()
    self:SetScaleBase(newScale)
    if oldScale == newScale then return end
    for i = 1, self:GetNumPoints() do
        local point, rel, relPoint, x, y = self:GetPoint(i)
        self:SetPoint(point, rel, relPoint, x * oldScale / newScale, y * oldScale / newScale)
    end
end
local function SetPointOverride(self, point, rel, relPoint, x, y) -- :147-151
    self:SetPointBase(point, rel, relPoint, x, y)
    self:SetSnappedToFrame(rel)
    EditModeManagerFrame:OnEditModeSystemAnchorChanged()
end
local function ClearAllPointsOverride(self) -- :153-156
    self:ClearAllPointsBase()
    self:ClearFrameSnap()
end
local function AddSnappedFrame(self, frame) self.snappedFrames[frame] = true end -- :700-702
local function RemoveSnappedFrame(self, frame) self.snappedFrames[frame] = nil end -- :704-706
local function SetSnappedToFrame(self, frame) -- :719-727
    if type(frame) == "string" then frame = _G[frame] end
    if frame and type(frame) == "table" and frame.AddSnappedFrame then
        frame:AddSnappedFrame(self)
        self.snappedToFrame = frame
    end
end
local function ClearFrameSnap(self) -- :729-734
    if self.snappedToFrame then
        self.snappedToFrame:RemoveSnappedFrame(self)
        self.snappedToFrame = nil
    end
end
local function OnSystemLoad(self) -- :3-29
    self.SetScaleBase = C("SetScaleBase", "SetScale")
    self.SetScale = SetScaleOverride
    self.SetPointBase = C("SetPointBase", "SetPoint")
    self.SetPoint = SetPointOverride
    self.ClearAllPointsBase = C("ClearAllPointsBase", "ClearAllPoints")
    self.ClearAllPoints = ClearAllPointsOverride
    self.AddSnappedFrame, self.RemoveSnappedFrame = AddSnappedFrame, RemoveSnappedFrame
    self.SetSnappedToFrame, self.ClearFrameSnap = SetSnappedToFrame, ClearFrameSnap
    self.snappedFrames = New("Table", S[self].name .. ".snappedFrames", nil, true)
    systems[#systems + 1] = self
end

-- FocusFrameMixin:SetSmallSize (Mainline/TargetFrame.lua:1163-1214).
local function SetSmallSize(self, smallSize)
    local main = self.TargetFrameContent.TargetFrameContentMain
    local contextual = self.TargetFrameContent.TargetFrameContentContextual
    self.smallSize = smallSize
    if self.smallSize then
        self.maxBuffs, self.maxDebuffs = 0, 8
        self.showLeader, self.showPVP, self.showAuraCount = nil, nil, nil
        self.TOT_AURA_ROW_WIDTH = 80
        self:SetScale(0.75)
        self.totFrame:SetScale(1.333)
        self.spellbar:SetScale(1.333)
        self.totFrame:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 20, 8)
        main.HealthBarsContainer.HealthBar.TextString:SetFontObject(TextStatusBarTextLarge)
        contextual.NumericalThreat:SetPoint("BOTTOM", main.ReputationColor, "TOP", 0, -1)
    else
        self.maxBuffs, self.maxDebuffs = nil, nil
        self.showLeader, self.showPVP, self.showAuraCount = true, true, true
        self.TOT_AURA_ROW_WIDTH = 101
        self:SetScale(1)
        self.totFrame:SetScale(1)
        self.spellbar:SetScale(1)
        self.totFrame:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 12, 10)
        main.HealthBarsContainer.HealthBar.TextString:SetFontObject(TextStatusBarText)
        contextual.NumericalThreat:SetPoint("BOTTOM", main.ReputationColor, "TOP", 0, 0)
    end
end

-- The user's layouts (Logs/EditMode.log): Foreverskin's focus is snapped to
-- the player frame; the EraUI and 11111111 layouts anchor it to the screen.
-- Use Larger Frame off in all three.
local focusTo
local function Layout() -- C_EditMode.GetLayouts(): fresh tables, secure
    return {
        PlayerFrame = { "TOPLEFT", "UIParent", "TOPLEFT", 4, -4 },
        TargetFrame = { "TOPLEFT", "UIParent", "TOPLEFT", 250, -4 },
        FocusFrame = focusTo == "PlayerFrame" and { "TOPLEFT", "PlayerFrame", "BOTTOMLEFT", 4.5, 26.5 }
            or { "TOPLEFT", "UIParent", "TOPLEFT", 250, -165 },
    }
end
-- EditModeManager.lua:1467-1475; none of these frames is a managed one.
local function initSystemAnchor(_, frame)
    if frame.isBottomManagedFrame or frame.isRightManagedFrame then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
end
-- UpdateLayoutInfo (EditModeManager.lua:1008-1035): every frame put at the
-- screen's corner, then on its saved anchor (ApplySystemAnchor,
-- EditModeSystemTemplates.lua:350-383), then its changed settings (all of
-- them at login, none when an unchanged layout is re-applied).
local function UpdateLayoutInfo(settingsDirty)
    local data = Layout()
    SecureRange(systems, initSystemAnchor)
    SecureRange(systems, function(_, frame)
        local info = data[S[frame].name]
        frame:ClearAllPoints()
        local scale = frame:GetScale()
        frame:SetPoint(info[1], info[2], info[3], info[4] / scale, info[5] / scale)
        if settingsDirty and frame == FocusFrame then frame:SetSmallSize(true) end -- UseLargerFrame 0, :1478-1486
    end)
end

-- The keys the game's aura update (ConfigureAuraContainer, :502-528) and the
-- cast bar's AdjustPosition (:827-849) read on the focus in a fight: the
-- taint they would run with.
local AURA_READS = { "maxBuffs", "maxDebuffs", "buffsOnTop", "showAuraCount", "TOT_AURA_ROW_WIDTH", "totFrame",
    "smallSize", "haveToT", "spellbar", "TargetFrameContent" }
local function GameReads(frame, keys)
    return Run(nil, function()
        for _, key in ipairs(keys) do local _ = frame[key] end
        return tainted
    end)
end

local function BuildGame()
    gameObjects, eraFrames, systems = {}, {}, {}
    local function G(kind, name, parent, protected)
        local obj = New(kind, name, parent, true)
        if name then _G[name] = obj end
        S[obj].protected = protected or false
        return obj
    end
    UIParent = G("Frame", "UIParent")
    EditModeManagerFrame = G("Frame", "EditModeManagerFrame", UIParent)
    EditModeManagerFrame.OnEditModeSystemAnchorChanged = function(self) self.editModeSystemAnchorDirty = true end -- :1037-1039
    PlayerFrame = G("Button", "PlayerFrame", UIParent, true)
    PlayerFrame.unit = "player"
    PlayerFrame.PlayerFrameContainer = G("Frame", "PlayerFrameContainer", PlayerFrame)
    local content = G("Frame", "PlayerFrameContent", PlayerFrame)
    PlayerFrame.PlayerFrameContent = content
    local main = G("Frame", "PlayerFrameContentMain", content)
    content.PlayerFrameContentMain = main
    content.PlayerFrameContentContextual = G("Frame", "PlayerFrameContentContextual", content)
    local hc = G("Frame", "PlayerHealthBarsContainer", main)
    main.HealthBarsContainer = hc
    hc.HealthBar = G("StatusBar", "PlayerFrameHealthBar", hc)
    main.ManaBarArea = G("Frame", "PlayerManaBarArea", main)
    main.ManaBarArea.ManaBar = G("StatusBar", "PlayerFrameManaBar", main.ManaBarArea)
    local function TargetLike(name, unit)
        local frame = G("Button", name, UIParent, true)
        frame.unit = unit
        frame.TargetFrameContainer = G("Frame", name .. "Container", frame)
        frame.TargetFrameContainer.FrameTexture = G("Texture", name .. "FrameTexture", frame.TargetFrameContainer)
        frame.TargetFrameContainer.Flash = G("Texture", name .. "Flash", frame.TargetFrameContainer)
        local c = G("Frame", name .. "Content", frame)
        frame.TargetFrameContent = c
        local m = G("Frame", name .. "ContentMain", c)
        c.TargetFrameContentMain = m
        local x = G("Frame", name .. "ContentContextual", c)
        c.TargetFrameContentContextual = x
        local health = G("Frame", name .. "HealthBarsContainer", m)
        m.HealthBarsContainer = health
        health.HealthBar = G("StatusBar", name .. "HealthBar", health)
        health.HealthBar.TextString = G("FontString", name .. "HealthBarText", health.HealthBar)
        S[health.HealthBar.TextString].font = TextStatusBarText
        m.ManaBar = G("StatusBar", name .. "ManaBar", m)
        m.ReputationColor = G("Texture", name .. "ReputationColor", m)
        m.Name = G("FontString", name .. "Name", m)
        m.LevelText = G("FontString", name .. "LevelText", m)
        x.NumericalThreat = G("Frame", name .. "NumericalThreat", x)
        x.Auras = G("Frame", name .. "Auras", x)
        frame.GetAuraContainer = function(self) return self.TargetFrameContent.TargetFrameContentContextual.Auras end
        local tot = G("Button", name .. "ToT", frame, true)
        frame.totFrame = tot
        tot.unit = unit .. "target"
        tot.HealthBar = G("StatusBar", name .. "ToTHealthBar", tot)
        tot.ManaBar = G("StatusBar", name .. "ToTManaBar", tot)
        tot.FrameTexture = G("Texture", name .. "ToTFrameTexture", tot)
        -- The cast bar and its own placing (TargetSpellBarMixin:AdjustPosition,
        -- Mainline/TargetFrame.lua:827-849, no aura rows shown), run by the
        -- game on each cast, in fights too.
        local bar = G("StatusBar", name .. "SpellBar", frame)
        frame.spellbar = bar
        bar.AdjustPosition = function(self)
            local parent = self:GetParent()
            local y = parent.smallSize and 3 or 5
            if parent.haveToT then y = parent.smallSize and -48 or -46 end
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", parent.smallSize and 38 or 43, y)
        end
        return frame
    end
    TargetFrame = TargetLike("TargetFrame", "target")
    FocusFrame = TargetLike("FocusFrame", "focus")
    FocusFrame.SetSmallSize = SetSmallSize
    PetFrame = G("Button", "PetFrame", UIParent, true)
    PetFrame.unit = "pet"
    for _, frame in ipairs({ PlayerFrame, TargetFrame, FocusFrame }) do OnSystemLoad(frame) end
end

-- EraUI ----------------------------------------------------------------------------
local settings = { enabled = true }
local E = { GetSetting = function(_, key) return settings[key] end }
local ns, modules
local function LoadEraUI()
    ns, modules = {}, {}
    E.Classic = ns
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.SafeCall = function(fn, ...) local ok, err = pcall(fn, ...); assert(ok, err); return ok end
    ns.QueueApply, ns.ApplyAll = function() end, function() end
    ns.MissingPiece = function() end
    Run(ERAUI, function()
        assert(loadfile("Classic/Textures.lua"))("EraUI", E)
        assert(loadfile("Classic/Skin.lua"))("EraUI", E)
        assert(loadfile("Classic/UnitFrames.lua"))("EraUI", E)
        -- After the unit frames, as in EraUI.toc: the cast bars read the elite
        -- flag they keep (ns.UnitFrameOwn) and hook the focus frame's own
        -- SetSmallSize.
        assert(loadfile("Classic/CastBars.lua"))("EraUI", E)
    end)
end
-- An event reaching EraUI's frames, and their OnUpdate checks: EraUI's code.
local function Fire(event, ...)
    for _, frame in ipairs(eraFrames) do
        local onEvent = S[frame].scripts.OnEvent
        if onEvent and S[frame].events[event] then Run(ERAUI, onEvent, frame, event, ...) end
    end
end
local function Tick()
    for _, frame in ipairs(eraFrames) do
        local onUpdate = S[frame].scripts.OnUpdate
        if onUpdate then Run(ERAUI, onUpdate, frame, 0.3) end
    end
end

-- Every key on the game's objects that carries EraUI's taint, "Owner.key".
local function TaintedKeys()
    local out = {}
    for _, obj in ipairs(gameObjects) do
        for key, taint in pairs(T[obj]) do
            if taint then
                local keyName = (type(key) == "table" and S[key] and S[key].name) or tostring(key)
                out[#out + 1] = tostring(S[obj].name or S[obj].kind) .. "." .. keyName
            end
        end
    end
    table.sort(out)
    return table.concat(out, ",")
end
local function Unique(list)
    local seen, out = {}, {}
    for _, item in ipairs(list) do if not seen[item] then seen[item] = true; out[#out + 1] = item end end
    return table.concat(out, ",")
end
local function Point(frame)
    local p = S[frame].points[1]
    local rel = p and p[2]
    return p and string.format("%s %s %s %.2f %.2f", p[1], rel and S[rel] and S[rel].name or tostring(rel), p[3], p[4], p[5]) or "none"
end
-- Where the frame's top left sits on the screen, in UIParent units (the
-- anchor's offset times the frame's scale), for the anchors used here.
local function OnScreen(frame)
    local p = S[frame].points[1]
    if not p then return "none" end
    return string.format("%.2f %.2f", p[4] * S[frame].scale, p[5] * S[frame].scale)
end
-- Two screen spots within the half pixel EraUI's pixel snapping may move a
-- frame by.
local function Near(a, b)
    local ax, ay = a:match("^(%S+) (%S+)$")
    local bx, by = b:match("^(%S+) (%S+)$")
    if not ax or not bx then return false end
    return math.abs(tonumber(ax) - tonumber(bx)) <= 0.5 and math.abs(tonumber(ay) - tonumber(by)) <= 0.5
end

-- One session: the game loads and applies the layout (the small focus),
-- EraUI styles the frames and runs on events and its checks; then a fight
-- where EraUI keeps running, asks for a pass, and the player levels up: the
-- game re-applies the layout in the fight. meddle: what else EraUI's code
-- does once before the fight (the mock's own checks).
local function Session(opts)
    refused, combat = {}, false
    focusTo = opts.focusTo
    settings.matchFocusSize = opts.match
    Run(nil, BuildGame)
    Run(nil, UpdateLayoutInfo, true)
    local before = { focus = Point(FocusFrame), screen = OnScreen(FocusFrame), scale = S[FocusFrame].scale }
    LoadEraUI()
    if not opts.noEraUI then
        Run(ERAUI, modules.unitFrames.apply)
        Run(ERAUI, modules.castBars.apply)
        Fire("PLAYER_ENTERING_WORLD")
        Fire("PLAYER_TARGET_CHANGED")
        Fire("PLAYER_FOCUS_CHANGED")
        Tick()
    end
    if opts.meddle then Run(ERAUI, opts.meddle) end
    local result = { before = before, outOfFight = Unique(refused) }
    result.styled = {
        scale = S[FocusFrame].scale, targetScale = S[TargetFrame].scale, point = Point(FocusFrame),
        screen = OnScreen(FocusFrame), small = V[FocusFrame].smallSize, tot = S[FocusFrame.totFrame].scale,
        font = S[FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.HealthBar.TextString].font,
        targetCast = Point(TargetFrame.spellbar), focusCast = Point(FocusFrame.spellbar),
        focusCastScale = S[FocusFrame.spellbar].scale,
    }
    combat = true
    if not opts.noEraUI then
        Fire("PLAYER_REGEN_DISABLED")
        Fire("UNIT_HEALTH", "focus")
        Tick()
        -- The target and the focus start casting: the game places their cast
        -- bars (EraUI's post-hook places them again).
        Run(nil, function()
            TargetFrame.spellbar:AdjustPosition()
            FocusFrame.spellbar:AdjustPosition()
        end)
        result.castInFight = Point(TargetFrame.spellbar) .. "|" .. Point(FocusFrame.spellbar)
        Run(ERAUI, modules.unitFrames.apply) -- a pass asked for in the fight
        Run(ERAUI, modules.castBars.apply)
        Fire("PLAYER_LEVEL_UP")
    end
    -- The level-up's re-apply, in the fight. dirtyInFight: a changed layout,
    -- so the game also runs its own FocusFrame:SetSmallSize(true) there (the
    -- cast bars' post-hook runs after it).
    Run(nil, UpdateLayoutInfo, opts.dirtyInFight and true or false)
    Tick()
    Fire("PLAYER_LEVEL_CHANGED")
    Run(nil, UpdateLayoutInfo, false) -- and once more, after EraUI's handlers
    result.auraTaint = GameReads(FocusFrame, AURA_READS)
    result.inFight = Unique(refused)
    result.keys = TaintedKeys()
    result.snapSecure = T[FocusFrame].snappedToFrame == nil
    combat = false
    Fire("PLAYER_REGEN_ENABLED")
    result.after = { point = Point(FocusFrame), screen = OnScreen(FocusFrame), scale = S[FocusFrame].scale }
    return result
end

-- 1. The user's case: Foreverskin (focus snapped to the player frame), small
--    focus, Match Focus Size on --------------------------------------------------
local r = Session({ focusTo = "PlayerFrame", match = true })
equal(r.before.focus, "TOPLEFT PlayerFrame BOTTOMLEFT 6.00 35.33", "the game puts the small focus on its saved spot")
equal(r.before.scale, 0.75, "Edit Mode's small focus")
equal(r.outOfFight, "", "nothing refused out of the fight")
equal(r.inFight, "", "the layout re-applied in the fight: nothing refused (was FocusFrame:SetPointBase())")
equal(r.keys, "", "no key on the game's frames carries EraUI's taint")
equal(r.snapSecure, true, "the focus's snap record is the game's own")
equal(r.auraTaint, nil, "the game's aura and cast bar reads on the focus in a fight are all the game's")
equal(r.styled.scale .. " " .. r.styled.targetScale, "1 1", "Match Focus Size: the focus at the target's scale")
equal(Near(r.styled.screen, r.before.screen), true, "where it was on the screen (" .. r.styled.screen .. ")")
equal(r.styled.point:sub(1, 30), "TOPLEFT PlayerFrame BOTTOMLEFT", "still on the player frame")
equal(r.styled.small, true, "the game's small mode left as the game set it")
equal(r.styled.tot, 1, "its target of target back at scale 1, as with the large focus")
equal(r.styled.font, TextStatusBarText, "its health text in the target frame's font")
equal(r.after.scale, 1, "after the fight: still the target's scale")
equal(ns.UnitFrameOwn(TargetFrame, "haveElite"), true, "an elite target's art flag, kept beside the frame")
equal(V[TargetFrame].haveElite, nil, "and not on it")
equal(ns.UnitFrameOwn(FocusFrame, "lastClassification"), "normal", "the focus's classification, kept beside the frame")
equal(type(ns.UnitFrameOwn(PlayerFrame, "host")), "table", "the player frame's bar host, kept beside the frame")
equal(V[PlayerFrame].fcui, nil, "no fcui table on the player frame")
equal(V[FocusFrame.totFrame].fcui, nil, "nor on the focus's target of target")
-- The cast bars (Classic/CastBars.lua Position): the elite flag now comes
-- from the unit frames' own table, the focus's bar at scale 1 from the game's
-- small mode, and the same spots after the game places them in a fight.
equal(r.styled.targetCast, "TOPLEFT TargetFrame BOTTOMLEFT 43.00 -9.00", "an elite target's cast bar below the dragon art")
equal(r.styled.focusCast, "TOPLEFT FocusFrame BOTTOMLEFT 43.00 3.00", "the focus's cast bar in its usual spot")
equal(r.styled.focusCastScale, 1, "the focus's cast bar at scale 1, not the small mode's 1.333")
equal(r.castInFight, "TOPLEFT TargetFrame BOTTOMLEFT 43.00 -9.00|TOPLEFT FocusFrame BOTTOMLEFT 43.00 3.00",
    "casts in the fight: the game places both bars, EraUI's hook puts them back")

-- 2. Match Focus Size off (the game's small focus as is) ----------------------------
r = Session({ focusTo = "PlayerFrame", match = false })
equal(r.inFight .. "|" .. r.keys, "|", "Match Focus Size off: nothing refused, no tainted key")
equal(r.styled.scale, 0.75, "the focus keeps the game's small scale")
equal(r.styled.font, TextStatusBarTextLarge, "and the game's font for it")

-- 3. The EraUI and 11111111 layouts (focus anchored to the screen) -----------------
r = Session({ focusTo = "UIParent", match = true })
equal(r.inFight .. "|" .. r.keys, "|", "focus on the screen: nothing refused, no tainted key")
equal(Near(r.styled.screen, r.before.screen), true, "the larger focus stays where it was (" .. r.styled.screen .. ")")

-- A changed layout re-applied in the fight: the game runs its own
-- FocusFrame:SetSmallSize(true) there, and the cast bars' post-hook on it
-- runs as EraUI right after.
r = Session({ focusTo = "PlayerFrame", match = true, dirtyInFight = true })
equal(r.inFight .. "|" .. r.keys, "|", "a changed layout in the fight: nothing refused, no tainted key")
equal(r.snapSecure, true, "and the focus's snap record still the game's own")

-- 4. The mock itself: what 1.6.0 and the version before it did -----------------------
-- 1.6.0's Match Focus Size ran the game's FocusFrame:SetSmallSize(false) as
-- EraUI: the snap record and a dozen keys carry EraUI's taint, and the
-- re-apply in the fight is refused, as in the report.
local function Old160() FocusFrame:SetSmallSize(false) end
r = Session({ focusTo = "PlayerFrame", match = false, noEraUI = true, meddle = Old160 })
equal(r.inFight, "FocusFrame:SetPointBase()", "1.6.0's SetSmallSize from EraUI: the report's refusal")
equal(r.snapSecure, false, "its snap record carries EraUI's taint")
equal(r.keys:find("FocusFrame.snappedToFrame", 1, true) ~= nil and r.keys:find("PlayerFrame.snappedFrames.FocusFrame", 1, true) ~= nil
    and r.keys:find("EditModeManagerFrame.editModeSystemAnchorDirty", 1, true) ~= nil, true,
    "the record on both frames and Edit Mode's dirty flag")
equal(r.auraTaint, ERAUI, "and the game's aura update on the focus would run as EraUI")
-- With the focus anchored to the screen there is no record to taint: no
-- refusal at the re-apply (so the user's layout was the snapped one).
r = Session({ focusTo = "UIParent", match = false, noEraUI = true, meddle = Old160 })
equal(r.inFight, "", "focus on the screen: the same call leaves no record to read")
-- Before 1.6.0, pixel snapping moved the focus with its own SetPoint (Edit
-- Mode's override) from EraUI's code: refused the same way.
r = Session({ focusTo = "PlayerFrame", match = false, noEraUI = true,
    meddle = function() FocusFrame:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 6, 35) end })
equal(r.inFight, "FocusFrame:SetPointBase()", "the SetPoint override from EraUI: refused too")
-- The plain base methods EraUI uses leave no record.
r = Session({ focusTo = "PlayerFrame", match = false, noEraUI = true,
    meddle = function() FocusFrame:SetScaleBase(1); FocusFrame:SetPointBase("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 4.5, 26.5) end })
equal(r.inFight .. "|" .. r.keys, "|", "SetScaleBase and SetPointBase from EraUI: nothing refused, no tainted key")

-- 5. EraUI's own moves never run in a fight -----------------------------------------
Session({ focusTo = "PlayerFrame", match = true })
combat = true
refused = {}
S[FocusFrame].scale = 0.75
Run(ERAUI, modules.unitFrames.apply)
equal(Unique(refused) .. " " .. S[FocusFrame].scale, " 0.75", "a pass in a fight: the focus is left alone, nothing refused")
combat = false
Run(ERAUI, modules.unitFrames.apply)
equal(Unique(refused) .. " " .. S[FocusFrame].scale, " 1", "the pass after it matches the size")

print("Focus taint checks passed: " .. checks .. " assertions.")
