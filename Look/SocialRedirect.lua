-- The friends key's way back to the classic social window (Classic look,
-- spec 10 section 6). On Forever, with the game's newer social window
-- switched on (C_SocialUI.IsSystemEnabled()), every way into the friends
-- list opens that newer window instead. While Friends & Guild is on, these
-- open the classic window on its Friends list instead, and the same key
-- closes it: the friends key, /friends, /ignore, the chat friends button, a
-- friend-request toast. Raid, Quick Join and Recruit A Friend stay in the
-- newer window.
-- How: post-hooks only. By the time one runs, the game has opened its newer
-- window; EraUI closes it through the game's own panel manager and opens
-- the classic one the same way. In a fight nothing is shown or hidden: the
-- request is booked and done after the fight, if the newer window is still
-- on the same page. Nothing of the game's is replaced, clicked or written
-- (the classic ignore list, a plain display child, is the one piece EraUI
-- shows itself), and no key binding is changed.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local W = S.who

local R = { closedAt = -1, ignoreClosedAt = -1, toggleClosedAt = -1 }
S.redirect = R

function S.RedirectActive()
    if not W.active or not FriendsFrame or not SocialUIFrame or not Look.Enabled() then return false end
    local api = C_SocialUI
    return S.Yes(type(api) == "table" and api.IsSystemEnabled or nil)
end

local function NewPage()
    local fine, page = Look.Ask(SocialUIFrame, "GetSelectedTab")
    if not fine or Look.Secret(page) then return nil end
    return page
end

local function FriendsPage(page)
    local kinds = SocialUITabType
    return page ~= nil and type(kinds) == "table" and (page == kinds.Friends or page == kinds.FriendRequests)
end

local function IgnoreAsked()
    local fine, side = Look.Ask(SocialUIFrame, "GetActiveSideWindowType")
    local kinds = SocialUISideWindowType
    return fine and side ~= nil and not Look.Secret(side) and type(kinds) == "table" and side == kinds.IgnoreListFrame
end

-- The classic window up (on its Friends list unless it's an /ignore).
local function ShowClassic(ignore)
    local classic = FriendsFrame
    if classic:IsShown() then
        if not ignore then
            W.Hide()
            if type(ns.HideGuildRoster) == "function" then Look.Try(ns.HideGuildRoster) end
            local friendsTab = _G.FriendsFrameTab1
            if friendsTab and type(PanelTemplates_SelectTab) == "function" then
                Look.Try(PanelTemplates_SelectTab, friendsTab)
                S.FitTab(friendsTab)
            end
        end
    elseif not Look.ShowPanel(classic) then
        return
    end
    local list = ignore and classic.IgnoreListWindow
    if list and not list:IsShown() then list:Show() end
end

-- mode "toggle" or "open"; anyPage: the request was for the friends list,
-- whatever page the newer window remembered.
local function Redirect(mode, anyPage)
    if not S.RedirectActive() then return end
    local new, classic, now = SocialUIFrame, FriendsFrame, S.Now()
    if not new:IsShown() then
        -- A hook further in already dealt with it; an open whose toggle
        -- closed the classic window this very frame opens it again.
        if mode == "open" and R.toggleClosedAt == now and not Look.InFight() then ShowClassic(false) end
        return
    end
    local page = NewPage()
    if not anyPage and not FriendsPage(page) then return end
    if Look.InFight() then
        R.booked = { page = page }
        return
    end
    R.booked = nil
    local ignore = IgnoreAsked()
    local wasOpen = classic:IsShown() or R.closedAt == now
    Look.HidePanel(new)
    if mode == "toggle" and wasOpen then
        local list = classic.IgnoreListWindow
        local listUp = list ~= nil and (list:IsShown() or (not classic:IsShown() and R.ignoreClosedAt == now))
        if ignore and not listUp then
            ShowClassic(true)
            return
        end
        Look.HidePanel(classic)
        R.closedAt, R.toggleClosedAt = now, now
        return
    end
    ShowClassic(ignore)
end
R.Redirect = Redirect

-- While the newer window is on, the game hides the classic Friends tab
-- (with Raid and Quick Join); EraUI keeps it, so Who and Guild lead back.
local function KeepFriendsTab()
    if not S.RedirectActive() then return end
    local friendsTab = _G.FriendsFrameTab1
    if friendsTab and not friendsTab:IsShown() then friendsTab:Show() end
end

local function FriendsTab(tab)
    return tab == nil or tab == (FRIEND_TAB_FRIENDS or 1)
end

-- The listeners, each made once here: S.After lists a listener only once,
-- by its identity, and S.HookRedirect runs on every pass and every addon
-- load, so a function made inside it would be listed again each time (and
-- run that many times on every friends key press).
local function ClassicHid() R.closedAt = S.Now() end
local function IgnoreListHid() R.ignoreClosedAt = S.Now() end
local function FriendsToggled(tab) if FriendsTab(tab) then Redirect("toggle", true) end end
local function AnyToggle() Redirect("toggle", true) end
local function FriendsOpened(tab) if FriendsTab(tab) then Redirect("open", true) end end
local function NewToggled() Redirect("toggle", false) end
local function NewOpened() Redirect("open", false) end
local function NewShown()
    if S.RedirectActive() then S.NextFrame(NewOpened) end
end

-- Installed once each; again on every addon load while on (the newer
-- window's addon may load later).
function S.HookRedirect()
    local classic = FriendsFrame
    if not classic then return end
    Look.HookScript(classic, "OnHide", ClassicHid, "socialRedirect")
    local list = classic.IgnoreListWindow
    if list then Look.HookScript(list, "OnHide", IgnoreListHid, "socialRedirect") end
    S.After("FriendsFrame_Update", KeepFriendsTab)
    S.After("ToggleFriendsFrame", FriendsToggled)
    S.After("ToggleFriendsPanel", AnyToggle)
    S.After("ToggleIgnorePanel", AnyToggle)
    S.After("OpenFriendsFrame", FriendsOpened)
    local control = SocialUIControl
    if type(control) == "table" then
        if type(control.Toggle) == "function" then Look.Hook(control, "Toggle", NewToggled) end
        if type(control.OpenToTab) == "function" then Look.Hook(control, "OpenToTab", NewOpened) end
    end
    if SocialUIFrame then Look.HookScript(SocialUIFrame, "OnShow", NewShown, "socialRedirect") end
end

-- After a fight: a booked request, if the newer window is still on the page
-- it was on, turns into the classic window.
do
    local fightEnds = CreateFrame("Frame")
    Look.Listen(fightEnds, "PLAYER_REGEN_ENABLED")
    fightEnds:SetScript("OnEvent", function()
        local booked = R.booked
        if not booked then return end
        R.booked = nil
        if not S.RedirectActive() or not SocialUIFrame:IsShown() then return end
        if NewPage() ~= booked.page then return end
        Look.Try(Redirect, "open", true)
    end)
end
