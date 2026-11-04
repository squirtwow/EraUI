-- The bag windows' registry entries, in this order after the window chrome's:
--   * "oneBag": the Classic setting follows the game's own Combine Bags
--     (the combinedBags CVar) on every pass, however it was changed. Its
--     apply and restore are the same read. Writing it is the engine's (the
--     option list and the Edit Mode bag panel set oneBag, then the engine's
--     ToggleChanged writes the CVar through its guarded writer, never in a
--     fight);
--   * "bags" (from /era's Bags & Bank, a reload setting): the bag windows in
--     the 1.x bag art while on. Off, the hooks stand still and the art stays
--     until the reload the option asks for.
-- Passes never run in a fight; the hooks may (see Look/BagWindows.lua).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local B = Look.Bags

-- The Classic settings this area reads, with their defaults (only where the
-- engine has none of its own).
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine then
        for key, value in pairs({ bags = true, oneBag = false, oneBagColumns = 8 }) do
            if engine[key] == nil then engine[key] = value end
        end
    end
end

local function ReadCombineBags()
    local saved, cvars = ns.db, C_CVar
    if not saved or type(cvars) ~= "table" or type(cvars.GetCVar) ~= "function" then return end
    local fine, value = pcall(cvars.GetCVar, "combinedBags")
    if not fine or value == nil or Look.Secret(value) then return end
    saved.oneBag = tostring(value) == "1"
end

local function BagsOn()
    B.active, B.applied = true, true
    for _, window in ipairs(B.Windows()) do
        B.Watch(window)
        if window:IsShown() then Look.Try(B.Dress, window) end
    end
end

-- Runs on every pass while Bags & Bank is off (cheap to repeat). The reload
-- note is asked for only when the art went on this session.
local function BagsOff()
    B.active = false
    if B.applied then ns.needsReload = true end
end

ns.RegisterModule("oneBag", { apply = ReadCombineBags, restore = ReadCombineBags })
ns.RegisterModule("bags", { apply = BagsOn, restore = BagsOff })

-- The One Bag window's slots across: rounded, kept within the limits and
-- saved; an open One Bag window follows at once (a closed one when it next
-- opens). The mirror is saved by the next pass or at logout. Returns the
-- number kept.
function ns.SetOneBagColumns(columns)
    local wanted = B.Columns(columns)
    local saved = ns.db
    if not saved then return wanted end
    saved.oneBagColumns = wanted
    local window = ContainerFrameCombinedBags
    if B.active and window and window:IsShown() then Look.Try(B.Dress, window) end
    return wanted
end
