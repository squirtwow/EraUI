-- The Guild page's ways in and out, and its registry entry ("guildRoster",
-- from /era's Friends & Guild, a reload setting):
--   * the Guild tab and ns.OpenGuildRoster() open the page; ns.HideGuildRoster()
--     closes it; the Communities tab and Guild Information open the game's
--     own guild window;
--   * the guild key and the guild micro button: both run the game's own
--     ToggleGuildFrame, which opens the game's guild window. EraUI post-hooks
--     it (never replaces it, never binds a key): the game's window closes
--     again at once and the social window toggles instead, on the Guild page
--     for the key, on its own page for the micro button (the 1.x Socials
--     button). In a fight nothing is shown or hidden: the game's guild window
--     stays, and turns into the Guild page after the fight;
--   * EraUIClassicGuildBind: a named click target (a /click macro) toggling
--     the Guild page.
-- A pass runs the apply again; the restore runs on every pass while off and
-- touches nothing of the game's when the page was never on.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local G = S.guild
local parts = G.parts

local function QuickBinding()
    return S.Yes(KeybindFrames_InQuickKeybindMode)
end

local function RefreshMicro()
    if type(ns.RefreshMicroButtons) == "function" then Look.Try(ns.RefreshMicroButtons) end
end

---------------------------------------------------------------------------
-- Showing and hiding the page
---------------------------------------------------------------------------

function G.Show()
    local page = parts.page
    if not page or not G.InGuild() then return end
    if type(ns.HideWhoList) == "function" then Look.Try(ns.HideWhoList) end
    S.HideGamePages("guild")
    local already = page:IsShown()
    page:Show()
    S.ChooseTab(S.guildTab)
    G.DressWindow()
    if already then G.Refresh() end
    G.TabState()
    RefreshMicro()
end

function G.Hide()
    local page = parts.page
    if not page then return end
    if G.menu then G.menu.Close() end
    if not page:IsShown() then
        S.notes.PutAway()
        return
    end
    page:Hide()
    G.HideMember()
    S.notes.PutAway()
    S.UnchooseTab(S.guildTab)
    G.UndressWindow()
    S.ShowGamePages("guild")
    G.TabState()
    RefreshMicro()
end

function G.PageShown()
    if C_GuildInfo then S.Call(C_GuildInfo.GuildRoster) end
    G.Refresh()
    if not G.active then return end
    S.HideGamePages("guild")
    S.ChooseTab(S.guildTab)
    G.DressWindow()
    RefreshMicro()
end

function G.PageHidden()
    G.HideMember()
end

ns.HideGuildRoster = function() G.Hide() end

-- The Guild page from anywhere: false while it's off; in a fight the game
-- may refuse the social window, and the page then opens when the fight ends.
function ns.OpenGuildRoster()
    if not G.active or not FriendsFrame then return false end
    G.Build()
    G.MakeTabs()
    if not Look.ShowPanel(FriendsFrame) then
        G.openAsked = true
        return false
    end
    G.Show()
    return true
end

---------------------------------------------------------------------------
-- The tabs
---------------------------------------------------------------------------

-- The game's own guild window (the Communities window), through the game's
-- own opener; EraUI's post-hook stands aside for it.
function G.GameGuildWindow()
    if type(ToggleGuildFrame) ~= "function" then return end
    G.passing = true
    Look.Try(ToggleGuildFrame)
    G.passing = false
end

local function CommunitiesClicked()
    if Look.InFight() then return S.NotInFight() end
    S.Sound("IG_CHARACTER_INFO_TAB")
    S.notes.PutAway()
    if parts.page and parts.page:IsShown() then G.Hide() end
    if CommunitiesFrame and CommunitiesFrame:IsShown() then return end
    Look.HidePanel(FriendsFrame)
    G.GameGuildWindow()
end

function G.GuildInformation()
    if Look.InFight() then return S.NotInFight() end
    S.notes.PutAway()
    G.GameGuildWindow()
end

function G.MakeTabs()
    if S.guildTab then return end
    S.guildTab = S.MakeTab("EraUIClassicGuildTab", 90, S.Say("GUILD", "Guild"), function()
        S.Sound("IG_CHARACTER_INFO_TAB")
        G.Show()
    end)
    if C_Club then
        S.communitiesTab = S.MakeTab("EraUIClassicCommunitiesTab", 92, S.Say("COMMUNITIES", "Communities"), CommunitiesClicked)
    end
end

