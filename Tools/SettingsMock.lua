-- The geometric frame mock and session for the /era tests
-- (Tools/TestSettingsLayout.lua, Tools/TestSettingsTour.lua). Not a test on
-- its own. Loads the real settings, navigation, rows, tour, layout and class
-- modules. Frames know their children, so showing or hiding one fires
-- OnShow/OnHide down its own branch only, as in the client. Protected
-- (secure) frames, their ancestors and anchors throw on combat mutations.
local M = {checks = 0}
local S = {frames = {}, timers = {}, combat = false, token = "DRUID"}
M.S = S
unpack = table.unpack or unpack

function M.equal(got, want, label)
 M.checks = M.checks + 1
 assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local methods = {}
M.methods = methods
local function Depends(f, target, seen)
 if f == target then return true end
 if not f or f == UIParent then return false end
 seen = seen or {}; if seen[f] then return false end; seen[f] = true
 if Depends(f.parent, target, seen) then return true end
 for _, p in ipairs(f.points) do if Depends(p[2], target, seen) then return true end end
 return false
end
M.Depends = Depends
local function Guard(f)
 if not S.combat or f == UIParent then return end
 for _, other in ipairs(S.frames) do
  if other.secure and Depends(other, f) then error("protected mutation of " .. (f.name or f.kind)) end
 end
end
M.Guard = Guard
local function Frame(kind, name, parent, template)
 local f = setmetatable({kind = kind, name = name, parent = parent, shown = true, points = {}, scripts = {}, hooks = {},
  children = {}, w = 0, h = 0, value = 0, scale = 1, alpha = 1, level = 1, attributes = {},
  secure = template ~= nil and template:find("SecureActionButton", 1, true) ~= nil}, {__index = methods})
 if parent then parent.children[#parent.children + 1] = f end
 S.frames[#S.frames + 1] = f
 if name then _G[name] = f end
 return f
end
M.Frame = Frame
function methods:Fire(event, ...)
 if self.scripts[event] then self.scripts[event](self, ...) end
 for _, fn in ipairs(self.hooks[event] or {}) do fn(self, ...) end
end
function methods:SetScript(event, fn) self.scripts[event] = fn end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn) self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event], fn) end
-- As in the client: IsShown is a frame's own flag, IsVisible also needs its parents.
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
local function Visit(f, event)
 f:Fire(event)
 for _, child in ipairs(f.children) do if child.shown then Visit(child, event) end end
end
function methods:SetShown(v)
 Guard(self); v = not not v
 if self.shown == v then return end
 local parentVisible = not self.parent or self.parent:IsVisible()
 self.shown = v
 if parentVisible then Visit(self, v and "OnShow" or "OnHide") end
