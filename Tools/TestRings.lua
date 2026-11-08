-- Action Rings (Modules/ActionRings.lua and its Ring*.lua parts) on a mock
-- of the game: the secure choice (Modules/RingSnippet.lua) run in a strict
-- copy of the game's restricted environment, every slice kind's attributes,
-- drag and drop, the ready-made rings, the saved rings, the secure buttons
-- with a fight on (any change to a protected frame from ordinary code then
-- throws), the look, the key names, the editor in /era and the settings page
-- it sits on. Run alone with fengari from the addon's folder.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    if got ~= want then error(label .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end
local function Has(text, part) return type(text) == "string" and text:find(part, 1, true) ~= nil end
-- A number as text, to two places ("800", "1.5").
local function N(x) return string.format("%g", math.floor(x * 100 + .5) / 100) end
unpack = table.unpack or unpack

---------------------------------------------------------------------------
-- The mock world
---------------------------------------------------------------------------

local W = {combat = false, secure = false, now = 100, cursor = {800, 450}, frames = {}, timers = {}, scripts = {},
    casts = {}, wraps = {}, refs = {}, executes = 0, forbidden = {}, status = {}, prints = {}, saves = 0, tips = {}}
-- A hidden value: any compare, sum, join or length of it throws.
local SECRET = setmetatable({}, {__eq = function() error("compared a secret") end, __lt = function() error("compared a secret") end,
    __le = function() error("compared a secret") end, __concat = function() error("joined a secret") end,
    __add = function() error("added a secret") end, __sub = function() error("added a secret") end, __len = function() error("measured a secret") end,
    __tostring = function() return "SECRET" end})
issecretvalue = function(v) return rawequal(v, SECRET) end

local methods = {}
local Meta = {__index = methods}
local function Protected(f)
    if f.protected then return true end
    for _, child in ipairs(f.children) do if Protected(child) then return true end end
    return false
end
-- Ordinary code changing a protected frame (or a parent of one) in a fight.
local function Guard(f, what)
    if W.combat and not W.secure and Protected(f) then error("blocked in a fight: " .. what .. " on " .. tostring(f.name or f.kind), 3) end
end
local function Under(f, ancestor)
    f = f and f.parent
    while f do if f == ancestor then return true end; f = f.parent end
    return false
