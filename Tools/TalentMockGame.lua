-- A mock of WoW Forever for the talent window's tests (Tools/TestTalents.lua).
-- Not a test itself. It models what Look/Talent*.lua touch:
--   * frames, buttons, sliders, scroll frames, textures and font strings,
--     with their anchors, sizes, art, colours, scripts, hooks and events
--     (no layout solver: the tests read the anchors themselves);
--   * the game's own pieces the window meets: UIParent, the two talents
--     micro buttons with their own click, the game menu, the inspect window
--     (optionally its talents button, optionally loaded late), the red
--     error text frame;
--   * Forever's trait tree (C_Traits with staging, refunds, rollback and
--     commits, C_ClassTalents, C_SpecializationInfo), spell names and icons,
--     tooltip data (C_TooltipInfo), units, sounds, timers and combat;
--   * EraUI's side: the engine's registry and pass, the shared window
--     manager and Escape list, Dark Mode's hand-overs, the developer sink.
-- The game's own objects are sealed: a key written on one by EraUI fails
-- the test. GameTooltip and MouseIsOver don't exist (reading either fails),
-- and every key binding call fails.
-- Usage: local Mock = dofile("Tools/TalentMockGame.lua"); local game = Mock.New(); game.Load()
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
local FACES = { "Normal", "Pushed", "Disabled", "Highlight" }

