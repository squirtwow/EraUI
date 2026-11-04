-- "Fade map while moving" (registry entry "mapFade", off by default, in the
-- Classic option list): the game's own mapFade setting, which dims the world
-- map while you move. No art, no frames of the game's touched.
--
-- Every pass writes EraUI's saved choice to the game ("1" on, "0" off)
-- through the engine's guarded setting writer, which skips a value the game
-- already holds, never writes in a fight, and notes the game's value from
-- before EraUI first changed it (handed back if EraUI is turned off). A
-- change made in the game's own settings while EraUI runs is followed: the
-- saved choice and the option list take it.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look

local fade = { on = false, writing = false }
local listener

do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine and engine.mapFade == nil then engine.mapFade = false end
end

-- Any value but "0", 0 or false is on.
local function IsOn(value)
    return not (value == "0" or value == 0 or value == false)
end

local function GameChanged(_, _, name, value)
    if fade.writing then return end
    if type(name) ~= "string" or Look.Secret(name) or name:lower() ~= "mapfade" or Look.Secret(value) then return end
    local on = IsOn(value)
    local saved = ns.db
    if saved == nil or (on == (saved.mapFade == true) and on == fade.on) then return end
    saved.mapFade = on
    fade.on = on
    if type(ns.RefreshOptionsWindow) == "function" then Look.Try(ns.RefreshOptionsWindow) end
end

local function FollowGame()
    if listener then return end
    listener = CreateFrame("Frame")
    Look.Listen(listener, "CVAR_UPDATE")
    listener:SetScript("OnEvent", GameChanged)
end

-- EraUI's own write; the echo it causes is ignored until the next frame.
local function WriteGame(value)
    if not (C_CVar and C_CVar.SetCVar) or type(ns.SetCVar) ~= "function" then return end
    fade.writing = true
    Look.Try(ns.SetCVar, "mapFade", value)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() fade.writing = false end)
    else
        fade.writing = false
    end
end

local function FadeOn()
    fade.on = true
    FollowGame()
    WriteGame("1")
end

local function FadeOff()
    fade.on = false
    FollowGame()
    WriteGame("0")
end

ns.RegisterModule("mapFade", { apply = FadeOn, restore = FadeOff })
