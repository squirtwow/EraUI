-- A small mock of WoW Forever's UI for the Look/ tests (Tools/TestClassicBand.lua
-- and friends). Not a test itself. It models what the band touches:
--   * frames, textures and font strings with anchors, sizes, scales and a
--     simple geometry solver (one anchor plus a size, or two corners), so
--     GetLeft/GetBottom/GetRight/GetTop answer as the game would;
--   * Edit Mode system frames whose SetPoint, ClearAllPoints and SetScale are
--     Edit Mode's overrides: any call from EraUI is recorded (game.overrides),
--     and their plain ...Base methods record a move made in a fight
--     (game.fightMoves);
--   * Action Bar 1 with its end caps and page arrows, bars 2 to 8, the stance,
--     pet and possess bars, the micro menu, the bag bar, both XP containers,
--     the player cast bar, Edit Mode's manager, the world map and the minimap's
--     zone button;
--   * each action button's art pieces from Forever's ActionButtonTemplate
--     (icon and its round mask, SlotBackground, SlotArt, Flash, Border, the
--     state faces) and its UpdateButtonArt (game.buttonArtUpdates counts it).
-- Usage: local Mock = dofile("Tools/LookMockGame.lua"); local game = Mock.New()
local Mock = {}

local POINTS = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}

function Mock.New(options)
    options = options or {}
    local game = { frames = {}, combat = false, editing = false, now = 100, timers = {}, mouseDown = false,
        overrides = {}, fightMoves = {}, native = false, queued = 0, saves = 0, settingsValues = {}, bindings = {},
        inventory = {}, hooks = 0 }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    game.env = env

    ---------------------------------------------------------------------------
    -- Widgets
    ---------------------------------------------------------------------------
    local Proto = {}
    local function New(kind, name, parent)
        local w = setmetatable({ kind = kind, name = name, parent = parent, points = {}, shown = true, alpha = 1,
            scale = 1, level = 1, strata = "MEDIUM", scripts = {}, scriptHooks = {}, events = {}, attributes = {},
            children = {}, regions = {}, mouse = false, color = { 1, 1, 1, 1 }, state = "NORMAL", enabled = true },
            { __index = Proto })
        if parent and parent.children and kind ~= "Texture" and kind ~= "FontString" and kind ~= "MaskTexture" then
            parent.children[#parent.children + 1] = w
        end
        game.frames[#game.frames + 1] = w
        if name then env[name] = w end
        return w
    end
    game.New = New

    function Proto:GetName() return self.name end
    function Proto:GetParent() return self.parent end
    function Proto:SetParent(parent)
        if self.parent and self.parent.children then
            for i, child in ipairs(self.parent.children) do
                if child == self then table.remove(self.parent.children, i) break end
            end
        end
        self.parent = parent
        if parent and parent.children then parent.children[#parent.children + 1] = self end
    end
    function Proto:IsObjectType(kind) return self.kind == kind end
    function Proto:IsForbidden() return false end
    -- Sizes and scales
    function Proto:SetSize(w, h) self.width, self.height = w, h end
    function Proto:SetWidth(w) self.width = w end
    function Proto:SetHeight(h) self.height = h end
    function Proto:GetScale() return self.scale end
    function Proto:SetScale(s) self.scale = s end
    function Proto:GetEffectiveScale()
        if self.kind == "Texture" or self.kind == "FontString" or self.kind == "MaskTexture" then
            return self.parent and self.parent:GetEffectiveScale() or 1
        end
        return self.scale * (self.parent and self.parent:GetEffectiveScale() or 1)
    end
    -- Anchors
    function Proto:ClearAllPoints() self.points = {} end
    function Proto:SetPoint(point, relative, relativePoint, x, y)
        if type(relative) == "number" then relative, relativePoint, x, y = nil, point, relative, relativePoint end
        if type(relative) == "string" then relative = env[relative] end
        local p = { point, relative or self.parent, relativePoint or point, x or 0, y or 0 }
        for i, old in ipairs(self.points) do
            if old[1] == point then self.points[i] = p return end
        end
        self.points[#self.points + 1] = p
    end
    function Proto:SetAllPoints(relative)
        relative = relative or self.parent
        self.points = { { "TOPLEFT", relative, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0 } }
    end
    function Proto:GetNumPoints() return #self.points end
    function Proto:GetPoint(i)
        local p = self.points[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    -- The geometry solver: screen pixels (left, bottom, right, top).
    local solving = {}
    function Proto:Rect()
        if self.fixed then
            local f = self:GetEffectiveScale()
            return self.fixed[1] * f, self.fixed[2] * f, self.fixed[3] * f, self.fixed[4] * f
        end
        if solving[self] then return nil end
        local first = self.points[1]
        if not first then return nil end
        solving[self] = true
        local s = self:GetEffectiveScale()
        local function At(p)
            local relative = p[2]
            if not relative then return nil end
            local l, b, r, t = relative:Rect()
            if not l then return nil end
            local f = POINTS[p[3]]
            return l + (r - l) * f[1] + p[4] * s, b + (t - b) * f[2] + p[5] * s
        end
        local result
        local second = self.points[2]
        if second then
            local x1, y1 = At(first)
            local x2, y2 = At(second)
            if x1 and x2 then
                local f1, f2 = POINTS[first[1]], POINTS[second[1]]
                local l = f1[1] == 0 and x1 or (f2[1] == 0 and x2 or math.min(x1, x2))
                local r = f1[1] == 1 and x1 or (f2[1] == 1 and x2 or math.max(x1, x2))
                local b = f1[2] == 0 and y1 or (f2[2] == 0 and y2 or math.min(y1, y2))
                local t = f1[2] == 1 and y1 or (f2[2] == 1 and y2 or math.max(y1, y2))
                result = { l, b, r, t }
            end
        else
            local x, y = At(first)
            if x and self.width and self.height then
                local w, h = self.width * s, self.height * s
                local f = POINTS[first[1]]
                local l, b = x - w * f[1], y - h * f[2]
                result = { l, b, l + w, b + h }
            end
        end
        solving[self] = nil
        if result then return result[1], result[2], result[3], result[4] end
        return nil
    end
    local function Edge(self, i)
        local edges = { self:Rect() }
        if edges[i] == nil then return nil end
        return edges[i] / self:GetEffectiveScale()
    end
    function Proto:GetLeft() return Edge(self, 1) end
    function Proto:GetBottom() return Edge(self, 2) end
    function Proto:GetRight() return Edge(self, 3) end
    function Proto:GetTop() return Edge(self, 4) end
    function Proto:GetWidth()
        if self.width then return self.width end
        local l, _, r = self:Rect()
        return l and (r - l) / self:GetEffectiveScale() or 0
    end
    function Proto:GetHeight()
        if self.height then return self.height end
        local _, b, _, t = self:Rect()
        return b and (t - b) / self:GetEffectiveScale() or 0
    end
    function Proto:GetCenter()
        local l, b, r, t = self:Rect()
        if not l then return nil end
        local s = self:GetEffectiveScale()
        return (l + r) / 2 / s, (b + t) / 2 / s
    end
    -- Shown and alpha
    function Proto:Show()
        if self.shown then return end
        self.shown = true
        if self.scripts.OnShow then self.scripts.OnShow(self) end
        for _, fn in ipairs(self.scriptHooks.OnShow or {}) do fn(self) end
    end
    function Proto:Hide()
        if not self.shown then return end
        self.shown = false
        if self.scripts.OnHide then self.scripts.OnHide(self) end
        for _, fn in ipairs(self.scriptHooks.OnHide or {}) do fn(self) end
    end
    function Proto:SetShown(on) if on then self:Show() else self:Hide() end end
    function Proto:IsShown() return self.shown end
    function Proto:IsVisible()
        if not self.shown then return false end
        return self.parent == nil or self.parent:IsVisible()
    end
    function Proto:SetAlpha(a) self.alpha = a end
    function Proto:GetAlpha() return self.alpha end
    function Proto:GetEffectiveAlpha() return self.alpha * (self.parent and self.parent.GetEffectiveAlpha and self.parent:GetEffectiveAlpha() or 1) end
    -- Layers
    function Proto:SetFrameLevel(l) self.level = l end
    function Proto:GetFrameLevel() return self.level end
    function Proto:SetFrameStrata(s) self.strata = s end
    function Proto:GetFrameStrata() return self.strata end
    function Proto:SetDrawLayer(layer, sub) self.layer, self.sublevel = layer, sub end
    function Proto:GetDrawLayer() return self.layer, self.sublevel end
    -- Children
    function Proto:CreateTexture(_, layer, _, sub)
        local t = New("Texture", nil, self)
        t.layer, t.sublevel = layer, sub
        self.regions[#self.regions + 1] = t
        return t
    end
    function Proto:CreateMaskTexture()
        local t = New("MaskTexture", nil, self)
        self.regions[#self.regions + 1] = t
        return t
    end
    function Proto:CreateFontString(_, layer, font)
        local t = New("FontString", nil, self)
        t.layer, t.fontObject = layer, font
        self.regions[#self.regions + 1] = t
        return t
    end
    function Proto:GetChildren() return table.unpack(self.children) end
    function Proto:GetRegions() return table.unpack(self.regions) end
    -- Textures
    function Proto:SetTexture(path) self.file, self.atlas = path, nil; return true end
    function Proto:GetTexture() return self.file end
    -- useAtlasSize: the texture takes the atlas's own size (kept as a flag).
    function Proto:SetAtlas(atlas, useAtlasSize)
        self.atlas, self.file = atlas, nil
        self.atlasSized = useAtlasSize and true or nil
    end
    -- Masks on a texture (an action button's round icon mask).
    function Proto:AddMaskTexture(mask)
        self.masks = self.masks or {}
        self.masks[#self.masks + 1] = mask
        game.maskChanges = (game.maskChanges or 0) + 1
    end
    function Proto:RemoveMaskTexture(mask)
        for i, held in ipairs(self.masks or {}) do
            if held == mask then table.remove(self.masks, i) break end
        end
        game.maskChanges = (game.maskChanges or 0) + 1
    end
    function Proto:GetNumMaskTextures() return #(self.masks or {}) end
    function Proto:GetAtlas() return self.atlas end
    function Proto:SetTexCoord(...) self.coords = { ... } end
    function Proto:SetVertexColor(r, g, b, a) self.color = { r, g, b, a or 1 } end
    function Proto:GetVertexColor() return self.color[1], self.color[2], self.color[3], self.color[4] end
    function Proto:SetDesaturated(on) self.desaturated = on and true or false end
    function Proto:IsDesaturated() return self.desaturated end
    function Proto:SetBlendMode(mode) self.blend = mode end
    function Proto:GetBlendMode() return self.blend end
    function Proto:SetColorTexture(r, g, b, a) self.colorTexture = { r, g, b, a } end
    function Proto:SetGradient() end
    -- Text
    function Proto:SetText(text) self.text = text end
    function Proto:GetText() return self.text end
    function Proto:SetFontObject(font) self.fontObject = font end
    function Proto:SetFont(font, size, flags) self.font = { font, size, flags } end
    function Proto:GetFont() if self.font then return self.font[1], self.font[2], self.font[3] end return "Fonts\\ARIALN.TTF", 12, "" end
    function Proto:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a or 1 } end
    function Proto:GetTextColor() local c = self.textColor or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
    function Proto:SetJustifyH(j) self.justify = j end
    function Proto:SetShadowColor() end
    function Proto:SetShadowOffset() end
    function Proto:GetStringWidth() return 100 end
    function Proto:GetStringHeight() return 12 end
    -- Scripts and events
    function Proto:SetScript(script, fn) self.scripts[script] = fn end
    function Proto:GetScript(script) return self.scripts[script] end
    function Proto:HookScript(script, fn)
        self.scriptHooks[script] = self.scriptHooks[script] or {}
        table.insert(self.scriptHooks[script], fn)
    end
    function Proto:RegisterEvent(event) self.events[event] = true end
    function Proto:RegisterUnitEvent(event) self.events[event] = true end
    function Proto:UnregisterEvent(event) self.events[event] = nil end
    function Proto:UnregisterAllEvents() self.events = {} end
    -- Mouse and buttons
    function Proto:EnableMouse(on) self.mouse = on and true or false end
    function Proto:IsMouseEnabled() return self.mouse end
    function Proto:EnableMouseWheel(on) self.wheel = on end
    function Proto:RegisterForDrag(button) self.dragButton = button end
    function Proto:RegisterForClicks(...) self.clicks = { ... } end
    function Proto:SetMovable(on) self.movable = on end
    function Proto:SetClampedToScreen(on) self.clamped = on end
    function Proto:StartMoving() self.moving = true end
    function Proto:StopMovingOrSizing() self.moving = false end
    function Proto:IsMouseOver() return self.mouseOver == true end
    function Proto:IsProtected() return self.protected == true end
    function Proto:SetAttribute(key, value) self.attributes[key] = value end
    function Proto:GetAttribute(key) return self.attributes[key] end
    function Proto:SetHitRectInsets(...) self.insets = { ... } end
    function Proto:SetButtonState(state, locked) self.state, self.locked = state, locked end
    function Proto:GetButtonState() return self.state end
    function Proto:LockHighlight() self.highlightLocked = true end
    function Proto:UnlockHighlight() self.highlightLocked = false end
    function Proto:IsEnabled() return self.enabled end
    function Proto:SetEnabled(on) self.enabled = on and true or false end
    function Proto:Enable() self.enabled = true end
    function Proto:Disable() self.enabled = false end
    function Proto:SetChecked(on) self.checked = on and true or false end
    function Proto:GetChecked() return self.checked end
    function Proto:SetBackdrop(b) self.backdrop = b end
    function Proto:SetBackdropColor() end
    function Proto:SetBackdropBorderColor() end
    function Proto:SetClipsChildren() end
    function Proto:SetHighlightLocked() end
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked" }) do
        local key = state:lower() .. "Face"
        Proto["Get" .. state .. "Texture"] = function(self) return self[key] end
        Proto["Set" .. state .. "Texture"] = function(self, path)
            -- As the game: an asset is required (nil is refused).
            if path == nil then error("Usage: self:Set" .. state .. "Texture(asset)", 2) end
            if not self[key] then self[key] = self:CreateTexture(nil, "ARTWORK") end
            self[key]:SetTexture(path)
        end
        Proto["Set" .. state .. "Atlas"] = function(self, atlas)
            if not self[key] then self[key] = self:CreateTexture(nil, "ARTWORK") end
            self[key]:SetAtlas(atlas)
        end
    end
    -- Sliders (MinimalSliderWithSteppersTemplate)
    function Proto:Init(value) self.value = value end
    function Proto:SetValue(value) self.value = value end
    function Proto:RegisterCallback(_, fn, owner) self.callback, self.callbackOwner = fn, owner end

    ---------------------------------------------------------------------------
    -- Edit Mode systems
    ---------------------------------------------------------------------------
    local function EditSystem(w, system, index, settings)
        w.system, w.systemIndex = system, index
        w.default = true
        w.settings = settings or {}
        w.systemInfo = { anchorInfo = { point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", offsetX = 0, offsetY = 0 } }
        w.SetPointBase, w.ClearAllPointsBase, w.SetScaleBase = function(self, ...)
            if game.combat then game.fightMoves[#game.fightMoves + 1] = (self.name or "?") .. ".SetPointBase" end
            return Proto.SetPoint(self, ...)
        end, function(self)
            if game.combat then game.fightMoves[#game.fightMoves + 1] = (self.name or "?") .. ".ClearAllPointsBase" end
            return Proto.ClearAllPoints(self)
        end, function(self, s)
            if game.combat then game.fightMoves[#game.fightMoves + 1] = (self.name or "?") .. ".SetScaleBase" end
            return Proto.SetScale(self, s)
        end
        for _, method in ipairs({ "SetPoint", "ClearAllPoints", "SetScale", "SetAllPoints" }) do
            w[method] = function(self, ...)
                if not game.native then game.overrides[#game.overrides + 1] = (self.name or "?") .. "." .. method end
                return Proto[method](self, ...)
            end
        end
        -- As in the game: false (not nil) until Edit Mode has set the frame up,
        -- and every setting 0 until then.
        function w:IsInDefaultPosition() return self:IsInitialized() and self.default end
        function w:IsInitialized() return self.uninitialized ~= true end
        function w:GetSettingValue(setting)
            if not self:IsInitialized() then return 0 end
            return self.settings[setting] or 0
        end
        function w:ResetToDefaultPosition() self.default = true; game.resets = (game.resets or 0) + 1 end
        w.Selection = New("Frame", nil, w)
        w.Selection:SetAllPoints(w)
        w.Selection.mouse = true
        return w
    end
    game.EditSystem = EditSystem
    -- The game's own call (not EraUI's): overrides allowed, nothing recorded.
    function game.Native(fn, ...)
        local was = game.native
        game.native = true
        fn(...)
        game.native = was
    end

    ---------------------------------------------------------------------------
    -- The globals
    ---------------------------------------------------------------------------
    env.CreateFrame = function(kind, name, parent, template)
        local w = New(kind or "Frame", name, parent)
        if template and template:find("UIPanelCloseButton") then w.template = template end
        if template == "UIPanelButtonTemplate" then
            w.Left, w.Middle, w.Right = w:CreateTexture(), w:CreateTexture(), w:CreateTexture()
        end
        w.template = template
        return w
    end
    env.UIParent = New("Frame", "UIParent")
    env.UIParent.fixed = { 0, 0, options.screenWidth or 1024, 768 }
    env.UIParent.width, env.UIParent.height = options.screenWidth or 1024, 768
    env.InCombatLockdown = function() return game.combat end
    env.issecretvalue = function(v) return game.secret ~= nil and v == game.secret end
    env.GetTime = function() return game.now end
    env.IsMouseButtonDown = function() return game.mouseDown end
    env.C_Timer = { After = function(delay, fn) game.timers[#game.timers + 1] = { at = game.now + delay, fn = fn } end }
    env.geterrorhandler = function() return function(err) game.errors = game.errors or {}; table.insert(game.errors, err) end end
    env.hooksecurefunc = function(object, key, fn)
        if type(object) == "string" then object, key, fn = env, object, key end
        game.hooks = game.hooks + 1
        local old = object[key]
        assert(type(old) == "function", "hooking a missing " .. tostring(key))
        rawset(object, key, function(...)
            local a, b, c = old(...)
            fn(...)
            return a, b, c
        end)
    end
    env.GetInventoryItemTexture = function(_, id) return game.inventory[id] end
    env.GetBindingKey = function(command) return game.bindings[command] end
    env.GetBindingText = function(key) return key end
    env.Settings = { GetValue = function(name) return game.settingsValues[name] end }
    env.Enum = {
        EditModeActionBarSetting = { Orientation = 0, NumRows = 1, NumIcons = 2, IconSize = 3, HideBarArt = 4, HideBarScrolling = 5 },
        EditModeMainActionBarEndCapSetting = { Hidden = 0 },
        EditModeBagsSetting = { Size = 2 },
    }
    env.ToggleWorldMap = function() game.mapToggles = (game.mapToggles or 0) + 1 end
    env.LoadMicroButtonTextures = function(button, name)
        button.textureName = name
        button:SetNormalAtlas("UI-HUD-MicroMenu-" .. name .. "-Up")
    end
    env.MultiActionBar_Update = function() end
    env.SetItemButtonTextureVertexColor = function(button, r, g, b) button.icon:SetVertexColor(r, g, b) end
    env.SetItemButtonDesaturated = function(button, on) button.icon:SetDesaturated(on) end
    env.UpdateContainerFrameAnchors = function() game.containerAnchors = (game.containerAnchors or 0) + 1 end
    env.ContainerFrameSettingsManager = { GetBagsShown = function() return game.bagWindows or {} end }

    ---------------------------------------------------------------------------
    -- Action bars
    ---------------------------------------------------------------------------
    -- The art pieces of Forever's ActionButtonTemplate (Blizzard_ActionBar
    -- Mainline/ActionButtonTemplate.xml) and its UpdateButtonArt (Mainline/
    -- ActionButtonOverrides.lua, a mixin method copied onto the button).
    local function ActionButtonPieces(button, bar)
        button.bar = bar
        button.icon = button:CreateTexture(nil, "BACKGROUND")
        button.icon.masks = {}
        button.IconMask = button:CreateMaskTexture()
        table.insert(button.icon.masks, button.IconMask)
        button.SlotBackground = button:CreateTexture(nil, "BACKGROUND")
        button.SlotBackground:SetAtlas("UI-HUD-ActionBar-IconFrame-Background")
        button.SlotBackground:SetAllPoints(button)
        button.SlotArt = button:CreateTexture(nil, "BACKGROUND")
        button.SlotArt:SetAtlas("ui-hud-actionbar-iconframe-slot")
        button.SlotArt:SetAllPoints(button)
        button.Flash = button:CreateTexture(nil, "ARTWORK", nil, 1)
        button.Flash:SetAtlas("UI-HUD-ActionBar-IconFrame-Flash", true)
        button.Flash:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.Flash.shown = false
        button.Border = button:CreateTexture(nil, "OVERLAY")
        button.Border:SetAtlas("UI-HUD-ActionBar-IconFrame-Border", true)
        button.Border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.Border.shown = false
        button.Border.blend = "BLEND"
        button:SetPushedAtlas("UI-HUD-ActionBar-IconFrame-Down")
        button:SetHighlightAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        button:SetCheckedAtlas("UI-HUD-ActionBar-IconFrame-Mouseover")
        button.checkedFace.blend = "ADD"
        function button:UpdateButtonArt()
            game.buttonArtUpdates = (game.buttonArtUpdates or 0) + 1
            local barArt = self.bar and not self.bar.hideBarArt
            self.SlotArt:SetShown(barArt)
            self.SlotBackground:SetShown(not barArt)
            local side = barArt and 46 or 51
            self:SetNormalAtlas(barArt and "UI-HUD-ActionBar-IconFrame" or "UI-HUD-ActionBar-IconFrame-AddRow")
            self:SetPushedAtlas(barArt and "UI-HUD-ActionBar-IconFrame-Down" or "UI-HUD-ActionBar-IconFrame-AddRow-Down")
            for _, face in ipairs({ self:GetNormalTexture(), self:GetPushedTexture() }) do
                face:SetDrawLayer("OVERLAY")
                face:SetSize(side, barArt and 45 or 51)
            end
        end
        button:UpdateButtonArt()
        game.buttonArtUpdates = 0
        button:SetNormalTexture("normal")
    end

    local function Bar(name, buttonName, count, horizontal, system, index)
        local bar = EditSystem(New("Frame", name, env.UIParent), system or 0, index)
        bar:SetSize(500, 45)
        bar.points = { { "BOTTOM", env.UIParent, "BOTTOM", 0, 0 } }
        bar.isHorizontal, bar.numRows, bar.numButtonsShowable = horizontal ~= false, 1, count
        bar.settings = { [3] = 100, [2] = count }
        -- As in the game: the stance, pet and possess bars have no Num Icons
        -- setting (Edit Mode answers 0) and no numButtonsShowable.
        if name == "StanceBar" or name == "PetActionBar" or name == "PossessActionBar" then
            bar.settings[2], bar.numButtonsShowable = nil, nil
        end
        bar.actionButtons = {}
        for i = 1, count do
            local holder = New("Frame", name .. "ButtonContainer" .. i, bar)
            holder:SetSize(45, 45)
            holder.points = { { "BOTTOMLEFT", bar, "BOTTOMLEFT", (i - 1) * 47, 0 } }
            holder.protected = true
            local button = New("CheckButton", buttonName .. i, holder)
            button:SetSize(45, 45)
            button.points = { { "CENTER", holder, "CENTER", 0, 0 } }
            button.container, button.action, button.protected = holder, i, true
            button.mouse = true
            button.cooldown = New("Cooldown", nil, button)
            button.SpellCastAnimFrame = New("Frame", nil, button)
            button.HotKey = button:CreateFontString()
            button.HotKey.text = ""
            button:SetNormalTexture("normal")
            ActionButtonPieces(button, bar)
            bar.actionButtons[i] = button
        end
        bar.protected = true
        return bar
    end
    local main = Bar("MainActionBar", "ActionButton", 12, true, 0, 1)
    main.BorderArt = main:CreateTexture()
    main.EndCaps = New("Frame", nil, main)
    main.EndCaps:SetAllPoints(main)
    for _, side in ipairs({ "LeftEndCap", "RightEndCap" }) do
        local cap = EditSystem(New("Frame", side, main.EndCaps), 20, side == "LeftEndCap" and 1 or 2)
        cap:SetSize(154, 95)
        cap.points = { { side == "LeftEndCap" and "RIGHT" or "LEFT", main, side == "LeftEndCap" and "LEFT" or "RIGHT", 0, 0 } }
        cap.Texture = cap:CreateTexture()
        main.EndCaps[side] = cap
    end
    local pages = New("Frame", nil, main)
    pages:SetSize(17, 30)
    pages.points = { { "BOTTOMRIGHT", main, "BOTTOMLEFT", -4, 9 } }
    pages.UpButton = New("Button", nil, pages)
    pages.UpButton:SetSize(17, 14)
    pages.UpButton.points = { { "CENTER", pages, "CENTER", 0, 10 } }
    pages.DownButton = New("Button", nil, pages)
    pages.DownButton:SetSize(17, 14)
    pages.DownButton.points = { { "CENTER", pages, "CENTER", 0, -10 } }
    for _, arrow in ipairs({ pages.UpButton, pages.DownButton }) do
        for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do arrow["Set" .. state .. "Atlas"](arrow, "modern") end
    end
    pages.Text = pages:CreateFontString()
    main.ActionBarPageNumber = pages
    Bar("MultiBarBottomLeft", "MultiBarBottomLeftButton", 12, true, 0, 2)
    Bar("MultiBarBottomRight", "MultiBarBottomRightButton", 12, true, 0, 3)
    Bar("MultiBarRight", "MultiBarRightButton", 12, false, 0, 4)
    Bar("MultiBarLeft", "MultiBarLeftButton", 12, false, 0, 5)
    for i = 5, 7 do Bar("MultiBar" .. i, "MultiBar" .. i .. "Button", 12, true, 0, i + 1) end
    local stance = Bar("StanceBar", "StanceButton", 10, true, 0, 11)
    for i = 4, 10 do stance.actionButtons[i].container.shown = false end
    Bar("PetActionBar", "PetActionButton", 10, true, 0, 12)
    local possess = Bar("PossessActionBar", "PossessButton", 2, true, 0, 13)
    possess.shown = false

    ---------------------------------------------------------------------------
    -- The micro menu
    ---------------------------------------------------------------------------
    local menu = New("Frame", "MicroMenu", env.UIParent)
    menu:SetSize(300, 40)
    menu.points = { { "BOTTOMRIGHT", env.UIParent, "BOTTOMRIGHT", 0, 0 } }
    menu.BorderArt, menu.BackgroundArt = menu:CreateTexture(), menu:CreateTexture()
    function menu:UpdateHelpTicketButtonAnchor() end
    EditSystem(New("Frame", "MicroMenuContainer", env.UIParent), 13)
    local microNames = options.micro or { "CharacterMicroButton", "ProfessionMicroButton", "SpellbookMicroButton",
        "TalentMicroButton", "QuestLogMicroButton", "HousingMicroButton", "GuildMicroButton", "LFDMicroButton",
        "CollectionsMicroButton", "EJMicroButton", "HelpMicroButton", "StoreMicroButton", "MainMenuMicroButton" }
    for i, name in ipairs(microNames) do
        local b = New("Button", name, menu)
        b:SetSize(32, 40)
        b.points = { { "BOTTOMLEFT", menu, "BOTTOMLEFT", (i - 1) * 32, 0 } }
        b.layoutIndex = i
        b.PostAddButtonCallback = function() end
        b.Background, b.PushedBackground = b:CreateTexture(), b:CreateTexture()
        b.tooltipText = name
        b.textureName = name:gsub("MicroButton", "")
        for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight" }) do b["Set" .. state .. "Atlas"](b, "modern-" .. state) end
        b.SetNormal = function(self) self.state = "NORMAL" end
        b.SetPushed = function(self) self.state = "PUSHED" end
        b.UpdateMicroButton = function() end
        if name == "CharacterMicroButton" then
            b.Portrait, b.PortraitMask, b.Shadow, b.PushedShadow = b:CreateTexture(), b:CreateTexture(), b:CreateTexture(), b:CreateTexture()
        end
    end
    env.HousingMicroButton.shown = false
    env.EJMicroButton.shown = false
    env.EJMicroButton.points = {} -- a hidden button the game's layout never placed
    env.HelpOpenWebTicketButton = New("Button", "HelpOpenWebTicketButton", env.UIParent)

    ---------------------------------------------------------------------------
    -- The bag bar
    ---------------------------------------------------------------------------
    local bags = EditSystem(New("Frame", "BagsBar", env.UIParent), 14)
    bags:SetSize(200, 45)
    bags.points = { { "BOTTOMRIGHT", env.UIParent, "BOTTOMRIGHT", 0, 40 } }
    bags.BorderArt = bags:CreateTexture()
    local function BagButton(name, id, icon)
        local b = New("ItemButton", name, bags)
        b:SetSize(45, 45)
        b.points = { { "RIGHT", bags, "RIGHT", 0, 0 } }
        b.id, b.bagIcon = id, icon
        function b:GetID() return self.id end
        b.icon = b:CreateTexture()
        b.IconBorder, b.CircleMask = b:CreateTexture(), b:CreateMaskTexture()
        b.SlotHighlightTexture = b:CreateTexture()
        b.Count = b:CreateFontString()
        b:SetNormalAtlas("bags")
        b:SetPushedAtlas("bags")
        b:SetHighlightAtlas("bags")
        rawset(b, "UpdateTextures", function(self)
            if self.bagIcon then self.icon:SetTexture(self.bagIcon) end
            self:GetNormalTexture():SetAtlas("bags")
            self.SlotHighlightTexture:SetAtlas("bags")
        end)
        return b
    end
    local pack = BagButton("MainMenuBarBackpackButton", 0, "backpack-icon")
    pack.FreeSlots = pack:CreateFontString()
    for i = 0, 3 do BagButton("CharacterBag" .. i .. "Slot", 20 + i) end
    BagButton("CharacterReagentBag0Slot", 24)
    if options.keyRing ~= false then BagButton("KeyRingButton", -2, "keyring-icon") end
    env.BagBarExpandToggle = New("Button", "BagBarExpandToggle", bags)

    ---------------------------------------------------------------------------
    -- XP and reputation
    ---------------------------------------------------------------------------
    local function Track(name, index, xp)
        local track = EditSystem(New("Frame", name, env.UIParent), 15, index)
        track:SetSize(804, 11)
        track.points = { { "BOTTOM", env.UIParent, "BOTTOM", 0, 0 } }
        track.BarFrameTexture = track:CreateTexture()
        track.bars = {}
        local meter = New("Frame", nil, track)
        meter:SetSize(800, 10)
        meter.points = { { "BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1 } }
        meter.StatusBar = New("StatusBar", nil, meter)
        meter.StatusBar:SetSize(800, 10)
        meter.StatusBar.points = { { "RIGHT", meter, "RIGHT", 0, 0 } }
        local gauge = meter.StatusBar
        function gauge:SetStatusBarTexture(path) self.barFile = path end
        function gauge:GetStatusBarTexture() return self.fillTexture end
        function gauge:SetStatusBarColor(r, g, b) self.barColor = { r, g, b } end
        function gauge:SetBarTexture(atlas) self.fillTexture.atlas = atlas end
        gauge.fillTexture = gauge:CreateTexture()
        gauge.Background = gauge:CreateTexture()
        if xp then
            meter.ExhaustionTick = New("Button", nil, meter)
            meter.ExhaustionTick.Normal, meter.ExhaustionTick.Highlight = meter.ExhaustionTick:CreateTexture(), meter.ExhaustionTick:CreateTexture()
            function meter.ExhaustionTick:UpdateTickPosition() end
            meter.ExhaustionLevelFillBar = meter:CreateTexture()
            meter.ExhaustionLevelFillBar.shown = false
            function meter:UpdateStatusBarTextures() end
        else
            meter.factionID = 72
        end
        track.bars[1] = meter
        track.shown = xp or options.reputation == true
        meter.shown = track.shown
        return track
    end
    Track("MainStatusTrackingBarContainer", 1, true)
    Track("SecondaryStatusTrackingBarContainer", 2, false)

    ---------------------------------------------------------------------------
    -- The cast bar, Edit Mode's manager, the map
    ---------------------------------------------------------------------------
    local cast = EditSystem(New("StatusBar", "PlayerCastingBarFrame", env.UIParent), 16)
    cast:SetSize(200, 12)
    cast.points = { { "BOTTOM", env.UIParent, "BOTTOM", 0, 160 } }
    cast.shown = false
    function cast:IsAttachedToPlayerFrame() return false end
    -- The shaman's totem bar (since 70425 one of Edit Mode's bottom bars,
    -- stacked above Action Bar 1): hidden, as for every class until level 20.
    local totem = EditSystem(New("Frame", "MultiCastActionBarFrame", env.UIParent), 17)
    totem:SetSize(230, 38)
    totem.points = { { "BOTTOMLEFT", main, "BOTTOMLEFT", 30, 49 } }
    totem.shown = false
    local editor = New("Frame", "EditModeManagerFrame", env.UIParent)
    function editor:IsEditModeActive() return game.editing end
    function editor:GetActiveLayoutInfo() return { layoutName = game.layoutName or "EraUI" } end
    function editor:GetActiveLayoutSystemInfo(_, _) return nil end
    function editor:UpdateSystemAnchorInfo(frame)
        local p = frame.points[1]
        local info = { point = p[1], relativeTo = p[2] and p[2]:GetName(), relativePoint = p[3], offsetX = p[4] * frame.scale,
            offsetY = p[5] * frame.scale }
        local before = frame.systemInfo.anchorInfo
        frame.systemInfo.anchorInfo = info
        frame.default = false
        game.anchorWrites = (game.anchorWrites or 0) + 1
        return not (before.point == info.point and before.offsetX == info.offsetX and before.offsetY == info.offsetY)
    end
    function editor:SaveLayouts() game.layoutSaves = (game.layoutSaves or 0) + 1 end
    function editor:UpdateActionBarPositions() end
    function editor:OnSystemSettingChange(frame, setting, value) game.settingWrites = { frame, setting, value } end
    editor.SaveChangesButton, editor.RevertAllChangesButton = New("Button", nil, editor), New("Button", nil, editor)
    editor.SaveChangesButton.enabled, editor.RevertAllChangesButton.enabled = false, false
    local dialog = New("Frame", "EditModeSystemSettingsDialog", env.UIParent)
    dialog.shown = false
    dialog.Buttons = { RevertChangesButton = New("Button", nil, dialog) }
    function dialog:UpdateDialog() end
    env.WorldMapFrame = New("Frame", "WorldMapFrame", env.UIParent)
    env.WorldMapFrame.shown = false
    env.MinimapCluster = New("Frame", "MinimapCluster", env.UIParent)
    env.MinimapCluster.ZoneTextButton = New("Button", nil, env.MinimapCluster)

    ---------------------------------------------------------------------------
    -- EraUI's side
    ---------------------------------------------------------------------------
    local ns = { db = {}, DB_DEFAULTS = {}, modules = {} }
    function ns.RegisterModule(key, module)
        module.key = key
        ns.modules[#ns.modules + 1] = module
    end
    -- The engine's queue: one pass on the next frame, after a fight if in one.
    function ns.QueueApply()
        game.queued = game.queued + 1
        game.passWanted = true
    end
    function ns.MirrorSave() game.saves = game.saves + 1 end
    function ns.ThemeTexture(texture, key) texture.theme = key end
    function ns.DarkCloseButton(button) button.darkened = true end
    function ns.DarkNativeButton(button) button.darkened = true end
    function ns.RefreshOptionsWindow() game.optionsRefreshed = (game.optionsRefreshed or 0) + 1 end
    function ns.LayoutWritable() return game.writable ~= false end
    function ns.ClassicLayoutActive() return game.classicLayout == true end
    game.ns = ns
    game.settings = { enabled = true, gryphons = true, advancedCastBar = false, darkMode = false, hideKeybindText = false }
    local E = { Classic = ns, settings = game.settings }
    function E:GetSetting(key) return self.settings[key] end
    game.E = E

    local FILES = { "Look/Base.lua", "Look/BarArt.lua", "Look/BandShape.lua", "Look/Band.lua", "Look/BandMicro.lua",
        "Look/BandBags.lua", "Look/BandStrips.lua", "Look/CastClearance.lua", "Look/BandPins.lua", "Look/BandWatch.lua",
        "Look/BandModule.lua", "Look/ButtonStyle.lua", "Look/CastAnim.lua", "Look/PageArrows.lua", "Look/EmptySlots.lua" }
    function game.Load()
        for _, file in ipairs(FILES) do assert(loadfile(file, "t", env))("EraUI", E) end
        game.Look = E.Look
        return E.Look
    end

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
    end
    function game.Fire(event, ...)
        for _, w in ipairs(game.frames) do
            if w.events[event] and w.scripts.OnEvent then w.scripts.OnEvent(w, event, ...) end
        end
    end
    -- Runs every OnUpdate (the shared ticker) for a span of time, in steps.
    function game.Tick(seconds, step)
        step = step or 0.05
        local done = 0
        while done < seconds - 1e-9 do
            game.now = game.now + step
            done = done + step
            for _, w in ipairs(game.frames) do
                if w.scripts.OnUpdate and w:IsShown() then w.scripts.OnUpdate(w, step) end
            end
            local due = {}
            for i = #game.timers, 1, -1 do
                if game.timers[i].at <= game.now then due[#due + 1] = table.remove(game.timers, i) end
            end
            for i = #due, 1, -1 do due[i].fn() end
            if game.passWanted and not game.combat then
                game.passWanted = false
                game.Pass()
            end
        end
    end
    return game
end

return Mock
