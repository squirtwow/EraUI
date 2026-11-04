-- A mock of WoW Forever for the quest area's tests (Tools/TestQuestLog.lua,
-- TestQuestNavigation.lua, TestQuestMapPane.lua, TestQuestTracker.lua).
-- Not a test itself. It models what Look/Quest*.lua touch:
--   * frames, buttons, check buttons, sliders, scroll frames, textures and
--     font strings, with anchors, sizes, scales and a small layout solver
--     (two anchors on an axis set its size; one anchor and a size place
--     it), scripts, hooks (hooksecurefunc) and events;
--   * the game's quest log (C_QuestLog and the older globals) over a list
--     of headers and quests the test writes, with selection, watching,
--     party members, rewards, timers and abandoning;
--   * the objective tracker (the whole tracker's header, its sections and
--     their blocks, lines and item buttons, with the game's own
--     SetStringText, SetHeader, AddBlock, SetCollapsed and Update);
--   * the world map's quest pane (the list with its header and title pools,
--     the details with their text, rewards and SetRewardsHeight);
--   * the quest micro button, the minimap's zone button, the world map,
--     the game menu, the red error text, the quest-log CVar, chat links,
--     tooltip data (C_TooltipInfo), sounds, timers and combat;
--   * EraUI's side: the engine's registry and pass, the shared window
--     manager (it puts a window in its slot on every show), Escape, the
--     secure pad, the micro buttons' pressed state, Dark Mode's hand-overs.
-- The game's own objects are sealed: a key written on one by EraUI fails
-- the test (hooksecurefunc's own wrapper excepted). GameTooltip and
-- MouseIsOver don't exist (reading either fails), and every key binding
-- call fails.
-- Usage: local Mock = dofile("Tools/QuestMockGame.lua"); local game = Mock.New(); game.Load()
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
        darkened = {}, registered = {}, escapes = {}, pads = {}, follows = {}, missing = {}, microRefreshes = 0,
        optionsRefreshes = 0, passes = 0, saves = 0, chat = {}, chatOpen = false, modified = {}, shift = false,
        quickBind = false, cvars = { questLogOpen = "0" }, cvarWrites = {}, slotX = 0, gameMicroClicks = 0,
        headerClicks = 0, rewardHeights = {}, rectUpdates = 0, expanded = {}, pushes = {}, hookCounts = {},
        settings = { enabled = true, darkMode = false } }
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
    function Proto:SetShown(on)
        local s = S(self)
        on = on and true or false
        if s.shown == on then return end
        local parentVisible = s.parent == nil or Visible(s.parent)
        s.shown = on
        if parentVisible and not REGIONS[s.kind] then
            if not on then LoseMouse(self) end
            Run(self, on and "OnShow" or "OnHide")
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

    ---------------------------------------------------------------------------
    -- Words, fonts and colours the game defines
    ---------------------------------------------------------------------------
    for name, words in pairs({ QUEST_LOG = "Quest Log", QUESTS = "Quests", ALL = "All", TRACK_QUEST = "Track Quest",
        ABANDON_QUEST = "Abandon Quest", SHARE_QUEST = "Share Quest", EXIT = "Exit", CLOSE = "Close",
        ABANDON_QUEST_ABBREV = "Abandon", SHARE_QUEST_ABBREV = "Share", TRACK_QUEST_ABBREV = "Track",
        SHOW_MAP = "Show Map", FAILED = "Failed", COMPLETE = "Complete", DAILY = "Daily", WEEKLY = "Weekly",
        GROUP = "Group", TIME_REMAINING = "Time Remaining:", REQUIRED_MONEY = "Required Money:",
        QUEST_DESCRIPTION = "Description", QUEST_REWARDS = "Rewards", REWARD_CHOICES = "Choose one of the following rewards:",
        REWARD_ITEMS = "You will also receive:", REWARD_ITEMS_ONLY = "You will receive:", REWARD_XP = "Experience",
        PARTY_QUEST_STATUS_ON = "Party members that are on this quest:", ERR_NOT_IN_COMBAT = "You can't do that while in combat",
        QUESTLOG_NO_QUESTS_TEXT = "You have no quests." }) do
        env[name] = words
    end
    for _, font in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontHighlight", "GameFontHighlightSmall",
        "GameFontDisable", "GameFontNormalLarge", "NumberFontNormal", "QuestFont_Large", "QuestFont",
        "QuestFontNormalSmall", "ObjectiveTrackerHeaderFont" }) do
        env[font] = { fontName = font }
    end
    env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
    env.QuestDifficultyColors = { header = { r = 0.75, g = 0.75, b = 0.75 } }
    env.OBJECTIVE_TRACKER_COLOR = { Normal = { r = 0.8, g = 0.8, b = 0.8 }, Failed = { r = 0.75, g = 0.1, b = 0.1 },
        Complete = { r = 0.6, g = 0.6, b = 0.6 }, Header = { r = 0.75, g = 0.61, b = 0 } }
    env.ITEM_QUALITY_COLORS = { [2] = { r = 0.12, g = 1, b = 0 }, [3] = { r = 0, g = 0.44, b = 0.87 } }
    env.SOUNDKIT = setmetatable({}, { __index = function(_, key) return "sound:" .. key end })
    env.PlaySound = function(kit) game.sounds[#game.sounds + 1] = kit end
    env.Enum = { QuestWatchType = { Automatic = 0, Manual = 1 }, QuestFrequency = { Default = 0, Daily = 1, Weekly = 2 } }
    env.InCombatLockdown = function() return game.combat end
    env.GetTime = function() return game.now end
    env.C_Timer = { After = function(seconds, fn) game.timers[#game.timers + 1] = { at = game.now + seconds, fn = fn } end }
    env.IsLoggedIn = function() return true end

    ---------------------------------------------------------------------------
    -- The game's own UI
    ---------------------------------------------------------------------------
    local root = New("Frame", "UIParent")
    st[root].fixed = { 0, 0, 1920, 1080 }
    st[root].width, st[root].height = 1920, 1080
    env.UIErrorsFrame = New("Frame", "UIErrorsFrame", root)
    env.GameMenuFrame = New("Frame", "GameMenuFrame", root)
    st[env.GameMenuFrame].shown = false
    env.WorldMapFrame = New("Frame", "WorldMapFrame", root)
    st[env.WorldMapFrame].shown = false
    env.HideUIPanel = function(frame)
        game.hiddenPanels = (game.hiddenPanels or 0) + 1
        frame:Hide()
    end
    env.ShowUIPanel = function(frame) frame:Show() end
    env.ToggleWorldMap = function() env.WorldMapFrame:SetShown(not env.WorldMapFrame:IsShown()) end
    env.MinimapCluster = New("Frame", "MinimapCluster", root)
    local zone = New("Button", nil, env.MinimapCluster)
    rawset(env.MinimapCluster, "ZoneTextButton", zone)
    st[zone].scripts.OnClick = function() env.ToggleWorldMap() end
    -- The quest micro button with its own click (the map's quest panel).
    local micro = New("Button", "QuestLogMicroButton", root)
    st[micro].width, st[micro].height = 28, 38
    rawset(micro, "tooltipText", "Quest Log (L)")
    st[micro].scripts.OnClick = function()
        game.gameMicroClicks = game.gameMicroClicks + 1
        env.WorldMapFrame:Show()
    end
    rawset(micro, "UpdateMicroButton", function(self)
        self:SetButtonState(env.WorldMapFrame:IsShown() and "PUSHED" or "NORMAL")
    end)
    game.ownMicroClick = st[micro].scripts.OnClick

    -- The objective tracker: the whole tracker's header, sections, blocks.
    local function TrackerHeader(parent, kind)
        local header = New("Frame", nil, parent)
        st[header].width, st[header].height = 260, 26
        for _, key in ipairs({ "Background", "Shine", "Glow" }) do
            local art = New("Texture", nil, header, key == "Glow" and "OVERLAY" or "BACKGROUND")
            st[art].atlas = kind .. "-" .. key:lower()
            rawset(header, key, art)
        end
        local text = New("FontString", nil, header, "ARTWORK")
        st[text].font = env.ObjectiveTrackerHeaderFont
        rawset(header, "Text", text)
        local button = New("Button", nil, header)
        st[button].width, st[button].height = 16, 16
        for _, face in ipairs({ "Normal", "Pushed" }) do
            local art = New("Texture", nil, button, "ARTWORK")
            st[art].atlas = kind .. "-collapse-" .. face:lower()
            st[button].faces[face] = art
        end
        rawset(header, "MinimizeButton", button)
        rawset(header, "SetCollapsed", function(self, collapsed)
            local suffix = collapsed and "expand" or "collapse"
            self.MinimizeButton:GetNormalTexture():SetAtlas(kind .. "-" .. suffix, true)
            self.MinimizeButton:GetPushedTexture():SetAtlas(kind .. "-" .. suffix .. "-pressed", true)
        end)
        return header
    end

    local tracker = New("Frame", "ObjectiveTrackerFrame", root)
    st[tracker].width, st[tracker].height = 260, 600
    rawset(tracker, "Header", TrackerHeader(tracker, "all"))
    rawset(tracker, "isCollapsed", false)
    rawset(tracker, "ShouldShowHeader", function() return true end)
    rawset(tracker, "Update", function(self)
        game.trackerUpdates = (game.trackerUpdates or 0) + 1
        if self:ShouldShowHeader() then self.Header:Show() end
    end)
    rawset(tracker, "SetCollapsed", function(self, collapsed)
        rawset(self, "isCollapsed", collapsed)
        self.Header:SetCollapsed(collapsed)
        self:Update()
    end)
    local sections = {}
    for _, name in ipairs({ "QuestObjectiveTracker", "CampaignQuestObjectiveTracker", "AchievementObjectiveTracker" }) do
        local module = New("Frame", name, tracker)
        st[module].width, st[module].height = 260, 200
        rawset(module, "Header", TrackerHeader(module, "section"))
        rawset(module, "usedBlocks", {})
        rawset(module, "isCollapsed", false)
        rawset(module, "IsCollapsed", function(self) return self.isCollapsed end)
        rawset(module, "SetCollapsed", function(self, collapsed)
            rawset(self, "isCollapsed", collapsed)
            self.Header:SetCollapsed(collapsed)
        end)
        rawset(module, "AddBlock", function(self, block)
            local kind = self.usedBlocks[block.template]
            if not kind then
                kind = {}
                self.usedBlocks[block.template] = kind
            end
            kind[block.id] = block
            return true
        end)
        rawset(module, "OnBlockHeaderClick", function(_, block, mouse)
            game.headerClicks = game.headerClicks + 1
            game.lastHeaderClick = { block, mouse }
            if mouse ~= "RightButton" and not game.modified.CHATLINK and not game.modified.QUESTWATCHTOGGLE then
                env.WorldMapFrame:Show()
            end
        end)
        sections[#sections + 1] = module
    end
    rawset(tracker, "modules", sections)

    -- A tracker block for a quest: its title, objective lines and maybe an
    -- item button, added through the section's own AddBlock.
    function game.Block(module, id, title, objectives, withItem)
        local was = building
        building = true
        local block = New("Frame", nil, module)
        rawset(block, "id", id)
        rawset(block, "template", "QuestTemplate")
        rawset(block, "usedLines", {})
        local headerText = New("FontString", nil, block, "ARTWORK")
        rawset(block, "HeaderText", headerText)
        rawset(block, "SetStringText", function(_, text, words, _, style)
            text:SetText(words)
            style = style or env.OBJECTIVE_TRACKER_COLOR.Normal
            if rawget(text, "colorStyle") ~= style then
                text:SetTextColor(style.r, style.g, style.b)
                rawset(text, "colorStyle", style)
            end
            return text:GetHeight()
        end)
        rawset(block, "SetHeader", function(self, words)
            self:SetStringText(self.HeaderText, words, nil, env.OBJECTIVE_TRACKER_COLOR.Header)
        end)
        rawset(block, "AddObjective", function(self, key, words, style)
            local line = self.usedLines[key]
            if not line then
                line = New("Frame", nil, self)
                rawset(line, "Text", New("FontString", nil, line, "ARTWORK"))
                rawset(line, "Dash", New("FontString", nil, line, "ARTWORK"))
                self.usedLines[key] = line
            end
            self:SetStringText(line.Text, words, nil, style)
            return line
        end)
        rawset(block, "ForEachUsedLine", function(self, fn)
            for key, line in pairs(self.usedLines) do
                if fn(line, key) then return end
            end
        end)
        if withItem then
            local item = New("Button", nil, block)
            st[item].width, st[item].height = 26, 26
            local ring = New("Texture", nil, item, "ARTWORK")
            st[ring].atlas, st[ring].width, st[ring].height = "questitem-frame", 42, 42
            st[item].faces.Normal = ring
            local pressed = New("Texture", nil, item, "ARTWORK")
            st[pressed].atlas = "questitem-frame"
            st[item].faces.Pushed = pressed
            rawset(block, "ItemButton", item)
        end
        if game.loaded then game.Seal() end
        building = was
        block:SetHeader(title)
        for i, words in ipairs(objectives or {}) do
            local style = type(words) == "table" and words[2] or nil
            block:AddObjective(i, type(words) == "table" and words[1] or words, style)
        end
        module:AddBlock(block)
        return block
    end

    -- The map's quest list background.
    env.QuestMapFrame = New("Frame", "QuestMapFrame", root)
    local map = env.QuestMapFrame
    map:SetPoint("TOPLEFT", root, "TOPLEFT", 1000, -100)
    st[map].width, st[map].height = 330, 600
    local quests = New("Frame", nil, map)
    quests:SetPoint("TOPLEFT", map, "TOPLEFT", 0, 0)
    st[quests].width, st[quests].height = 308, 502
    rawset(map, "QuestsFrame", quests)
    local list = New("ScrollFrame", "QuestScrollFrame", quests)
    rawset(quests, "ScrollFrame", list)
    list:SetPoint("TOPLEFT", quests, "TOPLEFT", 0, -29)
    st[list].width, st[list].height = 300, 450
    local listBack = New("Texture", nil, list, "BACKGROUND")
    st[listBack].atlas = "QuestLog-main-background"
    rawset(list, "Background", listBack)
    local edge = New("Texture", nil, list, "ARTWORK")
    st[edge].alpha = 0
    rawset(list, "Edge", edge)
    local border = New("Frame", nil, list)
    New("Texture", nil, border, "BORDER")
    New("Texture", nil, border, "BORDER")
    rawset(list, "BorderFrame", border)
    rawset(list, "UpdateBackground", function(self)
        self.Background:SetAtlas(game.emptyList and "QuestLog-empty-quest-background" or "QuestLog-main-background", true)
    end)
    local function Pool(make)
        local pool = { free = {}, active = {}, made = 0 }
        function pool:Acquire()
            local button = table.remove(self.free) or make()
            self.active[button] = true
            button:Show()
            return button
        end
        function pool:ReleaseAll()
            for button in pairs(self.active) do
                button:Hide()
                self.free[#self.free + 1] = button
            end
            self.active = {}
        end
        function pool:EnumerateActive() return pairs(self.active) end
        return pool
    end
    local listContents = New("Frame", nil, list)
    game.headerMade = 0
    local headers = Pool(function()
        local was = building
        building = true
        local button = New("Button", nil, listContents)
        st[button].width, st[button].height = 289, 22
        New("Texture", nil, button, "BACKGROUND")
        st[button].faces.Normal = New("Texture", nil, button, "ARTWORK")
        st[button].faces.Highlight = New("Texture", nil, button, "HIGHLIGHT")
        local collapse = New("Button", nil, button)
        rawset(button, "CollapseButton", collapse)
        st[collapse].mouse = true
        local words = New("FontString", nil, button, "ARTWORK")
        rawset(button, "ButtonText", words)
        st[button].label = words
        game.headerMade = game.headerMade + 1
        if game.loaded then game.Seal() end
        building = was
        return button
    end)
    local titles = Pool(function()
        local was = building
        building = true
        local button = New("Button", nil, listContents)
        st[button].width, st[button].height = 290, 16
        for _, key in ipairs({ "Text", "TagText" }) do rawset(button, key, New("FontString", nil, button, "ARTWORK")) end
        rawset(button, "StorylineTexture", New("Texture", nil, button, "ARTWORK"))
        rawset(button, "TaskIcon", New("Texture", nil, button, "ARTWORK"))
        local band = New("Texture", nil, button, "BORDER")
        st[band].atlas = "questlog-quest-glow-yellow"
        rawset(button, "HighlightTexture", band)
        local box = New("Frame", nil, button)
        New("Texture", nil, box, "BACKGROUND")
        rawset(box, "CheckMark", New("Texture", nil, box, "ARTWORK"))
        New("Texture", nil, box, "HIGHLIGHT")
        rawset(button, "Checkbox", box)
        st[button].scripts.OnLeave = function(self) self.Text:SetTextColor(0.75, 0.61, 0) end
        if game.loaded then game.Seal() end
        building = was
        return button
    end)
    rawset(list, "headerFramePool", headers)
    rawset(list, "titleFramePool", titles)

    -- The details: text, rewards, the game's own re-clip.
    local details = New("Frame", nil, quests)
    rawset(quests, "DetailsFrame", details)
    rawset(map, "DetailsFrame", details)
    details:SetPoint("TOPRIGHT", quests, "TOPRIGHT", 0, -1)
    st[details].width, st[details].height = 308, 502
    rawset(details, "Bg", New("Texture", nil, details, "BACKGROUND"))
    -- Camelot's themed backdrop (shown for some quests, above the floor).
    rawset(details, "SealMaterialBG", New("Texture", nil, details, "BORDER"))
    local detailBorder = New("Frame", nil, details)
    New("Texture", nil, detailBorder, "BORDER")
    rawset(details, "BorderFrame", detailBorder)
    local back = New("Frame", nil, details)
    New("Texture", nil, back, "BORDER")
    rawset(details, "BackFrame", back)
    local text = New("ScrollFrame", "QuestMapDetailsScrollFrame", details)
    text:SetPoint("TOPLEFT", details, "TOPLEFT", 5, -43)
    st[text].width, st[text].height = 298, 430
    rawset(details, "ScrollFrame", text)
    local contents = New("Frame", nil, text)
    st[contents].width, st[contents].height = 298, 1100
    rawset(text, "Contents", contents)
    text:SetScrollChild(contents)
    local info = New("Frame", nil, contents)
    game.detailTitle = New("FontString", nil, info, "ARTWORK")
    game.detailBody = New("FontString", nil, info, "ARTWORK")
    local inner = New("Frame", nil, info)
    game.detailDeep = New("FontString", nil, inner, "ARTWORK")
    local rewardButton = New("Button", nil, info)
    game.detailButtonText = New("FontString", nil, rewardButton, "ARTWORK")
    local container = New("Frame", nil, details)
    rawset(details, "RewardsFrameContainer", container)
    local rewards = New("Frame", nil, container)
    st[rewards].width, st[rewards].height = 307, 160
    rawset(container, "RewardsFrame", rewards)
    for _, key in ipairs({ "Top", "Bottom", "Background" }) do rawset(rewards, key, New("Texture", nil, rewards, "BORDER")) end
    rawset(rewards, "Label", New("FontString", nil, rewards, "ARTWORK"))
    rawset(details, "SetRewardsHeight", function(_, height)
        game.rewardHeights[#game.rewardHeights + 1] = height
    end)
    rawset(details, "AbandonButton", New("Button", nil, details))
    game.ownAbandon = function() end
    st[details.AbandonButton].scripts.OnClick = game.ownAbandon
    st[details].shown = false

    -- The game's own list and details code.
    function game.ListPainted()
        headers:ReleaseAll()
        titles:ReleaseAll()
        for index, entry in ipairs(game.log) do
            if type(entry) == "table" then
                local button = headers:Acquire()
                rawset(button, "questLogIndex", index)
                button.ButtonText:SetText(entry.header)
            else
                local quest = game.quests[entry]
                local button = titles:Acquire()
                rawset(button, "questID", entry)
                rawset(button, "questLogIndex", index)
                rawset(button, "info", { questID = entry, difficultyLevel = quest.difficultyLevel })
                button.Text:SetText(quest.title)
                button.Text:SetTextColor(0.75, 0.61, 0)
            end
        end
    end
    env.QuestLogQuests_Update = function() game.ListPainted() end
    env.QuestMapFrame_ShowQuestDetails = function(questID)
        game.detailQuest = questID
        for _, words in ipairs({ game.detailTitle, game.detailBody, game.detailDeep, game.detailButtonText }) do
            words:SetText("words")
            words:SetTextColor(1, 1, 1)
        end
        details:Show()
    end

    ---------------------------------------------------------------------------
    -- The quest log
    ---------------------------------------------------------------------------
    -- game.log: headers ({ header = "Title", collapsed, sortKey }) and quest
    -- IDs; game.quests[id]: { title, level, difficultyLevel, ... }.
    game.log, game.quests = {}, {}
    game.party, game.partyOn, game.names = 0, {}, {}
    game.money, game.level, game.maxQuests = 1000, 10, 20
    game.canUnwatch, game.inGroup = true, false
    local function QuestAt(index)
        local entry = game.log[index]
        if type(entry) == "number" then return entry, game.quests[entry] end
        return nil
    end
    local function IndexOf(questID)
        for index, entry in ipairs(game.log) do if entry == questID then return index end end
        return 0
    end
    game.IndexOf = IndexOf
    local log = {}
    env.C_QuestLog = log
    function log.GetNumQuestLogEntries()
        local quests = 0
        for _, entry in ipairs(game.log) do if type(entry) == "number" then quests = quests + 1 end end
        return #game.log, quests
    end
    function log.GetMaxNumQuestsCanAccept() return game.maxQuests end
    function log.GetInfo(index)
        local entry = game.log[index]
        if type(entry) == "table" then
            return { isHeader = true, title = entry.header, questLogIndex = index, isCollapsed = entry.collapsed == true,
                headerSortKey = entry.sortKey }
        end
        local questID, quest = QuestAt(index)
        if not questID then return nil end
        return { questID = questID, title = quest.title, level = quest.level, difficultyLevel = quest.difficultyLevel,
            questLogIndex = index, isHidden = quest.hidden, isTask = quest.task, isBounty = quest.bounty,
            frequency = quest.frequency, suggestedGroup = quest.group or 0, isHeader = false }
    end
    function log.GetLogIndexForQuestID(questID) return IndexOf(questID) end
    function log.GetSelectedQuest() return game.selected or 0 end
    function log.SetSelectedQuest(questID) game.selected = questID end
    function log.IsFailed(questID) return game.quests[questID] and game.quests[questID].failed == true end
    function log.IsComplete(questID) return game.quests[questID] and game.quests[questID].complete == true end
    function log.GetQuestTagInfo(questID)
        local quest = game.quests[questID]
        if quest and quest.tag then return { tagName = quest.tag } end
        return nil
    end
    function log.GetQuestWatchType(questID)
        return game.quests[questID] and game.quests[questID].watched and env.Enum.QuestWatchType.Manual or nil
    end
    function log.AddQuestWatch(questID, kind)
        game.quests[questID].watched = true
        game.lastWatchKind = kind
    end
    function log.RemoveQuestWatch(questID) game.quests[questID].watched = false end
    function log.IsUnitOnQuest(unit, questID)
        local on = game.partyOn[questID] and game.partyOn[questID][unit]
        if on == "error" then error("not available") end
        return on
    end
    function log.IsPushableQuest(questID) return game.quests[questID] and game.quests[questID].pushable end
    function log.GetRequiredMoney(questID) return game.quests[questID] and game.quests[questID].money or 0 end
    function log.SetAbandonQuest() game.abandonSet = game.selected end
    function log.GetAbandonQuestName()
        local quest = game.quests[game.abandonSet or 0]
        return quest and quest.title
    end
    function log.GetAbandonQuestItems()
        local quest = game.quests[game.abandonSet or 0]
        return quest and quest.abandonItems or {}
    end
    function log.GetQuestDifficultyLevel(questID)
        local quest = game.quests[questID]
        if quest and quest.difficultyError then error("unavailable") end
        return quest and quest.difficultyLevel
    end
    env.QuestUtil = { CanRemoveQuestWatch = function() return game.canUnwatch end }
    env.ExpandQuestHeader = function(index)
        game.expanded[#game.expanded + 1] = index
        game.log[index].collapsed = false
    end
    env.GetQuestLogQuestText = function(index)
        local _, quest = QuestAt(index)
        if not quest then return nil end
        return quest.description, quest.objectivesText
    end
    env.GetQuestLogTimeLeft = function()
        local quest = game.quests[game.selected or 0]
        return quest and quest.timeLeft
    end
    env.GetNumQuestLeaderBoards = function(index)
        local _, quest = QuestAt(index)
        return quest and quest.board and #quest.board or 0
    end
    env.GetQuestLogLeaderBoard = function(i, index)
        local _, quest = QuestAt(index)
        local row = quest and quest.board[i]
        if not row then return nil end
        return row[1], row[2], row[3]
    end
    local function RewardList(questID, kind)
        local quest = game.quests[questID]
        return quest and quest[kind] or {}
    end
    env.GetNumQuestLogChoices = function(questID, includeCurrencies)
        game.choiceCurrencies = includeCurrencies
        return #RewardList(questID, "choices")
    end
    env.GetNumQuestLogRewards = function(questID) return #RewardList(questID, "rewards") end
    env.GetQuestLogRewardMoney = function(questID) return game.quests[questID] and game.quests[questID].rewardMoney or 0 end
    env.GetQuestLogRewardXP = function(questID) return game.quests[questID] and game.quests[questID].xp or 0 end
    local function Reward(kind)
        return function(i, questID)
            local item = RewardList(questID, kind)[i]
            if not item then return nil end
            return item.name, item.texture, item.count, item.quality, true, item.itemID
        end
    end
    env.GetQuestLogChoiceInfo = Reward("choices")
    env.GetQuestLogRewardInfo = Reward("rewards")
    env.GetQuestLogItemLink = function(kind, i, questID) return "|Hitem:" .. kind .. i .. ":" .. questID .. "|h" end
    env.GetQuestLink = function(questID) return "|Hquest:" .. questID .. "|h" end
    env.QuestLogPushQuest = function(index) game.pushes[#game.pushes + 1] = index end
    env.GetMoney = function() return game.money end
    env.GetNumSubgroupMembers = function() return game.party end
    env.IsInGroup = function() return game.inGroup end
    env.UnitName = function(unit) return game.names[unit] end
    env.UnitLevel = function() return game.level end
    env.UnitQuestTrivialLevelRange = function() return game.greenRange end
    env.IsModifiedClick = function(action) return game.modified[action] == true end
    env.IsShiftKeyDown = function() return game.shift end
    env.SecondsToTime = function(seconds) return seconds .. " sec" end
    env.BreakUpLargeNumbers = function(amount)
        local text = tostring(amount)
        local done = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return (done:gsub("^,", ""))
    end
    env.C_CurrencyInfo = { GetCoinTextureString = function(amount) return amount .. "c" end }
    env.C_Item = { GetItemNameByID = function(itemID) return game.itemNames and game.itemNames[itemID] end }
    env.StaticPopup_Show = function(which, a, b) game.popups[#game.popups + 1] = { "show", which, a, b } end
    env.StaticPopup_Hide = function(which) game.popups[#game.popups + 1] = { "hide", which } end
    env.C_CVar = {
        GetCVar = function(name) return game.cvars[name] end,
        SetCVar = function(name, value)
            game.cvarWrites[#game.cvarWrites + 1] = { name, value }
            game.cvars[name] = value
        end,
    }
    env.C_TooltipInfo = {
        GetQuestLogItem = function(kind, index, questID)
            game.tipAsked = { kind, index, questID }
            return { lines = { { leftText = "Tip of " .. kind .. index, leftColor = { r = 0, g = 0.44, b = 0.87 } },
                { leftText = "Binds when picked up" } } }
        end,
    }
    env.ChatFrameUtil = { InsertLink = function(link)
        if not game.chatOpen then return false end
        game.chat[#game.chat + 1] = link
        return true
    end }
    env.KeybindFrames_InQuickKeybindMode = function() return game.quickBind end

    ---------------------------------------------------------------------------
    -- EraUI's side: the engine, the window manager, Escape, the pads, Dark Mode
    ---------------------------------------------------------------------------
    local ns = { db = options.db or {}, DB_DEFAULTS = {}, modules = {}, PANE_SHADE = 0.9 }
    function ns.RegisterModule(key, module)
        module.key = key
        ns.modules[#ns.modules + 1] = module
    end
    function ns.ApplyAll()
        game.passes = game.passes + 1
        if game.combat then
            game.passWanted = true
            return
        end
        game.Pass()
    end
    function ns.RefreshOptionsWindow() game.optionsRefreshes = game.optionsRefreshes + 1 end
    function ns.MirrorSave() game.saves = game.saves + 1 end
    -- The shared window manager: on every show the window goes to its slot.
    function ns.RegisterClassicWindow(frame, shares)
        game.registered[#game.registered + 1] = { frame = frame, shares = shares }
        frame:HookScript("OnShow", function(self)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", game.slotX, -104)
        end)
    end
    env.UISpecialFrames = { "GameMenuFrame" }
    function ns.CloseOnEscape(frame, closer)
        game.escapes[#game.escapes + 1] = { frame = frame, closer = closer }
    end
    function game.Escape()
        for _, listed in ipairs(game.escapes) do
            if listed.frame:IsShown() then
                if listed.closer then listed.closer() else listed.frame:Hide() end
            end
        end
    end
    function ns.MapPad(real, strata, after, target, when)
        game.pads[#game.pads + 1] = { real = real, strata = strata, after = after, target = target, when = when }
    end
    function game.PadFor(real)
        for _, pad in ipairs(game.pads) do if pad.real == real then return pad end end
        return nil
    end
    -- A click on a pad: a secure click on its target (by default the
    -- minimap's zone button), then its "after".
    function game.PadClick(real)
        local pad = assert(game.PadFor(real), "no pad over that button")
        if pad.when and not pad.when() then return false end
        local target = pad.target or env.MinimapCluster.ZoneTextButton
        target:Click("LeftButton")
        if pad.after then pad.after() end
        return true
    end
    function ns.MicroButtonFollows(entry, isShown) game.follows[#game.follows + 1] = { entry = entry, isShown = isShown } end
    function ns.RefreshMicroButtons() game.microRefreshes = game.microRefreshes + 1 end
    function ns.ThemeTexture(texture, key) st[texture].theme = key end
    for _, name in ipairs({ "DarkBackdrop", "DarkCloseButton", "DarkRedButton", "DarkNativeButton", "DarkWindowArt" }) do
        ns[name] = function(object, ...) game.darkened[#game.darkened + 1] = { name, object, ... } end
    end
    function ns.MissingPiece(name) game.missing[#game.missing + 1] = name end
    function ns.Persist() end
    game.ns = ns
    local E = { Classic = ns }
    function E:GetSetting(key) return game.settings[key] end
    game.E = E

    local FILES = { "Look/Base.lua", "Look/QuestKit.lua", "Look/QuestTracker.lua", "Look/QuestLogFrame.lua",
        "Look/QuestLogList.lua", "Look/QuestLogDetail.lua", "Look/QuestLogOpen.lua", "Look/QuestMapPane.lua" }
    game.FILES = FILES
    function game.Seal()
        for _, obj in ipairs(made) do if st[obj].game then sealed[obj] = true end end
    end
    function game.Load()
        building = false
        game.Seal()
        game.loaded = true
        for _, file in ipairs(FILES) do assert(loadfile(file, "t", env))("EraUI", E) end
        for key, value in pairs(ns.DB_DEFAULTS) do if ns.db[key] == nil then ns.db[key] = value end end
        game.Look = E.Look
        game.Q = E.Look.Quest
        return game.Q
    end
    function game.Module(key)
        for _, module in ipairs(ns.modules) do if module.key == key then return module end end
        return nil
    end
    -- The engine's pass: each entry's apply, or its restore while its key is off.
    function game.Pass()
        for _, module in ipairs(ns.modules) do
            if ns.db[module.key] ~= false then module.apply() else module.restore() end
        end
    end
    -- Login: each entry's one-time step (while its key is on), then a pass.
    function game.Login()
        for _, module in ipairs(ns.modules) do
            if module.init and ns.db[module.key] ~= false then module.init() end
        end
        game.Pass()
    end
    function game.Fire(event, ...)
        for _, obj in ipairs(made) do
            local s = st[obj]
            if s.events[event] then
                local unit = s.eventUnits and s.eventUnits[event]
                if not unit or unit == (...) then Run(obj, "OnEvent", event, ...) end
            end
        end
    end
    -- Time passing: visible frames' OnUpdate, then the timers that are due.
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
    -- The timers due now (a timer of 0 runs on the next frame).
    function game.Flush()
        local due = {}
        for i = #game.timers, 1, -1 do
            if game.timers[i].at <= game.now + 1e-9 then due[#due + 1] = table.remove(game.timers, i) end
        end
        for i = #due, 1, -1 do due[i].fn() end
        return #due
    end
    function game.Enter(obj)
        st[obj].hovered = true
        Run(obj, "OnEnter")
    end
    function game.Leave(obj)
        st[obj].hovered = false
        Run(obj, "OnLeave")
    end
    function game.Fight(on)
        game.combat = on
        if on then game.Fire("PLAYER_REGEN_DISABLED") else game.Fire("PLAYER_REGEN_ENABLED") end
    end
    -- Questie, loaded now: its tracker module with its own handlers.
    function game.MakeQuestie()
        local utilities = { nativeCalls = 0, objective = 0, finisher = 0 }
        utilities.ShowQuestLog = function(self, quest, ...)
            assert(self == utilities, "Questie's receiver kept")
            utilities.nativeCalls = utilities.nativeCalls + 1
            return "native", nil, select("#", ...)
        end
        utilities.ShowObjectiveOnMap = function() utilities.objective = utilities.objective + 1 end
        utilities.ShowFinisherOnMap = function() utilities.finisher = utilities.finisher + 1 end
        game.questieImports = {}
        env.QuestieLoader = { ImportModule = function(_, name)
            game.questieImports[#game.questieImports + 1] = name
            return utilities
        end }
        return utilities
    end
    return game
end

return Mock
