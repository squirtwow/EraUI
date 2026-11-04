-- A mock of WoW Forever for the social area's tests (Tools/TestSocial.lua and
-- its siblings). Not a test itself. The object model (frames, textures,
-- font strings, anchors and a small layout solver, scripts, hooks, events,
-- sealed game objects, secret values) is the quest mock's
-- (Tools/QuestMockGame.lua); on it this file models what Look/Social*.lua,
-- Who*.lua, Guild*.lua and Finder*.lua touch:
--   * the social window (FriendsFrame) with its pieces, its game tabs (1, 3
--     and 4 as on Forever), its pages, header and ignore list; the game's
--     panel manager (ShowUIPanel/HideUIPanel, refused for an addon in a
--     fight) and its tab functions;
--   * /who (C_FriendList), the guild roster and its permissions, the guild
--     micro button, ToggleGuildFrame and the Communities window with its
--     member rows, member box and message editor;
--   * the group finder (LFGParentFrame, Group Browser, Create Listing, its
--     own Who list and tabs);
--   * EraUI's side: the engine's registry and pass, the window chrome's tab
--     skin and fitter, the secure pad, the micro buttons, Dark Mode.
-- GameTooltip and MouseIsOver don't exist (reading either fails), and every
-- key binding call fails.
-- Usage: local Mock = dofile("Tools/SocialMockGame.lua"); local game = Mock.New(); game.Load()
local Mock = {}
unpack = unpack or table.unpack

-- A value the game keeps hidden: any comparison, sum, text or index fails.
local function Refuse(what) return function() error("a secret " .. what, 2) end end
local SECRET = setmetatable({}, {
    __tostring = Refuse("turned to text"), __concat = Refuse("joined to text"), __eq = Refuse("compared"),
    __lt = Refuse("compared"), __le = Refuse("compared"), __add = Refuse("in a sum"), __sub = Refuse("in a sum"),
    __mul = Refuse("in a sum"), __div = Refuse("in a sum"), __unm = Refuse("in a sum"), __index = Refuse("indexed"),
})
Mock.SECRET = SECRET

local REGIONS = { Texture = true, FontString = true }
local FACES = { "Normal", "Pushed", "Disabled", "Highlight", "Checked" }
local SPOT = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }

local function Plain(text) return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
Mock.Plain = Plain

