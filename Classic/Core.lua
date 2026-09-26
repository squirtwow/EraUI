-- EraUI skinning engine.
-- Owns the Classic-look presentation layer: a module registry, a settings
-- mirror that survives Forever's lost SavedVariables, and the apply pass that
-- drives every skin module. QoL features live in Core/ and Modules/ and are
-- bridged in through Core/Integration.lua.
local ADDON, EraUI = ...
local ns = {}
EraUI.Classic = ns

ns.ADDON = ADDON
ns.PREFIX = "|cffe6c56cEraUI|r: "

ns.DB_DEFAULTS = {
    dbVersion = 1,
    classicBar = true,
    oneBar = false,
    defaultBarSize = false,
    oneBag = false,
    bagsAboveRow = false,
    oneBagColumns = 8,
    barOffsetX = 0,
    barOffsetY = 0,
    barDragged = false,
    bagsHeld = false,
    bagsSnapScale = 0,
    capHeldLeft = false,
    capHeldRight = false,
    barScale = 1,
    buttons = true,
    squareIcons = true,
    castAnim = true,
    emptySlots = true,
    professionsBook = true,
    tradeSkill = true,
    trainer = true,
    tradeSkillSearch = true,
    talents = true,
    professionTabs = false,
    whoTabs = false,
    whoColumn = "zone",
    hideBuffArrow = true,
    spellBookTopRank = false,
    spellDrag = true,
    bagsBesideBars = true,
    gameDamageNumbers = true,
    previousLayout = "",
    layoutSelectPending = false,
    layoutSelectTries = 0,
    pinShape = false,
    microPosText = "",
    microScale = 1,
    bagsFirst = false,
    hideExtraBars = true,
    unitFrames = true,
    castBars = true,
    mirrorTimers = true,
    comboPoints = true,
    hideLastNames = false,
    classColorHealth = false,
    classColorPlates = false,
    mapFade = false,
    welcomeNote = true,
    minimap = true,
    minimapButton = true,
    minimapButtonAngle = 200,
    namePlates = true,
    fullPlates = true,
    questTracker = true,
    questLog = true,
    questLogDual = false,
    unitFramePlayer = true,
    unitFrameTarget = true,
    unitFrameFocus = true,
    unitFramePet = true,
    unitFrameParty = true,
    questMapPane = true,
    gameMenu = true,
    settingsPanel = true,
    panels = true,
    bags = true,
    characterSheet = true,
    statPanes = false,
    statPaneLeft = "section2",
    statPaneRight = "section3",
    spellBook = true,
    guildRoster = true,
    whoList = true,
    spellBookSearch = true,
    welcomed = false,
    -- "builtin" reads the art still shipped by the client; "bundled" reads the
    -- copies in Media/Classic/ when a client build drops the original file.
    textureSource = "builtin",
}

-- Each skin module is { key = db key, apply = fn, restore = fn, init = fn }.
-- Modules run in registration order so bar art lays out after end caps.
ns.modules = {}

