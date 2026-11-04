-- The Legacy window's registry entry ("legacyWindow", from /era's Legacy
-- Window, a reload setting, on unless chosen otherwise) and its watch:
--   * the game's Legacy window (Blizzard_LegacySystem) loads the first time
--     it is wanted (Y): it is dressed as its addon loads, again each time it
--     opens, and every 0.1 s while it shows new rows, cards, talents and
--     links are dressed and the page tabs follow;
--   * nothing of the game's is changed in a fight: a dressing a fight
--     stopped waits for its end (EraUI's own tabs, checks, bars, sockets
--     and links still follow the game's repaints, see L.AfterOwn);
--   * the window is made the 1.x spellbook's size and each page laid out
--     anew on it (the game sizes and anchors these once, so they hold; the
--     cards and talents it lays out again on every show are laid out again
--     after it, in a fight too);
--   * off, every piece of the game's EraUI changed goes back as it was (the
--     window's size and layout too) and EraUI's own art is hidden; the
--     shared 1.x skins (the red X, the arrows, the drop down, the scroll
--     bars, the red button) clear with a reload, which the reload note asks
--     for.
-- The look itself: Look/LegacyShell.lua (the frame and tabs),
-- LegacyRewards.lua, LegacyChallenges.lua (with LegacyChallengeData.lua,
-- LegacyChallengeList.lua and LegacyChallengeDetail.lua: the Challenges
-- page EraUI draws), LegacyTree.lua and LegacyEdges.lua (the pages), on
-- Look/LegacyKit.lua.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local L = Look.Legacy

-- The Classic setting this area reads, with its default (only where the
-- engine has none of its own), and its reload note.
do
    local engine = type(ns.DB_DEFAULTS) == "table" and ns.DB_DEFAULTS or nil
    if engine and engine.legacyWindow == nil then engine.legacyWindow = true end
    if type(ns.RELOAD_KEYS) == "table" then ns.RELOAD_KEYS.legacyWindow = true end
end

local function Window()
    local window = rawget(_G, "LegacySystemFrame")
    if type(window) ~= "table" then return nil end
    return window
end
L.Window = Window

local function Page(window, key)
    local page = L.Field(window, key)
    if page and L.IsShown(page) then return page end
    return nil
end

---------------------------------------------------------------------------
-- Dressing
---------------------------------------------------------------------------

local hooked = Look.Weak()

-- The window's own show (once): dressed again each time it opens, or
-- booked for a fight's end.
local function HookWindow(window)
    if hooked[window] then return end
    hooked[window] = true
    Look.HookScript(window, "OnShow", function()
        if not L.active then return end
        if Look.InFight() then
            L.booked = true
            return
        end
        Look.Try(L.Dress)
    end, "legacy")
end

-- The whole window (out of a fight; a fight books it for its end). True
-- when it was dressed.
function L.Dress()
    if not L.active then return false end
    if Look.InFight() then
        L.booked = true
        return false
    end
    local window = Window()
    if not window then return false end
    L.applied = true
    HookWindow(window)
    -- The frame first: it sets the window's size, which the pages lay out in.
    Look.Try(L.DressShell, window)
    Look.Try(L.DressRewards, L.Field(window, "RewardTrackPage"), window)
    Look.Try(L.DressChallenges, L.Field(window, "ChallengesPage"), window)
    Look.Try(L.DressTree, L.Field(window, "TreePage"), window)
    L.dressed = true
    return true
end

-- While the window shows: what the shown page has made since (the game's
-- own repaints are followed by post-hooks), the tree kept fitted, and the
-- tabs.
function L.Refresh(window)
    L.TabsFollow(window)
    local rewards = Page(window, "RewardTrackPage")
    if rewards then L.RewardCards(rewards, true) end
    local challenges = Page(window, "ChallengesPage")
    if challenges then L.ChallengeLists(challenges, true) end
    local tree = Page(window, "TreePage")
    if tree then
        local panel = L.Field(tree, "LegacyTreeTraitPanel")
        L.TreeTabs(L.Field(tree, "LegacyTreeSelectionPanel"), window)
        if panel then L.Refit(panel) end
        L.Nodes(panel, true)
    end
end

local function Step()
    if not L.On() then return end
    local window = Window()
    if not (window and L.IsShown(window)) then return end
    if not L.dressed then
        L.Dress()
        return
    end
    Look.Try(L.Refresh, window)
end

---------------------------------------------------------------------------
-- The watch, on and off
---------------------------------------------------------------------------

local function Watch()
    if L.watch then return end
    local watch = Look.Build("Frame", UIParent, nil, { size = { 1, 1 } })
    Look.Pin(watch, "TOPLEFT", UIParent, "TOPLEFT", 0, 0)
    Look.Listen(watch, "ADDON_LOADED")
    Look.Listen(watch, "PLAYER_REGEN_ENABLED")
    -- A fight's end: a dressing it stopped, or the open window painted again
    -- (the game's repaints in the fight were left alone).
    watch:SetScript("OnEvent", function(_, event, addon)
        if event == "ADDON_LOADED" and addon ~= L.ADDON then return end
        if event == "PLAYER_REGEN_ENABLED" then
            local window = Window()
            if not (L.booked or (window and L.IsShown(window))) then return end
            L.booked = false
        end
        if L.active then Look.Try(L.Dress) end
    end)
    Look.Every(0.1, Step)
    L.watch = watch
end

local function LegacyOn()
    L.active = true
    Watch()
    Look.Try(L.Dress)
end

-- Every pass while off: cheap, safe to repeat.
local function LegacyOff()
    L.active = false
    L.booked = false
    if not L.applied then return end
    ns.needsReload = true
    if L.RestoreAll() then
        L.applied, L.dressed = false, false
    end
end

ns.RegisterModule("legacyWindow", { apply = LegacyOn, restore = LegacyOff })