---------------------------------------------------------------------------
-- The guild key and the micro button (post-hooks on the game's own calls)
---------------------------------------------------------------------------

-- The game's guild window closed again, the social window toggled.
-- onGuildPage: open on the Guild page (the key) rather than its own page.
function G.Turn(now, onGuildPage)
    S.notes.PutAway()
    for _, window in ipairs({ CommunitiesFrame or false, GuildFrame or false }) do
        if window and window:IsShown() then Look.HidePanel(window) end
    end
    local classic = FriendsFrame
    if classic:IsShown() or G.closedAt == now then
        G.Hide()
        Look.HidePanel(classic)
    elseif Look.ShowPanel(classic) and onGuildPage then
        G.Show()
        G.openedAt = now
    end
    RefreshMicro()
end

local function Toggled()
    if G.passing or not G.active or not Look.Enabled() or not FriendsFrame then return end
    local now = S.Now()
    G.toggledAt = now
    if Look.InFight() then
        G.booked = { micro = false }
        return
    end
    G.Turn(now, true)
end

local function MicroClicked()
    if not G.active or not Look.Enabled() or QuickBinding() or not FriendsFrame then return end
    local now = S.Now()
    if G.toggledAt == now then
        -- The game's own click ran ToggleGuildFrame (the post-hook above):
        -- the micro button keeps the social window on its own page.
        if G.booked then G.booked.micro = true end
        if G.openedAt == now then G.Hide() end
        return
    end
    G.toggledAt = now
    if Look.InFight() then return end
    G.Turn(now, false)
end

-- After a fight: the game's guild window, if still up, becomes the social
-- window.
local function AfterFight()
    local booked = G.booked
    G.booked = nil
    if not (booked and G.active and CommunitiesFrame and CommunitiesFrame:IsShown()) then return end
    G.Turn(S.Now(), not booked.micro)
end

-- The named click target (a /click macro): the Guild page toggled.
local function BindClicked()
    if not G.active then return end
    local page = parts.page
    if FriendsFrame and FriendsFrame:IsShown() and page and page:IsShown() then
        Look.HidePanel(FriendsFrame)
    else
        ns.OpenGuildRoster()
    end
end

local function ClickTarget()
    if G.target then return end
    local target = Look.Build("Button", UIParent, nil, { name = "EraUIClassicGuildBind", size = { 1, 1 } })
    Look.Pin(target, "TOPLEFT", UIParent, "TOPLEFT", -500, 500)
    target:EnableMouse(false)
    target:RegisterForClicks("AnyUp")
    target:SetScript("OnClick", BindClicked)
    G.target = target
end

---------------------------------------------------------------------------
-- Hooks (once) and the registry entry
---------------------------------------------------------------------------

local function KeepUp()
    local page = parts.page
    if not (G.active and page and page:IsShown()) then return end
    S.HideGamePages("guild")
    S.ChooseTab(S.guildTab)
    G.DressWindow()
end

local function Hooks()
    if G.hooked then return end
    G.hooked = true
    local classic = FriendsFrame
    Look.HookScript(classic, "OnShow", function()
        if not G.active then return end
        ns.PlaceSocialTabs()
        G.TabState()
    end, "guild")
    Look.HookScript(classic, "OnHide", function()
        G.closedAt = S.Now()
        G.Hide()
    end, "guild")
    S.After("FriendsFrame_Update", KeepUp)
    S.After("ToggleGuildFrame", Toggled)
    S.HookGameTabs()
    S.WatchTabResize()
    local micro = GuildMicroButton
    if micro then
        Look.HookScript(micro, "OnClick", MicroClicked, "guild")
        if type(ns.MicroButtonFollows) == "function" then
            ns.MicroButtonFollows(micro, function() return FriendsFrame ~= nil and FriendsFrame:IsShown() end)
        end
    end
    local fightEnds = CreateFrame("Frame")
    Look.Listen(fightEnds, "PLAYER_REGEN_ENABLED")
    fightEnds:SetScript("OnEvent", function() Look.Try(AfterFight) end)
    S.notes.Start()
    ClickTarget()
end

local function GuildOn()
    if not FriendsFrame then
        Look.MissingPiece("FriendsFrame")
        return
    end
    G.active = true
    G.Build()
    G.MakeTabs()
    Look.Shown(S.guildTab, true)
    Look.Shown(S.communitiesTab, true)
    Hooks()
    ns.PlaceSocialTabs()
    G.TabState()
    G.applied = true
end

local function GuildOff()
    G.active = false
    if not G.applied then return end
    G.Hide()
    S.notes.PutAway()
    Look.Shown(S.guildTab, false)
    Look.Shown(S.communitiesTab, false)
    ns.PlaceSocialTabs()
end

ns.RegisterModule("guildRoster", { apply = GuildOn, restore = GuildOff })