end
function methods:Hide() self:SetShown(false) end
function methods:Show() self:SetShown(true) end
function methods:SetParent(p)
 Guard(self)
 if self.parent == p then return end
 local before = self:IsVisible()
 if self.parent then
  for i, child in ipairs(self.parent.children) do if child == self then table.remove(self.parent.children, i); break end end
 end
 self.parent = p
 if p then p.children[#p.children + 1] = self end
 local now = self:IsVisible()
 if now ~= before then Visit(self, now and "OnShow" or "OnHide") end
end
function methods:GetParent() return self.parent end
function methods:SetScale(s) Guard(self); self.scale = s end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetFrameLevel(level) Guard(self); self.level = level end
function methods:GetFrameLevel() return self.level end
local factors = {TOPLEFT = {0, 1}, TOP = {.5, 1}, TOPRIGHT = {1, 1}, LEFT = {0, .5}, CENTER = {.5, .5}, RIGHT = {1, .5},
 BOTTOMLEFT = {0, 0}, BOTTOM = {.5, 0}, BOTTOMRIGHT = {1, 0}}
function methods:SetPoint(p, r, rp, x, y)
 Guard(self)
 if type(r) == "number" or r == nil then x, y = r or 0, rp or 0; r = self.parent; rp = p
 elseif type(rp) == "number" then x, y = rp, x or 0; rp = p end
 local point = {p, r, rp or p, x or 0, y or 0}
 for i, old in ipairs(self.points) do if old[1] == p then self.points[i] = point; return end end
 self.points[#self.points + 1] = point
end
function methods:ClearAllPoints() Guard(self); self.points = {} end
function methods:GetPoint(i) return table.unpack(self.points[i or 1] or {}) end
function methods:GetNumPoints() return #self.points end
function methods:SetAllPoints(r)
 r = r or self.parent; self:ClearAllPoints()
 self:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
end
local function Anchor(f, p)
 local r = p[2]; local x, y, w, h = r:Rect(); local ratio = r:GetEffectiveScale() / f:GetEffectiveScale(); local a = factors[p[3]]
 y = y + ((f.parent and f.parent.scrollChild == f) and (f.parent.scroll or 0) or 0)
 return (x + w * a[1]) * ratio + p[4], (y + h * a[2]) * ratio + p[5]
end
function methods:Rect()
 if self == UIParent then return 0, 0, self.w, self.h end
 local p = self.points[1]; local w, h = self.w, self.h
 if not p then return 0, 0, w, h end
 local x, y = Anchor(self, p); local a = factors[p[1]]
 for i = 2, #self.points do
  local other = self.points[i]; local ox, oy = Anchor(self, other); local b = factors[other[1]]
  if a[1] ~= b[1] then w = (ox - x) / (b[1] - a[1]) end
  if a[2] ~= b[2] then h = (oy - y) / (b[2] - a[2]) end
 end
 return x - a[1] * w, y - a[2] * h, w, h
end
function methods:GetWidth() local _, _, w = self:Rect(); return w end
function methods:GetHeight() local _, _, _, h = self:Rect(); return h end
function methods:GetLeft() return self:Rect() end
function methods:GetBottom() local _, y = self:Rect(); return y end
function methods:GetTop() local _, y, _, h = self:Rect(); return y + h end
function methods:GetRight() local x, _, w = self:Rect(); return x + w end
function methods:GetCenter() local x, y, w, h = self:Rect(); return x + w / 2, y + h / 2 end
function methods:SetSize(w, h)
 Guard(self); local changed = self.w ~= w or self.h ~= h; self.w, self.h = w, h
 if changed then self:Fire("OnSizeChanged", w, h) end
end
function methods:SetWidth(w) self:SetSize(w, self.h) end
function methods:SetHeight(h) self:SetSize(self.w, h) end
-- As in the client, a button's text goes to the font string it was given.
function methods:SetText(text) self.text = text; if self.fontString then self.fontString:SetText(text) end; self:Fire("OnTextChanged") end
function methods:SetFontString(fs) self.fontString = fs end
-- A click runs PreClick, OnClick and PostClick, as in the client.
function methods:Click(button) self:Fire("PreClick", button); self:Fire("OnClick", button); self:Fire("PostClick", button) end
function methods:GetText() return self.text or "" end
function methods:SetFont(...) self.font = {...}; if self.kind == "FontString" then self.h = self.font[2] or 12 end end
function methods:GetFont() return "font", 12, "" end
-- Six per letter (colour codes and texture codes take no room).
local function Drawn(text) return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "x")) end
M.Drawn = Drawn
function methods:GetStringWidth() return #Drawn(self:GetText()) * 6 end
function methods:GetStringHeight()
 local size = self.font and self.font[2] or 12
 local width = self.w > 0 and self.w or 1e9
 local lines, line = 0, 0
 for word in Drawn(self:GetText()):gmatch("%S+") do
  local add = (line > 0 and 1 or 0) + #word
  if line > 0 and (line + add) * 6 > width then lines = lines + 1; line = #word else line = line + add end
 end
 if line > 0 then lines = lines + 1 end
 if self.maxLines and self.maxLines > 0 then lines = math.min(lines, self.maxLines) end
 return math.max(1, lines) * (size + 2)
