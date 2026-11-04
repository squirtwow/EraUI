-- The social area's clean-room rewrite (Look/Social*.lua, Who*.lua,
-- Finder*.lua, 2026-10-21) on the social mock (Tools/SocialMockGame.lua):
--   * the registry, its defaults and a restore that touches nothing of the
--     game's when the area never came on;
--   * the social window: the tab row (Friends, Who, Guild, Communities, then
--     the game's), each tab fitted to its text + 38, the chrome's lift; the
--     game's pages and everything else on the window swept aside while a page
--     is up, and back after (mouse included, after a fight too); the title;
--   * the Who page: reading (hidden fields and counts), sorting (every
--     column, the second column's field, ties, reversing), the column drop
--     down saving whoColumn, selection, the menu, whisper, searching and
--     where /who results land, the side tabs following whoTabs (the arrow
--     saving it, its art, its tooltip), the secure pads;
--   * the group finder: the size rule, the window layout width, the game's
--     tabs, EraUI's side tabs, the two pages' dressing, warming, restore.
-- The game's objects are sealed (a key written on one fails), GameTooltip
-- and MouseIsOver don't exist, every key binding call fails, and an error
-- handed to the game's error handler fails the run.
-- Run with: fengari Tools/TestSocial.lua (from the addon folder).
local Mock = dofile("Tools/SocialMockGame.lua")
local checks = 0
-- Whole numbers joined into text read the same on Lua 5.1 and 5.3 ("3", not "3.0").
local function Whole(value)
    if type(value) ~= "string" then return value end
    return (value:gsub("(%d+)%.0+%f[%D]", "%1"))
end
local function Equal(actual, expected, label)
    checks = checks + 1
    actual = Whole(actual)
    if actual ~= expected then error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2) end
end
local function Near(actual, expected, label)
    checks = checks + 1
    if type(actual) ~= "number" or math.abs(actual - expected) > 0.01 then
        error(label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function NoErrors(game, label)
    Equal(table.concat(game.errors, " || "), "", label .. ": no error handed to the game's error handler")
end

local function Who(name, guild, zone, level, class, file, race)
    return { fullName = name, fullGuildName = guild, area = zone, level = level, classStr = class, filename = file,
        raceStr = race }
end

local function Game(options)
    local game = Mock.New(options)
    game.who = {
        Who("Coww Stagkiller", "Filth", "Ironforge", 60, "Hunter", "HUNTER", "Dwarf"),
        Who("abel Ashwood", "", "Darnassus", 10, "Mage", "MAGE", "Night Elf"),
        Who("Zriel Gustbellow", "Filth", "Moonglade", 2, "Druid", "DRUID", "Night Elf"),
    }
    return game
end

local function Point(obj, i)
    return { obj:GetPoint(i or 1) }
end

---------------------------------------------------------------------------
-- 1. The registry, defaults, and a restore that never touches the game
---------------------------------------------------------------------------
do
    local game = Mock.New({ db = { whoList = false, guildRoster = false, groupFinder = false } })
    local S = game.Load()
    local keys = {}
    for _, module in ipairs(game.ns.modules) do keys[#keys + 1] = module.key end
    Equal(table.concat(keys, ","), "guildRoster,whoList,groupFinder", "the registry entries, in the old order")
    local d = game.ns.DB_DEFAULTS
    Equal(tostring(d.whoList) .. tostring(d.guildRoster) .. tostring(d.whoTabs) .. tostring(d.whoColumn) .. tostring(d.groupFinder),
        "truetruefalsezonenil", "defaults: whoList, guildRoster on, whoTabs off, whoColumn zone, groupFinder none")
    local tab1 = game.env.FriendsFrameTab1
    local before = Point(tab1)
    local width = tab1:GetWidth()
    game.Pass()
    game.Pass()
    local after = Point(tab1)
    Equal(after[1] .. after[3] .. after[4] .. after[5], before[1] .. before[3] .. before[4] .. before[5],
        "off from login: the game's Friends tab is never re-anchored")
    Equal(tab1:GetWidth(), width, "nor refitted")
    Equal(tab1:GetText(), "Contacts", "nor renamed")
    Equal(#game.skinnedTabs + #game.chromeFits, 0, "no tab skinned or fitted at all")
    Equal(game.env.EraUIClassicWhoPanel == nil and game.env.EraUIClassicGuildPanel == nil, true, "no page built")
    local hooked = 0
    for _ in pairs(game.hookCounts) do hooked = hooked + 1 end
    Equal(hooked, 0, "nothing of the game's post-hooked")
    Equal(game.ns.needsReload, true, "the group finder's restore asks for a reload")
    Equal(game.ns.OpenWhoList(), false, "the Who page won't open while off")
    Equal(game.ns.OpenGuildRoster(), false, "nor the Guild page")
    NoErrors(game, "off from login")
end

---------------------------------------------------------------------------
-- 2. The tab row
---------------------------------------------------------------------------
do
    local game = Game()
    local S = game.Load()
    local env = game.env
    game.Pass()
    local tab1, tab3, tab4 = env.FriendsFrameTab1, env.FriendsFrameTab3, env.FriendsFrameTab4
    local who, guild, comm = env.EraUIClassicWhoTab, env.EraUIClassicGuildTab, env.EraUIClassicCommunitiesTab
    Equal(who and guild and comm and true, true, "the Who, Guild and Communities tabs are made")
    Equal(who:GetID() .. "," .. guild:GetID() .. "," .. comm:GetID(), "91,90,92", "with their IDs")
    Equal(who:GetParent() ~= env.FriendsFrame and who:GetParent():GetName(), "EraUIClassicSocialTabs",
        "on a holder of EraUI's own (the window's own tab list is never added to)")
    Equal(tab1:GetText(), "Friends", "the game's Friends tab is called Friends")
    local skinned = {}
    for _, tab in ipairs(game.skinnedTabs) do skinned[tab] = true end
    Equal(skinned[who] and skinned[guild] and skinned[comm], true, "EraUI's tabs wear the chrome's tab art")
    -- Row order and places: Friends first at the window's foot (lifted 3 by
    -- the chrome's fitter), then each just right of the last.
    local p = Point(tab1)
    Equal(p[1] .. ":" .. tostring(p[2] == env.FriendsFrame) .. ":" .. p[3], "TOPLEFT:true:BOTTOMLEFT", "Friends at the window's bottom-left")
    Equal(p[4] .. "," .. p[5], "5,5", "at (5, 2), lifted 3 by the chrome")
    local gap = 3 -- Tab3 sat 3 right of Tab1 when the row was first laid (measured once)
    local order = { tab1, who, guild, comm, tab3, tab4 }
    for i = 2, #order do
        local q = Point(order[i])
        Equal(q[1] .. ":" .. tostring(q[2] == order[i - 1]) .. ":" .. q[3] .. ":" .. q[4],
            "BOTTOMLEFT:true:BOTTOMRIGHT:" .. gap, "tab " .. i .. " sits just right of the one before")
    end
    -- Each fitted to its text (6 a letter on the mock) + 38, middles 40 less.
    Equal(tab1:GetWidth(), #"Friends" * 6 + 38, "Friends: its text + 38")
    Equal(who:GetWidth(), #"Who" * 6 + 38, "Who: its text + 38")
    Equal(game.State(who.Middle).width, #"Who" * 6 + 38 - 40, "its middle 40 less")
    -- The game's own resize brings the chrome's width back; the 38 is put back.
    env.PanelTemplates_TabResize(tab4, 0)
    Equal(tab4:GetWidth(), #"Quick Join" * 6 + 38, "after the game's resize: still text + 38")
    -- A hidden tab leaves no gap.
    tab3:Hide()
    game.ns.PlaceSocialTabs()
    local q = Point(tab4)
    Equal(tostring(q[2] == comm), "true", "Quick Join follows Communities while Raid is hidden")
    tab3:Show()
    -- EraUI's own tooltip on a tab whose text is cut (none here: no tip).
    game.Enter(who)
    Equal(game.TipText(), nil, "no tooltip on a tab whose text fits")
    game.Leave(who)
    NoErrors(game, "tab row")
end

---------------------------------------------------------------------------
-- 3. The Who page: the sweep, the title, reading and the rows
---------------------------------------------------------------------------
local game = Game()
local S = game.Load()
local env, W = game.env, S.who
local f = game.friends
game.Pass()
Equal(game.ns.OpenWhoList(), true, "the Who page opens")
local page = env.EraUIClassicWhoPanel
local parts = W.parts
Equal(env.FriendsFrame:IsShown() and page:IsShown(), true, "the social window with the Who page")
local tl, br = Point(page, 1), Point(page, 2)
Equal(table.concat({ tl[1], tl[4], tl[5], br[1], br[4], br[5] }, ","), "TOPLEFT,8,-64,BOTTOMRIGHT,-8,12", "the page's place")
Equal(page:GetFrameLevel(), env.FriendsFrame:GetFrameLevel() + 6, "6 levels above the window")
Equal(f.title:GetText(), "Who List", "the title reads Who List")
Equal(game.tabLook[env.EraUIClassicWhoTab], "selected", "the Who tab looks chosen")
Equal(game.tabLook[env.FriendsFrameTab1], "deselected", "the game's tabs don't")
-- The game's pages, the header and anything else on the window step aside.
Equal(f.list:GetAlpha() .. tostring(f.list:IsMouseEnabled()), "0false", "the friends list faded, the mouse off")
Equal(f.list:IsShown(), true, "never hidden (alpha only)")
Equal(f.header:GetAlpha(), 0, "the sub-tab header faded")
Equal(game.State(f.battle).mouse, false, "the header's buttons let go of the mouse")
Equal(f.addonBit:GetAlpha() .. tostring(f.addonBit:IsMouseEnabled()), "0false", "another addon's button on the window swept")
Equal(f.insetBit:GetAlpha(), 0, "and one on the inset")
Equal(env.FriendsFrameTab1:GetAlpha(), 1, "the game's tabs kept")
Equal(env.EraUIClassicSocialTabs:GetAlpha(), 1, "EraUI's own kept")
Equal(Point(f.inset)[5], -83, "the inset at its friends-list place (-83)")
-- Reading: three results, sorted by name (lower case).
Equal(parts.found:GetText(), "3 found", "the found text")
local function RowText(i, c) return Mock.Plain(game.State(S.rowParts[parts.rows[i]].texts[c]).text) end
local function Names()
    local out = {}
    for i = 1, 3 do out[#out + 1] = RowText(i, 1) end
    return table.concat(out, ",")
end
Equal(Names(), "abel Ashwood,Coww Stagkiller,Zriel Gustbellow", "sorted by name in lower case")
Equal(RowText(2, 2) .. "|" .. RowText(2, 3) .. "|" .. RowText(2, 4), "Ironforge|60|Hunter", "zone, level, class")
local tc = game.State(S.rowParts[parts.rows[2]].texts[1]).textColour
Equal(tc[1] .. "," .. tc[2] .. "," .. tc[3], "1,0.82,0", "the name in gold")
tc = game.State(S.rowParts[parts.rows[2]].texts[4]).textColour
Equal(tc[1] .. "," .. tc[2] .. "," .. tc[3], "0.67,0.83,0.45", "the class in its colour")
Equal(parts.rows[4]:IsShown(), false, "rows past the results hidden")
Equal(parts.addFriend:IsEnabled() or parts.invite:IsEnabled(), false, "Add Friend and Group Invite need a selection")

-- Sorting: each column, the same column again reverses, ties by the name.
local function Header(i) parts.headers[i]:Click() end
Header(1)
Equal(Names(), "Zriel Gustbellow,Coww Stagkiller,abel Ashwood", "the name again: reversed")
Header(3)
Equal(Names(), "Zriel Gustbellow,abel Ashwood,Coww Stagkiller", "level, as a number (2, 10, 60)")
Header(3)
Equal(Names(), "Coww Stagkiller,abel Ashwood,Zriel Gustbellow", "level reversed")
Header(4)
Equal(Names(), "Zriel Gustbellow,Coww Stagkiller,abel Ashwood", "class (Druid, Hunter, Mage)")
Header(2)
Equal(Names(), "abel Ashwood,Coww Stagkiller,Zriel Gustbellow", "the second column: zone (Darnassus, Ironforge, Moonglade)")
-- Ties: the same zone for two falls back to the name, the same way round.
game.who[2].area = "Ironforge"
W.Refresh()
Equal(Names(), "abel Ashwood,Coww Stagkiller,Zriel Gustbellow", "equal zones: by name")
Header(2)
Equal(Names(), "Zriel Gustbellow,Coww Stagkiller,abel Ashwood", "reversed: ties reversed too")
game.who[2].area = "Darnassus"

-- The second column's drop down: Guild, saved, the header relabelled.
parts.columnDrop:Click()
local menu = W.columnMenu
Equal(menu and menu.IsShown(), true, "the column menu opens")
local labels = {}
for _, item in ipairs(menu.items) do labels[#labels + 1] = item.text end
Equal(table.concat(labels, ","), "Zone,Guild,Race,Cancel", "Zone, Guild, Race and Cancel")
menu.buttons[2]:Click()
Equal(game.ns.db.whoColumn, "guild", "Guild picked: whoColumn saved")
Equal(parts.headers[2]:GetText(), "Guild", "the header relabelled")
Equal(Names(), "abel Ashwood,Coww Stagkiller,Zriel Gustbellow", "sorted by guild ascending ('' first)")
Equal(RowText(2, 2), "Filth", "the second column shows the guild")
Equal(menu.IsShown(), false, "the menu closed")
-- A menu is made hidden, but placed and sized at once like every frame of
-- the look (and its items), before anything opens it.
local fresh = game.S.RowMenu({ { "One", function() end } })
Equal(fresh.frame:GetNumPoints() > 0 and fresh.buttons[1]:GetNumPoints() > 0 and fresh.buttons[2]:GetNumPoints() > 0,
    true, "a new menu and its items are anchored when made")
game.ns.db.whoColumn = "nonsense"
W.Refresh()
Equal(RowText(2, 2), "Ironforge", "an unknown whoColumn counts as zone")
game.ns.db.whoColumn = "race"
W.Refresh()
Equal(RowText(3, 2), "Night Elf", "race")
game.ns.db.whoColumn = "zone"
Header(1)
if Names() ~= "abel Ashwood,Coww Stagkiller,Zriel Gustbellow" then Header(1) end

-- Hidden fields and counts.
game.who[4] = Who(Mock.SECRET, "", "Elwynn", 5, "Rogue", "ROGUE", "Human")
game.who[5] = { fullName = "Hidden Fields", fullGuildName = Mock.SECRET, area = Mock.SECRET, level = Mock.SECRET,
    classStr = Mock.SECRET, filename = Mock.SECRET, raceStr = Mock.SECRET }
W.Refresh()
Equal(Names(), "abel Ashwood,Coww Stagkiller,Hidden Fields", "a hidden name is skipped, hidden fields read as missing")
local hiddenRow
for _, row in ipairs(parts.rows) do
    if W.rowEntry[row] and W.rowEntry[row].name == "Hidden Fields" then hiddenRow = row end
end
Equal(Mock.Plain(game.State(S.rowParts[hiddenRow].texts[3]).text), "0", "a hidden level is 0")
tc = game.State(S.rowParts[hiddenRow].texts[4]).textColour
Equal(tc[1] .. tc[2] .. tc[3], "111", "an unknown class in white")
Equal(parts.found:GetText(), "5 found", "the found text counts the server's total")
game.whoTotal = 50
W.Refresh()
Equal(parts.found:GetText(), "50 found", "the server's total when it gives one")
game.whoTotal = Mock.SECRET
W.Refresh()
Equal(parts.found:GetText(), "5 found", "a hidden total: the shown count")
game.whoCount, game.whoTotal = Mock.SECRET, nil
W.Refresh()
Equal(parts.found:GetText() .. "|" .. tostring(parts.rows[1]:IsShown()), "0 found|false", "a hidden count counts as 0")
game.whoCount = nil
game.who[4], game.who[5] = nil, nil
W.Refresh()

-- Selection (kept by name), the buttons, the menu, whisper.
local function RowOf(name)
    for _, row in ipairs(parts.rows) do
        if W.rowEntry[row] and W.rowEntry[row].name == name then return row end
    end
end
RowOf("Coww Stagkiller"):Click("LeftButton")
Equal(parts.addFriend:IsEnabled() and parts.invite:IsEnabled(), true, "a selection enables Add Friend and Group Invite")
Equal(game.State(S.rowParts[RowOf("Coww Stagkiller")].mark).shown, true, "the selected row shows its gold mark")
Header(1)
Equal(game.State(S.rowParts[RowOf("Coww Stagkiller")].mark).shown, true, "the selection follows the member after a re-sort")
Header(1)
parts.addFriend:Click()
parts.invite:Click()
Equal(game.friendsAdded[#game.friendsAdded] .. "|" .. game.invites[#game.invites], "Coww Stagkiller|Coww Stagkiller",
    "Add Friend and Group Invite act on the selected name")
RowOf("Zriel Gustbellow"):Click("RightButton")
Equal(W.menu == nil or not W.menu.IsShown(), true, "no menu on your own line")
RowOf("Coww Stagkiller"):Click("RightButton")
Equal(W.menu.IsShown() and game.Look.OwnPiece(W.menu.frame, "title"):GetText(), "Coww Stagkiller",
    "the menu on someone else's line, titled with the name")
Equal(W.menu.frame:GetFrameStrata(), "DIALOG", "a black panel on the dialog strata")
local shown = {}
for i, item in ipairs(W.menu.items) do
    if W.menu.buttons[i]:IsShown() then shown[#shown + 1] = item.text end
end
Equal(table.concat(shown, ","), "Whisper,Invite,Add Friend,Ignore,Cancel", "Whisper, Invite, Add Friend, Ignore, Cancel")
local mp = Point(W.menu.frame)
Equal(mp[1] .. mp[3] .. mp[4] .. "," .. mp[5], "TOPLEFTBOTTOMLEFT500,500", "at the cursor")
Equal(W.menu.frame:GetHeight(), 24 + 15 * 5, "24 + 15 a row tall")
W.menu.buttons[4]:Click()
Equal(game.ignored[#game.ignored], "Coww Stagkiller", "Ignore ignores the name")
Equal(W.menu.IsShown(), false, "and closes the menu")
-- An outside click closes it; the same row's click right after doesn't reopen it.
RowOf("Coww Stagkiller"):Click("RightButton")
game.Fire("GLOBAL_MOUSE_DOWN")
RowOf("Coww Stagkiller"):Click("RightButton")
Equal(W.menu.IsShown(), false, "closed by a click on its own row: stays closed")
game.Tick(0.5)
RowOf("Coww Stagkiller"):Click("RightButton")
Equal(W.menu.IsShown(), true, "a later right-click opens it again")
W.menu.Close()
-- Whisper: the chat box ready to type.
local box = { text = nil }
function box.SetText(_, text) box.text = text end
function box.Show() end
function box.SetFocus() box.focus = true end
function box.SetCursorPosition(_, n) box.cursor = n end
env.ChatFrameUtil = { ChooseBoxForSend = function() return box end, ActivateChat = function() end }
game.Run(RowOf("Coww Stagkiller"), "OnDoubleClick")
Equal(box.text .. "|" .. tostring(box.focus), "/w Coww Stagkiller |true", "a double-click whispers")

-- Searching and where results land.
local search = parts.search
search:SetText("Squirt")
game.Run(search, "OnTextChanged")
Equal(parts.searchClear:IsShown(), true, "the clear button shows while the box holds text")
game.whoToUi = false
game.Run(search, "OnEnterPressed")
Equal(game.sent[#game.sent], "Squirt|true", "Enter: results switched to the window first, then the search")
Equal(search:HasFocus(), false, "and the box lets go")
parts.refresh:Click()
Equal(game.sent[#game.sent], "Squirt|true", "Refresh searches with the box's text")
parts.searchClear:Click()
game.Run(search, "OnTextChanged")
Equal((search:GetText() or "") .. tostring(parts.searchClear:IsShown()), "false", "the clear button empties the box")
parts.refresh:Click()
Equal(game.sent[#game.sent], "|true", "Refresh with an empty box")
Equal(#game.sent, 3, "no search sent by EraUI on its own")
Equal(game.State(parts.searchBorder).backdrop.edgeFile, "Interface\\DialogFrame\\UI-DialogBox-Border", "the search line's border")
local darkBand = false
for _, entry in ipairs(game.darkened) do
    if entry[1] == "DarkBackdrop" and entry[2] == parts.searchBorder and entry[3] == false then darkBand = true end
end
Equal(darkBand, true, "handed to Dark Windows as a border with no fill")

-- Hiding: the game's pages, the swept pieces and the title come back.
env.HideUIPanel(env.FriendsFrame)
Equal(page:IsShown(), false, "the window closing hides the page")
Equal(game.whoToUi, false, "and hands /who back to chat")
Equal(f.list:GetAlpha() .. tostring(f.list:IsMouseEnabled()), "1true", "the friends list back, with its mouse")
Equal(f.header:GetAlpha(), 1, "the header back")
Equal(game.State(f.battle).mouse, true, "its buttons take the mouse again")
Equal(f.addonBit:GetAlpha() .. tostring(f.addonBit:IsMouseEnabled()), "1true", "the other addon's button back")
Equal(f.title:GetText(), "Contacts", "the title back for the game's page")
Equal(game.tabLook[env.FriendsFrameTab1], "selected", "the game's chosen tab looks chosen again")

-- A fight: the mouse is never touched; it is put right after the fight.
env.ShowUIPanel(env.FriendsFrame)
game.Fight(true)
W.Show()
Equal(f.list:GetAlpha() .. tostring(f.list:IsMouseEnabled()), "0true", "in a fight: faded, the mouse left alone")
game.Fight(false)
Equal(f.list:IsMouseEnabled(), false, "after the fight: the mouse off while the page is up")
Equal(f.addonBit:IsMouseEnabled(), true, "a swept piece's mouse waits for the next sweep")
game.Tick(0.3)
Equal(f.addonBit:IsMouseEnabled(), false, "and the keeper's sweep takes it")
game.Fight(true)
W.Hide()
Equal(f.list:GetAlpha() .. tostring(f.addonBit:IsMouseEnabled()), "1false", "given back in a fight: alpha now, mouse later")
game.Fight(false)
Equal(tostring(f.list:IsMouseEnabled()) .. tostring(f.addonBit:IsMouseEnabled()), "truetrue", "after the fight: the mouse back")

-- The sweep keeper: a piece the game shows again is swept again.
W.Show()
f.addonBit:SetAlpha(1)
game.Tick(0.3)
Equal(f.addonBit:GetAlpha(), 0, "swept again within 0.25 s")
-- The developer trace prints what is still visible on the next sweep.
game.ns.db.sweepTrace = true
game.ns.SweepFriendsReport()
game.Tick(0.3)
Equal(type(game.printed) == "string" and game.printed:find("still visible", 1, true) ~= nil, true, "the sweep trace prints")
game.ns.db.sweepTrace = nil
W.Hide()

---------------------------------------------------------------------------
-- 4. The Who page's side tabs (whoTabs) and their pads
---------------------------------------------------------------------------
W.Show()
local tabs = parts.sideTabs
Equal(tabs and #tabs, 3, "three side tabs")
Equal(tabs[1]:IsShown() or tabs[2]:IsShown() or tabs[3]:IsShown(), false, "hidden while whoTabs is off")
local tp = Point(tabs[1])
Equal(tp[1] .. ":" .. tostring(tp[2] == env.FriendsFrame) .. ":" .. tp[3] .. ":" .. tp[4] .. "," .. tp[5],
    "TOPLEFT:true:TOPRIGHT:-3,-58", "the first at the window's top-right (-3, -58)")
local arrow = env.EraUIClassicWhoTabsToggle
Equal(game.State(arrow:GetNormalTexture()).file, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", "the arrow: next page while hidden")
game.Enter(arrow)
Equal(game.TipText(), "Group Finder", "its tooltip is EraUI's own: Group Finder")
game.Leave(arrow)
Equal(game.TipText(), nil, "gone on leave")
local saves = game.saves
arrow:Click()
Equal(game.ns.db.whoTabs, true, "the arrow turns whoTabs on")
Equal(game.saves, saves + 1, "and saves the mirror at once")
Equal(tabs[1]:IsShown() and tabs[2]:IsShown() and tabs[3]:IsShown(), true, "the three tabs show")
Equal(tostring(tabs[1]:GetChecked()) .. tostring(tabs[2]:GetChecked()) .. tostring(tabs[3]:GetChecked()), "falsefalsetrue",
    "only Who checked")
Equal(game.State(arrow:GetNormalTexture()).file, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", "the arrow: previous page while shown")
Equal(game.loads[#game.loads], "Blizzard_GroupFinder_VanillaStyle", "the group finder is warmed")
game.Enter(tabs[1])
Equal(game.TipText(), "Create Listing", "the side tab's tooltip is EraUI's own")
game.Leave(tabs[1])
-- The secure pads: Create Listing and Group Browser, on the game's group
-- finder button, standing aside while the finder shows.
local pad1, pad2 = game.PadFor(tabs[1]), game.PadFor(tabs[2])
Equal(pad1 and pad2 and pad1.target == env.LFDMicroButton and pad1.strata == "HIGH", true, "secure pads on tabs 1 and 2")
Equal(game.PadFor(tabs[3]), nil, "none on Who")
Equal(pad1.when(), true, "up while the finder is shut")
-- The tab's own click (the pad aside): out of a fight, the finder opens there.
local finder = game.MakeFinder()
game.Seal()
tabs[2]:Click()
Equal(finder:IsShown() and finder.selectedTab == 2, true, "Group Browser opens the finder on its tab 2")
Equal(env.FriendsFrame:IsShown(), false, "and closes the social window")
Equal(tabs[2]:GetChecked(), false, "the clicked tab isn't left checked")
Equal(pad1.when(), false, "the pads stand aside while the finder shows")
env.HideUIPanel(finder)
game.ns.OpenWhoList()
game.Fight(true)
tabs[1]:Click()
Equal(game.messages[#game.messages][1], "You can't do that while in combat", "in a fight: the red line")
Equal(env.FriendsFrame:IsShown() and not finder:IsShown(), true, "and nothing else")
game.Fight(false)
-- After the pad's secure click: turned to the tab, the social window closed,
-- and turned again a frame later.
env.ShowUIPanel(finder)
local turns = game.finderTurns
pad1.after()
Equal(finder.selectedTab, 1, "the pad's release turns the finder to Create Listing")
Equal(env.FriendsFrame:IsShown(), false, "and closes the social window")
game.NextFrame()
Equal(game.finderTurns >= turns + 1, true, "turned again a frame later (when needed)")
env.HideUIPanel(finder)
game.ns.OpenWhoList()
arrow:Click()
Equal(game.ns.db.whoTabs == false and not tabs[1]:IsShown(), true, "the arrow turns them off again")

---------------------------------------------------------------------------
-- 5. /who results land on the Who page
---------------------------------------------------------------------------
env.HideUIPanel(env.FriendsFrame)
game.Fire("WHO_LIST_UPDATE")
Equal(env.FriendsFrame:IsShown() and page:IsShown(), true, "a /who result opens the social window on the Who page")
game.NextFrame()
Equal(game.tabLook[env.EraUIClassicWhoTab], "selected", "and a frame later the Who tab still looks chosen")
-- The game's own Who list (the finder on its Who tab) turns into the page.
env.LFGVanilla_ShowFrame(3)
Equal(env.LFGWhoListFrame:IsShown(), true, "setup: the game's own Who list shows")
game.Tick(0.05)
Equal(finder:IsShown(), false, "the watch closes the game's Who list")
Equal(finder.selectedTab, 1, "leaving the finder on its first tab")
Equal(game.whoToUi, true, "results still go to the Who page")
Equal(page:IsShown(), true, "the Who page stays")
-- In a fight with the social window shut: nothing.
env.HideUIPanel(env.FriendsFrame)
env.LFGVanilla_ShowFrame(3)
game.Fight(true)
game.Tick(0.05)
Equal(env.FriendsFrame:IsShown(), false, "in a fight with the window shut: the watch does nothing")
game.Fight(false)
game.Tick(0.05)
Equal(env.FriendsFrame:IsShown() and not finder:IsShown(), true, "after it: the Who page")
NoErrors(game, "Who page")

---------------------------------------------------------------------------
-- 6. The group finder
---------------------------------------------------------------------------
do
    local finderGame = Game()
    local FS = finderGame.Load()
    local fenv = finderGame.env
    local lfg = finderGame.MakeFinder()
    finderGame.Seal()
    finderGame.Pass()
    Equal(lfg:GetWidth() .. "x" .. lfg:GetHeight(), "360x424", "the finder cut to the social window's size")
    Equal(lfg:GetAttribute("UIPanelLayout-width"), 360, "the window layout's width too")
    Equal(finderGame.panelUpdates, nil, "not placed again while shut")
    fenv.FriendsFrame:SetWidth(385)
    fenv.ShowUIPanel(lfg)
    finderGame.Tick(0.15)
    Equal(lfg:GetWidth(), 385, "it follows the social window's width")
    Equal(finderGame.panelUpdates, 1, "the window manager places it again once the width changed")
    finderGame.Tick(0.5)
    Equal(finderGame.panelUpdates, 1, "and not again while nothing changes")
    fenv.FriendsFrame:SetWidth(200)
    finderGame.Tick(0.15)
    Equal(lfg:GetWidth() .. "x" .. lfg:GetHeight(), "360x424", "a social window not laid out: 360 x 424")
    finderGame.Fight(true)
    fenv.FriendsFrame:SetWidth(390)
    finderGame.Tick(0.15)
    Equal(lfg:GetWidth(), 360, "never resized in a fight")
    finderGame.Fight(false)
    fenv.FriendsFrame:SetWidth(360)
    finderGame.Tick(0.15)
    -- The game's tabs and EraUI's.
    for _, key in ipairs({ "ListingTab", "BrowsingTab", "WhoListingTab" }) do
        Equal(lfg[key]:GetAlpha() .. tostring(lfg[key]:IsMouseEnabled()), "0false", key .. ": faded, the mouse off")
    end
    local mine = FS.finder.tabs
    Equal(mine and #mine, 3, "EraUI's three side tabs")
    local p1 = Point(mine[1])
    Equal(p1[1] .. ":" .. tostring(p1[2] == lfg) .. ":" .. p1[3] .. ":" .. p1[4] .. "," .. p1[5], "TOPLEFT:true:TOPRIGHT:-3,-58",
        "the first at the finder's top-right (-3, -58)")
    Equal(tostring(mine[1]:GetChecked()) .. tostring(mine[2]:GetChecked()) .. tostring(mine[3]:GetChecked()), "truefalsefalse",
        "checked: the finder's own page; Who never")
    mine[2]:Click()
    Equal(lfg.selectedTab, 2, "Group Browser turns the finder")
    Equal(tostring(mine[1]:GetChecked()) .. tostring(mine[2]:GetChecked()), "falsetrue", "and the checks follow")
    finderGame.Fight(true)
    mine[1]:Click()
    Equal(lfg.selectedTab .. finderGame.messages[#finderGame.messages][1], "2You can't do that while in combat",
        "in a fight: not turned (the game's own tab code is never run in a fight), the red line")
    mine[3]:Click()
    Equal(lfg:IsShown(), true, "Who in a fight: nothing")
    finderGame.Fight(false)
    mine[3]:Click()
    Equal(lfg:IsShown(), false, "Who: the finder closes")
    Equal(fenv.EraUIClassicWhoPanel and fenv.EraUIClassicWhoPanel:IsShown(), true, "and EraUI's Who page opens")
    Equal(mine[3]:GetChecked(), false, "Who is left unchecked")
    -- Create Listing's dressing.
    local listing = fenv.LFGListingFrame
    Equal(listing.DividerFrame.Divider:GetAlpha(), 0, "the long line faded")
    Equal(listing.DividerFrame:GetAlpha(), 1, "its frame untouched")
    local back = Point(listing.BackButton)
    Equal(back[1] .. back[4] .. "," .. back[5] .. ":" .. listing.BackButton:GetWidth(), "BOTTOMLEFT8,9:124", "Back: bottom-left, 124 wide")
    local post = Point(listing.PostButton)
    Equal(post[1] .. post[4] .. "," .. post[5], "BOTTOMRIGHT-8,9", "Post: bottom-right")
    local bars = listing.CategoryView.CategoryButtons
    Equal(bars[2]:GetWidth() .. "x" .. bars[2]:GetHeight(), "340x52", "the category bars (W - 20) x 52")
    Equal(bars[2].SelectedTexture:GetWidth() .. "x" .. bars[2].HighlightTexture:GetHeight(), "326x42", "their glows (W - 34) x 42")
    local first = Point(bars[1])
    Equal(first[1] .. ":" .. tostring(first[2] == listing.CategoryView) .. ":" .. first[5], "TOP:true:-8", "the first under the view's top")
    local style = listing.ActivityView.PlayStyleDropdown
    Equal(style:GetWidth(), 174, "the play style kept clear of the level ranges label")
    -- Group Browser's dressing.
    local browse = fenv.LFGBrowseFrame
    Equal(browse.CategoryDropdown:GetWidth() .. "," .. browse.ActivityDropdown:GetWidth(), "100,138", "the drop downs 100 and W - 222")
    local act = Point(browse.ActivityDropdown)
    Equal(act[1] .. ":" .. tostring(act[2] == browse.CategoryDropdown) .. ":" .. act[3] .. act[4], "LEFT:true:RIGHT8",
        "side by side")
    Equal(browse.RefreshButton:GetWidth() .. "x" .. browse.RefreshButton:GetHeight(), "28x28", "refresh 28 x 28")
    Equal(browse.BackgroundArt:GetAlpha(), 0, "its background art faded")
    -- Warming, and the restore.
    finderGame.loaded = { Blizzard_GroupFinder_VanillaStyle = true }
    local loads = #finderGame.loads
    finderGame.ns.WarmGroupFinder()
    Equal(#finderGame.loads, loads, "already loaded: not loaded again")
    finderGame.ns.db.groupFinder = false
    finderGame.Pass()
    Equal(finderGame.ns.needsReload, true, "turned off: a reload is asked for")
    NoErrors(finderGame, "group finder")
end

print("Social checks passed: " .. checks .. " assertions.")