function ns.RegisterModule(key, mod)
    mod.key = key
    ns.modules[#ns.modules + 1] = mod
end

-- Optional developer sink; nothing is written to disk by the addon itself.
function ns.Persist(line)
    if ns.debugSink then ns.debugSink(line) end
end

-- Distinguish the Forever client (1.60 build, toc in the 16000s) from
-- modern clients (12.x, toc in the 120000s). Branches key off the build,
-- never off whether a function merely exists.
function ns.OnForever()
    local _, _, _, toc = GetBuildInfo()
    return type(toc) == "number" and toc >= 16000 and toc < 17000
end

function ns.Print(msg)
    if issecretvalue and issecretvalue(msg) then msg = "<protected value>" end
    DEFAULT_CHAT_FRAME:AddMessage(ns.PREFIX .. tostring(msg))
    ns.Persist(msg)
end

function ns.BeginOutput(title)
    ns.Persist("=== " .. title .. " " .. date("%Y-%m-%d %H:%M:%S") .. " ===")
end

function ns.FlushNotice()
    if ns.debugFlushNotice then ns.debugFlushNotice() end
end

-- Hands the namespace to a developer addon. Nothing else calls this.
function EraUIClassic_AttachDevTools(fn)
    fn(ns)
end

function ns.SafeCall(fn, ...)
    local ok, err = xpcall(fn, geterrorhandler(), ...)
    return ok, err
end

function ns.GetMainBar()
    return MainActionBar or MainMenuBar
end

local function CopyDefaults(dst, src)
    for k, v in pairs(src) do
        if dst[k] == nil then
            dst[k] = v
        end
    end
end

-- The Forever client writes an addon's saved variables at logout but does not
-- reliably restore them next login, so every non-default setting is mirrored
-- into one CVar of ours on each change and read back over the saved table at
-- load; on clients with working SavedVariables the file itself is used.
local MIRROR_CVAR = "EraUIClassicSettings"
local function MirrorReady()
    return ns.OnForever() and C_CVar and C_CVar.RegisterCVar and C_CVar.SetCVar and C_CVar.GetCVar
end

function ns.MirrorSave()
    if EraUI.Persistence and EraUI.Persistence.resetting then return end
    if not ns.db or not MirrorReady() then return end
    local pos = ns.db.microPos
    if type(pos) == "table" and pos.point then
        ns.db.microPosText = string.format("%s,%s,%.1f,%.1f", pos.point, pos.relPoint or pos.point, pos.x or 0, pos.y or 0)
    else
        ns.db.microPosText = ""
    end
    local parts = {}
    -- Walk by key rather than pairs() so a metatable probe can never hide keys.
    for k in pairs(ns.DB_DEFAULTS) do
        local v = ns.db[k]
        local t = type(v)
        if (t == "boolean" or t == "number" or t == "string") and ns.DB_DEFAULTS[k] ~= v and not tostring(v):find("[;=]") then
            parts[#parts + 1] = k .. "=" .. (t == "boolean" and (v and "b1" or "b0") or t == "number" and ("n" .. v) or ("s" .. v))
        end
    end
    table.sort(parts)
    pcall(C_CVar.SetCVar, MIRROR_CVAR, table.concat(parts, ";"))
end

local function MirrorLoad()
    if not ns.db or not MirrorReady() then return end
    -- Read before registering: a value the client kept from last session must
    -- not be reset by the registration.
    local ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    if not ok or text == nil then
        pcall(C_CVar.RegisterCVar, MIRROR_CVAR, "")
        ok, text = pcall(C_CVar.GetCVar, MIRROR_CVAR)
    end
    ns.mirrorLoaded = ok and text or nil
    if not ok or not text or text == "" then return end
    for pair in text:gmatch("[^;]+") do
        local k, kind, raw = pair:match("^([%w_]+)=([bns])(.*)$")
        if k then
            if kind == "b" then ns.db[k] = raw == "1"
            elseif kind == "n" then ns.db[k] = tonumber(raw)
            else ns.db[k] = raw end
        end
    end
    if ns.db.microPos == nil and type(ns.db.microPosText) == "string" and ns.db.microPosText ~= "" then
        local point, relPoint, x, y = ns.db.microPosText:match("^(%a+),(%a+),([%-%d%.]+),([%-%d%.]+)$")
        if point then ns.db.microPos = { point = point, relPoint = relPoint, x = tonumber(x) or 0, y = tonumber(y) or 0 } end
    end
end

-- One deferred pass per frame no matter how many hooks fire.
local applyQueued = false
function ns.QueueApply()
    if applyQueued then return end
    applyQueued = true
    C_Timer.After(0, function()
        applyQueued = false
        ns.ApplyAll()
    end)
end

-- Modules move and re-level protected frames (unit frames, action bars), which
-- the client blocks in combat; a pass asked for in combat runs when it ends.
local applyAfterCombat = false
function ns.ApplyAll()
    if not ns.db or not ns.ready or not EraUI:GetSetting("enabled") then return end
    if InCombatLockdown() then
        applyAfterCombat = true
        return
    end
    for _, mod in ipairs(ns.modules) do
        if ns.db[mod.key] ~= false then
            local ok, err = ns.SafeCall(mod.apply)
            ns.applyResults = ns.applyResults or {}
            ns.applyResults[mod.key] = {ok = ok, error = not ok and tostring(err) or nil}
        else
            ns.SafeCall(mod.restore)
        end
    end
    ns.MirrorSave()
end

-- Turning one of these off leaves art on screen that only a reload clears, so
-- the player is asked plainly rather than told in a line of text.
ns.RELOAD_KEYS = {
    bags = true, castBars = true, characterSheet = true, classicBar = true, comboPoints = true,
    gameMenu = true, minimap = true, namePlates = true, panels = true,
    professionsBook = true, tradeSkill = true, groupFinder = true, questMapPane = true, questTracker = true, settingsPanel = true, unitFrames = true,
    -- Not art: once the client's spellbook entries are handed back they stay
    -- marked as the addon's and misbehave until the interface restarts.
    spellBook = true,
}

StaticPopupDialogs["ERAUICLASSIC_RELOAD"] = {
    text = "Some of the old art stays on screen until the interface reloads.",
    button1 = RELOADUI or "Reload Now",
    button2 = LATER or "Later",
    OnAccept = function() ns.ReloadForLayout() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- Floating combat damage is the game's own setting, read from and written back
-- to the game's CVars, and kept nowhere else.
local DAMAGE_CVARS = { "floatingCombatTextCombatDamage", "floatingCombatTextCombatDamage_v2" }
function ns.ReadGameDamageNumbers()
    if not (ns.db and C_CVar and C_CVar.GetCVar) then return end
    local shown
    for _, name in ipairs(DAMAGE_CVARS) do
        local ok, value = pcall(C_CVar.GetCVar, name)
        if ok and value ~= nil then shown = shown or value == "1" end
    end
    if shown ~= nil then ns.db.gameDamageNumbers = shown end
end

function ns.ToggleChanged(key)
    if key == "gameDamageNumbers" then
        for _, name in ipairs(DAMAGE_CVARS) do
            if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, ns.db.gameDamageNumbers and "1" or "0") end
        end
    end
    if key == "defaultBarSize" and ns.FitBarsToSize then ns.FitBarsToSize(ns.db.defaultBarSize == true) end
    if key == "oneBag" then ns.SetCVar("combinedBags", ns.db.oneBag == true and "1" or "0") end
    ns.ApplyAll()
    if ns.RefreshOptionsWindow then ns.RefreshOptionsWindow() end
    if key and ns.RELOAD_KEYS[key] and ns.db and ns.db[key] == false and StaticPopup_Show then
        StaticPopup_Show("ERAUICLASSIC_RELOAD")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("UI_SCALE_CHANGED")
frame:RegisterEvent("DISPLAY_SIZE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_REGEN_ENABLED" then
        if applyAfterCombat then
            applyAfterCombat = false
            ns.ApplyAll()
        end
        return
    end
    if event == "PLAYER_LOGOUT" then
        ns.MirrorSave()
        -- Last code of ours to run when the addon is disabled and reloading:
        -- the one chance to leave the client's UI as it was found.
        if ns.BeingTurnedOff and ns.BeingTurnedOff() and ns.HandBack then pcall(ns.HandBack) end
        return
    end
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        EraUIClassicDB = EraUIClassicDB or {}
        ns.db = EraUIClassicDB
        CopyDefaults(ns.db, ns.DB_DEFAULTS)
        ns.db.lastOutput = nil
        MirrorLoad()
    elseif event == "PLAYER_LOGIN" then
        if not EraUI:GetSetting("enabled") then return end
        ns.ready = true
        ns.ReadGameDamageNumbers()
        for _, mod in ipairs(ns.modules) do
            if mod.init and ns.db[mod.key] ~= false then ns.SafeCall(mod.init) end
        end
        ns.ApplyAll()
        ns.OnEditMode(function() ns.QueueApply() end)
        if ns.WatchEditWrites then ns.WatchEditWrites() end
    else
        ns.QueueApply()
        if event == "PLAYER_ENTERING_WORLD" and not ns.layoutChecked and ns.FirstRun then
            ns.layoutChecked = true
            C_Timer.After(3, function()
                if ns.SelectClassicLayoutIfPending then ns.SelectClassicLayoutIfPending() end
                ns.FirstRun()
            end)
        end
    end
end)

-- One guarded path for every CVar this addon writes. A setting the client
-- guards (the nameplate family among them) refuses an addon write in combat,
-- and a write of a value it already holds is refused the same way for nothing
-- gained; both are avoided here.
function ns.SetCVar(name, value)
    if not name or value == nil then return false end
    if InCombatLockdown() then return false end
    if not (C_CVar and C_CVar.SetCVar and C_CVar.GetCVar) then return false end
    local ok, current = pcall(C_CVar.GetCVar, name)
    if ok and current ~= nil and tostring(current) == tostring(value) then return true end
    -- Remember the pre-addon value so it can be handed back on disable.
    if ok and current ~= nil and ns.db and not ns.handingBack then
        ns.db.cvarWas = ns.db.cvarWas or {}
        if ns.db.cvarWas[name] == nil then ns.db.cvarWas[name] = tostring(current) end
    end
    local wrote = pcall(C_CVar.SetCVar, name, value)
    return wrote
end

-- Edit mode is watched rather than hooked: asking the manager what it is doing
-- leaves its own passes alone (party/raid frames are laid out in them).
local editWatchers = {}
local editWatch, editState
function ns.OnEditMode(fn)
    if type(fn) ~= "function" then return false end
    editWatchers[#editWatchers + 1] = fn
    if not editWatch then
        local mgr = EditModeManagerFrame
        editState = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() and true or false
        editWatch = CreateFrame("Frame")
        editWatch:SetScript("OnUpdate", function(self, elapsed)
            self.since = (self.since or 0) + elapsed
            if self.since < 0.1 then return end
            self.since = 0
            local mgr = EditModeManagerFrame
            local now = mgr and mgr.IsEditModeActive and mgr:IsEditModeActive() and true or false
            if now == editState then return end
            editState = now
            for _, watcher in ipairs(editWatchers) do ns.SafeCall(watcher) end
        end)
    end
    return true
end

-- The client reports refused calls; the last few are kept for the debug command.
ns.blocked = {}
local watchdog = CreateFrame("Frame")
watchdog:RegisterEvent("ADDON_ACTION_BLOCKED")
watchdog:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watchdog:SetScript("OnEvent", function(_, event, addon, func)
    if addon ~= ADDON then return end
    table.insert(ns.blocked, 1, {
        event = event,
        func = tostring(func),
        when = date and date("%H:%M:%S") or "",
        combat = InCombatLockdown() and true or false,
        editMode = EditModeManagerFrame and EditModeManagerFrame.IsEditModeActive
            and EditModeManagerFrame:IsEditModeActive() and true or false,
    })
    for i = #ns.blocked, 6, -1 do table.remove(ns.blocked, i) end
    if ns.OfferStatus then ns.OfferStatus() end
end)

function EraUIClassic_OnAddonCompartmentClick()
    if ns.OpenOptions then ns.OpenOptions() end
end
