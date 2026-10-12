-- Clean Minimap (Modules/MinimapTools.lua) on a mock game: the Hover style
-- exactly as before, and the Drawer style. Discovery (LibDBIcon buttons,
-- Squirt's buttons and other addons' minimap buttons; never the game's,
-- EraUI's own drawer pieces, map markers, protected or forbidden frames),
-- the drawer opening and closing (its button, a second click, Escape, a
-- click elsewhere, with or without the game's mouse-down event), the grid
-- by icons per row, Arrange's drag to reorder (saved by name and restored
-- after a reload, new buttons at the end, missing ones skipped), buttons
-- given back exactly when the style, Clean Minimap or EraUI is turned off
-- (and at log out), reparenting only out of combat, an addon re-placing or
-- taking back its own button, and no key or script written on any frame
-- that isn't EraUI's. The mock keeps every frame's state in its own table,
-- so a frame's own keys show exactly what was written on it.
local checks = 0
local function equal(got, want, label)
 checks = checks + 1
 assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
local function near(got, want, label) equal(type(got) == "number" and math.abs(got - want) < .01, true, label .. " (" .. tostring(got) .. " vs " .. tostring(want) .. ")") end
unpack = table.unpack or unpack

local W, H = 1920, 1080
local S -- the mock world
local methods = {}
local function St(f)
 local s = S.state[f]
 assert(s, "not a mock frame")
 if s.forbidden then error("touched a forbidden frame") end
 return s
end
-- The game refuses addon changes to protected frames; EraUI never makes
-- any to the game's own minimap frames, and none to another addon's
-- buttons in combat. setup lifts the rules while the world is built.
local function Mutate(f, what)
 local s = St(f)
 if S.setup then return s end
 if s.protected then error("changed a protected frame: " .. what) end
 if s.blizzard then error("changed the game's frame " .. tostring(s.name) .. ": " .. what) end
 if what == "SetParent" and s.foreign and S.combat then error("reparented " .. tostring(s.name) .. " in combat") end
 return s
end
local function New(kind, name, parent, template)
 local f = setmetatable({}, {__index = methods})
 local ps = parent and S.state[parent]
 S.state[f] = {kind = kind, name = name, parent = parent, children = {}, regions = {}, points = {}, scripts = {}, hooks = {},
  events = {}, w = 0, h = 0, scale = 1, alpha = 1, mouse = kind == "Button", shown = true,
  strata = ps and ps.strata or "MEDIUM", level = ps and ps.level + 1 or 0, template = template, text = "", writes = 0}
 if parent and (kind ~= "Texture" and kind ~= "FontString") then table.insert(ps.children, f) end
 if name then _G[name] = f end
 S.frames[#S.frames + 1] = f
 return f
end
function methods:GetObjectType() return St(self).kind end
function methods:IsObjectType(kind) return St(self).kind == kind end
function methods:IsForbidden() return S.state[self].forbidden == true end
function methods:IsProtected() return St(self).protected == true, false end
function methods:GetName() return St(self).name end
function methods:GetParent() return St(self).parent end
function methods:GetChildren() return unpack(St(self).children) end
function methods:SetParent(parent)
 local s = Mutate(self, "SetParent")
 if s.parent then
  local list = S.state[s.parent].children
  for i, child in ipairs(list) do if child == self then table.remove(list, i); break end end
 end
 s.parent = parent
 if parent then
  local ps = S.state[parent]
  table.insert(ps.children, self)
  -- As in the client: a frame takes its new parent's strata and goes above
  -- it, unless its strata or level is fixed.
  if not s.fixedStrata then s.strata = ps.strata end
  if not s.fixedLevel then s.level = ps.level + 1 end
 end
 s.writes = s.writes + 1
end
-- A fixed strata or level can't be changed until it's let go of (the game's
-- own code lets go, sets, and fixes it again).
function methods:GetFrameStrata() return St(self).strata end
function methods:SetFrameStrata(strata) local s = Mutate(self, "SetFrameStrata"); if not s.fixedStrata then s.strata = strata end end
function methods:GetFrameLevel() return St(self).level end
function methods:SetFrameLevel(level) local s = Mutate(self, "SetFrameLevel"); if not s.fixedLevel then s.level = level end end
function methods:HasFixedFrameStrata() return St(self).fixedStrata == true end
function methods:HasFixedFrameLevel() return St(self).fixedLevel == true end
function methods:SetFixedFrameStrata(on) local s = Mutate(self, "SetFixedFrameStrata"); s.fixedStrata = on and true or false end
function methods:SetFixedFrameLevel(on) local s = Mutate(self, "SetFixedFrameLevel"); s.fixedLevel = on and true or false end
function methods:Raise() end
function methods:SetSize(w, h) local s = Mutate(self, "SetSize"); s.w, s.h = w, h end
function methods:SetWidth(w) local s = Mutate(self, "SetWidth"); s.w = w end
function methods:SetHeight(h) local s = Mutate(self, "SetHeight"); s.h = h end
function methods:GetWidth() return St(self).w end
function methods:GetHeight() return St(self).h end
function methods:GetSize() local s = St(self); return s.w, s.h end
function methods:SetScale(scale) local s = Mutate(self, "SetScale"); s.scale = scale end
function methods:GetScale() return St(self).scale end
function methods:GetEffectiveScale()
 local s = St(self)
 return s.scale * (s.parent and s.parent:GetEffectiveScale() or 1)
end
function methods:SetAlpha(alpha) local s = Mutate(self, "SetAlpha"); s.alpha = alpha end
function methods:GetAlpha() return St(self).alpha end
function methods:EnableMouse(on) local s = Mutate(self, "EnableMouse"); s.mouse = on and true or false end
function methods:IsMouseEnabled() return St(self).mouse end
function methods:SetClampedToScreen() end
function methods:SetHitRectInsets() end
function methods:SetMovable() end
function methods:ClearAllPoints() local s = Mutate(self, "ClearAllPoints"); s.points, s.all = {}, nil end
function methods:SetPoint(point, relative, relativePoint, x, y)
 local s = Mutate(self, "SetPoint")
 if type(relative) == "number" then relative, relativePoint, x, y = nil, point, relative, relativePoint end
 relativePoint = relativePoint or point
 local entry = {point, relative or s.parent, relativePoint, x or 0, y or 0}
 for i, p in ipairs(s.points) do if p[1] == point then s.points[i] = entry; return end end
 s.points[#s.points + 1] = entry
end
function methods:SetAllPoints(relative) local s = Mutate(self, "SetAllPoints"); s.points, s.all = {}, relative or s.parent end
function methods:GetNumPoints() return #St(self).points end
function methods:GetPoint(i)
 local p = St(self).points[i or 1]
 if p then return p[1], p[2], p[3], p[4], p[5] end
end
-- Where a frame is on the screen (pixels, UIParent's scale is 1): its first
-- point only, as every frame here has.
local function Has(point, part) return point:find(part, 1, true) ~= nil end
local function Rect(f, depth)
 depth = (depth or 0) + 1
 assert(depth < 30, "anchor loop")
 if f == UIParent then return 0, 0, W, H end
 local s = St(f)
 if s.all then return Rect(s.all, depth) end
 local p = s.points[1]
 if not p then return end
 local l, b, r, t = Rect(p[2], depth)
 if not l then return end
 local ax = Has(p[3], "LEFT") and l or Has(p[3], "RIGHT") and r or (l + r) / 2
 local ay = Has(p[3], "TOP") and t or Has(p[3], "BOTTOM") and b or (b + t) / 2
 local eff = f:GetEffectiveScale()
 ax, ay = ax + p[4] * eff, ay + p[5] * eff
 local w, h = s.w * eff, s.h * eff
 local left = Has(p[1], "LEFT") and ax or Has(p[1], "RIGHT") and ax - w or ax - w / 2
 local bottom = Has(p[1], "BOTTOM") and ay or Has(p[1], "TOP") and ay - h or ay - h / 2
 return left, bottom, left + w, bottom + h
end
function methods:GetCenter()
 local l, b, r, t = Rect(self)
 if not l then return end
 local eff = self:GetEffectiveScale()
 return (l + r) / 2 / eff, (b + t) / 2 / eff
end
function methods:GetLeft() local l = Rect(self); return l and l / self:GetEffectiveScale() end
function methods:GetRight() local _, _, r = Rect(self); return r and r / self:GetEffectiveScale() end
function methods:GetTop() local _, _, _, t = Rect(self); return t and t / self:GetEffectiveScale() end
function methods:GetBottom() local _, b = Rect(self); return b and b / self:GetEffectiveScale() end
-- Screen centre in pixels.
local function Screen(f) local l, b, r, t = Rect(f); return (l + r) / 2, (b + t) / 2 end
function methods:IsShown() return St(self).shown end
function methods:IsVisible()
 local s = St(self)
 return s.shown and (not s.parent or s.parent:IsVisible())
end
function methods:Fire(event, ...)
 local s = St(self)
 if s.scripts[event] then s.scripts[event](self, ...) end
 for _, fn in ipairs(s.hooks[event] or {}) do fn(self, ...) end
end
function methods:Show() local s = Mutate(self, "Show"); if not s.shown then s.shown = true; self:Fire("OnShow") end end
function methods:Hide() local s = Mutate(self, "Hide"); if s.shown then s.shown = false; self:Fire("OnHide") end end
function methods:SetShown(on) if on then self:Show() else self:Hide() end end
function methods:IsMouseOver()
 if not self:IsVisible() then return false end
 local l, b, r, t = Rect(self)
 return l ~= nil and S.cx >= l and S.cx <= r and S.cy >= b and S.cy <= t
end
function methods:SetScript(event, fn) local s = Mutate(self, "SetScript"); s.scripts[event] = fn end
function methods:GetScript(event) return St(self).scripts[event] end
function methods:HasScript() return true end
function methods:HookScript(event, fn)
 local s = St(self)
 s.hooks[event] = s.hooks[event] or {}
 table.insert(s.hooks[event], fn)
end
function methods:RegisterEvent(event)
 if event == "GLOBAL_MOUSE_DOWN" and S.noGlobalMouse then error("unknown event " .. event) end
 St(self).events[event] = true
end
function methods:UnregisterEvent(event) St(self).events[event] = nil end
function methods:RegisterForClicks() end
function methods:RegisterForDrag(...) St(self).drag = {...} end
function methods:Click(button) self:Fire("OnClick", button or "LeftButton") end
function methods:SetBackdrop(backdrop) St(self).backdrop = backdrop end
function methods:SetBackdropColor(...) St(self).fill = {...} end
function methods:SetBackdropBorderColor(...) St(self).border = {...} end
function methods:CreateTexture(_, layer)
 local t = New("Texture", nil, self)
 table.insert(St(self).regions, t)
 S.state[t].layer = layer
 return t
end
function methods:CreateFontString(_, layer, font)
 local t = New("FontString", nil, self)
 table.insert(St(self).regions, t)
 S.state[t].layer, S.state[t].font = layer, font
 return t
end
function methods:SetTexture(path) St(self).texture = path; return true end
function methods:SetColorTexture(...) St(self).colour = {...} end
function methods:SetVertexColor(...) St(self).vertex = {...} end
function methods:SetTexCoord() end
function methods:SetDrawLayer() end
function methods:SetBlendMode() end
function methods:SetNormalTexture(path)
 local s = St(self)
 s.normal = s.normal or self:CreateTexture(nil, "ARTWORK")
 s.normal:SetTexture(path)
end
function methods:GetNormalTexture() return St(self).normal end
function methods:SetHighlightTexture(path) St(self).highlight = path end
function methods:SetFont() end
function methods:SetFontObject() end
function methods:SetJustifyH() end
function methods:SetWordWrap() end
function methods:SetTextColor(...) St(self).textColour = {...} end
function methods:SetText(text) St(self).text = text or "" end
function methods:SetFormattedText(format, ...) St(self).text = string.format(format, ...) end
function methods:GetText() return St(self).text end
function methods:GetStringWidth()
 local widest = 0
 for line in (St(self).text .. "\n"):gmatch("(.-)\n") do widest = math.max(widest, #line * 6) end
 return widest
end
function methods:GetStringHeight()
 local lines = 0
 for _ in (St(self).text .. "\n"):gmatch("(.-)\n") do lines = lines + 1 end
 return lines * 12
end

-- The world ---------------------------------------------------------------------

-- A button of another addon round the minimap, at an angle (degrees).
local RING = 74
local function AddonButton(name, angle, parent, size)
 local button = New("Button", name, parent or Minimap)
 local s = S.state[button]
 s.foreign, s.w, s.h, s.strata, s.level = true, size or 32, size or 32, "MEDIUM", 8
 button:SetPoint("CENTER", Minimap, "CENTER", math.cos(math.rad(angle)) * RING, math.sin(math.rad(angle)) * RING)
 s.clicks = 0
 button:SetScript("OnClick", function() s.clicks = s.clicks + 1 end)
 -- Its own drag round the minimap, as Squirt's buttons and the library's do.
 s.drags = 0
 button:SetScript("OnDragStart", function(self) s.drags = s.drags + 1; rawset(self, "isMoving", true) end)
 button:SetScript("OnDragStop", function(self) rawset(self, "isMoving", nil) end)
 button:SetScript("OnEnter", function() end)
 button:SetScript("OnLeave", function() end)
 return button
end
local function GameButton(name, parent, x, y, w, h)
 local button = New("Button", name, parent)
 local s = S.state[button]
 s.blizzard, s.w, s.h = true, w or 32, h or 32
 button:SetPoint("CENTER", Minimap, "CENTER", x, y)
 button:SetScript("OnClick", function() end)
 return button
end

-- What each frame looked like, to compare after: its own keys (nothing of
-- EraUI's may land on it), its scripts and hooks, and its place.
local function Snapshot(f)
 local s = S.state[f]
 local keys = {}
 for k, v in pairs(f) do keys[k] = v end
 local scripts, hooks = {}, {}
 for k, v in pairs(s.scripts) do scripts[k] = v end
 for k, v in pairs(s.hooks) do hooks[k] = #v end
 local points = {}
 for i, p in ipairs(s.points) do points[i] = {p[1], p[2], p[3], p[4], p[5]} end
 return {keys = keys, scripts = scripts, hooks = hooks, points = points, parent = s.parent, strata = s.strata, level = s.level,
  shown = s.shown, scale = s.scale, alpha = s.alpha, mouse = s.mouse, fixed = tostring(s.fixedStrata) .. "/" .. tostring(s.fixedLevel)}
end
local function PointsText(points)
 local out = {}
 for i, p in ipairs(points) do out[i] = table.concat({p[1], tostring(S.state[p[2]] and S.state[p[2]].name or p[2]), p[3], string.format("%.2f", p[4]), string.format("%.2f", p[5])}, " ") end
 return table.concat(out, "; ")
end

local E, M, fired
local function Session(settings, build)
 S = {state = setmetatable({}, {__mode = "k"}), frames = {}, timers = {}, combat = false, now = 100, cx = 10, cy = 10,
  setup = true, noGlobalMouse = settings and settings.noGlobalMouse}
 UISpecialFrames = {}
 UIParent = New("Frame", "UIParent")
 S.state[UIParent].w, S.state[UIParent].h, S.state[UIParent].blizzard = W, H, true
 MinimapCluster = New("Frame", "MinimapCluster", UIParent)
 local cluster = S.state[MinimapCluster]
 cluster.blizzard, cluster.w, cluster.h, cluster.strata, cluster.level = true, 192, 192, "LOW", 1
 -- A bigger minimap (Edit Mode's size), so its scale isn't the screen's.
 cluster.scale = 1.25
 MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
 Minimap = New("Frame", "Minimap", MinimapCluster)
 S.state[Minimap].blizzard, S.state[Minimap].w, S.state[Minimap].h = true, 140, 140
 Minimap:SetPoint("CENTER", MinimapCluster, "CENTER", 9, 4)
 MinimapBackdrop = New("Frame", "MinimapBackdrop", Minimap)
 S.state[MinimapBackdrop].blizzard, S.state[MinimapBackdrop].w, S.state[MinimapBackdrop].h = true, 192, 192
 MinimapBackdrop:SetPoint("CENTER", Minimap, "CENTER", -9, -24)
 -- The game's own: zoom (unnamed, and the older clients' named one), the
 -- clock, the calendar, tracking, the expansion button, the add-on
 -- compartment, the queue eye.
 Minimap.ZoomIn = GameButton(nil, MinimapBackdrop, 63, -49)
 Minimap.ZoomOut = GameButton(nil, MinimapBackdrop, 41, -67)
 GameButton("MinimapZoomIn", Minimap, 70, -20)
 GameButton("GameTimeFrame", Minimap, 70, 48, 40, 40)
 GameButton("TimeManagerClockButton", Minimap, 0, -75, 60, 28)
 GameButton("MiniMapTrackingButton", Minimap, -80, 11)
 GameButton("ExpansionLandingPageMinimapButton", MinimapBackdrop, -60, -60)
 GameButton("AddonCompartmentFrame", MinimapCluster, 60, 80)
 GameButton("QueueStatusButton", UIParent, -66, -44)
 MinimapCluster.Tracking = GameButton(nil, MinimapBackdrop, -80, 11)
 -- Squirt's buttons, the library's, and other addons' on the minimap.
 local made = {}
 local function Add(name, angle, parent, size)
  local button = AddonButton(name, angle, parent, size)
  made[name or "(unnamed)"] = button
  return button
 end
 Add("FECMMinimapButton", 160); Add("ClamOpenerMinimapButton", 140); Add("ForeverEnhancedPrivacyMinimapButton", 200)
 Add("FECursorMinimapButton", 250)
 -- Free-floating on the screen: not on the minimap, so it stays out.
 Add("FENMinimapButton", 0, UIParent)
 local lib = {objects = {}, callbacks = {}}
 function lib:GetButtonList() local list = {} for name in pairs(self.objects) do list[#list + 1] = name end table.sort(list) return list end
 function lib:GetMinimapButton(name) return self.objects[name] end
 function lib.RegisterCallback(target, event, method) lib.callbacks[event] = {target, method} end
 S.lib = lib
 -- The library fixes its buttons' strata and level.
 for _, name in ipairs(settings and settings.library or {"Alpha", "Zulu"}) do
  local button = Add("LibDBIcon10_" .. name, name == "Alpha" and 110 or 290, nil, 31)
  lib.objects[name] = button
  S.state[button].fixedStrata, S.state[button].fixedLevel = true, true
 end
 LibStub = setmetatable({}, {__call = function(_, name) if name == "LibDBIcon-1.0" then return lib end end})
 if not (settings and settings.noOther) then Add("OtherAddonMinimapButton", 30) end
 -- Not buttons: a map marker at the edge, one inside the map, an unnamed
 -- button at the edge; a protected button and a forbidden one.
 Add("TrackerMinimapPin7", 330)
 local inside = Add("InsideMarkButton", 0); inside:SetPoint("CENTER", Minimap, "CENTER", 10, 5)
 Add(nil, 60)
 S.state[Add("SecureThingMinimapButton", 80)].protected = true
 local forbidden = Add("ForbiddenMinimapButton", 100)
 if build then build(made) end
 S.state[forbidden].forbidden = true
 -- EraUI and the game around it.
 E = {modules = {}, settings = settings or {}, saves = 0}
 function E:RegisterModule(name, m) self.modules[name] = m end
 function E:GetSetting(key) return self.settings[key] end
 function E:SetSetting(key, value) self.settings[key] = value end
 function E:SaveSettings() self.saves = self.saves + 1 end
 S.texCalls, S.darkCalls = {}, {}
 E.Classic = {TEX = {trackingBorder = {}}, SetTex = function(t, key) S.texCalls[#S.texCalls + 1] = key; t:SetTexture("ring:" .. key); return true end,
  DarkBackdrop = function(frame) S.darkCalls[#S.darkCalls + 1] = frame end, ShowWelcome = function() end, OpenOptions = function() end}
 S.tooltip = 0
 GameTooltip = {SetOwner = function() S.tooltip = S.tooltip + 1 end, SetText = function() S.tooltip = S.tooltip + 1 end,
  AddLine = function(_, text) S.tooltip = S.tooltip + 1; S.tooltipLine = text end, Show = function() end, Hide = function() end}
 CreateFrame = function(kind, name, parent, template) return New(kind, name, parent, template) end
 InCombatLockdown = function() return S.combat end
 GetTime = function() return S.now end
 GetCursorPosition = function() return S.cx, S.cy end
 C_Timer = {After = function(_, fn) S.timers[#S.timers + 1] = fn end}
 hooksecurefunc = function() error("no secure hooks here") end
 -- The game's own frames, as they are now (nothing of EraUI's may change them).
 S.before = {}
 for _, f in ipairs(S.frames) do S.before[f] = Snapshot(f) end
 S.setup = false
 assert(loadfile("Modules/MinimapTools.lua"))("EraUI", E)
 M = E.modules.MinimapTools
 M:Initialize()
 return made
end
local function Flush()
 for _ = 1, 10 do
  if #S.timers == 0 then return end
  local pending = S.timers; S.timers = {}
  for _, fn in ipairs(pending) do fn() end
 end
 error("timers never settled")
end
local function Event(event, ...)
 for _, f in ipairs(S.frames) do
  local s = S.state[f]
  if s.events[event] and s.scripts.OnEvent and not s.forbidden then f:Fire("OnEvent", event, ...) end
 end
end
-- Escape: the game hides every shown window on its list.
local function Escape()
 for _, name in ipairs(UISpecialFrames) do
  local f = _G[name]
  if f and f:IsShown() then f:Hide() end
 end
end
local function Tick(dt) S.now = S.now + (dt or .1); M:Refresh() end
local function Panel() return M.drawer.panel end
local function DrawerButton() return M.drawer.button end
local function Names(list)
 local out = {}
 for i, f in ipairs(list) do out[i] = f:GetName() end
 return table.concat(out, ",")
end
local function Held(f) return f:GetParent() == Panel() end
-- Nothing of EraUI's on the frame, its scripts and hooks as they were
-- (the minimap's size hook is EraUI's, as before).
local function Untouched(f, label)
 local before = S.before[f]
 for k, v in pairs(f) do
  if k ~= "isMoving" then equal(before.keys[k], v, label .. ": no key written on " .. tostring(f:GetName()) .. " (" .. tostring(k) .. ")") end
 end
 local s = S.state[f]
 for k, v in pairs(before.scripts) do equal(s.scripts[k], v, label .. ": " .. tostring(f:GetName()) .. " keeps its " .. k) end
 for k, v in pairs(s.scripts) do equal(before.scripts[k], v, label .. ": no script set on " .. tostring(f:GetName()) .. " (" .. k .. ")") end
 for k, list in pairs(s.hooks) do
  local allowed = (f == Minimap and k == "OnSizeChanged") and 1 or 0
  equal(#list, (before.hooks[k] or 0) + allowed, label .. ": no hook on " .. tostring(f:GetName()) .. " " .. k)
 end
end
-- Exactly as it was: parent, points, strata, level, shown, scale. points:
-- where its addon placed it since it was lent, when it did.
local function Exact(f, label, points)
 local before, s = S.before[f], S.state[f]
 equal(s.parent, before.parent, label .. ": " .. f:GetName() .. " back on its parent")
 equal(PointsText(s.points), points or PointsText(before.points), label .. ": " .. f:GetName() .. " back on its points")
 equal(s.strata .. " " .. s.level, before.strata .. " " .. before.level, label .. ": " .. f:GetName() .. " its strata and level back")
 equal(tostring(s.shown) .. " " .. s.scale, tostring(before.shown) .. " " .. before.scale, label .. ": " .. f:GetName() .. " shown and scale unchanged")
 equal(tostring(s.fixedStrata) .. "/" .. tostring(s.fixedLevel), before.fixed, label .. ": " .. f:GetName() .. " fixed (or not) as its addon left it")
end

local SQUIRT = {"FECMMinimapButton", "ClamOpenerMinimapButton", "ForeverEnhancedPrivacyMinimapButton", "FECursorMinimapButton"}
local GAME = {"MinimapZoomIn", "GameTimeFrame", "TimeManagerClockButton", "MiniMapTrackingButton", "ExpansionLandingPageMinimapButton",
 "AddonCompartmentFrame", "QueueStatusButton"}
local DEFAULT_ORDER = "EraUIMinimapButton,ClamOpenerMinimapButton,FECMMinimapButton,FECursorMinimapButton,ForeverEnhancedPrivacyMinimapButton,"
 .. "LibDBIcon10_Alpha,LibDBIcon10_Zulu,OtherAddonMinimapButton"

-- Off: nothing happens -----------------------------------------------------------

local made = Session({})
equal(DrawerButton(), nil, "Clean Minimap off: no drawer is made")
for name, f in pairs(made) do
 if f ~= _G.ForbiddenMinimapButton then equal(S.state[f].alpha .. " " .. tostring(S.state[f].parent == S.before[f].parent), "1 true", "off: " .. name .. " untouched") end
end

-- Hide until hover: exactly as before ------------------------------------------------

made = Session({cleanMinimap = true})
S.cx, S.cy = 10, 10
Tick(1)
local registered = {"EraUIMinimapButton", "LibDBIcon10_Alpha", "LibDBIcon10_Zulu", unpack(SQUIRT)}
for _, name in ipairs(registered) do
 local s = S.state[_G[name]]
 equal(s.alpha .. " " .. tostring(s.mouse), "0 false", "Hover: " .. name .. " hidden until you hover the minimap")
end
equal(S.state[made.FENMinimapButton].alpha, 0, "Hover: a known Squirt button off the minimap hides too, as before")
equal(S.state[made.OtherAddonMinimapButton].alpha, 1, "Hover: an unlisted addon's button is left alone, as before")
equal(DrawerButton(), nil, "Hover: no drawer")
for _, name in ipairs(registered) do equal(Held(_G[name]), false, "Hover: " .. name .. " stays on the minimap") end
S.cx, S.cy = Screen(Minimap)
Tick(.1)
for _, name in ipairs(registered) do
 local s = S.state[_G[name]]
 equal(s.alpha .. " " .. tostring(s.mouse), "1 true", "Hover: " .. name .. " shown while you hover")
end
S.cx, S.cy = 10, 10
Tick(.3)
equal(S.state[made.FECMMinimapButton].alpha, 1, "Hover: still shown in the grace moment")
Tick(.5)
equal(S.state[made.FECMMinimapButton].alpha, 0, "Hover: hidden again after it")
rawset(made.FECMMinimapButton, "isMoving", true)
Tick(1)
equal(S.state[made.ClamOpenerMinimapButton].alpha, 1, "Hover: nothing fades while an addon's button is dragged")
rawset(made.FECMMinimapButton, "isMoving", nil)
Tick(1)
Event("ADDON_LOADED", "SomeAddon")
equal(#S.timers, 0, "Hover: no extra look after an addon loads, as before")
for _, f in ipairs(S.frames) do if S.before[f] and f ~= _G.ForbiddenMinimapButton then Untouched(f, "Hover") end end

-- Drawer: what goes in ------------------------------------------------------------

E.settings.cleanMinimapStyle = "drawer"
M:Discover(); M:Refresh()
local panel, drawer = Panel(), DrawerButton()
equal(panel ~= nil and drawer ~= nil, true, "Drawer: made")
equal(panel:GetName() .. " " .. drawer:GetName(), "EraUIMinimapDrawer EraUIMinimapDrawerButton", "the drawer and its button are EraUI's own, named")
equal(drawer:GetParent() == Minimap and drawer:IsShown(), true, "the drawer button is on the minimap")
-- Positions on the minimap in its own units (it's scaled; so is the drawer button).
local x, y = drawer:GetCenter()
local mx, my = Minimap:GetCenter()
near(x - mx, -.7071 * 74, "the drawer button starts bottom left on the edge (x)")
near(y - my, -.7071 * 74, "the drawer button starts bottom left on the edge (y)")
equal(Names(M.drawer.order), DEFAULT_ORDER, "in: EraUI's button, Squirt's, the library's and another addon's; EraUI's first, then by name")
for _, name in ipairs(GAME) do equal(Held(_G[name]), false, "out: the game's " .. name) end
equal(Held(Minimap.ZoomIn) or Held(Minimap.ZoomOut) or Held(MinimapCluster.Tracking), false, "out: the game's zoom and tracking")
for _, name in ipairs({"TrackerMinimapPin7", "InsideMarkButton", "SecureThingMinimapButton", "FENMinimapButton"}) do
 equal(Held(_G[name]), false, "out: " .. name)
end
equal(S.state[_G.ForbiddenMinimapButton].parent, Minimap, "out: a forbidden frame is never touched")
equal(Held(made["(unnamed)"]), false, "out: an unnamed button")
equal(Held(drawer), false, "out: the drawer button itself")
for _, name in ipairs(registered) do
 local s = S.state[_G[name]]
 equal(s.alpha .. " " .. tostring(s.mouse), "1 true", "Drawer: " .. name .. " shown as its addon left it (Hover's fade undone)")
end
Tick(1)
equal(S.state[made.ClamOpenerMinimapButton].alpha, 1, "Drawer: Hover's fade leaves buttons in the drawer alone")
equal(S.state[made.FENMinimapButton].alpha, 0, "Drawer: a known button left off the minimap still hides until hover")
rawset(made.ClamOpenerMinimapButton, "isMoving", true)
Tick(1)
equal(S.state[made.FENMinimapButton].alpha, 0, "Drawer: a button dragged in the drawer doesn't count as hovering the minimap")
rawset(made.ClamOpenerMinimapButton, "isMoving", nil)
M:Discover(); M:Refresh()
equal(Held(drawer), false, "a new look never takes the drawer button itself")
equal(panel:IsShown(), false, "the drawer starts closed")
equal(S.state[panel].events.GLOBAL_MOUSE_DOWN, nil, "closed: it doesn't listen for clicks")
equal(tostring(S.state[made.ClamOpenerMinimapButton].shown) .. " " .. tostring(made.ClamOpenerMinimapButton:IsVisible()), "true false",
 "closed: its buttons are out of sight, still shown by their addons")
-- The look: EraUI's ring (Dark Mode's grey through the theme), the classic dialog box.
equal(table.concat(S.texCalls, ","), "trackingBorder", "the drawer button's ring is EraUI's themed minimap ring")
equal(S.darkCalls[1], panel, "the drawer's box goes to Dark Windows for Dark Mode")
equal(S.state[panel].backdrop.edgeFile, "Interface\\DialogFrame\\UI-DialogBox-Border", "the classic dialog edge")

-- Its hover box: EraUI's own, never the game's tooltip.
S.tooltip = 0
drawer:Fire("OnEnter")
local hint = M.drawer.hint
equal(hint:IsShown() and S.state[hint.title].text .. " | " .. S.state[hint.body].text, "Addon buttons | Click: open or close\nDrag: move", "the hover box")
equal(S.tooltip, 0, "the game's tooltip is never used")
equal(St(hint).backdrop.edgeFile:find("EraUI\\Media\\TooltipBorder", 1, true) ~= nil and St(hint).backdrop.edgeSize == 16
 and table.concat(St(hint).fill, ",") == "0.016,0.016,0.02,0.9", true, "drawn like EraUI's tooltips: its border and dark fill")
equal(St(hint).points[1][1] .. " " .. St(hint).points[1][3], "BOTTOMRIGHT TOPLEFT", "to the left of the button, like the E button's")
drawer:Fire("OnLeave")
-- The dots: gold in the Classic look, light grey on a dark disc in Dark Mode.
do
 local function Dots()
  local out = {}
  for _, dot in ipairs(M.drawer.dots) do out[#out + 1] = table.concat(St(dot).colour, ",") end
  return #out .. " " .. out[1] .. " " .. table.concat(St(M.drawer.back).vertex, ",")
 end
 local was = E.settings.darkMode
 E.settings.darkMode = false; M:Refresh()
 equal(Dots(), "9 1,0.82,0.25,1 0.08,0.065,0.035", "Classic: nine gold dots on a brown disc")
 E.settings.darkMode = true; M:Refresh()
 equal(Dots(), "9 0.8,0.82,0.86,1 0.05,0.05,0.06", "Dark Mode: light grey dots on a neutral dark disc")
 E.settings.darkMode = was; M:Refresh()
end
equal(hint:IsShown(), false, "the hover box goes with the mouse")

-- Open, the grid, close ------------------------------------------------------------

drawer:Click()
equal(panel:IsShown(), true, "a click opens the drawer")
equal(S.state[panel].strata, "HIGH", "above the minimap")
-- Right next to the drawer button, out from the minimap, never over it (the
-- user: "button pop out is too far even if i moved the minimap icon it always
-- pops out there").
local function Overlap(a, b)
 local al, ab, ar, at = Rect(a)
 local bl, bb, br, bt = Rect(b)
 return al < br and bl < ar and ab < bt and bb < at
end
local function Gap(a, b)
 local al, ab, ar, at = Rect(a)
 local bl, bb, br, bt = Rect(b)
 return math.max(0, bl - ar, al - br, bb - at, ab - bt)
end
local p = S.state[panel].points[1]
equal(S.state[p[2]].name, "EraUIMinimapDrawerButton", "the drawer opens from its button")
equal(Overlap(panel, Minimap), false, "and never over the minimap")
equal(Gap(panel, drawer) <= 6, true, "right next to the button (" .. Gap(panel, drawer) .. ")")
do
 local pl, pb, pr, pt = Rect(panel)
 equal(pl >= 0 and pb >= 0 and pr <= W and pt <= H, true, "on the screen")
end
near(panel:GetEffectiveScale(), Minimap:GetEffectiveScale(), "at the minimap's own scale")
local function Grid(label, columns, count)
 local shown = M.drawer.shown
 equal(#shown, count, label .. ": " .. count .. " in the grid")
 local size, gap = 32, 4
 local across = math.min(columns, count)
 local gridWidth = across * size + (across - 1) * gap
 local width = math.max(176, gridWidth + 24)
 local rows = math.ceil(count / columns)
 near(panel:GetWidth(), width, label .. ": the panel's width")
 near(panel:GetHeight(), 32 + rows * size + (rows - 1) * gap + 12, label .. ": the panel's height")
 -- In the drawer's own units (it takes the minimap's scale).
 local left, top = panel:GetLeft(), panel:GetTop()
 for i, button in ipairs(shown) do
  local column, row = (i - 1) % columns, math.floor((i - 1) / columns)
  local bx, by = button:GetCenter()
  near(bx - left, (width - gridWidth) / 2 + column * (size + gap) + size / 2, label .. ": " .. button:GetName() .. " in column " .. (column + 1))
  near(top - by, 32 + row * (size + gap) + size / 2, label .. ": " .. button:GetName() .. " in row " .. (row + 1))
  equal(button:IsVisible() and S.state[button].strata, "HIGH", label .. ": " .. button:GetName() .. " shows in the drawer")
  equal(S.state[button].level, S.state[panel].level + 5, label .. ": " .. button:GetName() .. " above the drawer's box")
  local bl, bb, br, bt = Rect(button)
  local pl, pb, pr, pt = Rect(panel)
  equal(bl >= pl and br <= pr and bb >= pb and bt <= pt, true, label .. ": " .. button:GetName() .. " inside the drawer")
 end
end
Grid("five a row", 5, 8)
E.settings.minimapDrawerColumns = 3; M:LayoutDrawer()
Grid("three a row", 3, 8)
E.settings.minimapDrawerColumns = 8; M:LayoutDrawer()
Grid("eight a row", 8, 8)
E.settings.minimapDrawerColumns = 99; M:LayoutDrawer()
Grid("never more than eight", 8, 8)
E.settings.minimapDrawerColumns = nil; M:LayoutDrawer()
-- An addon's button works in the drawer: its own click.
made.ClamOpenerMinimapButton:Click()
equal(S.state[made.ClamOpenerMinimapButton].clicks, 1, "an addon's button clicks as ever in the drawer")
-- A second click closes it.
drawer:Click()
equal(panel:IsShown(), false, "a second click closes it")
-- Escape, through the game's own list (no key bound).
drawer:Click(); Escape()
equal(panel:IsShown(), false, "Escape closes it")
-- A click anywhere else; a click inside or on the drawer button doesn't.
drawer:Click()
S.cx, S.cy = Screen(panel); Event("GLOBAL_MOUSE_DOWN")
equal(panel:IsShown(), true, "a click inside keeps it open")
S.cx, S.cy = Screen(drawer); Event("GLOBAL_MOUSE_DOWN")
equal(panel:IsShown(), true, "pressing its button leaves the closing to the click")
drawer:Click()
equal(panel:IsShown(), false, "which closes it")
drawer:Click()
S.cx, S.cy = 300, 300; Event("GLOBAL_MOUSE_DOWN")
equal(panel:IsShown(), false, "a click anywhere else closes it")
equal(S.state[panel].events.GLOBAL_MOUSE_DOWN, nil, "closed: it no longer listens for clicks")
-- A game menu a button in the drawer opened (it closes once its button is
-- out of sight): a click on it leaves the drawer open, so the click lands.
local openMenu
Menu = {GetManager = function() return {GetOpenMenu = function() return openMenu end} end}
drawer:Click()
equal(S.state[panel].events.GLOBAL_MOUSE_DOWN, true, "open: it listens for clicks")
openMenu = {GetOwnerRegion = function() return made.LibDBIcon10_Zulu end}
S.cx, S.cy = 300, 300; Event("GLOBAL_MOUSE_DOWN")
equal(panel:IsShown(), true, "a click on a menu a drawer button opened leaves the drawer open")
S.setup = true; local part = made.ClamOpenerMinimapButton:CreateTexture(nil, "ARTWORK"); S.setup = false
openMenu = {GetOwnerRegion = function() return part end}
Event("GLOBAL_MOUSE_DOWN")
equal(panel:IsShown(), true, "the same for a menu owned by a part of a drawer button")
openMenu = {GetOwnerRegion = function() return Minimap end}
Event("GLOBAL_MOUSE_DOWN")
equal(panel:IsShown(), false, "a menu opened from anything else doesn't keep it open")
openMenu = nil
drawer:Click()
Event("GLOBAL_MOUSE_DOWN")
equal(panel:IsShown(), false, "with the menu closed, a click elsewhere closes it")
Menu = nil
-- A button its addon hides is left out of the grid, and back when shown.
drawer:Click()
S.setup = true; made.FECursorMinimapButton:Hide(); S.setup = false
panel:Fire("OnUpdate", .1)
equal(Names(M.drawer.shown):find("FECursor", 1, true), nil, "a button its addon hides leaves the grid")
Grid("one hidden", 5, 7)
S.setup = true; made.FECursorMinimapButton:Show(); S.setup = false
panel:Fire("OnUpdate", .1)
Grid("shown again", 5, 8)
equal(Names(M.drawer.shown), DEFAULT_ORDER, "back in its turn")
-- An addon putting its button back on the minimap's edge (as the library's
-- refresh does) while the drawer is open: back in its slot at once.
local alpha = made.LibDBIcon10_Alpha
local ax, ay = Screen(alpha)
S.setup = true; alpha:ClearAllPoints(); alpha:SetPoint("CENTER", Minimap, "CENTER", 0, 74); S.setup = false
panel:Fire("OnUpdate", .1)
local bx, by = Screen(alpha)
near(bx, ax, "re-placed by its addon: back in its slot (x)"); near(by, ay, "and (y)")
-- Dragged by its own script (outside Arrange): left to it until let go.
alpha:Fire("OnDragStart")
S.setup = true; alpha:ClearAllPoints(); alpha:SetPoint("CENTER", Minimap, "CENTER", 74, 0); S.setup = false
panel:Fire("OnUpdate", .1)
local _, rel = alpha:GetPoint(1)
equal(rel, Minimap, "mid its own drag: not pulled back")
alpha:Fire("OnDragStop")
panel:Fire("OnUpdate", .1)
bx, by = Screen(alpha)
near(bx, ax, "let go: back in its slot (x)"); near(by, ay, "and (y)")
-- Its addon lowering it (or raising its strata) while open: put right.
local clam = made.ClamOpenerMinimapButton
S.setup = true; clam:SetFrameLevel(3); clam:SetFrameStrata("LOW"); S.setup = false
panel:Fire("OnUpdate", .1)
equal(S.state[clam].strata .. " " .. S.state[clam].level, "HIGH " .. (S.state[panel].level + 5), "kept above the drawer's box")
-- The library's buttons, fixed by it: above the box too, and still fixed.
equal(S.state[alpha].strata .. " " .. S.state[alpha].level .. " " .. tostring(S.state[alpha].fixedStrata) .. "/" .. tostring(S.state[alpha].fixedLevel),
 "HIGH " .. (S.state[panel].level + 5) .. " true/true", "a fixed button is let go of, raised and fixed again")
drawer:Click()

-- Arrange ------------------------------------------------------------------------------

drawer:Click()
equal(#M.drawer.slots == 0 or not M.drawer.slots[1]:IsShown(), true, "no handles until Arrange")
M.drawer.arrange:Click()
equal(S.state[M.drawer.title].text .. " / " .. S.state[M.drawer.arrangeLabel].text, "Drag to reorder / Done", "Arrange: says what to do")
local handles = 0
for i, slot in ipairs(M.drawer.slots) do
 if slot:IsShown() then
  handles = handles + 1
  local button = slot.button
  near(select(1, Screen(slot)), select(1, Screen(button)), "handle " .. i .. " over " .. button:GetName())
  equal(S.state[slot].level > S.state[button].level, true, "handle " .. i .. " above the button, so the button's own scripts can't fire")
 end
end
equal(handles, 8, "a handle on every button")
-- Drag EraUI's button (first) to the third slot.
local first = M.drawer.slots[1]
local before = {}
for _, name in ipairs({"LibDBIcon10_Alpha", "FECMMinimapButton"}) do before[name] = S.state[_G[name]].drags end
first:Fire("OnDragStart")
S.cx, S.cy = Screen(M.drawer.slots[3])
panel:Fire("OnUpdate", .016)
equal(Names(M.drawer.shown), "ClamOpenerMinimapButton,FECMMinimapButton,EraUIMinimapButton,FECursorMinimapButton,ForeverEnhancedPrivacyMinimapButton,"
 .. "LibDBIcon10_Alpha,LibDBIcon10_Zulu,OtherAddonMinimapButton", "lifted and moved: the others make room as you drag")
-- On to the last slot, then back to the second row's start.
S.cx, S.cy = Screen(M.drawer.slots[8]); panel:Fire("OnUpdate", .016)
equal(Names(M.drawer.shown):match("([^,]+)$"), "EraUIMinimapButton", "dragged to the end")
S.cx, S.cy = Screen(M.drawer.slots[6]); panel:Fire("OnUpdate", .016)
first:Fire("OnDragStop")
local ARRANGED = "ClamOpenerMinimapButton,FECMMinimapButton,FECursorMinimapButton,ForeverEnhancedPrivacyMinimapButton,LibDBIcon10_Alpha,"
 .. "EraUIMinimapButton,LibDBIcon10_Zulu,OtherAddonMinimapButton"
equal(Names(M.drawer.shown), ARRANGED, "let go in the sixth slot")
equal(table.concat(E.settings.minimapDrawerOrder, ","), ARRANGED, "the order is saved by name")
equal(E.saves > 0, true, "and backed up")
for name, count in pairs(before) do equal(S.state[_G[name]].drags, count, "arranging never runs " .. name .. "'s own drag") end
Grid("arranged", 5, 8)
-- Done: the handles go.
M.drawer.arrange:Click()
equal(S.state[M.drawer.arrangeLabel].text, "Arrange", "Done: back to Arrange")
for _, slot in ipairs(M.drawer.slots) do equal(slot:IsShown(), false, "Done: no handles") end
-- Closing mid-arrange ends it, keeping what was done.
M.drawer.arrange:Click()
M.drawer.slots[2]:Fire("OnDragStart")
S.cx, S.cy = Screen(M.drawer.slots[1]); panel:Fire("OnUpdate", .016)
Escape()
equal(M.drawer.arranging, false, "closing ends Arrange")
equal(E.settings.minimapDrawerOrder[1], "FECMMinimapButton", "a drag cut short by closing is kept")
-- EraUI's own button in the drawer: its drag round the minimap is off, and
-- its tooltip doesn't offer it.
local era = _G.EraUIMinimapButton
local slotX, slotY = Screen(era)
era:Fire("OnDragStart")
equal(M.dragging, nil, "EraUI's button keeps its slot (no drag round the minimap)")
Event("UI_SCALE_CHANGED")
local ex, ey = Screen(era)
near(ex, slotX, "and stays in its slot when the minimap is laid out again")
era:Fire("OnEnter")
equal(S.tooltipLine:find("Drag", 1, true), nil, "its tooltip doesn't offer a drag in the drawer")

-- Combat: buttons are lent and given back only out of it -----------------------------

for _, f in ipairs(S.frames) do if S.before[f] and f ~= _G.ForbiddenMinimapButton then Untouched(f, "Drawer") end end
E.settings.cleanMinimapStyle = "hover"
S.combat = true
M:Refresh()
equal(Held(made.ClamOpenerMinimapButton), true, "turned off in combat: held until it ends")
drawer:Click()
equal(panel:IsShown(), true, "the drawer still opens in combat")
Escape()
S.combat = false
Event("PLAYER_REGEN_ENABLED")
-- Given back exactly; Alpha where its own drag put it (round the ring, as
-- the library saves it too).
for _, name in ipairs({"EraUIMinimapButton", "LibDBIcon10_Alpha", "LibDBIcon10_Zulu", "OtherAddonMinimapButton", unpack(SQUIRT)}) do
 if name ~= "EraUIMinimapButton" then
  Exact(_G[name], "Hover again", name == "LibDBIcon10_Alpha" and "CENTER Minimap CENTER 74.00 0.00" or nil)
 end
 equal(Held(_G[name]), false, "Hover again: " .. name .. " given back")
end
local ux, uy = era:GetCenter()
near(ux - mx, .7071 * 74, "EraUI's button back on its spot on the edge (x)")
near(uy - my, -.7071 * 74, "and (y)")
equal(drawer:IsShown() or panel:IsShown(), false, "the drawer button goes")
for _, f in ipairs(S.frames) do if S.before[f] and f ~= _G.ForbiddenMinimapButton then Untouched(f, "Given back") end end
-- Back to the drawer in combat: lent when it ends.
E.settings.cleanMinimapStyle = "drawer"
S.combat = true
M:Discover(); M:Refresh()
equal(Held(made.ClamOpenerMinimapButton), false, "Drawer chosen in combat: nothing lent yet")
S.combat = false
Event("PLAYER_REGEN_ENABLED")
equal(Held(made.ClamOpenerMinimapButton) and drawer:IsShown(), true, "lent when the fight ends")
equal(Names(M.drawer.order):sub(1, 17), "FECMMinimapButton", "in the saved order")
-- Clean Minimap off, and EraUI off: given back.
E.settings.cleanMinimap = false; M:Refresh()
for _, name in ipairs(SQUIRT) do Exact(_G[name], "Clean Minimap off") end
equal(drawer:IsShown(), false, "Clean Minimap off: no drawer button")
E.settings.cleanMinimap = true; M:Refresh()
equal(Held(made.FECMMinimapButton), true, "on again: back in the drawer")
E.settings.enabled = false; M:Refresh()
for _, name in ipairs(SQUIRT) do Exact(_G[name], "EraUI off") end
E.settings.enabled = nil; M:Refresh()
-- Log out: every button back where its addon put it.
Event("PLAYER_LOGOUT")
for _, name in ipairs(SQUIRT) do Exact(_G[name], "log out") end

-- An addon taking its own button back ----------------------------------------------

made = Session({cleanMinimap = true, cleanMinimapStyle = "drawer"})
panel, drawer = Panel(), DrawerButton()
equal(Held(made.FECMMinimapButton), true, "set up: in the drawer at once")
-- Its own settings put it back on the minimap: it's its again, then lent anew.
S.setup = true
made.FECMMinimapButton:SetParent(Minimap); made.FECMMinimapButton:SetFrameStrata("MEDIUM"); made.FECMMinimapButton:SetFrameLevel(9)
made.FECMMinimapButton:ClearAllPoints(); made.FECMMinimapButton:SetPoint("CENTER", Minimap, "CENTER", 0, -74)
S.setup = false
Tick(.1)
equal(Held(made.FECMMinimapButton), true, "re-placed on the minimap by its addon: lent again")
E.settings.cleanMinimapStyle = "hover"; M:Refresh()
equal(PointsText(S.state[made.FECMMinimapButton].points), "CENTER Minimap CENTER 0.00 -74.00", "given back where its addon last put it")
equal(S.state[made.FECMMinimapButton].level, 9, "at the level its addon last gave it")
E.settings.cleanMinimapStyle = "drawer"; M:Refresh()
-- Set free on the screen by its addon: it keeps it.
S.setup = true; made.FECMMinimapButton:SetParent(UIParent); made.FECMMinimapButton:SetPoint("CENTER", UIParent, "CENTER", 5, 5); S.setup = false
Tick(.1)
equal(Held(made.FECMMinimapButton), false, "free-floating by its addon: left to it")
equal(PointsText(S.state[made.FECMMinimapButton].points), "CENTER UIParent CENTER 5.00 5.00", "where its addon put it")
equal(Names(M.drawer.order):find("FECM", 1, true), nil, "out of the drawer's order")
-- Taken back just before the drawer gives everything back (no look in
-- between): it stays where its addon put it.
S.setup = true; made.ClamOpenerMinimapButton:SetParent(UIParent); made.ClamOpenerMinimapButton:SetPoint("CENTER", UIParent, "CENTER", 9, 9); S.setup = false
Event("PLAYER_LOGOUT")
equal(made.ClamOpenerMinimapButton:GetParent() == UIParent and PointsText(S.state[made.ClamOpenerMinimapButton].points), "CENTER UIParent CENTER 9.00 9.00",
 "taken back by its addon: never pulled back to where it was lent from")
Exact(made.FECursorMinimapButton, "log out after a take-back")

-- Reload: the saved order, new buttons at the end, missing ones skipped --------------

local saved = {cleanMinimap = true, cleanMinimapStyle = "drawer", minimapDrawerColumns = 4,
 minimapDrawerOrder = {"OtherAddonMinimapButton", "LibDBIcon10_Zulu", "GoneAddonMinimapButton", "EraUIMinimapButton", "FECMMinimapButton",
  "ClamOpenerMinimapButton", "LibDBIcon10_Alpha", "ForeverEnhancedPrivacyMinimapButton", "FECursorMinimapButton"}}
made = Session(saved, function(list)
 list.NewAddonMinimapButton = AddonButton("NewAddonMinimapButton", 45)
 list.AnotherNewMinimapButton = AddonButton("AnotherNewMinimapButton", 50)
end)
panel, drawer = Panel(), DrawerButton()
equal(Names(M.drawer.order), "OtherAddonMinimapButton,LibDBIcon10_Zulu,EraUIMinimapButton,FECMMinimapButton,ClamOpenerMinimapButton,"
 .. "LibDBIcon10_Alpha,ForeverEnhancedPrivacyMinimapButton,FECursorMinimapButton,AnotherNewMinimapButton,NewAddonMinimapButton",
 "after a reload: the saved order, a missing button skipped, new ones at the end (by name)")
drawer:Click()
Grid("four a row, saved", 4, 10)
E.settings.minimapDrawerColumns = 99; M:LayoutDrawer()
Grid("ten buttons: never more than eight a row", 8, 10)
E.settings.minimapDrawerColumns = 4; M:LayoutDrawer()
-- Arranging keeps the missing button's turn for when it's back.
M.drawer.arrange:Click()
M.drawer.slots[10]:Fire("OnDragStart")
S.cx, S.cy = Screen(M.drawer.slots[1]); panel:Fire("OnUpdate", .016)
M.drawer.slots[1]:Fire("OnDragStop")
equal(table.concat(E.settings.minimapDrawerOrder, ","), "NewAddonMinimapButton,OtherAddonMinimapButton,LibDBIcon10_Zulu,EraUIMinimapButton,"
 .. "FECMMinimapButton,ClamOpenerMinimapButton,LibDBIcon10_Alpha,ForeverEnhancedPrivacyMinimapButton,FECursorMinimapButton,"
 .. "AnotherNewMinimapButton,GoneAddonMinimapButton", "saved: the new order, the missing button kept after it")
Escape()

-- Late buttons: the library's at once, another addon's a moment after it loads -------

made = Session({cleanMinimap = true, cleanMinimapStyle = "drawer"}, nil)
panel, drawer = Panel(), DrawerButton()
S.setup = true
local icon = AddonButton("LibDBIcon10_Late", 10, nil, 31)
S.lib.objects.Late = icon
S.setup = false
S.before[icon] = Snapshot(icon)
local callback = S.lib.callbacks.LibDBIcon_IconCreated
callback[1][callback[2]](callback[1], "LibDBIcon_IconCreated", icon)
equal(Held(icon), true, "a library button made later goes in at once")
-- Another addon loads, then makes its button as you log in.
Event("ADDON_LOADED", "LateAddon")
S.setup = true
local late = AddonButton("LateAddonMinimapButton", 20)
S.setup = false
S.before[late] = Snapshot(late)
Tick(.1)
equal(Held(late), false, "another addon's late button: not yet")
Flush()
equal(Held(late), true, "a moment after an addon loads, its button goes in")
equal(Names(M.drawer.order):match("([^,]+)$"), "OtherAddonMinimapButton", "new ones join in name order with no saved order")
equal(Held(drawer), false, "a later look never takes the drawer button itself")
for _, f in ipairs(S.frames) do if S.before[f] and f ~= _G.ForbiddenMinimapButton then Untouched(f, "Late") end end

-- Moving the drawer button round the edge ------------------------------------------

drawer:Fire("OnDragStart")
S.cx, S.cy = Screen(Minimap); S.cx = S.cx - 200
drawer:Fire("OnUpdate", .016)
drawer:Fire("OnDragStop")
local dx, dy = drawer:GetCenter()
mx, my = Minimap:GetCenter()
near(dx - mx, -74, "dragged round to the left of the minimap (x)"); near(dy - my, 0, "(y)")
near(E.settings.minimapDrawerButtonPosition.x, -1, "its spot is saved (x)")
near(E.settings.minimapDrawerButtonPosition.y, 0, "its spot is saved (y)")
drawer:Click()
equal(panel:IsShown(), false, "the click ending a drag doesn't open it")
S.now = S.now + 1
-- Moved round to the minimap's left: it opens out to the left from there.
drawer:Click()
equal(panel:IsShown(), true, "a click after the drag opens it")
equal(Overlap(panel, Minimap), false, "moved to the left of the minimap: still never over it")
do
 local _, _, pr2 = Rect(panel)
 local bl2 = Rect(drawer)
 equal(math.abs(pr2 - bl2) <= 6, true, "it opens to the left of the button, right beside it")
end
drawer:Click()
S.now = S.now + 1
local keep = E.settings
made = Session({cleanMinimap = true, cleanMinimapStyle = "drawer", minimapDrawerButtonPosition = keep.minimapDrawerButtonPosition})
dx, dy = DrawerButton():GetCenter()
near(dx - mx, -74, "after a reload: still there")

-- Without the game's mouse-down event: a catcher over the screen closes it -----------

made = Session({cleanMinimap = true, cleanMinimapStyle = "drawer", noGlobalMouse = true})
panel, drawer = Panel(), DrawerButton()
drawer:Click()
local catcher = M.drawer.catcher
equal(catcher ~= nil and catcher:IsVisible() and S.state[catcher].mouse, true, "a catcher shows with the drawer")
equal(S.state[catcher].level < S.state[panel].level, true, "below the drawer")
catcher:Fire("OnMouseDown")
equal(panel:IsShown(), false, "a click on it closes the drawer")
drawer:Click()
equal(catcher:IsVisible(), true, "and it comes back with it")
Escape()
equal(catcher:IsVisible(), false, "and goes with it")

-- Placed by its addon after it was lent -------------------------------------------------
-- The library places its buttons as you log in, which can be after EraUI
-- lent them (no points yet), and re-places them later: given back where
-- the library put them, whether the drawer was opened in between or not.

made = Session({cleanMinimap = true, cleanMinimapStyle = "drawer"}, function(list)
 list.LibDBIcon10_Alpha:ClearAllPoints(); list.LibDBIcon10_Zulu:ClearAllPoints()
end)
panel, drawer = Panel(), DrawerButton()
equal(Held(made.LibDBIcon10_Alpha) and Held(made.LibDBIcon10_Zulu), true, "lent before the library placed them")
-- The library's log in: a centre point on the minimap, no clearing first.
S.setup = true
made.LibDBIcon10_Alpha:SetPoint("CENTER", Minimap, "CENTER", -50, 50)
made.LibDBIcon10_Zulu:SetPoint("CENTER", Minimap, "CENTER", 50, -50)
S.setup = false
Tick(.1)
-- Both laid out in the open drawer (Zulu stays in its slot); then the
-- library re-places Alpha on the ring (a new spot, as after its own
-- settings) while the drawer is closed.
drawer:Click(); drawer:Click()
equal(select(2, made.LibDBIcon10_Zulu:GetPoint(1)), panel, "Zulu in its slot")
S.setup = true; made.LibDBIcon10_Alpha:SetPoint("CENTER", Minimap, "CENTER", -60, 40); S.setup = false
E.settings.cleanMinimapStyle = "hover"; M:Refresh()
equal(PointsText(S.state[made.LibDBIcon10_Alpha].points), "CENTER Minimap CENTER -60.00 40.00", "given back where the library last placed it")
equal(PointsText(S.state[made.LibDBIcon10_Zulu].points), "CENTER Minimap CENTER 50.00 -50.00", "and after the open drawer had it in its slot")
Exact(made.FECMMinimapButton, "placed later: the rest exactly as lent")

-- The order kept from the first open; a look as it opens ------------------------------

made = Session({cleanMinimap = true, cleanMinimapStyle = "drawer"})
panel, drawer = Panel(), DrawerButton()
equal(E.settings.minimapDrawerOrder, nil, "no order saved before it's opened")
drawer:Click()
equal(table.concat(E.settings.minimapDrawerOrder, ","), DEFAULT_ORDER, "first open: the order you see is kept")
local saves = E.saves
drawer:Click(); drawer:Click()
equal(E.saves, saves, "opening again saves nothing new")
drawer:Click()
-- An addon makes its button later with no addon loading (no look then): it
-- joins as the drawer opens, at the end though its name comes first.
S.setup = true; local early = AddonButton("AaaLateMinimapButton", 15); S.setup = false
S.before[early] = Snapshot(early)
Tick(.1)
equal(Held(early), false, "made later: not in yet")
drawer:Click()
equal(Held(early), true, "in as the drawer opens")
equal(Names(M.drawer.shown):match("([^,]+)$"), "AaaLateMinimapButton", "at the end, not in among them by name")
equal(E.settings.minimapDrawerOrder[#E.settings.minimapDrawerOrder], "AaaLateMinimapButton", "and kept there")
Grid("one joined as it opened", 5, 9)
drawer:Click()
-- In a fight nothing is lent as it opens; the first open after it takes it.
S.setup = true; local fight = AddonButton("FightMinimapButton", 25); S.setup = false
S.before[fight] = Snapshot(fight)
S.combat = true
drawer:Click()
equal(tostring(Held(fight)) .. " " .. tostring(panel:IsShown()), "false true", "opened in a fight: open, nothing new lent")
drawer:Click()
S.combat = false
Event("PLAYER_REGEN_ENABLED")
drawer:Click()
equal(Held(fight) and Names(M.drawer.shown):match("([^,]+)$"), "FightMinimapButton", "after the fight, the next open takes it in, at the end")
drawer:Click()
for _, f in ipairs(S.frames) do if S.before[f] and f ~= _G.ForbiddenMinimapButton then Untouched(f, "Joined later") end end

-- Nothing to show ---------------------------------------------------------------------

made = Session({cleanMinimap = true, cleanMinimapStyle = "drawer", library = {}, noOther = true})
panel, drawer = Panel(), DrawerButton()
S.setup = true
for _, f in ipairs(M.drawer.order) do f:Hide() end
S.setup = false
drawer:Click()
equal(#M.drawer.shown .. " " .. tostring(M.drawer.empty:IsShown()) .. " " .. S.state[M.drawer.empty].text, "0 true No addon buttons yet.", "an empty drawer says so")
near(panel:GetWidth(), 176, "an empty drawer keeps its narrowest width")

print("Minimap drawer checks passed: " .. checks .. " assertions.")
