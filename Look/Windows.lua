-- How EraUI's own windows (the quest log, the spellbook, the talents) share
-- the screen, the way the 1.x panels did: each opens at the top left, 104
-- below the top, one at a time, except that the windows that share (the
-- spellbook and the talents) stand side by side; they start right of the
-- character window when it is open; opening one closes the game's open
-- panels (out of a fight), and opening a game panel, an NPC window or the
-- world map closes them.
--
-- A window tells the manager about itself through Look.WindowTraits
-- (Look/Base.lua): width (its slot, 352 unless given), hold() (an x it must
-- keep for now), keep() (a frame it starts right of and leaves open),
-- placed(x, y) (after the manager moved it). The game's windows are watched,
-- never hooked: a hook on the game's panel calls would run inside every
-- window the client opens, in the client's own pass.
local _, EraUI = ...
local ns, Look = EraUI.Classic, EraUI.Look

local SLOT, DOWN, BESIDE_CHARACTER = 352, -104, 352
local NPC_WINDOWS = Look.Words([[GossipFrame QuestFrame MerchantFrame MailFrame BankFrame ClassTrainerFrame
    AuctionHouseFrame AuctionFrame TradeFrame TaxiFrame FlightMapFrame PetStableFrame StableFrame ItemTextFrame
    TabardFrame GuildRegistrarFrame PetitionFrame CraftFrame TradeSkillFrame ProfessionsFrame BarberShopFrame
    GuildBankFrame InspectFrame LootFrame]])

local W = { windows = {}, known = Look.Weak(), shares = Look.Weak(), shownAt = Look.Weak(), placedX = Look.Weak(),
    opened = 0, names = {}, lastShown = {}, npc = {} }
Look.Windows = W
for _, name in ipairs(NPC_WINDOWS) do W.npc[name] = true end

-- A window's answer to one of its questions (or nil).
local function Asked(window, question)
    local ask = Look.WindowTrait(window, question)
    if type(ask) ~= "function" then return nil end
    local fine, answer = Look.Try(ask, window)
    if fine then return answer end
    return nil
end

local function Width(window)
    return Look.Number(Look.WindowTrait(window, "width")) or SLOT
end

-- Shown, asked carefully (a forbidden frame may refuse).
local function Showing(frame)
    if type(frame) ~= "table" or type(frame.IsShown) ~= "function" then return false end
    local fine, shown = pcall(frame.IsShown, frame)
    return fine and shown == true
end

---------------------------------------------------------------------------
-- Placing
---------------------------------------------------------------------------

-- The first free x for a slot of this width at or right of x: past every
-- held window it would overlap.
local function PastHeld(x, width, held)
    local moved = true
    while moved do
        moved = false
        for other, at in pairs(held) do
            local otherWidth = Width(other)
            if x < at + otherWidth and at < x + width then
                x = at + otherWidth
                moved = true
            end
        end
    end
    return x
end

