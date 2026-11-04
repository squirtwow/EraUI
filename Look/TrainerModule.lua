-- The classic trainer's registry entry ("trainer", from /era's Trainer, a
-- reload setting) and its timing: post-hooks on the game's trainer code
-- (each queues one refresh on the next frame; the window opening refreshes
-- at once, before it is first drawn), the trainer's events, and the
-- refresh itself. Never in a fight: no refresh, collect or re-route then
-- (the panel stays up, so the game's faded shell never shows). No polling:
-- only Train's cosmetic glow looks at the cursor. Off really gives the
-- game's trainer back (out of a fight).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local R = Look.Trainer

do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine and engine.trainer == nil then engine.trainer = true end
end

local EVENTS = Look.Words([[ADDON_LOADED TRAINER_SHOW TRAINER_CLOSED TRAINER_UPDATE TRAINER_DESCRIPTION_UPDATE
    UNIT_PET_TRAINING_POINTS PLAYER_MONEY PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED]])

local function Window()
    return ClassTrainerFrame
end

-- The last ten events, with the service count at each (diagnostics).
local function Log(event)
    local count = type(GetNumTrainerServices) == "function" and Look.Number(GetNumTrainerServices()) or 0
    table.insert(R.log, 1, event .. " (" .. count .. ")")
    R.log[11] = nil
end

---------------------------------------------------------------------------
-- The refresh and its queue
---------------------------------------------------------------------------

function R.Refresh()
    local window = Window()
    if not R.active or R.refreshing or Look.InFight() or not (window and window:IsShown()) then return end
    R.refreshing = true
    Look.Try(function()
        R.Build()
        R.ShowPanel()
        R.counts = { before = type(GetNumTrainerServices) == "function" and GetNumTrainerServices() or 0 }
        R.Layout()
        R.counts.laid = type(GetNumTrainerServices) == "function" and GetNumTrainerServices() or 0
        R.Collect()
        R.DrawGreeting()
        Look.ScrollRange(R.shell.bar, math.max(0, #R.lines - R.ROWS))
        R.DrawRows()
        R.DrawDetail()
    end)
    R.refreshing = false
end

local booked = false
local function Booked()
    booked = false
    local window = Window()
    if R.active and not Look.InFight() and window and window:IsShown() then R.Refresh() end
end

-- One refresh on the next frame. Out of a fight the rows lose their routes
-- at once first: the game may recycle its rows before then.
function R.Queue()
    if not R.active or R.refreshing then return end
    if not Look.InFight() and R.routesValid and R.shell then
        for _, row in ipairs(R.shell.rows) do R.Disarm(row) end
        R.routesValid = false
    end
    if booked then return end
    booked = true
    if C_Timer and C_Timer.After then C_Timer.After(0, Booked) else Booked() end
end

---------------------------------------------------------------------------
-- Hooks (once, as soon as the game's trainer code is there)
---------------------------------------------------------------------------

local GAME = Look.Words([[ClassTrainerFrame_InitServiceButton ClassTrainerFrame_InitCategoryButton
    ClassTrainerFrame_Update ClassTrainer_SetSelection ClassTrainerFrame_UpdateTrainingPoints]])

local hooked = false
local function Hook()
    local window = Window()
    if hooked or not window or type(ClassTrainerFrame_InitServiceButton) ~= "function" then return end
    hooked = true
    for _, name in ipairs(GAME) do Look.HookGlobal(name, function() R.Queue() end) end
    Look.HookScript(window, "OnShow", function()
        if R.active and not Look.InFight() then R.Refresh() end
    end, "trainer")
    Look.HookScript(window, "OnHide", function() Log("hidden") end, "trainer")
    R.WatchTrain()
end

local listener = CreateFrame("Frame")
listener:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon ~= "Blizzard_TrainerUI" then return end
    -- A fight starting: Train's glow out at once (no purchase look in a fight).
    if event == "PLAYER_REGEN_DISABLED" then return Look.Shown(R.trainGlow, false) end
    Log(event)
    if event == "TRAINER_CLOSED" then return end
    Hook()
    R.Queue()
end)

---------------------------------------------------------------------------
-- On and off
---------------------------------------------------------------------------

local function TrainerOn()
    R.active = true
    for _, event in ipairs(EVENTS) do
        if event == "UNIT_PET_TRAINING_POINTS" then Look.Listen(listener, event, "player") else Look.Listen(listener, event) end
    end
    Hook()
    if Window() and not Look.InFight() then
        R.Build()
        R.Refresh()
    end
end

-- Out of a fight only: the panel down, every route gone, the game's list
-- and pieces as they were (remembered afresh by a later look).
local function TrainerOff()
    if Look.InFight() then return end
    R.active = false
    listener:UnregisterAllEvents()
    if R.panel then R.panel:Hide() end
    if R.shell then
        for _, row in ipairs(R.shell.rows) do R.Disarm(row) end
    end
    R.routesValid = false
    R.GiveBack()
end

ns.RegisterModule("trainer", { apply = TrainerOn, restore = TrainerOff })

---------------------------------------------------------------------------
-- Diagnostics (read only: no filter is touched, nothing asked to refresh)
---------------------------------------------------------------------------

function ns.TrainerDiagnostics()
    local window = Window()
    local lines = {}
    local function Add(text) lines[#lines + 1] = text end
    Add(string.format("on %s; refreshing %s; queued %s", tostring(R.active), tostring(R.refreshing), tostring(booked)))
    Add(string.format("window %s; panel %s; in a fight %s", tostring(window and window:IsShown()),
        tostring(R.panel and R.panel:IsShown()), tostring(Look.InFight())))
    local count = type(GetNumTrainerServices) == "function" and GetNumTrainerServices() or 0
    Add(string.format("services %s, named %s, lines drawn %s", tostring(count), tostring(R.named), tostring(R.lines and #R.lines)))
    for index = 1, math.min(3, Look.Number(count) or 0) do
        local name, kind = GetTrainerServiceInfo(index)
        Add(string.format("  %d: %s (%s)", index, tostring(name), tostring(kind)))
    end
    for _, kind in ipairs({ "available", "unavailable", "used" }) do
        Add(kind .. " filter " .. tostring(GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter(kind)))
    end
    local counts = R.counts or {}
    Add(string.format("last refresh: before %s, after layout %s", tostring(counts.before), tostring(counts.laid)))
    local list = window and window.ScrollBox
    if list then
        local frames = 0
        if type(list.ForEachFrame) == "function" then list:ForEachFrame(function() frames = frames + 1 end) end
        Add(string.format("game rows %d; list height %s, scale %s", frames, tostring(list:GetHeight()), tostring(list:GetScale())))
    end
    Add("selected " .. tostring(R.Selected and R.Selected()))
    for _, event in ipairs(R.log) do Add("event " .. event) end
    return lines
end
