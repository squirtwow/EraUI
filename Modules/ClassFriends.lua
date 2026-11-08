local _, EraUI = ...

-- Class-coloured Friends (/era > Appearance > Class Colours; on by default,
-- seen in game 2026-11-07). In the friends list an online friend's name shows in their
-- class colour: a character friend's whole name line, and for a Battle.net
-- friend playing this game only the character's name in brackets after the
-- account name. Battle.net friends on the other faction are coloured too (the
-- game opens their brackets with a different colour code, and in colourblind
-- mode puts a * after the name, which stays). Offline friends, and friends
-- in other games, keep the game's colours. Switched on with the list open it
-- colours at once; switched off, the names it coloured go back at once, each
-- with the code the game wrote.
-- Show Their Level (under it; off by default; seen in game 2026-11-07) puts a Battle.net
-- friend's level in those brackets too, "(Vex, 60)", in the same colour.
-- Character friends already have "Name, Level 24 Rogue" from the game.
-- One post-hook on the game's own friend row function, after it sets the
-- name; only the name's colour (or the colour code in its text, and the
-- level in its brackets) changes. The rows this changed are kept in a weak
-- table of EraUI's own, never on them.
local Friends = {}
EraUI:RegisterModule("ClassFriends", Friends)

-- row: "wow", or {colour code put in its text, ", 60" put in its brackets or nil,
-- the code the game had written there}
local painted = setmetatable({}, {__mode = "k"})

local function Public(value)
    return not (issecretvalue and issecretvalue(value))
end

function Friends:On()
    return EraUI:GetSetting("enabled") ~= false and EraUI:GetSetting("classColourFriends") == true
end

function Friends:LevelOn()
    return self:On() and EraUI:GetSetting("classColourFriendsLevel") == true
end

-- ", 60" for a level worth showing, else nil (missing, 0 or secret).
function Friends.Level(level)
    if not Public(level) or type(level) ~= "number" or level < 1 then return nil end
    return ", " .. math.floor(level)
end

-- A class's token (WARRIOR) from its name as the friends list gives it.
local tokens
function Friends.Token(className)
    if not Public(className) or type(className) ~= "string" or className == "" then return nil end
    if not tokens then
        local found = {}
        for _, names in ipairs({LOCALIZED_CLASS_NAMES_MALE or false, LOCALIZED_CLASS_NAMES_FEMALE or false}) do
            if type(names) == "table" then
                for token, name in pairs(names) do found[name] = token end
            end
        end
        if type(GetNumClasses) == "function" and type(GetClassInfo) == "function" then
            for i = 1, GetNumClasses() do
                local name, token = GetClassInfo(i)
                if type(name) == "string" and type(token) == "string" then found[name] = token end
            end
        end
        if next(found) then tokens = found end
    end
    local token = tokens and tokens[className]
    if token then return token end
    local upper = className:upper()
    if RAID_CLASS_COLORS and RAID_CLASS_COLORS[upper] then return upper end
end

-- The class token from a character's GUID, when its name didn't give one.
local function ByGuid(guid)
    if type(GetPlayerInfoByGUID) ~= "function" or not Public(guid) or type(guid) ~= "string" or guid == "" then return nil end
    local ok, _, token = pcall(GetPlayerInfoByGUID, guid)
    if ok and Public(token) and type(token) == "string" and token ~= "" then return token end
end

-- r, g, b of a class, or nil.
function Friends.Colour(token)
    local colour = token and RAID_CLASS_COLORS and RAID_CLASS_COLORS[token]
    if type(colour) ~= "table" or type(colour.r) ~= "number" then return nil end
    return colour.r, colour.g, colour.b
end

local function Code(r, g, b)
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + .5), math.floor(g * 255 + .5), math.floor(b * 255 + .5))
end

-- Where the last "find" starts in text, plainly.
local function LastPlain(text, find)
    local at, from = nil, 1
    while true do
        local start = text:find(find, from, true)
        if not start then return at end
        at, from = start, start + 1
    end
end

-- The code the game opened a Battle.net friend's brackets with (this
-- faction's, or the other faction's) and where the last of them starts.
local function Bracket(text)
    local code, at
    for i = 1, 2 do
        local try = select(i, FRIENDS_WOW_NAME_COLOR_CODE, FRIENDS_OTHER_NAME_COLOR_CODE)
        local found = type(try) == "string" and try ~= "" and LastPlain(text, try .. "(")
        if found and (not at or found > at) then code, at = try, found end
    end
    return code, at
end

-- A character friend: online, the whole name line in the class colour.
local function PaintWow(button, id, name)
    local list = C_FriendList
    if not (list and list.GetFriendInfoByIndex) then return end
    local ok, info = pcall(list.GetFriendInfoByIndex, id)
    if not ok or type(info) ~= "table" or not Public(info.connected) or not info.connected then return end
    local r, g, b = Friends.Colour(Friends.Token(info.className) or ByGuid(info.guid))
    if not r then return end
    name:SetTextColor(r, g, b)
    painted[button] = "wow"
end

-- A widget's yes/no; a secret one counts as yes.
local function Yes(widget, method)
    if type(widget) ~= "table" or type(widget[method]) ~= "function" then return false end
    local yes = widget[method](widget)
    return not Public(yes) or yes == true
end

