-- A mock of WoW Forever for the windows and settings area's tests
-- (Tools/TestWindowChrome.lua, TestWindowsSettings.lua, TestClassicOptions.lua).
-- Not a test itself. The object model (frames, textures, font strings,
-- anchors and a small layout solver, scripts and post-hooks, events, sealed
-- game objects: any key EraUI writes on one fails) follows the area mocks
-- before it (Tools/QuestMockGame.lua, SocialMockGame.lua). On it this file
-- models what Look/Chrome*.lua, GameMenu.lua, SettingsSkin.lua and the
-- Classic options page touch:
--   * the game's portrait windows (ButtonFrameTemplate on Forever: the
--     nine-slice, portrait, title, background rock and streaks, the X, the
--     inset and its tabs) and the world map's border with its size buttons;
--   * the merchant, quest and gossip NPC windows, trade, item text, inspect,
--     macros and the loot window (Forever's scrolling flat panel, an Edit
--     Mode frame, with its list of rows);
--   * the game menu (a vertical layout frame of pooled red buttons) and the
--     Settings window (its tabs, category list and settings list with the
--     rows it reuses as pages scroll);
--   * EraUI's side: the engine's registry and pass, Dark Mode's hand-overs
--     (recorded), the reset prompt.
-- GameTooltip and MouseIsOver don't exist (reading either fails), and every
-- key binding call fails.
-- Usage: local Mock = dofile("Tools/WindowMockGame.lua"); local game = Mock.New(); game.Load(files)
local Mock = {}
unpack = unpack or table.unpack

-- A value the game keeps hidden: any comparison, sum, text or index fails.
local function Refuse(what) return function() error("a secret " .. what, 2) end end
local SECRET = setmetatable({}, {
    __tostring = Refuse("turned to text"), __concat = Refuse("joined to text"), __eq = Refuse("compared"),
    __lt = Refuse("compared"), __le = Refuse("compared"), __add = Refuse("in a sum"), __sub = Refuse("in a sum"),
    __index = Refuse("indexed"),
})
Mock.SECRET = SECRET

local REGIONS = { Texture = true, FontString = true, MaskTexture = true }
local FACES = { "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked" }
local SPOT = { TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 } }

