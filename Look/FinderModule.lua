-- The group finder's registry entry ("groupFinder", from /era's Group
-- Finder & PvP, a reload setting): LFGParentFrame cut to the social
-- window's size and spot and dressed (Look/FinderDress.lua) at once, when
-- the game's finder addon loads, and every 0.1 s while it shows. Every step
-- is its own protected call, so one missing piece never stops the rest. The
-- window's size and the game's window layout width change only out of a
-- fight. Turning it off asks for a reload (nothing is undone in a session).
-- Public: ns.WarmGroupFinder() (the Who page's side tabs).
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local F = S.finder

local FINDER_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local dressed = Look.Weak() -- the Browse and Listing pages, dressed once

-- The social window's size, rounded; 360 x 424 while it isn't laid out.
function F.Size()
    local window = FriendsFrame
    local wide = Look.Number(window and window:GetWidth()) or 0
    local tall = Look.Number(window and window:GetHeight()) or 0
    if wide < 300 then return 360, 424 end
    return math.floor(wide + 0.5), math.floor(tall + 0.5)
end

local function Resize(finder, wide, tall)
    if Look.InFight() then return end
    local w, h = Look.Number(finder:GetWidth()) or 0, Look.Number(finder:GetHeight()) or 0
    if math.abs(w - wide) > 0.5 or math.abs(h - tall) > 0.5 then finder:SetSize(wide, tall) end
    if not finder:GetAttribute("UIPanelLayout-defined") then return end
    if Look.Number(finder:GetAttribute("UIPanelLayout-width")) == wide then return end
    finder:SetAttribute("UIPanelLayout-width", wide)
    if finder:IsShown() then S.Call(UpdateUIPanelPositions, finder) end
end

local function DressOnce(page, dress, wide)
    if not page or dressed[page] then return end
    dressed[page] = true
    Look.Try(dress, page, wide)
end

function F.Fit()
    local finder = LFGParentFrame
    if not F.active or not finder then return end
    local wide, tall = F.Size()
    Look.Try(Resize, finder, wide, tall)
    DressOnce(LFGBrowseFrame, F.DressBrowse, wide)
    DressOnce(LFGListingFrame, F.DressListing, wide)
    Look.Try(F.BuildTabs, finder)
    Look.Try(F.HideGameTabs, finder)
    Look.Try(F.SyncTabs)
    if LFGListingFrame then
        Look.Try(F.FitCategoryBars, LFGListingFrame, wide)
        Look.Try(F.FitPlayStyle, LFGListingFrame)
    end
    if LFGBrowseFrame then Look.Try(F.DressRows, LFGBrowseFrame) end
end

-- The game's finder loaded (out of a fight) and fitted.
function ns.WarmGroupFinder()
    if not F.active or Look.InFight() then return end
    local addons = C_AddOns
    if addons and not S.Yes(addons.IsAddOnLoaded, FINDER_ADDON) then S.Call(addons.LoadAddOn, FINDER_ADDON) end
    Look.Try(F.Fit)
end

local function Watch()
    if F.watching then return end
    F.watching = true
    local loads = CreateFrame("Frame")
    Look.Listen(loads, "ADDON_LOADED")
    loads:SetScript("OnEvent", function(_, _, addon)
        if addon == FINDER_ADDON then Look.Try(F.Fit) end
    end)
    Look.Every(0.1, function()
        local finder = LFGParentFrame
        if F.active and finder and finder:IsShown() then F.Fit() end
    end)
end

local function FinderOn()
    F.active = true
    Watch()
    Look.Try(F.Fit)
end

local function FinderOff()
    F.active = false
    ns.needsReload = true
end

ns.RegisterModule("groupFinder", { apply = FinderOn, restore = FinderOff })
