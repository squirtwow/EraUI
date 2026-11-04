-- The Guild page of the social area's clean-room rewrite (Look/Guild*.lua,
-- 2026-10-21) on the social mock (Tools/SocialMockGame.lua):
--   * the page: the title and portrait while it is up, the roster read from
--     the game (offline members only with Show Offline, hidden fields,
--     Ambiguate), the two counts, the message of the day, the two views
--     (columns, labels, text colours), sorting (rank by index, last online,
--     level as a number, ties A to Z even reversed, the server asked too),
--     the view toggle's tooltip (EraUI's own) and its reset of a sort the
--     new view lacks, Show Offline, the foot's buttons;
--   * the member box: its rules (yourself, permissions, online, the guild
--     leader), its height, the notes' texts and hint, the right-click menu;
--   * the Guild tab: greyed and dead outside a guild, back after the game's
--     guild events (and 1 s and 4 s later);
--   * Squirt's answers: no key binding anywhere; the game's ToggleGuildFrame
--     post-hooked, never replaced (the guild key opens the social window on
--     the Guild page, the micro button opens and closes it on its own page,
--     never twice in one frame, the game's guild window closed at once, a
--     fight booked and done after it); the Communities tab and Guild
--     Information open the game's own guild window;
--   * the hidden guild window for notes: only when a note may be written,
--     never in a fight or over the player's own guild window, parked off the
--     screen, put back exactly, guildGhost only while open; the secure
--     overlays (rows, notes, message of the day), hidden as a fight starts;
--     the game's member box docked in the member box's place and given back.
-- The game's objects are sealed, GameTooltip and MouseIsOver don't exist,
-- every key binding call fails, and an error handed to the game's error
-- handler fails the run.
-- Run with: fengari Tools/TestGuild.lua (from the addon folder).
local Mock = dofile("Tools/SocialMockGame.lua")
local checks = 0
local function Whole(value)
    if type(value) ~= "string" then return value end
    return (value:gsub("(%d+)%.0+%f[%D]", "%1"))
end
local function Equal(actual, expected, label)
    checks = checks + 1
    actual = Whole(actual)
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function NoErrors(game, label)
    Equal(table.concat(game.errors, " || "), "", label .. ": no error handed to the game's error handler")
end
local function Point(obj, i) return { obj:GetPoint(i or 1) } end

local function Member(name, rank, rankIndex, level, class, zone, online, file, guid, extra)
    local m = { name = name, rank = rank, rankIndex = rankIndex, level = level, class = class, zone = zone, note = "",
        officerNote = "", online = online, status = 0, classFile = file, guid = guid }
    for k, v in pairs(extra or {}) do m[k] = v end
    return m
end

local function Game(options)
    local game = Mock.New(options)
    game.roster = {
        Member("Zriel Gustbellow", "Officer", 1, 60, "Druid", "Moonglade", true, "DRUID", "Player-4-0001"),
        Member("Coww Stagkiller", "Member", 3, 60, "Hunter", "Ironforge", true, "HUNTER", "Player-4-0002", { note = "tank" }),
        Member("abel Ashwood-Realm", "Member", 3, 9, "Mage", "Darnassus", false, "MAGE", "Player-4-0003",
            { ago = { 0, 0, 3, 0 } }),
        Member("Bram Oakes", "Guild Master", 0, 12, "Mage", "Elwynn", true, "MAGE", "Player-4-0004"),
    }
    return game
end

local game = Game()
local S = game.Load()
local env, G = game.env, S.guild
local parts = G.parts
local f = game.friends
game.Pass()

