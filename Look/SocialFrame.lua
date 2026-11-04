-- The social window (FriendsFrame) as EraUI's Who and Guild pages share it
-- (Classic look, spec 10 sections 5 and 14):
--   * the game's own pages stepping aside (alpha and mouse, never Hide)
--     while one of EraUI's pages is up, and everything else hung on the
--     window swept aside with them, every 0.25 s while a page shows;
--   * the window's title for whatever the game's page now is;
--   * the bottom tab row (Friends, Who, Guild, Communities, then the game's
--     others) and EraUI's three tabs, each fitted to its text + 38;
--   * one post-hook per game function, shared by every listener of the
--     area (so the Who and Guild pages can both follow FriendsFrame_Update).
-- EraUI's records of the game's frames live in weak tables here, never on
-- the frames. The window's chrome (spec 12) is not drawn here.
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social

local function InFight() return Look.InFight() end

local function MouseOn(frame)
    local fine, on = Look.Ask(frame, "IsMouseEnabled")
    return fine and on == true
end

local function Alpha(frame)
    local fine, alpha = Look.Ask(frame, "GetAlpha")
    return fine and Look.Number(alpha) or 1
end

---------------------------------------------------------------------------
-- One post-hook per game function, many listeners
---------------------------------------------------------------------------

local listeners = {}

