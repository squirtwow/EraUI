-- The Who page's registry entry ("whoList", from /era's Friends & Guild, a
-- reload setting). Each pass: the page built once, the Who tab shown, the
-- game's Friends tab renamed "Friends", the tab row laid, and the hooks put
-- in once (the friends key's way back too, again whenever an addon loads,
-- for the game's newer social window loading later). The restore runs on
-- every pass while off and touches nothing of the game's when the page was
-- never on.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local W = S.who

-- The page kept up when the game redraws its window under it.
local function KeepUp()
    local page = W.parts.page
    if not (W.active and page and page:IsShown()) then return end
    W.HideGamePages()
    S.ChooseTab(S.whoTab)
    W.Title()
end

local function WhoTabClicked()
    S.Sound("IG_CHARACTER_INFO_TAB")
    W.Show()
end

local function Hooks()
    if W.hooked then return end
    W.hooked = true
    local classic = FriendsFrame
    Look.HookScript(classic, "OnShow", function() if W.active then ns.PlaceSocialTabs() end end, "who")
    Look.HookScript(classic, "OnHide", function() W.Hide() end, "who")
    S.After("FriendsFrame_ShowSubFrame", KeepUp)
    S.After("FriendsFrame_Update", KeepUp)
    S.HookGameTabs()
    S.WatchTabResize()
    local loads = CreateFrame("Frame")
    Look.Listen(loads, "ADDON_LOADED")
    loads:SetScript("OnEvent", function() if W.active then Look.Try(S.HookRedirect) end end)
end

local function WhoOn()
    if not FriendsFrame then
        Look.MissingPiece("FriendsFrame")
        return
    end
    W.active = true
    W.Build()
    if not S.whoTab then
        S.whoTab = S.MakeTab("EraUIClassicWhoTab", 91, S.Say("WHO", "Who"), WhoTabClicked)
    end
    Look.Shown(S.whoTab, true)
    Hooks()
    S.HookRedirect()
    local friendsTab = _G.FriendsFrameTab1
    if friendsTab then
        friendsTab:SetText(S.Say("FRIENDS", "Friends"))
        S.FitTab(friendsTab)
    end
    ns.PlaceSocialTabs()
    W.applied = true
end

local function WhoOff()
    W.active = false
    if not W.applied then return end
    W.Hide()
    Look.Shown(S.whoTab, false)
    local friendsTab = _G.FriendsFrameTab1
    if friendsTab then friendsTab:SetText(S.Say("CONTACTS_TAB_TITLE", S.Say("FRIENDS", "Friends"))) end
    ns.PlaceSocialTabs()
end

ns.RegisterModule("whoList", { apply = WhoOn, restore = WhoOff })