end
function methods:SetChecked(v) self.checked = not not v end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(v) self.enabled = v end
function methods:Enable() self.enabled = true end
function methods:Disable() self.enabled = false end
function methods:IsEnabled() return self.enabled ~= false end
function methods:SetAttribute(k, v) Guard(self); self.attributes[k] = v end
function methods:GetAttribute(k) return self.attributes[k] end
function methods:CreateTexture() return Frame("Texture", nil, self) end
function methods:CreateFontString() return Frame("FontString", nil, self) end
function methods:SetThumbTexture() self.thumbTexture = Frame("Texture", nil, self) end
function methods:GetThumbTexture() return self.thumbTexture end
function methods:SetValue(v) if v ~= self.value then self.value = v; self:Fire("OnValueChanged", v) end end
function methods:GetValue() return self.value end
function methods:SetMinMaxValues(low, high) self.low, self.high = low, high end
function methods:GetMinMaxValues() return self.low, self.high end
function methods:SetScrollChild(f) self.scrollChild = f; f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0) end
function methods:SetVerticalScroll(v) Guard(self); self.scroll = v end
function methods:GetVerticalScroll() return self.scroll or 0 end
for _, key in ipairs({"SetBackdrop", "SetTexCoord", "SetShadowColor", "SetShadowOffset", "SetFrameStrata", "SetMovable",
 "SetClampedToScreen", "RegisterForDrag", "RegisterEvent", "UnregisterAllEvents", "SetOrientation", "SetValueStep",
 "SetObeyStepOnDrag", "SetAutoFocus", "SetMaxLetters", "SetTextInsets", "StartMoving", "StopMovingOrSizing",
 "SetHitRectInsets", "SetAltArrowKeyMode", "SetNonSpaceWrap", "Raise", "SetDrawLayer", "SetBlendMode",
 "SetDesaturated", "SetCheckedTexture", "SetHighlightTexture", "SetNormalTexture", "SetPushedTexture",
 "SetDisabledTexture", "LockHighlight", "UnlockHighlight", "SetStatusBarTexture", "SetStatusBarColor"}) do
 methods[key] = function(self) Guard(self) end
end
-- Kept, so wrapping, justification, colours, alpha and mouse can be checked.
function methods:SetWordWrap(v) Guard(self); self.wordWrap = v end
function methods:SetJustifyH(v) Guard(self); self.justifyH = v end
function methods:SetJustifyV(v) Guard(self); self.justifyV = v end
function methods:SetMaxLines(n) self.maxLines = n end
function methods:GetMaxLines() return self.maxLines end
function methods:EnableMouse(v) Guard(self); self.mouse = v end
function methods:IsMouseEnabled() return self.mouse == true end
function methods:EnableMouseWheel(v) Guard(self); self.wheel = v end
function methods:RegisterForClicks(...) Guard(self); self.clicks = {...} end
function methods:SetTextColor(r, g, b) Guard(self); self.colour = {r, g, b} end
function methods:SetColorTexture(r, g, b, a) Guard(self); self.fill = {r, g, b, a or 1} end
function methods:SetVertexColor(r, g, b, a) Guard(self); self.vertex = {r, g, b, a or 1} end
function methods:SetBackdropColor(r, g, b, a) Guard(self); self.backdropColour = {r, g, b, a or 1} end
function methods:SetBackdropBorderColor(r, g, b, a) Guard(self); self.borderColour = {r, g, b, a or 1} end
function methods:SetAlpha(a) Guard(self); self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:SetTexture(texture) Guard(self); self.texture = texture end
-- One edit box has the keyboard at a time; losing it fires OnEditFocusLost.
function methods:SetFocus()
 if S.focus == self then return end
 local old = S.focus
 S.focus = self
 if old then old:Fire("OnEditFocusLost") end
 self:Fire("OnEditFocusGained")
end
function methods:ClearFocus()
 if S.focus ~= self then return end
 S.focus = nil
 self:Fire("OnEditFocusLost")
end
function methods:HasFocus() return S.focus == self end

function M.Flush()
 for _ = 1, 20 do
  if #S.timers == 0 then return end
  local pending = S.timers; S.timers = {}
  for _, fn in ipairs(pending) do fn() end
 end
 error("layout queue did not settle")
end

