-- The shared base under the Classic look (clean-room 2026-10-22, from
-- Tools/ClassicSpecs/13-old-base.md): Look/Engine.lua and Look/EnginePass.lua
-- (the namespace, EraUIClassicDB and its starting values, the CVar copy, the
-- list of look parts and the pass, login, entering the world and logout,
-- the Edit Mode watch, refused calls, game settings, the toggles and the
-- reload question), Look/ArtKeys.lua (the 1.x art by name), Look/BaseNames.lua
-- (the shared names the kept files, Core/ and Modules/ call) and
-- Look/Windows.lua (how EraUI's windows share the screen), on a small mock of
-- the game: frames with scripts, events and OnUpdate, textures the game may
-- refuse, CVars, timers, the fight lock and Edit Mode. Escape is
-- Tools/TestEscapeWindows.lua's; the copies on disk Tools/TestArtFiles.mjs's;
-- the source rules Tools/TestRules.mjs's; the reset with the real Core files
-- Tools/TestResetLifecycle.lua's.
-- Run from the addon folder: fengari Tools/TestClassicBase.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    if actual ~= expected then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function True(value, label) Equal(value and true or false, true, label) end
local function False(value, label) Equal(value and true or false, false, label) end

local SECRET = setmetatable({}, { __tostring = function() error("a secret was turned into text") end })
local BASE_FILES = { "Look/Engine.lua", "Look/EnginePass.lua", "Look/Base.lua", "Look/ArtKeys.lua", "Look/BaseNames.lua",
    "Look/Escape.lua", "Look/Windows.lua" }

---------------------------------------------------------------------------
-- The mock game
---------------------------------------------------------------------------

local function Game(options)
    options = options or {}
    local game = { frames = {}, timers = {}, now = 0, combat = false, editing = false, interface = options.interface or 16001,
        cvars = {}, cvarLog = {}, refused = {}, settings = { enabled = true }, popups = {}, prints = {}, errors = {},
        panelsHidden = {}, hooked = 0 }
    for name, value in pairs(options.cvars or {}) do game.cvars[name] = value end
    local env = setmetatable({}, { __index = _G })
    env._G = env
    game.env = env

    local Proto, ButtonProto = {}, {}
    setmetatable(ButtonProto, { __index = Proto })
    local function New(kind, name, parent)
        local proto = (kind == "Button" or kind == "CheckButton") and ButtonProto or Proto
        local o = setmetatable({ kind = kind, name = name, parent = parent, shown = true, alpha = 1, points = {}, scripts = {},
            hooks = {}, events = {}, stateTex = {}, colour = { 1, 1, 1 } }, { __index = proto })
        game.frames[#game.frames + 1] = o
        if name then env[name] = o end
        return o
    end
    game.New = New
    local function Run(o, script, ...)
        if o.scripts[script] then o.scripts[script](o, ...) end
        for _, fn in ipairs(o.hooks[script] or {}) do fn(o, ...) end
    end
    function Proto:GetName() return self.name end
    function Proto:GetParent() return self.parent end
    function Proto:IsShown() return self.shown end
    function Proto:IsVisible() return self.shown end
    function Proto:Show()
        if self.shown then return end
        self.shown = true
        Run(self, "OnShow")
    end
    function Proto:Hide()
        if not self.shown then return end
        self.shown = false
        Run(self, "OnHide")
    end
    function Proto:SetShown(on) if on then self:Show() else self:Hide() end end
    function Proto:SetScript(script, fn) self.scripts[script] = fn end
    function Proto:GetScript(script) return self.scripts[script] end
    function Proto:HookScript(script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    function Proto:HasScript() return true end
    function Proto:RegisterEvent(event) self.events[event] = true end
    function Proto:RegisterUnitEvent(event) self.events[event] = true end
    function Proto:UnregisterEvent(event) self.events[event] = nil end
    function Proto:UnregisterAllEvents() self.events = {} end
    function Proto:SetSize(w, h) self.width, self.height = w, h end
    function Proto:SetWidth(w) self.width = w end
    function Proto:SetHeight(h) self.height = h end
    function Proto:GetWidth() return self.width or 0 end
    function Proto:GetHeight() return self.height or 0 end
    function Proto:SetPoint(point, relative, relativePoint, x, y)
        self.points[#self.points + 1] = { point, relative, relativePoint, x, y }
    end
    function Proto:ClearAllPoints() self.points = {} end
    function Proto:SetAllPoints(other) self.points = { { "ALL", other } } end
    function Proto:GetNumPoints() return #self.points end
    function Proto:GetPoint(i)
        local p = self.points[i or 1]
        if p then return p[1], p[2], p[3], p[4], p[5] end
    end
    -- A rect only where the test gives one: left, bottom, right, top.
    function Proto:GetLeft() return self.rect and self.rect[1] end
    function Proto:GetBottom() return self.rect and self.rect[2] end
    function Proto:GetRight() return self.rect and self.rect[3] end
    function Proto:GetTop() return self.rect and self.rect[4] end
    function Proto:GetEffectiveScale() return 1 end
    function Proto:GetCenter() return 0, 0 end
    function Proto:IsProtected() return self.protected == true end
    function Proto:IsForbidden() return false end
    function Proto:CreateTexture() return New("Texture", nil, self) end
    function Proto:CreateMaskTexture() return New("MaskTexture", nil, self) end
    function Proto:CreateFontString() return New("FontString", nil, self) end
    function Proto:SetTexture(path)
        if path == nil then error("the game refuses a nil texture") end
        if game.refused[path] then return false end
        self.file = path
        return true
    end
    function Proto:GetTexture() return self.file end
    function Proto:SetVertexColor(r, g, b) self.colour = { r, g, b } end
    function Proto:SetAlpha(a) self.alpha = a end
    function Proto:GetAlpha() return self.alpha end
    function Proto:SetTexCoord(...) self.coords = { ... } end
    function Proto:AddMaskTexture(mask) self.masks = (self.masks or 0) + 1; self.mask = mask end
    function Proto:IsMouseOver() return false end
    for _, name in ipairs({ "SetBlendMode", "SetDrawLayer", "SetHorizTile", "SetVertTile", "SetFrameStrata", "SetFrameLevel",
        "EnableMouse", "SetMovable", "SetClampedToScreen", "SetText", "SetFontObject", "SetTextColor", "Raise",
        "SetJustifyH", "EnableMouseWheel", "RegisterForDrag", "SetBackdrop", "SetBackdropColor", "SetBackdropBorderColor" }) do
        Proto[name] = Proto[name] or function() end
    end
    function Proto:GetFrameLevel() return 1 end
    function Proto:GetStringWidth() return 40 end
    for _, state in ipairs({ "Normal", "Pushed", "Disabled", "Highlight", "Checked" }) do
        ButtonProto["Set" .. state .. "Texture"] = function(self, path)
            if path == nil then error("the game refuses a nil state texture") end
            local face = self.stateTex[state] or New("Texture", nil, self)
            self.stateTex[state] = face
            face:SetTexture(path)
        end
        ButtonProto["Get" .. state .. "Texture"] = function(self) return self.stateTex[state] end
    end

    env.CreateFrame = function(kind, name, parent) return New(kind, name, parent) end
    env.CreateFont = function(name)
        local font = { name = name, colour = {} }
        function font:SetTextColor(r, g, b) self.colour = { r, g, b } end
        function font:GetTextColor() return self.colour[1], self.colour[2], self.colour[3] end
        function font:CopyFontObject(model) self.model = model end
        function font:SetFontObject(model) self.model = model end
        env[name] = font
        return font
    end
    env.GameFontNormal, env.GameFontNormalSmall = { name = "GameFontNormal" }, { name = "GameFontNormalSmall" }
    env.UIParent = New("Frame", "UIParent")
    env.UIParent.rect = { 0, 0, 1920, 1080 }
    env.InCombatLockdown = function() return game.combat end
    env.issecretvalue = function(value) return value == SECRET end
    env.GetBuildInfo = function() return "1.60.1", "70450", "Oct 1 2026", game.interface end
    env.date = function() return "12:34:56" end
    env.geterrorhandler = function() return function(problem) game.errors[#game.errors + 1] = tostring(problem) end end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) game.prints[#game.prints + 1] = text end }
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show = function(name) game.popups[#game.popups + 1] = name end
    env.RELOADUI, env.LATER = "Reload UI", "Later"
    env.EditModeManagerFrame = { IsEditModeActive = function() return game.editing end }
    env.C_Timer = { After = function(seconds, fn) game.timers[#game.timers + 1] = { at = game.now + seconds, fn = fn } end }
    env.C_CVar = {
        GetCVar = function(name)
            game.cvarLog[#game.cvarLog + 1] = "get " .. name
            return game.cvars[name]
        end,
        RegisterCVar = function(name, value)
            game.cvarLog[#game.cvarLog + 1] = "register " .. name
            if game.cvars[name] == nil then game.cvars[name] = value end
        end,
        SetCVar = function(name, value)
            game.cvarLog[#game.cvarLog + 1] = "set " .. name .. "=" .. tostring(value)
            game.cvars[name] = tostring(value)
            return true
        end,
    }
    -- Post-hooks: the original first, then each hook.
    env.hooksecurefunc = function(target, method, after)
        game.hooked = game.hooked + 1
        if type(target) == "string" then
            local original = env[target]
            env[target] = function(...) original(...); after(...) end
            return
        end
        local original = target[method]
        target[method] = function(...) original(...); after(...) end
    end
    env.HideUIPanel = function(frame)
        game.panelsHidden[#game.panelsHidden + 1] = frame:GetName()
        frame:Hide()
    end
    env.UIPanelWindows = {}

    local E = { settings = game.settings, Persistence = {} }
    function E:GetSetting(key) return self.settings[key] end
    game.E = E
    function game.Load(files)
        for _, file in ipairs(files or BASE_FILES) do assert(loadfile(file, "t", env))("EraUI", E) end
        game.ns, game.Look = E.Classic, E.Look
        return E.Classic
    end
    function game.Fire(event, ...)
        for _, o in ipairs(game.frames) do
            if o.events[event] and o.scripts.OnEvent then o.scripts.OnEvent(o, event, ...) end
        end
    end
    -- Time passing in steps: every shown frame's OnUpdate, then the timers due.
    function game.Tick(seconds, step)
        step = step or 0.05
        local done = 0
        while done < seconds - 1e-9 do
            game.now, done = game.now + step, done + step
            for _, o in ipairs(game.frames) do
                if o.shown and o.scripts.OnUpdate then o.scripts.OnUpdate(o, step) end
            end
            local due = {}
            for i = #game.timers, 1, -1 do
                if game.timers[i].at <= game.now + 1e-9 then table.insert(due, 1, table.remove(game.timers, i)) end
            end
            for _, timer in ipairs(due) do timer.fn() end
        end
    end
    return game
end

-- A game with the base loaded and EraUI's saved files read.
local function Loaded(options)
    local game = Game(options)
    game.Load()
    game.Fire("ADDON_LOADED", "EraUI")
    return game, game.ns, game.env
end

---------------------------------------------------------------------------
-- The namespace and the starting values (spec 1.1, 3.1, 3.5)
---------------------------------------------------------------------------

do
    local game = Game()
    local ns = game.Load()
    Equal(game.E.Classic, ns, "the engine makes the Classic namespace")
    Equal(ns.ADDON, "EraUI", "with the addon's folder name")
    -- Every start, from the spec's table (none may ever change: the copy
    -- keeps only what differs from these).
    local want = {}
    local function Starts(value, keys) for key in keys:gmatch("%S+") do want[key] = value end end
    -- (Audit A27 retired three that nothing read: minimapButton, barScale and
    -- minimapButtonAngle; professionTabs went with the professions window's
    -- arrow, so 74 of the spec's 78.)
    Starts(true, [[classicBar buttons castAnim emptySlots squareIcons professionsBook tradeSkill trainer tradeSkillSearch talents
        hideBuffArrow spellDrag bagsBesideBars gameDamageNumbers hideExtraBars unitFrames castBars mirrorTimers comboPoints
        welcomeNote minimap namePlates fullPlates questTracker questLog unitFramePlayer unitFrameTarget
        unitFrameFocus unitFramePet unitFrameParty questMapPane gameMenu settingsPanel panels bags characterSheet spellBook
        guildRoster whoList spellBookSearch]])
    Starts(false, [[oneBar defaultBarSize oneBag bagsAboveRow barDragged bagsHeld capHeldLeft capHeldRight whoTabs
        spellBookTopRank layoutSelectPending pinShape bagsFirst hideLastNames classColorHealth classColorPlates mapFade
        questLogDual statPanes damageMeter welcomed]])
    want.dbVersion, want.oneBagColumns, want.barOffsetX, want.barOffsetY, want.bagsSnapScale = 1, 8, 0, 0, 0
    want.whoColumn, want.previousLayout, want.layoutSelectTries, want.microPosText, want.microScale = "zone", "", 0, "", 1
    want.statPaneLeft, want.statPaneRight, want.textureSource = "section2", "section3", "builtin"
    local count = 0
    for key, value in pairs(want) do
        count = count + 1
        Equal(ns.DB_DEFAULTS[key], value, "start of " .. key)
    end
    for key in pairs(ns.DB_DEFAULTS) do True(want[key] ~= nil, key .. " is one of the spec's starts") end
    Equal(count, 74, "the spec's 78 starts less the four retired")
    for _, key in ipairs({ "minimapButton", "barScale", "minimapButtonAngle", "professionTabs" }) do
        Equal(ns.DB_DEFAULTS[key], nil, "A27: " .. key .. " retired: no start")
    end
    local reload = {}
    for key in pairs(ns.RELOAD_KEYS) do reload[#reload + 1] = key end
    table.sort(reload)
    Equal(table.concat(reload, " "), "bags castBars characterSheet classicBar comboPoints gameMenu groupFinder minimap namePlates "
        .. "panels professionsBook questMapPane questTracker settingsPanel spellBook tradeSkill unitFrames", "the reload keys")

    -- Saved files read: only EraUI's own ADDON_LOADED, defaults copied in
    -- (a start another file added before then too), old values kept.
    game.env.EraUIClassicDB = { oneBar = true, lastOutput = "old", custom = "kept" }
    ns.DB_DEFAULTS.addedLater = "late"
    game.Fire("ADDON_LOADED", "SomeOtherAddon")
    Equal(ns.db, nil, "another addon's load: nothing")
    game.settings.enabled = false
    game.Fire("ADDON_LOADED", "EraUI")
    Equal(ns.db, game.env.EraUIClassicDB, "the working table is the saved table itself (even with EraUI turned off)")
    Equal(ns.db.oneBar, true, "a saved value kept")
    Equal(ns.db.classicBar, true, "a missing value takes its start")
    Equal(ns.db.addedLater, "late", "a start added by a later file counts")
    Equal(ns.db.lastOutput, nil, "the old lastOutput cleared")
    Equal(ns.db.custom, "kept", "unknown keys left alone")
end

---------------------------------------------------------------------------
-- The CVar copy (spec 4.3)
---------------------------------------------------------------------------

do
    -- Read back: before the CVar is registered, every kind, the menu's place.
    local game, ns = Loaded({ cvars = { EraUIClassicSettings =
        "classicBar=b0;microScale=n1.5;whoColumn=sname;oneBagColumns=n12;noStart=b1;broken=nfoo;barOffsetY=n-7.25;"
        .. "microPosText=sBOTTOMRIGHT,BOTTOMRIGHT,-4.5,20.0;previousLayout=s" } })
    Equal(game.cvarLog[1], "get EraUIClassicSettings", "the copy is read first")
    for _, line in ipairs(game.cvarLog) do False(line:find("^register"), "a copy the game kept is never registered again") end
    Equal(ns.db.classicBar, false, "a no")
    Equal(ns.db.microScale, 1.5, "a number")
    Equal(ns.db.barOffsetY, -7.25, "a negative decimal")
    Equal(ns.db.whoColumn, "name", "a word")
    Equal(ns.db.oneBagColumns, 12, "a whole number")
    Equal(ns.db.noStart, true, "a pair applied whether or not it has a start")
    Equal(ns.db.broken, nil, "a number that isn't one is left out")
    Equal(ns.db.previousLayout, "", "an empty word")
    local place = ns.db.microPos
    Equal(type(place) == "table" and string.format("%s,%s,%g,%g", place[1], place[2], place[3], place[4]),
        "BOTTOMRIGHT,BOTTOMRIGHT,-4.5,20", "the micro menu's place rebuilt from its text")
end

do
    -- Audit A27: retired settings leave the saved table and the copy as it
    -- loads, and are never written to the copy again.
    local game, ns = Loaded({ cvars = { EraUIClassicSettings =
        "barScale=n1.5;minimapButton=b0;minimapButtonAngle=n90;eraui_reminderX=n10;eraui_reminderScale=n2;oneBar=b1" } })
    Equal(tostring(ns.db.barScale) .. " " .. tostring(ns.db.minimapButton) .. " " .. tostring(ns.db.minimapButtonAngle) .. " "
        .. tostring(ns.db.eraui_reminderX) .. " " .. tostring(ns.db.eraui_reminderScale) .. " " .. tostring(ns.db.oneBar),
        "nil nil nil nil nil true", "A27: the retired settings dropped from the copy read back, the rest kept")
    ns.db.barScale = 2
    ns.MirrorSave()
    Equal(game.cvars.EraUIClassicSettings:find("barScale", 1, true), nil, "A27: and never written to the copy again")
    game.env.EraUIClassicDB = { minimapButton = false, barScale = 1.2, minimapButtonAngle = 45, oneBar = true }
    game.Fire("ADDON_LOADED", "EraUI")
    Equal(tostring(ns.db.minimapButton) .. " " .. tostring(ns.db.barScale) .. " " .. tostring(ns.db.minimapButtonAngle),
        "nil nil nil", "A27: and dropped from a saved table as it loads")
end

do
    -- Never seen: read, registered with "", read again.
    local game = Loaded()
    Equal(table.concat(game.cvarLog, " | "), "get EraUIClassicSettings | register EraUIClassicSettings | get EraUIClassicSettings",
        "read, registered, read again")
end

do
    -- Written: only changed values with a start, walked from the starts, sorted.
    local game, ns = Loaded()
    local db = ns.db
    db.microScale, db.barOffsetX, db.previousLayout, db.oneBag, db.classicBar = 1.25, -12, "Mine", true, false
    db.whoColumn, db.statPaneLeft = "a;b", "x=y"
    db.cvarWas, db.noStart = { foo = "1" }, true
    ns.DB_DEFAULTS.lateKey = false
    db.lateKey = true
    db.microPos = { "TOPLEFT", nil, 10.04 }
    ns.MirrorSave()
    local text = "barOffsetX=n-12;classicBar=b0;lateKey=b1;microPosText=sTOPLEFT,TOPLEFT,10.0,0.0;microScale=n1.25;oneBag=b1;previousLayout=sMine"
    Equal(game.cvars.EraUIClassicSettings, text, "the copy's exact text")
    Equal(db.microPosText, "TOPLEFT,TOPLEFT,10.0,0.0", "the menu's place as text first (a missing relPoint is the point, x and y 0)")
    db.microPos = "not a place"
    ns.MirrorSave()
    Equal(db.microPosText, "", "no place: no text")
    -- The copy read in the next session gives the same values back.
    local again, ns2 = Loaded({ cvars = { EraUIClassicSettings = text } })
    Equal(string.format("%g %g %s %s %s", ns2.db.microScale, ns2.db.barOffsetX, ns2.db.previousLayout, tostring(ns2.db.oneBag),
        tostring(ns2.db.classicBar)), "1.25 -12 Mine true false", "round trip")
    local back = ns2.db.microPos
    Equal(string.format("%s %s %g %g", back[1], back[2], back[3], back[4]), "TOPLEFT TOPLEFT 10 0", "the place back as a table")
    -- While a settings reset waits for its reload: nothing written.
    again.E.Persistence.resetting = true
    ns2.db.microScale = 2
    ns2.MirrorSave()
    Equal(again.cvars.EraUIClassicSettings, text, "a pending reset: the copy left alone")
end

do
    -- Off Forever the saved file is enough: the copy is neither read nor written.
    local game, ns = Loaded({ interface = 11507 })
    False(ns.OnForever(), "11507 is not Forever")
    ns.db.oneBar = true
    ns.MirrorSave()
    Equal(#game.cvarLog, 0, "no CVar asked, set or registered")
    local forever = Game({ interface = 16001 })
    True(forever.Load().OnForever(), "16001 is Forever")
    local later = Game({ interface = 17000 })
    False(later.Load().OnForever(), "17000 is not")
end

---------------------------------------------------------------------------
-- The pass, the queue and the timing (spec 4.1, 4.4, 4.6)
---------------------------------------------------------------------------

local function Parts(game, ns)
    local ran = {}
    local function Part(name, extra)
        local part = { init = function() ran[#ran + 1] = "init " .. name end,
            apply = function() ran[#ran + 1] = "apply " .. name end,
            restore = function() ran[#ran + 1] = "restore " .. name end }
        for k, v in pairs(extra or {}) do part[k] = v end
        return part
    end
    ns.RegisterModule("alpha", Part("alpha"))
    ns.RegisterModule("beta", Part("beta"))
    ns.RegisterModule("alpha", Part("alpha2"))
    ns.RegisterModule("gamma", Part("gamma"))
    ns.RegisterModule("delta", Part("delta", { apply = function() ran[#ran + 1] = "apply delta"; error("boom") end }))
    ns.db.beta = false
    ns.db.gamma = nil
    -- Core/Integration.lua's way: the three fields replaced with wrappers.
    local through = { pass = 0, save = 0 }
    local pass, save = ns.ApplyAll, ns.MirrorSave
    ns.ApplyAll = function() through.pass = through.pass + 1; return pass() end
    ns.MirrorSave = function() through.save = through.save + 1; return save() end
    return ran, through
end

do
    local game, ns = Loaded()
    local ran, through = Parts(game, ns)
    Equal(ns.modules[1].key .. ns.modules[3].key, "alphaalpha", "each entry carries its key, a key may come twice")
    ns.ApplyAll()
    Equal(#ran, 0, "no pass before login")
    through.pass = 0
    local watched = 0
    ns.WatchEditWrites = function() watched = watched + 1 end
    game.Fire("PLAYER_LOGIN")
    Equal(table.concat(ran, ", "), "init alpha, init alpha2, init gamma, init delta, apply alpha, restore beta, apply alpha2, "
        .. "apply gamma, apply delta", "inits for keys not off, then one pass in the order registered (no saved value: on)")
    Equal(through.pass .. " " .. through.save, "1 1", "login's pass and its save through the namespace (the wrappers ran)")
    True(ns.applyResults.alpha.ok, "an apply's result kept (two entries share one: the later's)")
    Equal(ns.applyResults.beta, nil, "a restore records nothing")
    False(ns.applyResults.delta.ok, "an apply's error recorded")
    True(tostring(ns.applyResults.delta.error):find("boom", 1, true), "with its text")
    Equal(#game.errors, 1, "shown through the game's error handler, the pass went on")
    Equal(watched, 1, "the Edit Mode write watch started at login")

    -- One queued pass a frame.
    for i = #ran, 1, -1 do ran[i] = nil end
    ns.QueueApply()
    ns.QueueApply()
    Equal(#ran, 0, "queued for the next frame")
    game.Tick(0.05)
    Equal(through.pass, 2, "one queued pass, through the namespace")
    ns.QueueApply()
    game.Tick(0.05)
    Equal(through.pass, 3, "and another after it ran")

    -- A pass in a fight waits for its end, once.
    game.combat = true
    local before = #ran
    ns.ApplyAll()
    ns.ApplyAll()
    Equal(#ran, before, "nothing applied in a fight")
    game.combat = false
    game.Fire("PLAYER_REGEN_ENABLED")
    Equal(through.pass, 6, "the fight's end runs the booked pass through the namespace")
    local after = #ran
    game.Fire("PLAYER_REGEN_ENABLED")
    Equal(#ran, after, "only once")

    -- Edit Mode watched: opening or closing it queues a pass.
    local passes = through.pass
    game.editing = true
    game.Tick(0.2)
    Equal(through.pass, passes + 1, "Edit Mode opening: a pass")
    game.editing = false
    game.Tick(0.2)
    Equal(through.pass, passes + 2, "and closing it")
    game.Fire("UI_SCALE_CHANGED")
    game.Fire("DISPLAY_SIZE_CHANGED")
    game.Tick(0.05)
    Equal(through.pass, passes + 3, "the interface's scale or size changing: one queued pass")

    -- Logout: the last save through the namespace; the hand-back only when
    -- EraUI is off for the next load.
    local handed = 0
    ns.HandBack = function() handed = handed + 1 end
    ns.BeingTurnedOff = function() return false end
    local saves = through.save
    game.Fire("PLAYER_LOGOUT")
    Equal(through.save .. " " .. handed, (saves + 1) .. " 0", "logout saves, no hand-back")
    ns.BeingTurnedOff = function() return true end
    ns.HandBack = function() handed = handed + 1; error("hand-back trouble") end
    game.Fire("PLAYER_LOGOUT")
    Equal(handed, 1, "turned off for the next load: the hand-back runs")
    True(game.errors[#game.errors]:find("hand-back trouble", 1, true), "protected: its error shown, logout went on")
end

do
    -- EraUI turned off: no inits, no pass, ever.
    local game, ns = Loaded()
    local ran, through = Parts(game, ns)
    game.settings.enabled = false
    game.Fire("PLAYER_LOGIN")
    ns.ApplyAll()
    ns.QueueApply()
    game.Tick(0.1)
    Equal(#ran .. " " .. through.pass, "0 2", "nothing runs with EraUI off (the calls reach the engine, which stops)")
end

do
    -- The first time into the world: three seconds on, the layout check then
    -- the first run; never again that session.
    local game, ns = Loaded()
    local order = {}
    ns.SelectClassicLayoutIfPending = function() order[#order + 1] = "layout" end
    ns.FirstRun = function() order[#order + 1] = "first run" end
    game.Fire("PLAYER_LOGIN")
    game.Fire("PLAYER_ENTERING_WORLD", true, false)
    game.Tick(2.9)
    Equal(#order, 0, "not before three seconds")
    game.Tick(0.2)
    Equal(table.concat(order, ", "), "layout, first run", "the layout check, then the first run")
    game.Fire("PLAYER_ENTERING_WORLD", false, true)
    game.Tick(4)
    Equal(#order, 2, "once a session")
    -- Through whatever FirstRun is by then (Core/Integration.lua's wrapper).
    local other = Loaded()
    local otherNs = other.ns
    local wrapped = 0
    otherNs.FirstRun = function() end
    other.Fire("PLAYER_ENTERING_WORLD", true, false)
    otherNs.FirstRun = function() wrapped = wrapped + 1 end
    other.Tick(3.1)
    Equal(wrapped, 1, "the first run read through the namespace when it runs")
    -- With EraUI turned off it still runs (the first run checks for itself).
    local off = Loaded()
    off.settings.enabled = false
    local offRuns = 0
    off.ns.FirstRun = function() offRuns = offRuns + 1 end
    off.Fire("PLAYER_LOGIN")
    off.Fire("PLAYER_ENTERING_WORLD", true, false)
    off.Tick(3.1)
    Equal(offRuns, 1, "even with EraUI off")
end

---------------------------------------------------------------------------
-- The Edit Mode watch and refused calls (spec 4.7, 4.8)
---------------------------------------------------------------------------

do
    local game, ns = Loaded()
    Equal(ns.OnEditMode("not a function"), false, "only a function is watched")
    local seen = {}
    True(ns.OnEditMode(function(open) seen[#seen + 1] = tostring(open) end), "a watcher added")
    True(ns.OnEditMode(function() error("watcher trouble") end), "another")
    game.Tick(0.3)
    Equal(#seen, 0, "nothing while nothing changes")
    game.editing = true
    game.Tick(0.05)
    Equal(#seen, 0, "looked at every 0.1 s")
    game.Tick(0.1)
    Equal(table.concat(seen, ","), "true", "the change seen")
    Equal(#game.errors, 1, "one watcher's error shown, the others still told")
    game.EditModeManagerFrame = nil
    game.env.EditModeManagerFrame = nil
    game.Tick(0.2)
    Equal(table.concat(seen, ","), "true,false", "no manager counts as closed")

    -- Refused calls: only EraUI's, newest first, the last five.
    local offers = 0
    ns.OfferStatus = function() offers = offers + 1 end
    game.Fire("ADDON_ACTION_BLOCKED", "SomeOtherAddon", "Foo()")
    Equal(#ns.blocked, 0, "another addon's refusal isn't EraUI's")
    game.combat, game.editing = true, false
    game.Fire("ADDON_ACTION_BLOCKED", "EraUI", "PlayerFrame:SetPoint()")
    local first = ns.blocked[1]
    Equal(first.event .. " " .. first.func .. " " .. first.time .. " " .. tostring(first.combat) .. " " .. tostring(first.editMode),
        "ADDON_ACTION_BLOCKED PlayerFrame:SetPoint() 12:34:56 true false", "what, when, in a fight or Edit Mode")
    game.combat = false
    for i = 1, 6 do game.Fire("ADDON_ACTION_FORBIDDEN", "EraUI", "Call" .. i .. "()") end
    Equal(#ns.blocked .. " " .. ns.blocked[1].func .. " " .. ns.blocked[5].func, "5 Call6() Call2()", "newest first, five kept")
    Equal(offers, 7, "the status report's offer each time (it says so once itself)")
end

---------------------------------------------------------------------------
-- Game settings (spec 4.9)
---------------------------------------------------------------------------

do
    local game, ns = Loaded({ cvars = { nameplateShowAll = "0", floatingCombatTextCombatDamage = "0",
        floatingCombatTextCombatDamage_v2 = "1" } })
    game.Fire("PLAYER_LOGIN")
    Equal(ns.db.gameDamageNumbers, true, "login reads the game's damage numbers (either on: on)")
    game.cvars.floatingCombatTextCombatDamage_v2 = "0"
    ns.ReadGameDamageNumbers()
    Equal(ns.db.gameDamageNumbers, false, "both off: off")
    game.cvars.floatingCombatTextCombatDamage, game.cvars.floatingCombatTextCombatDamage_v2 = nil, nil
    ns.ReadGameDamageNumbers()
    Equal(ns.db.gameDamageNumbers, false, "neither readable: unchanged")

    local function Writes()
        local n = 0
        for _, line in ipairs(game.cvarLog) do if line:find("^set nameplate") then n = n + 1 end end
        return n
    end
    game.combat = true
    False(ns.SetCVar("nameplateShowAll", "1"), "refused in a fight")
    game.combat = false
    False(ns.SetCVar(nil, "1") or ns.SetCVar("nameplateShowAll", nil), "a missing name or value refused")
    True(ns.SetCVar("nameplateShowAll", 0), "the value it already has (as text): true")
    Equal(Writes(), 0, "without a write")
    True(ns.SetCVar("nameplateShowAll", "1"), "written")
    Equal(game.cvars.nameplateShowAll .. " " .. ns.db.cvarWas.nameplateShowAll, "1 0", "the value from before EraUI kept")
    True(ns.SetCVar("nameplateShowAll", "2"), "written again")
    Equal(ns.db.cvarWas.nameplateShowAll, "0", "the first value kept, once")
    ns.handingBack = true
    game.cvars.nameplateOther = "5"
    True(ns.SetCVar("nameplateOther", "6"), "handing back still writes")
    Equal(ns.db.cvarWas.nameplateOther, nil, "but keeps nothing new")
    ns.handingBack = nil
    local blind = Loaded()
    blind.env.C_CVar = nil
    False(blind.ns.SetCVar("anything", "1"), "no CVar functions: false")
end

---------------------------------------------------------------------------
-- The toggles and the reload question (spec 4.9, 4.10)
---------------------------------------------------------------------------

do
    local game, ns = Loaded()
    local ran, through = Parts(game, ns)
    game.Fire("PLAYER_LOGIN")
    local fitted, refreshed, reloads = {}, 0, 0
    ns.FitBarsToSize = function(big) fitted[#fitted + 1] = tostring(big) end
    ns.RefreshOptionsWindow = function() refreshed = refreshed + 1 end
    ns.ReloadForLayout = function() reloads = reloads + 1 end
    local passes = through.pass
    ns.db.gameDamageNumbers = false
    ns.ToggleChanged("gameDamageNumbers")
    Equal(game.cvars.floatingCombatTextCombatDamage .. game.cvars.floatingCombatTextCombatDamage_v2, "00", "both damage settings written")
    Equal(through.pass .. " " .. refreshed, (passes + 1) .. " 1", "then a pass (through the namespace) and the option list")
    ns.db.oneBag = true
    ns.ToggleChanged("oneBag")
    Equal(game.cvars.combinedBags, "1", "One Bag: the game's Combine Bags")
    ns.db.defaultBarSize = true
    ns.ToggleChanged("defaultBarSize")
    Equal(table.concat(fitted, ","), "true", "the bars fitted to the new size")
    Equal(#game.popups, 0, "no reload question so far")
    ns.db.oneBar = false
    ns.ToggleChanged("oneBar")
    Equal(#game.popups, 0, "a switch that leaves no art: no question")
    ns.db.bags = true
    ns.ToggleChanged("bags")
    Equal(#game.popups, 0, "a reload part turned on: no question")
    ns.db.bags = false
    ns.ToggleChanged("bags")
    Equal(game.popups[1], "ERAUICLASSIC_RELOAD", "a reload part turned off: the reload question")
    local question = game.env.StaticPopupDialogs.ERAUICLASSIC_RELOAD
    Equal(question.text, "Some of the old art stays on screen until the interface reloads.", "its text")
    Equal(question.button1 .. "/" .. question.button2 .. " " .. question.timeout .. " " .. tostring(question.whileDead) .. " "
        .. tostring(question.hideOnEscape) .. " " .. question.preferredIndex, "Reload UI/Later 0 true true 3", "its buttons and manners")
    question.OnAccept()
    Equal(reloads, 1, "Reload Now: the reload that finishes the layout")
end

---------------------------------------------------------------------------
-- Small helpers (spec 4.11, 4.12)
---------------------------------------------------------------------------

do
    local game, ns = Loaded()
    ns.Print("hello")
    Equal(game.prints[1], "|cffe6c56cEraUI:|r hello", "a chat line after the gold EraUI:")
    ns.Print(SECRET)
    Equal(game.prints[2], "|cffe6c56cEraUI:|r <protected value>", "a hidden value never turned into text")
    local lines, flushed, handed = {}, 0, nil
    ns.Persist("nobody listening")
    game.env.EraUIClassic_AttachDevTools(function(given)
        handed = given
        given.devLog = function(line) lines[#lines + 1] = line end
        given.devFlush = function() flushed = flushed + 1 end
    end)
    Equal(handed, ns, "a developer tool is handed the namespace")
    ns.Print("noted")
    ns.BeginOutput("debug")
    ns.FlushNotice()
    Equal(table.concat(lines, " | ") .. " " .. flushed, "noted | === debug 12:34:56 === 1", "its log lines and flush")
    local ok, value = ns.SafeCall(function(a, b) return a + b end, 2, 3)
    Equal(tostring(ok) .. " " .. tostring(value), "true 5", "a protected call's result")
    local before = #game.errors
    ok, value = ns.SafeCall(function() error("oops") end)
    False(ok, "an error contained")
    True(tostring(value):find("oops", 1, true), "its text returned")
    Equal(#game.errors, before + 1, "and shown through the game's error handler")
    game.env.MainActionBar = game.New("Frame", "MainActionBar")
    Equal(ns.GetMainBar(), game.env.MainActionBar, "Action Bar 1 by its Forever name")
    local opened = 0
    ns.OpenOptions = function() opened = opened + 1 end
    game.env.EraUIClassic_OnAddonCompartmentClick()
    Equal(opened, 1, "the AddOns compartment opens whatever OpenOptions is by then")
end

---------------------------------------------------------------------------
-- The art by name (spec 5)
---------------------------------------------------------------------------

do
    local game, ns = Loaded()
    local themed = {}
    ns.ThemeTexture = function(texture, key) themed[#themed + 1] = key; texture.themed = key end
    local MEDIA = "Interface\\AddOns\\EraUI\\Media\\Classic\\"
    local first, second = ns.TexPath("statusBar")
    Equal(first .. " | " .. second, "Interface\\TargetingFrame\\UI-StatusBar | " .. MEDIA .. "UI-StatusBar", "the client's file first")
    Equal((ns.TexPath("statusBarSolid")), "Interface\\Buttons\\WHITE8X8", "the client's white square (no copy)")
    Equal(select(2, ns.TexPath("statusBarSolid")), "Interface\\Buttons\\WHITE8X8", "both ways")
    Equal((ns.TexPath("portraitMask")), "Interface\\CharacterFrame\\TempPortraitAlphaMask", "the portrait mask")
    Equal((ns.TexPath("trackingNone")), MEDIA .. "Tracking-None", "the copy first where the client's file changed")
    Equal((ns.TexPath("microSocialsUp")), MEDIA .. "UI-MicroButton-socials-up", "the Socials sheets: the copy first")
    Equal((ns.TexPath("scrollKnob")) .. " " .. select(2, ns.TexPath("scrollKnob")), MEDIA .. "UI-ScrollBar-Knob " .. MEDIA .. "UI-ScrollBar-Knob",
        "a piece only the copy gets right: the copy both ways")
    True(ns.TEX.trackingBorder ~= nil, "the tracking ring the minimap drawer asks for")
    ns.db.textureSource = "bundled"
    Equal((ns.TexPath("statusBar")), MEDIA .. "UI-StatusBar", "the copies chosen: the copy first")
    ns.db.textureSource = "builtin"
    False(pcall(ns.TexPath, "noSuchArt"), "an unknown name is an error")

    local texture = game.New("Texture")
    True(ns.SetTex(texture, "castBorder"), "set")
    Equal(texture.file .. " " .. game.Look.artResults.castBorder .. " " .. texture.themed, "Interface\\CastingBar\\UI-CastingBar-Border ok castBorder",
        "the client's file, recorded ok, Dark Mode told the same name")
    game.refused["Interface\\CastingBar\\UI-CastingBar-Spark"] = true
    True(ns.SetTex(texture, "castSpark"), "the copy when the client refuses its file")
    Equal(texture.file .. " " .. game.Look.artResults.castSpark, MEDIA .. "UI-CastingBar-Spark fallback", "recorded as a fallback")
    game.refused[MEDIA .. "UI-CastingBar-Spark"] = true
    local missing = game.New("Texture")
    False(ns.SetTex(missing, "castSpark"), "both refused: false")
    Equal(game.Look.artResults.castSpark .. " " .. tostring(missing.themed), "missing castSpark", "recorded missing, Dark Mode still told")

    local button = game.New("Button")
    local face = ns.SetButtonTex(button, "Normal", "closeUp")
    Equal(face ~= nil and face == button:GetNormalTexture() and face.file, "Interface\\Buttons\\UI-Panel-MinimizeButton-Up",
        "a button without that state's texture is given one, from the first file")
    Equal(ns.SetButtonTex(game.New("Frame"), "Normal", "closeUp"), nil, "nothing for a frame without the state's setter and getter")

    Equal(ns.BarFill("statusBar"), "Interface\\TargetingFrame\\UI-StatusBar", "Flat Bars off: the shaded fill")
    game.settings.flatBars = true
    Equal(ns.BarFill("statusBar"), "Interface\\Buttons\\WHITE8X8", "Flat Bars on: the solid square")
    ns.db.textureSource = "bundled"
    Equal(ns.BarFill("statusBar"), "Interface\\Buttons\\WHITE8X8", "the copies chosen: the same square")
    game.settings.flatBars = false
    Equal(ns.BarFill("statusBar"), MEDIA .. "UI-StatusBar", "and the shaded copy without Flat Bars")
end

---------------------------------------------------------------------------
-- The shared names (spec 6)
---------------------------------------------------------------------------

do
    local game, ns = Loaded()
    local Look = game.Look
    local frame = game.New("Frame", "SomeFrame")
    local calls = {}
    frame.DoThing = function() calls[#calls + 1] = "original" end
    False(ns.HookMethod(nil, "DoThing", function() end), "no frame: false")
    True(ns.HookMethod(frame, "DoThing", function() calls[#calls + 1] = "names" end), "hooked")
    True(ns.HookMethod(frame, "DoThing", function() calls[#calls + 1] = "again" end), "asked again: true")
    True(Look.Hook(frame, "DoThing", function() calls[#calls + 1] = "look" end), "a Look file's own hook on the same method")
    frame:DoThing()
    Equal(table.concat(calls, ","), "original,names,look", "each hook once, the Look file's beside it")
    False(ns.HookMethod(frame, "Absent", function() end), "a missing method: false")
    True(ns.missing["SomeFrame:Absent"], "named for the debug report")
    False(ns.HookMethod(game.New("Frame"), "Absent", function() end), "an unnamed frame too")
    True(ns.missing["?:Absent"], "as ?")
    Equal(ns.missing, Look.missingPieces, "one record of missing pieces")
    False(ns.HookGlobal("NoSuchFunction", function() end), "a missing global: false")
    True(ns.missing.NoSuchFunction, "named")
    local once = 0
    True(ns.HookScriptOnce(frame, "OnShow", function() once = once + 1 end), "a script hooked")
    ns.HookScriptOnce(frame, "OnShow", function() once = once + 10 end)
    Look.HookScript(frame, "OnShow", function() once = once + 100 end)
    frame:Hide()
    frame:Show()
    Equal(once, 101, "once per frame and script, beside a Look file's own")
    ns.MissingPiece("SomethingNew")
    ns.MissingPiece("SomethingNew")
    True(Look.missingPieces.SomethingNew, "a piece recorded once")
    local region = game.New("Texture")
    ns.Fade(region)
    Equal(region.alpha, 0, "faded by alpha")
    ns.Unfade(region)
    Equal(region.alpha, 1, "and back")
    frame.Content = { Main = { Bar = "here" } }
    Equal(ns.Path(frame, "Content", "Main", "Bar"), "here", "a path of keys")
    Equal(ns.Path(frame, "Content", "Nope", "Bar"), nil, "nil as soon as a step is missing")
    Equal(ns.PANE_SHADE, 0.9, "the list pane's shade")
    local gold = ns.FONT_GOLD
    Equal(gold and gold.name, "EraUILookGold", "the gold font, made as the file loads")
    Equal(table.concat({ gold:GetTextColor() }, ","), "1,0.82,0", "in the old gold")
    Equal(ns.FONT_GOLD_SMALL and ns.FONT_GOLD_SMALL.model, game.env.GameFontNormalSmall, "and a small one")
    local icon = game.New("Texture", nil, game.New("Frame"))
    ns.RoundIcon(icon, 2)
    ns.RoundIcon(icon, 2)
    Equal(table.concat(icon.coords, ",") .. " " .. icon.masks, "0.1,0.9,0.1,0.9 1", "a round icon: cropped, masked once")
    Equal(ns.Refill, Look.Refill, "Refill")
    local bar = game.New("StatusBar")
    bar.protected = true
    game.combat = true
    True(ns.HeldInFight(bar), "a guarded bar is held in a fight")
    game.combat = false
    False(ns.HeldInFight(bar), "not out of one")

    -- Flat Bars switched live (Core/Settings.lua's tick).
    local passes = 0
    ns.ApplyAll = function() passes = passes + 1 end
    True(ns.RefreshFlatBars(), "nothing to refresh: true")
    ns.RefreshUnitFrameFills = function() return true end
    ns.RefreshCastFills = function() return false end
    False(ns.RefreshFlatBars(), "a bar held in a fight: false")
    Equal(passes, 1, "and the pass after the fight booked, once")
    ns.RefreshCastFills = function() error("fills trouble") end
    True(ns.RefreshFlatBars(), "a refresher's error shown, the rest done")
end

---------------------------------------------------------------------------
-- EraUI's windows sharing the screen (spec 7.1 to 7.3)
---------------------------------------------------------------------------

local function Windows()
    local game, ns, env = Loaded()
    local Look = game.Look
    local function Window(name)
        local window = game.New("Frame", name, env.UIParent)
        window:Hide()
        return window
    end
    local quest, book, talents = Window("EraUIClassicQuestLog"), Window("EraUIClassicSpellBook"), Window("EraUIClassicTalents")
    local placedAt = {}
    local hold, keep
    Look.WindowTraits(quest, {})
    Look.WindowTraits(book, { width = 392, hold = function() return hold end,
        placed = function(x, y) placedAt[#placedAt + 1] = x .. "," .. y end })
    Look.WindowTraits(talents, { keep = function() return keep end })
    for _, name in ipairs({ "CharacterFrame", "FriendsFrame", "PlayerSpellsFrame", "GameMenuFrame", "InspectFrame",
        "CommunitiesFrame" }) do
        env.UIPanelWindows[name] = { area = "left" }
        game.New("Frame", name, env.UIParent):Hide()
    end
    for _, name in ipairs({ "WorldMapFrame", "MerchantFrame" }) do game.New("Frame", name, env.UIParent):Hide() end
    ns.RegisterClassicWindow(quest)
    ns.RegisterClassicWindow(book, true)
    ns.RegisterClassicWindow(talents, true)
    ns.RegisterClassicWindow(book, true)
    local function X(window)
        local point, relative, relativePoint, x, y = window:GetPoint(1)
        if point ~= "TOPLEFT" or relative ~= env.UIParent or relativePoint ~= "TOPLEFT" then return "?" end
        return x .. "," .. y
    end
    return { game = game, ns = ns, env = env, quest = quest, book = book, talents = talents, X = X, placedAt = placedAt,
        Hold = function(x) hold = x end, Keep = function(frame) keep = frame end }
end

do
    local w = Windows()
    local game, env = w.game, w.env
    Equal(#w.book.hooks.OnShow, 1, "each window registered once")
    w.book:Show()
    Equal(w.X(w.book), "0,-104", "the first window at the left edge, 104 below the top")
    Equal(table.concat(w.placedAt, " "), "0,-104", "its placed callback told")
    w.talents:Show()
    True(w.book:IsShown(), "two sharing windows stand together")
    Equal(w.X(w.talents), "392,-104", "the second right of the first's 392 slot")
    w.quest:Show()
    False(w.book:IsShown() or w.talents:IsShown(), "a window that doesn't share closes the others")
    Equal(w.X(w.quest), "0,-104", "and takes the left edge")
    w.quest:Hide()

    -- Right of the character window.
    local character = env.CharacterFrame
    character.rect = { 20, 100, 404, 600 }
    character:Show()
    game.Tick(0.1)
    w.book:Show()
    Equal(w.X(w.book), "372,-104", "beside the character window: its left + 352")
    w.talents:Show()
    Equal(w.X(w.talents), "764,-104", "the next one after it")
    True(character:IsShown(), "the character window stays open")
    character:Hide()
    game.Tick(0.1)
    Equal(w.X(w.book) .. " " .. w.X(w.talents), "0,-104 392,-104", "the character window closing: they step back left")

    -- A held window keeps its place; the others jump past it.
    w.book:Hide()
    w.talents:Hide()
    w.Hold(100)
    w.book:Show()
    Equal(w.X(w.book), "0,-104", "a held window is not moved")
    w.talents:Show()
    Equal(w.X(w.talents), "492,-104", "the next one jumps past the held one's slot")
    w.book:Hide()
    w.talents:Hide()
    w.talents:Show()
    Equal(w.X(w.talents), "0,-104", "alone, the talents take the left edge")
    w.book:Show()
    Equal(w.X(w.talents), "492,-104", "an older window steps past a held one that opened after it")
    Equal(w.X(w.book), "0,-104", "the held one stays where it is")
    w.Hold(nil)
    w.book:Hide()
    w.talents:Hide()

    -- The window's keep frame: started right of it, never closed.
    local inspect = env.InspectFrame
    inspect.rect = { 0, 0, 400, 500 }
    inspect:Show()
    game.Tick(0.1)
    w.Keep(inspect)
    w.talents:Show()
    True(inspect:IsShown(), "the inspect window kept open")
    Equal(w.X(w.talents), "400,-104", "the talents start right of it")
    w.Keep(nil)
    w.talents:Hide()
    inspect:Hide()
    game.Tick(0.1)
end

do
    -- Opening one closes the game's open panels, out of a fight only.
    local w = Windows()
    local game, env, ns = w.game, w.env, w.ns
    for _, name in ipairs({ "FriendsFrame", "WorldMapFrame", "CharacterFrame", "PlayerSpellsFrame", "CommunitiesFrame" }) do
        env[name]:Show()
    end
    ns.guildGhost = true
    game.Tick(0.1)
    w.quest:Show()
    table.sort(game.panelsHidden)
    Equal(table.concat(game.panelsHidden, ","), "FriendsFrame,WorldMapFrame",
        "the game's panels and the world map closed (not the character window, the game's spellbook, the guild window hidden for notes)")
    True(env.CharacterFrame:IsShown() and env.PlayerSpellsFrame:IsShown() and env.CommunitiesFrame:IsShown(), "those stay")
    w.quest:Hide()
    env.FriendsFrame:Show()
    game.Tick(0.1)
    game.panelsHidden = {}
    game.combat = true
    w.quest:Show()
    Equal(#game.panelsHidden, 0, "in a fight the game's panels are left alone")
    True(env.FriendsFrame:IsShown(), "still open")
    game.combat = false
end

do
    -- The game's windows watched: an NPC window, a game panel or the map
    -- closes EraUI's windows; the character window moves them.
    local w = Windows()
    local game, env, ns = w.game, w.env, w.ns
    w.book:Show()
    w.talents:Show()
    env.PlayerSpellsFrame:Show()
    game.Tick(0.1)
    True(w.book:IsShown() and w.talents:IsShown(), "the game's own spellbook opening closes nothing")
    env.CommunitiesFrame:Show()
    ns.guildGhost = true
    game.Tick(0.1)
    True(w.book:IsShown(), "nor the guild window hidden for notes")
    ns.guildGhost = nil
    env.CommunitiesFrame:Hide()
    game.Tick(0.1)
    env.FriendsFrame:Show()
    env.MerchantFrame:Show()
    game.Tick(0.1)
    False(w.book:IsShown() or w.talents:IsShown(), "a vendor: EraUI's windows close")
    False(env.FriendsFrame:IsShown(), "and the social window too")
    env.MerchantFrame:Hide()
    game.Tick(0.1)
    w.book:Show()
    game.combat = true
    env.CharacterFrame.rect = { 0, 0, 384, 500 }
    env.CharacterFrame:Show()
    game.Tick(0.1)
    False(w.book:IsShown(), "the character window opening in a fight closes them instead")
    game.combat = false
    env.CharacterFrame:Hide()
    game.Tick(0.1)
    -- A panel that loads on first use (and joins the game's panel list then)
    -- is watched from its first open.
    w.book:Show()
    env.UIPanelWindows.LateLoadedFrame = { area = "left" }
    local late = game.New("Frame", "LateLoadedFrame", env.UIParent)
    late:Hide()
    game.Fire("ADDON_LOADED", "Blizzard_Late")
    late:Show()
    game.Tick(0.1)
    False(w.book:IsShown(), "a panel loaded just now closes them at its first open")
    local other = game.New("Frame", "EraUIClassicSomethingElse", env.UIParent)
    late:Hide()
    game.Tick(0.1)
    late:Show()
    game.Tick(0.1)
    True(other:IsShown(), "a frame that isn't one of EraUI's windows is never closed")
end

do
    -- A game window already open when the watch starts closes nothing.
    local game, ns, env = Loaded()
    local merchant = game.New("Frame", "MerchantFrame", env.UIParent)
    local window = game.New("Frame", "EraUIClassicQuestLog", env.UIParent)
    window:Hide()
    ns.RegisterClassicWindow(window)
    window:Show()
    game.Tick(0.3)
    True(window:IsShown(), "a vendor already open when the watch starts closes nothing")
    merchant:Hide()
    game.Tick(0.1)
    merchant:Show()
    game.Tick(0.1)
    False(window:IsShown(), "opened again later, it does")
end

---------------------------------------------------------------------------
-- A game panel opened or closed (spec 7.4; Look.ShowPanel and
-- Look.HidePanel in Look/Base.lua, which the window watch, the social and
-- the spell windows use): out of a fight through the game's own panel
-- manager; in a fight a guarded panel is refused and any other is shown or
-- hidden plainly, at the 1.x panels' corner when nothing placed it yet.
---------------------------------------------------------------------------

do
    local game, _, env = Loaded()
    local Look = game.Look
    local opened = {}
    env.ShowUIPanel = function(frame)
        opened[#opened + 1] = frame:GetName()
        frame:Show()
    end
    local panel = game.New("Frame", "SomePanel", env.UIParent)
    panel:Hide()
    True(Look.ShowPanel(panel), "out of a fight: shown")
    True(panel:IsShown() and opened[1] == "SomePanel", "through the game's own panel manager")
    True(Look.ShowPanel(panel), "already open: true")
    Equal(#opened, 1, "without asking the game again")
    True(Look.HidePanel(panel), "out of a fight: closed")
    True(not panel:IsShown() and game.panelsHidden[#game.panelsHidden] == "SomePanel", "through the game's own panel manager")
    True(Look.HidePanel(panel), "already closed: true")

    game.combat = true
    local guarded = game.New("Frame", "GuardedPanel", env.UIParent)
    guarded.protected = true
    guarded:Hide()
    False(Look.ShowPanel(guarded), "in a fight: a guarded panel is refused")
    False(guarded:IsShown(), "and left closed")
    True(Look.ShowPanel(panel), "an unguarded one is shown")
    True(panel:IsShown(), "plainly")
    Equal(#opened, 1, "not through the game's panel manager")
    local point, relative, relativePoint, x, y = panel:GetPoint(1)
    Equal(string.format("%s %s %s %s %s", tostring(point), tostring(relative == env.UIParent), tostring(relativePoint), tostring(x),
        tostring(y)), "TOPLEFT true TOPLEFT 16 -116", "at the 1.x panels' corner when nothing placed it")
    local closedBefore = #game.panelsHidden
    True(Look.HidePanel(panel), "closed in a fight")
    False(panel:IsShown(), "plainly")
    Equal(#game.panelsHidden, closedBefore, "not through the game's panel manager")
    True(Look.ShowPanel(panel), "shown again in the fight")
    Equal(panel:GetNumPoints(), 1, "a placed panel keeps its own place")
    guarded:Show()
    False(Look.HidePanel(guarded), "a guarded panel the game opened is not closed in a fight")
    True(guarded:IsShown(), "and stays open")
    game.combat = false
end

print("Classic base checks passed: " .. checks .. " assertions.")
