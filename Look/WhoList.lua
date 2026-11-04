-- What the Who page does (Classic look, spec 10 section 7): reading the
-- /who results (every field the game may hide checked first), sorting them
-- locally, the rows, selection and right-click menu, searching, results
-- landing on the page instead of the game's own Who list, showing and
-- hiding the page, and the group finder's side tabs. The page is laid out
-- in Look/WhoPage.lua; the registry entry is in Look/WhoModule.lua.
-- Public: ns.OpenWhoList(), ns.HideWhoList().
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local W = S.who
local parts = W.parts

W.entries = {}
W.sort = { field = "name", up = true }
local rowEntry = Look.Weak() -- row: the entry it shows
W.rowEntry = rowEntry

local function Words(name, fallback) return S.Say(name, fallback) end

---------------------------------------------------------------------------
-- Reading and sorting
---------------------------------------------------------------------------

local function Entry(info)
    if type(info) ~= "table" then return nil end
    local name = info.fullName
    if type(name) ~= "string" or Look.Secret(name) or name == "" then return nil end
    return {
        name = name,
        guild = S.Text(info.fullGuildName, ""),
        zone = S.Text(info.area, ""),
        level = Look.Number(info.level) or 0,
        class = S.Text(info.classStr, ""),
        classFile = S.Text(info.filename, nil),
        race = S.Text(info.raceStr, ""),
    }
end

