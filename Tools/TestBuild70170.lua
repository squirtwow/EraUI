-- Build 70170 (Forever 1.60.1) changes, with the real files:
-- * Classic/Professions.lua: the Professions window now remembers the last
--   profession and casts it again when it opens. EraUI's spellbook tab sends
--   it to the book page first (no cast from EraUI's code), and the shut window
--   forgets the profession, so the micro button still opens the book as in
--   1.5.0. The old tab workaround is gone.
-- * Modules/QoL.lua: Bag Space is the game's new Show Free Bag Space switch
--   where the game has it (read at login and on change, written on a flip in
--   EraUI, never in a fight); the old hook only without it.
-- * Classic/BarSkins.lua: the backpack's new FreeSlots text is styled, and
--   its Count (now the game's leftover ammo count) is hidden by alpha.
-- * Classic/GroupFinder.lua: Create Listing's new play style drop down is
--   dressed and kept clear of the level ranges tick.
-- (The new event registrations are checked by Tools/TestBuild70170.mjs.)
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local SECRET = setmetatable({}, {
    __tostring = function() error("secret turned to text") end,
    __lt = function() error("secret compared") end, __le = function() error("secret compared") end,
    __sub = function() error("secret used in arithmetic") end, __add = function() error("secret used in arithmetic") end,
})

-- A permissive widget: the methods below keep state; any other method (a
-- name starting with one of these verbs) is a recorded no-op, so the
-- modules' cosmetic calls need no list. Other keys are plain fields (nil
-- unless set), like a child the frame doesn't have.
local VERBS = { "Set", "Get", "Enable", "Disable", "Register", "Unregister", "Lock", "Unlock", "Add",
    "Clear", "Raise", "Lower", "Update" }
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
    w.calls = {}
    if w.shown == nil then w.shown = true end
    w.points = w.points or {}
    w.scripts = w.scripts or {}
    w.attrs = w.attrs or {}
    return setmetatable(w, { __index = function(_, key)
        local method = Methods[key]
        if method then return method end
        if IsMethodName(key) then
            return function(self, ...)
                local call = { key, ... }
                self.calls[#self.calls + 1] = call
            end
        end
    end })
end
function Methods:Show()
    if self.shown then return end
    self.shown = true
    if self.OnShowScript then self:OnShowScript() end
end
function Methods:Hide() self.shown = false end
function Methods:SetShown(on) if on then self:Show() else self:Hide() end end
function Methods:IsShown() return self.shown end
function Methods:IsVisible()
    if not self.shown then return false end
    if self.parent then return self.parent:IsVisible() end
    return true
end
function Methods:GetWidth() return self.width or 0 end
function Methods:SetWidth(w) self.width = w end
function Methods:GetHeight() return self.height or 0 end
function Methods:SetHeight(h) self.height = h end
function Methods:SetSize(w, h) self.width, self.height = w, h end
function Methods:GetLeft() return self.left end
function Methods:ClearAllPoints() self.points = {} end
function Methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Methods:GetPoint(i) local p = self.points[i or 1]; if p then return table.unpack(p) end end
function Methods:SetFontObject(font) self.font = font end
function Methods:GetAttribute(key) return self.attrs[key] end
function Methods:SetAttribute(key, value) self.attrs[key] = value end
function Methods:GetAlpha() return self.alpha or 1 end
function Methods:SetAlpha(a) self.alpha = a end
function Methods:IsMouseEnabled() return self.mouse ~= false end
function Methods:EnableMouse(on) self.mouse = on and true or false end
function Methods:GetFrameLevel() return self.level or 1 end
function Methods:SetFrameLevel(level) self.level = level end
function Methods:SetScript(name, fn) self.scripts[name] = fn end
function Methods:GetScript(name) return self.scripts[name] end
function Methods:HookScript(name, fn) self.scripts[name] = fn end
function Methods:SetChecked(on) self.checked = on and true or false end
function Methods:GetChecked() return self.checked end
function Methods:SetText(text) self.text = text end
function Methods:GetText() return self.text end
function Methods:CreateTexture() return Widget() end
function Methods:CreateFontString() return Widget() end
function Methods:IsObjectType() return false end
function Methods:GetRegions() return end

local function Session()
    local s = { frames = {}, timers = {}, clock = 100, combat = false, persisted = {} }
    local env = setmetatable({}, { __index = _G })
    env._G = env
    s.env = env
    env.CreateFrame = function(_, name, parent)
        local f = Widget({ events = {}, parent = parent })
        function f:RegisterEvent(event) self.events[event] = true end
        function f:UnregisterEvent(event) self.events[event] = nil end
        s.frames[#s.frames + 1] = f
        if name then env[name] = f end
        return f
    end
    env.InCombatLockdown = function() return s.combat end
    env.GetTime = function() return s.clock end
    env.C_Timer = { After = function(_, fn) s.timers[#s.timers + 1] = fn end }
    env.hooksecurefunc = function(object, method, hook)
        s.hooks = (s.hooks or 0) + 1
        local original = object[method]
        object[method] = function(...)
            local result = original(...)
            hook(...)
            return result
        end
    end
    env.issecretvalue = function(value) return value == SECRET end
    function s.Fire(event, ...)
        for _, f in ipairs(s.frames) do
            local handler = f.scripts.OnEvent
            if f.events[event] and handler then handler(f, event, ...) end
        end
    end
    function s.Tick(times)
        for _ = 1, times or 1 do
            s.clock = s.clock + 0.2
            for _, f in ipairs(s.frames) do
                local tick = f.scripts.OnUpdate
                if tick then tick(f, 0.2) end
            end
        end
    end
    local ns = { db = {}, modules = {} }
    function ns.RegisterModule(key, module) ns.modules[key] = module end
    function ns.Persist(line) s.persisted[#s.persisted + 1] = line end
    function ns.SafeCall(fn, ...) return fn(...) end
    s.ns = ns
    s.E = { Classic = ns, modules = {}, settings = {} }
    function s.E:RegisterModule(name, module) self.modules[name] = module end
    function s.E:GetSetting(key) return self.settings[key] end
    function s.E:SetSetting(key, value) self.settings[key] = value; s.settingWrites = (s.settingWrites or 0) + 1 end
    function s.E:Print(line) s.printed = line end
    function s.Load(path) assert(loadfile(path, "t", env))("EraUI", s.E) end
    return s
end

---------------------------------------------------------------------------
-- Professions window (Classic/Professions.lua)
---------------------------------------------------------------------------
local TAILORING = 197

-- Blizzard's window as build 70170 has it (recasts = true), or as before.
local function Professions(s, recasts)
    local env = s.env
    local frame = Widget({ shown = false, width = 750, height = 600 })
    s.frame = frame
    s.casts, s.blocked, s.selects, s.order = 0, 0, 0, {}
    s.tradeSkill = 0
    frame.BookPage = Widget({ parent = frame, shown = true })
    frame.CraftingPage = Widget({ parent = frame, shown = false })
    frame.ProfessionsOverviewTab = Widget({ parent = frame })
    local tab = Widget({ parent = frame, skillLine = TAILORING })
    frame.rightProfessionTabs = { tab }
    frame.TitleContainer = { TitleText = Widget() }
    frame.PortraitContainer = { portrait = Widget() }
    function frame:RightTabSelected(selected) self.selectedSkillLine = selected.skillLine end
    function frame:SelectBookPage()
        s.selects = s.selects + 1
        s.order[#s.order + 1] = "select"
        if s.selectFails then error("select failed") end
        self.BookPage:Show()
        self.CraftingPage:Hide()
        self:RightTabSelected(self.ProfessionsOverviewTab)
    end
    -- The player's trade skill opening (a profession spell, or the window's
    -- own cast): the window shows the crafting page and remembers the tab.
    function s.OpenTradeSkill(skillLine)
        s.tradeSkill = skillLine
        frame.BookPage:Hide()
        frame.CraftingPage:Show()
        frame.selectedSkillLine = skillLine
        s.Fire("TRADE_SKILL_SHOW")
        frame:Show()
    end
    local function Cast(skillLine)
        s.order[#s.order + 1] = "cast"
        if s.addonCall then
            s.blocked = s.blocked + 1
            return
        end
        s.casts = s.casts + 1
        s.OpenTradeSkill(skillLine)
    end
    if recasts then
        function frame:RecastSelectedProfession()
            if s.tradeSkill ~= 0 then return end
            if self.selectedSkillLine then
                Cast(self.selectedSkillLine)
                return
            end
            self:SelectBookPage()
        end
    end
    function frame:OnShowScript()
        s.order[#s.order + 1] = "show"
        if self.RecastSelectedProfession then self:RecastSelectedProfession() end
    end
    function s.Close()
        frame:Hide()
        s.tradeSkill = 0
    end
    env.ProfessionsFrame = frame
    env.ShowUIPanel = function(f)
        s.panels = (s.panels or 0) + 1
        if not f:IsShown() then f:Show() end
    end
    env.ToggleFrame = function(f) if f:IsShown() then f:Hide() else f:Show() end end
    env.UIErrorsFrame = Widget()
    env.ERR_NOT_IN_COMBAT = "You can't do that in combat."
    env.TRADE_SKILLS = "Professions"
    env.EventRegistry = setmetatable({}, { __index = function() s.registry = (s.registry or 0) + 1; return function() end end })
    s.Load("Classic/Professions.lua")
    -- The micro button (secure, the player's own click).
    function s.MicroButton()
        s.addonCall = false
        env.ToggleFrame(frame)
    end
    -- EraUI's spellbook Professions tab (EraUI's own code).
    function s.BookTab()
        s.addonCall = true
        local ok = s.ns.OpenProfessionsBook()
        s.addonCall = false
        return ok
    end
    return frame
end

-- 1. EraUI's spellbook tab with a remembered profession: forgotten first,
-- then opened on the book; nothing cast from EraUI's code.
do
    local s = Session()
    local frame = Professions(s, true)
    s.ns.modules.professionsBook.apply()
    s.OpenTradeSkill(TAILORING)
    Equal(frame.selectedSkillLine, TAILORING, "setup: the window remembers Tailoring")
    s.Close()
    frame.CraftingPage:Show(); frame.BookPage:Hide() -- as the window was left
    frame.selectedSkillLine = TAILORING
    s.combat = true
    Equal(s.BookTab(), false, "in a fight the book tab does nothing")
    Equal(s.selects, 0, "nothing chosen in a fight")
    Equal(frame:IsShown(), false, "the window stays shut in a fight")
    s.combat = false
    s.order = {}
    Equal(s.BookTab(), true, "the book tab opens the window")
    Equal(s.order[1], "select", "the book page is chosen before the window opens")
    Equal(s.order[2], "show", "then the window opens")
    Equal(s.blocked, 0, "no cast from EraUI's code")
    Equal(s.casts, 0, "and none at all")
    Equal(frame.BookPage:IsShown(), true, "the book page shows")
    Equal(frame.CraftingPage:IsShown(), false, "not the last profession")
    Equal(frame.selectedSkillLine, nil, "the remembered profession is forgotten")
    Equal(s.registry, nil, "the old tab workaround is gone (no EventRegistry use)")
end

-- 2. Nothing remembered: no needless choice; shown window: no reopening.
do
    local s = Session()
    local frame = Professions(s, true)
    s.ns.modules.professionsBook.apply()
    s.order = {}
    Equal(s.BookTab(), true, "opens with nothing remembered")
    Equal(s.order[1], "show", "nothing chosen first when nothing is remembered")
    Equal(s.blocked + s.casts, 0, "no cast")
    local panels = s.panels
    frame.selectedSkillLine = TAILORING
    s.selects = 0
    Equal(s.BookTab(), true, "already open: still true")
    Equal(s.selects, 0, "an open window is not sent to the book page by its memory")
    Equal(s.panels, panels, "an open window is not opened again")
end

-- 3. A window without the recast: nothing to forget, so EraUI doesn't choose
-- the book page first. (Written for 70170 and later: 70124's tabs cast
-- themselves on opening, which the removed workaround handled.)
do
    local s = Session()
    local frame = Professions(s, false)
    frame.selectedSkillLine = TAILORING
    Equal(s.BookTab(), true, "no recast: opens")
    Equal(s.selects, 0, "no recast: the book page is not chosen by EraUI")
    Equal(frame:IsShown(), true, "no recast: the window shows")
end

-- 4. If the profession can't be forgotten, EraUI doesn't open the window
-- (that would cast from its code).
do
    local s = Session()
    local frame = Professions(s, true)
    frame.selectedSkillLine = TAILORING
    s.selectFails = true
    Equal(s.BookTab(), false, "not forgotten: the book tab does nothing")
    Equal(frame:IsShown(), false, "the window stays shut")
    Equal(s.blocked, 0, "no cast from EraUI's code")
end

-- 5. The book skin off: the spellbook tab still forgets first.
do
    local s = Session()
    local frame = Professions(s, true)
    frame.selectedSkillLine = TAILORING
    Equal(s.BookTab(), true, "skin off: opens")
    Equal(s.blocked, 0, "skin off: no cast from EraUI's code")
    Equal(frame.BookPage:IsShown(), true, "skin off: the book")
end

-- 6. The micro button: the shut window forgets, so it opens on the book as
-- in 1.5.0. Once per closing; never in a fight; not while a profession is
-- opening.
do
    local s = Session()
    local frame = Professions(s, true)
    s.ns.modules.professionsBook.apply()
    s.OpenTradeSkill(TAILORING)
    s.Tick(20)
    Equal(frame.CraftingPage:IsShown(), true, "setup: Tailoring open")
    s.Close()
    s.selects = 0
    s.Tick()
    Equal(s.selects, 1, "the shut window forgets the profession")
    Equal(frame.selectedSkillLine, nil, "nothing remembered")
    Equal(frame.BookPage:IsShown(), true, "the shut window is on the book")
    local last = s.persisted[#s.persisted]
    Equal(last, "professions: shut window turned to the book, last profession forgotten", "dev log")
    s.Tick(10)
    Equal(s.selects, 1, "only once")
    s.MicroButton()
    Equal(s.casts, 0, "the micro button casts nothing")
    Equal(frame:IsShown(), true, "the micro button opens the window")
    Equal(frame.BookPage:IsShown(), true, "on the book, as in 1.5.0")
    s.Close()

    -- Turned to the book while a profession was open, then closed: the book
    -- page already shows, but the profession is still remembered.
    s.OpenTradeSkill(TAILORING)
    s.Tick(20)
    Equal(s.BookTab(), true, "the book tab on an open profession")
    Equal(frame.BookPage:IsShown(), true, "shows the book page")
    Equal(frame.selectedSkillLine, TAILORING, "the window still remembers Tailoring")
    s.Close()
    s.selects = 0
    s.Tick()
    Equal(s.selects, 1, "closed on the book page: still forgotten")
    s.casts = 0
    s.MicroButton()
    Equal(s.casts, 0, "so the micro button casts nothing")
    Equal(frame.BookPage:IsShown(), true, "and opens the book")
    s.Close()

    -- Closed in a fight: forgotten when it ends.
    s.OpenTradeSkill(TAILORING)
    s.Tick(20)
    s.combat = true
    s.Close()
    s.selects = 0
    s.Tick(5)
    Equal(s.selects, 0, "nothing chosen in a fight")
    Equal(frame.selectedSkillLine, TAILORING, "still remembered in the fight")
    s.combat = false
    s.Tick()
    Equal(s.selects, 1, "forgotten when the fight ends")
    Equal(frame.selectedSkillLine, nil, "nothing remembered after the fight")

    -- A choice that doesn't clear it is tried once per closing.
    s.OpenTradeSkill(TAILORING)
    s.Tick(20)
    s.Close()
    s.selectFails = true
    s.selects = 0
    s.Tick(10)
    Equal(s.selects, 1, "a failing choice is tried once")
    frame:Show(); s.Tick(); s.Close()
    s.Tick(3)
    Equal(s.selects, 2, "and once more after the next closing")
    s.selectFails = false
    s.Tick()
    Equal(s.selects, 2, "not again before the next opening")

    Equal(s.registry, nil, "no EventRegistry use while watching")
end

-- 6b. A profession opening while the window is shut is left alone (for 3
-- seconds, the time it has to show).
do
    local s = Session()
    local frame = Professions(s, true)
    s.ns.modules.professionsBook.apply()
    frame.selectedSkillLine = TAILORING
    s.Fire("TRADE_SKILL_SHOW")
    s.selects = 0
    s.Tick(3)
    Equal(s.selects, 0, "not while a profession is opening")
    s.Tick(20)
    Equal(s.selects, 1, "forgotten once that time has passed with the window still shut")
end

-- 6c. Closed in a fight, then the micro button before the fight ends. EraUI
-- can't act in a fight, so Blizzard reopens the last profession from the
-- player's own click: EraUI chooses nothing and writes nothing on the window
-- until the fight is over. (Whether the game allows that cast with EraUI
-- loaded can only be checked in game.)
do
    local s = Session()
    local frame = Professions(s, true)
    s.ns.TradeSkillActive = function() return true end
    s.ns.TradeSkillWindowSize = function() return 700, 500 end
    s.ns.modules.professionsBook.apply()
    s.OpenTradeSkill(TAILORING)
    s.Tick(20)
    Equal(frame.width, 700, "setup: sized for the profession")
    Equal(s.BookTab(), true, "setup: EraUI's book tab on the open profession")
    s.Tick(5)
    Equal(frame.width, 550, "setup: sized for the book")
    Equal(frame.selectedSkillLine, TAILORING, "setup: Tailoring still remembered")
    local fightWrites = 0
    for _, name in ipairs({ "SetAttribute", "SetSize", "SetWidth", "SetHeight" }) do
        local write = Methods[name]
        frame[name] = function(self, ...)
            if s.combat then fightWrites = fightWrites + 1 end
            return write(self, ...)
        end
    end
    s.combat = true
    s.Close()
    s.selects, s.casts, s.blocked = 0, 0, 0
    s.Tick(5)
    Equal(s.selects, 0, "closed in the fight: nothing chosen")
    s.MicroButton()
    Equal(s.casts, 1, "the micro button reopens Tailoring, as Blizzard does")
    Equal(s.blocked, 0, "from the player's own click, not EraUI's code")
    Equal(frame.CraftingPage:IsShown(), true, "Tailoring shows")
    s.Tick(5)
    Equal(s.selects, 0, "EraUI chooses nothing in the fight")
    Equal(frame.CraftingPage:IsShown(), true, "and leaves the profession open")
    Equal(fightWrites, 0, "nothing written on the window in the fight")
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    s.Tick(5)
    Equal(frame.width, 700, "sized for the profession once the fight ends")
    Equal(s.selects, 0, "the open profession isn't sent to the book")
    s.Close()
    s.Tick()
    Equal(s.selects, 1, "closed after the fight: forgotten")
    s.casts = 0
    s.MicroButton()
    Equal(s.casts, 0, "so the micro button opens the book again")
    Equal(frame.BookPage:IsShown(), true, "the book, as in 1.5.0")
end

-- 7. The book skin off: the shut window is left as Blizzard has it.
do
    local s = Session()
    local frame = Professions(s, true)
    s.ns.StartProfessionsWatch()
    frame.selectedSkillLine = TAILORING
    s.Tick(10)
    Equal(s.selects, 0, "skin off: the shut window keeps Blizzard's memory")
end

---------------------------------------------------------------------------
-- Bag Space and the game's Show Free Bag Space (Modules/QoL.lua)
---------------------------------------------------------------------------
local function Bags(s, gameValue)
    local env = s.env
    s.cvars = { displayFreeBagSlots = gameValue, chatClassColorOverride = "0" }
    s.writes = {}
    s.refusing = false
    env.C_CVar = {
        GetCVar = function(name) return s.cvars[name] end,
        SetCVar = function(name, value)
            s.writes[#s.writes + 1] = name .. "=" .. tostring(value)
            if s.refusing then return false end
            s.cvars[name] = value
            s.Fire("CVAR_UPDATE", name, value)
            return true
        end,
    }
    local backpack = Widget()
    s.countShown = {}
    function backpack:UpdateFreeSlots() end
    function backpack:SetCountShown(on) s.countShown[#s.countShown + 1] = on end
    env.MainMenuBarBackpackButton = backpack
    s.E.settings.bagSpace = true
    s.E.settings.classColors = true
    local card = Widget({ checked = true })
    s.E.settingsFrame = { checks = { bagSpace = card } }
    s.card = card
    s.ns.RefreshOptionsWindow = function() s.optionsRefreshed = (s.optionsRefreshed or 0) + 1 end
    s.Load("Modules/QoL.lua")
    s.qol = s.E.modules.QoL
    -- A flip of Bag Space in /era (or the Classic options): saved, then applied.
    function s.Flip(on)
        s.E:SetSetting("bagSpace", on)
        s.card.checked = on
        s.qol:UpdateBagSpace()
    end
    return backpack
end

local function BagWrites(s)
    local n = 0
    for _, write in ipairs(s.writes) do if write:find("^displayFreeBagSlots=") then n = n + 1 end end
    return n
end

-- 8. Login: the game's switch wins; no hook, no write.
do
    local s = Session()
    Bags(s, "0")
    s.qol:Initialize()
    Equal(s.E.settings.bagSpace, false, "login: Bag Space follows the game's switch (off)")
    Equal(s.card.checked, false, "login: the /era card follows")
    Equal(BagWrites(s), 0, "login: nothing written to the game")
    Equal(s.hooks or 0, 0, "login: no count hook with the game's switch")
    Equal(#s.countShown, 0, "login: EraUI doesn't show or hide the count itself")
    Equal(s.qol.bagSpacePending, nil, "nothing pending")

    -- A flip in EraUI is written to the game.
    s.Flip(true)
    Equal(BagWrites(s), 1, "a flip in EraUI is written once")
    Equal(s.writes[#s.writes], "displayFreeBagSlots=1", "as the game's switch on")
    Equal(s.E.settings.bagSpace, true, "Bag Space stays on")
    s.Fire("BAG_UPDATE_DELAYED")
    Equal(BagWrites(s), 1, "bag updates write nothing")

    -- The game's Options flip it: Bag Space and both option windows follow.
    s.optionsRefreshed = 0
    s.cvars.displayFreeBagSlots = "0"
    s.Fire("CVAR_UPDATE", "displayFreeBagSlots", "0")
    Equal(s.E.settings.bagSpace, false, "the game's flip reaches Bag Space")
    Equal(s.card.checked, false, "and the /era card")
    Equal(s.optionsRefreshed, 1, "and the Classic options window")
    Equal(BagWrites(s), 1, "nothing written back")
    s.cvars.displayFreeBagSlots = "1"
    s.Fire("CVAR_UPDATE", "DISPLAYFREEBAGSLOTS", "1")
    Equal(s.E.settings.bagSpace, true, "the name is matched in any case")
    s.cvars.displayFreeBagSlots = "0"
    s.Fire("CVAR_UPDATE", "displayFreeBagSlotsX", "0")
    s.Fire("CVAR_UPDATE", SECRET, "0")
    s.Fire("CVAR_UPDATE", nil)
    Equal(s.E.settings.bagSpace, true, "other, secret or missing names are ignored")
    s.Fire("BAG_UPDATE_DELAYED")
    Equal(s.E.settings.bagSpace, false, "a missed change is read on the next bag update")
    Equal(BagWrites(s), 1, "still nothing written back")
end

-- 9. A flip in a fight: handed over when it ends, unless taken back or the
-- game's switch is flipped meanwhile.
do
    local s = Session()
    Bags(s, "0")
    s.qol:Initialize()
    s.combat = true
    s.Flip(true)
    Equal(BagWrites(s), 0, "nothing written in a fight")
    s.Fire("BAG_UPDATE_DELAYED")
    Equal(s.E.settings.bagSpace, true, "a bag update in the fight keeps the newer choice")
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    Equal(BagWrites(s), 1, "written when the fight ends")
    Equal(s.cvars.displayFreeBagSlots, "1", "the game's switch is on")
    s.Fire("PLAYER_REGEN_ENABLED")
    Equal(BagWrites(s), 1, "only once")

    s.combat = true
    s.Flip(false)
    s.Flip(true)
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    Equal(BagWrites(s), 1, "flipped back in the fight: nothing to write")

    s.combat = true
    s.Flip(false)
    s.cvars.displayFreeBagSlots = "1"
    s.Fire("CVAR_UPDATE", "displayFreeBagSlots", "1")
    s.combat = false
    s.Fire("PLAYER_REGEN_ENABLED")
    Equal(BagWrites(s), 1, "the game's later flip wins over the pending one")
    Equal(s.E.settings.bagSpace, true, "Bag Space follows the game's later flip")
end

-- 10. The game keeps its own value: Bag Space shows the game's at once.
do
    local s = Session()
    Bags(s, "1")
    s.qol:Initialize()
    s.refusing = true
    s.Flip(false)
    Equal(BagWrites(s), 1, "the write is tried")
    Equal(s.E.settings.bagSpace, true, "refused: Bag Space follows the game at once")
    Equal(s.card.checked, true, "and so does its card")
end

-- 11. A game without the switch (or one that won't say): the old hook.
for _, value in ipairs({ "none", "secret" }) do
    local s = Session()
    local backpack = Bags(s, value == "secret" and SECRET or nil)
    s.qol:Initialize()
    Equal(s.hooks, 1, value .. ": the count hook is installed")
    Equal(s.countShown[#s.countShown], true, value .. ": EraUI shows the count")
    s.Flip(false)
    Equal(s.countShown[#s.countShown], false, value .. ": and hides it")
    Equal(BagWrites(s), 0, value .. ": nothing written")
    s.Fire("BAG_UPDATE_DELAYED")
    Equal(s.hooks, 1, value .. ": hooked once")
    Equal(s.E.settings.bagSpace, false, value .. ": Bag Space keeps its own choice")
    -- The game's switch showing up later turns the hook into a no-op.
    s.cvars.displayFreeBagSlots = "1"
    local shown = #s.countShown
    backpack:UpdateFreeSlots()
    Equal(#s.countShown, shown, value .. ": the hook stands aside once the game has the switch")
end

---------------------------------------------------------------------------
-- The backpack's free-slot text (Classic/BarSkins.lua)
---------------------------------------------------------------------------
do
    local s = Session()
    s.ns.SetTex = function() end
    s.ns.SetButtonTex = function() end
    s.env.GetInventoryItemTexture = function() return nil end
    s.Load("Classic/BarSkins.lua")
    -- UpdateTextures stands in for the game's refresh (its bag mixin runs it
    -- from SetItemButtonTexture and SetItemButtonQuality), so the skin hooks it.
    -- A Count that tallies every Show, Hide and SetShown, so "never hidden or
    -- shown" is checked by the calls themselves, not a flag that starts true.
    local function CountText()
        local count = Widget()
        count.toggles = 0
        count.Show = function(self) self.toggles = self.toggles + 1; Methods.Show(self) end
        count.Hide = function(self) self.toggles = self.toggles + 1; Methods.Hide(self) end
        count.SetShown = function(self, on) self.toggles = self.toggles + 1; Methods.SetShown(self, on) end
        return count
    end
    local new = Widget({ width = 30, icon = Widget(), Count = CountText(), FreeSlots = Widget(),
        UpdateTextures = function() end })
    s.ns.SkinBagButton(new, 30, true)
    local p = new.FreeSlots.points[1]
    Equal(p and p[1], "BOTTOM", "70170: the free-slot text sits at the bottom")
    Equal(p and p[4], 0, "centred")
    Equal(p and p[5], 3, "3 up")
    Equal(new.FreeSlots.font, "NumberFontNormalSmall", "in the small number font")
    Equal(#new.Count.points, 0, "70170: Count is left alone")
    Equal(new.Count.font, nil, "70170: Count's font untouched")
    -- 70170 still fills the backpack's Count from inventory slot 0, the ammo
    -- slot: with arrows equipped it read 312 next to the free-slot number.
    Equal(new.Count:GetAlpha(), 0, "70170: the backpack's Count (the game's ammo count) is hidden")
    Equal(new.Count.toggles, 0, "hidden by alpha only, never hidden or shown")
    new.Count:SetAlpha(1)
    new:UpdateTextures()
    Equal(new.Count:GetAlpha(), 0, "and hidden again on the game's next refresh")
    Equal(new.Count.toggles, 0, "the refresh never hides or shows it either")
    s.ns.UnskinBagButton(new)
    p = new.FreeSlots.points[1]
    Equal(p and p[1], "CENTER", "unskinned: back where the game puts it")
    Equal(p and p[5], -10, "10 down")
    Equal(new.FreeSlots.font, "NumberFontNormal", "in the game's font")
    Equal(new.Count:GetAlpha(), 1, "unskinned: the game's Count is back as the game has it")
    new:UpdateTextures()
    Equal(new.Count:GetAlpha(), 1, "and a refresh after unskinning leaves it")
    Equal(new.Count.toggles, 0, "unskinning never hides or shows it")

    local old = Widget({ width = 30, icon = Widget(), Count = Widget() })
    s.ns.SkinBagButton(old, 30, true)
    p = old.Count.points[1]
    Equal(p and p[1], "BOTTOM", "before 70170: Count styled as before")
    Equal(old.Count.font, "NumberFontNormalSmall", "before 70170: small font")
    Equal(old.Count:GetAlpha(), 1, "before 70170: Count is the free-slot number, so it stays shown")

    local bag = Widget({ width = 30, icon = Widget(), Count = CountText(), FreeSlots = Widget() })
    s.ns.SkinBagButton(bag, 30, false)
    Equal(#bag.FreeSlots.points, 0, "other bag buttons: not the backpack's text")
    Equal(bag.Count:GetAlpha(), 1, "other bag buttons: their count (a quiver's ammo) stays, as the game shows it")
    s.ns.UnskinBagButton(bag)
    Equal(#bag.FreeSlots.points, 0, "other bag buttons: nothing put back")
    Equal(bag.Count:GetAlpha(), 1, "other bag buttons: count still shown after unskinning")
    Equal(bag.Count.toggles, 0, "other bag buttons: their count is never hidden or shown")
end

---------------------------------------------------------------------------
-- Create Listing's play style drop down (Classic/GroupFinder.lua)
---------------------------------------------------------------------------
local function Finder(s, opts)
    opts = opts or {}
    local env = s.env
    s.dressed = {}
    s.ns.DressDropdown = function(dropdown, inset) s.dressed[#s.dressed + 1] = { dropdown, inset } end
    s.ns.NewSideTab = function() return Widget() end
    env.FriendsFrame = Widget({ width = 385, height = 424 })
    local parent = Widget({ width = 458, height = 424, selectedTab = 1 })
    env.LFGParentFrame = parent
    local listing = Widget({ parent = parent })
    local view = Widget({ parent = listing, left = 7, width = 371, shown = opts.viewShown ~= false })
    listing.ActivityView = view
    listing.CategoryView = Widget({ parent = listing, CategoryButtons = {} })
    if opts.style ~= false then view.PlayStyleDropdown = Widget({ parent = view, width = 210, height = 25 }) end
    local ranges = Widget({ parent = view, shown = opts.rangesShown ~= false })
    ranges.Text = Widget({ parent = ranges, left = opts.labelLeft or (7 + 216) })
    view.LevelRangesCheckbox = ranges
    env.LFGListingFrame = listing
    s.Load("Classic/GroupFinder.lua")
    s.ns.modules.groupFinder.apply()
    return view
end

do
    local s = Session()
    local view = Finder(s)
    local style = view.PlayStyleDropdown
    local dressed
    for _, entry in ipairs(s.dressed) do if entry[1] == style then dressed = entry end end
    Equal(dressed ~= nil, true, "the play style drop down wears the old drop down")
    Equal(dressed and dressed[2], 14, "like the others (14)")
    local p = style.points[1]
    Equal(#style.points, 1, "one anchor")
    Equal(p and p[1], "TOPLEFT", "top left")
    Equal(p and p[2], view, "of the activity view")
    Equal(p and p[4], 22, "22 in")
    Equal(p and p[5], -10, "on the top row")
    -- The tick's label starts 216 in: 14 for the old drop down's end and a
    -- 6 gap leave the drop down 174 wide.
    Equal(style.width, 174, "it ends short of the level ranges label")
    view.LevelRangesCheckbox.Text.left = 7 + 250
    s.Tick()
    Equal(style.width, 208, "it follows the label")
    view.LevelRangesCheckbox.Text.left = 7 + 400
    s.Tick()
    Equal(style.width, 210, "never wider than its own 210")
    view.LevelRangesCheckbox.Text.left = 7 + 100
    s.Tick()
    Equal(style.width, 120, "never narrower than 120")
    view.LevelRangesCheckbox.Text.left = SECRET
    s.Tick()
    Equal(style.width, 120, "a secret position changes nothing")
    view.LevelRangesCheckbox.Text.left = 7 + 216
    s.Tick()
    Equal(style.width, 174, "back to 174")
    view.shown = false
    view.LevelRangesCheckbox.Text.left = 7 + 250
    s.Tick()
    Equal(style.width, 174, "a hidden view is left alone")
    view.shown = true
    s.Tick()
    Equal(style.width, 208, "and fitted again when shown")
    view.LevelRangesCheckbox.Text.left = 7 + 216
    view.LevelRangesCheckbox.shown = false
    s.Tick()
    Equal(style.width, 210, "without the tick it takes its own width")
end

do
    local s = Session()
    local hidden = Finder(s, { viewShown = false })
    Equal(hidden.PlayStyleDropdown.width, 210, "a view not yet shown keeps the game's width")
    local s2 = Session()
    local view = Finder(s2, { style = false })
    Equal(view.PlayStyleDropdown, nil, "before 70170: no play style drop down")
    Equal(#s2.dressed, 0, "before 70170: nothing extra dressed")
end

print("Build 70170 checks passed: " .. checks .. " assertions.")
