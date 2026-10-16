-- Classic character window: the Skills list, skill detail and Reputation bar
-- fills (Classic/CharacterSheet.lua, the real file).
-- Forever 1.60.1 (70425) moved Blizzard's ColoredProgressBar fill onto
-- FillArea, a track 6 in from each side of the bar, and sizes the fill against
-- it (before: against the bar's own width). EraUI pins the fill to the bar's
-- own left edge and runs it the bar's width (rep bars 2 in), so a maxed bar
-- must still fill to its end and a partial one keep its share, on both builds:
-- filled before EraUI's hooks (the first dress), refilled on a recycled row,
-- after the bar changes size, and on the skill detail bar after it moves.
-- Nothing new is written on the game's bars and no secret is compared.
-- Run: fengari Tools/TestSkillBarFill.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 1e-6 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local SECRET = setmetatable({}, {
    __tostring = function() error("secret turned to text") end,
    __concat = function() error("secret joined to text") end,
    __eq = function() error("secret compared") end,
    __lt = function() error("secret compared") end, __le = function() error("secret compared") end,
    __sub = function() error("secret used in arithmetic") end, __mul = function() error("secret used in arithmetic") end,
    __index = function() error("secret indexed") end,
})

-- A permissive widget: the methods below keep state; any other method whose
-- name starts with one of these verbs is a no-op.
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Lock", "Unlock", "Add",
    "Clear", "Raise", "Lower", "Update", "Remove" }
