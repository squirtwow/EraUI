-- The nameplates' three registry entries, in order: "namePlates" (the 1.x
-- plate, from /era's Friendly and Enemy Nameplates), "classColorPlates" (a
-- player's plate in class colour, off unless chosen) and "fullPlates" (no
-- simplified plates: the game's nameplateSimplifiedTypes held at 0, the
-- player's own value given back when it goes off).
--
-- With Forever Enhanced Nameplates loaded (Squirt's own nameplate addon),
-- EraUI steps aside completely: no plate asked for or touched, no setting
-- written or put back, no frame made. Plates EraUI dressed earlier keep its
-- art until a reload.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local P = Look.Plates

-- The player's own simplified-plates value is mirrored (an empty default)
-- so a lost saved-variables file can't lose it.
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine then
        for key, value in pairs({ namePlates = true, classColorPlates = false, fullPlates = true, savedSimplifiedTypes = "" }) do
            if engine[key] == nil then engine[key] = value end
        end
    end
end

-- Asked on every pass, never kept.
function ns.PlatesHandedOver()
    if type(EraUI.NamePlatesHandedOver) ~= "function" then return false end
    local fine, yes = pcall(EraUI.NamePlatesHandedOver, EraUI)
    return fine and yes == true
end

local SIMPLE = "nameplateSimplifiedTypes"
local EVENTS = Look.Words([[NAME_PLATE_UNIT_ADDED UNIT_LEVEL PLAYER_TARGET_CHANGED DISPLAY_SIZE_CHANGED UI_SCALE_CHANGED
    CVAR_UPDATE UNIT_SPELLCAST_START UNIT_SPELLCAST_STOP UNIT_SPELLCAST_CHANNEL_START UNIT_SPELLCAST_CHANNEL_STOP
    UNIT_SPELLCAST_INTERRUPTED UNIT_SPELLCAST_INTERRUPTIBLE UNIT_SPELLCAST_NOT_INTERRUPTIBLE UNIT_SPELLCAST_DELAYED]])
local CASTS = {}
for _, event in ipairs(EVENTS) do
    if event:find("^UNIT_SPELLCAST") then CASTS[event] = true end
end

local applied = false   -- the look went on this session
local coloured = false  -- class colours went on this session
local driver

---------------------------------------------------------------------------
-- The driver: the game's plate events and a sweep while the look is on
---------------------------------------------------------------------------

-- Plates whose cast look goes back on at the next frame, after the game's
-- own cast bar has drawn the cast (it resets the fill and colour).
local castsDue = Look.Weak()

local function OnEvent(_, event, unit)
    if not P.active then return end
    if CASTS[event] then
        -- Only a plate's own token: the same cast also comes as target or focus.
        if type(unit) ~= "string" or Look.Secret(unit) or not unit:find("^nameplate%d") then return end
        local unitFrame = P.ForUnit(unit)
        if unitFrame then castsDue[unitFrame] = true end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unitFrame = P.ForUnit(unit)
        if unitFrame then P.Dress(unitFrame) end
    elseif event == "UNIT_LEVEL" then
        local unitFrame = P.ForUnit(unit)
        if unitFrame then P.Level(unitFrame) end
    else
        P.DressAll()
    end
end

-- Each frame: the casts due get their look. Every 0.2 s: each plate kept in
-- the look (P.Keep), dressed whole only when new or laid out again by the game.
local waited = 0
local function Sweep(_, elapsed)
    if not P.active then return end
    if next(castsDue) then
        for unitFrame in pairs(castsDue) do
            castsDue[unitFrame] = nil
            Look.Try(P.CastLook, unitFrame)
        end
    end
    waited = waited + (Look.Number(elapsed) or 0)
    if waited < 0.2 then return end
    waited = 0
    P.Each(P.Keep)
end

local function Driver()
    if driver then return driver end
    driver = Look.Build("Frame", UIParent, nil, { size = { 1, 1 } })
    driver:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    for _, event in ipairs(EVENTS) do Look.Listen(driver, event) end
    driver:SetScript("OnEvent", OnEvent)
    driver:SetScript("OnUpdate", Sweep)
    return driver
end

---------------------------------------------------------------------------
-- The legacy style and the simplified plates (through the engine's guarded
-- writer: refused in a fight, the next pass tries again)
---------------------------------------------------------------------------

local function LegacyStyle()
    local saved = ns.db
    if not saved or saved.savedNamePlateStyle == nil then return end
    local style = saved.savedNamePlateStyle
    saved.savedNamePlateStyle = nil
    if type(ns.SetCVar) == "function" then Look.Try(ns.SetCVar, "nameplateStyle", style) end
end

local function Remembered(saved)
    local kept = saved.savedSimplifiedTypes
    return kept ~= nil and kept ~= ""
end

---------------------------------------------------------------------------
-- The registry entries
---------------------------------------------------------------------------

local function StepAside()
    if P.active then ns.needsReload = true end
    P.active = false
    if driver then driver:Hide() end
end

local function PlatesOn()
    if ns.PlatesHandedOver() then return StepAside() end
    P.active, applied = true, true
    LegacyStyle()
    if not NamePlateDriverFrame then
        Look.MissingPiece("NamePlateDriverFrame")
        return
    end
    Driver():Show()
    P.DressAll()
end

-- Every pass while off (cheap, safe to repeat).
local function PlatesOff()
    if ns.PlatesHandedOver() then return StepAside() end
    P.active = false
    if driver then driver:Hide() end
    LegacyStyle()
    for unitFrame in pairs(P.dressed) do Look.Try(P.Release, unitFrame) end
    if applied then ns.needsReload = true end
end

local function ColoursOn()
    if ns.PlatesHandedOver() then return end
    coloured = true
    P.Each(P.Colour)
end

-- Off: the game's own colour handed back once, when they were on.
local function ColoursOff()
    if ns.PlatesHandedOver() or not coloured then return end
    coloured = false
    P.Each(function(unitFrame)
        if type(unitFrame.UpdateHealthColor) == "function" then Look.Try(unitFrame.UpdateHealthColor, unitFrame) end
    end)
end

local function FullOn()
    if ns.PlatesHandedOver() then return end
    local saved, cvars = ns.db, C_CVar
    if not saved or type(cvars) ~= "table" or type(cvars.GetCVar) ~= "function" or type(cvars.SetCVar) ~= "function" then return end
    local fine, value = pcall(cvars.GetCVar, SIMPLE)
    if not fine or Look.Secret(value) then return end
    local number = tonumber(value)
    if not number or number == 0 then return end
    if not Remembered(saved) then saved.savedSimplifiedTypes = tostring(value) end
    if type(ns.SetCVar) == "function" then Look.Try(ns.SetCVar, SIMPLE, "0") end
end

local function FullOff()
    if ns.PlatesHandedOver() then return end
    local saved = ns.db
    if not saved or not Remembered(saved) then return end
    local kept = saved.savedSimplifiedTypes
    saved.savedSimplifiedTypes = nil
    if tonumber(kept) and type(ns.SetCVar) == "function" then Look.Try(ns.SetCVar, SIMPLE, kept) end
end

ns.RegisterModule("namePlates", { apply = PlatesOn, restore = PlatesOff })
ns.RegisterModule("classColorPlates", { apply = ColoursOn, restore = ColoursOff })
ns.RegisterModule("fullPlates", { apply = FullOn, restore = FullOff })