function Mock.New(options)
    options = options or {}
    local game = { now = 100, timers = {}, combat = false, errors = {}, popups = {}, printed = {}, hookCounts = {},
        themed = setmetatable({}, { __mode = "k" }), dark = setmetatable({}, { __mode = "k" }), darkForced = 0,
        missing = {}, passes = 0, saves = 0, settings = { enabled = true, darkMode = false } }
    local env = setmetatable({}, { __index = function(_, key)
        if key == "GameTooltip" or key == "MouseIsOver" then error("EraUI read " .. key, 2) end
        return _G[key]
    end })
    env._G = env
    game.env = env
    for _, name in ipairs({ "SetBinding", "SetBindingClick", "SetOverrideBinding", "SetOverrideBindingClick",
        "ClearOverrideBindings", "SaveBindings", "LoadBindings" }) do
        env[name] = function() error(name .. " called: EraUI must never change a key binding", 2) end
    end
    env.geterrorhandler = function() return function(problem) game.errors[#game.errors + 1] = tostring(problem) end end
    env.issecretvalue = function(value) return rawequal(value, SECRET) end
    env.InCombatLockdown = function() return game.combat end
    env.GetTime = function() return game.now end
    env.C_Timer = { After = function(delay, fn) game.timers[#game.timers + 1] = { at = game.now + delay, fn = fn } end }
    env.UISpecialFrames = {}
    env.StaticPopupDialogs = {}
    env.SlashCmdList = {}
    env.StaticPopup_Show = function(name, a, b, data) game.popups[#game.popups + 1] = { name, a, b, data } end
    env.PlaySound = function() end
    env.SOUNDKIT = setmetatable({}, { __index = function(_, key) return key end })
    env.PREV, env.NEXT, env.CLOSE, env.CANCEL, env.MAIN_MENU = "Prev", "Next", "Close", "Cancel", "Main Menu"

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
    end
    function Proto:IsProtected() return S(self).protected == true, false end
    function Proto:IsForbidden() return S(self).forbidden == true end
    local function Cascade(obj, script)
        for _, child in ipairs(st[obj].children) do
            if st[child].shown then
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
        -- Regions (textures, font strings) have their own show and hide
        -- scripts on Forever too; only frames pass them on to children.
        if parentVisible then Run(self, on and "OnShow" or "OnHide") end
        if parentVisible and not REGIONS[s.kind] then Cascade(self, on and "OnShow" or "OnHide") end
    end
    function Proto:Show() self:SetShown(true) end
    function Proto:Hide() self:SetShown(false) end
    function Proto:IsShown() return S(self).shown end
    function Proto:IsVisible() return Visible(self) end
    function Proto:SetAlpha(alpha) S(self).alpha = alpha end
    function Proto:GetAlpha() return S(self).alpha end
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
    -- A text's size: 6 across a character, or its font's own (a font object,
    -- or one named by CreateFontString, with st[font].charWidth set).
    local function TextSize(s)
        local font = s.font
        if type(font) == "string" then font = rawget(env, font) end
        local per = font and st[font] and st[font].charWidth or 6
        local across = rawequal(s.text, SECRET) and 60 or #tostring(s.text or "") * per
        return across, 12
    end
    local function OwnSize(obj)
        local s = st[obj]
        if s.kind == "FontString" then
            local across, tall = TextSize(s)
            return (s.width or 0) > 0 and s.width or across, (s.height or 0) > 0 and s.height or tall
        end
        return s.width, s.height
    end
    local solving = {}
    local function Rect(obj)
        local s = st[obj]
        if s.fixed then return s.fixed[1], s.fixed[2], s.fixed[3], s.fixed[4] end
        if solving[obj] then return nil end
        solving[obj] = true
        local scale = obj:GetEffectiveScale()
        local across, down = {}, {}
        for _, name in ipairs(s.order) do
            local anchor = s.points[name]
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
        if l and #S(self).order > 1 then return (r - l) / self:GetEffectiveScale() end
        return (OwnSize(self)) or 0
    end
    function Proto:GetHeight()
        local _, b, _, t = Rect(self)
        if b and #S(self).order > 1 then return (t - b) / self:GetEffectiveScale() end
        local _, tall = OwnSize(self)
        return tall or 0
    end
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
    -- Regions take show and hide scripts unless the session says the client
    -- refuses them (options.regionShowScripts == false); a script an object
    -- can't have is an error, as in the game.
    local function CanHave(s, script)
        if not REGIONS[s.kind] then return true end
        if script == "OnShow" or script == "OnHide" then return options.regionShowScripts ~= false end
        return script == "OnEnter" or script == "OnLeave" or script == "OnMouseDown" or script == "OnMouseUp"
    end
    function Proto:HasScript(script) return CanHave(S(self), script) end
    function Proto:SetScript(script, fn)
        if not CanHave(S(self), script) then error("doesn't have a \"" .. tostring(script) .. "\" script", 2) end
        S(self).scripts[script] = fn
    end
    function Proto:GetScript(script) return S(self).scripts[script] end
    function Proto:HookScript(script, fn)
        local s = S(self)
        if not CanHave(s, script) then error("doesn't have a \"" .. tostring(script) .. "\" script", 2) end
        s.hooks[script] = s.hooks[script] or {}
        table.insert(s.hooks[script], fn)
    end
    function Proto:RegisterEvent(event) S(self).events[event] = true end
    function Proto:RegisterUnitEvent(event) S(self).events[event] = true end
    function Proto:UnregisterEvent(event) S(self).events[event] = nil end
    function Proto:UnregisterAllEvents() S(self).events = {} end
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
    function Proto:SetParent(parent)
        local s = S(self)
        local old = s.parent and st[s.parent]
        if old then
            local list = REGIONS[s.kind] and old.regions or old.children
            for i, item in ipairs(list) do
                if item == self then table.remove(list, i) break end
            end
        end
        s.parent = parent
        if parent and st[parent] then
            local list = REGIONS[s.kind] and st[parent].regions or st[parent].children
            list[#list + 1] = self
        end
    end

    -- Textures
    function Proto:SetTexture(file, wrapAcross, wrapDown)
        local s = S(self)
        if file ~= nil and options.refuse and options.refuse[file] then return false end
        s.file, s.atlas = file, nil
        s.wrap = wrapAcross and { wrapAcross, wrapDown } or nil
        return true
    end
    function Proto:GetTexture() return S(self).file end
    function Proto:GetTextureFilePath() return S(self).file end
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
    function Proto:GetBlendMode() return S(self).blend end
    function Proto:SetHorizTile(on) S(self).htile = on end
    function Proto:SetVertTile(on) S(self).vtile = on end
    function Proto:SetDrawLayer(layer, sublevel) S(self).layer, S(self).sublevel = layer, sublevel or 0 end
    function Proto:GetDrawLayer() return S(self).layer, S(self).sublevel end
    function Proto:SetDesaturated(on) S(self).desaturated = on and true or false end
    function Proto:IsDesaturated() return S(self).desaturated == true end
    function Proto:AddMaskTexture() end

    -- Font strings
    function Proto:SetText(text)
        local s = S(self)
        if s.kind == "FontString" or s.kind == "EditBox" then
            s.text = text
            if s.kind == "EditBox" then Run(self, "OnTextChanged", true) end
            return
        end
        self:GetFontString():SetText(text)
    end
    function Proto:GetText()
        local s = S(self)
        if s.kind == "FontString" or s.kind == "EditBox" then return s.text end
        return s.label and st[s.label].text
    end
    function Proto:SetTextColor(r, g, b) S(self).textColour = { r, g, b } end
    function Proto:GetTextColor() return unpack(S(self).textColour or { 1, 0.82, 0 }) end
    -- As in the game: a font object brings its own colour with it.
    function Proto:SetFontObject(font)
        local s = S(self)
        s.font = font
        local colour = font and S(font).colour
        s.textColour = colour and { colour[1], colour[2], colour[3] } or nil
    end
    function Proto:GetFontObject() return S(self).font end
    function Proto:SetShadowColor(...) S(self).shadowColour = { ... } end
    function Proto:SetShadowOffset(x, y) S(self).shadowOffset = { x, y } end
    function Proto:SetJustifyH(side) S(self).justify = side end
    function Proto:SetJustifyV(side) S(self).justifyV = side end
    function Proto:SetWordWrap(on) S(self).wordWrap = on and true or false end
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
    function Proto:SetFontString(text) S(self).label = text end
    function Proto:SetNormalFontObject(font) S(self).normalFont = font end
    function Proto:SetHighlightFontObject(font) S(self).highlightFont = font end
    function Proto:SetDisabledFontObject(font) S(self).disabledFont = font end
    function Proto:Enable() S(self).enabled = true end
    function Proto:Disable() S(self).enabled = false end
    function Proto:SetEnabled(on) S(self).enabled = on and true or false end
    function Proto:IsEnabled() return S(self).enabled end
    function Proto:SetHitRectInsets(...) S(self).hitInsets = { ... } end
    function Proto:SetChecked(on) S(self).checked = on and true or false end
    function Proto:GetChecked() return S(self).checked == true end
    function Proto:Click(mouse)
        local s = S(self)
        if not s.enabled then return end
        if s.kind == "CheckButton" then s.checked = not s.checked end
        Run(self, "OnClick", mouse or "LeftButton")
    end

    -- Sliders, scroll frames, edit boxes, backdrops
    function Proto:SetOrientation(way) S(self).orientation = way end
    function Proto:SetThumbTexture(texture)
        local s = S(self)
        if type(texture) == "string" then
            s.thumb = s.thumb or New("Texture", nil, self, "ARTWORK")
            s.thumb:SetTexture(texture)
        else
            s.thumb = texture
        end
    end
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
    function Proto:SetScrollChild(child) S(self).scrollChild = child end
    function Proto:GetScrollChild() return S(self).scrollChild end
    function Proto:SetVerticalScroll(value) S(self).scroll = value end
    function Proto:GetVerticalScroll() return S(self).scroll end
    function Proto:UpdateScrollChildRect() S(self).rectUpdates = (S(self).rectUpdates or 0) + 1 end
    function Proto:SetAutoFocus(on) S(self).autoFocus = on end
    function Proto:SetMaxLetters(count) S(self).maxLetters = count end
    function Proto:SetFocus() S(self).focus = true end
    function Proto:ClearFocus() S(self).focus = false end
    function Proto:HighlightText() S(self).highlighted = true end
    function Proto:SetBackdrop(backdrop) S(self).backdrop = backdrop end
    function Proto:SetBackdropColor(...) S(self).backdropColour = { ... } end
    function Proto:SetBackdropBorderColor(...) S(self).borderColour = { ... } end

    -- The pieces of a game template, made as the game would.
    local function Pieces(frame, keys, kind, layer)
        for key in keys:gmatch("%S+") do rawset(frame, key, New(kind or "Texture", nil, frame, layer or "BACKGROUND")) end
    end
    game.Pieces = Pieces
    local function TabPieces(tab, text)
        Pieces(tab, "LeftActive MiddleActive RightActive Left Middle Right LeftHighlight MiddleHighlight RightHighlight")
        local label = New("FontString", nil, tab, "ARTWORK")
        rawset(tab, "Text", label)
        st[tab].label = label
        st[label].text = text
        st[tab].width, st[tab].height = 80, 32
    end
    game.TabPieces = TabPieces
    env.CreateFrame = function(kind, name, parent, template)
        local frame = New(kind, name, parent)
        st[frame].template = template
        if template == "InputBoxTemplate" then Pieces(frame, "Left Middle Right") end
        if template == "UIPanelButtonTemplate" then Pieces(frame, "Left Middle Right") end
        return frame
    end
    env.CreateFont = function(name)
        local font = New("Font", name)
        st[font].game = false
        return font
    end
    function Proto:CopyFontObject(font) S(self).copied = font end
    for _, name in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontDisable", "GameFontNormalSmall",
        "GameFontHighlightSmall", "GameFontHighlightLarge", "GameFontDisableLarge", "ChatFontNormal",
        "SystemFont_NamePlateLevel", "NumberFontNormal" }) do
        local font = New("Font", name)
        st[font].fontName = name
        st[font].colour = name:find("Normal", 1, true) and name ~= "ChatFontNormal" and { 1, 0.82, 0 } or { 1, 1, 1 }
    end
    env.hooksecurefunc = function(object, method, hook)
        if type(object) == "string" then object, method, hook = env, object, method end
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

    function game.Building(fn)
        local was = building
        building = true
        local results = { fn() }
        building = was
        return unpack(results)
    end

    ---------------------------------------------------------------------------
    -- The game's world
    ---------------------------------------------------------------------------
    env.UIParent = New("Frame", "UIParent")
    st[env.UIParent].fixed = { 0, 0, 1024, 768 }
    st[env.UIParent].width, st[env.UIParent].height = 1024, 768

    -- A thin scroll bar (MinimalScrollBar): its track and thumb pieces, its
    -- two arrows, and whether it has anything to scroll.
    local function ThinBar(holder)
        local bar = New("Frame", nil, holder)
        st[bar].width, st[bar].height = 8, 200
        bar:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
        local track = New("Frame", nil, bar)
        rawset(bar, "Track", track)
        track:SetAllPoints(bar)
        Pieces(track, "Begin Middle End")
        local thumb = New("Frame", nil, track)
        rawset(track, "Thumb", thumb)
        Pieces(thumb, "Begin Middle End")
        for _, key in ipairs({ "Back", "Forward" }) do
            local arrow = New("Button", nil, bar)
            st[arrow].width, st[arrow].height = 10, 10
            arrow:SetPoint(key == "Back" and "BOTTOM" or "TOP", bar, key == "Back" and "TOP" or "BOTTOM", 0, 0)
            rawset(arrow, "Texture", New("Texture", nil, arrow, "ARTWORK"))
            rawset(bar, key, arrow)
        end
        rawset(bar, "HasScrollableExtent", function() return st[bar].scrollable == true end)
        rawset(bar, "SetScrollPercentageInternal", function() end)
        rawset(bar, "Update", function() end)
        rawset(holder, "ScrollBar", bar)
        return bar
    end
    game.ThinBar = ThinBar

    -- One of the game's portrait windows (ButtonFrameTemplate on Forever).
    -- opts: inset (a plain Frame inset), tabs (how many <name>TabN), noPortrait,
    -- noNineSlice, width, height, bg (its background's file).
    local CORNERS = { TopLeftCorner = { "TOPLEFT", -13, 16 }, TopRightCorner = { "TOPRIGHT", 4, 16 },
        BottomLeftCorner = { "BOTTOMLEFT", -13, -3 }, BottomRightCorner = { "BOTTOMRIGHT", 4, -3 } }
    local function Window(name, opts)
        opts = opts or {}
        local window = New("Frame", name, env.UIParent)
        st[window].width, st[window].height = opts.width or 338, opts.height or 424
        window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
        st[window].shown = opts.shown == true
        if not opts.noNineSlice then
            local slice = New("Frame", nil, window)
            rawset(window, "NineSlice", slice)
            slice:SetAllPoints(window)
            for key, at in pairs(CORNERS) do
                local corner = New("Texture", nil, slice, "BORDER")
                corner:SetAtlas("UI-Frame-Metal-" .. key, true)
                corner:SetPoint(at[1], window, at[1], at[2], at[3])
                rawset(slice, key, corner)
            end
            for _, key in ipairs({ "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center" }) do
                local piece = New("Texture", nil, slice, "BORDER")
                piece:SetAtlas("UI-Frame-Metal-" .. key)
                rawset(slice, key, piece)
            end
        end
        if not opts.noPortrait then
            local holder = New("Frame", nil, window)
            rawset(window, "PortraitContainer", holder)
            local face = New("Texture", name and (name .. "Portrait") or nil, holder, "OVERLAY")
            rawset(holder, "portrait", face)
            st[face].width, st[face].height = 62, 62
        end
        local title = New("Frame", nil, window)
        rawset(window, "TitleContainer", title)
        title:SetPoint("TOPLEFT", window, "TOPLEFT", 58, -1)
        title:SetPoint("TOPRIGHT", window, "TOPRIGHT", -24, -1)
        local titleText = New("FontString", nil, title, "OVERLAY")
        rawset(title, "TitleText", titleText)
        local bg = New("Texture", name and (name .. "Bg") or nil, window, "BACKGROUND")
        bg:SetTexture(opts.bg or "Interface\\FrameGeneral\\UI-Background-Rock")
        rawset(window, "Bg", bg)
        rawset(window, "TopTileStreaks", New("Texture", nil, window, "BORDER"))
        local close = New("Button", name and (name .. "CloseButton") or nil, window)
        st[close].width, st[close].height = 24, 24
        close:SetPoint("TOPRIGHT", window, "TOPRIGHT", 0, 0)
        rawset(window, "CloseButton", close)
        if opts.inset then
            local inset = New("Frame", name and (name .. "Inset") or nil, window)
            inset:SetPoint("TOPLEFT", window, "TOPLEFT", 4, -60)
            inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -6, 26)
            local insetSlice = New("Frame", nil, inset)
            rawset(inset, "NineSlice", insetSlice)
            Pieces(insetSlice, "TopEdge BottomEdge LeftEdge RightEdge")
            rawset(inset, "Bg", New("Texture", nil, inset, "BACKGROUND"))
            rawset(window, "Inset", inset)
        end
        for i = 1, opts.tabs or 0 do
            local tab = New("Button", name .. "Tab" .. i, window)
            TabPieces(tab, "Tab " .. i)
            if i == 1 then
                tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 11, 2)
            else
                tab:SetPoint("LEFT", env[name .. "Tab" .. (i - 1)], "RIGHT", -15, 0)
            end
        end
        return window
    end
    game.Window = Window

    function game.Seal()
        for _, obj in ipairs(made) do
            if st[obj].game then sealed[obj] = true end
        end
    end

    ---------------------------------------------------------------------------
    -- EraUI's side
    ---------------------------------------------------------------------------
    local ns = { db = {}, DB_DEFAULTS = {}, RELOAD_KEYS = {}, modules = {}, missing = {} }
    function ns.RegisterModule(key, module)
        module.key = key
        ns.modules[#ns.modules + 1] = module
    end
    function ns.QueueApply() game.queued = (game.queued or 0) + 1 end
    function ns.ApplyAll() game.Pass() end
    function ns.MirrorSave() game.saves = game.saves + 1 end
    function ns.Print(text) game.printed[#game.printed + 1] = tostring(text) end
    function ns.MissingPiece(name) game.missing[#game.missing + 1] = name end
    function ns.CloseOnEscape(frame) table.insert(env.UISpecialFrames, frame:GetName()) end
    -- Dark Mode's hand-overs (Core/Appearance.lua), recorded beside the pieces.
    function ns.ThemeTexture(texture, key) if game.settings.darkMode then game.themed[texture] = key end end
    function ns.DarkWindowArt(texture, role, force)
        game.dark[texture] = role
        if force then game.darkForced = game.darkForced + 1 end
    end
    function ns.DarkCloseButton(button) game.dark[button] = "cross" end
    function ns.DarkRedButton(button) game.dark[button] = "button" end
    function ns.DarkNativeButton(button) game.dark[button] = "native" end
    function ns.DarkBackdrop(frame) game.dark[frame] = "box" end
    game.ns = ns
    local E = { Classic = ns, modules = {} }
    function E:GetSetting(key) return game.settings[key] end
    function E:Print(text) game.printed[#game.printed + 1] = tostring(text) end
    game.E = E

    function game.Load(files)
        building = false
        game.Seal()
        for _, file in ipairs(files) do assert(loadfile(file, "t", env))("EraUI", E) end
        for key, value in pairs(ns.DB_DEFAULTS) do
            if ns.db[key] == nil then ns.db[key] = value end
        end
        game.Look = E.Look
        return E.Look
    end
    function game.Module(key)
        for _, module in ipairs(ns.modules) do
            if module.key == key then return module end
        end
        return nil
    end
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
    -- EraUI's tooltip box's lines, or nil while none shows.
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
            if s.kind == "FontString" and s.shown and s.text then lines[#lines + 1] = tostring(s.text) end
        end
        return table.concat(lines, " | ")
    end
    -- Writes on the game's objects by anything but the game itself fail at
    -- once (sealed); this is the list of made objects for searches.
    function game.Find(test)
        for _, obj in ipairs(made) do
            if test(st[obj], obj) then return obj end
        end
        return nil
    end
    function game.FindAll(test)
        local found = {}
        for _, obj in ipairs(made) do
            if test(st[obj], obj) then found[#found + 1] = obj end
        end
        return found
    end
    return game
end

return Mock