-- The open windows, oldest open first. Held ones keep their x; the others
-- stand in the room around them, left to right, from the left edge (or
-- right of the character window), each right of the frame it keeps open.
function W.Place()
    local open = {}
    for _, window in ipairs(W.windows) do
        if window:IsShown() then open[#open + 1] = window end
    end
    table.sort(open, function(a, b) return (W.shownAt[a] or 0) < (W.shownAt[b] or 0) end)
    local held = {}
    for _, window in ipairs(open) do
        local x = Look.Number(Asked(window, "hold"))
        if x then held[window] = x end
    end
    local cursor = 0
    local character = _G.CharacterFrame
    if Showing(character) then
        local left = Look.Rect(character)
        if left then cursor = math.floor(left + BESIDE_CHARACTER + 0.5) end
    end
    for _, window in ipairs(open) do
        local width, x = Width(window), held[window]
        if not x then
            local keep = Asked(window, "keep")
            if Showing(keep) then
                local _, _, right = Look.Rect(keep)
                if right then cursor = math.max(cursor, math.floor(right + 0.5)) end
            end
            x = PastHeld(cursor, width, held)
            if x ~= W.placedX[window] then
                W.placedX[window] = x
                Look.Pin(window, "TOPLEFT", UIParent, "TOPLEFT", x, DOWN)
                local placed = Look.WindowTrait(window, "placed")
                if type(placed) == "function" then Look.Try(placed, x, DOWN) end
            end
        end
        cursor = math.max(cursor, x + width)
    end
end

-- The x the manager last placed a window at (nil before it ever did).
function W.PlacedX(window)
    return W.placedX[window]
end

function W.HideAll()
    for _, window in ipairs(W.windows) do
        if window:IsShown() then window:Hide() end
    end
end

---------------------------------------------------------------------------
-- One of EraUI's windows opening
---------------------------------------------------------------------------

-- Out of a fight only: every open game panel closed through the game's own
-- panel manager, the world map too, but never the window's keep frame,
-- the game's talents and spellbook (closing it clears the bars' empty-slot
-- note, which the client then stops acting on), the character window (it
-- stands beside), nor the guild window while it is hidden for notes.
local function CloseGamePanels(window)
    if type(HideUIPanel) ~= "function" then return end
    local keep = Asked(window, "keep")
    local function Spared(frame)
        return frame == keep or frame == _G.PlayerSpellsFrame or frame == _G.CharacterFrame
            or (frame == _G.CommunitiesFrame and ns.guildGhost)
    end
    local open = {}
    if type(UIPanelWindows) == "table" then
        for name in pairs(UIPanelWindows) do
            local frame = type(name) == "string" and _G[name]
            if Showing(frame) and not Spared(frame) then open[#open + 1] = frame end
        end
    end
    local map = _G.WorldMapFrame
    if Showing(map) and not Spared(map) then open[#open + 1] = map end
    for _, frame in ipairs(open) do Look.Try(HideUIPanel, frame) end
end

local function Opened(window)
    W.opened = W.opened + 1
    W.shownAt[window] = W.opened
    for _, other in ipairs(W.windows) do
        if other ~= window and other:IsShown() and not (W.shares[window] and W.shares[other]) then other:Hide() end
    end
    if not Look.InFight() then CloseGamePanels(window) end
    W.Place()
end

---------------------------------------------------------------------------
-- Watching the game's windows (every 0.1 s; the names again every 5 s and
-- whenever an addon loads, so a window's first open is never missed)
---------------------------------------------------------------------------

local function GameShowing(name)
    if name == "CommunitiesFrame" and ns.guildGhost then return false end
    return Showing(_G[name])
end

-- A name new to the list starts from what it shows now, so a window
-- already open when the watch starts closes nothing.
function W.Names()
    local list, seen = {}, {}
    local function Add(name)
        if type(name) ~= "string" or seen[name] then return end
        seen[name] = true
        list[#list + 1] = name
        if W.lastShown[name] == nil then W.lastShown[name] = GameShowing(name) end
    end
    if type(UIPanelWindows) == "table" then
        for name in pairs(UIPanelWindows) do Add(name) end
    end
    Add("WorldMapFrame")
    for _, name in ipairs(NPC_WINDOWS) do Add(name) end
    W.names = list
end

local function Appeared(name)
    if name == "PlayerSpellsFrame" then return end
    if name == "CharacterFrame" and not Look.InFight() then
        W.Place()
    else
        W.HideAll()
    end
    if W.npc[name] then
        local friends = _G.FriendsFrame
        if friends ~= _G[name] and Showing(friends) then Look.HidePanel(friends) end
    end
end

function W.Scan()
    for _, name in ipairs(W.names) do
        local now = GameShowing(name)
        if now ~= W.lastShown[name] then
            W.lastShown[name] = now
            if now then
                Appeared(name)
            elseif name == "CharacterFrame" then
                W.Place()
            end
        end
    end
end

local function StartWatch()
    if W.watching then return end
    W.watching = true
    W.Names()
    Look.Every(0.1, W.Scan)
    Look.Every(5, W.Names)
    local loads = Look.Build("Frame", nil, nil, { size = { 1, 1 } })
    Look.Listen(loads, "ADDON_LOADED")
    loads:SetScript("OnEvent", W.Names)
end

-- Once per window. shares: it may stand beside the other sharing windows.
function ns.RegisterClassicWindow(window, shares)
    if not window or W.known[window] then return end
    W.known[window] = true
    W.windows[#W.windows + 1] = window
    W.shares[window] = shares and true or false
    Look.HookScript(window, "OnShow", function() Look.Try(Opened, window) end, "windows")
    Look.HookScript(window, "OnHide", function() Look.Try(W.Place) end, "windows")
    StartWatch()
end
