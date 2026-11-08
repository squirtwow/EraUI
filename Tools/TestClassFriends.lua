-- Class-coloured Friends (/era > Appearance > Class Colours;
-- Modules/ClassFriends.lua) on a small mock of the game's friends list: off by
-- default; on, an online character friend's whole name line is in their class
-- colour, and a Battle.net friend playing this game gets the colour on the
-- character's name in brackets only. Offline friends, other games, other
-- projects, headers and secrets keep the game's colours. Live both ways, and
-- it waits for the friends window to load. Show Their Level puts a Battle.net
-- friend's level in its brackets (none when missing, 0 or secret, for a
-- favourite under the game's star, or when it would no longer fit; brackets
-- already coloured inside are left alone; only with Class-coloured Friends
-- on). Battle.net friends on the other faction (the game's other colour code,
-- and a * in colourblind mode) get the same, and go back to that code. Run
-- from the addon folder.
local checks = 0
local function equal(got, want, label)
    checks = checks + 1
    assert(got == want, label .. ": expected " .. tostring(want) .. ", got " .. tostring(got))
end

local SECRET = setmetatable({}, {__tostring = function() return "SECRET" end})
_G.issecretvalue = function(value) return value == SECRET end

-- The game's colours and names.
_G.RAID_CLASS_COLORS = {WARRIOR = {r = .78, g = .61, b = .43}, MAGE = {r = .25, g = .78, b = .92}, PRIEST = {r = 1, g = 1, b = 1},
    ROGUE = {r = 1, g = .96, b = .41}, HUNTER = {r = .67, g = .83, b = .45}, DRUID = {r = 1, g = .49, b = .04}}
_G.LOCALIZED_CLASS_NAMES_MALE = {WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priest", ROGUE = "Rogue", HUNTER = "Hunter", DRUID = "Druid"}
_G.LOCALIZED_CLASS_NAMES_FEMALE = {WARRIOR = "Warrior", MAGE = "Mage", PRIEST = "Priestess", ROGUE = "Rogue", HUNTER = "Huntress",
    DRUID = "Druid"}
_G.FRIENDS_BUTTON_TYPE_DIVIDER, _G.FRIENDS_BUTTON_TYPE_BNET, _G.FRIENDS_BUTTON_TYPE_WOW, _G.FRIENDS_BUTTON_TYPE_INVITE = 1, 2, 3, 4
_G.FRIENDS_WOW_NAME_COLOR_CODE, _G.FRIENDS_OTHER_NAME_COLOR_CODE, _G.FONT_COLOR_CODE_CLOSE = "|cfffde05c", "|cff7b8489", "|r"
_G.FRIENDS_WOW_NAME_COLOR = {r = .996, g = .882, b = .361}
_G.FRIENDS_GRAY_COLOR = {r = .5, g = .5, b = .5}
_G.FRIENDS_BNET_NAME_COLOR = {r = .51, g = .773, b = 1}
_G.BNET_CLIENT_WOW, _G.WOW_PROJECT_ID = "WoW", 2
_G.CANNOT_COOPERATE_LABEL = "*"

-- Friends: character friends by index, Battle.net friends by index.
local wow = {
    {name = "Garrok", connected = true, level = 60, className = "Warrior", guid = "Player-1-A"},
    {name = "Lunia", connected = false, level = 12, className = "Mage", guid = "Player-1-B"},
    {name = "Selra", connected = true, level = 40, className = "Priestess", guid = "Player-1-C"},
    {name = "Odd", connected = true, level = 5, className = "Wanderer", guid = "Player-1-D"},  -- a class name it can't map
    {name = "Hush", connected = true, level = 9, className = SECRET, guid = SECRET},
}
local bnet = {
    {accountName = "Tamsin (Main)", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, characterName = "Vex", className = "Rogue",
        characterLevel = 60}},
    {accountName = "Bram", game = {isOnline = true, clientProgram = "App", wowProjectID = 0, characterName = "", className = nil}},
    {accountName = "Ilse", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 1, characterName = "Ari", className = "Mage",
        characterLevel = 40}},
    {accountName = "Corin", game = {isOnline = false, clientProgram = "WoW", wowProjectID = 2, characterName = "", className = "Hunter"}},
    {accountName = "Pell", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, characterName = "Nim", className = "Unknown",
        playerGuid = "Player-1-E", characterLevel = 12}},
    -- Show Their Level: a secret level, 0, none, and a class it can't tell.
    {accountName = "Quill", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, characterName = "Fen", className = "Mage",
        characterLevel = SECRET}},
    {accountName = "Rook", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, characterName = "Tor", className = "Warrior",
        characterLevel = 0}},
    {accountName = "Sable", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, characterName = "Wisp", className = "Hunter"}},
    {accountName = "Ulf", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, characterName = "Ash", className = "Wanderer",
        characterLevel = 33}},
    -- A favourite (the game's star sits just after its name), and names that only fit without the level.
    {accountName = "Wren", isFavorite = true, game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, characterName = "Kip",
        className = "Rogue", characterLevel = 50}},
    {accountName = "Bartholomew Featherstonehaugh", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2,
        characterName = "Wilhelmina Thornbury", className = "Mage", characterLevel = 60}},
    {accountName = "Bartholomew Featherstonehaugh", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2,
        characterName = "Wilhelmina Thornbury", className = "Wanderer", characterLevel = 60}},
    -- On the other faction (13-15), the last with a class it can't tell.
    {accountName = "Berza", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, otherFaction = true,
        characterName = "Berz Forever", className = "Druid", characterLevel = 28}},
    {accountName = "MalohiQueen", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, otherFaction = true,
        characterName = "Indi Kha", className = "Druid", characterLevel = 17}},
    {accountName = "Yarrow", game = {isOnline = true, clientProgram = "WoW", wowProjectID = 2, otherFaction = true,
        characterName = "Grum", className = "Wanderer", characterLevel = 20}},
}
_G.GetPlayerInfoByGUID = function(guid)
    if guid == "Player-1-D" then return "Hunter", "HUNTER" end
    if guid == "Player-1-E" then return "Priest", "PRIEST" end
