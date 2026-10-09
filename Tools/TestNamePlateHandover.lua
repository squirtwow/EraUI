-- EraUI steps aside for Forever Enhanced Nameplates. The real
-- Classic/NamePlates.lua (Classic nameplates, class-coloured plates and no
-- simplified plates), Modules/ClassAccents.lua (class outlines on player plate
-- casts) and Classic/OptionsWindow.lua, with the real
-- EraUI:NamePlatesHandedOver (Core/Utils.lua). Every call on the game's plates
-- and every key written on them is recorded. With that addon loaded: no call
-- on a plate, no key, no nameplate setting written or put back, no frame of
-- ours, the plates never even asked for, whatever EraUI's own switches say,
-- and the old options page greys its nameplate boxes with a note. Without it,
-- or when the answer can't be read: EraUI as before.
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
-- Regions of our own: anything asked of them is a quiet no-op.
local function Own()
    return setmetatable({}, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() end end
    end })
end
local function Record(method, result)
    Proto[method] = function(self, ...)
        calls[#calls + 1] = S[self].name .. ":" .. method
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
-- containers, the name and the level frame. Plate 2 is a player.
local function Plate(i)
    local tag = "plate" .. i
    local health = Game(tag .. ".healthBar")
    S[health].fill = Game(tag .. ".healthBar.fill")
    local cast = Game(tag .. ".castBar", {
        Background = Game(tag .. ".castBar.Background"), Border = Game(tag .. ".castBar.Border"),
        Icon = Game(tag .. ".castBar.Icon"), Text = Game(tag .. ".castBar.Text"),
    })
    S[cast].fill = Game(tag .. ".castBar.fill")
    local unitFrame = Game(tag .. ".UnitFrame", {
        unit = "nameplate" .. i,
        HealthBarsContainer = Game(tag .. ".HealthBarsContainer", { healthBar = health }),
        CastBarsContainer = Game(tag .. ".CastBarsContainer", { castBar = cast }),
        name = Game(tag .. ".name"), LevelFrame = Game(tag .. ".LevelFrame"),
    })
    return Game(tag, { UnitFrame = unitFrame, namePlateUnitToken = "nameplate" .. i })
end

-- The rest of the game -----------------------------------------------------------

local plates, asked, created, cvars, cvarWrites
local function World()
    calls, writes, asked, created, cvarWrites = {}, {}, 0, {}, {}
    cvars = { nameplateSimplifiedTypes = "1", nameplateSize = "2", nameplateStyle = "0" }
    plates = { Plate(1), Plate(2) }
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
    CreateFrame = function(kind, name, parent)
        if IsGame(parent) then calls[#calls + 1] = S[parent].name .. ":CreateFrame" end
        local f = Own()
        local events, scripts, hooks = {}, {}, {}
        rawset(f, "events", events)
        rawset(f, "scripts", scripts)
        rawset(f, "shown", true)
        rawset(f, "RegisterEvent", function(_, event) events[event] = true end)
        rawset(f, "SetScript", function(_, script, fn) scripts[script] = fn end)
        rawset(f, "HookScript", function(_, script, fn) hooks[script] = fn end)
        rawset(f, "Show", function(self) rawset(self, "shown", true) end)
        rawset(f, "Hide", function(self) rawset(self, "shown", false) end)
        rawset(f, "IsShown", function(self) return rawget(self, "shown") end)
        created[#created + 1] = f
        return f
    end
    NamePlateDriverFrame = Game("NamePlateDriverFrame")
    InCombatLockdown = function() return false end
    UnitLevel = function() return 20 end
    UnitIsPlayer = function(unit) return unit == "nameplate2" end
    UnitClass = function() return "Mage", "MAGE" end
    UnitIsFriend = function(_, unit) return unit == "nameplate2" end
    UnitIsPVP = function() return false end
    UnitCanAttack = function(_, unit) return unit ~= "nameplate2" end
    C_PlayerInfo = nil
    GetCreatureDifficultyColor = function() return { r = 1, g = 1, b = 0 } end
    RAID_CLASS_COLORS = { MAGE = { r = .25, g = .78, b = .92 } }
    CUSTOM_CLASS_COLORS = nil
    TargetFrame, FocusFrame, PlayerCastingBarFrame, CastingBarFrame = nil, nil, nil, nil
end

-- EraUI's Classic layer around the real NamePlates.lua, loaded fresh.
local function Classic(db)
    local E = {}
    local ns = { db = db, modules = {} }
    E.Classic = ns
    function ns.RegisterModule(key, mod) mod.key = key; ns.modules[key] = mod end
    -- As Classic/Core.lua, Classic/Skin.lua and Classic/Textures.lua.
    function ns.SetCVar(name, value)
        if cvars[name] == tostring(value) then return true end
        C_CVar.SetCVar(name, value)
        return true
    end
    function ns.Path(frame, ...)
        local node = frame
        for i = 1, select("#", ...) do
            if type(node) ~= "table" then return nil end
            node = node[(select(i, ...))]
        end
        return node
    end
    function ns.OwnTexture(frame, key, layer, sublevel)
        frame.fcui = frame.fcui or {}
        local tex = frame.fcui[key]
        if not tex then
            tex = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
            frame.fcui[key] = tex
        end
        return tex
    end
    function ns.Fade(region) if region and region.SetAlpha then region:SetAlpha(0) end end
    function ns.SetTex(texture, key) texture:SetTexture("Classic\\" .. key) end
    function ns.SkullLevel() return false end
    function ns.MissingPiece() end
    function ns.PlateAllowed() return true end
    assert(loadfile("Core/Utils.lua"))("EraUI", E)
    assert(loadfile("Classic/NamePlates.lua"))("EraUI", E)
    return ns, E
end

-- One pass as Classic/Core.lua's ApplyAll runs these modules.
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
local function Has(list, item)
    for _, v in ipairs(list) do if v == item then return true end end
    return false
end

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

-- Without it: EraUI as before ---------------------------------------------------------

-- The same run, recorded, for each way of not being handed over.
local function Before(state)
    World()
    Addons(state)
    local db = { namePlates = true, classColorPlates = false, fullPlates = true, savedNamePlateStyle = "1" }
    local ns = Classic(db)
    Pass(ns)
    Play()
    Pass(ns)
    return { calls = table.concat(calls, " "), writes = table.concat(writes, " "), cvars = table.concat(cvarWrites, " "),
        asked = asked, created = #created, db = db, ns = ns, frame = created[1] }
end
do
    local first = Before("none")
    Equal(first.created, 1, "no FEN: EraUI's own plate driver, as before")
    local events = 0
    for _ in pairs(first.frame.events) do events = events + 1 end
    Equal(events, 11, "no FEN: its eleven events, as before")
    Equal(first.frame.scripts.OnUpdate ~= nil and first.frame:IsShown(), true, "no FEN: and its sweep, running")
    Equal(first.calls:find("plate1.HealthBarsContainer:SetScale", 1, true) ~= nil, true, "no FEN: the plates are laid out as before")
    Equal(first.calls:find("plate2.healthBar:SetStatusBarColor", 1, true) ~= nil, true, "no FEN: a player's plate coloured as before")
    Equal(first.calls:find("plate1.UnitFrame:UpdateHealthColor", 1, true) ~= nil, true,
        "no FEN: class colours off still hands each plate's colour back, as before")
    Equal(first.writes:find("plate1.UnitFrame.fcui", 1, true) ~= nil, true, "no FEN: the same keys as before")
    Equal(first.cvars, "nameplateStyle=1 nameplateSimplifiedTypes=0", "no FEN: the same nameplate settings as before")
    Equal(first.db.savedSimplifiedTypes, "1", "no FEN: the player's simplified plates remembered, as before")
    for _, state in ipairs(ABSENT) do
        local run = Before(state)
        for _, part in ipairs({ "calls", "writes", "cvars", "asked", "created" }) do
            Equal(run[part], first[part], state .. ": " .. part .. " exactly as without the addon")
        end
    end
    -- "No simplified nameplates" off without FEN: the setting goes back, as before.
    World()
    Addons("none")
    local db = { namePlates = false, classColorPlates = false, fullPlates = false, savedSimplifiedTypes = "1" }
    cvars.nameplateSimplifiedTypes = "0"
    local ns = Classic(db)
    Pass(ns)
    Equal(table.concat(cvarWrites, " "), "nameplateSimplifiedTypes=1", "no FEN: switching it off puts the player's setting back, as before")
    Equal(ns.needsReload, true, "no FEN: Classic nameplates off asks for a reload, as before")
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

-- The old options page (Options > AddOns > EraUI) --------------------------------------

do
    World()
    local tooltip = {}
    GameTooltip = {
        SetOwner = function() end, Show = function() end, Hide = function() end,
        SetText = function(_, text) tooltip = { text } end,
        AddLine = function(_, text) tooltip[#tooltip + 1] = text end,
    }
    UISpecialFrames, SlashCmdList, StaticPopupDialogs = {}, {}, {}
    GameFontHighlight = { GetFont = function() return "font", 12, "" end }
    local function Methods(t)
        return setmetatable(t, { __index = function(_, key)
            if type(key) == "string" and key:match("^%u") then return function() return Methods({}) end end
        end })
    end
    local function Frame(kind, parent)
        local f = Methods({ kind = kind, parent = parent, scripts = {}, shown = true, anchors = {} })
        function f:SetScript(event, fn) self.scripts[event] = fn end
        function f:HookScript() end
        function f:IsShown() return self.shown end
        function f:Show() if not self.shown then self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end end
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
    CreateFrame = function(kind, _, parent) return Frame(kind, parent) end
    UIParent = Frame("Frame")
    local function Page(state)
        Addons(state)
        local E = { modules = {} }
        function E:Print() end
        local ns = { modules = {}, ClassicScrollBar = function() return Methods({}) end }
        E.Classic = ns
        function ns.RegisterModule(key, mod) mod.key = key; ns.modules[key] = mod end
        assert(loadfile("Core/Utils.lua"))("EraUI", E)
        assert(loadfile("Classic/NamePlates.lua"))("EraUI", E)
        assert(loadfile("Classic/Options.lua"))("EraUI", E)
        assert(loadfile("Classic/OptionsWindow.lua"))("EraUI", E)
        ns.DB_DEFAULTS, ns.RELOAD_KEYS = {}, {}
        ns.db = { namePlates = true, fullPlates = true, classColorPlates = true, minimap = true, unitFrames = true }
        local canvas = ns.OptionsCanvas()
        canvas:Show()
        local boxes = {}
        for _, box in ipairs(canvas.boxes) do boxes[box.key] = box end
        return boxes
    end
    local NOTE = "Forever Enhanced Nameplates is on and handles nameplates, so EraUI leaves them alone."
    local boxes = Page("fen")
    for _, key in ipairs({ "namePlates", "fullPlates", "classColorPlates" }) do
        local box = boxes[key]
        Equal(box.enabled, false, "FEN loaded: the " .. key .. " box is greyed")
        Equal(box.text.font, "GameFontDisable", "FEN loaded: and its label too")
        Equal(box.checked, true, "FEN loaded: the " .. key .. " choice is kept")
        box.scripts.OnEnter(box)
        Equal(tooltip[2], NOTE, "FEN loaded: the " .. key .. " hover says why")
        Equal(NOTE:find("\226\128\148", 1, true), nil, "no em dash in the note")
    end
    Equal(boxes.minimap.enabled and boxes.classColorHealth.enabled and boxes.minimap.note == nil, true,
        "FEN loaded: the other boxes are as they were")
    for _, state in ipairs(ABSENT) do
        boxes = Page(state)
        for _, key in ipairs({ "namePlates", "fullPlates", "classColorPlates" }) do
            Equal(boxes[key].enabled, true, state .. ": the " .. key .. " box works as before")
            Equal(boxes[key].note, nil, state .. ": no note on " .. key)
        end
    end
end

print("Nameplate handover checks passed: " .. checks .. " assertions.")