function Mock.New(options)
    options = options or {}
    local game = { now = 100, timers = {}, combat = false, sounds = {}, errors = {}, messages = {}, popups = {},
        darkened = {}, pads = {}, follows = {}, missing = {}, microRefreshes = 0, passes = 0, saves = 0,
        quickBind = false, cvars = {}, cvarWrites = {}, rectUpdates = 0, hookCounts = {}, panels = {}, blocked = {},
        tabLook = {}, sent = {}, invites = {}, friendsAdded = {}, ignored = {}, guildCalls = {}, loads = {},
        skinnedTabs = {}, chromeFits = {}, cursor = { 500, 500 }, settings = { enabled = true, darkMode = false } }
    local env = setmetatable({}, { __index = function(_, key)
        if key == "GameTooltip" or key == "MouseIsOver" then error("EraUI read " .. key, 2) end
        return _G[key]
    end })
    env._G = env
    game.env = env
    for _, name in ipairs({ "SetBinding", "SetBindingClick", "SetOverrideBinding", "SetOverrideBindingClick",
        "SetOverrideBindingSpell", "SetOverrideBindingMacro", "SetOverrideBindingItem", "ClearOverrideBindings",
        "SaveBindings", "LoadBindings" }) do
        env[name] = function() error(name .. " called: EraUI must never change a key binding", 2) end
    end
    env.geterrorhandler = function() return function(problem) game.errors[#game.errors + 1] = tostring(problem) end end
    env.issecretvalue = function(value) return value == SECRET end

    ---------------------------------------------------------------------------
    -- Objects
    ---------------------------------------------------------------------------
    local st = setmetatable({}, { __mode = "k" })
    local sealed = setmetatable({}, { __mode = "k" })
    local building = true
    local made = {}
    game.st, game.made = st, made
    local Proto = {}
    local Meta = {
        __index = Proto,
        __newindex = function(t, key, value)
            if sealed[t] then error("a key (" .. tostring(key) .. ") written on the game's " .. tostring(st[t].name or st[t].kind), 2) end
            rawset(t, key, value)
        end,
    }

    local function New(kind, name, parent, layer)
        local obj = setmetatable({}, Meta)
        local up = parent and st[parent]
        st[obj] = { kind = kind, name = name, parent = parent, layer = layer, sublevel = 0, points = {}, order = {},
            shown = true, alpha = 1, scale = 1, scripts = {}, hooks = {}, events = {}, children = {}, regions = {},
            game = building, enabled = true, colour = { 1, 1, 1, 1 }, coords = { 0, 1, 0, 1 }, faces = {},
            level = up and (up.level + 1) or 1, strata = "MEDIUM", value = 0, min = 0, max = 0, scroll = 0 }
        if up then
            local list = REGIONS[kind] and up.regions or up.children
            list[#list + 1] = obj
        end
        made[#made + 1] = obj
        if name then rawset(env, name, obj) end
        return obj
    end
    game.New = New
    function game.State(obj) return st[obj] end
    function game.IsGame(obj) return st[obj] ~= nil and st[obj].game end
    -- The game's own code writing a key on its object.
    function game.Own(obj, key, value) rawset(obj, key, value) end

    local function S(self) return st[self] end
    local function Run(obj, script, ...)
        local s = st[obj]
        if s.scripts[script] then s.scripts[script](obj, ...) end
        for _, hook in ipairs(s.hooks[script] or {}) do hook(obj, ...) end
    end
    game.Run = Run

    local function Visible(obj)
        while obj do
            if not st[obj].shown then return false end
            obj = st[obj].parent
        end
        return true
    end
    game.Visible = Visible

    function Proto:GetName() return S(self).name end
    function Proto:GetParent() return S(self).parent end
    function Proto:GetObjectType() return S(self).kind end
    function Proto:IsObjectType(kind)
        local own = S(self).kind
        return own == kind or (kind == "Button" and own == "CheckButton") or (kind == "Frame" and not REGIONS[own])
            or (kind == "Region")
    end
    function Proto:IsProtected() return S(self).protected == true, false end
    function Proto:IsForbidden() return false end
    local function LoseMouse(obj)
        local s = st[obj]
        if s.hovered then
            s.hovered = false
            Run(obj, "OnLeave")
        end
        for _, child in ipairs(s.children) do LoseMouse(child) end
    end
    -- As the game: a frame's own OnShow or OnHide, then every shown
    -- descendant's, as they become visible or not with it.
    local function Cascade(obj, script)
        for _, child in ipairs(st[obj].children) do
            if st[child].shown and not REGIONS[st[child].kind] then
                Run(child, script)
                Cascade(child, script)
            end
        end
    end
    function Proto:SetShown(on)
        local s = S(self)
        on = on and true or false
        if s.shown == on then return end
        local parentVisible = s.parent == nil or Visible(s.parent)
        s.shown = on
        if parentVisible and not REGIONS[s.kind] then
            if not on then LoseMouse(self) end
            Run(self, on and "OnShow" or "OnHide")
            Cascade(self, on and "OnShow" or "OnHide")
        end
    end
    function Proto:Show() self:SetShown(true) end
    function Proto:Hide() self:SetShown(false) end
    function Proto:IsShown() return S(self).shown end
    function Proto:IsVisible() return Visible(self) end
    function Proto:SetAlpha(alpha) S(self).alpha = alpha end
    function Proto:GetAlpha() return S(self).alpha end

    -- Anchors, sizes and scales
    function Proto:SetPoint(point, relative, relativePoint, x, y)
        local s = S(self)
        if type(relative) == "number" then relative, relativePoint, x, y = nil, point, relative, relativePoint end
        if type(relative) == "string" then relative = env[relative] end
        if relative == nil then relative = s.parent end
        if not s.points[point] then s.order[#s.order + 1] = point end
        s.points[point] = { point, relative, relativePoint or point, x or 0, y or 0 }
    end
    function Proto:ClearAllPoints()
        local s = S(self)
        s.points, s.order = {}, {}
    end
    function Proto:SetAllPoints(relative)
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", relative or S(self).parent, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", relative or S(self).parent, "BOTTOMRIGHT", 0, 0)
    end
    function Proto:GetNumPoints() return #S(self).order end
    function Proto:GetPoint(index)
        local s = S(self)
        local point = type(index) == "string" and index or s.order[index or 1]
        local anchor = point and s.points[point]
        if anchor then return unpack(anchor) end
    end
    local function Sized(self, wide, tall)
        local s = S(self)
        local changed = (wide ~= nil and wide ~= s.width) or (tall ~= nil and tall ~= s.height)
        if wide ~= nil then s.width = wide end
        if tall ~= nil then s.height = tall end
        if changed and not REGIONS[s.kind] then Run(self, "OnSizeChanged", s.width, s.height) end
    end
    function Proto:SetSize(w, h) Sized(self, w, h) end
    function Proto:SetWidth(w) Sized(self, w, nil) end
    function Proto:SetHeight(h) Sized(self, nil, h) end
    function Proto:SetScale(scale) S(self).scale = scale end
    function Proto:GetScale() return S(self).scale end
    function Proto:GetEffectiveScale()
        local s = S(self)
        local own = REGIONS[s.kind] and 1 or s.scale
        return own * (s.parent and s.parent:GetEffectiveScale() or 1)
    end

    -- The text's natural size: 6 across a letter, 12 a line.
    local function TextSize(s)
        -- The game lays out hidden text too (without showing it to addons).
        local across = rawequal(s.text, SECRET) and 60 or #Plain(s.text) * 6
        local lines = 1
        if (s.width or 0) > 0 and across > s.width and s.wrap ~= false then
            lines = math.ceil(across / s.width)
            if (s.maxLines or 0) > 0 then lines = math.min(lines, s.maxLines) end
        end
        return across, lines * 12
    end
    local function OwnSize(obj)
        local s = st[obj]
        if s.kind == "FontString" then
            local across, tall = TextSize(s)
            local wide = (s.width or 0) > 0 and s.width or across
            return wide, (s.height or 0) > 0 and s.height or tall
        end
        return s.width, s.height
    end

    -- Screen rect (left, bottom, right, top), or nil when it can't be laid out.
    local solving = {}
    local function Rect(obj)
        local s = st[obj]
        if s.fixed then return s.fixed[1], s.fixed[2], s.fixed[3], s.fixed[4] end
        if solving[obj] then return nil end
        solving[obj] = true
        local scale = obj:GetEffectiveScale()
        local across, down = {}, {}
        local order, points = s.order, s.points
        if #order == 0 and s.scrollOf then
            -- A scroll child hangs from its scroll frame's top-left, moved up by the scroll.
            order, points = { "TOPLEFT" }, { TOPLEFT = { "TOPLEFT", s.scrollOf, "TOPLEFT", 0, st[s.scrollOf].scroll or 0 } }
        end
        for _, name in ipairs(order) do
            local anchor = points[name]
            local l, b, r, t
            if anchor[2] then l, b, r, t = Rect(anchor[2]) end
            if l then
                local to, from = SPOT[anchor[3]], SPOT[anchor[1]]
                across[#across + 1] = { from[1], l + (r - l) * to[1] + anchor[4] * scale }
                down[#down + 1] = { from[2], b + (t - b) * to[2] + anchor[5] * scale }
            end
        end
        solving[obj] = nil
        local wide, tall = OwnSize(obj)
        local function Axis(marks, size)
            if #marks == 0 then return nil end
            local first, other = marks[1], nil
            for i = 2, #marks do
                if marks[i][1] ~= first[1] then other = marks[i] break end
            end
            if other then
                local extent = (other[2] - first[2]) / (other[1] - first[1])
                local start = first[2] - first[1] * extent
                return start, start + extent
            end
            if not size then return nil end
            local start = first[2] - first[1] * size * scale
            return start, start + size * scale
        end
        local l, r = Axis(across, wide)
        local b, t = Axis(down, tall)
        if not (l and b) then return nil end
        return l, b, r, t
    end
    game.Rect = Rect
    local function Edge(obj, i)
        local edges = { Rect(obj) }
        if edges[i] == nil then return nil end
        return edges[i] / obj:GetEffectiveScale()
    end
    function Proto:GetLeft() return Edge(self, 1) end
    function Proto:GetBottom() return Edge(self, 2) end
    function Proto:GetRight() return Edge(self, 3) end
    function Proto:GetTop() return Edge(self, 4) end
    function Proto:GetCenter()
        local l, b, r, t = Rect(self)
        if not l then return nil end
        local f = self:GetEffectiveScale()
        return (l + r) / 2 / f, (b + t) / 2 / f
    end
    function Proto:GetWidth()
        local l, _, r = Rect(self)
        if l and #S(self).order > 0 then return (r - l) / self:GetEffectiveScale() end
        return (OwnSize(self)) or 0
    end
    function Proto:GetHeight()
        local _, b, _, t = Rect(self)
        if b and #S(self).order > 0 then return (t - b) / self:GetEffectiveScale() end
        local _, tall = OwnSize(self)
        return tall or 0
    end
    function Proto:GetSize() return self:GetWidth(), self:GetHeight() end

    -- Layers and mouse
    function Proto:SetFrameStrata(strata) S(self).strata = strata end
    function Proto:GetFrameStrata() return S(self).strata end
    function Proto:SetFrameLevel(level) S(self).level = level end
    function Proto:GetFrameLevel() return S(self).level end
    function Proto:SetToplevel(on) S(self).toplevel = on end
    function Proto:SetClipsChildren(on) S(self).clips = on end
    function Proto:Raise() end
    function Proto:EnableMouse(on) S(self).mouse = on and true or false end
    function Proto:IsMouseEnabled() return S(self).mouse == true end
    function Proto:EnableMouseWheel(on) S(self).wheel = on and true or false end
    function Proto:IsMouseOver() return S(self).hovered == true end
    function Proto:SetMovable(on) S(self).movable = on end
    function Proto:SetClampedToScreen(on) S(self).clamped = on end
    function Proto:RegisterForDrag(button) S(self).drag = button end
    function Proto:StartMoving() S(self).moving = true end
    function Proto:StopMovingOrSizing() S(self).moving = false end
    function Proto:SetScript(script, fn) S(self).scripts[script] = fn end
    function Proto:GetScript(script) return S(self).scripts[script] end
    function Proto:HookScript(script, fn)
        local s = S(self)
        s.hooks[script] = s.hooks[script] or {}
        table.insert(s.hooks[script], fn)
    end
    function Proto:RegisterEvent(event)
        if options.unknownEvents and options.unknownEvents[event] then error("unknown event " .. event) end
        S(self).events[event] = true
    end
    function Proto:RegisterUnitEvent(event, unit)
        self:RegisterEvent(event)
        S(self).eventUnits = S(self).eventUnits or {}
        S(self).eventUnits[event] = unit
    end
    function Proto:UnregisterEvent(event) S(self).events[event] = nil end
    function Proto:GetChildren() return unpack(S(self).children) end
    function Proto:GetRegions() return unpack(S(self).regions) end
    function Proto:CreateTexture(name, layer, _, sublevel)
        local texture = New("Texture", name, self, layer)
        st[texture].sublevel = sublevel or 0
        return texture
    end
    function Proto:CreateFontString(name, layer, font)
        local text = New("FontString", name, self, layer)
        st[text].font = font
        return text
    end
    function Proto:CreateMaskTexture() return New("MaskTexture", nil, self, "ARTWORK") end

    -- Textures
    function Proto:SetTexture(file, wrapAcross, wrapDown)
        local s = S(self)
        if file ~= nil and options.refuse and options.refuse[file] then return false end
        s.file, s.atlas = file, nil
        s.wrap = wrapAcross and { wrapAcross, wrapDown } or nil
        return true
    end
    function Proto:GetTexture() return S(self).file end
    function Proto:SetAtlas(atlas, useSize)
        local s = S(self)
        s.atlas, s.file, s.atlasSized = atlas, nil, useSize and true or nil
        return true
    end
    function Proto:GetAtlas() return S(self).atlas end
    function Proto:SetColorTexture(r, g, b, a) S(self).solid = { r, g, b, a } end
    function Proto:SetTexCoord(...) S(self).coords = { ... } end
    function Proto:GetTexCoord() return unpack(S(self).coords) end
    function Proto:SetVertexColor(r, g, b, a) S(self).colour = { r, g, b, a or 1 } end
    function Proto:GetVertexColor() return unpack(S(self).colour) end
    function Proto:SetBlendMode(mode) S(self).blend = mode end
    function Proto:SetHorizTile(on) S(self).htile = on end
    function Proto:SetVertTile(on) S(self).vtile = on end
    function Proto:SetDrawLayer(layer, sublevel) S(self).layer, S(self).sublevel = layer, sublevel or 0 end
    function Proto:GetDrawLayer() return S(self).layer, S(self).sublevel end
    function Proto:SetDesaturated(on) S(self).desaturated = on and true or false end
    function Proto:AddMaskTexture() end

    -- Font strings
    function Proto:SetText(text)
        local s = S(self)
        if s.kind == "FontString" then
            s.text = text
            return
        end
        self:GetFontString():SetText(text)
    end
    function Proto:GetText()
        local s = S(self)
        if s.kind == "FontString" then return s.text end
        return s.label and st[s.label].text
    end
    function Proto:SetTextColor(r, g, b) S(self).textColour = { r, g, b } end
    function Proto:GetTextColor() return unpack(S(self).textColour or { 1, 0.82, 0 }) end
    function Proto:SetFontObject(font) S(self).font, S(self).fontFace = font, nil end
    function Proto:GetFontObject() return S(self).font end
    function Proto:SetFont(face, size, flags) S(self).fontFace = { face, size, flags } end
    function Proto:GetFont()
        local face = S(self).fontFace
        if face then return face[1], face[2], face[3] end
        return "Fonts\\FRIZQT__.TTF", 12, ""
    end
    function Proto:SetShadowColor(...) S(self).shadowColour = { ... } end
    function Proto:SetShadowOffset(x, y) S(self).shadowOffset = { x, y } end
    function Proto:SetJustifyH(side) S(self).justify = side end
    function Proto:SetWordWrap(on) S(self).wrap = on and true or false end
    function Proto:SetMaxLines(count) S(self).maxLines = count end
    function Proto:GetStringWidth() return (TextSize(S(self))) end
    function Proto:GetStringHeight()
        local _, tall = TextSize(S(self))
        return tall
    end

    -- Buttons
    for _, face in ipairs(FACES) do
        Proto["Set" .. face .. "Texture"] = function(self, file)
            -- As the game: an asset is required (nil is refused).
            if file == nil then error("Usage: self:Set" .. face .. "Texture(asset)", 2) end
            local s = S(self)
            local texture = s.faces[face]
            if not texture then
                texture = New("Texture", nil, self, face == "Highlight" and "HIGHLIGHT" or "ARTWORK")
                s.faces[face] = texture
            end
            if type(file) == "string" then texture:SetTexture(file) end
        end
        Proto["Get" .. face .. "Texture"] = function(self) return S(self).faces[face] end
    end
    function Proto:GetFontString()
        local s = S(self)
        if not s.label then s.label = self:CreateFontString(nil, "ARTWORK") end
        return s.label
    end
    function Proto:SetNormalFontObject(font) S(self).normalFont = font end
    function Proto:SetHighlightFontObject(font) S(self).highlightFont = font end
    function Proto:SetDisabledFontObject(font) S(self).disabledFont = font end
    function Proto:Enable() S(self).enabled = true end
    function Proto:Disable() S(self).enabled = false end
    function Proto:SetEnabled(on) S(self).enabled = on and true or false end
    function Proto:IsEnabled() return S(self).enabled end
    function Proto:RegisterForClicks(...) S(self).clicks = { ... } end
    function Proto:LockHighlight() S(self).highlightLocked = true end
    function Proto:UnlockHighlight() S(self).highlightLocked = false end
    function Proto:SetButtonState(state) S(self).state = state end
    function Proto:GetButtonState() return S(self).state or "NORMAL" end
    function Proto:SetChecked(on) S(self).checked = on and true or false end
    function Proto:GetChecked() return S(self).checked == true end
    function Proto:Click(mouse, down)
        local s = S(self)
        if not s.enabled then return end
        if s.kind == "CheckButton" then s.checked = not s.checked end
        Run(self, "OnClick", mouse or "LeftButton", down)
    end

    -- Sliders and scroll frames
    function Proto:SetOrientation(way) S(self).orientation = way end
    function Proto:SetThumbTexture(texture) S(self).thumb = texture end
    function Proto:GetThumbTexture() return S(self).thumb end
    function Proto:SetValueStep(step) S(self).valueStep = step end
    function Proto:SetObeyStepOnDrag(on) S(self).obey = on end
    local function Settle(self, value)
        local s = S(self)
        value = math.max(s.min, math.min(s.max, value))
        if value ~= s.value then
            s.value = value
            Run(self, "OnValueChanged", value, false)
        end
    end
    function Proto:SetMinMaxValues(low, high)
        local s = S(self)
        s.min, s.max = low, high
        Settle(self, s.value)
    end
    function Proto:GetMinMaxValues() return S(self).min, S(self).max end
    function Proto:SetValue(value) Settle(self, value) end
    function Proto:GetValue() return S(self).value end
    function Proto:SetScrollChild(child)
        S(self).scrollChild = child
        st[child].scrollOf = self
    end
    function Proto:GetScrollChild() return S(self).scrollChild end
    function Proto:SetVerticalScroll(value) S(self).scroll = value end
    function Proto:GetVerticalScroll() return S(self).scroll end
    function Proto:GetVerticalScrollRange()
        local child = S(self).scrollChild
        local inside = child and child:GetHeight() or (S(self).contentHeight or 0)
        return math.max(0, inside - self:GetHeight())
    end
    function Proto:UpdateScrollChildRect() game.rectUpdates = game.rectUpdates + 1 end

    -- Backdrops and the red error text
    function Proto:SetBackdrop(backdrop) S(self).backdrop = backdrop end
    function Proto:SetBackdropColor(...) S(self).backdropColour = { ... } end
    function Proto:SetBackdropBorderColor(...) S(self).borderColour = { ... } end
    function Proto:AddMessage(text, r, g, b) game.messages[#game.messages + 1] = { text, r, g, b } end

    env.CreateFrame = function(kind, name, parent, template)
        local frame = New(kind, name, parent)
        st[frame].template = template
        return frame
    end

    -- hooksecurefunc: the game's own function runs, then the hook, with the
    -- same arguments. On an object the wrapper replaces the method field
    -- (the one key a post-hook writes, as in the game).
    env.hooksecurefunc = function(object, method, hook)
        if type(object) == "string" then
            object, method, hook = env, object, method
        end
        local own = object[method]
        assert(type(own) == "function", "hooksecurefunc on a missing " .. tostring(method))
        game.hookCounts[object] = game.hookCounts[object] or {}
        game.hookCounts[object][method] = (game.hookCounts[object][method] or 0) + 1
        rawset(object, method, function(...)
            local results = { own(...) }
            hook(...)
            return unpack(results)
        end)
    end

    -- What the social area needs beyond the quest mock's objects.
    function Proto:SetAttribute(key, value)
        local s = S(self)
        s.attributes = s.attributes or {}
        s.attributes[key] = value
    end
    function Proto:GetAttribute(key) return (S(self).attributes or {})[key] end
    function Proto:SetID(id) S(self).id = id end
    function Proto:GetID() return S(self).id or 0 end
    function Proto:SetFontString(text) S(self).label = text end
    function Proto:SetJustifyV(side) S(self).justifyV = side end
    function Proto:SetAutoFocus(on) S(self).autoFocus = on end
    function Proto:SetMaxLetters(count) S(self).maxLetters = count end
    function Proto:SetTextInsets(...) S(self).textInsets = { ... } end
    function Proto:SetFocus() S(self).focus = true end
    function Proto:ClearFocus() S(self).focus = false end
    function Proto:HasFocus() return S(self).focus == true end
    function Proto:SetCursorPosition(n) S(self).cursor = n end
    function Proto:IsTruncated() return false end
    function Proto:SetHitRectInsets(...) S(self).hitInsets = { ... } end
    function Proto:UnregisterAllEvents() S(self).events = {} end
    function Proto:IsDesaturated() return S(self).desaturated == true end
    function Proto:SetParent(parent)
        local s = S(self)
        local old = s.parent and st[s.parent]
        if old then
            local list = REGIONS[s.kind] and old.regions or old.children
            for i, item in ipairs(list) do
                if item == self then
                    table.remove(list, i)
                    break
                end
            end
        end
        s.parent = parent
        if parent and st[parent] then
            local list = REGIONS[s.kind] and st[parent].regions or st[parent].children
            list[#list + 1] = self
        end
    end
    -- A button face given a file and a blend at once.
    local plainHighlight = Proto.SetHighlightTexture
    function Proto:SetHighlightTexture(file, blend)
        plainHighlight(self, file)
        if blend then S(self).faces.Highlight:SetBlendMode(blend) end
    end

    -- The pieces of a game template, made as the game would.
    local function Pieces(frame, keys, kind)
        for key in keys:gmatch("%S+") do rawset(frame, key, New(kind or "Texture", nil, frame, "BACKGROUND")) end
    end
    local function TabTemplate(tab, text)
        Pieces(tab, "LeftActive MiddleActive RightActive Left Middle Right LeftHighlight MiddleHighlight RightHighlight")
        local label = New("FontString", nil, tab, "ARTWORK")
        rawset(tab, "Text", label)
        st[tab].label = label
        st[label].text = text
        st[tab].width, st[tab].height = 80, 32
    end
    game.TabTemplate = TabTemplate
    env.CreateFrame = function(kind, name, parent, template)
        local frame = New(kind, name, parent)
        st[frame].template = template
        if template == "PanelTabButtonTemplate" then
            TabTemplate(frame, "")
        elseif template == "InputBoxTemplate" then
            Pieces(frame, "Left Middle Right")
        end
        return frame
    end

    -- Building the game's own world now (sealed when EraUI loads, or by
    -- game.Seal()).
    function game.Building(fn)
        local was = building
        building = true
        local results = { fn() }
        building = was
        return unpack(results)
    end

    ---------------------------------------------------------------------------
    -- Words, fonts and colours the game defines
    ---------------------------------------------------------------------------
    for name, words in pairs({ NAME = "Name", ZONE = "Zone", GUILD = "Guild", RACE = "Race", LEVEL_ABBR = "Lvl",
        CLASS = "Class", WHO = "Who", WHO_LIST = "Who List", WHO_NUM_RESULTS = "%d found", ADD_FRIEND = "Add Friend",
        REFRESH = "Refresh", GROUP_INVITE = "Group Invite", WHISPER = "Whisper", INVITE = "Invite", IGNORE = "Ignore",
        CANCEL = "Cancel", FRIENDS = "Friends", CONTACTS_TAB_TITLE = "Contacts", CONTACTS_LIST_TITLE = "Contacts",
        COMMUNITIES = "Communities", SHOW_OFFLINE_MEMBERS = "Show Offline Members", RANK = "Rank", LABEL_NOTE = "Note",
        LASTONLINE = "Last Online", GUILD_ONLINE_LABEL = "Online", LASTONLINE_YEARS = "%d years",
        LASTONLINE_MONTHS = "%d months", LASTONLINE_DAYS = "%d days", LASTONLINE_HOURS = "%d hours",
        LASTONLINE_MINS = "< an hour", GUILD_TOTAL = "%d Guild Members", GUILD_TOTALONLINE = "(%d Online)",
        GUILD_TITLE_TEMPLATE = "%s of %s", GUILD_STATUS = "Guild Status", PLAYER_STATUS = "Player Status",
        ADDMEMBER = "Add Member", GUILDCONTROL = "Guild Control", GUILD_INFORMATION = "Guild Information",
        GUILD_PROMOTE = "Promote", GUILD_DEMOTE = "Demote", REMOVE = "Remove", LEVEL = "Level",
        GUILD_NOTE_EDITLABEL = "Click here to set a Public Note.",
        GUILD_OFFICERNOTE_EDITLABEL = "Click here to set an Officer's Note.", GUILD_OFFICERNOTE_LABEL = "Officer Note:",
        ERR_NOT_IN_COMBAT = "You can't do that while in combat", LFG_LIST_TAB_1 = "Create Listing",
        LFG_LIST_TAB_2 = "Group Browser", LFG_LIST_TAB_3 = "Who", LOOKING_FOR_GROUP = "Group Finder", RAID = "Raid",
        QUICK_JOIN = "Quick Join" }) do
        env[name] = words
    end
    env.FRIEND_TAB_FRIENDS, env.FRIEND_TAB_RAID, env.FRIEND_TAB_QUICK_JOIN = 1, 2, 3
    for _, font in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontHighlight", "GameFontHighlightSmall",
        "GameFontDisable", "ChatFontNormal" }) do
        env[font] = { fontName = font }
    end
    env.RAID_CLASS_COLORS = { HUNTER = { r = 0.67, g = 0.83, b = 0.45 }, DRUID = { r = 1, g = 0.49, b = 0.04 },
        MAGE = { r = 0.25, g = 0.78, b = 0.92 } }
    env.SOUNDKIT = setmetatable({}, { __index = function(_, key) return "sound:" .. key end })
    env.PlaySound = function(kit) game.sounds[#game.sounds + 1] = kit end
    env.InCombatLockdown = function() return game.combat end
    env.GetTime = function() return game.now end
    env.C_Timer = { After = function(seconds, fn) game.timers[#game.timers + 1] = { at = game.now + seconds, fn = fn } end }
    env.GetCursorPosition = function() return game.cursor[1], game.cursor[2] end
    env.GetLocale = function() return game.locale or "enUS" end
    env.KeybindFrames_InQuickKeybindMode = function() return game.quickBind end

    ---------------------------------------------------------------------------
    -- The game's own UI
    ---------------------------------------------------------------------------
    local root = New("Frame", "UIParent")
    st[root].fixed = { 0, 0, 1920, 1080 }
    st[root].width, st[root].height = 1920, 1080
    env.UIErrorsFrame = New("Frame", "UIErrorsFrame", root)

    -- The panel manager: the game's own show and hide; an addon's in a fight
    -- is refused (recorded), as on Forever.
    env.ShowUIPanel = function(frame)
        game.panels[#game.panels + 1] = { "show", frame }
        if game.combat and not game.secure then
            game.blocked[#game.blocked + 1] = "ShowUIPanel " .. tostring(frame:GetName())
            return
        end
        frame:Show()
    end
    env.HideUIPanel = function(frame)
        game.panels[#game.panels + 1] = { "hide", frame }
        if game.combat and not game.secure then
            game.blocked[#game.blocked + 1] = "HideUIPanel " .. tostring(frame:GetName())
            return
        end
        frame:Hide()
    end
    env.UpdateUIPanelPositions = function(frame)
        game.panelUpdates = (game.panelUpdates or 0) + 1
        game.panelUpdated = frame
    end

    -- The game's tab looks (cosmetic): a selected tab is disabled.
    env.PanelTemplates_SelectTab = function(tab)
        game.tabLook[tab] = "selected"
        tab:Disable()
    end
    env.PanelTemplates_DeselectTab = function(tab)
        game.tabLook[tab] = "deselected"
        tab:Enable()
    end
    env.PanelTemplates_TabResize = function(tab, padding)
        tab:SetWidth((tab.Text and tab.Text:GetStringWidth() or 40) + 20 + (padding or 0))
    end
    env.PanelTemplates_GetSelectedTab = function(frame) return frame.selectedTab end

    -- The social window (Blizzard_FriendsFrame, Camelot).
    local friends = New("Frame", "FriendsFrame", root)
    st[friends].shown = false
    st[friends].width, st[friends].height = 360, 424
    friends:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -116)
    st[friends].level = 10
    rawset(friends, "selectedTab", 1)
    local function Child(key, name, kind)
        local child = New(kind or "Frame", name, friends)
        st[child].width, st[child].height = 50, 20
        if key then rawset(friends, key, child) end
        return child
    end
    Child("TitleContainer")
    Child("PortraitContainer")
    Child("NineSlice")
    Child("CloseButton", nil, "Button")
    local inset = Child("Inset", "FriendsFrameInset")
    inset:SetPoint("TOPLEFT", friends, "TOPLEFT", 4, -60)
    inset:SetPoint("BOTTOMRIGHT", friends, "BOTTOMRIGHT", -6, 26)
    local titleText = New("FontString", "FriendsFrameTitleText", friends, "OVERLAY")
    st[titleText].text = "Contacts"
    local icon = New("Texture", "FriendsFrameIcon", friends, "OVERLAY")
    st[icon].file = "Interface\\FriendsFrame\\Battlenet-Portrait"
    local header = Child("FriendsTabHeader", "FriendsTabHeader")
    st[header].mouse = true
    rawset(header, "friendsTabID", 1)
    rawset(header, "recentAlliesTabID", 2)
    rawset(header, "recruitAFriendTabID", 3)
    game.headerTab = 1
    rawset(header, "GetTab", function() return game.headerTab end)
    local battle = New("Frame", "FriendsFrameBattlenetFrame", header)
    st[battle].mouse = true
    local battleButton = New("Button", nil, battle)
    st[battleButton].mouse = true
    local list = Child(nil, "FriendsListFrame")
    st[list].mouse = true
    local ignore = Child("IgnoreListWindow")
    st[ignore].shown = false
    local addonBit = Child(nil, "SomeAddonFriendsButton", "Button")
    st[addonBit].mouse = true
    local insetBit = New("Frame", "SomeAddonInsetBit", inset)
    st[insetBit].mouse = true
    game.friends = { frame = friends, list = list, ignore = ignore, header = header, addonBit = addonBit,
        insetBit = insetBit, battle = battleButton, inset = inset, icon = icon, title = titleText }
    local tabs = {}
    for id, spec in ipairs({ { 1, "Contacts" }, { 3, "Raid" }, { 4, "Quick Join" } }) do
        local tab = New("Button", "FriendsFrameTab" .. spec[1], friends)
        TabTemplate(tab, spec[2])
        st[tab].scripts.OnClick = function()
            rawset(friends, "selectedTab", id)
            game.gameTabClicks = (game.gameTabClicks or 0) + 1
        end
        tabs[#tabs + 1] = tab
    end
    env.FriendsFrameTab1:SetPoint("TOPLEFT", friends, "BOTTOMLEFT", 5, 2)
    env.FriendsFrameTab3:SetPoint("TOPLEFT", env.FriendsFrameTab1, "TOPRIGHT", 3, 0)
    env.FriendsFrameTab4:SetPoint("TOPLEFT", env.FriendsFrameTab3, "TOPRIGHT", 3, 0)
    rawset(friends, "Tabs", tabs)
    game.friendsTabs = tabs
    env.FriendsFrame_ShowSubFrame = function(name)
        local page = env[name]
        if page then page:Show() end
    end
    env.FriendsFrame_Update = function()
        game.friendsUpdates = (game.friendsUpdates or 0) + 1
        env.FriendsFrame_ShowSubFrame("FriendsListFrame")
        icon:SetTexture("Interface\\FriendsFrame\\Battlenet-Portrait")
    end
    st[friends].scripts.OnShow = function() env.FriendsFrame_Update() end
    st[friends].scripts.OnHide = function() ignore:Hide() end
    env.ToggleFriendsFrame = function()
        if friends:IsShown() then env.HideUIPanel(friends) else env.ShowUIPanel(friends) end
    end

    -- /who (C_FriendList) over game.who, a list of info tables.
    game.who = {}
    env.C_FriendList = {
        GetNumWhoResults = function()
            if game.whoCount ~= nil then return game.whoCount, game.whoTotal end
            return #game.who, game.whoTotal or #game.who
        end,
        GetWhoInfo = function(i) return game.who[i] end,
        SetWhoToUi = function(on) game.whoToUi = on end,
        SendWho = function(text) game.sent[#game.sent + 1] = tostring(text) .. "|" .. tostring(game.whoToUi) end,
        AddFriend = function(name) game.friendsAdded[#game.friendsAdded + 1] = name end,
        AddIgnore = function(name) game.ignored[#game.ignored + 1] = name end,
    }
    env.C_PartyInfo = { InviteUnit = function(name) game.invites[#game.invites + 1] = name end }

    -- The guild roster over game.roster: { name, rank, rankIndex, level,
    -- class, zone, note, officerNote, online, status, classFile, guid, ago }.
    game.inGuild, game.showOffline, game.roster = true, false, {}
    game.may = { promote = true, demote = true, remove = true, invite = true, leader = false, publicNote = false,
        officerNote = false, viewOfficer = false, motd = false }
    game.motd = "Raid at eight"
    game.guildName, game.rankName = "Filth", "Unwashed"
    local function Note(...) game.guildCalls[#game.guildCalls + 1] = table.concat({ ... }, " ") end
    env.IsInGuild = function() return game.inGuild end
    env.GetNumGuildMembers = function()
        if game.rosterCount ~= nil then return game.rosterCount, game.rosterOnline end
        local online = 0
        for _, member in ipairs(game.roster) do
            if member.online == true then online = online + 1 end
        end
        return #game.roster, online
    end
    env.GetGuildRosterInfo = function(i)
        local m = game.roster[i]
        if not m then return nil end
        return m.name, m.rank, m.rankIndex, m.level, m.class, m.zone, m.note, m.officerNote, m.online, m.status,
            m.classFile, 0, 0, false, false, 0, m.guid
    end
    env.GetGuildRosterShowOffline = function() return game.showOffline end
    env.SetGuildRosterShowOffline = function(on)
        game.showOffline = on
        Note("showOffline", tostring(on))
    end
    env.GetGuildRosterLastOnline = function(i)
        local m = game.roster[i]
        local ago = m and m.ago or { 0, 0, 0, 0 }
        return ago[1], ago[2], ago[3], ago[4]
    end
    env.Ambiguate = function(name, context)
        assert(not env.issecretvalue(name), "a hidden name must never reach Ambiguate")
        game.ambiguated = context
        return (name:gsub("%-[^%s%-]+$", ""))
    end
    env.SortGuildRoster = function(key) Note("sort", key) end
    env.SetGuildRosterSelection = function(index) Note("select", tostring(index)) end
    env.GetGuildRosterMOTD = function() return game.oldMotd end
    env.GetGuildInfo = function() return game.guildName, game.rankName, 3 end
    env.CanGuildPromote = function() return game.may.promote end
    env.CanGuildDemote = function() return game.may.demote end
    env.CanGuildRemove = function() return game.may.remove end
    env.CanGuildInvite = function() return game.may.invite end
    env.IsGuildLeader = function() return game.may.leader end
    env.CanEditPublicNote = function() return game.may.publicNote end
    env.CanEditMOTD = function() return game.may.motd end
    env.C_GuildInfo = {
        GuildRoster = function() Note("roster") end,
        GetMOTD = function() return game.motd end,
        Promote = function(name) Note("promote", name) end,
        Demote = function(name) Note("demote", name) end,
        Uninvite = function(name) Note("remove", name) end,
        SetLeader = function(name) Note("leader", name) end,
        CanEditOfficerNote = function() return game.may.officerNote end,
        CanViewOfficerNote = function() return game.may.viewOfficer end,
    }
    env.C_Club = { GetGuildClubId = function() return game.inGuild and "club-7" or nil end }
    env.StaticPopup_Show = function(which, a, b, data) game.popups[#game.popups + 1] = { which, a, b, data } end
    env.C_CVar = { SetCVar = function(name, value) game.cvarWrites[#game.cvarWrites + 1] = { name, value } end }
    env.C_AddOns = {
        LoadAddOn = function(name)
            game.loads[#game.loads + 1] = name
            if game.onLoad and game.onLoad[name] then game.onLoad[name]() end
        end,
        IsAddOnLoaded = function(name) return game.loaded ~= nil and game.loaded[name] == true end,
    }

    -- The Communities window: hidden, its member list (rows by GUID), its
    -- member box and its message editor; ToggleGuildFrame opens and closes it.
    local communities = New("Frame", "CommunitiesFrame", root)
    st[communities].shown = false
    st[communities].width, st[communities].height = 800, 500
    communities:SetPoint("TOPLEFT", root, "TOPLEFT", 400, -100)
    communities:SetAttribute("UIPanelLayout-width", 800)
    rawset(communities, "GetSelectedClubId", function() return game.clubShown or "club-7" end)
    local members = New("Frame", nil, communities)
    rawset(communities, "MemberList", members)
    local scroll = New("Frame", nil, members)
    rawset(members, "ScrollBox", scroll)
    game.memberRows = {}
    rawset(scroll, "ForEachFrame", function(_, fn) for _, row in ipairs(game.memberRows) do fn(row) end end)
    local detail = New("Frame", nil, communities)
    st[detail].shown = false
    st[detail].width, st[detail].height = 212, 270
    rawset(communities, "GuildMemberDetailFrame", detail)
    rawset(detail, "GetMemberInfo", function() return game.detailInfo end)
    local border = New("Frame", nil, detail)
    rawset(detail, "Border", border)
    rawset(border, "Bg", New("Texture", nil, border, "BACKGROUND"))
    New("Texture", nil, border, "BORDER")
    for _, key in ipairs({ "NoteBackground", "OfficerNoteBackground" }) do
        local back = New("Frame", nil, detail)
        rawset(back, "Center", New("Texture", nil, back, "BACKGROUND"))
        New("Texture", nil, back, "BORDER")
        rawset(detail, key, back)
    end
    for _, key in ipairs({ "CloseButton", "RemoveButton", "GroupInviteButton" }) do rawset(detail, key, New("Button", nil, detail)) end
    local details = New("Frame", nil, communities)
    rawset(communities, "GuildDetailsFrame", details)
    local info = New("Frame", nil, details)
    rawset(details, "Info", info)
    local editMotd = New("Button", nil, info)
    rawset(info, "EditMOTDButton", editMotd)
    game.communities = { frame = communities, detail = detail, editMotd = editMotd }
    -- A row of the game's member list for a member (made by the game).
    function game.MemberRow(guid)
        return game.Building(function()
            local row = New("Button", nil, scroll)
            rawset(row, "GetMemberInfo", function() return { guid = guid } end)
            st[row].scripts.OnClick = function()
                game.detailInfo = { guid = guid }
                detail:Show()
                game.rowClicks = (game.rowClicks or 0) + 1
            end
            game.memberRows[#game.memberRows + 1] = row
            return row
        end)
    end
    env.ToggleGuildFrame = function()
        game.toggleGuildCalls = (game.toggleGuildCalls or 0) + 1
        if communities:IsShown() then env.HideUIPanel(communities) else env.ShowUIPanel(communities) end
    end
    local micro = New("Button", "GuildMicroButton", root)
    st[micro].width, st[micro].height = 28, 38
    rawset(micro, "tooltipText", "Guild & Communities (J)")
    st[micro].scripts.OnClick = function()
        if not env.KeybindFrames_InQuickKeybindMode() then env.ToggleGuildFrame() end
    end
    rawset(micro, "UpdateMicroButton", function() end)
    local lfd = New("Button", "LFDMicroButton", root)
    st[lfd].scripts.OnClick = function() game.lfdClicks = (game.lfdClicks or 0) + 1 end

    -- The group finder (Blizzard_GroupFinder_VanillaStyle), made by
    -- game.MakeFinder() when a test wants it.
    local function FinderPages(finder)
        local listing = New("Frame", "LFGListingFrame", finder)
        listing:SetAllPoints(finder)
        local divider = New("Frame", nil, listing)
        rawset(listing, "DividerFrame", divider)
        rawset(divider, "Divider", New("Texture", nil, divider, "ARTWORK"))
        for _, key in ipairs({ "BackButton", "PostButton", "OptionsButton" }) do rawset(listing, key, New("Button", nil, listing)) end
        local view = New("Frame", nil, listing)
        view:SetPoint("TOPLEFT", listing, "TOPLEFT", 7, -60)
        st[view].width, st[view].height = 371, 300
        rawset(listing, "ActivityView", view)
        local style = New("Frame", nil, view)
        st[style].width, st[style].height = 210, 25
        rawset(view, "PlayStyleDropdown", style)
        local ranges = New("CheckButton", nil, view)
        ranges:SetPoint("TOPLEFT", view, "TOPLEFT", 216, -10)
        st[ranges].width, st[ranges].height = 20, 20
        rawset(view, "LevelRangesCheckbox", ranges)
        local rangesText = New("FontString", nil, ranges, "ARTWORK")
        rangesText:SetPoint("LEFT", ranges, "LEFT", 0, 0)
        st[rangesText].text = "Show All Level Ranges"
        rawset(ranges, "Text", rangesText)
        local category = New("Frame", nil, listing)
        rawset(listing, "CategoryView", category)
        category:SetAllPoints(listing)
        local bars = {}
        for i = 1, 3 do
            local bar = New("Button", nil, category)
            st[bar].width, st[bar].height = 420, 52
            bar:SetPoint("TOP", category, "TOP", 0, -40 * i)
            rawset(bar, "SelectedTexture", New("Texture", nil, bar, "ARTWORK"))
            rawset(bar, "HighlightTexture", New("Texture", nil, bar, "HIGHLIGHT"))
            rawset(bar, "Label", New("FontString", nil, bar, "ARTWORK"))
            bars[i] = bar
        end
        rawset(category, "CategoryButtons", bars)
        local browse = New("Frame", "LFGBrowseFrame", finder)
        browse:SetAllPoints(finder)
        st[browse].shown = false
        for _, key in ipairs({ "CategoryDropdown", "ActivityDropdown", "RefreshButton", "OptionsButton",
            "SendMessageButton", "GroupInviteButton" }) do
            local piece = New(key:find("Dropdown") and "Frame" or "Button", nil, browse)
            st[piece].width, st[piece].height = 120, 24
            rawset(browse, key, piece)
        end
        rawset(browse, "BackgroundArt", New("Texture", nil, browse, "BACKGROUND"))
        local who = New("Frame", "LFGWhoListFrame", finder)
        who:SetAllPoints(finder)
        st[who].shown = false
        st[who].scripts.OnShow = function() env.C_FriendList.SetWhoToUi(true) end
        st[who].scripts.OnHide = function() env.C_FriendList.SetWhoToUi(false) end
        return listing, browse, who
    end
    function game.MakeFinder()
        return game.Building(function()
            local finder = New("Frame", "LFGParentFrame", root)
            st[finder].shown = false
            st[finder].width, st[finder].height = 458, 535
            finder:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -116)
            finder:SetAttribute("UIPanelLayout-defined", true)
            finder:SetAttribute("UIPanelLayout-width", 458)
            rawset(finder, "selectedTab", 1)
            for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
                local tab = New("Frame", nil, finder)
                st[tab].mouse = true
                rawset(finder, key, tab)
            end
            local listing, browse, who = FinderPages(finder)
            local function Turn(index)
                rawset(finder, "selectedTab", index)
                listing:SetShown(index == 1)
                browse:SetShown(index == 2)
                who:SetShown(index == 3)
                game.finderTurns = (game.finderTurns or 0) + 1
            end
            st[finder].scripts.OnShow = function() Turn(finder.selectedTab) end
            for i = 1, 3 do env["LFGParentFrameTab" .. i .. "_OnClick"] = function() Turn(i) end end
            env.LFGVanilla_ShowFrame = function(tab)
                env.ShowUIPanel(finder)
                Turn(tab or finder.selectedTab)
            end
            return finder
        end)
    end

    ---------------------------------------------------------------------------
    -- EraUI's side: the engine, the chrome's tabs, the pads, Dark Mode
    ---------------------------------------------------------------------------
    local ns = { db = options.db or {}, DB_DEFAULTS = {}, modules = {} }
    function ns.RegisterModule(key, module)
        module.key = key
        ns.modules[#ns.modules + 1] = module
    end
    function ns.MirrorSave() game.saves = game.saves + 1 end
    function ns.MapPad(real, strata, after, target, when)
        game.pads[#game.pads + 1] = { real = real, strata = strata, after = after, target = target, when = when }
    end
    function game.PadFor(real)
        for _, pad in ipairs(game.pads) do
            if pad.real == real then return pad end
        end
        return nil
    end
    function ns.MicroButtonFollows(entry, isShown) game.follows[#game.follows + 1] = { entry = entry, isShown = isShown } end
    function ns.RefreshMicroButtons() game.microRefreshes = game.microRefreshes + 1 end
    function ns.ThemeTexture(texture, key) st[texture].theme = key end
    for _, name in ipairs({ "DarkBackdrop", "DarkCloseButton", "DarkRedButton", "DarkNativeButton", "DarkWindowArt" }) do
        ns[name] = function(object, ...) game.darkened[#game.darkened + 1] = { name, object, ... } end
    end
    function ns.MissingPiece(name) game.missing[#game.missing + 1] = name end
    function ns.Persist() end
    -- The window chrome's tab skin and fitter (spec 12): the fitter lifts a
    -- tab hung straight on its own window by 3 (the social window's lift),
    -- once per anchor, and fits it at its text + 50.
    function ns.SkinBottomTab(tab) game.skinnedTabs[#game.skinnedTabs + 1] = tab end
    local lifted = setmetatable({}, { __mode = "k" })
    function ns.FitBottomTab(tab)
        game.chromeFits[#game.chromeFits + 1] = tab
        local point, relative, relativePoint, x, y = tab:GetPoint(1)
        if relative == tab:GetParent() and lifted[tab] ~= y then
            tab:SetPoint(point, relative, relativePoint, x, y + 3)
            lifted[tab] = y + 3
        end
        tab:SetWidth(math.ceil(tab.Text:GetStringWidth()) + 50)
    end
    game.ns = ns
    local E = { Classic = ns }
    function E:GetSetting(key) return game.settings[key] end
    function E:IsPlayer(name, guid)
        if guid ~= nil and guid == game.myGuid then return true end
        return name ~= nil and name == game.myName
    end
    function E:Print(text) game.printed = text end
    game.E = E
    game.myName, game.myGuid = "Zriel Gustbellow", "Player-4-0001"

    local FILES = { "Look/Base.lua", "Look/SpellKit.lua", "Look/SocialKit.lua", "Look/SocialFrame.lua",
        "Look/WhoPage.lua", "Look/WhoList.lua", "Look/SocialRedirect.lua", "Look/GuildPage.lua", "Look/GuildRoster.lua",
        "Look/GuildMember.lua", "Look/GuildNotes.lua", "Look/GuildModule.lua", "Look/WhoModule.lua",
        "Look/FinderDress.lua", "Look/FinderModule.lua" }
    game.FILES = FILES
    function game.Seal()
        for _, obj in ipairs(made) do
            if st[obj].game then sealed[obj] = true end
        end
    end
    function game.Load()
        building = false
        game.Seal()
        for _, file in ipairs(FILES) do assert(loadfile(file, "t", env))("EraUI", E) end
        for key, value in pairs(ns.DB_DEFAULTS) do
            if ns.db[key] == nil then ns.db[key] = value end
        end
        game.Look = E.Look
        game.S = E.Look.Social
        return game.S
    end
    function game.Module(key)
        for _, module in ipairs(ns.modules) do
            if module.key == key then return module end
        end
        return nil
    end
    -- The engine's pass: each entry's apply, or its restore while its key is off.
    function game.Pass()
        game.passes = game.passes + 1
        for _, module in ipairs(ns.modules) do
            if ns.db[module.key] ~= false then module.apply() else module.restore() end
        end
    end
    function game.Fire(event, ...)
        for _, obj in ipairs(made) do
            if st[obj].events[event] then Run(obj, "OnEvent", event, ...) end
        end
    end
    -- Time passing: visible frames' OnUpdate, then the timers that are due.
    function game.Flush()
        local due = {}
        for i = #game.timers, 1, -1 do
            if game.timers[i].at <= game.now + 1e-9 then due[#due + 1] = table.remove(game.timers, i) end
        end
        for i = #due, 1, -1 do due[i].fn() end
        return #due
    end
    function game.Tick(seconds, step)
        step = step or 0.05
        local done = 0
        repeat
            game.now = game.now + step
            done = done + step
            for _, obj in ipairs(made) do
                if st[obj].scripts.OnUpdate and Visible(obj) then st[obj].scripts.OnUpdate(obj, step) end
            end
            game.Flush()
        until done >= (seconds or step) - 1e-9
    end
    -- One new frame: the clock moves on, the timers of 0 run.
    function game.NextFrame()
        game.now = game.now + 0.02
        game.Flush()
    end
    function game.Enter(obj)
        st[obj].hovered = true
        Run(obj, "OnEnter")
    end
    function game.Leave(obj)
        st[obj].hovered = false
        Run(obj, "OnLeave")
    end
    -- A fight: the game's "regen disabled" comes just before its lockdown.
    function game.Fight(on)
        if on then
            game.Fire("PLAYER_REGEN_DISABLED")
            game.combat = true
        else
            game.combat = false
            game.Fire("PLAYER_REGEN_ENABLED")
        end
    end
    -- The game's own call (a key press, a secure click): its panel manager
    -- isn't refused.
    function game.Secure(fn, ...)
        local was = game.secure
        game.secure = true
        local results = { fn(...) }
        game.secure = was
        return unpack(results)
    end
    -- EraUI's tooltip's lines, or nil while none shows.
    function game.TipText()
        local tip
        for _, obj in ipairs(made) do
            local s = st[obj]
            if s.strata == "TOOLTIP" and s.shown and not s.game then tip = obj end
        end
        if not tip then return nil end
        local lines = {}
        for _, region in ipairs(st[tip].regions) do
            local s = st[region]
            if s.kind == "FontString" and s.shown and s.text then lines[#lines + 1] = Plain(s.text) end
        end
        return table.concat(lines, " | ")
    end
    return game
end

return Mock