end
_G.C_FriendList = {GetFriendInfoByIndex = function(i) return wow[i] end}
_G.C_BattleNet = {GetFriendAccountInfo = function(i)
    local f = bnet[i]
    return f and {accountName = f.accountName, gameAccountInfo = f.game, isFavorite = f.isFavorite}
end}

-- A friend row: its name line (fits WIDTH letters, colour codes take none)
-- and the favourite star.
local WIDTH = 54
local function Row()
    local name = {text = "", colour = nil, sets = 0}
    function name:SetText(t) self.text = t; self.sets = self.sets + 1 end
    function name:GetText() return self.text end
    function name:SetTextColor(r, g, b) self.colour = string.format("%.2f,%.2f,%.2f", r, g, b) end
    function name:IsTruncated() return #(self.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) > WIDTH end
    local star = {shown = false}
    function star:Show() self.shown = true end
    function star:Hide() self.shown = false end
    function star:IsShown() return self.shown end
    return {name = name, Favorite = star}
end
local function C(t) return string.format("%.2f,%.2f,%.2f", t.r, t.g, t.b) end

-- The game's own row function, as the friends list fills a row. A friend it
-- can't cooperate with (another faction or game) gets the other code, and in
-- colourblind mode a * after the name.
local colourblind = false
local function GameRow(button, elementData)
    button.buttonType, button.id = elementData.buttonType, elementData.id
    if elementData.buttonType == FRIENDS_BUTTON_TYPE_WOW then
        local info = C_FriendList.GetFriendInfoByIndex(elementData.id)
        if info.connected then
            button.name:SetText(info.name .. ", Level " .. info.level .. " " .. tostring(info.className))
            button.name:SetTextColor(FRIENDS_WOW_NAME_COLOR.r, FRIENDS_WOW_NAME_COLOR.g, FRIENDS_WOW_NAME_COLOR.b)
        else
            button.name:SetText(info.name)
            button.name:SetTextColor(FRIENDS_GRAY_COLOR.r, FRIENDS_GRAY_COLOR.g, FRIENDS_GRAY_COLOR.b)
        end
    elseif elementData.buttonType == FRIENDS_BUTTON_TYPE_BNET then
        local account = C_BattleNet.GetFriendAccountInfo(elementData.id)
        local game = account.gameAccountInfo
        local text = account.accountName
        if game.characterName ~= "" then
            local cooperate = game.clientProgram == BNET_CLIENT_WOW and game.wowProjectID == WOW_PROJECT_ID and not game.otherFaction
            local character = game.characterName
            if not cooperate and colourblind then character = character .. CANNOT_COOPERATE_LABEL end
            local code = cooperate and FRIENDS_WOW_NAME_COLOR_CODE or FRIENDS_OTHER_NAME_COLOR_CODE
            text = text .. " " .. code .. "(" .. character .. ")" .. FONT_COLOR_CODE_CLOSE
        end
        button.name:SetText(text)
        local colour = game.isOnline and FRIENDS_BNET_NAME_COLOR or FRIENDS_GRAY_COLOR
        button.name:SetTextColor(colour.r, colour.g, colour.b)
        if account.isFavorite then button.Favorite:Show() else button.Favorite:Hide() end
    end
