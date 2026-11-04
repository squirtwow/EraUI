-- Quest Item Sparkles and Herb and Ore Sparkles (Modules/QuestSparkles.lua)
-- against a mock of the game's settings. Off: nothing listened to and nothing
-- written. On: the game's own settings change and your values
-- are kept; off again, those go back. A change from elsewhere is put right; a
-- fight makes it wait; a value the game won't say about is left alone.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local cvars, writes, events, frames, timers, settings, lockdown, secretRead, saves, module
local target, plateOf, anchors, capped
local SECRET = {}

local function Start(saved, db)
    cvars = {
        outlineModeShowLootEffectWhenDisabled = "0", graphicsOutlineMode = "2", OutlineEngineMode = "2",
        SoftTargetInteract = "1", SoftTargetIconGameObject = "0", SoftTargetIconInteract = "1",
        SoftTargetInteractArc = "1", SoftTargetInteractRange = "10.000000", SoftTargetInteractOnlyInRange = "1",
        SoftTargetLowPriorityIcons = "0", SoftTargetNameplateInteract = "0", nameplateGameObjectMaxDistance = "20",
    }
    capped = {}
    writes, events, frames, timers, lockdown, secretRead, saves = {}, {}, {}, {}, false, nil, 0
    settings = saved or {}
    _G.EraUIDB = db
    _G.issecretvalue = function(value) return value == SECRET end
    _G.InCombatLockdown = function() return lockdown end
    _G.C_Timer = {After = function(_, fn) timers[#timers + 1] = fn end}
    _G.C_CVar = {
        GetCVar = function(name)
            if name == secretRead then return SECRET end
            return cvars[name]
        end,
        SetCVar = function(name, value)
            writes[#writes + 1] = name .. "=" .. value
            cvars[name] = capped[name] or value
        end,
    }
    target, plateOf, anchors = nil, nil, {}
    _G.UIParent = {}
    _G.UnitGUID = function(unit) assert(unit == "softinteract"); return target and target.guid end
    _G.UnitName = function(unit) assert(unit == "softinteract"); return target and target.name end
    _G.C_NamePlate = {GetNamePlateForUnit = function(unit) assert(unit == "softinteract"); return plateOf end}
    local function Widget()
        return setmetatable({}, {__index = function() return function() end end})
    end
    _G.CreateFrame = function()
        local frame = Widget()
        frame.on, frame.shown, frame.alpha = {}, true, 1
        function frame:RegisterEvent(event) self.on[event] = true; events[event] = true end
        function frame:UnregisterEvent(event) self.on[event] = nil; events[event] = nil end
        function frame:SetScript(kind, fn) if kind == "OnUpdate" then self.tick = fn else self.script = fn end end
        function frame:Show() self.shown = true end
        function frame:Hide() self.shown = false end
        function frame:SetAlpha(alpha) self.alpha = alpha end
        function frame:ClearAllPoints() anchors[self] = nil end
        function frame:SetPoint(_, to, _, _, y) anchors[self] = {to = to, y = y} end
        function frame:CreateTexture()
            local star = Widget()
            function star:SetAlpha(alpha) self.alpha = alpha end
            return star
        end
        frames[#frames + 1] = frame
        return frame
    end
    local EraUI = {modules = {}}
    function EraUI:RegisterModule(name, mod) self.modules[name] = mod end
    function EraUI:GetSetting(key) return settings[key] end
    function EraUI:SaveSettings() saves = saves + 1 end
    assert(loadfile("Modules/QuestSparkles.lua"))("EraUI", EraUI)
    module = EraUI.modules.QuestSparkles
    module:Initialize()
end

local function Fire(event, ...)
    for _, frame in ipairs(frames) do
        if frame.on[event] and frame.script then frame.script(frame, event, ...) end
    end
end

local function RunTimers()
    local due = timers
    timers = {}
    for _, fn in ipairs(due) do fn() end
end

-- Off: nothing at all.
Start()
equal(#writes, 0, "off: nothing written")
equal(#frames, 0, "off: nothing listened to")
equal(EraUIDB, nil, "off: nothing saved")

-- Quest items only: outlines off, sparkles on, soft targeting left alone.
Start({questSparkles = true})
equal(cvars.outlineModeShowLootEffectWhenDisabled .. cvars.graphicsOutlineMode .. cvars.OutlineEngineMode, "100", "quest items: the sparkle settings")
equal(cvars.SoftTargetInteract, "1", "quest items: soft targeting left alone")
equal(EraUIDB.sparkleKept.graphicsOutlineMode, "2", "your value kept")
equal(events.CVAR_UPDATE, true, "listening while on")

-- Herbs and ore too.
settings.gatherSparkles = true
module:Refresh()
equal(cvars.SoftTargetInteract .. cvars.SoftTargetIconGameObject .. cvars.SoftTargetInteractArc .. cvars.SoftTargetInteractRange, "312100", "herbs and ore: soft targeting on")
equal(cvars.nameplateGameObjectMaxDistance, "100", "and its name plate's own limit")
equal(EraUIDB.sparkleKept.SoftTargetInteractRange, "10.000000", "the range you had, kept")
equal(EraUIDB.sparkleKept.nameplateGameObjectMaxDistance, "20", "the plate limit you had, kept")
equal(EraUIDB.sparkleKept.SoftTargetIconInteract, nil, "a value already right isn't kept: nothing to put back")

-- Herbs and ore off: those go back, the sparkles stay.
settings.gatherSparkles = false
module:Refresh()
equal(cvars.SoftTargetInteract .. cvars.SoftTargetIconGameObject .. cvars.SoftTargetInteractArc .. cvars.SoftTargetInteractRange, "1" .. "0" .. "1" .. "10.000000", "herbs and ore off: yours back")
equal(cvars.graphicsOutlineMode, "0", "quest item sparkles stay on")

-- All off: everything back, nothing left kept, nothing listened to.
settings.questSparkles = false
module:Refresh()
equal(cvars.outlineModeShowLootEffectWhenDisabled .. cvars.graphicsOutlineMode .. cvars.OutlineEngineMode, "022", "all off: yours back")
equal(EraUIDB.sparkleKept, nil, "nothing left kept")
equal(events.CVAR_UPDATE, nil, "not listening when off")

-- Herbs and ore alone draw their own: the game's outlines stay as they are.
Start({gatherSparkles = true})
equal(cvars.graphicsOutlineMode .. cvars.SoftTargetInteract, "23", "herbs and ore alone: outlines left alone")
equal(cvars.SoftTargetInteractOnlyInRange .. cvars.SoftTargetLowPriorityIcons, "01", "picked out before it's in reach")

-- A graphics preset turns it off: put right on the next frame, once, and your
-- own value stays the one kept.
Start({questSparkles = true})
local before = #writes
cvars.graphicsOutlineMode = "1"
Fire("CVAR_UPDATE", "graphicsOutlineMode", "1")
Fire("CVAR_UPDATE", "GRAPHICSOUTLINEMODE", "1")
equal(#timers, 1, "several changes: one look")
RunTimers()
equal(cvars.graphicsOutlineMode, "0", "put right")
equal(EraUIDB.sparkleKept.graphicsOutlineMode, "2", "your own value still the one kept")
equal(#writes, before + 1, "only that one written")
Fire("CVAR_UPDATE", "someOtherSetting", "1")
equal(#timers, 0, "another setting is none of its business")
Fire("CVAR_UPDATE", SECRET, "1")
equal(#timers, 0, "a secret name is left alone")

-- A range reading back as a longer number isn't a change, so no fight with the game.
Start({gatherSparkles = true})
cvars.SoftTargetInteractRange = "100.000000"
before = #writes
module:Apply()
equal(#writes, before, "the same number isn't rewritten")

-- A number the game caps lower is asked for once, not again and again, and what
-- you had still goes back.
Start({gatherSparkles = true})
capped.nameplateGameObjectMaxDistance = "40"
cvars.nameplateGameObjectMaxDistance = "20"
EraUIDB.sparkleKept.nameplateGameObjectMaxDistance = "20"
module:Apply()
equal(cvars.nameplateGameObjectMaxDistance, "40", "the game's cap")
before = #writes
Fire("CVAR_UPDATE", "nameplateGameObjectMaxDistance", "40")
RunTimers()
module:Apply()
equal(#writes, before, "not asked again")
capped = {}
settings.gatherSparkles = false
module:Refresh()
equal(cvars.nameplateGameObjectMaxDistance, "20", "yours back")

-- In a fight it waits for the end.
Start({})
lockdown = true
settings.questSparkles = true
module:Refresh()
equal(#writes, 0, "in a fight: nothing written")
equal(events.PLAYER_REGEN_ENABLED, true, "waiting for the end")
lockdown = false
Fire("PLAYER_REGEN_ENABLED")
equal(cvars.graphicsOutlineMode, "0", "done as it ends")
equal(events.PLAYER_REGEN_ENABLED, nil, "and it stops waiting")

-- A value the game won't say about is left alone.
Start({})
secretRead = "graphicsOutlineMode"
settings.questSparkles = true
module:Refresh()
equal(cvars.graphicsOutlineMode, "2", "a secret value isn't overwritten")
equal(EraUIDB.sparkleKept.graphicsOutlineMode, nil, "nor kept")

-- EraUI itself turned off: back to yours.
Start({questSparkles = true})
settings.enabled = false
module:Refresh()
equal(cvars.graphicsOutlineMode, "2", "EraUI off: yours back")

-- Logging in with it on, your kept values survive and aren't overwritten.
Start({questSparkles = true}, {sparkleKept = {graphicsOutlineMode = "1"}})
equal(EraUIDB.sparkleKept.graphicsOutlineMode, "1", "kept from before")
settings.questSparkles = false
module:Refresh()
equal(cvars.graphicsOutlineMode, "1", "and those go back")

-- Herbs and ore by name.
Start()
for _, name in ipairs({"Peacebloom", "Wilted Peacebloom", "Khadgar's Whisker", "Black Lotus", "Copper Vein",
    "Incendicite Mineral Vein", "Lesser Bloodstone Deposit", "Ooze Covered Silver Vein"}) do
    equal(module.IsNodeName(name), true, name .. " is a node")
end
for _, name in ipairs({"Mailbox", "Battered Chest", "Campfire", "Felix's Box", ""}) do
    equal(module.IsNodeName(name), false, name .. " isn't")
end
equal(module.IsNodeName(nil), false, "no name isn't")

-- Quest items only: the soft target isn't even listened to.
Start({questSparkles = true})
equal(events.PLAYER_SOFT_INTERACT_CHANGED, nil, "quest items only: the soft target isn't heard")
equal(module.glints, nil, "and no glints are made")

-- Walking up to a herb: its plate on, the glints on the plate.
Start({gatherSparkles = true})
equal(events.PLAYER_SOFT_INTERACT_CHANGED, true, "the soft target heard")
equal(cvars.SoftTargetNameplateInteract, "0", "no plate until there's a node")
equal(module.glints, nil, "no glints made until they're wanted")
target = {guid = "GameObject-0-70-0-0-656160-E53466309F", name = "Wilted Peacebloom"}
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", target.guid)
equal(cvars.SoftTargetNameplateInteract, "1", "a herb: its plate on")
local glints = module.glints
equal(glints.shown, true, "glints showing")
equal(anchors[glints], nil, "no plate yet: placed nowhere")
-- The plate comes a moment later, and the next look finds it.
local plate = {}
plateOf = plate
glints.tick(glints, 0.2)
equal(anchors[glints].to, plate, "on the plate")
equal(anchors[glints].y < 0, true, "below it, down at the node")
local star = glints.stars[1]
glints.tick(glints, 0.2)
local first = star.alpha
glints.tick(glints, 0.4)
equal(first ~= star.alpha, true, "they twinkle")
-- The plate going while it's still the node: they go with it.
plateOf = nil
glints.tick(glints, 0.2)
equal(anchors[glints], nil, "plate gone: placed nowhere")
plateOf = plate
glints.tick(glints, 0.2)
equal(anchors[glints].to, plate, "and back on it")
-- On to another herb before its plate comes: not left where the last one was.
plateOf = nil
target = {guid = "GameObject-0-70-0-0-1618-AB", name = "Peacebloom"}
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", target.guid)
equal(tostring(glints.shown) .. tostring(anchors[glints]), "truenil", "the next herb starts from no plate")
-- Walking on to something else: all off.
target = {guid = "GameObject-0-70-0-0-1-AA", name = "Mailbox"}
plateOf = {}
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", target.guid)
equal(cvars.SoftTargetNameplateInteract .. tostring(glints.shown), "0false", "a mailbox: no plate, no glints")
-- An NPC named like ore isn't ore, and a secret answer isn't a node.
target = {guid = "Creature-0-70-0-0-259209-AA", name = "Copper Vein"}
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", target.guid)
equal(tostring(glints.shown), "false", "an NPC isn't a node")
target = {guid = SECRET, name = "Copper Vein"}
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", SECRET)
equal(tostring(glints.shown), "false", "a secret isn't a node")
-- Ore works too, and turning the option off takes everything down.
target = {guid = "GameObject-0-70-0-0-1731-AA", name = "Copper Vein"}
Fire("PLAYER_SOFT_INTERACT_CHANGED", "", target.guid)
equal(tostring(glints.shown) .. cvars.SoftTargetNameplateInteract, "true1", "ore glints")
settings.gatherSparkles = false
module:Refresh()
equal(tostring(glints.shown), "false", "option off: glints gone")
equal(events.PLAYER_SOFT_INTERACT_CHANGED, nil, "and the soft target isn't heard")
equal(EraUIDB.sparkleKept, nil, "everything back")
equal(cvars.SoftTargetNameplateInteract .. cvars.SoftTargetInteract, "01", "the settings as they were")

io.write("Quest sparkle checks passed: " .. checks .. " assertions.\n")
