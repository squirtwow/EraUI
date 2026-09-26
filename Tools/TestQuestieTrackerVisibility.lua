-- Loads EraUI's shipped adapter. No adjacent Questie installation is required.
-- Secure wrappers honor Blizzard's eligibility and second-return message gate.
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function Setup(options)
    options = options or {}
    local combat, secure = options.combat or false, false
    local frames, modules, hooks = {}, {}, 0
    local nativeRequest = false
    local function Native(fn, ...)
        local previous = secure
        secure = true
        local ok, a, b = pcall(fn, ...)
        secure = previous
        assert(ok, a)
        return a, b
    end
    local function Ordinary(fn, ...)
        local previous = secure
        secure = false
        local ok, a = pcall(fn, ...)
        secure = previous
        assert(ok, a)
    end
    local function Frame(protected)
        local f = { protected=protected, scripts={}, events={}, attrs={}, refs={}, wraps={}, hooks={}, shown=true, updates=0, onShows=0, content=true }
        function f:RegisterEvent(event) self.events[event] = true end
        function f:SetScript(event, fn) self.scripts[event] = fn end
        function f:HookScript(event, fn) self.hooks[event] = self.hooks[event] or {}; table.insert(self.hooks[event], fn) end
        function f:IsProtected() return self.protected end
        function f:IsShown() return self.shown end
        function f:SetAttribute(key, value) assert(not combat, "insecure policy write in combat"); self.attrs[key] = value end
        function f:GetAttribute(key) return self.attrs[key] end
        function f:SetFrameRef(key, value) assert(not combat, "frame reference in combat"); self.refs[key] = value end
        function f:GetFrameRef(key) return self.refs[key] end
        function f:Execute(body)
            assert(not combat, "addon Execute in combat")
            Native(assert(load(body, "restricted execute", "t", { self=self })))
        end
        function f:WrapScript(target, event, pre, post)
            assert(not combat, "wrapping in combat")
            Equal(self.protected, true, "wrapper header explicitly protected")
            Equal(event, "OnShow", "only native visibility wrapped")
            target.wraps[#target.wraps+1] = {header=self, pre=pre, post=post}
        end
        function f:Show()
            assert(not combat or secure or not self.protected, "insecure protected Show")
            if self.shown then return end
            self.shown = true
            local messages = {}
            for i, wrapper in ipairs(self.wraps) do
                if not combat or self:IsProtected() then
                    local allow, message = Native(assert(load(wrapper.pre, "restricted pre", "t", {self=self, control=wrapper.header})))
                    if allow == false then return end
                    messages[i] = message
                end
            end
            self.onShows = self.onShows + 1
            if self.scripts.OnShow then Ordinary(self.scripts.OnShow, self) end
            for _, fn in ipairs(self.hooks.OnShow or {}) do Ordinary(fn, self) end
            for i, wrapper in ipairs(self.wraps) do
                if wrapper.post and messages[i] ~= nil then
                    Native(assert(load(wrapper.post, "restricted post", "t", {self=self, control=wrapper.header, message=messages[i]})))
                end
            end
        end
        function f:Hide() assert(not combat or secure or not self.protected, "insecure protected Hide"); self.shown=false end
        function f:Update()
            assert(not combat, "native update invoked by addon in combat")
            self.updates=self.updates+1
            if self.content then self:Show() else self:Hide() end
        end
        frames[#frames+1] = f
        return f
    end
    local env = setmetatable({}, {__index=_G})
    env._G = env
    env.InCombatLockdown = function() return combat end
    env.CreateFrame = function(_, _, _, template)
        assert(not combat or not template, "secure frame creation during combat")
        return Frame(template == "SecureHandlerBaseTemplate")
    end
    env.hooksecurefunc = function(object, method, callback)
        hooks = hooks + 1
        local original = assert(object[method])
        object[method] = function(...)
            local result = original(...)
            Ordinary(callback, ...)
            return result
        end
    end
    local tracker = Frame(options.protected ~= false)
    local function AddLegacyHook(frame)
        -- Model a pre-existing Questie hide request. Its ordinary combat path
        -- waits for combat to end, just as the unpatched Forever compatibility does.
        frame:HookScript("OnShow", function(self)
            if nativeRequest and not combat then self:Hide() end
        end)
    end
    AddLegacyHook(tracker)
    if not options.lateTracker then env.ObjectiveTrackerFrame = tracker end
    local questie = {db={profile={trackerEnabled=options.enabled ~= false, showBlizzardQuestTimer=false}}, enabled=true}
    function questie:IsEnabled() return self.enabled end
    function questie:OnEnable() self.enabled=true end
    function questie:OnDisable() self.enabled=false end
    function questie:RefreshConfig() end
    local qt = {calls=0}
    function qt:Update() self.calls=self.calls+1 end
    function qt:Enable() questie.db.profile.trackerEnabled=true; self:Update() end
    function qt:Disable() questie.db.profile.trackerEnabled=false; self:Update() end
    function qt:Toggle() questie.db.profile.trackerEnabled=not questie.db.profile.trackerEnabled; self:Update() end
    local compat = {}
    function compat.HideWatchFrame() nativeRequest=true; if not combat and env.ObjectiveTrackerFrame then env.ObjectiveTrackerFrame:Hide() end end
    function compat.ShowWatchFrame() nativeRequest=false; if not combat and env.ObjectiveTrackerFrame then env.ObjectiveTrackerFrame:Update() end end
    local function LoadQuestie()
        env.Questie = questie
        env.QuestieLoader = {ImportModule=function(_, name) return ({QuestieTracker=qt, QuestieCompat=compat})[name] end}
    end
    if not options.absent then LoadQuestie() end
    local E = {settings={enabled=true}, Classic={OnForever=function() return options.forever ~= false end}}
    function E:RegisterModule(name, module) modules[name]=module end
    function E:GetSetting(key) return self.settings[key] end
    function E:SetSetting(key, value) self.settings[key]=value end
    assert(loadfile("Modules/QuestieCompatibility.lua", "t", env))("EraUI", E)
    local module = modules.QuestieCompatibility
    module:Initialize()
    local function Event(event)
        for _, f in ipairs(frames) do if f.events[event] then Ordinary(f.scripts.OnEvent, f, event) end end
    end
    return {E=E, module=module, tracker=tracker, qt=qt, compat=compat, questie=questie, frames=frames,
        combat=function(value) combat=value end, event=Event, hookCount=function() return hooks end,
        show=function(frame) Native(function() (frame or tracker):Show() end) end,
        loadTracker=function() env.ObjectiveTrackerFrame=tracker; Event("ADDON_LOADED") end,
        loadQuestie=function() LoadQuestie(); Event("ADDON_LOADED") end,
        replaceTracker=function() local f=Frame(true); AddLegacyHook(f); env.ObjectiveTrackerFrame=f; Event("ADDON_LOADED"); return f end}
end

for _, protected in ipairs({true, false}) do
    local s = Setup({protected=protected})
    Equal(s.tracker.shown, false, "native tracker initially hidden")
    for _=1,3 do s.show(); Equal(s.tracker.shown, false, "idle Orgrimmar native re-show suppressed") end
    s.combat(true)
    for _=1,3 do s.show(); Equal(s.tracker.shown, false, "combat re-show suppressed for either protection state") end
    Equal(s.tracker.onShows, 6, "original native OnShow still runs")
    s.questie.db.profile.trackerEnabled=false
    s.qt:Update()
    s.show()
    Equal(s.tracker.shown, false, "combat policy release waits for combat end")
    s.combat(false); s.event("PLAYER_REGEN_ENABLED")
    Equal(s.tracker.shown, true, "native visibility restored after combat")
    s.compat.HideWatchFrame() -- stale request from an older Questie implementation
    s.qt:Enable()
    local hooks = s.hookCount()
    for _=1,10 do s.qt:Update(); s.module:Refresh() end
    Equal(s.hookCount(), hooks, "repeated updates do not stack method hooks")
    Equal(#s.tracker.wraps, 1, "one secure wrapper per native tracker")
    s.qt:Disable()
    Equal(s.tracker.shown, true, "disable releases the older Questie hide request too")
    s.qt:Toggle()
    Equal(s.tracker.shown, false, "slash toggle enables suppression")
    s.questie.db.profile.showBlizzardQuestTimer=true; s.qt:Update()
    Equal(s.tracker.shown, true, "explicit Blizzard timer preference respected")
    s.questie.db.profile.showBlizzardQuestTimer=false; s.questie:RefreshConfig()
    Equal(s.tracker.shown, false, "profile refresh reinstates suppression")
    s.questie:OnDisable()
    Equal(s.tracker.shown, true, "disabling Questie releases suppression")
    s.questie:OnEnable()
    Equal(s.tracker.shown, false, "re-enabling Questie reinstates suppression")
    s.E:SetSetting("enabled", false)
    Equal(s.tracker.shown, true, "EraUI disable releases its own suppression")
    s.E:SetSetting("enabled", true)
    s.tracker.content=false; s.qt:Disable()
    Equal(s.tracker.shown, false, "native update can keep an empty tracker hidden")
    for _, f in ipairs(s.frames) do Equal(f.scripts.OnUpdate, nil, "no recurring polling") end
end

local absent = Setup({absent=true})
Equal(absent.tracker.shown, true, "no Questie leaves native tracker alone")
Equal(#absent.tracker.wraps, 0, "no Questie installs no native wrapper")
absent.loadQuestie()
Equal(absent.tracker.shown, false, "late Questie loading supported")
local disabled = Setup({enabled=false})
Equal(disabled.tracker.shown, true, "Questie tracker disabled at login")
disabled.qt:Enable()
Equal(disabled.tracker.shown, false, "later enable is observed")
local late = Setup({lateTracker=true})
late.loadTracker(); Equal(late.tracker.shown, false, "late native tracker loading supported")
local replacement = late.replaceTracker()
Equal(replacement.shown, false, "replacement native frame suppressed")
late.show(late.tracker); Equal(late.tracker.shown, true, "old frame is no longer owned")
late.combat(true); late.show(replacement)
Equal(replacement.shown, false, "replacement wrapper handles combat")
local loginCombat = Setup({combat=true})
Equal(#loginCombat.tracker.wraps, 0, "initial secure setup deferred in combat")
loginCombat.combat(false); loginCombat.event("PLAYER_REGEN_ENABLED")
Equal(loginCombat.tracker.shown, false, "deferred setup applies after combat")
loginCombat.combat(true); loginCombat.show()
Equal(loginCombat.tracker.shown, false, "later combat covered after deferred setup")
local classic = Setup({forever=false})
Equal(classic.tracker.shown, true, "adapter is Forever-only")
Equal(classic.hookCount(), 0, "other clients receive no compatibility hooks")
print("Questie tracker visibility: " .. checks .. " assertions passed")