-- fn runs after the game's global function (with its arguments), each
-- listener on its own, so one error never stops the others. The hook goes in
-- only when the first listener asks (nothing is hooked while the area is off).
function S.After(globalName, fn)
    local list = listeners[globalName]
    if not list then
        list = {}
        listeners[globalName] = list
    end
    local known = false
    for _, run in ipairs(list) do
        if run == fn then known = true end
    end
    if not known then list[#list + 1] = fn end
    Look.HookGlobal(globalName, function(...)
        for _, run in ipairs(list) do Look.Try(run, ...) end
    end)
end

---------------------------------------------------------------------------
-- The game's own pages, out of the way while an EraUI page is up
---------------------------------------------------------------------------

local GAME_PAGES = Look.Words("FriendsListFrame IgnoreListFrame WhoFrame RaidFrame QuickJoinFrame FriendsFrameBroadcastInput")
local held = { who = Look.Weak(), guild = Look.Weak() } -- mark: { frame = true }
local headerHeld = {}                                   -- mark: true
local hadMouse = Look.Weak()                            -- frame: took the mouse before EraUI
local mouseOwed = false                                 -- a mouse change waits for the fight's end

local function HeldElsewhere(frame, mark)
    for other, frames in pairs(held) do
        if other ~= mark and frames[frame] then return true end
    end
    return false
end

local function Header()
    return FriendsFrame and FriendsFrame.FriendsTabHeader or nil
end

function S.HideGamePages(mark)
    local mine = held[mark]
    for _, name in ipairs(GAME_PAGES) do
        local frame = _G[name]
        if frame and frame:IsShown() then
            if hadMouse[frame] == nil then hadMouse[frame] = MouseOn(frame) end
            Look.Fade(frame)
            mine[frame] = true
            if InFight() then
                mouseOwed = true
            elseif MouseOn(frame) then
                frame:EnableMouse(false)
            end
        end
    end
    headerHeld[mark] = true
    Look.Fade(Header())
    S.Sweep(mark, true)
end

function S.ShowGamePages(mark)
    local mine = held[mark]
    for frame in pairs(mine) do
        mine[frame] = nil
        if not HeldElsewhere(frame, mark) then
            frame:SetAlpha(1)
            if InFight() then
                mouseOwed = true
            elseif hadMouse[frame] and not MouseOn(frame) then
                frame:EnableMouse(true)
            end
        end
    end
    headerHeld[mark] = nil
    if not next(headerHeld) then Look.Alpha(Header(), 1) end
    S.Sweep(mark, false)
end

---------------------------------------------------------------------------
-- The sweep: whatever else hangs on the window (the client adds and
-- re-shows pieces EraUI knows no name for, other addons too) fades and
-- lets go of the mouse while a page is up, and comes back with it.
---------------------------------------------------------------------------

local swept = { who = Look.Weak(), guild = Look.Weak() } -- mark: { child = { alpha, mouse } }
local own = Look.Weak()                                  -- EraUI's own frames on the window
S.owedBack = Look.Weak()                                 -- pieces given back in a fight, mouse owed
local traceArmed, traceSeen = false, false

function S.Own(frame)
    if frame then own[frame] = true end
end

local function Called(frame)
    local fine, name = Look.Ask(frame, "GetName")
    if fine and type(name) == "string" and not Look.Secret(name) then return name end
    return ""
end

local function KeptOnWindow(child, window)
    if own[child] then return true end
    local name = Called(child)
    if name:find("EraUIClassic", 1, true) or name:find("FriendsFrameTab", 1, true) then return true end
    return child == window.CloseButton or child == window.PortraitContainer or child == window.NineSlice
        or child == window.TitleContainer or child == window.Inset or child == _G.FriendsFrameInset
end

local function Children(frame)
    if not frame or type(frame.GetChildren) ~= "function" then return {} end
    local fine, list = pcall(function() return { frame:GetChildren() } end)
    return fine and list or {}
end

-- One child out of the way (its first alpha and mouse remembered).
local function Tuck(record, child, mouseOnly)
    local entry = record[child]
    if not entry then
        local alpha = Alpha(child)
        entry = { alpha = alpha > 0 and alpha or nil, mouse = MouseOn(child), mouseOnly = mouseOnly }
        record[child] = entry
    end
    if not mouseOnly and Alpha(child) > 0 then child:SetAlpha(0) end
    if not InFight() and MouseOn(child) then child:EnableMouse(false) end
end

local function TuckDeep(record, frame, depth)
    if depth <= 0 then return end
    for _, child in ipairs(Children(frame)) do
        Tuck(record, child, true)
        TuckDeep(record, child, depth - 1)
    end
end

-- The window's inset kept at its friends-list place (out of a fight).
local function SeatInset(window)
    local inset = _G.FriendsFrameInset or window.Inset
    if not inset or InFight() then return end
    local point, _, _, x, y = inset:GetPoint(1)
    y, x = Look.Number(y), Look.Number(x)
    if type(point) ~= "string" or not y or math.abs(y + 83) <= 0.5 then return end
    inset:SetPoint("TOPLEFT", window, "TOPLEFT", x or 4, -83)
end

local function Trace(window)
    local saved = ns.db
    local on = saved and saved.sweepTrace == true
    if on and not traceSeen then traceArmed = true end
    traceSeen = on
    if not (on and traceArmed) then return end
    traceArmed = false
    local still = {}
    for _, holder in ipairs({ window, window.TitleContainer, _G.FriendsFrameInset or window.Inset }) do
        for _, child in ipairs(Children(holder)) do
            if child:IsVisible() and Alpha(child) > 0 then still[#still + 1] = Called(child) ~= "" and Called(child) or "(unnamed)" end
        end
    end
    local say = type(EraUI.Print) == "function" and function(text) EraUI:Print(text) end or print
    say("Social window sweep: still visible: " .. (#still > 0 and table.concat(still, ", ") or "nothing"))
end

-- The options' "/eraui-classic sweep": the next sweep says what is left.
function ns.SweepFriendsReport()
    traceArmed = true
end

function S.Sweep(mark, hide)
    local window = FriendsFrame
    local record = swept[mark]
    if not window or not record then return end
    if hide then
        SeatInset(window)
        for _, holder in ipairs({ window.TitleContainer, _G.FriendsFrameInset or window.Inset }) do
            for _, child in ipairs(Children(holder)) do
                if not Called(child):find("EraUIClassic", 1, true) and not own[child] then Tuck(record, child) end
            end
        end
        for _, child in ipairs(Children(window)) do
            if not KeptOnWindow(child, window) then Tuck(record, child) end
        end
        TuckDeep(record, Header(), 4)
        Trace(window)
        return
    end
    local other = mark == "who" and swept.guild or swept.who
    for child, entry in pairs(record) do
        record[child] = nil
        if not other[child] then
            if not entry.mouseOnly then child:SetAlpha(entry.alpha or 1) end
            if entry.mouse then
                if InFight() then S.owedBack[child] = true elseif not MouseOn(child) then child:EnableMouse(true) end
            end
        end
    end
end

-- Pages kept swept: every 0.25 s each registered page that shows sweeps again.
local keptPages = {}
local keeping = false
function S.KeepSwept(page, mark)
    keptPages[page] = mark
    if keeping then return end
    keeping = true
    Look.Every(0.25, function()
        for kept, itsMark in pairs(keptPages) do
            if kept:IsShown() then S.Sweep(itsMark, true) end
        end
    end)
end

-- After a fight: each of the game's pages takes the mouse it had, unless a
-- page of EraUI's still has it aside; a swept piece given back in the fight
-- takes its mouse again. (Pieces still swept are caught by the keeper.)
local function SettleMouse()
    if InFight() then return end
    if mouseOwed then
        mouseOwed = false
        for frame, had in pairs(hadMouse) do
            local want = had and not held.who[frame] and not held.guild[frame]
            if MouseOn(frame) ~= want then frame:EnableMouse(want) end
        end
    end
    for child in pairs(S.owedBack) do
        S.owedBack[child] = nil
        if not swept.who[child] and not swept.guild[child] and not MouseOn(child) then child:EnableMouse(true) end
    end
end

do
    local fightEnds = CreateFrame("Frame")
    Look.Listen(fightEnds, "PLAYER_REGEN_ENABLED")
    fightEnds:SetScript("OnEvent", function() Look.Try(SettleMouse) end)
end

---------------------------------------------------------------------------
-- The window's title, for the game's own page
---------------------------------------------------------------------------

local function SelectedGameTab(window)
    local chosen = Look.Number(window.selectedTab)
    if not chosen and type(PanelTemplates_GetSelectedTab) == "function" then
        local fine, answer = pcall(PanelTemplates_GetSelectedTab, window)
        chosen = fine and Look.Number(answer) or nil
    end
    return chosen or 1
end

function S.RestoreTitle()
    local window, title = FriendsFrame, _G.FriendsFrameTitleText
    if not window or not title then return end
    local chosen = SelectedGameTab(window)
    local text
    if FRIEND_TAB_WHO and chosen == FRIEND_TAB_WHO then
        text = S.Say("WHO_LIST", "Who List")
    elseif chosen == (FRIEND_TAB_RAID or 3) then
        text = S.Say("RAID", "Raid")
    elseif chosen == (FRIEND_TAB_QUICK_JOIN or 4) then
        text = S.Say("QUICK_JOIN", "Quick Join")
    else
        local header = Header()
        local fine, sub = Look.Ask(header, "GetTab")
        sub = fine and Look.Number(sub) or nil
        if sub and header and sub == header.recentAlliesTabID then
            text = S.Say("CONTACTS_RECENT_ALLIES_TITLE", "Recent Allies")
        elseif sub and header and sub == header.recruitAFriendTabID then
            text = S.Say("RECRUIT_A_FRIEND", "Recruit A Friend")
        else
            text = S.Say("CONTACTS_LIST_TITLE", S.Say("FRIENDS", "Friends"))
        end
    end
    title:SetText(text)
end

---------------------------------------------------------------------------
-- The bottom tab row
---------------------------------------------------------------------------

local PADDING = 38
local rowTabs = Look.Weak() -- the tabs EraUI lays: fitted to text + 38
local gap                   -- measured once, the first time the row is laid

-- Its text width + 38, the middle pieces 40 less (no chrome refit here).
local function FitWidth(tab)
    local label = tab.Text or (tab.GetFontString and tab:GetFontString())
    local across = label and Look.Number(label:GetStringWidth())
    if not across then return end
    local wide = math.ceil(across) + PADDING
    if math.abs((Look.Number(tab:GetWidth()) or 0) - wide) > 0.5 then tab:SetWidth(wide) end
    for _, key in ipairs({ "Middle", "MiddleActive" }) do
        local piece = tab[key]
        if piece and piece.SetWidth then piece:SetWidth(wide - 40) end
    end
end

-- The window chrome's own fit first (it lifts a tab hung straight on the
-- window), then the 38 padding this area uses.
function S.FitTab(tab)
    if not tab then return end
    rowTabs[tab] = true
    if type(ns.FitBottomTab) == "function" then Look.Try(ns.FitBottomTab, tab) end
    FitWidth(tab)
end

local function GameTabs()
    local list = {}
    for i = 1, 10 do
        local tab = _G["FriendsFrameTab" .. i]
        if tab then list[#list + 1] = tab end
    end
    return list
end

local function MeasureGap()
    local first, second
    for _, tab in ipairs(GameTabs()) do
        if tab:IsShown() then
            if not first then first = tab elseif not second then second = tab end
        end
    end
    if first and second then
        local right, left = Look.Number(first:GetRight()), Look.Number(second:GetLeft())
        if right and left then return left - right end
    end
    return -14
end

-- Order: the game's Friends tab, EraUI's Who, Guild and Communities, then
-- the game's others as it numbers them; only the shown ones, the first at
-- the window's bottom-left (5, 2), each next one just right of the last.
function ns.PlaceSocialTabs()
    local window = FriendsFrame
    if not window then return end
    if gap == nil then gap = MeasureGap() end
    local order = { _G.FriendsFrameTab1 }
    for _, key in ipairs({ "whoTab", "guildTab", "communitiesTab" }) do
        if S[key] then order[#order + 1] = S[key] end
    end
    for i = 2, 10 do
        local tab = _G["FriendsFrameTab" .. i]
        if tab then order[#order + 1] = tab end
    end
    local previous
    for _, tab in ipairs(order) do
        if tab:IsShown() then
            tab:ClearAllPoints()
            if previous then
                tab:SetPoint("BOTTOMLEFT", previous, "BOTTOMRIGHT", gap, 0)
            else
                tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 5, 2)
            end
            S.FitTab(tab)
            previous = tab
        end
    end
end

-- The game's own resize (a tab shown, the Quick Join count) brings the
-- chrome's fit back; the 38 padding is put back after it.
local function AfterTabResize(tab)
    if tab and rowTabs[tab] and (S.who.active or S.guild.active) then FitWidth(tab) end
end

function S.WatchTabResize()
    S.After("PanelTemplates_TabResize", AfterTabResize)
end

-- The game's own tabs close EraUI's pages (the game's tab code then shows
-- its own page). Once per tab.
local function GameTabClicked()
    if S.who.active and S.who.Hide then S.who.Hide() end
    if S.guild.active and S.guild.Hide then S.guild.Hide() end
end

function S.HookGameTabs()
    for i = 1, 8 do
        local tab = _G["FriendsFrameTab" .. i]
        if tab then Look.HookScript(tab, "OnClick", GameTabClicked, "social") end
    end
end

---------------------------------------------------------------------------
-- EraUI's tabs (Who 91, Guild 90, Communities 92): the game's tab template,
-- on a holder of EraUI's own (so the window's own tab list is never added
-- to), the 1.x tab art from the window chrome, EraUI's own tooltip.
---------------------------------------------------------------------------

local function TabEnter(tab)
    local text = tab.Text
    local fine, cut = Look.Ask(text, "IsTruncated")
    if fine and cut == true then Look.ShowTip(tab, "RIGHT", { { text:GetText() or "", 1, 1, 1 } }) end
end

local function TabLeave(tab) Look.HideTip(tab) end

function S.TabHolder()
    if S.tabHolder then return S.tabHolder end
    local window = FriendsFrame
    local holder = Look.Build("Frame", window, nil, { name = "EraUIClassicSocialTabs", size = { 10, 10 } })
    Look.Fill(holder, window)
    S.Own(holder)
    S.tabHolder = holder
    return holder
end

function S.MakeTab(name, id, text, onClick)
    local tab = CreateFrame("Button", name, S.TabHolder(), "PanelTabButtonTemplate")
    tab:SetSize(80, 32)
    tab:SetID(id)
    tab:SetText(text)
    tab:SetScript("OnEnter", TabEnter)
    tab:SetScript("OnLeave", TabLeave)
    tab:SetScript("OnClick", onClick)
    if type(ns.SkinBottomTab) == "function" then Look.Try(ns.SkinBottomTab, tab) end
    if type(PanelTemplates_DeselectTab) == "function" then Look.Try(PanelTemplates_DeselectTab, tab) end
    S.FitTab(tab)
    return tab
end

-- Its page up: the tab looks chosen, the game's tabs not (cosmetic only:
-- the game's tabs are never clicked, their state never written).
function S.ChooseTab(tab)
    if not tab then return end
    if type(PanelTemplates_SelectTab) == "function" then Look.Try(PanelTemplates_SelectTab, tab) end
    if type(PanelTemplates_DeselectTab) == "function" then
        for i = 1, 8 do
            local gameTab = _G["FriendsFrameTab" .. i]
            if gameTab then Look.Try(PanelTemplates_DeselectTab, gameTab) end
        end
    end
    S.FitTab(tab)
end

-- Its page gone: the tab looks unchosen, and the game's chosen tab looks
-- chosen again.
function S.UnchooseTab(tab)
    if not tab then return end
    if type(PanelTemplates_DeselectTab) == "function" then Look.Try(PanelTemplates_DeselectTab, tab) end
    S.FitTab(tab)
    local window = FriendsFrame
    local tabs = window and window.Tabs
    local gameTab = type(tabs) == "table" and tabs[SelectedGameTab(window)] or nil
    if gameTab and gameTab:IsShown() and type(PanelTemplates_SelectTab) == "function" then
        Look.Try(PanelTemplates_SelectTab, gameTab)
    end
end

-- A page frame on the window: (8, -64) to (-8, 12), 6 levels above it.
function S.PageFrame(name)
    local window = FriendsFrame
    local page = Look.Build("Frame", window, nil, { name = name, size = { 344, 348 }, hidden = true })
    page:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -64)
    page:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 12)
    page:SetFrameLevel((Look.Number(window:GetFrameLevel()) or 1) + 6)
    S.Own(page)
    return page
end
