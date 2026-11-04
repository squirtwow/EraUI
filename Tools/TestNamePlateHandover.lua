-- EraUI steps aside for Forever Enhanced Nameplates. The real nameplate look
-- (Look/PlateDress.lua and Look/PlateModule.lua, clean-room 2026-10-21, on
-- Look/Base.lua: Classic nameplates, class-coloured plates and no simplified
-- plates), Modules/ClassAccents.lua (class outlines on player plate casts)
-- and the old options page (Look/Option*.lua), with the real
-- EraUI:NamePlatesHandedOver (Core/Utils.lua). Every call on the game's
-- plates and every key written on them is recorded. With that addon loaded:
-- no call on a plate, no key, no nameplate setting written or put back, no
-- frame of ours, the plates never even asked for, whatever EraUI's own
-- switches say, and the old options page greys its nameplate boxes with a
-- note. Without it, or when the answer can't be read: EraUI's plates, and
-- never a key written on a plate (EraUI's records are its own weak tables).
-- Run from the addon folder: fengari Tools/TestNamePlateHandover.lua
local checks = 0
local function Equal(actual, expected, label)
    checks = checks + 1
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
unpack = unpack or table.unpack

local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == SECRET end
local FEN = "ForeverEnhancedNameplates"
local reported = {}
geterrorhandler = function() return function(problem) reported[#reported + 1] = tostring(problem) end end

-- What the game says about addons: FEN loaded, another addon only, no API,
-- an API that fails, or one that answers a secret.
local function Addons(state)
    if state == "fen" then
        C_AddOns = { IsAddOnLoaded = function(name) return name == FEN, name == FEN end }
    elseif state == "loading" then
        C_AddOns = { IsAddOnLoaded = function(name) return name == FEN, false end }
    elseif state == "other" then
        C_AddOns = { IsAddOnLoaded = function(name) return name == "ForeverEnhancedCooldownManager" end }
    elseif state == "broken" then
        C_AddOns = { IsAddOnLoaded = function() error("no addon list") end }
    elseif state == "secret" then
        C_AddOns = { IsAddOnLoaded = function() return SECRET end }
    elseif state == "odd" then
        C_AddOns = { IsAddOnLoaded = "not a function" }
    else
        C_AddOns = nil
    end
end
local ABSENT = { "none", "other", "broken", "secret", "odd" }

-- The game's frames: every method call and key write recorded ---------------------

local S = setmetatable({}, { __mode = "k" })
local calls, writes = {}, {}
local Proto = {}
local function Game(name, fields)
    local obj = fields or {}
    S[obj] = { name = name }
    return setmetatable(obj, {
        __index = Proto,
        __newindex = function(t, key, value)
            writes[#writes + 1] = S[t].name .. "." .. tostring(key)
            rawset(t, key, value)
        end,
    })
end
local function IsGame(obj) return type(obj) == "table" and S[obj] ~= nil end
-- Regions of our own: anything asked of them is a quiet no-op, but what
-- they are given is kept (shown, text, colour, anchors).
local ownState = setmetatable({}, { __mode = "k" })
local function Own()
    local region = {}
    ownState[region] = { shown = true }
    return setmetatable(region, { __index = function(_, key)
        if key == "Show" then return function(self) ownState[self].shown = true end end
        if key == "Hide" then return function(self) ownState[self].shown = false end end
        if key == "IsShown" then return function(self) return ownState[self].shown end end
        if key == "SetText" then return function(self, text) ownState[self].text = text end end
        if key == "SetTextColor" then return function(self, r, g, b) ownState[self].colour = { r, g, b } end end
        if key == "SetTexture" then return function(self, file) ownState[self].file = file end end
        if key == "SetTexCoord" then return function(self, ...) ownState[self].crop = { ... } end end
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
end
local function Record(method, result)
    Proto[method] = function(self, ...)
        calls[#calls + 1] = S[self].name .. ":" .. method
        S[self].last = S[self].last or {}
        S[self].last[method] = { ... }
        if type(result) == "function" then return result(self, ...) end
        return result
    end
end
for _, method in ipairs({ "ClearAllPoints", "SetPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetScale",
    "SetAlpha", "Show", "Hide", "SetShown", "SetAtlas", "SetTexture", "SetTexCoord", "SetVertexColor",
    "SetStatusBarColor", "SetDrawLayer", "SetShadowColor", "SetShadowOffset", "SetJustifyH", "SetText",
    "SetTextColor", "HookScript", "SetScript", "UpdateHealthColor" }) do
    Record(method)
end
Record("CreateTexture", function() return Own() end)
Record("CreateFontString", function() return Own() end)
Record("GetStatusBarTexture", function(self) return S[self].fill end)
Record("IsForbidden", function(self) return S[self].forbidden == true end)
Record("GetTexture", "Interface\\CastingBar\\UI-CastingBar-Border-Small")
Record("GetTexCoord", function() return 0, 1, 0, 1 end)
Record("IsShown", true)

-- A nameplate as Forever builds it: the unit frame, its health and cast bar
-- containers, the name, the level frames and the debuff list. Plate 2 is a
-- player.
local function Plate(i)
    local tag = "plate" .. i
    local health = Game(tag .. ".healthBar", {
        bgTexture = Game(tag .. ".healthBar.bgTexture"), Text = Game(tag .. ".healthBar.Text"),
    })
    S[health].fill = Game(tag .. ".healthBar.fill")
    local cast = Game(tag .. ".castBar", {
        Background = Game(tag .. ".castBar.Background"), Border = Game(tag .. ".castBar.Border"),
        Icon = Game(tag .. ".castBar.Icon"), Text = Game(tag .. ".castBar.Text"),
        CastTargetNameText = Game(tag .. ".castBar.CastTargetNameText"),
    })
    S[cast].fill = Game(tag .. ".castBar.fill")
    local unitFrame = Game(tag .. ".UnitFrame", {
        unit = "nameplate" .. i,
        HealthBarsContainer = Game(tag .. ".HealthBarsContainer", { healthBar = health }),
        CastBarsContainer = Game(tag .. ".CastBarsContainer", { castBar = cast }),
        name = Game(tag .. ".name"), LevelFrame = Game(tag .. ".LevelFrame"),
        ClassificationFrame = Game(tag .. ".ClassificationFrame"),
        AurasFrame = Game(tag .. ".AurasFrame", { DebuffListFrame = Game(tag .. ".DebuffListFrame") }),
    })
    return Game(tag, { UnitFrame = unitFrame, namePlateUnitToken = "nameplate" .. i })
end

-- The rest of the game -----------------------------------------------------------

local plates, asked, created, cvars, cvarWrites
local levels, canAttack, isPlayer, isFriend, isPvp, classOf
local function World()
    calls, writes, asked, created, cvarWrites = {}, {}, 0, {}, {}
    cvars = { nameplateSimplifiedTypes = "1", nameplateSize = "2", nameplateStyle = "0" }
    plates = { Plate(1), Plate(2) }
    levels = { nameplate1 = 20, nameplate2 = 20, player = 30 }
    canAttack = { nameplate1 = true, nameplate2 = false }
    isPlayer = { nameplate2 = true }
    isFriend = { nameplate2 = true }
    isPvp, classOf = {}, { nameplate2 = "MAGE" }
    C_NamePlate = {
        GetNamePlates = function() asked = asked + 1; return plates end,
        GetNamePlateForUnit = function(unit)
            asked = asked + 1
            for _, plate in ipairs(plates) do if plate.namePlateUnitToken == unit then return plate end end
        end,
    }
    C_CVar = {
        GetCVar = function(name) return cvars[name] end,
        SetCVar = function(name, value) cvarWrites[#cvarWrites + 1] = name .. "=" .. tostring(value); cvars[name] = tostring(value) end,
    }
    -- Frames of ours: events and scripts kept; a Blizzard parent counts as a call on it.
    CreateFrame = function(_, _, parent)
        if IsGame(parent) then calls[#calls + 1] = S[parent].name .. ":CreateFrame" end
        local f = Own()
        local events, scripts, hooks = {}, {}, {}
        rawset(f, "events", events)
        rawset(f, "scripts", scripts)
        rawset(f, "RegisterEvent", function(_, event) events[event] = true end)
        rawset(f, "SetScript", function(_, script, fn) scripts[script] = fn end)
        rawset(f, "HookScript", function(_, script, fn) hooks[script] = fn end)
        created[#created + 1] = f
        return f
    end
    UIParent = Own()
    NamePlateDriverFrame = Game("NamePlateDriverFrame")
    InCombatLockdown = function() return false end
    UnitLevel = function(unit) return levels[unit] end
    UnitIsPlayer = function(unit) return isPlayer[unit] == true end
    UnitClass = function(unit) return "Class", classOf[unit] end
    UnitIsFriend = function(_, unit) return isFriend[unit] == true end
    UnitIsPVP = function(unit) return isPvp[unit] == true end
    UnitCanAttack = function(_, unit) return canAttack[unit] end
    C_PlayerInfo = nil
    GetDifficultyColor = nil
    GetCreatureDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
    RAID_CLASS_COLORS = { MAGE = { r = .25, g = .78, b = .92 } }
    CUSTOM_CLASS_COLORS = nil
    TargetFrame, FocusFrame, PlayerCastingBarFrame, CastingBarFrame = nil, nil, nil, nil
end

-- EraUI's Classic layer around the real plate files, loaded fresh.
local function Classic(db, allowed)
    local E = {}
    local ns = { db = db, modules = {}, DB_DEFAULTS = {} }
    E.Classic = ns
    function ns.RegisterModule(key, mod) mod.key = key; ns.modules[key] = mod end
    -- As the engine's guarded writer (Look/EnginePass.lua).
    function ns.SetCVar(name, value)
        if cvars[name] == tostring(value) then return true end
        C_CVar.SetCVar(name, value)
        return true
    end
    function ns.MissingPiece() end
    -- Core/Integration.lua's question (each side's /era switch).
    function ns.PlateAllowed(unitFrame) return allowed == nil or allowed(unitFrame) end
    assert(loadfile("Core/Utils.lua"))("EraUI", E)
    for _, file in ipairs({ "Look/Base.lua", "Look/PlateDress.lua", "Look/PlateModule.lua" }) do
        assert(loadfile(file))("EraUI", E)
    end
    return ns, E
end

-- One pass as the engine's ApplyAll runs these entries.
local ORDER = { "namePlates", "classColorPlates", "fullPlates" }
local function Pass(ns)
    for _, key in ipairs(ORDER) do
        local mod = ns.modules[key]
        if ns.db[key] ~= false then mod.apply() else mod.restore() end
    end
end
-- The game's events and a few seconds of frames, sent to every frame of ours.
local function Play()
    for _, f in ipairs(created) do
        local onEvent, onUpdate = f.scripts.OnEvent, f.scripts.OnUpdate
        if onEvent then
            for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "UNIT_LEVEL", "PLAYER_TARGET_CHANGED", "UI_SCALE_CHANGED",
                "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_STOP" }) do
                if f.events[event] then onEvent(f, event, "nameplate1") end
            end
        end
        if onUpdate and f:IsShown() then for _ = 1, 8 do onUpdate(f, 0.2) end end
    end
end
local function Count(list, item)
    local n = 0
    for _, v in ipairs(list) do if v == item then n = n + 1 end end
    return n
end
local function Last(region, method) return S[region].last and S[region].last[method] end

-- The handover question itself (Core/Utils.lua) -----------------------------------

do
    World()
    local _, E = Classic({})
    local answers = {}
    for _, state in ipairs({ "fen", "loading", "none", "other", "broken", "secret", "odd" }) do
        Addons(state)
        answers[#answers + 1] = state .. "=" .. tostring(E:NamePlatesHandedOver())
    end
    Equal(table.concat(answers, " "), "fen=true loading=true none=false other=false broken=false secret=false odd=false",
        "handed over only while Forever Enhanced Nameplates is loaded; anything unreadable is no")
    Equal(E.NAMEPLATES_ADDON, FEN, "asks about the nameplate addon by its folder name")
end

-- With Forever Enhanced Nameplates: EraUI never touches a plate --------------------

do
    local runs = 0
    for _, plates_ in ipairs({ true, false }) do
        for _, colours in ipairs({ true, false }) do
            for _, full in ipairs({ true, false }) do
                World()
                Addons("fen")
                local db = { namePlates = plates_, classColorPlates = colours, fullPlates = full,
                    savedNamePlateStyle = "1", savedSimplifiedTypes = "1" }
                -- As EraUI left the game: simplified plates off while its switch is
                -- on, and still off after it was switched off (a put-back is due).
                cvars.nameplateSimplifiedTypes = full and "1" or "0"
                local gameHad = cvars.nameplateSimplifiedTypes
                local ns = Classic(db)
                local label = "FEN loaded, nameplates " .. tostring(plates_) .. ", class colours " .. tostring(colours)
                    .. ", no simplified " .. tostring(full)
                for _ = 1, 3 do Pass(ns) end
                Play()
                Equal(#calls, 0, label .. ": no call on any plate (" .. table.concat(calls, " ") .. ")")
                Equal(#writes, 0, label .. ": no key written on a plate")
                Equal(#cvarWrites, 0, label .. ": no nameplate setting written or put back")
                Equal(asked, 0, label .. ": the plates are never even asked for")
                Equal(#created, 0, label .. ": no frame of ours, so no 0.2 s relayout and no events")
                Equal(tostring(db.savedNamePlateStyle) .. tostring(db.savedSimplifiedTypes), "11", label .. ": the saved choices are kept for later")
                Equal(ns.needsReload, nil, label .. ": no reload asked for")
                Equal(cvars.nameplateSimplifiedTypes, gameHad, label .. ": the game's simplified plates setting is left as it is")
                runs = runs + 1
            end
        end
    end
    Equal(runs, 8, "every combination of EraUI's three nameplate switches")
    -- Its class colour helper, called from anywhere, does nothing either.
    World()
    Addons("fen")
    local ns = Classic({ namePlates = true, classColorPlates = true, fullPlates = true })
    Pass(ns)
    ns.NamePlateClassColor(plates[2].UnitFrame)
    Equal(#calls + #writes, 0, "FEN loaded: the class colour helper leaves a player's plate alone")
end

-- Without it: EraUI's plates ---------------------------------------------------------

-- The same run, recorded, for each way of not being handed over.
local function Before(state)
    World()
    Addons(state)
    local db = { namePlates = true, classColorPlates = false, fullPlates = true, savedNamePlateStyle = "1" }
    local ns, E = Classic(db)
    Pass(ns)
    Play()
    Pass(ns)
    return { calls = table.concat(calls, " "), writes = table.concat(writes, " "), cvars = table.concat(cvarWrites, " "),
        asked = asked, created = #created, db = db, ns = ns, E = E, frame = created[1] }
end
do
    local first = Before("none")
    Equal(first.created, 1, "no FEN: EraUI's own plate driver")
    local events = 0
    for _ in pairs(first.frame.events) do events = events + 1 end
    -- (Fourteen since audit A13 added the cast's interruptible and delayed events.)
    Equal(events, 14, "no FEN: its fourteen events")
    Equal(first.frame.scripts.OnUpdate ~= nil and first.frame:IsShown(), true, "no FEN: and its sweep, running")
    Equal(first.calls:find("plate1.HealthBarsContainer:SetScale", 1, true) ~= nil, true, "no FEN: the plates are laid out")
    Equal(first.calls:find("plate2.healthBar:SetStatusBarColor", 1, true) ~= nil, true, "no FEN: a player's plate coloured")
    Equal(first.calls:find("UpdateHealthColor", 1, true), nil,
        "no FEN: class colours never on this session: no plate's colour handed back on every pass")
    Equal(first.writes, "", "no FEN: no key written on any plate (EraUI's records are its own)")
    Equal(first.cvars, "nameplateStyle=1 nameplateSimplifiedTypes=0", "no FEN: the legacy style written back, then no simplified plates")
    Equal(first.db.savedSimplifiedTypes, "1", "no FEN: the player's simplified plates remembered")
    Equal(first.db.savedNamePlateStyle, nil, "no FEN: the legacy style cleared once written back")
    Equal(first.ns.DB_DEFAULTS.savedSimplifiedTypes, "", "the remembered value has a default, so the settings mirror keeps it")
    for _, state in ipairs(ABSENT) do
        local run = Before(state)
        for _, part in ipairs({ "calls", "writes", "cvars", "asked", "created" }) do
            Equal(run[part], first[part], state .. ": " .. part .. " exactly as without the addon")
        end
    end
    -- "No simplified nameplates" off: the setting goes back, once.
    World()
    Addons("none")
    local db = { namePlates = false, classColorPlates = false, fullPlates = false, savedSimplifiedTypes = "1" }
    cvars.nameplateSimplifiedTypes = "0"
    local ns = Classic(db)
    Pass(ns)
    Pass(ns)
    Equal(table.concat(cvarWrites, " "), "nameplateSimplifiedTypes=1", "no FEN: switching it off puts the player's setting back, once")
    Equal(db.savedSimplifiedTypes, nil, "and forgets it")
    Equal(ns.needsReload, nil, "Classic nameplates off from login: nothing to clear, no reload asked for")
    Equal(#created + asked, 0, "Classic nameplates off from login: no frame, no plate asked for")
    -- A remembered value isn't replaced by the game's next one.
    World()
    Addons("none")
    db = { namePlates = true, classColorPlates = false, fullPlates = true, savedSimplifiedTypes = "3" }
    ns = Classic(db)
    Pass(ns)
    Equal(db.savedSimplifiedTypes, "3", "the first remembered value is kept")
    -- In a fight the guarded writer refuses: the next pass tries again.
    World()
    Addons("none")
    db = { namePlates = true, classColorPlates = false, fullPlates = true }
    ns = Classic(db)
    ns.SetCVar = function() return false end
    Pass(ns)
    Equal(cvars.nameplateSimplifiedTypes .. " " .. tostring(db.savedSimplifiedTypes), "1 1", "refused: the player's value kept, the setting as it was")
end

-- Turned off after it was on: the plates let go of EraUI's look, a reload is due.
do
    World()
    Addons("none")
    local db = { namePlates = true, classColorPlates = false, fullPlates = true }
    local ns, E = Classic(db)
    Pass(ns)
    local P = E.Look.Plates
    local health = plates[1].UnitFrame.HealthBarsContainer.healthBar
    local border = P.pieces[plates[1].UnitFrame].border
    Equal(ownState[border].shown, true, "setup: the 1.x border shows")
    db.namePlates = false
    Pass(ns)
    Equal(ownState[border].shown, false, "Classic nameplates off: EraUI's border put away")
    Equal(Last(plates[1].UnitFrame.HealthBarsContainer, "SetScale")[1], 1, "and the containers at their own scale")
    Equal(Last(health.bgTexture, "SetAlpha")[1], 1, "the game's faded pieces given their alpha back")
    Equal(ns.needsReload, true, "and a reload asked for")
    Equal(created[1]:IsShown(), false, "the driver stops")
    calls = {}
    Play()
    Equal(#calls, 0, "no plate touched after")
end

-- Installed while EraUI's plates are up (it can't happen without a reload, but
-- if it did): EraUI's driver stops, nothing more is done to a plate.
do
    local run = Before("none")
    calls, writes, cvarWrites, asked = {}, {}, {}, 0
    Addons("fen")
    Pass(run.ns)
    Equal(run.frame:IsShown(), false, "handed over mid-session: our driver frame stops")
    run.frame.scripts.OnUpdate(run.frame, 1.2)
    run.frame.scripts.OnEvent(run.frame, "NAME_PLATE_UNIT_ADDED", "nameplate1")
    run.frame.scripts.OnEvent(run.frame, "UNIT_SPELLCAST_START", "nameplate2")
    Equal(#calls + #writes + #cvarWrites + asked, 0, "handed over mid-session: no plate touched or asked for after")
    Equal(run.ns.needsReload, true, "handed over mid-session: the old look clears on a reload")
    -- Handed back: EraUI's look as before.
    Addons("none")
    Pass(run.ns)
    Equal(run.frame:IsShown() and #calls > 0, true, "handed back: EraUI's plates again")
end

-- The plate itself ------------------------------------------------------------------

do
    World()
    Addons("none")
    cvars.nameplateSize = "3"
    local db = { namePlates = true, classColorPlates = false, fullPlates = false }
    local ns, E = Classic(db)
    Pass(ns)
    local P = E.Look.Plates
    local uf = plates[1].UnitFrame
    local healthBox, castBox = uf.HealthBarsContainer, uf.CastBarsContainer
    Equal(Last(healthBox, "SetScale")[1] .. " " .. Last(castBox, "SetScale")[1], "1.25 1.25", "nameplateSize 3: both containers at 1.25")
    Equal(table.concat(Last(castBox, "SetSize"), "x"), "102x8", "the cast container 102 x 8")
    local castAt = Last(castBox, "SetPoint")
    Equal(castAt[1] .. " " .. tostring(castAt[2] == uf) .. " " .. castAt[3] .. " " .. castAt[4] .. "," .. castAt[5], "BOTTOM true BOTTOM 0,4",
        "at the plate's bottom, 4 up")
    local healthAt = Last(healthBox, "SetPoint")
    Equal(healthAt[1] .. " " .. tostring(healthAt[2] == castBox) .. " " .. healthAt[3] .. " " .. healthAt[4] .. "," .. healthAt[5],
        "BOTTOM true TOP 0,10", "the health container 10 over the cast container")
    Equal(Last(uf.HealthBarsContainer.healthBar, "SetAllPoints")[1], healthBox, "the bar fills its container")
    local pieces = P.pieces[uf]
    Equal(ownState[pieces.border].file, "Interface\\AddOns\\EraUI\\Media\\Classic\\Nameplate-Border", "the bundled 1.x border")
    Equal(table.concat(ownState[pieces.border].crop, ","), "0,1,0.5,1", "its lower half")
    Equal(Last(S[uf.HealthBarsContainer.healthBar].fill, "SetTexture")[1], "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill",
        "the shaded 1.x fill")
    for _, key in ipairs({ "bgTexture", "Text" }) do
        Equal(Last(uf.HealthBarsContainer.healthBar[key], "SetAlpha")[1], 0, "the health bar's " .. key .. " faded")
    end
    for _, key in ipairs({ "LevelFrame", "ClassificationFrame" }) do Equal(Last(uf[key], "SetAlpha")[1], 0, "the plate's " .. key .. " faded") end
    local nameAt = Last(uf.name, "SetPoint")
    Equal(nameAt[1] .. " " .. tostring(nameAt[2] == pieces.border) .. " " .. nameAt[3] .. " " .. nameAt[5], "BOTTOM true TOP 2",
        "the name 2 over the border")
    Equal(Last(uf.AurasFrame.DebuffListFrame, "SetPoint")[1], "BOTTOM", "the debuffs above the name")
    -- The level, coloured by difficulty against a foe.
    Equal(ownState[pieces.level].text .. " " .. table.concat(ownState[pieces.level].colour, ","), "20 1,1,0", "a foe's level in its difficulty colour")
    Equal(ownState[pieces.skull].shown, false, "no skull")
    -- A friend's level in gold; a boss's a skull; a hidden level shows nothing.
    canAttack.nameplate1 = false
    P.Level(uf)
    Equal(table.concat(ownState[pieces.level].colour, ","), "1,0.82,0", "a friend's level gold")
    canAttack.nameplate1 = true
    levels.nameplate1 = -1
    P.Level(uf)
    Equal(ownState[pieces.level].text .. " " .. tostring(ownState[pieces.skull].shown), " true", "a boss: the skull, no number")
    levels.nameplate1 = 41
    P.Level(uf)
    Equal(tostring(ownState[pieces.skull].shown), "true", "more than ten above you: the skull")
    levels.nameplate1 = SECRET
    P.Level(uf)
    Equal(ownState[pieces.level].text .. " " .. tostring(ownState[pieces.skull].shown), " false", "a hidden level: nothing shown")
    canAttack.nameplate1 = SECRET
    levels.nameplate1 = 21
    P.Level(uf)
    Equal(table.concat(ownState[pieces.level].colour, ","), "1,0.82,0", "can't tell whether it's a foe: gold")
    -- The cast bar: gold, green while channelling, its border in two halves.
    local cast = castBox.castBar
    Equal(table.concat(Last(cast, "SetStatusBarColor"), ","), "1,0.7,0", "a cast in gold")
    rawset(cast, "channeling", true)
    P.Dress(uf)
    Equal(table.concat(Last(cast, "SetStatusBarColor"), ","), "0,1,0", "a channel in green")
    Equal(table.concat(ownState[pieces.castRight].crop, ","), "0.5,0,0.5,1", "the right half mirrored")
    for _, key in ipairs({ "Background", "Border", "CastTargetNameText" }) do
        Equal(Last(cast[key], "SetAlpha")[1], 0, "the cast bar's " .. key .. " faded")
    end
    Equal(table.concat(Last(cast.Icon, "SetSize"), "x"), "14x14", "the spell's icon 14 x 14")
    -- Friendly players: blue, green while PvP flagged, their class colour with class colours on.
    local friend = plates[2].UnitFrame.HealthBarsContainer.healthBar
    Equal(table.concat(Last(friend, "SetStatusBarColor"), ","), "0,0,1", "a friendly player blue")
    isPvp.nameplate2 = true
    P.Colour(plates[2].UnitFrame)
    Equal(table.concat(Last(friend, "SetStatusBarColor"), ","), "0,1,0", "PvP flagged: green")
    isPvp.nameplate2 = SECRET
    P.Colour(plates[2].UnitFrame)
    Equal(table.concat(Last(friend, "SetStatusBarColor"), ","), "0,0,1", "can't tell about PvP: blue")
    db.classColorPlates = true
    Pass(ns)
    Equal(table.concat(Last(friend, "SetStatusBarColor"), ","), "0.25,0.78,0.92", "class colours: the player's class")
    -- Class colours off again: the game's own colour handed back once.
    calls = {}
    db.classColorPlates = false
    Pass(ns)
    Pass(ns)
    Equal(Count(calls, "plate1.UnitFrame:UpdateHealthColor") .. " " .. Count(calls, "plate2.UnitFrame:UpdateHealthColor"), "1 1",
        "class colours off: each plate's colour handed back to the game once")
    -- Secrets: a hidden "is a player" or class changes nothing.
    calls = {}
    isPlayer.nameplate2 = SECRET
    P.Colour(plates[2].UnitFrame)
    isPlayer.nameplate2 = true
    db.classColorPlates = true
    classOf.nameplate2 = SECRET
    P.Colour(plates[2].UnitFrame)
    Equal(Count(calls, "plate2.healthBar:SetStatusBarColor"), 0, "hidden answers: the game's colour stays")
    classOf.nameplate2 = "MAGE"
    db.classColorPlates = false
    -- A forbidden plate is never touched.
    calls = {}
    S[plates[1].UnitFrame].forbidden = true
    P.DressAll()
    for _, call in ipairs(calls) do
        Equal(call:find("^plate1") == nil or call == "plate1.UnitFrame:IsForbidden" or call == "plate1:IsForbidden", true,
            "a forbidden plate: nothing but the question (" .. call .. ")")
    end
    S[plates[1].UnitFrame].forbidden = false
    -- Each nameplate size.
    for value, scale in pairs({ ["1"] = 0.8, ["2"] = 1, ["4"] = 1.4, ["5"] = 1.6, ["9"] = 1, ["2.5"] = 1 }) do
        cvars.nameplateSize = value
        Equal(P.Scale(), scale, "nameplateSize " .. value)
    end
    cvars.nameplateSize = nil
    Equal(P.Scale(), 1, "no nameplateSize: the plain size")
    Equal(#writes, 0, "no key written on any plate")
end

-- A plate reused for a side whose switch is off: given back to the game's look.
do
    World()
    Addons("none")
    local allow = { nameplate1 = true, nameplate2 = true }
    local db = { namePlates = true, classColorPlates = false, fullPlates = false }
    local ns, E = Classic(db, function(uf) return allow[uf.unit] end)
    Pass(ns)
    local P = E.Look.Plates
    local uf = plates[1].UnitFrame
    local border = P.pieces[uf].border
    Equal(P.dressed[uf] and ownState[border].shown, true, "setup: an enemy plate in the 1.x look")
    allow.nameplate1 = false -- the plate now shows a unit of the side that's switched off
    created[1].scripts.OnEvent(created[1], "NAME_PLATE_UNIT_ADDED", "nameplate1")
    Equal(P.dressed[uf], nil, "the reused plate leaves the look")
    Equal(ownState[border].shown, false, "its 1.x border put away")
    Equal(Last(uf.HealthBarsContainer, "SetScale")[1], 1, "its containers at their own scale")
    Equal(Last(uf.LevelFrame, "SetAlpha")[1], 1, "the game's level frame given its alpha back")
    allow.nameplate1 = true
    created[1].scripts.OnEvent(created[1], "NAME_PLATE_UNIT_ADDED", "nameplate1")
    Equal(P.dressed[uf] and ownState[border].shown, true, "reused again for an allowed unit: the 1.x look again")
    -- The sweep: plates not yet dressed are, every 0.2 s; every plate again each second.
    P.dressed[uf] = nil
    created[1].scripts.OnUpdate(created[1], 0.2)
    Equal(P.dressed[uf], true, "the sweep dresses a plate it finds undressed")
    Equal(#writes, 0, "no key written on any plate")
end

-- Class outlines on player plate casts (Modules/ClassAccents.lua) ------------------

local function Accents(state)
    World()
    Addons(state)
    local E = { modules = {}, settings = { enabled = true, unitFrames = true, castBarClassBorder = true } }
    function E:RegisterModule(name, mod) self.modules[name] = mod end
    function E:GetSetting(key) return self.settings[key] end
    assert(loadfile("Core/Utils.lua"))("EraUI", E)
    assert(loadfile("Modules/ClassAccents.lua"))("EraUI", E)
    local accents = E.modules.ClassAccents
    accents:Initialize()
    for _, event in ipairs({ "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_TARGET_CHANGED" }) do
        created[1].scripts.OnEvent(created[1], event)
    end
    accents:Refresh()
    return table.concat(calls, " "), asked
end
do
    local before, beforeAsked = Accents("none")
    Equal(before:find("plate2.castBar:CreateFrame", 1, true) ~= nil and before:find("plate2.castBar:HookScript", 1, true) ~= nil, true,
        "no FEN: a player's plate cast gets its class outline, as before")
    Equal(beforeAsked > 0, true, "no FEN: the plates are looked at, as before")
    for _, state in ipairs(ABSENT) do
        local run, runAsked = Accents(state)
        Equal(run .. runAsked, before .. beforeAsked, state .. ": outlines exactly as without the addon")
    end
    local after, afterAsked = Accents("fen")
    Equal(after, "", "FEN loaded: no call on any plate cast bar")
    Equal(afterAsked, 0, "FEN loaded: the plates are never asked for")
end

-- Audit A14: plates are handled one at a time. A plate added or removed
-- touches only that plate; target and focus changes touch no plate; a cast
-- bar showing repaints only itself (its plate's token only read); with the
-- option off and no outline ever made, nothing is asked at all.
do
    World()
    Addons("none")
    local lists, singles = 0, 0
    local list, single = C_NamePlate.GetNamePlates, C_NamePlate.GetNamePlateForUnit
    C_NamePlate.GetNamePlates = function() lists = lists + 1; return list() end
    C_NamePlate.GetNamePlateForUnit = function(unit) singles = singles + 1; return single(unit) end
    local E = { modules = {}, settings = { enabled = true, unitFrames = true, castBarClassBorder = false } }
    function E:RegisterModule(name, mod) self.modules[name] = mod end
    function E:GetSetting(key) return self.settings[key] end
    assert(loadfile("Core/Utils.lua"))("EraUI", E)
    assert(loadfile("Modules/ClassAccents.lua"))("EraUI", E)
    local accents = E.modules.ClassAccents
    accents:Initialize()
    local events = created[1]
    local function Fire(event, unit) events.scripts.OnEvent(events, event, unit) end
    lists, singles = 0, 0
    for _ = 1, 20 do Fire("NAME_PLATE_UNIT_ADDED", "nameplate1"); Fire("NAME_PLATE_UNIT_REMOVED", "nameplate1") end
    Equal(lists .. " " .. singles, "0 0", "A14: off, never used: plates coming and going ask for nothing")
    E.settings.castBarClassBorder = true
    lists, singles = 0, 0
    local made = Count(calls, "plate2.castBar:CreateFrame")
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    Equal(lists .. " " .. singles .. " " .. (Count(calls, "plate2.castBar:CreateFrame") - made), "0 1 1",
        "A14: on: a player's plate added: only that plate, its class outline made")
    Fire("PLAYER_TARGET_CHANGED"); Fire("PLAYER_FOCUS_CHANGED")
    Equal(lists .. " " .. singles, "0 1", "A14: a new target or focus: no plate looked at")
    local cast = plates[2].UnitFrame.CastBarsContainer.castBar
    local hook = Last(cast, "HookScript")
    Equal(hook and hook[1], "OnShow", "A14: the plate's cast bar has its show hook")
    local outline = created[#created]
    Equal(outline:IsShown(), true, "the outline shows")
    hook[2](cast)
    Equal(lists .. " " .. singles .. " " .. tostring(outline:IsShown()), "0 1 true",
        "A14: its bar showing repaints only itself, reading its plate's token")
    Fire("NAME_PLATE_UNIT_REMOVED", "nameplate2")
    Equal(lists .. " " .. singles .. " " .. tostring(outline:IsShown()), "0 2 false", "A14: removed: only that plate's outline hidden")
    E.settings.castBarClassBorder = false
    Fire("NAME_PLATE_UNIT_ADDED", "nameplate2")
    hook[2](cast)
    Equal(lists .. " " .. tostring(outline:IsShown()), "0 false", "A14: switched off: a shown bar or a new plate keeps the outline hidden")
    accents:Refresh()
    Equal(lists, 0, "A14: off: the refresh hides the outlines made without looking at any plate")
    Equal(#writes, 0, "A14: no key written on any plate")
end

-- The old options page (Options > AddOns > EraUI) --------------------------------------

do
    World()
    UISpecialFrames, SlashCmdList, StaticPopupDialogs = {}, {}, {}
    GameFontHighlight, GameFontDisable = "GameFontHighlight", "GameFontDisable"
    local function Methods(t)
        return setmetatable(t, { __index = function(_, key)
            if type(key) == "string" and key:match("^%u") then return function() return nil end end
        end })
    end
    local function Frame(kind, parent)
        local f = Methods({ kind = kind, parent = parent, scripts = {}, shown = true, anchors = {} })
        function f:SetScript(event, fn) self.scripts[event] = fn end
        function f:HookScript(event, fn) self.scripts["hook" .. event] = fn end
        function f:IsShown() return self.shown end
        function f:Show() if not self.shown then self.shown = true; if self.scripts.hookOnShow then self.scripts.hookOnShow(self) end end end
        function f:Hide() self.shown = false end
        function f:SetChecked(on) self.checked = on and true or false end
        function f:GetChecked() return self.checked end
        function f:SetEnabled(on) self.enabled = on end
        function f:SetFontObject(font) self.font = font end
        function f:SetText(text) self.text = text end
        function f:GetText() return self.text end
        function f:GetWidth() return 620 end
        function f:CreateTexture() return Frame("Texture", self) end
        function f:CreateFontString() return Frame("FontString", self) end
        return f
    end
    CreateFrame = function(kind, name, parent)
        local f = Frame(kind, parent)
        if name then _G[name] = f end
        return f
    end
    UIParent = Frame("Frame")
    local function Page(state)
        Addons(state)
        local E = { modules = {} }
        function E:Print() end
        local ns = { modules = {}, DB_DEFAULTS = {}, RELOAD_KEYS = {} }
        E.Classic = ns
        function ns.RegisterModule(key, mod) mod.key = key; ns.modules[key] = mod end
        assert(loadfile("Core/Utils.lua"))("EraUI", E)
        for _, file in ipairs({ "Look/Base.lua", "Look/PlateDress.lua", "Look/PlateModule.lua", "Look/ChromeKit.lua",
            "Look/OptionList.lua", "Look/OptionRows.lua", "Look/OptionPage.lua", "Look/OptionOpen.lua" }) do
            assert(loadfile(file))("EraUI", E)
        end
        ns.db = { namePlates = true, fullPlates = true, classColorPlates = true, minimap = true, unitFrames = true }
        local canvas = ns.OptionsCanvas()
        canvas:Show()
        return E.Look.Options.pages[canvas].byKey, E.Look
    end
    local NOTE = "Forever Enhanced Nameplates is on and handles nameplates, so EraUI leaves them alone."
    local rows, Look = Page("fen")
    for _, key in ipairs({ "namePlates", "fullPlates", "classColorPlates" }) do
        local row = rows[key]
        Equal(row.frame.enabled, false, "FEN loaded: the " .. key .. " box is greyed")
        Equal(row.text.font, "GameFontDisable", "FEN loaded: and its label too")
        Equal(row.frame.checked, true, "FEN loaded: the " .. key .. " choice is kept")
        row.frame.scripts.OnEnter(row.frame)
        Equal(Look.TipOwner(), row.frame, "FEN loaded: the " .. key .. " hover shows EraUI's own tooltip box")
        local lines = Look.Options.TipRows(row.frame)
        Equal(lines[2][1], NOTE, "FEN loaded: the " .. key .. " hover says why, as its second line")
        Equal(NOTE:find("\226\128\148", 1, true), nil, "no em dash in the note")
        row.frame.scripts.OnLeave(row.frame)
        Equal(Look.TipOwner(), nil, "and it goes when the mouse leaves")
    end
    Equal(rows.minimap.frame.enabled and rows.classColorHealth.frame.enabled and rows.minimap.note == nil, true,
        "FEN loaded: the other boxes are as they were")
    for _, state in ipairs(ABSENT) do
        rows = Page(state)
        for _, key in ipairs({ "namePlates", "fullPlates", "classColorPlates" }) do
            Equal(rows[key].frame.enabled, true, state .. ": the " .. key .. " box works as before")
            Equal(rows[key].note, nil, state .. ": no note on " .. key)
        end
    end
end

-- Audit A13: the sweep dresses a plate whole only when it is new or the game
-- has laid it out again (its health box back on the game's two points; EraUI
-- gives it one); otherwise every 0.2 s only the colour, and the shade when
-- the game put its own art back. Cast events count only for a plate's own
-- token (never target or focus), the interruptible and delayed ones too,
-- and the cast's look goes back on at the next frame, after the game's own
-- cast bar has drawn it.
do
    -- Points on the game's frames counted, the fill's art read back.
    local clear, point, texture, atlas = Proto.ClearAllPoints, Proto.SetPoint, Proto.SetTexture, Proto.SetAtlas
    Proto.ClearAllPoints = function(self, ...) S[self].points = {}; return clear(self, ...) end
    Proto.SetPoint = function(self, where, ...)
        S[self].points = S[self].points or {}
        S[self].points[where] = true
        return point(self, where, ...)
    end
    Proto.SetTexture = function(self, ...) S[self].atlas = nil; return texture(self, ...) end
    Proto.SetAtlas = function(self, name, ...) S[self].atlas = name; return atlas(self, name, ...) end
    Record("GetNumPoints", function(self)
        local n = 0
        for _ in pairs(S[self].points or {}) do n = n + 1 end
        return n
    end)
    Record("GetAtlas", function(self) return S[self].atlas end)
    World()
    Addons("none")
    -- As the game: the target's and focus's own plates answer their tokens too.
    local forUnit = C_NamePlate.GetNamePlateForUnit
    C_NamePlate.GetNamePlateForUnit = function(unit)
        if unit == "target" or unit == "focus" then return plates[1] end
        return forUnit(unit)
    end
    local ns = Classic({ namePlates = true, classColorPlates = false, fullPlates = true })
    Pass(ns)
    local driver = created[1]
    local onEvent, sweep = driver.scripts.OnEvent, driver.scripts.OnUpdate
    local box = plates[1].UnitFrame.HealthBarsContainer
    local function Laid(from) return Count(calls, "plate1.HealthBarsContainer:SetScale") - from end
    local function Coloured(from) return Count(calls, "plate2.healthBar:SetStatusBarColor") - from end
    sweep(driver, 0.2)
    Equal(Laid(0) >= 1, true, "A13: the plates dressed")
    local laid, coloured = Count(calls, "plate1.HealthBarsContainer:SetScale"), Count(calls, "plate2.healthBar:SetStatusBarColor")
    for _ = 1, 25 do sweep(driver, 0.2) end
    Equal(Laid(laid), 0, "A13: five seconds of sweeps: a plate still in the look is never laid out again")
    Equal(Coloured(coloured), 25, "A13: but a player's plate is coloured on every sweep")
    -- The game lays the plate out again (UpdateAnchors: two points).
    box:ClearAllPoints()
    box:SetPoint("BOTTOMLEFT", plates[1].UnitFrame.CastBarsContainer, "TOPLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", plates[1].UnitFrame.CastBarsContainer, "TOPRIGHT", 0, 0)
    laid = Count(calls, "plate1.HealthBarsContainer:SetScale")
    sweep(driver, 0.2)
    Equal(Laid(laid), 1, "A13: laid out again by the game: dressed whole on the next sweep")
    Equal(box:GetNumPoints(), 1, "A13: and back on EraUI's one point")
    -- The game puts its own art back on the fill: shaded again, nothing else.
    local fill = S[plates[1].UnitFrame.HealthBarsContainer.healthBar].fill
    fill:SetAtlas("UI-HUD-CoolDownManager-Bar")
    laid = Count(calls, "plate1.HealthBarsContainer:SetScale")
    sweep(driver, 0.2)
    Equal(tostring(fill:GetAtlas()) .. " " .. Laid(laid), "nil 0", "A13: the game's art back on the fill: shaded again, not laid out")
    -- Casts: the plate's own token only, the look at the next frame.
    local function Casts() return Count(calls, "plate1.castBar:SetStatusBarColor") end
    local before = Casts()
    for _, unit in ipairs({ "target", "focus", "player" }) do onEvent(driver, "UNIT_SPELLCAST_START", unit) end
    sweep(driver, 0.01)
    Equal(Casts(), before, "A13: a cast seen as target, focus or player: no plate touched")
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
        "UNIT_SPELLCAST_DELAYED" }) do
        onEvent(driver, event, "nameplate1")
    end
    Equal(Casts(), before, "A13: the plate's own cast events: nothing yet (the game's cast bar draws first)")
    laid = Count(calls, "plate1.HealthBarsContainer:SetScale")
    sweep(driver, 0.01)
    Equal(Casts() .. " " .. Laid(laid), (before + 1) .. " 0", "A13: at the next frame its cast look once, the plate not laid out")
    sweep(driver, 0.01)
    Equal(Casts(), before + 1, "A13: and only once")
    -- Its side no longer allowed (a faction change): out of the look.
    ns.PlateAllowed = function(unitFrame) return unitFrame ~= plates[2].UnitFrame end
    local scaled = Count(calls, "plate2.HealthBarsContainer:SetScale")
    sweep(driver, 0.2)
    Equal(Count(calls, "plate2.HealthBarsContainer:SetScale") - scaled, 1, "A13: a plate whose side is no longer allowed leaves the look")
    Equal(Last(plates[2].UnitFrame.HealthBarsContainer, "SetScale")[1], 1, "A13: its container back at the game's scale")
    scaled = Count(calls, "plate2.HealthBarsContainer:SetScale")
    sweep(driver, 0.2)
    Equal(Count(calls, "plate2.HealthBarsContainer:SetScale") - scaled, 0, "A13: and is left alone after that")
    Proto.ClearAllPoints, Proto.SetPoint, Proto.SetTexture, Proto.SetAtlas = clear, point, texture, atlas
    Proto.GetNumPoints, Proto.GetAtlas = nil, nil
end

Equal(table.concat(reported, " || "), "", "no error handed to the game's error handler")
print("Nameplate handover checks passed: " .. checks .. " assertions.")