function W.Read()
    local list, shown, total = {}, 0, nil
    local api = C_FriendList
    if type(api) == "table" then
        local fine, count, all = S.Call(api.GetNumWhoResults)
        if fine then shown, total = S.Count(count), Look.Number(all) end
        for i = 1, shown do
            local asked, info = S.Call(api.GetWhoInfo, i)
            local entry = asked and Entry(info) or nil
            if entry then list[#list + 1] = entry end
        end
    end
    W.entries = list
    W.total = total or shown
end

local function SortValue(entry, field)
    if field == "level" then return entry.level end
    return S.Lower(entry[field])
end

-- Strings in lower case, the level as a number; equal values by the name,
-- the same way round.
function W.Sort()
    local field, up = W.sort.field, W.sort.up
    table.sort(W.entries, function(a, b)
        local x, y = SortValue(a, field), SortValue(b, field)
        if x == y then x, y = S.Lower(a.name), S.Lower(b.name) end
        if up then return x < y end
        return x > y
    end)
end

function W.HeaderClicked(index)
    local column = W.COLUMNS[index]
    if not column then return end
    local field = column.key == "second" and W.SecondField() or column.key
    if W.sort.field == field then
        W.sort.up = not W.sort.up
    else
        W.sort.field, W.sort.up = field, true
    end
    W.Refresh()
end

---------------------------------------------------------------------------
-- The rows
---------------------------------------------------------------------------

local function Draw(row, entry)
    local texts = S.rowParts[row].texts
    texts[1]:SetText(entry.name)
    S.Colour(texts[1], S.GOLD)
    texts[2]:SetText(entry[W.SecondField()] or "")
    S.Colour(texts[2], S.WHITE)
    texts[3]:SetText(tostring(entry.level))
    S.Colour(texts[3], S.WHITE)
    texts[4]:SetText(entry.class)
    texts[4]:SetTextColor(S.ClassColour(entry.classFile))
    Look.Shown(S.rowParts[row].mark, W.selected ~= nil and W.selected == entry.name)
end

local filling = false
function W.Fill()
    if filling or not parts.rows then return end
    filling = true
    local shown = S.RowsShown(parts.area)
    W.rowsShown = shown
    Look.ScrollRange(parts.bar, math.max(0, #W.entries - shown))
    local offset = math.floor(Look.Number(parts.bar:GetValue()) or 0)
    for i, row in ipairs(parts.rows) do
        local entry = i <= shown and W.entries[offset + i] or nil
        rowEntry[row] = entry
        if entry then
            Draw(row, entry)
            row:Show()
        else
            row:Hide()
        end
    end
    filling = false
end

function W.Buttons()
    local chosen = W.selected ~= nil
    if parts.addFriend then parts.addFriend:SetEnabled(chosen) end
    if parts.invite then parts.invite:SetEnabled(chosen) end
end

function W.Title()
    local title = _G.FriendsFrameTitleText
    if title then title:SetText(Words("WHO_LIST", "Who List")) end
end

local function Found()
    if not parts.found then return end
    local fine, text = pcall(string.format, Words("WHO_NUM_RESULTS", "%d found"), W.total or 0)
    parts.found:SetText(fine and text or tostring(W.total or 0))
end

-- Only while the page shows.
function W.Refresh()
    local page = parts.page
    if not page or not page:IsShown() then return end
    W.Read()
    W.Sort()
    Found()
    W.Title()
    W.Fill()
    W.Buttons()
end

---------------------------------------------------------------------------
-- Selection, the menu, the buttons
---------------------------------------------------------------------------

local function Invite(name)
    if C_PartyInfo and name then S.Call(C_PartyInfo.InviteUnit, name) end
end

local function AddFriend(name)
    if C_FriendList and name then S.Call(C_FriendList.AddFriend, name) end
end

function W.Menu()
    if W.menu then return W.menu end
    W.menu = S.RowMenu({
        { Words("WHISPER", "Whisper"), function(entry) Look.Whisper(entry and entry.name) end },
        { Words("INVITE", "Invite"), function(entry) Invite(entry and entry.name) end },
        { Words("ADD_FRIEND", "Add Friend"), function(entry) AddFriend(entry and entry.name) end },
        { Words("IGNORE", "Ignore"), function(entry)
            if C_FriendList and entry then S.Call(C_FriendList.AddIgnore, entry.name) end
        end },
    })
    W.menu.Follow(parts.page)
    return W.menu
end

function W.RowClicked(row, mouse)
    local entry = rowEntry[row]
    if not entry then return end
    W.selected = entry.name
    W.Fill()
    W.Buttons()
    if mouse == "RightButton" and not S.Mine(entry.name) then W.Menu().Open(entry, entry.name) end
end

function W.RowDoubleClicked(row)
    local entry = rowEntry[row]
    if entry then Look.Whisper(entry.name) end
end

function W.AddFriend() AddFriend(W.selected) end
function W.Invite() Invite(W.selected) end

-- The second column's drop down: Zone, Guild or Race.
local COLUMN_PICK = { menu = "whoColumn" }
function W.OpenColumnMenu()
    if not W.columnMenu then
        local entries = {}
        for _, field in ipairs({ "zone", "guild", "race" }) do
            entries[#entries + 1] = { W.SECOND[field].label(), function() W.PickColumn(field) end }
        end
        W.columnMenu = S.RowMenu(entries)
        W.columnMenu.Follow(parts.page)
    end
    W.columnMenu.Open(COLUMN_PICK, "")
end

function W.PickColumn(field)
    if not W.SECOND[field] then return end
    local saved = ns.db
    if saved then saved.whoColumn = field end
    local header = parts.headers and parts.headers[2]
    if header then header:SetText(W.SECOND[field].label()) end
    W.sort.field, W.sort.up = field, true
    W.Refresh()
end

---------------------------------------------------------------------------
-- Searching, and where /who results land
---------------------------------------------------------------------------

-- Results to the window (true) or to chat (false).
function W.ToWindow(on)
    if C_FriendList then S.Call(C_FriendList.SetWhoToUi, on and true or false) end
end

-- The game's own Who list (in the group finder) switches results to chat as
-- it closes, so every search switches them back first.
function W.Send(text)
    W.ToWindow(true)
    if C_FriendList then S.Call(C_FriendList.SendWho, type(text) == "string" and text or "") end
end

-- The game's own Who window closed (out of a fight): the finder turned back
-- to its first tab first, so it doesn't remember Who.
function W.CloseGameWho()
    if Look.InFight() then return end
    local window, gameWho, finder = FriendsFrame, LFGWhoListFrame, LFGParentFrame
    if not (window and window:IsVisible() and gameWho and gameWho:IsShown() and finder and finder:IsShown()) then return end
    S.Call(LFGParentFrameTab1_OnClick)
    Look.HidePanel(finder)
    if parts.page and parts.page:IsShown() then W.ToWindow(true) end
end

function W.HideGamePages()
    S.HideGamePages("who")
    W.CloseGameWho()
end

local function AfterResult()
    if W.active and parts.page and parts.page:IsShown() then
        W.HideGamePages()
        S.ChooseTab(S.whoTab)
        W.Title()
    end
end

local function ResultCame()
    if not W.active or not ns.OpenWhoList() then return end
    W.HideGamePages()
    W.Title()
    W.Refresh()
    S.NextFrame(AfterResult)
end

-- Every frame while on: the game's own Who list showing (a /who from
-- anywhere, its Who tab) turns into this page. In a fight only with the
-- social window already open.
function W.Watch()
    if not W.active then return end
    local gameWho = LFGWhoListFrame
    if not (gameWho and gameWho:IsVisible()) then return end
    local window = FriendsFrame
    if Look.InFight() and not (window and window:IsShown()) then return end
    if Look.InFight() and parts.page and parts.page:IsShown() then return end
    if ns.OpenWhoList() then W.HideGamePages() end
end

function W.Listen()
    if W.listening then return end
    W.listening = true
    local listener = CreateFrame("Frame")
    Look.Listen(listener, "WHO_LIST_UPDATE")
    listener:SetScript("OnEvent", function() Look.Try(ResultCame) end)
    Look.Every(0, W.Watch)
end

---------------------------------------------------------------------------
-- Showing and hiding
---------------------------------------------------------------------------

function W.PageShown()
    W.ToWindow(true)
    W.Refresh()
end

function W.PageHidden()
    W.ToWindow(false)
end

function W.Show()
    local page = W.Build()
    W.BuildSideTabs()
    W.SyncSideTabs()
    if type(ns.HideGuildRoster) == "function" then Look.Try(ns.HideGuildRoster) end
    W.HideGamePages()
    local already = page:IsShown()
    page:Show()
    S.ChooseTab(S.whoTab)
    W.Title()
    if already then W.Refresh() end
    W.SyncSideTabs()
end

function W.Hide()
    local page = parts.page
    if not page then return end
    if W.menu then W.menu.Close() end
    if W.columnMenu then W.columnMenu.Close() end
    if not page:IsShown() then return end
    page:Hide()
    -- (Its own OnHide does this too; hidden while its window is going, it
    -- may not run.)
    W.ToWindow(false)
    S.UnchooseTab(S.whoTab)
    S.ShowGamePages("who")
    S.RestoreTitle()
end

-- The Who page from anywhere: false while the page is off, or when the
-- game refuses the social window (a fight, a guarded window).
function ns.OpenWhoList()
    if not W.active or not FriendsFrame then return false end
    W.Build()
    if not Look.ShowPanel(FriendsFrame) then return false end
    W.Show()
    return true
end

function ns.HideWhoList()
    W.Hide()
end

---------------------------------------------------------------------------
-- The group finder's side tabs on the page
---------------------------------------------------------------------------

function W.SyncSideTabs()
    local tabs = parts.sideTabs
    local on = Look.Saved().whoTabs == true
    if parts.arrow then W.ArrowArt(parts.arrow, on) end
    if not tabs then return end
    for i, tab in ipairs(tabs) do
        Look.Shown(tab, on)
        tab:SetChecked(i == 3)
    end
    local page = parts.page
    if on and page and page:IsShown() and not Look.InFight() and type(ns.WarmGroupFinder) == "function" then
        Look.Try(ns.WarmGroupFinder)
    end
end

function W.FlipSideTabs()
    local saved = ns.db
    if not saved then return end
    saved.whoTabs = saved.whoTabs ~= true
    Look.Save()
    W.BuildSideTabs()
    W.SyncSideTabs()
end

local function FinderTo(index)
    if type(ns.TurnGroupFinder) == "function" then Look.Try(ns.TurnGroupFinder, index) end
end

-- Create Listing or Group Browser, from the tab's own click (the secure
-- pad covers it while the finder is shut and no fight is on).
function W.SideTabClicked(tab, index)
    tab:SetChecked(index == 3)
    if index == 3 then return end
    if Look.InFight() then
        S.NotInFight()
        return
    end
    S.Sound("IG_CHARACTER_INFO_TAB")
    if LFGParentFrame and LFGParentFrame:IsShown() then
        FinderTo(index)
    else
        S.Call(LFGVanilla_ShowFrame, index)
    end
    Look.HidePanel(FriendsFrame)
end

-- After the pad's secure click opened the finder: turned to the tab, the
-- social window closed, and turned again a frame later.
function W.SideTabReleased(index)
    S.Sound("IG_CHARACTER_INFO_TAB")
    FinderTo(index)
    Look.HidePanel(FriendsFrame)
    S.NextFrame(function() FinderTo(index) end)
end