function Mock.New(options)
    options = options or {}
    local game = { now = 100, timers = {}, combat = false, sounds = {}, errors = {}, persisted = {}, messages = {},
        darkened = {}, registered = {}, purchases = {}, refunds = {}, rollbacks = 0, commits = {}, traitCommits = {},
        gameClicks = 0, quickBind = false, validInspect = true, scriptSets = 0, settings = { enabled = true, darkMode = false } }
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

    local function New(kind, name, parent, template, layer)
        local obj = setmetatable({}, Meta)
        local parentState = parent and st[parent]
        st[obj] = { kind = kind, name = name, parent = parent, template = template, layer = layer, points = {}, order = {},
            shown = true, alpha = 1, scripts = {}, hooks = {}, events = {}, children = {}, regions = {}, game = building,
            enabled = true, colour = { 1, 1, 1, 1 }, coords = { 0, 1, 0, 1 }, level = parentState and (parentState.level + 1) or 1,
            strata = "MEDIUM", faces = {}, value = 0, min = 0, max = 0 }
        if parentState then
            local list = REGIONS[kind] and parentState.regions or parentState.children
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

    function Proto:GetName() return S(self).name end
    function Proto:GetParent() return S(self).parent end
    function Proto:GetObjectType() return S(self).kind end
    function Proto:IsObjectType(kind) return S(self).kind == kind end
    function Proto:IsProtected() return false, false end
    function Proto:Show() self:SetShown(true) end
    function Proto:Hide() self:SetShown(false) end
    -- As in the game, a frame under the mouse that hides (itself or with a
    -- parent) loses the mouse: its OnLeave runs.
    local function LoseMouse(obj)
        local s = st[obj]
        if s.hovered then
            s.hovered = false
            if s.enabled or s.motionWhileDisabled then Run(obj, "OnLeave") end
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
    function Proto:IsShown() return S(self).shown end
    function Proto:IsVisible() return Visible(self) end
    function Proto:SetAlpha(alpha) S(self).alpha = alpha end
    function Proto:GetAlpha() return S(self).alpha end
    function Proto:SetPoint(point, relative, relativePoint, x, y)
        local s = S(self)
        if type(relative) == "number" then relative, relativePoint, x, y = s.parent, point, relative, relativePoint end
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
    function Proto:SetSize(w, h)
        local s = S(self)
        s.width, s.height = w, h
    end
    function Proto:SetWidth(w) S(self).width = w end
    function Proto:SetHeight(h)
        local s = S(self)
        local changed = s.height ~= h
        s.height = h
        if changed and not REGIONS[s.kind] then Run(self, "OnSizeChanged", s.width, h) end
    end
    function Proto:GetWidth() return S(self).width or 0 end
    function Proto:GetHeight() return S(self).height or 0 end
    function Proto:GetSize() return self:GetWidth(), self:GetHeight() end
    function Proto:GetScale() return 1 end
    function Proto:GetEffectiveScale() return 1 end
    function Proto:SetFrameStrata(strata) S(self).strata = strata end
    function Proto:GetFrameStrata() return S(self).strata end
    function Proto:SetFrameLevel(level) S(self).level = level end
    function Proto:GetFrameLevel() return S(self).level end
    function Proto:SetToplevel(on) S(self).toplevel = on end
    function Proto:IsToplevel() return S(self).toplevel == true end
    function Proto:Raise() end
    function Proto:EnableMouse(on) S(self).mouse = on and true or false end
    function Proto:IsMouseEnabled() return S(self).mouse end
    function Proto:EnableMouseWheel(on) S(self).wheel = on and true or false end
    function Proto:IsMouseOver() return S(self).hovered == true end
    function Proto:SetMovable(on) S(self).movable = on end
    function Proto:SetClampedToScreen(on) S(self).clamped = on end
    function Proto:RegisterForDrag() end
    function Proto:SetMotionScriptsWhileDisabled(on) S(self).motionWhileDisabled = on end
    function Proto:SetScript(script, fn)
        if sealed[self] then game.scriptSets = game.scriptSets + 1 end
        S(self).scripts[script] = fn
    end
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
    function Proto:RegisterUnitEvent(event) self:RegisterEvent(event) end
    function Proto:UnregisterEvent(event) S(self).events[event] = nil end
    function Proto:GetChildren() return unpack(S(self).children) end
    function Proto:GetRegions() return unpack(S(self).regions) end
    function Proto:CreateTexture(name, layer) return New("Texture", name, self, nil, layer) end
    function Proto:CreateFontString(name, layer, font)
        local text = New("FontString", name, self, nil, layer)
        st[text].font = font
        return text
    end

    -- Textures
    function Proto:SetTexture(file)
        local s = S(self)
        if options.refuse and options.refuse[file] then return false end
        s.file, s.atlas, s.solid = file, nil, nil
        return true
    end
    function Proto:GetTexture() return S(self).file end
    function Proto:SetAtlas(atlas)
        if not (options.atlases and options.atlases[atlas]) then return false end
        local s = S(self)
        s.atlas, s.file = atlas, nil
        return true
    end
    function Proto:GetAtlas() return S(self).atlas end
    function Proto:SetColorTexture(r, g, b, a) S(self).solid = { r, g, b, a } end
    function Proto:SetTexCoord(...) S(self).coords = { ... } end
    function Proto:GetTexCoord() return unpack(S(self).coords) end
    function Proto:SetVertexColor(r, g, b, a) S(self).colour = { r, g, b, a or 1 } end
    function Proto:GetVertexColor() return unpack(S(self).colour) end
    function Proto:SetDesaturated(on) S(self).desaturated = on and true or false end
    function Proto:IsDesaturated() return S(self).desaturated == true end
    function Proto:SetBlendMode(mode) S(self).blend = mode end
    function Proto:SetHorizTile(on) S(self).htile = on end
    function Proto:SetVertTile(on) S(self).vtile = on end
    function Proto:SetDrawLayer(layer) S(self).layer = layer end
    function Proto:GetDrawLayer() return S(self).layer end

    -- Font strings
    local function Plain(text) return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    Mock.Plain = Plain
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
    function Proto:SetFontObject(font) S(self).font = font end
    function Proto:SetJustifyH(side) S(self).justify = side end
    function Proto:SetWordWrap(on) S(self).wordWrap = on end
    function Proto:GetStringWidth()
        local s = S(self)
        local across = #Plain(s.text) * 6
        if (s.width or 0) > 0 then return math.min(across, s.width) end
        return across
    end
    function Proto:GetStringHeight()
        local s = S(self)
        local across = #Plain(s.text) * 6
        if (s.width or 0) > 0 and across > s.width then return 12 * math.ceil(across / s.width) end
        return 12
    end

    -- Buttons
    for _, face in ipairs(FACES) do
        Proto["Set" .. face .. "Texture"] = function(self, file)
            local s = S(self)
            local texture = s.faces[face]
            if not texture then
                texture = New("Texture", nil, self, nil, face == "Highlight" and "HIGHLIGHT" or "ARTWORK")
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
    function Proto:LockHighlight() end
    function Proto:UnlockHighlight() end
    function Proto:SetButtonState(state) S(self).state = state end
    function Proto:GetButtonState() return S(self).state or "NORMAL" end
    function Proto:Click(mouse, down)
        if not S(self).enabled then return end
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
    function Proto:SetScrollChild(child) S(self).scrollChild = child end
    function Proto:GetScrollChild() return S(self).scrollChild end
    function Proto:SetVerticalScroll(value) S(self).scroll = value end
    function Proto:GetVerticalScroll() return S(self).scroll or 0 end

    -- Backdrops
    function Proto:SetBackdrop(backdrop) S(self).backdrop = backdrop end
    function Proto:SetBackdropColor(...) S(self).backdropColour = { ... } end
    function Proto:SetBackdropBorderColor(...) S(self).borderColour = { ... } end

    -- The red error text and a game font or two
    function Proto:AddMessage(text, r, g, b) game.messages[#game.messages + 1] = { text, r, g, b } end

    env.CreateFrame = function(kind, name, parent, template)
        local frame = New(kind, name, parent, template)
        return frame
    end

    ---------------------------------------------------------------------------
    -- The game's own UI
    ---------------------------------------------------------------------------
    env.UIParent = New("Frame", "UIParent")
    st[env.UIParent].width, st[env.UIParent].height = 1920, 1080
    for _, font in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontHighlight", "GameFontHighlightSmall",
        "GameFontDisable" }) do
        env[font] = { fontName = font }
    end
    local function GameClick() game.gameClicks = game.gameClicks + 1 end
    game.GameClick = GameClick
    for _, name in ipairs({ "TalentMicroButton", "PlayerSpellsMicroButton" }) do
        local button = New("Button", name, env.UIParent)
        st[button].scripts.OnClick = GameClick
    end
    env.GameMenuFrame = New("Frame", "GameMenuFrame", env.UIParent)
    st[env.GameMenuFrame].shown = false
    env.UIErrorsFrame = New("Frame", "UIErrorsFrame", env.UIParent)
    local function MakeInspect()
        env.InspectFrame = New("Frame", "InspectFrame", env.UIParent)
        st[env.InspectFrame].shown = false
        env.InspectPaperDollFrame = New("Frame", "InspectPaperDollFrame", env.InspectFrame)
        if options.inspectButton then
            local talents = New("Button", nil, env.InspectPaperDollFrame)
            rawset(env.InspectPaperDollFrame, "InspectTalents", talents)
            st[talents].scripts.OnClick = GameClick
            game.inspectButton = talents
        end
    end
    if not options.inspectLate then MakeInspect() end
    function game.Seal()
        for _, obj in ipairs(made) do if st[obj].game then sealed[obj] = true end end
    end

    -- The inspect window loading the first time it is wanted.
    function game.LoadInspect()
        building = true
        MakeInspect()
        building = false
        game.Seal()
        game.Fire("ADDON_LOADED", "Blizzard_InspectUI")
    end
    function game.Inspect(unit)
        game.Own(env.InspectFrame, "unit", unit)
        env.InspectFrame:Show()
    end

    ---------------------------------------------------------------------------
    -- The game's API
    ---------------------------------------------------------------------------
    env.InCombatLockdown = function() return game.combat end
    env.GetTime = function() return game.now end
    env.C_Timer = { After = function(delay, fn) game.timers[#game.timers + 1] = { at = game.now + delay, fn = fn } end }
    env.SOUNDKIT = { IG_CHARACTER_INFO_OPEN = 1, IG_CHARACTER_INFO_CLOSE = 2, IG_CHARACTER_INFO_TAB = 3,
        IG_MAINMENU_OPTION_CHECKBOX_OFF = 4, U_CHAT_SCROLL_BUTTON = 5 }
    local soundName = {}
    for name, id in pairs(env.SOUNDKIT) do soundName[id] = name end
    env.PlaySound = function(id) game.sounds[#game.sounds + 1] = soundName[id] or id end
    env.KeybindFrames_InQuickKeybindMode = function() return game.quickBind end
    env.issecretvalue = function(value) return rawequal(value, SECRET) end
    env.geterrorhandler = function() return function(problem) game.errors[#game.errors + 1] = tostring(problem) end end
    env.hooksecurefunc = function() error("no function hooks in the talent window") end
    env.SetPortraitTexture = function(texture, unit) st[texture].portrait = unit end
    game.units = { player = { "Squirt", "Warrior", "WARRIOR" } }
    env.UnitName = function(unit) local u = game.units[unit] return u and u[1], nil end
    env.UnitClass = function(unit) local u = game.units[unit] if u then return u[2], u[3] end end
    env.Enum = { TraitEdgeType = { VisualOnly = 0, Default = 1, RequiredForActivation = 2 } }
    env.Constants = { TraitConsts = { INSPECT_TRAIT_CONFIG_ID = -1 } }
    local WORDS = { TALENTS = "Talents", TALENT_POINTS = "Talent Points", TOOLTIP_TALENT_RANK = "Rank %d/%d",
        TOOLTIP_TALENT_TIER_POINTS = "Requires %d points in %s Talents", TOOLTIP_TALENT_PREREQ = "Requires %d point in %s",
        TOOLTIP_TALENT_NEXT_RANK = "Next rank:", TOOLTIP_TALENT_LEARN = "Click to learn",
        TALENT_FRAME_RESET_BUTTON_TOOLTIP_TITLE = "Reset Pending Changes",
        TALENT_FRAME_CONFIG_OPERATION_TOO_FAST = "Too fast" }
    for key, value in pairs(WORDS) do if not (options.noWords and options.noWords[key]) then env[key] = value end end

    -- Forever's trait tree. game.trees.player (and .inspect while inspecting):
    -- { config, tree, groups = { { groupID, displayName, orderIndex } },
    --   nodes = { [id] = { id, group, x, y, ranks, max, buyable, spell, edges, gates, hidden, ... } }, unspent }
    game.trees, game.conditions, game.spellNames, game.entryText = {}, {}, {}, {}
    local function TreeOf(config)
        for _, tree in pairs(game.trees) do if tree.config == config then return tree end end
    end
    local function TreeByID(id)
        for _, tree in pairs(game.trees) do if tree.tree == id then return tree end end
    end
    game.TreeOf = TreeOf
    local function Spent(tree, group)
        local total = 0
        for _, node in pairs(tree.nodes) do if node.group == group then total = total + node.ranks end end
        return total
    end
    local traits = {}
    env.C_Traits = traits
    function traits.GetConfigInfo(config)
        local tree = TreeOf(config)
        return tree and { ID = config, treeIDs = { tree.tree } } or nil
    end
    function traits.GetGroupDisplayInfoByTreeID(id)
        local tree = TreeByID(id)
        if options.groupsBroken then return "broken" end
        return tree and tree.groups or {}
    end
    function traits.GetGroupCurrencyInfo(config, ids)
        local tree, out = TreeOf(config), {}
        for _, id in ipairs(ids) do out[#out + 1] = { traitNodeGroupID = id, currencyInfos = { { spent = Spent(tree, id) } } } end
        return out
    end
    function traits.GetTreeCurrencyInfo(config)
        local tree = TreeOf(config)
        return { { quantity = tree and tree.unspent or 0, traitCurrencyID = 1 } }
    end
    function traits.ConfigHasStagedChanges(config)
        local tree = TreeOf(config)
        return tree ~= nil and (tree.staged or 0) > 0
    end
    function traits.GetTreeNodes(id)
        local tree, out = TreeByID(id), {}
        if not tree then return out end
        for nodeID in pairs(tree.nodes) do out[#out + 1] = nodeID end
        table.sort(out)
        return out
    end
    function traits.GetNodeInfo(config, id)
        local tree = TreeOf(config)
        local node = tree and tree.nodes[id]
        if not node then return nil end
        local info = { ID = id, posX = node.x, posY = node.y, isVisible = not node.hidden, groupIDs = node.groups or { node.group },
            activeEntry = node.ranks > 0 and { entryID = id * 10, rank = node.ranks } or nil, entryIDs = { id * 10 },
            ranksPurchased = node.ranks, maxRanks = node.max, isAvailable = true,
            canPurchaseRank = node.buyable ~= false and node.ranks < node.max and (tree.unspent or 0) > 0,
            canRefundRank = (node.staged or 0) > 0, visibleEdges = node.edges or {}, conditionIDs = node.gates or {} }
        for key, value in pairs(node.override or {}) do info[key] = value end
        return info
    end
    function traits.GetEntryInfo(_, entry) return { definitionID = entry + 1 } end
    function traits.GetDefinitionInfo(definition)
        local id = (definition - 1) / 10
        for _, tree in pairs(game.trees) do
            local node = tree.nodes[id]
            if node then return { spellID = node.spell, overrideIcon = node.icon } end
        end
    end
    function traits.GetConditionInfo(_, id) return game.conditions[id] end
    function traits.PurchaseRank(config, id)
        local tree = TreeOf(config)
        game.purchases[#game.purchases + 1] = { config, id }
        local node = tree.nodes[id]
        node.ranks, node.staged, tree.unspent = node.ranks + 1, (node.staged or 0) + 1, tree.unspent - 1
        tree.staged = (tree.staged or 0) + 1
        return true
    end
    function traits.RefundRank(config, id)
        local tree = TreeOf(config)
        game.refunds[#game.refunds + 1] = { config, id }
        local node = tree.nodes[id]
        if (node.staged or 0) == 0 then return false end
        node.ranks, node.staged, tree.unspent = node.ranks - 1, node.staged - 1, tree.unspent + 1
        tree.staged = tree.staged - 1
        return true
    end
    function traits.RollbackConfig(config)
        local tree = TreeOf(config)
        game.rollbacks = game.rollbacks + 1
        for _, node in pairs(tree.nodes) do
            node.ranks, tree.unspent = node.ranks - (node.staged or 0), tree.unspent + (node.staged or 0)
            node.staged = 0
        end
        tree.staged = 0
        return true
    end
    local function Learn(tree)
        for _, node in pairs(tree.nodes) do node.staged = 0 end
        tree.staged = 0
    end
    function traits.CommitConfig(config)
        game.traitCommits[#game.traitCommits + 1] = config
        Learn(TreeOf(config))
        return true
    end
    function traits.HasValidInspectData() return game.validInspect end
    if not options.noClassTalents then
        env.C_ClassTalents = {
            GetActiveConfigID = function() return game.trees.player and game.trees.player.config end,
            CommitConfig = function(saved)
                game.commits[#game.commits + 1] = { saved = saved, n = select("#", saved) }
                if game.commitResult == false then return false end
                Learn(game.trees.player)
                return true
            end,
        }
    end
    env.C_SpecializationInfo = {
        GetActiveSpecGroup = function() return 1 end,
        GetCombatConfigIDForSpecGroup = function(group)
            if options.noCombatConfig or group ~= 1 then return nil end
            return game.trees.player and game.trees.player.config
        end,
    }
    env.C_Spell = {
        GetSpellName = function(id) return game.spellNames[id] end,
        GetSpellTexture = function(id) return id and (500000 + id) or nil end,
    }
    env.C_TooltipInfo = {
        GetTraitEntry = function(entry, rank)
            local text = game.entryText[entry]
            if not text then return nil end
            return { lines = text(rank) }
        end,
        GetSpellByID = function(spell)
            return { lines = { { leftText = game.spellNames[spell] or "Spell", leftColor = { r = 1, g = 1, b = 1 } },
                { leftText = "Its own words." } } }
        end,
    }
    if options.noTraitEntry then env.C_TooltipInfo.GetTraitEntry = nil end

    ---------------------------------------------------------------------------
    -- EraUI's side: the engine, the window manager, Escape, Dark Mode
    ---------------------------------------------------------------------------
    local ns = { db = options.db or {}, DB_DEFAULTS = {}, modules = {} }
    function ns.RegisterModule(key, module)
        module.key = key
        ns.modules[#ns.modules + 1] = module
    end
    function ns.RegisterClassicWindow(frame, shares)
        game.registered[#game.registered + 1] = { frame = frame, shares = shares }
    end
    env.UISpecialFrames = { "GameMenuFrame" }
    function ns.CloseOnEscape(frame)
        local name = frame:GetName()
        for _, listed in ipairs(env.UISpecialFrames) do if listed == name then return end end
        table.insert(env.UISpecialFrames, name)
    end
    function ns.ThemeTexture(texture, key) st[texture].theme = key end
    for _, name in ipairs({ "DarkBackdrop", "DarkCloseButton", "DarkRedButton", "DarkNativeButton", "DarkWindowArt" }) do
        ns[name] = function(object, ...) game.darkened[#game.darkened + 1] = { name, object, ... } end
    end
    function ns.Persist(line) game.persisted[#game.persisted + 1] = line end
    game.ns = ns
    local E = { Classic = ns }
    function E:GetSetting(key) return game.settings[key] end
    game.E = E

    local FILES = { "Look/Base.lua", "Look/TalentKit.lua", "Look/TalentFrame.lua", "Look/TalentTree.lua", "Look/TalentModule.lua" }
    game.FILES = FILES
    function game.Load()
        building = false
        game.Seal()
        for _, file in ipairs(FILES) do assert(loadfile(file, "t", env))("EraUI", E) end
        for key, value in pairs(ns.DB_DEFAULTS) do if ns.db[key] == nil then ns.db[key] = value end end
        game.Look = E.Look
        game.T = E.Look.Talent
        return game.T
    end
    -- The engine's pass: each entry's apply, or its restore while its key is off.
    function game.Pass()
        for _, module in ipairs(ns.modules) do
            if ns.db[module.key] ~= false then module.apply() else module.restore() end
        end
    end
    function game.Fire(event, ...)
        for _, obj in ipairs(made) do
            local s = st[obj]
            if s.events[event] then Run(obj, "OnEvent", event, ...) end
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
            local due = {}
            for i = #game.timers, 1, -1 do
                if game.timers[i].at <= game.now + 1e-9 then due[#due + 1] = table.remove(game.timers, i) end
            end
            for i = #due, 1, -1 do due[i].fn() end
        until done >= (seconds or step) - 1e-9
    end
    -- The mouse is over one button at a time: entering one leaves the last.
    function game.Enter(obj)
        for _, other in ipairs(made) do
            local s = st[other]
            if other ~= obj and s.hovered and not REGIONS[s.kind] then
                s.hovered = false
                if s.enabled or s.motionWhileDisabled then Run(other, "OnLeave") end
            end
        end
        st[obj].hovered = true
        if st[obj].enabled or st[obj].motionWhileDisabled then Run(obj, "OnEnter") end
    end
    function game.Leave(obj)
        st[obj].hovered = false
        if st[obj].enabled or st[obj].motionWhileDisabled then Run(obj, "OnLeave") end
    end
    return game
end

return Mock