end
local function Frame(kind, name, parent, template)
    local f = setmetatable({kind = kind, name = name, parent = parent, template = template, children = {}, shown = true, points = {},
        attrs = {}, scripts = {}, hooks = {}, w = 0, h = 0, scale = 1, alpha = 1, level = 1}, Meta)
    f.protected = type(template) == "string" and template:find("Secure", 1, true) ~= nil
    if parent then parent.children[#parent.children + 1] = f end
    W.frames[#W.frames + 1] = f
    if name then _G[name] = f end
    return f
end
CreateFrame = function(kind, name, parent, template) return Frame(kind, name, parent or UIParent, template) end
local function Visit(f, event)
    if f.scripts[event] then f.scripts[event](f) end
    for _, fn in ipairs(f.hooks[event] or {}) do fn(f) end
    for _, child in ipairs(f.children) do if child.shown then Visit(child, event) end end
end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function methods:SetShown(v)
    Guard(self, v and "Show" or "Hide")
    v = not not v
    if self.shown == v then return end
    local before = not self.parent or self.parent:IsVisible()
    self.shown = v
    if before then Visit(self, v and "OnShow" or "OnHide") end
end
function methods:Show() self:SetShown(true) end
function methods:Hide() self:SetShown(false) end
function methods:SetScript(event, fn)
    W.scripts[#W.scripts + 1] = {frame = self, event = event}
    self.scripts[event] = fn
end
function methods:GetScript(event) return self.scripts[event] end
function methods:HookScript(event, fn)
    W.scripts[#W.scripts + 1] = {frame = self, event = event}
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], fn)
end
function methods:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, fn in ipairs(self.hooks[event] or {}) do fn(self, ...) end
end
function methods:SetPoint(point, rel, relPoint, x, y)
    Guard(self, "SetPoint")
    if type(rel) == "number" then x, y, rel, relPoint = rel, relPoint, self.parent, point
    elseif rel == nil and relPoint == nil then rel, relPoint, x, y = self.parent, point, 0, 0
    elseif type(relPoint) == "number" then x, y, relPoint = relPoint, x, point end
    for i, old in ipairs(self.points) do if old[1] == point then table.remove(self.points, i); break end end
    self.points[#self.points + 1] = {point, rel, relPoint or point, x or 0, y or 0}
end
function methods:ClearAllPoints() Guard(self, "ClearAllPoints"); self.points = {} end
function methods:SetAllPoints(rel) self:ClearAllPoints(); self:SetPoint("TOPLEFT", rel or self.parent, "TOPLEFT", 0, 0); self:SetPoint("BOTTOMRIGHT", rel or self.parent, "BOTTOMRIGHT", 0, 0) end
function methods:GetPoint(i) return unpack(self.points[i or 1] or {}) end
function methods:SetSize(w, h)
    Guard(self, "SetSize")
    local changed = self.w ~= w or self.h ~= h
    self.w, self.h = w, h
    if changed then self:Fire("OnSizeChanged", w, h) end
end
function methods:SetWidth(w) self:SetSize(w, self.h) end
function methods:SetHeight(h) self:SetSize(self.w, h) end
function methods:GetWidth() return self.w end
function methods:GetHeight() return self.h end
function methods:SetScale(s) Guard(self, "SetScale"); self.scale = s end
function methods:GetScale() return self.scale end
function methods:GetEffectiveScale() return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetAlpha(a) Guard(self, "SetAlpha"); self.alpha = a end
function methods:GetAlpha() return self.alpha end
function methods:SetAttribute(key, value) Guard(self, "SetAttribute"); self.attrs[key] = value end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:SetFrameStrata(s) Guard(self, "SetFrameStrata"); self.strata = s end
function methods:SetFrameLevel(l) Guard(self, "SetFrameLevel"); self.level = l end
function methods:GetFrameLevel() return self.level end
function methods:EnableMouse(v) Guard(self, "EnableMouse"); self.mouse = v end
function methods:EnableMouseWheel(v) self.wheel = v end
function methods:RegisterForClicks(...) Guard(self, "RegisterForClicks"); self.clicks = {...} end
function methods:SetParent(p)
    if self.parent then for i, c in ipairs(self.parent.children) do if c == self then table.remove(self.parent.children, i); break end end end
    self.parent = p
    if p then p.children[#p.children + 1] = self end
end
function methods:GetParent() return self.parent end
function methods:CreateTexture(_, layer, _, sub) local t = Frame("Texture", nil, self); t.layer, t.sub = layer, sub; return t end
function methods:CreateFontString(_, layer, template) local t = Frame("FontString", nil, self); t.layer, t.template = layer, template; t.text = ""; return t end
function methods:SetTexture(path) self.texture = path end
function methods:SetColorTexture(r, g, b, a) self.fill = {r, g, b, a} end
function methods:SetVertexColor(r, g, b, a) self.vertex = {r, g, b, a} end
function methods:SetTexCoord(...) self.coords = {...} end
function methods:SetDesaturated(v) self.desaturated = v end
function methods:SetBlendMode(m) self.blend = m end
function methods:SetRotation(r) self.rotation = r end
function methods:CreateMaskTexture() return Frame("MaskTexture", nil, self) end
function methods:AddMaskTexture(mask) self.masks = self.masks or {}; self.masks[#self.masks + 1] = mask end
function methods:SetSwipeTexture(path) self.swipe = path end
function methods:SetUseCircularEdge(v) self.circular = v end
function methods:SetText(text) self.text = text == nil and "" or tostring(text); if self.fontString then self.fontString:SetText(text) end end
function methods:GetText() return self.text or "" end
function methods:SetFont(file, size, flags) self.font = {file, size, flags} end
function methods:GetFont() return "font", 12, "" end
function methods:SetTextColor(r, g, b) self.colour = {r, g, b} end
function methods:SetJustifyH(v) self.justifyH = v end
function methods:SetJustifyV(v) self.justifyV = v end
function methods:SetWordWrap(v) self.wordWrap = v end
function methods:SetMaxLines(n) self.maxLines = n end
function methods:SetShadowColor() end
function methods:SetShadowOffset() end
-- As the game measures words: inside a width set earlier, at most that wide.
function methods:GetStringWidth()
    local whole = #(self.text or "") * 6
    return self.w > 0 and math.min(whole, self.w) or whole
end
function methods:SetBackdrop(b) self.backdrop = b end
function methods:SetBackdropColor(r, g, b, a) self.backdropColour = {r, g, b, a} end
function methods:SetBackdropBorderColor(r, g, b, a) self.borderColour = {r, g, b, a} end
function methods:SetDrawEdge(v) self.drawEdge = v end
function methods:SetDrawBling(v) self.drawBling = v end
function methods:SetHideCountdownNumbers(v) self.hideNumbers = v end
function methods:SetCooldown(start, length) self.cooldown = {start, length} end
function methods:SetCooldownFromDurationObject(duration)
    if duration == nil then error("no duration") end
    self.cooldown = {"duration", duration}
end
function methods:Clear() self.cooldown = nil end
function methods:SetTextInsets() end
function methods:SetAutoFocus() end
function methods:SetMaxLetters(n) self.maxLetters = n end
function methods:SetFocus()
    if W.focus == self then return end
    if W.focus then W.focus:ClearFocus() end
    W.focus = self
    self:Fire("OnEditFocusGained")
end
function methods:HasFocus() return W.focus == self end
function methods:ClearFocus()
    if W.focus ~= self then return end
    W.focus = nil
    self:Fire("OnEditFocusLost")
end
function methods:Click(button, down)
    self:Fire("PreClick", button, down)
    self:Fire("OnClick", button, down)
    self:Fire("PostClick", button, down)
end
function methods:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:RegisterUnitEvent(event) self.events = self.events or {}; self.events[event] = true end
function methods:UnregisterAllEvents() self.events = {} end

UIParent = Frame("Root", "UIParent")
UIParent.w, UIParent.h = 1600, 900
GameFontHighlight = Frame("Font")
GameFontHighlightSmall = GameFontHighlight
InCombatLockdown = function() return W.combat end
GetTime = function() return W.now end
GetCursorPosition = function() return W.cursor[1], W.cursor[2] end
C_Timer = {After = function(_, fn) W.timers[#W.timers + 1] = fn end}
local function Flush()
    for _ = 1, 20 do
        if #W.timers == 0 then return end
        local pending = W.timers; W.timers = {}
        for _, fn in ipairs(pending) do fn() end
    end
end
RAID_CLASS_COLORS = {MAGE = {r = .25, g = .78, b = .92}, ROGUE = {r = 1, g = .96, b = .41}, PALADIN = {r = .96, g = .55, b = .73},
    WARLOCK = {r = .53, g = .53, b = .93}, DRUID = {r = 1, g = .49, b = .04}, WARRIOR = {r = .78, g = .61, b = .43}}
W.class, W.className = "MAGE", "Mage"
UnitClass = function() return W.className, W.class end
Enum = {SpellBookSpellBank = {Player = 0, Pet = 1}, SpellBookItemType = {Spell = 1, Flyout = 2}}
NUM_BAG_SLOTS = 4

-- Calls that must never be made: binding changes, the game's tooltip,
-- MouseIsOver (absent on Forever) and Edit Mode.
for _, name in ipairs({"SetBinding", "SetBindingClick", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
    "SaveBindings", "LoadBindings", "MouseIsOver"}) do
    _G[name] = function() W.forbidden[#W.forbidden + 1] = name end
end
GameTooltip = setmetatable({}, {__index = function(_, key) W.forbidden[#W.forbidden + 1] = "GameTooltip." .. tostring(key); return function() end end})
EditModeManagerFrame = setmetatable({}, {__index = function(_, key) W.forbidden[#W.forbidden + 1] = "EditMode." .. tostring(key); return function() end end})

-- The game's secure handler calls: the header and refs as handles, the wrap
-- run as the game runs it (the pre-body; false stops the button's own click).
SecureHandlerSetFrameRef = function(header, label, frame)
    Guard(header, "SetFrameRef")
    assert(header.protected and frame.protected, "frame refs only between protected frames")
    W.refs[header] = W.refs[header] or {}
    W.refs[header][label] = frame
end
SecureHandlerWrapScript = function(frame, script, header, body)
    Guard(frame, "WrapScript")
    assert(script == "OnClick" and header.protected, "wraps a protected header's OnClick")
    W.wraps[frame] = {header = header, body = body}
end

---------------------------------------------------------------------------
-- The restricted environment (RestrictedEnvironment.lua's names; any other
-- global the snippet touched would throw) and frame handles.
---------------------------------------------------------------------------

local function Strict(extra)
    local env = {math = setmetatable({}, {__index = {deg = math.deg, floor = math.floor, rad = math.rad, abs = math.abs,
        atan2 = function(y, x) return math.atan(y, x) end}, __newindex = function() error("math is read only") end})}
    for _, name in ipairs({"select", "tonumber", "tostring", "type", "format", "strsub", "strfind", "abs", "floor", "max", "min",
        "GetBindingKey", "PlayerInCombat", "print", "newtable", "pairs", "ipairs", "wipe", "tinsert", "SecureCmdOptionParse",
        "IsModifierKeyDown"}) do env[name] = function() error(name .. " stub called") end end
    for key, value in pairs(extra or {}) do env[key] = value end
    return setmetatable(env, {__index = function(_, key) error("the snippet used a global it doesn't have: " .. tostring(key)) end})
end

-- A protected frame as the snippet sees it.
local HandleFrame = setmetatable({}, {__mode = "k"})
-- Where a frame is, in its own units: the whole screen when it's set to all
-- of UIParent, else round the centre the snippet gave it.
local function Rect(frame)
    local p = frame.points
    if p[1] and p[2] and p[1][1] == "TOPLEFT" and p[2][1] == "BOTTOMRIGHT" and p[1][2] == UIParent and p[2][2] == UIParent then
        return 0, 0, UIParent.w, UIParent.h
    end
    local c = frame.centre or {0, 0}
    return c[1] - frame.w / 2, c[2] - frame.h / 2, frame.w, frame.h
end
local function Handle(frame)
    local h = {}
    HandleFrame[h] = frame
    function h:IsShown() return frame.shown end
    function h:Show() local was = W.secure; W.secure = true; frame:Show(); W.secure = was end
    function h:Hide() local was = W.secure; W.secure = true; frame:Hide(); W.secure = was end
    function h:ClearAllPoints() local was = W.secure; W.secure = true; frame:ClearAllPoints(); W.secure = was end
    -- At the cursor, or (as RestrictedFrames.lua allows) on another protected
    -- frame's handle: the snippet uses the screen frame's bottom left.
    function h:SetPoint(point, rel, relPoint, x, y)
        assert(point == "CENTER", "placed by its centre")
        local eff = frame:GetEffectiveScale()
        local cx, cy
        if rel == "$cursor" then
            cx, cy = W.cursor[1] / eff, W.cursor[2] / eff
        else
            local other = HandleFrame[rel]
            assert(other and other.protected and relPoint == "BOTTOMLEFT" and type(x) == "number" and type(y) == "number",
                "placed on a protected frame's bottom left")
            local left, bottom = Rect(other)
            cx, cy = left + x, bottom + y
        end
        local was = W.secure; W.secure = true
        frame:SetPoint("CENTER", nil, "BOTTOMLEFT", cx, cy)
        W.secure = was
        frame.centre = {cx, cy}
    end
    -- Fractions of the frame, nil outside it (RestrictedFrames.lua).
    function h:GetMousePosition()
        local eff = frame:GetEffectiveScale()
        local left, bottom, w, h2 = Rect(frame)
        if w == 0 or h2 == 0 then return nil end
        local x = (W.cursor[1] / eff - left) / w
        local y = (W.cursor[2] / eff - bottom) / h2
        if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
        return x, y
    end
    function h:GetWidth() return select(3, Rect(frame)) end
    function h:GetHeight() return select(4, Rect(frame)) end
    function h:GetAttribute(key) return frame.attrs[key] end
    function h:SetAttribute(key, value)
        assert(type(key) == "string" and not key:find("^_"), "no _ attribute names")
        local was = W.secure; W.secure = true; frame:SetAttribute(key, value); W.secure = was
    end
    function h:GetFrameRef(label)
        local ref = W.refs[frame] and W.refs[frame][label]
        return ref and Handle(ref) or nil
    end
    return h
end

local compiled = {}
local function Run(body, signature, ...)
    local key = signature .. body
    local fn, env = compiled[key] and compiled[key][1], compiled[key] and compiled[key][2]
    if not fn then
        env = Strict({owner = false})
        fn = assert(load("local " .. signature .. " = ...\n" .. body, "snippet", "t", env))
        compiled[key] = {fn, env}
    end
    return fn, env
end
SecureHandlerExecute = function(header, body)
    Guard(header, "Execute")
    W.executes = W.executes + 1
    local fn = Run(body, "self")
    local was = W.secure; W.secure = true
    fn(Handle(header))
    W.secure = was
end

-- A key on a ring button, down or up, as the binding clicks it: the wrap's
-- pre-body (secure), the button's own click (acts on the up click: the
-- game casts what type and its key say), then PostClick (ordinary code).
local function Press(button, down)
    local wrap = W.wraps[button]
    local result
    if wrap then
        local fn, env = Run(wrap.body, "self, button, down")
        env.owner = Handle(wrap.header)
        local was = W.secure; W.secure = true
        result = fn(Handle(button), "LeftButton", down)
        W.secure = was
    end
    if result ~= false and not down and button.attrs.useOnKeyDown == false then
        local a = button.attrs
        local key = ({spell = "spell", item = "item", macro = a.macro and "macro" or "macrotext", equipmentset = "equipmentset", toy = "toy",
            raidtarget = "marker", worldmarker = "marker"})[a.type]
        W.casts[#W.casts + 1] = {type = a.type, value = key and a[key], action = a.action, slot = a["target-slot"], macro = a.macro,
            macrotext = a.macrotext, combat = W.combat}
    end
    if button.scripts.PostClick then button.scripts.PostClick(button, "LeftButton", down) end
    return result
end

---------------------------------------------------------------------------
-- The game's data: a mage's spellbook, bags, journals, macros and sets
---------------------------------------------------------------------------

local G = {}
local function Reset()
    G.spells = {} -- id -> {name, rank, icon, passive}
    G.book = {}   -- spellbook slots, in order: ids
    G.known = {}  -- extra known ids (IsPlayerSpell)
    G.bags = {}   -- [bag] = {[slot] = {id, count, name, quest = {isQuestItem, questID, isActive}}}
    G.items = {}  -- id -> {name, class, sub, use, icon}
    G.counts = {} -- id -> count (else from bags)
    G.cooldowns = {} -- item id -> {start, length}
    G.mounts = {} -- id -> {name, spell, icon, collected, hidden, favourite}
    G.mountOrder = {}
    G.displayed = {} -- display index -> mount id
    G.pets = {}   -- guid -> {species, name, custom, icon, revoked}
    G.petOrder = {}
    G.toys = {}   -- item id -> {name, icon, owned}
    G.toyOrder = {}
    G.macros = {} -- index -> {name, icon}
    G.sets = {}   -- id -> {name, icon}
    G.cursor = nil
    G.cleared = 0
    G.bindings = {}
    G.offhand = nil
    G.spellCooldown = {}
end
Reset()
local function Spell(id, name, rank, extra)
    G.spells[id] = {name = name, rank = rank, icon = 1000 + id, passive = extra and extra.passive}
    if not (extra and extra.unlearned) then G.book[#G.book + 1] = id end
end
C_Spell = {
    GetSpellName = function(id) local s = G.spells[id]; return s and s.name end,
    GetSpellTexture = function(id) local s = G.spells[id]; return s and s.icon end,
    GetSpellSubtext = function(id) local s = G.spells[id]; return s and s.rank and ("Rank " .. s.rank) or nil end,
    IsSpellUsable = function(id) return G.spells[id] and not G.spells[id].unusable, false end,
    GetSpellCooldown = function(id) return G.spellCooldown[id] or {startTime = 0, duration = 0, isEnabled = true, isOnGCD = false} end,
    GetSpellCooldownDuration = function(id) return G.spellCooldown[id] and G.spellCooldown[id].object or nil end,
}
C_SpellBook = {
    GetNumSpellBookSkillLines = function() return 2 end,
    GetSpellBookSkillLineInfo = function(line)
        if line == 1 then return {itemIndexOffset = 0, numSpellBookItems = 2} end
        return {itemIndexOffset = 2, numSpellBookItems = math.max(0, #G.book - 2), shouldHide = false, offSpecID = nil}
    end,
    GetSpellBookItemInfo = function(slot)
        local id = G.book[slot]
        local s = id and G.spells[id]
        if not s then return nil end
        return {itemType = 1, actionID = id, spellID = id, name = s.name, subName = s.rank and ("Rank " .. s.rank) or "", isPassive = s.passive == true}
    end,
}
IsPlayerSpell = function(id) return G.known[id] == true end
C_Container = {
    GetContainerNumSlots = function(bag) return G.bags[bag] and 16 or 0 end,
    GetContainerItemInfo = function(bag, slot)
        local entry = G.bags[bag] and G.bags[bag][slot]
        if not entry then return nil end
        local item = G.items[entry.id] or {}
        return {itemID = entry.id, stackCount = entry.count or 1, isLocked = false, itemName = item.name, iconFileID = item.icon}
    end,
    GetContainerItemQuestInfo = function(bag, slot)
        local entry = G.bags[bag] and G.bags[bag][slot]
        local quest = entry and entry.quest or {}
        return {isQuestItem = quest.isQuestItem == true, questID = quest.questID, isActive = quest.isActive == nil and false or quest.isActive}
    end,
}
local function Count(id)
    if G.counts[id] ~= nil then return G.counts[id] end
    local n = 0
    for _, bag in pairs(G.bags) do for _, entry in pairs(bag) do if entry.id == id then n = n + (entry.count or 1) end end end
    return n
end
C_Item = {
    GetItemInfoInstant = function(id) local i = G.items[id]; if not i then return nil end; return id, "", "", "", i.icon, i.class or 0, i.sub or 0 end,
    GetItemSpell = function(id) local i = G.items[id]; if i and i.use then return "Use", 999 end end,
    GetItemCount = function(id) return Count(id) end,
    GetItemCooldown = function(id) local c = G.cooldowns[id]; if c then return c[1], c[2], true end; return 0, 0, true end,
    GetItemNameByID = function(id) return G.items[id] and G.items[id].name end,
    GetItemIconByID = function(id) return G.items[id] and G.items[id].icon end,
}
GetInventoryItemID = function(_, slot) if slot == 17 then return G.offhand end end
C_MountJournal = {
    GetMountIDs = function() return G.mountOrder end,
    GetMountInfoByID = function(id)
        local m = G.mounts[id]
        if not m then return nil end
        return m.name, m.spell, m.icon, false, true, 0, m.favourite == true, false, nil, m.hidden == true, m.collected == true, id
    end,
    GetDisplayedMountInfo = function(index)
        local id = G.displayed[index]
        if not id then return nil end
        return C_MountJournal.GetMountInfoByID(id)
    end,
}
C_PetJournal = {
    GetPetInfoByPetID = function(guid)
        local p = G.pets[guid]
        if not p then return nil end
        return p.species, p.custom, 1, 0, 0, 0, false, p.name, p.icon
    end,
    PetIsRevoked = function(guid) return G.pets[guid] and G.pets[guid].revoked == true end,
    GetNumPets = function() return #G.petOrder, #G.petOrder end,
    GetPetInfoByIndex = function(i)
        local guid = G.petOrder[i]
        local p = G.pets[guid]
        return guid, p.species, p.owned ~= false, p.custom, 1, false, p.revoked == true, p.name, p.icon
    end,
}
C_ToyBox = {
    GetToyInfo = function(id) local t = G.toys[id]; if t then return id, t.name, t.icon end end,
    GetNumFilteredToys = function() return #G.toyOrder end,
    GetToyFromIndex = function(i) return G.toyOrder[i] or -1 end,
}
PlayerHasToy = function(id) return G.toys[id] ~= nil and G.toys[id].owned ~= false end
C_EquipmentSet = {
    GetEquipmentSetID = function(name) for id, s in pairs(G.sets) do if s.name == name then return id end end end,
    GetEquipmentSetInfo = function(id) local s = G.sets[id]; if s then return s.name, s.icon, id end end,
    GetEquipmentSetIDs = function() local ids = {}; for id in pairs(G.sets) do ids[#ids + 1] = id end; table.sort(ids); return ids end,
}
GetMacroIndexByName = function(name) for i, m in pairs(G.macros) do if m.name == name then return i end end; return 0 end
GetMacroInfo = function(index)
    if type(index) == "string" then index = GetMacroIndexByName(index) end
    local m = G.macros[index]
    if m then return m.name, m.icon, "/say hi" end
end
GetNumMacros = function()
    local account, character = 0, 0
    for i in pairs(G.macros) do if i <= 120 then account = math.max(account, i) else character = math.max(character, i - 120) end end
    return account, character
end
MAX_ACCOUNT_MACROS = 120
GetProfessions = function() return nil, nil, nil, 4, 5 end
GetProfessionInfo = function(index)
    if index == 4 then return "Fishing", 1, 75, 75, 1, 40 end
    if index == 5 then return "Cooking", 1, 75, 75, 1, 41 end
end
GetCursorInfo = function() if G.cursor then return unpack(G.cursor) end end
ClearCursor = function() G.cleared = G.cleared + 1; G.cursor = nil end
GetBindingKey = function(action) return G.bindings[action] end
GetBindingText = function(key) return key == "BUTTON4" and "Mouse Button 4" or key end
for i, name in ipairs({"Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull"}) do _G["RAID_TARGET_" .. i] = name end

-- A mage's book: Conjure Water ranks 1 to 3 (rank 3 the highest), Conjure
-- Food rank 1, Teleport: Stormwind, Arcane Intellect 1 and 2, a passive.
local function MageBook()
    G.spells, G.book = {}, {}
    Spell(5504, "Conjure Water", 1)
    Spell(5505, "Conjure Water", 2)
    Spell(5506, "Conjure Water", 3)
    Spell(587, "Conjure Food", 1)
    Spell(3561, "Teleport: Stormwind", nil)
    Spell(1459, "Arcane Intellect", 1)
    Spell(1460, "Arcane Intellect", 2)
    Spell(10054, "Conjure Mana Ruby", nil, {unlearned = true})
    Spell(759, "Conjure Mana Agate", nil)
    Spell(9999, "Some Passive", nil, {passive = true})
    Spell(3562, "Teleport: Ironforge", nil, {unlearned = true})
    Spell(7620, "Fishing", nil)
    G.book[41] = 7620
end

---------------------------------------------------------------------------
-- EraUI: the real Init (settings, key names), Rows, ClassTools, PoisonData
-- and the ring files, in the .toc's order.
---------------------------------------------------------------------------

EraUIDB, EraUIClassicCharDB = {}, {}
local E = {}
assert(loadfile("Core/Init.lua"))("EraUI", E)
for key, value in pairs(E.settingDefaults) do EraUIDB[key] = value end
EraUIDB.enabled = true
function E:SaveSettings() W.saves = W.saves + 1 end
function E:Status(text) W.status[#W.status + 1] = text end
function E:Print(text) W.prints[#W.prints + 1] = text end
E.Classic = {DarkGrey = function() return .3, .31, .34 end}
E.Look = {ShowTip = function(_, _, rows) W.tips[#W.tips + 1] = rows[1][1]; W.tipRows = rows end, HideTip = function() end}
assert(loadfile("Core/SettingsRows.lua"))("EraUI", E)
assert(loadfile("Modules/PoisonData.lua"))("EraUI", E)
assert(loadfile("Modules/ClassTools.lua"))("EraUI", E)
local RING_FILES = {"RingSnippet", "RingClassData", "RingData", "RingFill", "RingSecure", "RingView", "RingEditor", "RingRows", "ActionRings"}
for _, name in ipairs(RING_FILES) do assert(loadfile("Modules/" .. name .. ".lua"))("EraUI", E) end
local RS, D, F, S, V, Ed, M = E.RingSnippet, E.RingData, E.RingFill, E.RingSecure, E.RingView, E.RingEditor, E.modules.ActionRings
equal(M ~= nil and M.name, "ActionRings", "the module registers as ActionRings")

---------------------------------------------------------------------------
-- 1. The snippet's text: what the restricted environment accepts
---------------------------------------------------------------------------

for name, body in pairs({PICK = RS.PICK, CLOSE = RS.CLOSE}) do
    equal(body:find("function", 1, true), nil, name .. ": no function keyword (the game refuses the body)")
    equal(body:find("[{}]"), nil, name .. ": no braces (no table made)")
    equal(body:find("--", 1, true), nil, name .. ": no comment")
    local bare = body:gsub("~=", "")
    equal(bare:find("[&|~]") or bare:find("<<", 1, true) or bare:find(">>", 1, true) or bare:find("//", 1, true)
        or bare:find("::", 1, true) or bare:find("goto", 1, true), nil, name .. ": no Lua 5.2+ syntax")
    equal(body:find('SetAttribute("_', 1, true), nil, name .. ": no _ attribute names")
    equal(load("local self, button, down, owner = ...\n" .. body) ~= nil, true, name .. ": compiles")
end
equal(#RS.LIVE, 10, "ten live attributes cleared each pick")
for _, live in ipairs(RS.LIVE) do equal(Has(RS.PICK, 'self:SetAttribute("' .. live .. '", nil)'), true, "PICK clears " .. live) end

---------------------------------------------------------------------------
-- 2 to 7. The snippet on handles, in the strict environment
---------------------------------------------------------------------------

-- A small world of its own: a header, the screen frame (unless noScreen),
-- ten 4096 hit frames, ring buttons.
local function SnipWorld(scale, noScreen)
    local world = {header = Frame("Frame", nil, UIParent, "SecureHandlerBaseTemplate"), hits = {}, buttons = {}}
    W.refs[world.header] = {}
    if not noScreen then
        world.screen = Frame("Frame", nil, UIParent, "SecureFrameTemplate")
        world.screen:SetAllPoints(UIParent)
        W.refs[world.header].screen = world.screen
    end
    for i = 1, 10 do
        local hit = Frame("Frame", nil, UIParent, "SecureFrameTemplate")
        hit.w, hit.h, hit.shown = RS.HIT, RS.HIT, false
        world.hits[i] = hit
        W.refs[world.header] = W.refs[world.header] or {}
        W.refs[world.header]["ring" .. i] = hit
        local button = Frame("Button", nil, UIParent, "SecureActionButtonTemplate")
        button.attrs = {["ring-slot"] = i, ["ring-count"] = 0, useOnKeyDown = false, dead2 = RS.Dead2(scale or 1)}
        W.wraps[button] = {header = world.header, body = RS.PICK}
        world.buttons[i] = button
    end
    return world
end
local function Fill(button, n, kind, key)
    button.attrs["ring-count"] = n
    for k = 1, 16 do
        local pre = "s" .. k .. "-"
        if k <= n then
            button.attrs[pre .. "type"], button.attrs[pre .. "key"], button.attrs[pre .. "value"] = kind or "spell", key or "spell", 1000 + k
        else
            button.attrs[pre .. "type"], button.attrs[pre .. "key"], button.attrs[pre .. "value"] = nil, nil, nil
        end
    end
end
-- Down at the centre, then the cursor moved by fractions (fx, fy) of the
-- hit frame from the centre, then up: the result, chosen and the cast.
local function Flick(world, i, fx, fy)
    W.cursor = {800, 450}
    W.casts = {}
    local downResult = Press(world.buttons[i], true)
    if fx then
        local eff = world.hits[i]:GetEffectiveScale()
        W.cursor = {800 + fx * RS.HIT * eff, 450 + fy * RS.HIT * eff}
    else
        W.cursor = {800 + 5000, 450}
    end
    local result = Press(world.buttons[i], false)
    return result, world.buttons[i].attrs.chosen, W.casts[1], downResult
end

do
    local world = SnipWorld(1)
    local button, hit = world.buttons[1], world.hits[1]
    local dead = math.sqrt(RS.Dead2(1))
    for n = 1, 16 do
        Fill(button, n)
        local step = 360 / n
        for k = 1, n do
            for _, radius in ipairs({.02, .1, .3, .49}) do
                local a = math.rad((k - 1) * step)
                local result, chosen, cast, down = Flick(world, 1, radius * math.sin(a), radius * math.cos(a))
                if down ~= false or result ~= nil or chosen ~= k or not cast or cast.value ~= 1000 + k or hit.shown then
                    equal(string.format("%s %s %s %s", tostring(down), tostring(result), tostring(chosen), tostring(cast and cast.value)),
                        string.format("false nil %d %d", k, 1000 + k), "n " .. n .. " slice " .. k .. " at radius " .. radius)
                end
                checks = checks + 1
            end
            -- Either side of the boundary after slice k: k, then its neighbour.
            if n > 1 then
                for _, side in ipairs({-.5, .5}) do
                    local a = math.rad((k - .5) * step + side)
                    local _, chosen = Flick(world, 1, .3 * math.sin(a), .3 * math.cos(a))
                    local want = side < 0 and k or (k % n + 1)
                    if chosen ~= want then equal(chosen, want, "n " .. n .. " boundary after " .. k .. " side " .. side) end
                    checks = checks + 1
                end
            end
        end
        -- Just inside the middle: nothing, and nothing cast.
        button.attrs.type = "stale"
        local result, chosen, cast = Flick(world, 1, dead * .98, 0)
        equal(tostring(result) .. " " .. chosen .. " " .. tostring(cast) .. " " .. button.attrs.type, "false 0 nil stale",
            "n " .. n .. ": let go in the middle picks nothing, live attributes untouched")
    end
    -- Off the hit frame (nil position), and an empty ring.
    Fill(button, 4)
    local result, chosen, cast = Flick(world, 1, nil)
    equal(tostring(result) .. " " .. chosen .. " " .. tostring(cast) .. " " .. tostring(hit.shown), "false 0 nil false", "outside the frame: nothing, ring away")
    Fill(button, 0)
    result, chosen = Flick(world, 1, .3, 0)
    equal(tostring(result) .. " " .. chosen, "false 0", "an empty ring: nothing")
    -- A slice with no type, or no key (greyed: it can't be used now): refused,
    -- chosen -3 (so nothing pops or is noted as cast); the stale type stays
    -- but no click goes through.
    Fill(button, 4)
    button.attrs.type, button.attrs.spell = "spell", 1003
    button.attrs["s2-type"] = nil
    result, chosen, cast = Flick(world, 1, .3, 0)
    equal(tostring(result) .. " " .. chosen .. " " .. tostring(cast) .. " " .. button.attrs.type .. " " .. button.attrs.spell,
        "false -3 nil spell 1003", "a slice with no type: the click is refused, chosen -3, live attributes untouched")
    Fill(button, 4)
    button.attrs["s2-key"] = nil
    result, chosen, cast = Flick(world, 1, .3, 0)
    equal(tostring(result) .. " " .. chosen .. " " .. tostring(cast), "false -3 nil", "a slice with no key: refused, chosen -3")
    -- 5. Stale attributes cleared: a pet (macro text), then a spell; a poison, then a spell.
    Fill(button, 4)
    button.attrs["s1-type"], button.attrs["s1-key"], button.attrs["s1-value"] = "macro", "macrotext", "/summonpet BattlePet-1"
    button.attrs["s2-type"], button.attrs["s2-key"], button.attrs["s2-value"], button.attrs["s2-slot"] = "item", "item", "item:6947", 16
    result, chosen, cast = Flick(world, 1, 0, .3)
    equal(cast.type .. " " .. cast.macrotext .. " " .. tostring(cast.macro), "macro /summonpet BattlePet-1 nil", "a pet: its macro text")
    result, chosen, cast = Flick(world, 1, 0, -.3)
    equal(cast.type .. " " .. cast.value .. " " .. tostring(button.attrs.macrotext) .. " " .. tostring(button.attrs.macro), "spell 1003 nil nil",
        "then a spell: the macro text is gone")
    result, chosen, cast = Flick(world, 1, .3, 0)
    equal(cast.type .. " " .. cast.value .. " " .. tostring(cast.slot), "item item:6947 16", "a poison: the item and its weapon slot")
    result, chosen, cast = Flick(world, 1, 0, -.3)
    equal(cast.type .. " " .. tostring(button.attrs["target-slot"]) .. " " .. tostring(button.attrs.item), "spell nil nil", "then a spell: no weapon slot left")
    -- 6. Down and up in their order.
    Fill(button, 4)
    W.cursor = {800, 450}
    equal(Press(button, true), false, "down: the click does nothing")
    local point = hit.points[1]
    equal(hit.shown and point[1] .. " " .. N(point[4]) .. " " .. N(point[5]), "CENTER 800 450", "down: the ring shows centred on the cursor")
    W.cursor = {900, 500}
    equal(Press(button, true), false, "a second down while it shows")
    equal(N(hit.points[1][4]) .. " " .. N(hit.points[1][5]), "800 450", "changes nothing (the ring never jumps)")
    local other = world.buttons[2]
    Fill(other, 3)
    Press(other, true)
    equal(tostring(hit.shown) .. " " .. tostring(world.hits[2].shown) .. " " .. tostring(world.header.attrs["open-ring"]),
        "false true 2", "ring 2 down puts ring 1 away and owns the open ring")
    W.casts = {}
    equal(tostring(Press(button, false)) .. " " .. button.attrs.chosen .. " " .. #W.casts, "false -2 0", "ring 1's up then: nothing")
    W.cursor = {800, 450}
    Press(other, false)
    equal(tostring(world.hits[2].shown) .. " " .. tostring(world.header.attrs["open-ring"]), "false nil", "ring 2's up closes it")
    equal(tostring(Press(button, false)) .. " " .. button.attrs.chosen, "false -2", "an up with no down: nothing")
    button.attrs["ring-off"] = true
    button.attrs.chosen = nil
    equal(tostring(Press(button, true)) .. " " .. tostring(hit.shown) .. " " .. tostring(button.attrs.chosen), "false false nil", "ring-off: nothing shows")
    button.attrs["ring-off"] = nil
    -- 7. CLOSE: every ring away, no ring open.
    Press(button, true)
    world.hits[5].shown = true
    SecureHandlerExecute(world.header, RS.CLOSE)
    local open = 0
    for _, h in ipairs(world.hits) do if h.shown then open = open + 1 end end
    equal(open .. " " .. tostring(world.header.attrs["open-ring"]), "0 nil", "CLOSE hides every ring and clears the open one")
end

---------------------------------------------------------------------------
-- 7b. Near the screen's edges: the ring moved in to show whole (its reach
-- up and to the sides 110, down 136), every slice still reachable, and a
-- tap where it opened still nothing
---------------------------------------------------------------------------

do
    local world = SnipWorld(1)
    local button, hit = world.buttons[1], world.hits[1]
    local SIDE, FOOT = 110, 136
    button.attrs["ring-edge"], button.attrs["ring-foot"], button.attrs.tap2 = SIDE, FOOT, RS.Tap2(1)
    local SW, SH = UIParent.w, UIParent.h
    -- Opens with the cursor at (ox, oy), lets go at (rx, ry), in screen units
    -- (UIParent's scale is 1 here): what was chosen, cast, and the centre.
    local function At(ox, oy, rx, ry)
        W.casts = {}
        W.cursor = {ox, oy}
        Press(button, true)
        local centre = {hit.centre[1], hit.centre[2]}
        W.cursor = {rx, ry}
        Press(button, false)
        return button.attrs.chosen, W.casts[1], centre
    end
    local places = {{10, 5, 110, 136, "the bottom left corner"}, {800, 0, 800, 136, "the bottom edge"},
        {1595, 450, 1490, 450, "the right edge"}, {1600, 900, 1490, 790, "the top right corner"},
        {0, 450, 110, 450, "the left edge"}, {800, 899, 800, 790, "the top edge"},
        {800, 450, 800, 450, "the middle of the screen"}, {111, 137, 111, 137, "just inside the margins"}}
    Fill(button, 8)
    for _, place in ipairs(places) do
        local chosen, cast, centre = At(place[1], place[2], place[1], place[2])
        equal(N(centre[1]) .. " " .. N(centre[2]), N(place[3]) .. " " .. N(place[4]), place[5] .. ": the ring's centre")
        local x, y = RS.Clamp(place[1], place[2], SW, SH, SIDE, FOOT)
        equal(N(x) .. " " .. N(y), N(place[3]) .. " " .. N(place[4]), place[5] .. ": the mirror's centre")
        equal(chosen .. " " .. tostring(cast), "0 nil", place[5] .. ": a tap where it opened picks nothing")
        local step = place[1] < 800 and 5 or -5
        chosen, cast = At(place[1], place[2], place[1] + step, place[2])
        equal(chosen .. " " .. tostring(cast), "0 nil", place[5] .. ": moved less than a tap: still nothing")
    end
    -- Every slice, 60 out from the centre towards it: on the screen, and picked.
    for _, n in ipairs({4, 8, 16}) do
        Fill(button, n)
        for _, place in ipairs(places) do
            local cx, cy = RS.Clamp(place[1], place[2], SW, SH, SIDE, FOOT)
            for k = 1, n do
                local a = math.rad(RS.SliceAngle(k, n))
                local rx, ry = cx + 60 * math.sin(a), cy + 60 * math.cos(a)
                local seen = rx >= 0 and rx <= SW and ry >= 0 and ry <= SH
                local chosen, cast = At(place[1], place[2], rx, ry)
                if not seen or chosen ~= k or not cast or cast.value ~= 1000 + k then
                    equal(tostring(seen) .. " " .. tostring(chosen) .. " " .. tostring(cast and cast.value), "true " .. k .. " " .. (1000 + k),
                        place[5] .. ": n " .. n .. " slice " .. k)
                end
                checks = checks + 1
            end
        end
    end
    -- Before: opened on the bottom edge round the cursor, the slices pointing
    -- down (4, 5 and 6 of 8) could never be reached.
    Fill(button, 8)
    local reached = {}
    for _, rx in ipairs({700, 790, 900}) do
        local chosen = At(800, 0, rx, 0)
        if chosen > 0 then reached[chosen] = true end
    end
    equal(tostring(reached[4]) .. " " .. tostring(reached[5]) .. " " .. tostring(reached[6]), "true true true",
        "from the bottom edge, the slices pointing down are reached along it")
    -- A screen too small for the ring: its middle.
    local x, y = RS.Clamp(10, 10, 200, 150, SIDE, FOOT)
    equal(N(x) .. " " .. N(y), "100 75", "a screen smaller than the ring: centred on it")
    -- No screen frame (a client without it): at the cursor itself, as before.
    local bare = SnipWorld(1, true)
    local lone = bare.buttons[1]
    lone.attrs["ring-edge"], lone.attrs["ring-foot"] = SIDE, FOOT
    Fill(lone, 4)
    W.cursor = {10, 5}
    Press(lone, true)
    equal(N(bare.hits[1].centre[1]) .. " " .. N(bare.hits[1].centre[2]) .. " " .. tostring(lone.attrs["open-dx"]), "10 5 0",
        "no screen frame: centred on the cursor")
    W.cursor = {10, 105}
    Press(lone, false)
    equal(lone.attrs.chosen, 1, "and it picks round it")
end

---------------------------------------------------------------------------
-- 8. The plain Lua mirror picks what the snippet picks, at every scale
---------------------------------------------------------------------------

do
    local seed = 12345
    local function Random() seed = (seed * 1103515245 + 12345) % 2147483648; return seed / 2147483648 end
    for _, scale in ipairs({.75, 1, 1.5}) do
        local world = SnipWorld(scale)
        local button = world.buttons[1]
        local same, total = 0, 0
        for n = 1, 16 do
            Fill(button, n)
            for _ = 1, 400 do
                -- Mostly near the ring, some in or near the middle.
                local reach = (Random() < .2) and (Random() * 3 * RS.DEAD * scale / RS.HIT) or (Random() * .45)
                local a = Random() * 2 * math.pi
                local fx, fy = reach * math.sin(a), reach * math.cos(a)
                local _, chosen = Flick(world, 1, fx, fy)
                local mirror = RS.Pick(fx * RS.HIT / scale, fy * RS.HIT / scale, n, RS.DEAD)
                total = total + 1
                if chosen == mirror then same = same + 1 else equal(mirror, chosen, "mirror at scale " .. scale .. " n " .. n) end
            end
        end
        equal(same, total, "scale " .. scale .. ": the mirror matches the snippet on " .. total .. " releases")
    end
    -- Opened anywhere, often near an edge (so moved in), let go anywhere on
    -- the screen, often near where it opened: the mirror, with Clamp and the
    -- tap, still picks what the snippet picks.
    for _, scale in ipairs({.75, 1, 1.5}) do
        local world = SnipWorld(scale)
        local button = world.buttons[1]
        local side, foot = 110 * scale, 136 * scale
        button.attrs["ring-edge"], button.attrs["ring-foot"], button.attrs.tap2 = side, foot, RS.Tap2(scale)
        local SW, SH = UIParent.w, UIParent.h
        local same, total, moved = 0, 0, 0
        for n = 1, 16 do
            Fill(button, n)
            for _ = 1, 150 do
                local ox, oy = Random() * SW, Random() * SH
                if Random() < .5 then ox = Random() < .5 and Random() * 60 or SW - Random() * 60 end
                if Random() < .5 then oy = Random() < .5 and Random() * 60 or SH - Random() * 60 end
                local cx, cy = RS.Clamp(ox, oy, SW, SH, side, foot)
                local rx, ry
                if Random() < .25 then
                    rx, ry = ox + (Random() - .5) * 4 * RS.TAP * scale, oy + (Random() - .5) * 4 * RS.TAP * scale
                else
                    local reach, a = Random() * 200 * scale, Random() * 2 * math.pi
                    rx, ry = cx + reach * math.sin(a), cy + reach * math.cos(a)
                end
                rx, ry = math.max(0, math.min(SW, rx)), math.max(0, math.min(SH, ry))
                W.cursor = {ox, oy}
                Press(button, true)
                if cx ~= ox or cy ~= oy then moved = moved + 1 end
                W.cursor = {rx, ry}
                Press(button, false)
                local chosen = button.attrs.chosen
                local mirror = RS.Pick((rx - cx) / scale, (ry - cy) / scale, n, RS.DEAD, (ox - cx) / scale, (oy - cy) / scale, RS.TAP)
                total = total + 1
                if chosen == mirror then same = same + 1 else equal(mirror, chosen, "moved in, scale " .. scale .. " n " .. n) end
            end
        end
        equal(same, total, "scale " .. scale .. ": opened anywhere, the mirror matches the snippet on " .. total .. " releases")
        equal(moved > total / 3, true, "scale " .. scale .. ": many of them moved in from an edge (" .. moved .. ")")
    end
    -- Let go off the hit frame on either axis (a very wide screen) as often
    -- as on it: the mirror, given the frame's half-size, picks nothing there
    -- as the snippet does.
    for _, scale in ipairs({.75, 1, 1.5}) do
        local world = SnipWorld(scale)
        local button = world.buttons[1]
        local same, total, off = 0, 0, 0
        for n = 1, 16 do
            Fill(button, n)
            for _ = 1, 40 do
                local fx, fy = (Random() - .5) * 1.4, (Random() - .5) * 1.4
                local _, chosen = Flick(world, 1, fx, fy)
                local mirror = RS.Pick(fx * RS.HIT / scale, fy * RS.HIT / scale, n, RS.DEAD, nil, nil, nil, RS.Reach(scale))
                if math.abs(fx) > .5 or math.abs(fy) > .5 then off = off + 1 end
                total = total + 1
                if chosen == mirror then same = same + 1 else equal(mirror, chosen, "off the frame, scale " .. scale .. " n " .. n) end
            end
        end
        equal(same, total, "scale " .. scale .. ": on and off the hit frame, the mirror matches the snippet on " .. total .. " releases")
        equal(off > total / 3, true, "scale " .. scale .. ": many of them off it (" .. off .. ")")
    end
    equal(RS.Pick(2047, 0, 4, 26, nil, nil, nil, RS.Reach(1)) .. " " .. RS.Pick(2049, 0, 4, 26, nil, nil, nil, RS.Reach(1)) .. " "
        .. RS.Pick(0, -1365, 4, 26, nil, nil, nil, RS.Reach(1.5)) .. " " .. RS.Pick(0, -1366, 4, 26, nil, nil, nil, RS.Reach(1.5)),
        "2 0 3 0", "the mirror's reach: the hit frame's half-size in face units, at each ring size")
    equal(RS.Pick(0, 10, 4, 26) .. " " .. RS.Pick(10, 0, 4, 26) .. " " .. RS.Pick(0, -30, 4, 26) .. " " .. RS.Pick(-30, 0, 4, 26) .. " " .. RS.Pick(5, 5, 4, 26),
        "0 0 3 4 0", "the mirror: up 1, right 2, down 3, left 4, the middle 0")
end

---------------------------------------------------------------------------
-- 9. What each slice kind does (RingData.Attr)
---------------------------------------------------------------------------

MageBook()
F.Invalidate()
local function Ctx() return {ranks = F.BestRanks().byName} end
local function A(slice) return table.concat({tostring(D.Attr(slice, Ctx()))}, " ") end
local function Attr(slice)
    local kind, key, value, action, hand = D.Attr(slice, Ctx())
    return tostring(kind) .. " " .. tostring(key) .. " " .. tostring(value) .. " " .. tostring(action) .. " " .. tostring(hand)
end
do
    equal(Attr({kind = "spell", id = 5504, rank = "top"}), "spell spell 5506 nil nil", "rank 1 put in, rank 3 known: casts rank 3")
    equal(Attr({kind = "spell", id = 5505, rank = "exact"}), "spell spell 5505 nil nil", "kept at rank 2: rank 2")
    equal(Attr({kind = "spell", id = 10054, rank = "top", name = "Conjure Mana Ruby"}), "nil nil nil nil nil", "a spell you don't know: nothing")
    equal(Attr({kind = "spell", id = 3561, rank = "top"}), "spell spell 3561 nil nil", "a spell without ranks")
    G.spells[3273], G.spells[3274] = {name = "First Aid"}, {name = "First Aid"}
    local fishing = G.book[41]
    G.book[41] = 3274
    F.Invalidate()
    equal(Attr({kind = "spell", id = 3273, rank = "top", name = "First Aid"}), "spell spell 3274 nil nil", "an old profession rank casts the one in its book")
    G.book[41] = fishing
    F.Invalidate()
    equal(Attr({kind = "item", id = 6947, hand = 17}), "item item item:6947 nil 17", "an item on the off hand")
    equal(Attr({kind = "item", id = 5}), "item item item:5 nil nil", "an item (always set; greyed with none)")
    G.macros[3] = {name = "Pull", icon = 77}
    equal(Attr({kind = "macro", id = "Pull"}), "macro macro Pull nil nil", "a macro by name")
    equal(Attr({kind = "macro", id = "Gone"}), "nil nil nil nil nil", "a macro that's gone")
    G.mounts[6] = {name = "Brown Horse", spell = 458, icon = 6, collected = true}
    G.mounts[7] = {name = "Hidden Horse", spell = 459, icon = 7, collected = true, hidden = true}
    G.mounts[8] = {name = "Wanted Horse", spell = 460, icon = 8, collected = false}
    equal(Attr({kind = "mount", id = 6}), "spell spell 458 nil nil", "a mount: its spell")
    equal(Attr({kind = "mount", id = 7}) .. " / " .. Attr({kind = "mount", id = 8}), "nil nil nil nil nil / nil nil nil nil nil", "hidden or not collected: nothing")
    G.pets["BattlePet-0-1"] = {species = 40, name = "Cat", icon = 9}
    G.pets["BattlePet-0-2"] = {species = 41, name = "Rat", icon = 10, revoked = true}
    equal(Attr({kind = "pet", id = "BattlePet-0-1"}), "macro macrotext /summonpet BattlePet-0-1 nil nil", "a pet: /summonpet and its GUID")
    equal(Attr({kind = "pet", id = "BattlePet-0-2"}), "nil nil nil nil nil", "a revoked pet: nothing")
    G.toys[1973] = {name = "Orb of Deception", icon = 11}
    equal(Attr({kind = "toy", id = 1973}) .. " / " .. Attr({kind = "toy", id = 1974}), "toy toy 1973 nil nil / nil nil nil nil nil", "a toy you have; one you don't")
    G.sets[2] = {name = "Tank", icon = 12}
    equal(Attr({kind = "equipmentset", id = "Tank"}) .. " / " .. Attr({kind = "equipmentset", id = "Gone"}),
        "equipmentset equipmentset Tank nil nil / nil nil nil nil nil", "an equipment set by name")
    equal(Attr({kind = "raidtarget", id = 8}) .. " / " .. Attr({kind = "raidtarget", id = 0}),
        "raidtarget marker 8 toggle nil / raidtarget marker nil clear nil", "raid markers: toggle; 0 clears")
    PlaceRaidMarker = nil
    equal(Attr({kind = "worldmarker", id = 5}), "nil nil nil nil nil", "world markers: nothing on a client without them")
    PlaceRaidMarker = function() end
    equal(Attr({kind = "worldmarker", id = 5}) .. " / " .. Attr({kind = "worldmarker", id = 0}),
        "worldmarker marker 5 toggle nil / worldmarker marker nil clear nil", "world markers: toggle; 0 clears all")
    -- Their looks.
    local name, icon = D.Display({kind = "raidtarget", id = 1}, Ctx())
    equal(name .. " " .. icon, "Star Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", "Star and its icon")
    name, icon = D.Display({kind = "worldmarker", id = 5}, Ctx())
    equal(name .. " " .. icon, "Star Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", "world marker 5 is the star")
    name = D.Display({kind = "item", id = 6947, hand = 16, name = "Instant Poison"}, Ctx())
    equal(name, "Instant Poison, main hand", "a poison says its hand")
    name, icon = D.Display({kind = "spell", id = 424242, name = "Old Spell", icon = 55}, Ctx())
    equal(name .. " " .. icon, "Old Spell 55", "a spell the game can't name now: its kept name and icon")
    equal(D.KindLine({kind = "spell", id = 5505, rank = "exact"}, true, Ctx()) .. " / " .. D.KindLine({kind = "spell", id = 5504, rank = "top"}, true, Ctx()),
        "Spell, kept at Rank 2 / Spell, highest rank you know", "the editor's kind lines for spells")
end

---------------------------------------------------------------------------
-- 10. Drag and drop (RingData.FromCursor)
---------------------------------------------------------------------------

do
    local slice = D.FromCursor("spell", 3, 0, 5505)
    equal(slice.kind .. " " .. slice.id .. " " .. slice.rank, "spell 5505 exact", "rank 2 dragged with rank 3 known: kept at rank 2")
    slice = D.FromCursor("spell", 3, 0, 5506)
    equal(slice.id .. " " .. slice.rank .. " " .. slice.name, "5506 top Conjure Water", "the highest rank: follows new ranks")
    slice = D.FromCursor("spell", 4, 0, nil)
    equal(slice and slice.id, 587, "no spell ID given: read from the spellbook slot")
    G.items[6948] = {name = "Hearthstone", icon = 13, use = true}
    slice = D.FromCursor("item", 6948, "link")
    equal(slice.kind .. " " .. slice.id .. " " .. slice.name, "item 6948 Hearthstone", "an item")
    slice = D.FromCursor("item", 1973, "link")
    equal(slice.kind .. " " .. slice.id, "toy 1973", "an item that's a toy you have: a toy")
    slice = D.FromCursor("macro", 3)
    equal(slice.kind .. " " .. slice.id, "macro Pull", "a macro, by its name")
    slice = D.FromCursor("mount", 6)
    equal(slice.kind .. " " .. slice.id, "mount 6", "a mount by its journal ID")
    G.displayed[2] = 6
    slice = D.FromCursor("mount", 2)
    equal(slice.kind .. " " .. slice.id, "mount 6", "a mount by its place in the journal's list")
    slice = D.FromCursor("battlepet", "BattlePet-0-1")
    equal(slice.kind .. " " .. slice.id .. " " .. slice.name, "pet BattlePet-0-1 Cat", "a pet")
    slice = D.FromCursor("equipmentset", "Tank")
    equal(slice.kind .. " " .. slice.id, "equipmentset Tank", "a set by name")
    slice = D.FromCursor("equipmentset", 2)
    equal(slice.kind .. " " .. slice.id, "equipmentset Tank", "a set by ID")
    local none, why = D.FromCursor("money", 500)
    equal(tostring(none) .. " " .. why, "nil That can't go in a ring.", "money is refused")
    none = D.FromCursor("merchant", 3)
    equal(none, nil, "a merchant's item is refused")
end

---------------------------------------------------------------------------
-- 11. Ready-made rings (RingFill)
---------------------------------------------------------------------------

do
    -- Quest items: usable ones first, then starters, once each, none without use.
    G.items[100] = {name = "Usable Quest Thing", icon = 21, class = 12, use = true}
    G.items[101] = {name = "Quest Rock", icon = 22, class = 12}
    G.items[102] = {name = "Letter", icon = 23}
    G.items[103] = {name = "Flagged Orb", icon = 24, use = true}
    G.items[104] = {name = "Old Map", icon = 25}
    G.bags = {[0] = {[1] = {id = 102, quest = {questID = 500, isActive = false}}, [2] = {id = 100}, [3] = {id = 101},
        [4] = {id = 100}, [5] = {id = 103, quest = {isQuestItem = true}}},
        [1] = {[1] = {id = 104, quest = {questID = 501, isActive = true}}}}
    local list = F.QuestItems()
    local ids = {}
    for i, slice in ipairs(list) do ids[i] = slice.kind .. ":" .. slice.id end
    equal(table.concat(ids, ","), "item:100,item:103,item:102", "usable quest items first, then the starter; a plain quest item, a started quest and a repeat left out")
    -- At most 16.
    for i = 1, 20 do G.items[200 + i] = {name = "Q" .. i, class = 12, use = true}; G.bags[2] = G.bags[2] or {}; G.bags[2][i] = {id = 200 + i} end
    equal(#F.Slices({kind = "quest"}), 16, "a ready-made ring holds 16 at most")
    G.bags[2] = nil
    -- Raid markers: 9 in order, then Clear.
    list = F.RaidMarkers()
    equal(#list .. " " .. list[1].id .. " " .. list[8].id .. " " .. list[9].id, "9 1 8 0", "Star to Skull, then Clear")
    PlaceRaidMarker = nil
    equal(#F.WorldMarkers(), 0, "no world markers on a client without them")
    PlaceRaidMarker = function() end
    list = F.WorldMarkers()
    ids = {}
    for i, slice in ipairs(list) do ids[i] = slice.id end
    equal(table.concat(ids, ","), "5,6,3,2,7,1,4,8,0", "world markers in the raid icons' order: star 5 ... skull 8, then Clear All")
    -- Mounts: collected only, favourites first then by name, then bag mounts once.
    G.mounts[9] = {name = "Arctic Wolf", spell = 461, icon = 14, collected = true, favourite = true}
    G.mounts[10] = {name = "Zebra", spell = 462, icon = 15, collected = true}
    G.mountOrder = {6, 7, 8, 9, 10}
    G.items[300] = {name = "Reins of the Black Ram", class = 15, sub = 5}
    G.items[301] = {name = "Brown Horse", class = 15, sub = 5}
    G.bags[3] = {[1] = {id = 300}, [2] = {id = 301}}
    list = F.Mounts()
    ids = {}
    for i, slice in ipairs(list) do ids[i] = slice.kind .. ":" .. slice.id end
    equal(table.concat(ids, ","), "mount:9,mount:6,mount:10,item:300", "favourite first, then by name; hidden and uncollected out; a bag mount the journal hasn't named")
    G.bags[3] = nil
    -- The mage's ring: highest ranks, picks the first known, unknown out.
    W.class = "MAGE"
    list = F.ClassRing("MAGE")
    ids = {}
    for i, slice in ipairs(list) do ids[i] = select(3, D.Attr(slice, Ctx())) end
    equal(table.concat(ids, ","), "587,5506,759,3561,1460", "Conjure Food, Water at rank 3, the gem pick's first known (Agate), Stormwind, Intellect rank 2")
    equal(list[2].name .. " " .. list[2].rank, "Conjure Water top", "each following the highest rank")
    -- Every class's ring loads, no rune or removed spell in it.
    for token, data in pairs(E.RingClassData) do
        if type(data) == "table" and token ~= "POISON_ORDER" then
            for _, entry in ipairs(data) do
                for _, id in ipairs(type(entry) == "table" and entry.pick or {entry}) do
                    equal(id ~= 5784 and id ~= 23161, true, token .. ": no Felsteed or Dreadsteed")
                end
            end
        end
    end
    equal(#E.RingClassData.WARLOCK, 14, "the warlock's fourteen")
    -- The rogue's: the best of each poison it carries, main hand, then off hand with a weapon there.
    G.items[6947] = {name = "Instant Poison"}
    G.items[6950] = {name = "Instant Poison III"}
    G.items[2892] = {name = "Deadly Poison"}
    G.bags[4] = {[1] = {id = 6947}, [2] = {id = 6950}, [3] = {id = 2892}}
    list = F.ClassRing("ROGUE")
    ids = {}
    for i, slice in ipairs(list) do ids[i] = slice.id .. "@" .. slice.hand end
    equal(table.concat(ids, ","), "6950@16,2892@16", "a rogue without an off-hand weapon: main hand only, the best Instant")
    G.offhand = 7000
    G.items[7000] = {name = "Dagger", class = 2}
    list = F.ClassRing("ROGUE")
    equal(#list .. " " .. list[3].id .. "@" .. list[3].hand, "4 6950@17", "with an off-hand weapon: the off hand's too")
    G.offhand, G.bags[4] = nil, nil
end

---------------------------------------------------------------------------
-- 12. The saved rings (RingData)
---------------------------------------------------------------------------

do
    local junk = {version = 1, rings = {
        [1] = {kind = "custom", name = "  |cffff0000Very|r Long Name That Goes On And On  ", slices = {
            {kind = "spell", id = 587, rank = "odd"}, {kind = "nope", id = 1}, {kind = "item", id = "x"}, {kind = "raidtarget", id = 9},
            {kind = "item", id = 6947, hand = 18}, {kind = "macro", id = "Pull"}}},
        [2] = {kind = "quest", name = "Q", slices = {{kind = "spell", id = 1}}},
        [3] = {kind = "weird"}, [11] = {kind = "custom"}, ["x"] = {kind = "custom"}}}
    for i = 1, 20 do table.insert(junk.rings[1].slices, {kind = "spell", id = 587}) end
    local out = D.Validate(junk)
    local ring = out.rings[1]
    equal(ring.name, "Very Long Name That Goes", "a name trimmed to 24 letters, colour codes out")
    equal(#ring.slices .. " " .. ring.slices[1].rank .. " " .. tostring(ring.slices[2].hand) .. " " .. ring.slices[3].id,
        "16 top nil Pull", "junk slices out, at most 16, rank top by default, a bad hand dropped")
    equal(tostring(out.rings[2].slices) .. " " .. tostring(out.rings[3]) .. " " .. tostring(out.rings[11]) .. " " .. tostring(out.rings.x),
        "nil nil nil nil", "a ready-made ring keeps no slices; unknown kinds and slots past 10 go")
    equal(D.CleanName("Café Crème Brûlée Supreme XL", 24), "Café Crème Brûlée Suprem", "names are cut by letters, UTF-8 safe")
    local odd = D.Validate({version = 7, rings = {{kind = "custom"}}})
    equal(next(odd.rings) == nil and odd.old.version, 7, "an unknown version starts empty, a copy kept under old")
    -- Per character: what Load finds in this character's saved table.
    EraUIClassicCharDB = {actionRings = {version = 1, rings = {[4] = {kind = "raid"}}}}
    D.Load()
    equal(D.Ring(4).name .. " " .. D.Count(), "Raid Markers 1", "loaded from this character's saved table, its default name")
    EraUIClassicCharDB = {}
    D.Load()
    for i = 1, 10 do equal(D.NewRing("custom"), i, "new ring " .. i .. " in the lowest free slot") end
    local none, why = D.NewRing("custom")
    equal(tostring(none) .. " " .. why, "nil full", "ten is the most")
    D.DeleteRing(3)
    equal(D.NewRing("mounts"), 3, "a freed slot is used again")
    EraUIClassicCharDB = {}
    D.Load()
end

---------------------------------------------------------------------------
-- 13. The secure buttons with a fight on
---------------------------------------------------------------------------

local function Scripted(event)
    local list = {}
    for _, row in ipairs(W.scripts) do if row.event == event then list[#list + 1] = row.frame end end
    return list
end
do
    EraUIDB.actionRings = true
    -- A character saved by the test build still holds its pick log.
    EraUIClassicCharDB = {actionRingsProbe = {rows = {{slot = 1, chosen = 2}}}}
    W.class, W.className = "MAGE", "Mage"
    M:Initialize()
    equal(EraUIClassicCharDB.actionRingsProbe, nil, "an old pick log is cleared on load")
    -- What the module listens to: no cast events, no blocked actions.
    local heard = {}
    for event in pairs(M.events.events or {}) do heard[#heard + 1] = event end
    table.sort(heard)
    equal(table.concat(heard, ","), "BAG_UPDATE_COOLDOWN,BAG_UPDATE_DELAYED,COMPANION_LEARNED,EQUIPMENT_SETS_CHANGED,LEARNED_SPELL_IN_SKILL_LINE,"
        .. "NEW_MOUNT_ADDED,NEW_PET_ADDED,NEW_TOY_ADDED,PET_JOURNAL_LIST_UPDATE,PLAYER_EQUIPMENT_CHANGED,PLAYER_LEVEL_UP,PLAYER_REGEN_DISABLED,"
        .. "PLAYER_REGEN_ENABLED,QUEST_ACCEPTED,QUEST_LOG_UPDATE,QUEST_REMOVED,SPELLS_CHANGED,SPELL_UPDATE_COOLDOWN,SPELL_UPDATE_USABLE,"
        .. "TOYS_UPDATED,UPDATE_BINDINGS,UPDATE_MACROS", "the game changes it listens to, and no cast or blocked-action events")
    equal(tostring(M.Note) .. " " .. tostring(M.Picked) .. " " .. tostring(M.Dropped) .. " " .. tostring(M.Seen) .. " " .. tostring(M.Blocked)
        .. " " .. tostring(M.PROBE_ROWS), "nil nil nil nil nil nil", "no pick log left in the module")
    equal(S.built, true, "switched on: built")
    local button, hit = _G.EraUIRingButton1, S.hits[1]
    equal(button ~= nil and button.template, "SecureActionButtonTemplate", "EraUIRingButton1, a secure action button")
    equal(_G.EraUIRingButton10 ~= nil and _G.EraUIRingButton11 == nil, true, "ten buttons")
    equal(table.concat(button.clicks, ",") .. " " .. tostring(button.attrs.useOnKeyDown) .. " " .. tostring(button.mouse), "AnyDown,AnyUp false false",
        "down and up clicks, acting on the up one, no mouse")
    equal(hit.template .. " " .. hit.w .. " " .. tostring(hit.mouse) .. " " .. hit.strata .. " " .. tostring(hit.shown),
        "SecureFrameTemplate 4096 false FULLSCREEN_DIALOG false", "the hit frame: protected, 4096 wide, mouse off, hidden, above /era's window")
    local screen = S.screen
    equal(screen.template .. " " .. tostring(screen.mouse) .. " " .. tostring(screen.shown) .. " " .. screen.points[1][1] .. " "
        .. tostring(screen.points[1][2] == UIParent) .. " " .. screen.points[2][1] .. " " .. tostring(screen.points[2][2] == UIParent),
        "SecureFrameTemplate false true TOPLEFT true BOTTOMRIGHT true", "the screen frame: protected, mouse off, shown, all of UIParent")
    equal(W.wraps[button].body, RS.PICK, "PICK wrapped round the button's click")
    equal(W.refs[S.header].ring1 == hit and W.refs[S.header].ring10 == S.hits[10] and W.refs[S.header].screen == screen, true,
        "the header knows each ring and the screen")
    equal(tostring(button.attrs["ring-off"]) .. " " .. button.attrs["ring-count"], "true 0", "no ring there: off")
    -- A ring made, out of combat: written at once.
    D.NewRing("class")
    M:Edited(1)
    equal(tostring(button.attrs["ring-off"]) .. " " .. button.attrs["ring-count"] .. " " .. button.attrs["s2-type"] .. " " .. button.attrs["s2-value"],
        "false 5 spell 5506", "the mage ring written: five slices, Water at rank 3")
    for k = 6, 16 do
        if button.attrs["s" .. k .. "-type"] or button.attrs["s" .. k .. "-key"] or button.attrs["s" .. k .. "-value"] then equal(k, 0, "slice " .. k .. " left empty") end
    end
    equal(button.attrs.dead2, RS.Dead2(1), "the middle at Ring Size 100%")
    equal(button.attrs.tap2 == RS.Tap2(1) and N(button.attrs["ring-edge"]) .. " " .. N(button.attrs["ring-foot"]), "110 136",
        "a tap's size, and the ring's reach kept on the screen: up and to the sides, then down (under its name)")
    equal(N(V.Edge(5)) .. " " .. N(V.Foot(5)) .. " " .. N(V.Edge(16)) .. " " .. N(V.Foot(16)), "110 136 151 177", "the reach grows with the ring")
    EraUIDB.actionRingScale = 150
    M:Refresh()
    equal(button.attrs.dead2, RS.Dead2(1.5), "Ring Size 150%: the middle follows")
    equal(button.attrs.tap2 == RS.Tap2(1.5) and N(button.attrs["ring-edge"]) .. " " .. N(button.attrs["ring-foot"]), "165 204", "and the tap and the reach")
    equal(V.faces[1].ringScale .. " " .. V.faces[1]:GetScale(), "1.5 1.5", "and the face")
    EraUIDB.actionRingScale = 100
    M:Refresh()
    -- Into a fight: a ring changed is saved, and written when it ends.
    W.combat = true
    D.Rename(1, "Travel")
    local said = M:Edited(1)
    equal(said .. " " .. tostring(S.dirty[1]) .. " " .. tostring(button.attrs["s1-type"]), "later true spell", "in a fight: kept for later, nothing written")
    equal(W.status[#W.status], "Action Rings: your ring changes when this fight ends.", "said once")
    local before = #W.status
    M:Edited(1)
    equal(#W.status, before, "only once a fight")
    -- A pick in the fight goes through the secure code.
    W.cursor = {800, 450}
    Press(button, true)
    equal(hit.shown and V.open, 1, "in a fight: the ring opens and the view knows")
    W.cursor = {800, 450 + 200}
    W.casts = {}
    Press(button, false)
    equal(W.casts[1] and W.casts[1].type .. " " .. W.casts[1].value .. " " .. tostring(W.casts[1].combat), "spell 587 true", "and casts Conjure Food (slice 1, straight up)")
    -- Ordinary code can't change a protected frame in a fight: the mock throws.
    local ok = pcall(function() button:SetAttribute("type", "spell") end)
    equal(ok, false, "the mock refuses a protected change from ordinary code in a fight")
    W.combat = false
    M:OnEvent("PLAYER_REGEN_ENABLED")
    equal(tostring(S.dirty[1]) .. " " .. V.faces[1].ringName, "nil Travel", "the fight over: the change is made")
    -- Switched off: every button off, every ring away.
    EraUIDB.actionRings = false
    local executes = W.executes
    M:Refresh()
    local off = 0
    for slot = 1, 10 do if S.buttons[slot].attrs["ring-off"] == true then off = off + 1 end end
    equal(off .. " " .. (W.executes - executes), "10 1", "off: all ten off, CLOSE run once")
    EraUIDB.actionRings = true
    M:Refresh()
    equal(button.attrs["ring-off"], false, "on again: the ring works")
    -- Off in a fight: when it ends.
    W.combat = true
    EraUIDB.actionRings = false
    M:Refresh()
    equal(button.attrs["ring-off"], false, "off in a fight: nothing changes yet")
    W.combat = false
    executes = W.executes
    M:OnEvent("PLAYER_REGEN_ENABLED")
    equal(tostring(button.attrs["ring-off"]) .. " " .. (W.executes - executes), "true 1", "then off, every ring away")
    EraUIDB.actionRings = true
    M:Refresh()
    -- Switched on in a fight before it was ever built: built when it ends.
    for slot = 1, 10 do _G["EraUIRingButton" .. slot] = nil end
    S.built, S.buttons, S.hits, S.signature, S.dirty = false, {}, {}, {}, {}
    V.faces = {}
    W.combat = true
    M:Refresh()
    equal(S.built, false, "not built in a fight")
    W.combat = false
    M:OnEvent("PLAYER_REGEN_ENABLED")
    equal(S.built and S.buttons[1].attrs["ring-count"], 5, "built and written when it ends")
    button, hit = S.buttons[1], S.hits[1]
    -- Game changes are gathered: a new rank learned re-writes the class ring.
    Spell(10138, "Conjure Water", 4)
    M:OnEvent("LEARNED_SPELL_IN_SKILL_LINE")
    Flush()
    equal(button.attrs["s2-value"], 10138, "a new rank learned: the ring casts it")
    -- 14. Nothing under a hit frame has an OnShow, OnHide or OnSizeChanged script.
    for _, event in ipairs({"OnShow", "OnHide", "OnSizeChanged"}) do
        for _, frame in ipairs(Scripted(event)) do
            for slot = 1, 10 do
                if frame == S.hits[slot] or Under(frame, S.hits[slot]) then equal(event, "none", "a script under a hit frame") end
            end
        end
    end
    checks = checks + 1
    for _, frame in ipairs(W.frames) do
        if frame.kind == "Cooldown" then equal(frame.template, nil, "cooldowns made without a template") end
    end
end

---------------------------------------------------------------------------
-- 14. The look: arrow, lit slice, labels, cooldowns, counts, swirl out
---------------------------------------------------------------------------

do
    local button, face = S.buttons[1], V.faces[1]
    W.combat = true
    W.cursor = {800, 450}
    Press(button, true)
    local function Frame(elapsed) face.scripts.OnUpdate(face, elapsed or .016) end
    Frame(.2)
    equal(face.lit .. " " .. tostring(face.bearing) .. " " .. N(face.arms[1].alpha) .. " " .. N(face.arms[2].alpha), "0 nil 0.25 0.25",
        "opened in the middle (its swirl in over): nothing lit, the arrow faint")
    equal(face.label:GetText(), "Travel", "the ring's own name in the middle, muted")
    -- To the right: slice 2 of 5 is at 72 degrees.
    W.cursor = {800 + 100 * math.sin(math.rad(72)), 450 + 100 * math.cos(math.rad(72))}
    Frame()
    equal(face.lit .. " " .. math.floor(face.bearing + .5), "2 72", "the slice under the pointer lit; the pointer snaps the first time out")
    equal(face.label:GetText(), button.attrs["s2-value"] and V.faces[1].list[2].name, "its name in the middle")
    equal(face.lit, RS.Pick((W.cursor[1] - 800) / face.ringScale, (W.cursor[2] - 450) / face.ringScale, face.n, RS.DEAD), "the lit slice is the mirror's")
    W.cursor = {800 + 100 * math.sin(math.rad(216)), 450 + 100 * math.cos(math.rad(216))}
    Frame(.016)
    equal(face.lit, 4, "moved round: slice 4 lit at once")
    equal(math.abs(V.Turn(face.bearing, 216)) > 1, true, "the pointer eases, not jumps")
    for _ = 1, 30 do Frame(.0167) end
    equal(math.abs(V.Turn(face.bearing, 216)) < 1, true, "after half a second it's there")
    equal(face.glow.shown, true, "the glow follows the lit icon")
    -- Far out to the right on a very wide screen: on the hit frame, lit; past
    -- its half-size the game gives the secure code no position, so nothing
    -- lights and a release there picks nothing.
    W.cursor = {800 + 2000, 450}
    Frame()
    equal(face.lit, 2, "2000 out to the right, still on the hit frame: slice 2 lit")
    W.cursor = {800 + RS.HIT / 2 + 50, 450}
    Frame()
    equal(face.lit .. " " .. N(face.arms[1].alpha) .. " " .. tostring(face.glow.shown) .. " " .. face.label:GetText(), "0 0.25 false Travel",
        "past the hit frame: nothing lit, the arrow faint, the ring's own name")
    W.casts = {}
    Press(button, false)
    equal(button.attrs.chosen .. " " .. #W.casts, "0 0", "and let go there: nothing, as the ring showed")
    W.cursor = {800, 450}
    Press(button, true)
    W.cursor = {800 + 100 * math.sin(math.rad(216)), 450 + 100 * math.cos(math.rad(216))}
    for _ = 1, 30 do Frame(.0167) end
    equal(face.lit .. " " .. tostring(face.glow.shown), "4 true", "opened again: slice 4 lit")
    EraUIDB.actionRingNames = false
    Frame()
    equal(face.label:GetText(), "Travel", "Slice Names off: the ring's name")
    EraUIDB.actionRingNames = true
    -- The name sits on a plate under the icons, clear of the bottom one (lit,
    -- grown and with its dark edge), as wide as its words, the ring's at most.
    local lp = face.label.points[1]
    equal(lp[1] .. " " .. tostring(lp[2] == face) .. " " .. lp[3] .. " " .. N(lp[4]) .. " " .. N(lp[5]) .. " " .. tostring(face.label.wordWrap),
        "TOP true BOTTOM 0 -6 false", "the name under the ring, on one line")
    equal(face.plate.shown and face.plate.points[1][2] == face.label and face.plateEdge.points[2][2] == face.label, true, "on its plate")
    local plateTop = face.h / 2 + 6 - 5
    equal(plateTop > face.R + V.ICON * V.GROW / 2 + 3.5 and V.Foot(face.n) > face.h / 2 + 6 + 14, true, "the plate clear of the bottom icon, and kept on screen")
    V.SetLabel(face, "Teleport: Stormwind")
    equal(N(face.label.w), N(#"Teleport: Stormwind" * 6 + 2), "the plate fits its words")
    V.SetLabel(face, string.rep("Long ", 20))
    equal(N(face.label.w) .. " " .. N(face.label.w + 16), N(V.LabelWidth(face.n)) .. " " .. N(face.w), "a very long one: the ring's width, then it ends in ...")
    -- What must show whole: the longest poison names (both hands share an
    -- icon, so the hand must show) and every empty ring's words.
    local whole = {"Mind-numbing Poison III, off hand", "Instant Poison VI, main hand", "Crippling Poison II, off hand"}
    for _, line in pairs(V.EMPTY) do whole[#whole + 1] = line end
    for _, line in ipairs(whole) do
        V.SetLabel(face, line)
        if #line * 6 + 2 > face.label.w then equal(line, "fits " .. N(face.label.w), "a name or line cut off under the ring") end
        checks = checks + 1
    end
    V.SetLabel(face, "")
    equal(tostring(face.plate.shown) .. " " .. tostring(face.plateEdge.shown), "false false", "no words: no plate")
    -- Cooldowns: spells from the duration object only; items from public numbers.
    G.spellCooldown[587] = {isEnabled = true, isOnGCD = false, object = {"duration of 587"}}
    V.RefreshFace(face)
    equal(face.slots[1].cd.cooldown and face.slots[1].cd.cooldown[1], "duration", "a spell's sweep from its duration object")
    G.spellCooldown[587] = {isEnabled = SECRET, isOnGCD = SECRET, object = SECRET}
    V.RefreshFace(face)
    equal(face.slots[1].cd.cooldown and face.slots[1].cd.cooldown[2], SECRET, "a hidden one handed on as it is, never compared")
    G.spellCooldown[587] = {isEnabled = false}
    V.RefreshFace(face)
    equal(face.slots[1].cd.cooldown, nil, "a spell on hold: no sweep")
    EraUIDB.actionRingCooldowns = false
    G.spellCooldown[587] = {isEnabled = true, isOnGCD = false, object = {"duration"}}
    V.RefreshFace(face)
    equal(face.slots[1].cd.cooldown, nil, "Cooldowns & Counts off: none")
    EraUIDB.actionRingCooldowns = true
    G.spellCooldown[587] = nil
    W.cursor = {800, 450}
    Press(button, false)
    -- An item ring: counts and greying.
    W.combat = false
    EraUIClassicCharDB.actionRings.rings[2] = {kind = "custom", name = "Bag", slices = {{kind = "item", id = 6948}, {kind = "item", id = 777, name = "None Left"},
        {kind = "macro", id = "Gone", name = "Gone Macro"}}}
    G.items[777] = {name = "None Left", icon = 30}
    G.bags[0] = {[1] = {id = 6948, count = 5}}
    G.cooldowns[6948] = {50, 900}
    M:Edited(2)
    local bag = V.faces[2]
    Press(S.buttons[2], true)
    equal(bag.slots[1].count:GetText() .. " " .. tostring(bag.slots[1].cd.cooldown and bag.slots[1].cd.cooldown[2]) .. " " .. tostring(bag.slots[2].greyed),
        "5 900 true", "an item's count and cooldown; one you have none of greyed")
    G.counts[6948] = SECRET
    V.RefreshFace(bag)
    equal(bag.slots[1].count:GetText(), "", "a hidden count: no number, never compared")
    G.counts[6948] = nil
    -- Let go on slice 1: the swirl out plays on its own frame on the screen,
    -- placed by UIParent's offsets at the ring's centre, slice 1's copy
    -- where its icon was.
    W.cursor = {800, 450 + 150}
    bag.scripts.OnUpdate(bag, .2)
    Press(S.buttons[2], false)
    local swirl = V.swirl
    local point = swirl.points[1]
    local first = swirl.ghosts[1].points[1]
    equal(swirl.shown and point[2] == UIParent and point[3] == "BOTTOMLEFT" and N(point[4]) .. " " .. N(point[5]) .. " " .. N(first[4]) .. " " .. N(first[5]),
        "800 450 0 " .. N(bag.R), "the picked slice's copy where its icon was, the swirl placed on UIParent")
    for _ = 1, 22 do swirl.scripts.OnUpdate(swirl, .02) end
    equal(swirl.shown, true, "still showing at 0.44 s (the middle ring fading last)")
    for _ = 1, 3 do swirl.scripts.OnUpdate(swirl, .02) end
    equal(swirl.shown, false, "and gone when its swirl ends")
    EraUIDB.actionRingMotion = false
    W.cursor = {800, 450}
    Press(S.buttons[2], true)
    equal(N(bag.alpha) .. " " .. N(bag:GetScale()) .. " " .. N(bag.slots[1].alpha) .. " " .. N(bag.middle.alpha) .. " " .. N(bag.slots[1].points[1][5]),
        "1 1 0.78 1 " .. N(bag.R), "Ring Motion off: it shows at once, every icon in its place")
    W.cursor = {800, 600}
    Press(S.buttons[2], false)
    equal(swirl.shown, false, "and goes at once (no swirl)")
    EraUIDB.actionRingMotion = true
    -- Let go on a greyed slice (a macro that's gone): it lights as you point
    -- at it, but nothing is cast and nothing glows.
    W.cursor = {800, 450}
    Press(S.buttons[2], true)
    W.cursor = {800 + 100 * math.sin(math.rad(240)), 450 + 100 * math.cos(math.rad(240))}
    bag.scripts.OnUpdate(bag, .016)
    equal(bag.lit .. " " .. tostring(bag.list[3].ready), "3 false", "the greyed slice lights where it is")
    W.casts = {}
    Press(S.buttons[2], false)
    equal(S.buttons[2].attrs.chosen .. " " .. #W.casts .. " " .. tostring(swirl.glow.shown), "-3 0 false", "let go on it: nothing cast, no glow")
    equal(swirl.shown, true, "its icons still swirl out")
    -- Opened in the screen's bottom left corner: moved in (its reach 110 up
    -- and to the sides, 136 down), the view's centre where the secure code
    -- put it; nothing lit until the cursor moves, then each slice lights
    -- where a release picks it.
    W.cursor = {5, 5}
    Press(S.buttons[2], true)
    equal(N(V.cx) .. " " .. N(V.cy) .. " " .. N(S.hits[2].centre[1]) .. " " .. N(S.hits[2].centre[2]), "110 136 110 136",
        "moved in from the corner: the view's centre is the ring's")
    equal(swirl.shown, false, "opening a ring stops the swirl out at once")
    bag.scripts.OnUpdate(bag, .2)
    equal(bag.lit .. " " .. N(bag.arms[1].alpha), "0 0.25", "not moved yet: nothing lit, the arrow faint")
    W.cursor = {8, 5}
    bag.scripts.OnUpdate(bag, .016)
    equal(bag.lit, 0, "moved less than a tap: still nothing")
    for k = 3, 1, -1 do
        local a = math.rad(RS.SliceAngle(k, 3))
        W.cursor = {110 + 60 * math.sin(a), 136 + 60 * math.cos(a)}
        bag.scripts.OnUpdate(bag, .016)
        equal(bag.lit .. " " .. N(bag.arms[1].alpha), k .. " 1", "pointing at slice " .. k .. " from the corner: lit")
    end
    W.casts = {}
    Press(S.buttons[2], false)
    equal(S.buttons[2].attrs.chosen .. " " .. tostring(W.casts[1] and W.casts[1].value), "1 item:6948", "and let go there: that slice")
    point, first = swirl.points[1], swirl.ghosts[1].points[1]
    equal(N(point[4] + first[4]) .. " " .. N(point[5] + first[5]), "110 " .. N(136 + bag.R), "its copy where its icon was, on the moved-in ring")
    W.cursor = {5, 5}
    Press(S.buttons[2], true)
    W.casts = {}
    Press(S.buttons[2], false)
    equal(S.buttons[2].attrs.chosen .. " " .. #W.casts, "0 0", "a tap in the corner: nothing")
    -- Dark Mode and Classic: the rims (slice 2 at rest, slice 1 lit), the
    -- middle ring, the arrow, the glows and the name's plate follow the look
    -- each time a ring opens.
    local function F3(x) return string.format("%.3f", x) end
    local function C3(t) return F3(t[1]) .. "," .. F3(t[2]) .. "," .. F3(t[3]) end
    local function Colours(f)
        return C3(f.slots[2].rim.vertex) .. " / " .. C3(f.slots[1].rim.vertex) .. " / " .. C3(f.middle.vertex) .. " / " .. C3(f.arms[1].vertex)
            .. " / " .. C3(f.glow.vertex) .. " / " .. F3(f.plate.vertex[1]) .. "," .. F3(f.plate.vertex[4])
    end
    local function Lit()
        W.cursor = {800, 450}
        Press(S.buttons[2], true)
        W.cursor = {800, 600}
        bag.scripts.OnUpdate(bag, .2)
        local seen = Colours(bag)
        W.cursor = {800, 450}
        Press(S.buttons[2], false)
        return seen
    end
    EraUIDB.darkMode = true
    equal(Lit(), "0.300,0.310,0.340 / 0.250,0.780,0.920 / 0.250,0.780,0.920 / 0.250,0.780,0.920 / 0.250,0.780,0.920 / 0.066,0.880",
        "Dark Mode: rims its muted grey; the lit rim, middle ring, arrow and glow your class colour; the plate dark grey")
    -- Dark Mode's rims stay a muted grey at every Darkness (40 light grey
    -- to 90 near black): never white, never lost on the dark edge; the
    -- grey's slight blue kept.
    local grey = E.Classic.DarkGrey
    local function RimAt(darkness)
        local v = 1 - darkness / 100
        E.Classic.DarkGrey = function() return v, math.min(1, v * 44 / 42), math.min(1, v * 48 / 42) end
        return V.Palette().rim
    end
    equal(C3(RimAt(40)) .. " / " .. C3(RimAt(58)) .. " / " .. C3(RimAt(90)), "0.500,0.524,0.571 / 0.420,0.440,0.480 / 0.300,0.314,0.343",
        "Dark Mode rims at Darkness 40, 58 and 90: kept between .3 and .5")
    for darkness = 40, 90 do
        local rim = RimAt(darkness)
        if rim[1] < .3 - 1e-9 or rim[1] > .5 + 1e-9 or math.abs(rim[2] / rim[1] - 44 / 42) > 1e-6 then equal(C3(rim), "between .3 and .5", "the rim at Darkness " .. darkness) end
        checks = checks + 1
    end
    E.Classic.DarkGrey = grey
    EraUIDB.darkMode = false
    equal(Lit(), "0.550,0.450,0.200 / 1.000,0.820,0.000 / 1.000,0.820,0.000 / 1.000,0.820,0.000 / 1.000,0.820,0.000 / 0.070,0.850",
        "Classic: bronze rims; the game's gold for the lit rim, the middle ring, the arrow and the glow")
    equal(C3(swirl.middle.vertex) .. " / " .. C3(swirl.arms[2].vertex), "1.000,0.820,0.000 / 1.000,0.820,0.000", "the swirl out in the same colours")
    -- A ring left open (its key's release lost) out of a fight: put away after 20 s.
    Press(S.buttons[2], true)
    W.now = W.now + 21
    bag.scripts.OnUpdate(bag, .016)
    equal(tostring(S.hits[2].shown) .. " " .. tostring(V.open), "false nil", "left open 20 s out of a fight: put away")
    -- Nothing is logged: every pick above, a cast event and a blocked action
    -- (even ones the module never listens to) leave the saved table alone.
    equal(EraUIClassicCharDB.actionRingsProbe, nil, "no pick writes a log")
    local listen = M.events.scripts.OnEvent
    listen(M.events, "UNIT_SPELLCAST_SENT", "player", "Target", "Cast-1", 587)
    listen(M.events, "UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 587)
    listen(M.events, "UNIT_SPELLCAST_FAILED", "player", "Cast-2", 587)
    listen(M.events, "ADDON_ACTION_BLOCKED", "EraUI", "CastSpellByID()")
    listen(M.events, "ADDON_ACTION_FORBIDDEN", "EraUI", "UseAction()")
    Flush()
    local keys = {}
    for key in pairs(EraUIClassicCharDB) do keys[#keys + 1] = key end
    equal(tostring(EraUIClassicCharDB.actionRingsProbe) .. " " .. tostring(M.pending) .. " " .. table.concat(keys, ","), "nil nil actionRings",
        "a cast event or a blocked action: nothing saved, nothing waiting")
end

---------------------------------------------------------------------------
-- 14b. The look: round icons with rims, the hollow middle and its arrow,
-- the swirl in and out (Ring Motion), the picked glow, the name's plate
---------------------------------------------------------------------------

do
    W.combat = false
    EraUIDB.actionRingMotion, EraUIDB.darkMode = true, false
    local SHEET = "Interface\\AddOns\\EraUI\\Media\\CursorRings"
    local DISC = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
    local function F3(x) return string.format("%.3f", x) end
    local function C3(t) return F3(t[1]) .. "," .. F3(t[2]) .. "," .. F3(t[3]) end
    -- A ring sheet texture's cell, and the ring it draws: its inside and
    -- outside radius (a texture pinned round its frame, or sized).
    local function Cell(t) return math.floor(t.coords[1] * 8 + .5) + 8 * math.floor(t.coords[3] * 8 + .5) end
    local function Drawn(t, frame)
        local across = (t.w > 0 and t.w or frame.w - 2 * t.points[1][4]) * 120 / 128
        return across / 2 - (Cell(t) + 1) / 128 * across, across / 2
    end
    local slot = D.NewRing("custom")
    for _, id in ipairs({587, 5504, 3561, 1459, 759, 1460}) do D.AddSlice(slot, {kind = "spell", id = id, rank = "top"}) end
    M:Edited(slot)
    local face, button, swirl = V.faces[slot], S.buttons[slot], V.swirl
    equal(face.n .. " " .. face.R .. " " .. button.attrs["ring-count"], "6 78 6", "a ring of six, laid out")
    -- No dial: no dark disc, grey track, ticks, hub or needle, on any face.
    for _, f in pairs(V.faces) do
        equal(tostring(f.dial) .. " " .. tostring(f.band) .. " " .. tostring(f.hub) .. " " .. tostring(f.rim) .. " " .. tostring(f.needle) .. " "
            .. tostring(f.tip) .. " " .. tostring(f.dividers), "nil nil nil nil nil nil nil", "no dark disc, track, ticks, hub or needle")
        for _, t in ipairs(W.frames) do
            if t.kind == "Texture" and Under(t, f) and (t.texture == DISC or Has(t.texture, "CursorCastRing")) then
                equal(t.texture, "none", "a disc or the old track under a face")
            end
        end
        checks = checks + 1
    end
    -- Round icons: cut by the game's portrait mask, a thin rim from EraUI's
    -- ring sheet on the icon's edge, a dark edge and a soft shade behind.
    for k = 1, 6 do
        local s = face.slots[k]
        local mask = s.icon.masks and s.icon.masks[1]
        if not (mask and mask.kind == "MaskTexture" and mask.texture == DISC and mask.points[1][2] == s.icon) then equal(k, 0, "icon " .. k .. " cut round") end
        checks = checks + 1
    end
    local s1 = face.slots[1]
    local inside, outside = Drawn(s1.rim, s1)
    equal(s1.rim.texture .. " " .. N(inside) .. " " .. N(outside), SHEET .. " 17.06 19.5",
        "each icon's rim from EraUI's ring sheet: a thin line from just inside the icon's edge (18 out) to 1.5 past it")
    inside, outside = Drawn(s1.edge, s1)
    equal(s1.edge.texture .. " " .. Cell(s1.edge) .. " " .. N(outside) .. " " .. N(s1.edge.vertex[1]) .. " " .. N(s1.edge.vertex[4]) .. " "
        .. tostring(Has(s1.shade.texture, "CursorTrailDot")) .. " " .. N(s1.shade.vertex[1]) .. " " .. N(s1.shade.vertex[4]),
        SHEET .. " 63 21.5 0 0.65 true 0 0.5", "behind each a dark edge (the sheet's disc, 3.5 past the icon) and a soft shade: it reads on bright ground")
    equal(tostring(s1.cd.swipe == DISC) .. " " .. tostring(s1.cd.circular), "true true", "a round cooldown sweep")
    -- The middle: a hollow ring, about a third of the radius, never inside
    -- the middle where letting go cancels; a third of a wider ring too.
    inside, outside = Drawn(face.middle)
    equal(face.middle.texture .. " " .. N(inside) .. " " .. N(outside) .. " " .. tostring(inside >= RS.DEAD) .. " " .. tostring(math.abs(inside - face.R / 3) < 1),
        SHEET .. " 26.25 30 true true", "the middle ring: hollow, a third of the radius, round the middle that cancels")
    for n = 1, 16 do
        local inner, R = V.Middle(n), V.Radius(n)
        if inner < RS.DEAD or inner < R / 3 - 1e-9 or inner > math.max(RS.DEAD, R / 3) + 1e-9 then equal(n .. " " .. inner, "a third of " .. R, "the middle ring's size") end
        checks = checks + 1
    end
    local sixteen = {}
    for k = 1, 16 do sixteen[k] = {icon = k, ready = true, name = "Slice " .. k, kind = "spell"} end
    V.Layout(9, S.hits[9], sixteen, {name = "Big", kind = "custom"}, 1)
    inside = Drawn(V.faces[9].middle)
    equal(V.faces[9].R .. " " .. tostring(inside >= RS.DEAD and inside >= V.faces[9].R / 3 and inside < V.faces[9].R / 3 + 1), "119 true",
        "sixteen slices: the middle ring a third of the wider ring")
    -- No two icons touch, dark edges and all, at rest or one lit, for every
    -- count of slices (the icons are round: the straight line between them).
    do
        local big, touching, radii = V.faces[9], {}, {}
        for n = 1, 16 do
            local list = {}
            for k = 1, n do list[k] = sixteen[k] end
            V.Layout(9, S.hits[9], list, {name = "Test", kind = "custom"}, 1)
            radii[n] = big.R
            local out = -big.slots[1].edge.points[1][4]
            local function Outside(size) return (size + 2 * out) * 120 / 128 / 2 end
            for a = 1, n - 1 do
                for b = a + 1, n do
                    local pa, pb = big.slots[a].points[1], big.slots[b].points[1]
                    local apart = math.sqrt((pa[4] - pb[4]) ^ 2 + (pa[5] - pb[5]) ^ 2)
                    for _, lit in ipairs({1, V.GROW}) do
                        if apart < Outside(V.ICON) + Outside(V.ICON * lit) - 1e-6 then touching[#touching + 1] = n .. " slices: " .. a .. " and " .. b .. " " .. N(apart) end
                    end
                    checks = checks + 1
                end
            end
        end
        equal(table.concat(touching, ", "), "", "no two icons touch, at rest or one lit, from 1 slice to 16")
        equal(table.concat(radii, " ", 1, 10) .. " | " .. table.concat(radii, " ", 11, 16), "78 78 78 78 78 78 78 78 78 78 | 83 90 97 104 112 119",
            "1 to 10 slices as before; more spread out just enough")
    end
    S.Apply(9, false, true)
    -- The arrow: just outside the middle ring, well inside the icons, its
    -- point on the bearing, its arms turned back either side.
    local function Line(a, b) local d = (a - b) % 180; return math.min(d, 180 - d) end
    local tip, reach = V.Tip(6), (V.ARM - V.ARM_WIDTH) / 2
    for _, b in ipairs({0, 60, 135, 200, 315}) do
        face.bearing = b
        V.Pointer(face, true, 1)
        local p1, p2 = face.arms[1].points[1], face.arms[2].points[1]
        local mx, my = (p1[4] + p2[4]) / 2, (p1[5] + p2[5]) / 2
        local turn1, turn2 = math.deg(-face.arms[1].rotation), math.deg(-face.arms[2].rotation)
        equal(N(V.Turn(b, RS.Bearing(mx, my))) .. " " .. N(math.sqrt(mx * mx + my * my)) .. " " .. tostring(Line(turn1, b + 135) < .01 and Line(turn2, b + 225) < .01)
            .. " " .. N(face.arms[1].alpha), "0 " .. N(tip - reach * math.sqrt(.5)) .. " true 1", "the arrow at " .. b .. " degrees: on that line, its arms turned back either side")
        -- Each arm over its dark shadow: the same centre and turn, a little bigger, under it.
        for i = 1, 2 do
            local arm, shade = face.arms[i], face.arms.shades[i]
            local ap, sp = arm.points[1], shade.points[1]
            equal(N(sp[4] - ap[4]) .. " " .. N(sp[5] - ap[5]) .. " " .. tostring(sp[2] == face and shade.rotation == arm.rotation) .. " " .. N(shade.alpha),
                "0 0 true 1", "the arrow at " .. b .. " degrees: arm " .. i .. "'s shadow under it")
        end
    end
    local shade, arm = face.arms.shades[1], face.arms[1]
    equal(N(arm.w) .. "x" .. N(arm.h) .. " " .. N(shade.w) .. "x" .. N(shade.h) .. " " .. C3(shade.vertex) .. " " .. N(shade.vertex[4]) .. " "
        .. tostring(shade.layer == arm.layer and shade.sub < arm.sub) .. " " .. tostring(face.arms[3]),
        "4x13 6x15 0.000,0.000,0.000 0.45 true nil", "the arms as thick as the middle ring's line, each over a dark bar 1 bigger all round")
    equal(N(tip - (V.ARM - V.ARM_WIDTH / 2) * math.sqrt(.5) - outside) .. " " .. tostring(tip + V.ARM_WIDTH < face.R - V.ICON * V.GROW / 2 - 3.5),
        N(V.ARROW_GAP) .. " true", "the arrow's back 3 past the middle ring, its point well inside the icons")
    V.Pointer(face, false, 1)
    equal(N(face.arms[1].alpha) .. " " .. N(face.arms[2].alpha) .. " " .. N(face.arms.shades[1].alpha) .. " " .. N(face.arms.shades[2].alpha) .. " " .. C3(face.arms[1].vertex),
        "0.25 0.25 0.25 0.25 1.000,0.820,0.000", "faint inside the middle (its shadow too), in the accent colour")

    -- The swirl in, in a fight (the mock throws if a protected frame is touched).
    W.combat = true
    local function Step(t) face.scripts.OnUpdate(face, t) end
    local function Spot(f) local p = f.points[1]; return RS.Bearing(p[4], p[5]), math.sqrt(p[4] * p[4] + p[5] * p[5]) end
    -- Each icon's turn from its own place, its distance over the radius and
    -- how strongly it shows (one line when all six agree).
    local function Where(frames)
        local seen
        for k = 1, 6 do
            local b, r = Spot(frames[k])
            local line = N(V.Turn((k - 1) * 60, b)) .. " " .. N(r / face.R) .. " " .. N(frames[k].alpha)
            if seen and seen ~= line then return seen .. " but slice " .. k .. " " .. line end
            seen = line
        end
        return seen
    end
    W.cursor = {800, 450}
    Press(button, true)
    equal(Where(face.slots) .. " " .. N(face.middle.alpha) .. " " .. N(face.arms[1].alpha), "-60 1.6 0 0 0",
        "the swirl in from the first frame: 60 degrees anticlockwise of each place, 1.6 times out, unseen")
    Step(.075)
    equal(Where(face.slots) .. " " .. N(face.middle.alpha), "-15 1.15 0.59 0.75", "half way (eased out): three quarters there, coming clockwise, fading in")
    Step(.075)
    equal(Where(face.slots) .. " " .. N(face.middle.alpha) .. " " .. tostring(face.motion), "0 1 0.78 1 nil", "in 0.15 s every icon in its place")
    Step(.016)
    equal(Where(face.slots), "0 1 0.78", "and it stays there")
    -- A tap: the same swirl out, no glow; opening again stops it at once.
    Press(button, false)
    equal(button.attrs.chosen .. " " .. tostring(swirl.shown) .. " " .. tostring(swirl.glow.shown) .. " | " .. Where(swirl.ghosts), "0 true false | 0 1 0.78",
        "a tap: the icons swirl out from where they were, no glow")
    swirl.scripts.OnUpdate(swirl, .05)
    equal(swirl.shown, true, "still swirling")
    Press(button, true)
    equal(tostring(swirl.shown) .. " " .. V.open, "false " .. slot, "the ring opened again mid-swirl: the swirl out stops at once")
    -- Let go during the swirl in: the secure choice as always; the icons are
    -- copied where they were, mid-swirl.
    Step(.03)
    local a = math.rad(RS.SliceAngle(3, 6))
    W.cursor = {800 + 60 * math.sin(a), 450 + 60 * math.cos(a)}
    Step(.016)
    local before = face.slots[2].points[1]
    before = N(before[4]) .. " " .. N(before[5])
    W.casts = {}
    Press(button, false)
    equal(button.attrs.chosen .. " " .. tostring(W.casts[1] and W.casts[1].value) .. " | " .. N(swirl.ghosts[2].points[1][4]) .. " " .. N(swirl.ghosts[2].points[1][5]),
        "3 " .. tostring(button.attrs["s3-value"]) .. " | " .. before, "let go mid-swirl: the slice the secure code picks; the icons copied where they were")
    swirl.scripts.OnUpdate(swirl, 1)
    -- A pick: slice 2 lit and grown, then let go.
    W.cursor = {800, 450}
    Press(button, true)
    Step(.2)
    local a2 = math.rad(RS.SliceAngle(2, 6))
    W.cursor = {800 + 100 * math.sin(a2), 450 + 100 * math.cos(a2)}
    Step(.5)
    equal(face.lit .. " " .. N(face.slots[2].w) .. " " .. N(face.slots[2].alpha) .. " " .. C3(face.slots[2].rim.vertex) .. " " .. C3(face.slots[1].rim.vertex),
        "2 42.48 1 1.000,0.820,0.000 0.550,0.450,0.200", "slice 2 lit: grown, its rim gold, the others bronze")
    Press(button, false)
    local ghosts, glow = swirl.ghosts, swirl.glow
    local function Ghost(k) local b, r = Spot(ghosts[k]); return N(V.Turn((k - 1) * 60, b)) .. " " .. N(r / face.R) .. " " .. N(ghosts[k].alpha) end
    equal(Ghost(1) .. " / " .. Ghost(2) .. " / " .. N(ghosts[2].w) .. " / " .. C3(ghosts[2].rim.vertex) .. " / " .. C3(ghosts[1].rim.vertex) .. " / "
        .. tostring(ghosts[6].shown) .. " " .. tostring(ghosts[7].shown), "0 1 0.78 / 0 1 1 / 42.48 / 1.000,0.820,0.000 / 0.550,0.450,0.200 / true false",
        "the pick: each icon copied as it was (the picked one grown, its rim gold), six copies shown")
    equal(tostring(glow.shown) .. " " .. N(glow.alpha) .. " " .. N(glow.w) .. " " .. N(glow.points[1][4]) .. " " .. N(glow.points[1][5]) .. " " .. glow.blend,
        "true 1 " .. N(42.48 * 2.2) .. " " .. N(face.R * math.sin(a2)) .. " " .. N(face.R * math.cos(a2)) .. " ADD", "and a bright glow under the picked one at the start")
    swirl.scripts.OnUpdate(swirl, .075)
    equal(N(glow.alpha) .. " " .. N(glow.w), "0.5 " .. N(42.48 * 2.5), "the glow fades as it grows")
    swirl.scripts.OnUpdate(swirl, .075)
    equal(Ghost(1) .. " / " .. Ghost(2) .. " / " .. tostring(glow.shown) .. " / " .. N(swirl.middle.alpha) .. " " .. N(swirl.arms[1].alpha) .. " " .. N(swirl.arms.shades[1].alpha),
        "12.86 1.22 0.78 / 12.86 1.22 1 / false / 1 1 1",
        "at 0.15 s (eased in): a little way round and out, at full strength; the glow gone; the middle ring and arrow full")
    swirl.scripts.OnUpdate(swirl, .1)
    equal(Ghost(1) .. " / " .. Ghost(2) .. " / " .. N(swirl.middle.alpha), "35.71 1.61 0.78 / 35.71 1.61 1 / 1",
        "at 0.25 s: half way out and still at full strength (seen far out)")
    swirl.scripts.OnUpdate(swirl, .05)
    equal(Ghost(1) .. " / " .. Ghost(4) .. " / " .. tostring(swirl.shown) .. " / " .. N(swirl.middle.alpha) .. " " .. N(swirl.arms[1].alpha),
        "51.43 1.88 0.45 / 51.43 1.88 0.45 / true / 1 1", "at 0.3 s: nearly twice out, now fading; the middle ring and arrow still full")
    swirl.scripts.OnUpdate(swirl, .05)
    equal(Ghost(1) .. " / " .. Ghost(4) .. " / " .. tostring(swirl.shown) .. " / " .. N(swirl.middle.alpha) .. " " .. N(swirl.arms[2].alpha) .. " " .. N(swirl.arms.shades[2].alpha),
        "70 2.2 0 / 70 2.2 0 / true / 0.67 0.67 0.67", "at 0.35 s: 70 degrees on round the middle, 2.2 times out, gone; then the middle ring and arrow fade")
    swirl.scripts.OnUpdate(swirl, .05)
    equal(tostring(swirl.shown) .. " " .. N(swirl.middle.alpha), "true 0.33", "at 0.4 s: the middle ring nearly gone")
    swirl.scripts.OnUpdate(swirl, .055)
    equal(tostring(swirl.shown) .. " " .. N(swirl.middle.alpha) .. " " .. N(swirl.arms[2].alpha), "false 0 0", "past 0.45 s the swirl's frame hides (its updates stop)")
    -- The swirl's frame: on UIParent, never under or pinned to a protected
    -- frame, made once (no frame or texture made at a close or a re-layout).
    equal(tostring(swirl.parent == UIParent) .. " " .. tostring(swirl.protected) .. " " .. swirl.strata .. " " .. tostring(swirl.mouse),
        "true false FULLSCREEN_DIALOG false", "the swirl's own frame on UIParent, over every window, mouse off")
    for _, f in ipairs(W.frames) do
        if f == swirl or Under(f, swirl) then
            if f.protected then equal("protected", "plain", "a protected frame in the swirl") end
            for _, point in ipairs(f.points) do
                local rel = point[2]
                if rel ~= UIParent and rel ~= swirl and not Under(rel, swirl) then equal("pinned elsewhere", "to the swirl or UIParent", "a part of the swirl") end
            end
            checks = checks + 1
        end
    end
    W.combat = false
    local made = #W.frames
    S.ApplyAll(false, true)
    W.combat = true
    W.cursor = {800, 450}
    Press(button, true)
    Step(.2)
    W.cursor = {800, 550}
    Step(.016)
    Press(button, false)
    swirl.scripts.OnUpdate(swirl, 1)
    equal(tostring(V.swirl == swirl) .. " " .. #swirl.ghosts .. " " .. (#W.frames - made), "true 16 0", "made once, 16 copies: nothing made at a close or a re-layout")
    -- Ring Motion off: no swirl in or out, no glide, no glow.
    EraUIDB.actionRingMotion = false
    W.cursor = {800, 450}
    Press(button, true)
    equal(Where(face.slots) .. " " .. N(face.middle.alpha) .. " " .. tostring(face.motion), "0 1 0.78 1 nil", "Ring Motion off: no swirl in, every icon in its place at once")
    W.cursor = {800 + 100 * math.sin(math.rad(216)), 450 + 100 * math.cos(math.rad(216))}
    Step(.016)
    W.cursor = {800 + 100 * math.sin(math.rad(20)), 450 + 100 * math.cos(math.rad(20))}
    Step(.016)
    equal(N(face.bearing) .. " " .. face.lit .. " " .. N(face.slots[1].w), "20 1 42.48", "no glide: the arrow and the lit icon snap")
    Press(button, false)
    equal(tostring(swirl.shown) .. " " .. tostring(swirl.glow.shown), "false false", "and no swirl out or glow: the ring just goes")
    EraUIDB.actionRingMotion = true
    -- The name's plate: a long name after a short one is measured whole
    -- (the game measures inside the width set before: "Heart..." was the bug).
    face.labelText = nil
    V.SetLabel(face, "Hearth")
    V.SetLabel(face, "Hearthstone")
    equal(N(face.label.w), N(#"Hearthstone" * 6 + 2), "Hearthstone whole after a shorter name")
    methods.GetUnboundedStringWidth = function(self) return #(self.text or "") * 6 end
    V.SetLabel(face, "Hearth")
    V.SetLabel(face, "Hearthstone Plus")
    equal(N(face.label.w), N(#"Hearthstone Plus" * 6 + 2), "and with the client's own unbounded width")
    methods.GetUnboundedStringWidth = nil
    W.combat = false
    D.DeleteRing(slot)
    M:Deleted(slot)
end

---------------------------------------------------------------------------
-- 15. The names in Key Bindings
---------------------------------------------------------------------------

do
    EraUIClassicCharDB = {}
    D.Load()
    for i = 1, 10 do M:Name(i) end
    equal(_G["BINDING_NAME_CLICK EraUIRingButton1:LeftButton"] .. " / " .. _G["BINDING_NAME_CLICK EraUIRingButton10:LeftButton"],
        "Action Ring 1 / Action Ring 10", "the plain names")
    local slot = D.NewRing("quest")
    M:Edited(slot)
    equal(_G["BINDING_NAME_CLICK EraUIRingButton1:LeftButton"], "Action Ring 1: Quest Items", "a ring's name joins its entry's")
    D.DeleteRing(slot)
    M:Deleted(slot)
    equal(_G["BINDING_NAME_CLICK EraUIRingButton1:LeftButton"], "Action Ring 1", "deleted: the plain name back")
    E:SetRingBindingName(11, "x")
    equal(_G["BINDING_NAME_CLICK EraUIRingButton11:LeftButton"], nil, "only the ten")
end

---------------------------------------------------------------------------
-- 16. The editor
---------------------------------------------------------------------------

do
    EraUIClassicCharDB = {}
    D.Load()
    MageBook()
    F.Invalidate()
    local content = Frame("Frame", nil, UIParent)
    local row = Frame("Frame", nil, content)
    row.w, row.h = 718, 32
    local settings = {QueueSettingsLayout = function() end}
    E.settingsFrame = settings
    M:AttachEditor(settings, row)
    local p = Ed.panel
    equal(p.parent == content and p.points[1][2] == row and p.points[1][5] == -6 and p.w .. "x" .. p.h, "718x530", "the box under the Your Rings row, the page's width")
    equal(row.inlinePanel, p, "measured with the row (the page grows with it)")
    equal(p.top:GetText(), "Bind each ring in Key Bindings > AddOns > EraUI. A change made in a fight waits for it to end.", "its top line")
    equal(p.none.shown and not p.nameBox.shown, true, "no ring yet: says how to start")
    -- Every line in the box given a width fits its words: 6 px a letter at
    -- 12 pt (by its size), a wrapping one on its lines with a tenth spare.
    local function Fits(where)
        for _, f in ipairs(W.frames) do
            if f.kind == "FontString" and Under(f, p) and f.w > 0 and (f.text or "") ~= "" then
                local size = f.font and f.font[2] or 12
                local lines = f.wordWrap and (f.maxLines or 1) or 1
                local room = f.w * lines * (lines > 1 and .9 or 1)
                if #f.text * size / 2 > room then equal(f.text, "fits in " .. N(room), where .. ": a line in the box cut off") end
                checks = checks + 1
            end
        end
    end
    Fits("no ring yet")
    equal(tostring(p.none.wordWrap) .. " " .. tostring(p.none.maxLines), "true 2", "its words on two lines")
    -- New Ring: every kind, World Markers only with the client's markers.
    PlaceRaidMarker = nil
    p.new:Click()
    local kinds = {}
    for _, entry in ipairs(p.menu.entries) do if entry.shown then kinds[#kinds + 1] = entry.label:GetText() end end
    equal(table.concat(kinds, ","), "Empty Ring,Quest Items,Raid Markers,Mounts,Mage Ring", "New Ring's list, no World Markers without them")
    p.new:Click()
    PlaceRaidMarker = function() end
    p.new:Click()
    kinds = {}
    for _, entry in ipairs(p.menu.entries) do if entry.shown then kinds[#kinds + 1] = entry.label:GetText() end end
    equal(table.concat(kinds, ","), "Empty Ring,Quest Items,Raid Markers,World Markers (experimental),Mounts,Mage Ring", "with them: World Markers (experimental)")
    p.menu.entries[1]:Click()
    equal(Ed.slot .. " " .. D.Ring(1).kind .. " " .. D.Ring(1).name .. " " .. tostring(p.menu.shown), "1 custom My Ring false", "Empty Ring made in slot 1")
    equal(p.list[1].shown and p.list[1].name:GetText() .. " | " .. p.list[1].key:GetText(), "1  My Ring | no key", "listed with no key yet")
    G.bindings["CLICK EraUIRingButton1:LeftButton"] = "BUTTON4"
    M:OnEvent("UPDATE_BINDINGS")
    equal(p.list[1].key:GetText(), "Mouse Button 4", "its key, as the game names it")
    -- The key as wide as its words (at most 96), the ring's name up to it:
    -- a long name ends in "...", never under the key.
    local line = p.list[1]
    equal(N(line.key.w) .. " " .. line.name.points[2][1] .. " " .. tostring(line.name.points[2][2] == line.key) .. " " .. line.name.points[2][3] .. " " .. N(line.name.points[2][4]),
        N(#"Mouse Button 4" * 6 + 2) .. " RIGHT true LEFT -6", "the key as wide as its words; the name stops short of it")
    G.bindings["CLICK EraUIRingButton1:LeftButton"] = "SHIFT-MOUSEWHEELDOWN-AND-MORE"
    M:OnEvent("UPDATE_BINDINGS")
    equal(N(line.key.w), N(Ed.KEY_WIDTH), "a very long key: at most 96, the name keeps the rest")
    G.bindings["CLICK EraUIRingButton1:LeftButton"] = "BUTTON4"
    M:OnEvent("UPDATE_BINDINGS")
    -- Rename: trimmed, at most 24, empty puts its own name back; Escape keeps the old one.
    p.nameBox:SetFocus(); p.nameBox:SetText("  Utility and Travel Ring Plus  "); p.nameBox:ClearFocus()
    equal(D.Ring(1).name .. " | " .. _G["BINDING_NAME_CLICK EraUIRingButton1:LeftButton"], "Utility and Travel Ring | Action Ring 1: Utility and Travel Ring",
        "renamed (24 letters), and its key's name")
    p.nameBox:SetFocus(); p.nameBox:SetText("   "); p.nameBox:ClearFocus()
    equal(D.Ring(1).name, "My Ring", "an empty name puts its own back")
    p.nameBox:SetFocus(); p.nameBox:SetText("Nope"); p.nameBox.scripts.OnEscapePressed(p.nameBox)
    equal(D.Ring(1).name .. " " .. p.nameBox:GetText(), "My Ring My Ring", "Escape keeps the name it had")
    -- The pickers: each kind's button fits the strip; a click on one adds it.
    local right = 0
    for _, tab in ipairs(p.tabs) do right = math.max(right, tab.points[1][4] + tab.w) end
    equal(#p.tabs .. " " .. tostring(right <= Ed.RIGHT + Ed.RIGHT_WIDTH), "9 true", "nine picker buttons, all inside the box")
    equal(p.grid.cells[1].shown and p.grid.cells[1].slice.name, "Conjure Water", "Spells: your spells, the highest rank of each")
    p.grid.cells[1]:Fire("OnEnter")
    equal(W.tips[#W.tips], "Conjure Water", "hovering one names it, in EraUI's own tooltip")
    p.grid.cells[1]:Fire("OnLeave")
    p.grid.cells[1]:Click()
    local ring = D.Ring(1)
    equal(#ring.slices .. " " .. ring.slices[1].id .. " " .. ring.slices[1].rank .. " " .. Ed.k, "1 5506 top 1", "a click adds it")
    equal(S.buttons[1].attrs["s1-value"], 5506, "and the ring has it at once")
    equal(W.tipRows[2] and W.tipRows[2][1], "Spell, highest rank you know", "and under its name, what it is")
    for _, tab in ipairs(p.tabs) do if tab.id == "markers" then tab:Click() end end
    local names = {}
    for i = 1, 22 do local cell = p.grid.cells[i]; names[i] = cell.shown and cell.slice and cell.slice.name or "-" end
    equal(table.concat(names, ","), "Star,Circle,Diamond,Triangle,Moon,Square,Cross,Skull,Clear,-,-,Star,Circle,Diamond,Triangle,Moon,Square,Cross,Skull,Clear All,-,-",
        "Markers: raid markers and Clear on the first row, world markers and Clear All starting the next")
    p.grid.cells[12]:Fire("OnEnter")
    equal(W.tipRows[1][1] .. " / " .. W.tipRows[2][1], "Star / World marker", "hovering a world marker says so")
    p.grid.cells[1]:Fire("OnEnter")
    equal(W.tipRows[1][1] .. " / " .. W.tipRows[2][1], "Star / Raid marker", "and a raid marker")
    p.grid.cells[1]:Fire("OnLeave")
    PlaceRaidMarker = nil
    Ed.Refresh()
    names = {}
    for i = 1, 11 do local cell = p.grid.cells[i]; names[i] = cell.shown and cell.slice and cell.slice.name or "-" end
    equal(table.concat(names, ","), "Star,Circle,Diamond,Triangle,Moon,Square,Cross,Skull,Clear,-,-", "no world markers on the client: the raid ones alone")
    PlaceRaidMarker = function() end
    Ed.Refresh()
    -- Drops: each kind of thing on the cursor.
    local function Drop(...)
        G.cursor = {...}
        local cleared = G.cleared
        p.drop:Fire("OnReceiveDrag")
        return G.cleared - cleared, p.hint:GetText()
    end
    Ed.k = nil
    local cleared = Drop("spell", 3, 0, 5505)
    equal(cleared .. " " .. ring.slices[2].id .. " " .. ring.slices[2].rank, "1 5505 exact", "a dropped lower rank: kept, the cursor cleared")
    Drop("item", 6948, "link")
    Drop("macro", 3)
    Drop("mount", 6)
    Drop("battlepet", "BattlePet-0-1")
    Drop("equipmentset", "Tank")
    Drop("item", 1973, "link")
    local kinds = {}
    for i, slice in ipairs(ring.slices) do kinds[i] = slice.kind end
    equal(table.concat(kinds, ","), "spell,spell,item,macro,mount,pet,equipmentset,toy", "a spell, an item, a macro, a mount, a pet, a set and a toy")
    equal(ring.slices[8].kind .. " " .. ring.slices[8].id .. " " .. tostring(EraUIClassicCharDB.actionRingsProbe), "toy 1973 nil",
        "a toy dropped as an item: kept as the toy, and no drop writes a log")
    local none, said = Drop("money", 50)
    equal(none .. " " .. said .. " " .. #ring.slices, "0 That can't go in a ring. 8", "money is refused, the cursor left alone")
    -- Up to 16; the 17th is refused.
    for _ = 9, 16 do Drop("spell", 4, 0, 587) end
    local full
    full, said = Drop("spell", 4, 0, 587)
    equal(#ring.slices .. " " .. full .. " " .. said, "16 0 Full: a ring holds 16.", "full at 16")
    -- The preview's icons never touch (round outlines and all), from 1 slice
    -- to 16, and stay in its box.
    do
        local all, problems = ring.slices, {}
        for n = 1, 16 do
            ring.slices = {}
            for k = 1, n do ring.slices[k] = all[k] end
            Ed.Refresh()
            local at = {}
            for k = 1, n do
                local icon = p.preview.icons[k]
                local point = icon.points[1]
                at[k] = {point[4], point[5], icon.w}
                if math.max(math.abs(point[4]), math.abs(point[5])) + icon.w / 2 + 2 > Ed.PREVIEW / 2 + 1e-6 then
                    problems[#problems + 1] = n .. " slices: " .. k .. " out of the box"
                end
            end
            for a = 1, n - 1 do
                for b = a + 1, n do
                    local apart = math.sqrt((at[a][1] - at[b][1]) ^ 2 + (at[a][2] - at[b][2]) ^ 2)
                    if apart < (at[a][3] + at[b][3]) / 2 + 4 then problems[#problems + 1] = n .. " slices: " .. a .. " and " .. b .. " " .. N(apart) end
                    checks = checks + 1
                end
            end
        end
        local icon = p.preview.icons[1]
        equal(table.concat(problems, ", ") .. N(icon.w) .. " " .. N(icon.points[1][5]), "24 75", "the preview's icons never touch and stay in its box; 16 slices further out")
        ring.slices = {}
        for k = 1, 14 do ring.slices[k] = all[k] end
        Ed.Refresh()
        equal(N(icon.w) .. " " .. N(icon.points[1][5]), "24 66", "14 slices: as before")
        ring.slices = all
        Ed.Refresh()
    end
    for _ = 1, 8 do Ed.k = #ring.slices; p.remove:Click() end
    equal(#ring.slices, 8, "Remove, eight times from the end")
    -- Choosing a slice, moving and removing it.
    p.preview.icons[2]:Click()
    equal(Ed.k .. " " .. p.slotName:GetText() .. " | " .. p.slotKind:GetText(), "2 Conjure Water | Spell, kept at Rank 2", "a slice chosen: its name and kind")
    equal(p.keep.shown and p.keep.tickMark.shown, true, "a lower rank: Keep This Rank, ticked")
    p.keep:Click()
    equal(ring.slices[2].rank .. " " .. S.buttons[1].attrs["s2-value"], "top 5506", "unticked: it follows the highest rank")
    p.keep:Click()
    equal(ring.slices[2].rank .. " " .. S.buttons[1].attrs["s2-value"], "exact 5505", "ticked again: kept at rank 2")
    p.later:Click()
    equal(Ed.k .. " " .. ring.slices[3].id .. " " .. ring.slices[2].id, "3 5505 6948", "Move Later")
    p.earlier:Click(); p.earlier:Click()
    equal(Ed.k .. " " .. ring.slices[1].id, "1 5505", "Move Earlier, twice")
    p.earlier:Click()
    equal(Ed.k, 1, "the first can't move earlier")
    p.remove:Click()
    equal(#ring.slices .. " " .. ring.slices[1].id .. " " .. Ed.k, "7 5506 1", "Remove")
    -- A long ring name in the preview's middle: whole, on up to two lines.
    p.nameBox:SetFocus(); p.nameBox:SetText("Utility and Travel Ring"); p.nameBox:ClearFocus()
    equal(p.preview.label:GetText() .. " " .. tostring(p.preview.label.maxLines), "Utility and Travel Ring 2", "a long ring name in the preview, on two lines")
    Fits("a ring with a long name, a slice chosen")
    -- The preview looks like the ring: no dark disc or track behind its
    -- icons; each icon outlined in the ring's rim colour, the chosen one
    -- (slice 1) in its accent colour, in Dark Mode and Classic.
    local function Tint(t) return string.format("%.3f,%.3f,%.3f", t[1], t[2], t[3]) end
    equal(tostring(p.preview.dial) .. " " .. tostring(p.preview.band) .. " " .. Ed.k, "nil nil 1", "the preview: no dark disc or track; slice 1 chosen")
    for _, t in ipairs(W.frames) do
        if t.kind == "Texture" and t.parent == p.preview then equal(tostring(t.texture), "only icons", "a texture behind the preview's icons") end
    end
    checks = checks + 1
    EraUIDB.darkMode = true
    Ed.Refresh()
    local palette = V.Palette()
    equal(Tint(p.preview.icons[2].outline.vertex) .. " / " .. Tint(p.preview.icons[1].outline.vertex), Tint(palette.rim) .. " / " .. Tint(palette.accent),
        "the preview in Dark Mode: the ring's rims, the chosen one its accent")
    equal(Tint(palette.rim) .. " / " .. Tint(palette.accent), "0.300,0.310,0.340 / 0.250,0.780,0.920", "(Dark Mode's muted grey and your class colour)")
    EraUIDB.darkMode = false
    Ed.Refresh()
    equal(Tint(p.preview.icons[2].outline.vertex) .. " / " .. Tint(p.preview.icons[1].outline.vertex), "0.550,0.450,0.200 / 1.000,0.820,0.000",
        "and in Classic: bronze, the chosen one gold")
    -- In a fight: a drop waits; other changes are saved and made when it ends.
    W.combat = true
    none, said = Drop("spell", 4, 0, 587)
    equal(none .. " " .. said .. " " .. #ring.slices, "0 Drop it after this fight. 7", "in a fight a drop waits")
    G.cursor = nil
    p.nameBox:SetFocus(); p.nameBox:SetText("Fight Ring"); p.nameBox:ClearFocus()
    equal(ring.name .. " | " .. p.hint:GetText() .. " | " .. tostring(S.dirty[1]), "Fight Ring | Saved. Your ring changes when this fight ends. | true",
        "renamed in a fight: saved, made when it ends")
    p.remove:Click()
    equal(#ring.slices .. " " .. S.buttons[1].attrs["ring-count"], "6 7", "removed in a fight: saved, the ring unchanged")
    W.combat = false
    M:OnEvent("PLAYER_REGEN_ENABLED")
    equal(S.buttons[1].attrs["ring-count"] .. " " .. V.faces[1].ringName, "6 Fight Ring", "the fight over: both made")
    -- A ready-made ring: its note, Make Editable, no editing until then.
    p.new:Click()
    for _, entry in ipairs(p.menu.entries) do if entry.ringKind == "raid" then entry:Click() end end
    equal(Ed.slot .. " " .. p.note:GetText() .. " | " .. tostring(p.editable.shown), "2 Marks your target. Pick a mark again to take it off. | true",
        "Raid Markers: its note and Make Editable")
    equal(#p.preview.icons > 0 and p.preview.icons[9].shown and p.preview.icons[9].tip, "Clear", "its nine slices in the preview")
    p.grid.cells[1]:Click()
    equal(p.hint:GetText(), "This ring fills itself. Make Editable to add your own.", "a ready-made ring takes nothing")
    p.editable:Click()
    equal(D.Ring(2).kind .. " " .. #D.Ring(2).slices .. " " .. D.Ring(2).slices[9].id, "custom 9 0", "Make Editable: your own ring holding what it held")
    -- A name typed for one ring stays that ring's, whatever is clicked before
    -- it's saved (a click on a button leaves the box typing): another ring in
    -- the list, New Ring or Delete each save it first.
    do
        local box = p.nameBox
        box:SetFocus(); box:SetText("Marks")
        p.list[1]:Click()
        equal(D.Ring(2).name .. " | " .. D.Ring(1).name .. " | " .. Ed.slot .. " " .. box:GetText() .. " " .. tostring(box:HasFocus()),
            "Marks | Fight Ring | 1 Fight Ring false", "typed for ring 2, then ring 1 clicked: ring 2 renamed, ring 1 as it was, its name shown")
        equal(_G["BINDING_NAME_CLICK EraUIRingButton2:LeftButton"] .. " / " .. _G["BINDING_NAME_CLICK EraUIRingButton1:LeftButton"],
            "Action Ring 2: Marks / Action Ring 1: Fight Ring", "and only ring 2's key entry changed")
        box:SetFocus(); box:SetText("Travel")
        p.new:Click()
        p.menu.entries[1]:Click()
        local extra = Ed.slot
        equal(D.Ring(1).name .. " | " .. D.Ring(extra).name .. " " .. box:GetText(), "Travel | My Ring My Ring",
            "typed, then New Ring: the name goes to the ring it was typed for")
        box:SetFocus(); box:SetText("Spare")
        p.delete:Click()
        equal(D.Ring(extra).name .. " " .. p.delete.label:GetText(), "Spare Delete?", "typed, then Delete: the name saved, then the question")
        p.delete:Click()
        equal(tostring(D.Ring(extra)) .. " " .. D.Ring(1).name .. " " .. D.Ring(2).name, "nil Travel Marks", "then deleted, no other ring renamed")
        -- The chosen ring changed any other way while typing: still the ring it was typed for.
        equal(Ed.slot, 1, "ring 1 chosen after the delete")
        box:SetFocus(); box:SetText("Fight Ring")
        Ed.slot = 2
        box:ClearFocus()
        equal(D.Ring(1).name .. " | " .. D.Ring(2).name .. " | " .. box:GetText(), "Fight Ring | Marks | Marks", "renamed ring 1, the box showing ring 2's")
        p.list[2]:Click()
        equal(Ed.slot, 2, "back on ring 2")
    end
    -- A pick from it first, for the key pressed again once it's gone (below).
    W.cursor = {800, 450}
    Press(S.buttons[2], true)
    W.cursor = {800, 650}
    Press(S.buttons[2], false)
    equal(S.buttons[2].attrs.chosen, 1, "a pick from ring 2: slice 1")
    -- Delete: the first click asks, the second deletes (and puts the ring away).
    local executes = W.executes
    p.delete:Click()
    equal(p.delete.label:GetText() .. " " .. tostring(D.Ring(2) ~= nil), "Delete? true", "the first click asks")
    p.delete:Click()
    equal(tostring(D.Ring(2)) .. " " .. Ed.slot .. " " .. (W.executes - executes) .. " " .. tostring(S.buttons[2].attrs["ring-off"]), "nil 1 1 true",
        "the second deletes it, puts the rings away, its key does nothing")
    equal(_G["BINDING_NAME_CLICK EraUIRingButton2:LeftButton"], "Action Ring 2", "and its key's name is the plain one again")
    -- Its key pressed again: PICK refuses before "chosen" changes, and
    -- PostClick returns at once, so the view hears nothing (no phantom pick
    -- of the old slice).
    do
        local opened, closed = V.Opened, V.Closed
        local heard = 0
        V.Opened = function(...) heard = heard + 1; return opened(...) end
        V.Closed = function(...) heard = heard + 1; return closed(...) end
        W.casts = {}
        W.cursor = {800, 450}
        Press(S.buttons[2], true)
        W.cursor = {800, 650}
        Press(S.buttons[2], false)
        V.Opened, V.Closed = opened, closed
        equal(S.buttons[2].attrs.chosen .. " " .. heard .. " " .. #W.casts .. " " .. tostring(V.open) .. " " .. tostring(EraUIClassicCharDB.actionRingsProbe),
            "1 0 0 nil nil", "a deleted ring's key: chosen as it was, the view hears nothing, nothing cast, nothing open, nothing logged")
    end
    -- Ready-made rings' notes, whole on two lines beside Make Editable; a
    -- slice that can't be used now says so in full; and an empty ready-made
    -- ring, opened, says why it's empty (it can't be filled by hand).
    local function Opened(slot)
        W.cursor = {800, 450}
        Press(S.buttons[slot], true)
        local text = V.faces[slot].label:GetText()
        Press(S.buttons[slot], false)
        return text
    end
    local quest = D.NewRing("quest")
    M:Edited(quest)
    Ed.slot, Ed.k = quest, nil
    Ed.Refresh()
    equal(p.note:GetText() .. " | " .. tostring(p.note.maxLines) .. " " .. N(p.note.points[1][5]), Ed.NOTES.quest .. " | 2 -64", "Quest Items: its note on two lines")
    Fits("Quest Items")
    equal(#F.Slices(D.Ring(quest)) .. " " .. Opened(quest), "0 No quest items", "no quest items in your bags: it says so, not to add slices")
    local world = D.NewRing("world")
    M:Edited(world)
    Ed.slot = world
    Ed.Refresh()
    equal(p.note:GetText(), Ed.NOTES.world, "World Markers: its note, (experimental) and all")
    Fits("World Markers")
    PlaceRaidMarker = nil
    M:Edited(world)
    equal(Opened(world), "No world markers here", "World Markers where the client has none")
    PlaceRaidMarker = function() end
    local poisons = D.NewRing("class")
    W.class, W.className = "ROGUE", "Rogue"
    M:Edited(poisons)
    equal(Opened(poisons), "No poisons in your bags", "a rogue's ring with no poisons")
    W.class, W.className = "MAGE", "Mage"
    local own = D.NewRing("custom")
    D.AddSlice(own, {kind = "spell", id = 10054, rank = "top", name = "Conjure Mana Ruby"})
    M:Edited(own)
    Ed.slot, Ed.k = own, 1
    Ed.Refresh()
    equal(p.slotKind:GetText() .. " | " .. tostring(p.slotKind.maxLines), "Spell, highest rank you know. Can't be used now. | 2", "a greyed slice says why, on two lines")
    Fits("a greyed slice chosen")
    local bare = D.NewRing("custom")
    M:Edited(bare)
    equal(Opened(bare), "Empty ring. Add slices in /era.", "an empty ring of your own: where to fill it")
    for _, slot in ipairs({quest, world, poisons, own, bare}) do D.DeleteRing(slot); M:Deleted(slot) end
    Ed.slot, Ed.k = 1, nil
    Ed.Refresh()
    -- The most rings there can be.
    for _ = 2, 10 do D.NewRing("custom") end
    Ed.Refresh()
    p.new:Click()
    equal(tostring(p.menu.shown) .. " " .. p.hint:GetText(), "false You have 10 rings, the most there can be.", "ten rings: New Ring says so")
    -- Off: the box goes with its row.
    M:HideEditor()
    equal(p.shown, false, "hidden with its row")
end

---------------------------------------------------------------------------
-- 17. Nothing it must never call
---------------------------------------------------------------------------

equal(table.concat(W.forbidden, ","), "", "no key binding changed, no GameTooltip, no MouseIsOver, no Edit Mode")
equal(#W.tips > 0, true, "names shown through EraUI's own tooltip")

---------------------------------------------------------------------------
-- The settings page: Action Bars > Action Rings in the real /era window
---------------------------------------------------------------------------

do
    local SM = dofile("Tools/SettingsMock.lua")
    for _, key in ipairs({"SetRotation", "SetDrawEdge", "SetDrawBling", "SetHideCountdownNumbers", "Clear", "SetCooldown"}) do
        SM.methods[key] = SM.methods[key] or function() end
    end
    local E2, f = SM.Session("MAGE", nil, nil, nil, function(E2)
        for _, name in ipairs(RING_FILES) do
            if name ~= "RingRows" then assert(loadfile("Modules/" .. name .. ".lua"))("EraUI", E2) end
        end
        E2.SetRingBindingName = function() end
        SecureHandlerSetFrameRef, SecureHandlerWrapScript, SecureHandlerExecute = function() end, function() end, function() end
        -- Its settings as a new player has them (Core/Init.lua's defaults).
        for key, value in pairs(E.settingDefaults) do
            if key:find("^actionRing") then E2.settings[key], E2.settingDefaults[key] = value, value end
        end
    end)
    SM.Open(f, "actionBars", "rings")
    SM.equal(table.concat(SM.Keys(f), ","), "actionRings", "the switch alone while it's off")
    SM.equal(E2.RingEditor.panel, nil, "and no box")
    f.checks.actionRings:Click(); SM.Flush()
    equal(E2.settings.actionRings, true, "a click on the row switches it on")
    SM.equal(table.concat(SM.Keys(f), ","), "actionRings,actionRingScale,actionRingNames,actionRingCooldowns,actionRingMotion,actionRingEditor",
        "on: its options, then Your Rings")
    SM.equal(tostring(f.checks.actionRingNames:GetChecked()) .. " " .. tostring(f.checks.actionRingCooldowns:GetChecked()) .. " "
        .. tostring(f.checks.actionRingMotion:GetChecked()) .. " " .. f.checks.actionRingScale.text:GetText(), "true true true Ring Size: 100%",
        "Slice Names, Cooldowns & Counts and Ring Motion start ticked, Ring Size at 100%")
    local heading, panel = f.checks.actionRingEditor, E2.RingEditor.panel
    SM.equal(heading.wide and panel ~= nil and heading.inlinePanel == panel and panel:IsShown(), true, "the box under the whole-line Your Rings")
    SM.NoOverlaps(f, "Action Rings")
    SM.Fits(f, "Action Rings")
    SM.equal(f.settingsContent:GetHeight() > f.settingsScroll:GetHeight() + .01 and f.settingsScrollHint:IsShown(), true, "the page scrolls with the box open")
    SM.equal(panel:GetTop() <= heading:GetBottom() - 5.99 and panel:GetLeft() == f.settingsContent:GetLeft(), true, "6 under its row, at the page's left")
    SM.equal(f.checks.actionRings.tagIds[1], "TEST", "Action Rings says experimental")
    -- /era closed: the box goes with its row (the row's OnHide), so a fight
    -- starting or ending, a key changed or the rings switched off and on
    -- redraw nothing nobody sees; opening /era again redraws it.
    do
        local Ed2, M2 = E2.RingEditor, E2.modules.ActionRings
        local drawn, draw = 0, Ed2.DrawPicker
        Ed2.DrawPicker = function(...)
            drawn = drawn + 1
            return draw(...)
        end
        f:Hide(); SM.Flush()
        SM.equal(tostring(panel:IsShown()) .. " " .. tostring(panel:IsVisible()), "false false", "/era closed: the box hidden, not just out of sight")
        M2:OnEvent("PLAYER_REGEN_DISABLED")
        M2:OnEvent("PLAYER_REGEN_ENABLED")
        M2:OnEvent("UPDATE_BINDINGS")
        M2:Refresh()
        SM.equal(drawn, 0, "closed: a fight, a key change and a refresh redraw nothing")
        f:Show(); SM.Flush()
        SM.equal(tostring(drawn > 0) .. " " .. tostring(panel:IsVisible()), "true true", "opened again: the box shows, redrawn")
        Ed2.DrawPicker = draw
    end
    -- In a fight: the page, the box and its ticks change nothing protected
    -- (the mock throws if they did); a new ring is saved for later.
    SM.S.combat = true
    SM.Open(f, "class"); SM.Open(f, "actionBars", "rings")
    panel.new:Click()
    for _, entry in ipairs(panel.menu.entries) do if entry.ringKind == "raid" then entry:Click() end end
    SM.equal(E2.RingData.Ring(1) and E2.RingData.Ring(1).kind .. " " .. panel.hint:GetText(), "raid Saved. Your ring changes when this fight ends.",
        "a ring made in a fight: saved, made when it ends")
    f.checks.actionRingMotion:Click(); SM.Flush()
    SM.NoOverlaps(f, "Action Rings in a fight")
    -- The switch in a fight: chat says the rings follow when it ends (and
    -- the editor's own line isn't said again that fight).
    local said
    local status = E2.Status
    E2.Status = function(_, text) said = text end
    E2.RingSecure.told = nil
    f.checks.actionRings:Click(); SM.Flush()
    SM.equal(tostring(said) .. " | " .. tostring(E2.RingSecure.told), "Action Rings disabled. Your rings stop when this fight ends. | true",
        "switched off in a fight: chat says when")
    f.checks.actionRings:Click(); SM.Flush()
    SM.equal(said, "Action Rings enabled. Give each ring a key in Key Bindings > AddOns > EraUI. Your rings start when this fight ends.", "and on again")
    E2.Status = status
    SM.S.combat = false
    f.checks.actionRingMotion:Click(); SM.Flush()
    f.checks.actionRings:Click(); SM.Flush()
    SM.equal(table.concat(SM.Keys(f), ",") .. " " .. tostring(panel:IsShown()), "actionRings false", "off: its rows and the box fold away")
    checks = checks + SM.checks
end

print("Action ring checks passed: " .. checks .. " assertions.")
