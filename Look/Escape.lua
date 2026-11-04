-- Escape closes EraUI's own windows the way it closes the game's: through
-- the game's own list of windows it hides (UISpecialFrames), never by
-- changing a key binding (a binding changed from addon code had the game
-- rebuild the action bars inside EraUI's code, which then broke on hidden
-- health values, 2026-10-06). The game reads that list inside a protected
-- call, so the entries stay out of the rest of its Escape handling.
--
-- A named window that just hides goes on the list under its own name. A
-- window that closes its own way (the quest log, the spellbook) or has no
-- name (a drop down's list) is listed through a stand-in: a tiny frame of
-- EraUI's, in nothing (so hiding the interface never hides it), shown while
-- its window is open and Escape may close it. When the game hides the
-- stand-in, the window is closed its own way. Needs nothing but the game's
-- API, so a test can load it on its own.
local _, EraUI = ...
local ns = EraUI.Classic

local done = setmetatable({}, { __mode = "k" }) -- window: true, or its stand-in's record
local records = {}
local made = 0
local starting = false -- a fight starting: lockdown follows the event
local listener

local function List(name)
    table.insert(UISpecialFrames, name)
end

local function Listed(name)
    for _, listed in pairs(UISpecialFrames) do
        if listed == name then return true end
    end
    return false
end

local function Fighting()
    return starting or (type(InCombatLockdown) == "function" and InCombatLockdown() and true or false)
end

-- Escape may close the window now: it is open and, in a fight, not held
-- open (the spellbook while its secure layer holds it).
local function Closable(record)
    if not record.window:IsShown() then return false end
    if record.held and Fighting() then
        local fine, holding = pcall(record.held, record.window)
        if fine and holding then return false end
    end
    return true
end

-- The stand-in shown or hidden to match; doing so is never an Escape.
local function Follow(record)
    local wanted = Closable(record)
    if (record.standIn:IsShown() and true or false) == wanted then return end
    record.quiet = true
    if wanted then record.standIn:Show() else record.standIn:Hide() end
    record.quiet = false
end

-- The game hid the stand-in (Escape, or the game closing every listed
-- window): the window, if still open, closed its own way. A closer that
-- keeps it open spends that Escape; the stand-in stays down until the
-- window shows again or the fight ends.
local function Escaped(record)
    if record.quiet or not record.window:IsShown() then return end
    if record.closer then record.closer(record.window) else record.window:Hide() end
end

local function Listen(held)
    if not listener then
        listener = CreateFrame("Frame")
        listener:RegisterEvent("PLAYER_REGEN_ENABLED")
        listener:SetScript("OnEvent", function(_, event)
            starting = event == "PLAYER_REGEN_DISABLED"
            for _, record in ipairs(records) do Follow(record) end
        end)
    end
    if held then listener:RegisterEvent("PLAYER_REGEN_DISABLED") end
end

local function StandIn(window, closer, held)
    made = made + 1
    local name = "EraUIClassicEscape" .. made
    local standIn = CreateFrame("Frame", name)
    standIn:SetSize(1, 1)
    standIn:SetPoint("TOPLEFT")
    standIn:Hide()
    local record = { window = window, closer = closer, held = held, standIn = standIn }
    record.follow = function() Follow(record) end
    standIn:SetScript("OnHide", function() Escaped(record) end)
    window:HookScript("OnShow", record.follow)
    window:HookScript("OnHide", record.follow)
    records[#records + 1] = record
    Listen(held)
    List(name)
    Follow(record)
    return record
end

-- Once per window. Returns, for a window listed through a stand-in, a
-- function that looks again when held changes with no show or hide (a
-- secure click in a fight).
function ns.CloseOnEscape(window, closer, held)
    if not window or type(UISpecialFrames) ~= "table" then return nil end
    local known = done[window]
    if known ~= nil then return known ~= true and known.follow or nil end
    local name = window.GetName and window:GetName()
    if type(name) == "string" and name ~= "" and not closer then
        done[window] = true
        if not Listed(name) then List(name) end
        return nil
    end
    local record = StandIn(window, closer, held)
    done[window] = record
    return record.follow
end