---------------------------------------------------------------------------
-- 1. The page
---------------------------------------------------------------------------
Equal(game.ns.OpenGuildRoster(), true, "the Guild page opens")
local page = env.EraUIClassicGuildPanel
Equal(env.FriendsFrame:IsShown() and page:IsShown(), true, "the social window with the Guild page")
Equal(f.title:GetText(), "Unwashed of Filth", "the title: Rank of Guild")
Equal(game.State(f.icon).file, "Interface\\FriendsFrame\\FriendsFrameScrollIcon", "the portrait: the guild scroll")
Equal(game.tabLook[env.EraUIClassicGuildTab], "selected", "the Guild tab looks chosen")
local label = env.EraUIClassicGuildTab.Text
local c = game.State(label).textColour
Equal(c[1] .. c[2] .. c[3], "111", "its text white while the page shows")
Equal(game.guildCalls[1], "roster", "the server is asked for the roster as the page shows")
local function Names()
    local out = {}
    for _, row in ipairs(parts.rows) do
        if row:IsShown() then out[#out + 1] = G.rowEntry[row].name end
    end
    return table.concat(out, ",")
end
Equal(Names(), "Bram Oakes,Coww Stagkiller,Zriel Gustbellow", "online members only, by name")
Equal(parts.members:GetText() .. " " .. parts.online:GetText(), "4 Guild Members (3 Online)", "the counts")
Equal(parts.motd:GetText(), "Raid at eight", "the message of the day")
Equal(parts.motdHeading:GetText(), "Guild Message Of The Day:", "its heading (enUS)")
Equal(parts.offline:GetChecked(), false, "Show Offline follows the game")
local tl = Point(parts.offline)
Equal(tl[1] .. tl[3] .. tl[4] .. "," .. tl[5], "TOPRIGHTTOPRIGHT0,30", "the pill above the page's top-right")
-- Show Offline: the game's switch, the server asked, the list refreshed.
parts.offline:Click()
Equal(game.showOffline, true, "Show Offline sets the game's switch")
Equal(game.guildCalls[#game.guildCalls], "roster", "and asks the server again")
Equal(Names(), "abel Ashwood,Bram Oakes,Coww Stagkiller,Zriel Gustbellow", "offline members listed, names shortened")
Equal(game.ambiguated, "guild", "through Ambiguate(name, \"guild\")")
-- Colours, player view: online name gold, middle white, class coloured;
-- offline all grey.
local function TextOf(name, col)
    for _, row in ipairs(parts.rows) do
        if row:IsShown() and G.rowEntry[row].name == name then return S.rowParts[row].texts[col] end
    end
end
local function Colour(text) local cc = game.State(text).textColour; return cc[1] .. "," .. cc[2] .. "," .. cc[3] end
Equal(Colour(TextOf("Coww Stagkiller", 1)), "1,0.82,0", "an online name in gold")
Equal(Colour(TextOf("Coww Stagkiller", 2)), "1,1,1", "its zone white")
Equal(Colour(TextOf("Coww Stagkiller", 4)), "0.67,0.83,0.45", "its class in the class colour")
for col = 1, 4 do Equal(Colour(TextOf("abel Ashwood", col)), "0.5,0.5,0.5", "offline: text " .. col .. " grey") end
Equal(game.State(TextOf("abel Ashwood", 2)).text, "Darnassus", "player view: the zone")

-- Sorting.
local function Header(i) parts.headers[i]:Click() end
Header(3)
Equal(Names(), "abel Ashwood,Bram Oakes,Coww Stagkiller,Zriel Gustbellow", "level as a number (9, 12, 60, 60), ties by name")
Equal(game.guildCalls[#game.guildCalls], "sort level", "the server's order asked too")
Header(3)
Equal(Names(), "Coww Stagkiller,Zriel Gustbellow,Bram Oakes,abel Ashwood", "reversed: ties still A to Z")
-- The status view.
local toggle = parts.viewToggle
game.Enter(toggle)
Equal(game.TipText(), "Player Status", "the view toggle's tooltip (EraUI's own): Player Status")
toggle:Click()
Equal(game.TipText(), "Guild Status", "it follows the view at once")
game.Leave(toggle)
local labels = {}
for i = 1, 4 do labels[i] = parts.headers[i]:GetText() .. "/" .. parts.headers[i]:GetWidth() end
Equal(table.concat(labels, ","), "Name/96,Rank/80,Note/84,Last Online/74", "the status view's columns")
Equal(Names(), "abel Ashwood,Bram Oakes,Coww Stagkiller,Zriel Gustbellow", "sorted by level before, a column it lacks: back to the name")
Equal(game.State(TextOf("Coww Stagkiller", 3)).text .. "|" .. game.State(TextOf("Coww Stagkiller", 4)).text, "tank|Online",
    "the note and Online")
Equal(game.State(TextOf("abel Ashwood", 4)).text, "3 days", "last online: the first span above 0")
Equal(Colour(TextOf("Coww Stagkiller", 4)), "1,1,1", "the fourth text white in this view")
local tp = Point(S.rowParts[parts.rows[1]].texts[3])
Equal(tp[4] .. "," .. game.State(S.rowParts[parts.rows[1]].texts[3]).width, "180,84", "the rows' texts moved to the new columns")
Header(2)
Equal(Names(), "Bram Oakes,Zriel Gustbellow,abel Ashwood,Coww Stagkiller", "rank by its index (0, 1, 3, 3), ties by name in lower case")
Header(4)
Equal(Names(), "Bram Oakes,Coww Stagkiller,Zriel Gustbellow,abel Ashwood", "last online: online first")
Equal(game.guildCalls[#game.guildCalls], "sort lastOnline", "a sort the server doesn't know is still asked (quietly)")
toggle:Click()
Equal(parts.headers[2]:GetText(), "Zone", "back to the player view")
Equal(Names(), "abel Ashwood,Bram Oakes,Coww Stagkiller,Zriel Gustbellow", "its sort reset to the name")
-- Hidden fields: a hidden name skips the member, a hidden online flag is offline.
game.roster[5] = Member(Mock.SECRET, "Member", 3, 5, "Rogue", "Elwynn", true, "ROGUE", "Player-4-0005")
game.roster[6] = Member("Hidden Bits", Mock.SECRET, Mock.SECRET, Mock.SECRET, Mock.SECRET, Mock.SECRET, Mock.SECRET,
    Mock.SECRET, Mock.SECRET)
game.showOffline = false
G.Refresh()
Equal(Names(), "Bram Oakes,Coww Stagkiller,Zriel Gustbellow", "a hidden name skipped; hidden online counts as offline")
game.showOffline = true
G.Refresh()
Equal(Names(), "abel Ashwood,Bram Oakes,Coww Stagkiller,Hidden Bits,Zriel Gustbellow", "shown with Show Offline, fields read as missing")
game.roster[5], game.roster[6] = nil, nil
game.showOffline = false
G.Refresh()
-- The foot: Add Member (with the guild's club), Guild Control for the leader.
Equal(parts.addMember:IsEnabled() and not parts.guildControl:IsEnabled(), true, "Add Member enabled, Guild Control only for the leader")
parts.addMember:Click()
local popup = game.popups[#game.popups]
Equal(popup[1] .. "|" .. tostring(popup[4] and popup[4].clubId), "ADD_GUILDMEMBER|club-7", "Add Member: the game's pop-up, the guild's club")
game.Fight(true)
parts.addMember:Click()
Equal(#game.popups .. game.messages[#game.messages][1], "1You can't do that while in combat", "not in a fight")
game.Fight(false)
-- The message of the day in a fight: the last one read.
game.motd = "Changed"
game.Fight(true)
G.Refresh()
Equal(parts.motd:GetText(), "Raid at eight", "in a fight: the last message read")
game.Fight(false)
Equal(parts.motd:GetText(), "Changed", "after the fight: read again")
NoErrors(game, "the page")

---------------------------------------------------------------------------
-- 2. The member box and the menu
---------------------------------------------------------------------------
local box = G.memberParts
local function Row(name)
    for _, row in ipairs(parts.rows) do
        if row:IsShown() and G.rowEntry[row].name == name then return row end
    end
end
Row("Coww Stagkiller"):Click("LeftButton")
Equal(box.frame:IsShown(), true, "a left click opens the member box")
Equal(game.guildCalls[#game.guildCalls], "select " .. G.rowEntry[Row("Coww Stagkiller")].index, "the game's roster selection set")
local bp = Point(box.frame)
Equal(bp[1] .. ":" .. tostring(bp[2] == env.FriendsFrame) .. ":" .. bp[3] .. ":" .. bp[4] .. "," .. bp[5], "TOPLEFT:true:TOPRIGHT:-6,-70",
    "to the window's right")
Equal(box.title:GetText() .. "|" .. box.level:GetText() .. "|" .. box.zone:GetText() .. "|" .. box.rank:GetText() .. "|" .. box.last:GetText(),
    "Coww Stagkiller|Level 60 Hunter|Ironforge|Member|Online", "name, level and class, zone, rank, last online")
Equal(box.frame:GetHeight(), 216, "216 tall (no officer note, not the leader)")
Equal(box.officer:IsShown(), false, "no officer note while you may not see it")
Equal(box.promote:IsEnabled() and box.demote:IsEnabled() and box.remove:IsEnabled() and box.invite:IsEnabled(), true,
    "rank, remove and invite work on a guildmate")
Equal(box.leader:IsShown(), false, "Promote to Guild Master only for the leader")
Equal(box.noteText:GetText(), "tank", "their note")
game.Enter(box.note)
Equal(game.TipText(), nil, "no note hint while you may not write it")
game.Leave(box.note)
box.promote:Click()
box.remove:Click()
Equal(game.guildCalls[#game.guildCalls - 1] .. "|" .. game.guildCalls[#game.guildCalls], "promote Coww Stagkiller|remove Coww Stagkiller",
    "the arrows and Remove act on the member")
-- The guild leader with officer notes.
game.may.leader, game.may.viewOfficer, game.may.officerNote = true, true, true
G.UpdateMember()
Equal(box.frame:GetHeight(), 216 + 60 + 26, "+60 with the officer note, +26 for the leader")
Equal(box.officer:IsShown() and box.leader:IsShown() and box.leader:IsEnabled(), true, "the officer note and Guild Master shown")
-- Yourself.
Row("Zriel Gustbellow"):Click("LeftButton")
Equal(box.promote:IsEnabled() or box.demote:IsEnabled() or box.remove:IsEnabled() or box.invite:IsEnabled() or box.leader:IsEnabled(),
    false, "nothing to do to yourself")
Equal(G.NoteMayEdit("note"), true, "but your own note is yours to write")
game.Enter(box.note)
Equal(game.TipText(), "Note: | Out of combat, click the member in the list, then click here to write the note.", "the note hint (EraUI's own)")
game.Leave(box.note)
-- An offline member: no invite, no Guild Master.
game.showOffline = true
G.Refresh()
Row("abel Ashwood"):Click("LeftButton")
Equal(box.invite:IsEnabled() or box.leader:IsEnabled(), false, "an offline member: no invite, no Guild Master")
Equal(box.remove:IsEnabled(), true, "but Remove")
game.Run(Row("abel Ashwood"), "OnDoubleClick")
Equal(game.chatBox, nil, "no whisper to an offline member")
-- The menu: on yourself only Cancel; on a guildmate what you may do.
Row("Zriel Gustbellow"):Click("RightButton")
local function Offered()
    local out = {}
    for i, item in ipairs(G.menu.items) do
        if G.menu.buttons[i]:IsShown() then out[#out + 1] = item.text end
    end
    return table.concat(out, ",")
end
Equal(Offered(), "Cancel", "on your own line only Cancel")
Equal(game.State(G.menu.frame).shown and G.menu.entry.name, "Zriel Gustbellow", "the menu titled with your name")
G.menu.Close()
Row("abel Ashwood"):Click("RightButton")
Equal(Offered(), "Add Friend,Promote,Demote,Remove,Cancel", "an offline guildmate: no whisper or invite")
G.menu.Close()
game.may.promote, game.may.remove = false, false
Row("Coww Stagkiller"):Click("RightButton")
Equal(Offered(), "Whisper,Invite,Add Friend,Demote,Cancel", "only what you may do")
G.menu.buttons[2]:Click()
Equal(game.invites[#game.invites], "Coww Stagkiller", "Invite invites")
game.may.promote, game.may.remove = true, true
game.showOffline = false
G.Refresh()
NoErrors(game, "the member box")

---------------------------------------------------------------------------
-- 3. The Guild tab outside a guild
---------------------------------------------------------------------------
game.inGuild = false
game.Fire("PLAYER_GUILD_UPDATE")
local tab = env.EraUIClassicGuildTab
Equal(page:IsShown(), false, "out of a guild: the page goes")
Equal(tab:IsEnabled(), false, "the tab is greyed and dead")
c = game.State(tab.Text).textColour
Equal(c[1] .. c[2] .. c[3], "0.50.50.5", "its text grey")
Equal(game.ns.OpenGuildRoster() and page:IsShown(), false, "nor can the page be opened")
game.inGuild = true
game.Tick(1.1)
Equal(tab:IsEnabled(), true, "the guild comes back: the tab works again (the 1 s look)")
c = game.State(tab.Text).textColour
Equal(c[1] .. c[2] .. c[3], "10.820", "gold while its page is shut")
game.inGuild = false
game.Fire("GUILD_ROSTER_UPDATE")
game.inGuild = true
game.Tick(3.5)
Equal(tab:IsEnabled(), true, "and again 4 s after the event (guild state arrives late)")
NoErrors(game, "the Guild tab")

---------------------------------------------------------------------------
-- 4. Squirt's answers: the guild key and micro button through a post-hook
---------------------------------------------------------------------------
env.HideUIPanel(env.FriendsFrame)
-- (No note to write here, so the hidden guild window of section 5 stays shut.)
game.may.officerNote, game.may.publicNote = false, false
local micro = env.GuildMicroButton
Equal(game.hookCounts[env] and game.hookCounts[env].ToggleGuildFrame, 1, "the game's ToggleGuildFrame is post-hooked once")
local calls = game.toggleGuildCalls or 0
local communities = game.communities.frame
local function Key() game.NextFrame(); game.Secure(env.ToggleGuildFrame) end
local function MicroClick() game.NextFrame(); game.Secure(function() micro:Click("LeftButton") end) end
local shows = 0
game.Run(env.FriendsFrame, "OnLoad")
env.FriendsFrame:HookScript("OnShow", function() shows = shows + 1 end)
Key()
Equal(game.toggleGuildCalls, calls + 1, "the game's own ToggleGuildFrame still runs (never replaced)")
Equal(communities:IsShown(), false, "the game's guild window closed again at once")
Equal(env.FriendsFrame:IsShown() and page:IsShown(), true, "the guild key: the social window on the Guild page")
Key()
Equal(env.FriendsFrame:IsShown(), false, "again: closed")
MicroClick()
Equal(env.FriendsFrame:IsShown() and not page:IsShown(), true, "the micro button: the social window on its own page")
Equal(shows, 2, "opened once per press, never twice in one frame")
Equal(communities:IsShown(), false, "the game's guild window closed")
MicroClick()
Equal(env.FriendsFrame:IsShown(), false, "the micro button closes it again")
local follows
for _, entry in ipairs(game.follows) do
    if entry.entry == micro then follows = entry.isShown end
end
Equal(follows ~= nil, true, "the micro button's pressed look follows the social window")
env.ShowUIPanel(env.FriendsFrame)
Equal(follows(), true, "pressed while it shows")
env.HideUIPanel(env.FriendsFrame)
-- Quick keybind mode: the micro button is the game's alone.
game.quickBind = true
MicroClick()
Equal(env.FriendsFrame:IsShown() or communities:IsShown(), false, "quick keybind mode: nothing opens")
game.quickBind = false
-- In a fight: nothing shown or hidden; after it, the Guild page.
game.Fight(true)
Key()
Equal(communities:IsShown() and not env.FriendsFrame:IsShown(), true, "in a fight: the game's guild window stays")
Equal(#game.blocked, 0, "nothing blocked")
game.Fight(false)
Equal(communities:IsShown(), false, "after the fight: the game's window closed")
Equal(env.FriendsFrame:IsShown() and page:IsShown(), true, "and the Guild page instead")
env.HideUIPanel(env.FriendsFrame)
game.Fight(true)
MicroClick()
game.Fight(false)
Equal(env.FriendsFrame:IsShown() and not page:IsShown(), true, "the micro button in a fight: its own page after it")
env.HideUIPanel(env.FriendsFrame)
game.Fight(true)
Key()
game.Secure(env.HideUIPanel, communities)
game.Fight(false)
Equal(env.FriendsFrame:IsShown(), false, "the game's window closed in the fight: nothing opens after it")
-- The Communities tab and Guild Information: the game's own guild window.
game.ns.OpenGuildRoster()
env.EraUIClassicCommunitiesTab:Click()
Equal(communities:IsShown() and not env.FriendsFrame:IsShown(), true, "the Communities tab: the game's guild window, not redirected")
env.HideUIPanel(communities)
game.ns.OpenGuildRoster()
game.Fight(true)
env.EraUIClassicCommunitiesTab:Click()
Equal(game.messages[#game.messages][1] .. tostring(env.FriendsFrame:IsShown()), "You can't do that while in combattrue",
    "in a fight: the red line, nothing else")
game.Fight(false)
parts.guildInfo:Click()
Equal(communities:IsShown(), true, "Guild Information: the game's guild window")
env.HideUIPanel(communities)
-- The named click target (a /click macro).
env.HideUIPanel(env.FriendsFrame)
env.EraUIClassicGuildBind:Click()
Equal(env.FriendsFrame:IsShown() and page:IsShown(), true, "EraUIClassicGuildBind opens the Guild page")
env.EraUIClassicGuildBind:Click()
Equal(env.FriendsFrame:IsShown(), false, "and closes it")
Equal(micro.tooltipText, "Guild & Communities (J)", "the micro button's own tooltip text untouched")
NoErrors(game, "the openers")

---------------------------------------------------------------------------
-- 5. The hidden guild window for notes, and the overlays
---------------------------------------------------------------------------
local N = S.notes
game.may.publicNote, game.may.officerNote = false, false
game.ns.OpenGuildRoster()
Row("Coww Stagkiller"):Click("LeftButton")
game.Tick(0.3)
Equal(N.open or communities:IsShown(), false, "no note to write: the guild window stays shut")
Equal(game.ns.guildGhost or false, false, "guildGhost off")
-- Your own line: your own note may be written.
local rowFor = {}
for _, m in ipairs(game.roster) do rowFor[m.guid] = game.MemberRow(m.guid) end
game.Seal()
Row("Zriel Gustbellow"):Click("LeftButton")
Equal(N.open and communities:IsShown(), true, "your own note: the guild window opens, hidden")
Equal(game.ns.guildGhost, true, "guildGhost on")
Equal(communities:GetAlpha() .. "|" .. communities:GetAttribute("UIPanelLayout-width"), "0|1", "invisible, taking no room")
Equal(communities:GetHeight(), 91 + (3 + 12) * 20, "tall enough for every listed member")
local park = Point(communities)
Equal(park[1] .. ":" .. tostring(park[2] == env.UIParent) .. ":" .. park[3] .. ":" .. park[4] .. "," .. park[5], "TOPLEFT:true:TOPRIGHT:4000,0",
    "parked far off the screen")
Equal(game.cvarWrites[#game.cvarWrites][1] .. "=" .. game.cvarWrites[#game.cvarWrites][2], "lastSelectedClubId=club-7", "on the guild")
communities:ClearAllPoints()
communities:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
game.Tick(0.05)
park = Point(communities)
Equal(park[1] .. park[4], "TOPLEFT4000", "parked again when something moves it")
-- The row overlays: one over each row with a game row, clicking it.
game.Tick(0.3)
local myRow = Row("Zriel Gustbellow")
local index
for i, row in ipairs(parts.rows) do if row == myRow then index = i end end
local overlay = env["EraUIClassicGuildRowPad" .. index]
Equal(overlay and overlay:IsShown(), true, "a secure overlay over your row")
Equal(overlay:GetAttribute("type1") .. "|" .. tostring(overlay:GetAttribute("clickbutton") == rowFor["Player-4-0001"]),
    "click|true", "clicking the game's own member row")
Equal(overlay:GetFrameStrata(), "HIGH", "above the window")
local rl, rb = game.Rect(myRow)
local ol, ob = game.Rect(overlay)
Equal(math.floor(ol + 0.5) .. "," .. math.floor(ob + 0.5), math.floor(rl + 0.5) .. "," .. math.floor(rb + 0.5), "laid exactly over the row")
-- Its release: the game's row was clicked through it; EraUI's row logic follows.
rowFor["Player-4-0001"]:Click("LeftButton")
game.Run(overlay, "PostClick", "LeftButton", false)
game.Tick(0.3)
local detail = game.communities.detail
Equal(N.live and detail:GetParent() == env.UIParent and detail:IsShown(), true, "the game's member box docked: notes are live")
local dp = Point(detail)
Equal(dp[1] .. ":" .. tostring(dp[2] == env.FriendsFrame) .. ":" .. dp[3] .. ":" .. dp[4] .. "," .. dp[5], "TOPLEFT:true:TOPRIGHT:-6,-70",
    "in the member box's place")
Equal(detail:GetFrameStrata() .. "|" .. detail:GetAlpha(), "HIGH|1", "on top, seen")
Equal(box.frame:IsShown(), false, "EraUI's member box out of the way")
Equal(game.State(detail.Border.Bg).desaturated == true, false, "its border's background kept")
-- A guildmate without permission: the member box back, the game's given back.
Row("Coww Stagkiller"):Click("LeftButton")
game.Tick(0.3)
Equal(N.open, false, "no note to write any more: the hidden window put away")
Equal(detail:GetParent() == communities and detail:GetFrameLevel(), 1000, "the game's member box given back")
Equal(communities:IsShown(), false, "the guild window closed")
Equal(communities:GetAlpha() .. "|" .. communities:GetAttribute("UIPanelLayout-width") .. "|" .. communities:GetHeight(), "1|800|500",
    "its alpha, layout width and size put back exactly")
Equal(game.ns.guildGhost, false, "guildGhost off again")
Equal(overlay:IsShown(), false, "the overlays hidden")
-- Officer notes: the note overlays over the member box's note boxes.
game.may.publicNote = true
game.Tick(0.3)
Equal(N.open, true, "public notes may be written: open again")
local notePad = env.EraUIClassicGuildNotePad
Equal(notePad and notePad:IsShown() and notePad:GetAttribute("clickbutton") == rowFor["Player-4-0002"], true,
    "the note overlay over the note box, clicking the member's game row")
Equal(box.noteText:GetText(), "tank", "their note")
game.Enter(box.note)
Equal(game.TipText() ~= nil, true, "the note hint shows (you may write it)")
game.Leave(box.note)
-- A fight: the overlays go as it starts; nothing opens or closes in it.
game.Fight(true)
Equal(overlay:IsShown() or notePad:IsShown(), false, "the overlays hidden as the fight starts")
game.may.publicNote = false
game.Tick(0.3)
Equal(N.open, true, "nothing put away in a fight")
game.Fight(false)
game.Tick(0.3)
Equal(N.open, false, "put away after it")
game.Fight(true)
game.may.publicNote = true
game.Tick(0.3)
Equal(N.open or communities:IsShown(), false, "never opened in a fight")
game.may.publicNote = false
game.Fight(false)
game.Tick(0.3)
-- Never over a guild window the player has open.
game.Secure(env.ShowUIPanel, communities)
Row("Zriel Gustbellow"):Click("LeftButton")
game.Tick(0.3)
Equal(N.open, false, "the player's own guild window: not taken over")
Equal(communities:GetAlpha(), 1, "and left as it is")
game.Secure(env.HideUIPanel, communities)
-- The page hiding puts it away too.
game.Tick(0.3)
Equal(N.open, true, "your note again: open")
env.HideUIPanel(env.FriendsFrame)
Equal(N.open or communities:IsShown(), false, "the window closing puts it away")
-- The message of the day's overlay.
game.may.motd = true
game.ns.OpenGuildRoster()
game.Tick(0.25)
local motdPad = env.EraUIClassicMotdPad
Equal(motdPad and motdPad:IsShown() and motdPad:GetAttribute("type") == "click", true, "the message overlay while you may edit it")
Equal(motdPad:GetAttribute("clickbutton"), game.communities.editMotd, "clicking the game's own message editor")
game.may.motd = false
game.Tick(0.25)
Equal(motdPad:IsShown(), false, "hidden when you may not")
NoErrors(game, "the notes")

---------------------------------------------------------------------------
-- 6. Restore after the page was on
---------------------------------------------------------------------------
game.ns.db.guildRoster = false
game.Pass()
Equal(env.EraUIClassicGuildTab:IsShown() or env.EraUIClassicCommunitiesTab:IsShown(), false, "off: the Guild and Communities tabs go")
Equal(page:IsShown(), false, "and the page")
local calls2 = game.toggleGuildCalls
Key()
Equal(communities:IsShown() and game.toggleGuildCalls == calls2 + 1, true, "the guild key: the game's own guild window again")
NoErrors(game, "restore")

print("Guild checks passed: " .. checks .. " assertions.")
