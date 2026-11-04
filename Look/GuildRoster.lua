-- What the Guild page shows (Classic look, spec 10 section 8): the roster
-- read from the game (only in a guild; every field the game may hide checked
-- first; offline members only while Show Offline is on), sorted locally (and
-- asked of the server too), the rows in either view, the two counts, the
-- message of the day, the window's title and portrait while the page is
-- up, the Guild tab's state, the foot's buttons and the roster's events.
-- Public: ns.RefreshGuildRoster().
local _, EraUI = ...
local ns = EraUI.Classic
local Look = EraUI.Look
local S = Look.Social
local G = S.guild
local parts = G.parts
local unpack = unpack or table.unpack

G.entries = {}
G.sort = { field = "name", up = true }
G.total, G.onlineCount = 0, 0
G.rowEntry = Look.Weak() -- row: the member it shows

---------------------------------------------------------------------------
-- Reading
---------------------------------------------------------------------------

function G.InGuild()
    return S.Yes(IsInGuild)
end

function G.ShowOffline()
    return S.Yes(GetGuildRosterShowOffline)
end

local SPANS = { { "LASTONLINE_YEARS", "%d years" }, { "LASTONLINE_MONTHS", "%d months" },
    { "LASTONLINE_DAYS", "%d days" }, { "LASTONLINE_HOURS", "%d hours" } }

local function LastOnline(entry)
    if entry.online then return S.Say("GUILD_ONLINE_LABEL", "Online") end
    if type(GetGuildRosterLastOnline) ~= "function" then return "" end
    local answer = { pcall(GetGuildRosterLastOnline, entry.index) }
    if not answer[1] then return "" end
    for i, span in ipairs(SPANS) do
        local count = Look.Number(answer[i + 1]) or 0
        if count > 0 then
            local fine, text = pcall(string.format, S.Say(span[1], span[2]), count)
            return fine and text or tostring(count)
        end
    end
    return S.Say("LASTONLINE_MINS", "moments ago")
end

local function ShortName(name)
    if type(Ambiguate) ~= "function" then return name end
    local fine, short = pcall(Ambiguate, name, "guild")
    if fine and type(short) == "string" and not Look.Secret(short) and short ~= "" then return short end
    return name
end