-- A Battle.net friend playing this game, on either faction: the character's
-- name in brackets, and with Show Their Level its level before the closing
-- bracket. A class it can't tell keeps the game's colour (this faction's code
-- or the other's, whichever it wrote); the level still shows. No level for a
-- favourite (the game puts its star just after the name it wrote) or when it
-- would no longer fit the row. Brackets already coloured inside are left alone.
local function PaintBnet(button, id, name)
    local net = C_BattleNet
    if not (net and net.GetFriendAccountInfo) then return end
    local ok, account = pcall(net.GetFriendAccountInfo, id)
    local game = ok and type(account) == "table" and account.gameAccountInfo
    if type(game) ~= "table" or not Public(game.isOnline) or not game.isOnline then return end
    if not Public(game.clientProgram) or game.clientProgram ~= BNET_CLIENT_WOW then return end
    if WOW_PROJECT_ID and not (Public(game.wowProjectID) and game.wowProjectID == WOW_PROJECT_ID) then return end
    local r, g, b = Friends.Colour(Friends.Token(game.className) or ByGuid(game.playerGuid))
    local level = Friends:LevelOn() and not Yes(button.Favorite, "IsShown") and Friends.Level(game.characterLevel) or nil
    local text = name:GetText()
    if not (r or level) or not Public(text) or type(text) ~= "string" then return end
    local opener, at = Bracket(text)
    if not at or text:sub(at + #opener + 1, at + #opener + 2) == "|c" then return end
    local code = r and Code(r, g, b) or opener
    local coloured = text:sub(1, at - 1) .. code .. text:sub(at + #opener)
    local close = level and LastPlain(coloured, ")")
    if close and close > at then
        name:SetText(coloured:sub(1, close - 1) .. level .. coloured:sub(close))
        if not Yes(name, "IsTruncated") then
            painted[button] = {code, level, opener}
            return
        end
        if not r then name:SetText(text) end -- too long, and no colour: the game's text back
    end
    if not r then return end
    name:SetText(coloured)
    painted[button] = {code, nil, opener}
end

-- After the game fills a friend row.
function Friends:Paint(button, elementData)
    if type(button) ~= "table" then return end
    painted[button] = nil -- the game has just set its name afresh
    if not self:On() then return end
    local name = button.name
    if type(name) ~= "table" or type(name.SetTextColor) ~= "function" then return end
    local data = type(elementData) == "table" and elementData or button
    local kind, id = data.buttonType, data.id
    if not Public(kind) or not Public(id) or type(id) ~= "number" then return end
    if kind == FRIENDS_BUTTON_TYPE_WOW then
        PaintWow(button, id, name)
    elseif kind == FRIENDS_BUTTON_TYPE_BNET then
        PaintBnet(button, id, name)
    end
end

-- The names this coloured, back to the game's colours, without the levels.
function Friends:Unpaint()
    local wowColour = FRIENDS_WOW_NAME_COLOR
    for button, what in pairs(painted) do
        local name = button.name
        if type(name) == "table" then
            if what == "wow" then
                if type(wowColour) == "table" then name:SetTextColor(wowColour.r, wowColour.g, wowColour.b) end
            elseif type(what) == "table" and type(what[3]) == "string" then
                local code, level, opener = what[1], what[2], what[3] -- opener: this faction's code or the other's
                local text = name:GetText()
                local at = Public(text) and type(text) == "string" and LastPlain(text, code .. "(")
                if at then
                    text = text:sub(1, at - 1) .. opener .. text:sub(at + #code)
                    local close = level and LastPlain(text, level .. ")")
                    if close and close > at then text = text:sub(1, close - 1) .. text:sub(close + #level) end
                    name:SetText(text)
                end
            end
        end
        painted[button] = nil
    end
end

-- Every friend row showing now and not coloured yet, coloured.
function Friends:PaintShown()
    local box = FriendsListFrame and FriendsListFrame.ScrollBox
    if type(box) ~= "table" or type(box.ForEachFrame) ~= "function" then return end
    box:ForEachFrame(function(button, elementData)
        if painted[button] == nil then Friends:Paint(button, elementData) end
    end)
end

local function After(button, elementData)
    local ok, problem = pcall(Friends.Paint, Friends, button, elementData)
    if not ok and geterrorhandler then geterrorhandler()(problem) end
end

-- The game's friend row function (its friends window may load later).
function Friends:Hook()
    if self.hooked then return true end
    if type(FriendsFrame_UpdateFriendButton) ~= "function" then return false end
    self.hooked = true
    hooksecurefunc("FriendsFrame_UpdateFriendButton", After)
    return true
end

local function OnEvent(self)
    if Friends:Hook() then self:UnregisterEvent("ADDON_LOADED") end
end

-- Follows the option, at once both ways. again: Show Their Level changed, so
-- the rows showing are put back and done afresh.
function Friends:Refresh(again)
    if again or not self:On() then self:Unpaint() end
    if not self:On() then return end
    if not self:Hook() and not self.waiting then
        self.waiting = CreateFrame("Frame")
        self.waiting:SetScript("OnEvent", OnEvent)
        self.waiting:RegisterEvent("ADDON_LOADED")
    end
    if self.hooked then self:PaintShown() end
end

function Friends:Initialize()
    self:Refresh()
end
