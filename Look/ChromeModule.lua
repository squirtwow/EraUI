-- The window chrome's registry entry ("panels", on unless the Classic option
-- says otherwise) and its list of the game's windows. Each pass while on
-- dresses every listed window that exists and isn't dressed yet; a window
-- that arrives with its own Blizzard addon later is dressed when that addon
-- loads. Each window is dressed once a session (the world map's border again
-- when the map changes size). Restore, on every pass while off, only hides
-- the title strips and asks for a reload when something was dressed: the
-- rest of the art stays until then.
--
-- Its place in the .toc keeps the registry order: after the quest map pane,
-- before the bank (whose dressing, ns.SkinBank, expects the chrome on
-- first), the social windows, bags, the character sheet, the spell windows
-- and talents.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local C = Look.Chrome
local X = C.extras

-- The windows: global name (or a function finding the frame), options.
local LIFTED = { lift = 5 }
C.WINDOWS = {
    { function() return WorldMapFrame and WorldMapFrame.BorderFrame end, { noRing = true, noStone = true, lift = 5, extras = X.WorldMap } },
    { "MerchantFrame", { lift = 5, extras = X.Merchant } },
    { "MailFrame", LIFTED },
    { "FriendsFrame", { lift = 5, tabLift = 3, extras = X.Friends } },
    { "QuestFrame", { lift = 5, stoneRight = 5, extras = X.Quest } },
    { "GossipFrame", { lift = 5, stoneRight = 5, extras = X.Gossip } },
    { "TradeFrame", { lift = 5, extras = X.Trade } },
    { "TaxiFrame", {} }, { "DressUpFrame", {} }, { "PetStableFrame", {} }, { "TabardFrame", {} },
    { "GuildRegistrarFrame", {} }, { "PetitionFrame", {} },
    { "ItemTextFrame", { extras = X.ItemText } },
    { "GuildControlUI", { noRing = true, extras = X.GuildControl } },
    { "BankFrame", { extras = X.Bank } },
    { "LootFrame", { noStone = true, extras = X.Loot } },
    { "LFGListingFrame", { lift = 5, extras = X.Listing } },
    { "LFGBrowseFrame", LIFTED }, { "LFGWhoListFrame", LIFTED },
    { "InspectFrame", { stoneBottom = 4, extras = X.Inspect } },
    { "MacroFrame", { topTabs = true, lift = 2, extras = X.Macro } },
    { "ClassTrainerFrame", {} },
    { "AuctionHouseFrame", { lift = 9, stoneRight = 6, stoneBottom = 8 } },
    { "CommunitiesFrame", {} },
    { "CollectionsJournal", { extras = X.Collections } },
    { "EncounterJournal", {} }, { "AchievementFrame", {} },
    -- ProfessionsFrameInset is the inset of the crafting page's search pop-up,
    -- not the window's: a floor on it pokes out above the window.
    { "ProfessionsFrame", { stoneBottom = 4, noFloor = true } },
    { "ProfessionsBookFrame", {} }, { "GuildBankFrame", {} },
    { "CalendarFrame", { noRing = true } },
    { "ItemSocketingFrame", {} },
    { "AddonList", { noRing = true } },
}

local function Find(entry)
    local where = entry[1]
    if type(where) == "function" then
        local fine, frame = pcall(where)
        return fine and frame or nil
    end
    return _G[where]
end

-- Every listed window that exists and isn't dressed yet (a refused one is
-- tried again next time).
function C.DressAll()
    if not C.applied then return end
    for _, entry in ipairs(C.WINDOWS) do
        local window = Find(entry)
        if type(window) == "table" and not C.dressed[window] then Look.Try(C.Dress, window, entry[2]) end
    end
end

local loads
local function WatchLoads()
    if loads then return end
    loads = Look.Build("Frame", UIParent, nil, { size = { 1, 1 } })
    loads:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    Look.Listen(loads, "ADDON_LOADED")
    loads:SetScript("OnEvent", function()
        if C.applied then C.DressAll() end
    end)
end

local function PanelsOn()
    C.applied = true
    WatchLoads()
    C.DressAll()
end

-- Every pass while off: cheap, safe to repeat.
local function PanelsOff()
    C.applied = false
    local any = false
    for window in pairs(C.dressed) do
        any = true
        local strip = C.Found(window, "titleStrip")
        if strip then strip:Hide() end
    end
    if any then ns.needsReload = true end
end

ns.RegisterModule("panels", { apply = PanelsOn, restore = PanelsOff })