local function IsMethodName(key)
    if type(key) ~= "string" then return false end
    for _, verb in ipairs(VERBS) do
        if key:sub(1, #verb) == verb and key:sub(#verb + 1, #verb + 1):match("^%u") then return true end
    end
    return false
end
local Methods = {}
local function Widget(props)
    local w = props or {}
    if w.shown == nil then w.shown = true end
    w.scripts = w.scripts or {}
    return setmetatable(w, { __index = function(_, key)
        local method = Methods[key]
        if method then return method end
        if IsMethodName(key) then return function() end end
    end })
end
function Methods:Show() self.shown = true end
function Methods:Hide() self.shown = false end
function Methods:SetShown(on) self.shown = on and true or false end
function Methods:IsShown() return self.shown end
function Methods:IsVisible() return self.shown end
function Methods:GetWidth() return self.width or 0 end
function Methods:GetFrameLevel() return 1 end
function Methods:GetID() return self.id or 0 end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:HookScript(name, fn) self.scripts[name] = fn end
function Methods:SetText(text) self.text = text end
function Methods:GetText() return self.text end
function Methods:CreateTexture() return Widget() end
function Methods:CreateFontString() return Widget() end
function Methods:GetHighlightTexture() return Widget() end

local ATLAS_W = 160 -- the fill's atlas size, which SetFillTextureByColorType gives it
local ROW_W = 360   -- a list row; the skinned skill bar runs 20 in from its left to 8 in from its right
local DETAIL_W = 320
local SKILL_W, REP_W, RANK_W = ROW_W - 28, 137, DETAIL_W - 46 - 70

-- build "70425": the fill sized against FillArea; "70374": against the bar.
local function Session(build)
    local s = { frames = {}, bars = {}, writes = {}, hooks = setmetatable({}, { __mode = "k" }) }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.unpack = table.unpack
    s.env = env
    env.issecretvalue = function(value) return rawequal(value, SECRET) end

    local function AddHook(obj, key, fn)
        s.hooks[obj] = s.hooks[obj] or {}
        s.hooks[obj][key] = s.hooks[obj][key] or {}
        table.insert(s.hooks[obj][key], fn)
    end
    local function RunHooks(obj, key, ...)
        for _, fn in ipairs(s.hooks[obj] and s.hooks[obj][key] or {}) do fn(obj, ...) end
    end
    s.RunHooks = RunHooks
    -- Post-hooks, kept beside the object (the game's wrapper is its own business).
    env.hooksecurefunc = function(obj, key, fn)
        assert(type(obj) == "table", "only methods are hooked here")
        assert(type(obj[key]) == "function", "hooksecurefunc on a missing method: " .. tostring(key))
        AddHook(obj, key, fn)
    end

    env.CreateFrame = function(_, name, parent)
        local f = Widget({ parent = parent, events = {} })
        function f:RegisterEvent(event) self.events[event] = true end
        s.frames[#s.frames + 1] = f
        if name then env[name] = f end
        return f
    end

    -- The game's bar (ColoredProgressBarTemplate with its mixin): its width
    -- from two side anchors on one frame, else its own size. Keys written on
    -- it are listed, past the four EraUI already kept there.
    local area = build ~= "70374"
    local KEPT = { fcui = true, fcuiInset = true, fcuiCoords = true, fcuiFill = true }
    function s.GameBar(templateWidth)
        local g = { width = templateWidth, points = {}, seen = templateWidth }
        local fill = Widget({ width = 0 })
        function fill:SetWidth(w)
            assert(not rawequal(w, SECRET), "a secret width")
            self.width = w
        end
        local fields = { Fill = fill, Text = Widget() }
        local methods = {}
        local bar = setmetatable({}, {
            __index = function(_, k)
                local v = fields[k]
                if v ~= nil then return v end
                v = methods[k] or Methods[k]
                if v then return v end
                if IsMethodName(k) then return function() end end
            end,
            __newindex = function(_, k, v)
                if not KEPT[k] then s.writes[#s.writes + 1] = k end
                fields[k] = v
            end,
        })
        if area then
            fields.FillArea = { GetWidth = function() return math.max(0, bar:GetWidth() - 12) end }
        end
        function methods:SetPoint(point, rel, _, x) g.points[point] = { rel = rel, x = x or 0 } end
        function methods:ClearAllPoints() g.points = {} end
        function methods:SetSize(w) g.width = w end
        function methods:SetWidth(w) g.width = w end
        function methods:GetWidth()
            local l, r = g.points.LEFT or g.points.TOPLEFT, g.points.RIGHT or g.points.TOPRIGHT
            if l and r and l.rel == r.rel then return math.max(0, (l.rel:GetWidth() or 0) - l.x + r.x) end
            return g.width
        end
        function methods:HookScript(name, fn) AddHook(bar, "script:" .. name, fn) end
        function methods:SetFillWidth(width)
            self.Fill:SetWidth(width)
            RunHooks(self, "SetFillWidth", width)
        end
        function methods:SetFillPercent(percent)
            local p = math.min(1, math.max(0, percent))
            self:SetFillWidth(p * (self.FillArea or self):GetWidth())
            self.Fill:SetTexCoord(0, p, 1, 0)
            RunHooks(self, "SetFillPercent", percent)
        end
        function methods:SetFillTextureByColorType(colorType)
            self.Fill:SetWidth(ATLAS_W)
            RunHooks(self, "SetFillTextureByColorType", colorType)
        end
        function methods:UpdateBarValues(minValue, maxValue, currentValue)
            local percent = 0
            if maxValue ~= 0 then percent = currentValue / maxValue end
            self:SetFillPercent(percent)
        end
        function methods:UpdateBarColor(color) RunHooks(self, "UpdateBarColor", color) end
        function methods:SetText(text)
            self.Text:SetText(text)
            RunHooks(self, "SetText", text)
        end
        -- The next layout pass: OnSizeChanged when its width changed.
        function g.Layout()
            local w = bar:GetWidth()
            if w ~= g.seen then
                g.seen = w
                RunHooks(bar, "script:OnSizeChanged", w, 13)
            end
        end
        s.bars[#s.bars + 1] = g
        return bar
    end
    function s.NextFrame() for _, g in ipairs(s.bars) do g.Layout() end end

    -- SkillsEntryMixin.InitializeBarForStandardSkill and the reputation entry.
    function s.FillSkill(bar, rank, maxRank)
        bar:SetFillTextureByColorType(3)
        bar:UpdateBarColor()
        bar:UpdateBarValues(0, maxRank, rank)
        bar:SetText(rank .. " / " .. maxRank)
    end
    function s.FillRep(bar, current, max)
        bar:UpdateBarValues(0, max, current)
        bar:UpdateBarColor()
    end
    local function Row(barKey, bar, data)
        local content = Widget({ Name = Widget({ text = data.name }) })
        content[barKey] = bar
        local row = Widget({ width = ROW_W, Content = content, data = data })
        function row:GetElementData() return self.data end
        return row
    end
    local function ListFrame(rows)
        local box = Widget({ rows = rows })
        function box:ForEachFrame(fn) for _, row in ipairs(self.rows) do fn(row) end end
        local frame = Widget({ ScrollBox = box })
        function frame:Update() end
        return frame
    end

    -- A skills list, the detail pane's rank bar and a reputation list, filled
    -- by the game before EraUI applies.
    s.skillBars = { s.GameBar(160), s.GameBar(160), s.GameBar(160) }
    s.FillSkill(s.skillBars[1], 10, 10)
    s.FillSkill(s.skillBars[2], 7, 10)
    s.FillSkill(s.skillBars[3], 3, 300)
    s.skillRows = {}
    for i, name in ipairs({ "Daggers", "Thrown", "Cooking" }) do
        s.skillRows[i] = Row("SkillsBar", s.skillBars[i], { name = name })
    end
    s.rankBar = s.GameBar(180)
    s.FillSkill(s.rankBar, 150, 300)
    s.detail = Widget({ width = DETAIL_W, RankBar = s.rankBar })
    env.SkillsFrame = ListFrame(s.skillRows)
    env.SkillsFrame.SkillDetailFrame = s.detail
    s.repBars = { s.GameBar(160), s.GameBar(160) }
    s.FillRep(s.repBars[1], 21000, 21000)
    s.FillRep(s.repBars[2], 1500, 3000)
    s.repRows = {
        Row("ReputationBar", s.repBars[1], { name = "Stormwind" }),
        Row("ReputationBar", s.repBars[2], { name = "Darnassus" }),
    }
    env.ReputationFrame = ListFrame(s.repRows)

    env.C_Timer = { After = function() end }
    env.StaticPopupDialogs = {}
    env.MELEE_ATTACK, env.RANGED_ATTACK = "Melee Attack", "Ranged Attack"
    env.INVSLOT_MAINHAND, env.INVSLOT_RANGED = 16, 18
    env.CharacterFrame = Widget({ width = 384 })
    env.PaperDollFrame = Widget()
    env.UnitLevel = function() return 2 end
    env.UnitRace = function() return "Human" end
    env.UnitClass = function() return "Rogue", "ROGUE" end
    env.UnitStat = function() return 20, 20, 0, 0 end
    env.UnitArmor = function() return 50, 50, 50, 0, 0 end
    env.UnitAttackPower = function() return 40, 0, 0 end
    env.UnitRangedAttackPower = function() return 30, 0, 0 end
    env.UnitDamage = function() return 3, 6 end
    env.UnitRangedDamage = function() return 2, 4, 8 end
    env.UnitResistance = function() return 0, 0 end
    env.GetShapeshiftForm = function() return 0 end
    env.GetInventoryItemID = function() return nil end
    env.C_Item = { GetItemInfoInstant = function() end }
    env.C_SkillInfo = {
        GetSkillLineInfoByID = function() end,
        GetNumSkillLines = function() return 0 end,
        GetSkillLineInfo = function() end,
        GetSelectedSkill = function() return 0 end,
    }
    env.GameTooltip = Widget()

    local ns = { db = {}, modules = {} }
    function ns.RegisterModule(key, module) ns.modules[key] = module end
    function ns.SafeCall(fn, ...) return fn(...) end
    function ns.SetTex() end
    function ns.TexPath(key) return key end
    function ns.Fade() end
    function ns.OnForever() return true end
    function ns.HookMethod(obj, key, fn) AddHook(obj, key, fn) end
    function ns.HookGlobal() end
    function ns.SetCVar() end
    function ns.MissingPiece(name) error("missing " .. name) end
    function ns.PanelButton() return Widget() end
    function ns.OwnTexture(frame, key)
        frame.fcui = frame.fcui or {}
        frame.fcui[key] = frame.fcui[key] or frame:CreateTexture()
        return frame.fcui[key]
    end
    function ns.OwnFontString(frame, key)
        frame.fcui = frame.fcui or {}
        frame.fcui[key] = frame.fcui[key] or frame:CreateFontString()
        return frame.fcui[key]
    end
    s.ns = ns
    assert(loadfile("Classic/CharacterSheet.lua", "t", env))("EraUI", { Classic = ns })
    ns.modules.characterSheet.apply()

    -- The list's own poll, a frame later: rows whose data changed are dressed again.
    function s.Poll(frame)
        for _, f in ipairs(s.frames) do
            if f.parent == frame and f.scripts.OnUpdate then
                f.scripts.OnUpdate(f, 1)
                return
            end
        end
        error("no poll on the list")
    end
    -- The detail pane's Refresh (SkillDetailFrameMixin), then EraUI's post-hook.
    function s.RefreshDetail(rank, maxRank)
        s.FillSkill(s.rankBar, rank, maxRank)
        RunHooks(s.detail, "Refresh")
    end
    function s.Width(bar) return bar.Fill:GetWidth() end
    return s
end

for _, build in ipairs({ "70425", "70374" }) do
    local s = Session(build)
    local on = " (" .. build .. ")"

    -- First dress: filled by the game before EraUI's hooks.
    Near(s.Width(s.skillBars[1]), SKILL_W, "a maxed skill fills its bar" .. on)
    Near(s.Width(s.skillBars[2]), 0.7 * SKILL_W, "a skill at 7/10 fills 70%" .. on)
    Near(s.Width(s.skillBars[3]), 0.01 * SKILL_W, "a skill at 3/300 fills 1%" .. on)
    Near(s.Width(s.repBars[1]), REP_W - 2, "an Exalted rep bar fills to 2 in from its end" .. on)
    Near(s.Width(s.repBars[2]), 0.5 * (REP_W - 2), "a half rep bar fills half" .. on)
    Near(s.Width(s.rankBar), 0.5 * RANK_W, "the skill detail bar at 150/300 fills half" .. on)
    s.Poll(s.env.SkillsFrame)
    s.Poll(s.env.ReputationFrame)
    s.NextFrame()
    Near(s.Width(s.skillBars[1]), SKILL_W, "still full a frame later" .. on)
    Near(s.Width(s.repBars[2]), 0.5 * (REP_W - 2), "the rep bar still half a frame later" .. on)

    -- A recycled row: the game fills it again, the list dresses it again.
    s.FillSkill(s.skillBars[1], 7, 10)
    Near(s.Width(s.skillBars[1]), 0.7 * SKILL_W, "refilled at 7/10: 70% at once" .. on)
    s.skillRows[1].data = { name = "Thrown" }
    s.Poll(s.env.SkillsFrame)
    Near(s.Width(s.skillBars[1]), 0.7 * SKILL_W, "and after the row is dressed again" .. on)
    s.FillSkill(s.skillBars[1], 10, 10)
    s.skillRows[1].data = { name = "Daggers" }
    s.Poll(s.env.SkillsFrame)
    Near(s.Width(s.skillBars[1]), SKILL_W, "refilled at max: full" .. on)
    s.FillRep(s.repBars[2], 3000, 3000)
    Near(s.Width(s.repBars[2]), REP_W - 2, "a rep bar refilled at max: full" .. on)
    s.FillRep(s.repBars[1], 0, 3000)
    Equal(s.Width(s.repBars[1]), 0, "a rep bar refilled empty: empty" .. on)

    -- The bar changes size: the fill follows on the next layout pass.
    for _, row in ipairs(s.skillRows) do row.width = 300 end
    s.NextFrame()
    Near(s.Width(s.skillBars[1]), 300 - 28, "a full bar made narrower stays full" .. on)
    Near(s.Width(s.skillBars[2]), 0.7 * (300 - 28), "a 70% bar keeps its share" .. on)

    -- The skill detail bar is skinned off its pane and then moved back each
    -- time: the fill is fitted where it ends up.
    s.RefreshDetail(300, 300)
    Near(s.Width(s.rankBar), RANK_W, "the skill detail bar at max fills it" .. on)
    s.NextFrame()
    Near(s.Width(s.rankBar), RANK_W, "still full a frame later" .. on)
    s.RefreshDetail(75, 300)
    Near(s.Width(s.rankBar), 0.25 * RANK_W, "and at 75/300 a quarter" .. on)

    -- A secret share (no game value is, but a hook mustn't compare one).
    local before = s.Width(s.skillBars[2])
    s.RunHooks(s.skillBars[2], "SetFillPercent", SECRET)
    Equal(s.Width(s.skillBars[2]), before, "a secret share leaves the fill as it was" .. on)

    Equal(table.concat(s.writes, ", "), "", "no new key written on the game's bars" .. on)
end

print("Skill bar fill checks passed: " .. checks .. " assertions.")
