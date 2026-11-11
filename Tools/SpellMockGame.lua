-- A mock of WoW Forever for the spell windows' tests (the spellbook, the
-- professions book, the trade skill window, the trainer). Not a test itself.
-- It models what those windows lean on:
--   * widgets with anchors, sizes, scales and a small geometry solver;
--   * secure buttons as the game runs them: a click acts on release (with
--     useOnKeyDown false), "attribute", "click", "macro" (/click lines) and
--     "spell" actions, helpbutton remapping on a "player" unit, modifier and
--     button suffixes; PreClick and PostClick run as addon code;
--   * unit watches: a watched frame shows while its unit (its own, or its
--     parent's with useparent-unit, plus unitsuffix) is "player";
--   * the fight lock: in a fight addon code may not move, show, hide,
--     resize, re-parent or set attributes on a protected frame (secure
--     frames, their ancestors, and frames a protected frame is anchored to),
--     nor make a secure frame;
--   * sealed game frames (game.Native): any key EraUI writes on one fails;
--   * no GameTooltip, no MouseIsOver, no key bindings: touching any fails.
-- Usage: local Mock = dofile("Tools/SpellMockGame.lua"); local game = Mock.New()
local Mock = {}

local POINTS = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local REGIONS = { Texture = true, FontString = true, MaskTexture = true }

function Mock.New(options)
    options = options or {}
    local game = { frames = {}, combat = false, restricted = false, now = 100, timers = {}, watched = {}, casts = {},
        errors = {}, sounds = 0, hooks = 0, persisted = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    game.env = env

    local function Fail(text) error(text, 3) end

    ---------------------------------------------------------------------------
    -- Widgets
    ---------------------------------------------------------------------------
    local Methods = {}
    local sealed = setmetatable({}, { __mode = "k" }) -- game frame: true
    local writtenBy = setmetatable({}, { __mode = "k" }) -- game frame: { key = "addon" }

    local function New(kind, name, parent, template)
        local w = { kind = kind, name = name, parent = parent, template = template, points = {}, shown = true,
            alpha = 1, scale = 1, level = 1, strata = "MEDIUM", scripts = {}, hooks = {}, events = {}, attrs = {},
            children = {}, regions = {}, enabled = true, checked = false, colour = { 1, 1, 1, 1 },
            mouse = kind == "Button" or kind == "CheckButton" or kind == "EditBox" }
        setmetatable(w, { __index = Methods, __newindex = function(t, key, value)
            if sealed[t] and not game.native then Fail("EraUI wrote " .. tostring(key) .. " on the game's " .. tostring(t.name or t.kind)) end
            rawset(t, key, value)
        end })
        if parent then
            if REGIONS[kind] then parent.regions[#parent.regions + 1] = w else parent.children[#parent.children + 1] = w end
            if parent.level and not REGIONS[kind] then w.level = parent.level + 1 end
            if parent.strata and not REGIONS[kind] then w.strata = parent.strata end
        end
        game.frames[#game.frames + 1] = w
        if name then env[name] = w end
        return w
    end
    game.New = New

    -- A frame of the game's own: sealed (no key may be written by EraUI).
    function game.Native(fn, ...)
        local was = game.native
        game.native = true
        local a, b = fn(...)
        game.native = was
        return a, b
    end
    function game.GameFrame(kind, name, parent)
        local w = game.Native(New, kind, name, parent)
        sealed[w] = true
        return w
    end

    -- The fight lock on a protected frame (the game's own secure code may).
    local function Lock(self, what)
        if game.combat and self.protected and not game.restricted then
            Fail("EraUI changed a protected frame in a fight (" .. tostring(what) .. " on " .. tostring(self.name or self.kind) .. ")")
        end
    end

    -- Sizes, scales, anchors
    function Methods:SetSize(w, h) Lock(self, "SetSize"); rawset(self, "width", w); rawset(self, "height", h) end
    function Methods:SetWidth(w) Lock(self, "SetWidth"); rawset(self, "width", w) end
    function Methods:SetHeight(h) Lock(self, "SetHeight"); rawset(self, "height", h) end
    function Methods:GetScale() return self.scale end
    function Methods:SetScale(s) Lock(self, "SetScale"); rawset(self, "scale", s) end
    function Methods:GetEffectiveScale()
        if REGIONS[self.kind] then return self.parent and self.parent:GetEffectiveScale() or 1 end
        return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
    end
    function Methods:ClearAllPoints() Lock(self, "ClearAllPoints"); rawset(self, "points", {}) end
    function Methods:SetPoint(point, relative, relativePoint, x, y)
        Lock(self, "SetPoint")
        if type(relative) == "number" then relative, relativePoint, x, y = nil, point, relative, relativePoint end
        if type(relative) == "string" then relative = env[relative] end
        relative = relative or self.parent
        if self.protected and type(relative) == "table" and relative ~= env.UIParent then rawset(relative, "protected", true) end
        local p = { point, relative, relativePoint or point, x or 0, y or 0 }
        for i, old in ipairs(self.points) do
            if old[1] == point then self.points[i] = p return end
        end
        self.points[#self.points + 1] = p
    end
    function Methods:SetAllPoints(relative)
        relative = relative or self.parent
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", relative, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0)
    end
    function Methods:GetNumPoints() return #self.points end
    function Methods:GetPoint(i)
        local p = self.points[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    local solving = {}
    function Methods:Rect()
        if self.fixed then return self.fixed[1], self.fixed[2], self.fixed[3], self.fixed[4] end
        if solving[self] or not self.points[1] then return nil end
        solving[self] = true
        local s = self:GetEffectiveScale()
        local function At(p)
            local rel = p[2]
            if type(rel) ~= "table" or not rel.Rect then return nil end
            local l, b, r, t = rel:Rect()
            if not l then return nil end
            local f = POINTS[p[3]]
            return l + (r - l) * f[1] + p[4] * s, b + (t - b) * f[2] + p[5] * s
        end
        local result
        local first, second = self.points[1], self.points[2]
        if second then
            local x1, y1 = At(first)
            local x2, y2 = At(second)
            if x1 and x2 then
                local f1, f2 = POINTS[first[1]], POINTS[second[1]]
                local l = f1[1] == 0 and x1 or (f2[1] == 0 and x2 or math.min(x1, x2))
                local r = f1[1] == 1 and x1 or (f2[1] == 1 and x2 or math.max(x1, x2))
                local b = f1[2] == 0 and y1 or (f2[2] == 0 and y2 or math.min(y1, y2))
                local t = f1[2] == 1 and y1 or (f2[2] == 1 and y2 or math.max(y1, y2))
                if f1[2] == 0.5 and f2[2] == 0.5 and self.height then b, t = y1 - self.height * s / 2, y1 + self.height * s / 2 end
                result = { l, b, r, t }
            end
        else
            local x, y = At(first)
            if x and self.width and self.height then
                local w, h = self.width * s, self.height * s
                local f = POINTS[first[1]]
                result = { x - w * f[1], y - h * f[2], x - w * f[1] + w, y - h * f[2] + h }
            end
        end
        solving[self] = nil
        if result then return result[1], result[2], result[3], result[4] end
    end
    local function Edge(self, i)
        local e = { self:Rect() }
        if e[i] == nil then return nil end
        return e[i] / self:GetEffectiveScale()
    end
    function Methods:GetLeft() return Edge(self, 1) end
    function Methods:GetBottom() return Edge(self, 2) end
    function Methods:GetRight() return Edge(self, 3) end
    function Methods:GetTop() return Edge(self, 4) end
    function Methods:GetWidth()
        if self.width then return self.width end
        local l, _, r = self:Rect()
        return l and (r - l) / self:GetEffectiveScale() or 0
    end
    function Methods:GetHeight()
        if self.height then return self.height end
        local _, b, _, t = self:Rect()
        return b and (t - b) / self:GetEffectiveScale() or 0
    end
    function Methods:GetRect()
        local l, b, r, t = self:Rect()
        if not l then return nil end
        local s = self:GetEffectiveScale()
        return l / s, b / s, (r - l) / s, (t - b) / s
    end
    function Methods:GetCenter()
        local l, b, r, t = self:Rect()
        if not l then return nil end
        local s = self:GetEffectiveScale()
        return (l + r) / 2 / s, (b + t) / 2 / s
    end

    -- Scripts (handlers are addon code, even when secure code set them off)
    function Methods:SetScript(script, fn)
        if sealed[self] and not game.native then Fail("EraUI replaced the game's " .. script .. " on " .. tostring(self.name or self.kind)) end
        self.scripts[script] = fn
    end
    function Methods:GetScript(script) return self.scripts[script] end
    function Methods:HookScript(script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    function Methods:Fire(script, ...)
        local was = game.restricted
        game.restricted = false
        if self.scripts[script] then self.scripts[script](self, ...) end
        for _, fn in ipairs(self.hooks[script] or {}) do fn(self, ...) end
        game.restricted = was
    end

    -- Shown and alpha
    function Methods:Show() self:SetShown(true) end
    function Methods:Hide() self:SetShown(false) end
    function Methods:SetShown(on)
        Lock(self, on and "Show" or "Hide")
        on = on and true or false
        if self.shown == on then return end
        rawset(self, "shown", on)
        self:Fire(on and "OnShow" or "OnHide")
    end
    function Methods:IsShown() return self.shown end
    function Methods:IsVisible()
        local f = self
        while f do
            if not f.shown then return false end
            f = f.parent
        end
        return true
    end
    function Methods:SetAlpha(a) rawset(self, "alpha", a) end
    function Methods:GetAlpha() return self.alpha end

    -- Layers
    function Methods:SetFrameLevel(l) Lock(self, "SetFrameLevel"); rawset(self, "level", l) end
    function Methods:GetFrameLevel() return self.level end
    function Methods:SetFrameStrata(s) Lock(self, "SetFrameStrata"); rawset(self, "strata", s) end
    function Methods:GetFrameStrata() return self.strata end
    function Methods:SetToplevel() end
    function Methods:SetDrawLayer(layer, sub) rawset(self, "layer", layer); rawset(self, "sublevel", sub) end
    function Methods:GetDrawLayer() return self.layer, self.sublevel end
    function Methods:GetParent() return self.parent end
    function Methods:SetParent(parent)
        Lock(self, "SetParent")
        local old = self.parent
        if old then
            for i, child in ipairs(old.children) do if child == self then table.remove(old.children, i) break end end
        end
        rawset(self, "parent", parent)
        if parent then parent.children[#parent.children + 1] = self end
    end
    function Methods:GetName() return self.name end
    function Methods:GetChildren() return table.unpack(self.children) end
    function Methods:GetRegions() return table.unpack(self.regions) end
    function Methods:IsObjectType(kind) return self.kind == kind end
    function Methods:GetObjectType() return self.kind end
    function Methods:IsForbidden() return false end
    function Methods:IsProtected() return self.protected == true end

    -- Children
    function Methods:CreateTexture(_, layer, _, sub)
        local t = New("Texture", nil, self)
        t.layer, t.sublevel = layer, sub
        return t
    end
    function Methods:CreateMaskTexture() return New("MaskTexture", nil, self) end
    function Methods:CreateFontString(_, layer, font)
        local t = New("FontString", nil, self)
        t.layer, t.font = layer, font
        return t
    end

    -- Textures and text
    function Methods:SetTexture(file) rawset(self, "file", file); rawset(self, "atlas", nil); return true end
    function Methods:GetTexture() return self.file end
    function Methods:GetTextureFilePath() return self.file end
    function Methods:SetAtlas(atlas) rawset(self, "atlas", atlas) end
    function Methods:GetAtlas() return self.atlas end
    function Methods:SetTexCoord(...) rawset(self, "coords", { ... }) end
    function Methods:GetTexCoord()
        local c = self.coords or { 0, 1, 0, 1 }
        if #c == 4 then return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4] end
        return table.unpack(c)
    end
    function Methods:SetVertexColor(r, g, b, a) rawset(self, "colour", { r, g, b, a or 1 }) end
    function Methods:GetVertexColor() return self.colour[1], self.colour[2], self.colour[3], self.colour[4] end
    function Methods:SetColorTexture(r, g, b, a) rawset(self, "colourTexture", { r, g, b, a }) end
    function Methods:SetDesaturated(on) rawset(self, "desaturated", on and true or false) end
    function Methods:SetBlendMode(mode) rawset(self, "blend", mode) end
    function Methods:AddMaskTexture(mask) rawset(self, "masks", self.masks or {}); table.insert(self.masks, mask) end
    function Methods:RemoveMaskTexture(mask)
        for i, held in ipairs(self.masks or {}) do if held == mask then table.remove(self.masks, i) break end end
    end
    function Methods:SetText(text) rawset(self, "text", text) end
    function Methods:GetText() return self.text end
    function Methods:SetFormattedText(format, ...) rawset(self, "text", string.format(format, ...)) end
    function Methods:SetTextColor(r, g, b, a) rawset(self, "textColour", { r, g, b, a or 1 }) end
    function Methods:GetTextColor() local c = self.textColour or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    function Methods:SetFontObject(font) rawset(self, "font", font) end
    function Methods:GetStringWidth() return #(self.text or "") * 6 end
    function Methods:GetStringHeight() return 12 end
    function Methods:IsTruncated() return false end

    -- Mouse, buttons, check buttons, edit boxes, bars, sliders
    function Methods:EnableMouse(on) Lock(self, "EnableMouse"); rawset(self, "mouse", on and true or false) end
    function Methods:IsMouseEnabled() return self.mouse end
    function Methods:IsMouseOver() return self.mouseOver == true end
    function Methods:RegisterForClicks(...) Lock(self, "RegisterForClicks"); rawset(self, "clicks", { ... }) end
    function Methods:RegisterForDrag(...) rawset(self, "drag", { ... }) end
    function Methods:SetAttribute(key, value)
        Lock(self, "SetAttribute " .. tostring(key))
        self.attrs[key] = value
        if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, key, value) end
    end
    function Methods:GetAttribute(key) return self.attrs[key] end
    function Methods:SetEnabled(on) rawset(self, "enabled", on and true or false) end
    function Methods:Enable() self:SetEnabled(true) end
    function Methods:Disable() self:SetEnabled(false) end
    function Methods:IsEnabled() return self.enabled end
    function Methods:SetChecked(on) rawset(self, "checked", on and true or false) end
    function Methods:GetChecked() return self.checked end
    function Methods:SetButtonState(state) rawset(self, "state", state) end
    function Methods:GetButtonState() return self.state or "NORMAL" end
    function Methods:LockHighlight() rawset(self, "highlightLocked", true) end
    function Methods:UnlockHighlight() rawset(self, "highlightLocked", false) end
    function Methods:SetFontString(f) rawset(self, "fontString", f) end
    function Methods:GetFontString() return self.fontString end
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked" }) do
        local key = state:lower() .. "Face"
        Methods["Get" .. state .. "Texture"] = function(self) return self[key] end
        Methods["Set" .. state .. "Texture"] = function(self, path)
            if path == nil then Fail("Usage: self:Set" .. state .. "Texture(asset)") end
            if not self[key] then rawset(self, key, self:CreateTexture(nil, "ARTWORK")) end
            self[key]:SetTexture(path)
        end
    end
    function Methods:SetValue(v)
        local low, high = self.low or 0, self.high or math.huge
        v = math.max(low, math.min(high, v))
        local changed = v ~= self.value
        rawset(self, "value", v)
        if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, v) end
    end
    function Methods:GetValue() return self.value or 0 end
    function Methods:SetMinMaxValues(low, high) rawset(self, "low", low); rawset(self, "high", high) end
    function Methods:GetMinMaxValues() return self.low or 0, self.high or 0 end
    function Methods:SetThumbTexture(t) rawset(self, "thumb", t) end
    function Methods:GetThumbTexture() return self.thumb end
    function Methods:SetStatusBarTexture(path) rawset(self, "barFile", path) end
    function Methods:SetStatusBarColor(r, g, b) rawset(self, "barColour", { r, g, b }) end
    function Methods:GetStatusBarColor() local c = self.barColour or { 1, 1, 1 }; return c[1], c[2], c[3], 1 end
    function Methods:SetCooldown(start, duration) rawset(self, "cooldown", { start, duration }) end
    function Methods:Clear() rawset(self, "cooldown", nil) end
    function Methods:ClearFocus() rawset(self, "focus", false) end
    function Methods:HasFocus() return self.focus == true end
    function Methods:SetFocus() rawset(self, "focus", true) end
    function Methods:SetMaxLines(n) rawset(self, "maxLines", n) end
    function Methods:SetWordWrap(on) rawset(self, "wrap", on) end
    function Methods:SetJustifyH(j) rawset(self, "justifyH", j) end
    function Methods:SetJustifyV(j) rawset(self, "justifyV", j) end
    function Methods:SetBackdrop(info) rawset(self, "backdrop", info) end
    function Methods:SetFrameRef(key, frame) rawset(self, "refs", self.refs or {}); self.refs[key] = frame end
    function Methods:GetFrameRef(key) return self.refs and self.refs[key] end
    function Methods:Raise() end
    -- Cosmetic setters with nothing to keep.
    for _, name in ipairs({ "SetMovable", "SetClampedToScreen", "EnableMouseWheel", "SetHitRectInsets", "SetAutoFocus",
        "SetMaxLetters", "SetNumeric", "SetTextInsets", "SetShadowColor", "SetShadowOffset", "SetOrientation",
        "SetValueStep", "SetObeyStepOnDrag", "SetHorizTile", "SetVertTile", "SetNormalFontObject",
        "SetHighlightFontObject", "SetDisabledFontObject", "SetBackdropColor", "SetBackdropBorderColor",
        "SetClipsChildren", "SetID", "RegisterEvent", "RegisterUnitEvent", "UnregisterEvent", "UnregisterAllEvents",
        "SetScrollChild", "SetVerticalScroll", "SetPushedTextOffset", "SetMotionScriptsWhileDisabled",
        "SetCursorPosition", "SetIgnoreParentAlpha" }) do
        Methods[name] = Methods[name] or function() end
    end
    function Methods:RegisterEvent(event) self.events[event] = true end
    function Methods:RegisterUnitEvent(event) self.events[event] = true end
    function Methods:UnregisterEvent(event) self.events[event] = nil end
    function Methods:UnregisterAllEvents() rawset(self, "events", {}) end
    function Methods:SetVerticalScroll(v) rawset(self, "scroll", v) end
    function Methods:GetVerticalScroll() return self.scroll or 0 end
    function Methods:EnableMouseWheel(on) rawset(self, "wheel", on) end
    function Methods:SetHitRectInsets(...) rawset(self, "insets", { ... }) end

    ---------------------------------------------------------------------------
    -- Secure buttons, as far as these windows use them
    ---------------------------------------------------------------------------
    local function Suffix(button)
        if button == "LeftButton" then return "1" end
        if button == "RightButton" then return "2" end
        return "-" .. button
    end
    local function Attr(f, name, suffix)
        local prefix = game.modifier or ""
        local a = f.attrs
        local v = a[prefix .. name .. suffix]
        if v == nil then v = a["*" .. name .. suffix] end
        if v == nil then v = a[prefix .. name .. "*"] end
        if v == nil then v = a["*" .. name .. "*"] end
        if v == nil then v = a[name] end
        return v
    end
    local function Unit(f)
        local node, unit = f, f.attrs.unit
        while unit == nil and node.attrs["useparent-unit"] and node.parent do
            node = node.parent
            unit = node.attrs.unit
        end
        if unit and f.attrs.unitsuffix then unit = unit .. f.attrs.unitsuffix end
        return unit
    end
    game.Unit = Unit
    local function SecureAction(f, button, down)
        if (down and true or false) ~= (f.attrs.useOnKeyDown and true or false) then return end
        local unit = Attr(f, "unit", Suffix(button))
        if unit == "player" then
            local help = Attr(f, "helpbutton", Suffix(button))
            if help then button = help end
        end
        local suffix = Suffix(button)
        local kind = Attr(f, "type", suffix)
        if kind == "attribute" then
            local target = Attr(f, "attribute-frame", suffix) or f
            local name = Attr(f, "attribute-name", suffix)
            if name then target.attrs[name] = Attr(f, "attribute-value", suffix) end
        elseif kind == "click" then
            local other = Attr(f, "clickbutton", suffix)
            if other then other:Click(button, down) end
        elseif kind == "macro" then
            for line in (Attr(f, "macrotext", suffix) or ""):gmatch("[^\n]+") do
                local name = line:match("^/click%s+(%S+)")
                if name and env[name] then env[name]:Click("LeftButton", false) end
            end
        elseif kind == "spell" then
            game.casts[#game.casts + 1] = Attr(f, "spell", suffix)
        end
    end
    function Methods:Click(button, down)
        button = button or "LeftButton"
        if self.scripts.PreClick then self:Fire("PreClick", button, down) end
        local secure = self.template and self.template:find("Secure", 1, true)
        if secure then
            local was = game.restricted
            game.restricted = true
            SecureAction(self, button, down)
            game.restricted = was
        elseif self.enabled ~= false then
            if self.kind == "CheckButton" then rawset(self, "checked", not self.checked) end
            if self.scripts.OnClick then self:Fire("OnClick", button, down) end
        end
        if self.scripts.PostClick then self:Fire("PostClick", button, down) end
    end
    -- A real mouse click: down then up.
    function game.Press(button)
        button:Click("LeftButton", true)
        button:Click("LeftButton", false)
        game.Settle()
    end

    -- Unit watches (the game's state driver: every 0.2 s, here every Settle)
    local function Watch()
        local was = game.restricted
        game.restricted = true
        for _, f in ipairs(game.watched) do f:SetShown(Unit(f) == "player") end
        game.restricted = was
    end
    game.Watch = Watch
    function game.Settle()
        for _ = 1, 30 do
            Watch()
            if #game.timers == 0 then return end
            local due = game.timers
            game.timers = {}
            for _, timer in ipairs(due) do timer.fn() end
        end
        error("timers never settled")
    end
    -- Time passing: every OnUpdate run in steps, timers as they come due.
    function game.Tick(seconds, step)
        step = step or 0.05
        local done = 0
        while done < seconds - 1e-9 do
            game.now = game.now + step
            done = done + step
            local list = {}
            for _, f in ipairs(game.frames) do list[#list + 1] = f end
            for _, f in ipairs(list) do
                if f.scripts.OnUpdate and f:IsShown() then f:Fire("OnUpdate", step) end
            end
            Watch()
            local due, kept = {}, {}
            for _, timer in ipairs(game.timers) do
                if timer.at <= game.now then due[#due + 1] = timer else kept[#kept + 1] = timer end
            end
            game.timers = kept
            for _, timer in ipairs(due) do timer.fn() end
        end
        Watch()
    end
    function game.Fire(event, ...)
        local list = {}
        for _, f in ipairs(game.frames) do if f.events[event] and f.scripts.OnEvent then list[#list + 1] = f end end
        for _, f in ipairs(list) do f:Fire("OnEvent", event, ...) end
    end
    function game.EnterCombat()
        game.Fire("PLAYER_REGEN_DISABLED")
        game.combat = true
        game.Settle()
    end
    function game.LeaveCombat()
        game.combat = false
        game.Fire("PLAYER_REGEN_ENABLED")
        game.Settle()
    end

    ---------------------------------------------------------------------------
    -- The globals
    ---------------------------------------------------------------------------
    env.CreateFrame = function(kind, name, parent, template)
        local secure = type(template) == "string" and template:find("Secure", 1, true) ~= nil
        if secure and game.combat then Fail("a secure frame made in a fight") end
        if template and options.templates and options.templates[template] == false then error("no such template " .. template) end
        local f = New(kind or "Frame", name, parent, template)
        if secure then
            f.protected = true
            local p = parent
            while p and p ~= env.UIParent do rawset(p, "protected", true); p = p.parent end
        end
        if template == "SecureHandlerStateTemplate" then
            function f:Execute(body)
                if game.combat then Fail("Execute in a fight") end
                local snippet = assert(load(body, "snippet", "t", { self = f }))
                local was = game.restricted
                game.restricted = true
                snippet()
                game.restricted = was
            end
        end
        if template == "CooldownFrameTemplate" then f.kind = "Cooldown" end
        if template == "InputBoxTemplate" then f.Left, f.Right, f.Middle = f:CreateTexture(), f:CreateTexture(), f:CreateTexture() end
        if template == "BackdropTemplate" then
            for _, piece in ipairs({ "TopLeftCorner", "TopRightCorner", "TopEdge", "BottomEdge" }) do f[piece] = f:CreateTexture() end
        end
        return f
    end
    env.UIParent = New("Frame", "UIParent")
    env.UIParent.fixed = { 0, 0, 1024, 768 }
    env.UIParent.width, env.UIParent.height = 1024, 768
    env.RegisterUnitWatch = function(f) game.watched[#game.watched + 1] = f end
    env.UnregisterUnitWatch = function(f)
        for i, w in ipairs(game.watched) do if w == f then table.remove(game.watched, i) break end end
    end
    env.RegisterStateDriver = function() Fail("a state driver (never wanted here)") end
    env.InCombatLockdown = function() return game.combat end
    env.issecretvalue = function(v) return game.secret ~= nil and v == game.secret end
    env.issecurevariable = function(t, key)
        local by = writtenBy[t]
        return not (by and by[key])
    end
    function game.AddonWrote(t, key) writtenBy[t] = writtenBy[t] or {}; writtenBy[t][key] = true end
    env.GetTime = function() return game.now end
    env.IsLoggedIn = function() return true end
    env.C_Timer = { After = function(delay, fn) game.timers[#game.timers + 1] = { at = game.now + (delay or 0), fn = fn } end }
    env.geterrorhandler = function() return function(err) game.errors[#game.errors + 1] = err end end
    env.hooksecurefunc = function(object, key, fn)
        if type(object) == "string" then object, key, fn = env, object, key end
        game.hooks = game.hooks + 1
        local old = object[key]
        assert(type(old) == "function", "hooking a missing " .. tostring(key))
        local wrapped = function(...)
            local a, b, c = old(...)
            fn(...)
            return a, b, c
        end
        if sealed[object] then game.Native(rawset, object, key, wrapped) else rawset(object, key, wrapped) end
    end
    env.PlaySound = function() game.sounds = game.sounds + 1 end
    env.SOUNDKIT = setmetatable({}, { __index = function() return 1 end })
    env.unpack = table.unpack
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.CreateFont = function(name)
        local font = { name = name }
        function font:CopyFontObject() end
        function font:SetFontObject() end
        function font:SetTextColor() end
        env[name] = font
        return font
    end
    for _, font in ipairs({ "GameFontNormal", "GameFontHighlight", "GameFontHighlightSmall", "GameFontNormalSmall",
        "GameFontDisable", "GameFontDisableSmall", "GameFontBlack", "SubSpellFont", "NumberFontNormal", "GameFontRedSmall",
        "GameFontNormalLarge", "TextStatusBarText", "QuestTitleFontBlackShadow", "QuestFont_Shadow_Small", "QuestFont_Large" }) do
        env[font] = { name = font }
    end
    env.IsModifiedClick = function(action) return game.modified == action end
    env.UISpecialFrames = {}
    env.CloseSpecialWindows = function()
        local found
        for _, name in pairs(env.UISpecialFrames) do
            local f = env[name]
            if f and f:IsShown() then f:Hide(); found = 1 end
        end
        return found
    end
    -- Never touched by EraUI's look: the game's tooltip, MouseIsOver, bindings.
    env.GameTooltip = setmetatable({}, { __index = function(_, key) Fail("EraUI used GameTooltip." .. tostring(key)) end })
    for _, name in ipairs({ "MouseIsOver", "SetOverrideBinding", "SetOverrideBindingClick", "ClearOverrideBindings",
        "SetBinding", "SetBindingClick", "SaveBindings" }) do
        env[name] = function() Fail("EraUI called " .. name) end
    end
    env.GetBindingKey = function(command) if command == "TOGGLESPELLBOOK" then return "P" end end
    env.NORMAL_FONT_COLOR = { GetRGB = function() return 1, 0.82, 0 end }
    env.PASSIVE_SPELL_FONT_COLOR = { GetRGB = function() return 0.77, 0.64, 0 end }
    env.SPELLBOOK, env.PAGE_NUMBER, env.SEARCH, env.TRADE_SKILLS, env.PET = "Spellbook", "Page %d", "Search", "Professions", "Pet"

    ---------------------------------------------------------------------------
    -- EraUI's side: the namespace, settings, the Look/ base
    ---------------------------------------------------------------------------
    local ns = { db = {}, DB_DEFAULTS = {}, modules = {} }
    game.ns = ns
    function ns.RegisterModule(key, module)
        module.key = key
        ns.modules[#ns.modules + 1] = module
        ns.modules[key] = module
    end
    function ns.Persist(line) game.persisted[#game.persisted + 1] = line end
    function ns.MirrorSave() game.saves = (game.saves or 0) + 1 end
    function ns.QueueApply() game.queued = (game.queued or 0) + 1 end
    function ns.RegisterClassicWindow(frame, shares) game.registered = { frame = frame, shares = shares } end
    function ns.MapPad(real, strata, after, target, when) game.pad = { real = real, target = target, when = when } end
    function ns.RefreshMicroButtons() game.microRefreshes = (game.microRefreshes or 0) + 1 end
    function ns.MicroButtonFollows(button, isShown) game.follows = game.follows or {}; game.follows[button] = isShown end
    game.settings = { enabled = true, trainingGuide = true }
    local E = { Classic = ns, modules = {}, settings = game.settings }
    function E:GetSetting(key) return self.settings[key] end
    function E:RegisterModule(name, module) self.modules[name] = module end
    function E:SaveSettings() end
    game.E = E
    function game.Load(path) assert(loadfile(path, "t", env))("EraUI", E) end
    -- The engine's pass: each entry's apply, or restore when its key is off.
    function game.Pass()
        for _, module in ipairs(ns.modules) do
            if ns.db[module.key] ~= false then module.apply() else module.restore() end
        end
    end
    function game.Login()
        for _, module in ipairs(ns.modules) do
            if module.init and ns.db[module.key] ~= false then module.init() end
        end
        game.Pass()
        game.Settle()
    end
    return game
end

-- The game's spellbook data: lines of spells (and optional pet spells).
-- lines: { { name, count, passive = { slot = true }, ranks = { slot = "Rank n" }, names = { slot = name } } }
function Mock.SpellBook(game, lines, pet)
    local env = game.env
    env.Enum = env.Enum or {}
    env.Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
    -- Forever's values (SpellBookConstantsDocumentation): a pet's spells are
    -- PetAction items, never flyouts.
    env.Enum.SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4 }
    local items, offset, info = {}, 0, {}
    for index, line in ipairs(lines) do
        info[index] = { name = line.name, iconID = 100 + index, itemIndexOffset = offset, numSpellBookItems = line.count,
            shouldHide = line.hidden or false, offSpecID = line.offSpec or 0 }
        for n = 1, line.count do
            local slot = offset + n
            local extra = line.items and line.items[n] or {}
            items[slot] = { name = extra.name or (line.name .. " " .. n), subName = extra.subName or "Rank 1",
                iconID = 1000 + slot, spellID = 5000 + slot, actionID = 5000 + slot, itemType = extra.itemType or 1,
                isPassive = extra.passive or false, isOffSpec = extra.offSpec or false }
        end
        offset = offset + line.count
    end
    game.items = items
    -- A line marked uncounted (and every one after it) is left out of the
    -- count and has no line info, as Forever does with a rogue's Poisons:
    -- only its spells can be read, by slot.
    local counted = #info
    for index, line in ipairs(lines) do
        if line.uncounted then counted = math.min(counted, index - 1) end
    end
    local pets = pet or {}
    for slot, item in ipairs(pets) do
        if item.itemType == nil then item.itemType = 3 end
        if item.spellID == nil then item.spellID = 6000 + slot end
    end
    game.petItems = pets
    env.C_SpellBook = {
        GetNumSpellBookSkillLines = function() return counted end,
        GetSpellBookSkillLineInfo = function(i) if i > counted then return nil end return info[i] end,
        GetSpellBookItemInfo = function(slot, bank)
            if bank == 1 then return pets[slot] end
            return items[slot]
        end,
        HasPetSpells = function() if #pets > 0 then return #pets, "CAT" end return nil end,
        GetSpellBookItemCooldown = function() return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end,
        PickupSpellBookItem = function(slot, bank) game.picked = { slot, bank } end,
        GetSpellBookItemLink = function(slot) return "|Hspell:" .. (5000 + slot) .. "|h[" .. tostring(items[slot] and items[slot].name) .. "]|h" end,
    }
    env.PET_TYPE_CAT = "Cat"
end

-- The game's own spellbook window (PlayerSpellsFrame, sealed), its spell
-- items for the first page of the first line, its category tabs, the
-- spellbook micro button and the game's spellbook key
-- (PlayerSpellsUtil.ToggleSpellBookFrame). Both toggle the window.
function Mock.GameSpellbook(game, itemCount)
    local env = game.env
    local G = game.GameFrame
    local window = G("Frame", "PlayerSpellsFrame", env.UIParent)
    local page = G("Frame", nil, window)
    local paged = G("Frame", nil, page)
    local talents = G("Frame", nil, window)
    local items, tabs = {}, {}
    game.Native(function()
        window.shown = false
        window:SetSize(800, 600)
        window:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 16, -116)
        window.SpellBookFrame, window.TalentsFrame = page, talents
        page.PagedSpellsFrame = paged
        talents.shown = false
        for i = 1, itemCount or 8 do
            local item = G("Frame", nil, paged)
            item:SetSize(180, 50)
            item:SetPoint("TOPLEFT", paged, "TOPLEFT", 10, -60 * i)
            item.Button = G("Button", nil, item)
            item.Button:SetSize(36, 36)
            item.Button:SetPoint("TOPLEFT", item, "TOPLEFT", 6, -7)
            item.slotIndex, item.spellBank = i, 0
            function item:HasValidData() return true end
            items[i] = item
        end
        function paged:EnumerateFrames() return ipairs(items) end
        page.categoryMixins = {}
        local system = G("Frame", nil, page)
        page.CategoryTabSystem = system
        for id, bank in ipairs({ 0, 0, 1 }) do
            local category = { tabID = id, bank = bank }
            function category:GetSpellBank() return self.bank end
            function category:GetTabID() return self.tabID end
            function category:ContainsSkillLine(line) return self.bank == 0 and line == self.tabID end
            page.categoryMixins[id] = category
            local tab = G("Button", nil, system)
            tab:SetScript("OnClick", function() game.gameTab = id end)
            tabs[id] = tab
        end
        function system:GetTabButton(id) return tabs[id] end
    end)
    local function Toggle()
        game.Native(function()
            if window:IsShown() then window:Hide() return end
            page.shown, talents.shown = true, false
            window:Show()
        end)
    end
    env.PlayerSpellsUtil = { ToggleSpellBookFrame = Toggle }
    local micro = G("Button", "SpellbookMicroButton", env.UIParent)
    game.Native(function() micro:SetScript("OnClick", function() game.microClicks = (game.microClicks or 0) + 1; Toggle() end) end)
    env.HideUIPanel = function(frame) game.Native(function() frame:Hide() end) end
    game.gameBook, game.gameItems, game.gameTabs = window, items, tabs
    return window
end

return Mock