end

-- The friends list showing rows (the scroll box's own frames).
local shown = {}
_G.FriendsListFrame = {ScrollBox = {ForEachFrame = function(_, fn)
    for _, pair in ipairs(shown) do if fn(pair[1], pair[2]) then return end end
end}}

_G.hooksecurefunc = function(name, after)
    local original = _G[name]
    _G[name] = function(...) original(...); after(...) end
end
local frames = {}
_G.CreateFrame = function()
    local f = {events = {}, scripts = {}}
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    frames[#frames + 1] = f
    return f
end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

local settings
local function Load(windowLoaded)
    frames = {}
    _G.FriendsFrame_UpdateFriendButton = windowLoaded and GameRow or nil
    settings = {enabled = true, classColourFriends = false}
    local E = {modules = {}}
    function E:RegisterModule(name, module) module.name = name; self.modules[name] = module end
    function E:GetSetting(key) return settings[key] end
    assert(loadfile("Modules/ClassFriends.lua"))("EraUI", E)
    local friends = E.modules.ClassFriends
    friends:Initialize()
    return friends
end
-- Fills a row through the game's function (and any hook on it).
local function Fill(kind, id)
    local button, data = Row(), {buttonType = kind, id = id}
    FriendsFrame_UpdateFriendButton(button, data)
    return button, data
end
local WOW, BNET = FRIENDS_BUTTON_TYPE_WOW, FRIENDS_BUTTON_TYPE_BNET
local GAME_WOW, GREY = C(FRIENDS_WOW_NAME_COLOR), C(FRIENDS_GRAY_COLOR)
local function Hex(t) return string.format("|cff%02x%02x%02x", math.floor(t.r * 255 + .5), math.floor(t.g * 255 + .5), math.floor(t.b * 255 + .5)) end

-- Off (the default): the game's colours.
local friends = Load(true)
local row = Fill(WOW, 1)
equal(row.name.colour .. " " .. row.name.text, GAME_WOW .. " Garrok, Level 60 Warrior", "off by default: the game's colour")
row = Fill(BNET, 1)
equal(row.name.text, "Tamsin (Main) |cfffde05c(Vex)|r", "off: a Battle.net friend's name as the game writes it")

-- On.
settings.classColourFriends = true
friends:Refresh()
row = Fill(WOW, 1)
equal(row.name.colour .. " " .. row.name.text, C(RAID_CLASS_COLORS.WARRIOR) .. " Garrok, Level 60 Warrior",
    "an online character friend: the whole name line in the class colour, its words unchanged")
row = Fill(WOW, 2)
equal(row.name.colour, GREY, "an offline friend keeps the game's grey")
row = Fill(WOW, 3)
equal(row.name.colour, C(RAID_CLASS_COLORS.PRIEST), "a female class name (Priestess) is found too")
row = Fill(WOW, 4)
equal(row.name.colour, C(RAID_CLASS_COLORS.HUNTER), "a class name it can't map: the character's GUID gives the class")
row = Fill(WOW, 5)
equal(row.name.colour, GAME_WOW, "a secret class and GUID: the game's colour")

row = Fill(BNET, 1)
equal(row.name.text, "Tamsin (Main) " .. Hex(RAID_CLASS_COLORS.ROGUE) .. "(Vex)|r",
    "a Battle.net friend on this game: only the character's name in brackets in the class colour (the last bracket, not the account name's)")
equal(row.name.colour, C(FRIENDS_BNET_NAME_COLOR), "the account name keeps the game's blue")
row = Fill(BNET, 2)
equal(row.name.text .. " " .. row.name.sets, "Bram 1", "a Battle.net friend in another program: untouched")
row = Fill(BNET, 3)
equal(row.name.text .. " " .. row.name.sets, "Ilse |cff7b8489(Ari)|r 1", "a friend on another WoW game: untouched")
row = Fill(BNET, 4)
equal(row.name.text .. " " .. row.name.sets, "Corin 1", "an offline Battle.net friend: untouched")
row = Fill(BNET, 5)
equal(row.name.text, "Pell " .. Hex(RAID_CLASS_COLORS.PRIEST) .. "(Nim)|r", "a Battle.net class name it can't map: the GUID gives the class")

-- Rows that aren't friends: untouched.
for _, kind in ipairs({FRIENDS_BUTTON_TYPE_DIVIDER, FRIENDS_BUTTON_TYPE_INVITE}) do
    row = Fill(kind, 1)
    equal(tostring(row.name.colour) .. " " .. row.name.sets, "nil 0", "row type " .. kind .. ": untouched")
end

-- Secrets in the row itself: untouched, no error.
row = Row()
FriendsFrame_UpdateFriendButton(row, {buttonType = WOW, id = 1})
local painted = row.name.colour
row = Row(); row.name.text = "x"
friends:Paint(row, {buttonType = SECRET, id = 1})
equal(tostring(row.name.colour), "nil", "a secret row type: untouched")
row = Row()
friends:Paint(row, {buttonType = WOW, id = SECRET})
equal(tostring(row.name.colour), "nil", "a secret friend index: untouched")
row = Row()
GameRow(row, {buttonType = BNET, id = 1})
row.name.text = SECRET
friends:Paint(row, {buttonType = BNET, id = 1})
equal(row.name.text, SECRET, "a secret name text: untouched")
equal(painted, C(RAID_CLASS_COLORS.WARRIOR), "a normal row still colours")

-- Switched off with the list open: what it coloured goes back at once.
local a, da = Fill(WOW, 1)
local b, db = Fill(BNET, 1)
local c, dc = Fill(WOW, 2)
shown = {{a, da}, {b, db}, {c, dc}}
settings.classColourFriends = false
friends:Refresh()
equal(a.name.colour .. " | " .. b.name.text .. " | " .. c.name.colour, GAME_WOW .. " | Tamsin (Main) |cfffde05c(Vex)|r | " .. GREY,
    "switched off: the game's colours back at once")
-- The game fills a row while it's off: the game's colours stay.
row = Fill(WOW, 1)
equal(row.name.colour, GAME_WOW, "off: a new fill keeps the game's colour")

-- Switched on with the list open: the rows showing colour at once, once.
friends:Refresh()
settings.classColourFriends = true
friends:Refresh()
equal(a.name.colour .. " | " .. b.name.text, C(RAID_CLASS_COLORS.WARRIOR) .. " | Tamsin (Main) " .. Hex(RAID_CLASS_COLORS.ROGUE) .. "(Vex)|r",
    "switched on with the list open: coloured at once")
local sets = b.name.sets
friends:Refresh()
equal(b.name.sets, sets, "refreshed again: rows already coloured are left alone")
-- A row the game fills again while on: coloured afresh, and still put back when off.
FriendsFrame_UpdateFriendButton(b, db)
equal(b.name.text, "Tamsin (Main) " .. Hex(RAID_CLASS_COLORS.ROGUE) .. "(Vex)|r", "a refill while on: coloured afresh")
settings.classColourFriends = false
friends:Refresh()
equal(b.name.text, "Tamsin (Main) |cfffde05c(Vex)|r", "and back when switched off")
shown = {}

-- The friends window loads later: hooked when it arrives.
friends = Load(false)
settings.classColourFriends = true
friends:Refresh()
equal(friends.hooked, nil, "no friends window yet: nothing hooked")
_G.FriendsFrame_UpdateFriendButton = GameRow
Fire("ADDON_LOADED", "Blizzard_FriendsFrame")
equal(friends.hooked, true, "it loads: hooked")
row = Fill(WOW, 1)
equal(row.name.colour, C(RAID_CLASS_COLORS.WARRIOR), "its rows colour")

-- EraUI switched off as a whole: the game's colours.
settings.enabled = false
row = Fill(WOW, 1)
equal(row.name.colour, GAME_WOW, "EraUI off: the game's colour")
settings.enabled = true

-- Show Their Level (off by default): a Battle.net friend's level in its
-- brackets, in the same colour as the name; only with Class-coloured Friends on.
local ROGUE, PRIEST, MAGE, WARRIOR = Hex(RAID_CLASS_COLORS.ROGUE), Hex(RAID_CLASS_COLORS.PRIEST), Hex(RAID_CLASS_COLORS.MAGE), Hex(RAID_CLASS_COLORS.WARRIOR)
row = Fill(BNET, 1)
equal(row.name.text, "Tamsin (Main) " .. ROGUE .. "(Vex)|r", "Show Their Level off (the default): no level")
settings.classColourFriendsLevel = true
row = Fill(BNET, 1)
equal(row.name.text, "Tamsin (Main) " .. ROGUE .. "(Vex, 60)|r", "on: the level after the character's name, inside the class-coloured brackets")
equal(row.name.colour, C(FRIENDS_BNET_NAME_COLOR), "the account name keeps the game's blue")
row = Fill(BNET, 5)
equal(row.name.text, "Pell " .. PRIEST .. "(Nim, 12)|r", "a class from the GUID: its colour, and the level")
row = Fill(BNET, 6)
equal(row.name.text, "Quill " .. MAGE .. "(Fen)|r", "a secret level: no level, the colour still")
row = Fill(BNET, 7)
equal(row.name.text, "Rook " .. WARRIOR .. "(Tor)|r", "level 0: no level")
row = Fill(BNET, 8)
equal(row.name.text, "Sable " .. Hex(RAID_CLASS_COLORS.HUNTER) .. "(Wisp)|r", "no level given: no level")
row = Fill(BNET, 9)
equal(row.name.text, "Ulf |cfffde05c(Ash, 33)|r", "a class it can't tell: the game's colour, the level still")
row = Fill(BNET, 3)
equal(row.name.text .. " " .. row.name.sets, "Ilse |cff7b8489(Ari)|r 1", "a friend on another WoW game: untouched, no level")
row = Fill(BNET, 2)
equal(row.name.text .. " " .. row.name.sets, "Bram 1", "another program: untouched")
row = Fill(WOW, 1)
equal(row.name.colour .. " " .. row.name.text, C(RAID_CLASS_COLORS.WARRIOR) .. " Garrok, Level 60 Warrior",
    "a friend added by name: unchanged (the game shows the level already)")
-- A favourite: the game's star sits just after the name it wrote, so the colour only.
row = Fill(BNET, 10)
equal(row.name.text .. " " .. tostring(row.Favorite.shown), "Wren " .. ROGUE .. "(Kip)|r true", "a favourite: the colour, no level under its star")
-- Too long for the row with the level: the colour only; with no colour either, the game's text.
row = Fill(BNET, 11)
equal(row.name.text, "Bartholomew Featherstonehaugh " .. MAGE .. "(Wilhelmina Thornbury)|r", "too long with the level: the colour only")
equal(row.name:IsTruncated(), false, "and it fits")
row = Fill(BNET, 12)
equal(row.name.text, "Bartholomew Featherstonehaugh |cfffde05c(Wilhelmina Thornbury)|r", "too long, class unknown: the game's text")
-- Brackets already coloured inside (another copy of this feature got there first): left alone, no second level.
local QUILLED = "Tamsin (Main) |cfffde05c(" .. ROGUE .. "Vex, 60|r|cfffde05c)|r"
row = Row()
GameRow(row, {buttonType = BNET, id = 1})
row.name.text = QUILLED
local before = row.name.sets
friends:Paint(row, {buttonType = BNET, id = 1})
equal(row.name.text .. " " .. (row.name.sets - before), QUILLED .. " 0", "already coloured inside: left alone")
shown = {{row, {buttonType = BNET, id = 1}}}
friends:Refresh()
equal(row.name.text .. " " .. (row.name.sets - before), QUILLED .. " 0", "and when the rows showing are done afresh")
shown = {}
-- Its parent off: no level either.
settings.classColourFriends = false
row = Fill(BNET, 1)
equal(row.name.text .. " " .. row.name.sets, "Tamsin (Main) |cfffde05c(Vex)|r 1", "Class-coloured Friends off: no level, untouched")
row = Fill(BNET, 9)
equal(row.name.text .. " " .. row.name.sets, "Ulf |cfffde05c(Ash)|r 1", "nor for a class it can't tell")
settings.classColourFriends = true

-- The tick switched with the list open: rows put back and done afresh at once.
local t, dt = Fill(BNET, 1)
local u, du = Fill(BNET, 9)
local w, dw = Fill(WOW, 1)
local v, dv = Fill(BNET, 11)
shown = {{t, dt}, {u, du}, {w, dw}, {v, dv}}
settings.classColourFriendsLevel = false
friends:Refresh(true)
equal(t.name.text .. " | " .. u.name.text .. " | " .. w.name.colour, "Tamsin (Main) " .. ROGUE .. "(Vex)|r | Ulf |cfffde05c(Ash)|r | " .. C(RAID_CLASS_COLORS.WARRIOR),
    "tick off: the levels go at once, the colours stay")
settings.classColourFriendsLevel = true
friends:Refresh(true)
equal(t.name.text .. " | " .. u.name.text, "Tamsin (Main) " .. ROGUE .. "(Vex, 60)|r | Ulf |cfffde05c(Ash, 33)|r", "tick on: the levels back at once")
-- Class-coloured Friends off with levels showing: the game's own text back.
settings.classColourFriends = false
friends:Refresh()
equal(t.name.text .. " | " .. u.name.text .. " | " .. w.name.colour, "Tamsin (Main) |cfffde05c(Vex)|r | Ulf |cfffde05c(Ash)|r | " .. GAME_WOW,
    "switched off: no colours, no levels")
equal(v.name.text, "Bartholomew Featherstonehaugh |cfffde05c(Wilhelmina Thornbury)|r", "a row too long for its level: back too")
shown = {}
settings.classColourFriends, settings.classColourFriendsLevel = true, nil

-- Battle.net friends on the other faction: the game opens their brackets with
-- its other colour code (and in colourblind mode puts a * after the name).
-- Coloured and given their level all the same; put back with that code.
local OTHER, DRUID = FRIENDS_OTHER_NAME_COLOR_CODE, Hex(RAID_CLASS_COLORS.DRUID)
local function Game(id) local r = Row(); GameRow(r, {buttonType = BNET, id = id}); return r.name.text end
equal(Game(13), "Berza |cff7b8489(Berz Forever)|r", "the game writes a cross-faction friend with the other code")
row = Fill(BNET, 13)
equal(row.name.text, "Berza " .. DRUID .. "(Berz Forever)|r", "the other faction: the class colour on the character's name")
equal(row.name.colour, C(FRIENDS_BNET_NAME_COLOR), "its account name keeps the game's blue")
settings.classColourFriendsLevel = true
row = Fill(BNET, 13)
equal(row.name.text, "Berza " .. DRUID .. "(Berz Forever, 28)|r", "the other faction with Show Their Level: its level too")
row = Fill(BNET, 14)
equal(row.name.text, "MalohiQueen " .. DRUID .. "(Indi Kha, 17)|r", "another friend on the other faction")
row = Fill(BNET, 15)
equal(row.name.text, "Yarrow " .. OTHER .. "(Grum, 20)|r", "the other faction, a class it can't tell: the game's other code kept, the level still")
row = Fill(BNET, 1)
equal(row.name.text, "Tamsin (Main) " .. ROGUE .. "(Vex, 60)|r", "this faction's friends: the same as before")
row = Fill(BNET, 3)
equal(row.name.text .. " " .. row.name.sets, "Ilse |cff7b8489(Ari)|r 1", "a friend on another WoW game (the other code too): still untouched")
-- Colourblind mode: the * stays, the level after it.
colourblind = true
equal(Game(13), "Berza |cff7b8489(Berz Forever*)|r", "colourblind: the game puts a * after the name")
row = Fill(BNET, 13)
equal(row.name.text, "Berza " .. DRUID .. "(Berz Forever*, 28)|r", "colourblind: the colour, the * kept, the level after it")
row = Fill(BNET, 1)
equal(row.name.text, "Tamsin (Main) " .. ROGUE .. "(Vex, 60)|r", "colourblind: this faction's friends unchanged")
colourblind = false

-- Rows showing, the tick switched and then Class-coloured Friends off.
local originals = {}
for _, case in ipairs({{13, true}, {14, false}, {15, false}, {1, false}}) do
    colourblind = case[2]
    local button, data = Fill(BNET, case[1])
    shown[#shown + 1] = {button, data}
    originals[#originals + 1] = Game(case[1])
end
colourblind = false
local function Texts()
    local out = {}
    for i, pair in ipairs(shown) do out[i] = pair[1].name.text end
    return table.concat(out, " | ")
end
local ORIGINAL = table.concat(originals, " | ")
equal(ORIGINAL, "Berza |cff7b8489(Berz Forever*)|r | MalohiQueen |cff7b8489(Indi Kha)|r | Yarrow |cff7b8489(Grum)|r | Tamsin (Main) |cfffde05c(Vex)|r",
    "the game's own text for those rows")
equal(Texts(), "Berza " .. DRUID .. "(Berz Forever*, 28)|r | MalohiQueen " .. DRUID .. "(Indi Kha, 17)|r | Yarrow " .. OTHER .. "(Grum, 20)|r | Tamsin (Main) "
    .. ROGUE .. "(Vex, 60)|r", "coloured, with levels")
settings.classColourFriendsLevel = false
friends:Refresh(true)
equal(Texts(), "Berza " .. DRUID .. "(Berz Forever*)|r | MalohiQueen " .. DRUID .. "(Indi Kha)|r | Yarrow " .. OTHER .. "(Grum)|r | Tamsin (Main) "
    .. ROGUE .. "(Vex)|r", "tick off: the levels go, the colours stay")
settings.classColourFriendsLevel = true
friends:Refresh(true)
equal(Texts(), "Berza " .. DRUID .. "(Berz Forever*, 28)|r | MalohiQueen " .. DRUID .. "(Indi Kha, 17)|r | Yarrow " .. OTHER .. "(Grum, 20)|r | Tamsin (Main) "
    .. ROGUE .. "(Vex, 60)|r", "tick on: the levels back")
settings.classColourFriends = false
friends:Refresh()
equal(Texts(), ORIGINAL, "switched off: each row exactly the game's text, the other faction's code back where the game wrote it")
shown = {}
settings.classColourFriends = true

-- Neither of the game's codes before the brackets: left alone.
for _, odd in ipairs({"Tamsin (Main) (Vex)", "Tamsin (Main) |cff00ff00(Vex)|r"}) do
    row = Row()
    GameRow(row, {buttonType = BNET, id = 1})
    row.name.text = odd
    local before = row.name.sets
    friends:Paint(row, {buttonType = BNET, id = 1})
    equal(row.name.text .. " " .. (row.name.sets - before), odd .. " 0", "neither code (" .. odd .. "): left alone")
end
-- Both codes in one name: the last bracket is the character's.
row = Row()
GameRow(row, {buttonType = BNET, id = 1})
row.name.text = "Tamsin |cff7b8489(Main)|r |cfffde05c(Vex)|r"
friends:Paint(row, {buttonType = BNET, id = 1})
equal(row.name.text, "Tamsin |cff7b8489(Main)|r " .. ROGUE .. "(Vex, 60)|r", "both codes, this faction's last: that one")
row = Row()
GameRow(row, {buttonType = BNET, id = 13})
row.name.text = "Berza |cfffde05c(Main)|r |cff7b8489(Berz Forever)|r"
friends:Paint(row, {buttonType = BNET, id = 13})
equal(row.name.text, "Berza |cfffde05c(Main)|r " .. DRUID .. "(Berz Forever, 28)|r", "both codes, the other faction's last: that one")
-- One of the game's codes missing: the other still found.
local wowCode = FRIENDS_WOW_NAME_COLOR_CODE
_G.FRIENDS_WOW_NAME_COLOR_CODE = nil
row = Fill(BNET, 13)
equal(row.name.text, "Berza " .. DRUID .. "(Berz Forever, 28)|r", "this faction's code missing: the other faction's still found")
_G.FRIENDS_WOW_NAME_COLOR_CODE = wowCode
_G.FRIENDS_OTHER_NAME_COLOR_CODE = ""
row = Fill(BNET, 1)
equal(row.name.text, "Tamsin (Main) " .. ROGUE .. "(Vex, 60)|r", "the other faction's code empty: this faction's still found")
_G.FRIENDS_OTHER_NAME_COLOR_CODE = OTHER
settings.classColourFriendsLevel = nil

io.write("Class-coloured Friends checks passed: " .. checks .. " assertions.\n")