-- One roster line (GetGuildRosterInfo's answers), or nil when its name
-- can't be read.
local function Member(index, name, rank, rankIndex, level, class, zone, note, officerNote, online, status, classFile, ...)
    if type(name) ~= "string" or Look.Secret(name) or name == "" then return nil end
    local guid = select(6, ...) -- the 17th answer
    return {
        index = index, name = ShortName(name), rank = S.Text(rank, ""), rankIndex = Look.Number(rankIndex) or 0,
        level = Look.Number(level) or 0, class = S.Text(class, ""), classFile = S.Text(classFile, nil),
        zone = S.Text(zone, ""), note = S.Text(note, ""), officerNote = S.Text(officerNote, ""),
        online = not Look.Secret(online) and online == true, status = Look.Number(status) or 0,
        guid = S.Text(guid, nil),
    }
end

function G.Read()
    local list = {}
    G.total, G.onlineCount = 0, 0
    if G.InGuild() then
        local fine, total, online = S.Call(GetNumGuildMembers)
        if fine then G.total, G.onlineCount = S.Count(total), S.Count(online) end
        local offlineToo = G.ShowOffline()
        for i = 1, G.total do
            local answer = { S.Call(GetGuildRosterInfo, i) }
            local entry = answer[1] and Member(i, unpack(answer, 2, 18)) or nil
            if entry and (entry.online or offlineToo) then
                entry.lastText = LastOnline(entry)
                list[#list + 1] = entry
            end
        end
    end
    G.entries = list
end

-- The chosen member (kept by roster index), or nil.
function G.Chosen()
    if not G.selected then return nil end
    for _, entry in ipairs(G.entries) do
        if entry.index == G.selected then return entry end
    end
    return nil
end

function ns.GuildIsMe(entry)
    if type(entry) ~= "table" then return false end
    return S.Mine(entry.name, entry.guid)
end

---------------------------------------------------------------------------
-- Sorting: rank by its index, last online as online-before-offline, the
-- level as a number, the rest as lower-case text; ties by the name, always
-- A to Z.
---------------------------------------------------------------------------

local function SortValue(entry, field)
    if field == "rank" then return entry.rankIndex end
    if field == "level" then return entry.level end
    if field == "lastOnline" then return entry.online and 0 or 1 end
    return S.Lower(entry[field])
end

function G.Sort()
    local field, up = G.sort.field, G.sort.up
    table.sort(G.entries, function(a, b)
        local x, y = SortValue(a, field), SortValue(b, field)
        if x ~= y then
            if up then return x < y end
            return x > y
        end
        return S.Lower(a.name) < S.Lower(b.name)
    end)
end

function G.HeaderClicked(index)
    local column = G.Columns()[index]
    if not column then return end
    if G.sort.field == column.key then
        G.sort.up = not G.sort.up
    else
        G.sort.field, G.sort.up = column.key, true
    end
    -- The server's own order too (out of a fight; it knows no last-online
    -- sort, so that one quietly does nothing).
    if not Look.InFight() then S.Call(SortGuildRoster, column.key) end
    G.Refresh()
end

---------------------------------------------------------------------------
-- The rows and the views
---------------------------------------------------------------------------

local function Draw(row, entry)
    local texts = S.rowParts[row].texts
    local status = G.view == "status"
    local values = status and { entry.name, entry.rank, entry.note, entry.lastText }
        or { entry.name, entry.zone, tostring(entry.level), entry.class }
    for c = 1, 4 do texts[c]:SetText(values[c] or "") end
    if not entry.online then
        for c = 1, 4 do S.Colour(texts[c], S.GREY) end
    else
        S.Colour(texts[1], S.GOLD)
        S.Colour(texts[2], S.WHITE)
        S.Colour(texts[3], S.WHITE)
        if status then S.Colour(texts[4], S.WHITE) else texts[4]:SetTextColor(S.ClassColour(entry.classFile)) end
    end
    Look.Shown(S.rowParts[row].mark, G.selected ~= nil and G.selected == entry.index)
end

local function PlaceToggle()
    local toggle, bar = parts.viewToggle, parts.bar
    if not toggle then return end
    Look.Pin(toggle, "BOTTOMRIGHT", parts.box, "BOTTOMRIGHT", (bar and bar:IsShown()) and -32 or -8, 2)
end

local filling = false
function G.Fill()
    if filling or not parts.rows then return end
    filling = true
    local shown = S.RowsShown(parts.area)
    Look.ScrollRange(parts.bar, math.max(0, #G.entries - shown))
    local offset = math.floor(Look.Number(parts.bar:GetValue()) or 0)
    for i, row in ipairs(parts.rows) do
        local entry = i <= shown and G.entries[offset + i] or nil
        G.rowEntry[row] = entry
        if entry then
            Draw(row, entry)
            row:Show()
        else
            row:Hide()
        end
    end
    PlaceToggle()
    filling = false
    if S.notes.Check then Look.Try(S.notes.Check) end
end

-- The headers re-keyed, re-labelled and re-widthed, the rows' texts placed
-- again (after a view switch).
function G.LayColumns()
    local columns = G.Columns()
    for i, header in ipairs(parts.headers or {}) do
        header:SetWidth(columns[i].width)
        header:SetText(columns[i].label())
    end
    for _, row in ipairs(parts.rows or {}) do S.LayRow(row, columns) end
end

function G.ViewTip(owner)
    local words = G.view == "status" and S.Say("GUILD_STATUS", "Guild Status") or S.Say("PLAYER_STATUS", "Player Status")
    Look.ShowTip(owner, "RIGHT", { { words, 1, 1, 1 } })
end

function G.FlipView()
    G.view = G.view == "player" and "status" or "player"
    S.Sound("IG_MAINMENU_OPTION_CHECKBOX_ON")
    G.LayColumns()
    local known = false
    for _, column in ipairs(G.Columns()) do
        if column.key == G.sort.field then known = true end
    end
    if not known then G.sort.field, G.sort.up = "name", true end
    G.Refresh()
    if parts.viewToggle and Look.TipOwner() == parts.viewToggle then G.ViewTip(parts.viewToggle) end
end

---------------------------------------------------------------------------
-- Counts, message of the day, title and portrait
---------------------------------------------------------------------------

local function Formatted(word, fallback, count)
    local fine, text = pcall(string.format, S.Say(word, fallback), count)
    return fine and text or tostring(count)
end

local function Motd()
    if not Look.InFight() then
        local info = C_GuildInfo
        local fine, text = S.Call(info and info.GetMOTD)
        if not (fine and type(text) == "string" and not Look.Secret(text)) then
            fine, text = S.Call(GetGuildRosterMOTD)
        end
        if fine and type(text) == "string" and not Look.Secret(text) then G.lastMotd = text end
    end
    if parts.motd then parts.motd:SetText(G.lastMotd or "") end
end

-- "Rank of Guild", the guild alone, or "Guild" (the last read in a fight).
function G.Title()
    if not Look.InFight() then
        local fine, guild, rank = S.Call(GetGuildInfo, "player")
        guild, rank = fine and S.Text(guild, nil), fine and S.Text(rank, nil)
        if guild and guild ~= "" then
            if rank and rank ~= "" then
                local ok, text = pcall(string.format, S.Say("GUILD_TITLE_TEMPLATE", "%s of %s"), rank, guild)
                G.lastTitle = ok and text or guild
            else
                G.lastTitle = guild
            end
        else
            G.lastTitle = S.Say("GUILD", "Guild")
        end
    end
    local title = _G.FriendsFrameTitleText
    if title then title:SetText(G.lastTitle or S.Say("GUILD", "Guild")) end
end

local iconWas = Look.Weak() -- the window's portrait: its own texture before
local SCROLL_ICON = "Interface\\FriendsFrame\\FriendsFrameScrollIcon"

function G.DressWindow()
    G.Title()
    local icon = _G.FriendsFrameIcon
    if not icon then return end
    if iconWas[icon] == nil then
        local fine, file = Look.Ask(icon, "GetTexture")
        iconWas[icon] = (fine and file and not Look.Secret(file)) and file or false
    end
    icon:SetTexture(SCROLL_ICON)
    Look.Crop(icon, 0, 1, 0, 1)
end

function G.UndressWindow()
    S.RestoreTitle()
    local icon = _G.FriendsFrameIcon
    local was = icon and iconWas[icon]
    if was then icon:SetTexture(was) end
    if icon then iconWas[icon] = nil end
end

---------------------------------------------------------------------------
-- The foot's buttons and the Show Offline pill
---------------------------------------------------------------------------

function G.Buttons()
    if parts.addMember then parts.addMember:SetEnabled(S.Yes(CanGuildInvite)) end
    if parts.guildControl then parts.guildControl:SetEnabled(S.Yes(IsGuildLeader)) end
end

function G.OfflineClicked(checked)
    S.Call(SetGuildRosterShowOffline, checked)
    if C_GuildInfo then S.Call(C_GuildInfo.GuildRoster) end
    G.Refresh()
end

function G.AddMember()
    if Look.InFight() then return S.NotInFight() end
    local club
    if C_Club then
        local fine, id = S.Call(C_Club.GetGuildClubId)
        if fine and not Look.Secret(id) then club = id end
    end
    S.Call(StaticPopup_Show, "ADD_GUILDMEMBER", nil, nil, { clubId = club })
end

local function PlaceControl()
    local control = GuildControlUI
    if control and control:IsShown() and FriendsFrame and FriendsFrame:IsShown() and not Look.InFight() then
        Look.Pin(control, "TOPLEFT", FriendsFrame, "TOPRIGHT", 6, 0)
    end
end

function G.GuildControl()
    if Look.InFight() then return S.NotInFight() end
    local control = GuildControlUI
    if control and control:IsShown() then
        Look.HidePanel(control)
        return
    end
    if type(GuildControlUI_Show) ~= "function" and type(ToggleGuildControlUI) ~= "function" and C_AddOns then
        S.Call(C_AddOns.LoadAddOn, "Blizzard_GuildControlUI")
    end
    if type(GuildControlUI_Show) == "function" then
        Look.Try(GuildControlUI_Show)
        S.NextFrame(PlaceControl)
    elseif type(ToggleGuildControlUI) == "function" then
        Look.Try(ToggleGuildControlUI)
    end
end

---------------------------------------------------------------------------
-- Refresh, events, the Guild tab's state
---------------------------------------------------------------------------

-- Only while the page shows.
function G.Refresh()
    local page = parts.page
    if not page or not page:IsShown() then return end
    G.Read()
    G.Sort()
    if parts.members then parts.members:SetText(Formatted("GUILD_TOTAL", "%d Guild Members", G.total)) end
    if parts.online then parts.online:SetText(Formatted("GUILD_TOTALONLINE", "(%d Online)", G.onlineCount)) end
    Motd()
    if parts.offline then parts.offline:SetChecked(G.ShowOffline()) end
    G.Title()
    G.Fill()
    G.Buttons()
    if G.UpdateMember then G.UpdateMember() end
end

function ns.RefreshGuildRoster()
    G.Refresh()
end

-- In a guild: the tab works, white while its page shows, gold otherwise.
-- Not: the page goes, the tab is greyed and does nothing.
function G.TabState()
    local tab = S.guildTab
    if not tab then return end
    local label = tab.Text or (tab.GetFontString and tab:GetFontString())
    if G.InGuild() then
        if G.tabOff then
            G.tabOff = false
            tab:Enable()
            if type(PanelTemplates_DeselectTab) == "function" then Look.Try(PanelTemplates_DeselectTab, tab) end
            S.FitTab(tab)
        end
        local up = parts.page and parts.page:IsShown()
        if label then S.Colour(label, up and S.WHITE or S.GOLD) end
    else
        if parts.page and parts.page:IsShown() then G.Hide() end
        G.tabOff = true
        tab:Disable()
        if label then S.Colour(label, S.GREY) end
    end
end

local function TabStateSoon()
    G.TabState()
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(1, function() Look.Try(G.TabState) end)
        C_Timer.After(4, function() Look.Try(G.TabState) end)
    end
end

local ROSTER_EVENTS = { GUILD_ROSTER_UPDATE = true, PLAYER_GUILD_UPDATE = true, GUILD_MOTD = true }

function G.Listen()
    if G.listening then return end
    G.listening = true
    local listener = CreateFrame("Frame")
    for event in pairs(ROSTER_EVENTS) do Look.Listen(listener, event) end
    Look.Listen(listener, "PLAYER_REGEN_ENABLED")
    listener:SetScript("OnEvent", function(_, event)
        if ROSTER_EVENTS[event] then
            G.dirty = true
            S.notes.stale = true
            if event ~= "GUILD_MOTD" and G.active then Look.Try(TabStateSoon) end
            return
        end
        if not G.active then return end
        if parts.page and parts.page:IsShown() then Look.Try(G.Refresh) end
        if G.openAsked then
            G.openAsked = false
            Look.Try(ns.OpenGuildRoster)
        end
    end)
    Look.Every(0.33, function()
        if G.dirty and G.active then
            G.dirty = false
            G.Refresh()
        end
    end)
end