-- A game session: a fresh mock world, the real modules, and the settings
-- window open on the class tab. ready: the Coming soon features as
-- finished; soon: Bag Item Levels back to Coming soon; char: the
-- per-character saved table; setup(E): spies before settings initialise.
function M.Session(c, ready, soon, char, setup)
 S.frames, S.timers, S.combat, S.token, S.focus = {}, {}, false, c, nil
 UIParent = Frame("Root"); UIParent.w = 2560 / .65; UIParent.h = 1440 / .65; UIParent.scale = .65
 GameFontHighlight = Frame("Font"); GameFontHighlightSmall = GameFontHighlight
 C_Timer = {After = function(_, fn) S.timers[#S.timers + 1] = fn end}
 EraUIDB = {}; EraUIClassicCharDB = char or {}; UISpecialFrames = {}; SlashCmdList = {}
 local E = {modules = {}, reloadSettings = {}, settingDefaults = {}, charSettingKeys = {},
  settings = {enabled = true, mageSupplies = true, hunterFeed = true}, version = "9.9.9"}
 function E:RegisterModule(name, m) self.modules[name] = m end
 function E:GetSetting(key) return self.settings[key] end
 E.GetSavedSetting = E.GetSetting
 function E:SetSetting(key, value) self.settings[key] = value end
 function E:SaveSettings() end
 function E:Print() end
 function E:Status() end
 E.Persistence = {}
 E.Classic = {DB_DEFAULTS = {}, TOGGLES = {}, RELOAD_KEYS = {}, MirrorSave = function() end,
  OpenOptions = function() end, ApplyAll = function() end, ToggleChanged = function() end, FirstRun = function() end}
 assert(loadfile("Modules/PoisonData.lua"))("EraUI", E)
 assert(loadfile("Modules/ClassTools.lua"))("EraUI", E)
 assert(loadfile("Modules/ClassReminderData.lua"))("EraUI", E)
 assert(loadfile("Modules/ClassReminderPoisons.lua"))("EraUI", E)
 assert(loadfile("Modules/ClassReminders.lua"))("EraUI", E)
 assert(loadfile("Modules/HunterFeed.lua"))("EraUI", E)
 assert(loadfile("Modules/MageSupplies.lua"))("EraUI", E)
 assert(loadfile("Modules/RoguePoisons.lua"))("EraUI", E)
 -- The real Classic -> settings toggle bridge and slash commands.
 assert(loadfile("Core/Integration.lua"))("EraUI", E)
 assert(loadfile("Core/Commands.lua"))("EraUI", E)
 assert(loadfile("Core/SettingsLayout.lua"))("EraUI", E)
 assert(loadfile("Core/Presets.lua"))("EraUI", E)
 assert(loadfile("Modules/CombatFont.lua"))("EraUI", E)
 -- The real Coming soon flags; ready runs the finished features instead.
 assert(loadfile("Modules/AFKScreen.lua"))("EraUI", E)
 assert(loadfile("Modules/BagItemLevels.lua"))("EraUI", E)
 if ready then E.modules.AFKScreen.comingSoon = false; E.modules.BagItemLevels.comingSoon = false end
 if soon then E.modules.BagItemLevels.comingSoon = true end
 -- As Core/Init.lua (TestPersistence and each feature's own test check the real defaults).
 for key, value in pairs({darkAuraBorders = true, darkAuraShadows = true, darkWindows = true, darkMenuBar = true,
  afkScreen = true, afkShowQuote = true, afkShowZone = true, afkShowGuild = true, afkShowDate = true, afkZoom = true,
  darkModeDarkness = 58, cursorRingSize = 48, cursorRingThickness = 2, cursorCastSize = 60, cursorCastOpacity = 90,
  cursorTrailSize = 10, cursorTrailOpacity = 55, cursorTrailLength = 25, cursorCastColour = "FFFFFF",
  cursorTrailColour = "FFFFFF", damageFont = "pepsi", linkToggle = true, updateCheck = true, vendorPrice = true,
  classColors = true, bagSpace = true, questLevels = true, matchFocusSize = true, trainingGuide = true,
  spellbookCombatDrag = true, gryphons = true, actionBars = true, unitFrames = true, minimap = true, castBars = true,
  advancedCastLatency = true, advancedCastTicks = true, movableMap = true, mapQuestObjectives = true,
  hideStatusMessages = true}) do E.settingDefaults[key] = value end
 E.cvarSettings = {classIconPortraitMine = "ReplaceMyPlayerPortrait", classIconPortraitOthers = "ReplaceOtherPlayerPortraits"}
 -- The real release list: What's New's release (1.7.0 here, the newest, as
 -- "9.9.9" has no notes of its own) and version order for "just added".
 assert(loadfile("Core/Updates.lua"))("EraUI", E)
 -- A test can pin What's New's release instead (MOCK_RELEASE): the tour's
 -- walkthroughs run as the newest release that added options.
 if MOCK_RELEASE then E.ReleaseVersion = function() return MOCK_RELEASE end end
 -- In the .toc's order.
 assert(loadfile("Core/SettingsRows.lua"))("EraUI", E)
 assert(loadfile("Core/SettingsNav.lua"))("EraUI", E)
 assert(loadfile("Core/SettingsTour.lua"))("EraUI", E)
 assert(loadfile("Core/Settings.lua"))("EraUI", E)
 E.modules.ClassReminders:Initialize()
 E.modules.MageSupplies:Initialize()
 if setup then setup(E) end
 E.modules.Settings:Initialize()
 local f = E.settingsFrame; f.selectedCategory = f.tabIndex.class; f:Show(); M.Flush()
 return E, f
end

-- The mock world's globals the session sets up for every test.
CreateFrame = Frame
InCombatLockdown = function() return S.combat end
UnitClass = function() return S.token, S.token end
UnitIsPlayer = function() return true end
UnitLevel = function() return 20 end
GetTime = function() return 10 end
IsShiftKeyDown = function() return S.shift == true end
IsPlayerSpell = function(id) return id == 587 or id == 5504 end
C_Spell = {GetSpellInfo = function(id) return {name = "Spell" .. id, iconID = id} end}
C_Item = {GetItemInfo = function() return "Item", nil, nil, nil, 1, nil, nil, 20 end, GetItemCount = function() return 0 end}
RAID_CLASS_COLORS = {MAGE = {r = .4, g = .8, b = 1}, HUNTER = {r = .6, g = .8, b = .4}, ROGUE = {r = 1, g = .96, b = .41},
 DRUID = {r = 1, g = .49, b = .04}}
GetCVarBool = function() return false end
hooksecurefunc = function(f, key, fn) local old = f[key]; f[key] = function(self, ...) old(self, ...); fn(self, ...) end end
RegisterStateDriver = function(f, _, rule) Guard(f); f.rule = rule; f:SetShown(rule ~= "hide" and not S.combat) end

-- Helpers ---------------------------------------------------------------------

function M.Tab(f, id) return f.tabIndex[id] end
-- A taller or shorter window; the viewport, pinned by two corners, changes
-- size with it and says so, as in the client.
function M.Resize(f, height)
 f:SetHeight(height)
 f.settingsScroll:Fire("OnSizeChanged", f.settingsScroll:GetWidth(), f.settingsScroll:GetHeight())
 M.Flush()
end
-- Opens a tab (and sub-tab) the way a click does.
function M.Open(f, id, sub)
 if f.setupMode then f:SetSetupMode(false); M.Flush() end
 f:SelectCategory(f.tabIndex[id], sub); M.Flush()
end
-- The rows on show, in the page's reading order (keys).
function M.Keys(f)
 local out = {}
 for i, row in ipairs(f.visibleRows or {}) do out[i] = row.settingKey or "?" end
 return out
end
function M.Text(text) return Drawn(text or "") end
-- What a row's footer description says (help, then extras), colour codes taken out.
function M.Hover(f, row)
 row:Fire("OnEnter")
 local help = Drawn(f.footerHelp:GetText())
 local extras = f.footerExtras:IsShown() and Drawn(f.footerExtras:GetText()) or ""
 row:Fire("OnLeave")
 return help .. "\n" .. extras, help, extras
end
-- Search results: the keys they lead to, in order, and their breadcrumbs.
function M.Results(f, query)
 f.searchBox:SetText(query); M.Flush()
 local keys, crumbs = {}, {}
 for i, row in ipairs(f.visibleRows or {}) do keys[i] = row.target and row.target.settingKey or "?"; crumbs[i] = row.crumb and row.crumb:GetText() end
 return keys, crumbs
end
-- How many lines text wraps to at chars letters a line.
function M.Lines(text, chars)
 local lines, line = 0, ""
 for word in text:gmatch("%S+") do
  if line == "" then line = word elseif #line + 1 + #word <= chars then line = line .. " " .. word else lines = lines + 1; line = word end
 end
 return lines + (line ~= "" and 1 or 0)
end
-- Honest widths for the game's font (Friz Quadrata): a glyph estimate never
-- under the tab names measured in game on 2026-10-01 at 13 point (checked
-- in TestSettingsLayout), scaled to the size asked for. Colour and texture
-- codes take no room.
function M.Glyphs(text, size)
 local width = 0
 for ch in Drawn(text):gmatch(".") do
  width = width + (ch == " " and 3.4 or ("iljtfr"):find(ch, 1, true) and 5.4 or ("mwMW&"):find(ch, 1, true) and 12.5 or 8.0)
 end
 return width * 1.06 * (size or 13) / 13
end
-- How many lines text wraps to in width at that size, word by word, with
-- those widths (the game wraps a font string the same way).
function M.LinesIn(text, width, size)
 local lines, line = 0, 0
 local space = M.Glyphs(" ", size)
 for word in Drawn(text):gmatch("%S+") do
  local w = M.Glyphs(word, size)
  if line == 0 then line = w elseif line + space + w <= width then line = line + space + w else lines = lines + 1; line = w end
 end
 return lines + (line > 0 and 1 or 0)
end
-- Rows, headings, inline boxes and results on show never overlap.
function M.NoOverlaps(f, label)
 local shown = {}
 for _, row in ipairs(f.visibleRows or {}) do
  shown[#shown + 1] = {name = row.settingKey or "result", r = row}
  if row.inlinePanel and row.inlinePanel:IsShown() then shown[#shown + 1] = {name = (row.settingKey or "?") .. " box", r = row.inlinePanel} end
 end
 for i, fs in ipairs(f.headingPool) do if fs:IsShown() then shown[#shown + 1] = {name = "heading " .. fs:GetText(), r = fs, heading = true} end end
 for i = 1, #shown do
  for j = i + 1, #shown do
   local a, b = shown[i].r, shown[j].r
   local ar = shown[i].heading and a:GetLeft() + a:GetStringWidth() or a:GetRight()
   local br = shown[j].heading and b:GetLeft() + b:GetStringWidth() or b:GetRight()
   local hit = a:GetLeft() < br - .01 and b:GetLeft() < ar - .01 and a:GetBottom() < b:GetTop() - .01 and b:GetBottom() < a:GetTop() - .01
   M.equal(hit, false, label .. " " .. shown[i].name .. " / " .. shown[j].name .. " do not overlap")
  end
 end
end
-- Every row on show lies in the clipped content, inside the page's width,
-- and its box fits the viewport.
function M.Fits(f, label)
 local s = f.settingsScroll
 M.equal(s:GetBottom() >= f:GetBottom() + 92 + 16 - .01, true, label .. " viewport clears the footer")
 for _, row in ipairs(f.visibleRows or {}) do
  M.equal(row:GetParent(), f.settingsContent, label .. " " .. tostring(row.settingKey) .. " in clipped content")
  M.equal(row:GetLeft() >= s:GetLeft() - .01 and row:GetRight() <= s:GetRight() + .01, true, label .. " " .. tostring(row.settingKey) .. " fits the width")
  if row.inlinePanel and row.inlinePanel:IsShown() then
   M.equal(row.inlinePanel:GetParent(), f.settingsContent, label .. " inline panel in clipped content")
   M.equal(row.inlinePanel:GetRight() <= s:GetRight() + .01, true, label .. " right panel border fits viewport")
  end
 end
end
-- The sub-option rule: each row with a layout parent on show sits in that
-- parent's column block, after it, indented 22 a level, with its connector.
function M.SubOptionsFollow(f, label, parentOf)
 local seen = {}
 for _, row in ipairs(f.visibleRows or {}) do
  local key = row.settingKey
  local parent = parentOf(key)
  local owner = parent and f.checks[parent]
  if owner and owner:IsShown() and seen[parent] then
   M.equal(row:GetTop() <= owner:GetBottom() + .01, true, label .. ": " .. key .. " below " .. parent)
   local depth = row.depth or 0
   M.equal(depth, owner.wide and 1 or math.min(2, (owner.depth or 0) + 1), label .. ": " .. key .. " indented one level under " .. parent)
   local base = owner.wide and f.settingsContent:GetLeft() or owner:GetLeft() - (owner.depth or 0) * 22
   M.equal(math.abs(row:GetLeft() - (base + depth * 22)) < .01, true, label .. ": " .. key .. " in " .. parent .. "'s column, 22 in a level")
   M.equal(row.connV:IsShown() and row.connH:IsShown(), true, label .. ": " .. key .. " joined to " .. parent .. " by its line")
  end
  seen[key] = true
 end
end

return M
