-- Square Minimap (Map & Minimap) on the real Classic/Minimap.lua and
-- Modules/MinimapTools.lua, with Classic/Textures.lua, Core/Appearance.lua
-- (Dark Mode's grey and the Darkness slider) and Classic/Skin.lua, against a
-- mock of Forever's minimap cluster keyed as its Blizzard_Minimap XML builds
-- it (the cluster, its zone button and name, tracking, mail, the container
-- with the map, its zoom buttons and backdrop, the compass textures, the
-- calendar, clock, queue eye, day and night, the native coordinates, the
-- hybrid map's round mask) and a minimap button library. Every piece's
-- place is worked out through its anchors, at the map's own scale.
-- Checked: off (the default) is the round look exactly, nothing made, the
-- shape unclaimed. On: the map's mask square; EraUI's frame (unnamed, no
-- mouse) a level under the zone's name, its near-black edge tiling the band
-- round the map exactly with the zone's strip on top, the fine line one unit
-- wide 1 to 2 out from the map, square at the corners, clear of the map;
-- the line bronze in the Classic look, the Darkness grey in Dark Mode, live
-- with the slider (in a fight too); the stone ring, its top bar and the
-- rotating compass ring put aside; the zone's name centred on the strip;
-- the zoom buttons and the eye on the square's edges, tracking, mail,
-- calendar and clock where they were, none overlapping; EraUI's own button
-- and the drawer's on the square's edge for every direction, live; the
-- library told SQUARE and its button on the edge too; another addon's
-- GetMinimapShape never replaced, ours given back; the hybrid map's mask
-- square and its own file back; Classic and Dark Mode, Edit Mode's size,
-- Clean Minimap's hover and drawer, the coordinates under the frame. Live
-- on and off, back to the round look exactly (every game piece's place,
-- size, art, mask and shown state), no key written on the game's frames
-- beyond what the round look writes, no kind of change to them beyond the
-- round look's (and the hybrid mask's file). In a fight a switch changes
-- nothing and books the pass after it. Minimap off: nothing. The game's
-- own round mask after a rotation switch is put right. Square Size (its
-- slider): the cluster at Edit Mode's size times it while the square is
-- worn, every place the same in the map's units, ignored while off, live,
-- waiting out a fight, unreadable values at 100%, back to Edit Mode's size
-- on restore. The cluster is an Edit Mode frame here (Edit Mode's own
-- SetScale, SetPoint and ClearAllPoints in place, their records listed as
-- writes): it's resized only through its plain SetScaleBase and
-- SetPointBase, no record written, its corner kept where Edit Mode put it
-- (snapped to another Edit Mode frame too), never in a fight.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end
unpack = unpack or table.unpack
local function N(v) return string.format("%g", math.floor(v * 100 + .5) / 100) end
local function C(r, g, b, a) return string.format("%.3f,%.3f,%.3f,%.3f", r, g, b, a or 1) end

-- Mock widgets ------------------------------------------------------------------------
-- Each object's state lives beside it (S). A key written on one of the
-- game's objects is listed in writes as "label.key"; while logging, every
-- call made on one of them is listed as "label:Method".
local W, H = 1920, 1080
local S = setmetatable({}, { __mode = "k" })
local Proto = {}
local writes, calls, logging = {}, {}, false
local made = {} -- EraUI's own objects, in order
local function New(kind, name, parent, game, layer)
    local obj = {}
    local p = parent and S[parent]
    local s = { kind = kind, name = name, parent = parent, game = game, points = {}, w = 0, h = 0, scale = 1, alpha = 1,
        shown = true, level = (p and p.level or 0) + 1, strata = p and p.strata or "MEDIUM", layer = layer, scripts = {},
        hooks = {}, events = {}, children = {}, regions = {}, label = name }
    S[obj] = s
    if p then
        if kind == "Texture" or kind == "FontString" or kind == "MaskTexture" then table.insert(p.regions, obj)
        else table.insert(p.children, obj) end
    end
    if not game then made[#made + 1] = obj end
    if name then _G[name] = obj end
    return setmetatable(obj, {
        __index = function(_, key)
            local fn = Proto[key]
            if not fn then return nil end
            return function(self, ...)
                local st = S[self]
                if logging and st and st.game then calls[#calls + 1] = tostring(st.label) .. ":" .. key end
                return fn(self, ...)
            end
        end,
        __newindex = function(t, key, value)
            if S[t].game then writes[#writes + 1] = tostring(S[t].label) .. "." .. tostring(key) end
            rawset(t, key, value)
        end,
    })
end
local function Region(s) return s.kind == "Texture" or s.kind == "FontString" or s.kind == "MaskTexture" end
function Proto:GetName() return S[self].name end
function Proto:GetParent() return S[self].parent end
function Proto:SetParent(p)
    local s = S[self]
    if s.parent and S[s.parent] then
        local list = S[s.parent].children
        for i, child in ipairs(list) do if child == self then table.remove(list, i); break end end
    end
    s.parent = p
    if p then table.insert(S[p].children, self); s.level = S[p].level + 1; s.strata = S[p].strata end
end
function Proto:GetChildren() return unpack(S[self].children) end
function Proto:GetRegions() return unpack(S[self].regions) end
function Proto:IsObjectType(kind) return S[self].kind == kind end
function Proto:GetObjectType() return S[self].kind end
function Proto:IsForbidden() return false end
function Proto:IsProtected() return false end
function Proto:GetFrameLevel() return S[self].level end
function Proto:SetFrameLevel(v) S[self].level = v end
function Proto:GetFrameStrata() return S[self].strata end
function Proto:SetFrameStrata(v) S[self].strata = v end
function Proto:HasFixedFrameStrata() return false end
function Proto:HasFixedFrameLevel() return false end
function Proto:IsShown() return S[self].shown end
function Proto:IsVisible() local s = S[self]; return s.shown and (s.parent == nil or s.parent:IsVisible()) end
function Proto:Show() S[self].shown = true end
function Proto:Hide() S[self].shown = false end
function Proto:SetShown(v) S[self].shown = v and true or false end
function Proto:SetAlpha(a) S[self].alpha = a end
function Proto:GetAlpha() return S[self].alpha end
function Proto:EnableMouse(v) S[self].mouse = v and true or false end
function Proto:IsMouseEnabled() local s = S[self]; if s.mouse == nil then return s.kind == "Button" end; return s.mouse end
function Proto:ClearAllPoints() S[self].points = {} end
function Proto:SetPoint(point, rel, relPoint, x, y)
    local s = S[self]
    if type(rel) == "number" then rel, relPoint, x, y = nil, nil, rel, relPoint end
    if rel == nil and relPoint == nil and x == nil then rel = s.parent end
    local entry = { point, rel or s.parent, relPoint or point, x or 0, y or 0 }
    for i, old in ipairs(s.points) do if old[1] == point then s.points[i] = entry; return end end
    table.insert(s.points, entry)
end
function Proto:SetAllPoints(rel)
    rel = rel or S[self].parent
    S[self].points = { { "TOPLEFT", rel, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", rel, "BOTTOMRIGHT", 0, 0 } }
end
function Proto:GetNumPoints() return #S[self].points end
function Proto:GetPoint(i) local p = S[self].points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Proto:SetSize(w, h) local s = S[self]; local changed = s.w ~= w or s.h ~= h; s.w, s.h = w, h
    if changed and s.scripts.OnSizeChanged then s.scripts.OnSizeChanged(self, w, h) end
    for _, fn in ipairs(s.hooks.OnSizeChanged or {}) do if changed then fn(self, w, h) end end
end
function Proto:SetWidth(w) self:SetSize(w, S[self].h) end
function Proto:SetHeight(h) self:SetSize(S[self].w, h) end
function Proto:GetWidth() return S[self].w end
function Proto:GetHeight() return S[self].h end
function Proto:GetSize() return S[self].w, S[self].h end
function Proto:SetScale(v) S[self].scale = v end
function Proto:GetScale() return S[self].scale end
local function Eff(obj)
    local s = S[obj]
    if Region(s) then return Eff(s.parent) end
    return s.scale * (s.parent and Eff(s.parent) or 1)
end
function Proto:GetEffectiveScale() return Eff(self) end
function Proto:SetScript(name, fn) S[self].scripts[name] = fn end
function Proto:GetScript(name) return S[self].scripts[name] end
function Proto:HasScript() return true end
function Proto:HookScript(name, fn) local s = S[self]; s.hooks[name] = s.hooks[name] or {}; table.insert(s.hooks[name], fn) end
function Proto:RegisterEvent(event) S[self].events[event] = true end
function Proto:UnregisterEvent(event) S[self].events[event] = nil end
function Proto:UnregisterAllEvents() S[self].events = {} end
function Proto:CreateTexture(_, layer) return New("Texture", nil, self, false, layer or "ARTWORK") end
function Proto:CreateFontString(_, layer) return New("FontString", nil, self, false, layer or "ARTWORK") end
function Proto:SetTexture(file, h, v) local s = S[self]; s.texture, s.wrap, s.colour, s.atlas = file, (h or "") .. "/" .. (v or ""), nil, nil; return true end
function Proto:GetTexture() return S[self].texture end
function Proto:SetColorTexture(r, g, b, a) local s = S[self]; s.colour, s.texture = C(r, g, b, a), nil end
function Proto:SetVertexColor(r, g, b, a) S[self].tint = C(r, g, b, a) end
function Proto:SetTexCoord(...) S[self].coords = table.concat({ ... }, ",") end
function Proto:SetAtlas(atlas) local s = S[self]; s.atlas, s.texture = atlas, nil end
function Proto:GetAtlas() return S[self].atlas end
function Proto:SetDrawLayer(layer) S[self].layer = layer end
function Proto:SetBlendMode(mode) S[self].blend = mode end
function Proto:SetDesaturated(v) S[self].desaturated = v end
function Proto:SetMaskTexture(asset) S[self].mask = asset end
function Proto:SetHitRectInsets(...) S[self].hit = table.concat({ ... }, ",") end
function Proto:SetJustifyH(v) S[self].justify = v end
function Proto:SetFont(...) S[self].font = table.concat({ ... }, ",") end
function Proto:SetFontObject(v) S[self].fontObject = v end
function Proto:SetNormalFontObject(v) S[self].fontObject = v end
function Proto:SetTextColor(r, g, b) S[self].textColour = C(r, g, b) end
function Proto:SetText(text) S[self].text = text; local fs = S[self].fontString; if fs then fs:SetText(text) end end
function Proto:GetText() return S[self].text end
function Proto:SetFormattedText(f, ...) S[self].text = string.format(f, ...) end
function Proto:GetFontString() return S[self].fontString end
function Proto:SetFontString(fs) S[self].fontString = fs end
function Proto:GetStringWidth() return #(S[self].text or "") * 6 end
function Proto:GetStringHeight() return 12 end
function Proto:IsEnabled() return S[self].enabled ~= false end
function Proto:Enable() S[self].enabled = true end
function Proto:Disable() S[self].enabled = false end
function Proto:SetEnabled(v) S[self].enabled = v and true or false end
function Proto:RegisterForClicks() end
function Proto:RegisterForDrag() end
function Proto:SetClampedToScreen() end
function Proto:SetBackdrop(v) S[self].backdrop = v end
function Proto:SetBackdropColor(...) S[self].fill = C(...) end
function Proto:SetBackdropBorderColor(...) S[self].border = C(...) end
function Proto:SetWordWrap() end
for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
    Proto["Set" .. state .. "Texture"] = function(self, file)
        local s = S[self]
        s[state] = s[state] or New("Texture", nil, self, s.game, state == "Highlight" and "HIGHLIGHT" or "ARTWORK")
        s[state]:SetTexture(file)
    end
    Proto["Get" .. state .. "Texture"] = function(self) return S[self][state] end
end

-- Where a region sits on the screen (left, bottom, right, top; y up),
-- worked out through its anchors as the game lays it out: offsets and sizes
-- at its own effective scale.
local FRAC = { TOPLEFT = { 0, 1 }, TOP = { .5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, .5 }, CENTER = { .5, .5 },
    RIGHT = { 1, .5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { .5, 0 }, BOTTOMRIGHT = { 1, 0 } }
local function Rect(obj, depth)
    depth = (depth or 0) + 1
    assert(depth < 40, "anchor loop")
    if obj == UIParent then return 0, 0, W, H end
    local s = S[obj]
    assert(#s.points > 0, tostring(s.label or s.kind) .. " has no place")
    local e = Eff(obj)
    local left, right, top, bottom, cx, cy
    for _, p in ipairs(s.points) do
        local l, b, r, t = Rect(p[2], depth)
        local f, g = assert(FRAC[p[3]], p[3]), assert(FRAC[p[1]], p[1])
        local ax, ay = l + f[1] * (r - l) + p[4] * e, b + f[2] * (t - b) + p[5] * e
        if g[1] == 0 then left = ax elseif g[1] == 1 then right = ax else cx = ax end
        if g[2] == 0 then bottom = ay elseif g[2] == 1 then top = ay else cy = ay end
    end
    local w, h = s.w * e, s.h * e
    if not left then left = right and right - w or cx - w / 2 end
    right = right or left + w
    if not bottom then bottom = top and top - h or cy - h / 2 end
    top = top or bottom + h
    return left, bottom, right, top
end
function Proto:GetCenter() local l, b, r, t = Rect(self); local e = Eff(self); return (l + r) / 2 / e, (b + t) / 2 / e end
function Proto:GetLeft() local l = Rect(self); return l / Eff(self) end
function Proto:GetRight() local _, _, r = Rect(self); return r / Eff(self) end
function Proto:GetTop() local _, _, _, t = Rect(self); return t / Eff(self) end
function Proto:GetBottom() local _, b = Rect(self); return b / Eff(self) end
local cursor = { 0, 0 }
function Proto:IsMouseOver()
    if not self:IsVisible() then return false end
    local l, b, r, t = Rect(self)
    return cursor[1] >= l and cursor[1] <= r and cursor[2] >= b and cursor[2] <= t
end

-- A region's box from the map's centre, in the map's units: left, bottom,
-- right, top; and its centre.
local function Box(obj)
    local ml, mb, mr, mt = Rect(Minimap)
    local mx, my, e = (ml + mr) / 2, (mb + mt) / 2, Eff(Minimap)
    local l, b, r, t = Rect(obj)
    return (l - mx) / e, (b - my) / e, (r - mx) / e, (t - my) / e
end
local function Spot(obj) local l, b, r, t = Box(obj); return N((l + r) / 2) .. "," .. N((b + t) / 2) end
local function BoxText(obj) local l, b, r, t = Box(obj); return N(l) .. "," .. N(b) .. "," .. N(r) .. "," .. N(t) end
local function Area(l, b, r, t) return math.max(0, r - l) * math.max(0, t - b) end
local function Overlap(a, b)
    local l1, b1, r1, t1 = Box(a)
    local l2, b2, r2, t2 = Box(b)
    return Area(math.max(l1, l2), math.max(b1, b2), math.min(r1, r2), math.min(t1, t2))
end

-- The game -----------------------------------------------------------------------------
local combat = false
InCombatLockdown = function() return combat end
GetTime = function() return 100 end
GetCursorPosition = function() return cursor[1], cursor[2] end
CreateFrame = function(kind, name, parent) return New(kind, name, parent or UIParent, false) end
CreateFont = function() return { SetFontObject = function() end, SetTextColor = function() end } end
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
local timers = {}
C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
local function RunTimers()
    for _ = 1, 10 do
        if #timers == 0 then return end
        local due = timers; timers = {}
        for _, fn in ipairs(due) do fn() end
    end
end
local rotate = false
C_CVar = { GetCVarBool = function(name) return name == "rotateMinimap" and rotate end }
C_DateAndTime = { GetCurrentCalendarTime = function() return { monthDay = 15 } end }
C_Map = {}
Enum = { EditModeMinimapSetting = { Size = 1 } }
hooksecurefunc = function(t, key, fn)
    if type(t) == "string" then t, key, fn = _G, t, key end
    local old = rawget(t, key)
    rawset(t, key, function(...) old(...); fn(...) end)
end
GameTooltip = { SetOwner = function() end, SetText = function() end, AddLine = function() end, Show = function() end, Hide = function() end }

local MASK_ROUND = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local MASK_SQUARE = "Interface\\Buttons\\WHITE8X8"
local GAME_MASK = "ui-hud-minimap-frame-generic-mask"
local game -- the game's pieces by label, and the library
local gameList = {} -- this session's pieces of the game's, in order
local function G(kind, name, parent, w, h, label, layer)
    local o = New(kind, name, parent, true, layer)
    gameList[#gameList + 1] = o
    S[o].w, S[o].h = w or 0, h or 0
    S[o].label = label or name
    return o
end
local function Put(obj, key, value) rawset(obj, key, value); return value end
-- A table of the game's whose every write is listed in writes as "label",
-- or "label.key" byKey (its keys, as the game set them itself, are the
-- second value).
local function Logged(label, byKey)
    local keys = {}
    return setmetatable({}, { __index = keys, __newindex = function(_, key, value)
        writes[#writes + 1] = byKey and (label .. "." .. tostring(key)) or label
        keys[key] = value
    end }), keys
end
-- Edit Mode's frames (the cluster is one): OnSystemLoad keeps the plain
-- SetScale, SetPoint and ClearAllPoints as ...Base and puts Edit Mode's own
-- in their place (Blizzard_EditMode/Shared/EditModeSystemTemplates.lua
-- SetScaleOverride, SetPointOverride, ClearAllPointsOverride,
-- SetSnappedToFrame, ClearFrameSnap; EditModeManager.lua
-- OnEditModeSystemAnchorChanged). Their records (the frame it snaps to, that
-- frame's list, every anchor marked changed) show as writes here: run from
-- EraUI's code they would carry EraUI's taint. Each call is listed while
-- logging, under the name it was called by.
local editMode -- EditModeManagerFrame's keys
local function EditModeFrame(frame)
    local label = S[frame].label
    local function Logs(name, fn)
        return function(self, ...)
            if logging then calls[#calls + 1] = label .. ":" .. name end
            return fn(self, ...)
        end
    end
    Put(frame, "SetScaleBase", Logs("SetScaleBase", Proto.SetScale))
    Put(frame, "SetPointBase", Logs("SetPointBase", Proto.SetPoint))
    Put(frame, "ClearAllPointsBase", Logs("ClearAllPointsBase", Proto.ClearAllPoints))
    Put(frame, "SetScale", Logs("SetScale", function(self, newScale)
        local oldScale = self:GetScale()
        self:SetScaleBase(newScale)
        if oldScale == newScale then return end
        for i = 1, self:GetNumPoints() do
            local point, rel, relPoint, x, y = self:GetPoint(i)
            self:SetPoint(point, rel, relPoint, x * oldScale / newScale, y * oldScale / newScale)
        end
    end))
    Put(frame, "SetPoint", Logs("SetPoint", function(self, point, rel, relPoint, x, y)
        self:SetPointBase(point, rel, relPoint, x, y)
        self:SetSnappedToFrame(rel)
        editMode.editModeSystemAnchorDirty = true
    end))
    Put(frame, "ClearAllPoints", Logs("ClearAllPoints", function(self)
        self:ClearAllPointsBase()
        self:ClearFrameSnap()
    end))
    -- The frame it snaps to (its snappedToFrame key) is kept beside it, so
    -- every write of it is listed, not just the first.
    Put(frame, "SetSnappedToFrame", function(self, rel)
        if type(rel) == "table" and rawget(rel, "AddSnappedFrame") then
            rel:AddSnappedFrame(self)
            writes[#writes + 1] = label .. ".snappedToFrame"
            S[self].snappedTo = rel
        end
    end)
    Put(frame, "ClearFrameSnap", function(self)
        local to = S[self].snappedTo
        if to then
            to:RemoveSnappedFrame(self)
            writes[#writes + 1] = label .. ".snappedToFrame"
            S[self].snappedTo = nil
        end
    end)
    Put(frame, "AddSnappedFrame", function(self, other) self.snappedFrames[other] = true end)
    Put(frame, "RemoveSnappedFrame", function(self, other) self.snappedFrames[other] = nil end)
    local list, keys = Logged(label .. ".snappedFrames")
    Put(frame, "snappedFrames", list)
    return keys
end
local function Button(name, parent, w, h, label, atlas)
    local b = G("Button", name, parent, w, h, label)
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do
        local t = G("Texture", nil, b, nil, nil, label .. "." .. state, state == "Highlight" and "HIGHLIGHT" or "ARTWORK")
        S[t].atlas = atlas and (atlas .. "-" .. state:lower())
        S[b][state] = t
    end
    return b
end

-- Forever's minimap cluster (Blizzard_Minimap Mainline/Minimap.xml and the
-- Camelot day/night frame), as the game builds it before EraUI.
-- opts.size: Edit Mode's minimap size (100); opts.hybrid: the hybrid map
-- is loaded; opts.shape: another addon's GetMinimapShape, there first.
local function Build(opts)
    opts = opts or {}
    writes, calls, made, gameList = {}, {}, {}, {}
    UIParent = G("Frame", "UIParent", nil, W, H)
    S[UIParent].level, S[UIParent].strata = 0, "MEDIUM"
    local cluster = G("Frame", "MinimapCluster", UIParent, 256, 256)
    S[cluster].strata = "LOW"
    -- An Edit Mode frame, at the screen's top right or (opts.snap) snapped
    -- in Edit Mode under another Edit Mode frame, the game's own record of
    -- that kept on both.
    editMode = Logged("EditModeManagerFrame", true)
    local neighbour
    if opts.snap then
        neighbour = G("Frame", nil, UIParent, 200, 40, "EditModeNeighbour")
        neighbour:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
        cluster:SetPoint("TOPRIGHT", neighbour, "BOTTOMRIGHT", 0, -6)
    else
        cluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -20)
    end
    EditModeFrame(cluster)
    if neighbour then
        EditModeFrame(neighbour)[cluster] = true
        S[cluster].snappedTo = neighbour
    end
    Put(cluster, "Layout", function() end)
    Put(cluster, "SetRotateMinimap", function(_, on) rotate = on and true or false end)
    Put(cluster, "GetSettingValue", function() return opts.size or 100 end)
    local border = Put(cluster, "BorderTop", G("Frame", nil, cluster, 175, 16, "BorderTop"))
    border:SetPoint("TOP", cluster, "TOP", 15, -4)
    local zone = Put(cluster, "ZoneTextButton", G("Button", nil, cluster, 135, 12, "ZoneTextButton"))
    zone:SetPoint("LEFT", border, "LEFT", 4, 0)
    local zoneText = G("FontString", "MinimapZoneText", zone, 130, 12)
    zoneText:SetPoint("CENTER", zone, "CENTER", 0, 1)
    local tracking = Put(cluster, "Tracking", G("Frame", nil, cluster, 17, 17, "Tracking"))
    tracking:SetPoint("RIGHT", border, "LEFT", -2, 0)
    Put(tracking, "Background", G("Texture", nil, tracking, 17, 17, "Tracking.Background", "BACKGROUND"))
    local trackButton = Put(tracking, "Button", Button(nil, tracking, 13, 14, "Tracking.Button", "ui-hud-minimap-tracking"))
    trackButton:SetPoint("CENTER", tracking, "CENTER", 0, 0)
    local indicator = Put(cluster, "IndicatorFrame", G("Frame", nil, cluster, 20, 15, "IndicatorFrame"))
    indicator:SetPoint("TOPRIGHT", tracking, "BOTTOMRIGHT", 0, 0)
    Put(indicator, "Layout", function() end)
    local mail = Put(indicator, "MailFrame", G("Frame", nil, indicator, 20, 15, "MailFrame"))
    mail:SetPoint("TOPLEFT", indicator, "TOPLEFT", 0, 0)
    local icon = G("Texture", "MiniMapMailIcon", mail, 20, 15)
    icon:SetPoint("TOPLEFT", mail, "TOPLEFT", 0, 0)
    local crafting = Put(indicator, "CraftingOrderFrame", G("Frame", nil, indicator, 20, 15, "CraftingOrderFrame"))
    crafting:SetPoint("TOPLEFT", indicator, "TOPLEFT", 20, 0)
    local container = Put(cluster, "MinimapContainer", G("Frame", nil, cluster, 215, 226, "MinimapContainer"))
    container:SetPoint("TOP", cluster, "TOP", 10, -30)
    local map = G("Minimap", "Minimap", container, 198, 198)
    Put(container, "Minimap", map)
    map:SetPoint("CENTER", container, "CENTER", 0, 0)
    S[map].mask = GAME_MASK
    local hit = Put(map, "ZoomHitArea", G("Frame", nil, map, 40, 40, "ZoomHitArea"))
    hit:SetPoint("CENTER", map, "CENTER", 77, -77)
    local zin = Put(map, "ZoomIn", Button(nil, map, 17, 17, "ZoomIn", "ui-hud-minimap-zoom-in"))
    zin:SetPoint("CENTER", map, "CENTER", 88, -68)
    local zout = Put(map, "ZoomOut", Button(nil, map, 17, 9, "ZoomOut", "ui-hud-minimap-zoom-out"))
    zout:SetPoint("CENTER", map, "CENTER", 72, -84)
    S[zin].shown, S[zout].shown = false, false
    local backdrop = G("Frame", "MinimapBackdrop", map, 215, 226)
    backdrop:SetPoint("CENTER", map, "CENTER", 0, 0)
    local static = Put(backdrop, "StaticOverlayTexture", G("Texture", nil, backdrop, 0, 0, "StaticOverlayTexture", "OVERLAY"))
    static:SetAllPoints(backdrop)
    S[static].shown = false
    local underlay = G("Texture", "MinimapCompassTextureUnderlay", backdrop, 215, 226, nil, "OVERLAY")
    underlay:SetPoint("CENTER", backdrop, "CENTER", 0, 0)
    local compass = G("Texture", "MinimapCompassTexture", backdrop, 215, 226, nil, "OVERLAY")
    compass:SetPoint("CENTER", map, "CENTER", 0, 0)
    S[compass].atlas = "ui-hud-minimap-frame"
    local landing = Button("ExpansionLandingPageMinimapButton", backdrop, 53, 53, "ExpansionLandingPageMinimapButton")
    landing:SetPoint("TOPLEFT", backdrop, "TOPLEFT", -3, -150)
    Put(landing, "UpdateIcon", function() end)
    local coords = Put(container, "PlayerCoords", G("Frame", nil, container, 90, 10, "PlayerCoords"))
    coords:SetPoint("BOTTOM", map, "BOTTOM", 0, -18)
    local difficulty = Put(cluster, "InstanceDifficulty", G("Frame", nil, cluster, 30, 30, "InstanceDifficulty"))
    difficulty:SetPoint("TOPRIGHT", border, "TOPRIGHT", 0, -15)
    local diel = Put(cluster, "DielFrame", G("Frame", nil, cluster, 40, 40, "DielFrame"))
    S[diel].level = 5
    diel:SetPoint("CENTER", cluster, "CENTER", 63, 72)
    Put(diel, "Background", G("Texture", nil, diel, 30, 30, "DielFrame.Background", "BACKGROUND"))
    G("Texture", nil, diel, 40, 40, "DielFrame.Border", "OVERLAY"):SetAllPoints(diel)
    local calendar = Button("GameTimeFrame", cluster, 40, 40, "GameTimeFrame")
    calendar:SetPoint("TOPRIGHT", cluster, "TOPRIGHT", -10, -40)
    local clock = G("Button", "TimeManagerClockButton", cluster, 60, 28)
    clock:SetPoint("TOP", map, "BOTTOM", 0, 0)
    G("Texture", nil, clock, 60, 28, "TimeManagerClockButton.Art"):SetAllPoints(clock)
    G("FontString", "TimeManagerClockTicker", clock, 40, 12):SetPoint("CENTER", clock, "CENTER", 0, 0)
    local eye = G("Button", "QueueStatusButton", cluster, 45, 45)
    eye:SetPoint("TOPLEFT", cluster, "BOTTOMLEFT", 0, 0)
    local eyeArt = Put(eye, "Eye", G("Frame", nil, eye, 45, 45, "QueueStatusButton.Eye"))
    eyeArt:SetPoint("CENTER", eye, "CENTER", 0, 0)
    Put(eye, "IsInDefaultPosition", function() return true end)
    Put(eye, "UpdatePosition", function() end)
    local compartment = Button("AddonCompartmentFrame", cluster, 20, 20, "AddonCompartmentFrame")
    compartment:SetPoint("TOPRIGHT", cluster, "TOPRIGHT", 0, 0)
    Put(compartment, "UpdateDisplay", function() end)
    local hybrid, hybridMask
    if opts.hybrid then
        hybrid = G("Frame", "HybridMinimap", map, 198, 198)
        hybrid:SetAllPoints(map)
        S[hybrid].strata = "BACKGROUND"
        hybridMask = Put(hybrid, "CircleMask", G("MaskTexture", nil, hybrid, 0, 0, "HybridMinimap.CircleMask", "OVERLAY"))
        S[hybridMask].texture, S[hybridMask].wrap = MASK_ROUND, "CLAMPTOBLACKADDITIVE/CLAMPTOBLACKADDITIVE"
        hybridMask:SetPoint("TOPLEFT", hybrid, "TOPLEFT", 3, -3)
        hybridMask:SetPoint("BOTTOMRIGHT", hybrid, "BOTTOMRIGHT", -3, 3)
    else
        HybridMinimap = nil
    end
    -- A minimap button library: each refresh places its button on the edge
    -- (5 out from the map) at 225 degrees, round or square as the shape it
    -- reads says, and notes the shape it read.
    local lib = { shapes = {}, objects = {} }
    local libButton = New("Button", "LibDBIcon10_Test", map, false)
    S[libButton].w, S[libButton].h = 31, 31
    libButton:SetPoint("CENTER", map, "CENTER", -53, -53)
    lib.objects.Test = libButton
    function lib:GetButtonList() return { "Test" } end
    function lib:GetMinimapButton(name) return self.objects[name] end
    function lib.RegisterCallback() end
    function lib:Refresh(name)
        local shape = type(GetMinimapShape) == "function" and GetMinimapShape() or "ROUND"
        self.shapes[#self.shapes + 1] = shape
        local half = Minimap:GetWidth() / 2 + 5
        local x, y = math.cos(math.rad(225)), math.sin(math.rad(225))
        if shape == "SQUARE" then local far = math.max(math.abs(x), math.abs(y)); x, y = x / far, y / far end
        local button = self.objects[name]
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x * half, y * half)
    end
    LibStub = setmetatable({ GetLibrary = function(_, name) if name == "LibDBIcon-1.0" then return lib end end },
        { __call = function(_, name) if name == "LibDBIcon-1.0" then return lib end end })
    GetMinimapShape = opts.shape
    game = { cluster = cluster, map = map, backdrop = backdrop, zone = zone, zoneText = zoneText, tracking = tracking,
        mail = mail, calendar = calendar, clock = clock, eye = eye, zin = zin, zout = zout, compass = compass, diel = diel,
        coords = coords, hybrid = hybrid, hybridMask = hybridMask, lib = lib, libButton = libButton, border = border,
        neighbour = neighbour }
end

-- What the game's pieces look like now, every one, as text: place, size,
-- scale, art, mask and shown state, parent and level (the shape too).
local function Snapshot()
    local out = {}
    for _, obj in ipairs(gameList) do
        local s = S[obj]
        do
            local points = {}
            for i, p in ipairs(s.points) do
                local rel = p[2] and S[p[2]]
                points[i] = table.concat({ p[1], tostring(rel and (rel.label or "EraUI")), p[3], N(p[4]), N(p[5]) }, " ")
            end
            out[#out + 1] = table.concat({ tostring(s.label), table.concat(points, ";"), N(s.w) .. "x" .. N(s.h), N(s.scale),
                N(s.alpha), tostring(s.shown), tostring(s.parent and (S[s.parent].label or "EraUI")), tostring(s.level),
                tostring(s.texture), tostring(s.wrap), tostring(s.atlas), tostring(s.colour), tostring(s.tint), tostring(s.mask),
                tostring(s.layer) }, "|")
        end
    end
    table.sort(out)
    out[#out + 1] = "shape: " .. (type(GetMinimapShape) == "function" and GetMinimapShape() or "none")
    return table.concat(out, "\n")
end
-- The game's pieces that changed between two snapshots.
local function Diff(a, b)
    local seen, out = {}, {}
    for line in a:gmatch("[^\n]+") do seen[line] = true end
    for line in b:gmatch("[^\n]+") do if not seen[line] then out[#out + 1] = line end end
    return table.concat(out, " // ")
end

-- EraUI ---------------------------------------------------------------------------------
local settings, E, ns, modules, booked
-- A fresh game and EraUI on it, logged in: EraUI's modules first (the
-- minimap button and the drawer), then the Classic pass.
local function Session(extra, opts)
    settings = { enabled = true, darkModeDarkness = 58, minimap = true }
    for k, v in pairs(extra or {}) do settings[k] = v end
    combat, rotate, timers, cursor = false, false, {}, { 0, 0 }
    Build(opts)
    UISpecialFrames = {}
    ns, modules, booked = {}, {}, 0
    E = { Classic = ns, modules = {} }
    function E:GetSetting(key) return settings[key] end
    function E:GetSavedSetting(key) return settings[key] end
    function E:SetSetting(key, value) settings[key] = value end
    function E:SaveSettings() end
    function E:RegisterModule(name, mod) self.modules[name] = mod end
    ns.RegisterModule = function(key, mod) modules[key] = mod end
    ns.SafeCall = function(fn, ...) local ok, err = pcall(fn, ...); assert(ok, err); return ok end
    ns.QueueApply = function() end
    -- EraUI's pass (Classic/Core.lua): never in a fight, booked for after it.
    ns.ApplyAll = function()
        if combat then booked = booked + 1; return end
        if settings.minimap ~= false then modules.minimap.apply() else modules.minimap.restore() end
    end
    assert(loadfile("Classic/Textures.lua"))("EraUI", E)
    assert(loadfile("Core/Appearance.lua"))("EraUI", E)
    assert(loadfile("Classic/Skin.lua"))("EraUI", E)
    assert(loadfile("Classic/Minimap.lua"))("EraUI", E)
    assert(loadfile("Modules/MinimapTools.lua"))("EraUI", E)
    E.modules.MinimapTools:Initialize()
    ns.ApplyAll()
    RunTimers()
end
local function Tools() return E.modules.MinimapTools end
-- EraUI's square frame: its strips, textures of EraUI's drawn on the
-- cluster itself (the edge BACKGROUND, the line BORDER), each pinned to the
-- map by two corners. Frame() is its top strip (nil until made), standing
-- for the whole; FrameShown() says whether every strip shows ("true"),
-- none does ("false") or some do ("mixed").
local function Pieces()
    local shell, line = {}, {}
    for _, o in ipairs(made) do
        local s = S[o]
        if s.kind == "Texture" and s.parent == game.cluster and #s.points == 2 and s.points[1][2] == game.map then
            if s.layer == "BACKGROUND" then shell[#shell + 1] = o elseif s.layer == "BORDER" then line[#line + 1] = o end
        end
    end
    return shell, line
end
local function Frame() return (Pieces())[1] end
local function FrameShown()
    local shell, line = Pieces()
    local seen = {}
    for _, list in ipairs({ shell, line }) do
        for _, piece in ipairs(list) do seen[S[piece].shown == true] = true end
    end
    if seen[true] and seen[false] then return "mixed" end
    return tostring(seen[true] == true)
end
-- EraUI's stone ring art: the bar on the cluster and the ring on the backdrop.
local function RingArt()
    local found = {}
    for _, o in ipairs(made) do
        local s = S[o]
        if s.kind == "Texture" and s.texture == "Interface\\Minimap\\UI-Minimap-Border" then found[#found + 1] = o end
    end
    return found
end
local function RingShown()
    local out = {}
    for _, t in ipairs(RingArt()) do out[#out + 1] = tostring(S[t].shown) end
    return table.concat(out, ",")
end
local function Grey(d)
    local v = 1 - d / 100
    return v, math.min(1, v * 44 / 42), math.min(1, v * 48 / 42)
end
-- The rotation watch: EraUI's frame listening for the game's settings.
local function RotationWatch()
    for _, o in ipairs(made) do if S[o].events.CVAR_UPDATE then return o end end
end

-- Off (the default) ----------------------------------------------------------------------
Session()
local round = Snapshot()
local roundWrites = table.concat(writes, ",")
equal(type(ns.RefreshSquareMinimap) .. type(ns.RefreshSquareMinimapLine) .. type(ns.SquareMinimapOn), "functionfunctionfunction",
    "the switch, the line's tone and the state for the minimap buttons")
equal(settings.squareMinimap, nil, "the mock starts with the switch never touched (Core/Init.lua's default is off)")
equal(S[game.map].mask, MASK_ROUND, "off: the round mask, as before")
equal(Frame(), nil, "off: no square frame made")
equal(GetMinimapShape, nil, "off: the shape left unclaimed")
equal(RingShown(), "true,true", "off: the stone bar and ring shown")
equal(Spot(game.zin) .. " " .. Spot(game.zout), "63,-49 41,-67", "off: the zoom buttons on the ring, as before")
equal(Spot(game.eye), "-66.5,-44.5", "off: the eye where it was")
equal(Spot(game.zoneText), "-9,80", "off: the zone's name on the stone bar")
equal(N(select(1, Box(Tools().button))) ~= nil and Spot(Tools().button), "52.33,-52.33", "off: EraUI's button on the ring")
equal(game.lib.shapes[#game.lib.shapes], "ROUND", "off: the library reads round")
equal(ns.SquareMinimapOn(), false, "off: not worn")
-- Switched on with Minimap off nothing changes.
equal(ns.RefreshSquareMinimap(), true, "a refresh with the switch off: nothing to do")
equal(Snapshot(), round, "and nothing changed")

-- On at log in -----------------------------------------------------------------------------
Session({ squareMinimap = true })
local frame = Frame()
equal(frame ~= nil, true, "on at log in: EraUI's frame round the map")
equal(ns.SquareMinimapOn(), true, "worn")
equal(S[game.map].mask, MASK_SQUARE, "the map's mask is the plain square")
equal(FrameShown(), "true", "shown")
-- The cluster's own art, so the zone's name and every button (the cluster's
-- children, however the game layers them) draw over it. A frame of its own
-- on the map was lifted over the zone's name in game.
local function Within(obj, ancestor)
    local p = S[obj].parent
    while p do
        if p == ancestor then return true end
        p = S[p].parent
    end
    return false
end
for _, piece in ipairs({ game.zone, game.zin, game.zout, game.tracking, game.cluster.IndicatorFrame, game.calendar, game.clock,
    game.map, Tools().button }) do
    equal(Within(piece, game.cluster), true, tostring(S[piece].label or "EraUI's button") .. " draws over the frame (the cluster's child)")
end
local shell, line = Pieces()
equal(#shell .. " " .. #line, "4 4", "four edge strips and four line strips")
equal(BoxText(shell[1]) .. " | " .. BoxText(shell[2]) .. " | " .. BoxText(shell[3]) .. " | " .. BoxText(shell[4]),
    "-74,70,74,92 | -74,-74,74,-70 | -74,-70,-70,70 | 70,-70,74,70", "the edge: 4 out all round, the top strip 22 deep")
local tiled = 0
for i = 1, 4 do
    local l, b, r, t = Box(shell[i])
    tiled = tiled + Area(l, b, r, t)
    equal(Overlap(shell[i], game.map), 0, "edge strip " .. i .. " clear of the map")
    for j = i + 1, 4 do equal(Overlap(shell[i], shell[j]), 0, "edge strips " .. i .. " and " .. j .. " don't overlap") end
end
equal(N(tiled), N(148 * 166 - 140 * 140), "the edge tiles the band round the map with no gap")
equal(BoxText(line[1]) .. " | " .. BoxText(line[2]) .. " | " .. BoxText(line[3]) .. " | " .. BoxText(line[4]),
    "-72,71,72,72 | -72,-72,72,-71 | -72,-71,-71,71 | 71,-71,72,71", "the line: one unit wide, 1 to 2 out from the map, square corners")
local drawn = 0
for i = 1, 4 do
    local l, b, r, t = Box(line[i])
    drawn = drawn + Area(l, b, r, t)
    equal(Overlap(line[i], game.map), 0, "line strip " .. i .. " clear of the map")
    for j = i + 1, 4 do equal(Overlap(line[i], line[j]), 0, "line strips " .. i .. " and " .. j .. " don't overlap") end
end
equal(N(drawn), N(144 * 144 - 142 * 142), "the line closes round the map")
for i = 1, 4 do
    equal(S[shell[i]].colour, C(.05, .05, .06, 1), "edge strip " .. i .. " near black")
    equal(S[line[i]].colour, C(.55, .46, .27, 1), "line strip " .. i .. " muted bronze in the Classic look")
    equal(S[shell[i]].layer .. " " .. S[line[i]].layer, "BACKGROUND BORDER", "the line over the edge")
end
-- The round art aside; the zone's name on the top strip.
equal(RingShown(), "false,false", "the stone bar and ring put aside")
equal(S[game.compass].shown, false, "no compass ring")
equal(Spot(game.zoneText) .. " " .. Spot(game.zone), "0,82 0,82", "the zone's name centred on the top strip")
do
    local l, b, r, t = Box(game.zoneText)
    local sl, sb, sr, st = Box(shell[1])
    local _, _, _, lt = Box(line[1])
    equal(l >= sl and r <= sr and b >= lt and t <= st, true, "the zone's name inside the strip, above the line")
end
-- The buttons on the square.
equal(Spot(game.zin) .. " " .. Spot(game.zout), "78,-20 78,-44", "the zoom buttons on the right edge, above the corner")
equal(Spot(game.eye), "-78,-40", "the eye on the left edge")
equal(Spot(game.tracking) .. " " .. Spot(game.mail) .. " " .. Spot(game.calendar) .. " " .. Spot(game.clock),
    "-80,11 77.5,16.5 70,48 0,-75", "tracking, mail, the calendar and clock where they were")
equal(Spot(game.diel), "70,48", "day and night with the calendar")
equal(Spot(Tools().button), "74,-74", "EraUI's button on the square's corner (its default, bottom right)")
equal(game.lib.shapes[#game.lib.shapes], "SQUARE", "the library reads SQUARE")
equal(GetMinimapShape(), "SQUARE", "GetMinimapShape says SQUARE")
equal(Spot(game.libButton), "-75,-75", "and puts its button on the square's edge")
-- None of the controls overlap: their art's round edge (r) apart, the clock
-- a box.
local CONTROLS = { { game.tracking, 16 }, { game.mail, 16 }, { game.calendar, 14 }, { game.zin, 11 }, { game.zout, 11 },
    { game.eye, 16 }, { Tools().button, 16 } }
for i = 1, #CONTROLS do
    local a = CONTROLS[i]
    local ax, ay = Spot(a[1]):match("([^,]+),(.+)")
    ax, ay = tonumber(ax), tonumber(ay)
    for j = i + 1, #CONTROLS do
        local b = CONTROLS[j]
        local bx, by = Spot(b[1]):match("([^,]+),(.+)")
        local apart = math.sqrt((ax - tonumber(bx)) ^ 2 + (ay - tonumber(by)) ^ 2)
        equal(apart >= a[2] + b[2], true, tostring(S[a[1]].label or "EraUI's button") .. " and " .. tostring(S[b[1]].label or "EraUI's button") .. " apart")
    end
    local cl, cb, cr, ct = Box(game.clock)
    local nx, ny = math.max(cl, math.min(ax, cr)), math.max(cb, math.min(ay, ct))
    equal(math.sqrt((ax - nx) ^ 2 + (ay - ny) ^ 2) >= a[2], true, tostring(S[a[1]].label or "EraUI's button") .. " clear of the clock")
end
-- The coordinates under the frame.
equal(select(4, Box(game.coords)) <= -70 and true, true, "the game's coordinates under the map")
-- The game's Layout passes keep it (the hooks run Layout again).
local before = #made
game.cluster:Layout()
game.cluster.IndicatorFrame:Layout()
equal(#made, before, "Layout again makes nothing new")
equal(S[game.map].mask .. " " .. Spot(game.zin) .. " " .. FrameShown(), MASK_SQUARE .. " 78,-20 true", "and keeps the square")

-- The Darkness slider and the looks ---------------------------------------------------------
Session({ squareMinimap = true, darkMode = true })
frame = Frame()
shell, line = Pieces(frame)
equal(S[line[1]].colour, C(Grey(58)) , "Dark Mode: the line in the Darkness grey (58)")
equal(S[shell[1]].colour, C(.05, .05, .06, 1), "the edge near black in Dark Mode too")
for _, d in ipairs({ 40, 72, 90 }) do
    settings.darkModeDarkness = d
    ns.RefreshDarkness()
    for i = 1, 4 do equal(S[line[i]].colour, C(Grey(d)), "Darkness " .. d .. ": line strip " .. i .. " follows at once") end
end
-- In a fight too, touching none of the game's pieces.
combat, logging, calls = true, true, {}
settings.darkModeDarkness = 66
ns.RefreshDarkness()
logging = false
equal(S[line[2]].colour, C(Grey(66)), "in a fight: the line still follows")
local mutated = {}
for _, call in ipairs(calls) do
    if not call:find(":Get") and not call:find(":Is") and not call:find(":SetVertexColor$") then mutated[#mutated + 1] = call end
end
equal(table.concat(mutated, ","), "", "in a fight the slider only re-tints the game's art Dark Mode tints (as before), nothing moved or shown")
combat = false
equal(Spot(game.zin) .. " " .. Spot(game.eye) .. " " .. Spot(Tools().button), "78,-20 -78,-40 74,-74", "Dark Mode: the same places")
-- The zoom buttons' own light glyphs come along.
local glyphs = 0
for _, o in ipairs(made) do if S[o].parent == game.zin and S[o].kind == "Texture" and S[o].layer == "OVERLAY" then glyphs = glyphs + 1 end end
equal(glyphs, 2, "Dark Mode: the + glyph on the zoom-in button moves with it")
-- Classic look: the slider doesn't touch it.
Session({ squareMinimap = true })
frame = Frame(); shell, line = Pieces(frame)
settings.darkModeDarkness = 90
ns.RefreshDarkness(); ns.RefreshSquareMinimapLine()
equal(S[line[1]].colour, C(.55, .46, .27, 1), "Classic look: the line stays bronze whatever the slider")

-- Live on and off ----------------------------------------------------------------------------
Session()
local roundAgain = Snapshot()
equal(roundAgain, round, "a fresh round session matches")
logging, calls = true, {}
local roundLayout = {}
game.cluster:Layout()
logging = false
for _, call in ipairs(calls) do roundLayout[call] = true end
settings.squareMinimap = true
logging, calls = true, {}
equal(ns.RefreshSquareMinimap(), true, "switched on: done at once")
logging = false
local onCalls = calls
frame = Frame()
equal(frame ~= nil and FrameShown() == "true" and S[game.map].mask == MASK_SQUARE, true, "live: square at once")
equal(Spot(Tools().button) .. " " .. Spot(game.libButton) .. " " .. GetMinimapShape(), "74,-74 -75,-75 SQUARE",
    "live: EraUI's button and the library's on the square")
local onSnapshot = Snapshot()
Session({ squareMinimap = true })
equal(onSnapshot, Snapshot(), "live on: the same as on at log in")
local onWrites = table.concat(writes, ",")
equal(onWrites, roundWrites, "no key written on the game's frames beyond the round look's")
Session()
settings.squareMinimap = true
ns.RefreshSquareMinimap()
settings.squareMinimap = false
logging, calls = true, {}
equal(ns.RefreshSquareMinimap(), true, "switched off: done at once")
logging = false
local offCalls = calls
equal(Snapshot(), round, "off again: every game piece back as the round look has it: " .. Diff(round, Snapshot()))
equal(FrameShown(), "false", "EraUI's frame hidden, every strip")
equal(RingShown(), "true,true", "the stone bar and ring back")
equal(Spot(Tools().button), "52.33,-52.33", "EraUI's button back on the ring")
equal(game.lib.shapes[#game.lib.shapes], "ROUND", "the library reads round again")
equal(table.concat(writes, ","), roundWrites, "still no key written beyond the round look's")
-- Making the frame's strips on the cluster (the first time it's worn) is the
-- kind of change the round look makes too: its stone bar is made there the
-- same way, the first time the look is applied (not on a later Layout).
local firstMade = { ["MinimapCluster:CreateTexture"] = true }
for label, list in pairs({ on = onCalls, off = offCalls }) do
    for _, call in ipairs(list) do
        if not call:find(":Get") and not call:find(":Is") and not call:find(":Has") and not (label == "on" and firstMade[call]) then
            equal(roundLayout[call], true, "switched " .. label .. ": " .. call .. " is a change the round look makes too")
        end
    end
end
-- On and off again: the same frame, nothing new.
local count = #made
settings.squareMinimap = true; ns.RefreshSquareMinimap()
settings.squareMinimap = false; ns.RefreshSquareMinimap()
settings.squareMinimap = true; ns.RefreshSquareMinimap()
equal(#made, count, "on and off again makes nothing new")
equal(FrameShown() == "true" and S[game.map].mask == MASK_SQUARE, true, "and is square again")

-- EraUI's button and the drawer's go round the square ---------------------------------------
Session({ squareMinimap = true, cleanMinimap = true, cleanMinimapStyle = "drawer" })
local drawer = Tools().drawer.button
equal(drawer ~= nil and drawer:IsShown(), true, "the drawer's button")
equal(Spot(drawer), "-74,-74", "the drawer's button on the square's corner (its default, bottom left)")
for _, case in ipairs({ { 1, 0, "74,0" }, { 0, 1, "0,74" }, { -1, 0, "-74,0" }, { 0, -2, "0,-74" }, { 1, .5, "74,37" },
    { -.25, 1, "-18.5,74" }, { 3, -3, "74,-74" } }) do
    settings.minimapDrawerButtonPosition = { x = case[1], y = case[2] }
    Tools():PlaceDrawerButton()
    equal(Spot(drawer), case[3], "the drawer's button saved at " .. case[1] .. "," .. case[2] .. ": on the square's edge")
    settings.minimapButtonPosition = { x = case[1], y = case[2] }
    Tools().position = nil
    Tools():Position()
end
-- (EraUI's own button is in the drawer here; it keeps its slot.)
Session({ squareMinimap = true })
for _, case in ipairs({ { 1, 0, "74,0" }, { -1, 1, "-74,74" }, { .2, -1, "14.8,-74" } }) do
    settings.minimapButtonPosition = { x = case[1], y = case[2] }
    Tools():Position()
    equal(Spot(Tools().button), case[3], "EraUI's button saved at " .. case[1] .. "," .. case[2] .. ": on the square's edge")
end
-- Dragged: it follows the cursor round the square.
local ml, mb, mr, mt = Rect(game.map)
cursor = { (ml + mr) / 2 + 300, (mb + mt) / 2 + 100 }
Tools().dragging = true
Tools():Drag()
equal(Spot(Tools().button), "74,24.67", "dragged to the right: on the square's right edge")
Tools().dragging = false
-- Live off: the drawer's button back on the ring.
Session({ squareMinimap = true, cleanMinimap = true, cleanMinimapStyle = "drawer" })
drawer = Tools().drawer.button
settings.squareMinimap = false; ns.RefreshSquareMinimap()
equal(Spot(drawer), "-52.33,-52.33", "switched off: the drawer's button back on the ring")
settings.squareMinimap = true; ns.RefreshSquareMinimap()
equal(Spot(drawer), "-74,-74", "and on: back on the square")
-- Clean Minimap's hover: a corner of the square counts as the map.
Session({ squareMinimap = true, cleanMinimap = true })
ml, mb, mr, mt = Rect(game.map)
cursor = { ml - 400, mb - 400 }
Tools():Refresh()
equal(Tools().button:GetAlpha(), 0, "Clean Minimap: EraUI's button hidden while you're away")
cursor = { mr - 3, mt - 3 }
Tools():Refresh()
equal(Tools().button:GetAlpha(), 1, "and shown with the cursor in the square's corner")

-- Edit Mode's size ----------------------------------------------------------------------------
Session({ squareMinimap = true }, { size = 125 })
equal(N(Eff(game.map)), "1.25", "a bigger minimap (Edit Mode's size)")
frame = Frame(); shell, line = Pieces(frame)
equal(BoxText(shell[1]) .. " | " .. BoxText(line[4]), "-74,70,74,92 | 71,-71,72,71", "the frame scales with it")
equal(Spot(game.zin) .. " " .. Spot(game.eye) .. " " .. Spot(Tools().button) .. " " .. Spot(game.zoneText),
    "78,-20 -78,-40 74,-74 0,82", "every place the same, in the map's units")
-- Edit Mode's records written on the game's frames (the frame the cluster
-- snaps to, that frame's list, every anchor marked changed).
local function Records()
    local out = {}
    for _, w in ipairs(writes) do
        if w:find("snappedToFrame", 1, true) or w:find("snappedFrames", 1, true) or w:find("EditModeManagerFrame", 1, true) then
            out[#out + 1] = w
        end
    end
    return table.concat(out, ",")
end
-- Where the cluster's own anchor (the corner Edit Mode placed) sits on the
-- screen.
local function Anchor()
    local p = S[game.cluster].points[1]
    local l, b, r, t = Rect(game.cluster)
    local f = FRAC[p[1]]
    return N(l + f[1] * (r - l)) .. "," .. N(b + f[2] * (t - b))
end
equal(Records(), "", "Edit Mode's 125: the cluster resized with no Edit Mode record written (its plain SetScaleBase)")
equal(Anchor(), "1900,1060", "Edit Mode's 125: the cluster's corner where Edit Mode put it")

-- Square Size ----------------------------------------------------------------------------------
-- The slider under Square Minimap (squareMinimapScale, percent, 75 to 150,
-- 100 by default): the whole square on top of Edit Mode's size, through the
-- cluster's scale (which the round look already sets), only while the
-- square is worn.
-- Every place, in the map's units: the controls, EraUI's button, the
-- library's, the zone's name and the frame's strips.
local function Places()
    local shell, line = Pieces()
    local out = {}
    for _, piece in ipairs({ game.zin, game.zout, game.eye, game.tracking, game.mail, game.calendar, game.diel, game.clock, game.zoneText,
        Tools().button, game.libButton }) do
        out[#out + 1] = Spot(piece)
    end
    for i = 1, 4 do out[#out + 1] = BoxText(shell[i]); out[#out + 1] = BoxText(line[i]) end
    return table.concat(out, " ")
end
Session({ squareMinimap = true })
local squarePlaces, squareAt100 = Places(), Snapshot()
equal(N(S[game.cluster].scale) .. " " .. N(Eff(game.map)), "1 1", "never moved (the default): the square at Edit Mode's size alone")
Session({ squareMinimap = true, squareMinimapScale = 100 })
equal(Snapshot(), squareAt100, "100% is today's square exactly: " .. Diff(squareAt100, Snapshot()))
for _, case in ipairs({ { 75, 100, "0.75" }, { 150, 100, "1.5" }, { 120, 125, "1.5" }, { 75, 125, "0.94" }, { 150, 125, "1.88" } }) do
    Session({ squareMinimap = true, squareMinimapScale = case[1] }, { size = case[2] })
    equal(N(S[game.cluster].scale) .. " " .. N(Eff(game.map)), case[3] .. " " .. case[3],
        "Square Size " .. case[1] .. "% with Edit Mode's " .. case[2] .. ": the cluster at " .. case[3])
    equal(N(S[game.cluster.MinimapContainer].scale), "1", "the game's container stays at 1")
    equal(Places(), squarePlaces, "Square Size " .. case[1] .. "% with Edit Mode's " .. case[2] .. ": every place the same, in the map's units")
    equal(FrameShown() .. " " .. S[game.map].mask .. " " .. GetMinimapShape(), "true " .. MASK_SQUARE .. " SQUARE", "and square as ever")
    equal(Records(), "", "Square Size " .. case[1] .. "% with Edit Mode's " .. case[2] .. ": no Edit Mode record written")
    equal(Anchor(), "1900,1060", "Square Size " .. case[1] .. "% with Edit Mode's " .. case[2] .. ": the cluster's corner where Edit Mode put it")
end
-- A saved value it can't read: 100%; one beyond its ends: the nearest.
for _, case in ipairs({ { "big", "1" }, { 0 / 0, "1" }, { math.huge, "1" }, { -math.huge, "1" }, { 400, "1.5" }, { 10, "0.75" },
    { "130", "1.3" }, { false, "1" } }) do
    Session({ squareMinimap = true, squareMinimapScale = case[1] })
    equal(N(S[game.cluster].scale), case[2], "saved " .. tostring(case[1]) .. ": the cluster at " .. case[2])
end
-- Off (or Minimap off): the slider changes nothing; the round look's scale
-- exactly as before.
Session({ squareMinimapScale = 150 })
equal(Snapshot(), round, "square off at 150%: the round look exactly: " .. Diff(round, Snapshot()))
Session({}, { size = 125 })
local round125 = Snapshot()
Session({ squareMinimapScale = 75 }, { size = 125 })
equal(Snapshot(), round125, "square off with Edit Mode's 125 at 75%: Edit Mode's size alone")
equal(N(S[game.cluster].scale), "1.25", "the cluster at Edit Mode's size")
equal(Records(), "", "the round look at Edit Mode's 125: no Edit Mode record written")
Session({ squareMinimap = true, minimap = false })
local ownMap = Snapshot()
Session({ squareMinimap = true, minimap = false, squareMinimapScale = 150 })
equal(Snapshot(), ownMap, "Minimap off: the game's own minimap, its scale untouched")
settings.squareMinimapScale = 75
equal(ns.RefreshSquareMinimap(), true, "Minimap off: a new size, nothing to do")
equal(Snapshot(), ownMap, "and nothing changed")
-- Live: a move applies at once, out of a fight, only the cluster's scale
-- changing (the round look sets it too, at log in and with Edit Mode's
-- size), no key written, no button moved in the map's units.
Session({ squareMinimap = true })
local liveWrites = table.concat(writes, ",")
settings.squareMinimapScale = 150
logging, calls = true, {}
equal(ns.RefreshSquareMinimap(), true, "a new size: done at once")
logging = false
equal(N(S[game.cluster].scale) .. " " .. Places(), "1.5 " .. squarePlaces, "live: the square at 150%, every place the same in the map's units")
local resized = {}
for _, call in ipairs(calls) do
    if not call:find(":Get") and not call:find(":Is") and not call:find(":Has") then
        resized[call] = true
        equal(roundLayout[call] or call == "MinimapCluster:SetScaleBase" or call == "MinimapCluster:SetPointBase", true,
            "resized: " .. call .. " is a change the round look makes too")
    end
end
equal(resized["MinimapCluster:SetScaleBase"] and resized["MinimapCluster:SetPointBase"], true,
    "the cluster's scale set through Edit Mode's plain SetScaleBase, its anchor put back through SetPointBase")
equal(tostring(resized["MinimapCluster:SetScale"]) .. " " .. tostring(resized["MinimapCluster:SetPoint"]) .. " "
    .. tostring(resized["MinimapCluster:ClearAllPoints"]), "nil nil nil", "never through Edit Mode's own SetScale, SetPoint or ClearAllPoints")
equal(table.concat(writes, ","), liveWrites, "no key written on the game's frames")
equal(Records(), "", "no Edit Mode record written")
equal(Anchor(), "1900,1060", "the cluster's corner kept where Edit Mode put it, as Edit Mode's own SetScale keeps it")
local beforeMade = #made
settings.squareMinimapScale = 100
ns.RefreshSquareMinimap()
equal(#made, beforeMade, "resizing makes nothing new")
equal(Snapshot(), squareAt100, "back to 100%: today's square exactly: " .. Diff(squareAt100, Snapshot()))
settings.squareMinimapScale = 100
logging, calls = true, {}
equal(ns.RefreshSquareMinimap(), true, "the same size again: nothing to do")
logging = false
local quietCalls = {}
for _, call in ipairs(calls) do if not call:find(":Get") and not call:find(":Is") then quietCalls[#quietCalls + 1] = call end end
equal(table.concat(quietCalls, ","), "", "and nothing touched")
-- The game's own Layout passes keep the size.
settings.squareMinimapScale = 125; ns.RefreshSquareMinimap()
game.cluster:Layout()
equal(N(S[game.cluster].scale) .. " " .. Places(), "1.25 " .. squarePlaces, "the game's Layout keeps Square Size")
-- Square off with a size: Edit Mode's size alone, the round look exactly.
settings.squareMinimap = false
equal(ns.RefreshSquareMinimap(), true, "switched off at 125%: done at once")
equal(Snapshot(), round, "off at 125%: the round look exactly: " .. Diff(round, Snapshot()))
settings.squareMinimapScale = 150
equal(ns.RefreshSquareMinimap(), true, "a new size with the square off: nothing to do")
equal(Snapshot(), round, "still the round look exactly")
settings.squareMinimap = true
ns.RefreshSquareMinimap()
equal(N(S[game.cluster].scale) .. " " .. Places(), "1.5 " .. squarePlaces, "on again: at the size saved meanwhile")
-- In a fight: nothing changes, the pass after it is booked.
Session({ squareMinimap = true })
local calm = Snapshot()
combat = true
settings.squareMinimapScale = 150
logging, calls = true, {}
equal(ns.RefreshSquareMinimap(), false, "a new size in a fight: waits")
logging = false
equal(Snapshot(), calm, "nothing of the game's changed in the fight")
local fightCalls = {}
for _, call in ipairs(calls) do if not call:find(":Get") and not call:find(":Is") then fightCalls[#fightCalls + 1] = call end end
equal(table.concat(fightCalls, ","), "", "nothing touched in the fight")
equal(booked, 1, "EraUI's pass booked for after the fight")
game.cluster:Layout()
equal(N(S[game.cluster].scale), "1", "the game's own passes in the fight keep the old size")
settings.squareMinimapScale = 75
equal(ns.RefreshSquareMinimap(), false, "another move in the same fight: waits too")
equal(booked .. " " .. N(S[game.cluster].scale), "2 1", "booked again (one pass all the same), still the old size")
combat = false
ns.ApplyAll()
equal(N(S[game.cluster].scale) .. " " .. Places(), "0.75 " .. squarePlaces, "after the fight: the size last chosen, every place the same")
equal(Records() .. " " .. Anchor(), " 1900,1060", "after the fight: no Edit Mode record written, the corner where it was")
-- A Layout pass of the game's in a fight that would resize the cluster (its
-- scale changed under it): the cluster's scale and anchors untouched, the
-- pass after it booked.
Session({ squareMinimap = true, squareMinimapScale = 150 })
combat = true
S[game.cluster].scale = 1
logging, calls = true, {}
game.cluster:Layout()
logging = false
local moved = {}
local MOVES = { SetScale = true, SetScaleBase = true, SetPoint = true, SetPointBase = true, ClearAllPoints = true, ClearAllPointsBase = true }
for _, call in ipairs(calls) do
    local method = call:match("^MinimapCluster:(%a+)$")
    if method and MOVES[method] then moved[#moved + 1] = call end
end
equal(table.concat(moved, ","), "", "a Layout pass in a fight never rescales or moves the cluster")
equal(booked .. " " .. N(S[game.cluster].scale), "1 1", "the pass after the fight booked, the scale left as it is")
combat = false
ns.ApplyAll()
equal(N(S[game.cluster].scale) .. " " .. Places() .. " " .. Records(), "1.5 " .. squarePlaces .. " ", "after the fight: 150% again, no record written")
-- In a fight with the square off: nothing to change, nothing booked.
Session()
combat = true
settings.squareMinimapScale = 150
equal(ns.RefreshSquareMinimap(), true, "a new size in a fight with the square off: nothing to wait for")
equal(booked, 0, "nothing booked")
combat = false
-- Minimap's restore with the square worn at 150%: Edit Mode's size alone again.
for _, editSize in ipairs({ 100, 125 }) do
    Session({ squareMinimap = true, squareMinimapScale = 150 }, { size = editSize })
    modules.minimap.restore()
    equal(N(S[game.cluster].scale), N(editSize / 100), "Minimap's restore at 150% with Edit Mode's " .. editSize .. ": Edit Mode's size alone")
    equal(Records() .. " " .. Anchor(), " 1900,1060", "Minimap's restore with Edit Mode's " .. editSize .. ": no Edit Mode record written, the corner kept")
end
-- Snapped in Edit Mode under another Edit Mode frame: resized at log in,
-- live and on restore with the corner kept where Edit Mode snapped it, the
-- game's own snap records as it left them and none written.
Session({ squareMinimap = true, squareMinimapScale = 120 }, { snap = true, size = 125 })
equal(N(S[game.cluster].scale) .. " " .. Places(), "1.5 " .. squarePlaces, "snapped: Edit Mode's 125 with Square Size 120 is 1.5, every place the same")
equal(Anchor(), "1900,1014", "snapped: the cluster's corner where Edit Mode snapped it")
settings.squareMinimapScale = 75
ns.RefreshSquareMinimap()
equal(N(S[game.cluster].scale) .. " " .. Anchor(), "0.94 1900,1014", "snapped: live to 75%, the corner kept")
modules.minimap.restore()
equal(N(S[game.cluster].scale) .. " " .. Anchor(), "1.25 1900,1014", "snapped: restore to Edit Mode's size alone, the corner kept")
equal(Records(), "", "snapped: no Edit Mode record written")
do
    local p = S[game.cluster].points
    equal(#p .. " " .. tostring(p[1][2] == game.neighbour) .. " " .. tostring(S[game.cluster].snappedTo == game.neighbour) .. " "
        .. tostring(game.neighbour.snappedFrames[game.cluster]), "1 true true true",
        "snapped: still anchored to the frame it snaps to, the game's own records as it left them")
end

-- Another addon's GetMinimapShape ------------------------------------------------------------
local theirs = function() return "ROUND" end
Session({ squareMinimap = true }, { shape = theirs })
equal(GetMinimapShape, theirs, "on with another addon's shape there first: never replaced")
equal(game.lib.shapes[#game.lib.shapes], "ROUND", "the library reads that addon's answer")
settings.squareMinimap = false; ns.RefreshSquareMinimap()
equal(GetMinimapShape, theirs, "off: theirs left as it is")
Session({ squareMinimap = true })
local later = function() return "SQUARE" end
GetMinimapShape = later
settings.squareMinimap = false; ns.RefreshSquareMinimap()
equal(GetMinimapShape, later, "another addon's taken over while on: off leaves theirs")
settings.squareMinimap = true; ns.RefreshSquareMinimap()
equal(GetMinimapShape, later, "and on again doesn't replace it")

-- The hybrid map's own mask -------------------------------------------------------------------
Session({ squareMinimap = true }, { hybrid = true })
equal(S[game.hybridMask].texture .. " " .. S[game.hybridMask].wrap, MASK_SQUARE .. " CLAMPTOBLACKADDITIVE/CLAMPTOBLACKADDITIVE",
    "the hybrid map's mask square too")
settings.squareMinimap = false; ns.RefreshSquareMinimap()
equal(S[game.hybridMask].texture .. " " .. S[game.hybridMask].wrap, MASK_ROUND .. " CLAMPTOBLACKADDITIVE/CLAMPTOBLACKADDITIVE",
    "off: its own round file back")
Session({}, { hybrid = true })
local hybridRound = Snapshot()
settings.squareMinimap = true; ns.RefreshSquareMinimap()
settings.squareMinimap = false; ns.RefreshSquareMinimap()
equal(Snapshot(), hybridRound, "on and off with the hybrid map: back exactly")
-- Loaded after the square went on (the game loads it where it's used): the
-- next pass makes it square.
Session({ squareMinimap = true })
local hybrid = G("Frame", "HybridMinimap", game.map, 198, 198)
hybrid:SetAllPoints(game.map)
local lateMask = Put(hybrid, "CircleMask", G("MaskTexture", nil, hybrid, 0, 0, "HybridMinimap.CircleMask"))
S[lateMask].texture = MASK_ROUND
ns.ApplyAll()
equal(S[lateMask].texture, MASK_SQUARE, "the hybrid map loaded later: square on the next pass")
HybridMinimap = nil

-- A fight ---------------------------------------------------------------------------------------
Session()
local quiet = Snapshot()
combat = true
settings.squareMinimap = true
logging, calls = true, {}
equal(ns.RefreshSquareMinimap(), false, "switched on in a fight: waits")
logging = false
equal(Snapshot(), quiet, "nothing of the game's changed in the fight")
equal(Frame(), nil, "no frame made in the fight")
equal(GetMinimapShape, nil, "the shape unclaimed in the fight")
equal(booked, 1, "EraUI's pass booked for after the fight")
-- The game's own Layout passes in the fight keep the round look.
game.cluster:Layout()
equal(S[game.map].mask .. " " .. Spot(game.zin), MASK_ROUND .. " 63,-49", "the game's passes in the fight keep it round")
combat = false
ns.ApplyAll()
equal(S[game.map].mask .. " " .. tostring(Frame() ~= nil) .. " " .. GetMinimapShape(), MASK_SQUARE .. " true SQUARE", "after the fight: square")
equal(Spot(Tools().button), "74,-74", "after the fight: EraUI's button on the square too (the map's size didn't change)")
combat = true
settings.squareMinimap = false
equal(ns.RefreshSquareMinimap(), false, "switched off in a fight: waits")
equal(S[game.map].mask .. " " .. FrameShown(), MASK_SQUARE .. " true", "still square in the fight")
equal(booked, 2, "the pass booked again")
combat = false
ns.ApplyAll()
equal(Snapshot(), round, "after the fight: round again exactly: " .. Diff(round, Snapshot()))
equal(Spot(Tools().button), "52.33,-52.33", "and EraUI's button back on the ring")

-- Minimap off ------------------------------------------------------------------------------------
Session({ squareMinimap = true, minimap = false })
equal(Frame(), nil, "Minimap off: no frame")
equal(S[game.map].mask .. " " .. tostring(GetMinimapShape), GAME_MASK .. " nil", "the game's own mask, the shape unclaimed")
local gameOwn = Snapshot()
equal(ns.RefreshSquareMinimap(), true, "a refresh changes nothing")
equal(Frame(), nil, "still no frame")
equal(Snapshot(), gameOwn, "the game's own minimap left exactly as it was: " .. Diff(gameOwn, Snapshot()))
-- In a fight with nothing to change: no pass booked, no message.
combat = true
equal(ns.RefreshSquareMinimap(), true, "a refresh in a fight with nothing to change: done, not waiting")
equal(booked, 0, "no pass booked for after the fight")
combat = false
equal(Snapshot(), gameOwn, "and still the game's own minimap")
-- Taken off with it worn (EraUI's module restore): round mask, shape given
-- back, and the hybrid map's own round file back too.
Session({ squareMinimap = true }, { hybrid = true })
equal(S[game.hybridMask].texture, MASK_SQUARE, "worn with the hybrid map: its mask square")
modules.minimap.restore()
equal(S[game.map].mask .. " " .. tostring(GetMinimapShape) .. " " .. FrameShown(), MASK_ROUND .. " nil false",
    "Minimap's restore with the square worn: the round mask, the shape given back, the frame hidden")
equal(S[game.hybridMask].texture .. " " .. S[game.hybridMask].wrap, MASK_ROUND .. " CLAMPTOBLACKADDITIVE/CLAMPTOBLACKADDITIVE",
    "Minimap's restore: the hybrid map's own round file back")
equal(ns.SquareMinimapOn(), false, "not worn")
equal(Spot(Tools().button), "52.33,-52.33", "EraUI's button back on the ring")

-- Rotation -----------------------------------------------------------------------------------------
Session({ squareMinimap = true })
game.cluster:SetRotateMinimap(true)
equal(S[game.compass].shown, false, "rotating: still no compass ring on the square")
-- The game's Options switch the rotation without the hook: its own round
-- mask goes on, and EraUI puts the square's back after.
rotate = false
S[game.map].mask = GAME_MASK
local watch = RotationWatch()
equal(watch ~= nil, true, "EraUI's own frame watches the game's settings")
S[watch].scripts.OnEvent(watch, "CVAR_UPDATE", "rotateMinimap", "0")
equal(S[game.map].mask, GAME_MASK, "not at once (the game's own change comes first)")
RunTimers()
equal(S[game.map].mask, MASK_SQUARE, "the square's mask back after")
S[watch].scripts.OnEvent(watch, "CVAR_UPDATE", "someOtherSetting", "1")
equal(#timers, 0, "another setting: nothing")
settings.squareMinimap = false; ns.RefreshSquareMinimap()
S[game.map].mask = GAME_MASK
S[watch].scripts.OnEvent(watch, "CVAR_UPDATE", "rotateMinimap", "1")
equal(#timers, 0, "with the square off nothing is booked")
RunTimers()
equal(S[game.map].mask, GAME_MASK, "with the square off it leaves the mask alone")

print("Square Minimap checks passed: " .. checks .. " assertions.")
