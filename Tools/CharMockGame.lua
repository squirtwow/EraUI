-- A mock of WoW Forever's character window for the character look's tests
-- (Tools/TestCharacterSheet.lua, TestAttackRating.lua, TestSkillBarFill.lua,
-- TestStatPanes.lua). Not a test itself. It models what Look/Char*.lua
-- touches, the way Camelot's Blizzard_UIPanels_Game builds it:
--   * CharacterFrame with its LeftPaneHost, RightPaneHost, side panes, mode
--     tabs (ModeTabs.Tabs with frameName), portrait, title and close button,
--     UpdateSize / ShowSubFrame / Expand / RefreshRightPane;
--   * PaperDollFrame with its gear slots, model scene (camera, actor,
--     controls) and Equipment Manager pane; the stats panes and sidebars;
--   * the Skills, Reputation, Currency and Statistics lists (scroll box,
--     minimal scroll bar, pooled rows built from the game's templates), the
--     skill detail pane and its rank bar, the PvP panel; the Currency tab's
--     selection, row clicks, watch toggle and detail pane (TokenDetailFrame
--     with its Unused and Show on Backpack ticks), and SetRightPaneCollapsed;
--   * ColoredProgressBarMixin, SkillsBarMixin and ReputationBarMixin with the
--     game's SetFillPercent (it sizes against FillArea);
--   * the stat, item, skill, reputation and timer APIs, secret values, and
--     the engine's registry and pass.
-- The game's own objects are sealed: a key written on one by anything but
-- the game's own (mock) code fails the test. hooksecurefunc and HookScript
-- are allowed. A small layout solver answers GetLeft/GetWidth... and
-- game.Resize() fires OnSizeChanged the way the client's layout does.
-- Usage: local Mock = dofile("Tools/CharMockGame.lua"); local game = Mock.New(); game.Load()
local Mock = {}
unpack = unpack or table.unpack

local POINTS = {
    TOPLEFT = { 0, 1 }, TOP = { 0.5, 1 }, TOPRIGHT = { 1, 1 }, LEFT = { 0, 0.5 }, CENTER = { 0.5, 0.5 },
    RIGHT = { 1, 0.5 }, BOTTOMLEFT = { 0, 0 }, BOTTOM = { 0.5, 0 }, BOTTOMRIGHT = { 1, 0 },
}
local ATLAS_SIZE = { ["common-stat-bar-white"] = { 120, 15 }, ["common-stat-bar-blue"] = { 120, 15 },
    ["common-stat-bar-red"] = { 120, 15 } }

-- A value the game keeps hidden: any comparison, sum, text or index fails.
local SECRET = setmetatable({}, {
    __tostring = function() error("a secret turned to text", 2) end,
    __concat = function() error("a secret joined to text", 2) end,
    __eq = function() error("a secret compared", 2) end,
    __lt = function() error("a secret compared", 2) end, __le = function() error("a secret compared", 2) end,
    __add = function() error("a secret in a sum", 2) end, __sub = function() error("a secret in a sum", 2) end,
    __mul = function() error("a secret in a sum", 2) end, __div = function() error("a secret in a sum", 2) end,
    __unm = function() error("a secret in a sum", 2) end,
    __index = function() error("a secret indexed", 2) end,
})
Mock.SECRET = SECRET

local function Strip(text)
    return (tostring(text or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end
Mock.Strip = Strip

function Mock.New(options)
    options = options or {}
    local game = { now = 100, timers = {}, combat = false, sounds = {}, errors = {}, hooks = 0, cvars = {},
        cvarWrites = 0, popups = {}, tips = {}, gameTips = 0, gameTipHides = 0, signals = 0, uiCalls = 0,
        secretArgs = 0, hidden = {}, saves = 0, darkened = {}, refused = {}, unknownEvents = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    game.env = env
    local st = setmetatable({}, { __mode = "k" })
    local sealed = setmetatable({}, { __mode = "k" })
    local building = true
    local made = {}
    game.st, game.made = st, made

    ---------------------------------------------------------------------------
    -- Objects
    ---------------------------------------------------------------------------
    local Proto = {}
    local Meta = {
        __index = Proto,
        __newindex = function(t, key, value)
            if sealed[t] then
                error("a key (" .. tostring(key) .. ") written on the game's " .. tostring(st[t].name or st[t].kind), 2)
            end
            rawset(t, key, value)
        end,
    }
    local FRAMES = { Frame = true, Button = true, CheckButton = true, ModelScene = true, StatusBar = true,
        EventButton = true, ItemButton = true, EventFrame = true }

    local function New(kind, name, parent)
        local obj = setmetatable({}, Meta)
        st[obj] = { kind = kind, name = name, parent = parent, points = {}, shown = true, alpha = 1, scale = 1,
            scripts = {}, hooks = {}, events = {}, children = {}, regions = {}, mouse = false, game = building,
            color = { 1, 1, 1, 1 }, coords = { 0, 1, 0, 1 }, enabled = true }
        if parent and FRAMES[kind] then
            table.insert(st[parent].children, obj)
            st[obj].level = (st[parent].level or 1) + 1
        elseif parent then
            table.insert(st[parent].regions, obj)
        else
            st[obj].level = 1
        end
        made[#made + 1] = obj
        if name then env[name] = obj end
        return obj
    end
    game.New = New
    function game.Seal() for _, obj in ipairs(made) do if st[obj].game then sealed[obj] = true end end end
    -- The game's own construction after load: every object it made, sealed.
    local function GameMakes(fn, ...)
        local was, from = building, #made + 1
        building = true
        local result = fn(...)
        building = was
        if not was then
            for i = from, #made do if st[made[i]].game then sealed[made[i]] = true end end
        end
        return result
    end
    game.GameMakes = GameMakes
    function game.IsGame(obj) return st[obj] and st[obj].game end
    -- The game's own code writing a key on its object.
    local function Own(obj, key, value) rawset(obj, key, value) end
    game.Own = Own

    local function S(self) return st[self] end
    function Proto:GetName() return S(self).name end
    function Proto:GetParent() return S(self).parent end
    function Proto:SetParent(parent)
        local s = S(self)
        local list = s.parent and st[s.parent].children
        if list then for i, child in ipairs(list) do if child == self then table.remove(list, i) break end end end
        s.parent = parent
        if parent then table.insert(st[parent].children, self) end
        game.reparented = (game.reparented or 0) + 1
    end
    function Proto:IsObjectType(kind) return S(self).kind == kind or (kind == "Frame" and FRAMES[S(self).kind] == true) end
    function Proto:GetObjectType() return S(self).kind end
    function Proto:IsForbidden() return false end
    function Proto:IsProtected() return S(self).protected == true end
    -- Size and scale
    function Proto:SetSize(w, h) S(self).w, S(self).h = w, h end
    function Proto:SetWidth(w) S(self).w = (S(self).kind == "FontString" and w == 0) and nil or w end
    function Proto:SetHeight(h) S(self).h = h end
    function Proto:SetScale(s) S(self).scale = s end
    function Proto:GetScale() return S(self).scale end
    function Proto:GetEffectiveScale()
        local s = S(self)
        local up = s.parent and s.parent:GetEffectiveScale() or 1
        if not FRAMES[s.kind] then return up end
        return s.scale * up
    end
    -- Anchors
    function Proto:ClearAllPoints() S(self).points = {} end
    function Proto:SetPoint(point, relative, relativePoint, x, y)
        if type(relative) == "number" then relative, relativePoint, x, y = nil, point, relative, relativePoint end
        if type(relative) == "string" then relative = env[relative] end
        local list = S(self).points
        local p = { point, relative or S(self).parent, relativePoint or point, x or 0, y or 0 }
        for i, old in ipairs(list) do if old[1] == point then list[i] = p return end end
        list[#list + 1] = p
    end
    function Proto:SetAllPoints(relative)
        relative = relative or S(self).parent
        S(self).points = { { "TOPLEFT", relative, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relative, "BOTTOMRIGHT", 0, 0 } }
    end
    function Proto:GetNumPoints() return #S(self).points end
    function Proto:GetPoint(i)
        local p = S(self).points[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    -- The layout solver (screen units: left, bottom, right, top)
    local solving = {}
    local function Axis(lo, hi, mid, size)
        if lo and hi then return lo, hi end
        if lo then return lo, size and lo + size end
        if hi then return size and hi - size, hi end
        if mid and size then return mid - size / 2, mid + size / 2 end
    end
    function Proto:Rect()
        local s = S(self)
        if s.fixed then return s.fixed[1], s.fixed[2], s.fixed[3], s.fixed[4] end
        if solving[self] or #s.points == 0 then return nil end
        solving[self] = true
        local scale = self:GetEffectiveScale()
        local xs, ys, ok = {}, {}, true
        for _, p in ipairs(s.points) do
            local l, b, r, t
            if p[2] then l, b, r, t = p[2]:Rect() end
            if not l then ok = false break end
            local to, from = POINTS[p[3]], POINTS[p[1]]
            xs[from[1]] = l + (r - l) * to[1] + p[4] * scale
            ys[from[2]] = b + (t - b) * to[2] + p[5] * scale
        end
        solving[self] = nil
        if not ok then return nil end
        local w, h = s.w, s.h
        if s.kind == "FontString" then
            w = w or self:GetStringWidth()
            h = h or 12
        end
        local l, r = Axis(xs[0], xs[1], xs[0.5], w and w * scale)
        local b, t = Axis(ys[0], ys[1], ys[0.5], h and h * scale)
        if not (l and r and b and t) then return nil end
        return l, b, r, t
    end
    local function Edge(self, i)
        local e = { self:Rect() }
        if e[i] == nil then return nil end
        return e[i] / self:GetEffectiveScale()
    end
    function Proto:GetLeft() return Edge(self, 1) end
    function Proto:GetBottom() return Edge(self, 2) end
    function Proto:GetRight() return Edge(self, 3) end
    function Proto:GetTop() return Edge(self, 4) end
    function Proto:GetCenter()
        local l, b, r, t = self:Rect()
        if not l then return nil end
        local f = self:GetEffectiveScale()
        return (l + r) / 2 / f, (b + t) / 2 / f
    end
    function Proto:GetWidth()
        local l, _, r = self:Rect()
        if l then return (r - l) / self:GetEffectiveScale() end
        return S(self).w or 0
    end
    function Proto:GetHeight()
        local _, b, _, t = self:Rect()
        if b then return (t - b) / self:GetEffectiveScale() end
        return S(self).h or 0
    end
    function Proto:GetSize() return self:GetWidth(), self:GetHeight() end
    -- Shown, visible, alpha, levels
    local function Run(obj, script, ...)
        local s = S(obj)
        if s.scripts[script] then s.scripts[script](obj, ...) end
        for _, fn in ipairs(s.hooks[script] or {}) do fn(obj, ...) end
    end
    game.Run = Run
    function Proto:Show()
        if S(self).shown then return end
        S(self).shown = true
        Run(self, "OnShow")
    end
    function Proto:Hide()
        if not S(self).shown then return end
        S(self).shown = false
        Run(self, "OnHide")
    end
    function Proto:SetShown(on) if on then self:Show() else self:Hide() end end
    function Proto:IsShown() return S(self).shown end
    function Proto:IsVisible()
        local s = S(self)
        if not s.shown then return false end
        return s.parent == nil or s.parent:IsVisible()
    end
    function Proto:SetAlpha(a) S(self).alpha = a end
    function Proto:GetAlpha() return S(self).alpha end
    function Proto:SetFrameLevel(level) S(self).level = level end
    function Proto:GetFrameLevel() return S(self).level or 1 end
    function Proto:SetFrameStrata(strata) S(self).strata = strata end
    function Proto:GetFrameStrata() return S(self).strata or "MEDIUM" end
    function Proto:Raise() S(self).raised = true end
    function Proto:SetClipsChildren(on) S(self).clips = on end
    function Proto:SetClampedToScreen(on) S(self).clamped = on end
    function Proto:SetMovable(on) S(self).movable = on end
    -- Children and regions
    function Proto:GetChildren() return unpack(S(self).children) end
    function Proto:GetRegions() return unpack(S(self).regions) end
    function Proto:CreateTexture(_, layer, _, sublevel)
        local t = New("Texture", nil, self)
        S(t).layer, S(t).sublevel = layer, sublevel
        return t
    end
    function Proto:CreateMaskTexture() return New("MaskTexture", nil, self) end
    function Proto:CreateFontString(_, layer, font)
        local t = New("FontString", nil, self)
        S(t).layer, S(t).font = layer, font
        return t
    end
    -- Textures
    function Proto:SetTexture(path)
        if path ~= nil and game.refused[path] then return false end
        S(self).file, S(self).atlas = path, nil
        return true
    end
    function Proto:GetTexture() return S(self).file end
    function Proto:GetTextureFilePath() return S(self).file end
    function Proto:SetAtlas(atlas, useSize)
        S(self).atlas, S(self).file = atlas, nil
        if useSize then
            local size = ATLAS_SIZE[atlas] or { 40, 20 }
            S(self).w, S(self).h = size[1], size[2]
        end
    end
    function Proto:GetAtlas() return S(self).atlas end
    function Proto:SetTexCoord(...) S(self).coords = { ... } end
    function Proto:GetTexCoord()
        local c = S(self).coords
        if #c == 8 then return unpack(c) end
        return c[1], c[3], c[1], c[4], c[2], c[3], c[2], c[4]
    end
    function Proto:SetVertexColor(r, g, b, a) S(self).color = { r, g, b, a or 1 } end
    function Proto:GetVertexColor() local c = S(self).color return c[1], c[2], c[3], c[4] end
    function Proto:SetColorTexture(r, g, b, a) S(self).colorTexture = { r, g, b, a } end
    function Proto:SetBlendMode(mode) S(self).blend = mode end
    function Proto:GetBlendMode() return S(self).blend end
    function Proto:SetDrawLayer(layer, sub) S(self).layer, S(self).sublevel = layer, sub end
    function Proto:GetDrawLayer() return S(self).layer, S(self).sublevel end
    function Proto:SetHorizTile(on) S(self).htile = on end
    function Proto:SetVertTile(on) S(self).vtile = on end
    function Proto:SetDesaturated(on) S(self).desaturated = on end
    function Proto:AddMaskTexture(mask) S(self).masks = S(self).masks or {}; table.insert(S(self).masks, mask) end
    function Proto:RemoveMaskTexture(mask)
        for i, held in ipairs(S(self).masks or {}) do if held == mask then table.remove(S(self).masks, i) break end end
    end
    function Proto:GetNumMaskTextures() return #(S(self).masks or {}) end
    -- Text
    function Proto:SetText(text) S(self).text = text end
    function Proto:GetText() return S(self).text end
    function Proto:SetFontObject(font) S(self).font = font end
    function Proto:GetFontObject() return S(self).font end
    function Proto:SetTextColor(r, g, b, a) S(self).textColor = { r, g, b, a or 1 } end
    function Proto:GetTextColor() local c = S(self).textColor or { 1, 1, 1, 1 } return c[1], c[2], c[3], c[4] end
    function Proto:SetJustifyH(j) S(self).justifyH = j end
    function Proto:SetJustifyV(j) S(self).justifyV = j end
    function Proto:SetWordWrap(on) S(self).wrap = on end
    function Proto:GetStringWidth()
        local text = S(self).text
        if env.issecretvalue(text) then return 60 end
        return #Strip(text) * 6
    end
    function Proto:GetStringHeight() return S(self).text and 12 or 0 end
    -- Scripts and events
    function Proto:SetScript(script, fn) S(self).scripts[script] = fn end
    function Proto:GetScript(script) return S(self).scripts[script] end
    function Proto:HookScript(script, fn)
        local list = S(self).hooks[script] or {}
        S(self).hooks[script] = list
        list[#list + 1] = fn
    end
    function Proto:RegisterEvent(event)
        if game.unknownEvents[event] then error("unknown event " .. event) end
        S(self).events[event] = true
    end
    function Proto:RegisterUnitEvent(event) S(self).events[event] = true end
    function Proto:UnregisterEvent(event) S(self).events[event] = nil end
    -- Mouse and buttons
    function Proto:EnableMouse(on)
        if game.combat and S(self).protected then error("blocked: a guarded frame's mouse changed in a fight") end
        S(self).mouse = on and true or false
    end
    function Proto:IsMouseEnabled() return S(self).mouse end
    function Proto:EnableMouseWheel(on) S(self).wheel = on end
    function Proto:SetHitRectInsets(...) S(self).insets = { ... }; S(self).insetWrites = (S(self).insetWrites or 0) + 1 end
    function Proto:IsMouseOver() return S(self).over == true end
    function Proto:RegisterForClicks(...) S(self).clicks = { ... } end
    function Proto:RegisterForDrag() end
    function Proto:LockHighlight() S(self).locked = true end
    function Proto:UnlockHighlight() S(self).locked = false end
    function Proto:Enable() S(self).enabled = true end
    function Proto:Disable() S(self).enabled = false end
    function Proto:SetEnabled(on) S(self).enabled = on and true or false end
    function Proto:IsEnabled() return S(self).enabled end
    function Proto:SetChecked(on) S(self).checked = on and true or false end
    function Proto:GetChecked() return S(self).checked == true end
    function Proto:Click()
        if S(self).kind == "CheckButton" then S(self).checked = not S(self).checked end
        Run(self, "OnClick", "LeftButton")
    end
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked", "DisabledChecked" }) do
        local key = state .. "Face"
        Proto["Set" .. state .. "Texture"] = function(self, path)
            local s = S(self)
            if not s[key] then s[key] = self:CreateTexture(nil, state == "Highlight" and "HIGHLIGHT" or "ARTWORK") end
            if type(path) == "string" then s[key]:SetTexture(path) end
        end
        Proto["Get" .. state .. "Texture"] = function(self) return S(self)[key] end
    end
    function Proto:SetNormalFontObject(font) S(self).normalFont = font end
    function Proto:SetHighlightFontObject(font) S(self).highlightFont = font end
    function Proto:SetDisabledFontObject(font) S(self).disabledFont = font end
    function Proto:GetFontString()
        local s = S(self)
        if not s.label then s.label = self:CreateFontString(nil, "OVERLAY") end
        return s.label
    end
    function Proto:SetBackdrop(b) S(self).backdrop = b end
    function Proto:SetBackdropColor(...) S(self).backdropColor = { ... } end
    function Proto:SetBackdropBorderColor(...) S(self).backdropBorder = { ... } end

    -- Frames made by EraUI (with the few templates it asks for).
    local function Template(obj, template)
        if not template then return end
        S(obj).template = template
        if template == "UICheckButtonTemplate" then
            obj.Text = obj:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
            obj.Text:SetPoint("LEFT", obj, "RIGHT", 0, 1)
        elseif template == "CharacterStatFrameTemplate" then
            obj.Background = obj:CreateTexture(nil, "BACKGROUND")
            obj.Background:SetAtlas("UI-Character-Info-Line-Bounce", true)
            obj.Label = obj:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            obj.Value = obj:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            -- The game's own hover (CharacterStatFrameMixin) and GameTooltip_Hide.
            obj:SetScript("OnEnter", function(self)
                if self.onEnterFunc then self:onEnterFunc() else env.PaperDollStatTooltip(self) end
            end)
            obj:SetScript("OnLeave", function() game.gameTipHides = game.gameTipHides + 1 end)
        elseif template == "UIPanelButtonTemplate" then
            obj.Left, obj.Middle, obj.Right = obj:CreateTexture(), obj:CreateTexture(), obj:CreateTexture()
        end
    end
    env.CreateFrame = function(kind, name, parent, template)
        if template == "CharacterStatFrameTemplate" and game.noStatTemplate then error("no such template") end
        local obj = New(kind or "Frame", name, parent)
        Template(obj, template)
        return obj
    end

    ---------------------------------------------------------------------------
    -- Globals the look uses
    ---------------------------------------------------------------------------
    env.UIParent = New("Frame", "UIParent")
    st[env.UIParent].fixed = { 0, 0, 1024, 768 }
    env.InCombatLockdown = function() return game.combat end
    env.issecretvalue = function(value) return rawequal(value, SECRET) end
    env.GetTime = function() return game.now end
    env.GetBuildInfo = function() return "1.60.1", "70425", "Oct 1 2026", options.interface or 16001 end
    env.C_Timer = { After = function(delay, fn) game.timers[#game.timers + 1] = { at = game.now + delay, fn = fn } end }
    env.geterrorhandler = function() return function(problem) table.insert(game.errors, tostring(problem)) end end
    env.hooksecurefunc = function(object, key, fn)
        if type(object) == "string" then object, key, fn = env, object, key end
        game.hooks = game.hooks + 1
        local old = object[key]
        assert(type(old) == "function", "hooking a missing " .. tostring(key))
        rawset(object, key, function(...)
            local a, b, c, d = old(...)
            fn(...)
            return a, b, c, d
        end)
    end
    env.PlaySound = function(id) game.sounds[#game.sounds + 1] = id end
    env.SOUNDKIT = { IG_INVENTORY_ROTATE_CHARACTER = "rotate", IG_MAINMENU_OPTION_CHECKBOX_ON = "on",
        IG_MAINMENU_OPTION_CHECKBOX_OFF = "off", IG_CHARACTER_INFO_OPEN = "open", IG_CHARACTER_INFO_CLOSE = "close",
        U_CHAT_SCROLL_BUTTON = "scroll" }
    env.EventRegistry = { TriggerEvent = function(_, event)
        if event == "EraUIClassic.CharacterSheetLaid" then game.signals = game.signals + 1 end
    end }
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show = function(which, a, b, data) game.popups[#game.popups + 1] = { which, a, b, data } end
    env.HideUIPanel = function(frame) game.closed = frame; frame:Hide() end
    for _, font in ipairs({ "GameFontNormal", "GameFontNormalSmall", "GameFontHighlight", "GameFontHighlightSmall",
        "GameFontDisable" }) do env[font] = { fontName = font } end
    local strings = {
        LEVEL = "Level", CHARACTER = "Character", REPUTATION = "Reputation", CURRENCY = "Currency", SKILLS = "Skills",
        SPELL_STAT1_NAME = "Strength", SPELL_STAT2_NAME = "Agility", SPELL_STAT3_NAME = "Stamina",
        SPELL_STAT4_NAME = "Intellect", SPELL_STAT5_NAME = "Spirit", ARMOR = "Armor", MELEE_ATTACK = "Melee Attack",
        RANGED_ATTACK = "Ranged Attack", ATTACK_POWER = "Power", DAMAGE = "Damage", MELEE_ATTACK_POWER = "Attack Power",
        RANGED_ATTACK_POWER = "Ranged Attack Power", WEAPON_SKILL_RANK_TOOLTIP = "You have %s skill in %s.",
        RESISTANCE = "Resistance", DAMAGE_SCHOOL3 = "Fire", DAMAGE_SCHOOL4 = "Nature", DAMAGE_SCHOOL5 = "Frost",
        DAMAGE_SCHOOL6 = "Shadow", DAMAGE_SCHOOL7 = "Arcane", FACTION = "Faction", STANDING = "Standing", CLOSE = "Close",
        UNLEARN_SKILL_TOOLTIP = "Unlearn this skill", UNLEARN_SKILL_PROMPT = "Unlearn %s?", YES = "Yes", NO = "No",
        AT_WAR = "At War", MOVE_TO_INACTIVE = "Move to Inactive", SHOW_FACTION_ON_MAINSCREEN = "Show as Experience Bar",
        EQUIPMENT_MANAGER = "Equipment Manager", RESISTANCE_LABEL = "Resistances", STAT_FORMAT = "%s:",
        STAT_CATEGORY_GENERAL = "General", STAT_CATEGORY_PRIMARY_ATTRIBUTES = "Primary Attributes",
        STAT_CATEGORY_WEAPONS = "Weapons", STAT_CATEGORY_MODIFIERS = "Modifiers", STAT_CATEGORY_DEFENSE = "Defense",
        INVSLOT_MAINHAND = 16, INVSLOT_RANGED = 18,
    }
    for key, value in pairs(strings) do env[key] = value end

    ---------------------------------------------------------------------------
    -- The player: stats, gear, skills, factions
    ---------------------------------------------------------------------------
    game.level, game.race, game.class, game.classToken = 12, "Human", "Rogue", "ROGUE"
    game.stats = { { 20, 20, 0, 0 }, { 25, 25, 0, 0 }, { 22, 22, 0, 0 }, { 18, 18, 0, 0 }, { 19, 19, 0, 0 } }
    game.armor = { 50, 50, 50, 0, 0 }
    game.attackPower, game.rangedPower = { 40, 0, 0 }, { 30, 0, 0 }
    game.damage, game.rangedDamage = { 3.4, 6.2 }, { 2.9, 4.1, 8.3 }
    game.resists = { [2] = 5, [3] = 0, [4] = 10, [5] = 0, [6] = 3 }
    game.equip = { [16] = 2092, [18] = 25861 }
    game.items = { [2092] = { 2, 15 }, [25861] = { 2, 16 } }
    game.skills = {}
    game.form = 0
    env.UnitLevel = function() return game.level end
    env.UnitRace = function() return game.race, "Human" end
    env.UnitClass = function() return game.class, game.classToken end
    env.UnitStat = function(_, i) local s = game.stats[i] return s[1], s[2], s[3], s[4] end
    env.UnitArmor = function() return unpack(game.armor) end
    env.UnitAttackPower = function() return unpack(game.attackPower) end
    env.UnitRangedAttackPower = function() return unpack(game.rangedPower) end
    env.UnitDamage = function() return game.damage[1], game.damage[2] end
    env.UnitRangedDamage = function() return game.rangedDamage[1], game.rangedDamage[2], game.rangedDamage[3] end
    env.UnitResistance = function(_, school) local v = game.resists[school] return v, v, v, 0 end
    env.GetShapeshiftForm = function() return game.form end
    env.GetInventoryItemID = function(unit, slot)
        assert(unit == "player", "items are the player's")
        return game.equip[slot]
    end
    env.C_Item = { GetItemInfoInstant = function(itemID)
        if rawequal(itemID, SECRET) then
            game.secretArgs = game.secretArgs + 1
            error("a secret handed to the game")
        end
        if game.itemError then error("item lookup failed") end
        local kind = game.items[itemID]
        if not kind then return nil end
        return itemID, "Weapon", "Sub", "INVTYPE_WEAPON", 135641, kind[1], kind[2]
    end }
    local function Touch() game.uiCalls = game.uiCalls + 1 end
    game.skillList = {} -- the Skills window's lines: { name, rank, maxRank, isHeader, skillID, isAbandonable }
    game.selected = 0
    env.C_SkillInfo = {
        GetSkillLineInfoByID = function(id)
            game.skillCalls = (game.skillCalls or 0) + 1
            if game.skillError then error("skill lookup failed") end
            return game.skills[id]
        end,
        GetSelectedSkill = function() return game.selected end,
        GetSkillLineInfo = function(index) return game.skillList[index] end,
        GetNumSkillLines = function() Touch() return #game.skillList end,
        SetSelectedSkill = Touch, ExpandSkillHeader = Touch, CollapseSkillHeader = Touch,
        AbandonSkill = function(id) game.abandoned = id end,
    }
    game.factions = {}
    game.repCalls = {}
    env.C_Reputation = {
        GetNumFactions = function() return #game.factions end,
        GetFactionDataByIndex = function(i) return game.factions[i] end,
        IsFactionActive = function(i) return game.factions[i] and game.factions[i].active ~= false end,
        ToggleFactionAtWar = function(i) table.insert(game.repCalls, "war " .. i) end,
        SetFactionActive = function(i, on) table.insert(game.repCalls, "active " .. i .. " " .. tostring(on)) end,
        SetWatchedFactionByIndex = function(i)
            table.insert(game.repCalls, "watch " .. i)
            for index, faction in ipairs(game.factions) do faction.isWatched = index == i end
        end,
    }
    -- The Currency tab's lines (C_CurrencyInfo.GetCurrencyListInfo): { name,
    -- isHeader, currencyID, quantity, discovered, isShowInBackpack,
    -- isTypeUnused }; the game's calls that change them, in order.
    game.currencies = {}
    game.coinCalls = {}
    env.C_CurrencyInfo = {
        GetCurrencyListSize = function() return #game.currencies end,
        GetCurrencyListInfo = function(i) return game.currencies[i] end,
        SetCurrencyBackpack = function(i, on)
            table.insert(game.coinCalls, "backpack " .. tostring(i) .. " " .. tostring(on))
            if game.currencies[i] then game.currencies[i].isShowInBackpack = on end
        end,
        SetCurrencyUnused = function(i, on)
            table.insert(game.coinCalls, "unused " .. tostring(i) .. " " .. tostring(on))
            if game.currencies[i] then game.currencies[i].isTypeUnused = on end
        end,
    }
    -- The modifier held for a click: game.modified names the action it
    -- matches ("CHATLINK", "TOKENWATCHTOGGLE"), nil for a plain click.
    env.IsModifiedClick = function(action) return game.modified ~= nil and game.modified == action end
    env.PaperDollStatTooltip = function(self)
        game.gameTips = game.gameTips + 1
        game.lastStatTip = { self.tooltip, self.tooltip2, self.tooltip3 }
    end

    ---------------------------------------------------------------------------
    -- The game's progress bars (ColoredProgressBarTemplate and its mixins)
    ---------------------------------------------------------------------------
    local function Mixin(obj, ...)
        for i = 1, select("#", ...) do
            for key, value in pairs((select(i, ...))) do Own(obj, key, value) end
        end
        return obj
    end
    local function CreateFromMixins(...) return Mixin({}, ...) end
    env.ColoredProgressBarMixin = { ColorType = { Red = 1, Green = 2, Blue = 3, White = 4 } }
    local CPB = env.ColoredProgressBarMixin
    function CPB:OnLoad() self:SetFillPercent(0) end
    function CPB:SetText(text) self.Text:SetText(text) end
    function CPB:SetFillWidth(width) self.Fill:SetWidth(width) end
    function CPB:SetFillPercent(percent)
        if rawequal(percent, SECRET) then return end
        local p = math.min(1, math.max(0, percent))
        self:SetFillWidth(p * (self.FillArea or self):GetWidth())
        self.Fill:SetTexCoord(0, p, 1, 0)
    end
    function CPB:SetFillTextureByColorType(kind)
        self.Fill:SetAtlas(kind == 3 and "common-stat-bar-blue" or "common-stat-bar-white", true)
    end
    env.SkillsBarMixin = CreateFromMixins(CPB)
    function env.SkillsBarMixin:UpdateBarColor(r, g, b) self.Fill:SetVertexColor(r, g, b) end
    env.ReputationBarMixin = {}
    function env.ReputationBarMixin:UpdateBarColor(r, g, b) self.Fill:SetVertexColor(r, g, b) end

    -- A bar from the template: its track (FillArea) 6 in from each end.
    local function MakeBar(parent, mixin, width)
        local bar = New("Frame", nil, parent)
        bar:SetSize(width or 67, 29)
        local bg = bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAtlas("common-stat-bar-BG")
        bg:SetAllPoints(bar)
        if not options.noFillArea then -- 70374 had no track inside the bar
            Own(bar, "FillArea", New("Frame", nil, bar))
            bar.FillArea:SetPoint("TOPLEFT", bar, "TOPLEFT", 6, 0)
            bar.FillArea:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -6, 0)
        end
        Own(bar, "Fill", bar:CreateTexture(nil, "BORDER"))
        bar.Fill:SetAtlas("common-stat-bar-white", true)
        bar.Fill:SetSize(0, 15)
        bar.Fill:SetPoint("LEFT", bar.FillArea or bar, "LEFT")
        Own(bar, "Mask", bar:CreateMaskTexture())
        bar.Fill:AddMaskTexture(bar.Mask)
        Own(bar, "Text", bar:CreateFontString(nil, "ARTWORK", "GameFontHighlight"))
        Mixin(bar, CPB, mixin)
        return bar
    end
    -- The game made the bar, then ran its OnLoad (SetFillPercent(0)).
    function game.Bar(parent, mixin, width)
        local bar = GameMakes(MakeBar, parent, mixin, width)
        bar:OnLoad()
        return bar
    end

    ---------------------------------------------------------------------------
    -- The character window
    ---------------------------------------------------------------------------
    local sheet = New("Frame", "CharacterFrame", env.UIParent)
    sheet:SetSize(676, 540)
    sheet:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 20, -100)
    st[sheet].level = 10
    st[sheet].shown = false
    st[sheet].collapsed = false
    for _, key in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "Inset", "InsetRight" }) do Own(sheet, key, New("Frame", nil, sheet)) end
    Own(sheet, "PortraitContainer", New("Frame", nil, sheet))
    Own(sheet.PortraitContainer, "portrait", sheet.PortraitContainer:CreateTexture(nil, "ARTWORK"))
    sheet.PortraitContainer.portrait:SetTexture("Interface\\Icons\\Ability_Rogue_Eviscerate")
    Own(sheet, "TitleContainer", New("Frame", nil, sheet))
    Own(sheet.TitleContainer, "TitleText", sheet.TitleContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal"))
    sheet.TitleContainer.TitleText:SetText("Squirt Gutterson")
    Own(sheet, "CloseButton", New("Button", "CharacterFrameCloseButton", sheet))
    sheet.CloseButton:SetSize(24, 24)
    sheet.CloseButton:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", -2, -2)
    sheet.CloseButton:SetNormalTexture("c60-close")
    Own(sheet, "LeftPaneHost", New("Frame", "CharacterFrameLeftPaneHost", sheet))
    sheet.LeftPaneHost:SetWidth(398)
    sheet.LeftPaneHost:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, -20)
    sheet.LeftPaneHost:SetPoint("BOTTOMLEFT", sheet, "BOTTOMLEFT")
    sheet.LeftPaneHost:CreateTexture(nil, "BACKGROUND"):SetAtlas("UI-Character-Info-General-BG")
    Own(sheet, "RightPaneHost", New("Frame", "CharacterFrameRightPaneHost", sheet))
    sheet.RightPaneHost:SetWidth(233)
    sheet.RightPaneHost:EnableMouse(true)
    Own(sheet, "RightPaneToggleButton", New("Button", "CharacterFrameRightPaneToggleButton", sheet))
    sheet.RightPaneToggleButton:EnableMouse(true)
    Own(sheet, "ModeTabs", New("Frame", "CharacterFrameModeTabs", sheet))
    sheet.ModeTabs:EnableMouse(true)
    Own(sheet.ModeTabs, "Tabs", {})
    local SUBFRAMES = { "PaperDollFrame", "ReputationFrame", "SkillsFrame", "PVPRankFrame", "TokenFrame", "StatisticsFrame" }
    for i, frameName in ipairs(SUBFRAMES) do
        local tab = New("Frame", "CharacterFrameModeTab" .. i, sheet.ModeTabs)
        tab:SetSize(48, 44)
        tab:SetPoint("TOPLEFT", sheet.ModeTabs, "TOPLEFT", 0, -46 * (i - 1))
        tab:EnableMouse(true)
        tab:SetHitRectInsets(4, 4, 4, 4)
        Own(tab, "frameName", frameName)
        Own(tab, "tooltipText", frameName)
        tab:SetScript("OnEnter", function() game.tabTips = (game.tabTips or 0) + 1 end)
        sheet.ModeTabs.Tabs[i] = tab
    end
    st[sheet.ModeTabs.Tabs[6]].shown = options.statisticsTab ~= false
    function sheet:UpdateSize() self:SetSize(st[self].collapsed and 438 or 676, 540) end
    function sheet:ShowSubFrame(frameName)
        Own(self, "activeSubframe", frameName)
        for _, name in ipairs(SUBFRAMES) do if env[name] and name ~= frameName then env[name]:Hide() end end
        if env[frameName] then env[frameName]:Show() end
    end
    function sheet:Expand()
        env.PaperDollSidebarTabs:Show()
        env.CharacterStatsPaneScrollBox:Show()
    end
    function sheet:RefreshRightPane()
        self.RightPaneHost:SetShown(not st[self].collapsed)
        for _, pane in ipairs(self.SidePanes) do pane:SetShown(not st[self].collapsed) end
    end
    -- The game's own open or close of its right pane (a currency's click opens
    -- it): its panes shown or hidden, then the window sized.
    function sheet:SetRightPaneCollapsed(collapsed)
        if st[self].collapsed == collapsed then return end
        st[self].collapsed = collapsed
        game.paneOpens = (game.paneOpens or 0) + (collapsed and 0 or 1)
        self:RefreshRightPane()
        self:UpdateSize()
    end
    Own(sheet, "SidePanes", {})

    local paper = New("Frame", "PaperDollFrame", sheet)
    paper:SetAllPoints(sheet)
    st[paper].level = 10
    for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight" }) do
        Own(paper, key, paper:CreateTexture(nil, "BACKGROUND"))
    end
    -- Forever's level-line strip (build 70450): a rock strip across the left pane.
    Own(paper, "TopBackgroundStripHost", New("Frame", nil, paper))
    paper.TopBackgroundStripHost:SetPoint("TOPLEFT", sheet.LeftPaneHost, "TOPLEFT")
    paper.TopBackgroundStripHost:SetPoint("TOPRIGHT", sheet.LeftPaneHost, "TOPRIGHT")
    paper.TopBackgroundStripHost:SetHeight(36)
    Own(paper.TopBackgroundStripHost, "TopBackgroundStrip", paper.TopBackgroundStripHost:CreateTexture(nil, "ARTWORK"))
    Own(paper, "EquipmentManagerPane", New("Frame", nil, paper))
    local setList = paper.EquipmentManagerPane
    setList:SetPoint("TOPLEFT", sheet.RightPaneHost, "TOPLEFT", 10, -10)
    setList:SetPoint("BOTTOMRIGHT", sheet.RightPaneHost, "BOTTOMRIGHT", -10, 10)
    setList:CreateTexture(nil, "BACKGROUND")
    setList:CreateTexture(nil, "BORDER")
    st[setList].shown = false
    st[setList].level = 30
    Own(paper, "TitleManagerPane", New("Frame", nil, paper))
    New("Frame", "CharacterStatsPane", sheet)
    New("Frame", "CharacterStatsPaneScrollBox", sheet)
    New("Frame", "CharacterStatsPanePetScrollBox", sheet)
    New("Frame", "PaperDollSidebarTabs", sheet)
    New("Frame", "PaperDollLevelInfo", sheet)
    env.CharacterLevelText = env.PaperDollLevelInfo:CreateFontString(nil, "ARTWORK")
    for _, frame in ipairs({ env.CharacterStatsPane, env.CharacterStatsPaneScrollBox, env.PaperDollSidebarTabs }) do
        frame:EnableMouse(true)
        local inner = New("Button", nil, frame)
        inner:EnableMouse(true)
        New("Button", nil, inner):EnableMouse(true)
    end
    env.PAPERDOLL_SIDEBARS = { 1, 2, 3, 4 }
    env.GetPaperDollSideBarFrame = function(i)
        return ({ env.CharacterStatsPaneScrollBox, paper.EquipmentManagerPane, paper.TitleManagerPane,
            env.CharacterStatsPanePetScrollBox })[i]
    end
    env.PaperDollFrame_UpdateSidebarTabs = function() env.PaperDollSidebarTabs:SetAlpha(1) end

    -- Gear slots (item buttons with their gear-slot art).
    local items = New("Frame", "PaperDollItemsFrame", paper)
    items:SetAllPoints(paper)
    for _, short in ipairs({ "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist", "Hands", "Waist",
        "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1", "MainHand", "SecondaryHand", "Ranged", "Ammo" }) do
        local name = "Character" .. short .. "Slot"
        if not (options.missingSlot == short) then
            local slot = New("ItemButton", name, items)
            slot:SetSize(37, 37)
            slot:SetPoint("TOPLEFT", items, "TOPLEFT", 0, 0)
            Own(slot, "BorderFrame", New("Frame", nil, slot))
            env[name .. "Frame"] = slot:CreateTexture(nil, "BACKGROUND")
            Own(slot, "GetID", function() return ({ MainHand = 16, Ranged = 18, Ammo = 0 })[short] or 1 end)
        end
    end
    local ammo = env.CharacterAmmoSlot
    ammo:CreateTexture(nil, "BACKGROUND"):SetAtlas("UI-Character-Info-GearSlot")
    New("Frame", nil, ammo):CreateTexture(nil, "ARTWORK"):SetAtlas("ui-character-info-gearslot-ammo")

    -- The model scene.
    local scene = New("ModelScene", "CharacterModelScene", paper)
    Own(paper, "CharacterModelScene", scene)
    scene:SetPoint("TOPLEFT", paper, "TOPLEFT", 0, -60)
    scene:SetSize(398, 400)
    st[scene].level = 50
    for _, key in ipairs({ "BackgroundTopLeft", "BackgroundTopRight", "BackgroundBotLeft", "BackgroundBotRight",
        "BackgroundOverlay" }) do Own(scene, key, scene:CreateTexture(nil, "BACKGROUND")) end
    Own(scene, "ControlFrame", New("Frame", nil, scene))
    scene.ControlFrame:EnableMouse(true)
    Own(scene, "GearEnchantAnimation", New("Frame", nil, scene))
    local function Camera(name)
        local camera = setmetatable({}, Meta)
        st[camera] = { kind = "Camera", name = name, game = true, scripts = {}, hooks = {} }
        made[#made + 1] = camera
        Own(camera, "zoom", 0)
        Own(camera, "yaw", 0)
        function camera:OnMouseWheel(delta) Own(self, "zoom", self.zoom - delta) end
        function camera:GetYaw() return self.yaw end
        function camera:SetYaw(yaw) Own(self, "yaw", yaw) end
        function camera:SnapToTargetInterpolationYaw() Own(self, "snaps", (self.snaps or 0) + 1) end
        return camera
    end
    game.camera = Camera("first")
    game.actor = setmetatable({}, Meta)
    st[game.actor] = { kind = "Actor", game = true, scripts = {}, hooks = {} }
    made[#made + 1] = game.actor
    Own(game.actor, "yaw", 0)
    function game.actor:GetYaw() return self.yaw end
    function game.actor:SetYaw(yaw) Own(self, "yaw", yaw) end
    function scene:GetActiveCamera() return game.camera end
    function scene:GetPlayerActor()
        if game.noActor then return nil end
        return game.actor
    end
    function scene:GetActorByTag(tag) return (not game.noActor and tag == "player") and game.actor or nil end
    function scene:TransitionToModelSceneID(id) game.camera = GameMakes(Camera, "scene" .. tostring(id)) end
    function scene:OnMouseWheel(delta) game.camera:OnMouseWheel(delta) end

    ---------------------------------------------------------------------------
    -- The lists
    ---------------------------------------------------------------------------
    local function ScrollBar(parent)
        local bar = New("EventFrame", nil, parent)
        bar:SetSize(10, 200)
        Own(bar, "Track", New("Frame", nil, bar))
        bar.Track:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -16)
        bar.Track:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 16)
        for _, key in ipairs({ "Begin", "Middle", "End" }) do Own(bar.Track, key, bar.Track:CreateTexture(nil, "ARTWORK")) end
        Own(bar.Track, "Thumb", New("Frame", nil, bar.Track))
        for _, key in ipairs({ "Begin", "Middle", "End" }) do Own(bar.Track.Thumb, key, bar.Track.Thumb:CreateTexture(nil, "ARTWORK")) end
        for _, key in ipairs({ "Back", "Forward" }) do
            local arrow = New("Button", nil, bar)
            arrow:SetSize(17, 11)
            arrow:SetPoint(key == "Back" and "TOP" or "BOTTOM", bar, key == "Back" and "TOP" or "BOTTOM", 0, 0)
            Own(arrow, "Texture", arrow:CreateTexture(nil, "ARTWORK"))
            arrow:SetNormalTexture("minimal-arrow")
            Own(bar, key, arrow)
        end
        Own(bar, "scrollable", true)
        function bar:HasScrollableExtent() return self.scrollable end
        function bar:SetScrollPercentageInternal(fraction) Own(self, "fraction", fraction) end
        function bar:Update() end
        return bar
    end
    game.ScrollBar = ScrollBar

    local lists = {}
    game.lists = lists
    local function List(name, id)
        local list = New("Frame", name, sheet)
        list:SetAllPoints(sheet)
        st[list].shown = false
        Own(list, "ScrollBox", New("Frame", nil, list))
        local box = list.ScrollBox
        box:SetPoint("TOPLEFT", sheet.LeftPaneHost, "TOPLEFT", 10, -40)
        box:SetPoint("BOTTOMRIGHT", sheet.LeftPaneHost, "BOTTOMRIGHT", -25, 15)
        local line = New("Frame", nil, box)
        line:CreateTexture(nil, "OVERLAY"):SetAtlas("UI-Character-Info-ScrollLine-Long")
        Own(box, "ScrollTarget", New("Frame", nil, box))
        box.ScrollTarget:SetPoint("TOPLEFT", box, "TOPLEFT")
        box.ScrollTarget:SetPoint("TOPRIGHT", box, "TOPRIGHT")
        box.ScrollTarget:SetHeight(2000)
        st[box].rows = {}
        function box:ForEachFrame(fn) for _, row in ipairs(st[self].rows) do fn(row) end end
        Own(list, "ScrollBar", ScrollBar(list))
        list.ScrollBar:SetPoint("TOPLEFT", box, "TOPRIGHT", 5, -2)
        list.ScrollBar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 5, 4)
        function list:Update() game.updates = (game.updates or 0) + 1 end
        lists[id] = list
        return list
    end
    List("SkillsFrame", "skills")
    List("ReputationFrame", "reputation")
    List("TokenFrame", "currency")
    List("StatisticsFrame", "statistics")
    Own(env.ReputationFrame, "filterDropdown", New("Button", nil, env.ReputationFrame))
    env.ReputationFrame.filterDropdown:SetSize(100, 20)

    -- The skill detail pane (one of the window's side panes) and its rank
    -- bar, made with the UI before EraUI loads.
    local pane = New("Frame", nil, env.SkillsFrame)
    Own(env.SkillsFrame, "SkillDetailFrame", pane)
    table.insert(sheet.SidePanes, pane)
    pane:EnableMouse(true)
    for _, key in ipairs({ "Title", "Subtitle" }) do Own(pane, key, pane:CreateFontString(nil, "ARTWORK")) end
    Own(pane, "Content", New("Frame", nil, pane))
    Own(pane, "Description", New("Frame", nil, pane))
    Own(pane.Description, "ScrollBox", New("Frame", nil, pane.Description))
    Own(pane.Description.ScrollBox, "FontStringContainer", New("Frame", nil, pane.Description.ScrollBox))
    local holder = pane.Description.ScrollBox.FontStringContainer
    Own(holder, "FontString", holder:CreateFontString(nil, "ARTWORK"))
    function pane.Description:SetFontObject(font) holder.FontString:SetFontObject(font) end
    function pane.Description.ScrollBox:FullUpdate() game.fullUpdates = (game.fullUpdates or 0) + 1 end
    Own(pane, "DescriptionScrollBar", ScrollBar(pane))
    Own(pane, "RankBar", game.Bar(pane, env.SkillsBarMixin, 180))
    function pane:Refresh() game.paneRefreshes = (game.paneRefreshes or 0) + 1 end
    local repPane = New("Frame", nil, env.ReputationFrame)
    Own(env.ReputationFrame, "ReputationDetailFrame", repPane)
    repPane:EnableMouse(true)
    table.insert(sheet.SidePanes, repPane)

    -- The Currency tab (Camelot Blizzard_TokenUI): its detail pane
    -- (TokenDetailFrame, from CharacterFrameSidePaneTemplate: HIGH strata, on
    -- the right pane) with the Unused and Show on Backpack ticks and the
    -- transfer button; the tab's selection (first currency on show, cleared
    -- on hide), Update and SetTokenWatched. Every click below is the game's.
    local coins = env.TokenFrame
    local coinPane = New("Frame", "TokenDetailFrame", coins)
    Own(coins, "DetailFrame", coinPane)
    table.insert(sheet.SidePanes, coinPane)
    coinPane:SetFrameStrata("HIGH")
    coinPane:EnableMouse(true)
    coinPane:SetPoint("TOPLEFT", sheet.RightPaneHost, "TOPLEFT", 16, -14)
    coinPane:SetPoint("BOTTOMRIGHT", sheet.RightPaneHost, "BOTTOMRIGHT", -12, 14)
    for _, key in ipairs({ "Title", "Subtitle", "EmptyText" }) do Own(coinPane, key, coinPane:CreateFontString(nil, "ARTWORK")) end
    Own(coinPane, "Divider", coinPane:CreateTexture(nil, "BORDER"))
    coinPane.Divider:SetAtlas("UI-Character-Info-ScrollLine", true)
    Own(coinPane, "Description", New("Frame", nil, coinPane))
    Own(coinPane, "DescriptionScrollBar", ScrollBar(coinPane))
    Own(coinPane, "Content", New("Frame", nil, coinPane))
    Own(coinPane, "Footer", New("Frame", nil, coinPane))
    coinPane.Footer:SetHeight(90)
    coinPane.Footer:SetPoint("BOTTOMLEFT", coinPane, "BOTTOMLEFT")
    coinPane.Footer:SetPoint("BOTTOMRIGHT", coinPane, "BOTTOMRIGHT")
    local function Tick(key, words)
        local tick = New("CheckButton", nil, coinPane)
        tick:SetSize(26, 26)
        tick:EnableMouse(true)
        for _, state in ipairs({ "Normal", "Pushed", "Checked", "DisabledChecked" }) do
            tick["Set" .. state .. "Texture"](tick)
            tick["Get" .. state .. "Texture"](tick):SetAtlas(state:find("Checked") and "checkmark-minimal" or "checkbox-minimal", true)
        end
        Own(tick, "Label", tick:CreateFontString(nil, "ARTWORK", "GameFontNormal"))
        tick.Label:SetText(words)
        tick.Label:SetPoint("LEFT", tick, "RIGHT", 2, 0)
        Own(coinPane, key, tick)
        return tick
    end
    local unused, backpack = Tick("InactiveCheckbox", "Unused"), Tick("BackpackCheckbox", "Show on Backpack")
    unused:SetPoint("TOPLEFT", coinPane.Footer, "TOPLEFT", -4, 0)
    backpack:SetPoint("TOPLEFT", unused, "BOTTOMLEFT", 0, -2)
    unused:SetScript("OnClick", function(self)
        env.PlaySound(self:GetChecked() and env.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or env.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
        env.C_CurrencyInfo.SetCurrencyUnused(coins.selectedID, self:GetChecked())
        coins:Update()
    end)
    backpack:SetScript("OnClick", function(self)
        local watched = self:GetChecked()
        if not coins:SetTokenWatched(coins.selectedID, watched) then
            self:SetChecked(false)
            return
        end
        env.PlaySound(watched and env.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or env.SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    end)
    local transfer = New("Button", nil, coinPane)
    transfer:SetSize(120, 22)
    transfer:EnableMouse(true)
    for _, key in ipairs({ "Left", "Middle", "Right" }) do Own(transfer, key, transfer:CreateTexture(nil, "BACKGROUND")) end
    transfer:SetPoint("TOP", backpack, "BOTTOM", 60, -8)
    st[transfer].shown = false
    Own(coinPane, "CurrencyTransferToggleButton", transfer)
    function coinPane:Refresh()
        game.coinRefreshes = (game.coinRefreshes or 0) + 1
        local info = coins.selectedID and game.currencies[coins.selectedID]
        if not info then
            self.Title:SetText("")
            self.EmptyText:SetText("Select a currency")
            self.EmptyText:Show()
            self.InactiveCheckbox:Hide()
            self.BackpackCheckbox:Hide()
            return
        end
        self.EmptyText:Hide()
        self.Title:SetText(info.name)
        self.Subtitle:SetText(tostring(info.quantity or 0))
        self.InactiveCheckbox:SetShown(info.discovered ~= false)
        self.InactiveCheckbox:SetChecked(info.isTypeUnused == true)
        self.BackpackCheckbox:SetShown(info.discovered ~= false)
        self.BackpackCheckbox:SetChecked(info.isShowInBackpack == true)
    end
    function coinPane:ClearSelectionIfMissing()
        local found = false
        for _, info in ipairs(game.currencies) do if info.name == coins.selectedToken then found = true end end
        if not found then
            Own(coins, "selectedToken", nil)
            Own(coins, "selectedID", nil)
        end
        self:Refresh()
    end
    coinPane:SetScript("OnShow", function(self) self:Refresh() end)
    -- game.reuseRows: the refill hands the entry rows each other's currency
    -- (the scroll box's pool gives frames back in another order).
    function coins:Update()
        game.updates = (game.updates or 0) + 1
        if game.reuseRows then
            local entries, held = {}, {}
            for _, row in ipairs(st[self.ScrollBox].rows) do
                if row.Content and row:IsShown() then entries[#entries + 1] = row end
            end
            for i, row in ipairs(entries) do held[i] = row.elementData end
            for i, row in ipairs(entries) do row:Initialize(held[#entries + 1 - i]) end
        end
        self.DetailFrame:Refresh()
    end
    function coins:SetTokenWatched(id, watched)
        if watched and game.watchFull then return false end
        env.C_CurrencyInfo.SetCurrencyBackpack(id, watched)
        self:Update()
        return true
    end
    coins:SetScript("OnShow", function(self)
        if not self.selectedID then
            for i, info in ipairs(game.currencies) do
                if not info.isHeader then
                    Own(self, "selectedToken", info.name)
                    Own(self, "selectedID", i)
                    break
                end
            end
        end
        self:Update()
    end)
    coins:SetScript("OnHide", function(self)
        Own(self, "selectedToken", nil)
        Own(self, "selectedID", nil)
    end)

    local pvp = New("Frame", "PVPRankFrame", sheet)
    pvp:SetAllPoints(sheet)
    st[pvp].shown = false
    Own(pvp, "MainInfoFrame", New("Frame", nil, pvp))

    -- Rows from the game's templates. Each row type's Initialize is the game's.
    local function MakeEntry(list, kind)
        local row = New("Button", nil, list.ScrollBox.ScrollTarget)
        row:SetHeight(30)
        Own(row, "Content", New("Frame", nil, row))
        row.Content:SetAllPoints(row)
        local content = row.Content
        Own(content, "BackgroundHighlight", New("Frame", nil, content))
        content.BackgroundHighlight:CreateTexture(nil, "BACKGROUND")
        Own(content, "Name", content:CreateFontString(nil, "OVERLAY", "GameFontHighlight"))
        if kind == "skills" then
            Own(content, "SkillsBar", game.Bar(content, env.SkillsBarMixin, 160))
            content.SkillsBar:SetPoint("RIGHT", content, "RIGHT", -3, 0)
        elseif kind == "currency" then
            -- TokenEntryTemplate: count, icon, the watched tick; its click is
            -- TokenEntryMixin:OnClick (select, or Shift to watch; a chosen
            -- currency opens the right pane; then the tab's Update).
            Own(content, "Count", content:CreateFontString(nil, "BORDER", "GameFontHighlightRight"))
            Own(content, "CurrencyIcon", content:CreateTexture(nil, "BORDER"))
            Own(content, "WatchedCurrencyCheck", content:CreateTexture(nil, "BORDER"))
            row:EnableMouse(true)
            row:SetScript("OnClick", function(self)
                local coins = env.TokenFrame
                if env.IsModifiedClick("TOKENWATCHTOGGLE") then
                    coins:SetTokenWatched(self.currencyIndex, not self.elementData.isShowInBackpack)
                elseif not env.IsModifiedClick("CHATLINK") then
                    Own(coins, "selectedToken", self.Content.Name:GetText())
                    Own(coins, "selectedID", self.currencyIndex)
                end
                if self.elementData.name == coins.selectedToken then sheet:SetRightPaneCollapsed(false) end
                coins:Update()
                coins.DetailFrame:ClearSelectionIfMissing()
            end)
        else
            Own(content, "ReputationBar", game.Bar(content, env.ReputationBarMixin, 120))
            content.ReputationBar:SetPoint("RIGHT", content, "RIGHT", -3, 0)
            Own(content, "AccountWideIcon", New("Frame", nil, content))
        end
        function row:Initialize(data)
            Own(self, "elementData", data)
            self.Content.Name:SetText(data.name)
            if kind == "currency" then
                Own(self, "currencyIndex", data.currencyIndex)
                self.Content.Count:SetText(tostring(data.quantity or 0))
                self.Content.WatchedCurrencyCheck:SetShown(data.isShowInBackpack == true)
                return
            end
            local bar = self.Content.SkillsBar or self.Content.ReputationBar
            if self.Content.SkillsBar then
                bar:SetFillTextureByColorType(3)
                bar:UpdateBarColor(1, 1, 1)
                bar:SetFillPercent(data.rank / data.maxRank)
                bar:SetText(data.rank .. " / " .. data.maxRank)
            else
                bar:SetFillPercent(data.share)
                bar:UpdateBarColor(0, 0.6, 0.1)
                bar:SetText(data.standing or "Friendly")
            end
        end
        return row
    end
    local function EntryRow(list, kind) return GameMakes(MakeEntry, list, kind) end
    local function MakeHeader(list)
        local row = New("Button", nil, list.ScrollBox.ScrollTarget)
        row:SetHeight(28)
        row:CreateTexture(nil, "BACKGROUND"):SetAtlas("common-button-list-collapseExpand")
        Own(row, "StateIcon", row:CreateTexture(nil, "BORDER"))
        Own(row, "Name", row:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft"))
        function row:Initialize(data)
            Own(self, "elementData", data)
            self.Name:SetText(data.name)
            self.StateIcon:SetAtlas(data.collapsed and "common-button-list-plus" or "common-button-list-minus", true)
        end
        function row:IsCollapsed() return self.elementData.collapsed == true end
        return row
    end
    local function HeaderRow(list) return GameMakes(MakeHeader, list) end
    -- The list's data: new rows when there are more lines than rows, every
    -- row filled; laid out (anchored in the box) only when asked.
    function game.Fill(id, lines, lay)
        local list = lists[id]
        local rows = st[list.ScrollBox].rows
        for i, data in ipairs(lines) do
            local wantHeader = data.header == true
            local row = rows[i]
            if not row or (row.Content == nil) ~= wantHeader then
                row = wantHeader and HeaderRow(list) or EntryRow(list, id)
                if rows[i] then rows[i]:Hide() end
                rows[i] = row
            end
            row:Show()
            row:Initialize(data)
        end
        for i = #lines + 1, #rows do rows[i]:Hide() end
        list:Update() -- the game's own update built these rows
        if lay then game.LayRows(id) end
        return rows
    end
    function game.LayRows(id)
        local list = lists[id]
        for i, row in ipairs(st[list.ScrollBox].rows) do
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", list.ScrollBox.ScrollTarget, "TOPLEFT", 0, -33 * (i - 1))
            row:SetPoint("TOPRIGHT", list.ScrollBox.ScrollTarget, "TOPRIGHT", 0, -33 * (i - 1))
        end
        game.Resize()
    end
    function game.Rows(id) return st[lists[id].ScrollBox].rows end

    ---------------------------------------------------------------------------
    -- The game's stat table (a short copy of Camelot's)
    ---------------------------------------------------------------------------
    local function SetLine(frame, label, text, number)
        frame.Label:SetText(string.format(env.STAT_FORMAT, label))
        frame.Value:SetText(text)
        frame.numericValue = number
    end
    game.statValues = { HEALTH = 120, POWER = 100, MOVESPEED = 7, MAINHAND_DAMAGE = 5, OFFHAND_DAMAGE = 0, RANGED_DAMAGE = 3,
        ATTACK_AP = 40, RANGED_ATTACK_AP = 0, HITCHANCE = 0, CRITCHANCE = 5, HASTE = 0, EXPERTISE = 0, ARMORPEN = 0,
        SPELLPOWER = 0, SPELLHEALING = 0, SPELLPENETRATION = 0, DEFENSE = 60, DODGE = 6, BLOCK = 5, PARRY = 0, ARMOR = 50,
        STRENGTH = 20, AGILITY = 25, STAMINA = 22, INTELLECT = 18, SPIRIT = 19 }
    env.PAPERDOLL_STATINFO = {}
    for stat in pairs(game.statValues) do
        env.PAPERDOLL_STATINFO[stat] = { updateFunc = function(frame, unit)
            assert(unit == "player", "the panes ask for the player")
            if game.statError == stat then error("this stat broke") end
            if game.statHides == stat then frame:Hide() return end
            local value = game.statValues[stat]
            SetLine(frame, stat:sub(1, 1) .. stat:sub(2):lower(), game.statEmpty == stat and "" or tostring(value), value)
            frame.tooltip = stat .. " " .. value
            if stat == "ARMOR" then frame.onEnterFunc = function() game.richTips = (game.richTips or 0) + 1 end end
        end }
    end
    for school, name in pairs({ [6] = "ARCANE_RESIST", [2] = "FIRE_RESIST", [4] = "FROST_RESIST", [3] = "NATURE_RESIST", [5] = "SHADOW_RESIST" }) do
        env.PAPERDOLL_STATINFO[name] = { updateFunc = function(frame)
            local value = game.resists[school]
            SetLine(frame, "Resist" .. school, tostring(value), value)
        end }
    end
    env.C_PaperDollInfo = { OffhandHasShield = function() return game.shield == true end }
    if not options.noStatCategories then
        env.PAPERDOLL_STATCATEGORIES = {
            { categoryName = "General", unit = "player", stats = { { stat = "HEALTH" }, { stat = "POWER" }, { stat = "MOVESPEED" } } },
            { categoryName = "Primary Attributes", unit = "player", stats = { { stat = "STRENGTH" }, { stat = "AGILITY" },
                { stat = "STAMINA" }, { stat = "INTELLECT" }, { stat = "SPIRIT" } } },
            { categoryName = "Weapons", unit = "player", stats = { { stat = "MAINHAND_DAMAGE" }, { stat = "OFFHAND_DAMAGE", hideAt = 0 },
                { stat = "RANGED_DAMAGE", hideAt = 0 }, { stat = "ATTACK_AP", hideAt = 0 }, { stat = "RANGED_ATTACK_AP", hideAt = 0 } } },
            { categoryName = "Modifiers", unit = "player", stats = { { stat = "HITCHANCE", hideAt = 0 }, { stat = "CRITCHANCE", hideAt = 0 },
                { stat = "HASTE", hideAt = 0 }, { stat = "EXPERTISE", hideAt = 0 }, { stat = "ARMORPEN", hideAt = 0 },
                { stat = "SPELLPOWER", hideAt = 0 }, { stat = "SPELLHEALING", hideAt = 0 }, { stat = "SPELLPENETRATION", hideAt = 0 } } },
            { categoryName = "Defense", unit = "player", stats = { { stat = "DEFENSE" }, { stat = "DODGE", hideAt = 0 },
                { stat = "BLOCK", hideAt = 0, showFunc = env.C_PaperDollInfo.OffhandHasShield }, { stat = "PARRY", hideAt = 0 },
                { stat = "ARMOR" } } },
            { categoryName = "General", unit = "pet", stats = { { stat = "HEALTH" } } },
        }
    end

    ---------------------------------------------------------------------------
    -- EraUI's side: the engine and Core/Appearance.lua
    ---------------------------------------------------------------------------
    local ns = { db = options.db or {}, DB_DEFAULTS = {}, modules = {} }
    function ns.RegisterModule(key, module)
        module.key = key
        ns.modules[#ns.modules + 1] = module
    end
    function ns.SetCVar(name, value)
        if game.combat then return false end
        game.cvarWrites = game.cvarWrites + 1
        if game.cvars[name] == value then return true end
        ns.db.cvarWas = ns.db.cvarWas or {}
        if ns.db.cvarWas[name] == nil then ns.db.cvarWas[name] = game.cvars[name] or "0" end
        game.cvars[name] = value
        return true
    end
    function ns.MirrorSave() game.saves = game.saves + 1 end
    function ns.ThemeTexture(texture, key) st[texture].theme = key end
    for _, name in ipairs({ "DarkBackdrop", "DarkWindowArt", "DarkCloseButton", "DarkRedButton", "DarkNativeButton" }) do
        ns[name] = function(object, ...) game.darkened[#game.darkened + 1] = { name, object, ... } end
    end
    function ns.CloseOnEscape(frame) game.escapes = (game.escapes or 0) + 1; game.escaped = frame end
    function ns.MissingPiece(name) game.missing = game.missing or {}; game.missing[name] = true end
    function ns.StatusBarsShowFaction() return game.stripsShowFaction == true end
    function ns.StatusBarsBusy() return game.stripsBusy == true end
    function ns.OnForever() local build = select(4, env.GetBuildInfo()) return build >= 16000 and build < 17000 end
    game.ns = ns
    game.settings = { enabled = true, darkMode = false }
    local E = { Classic = ns }
    function E:GetSetting(key) return game.settings[key] end
    game.E = E

    local FILES = { "Look/Base.lua", "Look/CharKit.lua", "Look/CharFrame.lua", "Look/CharStats.lua", "Look/CharTabs.lua",
        "Look/CharLists.lua", "Look/CharSkill.lua", "Look/CharRep.lua", "Look/CharCurrency.lua", "Look/CharEquip.lua", "Look/CharModule.lua",
        "Look/CharPanes.lua" }
    game.FILES = FILES
    -- Loads the look as the game does, after its own UI; the engine's
    -- defaults then go into the saved table.
    function game.Load()
        building = false
        game.Seal()
        if options.before then options.before(game, env) end
        for _, file in ipairs(FILES) do assert(loadfile(file, "t", env))("EraUI", E) end
        for key, value in pairs(ns.DB_DEFAULTS) do if ns.db[key] == nil then ns.db[key] = value end end
        game.Look, game.C = E.Look, E.Look.Char
        return game.C
    end
    -- The engine's pass: each entry's apply, or restore when its key is off;
    -- then the client's layout, as it runs before anything is drawn.
    function game.Pass()
        for _, module in ipairs(ns.modules) do
            if ns.db[module.key] ~= false then module.apply() else module.restore() end
        end
        game.Resize()
    end
    -- The window opened on a tab, as the game does it.
    function game.Open(frameName)
        sheet:ShowSubFrame(frameName or "PaperDollFrame")
        sheet:Show()
        sheet:UpdateSize()
        sheet:Expand()
        sheet:RefreshRightPane()
        game.Resize()
    end
    function game.Fire(event, ...)
        for _, obj in ipairs(made) do
            local s = st[obj]
            if s.events and s.events[event] and s.scripts.OnEvent then s.scripts.OnEvent(obj, event, ...) end
        end
    end
    -- OnSizeChanged wherever a size changed since last asked (the client's
    -- layout pass).
    -- (A rect the client can't place yet counts as -1 by -1: placing it is a
    -- size change too.)
    local function LaidSize(obj)
        local l, b, r, t = obj:Rect()
        if not l then return -1, -1 end
        local f = obj:GetEffectiveScale()
        return (r - l) / f, (t - b) / f
    end
    function game.Resize()
        for _, obj in ipairs(made) do
            local s = st[obj]
            if s.scripts and (s.scripts.OnSizeChanged or s.hooks.OnSizeChanged) then
                local w, h = LaidSize(obj)
                if s.lastW == nil then s.lastW, s.lastH = -1, -1 end
                if math.abs(s.lastW - w) > 0.001 or math.abs(s.lastH - h) > 0.001 then
                    s.lastW, s.lastH = w, h
                    if w >= 0 then Run(obj, "OnSizeChanged", w, h) end
                end
            end
        end
    end
    -- Time passing in steps: every visible frame's OnUpdate, due timers, the
    -- layout's size changes.
    function game.Tick(seconds, step)
        step = step or 0.05
        local done = 0
        while done < seconds - 1e-9 do
            game.now = game.now + step
            done = done + step
            for _, obj in ipairs(made) do
                local s = st[obj]
                if s.scripts and s.scripts.OnUpdate and obj:IsVisible() then s.scripts.OnUpdate(obj, step) end
            end
            local due = {}
            for i = #game.timers, 1, -1 do
                if game.timers[i].at <= game.now + 1e-9 then due[#due + 1] = table.remove(game.timers, i) end
            end
            for i = #due, 1, -1 do due[i].fn() end
            game.Resize()
        end
    end
    function game.State(obj) return st[obj] end
    function game.Seal1(obj) sealed[obj] = true end
    return game
end

return Mock
