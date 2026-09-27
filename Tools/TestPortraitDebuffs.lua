-- Run the actual portrait crowd-control module against fixtures shaped like
-- Blizzard's CustomAuraContainer and C_LossOfControl. Any addon aura read
-- errors, as it does in combat on the client, and slot buttons refuse addon
-- access after their initializer, as the client's access restrictions do.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local combat, now = false, 100
issecretvalue = function() return false end
InCombatLockdown = function() return combat end
GetTime = function() return now end
STANDARD_TEXT_FONT = "font"
C_UnitAuras = setmetatable({}, { __index = function(_, key) error("addon read auras: C_UnitAuras." .. key) end })
CustomAuraContainerSlotDefaultOptions = { sortMethod = 0, sortDirection = 0 }

CreateFont = function(name)
    local font = { name = name }
    function font:SetFont(_, size, flags) self.size, self.flags = size, flags end
    function font:SetTextColor(...) self.colour = { ... } end
    function font:GetName() return self.name end
    return font
end

local all = {} -- Every fixture region, to locate the module's own displays.
local function Region(parent, kind)
    local r = { parent = parent, kind = kind, shown = true, points = {}, scripts = {}, events = {} }
    r.level = parent and parent.level and parent.level + 1 or 1
    function r:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function r:SetAllPoints(target) self.allPoints = target or true end
    function r:SetSize(w, h) self.width, self.height = w, h end
    function r:EnableMouse(value) self.mouse = value end
    function r:SetFrameLevel(level) self.level = level end
    function r:GetFrameLevel() return self.level end
    function r:GetParent() return self.parent end
    function r:Show() self.shown = true end
    function r:Hide() self.shown = false end
    function r:SetShown(value) self.shown = value and true or false end
    function r:IsShown() return self.shown end
    function r:SetScript(key, fn) self.scripts[key] = fn end
    function r:RegisterEvent(event) self.events[event] = true end
    function r:CreateTexture() return Region(self, "Texture") end
    function r:CreateMaskTexture() return Region(self, "MaskTexture") end
    function r:CreateFontString() return Region(self, "FontString") end
    function r:SetTexture(value) self.texture = value end
    function r:SetTexCoord(...) self.coords = { ... } end
    function r:AddMaskTexture(mask) self.mask = mask end
    function r:SetText(value) self.text = value end
    function r:SetFontObject(font) self.font = font end
    all[#all + 1] = r
    return r
end
local function Descends(object, owner)
    local p = object and object.parent
    while p do if p == owner then return true end; p = p.parent end
    return false
end
local function Find(test) for _, r in ipairs(all) do if test(r) then return r end end end

-- Slot buttons: after the initializer, addon access is denied (the client's
-- DenyTaintedAccessWhenAurasAreSecret restriction), so any later touch fails.
local function SlotButton(container)
    local b = Region(container, "AuraButton")
    local function Guard() assert(not b.restricted, "addon touched a restricted aura slot button") end
    for _, name in ipairs({ "SetAllPoints", "EnableMouse", "SetFrameLevel", "CreateTexture", "SetPoint", "Show", "Hide", "SetShown" }) do
        local original = b[name]
        b[name] = function(self, ...) Guard(); return original(self, ...) end
    end
    function b:SetIcon(texture)
        Guard()
        assert(texture.kind == "Texture" and Descends(texture, self), "icon must be a Texture descendant of the slot")
        self.icon = texture
    end
    function b:SetDurationCooldown(cooldown)
        Guard()
        assert(cooldown.kind == "Cooldown" and Descends(cooldown, self), "cooldown must be a Cooldown descendant of the slot")
        self.cooldown = cooldown
    end
    return b
end

local containers = {}
local function Container(parent)
    local c = Region(parent, "AuraContainer")
    c.slots, c.order, c.updates = {}, {}, 0
    function c:SetEditModePreviewEnabled(value) self.preview = value end
    function c:SetUnit(unit) self.unit = unit end
    function c:UpdateAllAuras() self.updates = self.updates + 1 end
    function c:SetEnabled(value) self.enabled = value end
    function c:AddAuraSlot(key, filter, options)
        assert(not self.slots[key], "duplicate slot " .. key)
        local button = SlotButton(self)
        options.initializeFrame(button)
        button.restricted = true
        self.slots[key] = { filter = filter, options = options, button = button }
        self.order[#self.order + 1] = key
        return button
    end
    containers[#containers + 1] = c
    return c
end

local function Cooldown(parent)
    local c = Region(parent, "Cooldown")
    function c:SetDrawEdge(value) self.edge = value end
    function c:SetDrawBling(value) self.bling = value end
    function c:SetSwipeTexture(value, colour)
        assert(type(colour) ~= "string", "bad argument #2 to 'SetSwipeTexture' (Usage: self:SetSwipeTexture([texture, color]))")
        self.swipe = value
    end
    function c:SetSwipeColor(...) self.swipeColour = { ... } end
    function c:SetUseCircularEdge(value) self.circular = value end
    function c:SetHideCountdownNumbers(value) self.hideNumbers = value end
    function c:SetCountdownFont(name) self.countdownFont = name end
    function c:SetCooldown(start, duration) self.start, self.duration = start, duration end
    function c:Clear() self.start, self.duration = nil, nil end
    return c
end

local driver
local buildFails = false
CreateFrame = function(kind, _, parent)
    assert(not combat, "created a display in combat")
    if kind == "AuraContainer" then
        assert(not buildFails, "AuraContainer is unavailable")
        return Container(parent)
    end
    if kind == "Cooldown" then return Cooldown(parent) end
    local f = Region(parent, "Frame")
    driver = driver or f -- The module's first frame is its event driver.
    return f
end

local function Native(unit, style)
    local owner = Region(nil, "Frame"); owner.unit = unit; owner.level = 10
    local container = Region(owner, "Frame")
    local portrait = Region(container, "Texture")
    if style == "player" then owner.PlayerFrameContainer = container; container.PlayerPortrait = portrait
    elseif style == "target" then owner.TargetFrameContainer = container; container.Portrait = portrait
    else owner.Portrait = portrait end
    return owner
end
PlayerFrame = Native("player", "player")
TargetFrame = Native("target", "target")
FocusFrame = Native("focus", "target")
local party = { Native("party1"), Native("party2") }
PartyFrame = { PartyMemberFramePool = { EnumerateActive = function()
    local i = 0
    return function() i = i + 1; return party[i] end
end } }

local loc = {}
C_LossOfControl = { GetActiveLossOfControlData = function(index) return loc[index] end }

local printed = {}
local E = { settings = { enabled = true, unitFrames = true, portraitDebuffs = false }, modules = {}, Classic = {} }
function E:RegisterModule(name, module) self.modules[name] = module end
function E:GetSetting(key) return self.settings[key] end
function E:Print(message) printed[#printed + 1] = message end
function E.Classic.TexPath(key) return key, "bundled:" .. key end -- Path plus fallback, like the real helper.
function E.Classic.RoundIcon(icon)
    icon:SetTexCoord(.1, .9, .1, .9)
    icon:AddMaskTexture(icon:GetParent():CreateMaskTexture())
end

assert(loadfile("Modules/PortraitDebuffs.lua"))("EraUI", E)
local M = E.modules.PortraitDebuffs
M:Initialize()
local function Fire(event) driver.scripts.OnEvent(driver, event) end

Equal(#containers, 0, "off by default: nothing built")
Equal(driver.events.LOSS_OF_CONTROL_ADDED, true, "listens for loss-of-control changes")

-- Enable ------------------------------------------------------------------------------

E.settings.portraitDebuffs = true
M:Refresh()
local byUnit = {}
for _, c in ipairs(containers) do byUnit[c.unit] = c end
Equal(#containers, 4, "containers for target, focus and two party members")
Equal(byUnit.player, nil, "the player portrait does not use an aura container")

local target = byUnit.target
Equal(target.preview, false, "Edit Mode preview auras disabled")
Equal(target.mouse, false, "container never blocks portrait clicks")
Equal(target.level, TargetFrame.level + 5, "container sits above the portrait")
Equal(target.enabled, true, "container enabled")
Equal(#target.order, 5, "hostile units get four priority slots and one catch-all")
Equal(target.slots.any.filter, "HARMFUL|CROWD_CONTROL", "catch-all uses the client's crowd-control category")
for _, key in ipairs({ "stun", "fear", "silence", "root" }) do
    local slot = target.slots[key]
    Equal(slot.filter, "HARMFUL", key .. " slot scans harmful auras")
    Equal(type(slot.options.candidateFilters.includeSpellIDs), "table", key .. " slot matches by spell ID")
end
Equal(target.slots.root.options.candidateFilters.includeSpellIDs[339], true, "Entangling Roots rank 1 is a root")
Equal(target.slots.root.options.candidateFilters.includeSpellIDs[9853], true, "Entangling Roots rank 6 is a root")
Equal(target.slots.stun.options.candidateFilters.includeSpellIDs[5211], true, "Bash is a stun")
Equal(target.slots.stun.options.candidateFilters.includeSpellIDs[339], nil, "roots are not stuns")
local function Level(key) return target.slots[key].button.level end
Equal(Level("stun") > Level("fear") and Level("fear") > Level("silence") and Level("silence") > Level("root")
    and Level("root") > Level("any"), true, "stun draws above fear, silence, root, then any")

local BADGE_RIGHT = "Interface\\AddOns\\EraUI\\Media\\PortraitCCMaskRight.tga"
for key, slot in pairs(target.slots) do
    local button = slot.button
    Equal(button.mouse, false, key .. " slot is click-through")
    Equal(button.allPoints, target, key .. " slot fills the portrait area")
    Equal(button.icon ~= nil and button.icon.mask ~= nil, true, key .. " icon is masked")
    Equal(button.icon.mask.texture, BADGE_RIGHT, key .. " icon also covers the level badge below-right")
    Equal(button.icon.width, 88, key .. " icon spans the portrait and badge")
    Equal(button.icon.points[1][2], button, key .. " icon is centred on the portrait")
    Equal(button.cooldown.swipe, "portraitMask", key .. " sweep uses the round portrait mask")
    Equal(button.cooldown.hideNumbers, false, key .. " countdown comes from the client")
    Equal(button.cooldown.countdownFont, "EraUIPortraitCCLarge", key .. " countdown uses the large font")
    Equal(button.cooldown.circular, true, key .. " sweep edge is circular")
end

local party1 = byUnit.party1
Equal(#party1.order, 1, "friendly party portraits use the catch-all only")
Equal(party1.slots.any.button.icon.coords[1], .1, "party portraits have no level badge: plain round icon")
Equal(byUnit.focus.slots.any.button.icon.mask.texture, BADGE_RIGHT, "focus icon also covers its level badge")
Equal(party1.slots.any.button.cooldown.countdownFont, "EraUIPortraitCCSmall", "party countdown uses the small font")

-- Unit changes refresh in combat, without touching restricted slots or reading auras.
combat = true
local before = target.updates
Fire("PLAYER_TARGET_CHANGED")
Equal(target.updates, before + 1, "target change refreshes the target container in combat")
before = byUnit.focus.updates
Fire("PLAYER_FOCUS_CHANGED")
Equal(byUnit.focus.updates, before + 1, "focus change refreshes the focus container")
Fire("GROUP_ROSTER_UPDATE")
combat = false

-- Party reassignment and new members ----------------------------------------------------

party[1].unit, party[2].unit = "party2", "party1"
Fire("GROUP_ROSTER_UPDATE")
Equal(party1.unit, "party2", "pooled party frame follows its new unit")
party[3] = Native("party3")
combat = true
Fire("GROUP_ROSTER_UPDATE")
Equal(#containers, 4, "no display is built in combat")
combat = false
Fire("PLAYER_REGEN_ENABLED")
Equal(#containers, 5, "the new party member gets its display after combat")

-- Player: loss of control, highest priority first -----------------------------------------

local playerContainer = PlayerFrame.PlayerFrameContainer
local overlay = Find(function(r) return r.parent == playerContainer and r.kind == "Frame" end)
local sweep = Find(function(r) return r.parent == overlay and r.kind == "Cooldown" end)
local icon = Find(function(r) return r.parent == overlay and r.kind == "Texture" end)
local time = Find(function(r) return r.kind == "FontString" and r.parent and r.parent.parent == sweep end)
Equal(overlay ~= nil and sweep ~= nil and icon ~= nil and time ~= nil, true, "player display built")
Equal(overlay.mouse, false, "player display is click-through")
Equal(overlay.shown, false, "hidden without a loss-of-control effect")
Equal(icon.mask ~= nil and icon.mask.texture, "Interface\\AddOns\\EraUI\\Media\\PortraitCCMaskLeft.tga",
    "player icon also covers the level badge below-left")

loc[1] = { iconTexture = 136100, startTime = 95, duration = 10, locType = "ROOT" }
combat = true
Fire("LOSS_OF_CONTROL_ADDED")
Equal(overlay.shown, true, "shows the active effect, in combat")
Equal(icon.texture, 136100, "shows the effect's icon")
Equal(sweep.start, 95, "sweep starts with the effect")
Equal(sweep.duration, 10, "sweep lasts the effect's duration")
Equal(sweep.hideNumbers, true, "player countdown is EraUI's own text")
overlay.scripts.OnUpdate(overlay, .2)
Equal(time.text, "5", "countdown shows seconds left")
now = 150
loc[1] = { iconTexture = 132090, startTime = 149, duration = 120, locType = "STUN" }
Fire("LOSS_OF_CONTROL_UPDATE")
overlay.scripts.OnUpdate(overlay, .2)
Equal(icon.texture, 132090, "switches to the new highest-priority effect")
Equal(time.text, "2m", "long effects count down in minutes")
loc[1] = { iconTexture = 132091, locType = "SILENCE" }
Fire("LOSS_OF_CONTROL_UPDATE")
Equal(sweep.start, nil, "an effect without a known end has no sweep")
Equal(time.text, "", "and no countdown")
loc[1] = nil
Fire("LOSS_OF_CONTROL_UPDATE")
Equal(overlay.shown, false, "hides when the effect ends")
loc[1] = { iconTexture = 136100, startTime = 150, duration = 2 }
Fire("LOSS_OF_CONTROL_ADDED")
now = 153
loc[1] = nil
overlay.scripts.OnUpdate(overlay, .2)
Equal(overlay.shown, false, "hides at expiry even without an update event")
combat = false

-- Turning it off -------------------------------------------------------------------------------

loc[1] = { iconTexture = 136100, startTime = 153, duration = 10 }
M:UpdatePlayer()
E.settings.portraitDebuffs = false
M:Refresh()
Equal(target.shown, false, "turning off hides the containers")
Equal(target.enabled, false, "and stops their updates")
Equal(overlay.shown, false, "and hides the player display")
local updates = target.updates
Fire("PLAYER_TARGET_CHANGED")
Equal(target.updates, updates, "no refreshes while off")
E.settings.portraitDebuffs = true
M:Refresh()
Equal(target.shown and target.enabled, true, "turning back on restores them without rebuilding")
Equal(#containers, 5, "no duplicate containers")
Equal(#printed, 0, "nothing failed to build")

-- A client without the aura container: the player display still works and
-- nothing errors or retries.
containers, all, driver = {}, {}, nil
buildFails = true
E.modules = {}
assert(loadfile("Modules/PortraitDebuffs.lua"))("EraUI", E)
M = E.modules.PortraitDebuffs
M:Initialize()
Equal(#printed, 1, "a failed build is reported once per session")
Equal(M.lastError ~= nil, true, "the failure reason is kept")
M:Refresh()
Equal(#printed, 1, "failures are not retried on every event")
Equal(Find(function(r) return r.parent == PlayerFrame.PlayerFrameContainer and r.kind == "Frame" end) ~= nil, true,
    "the player display still builds")
local savedOptions = CustomAuraContainerSlotDefaultOptions
CustomAuraContainerSlotDefaultOptions = nil
E.modules = {}
containers, all, driver = {}, {}, nil
printed = {}
assert(loadfile("Modules/PortraitDebuffs.lua"))("EraUI", E)
E.modules.PortraitDebuffs:Initialize()
Equal(#containers + #printed, 0, "no aura container API: the unit portraits are skipped quietly")
CustomAuraContainerSlotDefaultOptions = savedOptions

print("Portrait crowd-control checks passed: " .. checks .. " assertions.")
