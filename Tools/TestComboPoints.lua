-- Combo points on the real Classic/ComboPoints.lua and
-- Classic/FloatingComboPoints.lua against Forever's own ComboFrame
-- (Blizzard_UnitFrame/Camelot/ComboFrame.lua: five points numbered from 1,
-- laid round the portrait by the frame itself on every update, faded back in
-- with UIFrameFadeIn when you gain a point). Bug report 2026-10-11: with
-- Floating Combo Points off the target frame showed only four points (EraUI
-- assumed the older numbering from startComboPointIndex 2 and hid point 1);
-- with it on, the game's arc faded back in beside the floating row.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

-- A permissive widget: these methods keep state; any other method named with
-- one of these verbs is a no-op.
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Clear", "Start", "Stop", "Create" }
local Methods = {}
local function Widget(props)
    local w = props or {}
    w.alpha, w.shown, w.hooks, w.scripts, w.points = w.alpha or 1, w.shown ~= false, {}, {}, {}
    return setmetatable(w, { __index = function(_, key)
        if Methods[key] then return Methods[key] end
        if type(key) == "string" then
            for _, verb in ipairs(VERBS) do
                if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return function() end end
            end
        end
    end })
end
function Methods:SetAlpha(a) self.alpha = a end
function Methods:GetAlpha() return self.alpha end
function Methods:Show() self.shown = true; for _, fn in ipairs(self.hooks.OnShow or {}) do fn(self) end end
function Methods:Hide() self.shown = false end
function Methods:IsShown() return self.shown end
function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
function Methods:HookScript(name, fn) self.hooks[name] = self.hooks[name] or {}; table.insert(self.hooks[name], fn) end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Methods:GetFrameLevel() return 1 end
function Methods:CreateTexture() return Widget() end
function Methods:CreateFontString() return Widget() end
function Methods:IsMouseOver() return false end

CreateFrame = function() return Widget() end
hooksecurefunc = function(object, method, hook)
    if type(object) == "string" then object, method, hook = _G, object, method end
    local original = object[method]
    object[method] = function(...) local a, b = original(...); hook(...); return a, b end
end
InCombatLockdown = function() return false end
UnitPowerMax = function() return 5 end
UnitPower = function() return 2 end
UnitClass = function() return "Rogue", "ROGUE" end
UnitPowerType = function() return 3 end
UnitExists = function() return true end
UnitCanAttack = function() return true end
Enum = { PowerType = { ComboPoints = 4 } }
UIParent = Widget()
EraUIDB = {}

-- Forever's ComboFrame: five points from 1, its own circle, a fade-in that
-- raises the frame's alpha (not the points') when points arrive.
local function ForeverComboFrame()
    local cf = Widget({ alpha = 0, shown = false })
    cf.ComboPoints = {}
    for i = 1, 5 do cf.ComboPoints[i] = Widget({ layoutIndex = i }) end
    function cf:LayoutPointsCircle()
        for i, point in ipairs(self.ComboPoints) do point:ClearAllPoints(); point:SetPoint("CENTER", self, "CENTER", i, i) end
    end
    function cf:Update()
        self:LayoutPointsCircle()
        for _, point in ipairs(self.ComboPoints) do point:Show() end
        if not self:IsShown() then self:Show(); self:SetAlpha(1) end -- UIFrameFadeIn's end result
    end
    return cf
end

local settings = { floatingComboPoints = false }
local E = { modules = {} }
function E:GetSetting(key) return settings[key] end
function E:SaveSettings() end
function E:Print() end
local ns, module = {}, nil
E.Classic = ns
function ns.RegisterModule(_, m) module = m end
function ns.Path(root) return root end
function ns.SetTex() end
function ns.MissingPiece() end
function ns.Fade() end
function ns.Unfade() end

TargetFrame = Widget()
ComboFrame = ForeverComboFrame()
assert(loadfile("Classic/FloatingComboPoints.lua"))("EraUI", E)
assert(loadfile("Classic/ComboPoints.lua"))("EraUI", E)

local function Visible(cf)
    local n = 0
    if cf.alpha == 0 or not cf.shown then return 0 end
    for _, point in ipairs(cf.ComboPoints) do if point.shown and point.alpha > 0 then n = n + 1 end end
    return n
end

-- Floating off: all five of the game's points show, where the game put them.
module.apply()
ComboFrame:Update()
equal(Visible(ComboFrame), 5, "floating off: all five points show on the target frame")
equal(ComboFrame.ComboPoints[1].alpha, 1, "point 1 (the lowest in the arc) is not hidden")
equal(ComboFrame.ComboPoints[1].points[1][4], 1, "Forever's own circle keeps its place for each point")

-- Floating on: the game's arc stays out of sight even after it fades back in.
settings.floatingComboPoints = true
module.apply()
ComboFrame:Hide()
ComboFrame:Update()
equal(Visible(ComboFrame), 0, "floating on: the game's arc stays hidden when it fades back in")

-- Floating off again: everything comes back.
settings.floatingComboPoints = false
module.restore()
module.apply()
ComboFrame:Hide()
ComboFrame:Update()
equal(Visible(ComboFrame), 5, "floating off again: all five points show")

-- An older ComboFrame numbered from startComboPointIndex 2 (six slots) keeps
-- EraUI's own arc: its first slot hidden, the next five pinned and shown.
local old = Widget()
old.startComboPointIndex = 2
old.ComboPoints = {}
for i = 1, 6 do old.ComboPoints[i] = Widget() end
ComboFrame = old
module.apply()
equal(old.ComboPoints[1].alpha, 0, "older frame: slot 1 (unused) hidden")
local shown = 0
for i = 2, 6 do if old.ComboPoints[i].alpha == 1 then shown = shown + 1 end end
equal(shown, 5, "older frame: its five points shown")

print("Combo point checks passed: " .. checks .. " assertions.")
